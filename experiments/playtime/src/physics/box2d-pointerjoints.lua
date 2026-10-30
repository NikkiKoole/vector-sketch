--box2d-pointerjoints.lua
local lib = {}
local state = require 'src.state'
local BT = require('src.body-types')
local mipoRegistry = require('src.mipo-registry')
local units = require('src.physics-units')
local pointerJoints = {}

local function getPointerPosition(id)
    if id == 'mouse' then
        return love.mouse.getPosition()
    else
        return love.touch.getPosition(id)
    end
end

local function makePrio(fixture)
    local ud = fixture:getUserData()
    if ud and type(ud) == 'table' then
        if ud.bodyType then
            if string.match(ud.bodyType, 'hand') then
                return 3
            end

            if string.match(ud.bodyType, 'arm') then
                return 2
            end
        end
    end
    return 1
end

function lib.makePointerJoint(id, bodyToAttachTo, wx, wy, force, damp)
    local pointerJoint = {}
    pointerJoint.id = id
    pointerJoint.jointBody = bodyToAttachTo
    pointerJoint.joint = love.physics.newMouseJoint(pointerJoint.jointBody, wx, wy)
    pointerJoint.joint:setDampingRatio(damp or .5)
    -- force (src/input-manager.lua, from state.world.dragStrength) and Box2D's 5 Hz spring
    -- as at 100 px per metre
    pointerJoint.joint:setMaxForce(units.force(force))
    pointerJoint.joint:setFrequency(units.rate(pointerJoint.joint:getFrequency()))
    return pointerJoint
end

function lib.resetPointerJoints()
    pointerJoints = {}
end

function lib.killMouseJointIfPossible(id)
    local index = -1
    if pointerJoints then
        for i = 1, #pointerJoints do
            if pointerJoints[i].id == id then
                index = i
                if (pointerJoints[i].joint and not pointerJoints[i].joint:isDestroyed()) then
                    pointerJoints[i].joint:destroy()
                end
                pointerJoints[i].joint     = nil
                pointerJoints[i].jointBody = nil
            end
        end
        if index ~= -1 then
            table.remove(pointerJoints, index)
        end
    end
end

function lib.removeDeadPointerJoints()
    for i = #pointerJoints, 1, -1 do
        if (pointerJoints[i].joint and pointerJoints[i].joint:isDestroyed()) then
            pointerJoints[i].joint     = nil
            pointerJoints[i].jointBody = nil
            table.remove(pointerJoints, i)
        end
    end
end

-- A grabbed Mipo follows the pointer at most this fast (world units/s); false = off.
-- Added when fast drags tore limb joints; off since unwind + heal (mipo-joint-guard)
-- handle that and the cap made dragging feel laggy. 3000 if it's ever needed again.
lib.maxMipoDragSpeed = false

-- Move a target toward (wx, wy), at most maxStep far.
function lib.stepToward(tx, ty, wx, wy, maxStep)
    local dx, dy = wx - tx, wy - ty
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist <= maxStep or dist == 0 then return wx, wy end
    local k = maxStep / dist
    return tx + dx * k, ty + dy * k
end

function lib.handlePointerUpdate(dt, cam)
    lib.removeDeadPointerJoints()
    -- connect connectors
    for i = 1, #pointerJoints do
        local mj = pointerJoints[i]
        if (mj.joint) then
            local mx, my = getPointerPosition(mj.id) --love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)
            if lib.maxMipoDragSpeed and dt and mipoRegistry.getFromBody(mj.jointBody) then
                local tx, ty = mj.joint:getTarget()
                wx, wy = lib.stepToward(tx, ty, wx, wy, lib.maxMipoDragSpeed * dt)
            end
            mj.joint:setTarget(wx, wy)
        end
    end

    -- diconnect connectors
end

function lib.getPointerJointAttachedTo(body)
    if pointerJoints then
        for i = 1, #pointerJoints do
            local mj = pointerJoints[i]
            if mj.joint and mj.jointBody and mj.jointBody == body then
                return mj
            end
        end
    end
end

function lib.getInteractedWithPointer()
    local interactedWith = {}
    local pjs = pointerJoints
    for i = 1, #pjs do
        local b = pjs[i].jointBody
        -- A stone being dragged can be destroyed out from under us (e.g. by
        -- the beginContact reset hook). Skip dead refs so callers don't
        -- crash on :getUserData().
        if b and not b:isDestroyed() then
            table.insert(interactedWith, b)
        end
    end
    return interactedWith
end

function lib.getPointerJoints()
    return pointerJoints
end

function lib.handlePointerReleased(_x, _y, id)
    local released = {}
    if pointerJoints then
        for i = 1, #pointerJoints do
            local mj = pointerJoints[i]
            if mj.id == id then
                if mj.joint and mj.jointBody then
                    table.insert(released, mj.jointBody)
                end
            end
        end
        lib.killMouseJointIfPossible(id)
    end
    return released
end

function lib.handlePointerPressed(wx, wy, id, onPressedParams, allowMouseJointMaking)
    if allowMouseJointMaking == nil then allowMouseJointMaking = true end

    local bodies = state.physicsWorld:getBodies()
    local temp = {}
    local hitted = {}
    for _, body in ipairs(bodies) do
        if body:getType() == BT.KINEMATIC then
            -- for the playitme editor i do want to be able to slect these..
            local fixtures = body:getFixtures()
            for _, fixture in ipairs(fixtures) do
                local hitThisOne = fixture:testPoint(wx, wy)

                if (hitThisOne) then
                    table.insert(hitted, fixture)
                end
            end
        end
        if body:getType() ~= BT.KINEMATIC then
            local fixtures = body:getFixtures()
            for _, fixture in ipairs(fixtures) do
                local hitThisOne = fixture:testPoint(wx, wy)
                local isSensor = fixture:isSensor()
                if (hitThisOne) then
                    table.insert(hitted, fixture)
                end
                -- something here needs to be parameterized.

                if (hitThisOne and not isSensor) then
                    table.insert(temp,
                        { id = id, body = body, wx = wx, wy = wy, prio = makePrio(fixture), fixture = fixture })
                end
            end
        end
    end

    -- inside a blob but between its rim circles and its handle: carry it by the handle
    if #temp == 0 then
        local blobBody, handle = require('src.blob').hitAt(wx, wy)
        if blobBody then
            table.insert(hitted, handle)
            table.insert(temp, { id = id, body = blobBody, wx = wx, wy = wy, prio = 1, fixture = handle })
        end
    end

    local createdmousejointdata = {}

    if #temp > 0 then
        table.sort(temp, function(k1, k2) return k1.prio > k2.prio end)
        lib.killMouseJointIfPossible(id)

        local damp = .5
        if onPressedParams and onPressedParams.damp then
            damp = onPressedParams.damp
        end
        local force = 100
        if onPressedParams and onPressedParams.pointerForceFunc then
            force = onPressedParams.pointerForceFunc(temp[1].fixture)
        end

        if (allowMouseJointMaking) then
            local udID = nil
            if temp[1].body:getUserData() and temp[1].body:getUserData().thing.id then
                udID = temp[1].body:getUserData().thing.id
            end
            createdmousejointdata = {
                pointerID = temp[1].id,
                bodyID = udID,
                --body = temp[1].body,
                wx = temp[1].wx,
                wy = temp[1].wy,
                force = force,
                damp = damp
            }
            table.insert(pointerJoints,
                lib.makePointerJoint(temp[1].id, temp[1].body, temp[1].wx, temp[1].wy, force, damp))
        end
    end
    if #temp == 0 then lib.killMouseJointIfPossible(id) end

    return #temp > 0, hitted, createdmousejointdata
end

return lib

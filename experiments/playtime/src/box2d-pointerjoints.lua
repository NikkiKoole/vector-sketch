local lib = {}


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
        if string.match(ud.bodyType, 'hand') then
            return 3
        end

        if string.match(ud.bodyType, 'arm') then
            return 2
        end
    end
    return 1
end

local function makePointerJoint(id, bodyToAttachTo, wx, wy, force, damp)
    local pointerJoint = {}
    pointerJoint.id = id
    pointerJoint.jointBody = bodyToAttachTo
    pointerJoint.joint = love.physics.newMouseJoint(pointerJoint.jointBody, wx, wy)
    pointerJoint.joint:setDampingRatio(damp or .5)
    pointerJoint.joint:setMaxForce(force)
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
    local index = -1
    for i = #pointerJoints, 1, -1 do
        if (pointerJoints[i].joint and pointerJoints[i].joint:isDestroyed()) then
            pointerJoints[i].joint     = nil
            pointerJoints[i].jointBody = nil
            table.remove(pointerJoints, i)
        end
    end
end

function lib.handlePointerUpdate(dt, cam)
    lib.removeDeadPointerJoints()
    -- connect connectors
    for i = 1, #pointerJoints do
        local mj = pointerJoints[i]
        if (mj.joint) then
            local mx, my = getPointerPosition(mj.id) --love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)
            mj.joint:setTarget(wx, wy)

            local fixtures = mj.jointBody:getFixtures()
            for k = 1, #fixtures do
                local f = fixtures[k]
                if f:getUserData() and type(f:getUserData()) == 'table' and f:getUserData().bodyType then
                    if f:getUserData().bodyType == 'connector' then
                        --connect.maybeConnectThisConnector(f)
                    end
                end
            end
        end
    end

    -- diconnect connectors
    --connect.maybeBreakAnyConnectorBecauseForce(dt)
    --connect.cleanupCoolDownList(dt)
end

function lib.handlePointerReleased(x, y, id)
    local released = {}
    if pointerJoints then
        for i = 1, #pointerJoints do
            local mj = pointerJoints[i]
            -- if false then
            if mj.id == id then
                if mj.joint and mj.jointBody then
                    table.insert(released, mj.jointBody)
                end
            end
        end
        lib.killMouseJointIfPossible(id)
    end
    print('jo!', #released)
    return released
end

function lib.handlePointerPressed(wx, wy, id, onPressedParams, allowMouseJointMaking)
    if allowMouseJointMaking == nil then allowMouseJointMaking = true end
    -- local wx, wy = cam:getWorldCoordinates(x, y)
    --

    local bodies = world:getBodies()
    local temp = {}
    local hitted = {}
    for _, body in ipairs(bodies) do
        if body:getType() == 'kinematic' then
            -- for the playitme editor i do want to be able to slect these..
            -- local fixtures = body:getFixtures()
            local fixtures = body:getFixtures()
            for _, fixture in ipairs(fixtures) do
                local hitThisOne = fixture:testPoint(wx, wy)

                if (hitThisOne) then
                    table.insert(hitted, fixture)
                end
            end
        end
        if body:getType() ~= 'kinematic' then
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

                    if onPressedParams then
                        if onPressedParams.onPressedFunc then
                            onPressedParams.onPressedFunc(body)
                        end
                    end
                end
            end
        end
    end
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
            table.insert(pointerJoints, makePointerJoint(temp[1].id, temp[1].body, temp[1].wx, temp[1].wy, force, damp))
        end
    end
    -- print(#pointerJoints)
    if #temp == 0 then lib.killMouseJointIfPossible(id) end

    return #temp > 0, hitted
end

return lib

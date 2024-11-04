if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

package.path = package.path .. ";../../?.lua"
--local phys   = require 'lib.mainPhysics'
local phys = {}
function love.mousereleased(x, y, button, istouch)
    lastDraggedElement = nil
    if not istouch then
        pointerReleased(x, y, 'mouse')
    end
end

phys.killMouseJointIfPossible = function(id)
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
        table.remove(pointerJoints, index)
    end
end
local function makePointerJoint(id, bodyToAttachTo, wx, wy, force)
    local pointerJoint = {}
    pointerJoint.id = id

    -- local ud = fixture:getUserData()
    -- TODO parametrtize this...!
    -- local force = 100 -- ud and ud.bodyType == 'torso' and 5000000 or 50000

    pointerJoint.jointBody = bodyToAttachTo
    pointerJoint.joint = love.physics.newMouseJoint(pointerJoint.jointBody, wx, wy)
    pointerJoint.joint:setDampingRatio(.5)
    pointerJoint.joint:setMaxForce(force)
    return pointerJoint
end
phys.handlePointerPressed = function(wx, wy, id, onPressedParams)
    -- local wx, wy = cam:getWorldCoordinates(x, y)
    local bodies = world:getBodies()
    local temp = {}
    for _, body in ipairs(bodies) do
        if body:getType() ~= 'kinematic' then
            local fixtures = body:getFixtures()
            for _, fixture in ipairs(fixtures) do
                local hitThisOne = fixture:testPoint(wx, wy)
                local isSensor = fixture:isSensor()

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
        local force = 100
        if onPressedParams and onPressedParams.pointerForceFunc then
            force = onPressedParams.pointerForceFunc(temp[1].fixture)
        end

        table.insert(pointerJoints, makePointerJoint(temp[1].id, temp[1].body, temp[1].wx, temp[1].wy, force))
    end
    -- print(#pointerJoints)
    if #temp == 0 then lib.killMouseJointIfPossible(id) end

    return #temp > 0
end
local function makePrio(fixture)
    local ud = fixture:getUserData()
    if ud then
        if string.match(ud.bodyType, 'hand') then
            return 3
        end

        if string.match(ud.bodyType, 'arm') then
            return 2
        end
    end
    return 1
end

phys.setupWorld = function(m)
    love.physics.setMeter(m)
    world = love.physics.newWorld(0, 9.81 * love.physics.getMeter(), true)

    disabledContacts = {}
    pointerJoints = {}

    --connect.resetConnectors()
end

local function pointerReleased(x, y, id)
    phys.handlePointerReleased(x, y, id)
    --ui.removeFromPressedPointers(id)
end
function love.touchreleased(id, x, y, dx, dy, pressure)
    pointerReleased(x, y, id)
    --ui.removeFromPressedPointers(id)
end

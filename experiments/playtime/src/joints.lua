--joints.lua

local lib = {}
local uuid = require 'src.uuid'
local jointHandlers = require 'src.joint-handlers'
local registry = require 'src.registry'
local mathutils = require 'src.math-utils'

function lib.getJointId(joint)
    local ud = joint:getUserData()
    if ud then
        return ud.id
    end
    print('THIS IS WRONG WHY THIS JOINT HAS NO ID!!', tostring(joint:getType()))
    return nil
end

function lib.setJointMetaSetting(joint, settingKey, settingValue)
    -- Get the existing userdata
    local ud = joint:getUserData() or {}

    -- Ensure userdata is a table
    if type(ud) ~= "table" then
        ud = {} -- Initialize as a table if not already
    end

    -- Update or add the specific setting
    ud[settingKey] = settingValue

    -- Set the updated userdata back on the joint
    joint:setUserData(ud)
end

function lib.getJointMetaSetting(joint, settingKey)
    -- Get the existing userdata
    local ud = joint:getUserData()

    -- Check if userdata exists and is a table
    if type(ud) == "table" then
        return ud[settingKey] -- Return the specific setting
    else
        print('could not find meta settting ' .. settingKey .. ' on joint with type ' .. tostring(joint:getType()))
        return nil -- Return nil if userdata is not a table or doesn't exist
    end
end

function lib.createJoint(data)
    local bodyA = data.body1
    local bodyB = data.body2
    local jointType = data.jointType

    local joint

    local x1, y1 = bodyA:getPosition()
    local x2, y2 = bodyB:getPosition()


    if not (jointType == 'rope' or jointType == 'distance') then
        -- i only want to do the positioning when im a rope joint..!
        -- that p1 and p2 is set when creating the joint by clicking on the bodies..
        data.p1 = { 0, 0 }
        data.p2 = { 0, 0 }
    end

    local offsetA = data.offsetA or { x = data.p1[1], y = data.p1[2] } or { x = 0, y = 0 }
    local rx, ry = mathutils.rotatePoint(offsetA.x, offsetA.y, 0, 0, bodyA:getAngle())
    x1, y1 = x1 + rx, y1 + ry

    local offsetB = data.offsetB or { x = data.p2[1], y = data.p2[2] } or { x = 0, y = 0 }
    local rx, ry = mathutils.rotatePoint(offsetB.x, offsetB.y, 0, 0, bodyB:getAngle())
    x2, y2 = x2 + rx, y2 + ry

    local handler = jointHandlers[jointType]

    if handler and handler.create then
        joint = handler.create(data, x1, y1, x2, y2)
    else
        print("Joint type '" .. jointType .. "' is not implemented yet.")
        return
    end

    local setId = data.id or uuid.generateID()
    joint:setUserData({ id = setId })
    lib.setJointMetaSetting(joint, 'offsetA', offsetA)
    lib.setJointMetaSetting(joint, 'offsetB', offsetB)

    registry.registerJoint(setId, joint)
    return joint
end

function lib.extractJoints(body)
    local joints = body:getJoints()
    local jointData = {}

    for _, joint in ipairs(joints) do
        local bodyA, bodyB = joint:getBodies()
        local otherBody = (bodyA == body) and bodyB or bodyA -- Determine the other connected body
        local jointType = joint:getType()
        local isBodyA = (bodyA == body)

        local data = {
            offsetA = lib.getJointMetaSetting(joint, "offsetA"),
            offsetB = lib.getJointMetaSetting(joint, "offsetB"),
            id = lib.getJointId(joint),
            jointType = jointType,
            otherBody = otherBody,
            collideConnected = joint:getCollideConnected(),
            originalBodyOrder = isBodyA and "bodyA" or "bodyB",
        }

        local handler = jointHandlers[jointType]
        if not handler or not handler.extract then
            print("extract: Unsupported joint type: " .. jointType)
            goto continue
        end

        -- Extract additional data using the handler
        local additionalData = handler.extract(joint)
        for key, value in pairs(additionalData) do
            data[key] = value
        end

        table.insert(jointData, data)
        ::continue::
    end

    return jointData
end

function lib.recreateJoint(joint, newSettings)
    if joint:isDestroyed() then
        print("The joint is already destroyed.")
        return nil
    end

    local bodyA, bodyB = joint:getBodies()
    local jointType = joint:getType()

    local id = lib.getJointId(joint)
    local offsetA = lib.getJointMetaSetting(joint, "offsetA") or { x = 0, y = 0 }
    local offsetB = lib.getJointMetaSetting(joint, "offsetB") or { x = 0, y = 0 }
    --  print(inspect(offsetA), inspect(offsetB))
    local data = {
        body1 = bodyA,
        body2 = bodyB,
        jointType = jointType,
        id = id,
        offsetA = offsetA,
        offsetB = offsetB,
        collideConnected =
            joint:getCollideConnected()
    }

    -- Add new settings to the data
    for key, value in pairs(newSettings or {}) do
        data[key] = value
    end

    local handler = jointHandlers[jointType]
    if not handler or not handler.extract then
        print("recreate extract: Unsupported joint type: " .. jointType)
    end

    -- Extract additional data using the handler
    local additionalData = handler.extract(joint)
    for key, value in pairs(additionalData) do
        data[key] = value
    end

    joint:destroy()

    -- Create a new joint with the updated data
    bodyA:setAwake(true)
    bodyB:setAwake(true)
    --  print(inspect(data))
    return lib.createJoint(data)
end

-- this one is only called from recreateThingFromBody


local function tranlateBody(body, dx, dy)
    local x, y = body:getPosition()
    body:setPosition(x + dx, y + dy)
end

function moveUntilEnd(from, dx, dy, visited, dir)
    --print(dx, dy, visited[to:getUserData().thing.id], to)

    local joints = from:getJoints()
    for i = 1, #joints do
        local bodyA, bodyB = joints[i]:getBodies()

        if (dir == 'A') then
            if (not visited[bodyB:getUserData().thing.id]) then
                tranlateBody(bodyB, dx, dy)
                visited[bodyB:getUserData().thing.id] = true
                moveUntilEnd(bodyB, dx, dy, visited, dir)
            end
        end
        if dir == 'B' then
            if (not visited[bodyA:getUserData().thing.id]) then
                tranlateBody(bodyA, dx, dy)
                visited[bodyA:getUserData().thing.id] = true
                moveUntilEnd(bodyA, dx, dy, visited, dir)
            end
        end
    end
end

function lib.reattachJoints(jointData, newBody, oldVertices)
    local visited = {}
    for _, data in ipairs(jointData) do
        local jointType = data.jointType
        local otherBody = data.otherBody



        if data.originalBodyOrder == "bodyA" then
            data.body1 = newBody
            data.body2 = data.otherBody
            --  print(inspect(oldVertices))
            local before = { x = data.offsetA.x, y = data.offsetA.y }
            --  print('A before: ', data.offsetA.x, data.offsetA.y)
            if true then
                local weights = mathutils.getMeanValueCoordinatesWeights(data.offsetA.x, data.offsetA.y, oldVertices)
                local newx, newy = mathutils.repositionPointUsingWeights(weights, newBody:getUserData().thing.vertices)

                data.offsetA.x = newx
                data.offsetA.y = newy
            end


            local after = { x = data.offsetA.x, y = data.offsetA.y }

            local rx, ry = mathutils.rotatePoint(
                after.x - before.x, after.y - before.y, 0, 0, newBody:getAngle()
            )
            local id = data.otherBody:getUserData().thing.id
            if (not visited[id]) then
                local ox, oy = data.otherBody:getPosition()

                tranlateBody(data.otherBody, rx, ry)
                --moveUntilEnd(from, dx, dy, visited)
                --data.otherBody:setPosition(ox + rx, oy + ry)
                visited[id] = true
                moveUntilEnd(data.otherBody, rx, ry, visited, 'A')
                print('A', id)
            end
        else
            data.body1 = data.otherBody
            data.body2 = newBody

            local before = { x = data.offsetB.x, y = data.offsetB.y }

            if true then
                local weights = mathutils.getMeanValueCoordinatesWeights(data.offsetB.x, data.offsetB.y, oldVertices)
                local newx, newy = mathutils.repositionPointUsingWeights(weights, newBody:getUserData().thing.vertices)

                data.offsetB.x = newx
                data.offsetB.y = newy
            end


            local after = { x = data.offsetB.x, y = data.offsetB.y }

            local ox, oy = data.otherBody:getPosition()
            local rx, ry = mathutils.rotatePoint(
                after.x - before.x, after.y - before.y, 0, 0, newBody:getAngle()
            )
            local id = data.otherBody:getUserData().thing.id
            if not visited[id] then
                visited[id] = true
                tranlateBody(data.otherBody, rx, ry)
                --data.otherBody:setPosition(ox + rx, oy + ry)
                moveUntilEnd(data.otherBody, rx, ry, visited, 'B')
                --print('B', id)
            end


            -- if true then -- this pushes back the other way!
            --     local rx, ry = mathutils.rotatePoint(
            --         after.x - before.x, after.y - before.y, 0, 0, newBody:getAngle()
            --     )

            --     local nx, ny = newBody:getPosition()

            --     newBody:setPosition(nx - rx, ny - ry)
            -- end
        end


        local result = lib.createJoint(data)
    end
end

return lib

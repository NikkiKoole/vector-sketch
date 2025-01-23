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

function moveUntilEnd(from, to, dx, dy, visited)
    --print(dx, dy, visited[to:getUserData().thing.id], to)
    local mex, mey = to:getPosition()

    to:setPosition(mex - dx, mey - dy)
    visited[to:getUserData().thing.id] = true
    local joints = to:getJoints()
    for i = 1, #joints do
        local bodyA, bodyB = joints[i]:getBodies()
        local x1, y1, x2, y2 = joints[i]:getAnchors()
        --  print(x1, y1, x2, y2)
        -- print('***')
        -- print(bodyA:getLocalPoint(x1, y1))
        -- print(bodyB:getLocalPoint(x2, y2))
        -- print(inspect(joints[i]:getUserData().offsetA))
        -- print(inspect(joints[i]:getUserData().offsetB))
        if (not visited[bodyB:getUserData().thing.id]) then
            moveUntilEnd(to, bodyB, dx, dy, visited)
        end
        if (not visited[bodyA:getUserData().thing.id]) then
            moveUntilEnd(to, bodyA, dx, dy, visited)
        end
    end
end

function lib.reattachJoints(jointData, newBody, oldVertices)
    for _, data in ipairs(jointData) do
        local jointType = data.jointType
        local otherBody = data.otherBody

        local afterFunc = nil
        local visited = {}
        if data.originalBodyOrder == "bodyA" then
            data.body1 = newBody
            data.body2 = data.otherBody
            --  print(inspect(oldVertices))
            local before = { x = data.offsetA.x, y = data.offsetA.y }
            --  print('A before: ', data.offsetA.x, data.offsetA.y)
            if true then
                local weights = mathutils.getMeanValueCoordinatesWeights(data.offsetA.x, data.offsetA.y, oldVertices)
                local newx, newy = mathutils.repositionPointUsingWeights(weights, newBody:getUserData().thing.vertices)
                -- print('??', data.offsetA.x, data.offsetA.y, inspect(oldVertices), inspect(weights), newx, newy)
                data.offsetA.x = newx
                data.offsetA.y = newy
            end

            -- if false then
            --     local params = mathutils.closestEdgeParams(data.offsetA.x, data.offsetA.y, oldVertices)
            --     local newx, newy = mathutils.repositionPointClosestEdge(params, newBody:getUserData().thing.vertices)
            --     data.offsetA.x = newx
            --     data.offsetA.y = newy
            -- end

            -- if false then
            --     local edgeIndex, t = mathutils.findEdgeAndLerpParam(data.offsetA.x, data.offsetA.y, oldVertices)
            --     local newx, newy = mathutils.lerpOnEdge(edgeIndex, t, newBody:getUserData().thing.vertices)
            --     t = 0.5
            --     data.offsetA.x = newx
            --     data.offsetA.y = newy
            -- end
            -- print('A after: ', data.offsetA.x, data.offsetA.y)
            local after = { x = data.offsetA.x, y = data.offsetA.y }

            afterFunc = function(dx, dy)
                --    moveUntilEnd(newBody, data.otherBody, dx, dy, visited)
            end
            local ox, oy = data.otherBody:getPosition()
            --  print(after.x - before.x, after.y - before.y, 0, 0, newBody:getAngle())
            local rx, ry = mathutils.rotatePoint(
                after.x - before.x, after.y - before.y, 0, 0, newBody:getAngle()
            )

            data.otherBody:setPosition(ox + rx, oy + ry)
            -- print(inspect(weights))
        else
            data.body1 = data.otherBody
            data.body2 = newBody
            -- print(inspect(oldVertices))
            --  print('B before: ', data.offsetB.x, data.offsetB.y)
            local before = { x = data.offsetB.x, y = data.offsetB.y }
            if true then
                local weights = mathutils.getMeanValueCoordinatesWeights(data.offsetB.x, data.offsetB.y, oldVertices)
                local newx, newy = mathutils.repositionPointUsingWeights(weights, newBody:getUserData().thing.vertices)
                --print(newx, newy)
                data.offsetB.x = newx
                data.offsetB.y = newy
            end

            -- if false then
            --     local params = mathutils.closestEdgeParams(data.offsetB.x, data.offsetB.y, oldVertices)
            --     local newx, newy = mathutils.repositionPointClosestEdge(params, newBody:getUserData().thing.vertices)
            --     data.offsetB.x = newx
            --     data.offsetB.y = newy
            -- end


            -- if false then
            --     local edgeIndex, t = mathutils.findEdgeAndLerpParam(data.offsetB.x, data.offsetB.y, oldVertices)
            --     t = 0.5
            --     local newx, newy = mathutils.lerpOnEdge(edgeIndex, t, newBody:getUserData().thing.vertices)
            --     data.offsetB.x = newx
            --     data.offsetB.y = newy
            -- end
            local after = { x = data.offsetB.x, y = data.offsetB.y }
            --local ox, oy = newBody:getPosition()
            afterFunc = function(dx, dy)
                -- print(dx, dy)
                --  moveUntilEnd(newBody, data.otherBody, dx, dy, visited)
            end
            --  print('B after: ', data.offsetB.x, data.offsetB.y)
            -- print(inspect(weights))

            local ox, oy = data.otherBody:getPosition()
            -- data.otherBody:setPosition(ox + after.x - before.x, oy + after.y - before.y)
            local rx, ry = mathutils.rotatePoint(
                after.x - before.x, after.y - before.y, 0, 0, newBody:getAngle()
            )
            -- print(after.x - before.x, after.y - before.y, 0, 0, newBody:getAngle())
            -- print('?', rx, ry)
            data.otherBody:setPosition(ox + rx, oy + ry)
        end
        --print(
        --   'I should figure out if i want to do something weird with the reattach, think connect to torso logic at edge nr...')
        -- todo figure out how the changes between the old body and the new body will affect the joint..
        --





        -- Create the joint using the existing createJoint method
        --
        --- print(inspect(data))

        local result = lib.createJoint(data)
    end
end

return lib

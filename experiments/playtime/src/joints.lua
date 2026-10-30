--joints.lua

local lib = {}
local logger = require('src.logger')
local uuid = require('src.uuid')
local jointHandlers = require('src.joint-handlers')
local registry = require('src.registry')
local mathutils = require('src.math-utils')
local JT = require('src.joint-types')
local SIDES = require('src.sides')
local utils = require('src.utils')

-- Updates offsetA of a joint based on a new LOCAL point (relative to body A)
function lib.updateJointOffsetA(joint, localX, localY)
    if not joint or joint:isDestroyed() then
        logger:error("WARN: updateJointOffsetA called on invalid joint"); return nil
    end
    local offsetA = { x = localX, y = localY }
    local offsetB = lib.getJointMetaSetting(joint, "offsetB") or { x = 0, y = 0 } -- Keep existing offset B
    logger:info(string.format("Updating Joint %s Offset A to: (%.2f, %.2f)", (joint:getUserData().id or "N/A"), localX,
        localY))
    -- Recreate the joint using existing properties but new offset A
    return lib.recreateJoint(joint, { offsetA = offsetA, offsetB = offsetB })
end

-- Updates offsetB of a joint based on a new LOCAL point (relative to body B)
function lib.updateJointOffsetB(joint, localX, localY)
    if not joint or joint:isDestroyed() then
        logger:error("WARN: updateJointOffsetB called on invalid joint"); return nil
    end
    local offsetA = lib.getJointMetaSetting(joint, "offsetA") or { x = 0, y = 0 } -- Keep existing offset A
    local offsetB = { x = localX, y = localY }
    logger:info(string.format("Updating Joint %s Offset B to: (%.2f, %.2f)", (joint:getUserData().id or "N/A"), localX,
        localY))
    -- Recreate the joint using existing properties but new offset B
    return lib.recreateJoint(joint, { offsetA = offsetA, offsetB = offsetB })
end

function lib.getJointId(joint)
    local ud = joint:getUserData()
    if ud then
        return ud.id
    end
    logger:error('THIS IS WRONG WHY THIS JOINT HAS NO ID!!', tostring(joint:getType()))
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
        logger:error('could not find meta settting ' .. settingKey ..
            ' on joint with type ' .. tostring(joint:getType()))
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

    if not (jointType == JT.ROPE or jointType == JT.DISTANCE) then
        -- i only want to do the positioning when im a rope joint..!
        -- that p1 and p2 is set when creating the joint by clicking on the bodies..
        data.p1 = { 0, 0 }
        data.p2 = { 0, 0 }
    end
    -- rope/distance created without click-set anchors (e.g. from a script)
    -- still need defaults — data.p1[1] would index nil below
    data.p1 = data.p1 or { 0, 0 }
    data.p2 = data.p2 or { 0, 0 }

    local offsetA = data.offsetA or { x = data.p1[1], y = data.p1[2] }
    local rx, ry = mathutils.rotatePoint(offsetA.x, offsetA.y, 0, 0, bodyA:getAngle())
    x1, y1 = x1 + rx, y1 + ry

    local offsetB = data.offsetB or { x = data.p2[1], y = data.p2[2] }
    rx, ry = mathutils.rotatePoint(offsetB.x, offsetB.y, 0, 0, bodyB:getAngle())
    x2, y2 = x2 + rx, y2 + ry
    local handler = jointHandlers[jointType]

    if handler and handler.create then
        if bodyA == bodyB then
            logger:error("Cannot create joint: bodyA and bodyB are the same body")
            return
        else
            joint = handler.create(data, x1, y1, x2, y2)
            if handler.apply then handler.apply(joint, data) end
        end
    else
        logger:error("Joint type '" .. jointType .. "' is not implemented yet.")
        return
    end

    local setId = data.id or uuid.generateID()
    -- scriptmeta (e.g. a snap joint's { type = 'snap', a, b }) survives recreates
    joint:setUserData({ id = setId, scriptmeta = data.scriptmeta, label = data.label })
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
            scriptmeta = (joint:getUserData() or {}).scriptmeta,
        label = (joint:getUserData() or {}).label,
            collideConnected = joint:getCollideConnected(),
            originalBodyOrder = isBodyA and SIDES.BODY_A or SIDES.BODY_B,
        }

        local handler = jointHandlers[jointType]
        if handler and handler.extract then
            -- Extract additional data using the handler
            local additionalData = handler.extract(joint)
            for key, value in pairs(additionalData) do
                data[key] = value
            end

            table.insert(jointData, data)
        else
            logger:error("extract: Unsupported joint type: " .. jointType)
        end
    end

    return jointData
end

-- The joints along a chain of bodies, starting at body: each step takes the
-- first joint not walked yet. Ends at a body with no new joint (or none at all).
function lib.jointChain(body)
    local chain, walked, seen = {}, {}, {}
    while body and not seen[body] do
        seen[body] = true
        local nextJoint
        for _, joint in ipairs(body:getJoints()) do
            if not walked[joint] then
                nextJoint = joint
                break
            end
        end
        if not nextJoint then break end
        walked[nextJoint] = true
        table.insert(chain, nextJoint)
        local bodyA, bodyB = nextJoint:getBodies()
        body = (bodyA == body) and bodyB or bodyA
    end
    return chain
end

function lib.recreateJoint(joint, newSettings)
    if joint:isDestroyed() then
        logger:error("The joint is already destroyed.")
        return nil
    end

    local bodyA, bodyB = joint:getBodies()

    local jointType = joint:getType()

    local id = lib.getJointId(joint)
    local offsetA = lib.getJointMetaSetting(joint, "offsetA") or { x = 0, y = 0 }
    local offsetB = lib.getJointMetaSetting(joint, "offsetB") or { x = 0, y = 0 }

    local data = {
        body1 = bodyA,
        body2 = bodyB,
        jointType = jointType,
        id = id,
        offsetA = offsetA,
        offsetB = offsetB,
        collideConnected =
            joint:getCollideConnected(),
        scriptmeta = (joint:getUserData() or {}).scriptmeta,
        label = (joint:getUserData() or {}).label,
    }

    local handler = jointHandlers[jointType]
    if not handler or not handler.extract then
        logger:error("recreate extract: Unsupported joint type: " .. jointType)
        return nil
    end

    -- What the joint has now (motor, springs, limits), then the caller's changes on top
    for key, value in pairs(handler.extract(joint)) do
        data[key] = value
    end
    for key, value in pairs(newSettings or {}) do
        data[key] = value
    end

    joint:destroy()

    -- Create a new joint with the updated data
    bodyA:setAwake(true)
    bodyB:setAwake(true)

    return lib.createJoint(data)
end

-- this one is only called from recreateThingFromBody

local function translateBody(body, dx, dy)
    local x, y = body:getPosition()
    body:setPosition(x + dx, y + dy)
end

-- Move everything jointed onward from `from`, following the joints' other side (dir A: their
-- bodyB, dir B: their bodyA), each body once.
local function moveUntilEnd(from, dx, dy, visited, dir)
    local joints = from:getJoints()
    for i = 1, #joints do
        local bodyA, bodyB = joints[i]:getBodies()
        local nextBody = dir == SIDES.A and bodyB or bodyA
        local id = utils.thingOf(nextBody).id
        if not visited[id] then
            translateBody(nextBody, dx, dy)
            visited[id] = true
            moveUntilEnd(nextBody, dx, dy, visited, dir)
        end
    end
end

-- The new body keeps its side of each joint; that side's anchor moves with the reshaped polygon
-- (mean value coordinates), and what hangs on the other side moves along.
function lib.reattachJoints(jointData, newBody, oldVertices)
    local visited = {}
    for _, data in ipairs(jointData) do
        local onA = data.originalBodyOrder == SIDES.BODY_A
        local offset = onA and data.offsetA or data.offsetB
        if onA then
            data.body1, data.body2 = newBody, data.otherBody
        else
            data.body1, data.body2 = data.otherBody, newBody
        end

        local beforeX, beforeY = offset.x, offset.y
        local weights = mathutils.getMeanValueCoordinatesWeights(offset.x, offset.y, oldVertices)
        offset.x, offset.y = mathutils.repositionPointUsingWeights(weights, utils.thingOf(newBody).vertices)

        local rx, ry = mathutils.rotatePoint(offset.x - beforeX, offset.y - beforeY, 0, 0, newBody:getAngle())
        local id = utils.thingOf(data.otherBody).id
        if not visited[id] then
            visited[id] = true
            translateBody(data.otherBody, rx, ry)
            moveUntilEnd(data.otherBody, rx, ry, visited, onA and SIDES.A or SIDES.B)
        end

        lib.createJoint(data)
    end
end

return lib

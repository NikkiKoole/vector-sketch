local lib = {}
package.path = package.path .. ";../../?.lua"
local inspect = require 'vendor.inspect'
local json = require 'src.dkjson'
local uuid = require 'src.uuid'
local registry = require 'src.registry'
local function generateID()
    return uuid.uuid()
end


function lib.load(data, world)
    -- Read the JSON file
    -- print(love.filesystem.read(filename))
    local jsonData, pos, err = json.decode(data, 1, nil)
    if err then
        print("Error decoding JSON:", err)
        return
    end

    -- Verify version
    if jsonData then
        if jsonData.version ~= "1.0" then
            print("Unsupported save version:", jsonData.version)
            return
        end
    else
        print('failed loading json')
        return
    end
    -- Clear existing world

    local idMap = {}
    local function getNewId(oldId)
        if idMap[oldId] == nil then
            idMap[oldId] = generateID()
        end
        return idMap[oldId]
    end

    if true then
        for _, body in pairs(world:getBodies()) do
            body:destroy()
        end
        registry.reset()
    end
    -- Iterate through saved bodies and recreate them
    for _, bodyData in ipairs(jsonData.bodies) do
        -- Create a new body
        local body = love.physics.newBody(world, bodyData.position.x, bodyData.position.y, bodyData.bodyType)
        body:setAngle(bodyData.angle)
        body:setLinearVelocity(bodyData.linearVelocity.x, bodyData.linearVelocity.y)
        body:setAngularVelocity(bodyData.angularVelocity)
        body:setFixedRotation(bodyData.fixedRotation)

        -- Iterate through fixtures and recreate shapes
        for _, fixtureData in ipairs(bodyData.fixtures) do
            local shape
            if fixtureData.shapeType == "circle" then
                shape = love.physics.newCircleShape(fixtureData.radius)
            elseif fixtureData.shapeType == "polygon" then
                local points = {}
                for _, point in ipairs(fixtureData.points) do
                    table.insert(points, point.x)
                    table.insert(points, point.y)
                end
                shape = love.physics.newPolygonShape(unpack(points))
            elseif fixtureData.shapeType == "edge" then
                local x1 = fixtureData.points[1].x
                local y1 = fixtureData.points[1].y
                local x2 = fixtureData.points[2].x
                local y2 = fixtureData.points[2].y
                shape = love.physics.newEdgeShape(x1, y1, x2, y2)
            else
                print("Unsupported shape type:", fixtureData.shapeType)
            end

            if shape then
                local fixture = love.physics.newFixture(body, shape, fixtureData.density)
                fixture:setFriction(fixtureData.friction)
                fixture:setRestitution(fixtureData.restitution)
            end
        end

        -- Recreate the 'thing' table
        local thing = {
            id = getNewId(bodyData.id),
            label = bodyData.label,
            shapeType = bodyData.shapeType,
            radius = bodyData.radius,
            width = bodyData.width,
            height = bodyData.height,
            body = body,
            shape = body:getFixtures()[1]:getShape(), -- Assuming one fixture per body
            fixture = body:getFixtures()[1],
        }

        -- Assign the 'thing' to the body's user data
        body:setUserData({ thing = thing })
        registry.registerBody(thing.id, body)
    end

    -- Iterate through saved joints and recreate them
    for _, jointData in ipairs(jsonData.joints) do
        local bodyA = registry.getBodyByID(getNewId(jointData.bodyA))
        local bodyB = registry.getBodyByID(getNewId(jointData.bodyB))

        if bodyA and bodyB then
            local joint
            local anchorA = jointData.anchorA
            local anchorB = jointData.anchorB
            local collideConnected = jointData.collideConnected


            if jointData.type == "distance" then
                joint = love.physics.newDistanceJoint(
                    bodyA, bodyB,
                    anchorA.x, anchorA.y,
                    anchorB.x, anchorB.y,
                    collideConnected
                )
                joint:setLength(jointData.properties.length)
                joint:setFrequency(jointData.properties.frequency)
                joint:setDampingRatio(jointData.properties.dampingRatio)
            elseif jointData.type == "revolute" then
                joint = love.physics.newRevoluteJoint(
                    bodyA, bodyB,
                    anchorA.x, anchorA.y,
                    collideConnected
                )
                joint:setMotorEnabled(jointData.properties.motorEnabled)
                if jointData.properties.motorEnabled then
                    joint:setMotorSpeed(jointData.properties.motorSpeed)
                    joint:setMaxMotorTorque(jointData.properties.maxMotorTorque)
                end
                joint:setLimitsEnabled(jointData.properties.limitsEnabled)
                if jointData.properties.limitsEnabled then
                    joint:setLimits(jointData.properties.lowerLimit, jointData.properties.upperLimit)
                end
            elseif jointData.type == "rope" then
                joint = love.physics.newRopeJoint(
                    bodyA, bodyB,
                    anchorA.x, anchorA.y,
                    anchorB.x, anchorB.y,
                    jointData.properties.maxLength
                )
            elseif jointData.type == "weld" then
                joint = love.physics.newWeldJoint(
                    bodyA, bodyB,
                    anchorA.x, anchorA.y,
                    collideConnected
                )
                joint:setFrequency(jointData.properties.frequency)
                joint:setDampingRatio(jointData.properties.dampingRatio)
            elseif jointData.type == "prismatic" then
                joint = love.physics.newPrismaticJoint(
                    bodyA, bodyB,
                    anchorA.x, anchorA.y,
                    jointData.properties.axis.x, jointData.properties.axis.y,
                    collideConnected
                )
                joint:setMotorEnabled(jointData.properties.motorEnabled)
                if jointData.properties.motorEnabled then
                    joint:setMotorSpeed(jointData.properties.motorSpeed)
                    joint:setMaxMotorForce(jointData.properties.maxMotorForce)
                end
                joint:setLimitsEnabled(jointData.properties.limitsEnabled)
                if jointData.properties.limitsEnabled then
                    joint:setLimits(jointData.properties.lowerLimit, jointData.properties.upperLimit)
                end
            elseif jointData.type == "pulley" then
                joint = love.physics.newPulleyJoint(
                    bodyA, bodyB,
                    jointData.properties.groundAnchor1.x, jointData.properties.groundAnchor1.y,
                    jointData.properties.groundAnchor2.x, jointData.properties.groundAnchor2.y,
                    anchorA.x, anchorA.y,
                    anchorB.x, anchorB.y,
                    jointData.properties.ratio,
                    collideConnected
                )
            elseif jointData.type == "wheel" then
                joint = love.physics.newWheelJoint(
                    bodyA, bodyB,
                    anchorA.x, anchorA.y,
                    jointData.properties.axis.x, jointData.properties.axis.y,
                    collideConnected
                )
                joint:setSpringFrequency(jointData.properties.springFrequency)
                joint:setSpringDampingRatio(jointData.properties.springDampingRatio)

                joint:setMotorEnabled(jointData.properties.motorEnabled)

                if jointData.properties.motorEnabled then
                    joint:setMotorSpeed(jointData.properties.motorSpeed)
                    joint:setMaxMotorTorque(jointData.properties.maxMotorTorque)
                end
            elseif jointData.type == "motor" then
                joint = love.physics.newMotorJoint(
                    bodyA, bodyB,
                    jointData.properties.correctionFactor,
                    collideConnected
                )
                joint:setAngularOffset(jointData.properties.angularOffset)
                joint:setLinearOffset(jointData.properties.linearOffsetX, jointData.properties.linearOffsetY)
                joint:setMaxForce(jointData.properties.maxForce)
                joint:setMaxTorque(jointData.properties.maxTorque)
            elseif jointData.type == "friction" then
                joint = love.physics.newFrictionJoint(
                    bodyA, bodyB,
                    anchorA.x, anchorA.y,
                    collideConnected
                )
                joint:setMaxForce(jointData.properties.maxForce)
                joint:setMaxTorque(jointData.properties.maxTorque)
            else
                -- Handle unsupported joint types
                print("Unsupported joint type during load:", jointData.type)
            end

            if joint then
                -- Assign the joint ID
                -- joint:setUserData({ id = jointData.id })


                local fxa, fya = rotatePoint(anchorA.x - bodyA:getX(), anchorA.y - bodyA:getY(), 0, 0, -bodyA:getAngle())
                local fxb, fyb = rotatePoint(anchorB.x - bodyB:getX(), anchorB.y - bodyB:getY(), 0, 0, -bodyB:getAngle())
                joint:setUserData({
                    id = getNewId(jointData.id),
                    offsetA = { x = fxa, y = fya },
                    offsetB = { x = fxb, y = fyb }
                })


                -- Register the joint in the registry
                registry.registerJoint(jointData.id, joint)
            end
        else
            print("Failed to find bodies for joint:", jointData.id)
        end
    end

    print("World successfully loaded")
end

local function sanitizeString(input)
    if not input then return "" end   -- Handle nil or empty strings
    return input:gsub("[%c%s]+$", "") -- Remove control characters and trailing spaces
end
function lib.save(world, worldState, filename)
    local saveData = {
        version = "1.0", -- Versioning for future compatibility
        bodies = {},
        joints = {}
    }
    for _, body in pairs(world:getBodies()) do
        local userData = body:getUserData()
        local thing = userData and userData.thing

        if thing then
            local lvx, lvy = body:getLinearVelocity()
            local bodyData = {
                id = thing.id, -- Unique identifier
                label = sanitizeString(thing.label),
                shapeType = thing.shapeType,
                radius = thing.radius,
                width = thing.width,
                height = thing.height,
                bodyType = body:getType(), -- 'dynamic', 'kinematic', or 'static'
                position = { x = body:getX(), y = body:getY() },
                angle = body:getAngle(),
                linearVelocity = { x = lvx, y = lvy },
                angularVelocity = body:getAngularVelocity(),
                fixedRotation = body:isFixedRotation(),
                fixtures = {}
            }
            -- Iterate through all fixtures of the body
            for _, fixture in ipairs(body:getFixtures()) do
                local shape = fixture:getShape()
                local fixtureData = {
                    density = fixture:getDensity(),
                    friction = fixture:getFriction(),
                    restitution = fixture:getRestitution()
                }

                if shape:typeOf("CircleShape") then
                    fixtureData.shapeType = "circle"
                    fixtureData.radius = shape:getRadius()
                elseif shape:typeOf("PolygonShape") then
                    fixtureData.shapeType = "polygon"
                    local points = {}
                    local points2 = { shape:getPoints() }
                    for i = 1, #points2, 2 do
                        local x, y = points2[i], points2[i + 1]
                        table.insert(points, { x = x, y = y })
                    end
                    fixtureData.points = points
                elseif shape:typeOf("EdgeShape") then
                    fixtureData.shapeType = "edge"
                    local x1, y1, x2, y2 = shape:getPoints()
                    fixtureData.points = { { x = x1, y = y1 }, { x = x2, y = y2 } }
                else
                    -- Handle other shape types if any
                    fixtureData.shapeType = "unknown"
                end

                table.insert(bodyData.fixtures, fixtureData)
            end

            table.insert(saveData.bodies, bodyData)
        end
    end

    -- Iterate through all joints in the world
    for _, joint in pairs(world:getJoints()) do
        local jointUserData = joint:getUserData()
        local jointID = jointUserData and jointUserData.id

        if not jointID then
            print('what is up with this joint?')
        end
        -- Get connected bodies
        local bodyA, bodyB = joint:getBodies()

        local thingA = bodyA:getUserData() and bodyA:getUserData().thing
        local thingB = bodyB:getUserData() and bodyB:getUserData().thing

        if thingA and thingB then
            local x1, y1, x2, y2 = joint:getAnchors()
            local jointData = {
                id = jointID,
                type = joint:getType(),
                bodyA = thingA.id,
                bodyB = thingB.id,
                anchorA = { x = x1, y = y1 },
                anchorB = { x = x2, y = y2 },
                collideConnected = joint:getCollideConnected(),
                properties = {}
            }

            -- Extract joint-specific properties
            if joint:getType() == "distance" then
                jointData.properties.length = joint:getLength()
                jointData.properties.frequency = joint:getFrequency()
                jointData.properties.dampingRatio = joint:getDampingRatio()
            elseif joint:getType() == 'rope' then
                jointData.properties.maxLength = joint:getMaxLength()
            elseif joint:getType() == "revolute" then
                jointData.properties.motorEnabled = joint:isMotorEnabled()
                if jointData.properties.motorEnabled then
                    jointData.properties.motorSpeed = joint:getMotorSpeed()
                    jointData.properties.maxMotorTorque = joint:getMaxMotorTorque()
                end
                jointData.properties.limitsEnabled = joint:areLimitsEnabled()
                if jointData.properties.limitsEnabled then
                    jointData.properties.lowerLimit = joint:getLowerLimit()
                    jointData.properties.upperLimit = joint:getUpperLimit()
                end
            elseif joint:getType() == "weld" then
                jointData.properties.frequency = joint:getFrequency()
                jointData.properties.dampingRatio = joint:getDampingRatio()
            elseif joint:getType() == "prismatic" then
                local axisx, axisy = joint:getAxis()
                jointData.properties.axis = { x = axisx, y = axisy }
                jointData.properties.motorEnabled = joint:isMotorEnabled()
                if jointData.properties.motorEnabled then
                    jointData.properties.motorSpeed = joint:getMotorSpeed()
                    jointData.properties.maxMotorForce = joint:getMaxMotorForce()
                end
                jointData.properties.limitsEnabled = joint:areLimitsEnabled()
                if jointData.properties.limitsEnabled then
                    jointData.properties.lowerLimit = joint:getLowerLimit()
                    jointData.properties.upperLimit = joint:getUpperLimit()
                end
            elseif joint:getType() == "pulley" then
                local a1x, a1y, a2x, a2y = joint:getGroundAnchors()
                jointData.properties.groundAnchor1 = { x = a1x, y = a1y }
                jointData.properties.groundAnchor2 = { x = a2x, y = a2y }
                jointData.properties.ratio = joint:getRatio()
            elseif joint:getType() == "wheel" then
                jointData.properties.motorEnabled = joint:isMotorEnabled()
                if jointData.properties.motorEnabled then
                    jointData.properties.motorSpeed = joint:getMotorSpeed()
                    jointData.properties.maxMotorTorque = joint:getMaxMotorTorque()
                end
                local axisx, axisy = joint:getAxis()
                jointData.properties.axis = { x = axisx, y = axisy }
                jointData.properties.springFrequency = joint:getSpringFrequency()
                jointData.properties.springDampingRatio = joint:getSpringDampingRatio()
            elseif joint:getType() == "motor" then
                jointData.properties.correctionFactor = joint:getCorrectionFactor()
                jointData.properties.angularOffset = joint:getAngularOffset()
                jointData.properties.linearOffsetX, jointData.properties.linearOffsetY = joint:getLinearOffset()
                jointData.properties.maxForce = joint:getMaxForce()
                jointData.properties.maxTorque = joint:getMaxTorque()
            elseif joint:getType() == "friction" then
                jointData.properties.maxForce = joint:getMaxForce()
                jointData.properties.maxTorque = joint:getMaxTorque()
            else
                -- Handle unsupported joint types
                print("Unsupported joint type during save:", joint:getType())
            end

            table.insert(saveData.joints, jointData)
        else
            print("Failed to find bodies for joint:", jointID)
        end
    end
    -- Serialize the data to JSON
    local jsonData = json.encode(saveData, { indent = true })

    -- Write the JSON data to a file
    local success, message = love.filesystem.write(filename .. '.playtime.json', jsonData)
    if success then
        print("World successfully saved to " .. filename)
        print("file://" .. love.filesystem.getSaveDirectory())
    else
        print("Failed to save world:", message)
    end

    love.system.openURL("file://" .. love.filesystem.getSaveDirectory())
end

return lib

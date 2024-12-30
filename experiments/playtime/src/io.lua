--io.lua
local lib = {}

local inspect = require 'vendor.inspect'
local json = require 'vendor.dkjson'
local uuid = require 'src.uuid'
local registry = require 'src.registry'
local shapes = require 'src.shapes'
local jointHandlers = require 'src.joint-handlers'
local mathutils = require 'src.math-utils'
local utils = require 'src.utils'
local jointslib = require 'src.joints'
local fixtures = require 'src.fixtures'

function lib.load(data, world)
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
            idMap[oldId] = uuid.generateID()
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
        local body = love.physics.newBody(world, bodyData.position[1], bodyData.position[2], bodyData.bodyType)
        body:setAngle(bodyData.angle)
        body:setLinearVelocity(bodyData.linearVelocity[1], bodyData.linearVelocity[2])
        body:setAngularVelocity(bodyData.angularVelocity)
        body:setFixedRotation(bodyData.fixedRotation)

        local shared = bodyData.sharedFixtureData

        for i = #bodyData.fixtures, 1, -1 do -- doing this backwards keeps order intact
            local fixtureData = bodyData.fixtures[i]
            local shape
            if shared.shapeType == "circle" then
                shape = love.physics.newCircleShape(fixtureData.radius)
            elseif shared.shapeType == "polygon" then
                local points = {}
                -- for _, point in ipairs(fixtureData.points) do
                --     table.insert(points, point.x)
                --     table.insert(points, point.y)
                -- end
                for _, point in ipairs(fixtureData.points) do
                    table.insert(points, point)
                end
                shape = love.physics.newPolygonShape(unpack(points))
                -- elseif fixtureData.shapeType == "edge" then
                --     local x1 = fixtureData.points[1].x
                --     local y1 = fixtureData.points[1].y
                --     local x2 = fixtureData.points[2].x
                --     local y2 = fixtureData.points[2].y
                --     shape = love.physics.newEdgeShape(x1, y1, x2, y2)
            else
                print("Unsupported shape type:", fixtureData.shapeType)
            end


            if shape then
                local fixture = love.physics.newFixture(body, shape, shared.density)
                fixture:setFriction(shared.friction)
                fixture:setRestitution(shared.restitution)

                if fixtureData.userData then
                    fixture:setSensor(fixtureData.sensor)
                    local oldUD = utils.shallowCopy(fixtureData.userData)
                    oldUD.id = getNewId(oldUD.id)

                    fixture:setUserData(oldUD)
                    --print(inspect(utils.shallowCopy(fixture:getUserData())))
                end
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
            vertices = bodyData.vertices,
            --  shape = body:getFixtures()[1]:getShape(), -- Assuming one fixture per body
            fixture = body:getFixtures()[1], -- this is used in clone.
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
                    anchorA[1], anchorA[2],
                    anchorB[1], anchorB[2],
                    collideConnected
                )
                joint:setLength(jointData.properties.length)
                joint:setFrequency(jointData.properties.frequency)
                joint:setDampingRatio(jointData.properties.dampingRatio)
            elseif jointData.type == "revolute" then
                joint = love.physics.newRevoluteJoint(
                    bodyA, bodyB,
                    anchorA[1], anchorA[2],
                    --anchorB[1], anchorB[2],
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
                    anchorA[1], anchorA[2],
                    anchorB[1], anchorB[2],
                    jointData.properties.maxLength
                )
            elseif jointData.type == "weld" then
                joint = love.physics.newWeldJoint(
                    bodyA, bodyB,
                    anchorA[1], anchorA[2],
                    collideConnected
                )
                joint:setFrequency(jointData.properties.frequency)
                joint:setDampingRatio(jointData.properties.dampingRatio)
            elseif jointData.type == "prismatic" then
                joint = love.physics.newPrismaticJoint(
                    bodyA, bodyB,
                    anchorA[1], anchorA[2],
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
                    anchorA[1], anchorA[2],
                    anchorB[1], anchorB[2],
                    jointData.properties.ratio,
                    collideConnected
                )
            elseif jointData.type == "wheel" then
                joint = love.physics.newWheelJoint(
                    bodyA, bodyB,
                    anchorA[1], anchorA[2],
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
                    anchorA[1], anchorA[2],
                    anchorB[1], anchorB[2],
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


                local fxa, fya = mathutils.rotatePoint(anchorA[1] - bodyA:getX(), anchorA[2] - bodyA:getY(), 0, 0,
                    -bodyA:getAngle())
                local fxb, fyb = mathutils.rotatePoint(anchorB[1] - bodyB:getX(), anchorB[2] - bodyB:getY(), 0, 0,
                    -bodyB:getAngle())


                local scriptmeta = jointData.scriptmeta

                local ud = {
                    id = getNewId(jointData.id),
                    offsetA = { x = fxa, y = fya },
                    offsetB = { x = fxb, y = fyb }
                }
                if jointData.scriptmeta then ud.scriptmeta = jointData.scriptmeta end

                joint:setUserData(ud)

                -- Register the joint in the registry
                registry.registerJoint(jointData.id, joint)
            end
        else
            print("Failed to find bodies for joint:", jointData.id)
        end
    end

    print("World successfully loaded")
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

        if thing and thing.id then
            local lvx, lvy = body:getLinearVelocity()
            local bodyData = {
                id = thing.id, -- Unique identifier
                label = utils.sanitizeString(thing.label),
                shapeType = thing.shapeType,
                radius = thing.radius,
                width = thing.width,
                height = thing.height,
                vertices = thing.shapeType == 'custom' and thing.vertices,
                bodyType = body:getType(), -- 'dynamic', 'kinematic', or 'static'
                position = { utils.round_to_decimals(body:getX(), 4), utils.round_to_decimals(body:getY(), 4) },
                angle = utils.round_to_decimals(body:getAngle(), 4),
                linearVelocity = { lvx, lvy },
                angularVelocity = utils.round_to_decimals(body:getAngularVelocity(), 4),
                fixedRotation = body:isFixedRotation(),
                fixtures = {},
                sharedFixtureData = {}
            }
            -- Iterate through all fixtures of the body

            -- to save data i am assuming all fixtures are the same type and have the same settings.
            local bodyFixtures = body:getFixtures()
            if #bodyFixtures >= 1 then
                if #bodyFixtures >= 1 then
                    local first = bodyFixtures[1]
                    bodyData.sharedFixtureData.density = utils.round_to_decimals(first:getDensity(), 4)
                    bodyData.sharedFixtureData.friction = utils.round_to_decimals(first:getFriction(), 4)
                    bodyData.sharedFixtureData.restitution = utils.round_to_decimals(first:getRestitution(), 4)
                    local shape = first:getShape()
                    if shape:typeOf("CircleShape") then
                        bodyData.sharedFixtureData.shapeType = 'circle'
                    elseif shape:typeOf("PolygonShape") then
                        bodyData.sharedFixtureData.shapeType = 'polygon'
                    end
                end
            end

            for _, fixture in ipairs(body:getFixtures()) do
                local shape = fixture:getShape()

                local fixtureData = {}
                if shape:typeOf("CircleShape") then
                    --fixtureData.shapeType = "circle"
                    fixtureData.radius = shape:getRadius()
                elseif shape:typeOf("PolygonShape") then
                    local result = {}
                    local points = { shape:getPoints() }
                    for i = 1, #points do
                        table.insert(result, utils.round_to_decimals(points[i], 3))
                    end
                    fixtureData.points = result
                    -- elseif shape:typeOf("EdgeShape") then
                    --     fixtureData.shapeType = "edge"
                    --     local x1, y1, x2, y2 = shape:getPoints()
                    --     fixtureData.points = { { x = x1, y = y1 }, { x = x2, y = y2 } }
                else
                    -- Handle other shape types if any
                    fixtureData.shapeType = "unknown"
                end

                if fixture:getUserData() then
                    fixtureData.userData = utils.shallowCopy(fixture:getUserData())
                    fixtureData.sensor = fixture:isSensor()
                    --print(inspect(utils.shallowCopy(fixture:getUserData())))
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
        else
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
                    anchorA = { utils.round_to_decimals(x1, 3), utils.round_to_decimals(y1, 3) },
                    anchorB = { utils.round_to_decimals(x2, 3), utils.round_to_decimals(y2, 3) },
                    collideConnected = joint:getCollideConnected(),
                    properties = {}
                }


                if (jointUserData.scriptmeta) then
                    jointData.scriptmeta = utils.shallowCopy(jointUserData.scriptmeta)
                end

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

function lib.cloneSelection(selectedBodies)
    -- Mapping from original body IDs to cloned body instances
    local clonedBodiesMap = {}

    -- Step 1: Clone Bodies
    for _, originals in ipairs(selectedBodies) do
        local originalBody = originals.body
        local userData     = originalBody:getUserData()
        if userData and userData.thing then
            local originalThing = userData.thing

            -- Generate a new unique ID for the cloned body
            local newID = uuid.generateID()

            -- Clone body properties
            local newBody = love.physics.newBody(world, originalBody:getX() + 50, originalBody:getY() + 50,
                originalBody:getType())
            newBody:setAngle(originalBody:getAngle())
            newBody:setLinearVelocity(originalBody:getLinearVelocity())
            newBody:setAngularVelocity(originalBody:getAngularVelocity())
            newBody:setFixedRotation(originalBody:isFixedRotation())
            newBody:setSleepingAllowed(originalBody:isSleepingAllowed())

            -- Clone shape

            local newShapeList, newVertices = shapes.createShape(originalThing.shapeType, originalThing.radius,
                originalThing.width,
                originalThing.height, originalThing.vertices)


            local oldFixtures = originalBody:getFixtures()



            local ok, offset = fixtures.hasFixturesWithUserDataAtBeginning(oldFixtures)
            if not ok then
                print('some how the userdata fixtures arent at the beginning!')
            end
            if ok and offset > -1 then
                print(ok, offset)
                for i = 1 + offset, #oldFixtures do
                    local oldF = oldFixtures[i]
                    local newFixture = love.physics.newFixture(newBody, newShapeList[i - (offset)], oldF:getDensity())
                    newFixture:setRestitution(oldF:getRestitution())
                    newFixture:setFriction(oldF:getFriction())
                end
                if offset > 0 then
                    -- here we should recreate the special fixtures..
                    for i = 1, offset do
                        local oldF = oldFixtures[i]
                        local shape = oldF:getShape():getPoints()
                        --print(inspect(getCentroidOfFixture(originalBody, oldF)))

                        local newFixture = love.physics.newFixture(newBody, oldF:getShape(), oldF:getDensity())
                        newFixture:setRestitution(oldF:getRestitution())
                        newFixture:setFriction(oldF:getFriction())
                        local oldUD = utils.shallowCopy(oldF:getUserData())
                        oldUD.id = uuid.generateID()
                        newFixture:setUserData(oldUD)
                        newFixture:setSensor(oldF:isSensor())
                        registry.registerSFixture(oldUD.id, newFixture)
                    end
                end
            end


            -- Clone fixture
            --local newFixture = love.physics.newFixture(newBody, newShape, originalThing.fixture:getDensity())
            --newFixture:setRestitution(originalThing.fixture:getRestitution())
            --newFixture:setFriction(originalThing.fixture:getFriction())

            -- Clone user data
            if (originalThing.vertices) then
                if (#originalThing.vertices ~= #newVertices) then
                    utils.trace('vertex count before and after cloning ', #originalThing.vertices, #newVertices)
                end
            end
            local clonedThing = {
                shapeType = originalThing.shapeType,
                radius = originalThing.radius,
                width = originalThing.width,
                height = originalThing.height,
                label = originalThing.label,
                body = newBody,
                shapes = newShapeList,
                vertices = newVertices,
                id = newID
            }
            newBody:setUserData({ thing = clonedThing })

            -- Register the cloned body
            registry.registerBody(newID, newBody)

            -- Store in the map for joint cloning
            clonedBodiesMap[originalThing.id] = clonedThing
        end
    end

    local doneJoints = {}
    -- Step 2: Clone Joints
    for _, originalThing in ipairs(uiState.selectedBodies) do
        local originalBody = originalThing.body
        local joints = originalBody:getJoints()
        for _, originalJoint in ipairs(joints) do
            local ud = originalJoint:getUserData()
            if ud and ud.id then
                if not doneJoints[ud.id] == true then -- make sure we dont do joints twice..
                    local jointType = originalJoint:getType()
                    local handler = jointHandlers[jointType]
                    doneJoints[ud.id] = true
                    if handler and handler.extract then
                        local jointData = handler.extract(originalJoint)
                        -- utils.trace(inspect(jointData))
                        -- Determine the original bodies connected by the joint
                        local bodyA, bodyB = originalJoint:getBodies()
                        local clonedBodyA = clonedBodiesMap[bodyA:getUserData().thing.id]
                        local clonedBodyB = clonedBodiesMap[bodyB:getUserData().thing.id]

                        -- If both bodies are cloned, proceed to clone the joint
                        if clonedBodyA and clonedBodyB then
                            local newJointData = {
                                body1 = clonedBodyA.body,
                                body2 = clonedBodyB.body,
                                jointType = jointType,
                                collideConnected = originalJoint:getCollideConnected(),
                                id = uuid.generateID(),
                                offsetA = { x = ud.offsetA.x, y = ud.offsetA.y },
                                offsetB = { x = ud.offsetB.x, y = ud.offsetB.x }
                            }

                            -- Include all joint-specific properties
                            for key, value in pairs(jointData) do
                                newJointData[key] = value
                            end

                            local newJoint = jointslib.createJoint(newJointData)

                            -- Register the new joint
                            registry.registerJoint(newJointData.id, newJoint)
                        end
                    end
                end
            end
        end
    end

    local result = {}
    for k, v in pairs(clonedBodiesMap) do
        table.insert(result, v)
    end
    return result
    --uiState.selectedBodies = result
end

return lib

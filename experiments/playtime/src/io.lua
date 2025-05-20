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
local state = require 'src.state'

local snap = require 'src.snap'

function lib.reload(data, world, cam)
    lib.load(data, world, cam)
end

local function clearWorld(world)
    for _, body in pairs(world:getBodies()) do
        body:destroy()
    end
    registry.reset()
end

function lib.buildWorld(data, world, cam)
    local idMap = {}
    -- todo is this actually needed, i *think* its a premature optimization, getting ready to load a file into an exitsing situation, button
    -- this isnt really used. so we just might as well just always use the oldid....
    --print(reuseOldIds)
    -- local function getNewId(oldId)
    --     if not reuseOldIds then
    --         if idMap[oldId] == nil then
    --             idMap[oldId] = uuid.generateID()
    --         end
    --         return idMap[oldId]
    --     else
    --         return oldId
    --     end
    -- end
    local function getNewId(oldId)
        return oldId
    end
    -- should we mabe move this out ?
    clearWorld(world)

    snap.resetList()

    if data.camera then
        cam:setTranslation(data.camera.x, data.camera.y)
        cam:setScale(data.camera.scale)
    end

    local recreatedSFixtures = {}
    -- Iterate through saved bodies and recreate them
    for _, bodyData in ipairs(data.bodies) do
        -- Create a new body
        local body = love.physics.newBody(world, bodyData.position[1], bodyData.position[2], bodyData.bodyType)
        body:setAngle(bodyData.angle)
        body:setLinearVelocity(bodyData.linearVelocity[1], bodyData.linearVelocity[2])
        body:setAngularVelocity(bodyData.angularVelocity)
        body:setFixedRotation(bodyData.fixedRotation)
        body:setLinearDamping(bodyData.linearDamping or 0)
        body:setAngularDamping(bodyData.angularDamping or 0)

        local shared = bodyData.sharedFixtureData

        for i = #bodyData.fixtures, 1, -1 do -- doing this backwards keeps order intact
            local fixtureData = bodyData.fixtures[i]
            local shape
            if (fixtureData.radius) then
                --if shared.shapeType == "circle" then
                shape = love.physics.newCircleShape(fixtureData.radius)
            elseif fixtureData.points then
                --elseif shared.shapeType == "polygon" then
                local points = {}
                -- for _, point in ipairs(fixtureData.points) do
                --     table.insert(points, point.x)
                --     table.insert(points, point.y)
                -- end
                for _, point in ipairs(fixtureData.points) do
                    table.insert(points, point)
                end

                local success, err = pcall(function()
                    shape = love.physics.newPolygonShape(unpack(points))
                end)
                if err then
                    logger:info('failed creating a polygonshape, will add a circle instead')
                    shape = nil
                end



                -- elseif fixtureData.shapeType == "edge" then
                --     local x1 = fixtureData.points[1].x
                --     local y1 = fixtureData.points[1].y
                --     local x2 = fixtureData.points[2].x
                --     local y2 = fixtureData.points[2].y
                --     shape = love.physics.newEdgeShape(x1, y1, x2, y2)
            else
                logger:error("Unsupported shape type:", fixtureData.shapeType)
            end


            if shape then
                local fixture = love.physics.newFixture(body, shape, shared.density)
                fixture:setFriction(shared.friction)
                fixture:setRestitution(shared.restitution)
                fixture:setGroupIndex(shared.groupIndex or 0)
                if fixtureData.userData then
                    fixture:setSensor(fixtureData.sensor)
                    local oldUD = utils.shallowCopy(fixtureData.userData)
                    oldUD.id = oldUD.id and getNewId(oldUD.id) or uuid.generateID()

                    fixture:setUserData(oldUD)

                    -- make it recreate the image!
                    if oldUD.extra and oldUD.extra.OMP then
                        oldUD.extra.dirty = true
                    end

                    table.insert(recreatedSFixtures, fixture)


                    registry.registerSFixture(oldUD.id, fixture)
                    --print(inspect(utils.shallowCopy(fixture:getUserData())))
                end
            end
        end

        -- Recreate the 'thing' table
        local thing = {
            id = getNewId(bodyData.id),
            label = bodyData.label,
            shapeType = bodyData.shapeType,
            radius = (bodyData.dims and bodyData.dims.radius) or bodyData.radius,
            width = (bodyData.dims and bodyData.dims.width) or bodyData.width,
            width2 = (bodyData.dims and bodyData.dims.width2) or bodyData.width2,
            width3 = (bodyData.dims and bodyData.dims.width3) or bodyData.width3,
            height = (bodyData.dims and bodyData.dims.height) or bodyData.height,
            height2 = (bodyData.dims and bodyData.dims.height2) or bodyData.height2,
            height3 = (bodyData.dims and bodyData.dims.height3) or bodyData.height3,
            height4 = (bodyData.dims and bodyData.dims.height4) or bodyData.height4,
            body = body,
            mirrorX = bodyData.mirrorX or 1,
            mirrorY = bodyData.mirrorY or 1,
            vertices = bodyData.vertices,
            behaviors = bodyData.behaviors,
            --  shape = body:getFixtures()[1]:getShape(), -- Assuming one fixture per body
            fixture = body:getFixtures()[1], -- this is used in clone.
            -- textures = bodyData.textures or { bgURL = '', bgEnabled = false, bgHex = 'ffffffff' },
            -- zOffset = bodyData.zOffset or 0,
        }

        -- Assign the 'thing' to the body's user data
        body:setUserData({ thing = thing })
        --  print(thing.id, inspect(body:getUserData()))
        registry.registerBody(thing.id, body)
    end

    -- todo now we have all the sfixtures and bodies
    -- only now we can patch up stuff with old ids in extra folder ..

    -- Iterate through saved joints and recreate them
    for _, jointData in ipairs(data.joints) do
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
                logger:error("Unsupported joint type during load:", jointData.type)
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
                registry.registerJoint(ud.id, joint)
            end
        else
            logger:error("Failed to find bodies for joint:", jointData.id)
        end
    end
end

function lib.load(data, world, cam)
    local jsonData, pos, err = json.decode(data, 1, nil)
    if err then
        logger:error("Error decoding JSON:", err)
        return
    end

    -- Verify version
    if jsonData then
        if jsonData.version ~= "1.0" then
            logger:error("Unsupported save version:", jsonData.version)
            return
        end
    else
        logger:error('failed loading json')
        return
    end
    -- Clear existing world
    lib.buildWorld(jsonData, world, cam, reuseOldIds)

    snap.onSceneLoaded()
end

local function needsDimProperty(prop, shape)
    local needsRadius = function(shape)
        return shape == 'triangle' or shape == 'pentagon' or shape == 'hexagon' or
            shape == 'heptagon' or shape == 'octagon' or shape == 'circle'
    end

    if prop == 'radius' then
        return needsRadius(shape)
    elseif prop == 'width' then
        return not needsRadius(shape) and shape ~= 'custom'
    elseif prop == 'height' then
        return not needsRadius(shape) and shape ~= 'custom'
    elseif prop == 'height2' then
        return shape == 'capsule' or shape == 'torso'
    elseif prop == 'width2' then
        return shape == 'trapezium' or shape == 'torso'
    elseif prop == 'height3' or prop == 'height4' then
        return shape == 'torso'
    elseif prop == 'width3' then
        return shape == 'torso'
    end
end


function lib.gatherSaveData(world, camera)
    local saveData = {
        version = "1.0", -- Versioning for future compatibility
        bodies = {},
        joints = {},
        camera = {}
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
                dims = {
                    radius = needsDimProperty('radius', thing.shapeType) and thing.radius or nil,
                    width = needsDimProperty('width', thing.shapeType) and thing.width or nil,
                    width2 = needsDimProperty('width2', thing.shapeType) and thing.width2 or nil,
                    width3 = needsDimProperty('width3', thing.shapeType) and thing.width3 or nil,
                    height = needsDimProperty('height', thing.shapeType) and thing.height or nil,
                    height2 = needsDimProperty('height2', thing.shapeType) and thing.height2 or nil,
                    height3 = needsDimProperty('height3', thing.shapeType) and thing.height3 or nil,
                    height4 = needsDimProperty('height4', thing.shapeType) and thing.height4 or nil,
                },
                --textures = thing.textures,
                -- zOffset = thing.zOffset,
                mirrorX = thing.mirrorX,
                mirrorY = thing.mirrorY,
                --radius = thing.radius,
                vertices = thing.vertices,
                bodyType = body:getType(), -- 'dynamic', 'kinematic', or 'static'
                position = { utils.round_to_decimals(body:getX(), 4), utils.round_to_decimals(body:getY(), 4) },
                angle = utils.round_to_decimals(body:getAngle(), 4),
                linearVelocity = { lvx, lvy },
                angularVelocity = utils.round_to_decimals(body:getAngularVelocity(), 4),
                linearDamping = utils.round_to_decimals(body:getLinearDamping(), 4),
                angularDamping = utils.round_to_decimals(body:getAngularDamping(), 4),
                fixedRotation = body:isFixedRotation(),
                fixtures = {},
                sharedFixtureData = {},
                behaviors = thing.behaviors
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
                    bodyData.sharedFixtureData.groupIndex = first:getGroupIndex()
                    -- todo this shape type name isnt really used anymore...
                    -- can we just delete it ?
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
                    if utils.sanitizeString(fixture:getUserData().label) == 'snap' or fixture:getUserData().subtype == 'snap' then
                        local ud             = fixture:getUserData()

                        ud.extra.fixture     = 'fixture'
                        -- todo cannot reproduce this one yet.. ?Error: src/io.lua:455: attempt to call method 'getUserData' (a nil value)
                        ud.extra.at          = ud.extra.at and ud.extra.at:getUserData().thing.id
                        ud.extra.to          = ud.extra.to and ud.extra.to:getUserData().thing.id
                        fixtureData.userData = utils.deepCopy(ud)
                    else
                        local ud = fixture:getUserData()
                        if ud.extra and ud.extra.type == 'texfixture' or ud.subtype == 'texfixture' then
                            ud.extra.dirty = true
                            if ud.extra.ompImage then ud.extra.ompImage = nil end
                        end
                        if ud.extra and ud.extra.ompImage then
                            ud.extra.dirty = true
                            ud.extra.ompImage = nil
                        end
                        fixtureData.userData = utils.deepCopy(ud)
                    end



                    fixtureData.sensor = fixture:isSensor()
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
            logger:debug('what is up with this joint?')
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
                    logger:error("Unsupported joint type during save:", joint:getType())
                end

                table.insert(saveData.joints, jointData)
            else
                logger:error("Failed to find bodies for joint:", jointID)
            end
        end
    end

    local camx, camy = camera:getTranslation()
    saveData.camera = {
        rotation = camera:getRotation(),
        x = camx,
        y = camy,
        scale = camera:getScale()
    }
    return saveData
end

function lib.save(world, camera, filename)
    -- Serialize the data to JSON
    local saveData = lib.gatherSaveData(world, camera)
    logger:debug(inspect(saveData))
    local jsonData = json.encode(saveData, { indent = true })

    -- Write the JSON data to a file
    local success, message = love.filesystem.write(filename .. '.playtime.json', jsonData)
    if success then
        logger:info("World successfully saved to " .. filename)
        logger:info("file://" .. love.filesystem.getSaveDirectory())
    else
        logger:error("Failed to save world:", message)
    end

    love.system.openURL("file://" .. love.filesystem.getSaveDirectory())
end

function lib.cloneSelection(selectedBodies, world)
    -- Mapping from original body IDs to cloned body instances
    local clonedBodiesMap = {}

    -- mapping from old ids (of bodies and fixtures) to new cloned ids
    local idMapping = {}

    -- Step 1: Clone Bodies
    for _, originals in ipairs(selectedBodies) do
        local originalBody = originals.body
        local userData     = originalBody:getUserData()
        if userData and userData.thing then
            local originalThing = userData.thing

            -- Generate a new unique ID for the cloned body
            local newID = uuid.generateID()
            idMapping[originalThing.id] = newID
            -- Clone body properties
            local newBody = love.physics.newBody(world, originalBody:getX() + 50, originalBody:getY() + 50,
                originalBody:getType())
            newBody:setAngle(originalBody:getAngle())
            newBody:setLinearVelocity(originalBody:getLinearVelocity())
            newBody:setAngularVelocity(originalBody:getAngularVelocity())
            newBody:setFixedRotation(originalBody:isFixedRotation())
            newBody:setSleepingAllowed(originalBody:isSleepingAllowed())
            newBody:setLinearDamping(originalBody:getLinearDamping())
            newBody:setAngularDamping(originalBody:getAngularDamping())
            -- Clone shape
            local settings = {
                radius = originalThing.radius,
                width = originalThing.width,
                width2 = originalThing.width2,
                width3 = originalThing.width3,
                height = originalThing.height,
                height2 = originalThing.height2,
                height3 = originalThing.height3,
                height4 = originalThing.height4,
                optionalVertices = originalThing.vertices,

            }
            local newShapeList, newVertices = shapes.createShape(originalThing.shapeType, settings)


            local oldFixtures = originalBody:getFixtures()



            local ok, offset = fixtures.hasFixturesWithUserDataAtBeginning(oldFixtures)
            if not ok then
                logger:error('some how the userdata fixtures arent at the beginning!')
            end
            if ok and offset > -1 then
                for i = 1 + offset, #oldFixtures do
                    local oldF = oldFixtures[i]
                    local newFixture = love.physics.newFixture(newBody, newShapeList[i - (offset)], oldF:getDensity())
                    newFixture:setRestitution(oldF:getRestitution())
                    newFixture:setFriction(oldF:getFriction())
                    newFixture:setGroupIndex(oldF:getGroupIndex())
                end
                if offset > 0 then
                    -- here we should recreate the special fixtures..
                    for i = 1, offset do
                        local oldF = oldFixtures[i]
                        local shape = oldF:getShape():getPoints()


                        local newFixture = love.physics.newFixture(newBody, oldF:getShape(), oldF:getDensity())
                        newFixture:setRestitution(oldF:getRestitution())
                        newFixture:setFriction(oldF:getFriction())
                        newFixture:setGroupIndex(oldF:getGroupIndex())
                        local oldUD = utils.deepCopy(oldF:getUserData())
                        local oldid = oldUD.id

                        oldUD.id = uuid.generateID()
                        idMapping[oldid] = oldUD.id
                        if utils.sanitizeString(oldUD.label) == 'snap' or oldUD.subtype == 'snap' then
                            oldUD.extra.at = nil
                            oldUD.extra.to = nil
                            oldUD.extra.fixture = nil
                        end

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
                width2 = (originalThing.width2 or 1),
                width3 = originalThing.width3,
                height = originalThing.height,
                height2 = originalThing.height2,
                height3 = originalThing.height3,
                height4 = originalThing.height4,
                label = originalThing.label,
                mirrorX = originalThing.mirrorX,
                mirrorY = originalThing.mirrorY,
                behaviors = originalThing.behaviors,
                body = newBody,
                shapes = newShapeList,
                vertices = newVertices,
                --textures = originalThing.textures,
                --zOffset = originalThing.zOffset,
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
    for _, originalThing in ipairs(state.selection.selectedBodies) do
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
                                offsetB = { x = ud.offsetB.x, y = ud.offsetB.y }
                            }
                            idMapping[ud.id] = newJointData.id
                            -- Include all joint-specific properties
                            for key, value in pairs(jointData) do
                                newJointData[key] = value
                            end
                            local limitsEnabled = originalJoint:areLimitsEnabled()
                            local lower, upper = originalJoint:getLimits()
                            local oldRef = originalJoint:getReferenceAngle()
                            local newJoint = jointslib.createJoint(newJointData)
                            local newRef = originalJoint:getReferenceAngle()
                            --  logger:info(oldRef, newRef)
                            newJoint:setLimits(lower, upper)
                            --newJoint:setUpperLimit(upper)
                            --newJoint:setLowerLimit(lower)
                            newJoint:setLimitsEnabled(limitsEnabled)

                            if ud.scriptmeta then
                                local newud = newJoint:getUserData()
                                newud.scriptmeta = utils.shallowCopy(ud.scriptmeta)
                                newJoint:setUserData(newud)
                                if ud.scriptmeta.type and ud.scriptmeta.type == 'snap' then
                                    snap.addSnapJoint(newJoint)
                                end
                            end
                            -- Register the new joint
                            registry.registerJoint(newJointData.id, newJoint)
                        end
                    end
                end
            end
        end
    end

    -- at this point everything that is cloned is added into the world
    -- logger:inspect(idMapping)
    -- now we need to figure out if i have any of the connected-texture fixtures with ids in their userdata that needs updating
    for k, v in pairs(clonedBodiesMap) do
        local fixtures = v.body:getFixtures()
        for j = 1, #fixtures do
            local fixture = fixtures[j]
            local ud = fixture:getUserData()
            local oldUD = utils.deepCopy(ud)
            if oldUD and oldUD.extra and oldUD.extra.nodes then
                for ni = 1, #oldUD.extra.nodes do
                    oldUD.extra.nodes[ni].id = idMapping[oldUD.extra.nodes[ni].id]
                end
                fixture:setUserData(oldUD)
            end
        end
    end




    local result = {}
    for k, v in pairs(clonedBodiesMap) do
        table.insert(result, v)
    end
    return result
    --state.selection.selectedBodies = result
end

return lib

-- object-manager.lua
local lib = {}
local shapes = require 'src.shapes'
local uuid = require 'src.uuid'
local registry = require 'src.registry'
local joints = require 'src.joints'
local jointHandlers = require 'src.joint-handlers'
local inspect = require 'vendor.inspect'
local utils = require 'src.utils'
-- Helper function to create and configure a physics body with shapes
local function createThing(shapeType, x, y, bodyType, radius, width, height, label, optionalVertices)
    -- Initialize default values
    bodyType = bodyType or 'dynamic'
    radius = radius or 20         -- Default radius for circular shapes
    width = width or radius * 2   -- Default width for polygonal shapes
    height = height or radius * 2 -- Default height for polygonal shapes
    label = label or ""           -- Default label

    -- Create the physics body at the specified world coordinates
    local body = love.physics.newBody(world, x, y, bodyType)

    local shapeList, vertices = shapes.createShape(shapeType, radius, width, height, optionalVertices)

    if not shapeList then
        print("Failed to create shapes for:", shapeType)
        return nil
    end

    -- Attach fixtures to the body for each shape
    for _, shape in ipairs(shapeList) do
        local fixture = love.physics.newFixture(body, shape, 1)
        fixture:setRestitution(0.3) -- Set bounciness
    end

    -- Configure body properties
    body:setAwake(true)

    -- Create the 'thing' table to store properties
    local thing = {
        shapeType = shapeType,
        radius = radius,
        width = width,
        height = height,
        label = label,
        body = body,
        shapes = shapeList,
        vertices = vertices, -- Store vertices if needed
        id = uuid.generateID(),
    }

    -- Set user data for easy access
    body:setUserData({ thing = thing })

    -- Register the body in the registry
    registry.registerBody(thing.id, body)

    return thing
end

function lib.startSpawn(shapeType, wx, wy)
    local radius = tonumber(uiState.lastUsedRadius) or 10
    local width = tonumber(uiState.lastUsedWidth) or radius * 2   -- Default width for polygons
    local height = tonumber(uiState.lastUsedHeight) or radius * 2 -- Default height for polygons

    local bodyType = uiState.nextType
    local thing = createThing(shapeType, wx, wy, bodyType, radius, width, height, '')

    if not thing then
        print("startSpawn: Failed to create thing.")
        return
    end

    uiState.draggingObj = thing
    uiState.offsetDragging = { 0, 0 }
end

function lib.addThing(shapeType, x, y, bodyType, radius, width, height, label, optionalVertices)
    local thing = createThing(shapeType, x, y, bodyType, radius, width, height, label, optionalVertices)

    if not thing then
        print("addThing: Failed to create thing.")
        return nil
    end

    return thing
end

function lib.recreateThingFromBody(body, newSettings)
    if body:isDestroyed() then
        print("The body is already destroyed.")
        return nil
    end
    local userData = body:getUserData()
    local thing = userData and userData.thing
    -- Extract current properties
    local x, y = body:getPosition()
    local angle = body:getAngle()
    local velocityX, velocityY = body:getLinearVelocity()
    local angularVelocity = body:getAngularVelocity()
    local bodyType = newSettings.bodyType or body:getType()
    local firstFixture = body:getFixtures()[1]
    local restitution = firstFixture:getRestitution()
    local friction = firstFixture:getFriction()
    local fixedRotation = body:isFixedRotation() -- Capture fixed angle state
    -- Get the original `thing` for shape info


    local jointData = joints.extractJoints(body)
    -- Destroy the old body
    body:destroy()

    -- Create new body
    local newBody = love.physics.newBody(world, x, y, bodyType)
    newBody:setAngle(angle)
    newBody:setLinearVelocity(velocityX, velocityY)
    newBody:setAngularVelocity(angularVelocity)
    newBody:setFixedRotation(fixedRotation) -- Reapply fixed rotation
    -- Create a new shape

    local shapeList, newVertices = shapes.createShape(
        newSettings.shapeType or thing.shapeType,
        newSettings.radius or thing.radius,
        newSettings.width or thing.width,
        newSettings.height or thing.height,
        newSettings.optionalVertices
    )

    for _, shape in ipairs(shapeList) do
        local fixture = love.physics.newFixture(newBody, shape, 1)
        fixture:setRestitution(newSettings.restitution or restitution)
        fixture:setFriction(newSettings.friction or friction)
    end



    -- Update the `thing` table
    thing.label = thing.label
    thing.body = newBody
    thing.shapes = shapeList

    thing.radius = newSettings.radius or thing.radius
    thing.width = newSettings.width or thing.width
    thing.height = newSettings.height or thing.height
    thing.id = thing.id or uuid.generateID()
    thing.vertices = newVertices
    registry.registerBody(thing.id, thing.body)
    newBody:setUserData({ thing = thing })

    joints.reattachJoints(jointData, newBody)

    return thing
end

function lib.destroyBody(body)
    local thing = body:getUserData().thing
    local joints = body:getJoints()
    for i = 1, #joints do
        local ud = joints[i]:getUserData()
        if ud then
            registry.unregisterJoint(ud.id)
            joints[i]:destroy()
        end
    end
    registry.unregisterBody(thing.id)
    body:destroy()
end

-- Helper function to collect all connected bodies
local function collectBodies(thing, collected)
    collected = collected or {}
    if not thing or not thing.body or collected[thing.id] then
        return collected
    end
    collected[thing.id] = thing.body
    for _, joint in ipairs(thing.body:getJoints()) do
        local bodyA, bodyB = joint:getBodies()
        local otherBody = (bodyA == thing.body) and bodyB or bodyA
        local otherThing = otherBody:getUserData() and otherBody:getUserData().thing
        if otherThing then
            collectBodies(otherThing, collected)
        end
    end
    return collected
end
-- -- Rotates a point (x, y) by angle radians
-- local function rotatePoint(x, y, angle)
--     local cosA = math.cos(angle)
--     local sinA = math.sin(angle)
--     return x * cosA - y * sinA, x * sinA + y * cosA
-- end
-- Function to calculate centroid
local function calculateCentroid(thing)
    local bodies = collectBodies(thing)
    local totalMass = 0
    local sumX, sumY = 0, 0
    for id, body in pairs(bodies) do
        local mass = body:getMass()
        local x, y = body:getPosition()
        sumX = sumX + x * mass
        sumY = sumY + y * mass
        totalMass = totalMass + mass
    end
    if totalMass == 0 then
        return 0, 0 -- Avoid division by zero
    end
    return sumX / totalMass, sumY / totalMass
end

function lib.flipThing(thing, axis, recursive)
    -- print('************* Flipping Thing *************')

    -- Validate input
    if not thing or not thing.body then
        print("flipThing: Invalid 'thing' provided.")
        return
    end

    if axis ~= 'x' and axis ~= 'y' then
        print("flipThing: Invalid axis. Use 'x' or 'y'.")
        return
    end

    -- Tables to keep track of processed bodies and joints
    local processedBodies = {}
    local processedJoints = {}
    local toBeProcessedJoints = {}
    local centroidX, centroidY = calculateCentroid(thing)


    -- Phase 1: Flip All Bodies
    local function flipBody(currentThing)
        --print('called flipbody')
        local currentBody = currentThing.body
        if not currentBody or processedBodies[currentThing.id] then
            return
        end

        processedBodies[currentThing.id] = true

        -- Get current position and angle
        local currentX, currentY = currentBody:getPosition()
        local currentAngle = currentBody:getAngle()

        -- Calculate relative position to centroid
        local relX = currentX - centroidX
        local relY = currentY - centroidY

        -- Determine new relative position based on flip axis
        local newRelX, newRelY
        if axis == 'x' then
            newRelX = -relX
            newRelY = relY
        elseif axis == 'y' then
            newRelX = relX
            newRelY = -relY
        end
        -- Calculate new absolute position
        local newX = centroidX + newRelX
        local newY = centroidY + newRelY
        local newAngle
        if axis == 'x' then
            newAngle = -currentAngle
        elseif axis == 'y' then
            newAngle = -currentAngle
        end

        -- Update body's position and angle
        currentThing.body:setPosition(newX, newY)
        currentThing.body:setAngle(newAngle)


        if currentThing.vertices then
            --print('jojjo!')
            local flippedVertices = utils.shallowCopy(currentThing.vertices)
            for i = 1, #currentThing.vertices, 2 do
                if axis == 'x' then
                    flippedVertices[i] = -flippedVertices[i]         -- Invert X coordinate
                elseif axis == 'y' then
                    flippedVertices[i + 1] = -flippedVertices[i + 1] -- Invert Y coordinate
                end
            end
            currentThing.vertices = flippedVertices
        end

        -- Flip each fixture's shape
        for _, fixture in ipairs(currentBody:getFixtures()) do
            local shape = fixture:getShape()
            if shape:typeOf("PolygonShape") then
                local points = { shape:getPoints() }
                for i = 1, #points, 2 do
                    if axis == 'x' then
                        points[i] = -points[i]         -- Invert X coordinate
                    elseif axis == 'y' then
                        points[i + 1] = -points[i + 1] -- Invert Y coordinate
                    end
                end
                -- currentThing.vertices = points;
                -- Create a new shape with flipped vertices
                local success, newShape = pcall(love.physics.newPolygonShape, unpack(points))
                if not success then
                    print("flipThing: Failed to create new PolygonShape:", newShape)
                else
                    -- Preserve fixture properties
                    local density = fixture:getDensity()
                    local friction = fixture:getFriction()
                    local restitution = fixture:getRestitution()

                    -- Create a new fixture and destroy the old one
                    local newFixture = love.physics.newFixture(currentBody, newShape, density)
                    newFixture:setFriction(friction)
                    newFixture:setRestitution(restitution)
                    fixture:destroy()
                end
            elseif shape:typeOf("CircleShape") then
                -- No need to flip circle shapes beyond position
                -- Circle radius remains the same
                -- If the circle has user data affecting orientation, handle it here
            end
        end

        -- Determine new angle based on flip axis

        -- If recursive, flip connected bodies first
        if recursive then
            for _, joint in ipairs(currentBody:getJoints()) do
                local jointUserData = joint:getUserData()
                if not jointUserData or not jointUserData.id then
                    print("flipThing: Joint without valid user data encountered.")
                    goto continue
                end

                toBeProcessedJoints[jointUserData.id] = joint
                -- Determine the other body connected by the joint
                local bodyA, bodyB = joint:getBodies()
                local otherBody = (bodyA == currentBody) and bodyB or bodyA
                local otherThing = otherBody:getUserData() and otherBody:getUserData().thing

                if not otherThing then
                    print("flipThing: Connected joint's other body is invalid.")
                    goto continue
                end

                -- Recursively flip the connected body
                flipBody(otherThing)

                ::continue::
            end
        end
    end

    -- Phase 2: Flip All Joints
    local function flipJoints()
        for jointID, joint in pairs(toBeProcessedJoints) do
            local jointType = joint:getType()
            local jointUserData = joint:getUserData()

            if not jointUserData or not jointUserData.id then
                print("flipThing: Joint without valid user data encountered.")
                goto continue
            end

            if processedJoints[jointUserData.id] then
                goto continue
            end
            processedJoints[jointUserData.id] = true

            -- Extract joint data using the handler
            local handler = jointHandlers[jointType]
            if not handler or not handler.extract then
                print("flipThing: No handler found for joint type:", jointType)
                goto continue
            end
            local jointData = handler.extract(joint)

            -- Determine the connected bodies
            local bodyA, bodyB = joint:getBodies()
            local thingA = bodyA:getUserData() and bodyA:getUserData().thing
            local thingB = bodyB:getUserData() and bodyB:getUserData().thing

            if not thingA or not thingB then
                print("flipThing: One or both connected things are invalid.")
                goto continue
            end

            local offsetA = jointUserData.offsetA
            local offsetB = jointUserData.offsetB
            --print('before', inspect(offsetA), inspect(offsetB))
            if axis == 'x' then
                offsetA.x = -offsetA.x
                offsetB.x = -offsetB.x
            elseif axis == 'y' then
                offsetA.y = -offsetA.y
                offsetB.y = -offsetB.y
            end


            joints.recreateJoint(joint, { offsetA = offsetA, offsetB = offsetB })

            ::continue::
        end
    end

    -- Phase 1: Flip All Bodies Recursively
    flipBody(thing)

    -- Phase 2: Flip All Joints
    flipJoints()

    --print('************* Flip Completed *************')
    return thing
end

return lib

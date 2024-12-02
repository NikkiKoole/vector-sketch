local lib = {}
local shapes = require 'src.shapes'
local uuid = require 'src.uuid'
local registry = require 'src.registry'
local joint = require 'src.joints'
local jointHandlers = require 'src.joint-handlers'
local function generateID()
    return uuid.uuid()
end

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
        id = generateID(),
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


    local jointData = joint.extractJoints(body)
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
    thing.id = thing.id or generateID()
    thing.vertices = newVertices
    registry.registerBody(thing.id, thing.body)
    newBody:setUserData({ thing = thing })

    joint.reattachJoints(jointData, newBody)

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

-- Function to flip a body and its attached joints
function lib.flipThing(thing, axis)
    -- Validate input
    if not thing or not thing.body then
        print("flipThing: Invalid 'thing' provided.")
        return
    end

    if axis ~= 'x' and axis ~= 'y' then
        print("flipThing: Invalid axis. Use 'x' or 'y'.")
        return
    end

    local body = thing.body
    local currentX, currentY = body:getPosition()
    local currentAngle = body:getAngle()

    -- Determine new position based on flip axis
    local newX, newY
    if axis == 'x' then
        newX = -currentX
        newY = currentY
    elseif axis == 'y' then
        newX = currentX
        newY = -currentY
    end

    -- Determine new angle based on flip axis
    local newAngle
    if axis == 'x' then
        newAngle = -currentAngle
    elseif axis == 'y' then
        newAngle = math.pi - currentAngle
    end

    -- Update body's position and angle
    body:setPosition(newX, newY)
    body:setAngle(newAngle)

    -- Flip each fixture's shape
    for _, fixture in ipairs(body:getFixtures()) do
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
            -- Destroy and recreate the shape with flipped vertices
            --fixture:destroy()
            local newShape = love.physics.newPolygonShape(unpack(points))
            local newfixture = love.physics.newFixture(body, newShape, fixture:getDensity())
            -- body:createFixture(newShape, fixture:getDensity())
            newfixture:setFriction(fixture:getFriction())
            newfixture:setRestitution(fixture:getRestitution())
            fixture:destroy()
        elseif shape:typeOf("CircleShape") then
            -- No need to flip circle shapes beyond position
            -- Circle radius remains the same
            -- If the circle has user data affecting orientation, handle it here
        end
    end

    -- Update attached joints
    for _, joint in ipairs(body:getJoints()) do
        local jointType = joint:getType()
        local jointUserData = joint:getUserData()
        if not jointUserData or not jointUserData.id then
            print("flipThing: Joint without valid user data encountered.")
            goto continue
        end

        -- Extract joint data
        local jointData = jointHandlers[jointType].extract(joint)
        if not jointData then
            print("flipThing: Failed to extract joint data for joint type:", jointType)
            goto continue
        end

        -- Determine the other body connected by the joint
        local bodyA, bodyB = joint:getBodies()
        local otherBody = (bodyA == body) and bodyB or bodyA
        local otherThing = otherBody:getUserData() and otherBody:getUserData().thing

        if not otherThing then
            print("flipThing: Connected joint's other body is invalid.")
            goto continue
        end

        -- Calculate new anchor points based on flip axis

        local anchorA = { joint:getAnchorA() }
        local anchorB = { joint:getAnchorB() }

        if axis == 'x' then
            anchorA[1] = -anchorA[1]
            anchorB[1] = -anchorB[1]
        elseif axis == 'y' then
            anchorA[2] = -anchorA[2]
            anchorB[2] = -anchorB[2]
        end

        -- Prepare new joint data with updated anchors
        local newJointData = {
            body1 = body,
            body2 = otherBody,
            jointType = jointType,
            collideConnected = joint:getCollideConnected(),
            id = jointUserData.id, -- Preserve joint ID
            anchorA = { anchorA[1], anchorA[2] },
            anchorB = { anchorB[1], anchorB[2] },
            properties = jointData,
        }

        -- Destroy the old joint
        joint:destroy()

        -- Recreate the joint with flipped anchor points
        local newJoint = jointHandlers.createJoint(newJointData)
        if newJoint then
            print("flipThing: Joint flipped successfully:", jointType, jointUserData.id)
        else
            print("flipThing: Failed to recreate joint:", jointType, jointUserData.id)
        end

        ::continue::
    end
end

return lib

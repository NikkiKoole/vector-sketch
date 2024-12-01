local lib = {}
local shapes = require 'src.shapes'
local uuid = require 'src.uuid'
local registry = require 'src.registry'
local joint = require 'src.joints'

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

    local bodyType = uiState.bodyTypeOfNextSpawn
    local thing = createThing(shapeType, wx, wy, bodyType, radius, width, height, '')

    if not thing then
        print("startSpawn: Failed to create thing.")
        return
    end

    uiState.currentlyDraggingObject = thing
    uiState.offsetForCurrentlyDragging = { 0, 0 }
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

return lib

-- object-manager.lua
local lib = {}
local shapes = require 'src.shapes'
local uuid = require 'src.uuid'
local registry = require 'src.registry'
local joints = require 'src.joints'
local jointHandlers = require 'src.joint-handlers'
local inspect = require 'vendor.inspect'
local utils = require 'src.utils'
local mathutils = require 'src.math-utils'
local fixtures = require 'src.fixtures'
local snap = require 'src.snap'


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

-- Helper function to create and configure a physics body with shapes
local function createThing(shapeType, conf)
    --local function createThing(shapeType, x, y, bodyType, radius, width, width2, height, label, optionalVertices)
    -- Initialize default values
    bodyType = bodyType or 'dynamic'
    -- radius = radius or 20         -- Default radius for circular shapes
    -- width = width or radius * 2   -- Default width for polygonal shapes
    -- width2 = width2 or radius * 2 -- Default width for polygonal shapes
    -- height = height or radius * 2 -- Default height for polygonal shapes
    --label = label or "" -- Default label

    -- Create the physics body at the specified world coordinates
    local body = love.physics.newBody(world, conf.x or 0, conf.y or 0, bodyType)

    local settings = {
        radius = conf.radius,
        width = conf.width,
        width2 = conf.width2,
        width3 = conf.width3,
        height = conf.height,
        height2 = conf.height2,
        height3 = conf.height3,
        height4 = conf.height4,
        optionalVertices = conf.vertices or nil, --optionalVertices
        label = conf.label or ''
    }
    local shapeList, vertices = shapes.createShape(shapeType, settings)

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
        radius = settings.radius,
        width = settings.width,
        width2 = settings.width2,
        width3 = settings.width3,
        height = settings.height,
        height2 = settings.height2,
        height3 = settings.height3,
        height4 = settings.height4,
        label = settings.label,
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
    local width = tonumber(uiState.lastUsedWidth) or radius * 2     -- Default width for polygons
    local width2 = tonumber(uiState.lastUsedWidth2) or radius * 2.3 -- Default width for polygons
    local width3 = tonumber(uiState.lastUsedWidth3) or radius * 2.3 -- Default width for polygons

    local height = tonumber(uiState.lastUsedHeight) or radius * 2   -- Default height for polygons
    local height2 = tonumber(uiState.lastUsedHeight2) or radius * 2 -- Default height for polygons
    local height3 = tonumber(uiState.lastUsedHeight3) or radius * 2 -- Default height for polygons

    local height4 = tonumber(uiState.lastUsedHeight4) or radius * 2 -- Default height for polygons


    local bodyType = uiState.nextType
    local settings = {
        x = wx,
        y = wy,
        bodyType = bodyType,
        radius = radius,
        width = width,
        width2 = width2,
        width3 = width3,
        height = height,
        height2 = height2,
        height3 = height3,
        height4 = height4,
        label = ''
    }
    print(inspect(settings))
    local thing = createThing(shapeType, settings)

    if not thing then
        print("startSpawn: Failed to create thing.")
        return
    end

    uiState.draggingObj = thing
    uiState.offsetDragging = { 0, 0 }
end

function lib.addThing(shapeType, settings)
    --function lib.addThing(shapeType, x, y, bodyType, radius, width, width2, height, label, optionalVertices)
    --local thing = createThing(shapeType, x, y, bodyType, radius, width, width2, height, label, optionalVertices)
    --  print(inspect(settings))
    local thing = createThing(shapeType, settings)
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

    local oldFixtures = body:getFixtures()

    local jointData = joints.extractJoints(body)

    -- Create new body
    local newBody = love.physics.newBody(world, x, y, bodyType)
    newBody:setAngle(angle)
    newBody:setLinearVelocity(velocityX, velocityY)
    newBody:setAngularVelocity(angularVelocity)
    newBody:setFixedRotation(fixedRotation) -- Reapply fixed rotation
    -- Create a new shape


    local settings = {
        radius = newSettings.radius or thing.radius,
        width = newSettings.width or thing.width,
        width2 = newSettings.width2 or thing.width2,
        width3 = newSettings.width3 or thing.width3,
        height = newSettings.height or thing.height,
        height2 = newSettings.height2 or thing.height2,
        height3 = newSettings.height3 or thing.height3,
        height4 = newSettings.height4 or thing.height4,
        optionalVertices = newSettings.optionalVertices
    }
    local shapeList, newVertices = shapes.createShape(
        newSettings.shapeType or thing.shapeType,
        settings
    )



    local ok, offset = fixtures.hasFixturesWithUserDataAtBeginning(oldFixtures)

    for _, shape in ipairs(shapeList) do
        local fixture = love.physics.newFixture(newBody, shape, 1)
        fixture:setRestitution(newSettings.restitution or restitution)
        fixture:setFriction(newSettings.friction or friction)
    end

    if offset > 0 then
        -- here we should recreate the special fixtures..
        for i = 1, offset do
            local oldF = oldFixtures[i]
            local points = { oldF:getShape():getPoints() }
            -- so maybe we can figure out between which 2 vertices i am, or closest too
            -- and then reposition myself in the same way to those 2 vertices.
            --
            -- goal would be to for example remain in place when growing a leg.. ?
            -- oh maybe its better to also use fixtures for this behaviour but not snap, but boneconnect or something.
            --
            --print(inspect(fixtures/fixturesgetCentroidOfFixture(originalBody, oldF)))
            local abs = oldF:getShape()
            local centerX, centerY = mathutils.getCenterOfPoints(points)
            if (thing.vertices) then
                local params = mathutils.closestEdgeParams(centerX, centerY, thing.vertices)
                --     --  print(inspect(params))
                local new_px, new_py = mathutils.repositionPointClosestEdge(params, newVertices)

                --     --local cx, cy = mathutils.computeCentroid(uiState.selectedObj.vertices)
                --     --print(cx, cy, centerX, centerY)
                --     local allFixtures = body:getUserData().thing.body:getFixtures()
                --     local offX, offY = getCenterOfShapeFixtures(allFixtures)

                --     -- local weights = meanValueCoordinates(centerX, centerY, thing.vertices)
                --     -- local new_px, new_py = repositionPoint(weights, newVertices)
                ---local edgeIndex, t = findEdgeAndLerpParam(centerX, centerY, thing.vertices)
                --     --print(edgeIndex, t)
                --local new_px, new_py = lerpOnEdge(edgeIndex, t, newVertices)

                local rel = mathutils.makePolygonRelativeToCenter(points, centerX, centerY)
                abs = love.physics.newPolygonShape(mathutils.makePolygonAbsolute(rel, new_px, new_py))
                --print('jo!')

                --     --print(centerX, centerY, new_px, new_py)
            end
            --local relativePoints = makePolygonRelativeToCenter(points, centerX, centerY)
            -- local newShape = makePolygonAbsolute(relativePoints, localX, localY)



            local newFixture = love.physics.newFixture(newBody, abs, oldF:getDensity())
            newFixture:setRestitution(oldF:getRestitution())
            newFixture:setFriction(oldF:getFriction())
            newFixture:setUserData(utils.shallowCopy(oldF:getUserData()))

            registry.registerSFixture(oldF:getUserData().id, newFixture)
            snap.rebuildSnapFixtures(registry.sfixtures)
        end
    end



    -- Update the `thing` table
    thing.label = thing.label
    thing.body = newBody
    thing.shapes = shapeList

    thing.radius = newSettings.radius or thing.radius
    thing.width = newSettings.width or thing.width
    thing.width2 = newSettings.width2 or thing.width2
    thing.width3 = newSettings.width3 or thing.width3
    thing.height = newSettings.height or thing.height
    thing.height2 = newSettings.height2 or thing.height2
    thing.height3 = newSettings.height3 or thing.height3
    thing.height4 = newSettings.height4 or thing.height4
    thing.id = thing.id or uuid.generateID()
    thing.vertices = newVertices
    registry.registerBody(thing.id, thing.body)
    newBody:setUserData({ thing = thing })

    joints.reattachJoints(jointData, newBody)

    snap.maybeUpdateSnapJoints(jointData)

    -- Destroy the old body
    body:destroy()

    return thing
end

function lib.destroyBody(body)
    local thing = body:getUserData().thing
    local bjoints = body:getJoints()
    for i = 1, #joints do
        local ud = bjoints[i]:getUserData()
        if ud and ud.id then
            registry.unregisterJoint(ud.id)
            bjoints[i]:destroy()
        end
    end
    local bfixtures = body:getFixtures()
    for i = 1, #bfixtures do
        local ud = bfixtures[i]:getUserData()
        if ud and ud.id then
            registry.unregisterSFixture(ud.id)
            bfixtures[i]:destroy()
        end
    end
    registry.unregisterBody(thing.id)
    body:destroy()
end

function lib.flipThing(thing, axis, recursive)
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
    local centroidX, centroidY = thing.body:getPosition()

    -- if thing.vertices then
    -- local cx,cy = mathutils.getCenterOfPoints(thing.vertices)
    -- centroidX =  cx
    -- centroidY = cy
    -- end

    --print('calculating centroid')
    -- Phase 1: Flip All Bodies
    local function flipBody(currentThing)
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
        print(currentThing.body, newX, newY)
        -- Update body's position and angle
        currentThing.body:setPosition(newX, newY)
        currentThing.body:setAngle(newAngle)


        if currentThing.vertices then
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
        -- for _, fixture in ipairs(currentBody:getFixtures()) do
        --     print(_, fixture:getUserData() ~= nil)
        -- end
        local fixtures = currentBody:getFixtures()
        -- if i do this backwards the fixtures end up being in the same order... !!
        for i = #fixtures, 1, -1 do
            -- for _, fixture in ipairs(currentBody:getFixtures()) do
            local fixture = fixtures[i]
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
                    if (fixture:getUserData()) then
                        newFixture:setUserData(utils.deepCopy(fixture:getUserData()))
                        registry.registerSFixture(fixture:getUserData().id, newFixture)
                        snap.maybeUpdateSFixture(newFixture:getUserData().id)
                    end


                    fixture:destroy()
                end
            elseif shape:typeOf("CircleShape") then
                -- No need to flip circle shapes beyond position
                -- Circle radius remains the same
                -- If the circle has user data affecting orientation, handle it here
            end
        end
        -- for _, fixture in ipairs(currentBody:getFixtures()) do
        --     print(_, fixture:getUserData() ~= nil)
        -- end
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

            local id = joint:getUserData().id
            joints.recreateJoint(joint, { offsetA = offsetA, offsetB = offsetB })
            -- print(registry.getJointByID(id):isDestroyed())

            snap.maybeUpdateSnapJointWithId(id)
            ::continue::
        end
    end

    -- Phase 1: Flip All Bodies Recursively
    flipBody(thing)

    -- Phase 2: Flip All Joints
    flipJoints()

    -- snap.rebuildSnapFixtures(registry.sfixtures)
    --print('************* Flip Completed *************')
    return thing
end

return lib

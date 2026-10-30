-- object-manager.lua
local lib = {}
local logger = require 'src.logger'
local shapes = require 'src.shapes'
local uuid = require 'src.uuid'
local registry = require 'src.registry'
local joints = require 'src.joints'
local jointHandlers = require 'src.joint-handlers'
local utils = require 'src.utils'
local mathutils = require 'src.math-utils'
local fixtures = require 'src.fixtures'
local state = require 'src.state'
local JT = require('src.joint-types')
local BT = require('src.body-types')
local subtypes = require('src.subtypes')

-- Helper function to create and configure a physics body with shapes
local function createThing(shapeType, conf)
    --local function createThing(shapeType, x, y, bodyType, radius, width, width2, height, label, optionalVertices)
    -- Initialize default values
    local bodyType = conf.bodyType or BT.DYNAMIC

    -- Create the physics body at the specified world coordinates
    local body = love.physics.newBody(state.physicsWorld, conf.x or 0, conf.y or 0, bodyType)

    local settings = shapes.copyDims(conf, { optionalVertices = conf.vertices })
    local shapeList, vertices = shapes.createShape(shapeType, settings)

    if not shapeList then
        logger:error("Failed to create shapes for:", shapeType)
        return nil
    end

    -- Attach fixtures to the body for each shape
    for _, shape in ipairs(shapeList) do
        local success, newFixture = pcall(love.physics.newFixture, body, shape, 1)
        if success then
            newFixture:setRestitution(0.3) -- Set bounciness
        else
            logger:error('this is bad' .. newFixture)
        end
    end

    -- Configure body properties
    body:setAwake(true)

    -- Create the 'thing' table to store properties
    local thing = {
        shapeType = shapeType,
        label = conf.label or '',
        mirrorX = conf.mirrorX or 1,
        mirrorY = conf.mirrorY or 1,
        body = body,
        shapes = shapeList,
        vertices = vertices, -- Store vertices if needed
        -- textures = { bgURL = '', bgEnabled = false, bgHex = 'ffffffff' },
        behaviors = conf.behaviors,
        -- NOTE: z-order lives on sfixture extra.zOffset, not on the thing
        id = uuid.generateID(),
    }
    shapes.copyDims(settings, thing)

    -- Set user data for easy access
    body:setUserData({ thing = thing })

    -- Register the body in the registry
    registry.registerBody(thing.id, body)

    return thing
end

function lib.startSpawn(shapeType, wx, wy)
    local ep = state.editorPreferences
    local radius = tonumber(ep.lastUsedRadius) or 10
    local width = tonumber(ep.lastUsedWidth) or radius * 2     -- Default width for polygons
    local width2 = tonumber(ep.lastUsedWidth2) or radius * 2.3 -- Default width for polygons
    local width3 = tonumber(ep.lastUsedWidth3) or radius * 2.3 -- Default width for polygons

    local height = tonumber(ep.lastUsedHeight) or radius * 2   -- Default height for polygons
    local height2 = tonumber(ep.lastUsedHeight2) or radius * 2 -- Default height for polygons
    local height3 = tonumber(ep.lastUsedHeight3) or radius * 2 -- Default height for polygons

    local height4 = tonumber(ep.lastUsedHeight4) or radius * 2 -- Default height for polygons

    local bodyType = state.editorPreferences.nextType
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

    local thing = createThing(shapeType, settings)

    if not thing then
        logger:info("startSpawn: Failed to create thing.")
        return
    end

    state.interaction.draggingObj = thing
    state.interaction.offsetDragging = { 0, 0 }
end

-- Create a physics body+shape and register it.
-- settings: {x, y, bodyType, width, height, radius, label,
--   width2, width3, height2, height3, height4,  -- extra dims for complex shapes
--   vertices, mirrorX, mirrorY, behaviors, shape8URL, density}
function lib.addThing(shapeType, settings)
    local thing = createThing(shapeType, settings)
    if not thing then
        logger:error("addThing: Failed to create thing.")
        return nil
    end

    return thing
end

-- this one is called when the shape of the body changes, thus, its kinda safe to make weird changes to joints too.
function lib.recreateThingFromBody(body, newSettings)
    if body:isDestroyed() then
        logger:error("The body is already destroyed.")
        return nil
    end
    local thing = utils.thingOf(body) -- Extract current properties

    local x, y = body:getPosition()
    local angle = body:getAngle()
    local velocityX, velocityY = body:getLinearVelocity()
    local angularVelocity = body:getAngularVelocity()
    local bodyType = newSettings.bodyType or body:getType()
    -- Read restitution/friction from the first COLLISION fixture (nil
    -- userData). getFixtures()[1] is a sensor sfixture on bodies that carry
    -- them (ordering invariant), which silently reset these to defaults.
    local firstFixture = body:getFixtures()[1]
    for _, fixture in ipairs(body:getFixtures()) do
        if fixture:getUserData() == nil then
            firstFixture = fixture
            break
        end
    end
    local restitution = firstFixture:getRestitution()
    local friction = firstFixture:getFriction()
    local fixedRotation = body:isFixedRotation() -- Capture fixed angle state
    -- Get the original `thing` for shape info

    local oldVertices = utils.shallowCopy(thing.vertices)
    local oldFixtures = body:getFixtures()

    local jointData = joints.extractJoints(body)

    -- Create new body
    local newBody = love.physics.newBody(state.physicsWorld, x, y, bodyType)
    newBody:setAngle(angle)
    newBody:setLinearVelocity(velocityX, velocityY)
    newBody:setAngularVelocity(angularVelocity)
    newBody:setFixedRotation(fixedRotation) -- Reapply fixed rotation
    -- Create a new shape

    local settings = shapes.copyDims(thing, { optionalVertices = newSettings.optionalVertices }, newSettings)
    local shapeList, newVertices = shapes.createShape(
        newSettings.shapeType or thing.shapeType,
        settings
    )

    -- If shape construction produced nothing (degenerate polygon after scaling,
    -- pcall'd failure in shapes.lua), abort the recreate cleanly: throw away
    -- the empty newBody and leave the old body and its joints untouched.
    -- Otherwise we'd end up with a body that has zero collision fixtures.
    if not shapeList or #shapeList == 0 then
        logger:warn("recreateThingFromBody: no shapes for " ..
            tostring(thing.label or "?") .. " — keeping old body")
        newBody:destroy()
        return thing
    end

    local orderOK, offset = fixtures.hasFixturesWithUserDataAtBeginning(oldFixtures)

    for _, shape in ipairs(shapeList) do
        local fixture = love.physics.newFixture(newBody, shape, 1)
        fixture:setRestitution(newSettings.restitution or restitution)
        fixture:setFriction(newSettings.friction or friction)
    end

    -- Collect the sfixtures to carry over. When the ordering invariant holds
    -- they are the first `offset` fixtures; when it's broken (offset == -1)
    -- recover them by scanning instead of silently dropping them all.
    local oldSFixtures = {}
    if orderOK and offset > 0 then
        for i = 1, offset do table.insert(oldSFixtures, oldFixtures[i]) end
    elseif not orderOK then
        logger:error("recreateThingFromBody: fixture-ordering invariant broken on "
            .. tostring(thing.label or thing.id) .. " — recovering sfixtures by scan")
        for i = 1, #oldFixtures do
            if oldFixtures[i]:getUserData() then table.insert(oldSFixtures, oldFixtures[i]) end
        end
    end

    if #oldSFixtures > 0 then
        -- here we should recreate the special fixtures..
        for i = 1, #oldSFixtures do
            local oldF = oldSFixtures[i]
            local points = { oldF:getShape():getPoints() }

            local abs = oldF:getShape()
            local centerX, centerY = mathutils.getCenterOfPoints(points)
            if (thing.vertices) then
                -- we are repositioning special fixtures (anchors, snappoints)
                -- and doing our best to set them at a decent position.
                -- this is fine for all sort of editor made things,
                -- todo specific positioning for mipo on behavors
                -- but for mipos character we might just want to be very precise
                -- and dending on behaviors and tags and dedicated rules.

                -- this general case isn working when the amount of points
                -- change. (and im not sure if it wise otherwise)
                if (#thing.vertices == #newVertices) then
                    local weights = mathutils.getMeanValueCoordinatesWeights(centerX, centerY, thing.vertices)
                    local new_px, new_py = mathutils.repositionPointUsingWeights(weights, newVertices)

                    local rel = mathutils.makePolygonRelativeToCenter(points, centerX, centerY)
                    abs = love.physics.newPolygonShape(mathutils.makePolygonAbsolute(rel, new_px, new_py))
                else
                    local rel = mathutils.makePolygonRelativeToCenter(points, centerX, centerY)
                    abs = love.physics.newPolygonShape(mathutils.makePolygonAbsolute(rel, 0, 0))
                end
            end

            local newFixture = love.physics.newFixture(newBody, abs, oldF:getDensity())
            newFixture:setRestitution(oldF:getRestitution())
            newFixture:setFriction(oldF:getFriction())
            newFixture:setUserData(utils.shallowCopy(oldF:getUserData()))

            registry.registerSFixture(oldF:getUserData().id, newFixture)
        end
    end

    -- Update the `thing` table
    thing.label = thing.label
    thing.body = newBody
    thing.shapes = shapeList

    shapes.copyDims(thing, thing, newSettings)
    thing.id = thing.id or uuid.generateID()
    thing.vertices = newVertices
    thing.behaviors = newSettings.behaviors or thing.behaviors

    -- Vertex positions changed: invalidate tile-repeat cached triangulation and mesh.
    -- The draw loop caches thing._tris and extra._mesh on first draw and never rebuilds
    -- them, so stale data would persist until the scene is reloaded.
    thing._tris = nil
    for _, ud in ipairs(fixtures.sfixtureData(newBody, subtypes.TILE_REPEAT)) do
        ud.extra._mesh = nil
    end

    -- If the polygon vertex count changed, any RESOURCE sfixture on this body
    -- has a stale UV array (uvs length is pinned to the old vertex count).
    -- Drop it so the RESOURCE editor re-computes UVs next time it's selected,
    -- and so MESHUSERT/UVUSERT render paths don't hand out stale mappings.
    -- See docs/UV-BACKDROP-FRAGILITY.md (fragility #6).
    if oldVertices and #oldVertices ~= #newVertices then
        for _, ud in ipairs(fixtures.sfixtureData(newBody, subtypes.RESOURCE)) do
            ud.extra.uvs = nil
            -- triangles/meshVertices/triangleGroups/triangleBones all
            -- index into the old vertex count; any of them left behind
            -- will crash the MESHUSERT / UVUSERT draw paths on the next
            -- frame (bad argument to love.graphics.polygon). Drop them
            -- all and let computeResourceMesh rebuild on next select.
            ud.extra.triangles = nil
            ud.extra.meshVertices = nil
            ud.extra.triangleGroups = nil
            ud.extra.triangleBones = nil
            ud.extra.triangleOrderDirty = false
        end
        -- MESHUSERT spineBind.tsPerVert has 2 entries per polygon vert;
        -- vert-count change invalidates the whole bind. Drop so the
        -- next evaluate falls through to the no-deformation path.
        for _, ud in ipairs(fixtures.sfixtureData(newBody, subtypes.MESHUSERT)) do
            ud.extra.spineBind = nil
        end
        -- Path B: thing.extraSteiner may reference positions that fall outside
        -- the new polygon. Drop per the plan (docs/STEINER-OWNERSHIP-PLAN.md).
        thing.extraSteiner = nil
    end

    registry.registerBody(thing.id, thing.body)
    newBody:setUserData({ thing = thing })

    joints.reattachJoints(jointData, newBody, oldVertices)

    -- Destroy the old body
    body:destroy()

    return thing
end

function lib.destroyBody(body)
    local thing = utils.thingOf(body)
    local bjoints = body:getJoints()
    for i = 1, #bjoints do
        local ud = bjoints[i]:getUserData()
        if ud and ud.id then
            registry.unregisterJoint(ud.id)
            bjoints[i]:destroy()
        end
    end
    local bfixtures = body:getFixtures()
    ---print(#bfixtures)
    for i = 1, #bfixtures do
        local f = bfixtures[i]
        local ud = f:getUserData()
        if ud and ud.id then
            fixtures.destroyFixture(f)
        end
    end
    registry.unregisterBody(thing.id)
    body:destroy()
end

-- Clone a body x10 below itself, chained with revolute joints. Parked (2026-10-28):
-- no button since the add-shape panel went; the PICK_AUTO_ROPIFY mode still works.
-- If we miss it: a 'chain x 10' button next to clone in the body panel.
function lib.autoRopify(ud)
    if not ud.thing or not ud.thing.body then
        logger:error("autoRopify: Invalid 'thing' provided.")
        return
    else
        local thing = ud.thing
        for _ = 1, 10 do
            local originalBody = thing.body
            if thing.height then
                local settings = shapes.copyDims(thing, {
                    x = originalBody:getX(),
                    y = originalBody:getY() + thing.height,
                    optionalVertices = thing.vertices,
                })

                local newthing = createThing(thing.shapeType, settings)
                if newthing then
                    local data = {
                        jointType = JT.REVOLUTE,
                        body1 = thing.body,
                        body2 = newthing.body,
                        offsetA = { x = 0, y = thing.height / 2 }
                        --p2 = { 0, thing.height / 2 },
                        --  p2 = { 0, 0 },
                    }
                    joints.createJoint(data)
                end
                thing = newthing
            else
                logger:error("autoRopify: Invalid 'thing' provided. (it needs a height)")
                return
            end
        end

    end
end

function lib.flipThing(thing, axis, recursive)
    -- Validate input
    if not thing or not thing.body then
        logger:error("flipThing: Invalid 'thing' provided.")
        return
    end

    if axis ~= 'x' and axis ~= 'y' then
        logger:error("flipThing: Invalid axis. Use 'x' or 'y'.")
        return
    end

    -- Tables to keep track of processed bodies and joints
    local processedBodies = {}
    local processedJoints = {}
    local toBeProcessedJoints = {}
    local centroidX, centroidY = thing.body:getPosition()

    -- Phase 1: Flip All Bodies
    local function flipBody(currentThing)
        local currentBody = currentThing.body
        if not currentBody or processedBodies[currentThing.id] then
            return
        end

        processedBodies[currentThing.id] = utils.shallowCopy(currentThing.vertices) or true

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
            currentThing.mirrorX = currentThing.mirrorX * -1
        elseif axis == 'y' then
            newAngle = -currentAngle
            currentThing.mirrorY = currentThing.mirrorY * -1
        end

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
        local bodyFixtures = currentBody:getFixtures()
        -- if i do this backwards the fixtures end up being in the same order... !!
        for i = #bodyFixtures, 1, -1 do
            local fixture = bodyFixtures[i]
            local shape = fixture:getShape()
            if shape:typeOf("PolygonShape") then
                local points = { shape:getPoints() }
                for pi = 1, #points, 2 do
                    if axis == 'x' then
                        points[pi] = -points[pi]         -- Invert X coordinate
                    elseif axis == 'y' then
                        points[pi + 1] = -points[pi + 1] -- Invert Y coordinate
                    end
                end
                -- Create a new shape with flipped vertices
                local success, newShape = pcall(love.physics.newPolygonShape, unpack(points))
                if not success then
                    logger:error("flipThing: Failed to create new PolygonShape:", newShape)
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
                    end

                    fixture:destroy()
                end
            elseif shape:typeOf("CircleShape") then -- luacheck: ignore 542
                -- No need to flip circle shapes — radius is symmetric
            end
        end
        -- Determine new angle based on flip axis

        -- If recursive, flip connected bodies first
        if recursive then
            for _, joint in ipairs(currentBody:getJoints()) do
                local jointUserData = joint:getUserData()
                if jointUserData and jointUserData.id then
                    toBeProcessedJoints[jointUserData.id] = joint
                    -- Determine the other body connected by the joint
                    local bodyA, bodyB = joint:getBodies()
                    local otherBody = (bodyA == currentBody) and bodyB or bodyA
                    local otherThing = utils.thingOf(otherBody)

                    if otherThing then
                        -- Recursively flip the connected body
                        flipBody(otherThing)
                    else
                        logger:error("flipThing: Connected joint's other body is invalid.")
                    end
                else
                    logger:error("flipThing: Joint without valid user data encountered.")
                end
            end
        end
    end

    -- Phase 2: Flip All Joints
    local function flipJoints()
        for _, joint in pairs(toBeProcessedJoints) do
            local jointType = joint:getType()
            local jointUserData = joint:getUserData()

            if not jointUserData or not jointUserData.id then
                logger:error("flipThing: Joint without valid user data encountered.")
            elseif not processedJoints[jointUserData.id] then
                processedJoints[jointUserData.id] = true

                -- Extract joint data using the handler
                local handler = jointHandlers[jointType]
                if not handler or not handler.extract then
                    logger:error("flipThing: No handler found for joint type:", jointType)
                else
                    local props = handler.extract(joint)

                    -- Determine the connected bodies
                    local bodyA, bodyB = joint:getBodies()
                    local thingA = utils.thingOf(bodyA)
                    local thingB = utils.thingOf(bodyB)

                    if not thingA or not thingB then
                        logger:error("flipThing: One or both connected things are invalid.")
                    else
                        local offsetA = jointUserData.offsetA
                        local offsetB = jointUserData.offsetB
                        local key = (axis == 'x') and 'x' or 'y'
                        offsetA[key] = -offsetA[key]
                        offsetB[key] = -offsetB[key]

                        -- Mirroring negates every body angle, so the angle between the two
                        -- bodies turns around too: reference angle, limits, and which way a
                        -- motor spins. A slider axis mirrors with the bodies.
                        local settings = { offsetA = offsetA, offsetB = offsetB }
                        if props.referenceAngle then settings.referenceAngle = -props.referenceAngle end
                        if props.motorSpeed and (jointType == JT.REVOLUTE or jointType == JT.WHEEL) then
                            settings.motorSpeed = -props.motorSpeed
                        end
                        if props.lowerLimit and props.upperLimit then
                            settings.lowerLimit = -props.upperLimit
                            settings.upperLimit = -props.lowerLimit
                        end
                        if props.axisX and props.axisY then
                            settings.axisX = (axis == 'x') and -props.axisX or props.axisX
                            settings.axisY = (axis == 'y') and -props.axisY or props.axisY
                        end
                        joints.recreateJoint(joint, settings)
                    end
                end
            end
        end
    end

    -- Phase 1: Flip All Bodies Recursively
    flipBody(thing)

    -- Phase 2: Flip All Joints
    flipJoints()

    return thing
end

return lib

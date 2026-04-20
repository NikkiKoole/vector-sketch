--io.lua
local lib = {}
local logger = require 'src.logger'

local json = require 'vendor.dkjson'
local uuid = require 'src.uuid'
local registry = require 'src.registry'
local shapes = require 'src.shapes'
local jointHandlers = require 'src.joint-handlers'
local mathutils = require 'src.math-utils'
local utils = require 'src.utils'
local joints = require 'src.joints'
local fixtures = require 'src.fixtures'
local state = require 'src.state'

local snap = require 'src.physics.snap'
local subtypes = require 'src.subtypes'
local NT = require('src.node-types')
local SIDES = require('src.sides')
local FEXT = require('src.file-extensions')

function lib.reload(data, world, cam)
    lib.load(data, world, cam)
end

local function clearWorld(world)
    for _, body in pairs(world:getBodies()) do
        body:destroy()
    end
    registry.reset()
end

local function restoreInfluenceBodies(influences)
    for i = 1, #influences do
        local inflList = influences[i]
        for j = 1, #inflList do
            local infl = inflList[j]
            if infl.nodeType == NT.JOINT then
                local joint = registry.getJointByID(infl.nodeId)
                local bodyA, bodyB = joint:getBodies()
                infl.body = (infl.side == SIDES.A) and bodyA or bodyB
            elseif infl.nodeType == NT.ANCHOR then
                local anchor = registry.getSFixtureByID(infl.nodeId)
                infl.body = anchor:getBody()
            end
            -- Backfill bindAngle for scenes saved before DQS support.
            -- Assumes the loaded pose is the bind pose (true when scene is saved at rest).
            if infl.bindAngle == nil and infl.body then
                infl.bindAngle = infl.body:getAngle()
            end
            -- Recompute dist if stripped on save (new) or restore for older
            -- saves lacking it (defensive).
            if infl.dist == nil and infl.dx ~= nil and infl.dy ~= nil then
                infl.dist = math.sqrt(infl.dx * infl.dx + infl.dy * infl.dy)
            end
        end
    end
end

-- Backfill bindVerts from current body poses for scenes saved before DQS support.
-- At bind time, each influence's (offx,offy) IS the anchor's body-local position, so
-- (offx+dx, offy+dy) transformed by the body's current world transform gives the bind-world
-- position — provided bodies haven't moved since load. True when scene is loaded paused/at-rest.
local function backfillBindVerts(extra)
    if not extra or not extra.influences then return end
    if extra.bindVerts then return end
    local bindVerts = {}
    for vi = 1, #extra.influences do
        local inflList = extra.influences[vi]
        local infl = inflList and inflList[1]
        if infl and infl.body then
            local wx, wy = infl.body:getWorldPoint(
                (infl.offx or 0) + (infl.dx or 0),
                (infl.offy or 0) + (infl.dy or 0)
            )
            bindVerts[vi] = { wx, wy }
        end
    end
    extra.bindVerts = bindVerts
end
-- Rebuild rigidLookup after load. rigidLookup holds body refs so it is never
-- saved. rigidBindCoords (saved since the fix) stores the exact lx,ly from
-- bind time as plain numbers — we just attach body refs to them on load.
-- Falls back to bind-pose reconstruction for older saves without rigidBindCoords.
local function backfillRigidLookup(extra)
    if not extra or not extra.nodes then return end
    if extra.rigidLookup then return end

    local nodeBodies = {}
    for nj, node in ipairs(extra.nodes) do
        if node.type == NT.ANCHOR then
            local f = registry.getSFixtureByID(node.id)
            if f and not f:isDestroyed() then nodeBodies[nj] = f:getBody() end
        elseif node.type == NT.JOINT then
            local joint = registry.getJointByID(node.id)
            if joint then nodeBodies[nj] = joint:getBodies() end
        end
    end

    local coords = extra.rigidBindCoords
    if coords then
        local numNodes = #extra.nodes
        local rigidLookup = {}
        for vi = 1, #coords do
            local row = coords[vi]
            if row then
                rigidLookup[vi] = {}
                for nj = 1, numNodes do
                    local lx = row[2 * nj - 1]
                    local ly = row[2 * nj]
                    local body = nodeBodies[nj]
                    if body and lx then
                        rigidLookup[vi][nj] = { body = body, lx = lx, ly = ly }
                    end
                end
            end
        end
        extra.rigidLookup = rigidLookup
        return
    end

    -- Fallback for old saves without rigidBindCoords: reconstruct from influences.
    local influences = extra.influences
    if not influences or not extra.bindVerts then return end
    local bindPose = {}
    for vi = 1, #extra.bindVerts do
        local bv = extra.bindVerts[vi]
        if bv and influences[vi] then
            local wx, wy = bv[1], bv[2]
            for _, infl in ipairs(influences[vi]) do
                local ni = infl.nodeIndex
                if ni and not bindPose[ni] and infl.bindAngle and infl.offx then
                    local lx = infl.offx + infl.dx
                    local ly = infl.offy + infl.dy
                    local ba = infl.bindAngle
                    local c, s = math.cos(ba), math.sin(ba)
                    bindPose[ni] = {
                        bx = wx - (c * lx - s * ly),
                        by = wy - (s * lx + c * ly),
                        ba = ba, body = infl.body,
                    }
                end
            end
        end
    end
    local rigidLookup = {}
    for vi = 1, #extra.bindVerts do
        local bv = extra.bindVerts[vi]
        if bv then
            local wx, wy = bv[1], bv[2]
            rigidLookup[vi] = {}
            for nj = 1, #extra.nodes do
                local bp = bindPose[nj]
                if bp then
                    local dx2 = wx - bp.bx
                    local dy2 = wy - bp.by
                    local c, s = math.cos(bp.ba), math.sin(bp.ba)
                    rigidLookup[vi][nj] = {
                        body = bp.body,
                        lx   =  c * dx2 + s * dy2,
                        ly   = -s * dx2 + c * dy2,
                    }
                end
            end
        end
    end
    extra.rigidLookup = rigidLookup
end

-- For cloning: remap IDs THEN restore body references
local function remapAndRestoreInfluences(influences, idMapping)
    if not influences then return end

    for i = 1, #influences do
        local inflList = influences[i]
        for j = 1, #inflList do
            local infl = inflList[j]

            -- Remap to new cloned node ID
            infl.nodeId = idMapping[infl.nodeId]

            -- Now restore body reference using the NEW ID
            if infl.nodeType == NT.JOINT then
                local joint = registry.getJointByID(infl.nodeId)
                if joint then
                    local bodyA, bodyB = joint:getBodies()
                    infl.body = (infl.side == SIDES.A) and bodyA or bodyB
                end
            elseif infl.nodeType == NT.ANCHOR then
                local anchor = registry.getSFixtureByID(infl.nodeId)
                if anchor then
                    infl.body = anchor:getBody()
                end
            end
        end
    end
end

function lib.buildWorld(data, world, cam)
    -- todo is this actually needed, i *think* its a premature optimization,
    -- getting ready to load a file into an exitsing situation, button
    -- this isnt really used. so we just might as well always use the oldid....
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

    if data.backdrops then
        -- Scene-persisted backdrops replace session backdrops wholesale.
        -- Image/w/h aren't saved (just url+world position). Eagerly load
        -- the image here so dimensions are known before draw — UV compute
        -- and any width/height-dependent code can run on scene load
        -- without waiting for the first draw frame (was fragility #7 in
        -- docs/UV-BACKDROP-FRAGILITY.md).
        state.backdrops = {}
        for _, b in ipairs(data.backdrops) do
            local entry = {
                url = b.url,
                x = b.x,
                y = b.y,
                scale = b.scale,
                border = b.border,
                foreground = b.foreground,
            }
            if b.url and love.filesystem.getInfo(b.url) then
                local ok, img = pcall(love.graphics.newImage, b.url)
                if ok and img then
                    entry.image = img
                    entry.w = img:getWidth()
                    entry.h = img:getHeight()
                else
                    logger:error("Failed to load backdrop image: " .. tostring(b.url))
                end
            else
                logger:error("Backdrop URL not found: " .. tostring(b.url))
            end
            table.insert(state.backdrops, entry)
        end
    end

    local recreatedSFixtures = {}
    -- Iterate through saved bodies and recreate them
    for _, bodyData in ipairs(data.bodies) do
        -- Create a new body
        local body = love.physics.newBody(world, bodyData.position[1], bodyData.position[2], bodyData.bodyType)
        body:setAngle(bodyData.angle)
        body:setLinearVelocity(bodyData.linearVelocity[1], bodyData.linearVelocity[2])
        body:setAngularVelocity(bodyData.angularVelocity)
        body:setFixedRotation(bodyData.fixedRotation or false)
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

                local _, err = pcall(function()
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
                fixture:setSensor(shared.sensor or false)
                if fixtureData.userData then
                    fixture:setSensor(fixtureData.sensor)
                    local oldUD = utils.shallowCopy(fixtureData.userData)
                    if not oldUD.id then
                        logger:info('missing')
                    end
                    oldUD.id = oldUD.id or uuid.generateID()

                    fixture:setUserData(oldUD)

                    -- Migrate old/middle-era subtype formats to current era
                    subtypes.migrate(oldUD)

                    -- RESOURCE sfixtures reference backdrops by array index.
                    -- If a URL was saved alongside the index, resolve it now so
                    -- reordering/adding backdrops doesn't silently break the ref.
                    if subtypes.is(oldUD, subtypes.RESOURCE) and oldUD.extra
                        and oldUD.extra.selectedBGURL and state.backdrops then
                        for bi, b in ipairs(state.backdrops) do
                            if b.url == oldUD.extra.selectedBGURL then
                                oldUD.extra.selectedBGIndex = bi
                                break
                            end
                        end
                    end

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

    -- only after making the bodies and joints can we patch up the influences to have bodies.
    -- we want to look through all bodeis

    for _, v in pairs(registry.sfixtures) do
        local ud = v:getUserData()

        if subtypes.is(ud, subtypes.MESHUSERT) then
            if ud.extra then --and ud.extra.infuences then
                if ud.extra.influences then
                    restoreInfluenceBodies(ud.extra.influences)
                    backfillBindVerts(ud.extra)
                    backfillRigidLookup(ud.extra)
                end
                -- JSON serialises integer keys as strings; convert back so
                -- triangleBones[t] (integer lookup in the draw path) works.
                if ud.extra.triangleBones then
                    local tb = ud.extra.triangleBones
                    local needsFix = false
                    for k in pairs(tb) do
                        if type(k) == 'string' then needsFix = true; break end
                    end
                    if needsFix then
                        local fixed = {}
                        for k, v2 in pairs(tb) do fixed[tonumber(k) or k] = v2 end
                        ud.extra.triangleBones = fixed
                    end
                end
            end
        end
    end

    -- Auto-compute mesh (UVs + triangle indices, optionally with CDT Steiner
    -- points) for RESOURCE sfixtures that have a backdrop selected but no
    -- cached mesh. Without this, MESHUSERT meshes render untextured until
    -- the user manually selects the RESOURCE. Uses the current
    -- `state.triangulationMode`.
    local cdt = require 'src.cdt'
    for _, v in pairs(registry.sfixtures) do
        if not v:isDestroyed() then
            local ud = v:getUserData()
            if subtypes.is(ud, subtypes.RESOURCE) and ud.extra then
                -- JSON serialises integer keys as strings; convert back so
                -- triangleGroups[t] (integer lookup in the draw path) works.
                if ud.extra.triangleGroups then
                    local tg = ud.extra.triangleGroups
                    local needsFix = false
                    for k in pairs(tg) do
                        if type(k) == 'string' then needsFix = true; break end
                    end
                    if needsFix then
                        local fixed = {}
                        for k, v2 in pairs(tg) do fixed[tonumber(k) or k] = v2 end
                        ud.extra.triangleGroups = fixed
                    end
                end
                local idx = ud.extra.selectedBGIndex
                local bd = idx and state.backdrops and state.backdrops[idx]
                local needsUVs = not ud.extra.uvs or #ud.extra.uvs == 0
                local needsTris = not ud.extra.triangles or #ud.extra.triangles == 0
                if bd and bd.image and bd.w and bd.h and (needsUVs or needsTris) then
                    cdt.computeResourceMesh(ud, v:getBody(), bd,
                        state.triangulationMode or 'basic',
                        state.cdtSpacing, mathutils)
                end
            end
        end
    end
end

function lib.load(data, world, cam)
    local jsonData, _, err = json.decode(data, 1, nil)
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
    lib.buildWorld(jsonData, world, cam)

    snap.onSceneLoaded()
end

local function needsDimProperty(prop, shape)
    local ST = require 'src.shape-types'
    local needsRadius = function(s)
        return s == ST.TRIANGLE or s == ST.PENTAGON or s == ST.HEXAGON or
            s == ST.HEPTAGON or s == ST.OCTAGON or s == ST.CIRCLE
    end

    if prop == 'radius' then
        return needsRadius(shape)
    elseif prop == 'width' then
        return not needsRadius(shape) and shape ~= ST.CUSTOM
    elseif prop == 'height' then
        return not needsRadius(shape) and shape ~= ST.CUSTOM
    elseif prop == 'height2' then
        return shape == ST.CAPSULE or shape == ST.TORSO
    elseif prop == 'width2' then
        return shape == ST.TRAPEZIUM or shape == ST.TORSO
    elseif prop == 'height3' or prop == 'height4' then
        return shape == ST.TORSO
    elseif prop == 'width3' then
        return shape == ST.TORSO
    end
end


function lib.gatherSaveData(world, camera)
    local saveData = {
        version = "1.0", -- Versioning for future compatibility
        bodies = {},
        joints = {},
        camera = {},
        backdrops = {},
    }
    for _, b in ipairs(state.backdrops or {}) do
        table.insert(saveData.backdrops, {
            url = b.url,
            x = b.x,
            y = b.y,
            scale = b.scale,
            border = b.border,
            foreground = b.foreground,
        })
    end
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
                    -- local fixtures = fb:getFixtures()
                    -- local ff = fixtures[1]
                    local first = nil

                    for k = 1, #bodyFixtures do
                        local fixture = bodyFixtures[k]
                        if fixture:getUserData() == nil then
                            first = fixture
                            break
                        end
                    end

                    if not first then
                        logger:warn('gatherSaveData: body %s has no normal fixture (only sfixtures), '
                            .. 'using first fixture as fallback', thing.id)
                        first = bodyFixtures[1]
                    end

                    bodyData.sharedFixtureData.density = utils.round_to_decimals(first:getDensity(), 4)
                    bodyData.sharedFixtureData.friction = utils.round_to_decimals(first:getFriction(), 4)
                    bodyData.sharedFixtureData.restitution = utils.round_to_decimals(first:getRestitution(), 4)
                    bodyData.sharedFixtureData.groupIndex = first:getGroupIndex()

                    bodyData.sharedFixtureData.sensor = first:isSensor()

                    -- todo this shape type name isnt really used anymore...
                    -- can we just delete it ?
                    local shape = first:getShape()
                    if shape:typeOf("CircleShape") then
                        bodyData.sharedFixtureData.shapeType = require('src.shape-types').CIRCLE
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
                    if subtypes.is(fixture:getUserData(), subtypes.SNAP) then
                        local ud             = fixture:getUserData()

                        ud.extra.fixture     = 'fixture'
                        -- NOTE: at/to were runtime fixture references from an older snap system.
                        -- They may be stale (destroyed Box2D objects) or nil after load.
                        -- Safely extract IDs if they're live objects, otherwise clear them.
                        if ud.extra.at and type(ud.extra.at) ~= 'string' then
                            local atok, atid = pcall(function() return ud.extra.at:getUserData().thing.id end)
                            ud.extra.at = atok and atid or nil
                        end
                        if ud.extra.to and type(ud.extra.to) ~= 'string' then
                            local otok, otid = pcall(function() return ud.extra.to:getUserData().thing.id end)
                            ud.extra.to = otok and otid or nil
                        end
                        fixtureData.userData = utils.deepCopy(ud)
                    else
                        local ud = fixture:getUserData()
                        if ud and ud.extra and ud.extra._mesh then
                            ud.extra._mesh = nil
                        end
                        -- logger:inspect(ud)
                        if subtypes.is(ud, subtypes.TEXFIXTURE) then
                            ud.extra.dirty = true
                            if ud.extra.ompImage then ud.extra.ompImage = nil end
                        end
                        -- Stash the backdrop URL alongside the array index so the
                        -- reference survives backdrop reordering across sessions.
                        if subtypes.is(ud, subtypes.RESOURCE) and ud.extra then
                            local idx = ud.extra.selectedBGIndex
                            if idx and state.backdrops and state.backdrops[idx] then
                                ud.extra.selectedBGURL = state.backdrops[idx].url
                            end
                        end
                        if ud.extra and ud.extra.ompImage then
                            ud.extra.dirty = true
                            ud.extra.ompImage = nil
                        end
                        -- removing body before save
                        if ud.extra.influences then
                            for i = 1, #ud.extra.influences do
                                local inflList = ud.extra.influences[i]
                                for j = 1, #inflList do
                                    if inflList[j].body then
                                        ud.extra.influences[i][j].body = nil
                                    end
                                end
                            end
                        end
                        -- rigidLookup holds body references (userdata) — strip before JSON
                        local savedRigidLookup = ud.extra.rigidLookup
                        ud.extra.rigidLookup = nil
                        fixtureData.userData = utils.deepCopy(ud)
                        -- restoring body after save
                        if ud.extra.influences then
                            restoreInfluenceBodies(ud.extra.influences)
                        end
                        ud.extra.rigidLookup = savedRigidLookup
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
                local JT = require 'src.joint-types'
                if joint:getType() == JT.DISTANCE then
                    jointData.properties.length = joint:getLength()
                    jointData.properties.frequency = joint:getFrequency()
                    jointData.properties.dampingRatio = joint:getDampingRatio()
                elseif joint:getType() == JT.ROPE then
                    jointData.properties.maxLength = joint:getMaxLength()
                elseif joint:getType() == JT.REVOLUTE then
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
                elseif joint:getType() == JT.WELD then
                    jointData.properties.frequency = joint:getFrequency()
                    jointData.properties.dampingRatio = joint:getDampingRatio()
                elseif joint:getType() == JT.PRISMATIC then
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
                elseif joint:getType() == JT.PULLEY then
                    local a1x, a1y, a2x, a2y = joint:getGroundAnchors()
                    jointData.properties.groundAnchor1 = { x = a1x, y = a1y }
                    jointData.properties.groundAnchor2 = { x = a2x, y = a2y }
                    jointData.properties.ratio = joint:getRatio()
                elseif joint:getType() == JT.WHEEL then
                    jointData.properties.motorEnabled = joint:isMotorEnabled()
                    if jointData.properties.motorEnabled then
                        jointData.properties.motorSpeed = joint:getMotorSpeed()
                        jointData.properties.maxMotorTorque = joint:getMaxMotorTorque()
                    end
                    local axisx, axisy = joint:getAxis()
                    jointData.properties.axis = { x = axisx, y = axisy }
                    jointData.properties.springFrequency = joint:getSpringFrequency()
                    jointData.properties.springDampingRatio = joint:getSpringDampingRatio()
                elseif joint:getType() == JT.MOTOR then
                    jointData.properties.correctionFactor = joint:getCorrectionFactor()
                    jointData.properties.angularOffset = joint:getAngularOffset()
                    jointData.properties.linearOffsetX, jointData.properties.linearOffsetY = joint:getLinearOffset()
                    jointData.properties.maxForce = joint:getMaxForce()
                    jointData.properties.maxTorque = joint:getMaxTorque()
                elseif joint:getType() == JT.FRICTION then
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
    -- Serialize the data to JSON. Round numbers to 4 decimals before encode:
    -- sub-pixel precision at any reasonable world scale, and cuts the file
    -- size meaningfully by dropping the 13-digit tail that `tostring` emits.
    -- Then strip `dist` from influence entries — it's sqrt(dx^2+dy^2),
    -- recomputed on load. See docs/FILESIZE-ANALYSIS.md.
    local saveData = roundFloats(lib.gatherSaveData(world, camera), 4)
    for _, body in ipairs(saveData.bodies or {}) do
        for _, fix in ipairs(body.fixtures or {}) do
            local extra = fix.userData and fix.userData.extra
            if extra and extra.influences then
                pruneZeroWeightInfluences(extra.influences)
                stripInfluenceDist(extra.influences)
            end
        end
    end
    -- logger:debug(inspect(saveData))
    local jsonData = json.encode(saveData, { indent = true })

    -- Write the JSON data to a file
    local success, message = love.filesystem.write(filename .. FEXT.SCENE_JSON, jsonData)
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
            -- while registry.getBodyByID(newID) do
            --     logger:info('this body id was already taken, clashes')
            --     newID = uuid.generateID()
            -- end

            --local newID = uuid.generateID()

            --oldUD.id = newID

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
                    newFixture:setSensor(oldF:isSensor())
                end
                if offset > 0 then
                    -- here we should recreate the special fixtures..
                    for i = 1, offset do
                        local oldF = oldFixtures[i]


                        local newFixture = love.physics.newFixture(newBody, oldF:getShape(), oldF:getDensity())
                        newFixture:setRestitution(oldF:getRestitution())
                        newFixture:setFriction(oldF:getFriction())
                        newFixture:setGroupIndex(oldF:getGroupIndex())

                        local oldUD = utils.deepCopy(oldF:getUserData())
                        local oldid = oldUD.id

                        --oldUD.id = uuid.generateID()
                        local newFixID = uuid.generateID()

                        -- while registry.getSFixtureByID(newID) do
                        --     logger:info('this fixture id was already taken, clashes')
                        --     newID = uuid.generateID()
                        -- end

                        -- while registry.getSFixtureByID(newID) do
                        --     --print('this was already one!')
                        --     newID = uuid.generateID()
                        -- end
                        oldUD.id = newFixID

                        idMapping[oldid] = oldUD.id
                        if subtypes.is(oldUD, subtypes.SNAP) then
                            oldUD.extra.at = nil
                            oldUD.extra.to = nil
                            oldUD.extra.fixture = nil
                        end

                        newFixture:setUserData(oldUD)
                        --print('jozers')

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
        local bodyJoints = originalBody:getJoints()
        for _, originalJoint in ipairs(bodyJoints) do
            local ud = originalJoint:getUserData()
            if ud and ud.id then
                if not doneJoints[ud.id] then -- make sure we dont do joints twice..
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
                                --id = uuid.generateID(),




                                offsetA = { x = ud.offsetA.x, y = ud.offsetA.y },
                                offsetB = { x = ud.offsetB.x, y = ud.offsetB.y }
                            }


                            local newID = uuid.generateID()
                            -- while registry.getJointByID(newID) do
                            --     logger:info('this is was already taken, clashes')
                            --     newID = uuid.generateID()
                            -- end
                            newJointData.id = newID


                            idMapping[ud.id] = newJointData.id
                            -- Include all joint-specific properties
                            for key, value in pairs(jointData) do
                                newJointData[key] = value
                            end
                            local limitsEnabled = originalJoint:areLimitsEnabled()
                            local lower, upper = originalJoint:getLimits()
                            local newJoint = joints.createJoint(newJointData)
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
    -- now we need to figure out if i have any of the connected-texture fixtures
    -- with ids in their userdata that needs updating
    for _, v in pairs(clonedBodiesMap) do
        local bodyFixtures = v.body:getFixtures()
        for j = 1, #bodyFixtures do
            local fixture = bodyFixtures[j]
            local ud = fixture:getUserData()
            local oldUD = utils.deepCopy(ud)
            if oldUD and oldUD.extra and oldUD.extra.nodes then
                for ni = 1, #oldUD.extra.nodes do
                    oldUD.extra.nodes[ni].id = idMapping[oldUD.extra.nodes[ni].id]
                end
                -- stale body refs — will be rebuilt below from rigidBindCoords
                oldUD.extra.rigidLookup = nil
                fixture:setUserData(oldUD)
            end

            if oldUD and oldUD.extra and oldUD.extra.influences then
                remapAndRestoreInfluences(oldUD.extra.influences, idMapping)
            end

            if oldUD and oldUD.extra and oldUD.extra.rigidBindCoords then
                backfillRigidLookup(oldUD.extra)
            end
        end
    end




    local result = {}
    for _, v in pairs(clonedBodiesMap) do
        table.insert(result, v)
    end
    return result
    --state.selection.selectedBodies = result
end

-- `dist` on an influence entry is defined as sqrt(dx^2 + dy^2) — purely
-- redundant with dx/dy that are saved alongside. Strip on save, recompute
-- on load. In-place mutation; caller has already duplicated the structure.
local function stripInfluenceDist(influences)
    if type(influences) ~= 'table' then return end
    for i = 1, #influences do
        local inflList = influences[i]
        if type(inflList) == 'table' then
            for j = 1, #inflList do
                local infl = inflList[j]
                if type(infl) == 'table' then infl.dist = nil end
            end
        end
    end
end

-- Remove entries whose weight is 0 (or missing). They contribute 0 to the
-- DQS weighted sum, so pruning changes nothing at runtime. Preserves the
-- outer per-vertex array shape: a vertex whose entries are all zero-weight
-- ends up with an empty per-vertex list, not nil, to avoid holes.
local function pruneZeroWeightInfluences(influences)
    if type(influences) ~= 'table' then return end
    for i = 1, #influences do
        local inflList = influences[i]
        if type(inflList) == 'table' then
            local kept = {}
            for j = 1, #inflList do
                local infl = inflList[j]
                if type(infl) == 'table' and (infl.w or 0) ~= 0 then
                    kept[#kept + 1] = infl
                end
            end
            influences[i] = kept
        end
    end
end

local function restoreInfluenceDist(influences)
    if type(influences) ~= 'table' then return end
    for i = 1, #influences do
        local inflList = influences[i]
        if type(inflList) == 'table' then
            for j = 1, #inflList do
                local infl = inflList[j]
                if type(infl) == 'table' and infl.dist == nil
                   and infl.dx ~= nil and infl.dy ~= nil then
                    infl.dist = math.sqrt(infl.dx * infl.dx + infl.dy * infl.dy)
                end
            end
        end
    end
end

-- Recursively round every numeric leaf to `ndecimals` decimals and return a
-- new table. Strings/booleans/non-number values pass through unchanged. Used
-- at save-time to strip the 13-digit bloat that tostring() emits for floats
-- — see docs/FILESIZE-ANALYSIS.md for why this is worth doing.
local function roundFloats(x, ndecimals)
    local fmt = '%.' .. tostring(ndecimals) .. 'f'
    local function rec(v)
        if type(v) == 'number' then
            -- string.format handles negatives correctly and yields a clean
            -- decimal (tonumber collapses -0 back to 0).
            return tonumber(string.format(fmt, v)) or v
        elseif type(v) == 'table' then
            local out = {}
            for k, val in pairs(v) do out[k] = rec(val) end
            return out
        else
            return v
        end
    end
    return rec(x)
end

-- Expose locals for testing (not part of public API)
lib._test = {
    needsDimProperty = needsDimProperty,
    remapAndRestoreInfluences = remapAndRestoreInfluences,
    clearWorld = clearWorld,
    restoreInfluenceBodies = restoreInfluenceBodies,
    roundFloats = roundFloats,
    stripInfluenceDist = stripInfluenceDist,
    restoreInfluenceDist = restoreInfluenceDist,
    pruneZeroWeightInfluences = pruneZeroWeightInfluences,
}

return lib

-- scene-load.lua
-- A scene file into the world: decode, prepare (src/influences.lua, src/save-migrations.lua), then
-- buildWorld: the scene's camera, music and backdrops, the bodies with their fixtures, the joints,
-- the sfixture fix-ups that need bodies and joints to exist, the Mipos.
-- Split out of io.lua (CODE-SPLITS-2026-10.md SPLIT6); io.lua still hands these out.
local logger = require('src.logger')
local json = require('vendor.dkjson')
local uuid = require('src.uuid')
local registry = require('src.registry')
local shapes = require('src.shapes')
local jointHandlers = require('src.joint-handlers')
local mathutils = require('src.math-utils')
local utils = require('src.utils')
local joints = require('src.joints')
local state = require('src.state')
local snap = require('src.physics.snap')
local subtypes = require('src.subtypes')
local resourceLink = require('src.resource-link')
local JT = require('src.joint-types')
local cameraFollow = require('src.camera-follow')
local cdt = require('src.cdt')
local characterManager = require('src.character-manager')
local mipoRegistry = require('src.mipo-registry')
local roomMusic = require('src.room-music')
local influences = require('src.influences')
local migrations = require('src.save-migrations')

local lib = {}

-- body-local point of a world point
local function localPoint(body, point)
    local x, y = mathutils.rotatePoint(point[1] - body:getX(), point[2] - body:getY(), 0, 0, -body:getAngle())
    return { x = x, y = y }
end

-- A saved joint as joints.createJoint takes it.
local function jointFromFile(jointData, bodyA, bodyB)
    local anchorA = jointData.anchorA
    local anchorB = jointData.anchorB or anchorA
    local data = {
        body1 = bodyA, body2 = bodyB, jointType = jointData.type, id = jointData.id,
        collideConnected = jointData.collideConnected, label = jointData.label, scriptmeta = jointData.scriptmeta,
        offsetA = localPoint(bodyA, anchorA), offsetB = localPoint(bodyB, anchorB), anchorB = anchorB,
    }
    for key, value in pairs(jointData.properties or {}) do data[key] = value end
    if data.axis then
        data.axisX, data.axisY = data.axis.x, data.axis.y
        data.axis = nil
    end
    -- scenes saved before the reference angle was kept count from the saved pose
    if (data.jointType == JT.REVOLUTE or data.jointType == JT.WELD) and not data.referenceAngle then
        data.referenceAngle = bodyB:getAngle() - bodyA:getAngle()
    end
    return data
end

function lib.clearWorld(world)
    for _, body in pairs(world:getBodies()) do
        body:destroy()
    end
    registry.reset()
    mipoRegistry.reset()
end

-- JSON makes integer keys strings; the draw path looks them up as integers.
local function numberKeys(t)
    for k in pairs(t) do
        if type(k) == 'string' then
            local fixed = {}
            for k2, v in pairs(t) do fixed[tonumber(k2) or k2] = v end
            return fixed
        end
    end
    return t
end

-- Scene-persisted backdrops replace the session's wholesale, also when the scene has none (it used
-- to keep the previous scene's). Image, w and h aren't saved (just url and position): load the image
-- now so its size is known before the first draw (UV compute runs on load; was fragility #7 in
-- docs/UV-BACKDROP-FRAGILITY.md).
local function loadBackdrops(saved)
    state.backdrops = {}
    for _, b in ipairs(saved or {}) do
        local entry = { url = b.url, x = b.x, y = b.y, scale = b.scale, border = b.border, foreground = b.foreground }
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

-- A whole scene replaces the one before: an empty world, then its camera settings (follow, bounds,
-- zoom limits; none saved: the defaults), its music, its view and its backdrops.
local function resetScene(data, world, cam)
    lib.clearWorld(world)
    snap.reset()
    cameraFollow.loadSettings(data.camera and data.camera.settings)
    roomMusic.load(data.music) -- the room's music (src/room-music.lua)
    if data.camera then
        cam:setTranslation(data.camera.x, data.camera.y)
        cam:setScale(data.camera.scale)
    else
        -- no saved view: the default (pan 0,0, zoom 1), not the previous scene's framing
        cam:setTranslation(0, 0)
        cam:setScale(1)
    end
    loadBackdrops(data.backdrops)
end

-- A saved fixture's shape; nil when it can't be made (a bad polygon is logged and skipped).
local function shapeFromFile(fixtureData)
    if fixtureData.radius then
        return love.physics.newCircleShape(fixtureData.radius)
    elseif fixtureData.points then
        local ok, shape = pcall(love.physics.newPolygonShape, unpack(fixtureData.points))
        if ok then return shape end
        logger:info('failed creating a polygonshape, will add a circle instead')
    else
        logger:error("Unsupported shape type:", fixtureData.shapeType)
    end
    return nil
end

-- An sfixture's userdata from the file: an id, today's subtype format, the RESOURCE's own image,
-- and an OMP texture marked to be composed again.
local function sfixtureUserData(saved)
    local ud = utils.shallowCopy(saved)
    if not ud.id then logger:info('missing') end
    ud.id = ud.id or uuid.generateID()
    subtypes.migrate(ud)
    if subtypes.is(ud, subtypes.RESOURCE) then resourceLink.imageURL(ud) end
    if ud.extra and ud.extra.OMP then ud.extra.dirty = true end
    return ud
end

-- One saved body with its fixtures, registered. Fixtures go on back to front, which keeps their order.
local function buildBody(bodyData, world, builtSFixtures)
    local body = love.physics.newBody(world, bodyData.position[1], bodyData.position[2], bodyData.bodyType)
    body:setAngle(bodyData.angle)
    body:setLinearVelocity(bodyData.linearVelocity[1], bodyData.linearVelocity[2])
    body:setAngularVelocity(bodyData.angularVelocity)
    body:setFixedRotation(bodyData.fixedRotation or false)
    body:setLinearDamping(bodyData.linearDamping or 0)
    body:setAngularDamping(bodyData.angularDamping or 0)

    local shared = bodyData.sharedFixtureData
    for i = #bodyData.fixtures, 1, -1 do
        local fixtureData = bodyData.fixtures[i]
        local shape = shapeFromFile(fixtureData)
        if shape then
            -- sfixtures (textures, face decals, ribbons) are sensors and weigh nothing; the body's
            -- one shared density went onto them too, and a loaded Mipo's head, torso, hands and feet
            -- came back 4-5x heavier than when it was made
            local density = fixtureData.userData and 0 or shared.density
            local fixture = love.physics.newFixture(body, shape, density)
            fixture:setFriction(shared.friction)
            fixture:setRestitution(shared.restitution)
            fixture:setGroupIndex(shared.groupIndex or 0)
            fixture:setSensor(shared.sensor or false)
            if fixtureData.userData then
                fixture:setSensor(fixtureData.sensor)
                local ud = sfixtureUserData(fixtureData.userData)
                fixture:setUserData(ud)
                table.insert(builtSFixtures, fixture)
                registry.registerSFixture(ud.id, fixture)
            end
        end
    end

    local thing = {
        id = bodyData.id,
        label = bodyData.label,
        shapeType = bodyData.shapeType,
        body = body,
        mirrorX = bodyData.mirrorX or 1,
        mirrorY = bodyData.mirrorY or 1,
        vertices = bodyData.vertices,
        behaviors = bodyData.behaviors,
        extraSteiner = bodyData.extraSteiner, -- body-local Steiner points (Path B)
        mipoId = bodyData.mipoId,
        mipoPartName = bodyData.mipoPartName,
    }
    shapes.copyDims(bodyData, thing, bodyData.dims) -- older files: sizes on bodyData itself
    body:setUserData({ thing = thing })
    registry.registerBody(thing.id, body)
    if thing.mipoPartName then registry.updateSFixtureMasks(body) end -- a foot keeps its contacts
    return thing
end

local function buildJoints(saved)
    for _, jointData in ipairs(saved) do
        local bodyA = registry.getBodyByID(jointData.bodyA)
        local bodyB = registry.getBodyByID(jointData.bodyB)
        if bodyA and bodyB and jointHandlers[jointData.type] then
            joints.createJoint(jointFromFile(jointData, bodyA, bodyB))
        elseif bodyA and bodyB then
            logger:error("Unsupported joint type during load:", jointData.type)
        else
            logger:error("Failed to find bodies for joint:", jointData.id)
        end
    end
end

-- What needs the bodies and joints to exist: MESHUSERT influences get their bodies (and the
-- backfills for older files), and a RESOURCE with a picture but no cached mesh computes it now
-- (else its meshes draw untextured until you select the RESOURCE; computeResourceMesh picks the
-- mode from the body).
local function fixUpSFixtures(sfixtures)
    for _, fixture in pairs(sfixtures) do
        -- a destroyed one left in the registry (a hot reload of registry.lua split it) is skipped,
        -- not a crash in the middle of a room load
        local ud = not fixture:isDestroyed() and fixture:getUserData()
        if ud and subtypes.is(ud, subtypes.MESHUSERT) and ud.extra then
            if ud.extra.influences then
                influences.restoreBodies(ud.extra.influences)
                migrations.backfillBindVerts(ud.extra)
                migrations.backfillRigidLookup(ud.extra)
            end
            if ud.extra.triangleBones then ud.extra.triangleBones = numberKeys(ud.extra.triangleBones) end
        end
    end
    for _, fixture in pairs(sfixtures) do
        if not fixture:isDestroyed() then
            local ud = fixture:getUserData()
            if subtypes.is(ud, subtypes.RESOURCE) and ud.extra then
                if ud.extra.triangleGroups then ud.extra.triangleGroups = numberKeys(ud.extra.triangleGroups) end
                local bd = resourceLink.backdrop(ud)
                local needsUVs = not ud.extra.uvs or #ud.extra.uvs == 0
                local needsTris = not ud.extra.triangles or #ud.extra.triangles == 0
                if bd and bd.image and bd.w and bd.h and (needsUVs or needsTris) then
                    cdt.computeResourceMesh(ud, fixture:getBody(), bd)
                end
            end
        end
    end
end

-- The saved Mipos from their DNA, each over its bodies (grouped by mipoId, then part name).
local function buildCharacters(saved, world)
    if not (saved and #saved > 0) then return end
    local bodyGroups = {}
    for _, body in ipairs(world:getBodies()) do
        local thing = utils.thingOf(body)
        if thing and thing.mipoId then
            bodyGroups[thing.mipoId] = bodyGroups[thing.mipoId] or {}
            bodyGroups[thing.mipoId][thing.mipoPartName] = body
        end
    end
    for _, charData in ipairs(saved) do
        characterManager.reconstructInstance(charData, bodyGroups[charData.id])
    end
end

-- opts.additive: build the bodies and joints next to what's already in the world (a library prefab,
-- src/library.lua): no clearing, camera or backdrops. Returns the things it built.
function lib.buildWorld(data, world, cam, opts)
    local additive = opts and opts.additive
    -- hand-edited or partial files: no crash on a missing list
    if type(data.bodies) ~= 'table' then
        logger:warn('buildWorld: save data has no bodies array')
        data.bodies = {}
    end
    if type(data.joints) ~= 'table' then
        logger:warn('buildWorld: save data has no joints array')
        data.joints = {}
    end
    if not additive then resetScene(data, world, cam) end

    local builtSFixtures, builtThings = {}, {}
    for _, bodyData in ipairs(data.bodies) do
        table.insert(builtThings, buildBody(bodyData, world, builtSFixtures))
    end
    buildJoints(data.joints)

    if additive then
        -- a placed prefab saved before resourceId existed: link its meshes to its own RESOURCE
        for _, fixture in ipairs(builtSFixtures) do
            local ud = fixture:getUserData()
            if resourceLink.isUser(ud) then resourceLink.find(ud, builtSFixtures) end
        end
    end
    fixUpSFixtures(additive and builtSFixtures or registry.sfixtures)
    buildCharacters(data.characters, world)
    return builtThings
end

-- Decoded file data into the shape buildWorld expects: bone metadata back on each influence (files
-- without bones pass through), and old Steiner points moved to their body. Also for library imports.
function lib.prepareLoaded(jsonData)
    for _, body in ipairs(jsonData.bodies or {}) do
        for _, fix in ipairs(body.fixtures or {}) do
            influences.fromFile(fix.userData and fix.userData.extra)
        end
    end
    migrations.extraSteinerToBody(jsonData)
end

-- A scene file's text into the world, replacing what's there.
function lib.load(data, world, cam)
    local jsonData, _, err = json.decode(data, 1, nil)
    if err then
        logger:error("Error decoding JSON:", err)
        return
    end
    if not jsonData then
        logger:error('failed loading json')
        return
    end
    if jsonData.version ~= "1.0" then
        logger:error("Unsupported save version:", jsonData.version)
        return
    end

    lib.prepareLoaded(jsonData)
    lib.buildWorld(jsonData, world, cam)
    snap.onSceneLoaded()
end

return lib

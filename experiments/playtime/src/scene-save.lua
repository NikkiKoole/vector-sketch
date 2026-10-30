-- scene-save.lua
-- The world into a scene file: gatherSaveData makes the table (backdrops, bodies with their
-- fixtures, Mipos, joints, camera, music), save rounds it, packs the influences
-- (src/influences.lua) and writes it as JSON.
-- Split out of io.lua (CODE-SPLITS-2026-10.md SPLIT6); io.lua still hands these out.
local logger = require('src.logger')
local json = require('vendor.dkjson')
local shapes = require('src.shapes')
local jointHandlers = require('src.joint-handlers')
local utils = require('src.utils')
local state = require('src.state')
local subtypes = require('src.subtypes')
local resourceLink = require('src.resource-link')
local FEXT = require('src.file-extensions')
local ST = require('src.shape-types')
local cameraFollow = require('src.camera-follow')
local characterManager = require('src.character-manager')
local roomMusic = require('src.room-music')
local influences = require('src.influences')

local lib = {}

local round = utils.round_to_decimals

-- Joints in a scene file: world anchors (anchorA, anchorB), and the properties the joint
-- handlers read and set (src/joint-handlers.lua) with an axis as { x, y } and pulley
-- ground anchors as { x, y }; the handlers say axisX/axisY and { x, y } lists.
local function propertiesForFile(props)
    local out = {}
    for key, value in pairs(props) do out[key] = value end
    if out.axisX then
        out.axis = { x = out.axisX, y = out.axisY }
        out.axisX, out.axisY = nil, nil
    end
    for _, key in ipairs({ 'groundAnchor1', 'groundAnchor2' }) do
        local a = out[key]
        if a and a[1] then out[key] = { x = a[1], y = a[2] } end
    end
    return out
end

-- Every numeric leaf rounded to `ndecimals` decimals, in a new table; other values pass through.
-- Cuts the 13-digit tail tostring() gives floats (docs/FILESIZE-ANALYSIS.md).
function lib.roundFloats(x, ndecimals)
    local fmt = '%.' .. tostring(ndecimals) .. 'f'
    local function rec(v)
        if type(v) == 'number' then
            -- string.format handles negatives, and tonumber collapses -0 back to 0
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

-- The body's settings shared by its fixtures, read from its first collision fixture (a body with
-- only sfixtures falls back to its first one).
local function sharedFixtureData(body, thing)
    local bodyFixtures = body:getFixtures()
    if #bodyFixtures == 0 then return {} end
    local first
    for _, fixture in ipairs(bodyFixtures) do
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
    local shared = {
        density = round(first:getDensity(), 4),
        friction = round(first:getFriction(), 4),
        restitution = round(first:getRestitution(), 4),
        groupIndex = first:getGroupIndex(),
        sensor = first:isSensor(),
    }
    -- todo this shape type name isnt really used anymore... can we just delete it ?
    local shape = first:getShape()
    if shape:typeOf("CircleShape") then
        shared.shapeType = ST.CIRCLE
    elseif shape:typeOf("PolygonShape") then
        shared.shapeType = 'polygon'
    end
    return shared
end

-- An sfixture's userdata for the file. Clean a copy, not the live userdata: saving used to drop
-- every OMP image and mesh in the scene, so all of them were made again (BUG15).
local function sfixtureUserData(ud)
    -- snap points hold no runtime refs any more (links live on the snap joint, src/physics/snap.lua)
    if subtypes.is(ud, subtypes.SNAP) then return utils.deepCopy(ud) end
    local saved = utils.shallowCopy(ud)
    if ud.extra then
        local extra = utils.shallowCopy(ud.extra)
        extra._mesh = nil
        extra.rigidLookup = nil -- holds bodies (userdata)
        if extra.ompImage or subtypes.is(ud, subtypes.TEXFIXTURE) then
            extra.ompImage = nil
            extra.dirty = true -- composed again after a load
        end
        -- selectedBGURL mirrors imageURL for older builds reading this file
        if subtypes.is(ud, subtypes.RESOURCE) then
            extra.selectedBGURL = resourceLink.imageURL(ud)
        end
        saved.extra = extra
    end
    saved = utils.deepCopy(saved)
    -- influences point at bodies; the file keeps their ids
    for _, inflList in ipairs(saved.extra and saved.extra.influences or {}) do
        for _, influence in ipairs(inflList) do influence.body = nil end
    end
    return saved
end

local function fixtureForFile(fixture)
    local shape = fixture:getShape()
    local fixtureData = {}
    if shape:typeOf("CircleShape") then
        fixtureData.radius = shape:getRadius()
    elseif shape:typeOf("PolygonShape") then
        local points = { shape:getPoints() }
        for i = 1, #points do points[i] = round(points[i], 3) end
        fixtureData.points = points
    else
        fixtureData.shapeType = "unknown"
    end
    local ud = fixture:getUserData()
    if ud then
        fixtureData.userData = sfixtureUserData(ud)
        fixtureData.sensor = fixture:isSensor()
    end
    return fixtureData
end

local function bodyForFile(body, thing)
    local lvx, lvy = body:getLinearVelocity()
    local bodyData = {
        id = thing.id,
        label = utils.sanitizeString(thing.label),
        shapeType = thing.shapeType,
        dims = shapes.usedDims(thing),
        mirrorX = thing.mirrorX,
        mirrorY = thing.mirrorY,
        vertices = thing.vertices,
        extraSteiner = thing.extraSteiner, -- body-local Steiner points (Path B)
        mipoId = thing.mipoId,
        mipoPartName = thing.mipoPartName,
        bodyType = body:getType(), -- 'dynamic', 'kinematic' or 'static'
        position = { round(body:getX(), 4), round(body:getY(), 4) },
        angle = round(body:getAngle(), 4),
        linearVelocity = { lvx, lvy },
        angularVelocity = round(body:getAngularVelocity(), 4),
        linearDamping = round(body:getLinearDamping(), 4),
        angularDamping = round(body:getAngularDamping(), 4),
        fixedRotation = body:isFixedRotation(),
        fixtures = {},
        sharedFixtureData = sharedFixtureData(body, thing),
        behaviors = thing.behaviors,
    }
    for _, fixture in ipairs(body:getFixtures()) do
        table.insert(bodyData.fixtures, fixtureForFile(fixture))
    end
    return bodyData
end

-- A joint for the file, or nil (no id: a blob's rim joint, rebuilt from its sfixture by
-- src/blob.lua; bodies without a thing).
local function jointForFile(joint)
    local jointUserData = joint:getUserData()
    local jointID = jointUserData and jointUserData.id
    if not jointID then
        local bodyB = select(2, joint:getBodies())
        if not (state.blobRims and state.blobRims[bodyB]) then
            logger:debug('what is up with this joint?')
        end
        return nil
    end
    local bodyA, bodyB = joint:getBodies()
    local thingA, thingB = utils.thingOf(bodyA), utils.thingOf(bodyB)
    if not (thingA and thingB) then
        logger:error("Failed to find bodies for joint:", jointID)
        return nil
    end
    local x1, y1, x2, y2 = joint:getAnchors()
    local jointData = {
        id = jointID,
        type = joint:getType(),
        bodyA = thingA.id,
        bodyB = thingB.id,
        anchorA = { round(x1, 3), round(y1, 3) },
        anchorB = { round(x2, 3), round(y2, 3) },
        collideConnected = joint:getCollideConnected(),
        properties = {},
        label = jointUserData.label,
    }
    if jointUserData.scriptmeta then
        jointData.scriptmeta = utils.shallowCopy(jointUserData.scriptmeta)
    end
    local handler = jointHandlers[joint:getType()]
    if handler then
        jointData.properties = propertiesForFile(handler.extract(joint))
    else
        logger:error("Unsupported joint type during save:", joint:getType())
    end
    return jointData
end

function lib.gatherSaveData(world, camera)
    local saveData = {
        version = "1.0",
        bodies = {},
        joints = {},
        backdrops = {},
    }
    for _, b in ipairs(state.backdrops or {}) do
        table.insert(saveData.backdrops,
            { url = b.url, x = b.x, y = b.y, scale = b.scale, border = b.border, foreground = b.foreground })
    end
    for _, body in pairs(world:getBodies()) do
        local thing = utils.thingOf(body)
        if thing and thing.id then table.insert(saveData.bodies, bodyForFile(body, thing)) end
    end
    saveData.characters = characterManager.serializeCharacters()
    for _, joint in pairs(world:getJoints()) do
        local jointData = jointForFile(joint)
        if jointData then table.insert(saveData.joints, jointData) end
    end
    local camx, camy = camera:getTranslation()
    saveData.camera = {
        rotation = camera:getRotation(),
        x = camx,
        y = camy,
        scale = camera:getScale(),
        settings = cameraFollow.saveSettings(),
    }
    saveData.music = roomMusic.save()
    return saveData
end

-- Writes the world to <filename>.playtime.json in the save directory: numbers rounded to 4
-- decimals (sub-pixel at any reasonable scale), influences packed (docs/FILESIZE-ANALYSIS.md).
function lib.save(world, camera, filename)
    local saveData = lib.roundFloats(lib.gatherSaveData(world, camera), 4)
    for _, body in ipairs(saveData.bodies or {}) do
        for _, fix in ipairs(body.fixtures or {}) do
            influences.forFile(fix.userData and fix.userData.extra)
        end
    end
    local jsonData = json.encode(saveData, { indent = true })

    local success, message = love.filesystem.write(filename .. FEXT.SCENE_JSON, jsonData)
    if success then
        logger:info("World successfully saved to " .. filename)
        logger:info("file://" .. love.filesystem.getSaveDirectory())
    else
        logger:error("Failed to save world:", message)
    end

    love.system.openURL("file://" .. love.filesystem.getSaveDirectory())
end

return lib

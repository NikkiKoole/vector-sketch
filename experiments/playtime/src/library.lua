-- library.lua
-- Prefabs: a saved selection of bodies + the joints between them, as data in
-- library/<name>.playtime.json (in the save directory). Placing one builds a
-- fresh copy next to what's on the stage. Props stay code (src/props.lua);
-- prefabs are data. A Mipo is saved as its DNA (`mipos`: dna, scale, torso
-- position), not its bodies, and placing grows it fresh from that DNA, standing
-- in T-pose like 'add mipo'. Any selected part saves the whole Mipo.
-- See docs/EDITOR-INSPECTOR-LIBRARY.md, slice 3.
local lib = {}

local json = require('vendor.dkjson')
local state = require('src.state')
local uuid = require('src.uuid')
local camera = require('src.camera')
local sceneIO = require('src.io')
local snap = require('src.physics.snap')
local FEXT = require('src.file-extensions')
local signals = require('src.signals')
local resourceLink = require('src.resource-link')

lib.DIR = 'library'

function lib.cleanName(name)
    name = tostring(name or ''):lower():gsub('[^%w%-_]+', '-'):gsub('^%-+', ''):gsub('%-+$', '')
    return name
end

local function pathOf(name)
    return lib.DIR .. '/' .. name .. FEXT.SCENE_JSON
end

-- prefab names, sorted
function lib.list()
    local names = {}
    for _, file in ipairs(love.filesystem.getDirectoryItems(lib.DIR)) do
        local name = file:match('^(.*)' .. FEXT.SCENE_JSON:gsub('%.', '%%.') .. '$')
        if name then table.insert(names, name) end
    end
    table.sort(names)
    return names
end

-- The save data of these things, the joints between them and the Mipos any of
-- them belong to, positions relative to their centre. nil when nothing is left.
function lib.gather(things)
    local ids, mipoIds = {}, {}
    for _, thing in ipairs(things) do
        if thing.body and not thing.body:isDestroyed() then
            if thing.mipoId then mipoIds[thing.mipoId] = true else ids[thing.id] = true end
        end
    end
    if not next(ids) and not next(mipoIds) then return nil end
    local bodies = {}
    for _, thing in ipairs(things) do
        if ids[thing.id] then table.insert(bodies, thing.body) end
    end
    resourceLink.linkBodies(bodies) -- meshes carry their RESOURCE link

    return lib.trim(sceneIO.gatherSaveData(state.physicsWorld, camera.getInstance()), ids, mipoIds)
end

-- where a saved Mipo stands: its torso's position in the save data
local function mipoPosition(data, mipoId)
    local fallback
    for _, bodyData in ipairs(data.bodies or {}) do
        if bodyData.mipoId == mipoId then
            if bodyData.mipoPartName == 'torso1' then return bodyData.position end
            fallback = fallback or bodyData.position
        end
    end
    return fallback
end

-- Save data -> prefab: the bodies whose id is in ids and the Mipos whose id is
-- in mipoIds (when nil: every body and every Mipo), the joints between the
-- bodies, centred. nil when nothing is left.
function lib.trim(data, ids, mipoIds)
    local prefab = { version = data.version, bodies = {}, joints = {}, mipos = {} }
    local kept = {}
    local cx, cy, n = 0, 0, 0
    for _, bodyData in ipairs(data.bodies or {}) do
        if not bodyData.mipoId and (not ids or ids[bodyData.id]) then
            table.insert(prefab.bodies, bodyData)
            kept[bodyData.id] = true
            cx, cy, n = cx + bodyData.position[1], cy + bodyData.position[2], n + 1
        end
    end
    for _, character in ipairs(data.characters or {}) do
        local position = (not mipoIds or mipoIds[character.id]) and mipoPosition(data, character.id)
        if position then
            table.insert(prefab.mipos, { dna = character.dna, scale = character.scale,
                position = { position[1], position[2] } })
            cx, cy, n = cx + position[1], cy + position[2], n + 1
        end
    end
    if n == 0 then return nil end
    cx, cy = cx / n, cy / n
    for _, jointData in ipairs(data.joints or {}) do
        if kept[jointData.bodyA] and kept[jointData.bodyB] then
            table.insert(prefab.joints, jointData)
        end
    end
    lib.move(prefab, -cx, -cy)
    return prefab
end

-- shift every world position in the prefab data
function lib.move(prefab, dx, dy)
    for _, mipo in ipairs(prefab.mipos or {}) do
        mipo.position[1], mipo.position[2] = mipo.position[1] + dx, mipo.position[2] + dy
    end
    for _, bodyData in ipairs(prefab.bodies) do
        bodyData.position[1], bodyData.position[2] = bodyData.position[1] + dx, bodyData.position[2] + dy
    end
    for _, jointData in ipairs(prefab.joints) do
        for _, key in ipairs({ 'anchorA', 'anchorB' }) do
            local a = jointData[key]
            if a then a[1], a[2] = a[1] + dx, a[2] + dy end
        end
        local props = jointData.properties or {}
        for _, key in ipairs({ 'groundAnchor1', 'groundAnchor2' }) do
            local a = props[key]
            if a then a.x, a.y = a.x + dx, a.y + dy end
        end
    end
end

-- Give every body, sfixture and joint a new id, everywhere it's mentioned
-- (joints, influences, snap links...), so a prefab can be placed many times.
function lib.renewIds(prefab)
    local newIds = {}
    local function claim(id)
        if id ~= nil then newIds[id] = uuid.generateID() end
    end
    for _, bodyData in ipairs(prefab.bodies) do
        claim(bodyData.id)
        for _, fixtureData in ipairs(bodyData.fixtures or {}) do
            claim(fixtureData.userData and fixtureData.userData.id)
        end
    end
    for _, jointData in ipairs(prefab.joints) do claim(jointData.id) end

    local function walk(t)
        local renamed = {}
        for k, v in pairs(t) do
            if type(v) == 'table' then
                walk(v)
            elseif newIds[v] then
                t[k] = newIds[v]
            end
            if newIds[k] then renamed[k] = newIds[k] end
        end
        for old, new in pairs(renamed) do
            t[new], t[old] = t[old], nil
        end
    end
    walk(prefab)
end

function lib.save(name, things)
    name = lib.cleanName(name)
    if name == '' then return false, 'no name' end
    local prefab = lib.gather(things)
    if not prefab then return false, 'nothing to save' end
    love.filesystem.createDirectory(lib.DIR)
    local ok, err = love.filesystem.write(pathOf(name), json.encode(prefab, { indent = true }))
    return ok, err or name
end

-- A scene file (or prefab) dropped on the library tab: its non-Mipo bodies and
-- their joints become a prefab named after the file.
function lib.import(filename, contents)
    local name = lib.cleanName(filename:match('([^/\\]+)$'):gsub('%.playtime%.json$', ''))
    local data = type(contents) == 'string' and json.decode(contents)
    if type(data) ~= 'table' or type(data.bodies) ~= 'table' then return false, 'not a scene file' end
    sceneIO.prepareLoaded(data)
    local prefab = lib.trim(data)
    if not prefab then return false, 'nothing in it' end
    if name == '' then name = 'imported' end
    love.filesystem.createDirectory(lib.DIR)
    local ok, err = love.filesystem.write(pathOf(name), json.encode(prefab, { indent = true }))
    return ok, err or name
end

function lib.load(name)
    local contents = love.filesystem.read(pathOf(name))
    if not contents then return nil end
    local prefab = json.decode(contents)
    if type(prefab) ~= 'table' or type(prefab.bodies) ~= 'table' then return nil end
    prefab.joints = prefab.joints or {}
    return prefab
end

-- build a copy of the prefab centred on world x, y; returns its things
function lib.place(name, x, y)
    local prefab = lib.load(name)
    if not prefab then return {} end
    lib.renewIds(prefab)
    local behaviorLists = {}
    for _, bodyData in ipairs(prefab.bodies) do
        if bodyData.behaviors then table.insert(behaviorLists, bodyData.behaviors) end
    end
    signals.renameForCopy(behaviorLists, signals.namesInUse())
    lib.move(prefab, x, y)
    local things = {}
    if #prefab.bodies > 0 then
        things = sceneIO.buildWorld(prefab, state.physicsWorld, camera.getInstance(), { additive = true }) or {}
        snap.onSceneLoaded()
    end
    -- Mipos grow fresh from their DNA, with their own id, collision group and z-range
    local CharacterManager = require('src.character-manager')
    for _, mipo in ipairs(prefab.mipos or {}) do
        local instance = CharacterManager.createCharacterFromJustDNA(mipo.dna, mipo.position[1], mipo.position[2],
            mipo.scale)
        if instance then
            CharacterManager.poseTpose(instance)
            for _, part in pairs(instance.parts) do table.insert(things, part) end
        end
    end
    return things
end

function lib.delete(name)
    return love.filesystem.remove(pathOf(name))
end

return lib

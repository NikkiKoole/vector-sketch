-- library.lua
-- Prefabs: a saved selection of bodies + the joints between them, as data in
-- library/<name>.playtime.json (in the save directory). Placing one builds a
-- fresh copy next to what's on the stage. Props stay code (src/props.lua);
-- prefabs are data. Mipo parts are left out: a Mipo is more than its bodies.
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

-- The save data of these things (Mipo parts skipped) and the joints between
-- them, positions relative to their centre. Returns nil when nothing is left.
function lib.gather(things)
    local ids, count = {}, 0
    for _, thing in ipairs(things) do
        if thing.body and not thing.body:isDestroyed() and not thing.mipoId then
            ids[thing.id] = true
            count = count + 1
        end
    end
    if count == 0 then return nil end
    local bodies = {}
    for _, thing in ipairs(things) do
        if ids[thing.id] then table.insert(bodies, thing.body) end
    end
    resourceLink.linkBodies(bodies) -- meshes carry their RESOURCE link

    return lib.trim(sceneIO.gatherSaveData(state.physicsWorld, camera.getInstance()), ids)
end

-- Save data -> prefab: the bodies whose id is in ids (all non-Mipo bodies when
-- ids is nil), the joints between them, centred. nil when no body is left.
function lib.trim(data, ids)
    local prefab = { version = data.version, bodies = {}, joints = {} }
    local kept = {}
    local cx, cy = 0, 0
    for _, bodyData in ipairs(data.bodies or {}) do
        if (ids and ids[bodyData.id]) or (not ids and not bodyData.mipoId) then
            table.insert(prefab.bodies, bodyData)
            kept[bodyData.id] = true
            cx, cy = cx + bodyData.position[1], cy + bodyData.position[2]
        end
    end
    if #prefab.bodies == 0 then return nil end
    cx, cy = cx / #prefab.bodies, cy / #prefab.bodies
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
    if not prefab then return false, 'nothing to save (Mipos are left out)' end
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
    if not prefab then return false, 'no bodies in it (Mipos are left out)' end
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
    local things = sceneIO.buildWorld(prefab, state.physicsWorld, camera.getInstance(), { additive = true })
    snap.onSceneLoaded()
    return things or {}
end

function lib.delete(name)
    return love.filesystem.remove(pathOf(name))
end

return lib

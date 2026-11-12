-- src/kinds.lua: things made of bodies (docs/KINDS.md). A kind is a module that makes its parts out of
-- ordinary things (objectManager bodies, joints); a placed one is an instance { id, kind, settings, parts }.
-- Each part's thing carries `kindId` and `kindPart` (saved with the body, as a Mipo part's mipoId), and the
-- scene saves the instances' kind and settings (saveData.kinds). The bodies stay the truth: dissolve drops
-- the tags and leaves plain bodies; a file whose kind is gone loads as plain bodies.
--
-- A kind module: { make = function(settings, x, y) -> { [partName] = thing }, label = function(instance) }.
-- First kind: vehicles (src/vehicles.lua, KD4). The Mipo stays in its own registry for now (KD2).
local lib = {}

local state = require('src.state')
local utils = require('src.utils')
local uuid = require('src.uuid')

-- the kinds there are: name -> module, looked up per call so a hot swap holds
lib.MODULES = { vehicle = 'src.vehicles' }

-- on state, so a hot swap of this file keeps the live instances
state.kindInstances = state.kindInstances or {}

local function alive(body) return body ~= nil and not body:isDestroyed() end

function lib.kindOf(name)
    local path = lib.MODULES[name]
    return path and require(path) or nil
end

local function register(instance)
    state.kindInstances[instance.id] = instance
    return instance
end

local function tag(instance, partName, thing)
    thing.kindId, thing.kindPart = instance.id, partName
    instance.parts[partName] = thing
end

-- Make one at world x, y; returns the instance, or nil.
function lib.make(name, settings, x, y)
    local kind = lib.kindOf(name)
    if not kind then return nil end
    settings = settings or {}
    local parts = kind.make(settings, x, y)
    if not parts then return nil end
    local instance = { id = uuid.generateID(), kind = name, settings = settings, parts = {} }
    for partName, thing in pairs(parts) do tag(instance, partName, thing) end
    return register(instance)
end

-- The instance a body belongs to and its part's name, or nil.
function lib.ofBody(body)
    if not alive(body) then return nil end
    local thing = utils.thingOf(body)
    local instance = thing and thing.kindId and state.kindInstances[thing.kindId]
    if instance then return instance, thing.kindPart end
    return nil
end

function lib.getById(id) return state.kindInstances[id] end

-- its live parts' things and bodies
function lib.things(instance)
    local list = {}
    for _, thing in pairs(instance.parts) do
        if alive(thing.body) then list[#list + 1] = thing end
    end
    return list
end

function lib.bodies(instance)
    local list = {}
    for _, thing in ipairs(lib.things(instance)) do list[#list + 1] = thing.body end
    return list
end

function lib.label(instance)
    local kind = lib.kindOf(instance.kind)
    return (kind and kind.label and kind.label(instance)) or instance.kind
end

-- Forget it's one: its bodies stay, plain, the workshop's now.
function lib.dissolve(instance)
    for _, thing in pairs(instance.parts) do thing.kindId, thing.kindPart = nil, nil end
    state.kindInstances[instance.id] = nil
end

-- Take it out of the world, bodies and all.
function lib.remove(instance)
    local objectManager = require('src.object-manager')
    local snap = require('src.physics.snap')
    for _, body in ipairs(lib.bodies(instance)) do
        snap.destroySnapJointAboutBody(body)
        objectManager.destroyBody(body)
    end
    state.kindInstances[instance.id] = nil
end

-- Made again with new settings (another type, size): the same instance and id, in the same place (its
-- `anchor` part, the kind's or the first by name, where it was), upright. A part selected before is
-- selected again by its name. Changes made to its bodies in the workshop since are lost (they're the
-- kind's again). Returns the instance, or nil (the old bodies stay when the new ones can't be made).
function lib.rebuild(instance, settings)
    local kind = lib.kindOf(instance.kind)
    if not kind then return nil end
    local function anchorOf(parts)
        if kind.anchor and parts[kind.anchor] then return parts[kind.anchor] end
        local names = {}
        for name in pairs(parts) do names[#names + 1] = name end
        table.sort(names)
        return parts[names[1]]
    end
    local old = anchorOf(instance.parts)
    if not (old and alive(old.body)) then return nil end
    local ox, oy = old.body:getPosition()
    local parts = kind.make(settings, 0, 0)
    if not parts then return nil end
    local sel = state.selection
    local selectedName = sel.selectedObj and sel.selectedObj.kindId == instance.id and sel.selectedObj.kindPart
    local objectManager = require('src.object-manager')
    for _, body in ipairs(lib.bodies(instance)) do
        require('src.physics.snap').destroySnapJointAboutBody(body)
        objectManager.destroyBody(body)
    end
    instance.settings, instance.parts = settings, {}
    local nx, ny = anchorOf(parts).body:getPosition()
    for partName, thing in pairs(parts) do
        local x, y = thing.body:getPosition()
        thing.body:setPosition(x + ox - nx, y + oy - ny)
        tag(instance, partName, thing)
    end
    if selectedName and instance.parts[selectedName] then sel.selectedObj = instance.parts[selectedName] end
    return instance
end

-- every instance with a live part
function lib.all()
    local list = {}
    for _, instance in pairs(state.kindInstances) do
        if #lib.things(instance) > 0 then list[#list + 1] = instance end
    end
    return list
end

-- A new scene: none. Emptied in place (the table is shared through state).
function lib.reset()
    for id in pairs(state.kindInstances) do state.kindInstances[id] = nil end
end

-- The scene's instances for the file: { { id, kind, settings } }; nil when there are none.
function lib.save()
    local list = {}
    for _, instance in ipairs(lib.all()) do
        list[#list + 1] = { id = instance.id, kind = instance.kind, settings = utils.deepCopy(instance.settings) }
    end
    table.sort(list, function(a, b) return a.id < b.id end) -- the same file for the same scene
    return #list > 0 and list or nil
end

-- After a scene's (or a prefab's, a copy's) bodies are built: their instances again, from the saved
-- list and the things' kindId / kindPart. A body whose instance isn't in the list (or whose kind is
-- gone) is left plain.
function lib.load(saved, things)
    local byId = {}
    for _, entry in ipairs(saved or {}) do
        if entry.id and lib.MODULES[entry.kind] then byId[entry.id] = entry end
    end
    for _, thing in ipairs(things or {}) do
        local entry = thing.kindId and byId[thing.kindId]
        if entry then
            local instance = state.kindInstances[entry.id]
                or register({ id = entry.id, kind = entry.kind, settings = utils.deepCopy(entry.settings or {}),
                    parts = {} })
            tag(instance, thing.kindPart or thing.id, thing)
        elseif thing.kindId then
            thing.kindId, thing.kindPart = nil, nil
        end
    end
end

-- Save data's entries for these kind ids (a prefab, a copy), deep copied.
function lib.entriesFor(saved, ids)
    local list = {}
    for _, entry in ipairs(saved or {}) do
        if ids[entry.id] then list[#list + 1] = utils.deepCopy(entry) end
    end
    return list
end

return lib

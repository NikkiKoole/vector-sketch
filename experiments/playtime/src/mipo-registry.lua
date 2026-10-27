local lib = {}
local state = require('src.state')

-- Kept on state (not a module local) so a lurker hot-reload of this file doesn't
-- start a fresh, empty table and silently drop every live Mipo.
state.mipoInstances = state.mipoInstances or {}
local instances = state.mipoInstances

function lib.register(instance)
    instances[instance.id] = instance
end

function lib.unregister(id)
    instances[id] = nil
end

function lib.getById(id)
    return instances[id]
end

-- Find which instance a body belongs to (via thing.mipoId)
function lib.getFromBody(body)
    if not body or body:isDestroyed() then return nil, nil end
    local ud = body:getUserData()
    if ud and ud.thing and ud.thing.mipoId then
        return instances[ud.thing.mipoId], ud.thing.mipoPartName
    end
    return nil, nil
end

-- A Mipo whose bodies were all destroyed some other way (e.g. selecting it in
-- the editor and pressing destroy) would otherwise stay listed and be saved into
-- the scene as a ghost character.
local function hasLiveParts(instance)
    for _, part in pairs(instance.parts or {}) do
        if part.body and not part.body:isDestroyed() then return true end
    end
    return false
end

function lib.getAll()
    for id, instance in pairs(instances) do
        if instance.parts and next(instance.parts) and not hasLiveParts(instance) then
            instances[id] = nil
        end
    end
    return instances
end

function lib.reset()
    for id in pairs(instances) do instances[id] = nil end
end

return lib

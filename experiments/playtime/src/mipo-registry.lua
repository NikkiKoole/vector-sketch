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

function lib.getAll()
    return instances
end

function lib.reset()
    for id in pairs(instances) do instances[id] = nil end
end

return lib

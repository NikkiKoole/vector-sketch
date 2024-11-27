-- src/registry.lua
local registry = {
    bodies = {}, -- [id] = body
    joints = {}, -- [id] = joint
    -- Add more categories if needed
}
function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

-- Register a body
function registry.registerBody(id, body)
    registry.bodies[id] = body
    -- print('bodies:', tablelength(registry.bodies))
end

-- Unregister a body
function registry.unregisterBody(id)
    registry.bodies[id] = nil
    --  print('bodies:', tablelength(registry.bodies))
end

-- Get a body by ID
function registry.getBodyByID(id)
    return registry.bodies[id]
end

-- Register a joint
function registry.registerJoint(id, joint)
    registry.joints[id] = joint
    --print('joints:', tablelength(registry.joints))
end

-- Unregister a joint
function registry.unregisterJoint(id)
    registry.joints[id] = nil
    --print('joints:', tablelength(registry.joints))
end

-- Get a joint by ID
function registry.getJointByID(id)
    return registry.joints[id]
end

-- Reset the registry (useful when loading a new world)
function registry.reset()
    registry.bodies = {}
    registry.joints = {}
end

return registry

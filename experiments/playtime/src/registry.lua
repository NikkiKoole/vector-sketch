-- registry.lua
local utils = require 'src.utils'
--local snap = require 'src.snap'
local registry = {
    bodies = {}, -- [id] = body
    joints = {}, -- [id] = joint
    sfixtures = {},
    groups = {}
    -- Add more categories if needed
}

function registry.print()
    return '#b:' ..
        utils.tablelength(registry.bodies) ..
        ', #j:' .. utils.tablelength(registry.joints) .. ' #sf:' .. utils.tablelength(registry.sfixtures)
end

-- Register a body
function registry.registerBody(id, body)
    registry.bodies[id] = body
end

-- Unregister a body
function registry.unregisterBody(id)
    registry.bodies[id] = nil
end

-- Get a body by ID
function registry.getBodyByID(id)
    return registry.bodies[id]
end

-- Register a joint
function registry.registerJoint(id, joint)
    registry.joints[id] = joint
end

-- Unregister a joint
function registry.unregisterJoint(id)
    if not registry.joints[id] then
        logger:info('no s joint to unregister here', id)
    end
    --logger:info('unregistering joit ', id)
    registry.joints[id] = nil
end

-- Get a joint by ID
function registry.getJointByID(id)
    return registry.joints[id]
end

-- sfixtures
function registry.registerSFixture(id, sfix)
    registry.sfixtures[id] = sfix
    snap.rebuildSnapFixtures(registry.sfixtures)
end

function registry.unregisterSFixture(id)
    if not registry.sfixtures[id] then
        logger:info('no s fixture to unregister here')
    end
    registry.sfixtures[id] = nil
    snap.rebuildSnapFixtures(registry.sfixtures)
end

function registry.getSFixtureByID(id)
    return registry.sfixtures[id]
end

-- Reset the registry (useful when loading a new world)
function registry.reset()
    registry.bodies = {}
    registry.joints = {}
    registry.sfixtures = {}
    snap.rebuildSnapFixtures(registry.sfixtures)
end

return registry

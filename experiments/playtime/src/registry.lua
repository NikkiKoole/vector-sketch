-- registry.lua
local logger = require 'src.logger'
local utils = require 'src.utils'
-- snap is required lazily to avoid circular dependency (snap requires registry)
local snap
local function getSnap()
    if not snap then snap = require 'src.physics.snap' end
    return snap
end
local registry = {
    bodies = {}, -- [id] = body
    joints = {}, -- [id] = joint
    sfixtures = {},
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
-- Rebuilding the snap-fixture list on every (un)register is O(N) per call —
-- O(N²) across a scene load. beginBatch/endBatch defer it to one rebuild;
-- outside a batch the rebuild stays synchronous (specs and editor code rely
-- on state.snap.fixtures being current right after a register).
local batchDepth = 0

function registry.beginBatch()
    batchDepth = batchDepth + 1
end

function registry.endBatch()
    batchDepth = math.max(0, batchDepth - 1)
    if batchDepth == 0 then
        getSnap().rebuildSnapFixtures(registry.sfixtures)
    end
end

local function maybeRebuildSnap()
    if batchDepth == 0 then
        getSnap().rebuildSnapFixtures(registry.sfixtures)
    end
end

function registry.registerSFixture(id, sfix)
    registry.sfixtures[id] = sfix
    maybeRebuildSnap()
end

function registry.unregisterSFixture(id)
    if not registry.sfixtures[id] then
        logger:info('no s fixture to unregister here')
    end
    registry.sfixtures[id] = nil
    maybeRebuildSnap()
end

function registry.getSFixtureByID(id)
    return registry.sfixtures[id]
end

function registry.taken(id)
    return registry.bodies[id] or registry.joints[id] or registry.sfixtures[id]
end

-- Reset the registry (useful when loading a new world)
function registry.reset()
    registry.bodies = {}
    registry.joints = {}
    registry.sfixtures = {}
    batchDepth = 0 -- recover from a load that errored mid-batch
    getSnap().rebuildSnapFixtures(registry.sfixtures)
end

return registry

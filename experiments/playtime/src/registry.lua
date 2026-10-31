-- registry.lua
local logger = require('src.logger')
local utils = require('src.utils')
local registry = {
    bodies = {}, -- [id] = body
    joints = {}, -- [id] = joint
    sfixtures = {},
    -- Add more categories if needed
    -- goes up whenever an sfixture is added, replaced or removed: the renderer keeps its draw
    -- list until it changes (physics/box2d-draw-textured.lua)
    sfixtureVersion = 0,
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

-- The Mipo parts whose sfixtures keep their contacts: a Mipo stands when one of these touches
-- something, its picture's sensor too (mipo-actions.isGrounded; the solid foot alone flickers
-- while it balances, and Mipos stood differently).
registry.GROUND_PARTS = { lfoot = true, rfoot = true, llleg = true, rlleg = true }

-- sfixtures
function registry.registerSFixture(id, sfix)
    registry.sfixtures[id] = sfix
    -- Other sfixtures never collide: they're sensors for drawing (textures, ribbons, decals)
    -- or found by distance (snap, liquid, grass), not through contacts. Box2D still made a
    -- contact for every overlap and the callbacks went to Lua: with 40 Mipos 22000 contacts,
    -- three quarters with an sfixture, 10 fps on a desktop (2026-10-31). Picking
    -- (queryBoundingBox, testPoint) doesn't look at masks.
    if not sfix:isDestroyed() then registry.updateSFixtureMask(sfix) end
    registry.sfixtureVersion = registry.sfixtureVersion + 1
end

function registry.updateSFixtureMask(sfix)
    local ud = sfix:getBody():getUserData()
    local thing = type(ud) == 'table' and ud.thing
    if thing and registry.GROUND_PARTS[thing.mipoPartName] then
        sfix:setMask() -- collides with everything again
    else
        sfix:setMask(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)
    end
end

-- Again for a body's sfixtures once it knows which Mipo part it is: a scene load registers
-- them before the body has its thing, a Mipo build names the part after making it.
function registry.updateSFixtureMasks(body)
    for _, fixture in ipairs(body:getFixtures()) do
        if type(fixture:getUserData()) == 'table' then registry.updateSFixtureMask(fixture) end
    end
end

function registry.unregisterSFixture(id)
    if not registry.sfixtures[id] then
        logger:info('no s fixture to unregister here')
    end
    registry.sfixtures[id] = nil
    registry.sfixtureVersion = registry.sfixtureVersion + 1
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
    registry.sfixtureVersion = registry.sfixtureVersion + 1
end

return registry

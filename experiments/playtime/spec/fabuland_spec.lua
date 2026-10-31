-- Specs for src/fabuland.lua: every part builds, with stiff snap points on the 250 grid, and
-- two parts stacked on the grid weld together square (snap.lua's stiff points).

if not love then return end

local fabuland = require('src.fabuland')
local snap = require('src.physics.snap')
local registry = require('src.registry')
local state = require('src.state')
local subtypes = require('src.subtypes')
local mipoRegistry = require('src.mipo-registry')

describe('fabuland', function()
    local prevOnlyConnect

    before_each(function()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        registry.reset()
        mipoRegistry.reset()
        snap.reset()
        prevOnlyConnect = state.snap.onlyConnectWhenInteracted
        state.snap.onlyConnectWhenInteracted = false
    end)

    after_each(function()
        state.snap.onlyConnectWhenInteracted = prevOnlyConnect
        snap.reset()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    local function stiffPoints(body)
        local n = 0
        for _, fixture in ipairs(body:getFixtures()) do
            local ud = fixture:getUserData()
            if subtypes.is(ud, subtypes.SNAP) and ud.extra.stiff then n = n + 1 end
        end
        return n
    end

    for _, part in ipairs(fabuland.PARTS) do
        it('builds a ' .. part.name .. ' with its snap points, found again by its label', function()
            local thing = fabuland.make(part.name, 0, 0)
            assert.is_truthy(thing)
            assert.are.equal(#fabuland.snapPoints(part), stiffPoints(thing.body))
            local found, set = fabuland.partOf(thing.body)
            assert.are.equal(part, found)
            assert.is_truthy(fabuland.SETS[set])
        end)
    end

    it('puts snap points on the grid cells of an edge, counted from its start', function()
        local block = { w = 750, h = 1000, snaps = { 'top' } }
        local xs = {}
        for _, p in ipairs(fabuland.snapPoints(block)) do xs[#xs + 1] = p[1] end
        assert.are.same({ -250, 0, 250 }, xs)
    end)

    it('welds a block stacked on another, turned square', function()
        local below = fabuland.make('block', 0, 0, 'yellow')
        local above = fabuland.make('window block', 0, -1000, 'red')
        above.body:setAngle(0.2) -- dropped on a little crooked
        snap.update(1 / 60)
        local joints = snap.joints()
        assert.are.equal(1, #joints)
        assert.are.equal('weld', joints[1]:getType())
        assert.is_near(0, joints[1]:getReferenceAngle(), 1e-6)
    end)
end)

describe('the fabuland scene', function()
    local sceneLoader = require('src.scene-loader')
    local script = require('src.script')

    it('loads, turns the drawing on, builds the kit with a welded house, once', function()
        if not state.physicsWorld or state.physicsWorld:isDestroyed() then
            state.physicsWorld = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        end
        sceneLoader.loadScriptAndScene('fabuland')
        assert.is_true(state.fabuland and state.fabuland.on)
        local parts = 0
        for _, body in ipairs(state.physicsWorld:getBodies()) do
            if fabuland.partOf(body) then parts = parts + 1 end
        end
        assert.are.equal(9, parts)
        local welds = 0
        for _, joint in ipairs(snap.joints()) do
            if joint:getType() == 'weld' then welds = welds + 1 end
        end
        assert.is_true(welds >= 3) -- the blocks side by side, the roofs on them
        script.call('onStart') -- again: no second kit
        parts = 0
        for _, body in ipairs(state.physicsWorld:getBodies()) do
            if fabuland.partOf(body) then parts = parts + 1 end
        end
        assert.are.equal(9, parts)
        script.call('onUnload')
        assert.is_nil(state.fabuland)
    end)
end)

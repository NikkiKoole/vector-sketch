-- spec/pouring_spec.lua
-- Water poured out of cups (src/pouring.lua, ENGINE-MERGE EM3): what spills over a rim leaves as particle water
-- at most FLOW a second, the rest goes back in; the points land in another container and join its water.
-- Run with: love . --specs spec/pouring_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local props = require('src.props')
local pouring = require('src.pouring')

describe('pouring', function()
    before_each(function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        state.pouring = nil
    end)

    after_each(function()
        pouring.unload()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        state.pouring = nil
        registry.reset()
    end)

    it('turns what spills into points, keeping the rest in the cup', function()
        local cup = props.makeCup(0, 0, 1)
        local extra
        for _, f in ipairs(cup.body:getFixtures()) do
            local ud = f:getUserData()
            if ud and ud.subtype == 'liquid' then extra = ud.extra end
        end
        extra.fill = 0.5
        pouring.onSpill(extra, cup.body, 1e7) -- far more than a frame's flow
        assert.is_true(state.pouring.f.n > 0, 'points made')
        assert.is_true(extra.fill > 0.5, 'what couldn\'t leave this frame went back in')
    end)

    it('lets a point falling into a bath join its water', function()
        local bath = props.makeBath(0, 500, 1)
        local extra
        for _, f in ipairs(bath.body:getFixtures()) do
            local ud = f:getUserData()
            if ud and ud.subtype == 'liquid' then extra = ud.extra end
        end
        local before = extra.fill
        state.liquidSpillHook = nil
        pouring.update(0) -- takes the spill hook
        local f = state.pouring.f or (function()
            pouring.onSpill(extra, bath.body, 0) -- makes the points' water
            return state.pouring.f
        end)()
        require('src.fluid').add(f, 0, 500, 0, 300) -- inside the bath, falling
        f.px[0], f.py[0] = 0, 495
        pouring.update(1 / 60)
        assert.is_true(extra.fill > before, string.format('fill %.4f -> %.4f', before, extra.fill))
    end)
end)

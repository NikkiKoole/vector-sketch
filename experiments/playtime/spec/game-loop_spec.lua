-- spec/game-loop_spec.lua
-- The speed slider (state.world.speedMultiplier) works in one place, the physics
-- step. It used to also add or skip whole updates in the loop: 2x ran about 4x,
-- and slow motion skipped input too (BUG6, docs/CODE-BUGS-2026-10.md).

local gameLoop = require('src.game-loop')

local function near(expected, actual)
    assert.is_true(math.abs(expected - actual) < 1e-9, 'expected ' .. expected .. ', got ' .. actual)
end

describe('gameLoop.physicsSteps', function()
    local dt = 1 / 60

    it('takes one normal step at 1x', function()
        local steps, step = gameLoop.physicsSteps(dt, 1)
        assert.are.equal(1, steps)
        near(dt, step)
    end)

    it('takes one smaller step in slow motion', function()
        local steps, step = gameLoop.physicsSteps(dt, 0.25)
        assert.are.equal(1, steps)
        near(dt / 4, step)
    end)

    it('takes more steps, none longer than dt, when fast', function()
        for _, speed in ipairs({ 1.5, 2, 3.7, 10 }) do
            local steps, step = gameLoop.physicsSteps(dt, speed)
            near(dt * speed, steps * step) -- the world moves speed times as far
            assert.is_true(step <= dt + 1e-12)
        end
    end)
end)

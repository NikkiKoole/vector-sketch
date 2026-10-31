-- Specs for src/timers.lua — the scene's waits and tweens (F3, docs/DOLL-PLAY.md).

if not love then return end

local timers = require('src.timers')
local script = require('src.script')

describe('timers', function()
    before_each(function() timers.clear() end)
    after_each(function() timers.clear() end)

    it('runs an after once its time has passed', function()
        local hits = 0
        timers.after(0.5, function() hits = hits + 1 end)
        timers.update(0.4)
        assert.equal(0, hits)
        timers.update(0.2)
        assert.equal(1, hits)
        timers.update(1)
        assert.equal(1, hits)
    end)

    it('tweens a value to its target', function()
        local head = { angle = 0 }
        timers.tween(1, head, { angle = 2 }, 'linear')
        timers.update(0.5)
        assert.is_near(1, head.angle, 1e-6)
        timers.update(0.6)
        assert.is_near(2, head.angle, 1e-6)
    end)

    it('steps a script through its waits', function()
        local steps = {}
        timers.script(function(wait)
            steps[#steps + 1] = 'a'
            wait(0.3)
            steps[#steps + 1] = 'b'
        end)
        assert.same({ 'a' }, steps)
        timers.update(0.4)
        assert.same({ 'a', 'b' }, steps)
    end)

    it('cancels and clears', function()
        local hits = 0
        local handle = timers.every(0.1, function() hits = hits + 1 end)
        timers.update(0.15)
        timers.cancel(handle)
        timers.update(1)
        assert.equal(1, hits)
        timers.after(0.1, function() hits = hits + 1 end)
        timers.clear()
        timers.update(1)
        assert.equal(1, hits)
    end)

    it('is in the scene script sandbox as timer', function()
        local s = script.loadScript(
            'local t = { x = 0 }\ntimer.tween(1, t, { x = 10 }, "linear")\nreturn { x = function() return t.x end }',
            'spec-timer-env')
        timers.update(1)
        assert.is_near(10, s.x(), 1e-6)
    end)
end)

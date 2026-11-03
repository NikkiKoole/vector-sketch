-- spec/synth-fx-volume_spec.lua
-- The settings panel's FX volume scales the world's sounds: synth.hit (impacts, snap clicks). It can't
-- live on the slot, because an impact may borrow a band patch whose slot the music is playing on, so
-- below full volume a hit is a held note at its own fractional volume, released by synth.update when its
-- time is up. At full volume a hit is exactly the plain hit it always was. The library is faked: it
-- records the calls.
-- Run with: love . --specs spec/synth-fx-volume_spec.lua

if not love then return end

local state = require('src.state')
local synth = require('src.synth')

describe('synth FX volume', function()
    local S, saved, calls, clock

    local function named(name)
        local out = {}
        for _, c in ipairs(calls) do if c.name == name then out[#out + 1] = c.args end end
        return out
    end

    before_each(function()
        S = state.synth
        saved = { started = S.started, C = S.C, pool = S.pool, fx = S.fx, fxHeld = S.fxHeld,
                  fxVolume = S.fxVolume, thread = S.thread }
        S.started, S.pool, S.fx, S.fxHeld, S.thread = true, {}, {}, nil, nil
        calls, clock = {}, 0
        local handles = 0
        S.C = setmetatable({
            audio_time = function() return clock end,
            note_on = function(...) calls[#calls + 1] = { name = 'note_on', args = { ... } }
                handles = handles + 1 return handles end,
        }, { __index = function(_, name)
            return function(...) calls[#calls + 1] = { name = name, args = { ... } } end
        end })
    end)

    after_each(function()
        S.started, S.C, S.pool, S.fx, S.fxHeld, S.thread =
            saved.started, saved.C, saved.pool, saved.fx, saved.fxHeld, saved.thread
        synth.setFxVolume(saved.fxVolume or 1)
    end)

    it('at full FX volume a hit is the plain hit, unchanged', function()
        synth.setFxVolume(1)
        synth.hit('click', 86, 5, 30, 10, 20)
        assert.are.equal(1, #named('hit_at'))
        assert.are.equal(0, #named('note_on'))
        assert.are.equal(5, named('hit_at')[1][3])
    end)

    it('below full volume it is a held note at the exact fraction, positioned', function()
        synth.setFxVolume(0.3)
        synth.hit('click', 86, 5, 30, 10, 20)
        assert.are.equal(0, #named('hit_at'))
        local on, vol, pos = named('note_on'), named('note_vol'), named('note_pos')
        assert.are.equal(1, #on)
        assert.are.equal(2, on[1][3])                      -- starts at the nearest whole step of 1.5
        assert.is_true(math.abs(vol[1][2] - 1.5) < 1e-9)   -- then the exact value
        assert.are.equal(10, pos[1][2])
    end)

    it('the held hit is released once its time is up, not before', function()
        synth.setFxVolume(0.5)
        synth.hit('click', 86, 4, 100)
        clock = 0.05
        synth.update(1 / 60)
        assert.are.equal(0, #named('note_off'))
        clock = 0.11
        synth.update(1 / 60)
        assert.are.equal(1, #named('note_off'))
        synth.update(1 / 60)
        assert.are.equal(1, #named('note_off'))           -- once
    end)

    it('at zero FX volume a hit makes no sound at all', function()
        synth.setFxVolume(0)
        synth.hit('click', 86, 5, 30)
        assert.are.equal(0, #named('hit_at') + #named('hit') + #named('note_on'))
    end)

    it('music notes ignore the FX volume', function()
        synth.setFxVolume(0)
        synth.scheduleAt('click', 1.0, 86, 5, 30)
        assert.are.equal(1, #named('schedule_at'))
    end)
end)

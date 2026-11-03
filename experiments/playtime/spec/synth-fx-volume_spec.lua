-- spec/synth-fx-volume_spec.lua
-- (also the MUSIC volume: booked notes carry it as NoteOpts.gain, see the last four cases)
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
                  fxVolume = S.fxVolume, musicVolume = S.musicVolume, thread = S.thread,
                  hasNoteAt = S.hasNoteAt, noteGain = S.noteGain }
        S.started, S.pool, S.fx, S.fxHeld, S.thread = true, {}, {}, nil, nil
        calls, clock = {}, 0
        local handles = 0
        S.C = setmetatable({
            audio_time = function() return clock end,
            note_on = function(...) calls[#calls + 1] = { name = 'note_on', args = { ... } }
                handles = handles + 1 return handles end,
            schedule_note_at = function(t, midi, slot, vol, dur, o)
                calls[#calls + 1] = { name = 'schedule_note_at', args = { t, midi, slot, vol, dur, o.gain, o.accent } } end,
        }, { __index = function(_, name)
            return function(...) calls[#calls + 1] = { name = name, args = { ... } } end
        end })
    end)

    after_each(function()
        S.started, S.C, S.pool, S.fx, S.fxHeld, S.thread =
            saved.started, saved.C, saved.pool, saved.fx, saved.fxHeld, saved.thread
        synth.setFxVolume(saved.fxVolume or 1)
        synth.setMusicVolume(saved.musicVolume or 1)
        S.hasNoteAt, S.noteGain = saved.hasNoteAt, saved.noteGain
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

    it('music notes carry the music volume as their own gain', function()
        synth.setMusicVolume(0.4)
        S.hasNoteAt, S.noteGain = nil, nil
        synth.scheduleAt('click', 1.0, 86, 5, 30, { accent = 0.5 })
        local n = named('schedule_note_at')
        assert.are.equal(1, #n)
        assert.are.equal(5, n[1][4])                        -- the whole-step vol is untouched...
        assert.is_true(math.abs(n[1][6] - 0.4) < 1e-6)     -- ...the gain does the scaling
        assert.is_true(math.abs(n[1][7] - 0.5) < 1e-6)     -- and the opts still travel
    end)

    it('at full music volume a plain note is the plain schedule_at, as before', function()
        synth.setMusicVolume(1)
        synth.scheduleAt('click', 1.0, 86, 5, 30)
        assert.are.equal(1, #named('schedule_at'))
        assert.are.equal(0, #named('schedule_note_at'))
    end)

    it('with a NoteOpts that has no gain (a hot-reloaded game) it scales the whole-step vol', function()
        synth.setMusicVolume(0.5)
        S.hasNoteAt, S.noteGain = true, false
        synth.scheduleAt('click', 1.0, 86, 6, 30)
        local a = named('schedule_at')
        assert.are.equal(1, #a)
        assert.are.equal(3, a[1][4])
        assert.are.equal(0, #named('schedule_note_at'))
    end)

    it('at zero music volume nothing is booked; the FX volume leaves it alone', function()
        synth.setMusicVolume(0)
        synth.setFxVolume(1)
        synth.scheduleAt('click', 1.0, 86, 5, 30)
        assert.are.equal(0, #named('schedule_at') + #named('schedule_note_at'))
        synth.hit('click', 86, 5, 30)
        assert.are.equal(1, #named('hit'))
    end)
end)

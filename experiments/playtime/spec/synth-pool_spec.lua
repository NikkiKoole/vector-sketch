-- spec/synth-pool_spec.lua
-- The engine has 48 instrument slots and every one was taken, so patches only one music style
-- plays (pool = true) share lib.poolSlots: a pool patch takes a slot on its first note, keeps it
-- while it plays, and a new one takes the slot whose notes ended longest ago. The library is faked:
-- it records which slot each note and each instrument() went to.
-- Run with: love . --specs spec/synth-pool_spec.lua

if not love then return end

local state = require('src.state')
local synth = require('src.synth')

describe('synth pool slots', function()
    local S, saved, notes, defined

    before_each(function()
        S = state.synth
        saved = { started = S.started, C = S.C, pool = S.pool }
        notes, defined = {}, {}
        S.started, S.pool = true, {}
        S.C = setmetatable({
            schedule_at = function(t, midi, slot) notes[#notes + 1] = { t = t, slot = slot } end,
            instrument = function(slot) defined[#defined + 1] = slot end,
            audio_time = function() return 0 end,
        }, { __index = function() return function() end end })
    end)

    after_each(function()
        S.started, S.C, S.pool = saved.started, saved.C, saved.pool
    end)

    local function isPoolSlot(slot)
        for _, s in ipairs(synth.poolSlots) do if s == slot then return true end end
        return false
    end

    it('keeps fixed patches on their own slot', function()
        synth.scheduleAt('rhodes', 1, 60, 4, 500)
        assert.are.equal(synth.patches.rhodes.slot, notes[1].slot)
        assert.are.equal(0, #defined)
    end)

    it('gives a pool patch a pool slot, loads it once, and keeps it', function()
        synth.scheduleAt('clav', 1, 60, 4, 200)
        synth.scheduleAt('clav', 1.5, 62, 4, 200)
        assert.is_true(isPoolSlot(notes[1].slot))
        assert.are.equal(notes[1].slot, notes[2].slot)
        assert.are.equal(1, #defined)
    end)

    it('gives patches that play together their own slots', function()
        for i, name in ipairs({ 'citySynth', 'cityGuitar', 'strings', 'horn' }) do synth.scheduleAt(name, i, 60, 4, 5000) end
        local seen = {}
        for _, note in ipairs(notes) do
            assert.is_nil(seen[note.slot])
            seen[note.slot] = true
        end
    end)

    it('hands out the slot that went quiet longest ago once every slot is taken', function()
        local poolSlots = synth.poolSlots
        synth.poolSlots = { poolSlots[1], poolSlots[2] } -- a pool of two, so three patches fill it
        synth.scheduleAt('clav', 1, 60, 4, 100)
        synth.scheduleAt('horn', 2, 60, 4, 100)
        synth.scheduleAt('citySynth', 40, 60, 4, 100) -- clav's note ended first
        synth.poolSlots = poolSlots
        assert.are.equal(notes[1].slot, notes[3].slot)
        assert.are.equal('citySynth', S.pool[notes[1].slot].name)
    end)
end)

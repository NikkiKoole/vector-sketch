-- spec/synth-pool_spec.lua
-- The engine has 48 instrument slots and every one was taken, so patches only one music style
-- plays (pool = true) share lib.poolSlots: a pool patch takes a slot on its first note, keeps it
-- while it plays, and a new one takes the slot whose notes ended longest ago. Patches with pedals
-- (fx = true) share lib.fxSlots the same way, because a slot's pedals claim one of the 7 FX buses
-- for good: loading one switches the bus's pedals off before putting on its own, and puts the
-- engine modes back to their defaults. The library is faked: it records the calls.
-- Run with: love . --specs spec/synth-pool_spec.lua

if not love then return end

local state = require('src.state')
local synth = require('src.synth')

describe('synth pool slots', function()
    local S, saved, notes, defined, calls

    before_each(function()
        S = state.synth
        saved = { started = S.started, C = S.C, pool = S.pool, fx = S.fx }
        notes, defined = {}, {}
        S.started, S.pool, S.fx = true, {}, {}
        calls = {}
        S.C = setmetatable({
            schedule_at = function(t, midi, slot) notes[#notes + 1] = { t = t, slot = slot } end,
            instrument = function(slot) defined[#defined + 1] = slot end,
            audio_time = function() return 0 end,
        }, { __index = function(_, name)
            return function(...) calls[#calls + 1] = { name = name, args = { ... } } end
        end })
    end)

    after_each(function()
        S.started, S.C, S.pool, S.fx = saved.started, saved.C, saved.pool, saved.fx
    end)

    local function isPoolSlot(slot)
        for _, s in ipairs(synth.poolSlots) do if s == slot then return true end end
        return false
    end

    it('keeps fixed patches on their own slot', function()
        synth.scheduleAt('kick', 1, 36, 4, 200)
        assert.are.equal(synth.patches.kick.slot, notes[1].slot)
        assert.are.equal(0, #defined)
    end)

    local function isFxSlot(slot)
        for _, s in ipairs(synth.fxSlots) do if s == slot then return true end end
        return false
    end
    local function callsTo(name, slot)
        local out = {}
        for _, c in ipairs(calls) do if c.name == name and c.args[1] == slot then out[#out + 1] = c.args end end
        return out
    end

    it('gives patches with pedals an effect slot, pedals off first, then their own', function()
        synth.scheduleAt('guitar', 1, 52, 4, 600)
        local slot = notes[1].slot
        assert.is_true(isFxSlot(slot))
        local flangers = callsTo('instrument_flanger', slot)
        assert.are.equal(2, #flangers)
        assert.are.equal(0, flangers[1][5])                                  -- off: mix 0
        assert.are.equal(synth.patches.guitar.flanger[4], flangers[2][5])    -- then the guitar's own
        local chorus = callsTo('instrument_chorus', slot)
        assert.are.equal(0, chorus[#chorus][4])                              -- the guitar has none: stays off
    end)

    it("puts the engine's modes back to its defaults, then the patch's own", function()
        synth.scheduleAt('piano', 1, 60, 4, 600)
        local modes = {}
        for _, args in ipairs(callsTo('instrument_mode', notes[1].slot)) do modes[args[2]] = args[3] end
        assert.are.equal(0.5, modes[2]) -- the piano's decay: 0.5 is as voiced (0 changed its sound)
        assert.are.equal(0.5, modes[5])
        assert.are.equal(0, modes[0])
    end)

    it('scales every pedal by the effects slider, inside the engine ranges, and back', function()
        local amount = synth.effectAmount()
        synth.scheduleAt('guitar', 1, 52, 4, 600)
        local slot = notes[1].slot
        calls = {}
        synth.setEffectAmount(2)
        local f = callsTo('instrument_flanger', slot)[1]
        local own = synth.patches.guitar.flanger
        assert.are.equal(own[1], f[2])                         -- the rate doesn't scale
        assert.are.equal(math.min(1, own[4] * 2), f[5])        -- the mix doubles
        synth.slotFlanger('guitar', 0.1, 1.0, 0.85, 0.8)
        local hard = callsTo('instrument_flanger', slot)[2]
        assert.are.equal(0.95, hard[4])                        -- feedback stops where it resonates
        assert.are.equal(1, hard[5])
        assert.are.equal(1, synth.pedalsOf('guitar').flanger)
        calls = {}
        synth.setEffectAmount(amount)
        assert.are.equal(0.8, callsTo('instrument_flanger', slot)[1][5]) -- back to the live value
    end)

    it('sends a pedal change to the slot the patch holds now', function()
        synth.scheduleAt('rhodes', 1, 60, 4, 600)
        synth.scheduleAt('guitar', 1, 52, 4, 600)
        local guitarSlot = notes[2].slot
        assert.are_not.equal(notes[1].slot, guitarSlot)
        calls = {}
        synth.slotTape('guitar', 0.5, 0.1, 0.2, 0.3)
        assert.are.equal(1, #callsTo('instrument_tape', guitarSlot))
        assert.are.equal(1, #calls - #callsTo('instrument_tape', guitarSlot)) -- and its warble, nothing else
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

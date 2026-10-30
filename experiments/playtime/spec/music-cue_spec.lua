-- spec/music-cue_spec.lua
-- music.cue (src/music.lua): a room changes the music the way a game score does. 'bar' cuts at
-- the next bar line; 'phrase' waits for the end of the 4-bar phrase and plays a bridge bar (a
-- 9sus4 on the new key's fifth) first; 'keep' stays in the key; a cue for the style already set
-- does nothing. The synth is faked: an audio clock and a note log.
-- Run with: love . --specs spec/music-cue_spec.lua

if not love then return end

local state = require('src.state')

describe('music.cue', function()
    local music, synth, clock, notes, saved

    local function run(seconds)
        local stop = clock + seconds
        while clock < stop do
            clock = clock + 0.02
            music.update(synth, clock)
        end
    end
    local function song() return state.music.song end

    before_each(function()
        music = require('src.music')
        -- music.lua keeps state.music as its own table: clear its fields, put them back after
        saved = { music = {}, settings = state.musicSettings }
        for k, v in pairs(state.music) do saved.music[k] = v end
        for _, k in ipairs({ 'song', 'barAt', 'cue', 'audioTime', 'lastNow', 'barStart', 'voicing' }) do
            state.music[k] = nil
        end
        state.music.activity, state.music.withBand, state.music.listeners = 0, false, {}
        state.musicSettings = { enabled = true, style = 'bossa', rhythmSection = 'off', melody = true }
        clock, notes = 0, {}
        synth = { audioTime = function() return clock end,
                  scheduleAt = function(patch, t, midi) notes[#notes + 1] = { patch = patch, t = t, midi = midi } end }
    end)

    after_each(function()
        for k in pairs(state.music) do state.music[k] = nil end
        for k, v in pairs(saved.music) do state.music[k] = v end
        state.musicSettings = saved.settings
    end)

    it('does nothing for the style already set', function()
        run(3)
        assert.is_false(music.cue('bossa'))
        assert.is_nil(state.music.cue)
    end)

    it("cuts at the next bar with at = 'bar', into the new style's first A", function()
        run(3)
        assert.is_true(music.cue('sesame', { at = 'bar' }))
        run(song().barLength + 0.5)
        assert.are.equal('sesame', song().style)
        assert.are.equal('sesame', music.style)
        assert.are.equal('A', song().barSection[song().bar].kind)
        assert.is_nil(state.music.cue)
    end)

    it('waits for the phrase to end, then plays the bridge bar, then the new style', function()
        run(3)
        music.cue('citypop', { key = 'keep' })
        local oldKey, cueAt = song().setKey, clock
        local bridged = false
        while song().style == 'bossa' and clock < cueAt + 60 do
            run(0.1)
            if state.music.cue and state.music.cue.bridged then bridged = true end
        end
        assert.is_true(bridged)
        assert.are.equal('citypop', song().style)
        assert.are.equal(oldKey, song().setKey)
        -- the bridge's bass is the new key's fifth
        local fifth = (oldKey + 7) % 12
        local found = false
        for _, note in ipairs(notes) do
            if note.patch == 'roundBass' and note.midi % 12 == fifth then found = true end
        end
        assert.is_true(found)
    end)

    it('a second cue replaces the first', function()
        run(3)
        music.cue('citypop')
        music.cue('satie', { at = 'bar' })
        run(song().barLength + 0.5)
        assert.are.equal('satie', song().style)
    end)

    it("cueing back to what's set drops a pending cue", function()
        run(3)
        music.cue('citypop')
        music.cue('bossa')
        assert.is_nil(state.music.cue)
    end)
end)

-- spec/music-cue_spec.lua
-- music.cue and music.layers (src/music.lua): a room changes the music the way a game score does.
-- The handoff goes part by part: the old song's last bar keeps only its light parts and is cut at
-- the bar line, the new song comes in light and its drums join two bars in. 'phrase' makes that
-- last bar the phrase's last; 'keep' stays in the key; a cue for the style already set does
-- nothing. Layers switch parts off on the next bar line, same song. The synth is faked: an audio
-- clock, and music.trace logs every note with its part.
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
        for k in pairs(saved.music) do state.music[k] = nil end -- layers, a cue or an entry left by another spec too
        state.music.version, state.music.booked, state.music.heard = saved.music.version, {}, {}
        state.music.activity, state.music.withBand, state.music.listeners = 0, false, {}
        state.musicSettings = { enabled = true, style = 'bossa', rhythmSection = 'off', melody = true }
        clock, notes = 0, {}
        synth = { audioTime = function() return clock end, scheduleAt = function() end }
        music.trace = function(part, t, midi, _, durMs) notes[#notes + 1] = { part = part, t = t, midi = midi, ends = t + durMs / 1000 } end
    end)

    local function partsBetween(from, to)
        local parts = {}
        for _, note in ipairs(notes) do
            if note.t >= from - 0.01 and note.t < to - 0.01 then parts[note.part] = true end
        end
        return parts
    end

    after_each(function()
        music.trace = nil
        for k in pairs(state.music) do state.music[k] = nil end
        for k, v in pairs(saved.music) do state.music[k] = v end
        state.musicSettings = saved.settings
    end)

    it('does nothing for the style already set', function()
        run(3)
        assert.is_false(music.cue('bossa'))
        assert.is_nil(state.music.cue)
    end)

    it("lands a bar after the cue with at = 'bar', at the new style's first A", function()
        run(3)
        assert.is_true(music.cue('sesame', { at = 'bar' }))
        run(2 * song().barLength + 0.5) -- the old song's light last bar, then the new one
        assert.are.equal('sesame', song().style)
        assert.are.equal('sesame', music.style)
        assert.are.equal('A', song().barSection[song().bar].kind)
        assert.is_nil(state.music.cue)
    end)

    it('hands over part by part: a light last bar cut at the bar line, then the new style light first', function()
        state.musicSettings.rhythmSection = 'on'
        run(3)
        music.cue('citypop', { key = 'keep' })
        local oldKey, cueAt, tailStart = song().setKey, clock, nil
        while song().style == 'bossa' and clock < cueAt + 60 do
            run(0.02)
            if not tailStart and state.music.cue and state.music.cue.tailed then tailStart = state.music.barStart end
        end
        assert.is_truthy(tailStart)
        local tailEnd = state.music.barStart -- the new song's first bar starts where the tail ends
        -- the old song's last bar: no drums, no bass, and nothing rings past the bar line
        local tail = partsBetween(tailStart, tailEnd)
        assert.is_nil(tail.drums)
        assert.is_nil(tail.bass)
        -- (the new song's downbeat may be humanized up to ~18 ms early: it isn't the tail's)
        for _, note in ipairs(notes) do
            if note.t >= tailStart - 0.01 and note.t < tailEnd - 0.02 then
                assert.is_true(note.ends <= tailEnd + 0.03)
            end
        end
        -- the new song: in the old key, at its A (bossa was in A), drums only from its third bar
        assert.are.equal('citypop', song().style)
        assert.are.equal(oldKey, song().setKey)
        assert.are.equal('A', song().barSection[song().bar].kind)
        local barLength = song().barLength
        run(3 * barLength)
        assert.is_nil(partsBetween(tailEnd, tailEnd + 2 * barLength).drums)
        assert.is_true(partsBetween(tailEnd + 2 * barLength, tailEnd + 3 * barLength).drums)
    end)

    it('switches layers on the next bar line, same song', function()
        state.musicSettings.rhythmSection = 'on'
        run(3)
        local style = song().style
        assert.is_true(music.layers('cellar'))
        assert.is_false(music.layers('cellar'))
        run(2 * song().barLength + 0.5)
        local since = state.music.barStart - song().barLength
        local parts = partsBetween(since, since + song().barLength)
        assert.is_nil(parts.drums)
        assert.is_nil(parts.lead)
        assert.is_true(parts.keys)
        assert.are.equal(style, song().style)
        assert.are.equal('cellar', music.nowPlaying().layers)
    end)

    it('a cue with layers for the style already set only changes the layers', function()
        run(3)
        assert.is_true(music.cue('bossa', { layers = { drums = false } }))
        assert.is_nil(state.music.cue)
        run(song().barLength + 0.5)
        assert.are.equal('custom', music.nowPlaying().layers)
    end)

    it('a second cue replaces the first', function()
        run(3)
        music.cue('citypop')
        music.cue('satie', { at = 'bar' })
        run(2 * song().barLength + 0.5)
        assert.are.equal('satie', song().style)
    end)

    it("cueing back to what's set drops a pending cue", function()
        run(3)
        music.cue('citypop')
        music.cue('bossa')
        assert.is_nil(state.music.cue)
    end)
end)

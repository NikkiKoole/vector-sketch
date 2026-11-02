-- music-setups_spec.lua: saving a music setup and putting it back (src/music-setups.lua), on a test
-- file of its own so the game's saved setups stay as they are
if not love then return end

describe('music setups', function()
    local state = require('src.state')
    local setups = require('src.music-setups')
    local realFile, realList, realSettings

    before_each(function()
        realFile, realList, realSettings = setups.FILE, state.musicSetups, state.musicSettings
        setups.FILE, state.musicSetups = 'music-setups-spec.json', nil
        love.filesystem.remove(setups.FILE)
        state.musicSettings = { enabled = true, style = 'island', rhythmSection = 'on', melody = true,
                                voices = { lead = 'vibes' }, partsOff = { drums = true } }
    end)
    after_each(function()
        love.filesystem.remove(setups.FILE)
        setups.FILE, state.musicSetups, state.musicSettings = realFile, realList, realSettings
    end)

    it('saves the playing setup under its style and a number, and reads it back from the file', function()
        local first = setups.save()
        local second = setups.save()
        assert.are.equal('island 1', first.name)
        assert.are.equal('island 2', second.name)
        assert.are.same({ lead = 'vibes' }, first.voices)
        assert.are.same({ drums = true }, first.partsOff)
        state.musicSetups = nil -- read the file again
        assert.are.equal(2, #setups.list())
        assert.are.equal('on', setups.list()[1].band)
    end)

    it('puts a setup back, as copies, and forgets one by name', function()
        local saved = setups.save()
        state.musicSettings.style, state.musicSettings.voices, state.musicSettings.partsOff = 'bossa', {}, {}
        setups.apply(saved)
        assert.are.equal('island', state.musicSettings.style)
        assert.are.same({ lead = 'vibes' }, state.musicSettings.voices)
        state.musicSettings.voices.lead = 'flute'
        assert.are.equal('vibes', saved.voices.lead) -- the setup itself is untouched
        setups.remove('island 1')
        assert.are.equal(0, #setups.list())
    end)

    it('resets to the style\'s own setup, and undo brings it back (and undo again redoes the reset)', function()
        state.musicSettings.soundsOff, state.musicSettings.soundVoices = { kick = true }, { rim = 'wood' }
        setups.reset()
        assert.are.same({}, state.musicSettings.voices)
        assert.are.same({}, state.musicSettings.soundsOff)
        assert.are.equal('island', state.musicSettings.style) -- the style stays
        assert.is_true(setups.undo())
        assert.are.same({ lead = 'vibes' }, state.musicSettings.voices)
        assert.are.same({ kick = true }, state.musicSettings.soundsOff)
        assert.are.same({ rim = 'wood' }, state.musicSettings.soundVoices)
        setups.undo()
        assert.are.same({}, state.musicSettings.voices)
    end)

    it('undoes putting a setup back by accident, style and all', function()
        local saved = setups.save()
        state.musicSettings.style, state.musicSettings.voices = 'bossa', { bass = 'pickBass' }
        setups.apply(saved)
        assert.are.equal('island', state.musicSettings.style)
        setups.undo()
        assert.are.equal('bossa', state.musicSettings.style)
        assert.are.same({ bass = 'pickBass' }, state.musicSettings.voices)
    end)
end)

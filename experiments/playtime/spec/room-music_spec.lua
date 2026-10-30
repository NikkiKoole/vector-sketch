-- spec/room-music_spec.lua
-- A room's music (src/room-music.lua): loaded with the scene, cued on load, saved only when it
-- names a style; music.cue when it exists, else music.style.

local state = require('src.state')

describe('room music', function()
    local roomMusic, fakeMusic, savedMusic, savedRoom

    before_each(function()
        savedMusic, savedRoom = package.loaded['src.music'], state.roomMusic
        fakeMusic = { style = 'set', cues = {} }
        package.loaded['src.music'] = fakeMusic
        package.loaded['src.room-music'] = nil
        roomMusic = require('src.room-music')
    end)

    after_each(function()
        package.loaded['src.music'], state.roomMusic = savedMusic, savedRoom
    end)

    it('keeps whatever plays when the scene names no music', function()
        roomMusic.load(nil)
        assert.equals('set', fakeMusic.style)
        assert.is_nil(roomMusic.save())
    end)

    it('turns the music into the room style without music.cue', function()
        roomMusic.load({ style = 'satie' })
        assert.equals('satie', fakeMusic.style)
        assert.same({ style = 'satie', at = 'phrase' }, roomMusic.save())
    end)

    it('goes through music.cue when there is one', function()
        fakeMusic.cue = function(style, opts) fakeMusic.cues[#fakeMusic.cues + 1] = { style, opts.at } end
        roomMusic.load({ style = 'bossa', at = 'bar' })
        assert.same({ { 'bossa', 'bar' } }, fakeMusic.cues)
        assert.equals('set', fakeMusic.style)
    end)
end)

-- spec/music-zones_spec.lua
-- Music zones (src/music-zones.lua): the smallest zone around the camera centre wins, after a
-- dwell; the zone playing now holds until the centre is a margin past its edge; out of every zone,
-- the room's music (or what played before) comes back.

local state = require('src.state')

-- a fake body with one collision fixture over x1, y1 .. x2, y2 and a MUSIC_ZONE behavior
local function zoneBody(x1, y1, x2, y2, zone)
    zone.name = 'MUSIC_ZONE'
    local fixture = {
        getUserData = function() return nil end,
        getBoundingBox = function() return x1, y1, x2, y2 end,
    }
    return {
        getFixtures = function() return { fixture } end,
        getUserData = function() return { thing = { behaviors = { zone } } } end,
        isDestroyed = function() return false end,
    }
end

describe('music zones', function()
    local zones, fakeMusic, world, savedMusic, savedParams, savedRoom, savedZones

    before_each(function()
        savedMusic, savedParams = package.loaded['src.music'], package.loaded['src.music-params']
        savedRoom, savedZones = state.roomMusic, state.musicZones
        fakeMusic = { style = 'set', cues = {} }
        fakeMusic.cue = function(style, opts) fakeMusic.cues[#fakeMusic.cues + 1] = { style, opts.layers } end
        fakeMusic.layers = function(preset) fakeMusic.cues[#fakeMusic.cues + 1] = { 'layers', preset } end
        fakeMusic.nowPlaying = function() return { style = 'island', layers = 'full' } end
        fakeMusic.layerPresets = { 'full', 'quiet' }
        package.loaded['src.music'] = fakeMusic
        package.loaded['src.music-params'] = { rows = { { key = 'style', options = { 'set', 'island', 'satie' } } } }
        package.loaded['src.room-music'], package.loaded['src.music-zones'] = nil, nil
        state.roomMusic, state.musicZones = nil, nil
        zones = require('src.music-zones')
        world = { bodies = {} }
        world.getBodies = function() return world.bodies end
    end)

    after_each(function()
        package.loaded['src.music'], package.loaded['src.music-params'] = savedMusic, savedParams
        state.roomMusic, state.musicZones = savedRoom, savedZones
    end)

    -- look n times at x, y, a look apart
    local function stay(x, y, n)
        for _ = 1, n do zones.update(zones.every, world, x, y) end
    end

    it('picks the smallest zone around the point', function()
        local big = zoneBody(0, 0, 1000, 1000, {})
        local small = zoneBody(100, 100, 200, 200, {})
        local list = zones.zones({ getBodies = function() return { big, small } end })
        assert.equals(small, zones.pick(list, 150, 150))
        assert.equals(big, zones.pick(list, 500, 500))
        assert.is_nil(zones.pick(list, 2000, 0))
    end)

    it('keeps the zone playing now until the point is a margin past its edge', function()
        local z = zoneBody(0, 0, 100, 100, {})
        local list = zones.zones({ getBodies = function() return { z } end })
        assert.equals(z, zones.pick(list, 100 + zones.margin / 2, 50, z))
        assert.is_nil(zones.pick(list, 100 + zones.margin / 2, 50, nil))
    end)

    it('cues the zone after the dwell, and the music from before on the way out', function()
        world.bodies = { zoneBody(0, 0, 100, 100, { style = 'satie', layers = 'quiet', at = 'bar' }) }
        stay(50, 50, 1)
        assert.same({}, fakeMusic.cues) -- not yet: a dwell first
        stay(50, 50, 5)
        assert.same({ { 'satie', 'quiet' } }, fakeMusic.cues)
        stay(500, 500, 5)
        assert.same({ 'set', 'full' }, fakeMusic.cues[2]) -- the room keeps whatever played: back to that
    end)

    it("goes back to the room's own music when it has one", function()
        require('src.room-music').load({ style = 'island', layers = 'full' })
        fakeMusic.cues = {}
        world.bodies = { zoneBody(0, 0, 100, 100, { style = 'keep', layers = 'quiet' }) }
        stay(50, 50, 5)
        assert.same({ { 'layers', 'quiet' } }, fakeMusic.cues) -- Woodtick: same song, quieter
        stay(500, 500, 5)
        assert.same({ 'island', 'full' }, fakeMusic.cues[2])
    end)

    it('fills the inspector choices from the music', function()
        stay(0, 0, 1)
        local choices = require('src.behaviors').musicZoneChoices
        assert.same({ 'keep', 'set', 'island', 'satie' }, choices.style)
        assert.same({ 'keep', 'full', 'quiet' }, choices.layers)
    end)
end)

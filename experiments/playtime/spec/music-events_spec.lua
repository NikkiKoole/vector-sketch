local state = require('src.state')
state.music = state.music or { activity = 0 }
local events = require('src.music-events')
local D = require('src.music-styles')
local jam = require('src.music-jam')

local function fresh()
    state.music.events, state.music.moments, state.music.momentListeners = {}, {}, {}
    state.music.answeredAt = nil
    state.musicSettings = state.musicSettings or {}
    state.musicSettings.world, state.musicSettings.jam = nil, { layers = 'all' }
end

describe('music-events', function()
    before_each(fresh)

    it('an event at any time lands on the next beat, never in the past', function()
        for i = 0, 200 do
            local t = 10 + i * 0.0137
            local at = events.nextBeat(9.7, 0.5, t, 0.06)
            assert.is_true(at >= t + 0.06 - 1e-9)
            assert.is_true(at < t + 0.06 + 0.5)
            local k = (at - 9.7) / 0.5
            assert.is_true(math.abs(k - math.floor(k + 0.5)) < 1e-9)
        end
    end)

    it('fires a moment when the clock gets there, or `ahead` before', function()
        local heard = {}
        events.on('late', 'bar', function(data) heard[#heard + 1] = 'late' .. data.bar end)
        events.on('early', 'bar', function(data) heard[#heard + 1] = 'early' .. data.bar end, 0.5)
        events.moment('bar', 2.0, { bar = 1 })
        events.fire(1.4)
        assert.are.same({}, heard)
        events.fire(1.6)
        assert.are.same({ 'early1' }, heard)
        events.fire(2.0)
        assert.are.same({ 'early1', 'late1' }, heard)
        events.fire(2.1)
        assert.are.equal(2, #heard) -- once each
    end)

    it('keeps no moments when nobody listens', function()
        events.moment('beat', 1, {})
        assert.are.equal(0, #state.music.moments)
    end)

    it('lends the band\'s instruments: what a part played lately, the latest first (MW7)', function()
        state.music.audioTime = 100
        state.music.heard = { bass = { musicBass = { { from = 90, to = 91 } }, tb303 = { { from = 98, to = 99.5 } } },
                              keys = { rhodes = { { from = 50, to = 60 } } } }
        assert.are.same({ 'tb303' }, events.bandInstruments('bass', 4))
        assert.are.same({ 'tb303', 'musicBass' }, events.bandInstruments('bass', 20))
        assert.are.same({}, events.bandInstruments('keys', 4)) -- the keys stopped a while ago
        assert.are.same({}, events.bandInstruments('lead', 4))
        state.music.heard = nil
    end)

    it('lends the picked instrument even with the part off, else the song\'s own', function()
        state.music.audioTime, state.music.heard = 100, {}
        state.music.song = { style = 'acid' }
        state.music.styleParts = { acid = { bass = 'tb303' } }
        state.music.styleSounds = { acid = { drums = { kick = true, tom = true } } }
        assert.are.same({ 'tb303' }, events.bandInstruments('bass', 4)) -- off, nothing heard: the song's own
        state.musicSettings.voices = { bass = 'pickBass' }
        assert.are.same({ 'pickBass' }, events.bandInstruments('bass', 4)) -- the pick wins
        state.musicSettings.soundVoices = { tom = 'conga' }
        assert.are.same({ 'conga', 'kick' }, events.bandInstruments('drums', 4))
        state.musicSettings.voices, state.musicSettings.soundVoices = nil, nil
        state.music.song, state.music.styleParts, state.music.styleSounds = nil, nil, nil
    end)

    it('borrows for the ball and boxes by default, not for Mipo bumps', function()
        assert.is_true(events.borrows('ball'))
        assert.is_true(events.borrows('box'))
        assert.is_false(events.borrows('plonk'))
        state.musicSettings.world = { band = { ball = 'own', plonk = 'band' } }
        assert.is_false(events.borrows('ball'))
        assert.is_true(events.borrows('plonk'))
    end)

    describe('the jam', function()
        local style = D.styles.jam
        local function song()
            local s = { seed = 2, key = 5, style = 'jam', swing = style.swing }
            jam.plan(s, style, function() end)
            return s
        end

        local function answerImpact(s, strength, beatAt)
            local hits = {}
            local function play(_, part, patch, t) hits[#hits + 1] = { part = part, patch = patch, t = t } end
            state.music.barStart = 0
            events.event('impact', { strength = strength })
            -- the answer at the next beat after `beatAt - margin`
            events.update(nil, beatAt - 0.06 - 0.01, s, style, play)
            return hits
        end

        it('answers a hard impact with a crash on the next beat, at most one a bar', function()
            local s = song()
            local hits = answerImpact(s, 0.7, s.beat * 3)
            assert.are.equal(1, #hits)
            assert.are.equal('ride', hits[1].patch)
            assert.is_true(math.abs(hits[1].t - s.beat * 3) < 1e-6)
            assert.are.equal(0, #answerImpact(s, 0.7, s.beat * 5)) -- the same bar's worth: no
            assert.are.equal(1, #answerImpact(s, 0.7, s.beat * 7))
        end)

        it('ignores soft impacts and says nothing when off', function()
            local s = song()
            assert.are.equal(0, #answerImpact(s, 0.3, s.beat))
            state.musicSettings.world = { impact = 'off' }
            assert.are.equal(0, #answerImpact(s, 1, s.beat * 9))
        end)

        it('a very hard one gets a one-beat fill, then the crash', function()
            local s = song()
            local hits = answerImpact(s, 1, s.beat * 2)
            assert.are.equal(5, #hits)
            assert.are.equal('snare', hits[1].patch)
            assert.are.equal('ride', hits[5].patch)
            assert.is_true(math.abs(hits[5].t - s.beat * 3) < 1e-6)
        end)

        it('tells the next chord a bar early, and it is the chord that comes', function()
            local s = song()
            local told = {}
            events.on('spec', 'chord', function(data, at) told[#told + 1] = { at = at, root = data.root } end)
            local t0, roots = 0, {}
            for b = 1, 40 do
                state.music.activity = 5
                jam.bookBar(function() end, function() end, nil, t0, s, b)
                roots[#roots + 1] = { at = t0, root = (s.key + s.jam.root) % 12 }
                t0 = t0 + s.barLength
            end
            events.fire(t0 + 10)
            assert.is_true(#told > 5)
            for _, c in ipairs(told) do
                for _, r in ipairs(roots) do
                    if math.abs(r.at - c.at) < 1e-6 then assert.are.equal(r.root, c.root) end
                end
            end
        end)
    end)
end)

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
        -- these are about the answers, on the jam's played-kit voices (a drum machine genre plays a hit as
        -- several notes, music-jam's KITS); the last test checks a kit's own
        local kits
        before_each(function() kits, jam.KITS = jam.KITS, {} end)
        after_each(function() jam.KITS = kits end)
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

        -- STINGERS S4: the other moments, answered in drums
        local function answerMoment(s, name, beatAt, on)
            local hits = {}
            local function play(_, part, patch, t) hits[#hits + 1] = { part = part, patch = patch, t = t } end
            state.music.barStart = 0
            s.jam.on = on or { hats = true, kick = true, snare = true }
            events.event(name)
            events.update(nil, beatAt - 0.06 - 0.01, s, style, play)
            return hits
        end

        it('the moments: nothing while stingers are off, but the try button plays a fill', function()
            local s = song()
            assert.are.equal(0, #answerMoment(s, 'door', s.beat))
            local hits = answerMoment(s, 'stinger', s.beat * 2)
            assert.are.equal(5, #hits) -- four snare 16ths, landing on a kick
            assert.are.equal('snare', hits[1].patch)
            assert.is_true(math.abs(hits[1].t - s.beat * 2) < 1e-6)
            assert.are.equal('bapKick', hits[5].patch)
            assert.is_true(math.abs(hits[5].t - s.beat * 3) < 1e-6)
        end)

        it('a small moment nods (an open hat, a kick with the hats out), a door fills, one a bar', function()
            local s = song()
            state.musicSettings.world = { stingerSize = 'small', stingerMoments = 'rare' }
            local nod = answerMoment(s, 'snap', s.beat)
            assert.are.equal(1, #nod)
            assert.are.equal('hat', nod[1].patch)
            assert.are.equal(0, #answerMoment(s, 'door', s.beat * 3)) -- the same bar's worth: no
            assert.are.equal(5, #answerMoment(s, 'door', s.beat * 6))
            local kick = answerMoment(s, 'snap', s.beat * 11, { kick = true })
            assert.are.equal('bapKick', kick[1].patch)
            assert.are.equal(0, #answerMoment(s, 'throw', s.beat * 16)) -- not a 'rare' moment
        end)

        it("'big' moves each up a step: a nod becomes the fill, a door's fill gets the crash", function()
            local s = song()
            state.musicSettings.world = { stingerSize = 'big', stingerMoments = 'rare' }
            assert.are.equal(5, #answerMoment(s, 'snap', s.beat))
            local hits = answerMoment(s, 'door', s.beat * 6)
            assert.are.equal(6, #hits)
            assert.are.equal('ride', hits[6].patch)
        end)

        it('no answer into the gap (the silent beat before a drop): the hole stays a hole', function()
            local s = song()
            state.musicSettings.world = { stingerSize = 'small', stingerMoments = 'rare' }
            s.jam.gapAt = { s.beat * 3, s.beat * 4 }
            assert.are.equal(0, #answerMoment(s, 'snap', s.beat * 3))   -- a nod in it
            assert.are.equal(0, #answerMoment(s, 'door', s.beat * 2))   -- a fill landing in it
            assert.are.equal(0, #answerImpact(s, 0.7, s.beat * 3))      -- a crash in it
            assert.are.equal(1, #answerMoment(s, 'snap', s.beat * 4))   -- the drop's one: fine
            s.jam.gapAt = nil
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

        it('a drum machine genre answers on its machine: the 909 crash is its metal and its noise', function()
            local s = song()
            jam.KITS = { [s.jam.group] = 'tr909' } -- the 909 plays no genre now (parked); the answer still works
            local hits = answerImpact(s, 0.7, s.beat * 3)
            assert.are.equal(2, #hits)
            assert.are.equal('tr909Crash', hits[1].patch)
            assert.are.equal('tr909CrashNoise', hits[2].patch)
            assert.is_true(math.abs(hits[1].t - s.beat * 3) < 1e-6)
        end)
    end)
end)

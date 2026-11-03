-- music-stingers: a stinger's notes come from the chord, sit in range, start on the beat, and the
-- shapes come from a bag (no repeat until all have played)
if not love then return end

local stingers = require('src.music-stingers')
local state = require('src.state')

describe('music-stingers', function()
    before_each(function()
        state.music = state.music or {}
        state.music.stingers = nil
    end)

    it('plans chord tones in range, from the beat', function()
        local pcs = { 2, 6, 9, 1 } -- D F# A C#
        for _, size in ipairs({ 'small', 'big' }) do
            for _ = 1, 20 do
                local notes, stop = stingers.plan(size, pcs, 10, 0.6, 0)
                assert.is_truthy(notes)
                assert.are.equal(10, notes[1].t)
                assert.is_true(stop > notes[#notes].t)
                for _, n in ipairs(notes) do
                    local pc = n.midi % 12
                    assert.is_true(pc == 2 or pc == 6 or pc == 9 or pc == 1)
                    assert.is_true(n.midi >= stingers.range[1] and n.midi <= stingers.range[2])
                    assert.is_true(n.vol >= 1)
                end
            end
        end
    end)

    it('takes every shape once before repeating one', function()
        local n = #stingers.SHAPES.small
        local seen = {}
        for _ = 1, n do
            -- the same chord and start each time: the contour tells the shapes apart
            local notes = stingers.plan('small', { 0, 4, 7 }, 0, 0.5, 0)
            local key = {}
            for i, note in ipairs(notes) do key[i] = note.midi - notes[1].midi end
            seen[#seen + 1] = table.concat(key, ',')
        end
        assert.are.equal(n, #seen)
        assert.is_truthy(state.music.stingers.bags.smallshape)
        assert.are.equal(0, #state.music.stingers.bags.smallshape) -- the bag is empty: all n were drawn
    end)

    it('is softer when stingers come thick', function()
        local loud = stingers.plan('small', { 0, 4, 7 }, 0, 0.5, 0)
        local soft = stingers.plan('small', { 0, 4, 7 }, 0, 0.5, 3)
        assert.is_true(soft[1].vol < loud[1].vol)
    end)

    it('only answers the try button while off', function()
        state.musicSettings = state.musicSettings or {}
        local w = state.musicSettings.world
        state.musicSettings.world = { stingerSize = 'off', stingerMoments = 'all' }
        assert.is_true(stingers.wants('stinger'))
        assert.is_false(stingers.wants('snap'))
        state.musicSettings.world = { stingerSize = 'small', stingerMoments = 'rare' }
        assert.is_true(stingers.wants('snap'))
        assert.is_false(stingers.wants('grab'))
        state.musicSettings.world = w
    end)
end)

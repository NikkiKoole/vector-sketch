local state = require('src.state')
state.music = state.music or {} -- src/music.lua makes it in the game; music-jam reads it at load
local D = require('src.music-styles')
local jam = require('src.music-jam')

-- Drives the jam bar by bar with the play level jumping about, the way the game does.
local function run(seed, bars, pick)
    state.music.activity = 0
    state.musicSettings = state.musicSettings or {}
    state.musicSettings.jam = pick or {}
    local style = D.styles.jam
    local song = { seed = seed, key = 5, style = 'jam', swing = style.swing }
    jam.plan(song, style, function() end)
    local rnd = math.random
    math.randomseed(seed)
    local out = {}
    for b = 1, bars do
        state.music.activity = rnd(0, 3 * style.perLayer)
        jam.bookBar(function() end, function() end, nil, 0, song, b)
        local next, barsLeft = jam.ahead(song.jam)
        out[b] = { root = song.jam.root, next = next, barsLeft = barsLeft, mode = song.jam.mode }
    end
    return out
end

describe('music-jam', function()
    it('leans into the root that really arrives (decided a bar early)', function()
        for seed = 1, 20 do
            local bars = run(seed, 200)
            local changes = 0
            for b = 1, #bars - 1 do
                assert.are.equal(bars[b + 1].root, bars[b].next, ('seed %d bar %d'):format(seed, b))
                if bars[b + 1].root ~= bars[b].root then
                    changes = changes + 1
                    assert.are.equal(1, bars[b].barsLeft, ('seed %d bar %d: the ending plays'):format(seed, b))
                end
            end
            assert.is_true(changes > 10)
        end
    end)

    it('lands back home on a drop', function()
        local drops = 0
        for seed = 1, 20 do
            local bars = run(seed, 200)
            for b = 2, #bars do
                if bars[b].mode == 'drop' and bars[b - 1].mode == 'break' then
                    drops = drops + 1
                end
            end
        end
        assert.is_true(drops > 0)
    end)

    it('follows a walk picked mid-song from its first step', function()
        local bars = run(7, 64, { walk = '2 5 1', pace = '2' })
        assert.are.equal(2, bars[1].root) -- picked before the song: it starts there
    end)
end)

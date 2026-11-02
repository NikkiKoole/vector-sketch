-- How a style's harmony moves, from the songs' own chord plans (no sound): chord changes per 8 bars
-- of A and B, and the share of chord time whose root is outside the key (HookTheory counts both the
-- same way; claudetools/score-analysis.py reads one chord per bar and can't see a half-bar ii-V).
-- Walk steps count as changes. Used for R6/R6b (approach, borrow: docs/MUSIC-CONCEPTS.md).
-- usage: luajit claudetools/music-harmony.lua <style> [ideas] [songs]
--        ideas: approach:lots,borrow:some (never / less / some / always / lots; the rest never)
--        songs: how many, seeds 1.. (default 8)
package.path = './?.lua;' .. package.path
love = { math = { random = math.random } } -- luacheck: ignore
package.loaded['src.state'] = { synth = { started = false } }
local style, spec, count = arg[1], arg[2] or '', tonumber(arg[3]) or 8
local music = require('src.music')
local plan = require('src.music-plan')
local theory = require('src.music-theory')
music.style = style
local ideas = {}
for name, mode in spec:gmatch('(%w+):(%w+)') do ideas[name] = mode end
music.ideas = ideas
local changes, bars, outside, total = 0, 0, 0, 0
for seed = 1, count do
    math.randomseed(seed)
    local song = plan.planSong(nil)
    song.ideaOdds = music.ideaOdds(song, music.styles[song.style])
    local last
    for b = 1, song.bars do
        local kind = song.barSection[b].kind
        if kind == 'A' or kind == 'B' then
            bars = bars + 1
            for _, c in ipairs(theory.barChords(song, b)) do
                local name = c.degree .. c.quality
                if last and name ~= last then changes = changes + 1 end
                last = name
                total = total + c.len
                if not song.scale[c.degree % 12] then outside = outside + c.len end
            end
        end
    end
end
print(('%-11s %-24s changes per 8 bars %4.1f   roots outside the key %3.0f%%'):format(style, spec,
    8 * changes / math.max(1, bars), 100 * outside / math.max(1, total)))

-- Half-step rubs in a recorded song: a keys note against a tune or bass note sounding with it, a
-- semitone apart (or a minor 9th, a major 7th: any octave). The check that found the walks' and the
-- answer's wrong notes (docs/MUSIC-ANALYSIS.md). Not every rub is wrong: a maj7 over its root, the line
-- cliché's maj7 under the root and a V7b9's b9 are meant to bite. Compare before and after a change.
-- usage: luajit claudetools/music-rubs.lua song.lua [bars]
--        song.lua: a score from render-music.lua's NOTES= (or src/music-scores/); without bars: the
--        count and the rubs per bar; with bars ("10 18 22" or "1-40"): each rub, what it's against
--        and the keys' chord at that moment
local score = assert(loadfile(arg[1]))()
local per = (score.meter or 4) * 4
local NAMES = { 'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B' }
local function nm(m) return NAMES[m % 12 + 1] .. (math.floor(m / 12) - 1) end
local want
if arg[2] then
    want = {}
    for lo, hi in arg[2]:gmatch('(%d+)%-?(%d*)') do
        for b = tonumber(lo), tonumber(hi ~= '' and hi or lo) do want[b] = true end
    end
end
local notes = {}
for b, ns in pairs(score.bars) do
    for _, n in ipairs(ns) do
        notes[#notes + 1] = { t = (b - 1) * per + n[1], e = (b - 1) * per + n[1] + n[3], midi = n[2], part = n[4],
                              bar = b, step = n[1] }
    end
end
local count, byBar = 0, {}
for _, k in ipairs(notes) do
    if k.part == 'k' and (not want or want[k.bar]) then
        for _, o in ipairs(notes) do
            -- the other note sounds as the keys strike (started with it or before, not yet ended)
            if o.part ~= 'k' and o.t <= k.t and k.t < o.e then
                local d = (k.midi - o.midi) % 12
                if d == 1 or d == 11 then
                    count, byBar[k.bar] = count + 1, (byBar[k.bar] or 0) + 1
                    if want then
                        local chord = {}
                        for _, c in ipairs(notes) do
                            if c.part == 'k' and c.t == k.t then chord[#chord + 1] = nm(c.midi) end
                        end
                        print(('bar %d step %d: keys %s against %s %s (from bar %d step %d)   keys %s'):format(
                            k.bar, k.step, nm(k.midi), o.part == 'l' and 'tune' or o.part == 'b' and 'bass' or o.part,
                            nm(o.midi), o.bar, o.step, table.concat(chord, ' ')))
                    end
                end
            end
        end
    end
end
if not want then
    local bars = {}
    for b in pairs(byBar) do bars[#bars + 1] = b end
    table.sort(bars)
    for i, b in ipairs(bars) do bars[i] = b .. ':' .. byBar[b] end
    print(count .. ' rubs', table.concat(bars, ' '))
end

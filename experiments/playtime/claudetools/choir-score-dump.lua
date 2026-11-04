-- The choir scene's score outside LÖVE (docs/CHOIR.md), for offline renders (claudetools/choir-world-render.py).
-- args: tune(1-4) mode(round|mixed|solo) solo(1-3) feel(off|jitter|singer) rounds seed
-- prints a line per note: at sp syl rate lead voice cents scoop vibrato vibRate gain
love = {
  filesystem = { load = loadfile, getInfo = function(p) local f = io.open(p) if f then f:close() return {} end end },
  audio = { newSource = function() return {} end },
  math = { random = function(a) if a then return math.random(a) end return math.random() end },
  timer = { getTime = function() return 0 end },
}
math.randomseed(tonumber(arg[6]) or 7)
state = { playMode = true }
local s = dofile('scripts/spikes/choir.playtime.lua')
state.choir = { tune = tonumber(arg[1]), tempo = 0, transpose = 0, rounds = tonumber(arg[5]) or 1, tuning = 'syllable',
  mode = arg[2], solo = tonumber(arg[3]) or 1, swapRough = true, showPanel = true, mipos = {}, statics = {},
  playing = false, feel = arg[4] }
local c = state.choir
for _ = 1, 4 do s.onKeyPress('n') end -- a full cycle of the 4 tunes: back on this one, with its tempo
c.mode, c.feel = arg[2], arg[4]
s.sing()
for _, e in ipairs(c.events) do
  if not e.kind then
    print(string.format('%.4f %s %s %.6f %.4f %d %.2f %.2f %.2f %.3f %.4f', e.at, e.sp, e.syl, e.rate, e.lead, e.voice or 0,
      e.cents or 0, e.scoop or 0, e.vibrato or 0, e.vibRate or 5, e.gain or 1))
  end
end

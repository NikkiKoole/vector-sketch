-- main.lua
local music
local t            = 0     -- global time
local wowHz        = 0.9   -- slow drift
local flutterHz    = 8.0   -- fast jitter
local wowDepth     = 0.003 -- ±0.3 %  (subtle)
local flutterDepth = 0.001 -- ±0.1 %

function love.load()
    music = love.audio.newSource("loop.ogg", "stream")
    music:setLooping(true)
    music:play()
end

function love.update(dt)
    t             = t + dt
    local wow     = wowDepth * math.sin(2 * math.pi * wowHz * t)
    local flutter = flutterDepth * math.sin(2 * math.pi * flutterHz * t)
    music:setPitch(1 + wow + flutter) -- 1 = normal pitch :contentReference[oaicite:0]{index=0}
end

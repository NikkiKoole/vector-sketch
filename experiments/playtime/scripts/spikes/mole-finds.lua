-- mole-finds: the things in the mole's earth, and how each is drawn (code-drawn, flat with a dark outline).
-- Food is what lived or grew (Nikki 2026-11-16: "just you can eat some things, plant and animal"); the rest he
-- sniffs and pushes away. Loaded by scripts/spikes/mole.playtime.lua:
--   local finds = love.filesystem.load('scripts/spikes/mole-finds.lua')()
--   finds.KINDS[kind]   { r, bites, food, color, ... } (sizes for a 0.3 Mipo)
--   finds.FOODS         the food kinds, in a fixed order (the tastes are dealt over these)
--   finds.draw(kind, x, y, r, angle, t, veil)   r the body's radius now (bites shrink it), t the clock (worms
--                                                wiggle), veil 0..1 earth over it (still buried)
local lib = {}

local INK = { 0.16, 0.1, 0.07 }

lib.KINDS = {
    worm = { r = 26, bites = 1, food = true, color = { 0.93, 0.6, 0.62 } },
    beetle = { r = 24, bites = 1, food = true, color = { 0.16, 0.26, 0.3 } },
    snail = { r = 26, bites = 1, food = true, color = { 0.62, 0.42, 0.22 } },
    carrot = { r = 32, bites = 3, food = true, color = { 0.95, 0.5, 0.15 } },
    potato = { r = 38, bites = 2, food = true, color = { 0.8, 0.66, 0.42 } },
    berry = { r = 16, bites = 1, food = true, color = { 0.42, 0.16, 0.55 } },
    mushroom = { r = 28, bites = 2, food = true, color = { 0.85, 0.2, 0.17 } },
    acorn = { r = 20, bites = 1, food = true, color = { 0.6, 0.42, 0.2 } },
    -- not food
    pebble = { r = 22, color = { 0.62, 0.6, 0.56 } },
    bone = { r = 26, color = { 0.93, 0.9, 0.8 } },
    button = { r = 18, color = { 0.25, 0.55, 0.85 } },
    marble = { r = 15, color = { 0.3, 0.7, 0.75 } },
    -- the rare ones
    goldworm = { r = 30, bites = 1, food = true, rare = true, color = { 1, 0.8, 0.2 } },
    bigcarrot = { r = 70, bites = 6, food = true, rare = true, color = { 0.95, 0.5, 0.15 } },
}
lib.FOODS = { 'worm', 'beetle', 'snail', 'carrot', 'potato', 'berry', 'mushroom', 'acorn' }
-- how many of each go in the earth, and between which depths (world y; the grass is near 0): the deeper, the
-- stranger. Worms and roots near the top, beetles and potatoes in the clay, snails and acorns deep, buttons and
-- marbles near the bottom, the golden worms deepest. (The giant carrot is placed on its own.)
lib.BANDS = {
    worm = { 40, 300, 5000 }, carrot = { 15, 300, 2500 }, mushroom = { 15, 300, 4000 }, berry = { 15, 300, 3000 },
    beetle = { 25, 3000, 10000 }, potato = { 15, 2500, 8000 }, pebble = { 20, 300, 12000 },
    bone = { 10, 5000, 14000 }, snail = { 20, 8000, 15000 }, acorn = { 20, 7000, 14000 },
    button = { 8, 12000, 17000 }, marble = { 8, 12000, 17000 }, goldworm = { 5, 15000, 17500 },
}

local function set(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

-- a shape filled in the colour set, then its outline in ink: outlined('circle', x, y, r), outlined('arc', 'closed', ...)
local function outlined(shape, ...)
    love.graphics[shape]('fill', ...)
    set(INK)
    love.graphics[shape]('line', ...)
end

local function worm(r, t, col, gold)
    -- a wiggling row of round segments, head on the right
    local n, len = 9, r * 3
    local pts = {}
    for i = 0, n do
        local u = i / n
        local x = -len / 2 + u * len
        pts[#pts + 1] = { x, math.sin(u * 5 + t * 5) * r * 0.22 }
    end
    local w = r * 0.42
    set(INK)
    for _, p in ipairs(pts) do love.graphics.circle('fill', p[1], p[2], w + r * 0.07) end
    for i, p in ipairs(pts) do
        local shade = (i % 2 == 0) and 0.92 or 1
        love.graphics.setColor(col[1] * shade, col[2] * shade, col[3] * shade, 1)
        love.graphics.circle('fill', p[1], p[2], w)
    end
    -- the saddle band
    local band = pts[math.floor(n * 0.65)]
    love.graphics.setColor(col[1] * 0.85, col[2] * 0.7, col[3] * 0.7, 1)
    love.graphics.circle('fill', band[1], band[2], w * 1.05)
    if gold then
        love.graphics.setColor(1, 1, 0.85, 0.9)
        local s = r * 0.25 * (0.6 + 0.4 * math.sin(t * 7))
        local hx, hy = pts[3][1], pts[3][2] - w * 0.4
        love.graphics.polygon('fill', hx, hy - s, hx + s * 0.3, hy, hx, hy + s, hx - s * 0.3, hy)
        love.graphics.polygon('fill', hx - s, hy, hx, hy - s * 0.3, hx + s, hy, hx, hy + s * 0.3)
    end
end

local function beetle(r, t, col)
    set(INK)
    for side = -1, 1, 2 do
        for k = -1, 1 do
            local lx = k * r * 0.5
            love.graphics.line(lx, 0, lx + k * r * 0.2, side * r * 0.95)
        end
    end
    set(INK)
    love.graphics.circle('fill', r * 0.9, 0, r * 0.32)
    set(col)
    outlined('ellipse', 0, 0, r * 0.85, r * 0.62)
    love.graphics.line(-r * 0.85, 0, r * 0.4, 0)
    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.ellipse('fill', -r * 0.25, -r * 0.3, r * 0.3, r * 0.12)
end

local function snail(r, t, col)
    set({ 0.82, 0.74, 0.6 })
    outlined('ellipse', r * 0.15, r * 0.55, r * 1.05, r * 0.32)
    set(INK)
    love.graphics.line(r * 0.95, r * 0.35, r * 1.15, -r * 0.1)
    love.graphics.circle('fill', r * 1.15, -r * 0.1, r * 0.08)
    set(col)
    outlined('circle', -r * 0.1, -r * 0.05, r * 0.7)
    set(INK)
    love.graphics.arc('line', 'open', -r * 0.1, -r * 0.05, r * 0.45, 0, 4.5)
    love.graphics.arc('line', 'open', -r * 0.05, -r * 0.05, r * 0.22, 0, 4.5)
end

local function carrot(r, t, col)
    -- along x: leaves at the back (left), the tip on the right
    set({ 0.35, 0.62, 0.22 })
    for k = -1, 1 do
        outlined('ellipse', -r * 1.55, k * r * 0.3, r * 0.45, r * 0.14)
    end
    set(col)
    outlined('polygon', -r * 1.2, -r * 0.5, -r * 0.9, -r * 0.62, r * 0.4, -r * 0.3, r * 1.6, 0,
        r * 0.4, r * 0.3, -r * 0.9, r * 0.62, -r * 1.2, r * 0.5)
    set(INK)
    for k = 1, 3 do
        local x = -r * 0.7 + k * r * 0.5
        love.graphics.line(x, -r * 0.4 + k * r * 0.1, x + r * 0.12, -r * 0.2 + k * r * 0.05)
    end
end

local function potato(r, t, col)
    set(col)
    outlined('ellipse', 0, 0, r * 1.1, r * 0.82)
    set({ 0.45, 0.33, 0.2 })
    for _, e in ipairs({ { -0.5, -0.2 }, { 0.3, 0.3 }, { 0.6, -0.35 }, { -0.1, 0.45 } }) do
        love.graphics.circle('fill', e[1] * r, e[2] * r, r * 0.07)
    end
end

local function berry(r, t, col)
    set(col)
    outlined('circle', 0, 0, r)
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.circle('fill', -r * 0.35, -r * 0.35, r * 0.25)
end

local function mushroom(r, t, col)
    set({ 0.95, 0.9, 0.8 })
    outlined('rectangle', -r * 0.25, -r * 0.1, r * 0.5, r * 1, r * 0.15)
    set(col)
    outlined('arc', 'closed', 0, 0, r, math.pi, 2 * math.pi)
    love.graphics.setColor(1, 1, 1, 1)
    for _, d in ipairs({ { -0.5, -0.35 }, { 0.15, -0.6 }, { 0.55, -0.25 } }) do
        love.graphics.circle('fill', d[1] * r, d[2] * r, r * 0.13)
    end
end

local function acorn(r, t, col)
    set(col)
    outlined('ellipse', r * 0.25, 0, r * 0.85, r * 0.7)
    set({ 0.42, 0.3, 0.16 })
    outlined('arc', 'closed', -r * 0.3, 0, r * 0.75, math.pi / 2, math.pi * 1.5)
    set(INK)
    love.graphics.line(-r * 1.05, 0, -r * 1.35, -r * 0.15)
end

local function pebble(r, t, col)
    set(col)
    outlined('ellipse', 0, 0, r * 1.15, r * 0.85)
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.ellipse('fill', -r * 0.35, -r * 0.3, r * 0.35, r * 0.15)
end

local function bone(r, t, col)
    set(col)
    for _, e in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
        outlined('circle', e[1] * r * 1.05, e[2] * r * 0.28, r * 0.32)
    end
    set(col)
    love.graphics.rectangle('fill', -r * 1.05, -r * 0.3, r * 2.1, r * 0.6)
    set(INK)
    love.graphics.line(-r * 0.8, -r * 0.3, r * 0.8, -r * 0.3)
    love.graphics.line(-r * 0.8, r * 0.3, r * 0.8, r * 0.3)
end

local function button(r, t, col)
    set(col)
    outlined('circle', 0, 0, r)
    set(INK)
    love.graphics.circle('line', 0, 0, r * 0.72)
    for _, h in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
        love.graphics.circle('fill', h[1] * r * 0.25, h[2] * r * 0.25, r * 0.12)
    end
end

local function marble(r, t, col)
    set(col)
    outlined('circle', 0, 0, r)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.arc('line', 'open', 0, 0, r * 0.55, 0.4, 2.4)
    love.graphics.circle('fill', -r * 0.4, -r * 0.4, r * 0.2)
end

local DRAW = { worm = worm, beetle = beetle, snail = snail, carrot = carrot, potato = potato, berry = berry,
    mushroom = mushroom, acorn = acorn, pebble = pebble, bone = bone, button = button, marble = marble,
    goldworm = function(r, t, col) worm(r, t, col, true) end, bigcarrot = carrot }

function lib.draw(kind, x, y, r, angle, t, veil)
    local def = lib.KINDS[kind]
    local fn = def and DRAW[kind]
    if not fn then return end
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle or 0)
    love.graphics.setLineWidth(math.max(2, r * 0.12))
    fn(r, t or 0, def.color)
    if veil and veil > 0 then -- still in the earth: the earth's colour over it, so it reads as buried
        love.graphics.setColor(0.36, 0.25, 0.16, veil)
        love.graphics.circle('fill', 0, 0, r * (kind:find('worm') and 1.9 or kind:find('carrot') and 1.9 or 1.25))
    end
    love.graphics.pop()
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return lib

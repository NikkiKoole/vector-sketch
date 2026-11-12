-- pad: a 2D pad to press and drag on, with labelled spots on it (BESPOKE-UI.md BU1). Out of the
-- voicebox's vowel chart (Nikki 2026-11-12: "a custom ui element to show which vowel was playing,
-- ... places that could be improved by having a more bespoke ui"): a map of the thing itself (the
-- mouth, a mood, the wind) instead of two sliders for its two numbers.
--
--   local changed, u, v = pad.draw('feel', x, y, w, h, {
--       value = { u, v },                         -- where the dot is (0..1 each, v down)
--       spots = { { u = .8, v = .3, label = 'happy' }, ... },
--       edges = { left = 'unhappy', right = 'happy', top = 'excited', bottom = 'calm' },
--       corners = { bl = 'front', br = 'back' },  -- small words in the corners instead
--       lit = true,                               -- the dot bigger and warm (sounding, held …)
--   })
--   changed: the pad was pressed or dragged this frame, u, v: where (else the value given).
--   pad.pressed(id): the press began this frame (a note to start, say).
--   pad.weights(spots, u, v, reach): how close to each spot, 0..1 (1 on it, 0 at reach and past),
--   for blending between neighbours.
--
-- A press is the pad's only if it starts on the pad; a drag carries on outside it (clamped).
-- Call inside a ui.panel (it reads ui.mouseX / ui.mouseY like the other widgets).

local ui = require('src.ui.all')

local lib = {}

local held = {}      -- id -> true while a press that began on it lasts
local pressedNow = {} -- id -> true on the frame a press began
local wasDown = {}

local BG = { 0.13, 0.12, 0.11, 0.9 }
local GRID = { 1, 1, 1, 0.12 }
local SPOT = { 1, 0.85, 0.6, 0.9 }
local DOT = { 0.6, 0.9, 1, 1 }
local DOT_LIT = { 1, 0.4, 0.45, 1 }
local WORD = { 1, 1, 1, 0.5 }

local function clamp01(v) return math.max(0, math.min(1, v)) end

function lib.draw(id, x, y, w, h, opts)
    opts = opts or {}
    love.graphics.setColor(BG)
    love.graphics.rectangle('fill', x, y, w, h, 8, 8)
    love.graphics.setColor(GRID)
    for i = 1, 3 do
        love.graphics.line(x + w * i / 4, y + 4, x + w * i / 4, y + h - 4)
        love.graphics.line(x + 4, y + h * i / 4, x + w - 4, y + h * i / 4)
    end
    local font = love.graphics.getFont()
    local fh = font:getHeight()
    for _, s in ipairs(opts.spots or {}) do
        local sx, sy = x + s.u * w, y + s.v * h
        love.graphics.setColor(s.colour or SPOT)
        love.graphics.circle('fill', sx, sy, 4)
        if s.label then
            -- the word on the side of the dot that has room
            local tw = font:getWidth(s.label)
            local tx = (s.u > 0.7) and (sx - tw - 6) or (sx + 6)
            love.graphics.print(s.label, tx, sy - fh / 2)
        end
    end
    love.graphics.setColor(WORD)
    local e = opts.edges
    if e then
        if e.left then love.graphics.print(e.left, x + 6, y + h / 2 - fh / 2) end
        if e.right then love.graphics.print(e.right, x + w - font:getWidth(e.right) - 6, y + h / 2 - fh / 2) end
        if e.top then love.graphics.print(e.top, x + w / 2 - font:getWidth(e.top) / 2, y + 2) end
        if e.bottom then love.graphics.print(e.bottom, x + w / 2 - font:getWidth(e.bottom) / 2, y + h - fh - 2) end
    end
    local c = opts.corners
    if c then
        if c.tl then love.graphics.print(c.tl, x + 6, y + 2) end
        if c.tr then love.graphics.print(c.tr, x + w - font:getWidth(c.tr) - 6, y + 2) end
        if c.bl then love.graphics.print(c.bl, x + 6, y + h - fh - 2) end
        if c.br then love.graphics.print(c.br, x + w - font:getWidth(c.br) - 6, y + h - fh - 2) end
    end
    -- press and drag
    local mx, my = ui.mouseX, ui.mouseY
    local down = love.mouse.isDown(1)
    local inside = mx >= x and mx <= x + w and my >= y and my <= y + h
    pressedNow[id] = false
    if down and not wasDown[id] and inside then
        held[id] = true
        pressedNow[id] = true
    elseif not down then
        held[id] = nil
    end
    wasDown[id] = down
    local value = opts.value or { 0.5, 0.5 }
    local u, v = value[1], value[2]
    local changed = false
    if held[id] then
        u, v = clamp01((mx - x) / w), clamp01((my - y) / h)
        changed = true
    end
    local lit = opts.lit or held[id]
    love.graphics.setColor(lit and DOT_LIT or DOT)
    love.graphics.circle('fill', x + u * w, y + v * h, lit and 9 or 7)
    love.graphics.setColor(1, 1, 1, 1)
    return changed, u, v
end

function lib.pressed(id) return pressedNow[id] == true end
function lib.isHeld(id) return held[id] == true end

function lib.weights(spots, u, v, reach)
    reach = reach or 0.35
    local out = {}
    for i, s in ipairs(spots) do
        local d = math.sqrt((s.u - u) ^ 2 + (s.v - v) ^ 2)
        local k = clamp01(1 - d / reach)
        out[i] = k * k * (3 - 2 * k) -- smooth: a little way off a spot is still nearly all of it
    end
    return out
end

return lib

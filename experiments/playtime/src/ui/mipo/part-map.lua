-- src/ui/mipo/part-map.lua: pick a Mipo's part, or a face's feature, on a picture of one (BESPOKE-UI;
-- Nikki 2026-11-12: "instead of all the buttons ... a bespoke body skeleton ui and face ui for selecting
-- these parts, like a default skeleton face").
--   lib.drawBody(id, x, y, w, partNames, selected, opts) -> picked part name or nil, height used
--      a default Mipo skeleton with the parts this one has (necks, torso bands, lobes, noses as many as
--      it has; no head on a potato head); its left side drawn on the left, as on the stage.
--   lib.drawFace(id, x, y, w, features, isOpen) -> picked feature or nil, height used
--      a default face: brows, eyes, nose, mouth.
-- A pick is a press and a release on the same spot (as ui.button). Drawn in UI units.
local lib = {}

local ui = require('src.ui.all')
local theme = ui.theme

local BODY_H = 204
local FACE_H = 120

local BG = { 0.13, 0.12, 0.11, 0.6 }
local SELECTED = { 242 / 255, 133 / 255, 0 }
local WORD = { 1, 1, 1, 0.6 }

local pressedOn = {} -- id -> the zone a press began on

-- === ZONES ===
-- { name, kind = 'circle' (x, y, r) | 'seg' (x1, y1, x2, y2, r: a capsule) | 'rect' (x, y, w, h)
--   | 'ellipse' (x, y, rx, ry) }
local function distToSeg(px, py, x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    local len2 = dx * dx + dy * dy
    local t = len2 > 0 and math.max(0, math.min(1, ((px - x1) * dx + (py - y1) * dy) / len2)) or 0
    local cx, cy = x1 + t * dx, y1 + t * dy
    return math.sqrt((px - cx) ^ 2 + (py - cy) ^ 2)
end

local function hits(z, mx, my)
    if z.kind == 'circle' then return (mx - z.x) ^ 2 + (my - z.y) ^ 2 <= (z.r + 2) ^ 2 end
    if z.kind == 'seg' then return distToSeg(mx, my, z.x1, z.y1, z.x2, z.y2) <= z.r + 2 end
    if z.kind == 'rect' then return mx >= z.x and mx <= z.x + z.w and my >= z.y and my <= z.y + z.h end
    if z.kind == 'ellipse' then return ((mx - z.x) / z.rx) ^ 2 + ((my - z.y) / z.ry) ^ 2 <= 1.1 end
    return false
end

local function shape(z, mode)
    if z.kind == 'circle' then
        love.graphics.circle(mode, z.x, z.y, z.r)
    elseif z.kind == 'seg' then
        if mode == 'fill' then
            love.graphics.setLineWidth(z.r * 2)
            love.graphics.line(z.x1, z.y1, z.x2, z.y2)
            love.graphics.circle('fill', z.x1, z.y1, z.r)
            love.graphics.circle('fill', z.x2, z.y2, z.r)
        else
            -- the capsule's outline: its two sides and round ends
            local a = math.atan2(z.y2 - z.y1, z.x2 - z.x1)
            local nx, ny = -math.sin(a) * z.r, math.cos(a) * z.r
            love.graphics.line(z.x1 + nx, z.y1 + ny, z.x2 + nx, z.y2 + ny)
            love.graphics.line(z.x1 - nx, z.y1 - ny, z.x2 - nx, z.y2 - ny)
            love.graphics.arc('line', 'open', z.x1, z.y1, z.r, a + math.pi / 2, a + math.pi * 1.5)
            love.graphics.arc('line', 'open', z.x2, z.y2, z.r, a - math.pi / 2, a + math.pi / 2)
        end
    elseif z.kind == 'rect' then
        love.graphics.rectangle(mode, z.x, z.y, z.w, z.h, 4, 4)
    elseif z.kind == 'ellipse' then
        love.graphics.ellipse(mode, z.x, z.y, z.rx, z.ry)
    end
end

-- draw the zones, the hovered and picked ones lit; returns the zone picked this frame, or nil
-- (noBackground: the caller drew its own)
local function drawZones(id, zones, isLit, x, y, w, h, noBackground)
    if not noBackground then
        love.graphics.setColor(BG)
        love.graphics.rectangle('fill', x, y, w, h, 8, 8)
    end
    local mx, my = ui.mouseX, ui.mouseY
    local inside = mx >= x and mx <= x + w and my >= y and my <= y + h
    local hover
    if inside then
        for i = #zones, 1, -1 do -- the last drawn is on top
            if hits(zones[i], mx, my) then hover = zones[i] break end
        end
    end
    for _, z in ipairs(zones) do
        local colour = isLit(z.name) and SELECTED or (z == hover and theme.button.hover or theme.button.default)
        local alpha = z.ghost and 0.35 or 1 -- a ghost: a part that's off, there to pick
        love.graphics.setColor(colour[1], colour[2], colour[3], alpha)
        shape(z, 'fill')
        local o = theme.button.outline
        love.graphics.setColor(o[1], o[2], o[3], alpha)
        love.graphics.setLineWidth(1.5)
        shape(z, 'line')
    end
    love.graphics.setLineWidth(1)
    if hover then
        love.graphics.setColor(WORD)
        love.graphics.print(hover.label or hover.name, x + 6, y + 4)
    end
    love.graphics.setColor(1, 1, 1, 1)

    local picked
    if ui.mousePressed then pressedOn[id] = hover and hover.name or false end
    if ui.mouseReleased then
        if hover and pressedOn[id] == hover.name then picked = hover.name end
        pressedOn[id] = nil
    end
    return picked
end

-- === THE BODY ===
local function count(has, prefix)
    local n = 0
    while has[prefix .. (n + 1)] do n = n + 1 end
    return n
end

local function bodyZones(x, y, w, has)
    local zones = {}
    local function add(z) if has[z.name] then zones[#zones + 1] = z end end
    local cx = x + w / 2
    y = y + 8 -- room above the ears
    local potato = not has.head
    local necks, torsos, noses, lobes = count(has, 'neck'), count(has, 'torso'), count(has, 'nose'), count(has, 'lobe')

    -- the torso: torso1 at the bottom, the top band last; a potato head's reaches up where the head would be
    local torsoTop = potato and (y + 22) or (y + 70)
    local torsoBottom = y + 128
    local torsoW = potato and 60 or 50
    -- legs first: the torso is drawn over their tops
    for _, side in ipairs({ { 'l', -1 }, { 'r', 1 } }) do
        local s, k = side[1], side[2]
        local hx = cx + k * 14
        add({ name = s .. 'uleg', kind = 'seg', x1 = hx, y1 = torsoBottom - 4, x2 = hx + k * 4, y2 = y + 154, r = 7 })
        add({ name = s .. 'lleg', kind = 'seg', x1 = hx + k * 4, y1 = y + 156, x2 = hx + k * 6, y2 = y + 178, r = 6 })
        add({ name = s .. 'foot', kind = 'ellipse', x = hx + k * 12, y = y + 186, rx = 14, ry = 7 })
    end
    local bandH = (torsoBottom - torsoTop) / math.max(1, torsos)
    for i = 1, torsos do
        local top = torsoBottom - i * bandH
        add({ name = 'torso' .. i, kind = 'rect', x = cx - torsoW / 2, y = top + 1, w = torsoW, h = bandH - 2 })
    end
    for i = 1, lobes do
        local k = (i % 2 == 1) and -1 or 1
        local row = math.floor((i - 1) / 2)
        add({ name = 'lobe' .. i, kind = 'circle', x = cx + k * (torsoW / 2 + 2),
            y = torsoBottom - 14 - row * 18, r = 7 })
    end
    -- arms from the shoulders (a potato's from its sides), hanging out and down
    local shoulderY = potato and (torsoTop + (torsoBottom - torsoTop) * 0.45) or (torsoTop + 8)
    for _, side in ipairs({ { 'l', -1 }, { 'r', 1 } }) do
        local s, k = side[1], side[2]
        local sx = cx + k * (torsoW / 2 - 2)
        add({ name = s .. 'uarm', kind = 'seg', x1 = sx, y1 = shoulderY, x2 = sx + k * 22, y2 = shoulderY + 26, r = 6 })
        add({ name = s .. 'larm', kind = 'seg', x1 = sx + k * 24, y1 = shoulderY + 28, x2 = sx + k * 34,
            y2 = shoulderY + 54, r = 5 })
        add({ name = s .. 'hand', kind = 'circle', x = sx + k * 38, y = shoulderY + 64, r = 8 })
    end
    -- the neck bands, then the head with its ears and noses
    local headY = y + 32
    if not potato and necks == 0 then -- no neck: a faint one to pick, for turning it on
        zones[#zones + 1] = { name = 'neck', kind = 'rect', x = cx - 7, y = headY + 22, w = 14,
            h = torsoTop - headY - 20, ghost = true, label = 'neck (off)' }
    end
    if not potato then
        local neckTop, neckBottom = headY + 22, torsoTop + 2
        local neckH = (neckBottom - neckTop) / math.max(1, necks)
        for i = 1, necks do
            local top = neckBottom - i * neckH
            add({ name = 'neck' .. i, kind = 'rect', x = cx - 7, y = top, w = 14, h = neckH })
        end
    end
    local earY = potato and (torsoTop + 4) or (headY - 18)
    local earX = potato and (torsoW / 2 - 6) or 16
    add({ name = 'lear', kind = 'ellipse', x = cx - earX, y = earY, rx = 7, ry = 12 })
    add({ name = 'rear', kind = 'ellipse', x = cx + earX, y = earY, rx = 7, ry = 12 })
    add({ name = 'head', kind = 'circle', x = cx, y = headY, r = 22 })
    local noseY = potato and (torsoTop + 26) or (headY + 4)
    if noses == 0 then -- none as a body (none, or drawn on the face): a faint one to pick
        zones[#zones + 1] = { name = 'nose', kind = 'circle', x = cx + 16, y = noseY, r = 7, ghost = true }
    end
    for i = 1, noses do
        add({ name = 'nose' .. i, kind = 'circle', x = cx + 6 + i * 10, y = noseY, r = 5 })
    end
    return zones
end

function lib.drawBody(id, x, y, w, partNames, selected, opts)
    local has = {}
    for _, name in ipairs(partNames) do has[name] = true end
    local zones = bodyZones(x, y, w, has)
    local isLit = (opts and opts.isLit) or function(name) return name == selected end
    return drawZones(id, zones, isLit, x, y, w, BODY_H), BODY_H
end

-- === THE FACE ===
-- features: { brows = key, eyes = key, nose = key, mouth = key } (only the ones it has)
function lib.drawFace(id, x, y, w, features, isOpen)
    local cx = x + w / 2
    local zones = {}
    local function add(z) if features[z.name] then zones[#zones + 1] = z end end
    -- the face's outline, drawn under the features
    love.graphics.setColor(BG)
    love.graphics.rectangle('fill', x, y, w, FACE_H, 8, 8)
    love.graphics.setColor(theme.button.outline)
    love.graphics.ellipse('line', cx, y + FACE_H / 2, math.min(70, w / 2 - 6), FACE_H / 2 - 6)
    add({ name = 'brows', kind = 'seg', x1 = cx - 42, y1 = y + 26, x2 = cx - 16, y2 = y + 22, r = 4 })
    add({ name = 'eyes', kind = 'circle', x = cx - 28, y = y + 44, r = 11 })
    add({ name = 'nose', kind = 'ellipse', x = cx, y = y + 66, rx = 8, ry = 10 })
    add({ name = 'mouth', kind = 'ellipse', x = cx, y = y + 92, rx = 26, ry = 8 })
    -- the other brow and eye: the same feature, one zone each
    if features.brows then
        zones[#zones + 1] = { name = 'brows', kind = 'seg', x1 = cx + 16, y1 = y + 22, x2 = cx + 42, y2 = y + 26,
            r = 4 }
    end
    if features.eyes then
        zones[#zones + 1] = { name = 'eyes', kind = 'circle', x = cx + 28, y = y + 44, r = 11 }
    end
    local picked = drawZones(id, zones, function(name) return isOpen(name) end, x, y, w, FACE_H, true)
    return picked, FACE_H
end

return lib

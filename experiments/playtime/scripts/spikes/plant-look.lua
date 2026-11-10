-- plant-look: draws a grown plant (plant-grow.lua), not a scene. Loaded with
-- love.filesystem.load('scripts/spikes/plant-look.lua')() -> { draw, reset }.
-- draw(plant, opts): opts { time, sway (0..), wind (-1..1), outlines, stroke (which crayon stroke) }.
-- docs/FLORA.md. Stems are ribbons of Nikki's crayon strokes (a dark one under a coloured one, as the
-- plants spike); leaves and petals her drawn shapes (textures/plants: outline + mask), each leaf bent along
-- its droop (a strip, not a stiff sprite); small flowers dots of her drawn crayon rings. Order: leaves behind
-- the stems, the stems (branches under their parents), leaves in front, heads.
-- Sway: the plant bends in the wind as one (more toward its top), its leaves flutter on their own.
local lib = {}

local STROKE = require('src.drawn-stroke')
local OUTLINE = { 0.17, 0.13, 0.1 }
local UP, DOWN = -math.pi / 2, math.pi / 2

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end
local function smooth(x) x = clamp(x, 0, 1); return x * x * (3 - 2 * x) end
local function mix(c1, c2, k)
    return { c1[1] + (c2[1] - c1[1]) * k, c1[2] + (c2[2] - c1[2]) * k, c1[3] + (c2[3] - c1[3]) * k }
end
local function darker(c, k) return { c[1] * k, c[2] * k, c[3] * k } end
local function hash(a, b)
    local v = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
    return v - math.floor(v)
end
local function wrap(d) return math.atan2(math.sin(d), math.cos(d)) end

---------------------------------------------------------------- the recorder

-- A plant is drawn once into triangles (G below mimics the few love.graphics calls the drawing uses, with
-- its own transform stack), kept as meshes and drawn every frame through the sway shader: three meshes per
-- plant (leaves behind, stems, leaves in front and heads), each one draw. Leaves, petals and dots come from
-- one atlas of the drawn parts; stems from the plant's crayon stroke (it repeats along them).
local FORMAT = {
    { 'VertexPosition', 'float', 2 },
    { 'VertexTexCoord', 'float', 2 },
    { 'VertexColor', 'byte', 4 },
    { 'Anchor', 'float', 4 }, -- a leaf's foot (x, y), its flutter phase and amount (0: none)
}

local G = { list = nil, r = 1, g = 1, b = 1, a = 1, lw = 1, anchor = nil }
local M = { 1, 0, 0, 1, 0, 0 } -- x' = M1 x + M3 y + M5, y' = M2 x + M4 y + M6
local stack = {}
local NO_ANCHOR = { 0, 0, 0, 0 }

local function vert(x, y, u, v)
    local X, Y = M[1] * x + M[3] * y + M[5], M[2] * x + M[4] * y + M[6]
    local an = G.anchor or NO_ANCHOR
    local list = G.list
    list[#list + 1] = { X, Y, u, v, G.r, G.g, G.b, G.a, an[1], an[2], an[3], an[4] }
end
local function tri(x1, y1, u1, v1, x2, y2, u2, v2, x3, y3, u3, v3)
    vert(x1, y1, u1, v1); vert(x2, y2, u2, v2); vert(x3, y3, u3, v3)
end

function G.setColor(r, g, b, a)
    if type(r) == 'table' then r, g, b, a = r[1], r[2], r[3], r[4] end
    G.r, G.g, G.b, G.a = r, g, b, a or 1
end
function G.setLineWidth(w) G.lw = w end
function G.push() stack[#stack + 1] = { M[1], M[2], M[3], M[4], M[5], M[6] } end
function G.pop() local t = table.remove(stack); for k = 1, 6 do M[k] = t[k] end end
function G.translate(x, y) M[5], M[6] = M[1] * x + M[3] * y + M[5], M[2] * x + M[4] * y + M[6] end
function G.rotate(r)
    local c, s = math.cos(r), math.sin(r)
    M[1], M[2], M[3], M[4] = M[1] * c + M[3] * s, M[2] * c + M[4] * s, M[3] * c - M[1] * s, M[4] * c - M[2] * s
end

-- love.graphics.draw's way: region at (x, y), turned r, scaled sx, sy, its own (ox, oy) on that point
function G.draw(reg, x, y, r, sx, sy, ox, oy)
    r, sx, ox, oy = r or 0, sx or 1, ox or 0, oy or 0
    sy = sy or sx
    local c, s = math.cos(r), math.sin(r)
    local function at(px, py)
        local lx, ly = (px - ox) * sx, (py - oy) * sy
        return x + c * lx - s * ly, y + s * lx + c * ly
    end
    local ax, ay = at(0, 0)
    local bx, by = at(reg.w, 0)
    local cx, cy = at(reg.w, reg.h)
    local dx, dy = at(0, reg.h)
    tri(ax, ay, reg.u0, reg.v0, bx, by, reg.u1, reg.v0, cx, cy, reg.u1, reg.v1)
    tri(ax, ay, reg.u0, reg.v0, cx, cy, reg.u1, reg.v1, dx, dy, reg.u0, reg.v1)
end

local CIRCLE, WHITE -- atlas regions (below)
function G.circle(_, x, y, r) G.draw(CIRCLE, x, y, 0, r * 2 / CIRCLE.w, r * 2 / CIRCLE.h, CIRCLE.w / 2, CIRCLE.h / 2) end
function G.ellipse(_, x, y, rx, ry)
    G.draw(CIRCLE, x, y, 0, rx * 2 / CIRCLE.w, ry * 2 / CIRCLE.h, CIRCLE.w / 2, CIRCLE.h / 2)
end
function G.line(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1e-6 then return end
    local nx, ny = -dy / len * G.lw / 2, dx / len * G.lw / 2
    local u, v = (WHITE.u0 + WHITE.u1) / 2, (WHITE.v0 + WHITE.v1) / 2
    tri(x1 + nx, y1 + ny, u, v, x2 + nx, y2 + ny, u, v, x2 - nx, y2 - ny, u, v)
    tri(x1 + nx, y1 + ny, u, v, x2 - nx, y2 - ny, u, v, x1 - nx, y1 - ny, u, v)
end

---------------------------------------------------------------- the atlas of drawn parts

-- every picture in textures/plants (its outline, and its mask baked into a white picture with its shape as
-- alpha, so a fill is a plain tint), a soft round dot and a white square, packed in shelves
local PARTS, ATLAS = {}, nil
do
    local PAD, WIDTH = 6, 2048
    local items = {}
    for _, file in ipairs(love.filesystem.getDirectoryItems('textures/plants')) do
        local name = file:match('^(.-)%.png$')
        if name and not name:match('%-mask$') then
            local line = love.image.newImageData('textures/plants/' .. file)
            local mask
            if love.filesystem.getInfo('textures/plants/' .. name .. '-mask.png', 'file') then
                mask = love.image.newImageData('textures/plants/' .. name .. '-mask.png')
                mask:mapPixel(function(_, _, r)
                    local t = math.max(0, math.min(1, (r - 0.1) / 0.4))
                    return 1, 1, 1, t * t * (3 - 2 * t)
                end)
            end
            PARTS[name] = { w = line:getWidth(), h = line:getHeight() }
            items[#items + 1] = { name = name, key = 'line', data = line }
            if mask then items[#items + 1] = { name = name, key = 'mask', data = mask } end
        end
    end
    local circle = love.image.newImageData(64, 64)
    circle:mapPixel(function(x, y)
        local d = math.sqrt((x + 0.5 - 32) ^ 2 + (y + 0.5 - 32) ^ 2)
        return 1, 1, 1, math.max(0, math.min(1, 31 - d))
    end)
    local white = love.image.newImageData(8, 8)
    white:mapPixel(function() return 1, 1, 1, 1 end)
    items[#items + 1] = { special = 'circle', data = circle }
    items[#items + 1] = { special = 'white', data = white }
    table.sort(items, function(p, q) return p.data:getHeight() > q.data:getHeight() end)
    local x, y, shelf = PAD, PAD, 0
    for _, it in ipairs(items) do
        local w, h = it.data:getDimensions()
        if x + w + PAD > WIDTH then x, y, shelf = PAD, y + shelf + PAD, 0 end
        it.x, it.y = x, y
        x, shelf = x + w + PAD, math.max(shelf, h)
    end
    local height = y + shelf + PAD
    local data = love.image.newImageData(WIDTH, height)
    for _, it in ipairs(items) do
        local w, h = it.data:getDimensions()
        data:paste(it.data, it.x, it.y, 0, 0, w, h)
        local reg = { u0 = it.x / WIDTH, v0 = it.y / height, u1 = (it.x + w) / WIDTH, v1 = (it.y + h) / height, w = w, h = h }
        if it.special == 'circle' then CIRCLE = reg
        elseif it.special == 'white' then WHITE = reg
        else PARTS[it.name][it.key] = reg end
    end
    ATLAS = love.graphics.newImage(data, { mipmaps = true })
    ATLAS:setMipmapFilter('linear')
end

local function part(name) return PARTS[name] end

-- a part with its base at (x, y), pointing along a (radians, math way: -pi/2 up), long world units
local function drawPart(name, x, y, a, long, fill, line, alpha, widthK)
    local p = part(name)
    if not p or long <= 0.5 then return end
    local angle = a + math.pi / 2
    local k = long / p.h
    local kx = k * (widthK or 1)
    alpha = alpha or 1
    if p.mask and fill then
        G.setColor(fill[1], fill[2], fill[3], alpha)
        G.draw(p.mask, x, y, angle, kx, k, p.w / 2, p.h)
    end
    if line ~= false then
        local c = line or OUTLINE
        G.setColor(c[1], c[2], c[3], alpha)
        G.draw(p.line, x, y, angle, kx, k, p.w / 2, p.h)
    end
end

-- a part bent along a curve: from (x, y) along a, turning toward the ground by droop (radians over its
-- length; less the closer it already points down; below 0 it cups upward), as a strip of SEGS pieces
local SEGS = 7
local bendL, bendR = {}, {}
local function strip(reg)
    local du, dv = reg.u1 - reg.u0, reg.v1 - reg.v0
    for i = 1, SEGS do
        local p, q, r, s = bendL[i], bendR[i], bendL[i + 1], bendR[i + 1]
        local v0, v1 = reg.v0 + p[3] * dv, reg.v0 + r[3] * dv
        tri(p[1], p[2], reg.u0, v0, q[1], q[2], reg.u0 + du, v0, r[1], r[2], reg.u0, v1)
        tri(q[1], q[2], reg.u0 + du, v0, s[1], s[2], reg.u0 + du, v1, r[1], r[2], reg.u0, v1)
    end
end
local function drawBent(name, x, y, a, long, widthK, droop, side, fill, line, lie)
    local p = part(name)
    if not p or long <= 1 then return end
    local half = long * p.w / p.h * (widthK or 1) / 2
    local step = long / SEGS
    local px, py = x, y
    for i = 0, SEGS do
        local u = i / SEGS
        if i > 0 then
            -- (a leaf lying on the ground bends only to flat, not into it; a negative droop cups it upward)
            local target = lie and (math.cos(a) >= 0 and 0.08 or math.pi - 0.08) or (droop < 0 and UP or DOWN)
            local d = wrap(target - a)
            if math.abs(d) > math.pi - 0.05 then d = math.abs(d) * side end
            local turn = math.abs(droop) / SEGS * (0.5 + u)
            a = a + clamp(d, -turn, turn)
            px, py = px + math.cos(a) * step, py + math.sin(a) * step
        end
        local nx, ny = math.sin(a), -math.cos(a) -- the left of the way it points
        bendL[i + 1] = { px + nx * half, py + ny * half, 1 - u }
        bendR[i + 1] = { px - nx * half, py - ny * half, 1 - u }
    end
    if p.mask and fill then
        G.setColor(fill[1], fill[2], fill[3], 1)
        strip(p.mask)
    end
    if line ~= false then
        local c = line or OUTLINE
        G.setColor(c[1], c[2], c[3], 1)
        strip(p.line)
    end
end

---------------------------------------------------------------- stems: crayon ribbons

-- a polyline (flat x, y list) with a width per point, as a strip of the stroke picture repeated along it
-- (its own texture, so it can repeat: into the stems list)
local function drawRibbon(pts, widths, pic, color)
    local n = #pts / 2
    if n < 2 or not pic then return end
    local thick = pic.alongX and pic.h or pic.w
    local long = pic.alongX and pic.w or pic.h
    local tileLen = long * (math.max(4, widths[1] or 10) / thick)
    local alongX = pic.alongX
    G.setColor(color)
    local function uv(across, d)
        if alongX then return d / tileLen, across end
        return across, d / tileLen
    end
    local function side(i)
        local a = math.max(1, i - 1)
        local c = math.min(n, i + 1)
        local dx, dy = pts[c * 2 - 1] - pts[a * 2 - 1], pts[c * 2] - pts[a * 2]
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 1e-6 then len = 1 end
        local w = widths[i] / 2
        local nx, ny = -dy / len * w, dx / len * w
        local x, y = pts[i * 2 - 1], pts[i * 2]
        return x + nx, y + ny, x - nx, y - ny
    end
    local dist = 0
    local ax, ay, bx, by = side(1)
    for i = 2, n do
        local seg = math.sqrt((pts[i * 2 - 1] - pts[i * 2 - 3]) ^ 2 + (pts[i * 2] - pts[i * 2 - 2]) ^ 2)
        local d0, d1 = dist, dist + seg
        local cx, cy, dx, dy = side(i)
        local u1, v1 = uv(0, d0)
        local u2, v2 = uv(1, d0)
        local u3, v3 = uv(0, d1)
        local u4, v4 = uv(1, d1)
        tri(ax, ay, u1, v1, bx, by, u2, v2, cx, cy, u3, v3)
        tri(bx, by, u2, v2, dx, dy, u4, v4, cx, cy, u3, v3)
        ax, ay, bx, by, dist = cx, cy, dx, dy, d1
    end
end

---------------------------------------------------------------- sway

-- the plant bends as one, toward its top: the shader shifts each point by its height above the foot
-- (h: over the plant's height) s * H * h^2; a leaf flutters round its foot on its own
local swayShader = love.graphics.newShader([[
#ifdef VERTEX
attribute vec4 Anchor;
uniform float sway;
uniform float height;
uniform float footY;
uniform float time;
uniform float flutter;
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vec2 p = vertex_position.xy;
    if (Anchor.w > 0.0) {
        float ang = sin(time * 3.1 + Anchor.z) * Anchor.w * flutter;
        vec2 d = p - Anchor.xy;
        float c = cos(ang);
        float s = sin(ang);
        p = Anchor.xy + vec2(c * d.x - s * d.y, s * d.x + c * d.y);
    }
    float h = clamp((footY - p.y) / height, 0.0, 1.3);
    p.x += sway * height * h * h;
    p.y += abs(sway) * height * h * h * h * 0.15;
    return transform_projection * vec4(p, vertex_position.zw);
}
#endif
#ifdef PIXEL
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) { return Texel(tex, uv) * color; }
#endif
]])

local function swayAmount(plant, opts)
    local t = opts.time or 0
    local ph = plant.x0 * 0.0031
    local gust = love.math.noise(t * 0.25, ph) - 0.5
    local amp = (opts.sway or 1) * (0.025 + 0.06 * math.abs(opts.wind or 0))
    return amp * (math.sin(t * 1.3 + ph) * 0.6 + math.sin(t * 2.3 + ph * 1.7) * 0.25 + gust * 1.2)
        + (opts.wind or 0) * 0.03 * (opts.sway or 1)
end

---------------------------------------------------------------- dots: small flowers

local BUD = { 0.46, 0.6, 0.32 }
-- one drawn crayon ring, centred on (x, y), d across, turned a little its own way
local function dot(x, y, d, col, h)
    if d < 1 then return end
    local a = (h - 0.5) * 2
    drawPart('berry-0' .. (1 + math.floor(h * 2.999)), x - math.sin(a) * d * 0.5, y + math.cos(a) * d * 0.5,
        a - math.pi / 2, d, col, OUTLINE, 1, 1)
end

-- a ball of dots round (x, y), r its radius; flat squashes it along (ax, ay), the outer ones first
local function dotBall(x, y, r, n, cols, seed, open, flat, ux, uy)
    ux, uy = ux or 0, uy or -1
    local vx, vy = -uy, ux
    for i = n, 1, -1 do
        local h = hash(seed, i)
        local ang = i * 2.39996 + seed
        local rr = r * math.sqrt((i - 0.5) / n) * (0.4 + 0.6 * open)
        local d = r * 0.6 * (0.8 + h * 0.4) * (0.45 + 0.55 * open)
        local col = mix(BUD, cols[1 + math.floor(h * #cols * 0.999)], open)
        local across, along = math.cos(ang) * rr, math.sin(ang) * rr * (flat or 1)
        dot(x + vx * across + ux * along, y + vy * across + uy * along, d, col, h)
    end
end

---------------------------------------------------------------- heads

-- a disc round the stalk's tip seen at a slant: across (vx, vy) full, along the stalk (ux, uy) squashed by
-- flat; back petals first, then the heart, then the front ones
local function drawRay(o, H, col, open, over, x, y, ux, uy, flat, heartCol)
    local vx, vy = -uy, ux
    local r = o.size * 0.5
    local n = H.petals or 16
    -- going over: the petals fall one by one, the heart swells and browns (a dandelion: a clock)
    local keep = 1 - smooth(over * 1.6)
    if H.clock and over > 0.35 then
        local k = smooth((over - 0.35) / 0.4)
        local cr = r * (0.6 + 0.5 * k)
        G.setLineWidth(math.max(1, o.size * 0.012))
        for i = 1, 40 do
            local h = hash(o.seed * 100, i)
            local ang = i * 2.39996
            local rx, ry = math.cos(ang) * cr * (0.8 + 0.2 * h), math.sin(ang) * cr * (0.8 + 0.2 * h)
            local ex, ey = x + vx * rx + ux * ry * 0.95, y + vy * rx + uy * ry * 0.95
            G.setColor(0.92, 0.92, 0.88, 0.75 * k)
            G.line(x, y, ex, ey)
            G.setColor(0.98, 0.98, 0.95, 0.9 * k)
            G.circle('fill', ex, ey, cr * 0.09)
        end
        G.setColor(0.55, 0.45, 0.3, 1)
        G.circle('fill', x, y, r * 0.12)
        return
    end
    local function petals(front)
        for i = 0, n - 1 do
            local h = hash(o.seed * 50, i)
            if h < keep or over == 0 then
                local ang = i / n * math.pi * 2 + o.seed * 6
                local s = math.sin(ang)
                if (s >= 0) == front then
                    local dx = math.cos(ang)
                    local dy = s * flat
                    local px, py = vx * dx + ux * dy, vy * dx + uy * dy
                    local len = math.sqrt(px * px + py * py)
                    local pa = math.atan2(py, px)
                    local c = H.colors[1 + math.floor(h * #H.colors * 0.999)]
                    c = mix(c, { 0.6, 0.5, 0.3 }, over * 0.6)
                    drawPart((H.petal or 'petal') .. '-0' .. (1 + i % 9), x + px * r * 0.15, y + py * r * 0.15, pa,
                        r * (0.3 + 0.7 * open) * (0.4 + 0.6 * len), front and c or darker(c, 0.85), OUTLINE, 1,
                        (H.petalWk or 0.5) * (0.6 + 0.4 * (1 - len) + 0.4 * len))
                end
            end
        end
    end
    petals(false)
    local hr = r * (H.heartK or 0.3) * (0.5 + 0.5 * open) * (1 + over * 0.5)
    local hp = part('heart-01')
    local hc = mix(heartCol, { 0.38, 0.26, 0.14 }, over)
    if hp then
        local k = hr * 2 / hp.w
        local ang = math.atan2(uy, ux) + math.pi / 2
        G.setColor(hc)
        G.draw(hp.mask, x, y, ang, k, k * math.max(0.3, flat), hp.w / 2, hp.h / 2)
        G.setColor(darker(hc, 0.45))
        G.draw(hp.line, x, y, ang, k, k * math.max(0.3, flat), hp.w / 2, hp.h / 2)
    end
    petals(true)
    if open < 0.3 then
        -- a closed bud: green bracts round it
        local k = 1 - open / 0.3
        drawPart('oval-0' .. (1 + math.floor(o.seed * 4.99)), x - ux * r * 0.25, y - uy * r * 0.25,
            math.atan2(uy, ux), r * 0.85 * k, mix(col, BUD, 0.85), OUTLINE, k, 0.9)
    end
    local _ = col
end

local function drawCup(o, H, col, open, over, x, y, a)
    local s = o.size
    if over > 0.4 and not H.tulip then
        -- a poppy's seed capsule: a grey-green pot with a lid
        local k = smooth((over - 0.4) / 0.3)
        drawPart('oval-01', x, y, a, s * 0.55 * k, { 0.55, 0.6, 0.45 }, OUTLINE, 1, 0.8)
        drawPart('oval-03', x + math.cos(a) * s * 0.5 * k, y + math.sin(a) * s * 0.5 * k, a + math.pi / 2,
            s * 0.25 * k, { 0.45, 0.42, 0.35 }, OUTLINE, 1, 0.5)
        drawPart('oval-03', x + math.cos(a) * s * 0.5 * k, y + math.sin(a) * s * 0.5 * k, a - math.pi / 2,
            s * 0.25 * k, { 0.45, 0.42, 0.35 }, OUTLINE, 1, 0.5)
        if over < 0.7 then return end
        return
    end
    local fade = 1 - smooth((over - 0.2) / 0.3)
    if open < 0.15 then
        -- the bud: a hairy green oval
        drawPart('oval-02', x, y, a, s * 0.55, BUD, OUTLINE, 1, 0.6)
        return
    end
    local n = H.petals or 4
    local spread = (H.tulip and 0.1 or 0.35) + (H.tulip and 0.25 or 0.75) * open
    -- back petals, then the heart, then the front
    for i = 1, n do
        local f = n > 1 and (i - 1) / (n - 1) - 0.5 or 0
        local pa = a + f * spread * 2
        local len = s * (H.tulip and 0.8 or 0.62) * (0.5 + 0.5 * open) * (0.4 + 0.6 * fade)
        if fade > 0.05 then
            drawPart('oval-0' .. (1 + (i + math.floor(o.seed * 5)) % 5), x, y, pa, len, darker(col, 0.85), OUTLINE, 1,
                H.tulip and 0.8 or 1.15)
        end
    end
    if not H.tulip and open > 0.5 then
        G.setColor(H.heart or { 0.1, 0.1, 0.1 })
        G.circle('fill', x + math.cos(a) * s * 0.18, y + math.sin(a) * s * 0.18, s * 0.09)
    end
    if fade > 0.05 then
        drawPart('oval-0' .. (1 + math.floor(o.seed * 4.99)), x, y + 2, a, s * (H.tulip and 0.85 or 0.55) *
            (0.5 + 0.5 * open) * (0.4 + 0.6 * fade), col, OUTLINE, 1, H.tulip and 0.75 or 1.2)
    end
end

local function drawBell(o, H, col, open, over, x, y, a)
    local s = o.size * (0.45 + 0.55 * open)
    if open < 0.2 then
        drawPart('oval-0' .. (1 + math.floor(o.seed * 4.99)), x, y, a, s * 0.6, mix(BUD, col, 0.3), OUTLINE, 1, 0.6)
        return
    end
    if over > 0.5 then
        drawPart('oval-03', x, y, a, s * 0.45, { 0.5, 0.5, 0.35 }, OUTLINE, 1, 0.6)
        return
    end
    col = mix(col, { 0.6, 0.5, 0.4 }, over)
    -- a short stalk, the bell, its mouth (darker, speckled inside for a foxglove)
    local sx, sy = x + math.cos(a) * s * 0.12, y + math.sin(a) * s * 0.12
    G.setColor(0.4, 0.5, 0.3)
    G.setLineWidth(math.max(1, s * 0.04))
    G.line(x, y, sx, sy)
    if H.pair then
        -- a second one beside it, a little behind
        drawPart('oval-02', sx, sy, a + 0.22, s * 0.92, darker(col, 0.88), OUTLINE, 1, 0.42)
    end
    drawPart(H.slim and 'oval-02' or 'oval-01', sx, sy, a - (H.pair and 0.12 or 0), s, col, OUTLINE, 1,
        H.slim and 0.42 or 0.62)
    local mx, my = sx + math.cos(a) * s * 0.92, sy + math.sin(a) * s * 0.92
    G.push()
    G.translate(mx, my)
    G.rotate(a + math.pi / 2)
    G.setColor(darker(col, 0.6))
    G.ellipse('fill', 0, 0, s * (H.slim and 0.15 or 0.26) * open, s * 0.06)
    if not H.slim then
        G.setColor(0.35, 0.12, 0.25)
        for i = 1, 4 do
            G.circle('fill', (hash(o.seed, i) - 0.5) * s * 0.3, -s * 0.06 - hash(i, o.seed) * s * 0.18,
                s * 0.02)
        end
    end
    G.pop()
end

local function drawHead(plant, o, rot, ox, oy)
    local H = o.def
    local x, y = ox, oy
    local a = o.a + rot
    local ux, uy = math.cos(a), math.sin(a)
    local cols = H.colors or { { 1, 1, 1 } }
    local col = cols[1 + math.floor(((o.colorI or 0) + plant.colors.flower) % 1 * #cols * 0.999)]
    if H.white and hash(plant.x0, 3) < H.white then col = { 0.97, 0.95, 0.94 } end
    local open, over = o.open, o.over
    local st = H.style
    if st == 'ray' then
        -- it faces you as it opens (face), side-on as a bud
        local flat = 0.18 + (H.face or 0.6) * 0.82 * open
        drawRay(o, H, col, open, over, x + ux * o.size * 0.05, y + uy * o.size * 0.05, ux, uy, flat, H.heart or col)
    elseif st == 'cup' then
        drawCup(o, H, col, open, over, x, y, a)
    elseif st == 'bell' then
        drawBell(o, H, col, open, over, x, y, a)
    elseif st == 'dots' then
        local brown = mix({ 1, 1, 1 }, { 0.6, 0.5, 0.4 }, over)
        local c2 = {}
        for i, c in ipairs(cols) do c2[i] = { c[1] * brown[1], c[2] * brown[2], c[3] * brown[3] } end
        dotBall(x + ux * o.size * 0.3, y + uy * o.size * 0.3, o.size * 0.5, 14, c2, o.seed * 31, open, 0.9, ux, uy)
    elseif st == 'whorl' then
        local c2 = {}
        for i, c in ipairs(cols) do c2[i] = mix(c, { 0.55, 0.45, 0.35 }, over) end
        dotBall(x, y, o.size * 0.5, 10, c2, o.seed * 31, open, 0.35, ux, uy)
    elseif st == 'umbel' then
        local c2 = {}
        for i, c in ipairs(cols) do c2[i] = mix(c, { 0.5, 0.45, 0.3 }, over) end
        dotBall(x + ux * o.size * 0.15, y + uy * o.size * 0.15, o.size * 0.55, 16, c2, o.seed * 31, open, 0.4, ux, uy)
    elseif st == 'spike' then
        -- a grass's seed spike: dots along the stalk's last stretch, hanging with it
        local n = 9
        for i = 1, n do
            local f = (i - 1) / (n - 1)
            local h = hash(o.seed * 70, i)
            local along = f * o.size * (0.4 + 0.6 * open)
            local across = (h - 0.5) * o.size * 0.2 * (1 - f * 0.4)
            local c = mix(BUD, cols[1 + math.floor(h * #cols * 0.999)], clamp(open + over, 0, 1))
            dot(x + ux * along - uy * across, y + uy * along + ux * across, o.size * 0.16 * (1 - f * 0.4), c, h)
        end
    elseif st == 'tail' then
        -- a foxtail: a dense soft cylinder of small dots, blunt at both ends
        local n = H.dots or 26
        local len = o.size * (0.4 + 0.6 * open)
        local w = o.size * (H.thick or 0.16)
        for i = 1, n do
            local f = (i - 0.5) / n
            local h = hash(o.seed * 70, i)
            local across = (h - 0.5) * w * math.sin(math.pi * (0.15 + 0.7 * f)) * 1.6
            local c = mix(BUD, cols[1 + math.floor(h * #cols * 0.999)], clamp(open * 0.7 + over, 0, 1))
            dot(x + ux * f * len - uy * across, y + uy * f * len + ux * across, w * 0.75, c, h)
        end
    elseif st == 'catkin' then
        -- a nettle's flower strings: thin green tassels hanging out of the leaf's foot, in a pair
        for side = -1, 1, 2 do
            local px, py, pa = x, y, a + side * 0.35
            local n = 8
            local step = o.size / n * (0.4 + 0.6 * open)
            for i = 1, n do
                local d = wrap(DOWN - pa)
                pa = pa + clamp(d, -0.25, 0.25)
                px, py = px + math.cos(pa) * step, py + math.sin(pa) * step
                local h = hash(o.seed * 40 + side, i)
                local c = mix(BUD, cols[1 + math.floor(h * #cols * 0.999)], over)
                dot(px, py, o.size * 0.1 * (1 - i / n * 0.4), c, h)
            end
        end
    elseif st == 'panicle' then
        -- a grass's plume: side branches off the stalk's last stretch, hanging, dotted with spikelets
        -- (dense and feathery for a reed, airy for a bent grass)
        local n = H.branches or 9
        local len = o.size * (0.5 + 0.5 * open)
        local lw = math.max(1, o.size * 0.008)
        G.setLineWidth(lw)
        for i = 1, n do
            local f = (i - 1) / math.max(1, n - 1)
            local h = hash(o.seed * 90, i)
            local bx, by = x + ux * f * len, y + uy * f * len
            local side = (i % 2 == 0) and 1 or -1
            local ba = a + side * (H.spread or 0.5) * (0.6 + 0.6 * h) * (0.4 + 0.6 * open)
            local blen = o.size * (H.reach or 0.4) * (1 - f * 0.65) * (0.7 + 0.5 * h) * (0.5 + 0.5 * open)
            local m = H.spikelets or 5
            local step = blen / m
            local px, py = bx, by
            for j = 1, m do
                local d = wrap(DOWN - ba)
                ba = ba + clamp(d, -(H.droop or 0.15), H.droop or 0.15)
                local qx, qy = px + math.cos(ba) * step, py + math.sin(ba) * step
                local c = mix(BUD, cols[1 + math.floor(hash(h * 10, j) * #cols * 0.999)], clamp(open * 0.8 + over, 0, 1))
                G.setColor(c[1] * 0.7, c[2] * 0.7, c[3] * 0.7, 0.9)
                G.line(px, py, qx, qy)
                dot(qx, qy, o.size * (H.dot or 0.05), c, hash(h, j))
                px, py = qx, qy
            end
        end
        -- the tip of the plume
        local tc = mix(BUD, cols[1], clamp(open + over, 0, 1))
        dot(x + ux * len, y + uy * len, o.size * (H.dot or 0.05) * 1.3, tc, o.seed)
    end
end

---------------------------------------------------------------- a plant

local function leafColor(plant, o)
    local c = plant.colors.leaf
    c = { c[1] + (o.seed - 0.5) * 0.06, c[2] + (o.seed - 0.5) * 0.05, c[3] }
    -- going over: yellow, then brown
    if o.over > 0 then
        c = mix(c, { 0.78, 0.7, 0.3 }, smooth(o.over * 1.6))
        c = mix(c, { 0.55, 0.42, 0.26 }, smooth((o.over - 0.55) / 0.45))
    end
    -- some leaves turn another colour with age (a succulent's outer leaves pink at the tips)
    if o.tint then c = mix(c, o.tint, clamp(o.tintK, 0, 1) * 0.7) end
    if o.back then c = darker(c, 0.82) end
    return c
end

local function drawLeaf(plant, o, opts)
    local x, y = o.x, o.y
    local a = o.a
    G.anchor = { x, y, o.seed * 40, 0.05 }
    if o.petiole and o.petiole > 1 then
        local px, py = x + math.cos(a) * o.petiole, y + math.sin(a) * o.petiole
        local w = math.max(2, o.len * 0.03)
        if opts.outlines ~= false then
            G.setColor(OUTLINE); G.setLineWidth(w + 3); G.line(x, y, px, py)
        end
        G.setColor(plant.colors.stem); G.setLineWidth(w); G.line(x, y, px, py)
        x, y = px, py
    end
    local line = opts.outlines == false and false or OUTLINE
    if o.leaflets then
        -- a clover's: three leaflets fanned out at the stalk's end (the side ones shorter, seen at a slant)
        local len = math.max(o.len * 0.4, (o.len - (o.petiole or 0)) * 0.9)
        local col = leafColor(plant, o)
        for j = -1, 1 do
            if j ~= 0 then
                drawBent(o.shape, x, y, a + j * 1.1, len * 0.85, o.wk, o.droop * 0.5, j, darker(col, 0.92), line)
            end
        end
        drawBent(o.shape, x, y, a, len, o.wk, o.droop * 0.3, o.side, col, line)
    else
        drawBent(o.shape, x, y, a, o.len - (o.petiole or 0) * 0.5, o.wk, o.droop * (1 - 0.6 * (1 - o.flat)),
            o.side, leafColor(plant, o), line, o.lie)
    end
    G.anchor = nil
end

local function drawStems(plant, opts)
    local pic = STROKE.strokes[opts.stroke or 1] and STROKE.strokes[opts.stroke or 1].seamless
    local stemCol = plant.colors.stem
    if plant.over > 0 then stemCol = mix(stemCol, { 0.55, 0.48, 0.32 }, smooth(plant.over * 1.3) * 0.8) end
    for _, st in ipairs(plant.stems) do
        local flat, ws, wo = {}, {}, {}
        for i, p in ipairs(st.pts) do
            flat[i * 2 - 1], flat[i * 2] = p.x, p.y
            ws[i] = math.max(1.5, p.w)
            wo[i] = ws[i] + math.max(2.5, math.min(7, p.w * 0.45))
        end
        if opts.outlines ~= false then drawRibbon(flat, wo, pic, OUTLINE) end
        drawRibbon(flat, ws, pic, stemCol)
    end
    return pic and pic.image
end

local function meshOf(list, texture)
    if #list < 3 then return nil end
    local mesh = love.graphics.newMesh(FORMAT, list, 'triangles', 'static')
    mesh:setTexture(texture)
    return mesh
end

-- the plant drawn once into its three meshes: leaves (and hanging heads) behind the stems, the stems, the
-- leaves in front and the heads on top
local function record(plant, opts)
    local back, stems, front = {}, {}, {}
    G.list = back
    for _, o in ipairs(plant.organs) do
        if o.type == 'leaf' and o.back then drawLeaf(plant, o, opts) end
    end
    for _, o in ipairs(plant.organs) do
        if o.type == 'head' and o.def.pendant and o.z < 0 then drawHead(plant, o, 0, o.x, o.y) end
    end
    G.list = stems
    local strokeImage = drawStems(plant, opts)
    G.list = front
    for _, o in ipairs(plant.organs) do
        if o.type == 'leaf' and not o.back then drawLeaf(plant, o, opts) end
    end
    for _, o in ipairs(plant.organs) do
        if o.type == 'head' and not (o.def.pendant and o.z < 0) then drawHead(plant, o, 0, o.x, o.y) end
    end
    G.list = nil
    return { meshOf(back, ATLAS), strokeImage and meshOf(stems, strokeImage), meshOf(front, ATLAS),
        outlines = opts.outlines ~= false, stroke = opts.stroke }
end

-- (made on its first draw, again if the outlines or its stroke change; a regrown plant is a new plant)
function lib.draw(plant, opts)
    opts = opts or {}
    local c = plant.meshes
    if not c or c.outlines ~= (opts.outlines ~= false) or c.stroke ~= opts.stroke then
        c = record(plant, opts)
        plant.meshes = c
    end
    love.graphics.setShader(swayShader)
    swayShader:send('sway', swayAmount(plant, opts))
    swayShader:send('height', plant.height)
    swayShader:send('footY', plant.y0)
    swayShader:send('time', opts.time or 0)
    swayShader:send('flutter', (opts.sway or 1) * (0.5 + math.abs(opts.wind or 0)))
    love.graphics.setColor(1, 1, 1, 1)
    for k = 1, 3 do
        if c[k] then love.graphics.draw(c[k]) end
    end
    love.graphics.setShader()
end

-- frees a plant's meshes now (a regrow makes new plants; the old ones would wait for the collector)
function lib.release(plant)
    local c = plant.meshes
    if not c then return end
    for k = 1, 3 do if c[k] then c[k]:release() end end
    plant.meshes = nil
end

function lib.reset() end

lib.strokeCount = #STROKE.strokes

return lib

-- beak.lua — a beak in 3D from three pictures, for the beaks spike (docs/BEAKS.md).
-- Each beak (textures/beak/<name>-upper.png, -lower.png, -top.png; claudetools/beak-pictures.py) is two
-- halves: the side pictures give each half's height along its length and its colours, the top picture its
-- width. Each half becomes a shell: a dome outside and a hollow inside (the mouth's colour), in rings
-- along its length. The side picture is laid on the outside as seen from the side (every point takes the
-- picture's pixel where it lies in the side view), so a hand-drawn beak keeps its strokes and grain. The lower half hinges at the corner of the mouth; the upper lifts a
-- little as it opens. Between them, at the hinge, the throat and the mouth's corners: the hole.
-- Drawn after the world (over the Mipo), turned with the head (mipoFacing.angle) and seen a little from
-- above (`view`), so a beak pointing at you still shows: shaded, rings sorted back to front, an outline from
-- a slightly fatter copy drawn first in dark.
local lib = {}

lib.NAMES = { 'duck', 'stork', 'finch', 'parrot', 'toucan' }

-- per beak: length in head widths, droop (rad, the whole beak tipped down), gape (rad, the lower half's
-- swing fully open), lift (share of the gape the upper half swings up), nostril (where along, 0 = none),
-- hollow (how deep the inside of a half is, of its height)
lib.KINDS = {
    duck   = { length = 0.95, droop = 0.10, gape = 0.55, lift = 0.15, nostril = 0.22, hollow = 0.6 },
    stork  = { length = 2.3,  droop = 0.22, gape = 0.35, lift = 0.10, nostril = 0.08, hollow = 0.5 },
    finch  = { length = 0.42, droop = 0.25, gape = 0.65, lift = 0.15, nostril = 0.10, hollow = 0.5 },
    parrot = { length = 0.62, droop = 0.05, gape = 0.55, lift = 0.30, nostril = 0.06, hollow = 0.6 },
    toucan = { length = 1.7,  droop = 0.08, gape = 0.40, lift = 0.10, nostril = 0.05, hollow = 0.5 },
}

local STATIONS = 26 -- rings along a half
local RING = 16      -- points round a ring: the first half outside, the second inside
local OUTLINE = { 0.10, 0.08, 0.07 }
local THROAT = { 0.16, 0.04, 0.06 }
local INSIDE_DEEP, INSIDE = { 0.30, 0.07, 0.09 }, { 0.72, 0.36, 0.38 }
-- the light: from up left, toward the viewer (screen x right, y down, depth toward the viewer)
local LIGHT = { -0.45, -0.7, 0.55 }
do
    local l = math.sqrt(LIGHT[1] ^ 2 + LIGHT[2] ^ 2 + LIGHT[3] ^ 2)
    LIGHT[1], LIGHT[2], LIGHT[3] = LIGHT[1] / l, LIGHT[2] / l, LIGHT[3] / l
end

---------------------------------------------------------------- the pictures

local function opaque(data, x, y) return select(4, data:getPixel(x, y)) > 0.5 end

-- first and last+1 opaque row in a column, or nil
local function columnSpan(data, x)
    local h = data:getHeight()
    local top
    for y = 0, h - 1 do
        if opaque(data, x, y) then top = y; break end
    end
    if not top then return nil end
    for y = h - 1, top, -1 do
        if opaque(data, x, y) then return top, y + 1 end
    end
end

local function sample(data, x, row)
    local r, g, b = data:getPixel(x, math.max(0, math.min(data:getHeight() - 1, math.floor(row))))
    return r, g, b
end

-- one half from its side picture and the top picture: STATIONS + 1 rings' numbers, in beak lengths
local function readHalf(data, topData, isUpper)
    local w, h = data:getDimensions()
    local mid = h / 2
    local spans, last = {}, 0
    for x = 0, w - 1 do
        local t, b = columnSpan(data, x)
        if t then spans[x], last = { t, b }, x end
    end
    local half = { stations = {}, data = data, mid = mid, size = w, upper = isUpper }
    for i = 0, STATIONS do
        local x = math.floor(i / STATIONS * last + 0.5)
        while x > 0 and not spans[x] do x = x - 1 end
        local span = spans[x] or { mid, mid + 1 }
        local wt, wb = columnSpan(topData, math.min(x, topData:getWidth() - 1))
        local st = { f = x / w, top = (span[1] - mid) / w, bottom = (span[2] - mid) / w, col = x,
            half = wt and (wb - wt) / 2 / w or 0.004 }
        -- what of the picture is inside the shell's colour: sampled a little inward from its edge
        st.rimRow = isUpper and span[2] - 1.5 or span[1] + 1.5
        half.stations[i + 1] = st
    end
    local tip = half.stations[#half.stations] -- a point at the very end
    local y = (tip.top + tip.bottom) / 2
    tip.top, tip.bottom, tip.half = y, y, 0
    return half
end

local cache = {}
function lib.load(name)
    if cache[name] then return cache[name] end
    local base = 'textures/beak/' .. name
    local ok, upper, lower, top = pcall(function()
        return love.image.newImageData(base .. '-upper.png'), love.image.newImageData(base .. '-lower.png'),
            love.image.newImageData(base .. '-top.png')
    end)
    if not ok then return nil end
    cache[name] = { upper = readHalf(upper, top, true), lower = readHalf(lower, top, false) }
    return cache[name]
end

function lib.reload() cache = {} end

---------------------------------------------------------------- the shape

-- A ring's point j (0-based) at a station: x across, y down, f along (beak lengths), and whether it is
-- on the inside. The outside: a half ellipse from the rim (the cutting edge) out to the picture's far
-- edge; the inside: a shallower one back from the rim into the shell. `grow` fattens it (the outline).
local function ringPoint(half, st, j, hollow, grow)
    local a = j / RING * math.pi * 2
    local rim = half.upper and st.bottom or st.top
    local height = st.bottom - st.top
    local up = half.upper and -1 or 1 -- the outside's way, from the rim
    local x = math.cos(a) * (st.half + grow)
    if j < RING / 2 then
        return x, rim + up * math.sin(a) * (height + grow), false
    end
    if grow > 0 then return x, rim - up * grow, true end -- the outline closes flat over the hollow
    return x, rim - up * math.abs(math.sin(a)) * height * hollow, true
end

-- the jaw's frame: beak units -> world, and depth toward the viewer
local function frame(view, jaw)
    local fr = {}
    for k, v in pairs(view) do fr[k] = v end
    fr.cj, fr.sj = math.cos(jaw), math.sin(jaw)
    return fr
end

local function project(fr, x, y, f)
    x, y, f = x * fr.L * fr.wMul, y * fr.L * fr.hMul, f * fr.L
    local y1, f1 = y * fr.cj + f * fr.sj, f * fr.cj - y * fr.sj -- the jaw round the hinge
    local X, D = x * fr.cy + f1 * fr.sy, -x * fr.sy + f1 * fr.cy -- the head's turn
    local Y, depth = y1 * fr.cp + D * fr.sp, D * fr.cp - y1 * fr.sp -- seen a little from above
    return fr.rx + X * fr.ch - Y * fr.sh, fr.ry + X * fr.sh + Y * fr.ch, depth
end

local function lerp(a, b, t) return a + (b - a) * t end

---------------------------------------------------------------- drawing

-- quads to draw: { x1,y1,..x4,y4, u1,v1,..u4,v4, depth, r,g,b } in a reused list; u -1 = no picture
local function newList() return { n = 0, items = {} } end

local function addQuad(list, p1, p2, p3, p4, r, g, b, shade, textured)
    list.n = list.n + 1
    local q = list.items[list.n] or {}
    list.items[list.n] = q
    q[1], q[2], q[3], q[4], q[5], q[6], q[7], q[8] = p1[1], p1[2], p2[1], p2[2], p3[1], p3[2], p4[1], p4[2]
    if textured then
        q[9], q[10], q[11], q[12], q[13], q[14], q[15], q[16] = p1[7], p1[8], p2[7], p2[8], p3[7], p3[8], p4[7], p4[8]
    else
        q[9], q[10], q[11], q[12], q[13], q[14], q[15], q[16] = -1, 0, -1, 0, -1, 0, -1, 0
    end
    q.depth = (p1[3] + p2[3] + p3[3] + p4[3]) / 4
    if shade then -- the face's normal, turned toward the viewer, against the light
        local ax, ay, az = p3[1] - p1[1], p3[2] - p1[2], p3[3] - p1[3]
        local bx, by, bz = p4[1] - p2[1], p4[2] - p2[2], p4[3] - p2[3]
        local nx, ny, nz = ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
        local l = math.sqrt(nx * nx + ny * ny + nz * nz)
        if l > 1e-9 then
            if nz < 0 then l = -l end
            local d = (nx * LIGHT[1] + ny * LIGHT[2] + nz * LIGHT[3]) / l
            local s = 0.62 + 0.38 * math.max(0, d) + 0.12 * math.max(0, d) ^ 8 -- and a little shine
            r, g, b = math.min(1, r * s), math.min(1, g * s), math.min(1, b * s)
        end
    end
    q.r, q.g, q.b = r, g, b
end

local function byDepth(a, b) return a.depth < b.depth end

-- the drawn picture where a quad has one, the vertex colour (the shade, or a flat colour) where not
local shader
local function pictureShader()
    shader = shader or love.graphics.newShader([[
        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            if (tc.x < 0.0) return color;
            return vec4(Texel(tex, tc).rgb * color.rgb, color.a);
        }
    ]])
    return shader
end

local meshes = {}
local function flush(list, key, sorted, image)
    if list.n == 0 then return end
    local items = list.items
    if sorted then
        for i = list.n + 1, #items do items[i] = nil end -- table.sort sorts the whole list
        table.sort(items, byDepth)
    end
    local m = meshes[key]
    local need = list.n * 6
    if not m or m.size < need then
        m = { mesh = love.graphics.newMesh(math.max(need, 64), 'triangles', 'stream'), size = math.max(need, 64),
            verts = {} }
        meshes[key] = m
    end
    local verts, k = m.verts, 0
    local order = { 1, 2, 3, 1, 3, 4 }
    for i = 1, list.n do
        local q = items[i]
        for _, c in ipairs(order) do
            k = k + 1
            local v = verts[k] or {}
            verts[k] = v
            v[1], v[2], v[3], v[4] = q[c * 2 - 1], q[c * 2], q[8 + c * 2 - 1], q[8 + c * 2]
            v[5], v[6], v[7], v[8] = q.r, q.g, q.b, 1
        end
    end
    for i = k + 1, #verts do verts[i] = nil end
    m.mesh:setVertices(verts, 1)
    m.mesh:setDrawRange(1, k)
    love.graphics.setColor(1, 1, 1)
    m.mesh:setTexture(image)
    if image then love.graphics.setShader(pictureShader()) end
    love.graphics.draw(m.mesh)
    if image then love.graphics.setShader() end
end

-- where a point at height y lies on the half's side picture (0..1), kept a pixel and a half inside the
-- drawn part so the edge's see-through pixels don't bleed in
local function uvAt(half, st, y)
    local row = half.mid + y * half.size
    local lo, hi = half.mid + st.top * half.size + 1.5, half.mid + st.bottom * half.size - 1.5
    if hi < lo then row = (lo + hi) / 2 else row = math.max(lo, math.min(hi, row)) end
    local w, h = half.data:getDimensions()
    return (st.col + 0.5) / w, row / h
end

-- the rings of one half, projected: rings[i][j+1] = { x, y, depth, inside, bx, by, u, v }
local function rings(half, fr, hollow, grow)
    local out = {}
    for i, st in ipairs(half.stations) do
        local ring = {}
        local f = st.f
        if grow > 0 and i == 1 then f = f - grow end
        if grow > 0 and i == #half.stations then f = f + grow end
        for j = 0, RING - 1 do
            local x, y, inside = ringPoint(half, st, j, hollow, grow)
            local wx, wy, d = project(fr, x, y, f)
            local u, v = uvAt(half, st, y)
            ring[j + 1] = { wx, wy, d, inside, x, y, u, v }
        end
        out[i] = ring
    end
    return out
end

local function colourAt(half, st, y, inside)
    if inside then
        local t = math.min(1, st.f * 2.5)
        return lerp(INSIDE_DEEP[1], INSIDE[1], t), lerp(INSIDE_DEEP[2], INSIDE[2], t),
            lerp(INSIDE_DEEP[3], INSIDE[3], t)
    end
    local row = half.mid + y * half.size
    local lo, hi = half.mid + st.top * half.size + 1, half.mid + st.bottom * half.size - 1
    if hi < lo then row = (lo + hi) / 2 else row = math.max(lo, math.min(hi, row)) end
    return sample(half.data, st.col, row)
end

local function shellQuads(list, half, rs, flat, r0, g0, b0, textured)
    for i = 1, #rs - 1 do
        local a, b = rs[i], rs[i + 1]
        local st = half.stations[i]
        for j = 1, RING do
            local j2 = j % RING + 1
            local r, g, bl = r0, g0, b0
            local inside = a[j][4] and a[j2][4]
            if not flat then
                if textured and not inside then
                    r, g, bl = 1, 1, 1
                else
                    r, g, bl = colourAt(half, st, (a[j][6] + a[j2][6]) / 2, inside)
                end
            end
            addQuad(list, a[j], a[j2], b[j2], b[j], r, g, bl, not flat, textured and not flat and not inside)
        end
    end
    -- the base: a cap over the first ring
    local first = rs[1]
    local cx, cy, cd = 0, 0, 0
    for j = 1, RING do cx, cy, cd = cx + first[j][1], cy + first[j][2], cd + first[j][3] end
    local centre = { cx / RING, cy / RING, cd / RING }
    local r, g, bl = r0, g0, b0
    if not flat then r, g, bl = colourAt(half, half.stations[1], 0, false) end
    for j = 1, RING do
        local j2 = j % RING + 1
        addQuad(list, centre, first[j], first[j2], first[j2], r * 0.8, g * 0.8, bl * 0.8, false)
    end
end

-- the rim of a half at f (beak lengths along): x half width, y the rim
local function rimAt(half, f)
    local sts = half.stations
    for i = 1, #sts - 1 do
        local a, b = sts[i], sts[i + 1]
        if f <= b.f or i == #sts - 1 then
            local t = b.f > a.f and math.max(0, math.min(1, (f - a.f) / (b.f - a.f))) or 0
            local ra = half.upper and a.bottom or a.top
            local rb = half.upper and b.bottom or b.top
            return lerp(a.half, b.half, t), lerp(ra, rb, t)
        end
    end
end

-- the hole: the throat across the back, and the mouth's corners from the hinge a little way along
local function mouthQuads(list, beak, upFr, lowFr)
    local lowEnd, upEnd = beak.lower.stations[#beak.lower.stations], beak.upper.stations[#beak.upper.stations]
    local corner = math.min(lowEnd.f, upEnd.f) * 0.3
    local hu, ru = rimAt(beak.upper, 0)
    local hl, rl = rimAt(beak.lower, 0)
    local w = math.min(hu, hl) * 0.9
    local p1 = { project(upFr, -w, ru, 0) }
    local p2 = { project(upFr, w, ru, 0) }
    local p3 = { project(lowFr, w, rl, 0) }
    local p4 = { project(lowFr, -w, rl, 0) }
    addQuad(list, p1, p2, p3, p4, THROAT[1], THROAT[2], THROAT[3], false)
    list.items[list.n].depth = list.items[list.n].depth - 1e6 -- always at the back
    local steps = 5
    for side = -1, 1, 2 do
        for k = 0, steps - 1 do
            local f1, f2 = corner * k / steps, corner * (k + 1) / steps
            local hu1, ru1 = rimAt(beak.upper, f1)
            local hu2, ru2 = rimAt(beak.upper, f2)
            local hl1, rl1 = rimAt(beak.lower, f1)
            local hl2, rl2 = rimAt(beak.lower, f2)
            local a = { project(upFr, side * hu1, ru1, f1) }
            local b = { project(upFr, side * hu2, ru2, f2) }
            local c = { project(lowFr, side * hl2, rl2, f2) }
            local d = { project(lowFr, side * hl1, rl1, f1) }
            local t = 1 - k / steps
            addQuad(list, a, b, c, d, lerp(INSIDE[1], INSIDE_DEEP[1], t), lerp(INSIDE[2], INSIDE_DEEP[2], t),
                lerp(INSIDE[3], INSIDE_DEEP[3], t), false)
        end
    end
end

local function nostril(beak, fr, kind)
    if not kind.nostril or kind.nostril <= 0 then return end
    local half = beak.upper
    local hw, rim = rimAt(half, kind.nostril)
    local st -- the station nearest
    for _, s in ipairs(half.stations) do
        if not st or math.abs(s.f - kind.nostril) < math.abs(st.f - kind.nostril) then st = s end
    end
    local height = st.bottom - st.top
    love.graphics.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], 0.85)
    for side = -1, 1, 2 do
        local a = math.pi / 2 + side * 0.55
        local x, y = math.cos(a) * hw, rim - math.sin(a) * height * 0.92
        local px, py, pd = project(fr, x, y, kind.nostril)
        local ox, oy = math.cos(a) / math.max(hw, 1e-4), -math.sin(a) / math.max(height, 1e-4) -- outward
        local ol = math.sqrt(ox * ox + oy * oy)
        local _, _, nd = project(fr, x + ox / ol * 0.01, y + oy / ol * 0.01, kind.nostril)
        local facing = (nd - pd) / (0.01 * fr.L)
        if facing > 0.05 then
            local fx, fy = project(fr, x, y, kind.nostril + 0.02)
            local ang = math.atan2(fy - py, fx - px)
            local len = math.max(hw, 0.012) * 0.55 * fr.L
            love.graphics.push()
            love.graphics.translate(px, py)
            love.graphics.rotate(ang)
            love.graphics.ellipse('fill', 0, 0, len, len * 0.35 * math.min(1, facing))
            love.graphics.pop()
        end
    end
end

local lists = {}
local function listFor(key)
    lists[key] = lists[key] or newList()
    lists[key].n = 0
    return lists[key]
end

-- Draw a beak. opts: name, rx, ry (the hinge, world), headAngle, yaw (the head's turn), view (from above,
-- rad), L (length in px), wMul, hMul, open (0..1), outline (px), textured (false: the picture's colours
-- only at the rings' points, as first built), and any of KINDS' fields to override.
function lib.draw(id, opts)
    local beak = lib.load(opts.name)
    if not beak then return end
    local kind = {}
    for k, v in pairs(lib.KINDS[opts.name] or lib.KINDS.duck) do kind[k] = v end
    for _, k in ipairs({ 'droop', 'gape', 'lift', 'hollow' }) do
        if opts[k] then kind[k] = opts[k] end
    end
    local view = { L = opts.L, wMul = opts.wMul or 1, hMul = opts.hMul or 1, rx = opts.rx, ry = opts.ry,
        cy = math.cos(opts.yaw or 0), sy = math.sin(opts.yaw or 0),
        cp = math.cos(opts.view or 0), sp = math.sin(opts.view or 0),
        ch = math.cos(opts.headAngle or 0), sh = math.sin(opts.headAngle or 0) }
    local open = opts.open or 0
    local upFr = frame(view, kind.droop - kind.gape * kind.lift * open)
    local lowFr = frame(view, kind.droop + kind.gape * (1 - kind.lift) * open)
    local textured = opts.textured ~= false
    for _, half in ipairs({ beak.upper, beak.lower }) do
        if textured and not half.image then
            half.image = love.graphics.newImage(half.data)
            half.image:setFilter('linear', 'linear')
        end
    end
    local grow = (opts.outline or 3) / (opts.L * math.max(0.3, math.min(view.wMul, view.hMul)))

    -- the lower half and the hole, then the upper half over them: each its outline, then itself
    local hull = listFor(id .. 'lh')
    shellQuads(hull, beak.lower, rings(beak.lower, lowFr, kind.hollow, grow), true, OUTLINE[1], OUTLINE[2], OUTLINE[3])
    flush(hull, id .. 'lh', false)
    local fill = listFor(id .. 'l')
    if open > 0.01 then mouthQuads(fill, beak, upFr, lowFr) end
    shellQuads(fill, beak.lower, rings(beak.lower, lowFr, kind.hollow, 0), false, nil, nil, nil, textured)
    flush(fill, id .. 'l', true, textured and beak.lower.image or nil)
    hull = listFor(id .. 'uh')
    shellQuads(hull, beak.upper, rings(beak.upper, upFr, kind.hollow, grow), true, OUTLINE[1], OUTLINE[2], OUTLINE[3])
    flush(hull, id .. 'uh', false)
    fill = listFor(id .. 'u')
    shellQuads(fill, beak.upper, rings(beak.upper, upFr, kind.hollow, 0), false, nil, nil, nil, textured)
    flush(fill, id .. 'u', true, textured and beak.upper.image or nil)
    nostril(beak, upFr, kind)
end

return lib

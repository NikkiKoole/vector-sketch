-- drawn-stroke: the drawn outline, shared by the spikes (docs/LANDING-2026-11.md L4; was
-- scripts/spikes/drawn-stroke.lua). require('src.drawn-stroke') -> { strokes, meshes(lines, wobble,
-- step, seamless) }; a scene script calls drawnStroke() for it (src/script.lua). The pictures load on
-- the first require, once for every scene.
-- Nikki's crayon strokes (textures/strokes) as triangle strips along a line, broken at sharp
-- corners (overshooting, tapered), each side one picture repeated mirror-wise (seamless). Copied
-- out of planks.playtime.lua (2026-11-04). Burrow keeps an older copy of its own (canonical(), a
-- picture per marching-squares cell): merging it would change how burrow draws.
-- lines: { { pts = { {x, y}, ... }, loop = bool, width = n, wobble = k }, ... }
local STROKE_FAMILIES = {
    line = { alongX = false, from = 0.1, to = 0.9 },
    track = { alongX = true, from = 0.02, to = 0.98 },
}
-- the part of a picture that's steady along its length (measured: width and place per 5%)
local STEADY = { line1 = { 0.19, 0.83 }, line2 = { 0.08, 0.92 } }
local STROKES = {}
do
    local files = love.filesystem.getDirectoryItems('textures/strokes')
    table.sort(files)
    for _, file in ipairs(files) do
        local family = file:match('^(%a+)%d*%.png$')
        local f = STROKE_FAMILIES[family]
        if f then
            local image = love.graphics.newImage('textures/strokes/' .. file, { mipmaps = true })
            image:setMipmapFilter('linear')
            -- a copy cut to the part that's used (the ends are rough), repeated mirror-wise: each
            -- copy runs into the next as its own reflection, so the edges meet with no step
            -- Along: the steady part (line1 has a step drawn near its ends). Across: tight to the
            -- crayon itself, so every picture draws equally thick (the track lines fill only a
            -- fifth to a third of their pictures' height).
            local data = love.image.newImageData('textures/strokes/' .. file)
            local w, h = data:getDimensions()
            local range = STEADY[file:match('^(.-)%.png$')] or { f.from, f.to }
            local L, T = f.alongX and w or h, f.alongX and h or w
            local a0, a1 = math.floor(L * range[1]), math.floor(L * range[2])
            local lo, hi = T, 0
            for i = a0, a1 - 1, 2 do
                for j = 0, T - 1 do
                    local _, _, _, alpha = data:getPixel(f.alongX and i or j, f.alongX and j or i)
                    if alpha > 0.4 then lo = math.min(lo, j); hi = math.max(hi, j) end
                end
            end
            lo, hi = math.max(0, lo - 2), math.min(T - 1, hi + 2)
            local x0, y0, cw, ch
            if f.alongX then x0, y0, cw, ch = a0, lo, a1 - a0, hi - lo + 1
            else x0, y0, cw, ch = lo, a0, hi - lo + 1, a1 - a0 end
            local cut = love.image.newImageData(cw, ch)
            cut:paste(data, 0, 0, x0, y0, cw, ch)
            local seamless = love.graphics.newImage(cut, { mipmaps = true })
            seamless:setMipmapFilter('linear')
            if f.alongX then
                seamless:setWrap('mirroredrepeat', 'clamp')
            else
                seamless:setWrap('clamp', 'mirroredrepeat')
            end
            STROKES[#STROKES + 1] = { image = image, family = family, alongX = f.alongX, from = f.from, to = f.to,
                seamless = { image = seamless, family = family, alongX = f.alongX, from = 0, to = 1, w = cw, h = ch } }
        end
    end
end
local SPACING = 12            -- world units between the stroke's points
local CORNER = math.rad(55)   -- a sharper turn than this breaks the stroke

local function smooth01(x)
    x = math.max(0, math.min(1, x))
    return x * x * (3 - 2 * x)
end

-- the outline cut at its sharp corners into pieces; flags say which ends are cut (taper there)
local function cornerPieces(pts, loop)
    local n = #pts
    local sharp = {}
    for i = 1, n do
        local a = pts[i - 1] or (loop and pts[n])
        local c = pts[i + 1] or (loop and pts[1])
        if a and c then
            local p = pts[i]
            local t1 = math.atan2(p[2] - a[2], p[1] - a[1])
            local t2 = math.atan2(c[2] - p[2], c[1] - p[1])
            local turn = math.abs((t2 - t1 + math.pi) % (2 * math.pi) - math.pi)
            sharp[i] = turn > CORNER
        end
    end
    local first
    if loop then
        for i = 1, n do if sharp[i] then first = i; break end end
        if not first then
            local closed = {}
            for i = 1, n do closed[i] = pts[i] end
            closed[n + 1] = { pts[1][1], pts[1][2] }
            return { { pts = closed, cutStart = false, cutEnd = false } }
        end
    end
    local pieces = {}
    local count = loop and n or n - 1
    local startI = loop and first or 1
    local cur = { pts = { pts[startI] }, cutStart = true }
    for step = 1, count do
        local i = (startI - 1 + step) % n + 1
        cur.pts[#cur.pts + 1] = pts[i]
        if sharp[i] and step ~= count then
            cur.cutEnd = true
            pieces[#pieces + 1] = cur
            cur = { pts = { pts[i] }, cutStart = true }
        end
    end
    cur.cutEnd = true
    pieces[#pieces + 1] = cur
    return pieces
end

-- points every SPACING along a piece, its cut ends run on a little past the corner
local function penLine(piece, over)
    local src = piece.pts
    local out = {}
    for i = 1, #src - 1 do
        local a, c = src[i], src[i + 1]
        local len = math.sqrt((c[1] - a[1]) ^ 2 + (c[2] - a[2]) ^ 2)
        local k = math.max(1, math.ceil(len / SPACING))
        for j = 0, k - 1 do
            local t = j / k
            out[#out + 1] = { a[1] + (c[1] - a[1]) * t, a[2] + (c[2] - a[2]) * t }
        end
    end
    out[#out + 1] = src[#src]
    local function extend(p, q)
        local dx, dy = p[1] - q[1], p[2] - q[2]
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 1e-6 then return nil end
        return { p[1] + dx / len * over, p[2] + dy / len * over }
    end
    if piece.cutStart and #out >= 2 then
        local e = extend(out[1], out[2])
        if e then table.insert(out, 1, e) end
    end
    if piece.cutEnd and #out >= 2 then
        local e = extend(out[#out], out[#out - 1])
        if e then out[#out + 1] = e end
    end
    return out
end

local function hash3(a, b, c)
    local h = math.sin(a * 127.1 + b * 311.7 + c * 74.7) * 43758.5453
    return h - math.floor(h)
end

-- one piece as a strip of triangles, the stroke pictures repeating along it, into byPicture.
-- The noise and the picture choice read the point's place, so a plank's own seed (an offset
-- added to its points) makes each plank's line its own.
local function strokePiece(piece, width, wobble, step, byPicture, seamless)
    local halfW = width / 2
    local path = penLine(piece, halfW * 1.2)
    if #path < 2 then return end
    local seed = 3.7 + step * 7.3
    local dist, total = { 0 }, 0
    for i = 2, #path do
        local a, c = path[i - 1], path[i]
        total = total + math.sqrt((c[1] - a[1]) ^ 2 + (c[2] - a[2]) ^ 2)
        dist[i] = total
    end
    local taper = math.min(halfW * 4, total * 0.3)
    local amt = wobble * halfW / 9
    local f1, f2 = 0.012 * 9 / halfW, 0.05 * 9 / halfW
    local centre, widths = {}, {}
    for i, p in ipairs(path) do
        local a = path[math.max(1, i - 1)]
        local c = path[math.min(#path, i + 1)]
        local dx, dy = c[1] - a[1], c[2] - a[2]
        local len = math.sqrt(dx * dx + dy * dy)
        local nx, ny = 0, 0
        if len > 0 then nx, ny = -dy / len, dx / len end
        local wob = (love.math.noise(seed, p[1] * f1, p[2] * f1) - 0.5) * 2 * amt * 4
            + (love.math.noise(seed + 50, p[1] * f2, p[2] * f2) - 0.5) * amt
        centre[i] = { p[1] + nx * wob, p[2] + ny * wob }
        local w = halfW * (0.8 + love.math.noise(seed + 100, p[1] * 0.004, p[2] * 0.004) * 0.4)
        if piece.cutStart then w = w * (0.25 + 0.75 * smooth01(dist[i] / taper)) end
        if piece.cutEnd then w = w * (0.25 + 0.75 * smooth01((total - dist[i]) / taper)) end
        widths[i] = w
    end
    local function sides(i)
        local a = centre[math.max(1, i - 1)]
        local c = centre[math.min(#centre, i + 1)]
        local dx, dy = c[1] - a[1], c[2] - a[2]
        local len = math.sqrt(dx * dx + dy * dy)
        if len == 0 then len = 1 end
        local nx, ny = -dy / len, dx / len
        local p, w = centre[i], widths[i]
        return p[1] + nx * w, p[2] + ny * w, p[1] - nx * w, p[2] - ny * w
    end
    local tile
    local function nextTile(at, k)
        local p = path[1]
        local h1, h2, h3 = hash3(p[1], p[2], k + step * 17), hash3(p[2], p[1], k * 3 + 1), hash3(p[1] + k, p[2] - k, 7)
        local pic = STROKES[math.min(#STROKES, 1 + math.floor(h1 * #STROKES))]
        local iw, ih = pic.image:getDimensions()
        local thick = pic.alongX and ih or iw
        local long = pic.alongX and iw or ih
        tile = { pic = pic, start = at, length = long * (pic.to - pic.from) * (halfW * 2 / thick),
            mirror = h2 < 0.5, backwards = h3 < 0.5, k = k }
    end
    local function vertex(x, y, across, d)
        local along = (d - tile.start) / tile.length
        if tile.mirror then across = 1 - across end
        if tile.backwards then along = 1 - along end
        local p = tile.pic
        along = p.from + (p.to - p.from) * along
        if p.alongX then return { x, y, along, across } end
        return { x, y, across, along }
    end
    local function quad(ax, ay, bx, by, d0, cx, cy, dx, dy, d1)
        local verts = byPicture[tile.pic]
        if not verts then verts = {}; byPicture[tile.pic] = verts end
        local q1, q2 = vertex(ax, ay, 0, d0), vertex(bx, by, 1, d0)
        local q3, q4 = vertex(cx, cy, 0, d1), vertex(dx, dy, 1, d1)
        verts[#verts + 1] = q1; verts[#verts + 1] = q2; verts[#verts + 1] = q3
        verts[#verts + 1] = q2; verts[#verts + 1] = q4; verts[#verts + 1] = q3
    end
    if seamless then
        -- one picture for the whole piece, its length running on along the line (mirrored repeat)
        local p0 = path[1]
        local h1, h2, h3 = hash3(p0[1], p0[2], step * 17), hash3(p0[2], p0[1], 1), hash3(p0[1] + 3, p0[2] - 3, 7)
        local pic = STROKES[math.min(#STROKES, 1 + math.floor(h1 * #STROKES))].seamless
        local thick = pic.alongX and pic.h or pic.w
        local long = pic.alongX and pic.w or pic.h
        local length = long * (halfW * 2 / thick)
        local mirror, offset = h2 < 0.5, h3 * 2
        local verts = byPicture[pic]
        if not verts then verts = {}; byPicture[pic] = verts end
        local function seamlessVertex(x, y, across, d)
            if mirror then across = 1 - across end
            local along = offset + d / length
            if pic.alongX then return { x, y, along, across } end
            return { x, y, across, along }
        end
        for i = 2, #centre do
            local ax, ay, bx, by = sides(i - 1)
            local cx, cy, dx, dy = sides(i)
            local q1, q2 = seamlessVertex(ax, ay, 0, dist[i - 1]), seamlessVertex(bx, by, 1, dist[i - 1])
            local q3, q4 = seamlessVertex(cx, cy, 0, dist[i]), seamlessVertex(dx, dy, 1, dist[i])
            verts[#verts + 1] = q1; verts[#verts + 1] = q2; verts[#verts + 1] = q3
            verts[#verts + 1] = q2; verts[#verts + 1] = q4; verts[#verts + 1] = q3
        end
        return
    end
    nextTile(0, 0)
    for i = 2, #centre do
        local d0, d1 = dist[i - 1], dist[i]
        local ax, ay, bx, by = sides(i - 1)
        local cx, cy, dx, dy = sides(i)
        while d1 > tile.start + tile.length and d1 > d0 do
            local dm = tile.start + tile.length
            local t = (dm - d0) / (d1 - d0)
            local mx1, my1 = ax + (cx - ax) * t, ay + (cy - ay) * t
            local mx2, my2 = bx + (dx - bx) * t, by + (dy - by) * t
            quad(ax, ay, bx, by, d0, mx1, my1, mx2, my2, dm)
            nextTile(dm, tile.k + 1)
            ax, ay, bx, by, d0 = mx1, my1, mx2, my2, dm
        end
        quad(ax, ay, bx, by, d0, cx, cy, dx, dy, d1)
    end
end

-- a list of lines ({ pts, loop, width }) as meshes, one per stroke picture
local function strokeMeshes(lines, wobble, step, seamless)
    local byPicture = {}
    for _, line in ipairs(lines) do
        for _, piece in ipairs(cornerPieces(line.pts, line.loop)) do
            strokePiece(piece, line.width, wobble * (line.wobble or 1), step, byPicture, seamless)
        end
    end
    local meshes = {}
    for pic, verts in pairs(byPicture) do
        if #verts >= 3 then
            local mesh = love.graphics.newMesh(verts, 'triangles', 'static')
            mesh:setTexture(pic.image)
            meshes[#meshes + 1] = mesh
        end
    end
    return meshes
end

return { strokes = STROKES, meshes = strokeMeshes }

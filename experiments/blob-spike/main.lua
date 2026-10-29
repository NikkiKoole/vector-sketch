-- Blob spike (docs/BLOBS.md step 1): a soft body in the shape of a Mipo head/body outline,
-- wearing that part's baked OMP texture, squashing with it.
--
-- The answers this is for: does the picture look right while it squashes, and do the
-- non-round head shapes hold their form with spokes alone?
--
-- How it differs from experiments/loveblobs2 (whose texture looked wrong):
--   * every rim point gets its UV once, from its rest spot on the outline, so the picture
--     moves with the rim instead of being re-projected from a fixed frame each frame;
--   * a fan with a centre vertex, so dented shapes don't fold over;
--   * one mesh per blob, only the vertex positions change per frame.
--
-- Uses Playtime's own bake (src/ is a symlink) and real Mipo parts from the dollhouse.
--
--   left drag  grab a blob (a rim point squashes it, the middle carries it)
--   right      drop a new blob (next texture)
--   n          next texture for the last-touched blob
--   [ ]        spokes softer / stiffer      ; '        rim links rigid / springy
--   k          kick everything up            d          debug (nodes, triangles)
--   s          smooth edge on/off            x          clear blobs
--   m          mesh: mvc / fan               b          bend springs (0, 3, 6 .. 24 Hz)
--   esc        quit

-- --check: simulate drop, kick and settle without a window loop, print shape stats, quit
local CHECK = false
local BEND_ARG, DRAW_SMOOTH_ARG
local PRESSURE_ARG, HZ_ARG, FAN_ARG, NO_SMOOTH_ARG, NO_OFFSET_ARG
for _, a in ipairs(arg or {}) do
    local pv = tonumber(a:match('^%-%-pressure=([%d.]+)$') or '')
    if pv then PRESSURE_ARG = pv end
    local hv = tonumber(a:match('^%-%-hz=([%d.]+)$') or '')
    if hv then HZ_ARG = hv end
    if a == '--fan' then FAN_ARG = true end
    local dv = tonumber(a:match('^%-%-draw%-smooth=(%d+)$') or '')
    if dv then DRAW_SMOOTH_ARG = dv end
    local bv = tonumber(a:match('^%-%-bend=([%d.]+)$') or '')
    if bv then BEND_ARG = bv end
    if a == '--no-smooth' then NO_SMOOTH_ARG = true end
    if a == '--no-offset' then NO_OFFSET_ARG = true end
    if a == '--check' then
        CHECK = true
        love.errorhandler = function(msg)
            print(debug.traceback('Error: ' .. tostring(msg), 3))
        end
    end
end

local textured = require('src.physics.box2d-draw-textured')
local json = require('vendor.dkjson')

local SCENE = 'scripts/dollhouse.playtime.json'
local METER = 100 -- same as Playtime (state.world.meter)
local GRAVITY = 9.8
local BLOB_HEIGHT = 240 -- on-screen height of a new blob, px
local NODES = 28 -- rim points per blob

-- Head/body outlines, from character-manager.lua shape8Dict: texture-space points,
-- centred on the texture, over `dimensions` (which is not always the png's own size).
local SHAPES = {
    ['shapeA1.png'] = { dimensions = { 339, 560 },
        vertices = { 1, -272, 112, -133, 154, 76, 123, 229, 1, 273, -134, 225, -145, 73, -91, -132 } },
    ['shapeA2.png'] = { dimensions = { 289, 468 },
        vertices = { 11, -224, 60, -144, 59, -20, 133, 135, 4, 224, -133, 131, -51, -20, -39, -147, } },
    ['shapeA3.png'] = { dimensions = { 370, 422 },
        vertices = { -6, -189, 135, -69, 160, 45, 123, 154, -6, 189, -92, 153, -164, 53, -155, -67 } },
    ['shapeA4.png'] = { dimensions = { 308, 414 },
        vertices = { 7, -194, 133, -56, 126, 45, 101, 190, -6, 195, -129, 185, -134, 40, -110, -66 } },
    ['shapes1.png'] = { dimensions = { 296, 495 },
        vertices = { 10, -244, 133, -56, 135, 48, 124, 221, -0, 231, -128, 215, -138, 41, -134, -62 } },
    ['shapes2.png'] = { dimensions = { 252, 461 },
        vertices = { -3, -223, 74, -78, 89, 51, 104, 196, -0, 231, -92, 202, -94, 54, -61, -80 } },
    ['shapes3.png'] = { dimensions = { 324, 442 },
        vertices = { -3, -206, 132, -137, 148, 12, 110, 186, -6, 216, -97, 192, -149, 7, -141, -141 } },
    ['shapes4.png'] = { dimensions = { 364, 266 },
        vertices = { 0, -123, 164, -98, 148, 12, 157, 112, -1, 117, -149, 105, -149, 7, -168, -87 } },
    ['shapes5.png'] = { dimensions = { 194, 338 },
        vertices = { 0, -162, 74, -132, 78, -4, 73, 148, -2, 156, -81, 142, -84, 1, -87, -126, } },
    ['shapes6.png'] = { dimensions = { 250, 384 },
        vertices = { 3, -178, 77, -118, 92, -0, 93, 143, -2, 160, -85, 141, -92, 0, -67, -119 } },
    ['shapes7.png'] = { dimensions = { 722, 929 },
        vertices = { -3, -452, 127, -245, 305, 19, 247, 384, -2, 451, -276, 378, -283, 15, -207, -238 } },
    ['shapes8.png'] = { dimensions = { 788, 708 },
        vertices = { 3, -154, 271, -307, 341, 26, 89, 298, -9, 332, -166, 299, -302, 34, -238, -319 } },
    ['shapes9.png'] = { dimensions = { 520, 468 },
        vertices = { -0, -236, 233, -191, 198, 24, 174, 206, -18, 216, -226, 205, -233, 19, -234, -198 } },
    ['shapes10.png'] = { dimensions = { 520, 856 },
        vertices = { 4, -407, 166, -232, 231, 24, 141, 344, -16, 418, -186, 332, -233, 19, -182, -233 } },
    ['shapes11.png'] = { dimensions = { 652, 932 },
        vertices = { 4, -451, 110, -405, 195, 6, 306, 408, 13, 436, -277, 417, -205, -3, -114, -417 } },
    ['shapes12.png'] = { dimensions = { 558, 323 },
        vertices = { 17, -129, 208, -76, 249, 11, 191, 109, 9, 142, -228, 103, -247, -1, -175, -91 } },
    ['shapes13.png'] = { dimensions = { 486, 556 },
        vertices = { 22, -239, 175, -101, 197, 11, 177, 219, 14, 260, -168, 210, -156, 12, -125, -105 } },
}

local world
local blobs = {}
local looks = {} -- { extra, image } per dollhouse head/body part
local lookIndex = 0
local mouseJoint
local lastBlob
local settings = { spokeHz = 4, spokeDamping = 0.5, rimRigid = true, smooth = true, debug = false,
    pressure = 1, offset = 1, meshMode = 'mvc', bend = 3, drawSmooth = 4 }
local STEP = 1 / 120 -- fixed physics step; pressure is re-applied before every step
local blobCount = 0

---------------------------------------------------------------- baking (as omp-bench / makeCombinedImages)

local sourceCache = {}
local function getSource(path)
    if sourceCache[path] == nil then
        local info = love.filesystem.getInfo(path)
        sourceCache[path] = (info and info.type == 'file') and love.graphics.newImage(path) or false
    end
    return sourceCache[path] or nil
end

local tex1

local function bakePatch(p)
    if not (p and p.bgURL) then return nil end
    local outline = getSource('textures/' .. p.bgURL)
    if not outline then return nil end
    local olr, olg, olb, ola = textured.hexToColor(p.bgHex)
    local mr, mg, mb, ma = textured.hexToColor(p.fgHex)
    local pr, pg, pb, pa = textured.hexToColor(p.pHex)
    local imgData = textured.makeTexturedCanvas(
        outline, getSource('textures/' .. (p.fgURL or '')),
        { mr, mg, mb }, ma * 5,
        getSource('textures/pat/' .. (p.pURL or '')) or tex1, { pr, pg, pb }, pa * 5,
        p.pr or 0, p.psx or 1, p.psy or 1, p.ptx or 0, p.pty or 0,
        { olr, olg, olb }, ola * 5, p.fx or 1, p.fy or 1)
    local img = love.graphics.newImage(imgData)
    imgData:release()
    return { img = img, tint = p.tint or 'ffffff', tx = p.tx, ty = p.ty, sx = p.sx, sy = p.sy, r = p.r }
end

local function bake(extra)
    local main = extra.main
    if not main.cached then textured.makeCached(main) end
    local c = main.cached
    local patches = {}
    for i, name in ipairs({ 'patch1', 'patch2', 'patch3' }) do
        patches[i] = bakePatch(extra[name]) or false
    end
    local hasFg = main.fgURL and main.fgURL ~= ''
    local imgData = textured.makeTexturedCanvas(
        getSource('textures/' .. main.bgURL),
        hasFg and getSource('textures/' .. main.fgURL) or nil,
        c.fgRGB, c.fgA * 5,
        getSource('textures/pat/' .. (main.pURL or '')) or tex1, c.pRGB, c.pA * 5,
        main.pr or 0, main.psx or 1, main.psy or 1, main.ptx or 0, main.pty or 0,
        c.bgRGB, c.bgA * 5, main.fx or 1, main.fy or 1, patches)
    local img = love.graphics.newImage(imgData)
    imgData:release()
    for _, patch in ipairs(patches) do
        if patch then patch.img:release() end
    end
    return img
end

-- every head/body part in the dollhouse whose outline we know
local function loadLooks()
    local contents = love.filesystem.read(SCENE)
    local data = json.decode(contents, 1, nil)
    local seen = {}
    for _, body in ipairs(data.bodies) do
        for _, fixture in ipairs(body.fixtures or {}) do
            local extra = fixture.userData and fixture.userData.extra
            local url = extra and extra.OMP and extra.main and extra.main.bgURL
            if url and SHAPES[url] then
                local key = url .. (extra.main.fgHex or '') .. (extra.main.pURL or '')
                if not seen[key] then
                    seen[key] = true
                    looks[#looks + 1] = { extra = extra, url = url }
                end
            end
        end
    end
end

local function getLook(i)
    local look = looks[i]
    if not look.image then look.image = bake(look.extra) end
    return look
end

---------------------------------------------------------------- outline -> rim

local function catmull(p0, p1, p2, p3, t)
    local t2, t3 = t * t, t * t * t
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

-- closed Catmull-Rom through the 8 points, then N points evenly spaced along it
local function resampleOutline(flat, n)
    local pts = {}
    for i = 1, #flat, 2 do pts[#pts + 1] = { flat[i], flat[i + 1] } end
    local m = #pts
    local dense = {}
    local STEPS = 24
    for i = 1, m do
        local p0, p1 = pts[(i - 2) % m + 1], pts[i]
        local p2, p3 = pts[i % m + 1], pts[(i + 1) % m + 1]
        for s = 0, STEPS - 1 do
            local t = s / STEPS
            dense[#dense + 1] = { catmull(p0[1], p1[1], p2[1], p3[1], t), catmull(p0[2], p1[2], p2[2], p3[2], t) }
        end
    end
    local lengths, total = { 0 }, 0
    for i = 1, #dense do
        local a, b = dense[i], dense[i % #dense + 1]
        total = total + math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
        lengths[i + 1] = total
    end
    local out, j = {}, 1
    for k = 0, n - 1 do
        local target = total * k / n
        while lengths[j + 1] < target do j = j + 1 end
        local a, b = dense[j], dense[j % #dense + 1]
        local t = (target - lengths[j]) / math.max(lengths[j + 1] - lengths[j], 1e-6)
        out[#out + 1] = { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t }
    end
    return out, total
end

-- outward unit normal at point i of a closed loop of {x, y} (or of a flat getter)
local function outwardNormal(px, py, ax, ay, bx, by, cx, cy)
    local tx, ty = bx - ax, by - ay
    local len = math.sqrt(tx * tx + ty * ty)
    if len < 1e-6 then return 0, 0 end
    local nx, ny = ty / len, -tx / len
    if nx * (px - cx) + ny * (py - cy) < 0 then nx, ny = -nx, -ny end
    return nx, ny
end

---------------------------------------------------------------- blobs

local buildMesh -- below, after the rim helpers

local function setJointSettings(blob)
    for _, j in ipairs(blob.spokes) do
        j:setFrequency(settings.spokeHz)
        j:setDampingRatio(settings.spokeDamping)
    end
    for _, j in ipairs(blob.links) do
        j:setFrequency(settings.rimRigid and 0 or settings.spokeHz * 2)
        j:setDampingRatio(0.5)
    end
    for _, j in ipairs(blob.bends or {}) do
        j:setFrequency(settings.bend)
        j:setDampingRatio(0.7)
    end
end

local function makeBlob(x, y, lookIdx)
    blobCount = blobCount + 1
    local look = getLook(lookIdx)
    local shape = SHAPES[look.url]
    local dw, dh = shape.dimensions[1], shape.dimensions[2]
    local scale = BLOB_HEIGHT / dh

    local outline, perimeter = resampleOutline(shape.vertices, NODES)
    local cxs, cys = 0, 0 -- texture-space middle of the rim
    for _, p in ipairs(outline) do cxs, cys = cxs + p[1], cys + p[2] end
    cxs, cys = cxs / #outline, cys / #outline

    local r = perimeter * scale / NODES * 0.5 -- neighbours just touch
    local group = -blobCount                  -- a blob's own parts don't collide

    local blob = { look = lookIdx, nodes = {}, uvs = {}, spokes = {}, links = {}, r = r }
    blob.centre = love.physics.newBody(world, x, y, 'dynamic')
    local cf = love.physics.newFixture(blob.centre, love.physics.newCircleShape(r * 2), 2)
    cf:setSensor(true)
    cf:setGroupIndex(group)
    cf:setUserData({ blob = blob })
    blob.centre:setAngularDamping(5)
    blob.centreUV = { cxs / dw + 0.5, cys / dh + 0.5 }

    local nodeShape = love.physics.newCircleShape(r)
    for i, p in ipairs(outline) do
        local a, b = outline[(i - 2) % #outline + 1], outline[i % #outline + 1]
        local nx, ny = outwardNormal(p[1], p[2], a[1], a[2], b[1], b[2], cxs, cys)
        -- inset by r, so the circles' outer edge lies on the outline
        local lx, ly = (p[1] - cxs) * scale - nx * r, (p[2] - cys) * scale - ny * r
        local body = love.physics.newBody(world, x + lx, y + ly, 'dynamic')
        local f = love.physics.newFixture(body, nodeShape, 1)
        f:setFriction(0.7)
        f:setRestitution(0.05)
        f:setGroupIndex(group)
        f:setUserData({ blob = blob })
        body:setFixedRotation(true)
        blob.nodes[i] = body
        blob.uvs[i] = { p[1] / dw + 0.5, p[2] / dh + 0.5 }
        blob.spokes[i] = love.physics.newDistanceJoint(blob.centre, body, x, y, x + lx, y + ly, false)
    end
    for i = 1, #blob.nodes do
        local a, b = blob.nodes[i], blob.nodes[i % #blob.nodes + 1]
        local ax, ay = a:getPosition()
        local bx, by = b:getPosition()
        blob.links[i] = love.physics.newDistanceJoint(a, b, ax, ay, bx, by, false)
    end
    -- bend springs: each rim point to the one two along, so the rim curves but can't kink
    -- into a zigzag when squashed (a zigzag rim folds the triangles at the edge)
    blob.bends = {}
    if settings.bend > 0 then
        for i = 1, #blob.nodes do
            local a, b = blob.nodes[i], blob.nodes[(i + 1) % #blob.nodes + 1]
            local ax, ay = a:getPosition()
            local bx, by = b:getPosition()
            blob.bends[i] = love.physics.newDistanceJoint(a, b, ax, ay, bx, by, false)
        end
    end
    setJointSettings(blob)
    blob.rest = {}
    for i, body in ipairs(blob.nodes) do
        local bx, by = body:getPosition()
        blob.rest[i] = { bx - x, by - y }
    end
    local signed = 0
    for i = 1, #blob.rest do
        local p, q = blob.rest[i], blob.rest[i % #blob.rest + 1]
        signed = signed + p[1] * q[2] - q[1] * p[2]
    end
    blob.restArea = signed / 2 -- signed: its sign is the winding
    local mass = blob.centre:getMass()
    for _, b in ipairs(blob.nodes) do mass = mass + b:getMass() end
    -- pressure 1: at 10% less area the push on the whole rim is ~3x the blob's weight
    blob.pressureK = 30 * mass * GRAVITY * METER / (perimeter * scale)

    blob.smooth = settings.smooth
    blob.meshMode = settings.meshMode
    buildMesh(blob, look.image)

    blobs[#blobs + 1] = blob
    lastBlob = blob
    return blob
end

local function destroyBlob(blob)
    for _, b in ipairs(blob.nodes) do b:destroy() end
    blob.centre:destroy()
    blob.mesh:release()
end

local function rebuildBlob(blob, lookIdx)
    local x, y = blob.centre:getPosition()
    destroyBlob(blob)
    for i, b in ipairs(blobs) do
        if b == blob then table.remove(blobs, i) break end
    end
    return makeBlob(x, y, lookIdx or blob.look)
end

-- The drawn rim: each rim body pushed out by r along the normal (so the circles' outer edge
-- is the picture's edge), with Catmull-Rom midpoints when smoothing. UVs are fixed per point.
local function computeRim(blob)
    local nodes, n = blob.nodes, #blob.nodes
    local w = blob.restArea > 0 and 1 or -1
    local rim = blob.rim
    -- node positions, Taubin-smoothed for drawing only: the physics rim kinks where a floor
    -- or another blob presses one point in, and a kinked rim folds the triangles at the edge.
    -- A shrink pass (lambda) then an inflate pass (mu) irons out kinks without shrinking.
    local xs, ys = blob._xs or {}, blob._ys or {}
    blob._xs, blob._ys = xs, ys
    for i = 1, n do xs[i], ys[i] = nodes[i]:getPosition() end
    local tx, ty = blob._tx or {}, blob._ty or {}
    blob._tx, blob._ty = tx, ty
    for _ = 1, settings.drawSmooth do
        for _, f in ipairs({ 0.5, -0.53 }) do
            for i = 1, n do
                local a, b = (i - 2) % n + 1, i % n + 1
                tx[i] = xs[i] + f * ((xs[a] + xs[b]) / 2 - xs[i])
                ty[i] = ys[i] + f * ((ys[a] + ys[b]) / 2 - ys[i])
            end
            for i = 1, n do xs[i], ys[i] = tx[i], ty[i] end
        end
    end
    for i = 1, n do
        local px, py = xs[i], ys[i]
        local ax, ay = xs[(i - 2) % n + 1], ys[(i - 2) % n + 1]
        local bx, by = xs[i % n + 1], ys[i % n + 1]
        -- outward from the winding, the same way every frame ("away from the middle" flipped
        -- sign in dents and made rim vertices jump in and out)
        local ex, ey = bx - ax, by - ay
        local len = math.sqrt(ex * ex + ey * ey)
        if len < 1e-6 then len = 1 end
        local nx, ny = ey / len * w, -ex / len * w
        local rv = rim[i] or {}
        if rv.nx and nx * rv.nx + ny * rv.ny < 0 then blob.normalFlips = (blob.normalFlips or 0) + 1 end
        rv.nx, rv.ny = nx, ny
        rv[1], rv[2] = px + nx * blob.r * settings.offset, py + ny * blob.r * settings.offset
        rv[3], rv[4] = blob.uvs[i][1], blob.uvs[i][2]
        rim[i] = rv
    end
    local out = blob.rimVerts
    local k = 1
    for i = 1, n do
        local p1, p2 = rim[i], rim[i % n + 1]
        local v = out[k] or {}
        v[1], v[2], v[3], v[4] = p1[1], p1[2], p1[3], p1[4]
        out[k] = v
        k = k + 1
        if blob.smooth then
            local p0, p3 = rim[(i - 2) % n + 1], rim[(i + 1) % n + 1]
            v = out[k] or {}
            for c = 1, 4 do v[c] = catmull(p0[c], p1[c], p2[c], p3[c], 0.5) end
            out[k] = v
            k = k + 1
        end
    end
    return out
end

-- Mean value coordinates of point (px, py) in a polygon: weights that rebuild the point from
-- the polygon's corners, smooth inside, also for dented (non-convex) shapes.
local function mvcWeights(px, py, poly)
    local m = #poly
    local dist, angle, weights, sum = {}, {}, {}, 0
    for i = 1, m do
        local dx, dy = poly[i][1] - px, poly[i][2] - py
        dist[i] = math.max(math.sqrt(dx * dx + dy * dy), 1e-6)
    end
    for i = 1, m do
        local j = i % m + 1
        local ax, ay = poly[i][1] - px, poly[i][2] - py
        local bx, by = poly[j][1] - px, poly[j][2] - py
        angle[i] = math.atan2(ax * by - ay * bx, ax * bx + ay * by)
    end
    for i = 1, m do
        local prev = (i - 2) % m + 1
        weights[i] = (math.tan(angle[prev] / 2) + math.tan(angle[i] / 2)) / dist[i]
        sum = sum + weights[i]
    end
    for i = 1, m do weights[i] = weights[i] / sum end
    return weights
end

local RINGS = 3 -- inner rings between the middle and the rim ('mvc' mesh)

-- 'fan': the middle vertex at the rim's mean, triangles fanned out to the rim. Folds when a
-- squash bends the rim so part of it is hidden from the middle (flickering triangles).
-- 'mvc': triangles fixed at rest (middle, RINGS inner rings, rim); every frame the inner
-- vertices are rebuilt from the rim with mean value coordinates taken at rest, so the inside
-- bends with the rim instead of pivoting around one point.
buildMesh = function(blob, image)
    blob.rim, blob.rimVerts = {}, {}
    local rest = computeRim(blob)
    local m = #rest
    local cx, cy, cu, cv = 0, 0, 0, 0
    for _, r in ipairs(rest) do cx, cy, cu, cv = cx + r[1], cy + r[2], cu + r[3], cv + r[4] end
    cx, cy, cu, cv = cx / m, cy / m, cu / m, cv / m

    local verts = {}
    for i = 1, m do verts[i] = { rest[i][1], rest[i][2], rest[i][3], rest[i][4], 1, 1, 1, 1 } end
    blob.inner = {}
    local map, w = {}, blob.restArea > 0 and 1 or -1
    if blob.meshMode == 'fan' then
        verts[m + 1] = { cx, cy, cu, cv, 1, 1, 1, 1 }
        for i = 1, m do
            local j = i % m + 1
            map[#map + 1], map[#map + 2], map[#map + 3] = m + 1, i, j
        end
    else
        local restPoly = {}
        for i = 1, m do restPoly[i] = { rest[i][1], rest[i][2] } end
        local function addInner(t, i)
            local r = rest[i or 1]
            local x, y = cx + (r[1] - cx) * t, cy + (r[2] - cy) * t
            local u, v = cu + (r[3] - cu) * t, cv + (r[4] - cv) * t
            verts[#verts + 1] = { x, y, u, v, 1, 1, 1, 1 }
            blob.inner[#blob.inner + 1] = { index = #verts, weights = mvcWeights(x, y, restPoly) }
            return #verts
        end
        local centre = addInner(0)
        local rings = {}
        for k = 1, RINGS do
            rings[k] = {}
            for i = 1, m do rings[k][i] = addInner(k / (RINGS + 1), i) end
        end
        local rimRing = {}
        for i = 1, m do rimRing[i] = i end
        rings[RINGS + 1] = rimRing
        local function tri(a, b, c) map[#map + 1], map[#map + 2], map[#map + 3] = a, b, c end
        for i = 1, m do tri(centre, rings[1][i], rings[1][i % m + 1]) end
        for k = 1, RINGS do
            local a, b = rings[k], rings[k + 1]
            for i = 1, m do
                local j = i % m + 1
                tri(a[i], b[i], b[j])
                tri(a[i], b[j], a[j])
            end
        end
    end
    blob.verts, blob.map, blob.winding = verts, map, w
    blob.mesh = love.graphics.newMesh(verts, 'triangles', 'stream')
    blob.mesh:setVertexMap(map)
    blob.mesh:setTexture(image)
end

local function updateMesh(blob)
    local rimVerts = computeRim(blob)
    local verts, m = blob.verts, #rimVerts
    for i = 1, m do
        verts[i][1], verts[i][2] = rimVerts[i][1], rimVerts[i][2]
    end
    if blob.meshMode == 'fan' then
        local cx, cy = 0, 0
        for i = 1, m do cx, cy = cx + rimVerts[i][1], cy + rimVerts[i][2] end
        verts[m + 1][1], verts[m + 1][2] = cx / m, cy / m
    else
        for _, inner in ipairs(blob.inner) do
            local x, y, ws = 0, 0, inner.weights
            for i = 1, m do
                x, y = x + ws[i] * rimVerts[i][1], y + ws[i] * rimVerts[i][2]
            end
            verts[inner.index][1], verts[inner.index][2] = x, y
        end
    end

    -- folded triangles: wound the other way than at rest
    local folded, map, w = 0, blob.map, blob.winding
    for t = 1, #map, 3 do
        local a, b, c = verts[map[t]], verts[map[t + 1]], verts[map[t + 2]]
        local cross = (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
        if cross * w < 0 then
            folded = folded + 1
            -- which band: 0 = around the middle ... RINGS = between the last ring and the rim
            local tri = (t - 1) / 3
            local m3 = #blob.rimVerts
            local band = tri < m3 and 0 or math.floor((tri - m3) / (2 * m3)) + 1
            blob.bandFolds = blob.bandFolds or {}
            blob.bandFolds[band] = (blob.bandFolds[band] or 0) + 1
        end
    end
    blob.folded = folded
    blob.mesh:setVertices(verts)
end

-- Gas pressure (dreamengine jelly.c): push every rim edge outwards, harder the more the area
-- shrank. Signed area and winding normals, so a blob turned inside out is pushed back out.
local function applyPressure(blob)
    if settings.pressure <= 0 then return end
    local nodes, n = blob.nodes, #blob.nodes
    local signed = 0
    local xs, ys = {}, {}
    for i = 1, n do xs[i], ys[i] = nodes[i]:getPosition() end
    for i = 1, n do
        local j = i % n + 1
        signed = signed + xs[i] * ys[j] - xs[j] * ys[i]
    end
    signed = signed / 2
    local p = settings.pressure * blob.pressureK * (blob.restArea - signed) / blob.restArea
    p = math.max(-blob.pressureK, math.min(p, 5 * blob.pressureK))
    local w = blob.restArea > 0 and 1 or -1
    for i = 1, n do
        local j = i % n + 1
        -- edge normal * edge length, pointing out for this winding
        local fx, fy = (ys[j] - ys[i]) * w * p * 0.5, -(xs[j] - xs[i]) * w * p * 0.5
        nodes[i]:applyForce(fx, fy)
        nodes[j]:applyForce(fx, fy)
    end
end

local function stepWorld(dt)
    for _, blob in ipairs(blobs) do applyPressure(blob) end
    world:update(dt)
end

---------------------------------------------------------------- world

local function makeWalls()
    local w, h = love.graphics.getDimensions()
    local ground = love.physics.newBody(world, 0, 0, 'static')
    love.physics.newFixture(ground, love.physics.newEdgeShape(0, h - 40, w, h - 40))
    love.physics.newFixture(ground, love.physics.newEdgeShape(0, -2000, 0, h))
    love.physics.newFixture(ground, love.physics.newEdgeShape(w, -2000, w, h))
    -- a shelf and a ramp to squash against
    love.physics.newFixture(ground, love.physics.newPolygonShape(780, 430, 1200, 430, 1200, 460, 780, 460))
    love.physics.newFixture(ground, love.physics.newEdgeShape(0, h - 260, 300, h - 40))
end

local function nextLook()
    lookIndex = lookIndex % #looks + 1
    return lookIndex
end

local function area(points)
    local a = 0
    for i = 1, #points do
        local p, q = points[i], points[i % #points + 1]
        a = a + p[1] * q[2] - q[1] * p[2]
    end
    return math.abs(a) / 2
end

-- area now / at rest, and how far the rim is from its rest shape (best rotation about the
-- centroid, in % of the blob's size)
local function shapeStats(blob)
    local now, cx, cy = {}, 0, 0
    for i, b in ipairs(blob.nodes) do
        local x, y = b:getPosition()
        now[i] = { x, y }
        cx, cy = cx + x, cy + y
    end
    cx, cy = cx / #now, cy / #now
    local rx, ry = 0, 0
    for _, p in ipairs(blob.rest) do rx, ry = rx + p[1], ry + p[2] end
    rx, ry = rx / #blob.rest, ry / #blob.rest
    local sxx, sxy = 0, 0
    for i, p in ipairs(now) do
        local ax, ay = blob.rest[i][1] - rx, blob.rest[i][2] - ry
        local bx, by = p[1] - cx, p[2] - cy
        sxx = sxx + ax * bx + ay * by
        sxy = sxy + ax * by - ay * bx
    end
    local angle = math.atan2(sxy, sxx)
    local c, s = math.cos(angle), math.sin(angle)
    local err, size = 0, 0
    for i, p in ipairs(now) do
        local ax, ay = blob.rest[i][1] - rx, blob.rest[i][2] - ry
        local ex, ey = (ax * c - ay * s) - (p[1] - cx), (ax * s + ay * c) - (p[2] - cy)
        err = err + math.sqrt(ex * ex + ey * ey)
        size = math.max(size, math.sqrt(ax * ax + ay * ay))
    end
    return area(now) / area(blob.rest), err / #now / size * 100
end

local function pointInPoly(x, y, verts)
    local inside, n = false, #verts
    local j = n
    for k = 1, n do
        local xi, yi, xj, yj = verts[k][1], verts[k][2], verts[j][1], verts[j][2]
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then inside = not inside end
        j = k
    end
    return inside
end

-- rim points of a blob that sit inside another blob's rim (blobs passing into each other)
local function intruders(blob)
    local count = 0
    for _, other in ipairs(blobs) do
        if other ~= blob then
            for _, b in ipairs(blob.nodes) do
                if pointInPoly(b:getX(), b:getY(), other.rimVerts) then count = count + 1 end
            end
        end
    end
    return count
end

local function runCheck()
    love.math.setRandomSeed(7)
    local dt = STEP
    local worst = {}
    local function step(seconds)
        for _ = 1, math.floor(seconds / dt) do
            stepWorld(dt)
            for i, blob in ipairs(blobs) do
                updateMesh(blob)
                blob.foldedFrames = (blob.foldedFrames or 0) + (blob.folded > 0 and 1 or 0)
                if blob.lastFolded and blob.lastFolded ~= blob.folded then
                    blob.foldToggles = (blob.foldToggles or 0) + 1
                end
                blob.lastFolded = blob.folded
                blob.restFolded = blob.restFolded or blob.folded
                blob.maxFolded = math.max(blob.maxFolded or 0, blob.folded)
                -- rim kinks: consecutive rim edges turning back more than 90 degrees
                local n, kinks = #blob.nodes, 0
                for q = 1, n do
                    local ax, ay = blob.nodes[(q - 2) % n + 1]:getPosition()
                    local px, py = blob.nodes[q]:getPosition()
                    local bx, by = blob.nodes[q % n + 1]:getPosition()
                    if (px - ax) * (bx - px) + (py - ay) * (by - py) < 0 then kinks = kinks + 1 end
                end
                blob.kinkFrames = (blob.kinkFrames or 0) + (kinks > 0 and 1 or 0)
                blob.maxIntruders = math.max(blob.maxIntruders or 0, intruders(blob))
                local a, e = shapeStats(blob)
                local w = worst[i] or { amin = 1, amax = 1, emax = 0 }
                w.amin, w.amax, w.emax = math.min(w.amin, a), math.max(w.amax, a), math.max(w.emax, e)
                worst[i] = w
            end
        end
    end
    for t = 1, 12 do
        step(0.25)
        local line = string.format('t=%.2f', t * 0.25)
        for _, blob in ipairs(blobs) do
            local a, e = shapeStats(blob)
            line = line .. string.format('  %.2f/%2.0f%% y%4.0f', a, e, blob.centre:getY())
        end
        print(line)
    end
    love.keypressed('k')
    step(4)
    print(string.format('%-14s %8s %8s %10s %10s %10s %8s %8s %8s %8s %8s %8s', 'look', 'area', 'shape%', 'area min', 'area max',
        'shape% max', 'folded', 'flips', 'toggles', 'atRest', 'max', 'inside'))
    for i, blob in ipairs(blobs) do
        local a, e = shapeStats(blob)
        local okVerts = true
        updateMesh(blob)
        for _, v in ipairs(blob.verts) do
            if v[1] ~= v[1] or v[2] ~= v[2] then okVerts = false end
        end
        print(string.format('%-14s %8.2f %8.1f %10.2f %10.2f %10.1f %8d %8d %8d %8d %8d %8d %s', looks[blob.look].url, a, e,
            worst[i].amin, worst[i].amax, worst[i].emax, blob.foldedFrames or 0, blob.normalFlips or 0,
            blob.foldToggles or 0, blob.restFolded or 0, blob.maxFolded or 0, blob.maxIntruders or 0,
            okVerts and '' or 'NaN verts!'))
    end
    local bands = {}
    for _, blob in ipairs(blobs) do
        for band, c in pairs(blob.bandFolds or {}) do bands[band] = (bands[band] or 0) + c end
    end
    local kinkFrames = 0
    for _, blob in ipairs(blobs) do kinkFrames = kinkFrames + (blob.kinkFrames or 0) end
    print('frames with a kinked rim (summed over blobs): ' .. kinkFrames)
    local line = 'folds per band (0 = middle, ' .. RINGS .. ' = next to the rim):'
    for band = 0, RINGS do line = line .. ' ' .. (bands[band] or 0) end
    print(line)
    print(string.format('pressure %.2f, spokes %.1f Hz, rim %s, %d nodes, %d bodies, %d joints', settings.pressure, settings.spokeHz,
        settings.rimRigid and 'rigid' or 'springy', NODES, world:getBodyCount(), world:getJointCount()))
end

function love.load()
    if PRESSURE_ARG then settings.pressure = PRESSURE_ARG end
    if HZ_ARG then settings.spokeHz = HZ_ARG end
    settings.meshMode = FAN_ARG and 'fan' or 'mvc'
    if BEND_ARG then settings.bend = BEND_ARG end
    if DRAW_SMOOTH_ARG then settings.drawSmooth = DRAW_SMOOTH_ARG end
    if NO_SMOOTH_ARG then settings.smooth = false end
    settings.offset = NO_OFFSET_ARG and 0 or 1
    tex1 = getSource('textures/pat/type0.png')
    tex1:setWrap('mirroredrepeat', 'mirroredrepeat')
    loadLooks()
    love.physics.setMeter(METER)
    world = love.physics.newWorld(0, GRAVITY * METER, true)
    makeWalls()
    for i = 1, 5 do
        makeBlob(180 + i * 170, 100 - (i % 2) * 150, nextLook())
    end
    love.graphics.setBackgroundColor(0.93, 0.91, 0.86)
    if CHECK then
        runCheck()
        love.event.quit()
    end
end

local accumulator = 0
function love.update(dt)
    accumulator = math.min(accumulator + dt, 1 / 15)
    while accumulator >= STEP do
        stepWorld(STEP)
        accumulator = accumulator - STEP
    end
    if mouseJoint then mouseJoint:setTarget(love.mouse.getPosition()) end
end

function love.draw()
    love.graphics.setColor(0.55, 0.5, 0.45)
    for _, body in ipairs(world:getBodies()) do
        if body:getType() == 'static' then
            for _, f in ipairs(body:getFixtures()) do
                local s = f:getShape()
                if s:getType() == 'edge' then
                    love.graphics.setLineWidth(4)
                    love.graphics.line(body:getWorldPoints(s:getPoints()))
                elseif s:getType() == 'polygon' then
                    love.graphics.polygon('fill', body:getWorldPoints(s:getPoints()))
                end
            end
        end
    end

    love.graphics.setColor(1, 1, 1)
    for _, blob in ipairs(blobs) do
        updateMesh(blob)
        love.graphics.draw(blob.mesh)
    end

    if settings.debug then
        love.graphics.setLineWidth(1)
        for _, blob in ipairs(blobs) do
            local verts, map = blob.verts, blob.map
            for t = 1, #map, 3 do
                local a, b, c = verts[map[t]], verts[map[t + 1]], verts[map[t + 2]]
                local cross = (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
                if cross * blob.winding < 0 then
                    love.graphics.setColor(1, 0, 0, 0.6) -- folded
                    love.graphics.polygon('fill', a[1], a[2], b[1], b[2], c[1], c[2])
                end
                love.graphics.setColor(0, 0, 0, 0.3)
                love.graphics.polygon('line', a[1], a[2], b[1], b[2], c[1], c[2])
            end
            love.graphics.setColor(0.9, 0.1, 0.2, 0.8)
            for _, b in ipairs(blob.nodes) do
                love.graphics.circle('line', b:getX(), b:getY(), blob.r)
            end
        end
    end

    love.graphics.setColor(0.15, 0.15, 0.15)
    local look = blobs[1] and looks[lastBlob.look]
    love.graphics.print(string.format(
        '%s mesh (m)   blobs %d   spokes %.1f Hz ([ ])   pressure %.2f (, .)   rim %s (\')   smooth %s (s)   fps %d   look %s',
        settings.meshMode, settings.bend, #blobs, settings.spokeHz, settings.pressure, settings.rimRigid and 'rigid' or 'springy',
        settings.smooth and 'on' or 'off', love.timer.getFPS(), look and look.url or '-'), 10, 10)
    love.graphics.print('drag: grab   right: new blob   n: next look   k: kick   d: debug (red = folded)   x: clear', 10, 28)
end

local function blobAt(x, y)
    local found
    world:queryBoundingBox(x - 1, y - 1, x + 1, y + 1, function(f)
        local ud = f:getUserData()
        if ud and ud.blob and not f:isSensor() and f:testPoint(x, y) then
            found = { blob = ud.blob, body = f:getBody() }
            return false
        end
        return true
    end)
    if found then return found end
    -- inside a blob's outline: carry it by the middle
    for i = #blobs, 1, -1 do
        local blob = blobs[i]
        local poly = {}
        for _, v in ipairs(blob.rimVerts) do
            poly[#poly + 1] = v[1]
            poly[#poly + 1] = v[2]
        end
        local inside, n = false, #poly / 2
        local j = n
        for k = 1, n do
            local xi, yi, xj, yj = poly[2 * k - 1], poly[2 * k], poly[2 * j - 1], poly[2 * j]
            if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then inside = not inside end
            j = k
        end
        if inside then return { blob = blob, body = blob.centre } end
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then
        local hit = blobAt(x, y)
        if hit then
            lastBlob = hit.blob
            local mass = hit.blob.centre:getMass()
            for _, b in ipairs(hit.blob.nodes) do mass = mass + b:getMass() end
            mouseJoint = love.physics.newMouseJoint(hit.body, x, y)
            mouseJoint:setMaxForce(mass * 4000)
        end
    elseif button == 2 then
        makeBlob(x, y, nextLook())
    end
end

function love.mousereleased(_, _, button)
    if button == 1 and mouseJoint then
        mouseJoint:destroy()
        mouseJoint = nil
    end
end

function love.keypressed(key)
    if key == 'escape' then love.event.quit() end
    if mouseJoint and (key == 'n' or key == 's' or key == 'x' or key == 'm' or key == 'b') then
        mouseJoint:destroy()
        mouseJoint = nil
    end
    if key == 'd' then settings.debug = not settings.debug end
    if key == '[' or key == ']' then
        settings.spokeHz = math.max(0.5, math.min(20, settings.spokeHz * (key == ']' and 1.4 or 1 / 1.4)))
        for _, blob in ipairs(blobs) do setJointSettings(blob) end
    end
    if key == ',' or key == '.' then
        settings.pressure = key == '.' and (settings.pressure == 0 and 0.25 or settings.pressure * 2)
            or (settings.pressure <= 0.25 and 0 or settings.pressure / 2)
    end
    if key == "'" then
        settings.rimRigid = not settings.rimRigid
        for _, blob in ipairs(blobs) do setJointSettings(blob) end
    end
    if key == 's' then
        settings.smooth = not settings.smooth
        for i = 1, #blobs do blobs[1] = rebuildBlob(blobs[1]) end
    end
    if key == 'b' then
        settings.bend = settings.bend == 0 and 3 or settings.bend >= 30 and 0 or settings.bend * 2
        for i = 1, #blobs do blobs[1] = rebuildBlob(blobs[1]) end
    end
    if key == 'm' then
        settings.meshMode = settings.meshMode == 'mvc' and 'fan' or 'mvc'
        for i = 1, #blobs do blobs[1] = rebuildBlob(blobs[1]) end
    end
    if key == 'n' and lastBlob then lastBlob = rebuildBlob(lastBlob, nextLook()) end
    if key == 'k' then
        for _, blob in ipairs(blobs) do
            local ix, iy = love.math.random(-150, 150), -love.math.random(500, 900)
            for _, b in ipairs(blob.nodes) do b:applyLinearImpulse(ix * b:getMass(), iy * b:getMass()) end
            blob.centre:applyLinearImpulse(ix * blob.centre:getMass(), iy * blob.centre:getMass())
        end
    end
    if key == 'x' then
        for _, blob in ipairs(blobs) do destroyBlob(blob) end
        blobs, lastBlob = {}, nil
    end
end

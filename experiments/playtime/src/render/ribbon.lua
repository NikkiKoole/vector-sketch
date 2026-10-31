-- src/render/ribbon.lua (split from physics/box2d-draw-textured.lua, SPLIT1)
local lib = {}
local mathutils = require('src.math-utils')
local polyline = require('src.polyline')
local native = require('src.ribbon-native')

lib.useRibbonMiterClamp = true -- A/B toggle: per-sample bend-aware half-width in texturedCurve
-- Weak-keyed side tables so meshes GC cleanly.
local _vertsBufByMesh = setmetatable({}, { __mode = "k" })
local function _ensureVertsBuf(mesh)
    local buf = _vertsBufByMesh[mesh]
    if buf then return buf end
    local count = mesh:getVertexCount()
    buf = {}
    -- Precreate the vertex tables so we only mutate numbers each frame.
    for i = 1, count do buf[i] = { 0, 0, 0, 0 } end
    _vertsBufByMesh[mesh] = buf
    return buf
end

-- todo segments need to be parameterized
-- Samples along a textured ribbon (limbs, hair, lips). Each one costs per frame (the
-- curve is evaluated and the strip rewritten): 32 -> 16 took 20 ribbons-per-Mipo from
-- 3.4 to 2.2 ms with 20 Mipos. Only new strips pick up a change (hot reload makes new ones).
lib.ribbonSegments = 16
-- Pinched strips (lips) take more, for a round curl into the mouth corner (at 16 it was
-- chunky). Lips are laid only while a mouth moves.
lib.pinchSegments = 48

local function createTexturedTriangleStrip(image, optionalWidthMultiplier, segments)
    -- this assumes an strip that is oriented vertically
    local w, h = image:getDimensions()
    w = w * (optionalWidthMultiplier or 1)

    local vertices = {}
    segments = segments or lib.ribbonSegments
    local segMinus1 = segments - 1
    local hPart = h / (segMinus1)
    local hv = 1 / (segMinus1)
    local runningHV = 0
    local runningHP = 0
    local index = 0

    for _ = 1, segments do
        vertices[index + 1] = { -w * .5, runningHP, 0, runningHV }
        vertices[index + 2] = { w * .5, runningHP, 1, runningHV }
        runningHV = runningHV + hv
        runningHP = runningHP + hPart
        index = index + 2
    end

    local mesh = love.graphics.newMesh(vertices, "strip")
    mesh:setTexture(image)

    return mesh
end

local function resolveIndex(index, length)
    return (index < 0) and ((length + index) % length) or (index % length)
end

local function getIndices(length, startIdx, endIdx, allowFullLoop)
    local start = resolveIndex(startIdx, length)
    local ending = resolveIndex(endIdx, length)
    local result = {}

    local i = start
    repeat
        table.insert(result, i)
        i = (i + 1) % length
    until i == ending and (not allowFullLoop or i == start)

    if i == ending then
        table.insert(result, i)
    end

    return result
end

local _stripCache = setmetatable({}, { __mode = "k" }) -- image -> table
local function getStrip(image, wmul)
    wmul = wmul or 1
    local byW = _stripCache[image]
    if not byW then
        byW = {}; _stripCache[image] = byW
    end
    local m = byW[wmul]
    if not m then
        m = createTexturedTriangleStrip(image, wmul)
        byW[wmul] = m
    end
    return m
end

-- Fan mesh pool: image -> { [vertexCount] = { mesh=..., vertsBuf=... } }
local _fanPool = setmetatable({}, { __mode = "k" })

local function _getFanMesh(image, vertexCount)
    local byV = _fanPool[image]
    if not byV then
        byV = {}; _fanPool[image] = byV
    end
    local rec = byV[vertexCount]
    if not rec then
        local verts = {}
        for i = 1, vertexCount do verts[i] = { 0, 0, 0, 0 } end -- prealloc vertex tables
        local mesh = love.graphics.newMesh(verts, "fan")
        mesh:setTexture(image)
        rec = { mesh = mesh, verts = verts }
        byV[vertexCount] = rec
    end
    return rec.mesh, rec.verts
end

local sqrt = math.sqrt
local function growLine(p1, p2, length)
    local dx, dy = p1[1] - p2[1], p1[2] - p2[2]
    local inv = 1.0 / (sqrt(dx * dx + dy * dy) + 1e-12)
    return p1[1] + length * dx * inv, p1[2] + length * dy * inv
end

local function makeSquishableUVsFromPoints(v)
    local verts = {}
    if #v == 8 then -- has 4 (4*(x,y)) vertices
        verts[1] = { v[1], v[2], 0, 0 }
        verts[2] = { v[3], v[4], 1, 0 }
        verts[3] = { v[5], v[6], 1, 1 }
        verts[4] = { v[7], v[8], 0, 1 }
        verts[5] = { v[1], v[2], 0, 0 } -- this is an extra one to make it go round
    end

    if #v == 16 then -- has 8 (8*(x,y)) vertices
        verts[1] = { v[1], v[2], 0, 0 }
        verts[2] = { v[3], v[4], .5, 0 }
        verts[3] = { v[5], v[6], 1, 0 }
        verts[4] = { v[7], v[8], 1, .5 }
        verts[5] = { v[9], v[10], 1, 1 }
        verts[6] = { v[11], v[12], .5, 1 }
        verts[7] = { v[13], v[14], 0, 1 }
        verts[8] = { v[15], v[16], 0, .5 }
        verts[9] = { v[1], v[2], 0, 0 } -- this is an extra one to make it go round
    end

    return verts
end

-- Meshes that belong to one drawable (`owner`: its extra; `slot` tells its layers apart), kept
-- until what they're made from changes (docs/MIPO-DRAWING.md L1). The shared ones (getStrip,
-- _getFanMesh: one per picture) are rewritten by every user every frame.
local owned = setmetatable({}, { __mode = 'k' }) -- [owner] = { [slot] = record }
local function ownedRecord(owner, slot)
    local byOwner = owned[owner]
    if not byOwner then byOwner = {}; owned[owner] = byOwner end
    return byOwner, byOwner[slot]
end

local function samePoints(a, b)
    if not a or #a ~= #b then return false end
    for i = 1, #b do
        if a[i] ~= b[i] then return false end
    end
    return true
end

local function copyPoints(points, into)
    into = into or {}
    for i = 1, #points do into[i] = points[i] end
    for i = #points + 1, #into do into[i] = nil end
    return into
end

-- A fan over `vertices` (a texfixture's corners, in its body's frame) with `img`, built once and
-- kept until the picture, the corners or growFactor change.
local function ownFan(owner, slot, img, growFactor, vertices)
    local byOwner, rec = ownedRecord(owner, slot)
    if rec and rec.img == img and rec.growFactor == growFactor and samePoints(rec.vertices, vertices) then
        return rec.mesh
    end
    local n = math.floor(#vertices / 2)
    local grown = {}
    for i = 1, #vertices do grown[i] = vertices[i] * growFactor end
    local ring = makeSquishableUVsFromPoints(grown)
    local cx, cy = mathutils.getCenterOfPoints(vertices)
    local verts = { { cx, cy, 0.5, 0.5 } }
    for i = 1, (n + 1) do verts[i + 1] = ring[i] or { 0, 0, 0, 0 } end
    if rec then rec.mesh:release() end
    local mesh = love.graphics.newMesh(verts, 'fan')
    mesh:setTexture(img)
    byOwner[slot] = { mesh = mesh, img = img, growFactor = growFactor, vertices = copyPoints(vertices) }
    return mesh
end

local function drawSquishableHairOver(img, x, y, r, sx, sy, growFactor, vertices, owner, slot)
    if owner then
        love.graphics.draw(ownFan(owner, slot, img, growFactor, vertices), x, y, r, sx, sy)
        return
    end
    -- grow once into a flat array (reuse a local)
    local nnums = #vertices         -- flat x,y,... array
    local n = math.floor(nnums / 2) -- number of polygon points
    local grown = {}                -- short-lived; ok (main cost was newMesh)
    for i = 1, nnums do grown[i] = vertices[i] * growFactor end

    -- ring UVs from your existing helper (allocates, but cheap vs newMesh)
    local ring = makeSquishableUVsFromPoints(grown) -- size n+1 (closed)
    local cx, cy = mathutils.getCenterOfPoints(vertices)

    -- center + ring => total vertex count
    local vcount = (n + 1) + 1 -- closed ring + center
    local mesh, buf = _getFanMesh(img, vcount)

    -- write center
    local v = buf[1]; v[1], v[2], v[3], v[4] = cx, cy, 0.5, 0.5
    -- write ring
    for i = 1, #ring do
        local s = ring[i]
        local d = buf[i + 1]
        d[1], d[2], d[3], d[4] = s[1], s[2], s[3], s[4]
    end

    mesh:setVertices(buf) -- 1 call instead of creating a mesh
    love.graphics.draw(mesh, x, y, r, sx, sy)
end

-- Batched, no mesh:getVertex, 1x mesh:setVertices per call
-- Per-sample scratch arrays for texturedCurve (reused across calls, single-threaded).
local _tcX, _tcY, _tcDX, _tcDY = {}, {}, {}, {}

-- Build a textured triangle-strip ribbon along `curve`.
-- `halfWidth` is derived from image width × dir × scaleW.
--
-- Bow-tie prevention: at sharp bends (e.g. arm-hair curve through shoulder→elbow→wrist when
-- the elbow is flexed), a constant-width ribbon's inner edge crosses itself, producing a
-- visible X/bow-tie. We clamp per-sample halfWidth by the polyline-corner miter limit:
--   halfWidth ≤ min(prevSegLen, nextSegLen) × tan((π − turnAngle) / 2)
-- where turnAngle = acos(segDirPrev · segDirNext). Straight joins are unaffected
-- (tan(π/2) = ∞); 90° joins are capped at min-seg-len; sharper joins taper toward zero.
-- Pinch (lips): a lip curls into the mouth corner more tightly than it is thick, and its inner
-- edge folded there (a zigzag; the miter clamp below skips the ends and lets through about twice
-- what a smooth bend over several samples can take). Pinched, only the edge on the inside of a
-- bend is pulled in, to PINCH_FACTOR of the miter limit, and its u with it: the picture is cut
-- there, not squeezed. (Narrowing the whole strip squeezed the picture, and a squeezed picture
-- kinks along each section's diagonal: a sawtooth edge.) The limit may grow by at most PINCH_SLOPE
-- per px of curve, so the cut eases in. Tuned on a lip at lipScale 0.3 (2026-10-31). The same
-- in native/desound/ribbon.c.
local PINCH_FACTOR, PINCH_SLOPE = 0.4, 0.5
local _limitLeft, _limitRight = {}, {} -- per sample: how far the edge may reach to the left / right
local function pinchLimits(segments)
    local sqrt_, xs, ys = math.sqrt, _tcX, _tcY
    local left, right = _limitLeft, _limitRight
    for i = 1, segments do left[i], right[i] = math.huge, math.huge end
    for i = 2, segments - 1 do
        local ax, ay = xs[i] - xs[i - 1], ys[i] - ys[i - 1]
        local bx, by = xs[i + 1] - xs[i], ys[i + 1] - ys[i]
        local la, lb = sqrt_(ax * ax + ay * ay), sqrt_(bx * bx + by * by)
        if la > 1e-12 and lb > 1e-12 then
            local dot = (ax * bx + ay * by) / (la * lb)
            if dot < 0.9999 then
                if dot < -1 then dot = -1 end
                local limit = PINCH_FACTOR * (la < lb and la or lb) * math.tan((math.pi - math.acos(dot)) * 0.5)
                -- turning toward the left normal: the left edge is inside the bend
                if ax * by - ay * bx > 0 then left[i] = limit else right[i] = limit end
            end
        end
    end
    if segments > 2 then
        left[1], right[1] = left[2], right[2]
        left[segments], right[segments] = left[segments - 1], right[segments - 1]
    end
    for i = 2, segments do
        local dx, dy = xs[i] - xs[i - 1], ys[i] - ys[i - 1]
        local d = PINCH_SLOPE * sqrt_(dx * dx + dy * dy)
        if left[i - 1] + d < left[i] then left[i] = left[i - 1] + d end
        if right[i - 1] + d < right[i] then right[i] = right[i - 1] + d end
    end
    for i = segments - 1, 1, -1 do
        local dx, dy = xs[i] - xs[i + 1], ys[i] - ys[i + 1]
        local d = PINCH_SLOPE * sqrt_(dx * dx + dy * dy)
        if left[i + 1] + d < left[i] then left[i] = left[i + 1] + d end
        if right[i + 1] + d < right[i] then right[i] = right[i + 1] + d end
    end
end

local function texturedCurve(curve, image, mesh, dir, scaleW, dl, shift, pinch)
    dir             = dir or 1
    shift           = shift or 0 -- moves the ribbon's middle this far along the curve's left normal
    scaleW          = scaleW or 1
    dl              = dl or curve:getDerivative()

    -- Only need the texture width to set half-width of the ribbon
    local w         = image:getWidth()
    local halfWidth = (w * dir) * scaleW
    local absHW     = halfWidth < 0 and -halfWidth or halfWidth
    local signHW    = halfWidth < 0 and -1 or 1

    -- Prealloc / reuse vertex tables for this mesh
    local verts     = _ensureVertsBuf(mesh)

    local count     = mesh:getVertexCount() -- always even
    local segments  = count / 2             -- number of (left,right) pairs
    local segMinus1 = segments - 1

    -- Safety against degenerate curves
    local eps       = 1e-12
    local sqrt_     = math.sqrt
    local acos      = math.acos
    local tan       = math.tan
    local PI        = math.pi

    -- Pass 1: sample positions and normalized tangents along the curve.
    for p = 0, segMinus1 do
        local t            = p / segMinus1
        local x, y         = curve:evaluate(t)
        local dx, dy       = dl:evaluate(t)
        local invlen       = 1.0 / sqrt_(dx * dx + dy * dy + eps)
        _tcX[p + 1]        = x
        _tcY[p + 1]        = y
        _tcDX[p + 1]       = dx * invlen
        _tcDY[p + 1]       = dy * invlen
    end

    if pinch then pinchLimits(segments) end

    -- Pass 2: write ribbon vertices with bend-aware half-width.
    local p = 0
    for j = 1, count, 2 do
        local i    = p + 1
        local x    = _tcX[i]
        local y    = _tcY[i]

        -- Left normal of the tangent.
        local nx   = -_tcDY[i]
        local ny   = _tcDX[i]

        -- Adaptive half-width: clamp to prevent inner-edge crossover at sharp bends.
        -- A/B toggle (lib.useRibbonMiterClamp): false skips the clamp, restoring the
        -- pre-2026-04-13 constant-width behaviour (bow-tie at flexed elbows).
        local hw   = absHW
        if not pinch and lib.useRibbonMiterClamp and i > 1 and i < segments then
            local ax = x - _tcX[i - 1]
            local ay = y - _tcY[i - 1]
            local bx = _tcX[i + 1] - x
            local by = _tcY[i + 1] - y
            local la = sqrt_(ax * ax + ay * ay)
            local lb = sqrt_(bx * bx + by * by)
            if la > eps and lb > eps then
                local dot = (ax * bx + ay * by) / (la * lb)
                if dot < 0.9999 then
                    if dot < -1 then dot = -1 elseif dot > 1 then dot = 1 end
                    local turn  = acos(dot)                -- 0 = straight, π = reverse
                    local alpha = (PI - turn) * 0.5        -- interior half-angle
                    -- tan(alpha) can be huge near straight joins → harmless (clamp below hw)
                    local maxHw = (la < lb and la or lb) * tan(alpha)
                    if maxHw < hw then hw = maxHw end
                end
            end
        end
        hw = hw * signHW

        -- the u=0 and u=1 edges, as offsets along the left normal
        local oL, oR = hw + shift, shift - hw
        local uL, uR = 0, 1
        if pinch and oL ~= oR then
            -- pull in the edge inside the bend; u follows the offset, so the picture is cut
            local a, b, left, right = oL, oR, _limitLeft[i], _limitRight[i]
            if oL > left then oL = left elseif oL < -right then oL = -right end
            if oR > left then oR = left elseif oR < -right then oR = -right end
            uL, uR = (a - oL) / (a - b), (a - oR) / (a - b)
        end
        local xL                   = x + oL * nx
        local yL                   = y + oL * ny
        local xR                   = x + oR * nx
        local yR                   = y + oR * ny

        -- UVs: left u=0, right u=1; v increases 0..1 per pair
        local v                    = (segMinus1 > 0) and (p / segMinus1) or 0

        local vL                   = verts[j]
        vL[1], vL[2], vL[3], vL[4] = xL, yL, uL, v

        local vR                   = verts[j + 1]
        vR[1], vR[2], vR[3], vR[4] = xR, yR, uR, v

        p                          = p + 1
    end

    -- One C call instead of N*2
    mesh:setVertices(verts)
end

-- The hair strip along part of a body's outline (TRACE_VERTICES), in body space: it only
-- changes when the outline or the strip's settings do, so the mesh is kept until then.
-- Building it every frame (curve, polyline, newMesh) was ~120 us per Mipo.
-- Weak keys, not on `extra`: that's saved.
local traceMeshCache = setmetatable({}, { __mode = 'k' })
local function traceVerticesMesh(extra, outline)
    local sum = 0
    for k = 1, #outline do sum = sum + outline[k] * k end
    local key = table.concat({ #outline, sum, tostring(extra.startIndex), tostring(extra.endIndex),
        extra.tension or .02, extra.spacing or 5, extra.width or 100 }, '|')
    local cached = traceMeshCache[extra]
    if cached and cached.key == key then return cached.mesh end

    local indices = getIndices(#outline / 2, extra.startIndex, extra.endIndex)
    local points = {}
    for j = 1, #indices do
        points[#points + 1] = { outline[indices[j] * 2 + 1], outline[indices[j] * 2 + 2] }
    end
    local mesh
    if #points >= 2 then
        local coords = mathutils.unloosenVanillaline(points, extra.tension or .02, extra.spacing or 5)
        local verts = polyline.miter(coords, extra.width or 100)
        local cx, cy = mathutils.getCenterOfPoints(outline)
        local vertsWithUVs = {}
        for vi = 1, #verts do
            local u = (vi % 2 == 1) and 0 or 1
            local v = math.floor(((vi - 1) / 2)) / (#verts / 2 - 1)
            vertsWithUVs[vi] = { verts[vi][1] - cx, verts[vi][2] - cy, u, v }
        end
        mesh = love.graphics.newMesh(vertsWithUVs, "strip")
    end
    if cached and cached.mesh then cached.mesh:release() end
    traceMeshCache[extra] = { key = key, mesh = mesh }
    return mesh
end


-- A strip along the Bezier through `points`, with `img` `scaleW` wide (texturedCurve's dir, shift),
-- that belongs to `owner`: the curve is only laid again when the points or the picture change.
-- `curve` (optional): the Bezier through `points` and its derivative, when a drawer lays several
-- layers along one curve (made only if a layer needs laying). `pinch`: cut the inside of tight
-- curls instead of folding (lips, pinchLimits above).
--
-- Laid in C when the native library is there (src/ribbon-native.lua, lib.useNative): the same
-- vertices (to float rounding), 28 -> ~4 us a strip on an iPhone SE 2 (2026-10-31). Laying
-- them was ~3 ms a frame with 20 moving Mipos. Without it (the web, a desktop without
-- native/desound/build.sh) texturedCurve lays them in Lua.
lib.useNative = true
local nativeData -- one ByteData the C writes into; setVertices copies it into the mesh

local function nativeStrip(img, segments)
    local count = segments * 2
    local mesh = love.graphics.newMesh(native.FORMAT, count, 'strip', 'dynamic')
    mesh:setTexture(img)
    if not nativeData or nativeData:getSize() < count * native.BYTES_PER_VERTEX then
        nativeData = love.data.newByteData(count * native.BYTES_PER_VERTEX)
    end
    return mesh
end

function lib.ownStrip(owner, slot, img, scaleW, points, dir, shift, curve, pinch)
    local byOwner, rec = ownedRecord(owner, slot)
    local useNative = lib.useNative and native.available()
    if not rec or rec.img ~= img or rec.scaleW ~= scaleW or rec.dir ~= dir or rec.shift ~= shift
        or rec.native ~= useNative or rec.pinch ~= pinch then
        if rec then rec.mesh:release() end
        local segments = pinch and lib.pinchSegments or lib.ribbonSegments
        rec = { mesh = useNative and nativeStrip(img, segments) or createTexturedTriangleStrip(img, scaleW, segments),
            img = img, scaleW = scaleW, dir = dir, shift = shift, native = useNative, pinch = pinch }
        byOwner[slot] = rec
    end
    if not samePoints(rec.points, points) then
        if useNative then
            -- `points` are the Bezier's control points as they are: no growing, no doubling
            local segments = rec.mesh:getVertexCount() / 2
            local n = native.strip(points, 0, 0, segments, img:getWidth() * (dir or 1) * (scaleW or 1),
                shift or 0, lib.useRibbonMiterClamp, nativeData, pinch)
            if n > 0 then rec.mesh:setVertices(nativeData, 1, n) end
        else
            local bezier, derivative
            if curve then bezier, derivative = curve() else bezier = love.math.newBezierCurve(points) end
            texturedCurve(bezier, img, rec.mesh, dir, scaleW, derivative, shift, pinch)
        end
        rec.points = copyPoints(points, rec.points)
    end
    return rec.mesh
end

-- Forget every owned strip and fan (spec/draw-cache_spec.lua draws a frame from scratch).
function lib.clearOwned()
    for _, byOwner in pairs(owned) do
        for _, rec in pairs(byOwner) do rec.mesh:release() end
    end
    owned = setmetatable({}, { __mode = 'k' })
end

-- A baked image is being replaced: free the strips and fans made for it.
function lib.releaseImage(img)
    for _, mesh in pairs(_stripCache[img] or {}) do mesh:release() end
    for _, rec in pairs(_fanPool[img] or {}) do rec.mesh:release() end
    _stripCache[img] = nil
    _fanPool[img] = nil
end

lib.getStrip = getStrip
lib.texturedCurve = texturedCurve
lib.growLine = growLine
lib.drawSquishableHairOver = drawSquishableHairOver
lib.traceVerticesMesh = traceVerticesMesh

return lib

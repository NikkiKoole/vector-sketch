-- src/render/ribbon.lua (split from physics/box2d-draw-textured.lua, SPLIT1)
local lib = {}
local mathutils = require('src.math-utils')
local polyline = require('src.polyline')

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

local function createTexturedTriangleStrip(image, optionalWidthMultiplier)
    -- this assumes an strip that is oriented vertically
    local w, h = image:getDimensions()
    w = w * (optionalWidthMultiplier or 1)

    local vertices = {}
    local segments = lib.ribbonSegments
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

local function drawSquishableHairOver(img, x, y, r, sx, sy, growFactor, vertices)
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
local function texturedCurve(curve, image, mesh, dir, scaleW, dl, shift)
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
        if lib.useRibbonMiterClamp and i > 1 and i < segments then
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

        local xL                   = x + (hw + shift) * nx
        local yL                   = y + (hw + shift) * ny
        local xR                   = x - (hw - shift) * nx
        local yR                   = y - (hw - shift) * ny

        -- UVs: left u=0, right u=1; v increases 0..1 per pair
        local v                    = (segMinus1 > 0) and (p / segMinus1) or 0

        local vL                   = verts[j]
        vL[1], vL[2], vL[3], vL[4] = xL, yL, 0, v

        local vR                   = verts[j + 1]
        vR[1], vR[2], vR[3], vR[4] = xR, yR, 1, v

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

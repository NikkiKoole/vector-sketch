-- spine-mesh.lua — sandbox version.
--
-- Same (t, s) math as the parked playtime POC, but with none of the
-- coordinate-frame ambiguity: caller provides a polygon (world coords)
-- and a chain (world coords, in order). No bodies, no sfixtures.
--
--   bind(polygonWorld, chainWorld) -> bindTable
--   evaluate(bind, newChainWorld)  -> deformed polygon (world coords)
--
-- Chain is a flat {x1,y1,x2,y2,...} polyline. Polygon is a flat
-- {x1,y1,...} closed outline. Order of chain points is authoritative.

local M = {}

-- ─── internal helpers ──────────────────────────────────────────────

local function arcLengths(polyline)
    local out = { 0 }
    local total = 0
    local n = #polyline / 2
    for i = 1, n - 1 do
        local ax, ay = polyline[(i - 1) * 2 + 1], polyline[(i - 1) * 2 + 2]
        local bx, by = polyline[i * 2 + 1], polyline[i * 2 + 2]
        local dx, dy = bx - ax, by - ay
        total = total + math.sqrt(dx * dx + dy * dy)
        out[i + 1] = total
    end
    return out, total
end

-- Project (px, py) onto polyline, return normalised t ∈ [0,1] along arc
-- length and signed perpendicular s (positive = left of chain direction,
-- negative = right).
local function closestOnPolyline(px, py, polyline, arcs, totalLen)
    local bestD2, bestT, bestS = math.huge, 0, 0
    local numSeg = (#polyline / 2) - 1
    for i = 1, numSeg do
        local ax, ay = polyline[(i - 1) * 2 + 1], polyline[(i - 1) * 2 + 2]
        local bx, by = polyline[i * 2 + 1], polyline[i * 2 + 2]
        local dx, dy = bx - ax, by - ay
        local segLen2 = dx * dx + dy * dy
        if segLen2 < 1e-12 then
            local qx, qy = ax - px, ay - py
            local d2 = qx * qx + qy * qy
            if d2 < bestD2 then
                bestD2 = d2
                bestT = arcs[i] / math.max(totalLen, 1e-9)
                bestS = 0
            end
        else
            local u = ((px - ax) * dx + (py - ay) * dy) / segLen2
            if u < 0 then u = 0 elseif u > 1 then u = 1 end
            local cx, cy = ax + u * dx, ay + u * dy
            local qx, qy = px - cx, py - cy
            local d2 = qx * qx + qy * qy
            if d2 < bestD2 then
                bestD2 = d2
                local segArc = arcs[i] + u * math.sqrt(segLen2)
                bestT = segArc / math.max(totalLen, 1e-9)
                local nxn = -dy      -- left-normal of segment direction
                local nyn = dx
                local sign = (qx * nxn + qy * nyn) >= 0 and 1 or -1
                bestS = sign * math.sqrt(d2)
            end
        end
    end
    return bestT, bestS
end

-- Duplicate middle control points N times (CONNECTED_TEXTURE trick) so
-- a high-degree Bezier hugs them rather than smoothing them away.
local function doubleControlPoints(points, dups)
    local n = #points / 2
    if n <= 2 or dups <= 0 then return points end
    local out = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        out[#out + 1] = x
        out[#out + 1] = y
        local isMiddle = (i > 1) and (i < #points - 1)
        if isMiddle then
            for _ = 1, dups do
                out[#out + 1] = x
                out[#out + 1] = y
            end
        end
    end
    return out
end

-- ─── public API ────────────────────────────────────────────────────

-- Bind a polygon to a chain at rest pose. Chain is the sequence of
-- joint world positions (the skeleton's limb chain at rest).
--
-- `softRoot` (optional): { falloff = 0..1, strength = 0..1 }. When set,
-- computes a per-vertex `rootBlend` that pulls shoulder-end verts
-- toward their rest position. Verts with t <= falloff get a blend
-- ramped from `strength` at t=0 down to 0 at t=falloff. Rotating the
-- chain then *stretches* the shoulder skin instead of pivoting it
-- rigidly — a localized LBS-style soft attachment at the root.
function M.bind(polygon, chain, softRoot)
    assert(type(polygon) == 'table' and #polygon >= 6, 'polygon needs >=6 coords')
    assert(type(chain) == 'table' and #chain >= 4, 'chain needs >=4 coords (>=2 points)')
    local arcs, total = arcLengths(chain)
    assert(total > 1e-6, 'chain has zero length')

    local tsPerVert = {}
    local rootBlend = {}
    local falloff = (softRoot and softRoot.falloff) or 0
    local strength = (softRoot and softRoot.strength) or 0
    for i = 1, #polygon, 2 do
        local t, s = closestOnPolyline(polygon[i], polygon[i + 1], chain, arcs, total)
        tsPerVert[#tsPerVert + 1] = t
        tsPerVert[#tsPerVert + 1] = s
        local blend = 0
        if falloff > 0 and t < falloff then
            blend = strength * (1 - t / falloff)
        end
        rootBlend[#rootBlend + 1] = blend
    end
    return {
        polygon = polygon,
        restChain = chain,
        arcs = arcs,
        total = total,
        tsPerVert = tsPerVert,
        rootBlend = rootBlend,
    }
end

-- Evaluate a bind against new chain positions. Returns flat array of
-- deformed polygon coords (world). `bendiness` (0..4-ish) controls how
-- tightly the Bezier hugs the chain joints:
--   0 = very soft, rubbery (degree-N Bezier smooths across middles)
--   2 = moderate (default)
--   4+ = near-sharp corners at joints (curve hugs tightly)
function M.evaluate(bind, newChain, bendiness)
    if #newChain < 4 then return nil end
    bendiness = bendiness or 2
    local pts = newChain
    if #pts == 4 then
        pts = { pts[1], pts[2], (pts[1] + pts[3]) / 2, (pts[2] + pts[4]) / 2, pts[3], pts[4] }
    end
    local ctrl = doubleControlPoints(pts, bendiness)
    local curve = love.math.newBezierCurve(ctrl)
    local deriv = curve:getDerivative()

    local out = {}
    local ts = bind.tsPerVert
    local blends = bind.rootBlend
    local poly = bind.polygon
    for i = 1, #ts, 2 do
        local t, s = ts[i], ts[i + 1]
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
        local cx, cy = curve:evaluate(t)
        local dx, dy = deriv:evaluate(t)
        local dlen = math.sqrt(dx * dx + dy * dy)
        local tx = dlen > 1e-9 and dx / dlen or 1
        local ty = dlen > 1e-9 and dy / dlen or 0
        local nx, ny = -ty, tx -- left-normal
        local armX = cx + s * nx
        local armY = cy + s * ny
        -- Soft-root blend: near t=0, pull toward rest position so the
        -- shoulder end stretches instead of rotating rigidly.
        local vi = (i + 1) / 2
        local b = blends and blends[vi] or 0
        if b > 0 then
            local rx = poly[i]
            local ry = poly[i + 1]
            out[#out + 1] = armX + b * (rx - armX)
            out[#out + 1] = armY + b * (ry - armY)
        else
            out[#out + 1] = armX
            out[#out + 1] = armY
        end
    end
    return out
end

-- ─── multi-chain (hard assignment) ────────────────────────────────
--
-- Bind a single polygon against MULTIPLE chains. For each vertex, pick
-- the chain whose polyline is closest; store (chainName, t, s). At
-- runtime each vertex is evaluated on its own chain's live curve.
--
-- Caveat: hard assignment means a vertex is driven 100% by one chain.
-- At region boundaries (torso↔arm, hip↔leg) adjacent vertices may be
-- on different chains — the edge between them visibly stretches when
-- those chains diverge. To smooth seams, switch to weighted blending
-- (future work).
--
-- chainsByName = { [name] = {x1,y1,...}, ... }

function M.bindMultiChain(polygon, chainsByName)
    local cd = {}
    for name, chain in pairs(chainsByName) do
        local arcs, total = arcLengths(chain)
        cd[name] = { chain = chain, arcs = arcs, total = total }
    end

    local perVert = {}
    for i = 1, #polygon, 2 do
        local px, py = polygon[i], polygon[i + 1]
        local bestName, bestD2, bestT, bestS = nil, math.huge, 0, 0
        for name, c in pairs(cd) do
            local t, s = closestOnPolyline(px, py, c.chain, c.arcs, c.total)
            local d2 = s * s -- closestOnPolyline returns s = sign * sqrt(d²)
            if d2 < bestD2 then
                bestD2 = d2
                bestName = name
                bestT = t
                bestS = s
            end
        end
        perVert[#perVert + 1] = { chain = bestName, t = bestT, s = bestS }
    end

    return {
        polygon = polygon,
        chainsRest = chainsByName,
        perVert = perVert,
        multi = true, -- marker so callers know which evaluate to use
    }
end

function M.evaluateMultiChain(bind, chainsByName, bendiness)
    bendiness = bendiness or 2
    local curves = {}
    for name, chain in pairs(chainsByName) do
        if #chain >= 4 then
            local pts = chain
            if #pts == 4 then
                pts = { pts[1], pts[2], (pts[1] + pts[3]) / 2, (pts[2] + pts[4]) / 2, pts[3], pts[4] }
            end
            local ctrl = doubleControlPoints(pts, bendiness)
            local c = love.math.newBezierCurve(ctrl)
            curves[name] = { curve = c, deriv = c:getDerivative() }
        end
    end

    local out = {}
    for _, v in ipairs(bind.perVert) do
        local c = curves[v.chain]
        local x, y
        if c then
            local t = v.t
            if t < 0 then t = 0 elseif t > 1 then t = 1 end
            local cx, cy = c.curve:evaluate(t)
            local dx, dy = c.deriv:evaluate(t)
            local dlen = math.sqrt(dx * dx + dy * dy)
            local tx = dlen > 1e-9 and dx / dlen or 1
            local ty = dlen > 1e-9 and dy / dlen or 0
            local nx, ny = -ty, tx
            x = cx + v.s * nx
            y = cy + v.s * ny
        else
            x, y = 0, 0
        end
        out[#out + 1] = x
        out[#out + 1] = y
    end
    return out
end

return M

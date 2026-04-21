-- src/spine-mesh.lua
--
-- Single-chain spine-bind: deforms a polygon via a Bezier curve through
-- a chain of nodes. At bind time the Bezier is rendered to a dense
-- polyline and each vertex is decomposed into (t, s) — arc-length
-- parameter along that polyline + signed perpendicular distance. At
-- runtime the Bezier is rendered again with the SAME bendiness and
-- each vertex is placed at polyline(t) + s * left-normal.
--
-- Binding against the dense-polyline (not the raw chain or the Bezier
-- parameter) is what makes rest pose round-trip exactly: arc-length
-- fraction and Bezier parameter aren't the same mapping, so mixing
-- them shifts verts the moment you bind.
--
-- Used by MESHUSERT when spineBind is present. See
-- docs/MESHUSERT-SPINE-BIND-PLAN.md.

local lib = {}

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

-- Project (px, py) onto polyline, return t (arc-length fraction; can
-- be <0 or >1 when the vert sits past an endpoint along the first/
-- last segment tangent) and signed perpendicular s (positive = left
-- of chain direction). pointOnPolyline mirrors the same extrapolation.
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
            -- Clamp only between segments; allow overshoot past the
            -- first/last segment so end-of-chain verts record their
            -- along-axis offset instead of collapsing to the endpoint.
            if i > 1 and u < 0 then u = 0 end
            if i < numSeg and u > 1 then u = 1 end
            local cx, cy = ax + u * dx, ay + u * dy
            local qx, qy = px - cx, py - cy
            local d2 = qx * qx + qy * qy
            if d2 < bestD2 then
                bestD2 = d2
                local segArc = arcs[i] + u * math.sqrt(segLen2)
                bestT = segArc / math.max(totalLen, 1e-9)
                local nxn, nyn = -dy, dx -- left-normal
                local sign = (qx * nxn + qy * nyn) >= 0 and 1 or -1
                bestS = sign * math.sqrt(d2)
            end
        end
    end
    return bestT, bestS
end

-- Duplicate middle control points N times so the Bezier hugs them
-- instead of smoothing them away. Mirrors what CONNECTED_TEXTURE does.
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

-- Render a chain+bendiness pair into a dense polyline (flat {x,y,...}).
-- Bind and evaluate MUST go through this so the (t, s) parameterization
-- matches between them. `depth` defaults to 5 → 2^5 + 1 = 33 samples.
local function sampleChain(chain, bendiness, depth)
    local pts = chain
    if #pts == 4 then
        -- 2-node chain: pad with midpoint so Bezier has >=3 control points.
        pts = { pts[1], pts[2], (pts[1] + pts[3]) / 2, (pts[2] + pts[4]) / 2, pts[3], pts[4] }
    end
    local ctrl = doubleControlPoints(pts, bendiness)
    local curve = love.math.newBezierCurve(ctrl)
    return curve:render(depth or 5)
end

-- Return (x, y) at arc-length fraction `t` along `polyline`, offset
-- `s` along the left-normal of the local segment direction. t can be
-- <0 or >1; the first/last segment is extrapolated tangentially so
-- end-of-chain verts recorded with overshoot round-trip exactly.
local function pointOnPolyline(polyline, arcs, total, t, s)
    local target = t * total
    local numSeg = #polyline / 2 - 1
    local seg
    if target <= arcs[1] then
        seg = 1
    elseif target >= arcs[numSeg + 1] then
        seg = numSeg
    else
        seg = numSeg
        for i = 1, numSeg do
            if target <= arcs[i + 1] then
                seg = i
                break
            end
        end
    end
    local ax, ay = polyline[(seg - 1) * 2 + 1], polyline[(seg - 1) * 2 + 2]
    local bx, by = polyline[seg * 2 + 1], polyline[seg * 2 + 2]
    local segLen = arcs[seg + 1] - arcs[seg]
    local u = segLen > 1e-9 and (target - arcs[seg]) / segLen or 0
    local dx, dy = bx - ax, by - ay
    local dlen = math.sqrt(dx * dx + dy * dy)
    local tx = dlen > 1e-9 and dx / dlen or 1
    local ty = dlen > 1e-9 and dy / dlen or 0
    local nx, ny = -ty, tx
    local cx, cy = ax + u * dx, ay + u * dy
    return cx + s * nx, cy + s * ny
end

-- ─── public API ────────────────────────────────────────────────────

-- Resolve a playtime node list (anchors + joints) to a flat world-coord
-- chain { x1, y1, x2, y2, ... }. Skips nodes whose body/joint is gone.
function lib.buildChainFromNodes(nodes)
    local registry = require 'src.registry'
    local mathutils = require 'src.math-utils'
    local NT = require 'src.node-types'
    local chain = {}
    for i = 1, #nodes do
        local n = nodes[i]
        local nx, ny
        if n.type == NT.ANCHOR then
            local f = registry.getSFixtureByID(n.id)
            if f and not f:isDestroyed() then
                local b = f:getBody()
                nx, ny = mathutils.getCenterOfPoints({ b:getWorldPoints(f:getShape():getPoints()) })
            end
        elseif n.type == NT.JOINT then
            local j = registry.getJointByID(n.id)
            if j and not j:isDestroyed() then
                nx, ny = j:getAnchors()
            end
        end
        if nx and ny then
            chain[#chain + 1] = nx
            chain[#chain + 1] = ny
        end
    end
    return chain
end

-- Bind a polygon to a chain at rest pose. Both args are flat world-coord
-- tables: polygon = {x1,y1,x2,y2,...}, chain = {x1,y1,x2,y2,...}.
-- `bendiness` must match what evaluate will use or rest pose drifts — it
-- is captured into the bind so evaluate can default to it.
function lib.bind(polygon, chain, bendiness)
    if type(polygon) ~= 'table' or #polygon < 6 then return nil, 'polygon needs >=6 coords' end
    if type(chain) ~= 'table' or #chain < 4 then return nil, 'chain needs >=4 coords (>=2 points)' end
    bendiness = bendiness or 2

    local dense = sampleChain(chain, bendiness)
    local arcs, total = arcLengths(dense)
    if total < 1e-6 then return nil, 'chain has zero length' end

    local tsPerVert = {}
    for i = 1, #polygon, 2 do
        local t, s = closestOnPolyline(polygon[i], polygon[i + 1], dense, arcs, total)
        tsPerVert[#tsPerVert + 1] = t
        tsPerVert[#tsPerVert + 1] = s
    end

    return { tsPerVert = tsPerVert, bendiness = bendiness }
end

-- Evaluate a bind against new chain positions. Returns flat array of
-- deformed polygon coords (world). Defaults to the bind's captured
-- bendiness — overriding drifts rest pose, which the caller may want
-- when the user is live-tweaking the slider.
function lib.evaluate(spineBind, newChain, bendiness)
    if not spineBind or not spineBind.tsPerVert or #newChain < 4 then return nil end
    bendiness = bendiness or spineBind.bendiness or 2

    local dense = sampleChain(newChain, bendiness)
    local arcs, total = arcLengths(dense)
    if total < 1e-6 then return nil end

    local out = {}
    local ts = spineBind.tsPerVert
    for i = 1, #ts, 2 do
        -- No clamp on t — bind records overshoot past the chain ends
        -- (t < 0 or t > 1) and pointOnPolyline extrapolates tangentially.
        local x, y = pointOnPolyline(dense, arcs, total, ts[i], ts[i + 1])
        out[#out + 1] = x
        out[#out + 1] = y
    end
    return out
end

-- ─── multi-chain (hard assignment) ────────────────────────────────
--
-- Split a flat node list into sub-chains at repeated IDs — the user's
-- convention is to start each chain from a shared root anchor, so the
-- same node ID recurs as a separator. Returns { [1] = { node, ... }, ... }.
-- If no ID repeats, returns a single chain wrapping the whole list.
function lib.splitChainsByRootRepeat(nodes)
    if #nodes < 2 then return { nodes } end
    local seen = {}
    local chains = {}
    local current
    for _, n in ipairs(nodes) do
        if seen[n.id] then
            -- repeat of an already-seen id — start a new chain, and
            -- seed it with this node so it's shared between chains.
            current = { n }
            chains[#chains + 1] = current
        else
            seen[n.id] = true
            if not current then
                current = { n }
                chains[#chains + 1] = current
            else
                current[#current + 1] = n
            end
        end
    end
    return chains
end

-- Resolve a list of node sub-chains (from splitChainsByRootRepeat) to a
-- map { [i] = { x1,y1,x2,y2,... } }. Skips destroyed nodes.
function lib.buildChainsFromNodeLists(nodeLists)
    local out = {}
    for i, list in ipairs(nodeLists) do
        out[i] = lib.buildChainFromNodes(list)
    end
    return out
end

-- Bind a polygon against multiple chains. For each vertex, pick the
-- chain whose dense polyline projects closest (signed perpendicular
-- distance). Store { chain = index, t, s } per vert. Hard assignment —
-- seam triangles whose verts land on different chains will stretch
-- when those chains diverge. Soft blending is a future extension.
--
-- chainsByIdx = { [1] = { x1,y1,x2,y2,... }, [2] = ... }
function lib.bindMultiChain(polygon, chainsByIdx, bendiness)
    if type(polygon) ~= 'table' or #polygon < 6 then return nil, 'polygon needs >=6 coords' end
    bendiness = bendiness or 2

    local dense = {}
    for i, chain in pairs(chainsByIdx) do
        if type(chain) == 'table' and #chain >= 4 then
            local samples = sampleChain(chain, bendiness)
            local arcs, total = arcLengths(samples)
            if total > 1e-6 then
                dense[i] = { samples = samples, arcs = arcs, total = total }
            end
        end
    end
    if not next(dense) then return nil, 'no valid chains' end

    local perVert = {}
    for i = 1, #polygon, 2 do
        local px, py = polygon[i], polygon[i + 1]
        local bestIdx, bestD2, bestT, bestS = nil, math.huge, 0, 0
        for idx, d in pairs(dense) do
            local t, s = closestOnPolyline(px, py, d.samples, d.arcs, d.total)
            local d2 = s * s -- s = sign * sqrt(perp²), so s² == perp²
            if d2 < bestD2 then
                bestD2 = d2; bestIdx = idx; bestT = t; bestS = s
            end
        end
        perVert[#perVert + 1] = { chain = bestIdx, t = bestT, s = bestS }
    end

    return { perVert = perVert, bendiness = bendiness, multi = true }
end

-- Evaluate a multi-chain bind against new chain positions. Each vert is
-- placed on its assigned chain's live Bezier. Returns flat deformed coords.
function lib.evaluateMultiChain(spineBind, chainsByIdx, bendiness)
    if not spineBind or not spineBind.perVert then return nil end
    bendiness = bendiness or spineBind.bendiness or 2

    local dense = {}
    for i, chain in pairs(chainsByIdx) do
        if type(chain) == 'table' and #chain >= 4 then
            local samples = sampleChain(chain, bendiness)
            local arcs, total = arcLengths(samples)
            if total > 1e-6 then
                dense[i] = { samples = samples, arcs = arcs, total = total }
            end
        end
    end

    local out = {}
    for _, v in ipairs(spineBind.perVert) do
        local d = dense[v.chain]
        if d then
            local x, y = pointOnPolyline(d.samples, d.arcs, d.total, v.t, v.s)
            out[#out + 1] = x
            out[#out + 1] = y
        else
            -- chain missing (destroyed node?) — fall back to origin to
            -- avoid crashes; user sees a visible glitch and can rebind.
            out[#out + 1] = 0
            out[#out + 1] = 0
        end
    end
    return out
end

return lib

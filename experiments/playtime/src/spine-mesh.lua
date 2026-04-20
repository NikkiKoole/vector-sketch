-- spine-mesh.lua
--
-- POC for Phase 1 of SPINE-MESH-PLAN.md. Decomposes a ribbon body's mesh
-- verts into (t, s) pairs relative to a rest spine, then evaluates a live
-- Bezier through moving joint anchors to produce deformed verts.
--
-- Not wired into the draw pipeline yet. Intended use:
--
--   local sm = require('src.spine-mesh')
--   local bind = sm.bindFromRibbon(body)                    -- captures rest spine + (t,s) per vert
--   state.spineMeshBind = { body = body, bind = bind }      -- remember for overlay
--   -- (editor-render.lua's overlay pass can then call sm.evaluate to see deformation)
--
-- POC scope: ribbon bodies only (they carry an implicit spine via the top
-- row of thing.vertices — first half of the closed polygon). Traced/custom
-- polygon bodies need an explicit spine source (Phase 3 deals with that).

local lib = {}

local registry = require 'src.registry'
local mathutils = require 'src.math-utils'

-- Return world (x, y) for a node (joint or anchor). Defined early so it's
-- in scope for every function below — avoids the Lua forward-reference
-- trap (local fn defined after its first use resolves to nil global).
local function nodeWorldPos(n)
    local NT = require('src.node-types')
    if n.type == NT.ANCHOR then
        local f = registry.getSFixtureByID(n.id)
        if f then
            local b = f:getBody()
            return mathutils.getCenterOfPoints({ b:getWorldPoints(f:getShape():getPoints()) })
        end
    elseif n.type == NT.JOINT then
        local j = registry.getJointByID(n.id)
        if j and not j:isDestroyed() then
            local x1, y1 = j:getAnchors()
            return x1, y1
        end
    end
    return nil, nil
end

-- Extract the rest spine from a ribbon body's polygon. For a freepath
-- ribbon the closed polygon is [top left→right, bottom right→left]. The
-- real centerline is the pairwise midpoint of top[i] and bottom[i] — use
-- that (NOT the top row alone, which is offset by halfWidth and makes
-- the deformed mesh appear shifted laterally).
local function spineFromRibbon(thing)
    local verts = thing.vertices
    if not verts or #verts < 6 or (#verts % 2) ~= 0 then return nil end
    local totalPts = #verts / 2
    if totalPts % 2 ~= 0 then return nil end
    local perEdge = totalPts / 2
    if perEdge < 2 then return nil end
    local spine = {}
    for i = 1, perEdge do
        local tx = verts[(i - 1) * 2 + 1]
        local ty = verts[(i - 1) * 2 + 2]
        -- bottom is stored reversed: bottom[k] (matching top[k]) is at
        -- polygon index (2*perEdge - k + 1).
        local bIdx = (2 * perEdge - i + 1)
        local bx = verts[(bIdx - 1) * 2 + 1]
        local by = verts[(bIdx - 1) * 2 + 2]
        spine[#spine + 1] = (tx + bx) * 0.5
        spine[#spine + 1] = (ty + by) * 0.5
    end
    return spine
end

-- Cumulative arc length along a polyline. Returns an array of length
-- (numPoints), starting at 0, ending at total length. Used to map a
-- point on a segment to the global arc-length parameter.
local function arcLengths(polyline)
    local out = { 0 }
    local total = 0
    for i = 1, (#polyline / 2) - 1 do
        local ax, ay = polyline[(i - 1) * 2 + 1], polyline[(i - 1) * 2 + 2]
        local bx, by = polyline[i * 2 + 1], polyline[i * 2 + 2]
        local dx, dy = bx - ax, by - ay
        total = total + math.sqrt(dx * dx + dy * dy)
        out[i + 1] = total
    end
    return out, total
end

-- Find the closest point on a polyline to (px, py). Returns (t, s) where
-- t is arc-length-normalised 0..1 and s is signed perpendicular distance
-- (positive = left of the spine direction, negative = right).
local function closestOnPolyline(px, py, polyline, arcs, totalLen)
    local bestD2, bestT, bestS = math.huge, 0, 0
    local numSeg = (#polyline / 2) - 1
    for i = 1, numSeg do
        local ax, ay = polyline[(i - 1) * 2 + 1], polyline[(i - 1) * 2 + 2]
        local bx, by = polyline[i * 2 + 1], polyline[i * 2 + 2]
        local dx, dy = bx - ax, by - ay
        local segLen2 = dx * dx + dy * dy
        if segLen2 < 1e-12 then
            -- degenerate: treat as point
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
                -- signed perpendicular: left of segment direction is positive.
                -- left-normal of (dx, dy) is (-dy, dx). Sign via dot with (qx, qy).
                local nxn = -dy
                local nyn = dx
                local nlen = math.sqrt(nxn * nxn + nyn * nyn)
                local sign = (qx * nxn + qy * nyn) >= 0 and 1 or -1
                bestS = sign * math.sqrt(d2) * (nlen > 0 and 1 or 0)
            end
        end
    end
    return bestT, bestS
end

-- Capture spine + (t, s) per vert from a body AND a list of live nodes.
-- The rest spine is the chain of node world positions at bind time. This
-- guarantees bind and runtime reference the same path — if nodes don't
-- sit on the ribbon's internal midline, the (t, s) values still correctly
-- describe where each vert is relative to the chain the user drew.
-- Works for any polygon shape, not just ribbon. Returns:
--   { spine, arcs, total, tsPerVert, nodeOrder }
-- `nodeOrder` is the ordered node list matching spine control-point order.
function lib.bindFromBodyAndNodes(body, nodes)
    if not body or body:isDestroyed() then return nil end
    local ud = body:getUserData()
    local thing = ud and ud.thing
    if not thing or not thing.vertices then return nil end
    if not nodes or #nodes < 2 then return nil end

    -- Snapshot live node world positions → rest spine.
    local spine = {}
    local validNodes = {}
    for _, n in ipairs(nodes) do
        local wx, wy = nodeWorldPos(n)
        if wx and wy then
            spine[#spine + 1] = wx
            spine[#spine + 1] = wy
            validNodes[#validNodes + 1] = n
        end
    end
    if #spine < 4 then return nil end

    local arcs, total = arcLengths(spine)
    if total < 1e-6 then return nil end

    -- Polygon verts are in thing.vertices — their frame depends on shape
    -- type (ribbon palette ⇒ body-local; freepath ⇒ authoring-world).
    -- Going through body:getWorldPoint after subtracting the polygon
    -- centroid gives us world coords that work either way, matching what
    -- box2d-draw-textured uses elsewhere.
    local cenX, cenY = mathutils.computeCentroid(thing.vertices)
    local ts = {}
    for i = 1, #thing.vertices, 2 do
        local lx = thing.vertices[i] - cenX
        local ly = thing.vertices[i + 1] - cenY
        local wx, wy = body:getWorldPoint(lx, ly)
        local t, s = closestOnPolyline(wx, wy, spine, arcs, total)
        ts[#ts + 1] = t
        ts[#ts + 1] = s
    end

    return { spine = spine, arcs = arcs, total = total, tsPerVert = ts, nodeOrder = validNodes }
end

-- Build a Bezier-friendly control-point list from a node list. Matches
-- what CONNECTED_TEXTURE does (box2d-draw-textured.lua ~1071-1127) so we
-- share the same curve shape. Nodes may be anchors or joints.
local function pointsFromNodes(nodes)
    local NT = require('src.node-types')
    local pts = {}
    for j = 1, #nodes do
        local n = nodes[j]
        if n.type == NT.ANCHOR then
            local f = registry.getSFixtureByID(n.id)
            if f then
                local b = f:getBody()
                local cx, cy = mathutils.getCenterOfPoints({ b:getWorldPoints(f:getShape():getPoints()) })
                pts[#pts + 1] = cx
                pts[#pts + 1] = cy
            end
        elseif n.type == NT.JOINT then
            local j_ = registry.getJointByID(n.id)
            if j_ and not j_:isDestroyed() then
                local x1, y1 = j_:getAnchors()
                pts[#pts + 1] = x1
                pts[#pts + 1] = y1
            end
        end
    end
    return pts
end

-- Evaluate a Love2D Bezier at parameter t ∈ [0, 1], return point + tangent.
-- Tangent via its derivative curve.
local function evalCurve(curve, derivCurve, t)
    local x, y = curve:evaluate(t)
    local dx, dy = derivCurve:evaluate(t)
    local dlen = math.sqrt(dx * dx + dy * dy)
    if dlen < 1e-9 then return x, y, 1, 0 end
    return x, y, dx / dlen, dy / dlen
end

-- Duplicate middle control points N times so a high-degree Bezier
-- hugs them instead of oscillating — matches CONNECTED_TEXTURE.
local function doubleControlPoints(points, dups)
    local n = #points / 2
    if n <= 2 then return points end
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

-- Apply the bind to live node positions: Bezier through nodes, per-vert
-- placement at curve(t) + s * left-normal. Returns flat world-vert array
-- aligned with the original polygon's vert order.
function lib.evaluate(bind, nodes)
    if not bind or not nodes or #nodes < 2 then return nil end
    local pts = pointsFromNodes(nodes)
    -- love.math.newBezierCurve needs at least 2 points; if we only have 2
    -- we pad a midpoint so the curve is degree-2 (same trick CONNECTED_TEXTURE
    -- uses).
    if #pts < 4 then return nil end
    if #pts == 4 then
        pts = { pts[1], pts[2], (pts[1] + pts[3]) / 2, (pts[2] + pts[4]) / 2, pts[3], pts[4] }
    end
    -- Duplicate middles so the Bezier tracks the node chain instead of
    -- smoothing across it into wide oscillations (degree-10 Bezier with
    -- 10 near-collinear control points was doing exactly that).
    pts = doubleControlPoints(pts, 2)
    local curve = love.math.newBezierCurve(pts)
    local deriv = curve:getDerivative()

    local out = {}
    local ts = bind.tsPerVert
    for i = 1, #ts, 2 do
        local t, s = ts[i], ts[i + 1]
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
        local cx, cy, tx, ty = evalCurve(curve, deriv, t)
        -- left-normal of (tx, ty) is (-ty, tx)
        local nx, ny = -ty, tx
        out[#out + 1] = cx + s * nx
        out[#out + 1] = cy + s * ny
    end
    return out
end

-- POC bind. `nodes` is accepted in arbitrary order; we first build a
-- rough "nodes along polygon axis" ordering by projecting each onto a
-- scratch polygon-derived axis, then use the ordered chain itself as
-- the rest spine. This matches the runtime curve exactly by construction.
function lib.debugBind(body, nodes)
    if not body or not nodes or #nodes < 2 then
        return { error = 'need body + ≥2 nodes' }
    end

    -- Step 1: rough ordering. Use polygon-midline (if it's a ribbon) or
    -- the polygon's longest principal axis to get a monotonic order along
    -- the limb. For the POC we can cheat by using polygon-top-row as axis.
    local thing = body:getUserData() and body:getUserData().thing
    if not thing or not thing.vertices then return { error = 'no thing.vertices' } end

    local axis = spineFromRibbon(thing) -- centerline of ribbon polygon; OK as ordering heuristic
    if not axis or #axis < 4 then
        -- Fallback: order by world x+y as a lame projection. Good enough for
        -- POC; real impl needs proper principal-axis.
        local ordered = {}
        for _, n in ipairs(nodes) do
            local wx, wy = nodeWorldPos(n)
            if wx then ordered[#ordered + 1] = { n = n, k = wx + wy } end
        end
        table.sort(ordered, function(a, b) return a.k < b.k end)
        nodes = {}
        for _, e in ipairs(ordered) do nodes[#nodes + 1] = e.n end
    else
        -- Transform axis points from polygon frame to world (for scoring
        -- node positions against them).
        local cenX, cenY = mathutils.computeCentroid(thing.vertices)
        local axisWorld = {}
        for i = 1, #axis, 2 do
            local lx = axis[i] - cenX
            local ly = axis[i + 1] - cenY
            local wx, wy = body:getWorldPoint(lx, ly)
            axisWorld[#axisWorld + 1] = wx
            axisWorld[#axisWorld + 1] = wy
        end
        local axisArcs, axisTotal = arcLengths(axisWorld)
        local ordered = {}
        for _, n in ipairs(nodes) do
            local wx, wy = nodeWorldPos(n)
            if wx then
                local t = select(1, closestOnPolyline(wx, wy, axisWorld, axisArcs, axisTotal))
                ordered[#ordered + 1] = { n = n, t = t }
            end
        end
        table.sort(ordered, function(a, b) return a.t < b.t end)
        nodes = {}
        for _, e in ipairs(ordered) do nodes[#nodes + 1] = e.n end
    end

    -- Step 2: bind, using the ordered nodes as the actual rest spine.
    local bind = lib.bindFromBodyAndNodes(body, nodes)
    if not bind then return { error = 'bindFromBodyAndNodes failed' } end

    _G._spineMeshDebug = { body = body, bind = bind, nodes = nodes }
    return {
        spineLen = bind.total,
        spinePts = #bind.spine / 2,
        numVerts = #bind.tsPerVert / 2,
        numNodes = #nodes,
    }
end

return lib

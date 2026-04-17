-- Addon: Delaunay triangulation with interior Steiner points.
--
-- Purpose: replace `love.math.triangulate` (ear-clipping on the outline only)
-- with a triangulation that (a) produces well-shaped triangles via Delaunay
-- property and (b) includes interior vertices so long spans across the
-- polygon get subdivided — essential for smooth MESHUSERT deformation on
-- concave character silhouettes.
--
-- This is unconstrained Delaunay (Bowyer-Watson) on {outline + Steiner}
-- points, then triangles whose centroid falls outside the polygon are
-- discarded. Good enough for mostly-convex character shapes. For polygons
-- with deep concavities where the outline wraps around, upgrade to proper
-- constrained Delaunay (edge-flip pass to restore outline edges).
--
-- Output format matches what playtime already expects:
--   verts:   flat {x1,y1,x2,y2,...} — outline verts first (preserving input
--            order), then Steiner points appended
--   triIdx:  flat {i1,i2,i3,  i1,i2,i3, ...} 1-based indices into verts
--
-- Caller can then compute UVs per-vert from the same world-rect formula and
-- use triIdx as `data.triangles` directly.

local lib = {}

---------------------------------------------------------------------------
-- Geometry helpers
---------------------------------------------------------------------------

local function pointInPoly(px, py, poly)
    local inside = false
    local n = math.floor(#poly / 2)
    local j = n
    for i = 1, n do
        local xi, yi = poly[(i - 1) * 2 + 1], poly[(i - 1) * 2 + 2]
        local xj, yj = poly[(j - 1) * 2 + 1], poly[(j - 1) * 2 + 2]
        if ((yi > py) ~= (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end
lib.pointInPoly = pointInPoly

-- Unsigned distance from (px,py) to segment (ax,ay)-(bx,by).
local function distToSegment(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local l2 = dx * dx + dy * dy
    if l2 < 1e-12 then
        local ex, ey = px - ax, py - ay
        return math.sqrt(ex * ex + ey * ey)
    end
    local t = ((px - ax) * dx + (py - ay) * dy) / l2
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local cx, cy = ax + dx * t, ay + dy * t
    local ex, ey = px - cx, py - cy
    return math.sqrt(ex * ex + ey * ey)
end

-- Minimum distance from a point to the polygon's outline.
local function distToPolyEdge(px, py, poly)
    local best = math.huge
    local n = math.floor(#poly / 2)
    for i = 1, n do
        local j = (i % n) + 1
        local ax, ay = poly[(i - 1) * 2 + 1], poly[(i - 1) * 2 + 2]
        local bx, by = poly[(j - 1) * 2 + 1], poly[(j - 1) * 2 + 2]
        local d = distToSegment(px, py, ax, ay, bx, by)
        if d < best then best = d end
    end
    return best
end

local function pointInTriangle(px, py, ax, ay, bx, by, cx, cy)
    local d1 = (px - bx) * (ay - by) - (ax - bx) * (py - by)
    local d2 = (px - cx) * (by - cy) - (bx - cx) * (py - cy)
    local d3 = (px - ax) * (cy - ay) - (cx - ax) * (py - ay)
    local hasNeg = (d1 < 0) or (d2 < 0) or (d3 < 0)
    local hasPos = (d1 > 0) or (d2 > 0) or (d3 > 0)
    return not (hasNeg and hasPos)
end

-- Bounding box.
local function bbox(poly)
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    for i = 1, #poly, 2 do
        local x, y = poly[i], poly[i + 1]
        if x < minX then minX = x end
        if y < minY then minY = y end
        if x > maxX then maxX = x end
        if y > maxY then maxY = y end
    end
    return minX, minY, maxX, maxY
end

---------------------------------------------------------------------------
-- Steiner point generation: grid-sampled interior points.
---------------------------------------------------------------------------

-- Returns a flat list {x1,y1,x2,y2,...} of interior points inside the polygon,
-- on a grid with given spacing, and at least `minEdgeDist` pixels from any
-- outline edge (to avoid sliver triangles near the boundary).
function lib.generateSteinerGrid(poly, spacing, minEdgeDist)
    minEdgeDist = minEdgeDist or (spacing * 0.25)
    local minX, minY, maxX, maxY = bbox(poly)
    local pts = {}
    local y = minY + spacing * 0.5
    while y < maxY do
        local x = minX + spacing * 0.5
        -- Stagger every other row for a slightly better triangle shape
        -- (hexagonal-ish packing).
        local rowOffset = (math.floor((y - minY) / spacing) % 2 == 1) and (spacing * 0.5) or 0
        while x < maxX do
            local px = x + rowOffset
            if pointInPoly(px, y, poly) and distToPolyEdge(px, y, poly) >= minEdgeDist then
                pts[#pts + 1] = px
                pts[#pts + 1] = y
            end
            x = x + spacing
        end
        y = y + spacing
    end
    return pts
end

---------------------------------------------------------------------------
-- Bowyer-Watson Delaunay triangulation.
---------------------------------------------------------------------------

-- In-circumcircle test using the determinant form. Returns true if point p
-- is inside the circumcircle of counter-clockwise triangle (a, b, c).
local function inCircumcircle(px, py, ax, ay, bx, by, cx, cy)
    local adx, ady = ax - px, ay - py
    local bdx, bdy = bx - px, by - py
    local cdx, cdy = cx - px, cy - py
    local ad = adx * adx + ady * ady
    local bd = bdx * bdx + bdy * bdy
    local cd = cdx * cdx + cdy * cdy
    -- This determinant is positive iff p is inside the CCW circumcircle.
    return (ad * (bdx * cdy - cdx * bdy)
        - bd * (adx * cdy - cdx * ady)
        + cd * (adx * bdy - bdx * ady)) > 0
end

-- Force (a,b,c) into counter-clockwise order; returns indices in CCW order.
local function orientCCW(ax, ay, bx, by, cx, cy, ia, ib, ic)
    local cross = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
    if cross < 0 then
        return ia, ic, ib
    end
    return ia, ib, ic
end

-- Triangulate N points (flat {x,y,x,y,...}). Returns flat index list
-- {i1,i2,i3, i1,i2,i3, ...} 1-based into the input.
--
-- Classic Bowyer-Watson: bootstrap with a huge super-triangle enclosing
-- all points, insert each point, remove triangles whose circumcircle
-- contains it, re-triangulate the resulting hole. Finally drop any
-- triangles sharing a vertex with the super-triangle.
local function bowyerWatson(points)
    local n = math.floor(#points / 2)
    if n < 3 then return {} end

    -- Super-triangle: one that comfortably contains all points. Use a big
    -- multiplier on the bounding box so no input point ever lies on the
    -- super-triangle's circumcircle edge.
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    for i = 1, n do
        local x, y = points[(i - 1) * 2 + 1], points[(i - 1) * 2 + 2]
        if x < minX then minX = x end
        if y < minY then minY = y end
        if x > maxX then maxX = x end
        if y > maxY then maxY = y end
    end
    local dx, dy = maxX - minX, maxY - minY
    local dmax = math.max(dx, dy) * 1000 + 1
    local midX, midY = (minX + maxX) * 0.5, (minY + maxY) * 0.5
    -- Append super-triangle verts to the point list at indices n+1..n+3.
    local verts = {}
    for i = 1, #points do verts[i] = points[i] end
    local stI1 = n + 1
    local stI2 = n + 2
    local stI3 = n + 3
    verts[(stI1 - 1) * 2 + 1] = midX - 20 * dmax
    verts[(stI1 - 1) * 2 + 2] = midY - dmax
    verts[(stI2 - 1) * 2 + 1] = midX
    verts[(stI2 - 1) * 2 + 2] = midY + 20 * dmax
    verts[(stI3 - 1) * 2 + 1] = midX + 20 * dmax
    verts[(stI3 - 1) * 2 + 2] = midY - dmax

    -- Each triangle is {a, b, c} — 1-based indices into verts. Kept in CCW
    -- order after orientCCW.
    local triangles = {}
    local function vert(i) return verts[(i - 1) * 2 + 1], verts[(i - 1) * 2 + 2] end
    do
        local ax, ay = vert(stI1)
        local bx, by = vert(stI2)
        local cx, cy = vert(stI3)
        local ia, ib, ic = orientCCW(ax, ay, bx, by, cx, cy, stI1, stI2, stI3)
        triangles[1] = { ia, ib, ic }
    end

    -- Insert each input point.
    for pi = 1, n do
        local px, py = verts[(pi - 1) * 2 + 1], verts[(pi - 1) * 2 + 2]

        -- Find "bad" triangles: those whose circumcircle contains p.
        local bad = {}
        local keep = {}
        for _, tri in ipairs(triangles) do
            local ax, ay = vert(tri[1])
            local bx, by = vert(tri[2])
            local cx, cy = vert(tri[3])
            if inCircumcircle(px, py, ax, ay, bx, by, cx, cy) then
                bad[#bad + 1] = tri
            else
                keep[#keep + 1] = tri
            end
        end

        -- Build the polygon hole: edges of bad triangles that are NOT shared
        -- with another bad triangle. Use a canonical key (min..max) per edge.
        local edgeCount = {}
        local function edgeKey(a, b)
            if a < b then return a .. ',' .. b end
            return b .. ',' .. a
        end
        local function addEdge(a, b)
            local k = edgeKey(a, b)
            edgeCount[k] = (edgeCount[k] or 0) + 1
        end
        for _, tri in ipairs(bad) do
            addEdge(tri[1], tri[2])
            addEdge(tri[2], tri[3])
            addEdge(tri[3], tri[1])
        end
        -- Boundary edges: count == 1. Rebuild as {a, b} pairs for iteration.
        local hole = {}
        for _, tri in ipairs(bad) do
            local function maybeAdd(a, b)
                if edgeCount[edgeKey(a, b)] == 1 then
                    hole[#hole + 1] = { a, b }
                end
            end
            maybeAdd(tri[1], tri[2])
            maybeAdd(tri[2], tri[3])
            maybeAdd(tri[3], tri[1])
        end

        -- Fan-connect p to every boundary edge to form new triangles.
        triangles = keep
        for _, e in ipairs(hole) do
            local ax, ay = vert(e[1])
            local bx, by = vert(e[2])
            local ia, ib, ic = orientCCW(ax, ay, bx, by, px, py, e[1], e[2], pi)
            triangles[#triangles + 1] = { ia, ib, ic }
        end
    end

    -- Drop triangles that touch any super-triangle vertex.
    local result = {}
    for _, tri in ipairs(triangles) do
        if tri[1] < stI1 and tri[2] < stI1 and tri[3] < stI1 then
            result[#result + 1] = tri[1]
            result[#result + 1] = tri[2]
            result[#result + 1] = tri[3]
        end
    end
    return result
end
lib.bowyerWatson = bowyerWatson

---------------------------------------------------------------------------
-- Main entry: triangulate polygon (outline verts) with interior Steiner
-- points. Returns combined {verts, triIndices} where verts has all outline
-- verts first (preserving input order so UVs stay aligned for outline
-- vertices) followed by Steiner points.
---------------------------------------------------------------------------

-- True if open segments (p1,p2) and (q1,q2) properly cross (not just touch
-- at a shared endpoint). Uses the four orientation-sign test with a small
-- tolerance; colinear overlaps and shared-endpoint touches return false so
-- outline edges that coincide with a triangle edge don't get flagged.
local function segmentsProperlyCross(p1x, p1y, p2x, p2y, q1x, q1y, q2x, q2y)
    local function orient(ax, ay, bx, by, cx, cy)
        return (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
    end
    local EPS = 1e-6
    local d1 = orient(q1x, q1y, q2x, q2y, p1x, p1y)
    local d2 = orient(q1x, q1y, q2x, q2y, p2x, p2y)
    local d3 = orient(p1x, p1y, p2x, p2y, q1x, q1y)
    local d4 = orient(p1x, p1y, p2x, p2y, q2x, q2y)
    if ((d1 > EPS and d2 < -EPS) or (d1 < -EPS and d2 > EPS)) and
       ((d3 > EPS and d4 < -EPS) or (d3 < -EPS and d4 > EPS)) then
        return true
    end
    return false
end

-- Filter: keep only triangles that (a) have their centroid inside the
-- polygon AND (b) have no edge properly crossing any polygon outline edge.
--
-- The edge-cross test is what catches "bridging" triangles across concave
-- regions like armpits / crotches: unconstrained Delaunay will happily span
-- a triangle from one side of a V-shaped notch to the other, and the
-- centroid can still land inside the polygon's solid mass. Without this
-- test those bridge triangles pass the centroid filter and render as long
-- skinny triangles closing off the concavity.
--
-- Proper constrained Delaunay would fix this by edge-flipping until every
-- outline edge is present; this is a simpler "drop the offenders, leave a
-- hole" approximation. The hole is harmless since that space is outside
-- the polygon's silhouette anyway.
local function filterInsidePoly(triIndices, verts, poly, numPolyVerts)
    local out = {}
    local n = math.floor(#poly / 2)
    numPolyVerts = numPolyVerts or n

    -- Returns true if vertex index i is a polygon boundary vertex.
    local function isPolyVert(i) return i <= numPolyVerts end

    -- Returns true if i and j are adjacent polygon boundary vertices.
    local function areAdjacent(i, j)
        if not isPolyVert(i) or not isPolyVert(j) then return false end
        local diff = math.abs(i - j)
        return diff == 1 or diff == numPolyVerts - 1
    end

    for j = 1, #triIndices, 3 do
        local i1, i2, i3 = triIndices[j], triIndices[j + 1], triIndices[j + 2]
        local x1, y1 = verts[(i1 - 1) * 2 + 1], verts[(i1 - 1) * 2 + 2]
        local x2, y2 = verts[(i2 - 1) * 2 + 1], verts[(i2 - 1) * 2 + 2]
        local x3, y3 = verts[(i3 - 1) * 2 + 1], verts[(i3 - 1) * 2 + 2]
        local cx, cy = (x1 + x2 + x3) / 3, (y1 + y2 + y3) / 3
        if pointInPoly(cx, cy, poly) then
            local crosses = false
            -- Edge-cross test: catches diagonals that properly cross a poly edge.
            for k = 1, n do
                local m = (k % n) + 1
                local ax, ay = poly[(k - 1) * 2 + 1], poly[(k - 1) * 2 + 2]
                local bx, by = poly[(m - 1) * 2 + 1], poly[(m - 1) * 2 + 2]
                if segmentsProperlyCross(x1, y1, x2, y2, ax, ay, bx, by) or
                   segmentsProperlyCross(x2, y2, x3, y3, ax, ay, bx, by) or
                   segmentsProperlyCross(x3, y3, x1, y1, ax, ay, bx, by) then
                    crosses = true
                    break
                end
            end
            -- Diagonal test: for edges connecting two non-adjacent polygon
            -- boundary vertices, the midpoint must be inside the polygon.
            -- These edges don't properly cross any poly edge (shared endpoints)
            -- but can bridge concave notches. Safe to test midpoint directly
            -- since non-adjacent poly verts can't place the midpoint ON the boundary.
            if not crosses then
                local edges = {{i1,i2,x1,y1,x2,y2},{i2,i3,x2,y2,x3,y3},{i3,i1,x3,y3,x1,y1}}
                for _, e in ipairs(edges) do
                    if isPolyVert(e[1]) and isPolyVert(e[2]) and not areAdjacent(e[1], e[2]) then
                        if not pointInPoly((e[3]+e[5])/2, (e[4]+e[6])/2, poly) then
                            crosses = true
                            break
                        end
                    end
                end
            end
            if not crosses then
                out[#out + 1] = i1
                out[#out + 1] = i2
                out[#out + 1] = i3
            end
        end
    end
    return out
end

-- Returns (mergedVerts, triIndices). spacing in world-space units; auto-
-- picks a reasonable default based on polygon bbox if not given.
-- extraPoints: optional flat {x,y,x,y,...} array of additional Steiner points
-- (e.g. centroids of previously selected triangles for local refinement).
function lib.triangulatePolyWithSteiner(polyVerts, spacing, extraPoints)
    if not spacing then
        local minX, minY, maxX, maxY = bbox(polyVerts)
        local diag = math.sqrt((maxX - minX) ^ 2 + (maxY - minY) ^ 2)
        spacing = math.max(20, diag / 20)
    end
    local steiner = lib.generateSteinerGrid(polyVerts, spacing)
    local merged = {}
    for i = 1, #polyVerts do merged[i] = polyVerts[i] end
    for i = 1, #steiner do merged[#merged + 1] = steiner[i] end
    if extraPoints then
        for i = 1, #extraPoints do merged[#merged + 1] = extraPoints[i] end
    end
    local numPolyVerts = math.floor(#polyVerts / 2)
    -- If no Steiner points were added, Bowyer-Watson on just the polygon verts
    -- will bridge concavities. Fall back to love ear-clip which always correct.
    if #merged == #polyVerts then
        local ok, loveTris = pcall(love.math.triangulate, polyVerts)
        if ok and loveTris and #loveTris > 0 then
            local indices = {}
            local tolSq = 1.0
            for _, tri in ipairs(loveTris) do
                for k = 0, 2 do
                    local tx, ty = tri[k*2+1], tri[k*2+2]
                    local best, bestD = nil, math.huge
                    for vi = 1, numPolyVerts do
                        local dx = polyVerts[(vi-1)*2+1] - tx
                        local dy = polyVerts[(vi-1)*2+2] - ty
                        local d = dx*dx + dy*dy
                        if d < bestD then bestD = d; best = vi end
                    end
                    if best and bestD <= tolSq then indices[#indices+1] = best end
                end
            end
            if #indices > 0 then return polyVerts, indices end
        end
    end
    local triIndices = bowyerWatson(merged)
    triIndices = filterInsidePoly(triIndices, merged, polyVerts, numPolyVerts)
    return merged, triIndices
end

---------------------------------------------------------------------------
-- Refined triangulation: ear-clip base + centroid subdivision.
--
-- Alternative to triangulatePolyWithSteiner. Starts from love.math.triangulate
-- (always covers the full polygon — no boundary erosion) then repeatedly splits
-- triangles larger than spacing² by inserting their centroid, until all
-- triangles are small enough. extraPoints are inserted into the triangulation
-- before the subdivision pass (used by "split selected").
---------------------------------------------------------------------------
function lib.triangulatePolyRefined(polyVerts, spacing, extraPoints)
    if not spacing then
        local minX, minY, maxX, maxY = bbox(polyVerts)
        local diag = math.sqrt((maxX - minX) ^ 2 + (maxY - minY) ^ 2)
        spacing = math.max(20, diag / 20)
    end
    local numPolyVerts = math.floor(#polyVerts / 2)

    local ok, loveTris = pcall(love.math.triangulate, polyVerts)
    if not ok or not loveTris or #loveTris == 0 then return polyVerts, {} end

    -- Vertex pool: polygon verts first (preserves UV index alignment).
    local verts = {}
    for i = 1, #polyVerts do verts[i] = polyVerts[i] end
    local function getXY(i) return verts[(i-1)*2+1], verts[(i-1)*2+2] end
    local function addVert(x, y)
        verts[#verts+1] = x; verts[#verts+1] = y
        return math.floor(#verts / 2)
    end

    -- Convert love coord-triangles → {i1,i2,i3} tables referencing verts.
    local tolSq = 0.01
    local function findPolyIdx(x, y)
        for i = 1, numPolyVerts do
            local dx = verts[(i-1)*2+1] - x
            local dy = verts[(i-1)*2+2] - y
            if dx*dx + dy*dy <= tolSq then return i end
        end
        return nil
    end
    local tris = {}
    for _, tri in ipairs(loveTris) do
        local t = {}
        local valid = true
        for k = 0, 2 do
            local idx = findPolyIdx(tri[k*2+1], tri[k*2+2])
            if not idx then valid = false; break end
            t[k+1] = idx
        end
        if valid then tris[#tris+1] = t end
    end
    if #tris == 0 then return polyVerts, {} end

    -- Insert extraPoints (e.g. "split selected" centroids) into the
    -- triangulation before the area-based subdivision pass.
    if extraPoints then
        for ep = 1, #extraPoints, 2 do
            local px, py = extraPoints[ep], extraPoints[ep+1]
            for j = 1, #tris do
                local tri = tris[j]
                local x1,y1 = getXY(tri[1])
                local x2,y2 = getXY(tri[2])
                local x3,y3 = getXY(tri[3])
                if pointInTriangle(px, py, x1,y1, x2,y2, x3,y3) then
                    local pi = addVert(px, py)
                    table.remove(tris, j)
                    tris[#tris+1] = {tri[1], tri[2], pi}
                    tris[#tris+1] = {tri[2], tri[3], pi}
                    tris[#tris+1] = {tri[3], tri[1], pi}
                    break
                end
            end
        end
    end

    -- Longest-edge bisection: find each oversized triangle's longest edge,
    -- insert its midpoint, split into 2. The neighbor sharing that edge is
    -- also split at the same midpoint — no T-junctions.
    local threshold = spacing * spacing
    local function eKey(a, b) return a < b and (a .. ',' .. b) or (b .. ',' .. a) end
    for _ = 1, 30 do
        -- Build edge→triangle adjacency for this pass.
        local edgeAdj = {}
        for j, tri in ipairs(tris) do
            for e = 1, 3 do
                local a, b = tri[e], tri[e % 3 + 1]
                local k = eKey(a, b)
                if not edgeAdj[k] then edgeAdj[k] = {} end
                edgeAdj[k][#edgeAdj[k] + 1] = j
            end
        end

        -- For each oversized triangle find its longest edge and insert midpoint.
        local edgeMid = {}
        for _, tri in ipairs(tris) do
            local x1,y1 = getXY(tri[1]); local x2,y2 = getXY(tri[2]); local x3,y3 = getXY(tri[3])
            local area = math.abs((x2-x1)*(y3-y1) - (x3-x1)*(y2-y1)) * 0.5
            if area > threshold then
                local e12 = (x2-x1)^2+(y2-y1)^2
                local e23 = (x3-x2)^2+(y3-y2)^2
                local e31 = (x1-x3)^2+(y1-y3)^2
                local la, lb
                if e12 >= e23 and e12 >= e31 then la,lb = tri[1],tri[2]
                elseif e23 >= e31 then la,lb = tri[2],tri[3]
                else la,lb = tri[3],tri[1] end
                local k = eKey(la, lb)
                if not edgeMid[k] then
                    local ax,ay = getXY(la); local bx,by = getXY(lb)
                    edgeMid[k] = addVert((ax+bx)*0.5, (ay+by)*0.5)
                end
            end
        end

        if not next(edgeMid) then break end

        -- Split every triangle that touches a bisected edge (covers both the
        -- original oversized triangle AND its neighbor automatically).
        local newTris = {}
        for _, tri in ipairs(tris) do
            local sa, sb, mi
            for e = 1, 3 do
                local a, b = tri[e], tri[e % 3 + 1]
                mi = edgeMid[eKey(a, b)]
                if mi then sa, sb = a, b; break end
            end
            if mi then
                local c
                for _, v in ipairs(tri) do if v ~= sa and v ~= sb then c = v; break end end
                newTris[#newTris+1] = {sa, mi, c}
                newTris[#newTris+1] = {mi, sb, c}
            else
                newTris[#newTris+1] = tri
            end
        end
        tris = newTris
    end

    local triIdx = {}
    for _, tri in ipairs(tris) do
        triIdx[#triIdx+1] = tri[1]
        triIdx[#triIdx+1] = tri[2]
        triIdx[#triIdx+1] = tri[3]
    end
    return verts, triIdx
end

---------------------------------------------------------------------------
-- High-level helper: compute RESOURCE mesh data (verts, UVs, triangles)
-- in either `basic` or `cdt` mode. Called from io.lua on scene load, from
-- the RESOURCE UI when it's selected, and from the toggle-triangulation
-- button on MESHUSERT. Keeps the mesh-build policy in one place.
---------------------------------------------------------------------------

-- Ensures `ud.extra` on a RESOURCE fixture has consistent `meshVertices`,
-- `uvs`, and `triangles`. The caller is expected to have the backdrop rect
-- resolved already (bd with x/y/w/h in world space).
--
-- Returns true on success, false otherwise (missing data, triangulation
-- failed, etc.).
function lib.computeResourceMesh(ud, body, bd, mode, spacing, mathutils)
    if not (ud and ud.extra and body and bd) then return false end
    local bodyUD = body:getUserData()
    if not (bodyUD and bodyUD.thing and bodyUD.thing.vertices) then return false end
    local origVerts = bodyUD.thing.vertices

    local meshVerts, triIndices
    if mode == 'cdt' then
        meshVerts, triIndices = lib.triangulatePolyWithSteiner(origVerts, spacing, ud.extra.extraSteiner)
        if not triIndices or #triIndices == 0 then
            mode = 'basic'
            meshVerts = origVerts
        end
    elseif mode == 'refined' then
        meshVerts, triIndices = lib.triangulatePolyRefined(origVerts, spacing, ud.extra.extraSteiner)
        if not triIndices or #triIndices == 0 then
            mode = 'basic'
            meshVerts = origVerts
        end
    end
    if mode ~= 'cdt' and mode ~= 'refined' then
        meshVerts = origVerts
        triIndices = mathutils and mathutils.triangulateToIndices(origVerts) or nil
    end
    if not triIndices or #triIndices == 0 then return false end

    -- UV mapping: map each vertex to its actual world position on the
    -- backdrop. thing.vertices are in authoring-world space (frozen at
    -- creation time); the body may have been moved since. To get the
    -- vertex's current world position we compute:
    --   body-local = vert - computeCentroid(verts)     [same as fixture creation]
    --   world      = body:getWorldPoint(body-local)    [handles position + rotation]
    -- Then UV = (world - backdrop_corner) / backdrop_size.
    local mathutils2 = mathutils or require('src.math-utils')
    local centX, centY = mathutils2.computeCentroid(origVerts)
    local bdW, bdH = bd.w, bd.h

    local uvs = {}
    for i = 1, #meshVerts, 2 do
        local lx = meshVerts[i] - centX
        local ly = meshVerts[i + 1] - centY
        local wx, wy = body:getWorldPoint(lx, ly)
        uvs[#uvs + 1] = (wx - bd.x) / bdW
        uvs[#uvs + 1] = (wy - bd.y) / bdH
    end

    ud.extra.uvs = uvs
    ud.extra.triangles = triIndices
    -- Triangle-group assignments are index-based; retriangulating
    -- invalidates them. Drop so painter starts fresh.
    ud.extra.triangleGroups = nil
    ud.extra.triangleBones = nil
    ud.extra.triangleOrderDirty = false
    -- Only store meshVertices when it differs from the polygon's verts
    -- (saves data + lets legacy paths pick the polygon source directly).
    if mode == 'cdt' or mode == 'refined' then
        ud.extra.meshVertices = meshVerts
    else
        ud.extra.meshVertices = nil
    end
    ud.extra.triangulationMode = mode
    return true
end

return lib

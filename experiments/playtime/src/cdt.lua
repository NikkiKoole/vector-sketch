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

-- Returns (mergedVerts, triIndices). extraPoints: optional flat
-- {x,y,x,y,...} array of user-placed Steiner points in body-local coords.
-- With no extraPoints, falls back to love's ear-clip (always correct for
-- the outline; avoids Bowyer-Watson bridging concavities).
function lib.triangulatePolyWithSteiner(polyVerts, extraPoints)
    local merged = {}
    for i = 1, #polyVerts do merged[i] = polyVerts[i] end
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
-- High-level helper: compute RESOURCE mesh data (verts, UVs, triangles).
-- Mode is auto-derived from body state: ribbons → strip topology; bodies
-- with user-placed Steiner points → authored Delaunay; otherwise basic
-- ear-clip on the outline. Called from io.lua on scene load and from the
-- RESOURCE/MESHUSERT UI. Keeps the mesh-build policy in one place.
---------------------------------------------------------------------------

-- Ensures `ud.extra` on a RESOURCE fixture has consistent `meshVertices`,
-- `uvs`, and `triangles`. The caller is expected to have the backdrop rect
-- resolved already (bd with x/y/w/h in world space).
--
-- Returns true on success, false otherwise (missing data, triangulation
-- failed, etc.).
-- Ribbon polygons from freepath are stored as [top-left-to-right,
-- bottom-right-to-left]. A ribbon with N ribs has 2N points: top row
-- indices 1..N, bottom row indices N+1..2N (reversed). This emits
-- rib-to-rib diagonal triangles — the clean strip topology that
-- `shapes.triangulateRibbon` produces, but as 1-based indices into the
-- polygon vertex array rather than packed coordinates.
local function ribbonStripIndices(polyVerts)
    local total = #polyVerts / 2
    if total < 4 or (total % 2) ~= 0 then return nil end
    local perEdge = total / 2
    local tris = {}
    for i = 1, perEdge - 1 do
        local t1 = i
        local t2 = i + 1
        local b1 = 2 * perEdge - i + 1
        local b2 = 2 * perEdge - i
        tris[#tris + 1] = t1; tris[#tris + 1] = b1; tris[#tris + 1] = t2
        tris[#tris + 1] = t2; tris[#tris + 1] = b1; tris[#tris + 1] = b2
    end
    return tris
end

function lib.computeResourceMesh(ud, body, bd, mathutils)
    if not (ud and ud.extra and body and bd) then return false end
    local bodyUD = body:getUserData()
    if not (bodyUD and bodyUD.thing and bodyUD.thing.vertices) then return false end
    local origVerts = bodyUD.thing.vertices

    -- Operate in body-local throughout. Convert polygon verts to body-local
    -- up front (subtract the centroid that collision fixtures were also
    -- built from), and read Steiner points from the body (thing.extraSteiner
    -- is already body-local). The rest of the pipeline returns body-local
    -- meshVerts. UV mapping just applies the body's current world transform.
    local mathutils2 = mathutils or require('src.math-utils')
    local centX, centY = mathutils2.computeCentroid(origVerts)
    local localPolyVerts = {}
    for i = 1, #origVerts, 2 do
        localPolyVerts[i] = origVerts[i] - centX
        localPolyVerts[i + 1] = origVerts[i + 1] - centY
    end
    local extraSteiner = bodyUD.thing.extraSteiner

    -- Mode is auto-derived from body state:
    --   ribbon shapeType → 'strip' (rib-to-rib diagonals, perpendicular to
    --                      the bone axis; ear-clip would deform badly under
    --                      multi-bone skinning).
    --   extraSteiner present → 'authored' (outline + user-placed points).
    --   otherwise → 'basic' (love's ear-clip on the outline).
    local isRibbon = bodyUD.thing.shapeType == 'ribbon'
    local hasSteiner = extraSteiner and #extraSteiner >= 2

    local mode, meshVerts, triIndices
    if isRibbon then
        triIndices = ribbonStripIndices(localPolyVerts)
        if triIndices and #triIndices > 0 then
            meshVerts = localPolyVerts
            mode = 'strip'
        end
    end
    if not triIndices or #triIndices == 0 then
        if hasSteiner then
            meshVerts, triIndices = lib.triangulatePolyWithSteiner(localPolyVerts, extraSteiner)
            if triIndices and #triIndices > 0 then mode = 'authored' end
        end
        if not triIndices or #triIndices == 0 then
            mode = 'basic'
            meshVerts = localPolyVerts
            triIndices = mathutils and mathutils.triangulateToIndices(localPolyVerts) or nil
        end
    end
    if not triIndices or #triIndices == 0 then return false end

    -- UV mapping: meshVerts are in body-local, so applying the body's
    -- current world transform gives us the world-space sample location
    -- on the backdrop. The backdrop is drawn at (bd.x, bd.y) with
    -- bd.scale (see main.lua drawOneBackdrop), so its on-screen size
    -- is bd.w*scale × bd.h*scale — divide by that to get normalized UV.
    local bdScale = bd.scale or 1
    local bdW, bdH = bd.w * bdScale, bd.h * bdScale
    local uvs = {}
    for i = 1, #meshVerts, 2 do
        local wx, wy = body:getWorldPoint(meshVerts[i], meshVerts[i + 1])
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
    -- Stored in body-local. The draw path normalizes with makePolygonRelativeToCenter
    -- so it doesn't care whether meshVerts arrives body-local or authoring-world
    -- (legacy saves).
    if mode == 'authored' then
        ud.extra.meshVertices = meshVerts
    else
        ud.extra.meshVertices = nil
    end
    ud.extra.triangulationMode = mode
    return true
end

return lib

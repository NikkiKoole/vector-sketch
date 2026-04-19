-- strip-merge.lua
--
-- Merges N ribbon bodies' strip triangulations into a single mesh, expressed
-- in the first body's local frame. This is the core geometry primitive for
-- Goal 4 (MESH-DEFORM-PLAN.md): combine separately-authored freepath strips
-- into one mesh whose triangles are already bone-axis-aligned by construction.
--
-- What this does: concat + frame-transform + junction bridging. What this
-- does NOT do yet: UV mapping, sfixture creation. Those layer on top.
--
-- Usage (from bridge /eval):
--   local merge = require('src.strip-merge')
--   local result = merge.merge({42, 43})
--   local result = merge.mergeAndBridge({42, 43}, { threshold = 40 })
--   return { verts = #result.verts/2, tris = #result.tris/3, meta = result.meta }

local lib = {}

local registry = require 'src.registry'
local ST = require 'src.shape-types'
local mathutils = require 'src.math-utils'

-- Ribbon polygons are stored as [top-left-to-right, bottom-right-to-left]
-- (closed polygon winding). For a ribbon with N ribs, the flat vertex array
-- has 2N points: indices 1..N are the top row (left→right), indices N+1..2N
-- are the bottom row (right→left).
--
-- This builds triangle indices directly into that same flat vertex array —
-- no coordinate copying, so appending to a combined array just needs a
-- single index offset.
local function triangulateRibbonIndexed(polyVerts, vertOffset)
    local totalPoints = #polyVerts / 2
    assert(totalPoints % 2 == 0,
        'ribbon polygon must have even vert count, got ' .. tostring(totalPoints))
    local perEdge = totalPoints / 2

    local tris = {}
    for i = 1, perEdge - 1 do
        local t1 = vertOffset + i
        local t2 = vertOffset + (i + 1)
        -- bottom is stored reversed: bottom[k] (left→right) = poly[2*perEdge - k + 1]
        local b1 = vertOffset + (2 * perEdge - i + 1)
        local b2 = vertOffset + (2 * perEdge - i)

        -- Quad (t1, t2, b2, b1) → two triangles, winding matches shapes.triangulateRibbon.
        tris[#tris + 1] = t1
        tris[#tris + 1] = b1
        tris[#tris + 1] = t2

        tris[#tris + 1] = t2
        tris[#tris + 1] = b1
        tris[#tris + 1] = b2
    end
    return tris
end

-- Merge a list of ribbon body IDs into one mesh in the first body's local frame.
-- Returns { verts, tris, meta } on success, or { error = '...' } on failure.
--
-- verts: flat x,y,x,y,... in bodyIds[1]'s local space
-- tris: flat triangle index array (1-based), 3 indices per tri, indexing into verts
-- meta: per-ribbon { bodyId, firstVert, vertCount, firstTri, triCount } — useful
--       later for bone auto-assignment (every tri knows which ribbon it came from)
function lib.merge(bodyIds)
    if not bodyIds or #bodyIds < 1 then
        return { error = 'merge: need at least one body id' }
    end

    local hostBody = registry.getBodyByID(bodyIds[1])
    if not hostBody or hostBody:isDestroyed() then
        return { error = 'merge: host body (id ' .. tostring(bodyIds[1]) .. ') missing or destroyed' }
    end

    local combined = { verts = {}, tris = {}, meta = {} }

    for ribbonIndex, id in ipairs(bodyIds) do
        local body = registry.getBodyByID(id)
        if not body or body:isDestroyed() then
            return { error = 'merge: body id ' .. tostring(id) .. ' missing or destroyed' }
        end
        local thing = body:getUserData() and body:getUserData().thing
        if not thing or thing.shapeType ~= ST.RIBBON then
            return { error = 'merge: body id ' .. tostring(id) .. ' is not a RIBBON shape' }
        end
        if not thing.vertices or #thing.vertices < 6 then
            return { error = 'merge: body id ' .. tostring(id) .. ' has no/invalid vertices' }
        end

        local vertOffset = #combined.verts / 2
        local triOffset = #combined.tris / 3

        -- `thing.vertices` is authoring-world coords, but the RIBBON renderer
        -- treats `vert - centroid(thing.vertices)` as body-local (see
        -- shapes.lua: ST.RIBBON). For curved paths that centroid differs
        -- from the body position, producing a constant offset between raw
        -- verts and rendered geometry. Match the render frame: subtract the
        -- polygon centroid, then apply the body's current transform. This
        -- also makes the overlay follow moved bodies correctly.
        local cenX, cenY = mathutils.computeCentroid(thing.vertices)
        for i = 1, #thing.vertices, 2 do
            local bodyLx = thing.vertices[i] - cenX
            local bodyLy = thing.vertices[i + 1] - cenY
            local wx, wy = body:getWorldPoint(bodyLx, bodyLy)
            local tx, ty = hostBody:getLocalPoint(wx, wy)
            combined.verts[#combined.verts + 1] = tx
            combined.verts[#combined.verts + 1] = ty
        end

        local ribTris = triangulateRibbonIndexed(thing.vertices, vertOffset)
        for i = 1, #ribTris do
            combined.tris[#combined.tris + 1] = ribTris[i]
        end

        combined.meta[ribbonIndex] = {
            bodyId = id,
            firstVert = vertOffset + 1,
            vertCount = #thing.vertices / 2,
            firstTri = triOffset + 1,
            triCount = #ribTris / 3,
        }
    end

    return combined
end

-- -- bridging --------------------------------------------------------------

-- Given a ribbon's meta (from a merge result), return the two vert indices
-- that make up either the 'start' or 'end' rib of that ribbon. Ribbon layout:
-- first N/2 verts are the top row (left→right), next N/2 are the bottom row
-- (right→left). The start-rib is at path[1]; the end-rib is at path[N].
local function ribPair(m, which)
    local perEdge = m.vertCount / 2
    if which == 'start' then
        return m.firstVert, m.firstVert + m.vertCount - 1
    else
        return m.firstVert + perEdge - 1, m.firstVert + perEdge
    end
end

local function vertXY(verts, idx)
    return verts[(idx - 1) * 2 + 1], verts[(idx - 1) * 2 + 2]
end

-- Walks each ribbon's two end-ribs and finds the nearest *foreign* vertex to
-- each of its two points. If both distances are within `threshold`, emits two
-- triangles stitching the arriving rib to those two foreign verts. Appended
-- triangles are tracked in `result.bridgeFirstTri` / `bridgeTriCount` so the
-- overlay can color them distinctly.
--
-- Handles both junction cases uniformly:
-- * **End-to-end** (elbow/knee): nearest foreign verts are the other ribbon's
--   matching end-rib points; bridge tris form a thin quad that hides the seam.
-- * **T-junction** (shoulder/hip): nearest foreign verts are two adjacent
--   points on the other ribbon's side boundary; bridge tris fan-fill the gap.
--
-- Naive and per-ribbon; duplicates are possible if the same junction is
-- detected from both sides (A's start-rib sees B's end-rib, *and* vice versa).
-- Acceptable for a first cut — overlaps render fine; clean up later if needed.
function lib.buildBridges(combined, opts)
    opts = opts or {}
    local threshold = opts.threshold or 40
    local tSq = threshold * threshold

    local bridgeTris = {}
    local junctions = {}

    for r, m in ipairs(combined.meta) do
        for _, which in ipairs({ 'start', 'end' }) do
            local iA1, iA2 = ribPair(m, which)
            local ax1, ay1 = vertXY(combined.verts, iA1)
            local ax2, ay2 = vertXY(combined.verts, iA2)

            local bestIdx1, bestIdx2
            local bestD1, bestD2 = math.huge, math.huge
            local bestRib1, bestRib2

            for r2, m2 in ipairs(combined.meta) do
                if r2 ~= r then
                    for v = m2.firstVert, m2.firstVert + m2.vertCount - 1 do
                        local vx, vy = vertXY(combined.verts, v)
                        local d1 = (vx - ax1) ^ 2 + (vy - ay1) ^ 2
                        local d2 = (vx - ax2) ^ 2 + (vy - ay2) ^ 2
                        if d1 < bestD1 then bestD1 = d1; bestIdx1 = v; bestRib1 = r2 end
                        if d2 < bestD2 then bestD2 = d2; bestIdx2 = v; bestRib2 = r2 end
                    end
                end
            end

            if bestIdx1 and bestIdx2
                and bestD1 < tSq and bestD2 < tSq
                and bestIdx1 ~= bestIdx2 then
                -- Quad (iA1, iA2, bestIdx2, bestIdx1) → two tris. Winding
                -- is intentionally not enforced yet — the overlay doesn't
                -- care; MESHUSERT stage will need to align this with the
                -- rest of the mesh's winding.
                bridgeTris[#bridgeTris + 1] = iA1
                bridgeTris[#bridgeTris + 1] = iA2
                bridgeTris[#bridgeTris + 1] = bestIdx2

                bridgeTris[#bridgeTris + 1] = iA1
                bridgeTris[#bridgeTris + 1] = bestIdx2
                bridgeTris[#bridgeTris + 1] = bestIdx1

                junctions[#junctions + 1] = {
                    fromRibbon = r, fromEnd = which,
                    toRibbon = bestRib1,
                    dist = { math.sqrt(bestD1), math.sqrt(bestD2) },
                }
            end
        end
    end

    return bridgeTris, junctions
end

-- Convenience: merge + bridge + append. Result carries `bridgeFirstTri` and
-- `bridgeTriCount` so downstream consumers (overlay, later the RESOURCE
-- sfixture writer) can tell strip-tris and bridge-tris apart.
function lib.mergeAndBridge(bodyIds, opts)
    local combined = lib.merge(bodyIds)
    if combined.error then return combined end

    local bridgeTris, junctions = lib.buildBridges(combined, opts)
    combined.bridgeFirstTri = #combined.tris / 3 + 1
    combined.bridgeTriCount = #bridgeTris / 3
    combined.junctions = junctions
    for i = 1, #bridgeTris do
        combined.tris[#combined.tris + 1] = bridgeTris[i]
    end
    return combined
end

return lib

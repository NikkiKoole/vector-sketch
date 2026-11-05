-- src/render/skinning.lua (split from physics/box2d-draw-textured.lua, SPLIT1)
local lib = {}
local spineMesh = require('src.spine-mesh')
local shapes = require('src.shapes')
local registry = require('src.registry')
local mathutils = require('src.math-utils')
local NT = require('src.node-types')
local SIDES = require('src.sides')

-- Skinning mode for MESHUSERT deformation (the mesh-with-influences path).
--   true  = Dual Quaternion Skinning — preserves volume, avoids candy-wrapper at joints
--   false = Linear Blend Skinning    — fast, but collapses/pinches when influencing bones rotate oppositely
-- NOTE: this does NOT affect CONNECTED_TEXTURE (textured ribbon along a Bezier through joint
-- anchors — e.g. arm/leg hair), which has its own bow-tie cause (sharp curve bends at elbow/knee)
-- handled in `texturedCurve` via per-sample width clamping.
-- NOTE: requires per-influence `bindAngle` and per-vertex `bindVerts` on ud.extra. New binds
-- (re-running "edit vertices" → weights) capture these; old scenes are backfilled on load in io.lua
-- using the loaded pose as bind pose. Falls back to LBS gracefully per-vertex if data is missing.
lib.useDQS = true
-- UV lookup helpers for MESHUSERT / UVUSERT paths.
-- The source polygon (`polyVerts`) is `{x1,y1,x2,y2,...}` and its corresponding
-- UV array (`uvs`) is `{u1,v1,u2,v2,...}` aligned by vertex index. After
-- triangulation, each triangle vertex's (x,y) matches one of the source vertices
-- (triangulation doesn't add Steiner points for simple polygons). Build an
-- (x,y) → vertex-index map once, then look up both u and v from the same source
-- vertex by keying on the full (x,y) pair — not by matching x and y against
-- every slot independently (which was the pre-fix bug: numeric collisions between
-- x- and y-coordinates of different vertices caused scrambled UVs).
local function buildPolyVertexIndex(polyVerts)
    local map = {}
    local numVerts = math.floor(#polyVerts / 2)
    for vi = 1, numVerts do
        local key = string.format("%.3f,%.3f",
            polyVerts[(vi - 1) * 2 + 1],
            polyVerts[(vi - 1) * 2 + 2])
        map[key] = vi
    end
    return map
end

local function lookupUV(vx, vy, vertexIndex, uvs)
    local key = string.format("%.3f,%.3f", vx, vy)
    local vi = vertexIndex[key]
    if not vi then return nil, nil end
    return uvs[(vi - 1) * 2 + 1], uvs[(vi - 1) * 2 + 2]
end

local function currentAnchorLocal(infl)
    if infl.nodeType == NT.ANCHOR then
        local f = registry.getSFixtureByID(infl.nodeId)
        if not f then return infl.offx, infl.offy end
        local bp = f:getBody()

        local pts = { bp:getWorldPoints(f:getShape():getPoints()) }
        local cx, cy = mathutils.getCenterOfPoints(pts)
        return bp:getLocalPoint(cx, cy)
    end

    if infl.nodeType == NT.JOINT then
        local joint = registry.getJointByID(infl.nodeId)
        if not joint then return infl.offx, infl.offy end

        local x1, y1, x2, y2 = joint:getAnchors()
        local bodyA, bodyB = joint:getBodies()

        if infl.side == SIDES.A then
            return bodyA:getLocalPoint(x1, y1)
        else
            return bodyB:getLocalPoint(x2, y2)
        end
    end

    return infl.offx, infl.offy
end

-- Linear Blend Skinning: averages per-bone world positions directly.
-- Causes "candy wrapper" / bowtie collapse at joints when influencing bodies
-- rotate in opposite directions (the averaged midpoint falls inside the joint).
-- One vertex, linear blend: the weighted average of where each live bone puts it,
-- in the root body's coordinates. Nil when none of its bones is left.
local function lbsVertex(inflList, rootBody)
    local wxSum, wySum, wSum = 0, 0, 0
    for k = 1, #inflList do
        local infl = inflList[k]
        if infl.body and not infl.body:isDestroyed() then
            local ax, ay = currentAnchorLocal(infl)
            local wx, wy = infl.body:getWorldPoint(ax + infl.dx, ay + infl.dy)
            wxSum = wxSum + wx * infl.w
            wySum = wySum + wy * infl.w
            wSum = wSum + infl.w
        end
    end
    if wSum <= 0 then return nil end
    return rootBody:getLocalPoint(wxSum / wSum, wySum / wSum)
end

-- A vertex with no bone left (its joint / anchor deleted, its body destroyed) stays at its rest
-- place on its own body (restVerts: the placed polygon, body-local) instead of coming loose.
local function lbsVertexOrRest(inflList, rootBody, restVerts, vi)
    local x, y = lbsVertex(inflList, rootBody)
    if x then return x, y end
    return restVerts[(vi - 1) * 2 + 1], restVerts[(vi - 1) * 2 + 2]
end

local function deformWorldVertsLBS(influences, numVerts, rootBody, restVerts)
    local out = {}
    for vi = 1, numVerts do
        out[(vi - 1) * 2 + 1], out[(vi - 1) * 2 + 2] = lbsVertexOrRest(influences[vi], rootBody, restVerts, vi)
    end
    return out
end

-- Dual Quaternion Skinning (2D):
-- 1. Compute each bone's delta rotation from bind pose (Δθ_i = θ_i_now - θ_i_bind).
-- 2. Circular-mean blend the delta angles weighted by influence weight.
-- 3. Apply the single blended rotation to the bind vertex (around world origin).
-- 4. Add a rotation-compensated translation: Σ w_i·(P_i_now - R_blend·bindVert).
--
-- Requires per-influence `bindAngle` and per-vertex `bindVerts`. Falls back to LBS
-- if either is missing (old scenes that were never rebound).
local function deformWorldVertsDQS(influences, bindVerts, numVerts, rootBody, restVerts)
    local atan2, cos, sin = math.atan2, math.cos, math.sin
    local out = {}

    for vi = 1, numVerts do
        local inflList = influences[vi]
        local bv       = bindVerts and bindVerts[vi]

        -- Safety: stale influences (vert count mismatch) — skip vertex.
        if not inflList then
            out[(vi - 1) * 2 + 1] = 0
            out[(vi - 1) * 2 + 2] = 0
        -- Fallback path: no bind data for this vertex → LBS for this vertex only.
        elseif not bv then
            out[(vi - 1) * 2 + 1], out[(vi - 1) * 2 + 2] = lbsVertexOrRest(inflList, rootBody, restVerts, vi)
        else
            local bx, by = bv[1], bv[2]

            -- Pass 1: blended delta rotation + per-bone current world positions.
            local cosSum, sinSum, wSum = 0, 0, 0
            local nInfl = #inflList
            local pxs, pys, ws = {}, {}, {}

            for k = 1, nInfl do
                local infl = inflList[k]
                if infl.bindAngle == nil then
                    -- Missing bind angle on this influence → bail to LBS for this vertex.
                    pxs = nil
                    break
                end
                local body = infl.body
                if body and not body:isDestroyed() then
                    local ax, ay = currentAnchorLocal(infl)
                    local wx, wy = body:getWorldPoint(ax + infl.dx, ay + infl.dy)
                    local dTheta = body:getAngle() - infl.bindAngle
                    local w      = infl.w
                    pxs[k] = wx
                    pys[k] = wy
                    ws[k]  = w
                    cosSum = cosSum + w * cos(dTheta)
                    sinSum = sinSum + w * sin(dTheta)
                    wSum   = wSum + w
                else
                    pxs[k] = 0; pys[k] = 0; ws[k] = 0
                end
            end

            if not pxs then -- a bone without its bind angle: linear blend for this vertex
                out[(vi - 1) * 2 + 1], out[(vi - 1) * 2 + 2] = lbsVertexOrRest(inflList, rootBody, restVerts, vi)
            elseif wSum <= 0 then -- no bone left
                out[(vi - 1) * 2 + 1], out[(vi - 1) * 2 + 2] = restVerts[(vi - 1) * 2 + 1], restVerts[(vi - 1) * 2 + 2]
            else
                -- Blended delta rotation (circular mean).
                local len = (cosSum * cosSum + sinSum * sinSum) ^ 0.5
                local blendAngle
                if len > 1e-9 then
                    blendAngle = atan2(sinSum / len, cosSum / len)
                else
                    blendAngle = 0
                end

                -- R_blend · bindVert (rotate bind world pos by blended delta, around origin).
                local cosB, sinB = cos(blendAngle), sin(blendAngle)
                local rbx = cosB * bx - sinB * by
                local rby = sinB * bx + cosB * by

                -- Translation: Σ w_i · (P_i_now - R_blend · bindVert).
                local txBlend, tyBlend = 0, 0
                for k = 1, nInfl do
                    txBlend = txBlend + ws[k] * (pxs[k] - rbx)
                    tyBlend = tyBlend + ws[k] * (pys[k] - rby)
                end
                if wSum > 0 then
                    txBlend = txBlend / wSum
                    tyBlend = tyBlend / wSum
                end

                -- Final world position, then map to root-local.
                local fx = rbx + txBlend
                local fy = rby + tyBlend
                local rx, ry = rootBody:getLocalPoint(fx, fy)
                out[(vi - 1) * 2 + 1] = rx
                out[(vi - 1) * 2 + 2] = ry
            end
        end
    end

    return out
end

local function deformWorldVerts(influences, bindVerts, numVerts, rootBody, restVerts)
    if lib.useDQS then
        return deformWorldVertsDQS(influences, bindVerts, numVerts, rootBody, restVerts)
    else
        return deformWorldVertsLBS(influences, numVerts, rootBody, restVerts)
    end
end

-- Rigid single-bone position for vert vi: look up the unpruned rigidLookup
-- table (built at bind time) so any painted bone works regardless of
-- pruneTopK ranking. Falls back to the pruned influences path if rigidLookup
-- is absent (old scene compatibility).
local function rigidBoneVertLocal(vi, boneIndex, rigidLookupOrInfluences, rootBody, isLookup)
    if isLookup then
        local row = rigidLookupOrInfluences[vi]
        if not row then return nil end
        local entry = row[boneIndex]
        if not entry then return nil end
        if not entry.body or entry.body:isDestroyed() then return nil end
        local wx, wy = entry.body:getWorldPoint(entry.lx, entry.ly)
        return rootBody:getLocalPoint(wx, wy)
    else
        -- legacy path: pruned influences table
        local inflList = rigidLookupOrInfluences[vi]
        if not inflList then return nil end
        for k = 1, #inflList do
            local infl = inflList[k]
            if infl.nodeIndex == boneIndex then
                if not infl.body or infl.body:isDestroyed() then return nil end
                local ax, ay = currentAnchorLocal(infl)
                local wx, wy = infl.body:getWorldPoint(ax + infl.dx, ay + infl.dy)
                return rootBody:getLocalPoint(wx, wy)
            end
        end
        return nil
    end
end


-- The RESOURCE's polygon placed on the MESHUSERT: centred on the bbox centre of its vertices
-- (what makeShapeListFromPolygon subtracts for the Box2D fixtures: stable when the RESOURCE body
-- moves, where body:getPosition() wasn't: thing.vertices are authoring-world, not body-local),
-- then moved by extra.meshX/Y, scaled, turned by meshRot.
local function placePolygon(extra, verts)
    local cx, cy = mathutils.computeCentroid(verts)
    verts = mathutils.makePolygonRelativeToCenter(verts, cx, cy)
    verts = mathutils.transformPolygonPoints(verts, extra.meshX or 0, extra.meshY or 0)
    verts = mathutils.scalePolygonPoints(verts, extra.scaleX or 1, extra.scaleY or 1)
    local meshRot = extra.meshRot or 0
    if meshRot ~= 0 then
        verts = mathutils.rotatePolygonPoints(verts, meshRot)
    end
    return verts
end

-- Auto-unbind when the polygon's vertex count changed since the bind: stale influences /
-- spine (t,s) would crash or misalign.
local function dropStaleBinds(extra, numVerts)
    if extra.influences and #extra.influences ~= numVerts then
        extra.influences = nil
        extra.bindVerts = nil
    end
    local sb = extra.spineBind
    if sb then
        local boundVerts = sb.multi and (sb.perVert and #sb.perVert)
            or (sb.tsPerVert and #sb.tsPerVert / 2)
        if boundVerts and boundVerts ~= numVerts then
            extra.spineBind = nil
        end
    end
end

-- The spine bind's vertices this frame (a Bezier through the nodes), body-local: the mesh is
-- drawn with the body transform applied (love.graphics.draw(mesh, bx, by, ba)). Nil when the
-- chain is too short.
local function spineVerts(extra, body)
    local bendiness = extra.spineBendiness or 2
    local worldVerts
    if extra.spineBind.multi then
        local nodeLists = spineMesh.splitChainsByRootRepeat(extra.nodes or {})
        local chains = spineMesh.buildChainsFromNodeLists(nodeLists)
        worldVerts = spineMesh.evaluateMultiChain(extra.spineBind, chains, bendiness)
    else
        local liveChain = spineMesh.buildChainFromNodes(extra.nodes or {})
        if #liveChain >= 4 then
            worldVerts = spineMesh.evaluate(extra.spineBind, liveChain, bendiness)
        end
    end
    if not worldVerts then return nil end
    local localVerts = {}
    for k = 1, #worldVerts, 2 do
        localVerts[k], localVerts[k + 1] = body:getLocalPoint(worldVerts[k], worldVerts[k + 1])
    end
    return localVerts
end

-- Two bind modes, mutually exclusive: spine (Bezier through nodes) or DQS (per-vert
-- weighted-bone transforms). Each bind op clears the other; presence alone decides the path.
local function deform(extra, body, verts, numVerts)
    if extra.spineBind then
        return spineVerts(extra, body) or verts
    elseif extra.influences and #extra.influences > 0 then
        return deformWorldVerts(extra.influences, extra.bindVerts, numVerts, body, verts)
    end
    return verts
end

-- Re-order the stored triangle indices so triangles with a lower group number draw first
-- (behind). triangleGroups is written by the triangle painter; the reorder is stable
-- (triangles within a group keep their CDT order), and UVs are per vertex, so reordering
-- the indices never desyncs them. The painted bones follow their triangles. Returns the indices.
local function orderByGroup(extra, data, triIdx)
    if not (triIdx and data.triangleGroups and data.triangleOrderDirty) then return triIdx end
    local numTris = math.floor(#triIdx / 3)
    local perm = {}
    for t = 1, numTris do perm[t] = t end
    table.sort(perm, function(a, b)
        local ga = data.triangleGroups[a] or 0
        local gb = data.triangleGroups[b] or 0
        if ga == gb then return a < b end
        return ga < gb
    end)
    local newTri = {}
    local newGroups = {}
    local oldBones = extra.triangleBones
    local newBones = oldBones and {} or nil
    for k = 1, numTris do
        local src = perm[k]
        newTri[(k - 1) * 3 + 1] = triIdx[(src - 1) * 3 + 1]
        newTri[(k - 1) * 3 + 2] = triIdx[(src - 1) * 3 + 2]
        newTri[(k - 1) * 3 + 3] = triIdx[(src - 1) * 3 + 3]
        newGroups[k] = data.triangleGroups[src]
        if newBones then newBones[k] = oldBones[src] end
    end
    data.triangles = newTri
    data.triangleGroups = newGroups
    if newBones then extra.triangleBones = newBones end
    data.triangleOrderDirty = false
    return newTri
end

-- Per-vertex bone weights averaged over all the triangles that share the vertex: shared seam
-- vertices blend between adjacent painted bone regions instead of snapping to whichever
-- triangle is drawn first. [vertex index] = { [bone node index] = weight }
local function vertexBoneWeights(triangleBones, triIdx)
    local weights = {}
    local numTris = math.floor(#triIdx / 3)
    for t = 1, numTris do
        local boneIdx = triangleBones[t]
        if boneIdx then
            for corner = 0, 2 do
                local vi = triIdx[t * 3 - 2 + corner]
                if not weights[vi] then weights[vi] = {} end
                weights[vi][boneIdx] = (weights[vi][boneIdx] or 0) + 1
            end
        end
    end
    for _, bw in pairs(weights) do
        local total = 0
        for _, w in pairs(bw) do total = total + w end
        for bIdx, w in pairs(bw) do bw[bIdx] = w / total end
    end
    return weights
end

-- Where vertex vi is drawn: blended over its painted bones (rigidLookup preferred, unpruned;
-- the pruned influences for old scenes), else where the deformation put it.
local function vertexPlacer(extra, body, verts, triIdx)
    local rigidSource = extra.rigidLookup or extra.influences
    local isRigidLookup = extra.rigidLookup ~= nil
    local weights = extra.triangleBones and rigidSource and extra.bindVerts and triIdx
        and vertexBoneWeights(extra.triangleBones, triIdx)
    return function(vi)
        local bw = weights and weights[vi]
        if bw then
            local wxSum, wySum, wSum = 0, 0, 0
            for nodeIndex, w in pairs(bw) do
                local bx, by = rigidBoneVertLocal(vi, nodeIndex, rigidSource, body, isRigidLookup)
                if bx then
                    wxSum = wxSum + bx * w
                    wySum = wySum + by * w
                    wSum = wSum + w
                end
            end
            if wSum > 0 then return wxSum / wSum, wySum / wSum end
        end
        return verts[(vi - 1) * 2 + 1], verts[(vi - 1) * 2 + 2]
    end
end

-- index-based: vertex vi's UV is uvs[vi*2-1..vi*2]
local function indexedVertices(triIdx, placeVertex, uvs, alpha)
    local meshVertices = {}
    for j = 1, #triIdx do
        local vi = triIdx[j]
        local px, py = placeVertex(vi)
        if uvs then
            meshVertices[#meshVertices + 1] = { px, py, uvs[(vi - 1) * 2 + 1] or 0,
                uvs[(vi - 1) * 2 + 2] or 0, 1, 1, 1, alpha }
        else
            meshVertices[#meshVertices + 1] = { px, py, 1, 1, 1, alpha }
        end
    end
    return meshVertices
end

-- triangulated this frame: UVs looked up by each corner's (x, y)
local function triangulatedVertices(tris, verts, uvs, alpha)
    local meshVertices = {}
    local vertexIndex = uvs and buildPolyVertexIndex(verts)
    for j = 1, #tris do
        local tri = tris[j]
        for k = 0, 2 do
            local vx, vy = tri[k * 2 + 1], tri[k * 2 + 2]
            if uvs then
                local u, v = lookupUV(vx, vy, vertexIndex, uvs)
                meshVertices[#meshVertices + 1] = { vx, vy, u or 0, v or 0, 1, 1, 1, alpha }
            else
                meshVertices[#meshVertices + 1] = { vx, vy, 1, 1, 1, alpha }
            end
        end
    end
    return meshVertices
end

local FORMAT_UV = {
    { "VertexPosition", "float", 2 },
    { "VertexTexCoord", "float", 2 },
    { "VertexColor",    "float", 4 },
}
local FORMAT_PLAIN = {
    { "VertexPosition", "float", 2 },
    { "VertexColor",    "float", 4 },
}

-- A MESHUSERT's triangles this frame, in its body's frame: the RESOURCE's polygon (`verts`,
-- with its `data`: uvs, triangles, groups) centred and placed by extra.meshX/Y, scale and
-- rotation, then bent by the spine bind, the bone influences or the painted bones.
-- Returns the vertex format and vertices for love.graphics.newMesh, and for the debug
-- outline the placed polygon with its triangle indices (or, without indices, triangles).
function lib.meshusertVertices(extra, body, data, verts, isSelected)
    verts = placePolygon(extra, verts)
    local numVerts = #verts / 2
    dropStaleBinds(extra, numVerts)
    verts = deform(extra, body, verts, numVerts)

    -- Prefer pre-stored triangle indices (computed once at UV-compute time on the rest-pose
    -- polygon): topology stays stable across deformation, no per-frame triangulation, no
    -- Steiner-point UV gaps. Triangulated per frame when missing (old scenes, or the RESOURCE
    -- never selected after a polygon edit).
    local triIdx = orderByGroup(extra, data, data and data.triangles)
    local tris
    if not triIdx then
        tris = shapes.makeTrianglesFromPolygon(verts)
    end

    local uvs = data and data.uvs
    local alpha = uvs and (isSelected and 0.75 or 1) or 0.5
    local meshVertices
    if triIdx then
        meshVertices = indexedVertices(triIdx, vertexPlacer(extra, body, verts, triIdx), uvs, alpha)
    else
        meshVertices = triangulatedVertices(tris, verts, uvs, alpha)
    end
    return uvs and FORMAT_UV or FORMAT_PLAIN, meshVertices, verts, triIdx, tris
end

lib.lookupUV = lookupUV
lib.buildPolyVertexIndex = buildPolyVertexIndex

return lib

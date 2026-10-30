-- src/render/skinning.lua (split from physics/box2d-draw-textured.lua, SPLIT1)
local lib = {}
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
-- in the root body's coordinates.
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
    if wSum > 0 then wxSum = wxSum / wSum; wySum = wySum / wSum end
    return rootBody:getLocalPoint(wxSum, wySum)
end

local function deformWorldVertsLBS(influences, numVerts, rootBody)
    local out = {}
    for vi = 1, numVerts do
        out[(vi - 1) * 2 + 1], out[(vi - 1) * 2 + 2] = lbsVertex(influences[vi], rootBody)
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
local function deformWorldVertsDQS(influences, bindVerts, numVerts, rootBody)
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
            out[(vi - 1) * 2 + 1], out[(vi - 1) * 2 + 2] = lbsVertex(inflList, rootBody)
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
                out[(vi - 1) * 2 + 1], out[(vi - 1) * 2 + 2] = lbsVertex(inflList, rootBody)
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

local function deformWorldVerts(influences, bindVerts, numVerts, rootBody)
    if lib.useDQS then
        return deformWorldVertsDQS(influences, bindVerts, numVerts, rootBody)
    else
        return deformWorldVertsLBS(influences, numVerts, rootBody)
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


lib.lookupUV = lookupUV
lib.buildPolyVertexIndex = buildPolyVertexIndex
lib.deformWorldVerts = deformWorldVerts
lib.rigidBoneVertLocal = rigidBoneVertLocal

return lib

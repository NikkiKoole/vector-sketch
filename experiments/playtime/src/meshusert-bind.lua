-- meshusert-bind.lua
-- Binding a MESHUSERT (a skinned mesh) to its bones, the nodes along it (joints and
-- anchor sfixtures): per-vertex influences with weights for linear/dual-quaternion
-- skinning, or a spine bind (src/spine-mesh.lua) along the node chain. Moved out of the
-- sfixture panel's button handlers (src/ui/sfixture-editor.lua) so it can be read and
-- tested on its own; drawn by box2d-draw-textured.lua.
local registry = require('src.registry')
local mathutils = require('src.math-utils')
local resourceLink = require('src.resource-link')
local NT = require('src.node-types')
local SIDES = require('src.sides')

local lib = {}

-- Where a node (a joint or an anchor sfixture) sits, per body it's on, in that body's
-- coordinates: a joint gives one entry for each side.
local function getNodeLocal(node)
    if node.type == NT.JOINT then
        local joint = registry.getJointByID(node.id)
        if not joint then return {} end
        local x1, y1, x2, y2 = joint:getAnchors()
        local bodyA, bodyB = joint:getBodies()
        local ax, ay = bodyA:getLocalPoint(x1, y1)
        local bx, by = bodyB:getLocalPoint(x2, y2)
        return {
            { body = bodyA, offx = ax, offy = ay, type = NT.JOINT, id = node.id, side = SIDES.A },
            { body = bodyB, offx = bx, offy = by, type = NT.JOINT, id = node.id, side = SIDES.B },
        }
    end
    if node.type == NT.ANCHOR then
        local f = registry.getSFixtureByID(node.id)
        if not f then return {} end
        local bp = f:getBody()
        local pts = { bp:getWorldPoints(f:getShape():getPoints()) }
        local centerX, centerY = mathutils.getCenterOfPoints(pts)
        local lx, ly = bp:getLocalPoint(centerX, centerY)
        return { { body = bp, offx = lx, offy = ly, type = NT.ANCHOR, id = node.id } }
    end
    return {}
end
lib.nodeLocal = getNodeLocal

local function vertsToWorld(body, localVerts)
    local out = {}
    for i = 1, #localVerts, 2 do
        local lx, ly = localVerts[i], localVerts[i + 1]
        local wx, wy = body:getWorldPoint(lx, ly)
        out[#out + 1] = wx
        out[#out + 1] = wy
    end
    return out
end
local function computeInfluences(worldVerts, nodes)
    local influences = {}
    local numVerts = #worldVerts / 2

    for vi = 1, numVerts do
        local wx = worldVerts[(vi - 1) * 2 + 1]
        local wy = worldVerts[(vi - 1) * 2 + 2]
        influences[vi] = {}

        for nj = 1, #nodes do
            local node = nodes[nj]
            local infos = getNodeLocal(node)

            for _, info in ipairs(infos) do
                local bb = info.body

                local lx, ly = bb:getLocalPoint(wx, wy)
                local dx = lx - info.offx
                local dy = ly - info.offy
                local dist = math.sqrt(dx * dx + dy * dy)

                influences[vi][#influences[vi] + 1] = {
                    nodeIndex = nj,
                    body      = bb,        -- IMPORTANT but not wanetd here, atleast do not save it
                    offx      = info.offx, -- bind pose anchor local
                    offy      = info.offy,
                    nodeType  = info.type,
                    nodeId    = info.id,
                    side      = info.side, -- nil for anchors, "A"/"B" for joints
                    dx        = dx,
                    dy        = dy,
                    dist      = dist,
                    bindAngle = bb:getAngle(), -- body rotation at bind time (for DQS)
                    w         = 0,
                }
            end
        end
    end

    return influences
end
-- Segment-based weighting (ported from
-- experiments/deform-textured/main.lua:570). For each
-- consecutive pair of nodes that share a body, treat that
-- pair as a bone SEGMENT on that body. Compute weight per
-- body from segment-distance + smoothstep falloff, then
-- distribute the body weight across the influences we've
-- already created on that body.
--
-- Why: point-distance (old applyWeights) blurs a vertex
-- between every nearby anchor, which collapses mesh width
-- at bone midpoints. Segment-distance binds a vertex to
-- whichever bone it's closest-to as a whole line, keeping
-- width consistent along the length.
local function distToSegment(px, py, ax, ay, bx, by)
    local abx, aby = bx - ax, by - ay
    local abLen2 = abx * abx + aby * aby
    if abLen2 < 1e-12 then
        local dx, dy = px - ax, py - ay
        return math.sqrt(dx * dx + dy * dy), 0
    end
    local t = ((px - ax) * abx + (py - ay) * aby) / abLen2
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local cx, cy = ax + abx * t, ay + aby * t
    local dx, dy = px - cx, py - cy
    return math.sqrt(dx * dx + dy * dy), t
end
local function smoothstep(e0, e1, v)
    if v <= e0 then return 0 end
    if v >= e1 then return 1 end
    local t = (v - e0) / (e1 - e0)
    return t * t * (3 - 2 * t)
end
local function buildSegments(nodes)
    local segs = {}
    for i = 1, #nodes - 1 do
        local a = getNodeLocal(nodes[i])
        local b = getNodeLocal(nodes[i + 1])
        for _, ai in ipairs(a) do
            for _, bi in ipairs(b) do
                if ai.body == bi.body then
                    segs[#segs + 1] = {
                        body = ai.body,
                        lax = ai.offx, lay = ai.offy,
                        lbx = bi.offx, lby = bi.offy,
                    }
                end
            end
        end
    end
    return segs
end
local function applySegmentWeights(influences, nodes, worldVerts, radius, falloff)
    radius = radius or 80
    falloff = falloff or 1
    local segments = buildSegments(nodes)
    if #segments == 0 then
        -- Fall back to point-based inverse-distance weights.
        for vi = 1, #influences do
            local sum = 0
            for k = 1, #influences[vi] do
                influences[vi][k].w = 1 / (influences[vi][k].dist + 1e-6)
                sum = sum + influences[vi][k].w
            end
            if sum > 0 then
                for k = 1, #influences[vi] do
                    influences[vi][k].w = influences[vi][k].w / sum
                end
            end
        end
        return influences
    end

    local numVerts = #worldVerts / 2
    for vi = 1, numVerts do
        local px = worldVerts[(vi - 1) * 2 + 1]
        local py = worldVerts[(vi - 1) * 2 + 2]

        -- Per-body weight = max segment weight across any
        -- segment on that body (one body can host multiple
        -- segments if the node list is longer).
        local bodyW = {}
        for _, seg in ipairs(segments) do
            local wax, way = seg.body:getWorldPoint(seg.lax, seg.lay)
            local wbx, wby = seg.body:getWorldPoint(seg.lbx, seg.lby)
            local d = distToSegment(px, py, wax, way, wbx, wby)
            local weight = 1 - smoothstep(0, radius, d)
            if falloff ~= 1 and weight > 0 then weight = weight ^ falloff end
            if weight > 0 and (not bodyW[seg.body] or bodyW[seg.body] < weight) then
                bodyW[seg.body] = weight
            end
        end

        -- Count influences per body to split body-weight
        -- evenly (multiple endpoints on a body deform
        -- rigidly together — sharing the weight keeps the
        -- total body contribution = body-weight).
        local countPerBody = {}
        for k = 1, #influences[vi] do
            local b = influences[vi][k].body
            countPerBody[b] = (countPerBody[b] or 0) + 1
        end

        local sum = 0
        for k = 1, #influences[vi] do
            local b = influences[vi][k].body
            local bw = bodyW[b] or 0
            influences[vi][k].w = bw / countPerBody[b]
            sum = sum + influences[vi][k].w
        end

        if sum > 0 then
            for k = 1, #influences[vi] do
                influences[vi][k].w = influences[vi][k].w / sum
            end
        else
            -- All segments outside radius → bind to the
            -- nearest segment's body at full weight so the
            -- vertex isn't left orphaned.
            local bestBody, bestDist = nil, math.huge
            for _, seg in ipairs(segments) do
                local wax, way = seg.body:getWorldPoint(seg.lax, seg.lay)
                local wbx, wby = seg.body:getWorldPoint(seg.lbx, seg.lby)
                local d = distToSegment(px, py, wax, way, wbx, wby)
                if d < bestDist then bestDist = d; bestBody = seg.body end
            end
            if bestBody then
                local count = countPerBody[bestBody] or 1
                for k = 1, #influences[vi] do
                    influences[vi][k].w = (influences[vi][k].body == bestBody) and (1 / count) or 0
                end
            end
        end
    end
    return influences
end

local function pruneTopK(influences, K)
    for vi = 1, #influences do
        table.sort(influences[vi], function(a, b) return a.w > b.w end)
        while #influences[vi] > K do table.remove(influences[vi]) end

        local sum = 0
        for k = 1, #influences[vi] do sum = sum + influences[vi][k].w end
        if sum > 0 then
            for k = 1, #influences[vi] do influences[vi][k].w = influences[vi][k].w / sum end
        end
    end
    return influences
end

-- The mesh's vertices where they're drawn before binding, in world coordinates: the paired
-- RESOURCE's mesh (meshVertices, else its polygon) centred on its centroid, moved, scaled
-- and turned by the MESHUSERT's own offset, on the body that owns the MESHUSERT (the bone:
-- binding relative to it keeps the mesh in place, what you see is what you bind).
-- nil when there's no paired RESOURCE.
function lib.worldVerts(ud, ownerBody)
    local mappert = resourceLink.find(ud)
    if not mappert then return nil end
    local mapperExtra = mappert:getUserData().extra
    local verts = (mapperExtra and mapperExtra.meshVertices) or mappert:getBody():getUserData().thing.vertices
    local vx, vy = mathutils.computeCentroid(verts)
    verts = mathutils.makePolygonRelativeToCenter(verts, vx, vy)
    if ud.extra.meshX or ud.extra.meshY then
        verts = mathutils.transformPolygonPoints(verts, ud.extra.meshX or 0, ud.extra.meshY or 0)
    end
    if ud.extra.scaleX or ud.extra.scaleY then
        verts = mathutils.scalePolygonPoints(verts, ud.extra.scaleX or 1, ud.extra.scaleY or 1)
    end
    if ud.extra.meshRot and ud.extra.meshRot ~= 0 then
        verts = mathutils.rotatePolygonPoints(verts, ud.extra.meshRot)
    end
    return vertsToWorld(ownerBody, verts)
end

-- Forget the influence bind (weights, bind pose, rigid lookups); `triangleBones` too when asked
-- (painted bones index triangles, so a new triangulation drops them).
function lib.clearInfluences(extra, triangleBonesToo)
    extra.influences = nil
    extra.bindVerts = nil
    extra.rigidLookup = nil
    extra.rigidBindCoords = nil
    if triangleBonesToo then extra.triangleBones = nil end
end

-- Forget every bind: the mesh draws undeformed on its body.
function lib.unbind(extra)
    lib.clearInfluences(extra)
    extra.spineBind = nil
end

-- Bind the mesh to its nodes as it is now: each vertex weighted to the bone segments near it
-- (bindRadius, bindFalloff), the 3 strongest kept, plus the bind pose for DQS and an unpruned
-- per-bone lookup (rigidLookup / rigidBindCoords) for painted triangles. Clears a spine bind.
function lib.bindInfluences(ud, ownerBody)
    local verts = lib.worldVerts(ud, ownerBody)
    local nodes = ud.extra.nodes
    if not (verts and nodes and #nodes > 0) then return false end
    local influences = computeInfluences(verts, nodes)
    influences = applySegmentWeights(influences, nodes, verts,
        tonumber(ud.extra.bindRadius) or 80, tonumber(ud.extra.bindFalloff) or 1)
    ud.extra.influences = pruneTopK(influences, 3)

    local numVerts = #verts / 2
    local bindVerts, rigidLookup, rigidBindCoords = {}, {}, {}
    for vi = 1, numVerts do
        local wx, wy = verts[(vi - 1) * 2 + 1], verts[(vi - 1) * 2 + 2]
        bindVerts[vi] = { wx, wy }
        rigidLookup[vi] = {}
        local coordRow = {} -- just the numbers, no bodies: saved, so load gets the same lx/ly back
        for nj = 1, #nodes do
            local infos = getNodeLocal(nodes[nj])
            if #infos > 0 then
                local lx, ly = infos[1].body:getLocalPoint(wx, wy)
                rigidLookup[vi][nj] = { body = infos[1].body, lx = lx, ly = ly }
                coordRow[2 * nj - 1] = lx
                coordRow[2 * nj] = ly
            end
        end
        rigidBindCoords[vi] = coordRow
    end
    ud.extra.bindVerts = bindVerts
    ud.extra.rigidLookup = rigidLookup
    ud.extra.rigidBindCoords = rigidBindCoords
    ud.extra.spineBind = nil -- one bind at a time
    return true
end

-- Bind the mesh along its node chain (src/spine-mesh.lua): one chain, or with `multi` the
-- node list split where its root repeats (four limbs off one hub), each vertex on its
-- nearest chain. Clears an influence bind. Returns the bind, or nil and why.
function lib.bindSpine(ud, ownerBody, multi)
    local nodes = ud.extra.nodes or {}
    local verts = #nodes >= 2 and lib.worldVerts(ud, ownerBody)
    if not verts then return nil, 'need a paired RESOURCE and >=2 nodes' end
    local spineMesh = require('src.spine-mesh')
    local bendiness = ud.extra.spineBendiness or 2
    local bind, err
    if multi then
        local chains = spineMesh.buildChainsFromNodeLists(spineMesh.splitChainsByRootRepeat(nodes))
        bind, err = spineMesh.bindMultiChain(verts, chains, bendiness)
    else
        bind, err = spineMesh.bind(verts, spineMesh.buildChainFromNodes(nodes), bendiness)
    end
    if bind then
        ud.extra.spineBind = bind
        lib.clearInfluences(ud.extra)
    end
    return bind, err
end

return lib

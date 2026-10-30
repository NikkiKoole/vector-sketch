-- save-migrations.lua
-- Everything that is only here for scene files from before a change: one place to delete from
-- once those files are gone. src/scene-load.lua calls these; files saved today pass through.
-- (Subtype formats migrate in src/subtypes.lua, subtypes.migrate; a RESOURCE's image URL in
-- src/resource-link.lua.)
-- Split out of io.lua (CODE-SPLITS-2026-10.md SPLIT6).
local registry = require('src.registry')
local mathutils = require('src.math-utils')
local NT = require('src.node-types')

local lib = {}

-- Path B (docs/STEINER-OWNERSHIP-PLAN.md): old files keep `extraSteiner` on RESOURCE sfixtures in
-- authoring-world coords; now it's on the body, body-local. On decoded file data: subtract
-- centroid(body.vertices) from each pair, append onto body.extraSteiner, clear the RESOURCE's.
-- Idempotent (a second pass finds nothing to move); safe on nil, empty, bodies without vertices.
function lib.extraSteinerToBody(saveData)
    if type(saveData) ~= 'table' then return end
    local bodies = saveData.bodies
    if type(bodies) ~= 'table' then return end
    for _, body in ipairs(bodies) do
        if type(body) == 'table' and type(body.vertices) == 'table'
            and #body.vertices >= 6 and type(body.fixtures) == 'table' then
            local cenX, cenY = mathutils.computeCentroid(body.vertices)
            for _, fix in ipairs(body.fixtures) do
                local extra = fix.userData and fix.userData.extra
                local es = extra and extra.extraSteiner
                if type(es) == 'table' and #es >= 2 then
                    body.extraSteiner = body.extraSteiner or {}
                    for i = 1, #es - 1, 2 do
                        body.extraSteiner[#body.extraSteiner + 1] = es[i] - cenX
                        body.extraSteiner[#body.extraSteiner + 1] = es[i + 1] - cenY
                    end
                    extra.extraSteiner = nil
                end
            end
        end
    end
end

-- Files from before DQS have no bindVerts: take them from the bodies as loaded. At bind time each
-- influence's (offx, offy) IS the anchor's body-local position, so (offx + dx, offy + dy) through
-- the body's world transform is the bind-world position, as long as nothing moved since the load
-- (true when the scene loads paused, at rest).
function lib.backfillBindVerts(extra)
    if not extra or not extra.influences then return end
    if extra.bindVerts then return end
    local bindVerts = {}
    for vi = 1, #extra.influences do
        local inflList = extra.influences[vi]
        local infl = inflList and inflList[1]
        if infl and infl.body then
            local wx, wy = infl.body:getWorldPoint(
                (infl.offx or 0) + (infl.dx or 0),
                (infl.offy or 0) + (infl.dy or 0)
            )
            bindVerts[vi] = { wx, wy }
        end
    end
    extra.bindVerts = bindVerts
end

-- rigidLookup holds bodies, so it is never saved: rebuild it after a load. rigidBindCoords (saved
-- since the fix) keeps the exact lx, ly from bind time as plain numbers, so it's only the bodies
-- to attach. Older files without it: reconstruct from the bind pose.
function lib.backfillRigidLookup(extra)
    if not extra or not extra.nodes then return end
    if extra.rigidLookup then return end

    local nodeBodies = {}
    for nj, node in ipairs(extra.nodes) do
        if node.type == NT.ANCHOR then
            local f = registry.getSFixtureByID(node.id)
            if f and not f:isDestroyed() then nodeBodies[nj] = f:getBody() end
        elseif node.type == NT.JOINT then
            local joint = registry.getJointByID(node.id)
            if joint then nodeBodies[nj] = joint:getBodies() end
        end
    end

    local coords = extra.rigidBindCoords
    if coords then
        local numNodes = #extra.nodes
        local rigidLookup = {}
        for vi = 1, #coords do
            local row = coords[vi]
            if row then
                rigidLookup[vi] = {}
                for nj = 1, numNodes do
                    local lx = row[2 * nj - 1]
                    local ly = row[2 * nj]
                    local body = nodeBodies[nj]
                    if body and lx then
                        rigidLookup[vi][nj] = { body = body, lx = lx, ly = ly }
                    end
                end
            end
        end
        extra.rigidLookup = rigidLookup
        return
    end

    -- old files without rigidBindCoords: reconstruct from influences
    local influences = extra.influences
    if not influences or not extra.bindVerts then return end
    local bindPose = {}
    for vi = 1, #extra.bindVerts do
        local bv = extra.bindVerts[vi]
        if bv and influences[vi] then
            local wx, wy = bv[1], bv[2]
            for _, infl in ipairs(influences[vi]) do
                local ni = infl.nodeIndex
                if ni and not bindPose[ni] and infl.bindAngle and infl.offx then
                    local lx = infl.offx + infl.dx
                    local ly = infl.offy + infl.dy
                    local ba = infl.bindAngle
                    local c, s = math.cos(ba), math.sin(ba)
                    bindPose[ni] = {
                        bx = wx - (c * lx - s * ly),
                        by = wy - (s * lx + c * ly),
                        ba = ba, body = infl.body,
                    }
                end
            end
        end
    end
    local rigidLookup = {}
    for vi = 1, #extra.bindVerts do
        local bv = extra.bindVerts[vi]
        if bv then
            local wx, wy = bv[1], bv[2]
            rigidLookup[vi] = {}
            for nj = 1, #extra.nodes do
                local bp = bindPose[nj]
                if bp then
                    local dx2 = wx - bp.bx
                    local dy2 = wy - bp.by
                    local c, s = math.cos(bp.ba), math.sin(bp.ba)
                    rigidLookup[vi][nj] = {
                        body = bp.body,
                        lx   =  c * dx2 + s * dy2,
                        ly   = -s * dx2 + c * dy2,
                    }
                end
            end
        end
    end
    extra.rigidLookup = rigidLookup
end

return lib

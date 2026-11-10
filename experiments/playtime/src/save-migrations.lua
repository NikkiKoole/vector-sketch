-- save-migrations.lua
-- What a file saved before a change needs to load today, in one ordered list (docs/LANDING-2026-11.md
-- L3). A scene file carries `version` (SCENE_VERSION when saved now; "1.0", every file before
-- 2026-11-10, is 1); each saved Mipo in it (`characters`) its own `version` (DNA_VERSION). Loading,
-- every step from the file's version up to today's runs, in order; a file saved today passes through.
-- A scene from a newer Playtime than this one is refused (upgradeScene), not half loaded.
--
-- A change to what's saved: SCENE_VERSION or DNA_VERSION one up, and a step below that brings the
-- version before it up (STEPS[n] takes a version-n file to n+1). A new DNA field with a default
-- needs no step: src/dna-defaults.lua fills it in.
--
-- Not here, run on every load: old texture names (src/texture-names.lua, a name map that keeps
-- growing), subtype names (src/subtypes.lua migrate, which also cleans them), a RESOURCE's image
-- (src/resource-link.lua), and backfillRigidLookup below (bodies, never saved).
-- Split out of io.lua (CODE-SPLITS-2026-10.md SPLIT6).
local registry = require('src.registry')
local mathutils = require('src.math-utils')
local NT = require('src.node-types')
local logger = require('src.logger')

local lib = {}

lib.SCENE_VERSION = 2
lib.DNA_VERSION = 2

-- The version of a decoded scene (or prefab): "1.0" and no version are 1; nil when it isn't one.
function lib.sceneVersion(data)
    local v = type(data) == 'table' and data.version
    if v == nil or v == '1.0' then return 1 end
    v = tonumber(v)
    if v and v >= 1 and v == math.floor(v) then return v end
    return nil
end

-- A saved Mipo's DNA version (a scene's `characters` entry; nil: from before versions, 1).
function lib.dnaVersion(version)
    local v = tonumber(version)
    return v and v >= 1 and math.floor(v) or 1
end

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


-- Saved Mipos from before 2026-11-10 moved over to what builds now (were mipo-build's migrateDNA).
local function dnaBeforeVersions(dna)
    local mipoDna = require('src.mipo-dna') -- here, not on top: no require loop
    local JT = require('src.joint-types')
    for partName, partDNA in pairs(dna.parts or {}) do
        -- noses saved when they drew at z 490, above the arms
        if partName:find('^nose') and partDNA.appearance then
            for _, block in pairs(partDNA.appearance) do
                if type(block) == 'table' and block.zOffset == 490 then block.zOffset = 350 end
            end
        end
        -- ears on a hinge (saved before the soft weld): the next rebuild makes them springy
        if (partName == 'lear' or partName == 'rear') and partDNA.j and partDNA.j.type == JT.REVOLUTE then
            partDNA.j = mipoDna.earJoint()
        end
        local skin = partName:find('^torso%d') and partDNA.appearance and partDNA.appearance.skin
        if skin and skin.zOffset == 200 then skin.zOffset = mipoDna.TORSO_SKIN_Z end
        -- the duck beak upper lip is out (shape-catalogs.lua)
        local face = partDNA.appearance and partDNA.appearance.face
        if face and face.mouth and face.mouth.upperLipShape == 4 then face.mouth.upperLipShape = 1 end
    end
end

-- A saved Mipo part's fixtures from before 2026-11-10 (were mipo-build's migrateSavedFixtures): torsos
-- drawn at the head's 200/210 (TORSO_SKIN_Z), the duck-beak upper lip (out), noses drawn at z 490.
local function partBeforeVersions(body, partName)
    local mipoDna = require('src.mipo-dna')
    local subtypes = require('src.subtypes')
    for _, fixture in ipairs(body:getFixtures()) do
        local fud = fixture:getUserData()
        if fud and fud.extra and partName:find('^torso%d') and fud.subtype == subtypes.TEXFIXTURE then
            if fud.extra.zOffset == 200 then
                fud.extra.zOffset = mipoDna.TORSO_SKIN_Z
            elseif fud.extra.zOffset == 210 then
                fud.extra.zOffset = mipoDna.TORSO_SKIN_Z + mipoDna.TORSO_HAIR_ABOVE_SKIN
            end
        end
        if fud and fud.label == 'upperlip' and fud.extra and fud.extra.main
            and fud.extra.main.bgURL == 'mipo/upperlip/upperlip-04.png' then -- the duck beak is out
            fud.extra.main.bgURL = 'mipo/upperlip/upperlip-01.png'
            fud.extra.main.fgURL = 'mipo/upperlip/upperlip-01-mask.png'
            fud.extra.dirty = true
        end
        if fud and fud.extra and fud.extra.zOffset == 490 then
            if fud.label == 'nose' then
                fud.extra.zOffset = 254
            elseif partName:find('^nose') then
                fud.extra.zOffset = 350
            end
        end
    end
end

-- The steps, in order. STEPS[n] takes a version-n file to n+1, in up to four places:
--   scene(data)          the decoded scene file, before anything is built (scene-load prepareLoaded)
--   meshusert(extra)     each MESHUSERT's extra once its influences have their bodies (scene-load)
--   dna(dna)             a saved Mipo's DNA before it's built (mipo-build prepareDNA)
--   part(body, partName) each body of a saved Mipo, as it's taken in (mipo-build adoptPart)
lib.SCENE_STEPS = {
    [1] = { -- before versions (all files to 2026-11-10)
        scene = function(data) lib.extraSteinerToBody(data) end,
        meshusert = lib.backfillBindVerts, -- files from before DQS
    },
}
lib.DNA_STEPS = {
    [1] = { dna = dnaBeforeVersions, part = partBeforeVersions }, -- before versions (to 2026-11-10)
}

-- The decoded scene brought up to SCENE_VERSION: true, or false and why. Keeps the version it had
-- in data.migratedFrom (for the steps run once its bodies exist, lib.sceneSteps).
function lib.upgradeScene(data)
    local from = lib.sceneVersion(data)
    if not from then return false, 'not a scene version: ' .. tostring(data and data.version) end
    if from > lib.SCENE_VERSION then
        return false, ('saved by a newer Playtime (version %d, this one reads up to %d)')
            :format(from, lib.SCENE_VERSION)
    end
    for v = from, lib.SCENE_VERSION - 1 do
        local step = lib.SCENE_STEPS[v]
        if step and step.scene then step.scene(data) end
    end
    data.migratedFrom, data.version = from, lib.SCENE_VERSION
    return true
end

-- The MESHUSERT steps a decoded scene of this version still needs (once its bodies exist): a list,
-- empty for a file saved today. Data not through upgradeScene (specs build
-- files directly) goes by its own version.
function lib.sceneSteps(data)
    local from = (data and data.migratedFrom) or lib.sceneVersion(data) or lib.SCENE_VERSION
    local out = {}
    for v = from, lib.SCENE_VERSION - 1 do
        local step = lib.SCENE_STEPS[v]
        if step and step.meshusert then out[#out + 1] = step.meshusert end
    end
    return out
end

-- A saved Mipo's DNA brought up to DNA_VERSION in place, from `version` (nil: unknown, taken as 1,
-- which is safe: the steps leave today's DNA as it is). Returns the DNA_STEPS' part steps still to
-- run on its bodies, and the version it has now.
function lib.upgradeDNA(dna, version)
    local from = lib.dnaVersion(version)
    if from > lib.DNA_VERSION then
        logger:info('a Mipo from a newer Playtime (DNA version ' .. from .. '), built as it is')
        return {}, from
    end
    local parts = {}
    for v = from, lib.DNA_VERSION - 1 do
        local step = lib.DNA_STEPS[v]
        if step and step.dna then step.dna(dna) end
        if step and step.part then parts[#parts + 1] = step.part end
    end
    return parts, lib.DNA_VERSION
end

return lib

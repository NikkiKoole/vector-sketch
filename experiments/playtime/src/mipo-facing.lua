-- mipo-facing.lua: a Mipo facing left or right instead of front, after puppet-maker2's
-- facingVars.legs (lib/box2dGuyCreation.lua, lib/texturedBox2d.lua at the repo root;
-- docs/MIPO-FACING.md). dna.facing: nil or 'front' (as always), 'left', 'right'.
--
-- Facing a side, the limbs of the other side are built as copies of this side's: same joint
-- limits (both knees bend backwards, both hips swing forwards: what sitting on a chair needs),
-- same foot angle and the same foot picture, so both feet point the way the Mipo faces. The
-- limbs of the far side draw behind the torso. Head, face and torso stay front-on, as in
-- puppet-maker2. Part names are screen sides: l* hang on the left (xSign -1).
local shape8Dict = require('src.shape8-dict')
local mathutils = require('src.math-utils')

local lib = {}

-- The face turned toward the facing side, as if drawn on a cylinder (the head's width) turned
-- this far: a feature at x moves to R sin(asin(x / R) + turn), and gets narrower or wider by the
-- cosine, so the far eye squeezes by itself. Ears turn the same way (character-topology outline).
lib.faceTurn = math.rad(30)
-- The ear at the back of the head (the one that comes over it) turns less: at the full turn it
-- sat too far toward the face (Nikki 2026-11-05). 0 = it stays on the head's edge.
lib.backEarTurn = math.rad(8)
-- The nose sticks out in front of the face (NOSE-DEPTH N1, 2026-11-11): it turns on a cylinder this much
-- wider than the head, so on a turn it moves further than the eyes and comes over the near cheek.
lib.noseOut = 1.35
-- Idle gaze facing a side: the spot it looks around is this far ahead of the head.
lib.gazeAhead = 600

local OTHER = {
    luleg = 'ruleg', ruleg = 'luleg', llleg = 'rlleg', rlleg = 'llleg', lfoot = 'rfoot', rfoot = 'lfoot',
    luarm = 'ruarm', ruarm = 'luarm', llarm = 'rlarm', rlarm = 'llarm',
}

-- Copy the arms too (both swing forward), or only the legs and feet (puppet-maker2 did legs only).
lib.arms = true

local ARM = { luarm = true, ruarm = true, llarm = true, rlarm = true }

function lib.get(instance)
    local f = instance and instance.dna and instance.dna.facing
    if f == 'left' or f == 'right' then return f end
    return 'front'
end

-- The part whose joint limits, foot angle and foot picture this part takes.
function lib.source(instance, partName)
    local other = OTHER[partName]
    if not other then return partName end
    if ARM[partName] and not lib.arms then return partName end
    local f = lib.facingOf(instance, partName)
    local side = partName:sub(1, 1) -- 'l' or 'r'
    if (f == 'right' and side == 'l') or (f == 'left' and side == 'r') then return other end
    return partName
end

-- The arms can switch at another moment than the body (a turn: scripts/spikes/facing):
-- dna.armFacing, else they face as the body does.
function lib.armFacing(instance)
    local f = instance and instance.dna and instance.dna.armFacing
    if f == 'left' or f == 'right' or f == 'front' then return f end
    return lib.get(instance)
end

-- The ears can switch at another moment than the body too (a staggered turn, src/mipo-walk.lua: they
-- go with the head): dna.earFacing, else they face as the body does.
function lib.earFacing(instance)
    local f = instance and instance.dna and instance.dna.earFacing
    if f == 'left' or f == 'right' or f == 'front' then return f end
    return lib.get(instance)
end

local function earDir(instance)
    local f = lib.earFacing(instance)
    return f == 'right' and 1 or f == 'left' and -1 or 0
end

local ARM_KIND = { luarm = true, ruarm = true, llarm = true, rlarm = true, lhand = true, rhand = true }

-- the facing a part goes by: the arms' for arm parts, else the body's
function lib.facingOf(instance, partName)
    if ARM_KIND[partName] then return lib.armFacing(instance) end
    return lib.get(instance)
end

-- +1 facing right, -1 facing left, 0 front
function lib.dir(instance)
    local f = lib.get(instance)
    return f == 'right' and 1 or f == 'left' and -1 or 0
end

-- How far the face is turned (radians, + toward the right): instance._turnAngle while a turn
-- is under way (scripts/spikes/facing turns it a little every frame), else the facing's.
function lib.angle(instance)
    if instance._turnAngle then return instance._turnAngle end
    return lib.dir(instance) * lib.faceTurn
end

-- x on a head centred at cx with half width r, turned by angle (default lib.angle): the new x
-- and the width factor there.
function lib.turnX(instance, x, cx, r, angle)
    angle = angle or lib.angle(instance)
    if angle == 0 or not r or r <= 0 then return x, 1 end
    local theta = math.asin(mathutils.clamp((x - cx) / r, -1, 1))
    local turned = theta + angle
    local width = math.cos(turned) / math.max(0.2, math.cos(theta))
    return cx + r * math.sin(turned), mathutils.clamp(width, 0.25, 1.5)
end

-- The face's head box: centre and half width, from its shape8 outline (as mipo-textures does).
local function headBox(instance, partName)
    local partData = instance.dna.parts[partName]
    local shape = partData and partData.shape8URL and shape8Dict[partData.shape8URL]
    if not shape then return nil end
    local verts = mathutils.scalePolygonPoints(shape.vertices,
        (partData.dims.sx or 1) * instance.scale, (partData.dims.sy or 1) * instance.scale)
    local left, right = math.min(verts[5], verts[13]), math.max(verts[5], verts[13]) -- vertices 3, 7
    return (left + right) / 2, (right - left) / 2
end
lib.headBox = headBox

-- Eyes, pupils, brows, nose and mouth turned by lib.angle: after the face decals are made
-- (mipo-textures rebuildTextures), and every frame of a turn. Each decal keeps its front-on
-- place (base*), so turning again starts from there.
function lib.applyFace(instance)
    local owner = instance.dna.creation.isPotatoHead and 'torso1' or 'head'
    local part = instance.parts and instance.parts[owner]
    if not (part and part.body and not part.body:isDestroyed()) then return end
    local cx, r = headBox(instance, owner)
    if not cx then return end
    local angle = lib.angle(instance)
    local bases = {} -- [curvePoints] = its front-on copy: the lips and teeth share one table
    for _, fixture in ipairs(part.body:getFixtures()) do
        local ud = fixture:getUserData()
        local e = ud and ud.subtype == 'decal' and ud.extra
        if e and e.facePatches then -- one decal, several patches (breeds spike's face patches)
            for _, patch in ipairs(e.facePatches) do
                if angle ~= 0 or patch.baseOx then
                    if not patch.baseOx then patch.baseOx, patch.baseW = patch.ox, patch.w end
                    local ox, width = lib.turnX(instance, patch.baseOx, cx, r, angle)
                    patch.ox, patch.w = ox, patch.baseW * width
                end
            end
        end
        if e and e.ox and (angle ~= 0 or e.baseOx) then
            if not e.baseOx then e.baseOx, e.baseW, e.baseEyeW = e.ox, e.w, e.eyeW end
            local radius = ud.label == 'nose' and r * lib.noseOut or r -- the nose stands out (N1)
            local ox, width = lib.turnX(instance, e.baseOx, cx, radius, angle)
            if e.mouthCurve and e.curvePoints then
                e.mouthX = ox
                local base = e.baseCurve or bases[e.curvePoints]
                if not base then
                    base = {}
                    for i = 1, #e.curvePoints do base[i] = e.curvePoints[i] end
                end
                bases[e.curvePoints], e.baseCurve = base, base
                for i = 1, #base, 2 do
                    e.curvePoints[i] = (lib.turnX(instance, base[i], cx, r, angle))
                end
            end
            e.ox = ox
            if e.baseW then e.w = e.baseW * width end
            if e.baseEyeW then e.eyeW = e.baseEyeW * width end
        end
    end
end

-- The ear at the back of the turned head: lear facing right, rear facing left.
function lib.isBackEar(instance, partName)
    local d = earDir(instance)
    return (d > 0 and partName == 'lear') or (d < 0 and partName == 'rear')
end

-- An ear's attach point turned with the head (character-topology outline).
function lib.turnEarX(instance, partName, x, cx, r)
    local turn = lib.isBackEar(instance, partName) and lib.backEarTurn or lib.faceTurn
    return (lib.turnX(instance, x, cx, r, earDir(instance) * turn))
end

-- The idle gaze's centre: ahead of the face as far as the head is turned (mipo-actions gazeGoal).
function lib.gazeCenter(instance, fx, fy)
    return fx + (lib.angle(instance) / lib.faceTurn) * lib.gazeAhead, fy -- follows the head's turn
end

-- The far side draws behind the torso (torso skin 192, ears 190, neck ribbon 100):
-- facing right that is the r limbs, as puppet-maker2 drew them.
local FAR_Z = { -- [part] = { [old zOffset] = new }
    uleg = { [300] = 60, [301] = 61 }, -- leg ribbon and its hair live on the upper leg
    foot = { [399] = 62 },
    uarm = { [402] = 50, [403] = 51 }, -- the far arm and hand under the far leg; the near ones
    hand = { [500] = 52 },              -- keep their place over the near leg (Nikki 2026-11-05)
}
local KIND = { luleg = 'uleg', ruleg = 'uleg', lfoot = 'foot', rfoot = 'foot',
    luarm = 'uarm', ruarm = 'uarm', lhand = 'hand', rhand = 'hand' }

function lib.isFar(instance, partName)
    local f = lib.facingOf(instance, partName)
    if f == 'front' then return false end
    local side = f == 'right' and 'r' or 'l'
    return KIND[partName] ~= nil and partName:sub(1, 1) == side
end

-- The ear at the back of the turned head comes round to the side of it: in front of the head
-- skin (200), under its hair (210). The other one stays behind (190).
local BACK_EAR_Z = 205

-- After the textures are made (mipo-textures rebuildTextures): far limbs' sfixtures behind the
-- torso, the back ear over the head.
function lib.applyZ(instance)
    if lib.get(instance) == 'front' and lib.armFacing(instance) == 'front'
        and lib.earFacing(instance) == 'front' then return end
    local ed = earDir(instance)
    local backEar = ed ~= 0 and instance.parts and instance.parts[ed > 0 and 'lear' or 'rear']
    if backEar and backEar.body and not backEar.body:isDestroyed() then
        for _, fixture in ipairs(backEar.body:getFixtures()) do
            local ud = fixture:getUserData()
            if ud and ud.extra and ud.extra.zOffset == 190 then ud.extra.zOffset = BACK_EAR_Z end
        end
    end
    for partName, kind in pairs(KIND) do
        local part = instance.parts and instance.parts[partName]
        local map = lib.isFar(instance, partName) and FAR_Z[kind]
        if map and part and part.body and not part.body:isDestroyed() then
            for _, fixture in ipairs(part.body:getFixtures()) do
                local ud = fixture:getUserData()
                local z = ud and ud.extra and ud.extra.zOffset
                local new = z and map[z]
                if new then ud.extra.zOffset = new end
            end
        end
    end
end

return lib

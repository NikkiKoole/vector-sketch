-- src/mipo-balance.lua (split from character-manager.lua, SPLIT2)
local lib = {}

local utils = require('src.utils')
local mathutils = require('src.math-utils')
local ST = require('src.shape-types')
local JT = require('src.joint-types')
local mipoRegistry = require('src.mipo-registry')
local D = require('src.dna-defaults')

-- Arms are thin capsules under big hands and next to a big torso: by area alone a segment
-- weighed 1/40 of its hand and 1/80 of the torso (2eJYpY). Box2D chains past ~10:1 stretch
-- and lag; a hand snapped to a hold let the body slide 1000 units away on a stretched arm.
-- So each arm segment weighs at least this share of its hand and of the torso (the larger),
-- by density only: looks and collisions stay the same.
lib.armMinShare = { hand = 1 / 6, torso = 1 / 12 }

local arms = {
    { 'luarm', 'llarm', hand = 'lhand' },
    { 'ruarm', 'rlarm', hand = 'rhand' },
}

-- `share` (optional) instead of lib.armMinShare: to try values on live Mipos from the bridge.
function lib.balanceArms(instance, share)
    share = share or lib.armMinShare
    local torso = instance.parts.torso1
    if not (torso and torso.body and not torso.body:isDestroyed()) then return end
    for _, arm in ipairs(arms) do
        local hand = instance.parts[arm.hand]
        local handMass = (hand and hand.body and not hand.body:isDestroyed()) and hand.body:getMass() or 0
        local minMass = math.max(handMass * share.hand, torso.body:getMass() * share.torso)
        for _, name in ipairs(arm) do
            local part = instance.parts[name]
            if part and part.body and not part.body:isDestroyed() then
                local mass = part.body:getMass()
                if mass > 0 and mass < minMass then
                    for _, f in ipairs(part.body:getFixtures()) do
                        if not f:getUserData() then f:setDensity(f:getDensity() * minMass / mass) end
                    end
                    part.body:resetMassData()
                end
            end
        end
    end
end

-- A head weighs at most this many times the torso (all its segments). By area a big head
-- weighed up to 5x its torso (1C4UIs; CnANW 2.3x fell head first and was dazed over and
-- over): the Mipo tipped onto it and its light legs couldn't lift it. Density only, so a
-- big head still looks big.
lib.headMaxShare = 1.5

-- `share` (optional) instead of lib.headMaxShare: to try values on live Mipos from the bridge.
function lib.balanceHead(instance, share)
    share = share or lib.headMaxShare
    local head = instance.parts.head
    if not (head and head.body and not head.body:isDestroyed()) then return end
    local torsoMass = 0
    for i = 1, (instance.dna.creation.torsoSegments or 1) do
        local torso = instance.parts['torso' .. i]
        if torso and torso.body and not torso.body:isDestroyed() then torsoMass = torsoMass + torso.body:getMass() end
    end
    local mass, maxMass = head.body:getMass(), torsoMass * share
    if torsoMass > 0 and mass > maxMass then
        for _, f in ipairs(head.body:getFixtures()) do
            if not f:getUserData() then f:setDensity(f:getDensity() * maxMass / mass) end
        end
        head.body:resetMassData()
    end
end

-- A long neck under a big head (3BjZpF: 5 segments, each 1/7 of the head) hung to the side:
-- the light chain stretched past its limits. What held it (tested together; neither alone
-- did): each neck segment weighs at least neckMinShare of the head (density only), and keeps
-- itself upright (KEEP_ANGLE, as torso segments do; applyNeck). Head 200 -> 30 to the side.
lib.neckMinShare = 1 / 4

function lib.balanceNeck(instance, share)
    share = share or lib.neckMinShare
    local head = instance.parts.head
    if not (head and head.body and not head.body:isDestroyed()) then return end
    local minMass = head.body:getMass() * share
    for i = 1, (instance.dna.creation.neckSegments or 0) do
        local part = instance.parts['neck' .. i]
        if part and part.body and not part.body:isDestroyed() then
            local mass = part.body:getMass()
            if mass > 0 and mass < minMass then
                for _, f in ipairs(part.body:getFixtures()) do
                    if not f:getUserData() then f:setDensity(f:getDensity() * minMass / mass) end
                end
                part.body:resetMassData()
            end
        end
    end
end

-- How far a whole neck may bend, spread over its joints (none looser than the template's
-- 22.5 degrees, so 1-2 segments are as before): 5 joints of 22.5 let a neck fold 110 degrees
-- under its head and lie sideways (head 150-220 to the side, 3 random Mipos); 45 over 5
-- joints held it at 40-60.
lib.neckBend = 45

-- A segmented physics nose is a trunk: each joint bends this far (degrees). The template's
-- 5.6 made a 5-segment nose a stiff stick; Nikki wants it to hang and swing (2026-10-29).
lib.trunkBend = 30

-- Trunk limits on a segmented nose's DNA (built and loaded Mipos alike).
function lib.applyTrunk(instance)
    local creation = instance.dna.creation
    if (creation.noseSegments or 0) < 2 and creation.noseMode ~= 'physics' then return end
    local bend = math.rad(lib.trunkBend)
    for i = 1, creation.noseSegments or 0 do
        local part = instance.dna.parts['nose' .. i]
        if part and part.j and part.shape ~= ST.SHAPE8 then part.j.limits = { low = -bend, up = bend } end
    end
end

-- Neck segments keep themselves upright (see balanceNeck). Behaviors are the part's
-- thing.behaviors (from the DNA when built, saved with the body); `things` = true also sets
-- them on the built parts (a scene saved before this).
function lib.applyNeck(instance, things)
    local count = instance.dna.creation.neckSegments or 0
    local template = instance.dna.parts['neck-segment-template']
    local templateBend = template and template.j and template.j.limits and template.j.limits.up or math.pi / 8
    for i = 1, count do
        local name = 'neck' .. i
        local dnaPart = instance.dna.parts[name]
        if dnaPart and not (dnaPart.behaviors and dnaPart.behaviors[1]) then
            dnaPart.behaviors = { { name = 'KEEP_ANGLE', angle = 0, kp = 40 } }
        end
        if dnaPart and dnaPart.j then -- the bend budget (neckBend), from the template's own range
            local bend = math.min(templateBend, math.rad(lib.neckBend) / count)
            dnaPart.j.limits = { low = -bend, up = bend }
        end
        local part = things and instance.parts[name]
        if part and not (part.behaviors and part.behaviors[1]) then
            part.behaviors = { { name = 'KEEP_ANGLE', angle = 0, kp = 40 } }
        end
    end
end

-- A Mipo loaded in a pose its joints don't allow got yanked together by Box2D in one step and
-- fell over (3BjZpF stood rebuilt, fell loaded): saved while flailing, its joints pulled
-- apart (the nose tip 238 off, the neck 64), and saved bent past a limit that has changed
-- since (a neck at 25 degrees a joint, its limit now 9). Parents first, each part and
-- everything that hangs from it is moved onto its parent's anchor, then turned back inside
-- its limits about the joint, as a rebuild would assemble it.
local subtreeOf = mipoRegistry.subtreeBodies

function lib.settlePose(instance)
    for _, entry in ipairs(instance.topology or {}) do
        local part, parent = instance.parts[entry.name], entry.parent and instance.parts[entry.parent]
        if part and parent and part.body and parent.body and not part.body:isDestroyed() then
            for _, joint in ipairs(part.body:getJoints()) do
                local a, b = joint:getBodies()
                if a == parent.body and b == part.body then
                    local x1, y1, x2, y2 = joint:getAnchors()
                    if math.abs(x1 - x2) + math.abs(y1 - y2) > 0.5 then
                        for _, body in ipairs(subtreeOf(instance, entry.name, {})) do
                            local x, y = body:getPosition()
                            body:setPosition(x + x1 - x2, y + y1 - y2)
                        end
                    end
                end
                if a == parent.body and b == part.body and joint:getType() == 'revolute'
                    and joint:areLimitsEnabled() then
                    local angle = joint:getJointAngle()
                    local target = mathutils.clamp(angle, joint:getLowerLimit(), joint:getUpperLimit())
                    local turn = target - angle
                    if math.abs(turn) > 1e-3 then
                        local ax, ay = joint:getAnchors()
                        local c, s = math.cos(turn), math.sin(turn)
                        for _, body in ipairs(subtreeOf(instance, entry.name, {})) do
                            local x, y = body:getPosition()
                            local dx, dy = x - ax, y - ay
                            body:setPosition(ax + dx * c - dy * s, ay + dx * s + dy * c)
                            body:setAngle(body:getAngle() + turn)
                            body:setAngularVelocity(0)
                        end
                    end
                end
            end
        end
    end
end

-- Part masses that by area alone make a Mipo hard to move: a heavy head, thin arms and neck.
function lib.balanceMasses(instance)
    lib.balanceHead(instance)
    lib.balanceArms(instance)
    lib.balanceNeck(instance)
end

-- A spine (creation.torsoSpine, docs/MIPO-SPINE.md): the torso segments are bands of
-- torso1's shape (part.spineBand, read by topology.shape8Vertices), the upper ones bend
-- on a spring (mipo-actions, spineSpring) instead of each keeping its own angle.
-- Without it, the segments are whole torsos again, each with KEEP_ANGLE.
function lib.applySpine(instance)
    local creation = instance.dna.creation
    local count = creation.torsoSegments or 1
    local spine = creation.torsoSpine and count > 1
    local base = instance.dna.parts.torso1
    for i = 1, count do
        local part = instance.dna.parts['torso' .. i]
        if part then
            part.spineBand = spine and { i, count } or nil
            if i > 1 then
                if spine then
                    part.shape8URL = base.shape8URL
                    part.dims = utils.deepCopy(base.dims)
                    part.behaviors = {}
                    local bend = math.rad(creation.spineBend or D.creation.spineBend)
                    part.j = { type = JT.REVOLUTE, limits = { low = -bend, up = bend } }
                elseif not (part.behaviors and part.behaviors[1]) then
                    part.behaviors = { { name = 'KEEP_ANGLE', angle = 0 } }
                end
            end
        end
    end
end


return lib

-- mipo-stance.lua — muscles in the joints a Mipo stands with: ankles and (facing a side) knees
-- (Nikki, 2026-11-10: Mipos left on a heel or a toe tip after a hop, and some facing a side that
-- couldn't stand). An engine system (src/systems.lua); spec/feet-hop_spec.lua.
--
-- Ankles: a motor holds each foot square to its shin as the leg muscle (KEEP_ANGLE) aims the shin:
-- on the ground the leg stands upright over a flat foot, in the air the foot follows the leg.
-- Before, the ankle was limp inside its limits (±22.5 deg): a foot stayed wherever it landed, held
-- by its grip, and a Mipo facing a side (both feet pointing one way, a base one foot long) tipped
-- over its feet with the ankle as the pivot. Tried first: pulling each foot level with the world.
-- It levered the planted foot's shin (both the same way facing a side: Mipos leant 5-20 deg) and,
-- limp near level to stop that, left the ankle a pivot again.
--
-- Knees: the leg muscles set each leg part's spin directly, and the joints then share that out by
-- mass: a heavy torso wins. Facing front the two knees bend opposite ways and their limits brace
-- each other; facing a side both bend the same way (hip 0..90, knee -90..0: a straight leg is at
-- the edge of both), and some Mipos sat down into a squat, hopped up (the stand-up hop) and sat
-- down again. A motor in the knee is solved with the joint, so it holds against the body's weight.
-- It holds the bend the leg muscles ask for (shin target minus thigh target).
--
-- Strengths are shares of the Mipo's weight held at the end of the foot / thigh. Measured with 20
-- random Mipos facing front and left (standing) and spec/feet-hop_spec (hops): without these, 3 of
-- 20 facing a side squatted and hopped, 3 facing front stood knees bent; with them none. Stronger
-- (ankle 0.3+, knees facing front too) stood the same and fell over more after hops.
--
-- Resting (motor off): while the walk drives legs and feet (inst._walking, src/mipo-walk.lua); a
-- ragdoll or a flipped Mipo; a part whose leg muscle is off or limp (a jump's crouch, dazed, held);
-- a foot with a muscle of its own (a rider's feet, scripts/spikes/tracks); and a Mipo whose legs
-- the scene poses: held off walking (mipoWalk.hold, the facing spike's sitting) or ankles freed
-- (limits off: rides, soapbox, bike put feet on pedals and boards past their range).
local mipoRegistry = require('src.mipo-registry')
local facing = require('src.mipo-facing')
local mathutils = require('src.math-utils')
local utils = require('src.utils')
local behaviors = require('src.behaviors')

local lib = {}

lib.ankles = true
lib.ankleStrength = 0.15
lib.ankleGain = 12       -- motor speed (rad/s) per radian off its aim

lib.knees = true
lib.kneesFront = false   -- facing front too (the knees brace each other there already)
lib.kneeStrength = 0.25
lib.kneeGain = 12

-- A foot's flat angle: built a quarter turn from its shin (src/mipo-build.lua footRest).
local FLAT = { lfoot = math.pi / 2, rfoot = -math.pi / 2 }
local FEET = { 'lfoot', 'rfoot' }
local KNEES = { { thigh = 'luleg', shin = 'llleg' }, { thigh = 'ruleg', shin = 'rlleg' } }

-- the revolute joint that hangs `body` from its parent
local function jointTo(body)
    for _, joint in ipairs(body:getJoints()) do
        local _, b = joint:getBodies()
        if b == body and joint:getType() == 'revolute' then return joint end
    end
end

local function motorOff(joint)
    if joint and joint:isMotorEnabled() then joint:setMotorEnabled(false) end
end

-- the longest reach of a body's collision shapes (a foot's length, a thigh's)
local function reach(body)
    local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
    for _, fixture in ipairs(body:getFixtures()) do
        if not fixture:getUserData() then
            local tx, ty, bx, by = fixture:getBoundingBox(1)
            x1, y1, x2, y2 = math.min(x1, tx), math.min(y1, ty), math.max(x2, bx), math.max(y2, by)
        end
    end
    if x1 == math.huge then return 0 end
    return math.max(x2 - x1, y2 - y1)
end

local function liveBody(inst, name)
    local part = inst.parts and inst.parts[name]
    local body = part and part.body
    if body and not body:isDestroyed() then return body end
end

-- Drive `joint` toward `err` (radians the child should still turn relative to its parent).
local function drive(joint, err, gain, torque)
    joint:setMotorEnabled(true)
    joint:setMotorSpeed(gain * err)
    joint:setMaxMotorTorque(torque)
end

-- a part's leg muscle target (radians, world), or nil while it is off or the part limp
local function muscle(body)
    local thing = utils.thingOf(body)
    if not thing or thing.limp then return nil end
    local b = behaviors.find(body, 'KEEP_ANGLE')
    if not b or b.enabled == false then return nil end
    return math.rad(b.angle or 0)
end

-- the scene poses this Mipo's legs: held off walking, or its ankles freed
local function scenePosed(inst)
    if inst._noWalk then return true end
    for _, name in ipairs(FEET) do
        local foot = liveBody(inst, name)
        local ankle = foot and jointTo(foot)
        if ankle and not ankle:areLimitsEnabled() then return true end
    end
    return false
end

local function updateAnkles(inst, off, weight)
    for _, name in ipairs(FEET) do
        local foot = liveBody(inst, name)
        local ankle = foot and jointTo(foot)
        if ankle then
            local entry = inst.entryMap and inst.entryMap[name]
            local shin = entry and liveBody(inst, entry.parent)
            local shinAim = shin and muscle(shin)
            if off or not lib.ankles or not shinAim or muscle(foot) then
                motorOff(ankle)
            else
                local flat = FLAT[facing.source(inst, name)] or FLAT[name]
                local err = mathutils.wrapAngle((flat - shinAim) - (foot:getAngle() - shin:getAngle()))
                drive(ankle, err, lib.ankleGain, lib.ankleStrength * weight() * reach(foot))
            end
        end
    end
end

local function updateKnees(inst, off, weight)
    local useKnees = lib.knees and (lib.kneesFront or facing.get(inst) ~= 'front')
    for _, leg in ipairs(KNEES) do
        local thigh, shin = liveBody(inst, leg.thigh), liveBody(inst, leg.shin)
        local knee = shin and jointTo(shin)
        if knee then
            local thighAim = thigh and muscle(thigh)
            local shinAim = muscle(shin)
            if off or not useKnees or not thighAim or not shinAim then
                motorOff(knee)
            else
                local bend = mathutils.wrapAngle((shinAim - thighAim) - (shin:getAngle() - thigh:getAngle()))
                drive(knee, bend, lib.kneeGain, lib.kneeStrength * weight() * reach(thigh))
            end
        end
    end
end

function lib.update()
    local gravity = 9.8 * love.physics.getMeter()
    for _, inst in pairs(mipoRegistry.getAll()) do
        local off = inst._walking or inst._isRagdoll or inst._isFlipped or scenePosed(inst)
        local w
        local function weight()
            w = w or mipoRegistry.totalMass(inst) * gravity
            return w
        end
        updateAnkles(inst, off, weight)
        updateKnees(inst, off, weight)
    end
end

return lib

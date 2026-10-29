-- mipo-actions.lua
-- Physical actions for a Mipo: breathe, jump, ragdoll (limp), flip (handstand).
-- Moved out of the Mipo editor's actions accordion (src/ui/mipo-editor.lua) so
-- scene scripts and reactions can use them too (docs/DOLL-PLAY.md).
--
-- Actions work by toggling the KEEP_ANGLE behaviors on the parts (src/keep-angle.lua):
-- enabled = false makes a part limp, enabled = nil (default) keeps it upright.
local mipoRegistry = require('src.mipo-registry')
local box2dPointerJoints = require('src.physics.box2d-pointerjoints')
local units = require('src.physics-units')
local contactTracker = require('src.physics.contact-tracker')

local lib = {}

-- Speeds, gains and the breath impulse below are as tuned at 100 px per metre;
-- src/physics-units.lua turns them into the world's meter where they are used.

-- Jump speed (world units/s) for the whole Mipo; the impulse scales with its
-- mass. A fixed 4000 impulse lifted a heavy Mipo (mass 36) only ~20 units.
lib.jumpSpeed = 1200

local function totalMass(instance)
    local mass = 0
    for _, part in pairs(instance.parts) do
        if part.body and not part.body:isDestroyed() then mass = mass + part.body:getMass() end
    end
    return mass
end

local legPartNames = { 'luleg', 'ruleg', 'llleg', 'rlleg' }
local armPartNames = { 'luarm', 'ruarm', 'llarm', 'rlarm' }

function lib.getKeepAngle(part)
    if not (part and part.body and not part.body:isDestroyed()) then return nil end
    local ud = part.body:getUserData()
    if not (ud and ud.thing and ud.thing.behaviors) then return nil end
    for _, b in ipairs(ud.thing.behaviors) do
        if b.name == 'KEEP_ANGLE' then return b end
    end
    return nil
end

function lib.ensureKeepAngle(part, angle, kp)
    if not (part and part.body and not part.body:isDestroyed()) then return nil end
    local ud = part.body:getUserData()
    if not (ud and ud.thing) then return nil end
    ud.thing.behaviors = ud.thing.behaviors or {}
    local b = lib.getKeepAngle(part)
    if b then return b end
    b = { name = 'KEEP_ANGLE', angle = angle or 0, kp = kp or 40, enabled = false }
    table.insert(ud.thing.behaviors, b)
    return b
end

local function anything() return true end
local groundParts = { 'lfoot', 'rfoot', 'llleg', 'rlleg' }

-- A foot or lower leg touches something (anything, sensors too).
function lib.isGrounded(instance)
    for _, pname in ipairs(groundParts) do
        local p = instance.parts and instance.parts[pname]
        if p and p.body and not p.body:isDestroyed() and contactTracker.any(p.body, anything) then
            return true
        end
    end
    return false
end

-- Torso, head, extra torso and neck segments: the parts a flip turns over.
local function corePartNames(instance)
    local creation = instance.dna.creation
    local names = { 'torso1', 'head' }
    for i = 2, (creation.torsoSegments or 1) do table.insert(names, 'torso' .. i) end
    for i = 1, (creation.neckSegments or 0) do table.insert(names, 'neck' .. i) end
    return names
end

function lib.breathe(instance)
    local torso = instance.parts and instance.parts.torso1
    if torso and torso.body and not torso.body:isDestroyed() then
        torso.body:applyLinearImpulse(0, units.impulse(-1000))
    end
end

-- Crouch wind-up (legs go limp for 0.1s), then the jump fires from lib.update.
function lib.jump(instance)
    if not lib.isGrounded(instance) or instance._jumpAt then return false end
    if not instance._isRagdoll then
        for _, pname in ipairs(legPartNames) do
            local b = lib.getKeepAngle(instance.parts[pname])
            if b then b.enabled = false end
        end
    end
    instance._jumpAt = love.timer.getTime() + 0.1
    return true
end

local function fireJump(instance)
    instance._jumpAt = nil
    local torso = instance.parts and instance.parts.torso1
    if torso and torso.body and not torso.body:isDestroyed() then
        torso.body:applyLinearImpulse(0, -totalMass(instance) * units.speed(lib.jumpSpeed))
    end
    if not instance._isRagdoll then
        local flipped = instance._isFlipped
        for _, pname in ipairs(legPartNames) do
            local b = lib.getKeepAngle(instance.parts[pname])
            if b then
                if flipped then
                    b.enabled = false
                else
                    b.enabled = nil
                end
            end
        end
    end
end

function lib.isRagdoll(instance)
    return instance._isRagdoll or false
end

-- Ragdoll on: every KEEP_ANGLE off (fully limp). Off: restore what the flip
-- state wants (upright legs, or upright arms when flipped).
function lib.setRagdoll(instance, on)
    if on == lib.isRagdoll(instance) then return end
    local names = corePartNames(instance)
    for _, pn in ipairs(legPartNames) do table.insert(names, pn) end
    for _, pn in ipairs(armPartNames) do table.insert(names, pn) end

    if on then
        for _, pname in ipairs(names) do
            local b = lib.getKeepAngle(instance.parts[pname])
            if b then b.enabled = false end
        end
        instance._isRagdoll = true
    else
        local flipped = instance._isFlipped
        for _, pname in ipairs(names) do
            local b = lib.getKeepAngle(instance.parts[pname])
            if b then
                local isLeg = pname == 'luleg' or pname == 'ruleg' or pname == 'llleg' or pname == 'rlleg'
                local isArm = pname == 'luarm' or pname == 'ruarm' or pname == 'llarm' or pname == 'rlarm'
                if isLeg then
                    if flipped then b.enabled = false else b.enabled = nil end
                elseif isArm then
                    if flipped then b.enabled = nil else b.enabled = false end
                else
                    b.enabled = nil
                end
            end
        end
        instance._isRagdoll = false
    end
end

function lib.isFlipped(instance)
    return instance._isFlipped or false
end

-- Flip on: torso/head turned over by pi, arms point down to stand on, legs limp.
-- Off: the reverse. While ragdolled only the targets change, no snapping.
function lib.setFlipped(instance, on)
    if on == lib.isFlipped(instance) then return end
    local flipPartNames = corePartNames(instance)
    local ragdolled = lib.isRagdoll(instance)

    if on then
        for _, pname in ipairs(flipPartNames) do
            local part = instance.parts[pname]
            if part and part.body and not part.body:isDestroyed() then
                local b = lib.getKeepAngle(part)
                if b then b.angle = b.angle + 180 end
                if not ragdolled then
                    part.body:setAngle(part.body:getAngle() + math.pi)
                end
            end
        end
        local armTargets = { luarm = 350, ruarm = 10, llarm = 350, rlarm = 10 }
        for pname, targetDeg in pairs(armTargets) do
            local part = instance.parts[pname]
            if part and part.body and not part.body:isDestroyed() then
                local b = lib.ensureKeepAngle(part, targetDeg, 200)
                if b then b.angle = targetDeg; b.maxOmega = 50 end
                if not ragdolled then
                    part.body:setAngle(math.rad(targetDeg))
                    if b then b.enabled = nil end
                end
            end
        end
        if not ragdolled then
            for _, pname in ipairs(legPartNames) do
                local b = lib.getKeepAngle(instance.parts[pname])
                if b then b.enabled = false end
            end
        end
        instance._isFlipped = true
    else
        for _, pname in ipairs(flipPartNames) do
            local part = instance.parts[pname]
            if part and part.body and not part.body:isDestroyed() then
                local b = lib.getKeepAngle(part)
                if b then
                    b.angle = b.angle - 180
                    if not ragdolled then
                        part.body:setAngle(math.rad(b.angle))
                    end
                else
                    if not ragdolled then
                        part.body:setAngle(part.body:getAngle() + math.pi)
                    end
                end
            end
        end
        if not ragdolled then
            for _, pname in ipairs(legPartNames) do
                local part = instance.parts[pname]
                local b = lib.getKeepAngle(part)
                if b then
                    if part and part.body and not part.body:isDestroyed() then
                        part.body:setAngle(math.rad(b.angle or 0))
                    end
                    b.enabled = nil
                end
            end
            for _, pname in ipairs(armPartNames) do
                local b = lib.getKeepAngle(instance.parts[pname])
                if b then b.enabled = false end
            end
        end
        instance._isFlipped = false
    end
end

-- Dazed: a hard landing knocks a Mipo limp for a moment; then it straightens
-- up again (and the stand-up hop in src/mipo-joint-guard.lua gets it on its feet).
lib.daze = true
-- (impact speeds come from src/mipo-voice.lua already at 100 px per metre, src/physics-units.lua)
lib.dazeSpeed = 2000      -- impact speed that dazes (the 'oof' starts at 1200)
lib.dazeMin = 1.0         -- seconds limp for a hit at dazeSpeed
lib.dazeMax = 2.5         -- seconds limp for the hardest hits, and the cap
lib.dazeHardSpeed = 6000  -- impact speed that gives dazeMax

function lib.isDazed(instance)
    return instance._dazedUntil ~= nil
end

function lib.onHardImpact(instance, speed)
    if not lib.daze or speed < lib.dazeSpeed then return end
    local t = math.min(1, (speed - lib.dazeSpeed) / (lib.dazeHardSpeed - lib.dazeSpeed))
    local duration = lib.dazeMin + (lib.dazeMax - lib.dazeMin) * t
    local now = love.timer.getTime()
    if not instance._dazedUntil then
        -- only undo a ragdoll the daze made itself, never one switched on by hand
        if lib.isRagdoll(instance) then return end
        lib.setRagdoll(instance, true)
        instance._dazeStart = now
        instance._dazedUntil = now + duration
    else
        -- another hard hit while dazed: longer, up to dazeMax from the first hit
        instance._dazedUntil = math.min(math.max(instance._dazedUntil, now + duration),
            instance._dazeStart + lib.dazeMax)
    end
end

local function wakeUp(instance)
    instance._dazedUntil = nil
    instance._dazeStart = nil
    lib.setRagdoll(instance, false)
end

-- Held limb goes limp: while a pointer holds an arm or leg part, that whole
-- limb is slack (thing.limp, honoured by src/keep-angle.lua); the rest of the
-- body keeps its pose. Separate from the enabled flags that ragdoll/flip/daze use.
lib.limpHeldLimb = true

local limbs = {
    larm = { 'luarm', 'llarm', 'lhand' },
    rarm = { 'ruarm', 'rlarm', 'rhand' },
    lleg = { 'luleg', 'llleg', 'lfoot' },
    rleg = { 'ruleg', 'rlleg', 'rfoot' },
}
local limbOfPart = {}
for limb, parts in pairs(limbs) do
    for _, name in ipairs(parts) do limbOfPart[name] = limb end
end

function lib.limbOf(partName)
    return limbOfPart[partName]
end

-- Idle: when nobody touches a Mipo it breathes (a tiny torso lift now and then)
-- and every so often slumps (knees give for a moment, then it straightens).
lib.idle = true
lib.idleAfter = 1.5            -- seconds after the last touch before idling starts
lib.breatheEvery = { 3, 4.5 }  -- seconds between breaths (random in range)
lib.breatheSpeed = 60          -- breath lift (world units/s for the whole Mipo)
lib.slumpEvery = { 45, 90 }    -- seconds between slumps (12-25 was too often)
lib.slumpFor = 0.5             -- seconds the knees stay slack
lib.slumpPush = 350            -- downward push at the start (straight limp legs don't buckle alone);
                               -- measured: 250 = 20 deg dip, 350 = 30 deg, 500 collapses (hops to get up)

local function randomIn(range)
    return range[1] + love.math.random() * (range[2] - range[1])
end

local function canIdle(instance, now)
    return lib.idle and not instance._isRagdoll and not instance._isFlipped
        and not instance._dazedUntil and not instance._jumpAt
        and (not instance._lastHeld or now - instance._lastHeld > lib.idleAfter)
        and lib.isGrounded(instance)
end

local function updateIdle(instance, now)
    if not canIdle(instance, now) then
        instance._nextBreath, instance._nextSlump, instance._slumpUntil = nil, nil, nil
        return
    end
    instance._nextBreath = instance._nextBreath or now + randomIn(lib.breatheEvery)
    instance._nextSlump = instance._nextSlump or now + randomIn(lib.slumpEvery)
    if now >= instance._nextBreath then
        local torso = instance.parts.torso1
        if torso and torso.body and not torso.body:isDestroyed() then
            torso.body:applyLinearImpulse(0, -totalMass(instance) * units.speed(lib.breatheSpeed))
        end
        instance._nextBreath = now + randomIn(lib.breatheEvery)
    end
    if now >= instance._nextSlump then
        local torso = instance.parts.torso1
        if torso and torso.body and not torso.body:isDestroyed() then
            torso.body:applyLinearImpulse(0, totalMass(instance) * units.speed(lib.slumpPush))
        end
        instance._slumpUntil = now + lib.slumpFor
        instance._nextSlump = now + randomIn(lib.slumpEvery)
    end
    if instance._slumpUntil and now >= instance._slumpUntil then instance._slumpUntil = nil end
end

-- Arms hang: arms have no KEEP_ANGLE, so they swung free and often both ended
-- up on one side. A soft spring (bounded torque) pulls each arm toward hanging
-- slightly outward on its own side; it still swings with the body.
-- Angles are world angles: 0 = hanging straight down, + = toward the left.
lib.armHang = true
lib.armHangAngle = 15   -- degrees outward from straight down
lib.armHangKp = 40      -- spring (1/s^2)
lib.armHangKd = 12      -- damping (1/s)
lib.armHangMaxAlpha = 80 -- rad/s^2 cap, keeps it soft

-- Knot rescue: an arm flung straight up ends tipped just past vertical over the
-- head, the hand's weight (five times the forearm's) holding the shoulder against
-- its limit. The hang spring is scaled for the upper arm alone and can't lift it,
-- so the arm stayed there. Like a Mipo noticing: after knotAfter seconds pointing
-- up (within knotUp of straight up, the shoulder within knotLimit of its limit) it
-- sorts the arm out: the shoulder spring moves the whole arm (upper arm, forearm,
-- hand; its push-back lands on the heavy torso) until the arm hangs (within
-- knotDone of straight down), for at most knotPull seconds, then that arm rests
-- knotRest seconds. It has to finish: let go halfway, the folded hand's weight
-- pulled the arm back up. Not always on: a whole-arm pull on arms pinned in a pile
-- pumped energy in until Mipos flew out of the box (spec/mipo-arm-knot_spec.lua).
lib.knotRescue = true
-- rescues started; a local the functions hold, since a hot reload doesn't show
-- them tables added to lib (lume.hotswap)
local knotStats = { knots = 0 }
lib.stats = knotStats
lib.knotUp = 40         -- degrees from straight up that count as 'up'
lib.knotLimit = 25      -- degrees from the shoulder's limit
lib.knotAfter = 1.5     -- seconds up before the Mipo does something about it
lib.knotDone = 60       -- degrees from straight down that count as hanging again
lib.knotPull = 2.5      -- seconds of pulling at most
lib.knotRest = 2.0      -- seconds before the same arm is pulled again
lib.knotMaxAlpha = 12   -- rad/s^2 cap for the whole-arm pull: lifts the hand without a snap

local armParent = { luarm = 'torso1', ruarm = 'torso1', llarm = 'luarm', rlarm = 'ruarm' }

-- The part an arm segment hangs from: upper arms from the top torso segment.
local function armParentOf(instance, name)
    local parent = armParent[name]
    if parent == 'torso1' then
        local creation = instance.dna and instance.dna.creation
        return 'torso' .. ((creation and creation.torsoSegments) or 1)
    end
    return parent
end

local function jointBetween(parentBody, childBody)
    for _, joint in ipairs(childBody:getJoints()) do
        if joint:getType() == 'revolute' then
            local bodyA, bodyB = joint:getBodies()
            if bodyA == parentBody and bodyB == childBody then return joint end
        end
    end
    return nil
end

-- Inertia of the bodies hanging from a joint, about the joint's anchor.
local function chainInertia(bodies, ax, ay)
    local total = 0
    for _, body in ipairs(bodies) do
        if not body:isDestroyed() then
            local cx, cy = body:getWorldCenter()
            total = total + body:getInertia() + body:getMass() * ((cx - ax) ^ 2 + (cy - ay) ^ 2)
        end
    end
    return total
end

-- Steer a part toward a world angle through its joint to the parent: the target
-- is moved into the joint's allowed range, so the part goes the long way round
-- instead of pushing against a limit (shortest-path steering left right arms
-- stuck pointing left). `chain` (optional): the bodies that swing with the part;
-- the torque is then scaled to move all of them, not just the part.
function lib.steerJointToward(parentBody, childBody, targetWorldAngle, kp, kd, maxAlpha, chain)
    local joint = jointBetween(parentBody, childBody)
    if not joint then return end -- not joined (was a call to a steerToward that didn't exist)
    kp, kd, maxAlpha = units.accel(kp), units.rate(kd), units.accel(maxAlpha) -- 1/s^2, 1/s, rad/s^2
    local jointAngle = joint:getJointAngle()
    local desired = targetWorldAngle - parentBody:getAngle() - joint:getReferenceAngle()
    local diff
    if joint:areLimitsEnabled() then
        local lower, upper = joint:getLowerLimit(), joint:getUpperLimit()
        local mid = (lower + upper) / 2
        desired = desired - 2 * math.pi * math.floor((desired - mid) / (2 * math.pi) + 0.5)
        desired = math.max(lower, math.min(upper, desired))
        diff = desired - jointAngle
    else
        diff = (desired - jointAngle + math.pi) % (2 * math.pi) - math.pi
    end
    local alpha = kp * diff - kd * (childBody:getAngularVelocity() - parentBody:getAngularVelocity())
    if alpha > maxAlpha then alpha = maxAlpha end
    if alpha < -maxAlpha then alpha = -maxAlpha end
    -- equal and opposite on the parent, like a muscle: a torque on the arm alone
    -- is an outside force that spins the whole Mipo
    local inertia = chain and chainInertia(chain, joint:getAnchors()) or childBody:getInertia()
    local torque = inertia * alpha
    childBody:applyTorque(torque)
    parentBody:applyTorque(-torque)
end

-- Pointing: the arm on the target's side stretches toward it (upper and lower
-- arm aimed the same way); the other arm keeps hanging.
lib.pointKp = 40        -- KEEP_ANGLE gain for the pointing arm (20 drooped: ~45 deg off on average)
lib.pointMaxOmega = 12  -- rad/s cap, so the arm swings up instead of snapping

-- target: { x, y }, 'cursor' (mouse / last touch), a Box2D body, or a function
-- returning x, y. nil stops pointing.
function lib.pointAt(instance, target)
    instance._pointTarget = target
end

function lib.stopPointing(instance)
    instance._pointTarget = nil
end

function lib.isPointing(instance)
    return instance._pointTarget ~= nil
end

local function resolveTarget(target)
    if target == 'cursor' then
        local camera = require('src.camera')
        local touches = love.touch and love.touch.getTouches() or {}
        local sx, sy
        if #touches > 0 then
            sx, sy = love.touch.getPosition(touches[#touches])
        else
            sx, sy = love.mouse.getPosition()
        end
        return camera.getInstance():getWorldCoordinates(sx, sy)
    elseif type(target) == 'function' then
        return target()
    elseif type(target) == 'table' and target.x then
        return target.x, target.y
    elseif type(target) == 'table' then
        return target[1], target[2]
    elseif type(target) == 'userdata' and target.getPosition and not target:isDestroyed() then
        return target:getPosition()
    end
    return nil
end

-- World angle that makes an arm point along (dx, dy): 0 = down, + = toward the left.
function lib.pointAngle(dx, dy)
    return math.atan2(-dx, dy)
end

-- Is this arm in a knot (see knotRescue): the upper arm pointing up, the
-- shoulder at the top of its range?
local function armUp(upperBody, shoulderJoint)
    local fromUp = (upperBody:getAngle() % (2 * math.pi)) - math.pi -- 0 = straight up
    fromUp = (fromUp + math.pi) % (2 * math.pi) - math.pi
    if math.abs(fromUp) > math.rad(lib.knotUp) then return false end
    if not shoulderJoint or not shoulderJoint:areLimitsEnabled() then return true end
    local angle = shoulderJoint:getJointAngle()
    local near = math.rad(lib.knotLimit)
    return angle > shoulderJoint:getUpperLimit() - near or angle < shoulderJoint:getLowerLimit() + near
end

-- Whether the knot rescue pulls this arm now; tracks its timers on the instance.
local function knotPulling(instance, side, upperBody, shoulderJoint)
    if not lib.knotRescue then return false end
    instance._armKnot = instance._armKnot or {}
    local k = instance._armKnot[side] or {}
    instance._armKnot[side] = k
    local now = love.timer.getTime()
    if k.pullUntil then
        local fromDown = (upperBody:getAngle() + math.pi) % (2 * math.pi) - math.pi
        if now < k.pullUntil and math.abs(fromDown) > math.rad(lib.knotDone) then return true end
        k.pullUntil, k.upSince, k.restUntil = nil, nil, now + lib.knotRest
        return false
    end
    if not armUp(upperBody, shoulderJoint) then
        k.upSince = nil
        return false
    end
    k.upSince = k.upSince or now
    if now - k.upSince >= lib.knotAfter and not (k.restUntil and now < k.restUntil) then
        k.pullUntil = now + lib.knotPull
        knotStats.knots = knotStats.knots + 1
        return true
    end
    return false
end

local function steerArm(instance, side, angle, kp, kd, maxAlpha)
    for _, name in ipairs({ side .. 'uarm', side .. 'larm' }) do
        local part = instance.parts[name]
        local parent = instance.parts[armParentOf(instance, name)]
        if part and parent and part.body and parent.body and not part.body:isDestroyed()
            and not parent.body:isDestroyed() and not part.limp then
            local chain
            if name == side .. 'uarm'
                and knotPulling(instance, side, part.body, jointBetween(parent.body, part.body)) then
                chain = { part.body }
                for _, below in ipairs({ side .. 'larm', side .. 'hand' }) do
                    local p = instance.parts[below]
                    if p and p.body then chain[#chain + 1] = p.body end
                end
            end
            lib.steerJointToward(parent.body, part.body, angle, kp, kd,
                chain and math.min(maxAlpha, lib.knotMaxAlpha) or maxAlpha, chain)
        end
    end
end

-- The pointing arm uses KEEP_ANGLE (src/keep-angle.lua), like the legs and the
-- flip's handstand arms: it steers the spin only. Setting arm velocities from
-- here pumped momentum into the Mipo and it flew toward what it pointed at.
local function setArmKeepAngle(instance, side, degrees)
    -- the hand too: hanging loose at the end it dragged the whole arm down
    for _, name in ipairs({ side .. 'uarm', side .. 'larm', side .. 'hand' }) do
        local part = instance.parts[name]
        if part and part.body and not part.body:isDestroyed() then
            local b = lib.ensureKeepAngle(part, degrees or 0, lib.pointKp)
            if b then
                if degrees then
                    b.angle, b.kp, b.maxOmega, b.enabled = degrees, lib.pointKp, lib.pointMaxOmega, nil
                else
                    b.enabled = false
                end
            end
        end
    end
end

local function poseArms(instance)
    if instance._isRagdoll or instance._isFlipped or instance._dazedUntil then return end
    local pointingSide
    if instance._pointTarget then
        local tx, ty = resolveTarget(instance._pointTarget)
        local torso = instance.parts.torso1
        if tx and torso and torso.body and not torso.body:isDestroyed() then
            local cx = torso.body:getPosition()
            -- the Mipo's left (+angle) is screen -x
            pointingSide = (tx < cx) and 'l' or 'r'
            local shoulder = instance.parts[pointingSide .. 'uarm']
            if shoulder and shoulder.body then
                local sx, sy = shoulder.body:getPosition()
                setArmKeepAngle(instance, pointingSide, math.deg(lib.pointAngle(tx - sx, ty - sy)))
            end
        end
    end
    for _, side in ipairs({ 'l', 'r' }) do
        if side ~= pointingSide then
            if instance._pointedSide == side or instance._pointedSide == 'both' then
                setArmKeepAngle(instance, side, nil)
            end
            if lib.armHang then
                local hang = math.rad(lib.armHangAngle) * (side == 'l' and 1 or -1)
                steerArm(instance, side, hang, lib.armHangKp, lib.armHangKd, lib.armHangMaxAlpha)
            end
        end
    end
    instance._pointedSide = pointingSide and 'both' or nil
end

-- Spine (creation.torsoSpine, docs/MIPO-SPINE.md): each spine joint's motor turns it back
-- toward straight (spineReturn: the speed per radian off) with at most spineStrength times
-- the torque that the weight of everything above the joint (bands, neck, head, arms)
-- puts on it, so a landing bends it within the joint's limits and it comes back. Limp
-- while ragdolled or dazed. When idle it sways a little (spineSway).
-- (A torque spring sized for everything above, put on the light band, whipped the band
-- into its limit and tore the joint apart: bent 18 degrees in free fall, 100 on landing.)
lib.spine = true
lib.spineReturn = 6     -- 1/s at 100 px per metre
lib.spineStrength = 1.5 -- times the weight torque above the joint
lib.spineSwayAngle = 4  -- degrees of sway at spineSway 1
lib.spineSwayPeriod = 4 -- seconds

-- Every body in the part's subtree (the part itself too).
local function subtreeBodies(instance, name, out)
    local part = instance.parts[name]
    if part and part.body and not part.body:isDestroyed() then out[#out + 1] = part.body end
    for _, child in ipairs((instance.childrenMap or {})[name] or {}) do subtreeBodies(instance, child, out) end
    return out
end

-- The weight torque everything in `bodies` puts on a joint at (ax, ay), its arm taken as
-- the distance to their centre of mass (the most it can be).
local function weightTorque(bodies, ax, ay)
    local mass, mx, my = 0, 0, 0
    for _, body in ipairs(bodies) do
        local m = body:getMass()
        local cx, cy = body:getWorldCenter()
        mass, mx, my = mass + m, mx + m * cx, my + m * cy
    end
    if mass <= 0 then return 0 end
    local dx, dy = mx / mass - ax, my / mass - ay
    return mass * 9.8 * units.meter() * math.sqrt(dx * dx + dy * dy)
end

local function spineSpring(instance, now)
    local creation = instance.dna and instance.dna.creation
    local count = creation and creation.torsoSpine and creation.torsoSegments or 1
    if not lib.spine or count < 2 then return end
    local limp = instance._isRagdoll or instance._dazedUntil
    local sway = 0
    if (creation.spineSway or 0) > 0 and not (instance._lastHeld and now - instance._lastHeld < lib.idleAfter) then
        instance._swayPhase = instance._swayPhase or love.math.random() * 2 * math.pi
        sway = math.rad(lib.spineSwayAngle) * creation.spineSway
            * math.sin(2 * math.pi * now / lib.spineSwayPeriod + instance._swayPhase) / (count - 1)
    end
    for i = 2, count do
        local parent, part = instance.parts['torso' .. (i - 1)], instance.parts['torso' .. i]
        if parent and part and parent.body and part.body and not parent.body:isDestroyed()
            and not part.body:isDestroyed() then
            local joint = jointBetween(parent.body, part.body)
            if joint then
                if limp then
                    joint:setMotorEnabled(false)
                else
                    local ax, ay = joint:getAnchors()
                    joint:setMotorEnabled(true)
                    joint:setMotorSpeed(units.rate(lib.spineReturn) * (sway - joint:getJointAngle()))
                    joint:setMaxMotorTorque(lib.spineStrength
                        * weightTorque(subtreeBodies(instance, 'torso' .. i, {}), ax, ay))
                end
            end
        end
    end
end

-- Gaze: each Mipo looks at something. An explicit lookAt target first, else
-- what it points at, else the cursor/finger when near, else it looks around.
-- The pupils (src/physics/box2d-draw-textured.lua) read thing.gazeX/gazeY on
-- the face-owner part; the head tilts a little toward the gaze.
lib.gaze = true
lib.gazeCursorRadius = 1000      -- the cursor/finger is noticed within this distance
lib.gazeCursorBoredAfter = 3     -- seconds of a still cursor before they stop caring about it
                                 -- (and look around on their own again); moving it wakes them
lib.gazeWanderEvery = { 1.5, 4 } -- seconds between idle look-arounds
lib.gazeWanderRadius = 500       -- how far around itself it looks when idle
lib.gazeSpeed = 8                -- how fast the gaze follows (1/s)
lib.headTilt = 20                -- max head tilt toward the gaze (degrees)
lib.headTiltRange = 600          -- horizontal distance that gives the full tilt

function lib.lookAt(instance, target)
    instance._lookTarget = target
end

function lib.stopLooking(instance)
    instance._lookTarget = nil
end

-- When the cursor/finger last moved (on screen: the camera moving under a still cursor
-- doesn't count). A finger on the screen always counts as moving.
local cursorSeen = { x = nil, y = nil, movedAt = -math.huge }

local function noteCursor(now)
    local touches = love.touch and love.touch.getTouches() or {}
    if #touches > 0 then
        cursorSeen.movedAt = now
        return
    end
    local x, y = love.mouse.getPosition()
    if cursorSeen.x == nil or math.abs(x - cursorSeen.x) + math.abs(y - cursorSeen.y) > 2 then
        cursorSeen.x, cursorSeen.y, cursorSeen.movedAt = x, y, now
    end
end

function lib.cursorIsInteresting(now)
    return now - cursorSeen.movedAt < lib.gazeCursorBoredAfter
end

local function facePart(instance)
    return instance.parts.head or instance.parts.torso1
end

local function gazeGoal(instance, now)
    local face = facePart(instance)
    if not face or not face.body or face.body:isDestroyed() then return nil end
    local fx, fy = face.body:getPosition()
    local x, y = resolveTarget(instance._lookTarget)
    if x then return x, y end
    x, y = resolveTarget(instance._pointTarget)
    if x then return x, y end
    if lib.cursorIsInteresting(now) then
        x, y = resolveTarget('cursor')
        if x and (x - fx) ^ 2 + (y - fy) ^ 2 < lib.gazeCursorRadius ^ 2 then return x, y end
    end
    if not instance._wanderAt or now >= instance._wanderAt then
        local angle = love.math.random() * 2 * math.pi
        local r = lib.gazeWanderRadius * (0.3 + 0.7 * love.math.random())
        instance._wanderDX, instance._wanderDY = math.cos(angle) * r, math.sin(angle) * r * 0.5
        instance._wanderAt = now + randomIn(lib.gazeWanderEvery)
    end
    return fx + instance._wanderDX, fy + instance._wanderDY
end

local function updateGaze(instance, now)
    local face = facePart(instance)
    if not lib.gaze or not face then return end
    local gx, gy = gazeGoal(instance, now)
    if not gx then return end
    local dt = math.min(0.1, now - (instance._gazeTime or now))
    instance._gazeTime = now
    if not face.gazeX then face.gazeX, face.gazeY = gx, gy end
    local k = math.min(1, lib.gazeSpeed * dt)
    face.gazeX = face.gazeX + (gx - face.gazeX) * k
    face.gazeY = face.gazeY + (gy - face.gazeY) * k

    -- head tilt: top of the head leans toward what it looks at
    local head = instance.parts.head
    local b = head and lib.getKeepAngle(head)
    if b then
        local tilt = 0
        if not instance._isRagdoll and not instance._isFlipped and not instance._dazedUntil then
            local hx = head.body:getPosition()
            local f = math.max(-1, math.min(1, (face.gazeX - hx) / lib.headTiltRange))
            tilt = f * lib.headTilt
        end
        local base = instance._isFlipped and 180 or 0
        b.angle = base + tilt
    end
end

-- A part is limp (thing.limp, honoured by keep-angle) while its limb is held or
-- the Mipo slumps (legs only).
local function updateLimp(now)
    local heldLimbs = {} -- [instance] = { [limb] = true }
    for _, pointerJoint in ipairs(box2dPointerJoints.getPointerJoints()) do
        local body = pointerJoint.jointBody
        if body and not body:isDestroyed() then
            local instance, partName = mipoRegistry.getFromBody(body)
            if instance then
                instance._lastHeld = now
                local limb = limbOfPart[partName]
                if limb and lib.limpHeldLimb then
                    heldLimbs[instance] = heldLimbs[instance] or {}
                    heldLimbs[instance][limb] = true
                end
            end
        end
    end
    for _, instance in pairs(mipoRegistry.getAll()) do
        updateIdle(instance, now)
        updateGaze(instance, now)
        local held = heldLimbs[instance] or {}
        local slumping = instance._slumpUntil ~= nil
        for limb, names in pairs(limbs) do
            local isLeg = limb == 'lleg' or limb == 'rleg'
            for _, name in ipairs(names) do
                local part = instance.parts[name]
                if part then part.limp = (held[limb] or (slumping and isLeg)) or nil end
            end
        end
        poseArms(instance)
        spineSpring(instance, now)
    end
end

-- Pending jumps and dazes resolve here (jumps used to fire only while the
-- editor drew that Mipo).
function lib.update()
    local now = love.timer.getTime()
    noteCursor(now)
    updateLimp(now)
    for _, instance in pairs(mipoRegistry.getAll()) do
        if instance._jumpAt and now >= instance._jumpAt then fireJump(instance) end
        if instance._dazedUntil and now >= instance._dazedUntil then wakeUp(instance) end
    end
end

return lib

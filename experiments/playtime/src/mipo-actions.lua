-- mipo-actions.lua
-- Physical actions for a Mipo: breathe, jump, ragdoll (limp), flip (handstand).
-- Moved out of the Mipo editor's actions accordion (src/ui/mipo-editor.lua) so
-- scene scripts and reactions can use them too (docs/DOLL-PLAY.md).
--
-- Actions work by toggling the KEEP_ANGLE behaviors on the parts (src/keep-angle.lua):
-- enabled = false makes a part limp, enabled = nil (default) keeps it upright.
local mipoRegistry = require('src.mipo-registry')
local box2dPointerJoints = require('src.physics.box2d-pointerjoints')

local lib = {}

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

function lib.isGrounded(instance)
    for _, pname in ipairs({ 'lfoot', 'rfoot', 'llleg', 'rlleg' }) do
        local p = instance.parts and instance.parts[pname]
        if p and p.body and not p.body:isDestroyed() then
            for _, contact in pairs(p.body:getContacts()) do
                if contact:isTouching() then return true end
            end
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
        torso.body:applyLinearImpulse(0, -1000)
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
        torso.body:applyLinearImpulse(0, -totalMass(instance) * lib.jumpSpeed)
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
lib.slumpEvery = { 12, 25 }    -- seconds between slumps
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
            torso.body:applyLinearImpulse(0, -totalMass(instance) * lib.breatheSpeed)
        end
        instance._nextBreath = now + randomIn(lib.breatheEvery)
    end
    if now >= instance._nextSlump then
        local torso = instance.parts.torso1
        if torso and torso.body and not torso.body:isDestroyed() then
            torso.body:applyLinearImpulse(0, totalMass(instance) * lib.slumpPush)
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

local armHangTargets = { luarm = 1, llarm = 1, ruarm = -1, rlarm = -1 } -- side sign
local armParent = { luarm = 'torso1', ruarm = 'torso1', llarm = 'luarm', rlarm = 'ruarm' }

local function jointBetween(parentBody, childBody)
    for _, joint in ipairs(childBody:getJoints()) do
        if joint:getType() == 'revolute' then
            local bodyA, bodyB = joint:getBodies()
            if bodyA == parentBody and bodyB == childBody then return joint end
        end
    end
    return nil
end

-- Steer a part toward a world angle through its joint to the parent: the target
-- is moved into the joint's allowed range, so the part goes the long way round
-- instead of pushing against a limit (shortest-path steering left right arms
-- stuck pointing left).
function lib.steerJointToward(parentBody, childBody, targetWorldAngle, kp, kd, maxAlpha)
    local joint = jointBetween(parentBody, childBody)
    if not joint then
        return lib.steerToward(childBody, targetWorldAngle, kp, kd, maxAlpha)
    end
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
    childBody:applyTorque(childBody:getInertia() * alpha)
end

local function hangArms(instance)
    if not lib.armHang or instance._isRagdoll or instance._isFlipped or instance._dazedUntil then return end
    local target = math.rad(lib.armHangAngle)
    for name, side in pairs(armHangTargets) do
        local part = instance.parts[name]
        local parent = instance.parts[armParent[name]]
        if part and parent and part.body and parent.body and not part.body:isDestroyed()
            and not parent.body:isDestroyed() and not part.limp then
            lib.steerJointToward(parent.body, part.body, side * target,
                lib.armHangKp, lib.armHangKd, lib.armHangMaxAlpha)
        end
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
        local held = heldLimbs[instance] or {}
        local slumping = instance._slumpUntil ~= nil
        for limb, names in pairs(limbs) do
            local isLeg = limb == 'lleg' or limb == 'rleg'
            for _, name in ipairs(names) do
                local part = instance.parts[name]
                if part then part.limp = (held[limb] or (slumping and isLeg)) or nil end
            end
        end
        hangArms(instance)
    end
end

-- Pending jumps and dazes resolve here (jumps used to fire only while the
-- editor drew that Mipo).
function lib.update()
    local now = love.timer.getTime()
    updateLimp(now)
    for _, instance in pairs(mipoRegistry.getAll()) do
        if instance._jumpAt and now >= instance._jumpAt then fireJump(instance) end
        if instance._dazedUntil and now >= instance._dazedUntil then wakeUp(instance) end
    end
end

return lib

-- mipo-actions.lua
-- Physical actions for a Mipo: breathe, jump, ragdoll (limp), flip (handstand).
-- Moved out of the Mipo editor's actions accordion (src/ui/mipo-editor.lua) so
-- scene scripts and reactions can use them too (docs/DOLL-PLAY.md).
--
-- Actions work by toggling the KEEP_ANGLE behaviors on the parts (src/keep-angle.lua):
-- enabled = false makes a part limp, enabled = nil (default) keeps it upright.
local mipoRegistry = require('src.mipo-registry')

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
            for _, contact in pairs(p.body:getContactList()) do
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

-- Pending jumps fire here (they used to fire only while the editor drew that Mipo).
function lib.update()
    local now = love.timer.getTime()
    for _, instance in pairs(mipoRegistry.getAll()) do
        if instance._jumpAt and now >= instance._jumpAt then fireJump(instance) end
    end
end

return lib

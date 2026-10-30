local lib = {}
local registry = require('src.registry')
local utils = require('src.utils')
local units = require('src.physics-units')
local mathutils = require('src.math-utils')
local contactTracker = require('src.physics.contact-tracker')

-- While a part touches another Mipo or a prop, the controller only gets a
-- bounded torque (inertia * maxAlpha) so it yields instead of drilling through.
-- Otherwise it sets the angular velocity directly (full strength): a leg must
-- carry the whole body, and a torque sized by the leg's own inertia let heavy
-- Mipos sink into a split.
lib.maxAlpha = 1000

-- The controller sets omega = kp * error each step: with kp * dt over 1 it overshoots its
-- target every step and the part shakes. kp grows with the meter (src/physics-units.lua;
-- 40 at 100 px per metre is 80 at 400, 1.33 per step): legs splayed, Mipos hopped. Capped here.
lib.maxKpPerStep = 0.9

-- Legs within this of their target are left alone. 0 (off): with foot friction
-- 0.45 the legs settle by themselves; a 15 deg band let heavy Mipos sag into
-- repeated hops (spec/standing_spec.lua).
lib.legDeadband = 0
local deadbandParts = { luleg = true, ruleg = true, llleg = true, rlleg = true }

-- only another Mipo counts (piles); standing on a skateboard or leaning on a ball
-- needs full strength
local function solidOtherMipo(own, other, otherBody, ownMipo)
    if own:isSensor() or other:isSensor() then return false end
    local otherThing = utils.thingOf(otherBody)
    local otherMipo = otherThing and otherThing.mipoId
    return otherMipo ~= nil and otherMipo ~= ownMipo
end

-- Touching another Mipo (props and floors are fine).
local function touchingOthers(body)
    local thing = utils.thingOf(body)
    return contactTracker.any(body, solidOtherMipo, thing and thing.mipoId)
end

-- PD controller on angular velocity
local function rotateBodyTowards(body, dt, targetAngle, data)
    local currentAngle = body:getAngle()
    local diff = math.rad(targetAngle) - currentAngle
    -- wrap to [-pi, pi]
    diff = mathutils.wrapAngle(diff)

    local omega = body:getAngularVelocity()

    local thing = utils.thingOf(body)
    local partName = thing and thing.mipoPartName
    if partName and deadbandParts[partName] and math.abs(diff) < lib.legDeadband then return end

    -- Tunables (or read from data)

    -- (gains as tuned at the reference meter, src/physics-units.lua)
    local kp = units.rate((data and data.kp) or 20.0) -- P gain (1/s)  --was 8
    kp = math.min(kp, lib.maxKpPerStep / math.max(dt or 1 / 60, 1e-4))
    local kd = (data and data.kd) or .000015         -- D gain (unitless) -- was 1.5
    local maxOmega = units.rate((data and data.maxOmega) or 15.0)

    -- PD controller in "omega space"
    local omega_cmd = kp * diff - kd * omega

    -- clamp and apply
    if omega_cmd > maxOmega then omega_cmd = maxOmega end
    if omega_cmd < -maxOmega then omega_cmd = -maxOmega end

    if not touchingOthers(body) then
        body:setAngularVelocity(omega_cmd)
        return
    end

    -- Setting the velocity is infinitely strong: in a pile of Mipos a leg turned
    -- straight through its neighbours, the contact solver shoved them apart, and
    -- the pile gained energy until one was launched out of the world.
    local maxAlpha = units.accel((data and data.maxAlpha) or lib.maxAlpha)
    local alpha = (omega_cmd - omega) / math.max(dt or 1 / 60, 1e-4)
    if alpha > maxAlpha then alpha = maxAlpha end
    if alpha < -maxAlpha then alpha = -maxAlpha end
    body:applyTorque(body:getInertia() * alpha)
end

function lib.update(dt, hitted)
    local bods = registry.bodies
    for _, v in pairs(bods) do
        local thing = utils.thingOf(v)
        if thing and thing.behaviors then
            local behaviors = thing.behaviors
            local same = false
            if hitted and #hitted > 0 then
                for i = 1, #hitted do
                    if (hitted[i].id == thing.id) then
                        same = true
                    end
                end
            end

            for _, vb in pairs(behaviors) do
                -- figure out if im touching this body

                -- thing.limp: temporarily slack (a held Mipo limb, see mipo-actions)
                if vb.name == 'KEEP_ANGLE' and vb.enabled ~= false and not same and not thing.limp then

                    -- Drive the live registry body (v), not thing.body —
                    -- that ref can be stale after a recreate.
                    rotateBodyTowards(v, dt, vb.angle or 0, vb)
                end
            end
        end
    end
end

return lib

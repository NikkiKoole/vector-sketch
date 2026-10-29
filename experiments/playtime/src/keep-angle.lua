local lib = {}
local registry = require 'src.registry'
local units = require('src.physics-units')

-- While a part touches another Mipo or a prop, the controller only gets a
-- bounded torque (inertia * maxAlpha) so it yields instead of drilling through.
-- Otherwise it sets the angular velocity directly (full strength): a leg must
-- carry the whole body, and a torque sized by the leg's own inertia let heavy
-- Mipos sink into a split.
lib.maxAlpha = 1000

-- Legs within this of their target are left alone. 0 (off): with foot friction
-- 0.45 the legs settle by themselves; a 15 deg band let heavy Mipos sag into
-- repeated hops (spec/standing_spec.lua).
lib.legDeadband = 0
local deadbandParts = { luleg = true, ruleg = true, llleg = true, rlleg = true }

-- Touching another Mipo (props and floors are fine).
local function touchingOthers(body)
    local ud = body:getUserData()
    local ownMipo = ud and ud.thing and ud.thing.mipoId
    for _, contact in ipairs(body:getContacts()) do
        if contact:isTouching() then
            local fixtureA, fixtureB = contact:getFixtures()
            if not fixtureA:isSensor() and not fixtureB:isSensor() then
                local other = fixtureA:getBody() == body and fixtureB:getBody() or fixtureA:getBody()
                -- only another Mipo counts (piles); standing on a skateboard or
                -- leaning on a ball needs full strength
                local oud = other:getUserData()
                local otherMipo = oud and oud.thing and oud.thing.mipoId
                if otherMipo and otherMipo ~= ownMipo then return true end
            end
        end
    end
    return false
end

-- PD controller on angular velocity
local function rotateBodyTowards(body, dt, targetAngle, data)
    local currentAngle = body:getAngle()
    local diff = math.rad(targetAngle) - currentAngle
    -- wrap to [-pi, pi]
    diff = (diff + math.pi) % (2 * math.pi) - math.pi

    local omega = body:getAngularVelocity()

    local ud = body:getUserData()
    local partName = ud and ud.thing and ud.thing.mipoPartName
    if partName and deadbandParts[partName] and math.abs(diff) < lib.legDeadband then return end

    -- Tunables (or read from data)

    -- (gains as tuned at the reference meter, src/physics-units.lua)
    local kp = units.rate((data and data.kp) or 20.0) -- P gain (1/s)  --was 8
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
    --logger:inspect(registry.sfixtures)
    local bods = registry.bodies
    for _, v in pairs(bods) do
        local ud = v:getUserData()
        if ud and ud.thing and ud.thing.behaviors then
            local behaviors = ud.thing.behaviors
            local same = false
            if hitted and #hitted > 0 then
                for i = 1, #hitted do
                    if (hitted[i].id == ud.thing.id) then
                        same = true
                    end
                end
            end

            for _, vb in pairs(behaviors) do
                -- figure out if im touching this body

                -- thing.limp: temporarily slack (a held Mipo limb, see mipo-actions)
                if vb.name == 'KEEP_ANGLE' and vb.enabled ~= false and not same and not ud.thing.limp then
                    -- if same then vb.kp = 0.15 end

                    -- Drive the live registry body (v), not ud.thing.body —
                    -- that ref can be stale after a recreate.
                    rotateBodyTowards(v, dt, vb.angle or 0, vb)
                end
            end
        end
    end
    --print('jo trying to keep angle for the ones that have')
end

return lib

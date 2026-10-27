local lib = {}
local registry = require 'src.registry'

-- Max angular acceleration (rad/s^2) the controller may ask for, as a torque
-- (inertia * alpha). Strong enough to stand, weak enough to yield in a pile.
lib.maxAlpha = 1000 -- swept: 300 let 2 of 3 Mipos sink into a split, 3000 overshot

-- PD controller on angular velocity, applied as a bounded torque
local function rotateBodyTowards(body, dt, targetAngle, data)
    local currentAngle = body:getAngle()
    local diff = math.rad(targetAngle) - currentAngle
    -- wrap to [-pi, pi]
    diff = (diff + math.pi) % (2 * math.pi) - math.pi

    local omega = body:getAngularVelocity()

    -- Tunables (or read from data)

    local kp = (data and data.kp) or 20.0    -- P gain (1/s)  --was 8
    local kd = (data and data.kd) or .000015 -- D gain (unitless) -- was 1.5
    local maxOmega = (data and data.maxOmega) or 15.0

    -- PD controller in "omega space"
    local omega_cmd = kp * diff - kd * omega

    -- clamp and apply
    if omega_cmd > maxOmega then omega_cmd = maxOmega end
    if omega_cmd < -maxOmega then omega_cmd = -maxOmega end

    -- Reach omega_cmd through a bounded torque instead of setAngularVelocity.
    -- Setting the velocity is infinitely strong: in a pile of Mipos a leg turned
    -- straight through its neighbours, the contact solver shoved them apart, and
    -- the pile gained energy until one was launched out of the world.
    local maxAlpha = (data and data.maxAlpha) or lib.maxAlpha
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

                if vb.name == 'KEEP_ANGLE' and vb.enabled ~= false and not same then
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

local lib = {}


function rotateBodyTowards(body, dt, targetAngle, data)
    local currentAngle = body:getAngle()
    local diff = targetAngle - currentAngle

    -- Wrap difference into [-pi, pi] range
    diff = (diff + math.pi) % (2 * math.pi) - math.pi

    -- Simple proportional controller
    local rotationSpeed = data and data.speed or 5.00 -- tweak this for faster/slower turning
    local maxAngularVel = 10                          -- safety clamp

    local desiredAngularVel = diff * rotationSpeed
    desiredAngularVel = math.max(-maxAngularVel, math.min(maxAngularVel, desiredAngularVel))

    body:setAngularVelocity(desiredAngularVel)
end

-- Minimal PD version: still sets angular velocity directly
function rotateBodyTowards(body, dt, targetAngle, data)
    local currentAngle = body:getAngle()
    local diff = math.rad(targetAngle) - currentAngle
    -- wrap to [-pi, pi]
    diff = (diff + math.pi) % (2 * math.pi) - math.pi

    local omega = body:getAngularVelocity()

    -- Tunables (or read from data)
    local kp = (data and data.kp) or 20.0  -- P gain (1/s)  --was 8
    local kd = (data and data.kd) or .0015 -- D gain (unitless) -- was 1.5
    local maxOmega = (data and data.maxOmega) or 15.0

    -- PD controller in "omega space"
    local omega_cmd = kp * diff - kd * omega

    -- clamp and apply
    if omega_cmd > maxOmega then omega_cmd = maxOmega end
    if omega_cmd < -maxOmega then omega_cmd = -maxOmega end

    body:setAngularVelocity(omega_cmd)
end

function lib.update(dt, hitted)
    --logger:inspect(registry.sfixtures)
    local bods = registry.bodies
    for k, v in pairs(bods) do
        local ud = v:getUserData()
        if ud.thing and ud.thing.behaviors then
            local behaviors = ud.thing.behaviors
            local same = false
            if hitted and #hitted > 0 then
                for i = 1, #hitted do
                    if (hitted[i].id == ud.thing.id) then
                        same = true
                    end
                end
            end
            --print(same)
            for kb, vb in pairs(behaviors) do
                -- figure out if im touching this body

                if vb.name == 'KEEP_ANGLE' and not same then
                    -- logger:inspect(vb)
                    rotateBodyTowards(ud.thing.body, dt, vb.angle or 0, vb)
                end
            end
        end
    end
    --print('jo trying to keep angle for the ones that have')
end

return lib

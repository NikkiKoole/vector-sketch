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

function lib.update(dt)
    --logger:inspect(registry.sfixtures)
    local bods = registry.bodies
    for k, v in pairs(bods) do
        local ud = v:getUserData()
        if ud.thing and ud.thing.behaviors then
            local behaviors = ud.thing.behaviors
            for kb, vb in pairs(behaviors) do
                if vb.name == 'KEEP_ANGLE' then
                    logger:inspect(vb)
                    rotateBodyTowards(ud.thing.body, dt, 0, vb)
                end
            end
        end
    end
    --print('jo trying to keep angle for the ones that have')
end

return lib

local s = {}

local function calculateDistance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function mapInto(x, in_min, in_max, out_min, out_max)
    return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end

function s.onStart()
    cup = getObjectsByLabel('catapult-cup')[1]
    base = getObjectsByLabel('catapult-frame')[1]
    projectile = getObjectsByLabel('projectile')[1]


    projectile.fixture:setCategory(2)
    projectile.fixture:setMask(2)

    projectile.body:setBullet(true)

    base.fixture:setCategory(2)
    base.fixture:setMask(2)
    cup.fixture:setCategory(2)
    cup.fixture:setMask(2)

    maxLength = 0
    local joints = cup.body:getJoints()
    for i = 1, #joints do
        if joints[i]:getType() == 'rope' then
            maxLength = joints[i]:getMaxLength()
        end
    end

    isHoldingCup = false
    weldJoint = nil
end

function s.onKeyPress(key)
    --print(key)
    if key == 'p' then
        local bx, by = cup.body:getPosition()
        projectile.body:setPosition(bx, by)
        projectile.fixture:setSensor(true)
        -- now i want to connect the projectile to the cup, probably with a weld joint
        --if (not weldJoint) then
        local attachedJoints = projectile.body:getJoints()
        for i = 1, #attachedJoints do
            attachedJoints[i]:destroy()
        end

        love.physics.newWeldJoint(projectile.body, cup.body, bx, by, false)
        --end
    end
end

function s.update(dt)
    --print(isHoldingCup)
    local mx, my = mouseWorldPos()
    local bx, by = base.body:getPosition()
end

function s.draw()
    local mx, my = mouseWorldPos()
    local bx, by = base.body:getPosition()
    local d = calculateDistance(mx, my, bx, by)

    if d > maxLength and isHoldingCup then
        love.graphics.setColor(1, 0, 0, 1)
    else
        love.graphics.setColor(1, 1, 1, .5)
    end
    love.graphics.circle('fill', mx, my, 10)
end

function s.onPressed(objs)
    for i = 1, #objs do
        if objs[i] == cup then
            isHoldingCup = true
        end
    end
end

function s.onReleased(objs)
    for i = 1, #objs do
        if objs[i] == cup then
            if isHoldingCup then
                local bx, by = base.body:getPosition()
                local cupX, cupY = cup.body:getPosition()
                local dx = bx - cupX
                local dy = by - cupY

                local mx, my = mouseWorldPos()
                local d = calculateDistance(mx, my, bx, by)
                local force = mapInto(d, maxLength, maxLength * 2, 1, 5)
                if d >= maxLength then
                    local forceMultiplier = force -- Adjust based on desired power
                    cup.body:setLinearVelocity(dx * forceMultiplier, dy * forceMultiplier)
                    local attachedJoints = projectile.body:getJoints()
                    for i = 1, #attachedJoints do
                        attachedJoints[i]:destroy()
                    end
                    projectile.fixture:setSensor(false)
                    projectile.body:setLinearVelocity(dx * forceMultiplier, dy * forceMultiplier)
                end
            end
            isHoldingCup = false
        end
    end
end

return s

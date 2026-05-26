local s = {}

-- Per-anchor cluster definitions
local ANCHOR_DEFS = {
    { label = 'torso1', count = 36, centerR = 65, rMin = 30, rMax = 55 },
    { label = 'head',   count = 27, centerR = 50, rMin = 22, rMax = 45 },
    { label = 'lhand',  count = 18, centerR = 28, rMin = 16, rMax = 32 },
    { label = 'rhand',  count = 18, centerR = 28, rMin = 16, rMax = 32 },
    { label = 'lfoot',  count = 18, centerR = 28, rMin = 16, rMax = 32 },
    { label = 'rfoot',  count = 18, centerR = 28, rMin = 16, rMax = 32 },
}

local SPONGE_R    = 70
local MIN_SPEED   = 40
local DAMAGE_RATE = 12
local FOAM_COUNT  = 3

local JIGGLE_IMPULSE = 25
local JIGGLE_RADIUS  = 250
local SPLATTER_COUNT = 8
local FREED_SHRINK   = 2.2
local ANGLE_SPRING   = 700  -- restoring force toward initial spawn angle

local HIT_HEALTH = 10

local mudJoints    = {}
local anchorBodies = {}  -- { body, centerR, ballCount, totalBalls } per anchor
local freed        = {}
local freedAnchors = {}  -- { x, y, radius, scale } — shrinking center circles
local splatter     = {}
local foam         = {}
local totalJoints  = 0
local lastMx, lastMy = nil, nil

local function breakBall(j)
    local e      = mudJoints[j]
    local bx, by = e.body:getPosition()

    if not e.joint:isDestroyed() then e.joint:destroy() end

    -- Splatter
    for _ = 1, SPLATTER_COUNT do
        local a   = math.random() * math.pi * 2
        local spd = 60 + math.random() * 180
        table.insert(splatter, {
            x = bx, y = by,
            vx = math.cos(a) * spd, vy = math.sin(a) * spd - 50,
            age = 0, life = 0.3 + math.random() * 0.3,
            r   = 4 + math.random() * 7,
        })
    end

    -- Jiggle neighbours
    for k, nb in ipairs(mudJoints) do
        if k ~= j and not nb.joint:isDestroyed() then
            local nx, ny = nb.body:getPosition()
            if math.sqrt((nx-bx)^2+(ny-by)^2) < JIGGLE_RADIUS then
                local ja = math.random() * math.pi * 2
                local jf = JIGGLE_IMPULSE * nb.body:getMass()
                nb.body:applyLinearImpulse(math.cos(ja)*jf, math.sin(ja)*jf)
            end
        end
    end

    -- Freed: shrink in place (pure visual, destroy body now)
    local drawR = e.radius * math.max(0.3, e.health / HIT_HEALTH)
    local eAnchor = e.anchor
    e.body:destroy()
    table.insert(freed, { x = bx, y = by, radius = drawR, scale = 1.0 })
    table.remove(mudJoints, j)

    -- Check if this anchor's last ball just popped
    for _, a in ipairs(anchorBodies) do
        if a.body == eAnchor then
            a.ballCount = (a.ballCount or 1) - 1
            if a.ballCount <= 0 then
                local ax, ay = a.body:getPosition()
                table.insert(freedAnchors, { x = ax, y = ay, radius = a.centerR, scale = 1.0 })
                a.ballCount = -1  -- mark as already freed
            end
            break
        end
    end
end

local function spawnCluster()
    for _, e in ipairs(mudJoints) do
        if not e.joint:isDestroyed() then e.joint:destroy() end
        if not e.body:isDestroyed()  then e.body:destroy()  end
    end
    for _, f in ipairs(freed) do end  -- already destroyed bodies
    mudJoints    = {}
    anchorBodies = {}
    freed        = {}
    freedAnchors = {}
    splatter     = {}
    foam         = {}
    lastMx, lastMy = nil, nil

    for _, def in ipairs(ANCHOR_DEFS) do
        local found = getObjectsByLabel(def.label)
        local anchor = found[1] and found[1].body or nil
        if anchor and not anchor:isDestroyed() then
            local ax, ay = anchor:getPosition()
            table.insert(anchorBodies, { body = anchor, centerR = def.centerR, ballCount = def.count, totalBalls = def.count })

            for i = 1, def.count do
                local angle = (i / def.count) * math.pi * 2 + (math.random()-0.5) * 0.9
                local ballR = def.rMin + math.random() * (def.rMax - def.rMin)
                local dist  = def.centerR + ballR * (0.5 + math.random() * 0.7)
                local bx    = ax + math.cos(angle) * dist
                local by    = ay + math.sin(angle) * dist

                local body = love.physics.newBody(world, bx, by, 'dynamic')
                body:setGravityScale(0)
                body:setLinearDamping(8)
                body:setAngularDamping(20)
                body:setFixedRotation(true)
                local fix = love.physics.newFixture(body, love.physics.newCircleShape(ballR), 0.5)
                fix:setSensor(true)

                local joint = love.physics.newDistanceJoint(
                    anchor, body, ax, ay, bx, by, false
                )
                joint:setFrequency(4)
                joint:setDampingRatio(0.6)

                table.insert(mudJoints, {
                    joint      = joint,
                    body       = body,
                    radius     = ballR,
                    health     = HIT_HEALTH,
                    anchor     = anchor,
                    initAngle  = math.atan2(by - ay, bx - ax),
                    initDist   = math.sqrt((bx-ax)^2+(by-ay)^2),
                })
            end
        end
    end

    totalJoints = #mudJoints
end

function s.onStart()
    worldState.paused = false
    local toDestroy = {}
    for _, body in ipairs(world:getBodies()) do
        if not body:getUserData() then table.insert(toDestroy, body) end
    end
    for _, body in ipairs(toDestroy) do
        if not body:isDestroyed() then body:destroy() end
    end
    spawnCluster()
end

function s.onKeyPress(key)
    if key == 'r' then spawnCluster() end
end

function s.update(dt)
    local mx, my    = mouseWorldPos()
    local mouseDown = love.mouse.isDown(1)

    local speed = 0
    if lastMx then
        local dx, dy = mx - lastMx, my - lastMy
        speed = math.sqrt(dx*dx + dy*dy) / dt
    end
    lastMx, lastMy = mx, my

    if mouseDown and speed > MIN_SPEED then
        for j = #mudJoints, 1, -1 do
            local e = mudJoints[j]
            if not e.joint:isDestroyed() then
                local bx, by = e.body:getPosition()
                local drawR  = e.radius * (0.5 + 0.5 * e.health / HIT_HEALTH)
                local d      = math.sqrt((mx-bx)^2 + (my-by)^2)
                if d < SPONGE_R + drawR then
                    e.health = e.health - DAMAGE_RATE * math.min(speed/300, 2.0) * dt
                    if e.health <= 0 then breakBall(j) end
                end
            end
        end

        for _ = 1, FOAM_COUNT do
            local a = math.random() * math.pi * 2
            table.insert(foam, {
                x = mx + math.cos(a) * math.random() * SPONGE_R * 0.8,
                y = my + math.sin(a) * math.random() * SPONGE_R * 0.8,
                vx = (math.random()-0.5) * 50, vy = -30 - math.random()*50,
                age = 0, life = 0.3 + math.random()*0.3,
                r = 4 + math.random()*8,
            })
        end
    end

    -- Angular restoring force — push each ball back toward its initial angle
    for _, e in ipairs(mudJoints) do
        if not e.joint:isDestroyed() then
            local ax, ay = e.anchor:getPosition()
            local bx, by = e.body:getPosition()
            local idealX = ax + math.cos(e.initAngle) * e.initDist
            local idealY = ay + math.sin(e.initAngle) * e.initDist
            e.body:applyForce((idealX - bx) * ANGLE_SPRING, (idealY - by) * ANGLE_SPRING)
        end
    end

    for i = #freed, 1, -1 do
        local f = freed[i]
        f.scale = f.scale - FREED_SHRINK * dt
        if f.scale <= 0 then table.remove(freed, i) end
    end

    for i = #freedAnchors, 1, -1 do
        local a = freedAnchors[i]
        a.scale = a.scale - 0.8 * dt
        if a.scale <= 0 then table.remove(freedAnchors, i) end
    end

    for i = #splatter, 1, -1 do
        local p = splatter[i]
        p.x = p.x + p.vx*dt; p.y = p.y + p.vy*dt
        p.vy = p.vy + 300*dt; p.age = p.age + dt
        if p.age >= p.life then table.remove(splatter, i) end
    end

    for i = #foam, 1, -1 do
        local p = foam[i]
        p.x = p.x + p.vx*dt; p.y = p.y + p.vy*dt
        p.age = p.age + dt
        if p.age >= p.life then table.remove(foam, i) end
    end
end

function s.draw()
    local mx, my    = mouseWorldPos()
    local mouseDown = love.mouse.isDown(1)

    -- Center mud masses at each anchor (only while they still have balls)
    for _, a in ipairs(anchorBodies) do
        if a.ballCount > 0 and not a.body:isDestroyed() then
            local ax, ay = a.body:getPosition()
            love.graphics.setColor(0.32, 0.20, 0.08, 0.75)
            love.graphics.circle('fill', ax, ay, a.centerR)
        end
    end

    -- Freed anchor circles shrinking away
    for _, a in ipairs(freedAnchors) do
        love.graphics.setColor(0.32, 0.20, 0.08, a.scale * 0.75)
        love.graphics.circle('fill', a.x, a.y, a.radius * a.scale)
    end

    -- Active mud balls
    for _, e in ipairs(mudJoints) do
        if not e.joint:isDestroyed() then
            local bx, by = e.body:getPosition()
            local t      = e.health / HIT_HEALTH
            local drawR  = e.radius * (0.5 + 0.5 * t)
            love.graphics.setColor(0.32, 0.20, 0.08, 0.55 + t * 0.4)
            love.graphics.circle('fill', bx, by, drawR)
            love.graphics.setColor(0.22, 0.13, 0.04, t * 0.6)
            love.graphics.setLineWidth(2)
            love.graphics.circle('line', bx, by, drawR)
            love.graphics.setLineWidth(1)
        end
    end

    -- Freed balls shrinking in place
    for _, f in ipairs(freed) do
        love.graphics.setColor(0.32, 0.20, 0.08, f.scale * 0.7)
        love.graphics.circle('fill', f.x, f.y, f.radius * f.scale)
    end

    -- Splatter
    for _, p in ipairs(splatter) do
        local t = p.age / p.life
        love.graphics.setColor(0.28, 0.16, 0.05, (1-t) * 0.85)
        love.graphics.circle('fill', p.x, p.y, p.r * (1 - t*0.5))
    end

    -- Foam
    for _, p in ipairs(foam) do
        local t = p.age / p.life
        love.graphics.setColor(1, 1, 1, (1-t) * 0.75)
        love.graphics.circle('line', p.x, p.y, p.r * (1 - t*0.3))
    end

    -- Sponge
    local squeeze = mouseDown and 0.82 or 1.0
    love.graphics.setColor(1, 0.85, 0.25, 0.85)
    love.graphics.circle('fill', mx, my, SPONGE_R * squeeze)
    love.graphics.setColor(0.9, 0.7, 0.1, 0.9)
    love.graphics.setLineWidth(3)
    love.graphics.circle('line', mx, my, SPONGE_R * squeeze)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.85, 0.65, 0.1, 0.5)
    for _, o in ipairs({{0,-22},{-18,10},{18,10},{0,22},{-18,-10},{18,-10}}) do
        love.graphics.circle('fill', mx+o[1], my+o[2], 4)
    end

    -- Status
    local pct = totalJoints > 0 and math.floor((1 - #mudJoints / totalJoints) * 100) or 100
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(pct .. '%   joints: ' .. #mudJoints, mx - 50, my - SPONGE_R - 30)
    if #mudJoints == 0 then
        love.graphics.setColor(0.2, 1, 0.3, 1)
        love.graphics.print('CLEAN!', mx - 20, my - SPONGE_R - 60)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return s

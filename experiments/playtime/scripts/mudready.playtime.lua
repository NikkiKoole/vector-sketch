local s = {}

-- Per-anchor cluster definitions
local ANCHOR_LABELS = {
    'torso1',
    'head', 'lear', 'rear',
    'luarm', 'ruarm', 'llarm', 'rlarm',
    'lhand', 'rhand',
    'luleg', 'ruleg', 'llleg', 'rlleg',
    'lfoot', 'rfoot',
}

local SPONGE_R    = 70
local MIN_SPEED   = 40
local DAMAGE_RATE = 24
local FOAM_COUNT  = 3

local JIGGLE_IMPULSE = 25
local JIGGLE_RADIUS  = 250
local SPLATTER_COUNT = 8
local FREED_SHRINK   = 2.2
local ANGLE_SPRING   = 700  -- restoring force toward initial spawn angle

local HIT_HEALTH = 10

local waterY     = nil   -- world Y of water surface
local waterXmin  = nil
local waterXmax  = nil
local waterTime  = 0
local waterSplash = {}   -- { x, y, vx, vy, age, life, r }
local prevBodyY  = {}    -- [body] = last y, for crossing detection

local FLUID_DENSITY = 2.0
local FLUID_DRAG    = 1.5
local FLUID_ANGDAMP = 1.5

local SOAP_R           = 55    -- contact radius for lathering
local SOAP_DAMAGE_RATE = 5     -- health/sec drained while lathered
local LATHER_DURATION  = 10    -- seconds lather stays active after last contact (water cuts this short)
local SOAP_HW          = 22    -- half-width of bar (matches draw)
local SOAP_HH          = 14    -- half-height of bar
local SOAP_GRAB_PAD    = 18

local soapX           = 0
local soapY           = 0
local soapDetected    = false
local soapDragging    = false
local soapDragDX      = 0
local soapDragDY      = 0

local function pointInSoapGrab(mx, my)
    return mx >= soapX - SOAP_HW - SOAP_GRAB_PAD
       and mx <= soapX + SOAP_HW + SOAP_GRAB_PAD
       and my >= soapY - SOAP_HH - SOAP_GRAB_PAD
       and my <= soapY + SOAP_HH + SOAP_GRAB_PAD
end

local SHOWER_RATE      = 0.02   -- seconds between spawn bursts
local SHOWER_BURST     = 3      -- drops per burst
local SHOWER_SPREAD    = 80     -- horizontal spread
local SHOWER_DMG       = 4      -- health damage per drop hit
local SHOWER_BODY_SPLAT_CHANCE = 0.4  -- fraction of drops that splat on body hits;
                                      -- the rest pass through so lower parts get washed too

local showerDroplets  = {}
local showerTimer     = 0
local showerX         = 0
local showerY         = 0
local showerDetected  = false
local showerDragging  = false
local showerDragDX    = 0
local showerDragDY    = 0
local wasMouseDown    = false

local SHOWER_HEAD_HW  = 35   -- head half-width (matches draw)
local SHOWER_HEAD_HH  = 12   -- head half-height
local SHOWER_GRAB_PAD = 20   -- extra padding on the head hit-box
local SHOWER_PIPE_PAD = 14   -- pipe hit-box half-width

local function pointInShowerGrab(mx, my)
    -- Generous head box
    if mx >= showerX - SHOWER_HEAD_HW - SHOWER_GRAB_PAD
       and mx <= showerX + SHOWER_HEAD_HW + SHOWER_GRAB_PAD
       and my >= showerY - SHOWER_HEAD_HH - SHOWER_GRAB_PAD
       and my <= showerY + SHOWER_HEAD_HH + SHOWER_GRAB_PAD then
        return true
    end
    -- Pipe column above the head
    if mx >= showerX - SHOWER_PIPE_PAD and mx <= showerX + SHOWER_PIPE_PAD
       and my >= showerY - 120 and my <= showerY - 10 then
        return true
    end
    return false
end

local mudJoints    = {}
local anchorBodies = {}  -- { body, centerR, ballCount, totalBalls } per anchor
local freed        = {}
local freedAnchors = {}  -- { x, y, radius, scale } — shrinking center circles
local splatter     = {}
local foam         = {}
local stickyFoam   = {}  -- { body, lx, ly, r, age, life } — foam clinging to Mipo body parts
local totalJoints  = 0
local lastMx, lastMy = nil, nil

local currentMipoInstance = nil  -- tracks the procedurally-spawned Mipo, if any

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

local function spawnCluster(instance)
    for _, e in ipairs(mudJoints) do
        if not e.joint:isDestroyed() then e.joint:destroy() end
        if not e.body:isDestroyed()  then e.body:destroy()  end
    end
    mudJoints    = {}
    anchorBodies = {}
    freed        = {}
    freedAnchors = {}
    splatter     = {}
    foam         = {}
    stickyFoam   = {}
    lastMx, lastMy = nil, nil

    local anchorsToCoat = {}
    if instance then
        for _, thing in pairs(instance.parts) do
            if thing.body and not thing.body:isDestroyed() then
                table.insert(anchorsToCoat, thing.body)
            end
        end
    else
        for _, label in ipairs(ANCHOR_LABELS) do
            local found  = getObjectsByLabel(label)
            local anchor = found[1] and found[1].body or nil
            if anchor and not anchor:isDestroyed() then
                table.insert(anchorsToCoat, anchor)
            end
        end
    end

    for _, anchor in ipairs(anchorsToCoat) do
        local ax, ay = anchor:getPosition()

        -- Measure body size from collision fixtures only (no userData = not an sfixture)
        local maxHalf = 0
        for _, fix in ipairs(anchor:getFixtures()) do
            if not fix:getUserData() and not fix:isSensor() then
                local x1, y1, x2, y2 = fix:getBoundingBox(1)
                maxHalf = math.max(maxHalf, (x2-x1)/2, (y2-y1)/2)
            end
        end
        local r       = math.max(maxHalf, 10)
        local centerR = r * 0.35
        local rMin    = r * 0.3
        local rMax    = r * 0.65
        local count   = math.max(4, math.min(16, math.floor(r * 0.18)))

        table.insert(anchorBodies, { body = anchor, centerR = centerR, ballCount = count, totalBalls = count })

        for i = 1, count do
            local angle = (i / count) * math.pi * 2 + (math.random()-0.5) * 0.9
            local ballR = rMin + math.random() * (rMax - rMin)
            local dist  = centerR + ballR * (0.5 + math.random() * 0.7)
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
                joint     = joint,
                body      = body,
                radius    = ballR,
                health    = HIT_HEALTH,
                anchor    = anchor,
                initAngle = math.atan2(by - ay, bx - ax),
                initDist  = math.sqrt((bx-ax)^2+(by-ay)^2),
            })
        end
    end

    totalJoints = #mudJoints
end

local function destroyCurrentMipo()
    if currentMipoInstance then
        for _, thing in pairs(currentMipoInstance.parts) do
            if thing.body and not thing.body:isDestroyed() then
                objectManager.destroyBody(thing.body)
            end
        end
        currentMipoInstance = nil
    else
        -- destroy the scene-loaded Mipo (first call)
        for _, label in ipairs(ANCHOR_LABELS) do
            local found = getObjectsByLabel(label)
            for _, thing in ipairs(found) do
                if thing.body and not thing.body:isDestroyed() then
                    objectManager.destroyBody(thing.body)
                end
            end
        end
    end
end

local function spawnNewMudMipo(x, y)
    spawnCluster()  -- clear mud before destroying bodies to avoid dangling joint refs
    destroyCurrentMipo()
    local inst = characterManager.createCharacter("humanoid", x or 6600, y or 0, 0.3)
    if inst then
        characterManager.randomizeMipoConstrained(inst)
        currentMipoInstance = inst
        spawnCluster(inst)
    end
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

    -- Find the static tub body and compute water level from its bounding box
    for _, body in ipairs(world:getBodies()) do
        if body:getType() == 'static' and not body:isDestroyed() then
            local x1, y1, x2, y2 = 1e9, 1e9, -1e9, -1e9
            for _, fix in ipairs(body:getFixtures()) do
                local fx1,fy1,fx2,fy2 = fix:getBoundingBox(1)
                x1=math.min(x1,fx1); y1=math.min(y1,fy1)
                x2=math.max(x2,fx2); y2=math.max(y2,fy2)
            end
            if x2 > x1 then
                waterXmin = x1
                waterXmax = x2
                waterY       = y1 + (y2 - y1) * 0.52
                showerX      = (x1 + x2) * 0.5
                showerY      = y1 - 80
                showerDetected = true
                soapX        = x1 + 120
                soapY        = y1 - 35
                soapDetected = true
                break
            end
        end
    end

    spawnCluster()
end

function s.onKeyPress(key)
    if key == 'r' then spawnCluster() end
    if key == 'n' then spawnNewMudMipo() end
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

    -- Showerhead drag (press-transition detection)
    if showerDetected then
        if mouseDown and not wasMouseDown and pointInShowerGrab(mx, my) then
            showerDragging = true
            showerDragDX   = showerX - mx
            showerDragDY   = showerY - my
        end
        if showerDragging then
            if mouseDown then
                showerX = mx + showerDragDX
                showerY = my + showerDragDY
            else
                showerDragging = false
            end
        end
    end
    -- Soapbar drag
    if soapDetected then
        if mouseDown and not wasMouseDown and not showerDragging and pointInSoapGrab(mx, my) then
            soapDragging = true
            soapDragDX   = soapX - mx
            soapDragDY   = soapY - my
        end
        if soapDragging then
            if mouseDown then
                soapX = mx + soapDragDX
                soapY = my + soapDragDY
                -- lather mud balls within reach
                for _, e in ipairs(mudJoints) do
                    if not e.joint:isDestroyed() then
                        local bx, by = e.body:getPosition()
                        if math.sqrt((soapX-bx)^2+(soapY-by)^2) < SOAP_R + e.radius then
                            e.lather = LATHER_DURATION
                        end
                    end
                end
                -- sticky foam on Mipo body parts within reach
                for _, body in ipairs(world:getBodies()) do
                    local ud = body:getUserData()
                    if ud and ud.thing and not body:isDestroyed() then
                        local bx, by = body:getPosition()
                        if math.sqrt((soapX-bx)^2+(soapY-by)^2) < SOAP_R + 60 then
                            local lx, ly = body:getLocalPoint(
                                soapX + (math.random()-0.5) * SOAP_HW,
                                soapY + (math.random()-0.5) * SOAP_HH
                            )
                            table.insert(stickyFoam, {
                                body = body,
                                lx = lx, ly = ly,
                                r   = 6 + math.random() * 10,
                                age = 0,
                                life = 5 + math.random() * 4,
                            })
                        end
                    end
                end
            else
                soapDragging = false
            end
        end
    end

    -- Lather damage: lathered balls lose health over time
    for j = #mudJoints, 1, -1 do
        local e = mudJoints[j]
        if not e.joint:isDestroyed() and e.lather and e.lather > 0 then
            e.lather  = e.lather - dt
            e.health  = e.health - SOAP_DAMAGE_RATE * dt
            if e.health <= 0 then breakBall(j) end
        end
    end

    wasMouseDown = mouseDown

    -- Shower: spawn drops
    if showerDetected then
        showerTimer = showerTimer - dt
        if showerTimer <= 0 then
            showerTimer = SHOWER_RATE
            for _ = 1, SHOWER_BURST do
                table.insert(showerDroplets, {
                    x = showerX + (math.random()-0.5) * SHOWER_SPREAD,
                    y = showerY,
                    vx = (math.random()-0.5) * 30,
                    vy = 120 + math.random() * 100,
                    r  = 5 + math.random() * 7,
                    hit = false,
                    bodySplat = math.random() < SHOWER_BODY_SPLAT_CHANCE,
                })
            end
        end

        for i = #showerDroplets, 1, -1 do
            local d = showerDroplets[i]
            d.x  = d.x + d.vx * dt
            d.y  = d.y + d.vy * dt
            d.vy = d.vy + 500 * dt

            local removed = false

            if not d.hit then
                for j = #mudJoints, 1, -1 do
                    local e = mudJoints[j]
                    if not e.joint:isDestroyed() then
                        local bx, by = e.body:getPosition()
                        if math.sqrt((d.x-bx)^2+(d.y-by)^2) < e.radius + d.r then
                            e.health = e.health - SHOWER_DMG
                            e.lather = math.max(0, (e.lather or 0) - 1.5)  -- water rinses lather
                            d.hit = true
                            if e.health <= 0 then breakBall(j) end
                            break
                        end
                    end
                end
            end

            -- Body impact: splatter into small bouncing droplets, drop disappears.
            -- Only a fraction of drops are flagged for body-splat — the rest pass
            -- through so lower body parts get washed too. Skip if already underwater.
            if not removed and d.bodySplat and (not waterY or d.y < waterY) then
                for _, body in ipairs(world:getBodies()) do
                    if removed then break end
                    local ud = body:getUserData()
                    if ud and ud.thing and not body:isDestroyed() then
                        for _, fix in ipairs(body:getFixtures()) do
                            if not fix:getUserData() and not fix:isSensor()
                               and fix:testPoint(d.x, d.y) then
                                for _ = 1, 5 do
                                    local a   = -math.pi*0.5 + (math.random()-0.5) * math.pi * 1.1
                                    local spd = 40 + math.random() * 120
                                    table.insert(waterSplash, {
                                        x = d.x, y = d.y,
                                        vx = math.cos(a) * spd,
                                        vy = math.sin(a) * spd,
                                        age = 0, life = 0.2 + math.random() * 0.25,
                                        r   = 2 + math.random() * 3,
                                    })
                                end
                                -- water rinses sticky foam off this body
                                for k = #stickyFoam, 1, -1 do
                                    local sf = stickyFoam[k]
                                    if sf.body == body then
                                        local wx, wy = body:getWorldPoint(sf.lx, sf.ly)
                                        if math.sqrt((d.x-wx)^2+(d.y-wy)^2) < 40 then
                                            sf.life = sf.age + 0.3  -- quick fade out
                                        end
                                    end
                                end
                                table.remove(showerDroplets, i)
                                removed = true
                                break
                            end
                        end
                    end
                end
            end

            -- Water-surface impact: small crown of droplets, drop disappears.
            if not removed and waterY and d.y >= waterY then
                for _ = 1, 4 do
                    local a   = (math.random() - 0.5) * math.pi * 0.7
                    local spd = 60 + math.random() * 140
                    table.insert(waterSplash, {
                        x = d.x + (math.random()-0.5) * 8,
                        y = waterY,
                        vx = math.sin(a) * spd,
                        vy = -math.cos(a) * spd,
                        age = 0, life = 0.2 + math.random() * 0.2,
                        r   = 2 + math.random() * 4,
                    })
                end
                table.remove(showerDroplets, i)
                removed = true
            end

            if not removed and d.y > showerY + 1200 then
                table.remove(showerDroplets, i)
            end
        end
    end

    -- Sponge water disturbance (no click needed)
    if not showerDragging and waterY and my > waterY and speed > MIN_SPEED then
        for _ = 1, 2 do
            local side = (math.random() > 0.5) and 1 or -1
            table.insert(waterSplash, {
                x   = mx + (math.random()-0.5) * SPONGE_R,
                y   = my - math.random() * SPONGE_R * 0.5,
                vx  = side * (30 + math.random() * 120),
                vy  = -40 - math.random() * 100,
                age = 0, life = 0.2 + math.random() * 0.2,
                r   = 2 + math.random() * 5,
            })
        end
    end

    if mouseDown and not showerDragging and speed > MIN_SPEED then
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

    waterTime = waterTime + dt

    -- Water crossing detection → splash particles
    if waterY then
        for _, body in ipairs(world:getBodies()) do
            local ud = body:getUserData()
            if ud and ud.thing and not body:isDestroyed() then
                local bx, by = body:getPosition()
                local prevY  = prevBodyY[body]
                if prevY then
                    local entered = prevY <= waterY and by > waterY
                    local exited  = prevY >= waterY and by < waterY
                    if entered then
                        -- Entry: crown splash — droplets shoot straight up
                        for _ = 1, 14 do
                            local a   = (math.random() - 0.5) * math.pi * 0.6
                            local spd = 150 + math.random() * 280
                            table.insert(waterSplash, {
                                x = bx + (math.random()-0.5) * 50,
                                y = waterY,
                                vx = math.sin(a) * spd,
                                vy = -math.cos(a) * spd,
                                age = 0, life = 0.35 + math.random() * 0.3,
                                r   = 5 + math.random() * 9,
                            })
                        end
                    elseif exited then
                        -- Exit: sheet spray — droplets fly outward and drip back down
                        for _ = 1, 10 do
                            local side = (math.random() > 0.5) and 1 or -1
                            local spd  = 60 + math.random() * 160
                            table.insert(waterSplash, {
                                x = bx + (math.random()-0.5) * 60,
                                y = waterY,
                                vx = side * (40 + math.random() * spd),
                                vy = -20 - math.random() * 80,
                                age = 0, life = 0.25 + math.random() * 0.25,
                                r   = 3 + math.random() * 6,
                            })
                        end
                    end
                end
                prevBodyY[body] = by
            end
        end
    end

    -- Water buoyancy & drag for Mipo's body parts
    if waterY then
        local _, g_y = world:getGravity()
        for _, body in ipairs(world:getBodies()) do
            local ud = body:getUserData()
            if ud and ud.thing and not body:isDestroyed() then
                local _, by = body:getPosition()
                -- Estimate half-height from collision fixture
                local halfH = 30
                for _, fix in ipairs(body:getFixtures()) do
                    if not fix:getUserData() and not fix:isSensor() then
                        local _,fy1,_,fy2 = fix:getBoundingBox(1)
                        halfH = math.max(halfH, (fy2 - fy1) * 0.5)
                        break
                    end
                end
                local subFrac = math.min(1.0, math.max(0.0, (by - waterY + halfH) / (halfH * 2)))
                if subFrac > 0 then
                    -- Buoyancy cancels gravity, FLUID_DENSITY > 1 makes it float up
                    body:applyForce(0, -body:getMass() * g_y * subFrac * FLUID_DENSITY)
                    body:setLinearDamping(FLUID_DRAG * subFrac)
                    body:setAngularDamping(FLUID_ANGDAMP * subFrac)
                else
                    body:setLinearDamping(0)
                    body:setAngularDamping(0)
                end
            end
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

    for i = #stickyFoam, 1, -1 do
        local f = stickyFoam[i]
        f.age = f.age + dt
        if f.age >= f.life or f.body:isDestroyed() then table.remove(stickyFoam, i) end
    end

    for i = #foam, 1, -1 do
        local p = foam[i]
        p.x = p.x + p.vx*dt; p.y = p.y + p.vy*dt
        p.age = p.age + dt
        if p.age >= p.life then table.remove(foam, i) end
    end

    for i = #waterSplash, 1, -1 do
        local p = waterSplash[i]
        p.x = p.x + p.vx*dt; p.y = p.y + p.vy*dt
        p.vy = p.vy + 400*dt
        p.age = p.age + dt
        if p.age >= p.life then table.remove(waterSplash, i) end
    end
end

function s.draw()
    local mx, my    = mouseWorldPos()
    local mouseDown = love.mouse.isDown(1)

    -- Water fill
    if waterY and waterXmin then
        local depth = 1200  -- draw well below screen bottom
        love.graphics.setColor(0.15, 0.45, 0.75, 0.38)
        love.graphics.rectangle('fill', waterXmin, waterY, waterXmax - waterXmin, depth)

        -- Animated surface
        local steps = 48
        local wpts  = {}
        for i = 0, steps do
            local t  = i / steps
            local wx = waterXmin + t * (waterXmax - waterXmin)
            local wy = waterY
                     + math.sin(t * math.pi * 5 + waterTime * 1.8) * 6
                     + math.sin(t * math.pi * 9 - waterTime * 2.7) * 3
            table.insert(wpts, wx); table.insert(wpts, wy)
        end
        love.graphics.setColor(0.4, 0.75, 1.0, 0.7)
        love.graphics.setLineWidth(3)
        if #wpts >= 4 then love.graphics.line(wpts) end
        love.graphics.setLineWidth(1)
    end

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

    -- Foam (floating, from sponge)
    for _, p in ipairs(foam) do
        local t = p.age / p.life
        love.graphics.setColor(1, 1, 1, (1-t) * 0.75)
        love.graphics.circle('line', p.x, p.y, p.r * (1 - t*0.3))
    end

    -- Sticky foam clinging to clean Mipo body parts
    for _, f in ipairs(stickyFoam) do
        if not f.body:isDestroyed() then
            local wx, wy = f.body:getWorldPoint(f.lx, f.ly)
            local t = f.age / f.life
            love.graphics.setColor(1, 1, 1, (1 - t) * 0.8)
            love.graphics.circle('fill', wx, wy, f.r * (1 - t * 0.4))
            love.graphics.setColor(0.85, 0.95, 1.0, (1 - t) * 0.5)
            love.graphics.circle('fill', wx - f.r * 0.3, wy - f.r * 0.3, f.r * 0.4)
        end
    end

    -- Lather foam clinging to soaped mud balls
    for _, e in ipairs(mudJoints) do
        if not e.joint:isDestroyed() and e.lather and e.lather > 0 then
            local bx, by = e.body:getPosition()
            local t      = math.min(1, e.lather / LATHER_DURATION)
            love.graphics.setColor(1, 1, 1, t * 0.85)
            love.graphics.circle('fill', bx, by, e.radius * 0.9)
            love.graphics.setColor(0.85, 0.95, 1.0, t * 0.6)
            love.graphics.circle('fill', bx - e.radius * 0.3, by - e.radius * 0.25, e.radius * 0.45)
            love.graphics.circle('fill', bx + e.radius * 0.25, by - e.radius * 0.35, e.radius * 0.3)
        end
    end

    -- Soapbar
    if soapDetected then
        local hovering = pointInSoapGrab(mx, my) and not showerDragging
        love.graphics.setColor(0.98, 0.95, 0.88, 1)
        love.graphics.rectangle('fill', soapX - SOAP_HW, soapY - SOAP_HH, SOAP_HW*2, SOAP_HH*2, 6)
        love.graphics.setColor(0.88, 0.82, 0.72, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle('line', soapX - SOAP_HW, soapY - SOAP_HH, SOAP_HW*2, SOAP_HH*2, 6)
        -- indentation line
        love.graphics.setColor(0.80, 0.74, 0.64, 0.8)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(soapX - SOAP_HW + 8, soapY, soapX + SOAP_HW - 8, soapY)
        love.graphics.setLineWidth(1)
        if hovering or soapDragging then
            love.graphics.setColor(1.0, 0.95, 0.2, soapDragging and 1.0 or 0.7)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle('line', soapX - SOAP_HW - 4, soapY - SOAP_HH - 4, SOAP_HW*2+8, SOAP_HH*2+8, 8)
            love.graphics.setLineWidth(1)
        end
    end

    -- Showerhead + drops
    if showerDetected then
        local hovering = pointInShowerGrab(mx, my)
        -- Pipe
        love.graphics.setColor(0.65, 0.65, 0.72, 1)
        love.graphics.rectangle('fill', showerX - 3, showerY - 120, 6, 110)
        love.graphics.setLineWidth(1)
        -- Head
        love.graphics.rectangle('fill', showerX - 35, showerY - 12, 70, 14, 4)
        -- Nozzle dots
        love.graphics.setColor(0.35, 0.45, 0.6, 1)
        for i = -3, 3 do
            love.graphics.circle('fill', showerX + i * 9, showerY + 2, 2.5)
        end
        -- Hover/drag highlight
        if hovering or showerDragging then
            love.graphics.setColor(1.0, 0.95, 0.2, showerDragging and 1.0 or 0.7)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle('line', showerX - 39, showerY - 16, 78, 22, 5)
            love.graphics.setLineWidth(1)
        end
        -- Drops
        for _, d in ipairs(showerDroplets) do
            love.graphics.setColor(0.4, 0.75, 1.0, d.hit and 0.3 or 0.75)
            love.graphics.circle('fill', d.x, d.y, d.r)
        end
    end

    -- Water splash droplets
    for _, p in ipairs(waterSplash) do
        local t = p.age / p.life
        love.graphics.setColor(0.4, 0.75, 1.0, (1-t) * 0.85)
        love.graphics.circle('fill', p.x, p.y, p.r * (1 - t * 0.4))
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

function s.drawUI()
    local w, h    = love.graphics.getDimensions()
    local BH      = 40
    local BSPC    = 10
    local margin  = 20
    local pW      = 320
    local pH      = BH * 6 + BSPC * 2
    local startX  = margin
    local startY  = h - pH - margin

    ui.panel(startX, startY, pW, pH, '•• water ••', function()
        local layout = ui.createLayout({
            type = 'columns', spacing = BSPC,
            startX = startX + BSPC, startY = startY + BSPC,
        })

        local x, y = ui.nextLayoutPosition(layout, pW - 20, BH)
        local v = ui.sliderWithInput('density', x, y, 200, 0.1, 4.0, FLUID_DENSITY)
        if v then FLUID_DENSITY = v + 0 end
        ui.label(x, y, ' density')

        x, y = ui.nextLayoutPosition(layout, pW - 20, BH)
        v = ui.sliderWithInput('drag', x, y, 200, 0.0, 3.0, FLUID_DRAG)
        if v then FLUID_DRAG = v + 0 end
        ui.label(x, y, ' drag')

        x, y = ui.nextLayoutPosition(layout, pW - 20, BH)
        v = ui.sliderWithInput('angdamp', x, y, 200, 0.0, 3.0, FLUID_ANGDAMP)
        if v then FLUID_ANGDAMP = v + 0 end
        ui.label(x, y, ' ang.damp')

        x, y = ui.nextLayoutPosition(layout, pW - 20, BH)
        if waterY then
            v = ui.sliderWithInput('waterlvl', x, y, 200, -500, 1500, waterY)
            if v then waterY = v + 0 end
            ui.label(x, y, ' water level')
        else
            ui.label(x, y, ' water: not found')
        end

        x, y = ui.nextLayoutPosition(layout, pW - 20, BH)
        if showerDetected then
            v = ui.sliderWithInput('showerx', x, y, 200, waterXmin or 0, waterXmax or 2000, showerX)
            if v then showerX = v + 0 end
            ui.label(x, y, ' shower pos')
        else
            ui.label(x, y, ' shower: not found')
        end
    end)
end

return s

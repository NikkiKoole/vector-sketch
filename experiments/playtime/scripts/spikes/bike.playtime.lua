-- bike: a Mipo on a bike rolling down a hill by itself, a knikkerbaan to watch (no buttons).
-- After physics-testbed's downhill (docs/REBUILD-IN-PLAYTIME.md). A real physics bike, two
-- wheels and a frame, sized from the Mipo. The pedals are drawn, turning with the back wheel;
-- the legs follow them by muscle (KEEP_ANGLE aimed where the knee must be for the foot to reach
-- its pedal). Pinned to physical pedals instead, hip, knee and pedal made a closed loop with a
-- dead spot: the pedals jammed, or turning tipped the bike over backwards (tried 2026-11-06).
-- The Mipo faces right (src/mipo-facing.lua: facing a side, hips swing forward and knees bend
-- back), held at the saddle, hands on the bars, torso kept upright on the bike. At the bottom
-- it's put back at the top for now (a lift is the next step).
-- keys: r: a new Mipo on the bike   w: the next tire picture   p: pause

local s = {}

local SCALE = 0.3
local START_X, START_Y = -3000, 0
local END_X = 9000
local FRICTION = 0.9
local BIKE_DENSITY = 6    -- heavy enough that a big-bodied rider doesn't tip it over (2 did)
local AIR = 0.25          -- the bike's linear damping: a calmer top speed (without: ~2900 a second at the bottom)

local function check() -- on state: a script hot reload keeps the ride
    state.bikeSpike = state.bikeSpike or {}
    return state.bikeSpike
end

local function alive(body) return body and not body:isDestroyed() end

-- ─── The course: a long hill with humps, then flat ───

local function courseHeight(x)
    -- the end: flat (the lift's tray waits there), then a short rise to run out on
    local flatFrom, riseFrom = END_X - 2200, END_X - 700
    if x > flatFrom then
        local base = courseHeight(flatFrom)
        if x <= riseFrom then return base end
        local u = math.min(x - riseFrom, 700)
        return base - u * u / 700 * 0.35
    end
    local t = math.max(0, x - START_X)
    -- downhill from the start (a knikkerbaan: it rolls off by itself), humps along the way;
    -- 0.32 went far too fast (2900 a second at the bottom, into the end wall)
    return START_Y + t * 0.16 + math.sin(t / 700) * 90 + math.sin(t / 260) * 20
end

local function makeCourse()
    local c = check()
    if alive(c.ground) then return end
    local points = {}
    for x = START_X - 1500, END_X, 50 do
        points[#points + 1] = x
        points[#points + 1] = courseHeight(x)
    end
    -- walls at both ends
    table.insert(points, 1, START_Y - 1500)
    table.insert(points, 1, START_X - 1500)
    points[#points + 1] = END_X
    points[#points + 1] = courseHeight(END_X) - 1500
    c.ground = love.physics.newBody(world, 0, 0, 'static')
    love.physics.newFixture(c.ground, love.physics.newChainShape(false, points)):setFriction(FRICTION)
end

-- ─── Mipo helpers ───

-- where the joint between parent and part sits (hip, knee, ankle)
local jointPoint = characterManager.jointPoint -- src/mipo-build.lua

-- turn bodies rigidly about a point
local turnBodies = characterManager.turnBodies -- src/mipo-build.lua

-- the same for a Mipo's parts by name (as characterManager.poseTpose does with arms)
local turnParts = characterManager.turnParts -- src/mipo-build.lua

local moveAll = characterManager.moveAll -- src/mipo-build.lua

-- ─── Pedalling by muscle ───

local PEDAL_RATIO = 0.5   -- the pedals turn with the back wheel at this share of its speed
local LEG_KP = 60         -- the leg muscles' strength while pedalling
local HIP_BACK = math.rad(35) -- facing a side the hips only swing forward (sitting); a pedalling
                              -- thigh goes a little behind the body at the back of the circle

local function partAngle(dx, dy) return math.atan2(dy, dx) - math.pi / 2 end -- 0 = pointing down

-- The legs ready to pedal: hips some room behind, ankles free, feet held flat by a muscle.
local function legsPedal(inst)
    for _, leg in ipairs({ 'luleg', 'ruleg' }) do
        local part, torso = inst.parts[leg], inst.parts.torso1
        for _, joint in ipairs(part and part.body:getJoints() or {}) do
            local a, b = joint:getBodies()
            if a == torso.body and b == part.body and joint:getType() == 'revolute' then
                local lo, up = joint:getLimits()
                joint:setLimits(lo, up + HIP_BACK) -- facing right: behind is the upper side
            end
        end
    end
    for _, foot in ipairs({ 'lfoot', 'rfoot' }) do
        local f = inst.parts[foot]
        for _, joint in ipairs(f and f.body:getJoints() or {}) do
            local _, b = joint:getBodies()
            if b == f.body and joint:getType() == 'revolute' then joint:setLimitsEnabled(false) end
        end
        local keep = mipoActions.ensureKeepAngle(f, -90, LEG_KP)
        if keep then keep.angle, keep.enabled = -90, nil end -- flat, toes forward (facing right)
    end
end

-- Each leg's muscles aimed so its foot reaches its pedal: the knee where a thigh and a shin of
-- these lengths meet between hip and pedal, the knee forward (it faces right). Out of reach,
-- the leg stretches toward it.
local function pedalLegs(inst, bike)
    local crank = bike.crankAngle or 0
    local cx, cy = bike.frame:getWorldPoint(bike.crankX, bike.crankY)
    for i, side in ipairs({ 'l', 'r' }) do
        local u, l = side .. 'uleg', side .. 'lleg'
        local hx, hy = jointPoint(inst, 'torso1', u)
        if hx then
            local a = crank + (i - 1) * math.pi
            local px, py = cx + math.cos(a) * bike.crankR, cy + math.sin(a) * bike.crankR
            local t, s2 = bike.thigh, bike.shin
            local dx, dy = px - hx, py - hy
            local d = math.max(math.abs(t - s2) + 1, math.min(t + s2 - 1, math.sqrt(dx * dx + dy * dy)))
            local toPedal = math.atan2(dy, dx)
            local atHip = math.acos(math.max(-1, math.min(1, (t * t + d * d - s2 * s2) / (2 * t * d))))
            local thighDir = toPedal - atHip -- the knee forward (toward +x)
            local kx, ky = hx + math.cos(thighDir) * t, hy + math.sin(thighDir) * t
            local upper = mipoActions.ensureKeepAngle(inst.parts[u], 0, LEG_KP)
            local lower = mipoActions.ensureKeepAngle(inst.parts[l], 0, LEG_KP)
            if upper then upper.angle, upper.enabled, upper.kp = math.deg(partAngle(kx - hx, ky - hy)), nil, LEG_KP end
            if lower then lower.angle, lower.enabled, lower.kp = math.deg(partAngle(px - kx, py - ky)), nil, LEG_KP end
        end
    end
end

-- ─── The bike, sized from the Mipo's legs ───

-- how tall the Mipo stands (its solid shapes, top to bottom)
local mipoHeight = characterManager.mipoHeight -- src/mipo-build.lua

local function makeBike(inst, x, y)
    -- Sized from the whole Mipo (from the legs alone, a Mipo that's mostly body and head got a
    -- bike "way too small"); a short-legged one's feet just rest higher.
    local size = mipoHeight(inst)
    -- (0.3 / 1.0 of its height: "way too" big the other way; a kid's bike)
    local leg = size * 0.33         -- the bike's own measure (saddle height, bars)
    local r = size * 0.2            -- wheel radius
    local base = size * 0.7         -- wheelbase
    local group = inst.groupIndex   -- the bike and its rider don't collide

    local bike = { leg = leg, r = r, base = base }
    local function fixture(body, shape, density)
        local f = love.physics.newFixture(body, shape, density)
        f:setGroupIndex(group)
        f:setFriction(FRICTION)
        return f
    end
    -- frame: rear axle at (x - base/2, y), front at (x + base/2, y); saddle and bars relative to it
    bike.frame = love.physics.newBody(world, x, y, 'dynamic')
    bike.frame:setLinearDamping(AIR)
    local seatX, seatY = -leg * 0.45, -r * 0.25 - leg * 0.8
    local barX, barY = base * 0.42, seatY - leg * 0.2
    bike.seatX, bike.seatY, bike.barX, bike.barY = seatX, seatY, barX, barY
    local rearTube = { -base / 2, -r * 0.2, seatX, seatY, seatX + 40, seatY, 0, -r * 0.1 }
    fixture(bike.frame, love.physics.newPolygonShape(unpack(rearTube)), BIKE_DENSITY)
    local frontTube = { 0, -r * 0.1, seatX + 40, seatY, barX, barY, base / 2, -r * 0.2 }
    fixture(bike.frame, love.physics.newPolygonShape(unpack(frontTube)), BIKE_DENSITY)
    fixture(bike.frame, love.physics.newRectangleShape(seatX, seatY - 15, 160, 30), 1) -- the saddle
    local function wheel(wx)
        local w = love.physics.newBody(world, x + wx, y, 'dynamic')
        fixture(w, love.physics.newCircleShape(r), BIKE_DENSITY / 2)
        local j = love.physics.newRevoluteJoint(bike.frame, w, x + wx, y, false)
        return w, j
    end
    bike.back, bike.backJoint = wheel(-base / 2)
    bike.front, bike.frontJoint = wheel(base / 2)
    return bike
end

local function bikeBodies(bike)
    return { bike.frame, bike.back, bike.front }
end

-- ─── The Mipo on it ───

-- legs folded into a sitting pose (thigh forward, shin down), the hips on the saddle
local function seatMipo(inst, bike)
    local forward = -math.pi / 2 * 0.7 -- the thighs most of the way forward (facing right)
    for _, side in ipairs({ 'l', 'r' }) do
        local u, l, f = side .. 'uleg', side .. 'lleg', side .. 'foot'
        local hx, hy = jointPoint(inst, 'torso1', u)
        if hx then
            turnParts(inst, { u, l, f }, hx, hy, forward - inst.parts[u].body:getAngle())
            local kx, ky = jointPoint(inst, u, l)
            turnParts(inst, { l, f }, kx, ky, -inst.parts[l].body:getAngle())
        end
    end
    local sx, sy = bike.frame:getWorldPoint(bike.seatX, bike.seatY - 20)
    local hx, hy = jointPoint(inst, 'torso1', 'luleg')
    moveAll(inst, sx - hx, sy - hy)
end

-- the hold: hips at the saddle, hands at the bars (pulled there over the first moments), feet on
-- footrests where the sitting pose put them
local function holdOn(inst, bike)
    local joints = {}
    local hx, hy = jointPoint(inst, 'torso1', 'luleg')
    local sx, sy = bike.frame:getWorldPoint(bike.seatX, bike.seatY - 20)
    local seat = love.physics.newWeldJoint(bike.frame, inst.parts.torso1.body, sx, sy, hx, hy, false)
    seat:setFrequency(6)
    seat:setDampingRatio(0.7)
    joints[#joints + 1] = seat
    local bx, by = bike.frame:getWorldPoint(bike.barX, bike.barY)
    for _, hand in ipairs({ 'lhand', 'rhand' }) do
        local h = inst.parts[hand]
        if h then
            local px, py = h.body:getPosition()
            joints[#joints + 1] = love.physics.newRevoluteJoint(bike.frame, h.body, bx, by, px, py, false)
        end
    end
    return joints
end

-- The crank where this Mipo's legs reach it well (the bike is sized from its height, the legs
-- vary): below and a little in front of the hips, the pedal circle within a bent leg's reach.
local function placeCrank(inst, bike)
    local hx, hy = jointPoint(inst, 'torso1', 'luleg')
    local kx, ky = jointPoint(inst, 'luleg', 'llleg')
    local ax, ay = jointPoint(inst, 'llleg', 'lfoot')
    bike.thigh = math.sqrt((kx - hx) ^ 2 + (ky - hy) ^ 2)
    bike.shin = math.sqrt((ax - kx) ^ 2 + (ay - ky) ^ 2)
    local leg = bike.thigh + bike.shin
    bike.crankR = leg * 0.12
    local lx, ly = bike.frame:getLocalPoint(hx, hy)
    bike.crankX, bike.crankY = lx + leg * 0.3, ly + leg * 0.72
end

-- ─── The lift: a tray at the bottom carries bike and rider back up to the start ───
-- A cable car: the bike rolls onto the tray lying at the bottom and comes to rest; low edges
-- come up at both ends; the tray (a moving platform, kinematic) rides up, back over the hill and
-- down to the start, tips forward with its front edge open so the bike rolls off down the hill
-- again, and goes back the same way.

local LIFT_SPEED = 900          -- along its way, a second
local HOME_SPEED = 2700         -- empty, back to the bottom: there before the bike rides down
local LIFT_ACCEL = 1.2          -- how quickly it gets up to speed (1/s): no jerk to tip the rider
local LIFT_TOP = START_Y - 1100 -- the height it travels back at
local DOCK_X = END_X - 1450     -- where the tray waits, on the flat at the bottom
local TIP = 0.2                 -- radians the tray tips forward at the start
local SETTLE = 0.8              -- seconds the bike rests on the tray before it goes
local CATCH_SPEED = 400         -- slower than this, fully on the tray, its edges come up

local function destroyLift()
    local c = check()
    if c.lift and alive(c.lift.body) then c.lift.body:destroy() end
    c.lift = nil
end

-- the tray, as long as the bike plus room; its body's origin is the middle of its top
local function makeLift(bike)
    destroyLift()
    local L = bike.base + bike.r * 2 + bike.r * 1.5
    local T, H = bike.r * 0.25, bike.r * 0.9 -- plate thickness, edge height
    local body = love.physics.newBody(world, DOCK_X, courseHeight(DOCK_X), 'kinematic')
    local plate = love.physics.newFixture(body, love.physics.newRectangleShape(0, T / 2, L, T), 1)
    plate:setFriction(FRICTION)
    local function lip(x)
        local f = love.physics.newFixture(body, love.physics.newRectangleShape(x, -H / 2, T, H), 1)
        f:setSensor(true) -- open while waiting
        return f
    end
    local startX = START_X - L / 2 - 80
    local lift = { body = body, L = L, T = T, H = H, phase = 'wait', back = lip(-L / 2), front = lip(L / 2),
        vx = 0, vy = 0,
        carry = { { DOCK_X, LIFT_TOP }, { startX, LIFT_TOP }, { startX, courseHeight(startX) } },
        home = { { startX, LIFT_TOP }, { DOCK_X, LIFT_TOP }, { DOCK_X, courseHeight(DOCK_X) } } }
    check().lift = lift
    return lift
end

-- the wheels held (a joint motor at zero speed), as a lift clamps a bike: free wheels rolled
-- against the tray's edge when it started sideways and hopped over it
local function brake(bike, on)
    for _, joint in ipairs({ bike.backJoint, bike.frontJoint }) do
        if joint and not joint:isDestroyed() then
            joint:setMotorEnabled(on)
            joint:setMotorSpeed(0)
            joint:setMaxMotorTorque(on and 1e9 or 0)
        end
    end
end

-- Nothing solid where the tray's edges come up? An edge turned solid through a wheel or the
-- rider's foot shoved them apart with a jolt: the bike flew back up the hill, the rider dazed.
local function lipsClear(lift)
    local clear = true
    for _, lip in ipairs({ lift.back, lift.front }) do
        local x1, y1, x2, y2 = lip:getBoundingBox()
        world:queryBoundingBox(x1, y1, x2, y2, function(fixture)
            if fixture:getBody() ~= lift.body and not fixture:isSensor()
                and fixture:getBody():getType() ~= 'static' then
                clear = false
                return false
            end
            return true
        end)
    end
    return clear
end

local function setLips(lift, closed)
    lift.back:setSensor(not closed)
    lift.front:setSensor(not closed)
end

-- along the path a little each frame; true once at its end
local function follow(lift, path, dt, topSpeed)
    local body = lift.body
    local target = path[lift.step]
    if not target then return true end
    local x, y = body:getPosition()
    local dx, dy = target[1] - x, target[2] - y
    local d = math.sqrt(dx * dx + dy * dy)
    -- slow down near the end of the path, so it arrives gently
    local last = lift.step == #path
    topSpeed = topSpeed or LIFT_SPEED
    local speed = last and math.min(topSpeed, d * 2) or topSpeed
    local wantX, wantY = 0, 0
    if d > 1 then wantX, wantY = dx / d * speed, dy / d * speed end
    local k = math.min(1, dt * LIFT_ACCEL)
    lift.vx, lift.vy = lift.vx + (wantX - lift.vx) * k, lift.vy + (wantY - lift.vy) * k
    body:setLinearVelocity(lift.vx, lift.vy)
    if d < (last and 3 or 60) then lift.step = lift.step + 1 end
    if lift.step > #path then
        body:setLinearVelocity(0, 0)
        lift.vx, lift.vy = 0, 0
        return true
    end
    return false
end

-- both wheels between the tray's edges (the middle alone wasn't enough: a front wheel stood on
-- the front edge as it came up, and the bike fell off on the way)
local function bikeOnTray(lift, bike)
    local lx = lift.body:getPosition()
    local fx = bike.frame:getPosition()
    return math.abs(fx - lx) < lift.L / 2 - bike.base / 2 - bike.r - lift.T
end

local function updateLift(lift, bike, dt)
    local body = lift.body
    if lift.phase == 'wait' then
        -- fully on and slow-ish: the edges come up and catch it rolling back and forth
        local vx = bike.frame:getLinearVelocity()
        if bikeOnTray(lift, bike) and math.abs(vx) < CATCH_SPEED and lipsClear(lift) then
            setLips(lift, true)
            lift.phase, lift.still = 'catch', 0
        end
    elseif lift.phase == 'catch' then
        -- at rest a moment: off it goes
        local vx = bike.frame:getLinearVelocity()
        lift.still = math.abs(vx) < 40 and lift.still + dt or 0
        if lift.still > SETTLE then
            brake(bike, true)
            lift.phase, lift.step, lift.still = 'carry', 1, 0
        end
    elseif lift.phase == 'carry' then
        if follow(lift, lift.carry, dt) then lift.phase = 'tip' end
    elseif lift.phase == 'tip' then
        -- forward (clockwise), its front edge open, the wheels free: the bike rolls off downhill
        lift.front:setSensor(true)
        brake(bike, false)
        if body:getAngle() < TIP then
            body:setAngularVelocity(0.6)
        else
            body:setAngularVelocity(0)
            local lx = body:getPosition()
            if bike.frame:getPosition() > lx + lift.L / 2 + bike.base then lift.phase = 'level' end
        end
    elseif lift.phase == 'level' then
        if body:getAngle() > 0 then
            body:setAngularVelocity(-0.6)
        else
            body:setAngularVelocity(0)
            body:setAngle(0)
            setLips(lift, false)
            lift.phase, lift.step = 'home', 1
        end
    elseif lift.phase == 'home' then
        -- not down onto the bike: if it's at the bottom already, wait above till it rolls clear
        local fx = bike.frame:getPosition()
        local bikeBelow = math.abs(fx - DOCK_X) < lift.L / 2 + bike.base
        if lift.step == #lift.home and bikeBelow then
            lift.vx, lift.vy = 0, 0
            body:setLinearVelocity(0, 0)
        elseif follow(lift, lift.home, dt, HOME_SPEED) then
            lift.phase = 'wait'
        end
    end
end

local function removeRide()
    local c = check()
    destroyLift()
    for _, j in ipairs(c.joints or {}) do
        if not j:isDestroyed() then j:destroy() end
    end
    c.joints = nil
    if c.bike then
        for _, b in ipairs(bikeBodies(c.bike)) do
            if alive(b) then b:destroy() end
        end
    end
    c.bike = nil
    if c.mipo and c.mipo.parts and c.mipo.parts.torso1 and alive(c.mipo.parts.torso1.body) then
        characterManager.removeCharacter(c.mipo)
    end
    c.mipo = nil
end

local function newRide()
    local c = check()
    removeRide()
    local inst = characterManager.createCharacter('humanoid', START_X, courseHeight(START_X) - 2000, SCALE)
    if not inst then return end
    characterManager.randomizeMipo(inst)
    characterManager.switchFacing(inst, 'right')
    local bike = makeBike(inst, START_X, courseHeight(START_X))
    -- the bike's wheels on the ground
    for _, b in ipairs(bikeBodies(bike)) do
        local bx, by = b:getPosition()
        b:setPosition(bx, by - bike.r - 2)
    end
    seatMipo(inst, bike)
    placeCrank(inst, bike)
    legsPedal(inst)
    c.mipo, c.bike = inst, bike
    c.joints = holdOn(inst, bike)
    makeLift(bike)
end

-- back to the top: the bike and its rider moved as one (the lift comes next)
local function backToTop()
    local c = check()
    local frame = c.bike.frame
    local fx, fy = frame:getPosition()
    local dx = START_X - fx
    local dy = (courseHeight(START_X) - c.bike.r - 2) - fy
    local bodies = bikeBodies(c.bike)
    for _, part in pairs(c.mipo.parts) do bodies[#bodies + 1] = part.body end
    local angle = frame:getAngle()
    for _, b in ipairs(bodies) do
        if alive(b) then
            local x, y = b:getPosition()
            b:setPosition(x + dx, y + dy)
            b:setLinearVelocity(0, 0)
            b:setAngularVelocity(0)
        end
    end
    turnBodies(bodies, START_X, fy + dy, -angle) -- the bike level again, turned about its frame
end

-- ─── Drawing: tires of the rider's own leg picture, spokes, the frame, the course ───

local SPOKES = 8
local TIRE = 0.3      -- tire thickness, of the wheel radius
local TIRE_REPEAT = 3 -- the leg picture this many times round a tire
local TIRE_STEPS = 48
local TIRE_MIDDLE = { 0.2, 0.8 } -- the part of the leg picture used along the tire

-- the rider's composed leg picture (its connected skin on the upper leg, in its colours)
local function legPicture(inst)
    for _, name in ipairs({ 'luleg', 'ruleg' }) do
        local part = inst.parts[name]
        for _, fixture in ipairs(part and alive(part.body) and part.body:getFixtures() or {}) do
            local ud = fixture:getUserData()
            local e = ud and ud.subtype == 'connected-texture' and ud.extra
            if e and e.ompImage and e.main and not tostring(e.main.bgURL):find('hair') then return e.ompImage end
        end
    end
end

-- ─── The wheel, baked once into a picture that's drawn turning ───
-- The tire: a Mipo leg picture baked as an OMP (outline, mask) in rubber colours, laid round as
-- a ribbon (leg-05's ladder rungs read as tread, as the garden worm's rings); w cycles the six.
-- The spokes and hub: Nikki's crayon strokes (src/drawn-stroke.lua).

local STROKE = drawnStroke()
local RUBBER = { 0.26, 0.24, 0.23 }
local INK = { 0.09, 0.08, 0.08 }
local SPOKE_COUNT = 12
local LEG_PICTURES = 6

local function bakeTirePicture(n)
    local url = string.format('textures/mipo/leg/leg-%02d', n)
    local blank = love.graphics.newImage(love.image.newImageData(1, 1))
    local imageData = ompBake.makeTexturedCanvas(love.graphics.newImage(url .. '.png'),
        love.graphics.newImage(url .. '-mask.png'), RUBBER, 1, blank, INK, 0, 0, 1, 1, 0, 0, INK, 1, 1, 1)
    local image = love.graphics.newImage(imageData)
    imageData:release()
    return image
end

-- tire, spokes and hub on one canvas, the wheel's middle at its middle
local function bakeWheel(r, tirePicture)
    local size = math.ceil(r * 2 + 8)
    local canvas = love.graphics.newCanvas(size, size)
    local m = size / 2
    love.graphics.push('all')
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.origin()
    local inner = r * (1 - TIRE)
    -- spokes and the hub's rim, crayon
    local lines = {}
    for i = 1, SPOKE_COUNT do
        local a = i / SPOKE_COUNT * math.pi * 2 + (i % 2) * 0.05 -- a little uneven, hand-made
        lines[#lines + 1] = { pts = { { m + math.cos(a) * r * 0.1, m + math.sin(a) * r * 0.1 },
            { m + math.cos(a) * inner, m + math.sin(a) * inner } }, loop = false, width = math.max(3, r * 0.035) }
    end
    local hub = {}
    for i = 0, 9 do
        local a = i / 10 * math.pi * 2
        hub[#hub + 1] = { m + math.cos(a) * r * 0.11, m + math.sin(a) * r * 0.11 }
    end
    lines[#lines + 1] = { pts = hub, loop = true, width = math.max(3, r * 0.05) }
    love.graphics.setColor(INK[1], INK[2], INK[3], 0.85)
    for _, mesh in ipairs(STROKE.meshes(lines, 0.6, 0, true)) do love.graphics.draw(mesh) end
    -- the tire
    local verts = {}
    for i = 0, TIRE_STEPS do
        local a = i / TIRE_STEPS * math.pi * 2
        local cs, sn = math.cos(a), math.sin(a)
        local t = (i / TIRE_STEPS * TIRE_REPEAT) % 2
        local v = TIRE_MIDDLE[1] + (TIRE_MIDDLE[2] - TIRE_MIDDLE[1]) * (t < 1 and t or 2 - t)
        verts[#verts + 1] = { m + cs * r, m + sn * r, 0, v }
        verts[#verts + 1] = { m + cs * inner, m + sn * inner, 1, v }
    end
    local mesh = love.graphics.newMesh(verts, 'strip', 'static')
    mesh:setTexture(tirePicture)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(mesh)
    love.graphics.pop()
    return canvas
end

local function drawWheel(wheel, image)
    local x, y = wheel:getPosition()
    local w, h = image:getDimensions()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, x, y, wheel:getAngle(), 1, 1, w / 2, h / 2)
end

local tireMesh
local function drawTire(wheel, r, picture)
    local x, y = wheel:getPosition()
    local a0 = wheel:getAngle()
    local inner = r * (1 - TIRE)
    if picture then
        local verts = {}
        for i = 0, TIRE_STEPS do
            local a = a0 + i / TIRE_STEPS * math.pi * 2
            local cs, sn = math.cos(a), math.sin(a)
            -- only the leg picture's even middle (its ends are rounded: gaps), back and forth
            local t = (i / TIRE_STEPS * TIRE_REPEAT) % 2
            local v = TIRE_MIDDLE[1] + (TIRE_MIDDLE[2] - TIRE_MIDDLE[1]) * (t < 1 and t or 2 - t)
            verts[#verts + 1] = { x + cs * r, y + sn * r, 0, v }
            verts[#verts + 1] = { x + cs * inner, y + sn * inner, 1, v }
        end
        if not tireMesh or tireMesh:getVertexCount() ~= #verts then
            tireMesh = love.graphics.newMesh(#verts, 'strip', 'stream')
        end
        tireMesh:setVertices(verts)
        tireMesh:setTexture(picture)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(tireMesh)
    else
        love.graphics.setColor(0.15, 0.12, 0.1)
        love.graphics.setLineWidth(r * TIRE)
        love.graphics.circle('line', x, y, r * (1 - TIRE / 2))
    end
    -- spokes
    love.graphics.setColor(0.2, 0.17, 0.15, 0.9)
    love.graphics.setLineWidth(math.max(2, r * 0.025))
    for i = 1, SPOKES do
        local a = a0 + i / SPOKES * math.pi * 2
        love.graphics.line(x, y, x + math.cos(a) * inner, y + math.sin(a) * inner)
    end
    love.graphics.circle('fill', x, y, r * 0.08) -- the hub
end

-- the frame as tubes: rear axle - saddle - bars - front axle, and the bottom tube; the saddle
local function drawFrame(bike)
    local f = bike.frame
    local function p(x, y) return f:getWorldPoint(x, y) end
    local rx, ry = p(-bike.base / 2, 0)
    local fx, fy = p(bike.base / 2, 0)
    local sx, sy = p(bike.seatX, bike.seatY)
    local bx, by = p(bike.barX, bike.barY)
    local mx, my = p(0, -bike.r * 0.1)
    love.graphics.setColor(0.75, 0.3, 0.25)
    love.graphics.setLineWidth(bike.r * 0.09)
    love.graphics.setLineJoin('bevel')
    love.graphics.line(rx, ry, sx, sy, bx, by, fx, fy)
    love.graphics.line(rx, ry, mx, my, sx, sy)
    love.graphics.line(mx, my, bx, by)
    -- saddle and handlebar grip
    love.graphics.setColor(0.2, 0.15, 0.12)
    love.graphics.push()
    love.graphics.translate(sx, sy)
    love.graphics.rotate(f:getAngle())
    love.graphics.rectangle('fill', -bike.r * 0.35, -bike.r * 0.12, bike.r * 0.7, bike.r * 0.14, bike.r * 0.07)
    love.graphics.pop()
    love.graphics.circle('fill', bx, by, bike.r * 0.08)
end

local function drawCourse(ground)
    love.graphics.setColor(0.35, 0.25, 0.15)
    love.graphics.setLineWidth(14)
    for _, fixture in ipairs(ground:getFixtures()) do
        love.graphics.line(ground:getWorldPoints(fixture:getShape():getPoints()))
    end
end

-- the cable overhead, the rope down to the tray, the tray and its edges
local function drawLift(lift)
    local body = lift.body
    local x, y = body:getPosition()
    local cableY = LIFT_TOP - 900
    love.graphics.setColor(0.2, 0.18, 0.16, 0.8)
    love.graphics.setLineWidth(6)
    love.graphics.line(START_X - 800, cableY, END_X - 1000, cableY)
    love.graphics.line(x, cableY, x, y - lift.H)
    love.graphics.setColor(0.45, 0.6, 0.75)
    for _, fixture in ipairs(body:getFixtures()) do
        if not (fixture:isSensor() and fixture ~= lift.back and fixture ~= lift.front) then
            local alpha = fixture:isSensor() and 0.35 or 1
            love.graphics.setColor(0.45, 0.6, 0.75, alpha)
            love.graphics.polygon('fill', body:getWorldPoints(fixture:getShape():getPoints()))
        end
    end
end

-- the crank arm and the two pedals
local function drawCrank(bike)
    if not bike.crankX then return end
    local cx, cy = bike.frame:getWorldPoint(bike.crankX, bike.crankY)
    local a = bike.crankAngle or 0
    local r = bike.crankR
    local x1, y1 = cx + math.cos(a) * r, cy + math.sin(a) * r
    local x2, y2 = cx - math.cos(a) * r, cy - math.sin(a) * r
    love.graphics.setColor(0.25, 0.22, 0.2)
    love.graphics.setLineWidth(bike.r * 0.07)
    love.graphics.line(x1, y1, x2, y2)
    love.graphics.circle('fill', cx, cy, bike.r * 0.12) -- the chainring
    for _, p in ipairs({ { x1, y1 }, { x2, y2 } }) do
        love.graphics.rectangle('fill', p[1] - bike.r * 0.12, p[2] - bike.r * 0.03, bike.r * 0.24, bike.r * 0.06)
    end
end

function s.drawBelow()
    local c = check()
    -- in play the script draws the course and bike itself; the debug shapes off meanwhile
    if state.playMode then
        c.savedDrawBodies = state.world.debugDrawBodies
        state.world.debugDrawBodies = false
    end
    if alive(c.ground) then drawCourse(c.ground) end
    if c.lift and alive(c.lift.body) then drawLift(c.lift) end
    if c.bike and alive(c.bike.frame) then
        local picture = c.mipo and legPicture(c.mipo)
        if c.wheelImage then
            drawWheel(c.bike.back, c.wheelImage)
            drawWheel(c.bike.front, c.wheelImage)
        else
            drawTire(c.bike.back, c.bike.r, picture)
            drawTire(c.bike.front, c.bike.r, picture)
        end
        drawFrame(c.bike)
        drawCrank(c.bike)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function s.draw()
    local c = check()
    if c.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = c.savedDrawBodies
        c.savedDrawBodies = nil
    end
end

-- ─── Scene ───

function s.onStart()
    worldState.paused = false
    makeCourse()
    local c = check()
    if not (c.mipo and c.mipo.parts and c.mipo.parts.torso1 and alive(c.mipo.parts.torso1.body)) then newRide() end
end

function s.onUnload()
    local c = state.bikeSpike
    if not c then return end
    removeRide()
    destroyLift()
    if alive(c.ground) then c.ground:destroy() end
    c.ground = nil
end

function s.update()
    local c = check()
    if not (c.bike and alive(c.bike.frame)) then return end
    local frame = c.bike.frame
    local fx, fy = frame:getPosition()
    -- the rider sits upright on the bike: its torso's muscle aims at the frame's angle
    -- the pedals turn with the back wheel, the legs follow them
    c.bike.crankAngle = c.bike.back:getAngle() * PEDAL_RATIO
    pedalLegs(c.mipo, c.bike)
    local torsoKeep = mipoActions.getKeepAngle(c.mipo.parts.torso1)
    if torsoKeep then torsoKeep.angle = math.deg(frame:getAngle()) end
    -- the camera rides along (until you touch, drag or zoom)
    if not (c.noCam or love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0) then
        cam:setScale(0.35)
        local tx, ty = cam:getTranslation()
        cam:setTranslation(tx + (fx - tx) * 0.1, ty + (fy - 250 - ty) * 0.1)
    end
    -- the wheel picture, baked once per bike size and tire picture (a bake draws to canvases)
    local key = math.floor(c.bike.r) .. ':' .. (c.tirePicture or 5)
    if c.wheelFor ~= key then
        c.wheelImage = bakeWheel(c.bike.r, bakeTirePicture(c.tirePicture or 5))
        c.wheelFor = key
    end
    local dt = math.min(love.timer.getDelta(), 0.05)
    if c.lift and alive(c.lift.body) then updateLift(c.lift, c.bike, dt) end
    -- rescue: stuck somewhere off the lift for long (fallen over, wedged): back to the top
    local vx, vy = frame:getLinearVelocity()
    local riding = c.lift and c.lift.phase ~= 'wait'
    if not riding and vx * vx + vy * vy < 30 * 30 and not (c.lift and bikeOnTray(c.lift, c.bike)) then
        c.stillFor = (c.stillFor or 0) + dt
        if c.stillFor > 8 then
            c.stillFor = 0
            backToTop()
        end
    else
        c.stillFor = 0
    end
end

function s.onKeyPress(key)
    if key == 'r' then newRide() end
    if key == 'w' then -- the next leg picture as the tire
        local c = check()
        c.tirePicture = (c.tirePicture or 5) % LEG_PICTURES + 1
        c.wheelImage, c.wheelFor = nil, nil
    end
    if key == 'p' then worldState.paused = not worldState.paused end
end

return s

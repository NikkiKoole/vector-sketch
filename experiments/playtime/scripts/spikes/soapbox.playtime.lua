-- soapbox: a Mipo in a soapbox cart (zeepkist) rolling down a hill by itself, a knikkerbaan to
-- watch (no buttons; docs/SOAPBOX.md). After the bike (docs/BIKE.md, parked: "other vehicles
-- suit better"), whose course, cable-car lift and rider code this reuses. The cart: an open
-- wooden box on four pram wheels (two show), sized from the Mipo, heavy, a little air drag. The
-- Mipo faces right (src/mipo-facing.lua), sits inside held at the hips, legs stretched forward
-- against the front board by its leg muscles (aimed relative to the cart), hands on the
-- steering rope to the front axle; hips on a spring, so it bobs (SOAPBOX.md).
-- keys: r: a new Mipo in the cart   w: the next tire picture   p: pause

local s = {}

local SCALE = 0.3
local START_X, START_Y = -3000, 0
local END_X = 9000
local FRICTION = 0.9
local CART_DENSITY = 4    -- set again from the rider's mass (ballast) once it sits in the cart
local CART_WEIGHT = 2     -- the cart (wheels included) weighs this many riders: its thin boards
                          -- weighed 3 against a much heavier Mipo, and it tipped over backwards
local AIR = 0.35          -- the cart's linear damping: a calmer top speed (0.25: ~1700 a second
                          -- at the bottom, into the end wall; 0.45 felt too damped)
-- Bounce (Nikki: "it feels very damped, and these soap carts aren't"): the rider bobs in the
-- basket on a spring, a bumpy course. (Wheels on springs too: Nikki wants them pinned.)
local SEAT_SPRING = 5     -- Hz, the hips in the basket: a bob, and it carries the rider (3 sagged)
local SEAT_DAMPING = 0.2

local function check() -- on state: a script hot reload keeps the ride
    state.soapboxSpike = state.soapboxSpike or {}
    return state.soapboxSpike
end

local function alive(body) return body and not body:isDestroyed() end

-- ─── The course: a long hill with humps, then flat ───

local function courseHeight(x)
    -- the end: flat (the lift's tray waits there), then a short rise to run out on
    -- (the bike's short steep rise tipped the short cart over backwards: longer and gentler)
    local flatFrom, riseFrom, riseLength = END_X - 2800, END_X - 1300, 1300
    if x > flatFrom then
        local base = courseHeight(flatFrom)
        if x <= riseFrom then return base end
        local u = math.min(x - riseFrom, riseLength)
        return base - u * u / riseLength * 0.15
    end
    local t = math.max(0, x - START_X)
    -- downhill from the start (a knikkerbaan: it rolls off by itself), humps along the way;
    -- 0.32 went far too fast (2900 a second at the bottom, into the end wall)
    -- ripples all the way down, and now and then a proper hump (bounce)
    local hump = math.max(0, math.sin(t / 600)) ^ 12 * 90
    return START_Y + t * 0.16 + math.sin(t / 700) * 90 + math.sin(t / 260) * 20 + math.sin(t / 95) * 9 - hump
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
local function jointPoint(inst, parentName, partName)
    local part, parent = inst.parts[partName], inst.parts[parentName]
    if not (part and parent) then return nil end
    for _, joint in ipairs(part.body:getJoints()) do
        local a, b = joint:getBodies()
        if a == parent.body and b == part.body then
            local x, y = joint:getAnchors()
            return x, y
        end
    end
end

-- turn bodies rigidly about a point
local function turnBodies(bodies, px, py, delta)
    local cs, sn = math.cos(delta), math.sin(delta)
    for _, b in ipairs(bodies) do
        if alive(b) then
            local x, y = b:getPosition()
            local rx, ry = x - px, y - py
            b:setPosition(px + rx * cs - ry * sn, py + rx * sn + ry * cs)
            b:setAngle(b:getAngle() + delta)
        end
    end
end

-- the same for a Mipo's parts by name (as characterManager.poseTpose does with arms)
local function turnParts(inst, names, px, py, delta)
    local bodies = {}
    for _, name in ipairs(names) do
        if inst.parts[name] then bodies[#bodies + 1] = inst.parts[name].body end
    end
    turnBodies(bodies, px, py, delta)
end

local function moveAll(inst, dx, dy)
    for _, part in pairs(inst.parts) do
        local b = part.body
        if alive(b) then
            local px, py = b:getPosition()
            b:setPosition(px + dx, py + dy)
            b:setLinearVelocity(0, 0)
            b:setAngularVelocity(0)
        end
    end
end

-- ─── Sitting in the cart: hips on a spring, muscles aimed at fixed angles ───
-- The hips ride on a spring (a wheel joint: up and down in the basket, turning freely), so the
-- rider bobs over the bumps (Nikki: "it feels very damped"; a weld's softness is only in its
-- turning, its position stayed rigid). Turning freely, the rider can't twist the cart: its torso
-- and leg muscles aim at fixed angles in the world (upright, legs forward). Aimed at the cart's
-- angle instead they made a loop (cart tilts, target with it, body turns the cart further) and
-- the cart went over, backwards and over its nose.

local THIGH = -82          -- degrees: the thighs forward, nearly level
local KNEE = 12            -- degrees bent: the shins a little lower than straight on
local FEET = -150          -- degrees: the feet up against the front board
-- Gentle muscles: they only hold a pose against gravity and the bumps. At a standing Mipo's
-- strength (kp 40, up to 15 rad/s) the torso, held 28 degrees back by the rope, swung its hips
-- hard every frame and through the hip spring braked the cart: it rocked at the start.
local RIDER_KP = 8
local RIDER_MAX_OMEGA = 2  -- rad/s at most

local POSE = { torso1 = 0, luleg = THIGH, ruleg = THIGH, llleg = THIGH + KNEE, rlleg = THIGH + KNEE,
    lfoot = FEET, rfoot = FEET }

-- every frame (waking from a daze after a hard knock turns all muscles back to standing)
local function riderMuscles(inst)
    for name, angle in pairs(POSE) do
        local keep = mipoActions.ensureKeepAngle(inst.parts[name], angle, RIDER_KP)
        if keep then
            keep.angle, keep.enabled, keep.kp, keep.maxOmega = angle, nil, RIDER_KP, RIDER_MAX_OMEGA
        end
    end
end

-- ankles free (the feet stand up against the board, past their usual range)
local function freeAnkles(inst)
    for _, foot in ipairs({ 'lfoot', 'rfoot' }) do
        local f = inst.parts[foot]
        for _, joint in ipairs(f and f.body:getJoints() or {}) do
            local _, b = joint:getBodies()
            if b == f.body and joint:getType() == 'revolute' then joint:setLimitsEnabled(false) end
        end
    end
end

-- ─── The cart, sized from the Mipo ───

-- how tall the Mipo stands (its solid shapes, top to bottom)
local function mipoHeight(inst)
    local top, bottom = math.huge, -math.huge
    for _, part in pairs(inst.parts) do
        for _, fixture in ipairs(alive(part.body) and part.body:getFixtures() or {}) do
            if not fixture:isSensor() then
                local _, y0, _, y1 = fixture:getBoundingBox()
                top, bottom = math.min(top, y0), math.max(bottom, y1)
            end
        end
    end
    return bottom - top
end

local function makeCart(inst, x, y)
    -- A basket the Mipo sits in, nothing of it below the floor (Nikki: "a little basket where
    -- the Mipo sits in, not touching his body against the ground under it"; with the hip joint
    -- on a low floor the body stuck out underneath, dragged and rolled the cart over and over)
    local size = mipoHeight(inst)
    local hx, hy = jointPoint(inst, 'torso1', 'luleg')
    local ax, ay = jointPoint(inst, 'llleg', 'lfoot')
    local legReach = math.sqrt((ax - hx) ^ 2 + (ay - hy) ^ 2)
    local len = math.max(size * 0.85, legReach + size * 0.35) -- room for the legs stretched out
    local H = size * 0.34            -- the basket's walls
    local T = size * 0.04            -- board thickness
    local r = size * 0.14            -- pram wheels
    local base = len * 0.85          -- wheelbase
    local floorY = -r * 0.3          -- the floor's top, above the axles (1.3 wheels off the ground)
    -- The rider collides with the basket's boards (its legs rest on the floor, its feet against
    -- the front board: with gentle muscles they drooped through it and dragged on the ground),
    -- not with the wheels.
    local group = inst.groupIndex

    local cart = { size = size, len = len, H = H, T = T, r = r, base = base, floorY = floorY }
    local function fixture(body, shape, density, solidToRider)
        local f = love.physics.newFixture(body, shape, density)
        if not solidToRider then f:setGroupIndex(group) end
        f:setFriction(FRICTION)
        return f
    end
    cart.frame = love.physics.newBody(world, x, y, 'dynamic')
    cart.frame:setLinearDamping(AIR)
    -- the basket: floor, back and front walls
    cart.boards = {
        { 0, floorY + T / 2, len, T },
        { -len / 2 + T / 2, floorY - H / 2, T, H },
        { len / 2 - T / 2, floorY - H * 0.4, T, H * 0.8 },
    }
    for _, b in ipairs(cart.boards) do
        fixture(cart.frame, love.physics.newRectangleShape(b[1], b[2], b[3], b[4]), CART_DENSITY, true)
    end
    cart.seatX, cart.seatY = -len / 2 + T + size * 0.13, floorY - 6       -- where the hips go (x)
    cart.holdX, cart.holdY = len / 2 - T - size * 0.12, floorY - H * 0.55 -- the steering rope, held
    local function wheel(wx)
        local w = love.physics.newBody(world, x + wx, y, 'dynamic')
        fixture(w, love.physics.newCircleShape(r), CART_DENSITY / 2)
        -- a fixed axle (Nikki: the wheels pinned to the cart; tried 2026-11-06: on springs)
        local j = love.physics.newRevoluteJoint(cart.frame, w, x + wx, y, false)
        return w, j
    end
    cart.back, cart.backJoint = wheel(-base / 2)
    cart.front, cart.frontJoint = wheel(base / 2)
    return cart
end

local function cartBodies(bike)
    return { bike.frame, bike.back, bike.front }
end

-- ─── The Mipo in it ───

-- legs folded forward (the soapbox pose), the hips on the cart's floor at the back
local function seatMipo(inst, cart)
    for _, side in ipairs({ 'l', 'r' }) do
        local u, l, f = side .. 'uleg', side .. 'lleg', side .. 'foot'
        local hx, hy = jointPoint(inst, 'torso1', u)
        if hx then
            turnParts(inst, { u, l, f }, hx, hy, math.rad(THIGH) - inst.parts[u].body:getAngle())
            local kx, ky = jointPoint(inst, u, l)
            turnParts(inst, { l, f }, kx, ky, math.rad(THIGH + KNEE) - inst.parts[l].body:getAngle())
        end
    end
    -- the hips over the seat, and the Mipo's lowest point (body, legs or feet) just above the floor
    local sx = cart.frame:getWorldPoint(cart.seatX, cart.seatY)
    local hx = jointPoint(inst, 'torso1', 'luleg')
    local lowest = -math.huge
    for _, part in pairs(inst.parts) do
        for _, fixture in ipairs(alive(part.body) and part.body:getFixtures() or {}) do
            if not fixture:isSensor() then
                local _, _, _, y1 = fixture:getBoundingBox()
                lowest = math.max(lowest, y1)
            end
        end
    end
    local _, floorTop = cart.frame:getWorldPoint(0, cart.floorY)
    moveAll(inst, sx - hx, floorTop - 4 - lowest)
end

-- Ballast: the cart weighs CART_WEIGHT riders, most in the frame (low, its boards), some in the
-- wheels
local function ballast(cart, inst)
    local rider = mipoRegistry.totalMass(inst)
    local frameShare, wheelShare = 0.8, 0.1
    for body, share in pairs({ [cart.frame] = frameShare, [cart.back] = wheelShare, [cart.front] = wheelShare }) do
        local now = body:getMass()
        if now > 0 then
            local k = rider * CART_WEIGHT * share / now
            for _, f in ipairs(body:getFixtures()) do f:setDensity(f:getDensity() * k) end
            body:resetMassData()
        end
    end
end

-- the hold: hips on the floor (a soft weld), hands on the rope (pulled there over the first moments)
local function holdOn(inst, cart)
    local joints = {}
    local hx, hy = jointPoint(inst, 'torso1', 'luleg')
    local seat = love.physics.newWheelJoint(cart.frame, inst.parts.torso1.body, hx, hy, 0, 1, false)
    seat:setSpringFrequency(SEAT_SPRING)
    seat:setSpringDampingRatio(SEAT_DAMPING)
    joints[#joints + 1] = seat
    -- the rope held where the arms reach easily: forward and a little down from the shoulders (at
    -- the front of the basket the hands pulled the rider over, slumped 50-75 degrees)
    local bx, by = cart.frame:getWorldPoint(cart.holdX, cart.holdY)
    local shoulder = inst.parts.luarm and inst.parts.luarm.body
    for _, joint in ipairs(shoulder and shoulder:getJoints() or {}) do
        local a, b = joint:getBodies()
        if b == shoulder and a ~= inst.parts.llarm.body then
            local sx2, sy2 = joint:getAnchors()
            local ex, ey = jointPoint(inst, 'luarm', 'llarm')
            local wx, wy = jointPoint(inst, 'llarm', 'lhand')
            local arm = math.sqrt((ex - sx2) ^ 2 + (ey - sy2) ^ 2) + math.sqrt((wx - ex) ^ 2 + (wy - ey) ^ 2)
            bx, by = sx2 + arm * 0.65, sy2 + arm * 0.45
            local lx, ly = cart.frame:getLocalPoint(bx, by)
            cart.holdX, cart.holdY = lx, ly
        end
    end
    -- The hands hold the rope (drawn) but aren't pinned to the cart: pinned, they held the bobbing
    -- body at an angle and pulled it down the hip spring till it dragged on the ground. Free, the
    -- arms flap with the bumps.
    local _ = bx and by
    return joints
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
local DOCK_X = END_X - 2050     -- where the tray waits, on the flat at the bottom
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
        for _, b in ipairs(cartBodies(c.bike)) do
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
    -- a little way onto the slope (on the flat before it, it just sat there), just above the
    -- ground under both wheels
    local x0 = START_X + 400
    local bike = makeCart(inst, x0, courseHeight(x0))
    local lift = math.max(courseHeight(x0) - courseHeight(x0 - bike.base / 2),
        courseHeight(x0) - courseHeight(x0 + bike.base / 2), 0)
    for _, b in ipairs(cartBodies(bike)) do
        local bx, by = b:getPosition()
        b:setPosition(bx, by - bike.r - lift - 4)
    end
    seatMipo(inst, bike)
    freeAnkles(inst)
    riderMuscles(inst)
    ballast(bike, inst)
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
    local bodies = cartBodies(c.bike)
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
-- The spokes and hub: Nikki's crayon strokes (drawn-stroke.lua).

local STROKE = love.filesystem.load('scripts/spikes/drawn-stroke.lua')()
local RUBBER = { 0.26, 0.24, 0.23 }
local INK = { 0.09, 0.08, 0.08 }
local SPOKE_COUNT = 8 -- pram wheels
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

-- the cart's look in its own coordinates, made once: planks of wood, a crayon outline, plank seams
local WOOD = { 0.78, 0.58, 0.36 }
local WOOD_DARK = { 0.6, 0.42, 0.25 }
local function cartLook(cart)
    if cart.look then return cart.look end
    local outlines, seams = {}, {}
    for _, b in ipairs(cart.boards) do
        local x0, y0, x1, y1 = b[1] - b[3] / 2, b[2] - b[4] / 2, b[1] + b[3] / 2, b[2] + b[4] / 2
        outlines[#outlines + 1] = { pts = { { x0, y0 }, { x1, y0 }, { x1, y1 }, { x0, y1 } }, loop = true,
            width = math.max(3, cart.size * 0.012) }
    end
    -- the side of the box: planks between floor and back board top
    local backTop, frontTop = cart.floorY - cart.H, cart.floorY - cart.H * 0.8
    local bottom = cart.floorY + cart.T
    local side = { -cart.len / 2, backTop, cart.len / 2, frontTop, cart.len / 2, bottom, -cart.len / 2, bottom }
    for k = 1, 2 do
        local y = cart.floorY - cart.H * 0.27 * k
        seams[#seams + 1] = { pts = { { -cart.len / 2 + cart.T, y }, { cart.len / 2 - cart.T, y + cart.H * 0.08 * k } },
            loop = false, width = math.max(2, cart.size * 0.008), wobble = 0.5 }
    end
    outlines[#outlines + 1] = { pts = { { side[1], side[2] }, { side[3], side[4] }, { side[5], side[6] },
        { side[7], side[8] } }, loop = true, width = math.max(3, cart.size * 0.012) }
    cart.look = { side = side, inside = side, outline = STROKE.meshes(outlines, 0.6, 0, true),
        seams = STROKE.meshes(seams, 0.6, 0, true) }
    return cart.look
end

-- the inside of the basket behind the Mipo: its far side, darker
local function drawCartInside(cart)
    local look = cartLook(cart)
    local f = cart.frame
    local x, y = f:getPosition()
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(f:getAngle())
    love.graphics.setColor(WOOD_DARK)
    love.graphics.polygon('fill', look.inside)
    love.graphics.pop()
end

-- the box side, its outline and seams, turned with the cart; the steering rope from the hands to
-- the front axle
local function drawCart(cart, inst)
    local look = cartLook(cart)
    local f = cart.frame
    local x, y = f:getPosition()
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(f:getAngle())
    love.graphics.setColor(WOOD)
    love.graphics.polygon('fill', look.side)
    love.graphics.setColor(INK[1], INK[2], INK[3], 0.9)
    for _, mesh in ipairs(look.seams) do love.graphics.draw(mesh) end
    for _, mesh in ipairs(look.outline) do love.graphics.draw(mesh) end
    love.graphics.pop()
    -- the rope
    local hand = inst and inst.parts.rhand
    if hand and alive(hand.body) then
        local hx, hy = hand.body:getPosition()
        local ax, ay = f:getWorldPoint(cart.base / 2, -cart.r * 0.2)
        love.graphics.setColor(0.85, 0.75, 0.5)
        love.graphics.setLineWidth(math.max(3, cart.size * 0.01))
        love.graphics.line(hx, hy, (hx + ax) / 2, (hy + ay) / 2 + cart.size * 0.03, ax, ay)
    end
    love.graphics.setColor(WOOD_DARK)
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
        if not c.wheelImage then
            drawTire(c.bike.back, c.bike.r, picture)
            drawTire(c.bike.front, c.bike.r, picture)
        end
        drawCartInside(c.bike)
        c.drawCartInFront = true
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function s.draw()
    local c = check()
    -- the basket's side and the wheels in front of the Mipo: it sits in the basket
    if c.drawCartInFront and c.bike and alive(c.bike.frame) then
        c.drawCartInFront = nil
        drawCart(c.bike, c.mipo)
        if c.wheelImage then
            drawWheel(c.bike.back, c.wheelImage)
            drawWheel(c.bike.front, c.wheelImage)
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(1)
    end
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
    local c = state.soapboxSpike
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
    riderMuscles(c.mipo) -- every frame: waking from a daze turns them back to standing
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

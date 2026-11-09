-- rides: little vehicles Mipos get into and you drive: a kart, a tiny car, an electric skateboard (docs/RIDES.md)
-- A long street: kickers, bumps, dips, a hill at each end. Drop a Mipo on a vehicle and it gets
-- in (kart, car: sits, hips on a spring; skateboard: stands, feet held to the deck). Press a
-- vehicle to pick it up, the Mipo still in; carried, it's helped back upright, softly. Let go and
-- it keeps your push (it rolls on); pull it back along the ground and it winds up, let go and it
-- shoots off (a Darda). Tap it to drive: tap its front and it goes, tap again and it stops, tap
-- its back and it turns round. The rider faces the way it goes (src/mipo-facing.lua). Drag a
-- rider out to get off; a hard knock throws it off; one upside down falls out.
-- keys: r: another Mipo   c: the camera follows (on/off)   p: pause

local s = {}

local SCALE = 0.3
local LEFT, RIGHT = -24000, 24000
local FRICTION = 0.9
local N_MIPOS = 4

local function check() -- on state: a script hot reload keeps the street
    state.ridesSpike = state.ridesSpike or { vehicles = {}, mipos = {}, held = {}, camOn = true }
    return state.ridesSpike
end

local function alive(body) return body and not body:isDestroyed() end
local function liveMipo(inst) return inst and inst.parts and inst.parts.torso1 and alive(inst.parts.torso1.body) end

-- ─── Mipo helpers (as the soapbox's) ───

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

local function turnParts(inst, names, px, py, delta)
    local bodies = {}
    for _, name in ipairs(names) do
        if inst.parts[name] then bodies[#bodies + 1] = inst.parts[name].body end
    end
    turnBodies(bodies, px, py, delta)
end

local function allBodies(inst)
    local bodies = {}
    for _, part in pairs(inst.parts) do
        if alive(part.body) then bodies[#bodies + 1] = part.body end
    end
    return bodies
end

-- every solid shape's bounding box corners, in the frame's coordinates
local function localExtent(inst, frame)
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for _, b in ipairs(allBodies(inst)) do
        for _, fixture in ipairs(b:getFixtures()) do
            if not fixture:isSensor() then
                local ax, ay, bx, by = fixture:getBoundingBox()
                for _, p in ipairs({ { ax, ay }, { bx, ay }, { ax, by }, { bx, by } }) do
                    local lx, ly = frame:getLocalPoint(p[1], p[2])
                    x0, y0, x1, y1 = math.min(x0, lx), math.min(y0, ly), math.max(x1, lx), math.max(y1, ly)
                end
            end
        end
    end
    return x0, y0, x1, y1
end

local function mipoHeight(inst)
    local top, bottom = math.huge, -math.huge
    for _, b in ipairs(allBodies(inst)) do
        for _, fixture in ipairs(b:getFixtures()) do
            if not fixture:isSensor() then
                local _, y0, _, y1 = fixture:getBoundingBox()
                top, bottom = math.min(top, y0), math.max(bottom, y1)
            end
        end
    end
    return bottom - top
end

local function setAnkleLimits(inst, on)
    for _, foot in ipairs({ 'lfoot', 'rfoot' }) do
        local f = inst.parts[foot]
        for _, joint in ipairs(f and alive(f.body) and f.body:getJoints() or {}) do
            local _, b = joint:getBodies()
            if b == f.body and joint:getType() == 'revolute' then joint:setLimitsEnabled(on) end
        end
    end
end

-- ─── The street ───

-- The street's height at x (negative is up), in Mipo heights S. Flat in the middle where the
-- vehicles and Mipos start; out each way: a kicker (separate shapes), rolling bumps, a dip, then
-- a long hill up to the end wall. (Nikki 2026-11-09: "a longer terrain")
local function bell(x, x0, width, height)
    local t = (x - x0) / width
    if t <= 0 or t >= 1 then return 0 end
    return height * (0.5 - 0.5 * math.cos(t * math.pi * 2))
end

local function streetHeight(x, S)
    local y = 0
    y = y - bell(x, 4800, S * 3.5, S * 0.35) -- the hump
    for _, side in ipairs({ -1, 1 }) do
        local ax = x * side -- the same features both ways
        if ax > 11000 and ax < 16000 then -- rolling bumps
            y = y - S * 0.14 * (0.5 - 0.5 * math.cos((ax - 11000) / (S * 1.3) * math.pi * 2))
        end
        y = y + bell(ax, 17000, S * 6, S * 0.8) -- a dip
        if ax > 20000 then -- the long hill up to the wall
            local u = ax - 20000
            y = y - u * u / 4000 * 0.12
        end
    end
    return y
end

local function makeStreet(S)
    local c = check()
    if alive(c.ground) then return end
    c.ground = love.physics.newBody(world, 0, 0, 'static')
    local street = {}
    for x = LEFT, RIGHT, 40 do
        street[#street + 1] = x
        street[#street + 1] = streetHeight(x, S)
    end
    local wall = S * 3
    table.insert(street, 1, streetHeight(LEFT, S) - wall)
    table.insert(street, 1, LEFT)
    street[#street + 1] = RIGHT
    street[#street + 1] = streetHeight(RIGHT, S) - wall
    love.physics.newFixture(c.ground, love.physics.newChainShape(false, street)):setFriction(FRICTION)
    c.street = street
    -- kickers: up to the left and off left of the start, up to the right on the right
    local kl, kh = S * 2.2, S * 0.45
    c.kickers = {
        { -6500, 0, -6500 + kl, 0, -6500, -kh },
        { 8000, 0, 8000 + kl, 0, 8000 + kl, -kh },
    }
    for _, k in ipairs(c.kickers) do
        love.physics.newFixture(c.ground, love.physics.newPolygonShape(k)):setFriction(FRICTION)
    end
end

-- ─── Vehicles ───
-- Each: a frame and two wheels on fixed axles (motors in the axles drive it), built symmetric so
-- only the seat and the drawing turn round with v.dir. Sizes from S, a Mipo's standing height.

local KINDS = {}

local function addWheel(v, wx, r, group)
    local x, y = v.frame:getWorldPoint(wx, 0)
    local w = love.physics.newBody(world, x, y, 'dynamic')
    local f = love.physics.newFixture(w, love.physics.newCircleShape(r), 1)
    f:setFriction(1.2)
    local j = love.physics.newRevoluteJoint(v.frame, w, x, y, false)
    v.wheels[#v.wheels + 1] = { body = w, joint = j, r = r, x = wx, fixture = f }
    v.softToRider[#v.softToRider + 1] = f -- the rider never touches the wheels
    if group then f:setGroupIndex(group) end
end

local function board(v, x, y, w, h, softToRider)
    local f = love.physics.newFixture(v.frame, love.physics.newRectangleShape(x, y, w, h), 1)
    f:setFriction(FRICTION)
    if softToRider then v.softToRider[#v.softToRider + 1] = f end
    v.boards[#v.boards + 1] = { x, y, w, h }
    return f
end

-- the vehicle (wheels included) weighs `riders` of a rider of mass m: most in the frame
local function ballast(v, m, riders)
    local want = m * riders
    local shares = { [v.frame] = 0.8 }
    for _, w in ipairs(v.wheels) do shares[w.body] = 0.2 / #v.wheels end
    for body, share in pairs(shares) do
        local now = body:getMass()
        if now > 0 then
            local k = want * share / now
            for _, f in ipairs(body:getFixtures()) do f:setDensity(f:getDensity() * k) end
            body:resetMassData()
        end
    end
end

local function newVehicle(kind, x, S)
    local v = { kind = kind, S = S, dir = 1, wheels = {}, boards = {}, softToRider = {} }
    v.frame = love.physics.newBody(world, x, -S, 'dynamic')
    v.frame:setLinearDamping(0.15)
    KINDS[kind].build(v, S)
    -- on the street: the wheels' bottoms on the ground
    local dy = -(v.r) - v.frame:getY() - 2
    for _, b in ipairs({ v.frame, v.wheels[1].body, v.wheels[2].body }) do b:setY(b:getY() + dy) end
    return v
end

local function vehicleBodies(v)
    local list = { v.frame }
    for _, w in ipairs(v.wheels) do list[#list + 1] = w.body end
    return list
end

-- The kart: a low tray, sides a hand high, small fat wheels, legs stretched out to the front
-- (the soapbox pose).
KINDS.kart = {
    build = function(v, S)
        v.len, v.H, v.T, v.r = S * 1.0, S * 0.2, S * 0.05, S * 0.1
        v.floorY = -v.r * 0.2
        board(v, 0, v.floorY + v.T / 2, v.len, v.T)
        board(v, -v.len / 2 + v.T / 2, v.floorY - v.H / 2, v.T, v.H)
        board(v, v.len / 2 - v.T / 2, v.floorY - v.H / 2, v.T, v.H)
        addWheel(v, -v.len * 0.38, v.r)
        addWheel(v, v.len * 0.38, v.r)
        v.seatX = -v.len / 2 + v.T + S * 0.13 -- for dir 1: at the back
        -- whizzy (Nikki 2026-11-09: "an even wizzier gokart"; was 3.2 S/s, 0.35 g): low and long,
        -- it only tips back past ~1.9 g; a higher crash threshold so landings don't throw the driver
        v.topSpeed, v.accel, v.crash = S * 6.5, 0.7, 2.6 -- units a second; of g; S/s in a frame
        v.pose = 'legsOut'
        v.color, v.dark = { 0.86, 0.3, 0.22 }, { 0.55, 0.18, 0.14 }
    end,
}

-- The tiny car: open, no roof (Nikki 2026-11-09), on two wheels; the rider sits upright, shins
-- down, its body showing over the side.
KINDS.car = {
    build = function(v, S)
        v.len, v.H, v.T, v.r = S * 1.05, S * 0.32, S * 0.05, S * 0.13
        v.floorY = -v.r * 0.1
        board(v, 0, v.floorY + v.T / 2, v.len, v.T)
        board(v, -v.len / 2 + v.T / 2, v.floorY - v.H / 2, v.T, v.H)
        board(v, v.len / 2 - v.T / 2, v.floorY - v.H / 2, v.T, v.H)
        addWheel(v, -v.len * 0.33, v.r)
        addWheel(v, v.len * 0.33, v.r)
        v.seatX = -v.len * 0.12
        v.topSpeed, v.accel = S * 2.6, 0.3
        v.pose = 'carSeat'
        v.color, v.dark = { 0.45, 0.72, 0.82 }, { 0.26, 0.45, 0.55 }
    end,
}

-- The banana car (Nikki 2026-11-09: "a banana car", after Richard Scarry's Busytown): a long
-- banana on two little wheels, its ends curving up, brown tips, the stem at the front; the rider
-- sits in a hollow scooped out of its middle. Built as the car underneath.
KINDS.banana = {
    build = function(v, S)
        v.len, v.H, v.T, v.r = S * 1.3, S * 0.26, S * 0.05, S * 0.1
        v.floorY = -v.r * 0.3
        board(v, 0, v.floorY + v.T / 2, v.len * 0.8, v.T)
        board(v, -v.len * 0.4 + v.T / 2, v.floorY - v.H / 2, v.T, v.H)
        board(v, v.len * 0.4 - v.T / 2, v.floorY - v.H / 2, v.T, v.H)
        addWheel(v, -v.len * 0.27, v.r)
        addWheel(v, v.len * 0.27, v.r)
        v.seatX = -v.len * 0.08
        v.topSpeed, v.accel = S * 3, 0.35
        v.pose = 'carSeat'
        v.color, v.dark = { 0.98, 0.84, 0.24 }, { 0.8, 0.62, 0.14 }
    end,
}

-- The electric skateboard: a deck with kicktails, little wheels; the rider stands on it.
KINDS.skate = {
    build = function(v, S)
        v.len, v.T, v.r = S * 0.75, S * 0.045, S * 0.06
        v.floorY = -v.r * 1.4
        board(v, 0, v.floorY + v.T / 2, v.len * 0.8, v.T, true)
        addWheel(v, -v.len * 0.3, v.r)
        addWheel(v, v.len * 0.3, v.r)
        v.seatX = 0
        v.topSpeed, v.accel = S * 3.6, 0.22 -- gentle: a standing rider tips past ~0.4 g
        v.pose = 'stand'
        v.color, v.dark = { 0.95, 0.78, 0.25 }, { 0.3, 0.28, 0.32 }
    end,
}

-- ─── Getting in: the rider posed, placed and held ───

local SEAT_SPRING, SEAT_DAMPING = 5, 0.25
local RIDER_KP, RIDER_MAX_OMEGA = 8, 2
-- degrees for a rider facing right (mirrored facing left); 0 = hanging straight down
local POSES = {
    legsOut = { torso1 = 0, luleg = -82, ruleg = -82, llleg = -70, rlleg = -70, lfoot = -150, rfoot = -150 },
    carSeat = { torso1 = 0, luleg = -80, ruleg = -80, llleg = -5, rlleg = -5, lfoot = 0, rfoot = 0 },
}
local LEGS = { { 'luleg', 'llleg', 'lfoot' }, { 'ruleg', 'rlleg', 'rfoot' } }

local function riderMuscles(v)
    local pose = POSES[v.pose]
    if not pose then return end
    for name, angle in pairs(pose) do
        -- fixed angles in the world (the soapbox: aimed with the cart they made a loop, the cart
        -- tilts, the target with it, the body turns it further, and over it went)
        local target = angle * v.dir
        local keep = mipoActions.ensureKeepAngle(v.rider.parts[name], target, RIDER_KP)
        if keep then
            keep.angle, keep.enabled, keep.kp, keep.maxOmega = target, nil, RIDER_KP, RIDER_MAX_OMEGA
        end
    end
end

-- legs bent to the pose (or straight down along the frame, standing), turned at hip, knee, ankle
local function poseLegs(inst, v)
    local a = v.frame:getAngle()
    local pose = POSES[v.pose]
    for _, leg in ipairs(LEGS) do
        local u, l, f = leg[1], leg[2], leg[3]
        if inst.parts[u] and inst.parts[l] then
            local hx, hy = jointPoint(inst, 'torso1', u)
            local want = a + (pose and math.rad(pose[u] * v.dir) or 0)
            if hx then turnParts(inst, { u, l, f }, hx, hy, want - inst.parts[u].body:getAngle()) end
            local kx, ky = jointPoint(inst, u, l)
            want = a + (pose and math.rad(pose[l] * v.dir) or 0)
            if kx then turnParts(inst, { l, f }, kx, ky, want - inst.parts[l].body:getAngle()) end
            local ax, ay = jointPoint(inst, l, f)
            want = a + (pose and math.rad(pose[f] * v.dir) or 0)
            if ax and inst.parts[f] then turnParts(inst, { f }, ax, ay, want - inst.parts[f].body:getAngle()) end
        end
    end
end

local function unseat(v, fling)
    local inst = v.rider
    for _, j in ipairs(v.joints or {}) do
        if not j:isDestroyed() then j:destroy() end
    end
    v.joints, v.rider = nil, nil
    for _, f in ipairs(v.softToRider) do
        if not f:isDestroyed() then f:setGroupIndex(0) end
    end
    if not liveMipo(inst) then return end
    inst._ride = nil
    setAnkleLimits(inst, true)
    mipoActions.wake(inst) -- standing muscles again
    if fling then
        local vx, vy = fling[1], fling[2]
        for _, b in ipairs(allBodies(inst)) do b:setLinearVelocity(vx * 0.9, vy * 0.9 - v.S * 1.5) end
        mipoVoice.squeak(inst, 'pickup')
    end
end

local function seat(v, inst)
    local frame = v.frame
    mipoActions.wake(inst)
    local side = v.dir > 0 and 'right' or 'left'
    if mipoFacing.get(inst) ~= side then characterManager.switchFacing(inst, side) end
    -- upright with the vehicle, legs posed
    local tx, ty = inst.parts.torso1.body:getPosition()
    turnBodies(allBodies(inst), tx, ty, frame:getAngle() - inst.parts.torso1.body:getAngle())
    poseLegs(inst, v)
    -- hips over the seat, the lowest point just above the floor
    local hx, hy = jointPoint(inst, 'torso1', 'luleg')
    local hlx = frame:getLocalPoint(hx, hy)
    local _, _, _, lowest = localExtent(inst, frame)
    local dx, dy = frame:getWorldVector(v.seatX * v.dir - hlx, v.floorY - 3 - lowest)
    local vx, vy = frame:getLinearVelocity()
    for _, b in ipairs(allBodies(inst)) do
        local x, y = b:getPosition()
        b:setPosition(x + dx, y + dy)
        b:setLinearVelocity(vx, vy)
        b:setAngularVelocity(0)
    end
    for _, f in ipairs(v.softToRider) do f:setGroupIndex(inst.groupIndex or 0) end
    v.rider, v.joints = inst, {}
    inst._ride = v
    if v.pose == 'stand' then
        -- feet held to the deck; standing muscles keep the rest upright
        for _, name in ipairs({ 'lfoot', 'rfoot' }) do
            local foot = inst.parts[name]
            if foot and alive(foot.body) then
                local fx, fy = foot.body:getPosition()
                v.joints[#v.joints + 1] = love.physics.newWeldJoint(frame, foot.body, fx, fy, false)
            end
        end
    else
        setAnkleLimits(inst, false)
        hx, hy = jointPoint(inst, 'torso1', 'luleg')
        local ax, ay = frame:getWorldVector(0, 1)
        local j = love.physics.newWheelJoint(frame, inst.parts.torso1.body, hx, hy, ax, ay, false)
        j:setSpringFrequency(SEAT_SPRING)
        j:setSpringDampingRatio(SEAT_DAMPING)
        v.joints[1] = j
        riderMuscles(v)
    end
end

-- facing the other way: the rider off, the vehicle's front swapped, the rider on again
local function turnAround(v)
    local inst = v.rider
    if inst then
        for _, j in ipairs(v.joints or {}) do
            if not j:isDestroyed() then j:destroy() end
        end
        v.joints = nil
    end
    v.dir = -v.dir
    if liveMipo(inst) then seat(v, inst) end
end

-- the spot a dropped Mipo gets in from: over the vehicle, not far above
local function inReach(v, x, y)
    local lx, ly = v.frame:getLocalPoint(x, y)
    return math.abs(lx) < v.len / 2 + v.S * 0.15 and ly > -v.S * 1.4 and ly < v.S * 0.2
end

-- ─── Driving ───

local function pointerDown(id)
    if id == 'test' then return check().testHold end -- a pretend finger over the bridge (s.test)
    if id == 'mouse' then return love.mouse.isDown(1) end
    for _, t in ipairs(love.touch.getTouches()) do
        if t == id then return true end
    end
    return false
end

local function screenPosition(id)
    if id == 'test' then return 0, 0 end
    if id == 'mouse' then return love.mouse.getPosition() end
    return love.touch.getPosition(id)
end

local function pointerPosition(id)
    return cam:getWorldCoordinates(screenPosition(id))
end

local function totalMass(v)
    local m = 0
    for _, b in ipairs(vehicleBodies(v)) do m = m + b:getMass() end
    if liveMipo(v.rider) then m = m + mipoRegistry.totalMass(v.rider) end
    return m
end

-- speed, accel: a wound spring's instead of the motor's (the wind-up, below)
local function setMotors(v, driving, speed, accel)
    local _, g = world:getGravity()
    local m = totalMass(v)
    for _, w in ipairs(v.wheels) do
        local j = w.joint
        if not j:isDestroyed() then
            j:setMotorEnabled(true)
            if driving then
                j:setMotorSpeed(v.dir * (speed or v.topSpeed) / w.r)
                j:setMaxMotorTorque(m * g * (accel or v.accel) * w.r / #v.wheels)
            else
                -- coasting: a little rolling drag
                j:setMotorSpeed(0)
                j:setMaxMotorTorque(m * g * 0.03 * w.r / #v.wheels)
            end
        end
    end
end

-- A press on a vehicle picks it up, by its frame (a wheel pressed: the frame taken at that
-- spot), the rider still in. Carried, a soft spring turns it back toward upright (UPRIGHT_*:
-- just enough; held by one end it still hangs ~35 degrees). A tap (short, hardly moved) drives
-- instead: on the side it's going, it stops; when stopped, it goes toward the side tapped; on the
-- other side, it turns round and goes. (After physics-testbed's downhill, which only dragged the
-- frame, and kicked the bike back over when it landed upside down.)
local PICK_PX = 14        -- moved further than this, a press is a carry, not a tap
local TAP_TIME = 0.25     -- seconds
local UPRIGHT_KP = 2.0    -- the righting spring, per S^2 of the whole weight (rider included)
local UPRIGHT_KD = 1.8    -- its damping: no swinging on and on (1.1: a flick spun it past upside down)
local UPRIGHT_MAX = 3.0   -- at most (held by an end with more, it can't be turned past this)

-- The grab zone: the vehicle's thin boards, deck and small wheels were hard to hit (Nikki
-- 2026-11-09), so a press in a generous box round it takes the vehicle, the rider's legs inside
-- it too. Above the rim a press still takes the rider (to drag it out); an empty vehicle's zone
-- reaches up over its seat. (A sensor fixture wouldn't do: the pointer never grabs sensors.)
local function inGrabZone(v, wx, wy)
    local lx, ly = v.frame:getLocalPoint(wx, wy)
    local S = v.S
    local top
    if v.pose == 'stand' then
        top = v.floorY - (v.rider and S * 0.12 or S * 0.35)
    else
        top = v.floorY - (v.H or 0) - (v.rider and S * 0.04 or S * 0.35)
    end
    return math.abs(lx) < v.len / 2 + S * 0.12 and ly > top and ly < v.r + S * 0.1
end

local function newPresses(c)
    local presses = {}
    local down = love.mouse.isDown(1)
    if down and not c.mouseWasDown then presses[#presses + 1] = 'mouse' end
    c.mouseWasDown = down
    local seen = {}
    for _, id in ipairs(love.touch.getTouches()) do
        seen[id] = true
        if not (c.touchesSeen and c.touchesSeen[id]) then presses[#presses + 1] = id end
    end
    c.touchesSeen = seen
    return presses
end

local function grabZones(c)
    for _, id in ipairs(newPresses(c)) do
        local wx, wy = pointerPosition(id)
        for _, v in ipairs(c.vehicles) do
            if inGrabZone(v, wx, wy) then
                pointerGrab(id, v.frame, wx, wy)
                break
            end
        end
    end
end

local function takePresses(c)
    for _, v in ipairs(c.vehicles) do
        for _, b in ipairs(vehicleBodies(v)) do
            local pj = getPJAttachedTo(b)
            if pj and pj.id ~= v.carryId then
                local px, py = pointerPosition(pj.id)
                if b ~= v.frame then pointerGrab(pj.id, v.frame, px, py) end
                local sx, sy = screenPosition(pj.id)
                local lx = v.frame:getLocalPoint(px, py)
                v.carryId, v.press = pj.id, { sx = sx, sy = sy, lx = lx, t = 0, moved = false }
                v.wind, v.trail = 0, nil
                -- follows the finger without overshoot (0.5, the usual, sprang past it and back)
                local held = getPJAttachedTo(v.frame)
                if held and held.joint then held.joint:setDampingRatio(1) end
                c.following = v
            end
        end
    end
end

-- ─── Let go: pushed (it rolls on) or wound up (it shoots off) ───
-- Nikki 2026-11-09: "pick up and position the cart, or push it along, give it some momentum,
-- see it roll; or the Darda way, where a kid pulls the vehicle down and back and it shoots out".
-- Let go, it keeps the finger's speed over the last moment (MOMENTUM_WINDOW; the body's own
-- speed jumps about under the drag), capped. Dragged backwards with its wheels on the ground,
-- it winds up (the back wheel's backward roll; forward doesn't unwind, a ratchet); let go wound,
-- it starts from rest and its spring drives it forward: faster the further it was pulled back,
-- and for WIND_RUN times as far. The key on its back turns as it winds and unwinds.
local MOMENTUM_WINDOW = 0.1  -- seconds of finger movement the release speed is taken from
local MOMENTUM_MAX = 7       -- S a second at most
local WIND_MIN = 0.25        -- S of pulling back before it counts as wound
local WIND_MAX = 3           -- S
local WIND_RUN = 5           -- it runs this many times the pull-back
local WIND_SPEED = 3.5       -- S a second per S wound (2 S wound: 7 S a second)
local WIND_ACCEL = 1.1       -- g: the spring's snap
local WIND_NEEDS_RIDER = true -- as driving: only with a Mipo in (Nikki: an empty one just sits)

local function onGround(v)
    local ground = check().ground
    for _, w in ipairs(v.wheels) do
        for _, contact in ipairs(w.body:getContacts()) do
            if contact:isTouching() then
                local fa, fb = contact:getFixtures()
                if fa:getBody() == ground or fb:getBody() == ground then return true end
            end
        end
    end
    return false
end

-- every frame: how far the back wheel rolled forward (negative: backward), in world units
local function rolled(v)
    local w = v.wheels[1]
    local a = w.body:getAngle()
    local d = a - (v.lastWheelAngle or a)
    v.lastWheelAngle = a
    return d * w.r * v.dir
end

local function setVelocity(v, vx, vy)
    local bodies = vehicleBodies(v)
    if liveMipo(v.rider) then
        for _, b in ipairs(allBodies(v.rider)) do bodies[#bodies + 1] = b end
    end
    for _, b in ipairs(bodies) do
        b:setLinearVelocity(vx, vy)
        b:setAngularVelocity(0)
    end
end

local function letGo(v)
    local wound = v.wind and v.wind > WIND_MIN * v.S and (v.rider or not WIND_NEEDS_RIDER)
    if wound then
        setVelocity(v, 0, 0)
        v.spring = math.min(v.wind, WIND_MAX * v.S) * WIND_RUN
        v.springSpeed = math.min(v.wind, WIND_MAX * v.S) * WIND_SPEED
        v.going = false
    else
        -- the finger's speed over the last moment
        local trail = v.trail or {}
        local vx, vy = 0, 0
        if #trail >= 2 then
            local a, b = trail[1], trail[#trail]
            local dt = b[1] - a[1]
            if dt > 0.01 then vx, vy = (b[2] - a[2]) / dt, (b[3] - a[3]) / dt end
        end
        local speed = math.sqrt(vx * vx + vy * vy)
        local max = MOMENTUM_MAX * v.S
        if speed > max then vx, vy = vx / speed * max, vy / speed * max end
        setVelocity(v, vx, vy)
    end
    v.wind, v.trail = 0, nil
    v.settle = 0.6
end

local function tapped(v, lx)
    if v.spring and v.spring > 0 then v.spring = 0 return end -- caught: the spring let go
    if not v.rider then return end -- only a Mipo drives (Nikki 2026-11-09): an empty one just sits
    local side = lx >= 0 and 1 or -1
    if v.going and side == v.dir then
        v.going = false
    else
        if side ~= v.dir then turnAround(v) end
        v.going = true
    end
end

local function keepUpright(v, dt)
    local err = (v.frame:getAngle() + math.pi) % (2 * math.pi) - math.pi
    local w = v.frame:getAngularVelocity()
    local k = totalMass(v) * v.S * v.S
    local torque = -(UPRIGHT_KP * err + UPRIGHT_KD * w)
    torque = math.max(-UPRIGHT_MAX, math.min(UPRIGHT_MAX, torque))
    v.frame:applyTorque(torque * k)
end

local function drive(v, dt)
    local forward = rolled(v)
    if v.carryId then
        -- the finger's path for the release speed; winding while pulled back along the ground
        if v.carryId ~= 'test' and pointerDown(v.carryId) then
            local now = love.timer.getTime()
            local px, py = pointerPosition(v.carryId)
            v.trail = v.trail or {}
            v.trail[#v.trail + 1] = { now, px, py }
            while #v.trail > 2 and now - v.trail[1][1] > MOMENTUM_WINDOW do table.remove(v.trail, 1) end
        end
        if forward < 0 and onGround(v) then
            v.wind = math.min((v.wind or 0) - forward, WIND_MAX * v.S)
            v.keyAngle = (v.keyAngle or 0) - forward / v.S * 4
        end
        local press = v.press
        if press then
            press.t = press.t + dt
            if pointerDown(v.carryId) then
                local sx, sy = screenPosition(v.carryId)
                if (sx - press.sx) ^ 2 + (sy - press.sy) ^ 2 > PICK_PX * PICK_PX then press.moved = true end
            end
        end
        if not (pointerDown(v.carryId) and (v.carryId == 'test' or getPJAttachedTo(v.frame))) then
            -- let go: a tap drives, a carry is set down (a bump isn't a crash)
            if press and not press.moved and press.t < TAP_TIME then
                tapped(v, press.lx)
            else
                letGo(v)
            end
            v.carryId, v.press = nil, nil
        elseif press and (press.moved or press.t >= TAP_TIME) then
            keepUpright(v, dt)
        end
    end
    if not v.rider then v.going = false end -- the driver got out (or fell out): it rolls to a stop
    if v.spring and v.spring > 0 and not v.carryId then
        -- the spring unwinds as it rolls forward; slowing over its last stretch
        v.spring = v.spring - math.max(0, forward)
        v.keyAngle = (v.keyAngle or 0) + math.max(0, forward) / v.S * 4 / WIND_RUN
        if WIND_NEEDS_RIDER and not v.rider then v.spring = 0 end
        local fade = math.min(1, v.spring / (v.S * 1.5))
        setMotors(v, v.spring > 0, v.springSpeed * (0.3 + 0.7 * fade), WIND_ACCEL)
    else
        if v.carryId then v.spring = 0 end
        setMotors(v, v.going and not v.carryId)
    end
end

-- ─── Getting in, getting off, falling out ───

local CRASH = 1.6      -- a change of speed this many S a second in one frame throws the rider off
local UPSIDE = 1.7     -- radians off upright: the rider falls out after a moment

local function heldMipos()
    local held = {}
    for _, b in ipairs(getInteractedWithPointer()) do
        local inst = mipoRegistry.getFromBody(b)
        if inst then held[inst] = true end
    end
    return held
end

local function freeVehicleUnder(c, inst)
    local x, y = inst.parts.torso1.body:getPosition()
    for _, v in ipairs(c.vehicles) do
        if not v.rider and inReach(v, x, y) then return v end
    end
end

local function updateRiders(c, dt)
    local held = heldMipos()
    -- dropped on a free vehicle: in
    for inst in pairs(c.held) do
        if not held[inst] and liveMipo(inst) and not inst._ride then
            local v = freeVehicleUnder(c, inst)
            if v then
                seat(v, inst)
                mipoVoice.squeak(inst, 'pickup')
            end
        end
    end
    c.held = held
    for _, v in ipairs(c.vehicles) do
        local inst = v.rider
        if inst and not liveMipo(inst) then
            unseat(v)
        elseif inst then
            local vx, vy = v.frame:getLinearVelocity()
            local pv = v.lastV or { vx, vy }
            local dv = math.sqrt((vx - pv[1]) ^ 2 + (vy - pv[2]) ^ 2)
            local up = math.abs((v.frame:getAngle() + math.pi) % (2 * math.pi) - math.pi)
            v.upsideFor = up > UPSIDE and (v.upsideFor or 0) + dt or 0
            local tx, ty = inst.parts.torso1.body:getPosition()
            if held[inst] and not inReach(v, tx, ty) then
                unseat(v) -- dragged out
            elseif dv > (v.crash or CRASH) * v.S and dt > 0 and not v.carryId and (v.settle or 0) <= 0 then
                unseat(v, pv) -- thrown off, at the speed it had
            elseif v.upsideFor > 0.6 and not v.carryId then -- carried, the Mipo stays in
                unseat(v)
            elseif v.pose == 'stand' and mipoActions.isDazed(inst) then
                unseat(v)
            elseif v.pose ~= 'stand' then
                riderMuscles(v) -- every frame: a daze turns them back to standing
            end
            v.lastV = { vx, vy }
        end
        v.settle = math.max(0, (v.settle or 0) - dt)
        if not v.rider then
            v.lastV = nil
            -- an empty one on its back or side rights itself after a while
            local up = math.abs((v.frame:getAngle() + math.pi) % (2 * math.pi) - math.pi)
            v.overFor = up > 1.2 and (v.overFor or 0) + dt or 0
            if v.overFor > 2 then
                v.overFor = 0
                local fx, fy = v.frame:getPosition()
                turnBodies(vehicleBodies(v), fx, fy - v.S * 0.5, -v.frame:getAngle())
                for _, b in ipairs(vehicleBodies(v)) do
                    b:setY(b:getY() - v.S * 0.5)
                    b:setLinearVelocity(0, 0)
                    b:setAngularVelocity(0)
                end
            end
        end
    end
end

-- ─── Making and clearing the scene ───

local function newMipo(x)
    local c = check()
    local inst = characterManager.createCharacter('humanoid', x, -(c.S or 900) * 1.6, SCALE)
    if not inst then return end
    characterManager.randomizeMipo(inst)
    c.mipos[#c.mipos + 1] = inst
    return inst
end

local function clearAll()
    local c = state.ridesSpike
    if not c then return end
    for _, v in ipairs(c.vehicles or {}) do
        if v.rider then unseat(v) end
        for _, b in ipairs(vehicleBodies(v)) do
            if alive(b) then b:destroy() end
        end
    end
    c.vehicles = {}
    for _, inst in ipairs(c.mipos or {}) do
        if liveMipo(inst) then characterManager.removeCharacter(inst) end
    end
    c.mipos, c.held = {}, {}
    if alive(c.ground) then c.ground:destroy() end
    c.ground, c.following, c.streetMesh = nil, nil, nil
end

local function build()
    local c = check()
    local first = newMipo(-1200)
    c.S = first and mipoHeight(first) or 900
    local S = c.S
    makeStreet(S)
    for i, x in ipairs({ 1200, -1200 - S * 0.6, 1200 + S * 0.6 }) do -- in pairs between the vehicles, out of their runs
        if i <= N_MIPOS - 1 then newMipo(x) end
    end
    local refMass = first and mipoRegistry.totalMass(first) or 3
    local kart = newVehicle('kart', -2400, S)
    ballast(kart, refMass, 2)
    local car = newVehicle('car', 0, S)
    local banana = newVehicle('banana', 3700, S)
    ballast(banana, refMass, 2)
    ballast(car, refMass, 2.5)
    local skate = newVehicle('skate', 2400, S)
    ballast(skate, refMass, 0.6)
    c.vehicles = { kart, car, skate, banana }
end

-- ─── Drawing ───

local INK = { 0.12, 0.1, 0.1 }

local function inFrame(v, fn)
    local x, y = v.frame:getPosition()
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(v.frame:getAngle())
    love.graphics.scale(v.dir, 1) -- drawn facing right; mirrored facing left
    fn()
    love.graphics.pop()
end

local function drawWheel(w, S)
    local x, y = w.body:getPosition()
    local a = w.body:getAngle()
    local r = w.r
    love.graphics.setColor(0.18, 0.16, 0.16)
    love.graphics.circle('fill', x, y, r)
    love.graphics.setColor(0.75, 0.72, 0.68)
    love.graphics.circle('fill', x, y, r * 0.5)
    love.graphics.setColor(INK)
    love.graphics.setLineWidth(math.max(2, S * 0.008))
    love.graphics.circle('line', x, y, r)
    love.graphics.circle('line', x, y, r * 0.5)
    for i = 0, 2 do
        local t = a + i * math.pi * 2 / 3
        love.graphics.line(x, y, x + math.cos(t) * r * 0.5, y + math.sin(t) * r * 0.5)
    end
end

-- behind the rider
-- The banana's outline in its own coordinates (drawn facing right), made once: a crescent whose
-- ends curve up, thick in the middle and tapering; `hollow` scoops the seat out of its top.
local BANANA_TIP = { 0.36, 0.25, 0.12 }
local function bananaShape(v, hollow)
    local key = hollow and 'bananaFront' or 'bananaBack'
    if v[key] then return v[key] end
    local S, L = v.S, v.len * 0.56
    local N = 28
    local top, bottom = {}, {}
    for i = 0, N do
        local u = i / N * 2 - 1
        local x = u * L
        local cy = v.floorY - v.H * 0.35 - S * 0.32 * u * u          -- the ends curve up
        local th = v.H * 1.25 * math.sqrt(math.max(0, 1 - u * u)) + S * 0.025
        local ty = cy - th / 2
        if hollow then
            local k = math.cos(math.min(1, math.abs(u) / 0.62) * math.pi / 2)
            ty = ty + th * 0.45 * k * k
        end
        top[#top + 1] = { x, ty }
        bottom[#bottom + 1] = { x, cy + th / 2 }
    end
    local pts = {}
    for i = 1, #top do pts[#pts + 1], pts[#pts + 2] = top[i][1], top[i][2] end
    for i = #bottom, 1, -1 do pts[#pts + 1], pts[#pts + 2] = bottom[i][1], bottom[i][2] end
    -- a ridge along its side, a little below the top
    local ridge = {}
    for i = 3, N - 1 do
        local u = (i / N) * 2 - 1
        local cy = v.floorY - v.H * 0.35 - S * 0.32 * u * u
        local th = v.H * 1.25 * math.sqrt(math.max(0, 1 - u * u)) + S * 0.025
        ridge[#ridge + 1] = u * L
        ridge[#ridge + 1] = cy + th * 0.18
    end
    local ok, tris = pcall(love.math.triangulate, pts)
    v[key] = { pts = pts, tris = ok and tris or {}, ridge = ridge, L = L,
        backTip = { -L, v.floorY - v.H * 0.35 - S * 0.32 }, frontTip = { L, v.floorY - v.H * 0.35 - S * 0.32 } }
    return v[key]
end

local function drawBanana(v, hollow)
    local b = bananaShape(v, hollow)
    local S = v.S
    if hollow then love.graphics.setColor(v.color) else love.graphics.setColor(0.96, 0.92, 0.72) end
    for _, tri in ipairs(b.tris) do love.graphics.polygon('fill', tri) end
    if hollow then
        love.graphics.setColor(v.dark)
        love.graphics.setLineWidth(math.max(2, S * 0.008))
        love.graphics.line(b.ridge)
    end
    -- the tips: brown at the back, the stem at the front
    love.graphics.setColor(BANANA_TIP)
    love.graphics.circle('fill', b.backTip[1] + S * 0.01, b.backTip[2] + S * 0.005, S * 0.028)
    local fx, fy = b.frontTip[1], b.frontTip[2]
    love.graphics.polygon('fill', fx - S * 0.03, fy + S * 0.02, fx + S * 0.07, fy - S * 0.06,
        fx + S * 0.1, fy - S * 0.03, fx + S * 0.01, fy + S * 0.04)
    love.graphics.setColor(INK)
    love.graphics.setLineWidth(math.max(3, S * 0.01))
    love.graphics.polygon('line', b.pts)
end

local function drawBehind(v)
    local S, line = v.S, math.max(3, v.S * 0.01)
    love.graphics.setLineWidth(line)
    if v.kind == 'kart' then
        inFrame(v, function()
            love.graphics.setColor(v.dark)
            love.graphics.polygon('fill', -v.len / 2, v.floorY - v.H, v.len / 2, v.floorY - v.H,
                v.len / 2, v.floorY, -v.len / 2, v.floorY)
            -- the seat back
            local sx = v.seatX - S * 0.12
            love.graphics.setColor(0.25, 0.22, 0.22)
            love.graphics.rectangle('fill', sx - S * 0.05, v.floorY - S * 0.38, S * 0.1, S * 0.38, S * 0.04)
        end)
    elseif v.kind == 'car' then
        inFrame(v, function()
            -- the seat
            local sx = v.seatX - S * 0.14
            love.graphics.setColor(0.9, 0.85, 0.75)
            love.graphics.rectangle('fill', sx - S * 0.06, v.floorY - S * 0.55, S * 0.12, S * 0.55, S * 0.05)
        end)
    elseif v.kind == 'banana' then
        inFrame(v, function() drawBanana(v, false) end) -- the far side and the inside, peeled pale
    elseif v.kind == 'skate' then
        inFrame(v, function()
            local L, y, T = v.len / 2, v.floorY, v.T
            -- deck with kicked-up tails
            local pts = { -L, y - T * 2.2, -L * 0.8, y, L * 0.8, y, L, y - T * 2.2,
                L * 0.98, y - T * 1.2, L * 0.78, y + T, -L * 0.78, y + T, -L * 0.98, y - T * 1.2 }
            love.graphics.setColor(v.color)
            for _, tri in ipairs(love.math.triangulate(pts)) do love.graphics.polygon('fill', tri) end
            love.graphics.setColor(INK)
            love.graphics.polygon('line', pts)
            -- the battery under the deck, a light at the front
            love.graphics.setColor(v.dark)
            love.graphics.rectangle('fill', -L * 0.4, y + T, L * 0.8, T * 1.3, T * 0.4)
            local on = v.going and 1 or 0.35
            love.graphics.setColor(0.4, 1, 0.6, on)
            love.graphics.circle('fill', L * 0.32, y + T * 1.65, T * 0.35)
        end)
        for _, w in ipairs(v.wheels) do drawWheel(w, S) end
    end
end

-- in front of the rider
local function drawFront(v)
    local S, line = v.S, math.max(3, v.S * 0.01)
    love.graphics.setLineWidth(line)
    if v.kind == 'kart' then
        inFrame(v, function()
            local L, y = v.len / 2, v.floorY
            local side = { -L, y - v.H, L * 0.7, y - v.H * 0.8, L, y - v.H * 0.3, L, y + v.T, -L, y + v.T }
            love.graphics.setColor(v.color)
            love.graphics.polygon('fill', side)
            love.graphics.setColor(INK)
            love.graphics.polygon('line', side)
            -- a number on the side
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle('fill', -L * 0.1, y - v.H * 0.45, v.H * 0.32)
            love.graphics.setColor(INK)
            love.graphics.circle('line', -L * 0.1, y - v.H * 0.45, v.H * 0.32)
            -- the steering wheel on its column
            local cx, cy = L * 0.55, y - v.H * 0.8
            local wx, wy = L * 0.35, y - S * 0.42
            love.graphics.setColor(0.25, 0.25, 0.27)
            love.graphics.line(cx, cy, wx, wy)
            love.graphics.setLineWidth(line * 1.8)
            love.graphics.ellipse('line', wx, wy, S * 0.03, S * 0.1)
        end)
        for _, w in ipairs(v.wheels) do drawWheel(w, S) end
    elseif v.kind == 'car' then
        inFrame(v, function()
            local L, y = v.len / 2, v.floorY
            local belt = y - v.H -- the window's bottom edge
            -- the lower body, rounded at both ends
            local body = {}
            for i = 0, 12 do
                local t = -math.pi / 2 + i / 12 * math.pi -- the front, top to bottom
                body[#body + 1] = L + math.cos(t) * S * 0.06
                body[#body + 1] = (belt + y) / 2 + math.sin(t) * (y - belt + v.T * 2) / 2
            end
            for i = 0, 12 do
                local t = math.pi / 2 + i / 12 * math.pi -- the back, bottom to top
                body[#body + 1] = -L + math.cos(t) * S * 0.06
                body[#body + 1] = (belt + y) / 2 + math.sin(t) * (y - belt + v.T * 2) / 2
            end
            love.graphics.setColor(v.color)
            love.graphics.polygon('fill', body)
            love.graphics.setColor(INK)
            love.graphics.polygon('line', body)
            -- a headlight
            love.graphics.setColor(1, 0.95, 0.7, v.going and 1 or 0.6)
            love.graphics.circle('fill', L * 0.98, (belt + y) / 2, S * 0.035)
            love.graphics.setColor(INK)
            love.graphics.circle('line', L * 0.98, (belt + y) / 2, S * 0.035)
        end)
        for _, w in ipairs(v.wheels) do drawWheel(w, S) end
    elseif v.kind == 'banana' then
        for _, w in ipairs(v.wheels) do drawWheel(w, S) end
        inFrame(v, function() drawBanana(v, true) end)
    end
end

-- the road: a strip under the street's line, made once; dashes along it
local function streetMesh(c)
    if c.streetMesh then return c.streetMesh end
    local verts = {}
    local pts = c.street
    for i = 3, #pts - 2, 2 do -- the walls' tops left out
        local x, y = pts[i], pts[i + 1]
        verts[#verts + 1] = { x, y, 0, 0, 0.42, 0.4, 0.38, 1 }
        verts[#verts + 1] = { x, y + 900, 0, 0, 0.32, 0.3, 0.28, 1 }
    end
    c.streetMesh = love.graphics.newMesh(verts, 'strip', 'static')
    return c.streetMesh
end

-- the wind-up key on the vehicle's back, turning (seen from the side: its bow narrows and widens)
local function drawKey(v)
    inFrame(v, function()
        local S = v.S
        local x = -v.len / 2 - (v.pose == 'stand' and 0 or v.T * 0.5)
        local y = v.pose == 'stand' and v.floorY - v.T * 2 or v.floorY - (v.H or 0) * 0.5
        if v.kind == 'banana' then x, y = -v.len * 0.44, v.floorY - v.H * 0.15 end -- on its peel
        local reach = S * 0.07
        love.graphics.setColor(INK)
        love.graphics.setLineWidth(math.max(3, S * 0.012))
        love.graphics.line(x, y, x - reach, y)
        local w = math.abs(math.cos(v.keyAngle or 0))
        local bx = x - reach - S * 0.035
        love.graphics.setColor(0.85, 0.7, 0.3)
        love.graphics.ellipse('fill', bx, y - S * 0.035, S * 0.03 * w + 2, S * 0.035)
        love.graphics.ellipse('fill', bx, y + S * 0.035, S * 0.03 * w + 2, S * 0.035)
        love.graphics.setColor(INK)
        love.graphics.ellipse('line', bx, y - S * 0.035, S * 0.03 * w + 2, S * 0.035)
        love.graphics.ellipse('line', bx, y + S * 0.035, S * 0.03 * w + 2, S * 0.035)
    end)
end

local function drawStreet(c)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(streetMesh(c))
    love.graphics.setColor(0.95, 0.9, 0.6, 0.8)
    local S = c.S or 900
    for x = LEFT + 200, RIGHT - 400, 700 do
        local y = streetHeight(x, S)
        local y2 = streetHeight(x + 300, S)
        love.graphics.polygon('fill', x, y + 120, x + 300, y2 + 120, x + 300, y2 + 142, x, y + 142)
    end
    love.graphics.setColor(0.55, 0.5, 0.45)
    for _, k in ipairs(c.kickers) do love.graphics.polygon('fill', k) end
    love.graphics.setColor(INK)
    love.graphics.setLineWidth(8)
    love.graphics.line(c.street)
    for _, k in ipairs(c.kickers) do love.graphics.polygon('line', k) end
end

function s.drawBelow()
    local c = check()
    if state.playMode then
        c.savedDrawBodies = state.world.debugDrawBodies
        state.world.debugDrawBodies = false
    end
    if alive(c.ground) then drawStreet(c) end
    for _, v in ipairs(c.vehicles) do
        if alive(v.frame) then drawBehind(v) end
    end
    c.drawFront = true
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function s.draw()
    local c = check()
    if c.drawFront then
        c.drawFront = nil
        for _, v in ipairs(c.vehicles) do
            if alive(v.frame) then
                drawFront(v)
                drawKey(v)
            end
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
    local c = check()
    if not (c.vehicles[1] and alive(c.vehicles[1].frame)) then
        clearAll()
        build()
        cam:setScale(0.25)
        cam:setTranslation(0, -500)
    end
end

function s.onUnload()
    clearAll()
    state.ridesSpike = nil
end

function s.update()
    local c = check()
    if not (c.vehicles[1] and alive(c.vehicles[1].frame)) then return end
    local dt = math.min(love.timer.getDelta(), 0.05)
    grabZones(c)
    takePresses(c)
    for _, v in ipairs(c.vehicles) do drive(v, dt) end
    updateRiders(c, dt)
    -- the camera rides along with the last vehicle driven, while it's driven or still rolling;
    -- never while a finger holds anything: the finger stays put on the screen, so a moving camera
    -- moved the drag's target, the vehicle followed it, the camera followed the vehicle (leading
    -- by its speed) and it shot off (Nikki 2026-11-09: "cars just shoot away")
    local v = c.following
    local holding = love.mouse.isDown(1) or #love.touch.getTouches() > 0
    if c.camOn and v and alive(v.frame) and not holding then
        local vx = v.frame:getLinearVelocity()
        if v.going or math.abs(vx) > 60 then
            local fx, fy = v.frame:getPosition()
            local tx, ty = cam:getTranslation()
            cam:setTranslation(tx + (fx + vx * 0.4 - tx) * 0.06, ty + (fy - v.S * 0.6 - ty) * 0.06)
        end
    end
end

-- for trying it over the bridge: state.scene.sceneScript.test.seat(1, mipo); .drive(1, dir) / (1)
s.test = {
    seat = function(i, inst) local v = check().vehicles[i]; if v.rider then unseat(v) end seat(v, inst) end,
    unseat = function(i) unseat(check().vehicles[i]) end,
    drive = function(i, dir)
        local v = check().vehicles[i]
        if dir and dir ~= v.dir then turnAround(v) end
        v.going = dir ~= nil
        check().following = v
    end,
}

function s.onKeyPress(key)
    local c = check()
    if key == 'r' then
        local tx = cam:getTranslation()
        newMipo(tx)
    end
    if key == 'c' then c.camOn = not c.camOn end
    if key == 'p' then worldState.paused = not worldState.paused end
end

return s

-- vehicle-rides.lua — Mipos in vehicles, and driving them (docs/KINDS.md KD4c, out of the rides spike,
-- docs/RIDES.md). An engine system (src/systems.lua), for the vehicle kind's instances (src/vehicles.lua):
--   getting in: a Mipo let go over a free vehicle gets in (kart: legs out; car, banana: sitting, hips on a
--     spring; skateboard: standing, feet held to the deck), facing the way it drives;
--   getting off: dragged out, thrown off by a hard knock (a change of speed in a frame), falling out after
--     a while upside down, a dazed skater falling off;
--   driving: in play mode a tap on a vehicle with a Mipo in it drives it (stopped: toward the side tapped;
--     going: its front stops it, its back turns it round); the panel's actions do the same in the editor.
--     Motors in the wheel joints, torque from the whole weight (rider in) times an acceleration in g, up to
--     a top speed. An empty one doesn't drive (Nikki 2026-11-09);
--   carrying: a press on any part takes it by the frame (in play mode also a press in a generous zone round
--     it), the rider still in, pulled by its whole weight, turned softly toward upright once it's a carry;
--     let go, it keeps the finger's speed; pulled back along the ground it winds up, and let go wound it
--     shoots off on its spring (the Darda), only with a Mipo in.
-- Speeds are in S (a Mipo's height) a second and accelerations in g, so they hold at any px per metre.
-- Rides live on `state.vehicleRides` (a hot swap keeps them); not saved: a loaded scene's Mipos are out.
local state = require('src.state')
local kinds = require('src.kinds')
local mipoRegistry = require('src.mipo-registry')
local mipoActions = require('src.mipo-actions')
local mipoFacing = require('src.mipo-facing')
local characterManager = require('src.character-manager')
local pointerJoints = require('src.physics.box2d-pointerjoints')
local units = require('src.physics-units')

local lib = {}

lib.SEAT_SPRING, lib.SEAT_DAMPING = 5, 0.25 -- the hips on a wheel joint in their seat
lib.RIDER_KP, lib.RIDER_MAX_OMEGA = 8, 2     -- the legs' muscles
lib.UPSIDE = 1.7       -- radians off upright: the rider falls out after UPSIDE_TIME
lib.UPSIDE_TIME = 0.6
lib.TAP_TIME = 0.25    -- a press shorter than this, moved less than TAP_PX, is a tap (play mode)
lib.TAP_PX = 14
lib.COAST_DRAG = 0.03  -- rolling drag while not driven, of g
-- carried: a soft spring turns it toward upright, per S^2 of the whole weight (rider in): held by one end it
-- still hangs ~30 degrees; KD 1.1 let a flick spin it past upside down and the rider fell out (the spike)
lib.UPRIGHT_KP, lib.UPRIGHT_KD, lib.UPRIGHT_MAX = 2.0, 1.8, 3.0
-- let go: it keeps the finger's speed over the last MOMENTUM_WINDOW seconds, at most MOMENTUM_MAX S a second
lib.MOMENTUM_WINDOW, lib.MOMENTUM_MAX = 0.1, 7
-- the Darda: dragged backwards with its wheels on the ground it winds up (WIND_MIN..WIND_MAX S of pull-back);
-- let go wound (with a Mipo in), its spring drives it WIND_RUN times as far, WIND_SPEED S a second per S
-- wound, snapping off at WIND_ACCEL g (Nikki 2026-11-09: "the Darda way")
lib.WIND_MIN, lib.WIND_MAX, lib.WIND_RUN, lib.WIND_SPEED, lib.WIND_ACCEL = 0.25, 3, 5, 3.5, 1.1

-- degrees for a rider facing right (mirrored facing left); 0 = hanging straight down. Fixed angles in the
-- world (the soapbox's lesson: aimed with the cart they made a loop: the cart tilts, the target with it).
local POSES = {
    legsOut = { torso1 = 0, luleg = -82, ruleg = -82, llleg = -70, rlleg = -70, lfoot = -150, rfoot = -150 },
    carSeat = { torso1 = 0, luleg = -80, ruleg = -80, llleg = -5, rlleg = -5, lfoot = 0, rfoot = 0 },
}
local LEGS = { { 'luleg', 'llleg', 'lfoot' }, { 'ruleg', 'rlleg', 'rfoot' } }

local function rides()
    state.vehicleRides = state.vehicleRides or {}
    return state.vehicleRides
end

local function alive(body) return body ~= nil and not body:isDestroyed() end
local function liveMipo(inst) return inst and inst.parts and inst.parts.torso1 and alive(inst.parts.torso1.body) end

local function rideOf(instance)
    local list = rides()
    list[instance.id] = list[instance.id] or { dir = 1 }
    return list[instance.id]
end

local function frameOf(instance)
    local frame = instance.parts.frame
    return frame and alive(frame.body) and frame.body or nil
end

local function vehicleInstances()
    local list = {}
    for _, instance in ipairs(kinds.all()) do
        if instance.kind == 'vehicle' and frameOf(instance) then list[#list + 1] = instance end
    end
    return list
end

local function wheels(instance)
    local list = {}
    for _, name in ipairs({ 'backWheel', 'frontWheel' }) do
        local thing = instance.parts[name]
        if thing and alive(thing.body) then list[#list + 1] = thing end
    end
    return list
end

local function wheelJoint(thing)
    for _, joint in ipairs(thing.body:getJoints()) do
        if joint:getType() == 'wheel' then return joint end
    end
end

local function bodiesOf(inst)
    local out = {}
    for _, part in pairs(inst.parts or {}) do
        if alive(part.body) then out[#out + 1] = part.body end
    end
    return out
end

-- every solid shape's bounding box corners, in the frame's coordinates
local function localExtent(inst, frame)
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for _, b in ipairs(bodiesOf(inst)) do
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

local function setAnkleLimits(inst, on)
    for _, foot in ipairs({ 'lfoot', 'rfoot' }) do
        local f = inst.parts[foot]
        for _, joint in ipairs(f and alive(f.body) and f.body:getJoints() or {}) do
            local _, b = joint:getBodies()
            if b == f.body and joint:getType() == 'revolute' then joint:setLimitsEnabled(on) end
        end
    end
end

-- the parts that never touch the rider: the wheels, and a skateboard's deck (the feet are held to it)
local function softToRider(instance, g)
    local list = {}
    for _, w in ipairs(wheels(instance)) do list[#list + 1] = w.body end
    if g.pose == 'stand' then list[#list + 1] = frameOf(instance) end
    return list
end

local function setRiderGroup(instance, g, groupIndex)
    for _, body in ipairs(softToRider(instance, g)) do
        for _, fixture in ipairs(body:getFixtures()) do fixture:setGroupIndex(groupIndex) end
    end
end

local function riderMuscles(ride, g)
    local pose = POSES[g.pose]
    if not pose then return end
    for name, angle in pairs(pose) do
        local part = ride.rider.parts[name]
        if part then
            local target = angle * ride.dir
            local keep = mipoActions.ensureKeepAngle(part, target, lib.RIDER_KP)
            if keep then
                keep.angle, keep.enabled, keep.kp, keep.maxOmega = target, nil, lib.RIDER_KP, lib.RIDER_MAX_OMEGA
            end
        end
    end
end

-- legs bent to the pose (or straight down along the frame, standing), turned at hip, knee, ankle
local function poseLegs(inst, frame, g, dir)
    local a = frame:getAngle()
    local pose = POSES[g.pose]
    for _, leg in ipairs(LEGS) do
        local names = { leg[1], leg[2], leg[3] }
        local parents = { 'torso1', leg[1], leg[2] }
        for i = 1, 3 do
            local name = names[i]
            if inst.parts[name] then
                local px, py = characterManager.jointPoint(inst, parents[i], name)
                local want = a + (pose and math.rad(pose[name] * dir) or 0)
                local rest = {}
                for k = i, 3 do rest[#rest + 1] = names[k] end
                if px then characterManager.turnParts(inst, rest, px, py, want - inst.parts[name].body:getAngle()) end
            end
        end
    end
end

local function unseat(instance, fling)
    local ride = rides()[instance.id]
    if not ride or not ride.rider then return end
    local inst = ride.rider
    for _, j in ipairs(ride.joints or {}) do
        if not j:isDestroyed() then j:destroy() end
    end
    ride.joints, ride.rider, ride.going, ride.lastV = nil, nil, false, nil
    setRiderGroup(instance, require('src.vehicles').geometry(instance), 0)
    if not liveMipo(inst) then return end
    inst._vehicle = nil
    setAnkleLimits(inst, true)
    mipoActions.wake(inst) -- standing muscles again
    if fling then
        for _, b in ipairs(bodiesOf(inst)) do b:setLinearVelocity(fling[1] * 0.9, fling[2] * 0.9 - ride.S * 1.5) end
        require('src.mipo-voice').squeak(inst, 'pickup')
    end
end

-- In: facing the way it drives, upright with the vehicle, legs posed, hips over the seat, held there.
local function seat(instance, inst)
    local frame = frameOf(instance)
    if not (frame and liveMipo(inst)) then return false end
    local g = require('src.vehicles').geometry(instance)
    local ride = rideOf(instance)
    ride.S, ride.frame = g.S, frame
    mipoActions.wake(inst)
    local side = ride.dir > 0 and 'right' or 'left'
    if mipoFacing.get(inst) ~= side then characterManager.switchFacing(inst, side) end
    local tx, ty = inst.parts.torso1.body:getPosition()
    characterManager.turnBodies(bodiesOf(inst), tx, ty, frame:getAngle() - inst.parts.torso1.body:getAngle())
    poseLegs(inst, frame, g, ride.dir)
    -- hips over the seat, the lowest point just above the floor
    local hx, hy = characterManager.jointPoint(inst, 'torso1', 'luleg')
    if not hx then hx, hy = inst.parts.torso1.body:getPosition() end
    local hlx = frame:getLocalPoint(hx, hy)
    local _, _, _, lowest = localExtent(inst, frame)
    local dx, dy = frame:getWorldVector(g.seatX * ride.dir - hlx, g.floorY - 3 - lowest)
    local vx, vy = frame:getLinearVelocity()
    for _, b in ipairs(bodiesOf(inst)) do
        local x, y = b:getPosition()
        b:setPosition(x + dx, y + dy)
        b:setLinearVelocity(vx, vy)
        b:setAngularVelocity(0)
    end
    setRiderGroup(instance, g, inst.groupIndex or 0)
    ride.rider, ride.joints, ride.lastV, ride.settle = inst, {}, nil, 0.3 -- sitting down isn't a knock
    inst._vehicle = instance.id
    if g.pose == 'stand' then
        -- feet held to the deck; standing muscles keep the rest upright
        for _, name in ipairs({ 'lfoot', 'rfoot' }) do
            local foot = inst.parts[name]
            if foot and alive(foot.body) then
                local fx, fy = foot.body:getPosition()
                ride.joints[#ride.joints + 1] = love.physics.newWeldJoint(frame, foot.body, fx, fy, false)
            end
        end
    else
        setAnkleLimits(inst, false)
        hx, hy = characterManager.jointPoint(inst, 'torso1', 'luleg')
        if not hx then hx, hy = inst.parts.torso1.body:getPosition() end
        local ax, ay = frame:getWorldVector(0, 1)
        local j = love.physics.newWheelJoint(frame, inst.parts.torso1.body, hx, hy, ax, ay, false)
        j:setSpringFrequency(lib.SEAT_SPRING)
        j:setSpringDampingRatio(lib.SEAT_DAMPING)
        ride.joints[1] = j
        riderMuscles(ride, g)
    end
    return true
end

-- facing the other way: the rider off, the vehicle's front swapped, the rider on again
local function turnAround(instance)
    local ride = rideOf(instance)
    local inst = ride.rider
    if inst then
        for _, j in ipairs(ride.joints or {}) do
            if not j:isDestroyed() then j:destroy() end
        end
        ride.joints, ride.rider = nil, nil
    end
    ride.dir = -ride.dir
    if liveMipo(inst) then seat(instance, inst) end
end

-- the spot a dropped Mipo gets in from: over the vehicle, not far above
local function inReach(instance, g, x, y)
    local lx, ly = frameOf(instance):getLocalPoint(x, y)
    return math.abs(lx) < g.len / 2 + g.S * 0.15 and ly > g.floorY - g.S * 1.4 and ly < g.floorY + g.S * 0.2
end

local function totalMass(instance, ride)
    local m = 0
    for _, b in ipairs(kinds.bodies(instance)) do m = m + b:getMass() end
    if liveMipo(ride.rider) then m = m + mipoRegistry.totalMass(ride.rider) end
    return m
end

-- speed, accel: a wound spring's instead of the motor's
local function setMotors(instance, ride, g, driving, speed, accel)
    local _, gravity = state.physicsWorld:getGravity()
    local m = totalMass(instance, ride)
    local list = wheels(instance)
    for _, w in ipairs(list) do
        local joint = wheelJoint(w)
        if joint and not joint:isDestroyed() then
            local r = w.body:getFixtures()[1]:getShape():getRadius()
            joint:setMotorEnabled(true)
            if driving then
                joint:setMotorSpeed(ride.dir * (speed or g.topSpeed) / r)
                joint:setMaxMotorTorque(m * gravity * (accel or g.accel) * r / #list)
            else
                joint:setMotorSpeed(0)
                joint:setMaxMotorTorque(m * gravity * lib.COAST_DRAG * r / #list)
            end
        end
    end
end

-- ─── What the panel and scripts can ask ───

function lib.riderOf(instance) local ride = rides()[instance.id] return ride and ride.rider end
function lib.isGoing(instance) local ride = rides()[instance.id] return ride ~= nil and ride.going == true end

-- drive (toward its front) or stop; only with a Mipo in it
function lib.setGoing(instance, on)
    local ride = rideOf(instance)
    ride.going = on and ride.rider ~= nil
end

function lib.turnAround(instance) turnAround(instance) end
function lib.riderOut(instance) unseat(instance) end
lib.seat = seat -- seat(instance, mipo): for scripts and specs

-- a tap at frame-local x: stopped, it goes toward the side tapped; going, its front stops it, its back
-- turns it round
local function tapped(instance, lx)
    local ride = rideOf(instance)
    if not ride.rider then return end
    local side = lx >= 0 and 1 or -1
    if ride.going and side == ride.dir then
        ride.going = false
    else
        if side ~= ride.dir then turnAround(instance) end
        ride.going = true
    end
end

-- ─── Every frame (an engine system, while the world runs) ───

local function heldMipos()
    local held = {}
    for _, body in ipairs(pointerJoints.getInteractedWithPointer()) do
        local inst = mipoRegistry.getFromBody(body)
        if inst then held[inst] = true end
    end
    return held
end

local function camera() return require('src.camera').getInstance() end

local function pointerWorld(id)
    local sx, sy = pointerJoints.getPointerPosition(id)
    if not sx then return nil end
    return camera():getWorldCoordinates(sx, sy)
end

-- every frame: how far the back wheel rolled forward (negative: backward), in world units
local function rolled(instance, ride)
    local w = instance.parts.backWheel
    if not (w and alive(w.body)) then return 0 end
    local a = w.body:getAngle()
    local d = a - (ride.lastWheelAngle or a)
    ride.lastWheelAngle = a
    return d * w.body:getFixtures()[1]:getShape():getRadius() * ride.dir
end

-- a wheel touching something that doesn't move (the ground)
local function onGround(instance)
    for _, w in ipairs(wheels(instance)) do
        for _, contact in ipairs(w.body:getContacts()) do
            if contact:isTouching() then
                local fa, fb = contact:getFixtures()
                if fa:getBody():getType() == 'static' or fb:getBody():getType() == 'static' then return true end
            end
        end
    end
    return false
end

local function setVelocity(instance, ride, vx, vy)
    local bodies = kinds.bodies(instance)
    if liveMipo(ride.rider) then
        for _, b in ipairs(bodiesOf(ride.rider)) do bodies[#bodies + 1] = b end
    end
    for _, b in ipairs(bodies) do
        b:setLinearVelocity(vx, vy)
        b:setAngularVelocity(0)
    end
end

local function keepUpright(instance, ride, g)
    local frame = frameOf(instance)
    local err = (frame:getAngle() + math.pi) % (2 * math.pi) - math.pi
    local torque = -(lib.UPRIGHT_KP * err + lib.UPRIGHT_KD * frame:getAngularVelocity())
    torque = math.max(-lib.UPRIGHT_MAX, math.min(lib.UPRIGHT_MAX, torque))
    frame:applyTorque(torque * totalMass(instance, ride) * g.S * g.S)
end

-- A press on any of its parts (or in its grab zone, play mode) takes it by the frame, at that spot, pulling
-- its whole weight, the rider still in, following the finger without springing past it (damping 1).
local function takePress(instance, ride, pj)
    local frame = frameOf(instance)
    local sx, sy = pointerJoints.getPointerPosition(pj.id)
    local wx, wy = camera():getWorldCoordinates(sx or 0, sy or 0)
    if pj.jointBody ~= frame then pointerJoints.grab(pj.id, frame, wx, wy) end
    local held = pointerJoints.getPointerJointAttachedTo(frame)
    if held and held.joint and not held.joint:isDestroyed() then
        local force = state.world.dragStrength * units.weight(totalMass(instance, ride))
        held.joint:setMaxForce(force)
        held.fullForce = force
        held.joint:setDampingRatio(1)
    end
    ride.press = { id = pj.id, sx = sx or 0, sy = sy or 0, t = 0, moved = false, lx = (frame:getLocalPoint(wx, wy)) }
    ride.trail, ride.wind, ride.spring = {}, 0, 0
end

-- Let go: a tap drives (play mode); else, wound, its spring takes it off from rest; else it keeps the
-- finger's last speed (capped). A short click in the editor is a selection, and changes nothing.
local function released(instance, ride, g)
    local press = ride.press
    ride.press = nil
    local tap = not press.moved and press.t < lib.TAP_TIME
    if tap then
        if state.playMode == true then tapped(instance, press.lx) end
        return
    end
    if ride.wind > lib.WIND_MIN * g.S and ride.rider then
        setVelocity(instance, ride, 0, 0)
        local wound = math.min(ride.wind, lib.WIND_MAX * g.S)
        ride.spring, ride.springSpeed, ride.going = wound * lib.WIND_RUN, wound * lib.WIND_SPEED, false
    else
        local trail, vx, vy = ride.trail, 0, 0
        if #trail >= 2 then
            local a, b = trail[1], trail[#trail]
            local dt = b[1] - a[1]
            if dt > 0.01 then vx, vy = (b[2] - a[2]) / dt, (b[3] - a[3]) / dt end
        end
        local speed, max = math.sqrt(vx * vx + vy * vy), lib.MOMENTUM_MAX * g.S
        if speed > max then vx, vy = vx / speed * max, vy / speed * max end
        setVelocity(instance, ride, vx, vy)
    end
    ride.wind, ride.trail, ride.settle = 0, nil, 0.6 -- set down: a bump isn't a crash
end

-- while held: the finger's path (for the release speed), winding when pulled back along the ground,
-- upright once it's a carry, not a tap
local function carry(instance, ride, g, dt, forward)
    local press = ride.press
    press.t = press.t + dt
    local sx, sy = pointerJoints.getPointerPosition(press.id)
    if sx and (sx - press.sx) ^ 2 + (sy - press.sy) ^ 2 > lib.TAP_PX ^ 2 then press.moved = true end
    local wx, wy = pointerWorld(press.id)
    if wx then
        local now = love.timer.getTime()
        ride.trail[#ride.trail + 1] = { now, wx, wy }
        while #ride.trail > 2 and now - ride.trail[1][1] > lib.MOMENTUM_WINDOW do table.remove(ride.trail, 1) end
    end
    if forward < 0 and onGround(instance) then ride.wind = math.min(ride.wind - forward, lib.WIND_MAX * g.S) end
    if press.moved or press.t >= lib.TAP_TIME then keepUpright(instance, ride, g) end
end

-- the pointer joint holding one of its parts, or nil
local function heldBy(instance)
    for _, pj in ipairs(pointerJoints.getPointerJoints() or {}) do
        if pj.jointBody and alive(pj.jointBody) and kinds.ofBody(pj.jointBody) == instance then return pj end
    end
end

local function watchPresses(instance, ride, g, dt, forward)
    local pj = heldBy(instance)
    if pj and not ride.press then
        takePress(instance, ride, pj)
    elseif ride.press and pj and pj.id == ride.press.id then
        carry(instance, ride, g, dt, forward)
    elseif ride.press then
        released(instance, ride, g)
    end
end

-- The grab zone (play mode): its thin boards, deck and small wheels are hard to hit (Nikki 2026-11-09), so
-- a press that took nothing, in a generous box round it, takes it. Above the rim a press is the rider's.
local function inGrabZone(instance, g, ride, wx, wy)
    local lx, ly = frameOf(instance):getLocalPoint(wx, wy)
    local top
    if g.pose == 'stand' then
        top = g.floorY - (ride.rider and g.S * 0.12 or g.S * 0.35)
    else
        top = g.floorY - g.H - (ride.rider and g.S * 0.04 or g.S * 0.35)
    end
    return math.abs(lx) < g.len / 2 + g.S * 0.12 and ly > top and ly < g.axleY + g.r + g.S * 0.1
end

local function newPresses()
    local presses = {}
    local down = love.mouse.isDown(1)
    if down and not state.vehicleRidesMouseDown then presses[#presses + 1] = 'mouse' end
    state.vehicleRidesMouseDown = down
    local seen = {}
    for _, id in ipairs(love.touch.getTouches()) do
        seen[id] = true
        if not (state.vehicleRidesTouches and state.vehicleRidesTouches[id]) then presses[#presses + 1] = id end
    end
    state.vehicleRidesTouches = seen
    return presses
end

local function grabZones(list)
    local presses = newPresses()
    if state.playMode ~= true then return end
    for _, id in ipairs(presses) do
        local holding = false
        for _, pj in ipairs(pointerJoints.getPointerJoints() or {}) do
            if pj.id == id then holding = true end
        end
        local wx, wy = pointerWorld(id)
        if wx and not holding then
            for _, instance in ipairs(list) do
                if inGrabZone(instance, require('src.vehicles').geometry(instance), rideOf(instance), wx, wy) then
                    pointerJoints.grab(id, frameOf(instance), wx, wy)
                    break
                end
            end
        end
    end
end

-- the wound spring unwinds as it rolls forward, slowing over its last stretch; only with a Mipo in
local function springDrive(instance, ride, g, forward)
    ride.spring = ride.spring - math.max(0, forward)
    if not ride.rider then ride.spring = 0 end
    local fade = math.min(1, math.max(0, ride.spring) / (g.S * 1.5))
    setMotors(instance, ride, g, ride.spring > 0, ride.springSpeed * (0.3 + 0.7 * fade), lib.WIND_ACCEL)
end

-- a ride whose vehicle is gone (deleted, dissolved, a new scene's): its rider gets its own legs back
local function dropOrphans()
    for id, ride in pairs(rides()) do
        local instance = kinds.getById(id)
        if not (instance and frameOf(instance)) then
            local inst = ride.rider
            for _, j in ipairs(ride.joints or {}) do
                if not j:isDestroyed() then j:destroy() end
            end
            if liveMipo(inst) then
                inst._vehicle = nil
                setAnkleLimits(inst, true)
                mipoActions.wake(inst)
            end
            rides()[id] = nil
        end
    end
end

function lib.update(dt)
    dt = math.min(dt or 0, 0.05)
    dropOrphans()
    local list = vehicleInstances()
    grabZones(list)
    local held = heldMipos()
    -- let go over a free vehicle: in
    for inst in pairs(state.vehicleRidesHeld or {}) do
        if not held[inst] and liveMipo(inst) and not inst._vehicle then
            local x, y = inst.parts.torso1.body:getPosition()
            for _, instance in ipairs(list) do
                local ride = rides()[instance.id]
                local free = not (ride and ride.rider)
                if free and inReach(instance, require('src.vehicles').geometry(instance), x, y) then
                    if seat(instance, inst) then require('src.mipo-voice').squeak(inst, 'pickup') end
                    break
                end
            end
        end
    end
    state.vehicleRidesHeld = held
    for _, instance in ipairs(list) do
        local ride = rideOf(instance)
        local g = require('src.vehicles').geometry(instance)
        local frame = frameOf(instance)
        local forward = rolled(instance, ride)
        watchPresses(instance, ride, g, dt, forward)
        local inst = ride.rider
        if inst and (not liveMipo(inst) or ride.frame ~= frame or not ride.joints or not ride.joints[1]
                or ride.joints[1]:isDestroyed()) then
            unseat(instance) -- the Mipo, the vehicle (rebuilt) or the joints gone
        elseif inst then
            local vx, vy = frame:getLinearVelocity()
            local pv = ride.lastV or { vx, vy }
            local dv = math.sqrt((vx - pv[1]) ^ 2 + (vy - pv[2]) ^ 2)
            local up = math.abs((frame:getAngle() + math.pi) % (2 * math.pi) - math.pi)
            ride.upsideFor = up > lib.UPSIDE and (ride.upsideFor or 0) + dt or 0
            local tx, ty = inst.parts.torso1.body:getPosition()
            if held[inst] and not inReach(instance, g, tx, ty) then
                unseat(instance) -- dragged out
            elseif dv > g.crash and (ride.settle or 0) <= 0 and not ride.press then
                unseat(instance, pv) -- thrown off, at the speed it had
            elseif ride.upsideFor > lib.UPSIDE_TIME and not ride.press then -- carried, it stays in
                unseat(instance)
            elseif g.pose == 'stand' and mipoActions.isDazed(inst) then
                unseat(instance)
            elseif g.pose ~= 'stand' then
                riderMuscles(ride, g) -- every frame: a daze turns them back to standing
            end
            ride.lastV = { vx, vy }
        end
        ride.settle = math.max(0, (ride.settle or 0) - dt)
        if not ride.rider then ride.going = false end
        if ride.press then ride.spring = 0 end
        if (ride.spring or 0) > 0 then
            springDrive(instance, ride, g, forward)
        else
            setMotors(instance, ride, g, ride.going and not ride.press)
        end
    end
end

lib._test = { released = released, keepUpright = keepUpright, inGrabZone = inGrabZone } -- for specs

-- a new scene: no rides (the bodies go with it)
function lib.unload()
    state.vehicleRides, state.vehicleRidesHeld = nil, nil
end

return lib

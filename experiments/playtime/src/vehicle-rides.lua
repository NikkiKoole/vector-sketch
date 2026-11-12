-- vehicle-rides.lua — Mipos in vehicles, and driving them (docs/KINDS.md KD4c, out of the rides spike,
-- docs/RIDES.md). An engine system (src/systems.lua), for the vehicle kind's instances (src/vehicles.lua):
--   getting in: a Mipo let go over a free vehicle gets in (kart: legs out; car, banana: sitting, hips on a
--     spring; skateboard: standing, feet held to the deck), facing the way it drives;
--   getting off: dragged out, thrown off by a hard knock (a change of speed in a frame), falling out after
--     a while upside down, a dazed skater falling off;
--   driving: in play mode a tap on a vehicle with a Mipo in it drives it (stopped: toward the side tapped;
--     going: its front stops it, its back turns it round); the panel's actions do the same in the editor.
--     Motors in the wheel joints, torque from the whole weight (rider in) times an acceleration in g, up to
--     a top speed. An empty one doesn't drive (Nikki 2026-11-09).
-- Speeds are in S (a Mipo's height) a second and accelerations in g, so they hold at any px per metre.
-- Rides live on `state.vehicleRides` (a hot swap keeps them); not saved: a loaded scene's Mipos are out.
local state = require('src.state')
local kinds = require('src.kinds')
local mipoRegistry = require('src.mipo-registry')
local mipoActions = require('src.mipo-actions')
local mipoFacing = require('src.mipo-facing')
local characterManager = require('src.character-manager')
local pointerJoints = require('src.physics.box2d-pointerjoints')

local lib = {}

lib.SEAT_SPRING, lib.SEAT_DAMPING = 5, 0.25 -- the hips on a wheel joint in their seat
lib.RIDER_KP, lib.RIDER_MAX_OMEGA = 8, 2     -- the legs' muscles
lib.UPSIDE = 1.7       -- radians off upright: the rider falls out after UPSIDE_TIME
lib.UPSIDE_TIME = 0.6
lib.TAP_TIME = 0.25    -- a press shorter than this, moved less than TAP_PX, is a tap (play mode)
lib.TAP_PX = 14
lib.COAST_DRAG = 0.03  -- rolling drag while not driven, of g

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

local function setMotors(instance, ride, g, driving)
    local _, gravity = state.physicsWorld:getGravity()
    local m = totalMass(instance, ride)
    local list = wheels(instance)
    for _, w in ipairs(list) do
        local joint = wheelJoint(w)
        if joint and not joint:isDestroyed() then
            local r = w.body:getFixtures()[1]:getShape():getRadius()
            joint:setMotorEnabled(true)
            if driving then
                joint:setMotorSpeed(ride.dir * g.topSpeed / r)
                joint:setMaxMotorTorque(m * gravity * g.accel * r / #list)
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

-- presses on a vehicle in play mode: a short one that hardly moved is a tap
local function watchPresses(instance, ride, dt)
    local frame = frameOf(instance)
    local found
    for _, pj in ipairs(pointerJoints.getPointerJoints() or {}) do
        if pj.jointBody and alive(pj.jointBody) and kinds.ofBody(pj.jointBody) == instance then found = pj break end
    end
    local press = ride.press
    if found and not press then
        local sx, sy = pointerJoints.getPointerPosition(found.id)
        local wx, wy = require('src.camera').getInstance():getWorldCoordinates(sx or 0, sy or 0)
        ride.press = { id = found.id, sx = sx or 0, sy = sy or 0, t = 0, lx = (frame:getLocalPoint(wx, wy)) }
    elseif press and found and found.id == press.id then
        press.t = press.t + dt
        local sx, sy = pointerJoints.getPointerPosition(press.id)
        if sx and (sx - press.sx) ^ 2 + (sy - press.sy) ^ 2 > lib.TAP_PX ^ 2 then press.moved = true end
    elseif press and not found then
        if state.playMode == true and not press.moved and press.t < lib.TAP_TIME then tapped(instance, press.lx) end
        ride.press = nil
    end
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
        watchPresses(instance, ride, dt)
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
            elseif dv > g.crash and (ride.settle or 0) <= 0 then
                unseat(instance, pv) -- thrown off, at the speed it had
            elseif ride.upsideFor > lib.UPSIDE_TIME then
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
        setMotors(instance, ride, g, ride.going)
    end
end

-- a new scene: no rides (the bodies go with it)
function lib.unload()
    state.vehicleRides, state.vehicleRidesHeld = nil, nil
end

return lib

-- reach-arm.lua: a Mipo arm that reaches in 3D and stays honest in Box2D (docs/REACH.md; scene `reach`).
--
-- The hand has a place in 3D (x, y on screen, z toward the camera). A two-bone solve in 3D finds the
-- elbow; seen from the front an arm that points at you is shorter. Box2D does that for real: the arm
-- in the world is two small bodies, the elbow and the hand, on distance joints from the shoulder whose
-- lengths are set every step to the arm's length as seen (sqrt(L^2 - dz^2)). So where the hand is drawn
-- is where it is: it pushes, gets pushed and lands where you see it. Muscles pull the elbow and hand
-- toward the solve (a spring with gravity held up), nothing is teleported.
--
-- The look is the Mipo's own: its arm bodies (upper arm, forearm, hand) become ghosts (sensors, no
-- gravity, next to no mass, so their joints can't pull the body; not inactive: the engine asks every
-- Mipo part for its bounding box, which an inactive body hasn't got) and are only posed each step,
-- so their joint anchors sit on the physics elbow and wrist; the arm ribbon (drawn through those anchors)
-- and the hand picture follow. The hand grows nearer the camera and shrinks away; an arm
-- behind the body is drawn before the torso, one in front of it after everything.
local mipoRegistry = require('src.mipo-registry')
local state = require('src.state')

local lib = {}

-- the settings a scene can change (its panel); kept by the scene, passed in
lib.defaults = {
    strength = 1,      -- muscles: 0 the arm hangs, 1 it holds its place against gravity
    tone = 0.08,       -- a hanging arm's muscles: just enough to settle beside the body
    kp = 400,          -- 1/s^2: how hard the hand and elbow are pulled toward the solve
    damping = 1,       -- 1 = critically damped
    maxAccel = 6,      -- the pull at most, in g
    elbowOut = 0.35,   -- the elbow's hint: out to the side
    elbowBack = 0.6,   -- ... and backward (away from the camera); down is 1
    focal = 2.5,       -- perspective: the camera is this many arm-lengths away (hand size by depth)
    depthSize = true,  -- the hand bigger near the camera, smaller away
    layers = true,     -- an arm behind the body drawn behind the torso, one in front over everything
    zSpeed = 8,        -- 1/s: how fast the depths follow the solve
}

local sqrt, atan2, cos, sin, abs = math.sqrt, math.atan2, math.cos, math.sin, math.abs

local function len(x, y, z) return sqrt(x * x + y * y + (z or 0) * (z or 0)) end

local function jointFrom(a, b)
    return mipoRegistry.jointBetween(a, b, 'revolute')
end

-- the joint that hangs `child` from its parent (the parent is always body A)
local function parentJoint(child)
    for _, j in ipairs(child:getJoints()) do
        if j:getType() == 'revolute' and not j:isDestroyed() then
            local a, b = j:getBodies()
            if b == child then return j, a end
        end
    end
end

local function collisionFixture(body)
    for _, f in ipairs(body:getFixtures()) do
        if not f:getUserData() then return f end
    end
end

local function handRadius(body)
    local f = collisionFixture(body)
    if not f then return 20 end
    local shape = f:getShape()
    if shape:getType() == 'circle' then return shape:getRadius() end
    if shape:getType() == 'polygon' then
        local pts = { shape:getPoints() }
        local cx, cy = body:getLocalCenter()
        local r = 0
        for i = 1, #pts, 2 do r = math.max(r, len(pts[i] - cx, pts[i + 1] - cy)) end
        return r * 0.75
    end
    return 20
end

-- An arm for side 'l' or 'r' of a Mipo. nil when the Mipo has no such arm.
function lib.build(world, inst, side)
    local P = inst.parts
    local up, low, hand = P[side .. 'uarm'], P[side .. 'larm'], P[side .. 'hand']
    if not (up and low and hand and up.body and low.body and hand.body) then return nil end
    up, low, hand = up.body, low.body, hand.body
    local shoulderJ, torso = parentJoint(up)
    local elbowJ, wristJ = jointFrom(up, low), jointFrom(low, hand)
    if not (shoulderJ and elbowJ and wristJ) then return nil end

    local sx, sy = shoulderJ:getAnchors()
    local ex, ey = elbowJ:getAnchors()
    local wx, wy = wristJ:getAnchors()
    local cx, cy = hand:getPosition()
    local arm = {
        side = side, sign = side == 'l' and -1 or 1, inst = inst,
        torso = torso, up = up, low = low, hand = hand,
        a = len(ex - sx, ey - sy),          -- upper arm
        b = len(wx - ex, wy - ey),          -- forearm
        h = len(cx - wx, cy - wy),          -- wrist to the hand's middle
    }
    arm.B = arm.b + arm.h                    -- elbow to the hand's middle: the hand goes on straight
    arm.reach = arm.a + arm.B
    arm.localS = { torso:getLocalPoint(sx, sy) }
    arm.uS, arm.uE = { up:getLocalPoint(sx, sy) }, { up:getLocalPoint(ex, ey) }
    arm.lE, arm.lW = { low:getLocalPoint(ex, ey) }, { low:getLocalPoint(wx, wy) }
    arm.handRest = hand:getAngle() - low:getAngle()
    -- the hand's middle sits off the forearm's line a little (a thumb side); kept in the forearm's frame
    arm.hOff = { low:getLocalPoint(cx, cy) }
    arm.hOff[1], arm.hOff[2] = arm.hOff[1] - arm.lW[1], arm.hOff[2] - arm.lW[2]
    -- the rest pose, against the torso: to put them back for 'flat'
    arm.rest = {}
    for _, body in ipairs({ up, low, hand }) do
        local lx, ly = torso:getLocalPoint(body:getPosition())
        arm.rest[body] = { lx, ly, body:getAngle() - torso:getAngle() }
    end

    -- the physics arm: an elbow (a sensor, it doesn't snag) and a hand (it touches the world, not its
    -- own Mipo: the torso's collision group)
    local handFixture = collisionFixture(hand)
    arm.elbow = love.physics.newBody(world, ex, ey, 'dynamic')
    local ef = love.physics.newFixture(arm.elbow, love.physics.newCircleShape(arm.a * 0.12), 1)
    ef:setSensor(true)
    arm.elbow:setMass(up:getMass() * 0.5 + low:getMass() * 0.5)
    arm.palm = love.physics.newBody(world, cx, cy, 'dynamic')
    arm.palm:setFixedRotation(true)
    arm.radius = handRadius(hand)
    local pf = love.physics.newFixture(arm.palm, love.physics.newCircleShape(arm.radius), 1)
    if handFixture then
        pf:setFilterData(handFixture:getFilterData())
        pf:setFriction(handFixture:getFriction())
    end
    arm.palm:setMass(hand:getMass() + low:getMass() * 0.5)
    arm.palm:setBullet(true)
    -- not drawn as debug shapes: the Mipo's own arm is their picture (src/physics/box2d-draw.lua)
    state.hiddenBodies = state.hiddenBodies or setmetatable({}, { __mode = 'k' })
    state.hiddenBodies[arm.elbow], state.hiddenBodies[arm.palm] = true, true
    arm.j1 = love.physics.newDistanceJoint(torso, arm.elbow, sx, sy, ex, ey, false)
    arm.j2 = love.physics.newDistanceJoint(arm.elbow, arm.palm, ex, ey, cx, cy, false)

    arm.zE, arm.zH = 0, 0            -- depths now
    arm.pose = {}                    -- the last good angles (an arm straight at you has none)
    arm.seen = {}                    -- [d] = draw: the Mipo's arm ribbon, hair, hand, from the draw hook
    lib.setMode(arm, '3d')
    return arm
end

-- '3d': the physics arm works, the Mipo's own arm is only posed. 'flat': the Mipo's arm as always.
function lib.setMode(arm, mode)
    if arm.mode == mode then return end
    arm.mode = mode
    local torso = arm.torso
    if mode == 'flat' then
        local ta = torso:getAngle()
        for body, r in pairs(arm.rest) do
            local wx, wy = torso:getWorldPoint(r[1], r[2])
            body:setTransform(wx, wy, ta + r[3])
            body:setLinearVelocity(torso:getLinearVelocityFromWorldPoint(wx, wy))
            body:setAngularVelocity(torso:getAngularVelocity())
            lib.ghost(arm, body, false)
        end
        lib.ghost(arm, arm.elbow, true)
        lib.ghost(arm, arm.palm, true)
    else
        -- the physics arm starts where the Mipo's arm is now, flat
        local elbowJ = jointFrom(arm.up, arm.low)
        local ex, ey = elbowJ:getAnchors()
        arm.elbow:setPosition(ex, ey)
        arm.palm:setPosition(arm.hand:getWorldCenter())
        for _, body in ipairs({ arm.elbow, arm.palm }) do
            body:setLinearVelocity(arm.hand:getLinearVelocity())
            lib.ghost(arm, body, false)
        end
        arm.zE, arm.zH = 0, 0
        arm.j1:setLength(arm.a)
        arm.j2:setLength(len(arm.palm:getX() - ex, arm.palm:getY() - ey))
        for _, body in ipairs({ arm.up, arm.low, arm.hand }) do lib.ghost(arm, body, true) end
    end
end

-- A body as a ghost: it touches nothing, falls not, and weighs next to nothing, so whatever holds it
-- (a joint, a pose) moves it and it moves nothing. false: as it was.
lib.GHOST_MASS = 1 / 2000 -- of the torso's
function lib.ghost(arm, body, on)
    arm.saved = arm.saved or {}
    local saved = arm.saved[body]
    if on then
        if saved then return end
        local cx, cy, m, i = body:getMassData()
        saved = { cx = cx, cy = cy, m = m, i = i, g = body:getGravityScale(), sensors = {} }
        arm.saved[body] = saved
        for _, f in ipairs(body:getFixtures()) do
            saved.sensors[f] = f:isSensor()
            f:setSensor(true)
        end
        body:setGravityScale(0)
        local k = arm.torso:getMass() * lib.GHOST_MASS / math.max(m, 1e-9)
        body:setMassData(cx, cy, m * k, math.max(i * k, 1e-9))
    else
        if not saved then return end
        for f, was in pairs(saved.sensors) do
            if not f:isDestroyed() then f:setSensor(was) end
        end
        body:setGravityScale(saved.g)
        body:setMassData(saved.cx, saved.cy, saved.m, saved.i)
        arm.saved[body] = nil
    end
end

function lib.destroy(arm)
    if not arm then return end
    for _, body in ipairs({ arm.elbow, arm.palm }) do
        if body and not body:isDestroyed() then body:destroy() end -- (its joints go with it)
    end
end

function lib.alive(arm)
    return arm and not arm.palm:isDestroyed() and not arm.torso:isDestroyed()
end

function lib.shoulder(arm)
    return arm.torso:getWorldPoint(arm.localS[1], arm.localS[2])
end

-- The two-bone solve in 3D, in the shoulder's space (y down, z toward the camera): the elbow for a
-- hand at t, upper arm a, elbow-to-hand B, the elbow bending toward the pole. Returns the elbow and
-- the hand (pulled in when out of reach).
function lib.solve(tx, ty, tz, a, B, px, py, pz)
    local d = len(tx, ty, tz)
    local nx, ny, nz
    if d < 1e-6 then nx, ny, nz = 0, 1, 0 else nx, ny, nz = tx / d, ty / d, tz / d end
    d = math.max(abs(a - B) + 1e-3, math.min(d, (a + B) * 0.999))
    local x = (a * a - B * B + d * d) / (2 * d)
    local hgt = sqrt(math.max(0, a * a - x * x))
    -- the pole, square to the arm's line
    local dot = px * nx + py * ny + pz * nz
    local qx, qy, qz = px - dot * nx, py - dot * ny, pz - dot * nz
    local ql = len(qx, qy, qz)
    if ql < 1e-6 then qx, qy, qz, ql = 0, 0, -1, 1 end
    qx, qy, qz = qx / ql, qy / ql, qz / ql
    return nx * x + qx * hgt, ny * x + qy * hgt, nz * x + qz * hgt, nx * d, ny * d, nz * d
end

-- The arm's goal this step: `target` = { x, y, z } in the world (z toward the camera, in px), or nil:
-- no muscles, it hangs, and its depths ease back to flat.
function lib.update(arm, dt, target, cfg, gravity)
    if arm.mode ~= '3d' then return end
    local sx, sy = lib.shoulder(arm)
    local gx, gy = gravity[1], gravity[2]
    local ezT, hzT = 0, 0
    local goal
    if target then
        local ex, ey, ez, hx, hy, hz = lib.solve(target.x - sx, target.y - sy, target.z or 0, arm.a, arm.B,
            arm.sign * cfg.elbowOut, 1, -cfg.elbowBack)
        goal = { ex = sx + ex, ey = sy + ey, hx = sx + hx, hy = sy + hy }
        ezT, hzT = ez, hz
        arm.goal = { ex = ex, ey = ey, ez = ez, hx = hx, hy = hy, hz = hz }
    else
        arm.goal = nil
    end
    -- the depths follow the solve (so the lengths don't jump)
    local k = math.min(1, dt * cfg.zSpeed)
    arm.zE = arm.zE + (ezT - arm.zE) * k
    arm.zH = arm.zH + (hzT - arm.zH) * k
    arm.zE = math.max(-arm.a * 0.98, math.min(arm.a * 0.98, arm.zE))
    local dz = arm.zH - arm.zE
    dz = math.max(-arm.B * 0.98, math.min(arm.B * 0.98, dz))
    arm.zH = arm.zE + dz
    -- the lengths as seen from the front: the honest part
    arm.j1:setLength(math.max(2, sqrt(arm.a * arm.a - arm.zE * arm.zE)))
    arm.j2:setLength(math.max(2, sqrt(arm.B * arm.B - dz * dz)))

    local strength = cfg.strength
    if not goal then
        -- let go: not a pendulum, an arm. A little tone pulls the hand down beside the body (its elbow
        -- just in front), with friction in shoulder and elbow, so it settles instead of swinging round
        local ex, ey, _, hx, hy = lib.solve(arm.sign * 0.12 * arm.reach, arm.reach, 0, arm.a, arm.B,
            arm.sign * cfg.elbowOut, 1, -cfg.elbowBack)
        goal = { ex = sx + ex, ey = sy + ey, hx = sx + hx, hy = sy + hy }
        strength = cfg.tone
    end
    if strength <= 0 then return end
    local kp = cfg.kp * strength
    local kd = 2 * cfg.damping * sqrt(kp)
    local g = len(gx, gy)
    local maxA = cfg.maxAccel * g
    local function pull(body, tx, ty)
        local x, y = body:getPosition()
        local vx, vy = body:getLinearVelocity()
        local svx, svy = arm.torso:getLinearVelocityFromWorldPoint(sx, sy)
        local ax = kp * (tx - x) - kd * (vx - svx)
        local ay = kp * (ty - y) - kd * (vy - svy)
        local al = len(ax, ay)
        if al > maxA then ax, ay = ax * maxA / al, ay * maxA / al end
        local m = body:getMass()
        -- gravity held up by the muscles (as strong as they are); what pulls the arm pushes the body
        -- back at the shoulder, so the Mipo can't fly by waving (a muscle is inside it)
        local hold = target and strength or 0 -- a hanging arm is all weight
        local fx, fy = m * (ax - gx * hold), m * (ay - gy * hold)
        body:applyForce(fx, fy)
        arm.torso:applyForce(-fx, -fy, sx, sy)
    end
    pull(arm.elbow, goal.ex, goal.ey)
    pull(arm.palm, goal.hx, goal.hy)
end

local function place(body, lx, ly, wx, wy, angle)
    local c, s = cos(angle), sin(angle)
    body:setTransform(wx - (c * lx - s * ly), wy - (s * lx + c * ly), angle)
end

-- Pose the Mipo's own (inactive) arm on the physics arm, before the world is drawn.
function lib.pose(arm)
    if arm.mode ~= '3d' then return end
    local sx, sy = lib.shoulder(arm)
    local ex, ey = arm.elbow:getPosition()
    local cx, cy = arm.palm:getPosition()
    -- the wrist is on the line from elbow to hand's middle, as in 3D (a straight line stays one)
    local f = arm.b / arm.B
    local wx, wy = ex + (cx - ex) * f, ey + (cy - ey) * f
    local p = arm.pose
    -- an arm seen end-on has no direction: keep the last one
    if len(ex - sx, ey - sy) > 1 then
        p.up = atan2(ey - sy, ex - sx) - atan2(arm.uE[2] - arm.uS[2], arm.uE[1] - arm.uS[1])
    end
    if len(cx - ex, cy - ey) > 1 then
        p.low = atan2(cy - ey, cx - ex) - atan2(arm.lW[2] - arm.lE[2], arm.lW[1] - arm.lE[1])
    end
    p.up = p.up or arm.torso:getAngle()
    p.low = p.low or p.up
    place(arm.up, arm.uE[1], arm.uE[2], ex, ey, p.up)
    place(arm.low, arm.lW[1], arm.lW[2], wx, wy, p.low)
    -- the hand's middle on the physics hand (its wrist end then lies over the forearm when it's short)
    local ha = p.low + arm.handRest
    local hc, hs = cos(p.low), sin(p.low)
    local ox, oy = hc * arm.hOff[1] - hs * arm.hOff[2], hs * arm.hOff[1] + hc * arm.hOff[2]
    local fl = len(arm.hOff[1], arm.hOff[2])
    local hx, hy = cx, cy
    if fl > 1e-6 then -- only the sideways part of the offset: along the arm it is the physics hand
        local ux, uy = cos(p.low + math.pi / 2), sin(p.low + math.pi / 2)
        local along = ox * ux + oy * uy
        hx, hy = cx + ox - ux * along, cy + oy - uy * along
    end
    arm.hand:setTransform(hx, hy, ha)
    local vx, vy = arm.palm:getLinearVelocity()
    for _, body in ipairs({ arm.up, arm.low, arm.hand }) do
        body:setLinearVelocity(vx, vy)
        body:setAngularVelocity(0)
    end
end

-- How big the hand looks at its depth (perspective; 1 at the body's plane).
function lib.handScale(arm, cfg)
    if not cfg.depthSize then return 1 end
    local F = cfg.focal * arm.reach
    return F / math.max(F * 0.2, F - arm.zH)
end

-- 'back', 'front' or nil (where the Mipo draws it anyway) for one of the arm's drawables.
function lib.layerOf(arm, d, cfg)
    if not cfg.layers or arm.mode ~= '3d' then return nil end
    local z = (d.body == arm.hand) and arm.zH or (arm.zE + arm.zH) / 2
    local edge = arm.reach * 0.15
    if z < -edge then return 'back' end
    if z > edge then return 'front' end
    return nil
end

-- Is this drawable part of this arm (the ribbon and its hair hang on the upper arm)?
function lib.owns(arm, d)
    return d.body == arm.up or d.body == arm.low or d.body == arm.hand
end

-- Draw one of the arm's drawables, the hand at its depth's size.
function lib.drawPart(arm, d, draw, cfg)
    if d.body == arm.hand and arm.mode == '3d' then
        local s = lib.handScale(arm, cfg)
        if abs(s - 1) > 1e-3 then
            local hx, hy = arm.hand:getPosition()
            love.graphics.push()
            love.graphics.translate(hx, hy)
            love.graphics.scale(s)
            love.graphics.translate(-hx, -hy)
            draw(d)
            love.graphics.pop()
            return
        end
    end
    draw(d)
end

return lib

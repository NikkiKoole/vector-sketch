-- drag-feel.lua: a dragged Mipo that feels handled, not hauled (scene `dragfeel`, docs/DRAG-FEEL.md).
-- Loaded with love.filesystem.load('scripts/spikes/drag-feel.lua')(). Physics and muscles only (the
-- engine's KEEP_ANGLEs and the pointer's mouse joint), nothing teleported or floated.
-- The stages, each on its own switch (lib.on) with its numbers (lib.tuning):
--   notice   the finger hovers near and above a Mipo: it looks at it and lifts its arms (pick me up)
--   pickup   grabbed off the ground: a short crouch first (the drag held weak), then it's lifted
--   middle   held by the torso wherever it was pressed (a hand held swung the whole Mipo round it)
--   spring   the drag a softer spring: it lags behind the finger and swings past when the finger stops
--   upright  the torso kept upright while held, leaning with the drag (feet trailing)
--   dangle   arms and legs on soft muscles while held: they swing instead of standing stiff
--   brace    about to hit something along the drag: arms toward it, knees up, eyes on it
--   feel     a floor close below: legs reach for it; higher up they walk in the air
--   reach    the drag slow near something to hold (a bar, a rung, a ledge, another Mipo's hand): the
--            near hand reaches; touching it, it grips. A grip lets go when pulled hard or far. Let go
--            of a Mipo holding on and it hangs there.
-- The finger always wins: grips only form when the drag is slow, and a firm pull breaks them.
local state = require('src.state')
local mipoRegistry = require('src.mipo-registry')
local mipoActions = require('src.mipo-actions')
local mipoWalk = require('src.mipo-walk')
local mipoFacing = require('src.mipo-facing')
local characterManager = require('src.character-manager')
local pointerJoints = require('src.physics.box2d-pointerjoints')
local units = require('src.physics-units')
local camera = require('src.camera')

local lib = {}

lib.on = { notice = true, pickup = true, middle = true, spring = true, upright = true, dangle = true,
    brace = true, feel = true, reach = true, senses = false }
lib.ORDER = { 'notice', 'pickup', 'middle', 'spring', 'upright', 'dangle', 'brace', 'feel', 'reach', 'senses' }

lib.tuning = {
    notice = 900,       -- notice: the finger seen this near (world px)
    pickupTime = 0.16,  -- pickup: seconds of crouch before it leaves the ground
    crouch = 40,        -- pickup: degrees the knees give
    strength = 10,      -- the drag pulls with at most this many of the Mipo's weights
    follow = 2.6,       -- spring: Hz (the engine's is 5: lower lags more)
    damping = 0.45,     -- spring: damping ratio (lower swings past more; 0.3 swung far past a quick stop)
    upright = 18,       -- upright: the torso's muscle (KEEP_ANGLE kp)
    lean = 0.025,       -- upright: degrees of lean per px/s of drag
    maxLean = 30,       -- upright: degrees at most
    dangle = 3,         -- dangle: the limbs' muscles while held (kp; standing is ~40)
    lookAhead = 0.3,    -- brace: seconds ahead along the drag it looks
    feel = 1.8,         -- feel: legs reach for a floor this many leg lengths below
    walk = 2.2,         -- feel: air-walk steps a second
    reach = 300,        -- reach: a hand reaches for a hold this near its shoulder
    grabSpeed = 600,    -- reach: only when the drag is slower than this (px/s)
    gripBreak = 2.5,    -- reach: a grip lets go when pulled this many times the Mipo's weight for 0.15 s
    pullAway = 450,     -- reach: or when the finger is this far from the grip (px)
    hangFor = 8,        -- reach: let go holding on, it hangs this long (s; 0 for good)
}

local function data()
    state.dragFeel = state.dragFeel or { recs = {}, holds = {} }
    return state.dragFeel
end
lib.data = data

local function alive(body) return body ~= nil and not body:isDestroyed() end
local function world() return state.physicsWorld end

-- ── holds: what a hand can grip, as segments on bodies (a scene adds them) ──

function lib.clearHolds() data().holds = {} end
-- a segment from (x1, y1) to (x2, y2), world, on body; a point when x2 is nil
function lib.addHold(body, x1, y1, x2, y2)
    local holds = data().holds
    holds[#holds + 1] = { body = body, x1 = x1, y1 = y1, x2 = x2 or x1, y2 = y2 or y1 }
end

local function nearestOnSegment(h, x, y)
    local dx, dy = h.x2 - h.x1, h.y2 - h.y1
    local L = dx * dx + dy * dy
    local t = L > 0 and math.max(0, math.min(1, ((x - h.x1) * dx + (y - h.y1) * dy) / L)) or 0
    return h.x1 + dx * t, h.y1 + dy * t
end

-- ── the Mipo's muscles: set for a while, put back after ──

local function keep(inst, rec, name, angleDeg, kp, maxOmega)
    local part = inst.parts[name]
    if not (part and alive(part.body)) then return end
    local had = mipoActions.getKeepAngle(part)
    local b = mipoActions.ensureKeepAngle(part, angleDeg, kp)
    if not b then return end
    if rec.saved[name] == nil then
        rec.saved[name] = had and { angle = b.angle, kp = b.kp, maxOmega = b.maxOmega, enabled = b.enabled }
            or { none = true }
    end
    b.angle, b.kp, b.maxOmega, b.enabled = angleDeg, kp, maxOmega or 10, nil
end

local function restoreKeeps(inst, rec)
    for name, was in pairs(rec.saved) do
        local b = mipoActions.getKeepAngle(inst.parts[name])
        if b then
            if was.none then b.enabled = false
            else b.angle, b.kp, b.maxOmega, b.enabled = was.angle, was.kp, was.maxOmega, was.enabled end
        end
    end
    rec.saved = {}
end

local ARMS = { l = { 'luarm', 'llarm', 'lhand' }, r = { 'ruarm', 'rlarm', 'rhand' } }
local LEGS = { l = { 'luleg', 'llleg', 'lfoot' }, r = { 'ruleg', 'rlleg', 'rfoot' } }

local function arm(inst, rec, side, angleDeg, kp, elbow)
    local names = ARMS[side]
    keep(inst, rec, names[1], angleDeg, kp)
    keep(inst, rec, names[2], angleDeg + (elbow or 0), kp)
    keep(inst, rec, names[3], angleDeg + (elbow or 0), kp)
end

-- a leg: the thigh at angleDeg, the shin `knee` degrees further (the knee bends back: opposite the thigh)
local function leg(inst, rec, side, angleDeg, knee, kp)
    local names = LEGS[side]
    keep(inst, rec, names[1], angleDeg, kp)
    keep(inst, rec, names[2], angleDeg + knee, kp)
end

local function faceDir(inst)
    local f = mipoFacing.get(inst)
    return f == 'left' and -1 or 1
end

local function totalWeight(inst)
    return mipoRegistry.totalMass(inst) * 9.8 * love.physics.getMeter()
end

local function standingHeight(inst)
    if not inst._dragFeelH then inst._dragFeelH = characterManager.mipoHeight(inst) end
    return inst._dragFeelH
end

local function ownBody(inst, body)
    local other = mipoRegistry.getFromBody(body)
    return other ~= nil and other.id == inst.id
end

-- the first solid thing on the line from a to b that isn't the Mipo itself: x, y, fraction, body
local function ray(inst, x1, y1, x2, y2)
    if (x2 - x1) ^ 2 + (y2 - y1) ^ 2 < 1 then return nil end
    local hx, hy, hf, hb
    world():rayCast(x1, y1, x2, y2, function(fixture, x, y, _, _, fraction)
        if fixture:isSensor() or ownBody(inst, fixture:getBody()) then return -1 end
        hx, hy, hf, hb = x, y, fraction, fixture:getBody()
        return fraction
    end)
    return hx, hy, hf, hb
end

local function pointerWorld(id)
    local sx, sy = pointerJoints.getPointerPosition(id)
    if not sx then return nil end
    return camera.getInstance():getWorldCoordinates(sx, sy)
end

local function heldMipos()
    local held = {}
    for _, pj in ipairs(pointerJoints.getPointerJoints()) do
        if pj.joint and alive(pj.jointBody) then
            local inst, partName = mipoRegistry.getFromBody(pj.jointBody)
            if inst then held[inst] = { id = pj.id, part = partName, pj = pj } end
        end
    end
    return held
end

-- ── the record of what's being done to a Mipo ──

local function startRec(inst, kind)
    local rec = { kind = kind, saved = {}, grips = {}, t0 = love.timer.getTime(), senses = {} }
    data().recs[inst.id] = rec
    rec.wasRagdoll = inst._isRagdoll
    inst._isRagdoll = true -- (only the flag: mipoActions' arm hang leaves the arms to these muscles)
    inst._noStandUp = true -- (mipoJointGuard: a limb held off its target isn't a split to hop out of)
    return rec
end

local function dropGrips(rec)
    for name, g in pairs(rec.grips) do
        if g.joint and not g.joint:isDestroyed() then g.joint:destroy() end
        rec.grips[name] = nil
    end
end

local function endRec(inst, rec)
    restoreKeeps(inst, rec)
    dropGrips(rec)
    mipoActions.stopLooking(inst)
    mipoActions.wake(inst) -- every muscle as standing wants it, the arm hang back
    mipoWalk.hold(inst, false)
    inst._noStandUp = nil
    data().recs[inst.id] = nil
end

-- ── grips ──

-- the nearest hold to a point, within maxD: x, y, body (another Mipo's hand counts)
local function nearestHold(inst, x, y, maxD)
    local best, bx, by, bb = maxD * maxD, nil, nil, nil
    for _, h in ipairs(data().holds) do
        if alive(h.body) then
            local px, py = nearestOnSegment(h, x, y)
            local d = (px - x) ^ 2 + (py - y) ^ 2
            if d < best then best, bx, by, bb = d, px, py, h.body end
        end
    end
    for _, other in pairs(mipoRegistry.getAll and mipoRegistry.getAll() or {}) do
        if other.id ~= inst.id then
            for _, name in ipairs({ 'lhand', 'rhand' }) do
                local p = other.parts and other.parts[name]
                if p and alive(p.body) then
                    local px, py = p.body:getPosition()
                    local d = (px - x) ^ 2 + (py - y) ^ 2
                    if d < best then best, bx, by, bb = d, px, py, p.body end
                end
            end
        end
    end
    return bx, by, bb
end

-- a hand's grip: kept while it holds, broken by a pull (force for a while) or the finger far off
local function checkGrip(inst, rec, side, held, dt, weight)
    local g = rec.grips[side]
    if not g then return end
    if g.joint:isDestroyed() or not alive(g.body) then rec.grips[side] = nil return end
    local t = lib.tuning
    local fx, fy = g.joint:getReactionForce(1 / math.max(dt, 1e-3))
    local force = math.sqrt(fx * fx + fy * fy) / weight
    local fresh = love.timer.getTime() - g.at < 0.4 -- (catching on jerks)
    g.pull = (force > t.gripBreak and not fresh) and (g.pull or 0) + dt or 0
    local far = false
    if held then
        local wx, wy = pointerWorld(held.id)
        local ax, ay = g.joint:getAnchors()
        far = wx and math.sqrt((wx - ax) ^ 2 + (wy - ay) ^ 2) > t.pullAway
    end
    if g.pull > 0.15 or far then
        g.joint:destroy()
        rec.grips[side] = nil
        rec.letGoAt = love.timer.getTime()
    end
end

-- reaching: the arm on the hold's side aims at it, and grips when the hand is on it
local function reachFor(inst, rec, speed, dt)
    local t = lib.tuning
    local now = love.timer.getTime()
    rec.senses.reach = nil
    if speed > t.grabSpeed or now - (rec.letGoAt or 0) < 0.6 then return false end
    local reaching = false
    for side, names in pairs(ARMS) do
        if not rec.grips[side] then
            local shoulder, hand = inst.parts[names[1]], inst.parts[names[3]]
            if shoulder and hand and alive(shoulder.body) and alive(hand.body) then
                local sx, sy = shoulder.body:getPosition()
                local px, py, body = nearestHold(inst, sx, sy, t.reach)
                if px then
                    reaching = true
                    rec.senses.reach = { sx, sy, px, py }
                    arm(inst, rec, side, math.deg(mipoActions.pointAngle(px - sx, py - sy)), 25, 0)
                    local hx, hy = hand.body:getPosition()
                    if (hx - px) ^ 2 + (hy - py) ^ 2 < 70 * 70 then
                        hand.body:setPosition(px, py)
                        rec.grips[side] = { joint = love.physics.newRevoluteJoint(body, hand.body, px, py, false),
                            body = body, at = now }
                    end
                end
            end
        end
    end
    return reaching
end

-- ── the stages ──

-- held: the drag joint as the stages want it (spring, strength; weak while crouching)
local function shapeDrag(inst, rec, h)
    local t, on = lib.tuning, lib.on
    local j = h.pj.joint
    if not j or j:isDestroyed() then return end
    local full = t.strength * totalWeight(inst)
    local crouching = rec.phase == 'crouch'
    j:setMaxForce(crouching and totalWeight(inst) * 0.5 or full) -- (half its weight: it can't leave the ground)
    if on.spring then
        j:setFrequency(units.rate(t.follow))
        j:setDampingRatio(t.damping)
    else
        j:setFrequency(units.rate(5))
        j:setDampingRatio(0.5)
    end
end

local function startHeld(inst, h)
    local rec = data().recs[inst.id]
    if rec and rec.kind ~= 'held' then endRec(inst, rec) rec = nil end -- (was noticing, or hanging)
    if not rec then
        rec = startRec(inst, 'held')
        mipoWalk.hold(inst, true)
        if mipoWalk.drive then mipoWalk.drive(inst, nil) end
        rec.phase = (lib.on.pickup and mipoActions.isGrounded(inst)) and 'crouch' or 'carried'
    end
    -- held by the middle: the pointer moved onto the torso's centre (held off-centre, the drag twists it; the
    -- soft spring makes the step from the pressed spot a short glide)
    local torso = inst.parts.torso1
    if lib.on.middle and torso and alive(torso.body) and h.pj.jointBody ~= torso.body then
        local wx, wy = torso.body:getWorldCenter()
        pointerJoints.grab(h.id, torso.body, wx, wy)
        for _, pj in ipairs(pointerJoints.getPointerJoints()) do
            if pj.id == h.id then h.pj = pj end
        end
    end
    return rec
end

local function updateHeld(inst, rec, h, dt)
    local t, on = lib.tuning, lib.on
    local now = love.timer.getTime()
    local torso = inst.parts.torso1.body
    local d = faceDir(inst)
    shapeDrag(inst, rec, h)
    local vx, vy = torso:getLinearVelocity()
    rec.vx = (rec.vx or vx) + (vx - (rec.vx or vx)) * math.min(1, dt * 10) -- (smoothed: the lean doesn't twitch)
    local speed = math.sqrt(vx * vx + vy * vy)
    local H = standingHeight(inst)
    local legLen = H * 0.42
    local weight = totalWeight(inst)

    -- the crouch before the lift: knees give, arms back, then up
    if rec.phase == 'crouch' then
        for _, side in ipairs({ 'l', 'r' }) do
            leg(inst, rec, side, d * t.crouch, -d * t.crouch * 2, 30)
            arm(inst, rec, side, -d * 30, 20, 0)
        end
        if now - rec.t0 > t.pickupTime then rec.phase = 'carried' end
        return
    end

    -- the torso: upright, leaning with the drag (moved right, its feet trail left: a + angle). Its own
    -- KEEP_ANGLE doesn't run while the pointer holds it (src/keep-angle.lua skips held bodies), so steered
    -- here the same way: its turn speed toward the angle, capped
    if on.upright then
        local lean = math.rad(math.max(-t.maxLean, math.min(t.maxLean, rec.vx * t.lean)))
        local diff = (lean - torso:getAngle() + math.pi) % (2 * math.pi) - math.pi
        local cap = units.rate(8)
        torso:setAngularVelocity(math.max(-cap, math.min(cap, units.rate(t.upright) * diff)))
    end

    -- the limbs hang soft (or stand as they were)
    local limbKp = on.dangle and t.dangle or 40
    local legAngle, armAngle = 0, 0
    local legKnee = on.dangle and -d * 15 or 0

    -- feel: a floor near below? legs reach for it; else they walk in the air
    rec.senses.floor = nil
    if on.feel then
        local tx, ty = torso:getPosition()
        local fx, fy = ray(inst, tx, ty, tx, ty + legLen * (1 + t.feel))
        if fx then
            rec.senses.floor = { tx, ty, fx, fy }
            limbKp = math.max(limbKp, 22) -- ready to land
            legKnee = 0
        else
            rec.walkPhase = (rec.walkPhase or 0) + dt * t.walk * 2 * math.pi
            rec.senses.walking = true
        end
    end

    -- brace: something ahead along the drag
    rec.senses.ahead, rec.senses.hit = nil, nil
    local bracing = false
    if on.brace and speed > 250 then
        local tx, ty = torso:getPosition()
        local ax, ay = tx + vx * t.lookAhead, ty + vy * t.lookAhead
        rec.senses.ahead = { tx, ty, ax, ay }
        local hx, hy = ray(inst, tx, ty, ax, ay)
        if hx then
            rec.braceUntil, rec.braceAt = now + 0.3, { hx, hy }
        end
    end
    if on.brace and rec.braceUntil and now < rec.braceUntil then
        bracing = true
        local tx, ty = torso:getPosition()
        local bx, by = rec.braceAt[1], rec.braceAt[2]
        rec.senses.hit = { bx, by }
        local a = math.deg(mipoActions.pointAngle(bx - tx, by - ty))
        arm(inst, rec, 'l', a, 30, 0)
        arm(inst, rec, 'r', a, 30, 0)
        leg(inst, rec, 'l', d * 70, -d * 110, 30)
        leg(inst, rec, 'r', d * 70, -d * 110, 30)
        mipoActions.lookAt(inst, { bx, by })
    end

    local reaching = false
    if not bracing then
        mipoActions.lookAt(inst, nil)
        if on.reach then reaching = reachFor(inst, rec, speed, dt) end
        for _, side in ipairs({ 'l', 'r' }) do
            -- arms: hanging soft (a gripping or reaching arm is the reach's)
            if not rec.grips[side] and not (reaching and rec.senses.reach) then
                arm(inst, rec, side, armAngle, limbKp, 0)
            end
            local a = legAngle
            if on.feel and rec.senses.walking and not rec.senses.floor then
                a = (side == 'l' and 1 or -1) * 22 * math.sin(rec.walkPhase or 0)
            end
            leg(inst, rec, side, a, legKnee, limbKp)
        end
    end
    rec.senses.walking = nil
    for side in pairs(ARMS) do checkGrip(inst, rec, side, h, dt, weight) end
end

-- let go while holding on: it hangs, arms up along the grip, legs dangling; done when no grip is left
local function updateHanging(inst, rec, dt)
    local t = lib.tuning
    local weight = totalWeight(inst)
    for side in pairs(ARMS) do checkGrip(inst, rec, side, nil, dt, weight) end
    if t.hangFor > 0 and love.timer.getTime() - (rec.hangAt or 0) > t.hangFor then dropGrips(rec) end
    if not next(rec.grips) then endRec(inst, rec) return end
    for _, side in ipairs({ 'l', 'r' }) do
        local g = rec.grips[side]
        local shoulder = inst.parts[ARMS[side][1]]
        if g and shoulder and alive(shoulder.body) then
            local ax, ay = g.joint:getAnchors()
            local sx, sy = shoulder.body:getPosition()
            arm(inst, rec, side, math.deg(mipoActions.pointAngle(ax - sx, ay - sy)), 20, 0)
        end
        leg(inst, rec, side, 0, -faceDir(inst) * 10, 3)
    end
end

-- notice: the finger near and above, not pressed: look at it, arms up
local function updateNotice(inst, rec)
    local t = lib.tuning
    local torso = inst.parts.torso1.body
    local tx, ty = torso:getPosition()
    local sx, sy = love.mouse.getPosition()
    local wx, wy = camera.getInstance():getWorldCoordinates(sx, sy)
    local near = (wx - tx) ^ 2 + (wy - ty) ^ 2 < t.notice * t.notice and wy < ty and not love.mouse.isDown(1)
    if not near then
        if rec then endRec(inst, rec) end
        return
    end
    if not rec then
        rec = startRec(inst, 'notice')
        mipoWalk.hold(inst, true)
    end
    mipoActions.lookAt(inst, 'cursor')
    -- arms up toward the finger, the nearer the higher
    local k = 1 - math.sqrt((wx - tx) ^ 2 + (wy - ty) ^ 2) / t.notice
    local up = 60 + 110 * k
    arm(inst, rec, 'l', up, 12, 0)
    arm(inst, rec, 'r', -up, 12, 0)
end

-- every frame, from the scene: mipos is the list of Mipos it looks after
function lib.update(dt, mipos)
    dt = dt or 1 / 60
    local recs = data().recs
    local held = heldMipos()
    for _, inst in ipairs(mipos) do
        local torso = inst.parts and inst.parts.torso1
        if torso and alive(torso.body) then
            local rec = recs[inst.id]
            local h = held[inst]
            if h then
                rec = startHeld(inst, h)
                updateHeld(inst, rec, h, dt)
            elseif rec and rec.kind == 'held' then
                if next(rec.grips) then
                    rec.kind, rec.hangAt = 'hanging', love.timer.getTime()
                    restoreKeeps(inst, rec)
                else
                    endRec(inst, rec)
                end
            elseif rec and rec.kind == 'hanging' then
                updateHanging(inst, rec, dt)
            elseif lib.on.notice then
                updateNotice(inst, rec)
            elseif rec then
                endRec(inst, rec)
            end
        end
    end
end

-- everything put back (the scene unloading)
function lib.unload()
    for id, rec in pairs(data().recs) do
        local inst = mipoRegistry.getById(id)
        if inst then endRec(inst, rec) else dropGrips(rec) end
    end
    data().recs = {}
    lib.clearHolds()
end

-- what the Mipos sense, drawn (lib.on.senses): the floor below, the look ahead, a hit, a reach, grips, holds
function lib.drawSenses()
    if not lib.on.senses then return end
    love.graphics.push('all')
    love.graphics.setLineWidth(6)
    love.graphics.setColor(1, 0.8, 0.2, 0.7)
    for _, h in ipairs(data().holds) do love.graphics.line(h.x1, h.y1, h.x2 + 0.5, h.y2 + 0.5) end
    for _, rec in pairs(data().recs) do
        local s = rec.senses
        if s.floor then love.graphics.setColor(0.3, 0.9, 0.4, 0.8) love.graphics.line(s.floor) end
        if s.ahead then love.graphics.setColor(0.4, 0.7, 1, 0.8) love.graphics.line(s.ahead) end
        if s.hit then love.graphics.setColor(1, 0.3, 0.3, 0.9) love.graphics.circle('line', s.hit[1], s.hit[2], 40) end
        if s.reach then love.graphics.setColor(1, 0.8, 0.2, 0.9) love.graphics.line(s.reach) end
        for _, g in pairs(rec.grips) do
            if not g.joint:isDestroyed() then
                local ax, ay = g.joint:getAnchors()
                love.graphics.setColor(1, 0.5, 0.1, 1)
                love.graphics.circle('fill', ax, ay, 22)
            end
        end
    end
    love.graphics.pop()
end

return lib

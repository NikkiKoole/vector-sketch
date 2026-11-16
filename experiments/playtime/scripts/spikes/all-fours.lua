-- all-fours: any Mipo goes down on all fours and walks or trots like an animal (Nikki 2026-11-16: "could we
-- also have them go on 4 limbs ... so any old mipos can go animal and on all 4?"). The spike's reusable part,
-- loaded by scripts/spikes/allfours.playtime.lua (docs/ALL-FOURS.md).
--
-- Only facing a side (as sitting: a leg pointing at the camera can't be drawn in 2D). Down, its body tips to
-- lying, the arms are front legs (the shoulders swing like hips, limits off), the head is held looking ahead
-- by a motor in the neck (its own muscle off: the gaze sets it every frame and its neck limit held the body
-- back, as the rig zones' crawl found). Poses are KEEP_ANGLE targets (world degrees, 0 = hanging straight
-- down, + toward the screen's left) on soft, slow muscles. A Mipo with longer legs than arms keeps its back
-- high and its nose down (honest; 'level' evens it out).
-- Going: the four limbs step in a walk (one foot at a time: back left, front left, back right, front right)
-- or a trot (diagonal pairs), by how far it's come, not the clock; the feet push the torso toward the speed it
-- wants only while a foot or shin touches something (as the motor's honest push). Told to go the other way
-- it turns round: the body's muscle swings it over, rearing up on the way.
-- State per Mipo on the instance (inst._fours); the walk is held off meanwhile (mipoWalk.hold).
local mipoRegistry = require('src.mipo-registry')
local mipoActions = require('src.mipo-actions')
local mipoWalk = require('src.mipo-walk')
local mipoFacing = require('src.mipo-facing')
local characterManager = require('src.character-manager')
local contactTracker = require('src.physics.contact-tracker')

local lib = {}

lib.tuning = {
    kp = 30,         -- the pose muscles (KEEP_ANGLE kp; 10 held nothing once the hips were free)
    maxOmega = 6,    -- and how fast they may turn a part (rad/s)
    bodyKp = 90,     -- the body's own muscle, stronger: at the limbs' strength it pitched nose down walking
    bend = 88,       -- degrees the body tips over (90: lying level)
    level = 0,       -- 0: a body on longer legs than arms tips nose down (its back high), 1: level anyway
    maxTilt = 15,    -- degrees nose down at most (a short body on long legs came to ~25 and pitched over)
    look = 70,       -- degrees the neck turns the head back up, to look ahead
    stride = 24,     -- degrees each limb swings forward and back
    lift = 40,       -- degrees a knee (an elbow) bends as its foot swings forward
    legBend = 0.85,  -- the back legs bend (thigh forward, shin back, like a hind leg) to bring the hips down
                     -- toward the shoulders' height: 1 all the way, 0 straight (Nikki: "their legs need better
                     -- bending"); arms longer than the legs bend at the elbow the same way
    minBend = 18,    -- degrees every knee and elbow bends at least (straight looked stiff)
    cycle = 0.45,    -- heights it goes in one step cycle (all four feet once)
    speed = 0.6,     -- heights a second it wants, driven
    push = 0.4,      -- the most the feet push, of its weight
    trotSpeed = 1.6, -- a trot's speed against the walk's
}

lib.GAITS = {
    -- each limb's offset in the cycle, and how much of the cycle a foot is down (duty)
    walk = { duty = 0.7, offset = { lleg = 0, larm = 0.25, rleg = 0.5, rarm = 0.75 } },
    trot = { duty = 0.5, offset = { lleg = 0, rarm = 0, rleg = 0.5, larm = 0.5 } },
}

-- the part of each limb that stands on the floor
local ENDS = { lleg = 'lfoot', rleg = 'rfoot', larm = 'lhand', rarm = 'rhand' }

local LIMBS = {
    lleg = { 'luleg', 'llleg' }, rleg = { 'ruleg', 'rlleg' },
    larm = { 'luarm', 'llarm', 'lhand' }, rarm = { 'ruarm', 'rlarm', 'rhand' },
}

local function alive(body) return body ~= nil and not body:isDestroyed() end
local function aliveInst(inst)
    return inst and inst.parts and inst.parts.torso1 and alive(inst.parts.torso1.body)
end

local function parentOf(inst, name)
    for parentName, children in pairs(inst.childrenMap or {}) do
        for _, c in ipairs(children) do
            if c == name then return parentName end
        end
    end
end

local function jointTo(inst, name)
    local part, parent = inst.parts[name], inst.parts[parentOf(inst, name) or '']
    return part and parent and alive(part.body) and alive(parent.body)
        and mipoRegistry.jointBetween(parent.body, part.body, 'revolute') or nil
end

-- a part's KEEP_ANGLE to angle (degrees, world), its settings from before kept the first time
local function keep(inst, rec, name, angle, kp)
    kp = kp or lib.tuning.kp
    local part = inst.parts[name]
    if not (part and alive(part.body)) then return end
    local had = mipoActions.getKeepAngle(part)
    local b = mipoActions.ensureKeepAngle(part, angle, kp)
    if not b then return end
    if rec.saved[name] == nil then
        rec.saved[name] = had and { angle = b.angle, kp = b.kp, maxOmega = b.maxOmega, enabled = b.enabled }
            or { none = true }
    end
    b.angle, b.kp, b.maxOmega, b.enabled = angle, kp, lib.tuning.maxOmega, nil
end

-- the shoulders (elbows, wrists) free: their limits stop an arm about level (rig zones' freeShoulders); the
-- ankles, so a foot stays flat on the floor while its shin leans back (Nikki: "ankles need more freedom"); and
-- the hips: a thigh forward under a lying body folds the hip ~140 degrees, past a standing hip's limit, so the
-- legs stayed at it and dragged behind (Nikki: "its legs are dragging behind him")
local function freeArms(inst, rec)
    for _, name in ipairs({ 'luarm', 'ruarm', 'llarm', 'rlarm', 'lhand', 'rhand', 'lfoot', 'rfoot',
                            'luleg', 'ruleg' }) do
        local j = jointTo(inst, name)
        if j and rec.limits[j] == nil then
            rec.limits[j] = j:areLimitsEnabled()
            j:setLimitsEnabled(false)
        end
    end
end

-- the neck's motor holding the head at an angle to its parent (radians, within the neck's limits)
local function neckMotor(inst, rec, rel)
    local j = jointTo(inst, 'head')
    if not j then return end
    rec.motors[j] = true
    local want = rel
    if j:areLimitsEnabled() then want = math.max(j:getLowerLimit(), math.min(j:getUpperLimit(), want)) end
    j:setMotorEnabled(true)
    j:setMotorSpeed((want - j:getJointAngle()) * 8)
    j:setMaxMotorTorque(inst.parts.head.body:getMass() * 9.8 * love.physics.getMeter() * 400)
end

-- turned to face a side at once, the face drawn again with it (rig zones' face)
local function face(inst, dir)
    local want = dir > 0 and 'right' or 'left'
    if mipoFacing.get(inst) ~= want then characterManager.switchFacing(inst, want) end
    local a = mipoFacing.dir(inst) * mipoFacing.faceTurn
    inst._turnAngle, inst._bodyAngle, inst._headGoal, inst._turnGoal = a, a, nil, nil
    inst._home = want -- (stood up again it stays this way round)
    mipoFacing.applyFace(inst)
end

local function dist(ax, ay, bx, by) return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) end

-- how long its legs, arms and body are (world px), measured standing as it goes down
local function measure(inst)
    local function anchorOf(name)
        local j = jointTo(inst, name)
        if j then return j:getAnchors() end
    end
    local function bottomOf(name) -- a hand's or foot's centre
        local b = inst.parts[name] and inst.parts[name].body
        if not alive(b) then return nil end
        local x, y = b:getPosition()
        return x, y
    end
    local hx, hy = anchorOf('luleg')
    local sx, sy = anchorOf('luarm')
    local fx, fy = bottomOf('lfoot')
    local px, py = bottomOf('lhand')
    if not (hx and sx and fx and px) then return nil end
    return { leg = dist(hx, hy, fx, fy), arm = dist(sx, sy, px, py), body = math.max(1, dist(hx, hy, sx, sy)) }
end

function lib.isDown(inst) return inst._fours ~= nil end

-- down on all fours (facing its side, or right if it faced front)
function lib.down(inst, dir)
    if not aliveInst(inst) or inst._fours then return end
    dir = dir or mipoFacing.dir(inst)
    if dir == 0 then dir = 1 end
    face(inst, dir)
    local rec = {
        saved = {}, limits = {}, motors = {}, phase = 0, speed = 0, gait = 'walk',
        size = measure(inst), height = math.max(50, characterManager.mipoHeight(inst)),
        wasRagdoll = inst._isRagdoll or false,
        feet = {}, -- each foot's angle standing (degrees, as if facing right): held flat on the floor
    }
    for _, name in ipairs({ 'lfoot', 'rfoot' }) do
        local foot = inst.parts[name]
        if foot and alive(foot.body) then rec.feet[name] = math.deg(foot.body:getAngle()) * dir end
    end
    inst._fours = rec
    mipoWalk.hold(inst, true)
    inst._isRagdoll = true -- mipoActions' arm hang off (the legs keep their muscles), as the rig zones' arms
    freeArms(inst, rec)
end

-- up again: everything as it was, on its own muscles
function lib.up(inst)
    local rec = inst and inst._fours
    if not rec then return end
    for j in pairs(rec.motors) do
        if not j:isDestroyed() then j:setMotorEnabled(false) end
    end
    for name, was in pairs(rec.saved) do
        local b = mipoActions.getKeepAngle(inst.parts[name])
        if b then
            if was.none then b.enabled = false
            else b.angle, b.kp, b.maxOmega = was.angle, was.kp, was.maxOmega end
        end
    end
    for j, on in pairs(rec.limits) do
        if not j:isDestroyed() then j:setLimitsEnabled(on) end
    end
    inst._fours = nil
    inst._isRagdoll = rec.wasRagdoll or nil
    if aliveInst(inst) then mipoActions.wake(inst) end
    mipoWalk.hold(inst, false)
end

function lib.toggle(inst, dir)
    if lib.isDown(inst) then lib.up(inst) else lib.down(inst, dir) end
end

-- go at speed (heights a second, + right, - left; 0 or nil stands), in gait 'walk' or 'trot'
function lib.drive(inst, speed, gait)
    local rec = inst and inst._fours
    if not rec then return end
    rec.speed = speed or 0
    rec.gait = gait or rec.gait
end

local function smooth(v) return v * v * (3 - 2 * v) end

-- one limb's swing (degrees, + forward) and bend (degrees) at u in its cycle
local function limbPose(u, duty)
    local t = lib.tuning
    if u < duty then -- down: from forward to back, carrying the body
        return t.stride * (1 - 2 * u / duty), 0
    end
    local v = (u - duty) / (1 - duty) -- up: back to forward, the knee lifting it
    return -t.stride + 2 * t.stride * smooth(v), t.lift * math.sin(math.pi * v)
end

local function updateOne(inst, rec, dt)
    local t = lib.tuning
    local torso = inst.parts.torso1.body
    local d = mipoFacing.dir(inst)
    if d == 0 then d = 1 end
    -- told the other way: turn round (its body swings over on its muscle)
    if rec.speed ~= 0 and (rec.speed > 0 and 1 or -1) ~= d then
        face(inst, -d)
        d = -d
    end
    local H = rec.height
    local vx = torso:getLinearVelocity()
    local gait = lib.GAITS[rec.gait] or lib.GAITS.walk
    local want = rec.speed * H * (rec.gait == 'trot' and t.trotSpeed or 1)

    -- the steps go by how far it's come (and start before the body does)
    local going = math.max(math.abs(vx), math.abs(want) * 0.3)
    if rec.speed == 0 then going = math.abs(vx) end
    rec.phase = (rec.phase + going * dt / math.max(30, H * t.cycle)) % 1
    local amount = math.min(1, going / math.max(1, H * 0.15)) -- standing still: the limbs come to rest

    -- the knees (elbows) bent to bring the longer limbs down toward the shorter ones' height, and the body
    -- tipped nose down by what's left (unless level)
    local legBend, armBend, tilt = t.minBend, t.minBend, 0
    if rec.size then
        local leg, arm = rec.size.leg, rec.size.arm
        -- a limb bent by a at the top and back the other way below stands leg * cos(a) tall
        local function fit(long, short) return math.deg(math.acos(math.max(0, math.min(1, short / long)))) end
        if leg > arm then legBend = math.max(t.minBend, fit(leg, arm) * t.legBend)
        else armBend = math.max(t.minBend, fit(arm, leg) * t.legBend) end
        local effLeg = leg * math.cos(math.rad(legBend))
        local effArm = arm * math.cos(math.rad(armBend))
        tilt = math.deg(math.atan((effLeg - effArm) / rec.size.body)) * (1 - t.level)
        tilt = math.max(-t.maxTilt, math.min(t.maxTilt, tilt))
    end
    local bodyAngle = d * (t.bend + tilt)
    for i = 1, (inst.dna.creation.torsoSegments or 1) do keep(inst, rec, 'torso' .. i, bodyAngle, t.bodyKp) end

    -- the head looks ahead: its muscle off, the neck's motor holds it
    keep(inst, rec, 'head', 0)
    local hb = mipoActions.getKeepAngle(inst.parts.head)
    if hb then hb.enabled = false end
    neckMotor(inst, rec, math.rad(-d * t.look))

    -- the four limbs: thigh (upper arm) swings; standing, a back leg's thigh leans forward and its shin back
    -- (a hind leg's knee), a front leg's upper arm back and its forearm forward (an elbow behind); the foot
    -- swinging forward lifts on more bend
    local standing = {} -- the limbs down in the gait (all of them, standing still)
    for limb, parts in pairs(LIMBS) do
        local u = (rec.phase + gait.offset[limb]) % 1
        if u < gait.duty or amount < 0.2 then standing[#standing + 1] = ENDS[limb] end
        local swing, lift = limbPose(u, gait.duty)
        swing, lift = swing * amount, lift * amount
        local isArm = parts[3] ~= nil
        local bend = (isArm and armBend or legBend) + lift
        local fold = isArm and -1 or 1 -- a knee folds the shin back, an elbow the forearm forward
        local upper = -d * (swing + fold * (bend - lift * 0.5))
        local lower = upper + d * fold * 2 * (bend - lift * 0.5) + d * lift * 0.5 * fold
        keep(inst, rec, parts[1], upper)
        keep(inst, rec, parts[2], lower)
        if isArm then keep(inst, rec, parts[3], lower) end -- the hand, a paw on the floor
    end
    -- the feet flat, as they stood, whatever the shins do (the ankles free)
    for name, angle in pairs(rec.feet) do keep(inst, rec, name, d * angle) end

    -- the feet do the pushing (Nikki: "let the feet do the pushing"): toward the speed it wants, shared between
    -- the feet and hands that are down in the gait and touching something, at each one (the floor's push where
    -- it meets the floor). Pushed at the torso's middle the body pitched over its nose; this low, speeding up
    -- tips it back a little instead, as a real one
    if want ~= 0 or math.abs(vx) > 1 then
        local touching = {}
        for _, name in ipairs(standing) do
            local part = inst.parts[name]
            if part and alive(part.body) and contactTracker.any(part.body, function() return true end) then
                touching[#touching + 1] = part.body
            end
        end
        if #touching > 0 then
            local mass = mipoRegistry.totalMass(inst)
            local g = 9.8 * love.physics.getMeter()
            local most = t.push * mass * g
            local f = math.max(-most, math.min(most, (want - vx) * mass * 4)) / #touching
            for _, b in ipairs(touching) do
                local x, y = b:getPosition()
                b:applyForce(f, 0, x, y)
            end
        end
    end
end

-- every Mipo that's down, each frame (the scene calls it)
function lib.update(dt)
    for _, inst in pairs(mipoRegistry.getAll()) do
        local rec = inst._fours
        if rec then
            if aliveInst(inst) then updateOne(inst, rec, dt) else inst._fours = nil end
        end
    end
end

-- every Mipo up again (the scene's unload)
function lib.upAll()
    for _, inst in pairs(mipoRegistry.getAll()) do
        if inst._fours then lib.up(inst) end
    end
end

return lib

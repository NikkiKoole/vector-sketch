-- mipo-walk.lua — a Mipo turns (left / front / right) and walks when it's dragged along the floor,
-- every Mipo in every scene (docs/MIPO-FACING.md MF3, MF5, MF6; out of scripts/spikes/facing).
-- Run each frame by src/systems.lua (lib.update). Walking can be switched off per scene: the settings
-- panel's 'mipos' section, saved with the scene (lib.save / lib.load, scene-save / scene-load).
--
-- Turning: the body and the head turn separately. The body (feet, joint limits, draw order) switches
-- when its angle passes SWITCH_AT, so left -> right is two switches over front; it turns quickly. The
-- switch is in place (characterManager.switchFacing: only the turning foot and the ears are remade),
-- and the turning foot leans round: its picture tips toes up, is swapped for the new side's foot
-- leaning the other way, which comes down. The head (the face: mipoFacing.angle / applyFace, and the
-- idle gaze) turns as a keyed move (lib.headKeys, Nikki 2026-11-11: "weight, keyframe feel" instead
-- of the slow even drift): a small pull the other way, quick through the middle, past the side and
-- back (an ease-in-out with overshoot, lib.headBack) in lib.headTime a step. Off: the old drift,
-- HEAD_SPEED. Sometimes (lib.turnBlink) it blinks as it sets off, shut through the quick middle
-- (Nikki 2026-11-11: "do the blink on turn, sometimes"). The arms switch at their own moment, once
-- the head is lib.armAt of the way. Staggered (lib.stagger, Nikki 2026-11-11, MIPO-FACING MF7): the
-- switch spread over three moments instead of one frame: the ears go with the head (as it passes
-- lib.earAt of a step), the body and feet when the body switches, the arms lib.armLag after that.
-- Back home: a Mipo this module turned (arrows, a scene's turn, a walk) turns back to the facing it had
-- before (inst._home: as built, front for nearly all) once it has stood lib.relaxAfter seconds, not held
-- nor walking (Nikki 2026-11-11). Facing a scene sets itself (tracks, rides, soapbox) is left alone.
--
-- Walking: dragged sideways near the floor, a Mipo turns to face the way it's dragged (after a real
-- pull, not a nudge) and its leg muscles (KEEP_ANGLE targets) step: thighs swing in turn, the knee
-- bends on the swing forward, the steps going by how far it's dragged, not by the clock. No force of
-- its own: the finger moves it. A while after it stops, a Mipo the walk turned turns back to front.
-- Not while it's a ragdoll, flipped or dazed (src/mipo-actions.lua), nor a Mipo held off with
-- lib.hold(instance, true) (one a scene sits or seats: its legs are the scene's).
--
-- Per-Mipo state lives on the instance in `_` fields (not saved: a scene keeps dna.facing, a turn or
-- walk under way starts over).
local state = require('src.state')
local utils = require('src.utils')
local facing = require('src.mipo-facing')
local mipoActions = require('src.mipo-actions')
local mipoRegistry = require('src.mipo-registry')
local mipoFace = require('src.mipo-face')
local characterManager = require('src.character-manager')
local box2dPointerJoints = require('src.physics.box2d-pointerjoints')
local units = require('src.physics-units')

local lib = {}

-- the spike's switches, to compare (scripts/spikes/facing.playtime.lua's panel); the defaults are the
-- ones Nikki chose there. Every scene load puts them back (lib.load): set in the facing scene, 'turn
-- by itself' and 'rebuild whole' went on into the next scene and rebuilt the tracks spike's riders
-- out of their carts.
local SWITCHES = {
    armAt = 0.6,     -- the arms switch once the head is this far round (0: with the body, 1: at the end)
    lean = true,     -- the turning foot leans round (false: it flips)
    hop = false,     -- a little hop as the body switches, the swap in the air
    rebuild = false, -- switch by rebuilding the whole Mipo instead of in place
    auto = false,    -- turn back and forth by itself (a demo)
    headKeys = true, -- the head turns as a keyed move (false: the slow even drift, HEAD_SPEED)
    headTime = 0.3,  -- seconds the keyed head takes for one step (left -> right: two steps, ~1.4x)
    headBack = 1.7,  -- the keyed head's anticipation and overshoot (0: plain ease; 1.7 ~10% of a step)
    stagger = true,  -- ears with the head, body and feet, then the arms (false: ears with the body, arms by armAt)
    earAt = 0.5,     -- staggered: the ears switch once the head is this far through a step
    armLag = 0.1,    -- staggered: seconds after the body switches that the arms follow
    turnBlink = 0.5, -- the chance a keyed head turn blinks as it sets off (0: never, 1: always)
    relaxAfter = 3,  -- seconds standing before a turned Mipo turns back home (0: it stays turned)
    -- walking by itself (lib.drive, docs/MIPO-MOTOR.md)
    driveAccel = 1,    -- leg lengths a second^2: the most its feet speed it up or slow it down (was 4, then
                       -- 1.5, 2026-11-12; a firmer push drags the body and the standing foot skates along:
                       -- 2.5 slid it 66% of the body's speed, 1 with hipStrength 1 13%, spec/mipo-skate_spec)
    turningPace = 0.3, -- of its speed while it still faces the other way
    hopHeight = 0.35,  -- leg lengths a hop lifts it
    brakeFor = 1.2,    -- seconds its feet brake after it's told to stop
    pushAll = false,   -- the push on every part (by its mass) instead of all on the torso (tried: the same)
    upright = 0,       -- a torso muscle while it goes by itself (KEEP_ANGLE kp; tried 20: rocked more)
    walkLean = 6,      -- degrees the torso muscle leans it the way it goes
    hopCrouch = 0.1,   -- seconds crouched before a hop
    -- a weighty walk (MIPO-MOTOR MM8), walking by itself only: the standing knee gives just after
    -- contact and straightens to push off (the body bobs: contact, down, passing, up), the feet push
    -- in pulses at push-off, the arms swing against the legs
    weighty = true,
    give = 22,         -- degrees the standing knee bends at the down pose
    pulse = 0.6,       -- how much the push surges at push-off and eases between (0: an even push)
    armSwing = 25,     -- degrees each arm swings, with the other side's leg
    stanceGrip = 2,    -- the standing foot's grip walking by itself (gripping, the legs move it, not the push)
    keyed = true,      -- weighty: the legs go through keyed poses (WALK_KEYS) instead of a sine
    legMotors = true,  -- weighty: hip and knee motors hold the poses against the body's weight
    hipStrength = 1,   -- shares of the Mipo's weight held at a thigh's length (as mipo-stance's knees; was 0.6)
    kneeStrength = 0.5,
    motorGain = 12,    -- motor speed (rad/s) per radian off the pose
    swingStrength = 0.35, -- walking, the swinging leg's motors at this share of the standing leg's (LO13; a
                          -- skip's knee lift needs its full strength)
    swingMuscles = true, -- false: the swinging leg's KEEP_ANGLE muscles off (its motors alone move it; tried:
                         -- every Mipo floated more, bob doubled, so the muscles stay)
    -- walked into something (a wall, another Mipo): hardly getting anywhere for blockedAfter seconds, it
    -- stands facing it instead of stepping and pushing on the spot (legs walking, body still: it looked
    -- like floating, Nikki 2026-11-12: "if i keep left pressed 2 of the 3 end up floating while making
    -- walking movements"), and tries again after blockedRetry seconds (LO13)
    blockedAfter = 0.6,
    blockedRetry = 1.5,
    blockedSpeed = 0.15, -- of the speed it wants: slower than that is not getting anywhere
    tuckAfter = 0.3,   -- walking, seconds off the floor before the legs tuck (a jump, a fall)
    tuckFall = 99,     -- or sooner, once going down faster than this many leg lengths a second
    walkGlue = 0.2,    -- walking (the walk gait only), the weight's upward speed held to at most this many leg
                       -- lengths a second (0: off): a game's cheat against a walker lifting off its feet
    hopRest = 0.12,    -- seconds on the ground between hops
    -- SIMBICON (docs/MIPO-LOCOMOTION.md LO1), weighty keyed walking by itself: the torso held at a world
    -- angle (walkLean) by the standing hip, its torque taken off the standing thigh (nothing from
    -- outside); the swinging thigh aims further forward the faster it goes than it wants (placeV) and
    -- the further its centre is ahead of the standing ankle (placeD)
    torsoHold = 0.5,   -- the torso's stiffness: shares of its weight times a leg's length per radian (0: off)
    torsoDamp = 0,     -- its damping, in the same per (radian per sqrt(leg/g)) (0.5 tried: no better)
    placeV = 0.5,      -- radians the swing thigh aims forward per (speed too fast in sqrt(g*leg))
    placeD = 0,        -- radians per leg length its centre is ahead of the standing ankle
    torsoByMotor = true, -- torsoHold through the standing hip's motor (its aim: the torso at its angle);
                         -- false: as torques on torso and standing thigh (tried: the light thigh whips
                         -- forward to -98 degrees instead of the torso turning, tilt up to 108)
    footRoll = true,   -- keyed walk: the feet roll through the step (FOOT_KEYS): heel strike, plant, heel
                       -- off over the toes, following the shin on the swing, toes up before contact
    heelStrike = 18,   -- degrees the toes are up at contact (and reaching for it)
    toeOff = 30,       -- degrees the heel is up at toe-off
    footFollow = 0,    -- how much a swinging foot turns with its shin, on FOOT_KEYS' follow (1: toes down into
                       -- the floor mid swing, snagging, the foot turned 100-125 degrees; 0.4: one of 8 spec
                       -- Mipos didn't stop and two walked short; 0: every spec passes, the walk furthest)
    -- the jump as animation (LO8, Nikki 2026-11-12: "before a jump we have anticipation, you squat a little
    -- and then POING, jump!, learn from animation"): mipoActions.jump hands over to lib.jump
    animJump = true,   -- false: the old jump (legs limp 0.1 s, one impulse on the torso)
    jumpCrouch = 0.24, -- seconds sinking into the squat (eased in: slow into the lowest point)
    jumpHold = 0.05,   -- seconds held at the bottom (the moment before)
    jumpDepth = 1,     -- how deep the squat goes (1: thighs 50 deg forward, knees 95 bent)
    jumpPush = 0.08,   -- seconds the legs push off (the lift spread over it, while a foot touches)
    jumpHeight = 1.3,  -- leg lengths it lifts (0: mipoActions.jumpSpeed, the old fixed speed)
    jumpLand = 0.22,   -- seconds the knees give on landing and come back
    -- stopping and turning round (LO4): told to stop, a walking Mipo takes a step to where its momentum
    -- would carry it (the capture point), plants, and settles; told to go back, it stops that way,
    -- turns on the spot, dips and goes
    stopStep = true,   -- false: the old stop (legs straight, the feet braking brakeFor seconds)
    stopStepTime = 0.26, -- seconds the stopping step takes (lift, reach, plant)
    closeTime = 0.24,  -- seconds the back foot takes to step up beside the front one (lifted, not slid)
    settleTime = 0.4,  -- seconds settling after: knees give, torso and arms follow through
    stopBrake = 4,     -- the feet's braking push during the stopping step (times driveAccel; 0: the planted leg
                       -- alone: went 0.9 legs, still after 1.8 s; 4 from the start: 0.5 legs, 1.6 s)
    stopBrakeFrom = 0, -- how far into the step the braking starts (0: at once; 0.8, once the foot's down: 0.8 legs)
    stopReach = 0.75,  -- the stopping step's longest reach (leg lengths forward of the hip; 0.9: seed 11 walked short
                       -- in spec/mipo-motor_spec, 0.75: seed 4 stops in 1.56 legs, from its 2.1 legs/s)
    stopGrip = 3,      -- the planted feet's grip while stopping (1 or 6: the same)
    turnFirst = true,  -- going the other way: stop, turn on the spot, then go (false: turn while walking).
                       -- Walking only: a hop turning as it goes doesn't moonwalk (and a single hop facing
                       -- front, made to turn first, didn't hop once, spec/mipo-motor_spec)
    setOff = 0.16,     -- seconds dipping before it sets off once it faces its way
    -- LO3, steps by distance: the walk's steps go at the body's own speed, between gaitFloor and gaitCap
    -- times the speed it wants. Was 0.6 and 1.3 (a runaway's cap); 0.2 and 1: the same drift, less
    -- tilt (mean 18 -> 14, worst 27 -> 22 degrees), every spec passing
    gaitCap = 1,       -- at most this times the speed it wants (the body may go faster: faster legs ran away)
    gaitFloor = 0.2,   -- at least this times it (so it starts stepping before the body moves)
    -- LO3: the standing leg aims where its foot landed (two-bone IK on the thigh and shin's lengths)
    -- instead of the keyed pose, so the motors don't push a planted foot along. 0: keyed, 1: all IK.
    -- tried 2026-11-12 (off): 1 drifts less (27% -> 17% of the body's way) but walks a third slower and
    -- tilts more; the legs don't drive the body (a gentler push with leadByWant: half as far); a firmer
    -- push drags the foot again (40%); lockUntil (the keyed push-off back at the stance's end): 25-31%
    footLock = 0,
    footLead = 0.06,   -- footLock: seconds ahead the hip is aimed from (the body's speed times it)
    lockUntil = 1,     -- footLock: until where in the stance it holds (u, 0 contact .. 0.5 toe-off);
                       -- after it the keyed push-off takes over again (1: the whole stance)
    leadByWant = false, -- footLock: the hip led by the speed it wants, not the one it has (the leg drives it)
    -- the recovery step (LO4b): a standing Mipo whose capture point leaves its feet steps there
    recoverStep = true,
    recoverSpeed = 0.6,  -- leg lengths a second it must be moving (sways under it don't step)
    recoverMargin = 0.2, -- leg lengths past its outer feet the capture point must be (0.4: the same)
    recoverTime = 0.15,  -- seconds the catching step takes; the other foot follows in as long (0.22: went
                         -- further; spec/mipo-recover_spec, bumped Mipos never fell, with or without it)
    recoverCalm = 0.4,   -- seconds standing (not walking, squatting, jumping) before it may step
    recoverBrake = 4,    -- the feet's braking push once the step is down (times driveAccel; 0: the step alone,
                         -- went 0.78 legs from a soft bump, 4: 0.47; with no step at all it slides 0.36)
    -- hop, step and jump (lib.tripleJump, the spike's t): the run-up's seconds, each part's height (leg lengths)
    tripleRunUp = 1.2,
    tripleHop = 0.35,
    tripleStep = 0.3,
    tripleJumpHeight = 0.45,
    -- hopscotch (lib.hopscotch, the spike's k): one hop's height and length (leg lengths), a two-feet
    -- landing's and the turn's height, how long a landing gives (and loads the next push)
    hopscotchHop = 0.28, -- (0.22: the tucked foot touched more; 0.34: worse again)
    hopscotchLength = 0.55,
    hopscotchTwo = 0.26,
    hopscotchTurn = 0.34,
    hopscotchGive = 0.14,
    hopscotchTuck = -15, -- degrees the free leg's thigh is forward of straight down (-: behind)
    -- the squat (lib.squat, the spike's down key)
    squatTime = 0.25,  -- seconds into the squat (and out)
    squatDepth = 1,    -- as jumpDepth: 1 thighs 50 degrees forward, knees 95 bent
    stepTurn = true,   -- turning on the spot (turnFirst): each foot lifts as it turns round and comes down
                       -- facing the new way (Nikki 2026-11-12: "sometimes the feet quickly turn twice":
                       -- right -> front -> left flipped one foot, then the other, in place)
    stepTurnTime = 0.15, -- seconds each half of a stepping foot's turn (up and round, then down; else 0.12 / 0.16;
                       -- 0.2 left 3 of 8 Mipos swaying long after a stop)
    stepTurnLift = 1,  -- how high the turning foot lifts (1: the knee 60 degrees)
    stancePose = 1,    -- torsoByMotor: the standing hip also holds the thigh's pose (0: the torso only: skated)
    freeStance = true, -- torque torsoHold: the standing hip's motor and muscle off (SIMBICON: that hip is the torso's)
}
for k, v in pairs(SWITCHES) do lib[k] = v end

-- a gait with legs that step: walk, jog, run (lib.gaits), not a hop
local function stepGait(mode) return mode ~= nil and mode ~= 'hop' end
lib.stepGait = stepGait

local BODY_SPEED = math.rad(120) -- a second
local WALK_TURN_SPEED = 0.6 -- a turn the walk makes (or relaxing back to front): of BODY_SPEED
local HEAD_SPEED = math.rad(30)  -- a second: left -> right (60 degrees) in 2 s (lib.headKeys off)
local HEAD_SLOW = 1.6            -- a keyed head relaxing back to front (a turn the walk made) takes longer
local SWITCH_AT = math.rad(15)
local AUTO_HOLD = 1.2            -- seconds a turning-by-itself Mipo stays put at a side
local STEPS = { left = -1, front = 0, right = 1 }
local SIDE_OF = { [-1] = 'left', [0] = 'front', [1] = 'right' }
local HOP_SPEED = 450 -- world units a second at 100 px per metre (a jump is 1200)
local HOP_WAIT = 0.25 -- seconds: switch anyway if it hasn't left the ground by then
local LEAN = 0.5      -- of the way from its rest to pointing straight up
local LEAN_OUT = 0.12 -- seconds lifting the old foot's toes
local LEAN_IN = 0.16  -- seconds the new foot takes to come down

local STRIDE = 28          -- degrees each thigh swings forward and back
local KNEE = 55            -- degrees the knee bends on the swing forward
local WALK_SPEED = 0.25    -- leg lengths a second: slower than that it stands
-- Turning round takes a real pull (Nikki: no fidgety switching when just pressing it down): dragged
-- one way TURN_DISTANCE leg lengths in all, for TURN_TIME at least. Back the other way starts over,
-- held still it fades (PULL_FADE a second).
local TURN_DISTANCE = 0.7  -- leg lengths
local TURN_TIME = 0.3      -- seconds
local PULL_FADE = 1.5      -- 1/s
local GROUND_GRACE = 0.3   -- seconds after a foot last touched that it still counts as on the floor
local RELAX_AFTER = 1.2    -- seconds after it stopped walking that a walked-round Mipo turns back
local MAX_STEPS = 2.5      -- steps a second at most: dragged faster, it takes longer strides
local MAX_STRIDE = 48      -- degrees: the longest stride
-- Foot grip while walking: feet that grip the floor held the legs back, trailing, and tipped the
-- torso into the drag (2026-11-06). The swinging foot hardly grips, the standing one half.
local SWING_GRIP = 0.05
local STANCE_GRIP = 0.5
-- Feet flat while walking: on their ankles' few degrees the feet turned with the shins, toes into the
-- floor, and the swing jammed there. While walking the ankles bend freely and a muscle holds each foot
-- flat, its toes this much up on the swing.
local TOES_UP = 12 -- degrees
-- Hips: facing a side they only swing forward (for sitting), so a walking thigh couldn't swing back
-- behind the body. While walking they get this much room behind.
local HIP_BACK = math.rad(35)
local FEET = { 'lfoot', 'rfoot' }
local LEG_PAIRS = { { 'luleg', 'llleg' }, { 'ruleg', 'rlleg' } }
local REMADE = { 'lfoot', 'rfoot', 'lear', 'rear' } -- what an in-place switch remakes

---------------------------------------------------------------- the scene's setting

local function settings()
    state.mipoWalk = state.mipoWalk or { walk = true }
    return state.mipoWalk
end
lib.settings = settings

-- walking on in this scene (turning asked for by a scene works either way)
function lib.isOn() return settings().walk ~= false end

-- from a scene file (nil: on); the spike's switches back to their defaults
function lib.load(saved)
    state.mipoWalk = { walk = not (saved and saved.walk == false) }
    for k, v in pairs(SWITCHES) do lib[k] = v end
end

-- for a scene file: nothing when it's on, so files stay as they were
function lib.save()
    if lib.isOn() then return nil end
    return { walk = false }
end

-- the settings panel's rows (src/ui/world-settings.lua, src/ui/inspector.lua)
lib.rows = {
    { key = 'walk when dragged', kind = 'bool',
      get = function(s) return s.walk ~= false end,
      set = function(s, v) s.walk = v and true or false end },
}

-- a scene's own legs: a Mipo it sits or seats doesn't walk (on: true / false)
function lib.hold(instance, on) instance._noWalk = on or nil end

-- Walking by itself (docs/MIPO-MOTOR.md): speed in leg lengths a second, + right, - left; 0 or nil
-- stands. mode 'walk' (steps, the default) or 'hop' (both feet together, little hops). It turns to
-- face the way it goes; its feet push it, only while one touches something (nothing holds it up or
-- carries it in the air). A hand on it wins.
function lib.drive(inst, speed, mode)
    inst._stepsLeft, inst._hopsLeft, inst._gaitFrom = nil, nil, nil
    local was, wasMode = inst._drive, inst._driveMode
    -- a walk stopping, or turning back: the stopping step (LO4) while it walks on the floor
    local stepping = lib.stopStep and was and stepGait(wasMode) and inst._walking and not inst._jump
        and not inst._stop and (inst._goAt == nil or love.timer.getTime() - inst._goAt > lib.setOff)
    if speed and speed ~= 0 then
        if was and was * speed < 0 then inst._blockedAt, inst._slowFor = nil, 0 end -- the other way: not blocked
        if stepping and was * speed < 0 then inst._stop = { at = love.timer.getTime(), phase = 'step' } end
        inst._drive, inst._driveMode = speed, mode or 'walk'
    else
        if stepping then
            inst._stop = { at = love.timer.getTime(), phase = 'step' }
        elseif inst._drive then
            inst._brakeUntil = love.timer.getTime() + lib.brakeFor
        end
        inst._drive, inst._driveMode = nil, nil
        inst._blockedAt, inst._slowFor = nil, 0
    end
end
function lib.blocked(inst) return inst._blockedAt ~= nil end
function lib.driving(inst) return inst._drive, inst._driveMode end

-- one go, then it stops: n steps (counted once it faces its way), or one hop
function lib.steps(inst, speed, n)
    lib.drive(inst, speed, 'walk')
    inst._stepsLeft = n or 1
end
function lib.hopOnce(inst, speed)
    lib.drive(inst, speed, 'hop')
    inst._hopsLeft = 1
end

---------------------------------------------------------------- helpers

local function alive(inst)
    local torso = inst and inst.parts and inst.parts.torso1
    return torso and torso.body and not torso.body:isDestroyed()
end

local function partBody(inst, name)
    local part = inst.parts[name]
    return part and part.body and not part.body:isDestroyed() and part.body or nil
end

-- where a joint between parent and part sits (hip, knee)
local function jointPoint(inst, parentName, partName)
    local body, parent = partBody(inst, partName), partBody(inst, parentName)
    if not (body and parent) then return nil end
    for _, joint in ipairs(body:getJoints()) do
        local a, b = joint:getBodies()
        if a == parent and b == body then
            local x, y = joint:getAnchors()
            return x, y
        end
    end
end

-- the joint between a part and its parent (revolute)
local function jointTo(inst, parentName, partName)
    local body, parent = partBody(inst, partName), partBody(inst, parentName)
    if not (body and parent) then return nil end
    for _, joint in ipairs(body:getJoints()) do
        local a, b = joint:getBodies()
        if a == parent and b == body and joint:getType() == 'revolute' then return joint end
    end
end

-- the ankle's joint (shin -> foot)
local function ankleOf(inst, footName)
    local body = partBody(inst, footName)
    if not body then return nil end
    for _, joint in ipairs(body:getJoints()) do
        local _, b = joint:getBodies()
        if b == body and joint:getType() == 'revolute' then return joint end
    end
end

-- a finger holds one of these parts (or, names nil, any part of the Mipo)
local function held(inst, names)
    local attached = box2dPointerJoints.getPointerJointAttachedTo
    if names then
        for _, n in ipairs(names) do
            local body = partBody(inst, n)
            if body and attached(body) then return true end
        end
        return false
    end
    for _, part in pairs(inst.parts) do
        if part.body and not part.body:isDestroyed() and attached(part.body) then return true end
    end
    return false
end

local function approach(value, target, step)
    if math.abs(target - value) <= step then return target end
    return value + (target > value and step or -step)
end

-- ease in and out with a pull back first and an overshoot at the end (u 0..1); back 0 is a plain ease
local function easeBack(u, back)
    local c = back * 1.525
    if u < 0.5 then
        local t = 2 * u
        return t * t * ((c + 1) * t - c) / 2
    end
    local t = 2 * u - 2
    return (t * t * ((c + 1) * t + c) + 2) / 2
end

-- a blink as a keyed head turn sets off, shut through its quick middle (the eyes are on the head, or
-- on the torso of a Mipo without one)
local function blinkOnTurn(inst, dur)
    local face = partBody(inst, 'head') or partBody(inst, 'torso1')
    local thing = face and utils.thingOf(face)
    if thing then mipoFace.blink(thing, math.max(0, dur * 0.5 - 0.08)) end
end

-- the head's angle this frame as a keyed move toward target: restarts from where it is when the target
-- changes; true once it has arrived
local function keyHead(inst, target, dt)
    local key = inst._headKey
    if not key or key.to ~= target then
        local from = inst._turnAngle or facing.angle(inst)
        local steps = math.max(0.5, math.abs(target - from) / facing.faceTurn)
        key = { from = from, to = target, t = 0,
            dur = lib.headTime * math.sqrt(steps) * (inst._slowTurn and HEAD_SLOW or 1) }
        inst._headKey = key
        if math.random() < lib.turnBlink then blinkOnTurn(inst, key.dur) end
    end
    key.t = key.t + dt
    local u = math.min(1, key.t / math.max(key.dur, 0.01))
    inst._turnAngle = key.from + (key.to - key.from) * easeBack(u, lib.headBack)
    if u < 1 then return false end
    inst._turnAngle, inst._headKey = target, nil
    return true
end

local function facingAt(angle)
    if angle <= -SWITCH_AT then return 'left' end
    if angle >= SWITCH_AT then return 'right' end
    return 'front'
end

local function stepFrom(side, dir)
    return SIDE_OF[math.max(-1, math.min(1, (STEPS[side] or 0) + dir))]
end

---------------------------------------------------------------- turning

-- the head's side now: where it is going, else the nearest of the three
local function headSide(inst)
    if inst._headGoal then return inst._headGoal end
    local a = facing.angle(inst) / facing.faceTurn
    return a <= -0.5 and 'left' or a >= 0.5 and 'right' or 'front'
end

-- the facing to come back to, kept from before the first turn this module makes
local function keepHome(inst)
    inst._home = inst._home or facing.get(inst)
    inst._settledAt = nil
end

-- the head a step round (dir -1 left, 1 right), the body staying
function lib.turnHead(inst, dir)
    keepHome(inst)
    inst._turnAngle = inst._turnAngle or facing.angle(inst)
    inst._headGoal = stepFrom(headSide(inst), dir)
end

-- the body a step round (the head stays unless turned too: lib.turn)
function lib.turnBody(inst, dir)
    keepHome(inst)
    inst._bodyAngle = inst._bodyAngle or facing.dir(inst) * facing.faceTurn
    inst._turnGoal = stepFrom(inst._turnGoal or facing.get(inst), dir)
end

-- body and head a step round
function lib.turn(inst, dir)
    lib.turnBody(inst, dir)
    lib.turnHead(inst, dir)
end

-- body and head on their way to a side; slow: the body at WALK_TURN_SPEED
function lib.turnTo(inst, side, slow)
    if inst._turnGoal == side and inst._headGoal == side then return end
    keepHome(inst)
    inst._slowTurn = slow
    inst._bodyAngle = inst._bodyAngle or facing.dir(inst) * facing.faceTurn
    inst._turnAngle = inst._turnAngle or facing.angle(inst)
    inst._turnGoal, inst._headGoal = side, side
end

-- a turn under way (body or head)
function lib.isTurning(inst) return inst._turnGoal ~= nil or inst._headGoal ~= nil end

-- turning by itself (lib.auto): back and forth, a step at a time, once body and head have arrived
local function autoTurn(inst, now)
    if inst._turnGoal or inst._headGoal or now < (inst._turnHoldUntil or 0) then return end
    inst._turnBack = inst._turnBack or (facing.dir(inst) >= 0 and -1 or 1)
    local here = STEPS[facing.get(inst)]
    if here + inst._turnBack < -1 or here + inst._turnBack > 1 then inst._turnBack = -inst._turnBack end
    lib.turn(inst, inst._turnBack)
end

local function hop(inst)
    local body = partBody(inst, 'torso1')
    if not body then return end
    local speed = HOP_SPEED * love.physics.getMeter() / 100
    body:applyLinearImpulse(0, -mipoRegistry.totalMass(inst) * speed)
end

-- a foot's rest angle on its shin, by the side's foot it takes (character-topology angleOffset)
local function footOffset(inst, footName)
    return facing.source(inst, footName) == 'lfoot' and math.pi / 2 or -math.pi / 2
end

-- the foot whose side changes when the body goes to want (one per step)
local function turningFoot(inst, want)
    local was, before, name = inst.dna.facing, {}, nil
    for _, n in ipairs(FEET) do before[n] = facing.source(inst, n) end
    inst.dna.facing = want
    for _, n in ipairs(FEET) do
        if facing.source(inst, n) ~= before[n] then name = n end
    end
    inst.dna.facing = was
    return name
end

-- the foot's picture, with its ankle as the point it leans about
local function footPicture(inst, footName)
    local joint = ankleOf(inst, footName)
    if not joint then return nil end
    local body = inst.parts[footName].body
    for _, fixture in ipairs(body:getFixtures()) do
        local ud = fixture:getUserData()
        if ud and ud.subtype == 'texfixture' and ud.extra then
            local _, _, ax, ay = joint:getAnchors()
            ud.extra.leanPivotX, ud.extra.leanPivotY = body:getLocalPoint(ax, ay)
            return ud.extra
        end
    end
end

-- a held Mipo can't be rebuilt whole (its bodies go), and not in place while a remade part is held
local function switchBlocked(inst)
    if lib.rebuild then return held(inst) end
    return held(inst, REMADE)
end

local function doSwitch(inst, want)
    inst.dna.armFacing = facing.armFacing(inst) -- the arms keep theirs until updateArms moves them
    -- staggered, the ears keep theirs too (updateEars moves them with the head); else they go now
    inst.dna.earFacing = lib.stagger and facing.earFacing(inst) or nil
    inst._bodySwitchedAt = love.timer.getTime()
    if lib.rebuild then -- the whole Mipo made again (to compare)
        inst.dna.facing = want
        characterManager.rebuildFromCreation(inst, {}) -- its textures turn the face by _turnAngle
    else -- in place: only the turning foot and the ears remade
        characterManager.switchFacing(inst, want)
    end
end

local function updateLean(inst, dt)
    local L = inst._lean
    local picture = footPicture(inst, L.foot)
    if not picture then inst._lean = nil return end
    L.t = L.t + dt
    local dur = L.phase == 'out' and LEAN_OUT or LEAN_IN
    if L.step then dur = lib.stepTurnTime end
    local k = math.min(1, L.t / dur)
    local e = k * k * (3 - 2 * k)
    -- a step-turn's foot turns in the air, at the top of its lift: no lean (the lean flapped the foot
    -- up and down at each of the two switches, Nikki 2026-11-12: "the foot facing me flaps twice")
    picture.leanAngle = (not L.step) and (L.start + (L.goal - L.start) * e) or nil
    if k < 1 then return end
    if L.phase == 'out' then
        if switchBlocked(inst) then return end
        doSwitch(inst, L.want) -- remakes the foot (and its picture)
        local newPicture = footPicture(inst, L.foot)
        if not newPicture then inst._lean = nil return end
        -- the new foot leaning as far as the old one did, the other way, then down
        local lean = footOffset(inst, L.foot) * LEAN
        newPicture.leanAngle = (not L.step) and lean or nil
        L.phase, L.t, L.start, L.goal = 'in', 0, lean, 0
    else
        picture.leanAngle = nil
        inst._lean = nil
    end
end

-- the body's switch: now, or (hopping) once it is in the air, or (leaning) once its foot tipped
local function switchBody(inst, want, now)
    -- not while held there: the switch would pull bodies out from under the finger
    if switchBlocked(inst) or inst._lean then return false end
    if lib.hop then
        if not inst._hopAt then
            hop(inst)
            inst._hopAt = now
            return false
        end
        if mipoActions.isGrounded(inst) and now - inst._hopAt < HOP_WAIT then return false end
    end
    inst._hopAt = nil
    if lib.lean and not lib.rebuild then
        local foot = turningFoot(inst, want)
        if foot and footPicture(inst, foot) then
            inst._lean = { foot = foot, want = want, phase = 'out', t = 0,
                start = 0, goal = footOffset(inst, foot) * LEAN, -- toes up
                -- a step-turn (lib.stepTurn): the leg lifts it; a Mipo walking by itself (the flag alone
                -- missed the first foot, set a frame late: that foot still flapped)
                step = inst._stepTurning or (lib.stepTurn and lib.turnFirst and inst._drive ~= nil
                    and stepGait(inst._driveMode)) or nil }
            return false
        end
    end
    doSwitch(inst, want)
    return true
end

-- The arms (limits, draw order) follow the body's facing at their own moment: once the head is
-- lib.armAt of the way there (staggered: lib.armLag after the body switched). Turning only the head
-- leaves them with the body.
local function updateArms(inst, now)
    local body, arms = facing.get(inst), facing.armFacing(inst)
    if body == arms then return end
    if lib.stagger then
        if now - (inst._bodySwitchedAt or 0) >= lib.armLag then characterManager.switchArms(inst, body) end
        return
    end
    local ratio = facing.angle(inst) / facing.faceTurn -- the head: -1 left .. 1 right
    local at = lib.armAt
    local ready
    if body == 'right' then ready = ratio >= at
    elseif body == 'left' then ready = ratio <= -at
    else ready = math.abs(ratio) <= 1 - at end
    if ready or not inst._headGoal then characterManager.switchArms(inst, body) end
end

-- Staggered, the ears go with the head: the side it is past lib.earAt of a step toward. Only for a
-- Mipo this module turns (a scene that sets facing itself keeps its ears with the body). Not while an
-- ear is held (it is remade).
local EARS = { 'lear', 'rear' }
local function updateEars(inst)
    if not (inst._headGoal or inst._turnGoal or inst.dna.earFacing) then return end
    if not lib.stagger then
        if inst.dna.earFacing and not held(inst, EARS) then characterManager.switchEars(inst, nil) end
        return
    end
    local ratio = facing.angle(inst) / facing.faceTurn
    local side = ratio >= lib.earAt and 'right' or ratio <= -lib.earAt and 'left' or 'front'
    if side ~= facing.earFacing(inst) and not held(inst, EARS) then characterManager.switchEars(inst, side) end
    -- turned and settled with the body: back to following it
    if not (inst._headGoal or inst._turnGoal) and facing.earFacing(inst) == facing.get(inst) then
        inst.dna.earFacing = nil
    end
end

local function updateTurn(inst, dt, now)
    if lib.auto then autoTurn(inst, now) end
    local rebuilt = false
    if inst._lean then updateLean(inst, dt) end
    if not alive(inst) then return end
    if inst._turnGoal then
        local target = STEPS[inst._turnGoal] * facing.faceTurn
        local speed = BODY_SPEED * (inst._slowTurn and WALK_TURN_SPEED or 1)
        inst._bodyAngle = approach(inst._bodyAngle or facing.dir(inst) * facing.faceTurn, target, speed * dt)
        local want = facingAt(inst._bodyAngle)
        if want ~= facing.get(inst) then rebuilt = switchBody(inst, want, now) end
        if inst._bodyAngle == target and want == facing.get(inst) then inst._turnGoal, inst._slowTurn = nil, nil end
    end
    if inst._headGoal then
        local target = STEPS[inst._headGoal] * facing.faceTurn
        local arrived
        if lib.headKeys then
            arrived = keyHead(inst, target, dt)
        else
            inst._headKey = nil
            inst._turnAngle = approach(inst._turnAngle or facing.angle(inst), target, HEAD_SPEED * dt)
            arrived = inst._turnAngle == target
        end
        if not rebuilt then facing.applyFace(inst) end
        if arrived then
            inst._headGoal = nil
            -- turning by itself: a while at a side, through the front without stopping
            inst._turnHoldUntil = now + ((lib.auto and target ~= 0) and AUTO_HOLD or 0)
        end
    end
    updateArms(inst, now)
    updateEars(inst)
end

-- back home after standing a while (lib.relaxAfter): not while turning, held, walking or held off
local function updateRelax(inst, now)
    if not inst._home or lib.auto or lib.relaxAfter <= 0 then return end
    if inst._turnGoal or inst._headGoal or inst._walking or inst._noWalk or held(inst) then
        inst._settledAt = nil
        return
    end
    inst._settledAt = inst._settledAt or now
    if now - inst._settledAt < lib.relaxAfter then return end
    local home = inst._home
    if facing.get(inst) == home and headSide(inst) == home then
        inst._home, inst._settledAt = nil, nil -- home: nothing left to come back to
    else
        lib.turnTo(inst, home, true)
    end
end

---------------------------------------------------------------- walking

local function setLegTargets(inst, thigh, shin)
    for _, leg in ipairs(LEG_PAIRS) do
        local upper = mipoActions.ensureKeepAngle(inst.parts[leg[1]], 0, 40)
        local lower = mipoActions.ensureKeepAngle(inst.parts[leg[2]], 0, 40)
        if upper then upper.angle, upper.enabled = thigh, nil end
        if lower then lower.angle, lower.enabled = shin, nil end
    end
end

-- feet flat (face: 1 right, -1 left, toesUp per foot) or, face nil, back to their ankles' range
-- angles (optional, per foot): world degrees for the muscle instead (the foot's roll, footKeys)
local function holdFeet(inst, face, toesUp, angles)
    for i, footName in ipairs(FEET) do
        local ankle = ankleOf(inst, footName)
        if ankle then ankle:setLimitsEnabled(face == nil) end
        local b = mipoActions.ensureKeepAngle(inst.parts[footName], 0, 40)
        if b then
            if face and angles and angles[i] then
                b.angle, b.enabled = angles[i], nil
            elseif face then
                b.angle, b.enabled = -face * (90 + (toesUp[i] and TOES_UP or 0)), nil
            else
                b.enabled = false
            end
        end
    end
end

-- hips with room behind (face 1 / -1), or face nil: their limits as the facing set them. The facing's
-- limits are remembered per facing: a turn mid-walk sets new ones (switchFacing).
local function hipsBack(inst, face)
    inst._hipBase = inst._hipBase or {}
    local key = facing.get(inst)
    for _, leg in ipairs({ 'luleg', 'ruleg' }) do
        local joint = jointTo(inst, 'torso1', leg)
        if joint then
            local base = inst._hipBase[leg]
            if not base or base.facing ~= key or base.joint ~= joint then
                local lo, up = joint:getLimits()
                base = { facing = key, joint = joint, lo = lo, up = up }
                inst._hipBase[leg] = base
            end
            if face == 1 then joint:setLimits(base.lo, base.up + HIP_BACK)
            elseif face == -1 then joint:setLimits(base.lo - HIP_BACK, base.up)
            else joint:setLimits(base.lo, base.up) end
        end
    end
end

local function setGrip(inst, footName, friction)
    local body = partBody(inst, footName)
    if not body then return end
    for _, fixture in ipairs(body:getFixtures()) do
        if not fixture:isSensor() then fixture:setFriction(friction) end
    end
end

local function legLength(inst)
    local hx, hy = jointPoint(inst, 'torso1', 'luleg')
    local ax, ay = jointPoint(inst, 'llleg', 'lfoot')
    if not (hx and ax) then return nil end
    return math.sqrt((ax - hx) ^ 2 + (ay - hy) ^ 2)
end

local TWO_PI = 2 * math.pi

-- The walk's keys (MIPO-MOTOR MM8, Nikki: "as in animation"): one leg's cycle from its contact (t 0..1;
-- the other leg half a cycle later), the thigh forward as a share of the stride's swing (- is back),
-- the knee's bend in degrees ('give': lib.give). Through them a smooth curve (Catmull-Rom), so it moves
-- through the poses without stopping at each; the spacing is the timing.
local WALK_KEYS = {
    { t = 0.00, fwd = 1.00, knee = 5 },      -- contact: the heel down, the leg reaching
    { t = 0.12, fwd = 0.55, knee = 'give' }, -- down: the weight lands, the knee gives
    { t = 0.28, fwd = 0.00, knee = 2 },      -- passing: straight under the body, the up
    { t = 0.42, fwd = -0.75, knee = 0 },     -- push-off
    { t = 0.52, fwd = -1.00, knee = 25 },    -- toe-off
    { t = 0.68, fwd = -0.20, knee = 75 },    -- the swing: the foot lifted, passing
    { t = 0.86, fwd = 0.95, knee = 25 },     -- reaching for the next contact
}

-- A jog and a run (Nikki 2026-11-12: "reminded about the old prince of persia game, can we make a walk,
-- jog, run"), keyed in the same step time as the walk (0 contact, 0.5 the stance's end: lib.gaits'
-- duty squeezes the stance into its share of the cycle): more knee at the down pose, the heel kicked
-- up behind after toe-off, the knee driving forward, the leg reaching. Knees stop at 90 (the joints).
local JOG_KEYS = {
    { t = 0.00, fwd = 0.90, knee = 15 },  -- contact
    { t = 0.14, fwd = 0.45, knee = 35 },  -- down
    { t = 0.28, fwd = 0.00, knee = 20 },  -- passing
    { t = 0.42, fwd = -0.80, knee = 8 },  -- push-off
    { t = 0.52, fwd = -1.00, knee = 30 }, -- toe-off
    { t = 0.66, fwd = -0.40, knee = 85 }, -- the heel up behind
    { t = 0.80, fwd = 0.70, knee = 75 },  -- the knee forward
    { t = 0.92, fwd = 1.00, knee = 30 },  -- reaching
}
local RUN_KEYS = {
    { t = 0.00, fwd = 0.85, knee = 20 },  -- contact
    { t = 0.14, fwd = 0.40, knee = 45 },  -- down: the weight lands, deep
    { t = 0.28, fwd = 0.00, knee = 30 },  -- passing
    { t = 0.42, fwd = -0.85, knee = 8 },  -- push-off: the leg straight behind
    { t = 0.52, fwd = -1.00, knee = 35 }, -- toe-off
    { t = 0.64, fwd = -0.50, knee = 90 }, -- the heel kicked up to the bottom
    { t = 0.78, fwd = 0.85, knee = 85 },  -- the knee driving forward, high
    { t = 0.90, fwd = 1.05, knee = 40 },  -- reaching for the ground
}

-- Skipping, the way small children go (Nikki 2026-11-12: "hop with one leg, the way small children do, hop
-- one leg then the other"): a step onto a foot, a hop on it, a step onto the other, a hop on that. One
-- leg's cycle; the thigh in degrees forward (lib.gaits.skip.deg: a knee lift isn't a share of a stride).
local SKIP_KEYS = {
    { t = 0.00, fwd = 25, knee = 15 },  -- the step lands on it
    { t = 0.10, fwd = 12, knee = 30 },  -- the weight on it, the knee giving
    { t = 0.18, fwd = 0, knee = 10 },   -- straightening: the hop (hopAt)
    { t = 0.30, fwd = -8, knee = 25 },  -- in the air under the body
    { t = 0.40, fwd = -12, knee = 30 }, -- the hop lands, on the same foot
    { t = 0.50, fwd = -25, knee = 10 }, -- pushing off: the other foot steps
    { t = 0.60, fwd = 10, knee = 70 },  -- swinging through, the knee lifting
    { t = 0.72, fwd = 55, knee = 90 },  -- the knee high (while the other leg hops)
    { t = 0.88, fwd = 40, knee = 45 },  -- reaching down for the step
}

-- the gaits walking by itself (lib.drive's mode): keys, the stance's share of the cycle (duty; under a
-- half, both feet are off the floor between steps), the stride (degrees each thigh swings), steps a
-- second at most, lean (degrees; nil: lib.walkLean), arm swing (nil: lib.armSwing; the elbow bent
-- elbow degrees, elbowFwd more on the forward swing, armStiff: a jog's and a run's arms bent to a
-- shorter pendulum that keeps up with the legs), the push
-- (times driveAccel), the bounce at push-off (leg lengths up), the speed the spike asks (times its
-- walk speed). 'hop' is its own (updateHop).
lib.gaits = {
    walk = { keys = WALK_KEYS, duty = 0.5, stride = 28, maxSteps = 2.5, maxStride = 48, accel = 1, bounce = 0,
        speed = 1, elbow = 12, elbowFwd = 18, armStiff = 1 },
    jog = { keys = JOG_KEYS, duty = 0.42, stride = 30, maxSteps = 3.0, maxStride = 50, lean = 10, arms = 35,
        accel = 2, bounce = 0.04, speed = 1.8, elbow = 70, elbowFwd = 15, armStiff = 1.5 },
    run = { keys = RUN_KEYS, duty = 0.4, stride = 34, maxSteps = 3.4, maxStride = 55, lean = 16, arms = 40,
        accel = 3, bounce = 0.08, speed = 2.8, elbow = 88, elbowFwd = 10, armStiff = 2 },
    -- (skip: hopAt, where in a leg's cycle it hops on that foot, hopHeight leg lengths up; deg: the keys'
    -- thighs in degrees)
    skip = { keys = SKIP_KEYS, deg = true, duty = 0.5, stride = 17, maxSteps = 2.8, maxStride = 40, lean = 4,
        arms = 50, accel = 1.5, bounce = 0, hopAt = 0.18, hopHeight = 0.12, speed = 1.1, elbow = 30, elbowFwd = 20,
        armStiff = 1.5 },
    -- (arms, LO11: the run's 55 degrees at stiffness 3 whirled the arms over the shoulders once they had
    -- room behind; 40 at 2 swings ~100 in all. Elbows reach 55-65 of their 70-98: gravity and the swing)
    -- (spec/mipo-gaits_spec: walk 1.1, jog 2.4, run 3.2 legs/s; both feet off the floor 12 / 30 / 47% of
    -- the time. The run tops out near 3 whatever its push (accel 4.5, a gaitCap, a longer stride: the
    -- same); duty 0.34 tilted more)
}
local function gaitOf(inst) return lib.gaits[inst._driveMode] or lib.gaits.walk end
local function leanOf(inst) return gaitOf(inst).lean or lib.walkLean end

-- the cycle's u (0..1) in the keys' step time: the stance (u < duty) stretched to 0..0.5
local function keyTime(u, duty)
    if u < duty then return u / duty * 0.5 end
    return 0.5 + (u - duty) / (1 - duty) * 0.5
end

local function keyValue(key, field)
    local v = key[field]
    if v == 'give' then return lib.give end
    return v
end

-- the keyed pose at u (0..1 from contact): thigh forward share, knee bend (degrees); keys: WALK_KEYS
-- or a gait's
local function walkPose(u, keys)
    keys = keys or WALK_KEYS
    local n = #keys
    local i = n
    for k = 1, n do
        if keys[k].t <= u then i = k end
    end
    local t1 = keys[i].t
    local t2 = i < n and keys[i + 1].t or 1
    local s = (u - t1) / math.max(t2 - t1, 1e-6)
    local function at(k) return keys[(k - 1) % n + 1] end
    local p0, p1, p2, p3 = at(i - 1), at(i), at(i + 1), at(i + 2)
    local function curve(field)
        local a, b, c, d = keyValue(p0, field), keyValue(p1, field), keyValue(p2, field), keyValue(p3, field)
        return 0.5 * (2 * b + (c - a) * s + (2 * a - 5 * b + 4 * c - d) * s * s + (3 * b - a - 3 * c + d) * s * s * s)
    end
    return curve('fwd'), curve('knee')
end

-- the revolute joint that hangs a part from its parent
local function hangJoint(inst, name)
    local body = partBody(inst, name)
    if not body then return nil end
    for _, joint in ipairs(body:getJoints()) do
        local _, b = joint:getBodies()
        if b == body and joint:getType() == 'revolute' then return joint end
    end
end

-- the longest reach of a body's collision shapes (a thigh's length)
local function reach(body)
    local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
    for _, fixture in ipairs(body:getFixtures()) do
        if not fixture:getUserData() then
            local tx, ty, bx, by = fixture:getBoundingBox(1)
            x1, y1, x2, y2 = math.min(x1, tx), math.min(y1, ty), math.max(x2, bx), math.max(y2, by)
        end
    end
    if x1 == math.huge then return 0 end
    return math.max(x2 - x1, y2 - y1)
end

-- hip and knee motors toward the legs' aims (thigh and shin, degrees, world), or (aims nil) off
local function legMotors(inst, i, thighAim, shinAim)
    local leg = LEG_PAIRS[i]
    local hip, knee = hangJoint(inst, leg[1]), hangJoint(inst, leg[2])
    if not thighAim then
        if hip and hip:isMotorEnabled() then hip:setMotorEnabled(false) end
        if knee and knee:isMotorEnabled() then knee:setMotorEnabled(false) end
        return
    end
    local thigh, shin = partBody(inst, leg[1]), partBody(inst, leg[2])
    if not (thigh and shin and hip and knee) then return end
    local _, gy = thigh:getWorld():getGravity()
    local weight = mipoRegistry.totalMass(inst) * math.abs(gy) * reach(thigh)
    local wrap = function(a) return (a + math.pi) % TWO_PI - math.pi end
    local hipErr = wrap(math.rad(thighAim) - thigh:getAngle())
    local kneeErr = wrap((math.rad(shinAim) - math.rad(thighAim)) - (shin:getAngle() - thigh:getAngle()))
    hip:setMotorEnabled(true)
    hip:setMotorSpeed(lib.motorGain * hipErr)
    hip:setMaxMotorTorque(lib.hipStrength * weight)
    knee:setMotorEnabled(true)
    knee:setMotorSpeed(lib.motorGain * kneeErr)
    knee:setMaxMotorTorque(lib.kneeStrength * weight)
end

-- the torso held upright (leaning lib.walkLean degrees the way it faces, face 1 / -1) while it goes by
-- itself; face nil: the torso's muscle as it was before
local function uprightTorso(inst, face)
    local part = inst.parts.torso1
    if face and lib.upright > 0 then
        if not inst._torsoWas then
            local b = mipoActions.getKeepAngle(part)
            inst._torsoWas = b and { angle = b.angle, kp = b.kp, enabled = b.enabled } or { none = true }
        end
        local b = mipoActions.ensureKeepAngle(part, 0, lib.upright)
        if b then b.angle, b.kp, b.enabled = face * leanOf(inst), lib.upright, nil end
    elseif inst._torsoWas then
        local b = mipoActions.getKeepAngle(part)
        local was = inst._torsoWas
        inst._torsoWas = nil
        if b then
            if was.none then b.enabled = false else b.angle, b.kp, b.enabled = was.angle, was.kp, was.enabled end
        end
    end
end

-- The arms (LO11, Nikki 2026-11-12: "how do people use them when walking, running, jumping, think
-- anticipation and weight distribution"), for mipoActions' arm hang: fwd, degrees each upper arm swings
-- forward of hanging (- back; facing a side), elbow, degrees the forearm bends further forward, out,
-- degrees the arms lift out to the sides (facing front, where forward doesn't show), stiff, how
-- stiffly they follow (1: the hang's soft spring, lagging a little; a run's swing needs 3). One value
-- or { l, r }. nil fwd: the arms hang as they do (and elbows straight).
local function setArms(inst, face, fwd, elbow, out, stiff)
    if fwd == nil and out == nil then
        inst._armSwing, inst._armElbow, inst._armStiff, inst._armSide = nil, nil, nil, nil
        return
    end
    local function pick(v, side)
        if type(v) == 'table' then return v[side] or 0 end
        return v or 0
    end
    local swing, bend = {}, {}
    for _, side in ipairs({ 'l', 'r' }) do
        local outward = side == 'l' and 1 or -1 -- + world is toward the screen's left (the left arm out)
        if face ~= 0 then
            swing[side] = -face * math.rad(pick(fwd, side))
            bend[side] = -face * math.rad(pick(elbow, side))
        else
            swing[side] = outward * math.rad(pick(out, side))
            bend[side] = 0
        end
    end
    inst._armSwing, inst._armElbow, inst._armStiff = swing, bend, stiff
    inst._armSide = face ~= 0 and face or nil -- facing a side: the shoulders get room behind (mipoActions)
end

-- standing again: legs straight, feet back on their ankles, hips as the facing set them, full grip
local function stopWalking(inst)
    inst._goAt, inst._stepTurning = nil, nil
    uprightTorso(inst, nil)
    inst._armSwing, inst._driveTarget, inst._stance = nil, nil, nil
    inst._armElbow, inst._armStiff, inst._armSide = nil, nil, nil
    inst._prevU, inst._hopFire = nil, nil
    if inst._legMotorsOn then
        inst._legMotorsOn = nil
        legMotors(inst, 1, nil)
        legMotors(inst, 2, nil)
    end
    if not inst._walking then return end
    inst._walking = false
    setLegTargets(inst, 0, 0)
    holdFeet(inst, nil)
    hipsBack(inst, nil)
    for _, n in ipairs(FEET) do setGrip(inst, n, characterManager.footFriction) end
end
lib.stopWalking = stopWalking

-- a Mipo that may walk now: walking on in the scene, not held off, not a ragdoll, flipped or dazed
local function mayWalk(inst)
    return lib.isOn() and not inst._noWalk and not mipoActions.isRagdoll(inst)
        and not mipoActions.isFlipped(inst) and not mipoActions.isDazed(inst)
end

-- The foot through one leg's cycle (u as WALK_KEYS: 0 contact .. 0.5 toe-off .. 1), Nikki 2026-11-12:
-- "keep the same angle between shin and foot, maybe some anticipation and plant". lift: degrees the
-- toes are up from flat ('heel': lib.heelStrike, 'toe': -lib.toeOff, the heel up); follow: how much
-- the foot turns with the shin (1: the ankle keeps its standing angle, 0: held to the floor).
local FOOT_KEYS = {
    { t = 0.00, lift = 'heel', follow = 0 },   -- contact: the heel strikes, toes up
    { t = 0.10, lift = 0, follow = 0 },        -- plant: flat
    { t = 0.36, lift = 0, follow = 0 },        -- flat while the body passes over
    { t = 0.50, lift = 'toe', follow = 0 },    -- heel off, rolling over the toes
    { t = 0.62, lift = 'toeHalf', follow = 1 },-- lifted: with the shin, toes trailing
    { t = 0.80, lift = 0, follow = 1 },        -- the swing: with the shin
    { t = 0.92, lift = 'heel', follow = 0.5 }, -- anticipation: toes up before contact
}

local function footKeyValue(key, field)
    local v = key[field]
    if v == 'heel' then return lib.heelStrike end
    if v == 'toe' then return -lib.toeOff end
    if v == 'toeHalf' then return -lib.toeOff * 0.5 end
    return v
end

-- the foot's world angle (degrees) at u: flat is -face * 90 (the foot's picture stands on its heel)
local function footAngle(u, face, shinAngle)
    local n = #FOOT_KEYS
    local i = n
    for k = 1, n do
        if FOOT_KEYS[k].t <= u then i = k end
    end
    local a, b = FOOT_KEYS[i], FOOT_KEYS[i % n + 1]
    local t2 = i < n and b.t or 1
    local x = (u - a.t) / math.max(t2 - a.t, 1e-6)
    x = x * x * (3 - 2 * x) -- eased between keys
    local lift = footKeyValue(a, 'lift') + (footKeyValue(b, 'lift') - footKeyValue(a, 'lift')) * x
    local follow = (a.follow + (b.follow - a.follow) * x) * lib.footFollow
    return -face * (90 + lift) + follow * shinAngle
end

-- the standing leg's pose that reaches its foot where it is (LO3): world degrees for thigh and shin
-- (the walk's convention: 0 straight down, + the foot toward the screen's left), face 1 / -1
-- plant (x, y): where the foot landed (kept through the stance); lead: seconds ahead the hip is taken
-- (its speed times that): aimed at where the body is now, the motors held the leg still and the
-- body pushed the stiff leg's foot along (drift 99%)
local function legToFoot(inst, i, face, plant, lead)
    local leg = LEG_PAIRS[i]
    local hx, hy = jointPoint(inst, 'torso1', leg[1])
    local kx, ky = jointPoint(inst, leg[1], leg[2])
    local ax, ay = jointPoint(inst, leg[2], FEET[i])
    if not (hx and kx and ax) then return nil end
    local torso = partBody(inst, 'torso1')
    if torso and lead then
        local vx, vy = torso:getLinearVelocityFromWorldPoint(hx, hy)
        if lib.leadByWant and inst._driveTarget then vx, vy = inst._driveTarget, 0 end
        hx, hy = hx + vx * lead, hy + vy * lead
    end
    -- the segments' lengths from where the joints sit on them now (each a rigid body: fixed)
    local a = math.sqrt((kx - hx) ^ 2 + (ky - hy) ^ 2)
    local b = math.sqrt((ax - kx) ^ 2 + (ay - ky) ^ 2)
    local legA, legB = a, b
    local dx, dy = ax - hx, ay - hy
    if plant then dx, dy = plant[1] - hx, plant[2] - hy end
    a, b = legA, legB
    local d = math.min(math.sqrt(dx * dx + dy * dy), (a + b) * 0.999)
    local cosK = (d * d - a * a - b * b) / (2 * a * b)
    local k = math.acos(math.max(-1, math.min(1, cosK))) -- the knee's bend (0 straight)
    local line = math.atan2(-dx, dy)
    local alpha = math.atan2(b * math.sin(k), a + b * math.cos(k))
    local thigh = line - face * alpha
    return math.deg(thigh), math.deg(thigh + face * k)
end

-- where a Mipo's weight is: the mass-weighted centre of its parts (x, y)
local function centreOf(inst)
    local m, x, y = 0, 0, 0
    for _, part in pairs(inst.parts) do
        local b = part.body
        if b and not b:isDestroyed() then
            local bm = b:getMass()
            local cx, cy = b:getWorldCenter()
            m, x, y = m + bm, x + bm * cx, y + bm * cy
        end
    end
    if m == 0 then return nil end
    return x / m, y / m
end

-- SIMBICON's torso (LO1): a damped hold toward a world angle, its torque put on the torso and the
-- opposite on the standing thigh (at the hip between them: inside the Mipo, nothing from outside).
-- Impulses over the frame's dt, so it holds the same however many physics steps a frame takes.
local function holdTorso(inst, dt, face, stance, legLen)
    local torso, thigh = partBody(inst, 'torso1'), partBody(inst, LEG_PAIRS[stance][1])
    if not (torso and thigh) then return end
    local _, gy = torso:getWorld():getGravity()
    local g = math.max(math.abs(gy), 1)
    local mgl = mipoRegistry.totalMass(inst) * g * legLen
    local a = torso:getAngle()
    local err = (math.rad(face * leanOf(inst)) - a + math.pi) % TWO_PI - math.pi
    local tau = lib.torsoHold * mgl * err - lib.torsoDamp * mgl * math.sqrt(legLen / g) * torso:getAngularVelocity()
    tau = math.max(-2 * mgl, math.min(2 * mgl, tau))
    torso:applyAngularImpulse(tau * dt)
    thigh:applyAngularImpulse(-tau * dt)
end

-- SIMBICON's torso through the standing hip's motor (LO1, lib.torsoByMotor): the hip turns the torso
-- toward its world angle (walkLean), the thigh standing still. The joint's angle is thigh - torso, so
-- it opens at the torso's error; the motor is solved with the joint (stable), and what it pushes back
-- goes into a leg the weight presses down. Its muscle off: the thigh goes where the body puts it.
-- lib.stancePose (LO1b): the hip also keeps sweeping the thigh back through its pose, the torso's
-- correction on top. Without it (0) the standing thigh turned forward most frames and the foot slid
-- faster than the body went (Nikki 2026-11-12: "it looks skating, like the legs rotate the wrong way").
local function torsoByHip(inst, i, face, legLen, thighAim)
    local leg = LEG_PAIRS[i]
    local hip, torso, thigh = hangJoint(inst, leg[1]), partBody(inst, 'torso1'), partBody(inst, leg[1])
    if not (hip and torso and thigh) then return end
    local _, gy = torso:getWorld():getGravity()
    local err = (torso:getAngle() - math.rad(face * leanOf(inst)) + math.pi) % TWO_PI - math.pi
    local damp = lib.torsoDamp * torso:getAngularVelocity() * math.sqrt(legLen / math.max(math.abs(gy), 1))
    local poseErr = (math.rad(thighAim) - thigh:getAngle() + math.pi) % TWO_PI - math.pi
    hip:setMotorSpeed(lib.motorGain * (lib.stancePose * poseErr + lib.torsoHold * err + damp))
    if lib.stancePose == 0 then
        local upper = mipoActions.getKeepAngle(inst.parts[leg[1]])
        if upper then upper.enabled = false end
    end
end

-- the legs' step: thighs swing in turn, the knee bends on the swing forward. speed: world units a
-- second; face: 1 right, -1 left; side: it faces a side (feet held flat)
-- weighty (lib.weighty, walking by itself): returns how much a foot is pushing off now (0..1)
local function stepLegs(inst, dt, speed, face, side, legLen, weighty)
    -- one step (half a cycle) covers a stride; faster than MAX_STEPS, the strides grow
    local g = weighty and gaitOf(inst) or lib.gaits.walk
    local stride = math.max(2 * legLen * math.sin(math.rad(g.stride or STRIDE)), speed / (g.maxSteps or MAX_STEPS))
    local swing = math.min(g.maxStride or MAX_STRIDE, math.deg(math.asin(math.min(1, stride / (2 * legLen)))))
    inst._gait = (inst._gait or 0) + speed * dt / stride * math.pi
    local swinging, forward, pushOff, cycle = {}, {}, 0, {}
    local keyed = weighty and lib.keyed
    local holding = keyed and lib.torsoHold > 0
    -- SIMBICON's foot placement (LO1): degrees the swinging thigh aims further forward
    local place
    if keyed and (lib.placeV ~= 0 or lib.placeD ~= 0) and inst._driveTarget then
        local torso = partBody(inst, 'torso1')
        local cx = centreOf(inst)
        if torso and cx then
            local _, gy = torso:getWorld():getGravity()
            local vScale = math.sqrt(math.max(math.abs(gy), 1) * legLen)
            local vx = torso:getLinearVelocity()
            local ahead = 0
            local ax = inst._stance and jointPoint(inst, LEG_PAIRS[inst._stance][2], FEET[inst._stance])
            if ax then ahead = face * (cx - ax) / legLen end
            local rad = lib.placeV * (face * vx - math.abs(inst._driveTarget)) / vScale + lib.placeD * ahead
            place = math.deg(math.max(-0.6, math.min(0.6, rad)))
        end
    end
    for i, leg in ipairs(LEG_PAIRS) do
        local phase = inst._gait + (i - 1) * math.pi
        swinging[i] = math.cos(phase) > 0
        forward[i] = math.sin(phase)
        local thigh = -face * math.sin(phase) * swing              -- forward is the way it faces
        local shin = thigh + face * math.max(0, math.cos(phase)) * KNEE -- bent on the way forward
        if keyed then
            -- the sine's contact (thigh furthest forward) is at phase pi/2
            local uc = ((phase - math.pi / 2) % TWO_PI) / TWO_PI
            local u = keyTime(uc, g.duty or 0.5) -- in the keys' step time (the stance 0..0.5)
            cycle[i] = u
            local fwd, bend = walkPose(u, g.keys)
            swinging[i], forward[i] = u >= 0.5, fwd
            thigh = -face * fwd * swing
            if g.deg then thigh, forward[i] = -face * fwd, fwd / 55 end -- the keys in degrees (skip)
            shin = thigh + face * bend
            -- a skip's hop: this foot's moment in its cycle passed (updateDrive sends it up if it's down)
            if g.hopAt then
                inst._prevU = inst._prevU or {}
                local before = inst._prevU[i]
                if before and before < g.hopAt and u >= g.hopAt then inst._hopFire = i end
                inst._prevU[i] = u
            end
            if swinging[i] and place then -- SIMBICON's balance: the swinging foot lands further ahead
                thigh, shin = thigh - face * place, shin - face * place
            end
            -- where each foot landed: kept through its stance (LO3)
            inst._plant = inst._plant or {}
            if swinging[i] then
                inst._plant[i] = nil
            elseif not inst._plant[i] then
                local ax, ay = jointPoint(inst, leg[2], FEET[i])
                if ax then inst._plant[i] = { ax, ay } end
            end
            if not swinging[i] and lib.footLock > 0 and side then -- LO3: the standing leg to its foot
                local ikThigh, ikShin = legToFoot(inst, i, face, inst._plant[i], lib.footLead)
                if ikThigh then
                    local w = lib.footLock
                    if u > lib.lockUntil then w = w * math.max(0, 1 - (u - lib.lockUntil) / 0.08) end
                    thigh = thigh + (ikThigh - thigh) * w
                    shin = shin + (ikShin - shin) * w
                end
            end
            if u > 0.3 and u < 0.52 then pushOff = math.max(pushOff, math.sin(math.pi * (u - 0.3) / 0.22)) end
        end
        setGrip(inst, FEET[i], swinging[i] and SWING_GRIP or (weighty and lib.stanceGrip or STANCE_GRIP))
        local stanceFree = holding and lib.freeStance and not lib.torsoByMotor and not swinging[i] -- (holdTorso)
        if keyed and lib.legMotors then
            if swinging[i] and lib.swingStrength ~= 1 and (inst._driveMode or 'walk') == 'walk' then
                -- a swinging leg is loose: at the standing leg's strength, a long leg's foot that met the
                -- floor mid-swing pushed off it and lifted the whole Mipo (it floated, Nikki 2026-11-12)
                local hs, ks = lib.hipStrength, lib.kneeStrength
                lib.hipStrength, lib.kneeStrength = hs * lib.swingStrength, ks * lib.swingStrength
                legMotors(inst, i, thigh, shin)
                lib.hipStrength, lib.kneeStrength = hs, ks
            else
                legMotors(inst, i, thigh, shin)
            end
            if holding and lib.torsoByMotor and not swinging[i] then
                torsoByHip(inst, i, face, legLen, thigh)
            elseif stanceFree then
                local hip = hangJoint(inst, leg[1])
                if hip then hip:setMaxMotorTorque(0) end
            end
            inst._legMotorsOn = true
        elseif inst._legMotorsOn then
            legMotors(inst, i, nil)
        end
        if weighty and not keyed and not swinging[i] then
            -- through the stance (u 0: contact, thigh forward .. 1: push-off, thigh back): the knee
            -- gives to the down pose (u 0.25), straight again by passing (0.5), the up pose
            local u = ((phase - math.pi / 2) % TWO_PI) / math.pi
            if u < 0.5 then shin = shin + face * lib.give * math.sin(math.pi * u / 0.5) end
            if u > 0.6 then pushOff = math.max(pushOff, math.sin(math.pi * math.min(1, (u - 0.6) / 0.4))) end
        end
        local upper = mipoActions.ensureKeepAngle(inst.parts[leg[1]], 0, 40)
        local lower = mipoActions.ensureKeepAngle(inst.parts[leg[2]], 0, 40)
        if upper then
            upper.angle, upper.enabled = thigh, nil
            if stanceFree or (holding and lib.torsoByMotor and lib.stancePose == 0 and not swinging[i]) then
                upper.enabled = false
            end
        end
        if lower then lower.angle, lower.enabled = shin, nil end
        -- the swinging leg on its (weaker) motors alone: the muscles set a part's spin outright, so a foot
        -- meeting the floor mid-swing pushed off with no limit (LO13)
        if keyed and lib.legMotors and swinging[i] and lib.swingMuscles == false then
            if upper then upper.enabled = false end
            if lower then lower.enabled = false end
        end
    end
    inst._stance = (not swinging[1]) and 1 or ((not swinging[2]) and 2 or inst._stance)
    if holding and not lib.torsoByMotor and inst._stance then holdTorso(inst, dt, face, inst._stance, legLen) end
    local footAngles
    if keyed and lib.footRoll and side then
        footAngles = {}
        for i, leg in ipairs(LEG_PAIRS) do
            local shin = partBody(inst, leg[2])
            if shin and cycle[i] then
                local a = shin:getAngle()
                footAngles[i] = footAngle(cycle[i], face, math.deg((a + math.pi) % TWO_PI - math.pi))
            end
        end
    end
    if side then holdFeet(inst, face, swinging, footAngles) else holdFeet(inst, nil) end
    hipsBack(inst, side and face or nil)
    -- the arms against the legs: the left arm forward with the right leg (mipoActions' arm hang, world
    -- angles, + toward the screen's left)
    local arms = g.arms or lib.armSwing
    if weighty and arms > 0 then
        -- each arm with the other side's leg, the elbow bending more as it comes forward
        local fl, fr = forward[2], forward[1]
        local base, more = g.elbow or 0, g.elbowFwd or 0
        setArms(inst, face, { l = arms * fl, r = arms * fr },
            { l = base + more * math.max(0, fl), r = base + more * math.max(0, fr) }, nil, g.armStiff)
    else
        setArms(inst, 0, nil)
    end
    return pushOff
end

-- both legs the same (degrees): the thigh forward of straight down, the knee bent back
local function legsTo(inst, face, forward, knee)
    local thigh = -face * forward
    setLegTargets(inst, thigh, thigh + face * knee)
end

-- the feet push the torso toward target (world units a second), at most lib.driveAccel (times boost)
local function push(inst, torso, target, legLen, dt, boost)
    local vx = torso:getLinearVelocity()
    local most = lib.driveAccel * legLen * dt * (boost or 1)
    local dv = math.max(-most, math.min(most, target - vx))
    if lib.pushAll then
        for _, part in pairs(inst.parts) do
            local b = part.body
            if b and not b:isDestroyed() then b:applyLinearImpulse(b:getMass() * dv, 0) end
        end
    else
        torso:applyLinearImpulse(mipoRegistry.totalMass(inst) * dv, 0)
    end
end

-- hopping: crouch, spring up and forward (to the speed it wants), legs tucked in the air, a rest
-- on landing, again
local function updateHop(inst, now, torso, legLen, face, grounded, target)
    for _, n in ipairs(FEET) do setGrip(inst, n, STANCE_GRIP) end
    if inst._hopFireAt then
        if now < inst._hopFireAt then
            legsTo(inst, face, 30, 60) -- crouched
            return
        end
        inst._hopFireAt = nil
        local _, gy = torso:getWorld():getGravity()
        local up = math.sqrt(2 * math.max(gy, 1) * lib.hopHeight * legLen)
        local vx = torso:getLinearVelocity()
        local mass = mipoRegistry.totalMass(inst)
        torso:applyLinearImpulse(mass * (target - vx), -mass * up)
        inst._hopAt, inst._hopLanded = now, nil
        if inst._hopsLeft then inst._hopsLeft = inst._hopsLeft - 1 end
        legsTo(inst, face, 0, 0)
        return
    end
    if not grounded then
        inst._hopLanded = nil
        if now - (inst._hopAt or 0) > 0.08 then legsTo(inst, face, 35, 50) end -- tucked
        return
    end
    inst._hopLanded = inst._hopLanded or now
    if inst._hopsLeft == 0 and now - (inst._hopAt or 0) > 0.2 then -- the one hop landed
        lib.drive(inst, nil)
        return
    end
    legsTo(inst, face, 8, 16) -- soft knees
    if now - inst._hopLanded >= lib.hopRest and now - (inst._hopAt or 0) > 0.2 then
        inst._hopFireAt = now + lib.hopCrouch
    end
end

---------------------------------------------------------------- the jump (LO8)

-- One jump as an animator draws it: anticipation (squat, torso in, arms back, eased into the lowest
-- point and held a beat), the action (legs snap straight on their motors, the feet roll over the toes,
-- arms swing up; the lift spread over the push while a foot touches), follow-through (stretched, then
-- the knees tuck), and the landing (knees give, then up). inst._jump = { phase, at, face, forward, ... }.
-- Facing front the legs bend sideways, each its own way (mipo-stance): a frog squat (jumpLegs).

local function easeIn(x) return x * x end

-- the mass-weighted vertical speed of all its parts
local function centreVelocity(inst)
    local m, v = 0, 0
    for _, part in pairs(inst.parts) do
        local b = part.body
        if b and not b:isDestroyed() then
            local bm = b:getMass()
            local _, vy = b:getLinearVelocity()
            m, v = m + bm, v + bm * vy
        end
    end
    return m > 0 and v / m or 0
end
local function easeOut(x) return 1 - (1 - x) * (1 - x) end

-- both legs (degrees: the thigh forward of straight down, the knee bent), on motors (strength: times
-- the walk's) and on their muscles; face 0 (front): each knee its own way, the thighs straight
local function jumpLegs(inst, face, forwardDeg, kneeDeg, strength)
    for i = 1, 2 do
        local f = face
        -- facing front (hips 0..90 left, -90..0 right; knees the other way): a frog squat, thighs out,
        -- shins back in under (the knee bends twice the hip's turn: the foot under the hip)
        local fwd = forwardDeg
        if f == 0 then f, fwd = (i == 1) and -1 or 1, kneeDeg * 0.5 end
        local thigh = -f * fwd
        local shin = thigh + f * kneeDeg
        local hs, ks = lib.hipStrength, lib.kneeStrength
        lib.hipStrength, lib.kneeStrength = hs * strength, ks * strength
        legMotors(inst, i, thigh, shin)
        lib.hipStrength, lib.kneeStrength = hs, ks
        local leg = LEG_PAIRS[i]
        local upper = mipoActions.ensureKeepAngle(inst.parts[leg[1]], 0, 40)
        local lower = mipoActions.ensureKeepAngle(inst.parts[leg[2]], 0, 40)
        if upper then upper.angle, upper.enabled = thigh, nil end
        if lower then lower.angle, lower.enabled = shin, nil end
    end
    inst._legMotorsOn = true
end

-- the torso's lean (degrees the way it faces) on its muscle; nil: back as it was
local function jumpTorso(inst, face, lean)
    local part = inst.parts.torso1
    if lean then
        if not inst._torsoWas then
            local b = mipoActions.getKeepAngle(part)
            inst._torsoWas = b and { angle = b.angle, kp = b.kp, enabled = b.enabled } or { none = true }
        end
        local b = mipoActions.ensureKeepAngle(part, 0, 30)
        if b then b.angle, b.kp, b.enabled = face * lean, 30, nil end
    else
        uprightTorso(inst, nil) -- puts back what _torsoWas kept
    end
end

-- feet flat with toes up by lift degrees (side-facing only)
local function jumpFeet(inst, face, lift)
    if face == 0 then holdFeet(inst, nil) return end
    local a = -face * (90 + lift)
    holdFeet(inst, face, {}, { a, a })
end

-- the step-turn (lib.stepTurn): while a foot leans round (inst._lean, a step-turn), its leg lifts it
-- (up as it turns out, down as the new foot comes in), the other stands; false: no foot turning now
local function stepTurnLegs(inst, now)
    local L = inst._lean
    if L and not L.step then L.step = true end -- begun a frame before this turn on the spot
    if not (L and L.step) then
        if inst._walking then stopWalking(inst) end
        inst._stepTurning = true -- (stopWalking clears it; the turn reads it this frame)
        return true
    end
    local lifting
    for i, n in ipairs(FEET) do
        if n == L.foot then lifting = i end
    end
    if not lifting then return false end
    -- 0 .. 1 .. 0 over the two halves
    local k = math.min(1, L.t / lib.stepTurnTime)
    local up = L.phase == 'out' and math.sin(0.5 * math.pi * k) or math.cos(0.5 * math.pi * k)
    up = up * lib.stepTurnLift
    local face = facing.dir(inst)
    inst._walking, inst._walkedAt = true, now
    for i = 1, 2 do
        local f = face
        local fwd, knee = 25 * up, 60 * up
        if f == 0 then f, fwd = (i == 1) and -1 or 1, 30 * up end -- front: lifted out to the side
        if i ~= lifting then fwd, knee = 0, 4 end
        local thigh = -f * fwd
        local shin = thigh + f * knee
        legMotors(inst, i, thigh, shin)
        local leg = LEG_PAIRS[i]
        local upper = mipoActions.ensureKeepAngle(inst.parts[leg[1]], 0, 40)
        local lower = mipoActions.ensureKeepAngle(inst.parts[leg[2]], 0, 40)
        if upper then upper.angle, upper.enabled = thigh, nil end
        if lower then lower.angle, lower.enabled = shin, nil end
        setGrip(inst, FEET[i], i == lifting and SWING_GRIP or lib.stopGrip)
    end
    inst._legMotorsOn = true
    return true
end

-- walking (or hopping) by itself: lib.drive
local function updateDrive(inst, dt, now, torso, legLen)
    local dir = inst._drive > 0 and 1 or -1
    local side = SIDE_OF[dir]
    if facing.get(inst) ~= side and inst._turnGoal ~= side then lib.turnTo(inst, side) end
    local faceDir = facing.dir(inst)
    local face = faceDir ~= 0 and faceDir or dir
    local target = inst._drive * legLen * (faceDir == dir and 1 or lib.turningPace)
    local grounded = mipoActions.isGrounded(inst)
    -- turn first (LO4): not facing its way yet, it stands and turns on the spot; once it does, a dip
    -- (anticipation) and off
    local stepping = inst._lean and inst._lean.step -- a step-turn's foot still coming down
    if lib.turnFirst and stepGait(inst._driveMode) and (faceDir ~= dir or stepping) and grounded then
        inst._goAt = nil
        inst._stepTurning = lib.stepTurn or nil
        if lib.stepTurn and stepTurnLegs(inst, now) then return end
        if inst._walking then stopWalking(inst) end
        return
    end
    inst._stepTurning = nil
    if lib.turnFirst and stepGait(inst._driveMode) then
        if not inst._goAt then inst._goAt = now end
        local t = now - inst._goAt
        if t < lib.setOff then
            local d = math.sin(math.pi * t / lib.setOff)
            inst._walking, inst._walkedAt = true, now
            jumpLegs(inst, face, 14 * d, 30 * d, 1.2)
            jumpFeet(inst, face, 0)
            jumpTorso(inst, face, 6 * d)
            setArms(inst, face, -15 * d, 10 * d, nil, 1) -- arms a little back, then off
            return
        end
    end
    inst._walking, inst._walkedAt = true, now
    inst._driveTarget = target
    uprightTorso(inst, face)
    setArms(inst, 0, nil)
    if inst._jumpAt then return end -- crouching for a jump: the legs are the jump's
    if inst._driveMode == 'hop' then
        if grounded then push(inst, torso, target, legLen, dt) end
        holdFeet(inst, faceDir ~= 0 and face or nil, {})
        hipsBack(inst, faceDir ~= 0 and face or nil)
        updateHop(inst, now, torso, legLen, face, grounded, target)
        return
    end
    inst._hopFireAt = nil
    -- off the ground a while (a jump, a fall): tucked. Only once really falling (lib.tuckAfter seconds,
    -- or going down fast): a long-legged walker whose feet left the floor a moment tucked its legs up
    -- and hung there, feet off the floor (it floated, LO13)
    local airFor = now - (inst._groundAt or 0)
    if not grounded and airFor > GROUND_GRACE then
        local _, vy = torso:getLinearVelocity()
        if airFor > lib.tuckAfter or vy > lib.tuckFall * legLen then
            legsTo(inst, face, 30, 45)
            return
        end
    end
    local vx = torso:getLinearVelocity()
    -- blocked: going nowhere a while (a wall ahead), it stands facing it; tries again after a while
    if lib.blockedAfter > 0 and grounded and faceDir == dir and not inst._stepsLeft then
        local wants = math.abs(target)
        if vx * dir < lib.blockedSpeed * wants and inst._goAt and now - inst._goAt > lib.setOff + 0.4 then
            inst._slowFor = (inst._slowFor or 0) + dt
        else
            inst._slowFor = 0
        end
        if inst._blockedAt and now - inst._blockedAt > lib.blockedRetry then
            inst._blockedAt, inst._slowFor = nil, 0 -- a try again
        elseif (inst._slowFor or 0) > lib.blockedAfter and not inst._blockedAt then
            inst._blockedAt = now
        end
        if inst._blockedAt then
            if inst._walking then stopWalking(inst) end
            inst._walking, inst._walkedAt = false, now
            inst._goAt = now - lib.setOff -- back to walking without the set-off dip when it tries again
            return
        end
    end
    if inst._stepsLeft and faceDir ~= dir then inst._gaitFrom = nil end -- steps count once it faces its way
    if inst._stepsLeft then inst._gaitFrom = inst._gaitFrom or (inst._gait or 0) end
    -- the steps go at the body's speed, but at most gaitCap times the speed it wants: faster legs carried
    -- the body faster, which sped the legs up again (seed 42 ran away to 3x its speed, 2026-11-12)
    local cap = gaitOf(inst).gaitCap or lib.gaitCap
    local gaitSpeed = math.max(math.abs(target) * lib.gaitFloor, math.min(vx * dir, math.abs(target) * cap))
    local pushOff = stepLegs(inst, dt, gaitSpeed, face, faceDir ~= 0, legLen, lib.weighty)
    local g = gaitOf(inst)
    -- the walk's glue (lib.walkGlue): a walker whose feet have all left the floor doesn't go on rising
    -- (capping it on the floor too damped each step's push: three spec walks fell short)
    if lib.walkGlue > 0 and inst._driveMode == 'walk' and not grounded then
        local vy = centreVelocity(inst)
        local most = lib.walkGlue * legLen
        if -vy > most then torso:applyLinearImpulse(0, mipoRegistry.totalMass(inst) * (-vy - most)) end
    end
    local accel = g.accel or 1
    if grounded then
        if lib.weighty and lib.pulse > 0 then
            -- surging at push-off, easing between (a foot pushes off about a quarter of the time)
            push(inst, torso, target * (1 + lib.pulse * (pushOff - 0.25)), legLen, dt,
                accel * (1 + 2 * lib.pulse * pushOff))
        else
            push(inst, torso, target, legLen, dt, accel)
        end
        -- a skip's hop on one foot (its moment: stepLegs, hopAt)
        if inst._hopFire then
            inst._hopFire = nil
            local _, gy = torso:getWorld():getGravity()
            local up = math.sqrt(2 * math.max(math.abs(gy), 1) * (g.hopHeight or 0.1) * legLen)
            local vy = centreVelocity(inst)
            if -vy < up then torso:applyLinearImpulse(0, -mipoRegistry.totalMass(inst) * (up + vy)) end
        end
        -- a jog's and a run's bounce: at each push-off the foot sends it up (then both feet are off the floor)
        local step = math.floor((inst._gait or 0) / math.pi)
        if (g.bounce or 0) > 0 and pushOff > 0.7 and inst._bounceStep ~= step then
            inst._bounceStep = step
            local _, gy = torso:getWorld():getGravity()
            local up = math.sqrt(2 * math.max(math.abs(gy), 1) * g.bounce * legLen)
            local vy = centreVelocity(inst)
            if -vy < up then torso:applyLinearImpulse(0, -mipoRegistry.totalMass(inst) * (up + vy)) end
        end
    end
    if inst._stepsLeft and inst._gaitFrom and inst._gait - inst._gaitFrom >= inst._stepsLeft * math.pi then
        lib.drive(inst, nil)
    end
end

local function endJump(inst, now)
    inst._jump = nil
    setArms(inst, 0, nil)
    jumpTorso(inst, 0, nil)
    inst._walkedAt = now
    stopWalking(inst) -- legs straight, feet and grip back; a drive picks up again next frame
    inst._walking = false
end

function lib.jump(inst, forward)
    if not (alive(inst) and mayWalk(inst)) or inst._jump then return false end
    if not mipoActions.isGrounded(inst) then return false end
    local f = facing.dir(inst)
    local now = love.timer.getTime()
    local at = now
    if inst._squat then -- already down: the crouch starts as deep as the squat is (easeOut undone)
        local a = math.min(1, inst._squat.amount * lib.squatDepth / math.max(lib.jumpDepth, 0.01))
        at = now - lib.jumpCrouch * (1 - math.sqrt(1 - a))
        inst._squat = nil
    end
    inst._recover = nil
    inst._jump = { phase = 'crouch', at = at, face = f, forward = forward or 0 }
    return true
end

function lib.jumping(inst) return inst._jump ~= nil end

-- the jump's frame; false once it's over (or given up: held, ragdoll, gone)
local function updateJump(inst, dt, now)
    local j = inst._jump
    local torso = partBody(inst, 'torso1')
    local legLen = legLength(inst)
    if not (torso and legLen) or held(inst) or not mayWalk(inst) then endJump(inst, now) return false end
    inst._walking, inst._walkedAt = true, now
    local face, t = j.face, now - j.at
    local swingDir = face ~= 0 and face or 0
    local depth = lib.jumpDepth
    for _, n in ipairs(FEET) do setGrip(inst, n, characterManager.footFriction) end
    hipsBack(inst, face ~= 0 and face or nil)
    if j.phase == 'crouch' then
        -- anticipation: slow in to the bottom, then held a beat
        local x = easeOut(math.min(1, t / lib.jumpCrouch))
        jumpLegs(inst, face, 50 * depth * x, 95 * depth * x, 1.6)
        jumpTorso(inst, swingDir, 22 * depth * x)
        jumpFeet(inst, face, 0)
        -- anticipation: the arms swing back (and the elbows a little bent) as the knees load
        setArms(inst, face, -60 * x, 15 * x, 10 * x, 3)
        if t >= lib.jumpCrouch + lib.jumpHold then j.phase, j.at = 'push', now end
        return true
    end
    local _, gy = torso:getWorld():getGravity()
    local g = math.max(math.abs(gy), 1)
    if j.phase == 'push' then
        -- POING: legs snap straight, toes push, arms up; the lift over the push while a foot touches
        jumpLegs(inst, face, 0, 0, 3)
        jumpTorso(inst, swingDir, 4)
        jumpFeet(inst, face, -35)
        -- the arms whip forward and up with the legs' push (front: up in a V)
        setArms(inst, face, 150, 5, 130, 3)
        local mass = mipoRegistry.totalMass(inst)
        local target = lib.jumpHeight > 0 and math.sqrt(2 * g * lib.jumpHeight * legLen)
            or units.speed(mipoActions.jumpSpeed)
        if not j.started then
            j.started = true
            mipoActions.tellMusic('jump')
            if j.forward ~= 0 then torso:applyLinearImpulse(mass * units.speed(j.forward), 0) end
        end
        -- the whole Mipo's upward speed (the torso alone runs ahead of the legs it drags along)
        local share = math.min(1, (t + dt) / lib.jumpPush)
        local vy = centreVelocity(inst)
        local want = target * share
        if -vy < want and (mipoActions.isGrounded(inst) or share >= 1) then
            torso:applyLinearImpulse(0, -mass * (want + vy))
        end
        if t + dt >= lib.jumpPush then j.phase, j.at = 'air', now end
        return true
    end
    if j.phase == 'air' then
        -- follow-through: stretched a moment, then knees tucked, arms coming down
        local tuck = easeIn(math.min(1, math.max(0, (t - 0.08) / 0.2)))
        jumpLegs(inst, face, 35 * tuck, 60 * tuck, 1)
        jumpTorso(inst, swingDir, 0)
        jumpFeet(inst, face, -20 * (1 - tuck) + 8 * tuck)
        -- up at first, then coming forward and down for the landing
        setArms(inst, face, 150 - 100 * tuck, 25 * tuck, 130 - 80 * tuck, 2)
        if t > 0.15 and mipoActions.isGrounded(inst) then j.phase, j.at = 'land', now
        elseif t > 4 then endJump(inst, now) return false end
        return true
    end
    -- the landing: knees give quickly, then come back up slower
    local x = t / lib.jumpLand
    local give = x < 0.3 and easeOut(x / 0.3) or 1 - easeIn((x - 0.3) / 0.7)
    give = math.max(0, give)
    jumpLegs(inst, face, 35 * give, 65 * give, 1.4)
    jumpTorso(inst, swingDir, 12 * give)
    jumpFeet(inst, face, 0)
    -- forward as the knees give: the weight kept over the feet
    setArms(inst, face, 35 * give, 30 * give, 35 * give, 1.4)
    if x >= 1 then endJump(inst, now) return false end
    return true
end

---------------------------------------------------------------- stopping (LO4)

-- The stopping step, as a capture point (Pratt): a body over a leg is an inverted pendulum, and a foot
-- set down at x + v * sqrt(h / g) brings it to rest over that foot. The leg that isn't standing steps
-- there (lifted mid-way, reaching, heel down), the standing one holds; once the foot is down the feet
-- brake (both on the floor, as a person digging in). Then the settle: the feet come together under
-- the body, the knees give and straighten, the torso tips on past upright and back, the arms swing.
-- inst._stop = { phase 'step' | 'settle', at, face, leg, aim (degrees forward) }.

local function endStop(inst, now)
    inst._stop = nil
    setArms(inst, 0, nil)
    jumpTorso(inst, 0, nil)
    inst._walkedAt = now
    stopWalking(inst)
    inst._walking = false
end

-- the thigh's angle forward of straight down (degrees, + the way it faces)
local function thighForward(inst, i, face)
    local thigh = partBody(inst, LEG_PAIRS[i][1])
    if not thigh then return 0 end
    local a = (thigh:getAngle() + math.pi) % TWO_PI - math.pi
    return -face * math.deg(a)
end

local function updateStop(inst, dt, now)
    local st = inst._stop
    local torso = partBody(inst, 'torso1')
    local legLen = legLength(inst)
    if not (torso and legLen) or held(inst) or not mayWalk(inst) or inst._jump then
        endStop(inst, now)
        return false
    end
    if not st.face then
        local f = facing.dir(inst)
        if f == 0 then -- facing front: nothing to step with; brake as before
            inst._stop = nil
            inst._brakeUntil = now + lib.brakeFor
            return false
        end
        local stance = inst._stance or 1
        st.face, st.leg, st.stance = f, 3 - stance, stance
        st.from = thighForward(inst, st.leg, f)
        st.standFrom = thighForward(inst, stance, f)
    end
    inst._walking, inst._walkedAt = true, now
    local face, t = st.face, now - st.at
    local _, gy = torso:getWorld():getGravity()
    local g = math.max(math.abs(gy), 1)
    hipsBack(inst, face)
    if st.phase == 'step' then
        local x = math.min(1, t / lib.stopStepTime)
        -- where the momentum carries the body (forward of the hip, in leg lengths)
        local cx = centreOf(inst)
        local hx = jointPoint(inst, 'torso1', LEG_PAIRS[st.leg][1])
        local vx = torso:getLinearVelocity()
        local ahead = 0
        if cx and hx then ahead = face * (cx + vx * math.sqrt(legLen / g) - hx) / legLen end
        local aim = math.deg(math.asin(math.max(0.05, math.min(lib.stopReach, ahead))))
        st.aim = st.aim and (st.aim + (aim - st.aim) * math.min(1, dt * 10)) or aim
        -- the stepping leg: from where it was to the aim, lifted mid-way (knee) and reaching at the end
        local e = x * x * (3 - 2 * x)
        local fwd = st.from + (st.aim - st.from) * e
        local knee = 55 * math.sin(math.pi * math.min(1, x * 1.1))
        local thighW = -face * fwd
        legMotors(inst, st.leg, thighW, thighW + face * knee)
        -- the standing leg holds where it is, the knee a little soft
        local standW = -face * st.standFrom
        legMotors(inst, st.stance, standW, standW + face * 8)
        inst._legMotorsOn = true
        for i = 1, 2 do
            local leg = LEG_PAIRS[i]
            local upper = mipoActions.ensureKeepAngle(inst.parts[leg[1]], 0, 40)
            local lower = mipoActions.ensureKeepAngle(inst.parts[leg[2]], 0, 40)
            local th = i == st.leg and thighW or standW
            local sh = i == st.leg and (thighW + face * knee) or (standW + face * 8)
            if upper then upper.angle, upper.enabled = th, nil end
            if lower then lower.angle, lower.enabled = sh, nil end
        end
        -- feet: the stepping one toes up as it reaches (heel strike), the standing one flat
        local stepLift = 18 * math.max(0, (x - 0.5) / 0.5)
        local angles = {}
        angles[st.leg] = -face * (90 + stepLift)
        angles[st.stance] = -face * 90
        holdFeet(inst, face, {}, angles)
        setGrip(inst, FEET[st.leg], x < 0.8 and SWING_GRIP or lib.stopGrip)
        setGrip(inst, FEET[st.stance], lib.stopGrip)
        jumpTorso(inst, face, -5 * e) -- leaning back a touch, against the stop
        -- follow-through: the arms carry on forward with the momentum the legs are stopping
        setArms(inst, face, 30 * e, 20 * e, nil, 1.2)
        if lib.stopBrake > 0 and x >= lib.stopBrakeFrom and mipoActions.isGrounded(inst) then
            push(inst, torso, 0, legLen, dt, lib.stopBrake)
        end
        if x >= 1 then
            if inst._drive then endStop(inst, now) return false end -- turning back: no settle, it turns
            st.phase, st.at = 'close', now
            st.closeFrom = thighForward(inst, st.stance, face)
        end
        return true
    end
    if st.phase == 'close' then
        -- the back foot lifts and steps up beside the front one (sliding it in skidded both feet); the
        -- front leg holds where it is, a strut the body comes to rest over
        local x = math.min(1, t / lib.closeTime)
        local e = x * x * (3 - 2 * x)
        local front = thighForward(inst, st.leg, face)
        local fwd = st.closeFrom + (front - st.closeFrom) * e
        local knee = 50 * math.sin(math.pi * x)
        local closeW, frontW = -face * fwd, -face * front
        legMotors(inst, st.stance, closeW, closeW + face * knee)
        legMotors(inst, st.leg, frontW, frontW + face * 6)
        inst._legMotorsOn = true
        for i = 1, 2 do
            local leg = LEG_PAIRS[i]
            local upper = mipoActions.ensureKeepAngle(inst.parts[leg[1]], 0, 40)
            local lower = mipoActions.ensureKeepAngle(inst.parts[leg[2]], 0, 40)
            local th = i == st.stance and closeW or frontW
            local sh = th + face * (i == st.stance and knee or 6)
            if upper then upper.angle, upper.enabled = th, nil end
            if lower then lower.angle, lower.enabled = sh, nil end
        end
        holdFeet(inst, face, {}, { -face * 90, -face * 90 })
        setGrip(inst, FEET[st.stance], x < 0.85 and SWING_GRIP or lib.stopGrip)
        setGrip(inst, FEET[st.leg], lib.stopGrip)
        jumpTorso(inst, face, -5 * (1 - e))
        setArms(inst, face, 30 * (1 - e) + 10 * e, 20 * (1 - e), nil, 1.2) -- easing back
        if lib.stopBrake > 0 and mipoActions.isGrounded(inst) then push(inst, torso, 0, legLen, dt) end
        if x >= 1 then
            st.phase, st.at = 'settle', now
            st.stepAt = thighForward(inst, st.leg, face)
            st.standAt = thighForward(inst, st.stance, face)
        end
        return true
    end
    -- settle: both feet in under the body, knees giving and straightening, torso and arms following through
    local x = math.min(1, t / lib.settleTime)
    local e = x * x * (3 - 2 * x)
    local give = math.sin(math.pi * x)
    for _, n in ipairs(FEET) do setGrip(inst, n, lib.stopGrip) end
    for i = 1, 2 do
        local from = i == st.leg and st.stepAt or st.standAt
        local fwd = from * (1 - e)
        local thighW = -face * (fwd + 10 * give)
        local shinW = thighW + face * 22 * give
        legMotors(inst, i, thighW, shinW)
        local leg = LEG_PAIRS[i]
        local upper = mipoActions.ensureKeepAngle(inst.parts[leg[1]], 0, 40)
        local lower = mipoActions.ensureKeepAngle(inst.parts[leg[2]], 0, 40)
        if upper then upper.angle, upper.enabled = thighW, nil end
        if lower then lower.angle, lower.enabled = shinW, nil end
    end
    inst._legMotorsOn = true
    holdFeet(inst, face, {}, { -face * 90, -face * 90 })
    jumpTorso(inst, face, 7 * give - 5 * (1 - x)) -- on past upright, then back
    setArms(inst, face, 10 * (1 - x) - 15 * give, 10 * give, nil, 1) -- swinging back past hanging, settling
    if lib.stopBrake > 0 and mipoActions.isGrounded(inst) then push(inst, torso, 0, legLen, dt) end
    if x >= 1 then endStop(inst, now) return false end
    return true
end

---------------------------------------------------------------- the squat

-- held (on true) it sinks into a squat, let go (on false) it comes back up; a drive, a hand or a jump
-- takes over. A jump from the squat skips the jump's own crouch (lib.jump).
function lib.squat(inst, on)
    if on then
        inst._squat = inst._squat or { amount = 0 }
        inst._squat.on = true
    elseif inst._squat then
        inst._squat.on = false
    end
end
function lib.squatting(inst) return inst._squat ~= nil end

local function updateSquat(inst, dt, now)
    local sq = inst._squat
    if inst._drive or held(inst) or not mayWalk(inst) or not legLength(inst) then
        inst._squat = nil
        stopWalking(inst)
        return false
    end
    local step = dt / math.max(lib.squatTime, 0.01)
    sq.amount = sq.on and math.min(1, sq.amount + step) or math.max(0, sq.amount - step)
    if not sq.on and sq.amount <= 0 then
        inst._squat = nil
        setArms(inst, 0, nil)
        jumpTorso(inst, 0, nil)
        stopWalking(inst)
        inst._walking = false
        return false
    end
    local a = sq.amount * sq.amount * (3 - 2 * sq.amount)
    local face = facing.dir(inst)
    local d = lib.squatDepth
    inst._walking, inst._walkedAt = true, now
    for _, n in ipairs(FEET) do setGrip(inst, n, lib.stopGrip) end
    hipsBack(inst, face ~= 0 and face or nil)
    jumpLegs(inst, face, 50 * d * a, 95 * d * a, 1.6)
    jumpTorso(inst, face, 22 * d * a)
    jumpFeet(inst, face, 0)
    -- arms reaching forward: a counterweight for the hips going back (front: a little out)
    setArms(inst, face, 75 * a, 20 * a, 25 * a, 1.2)
    return true
end

---------------------------------------------------------------- the recovery step (LO4b)

-- A standing Mipo pushed or bumped: where its momentum carries it (the capture point, as the stopping
-- step) is past its feet, so it steps there (lifted, put down), the other foot follows in beside it
-- (as far apart as they stood), and it settles (legs back under it, knees giving). Facing a side the
-- foot further from the point steps (past the other, as in a walk); facing front the leg on that side
-- steps out sideways (front hips only open outward). inst._recover = { phase, at, leg, ... }.

-- the knee's bend sign for leg i (facing front each its own way)
local function kneeSign(i, face)
    if face ~= 0 then return face end
    return (i == 1) and -1 or 1
end

-- leg i's length straight (hip to knee to ankle) and its hip
local function legOf(inst, i)
    local leg = LEG_PAIRS[i]
    local hx, hy = jointPoint(inst, 'torso1', leg[1])
    local kx, ky = jointPoint(inst, leg[1], leg[2])
    local ax, ay = jointPoint(inst, leg[2], FEET[i])
    if not (hx and kx and ax) then return nil end
    return math.sqrt((kx - hx) ^ 2 + (ky - hy) ^ 2) + math.sqrt((ax - kx) ^ 2 + (ay - ky) ^ 2), hx, hy, ax
end

-- the thigh's world angle (degrees) that puts leg i's foot at x
local function thighTo(inst, i, x)
    local len, hx = legOf(inst, i)
    if not len then return 0 end
    return math.deg(math.asin(math.max(-0.8, math.min(0.8, (hx - x) / len))))
end

local function thighAngle(inst, i)
    local thigh = partBody(inst, LEG_PAIRS[i][1])
    if not thigh then return 0 end
    return math.deg((thigh:getAngle() + math.pi) % TWO_PI - math.pi)
end

-- both legs: thigh angles (world degrees), knee bends (degrees, each its own way)
local function poseLegs(inst, face, thighs, knees, strength)
    for i = 1, 2 do
        local thigh = thighs[i]
        local shin = thigh + kneeSign(i, face) * knees[i]
        local hs, ks = lib.hipStrength, lib.kneeStrength
        lib.hipStrength, lib.kneeStrength = hs * (strength or 1), ks * (strength or 1)
        legMotors(inst, i, thigh, shin)
        lib.hipStrength, lib.kneeStrength = hs, ks
        local leg = LEG_PAIRS[i]
        local upper = mipoActions.ensureKeepAngle(inst.parts[leg[1]], 0, 40)
        local lower = mipoActions.ensureKeepAngle(inst.parts[leg[2]], 0, 40)
        if upper then upper.angle, upper.enabled = thigh, nil end
        if lower then lower.angle, lower.enabled = shin, nil end
    end
    inst._legMotorsOn = true
end

-- the horizontal speed of its weight (mass-weighted)
local function centreVelocityX(inst)
    local m, v = 0, 0
    for _, part in pairs(inst.parts) do
        local b = part.body
        if b and not b:isDestroyed() then
            local bm = b:getMass()
            m, v = m + bm, v + bm * (b:getLinearVelocity())
        end
    end
    return m > 0 and v / m or 0
end

-- where its momentum carries it: x, and how fast it goes (nil: can't tell)
local function capturePoint(inst, legLen)
    local cx = centreOf(inst)
    local torso = partBody(inst, 'torso1')
    if not (cx and torso) then return nil end
    local _, gy = torso:getWorld():getGravity()
    local vx = centreVelocityX(inst)
    return cx + vx * math.sqrt(legLen / math.max(math.abs(gy), 1)), vx
end

local function endRecover(inst, now)
    inst._recover = nil
    setArms(inst, 0, nil)
    inst._recoveredAt = now
    stopWalking(inst)
    inst._walking = false
end

-- a standing Mipo: should it step? (and starts it)
local function maybeRecover(inst, now)
    if not lib.recoverStep or inst._drive or inst._walking or inst._jump or inst._stop or inst._squat or inst._triple
        or inst._hopscotch
        or inst._recover or inst._noWalk or held(inst) or not mayWalk(inst) then return end
    -- standing a moment first: not straight after a walk, a squat, a jump or a step (rising from a squat
    -- shifts the weight enough to set it off)
    if now - (inst._walkedAt or -10) < lib.recoverCalm or now - (inst._recoveredAt or -10) < 0.3
        or not mipoActions.isGrounded(inst) then return end
    local legLen = legLength(inst)
    if not legLen then return end
    local cpx, vx = capturePoint(inst, legLen)
    if not cpx or math.abs(vx) < lib.recoverSpeed * legLen then return end
    local _, _, _, a1 = legOf(inst, 1)
    local _, _, _, a2 = legOf(inst, 2)
    if not (a1 and a2) then return end
    local lo, hi = math.min(a1, a2) - lib.recoverMargin * legLen, math.max(a1, a2) + lib.recoverMargin * legLen
    if cpx >= lo and cpx <= hi then return end
    local face = facing.dir(inst)
    local leg
    if face ~= 0 then
        leg = math.abs(a1 - cpx) > math.abs(a2 - cpx) and 1 or 2 -- the further foot steps past
    else
        leg = cpx < (a1 + a2) / 2 and 1 or 2 -- the leg on that side steps out
    end
    local other = 3 - leg
    inst._recover = { phase = 'step', at = now, leg = leg, other = other, face = face,
        from = thighAngle(inst, leg), hold = thighAngle(inst, other), spacing = (leg == 1) and (a2 - a1) or (a1 - a2),
        dir = cpx < (a1 + a2) / 2 and -1 or 1 }
    inst._recoverCount = (inst._recoverCount or 0) + 1
end

local function updateRecover(inst, dt, now)
    local r = inst._recover
    local legLen = legLength(inst)
    local torso = partBody(inst, 'torso1')
    if not (legLen and torso) or inst._drive or held(inst) or not mayWalk(inst) or inst._jump then
        endRecover(inst, now)
        return false
    end
    inst._walking, inst._walkedAt = true, now
    local face, t = r.face, now - r.at
    local x = math.min(1, t / lib.recoverTime)
    local e = x * x * (3 - 2 * x)
    local lift = math.sin(math.pi * x)
    local thighs, knees = {}, {}
    if face ~= 0 then hipsBack(inst, face) end
    if r.phase == 'step' then
        local cpx = capturePoint(inst, legLen)
        local aim = cpx and thighTo(inst, r.leg, cpx) or r.from
        r.aim = r.aim and (r.aim + (aim - r.aim) * math.min(1, dt * 10)) or aim
        thighs[r.leg], knees[r.leg] = r.from + (r.aim - r.from) * e, 55 * lift
        thighs[r.other], knees[r.other] = r.hold, 6
        setGrip(inst, FEET[r.leg], x < 0.8 and SWING_GRIP or lib.stopGrip)
        setGrip(inst, FEET[r.other], lib.stopGrip)
        -- arms flung out: forward to counter the fall (facing a side), up and out (facing front)
        setArms(inst, face, 70 * lift, 35 * lift, 75 * lift, 2)
        if lib.recoverBrake > 0 and x >= 0.8 then push(inst, torso, 0, legLen, dt, lib.recoverBrake) end
        poseLegs(inst, face, thighs, knees, 1.4)
        if face ~= 0 then holdFeet(inst, face, {}, { -face * 90, -face * 90 }) end
        if x >= 1 then
            r.phase, r.at = 'close', now
            r.stepAt = thighAngle(inst, r.leg)
            r.closeFrom = thighAngle(inst, r.other)
        end
        return true
    end
    if r.phase == 'close' then
        -- the other foot in beside the stepped one, as far apart as they stood, lifted
        local _, _, _, stepFoot = legOf(inst, r.leg)
        local want = stepFoot and thighTo(inst, r.other, stepFoot + r.spacing) or r.closeFrom
        thighs[r.other], knees[r.other] = r.closeFrom + (want - r.closeFrom) * e, 45 * lift
        thighs[r.leg], knees[r.leg] = r.stepAt, 6
        setGrip(inst, FEET[r.other], x < 0.8 and SWING_GRIP or lib.stopGrip)
        setGrip(inst, FEET[r.leg], lib.stopGrip)
        setArms(inst, 0, nil)
        poseLegs(inst, face, thighs, knees, 1.4)
        if face ~= 0 then holdFeet(inst, face, {}, { -face * 90, -face * 90 }) end
        if x >= 1 then
            r.phase, r.at = 'settle', now
            r.settleFrom = { thighAngle(inst, 1), thighAngle(inst, 2) }
        end
        return true
    end
    -- settle: the legs back under it, knees giving and straightening
    for i = 1, 2 do
        thighs[i], knees[i] = r.settleFrom[i] * (1 - e), 18 * lift
    end
    for _, n in ipairs(FEET) do setGrip(inst, n, lib.stopGrip) end
    poseLegs(inst, face, thighs, knees, 1.2)
    if face ~= 0 then holdFeet(inst, face, {}, { -face * 90, -face * 90 }) end
    if x >= 1 then endRecover(inst, now) return false end
    return true
end

---------------------------------------------------------------- hop, step and jump (the triple jump)

-- After a run-up (a run, lib.tripleRunUp seconds, unless it's running already): the hop (off one foot,
-- the same foot lands: in the air that leg cycles round, knee forward, and reaches), the step (off it,
-- a long bound landing on the other foot: the legs split, the front knee driving), the jump (off that
-- foot, both legs swung forward to sail, landing on both, knees giving), then it stands. Heights in
-- leg lengths (lib.tripleHop / Step / Jump). inst._triple = { phase, at, face, a (the hop's foot), dir }.
local TRIPLE_PHASES = { hop = 'step', step = 'jump', jump = 'land' }

function lib.tripleJump(inst)
    if not (alive(inst) and mayWalk(inst)) or inst._triple or inst._jump then return false end
    local f = facing.dir(inst)
    local dir = f ~= 0 and f or 1
    inst._squat, inst._recover = nil, nil
    inst._triple = { phase = 'runup', at = love.timer.getTime(), dir = dir }
    return true
end
function lib.tripling(inst) return inst._triple ~= nil end

local function endTriple(inst, now)
    inst._triple = nil
    jumpTorso(inst, 0, nil)
    setArms(inst, 0, nil)
    inst._walkedAt = now
    lib.drive(inst, nil)
    stopWalking(inst)
    inst._walking = false
end

-- both legs (world degrees forward of straight down, knee bends) facing face
local function tripleLegs(inst, face, fa, ka, fb, kb, a, strength)
    local thighs, knees = {}, {}
    local b = 3 - a
    thighs[a], knees[a] = -face * fa, ka
    thighs[b], knees[b] = -face * fb, kb
    poseLegs(inst, face, thighs, knees, strength or 1.4)
end

local function takeOff(inst, torso, legLen, height, forward)
    local _, gy = torso:getWorld():getGravity()
    local up = math.sqrt(2 * math.max(math.abs(gy), 1) * height * legLen)
    local vy = centreVelocity(inst)
    local mass = mipoRegistry.totalMass(inst)
    torso:applyLinearImpulse(0, -mass * math.max(0, up + vy))
    if forward then
        local vx = torso:getLinearVelocity()
        torso:applyLinearImpulse(mass * (forward - vx) * 0.5, 0) -- keeps the run-up's speed going
    end
end

local function updateTriple(inst, dt, now)
    local tj = inst._triple
    local torso = partBody(inst, 'torso1')
    local legLen = legLength(inst)
    if not (torso and legLen) or held(inst) or not mayWalk(inst) or inst._jump then
        endTriple(inst, now)
        return false
    end
    local t = now - tj.at
    if tj.phase == 'runup' then
        -- run (turning first if it must), then off the foot that's down at a push-off
        if inst._driveMode ~= 'run' or not inst._drive then
            lib.drive(inst, tj.dir * 1.5 * lib.gaits.run.speed, 'run')
        end
        if t > lib.tripleRunUp and facing.dir(inst) == tj.dir and inst._stance and mipoActions.isGrounded(inst) then
            tj.face, tj.a = tj.dir, inst._stance
            inst._drive, inst._driveMode = nil, nil -- the legs are the triple's now
            tj.phase, tj.at, tj.speed = 'hop', now, torso:getLinearVelocity()
            takeOff(inst, torso, legLen, lib.tripleHop, tj.speed)
            mipoActions.tellMusic('jump')
        end
        return false -- the run's frame (updateWalk) goes on
    end
    inst._walking, inst._walkedAt = true, now
    local face, a = tj.face, tj.a
    local b = 3 - a
    hipsBack(inst, face)
    holdFeet(inst, face, {}, { -face * 90, -face * 90 })
    for _, n in ipairs(FEET) do setGrip(inst, n, lib.stopGrip) end
    local grounded = mipoActions.isGrounded(inst)
    local x = math.min(1, t / 0.45)
    if tj.phase == 'hop' then
        -- the takeoff leg cycles round under the body and reaches to land again; the other trails, bent
        local cyc = math.sin(math.pi * x)
        tripleLegs(inst, face, -20 + 60 * x, 20 + 70 * cyc, -25, 70, a)
        jumpTorso(inst, face, 10)
        setArms(inst, face, { l = (a == 1) and -40 or 40, r = (a == 1) and 40 or -40 }, 40, 30, 1.5)
    elseif tj.phase == 'step' then
        -- a bound: the legs split, the other knee driving forward to land on it
        tripleLegs(inst, face, -35, 40, 45 * math.min(1, x * 2), 30 * (1 - x) + 10, a)
        jumpTorso(inst, face, 8)
        setArms(inst, face, { l = (a == 1) and 50 or -40, r = (a == 1) and -40 or 50 }, 45, 30, 1.5)
    elseif tj.phase == 'jump' then
        -- both legs swung forward to sail, the arms up then forward
        local sail = math.min(1, x * 1.6)
        tripleLegs(inst, face, 50 * sail, 30, 50 * sail, 30, b)
        jumpTorso(inst, face, 15 * sail)
        setArms(inst, face, 140 - 90 * sail, 20, 120, 2)
    else -- 'land': the knees give, then up
        local lx = math.min(1, t / lib.jumpLand)
        local give = lx < 0.3 and easeOut(lx / 0.3) or 1 - easeIn((lx - 0.3) / 0.7)
        tripleLegs(inst, face, 35 * give, 65 * give, 35 * give, 65 * give, a)
        jumpTorso(inst, face, 12 * give)
        setArms(inst, face, 35 * give, 30 * give, 35 * give, 1.4)
        push(inst, torso, 0, legLen, dt, 3)
        if lx >= 1 then endTriple(inst, now) return true end
        return true
    end
    -- landing: on the right foot (or any, after a while), then the next takeoff at once
    if t > 0.15 and grounded then
        local nextPhase = TRIPLE_PHASES[tj.phase]
        tj.phase, tj.at = nextPhase, now
        if nextPhase == 'step' then
            takeOff(inst, torso, legLen, lib.tripleStep, tj.speed)
        elseif nextPhase == 'jump' then
            takeOff(inst, torso, legLen, lib.tripleJumpHeight, tj.speed)
        end
    elseif t > 3 then
        endTriple(inst, now)
        return false
    end
    return true
end

---------------------------------------------------------------- hopscotch (hinkelen)

-- Hopscotch (Nikki 2026-11-12: "you know hopscotch, hinkelen, can you really figure out the legs and arm
-- movements"), by a pattern: '1' a hop landing on one foot, '2' a jump landing on both (the double
-- squares), 'T' a jump turning round, landing on both. Every landing gives (the knee 30-40 degrees, the
-- torso a little forward, the arms back and down: loading) and is the next push's anticipation; the
-- push straightens knee and ankle over the toes, the arms go forward and up with it; in the air the
-- arms are out wide for balance, elbows bent. On one foot the other leg is tucked up behind (knee 100,
-- its foot never touches), swinging a little forward at the push. lib.hopscotch(inst, pattern) after
-- it faces a side; inst._hopscotch = { list, i, phase 'ready' | 'give' | 'air' | 'done', at, face, a }.
lib.HOPSCOTCH = '1 1 2 1 2 1 1 2 T 2 1 1 2 1 2 1 1'

function lib.hopscotch(inst, pattern)
    if not (alive(inst) and mayWalk(inst)) or inst._hopscotch or inst._jump or inst._triple then return false end
    local list = {}
    for c in (pattern or lib.HOPSCOTCH):gmatch('%S') do list[#list + 1] = c end
    if #list == 0 then return false end
    local f = facing.dir(inst)
    inst._squat, inst._recover = nil, nil
    lib.drive(inst, nil)
    inst._hopscotch = { list = list, i = 0, phase = 'ready', at = love.timer.getTime(), face = f ~= 0 and f or nil,
        landed = '2' }
    if f == 0 then lib.turnTo(inst, 'right') end
    return true
end
function lib.hopscotching(inst) return inst._hopscotch ~= nil end

local function endHopscotch(inst, now)
    inst._hopscotch = nil
    jumpTorso(inst, 0, nil)
    setArms(inst, 0, nil)
    inst._walkedAt = now
    stopWalking(inst)
    inst._walking = false
end

-- the legs: on = '1' (on leg a, the other tucked behind) or '2' (both); give 0..1 (knees bent as it
-- lands), stretch (in the air: the landing leg(s) reaching, 0..1)
local function hopscotchLegs(inst, face, a, on, give, stretch, tuckAll)
    if tuckAll then -- the turn: both tucked
        tripleLegs(inst, face, 30, 60, 30, 60, a, 1.4)
        return
    end
    local standFwd = 12 * give + 10 * stretch
    local standKnee = 38 * give + 15 * stretch
    if on == '1' then
        -- the free leg: thigh a little behind, knee bent all the way (the joint's 90), the heel kicked up
        -- to the bottom; swinging a little forward with the push (stretch). Thigh forward with the knee
        -- bent left the foot a third of a leg up: the standing knee's give put it on the floor
        tripleLegs(inst, face, standFwd, standKnee, lib.hopscotchTuck + 10 * stretch, 90, a, 1.8)
    else
        tripleLegs(inst, face, standFwd + 4, standKnee, standFwd - 4, standKnee, a, 1.6)
    end
end

-- a part touching something solid that isn't the Mipo itself (mipoActions.isGrounded counts any contact,
-- sensors and the other foot too: a tucked foot brushing the standing one counted as down, and the
-- feet touching each other in the air as a landing)
local function onFloor(inst, name)
    local body = partBody(inst, name)
    if not body then return false end
    for _, c in ipairs(body:getContacts()) do
        if c:isTouching() then
            local fa, fb = c:getFixtures()
            local other = (fa:getBody() == body) and fb or fa
            if not other:isSensor() then
                local ud = other:getBody():getUserData()
                local thing = ud and ud.thing
                if not (thing and thing.mipoId == inst.id) then return true end
            end
        end
    end
    return false
end
lib.onFloor = onFloor

local function updateHopscotch(inst, dt, now)
    local hs = inst._hopscotch
    local torso = partBody(inst, 'torso1')
    local legLen = legLength(inst)
    if not (torso and legLen) or held(inst) or not mayWalk(inst) or inst._jump or inst._drive then
        endHopscotch(inst, now)
        return false
    end
    local t = now - hs.at
    if hs.phase == 'ready' then -- facing a side first
        local f = facing.dir(inst)
        if f == 0 or lib.isTurning(inst) then return false end -- standing, turning (updateWalk's frame)
        hs.face, hs.a = f, inst._stance or 1
        hs.phase, hs.at, hs.first = 'give', now, true
        return true
    end
    inst._walking, inst._walkedAt = true, now
    local face, a = hs.face, hs.a
    local b = 3 - a
    hipsBack(inst, face)
    local _, gy = torso:getWorld():getGravity()
    local g = math.max(math.abs(gy), 1)
    if hs.phase == 'give' or hs.phase == 'done' then
        -- landed: the knee(s) give and load; the first one (from standing) a longer wind-up
        local dur = hs.first and lib.hopscotchGive * 1.8 or lib.hopscotchGive
        local x = math.min(1, t / dur)
        local give = math.sin(math.pi * math.min(1, x * 1.15)) -- down, and on its way up by the push
        if hs.phase == 'done' then give = 1 - x end
        local upNext = hs.phase == 'give' and hs.landed ~= '1' and hs.list[hs.i + 1] == '1'
        if upNext and x > 0.5 then
            -- from both feet onto one: the free foot comes up with the push, not after it (folding it in
            -- the air alone, it was still on the floor at the landing)
            local lift = (x - 0.5) / 0.5
            local standFwd, standKnee = 12 * math.max(give, 0.15), 38 * math.max(give, 0.15)
            tripleLegs(inst, face, standFwd, standKnee, standFwd + (lib.hopscotchTuck - standFwd) * lift,
                standKnee + (90 - standKnee) * lift, a, 1.8)
        else
            hopscotchLegs(inst, face, a, hs.landed, math.max(give, 0.15), 0)
        end
        local feet = {}
        feet[a] = -face * 90
        feet[b] = hs.landed == '1' and -face * (90 - 30) or -face * 90 -- the tucked foot pointing down
        holdFeet(inst, face, {}, feet)
        setGrip(inst, FEET[a], lib.stopGrip)
        setGrip(inst, FEET[b], hs.landed == '1' and SWING_GRIP or lib.stopGrip)
        jumpTorso(inst, face, 6 + 8 * give)
        setArms(inst, face, -25 * give + 10 * (1 - give), 30, 30 + 15 * give, 2)
        push(inst, torso, 0, legLen, dt, 2) -- the landing stops it; the push gives the next speed
        if hs.phase == 'done' and x >= 1 then endHopscotch(inst, now) return false end
        if hs.phase == 'give' and x >= 1 then
            hs.i, hs.first = hs.i + 1, nil
            local next = hs.list[hs.i]
            if not next then
                hs.phase, hs.at = 'done', now
                return true
            end
            -- the push: up to its height, forward to cover its length in the time up there
            local h = (next == '1' and lib.hopscotchHop) or (next == '2' and lib.hopscotchTwo) or lib.hopscotchTurn
            local up = math.sqrt(2 * g * h * legLen)
            local flight = 2 * up / g
            local fwd = next == 'T' and 0 or face * lib.hopscotchLength * legLen / flight
            local mass = mipoRegistry.totalMass(inst)
            local vx = torso:getLinearVelocity()
            local vy = centreVelocity(inst)
            torso:applyLinearImpulse(mass * (fwd - vx), -mass * math.max(0, up + vy))
            if next == 'T' then -- round in the air: the other side
                hs.face = -face
                lib.turnTo(inst, hs.face > 0 and 'right' or 'left')
            end
            hs.next, hs.phase, hs.at = next, 'air', now
        end
        return true
    end
    -- in the air: arms out wide, elbows bent; the leg(s) it lands on reaching for the floor
    local x = math.min(1, t / 0.25)
    local on = hs.next == '1' and '1' or '2'
    hopscotchLegs(inst, face, a, on, 0, 0.3 + 0.7 * x, hs.next == 'T' and x < 0.6)
    local feet = {}
    feet[a] = -face * (90 - 25 * (1 - x)) -- toes down off the push, flat for the landing
    feet[b] = on == '1' and -face * (90 - 30) or -face * (90 - 25 * (1 - x))
    holdFeet(inst, face, {}, feet)
    setGrip(inst, FEET[b], on == '1' and SWING_GRIP or lib.stopGrip)
    jumpTorso(inst, face, 8)
    if hs.next == 'T' then
        setArms(inst, face, 110 - 60 * x, 20, 120 - 70 * x, 2.5) -- up, then in as it comes round
    else
        setArms(inst, face, 60 - 30 * x, 35, 70 - 20 * x, 2)
    end
    -- landed: the foot it lands on (a '1'), either foot (a '2', a 'T') on the floor
    local landedNow = onFloor(inst, FEET[a]) or (on == '2' and onFloor(inst, FEET[b]))
    if t > 0.12 and landedNow then
        hs.landed, hs.phase, hs.at = on, 'give', now
    elseif t > 2.5 then
        endHopscotch(inst, now)
        return false
    end
    return true
end

local function updateWalk(inst, dt, now)
    if not mayWalk(inst) then
        stopWalking(inst)
        inst._pull, inst._walkTurned = 0, nil
        return
    end
    local torso = partBody(inst, 'torso1')
    if not torso then return end
    local vx = torso:getLinearVelocity()
    inst._walkVx = (inst._walkVx or 0) + (vx - (inst._walkVx or 0)) * math.min(1, dt * 8)
    if mipoActions.isGrounded(inst) then inst._groundAt = now end
    local legLen = legLength(inst)
    local isHeld = held(inst)
    if inst._drive and legLen and not isHeld then
        inst._pull, inst._walkTurned = 0, nil
        updateDrive(inst, dt, now, torso, legLen)
        return
    end
    inst._hopFireAt = nil
    -- told to stop: the feet brake a moment (only on the ground)
    if inst._brakeUntil and (isHeld or now > inst._brakeUntil) then inst._brakeUntil = nil end
    if inst._brakeUntil and legLen and mipoActions.isGrounded(inst) then push(inst, torso, 0, legLen, dt) end
    local walking = legLen and isHeld and inst._groundAt and now - inst._groundAt < GROUND_GRACE
        and math.abs(inst._walkVx) > legLen * WALK_SPEED
    -- the pull: how far it was dragged one way lately
    local pull = inst._pull or 0
    if not isHeld or inst._walkVx * pull < 0 then pull, inst._pullStart = 0, now end
    if isHeld then pull = pull + inst._walkVx * dt end
    inst._pull = pull * math.exp(-dt * PULL_FADE)
    inst._pullStart = inst._pullStart or now
    if not walking then
        -- standing again after a walk: back to front, relaxed (head slow, as any turn)
        if inst._walkTurned and not isHeld and now - (inst._walkedAt or now) > RELAX_AFTER then
            inst._walkTurned = nil
            local home = inst._home or 'front'
            if facing.get(inst) ~= home or inst._turnGoal then lib.turnTo(inst, home, true) end
        end
        stopWalking(inst)
        return
    end
    inst._walking, inst._walkedAt = true, now
    local dir = inst._walkVx > 0 and 1 or -1
    local pullDir = inst._pull > 0 and 1 or -1
    if facing.dir(inst) ~= pullDir and math.abs(inst._pull) > legLen * TURN_DISTANCE
        and now - inst._pullStart >= TURN_TIME then
        lib.turnTo(inst, SIDE_OF[pullDir], true)
        inst._walkTurned = true -- the walk turned it: it relaxes back to front after
    end
    local face = facing.dir(inst)
    local side = face ~= 0 -- feet flat only once it faces a side (front-on they point apart)
    if face == 0 then face = dir end
    stepLegs(inst, dt, math.abs(inst._walkVx), face, side, legLen)
end

---------------------------------------------------------------- each frame

-- every Mipo (in a fixed order: a switch remakes bodies, utils.sortedPairs), while the world runs
local ranAt -- when lib.update last ran (lib.isRunning: mipoActions.jump hands over only then)
function lib.isRunning() return ranAt ~= nil and math.abs(love.timer.getTime() - ranAt) < 1 end

function lib.update(dt)
    dt = math.min(dt, 0.05)
    local now = love.timer.getTime()
    ranAt = now
    for _, inst in utils.sortedPairs(mipoRegistry.getAll()) do
        if alive(inst) then
            if not (inst._hopscotch and updateHopscotch(inst, dt, now))
                and not (inst._triple and updateTriple(inst, dt, now))
                and not (inst._jump and updateJump(inst, dt, now))
                and not (inst._stop and updateStop(inst, dt, now))
                and not (inst._recover and updateRecover(inst, dt, now))
                and not (inst._squat and updateSquat(inst, dt, now)) then
                updateWalk(inst, dt, now)
                maybeRecover(inst, now)
            end
            updateTurn(inst, dt, now)
            updateRelax(inst, now)
        end
    end
end

return lib

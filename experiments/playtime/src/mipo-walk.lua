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
-- HEAD_SPEED. The arms switch at their own moment, once the head is lib.armAt of the way.
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
local characterManager = require('src.character-manager')
local box2dPointerJoints = require('src.physics.box2d-pointerjoints')

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
    relaxAfter = 3,  -- seconds standing before a turned Mipo turns back home (0: it stays turned)
}
for k, v in pairs(SWITCHES) do lib[k] = v end

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
    local k = math.min(1, L.t / (L.phase == 'out' and LEAN_OUT or LEAN_IN))
    local e = k * k * (3 - 2 * k)
    picture.leanAngle = L.start + (L.goal - L.start) * e
    if k < 1 then return end
    if L.phase == 'out' then
        if switchBlocked(inst) then return end
        doSwitch(inst, L.want) -- remakes the foot (and its picture)
        local newPicture = footPicture(inst, L.foot)
        if not newPicture then inst._lean = nil return end
        -- the new foot leaning as far as the old one did, the other way, then down
        local lean = footOffset(inst, L.foot) * LEAN
        newPicture.leanAngle = lean
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
                start = 0, goal = footOffset(inst, foot) * LEAN } -- toes up
            return false
        end
    end
    doSwitch(inst, want)
    return true
end

-- The arms (limits, draw order) follow the body's facing at their own moment: once the head is
-- lib.armAt of the way there. Turning only the head leaves them with the body.
local function updateArms(inst)
    local body, arms = facing.get(inst), facing.armFacing(inst)
    if body == arms then return end
    local ratio = facing.angle(inst) / facing.faceTurn -- the head: -1 left .. 1 right
    local at = lib.armAt
    local ready
    if body == 'right' then ready = ratio >= at
    elseif body == 'left' then ready = ratio <= -at
    else ready = math.abs(ratio) <= 1 - at end
    if ready or not inst._headGoal then characterManager.switchArms(inst, body) end
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
    updateArms(inst)
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
local function holdFeet(inst, face, toesUp)
    for i, footName in ipairs(FEET) do
        local ankle = ankleOf(inst, footName)
        if ankle then ankle:setLimitsEnabled(face == nil) end
        local b = mipoActions.ensureKeepAngle(inst.parts[footName], 0, 40)
        if b then
            if face then
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

-- standing again: legs straight, feet back on their ankles, hips as the facing set them, full grip
local function stopWalking(inst)
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
    -- one step (half a cycle) covers a stride; dragged faster than MAX_STEPS, the strides grow
    local speed = math.abs(inst._walkVx)
    local stride = math.max(2 * legLen * math.sin(math.rad(STRIDE)), speed / MAX_STEPS)
    local swing = math.min(MAX_STRIDE, math.deg(math.asin(math.min(1, stride / (2 * legLen)))))
    inst._gait = (inst._gait or 0) + speed * dt / stride * math.pi
    local swinging = {}
    for i, leg in ipairs(LEG_PAIRS) do
        local phase = inst._gait + (i - 1) * math.pi
        swinging[i] = math.cos(phase) > 0
        setGrip(inst, FEET[i], swinging[i] and SWING_GRIP or STANCE_GRIP)
        local thigh = -face * math.sin(phase) * swing              -- forward is the way it faces
        local shin = thigh + face * math.max(0, math.cos(phase)) * KNEE -- bent on the way forward
        local upper = mipoActions.ensureKeepAngle(inst.parts[leg[1]], 0, 40)
        local lower = mipoActions.ensureKeepAngle(inst.parts[leg[2]], 0, 40)
        if upper then upper.angle, upper.enabled = thigh, nil end
        if lower then lower.angle, lower.enabled = shin, nil end
    end
    if side then holdFeet(inst, face, swinging) else holdFeet(inst, nil) end
    hipsBack(inst, side and face or nil)
end

---------------------------------------------------------------- each frame

-- every Mipo (in a fixed order: a switch remakes bodies, utils.sortedPairs), while the world runs
function lib.update(dt)
    dt = math.min(dt, 0.05)
    local now = love.timer.getTime()
    for _, inst in utils.sortedPairs(mipoRegistry.getAll()) do
        if alive(inst) then
            updateWalk(inst, dt, now)
            updateTurn(inst, dt, now)
            updateRelax(inst, now)
        end
    end
end

return lib

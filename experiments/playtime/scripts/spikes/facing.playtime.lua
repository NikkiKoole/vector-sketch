-- facing: one Mipo three times, facing left, front and right (dna.facing, src/mipo-facing.lua;
-- docs/MIPO-FACING.md), after puppet-maker2's facingVars.legs. Facing a side, both legs bend like
-- that side's leg and both feet point that way; the far arm and leg draw behind the torso.
-- Sit puts a stool under each and folds the legs: thighs forward, shins down (front can't: its
-- hips only swing outward).
-- Turning: arrows turn every Mipo a step (left <- front -> right): the body quickly, the head
-- slowly after it; , and . turn only the heads; t turns them back and forth.
-- keys: r: a new Mipo   s: sit / stand   a: arms follow the facing (on/off)   left/right: turn
--       , .: turn the heads   j: a little hop as the body switches (on/off)
--       b: switch the body in place, or rebuild the whole Mipo (to compare)
--       f: the turning foot leans round, or flips   w: autowalk when dragged along the floor
--       t: turning by itself   p: pause   h: panel
--       c: face patches on/off (src/face-patches.lua: eye hollows and a snout, turning with the face)

local s = {}

local facing = mipoFacing
local actions = mipoActions

local SPACING = 1100
local GROUND_Y = 900
local ZOOM = 0.3
local SCALE = 0.3
-- all front: a Mipo faces front and turns when pulled (was left / front / right)
local SIDES = { 'front', 'front', 'front' }

local function check() -- on state: a script hot reload keeps the Mipos
    state.facingSpike = state.facingSpike or { mipos = {}, stools = {}, showPanel = true }
    return state.facingSpike
end

local alive = mipoKit.isAlive -- src/mipo-kit.lua

local function removeStools()
    local c = check()
    for _, body in ipairs(c.stools) do
        if not body:isDestroyed() then body:destroy() end
    end
    c.stools = {}
end

local function removeMipos()
    local c = check()
    for _, inst in pairs(c.mipos) do
        if alive(inst) then characterManager.removeCharacter(inst) end
    end
    c.mipos = {}
end

local function xOf(i) return (i - 2) * SPACING end

-- face patches on every Mipo, or none (c)
local function placePatches()
    local c = check()
    if c.patches == nil then c.patches = true end
    for _, inst in pairs(c.mipos) do
        if alive(inst) then
            inst.facePatches = c.patches and facePatches.defaults() or nil
            facePatches.place(inst, true)
        end
    end
end

local function newMipos()
    local c = check()
    removeStools()
    removeMipos()
    c.sitting = false
    local first = characterManager.createCharacter('humanoid', xOf(1), GROUND_Y - 500, SCALE)
    if not first then return end
    characterManager.randomizeMipo(first)
    characterManager.removeCharacter(first)
    for i, side in ipairs(SIDES) do
        first.dna.facing = side -- createCharacterFromJustDNA builds on a copy
        c.mipos[i] = characterManager.createCharacterFromJustDNA(first.dna, xOf(i), GROUND_Y - 500, SCALE)
    end
    placePatches()
end

-- arms on/off: the same Mipos rebuilt
local function rebuildAll()
    local c = check()
    for _, inst in pairs(c.mipos) do
        if alive(inst) then
            characterManager.rebuildFromCreation(inst, {})
        end
    end
end

-- where a joint between parent and part sits (hip, knee)
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

local LEGS = { l = { 'luleg', 'llleg' }, r = { 'ruleg', 'rlleg' } }

local function setLegTargets(inst, thigh, shin)
    for _, leg in pairs(LEGS) do
        local upper = actions.ensureKeepAngle(inst.parts[leg[1]], 0, 40)
        local lower = actions.ensureKeepAngle(inst.parts[leg[2]], 0, 40)
        if upper then upper.angle, upper.enabled = thigh, nil end
        if lower then lower.angle, lower.enabled = shin, nil end
    end
end

local function dist(ax, ay, bx, by) return math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2) end

-- turn these parts rigidly about a point (as characterManager.poseTpose does with arms)
local function turnParts(inst, names, px, py, delta)
    local cs, sn = math.cos(delta), math.sin(delta)
    for _, name in ipairs(names) do
        local part = inst.parts[name]
        if part and part.body and not part.body:isDestroyed() then
            local b = part.body
            local x, y = b:getPosition()
            local rx, ry = x - px, y - py
            b:setPosition(px + rx * cs - ry * sn, py + rx * sn + ry * cs)
            b:setAngle(b:getAngle() + delta)
        end
    end
end

local function moveAll(inst, dx, dy)
    for _, part in pairs(inst.parts) do
        local b = part.body
        if b and not b:isDestroyed() then
            local px, py = b:getPosition()
            b:setPosition(px + dx, py + dy)
            b:setLinearVelocity(0, 0)
            b:setAngularVelocity(0)
        end
    end
end

-- A stool as high as a shin plus a foot, and the Mipo put on it already sitting: each leg folded
-- (thigh turned forward about the hip, shin and foot turned back down about the knee), hips just
-- above the seat's front half.
local function seat(inst, dir, x)
    local hx, hy = jointPoint(inst, 'torso1', 'luleg')
    local kx, ky = jointPoint(inst, 'luleg', 'llleg')
    local ax, ay = jointPoint(inst, 'llleg', 'lfoot')
    if not (hx and kx and ax) then return end
    local thigh, shin = dist(hx, hy, kx, ky), dist(kx, ky, ax, ay)
    local foot = math.max(0, GROUND_Y - ay)
    local height = shin + foot
    local width = thigh * 1.2
    local body = love.physics.newBody(world, x - dir * width * 0.25, GROUND_Y - height / 2, 'static')
    love.physics.newFixture(body, love.physics.newRectangleShape(width, height)):setFriction(0.9)
    table.insert(check().stools, body)

    local forward = -dir * math.pi / 2 -- radians: a thigh pointing the way the Mipo faces
    for _, side in ipairs({ 'l', 'r' }) do
        local u, l, f = side .. 'uleg', side .. 'lleg', side .. 'foot'
        local hipX, hipY = jointPoint(inst, 'torso1', u)
        if hipX then
            local delta = forward - inst.parts[u].body:getAngle()
            turnParts(inst, { u, l, f }, hipX, hipY, delta)
            local kneeX, kneeY = jointPoint(inst, u, l)
            turnParts(inst, { l, f }, kneeX, kneeY, -inst.parts[l].body:getAngle())
        end
    end
    local nx, ny = jointPoint(inst, 'torso1', 'luleg')
    moveAll(inst, x - nx, (GROUND_Y - height - thigh * 0.15) - ny)
end

local function sit(on)
    local c = check()
    c.sitting = on
    removeStools()
    for i, inst in pairs(c.mipos) do
        if alive(inst) then
            local side = facing.get(inst)
            if on and side ~= 'front' then
                local dir = side == 'right' and 1 or -1
                seat(inst, dir, xOf(i))
                setLegTargets(inst, -dir * 90, 0) -- degrees (keep-angle): thighs forward, shins down
            else
                setLegTargets(inst, 0, 0)
            end
        end
    end
end

local function makeGround()
    local c = check()
    if c.ground and not c.ground:isDestroyed() then return end
    c.ground = love.physics.newBody(world, 0, GROUND_Y + 50, 'static')
    love.physics.newFixture(c.ground, love.physics.newRectangleShape(SPACING * 5, 100)):setFriction(0.9)
end

local function lookAtAll()
    cam:setScale(ZOOM)
    cam:setTranslation(0, GROUND_Y - 380)
    check().hold = true
end

function s.onStart()
    worldState.paused = false
    makeGround()
    local c = check()
    local any = false
    for _, inst in pairs(c.mipos) do any = any or alive(inst) end
    if not any then newMipos() else placePatches() end
    lookAtAll()
end

function s.onUnload()
    local c = state.facingSpike
    if not c then return end
    removeStools()
    if c.ground and not c.ground:isDestroyed() then c.ground:destroy() end
    c.ground = nil
end

-- Turning: the body and the head turn separately. The body (feet, joint limits, draw order)
-- switches by a rebuild when its angle passes SWITCH_AT, so left -> right is two rebuilds over
-- front; it turns quickly. The head (the face: mipoFacing.angle / applyFace, and the idle gaze)
-- follows slowly, so the eyes pass through every place in between.
local BODY_SPEED = math.rad(120) -- a second
local WALK_TURN_SPEED = 0.6 -- a turn the walk makes (or relaxing back to front): of BODY_SPEED
local HEAD_SPEED = math.rad(30)  -- a second: left -> right (60 degrees) in 2 s
local SWITCH_AT = math.rad(15)
local AUTO_HOLD = 1.2            -- seconds a turning Mipo stays put at a side before turning back
local STEPS = { left = -1, front = 0, right = 1 }
-- A little hop as the body switches: the switch waits until the feet are off the ground, so the
-- swap happens in the air (j: on/off, off to start).
local HOP_SPEED = 450 -- world units a second at 100 px per metre (a jump is 1200)
local HOP_WAIT = 0.25 -- seconds: switch anyway if it hasn't left the ground by then
local SIDE_OF = { [-1] = 'left', [0] = 'front', [1] = 'right' }

local function facingAt(angle)
    if angle <= -SWITCH_AT then return 'left' end
    if angle >= SWITCH_AT then return 'right' end
    return 'front'
end

local function approach(value, target, step)
    if math.abs(target - value) <= step then return target end
    return value + (target > value and step or -step)
end

local function stepFrom(side, dir)
    return SIDE_OF[math.max(-1, math.min(1, (STEPS[side] or 0) + dir))]
end

-- the head's side now: where it is going, else the nearest of the three
local function headSide(inst)
    if inst._headGoal then return inst._headGoal end
    local a = facing.angle(inst) / facing.faceTurn
    return a <= -0.5 and 'left' or a >= 0.5 and 'right' or 'front'
end

local function turnHead(inst, dir)
    inst._turnAngle = inst._turnAngle or facing.angle(inst)
    inst._headGoal = stepFrom(headSide(inst), dir)
end

local function turnBody(inst, dir)
    inst._bodyAngle = inst._bodyAngle or facing.dir(inst) * facing.faceTurn
    inst._turnGoal = stepFrom(inst._turnGoal or facing.get(inst), dir)
end

local function forAll(fn, dir)
    local c = check()
    if c.sitting then sit(false) end
    for _, inst in pairs(c.mipos) do
        if alive(inst) then fn(inst, dir) end
    end
end

local function turnAll(dir) forAll(function(inst) turnBody(inst, dir) turnHead(inst, dir) end) end
local function turnHeads(dir) forAll(turnHead, dir) end

-- auto: back and forth between the sides, a step at a time, once body and head have arrived
local function autoTurn(inst, now)
    if inst._turnGoal or inst._headGoal or now < (inst._turnHoldUntil or 0) then return end
    inst._turnBack = inst._turnBack or (facing.dir(inst) >= 0 and -1 or 1)
    local here = STEPS[facing.get(inst)]
    if here + inst._turnBack < -1 or here + inst._turnBack > 1 then inst._turnBack = -inst._turnBack end
    turnBody(inst, inst._turnBack)
    turnHead(inst, inst._turnBack)
end

local function hop(inst)
    local torso = inst.parts.torso1
    if not (torso and torso.body and not torso.body:isDestroyed()) then return end
    local speed = HOP_SPEED * love.physics.getMeter() / 100
    torso.body:applyLinearImpulse(0, -mipoRegistry.totalMass(inst) * speed)
end

-- The foot that turns leans into its new angle instead of flipping (Nikki: "now it's flip flip
-- flip"): it pivots on its heel, toes up, LEAN of the way to pointing straight up; it is swapped
-- there for the new side's foot leaning as far the other way (where the two look most alike),
-- and that one comes down to its rest. Only the picture leans (extra.leanAngle about the ankle,
-- box2d-draw-textured): the foot standing on the floor carries the Mipo, tipping the body
-- itself fought the floor. f: on/off.
local LEAN = 0.5      -- of the way from its rest to pointing straight up
local LEAN_OUT = 0.12 -- seconds lifting the old foot's toes
local LEAN_IN = 0.16  -- seconds the new foot takes to come down

local function ankleJoint(inst, footName)
    local foot = inst.parts[footName]
    if not (foot and foot.body and not foot.body:isDestroyed()) then return nil end
    for _, joint in ipairs(foot.body:getJoints()) do
        local _, b = joint:getBodies()
        if b == foot.body and joint:getType() == 'revolute' then return joint end
    end
end

-- a foot's rest angle on its shin, by the side's foot it takes (character-topology angleOffset)
local function footOffset(inst, footName)
    return facing.source(inst, footName) == 'lfoot' and math.pi / 2 or -math.pi / 2
end

-- the foot whose side changes when the body goes to want (one per step)
local function turningFoot(inst, want)
    local was, before, name = inst.dna.facing, {}, nil
    for _, n in ipairs({ 'lfoot', 'rfoot' }) do before[n] = facing.source(inst, n) end
    inst.dna.facing = want
    for _, n in ipairs({ 'lfoot', 'rfoot' }) do
        if facing.source(inst, n) ~= before[n] then name = n end
    end
    inst.dna.facing = was
    return name
end

-- the foot's picture, with its ankle as the point it leans about
local function footPicture(inst, footName)
    local joint = ankleJoint(inst, footName)
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

-- a finger holds one of these parts (or, names nil, any part of the Mipo)
local function held(inst, names)
    if names then
        for _, n in ipairs(names) do
            local part = inst.parts[n]
            if part and part.body and not part.body:isDestroyed() and getPJAttachedTo(part.body) then return true end
        end
        return false
    end
    for _, part in pairs(inst.parts) do
        if part.body and not part.body:isDestroyed() and getPJAttachedTo(part.body) then return true end
    end
    return false
end
-- what an in-place switch remakes: a finger on one of them waits the switch out
local REMADE = { 'lfoot', 'rfoot', 'lear', 'rear' }

-- a held Mipo can't be rebuilt whole (its bodies go), and not in place while a remade part is held
local function switchBlocked(inst)
    if check().rebuild then return held(inst) end
    return held(inst, REMADE)
end

local function doSwitch(inst, want)
    inst.dna.armFacing = facing.armFacing(inst) -- the arms keep theirs until updateArms moves them
    if check().rebuild then -- the whole Mipo made again (b: to compare)
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
    local c = check()
    -- not while held there: the switch would pull bodies out from under the finger
    if switchBlocked(inst) or inst._lean then return false end
    if c.hop then
        if not inst._hopAt then
            hop(inst)
            inst._hopAt = now
            return false
        end
        if mipoActions.isGrounded(inst) and now - inst._hopAt < HOP_WAIT then return false end
    end
    inst._hopAt = nil
    if c.lean ~= false and not c.rebuild then
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
-- c.armAt of the way there (0: with the body, 1: when the head arrives; the slider). Turning only
-- the head leaves them with the body.
local function updateArms(inst)
    local c = check()
    local body, arms = facing.get(inst), facing.armFacing(inst)
    if body == arms then return end
    local ratio = facing.angle(inst) / facing.faceTurn -- the head: -1 left .. 1 right
    local at = c.armAt or 0.6
    local ready
    if body == 'right' then ready = ratio >= at
    elseif body == 'left' then ready = ratio <= -at
    else ready = math.abs(ratio) <= 1 - at end
    if ready or not inst._headGoal then characterManager.switchArms(inst, body) end
end

local function updateTurn(inst, dt, now)
    local c = check()
    if c.auto then autoTurn(inst, now) end
    local rebuilt = false
    if inst._lean then updateLean(inst, dt) end
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
        inst._turnAngle = approach(inst._turnAngle or facing.angle(inst), target, HEAD_SPEED * dt)
        if not rebuilt then facing.applyFace(inst) end
        if inst._turnAngle == target then
            inst._headGoal = nil
            -- auto: through the front without stopping
            inst._turnHoldUntil = now + ((c.auto and target ~= 0) and AUTO_HOLD or 0)
        end
    end
    updateArms(inst)
end

-- Autowalk (w): dragged sideways near the floor, a Mipo walks. It turns to face the way it's
-- dragged, and its leg muscles (KEEP_ANGLE targets) step: the thighs swing forward and back in
-- turn, the knee bends on the swing forward. The steps go by how far it is dragged, not by the
-- clock, so a slow drag steps slowly and the feet don't skate. No force of its own: the finger
-- moves it, the legs only step (docs/MIPO-FACING.md).
local STRIDE = 28          -- degrees each thigh swings forward and back
local KNEE = 55            -- degrees the knee bends on the swing forward
local WALK_SPEED = 0.25    -- leg lengths a second: slower than that it stands
-- Turning round takes a real pull (Nikki: no fidgety switching when just pressing it down):
-- dragged one way TURN_DISTANCE leg lengths in all, for TURN_TIME at least. Back the other way
-- starts over, held still it fades (PULL_FADE a second). A turn the walk makes goes slower
-- (WALK_TURN_SPEED, with the turning above).
local TURN_DISTANCE = 0.7  -- leg lengths
local TURN_TIME = 0.3      -- seconds
local PULL_FADE = 1.5      -- 1/s
local GROUND_GRACE = 0.3   -- seconds after a foot last touched that it still counts as on the floor
local RELAX_AFTER = 1.2    -- seconds after it stopped walking that a walked-round Mipo turns back to front
local MAX_STEPS = 2.5      -- steps a second at most: dragged faster, it takes longer strides
local MAX_STRIDE = 48      -- degrees: the longest stride
-- Foot grip while walking: the dragging hand is faster than a Mipo walks, and feet that grip
-- the floor (friction 1) held the legs back, trailing, and tipped the torso into the drag
-- (Nikki's drag, 2026-11-06). The swinging foot hardly grips, the standing one half.
local SWING_GRIP = 0.05
local STANCE_GRIP = 0.5
local FEET = { 'lfoot', 'rfoot' }
-- Feet flat while walking: on their ankles' few degrees the feet turned with the shins, toes into
-- the floor once a shin trailed back, and the swing jammed there (measured 2026-11-06: a shin
-- held at its knee stop, 80 degrees off its target). While walking the ankles bend freely and a
-- muscle holds each foot flat, its toes this much up on the swing.
local TOES_UP = 12 -- degrees
-- Hips: facing a side they only swing forward (sitting, docs/MIPO-FACING.md), so a walking
-- thigh couldn't swing back behind the body (measured: the far leg stuck under it). While
-- walking they get this much room behind.
local HIP_BACK = math.rad(35)

local LEG_PAIRS = { { 'luleg', 'llleg' }, { 'ruleg', 'rlleg' } }

-- the ankle's joint (shin -> foot)
local function ankleOf(inst, footName)
    local foot = inst.parts[footName]
    if not (foot and foot.body and not foot.body:isDestroyed()) then return nil end
    for _, joint in ipairs(foot.body:getJoints()) do
        local _, b = joint:getBodies()
        if b == foot.body and joint:getType() == 'revolute' then return joint end
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

-- the joint between a part and its parent
local function jointTo(inst, parentName, partName)
    local part, parent = inst.parts[partName], inst.parts[parentName]
    if not (part and parent and part.body and not part.body:isDestroyed()) then return nil end
    for _, joint in ipairs(part.body:getJoints()) do
        local a, b = joint:getBodies()
        if a == parent.body and b == part.body and joint:getType() == 'revolute' then return joint end
    end
end

-- hips with room behind (face 1 / -1), or face nil: their limits as the facing set them. The
-- facing's limits are remembered per facing: a turn mid-walk sets new ones (switchFacing).
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
    local foot = inst.parts[footName]
    if not (foot and foot.body and not foot.body:isDestroyed()) then return end
    for _, fixture in ipairs(foot.body:getFixtures()) do
        if not fixture:isSensor() then fixture:setFriction(friction) end
    end
end

local function legLength(inst)
    local hx, hy = jointPoint(inst, 'torso1', 'luleg')
    local ax, ay = jointPoint(inst, 'llleg', 'lfoot')
    if not (hx and ax) then return nil end
    return math.sqrt((ax - hx) ^ 2 + (ay - hy) ^ 2)
end

-- body and head on their way to a side (the turn above takes it from there); slow: the body
-- at WALK_TURN_SPEED
local function turnTo(inst, side, slow)
    if inst._turnGoal == side and inst._headGoal == side then return end
    inst._slowTurn = slow
    inst._bodyAngle = inst._bodyAngle or facing.dir(inst) * facing.faceTurn
    inst._turnAngle = inst._turnAngle or facing.angle(inst)
    inst._turnGoal, inst._headGoal = side, side
end

local function updateWalk(inst, dt, now)
    local c = check()
    if c.walk == false or c.sitting then return end
    local torso = inst.parts.torso1
    if not (torso and torso.body and not torso.body:isDestroyed()) then return end
    local vx = torso.body:getLinearVelocity()
    inst._walkVx = (inst._walkVx or 0) + (vx - (inst._walkVx or 0)) * math.min(1, dt * 8)
    if mipoActions.isGrounded(inst) then inst._groundAt = now end
    local legLen = legLength(inst)
    local walking = legLen and held(inst) and inst._groundAt and now - inst._groundAt < GROUND_GRACE
        and math.abs(inst._walkVx) > legLen * WALK_SPEED
    -- the pull: how far it was dragged one way lately
    local pull = inst._pull or 0
    if not held(inst) or inst._walkVx * pull < 0 then pull, inst._pullStart = 0, now end
    if held(inst) then pull = pull + inst._walkVx * dt end
    inst._pull = pull * math.exp(-dt * PULL_FADE)
    inst._pullStart = inst._pullStart or now
    if not walking then
        -- standing again after a walk: back to front, relaxed (head slow, as any turn)
        if inst._walkTurned and not held(inst) and now - (inst._walkedAt or now) > RELAX_AFTER then
            inst._walkTurned = nil
            if facing.get(inst) ~= 'front' or inst._turnGoal then turnTo(inst, 'front', true) end
        end
        if inst._walking then
            inst._walking = false
            setLegTargets(inst, 0, 0) -- stand
            holdFeet(inst, nil)
            hipsBack(inst, nil)
            for _, n in ipairs(FEET) do setGrip(inst, n, characterManager.footFriction) end
        end
        return
    end
    inst._walking, inst._walkedAt = true, now
    local dir = inst._walkVx > 0 and 1 or -1
    local pullDir = inst._pull > 0 and 1 or -1
    if facing.dir(inst) ~= pullDir and math.abs(inst._pull) > legLen * TURN_DISTANCE
        and now - inst._pullStart >= TURN_TIME then
        turnTo(inst, SIDE_OF[pullDir], true)
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

-- the follow camera moves the view: hold it on the Mipos until you touch, drag or zoom
function s.update()
    local c = check()
    local dt, now = love.timer.getDelta(), love.timer.getTime()
    if not worldState.paused then
        for _, inst in pairs(c.mipos) do
            if alive(inst) then
                updateWalk(inst, math.min(dt, 0.05), now)
                updateTurn(inst, math.min(dt, 0.05), now)
            end
        end
    end
    if not c.hold then return end
    if love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0 or cam.scale ~= ZOOM then
        c.hold = false
    else
        lookAtAll()
    end
end

local function toggleArms()
    facing.arms = not facing.arms
    local sitting = check().sitting
    rebuildAll()
    sit(sitting)
end

function s.onKeyPress(key)
    local c = check()
    if key == 'r' then newMipos() lookAtAll() end
    if key == 's' then sit(not c.sitting) end
    if key == 'a' then toggleArms() end
    if key == 'left' then turnAll(-1) end
    if key == 'right' then turnAll(1) end
    if key == ',' then turnHeads(-1) end
    if key == '.' then turnHeads(1) end
    if key == 't' then c.auto = not c.auto end
    if key == 'j' then c.hop = not c.hop end
    if key == 'b' then c.rebuild = not c.rebuild end
    if key == 'f' then c.lean = c.lean == false end
    if key == 'w' then c.walk = c.walk == false end
    if key == 'p' then worldState.paused = not worldState.paused end
    if key == 'h' then c.showPanel = not c.showPanel end
    if key == 'c' then c.patches = not c.patches placePatches() end
end

function s.drawUI()
    local c = check()
    if not (state.playMode and c.showPanel) then return end
    ui.startFrame() -- play mode draws no editor UI, so nothing else starts the frame
    local BH, pad, w = 34, 6, 300
    local rows = 11
    local h = BH * rows + pad * (rows + 1) + 24
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• facing ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 24 })
        local x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        if ui.button(x, y, w - 12, 'a new Mipo (r)') then newMipos() lookAtAll() end
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        if ui.button(x, y, w - 12, c.sitting and 'stand (s)' or 'sit (s)') then sit(not c.sitting) end
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        if ui.button(x, y, w - 12, 'arms follow: ' .. (facing.arms and 'on' or 'off') .. ' (a)') then toggleArms() end
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        local half = (w - 12 - pad) / 2
        if ui.button(x, y, half, '< turn') then turnAll(-1) end
        if ui.button(x + half + pad, y, half, 'turn >') then turnAll(1) end
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        if ui.button(x, y, half, '< head (,)') then turnHeads(-1) end
        if ui.button(x + half + pad, y, half, 'head > (.)') then turnHeads(1) end
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        local autoLabel = 'turning by itself: ' .. (c.auto and 'on' or 'off') .. ' (t)'
        if ui.button(x, y, w - 12, autoLabel) then c.auto = not c.auto end
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        if ui.button(x, y, w - 12, 'hop at the turn: ' .. (c.hop and 'on' or 'off') .. ' (j)') then
            c.hop = not c.hop
        end
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        if ui.button(x, y, w - 12, 'switch: ' .. (c.rebuild and 'rebuild all' or 'in place') .. ' (b)') then
            c.rebuild = not c.rebuild
        end
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        if ui.button(x, y, w - 12, 'feet: ' .. (c.lean ~= false and 'lean round' or 'flip') .. ' (f)') then
            c.lean = c.lean == false
        end
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        if ui.button(x, y, w - 12, 'autowalk when dragged: ' .. (c.walk ~= false and 'on' or 'off') .. ' (w)') then
            c.walk = c.walk == false
        end
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        local v = ui.sliderWithInput('facing-armAt', x, y, 150, 0, 1, c.armAt or 0.6, nil, 0.05)
        if v then c.armAt = v + 0 end
        ui.label(x + 225, y, 'arms at')
    end)
    love.graphics.setColor(0.95, 0.92, 0.8)
    love.graphics.print('left            front            right', x0 + w + 20, sh - 40, 0, 1.4, 1.4)
    love.graphics.setColor(1, 1, 1)
end

return s

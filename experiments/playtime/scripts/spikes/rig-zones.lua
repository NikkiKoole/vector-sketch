-- rig-zones.lua: places and things in the world that take over a Mipo's skeleton (scene `rigzones`,
-- docs/RIG-ZONES.md), a bit like a vehicle's seat poses its rider (src/vehicle-rides.lua): a zone on a body
-- (a slide, a bench, a bar, a cushion) says what a Mipo whose torso is in it does with its limbs.
--   slide:   sitting, legs straight out down the chute (along its slope where the Mipo is), leaning back,
--            arms up: wheee. Faces the way the chute goes.
--   bench:   sitting: thighs out, shins down, hands on the knees.
--   bar:     arms up; a hand near the bar grips it (a joint), and holds until pulled off hard or far.
--   cushion: flops (a ragdoll) until picked up.
--   crawl:   under something low (a table, a tunnel): ducks, and lower still goes on hands and knees, by how
--            much room there is for its height; moving, its arms and legs go in turn.
--   ladder:  the bar's grip on every rung: drag it up and its hands catch rung after rung; let go, it hangs on.
--   beam:    on a narrow beam: arms out, swaying; near an end, the arms windmill.
--   wind:    blows on everything in it (a force on each part, ears and hair too); a Mipo leans into it, arms
--            streaming downwind.
--   swing:   sits on the seat (welded, like the bench), arms up along the ropes, and pumps: legs out going
--            forward, tucked going back. Stays on when dragged, unless pulled far off.
-- And how a Mipo is dragged (lib.setDrag):
--   normal:  as the engine does it, by the part you press.
--   scruff:  always by the head, whatever you press: lifted upright, legs dangling.
--   hand:    always by the nearest hand: it dangles from it.
--   pose:    a doll: every joint stiff with friction, so it stays as you leave it; the limb you hold is
--            free, so dragging a hand moves the arm and the rest stays put. Held by the torso, all of it.
-- Poses are KEEP_ANGLE targets (world angles, 0 = hanging straight down, + toward the screen's left; the
-- same as the vehicles' POSES) and mipoActions' arm hang (inst._armSwing); what a zone changed is put
-- back when the Mipo leaves it. Walking is held off meanwhile (mipoWalk.hold).
-- Zones live on `state.rigZones` (rebuilt by the scene's onStart; not saved).
local state = require('src.state')
local mipoRegistry = require('src.mipo-registry')
local mipoActions = require('src.mipo-actions')
local mipoWalk = require('src.mipo-walk')
local mipoFacing = require('src.mipo-facing')
local characterManager = require('src.character-manager')
local pointerJoints = require('src.physics.box2d-pointerjoints')

local lib = {}

lib.tuning = {
    kp = 14,          -- the zone poses' muscles (KEEP_ANGLE kp)
    maxOmega = 8,     -- and how fast they may turn a part (rad/s)
    reach = 45,       -- a hand this near the bar grips it (world px)
    grip = 2.5,       -- a grip lets go when pulled this many times the Mipo's weight
    pullAway = 420,   -- or when the finger holding it is this far from the grip (world px)
    poseStiff = 1.5,  -- pose drag: each joint's friction, the Mipo's weight times this share of its height
    lean = 12,        -- slide: degrees leaning back
    crawlAt = 0.65,   -- crawl: less room than this share of its height, on hands and knees (else it ducks)
    bellyAt = 0.48,   -- and less than this, on its belly
    crawlSpeed = 0.35, -- crawl: let go under something low, it goes through at this many heights a second
    sway = 6,         -- beam: degrees of sway
    wind = 0.3,       -- wind: the force on each part, of its weight
    pump = 0.25,      -- swing: a push along the swing while it pumps, of the weight (0: the legs alone)
}

lib.DRAGS = { 'normal', 'scruff', 'hand', 'pose' }

local neckMotor -- (below)

local function data()
    state.rigZones = state.rigZones or { zones = {}, mipos = {}, drag = 'normal' }
    return state.rigZones
end
lib.data = data

local function alive(body) return body ~= nil and not body:isDestroyed() end

-- zone = { kind, body (what it's on), inside(x, y) -> bool, dir (+1: the slide goes right),
--          slopeAt(x) -> radians down (slide), bar = { x1, x2, y } (bar), name }
function lib.addZone(zone)
    local zones = data().zones
    zones[#zones + 1] = zone
    return zone
end

function lib.clearZones() data().zones = {} end

local function zoneAt(x, y)
    for _, z in ipairs(data().zones) do
        if alive(z.body) and z.inside(x, y) then return z end
    end
end
lib.zoneAt = zoneAt

-- ── per Mipo: what a zone changed, to put back ──

-- a part's KEEP_ANGLE set to angle (radians, world; a KEEP_ANGLE holds degrees), its old settings kept the
-- first time
local function keep(inst, rec, name, angle, kp, maxOmega)
    angle = math.deg(angle)
    local part = inst.parts[name]
    if not (part and alive(part.body)) then return end
    local had = mipoActions.getKeepAngle(part)
    local b = mipoActions.ensureKeepAngle(part, angle, kp)
    if not b then return end
    if rec.saved[name] == nil then
        rec.saved[name] = had and { angle = b.angle, kp = b.kp, maxOmega = b.maxOmega, enabled = b.enabled }
            or { none = true }
    end
    b.angle, b.kp, b.maxOmega, b.enabled = angle, kp or lib.tuning.kp, maxOmega or lib.tuning.maxOmega, nil
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

-- the arms to world angles (degrees, as KEEP_ANGLE; one value or { l, r }; elbow: the forearm and hand that
-- much further), on KEEP_ANGLEs like the pointing arm. mipoActions' arm hang is off meanwhile (its
-- _isRagdoll flag, set alone: the legs keep their muscles): through inst._armSwing the walk cleared the
-- arms again every frame after this ran.
local function arms(inst, rec, angle, elbow)
    if rec.wasRagdoll == nil then rec.wasRagdoll = inst._isRagdoll or false end
    inst._isRagdoll = true
    for _, side in ipairs({ 'l', 'r' }) do
        local a = type(angle) == 'table' and angle[side] or angle
        local e = type(elbow) == 'table' and elbow[side] or elbow or 0
        keep(inst, rec, side .. 'uarm', math.rad(a))
        keep(inst, rec, side .. 'larm', math.rad(a + e))
        keep(inst, rec, side .. 'hand', math.rad(a + e))
    end
end

local function clearArms(inst, rec)
    if rec.wasRagdoll ~= nil and not rec.ragdoll then inst._isRagdoll = rec.wasRagdoll end
    rec.wasRagdoll = nil
end

local function faceOf(inst)
    local f = mipoFacing.get(inst)
    return f == 'right' and 1 or f == 'left' and -1 or 0
end

-- turned to face a side: the body, and the head's and body's picture turn with it (the walk's turn sets those
-- as it goes; switchFacing alone left the face looking the way it last turned: a Mipo sliding right looked
-- left, Nikki 2026-11-14)
local function face(inst, dir)
    local want = dir > 0 and 'right' or 'left'
    if mipoFacing.get(inst) ~= want then characterManager.switchFacing(inst, want) end
    -- (from the facing itself: mipoFacing.angle gives the turn under way, the old one, when there is one; and
    -- the face drawn again with it, as the walk's turn does: without, the face kept looking the old way)
    local a = mipoFacing.dir(inst) * mipoFacing.faceTurn
    inst._turnAngle, inst._bodyAngle, inst._headGoal, inst._turnGoal = a, a, nil, nil
    mipoFacing.applyFace(inst)
end

local function totalWeight(inst)
    return mipoRegistry.totalMass(inst) * 9.8 * love.physics.getMeter()
end

local function dropGrips(rec)
    for name, j in pairs(rec.grips) do
        if not j:isDestroyed() then j:destroy() end
        rec.grips[name] = nil
    end
end

-- a sitting Mipo's shins and feet pass through what it sits on (category lib.SEAT): in a side view they
-- hang down in front of the seat. Pushing on it, they shoved the Mipo along the bench and off its end.
lib.SEAT = 15
local function passThrough(inst, rec, names)
    rec.masks = rec.masks or {}
    for _, name in ipairs(names) do
        local part = inst.parts[name]
        for _, f in ipairs(part and alive(part.body) and part.body:getFixtures() or {}) do
            if not f:isSensor() and not rec.masks[f] then
                local mask = { f:getMask() }
                rec.masks[f] = mask
                local more = { unpack(mask) }
                more[#more + 1] = lib.SEAT
                f:setMask(unpack(more))
            end
        end
    end
end

local function restoreMasks(rec)
    for f, mask in pairs(rec.masks or {}) do
        if not f:isDestroyed() then f:setMask(unpack(mask)) end
    end
    rec.masks = nil
end

-- a part's parent (by the Mipo's childrenMap)
local function parentOf(inst, name)
    for parentName, children in pairs(inst.childrenMap or {}) do
        for _, c in ipairs(children) do
            if c == name then return parentName end
        end
    end
end

-- the arms' joints free (shoulder, elbow, wrist): the shoulder's limits stop an arm about level facing front,
-- and the elbow's and wrist's jammed the arm's muscles halfway (an elbow at its limit, forearm and upper arm
-- each turned another way)
local function freeShoulders(inst, rec)
    rec.limits = rec.limits or {}
    for _, name in ipairs({ 'luarm', 'ruarm', 'llarm', 'rlarm', 'lhand', 'rhand' }) do
        local part, parent = inst.parts[name], inst.parts[parentOf(inst, name) or '']
        local j = part and parent and alive(part.body) and alive(parent.body)
            and mipoRegistry.jointBetween(parent.body, part.body, 'revolute')
        if j and rec.limits[j] == nil then
            rec.limits[j] = j:areLimitsEnabled()
            j:setLimitsEnabled(false)
        end
    end
end

local function restoreLimits(rec)
    for j, on in pairs(rec.limits or {}) do
        if not j:isDestroyed() then j:setLimitsEnabled(on) end
    end
    rec.limits = nil
end

-- out of its zone: everything back
local function release(inst, rec)
    for f, friction in pairs(rec.frictions or {}) do
        if not f:isDestroyed() then f:setFriction(friction) end
    end
    rec.frictions = nil
    for j in pairs(rec.motors or {}) do
        if not j:isDestroyed() then j:setMotorEnabled(false) end
    end
    rec.motors = nil
    restoreKeeps(inst, rec)
    restoreLimits(rec)
    restoreMasks(rec)
    clearArms(inst, rec)
    dropGrips(rec)
    if rec.ragdoll then mipoActions.wake(inst) end
    mipoWalk.hold(inst, false)
    inst._noStandUp = nil
    data().mipos[inst.id] = nil
end

local LEGS = { { 'luleg', 'llleg', 'lfoot' }, { 'ruleg', 'rlleg', 'rfoot' } }

local function bodiesOf(inst)
    local out = {}
    for _, part in pairs(inst.parts) do
        if alive(part.body) then out[#out + 1] = part.body end
    end
    return out
end

-- the legs turned to world angles at once (radians by part name), at hip, knee and ankle (as
-- vehicle-rides' poseLegs)
local function poseLegsNow(inst, angles)
    for _, leg in ipairs(LEGS) do
        local parents = { 'torso1', leg[1], leg[2] }
        for i = 1, 3 do
            local name = leg[i]
            local part = inst.parts[name]
            if part and alive(part.body) and angles[name] then
                local px, py = characterManager.jointPoint(inst, parents[i], name)
                local rest = {}
                for k = i, 3 do rest[#rest + 1] = leg[k] end
                if px then characterManager.turnParts(inst, rest, px, py, angles[name] - part.body:getAngle()) end
            end
        end
    end
end

local function lowestOf(inst, names)
    local low = -math.huge
    for _, name in ipairs(names) do
        local part = inst.parts[name]
        for _, f in ipairs(part and alive(part.body) and part.body:getFixtures() or {}) do
            local shape = f:getShape()
            if not f:isSensor() and shape.getPoints then
                local pts = { part.body:getWorldPoints(shape:getPoints()) }
                for i = 2, #pts, 2 do low = math.max(low, pts[i]) end
            elseif not f:isSensor() and shape:getType() == 'circle' then
                local _, cy = part.body:getWorldPoint(shape:getPoint())
                low = math.max(low, cy + shape:getRadius())
            end
        end
    end
    return low
end

-- sat down on a bench at once (the vehicles' way: letting the muscles bend the legs drove the thighs
-- into the seat and flung the Mipo off): upright, legs in the pose, the thighs on the seat where it was
-- let go, the torso held there (a weld)
local function sitDown(inst, rec, zone, d)
    local torso = inst.parts.torso1.body
    local tx, ty = torso:getPosition()
    characterManager.turnBodies(bodiesOf(inst), tx, ty, -torso:getAngle())
    poseLegsNow(inst, { luleg = math.rad(d * -85), ruleg = math.rad(d * -85), llleg = math.rad(d * -3),
        rlleg = math.rad(d * -3), lfoot = 0, rfoot = 0 })
    local hx, hy = characterManager.jointPoint(inst, 'torso1', 'luleg')
    if not hx then hx, hy = torso:getPosition() end
    local low = lowestOf(inst, { 'luleg', 'ruleg' })
    local seat = zone.seatNow and zone.seatNow() or zone.seat -- (a swing's seat moves)
    local dx = math.max(seat.x1 + 60, math.min(seat.x2 - 60, hx)) - hx
    local dy = seat.top - low - 1
    local vx, vy = zone.body:getLinearVelocity()
    for _, b in ipairs(bodiesOf(inst)) do
        local x, y = b:getPosition()
        b:setPosition(x + dx, y + dy)
        b:setLinearVelocity(vx, vy)
        b:setAngularVelocity(0)
    end
    -- welded to the seat while it sits (a springy wheel joint, the vehicles' seat, let the torso bob and spin
    -- against the thighs' muscles: it bounced about)
    local j = love.physics.newWeldJoint(zone.body, torso, hx + dx, hy + dy, false)
    rec.grips.seat = j
    rec.sitAngles = {}
    for _, leg in ipairs(LEGS) do
        for _, name in ipairs(leg) do
            local part = inst.parts[name]
            if part and alive(part.body) then rec.sitAngles[name] = part.body:getAngle() end
        end
    end
end

local function enter(inst, zone)
    local rec = { kind = zone.kind, zone = zone, saved = {}, grips = {} }
    data().mipos[inst.id] = rec
    mipoWalk.hold(inst, true)
    -- posed on purpose: mipoJointGuard's stand-up hop leaves it be (a limb held off its target by the chute or
    -- a limit read as a split, and it hopped about)
    inst._noStandUp = true
    if mipoWalk.drive then mipoWalk.drive(inst, nil) end
    if zone.kind == 'slide' then
        face(inst, zone.dir)
        -- slippery while it slides (its parts' friction 0.02; a Mipo's own grip stopped it on a chute's gentle
        -- top), put back when it's off
        rec.frictions = {}
        for _, part in pairs(inst.parts) do
            for _, f in ipairs(alive(part.body) and part.body:getFixtures() or {}) do
                if not f:isSensor() then
                    rec.frictions[f] = f:getFriction()
                    f:setFriction(0.02)
                end
            end
        end
    elseif zone.kind == 'bench' or zone.kind == 'swing' then
        local f = faceOf(inst)
        face(inst, f ~= 0 and f or zone.dir or 1)
        -- all of it passes through the seat: the hips hang on the seat's joint (a vehicle's way); a thigh's
        -- muscle pushing against the seat shoved the Mipo about
        local names = {}
        for name in pairs(inst.parts) do names[#names + 1] = name end
        passThrough(inst, rec, names)
        if zone.seat or zone.seatNow then sitDown(inst, rec, zone, faceOf(inst) ~= 0 and faceOf(inst) or 1) end
    elseif zone.kind == 'cushion' then
        mipoActions.setRagdoll(inst, true)
        rec.ragdoll = true
    elseif zone.kind == 'crawl' then
        -- facing the way through: from an end toward the other, under it the way it faced (or front: right)
        local tx = inst.parts.torso1.body:getPosition()
        local d = faceOf(inst)
        if tx < zone.x1 then d = 1 elseif tx > zone.x2 then d = -1 elseif d == 0 then d = 1 end
        face(inst, d)
        rec.dir = d
    end
    return rec
end

-- ── the zones' poses, every frame ──

local function slidePose(inst, rec, zone, tx, dt)
    local d = zone.dir
    local theta = math.deg(zone.slopeAt(tx)) -- down the chute, degrees
    -- (soft, slow muscles: at full strength the legs swinging out into the chute flung a Mipo off the slide's
    -- deck and out of the world)
    for _, leg in ipairs(LEGS) do
        keep(inst, rec, leg[1], math.rad(d * (theta - 98)), 8, 3)
        keep(inst, rec, leg[2], math.rad(d * (theta - 94)), 8, 3)
        keep(inst, rec, leg[3], math.rad(d * (theta - 165)), 8, 3)
    end
    keep(inst, rec, 'torso1', math.rad(d * (theta * 0.4 - lib.tuning.lean)), 8, 3)
    arms(inst, rec, d * -125, 0) -- (ahead and a bit up: straight up they caught the chute above, in the sky tower)
    -- sat still on a slide (its gentle top, a dip in the bumpy one): it scoots forward, as kids do
    local torso = inst.parts.torso1.body
    local vx, vy = torso:getLinearVelocity()
    if vx * vx + vy * vy < 40 * 40 then
        rec.stillT = (rec.stillT or 0) + (dt or 1 / 60)
        if rec.stillT > 0.7 then
            rec.stillT = 0
            for _, part in pairs(inst.parts) do
                if alive(part.body) then part.body:applyLinearImpulse(d * part.body:getMass() * 160, 0) end
            end
        end
    else
        rec.stillT = 0
    end
end

-- Held as it sat down: the legs' targets are the angles they ended up at, the arms left to hang as they do.
-- (Aiming them at a pose they couldn't reach, a thigh on the seat, an arm stopped by its shoulder, read as a
-- split to mipoJointGuard, which hopped the Mipo every 1.2 s; freeing the arms let them drive into the seat
-- and throw it about. Nikki 2026-11-14: "mipo moves erratically".)
local function benchPose(inst, rec)
    -- the thighs out on slow, soft muscles (the vehicles' rider's: RIDER_KP 8, RIDER_MAX_OMEGA 2); the shins
    -- and feet slack, hanging down by their weight (held, they ended up straight out along the thighs)
    for _, leg in ipairs(LEGS) do
        if rec.sitAngles and rec.sitAngles[leg[1]] then keep(inst, rec, leg[1], rec.sitAngles[leg[1]], 8, 2) end
        for k = 2, 3 do
            keep(inst, rec, leg[k], 0)
            local b = mipoActions.getKeepAngle(inst.parts[leg[k]])
            if b then b.enabled = false end
        end
    end
    local seat = rec.grips.seat
    if not (seat and not seat:isDestroyed()) then keep(inst, rec, 'torso1', 0, 8, 2) end
end

-- the nearest point on a bar, or on a ladder's nearest rung (bar.rungs: their y's)
local function nearestOnBar(bar, x, y)
    local by = bar.y
    if bar.rungs then
        local best = math.huge
        for _, ry in ipairs(bar.rungs) do
            if math.abs(ry - y) < best then best, by = math.abs(ry - y), ry end
        end
    end
    return math.max(bar.x1, math.min(bar.x2, x)), by
end

-- a rung (or the bar) between two heights: crossed since the last frame
local function crossedRung(bar, was, now)
    for _, ry in ipairs(bar.rungs or { bar.y }) do
        if (was - ry) * (now - ry) <= 0 then return ry end
    end
end

local function pointerWorld(id)
    local sx, sy = pointerJoints.getPointerPosition(id)
    if not sx then return nil end
    return require('src.camera').getInstance():getWorldCoordinates(sx, sy)
end

-- how tall a Mipo stands (measured once, while it's in no zone)
local function standingHeight(inst)
    if not inst._rigH then inst._rigH = characterManager.mipoHeight(inst) end
    return inst._rigH
end

-- A bar, or a ladder's rungs: hands (and on a ladder feet, Nikki 2026-11-14: "the ladder feet should work
-- too") catch the nearest rung when near it or crossing it, and let go when pulled hard for a while or the
-- finger's far off; a foot also when the Mipo's pulled up past it (its leg stretched): it steps up a rung.
local function gripLimb(inst, rec, zone, name, held, dt, weight, isFoot)
    local t = lib.tuning
    local limb = inst.parts[name]
    local j = rec.grips[name]
    local now = love.timer.getTime()
    rec.letGoAt = rec.letGoAt or {}
    if j and j:isDestroyed() then rec.grips[name], j = nil, nil end
    if j then
        local fx, fy = j:getReactionForce(1 / math.max(dt, 1e-3))
        local ax, ay = j:getAnchors()
        local far = false
        if held then
            local wx, wy = pointerWorld(held.id)
            far = wx and math.sqrt((wx - ax) ^ 2 + (wy - ay) ^ 2) > (zone.pullAway or t.pullAway)
        end
        local stretched = false
        if isFoot then
            local tx, ty = inst.parts.torso1.body:getPosition()
            stretched = math.sqrt((tx - ax) ^ 2 + (ty - ay) ^ 2) > 0.62 * standingHeight(inst)
        end
        local force = math.sqrt(fx * fx + fy * fy) / weight
        local fresh = now - (rec.grippedAt or 0) < 0.4 -- (catching the bar jerks)
        -- a pull lasts, a jerk doesn't (dropping into the hang pulled 2.5 x its weight for a frame or two)
        rec.pullT = rec.pullT or {}
        rec.pullT[name] = (force > t.grip and not fresh) and (rec.pullT[name] or 0) + dt or 0
        if far or stretched or rec.pullT[name] > 0.15 then
            j:destroy()
            rec.grips[name] = nil
            rec.letGoAt[name] = now
            rec.why = far and 'pulled away' or stretched and 'stepped up'
                or string.format('pulled %.1f x its weight', force)
        end
    elseif limb and alive(limb.body) and (not rec.letGoAt[name] or now - rec.letGoAt[name] > (isFoot and 0.3 or 0.6)) then
        local hx, hy = limb.body:getPosition()
        local px, py = nearestOnBar(zone.bar, hx, hy)
        -- near the bar, or crossed it since the last frame (a hand lifted fast skips past)
        rec.lastHandY = rec.lastHandY or {}
        local was = rec.lastHandY[name]
        local crossed = was and hx > zone.bar.x1 and hx < zone.bar.x2 and crossedRung(zone.bar, was, hy)
        if crossed then py = crossed end
        -- a foot: not the rung a hand holds, nor one above the Mipo's middle
        local ok = true
        if isFoot then
            local _, ty = inst.parts.torso1.body:getPosition()
            ok = py > ty
            for _, other in ipairs({ 'lhand', 'rhand' }) do
                local hj = rec.grips[other]
                if hj and not hj:isDestroyed() then
                    local _, gy = hj:getAnchors()
                    if math.abs(gy - py) < 5 then ok = false end
                end
            end
        end
        if ok and (crossed or math.sqrt((hx - px) ^ 2 + (hy - py) ^ 2) < t.reach * (isFoot and 1.3 or 1)) then
            -- put on the rung, then held there
            limb.body:setPosition(px, py)
            rec.grips[name] = love.physics.newRevoluteJoint(zone.body, limb.body, px, py, false)
            rec.grippedAt = now
        end
        rec.lastHandY[name] = hy
    end
end

local function barPose(inst, rec, zone, held, dt)
    freeShoulders(inst, rec)
    arms(inst, rec, { l = 172, r = -172 }, 0)
    if not alive(zone.body) then dropGrips(rec) return end
    local weight = totalWeight(inst)
    for _, name in ipairs({ 'lhand', 'rhand' }) do gripLimb(inst, rec, zone, name, held, dt, weight, false) end
    if zone.bar.rungs then
        for _, name in ipairs({ 'lfoot', 'rfoot' }) do gripLimb(inst, rec, zone, name, held, dt, weight, true) end
        -- climbing: dragged with the finger well above, it lets go of its lowest grip every so often (and the
        -- limb catches a higher rung); well below, its highest (held by four grips it didn't budge)
        local now = love.timer.getTime()
        if held and now - (rec.stepAt or 0) > 0.2 then
            local _, wy = pointerWorld(held.id)
            local _, ty = inst.parts.torso1.body:getPosition()
            local H = standingHeight(inst)
            local up = wy and wy < ty - 0.25 * H
            local down = wy and wy > ty + 0.25 * H
            if up or down then
                local pick, pickY
                for name, j in pairs(rec.grips) do
                    if not j:isDestroyed() and name ~= 'seat' then
                        local _, gy = j:getAnchors()
                        if not pickY or (up and gy > pickY) or (down and gy < pickY) then pick, pickY = name, gy end
                    end
                end
                if pick then
                    rec.grips[pick]:destroy()
                    rec.grips[pick] = nil
                    rec.letGoAt = rec.letGoAt or {}
                    rec.letGoAt[pick] = now - 0.25 -- (may catch again soon: the next rung)
                    rec.stepAt = now
                end
            end
        end
    end
end

-- the neck's motor holding the head at an angle to the torso (radians, within the neck's limits)
neckMotor = function(inst, rec, rel)
    local head = inst.parts.head
    local parent = head and inst.parts[parentOf(inst, 'head') or '']
    local j = head and parent and alive(head.body) and alive(parent.body)
        and mipoRegistry.jointBetween(parent.body, head.body, 'revolute')
    if not j then return end
    rec.motors = rec.motors or {}
    rec.motors[j] = true
    local want = rel
    if j:areLimitsEnabled() then want = math.max(j:getLowerLimit(), math.min(j:getUpperLimit(), want)) end
    j:setMotorEnabled(true)
    j:setMotorSpeed((want - j:getJointAngle()) * 8)
    j:setMaxMotorTorque(head.body:getMass() * 9.8 * love.physics.getMeter() * 400)
end


-- Under something low: ducking (knees bent, bent over), or with less room on hands and knees (torso level,
-- thighs down, shins back along the floor, arms down), its arms and legs going in turn while it moves. Let go
-- there, it goes through by itself, the way it faces, once it's down (a held part's muscle is off: dragged by
-- the torso it couldn't bend over). (Turning round when dragged back flipped it to and fro as it rocked.)
local function crawlPose(inst, rec, zone, dt, held)
    local t = lib.tuning
    local torso = inst.parts.torso1.body
    local vx = torso:getLinearVelocity()
    local d = rec.dir or 1
    local H = math.max(50, standingHeight(inst))
    local room = (zone.floor - zone.ceiling) / H
    rec.phase = (rec.phase or 0) + math.abs(vx) * dt / math.max(30, H * 0.12)
    local step = math.min(1, math.abs(vx) / 150) * math.sin(rec.phase)
    local bend
    if room < t.bellyAt then -- flat on its belly, legs trailing, arms reaching forward in turn
        bend = 90
        local sw = 25 * step
        for _, leg in ipairs(LEGS) do
            keep(inst, rec, leg[1], math.rad(d * 95), 8, 3); keep(inst, rec, leg[2], math.rad(d * 95), 8, 3)
            keep(inst, rec, leg[3], math.rad(d * 100), 8, 3)
        end
        arms(inst, rec, { l = d * (-95 + sw), r = d * (-95 - sw) }, 0)
        rec.crawling = 'belly'
    elseif room < t.crawlAt then
        bend = 80
        local sw = 22 * step
        keep(inst, rec, 'luleg', math.rad(d * -sw), 8, 3); keep(inst, rec, 'ruleg', math.rad(d * sw), 8, 3)
        keep(inst, rec, 'llleg', math.rad(d * 88), 8, 3); keep(inst, rec, 'rlleg', math.rad(d * 88), 8, 3)
        keep(inst, rec, 'lfoot', math.rad(d * 90), 8, 3); keep(inst, rec, 'rfoot', math.rad(d * 90), 8, 3)
        arms(inst, rec, { l = d * (-8 + sw), r = d * (-8 - sw) }, 0)
        rec.crawling = true
    else
        bend = 40
        local sw = 15 * step
        keep(inst, rec, 'luleg', math.rad(d * (-40 - sw)), 8, 3); keep(inst, rec, 'ruleg', math.rad(d * (-40 + sw)), 8, 3)
        keep(inst, rec, 'llleg', math.rad(d * 25), 8, 3); keep(inst, rec, 'rlleg', math.rad(d * 25), 8, 3)
        keep(inst, rec, 'lfoot', 0); keep(inst, rec, 'rfoot', 0)
        arms(inst, rec, d * -20, d * -10)
        rec.crawling = false
    end
    keep(inst, rec, 'torso1', math.rad(d * bend), 8, 3)
    -- the head bent over with it, a little less, looking ahead. Kept upright (mipoActions' gaze sets its
    -- KEEP_ANGLE every frame, after this) its neck's limit held the torso back at ~45 degrees: its muscle off,
    -- a motor in the neck holds it at the bend
    keep(inst, rec, 'head', 0)
    local hb = mipoActions.getKeepAngle(inst.parts.head)
    if hb then hb.enabled = false end
    neckMotor(inst, rec, math.rad(-d * 25))
    -- going through: let go, down (the torso near its bend), slower than the speed
    local down = math.abs(math.deg(torso:getAngle()) - d * bend) < 25
    local g = 9.8 * love.physics.getMeter()
    if not held and down and vx * d < t.crawlSpeed * H then
        torso:applyForce(d * 0.35 * mipoRegistry.totalMass(inst) * g, 0)
    elseif not held and not down and zone.x1 then
        -- let go too near the edge to get down (its head on the corner as it bends over): back up a little
        local tx = torso:getPosition()
        local ahead = ((d > 0 and zone.x1 or zone.x2) - tx) * d
        if ahead > 0 and ahead < math.min(H * 0.6, (zone.margin or 600) - 120) and vx * d > -0.2 * H then
            torso:applyForce(-d * 0.3 * mipoRegistry.totalMass(inst) * g, 0)
        end
    end
end

-- On a narrow beam: arms out (a front-facing Mipo's to the sides, a side-facing one's front and back),
-- swaying; near an end the arms windmill and it leans away from the edge.
local function beamPose(inst, rec, zone)
    local t = lib.tuning
    local now = love.timer.getTime() + (rec.seed or 0)
    rec.seed = rec.seed or love.math.random() * 10
    local tx = inst.parts.torso1.body:getPosition()
    local edge = math.min(tx - zone.x1, zone.x2 - tx)
    local sway = t.sway * math.sin(now * 1.3) + t.sway * 0.4 * math.sin(now * 3.1)
    if edge < 140 then
        local away = (tx - zone.x1 < zone.x2 - tx) and 1 or -1 -- toward the middle
        local spin = 75 * math.sin(now * 9)
        keep(inst, rec, 'torso1', math.rad(away * 12 + sway))
        arms(inst, rec, { l = 95 + spin, r = -95 + spin }, 0)
    else
        keep(inst, rec, 'torso1', math.rad(sway))
        arms(inst, rec, { l = 88 - sway * 2, r = -88 - sway * 2 }, 0)
    end
end

-- In the wind: leaning into it, arms streaming downwind with a flutter
local function windPose(inst, rec, zone)
    local now = love.timer.getTime()
    local d = zone.dir
    keep(inst, rec, 'torso1', math.rad(-d * 16))
    local flutter = 10 * math.sin(now * 11 + inst.id:len())
    arms(inst, rec, { l = -d * 66 + flutter, r = -d * 70 - flutter }, 0)
end

-- the wind's push, on every body in a wind zone (Mipo parts, balls, anything loose)
local function blow()
    local world = state.physicsWorld
    if not world then return end
    for _, z in ipairs(data().zones) do
        if z.kind == 'wind' and alive(z.body) then
            local g = 9.8 * love.physics.getMeter()
            for _, b in ipairs(world:getBodies()) do
                if b:getType() == 'dynamic' then
                    local x, y = b:getPosition()
                    if z.inside(x, y) then
                        local gust = 0.75 + 0.25 * math.sin(love.timer.getTime() * 2.3 + x * 0.003)
                        b:applyForce(z.dir * lib.tuning.wind * gust * b:getMass() * g, -0.04 * b:getMass() * g)
                    end
                end
            end
        end
    end
end

-- On a swing: sat (welded to the seat), arms up along the ropes, pumping: legs out going forward, tucked
-- going back. A little push along the way it goes ('pump', 0 for the legs alone) keeps it going.
local function swingPose(inst, rec, zone)
    local t = lib.tuning
    local seat = zone.body
    local d = faceOf(inst)
    if d == 0 then d = 1 end
    local vx = seat:getLinearVelocity()
    local forward = vx * d > 0
    for _, leg in ipairs(LEGS) do
        keep(inst, rec, leg[1], math.rad(d * (forward and -95 or -70)), 8, 4)
        keep(inst, rec, leg[2], math.rad(d * (forward and -85 or 25)), 8, 5)
        keep(inst, rec, leg[3], math.rad(d * (forward and -100 or 20)), 8, 5)
    end
    -- the arms along the ropes, toward the pivot
    local px, py = zone.pivot[1], zone.pivot[2]
    local sx, sy = inst.parts.torso1.body:getPosition()
    local ux, uy = px - sx, py - sy
    local a = math.deg(math.atan2(-ux, uy))
    freeShoulders(inst, rec) -- (a shoulder's limit held one arm down)
    arms(inst, rec, a, 0)
    -- the push, while it's not too high (the seat's angle round the pivot)
    local bx, by = seat:getPosition()
    local swingAngle = math.atan2(bx - px, by - py)
    if t.pump > 0 and math.abs(vx) > 20 and math.abs(swingAngle) < 0.9 then
        local w = (mipoRegistry.totalMass(inst) + seat:getMass()) * 9.8 * love.physics.getMeter()
        seat:applyForce((vx > 0 and 1 or -1) * t.pump * w * math.cos(swingAngle), 0)
    end
end

-- ── dragging ──

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

-- scruff / hand: the press moved to the head or the nearest hand
local function regrab(held)
    local style = data().drag
    if style ~= 'scruff' and style ~= 'hand' then return end
    for inst, h in pairs(held) do
        local target
        if style == 'scruff' then
            target = inst.parts.head or inst.parts.neck1 or inst.parts.torso1
        else
            local bx, by = h.pj.jointBody:getPosition()
            local best = math.huge
            for _, name in ipairs({ 'lhand', 'rhand' }) do
                local p = inst.parts[name]
                if p and alive(p.body) then
                    local x, y = p.body:getPosition()
                    local dd = (x - bx) ^ 2 + (y - by) ^ 2
                    if dd < best then best, target = dd, p end
                end
            end
        end
        if target and alive(target.body) and target.body ~= h.pj.jointBody then
            local x, y = target.body:getPosition()
            pointerJoints.grab(h.id, target.body, x, y)
            h.part = nil
        end
    end
end

-- pose: friction in every joint of every Mipo, the held limb's free
local function jointsOf(inst)
    local out = {}
    for parentName, children in pairs(inst.childrenMap or {}) do
        local parent = inst.parts[parentName]
        for _, childName in ipairs(children) do
            local child = inst.parts[childName]
            if parent and child and alive(parent.body) and alive(child.body) then
                local j = mipoRegistry.jointBetween(parent.body, child.body, 'revolute')
                if j then out[#out + 1] = { joint = j, child = childName } end
            end
        end
    end
    return out
end

local function heightOf(inst)
    local top, bottom = math.huge, -math.huge
    for _, part in pairs(inst.parts) do
        if alive(part.body) then
            local _, y = part.body:getPosition()
            top, bottom = math.min(top, y), math.max(bottom, y)
        end
    end
    return math.max(100, bottom - top)
end

local function poseOn(inst, held)
    local rec = data().mipos[inst.id]
    if not rec or rec.kind ~= 'pose' then
        if rec then release(inst, rec) end
        rec = { kind = 'pose', saved = {}, grips = {}, ragdoll = true, height = heightOf(inst) }
        data().mipos[inst.id] = rec
        mipoWalk.hold(inst, true)
        if mipoWalk.drive then mipoWalk.drive(inst, nil) end
        mipoActions.setRagdoll(inst, true)
    end
    local free = {}
    local h = held[inst]
    local limb = h and h.part and mipoActions.limbOf(h.part)
    if limb then
        for _, name in ipairs(({ larm = { 'luarm', 'llarm', 'lhand' }, rarm = { 'ruarm', 'rlarm', 'rhand' },
            lleg = { 'luleg', 'llleg', 'lfoot' }, rleg = { 'ruleg', 'rlleg', 'rfoot' } })[limb] or {}) do
            free[name] = true
        end
    elseif h and h.part == 'head' then
        free.head = true
    end
    local torque = lib.tuning.poseStiff * totalWeight(inst) * rec.height * 0.25
    for _, e in ipairs(jointsOf(inst)) do
        local j = e.joint
        if free[e.child] then
            j:setMotorEnabled(false)
        else
            j:setMotorEnabled(true)
            j:setMotorSpeed(0)
            j:setMaxMotorTorque(torque)
        end
    end
end

local function poseOff(inst, rec)
    for _, e in ipairs(jointsOf(inst)) do e.joint:setMotorEnabled(false) end
    release(inst, rec)
end

function lib.setDrag(style)
    local dat = data()
    if dat.drag == 'pose' and style ~= 'pose' then
        for id, rec in pairs(dat.mipos) do
            local inst = mipoRegistry.getById(id)
            if rec.kind == 'pose' and inst then poseOff(inst, rec) end
        end
    end
    dat.drag = style
end

-- ── every frame ──
local LET_GO = { slide = true, bench = true, cushion = true, beam = true, swing = true }

function lib.update(dt)
    local dat = data()
    local held = heldMipos()
    regrab(held)
    blow()
    for _, inst in pairs(mipoRegistry.getAll()) do
        local torso = inst.parts and inst.parts.torso1
        if torso and alive(torso.body) then
            local rec = dat.mipos[inst.id]
            if dat.drag == 'pose' then
                poseOn(inst, held)
            else
                local tx, ty = torso.body:getPosition()
                local zone = zoneAt(tx, ty)
                local h = held[inst]
                if not rec and not zone then standingHeight(inst) end
                -- slides, benches, cushions, beams and swings take a Mipo that's let go; the rest one held too
                if zone and h and LET_GO[zone.kind] then
                    -- (on a swing it stays while dragged, unless pulled far off)
                    local stay = false
                    if rec and rec.zone == zone and zone.kind == 'swing' then
                        local wx, wy = pointerWorld(h.id)
                        local sx, sy = zone.body:getPosition()
                        stay = wx ~= nil and math.sqrt((wx - sx) ^ 2 + (wy - sy) ^ 2) < lib.tuning.pullAway
                    end
                    if not stay then zone = nil end
                end
                -- a Mipo gripping a bar or a ladder stays on it out of the zone
                if not zone and rec and (rec.kind == 'bar' or rec.kind == 'ladder') and next(rec.grips) then
                    zone = rec.zone
                end
                if rec and (not zone or rec.zone ~= zone) then
                    release(inst, rec)
                    rec = nil
                end
                if zone and not rec then rec = enter(inst, zone) end
                if rec then
                    if zone.kind == 'slide' then slidePose(inst, rec, zone, tx, dt)
                    elseif zone.kind == 'bench' then benchPose(inst, rec)
                    elseif zone.kind == 'bar' or zone.kind == 'ladder' then barPose(inst, rec, zone, h, dt)
                    elseif zone.kind == 'crawl' then crawlPose(inst, rec, zone, dt, h)
                    elseif zone.kind == 'beam' then beamPose(inst, rec, zone)
                    elseif zone.kind == 'wind' then windPose(inst, rec, zone)
                    elseif zone.kind == 'swing' then swingPose(inst, rec, zone)
                    end
                end
            end
        end
    end
    -- Mipos gone: forget them
    for id in pairs(dat.mipos) do
        if not mipoRegistry.getById(id) then dat.mipos[id] = nil end
    end
end

-- everything back (the scene unloading, or its script reloading)
function lib.unload()
    local dat = data()
    for id, rec in pairs(dat.mipos) do
        local inst = mipoRegistry.getById(id)
        if inst then
            if rec.kind == 'pose' then poseOff(inst, rec) else release(inst, rec) end
        end
    end
    dat.mipos, dat.drag = {}, 'normal'
    -- (the zones stay: a reload of the scene's script keeps its bodies; a zone whose body is gone is skipped,
    -- and the scene clears them when it builds its things again)
end

-- the wind: streaks blowing through its zones
function lib.drawWind()
    love.graphics.push('all')
    love.graphics.setLineWidth(5)
    local now = love.timer.getTime()
    for _, z in ipairs(data().zones) do
        if z.kind == 'wind' and z.box then
            local x1, y1, x2, y2 = z.box[1], z.box[2], z.box[3], z.box[4]
            local w = x2 - x1
            for i = 1, 26 do
                local y = y1 + (y2 - y1) * ((i * 0.618) % 1)
                local speed = 700 + (i * 137) % 500
                local x = x1 + ((now * speed * z.dir + i * 911) % w + w) % w
                local len = 80 + (i * 53) % 120
                local wob = 8 * math.sin(now * 3 + i)
                love.graphics.setColor(1, 1, 1, 0.25)
                love.graphics.line(x, y + wob, x - z.dir * len, y + wob * 0.3)
            end
        end
    end
    love.graphics.pop()
end

-- the zones drawn (editor help: outlines and names)
function lib.drawZones()
    love.graphics.push('all')
    love.graphics.setLineWidth(4)
    for _, z in ipairs(data().zones) do
        if z.outlineNow then z.outline = z.outlineNow() end
        if z.outline then
            love.graphics.setColor(1, 0.85, 0.3, 0.5)
            love.graphics.line(z.outline)
            love.graphics.print(z.kind, z.outline[1], z.outline[2] - 40, 0, 3, 3)
        end
    end
    love.graphics.pop()
end

return lib

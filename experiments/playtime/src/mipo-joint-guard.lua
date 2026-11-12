-- mipo-joint-guard.lua
-- Keeps Mipo ragdolls sane when they're dragged around hard. Each fix has its
-- own switch so they can be compared in play (see docs/DOLL-PLAY.md, found with
-- src/flight-recorder.lua: fast circles wound a shoulder ~6 turns past its limit).
--
-- unwind: Box2D counts a revolute joint's angle cumulatively. A limb spun whole
--   turns past its limit gets pulled back the long way round and stays twisted.
--   Turning the limb by whole turns looks identical but un-twists the joint.
-- heal: when a joint is torn open (anchors far apart), move the child part and
--   everything hanging below it back onto the parent's anchor, moving at the
--   parent's speed. Stops limbs flying far out or ending up through the floor.
--   Only while the Mipo is held (and just after release): in a resting pile,
--   squashed joints passed the threshold and healing teleported limbs into
--   neighbours, pumping energy in until the pile exploded out of the world.
-- unstick: a part on the wrong side of a wall or floor (a foot or an ear pushed
--   through, the rest of the Mipo on the other side) can't come back: the joint
--   pulls it against the wall forever. Seen as something static and solid across
--   the limb (parent centre -> joint -> child centre). The smaller side (the
--   stuck part and what hangs off it) turns into a ghost (its collision shapes
--   become sensors) so the joint pulls it back through; it gets its collision
--   back once it's clear, or after unstickMaxTime. Logged ('[unstick] ...') with
--   whether the Mipo was held, to learn when it happens. Not held or held alike.
-- standUp: a Mipo that lands in a split can't get up by turning its legs alone
--   (or its arms, in a handstand)
--   (they'd have to lift the whole body), so after a moment of splayed legs it
--   hops, again after a pause if needed. Only on the ground, not while held or
--   leaning on others.
local JT = require('src.joint-types')
local box2dPointerJoints = require('src.physics.box2d-pointerjoints')
local state = require('src.state')
local mipoRegistry = require('src.mipo-registry')
local registry = require('src.registry')
local utils = require('src.utils')
local mathutils = require('src.math-utils')
local units = require('src.physics-units') -- speeds below are as at 100 px per metre
local contactTracker = require('src.physics.contact-tracker')

local lib = {}

lib.unwind = true
lib.heal = true
lib.healDistance = 40 -- world units between joint anchors before a limb is pulled back
                      -- (recorded: up to ~12 while fine, 60-1000 once torn)
lib.healAfterRelease = 1.0 -- seconds healing stays on after a Mipo is let go (throws)

lib.unstick = true
lib.unstickDistance = 15  -- joint halves further apart than this, with a wall between, is stuck
lib.unstickMaxTime = 2.0  -- seconds a part stays a ghost at most

-- untangle: two Mipos knotted together (a limb of one through the other, see
-- lib.hooks; a Mipo sitting on another has no hooks) that stay knotted for
-- untangleAfter seconds, neither held, come apart: the upper one hops up and away
-- from the other, and the two pass through each other (their contacts switched
-- off in preSolve) until no limb crosses the other and nothing overlaps (at most
-- untangleMaxTime); then that pair rests untangleRest. Passing through alone left
-- them deep inside each other, re-hooking; a sideways drift stuck on grippy feet
-- and walls. Logged '[untangle] a and b'.
lib.untangle = true
lib.untangleAfter = 2.0     -- seconds knotted (and let go) before it untangles
lib.untangleMaxTime = 4.0   -- seconds of passing through at most
lib.untangleMinTime = 0.05  -- ...and at least (contacts are only there after a step)
lib.untangleRest = 3.0      -- seconds before the same pair untangles again
lib.untangleRetry = 0.5     -- ...but if the time ran out while still hooked, this soon
lib.untangleHop = { 250, 650 } -- the hop out: sideways (away from the other), up (world units/s)
-- A Mipo that has to untangle again and again stops trying: wedged between two others, standing
-- on their feet with its hands caught, it hopped away from one into the other, fell back with
-- contacts off and re-hooked, every ~2.5 s for good (scripts/tests/feet-pile, 2026-11-01). After
-- untangleMaxTries in untangleQuiet seconds it stays put and collides; picking it up starts over.
lib.untangleLetsGo = true -- an untangle starts with the two letting go of each other's hands
lib.untangleMaxTries = 4
lib.untangleQuiet = 60
lib.untangleCheckEvery = 0.25
-- Each Mipo is looked over for hooks once every this many physics steps (a slice of them each
-- step): ~0.43 s at 84 steps a second. The raycasts were ~0.3 ms a frame with 20 Mipos on an
-- iPhone SE 2 at every 12 steps (2026-10-31), and an untangle waits untangleAfter (2 s) anyway.
-- A hook seen within this many steps counts as still there.
lib.hookCheckSteps = 36

-- passThrough: Mipos put down overlapping (several stepping out of one door, src/doors.lua)
-- pass through each other, still standing on the floor, while a soft sideways push moves
-- them apart; each pair collides again once nothing overlaps (at most passThroughMaxTime).
-- The dismount trick from physics-testbed's downhill scene, but between Mipos only: there
-- the parts became sensors and would have fallen through the floor.
lib.passThroughMaxTime = 4.0
lib.passThroughSpeed = 220 -- the sideways speed the push brings an overlapping Mipo up to (units/s)

-- pileKick: in a pile (a Mipo touching other Mipos through a hundred-odd contacts) a
--   limb squeezed between heavier parts now and then shoots out at 3000-11000 units/s and
--   takes its Mipo along, out of a box or out of the room. Box2D caps a step at 2 metres:
--   at the 30 px per metre the specs used to run at that hid it (3600/s), at the game's
--   100 it doesn't (12000/s). A Mipo nobody holds or just threw, touching another Mipo,
--   goes no faster than pileMaxSpeed.
lib.pileKick = true
lib.pileMaxSpeed = 3000

lib.standUp = true
lib.splayedAngle = math.rad(30) -- further than this from its target counts as splayed (50 let a
                                -- wide stance on grippy feet tug forever instead of hopping to reset)
lib.splayedFor = 0.6            -- seconds of splayed legs before a hop
lib.standUpPause = 1.2          -- seconds between hops
lib.standUpSpeed = 500          -- hop speed (world units/s), like the grab hop

-- standUp and the search for newly stuck limbs look for things that last half a second
-- or more, so each Mipo (each joint, for stuck) is looked at once every this many physics
-- steps, a slice of them on every step: all at once, with 20 Mipos, they were 2-3 ms
-- spikes (contacts of every part, three raycasts per joint) that threw the fixed timestep
-- off. Counted in steps, not seconds, so a slow frame or a spec stepping faster than real
-- time sees the same thing. Heal and pulling a ghost back run every step.
lib.slowCheckSteps = 12
-- Going through every Mipo's joints (unwind, and the search for stuck limbs, which then
-- comes round every slowCheckSteps scans) happens every this many steps
lib.scanEvery = 2

local lastHeld = {} -- [mipoId] = time the Mipo was last held by a pointer
-- [pairKey] = { a, b, since, untilT, restUntil }; on state: preSolve reads it every step
state.mipoTangles = state.mipoTangles or {}
local tangles = state.mipoTangles
local lastTangleCheck = 0
local stepCount = 0
local scanCount = 0 -- the steps that went through every Mipo's joints (lib.scanEvery)
local splayedSince = {} -- [mipoId] = time its legs became splayed
local lastStandUp = {}  -- [mipoId] = time of its last stand-up hop
-- Parts that can carry the Mipo: legs normally, arms in a handstand (flip).
local supportParts = { 'luleg', 'ruleg', 'llleg', 'rlleg', 'luarm', 'ruarm', 'llarm', 'rlarm' }

lib.stats = { unwound = 0, healed = 0, standUps = 0, standUpsByMipo = {}, unstuck = 0 }
lib.unstuckLog = {} -- the last few cases: { part, through, distance, held, at }

-- [joint] = { fixtures = {...}, since = time }: parts made ghosts by unstick.
-- On state so a hot reload doesn't leave parts as sensors forever.
state.mipoGhosts = state.mipoGhosts or {}
local ghosts = state.mipoGhosts

local TWO_PI = 2 * math.pi

-- Whole turns to take off a joint angle so it lands within half a turn of the
-- middle of its limits (0 when it already does).
function lib.turnsToUnwind(angle, lower, upper)
    local mid = (lower + upper) / 2
    local turns = (angle - mid) / TWO_PI
    if turns > 0.5 then return math.floor(turns + 0.5) end
    if turns < -0.5 then return math.ceil(turns - 0.5) end
    return 0
end

-- A Mipo's revolute joints, from its own list (instance.joints: 'parent->child' = id).
-- Scanning every joint in the world and looking up both bodies' Mipo was most of
-- this module's per-step cost with 20 Mipos.
local function eachRevolute(instance, fn)
    for _, jointId in pairs(instance.joints or {}) do
        local joint = registry.getJointByID(jointId)
        if joint and not joint:isDestroyed() and joint:getType() == JT.REVOLUTE then fn(joint) end
    end
end

local function unwindJoints(joints)
    -- turning one body changes the angle of its other joints by whole turns too;
    -- a few passes settle a whole limb chain
    for _ = 1, 4 do
        local changed = false
        for _, joint in ipairs(joints) do
            local turns = lib.turnsToUnwind(joint:getJointAngle(), joint:getLowerLimit(), joint:getUpperLimit())
            if turns ~= 0 then
                local _, bodyB = joint:getBodies()
                bodyB:setAngle(bodyB:getAngle() - turns * TWO_PI)
                lib.stats.unwound = lib.stats.unwound + 1
                changed = true
            end
        end
        if not changed then return end
    end
end

local function collectSubtree(instance, partName, out)
    out[#out + 1] = partName
    for _, child in ipairs(instance.childrenMap and instance.childrenMap[partName] or {}) do
        collectSubtree(instance, child, out)
    end
    return out
end

-- A wall: something static and solid. state.passableBodies (a set of bodies, kept by a scene)
-- names static bodies Mipos pass through or in front of (the depth spike's back and front layers,
-- scripts/spikes/depth.playtime.lua): a limb across one isn't stuck.
local function isWall(fixture)
    local body = fixture:getBody()
    if body:getType() ~= 'static' or fixture:isSensor() then return false end
    -- a coaster track's rail: crossed by whatever rides its other lane (src/track.lua)
    if fixture:getType() == 'chain' and require('src.track').trackOf(fixture) then return false end
    local passable = state.passableBodies
    return not (passable and passable[body])
end

-- Joints are made parent (body A) -> child (body B), see character-manager.
-- Is there a wall (anything static) between the two points? Healing is a
-- teleport (setPosition), which skips Box2D's tunnelling protection: a limb
-- torn across a thin wall was put straight into it and got stuck.
local function wallBetween(x1, y1, x2, y2)
    if (x2 - x1) ^ 2 + (y2 - y1) ^ 2 < 1 then return false end
    local blocked = false
    state.physicsWorld:rayCast(x1, y1, x2, y2, function(fixture)
        if isWall(fixture) then
            blocked = true
            return 0
        end
        return -1
    end)
    return blocked
end

local function healJoint(joint)
    local x1, y1, x2, y2 = joint:getAnchors()
    local dx, dy = x1 - x2, y1 - y2
    if dx * dx + dy * dy < lib.healDistance * lib.healDistance then return end
    if wallBetween(x2, y2, x1, y1) then
        lib.stats.healBlocked = (lib.stats.healBlocked or 0) + 1
        return -- leave it to the joint itself; it pulls the limb around the wall
    end
    local bodyA, bodyB = joint:getBodies()
    local instance, childName = mipoRegistry.getFromBody(bodyB)
    if not instance then return end
    local vx, vy = bodyA:getLinearVelocityFromWorldPoint(x1, y1)
    for _, name in ipairs(collectSubtree(instance, childName, {})) do
        local part = instance.parts[name]
        local body = part and part.body
        if body and not body:isDestroyed() then
            local bx, by = body:getPosition()
            body:setPosition(bx + dx, by + dy)
            body:setLinearVelocity(vx, vy)
        end
    end
    lib.stats.healed = lib.stats.healed + 1
end

-- The static, solid fixture between two points, if any.
local function wallFixtureBetween(x1, y1, x2, y2)
    -- Box2D asserts on a zero-length ray (anchors exactly on top of each other), and on a NaN one (a blown-up
    -- body's anchors: NaN fails every comparison, so `< 1` let it through; 2026-11-12 in burrow)
    if not ((x2 - x1) ^ 2 + (y2 - y1) ^ 2 >= 1) then return nil end -- luacheck: ignore 581 (NaN)
    local found
    state.physicsWorld:rayCast(x1, y1, x2, y2, function(fixture)
        if isWall(fixture) then
            found = fixture
            return 0
        end
        return -1
    end)
    return found
end

local function fixtureLabel(fixture)
    local thing = utils.thingOf(fixture:getBody())
    return thing and (thing.label ~= '' and thing.label or thing.shapeType) or '?'
end

-- The parts on the smaller side of a joint: the child's subtree, or everything
-- else when that's smaller (the torso went through, a limb stayed behind).
local function smallerSide(instance, childName)
    local subtree = collectSubtree(instance, childName, {})
    local total = 0
    for _ in pairs(instance.parts) do total = total + 1 end
    if #subtree <= total / 2 then return subtree, childName end
    local inSubtree, rest = {}, {}
    for _, name in ipairs(subtree) do inSubtree[name] = true end
    for name in pairs(instance.parts) do
        if not inSubtree[name] then rest[#rest + 1] = name end
    end
    return rest, 'rest of ' .. tostring(instance.id)
end

local function partBodies(instance, names)
    local bodies = {}
    for _, name in ipairs(names) do
        local part = instance.parts[name]
        if part and part.body and not part.body:isDestroyed() then bodies[#bodies + 1] = part.body end
    end
    return bodies
end

-- Is the body overlapping something static and solid? (A ghost is a sensor, and
-- sensors still get contacts.)
local function touchingWall(body)
    for _, contact in ipairs(body:getContacts()) do
        if contact:isTouching() then
            local fa, fb = contact:getFixtures()
            local other = fa:getBody() == body and fb or fa
            if isWall(other) then return true end
        end
    end
    return false
end

-- A wall across the limb: on the path parent centre -> joint -> child centre.
-- (Only the anchors apart missed the resting case: the joint closed at the
-- floor's surface, the foot hanging under it.)
local function wallAcrossLimb(joint)
    local bodyA, bodyB = joint:getBodies()
    local x1, y1, x2, y2 = joint:getAnchors()
    local ax, ay = bodyA:getPosition()
    local bx, by = bodyB:getPosition()
    return wallFixtureBetween(ax, ay, x1, y1) or wallFixtureBetween(x1, y1, x2, y2)
        or wallFixtureBetween(x2, y2, bx, by)
end

-- Another Mipo's part across a limb: a hook, the two tangled. In a stack the
-- limbs rest ON the other Mipo (feet on a head), nothing crosses them; in a knot
-- a limb went through and wraps around the other's arm, leg or body. Returns
-- the first part of another Mipo on the path parent centre -> joint -> child
-- centre (the wallAcrossLimb path), and that Mipo.
-- A Mipo in another lane (instance.lane, the depth spike's back lane) passes by, it can't hook.
-- With state.legsPassMipos (lib.onPreSolve) legs go through other Mipos, so they can't hook either:
-- another Mipo's leg across a limb isn't a hook, and nor is anything across a Mipo's own legs (the
-- hip, knee and ankle paths); counted as hooks, they set off untangle after untangle.
local LEG = { luleg = true, ruleg = true, llleg = true, rlleg = true }
local LEG_PATH = { luleg = true, ruleg = true, llleg = true, rlleg = true, lfoot = true, rfoot = true }
local function otherMipoAcross(x1, y1, x2, y2, ownId, ownLane)
    if (x2 - x1) ^ 2 + (y2 - y1) ^ 2 < 1 then return nil end
    local found, foundInstance
    local legsPass = state.legsPassMipos
    state.physicsWorld:rayCast(x1, y1, x2, y2, function(fixture)
        if fixture:isSensor() then return -1 end
        local instance, partName = mipoRegistry.getFromBody(fixture:getBody())
        if legsPass and LEG[partName] then return -1 end
        if instance and instance.id ~= ownId and instance.lane == ownLane then
            found, foundInstance = fixture, instance
            return 0
        end
        return -1
    end)
    return found, foundInstance
end

-- Every hook right now: { a = the Mipo whose limb, b = the Mipo across it, part, through }.
local function hooksOf(owner, result)
    eachRevolute(owner, function(joint)
        local bodyA, bodyB = joint:getBodies()
        local instance, partName = mipoRegistry.getFromBody(bodyB)
        if instance and not (state.legsPassMipos and LEG_PATH[partName]) then
            local x1, y1, x2, y2 = joint:getAnchors()
            local ax, ay = bodyA:getPosition()
            local bx, by = bodyB:getPosition()
            local fixture, other = otherMipoAcross(ax, ay, x1, y1, instance.id, instance.lane)
            if not fixture then fixture, other = otherMipoAcross(x1, y1, x2, y2, instance.id, instance.lane) end
            if not fixture then fixture, other = otherMipoAcross(x2, y2, bx, by, instance.id, instance.lane) end
            if fixture then
                local _, through = mipoRegistry.getFromBody(fixture:getBody())
                result[#result + 1] = { a = instance, b = other, part = partName, through = through }
            end
        end
    end)
    return result
end

function lib.hooks()
    local result = {}
    if not state.physicsWorld then return result end
    for _, owner in pairs(mipoRegistry.getAll()) do hooksOf(owner, result) end
    return result
end

local function jointKey(joint)
    local _, bodyB = joint:getBodies()
    local thing = utils.thingOf(bodyB)
    return thing and thing.id
end

local function ghost(joint, instance, childName, wall, distance, now)
    local names, what = smallerSide(instance, childName)
    local fixtures = {}
    for _, body in ipairs(partBodies(instance, names)) do
        for _, fixture in ipairs(body:getFixtures()) do
            if not fixture:getUserData() and not fixture:isSensor() then
                fixture:setSensor(true)
                fixtures[#fixtures + 1] = fixture
            end
        end
    end
    -- moving the child side pulls it to the parent's anchor; moving the rest, the other way
    ghosts[jointKey(joint)] = { joint = joint, instance = instance, names = names, fixtures = fixtures,
        since = now, childSide = what == childName }
    lib.stats.unstuck = lib.stats.unstuck + 1
    local held = lastHeld[instance.id] ~= nil and now - lastHeld[instance.id] < 0.1
    local case = { part = what, through = fixtureLabel(wall), distance = math.floor(distance), held = held, at = now }
    table.insert(lib.unstuckLog, case)
    if #lib.unstuckLog > 20 then table.remove(lib.unstuckLog, 1) end
    print(string.format('[unstick] %s through %s, %d apart, %s', case.part, case.through, case.distance,
        held and 'held' or 'not held'))
end

local function unghost(key)
    for _, fixture in ipairs(ghosts[key].fixtures) do
        if not fixture:isDestroyed() then fixture:setSensor(false) end
    end
    ghosts[key] = nil
end

lib.unstickPull = 6 -- a ghost moves toward the good side's centre at this many times the gap per second

-- joints: the revolute joints to look through, a slice at a time (empty on steps without a
-- scan); `slice` counts scans, not steps, so every joint still comes round
local function unstickJoints(joints, now, scan)
    -- ghosts first: pull them toward the good side, solid again once they're clear
    for key, entry in pairs(ghosts) do
        local joint = entry.joint
        if not joint or joint:isDestroyed() or not entry.instance then -- gone, or left by an older version
            unghost(key)
        else
            local bodyA, bodyB = joint:getBodies()
            local good = entry.childSide and bodyA or bodyB
            local gx, gy = good:getPosition()
            local bodies = partBodies(entry.instance, entry.names)
            local clear = not wallAcrossLimb(joint)
            for _, body in ipairs(bodies) do
                if clear and touchingWall(body) then clear = false end
            end
            if clear or now - entry.since > lib.unstickMaxTime then
                unghost(key)
            else
                local vx, vy = good:getLinearVelocity()
                local pull = units.rate(lib.unstickPull)
                for _, body in ipairs(bodies) do
                    local x, y = body:getPosition()
                    body:setLinearVelocity(vx + (gx - x) * pull, vy + (gy - y) * pull)
                end
            end
        end
    end
    local slice = scan % lib.slowCheckSteps
    for j, joint in ipairs(joints) do
        if j % lib.slowCheckSteps == slice and not ghosts[jointKey(joint)] then
            local wall = wallAcrossLimb(joint)
            if wall then
                local _, bodyB = joint:getBodies()
                local instance, childName = mipoRegistry.getFromBody(bodyB)
                local x1, y1, x2, y2 = joint:getAnchors()
                local gap = math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)
                if instance then ghost(joint, instance, childName, wall, gap, now) end
            end
        end
    end
end

local function markHeldMipos(now)
    for _, pointerJoint in ipairs(box2dPointerJoints.getPointerJoints()) do
        local body = pointerJoint.jointBody
        if body and not body:isDestroyed() then
            local instance = mipoRegistry.getFromBody(body)
            if instance then lastHeld[instance.id] = now end
        end
    end
end


-- Splayed: a supporting part that is holding a target (KEEP_ANGLE enabled) is
-- far from that target. Follows the actions in src/mipo-actions.lua: upright
-- legs normally, down-pointing arms when flipped, nothing when ragdolled.
local function isSplayed(instance)
    for _, name in ipairs(supportParts) do
        local part = instance.parts[name]
        if part and part.body and not part.body:isDestroyed() then
            local thing = utils.thingOf(part.body)
            for _, behavior in ipairs(thing and thing.behaviors or {}) do
                -- limp parts (held limb, idle slump) are slack on purpose
                if behavior.name == 'KEEP_ANGLE' and behavior.enabled ~= false and not part.limp then
                    local diff = part.body:getAngle() - math.rad(behavior.angle or 0)
                    diff = mathutils.wrapAngle(diff)
                    if math.abs(diff) > lib.splayedAngle then return true end
                end
            end
        end
    end
    return false
end

local function solidOtherMipo(own, other, otherBody, instance)
    if own:isSensor() or other:isSensor() then return false end
    local otherMipo = mipoRegistry.getFromBody(otherBody)
    return otherMipo ~= nil and otherMipo ~= instance
end

local function solidNotMipo(own, other, otherBody)
    return not own:isSensor() and not other:isSensor() and not mipoRegistry.getFromBody(otherBody)
end

-- Does any part of the Mipo touch something `test` likes (src/physics/contact-tracker.lua)?
local function partsTouch(instance, test)
    for _, part in pairs(instance.parts) do
        local body = part.body
        if body and not body:isDestroyed() and contactTracker.any(body, test, instance) then return true end
    end
    return false
end

-- Any part resting against another Mipo (a pile). Props like a skateboard don't count.
local function leaningOnOthers(instance)
    return partsTouch(instance, solidOtherMipo)
end

-- Any part resting on something that isn't a Mipo (floor, wall, skateboard,
-- slide): no stand-up hops mid-air. Static-only missed a Mipo on a skateboard.
local function onGround(instance)
    return partsTouch(instance, solidNotMipo)
end

local function standUpMipo(id, instance, now)
    local torso = instance.parts.torso1
    local held = lastHeld[id] and now - lastHeld[id] <= lib.healAfterRelease
    if not torso or held or not isSplayed(instance) or not onGround(instance) then
        splayedSince[id] = nil
    elseif not splayedSince[id] then
        splayedSince[id] = now
    elseif now - splayedSince[id] >= lib.splayedFor
        and (not lastStandUp[id] or now - lastStandUp[id] >= lib.standUpPause)
        and not leaningOnOthers(instance) then
        local mass = 0
        for _, part in pairs(instance.parts) do mass = mass + part.body:getMass() end
        torso.body:applyLinearImpulse(0, -mass * units.speed(lib.standUpSpeed))
        lastStandUp[id] = now
        lib.stats.standUps = lib.stats.standUps + 1
        lib.stats.standUpsByMipo[id] = (lib.stats.standUpsByMipo[id] or 0) + 1
    end
end

local function standUpMipos(now)
    local slice, k = stepCount % lib.slowCheckSteps, 0
    for id, instance in pairs(mipoRegistry.getAll()) do
        k = k + 1
        if k % lib.slowCheckSteps == slice then standUpMipo(id, instance, now) end
    end
end

local function pairKey(idA, idB)
    if idA > idB then idA, idB = idB, idA end
    return idA .. '|' .. idB, idA, idB
end

-- Do any parts of Mipos a and b overlap? (Contacts switched off in preSolve
-- still report touching while the shapes overlap.)
local function overlapping(idA, idB)
    local instance = mipoRegistry.getAll()[idA]
    if not instance then return false end
    for _, part in pairs(instance.parts) do
        if part.body and not part.body:isDestroyed() then
            for _, contact in ipairs(part.body:getContacts()) do
                if contact:isTouching() then
                    local fa, fb = contact:getFixtures()
                    local other = fa:getBody() == part.body and fb or fa
                    local otherInstance = not other:isSensor() and mipoRegistry.getFromBody(other:getBody())
                    if otherInstance and otherInstance.id == idB then return true end
                end
            end
        end
    end
    return false
end

local function wasHeld(id, now)
    return lastHeld[id] ~= nil and now - lastHeld[id] <= lib.healAfterRelease
end

local function calmPileKicks(now)
    for id, instance in pairs(mipoRegistry.getAll()) do
        local torso = instance.parts.torso1
        if torso and torso.body and not torso.body:isDestroyed() and not wasHeld(id, now) then
            local vx, vy = torso.body:getLinearVelocity()
            local speed = math.sqrt(vx * vx + vy * vy)
            local maxSpeed = units.speed(lib.pileMaxSpeed)
            if speed > maxSpeed and leaningOnOthers(instance) then
                local scale = maxSpeed / speed
                for _, part in pairs(instance.parts) do
                    if part.body and not part.body:isDestroyed() then
                        local px, py = part.body:getLinearVelocity()
                        part.body:setLinearVelocity(px * scale, py * scale)
                        part.body:setAngularVelocity(part.body:getAngularVelocity() * scale)
                    end
                end
                lib.stats.pileKicks = (lib.stats.pileKicks or 0) + 1
            end
        end
    end
end

-- The upper of two knotted Mipos hops up and away from the other; first they let go of each
-- other's hands (holding hands keeps the arms crossed: still hooked).
local function hopOut(idA, idB)
    local all = mipoRegistry.getAll()
    local a, b = all[idA], all[idB]
    if lib.untangleLetsGo and a and b then require('src.physics.snap').letGo(a, b) end
    local ta = a and a.parts.torso1 and a.parts.torso1.body
    local tb = b and b.parts.torso1 and b.parts.torso1.body
    if not ta or not tb or ta:isDestroyed() or tb:isDestroyed() then return end
    local upper, lower = a, tb
    if tb:getY() < ta:getY() then upper, lower = b, ta end
    local dir = upper.parts.torso1.body:getX() < lower:getX() and -1 or 1
    local hopX, hopY = units.speed(lib.untangleHop[1]), units.speed(lib.untangleHop[2])
    for _, part in pairs(upper.parts) do
        if part.body and not part.body:isDestroyed() then
            part.body:setLinearVelocity(dir * hopX, -hopY)
        end
    end
end

-- [pairKey] = { a, b, step }: the hooks seen, a slice of the Mipos per step (all at once
-- was a ~6 ms step with 20 Mipos); a pair counts as hooked until a whole round of slices
-- has gone by without seeing it again.
local hookSeen = {}

local function lookForHooks()
    local slice, k = stepCount % lib.hookCheckSteps, 0
    for _, owner in pairs(mipoRegistry.getAll()) do
        k = k + 1
        if k % lib.hookCheckSteps == slice then
            for _, hook in ipairs(hooksOf(owner, {})) do
                local key, a, b = pairKey(hook.a.id, hook.b.id)
                hookSeen[key] = { a = a, b = b, step = stepCount }
            end
        end
    end
end

-- [mipoId] = { n = untangles, firstT }: a Mipo that keeps re-hooking gives up (untangleMaxTries)
state.untangleTries = state.untangleTries or {}
local untangleTries = state.untangleTries

local function countTry(id, now)
    local rec = untangleTries[id]
    if not rec or now - rec.firstT > lib.untangleQuiet then
        rec = { n = 0, firstT = now }
        untangleTries[id] = rec
    end
    rec.n = rec.n + 1
end

-- Given up on (too many tries lately), unless picked up since.
local function gaveUp(id, now)
    local rec = untangleTries[id]
    if not rec then return false end
    if wasHeld(id, now) or now - rec.firstT > lib.untangleQuiet then
        untangleTries[id] = nil
        return false
    end
    return rec.n >= lib.untangleMaxTries
end

-- Is a limb of a through b, or of b through a, right now? (hooksOf on just these two, no cache)
local function hookedNow(a, b)
    local all = mipoRegistry.getAll()
    for _, owner in ipairs({ all[a], all[b] }) do
        for _, hook in ipairs(hooksOf(owner, {})) do
            local id1, id2 = hook.a.id, hook.b.id
            if (id1 == a and id2 == b) or (id1 == b and id2 == a) then return true end
        end
    end
    return false
end

-- Every step, for the pairs passing through each other: the moment they're free (no hook, no
-- overlap), they collide again. Released by the sliced hook cache (a hook counts for ~0.43 s)
-- every untangleCheckEvery, they flew apart free but still ghosts for up to ~0.7 s and fell
-- back into the same knot (2026-11-03).
local function releaseFreedPairs(now)
    for key, t in pairs(tangles) do
        if t.untilT and not t.soft and now >= t.untilT - lib.untangleMaxTime + lib.untangleMinTime
            and not overlapping(t.a, t.b) and not hookedNow(t.a, t.b) then
            t.untilT, t.since, t.restUntil = nil, nil, now + lib.untangleRest
            hookSeen[key] = nil
        end
    end
end

-- Every Mipo hooked to `id`, through any chain of hooks (the hooked pairs, by pairKey).
local function knotGroup(id, hooked)
    local seen, list, i = { [id] = true }, { id }, 1
    while list[i] do
        local current = list[i]
        for _, h in pairs(hooked) do
            local other = (h.a == current and h.b) or (h.b == current and h.a)
            if other and not seen[other] then
                seen[other] = true
                list[#list + 1] = other
            end
        end
        i = i + 1
    end
    table.sort(list)
    return list
end

-- A knot of three or more (Nikki's pit, 2026-11-10: one Mipo hooked into two others, more around):
-- untangled pair by pair, each pair hopped its upper Mipo away from the other into the third, and
-- undid what the other pairs did; it gave up after 4 tries and lay knotted. Now every pair in the
-- knot passes through each other at once and drifts apart (pushApart, as Mipos put down overlapping),
-- no hop, until nothing overlaps.
local function untangleGroup(group, now)
    local all = mipoRegistry.getAll()
    for i = 1, #group do
        countTry(group[i], now)
        for j = i + 1, #group do
            local key, a, b = pairKey(group[i], group[j])
            if lib.untangleLetsGo and all[a] and all[b] then require('src.physics.snap').letGo(all[a], all[b]) end
            tangles[key] = { a = a, b = b, soft = true, overlap = true, startT = now,
                untilT = now + lib.untangleMaxTime + lib.passThroughMaxTime }
            hookSeen[key] = nil
        end
    end
    lib.stats.untangles = (lib.stats.untangles or 0) + 1
    print('[untangle] group ' .. table.concat(group, ', '))
end

local function untangleMipos(now)
    releaseFreedPairs(now)
    lookForHooks()
    if now - lastTangleCheck < lib.untangleCheckEvery then return end
    lastTangleCheck = now
    local hooked = {}
    for key, seen in pairs(hookSeen) do
        if stepCount - seen.step <= lib.hookCheckSteps then
            hooked[key] = seen
        else
            hookSeen[key] = nil
        end
    end
    for key, t in pairs(tangles) do
        if t.soft then
            -- put down overlapping: apart once nothing overlaps, or when the time is up
            -- (contacts only exist after a physics step, so give it a moment first)
            t.overlap = overlapping(t.a, t.b)
            local settled = now - t.startT > 0.1
            if (settled and not t.overlap) or now >= t.untilT then tangles[key] = nil end
        elseif t.untilT then
            if not hooked[key] and not overlapping(t.a, t.b) then
                t.untilT, t.since, t.restUntil = nil, nil, now + lib.untangleRest
            elseif now >= t.untilT and overlapping(t.a, t.b) then
                -- out of time, still inside each other: they drift apart, passing through, until
                -- nothing overlaps (pushApart). Colliding again deep inside each other knotted them
                -- again at once, the pair hopped and re-knotted for good (Nikki's pit, 2026-11-10)
                tangles[key] = { a = t.a, b = t.b, soft = true, overlap = true, startT = now,
                    untilT = now + lib.passThroughMaxTime }
            elseif now >= t.untilT then
                -- out of time, still hooked: hop again soon (the rest is for a pair that came
                -- apart; light Mipos' arms often still hung on when the 4 s ran out)
                t.untilT, t.since, t.restUntil = nil, now - lib.untangleAfter, now + lib.untangleRetry
            end
        elseif not hooked[key] then
            t.since = nil
            if not t.restUntil or now >= t.restUntil then tangles[key] = nil end
        end
    end
    for key, h in pairs(hooked) do
        local t = tangles[key] or { a = h.a, b = h.b }
        tangles[key] = t
        if not t.untilT and not t.soft then
            -- the wait starts once both are let go
            if wasHeld(h.a, now) or wasHeld(h.b, now) or not t.since then t.since = now end
            if now - t.since >= lib.untangleAfter and not (t.restUntil and now < t.restUntil)
                and not gaveUp(h.a, now) and not gaveUp(h.b, now) then
                local group = knotGroup(h.a, hooked)
                if #group >= 3 then
                    untangleGroup(group, now)
                else
                    t.untilT = now + lib.untangleMaxTime
                    countTry(h.a, now)
                    countTry(h.b, now)
                    hopOut(h.a, h.b)
                    lib.stats.untangles = (lib.stats.untangles or 0) + 1
                    print(string.format('[untangle] %s and %s', h.a, h.b))
                end
            end
        end
    end
end

-- These Mipos (ids) were just put down, maybe overlapping each other or Mipos already
-- there: every such pair passes through each other until apart (see lib.passThroughSpeed).
function lib.passThrough(ids)
    local now = love.timer.getTime()
    local all = mipoRegistry.getAll()
    local new = {}
    for _, id in ipairs(ids) do new[id] = true end
    for _, id in ipairs(ids) do
        for otherId in pairs(all) do
            if otherId ~= id and not (new[otherId] and otherId < id) then
                local key, a, b = pairKey(id, otherId)
                tangles[key] = { a = a, b = b, soft = true, overlap = false, startT = now,
                    untilT = now + lib.passThroughMaxTime }
            end
        end
    end
end

local function horizontalSpan(instance)
    local x1, x2 = math.huge, -math.huge
    for _, part in pairs(instance.parts) do
        if part.body and not part.body:isDestroyed() then
            local x = part.body:getX()
            x1, x2 = math.min(x1, x), math.max(x2, x)
        end
    end
    return x1, x2
end

-- Every step: overlapping pass-through pairs drift apart, each Mipo away from the other's
-- middle (by id when they're level), up to passThroughSpeed sideways, keeping its fall.
local function pushApart()
    local all = mipoRegistry.getAll()
    local target = units.speed(lib.passThroughSpeed)
    for _, t in pairs(tangles) do
        local a, b = all[t.a], all[t.b]
        if t.soft and t.overlap and a and b then
            local ax1, ax2 = horizontalSpan(a)
            local bx1, bx2 = horizontalSpan(b)
            local dir = ((ax1 + ax2) - (bx1 + bx2)) >= 0 and 1 or -1
            if (ax1 + ax2) == (bx1 + bx2) then dir = t.a < t.b and -1 or 1 end
            for instance, sign in pairs({ [a] = dir, [b] = -dir }) do
                for _, part in pairs(instance.parts) do
                    if part.body and not part.body:isDestroyed() then
                        local vx, vy = part.body:getLinearVelocity()
                        if vx * sign < target then part.body:setLinearVelocity(sign * target, vy) end
                    end
                end
            end
        end
    end
end

-- legsPass (a switch, on state so a hot swap keeps it): a Mipo's legs (thighs and shins, not the
-- feet: Mipos still stand on each other) go through other Mipos. Knots are mostly a limb hooked
-- through another Mipo; in a pile the legs hooked most (Nikki 2026-11-10, a pit of Mipos: knotted
-- pairs untangled again and again, then shot out of the room). The settings panel's 'mipos' section.
-- tried 2026-11-10, left off: 6 piles of 8 random Mipos, 30 s: untangles 18 -> 10, gave up 8 -> 4.
-- Nikki liked the pit as well without it once only stubby Mipos had wide leg shapes (mipo-build
-- fitLegWidth); turn it on if piles knot again.
lib.rows = {
    { key = 'legs pass other Mipos', kind = 'bool',
      get = function() return state.legsPassMipos == true end,
      set = function(_, v) state.legsPassMipos = v and true or nil end },
}

-- From preSolve (src/physics/physics-callbacks.lua): two Mipos that are
-- untangling, or were put down overlapping, pass through each other; with legsPass, a leg and
-- another Mipo do.
function lib.onPreSolve(fix1, fix2, contact)
    local legsPass = state.legsPassMipos
    if not legsPass and next(tangles) == nil then return end
    local instance1, part1 = mipoRegistry.getFromBody(fix1:getBody())
    if not instance1 then return end
    local instance2, part2 = mipoRegistry.getFromBody(fix2:getBody())
    if not instance2 or instance1 == instance2 then return end
    if legsPass and (LEG[part1] or LEG[part2]) then
        contact:setEnabled(false)
        return
    end
    local t = tangles[pairKey(instance1.id, instance2.id)]
    if t and (t.untilT or t.soft) then contact:setEnabled(false) end
end

function lib.update()
    if not state.physicsWorld then return end
    local now = love.timer.getTime()
    stepCount = stepCount + 1
    markHeldMipos(now)
    if lib.pileKick then calmPileKicks(now) end
    if lib.standUp then standUpMipos(now) end
    if lib.untangle then untangleMipos(now) end
    if next(tangles) ~= nil then pushApart() end
    if not lib.unwind and not lib.heal and not lib.unstick then return end
    -- Every Mipo's joints only every scanEvery steps (unwind, finding stuck limbs): going
    -- through all ~300 of them every step was ~1 ms a frame with 20 Mipos on an iPhone SE 2
    -- (2026-10-31). A held Mipo's joints still every step (heal), and ghosts are pulled
    -- back every step (unstickJoints).
    local scan = stepCount % lib.scanEvery == 0
    if scan then scanCount = scanCount + 1 end
    local revolute, limited, held = {}, {}, {}
    for id, instance in pairs(mipoRegistry.getAll()) do
        local recentlyHeld = wasHeld(id, now)
        if scan or recentlyHeld then
            eachRevolute(instance, function(joint)
                if scan then
                    revolute[#revolute + 1] = joint
                    if joint:areLimitsEnabled() then limited[#limited + 1] = joint end
                end
                if recentlyHeld then held[#held + 1] = joint end
            end)
        end
    end
    if lib.heal then
        for _, joint in ipairs(held) do healJoint(joint) end
    end
    if lib.unwind and scan then unwindJoints(limited) end
    if lib.unstick then unstickJoints(revolute, now, scanCount) end
end

return lib

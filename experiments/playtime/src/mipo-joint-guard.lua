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

local lib = {}

lib.unwind = true
lib.heal = true
lib.healDistance = 40 -- world units between joint anchors before a limb is pulled back
                      -- (recorded: up to ~12 while fine, 60-1000 once torn)
lib.healAfterRelease = 1.0 -- seconds healing stays on after a Mipo is let go (throws)

lib.unstick = true
lib.unstickDistance = 15  -- joint halves further apart than this, with a wall between, is stuck
lib.unstickMaxTime = 2.0  -- seconds a part stays a ghost at most

lib.standUp = true
lib.splayedAngle = math.rad(30) -- further than this from its target counts as splayed (50 let a
                                -- wide stance on grippy feet tug forever instead of hopping to reset)
lib.splayedFor = 0.6            -- seconds of splayed legs before a hop
lib.standUpPause = 1.2          -- seconds between hops
lib.standUpSpeed = 500          -- hop speed (world units/s), like the grab hop

local lastHeld = {} -- [mipoId] = time the Mipo was last held by a pointer
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

local function isMipoJoint(joint)
    local bodyA, bodyB = joint:getBodies()
    if not bodyA or not bodyB then return false end
    local mipo = mipoRegistry.getFromBody(bodyA)
    return mipo ~= nil and mipo == mipoRegistry.getFromBody(bodyB)
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

-- Joints are made parent (body A) -> child (body B), see character-manager.
-- Is there a wall (anything static) between the two points? Healing is a
-- teleport (setPosition), which skips Box2D's tunnelling protection: a limb
-- torn across a thin wall was put straight into it and got stuck.
local function wallBetween(x1, y1, x2, y2)
    if (x2 - x1) ^ 2 + (y2 - y1) ^ 2 < 1 then return false end
    local blocked = false
    state.physicsWorld:rayCast(x1, y1, x2, y2, function(fixture)
        if fixture:getBody():getType() == 'static' and not fixture:isSensor() then
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
    -- Box2D asserts on a zero-length ray (anchors exactly on top of each other)
    if (x2 - x1) ^ 2 + (y2 - y1) ^ 2 < 1 then return nil end
    local found
    state.physicsWorld:rayCast(x1, y1, x2, y2, function(fixture)
        if fixture:getBody():getType() == 'static' and not fixture:isSensor() then
            found = fixture
            return 0
        end
        return -1
    end)
    return found
end

local function fixtureLabel(fixture)
    local ud = fixture:getBody():getUserData()
    local thing = ud and ud.thing
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
            if other:getBody():getType() == 'static' and not other:isSensor() then return true end
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

local function jointKey(joint)
    local _, bodyB = joint:getBodies()
    local ud = bodyB:getUserData()
    return ud and ud.thing and ud.thing.id
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

local function unstickJoints(joints, now)
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
                for _, body in ipairs(bodies) do
                    local x, y = body:getPosition()
                    body:setLinearVelocity(vx + (gx - x) * lib.unstickPull, vy + (gy - y) * lib.unstickPull)
                end
            end
        end
    end
    for _, joint in ipairs(joints) do
        if not ghosts[jointKey(joint)] then
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

local function recentlyHeld(joint, now)
    local _, bodyB = joint:getBodies()
    local instance = mipoRegistry.getFromBody(bodyB)
    local held = instance and lastHeld[instance.id]
    return held ~= nil and now - held <= lib.healAfterRelease
end

-- Splayed: a supporting part that is holding a target (KEEP_ANGLE enabled) is
-- far from that target. Follows the actions in src/mipo-actions.lua: upright
-- legs normally, down-pointing arms when flipped, nothing when ragdolled.
local function isSplayed(instance)
    for _, name in ipairs(supportParts) do
        local part = instance.parts[name]
        if part and part.body and not part.body:isDestroyed() then
            local ud = part.body:getUserData()
            for _, behavior in ipairs(ud and ud.thing and ud.thing.behaviors or {}) do
                -- limp parts (held limb, idle slump) are slack on purpose
                if behavior.name == 'KEEP_ANGLE' and behavior.enabled ~= false and not part.limp then
                    local diff = part.body:getAngle() - math.rad(behavior.angle or 0)
                    diff = (diff + math.pi) % TWO_PI - math.pi
                    if math.abs(diff) > lib.splayedAngle then return true end
                end
            end
        end
    end
    return false
end

-- Any part resting against another Mipo (a pile). Props like a skateboard don't count.
local function leaningOnOthers(instance)
    for _, part in pairs(instance.parts) do
        local body = part.body
        if body and not body:isDestroyed() then
            for _, contact in ipairs(body:getContacts()) do
                if contact:isTouching() then
                    local fixtureA, fixtureB = contact:getFixtures()
                    local other = fixtureA:getBody() == body and fixtureB:getBody() or fixtureA:getBody()
                    local otherMipo = mipoRegistry.getFromBody(other)
                    if otherMipo and otherMipo ~= instance
                        and not fixtureA:isSensor() and not fixtureB:isSensor() then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- Any part resting on something that isn't a Mipo (floor, wall, skateboard,
-- slide): no stand-up hops mid-air. Static-only missed a Mipo on a skateboard.
local function onGround(instance)
    for _, part in pairs(instance.parts) do
        local body = part.body
        if body and not body:isDestroyed() then
            for _, contact in ipairs(body:getContacts()) do
                if contact:isTouching() then
                    local fixtureA, fixtureB = contact:getFixtures()
                    local other = fixtureA:getBody() == body and fixtureB:getBody() or fixtureA:getBody()
                    if not mipoRegistry.getFromBody(other) and not fixtureA:isSensor()
                        and not fixtureB:isSensor() then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function standUpMipos(now)
    for id, instance in pairs(mipoRegistry.getAll()) do
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
            torso.body:applyLinearImpulse(0, -mass * lib.standUpSpeed)
            lastStandUp[id] = now
            lib.stats.standUps = lib.stats.standUps + 1
            lib.stats.standUpsByMipo[id] = (lib.stats.standUpsByMipo[id] or 0) + 1
        end
    end
end

function lib.update()
    if not state.physicsWorld then return end
    local now = love.timer.getTime()
    markHeldMipos(now)
    if lib.standUp then standUpMipos(now) end
    if not lib.unwind and not lib.heal and not lib.unstick then return end
    local revolute, limited = {}, {}
    for _, joint in ipairs(state.physicsWorld:getJoints()) do
        if joint:getType() == JT.REVOLUTE and isMipoJoint(joint) then
            revolute[#revolute + 1] = joint
            if joint:areLimitsEnabled() then limited[#limited + 1] = joint end
        end
    end
    if lib.heal then
        for _, joint in ipairs(revolute) do
            if recentlyHeld(joint, now) then healJoint(joint) end
        end
    end
    if lib.unwind then unwindJoints(limited) end
    if lib.unstick then unstickJoints(revolute, now) end
end

return lib

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
lib.untangleRest = 3.0      -- seconds before the same pair untangles again
lib.untangleHop = { 250, 650 } -- the hop out: sideways (away from the other), up (world units/s)
lib.untangleCheckEvery = 0.25

lib.standUp = true
lib.splayedAngle = math.rad(30) -- further than this from its target counts as splayed (50 let a
                                -- wide stance on grippy feet tug forever instead of hopping to reset)
lib.splayedFor = 0.6            -- seconds of splayed legs before a hop
lib.standUpPause = 1.2          -- seconds between hops
lib.standUpSpeed = 500          -- hop speed (world units/s), like the grab hop

local lastHeld = {} -- [mipoId] = time the Mipo was last held by a pointer
-- [pairKey] = { a, b, since, untilT, restUntil }; on state: preSolve reads it every step
state.mipoTangles = state.mipoTangles or {}
local tangles = state.mipoTangles
local lastTangleCheck = 0
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

-- Another Mipo's part across a limb: a hook, the two tangled. In a stack the
-- limbs rest ON the other Mipo (feet on a head), nothing crosses them; in a knot
-- a limb went through and wraps around the other's arm, leg or body. Returns
-- the first part of another Mipo on the path parent centre -> joint -> child
-- centre (the wallAcrossLimb path), and that Mipo.
local function otherMipoAcross(x1, y1, x2, y2, ownId)
    if (x2 - x1) ^ 2 + (y2 - y1) ^ 2 < 1 then return nil end
    local found, foundInstance
    state.physicsWorld:rayCast(x1, y1, x2, y2, function(fixture)
        if fixture:isSensor() then return -1 end
        local instance = mipoRegistry.getFromBody(fixture:getBody())
        if instance and instance.id ~= ownId then
            found, foundInstance = fixture, instance
            return 0
        end
        return -1
    end)
    return found, foundInstance
end

-- Every hook right now: { a = the Mipo whose limb, b = the Mipo across it, part, through }.
function lib.hooks()
    local result = {}
    if not state.physicsWorld then return result end
    for _, joint in ipairs(state.physicsWorld:getJoints()) do
        if joint:getType() == JT.REVOLUTE and isMipoJoint(joint) then
            local bodyA, bodyB = joint:getBodies()
            local instance, partName = mipoRegistry.getFromBody(bodyB)
            if instance then
                local x1, y1, x2, y2 = joint:getAnchors()
                local ax, ay = bodyA:getPosition()
                local bx, by = bodyB:getPosition()
                local fixture, other = otherMipoAcross(ax, ay, x1, y1, instance.id)
                if not fixture then fixture, other = otherMipoAcross(x1, y1, x2, y2, instance.id) end
                if not fixture then fixture, other = otherMipoAcross(x2, y2, bx, by, instance.id) end
                if fixture then
                    local _, through = mipoRegistry.getFromBody(fixture:getBody())
                    result[#result + 1] = { a = instance, b = other, part = partName, through = through }
                end
            end
        end
    end
    return result
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

-- The upper of two knotted Mipos hops up and away from the other.
local function hopOut(idA, idB)
    local all = mipoRegistry.getAll()
    local a, b = all[idA], all[idB]
    local ta = a and a.parts.torso1 and a.parts.torso1.body
    local tb = b and b.parts.torso1 and b.parts.torso1.body
    if not ta or not tb or ta:isDestroyed() or tb:isDestroyed() then return end
    local upper, lower = a, tb
    if tb:getY() < ta:getY() then upper, lower = b, ta end
    local dir = upper.parts.torso1.body:getX() < lower:getX() and -1 or 1
    for _, part in pairs(upper.parts) do
        if part.body and not part.body:isDestroyed() then
            part.body:setLinearVelocity(dir * lib.untangleHop[1], -lib.untangleHop[2])
        end
    end
end

local function untangleMipos(now)
    if now - lastTangleCheck < lib.untangleCheckEvery then return end
    lastTangleCheck = now
    local hooked = {}
    for _, hook in ipairs(lib.hooks()) do
        local key, a, b = pairKey(hook.a.id, hook.b.id)
        hooked[key] = { a = a, b = b }
    end
    for key, t in pairs(tangles) do
        if t.untilT then
            if now >= t.untilT or (not hooked[key] and not overlapping(t.a, t.b)) then
                t.untilT, t.since, t.restUntil = nil, nil, now + lib.untangleRest
            end
        elseif not hooked[key] then
            t.since = nil
            if not t.restUntil or now >= t.restUntil then tangles[key] = nil end
        end
    end
    for key, h in pairs(hooked) do
        local t = tangles[key] or { a = h.a, b = h.b }
        tangles[key] = t
        if not t.untilT then
            -- the wait starts once both are let go
            if wasHeld(h.a, now) or wasHeld(h.b, now) or not t.since then t.since = now end
            if now - t.since >= lib.untangleAfter and not (t.restUntil and now < t.restUntil) then
                t.untilT = now + lib.untangleMaxTime
                hopOut(h.a, h.b)
                lib.stats.untangles = (lib.stats.untangles or 0) + 1
                print(string.format('[untangle] %s and %s', h.a, h.b))
            end
        end
    end
end

-- From preSolve (src/physics/physics-callbacks.lua): two Mipos that are
-- untangling pass through each other.
function lib.onPreSolve(fix1, fix2, contact)
    if next(tangles) == nil then return end
    local instance1 = mipoRegistry.getFromBody(fix1:getBody())
    if not instance1 then return end
    local instance2 = mipoRegistry.getFromBody(fix2:getBody())
    if not instance2 or instance1 == instance2 then return end
    local t = tangles[pairKey(instance1.id, instance2.id)]
    if t and t.untilT then contact:setEnabled(false) end
end

function lib.update()
    if not state.physicsWorld then return end
    local now = love.timer.getTime()
    markHeldMipos(now)
    if lib.standUp then standUpMipos(now) end
    if lib.untangle then untangleMipos(now) end
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

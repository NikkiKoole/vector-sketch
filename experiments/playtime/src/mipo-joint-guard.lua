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
-- standUp: a Mipo that lands in a split can't get up by turning its legs alone
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

lib.standUp = true
lib.splayedAngle = math.rad(50) -- a leg part further than this from upright counts as splayed
lib.splayedFor = 0.6            -- seconds of splayed legs before a hop
lib.standUpPause = 1.2          -- seconds between hops
lib.standUpSpeed = 500          -- hop speed (world units/s), like the grab hop

local lastHeld = {} -- [mipoId] = time the Mipo was last held by a pointer
local splayedSince = {} -- [mipoId] = time its legs became splayed
local lastStandUp = {}  -- [mipoId] = time of its last stand-up hop
local legParts = { 'luleg', 'ruleg', 'llleg', 'rlleg' }

lib.stats = { unwound = 0, healed = 0, standUps = 0 }

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
local function healJoint(joint)
    local x1, y1, x2, y2 = joint:getAnchors()
    local dx, dy = x1 - x2, y1 - y2
    if dx * dx + dy * dy < lib.healDistance * lib.healDistance then return end
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

local function isSplayed(instance)
    for _, name in ipairs(legParts) do
        local part = instance.parts[name]
        if part and part.body and not part.body:isDestroyed() then
            local angle = (part.body:getAngle() + math.pi) % TWO_PI - math.pi
            if math.abs(angle) > lib.splayedAngle then return true end
        end
    end
    return false
end

-- Any part resting against a dynamic body of another Mipo or a prop.
local function leaningOnOthers(instance)
    for _, part in pairs(instance.parts) do
        local body = part.body
        if body and not body:isDestroyed() then
            for _, contact in ipairs(body:getContacts()) do
                if contact:isTouching() then
                    local fixtureA, fixtureB = contact:getFixtures()
                    local other = fixtureA:getBody() == body and fixtureB:getBody() or fixtureA:getBody()
                    if other:getType() == 'dynamic' and mipoRegistry.getFromBody(other) ~= instance
                        and not fixtureA:isSensor() and not fixtureB:isSensor() then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- Any part resting on a static body (floor, wall): no stand-up hops mid-air.
local function onGround(instance)
    for _, part in pairs(instance.parts) do
        local body = part.body
        if body and not body:isDestroyed() then
            for _, contact in ipairs(body:getContacts()) do
                if contact:isTouching() then
                    local fixtureA, fixtureB = contact:getFixtures()
                    local other = fixtureA:getBody() == body and fixtureB:getBody() or fixtureA:getBody()
                    if other:getType() == 'static' and not fixtureA:isSensor() and not fixtureB:isSensor() then
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
        end
    end
end

function lib.update()
    if not state.physicsWorld then return end
    local now = love.timer.getTime()
    markHeldMipos(now)
    if lib.standUp then standUpMipos(now) end
    if not lib.unwind and not lib.heal then return end
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
end

return lib

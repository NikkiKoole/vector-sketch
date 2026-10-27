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
local JT = require('src.joint-types')
local state = require('src.state')
local mipoRegistry = require('src.mipo-registry')

local lib = {}

lib.unwind = true
lib.heal = true
lib.healDistance = 40 -- world units between joint anchors before a limb is pulled back
                      -- (recorded: up to ~12 while fine, 60-1000 once torn)

lib.stats = { unwound = 0, healed = 0 }

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

function lib.update()
    if not state.physicsWorld then return end
    if not lib.unwind and not lib.heal then return end
    local revolute, limited = {}, {}
    for _, joint in ipairs(state.physicsWorld:getJoints()) do
        if joint:getType() == JT.REVOLUTE and isMipoJoint(joint) then
            revolute[#revolute + 1] = joint
            if joint:areLimitsEnabled() then limited[#limited + 1] = joint end
        end
    end
    if lib.heal then
        for _, joint in ipairs(revolute) do healJoint(joint) end
    end
    if lib.unwind then unwindJoints(limited) end
end

return lib

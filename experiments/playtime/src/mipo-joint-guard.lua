-- mipo-joint-guard.lua
-- Keeps Mipo ragdolls sane when they're dragged around hard. Each fix has its
-- own switch so they can be compared in play (see docs/DOLL-PLAY.md, found with
-- src/flight-recorder.lua: fast circles wound a shoulder ~6 turns past its limit).
--
-- unwind: Box2D counts a revolute joint's angle cumulatively. A limb spun whole
--   turns past its limit gets pulled back the long way round and stays twisted.
--   Turning the limb by whole turns looks identical but un-twists the joint.
local JT = require('src.joint-types')
local state = require('src.state')
local mipoRegistry = require('src.mipo-registry')

local lib = {}

lib.unwind = true

lib.stats = { unwound = 0 }

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

function lib.update()
    if not lib.unwind or not state.physicsWorld then return end
    local limited = {}
    for _, joint in ipairs(state.physicsWorld:getJoints()) do
        if joint:getType() == JT.REVOLUTE and joint:areLimitsEnabled() and isMipoJoint(joint) then
            limited[#limited + 1] = joint
        end
    end
    unwindJoints(limited)
end

return lib

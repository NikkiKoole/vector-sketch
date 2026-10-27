-- snap.lua
-- Snap points: SNAP sfixtures on bodies. Two free snap points that come within
-- state.snap.snapDistance of each other (on different bodies) get joined by a
-- revolute "snap joint"; pulled hard enough, the joint breaks again.
--
-- One source of truth: the snap joint. Its userData.scriptmeta is
--   { type = 'snap', a = <sfixture id>, b = <sfixture id> }
-- and saves with the joint. A snap point is "linked" when a snap joint names
-- it; nothing else is stored, so nothing can drift. Snap points are found by
-- subtype in the registry each frame; cooldowns are keyed by sfixture id.
--
-- (Before: links lived in each snap point as live body refs (at/to) plus two
-- cached arrays kept in sync by hand. Deleting a body left its partner point
-- marked as linked forever, saving had to convert refs to ids, and loading
-- guessed which points a joint connected.)
local logger = require 'src.logger'
local registry = require 'src.registry'
local uuid = require 'src.uuid'
local box2dPointerJoints = require 'src.physics.box2d-pointerjoints'
local mathutils = require 'src.math-utils'
local subtypes = require 'src.subtypes'
local state = require('src.state')

local lib = {}

local cooldownUntil = {} -- [sfixture id] = time

local function now()
    return love.timer.getTime()
end

local function snapMeta(joint)
    if joint:isDestroyed() then return nil end
    local ud = joint:getUserData()
    local meta = ud and ud.scriptmeta
    return (meta and meta.type == 'snap') and meta or nil
end

-- Local position of a snap point on its body (the centre of its shape).
local function localCentre(fixture)
    local shape = fixture:getShape()
    if shape.getPoints then
        return mathutils.getCenterOfPoints({ shape:getPoints() })
    end
    return shape:getPoint()
end

-- All live snap points: { id, fixture, body, x, y } (world position).
function lib.points()
    local out = {}
    for id, fixture in pairs(registry.sfixtures) do
        if not fixture:isDestroyed() and subtypes.is(fixture:getUserData(), subtypes.SNAP) then
            local body = fixture:getBody()
            local lx, ly = localCentre(fixture)
            local x, y = body:getWorldPoint(lx, ly)
            out[#out + 1] = { id = id, fixture = fixture, body = body, x = x, y = y }
        end
    end
    table.sort(out, function(p, q) return p.id < q.id end) -- deterministic pairing
    return out
end

-- All live snap joints.
function lib.joints()
    local out = {}
    for _, joint in pairs(registry.joints) do
        if snapMeta(joint) then out[#out + 1] = joint end
    end
    return out
end

-- Snap point ids that are linked by a snap joint.
local function linkedIds(snapJoints)
    local linked = {}
    for _, joint in ipairs(snapJoints) do
        local meta = snapMeta(joint)
        if meta.a then linked[meta.a] = true end
        if meta.b then linked[meta.b] = true end
    end
    return linked
end

local function bodiesJoined(snapJoints, body1, body2)
    for _, joint in ipairs(snapJoints) do
        local a, b = joint:getBodies()
        if (a == body1 and b == body2) or (a == body2 and b == body1) then return true end
    end
    return false
end

local function isInteracted(body1, body2, interacted)
    for i = 1, #interacted do
        if interacted[i] == body1 or interacted[i] == body2 then return true end
    end
    return false
end

local function destroySnapJoint(joint)
    local meta = snapMeta(joint)
    if meta then
        local t = now() + state.snap.cooldownTime
        if meta.a then cooldownUntil[meta.a] = t end
        if meta.b then cooldownUntil[meta.b] = t end
    end
    local ud = joint:getUserData()
    if ud and ud.id then registry.unregisterJoint(ud.id) end
    joint:destroy()
end

local function createSnapJoint(p, q)
    local id = uuid.generateID()
    local joint = love.physics.newRevoluteJoint(p.body, q.body, p.x, p.y, q.x, q.y)
    local ax, ay = p.body:getLocalPoint(p.x, p.y)
    local bx, by = q.body:getLocalPoint(q.x, q.y)
    joint:setUserData({
        id = id,
        offsetA = { x = ax, y = ay },
        offsetB = { x = bx, y = by },
        scriptmeta = { type = 'snap', a = p.id, b = q.id },
    })
    registry.registerJoint(id, joint)
    return joint
end

local function checkForSnaps(points, snapJoints, interacted)
    local t = now()
    local linked = linkedIds(snapJoints)
    local free = {}
    for _, p in ipairs(points) do
        if not linked[p.id] and not (cooldownUntil[p.id] and t < cooldownUntil[p.id]) then
            free[#free + 1] = p
        end
    end
    local maxDist = state.snap.snapDistance
    for i = 1, #free do
        local p = free[i]
        if not linked[p.id] then
            for j = i + 1, #free do
                local q = free[j]
                if not linked[q.id] and p.body ~= q.body
                    and (p.x - q.x) ^ 2 + (p.y - q.y) ^ 2 <= maxDist * maxDist
                    and (not state.snap.onlyConnectWhenInteracted or isInteracted(p.body, q.body, interacted))
                    and not bodiesJoined(snapJoints, p.body, q.body) then
                    snapJoints[#snapJoints + 1] = createSnapJoint(p, q)
                    linked[p.id], linked[q.id] = true, true
                    break
                end
            end
        end
    end
end

local function checkForBreaks(dt, snapJoints, interacted)
    for _, joint in ipairs(snapJoints) do
        if not joint:isDestroyed() then
            local fx, fy = joint:getReactionForce(1 / dt)
            if math.max(math.abs(fx), math.abs(fy)) > state.snap.jointBreakThreshold then
                local a, b = joint:getBodies()
                if not state.snap.onlyBreakWhenInteracted or isInteracted(a, b, interacted) then
                    destroySnapJoint(joint)
                end
            end
        end
    end
end

function lib.update(dt)
    local t = now()
    for id, untilT in pairs(cooldownUntil) do
        if t >= untilT then cooldownUntil[id] = nil end
    end
    local points = lib.points()
    if #points < 2 then return end
    local interacted = box2dPointerJoints.getInteractedWithPointer()
    local snapJoints = lib.joints()
    checkForBreaks(dt, snapJoints, interacted)
    checkForSnaps(points, lib.joints(), interacted)
end

-- Snap joints on a body that's about to be destroyed. Linking lives only on the
-- joint, so the partner point is free again automatically.
function lib.destroySnapJointAboutBody(body)
    for _, joint in ipairs(lib.joints()) do
        local a, b = joint:getBodies()
        if a == body or b == body then destroySnapJoint(joint) end
    end
end

-- After a load: scenes saved before snap joints named their points carry only
-- { type = 'snap' }; pick the nearest free snap point on each body once, and
-- drop the old per-point link data (at / to / fixture).
function lib.onSceneLoaded()
    cooldownUntil = {}
    local points = lib.points()
    for _, p in ipairs(points) do
        local ud = p.fixture:getUserData()
        if ud.extra then ud.extra.at, ud.extra.to, ud.extra.fixture = nil, nil, nil end
    end
    local taken = linkedIds(lib.joints())
    for _, joint in ipairs(lib.joints()) do
        local meta = snapMeta(joint)
        if not (meta.a and meta.b) then
            local x1, y1, x2, y2 = joint:getAnchors()
            local bodyA, bodyB = joint:getBodies()
            local function nearest(body, x, y)
                local best, bestD
                for _, p in ipairs(points) do
                    if p.body == body and not taken[p.id] then
                        local d = (p.x - x) ^ 2 + (p.y - y) ^ 2
                        if not bestD or d < bestD then best, bestD = p, d end
                    end
                end
                return best
            end
            local pa, pb = nearest(bodyA, x1, y1), nearest(bodyB, x2, y2)
            if pa and pb then
                meta.a, meta.b = pa.id, pb.id
                taken[pa.id], taken[pb.id] = true, true
            else
                logger:warn('snap: loaded snap joint without matching snap points')
            end
        end
    end
end

-- Add a snap point to a body at local (x, y). Returns its sfixture id.
function lib.addPoint(body, x, y, radius)
    local fixtures = require('src.fixtures') -- lazy: fixtures -> registry -> ...
    local fixture = fixtures.createSFixture(body, x, y, subtypes.SNAP, { radius = radius or 10 })
    return fixture and fixture:getUserData().id
end

-- Does this body have snap points already?
function lib.hasPoints(body)
    for _, fixture in ipairs(body:getFixtures()) do
        if subtypes.is(fixture:getUserData(), subtypes.SNAP) then return true end
    end
    return false
end

function lib.reset()
    cooldownUntil = {}
end

return lib

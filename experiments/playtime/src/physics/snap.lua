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
-- Mipo hands are snap points too (no fixture: id = the hand part's thing id),
-- so a hand grabs a climbing hold, a snap block, or another Mipo's hand.
-- A hand grabs what it touches (reach radius + handMargin), holds on where it
-- touches, and lets go more easily (handBreakThreshold); never its own Mipo.
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
local mipoRegistry = require('src.mipo-registry')
local units = require('src.physics-units')

local lib = {}

lib.mipoHands = true
lib.handMargin = 30           -- a hand grabs what it touches: centres within both reach radii + this
                              -- (a fixed 70 was less than one hand's own radius, 100-124: two
                              -- solid hands could never get that close, so never held hands)
lib.handBreakThreshold = 40000 -- a hand lets go above this joint force (a pull, a hard fall);
                               -- forces here are as at 100 px per metre (src/physics-units.lua)

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
    if lib.mipoHands then
        for mipoId, instance in pairs(mipoRegistry.getAll()) do
            for _, name in ipairs({ 'lhand', 'rhand' }) do
                local hand = instance.parts and instance.parts[name]
                if hand and hand.body and not hand.body:isDestroyed() and hand.id then
                    local x, y = hand.body:getWorldCenter()
                    out[#out + 1] = { id = hand.id, body = hand.body, x = x, y = y, hand = true, mipo = mipoId,
                        radius = lib.reachRadius(hand.body, x, y) }
                end
            end
        end
    end
    table.sort(out, function(p, q) return p.id < q.id end) -- deterministic pairing
    return out
end

-- How far a body's solid shapes reach from (cx, cy).
function lib.reachRadius(body, cx, cy)
    local r = 0
    for _, fixture in ipairs(body:getFixtures()) do
        local shape = fixture:getShape()
        if not fixture:isSensor() then
            if shape.getPoints then
                local pts = { body:getWorldPoints(shape:getPoints()) }
                for k = 1, #pts, 2 do r = math.max(r, math.sqrt((pts[k] - cx) ^ 2 + (pts[k + 1] - cy) ^ 2)) end
            elseif shape.getRadius then
                local sx, sy = body:getWorldPoint(shape:getPoint())
                r = math.max(r, math.sqrt((sx - cx) ^ 2 + (sy - cy) ^ 2) + shape:getRadius())
            end
        end
    end
    return r
end

-- Is this snap-point id a Mipo hand? (for joints: hands break more easily)
local function isHandId(id)
    if not id then return false end
    local body = registry.getBodyByID(id)
    if not body then return false end
    local _, partName = mipoRegistry.getFromBody(body)
    return partName == 'lhand' or partName == 'rhand'
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

-- Held by a pointer, counted per Mipo: dragging a Mipo by its torso lets its
-- hands grab (the hand itself isn't the body under the finger).
local function isInteracted(body1, body2, interacted)
    for i = 1, #interacted do
        local held = interacted[i]
        if held == body1 or held == body2 then return true end
        local heldMipo = mipoRegistry.getFromBody(held)
        if heldMipo and (mipoRegistry.getFromBody(body1) == heldMipo
            or mipoRegistry.getFromBody(body2) == heldMipo) then
            return true
        end
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
    -- snap points click together (anchors pull into one point); a hand holds on
    -- where it touches (one shared anchor between them), or two solid hands
    -- would be pulled into each other
    local px, py, qx, qy = p.x, p.y, q.x, q.y
    if p.hand or q.hand then
        px, py = (p.x + q.x) / 2, (p.y + q.y) / 2
        qx, qy = px, py
    end
    local joint = love.physics.newRevoluteJoint(p.body, q.body, px, py, qx, qy)
    local ax, ay = p.body:getLocalPoint(px, py)
    local bx, by = q.body:getLocalPoint(qx, qy)
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
    -- every candidate pair within range, nearest first: a hand near two holds
    -- grabs the closest (first-in-id-order made pairing depend on random ids)
    local function sameMipo(p, q)
        local mp = p.mipo or (mipoRegistry.getFromBody(p.body) or {}).id
        local mq = q.mipo or (mipoRegistry.getFromBody(q.body) or {}).id
        return mp ~= nil and mp == mq
    end
    local candidates = {}
    for i = 1, #free do
        for j = i + 1, #free do
            local p, q = free[i], free[j]
            local dist = (p.hand or q.hand) and ((p.radius or 0) + (q.radius or 0) + lib.handMargin)
                or state.snap.snapDistance
            local d2 = (p.x - q.x) ^ 2 + (p.y - q.y) ^ 2
            if p.body ~= q.body and d2 <= dist * dist and not sameMipo(p, q) then
                candidates[#candidates + 1] = { p = p, q = q, d2 = d2 }
            end
        end
    end
    table.sort(candidates, function(c1, c2) return c1.d2 < c2.d2 end)
    for _, c in ipairs(candidates) do
        local p, q = c.p, c.q
        if not linked[p.id] and not linked[q.id]
            and (not state.snap.onlyConnectWhenInteracted or isInteracted(p.body, q.body, interacted))
            and not bodiesJoined(snapJoints, p.body, q.body) then
            snapJoints[#snapJoints + 1] = createSnapJoint(p, q)
            linked[p.id], linked[q.id] = true, true
        end
    end
end

local function checkForBreaks(dt, snapJoints, interacted)
    for _, joint in ipairs(snapJoints) do
        if not joint:isDestroyed() then
            local fx, fy = joint:getReactionForce(1 / dt)
            fx, fy = units.toReferenceForce(fx), units.toReferenceForce(fy)
            local meta = snapMeta(joint)
            local threshold = (isHandId(meta.a) or isHandId(meta.b)) and lib.handBreakThreshold
                or state.snap.jointBreakThreshold
            if math.max(math.abs(fx), math.abs(fy)) > threshold then
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
        local ud = p.fixture and p.fixture:getUserData() -- Mipo hands have no fixture
        if ud and ud.extra then ud.extra.at, ud.extra.to, ud.extra.fixture = nil, nil, nil end
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

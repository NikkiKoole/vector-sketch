-- wearables.lua: things a Mipo wears as loose toys (docs/WEARABLES.md). An item is a light body
-- of its own; let go of it near its spot on a Mipo (glasses: the eyes, pants: the hips) and it
-- welds on there. Grab it with the pointer, or jolt the Mipo (its spot's speed changing by more than
-- `grip` px/s within JOLT_STEPS steps, ~0.1 s: a landing, a throw), and it comes off.
-- A standing Mipo's parts jitter: the weld's reaction force per kilo spiked as high as a throw's
-- (92k vs 88-127k, 2026-11-08), so the jolt is a speed change over a few steps, not a force.
--
-- item: { body = <love body>, cooldown, joint, host, wearer, near, settle, vel, peak, passGroup } (this file keeps
-- those fields). spot(item, instance) -> host body, wx, wy, angle, reach (px), or nil: where the
-- item goes on that Mipo and how near counts. Worn items touch nothing (a neighbour's head bumping
-- them tore them off) but stay grabbable (the pointer skips sensors, so they aren't sensors).
-- A held item touches nothing either (bumping into the Mipos it was carried past made some impossible
-- to put on, Nikki 2026-11-09); let go, it passes through Mipos until it's clear of them.
local box2dPointerJoints = require('src.physics.box2d-pointerjoints')

local lib = {}

lib.JOLT_STEPS = 6
lib.SETTLE = 0.4   -- seconds after going on that the weld's catching up doesn't count
lib.COOLDOWN = 0.8 -- seconds after coming off before it can go on again

function lib.held(item)
    return box2dPointerJoints.getPointerJointAttachedTo(item.body) ~= nil
end

local function setWorn(item, worn)
    for _, fixture in ipairs(item.body:getFixtures()) do
        if worn then fixture:setMask(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16) else fixture:setMask() end
    end
end

-- held, or just let go inside a Mipo: touching nothing (the same mask as worn)
local function setPassing(item, passing)
    if (item.passing or false) == passing then return end
    item.passing = passing or nil
    setWorn(item, passing)
end

function lib.isWorn(item) return item.joint ~= nil end

function lib.wear(item, host, wx, wy, angle)
    local body = item.body
    body:setPosition(wx, wy)
    body:setAngle(angle)
    body:setLinearVelocity(host:getLinearVelocityFromWorldPoint(wx, wy))
    body:setAngularVelocity(host:getAngularVelocity())
    setWorn(item, true)
    item.passing = nil
    item.joint = love.physics.newWeldJoint(host, body, wx, wy, false)
    item.host, item.peak, item.vel, item.near = host, 0, nil, nil
    item.settle = lib.SETTLE
end

local function setGroup(item, group)
    for _, fixture in ipairs(item.body:getFixtures()) do fixture:setGroupIndex(group) end
end

-- Does the item still touch a fixture that match(fixture) picks (not a sensor, not its own)? Boxes found
-- by their bounding boxes, then the shapes' real distance: a box alone kept a hat lying by the feet
-- passing through that Mipo for good.
local function touching(item, match)
    local own = item.body:getFixtures()
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for _, fixture in ipairs(own) do
        local a, b, c, d = fixture:getBoundingBox()
        x0, y0, x1, y1 = math.min(x0, a), math.min(y0, b), math.max(x1, c), math.max(y1, d)
    end
    local hit = false
    item.body:getWorld():queryBoundingBox(x0, y0, x1, y1, function(fixture)
        if fixture:getBody() ~= item.body and not fixture:isSensor() and match(fixture) then
            for _, mine in ipairs(own) do
                if love.physics.getDistance(mine, fixture) < 1 then
                    hit = true
                    return false
                end
            end
        end
        return true
    end)
    return hit
end

-- pop: a little hop and spin, as if knocked off. It comes off inside its Mipo (a hat in the
-- head, glasses on the face): back to colliding there, Box2D stuck it in the face (Nikki
-- 2026-11-08), so it stays in that Mipo's collision group (never touching it) until it's clear.
function lib.takeOff(item, pop)
    if item.joint and not item.joint:isDestroyed() then item.joint:destroy() end
    local group = item.wearer and item.wearer.groupIndex
    item.joint, item.host, item.wearer = nil, nil, nil
    if not item.body:isDestroyed() then
        setWorn(item, false)
        item.passing = nil
        if group and group < 0 then
            setGroup(item, group)
            item.passGroup = group
        end
        if pop then
            local vx, vy = item.body:getLinearVelocity()
            item.body:setLinearVelocity(vx + (love.math.random() - 0.5) * 300, vy - 250)
            item.body:setAngularVelocity((love.math.random() - 0.5) * 12)
        end
    end
    item.cooldown = lib.COOLDOWN
end

-- this step's jolt for a worn item, px/s
local function jolt(item)
    local vx, vy = item.host:getLinearVelocityFromWorldPoint(item.body:getPosition())
    item.vel = item.vel or {}
    table.insert(item.vel, 1, { vx, vy })
    item.vel[lib.JOLT_STEPS + 1] = nil
    local old = item.vel[#item.vel]
    return math.sqrt((vx - old[1]) ^ 2 + (vy - old[2]) ^ 2)
end

-- the nearest Mipo whose spot for this item is in reach, and that spot
local function nearestSpot(item, mipos, spot)
    local x, y = item.body:getPosition()
    local best, bestD
    for _, inst in ipairs(mipos) do
        local host, wx, wy, angle, reach = spot(item, inst)
        if host then
            local d = math.sqrt((x - wx) ^ 2 + (y - wy) ^ 2)
            if d < reach and (not bestD or d < bestD) then
                best, bestD = { inst = inst, host = host, x = wx, y = wy, angle = angle }, d
            end
        end
    end
    return best
end

-- One step for one item. opts: mipos (list), spot (see top), grip (px/s), taken (item -> true
-- when its Mipo already wears one of its sort). Returns the jolt when it was knocked off.
function lib.update(item, dt, opts)
    if item.joint then
        if item.joint:isDestroyed() or not item.host or item.host:isDestroyed() then
            lib.takeOff(item)
        elseif lib.held(item) then
            lib.takeOff(item) -- picked off by hand
        else
            local j = jolt(item)
            item.settle = math.max(0, (item.settle or 0) - dt)
            if item.settle <= 0 then
                item.peak = math.max(item.peak or 0, j)
                if j > opts.grip then
                    lib.takeOff(item, true)
                    return j
                end
            end
        end
        return
    end
    if lib.held(item) then
        setPassing(item, true)
    elseif item.passing and not touching(item, function(f) return f:getGroupIndex() < 0 end) then
        setPassing(item, false) -- clear of every Mipo (a Mipo's parts share a negative group)
    end
    if item.passGroup and not touching(item, function(f) return f:getGroupIndex() == item.passGroup end) then
        setGroup(item, 0)
        item.passGroup = nil
    end
    item.cooldown = math.max(0, (item.cooldown or 0) - dt)
    item.near = nil
    if item.cooldown > 0 then return end
    local s = nearestSpot(item, opts.mipos, opts.spot)
    if s and not (opts.taken and opts.taken(item, s.inst)) then
        -- held over the spot: shown; let go: on
        if lib.held(item) then
            item.near = s
        else
            lib.wear(item, s.host, s.x, s.y, s.angle)
            item.wearer = s.inst
        end
    end
end

return lib

-- rail-rider.lua — Mipos riding coaster carts (docs/COASTER.md CO5). Drag a Mipo over a free cart (a
-- RAIL_CART body, src/rail-cart.lua) and it sits down in it, the pointer letting go of it; drag it out
-- again (pull it well away from its seat) and it's off. Seated, it rides through loops and rolls the
-- right way up for the cart: its hips are on a pivot at the cart's seat whose motor keeps the torso
-- upright in the cart (a servo at the pivot, not the torso's KEEP_ANGLE: that spins a part about its own
-- centre, and on a pivot at its hip the joint took ~3/4 of it away each step, tracks spike TR4); legs
-- forward, head and neck along the cart's up, arms loose (they flap). The cart is made heavier while
-- it carries someone, so a flailing rider doesn't bleed its speed away (TR4: the coaster stalled).
-- A rider touches neither its cart (the Mipo's own group) nor any track (src/track.lua's preSolve).
-- State on `state` (a hot swap keeps it): railRiders[cart] = seat, railRiderBodies[body] = cart.
local state = require('src.state')
local behaviors = require('src.behaviors')
local mipoRegistry = require('src.mipo-registry')
local mipoActions = require('src.mipo-actions')
local mipoWalk = require('src.mipo-walk')
local characterManager = require('src.character-manager')
local pointerJoints = require('src.physics.box2d-pointerjoints')

local lib = {}

lib.PIVOT_GAIN = 12      -- 1/s: the pivot's motor speed per radian off
lib.PIVOT_MAX_SPEED = 25 -- rad/s
lib.PIVOT_TORQUE = 4e6   -- the motor's most torque per unit of rider mass (LÖVE units at 200 px/m; TR4's 2e6
                         -- was for a Mipo of scale 0.15, a 0.3 one is twice as long)
lib.KP = 30              -- legs, head, neck: the cart turns fast in a loop
lib.MAX_OMEGA = 15
lib.THIGH, lib.KNEE, lib.FEET = -82, 12, -150 -- degrees from the torso: sitting, legs forward
lib.BALLAST = 3          -- a cart with a rider weighs this many riders
lib.REACH = 1.3          -- a held Mipo's hips this many cart half-lengths from the seat: it sits down
lib.PULL_OUT = 1.6       -- the pointer this many cart half-lengths from the seat: the rider comes out

local function riders()
    state.railRiders = state.railRiders or {}
    return state.railRiders
end

local function riderBodies()
    state.railRiderBodies = state.railRiderBodies or setmetatable({}, { __mode = 'k' })
    return state.railRiderBodies
end

local function alive(body) return body and not body:isDestroyed() end
local function liveMipo(inst) return inst and inst.parts and inst.parts.torso1 and alive(inst.parts.torso1.body) end

local function bodiesOf(inst)
    local out = {}
    for _, part in pairs(inst.parts or {}) do
        if alive(part.body) then out[#out + 1] = part.body end
    end
    return out
end

-- where the parent-child joint between two of a Mipo's parts is (the hip: torso1 -> luleg)
local function jointPoint(inst, parentName, partName)
    local part, parent = inst.parts[partName], inst.parts[parentName]
    if not (part and parent) then return nil end
    for _, joint in ipairs(part.body:getJoints()) do
        local a, b = joint:getBodies()
        if a == parent.body and b == part.body then
            local x, y = joint:getAnchors()
            return x, y
        end
    end
end

local function turnBodies(bodies, cx, cy, delta)
    local cs, sn = math.cos(delta), math.sin(delta)
    for _, b in ipairs(bodies) do
        local x, y = b:getPosition()
        b:setPosition(cx + (x - cx) * cs - (y - cy) * sn, cy + (x - cx) * sn + (y - cy) * cs)
        b:setAngle(b:getAngle() + delta)
    end
end

-- a cart's solid shape in its own space: half length, its top (local y, up is -y)
local function cartBox(cart)
    local minX, maxX, minY = math.huge, -math.huge, math.huge
    for _, fixture in ipairs(cart:getFixtures()) do
        if not fixture:isSensor() then
            local shape = fixture:getShape()
            if shape:typeOf('PolygonShape') then
                local p = { shape:getPoints() }
                for i = 1, #p, 2 do
                    minX, maxX, minY = math.min(minX, p[i]), math.max(maxX, p[i]), math.min(minY, p[i + 1])
                end
            elseif shape:typeOf('CircleShape') then
                local x, y = shape:getPoint()
                local r = shape:getRadius()
                minX, maxX, minY = math.min(minX, x - r), math.max(maxX, x + r), math.min(minY, y - r)
            end
        end
    end
    if minX == math.huge then return 30, -15 end
    return (maxX - minX) / 2, minY
end

-- the seat: the middle of the cart's top, in the world
local function seatPoint(cart)
    local _, top = cartBox(cart)
    return cart:getWorldPoint(0, top)
end

function lib.riderOf(cart) local s = state.railRiders and state.railRiders[cart] return s and s.inst end
function lib.isRiding(inst)
    for _, s in pairs(state.railRiders or {}) do
        if s.inst == inst then return true end
    end
    return false
end
-- true for a seated rider's bodies (src/track.lua: they touch no rail)
function lib.isRiderBody(body) return state.railRiderBodies ~= nil and state.railRiderBodies[body] ~= nil end

local function isCart(body)
    local b = behaviors.find(body, 'RAIL_CART')
    return b and b.enabled ~= false
end

-- which way the rider faces in the cart: the way the cart goes along its own forward (+x), right if still
local function facingFor(cart)
    local lock = require('src.rail-cart').lockOf(cart)
    if lock and math.abs(lock.speed) > 30 then
        return (lock.speed * lock.side) >= 0 and 'right' or 'left'
    end
    local vx, vy = cart:getLinearVelocity()
    local fx, fy = cart:getWorldVector(1, 0)
    return (vx * fx + vy * fy) >= -30 and 'right' or 'left'
end

-- every frame while seated: the pivot's servo keeps the torso upright in the cart; legs forward from it,
-- head and neck along it, torso, arms and hands loose
local function muscles(cart, seat)
    local inst = seat.inst
    local cartAngle = cart:getAngle()
    local rel = inst.parts.torso1.body:getAngle() - cartAngle
    local err = (-rel + math.pi) % (2 * math.pi) - math.pi
    seat.pivot:setMotorSpeed(math.max(-lib.PIVOT_MAX_SPEED, math.min(lib.PIVOT_MAX_SPEED, lib.PIVOT_GAIN * err)))
    local up = math.deg(cartAngle)
    local mirror = seat.facing == 'left' and -1 or 1
    local pose = { luleg = lib.THIGH, ruleg = lib.THIGH, llleg = lib.THIGH + lib.KNEE, rlleg = lib.THIGH + lib.KNEE,
        lfoot = lib.FEET, rfoot = lib.FEET }
    for name, angle in pairs(pose) do
        local keep = mipoActions.ensureKeepAngle(inst.parts[name], up + angle * mirror, lib.KP)
        if keep then
            keep.angle, keep.enabled, keep.kp, keep.maxOmega = up + angle * mirror, nil, lib.KP, lib.MAX_OMEGA
        end
    end
    for name, part in pairs(inst.parts) do
        if not pose[name] then
            local keep = mipoActions.getKeepAngle(part)
            if keep then
                if name == 'torso1' or name:find('arm') or name:find('hand') then
                    keep.enabled = false
                else
                    keep.angle, keep.enabled, keep.kp, keep.maxOmega = up, nil, lib.KP, lib.MAX_OMEGA
                end
            end
        end
    end
end

-- seat a Mipo in a cart: turned upright with it, legs forward, hips on the seat
function lib.seat(cart, inst)
    if not (alive(cart) and liveMipo(inst)) or riders()[cart] or lib.isRiding(inst) then return nil end
    mipoActions.wake(inst)
    mipoWalk.hold(inst, true) -- its legs are the seat's: no walking, no standing on its soles
    local facing = facingFor(cart)
    local ok = pcall(characterManager.switchFacing, inst, facing)
    if not ok or not liveMipo(inst) then facing = 'right' end
    local mirror = facing == 'left' and -1 or 1
    -- upright with the cart
    local tx, ty = inst.parts.torso1.body:getPosition()
    turnBodies(bodiesOf(inst), tx, ty, cart:getAngle() - inst.parts.torso1.body:getAngle())
    -- legs forward, turned at the hips and knees
    for _, side in ipairs({ 'l', 'r' }) do
        local u, l, f = side .. 'uleg', side .. 'lleg', side .. 'foot'
        local hx, hy = jointPoint(inst, 'torso1', u)
        if hx and inst.parts[u] and inst.parts[l] then
            local leg = { inst.parts[u].body, inst.parts[l].body }
            if inst.parts[f] then leg[3] = inst.parts[f].body end
            turnBodies(leg, hx, hy, cart:getAngle() + math.rad(lib.THIGH * mirror) - inst.parts[u].body:getAngle())
        end
    end
    -- hips onto the seat, moving with the cart
    local sx, sy = seatPoint(cart)
    local hx, hy = jointPoint(inst, 'torso1', 'luleg')
    if not hx then hx, hy = inst.parts.torso1.body:getPosition() end
    local vx, vy = cart:getLinearVelocity()
    for _, b in ipairs(bodiesOf(inst)) do
        local x, y = b:getPosition()
        b:setPosition(x + sx - hx, y + sy - hy)
        b:setLinearVelocity(vx, vy)
        b:setAngularVelocity(0)
    end
    -- it and its cart don't touch (the Mipo's own negative group), nor it a rail
    local seat = { inst = inst, facing = facing, groups = {}, densities = {} }
    for _, fixture in ipairs(cart:getFixtures()) do
        seat.groups[fixture] = fixture:getGroupIndex()
        fixture:setGroupIndex(inst.groupIndex or 0)
    end
    local flags = riderBodies()
    for _, b in ipairs(bodiesOf(inst)) do flags[b] = cart end
    -- the pivot at the hips
    local riderMass = mipoRegistry.totalMass(inst)
    local pivot = love.physics.newRevoluteJoint(cart, inst.parts.torso1.body, sx, sy, false)
    pivot:setMotorEnabled(true)
    pivot:setMaxMotorTorque(lib.PIVOT_TORQUE * riderMass)
    seat.pivot = pivot
    -- ballast: the cart heavier, so the rider doesn't swing it about
    local cartMass = cart:getMass()
    local k = cartMass > 0 and lib.BALLAST * riderMass / cartMass or 1
    if k > 1 then
        for _, fixture in ipairs(cart:getFixtures()) do
            seat.densities[fixture] = fixture:getDensity()
            fixture:setDensity(fixture:getDensity() * k)
        end
        cart:resetMassData()
    end
    riders()[cart] = seat
    muscles(cart, seat)
    return seat
end

-- a rider off its cart: the pivot gone, the cart as it was, the Mipo standing again
function lib.unseat(cart)
    local seat = state.railRiders and state.railRiders[cart]
    if not seat then return end
    state.railRiders[cart] = nil
    if seat.pivot and not seat.pivot:isDestroyed() then seat.pivot:destroy() end
    if alive(cart) then
        for fixture, group in pairs(seat.groups) do
            if not fixture:isDestroyed() then fixture:setGroupIndex(group) end
        end
        local changed = false
        for fixture, density in pairs(seat.densities) do
            if not fixture:isDestroyed() then
                fixture:setDensity(density)
                changed = true
            end
        end
        if changed then cart:resetMassData() end
    end
    local inst = seat.inst
    local flags = riderBodies()
    for body, c in pairs(flags) do
        if c == cart then flags[body] = nil end
    end
    if liveMipo(inst) then
        mipoWalk.hold(inst, false)
        mipoActions.wake(inst)
        inst._railOff = true -- not back in until it has been away from every seat
    end
end

-- the free cart whose seat a Mipo's hips are over, or nil
local function cartUnder(inst, carts)
    local hx, hy = jointPoint(inst, 'torso1', 'luleg')
    if not hx then hx, hy = inst.parts.torso1.body:getPosition() end
    for _, cart in ipairs(carts) do
        if not riders()[cart] then
            local half = cartBox(cart)
            local sx, sy = seatPoint(cart)
            if (hx - sx) ^ 2 + (hy - sy) ^ 2 <= (half * lib.REACH) ^ 2 then return cart end
        end
    end
end

local function heldBy(inst)
    local out = {}
    for _, pj in ipairs(pointerJoints.getPointerJoints() or {}) do
        if pj.jointBody and alive(pj.jointBody) and mipoRegistry.getFromBody(pj.jointBody) == inst then
            out[#out + 1] = pj
        end
    end
    return out
end

local function heldMipos()
    local out = {}
    for _, body in ipairs(pointerJoints.getInteractedWithPointer()) do
        local inst = mipoRegistry.getFromBody(body)
        if inst then out[inst] = true end
    end
    return out
end

-- once a frame (an engine system, src/systems.lua)
function lib.update()
    local list = state.railRiders
    -- riders: muscles, or out (dragged away, the cart or the Mipo gone)
    if list then
        for cart, seat in pairs(list) do
            if not alive(cart) or not liveMipo(seat.inst) or not seat.pivot or seat.pivot:isDestroyed() then
                lib.unseat(cart)
            else
                local out = false
                local half = cartBox(cart)
                local sx, sy = seatPoint(cart)
                for _, pj in ipairs(heldBy(seat.inst)) do
                    local px, py = pointerJoints.getPointerPosition(pj.id) -- on screen
                    if px then px, py = require('src.camera').getInstance():getWorldCoordinates(px, py) end
                    if px and (px - sx) ^ 2 + (py - sy) ^ 2 > (half * lib.PULL_OUT) ^ 2 then out = true end
                end
                if out then lib.unseat(cart) else muscles(cart, seat) end
            end
        end
    end
    -- a held Mipo over a free cart sits down in it
    local held = heldMipos()
    if not next(held) then return end
    local carts = {}
    for _, body in ipairs(state.physicsWorld:getBodies()) do
        if body:getType() == 'dynamic' and isCart(body) then carts[#carts + 1] = body end
    end
    for inst in pairs(held) do
        if liveMipo(inst) and not lib.isRiding(inst) then
            local cart = cartUnder(inst, carts)
            if inst._railOff then
                if not cart then inst._railOff = nil end
            elseif cart then
                for _, pj in ipairs(heldBy(inst)) do pointerJoints.killMouseJointIfPossible(pj.id) end
                if lib.seat(cart, inst) then require('src.mipo-voice').squeak(inst, 'pickup') end
            end
        end
    end
end

return lib

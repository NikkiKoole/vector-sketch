-- rail-cart.lua — carts on coaster tracks (docs/COASTER.md CO3): a body with the RAIL_CART behavior
-- locks onto the nearest track when it's let go near one, and rides it. Real Box2D plus a rail lock:
-- the body stays dynamic (gravity, things bumping it, riders on joints all act on it), and after each
-- physics step it's put back on its rail: the change in its velocity along the track is kept (gravity
-- down the slope, a push, a rider's pull), the rest is the rail's reaction and goes; it's moved on along
-- the line by its speed, turned along it, its up side the side it was dropped on. A joint that slides
-- along a curve. Carried by the pointer, or off an open end, it lets go. A locked cart touches no rail
-- (src/track.lua's preSolve), so it rides through crossings in either lane.
-- The locks live on state.railCarts (body -> lock), so a hot swap keeps them.
local state = require('src.state')
local track = require('src.track')
local behaviors = require('src.behaviors')
local units = require('src.physics-units')

local lib = {}

lib.BEHAVIOR = 'RAIL_CART'
lib.LOCK_MARGIN = 70   -- let go this near the rail (beyond its own half height), it locks on
lib.DRAG = 0.03        -- rolling drag, per second (a share of the speed)
lib.AIR_DRAG = 0.00008 -- drag growing with speed squared (per px at 100 px/m)
lib.MAX_SPEED = 4000   -- px/s at 100 px per metre (src/physics-units.lua): a Mipo-scale drop of 3500 px reaches ~3700 at 200

-- the painted zones (src/track.lua ZONES), numbers at 100 px per metre
lib.LIFT_SPEED = 260   -- a lift chain catches a slower cart and pulls it on at this speed (along the drawn way)
lib.LIFT_PULL = 2000   -- how hard it catches up to that, px/s^2
lib.BOOST = 900        -- a boost pushes on the way it's going, px/s^2
lib.BRAKE = 1400       -- a brake slows it, px/s^2 ...
lib.BRAKE_TO = 90      -- ... down to a crawl, never backwards

local function locks()
    state.railCarts = state.railCarts or setmetatable({}, { __mode = 'k' })
    return state.railCarts
end

function lib.lockOf(body) return state.railCarts and state.railCarts[body] end

-- how far the body's centre sits above its own bottom (its fixtures' lowest point in body space)
local function halfHeight(body)
    local lowest = 0
    for _, fixture in ipairs(body:getFixtures()) do
        if not fixture:isSensor() then
            local shape = fixture:getShape()
            if shape:typeOf('CircleShape') then
                local _, y = shape:getPoint()
                lowest = math.max(lowest, y + shape:getRadius())
            elseif shape:typeOf('PolygonShape') then
                local points = { shape:getPoints() }
                for i = 2, #points, 2 do lowest = math.max(lowest, points[i]) end
            end
        end
    end
    return lowest
end

-- put the body on its rail at the lock's arc position with the lock's speed. lock.side is the side of the
-- line it rides before any roll stretch; a roll turns it round the rail (through it, seen from the side)
local function place(body, lock)
    local layout = track.layout(lock.track)
    local lx, ly, ltx, lty, edge, inside = track.pointAt(layout, lock.s)
    local tb = lock.track.body
    local px, py = tb:getWorldPoint(lx, ly)
    local tx, ty = tb:getWorldVector(ltx, lty)
    local roll = track.rollAt(layout, lock.s)
    local rollRate = (track.rollAt(layout, lock.s + 1) - track.rollAt(layout, lock.s - 1)) / 2
    local ux, uy = ty * lock.side, -tx * lock.side -- the cart's up: the side of the line it rides
    local out = lock.height * math.cos(roll)
    body:setPosition(px + ux * out, py + uy * out)
    body:setAngle(math.atan2(ux, -uy) + roll * lock.side)
    body:setLinearVelocity(tx * lock.speed, ty * lock.speed)
    body:setAngularVelocity(lock.speed * (track.curvatureAt(layout, lock.s) + rollRate * lock.side))
    lock.tx, lock.ty = tx, ty
    lock.lane = layout.lane[edge]
    lock.zone = layout.zone[edge]
    return inside
end

-- the bodies that ride along in a cart (a seated Mipo, src/rail-rider.lua)
local function passengers(body)
    local seat = state.railRiders and state.railRiders[body]
    local out = {}
    if seat and seat.inst and seat.inst.parts then
        for _, part in pairs(seat.inst.parts) do
            if part.body and not part.body:isDestroyed() then out[#out + 1] = part.body end
        end
    end
    return out
end

-- place the cart, and give its passengers the same correction rigidly, in the cart's frame: moved and
-- turned with it, their velocity turned and shifted as its was. The rail's pull on the cart is theirs too,
-- so the seat's pivot only carries their own movement (left behind, they were dragged back by it and the
-- cart lost its speed to them: a loop's worth of energy)
local function placeAll(body, lock)
    local riders = passengers(body)
    if #riders == 0 then return place(body, lock) end
    local x0, y0 = body:getPosition()
    local a0 = body:getAngle()
    local vx0, vy0 = body:getLinearVelocity()
    local w0 = body:getAngularVelocity()
    local inside = place(body, lock)
    local x1, y1 = body:getPosition()
    local da = body:getAngle() - a0
    local vx1, vy1 = body:getLinearVelocity()
    local dw = body:getAngularVelocity() - w0
    local cs, sn = math.cos(da), math.sin(da)
    for _, b in ipairs(riders) do
        local px, py = b:getPosition()
        local rx, ry = px - x0, py - y0
        b:setPosition(x1 + rx * cs - ry * sn, y1 + rx * sn + ry * cs)
        b:setAngle(b:getAngle() + da)
        local vx, vy = b:getLinearVelocity()
        local ux, uy = vx - vx0, vy - vy0
        b:setLinearVelocity(vx1 + ux * cs - uy * sn, vy1 + ux * sn + uy * cs)
        b:setAngularVelocity(b:getAngularVelocity() + dw)
    end
    return inside
end

-- lock a body onto a track at arc position s, on `side` of the line (+1: left of the drawn way), still
function lib.lockAt(body, thing, s, side)
    local lock = { track = thing, s = s, side = side, height = halfHeight(body), speed = 0 }
    if state.railCartsFlown then state.railCartsFlown[body] = nil end
    locks()[body] = lock
    place(body, lock)
    return lock
end

-- lock a body onto the nearest track it's near, or nil (a cart that flew off an end: only once it has
-- been clear of every rail)
function lib.tryLock(body)
    local h = halfHeight(body)
    local bx, by = body:getPosition()
    local best, bestD = nil, h + lib.LOCK_MARGIN
    for _, thing in ipairs(track.list()) do
        local layout = track.layout(thing)
        if layout.n >= 2 then
            local lx, ly = thing.body:getLocalPoint(bx, by)
            local s, d = track.nearestArc(layout, lx, ly)
            if d <= bestD then
                local px, py, tx, ty = track.pointAt(layout, s)
                local side = ((lx - px) * ty - (ly - py) * tx) >= 0 and 1 or -1 -- left of the direction: +1
                -- past an odd number of rolls the side it's on is the other one before them
                if math.cos(track.rollAt(layout, s)) < 0 then side = -side end
                best, bestD = { track = thing, s = s, side = side, height = h }, d
            end
        end
    end
    local flown = state.railCartsFlown
    if flown and flown[body] then
        if not best then flown[body] = nil end
        return nil
    end
    if not best then return nil end
    local tb = best.track.body
    local layout = track.layout(best.track)
    local _, _, ltx, lty = track.pointAt(layout, best.s)
    local tx, ty = tb:getWorldVector(ltx, lty)
    local vx, vy = body:getLinearVelocity()
    best.speed = vx * tx + vy * ty
    locks()[body] = best
    place(body, best)
    return best
end

-- set a locked cart's speed along its track (+ along the way the line was drawn): a launch, a test
function lib.setSpeed(body, speed)
    local lock = lib.lockOf(body)
    if not lock then return end
    lock.speed = speed
    placeAll(body, lock) -- its riders launched with it
end

function lib.release(body)
    if state.railCarts then state.railCarts[body] = nil end
end

local function grabbed(body)
    return require('src.physics.box2d-pointerjoints').getPointerJointAttachedTo(body) ~= nil
end

-- a painted zone's say in a cart's speed over dt (+ is the way the track was drawn)
function lib.zoneSpeed(zone, speed, dt)
    if zone == 'lift' then
        local lift = units.speed(lib.LIFT_SPEED)
        if speed < lift then speed = math.min(lift, speed + units.accel(lib.LIFT_PULL) * dt) end
    elseif zone == 'boost' then
        speed = speed + (speed >= 0 and 1 or -1) * units.accel(lib.BOOST) * dt
    elseif zone == 'brake' then
        local floor = units.speed(lib.BRAKE_TO)
        local slow = units.accel(lib.BRAKE) * dt
        if speed > floor then
            speed = math.max(floor, speed - slow)
        elseif speed < -floor then
            speed = math.min(-floor, speed + slow)
        end
    end
    return speed
end

-- one locked cart after a physics step of dt
local function ride(body, lock, dt)
    local layout = track.layout(lock.track)
    -- the velocity's change along the track since it was placed is kept (gravity, pushes, riders)
    local vx, vy = body:getLinearVelocity()
    local dvx, dvy = vx - lock.tx * lock.speed, vy - lock.ty * lock.speed
    local _, _, ltx, lty = track.pointAt(layout, lock.s)
    local tx, ty = lock.track.body:getWorldVector(ltx, lty)
    local speed = lock.speed + dvx * tx + dvy * ty
    local ref = units.toReferenceSpeed(math.abs(speed))
    speed = speed - speed * (lib.DRAG + lib.AIR_DRAG * ref) * dt
    speed = lib.zoneSpeed(lock.zone, speed, dt)
    local max = units.speed(lib.MAX_SPEED)
    lock.speed = math.max(-max, math.min(max, speed))
    lock.s = lock.s + lock.speed * dt
    if not placeAll(body, lock) then
        lib.release(body) -- off an open end: it flies on with its speed,
        state.railCartsFlown = state.railCartsFlown or setmetatable({}, { __mode = 'k' })
        state.railCartsFlown[body] = true -- and doesn't lock on again until it's been clear of every rail
    end
end

local function wantsRail(body)
    local b = behaviors.find(body, lib.BEHAVIOR)
    return b and b.enabled ~= false
end

-- after every physics step (main.lua's substep loop): carts ride their rails; a cart picked up lets go
function lib.afterStep(dt)
    local list = state.railCarts
    if not list then return end
    for body, lock in pairs(list) do
        if body:isDestroyed() or lock.track.body:isDestroyed() or not wantsRail(body) or grabbed(body) then
            list[body] = nil
        else
            ride(body, lock, dt)
        end
    end
end

-- once a frame (an engine system, src/systems.lua): a cart let go near a track locks on
function lib.update()
    local list = state.railCarts
    local world = state.physicsWorld
    if not world or #track.list() == 0 then return end
    for _, body in ipairs(world:getBodies()) do
        if body:getType() == 'dynamic' and not (list and list[body]) and wantsRail(body) and not grabbed(body) then
            lib.tryLock(body)
        end
    end
end

return lib

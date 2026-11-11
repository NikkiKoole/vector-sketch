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
lib.LOCK_MARGIN = 30   -- let go this near the rail (beyond its own half height), it locks on
lib.DRAG = 0.03        -- rolling drag, per second (a share of the speed)
lib.AIR_DRAG = 0.00008 -- drag growing with speed squared (per px at 100 px/m)
lib.MAX_SPEED = 2500   -- px/s at 100 px per metre (src/physics-units.lua)

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

-- put the body on its rail at the lock's arc position with the lock's speed
local function place(body, lock)
    local layout = track.layout(lock.track)
    local lx, ly, ltx, lty, edge, inside = track.pointAt(layout, lock.s)
    local tb = lock.track.body
    local px, py = tb:getWorldPoint(lx, ly)
    local tx, ty = tb:getWorldVector(ltx, lty)
    local ux, uy = ty * lock.side, -tx * lock.side -- the cart's up: the side of the line it rides
    body:setPosition(px + ux * lock.height, py + uy * lock.height)
    body:setAngle(math.atan2(ux, -uy))
    body:setLinearVelocity(tx * lock.speed, ty * lock.speed)
    body:setAngularVelocity(lock.speed * track.curvatureAt(layout, lock.s))
    lock.tx, lock.ty = tx, ty
    lock.lane = layout.lane[edge]
    return inside
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
    place(body, lock)
end

function lib.release(body)
    if state.railCarts then state.railCarts[body] = nil end
end

local function grabbed(body)
    return require('src.physics.box2d-pointerjoints').getPointerJointAttachedTo(body) ~= nil
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
    local max = units.speed(lib.MAX_SPEED)
    lock.speed = math.max(-max, math.min(max, speed))
    lock.s = lock.s + lock.speed * dt
    if not place(body, lock) then
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

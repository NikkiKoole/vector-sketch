-- coaster: a drawn coaster track and a cart on its rail (docs/COASTER.md): off the station, down the drop,
-- round the loop upside down, over two hills and off the ski jump, then back to the station by itself.
-- Draw more track with the draw rail's 'track' tool; any body with the RAIL_CART behavior rides one.
-- keys: r: the cart back to the station now   f: follow the cart (again: the whole course)

local s = {}

local STATION_WAIT = 1.5 -- seconds at the station before the nudge
local NUDGE = 150        -- px/s off the station
local GIVE_UP = 2.5      -- seconds off the rail, or nearly still on it away from the station: back it goes
local VIEW = { x = -250, y = -520, scale = 0.19 } -- the whole course beside the tool rail, 1000 wide

local function lab() -- on state: a script hot reload keeps it
    state.coasterSpike = state.coasterSpike or { timer = 0 }
    return state.coasterSpike
end

local function findCart()
    for _, body in ipairs(world:getBodies()) do
        local ud = body:getUserData()
        if ud and ud.thing and ud.thing.label == 'cart' then return body end
    end
end

local function held(body)
    for _, b in ipairs(getInteractedWithPointer()) do
        if b == body then return true end
    end
    return false
end

local function toStation()
    local c = lab()
    local body = c.cart
    if not (body and not body:isDestroyed()) then return end
    railCart.release(body)
    body:setPosition(c.startX, c.startY)
    body:setAngle(0)
    body:setLinearVelocity(0, 0)
    body:setAngularVelocity(0)
    railCart.tryLock(body)
    c.timer, c.mode = 0, 'station'
end

function s.onStart()
    worldState.paused = false
    cam:setScale(VIEW.scale)
    cam:setTranslation(VIEW.x, VIEW.y)
    local c = lab()
    c.cart = findCart()
    if c.cart then
        c.startX, c.startY = c.cart:getPosition()
        toStation()
    end
end

function s.update(dt)
    local c = lab()
    local body = c.cart
    if not (body and not body:isDestroyed()) then return end
    if held(body) then
        c.timer, c.mode = 0, 'held'
        return
    end
    local lock = railCart.lockOf(body)
    c.timer = c.timer + dt
    if c.mode == 'station' then
        if lock and c.timer > STATION_WAIT then
            railCart.setSpeed(body, NUDGE)
            c.timer, c.mode = 0, 'riding'
        end
    elseif not lock then
        if c.mode ~= 'flying' then c.timer, c.mode = 0, 'flying' end
        if c.timer > GIVE_UP then toStation() end
    else
        if c.mode ~= 'riding' then c.timer, c.mode = 0, 'riding' end
        if math.abs(lock.speed) > 40 then c.timer = 0 end
        if c.timer > GIVE_UP then toStation() end -- stuck in a dip: back to the station
    end
end

function s.onKeyPress(key)
    local c = lab()
    if key == 'r' then toStation() end
    if key == 'f' and c.cart then
        c.follow = not c.follow
        if c.follow then
            camera.follow(c.cart)
            camera.zoomTo(0.7)
        else
            camera.follow(nil)
            camera.zoomTo(VIEW.scale)
            cam:setTranslation(VIEW.x, VIEW.y)
        end
    end
end

return s

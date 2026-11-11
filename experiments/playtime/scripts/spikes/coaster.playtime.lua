-- coaster: a drawn coaster track and a cart on its rail (docs/COASTER.md): off the station, down the drop,
-- round the loop upside down, over two hills and off the ski jump, then back to the station by itself.
-- Drag a Mipo over a cart and it sits in it and rides along; drag it well away to take it out.
-- Draw more track with the draw rail's 'track' tool; select a track to paint lift / boost / brake / roll on it.
-- A cart goes back to its home, where it last locked on: drop one on your own track and it lives there.
-- While drawing a track hold h (lift), b (boost), s (brake) or f (roll) to paint that stretch.
-- keys: n: a new cart at the mouse   r: every cart home now   v: the view: station, follow a cart, all of it

local s = {}

local HOME_WAIT = 1.5 -- seconds still at home before the nudge
local NUDGE = 350     -- px/s off home, along the way the track was drawn
local GIVE_UP = 2.5   -- seconds off the rail, or nearly still on it away from home: back it goes
-- the views `v` goes through: the station with the Mipos below it, following a cart, the whole course
local VIEWS = {
    { x = -5750, y = -1500, scale = 0.18 },
    'follow',
    { x = -750, y = -1500, scale = 0.068 },
}
local VIEW = VIEWS[1]

local function lab() -- on state: a script hot reload keeps it
    state.coasterSpike = state.coasterSpike or { carts = {} }
    return state.coasterSpike
end

local function alive(body) return body and not body:isDestroyed() end

local function held(body)
    for _, b in ipairs(getInteractedWithPointer()) do
        if b == body then return true end
    end
    return false
end

-- put a cart back at its home, still; it waits there before its nudge
local function goHome(c)
    if not (alive(c.body) and c.home and alive(c.home.track.body)) then return end
    railCart.release(c.body)
    c.body:setLinearVelocity(0, 0)
    c.body:setAngularVelocity(0)
    c.lock = railCart.lockAt(c.body, c.home.track, c.home.s, c.home.side)
    c.timer, c.mode = 0, 'home'
end

local function addCart(body)
    local c = { body = body, timer = 0, mode = 'loose' }
    table.insert(lab().carts, c)
    return c
end

local function newCartAt(x, y)
    local thing = objectManager.addThing('rectangle', { x = x, y = y, width = 260, height = 90, label = 'cart' })
    thing.behaviors = { { name = 'RAIL_CART', enabled = true } }
    return addCart(thing.body)
end

function s.onStart()
    worldState.paused = false
    cam:setScale(VIEW.scale)
    cam:setTranslation(VIEW.x, VIEW.y)
    local l = lab()
    l.carts, l.view = {}, 1
    for _, body in ipairs(world:getBodies()) do
        local ud = body:getUserData()
        if ud and ud.thing and ud.thing.label == 'cart' then addCart(body) end
    end
end

-- one cart this frame: a fresh lock is its new home (unless we put it there); stuck or flown off: home
local function tend(c, dt)
    if held(c.body) then
        c.timer, c.mode = 0, 'held'
        return
    end
    local lock = railCart.lockOf(c.body)
    if lock and lock ~= c.lock then -- locked on by itself: dropped on a rail, or landed on one
        c.lock = lock
        c.home = { track = lock.track, s = lock.s, side = lock.side }
        c.timer, c.mode = 0, 'home'
    end
    c.timer = c.timer + dt
    if c.mode == 'home' then
        if not lock then
            c.timer, c.mode = 0, 'flying'
        elseif math.abs(lock.speed) > 40 then
            c.timer, c.mode = 0, 'riding'
        elseif c.timer > HOME_WAIT then
            railCart.setSpeed(c.body, NUDGE)
            c.timer, c.mode = 0, 'riding'
        end
    elseif not lock then
        if c.mode ~= 'flying' then c.timer, c.mode = 0, 'flying' end
        if c.timer > GIVE_UP then goHome(c) end
    else
        if c.mode ~= 'riding' then c.timer, c.mode = 0, 'riding' end
        if math.abs(lock.speed) > 40 then c.timer = 0 end
        if c.timer > GIVE_UP then goHome(c) end -- stuck in a dip
    end
end

function s.update(dt)
    local l = lab()
    for i = #l.carts, 1, -1 do
        local c = l.carts[i]
        if alive(c.body) then tend(c, dt) else table.remove(l.carts, i) end
    end
end

function s.onKeyPress(key)
    local l = lab()
    if key == 'n' then
        local x, y = mouseWorldPos()
        newCartAt(x, y)
    end
    if key == 'r' then
        for _, c in ipairs(l.carts) do goHome(c) end
    end
    if key == 'v' then -- not f: f paints a roll while drawing a track
        l.view = (l.view or 1) % #VIEWS + 1
        local view = VIEWS[l.view]
        if view == 'follow' and l.carts[1] then
            camera.follow(l.carts[#l.carts].body) -- the newest cart
            camera.zoomTo(0.3)
        else
            if view == 'follow' then view = VIEWS[1] end
            camera.follow(nil)
            camera.zoomTo(view.scale)
            cam:setTranslation(view.x, view.y)
        end
    end
end

return s

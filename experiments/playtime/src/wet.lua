-- wet.lua — things getting wet and drying (docs/MATERIALS.md, MT6): wet spots that stick to the body
-- they land on and dry from their edge in, and a waterline under which every body is wet. The
-- plasticine shader (src/render/shaders.lua) darkens what's wet (porous things most) and gives it a
-- sharp shine. Off unless a scene uses it: no spots, nothing changes.
--   wet.splash(wx, wy, r, amount)  a wet spot; on the body under it if any (it moves with it)
--   wet.setWaterline(y)            everything below world y gets wet while it's there (nil: none)
--   wet.update(dt)                 drying, the waterline, and the spots' screen places for the shader
--   wet.shaderSpots(body)          count, the spots near that body as { x, y, r, amount } in screen pixels
--   wet.clear()
-- The spots live on `state` (a hot swap keeps them).
local state = require('src.state')
local camera = require('src.camera')

local lib = {}

lib.MAX = 12         -- the shader's MAX_WET
lib.DRY_SECONDS = 25 -- from soaked to dry

local function data()
    state.wet = state.wet or { spots = {}, waterline = nil }
    return state.wet
end

local function cam() return camera.getInstance() end

-- the body under a world point (its fixtures' shapes), or nil
local function bodyAt(wx, wy)
    local found
    state.physicsWorld:queryBoundingBox(wx - 1, wy - 1, wx + 1, wy + 1, function(fixture)
        if not fixture:isSensor() and fixture:testPoint(wx, wy) then
            found = fixture:getBody()
            return false
        end
        return true
    end)
    return found
end

local function addSpot(spot)
    local spots = data().spots
    if #spots >= lib.MAX then
        -- the driest makes room
        local driest = 1
        for i, s in ipairs(spots) do
            if s.amount < spots[driest].amount then driest = i end
        end
        table.remove(spots, driest)
    end
    spots[#spots + 1] = spot
end

function lib.splash(wx, wy, r, amount)
    local body = bodyAt(wx, wy)
    local spot = { r = r or 60, amount = amount or 1 }
    if body then
        spot.body = body
        spot.lx, spot.ly = body:getLocalPoint(wx, wy)
    else
        spot.x, spot.y = wx, wy
    end
    addSpot(spot)
end

function lib.setWaterline(y)
    data().waterline = y
end

function lib.clear()
    state.wet = nil
end

-- a body's size, roughly: its fixtures' bounding box
local function bodyRadius(body)
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for _, f in ipairs(body:getFixtures()) do
        if not f:isSensor() then
            local ax, ay, bx, by = f:getBoundingBox()
            x0, y0, x1, y1 = math.min(x0, ax), math.min(y0, ay), math.max(x1, bx), math.max(y1, by)
        end
    end
    if x0 == math.huge then return nil end
    return math.max(x1 - x0, y1 - y0) * 0.75
end

function lib.update(dt)
    local d = data()
    -- the waterline: every dynamic body whose middle is under it is soaked (its spot refreshed)
    if d.waterline then
        for _, body in ipairs(state.physicsWorld:getBodies()) do
            if body:getType() == 'dynamic' then
                local _, by = body:getPosition()
                if by > d.waterline then
                    local spot
                    for _, s in ipairs(d.spots) do
                        if s.body == body and s.soak then spot = s end
                    end
                    if spot then
                        spot.amount = 1
                    else
                        local r = bodyRadius(body)
                        if r then addSpot({ body = body, lx = 0, ly = 0, r = r, amount = 1, soak = true }) end
                    end
                end
            end
        end
    end
    -- drying, and the screen places for this frame
    local keep = {}
    local c = cam()
    local dpi = love.graphics.getDPIScale()
    local scale = c:getScale()
    for _, s in ipairs(d.spots) do
        s.amount = s.amount - (dt or 0) / lib.DRY_SECONDS
        if s.amount > 0 and (not s.body or not s.body:isDestroyed()) then
            local wx, wy = s.x, s.y
            if s.body then wx, wy = s.body:getWorldPoint(s.lx, s.ly) end
            local sx, sy = c:getScreenCoordinates(wx, wy)
            s.screen = { sx * dpi, sy * dpi, s.r * scale * dpi, s.amount }
            keep[#keep + 1] = s
        end
    end
    d.spots = keep
end

local empty = {}
for i = 1, lib.MAX do empty[i] = { 0, 0, 0, 0 } end
local buffer = {}

-- a body's reach from its middle (its fixtures' bounding box, measured once; the shape doesn't change)
local reach = setmetatable({}, { __mode = 'k' })
local function reachOf(body)
    local r = reach[body]
    if r == nil then
        local bx, by = body:getPosition()
        r = 0
        for _, f in ipairs(body:getFixtures()) do
            local x0, y0, x1, y1 = f:getBoundingBox()
            r = math.max(r, math.abs(x0 - bx), math.abs(x1 - bx), math.abs(y0 - by), math.abs(y1 - by))
        end
        r = r * 1.5 -- a picture can reach past its body's shapes
        reach[body] = r
    end
    return r
end

-- The spots for the shader, as { x, y, r, amount } in screen pixels: with a body, only those that
-- reach it (a dry part pays nothing per pixel: the shader loops over what it's sent); without one
-- (a limb ribbon, drawn in the world), all of them.
function lib.shaderSpots(body)
    local d = state.wet
    if not d or #d.spots == 0 then return 0, empty end
    local bsx, bsy, br
    if body and not body:isDestroyed() then
        local c = cam()
        local dpi = love.graphics.getDPIScale()
        local x, y = c:getScreenCoordinates(body:getPosition())
        bsx, bsy, br = x * dpi, y * dpi, reachOf(body) * c:getScale() * dpi
    end
    local n = 0
    for _, s in ipairs(d.spots) do
        local sc = s.screen
        if sc then
            local near = true
            if bsx then
                local dx, dy = sc[1] - bsx, sc[2] - bsy
                local rr = sc[3] + br
                near = dx * dx + dy * dy < rr * rr
            end
            if near then
                n = n + 1
                buffer[n] = sc
            end
        end
    end
    for i = n + 1, lib.MAX do buffer[i] = empty[i] end
    return n, buffer
end

return lib

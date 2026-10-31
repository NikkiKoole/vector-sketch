-- Two-finger camera gestures for touch screens: pinch zooms around the point between the
-- fingers, moving both pans. In the editor and in play mode.
--
-- main.lua asks first: pressed/moved/released return true when the touch belongs to a
-- gesture, and then the input manager never hears of it. When a second finger lands, the
-- first one's press (a grab, a selection) is let go through `releaseFirst`, and the gesture
-- keeps every finger until all are lifted: lifting one doesn't start a grab with the other.
--
-- State lives on state.touchGestures so a hot swap of this file doesn't lose it.
local state = require('src.state')
local cam = require('src.camera').getInstance()
local cameraFollow = require('src.camera-follow')

local lib = {}

local MIN_SCALE, MAX_SCALE = 0.01, 50 -- the wheel's limits (main.lua love.wheelmoved)

local function gestures()
    state.touchGestures = state.touchGestures or { down = {}, count = 0, pinch = nil }
    return state.touchGestures
end

-- The midpoint and distance of the two pinch fingers, in screen pixels.
local function span(g)
    local a, b = g.down[g.pinch.a], g.down[g.pinch.b]
    return (a.x + b.x) / 2, (a.y + b.y) / 2, math.max(1, math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2))
end

-- releaseFirst(id, x, y): lets go of what the first finger was doing.
function lib.pressed(id, x, y, releaseFirst)
    local g = gestures()
    -- forget fingers whose release never came (the app went to the background mid-touch)
    local onScreen = {}
    for _, t in ipairs(love.touch.getTouches()) do onScreen[t] = true end
    for other in pairs(g.down) do
        if other ~= id and not onScreen[other] then
            g.down[other] = nil
            g.count = g.count - 1
        end
    end
    if g.count == 0 then g.pinch = nil end
    g.down[id] = { x = x, y = y }
    g.count = g.count + 1
    if g.pinch then return true end -- a third finger: the gesture's too
    if g.count < 2 then return false end

    local first
    for other in pairs(g.down) do
        if other ~= id then first = other end
    end
    releaseFirst(first, g.down[first].x, g.down[first].y)
    g.pinch = { a = first, b = id }
    g.pinch.mx, g.pinch.my, g.pinch.dist = span(g)
    return true
end

function lib.moved(id, x, y)
    local g = gestures()
    if not g.down[id] then return false end
    g.down[id].x, g.down[id].y = x, y
    local p = g.pinch
    if not p then return false end
    if not (g.down[p.a] and g.down[p.b]) then return true end -- one of the two lifted

    local mx, my, dist = span(g)
    -- pan by how far the midpoint moved, then zoom around where it is now
    local tx, ty = cam:getTranslation()
    cam:setTranslation(tx - (mx - p.mx) / cam.scale, ty - (my - p.my) / cam.scale)
    local s = dist / p.dist
    local newScale = cam.scale * s
    if newScale > MIN_SCALE and newScale < MAX_SCALE and cameraFollow.zoomAllowed(newScale) then
        local wx, wy = cam:getWorldCoordinates(mx, my)
        cam:scaleToPoint(s, wx, wy)
    end
    cameraFollow.notePan() -- you steer now, until the next touch
    p.mx, p.my, p.dist = mx, my, dist
    return true
end

function lib.released(id)
    local g = gestures()
    if not g.down[id] then return false end
    g.down[id] = nil
    g.count = g.count - 1
    local owned = g.pinch ~= nil
    if g.count == 0 then g.pinch = nil end
    return owned
end

return lib

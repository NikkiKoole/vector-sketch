-- src/render/view.lua: the part of the world on screen, for skipping what's off it
-- (docs/MIPO-DRAWING.md L0, L1b). Read from the current transform (the camera's, or whatever a
-- canvas draw set), so it holds wherever drawing happens.
local lib = {}

-- The world rectangle the screen (or the active canvas) shows: x1, y1, x2, y2.
function lib.worldRect()
    local w, h = love.graphics.getDimensions()
    local canvas = love.graphics.getCanvas()
    if type(canvas) == 'userdata' then w, h = canvas:getDimensions() end
    local ax, ay = love.graphics.inverseTransformPoint(0, 0)
    local bx, by = love.graphics.inverseTransformPoint(w, 0)
    local cx, cy = love.graphics.inverseTransformPoint(0, h)
    local dx, dy = love.graphics.inverseTransformPoint(w, h)
    return math.min(ax, bx, cx, dx), math.min(ay, by, cy, dy), math.max(ax, bx, cx, dx), math.max(ay, by, cy, dy)
end

-- How far a body's fixtures reach from its centre (the furthest corner or circle edge). Kept per
-- body: a resized thing is a new body (objectManager.recreateThingFromBody).
local reachOf = setmetatable({}, { __mode = 'k' })
function lib.bodyReach(body)
    local reach = reachOf[body]
    if reach then return reach end
    reach = 0
    for _, fixture in ipairs(body:getFixtures()) do
        local shape = fixture:getShape()
        if shape:getType() == 'circle' then
            local px, py = shape:getPoint()
            reach = math.max(reach, math.sqrt(px * px + py * py) + shape:getRadius())
        else
            local points = { shape:getPoints() }
            for i = 1, #points, 2 do
                reach = math.max(reach, math.sqrt(points[i] * points[i] + points[i + 1] * points[i + 1]))
            end
        end
    end
    reachOf[body] = reach
    return reach
end

return lib

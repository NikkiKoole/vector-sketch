--selection-rect.lua
local lib = {}
local mathutils = require 'src.math-utils'
-- Include the drawDottedLine function here
local function drawDottedLine(x1, y1, x2, y2, dotSize, spacing)
    local dx = x2 - x1
    local dy = y2 - y1
    local distance = math.sqrt(dx * dx + dy * dy)

    local numDots = math.floor(distance / spacing)

    local stepX = dx / distance
    local stepY = dy / distance

    for i = 0, numDots do
        local cx = x1 + stepX * spacing * i
        local cy = y1 + stepY * spacing * i
        love.graphics.rectangle("fill", cx, cy, dotSize, dotSize)
    end
end

-- Convert local shape vertices to world coordinates based on the body's position and angle
local function getShapeWorldPoints(body, shape)
    local points = {}
    local angle = body:getAngle()
    local xBody, yBody = body:getPosition()

    if shape:typeOf("CircleShape") then
        -- For circles, represent as the center point
        table.insert(points, { x = xBody, y = yBody })
    elseif shape:typeOf("PolygonShape") or shape:typeOf("EdgeShape") then
        local points2 = { shape:getPoints() }

        for i = 1, #points2, 2 do
            local localX, localY = points2[i], points2[i + 1]
            -- Apply rotation
            local rotatedX = localX * math.cos(angle) - localY * math.sin(angle)
            local rotatedY = localX * math.sin(angle) + localY * math.cos(angle)
            -- Translate to world coordinates
            local worldX = xBody + rotatedX
            local worldY = yBody + rotatedY
            table.insert(points, { x = worldX, y = worldY })
        end
    elseif shape:typeOf("RectangleShape") then
        print('NOT HANDLING THIS SHAPE RectangleShape')
        -- Handle RectangleShape if using a custom shape type
        -- Love2D does not have a native RectangleShape; rectangles are typically PolygonShapes
    else
        print('NOT HANDLING THIS SHAPE ??')
    end

    return points
end



function lib.draw(selection)
    local x, y = love.mouse:getPosition()
    local tlx = math.min(selection.x, x)
    local tly = math.min(selection.y, y)
    local brx = math.max(selection.x, x)
    local bry = math.max(selection.y, y)
    -- print(inspect(selection), x, y)
    drawDottedLine(tlx, tly, brx, tly, 5, 10)
    drawDottedLine(brx, tly, brx, bry, 5, 10)
    drawDottedLine(tlx, bry, brx, bry, 5, 10)
    drawDottedLine(tlx, tly, tlx, bry, 5, 10)
end

function lib.selectWithin(world, rect)
    local bodiesInside = {}
    for _, body in pairs(world:getBodies()) do
        local userData = body:getUserData()
        local thing = userData and userData.thing
        if thing then
            local fixtures = body:getFixtures()
            local allFixturesInside = true
            for _, fixture in ipairs(fixtures) do
                local shape = fixture:getShape()
                local worldPoints = getShapeWorldPoints(body, shape)

                -- For each point of the shape, check if it's inside the rectangle
                for _, point in ipairs(worldPoints) do
                    if not mathutils.pointInRect(point.x, point.y, rect) then
                        allFixturesInside = false
                        break -- No need to check further points
                    end
                end
                if not allFixturesInside then
                    break -- No need to check further fixtures
                end
            end
            if allFixturesInside then
                table.insert(bodiesInside, thing)
            end
        end
    end
    return bodiesInside
end

return lib

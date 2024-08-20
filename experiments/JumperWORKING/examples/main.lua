--- Very minimal usage example for Jumper

-- Set up a collision map


local map = {}

for y = 1, 100 do
    map[y] = {}
    for x = 1, 100 do
        map[y][x] = math.random() < .2 and 1 or 0
    end
end




-- Value for walkable tiles
local walkable = 0
local cellsize = 8
local pathnodesize = 3
-- Library setup
-- Calls the grid class
local Grid = require("jumper.grid")
-- Calls the pathfinder class
local Pathfinder = require("jumper.pathfinder")

-- Creates a grid object
local grid = Grid(map)

-- Creates a pathfinder object using Jump Point Search algorithm
local myFinder = Pathfinder(grid, 'JPS', walkable)

-- Define start and goal locations coordinates
local startx, starty = 1, 1
local endx, endy = 5, 8

-- Calculates the path, and its length
local path = myFinder:getPath(startx, starty, endx, endy)

-- Pretty-printing the results
if path then
    print(('Path found! Length: %.2f'):format(path:getLength()))
    for node, count in path:nodes() do
        print(('Step: %d - x: %d - y: %d'):format(count, node:getX(), node:getY()))
    end
end


function love.mousepressed(x, y, button)
    local rows = #map
    local columns = #map[1]
    if x > cellsize and x < cellsize + columns * cellsize then
        if y > cellsize and y < cellsize + rows * cellsize then
            local tx = math.floor(x / cellsize)
            local ty = math.floor(y / cellsize)

            if love.keyboard.isDown('s') and (map[ty][tx] == 0) then
                startx = tx
                starty = ty
            end
            if love.keyboard.isDown('e') and (map[ty][tx] == 0) then
                endx = tx
                endy = ty
            end

            path = myFinder:getPath(startx, starty, endx, endy)
        end
    end
end

function love.update()
    if not love.keyboard.isDown('s') and not love.keyboard.isDown('e') then
        if love.mouse.isDown(1) or love.mouse.isDown(2) then
            local rows = #map
            local columns = #map[1]
            local x, y = love.mouse:getPosition()
            if x > cellsize and x < cellsize + columns * cellsize then
                if y > cellsize and y < cellsize + rows * cellsize then
                    local tx = math.floor(x / cellsize)
                    local ty = math.floor(y / cellsize)
                    map[ty][tx] = love.mouse.isDown(1) and 1 or 0
                end
            end
        end
    end
end

function love.keypressed(key)
    if key == 'escape' then love.event.quit() end
end

function love.draw()
    local rows = #map
    local columns = #map[1]
    love.graphics.setColor(1, 1, 1)
    for y = 1, rows do
        for x = 1, columns do
            -- love.graphics.rectangle('line', x * cellsize, y * cellsize, cellsize, cellsize)
            if map[y][x] == 1 then
                love.graphics.rectangle('fill', x * cellsize, y * cellsize, cellsize, cellsize)
            end
        end
    end
    love.graphics.setColor(1, 0, 0)
    if path then
        --print(('Path found! Length: %.2f'):format(path:getLength()))
        for node, count in path:nodes() do
            love.graphics.rectangle('fill', node:getX() * cellsize + cellsize / 2 - pathnodesize / 2,
                node:getY() * cellsize + cellsize / 2 - pathnodesize / 2,
                pathnodesize, pathnodesize)
        end
    end
end

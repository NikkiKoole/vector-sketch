package.path = package.path .. ";../../?.lua"

json = require "vendor.json"
inspect = require 'vendor.inspect'

local Grid = require("jumper.grid")             -- The grid class
local Pathfinder = require("jumper.pathfinder") -- The pathfinder class

function love.load()
    success = love.window.setMode(1024, 1024, { highdpi = true })
    screen = {
        scale = 1, dx = 0, dy = 0
    }
    cellsize = 8
    pathnodesize = 3
    quads, frameNames = loadTiles()

    world_width = 40
    world_height = 40
    walkgrid = {}
    for y = 1, world_height + 1 do
        walkgrid[y] = {}
        for x = 1, world_width + 1 do
            walkgrid[y][x] = 0
        end
    end
    buildWorld(walkgrid)

    walkable = 0
    grid = Grid(walkgrid)
    myFinder = Pathfinder(grid, 'JPS', walkable)

    max_speed = 100
    guy_count = 5
    guys = {}

    for i = 1, guy_count do
        local startx, starty = pickNewGoal()
        local goalx, goaly = pickNewGoal()
        local guy = {
            r = love.math.random(),
            g = love.math.random(),
            b = love.math.random(),
            goaltileX = goalx,
            goaltileY = goaly
        }
        guy.x = cellsize / 2 + startx * cellsize
        guy.y = cellsize / 2 + starty * cellsize
        guyGetPath(guy)
        guys[i] = guy
    end
end

function love.mousepressed(x, y, button)
    if false then
        local tx, ty = getTileUnderMousePos(x, y)
        if tx >= 0 and ty >= 0 then
            if love.keyboard.isDown('s') and (walkgrid[ty][tx] == 0) then
                startx = tx
                starty = ty
            end
            if love.keyboard.isDown('e') and (walkgrid[ty][tx] == 0) then
                endx = tx
                endy = ty
            end

            path = myFinder:getPath(startx, starty, endx, endy)
        end
    end
end

function love.update(dt)
    local waitWithAdvancing = false

    if love.mouse.isDown(1) or love.mouse.isDown(2) then
        local x, y = love.mouse:getPosition()
        local tx, ty = getTileUnderMousePos(x, y)
        if tx >= 0 and ty >= 0 then
            walkgrid[ty][tx] = love.mouse.isDown(1) and 1 or 0
            waitWithAdvancing = true
            for i = 1, #guys do
                guyGetPath(guys[i])
            end
        end
    end


    if not waitWithAdvancing then
        for i = 1, #guys do
            local it = guys[i]
            local arrived = true
            local eps = 1


            -- Calculate the difference between target and current position
            --
            --


            local nextX = nil
            local nextY = nil
            if it.path then
                --print(('Path found! Length: %.2f'):format(it.path:getLength()))
                for node, count in it.path:nodes() do
                    --  print(inspect(node), count)
                    --  print(('Step: %d - x: %d - y: %d'):format(count, node.x, node.y))
                    if count == it.nextNode then
                        nextX = cellsize / 2 + node.x * cellsize
                        nextY = cellsize / 2 + node.y * cellsize
                    end
                    it.nodesCount = count
                end
            else
                --print('why no path')
                nextX = it.x
                nextY = it.y
                it.nodesCount = 0

                --  guyGetPath(it)
            end


            local dx = nextX - it.x
            local dy = nextY - it.y

            -- Update position based on direction and speed
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance > eps then
                local vx = (dx / distance) * max_speed
                local vy = (dy / distance) * max_speed

                it.x = it.x + vx * dt
                it.y = it.y + vy * dt
                it.rad = math.atan2(vy, vx) - math.pi / 2
                arrived = false
            end


            if arrived then
                it.currentNode = it.nextNode
                it.nextNode = it.nextNode + 1

                if it.nextNode ~= nil and it.nodesCount ~= nil then
                    if it.nextNode > it.nodesCount then
                        local gx, gy = pickNewGoal(it)
                        guys[i].goaltileX = gx
                        guys[i].goaltileY = gy

                        guys[i].rad = math.atan2(guys[i].y - (guys[i].goaltileY * cellsize),
                            guys[i].x - (guys[i].goaltileX * cellsize)) - math.pi / 2
                        guyGetPath(guys[i])
                    end
                end
            end
        end
    end
end

function love.keypressed(key)
    if key == 'escape' then love.event.quit() end
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(screen.dx, screen.dy)
    love.graphics.scale(screen.scale, screen.scale)

    local rows = #walkgrid
    local columns = #walkgrid[1]
    love.graphics.setColor(1, 1, 1)

    for y = 1, rows do
        for x = 1, columns do
            -- love.graphics.rectangle('line', x * cellsize, y * cellsize, cellsize, cellsize)
            if walkgrid[y][x] == 1 then
                love.graphics.rectangle('fill', x * cellsize, y * cellsize, cellsize, cellsize)
            end
        end
    end
    love.graphics.rectangle('line', cellsize, cellsize, cellsize * rows, cellsize * columns)
    love.graphics.setColor(1, 0, 0)
    if path then
        --print(('Path found! Length: %.2f'):format(path:getLength()))
        for node, count in path:nodes() do
            love.graphics.rectangle('fill', node.x * cellsize + cellsize / 2 - pathnodesize / 2,
                node.y * cellsize + cellsize / 2 - pathnodesize / 2,
                pathnodesize, pathnodesize)
        end
    end


    for i = 1, #guys do
        local it = guys[i]
        --love.graphics.setColor(1, 0, 0)
        love.graphics.setColor(it.r, it.g, it.b)
        love.graphics.draw(img, quads[frameNames.head2], it.x, it.y, it.rad, 1, 1, 4, 4)
        --love.graphics.draw(img, quads[frameNames['arrow-up-down']], it.x, it.y, it.rad, 1, 1, 4, 4)
        if it.path then
            for node, count in it.path:nodes() do
                love.graphics.rectangle('fill', node.x * 8, node.y * 8, 5, 5)
                -- print(inspect(node), count)
                -- print(('Step: %d - x: %d - y: %d'):format(count, node.x, node.y))
            end
        end
    end

    love.graphics.pop()
end

function love.mousemoved(x, y, dx, dy)
    if love.mouse.isDown(3) then
        screen.dx = screen.dx + dx
        screen.dy = screen.dy + dy
    end
end

function love.wheelmoved(dx, dy)
    local mx, my = love.mouse.getPosition()
    local mtx_before = (mx - screen.dx) / screen.scale
    local mty_before = (my - screen.dy) / screen.scale

    if dy > 0 then
        screen.scale = screen.scale * 2
    else
        screen.scale = screen.scale * 1 / 2
    end

    screen.dx = mx - mtx_before * screen.scale
    screen.dy = my - mty_before * screen.scale
end

function drawRoom(walkgrid, x, y, w, h)
    --world_width = 120
    --world_height = 120
    local minX = math.min(math.max(x, 1), world_width - 1)
    local maxX = math.min(x + w, world_width - 1)
    local minY = math.min(math.max(y, 1), world_height - 1)
    local maxY = math.min(y + h, world_height - 1)
    print(minX, minY, maxX, maxY)
    for xt = minX, maxX do
        walkgrid[minY][xt] = 1
        walkgrid[maxY][xt] = 1
    end
    -- print(math.floor(minX + (maxX - minX) / 2))
    walkgrid[minY][math.floor(minX + (maxX - minX) / 2)] = 0
    walkgrid[maxY][math.floor(minX + (maxX - minX) / 2)] = 0
    for yt = minY, maxY do
        walkgrid[yt][minX] = 1
        walkgrid[yt][maxX] = 1
    end
    walkgrid[math.floor(minY + (maxY - minY) / 2)][minX] = 0
    walkgrid[math.floor(minY + (maxY - minY) / 2)][maxX] = 0
end

function buildWorld(walkgrid)
    for i = 1, 3 do
        drawRoom(walkgrid,
            math.floor(math.random() * world_width + 1),
            math.floor(math.random() * world_height + 1), 10, 10)
    end

    for i = 1, 3 do
        bresenhamLine(
            math.floor(1 + math.random() * world_width / 2),
            math.floor(1 + math.random() * world_width / 2),
            math.floor(1 + math.random() * world_width),
            math.floor(1 + math.random() * world_width), 1)
    end
    for i = 1, 3 do
        bresenhamLine(
            math.floor(1 + math.random() * world_width / 2),
            math.floor(1 + math.random() * world_width / 2),
            math.floor(1 + math.random() * world_width),
            math.floor(1 + math.random() * world_width), 0)
    end
end

function bresenhamLine(x0, y0, x1, y1, value)
    local dx = math.abs(x1 - x0)
    local dy = math.abs(y1 - y0)
    local sx = x0 < x1 and 1 or -1
    local sy = y0 < y1 and 1 or -1
    local err = dx - dy

    while true do
        -- Plot the point (x0, y0)
        --print(y0, x0)
        walkgrid[y0][x0] = value

        -- Check if we've reached the endpoint
        if x0 == x1 and y0 == y1 then break end

        local e2 = 2 * err

        if e2 > -dy then
            err = err - dy
            x0 = x0 + sx
        end

        if e2 < dx then
            err = err + dx
            y0 = y0 + sy
        end
    end
end

function loadTiles()
    img = love.graphics.newImage("tiles.png")
    img:setFilter("nearest", "nearest")
    contents, size = json.decode(love.filesystem.read('tiles.json'))
    local framecount = 0
    for k, v in pairs(contents.frames) do
        framecount = framecount + 1
    end

    local quads = {}
    local frameNames = {}

    for i = 0, framecount - 1 do
        local f = contents.frames['tiles ' .. i .. '.aseprite'].frame
        quads[i] = love.graphics.newQuad(f.x, f.y, f.w, f.h, img)
        frameNames[contents.meta.frameTags[i + 1].name] = i
    end
    return quads, frameNames
end

function guyGetPath(guy)
    local currentTileX = math.floor((guy.x) / cellsize)
    local currentTileY = math.floor((guy.y) / cellsize)

    if currentTileX <= world_width and currentTileY <= world_height then
        if currentTileX >= 1 and currentTileY >= 1 then
            guy.path = myFinder:getPath(currentTileX, currentTileY, guy.goaltileX, guy.goaltileY)
        end
    else
        print('current tilex or y was out of bounds', currentTileX < world_width, currentTileY < world_height)
        print(currentTileY, world_height)
    end
    guy.currentNode = 0
    guy.nextNode = 1
end

function math.clamp(low, n, high) return math.min(math.max(n, low), high) end

function pickNewGoal(guy)
    local foundGoodGoal = false
    local x = nil
    local y = nil
    repeat
        x = 1 + math.floor(love.math.random() * (world_width - .5))
        y = 1 + math.floor(love.math.random() * (world_height - .5))
        if walkgrid[y][x] == walkable then
            foundGoodGoal = true
        end
    until foundGoodGoal == true
    return x, y
end

function getTileUnderMousePos(x, y)
    local rows = #walkgrid
    local columns = #walkgrid[1]
    local px = (x - screen.dx) / screen.scale
    local py = (y - screen.dy) / screen.scale
    if px > cellsize and px < cellsize + columns * cellsize then
        if py > cellsize and py < cellsize + rows * cellsize then
            local tx = math.floor(px / cellsize)
            local ty = math.floor(py / cellsize)
            return tx, ty
        end
    end
    return -1, -1
end

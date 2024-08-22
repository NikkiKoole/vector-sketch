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
    quads, frameNames = loadTiles()
    guy_count = 10
    guys = {}

    world_width = 20
    world_height = 20



    walkgrid = {}
    for x = 1, world_width + 1 do
        walkgrid[x] = {}
        for y = 1, world_height + 1 do
            walkgrid[x][y] = 0
        end
    end

    max_speed = 100
    walkable = 0
    grid = Grid(walkgrid)
    -- Creates a pathfinder object using Jump Point Search
    myFinder = Pathfinder(grid, 'ASTAR', walkable)


    for i = 1, guy_count do
        local guy = {
            x = love.math.random() * (world_width * 8),
            y = love.math.random() * (world_height * 8),

            vx = 0,
            vy = 0,
            r = love.math.random(),
            g = love.math.random(),
            b = love.math.random(),
        }
        local gx, gy = pickNewGoal(guy)
        guy.goalX = gx
        guy.goalY = gy
        -- print(guy.x / 8, guy.y / 8, guy.tx / 8, guy.ty / 8)
        guyGetPath(guy)
        guy.rad = math.atan2(guy.goalY - guy.y, guy.goalX - guy.x) - math.pi / 2
        guys[i] = guy
    end
    -- print(inspect(walkgrid))
end

function pickNewGoal(guy)
    local foundGoodGoal = false

    local x = nil
    local y = nil
    repeat
        x = 1 + math.floor(love.math.random() * (world_width))
        y = 1 + math.floor(love.math.random() * (world_height))
        if walkgrid[x][y] == 0 then
            foundGoodGoal = true
        end
    until foundGoodGoal == true
    return x * 8, y * 8
end

function love.update(dt)
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
                    nextX = node.x * 8
                    nextY = node.y * 8
                end
                it.nodesCount = count
            end
        else
            print('why no path')
            nextX = it.x
            nextY = it.y
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
            if it.nextNode > it.nodesCount then
                local gx, gy = pickNewGoal(it)
                guys[i].goalX = gx
                guys[i].goalY = gy

                guys[i].rad = math.atan2(guys[i].y - guys[i].goalY, guys[i].x - guys[i].goalX) - math.pi / 2
                guyGetPath(guys[i])
            end
        end
    end

    if love.mouse.isDown(1) or love.mouse.isDown(2) then
        local mx, my = love.mouse.getPosition()
        local px = (mx - screen.dx) / screen.scale
        local py = (my - screen.dy) / screen.scale
        if px >= 0 and px <= world_width * 8 then
            if py >= 0 and py <= world_height * 8 then
                walkgrid[math.floor(px / 8)][math.floor(py / 8)] = love.mouse.isDown(1) and 1 or 0
                walkable = 0
                grid = Grid(walkgrid)
                -- Creates a pathfinder object using Jump Point Search
                myFinder = Pathfinder(grid, 'ASTAR', walkable)

                for i = 1, #guys do
                    guyGetPath(guys[i])
                end
            end
        end
    end
end

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(screen.dx, screen.dy)
    love.graphics.scale(screen.scale, screen.scale)
    for i = 1, #guys do
        local it = guys[i]
        love.graphics.setColor(it.r, it.g, it.b)
        love.graphics.draw(img, quads[frameNames.head2], it.x, it.y, it.rad, 1, 1, 4, 4)
        love.graphics.draw(img, quads[frameNames['arrow-up-down']], it.x, it.y, it.rad, 1, 1, 4, 4)
        if it.path then
            for node, count in it.path:nodes() do
                love.graphics.rectangle('fill', node.x * 8, node.y * 8, 5, 5)
                -- print(inspect(node), count)
                -- print(('Step: %d - x: %d - y: %d'):format(count, node.x, node.y))
            end
        end
    end
    love.graphics.setColor(1, 1, 1)
    for x = 1, world_width do
        for y = 1, world_height do
            if walkgrid[x][y] == 1 then
                love.graphics.draw(img, quads[frameNames.dither2], x * 8, y * 8, 0, 1, 1, 4, 4)
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

function guyGetPath(guy)
    --print(walkgrid[1][1])
    print(guy.x / 8, guy.y / 8)

    guy.path = myFinder:getPath(
        math.floor(.5 + guy.x / 8),
        math.floor(.5 + guy.y / 8),
        math.floor(guy.goalX / 8),
        math.floor(guy.goalY / 8))

    if guy.path == nil then
        print('hello')
        print(guy.x / 8, guy.y / 8, guy.goalX / 8, guy.goalY / 8)
        print(walkgrid[math.floor(guy.x / 8)][math.floor(guy.y / 8)])
        print(walkgrid[math.floor(guy.goalX / 8)][math.floor(guy.goalY / 8)])
    end

    guy.currentNode = 0
    guy.nextNode = 1
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

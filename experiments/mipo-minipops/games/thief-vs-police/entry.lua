local scene = {}

function makeBetterMap(old, wm, hm)
    local oldH = #old
    local oldW = #old[1]
    local newW = math.ceil(oldW / wm) * wm
    local newH = math.ceil(oldH / hm) * hm

    -- Initialize the new map filled with the default value
    local result = {}
    for y = 1, newH do
        result[y] = {}
        for x = 1, newW do
            result[y][x] = {tile=1}
        end
    end

     --Calculate the offset to center the old map in the new map
    local xOff = math.floor((newW - oldW) / 2)
    local yOff = math.floor((newH - oldH) / 2)

    -- Copy the old map into the new map, centered
    for y = 1, oldH do
        for x = 1, oldW do
            result[y + yOff][x + xOff] = old[y][x] and {tile=1} or {tile=0}
        end
    end

    return result
end

function scaleMap(map, factor)
    local newMap = {}

    for y = 1, #map do
        for fy = 1, factor do
            local newRow = {}
            for x = 1, #map[y] do
                for fx = 1, factor do
                    table.insert(newRow, map[y][x])
                end
            end
            table.insert(newMap, newRow)
        end
    end

    return newMap
end

function carve(map, x,y)
    map[y][x] = {tile=0}
end

function makeExit(map)
    -- Get the map dimensions
    local width = #map[1]
    local height = #map

    -- Randomly pick one of the sides (1 = top, 2 = left, 3 = bottom, 4 = right)
    local side = love.math.random(1, 4)

    -- Set the starting point in the middle of the chosen side
    local x, y
    if side == 1 then -- Top side
        x = math.floor(width / 2)
        y = 1
    elseif side == 2 then -- Left side
        x = 1
        y = math.floor(height / 2)
    elseif side == 3 then -- Bottom side
        x = math.floor(width / 2)
        y = height
    elseif side == 4 then -- Right side
        x = width
        y = math.floor(height / 2)
    end

    -- Tunnel through the wall until it reaches an open path
    while map[y][x].tile == 1 do
        carve(map, x, y)

        -- Continue tunneling based on the side
        if side == 1 then
            y = y + 1 -- Move down from top
        elseif side == 2 then
            x = x + 1 -- Move right from left
        elseif side == 3 then
            y = y - 1 -- Move up from bottom
        elseif side == 4 then
            x = x - 1 -- Move left from right
        end
    end

    -- Mark the exit on the border
    if side == 1 then
        map[1][x].exit1 = true -- Top side
         map[2][x].exit2 = true -- Top side
          map[3][x].exit3 = true -- Top side
    elseif side == 2 then
        map[y][1].exit1 = true -- Left side
        map[y][2].exit2 = true -- Left side
        map[y][3].exit3 = true -- Left side
    elseif side == 3 then
        map[height][x].exit1 = true -- Bottom side
         map[height-1][x].exit2 = true -- Bottom side
          map[height-2][x].exit3 = true -- Bottom side
    elseif side == 4 then

        map[y][width].exit1 = true -- Right side
         map[y][width-1].exit2 = true -- Right side
          map[y][width-2].exit3 = true -- Right side
    end

    return map
end

function getRandomEmptyPositionWithinRange(map, x, y, range)
    while true do
        local xindex = math.floor(x + math.random() * range - range/2)
        local yindex = math.floor(y + math.random() * range - range/2)
        --print( yindex, xindex, w,h,map[yindex][xindex])
        if map[yindex] and map[yindex][xindex].tile == 0 then
            return xindex, yindex
        end
    end
end

function getRandomEmptyPositionWithinRect(map, x, y, w, h)
    while true do
        local xindex = math.floor(x + math.random() * w)
        local yindex = math.floor(y + math.random() * h)
        --print( yindex, xindex, w,h,map[yindex][xindex])
        if map[yindex] and map[yindex][xindex].tile == 0 then
            return xindex, yindex
        end
    end
end

function calculateCamPosFromDiefPos(diefX, diefY)
    local camX = math.floor((diefX - 1) / screenData.columns) * screenData.columns + 1
    local camY = math.floor((diefY - 1) / screenData.rows) * screenData.rows + 1
    return camX, camY
end

function scene:load(args)
    print('hello')
    verloren = false
    gewonnen = false
    success = love.window.setMode(1400, 1000)
    love.keyboard.setKeyRepeat(true)
    --print("Scenery 2 is awesome")
    gras = love.graphics.newImage('games/thief-vs-police/img/gras.png')
    muur = love.graphics.newImage('games/thief-vs-police/img/muur.png')
    muurquad = love.graphics.newQuad(0, 0, muur:getWidth(), muur:getHeight(), muur:getWidth(), muur:getHeight())
    dief = love.graphics.newImage('games/thief-vs-police/img/thief2.png')
     geldzak = love.graphics.newImage('games/thief-vs-police/img/geldzak.png')
     diefsad = love.graphics.newImage('games/thief-vs-police/img/thief-sad.png')
     diefhappy = love.graphics.newImage('games/thief-vs-police/img/thief-happy.png')
    kooi = love.graphics.newImage('games/thief-vs-police/img/kooi.png')

      mist = love.graphics.newImage('games/thief-vs-police/img/mist.png')

    politie = love.graphics.newImage('games/thief-vs-police/img/politie2.png')

    stapsnd =  love.audio.newSource("games/thief-vs-police/sfx/stap.wav", "static")
     huilsnd =  love.audio.newSource("games/thief-vs-police/sfx/huil.wav", "static")
     winsnd =  love.audio.newSource("games/thief-vs-police/sfx/win.wav", "static")
     verlorensnd = love.audio.newSource("games/thief-vs-police/sfx/verloren.wav", "static")
     music =  love.audio.newSource("games/thief-vs-police/sfx/muziekje.mp3", "static")
     music:setLooping(true)
     music:play()

     camPos = { x = 1, y = 1 }
     screenData = {
        columns = 10,
        rows = 10
    }

    levels = {
        test = {police=4, loops=1, size=5,scale=1 },
        noob = {police=2, loops=1, size=5,scale=3 },
        easy = {police=4, loops=.8,size=6,scale=3 },
        medium = {police=6, loops=.5,size=12,scale=2 },
        hard = {police=8, loops=0.2,size=12,scale=1},
        expert = {police=10, loops=0.2,size=12,scale=1},
        impossible = {police=44, loops=0.12,size=12,scale=1}
    }
    level =  levels.hard
    local RZSMaze = require("games/thief-vs-police/RZSMaze")
    local myMaze = RZSMaze.new({ level.size, level.size }, love.math.random) -- Create a blank 6x6 maze
    myMaze:generate()                      -- Generate it
    myMaze:createLoops(level.loops)                 -- Create some loops
    local newMap = myMaze:toSimpleRepresentation()
    map = makeBetterMap(newMap, screenData.columns, screenData.rows, {tile=1})
    map = scaleMap(map, level.scale)
    map = makeExit(map)

    entities = {}
    local x, y = getRandomEmptyPositionWithinRange(map, #map[1]/2 , #map/2, 5)
    table.insert(entities, { x = x, y = y, type = "dief" })

    diefEnt = entities[1]
    for i = 1, level.police do
        local x, y = getRandomEmptyPositionWithinRect(map, 1, 1,  #map[1] , #map )
        table.insert(entities, { x = x, y = y, type = "politie" })
    end

    local x, y = calculateCamPosFromDiefPos(diefEnt.x, diefEnt.y)
    camPos.x = x
    camPos.y = y
end

local function drawInto(img, x, y, w, h)
    local myWidth, myHeight = img:getDimensions()
    local myScaleX = w / myWidth
    local myScaleY = h / myHeight
    love.graphics.draw(img, x, y, 0, myScaleX, myScaleY, myWidth/2, myHeight/2)
end

local function drawIntoW(img, x, y, w)
    local myWidth, myHeight = img:getDimensions()
    local myScaleX = w / myWidth
    local myScaleY = myScaleX
    love.graphics.draw(img, x, y, 0, myScaleX, myScaleY, myWidth / 2, myHeight)
end

function scene:keypressed(k)
    if k == 'escape' then
        self.setScene("overworld", { score = 52 })
        return
    end

    local directions = {
        left = { x = -1, y = 0 },
        right = { x = 1, y = 0 },
        up = { x = 0, y = -1 },
        down = { x = 0, y = 1 }
    }

    local dir = directions[k]
    local diefPos = diefEnt

    if dir then
        local newX = diefPos.x + dir.x
        local newY = diefPos.y + dir.y

        if newX >= 1 and newX <= #map[1] and newY >= 1 and newY <= #map then
            if map[newY][newX].tile == 0 then
                if (isFreeFromPolice(newX, newY, diefEnt)) then
                    maybeMoveCamera(diefPos.x, diefPos.y, newX, newY)
                    diefEnt.x = newX
                    diefEnt.y = newY
                    diefEnt.lastDir = dir
                    playSound(stapsnd)
                    updatePolities()
                end
            end
        end
    end
end

function isFreeFromPolice(x, y, popo)
    for i = 1, #entities do
        local it = entities[i]
        if it ~= pop then
            if it.x == x and it.y == y then return false end
        end
    end
    return true
end

function updatePolities()
    local target = { x = diefEnt.x, y = diefEnt.y }

    for i = 1, #entities do
        if (i % 2 == 0) then
            target = { x = diefEnt.x + diefEnt.lastDir.x, y = diefEnt.y + diefEnt.lastDir.y }
        end
        local it = entities[i]

        -- Skip the dief entity
        if it == diefEnt then
            goto continue
        end

        -- Add variation by randomly adjusting the target around dief
        if math.random() < 0.05 then
            target.x = target.x + (math.random() < 0.5 and 1 or -1)
            target.y = target.y + (math.random() < 0.5 and 1 or -1)
        end

        -- Calculate the next position based on the target's direction
        local nextX, nextY = it.x, it.y

        -- Determine movement in x-axis
        local xDir = 0
        local yDir = 0
        if target.x < it.x then
            xDir = -1
        elseif target.x > it.x then
            xDir = 1
        end

        -- Determine movement in y-axis
        if target.y < it.y then
            yDir = -1
        elseif target.y > it.y then
            yDir = 1
        end

        if xDir ~= 0 and yDir ~= 0 then -- prohibit diagonally moving, just pick one axis at random
            if math.random() < 0.5 then
                xDir = 0
            else
                yDir = 0
            end
        end
        nextX = it.x + xDir
        nextY = it.y + yDir

        -- Only move if the new position is valid (within map, free from police, and walkable)
        if map[nextY] and map[nextY][nextX].tile == 0 and isFreeFromPolice(nextX, nextY, it) then
            it.x = nextX
            it.y = nextY
        end

        ::continue::
    end
end

function maybeMoveCamera(oldX, oldY, newX, newY)
    if (oldX % screenData.columns == 0) then
        if newX > oldX then
            camPos.x = camPos.x + screenData.columns
        end
    end
    if (newX % screenData.columns == 0) then
        if newX < oldX then
            camPos.x = camPos.x - screenData.columns
        end
    end

    if (oldY % screenData.rows == 0) then
        if newY > oldY then
            camPos.y = camPos.y + screenData.rows
        end
    end
    if (newY % screenData.rows == 0) then
        if newY < oldY then
            camPos.y = camPos.y - screenData.rows
        end
    end
end

function checkGame()

    function cannotGoHere(x,y)
        if not map[y] then return true end
        if not map[y][x] then return true end
        if map[y][x].tile == 1 then return true end
        for i =1, #entities do
            local it = entities[i]
            if it.type == 'politie' then
                if it.x == x and it.y == y then return true end
            end
        end
        return false
    end

    local x = diefEnt.x
    local y = diefEnt.y
    if map[y][ x].exit1 then
        win()
    end

    if cannotGoHere(x-1,y) and cannotGoHere(x+1,y) and cannotGoHere(x,y-1) and cannotGoHere(x,y+1) then
        isverloren()
    end

end

function playSound(source)
    source:clone():play()
end

function resetGame()
    verloren = false
    gewonnen = false
    scene.setScene("overworld", { score = 52 })
    scene.setScene('thief-vs-police')
end

function win()
    if gewonnen == false then
        playSound(winsnd)
    end
    gewonnen = true
end

function isverloren()
    if verloren == false then
       playSound(huilsnd)
       playSound(verlorensnd)
       music:stop()
     --  resetGame()
      end
    verloren = true

end

function scene:draw()
    love.graphics.clear(.1, .1, .1)

    local w, h = love.graphics.getDimensions()
    local columns = screenData.columns
    local rows = screenData.rows
    local size = math.min(math.floor(w / columns), math.floor(h / rows)) * 0.9

    local offsetX = (w - (size * columns)) / 2
    local offsetY = (h - (size * rows)) / 2  + size/2

    -- Loop through all rows and columns
     if true then

    for row = 0, rows + 1 do
        for col = 0, columns + 1 do
            local mapX = math.floor(camPos.x) + col - 1
            local mapY = math.floor(camPos.y) + row - 1

            local t = 1 -- Default to non-walkable (walls)
            local isBorder = (row == 0 or col == 0 or row == rows + 1 or col == columns + 1)
            local exit1 = false
            local exit2 = false
            local exit3 = false
            -- Determine if it's inside the map and set walkable or non-walkable
            if mapY >= 1 and mapY <= #map and mapX >= 1 and mapX <= #map[1] then
                t = map[mapY][mapX].tile
                exit1 = map[mapY][mapX].exit1
               exit2 = map[mapY][mapX].exit2
              exit3= map[mapY][mapX].exit3
            end

            -- Draw border or regular tiles
            if isBorder then
                if t == 0 then
                    love.graphics.setColor(0.1, 0.45, 0.11, 0.5) -- Walkable (border)
                    drawInto(gras, offsetX + (col - 1) * size, offsetY + (row - 1) * size, size, size)
                else
                    love.graphics.setColor(0.62, 0.22, 0, 0.5) -- Non-walkable (border)
                    drawInto(muur, offsetX + (col - 1) * size, offsetY + (row - 1) * size, size, size)
                end
                --  love.graphics.rectangle('fill', offsetX + (col - 1) * size, offsetY + (row - 1) * size, size, size)
            else
                if t == 0 then
                    love.graphics.setColor(1, 1, 1) -- Walkable (inside the map)
                    drawInto(gras, offsetX + (col - 1) * size, offsetY + (row - 1) * size, size, size)
                else
                    love.graphics.setColor(1, 1, 1) -- Non-walkable (inside the map)
                    drawInto(muur, offsetX + (col - 1) * size, offsetY + (row - 1) * size, size, size)
                end
            end

            if (exit1 or exit2 or exit3) then

                if exit1 then

                    love.graphics.setColor(1,1,1,.8)
                end
                if exit2 then

                    love.graphics.setColor(1,1,1,.6)
                end
                if exit3 then

                    love.graphics.setColor(1,1,1,.4)
                end

                drawInto(mist, offsetX + (col - 1) * size, offsetY + (row - 1) * size, size, size) else

            end

            -- Reset color
            love.graphics.setColor(1, 1, 1)
        end
    end
     end

    -- Draw the player (dief) at its relative position
    --local diefScreenX = (diefPos.x - math.floor(camPos.x)) * size + offsetX + size / 2
    --local diefScreenY = (diefPos.y - math.floor(camPos.y)) * size + offsetY + size / 2
    --drawIntoW(dief, diefScreenX, diefScreenY, size)

    table.sort(entities, function(a, b)
        if (a.y == b.y) then
            return #(a.type) > #(b.type)
        end
        return a.y < b.y
    end)
    for i = 1, #entities do
        local it = entities[i]
        local screenX = (it.x - math.floor(camPos.x)) * size + offsetX
        local screenY = (it.y - math.floor(camPos.y)) * size + offsetY

        if it.x == camPos.x - 1 or it.x == camPos.x + columns or
            it.y == camPos.y - 1 or it.y == camPos.y + rows then
            if it.type == "dief" then
                --    drawIntoW(dief, screenX, screenY, size)
            elseif it.type == "politie" then
                love.graphics.setColor(.5, .5, .5, 1)
                drawIntoW(politie, screenX, screenY, size)
            end
        end


        love.graphics.setColor(1, 1, 1)
        if it.x >= camPos.x and it.x < camPos.x + columns then
            if it.y >= camPos.y and it.y < camPos.y + rows then
                if it.type == "dief" then
                    if (verloren) then
                    drawIntoW(diefsad, screenX, screenY, size)
                    drawIntoW(kooi, screenX, screenY, size)
                    elseif (gewonnen) then
                     drawIntoW(diefhappy, screenX, screenY, size)
                    else

                     drawIntoW(dief, screenX, screenY, size)

                     --drawInto(geldzak, screenX-50, screenY-60, size/1.5,size/1.5)
                     --drawInto(geldzak, screenX+50, screenY-80, size/1.5,size/1.5)
                    end
                elseif it.type == "politie" then
                    drawIntoW(politie, screenX, screenY, size)
                end
            end
        end
    end
    checkGame()
    -- Print player coordinates
    -- love.graphics.print(diefPos.x .. ',' .. diefPos.y, diefScreenX - size / 2, diefScreenY - size / 2)
end

function scene:update(dt)
    -- print("You agree, don't you?")
end

return scene

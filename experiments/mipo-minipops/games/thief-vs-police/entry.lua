local scene = {}


function makeBetterMap(old, wm, hm, default)
    local oldH = #old
    local oldW = #old[1]
    local newW = math.ceil(oldW / wm) * wm
    local newH = math.ceil(oldH / hm) * hm

    -- Initialize the new map filled with the default value
    local result = {}
    for y = 1, newH do
        result[y] = {}
        for x = 1, newW do
            result[y][x] = default
        end
    end

    -- Calculate the offset to center the old map in the new map
    local xOff = math.floor((newW - oldW) / 2)
    local yOff = math.floor((newH - oldH) / 2)

    -- Copy the old map into the new map, centered
    for y = 1, oldH do
        for x = 1, oldW do
            result[y + yOff][x + xOff] = old[y][x] and 1 or 0
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

function getRandomEmptyPositionWithinRect(map, x, y, w, h)
    while true do
        local xindex = math.floor(x + math.random() * w)
        local yindex = math.floor(y + math.random() * h)

        if map[yindex] and map[yindex][xindex] == 0 then
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
    success = love.window.setMode(1400, 1000)
    love.keyboard.setKeyRepeat(true)
    --print("Scenery 2 is awesome")
    gras = love.graphics.newImage('games/thief-vs-police/img/gras.png')


    muur = love.graphics.newImage('games/thief-vs-police/img/muur.png')
    muurquad = love.graphics.newQuad(0, 0, muur:getWidth(), muur:getHeight(), muur:getWidth(), muur:getHeight())
    dief = love.graphics.newImage('games/thief-vs-police/img/thief2.png')
    politie = love.graphics.newImage('games/thief-vs-police/img/politie2.png')

    camPos = { x = 1, y = 1 }
    screenData = {
        columns = 10,
        rows = 10
    }

    local RZSMaze = require("games/thief-vs-police/RZSMaze")
    local myMaze = RZSMaze.new({ 15, 15 }) -- Create a blank 6x6 maze
    myMaze:generate()                      -- Generate it
    myMaze:createLoops(30)                 -- Create some loops
    local newMap = myMaze:toSimpleRepresentation()
    map = makeBetterMap(newMap, screenData.columns, screenData.rows, 1)
    map = scaleMap(map, 2)

    entities = {}
    local x, y = getRandomEmptyPositionWithinRect(map, 1, 1, screenData.columns * 10, screenData.rows * 10)
    table.insert(entities, { x = x, y = y, type = "dief" })

    diefEnt = entities[1]
    for i = 1, 50 do
        local x, y = getRandomEmptyPositionWithinRect(map, 1, 1, screenData.columns * 10, screenData.rows * 10)
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
    love.graphics.draw(img, x, y, 0, myScaleX, myScaleY)
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
            if map[newY][newX] == 0 then
                if (isFreeFromPolice(newX, newY, diefEnt)) then
                    maybeMoveCamera(diefPos.x, diefPos.y, newX, newY)
                    diefEnt.x = newX
                    diefEnt.y = newY
                    diefEnt.lastDir = dir
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
        if map[nextY] and map[nextY][nextX] == 0 and isFreeFromPolice(nextX, nextY, it) then
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

function scene:draw()
    love.graphics.clear(.1, .1, .1)

    local w, h = love.graphics.getDimensions()
    local columns = screenData.columns
    local rows = screenData.rows
    local size = math.min(math.floor(w / columns), math.floor(h / rows)) * 0.9

    local offsetX = (w - (size * columns)) / 2
    local offsetY = (h - (size * rows)) / 2

    -- Loop through all rows and columns
    for row = 0, rows + 1 do
        for col = 0, columns + 1 do
            local mapX = math.floor(camPos.x) + col - 1
            local mapY = math.floor(camPos.y) + row - 1

            local t = 1 -- Default to non-walkable (walls)
            local isBorder = (row == 0 or col == 0 or row == rows + 1 or col == columns + 1)

            -- Determine if it's inside the map and set walkable or non-walkable
            if mapY >= 1 and mapY <= #map and mapX >= 1 and mapX <= #map[1] then
                t = map[mapY][mapX]
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

            -- Reset color
            love.graphics.setColor(1, 1, 1)
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
        local screenX = (it.x - math.floor(camPos.x)) * size + offsetX + size / 2
        local screenY = (it.y - math.floor(camPos.y)) * size + offsetY + size / 2



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
                    drawIntoW(dief, screenX, screenY, size)
                elseif it.type == "politie" then
                    drawIntoW(politie, screenX, screenY, size)
                end
            end
        end
    end
    -- Print player coordinates
    -- love.graphics.print(diefPos.x .. ',' .. diefPos.y, diefScreenX - size / 2, diefScreenY - size / 2)
end

function scene:update(dt)
    -- print("You agree, don't you?")
end

return scene

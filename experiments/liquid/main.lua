local gridWidth = 16
local gridHeight = 40
local cellSize = 12

local blocktype = {
    air = 1,
    solid = 2,
    water = 3
}

local blockcolors = {
    { 1,         1,         1 },
    { 137 / 255, 95 / 255,  43 / 255 },
    { 43 / 255,  118 / 255, 137 / 255 },
}

local function pickRandom(array)
    local index = math.ceil(love.math.random() * #array)
    return array[index]
end

function love.load()
    maxMass = 1.0
    maxCompress = 0.02
    maxCompress = 0.000002
    minMass = 0.0001
    maxSpeed = 1.0
    minFlow = 0.01


    autoWater = false
    loopWater = true

    map = {}
    for x = 0, gridWidth + 1 do
        map[x] = {}
        for y = 0, gridHeight + 1 do
            local b = pickRandom({ blocktype.air, blocktype.solid, blocktype.water })
            local mass = (b == blocktype.water and maxMass or 0)
            map[x][y] = { mass = mass, new_mass = mass, type = b }
        end
    end
end

function getStableState(total_mass)
    if (total_mass <= 1) then
        return 1
    elseif (total_mass < 2 * maxMass + maxCompress) then
        return (maxMass * maxMass + total_mass * maxCompress) / (maxMass + maxCompress)
    else
        return (total_mass + maxCompress) / 2
    end
end

function constrain(data, min, max)
    local result = data
    if data < min then result = min end
    if data > max then result = max end
    return result
end

function simulateCompression()
    local flow = 0
    local remainingMass = 0


    for x = 1, gridWidth do
        for y = 1, gridHeight + (loopWater and 1 or 0) do
            local skip = false
            if map[x][y].type == blocktype.solid then skip = true end

            if skip then goto done end

            flow = 0
            remainingMass = map[x][y].mass

            if remainingMass <= 0 then goto done end

            -- block below
            local yBelow = y + 1

            if (loopWater and y + 1 > gridHeight) then
                yBelow = 1 -- make the water go round
            end

            if map[x][yBelow] ~= blocktype.air then
                flow = getStableState(remainingMass + map[x][yBelow].mass) - map[x][yBelow].mass
                if flow > minFlow then
                    flow = flow * 0.5
                end
                flow = constrain(flow, 0, math.min(maxSpeed, remainingMass))

                map[x][y].new_mass = map[x][y].new_mass - flow
                map[x][yBelow].new_mass = map[x][yBelow].new_mass + flow
                remainingMass = remainingMass - flow
            end

            if remainingMass <= 0 then goto done end

            -- left
            if (map[x - 1][y].blocktype ~= blocktype.solid) then
                flow = (map[x][y].mass - map[x - 1][y].mass) / 4
                if (flow > minFlow) then
                    flow = flow * 0.5
                end
                flow = constrain(flow, 0, remainingMass)

                map[x][y].new_mass = map[x][y].new_mass - flow
                map[x - 1][y].new_mass = map[x - 1][y].new_mass + flow
                remainingMass = remainingMass - flow
            end
            if remainingMass <= 0 then goto done end

            -- right
            if (map[x + 1][y].blocktype ~= blocktype.solid) then
                flow = (map[x][y].mass - map[x + 1][y].mass) / 4
                if (flow > minFlow) then
                    flow = flow * 0.5
                end
                flow = constrain(flow, 0, remainingMass)

                map[x][y].new_mass = map[x][y].new_mass - flow
                map[x + 1][y].new_mass = map[x + 1][y].new_mass + flow
                remainingMass = remainingMass - flow
            end
            if remainingMass <= 0 then goto done end

            -- up
            if (map[x][y - 1].blocktype ~= blocktype.solid) then
                flow = remainingMass - getStableState(remainingMass + map[x][y - 1].mass);
                if (flow > minFlow) then
                    flow = flow * 0.5
                end
                flow = constrain(flow, 0, math.min(maxSpeed, remainingMass))

                map[x][y].new_mass = map[x][y].new_mass - flow
                map[x][y - 1].new_mass = map[x][y - 1].new_mass + flow
                remainingMass = remainingMass - flow
            end

            ::done::
        end
    end

    -- copy newmass
    for x = 1, gridWidth do
        for y = 1, gridHeight do
            map[x][y].mass = map[x][y].new_mass
        end
    end

    for x = 1, gridWidth do
        for y = 1, gridHeight do
            if map[x][y].type ~= blocktype.solid then
                if map[x][y].mass > minMass then
                    map[x][y].type = blocktype.water
                else
                    map[x][y].type = blocktype.air
                end
            end
        end
    end


    if autoWater then
        for x = 1, gridWidth do
            local y = 1
            if map[x][y].type ~= blocktype.solid then
                map[x][y].type = blocktype.water
                map[x][y].mass = maxMass
                map[x][y].new_mass = maxMass
            end
        end
    end
end

function love.update(dt)
    simulateCompression()
end

function love.draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle('fill', cellSize, cellSize, cellSize * gridWidth, cellSize * gridHeight)

    for y = 1, gridHeight do
        for x = 1, gridWidth do
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle('line', x * cellSize, y * cellSize, cellSize, cellSize)
            local color = blockcolors[map[x][y].type]
            local alpha = 1
            if map[x][y].type == blocktype.water then
                alpha = map[x][y].mass
            end
            love.graphics.setColor(color[1], color[2], color[3], alpha)
            love.graphics.rectangle('fill', x * cellSize, y * cellSize, cellSize, cellSize)
        end
    end

    love.graphics.setColor(1, 0, 1)
    love.graphics.print('click with mouse to draw, press (w)ater, (s)olid, (l)oopWater, (a)utoWater', -1, -1)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print('click with mouse to draw, press (w)ater, (s)olid, (l)oopWater, (a)utoWater')
end

function love.mousepressed(x, y, button)
    local t = blocktype.air
    if love.keyboard.isDown('w') then
        t = blocktype.water
    end
    if love.keyboard.isDown('s') then
        t = blocktype.solid
    end
    local xi = math.ceil((x / cellSize) - 1)
    local yi = math.ceil((y / cellSize) - 1)
    if xi >= 1 and xi <= gridWidth then
        if yi >= 1 and yi <= gridHeight then
            map[xi][yi].type = t
            if (t == blocktype.water) then
                map[xi][yi].mass = maxMass * 10
                map[xi][yi].new_mass = maxMass * 10
            else
                map[xi][yi].mass = 0
                map[xi][yi].new_mass = 0
            end
        end
    end
end

function love.keypressed(k)
    if k == 'escape' then
        love.event.quit()
    end
    if k == 'l' then
        --autoWater = false
        loopWater = not loopWater
    end
    if k == 'a' then
        --autoWater = false
        autoWater = not autoWater
    end
    print(autoWater, loopWater)
end

-- liquid: cellular water (W-Shadow's "simple fluid simulation", water.pde next to this
-- file) drawn with interpolated marching squares, so the cells read as one smooth body
-- of water. Each cell holds a mass: water falls, spreads half the difference sideways,
-- and a slightly compressible column pushes water up the other side (a U-tube).
-- See playtime/docs/WATER.md for where this could go.
--
-- mouse: drag to paint (left) or erase (right)   1 water  2 rock  3 erase
-- t: tap on/off (pours at the top, under the mouse x)   a: rain along the top
-- m: marching squares / plain cells   g: grid   r: new landscape   c: clear   n: random
-- space: pause   s: one step (paused)   l: loop water from the bottom to the top

local gridWidth = 96
local gridHeight = 60
local cellSize = 12
local offsetX, offsetY = 24, 24

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
local waterColor = { 0.23, 0.62, 0.85, 1 }
local surfaceColor = { 0.8, 0.93, 1, 1 }
local rockColor = { 0.54, 0.37, 0.17, 1 }
local skyColor = { 0.96, 0.96, 0.86 }

local maxMass = 1.0
local maxCompress = 0.02 -- how much more a cell holds per cell of water above it (0.000002 = barely)
local minMass = 0.0001
local maxSpeed = 1.0
local minFlow = 0.01
local stepsPerFrame = 8
local sideways = 1 / 4 -- part of the difference that flows to each side per step (water.pde: 1/4, then halved)
local tapRate = 0.15  -- mass the tap adds per step

local autoWater = false
local loopWater = false
local marching = true
local showGrid = false
local paused = false
local tapOn = true
local tapX = 30
local brush = blocktype.water
local brushRadius = 1.5

local map
local mesh

local function pickRandom(array)
    local index = math.ceil(love.math.random() * #array)
    return array[index]
end

local function newCell(t)
    local mass = (t == blocktype.water and maxMass or 0)
    return { mass = mass, new_mass = mass, type = t }
end

-- A border of rock all round (index 0 and gridWidth+1 / gridHeight+1), air inside.
local function clearMap()
    map = {}
    for x = 0, gridWidth + 1 do
        map[x] = {}
        for y = 0, gridHeight + 1 do
            local border = x == 0 or y == 0 or x == gridWidth + 1 or y == gridHeight + 1
            map[x][y] = newCell(border and blocktype.solid or blocktype.air)
        end
    end
end

-- Rolling ground from noise, a bowl, a ledge, and a lake to start with.
local function makeLandscape()
    clearMap()
    local seed = love.math.random() * 100
    for x = 1, gridWidth do
        local h = 10 + love.math.noise(x / 25, seed) * 18
        local bowl = math.max(0, 1 - math.abs(x - 62) / 12) * 12 -- a dip to fill
        local ground = gridHeight - math.floor(h - bowl)
        for y = ground, gridHeight do map[x][y] = newCell(blocktype.solid) end
    end
    for x = 12, 36 do -- a ledge the tap pours onto, tilted so it runs off
        local y = 20 + math.floor((x - 12) / 6)
        map[x][y] = newCell(blocktype.solid)
        map[x][y + 1] = newCell(blocktype.solid)
    end
    for x = 70, 90 do -- a lake hanging in the air: lets go on the first frame
        for y = 8, 16 do
            if map[x][y].type == blocktype.air then map[x][y] = newCell(blocktype.water) end
        end
    end
end

local function randomMap()
    clearMap()
    for x = 1, gridWidth do
        for y = 1, gridHeight do
            map[x][y] = newCell(pickRandom({ blocktype.air, blocktype.solid, blocktype.water }))
        end
    end
end

-- How much water a cell should hold when it and the one below share total_mass.
local function getStableState(total_mass)
    if (total_mass <= 1) then
        return 1
    elseif (total_mass < 2 * maxMass + maxCompress) then
        return (maxMass * maxMass + total_mass * maxCompress) / (maxMass + maxCompress)
    else
        return (total_mass + maxCompress) / 2
    end
end

local function constrain(data, min, max)
    local result = data
    if data < min then result = min end
    if data > max then result = max end
    return result
end

local function simulateCompression()
    local flow = 0
    local remainingMass = 0

    for x = 1, gridWidth do
        for y = 1, gridHeight do
            if map[x][y].type == blocktype.solid then goto done end

            flow = 0
            remainingMass = map[x][y].mass

            if remainingMass <= 0 then goto done end

            -- block below
            do
                local yBelow = y + 1
                if loopWater and yBelow > gridHeight then
                    yBelow = 1 -- make the water go round
                end
                -- was `map[x][yBelow] ~= blocktype.air` (a cell compared to a number: always true,
                -- so water fell into rock)
                if map[x][yBelow].type ~= blocktype.solid then
                    flow = getStableState(remainingMass + map[x][yBelow].mass) - map[x][yBelow].mass
                    if flow > minFlow then
                        flow = flow * 0.5
                    end
                    flow = constrain(flow, 0, math.min(maxSpeed, remainingMass))

                    map[x][y].new_mass = map[x][y].new_mass - flow
                    map[x][yBelow].new_mass = map[x][yBelow].new_mass + flow
                    remainingMass = remainingMass - flow
                end
            end

            if remainingMass <= 0 then goto done end

            -- left (was `.blocktype`, a field that doesn't exist: water spread into rock)
            if (map[x - 1][y].type ~= blocktype.solid) then
                flow = (map[x][y].mass - map[x - 1][y].mass) * sideways
                flow = constrain(flow, 0, remainingMass)

                map[x][y].new_mass = map[x][y].new_mass - flow
                map[x - 1][y].new_mass = map[x - 1][y].new_mass + flow
                remainingMass = remainingMass - flow
            end
            if remainingMass <= 0 then goto done end

            -- right
            if (map[x + 1][y].type ~= blocktype.solid) then
                flow = (map[x][y].mass - map[x + 1][y].mass) * sideways
                flow = constrain(flow, 0, remainingMass)

                map[x][y].new_mass = map[x][y].new_mass - flow
                map[x + 1][y].new_mass = map[x + 1][y].new_mass + flow
                remainingMass = remainingMass - flow
            end
            if remainingMass <= 0 then goto done end

            -- up (only compressed water goes up)
            if (map[x][y - 1].type ~= blocktype.solid) then
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
            if map[x][1].type ~= blocktype.solid and love.math.random() < 0.05 then
                map[x][1].type = blocktype.water
                map[x][1].mass = maxMass
                map[x][1].new_mass = maxMass
            end
        end
    end
    if tapOn and map[tapX][1].type ~= blocktype.solid then
        local c = map[tapX][1]
        c.type = blocktype.water
        c.mass = c.mass + tapRate
        c.new_mass = c.mass
    end
end

-- ---------------------------------------------------------------------------
-- Interpolated marching squares. The samples sit at cell centres; each square between
-- four centres becomes a polygon: its corners that are inside (value >= iso) plus,
-- on every edge whose two ends disagree, the point where the value crosses iso.
-- Corners go clockwise: 1 = left-top, 2 = right-top, 3 = right-bottom, 4 = left-bottom.

local ISO = 0.5
local THIN = 0.3 -- mass that already draws as water: a thin falling stream (~0.15 a cell) still shows

local function waterValue(x, y)
    local c = map[x] and map[x][y]
    if not c or c.type == blocktype.solid then return 0 end
    return math.min(1, c.mass / THIN)
end

-- A surface line belongs where water meets air, not where it meets rock.
local function isAir(x, y)
    local c = map[x] and map[x][y]
    return c ~= nil and c.type ~= blocktype.solid
end

local function rockValue(x, y)
    local c = map[x] and map[x][y]
    if not c then return 1 end
    return c.type == blocktype.solid and 1 or 0
end

local function centre(x, y)
    return offsetX + (x - 0.5) * cellSize, offsetY + (y - 0.5) * cellSize
end

local cx, cy, cv, inside = {}, {}, {}, {}
local gx = { 0, 1, 1, 0 } -- corner offsets in the grid, clockwise from left-top
local gy = { 0, 0, 1, 1 }
local px, py = {}, {}

-- Fill `tris` (flat x, y list, 3 points per triangle) and `lines` (surface segments)
-- for the field `value`. A segment is kept only when both its outside corners pass `lineWhere`.
local function march(value, tris, lines, lineWhere)
    for x = 0, gridWidth do
        for y = 0, gridHeight do
            cv[1], cv[2], cv[3], cv[4] = value(x, y), value(x + 1, y), value(x + 1, y + 1), value(x, y + 1)
            inside[1], inside[2], inside[3], inside[4] = cv[1] >= ISO, cv[2] >= ISO, cv[3] >= ISO, cv[4] >= ISO
            if inside[1] or inside[2] or inside[3] or inside[4] then
                cx[1], cy[1] = centre(x, y)
                cx[2], cy[2] = centre(x + 1, y)
                cx[3], cy[3] = centre(x + 1, y + 1)
                cx[4], cy[4] = centre(x, y + 1)
                local n = 0
                local a, b
                local open = true
                for i = 1, 4 do
                    local j = i % 4 + 1
                    if inside[i] then
                        n = n + 1; px[n], py[n] = cx[i], cy[i]
                    end
                    if inside[i] ~= inside[j] then
                        local t = (ISO - cv[i]) / (cv[j] - cv[i])
                        n = n + 1
                        px[n], py[n] = cx[i] + (cx[j] - cx[i]) * t, cy[i] + (cy[j] - cy[i]) * t
                        if a then b = n else a = n end
                        local out = inside[i] and j or i
                        if lineWhere and not lineWhere(x + gx[out], y + gy[out]) then open = false end
                    end
                end
                -- a fan from the first point
                for k = 2, n - 1 do
                    tris[#tris + 1] = px[1]; tris[#tris + 1] = py[1]
                    tris[#tris + 1] = px[k]; tris[#tris + 1] = py[k]
                    tris[#tris + 1] = px[k + 1]; tris[#tris + 1] = py[k + 1]
                end
                if lines and b and open then
                    lines[#lines + 1] = px[a]; lines[#lines + 1] = py[a]
                    lines[#lines + 1] = px[b]; lines[#lines + 1] = py[b]
                end
            end
        end
    end
end

local function drawField(value, color, lineColor, lineWhere)
    local tris, lines = {}, lineColor and {} or nil
    march(value, tris, lines, lineWhere)
    if #tris >= 6 then
        local vertices = {}
        for i = 1, #tris, 2 do vertices[#vertices + 1] = { tris[i], tris[i + 1] } end
        if not mesh or mesh:getVertexCount() < #vertices then
            mesh = love.graphics.newMesh(#vertices * 2, 'triangles', 'stream')
        end
        mesh:setVertices(vertices)
        mesh:setDrawRange(1, #vertices)
        love.graphics.setColor(color)
        love.graphics.draw(mesh)
    end
    if lines and #lines > 0 then
        love.graphics.setColor(lineColor)
        love.graphics.setLineWidth(3)
        for i = 1, #lines, 4 do love.graphics.line(lines[i], lines[i + 1], lines[i + 2], lines[i + 3]) end
        love.graphics.setLineWidth(1)
    end
end

-- ---------------------------------------------------------------------------

local function drawCells()
    for y = 1, gridHeight do
        for x = 1, gridWidth do
            local color = blockcolors[map[x][y].type]
            local alpha = 1
            if map[x][y].type == blocktype.water then
                alpha = math.min(1, map[x][y].mass)
            end
            if map[x][y].type ~= blocktype.air then
                love.graphics.setColor(color[1], color[2], color[3], alpha)
                love.graphics.rectangle('fill', offsetX + (x - 1) * cellSize, offsetY + (y - 1) * cellSize,
                    cellSize, cellSize)
            end
        end
    end
end

local function totalWater()
    local sum = 0
    for x = 1, gridWidth do
        for y = 1, gridHeight do
            if map[x][y].type ~= blocktype.solid then sum = sum + map[x][y].mass end
        end
    end
    return sum
end

local selftest -- set in love.load when run with --selftest

function love.load(args)
    love.graphics.setBackgroundColor(skyColor)
    makeLandscape()
    for _, a in ipairs(args or {}) do
        if a == '--selftest' then selftest = { frame = 0 } end
    end
end

local simTime, drawTime = 0, 0 -- ms, smoothed

function love.update(_dt)
    local t0 = love.timer.getTime()
    if not paused then
        for _ = 1, stepsPerFrame do simulateCompression() end
    end
    simTime = simTime * 0.95 + (love.timer.getTime() - t0) * 1000 * 0.05
    if love.mouse.isDown(1) or love.mouse.isDown(2) then
        local mx, my = love.mouse.getPosition()
        local gx, gy = (mx - offsetX) / cellSize + 1, (my - offsetY) / cellSize + 1
        local t = love.mouse.isDown(2) and blocktype.air or brush
        for x = math.floor(gx - brushRadius), math.ceil(gx + brushRadius) do
            for y = math.floor(gy - brushRadius), math.ceil(gy + brushRadius) do
                if x >= 1 and x <= gridWidth and y >= 1 and y <= gridHeight
                    and (x - gx) ^ 2 + (y - gy) ^ 2 <= brushRadius ^ 2 then
                    map[x][y] = newCell(t)
                end
            end
        end
    end
    if selftest then
        selftest.frame = selftest.frame + 1
        if selftest.frame == 80 then love.graphics.captureScreenshot('liquid-selftest-pouring.png') end
        if selftest.frame == 100 then tapOn = false end -- pour for a bit, then see it settle
        if selftest.frame == 400 then
            love.graphics.captureScreenshot('liquid-selftest.png')
        elseif selftest.frame > 405 then
            print(string.format('selftest ok: %d frames, water %.1f, sim %.1f ms, draw %.1f ms',
                selftest.frame, totalWater(), simTime, drawTime))
            love.event.quit()
        end
    end
end

function love.draw()
    local t0 = love.timer.getTime()
    if marching then
        drawField(rockValue, rockColor)
        drawField(waterValue, waterColor, surfaceColor, isAir)
    else
        drawCells()
    end
    drawTime = drawTime * 0.95 + (love.timer.getTime() - t0) * 1000 * 0.05

    if showGrid then
        love.graphics.setColor(0, 0, 0, 0.08)
        for x = 0, gridWidth do
            love.graphics.line(offsetX + x * cellSize, offsetY, offsetX + x * cellSize, offsetY + gridHeight * cellSize)
        end
        for y = 0, gridHeight do
            love.graphics.line(offsetX, offsetY + y * cellSize, offsetX + gridWidth * cellSize, offsetY + y * cellSize)
        end
    end

    if tapOn then
        love.graphics.setColor(0.4, 0.4, 0.45)
        love.graphics.rectangle('fill', offsetX + (tapX - 2) * cellSize, offsetY - 16, cellSize * 4, 14, 4, 4)
    end

    local brushName = ({ 'erase', 'rock', 'water' })[brush]
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.print(string.format(
        'drag: paint %s (right: erase)  1 water 2 rock 3 erase  t tap %s  a rain %s  m %s  g grid  ' ..
        'r new  c clear  space %s  l loop %s   water %.0f   sim %.1f ms  draw %.1f ms  %d fps',
        brushName, tapOn and 'on' or 'off', autoWater and 'on' or 'off', marching and 'smooth' or 'cells',
        paused and 'paused' or 'running', loopWater and 'on' or 'off', totalWater(), simTime, drawTime,
        love.timer.getFPS()),
        offsetX, love.graphics.getHeight() - 22)
end

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
    if k == 'l' then loopWater = not loopWater end
    if k == 'a' then autoWater = not autoWater end
    if k == 'm' then marching = not marching end
    if k == 'g' then showGrid = not showGrid end
    if k == 'r' then makeLandscape() end
    if k == 'c' then clearMap() end
    if k == 'n' then randomMap() end
    if k == 'space' then paused = not paused end
    if k == 's' and paused then simulateCompression() end
    if k == '1' then brush = blocktype.water end
    if k == '2' then brush = blocktype.solid end
    if k == '3' then brush = blocktype.air end
    if k == 't' then
        tapOn = not tapOn
        local mx = love.mouse.getPosition()
        tapX = math.max(1, math.min(gridWidth - 1, math.floor((mx - offsetX) / cellSize) + 1))
    end
end

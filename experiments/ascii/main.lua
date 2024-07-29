require 'colors'
require '437'

WORLD_WIDTH = 32 * 4
WORLD_HEIGHT = 32 * 4
CITY_BLOCKSIZE = 12

tiletype = {
    'marker',
    'text',
    'double-line',
    'single-line'
}


function love.load()
    love.window.setMode(800, 600, { resizable = true, minwidth = 400, minheight = 300 })
    screen_scale = 1
    screen_dx = 0
    screen_dy = 0

    -- prepare ascii tiles.
    img = love.graphics.newImage("assets/CGA8x8thickT.png")
    --img = love.graphics.newImage("assets/9x9.png")
    --   img:setFilter("nearest", "nearest")
    quads = {}
    charWidth = 8
    charHeight = 8
    for i = 0, 16 * 16 do
        local x = i % 16
        local y = math.floor(i / 16)
        quads[i] = love.graphics.newQuad(x * charWidth, y * charHeight, charWidth, charHeight, img)
    end

    -- initialize world
    world = {}
    for x = 0, WORLD_WIDTH do
        world[x] = {}
        for y = 0, WORLD_HEIGHT do
            local charIndex = -1
            if (x % CITY_BLOCKSIZE == 0 and y % CITY_BLOCKSIZE == 0) then
                charIndex = 18
                world[x][y] = { tile = charIndex, type = 'marker' }
            elseif (x % 7 == 0 or y % 7 == 0) then
                world[x][y] = { tile = 0, type = 'double-line' }
            else
                world[x][y] = { tile = 0, rotation = math.floor(love.math.random() * 4) }
                if love.math.random() < 0.1 then
                    world[x][y] = { tile = 0, type = 'double-line' }
                end
            end
        end
    end

    convertTileTypesToTile(world)
    --initialize actors
    actors = {
        { x = 0, y = 0, tile = 1 }
    }
end

function tileIsOfType(tile, type)
    return tile.type == type
end

function convertTileTypesToTile(world)
    for x = 1, WORLD_WIDTH - 1 do
        for y = 1, WORLD_HEIGHT - 1 do
            -- print(x, y, world[x][y])
            local it = world[x][y]
            local north = world[x][y - 1]
            local south = world[x][y + 1]
            local east = world[x + 1][y]
            local west = world[x - 1][y]

            if it.type and it.type == 'double-line' then
                world[x][y].tile = 1 -- temp
                local binaryScore = 0
                if tileIsOfType(north, 'double-line') then
                    binaryScore = binaryScore + 1
                end
                if tileIsOfType(south, 'double-line') then
                    binaryScore = binaryScore + 2
                end
                if tileIsOfType(east, 'double-line') then
                    binaryScore = binaryScore + 4
                end
                if tileIsOfType(west, 'double-line') then
                    binaryScore = binaryScore + 8
                end
                -- 1 neighbor

                if (binaryScore == 4) then -- east
                    world[x][y].tile = 5
                    world[x][y].rotation = 0
                end
                if (binaryScore == 2) then -- south
                    world[x][y].tile = 5
                    world[x][y].rotation = 1
                end
                if (binaryScore == 8) then -- west
                    world[x][y].tile = 5
                    world[x][y].rotation = 2
                end
                if (binaryScore == 1) then -- north
                    world[x][y].tile = 5
                    world[x][y].rotation = 3
                end -- east

                if (binaryScore == 3) then
                    world[x][y].tile = 2
                    world[x][y].rotation = 0
                end                         -- north - south
                if (binaryScore == 12) then -- east - west
                    world[x][y].tile = 2
                    world[x][y].rotation = 1
                end

                if (binaryScore == 10) then -- south - west
                    world[x][y].tile = 3
                    world[x][y].rotation = 0
                end
                if (binaryScore == 9) then -- north - west
                    world[x][y].tile = 3
                    world[x][y].rotation = 1
                end
                if (binaryScore == 6) then -- south - east
                    world[x][y].tile = 3
                    world[x][y].rotation = 3
                end
                if (binaryScore == 5) then -- north - east
                    world[x][y].tile = 3
                    world[x][y].rotation = 2
                end
                --- 3 neighbors
                if (binaryScore == 7) then -- north - south -east
                    world[x][y].tile = 4
                    world[x][y].rotation = 0
                end

                if (binaryScore == 14) then -- south - east -west
                    world[x][y].tile = 4
                    world[x][y].rotation = 1
                end

                if (binaryScore == 11) then -- north - south -west
                    world[x][y].tile = 4
                    world[x][y].rotation = 2
                end
                if (binaryScore == 13) then -- north - east -west
                    world[x][y].tile = 4
                    world[x][y].rotation = 3
                end

                -- 4 neighbors
                if (binaryScore == 15) then
                    world[x][y].tile = 7
                    world[x][y].rotation = 0
                end -- 4 dir
            end
        end
    end
end

function convertTileTypesToTileOld(world)
    for x = 1, WORLD_WIDTH - 1 do
        for y = 1, WORLD_HEIGHT - 1 do
            -- print(x, y, world[x][y])
            local it = world[x][y]
            local north = world[x][y - 1]
            local south = world[x][y + 1]
            local east = world[x + 1][y]
            local west = world[x - 1][y]

            if it.type and it.type == 'double-line' then
                world[x][y].tile = 1 -- temp
                local binaryScore = 0
                if tileIsOfType(north, 'double-line') then
                    binaryScore = binaryScore + 1
                end
                if tileIsOfType(south, 'double-line') then
                    binaryScore = binaryScore + 2
                end
                if tileIsOfType(east, 'double-line') then
                    binaryScore = binaryScore + 4
                end
                if tileIsOfType(west, 'double-line') then
                    binaryScore = binaryScore + 8
                end
                -- 1 neighbor

                if (binaryScore == 4) then -- east
                    world[x][y].tile = 5
                    world[x][y].rotation = 0
                end
                if (binaryScore == 2) then -- south
                    world[x][y].tile = 5
                    world[x][y].rotation = 1
                end
                if (binaryScore == 8) then -- west
                    world[x][y].tile = 5
                    world[x][y].rotation = 2
                end
                if (binaryScore == 1) then -- north
                    world[x][y].tile = 5
                    world[x][y].rotation = 3
                end -- east

                if (binaryScore == 3) then
                    world[x][y].tile = 2
                    world[x][y].rotation = 0
                end                         -- north - south
                if (binaryScore == 12) then -- east - west
                    world[x][y].tile = 2
                    world[x][y].rotation = 1
                end

                if (binaryScore == 10) then -- south - west
                    world[x][y].tile = 3
                    world[x][y].rotation = 0
                end
                if (binaryScore == 9) then -- north - west
                    world[x][y].tile = 3
                    world[x][y].rotation = 1
                end
                if (binaryScore == 6) then -- south - east
                    world[x][y].tile = 3
                    world[x][y].rotation = 3
                end
                if (binaryScore == 5) then -- north - east
                    world[x][y].tile = 3
                    world[x][y].rotation = 2
                end
                --- 3 neighbors
                if (binaryScore == 7) then -- north - south -east
                    world[x][y].tile = 4
                    world[x][y].rotation = 0
                end

                if (binaryScore == 14) then -- south - east -west
                    world[x][y].tile = 4
                    world[x][y].rotation = 1
                end

                if (binaryScore == 11) then -- north - south -west
                    world[x][y].tile = 4
                    world[x][y].rotation = 2
                end
                if (binaryScore == 13) then -- north - east -west
                    world[x][y].tile = 4
                    world[x][y].rotation = 3
                end

                -- 4 neighbors
                if (binaryScore == 15) then
                    world[x][y].tile = 7
                    world[x][y].rotation = 0
                end -- 4 dir
            end
        end
    end
end

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
end

function love.mousepressed(x, y, button)

end

function love.wheelmoved(dx, dy)
    local mx, my = love.mouse.getPosition()
    local mtx_before = (mx - screen_dx) / screen_scale
    local mty_before = (my - screen_dy) / screen_scale

    if dy > 0 then
        screen_scale = screen_scale * 2
    else
        screen_scale = screen_scale * 1 / 2
    end

    screen_dx = mx - mtx_before * screen_scale
    screen_dy = my - mty_before * screen_scale
end

function love.mousemoved(x, y, dx, dy)
    if love.mouse.isDown(3) then
        screen_dx = screen_dx + dx
        screen_dy = screen_dy + dy
    end
end

function drawWorld()
    for x = 0, WORLD_WIDTH do
        for y = 0, WORLD_HEIGHT do
            local charIndex = world[x][y].tile
            local r = (world[x][y].rotation or 0) * math.pi / 2
            if charIndex > -1 then
                --print(r)
                love.graphics.draw(img, quads[charIndex], x * charWidth, y * charHeight, r, 1, 1, charWidth / 2,
                    charHeight / 2)
            end
        end
    end
end

function drawActors()
    for i = 1, #actors do
        local it = actors[i]
        love.graphics.draw(img, quads[it.tile], it.x, it.y, 0, 1, 1, 4, 4)
    end
end

function drawEditorOverlay()
    -- i want to see all the ascii tiles, and maybe have some indixes when hovering over it.

    love.graphics.setColor(1, 1, 1)
    love.graphics.setColor(fromName('orange'))
    love.graphics.draw(img, 0, 0)

    for paletteY = 1, 4 do
        for paletteX = 1, 8 do
            local paletteIndex = paletteX + ((paletteY - 1) * 8)
            love.graphics.setColor(fromIndex(paletteIndex))
            love.graphics.rectangle('fill', (paletteX - 1) * 16, img:getHeight() + (paletteY - 1) * 16, 16, 16)
        end
    end
    local mx, my = love.mouse.getPosition()
    if mx < img:getWidth() and my < img:getHeight() then
        local x = math.floor(mx / 8)
        local y = math.floor(my / 8)
        local i = (y * 16) + x
        if i <= #quads then
            -- print(i)
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(img, quads[i], 0, img:getHeight() + 4 * 16, 0, 2, 2)
            love.graphics.print(tostring(i), 16, img:getHeight() + 4 * 16)
        end
    end


    love.graphics.setColor(1, 1, 1)
end

function drawTextRowInWorld(text, x, y)
    local codes = get437CharCodes(text)
    for i = 1, #codes do
        local it = codes[i]
        world[x + i][y] = { tile = it, type = tiletype.text }
    end
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(screen_dx, screen_dy)
    love.graphics.scale(screen_scale, screen_scale)

    drawWorld()
    drawActors()
    love.graphics.pop()
    drawTextRowInWorld('\x01!@#$¥¥¥%^&*+_&^^%%{LÚ▒▒ÚÚ║@#:║@#:║═════', 0, 0)
    drawEditorOverlay()
end

function love.update()
    if love.mouse.isDown(1) or love.mouse.isDown(2) then
        if love.keyboard.isDown('r') then
            local mx, my = love.mouse.getPosition()
            local tx = math.floor(.5 + ((mx - screen_dx) / screen_scale) / charWidth)
            local ty = math.floor(.5 + ((my - screen_dy) / screen_scale) / charHeight)
            --print(tx, ty)
            if tx >= 0 and ty >= 0 and tx <= WORLD_WIDTH and ty <= WORLD_HEIGHT then
                if (love.mouse.isDown(1)) then
                    world[tx][ty] = { tile = 0, type = 'double-line' }
                else
                    world[tx][ty] = { tile = 0 }
                end
                convertTileTypesToTile(world)
                -- print('draw road', tx, ty)
            end
        end
    end
end

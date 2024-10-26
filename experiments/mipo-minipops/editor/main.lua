local screenData = {
    columns = 10,
    rows = 10
}
local camPos = {
    x = 0, y = 0
}

function love.load()
    gras = love.graphics.newImage('/tiles/gras.png')
    muur = love.graphics.newImage('/tiles/muur.png')
    sky = love.graphics.newImage('/tiles/sky.png')
    geel = love.graphics.newImage('/tiles/geel.png')
    steen = love.graphics.newImage('/tiles/steen.png')
    zand = love.graphics.newImage('/tiles/zand.png')
    dollar = love.graphics.newImage('/tiles/dollar.png')
    struik = love.graphics.newImage('/tiles/struik.png')
    tiles = { gras, muur, sky, geel, steen, zand, dollar, struik }
    drawIndex = 1
    map = {}
    for y = 0, screenData.rows - 1 do
        map[y] = {}
        for x = 0, screenData.columns - 1 do
            map[y][x] = 0
        end
    end
end

function love.keypressed(k)
    if k == 'escape' then
        love.event.quit()
    end
end

local function drawInto(img, x, y, w, h)
    local myWidth, myHeight = img:getDimensions()
    local myScaleX = w / myWidth
    local myScaleY = h / myHeight
    love.graphics.draw(img, x, y, 0, myScaleX, myScaleY, myWidth / 2, myHeight / 2)
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    local columns = screenData.columns
    local rows = screenData.rows
    local size = math.min(math.floor(w / columns), math.floor((h) / rows)) * .8

    local offsetX = (w - (size * columns)) / 2
    local offsetY = (h - (size * rows)) / 2

    for row = 0, rows - 1 do
        for col = 0, columns - 1 do
            local mapX = math.floor(camPos.x) + col
            local mapY = math.floor(camPos.y) + row

            if love.mouse.isDown(1) then
                local x, y = love.mouse.getPosition()
                if (x >= offsetX + (col) * size and x <= offsetX + (col) * size + size) then
                    if (y >= offsetY + (row) * size and y <= offsetY + (row) * size + size) then
                        map[mapY][mapX] = drawIndex
                    end
                end
            end
            if love.mouse.isDown(2) then
                local x, y = love.mouse.getPosition()
                if (x >= offsetX + (col) * size and x <= offsetX + (col) * size + size) then
                    if (y >= offsetY + (row) * size and y <= offsetY + (row) * size + size) then
                        map[mapY][mapX] = 0
                    end
                end
            end

            if map[mapY][mapX] ~= 0 then
                local index = map[mapY][mapX]
                drawInto(tiles[index], offsetX + (col) * size + size / 2, offsetY + (row) * size + size / 2, size, size)
            end
            love.graphics.setColor(1, 1, 1, .3)
            love.graphics.rectangle('line',
                offsetX + (col) * size,
                offsetY + (row) * size,
                size, size)
            love.graphics.setColor(1, 1, 1)
        end
    end

    -- bottombar
    local size = 50
    love.graphics.rectangle('fill', 0, h - size, w, h)
    for i = 1, #tiles do
        if love.mouse.isDown(1) then
            local x, y = love.mouse.getPosition()
            if x >= i * size and x <= (i * size) + size then
                if y >= h - size and y <= h then
                    drawIndex = i
                end
            end
        end

        drawInto(tiles[i], i * size + size / 2, h - size + size / 2, size, size)
    end
end

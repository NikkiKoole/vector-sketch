local scene = {}


function isInRect(x, y, rx, ry, rw, rh)
    return x > rx and x < (rx + rw) and y > ry and y < (ry + rh)
end

function scene:load(args)
    -- print("Scenery is awesome", inspect(args))
    games = {}
    for i = 1, #scenes do
        local it = scenes[i]
        if it.img then
            local img = love.graphics.newImage(it.img)
            if img then
                table.insert(games, { img = img, key = it.key, draft = it.draft })
            end
        end
    end

    -- print(inspect(games))
end

function scene:unload()
    --print('unloading overworld')
end

function scene:keypressed(k)
    if k == 'escape' then love.event.quit() end
end

function scene:mousemoved(x, y, dx, dy)
    -- print(dx, dy)
end

local function drawInto(img, x, y, w, h)
    local myWidth, myHeight = img:getDimensions()
    local myScaleX = w / myWidth
    local myScaleY = h / myHeight
    love.graphics.draw(img, x, y, 0, myScaleX, myScaleY)
end

function scene:draw()
    local screenW, screenH = love.graphics.getDimensions()

    local itemsInRow = math.min(#games+2, 4)
    local m = 150
    local w = math.floor((screenW / m)) * m / itemsInRow
    local h = w * 3 / 4
    local offsetX = (screenW - (w * itemsInRow)) / 2
    local offsetY = (screenH - (h * 2)) / 2
    love.graphics.clear(.4, .7, .7)

    for i = 1, #games do
        local x = offsetX + ((i - 1) % itemsInRow) * w
        local y = offsetY + math.floor((i - 1) / itemsInRow) * h

        if love.mouse.isDown(1) then
            local mx, my = love.mouse.getPosition()
            if (isInRect(mx, my, x, y, w, h) and not games[i].draft ) then
                self.setScene(games[i].key)
            end
        end

        if (games[i].draft == true) then
            love.graphics.setColor(1,0,1,0.1)
            else
            love.graphics.setColor(1,1,1,1)
        end
        drawInto(games[i].img, x, y, w - 10, h - 10)
    end
    love.graphics.setColor(1,1,1,1)
    love.graphics.print('Free Game Pops\n', 200, 10)
end

function scene:update(dt)
    --print("You agree, don't you?")
end






return scene

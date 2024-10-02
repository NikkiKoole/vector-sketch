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
                table.insert(games, { img = img, key = it.key })
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

function scene:draw()
    love.graphics.clear(.4, .7, .7)
    local w = 400
    local h = 300
    for i = 1, #games do
        if love.mouse.isDown(1) then
            local mx, my = love.mouse.getPosition()
            if (isInRect(mx, my, 0, (i - 1) * h, w, h)) then
                self.setScene(games[i].key)
            end
        end
        love.graphics.draw(games[i].img, 0, (i - 1) * h)
    end
end

function scene:update(dt)
    --print("You agree, don't you?")
end

return scene

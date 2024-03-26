function love.load()
    introPlaatje = love.graphics.newImage("klik.png")
    introPlaatjeVierkant = {
        x = 272,
        y = 159,
        w = 290,
        h = 293
    }
    inIntro = true
    pop = love.graphics.newImage("hermanpop.png")
end

function love.draw()
    love.graphics.clear(1, 1, 1)
    love.graphics.setColor(1, 1, 1, 1)

    if inIntro == true then
        love.graphics.draw(introPlaatje)
    end

    if not inIntro then
        local r = love.timer.getTime()
        local w, h = love.graphics:getDimensions()
        love.graphics.draw(pop, w / 2, h / 2, r, 1, 1, pop:getWidth() / 2, pop:getHeight() / 2)
    end
end

function love.mousepressed(x, y)
    local k = introPlaatjeVierkant
    if inIntro then
        if x > k.x and x < k.x + k.w then
            if y > k.y and y < k.y + k.h then
                inIntro = false
            end
        end
    end
end

function love.keypressed(key)
    if key == 'escape' then love.event.quit() end
end

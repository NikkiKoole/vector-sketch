-- things todo, there should mybe be an extra y offset that makes certain mouths hapes move more down (or up)
-- look at teeth.

--inspect = require 'inspect'
local mouthEditor = require 'mouth-editor'
local Mouth = require 'mouth'
local mode = "edit" -- or "play"

function love.load()
    love.window.setMode(1600, 1024)
    love.graphics.setBackgroundColor(0.1, 0.1, 0.1)

    font = love.graphics.getFont()
    bigfont = love.graphics.newFont('assets/VoltaT-Regu.ttf', 24)


    mouth1 = Mouth.new()
    mouth2 = Mouth.new()
    --mouth.init()
end

function love.keypressed(key)
    if key == "tab" then
        mode = (mode == "edit") and "play" or "edit"
    end
    if key == 'escape' then
        love.event.quit()
    end

    -- if key == 'space' then
    --mouth1:nextLips()
    --mouth2:nextLips()
    if key == 'r' then
        mouth1:nextShape()
        mouth2:previousShape()
    elseif key == 'e' then
        mouth1:previousShape()
        mouth2:nextShape()
    end

    if key == 'space' then
        local phonemes = { 'a', 'i', 'o', 'b', 'p', 'f', 'k', 'l', 't', 'j', 'n', 'd', 's', 'h', 'w' }
        local index = math.ceil(love.math.random() * #phonemes)
        local phoneme = phonemes[index]
        mouth1:setToPhoneme(phoneme)
        print(phoneme)
    end
end

function love.update(dt)
    mouth1:update(dt)
    mouth2:update(dt)
end

function love.mousepressed(x, y, button)
    if mode == "edit" then
        mouthEditor.mousepressed(x, y, button)
    end
end

function love.mousereleased(x, y, button)
    if mode == "edit" then
        mouthEditor.mousereleased(x, y, button)
    end
end

function love.mousemoved(x, y)
    if mode == "edit" then
        mouthEditor.mousemoved(x, y, button)
    end
end

function love.draw()
    if mode == "edit" then
        mouthEditor.draw()


        love.graphics.push()
        -- love.graphics.setColor(1, 1, 0)
        -- love.graphics.translate(1400, 200)
        -- love.graphics.ellipse('fill', 0, 0, 150, 200)
        mouth1:draw(1, 1)
        love.graphics.pop()
        love.graphics.push()
        love.graphics.setColor(1, 1, 0)
        love.graphics.translate(1400, 400)
        --love.graphics.ellipse('fill', 0, 0, 150, 200)
        mouth2:draw(1, 1)
        love.graphics.pop()
    elseif mode == "play" then
        -- mouth:draw(400, 300, 1)
    end
end

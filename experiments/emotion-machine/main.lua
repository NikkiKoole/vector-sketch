-- things todo, there should mybe be an extra y offset that makes certain mouths hapes move more down (or up)
-- look at teeth.

local inspect = require 'inspect'

local mouthEditor = require 'mouth-editor'
local mouth = require 'mouth-renderer'
local shapes = require 'mouth-shapes'
local mode = "edit" -- or "play"


function love.load()
    love.window.setMode(1600, 1024)
    love.graphics.setBackgroundColor(0.1, 0.1, 0.1)

    font = love.graphics.getFont()
    bigfont = love.graphics.newFont('assets/VoltaT-Regu.ttf', 24)

    mouth.init()
end

function love.keypressed(key)
    if key == "tab" then
        mode = (mode == "edit") and "play" or "edit"
    end
    if key == 'escape' then
        love.event.quit()
    end

    if key == 'space' then
        mouth.nextLips()
    elseif key == 'r' then
        mouth.nextShape()
    elseif key == 'e' then
        mouth.previousShape()
    end
end

function love.update()
    mouth.update()
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
        love.graphics.translate(1400, 200)
        mouth.drawCurrentShape(1, 1)
        love.graphics.pop()
    elseif mode == "play" then
        -- mouth:draw(400, 300, 1)
    end
end

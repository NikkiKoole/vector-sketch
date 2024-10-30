-- main.lua

local Commander = require("commander") -- Ensure commander.lua is in the same directory

-- Instantiate the Commander
local commander = Commander:new()

-- Love2D Callbacks

function love.load()
    love.window.setMode(1200, 1000, { resizable = true })
    commander:load()
    commander:resize(1200, 1000)
end

function love.resize(w, h)
    commander:resize(w, h)
end

function love.draw()
    commander:draw()
end

function love.textinput(t)
    commander:textinput(t)
end

function love.keypressed(key)
    commander:keypressed(key)
end

function love.mousepressed(x, y, button)
    commander:mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    commander:mousereleased(x, y, button)
end

function love.wheelmoved(x, y)
    commander:wheelmoved(x, y)
end

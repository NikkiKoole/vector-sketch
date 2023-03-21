
function love.load()
    -- Set up the game window and background color
    love.window.setMode(800, 600)
    love.graphics.setBackgroundColor(0.8, 0.8, 0.8)
    
    -- Load the images for the game objects
    trashImage = love.graphics.newImage("trash.png")
    broomImage = love.graphics.newImage("broom.png")
    
    -- Set up the game objects
    trash = {x = 100, y = 400}
    broom = {x = 500, y = 400}
    
    -- Set up the game state
    dragging = false
    mouseX = 0
    mouseY = 0
  end
  
  function love.draw()
    -- Draw the game objects if they exist
    if trash ~= nil then
      love.graphics.draw(trashImage, trash.x, trash.y)
    end
    
    love.graphics.draw(broomImage, broom.x, broom.y)
  end
  
  function love.mousepressed(x, y, button)
    -- Check if the mouse is over the trash
    if trash ~= nil and x > trash.x and x < trash.x + trashImage:getWidth() and y > trash.y and y < trash.y + trashImage:getHeight() then
      dragging = true
    end
    
    -- Store the mouse position
    mouseX = x
    mouseY = y
  end
  
  function love.mousereleased(x, y, button)
    -- Check if the trash is over the broom
    if trash ~= nil and trash.x + trashImage:getWidth() > broom.x and trash.x < broom.x + broomImage:getWidth() and trash.y + trashImage:getHeight() > broom.y and trash.y < broom.y + broomImage:getHeight() then
      -- Remove the trash
      trash = nil
    end
    
    -- Reset the dragging state
    dragging = false
  end
  
  function love.mousemoved(x, y, dx, dy)
    -- Move the trash if it's being dragged
    if dragging and trash ~= nil then
      trash.x = trash.x + dx
      trash.y = trash.y + dy
    end
  end

--[[
function love.load()
        -- Set the initial position and velocity of the ball
    x, y = 100, 100
    vx, vy = 150, 150

    -- Set the radius and color of the ball
    radius = 20
    color = {255, 255, 255}
end

function love.update(dt)
    -- Update the position of the ball based on its velocity and the time since the last update
    x = x + vx * dt
    y = y + vy * dt

    -- Reverse the velocity of the ball if it hits the sides of the screen
    if x < radius or x > love.graphics.getWidth() - radius then
        vx = -vx
    end

    -- Reverse the velocity of the ball if it hits the top or bottom of the screen
    if y < radius or y > love.graphics.getHeight() - radius then
        vy = -vy
    end
end

function love.draw()
    -- Draw the ball on the screen
    love.graphics.setColor(color)
    love.graphics.circle("fill", x, y, radius)
end
--]]
Camera = require 'stalker'


function love.keypressed(key)
   if key == 'escape' then love.event.quit() end
end


function love.load()
   width = love.graphics.getWidth()
   height = love.graphics.getHeight()
   
   player = {
      x = width / 2 - 25,
      y = height / 2 - 25,
      width = 50,
      height = 50,
      speed = 300,
      color = { 150/255, 150/255, 150/255 }
   }
   
   box = {
      x = 0,
      y = 0,
      width = width*2 ,
      height = height*2 ,
      color = { 255/255, 20/255, 20/255 }
   }
   
   stuff = {}
   
   for i = 1, 10 do
      table.insert(
         stuff,
         {
            x = love.math.random(100, width * 2 - 100),
            y = love.math.random(100, height * 2 - 100),
            width = love.math.random(100, 300),
            height = love.math.random(100, 300),
            color = { 1, 1, 1 }
         }
      )
   end

   camera = Camera()
   camera:setFollowStyle('LOCKON')
   camera:setFollowLerp(0.02)
   camera:setFollowLead(10)
end


function love.update(dt)

   camera:update(dt)
    camera:follow(player.x, player.y)
    
   if love.keyboard.isDown('left') then
    player.x = player.x - player.speed * dt
  elseif love.keyboard.isDown('right') then
    player.x = player.x + player.speed * dt
  elseif love.keyboard.isDown('up') then
    player.y = player.y - player.speed * dt
  elseif love.keyboard.isDown('down') then
    player.y = player.y + player.speed * dt
  end

   
  
end

function love.draw()
   love.graphics.clear(.3, .3, .7)
   camera:attach()
--     -- Draw your game here

      -- box
   love.graphics.setColor(box.color)
   love.graphics.setLineWidth(4)
   love.graphics.rectangle('line', box.x, box.y, box.width, box.height)
   love.graphics.setLineWidth(1)
  
   -- stuff
   for _, v in pairs(stuff) do
      love.graphics.setColor(v.color)
      love.graphics.rectangle('fill', v.x, v.y, v.width, v.height)
   end
  
  -- player
  love.graphics.setColor(player.color)
  love.graphics.rectangle('fill', player.x, player.y, player.width, player.height)
  
    
     camera:detach()
--     camera:draw() -- Call this here if you're using camera:fade, camera:flash or debug drawing the deadzone
end


require('camera1')


function love.keypressed(key)
   if key == 'escape' then love.event.quit() end
end

function love.mousepressed(x,y)
   cameraLockedOnPlayer = not cameraLockedOnPlayer
end

function love.wheelmoved(x,y)
   local currentScale = camera.scaleX
   local newScale = y < 0 and 0.9 or 1.1
   local mx, my = love.mouse.getPosition()
 
   local w1x = camera._x  + mx*currentScale
   local w1y = camera._y  + my*currentScale
   local w2x = camera._x  + mx*newScale*currentScale
   local w2y = camera._y  + my*newScale*currentScale

   local dx, dy = w1x - w2x, w1y - w2y
   camera:scale(newScale)
   camera:move(dx, dy)
   
end


function love.load()
   
   width = love.graphics.getWidth()
   height = love.graphics.getHeight()
   --camera:setBounds(0, 0, width, height)
   
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

   cameraLockedOnPlayer = true
end

function love.update(dt)
  
   local v = {x=0, y=0}
   
   if love.keyboard.isDown('left') then
      v.x = v.x - 1
   end
   if love.keyboard.isDown('right') then
      v.x = v.x + 1
   end
   if love.keyboard.isDown('up') then
      v.y = v.y - 1
   end
   if love.keyboard.isDown('down') then
      v.y = v.y + 1
   end

   local mag = math.sqrt((v.x * v.x) + (v.y * v.y))
   if mag > 0 then
      v.x = (v.x/mag) * player.speed * dt 
      v.y = (v.y/mag) * player.speed * dt
      player.x = player.x + v.x
      player.y = player.y + v.y
   end
   
  if cameraLockedOnPlayer then
     camera:setPositionSmooth(
        (player.x + player.width/2) - (width / 2) * camera.scaleX,
        (player.y + player.height/2) - (height / 2) * camera.scaleY,
        dt
     )
  end
end

function love.draw()
   love.graphics.clear(.3, .3, .7)
   camera:set(width * camera.scaleX, height * camera.scaleY)
  
  -- box
   love.graphics.setColor(box.color)
   love.graphics.setLineWidth(4)
   love.graphics.rectangle('line', box.x, box.y, box.width, box.height)
   love.graphics.setLineWidth(1)
  
   -- stuff
   --bakc layer
   love.graphics.push()
   love.graphics.translate(-camera._x * 0.98, -camera._y * 0.98)
   love.graphics.scale(.98, .98)
    for _, v in pairs(stuff) do
      love.graphics.setColor(1,0,0)
      love.graphics.rectangle('fill', v.x , v.y, v.width , v.height)
    end
    love.graphics.pop()


    --
    --love.graphics.push()
    --love.graphics.translate(-camera._x, -camera._y)
    for _, v in pairs(stuff) do
      love.graphics.setColor(v.color)
      love.graphics.rectangle('fill', v.x, v.y, v.width, v.height)
    end
    --love.graphics.pop()
  
  -- player
  love.graphics.setColor(player.color)
  love.graphics.rectangle('fill', player.x, player.y, player.width, player.height)
  
  camera:unset()

  if cameraLockedOnPlayer then
     love.graphics.print('camera locked')
  end
  love.graphics.print('scale: '..camera.scaleX, 0, 20)
  love.graphics.print('pos: '..camera._x..", "..camera._y, 0, 40)
  
  love.graphics.setColor(1,.5,1,0.2)
  love.graphics.rectangle('fill',
                          width/2  - player.width/2,
                          height/2  - player.height/2,
                          player.width, player.height)

  love.graphics.line(0,0,width,height)
  love.graphics.line(0,height,width,0)

end


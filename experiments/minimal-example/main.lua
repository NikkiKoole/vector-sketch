local inspect= require 'inspect'

function love.keypressed(key)
   if key == 'escape' then love.event.quit() end
   
end

function love.load()
   vertices = {{0,0},{100,0},{100,100},{0,100}}
   mesh = love.graphics.newMesh(vertices)
   t = {400, 300, 0.75, 1, 1, 50, 100, 0, 0 }
   transform = love.math.newTransform(t[1],t[2],t[3],t[4],t[5],t[6],t[7],t[8],t[9])
   mousedown = false
   dragging = false
end

function love.mousepressed(x,y)
   mousedown = true

   if true then
      local invx, invy = transform:inverseTransformPoint(x,y)
      dragging = {dx=invx, dy=invy}
   end
end

function love.mousereleased(x,y)
   mousedown = false
   dragging = false
end

function love.update(dt)
   if mousedown then
      
      --the dragging part
      if  dragging then
	 local x, y = love.mouse.getPosition()
	 local invx, invy = transform:inverseTransformPoint(x,y)
	 t[1] = t[1] + (invx - dragging.dx)
	 t[2] = t[2] + (invy - dragging.dy)
	 transform = transform:translate( (invx - dragging.dx), (invy - dragging.dy) )
	 --transform = love.math.newTransform(t[1],t[2],t[3],t[4],t[5],t[6],t[7],t[8],t[9])
      end
      -- end the dragging part
      
      -- the rotating part
      --
      --t[3] = t[3] + 8*dt
      --transform = love.math.newTransform(t[1],t[2],t[3],t[4],t[5],t[6],t[7],t[8],t[9])

      --print(transform:getMatrix())
      transform = transform:rotate(8*dt)
      -- end the rotating part
   end
end



function love.draw()
   love.graphics.setColor(1,0,1,0.5)
   love.graphics.draw(mesh, transform)
   
   love.graphics.setColor(1,1,1)
   love.graphics.rectangle('fill', 400,300,2,2)
end

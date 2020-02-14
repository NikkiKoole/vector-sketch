require 'util'
require 'poly'

function love.keypressed(key)
   if key == 'escape' then
      love.event.quit()
   end
end

function love.load()
   love.window.setMode(1024, 600, {resizable=true, vsync=false, minwidth=400, minheight=300})
   points = {}

   local count = 32
   local space = 1024/count

   for i=1, count do
      points[i] = {i * space + (love.math.random()*(space/1.3) - (space/4)), 100}
   end
end

function drawPoints(counter)
   local coords = {}
   local waves = 5
   local middleY = 100
   local amplitude = 10
   local speed = 1000
   local screenwidth = love.graphics.getWidth()

   for i = 1, #points do
      local x = (points[i][1]) + counter*speed
      local x2 = (x / screenwidth) * math.pi * waves
      local r  =  math.sin(x2)
      points[i][2] = middleY + r * amplitude
      coords[i*2 - 1] = points[i][1]
      coords[i*2 ] = points[i][2]
   end

   for i =1, #points do
      love.graphics.rectangle("fill", points[i][1],  points[i][2], 2, 2)
   end

   love.graphics.line(coords)
end


local waveCounter = 0
function love.update(dt)
   waveCounter = waveCounter + dt
end

function love.draw()
   drawPoints(waveCounter)
end

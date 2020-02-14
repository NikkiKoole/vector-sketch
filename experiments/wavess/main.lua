require 'util'
require 'poly'

function love.keypressed(key)
   if key == 'escape' then
      love.event.quit()
   end
end

function love.load()
   local screenwidth = 1204
   love.window.setMode(screenwidth, 600, {resizable=true, vsync=false, minwidth=400, minheight=300})
   points = {}

   local count = 18
   local space = (screenwidth+200)/count

   for i=1, count do
      local x = -100 + i * space + (love.math.random()*(space/1.3) - (space/4))
      points[i] = {x, 100}
   end
end

function drawPoints(counter, delta)
   local coords = {}
   local waves = 7
   local middleY = 100
   local amplitude = 15
   local speed = 300
   local screenWidth = love.graphics.getWidth()


   ---- begin part moving with speed through water
   local velocity = delta * 100
   for i=1, #points do
      points[i][1] = points[i][1] - velocity
   end
   if (points[1][1] < -100) then
      points[1][1] = points[1][1] + screenWidth + 200
      local p = table.remove(points, 1)
      table.insert(points, p)
   end
   ---- end part moving with speed through water

   -- begin part waves moving
   for i = 1, #points do
      local x = (points[i][1]) + counter*speed
      local x2 = (x / screenWidth) * math.pi * waves
      local r  =  math.sin(x2)
      points[i][2] = middleY + r * amplitude
      coords[i*2 - 1] = points[i][1]
      coords[i*2 ] = points[i][2]
   end
   -- end part waves moving

   for i =1, #points do
      love.graphics.rectangle("fill", points[i][1],  points[i][2], 2, 2)
   end

   love.graphics.line(coords)
end


local waveCounter = 0
local delta = 0
function love.update(dt)
   delta = dt
   waveCounter = waveCounter + dt
end

function love.draw()
   drawPoints(waveCounter, delta)
end

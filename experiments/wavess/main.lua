require 'util'
require 'poly'

function love.keypressed(key)
   if key == 'escape' then
      love.event.quit()
   end

   if key == 'left' then
      pxPerSeconds = pxPerSeconds - 10
   end
   if key == 'right' then
      pxPerSeconds = pxPerSeconds + 10
   end
   if key == 'up' then
      amplitude = amplitude + 2
   end
   if key == 'down' then
      amplitude = amplitude - 2
   end
   if key == 'w' then
      waves = waves + 1
   end
   if key == 's' then
      waves = waves - 1
   end
   if key == 'a' then
      speed = speed + 10
   end
   if key == 'd' then
      speed = speed - 10
   end


end

function love.load()
   local screenwidth = 1204
   love.window.setMode(screenwidth, 600, {resizable=true, vsync=false, minwidth=400, minheight=300})
   points = {}

   waveOverflow = screenwidth/2
   pxPerSeconds = 100
   amplitude = 15
   waves = 7
   speed = 150
   local count = 47
   local space = (screenwidth+waveOverflow*2)/count

   for i=1, count do
      local x = -waveOverflow + i * space + (love.math.random()*(space/1.3) - (space/4))
      points[i] = {x, 100}
   end
end

local function sortPointsOnX(a,b)
   return a[1] < b[1]
end


function drawPoints(counter, delta, middleY, scale, waveMultiplier)
   local coords = {}
   --local waves = 7
   --local middleY = 400
   --local amplitude = 15
   --local speed = 150
   local screenWidth = love.graphics.getWidth()


   ---- begin part moving with speed through water
   --local pxPerSeconds = 100
   local velocity = delta * pxPerSeconds  / scale
   for i=1, #points do
      points[i][1] = points[i][1] - velocity
   end

   if (pxPerSeconds >= 0) then
      if (points[1][1] < -waveOverflow/2) then
	 points[1][1] = points[1][1] + screenWidth + waveOverflow*2
	 local p = table.remove(points, 1)
	 table.insert(points, p)
      end
   end

   if (pxPerSeconds <= 0) then
      if (points[#points][1] > screenWidth+waveOverflow/2) then
	 points[#points][1] =  points[#points][1] -(screenWidth+waveOverflow*2)
	 local p = table.remove(points, #points)
	 table.insert(points, 1, p)

      end
   end
   table.sort( points, sortPointsOnX)

   ---- end part moving with speed through water

   -- begin part waves moving
   for i = 1, #points do
      local x = (points[i][1]) + counter*speed*scale
      local x2 = (x / screenWidth) * math.pi * waves * waveMultiplier
      local r  =  math.sin(x2)
      points[i][2] = middleY + r * amplitude*scale
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
   drawPoints(waveCounter, delta, 400, 3, 1)
   drawPoints(waveCounter, delta, 100, 1, 12)
end

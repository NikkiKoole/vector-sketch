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
      amplitude = amplitude + 0.25
   end
   if key == 'down' then
      amplitude = amplitude - 0.25
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

   print("pxPerSeconds", pxPerSeconds, "amplitude", amplitude, "waves", waves, "speed", speed)

end

function love.load()
   local screenwidth = 1204
   love.window.setMode(screenwidth, 600, {resizable=true, vsync=false, minwidth=400, minheight=300})
   points = {}

   waveOverflow = screenwidth/2

--   pxPerSeconds	70	amplitude	3	waves	11	speed	20
   --pxPerSeconds	60	amplitude	1	waves	23	speed	40
--pxPerSeconds	30	amplitude	-0.55	waves	17	speed	0
   pxPerSeconds = 30
   amplitude = 0.55
   waves = 17
   speed = 0
   local count = 32
   local space = (screenwidth+waveOverflow*2)/count
   for i=1, count do
      local x = -waveOverflow + i * space + (love.math.random()*(space/1.3) - (space/4))
      points[i] = {x, 100}
   end


   points2 = {}
   count = 74
   space = (screenwidth+waveOverflow*2)/count
   for i=1, count do
      local x = -waveOverflow + i * space + (love.math.random()*(space/1.3) - (space/4))
      points2[i] = {x, 100}
   end



end

local function sortPointsOnX(a,b)
   return a[1] < b[1]
end


function drawPoints(points, counter, delta, middleY, scale, waveMultiplier, alpha)
   local coords = {}
   local screenWidth = love.graphics.getWidth()


   ---- begin part moving with speed through water
   --local pxPerSeconds = 100
   local velocity = delta * pxPerSeconds  * scale
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
      --love.graphics.rectangle("fill", points[i][1],  points[i][2], 2, 2)
   end


    -- now make it a closed shape please
   local lastX = coords[#coords-1]
   local lastY = coords[#coords]


   table.insert(coords, lastX)
   table.insert(coords, lastY+1200)
   table.insert(coords, coords[1])
   table.insert(coords, lastY+1200)
   table.insert(coords, coords[1])
   table.insert(coords, coords[2])

   love.graphics.setColor(0.145,0.6,0.670, alpha)
   local polys = decompose_complex_poly(coords, {})
    for i=1 , #polys do
       local p = polys[i]
       local triangles = love.math.triangulate(p)
       for j = 1, #triangles do
	  --print(triangles[j])
	  love.graphics.polygon('fill', triangles[j])
       end
    end

   love.graphics.setColor(1,1,1, alpha)

   --love.graphics.line(coords)
end


local waveCounter = 0
local delta = 0
function love.update(dt)
   delta = dt
   waveCounter = waveCounter + dt
end

function love.draw()
--   drawPoints(points2, waveCounter, delta, 100, 0.6, 12, 0.95)

   drawPoints(points, waveCounter, delta, 300, 3, 1, 0.9)

    love.graphics.setColor(1, 1, 0.670)
    love.graphics.rectangle("fill", 200, 200, 300, 300)

   drawPoints(points, waveCounter, delta, 400, 3, 1, 0.9)

end

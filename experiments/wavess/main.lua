require 'util'
require 'poly'
flux = require "flux"


function love.keypressed(key)
   if key == 'escape' then
      love.event.quit()
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
   -- if key == 'a' then
   --    speed = speed + 10
   -- end
   -- if key == 'd' then
   --    speed = speed - 10
   -- end

   if key == '1' then
      --local delta =  math.abs((waveVars.speed - 0) / 10)
      --local delta2 =  math.abs((waveVars.pxPerSeconds - 50) / 50)
      --print(delta, delta2)
      --flux.to(waveVars, delta, {speed=0}):after(waveVars, delta2, {pxPerSeconds=50})
      --flux.to(waveVars, 0.5, {pxPerSeconds=-75})--:after(waveVars, delta, {speed=0})
      --waveVars.speed = 0
      waveVars.pxPerSeconds = -100
   end
   if key == '2' then
      --local delta =   math.abs((waveVars.speed - 25) / 10)
      --local delta2 =   math.abs((waveVars.pxPerSeconds - 0) / 50)
      --print(delta, delta2)

      --flux.to(waveVars, delta, { speed=25}):after(waveVars, delta2, {pxPerSeconds=0})
      --local s = waveVars.pxPerSeconds
      --

      flux.to(waveVars, 0.5, {pxPerSeconds=25})--:after(waveVars, 2, {speed=s})
      --waveVars.speed = 25 --waveVars.pxPerSeconds
      --waveVars.pxPerSeconds = 50
   end
   if key == '3' then
      --local delta =   math.abs((waveVars.speed - 0) / 10)
      --local delta2 =   math.abs((waveVars.pxPerSeconds + 50) / 50)
      --print(delta, delta2)

      --flux.to(waveVars, delta, { speed=0}):after(waveVars, delta2, {pxPerSeconds=-50})
      flux.to(waveVars, 0.5, {pxPerSeconds=125})--:after(waveVars, delta2, {speed=0})
      -- waveVars.speed = 0
      --waveVars.pxPerSeconds = 100

   end


   --print("pxPerSeconds", pxPerSeconds, "amplitude", amplitude, "waves", waves, "speed", speed)

end

function love.load()
   local screenwidth = 1204
   love.window.setMode(screenwidth, 600, {resizable=true, vsync=false, minwidth=400, minheight=300})
   points = {}

   waveOverflow = screenwidth/2

--   pxPerSeconds	70	amplitude	3	waves	11	speed	20
   --pxPerSeconds	60	amplitude	1	waves	23	speed	40

   --pxPerSeconds	0	amplitude	1.7	waves	16	speed	50
   waveVars = {
      pxPerSeconds = 0.001,
      speed = 50
   }


   amplitude = 1.7
   waves = 16

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
  local velocity = delta * waveVars.pxPerSeconds  * scale
    for i=1, #points do
       points[i][1] = points[i][1] - velocity
    end

  --  if (waveVars.pxPerSeconds > 0) then
  --     for i=1, #points do
  -- 	 if (points[i][1] < -waveOverflow/2) then
  -- 	    points[i][1] = points[i][1] + screenWidth + waveOverflow*2
  -- 	    local p = table.remove(points, 1)
  -- 	    table.insert(points, p)
  -- 	    print('insert at end', delta)
  -- 	 end
  --     end
  --  end


  --  if (waveVars.pxPerSeconds < 0) then
  --     for i=1, #points do
  --     if (points[i][1] > screenWidth+waveOverflow/2) then
  -- 	 points[i][1] =  points[i][1] -(screenWidth+waveOverflow*2)
  -- 	 local p = table.remove(points, #points)
  -- 	 table.insert(points, 1, p)
  -- 	 print('insert at start', delta)

  --     end
  --     end
  --  end
  -- table.sort( points, sortPointsOnX)

   ---- end part moving with speed through water

   -- begin part waves moving
   for i = 1, #points do
      local x = (points[i][1]) + counter*waveVars.speed*scale
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
   flux.update(dt)

   delta = dt
   waveCounter = waveCounter + dt
end

function anotherWaveFunction(waveCounter)
   local waves = 20
   local amplitude = 10
   local middleY = 400
   local screenWidth = love.graphics.getWidth()

   for i =1, (screenWidth/10) do
      local x = (i*10)
      local x2 = ( x + (waveCounter * waveVars.pxPerSeconds))
      local y =  (x2 / screenWidth) * math.pi * waves
      love.graphics.rectangle("fill", x, middleY + math.sin(y) * amplitude , 5, 5)
   end
end


function love.draw()
   --drawPoints(points2, waveCounter, delta, 100, 0.6, 12, 0.95)
   --drawPoints(points, waveCounter, delta, 200, 3, 1, 0.9)
    --love.graphics.setColor(1, 1, 0.670)
    --love.graphics.rectangle("fill", 200, 200, 300, 300)

   --drawPoints(points, waveCounter, delta, 400, 3, 1, 0.9)
    anotherWaveFunction(waveCounter)
end

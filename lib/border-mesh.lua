local numbers = require 'lib.numbers'
local lerp = numbers.lerp

function makeBorderMesh(node)
   local work = unpackNodePointsLoop(node.points)

   local output = {}

   for i =50, 100 do
      local t = (i/100)
      if t >= 1 then t = 0.99999999 end

      local x,y = GetSplinePos(work, t, node.borderTension)
      table.insert(output, {x,y})
   end

   local rrr = {}
   local r2 = evenlySpreadPath(rrr, output, 1, 0, node.borderSpacing)

   output = unpackNodePoints(rrr)
   local verts, indices, draw_mode = polyline('miter',output, node.borderThickness, nil, nil, node.borderRandomizerMultiplier)
   local mesh = love.graphics.newMesh(simple_format, verts, draw_mode)
   return mesh
end


function evenlySpreadPath(result, path, index, running, spacing)
   local here = path[index]
   if index == #path then return end

   local nextIndex = index+1
   local there = path[nextIndex]
   local d = getDistance(here[1], here[2], there[1], there[2])
   if (d + running) < spacing then

      running = running + d
      return evenlySpreadPath(result, path, index+1, running, spacing)
   else
      if running >= d then
         --print('missing one here i think', running/d)
         local x = lerp(here[1], there[1], 1 or running/d)
         local y = lerp(here[2], there[2], 1 or running/d)
         --if index < #path-2 then
         table.insert(result, {x,y, {1,0,0}} )
         --end
         --running = d
      end

      while running <= d do

         local x = lerp(here[1], there[1], running/d)
         local y = lerp(here[2], there[2], running/d)
         table.insert(result, {x,y, {1,0,1}})

         running = running + spacing
      end

      if running >= d then
         running = running - d
         return evenlySpreadPath(result, path, index+1, running, spacing)
      end
   end


end

function evenlySpreadPath(result, path, index, running, spacing)
   local here = path[index]
   if index == #path then return end

   local nextIndex = index+1
   local there = path[nextIndex]
   local d = getDistance(here[1], here[2], there[1], there[2])
   if (d + running) < spacing then

      running = running + d
      return evenlySpreadPath(result, path, index+1, running, spacing)
   else
      if running >= d then
         --print('missing one here i think', running/d)
         local x = lerp(here[1], there[1], 1 or running/d)
         local y = lerp(here[2], there[2], 1 or running/d)
         --if index < #path-2 then
         table.insert(result, {x,y, {1,0,0}} )
         --end
         --running = d
      end

      while running <= d do

         local x = lerp(here[1], there[1], running/d)
         local y = lerp(here[2], there[2], running/d)
         table.insert(result, {x,y, {1,0,1}})

         running = running + spacing
      end

      if running >= d then
         running = running - d
         return evenlySpreadPath(result, path, index+1, running, spacing)
      end
   end


end

function getLengthOfPath(path)
   local result = 0
   for i = 1, #path-1 do
      local a = path[i]
      local b = path[i+1]
      result = result + getDistance(a[1], a[2], b[1], b[2])

   end
   return result
end


function getDistance(x1,y1,x2,y2)
   local dx = x1 - x2
   local dy = y1 - y2
   local distance =  math.sqrt ((dx*dx) + (dy*dy))

   return distance
end


--https://love2d.org/forums/viewtopic.php?t=1401
function GetSplinePos(tab, percent, tension)		--returns the position at 'percent' distance along the spline.
   if(tab and (#tab >= 4)) then
      local pos = (((#tab)/2) - 1) * percent
      local lowpnt, percent_2 = math.modf(pos)

      local i = (1+lowpnt*2)
      local p1x = tab[i]
      local p1y = tab[i+1]
      local p2x = tab[i+2]
      local p2y = tab[i+3]

      local p0x = tab[i-2]
      local p0y = tab[i-1]
      local p3x = tab[i+4]
      local p3y = tab[i+5]

      local tension = tension or .5
      local t1x = 0
      local t1y = 0
      if(p0x and p0y) then
         t1x = (1.0 - tension) * (p2x - p0x)
         t1y =  (1.0 - tension) * (p2y - p0y)
      end
      local t2x = 0
      local t2y = 0
      if(p3x and p3y) then
         t2x =  (1.0 - tension) * (p3x - p1x)
         t2y =  (1.0 - tension) * (p3y - p1y)
      end

      local s = percent_2
      local s2 = s*s
      local s3 = s*s*s
      local h1 = 2*s3 - 3*s2 + 1
      local h2 = -2*s3 + 3*s2
      local h3 = s3 - 2*s2 + s
      local h4 = s3 - s2
      local px = (h1*p1x) + (h2*p2x) + (h3*t1x) + (h4*t2x)
      local py = (h1*p1y) + (h2*p2y) + (h3*t1y) + (h4*t2y)

      return px, py
   end
end


--   -- https://stackoverflow.com/questions/24907476/how-to-get-a-fixed-number-of-evenly-spaced-points-describing-a-path
--       function evenlyDistributeOnPath(path)
--       local totalLength = 0
--       for i =1, #path do
--          local here = path[i]
--          local nextIndex = i == #path and 1 or i+1
--          local there = path[nextIndex]
--          totalLength = totalLength + getDistance(here[1], here[2], there[1], there[2])
--       end

--       -- i want a thing every 10 distance
--       local spacing = 10
--       local lengthBetween = totalLength / spacing
--       local output = {}

--       local runningTotal = 0
--       local runningPart = 0


--       local lookingAtIndex = 1

--       local done = false
--       while  lookingAtIndex < #path and (done ~= true)  do
--          --print(runningTotal)
--          --print(lookingAtIndex, #path)
--          local here = path[lookingAtIndex]
--          local nextIndex = lookingAtIndex == #path and 1 or lookingAtIndex+1
--          local there = path[nextIndex]

--          local d = getDistance(here[1], here[2], there[1], there[2])

--          if runningPart > d then
--             runningPart = runningPart - d
--             lookingAtIndex = lookingAtIndex + 1

--             if lookingAtIndex <= #path then
--                here = path[lookingAtIndex]
--                nextIndex = lookingAtIndex == #path and 1 or lookingAtIndex+1
--                there =path[nextIndex]
--                d = getDistance(here[1], here[2], there[1], there[2])
--             end
--          end
--          --if lookingAtIndex == #path then
--          if #output > 2 then -- this is an early exit
--             local d = getDistance(path[1][1],path[1][2],
--                                   output[#output][1],output[#output][2] )
--             if d < spacing then
--                done = true
--             end

--          end

--          if not done then
--             local x = lerp(here[1], there[1], runningPart/d)
--             local y = lerp(here[2], there[2], runningPart/d)

--             table.insert(output, {x,y})

--             runningPart = runningPart + spacing
--             runningTotal = runningTotal + spacing
--          end

--       end

--       return output
--       end

-- function experiment(work)
--    local verts, indices, draw_mode = polyline('bevel',work, 3 , 0, false)
--       --print(indices, draw_mode, inspect(verts))
--       love.graphics.setColor(1,1,1)
--       local mesh = love.graphics.newMesh(simple_format, verts, draw_mode)

--       love.graphics.draw(mesh, currentNode._parent.transforms._g)

--       love.graphics.setColor(1,0,0)
--       love.graphics.setLineWidth(1)


--       local withTexture = {}
--       for i = 1, #currentNode.points do
--          local here = currentNode.points[i]
--          local thereIndex
--          if i == #currentNode.points then
--             thereIndex = 1
--          else
--             thereIndex = i+1
--          end
--          local there = currentNode.points[thereIndex]


--          function addPoints(container, here, there)
--             --local there = currentNode.points[thereIndex]
--             local angle, distance = getAngleAndDistance(there[1],there[2], here[1], here[2])
--             local perpAngle = angle - math.pi/2


--             local j = 0
--             while j < distance do
--                local xx = here[1] +  (j * math.cos(angle))
--                local yy = here[2] +  (j * math.sin(angle))
--                local offset = 25 * math.random()
--                xx = xx + math.cos(perpAngle) * offset
--                yy = yy + math.sin(perpAngle) * offset
--                table.insert(container, {xx, yy, 3})

--                j = j +  love.math.random()*1
--             end
--          end
--          addPoints(withTexture, here, there)

--          if i <= #currentNode.points then

--             local next = there
--             local afterIndex = (thereIndex+1) > #currentNode.points and 1 or  (thereIndex+1)
--             local after = currentNode.points[afterIndex]
--             local angle, distance = getAngleAndDistance(after[1],after[2], next[1], next[2])
--             local perpAngle = angle - math.pi/2
--             --print(i, thereIndex, afterIndex)


--             local xx = there[1]
--             local yy = there[2]
--             local offset = 5 --12.5 * math.random()
--             xx = xx + math.cos(perpAngle) * offset
--             yy = yy + math.sin(perpAngle) * offset

--             addPoints(withTexture, withTexture[#withTexture], {xx,yy})
--             -- love.graphics.line(100 + withTexture[#withTexture][1],
--             --                    100 + withTexture[#withTexture][2],
--             --                    100 + xx,
--             --                    100 + yy)

--          else
-- --            print(i)
--          end


--          --table.insert(withTexture, {there[1], there[2], love.math.random()* 2})
--       end



--       for i = 1, #withTexture do
--          love.graphics.circle('fill',100 +  withTexture[i][1], 100 +  withTexture[i][2], withTexture[i][3])
--       end
-- end


function gaussian(mean, stdev)
   -- TODO get rid of returning a function, just return the result already
   local y2
   local use_last = false
   return function()
      local y1
      if (use_last) then
         y1 = y2
         use_last = false
      else
         local x1=0
         local x2=0
         local w=0
         x1 = 2.0 * love.math.random() - 1.0
         x2 = 2.0 * love.math.random() - 1.0
         w  = x1 * x1 + x2 * x2
         while( w >= 1.0) do
             x1 = 2.0 * love.math.random() - 1.0
             x2 = 2.0 * love.math.random() - 1.0
             w  = x1 * x1 + x2 * x2
         end
          w = math.sqrt((-2.0 * math.log(w))/w)
          y1 = x1 * w
          y2 = x2 * w
          use_last = true
      end
      local retval = mean + stdev * y1
      if (retval > 0) then return retval end
      return -retval
   end
end

function clip(value, min, max)
   if (min > max) then return value
   elseif (value < min) then return min
   elseif (value > max) then return max
   else return value end
end

function generatePolygon(ctrX, ctrY, aveRadius, irregularity, spikeyness, numVerts)
   irregularity = clip( irregularity, 0,1 ) * 2 * math.pi / numVerts
   spikeyness = clip( spikeyness, 0,1 ) * aveRadius
   angleSteps = {}
   lower = (2 * math.pi / numVerts) - irregularity
   upper = (2 * math.pi / numVerts) + irregularity
   sum = 0

   for i=0,numVerts-1 do
      local tmp =lower +  love.math.random()*(upper-lower)
      angleSteps[i] = tmp;
      sum = sum + tmp;
   end

   k = sum / (2 * math.pi)
   for i=0,numVerts-1 do
      angleSteps[i] = angleSteps[i] / k
   end

   points = {}
   angle = love.math.random()*(2.0*math.pi)
   for i=0,numVerts-1 do
      r_i = clip(gaussian(aveRadius, spikeyness)(), 0, 2*aveRadius)
      x = ctrX + r_i * math.cos(angle)
      y = ctrY + r_i * math.sin(angle)
      points[1 + i * 2 + 0] = math.floor(x)
      points[1 + i * 2 + 1] = math.floor(y)
      angle = angle + angleSteps[i]
   end
   return points
end

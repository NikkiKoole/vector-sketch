local numbers = require 'lib.numbers'
local geom = require 'lib.geom'

function makeParallelLine(line, offset)
   local x1 = line[1]
   local y1 = line[2]
   local x2 = line[3]
   local y2 = line[4]
   local L = math.sqrt((x1-x2)*(x1-x2)+(y1-y2)*(y1-y2))

   local x1p = x1 + offset * (y2-y1)/L
   local x2p = x2 + offset * (y2-y1)/L
   local y1p = y1 + offset * (x1-x2)/L
   local y2p = y2 + offset * (x1-x2)/L
   return {x1p, y1p, x2p, y2p}

end

function isectLineLine(line1, line2)
   local ax = line1[1]
   local bx = line1[3]
   local cx = line2[1]
   local dx = line2[3]
   
   local ay = line1[2]
   local by = line1[4]
   local cy = line2[2]
   local dy = line2[4]
   
   local dx12 = ax - bx;
   local dx34 = cx - dx;
   local dy12 = ay - by;
   local dy34 = cy - dy;
   local den = dx12 * dy34 - dy12 * dx34;
   local EPSILON = 0.000001
   
   if (math.abs(den) < EPSILON) then
      return nil
   else 
      local det12 = ax * by - ay * bx
      local det34 = cx * dy - cy * dx
      local numx = det12 * dx34 - dx12 * det34
      local numy = det12 * dy34 - dy12 * det34
      return {x= numx / den, y= numy / den}
   end
end

function connectAtIntersection(l1, l2)
   local i1 = isectLineLine(l1, l2)
   if (i1 ~= nil) then
      l1[3] = i1.x
      l1[4] = i1.y
      l2[1] = i1.x
      l2[2] = i1.y
   end
end

---
-- @rect {x1,y1,x2,y2,x3,y3,x4,y4}
-- @uvData  {tlx, tly, width, height} all in 1.0 unit
-- for example {.05, .08, .92, .8}
-- here the actual border of the image lies at .05 from the left, .08 from the top, and the width/height is clear.
function coloredOutsideTheLines(rect, uvData)
   local lerp = numbers.lerp
   
   local hx1 = lerp(rect[1], rect[7], 0.5)
   local hy1 = lerp(rect[2], rect[8], 0.5)
   local hx2 = lerp(rect[3], rect[5], 0.5)
   local hy2 = lerp(rect[4], rect[6], 0.5)

   local vx1 = lerp(rect[1], rect[3], 0.5)
   local vy1 = lerp(rect[2], rect[4], 0.5)
   local vx2 = lerp(rect[7], rect[5], 0.5)
   local vy2 = lerp(rect[8], rect[6], 0.5)

   local vertd = (geom.distance(vx1, vy1, vx2, vy2))
   local totalv = 1/uvData[4] * vertd
   
   local topOff = uvData[2] * totalv
   local bottomOff = (1-(uvData[4]+uvData[2])) * totalv

   local pTop = makeParallelLine({rect[1], rect[2], rect[3], rect[4]}, topOff)
   local pBottom = makeParallelLine({ rect[5], rect[6], rect[7], rect[8]}, bottomOff)

   local hord = (geom.distance(hx1, hy1, hx2, hy2))
   local totalh = 1/uvData[3] * hord
   local leftOff = uvData[1] * totalh
   local rightOff = (1-(uvData[3]+uvData[1])) * totalh
   
   local pLeft = makeParallelLine({ rect[7], rect[8], rect[1], rect[2]}, leftOff)
   local pRight = makeParallelLine({ rect[3], rect[4], rect[5], rect[6]}, rightOff)
   
  
   connectAtIntersection(pTop, pRight)
   connectAtIntersection(pRight, pBottom)
   connectAtIntersection(pBottom, pLeft)
   connectAtIntersection(pLeft, pTop)

   return {pTop[1], pTop[2], pRight[1], pRight[2], pBottom[1], pBottom[2], pLeft[1], pLeft[2]}
end

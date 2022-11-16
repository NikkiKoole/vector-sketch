local numbers = require 'lib.numbers'
local geom = {}


geom.distance = function(x1, y1, x2, y2)
   local nx = x2 - x1
   local ny = y2 - y1
   return math.sqrt(nx * nx + ny * ny)
end

geom.getPerpOfLine = function(x1, y1, x2, y2)
   local nx = x2 - x1
   local ny = y2 - y1
   local len = math.sqrt(nx * nx + ny * ny)
   nx = nx / len
   ny = ny / len
   return ny, nx
end

geom.lerpLine = function(x1, y1, x2, y2, t)
   return { x = numbers.lerp(x1, x2, t), y = numbers.lerp(y1, y2, t) }
end

geom.positionControlPoints = function(start, eind, hoseLength, flop, borderRadius)
   local pxm, pym = geom.getPerpOfLine(start.x, start.y, eind.x, eind.y)
   pxm = pxm * flop
   pym = pym * -flop
   local d = geom.distance(start.x, start.y, eind.x, eind.y)
   local b = geom.getEllipseWidth(hoseLength / math.pi, d)
   local perpL = b / 2 -- why am i dividing this?

   local sp2 = geom.lerpLine(start.x, start.y, eind.x, eind.y, borderRadius)
   local ep2 = geom.lerpLine(start.x, start.y, eind.x, eind.y, 1 - borderRadius)

   local startP = { x = sp2.x + (pxm * perpL), y = sp2.y + (pym * perpL) }
   local endP = { x = ep2.x + (pxm * perpL), y = ep2.y + (pym * perpL) }
   return startP, endP
end


geom.calculateLargestRect = function(angle, origWidth, origHeight)
   local w0, h0;
   if (origWidth <= origHeight) then
      w0 = origWidth;
      h0 = origHeight;

   else
      w0 = origHeight;
      h0 = origWidth;
   end

   --// Angle normalization in range [-PI..PI)
   local ang = angle - math.floor((angle + math.pi) / (2 * math.pi)) * 2 * math.pi;
   ang = math.abs(ang);
   if (ang > math.pi / 2) then
      ang = math.pi - ang
   end

   local sina = math.sin(ang);
   local cosa = math.cos(ang);
   local sinAcosA = sina * cosa;
   local w1 = w0 * cosa + h0 * sina;
   local h1 = w0 * sina + h0 * cosa;
   local c = h0 * sinAcosA / (2 * h0 * sinAcosA + w0);
   local x = w1 * c;
   local y = h1 * c;
   local w, h;
   if (origWidth <= origHeight) then
      w = w1 - 2 * x;
      h = h1 - 2 * y;

   else
      w = h1 - 2 * y;
      h = w1 - 2 * x;
   end

   return x, y, w, h
end


--function getEllipseCircumference(w, h)
--   return 2 * math.pi * math.sqrt(((w*w) + (h*h))/2)
--end

geom.getEllipseWidth = function(circumf, h)
   return math.sqrt((circumf * circumf) - (2 * (h * h))) / math.sqrt(2)
end

--function getEllipseWidth2(c, a)
--   return  math.sqrt((((c/(2* math.pi))^2)*2) - a^2)
--end


local function makeParallelLine(line, offset)
   local x1 = line[1]
   local y1 = line[2]
   local x2 = line[3]
   local y2 = line[4]
   local L = math.sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2))

   local x1p = x1 + offset * (y2 - y1) / L
   local x2p = x2 + offset * (y2 - y1) / L
   local y1p = y1 + offset * (x1 - x2) / L
   local y2p = y2 + offset * (x1 - x2) / L
   return { x1p, y1p, x2p, y2p }

end

local function isectLineLine(line1, line2)
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
      return { x = numx / den, y = numy / den }
   end
end

local function connectAtIntersection(l1, l2)
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
geom.coloredOutsideTheLines = function(rect, uvData)
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
   local totalv = 1 / uvData[4] * vertd

   local topOff = uvData[2] * totalv
   local bottomOff = (1 - (uvData[4] + uvData[2])) * totalv

   local pTop = makeParallelLine({ rect[1], rect[2], rect[3], rect[4] }, topOff)
   local pBottom = makeParallelLine({ rect[5], rect[6], rect[7], rect[8] }, bottomOff)

   local hord = (geom.distance(hx1, hy1, hx2, hy2))
   local totalh = 1 / uvData[3] * hord
   local leftOff = uvData[1] * totalh
   local rightOff = (1 - (uvData[3] + uvData[1])) * totalh

   local pLeft = makeParallelLine({ rect[7], rect[8], rect[1], rect[2] }, leftOff)
   local pRight = makeParallelLine({ rect[3], rect[4], rect[5], rect[6] }, rightOff)


   connectAtIntersection(pTop, pRight)
   connectAtIntersection(pRight, pBottom)
   connectAtIntersection(pBottom, pLeft)
   connectAtIntersection(pLeft, pTop)

   return { pTop[1], pTop[2], pRight[1], pRight[2], pBottom[1], pBottom[2], pLeft[1], pLeft[2] }
end


return geom

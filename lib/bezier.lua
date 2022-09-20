
local bezier = {}
local geom = require 'lib.geom'

bezier.positionControlPoints = function(start, eind, hoseLength, flop, borderRadius)
   local pxm,pym = geom.getPerpOfLine(start.x,start.y, eind.x, eind.y)
   pxm = pxm * flop
   pym = pym * -flop
   local d = geom.distance(start.x,start.y, eind.x, eind.y)
   local b = geom.getEllipseWidth(hoseLength/math.pi, d)
   local perpL = b /2 -- why am i dividing this?

   local sp2 = geom.lerpLine(start.x,start.y, eind.x, eind.y, borderRadius)
   local ep2 = geom.lerpLine(start.x,start.y, eind.x, eind.y, 1 - borderRadius)

   local startP = {x= sp2.x +(pxm*perpL), y= sp2.y + (pym*perpL)}
   local endP = {x= ep2.x +(pxm*perpL), y= ep2.y + (pym*perpL)}
   return startP, endP
end

return bezier

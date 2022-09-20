local numbers = require 'lib.numbers'
local geom = {}


geom.distance = function(x1,y1,x2,y2)
   local nx = x2 - x1
   local ny = y2 - y1
   return math.sqrt(nx * nx + ny * ny)
end

geom.getPerpOfLine = function(x1,y1,x2,y2)
    local nx = x2 - x1
    local ny = y2 - y1
    local len = math.sqrt(nx * nx + ny * ny)
    nx = nx/len
    ny = ny/len
    return ny, nx
end

geom.lerpLine = function(x1,y1, x2,y2, t)
   return {x=numbers.lerp(x1, x2, t), y= numbers.lerp(y1, y2, t)}
end


--function getEllipseCircumference(w, h)
--   return 2 * math.pi * math.sqrt(((w*w) + (h*h))/2)
--end

geom.getEllipseWidth = function(circumf, h)
   return math.sqrt((circumf*circumf) - (2* (h*h))) / math.sqrt(2)
end

--function getEllipseWidth2(c, a)
--   return  math.sqrt((((c/(2* math.pi))^2)*2) - a^2)
--end

return geom

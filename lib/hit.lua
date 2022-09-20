local hit = {}

hit.pointInCircle = function(x,y, cx, cy, cr)
   local dx = x - cx
   local dy = y - cy
   local d  = math.sqrt ((dx*dx) + (dy*dy))

   return cr > d
end

hit.pointInEllipse = function(px, py, cx, cy, rx, ry, rotation)
    local rotation = rotation or 0
    local cos = math.cos(rotation)
    local sin = math.sin(rotation)
    local dx  = (px - cx)
    local dy  = (py - cy)
    local tdx = cos * dx + sin * dy
    local tdy = sin * dx - cos * dy

    return (tdx * tdx) / (rx * rx) + (tdy * tdy) / (ry * ry) <= 1;
end

hit.pointInRect = function(x,y, rx, ry, rw, rh)
   if x < rx or y < ry then return false end
   if x > rx+rw or y > ry+rh then return false end
   return true
end


return hit

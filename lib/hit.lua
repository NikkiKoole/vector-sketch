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


local function signT(p1, p2, p3)
   return (p1[1] - p3[1]) * (p2[2] - p3[2]) - (p2[1] - p3[1]) * (p1[2] - p3[2])
end

hit.pointInTriangle = function(p, t1, t2, t3)
   local b1, b2, b3
   b1 = signT(p, t1, t2) < 0.0
   b2 = signT(p, t2, t3) < 0.0
   b3 = signT(p, t3, t1) < 0.0

   return ((b1 == b2) and (b2 == b3))
end

hit.pointInMesh = function(mx, my, body, mesh)

   if mesh and body then
      local count = mesh:getVertexCount()
      if body.transforms._g then
         local px, py = body.transforms._g:inverseTransformPoint(mx, my)
         for i = 1, count, 3 do
            if i + 2 <= count then
               if hit.pointInTriangle({ px, py }, { mesh:getVertex(i) }, { mesh:getVertex(i + 1) }, { mesh:getVertex(i + 2) }) then
                  return true
               end
            end

         end
      end
   end
   return false
end

hit.recursiveHitCheck = function(x, y, node)
   -- you want to check the first child IF IT HAS POINTS
   if not node then return false end

   if node.points then
      local body = node
      local mesh = body.mesh
      if (body and mesh) then
         if hit.pointInMesh(x, y, body._parent, mesh) then
            -- imma looking for hitareas
            if string.find(node.name, "-hitarea") then
               return node.name
            else
               return true
            end

         end
      end
   else
      if node.optimizedBatchMesh then
         for i = 1, #node.optimizedBatchMesh do
            if hit.pointInMesh(x, y, node, node.optimizedBatchMesh[i].mesh) then
               return true
            end
         end

      elseif node.children then
         local result = false
         for i = 1, #node.children do
            local result = hit.recursiveHitCheck(x, y, node.children[i])
            if result then
               return result
            end
         end
      end
   end
   return false
end


return hit

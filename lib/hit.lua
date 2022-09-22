local hit = {}

hit.pointInCircle = function(x, y, cx, cy, cr)
   local dx = x - cx
   local dy = y - cy
   local d  = math.sqrt((dx * dx) + (dy * dy))

   return cr > d
end

hit.pointInEllipse = function(px, py, cx, cy, rx, ry, rotation)
   local rotation = rotation or 0
   local cos      = math.cos(rotation)
   local sin      = math.sin(rotation)
   local dx       = (px - cx)
   local dy       = (py - cy)
   local tdx      = cos * dx + sin * dy
   local tdy      = sin * dx - cos * dy

   return (tdx * tdx) / (rx * rx) + (tdy * tdy) / (ry * ry) <= 1;
end

hit.pointInRect = function(x, y, rx, ry, rw, rh)
   if x < rx or y < ry then return false end
   if x > rx + rw or y > ry + rh then return false end
   return true
end

hit.pointInPath = function(x, y, poly)
   local num = #poly
   local j = num - 1
   local c = false
   for i = 1, #poly, 2 do
      if ((poly[i + 1] > y) ~= (poly[j + 1] > y)) and
          (x < (poly[j + 0] - poly[i + 0]) * (y - poly[i + 1]) / (poly[j + 1] - poly[i + 1]) + poly[i + 0]) then
         c = not c
      end
      j = i
   end
   return c
end

hit.findMeshThatsHit = function(parent, mx, my, order)
   -- order decides which way we will walk,
   -- order = false will return the firts hitted one (usually below everything)
   -- order = true will return the last hitted
   local result = nil
   for i = 1, #parent.children do
      if parent.children[i].children then
         if order then
            local temp = hit.findMeshThatsHit(parent.children[i], mx, my, order)
            if temp then
               result = temp
            end
         else
            return hit.findMeshThatsHit(parent.children[i], mx, my, order)
         end

      else

         local hitted = hit.pointInMesh(mx, my, parent, parent.children[i].mesh)
         if hitted then
            if order then
               result = parent.children[i]
            else
               return parent.children[i]
            end
         end
      end
   end
   if (order) then
      return result
   else
      return nil
   end
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
               if hit.pointInTriangle({ px, py }, { mesh:getVertex(i) }, { mesh:getVertex(i + 1) },
                  { mesh:getVertex(i + 2) }) then
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


hit.findHitArea = function(node)
   if not node then return false end
   print('recusricve looking', node.name)

   if node.points then
      if string.find(node.name, "-hitarea") then
         return true
      end

   else
      if node.children then
         for i = 1, #node.children do
            local result = hit.findHitArea(node.children[i])
            if result then
               return result
            end
         end
      end
   end
   return false
end



return hit

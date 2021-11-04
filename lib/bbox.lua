

function getPointsBBox(points)
   local tlx = 9999999999
   local tly = 9999999999
   local brx = -9999999999
   local bry = -9999999999
   for ip=1, #points do
      if points[ip][1] < tlx then tlx = points[ip][1] end
      if points[ip][1] > brx then brx = points[ip][1] end
      if points[ip][2] < tly then tly = points[ip][2] end
      if points[ip][2] > bry then bry = points[ip][2] end
   end
   return tlx, tly, brx, bry
end

function getBBoxRecursive(node)
   if node.children then
      setTransforms(node)
      -- first try to get as deep as possible
      local p1 = {math.huge, math.huge, -math.huge, -math.huge}
      for i = 1, #node.children do
         if node.children[i].folder then
            local r= getBBoxRecursive(node.children[i])
            --print('r', inspect(r))
            if r[1] < p1[1] then p1[1] = r[1] end
            if r[2] < p1[2] then p1[2] = r[2] end
            if r[3] > p1[3] then p1[3] = r[3] end
            if r[4] > p1[4] then p1[4] = r[4] end
         end
      end

      local p2 = {math.huge, math.huge, -math.huge, -math.huge}
      for i = 1, #node.children do
         if node.children[i].points then
            --local r = getBBoxR2(node.children[i])
            local tlx, tly, brx, bry = getPointsBBox(node.children[i].points)
            if tlx < p2[1] then p2[1] = tlx end
            if tly < p2[2] then p2[2] = tly end
            if brx > p2[3] then p2[3] = brx end
            if bry > p2[4] then p2[4] = bry end

         end
      end
      local tlxg , tlyg = node.transforms._g:transformPoint(p2[1], p2[2])
      local brxg , bryg = node.transforms._g:transformPoint(p2[3], p2[4])

      return {math.min(tlxg, p1[1]),
              math.min(tlyg, p1[2]),
              math.max(brxg, p1[3]),
              math.max(bryg, p1[4])}


   end


end


function getDirectChildrenBBox(node)
   local tlx = 9999999999
   local tly = 9999999999
   local brx = -9999999999
   local bry = -9999999999

   for i=1, #node.children do
      local points = node.children[i].points
      if points then
         for ip=1, #points do
            if points[ip][1] < tlx then tlx = points[ip][1] end
            if points[ip][1] > brx then brx = points[ip][1] end
            if points[ip][2] < tly then tly = points[ip][2] end
            if points[ip][2] > bry then bry = points[ip][2] end
         end
      end
   end

   if ( tlx == 9999999999 and tly == 9999999999 and brx == -9999999999 and bry == -9999999999) then
      print('no direct children you pancake!')
      return 0,0,0,0
   else
      return tlx, tly, brx, bry
   end

end

function getGroupBBox(group)
   local tlx = math.huge
   local tly = math.huge
   local brx = -math.huge
   local bry = -math.huge
   for i = 1, #group do

      if group[i].points then
         local tlx2, tly2, brx2, bry2 = getPointsBBox(group[i].points)
         if tlx2 < tlx then
            tlx = tlx2
         end
         if tly2 < tly then
            tly = tly2
         end
         if brx2 > brx then
            brx = brx2
         end
         if bry2 > bry then
            bry = bry2
         end
      end
   end

   return tlx, tly, brx, bry
end


function getBBoxOfChildren(children)
   local minX = math.huge
   local minY = math.huge
   local maxX = -math.huge
   local maxY = -math.huge

   for i = 1, #children do
      local c = children[i]
      if c.points then
         for ip = 1, #c.points do
            if c.points[ip][1] < minX then minX =  c.points[ip][1]  end
            if c.points[ip][1] > maxX then maxX =  c.points[ip][1]  end
            if c.points[ip][2]  < minY then minY =  c.points[ip][2]  end
            if c.points[ip][2]  > maxY then maxY =  c.points[ip][2]  end
         end
      end
   end

   return {tl = {x=minX, y=minY}, br={x=maxX, y=maxY}}
end

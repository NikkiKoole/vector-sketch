

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

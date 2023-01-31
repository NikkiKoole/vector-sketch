local bbox = {}

local transform = require 'lib.transform'


--[[
local function getScreenBBoxForItem(c, bbox)

   local stlx, stly = c.transforms._g:transformPoint(bbox[1], bbox[2])
   local strx, stry = c.transforms._g:transformPoint(bbox[3], bbox[2])
   local sblx, sbly = c.transforms._g:transformPoint(bbox[1], bbox[4])
   local sbrx, sbry = c.transforms._g:transformPoint(bbox[3], bbox[4])

   local tlx, tly = cam:getScreenCoordinates(stlx, stly)
   local brx, bry = cam:getScreenCoordinates(sbrx, sbry)
   local trx, try = cam:getScreenCoordinates(strx, stry)
   local blx, bly = cam:getScreenCoordinates(sblx, sbly)

   local smallestX = math.min(tlx, brx, trx, blx)
   local smallestY = math.min(tly, bry, try, bly)
   local biggestX = math.max(tlx, brx, trx, blx)
   local biggestY = math.max(tly, bry, try, bly)

   return smallestX, smallestY, biggestX, biggestY

end
--]]

bbox.getPointsBBox = function(points)
   local tlx = math.huge
   local tly = math.huge
   local brx = -math.huge
   local bry = -math.huge
   for ip = 1, #points do
      if points[ip][1] < tlx then tlx = points[ip][1] end
      if points[ip][1] > brx then brx = points[ip][1] end
      if points[ip][2] < tly then tly = points[ip][2] end
      if points[ip][2] > bry then bry = points[ip][2] end
   end
   return tlx, tly, brx, bry
end

bbox.getMiddleOfPoints = function(points)
   local tlx, tly, brx, bry = bbox.getPointsBBox(points)
   return tlx + (brx - tlx) / 2, tly + (bry - tly) / 2
end
bbox.getMiddleOfContainer = function(container)
   local bb                 = bbox.getBBoxRecursive(container)
   local tlx, tly, brx, bry = bb[1], bb[2], bb[3], bb[4]
   -- returns middle but also w and h
   return tlx + (brx - tlx) / 2, tly + (bry - tly) / 2, brx - tlx, bry - tly
end
bbox.getMiddleAndDimsOfBBox = function(tlx, tly, brx, bry)
   return tlx + (brx - tlx) / 2, tly + (bry - tly) / 2, brx - tlx, bry - tly
end

bbox.combineBboxes = function(...)
   local tlx = math.huge
   local tly = math.huge
   local brx = -math.huge
   local bry = -math.huge

   local args = { ... }
   --print(#args)

   for j = 1, #args do

      local v = args[j]

      for i = 1, #v do

         if v[i] < tlx then tlx = v[i] end
         if v[i] > brx then brx = v[i] end
         if v[i] < tly then tly = v[i] end
         if v[i] > bry then bry = v[i] end
      end
   end
   return tlx, tly, brx, bry
end

bbox.getPointsBBoxFlat = function(points)
   local tlx = 9999999999
   local tly = 9999999999
   local brx = -9999999999
   local bry = -9999999999
   for ip = 1, #points, 2 do
      if points[ip + 0] < tlx then tlx = points[ip + 0] end
      if points[ip + 0] > brx then brx = points[ip + 0] end
      if points[ip + 1] < tly then tly = points[ip + 1] end
      if points[ip + 1] > bry then bry = points[ip + 1] end
   end
   return tlx, tly, brx, bry
end

-- this works better fro hittesting the drawn figures,
bbox.getBBoxRecursiveVersion2 = function(node)
   if node.children then
      transform.setTransforms(node)
      local p2 = { math.huge, math.huge, -math.huge, -math.huge }

      for i = 1, #node.children do
         if node.children[i].points then
            local tlx, tly, brx, bry = bbox.getPointsBBox(node.children[i].points)
            if tlx < p2[1] then p2[1] = tlx end
            if tly < p2[2] then p2[2] = tly end
            if brx > p2[3] then p2[3] = brx end
            if bry > p2[4] then p2[4] = bry end
         end
      end

      local tlxg, tlyg = node.transforms._g:transformPoint(p2[1], p2[2])
      local brxg, bryg = node.transforms._g:transformPoint(p2[3], p2[4])
      return { tlxg, tlyg, brxg, bryg }


   end
end

-- i havent looked deeply in all places where this is used to see if the version2 above would work better
bbox.getBBoxRecursive = function(node)
   if node.children then
      transform.setTransforms(node)
      -- first try to get as deep as possible
      local p1 = { math.huge, math.huge, -math.huge, -math.huge }
      -- -- [[]]
      for i = 1, #node.children do
         if node.children[i].folder then
            local r = bbox.getBBoxRecursive(node.children[i])
            --print('r', inspect(r))
            if r[1] < p1[1] then p1[1] = r[1] end
            if r[2] < p1[2] then p1[2] = r[2] end
            if r[3] > p1[3] then p1[3] = r[3] end
            if r[4] > p1[4] then p1[4] = r[4] end
         end
      end
      --  --]]
      local p2 = { math.huge, math.huge, -math.huge, -math.huge }

      for i = 1, #node.children do
         if node.children[i].points then
            local tlx, tly, brx, bry = bbox.getPointsBBox(node.children[i].points)
            if tlx < p2[1] then p2[1] = tlx end
            if tly < p2[2] then p2[2] = tly end
            if brx > p2[3] then p2[3] = brx end
            if bry > p2[4] then p2[4] = bry end
         end
      end

      local tlxg, tlyg = node.transforms._g:transformPoint(p2[1], p2[2])
      local brxg, bryg = node.transforms._g:transformPoint(p2[3], p2[4])

      return { math.min(tlxg, p1[1]),
         math.min(tlyg, p1[2]),
         math.max(brxg, p1[3]),
         math.max(bryg, p1[4]) }


   else
      print('what is this for a thing')
      print(node.name, #node.points)
   end


end


bbox.transformFromParent = function(node, bb)
   local tlxg, tlyg = node._parent.transforms._g:inverseTransformPoint(bb[1], bb[2])
   local brxg, bryg = node._parent.transforms._g:inverseTransformPoint(bb[3], bb[4])

   return { tlxg, tlyg, brxg, bryg }
end

--[[
bbox.getBBoxRecursiveTransformed = function(node)
   if node.children then
      --transform.setTransforms(node)
      -- first try to get as deep as possible
      local p1 = { math.huge, math.huge, -math.huge, -math.huge }
      for i = 1, #node.children do
         if node.children[i].folder then
            local r = bbox.getBBoxRecursiveTransformed(node.children[i])
            --print('r', inspect(r))
            if r[1] < p1[1] then p1[1] = r[1] end
            if r[2] < p1[2] then p1[2] = r[2] end
            if r[3] > p1[3] then p1[3] = r[3] end
            if r[4] > p1[4] then p1[4] = r[4] end
         end
      end

      local p2 = { math.huge, math.huge, -math.huge, -math.huge }
      for i = 1, #node.children do
         if node.children[i].points then
            --local r = getBBoxR2(node.children[i])
            local tlx, tly, brx, bry = bbox.getPointsBBox(node.children[i].points)
            if tlx < p2[1] then p2[1] = tlx end
            if tly < p2[2] then p2[2] = tly end
            if brx > p2[3] then p2[3] = brx end
            if bry > p2[4] then p2[4] = bry end

         end
      end

      local pp = { math.min(p2[1], p1[1]),
         math.min(p2[2], p1[2]),
         math.max(p2[3], p1[3]),
         math.max(p2[4], p1[4]) }

      return pp
   end
end
--]]


bbox.drillDownForFirstBBox = function(node)
   -- local tlx, tly, brx, bry = bbox.getDirectChildrenBBox(node)
   -- if (tlx == math.huge and tly == math.huge and brx == -math.huge and bry == -math.huge) then
   for i = 1, #node.children do
      local tlx, tly, brx, bry = bbox.getDirectChildrenBBox(node.children[i])
      if (tlx ~= math.huge and tly ~= math.huge and brx ~= -math.huge and bry ~= -math.huge) then
         return tlx, tly, brx, bry
      end
   end
   --- else
   --    return tlx, tly, brx, bry
   -- end
end

bbox.getDirectChildrenBBox = function(node)
   local tlx = math.huge
   local tly = math.huge
   local brx = -math.huge
   local bry = -math.huge

   for i = 1, #node.children do
      local points = node.children[i].points
      if points then
         for ip = 1, #points do
            if points[ip][1] < tlx then tlx = points[ip][1] end
            if points[ip][1] > brx then brx = points[ip][1] end
            if points[ip][2] < tly then tly = points[ip][2] end
            if points[ip][2] > bry then bry = points[ip][2] end
         end
      end
   end

   if (tlx == math.huge and tly == math.huge and brx == -math.huge and bry == -math.huge) then
      print('no direct children you pancake!')
      -- todo make a simpler drilling down algo
      if node.children then
         local tlx, tly, brx, bry = bbox.drillDownForFirstBBox(node)
         return tlx, tly, brx, bry
      else
         return 0, 0, 0, 0, 0
      end
      -- return 0, 0, 0, 0
   else
      return tlx, tly, brx, bry
   end

end

bbox.getGroupBBox = function(group)
   local tlx = math.huge
   local tly = math.huge
   local brx = -math.huge
   local bry = -math.huge
   for i = 1, #group do

      if group[i].points then
         local tlx2, tly2, brx2, bry2 = bbox.getPointsBBox(group[i].points)
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

bbox.getBBoxOfChildren = function(children)
   local minX = math.huge
   local minY = math.huge
   local maxX = -math.huge
   local maxY = -math.huge

   for i = 1, #children do
      local c = children[i]
      if c.points then
         for ip = 1, #c.points do
            if c.points[ip][1] < minX then minX = c.points[ip][1] end
            if c.points[ip][1] > maxX then maxX = c.points[ip][1] end
            if c.points[ip][2] < minY then minY = c.points[ip][2] end
            if c.points[ip][2] > maxY then maxY = c.points[ip][2] end
         end
      end
   end

   return { tl = { x = minX, y = minY }, br = { x = maxX, y = maxY } }
end

return bbox

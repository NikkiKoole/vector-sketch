local mesh = {}

local formats = require 'lib.formats'
local bezier = require 'lib.bezier'
local unloop = require 'lib.unpack-points'
local hit = require 'lib.hit'
require 'lib.basics' --tableconcat

-- todo @global imageCache

local function split_poly(poly, intersection)
   local biggestIndex = math.max(intersection.i1, intersection.i2)
   local smallestIndex = math.min(intersection.i1, intersection.i2)
   local wrap = {}
   local bb = biggestIndex

   while bb ~= smallestIndex do
      bb = bb + 2
      if bb > #poly - 1 then
         bb = 1
      end
      table.insert(wrap, poly[bb])
      table.insert(wrap, poly[bb + 1])
   end

   table.insert(wrap, intersection.x)
   table.insert(wrap, intersection.y)

   local back = {}
   local bk = biggestIndex

   while bk ~= smallestIndex do
      table.insert(back, poly[bk])
      table.insert(back, poly[bk + 1])
      bk = bk - 2
   end

   table.insert(back, intersection.x)
   table.insert(back, intersection.y)

   return wrap, back
end

local function get_line_intersection(p0_x, p0_y, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y)
   local s1_x, s1_y, s2_x, s2_y
   local s1_x = p1_x - p0_x
   local s1_y = p1_y - p0_y
   local s2_x = p3_x - p2_x
   local s2_y = p3_y - p2_y

   local s, t
   s = (-s1_y * (p0_x - p2_x) + s1_x * (p0_y - p2_y)) / (-s2_x * s1_y + s1_x * s2_y)
   t = (s2_x * (p0_y - p2_y) - s2_y * (p0_x - p2_x)) / (-s2_x * s1_y + s1_x * s2_y)

   if (s >= 0 and s <= 1 and t >= 0 and t <= 1) then
      return p0_x + (t * s1_x), p0_y + (t * s1_y)
   end

   return 0
end

local function get_collisions(poly)
   local collisions = {}

   for outeri = 1, #poly, 2 do
      local ax = poly[outeri]
      local ay = poly[outeri + 1]
      local ni = outeri + 2
      if outeri == #poly - 1 then ni = 1 end
      local bx = poly[ni]
      local by = poly[ni + 1]

      for inneri = 1, #poly, 2 do
         local cx = poly[inneri]
         local cy = poly[inneri + 1]
         local ni = inneri + 2
         if inneri == #poly - 1 then ni = 1 end
         local dx = poly[ni]
         local dy = poly[ni + 1]

         if inneri ~= outeri then
            local result, opt = get_line_intersection(ax, ay, bx, by, cx, cy, dx, dy)
            if (ax == cx and ay == cy) or (ax == dx and ay == dy) or
                (bx == cx and by == cy) or (bx == dx and by == dy) then
               -- print("share corner")
            else
               if result ~= 0 then
                  local col = { i1 = outeri, i2 = inneri, x = result, y = opt }
                  local alreadyfound = false

                  for i = 1, #collisions do
                     if (collisions[i].i1 == inneri and collisions[i].i2 == outeri) then
                        alreadyfound = true
                     else
                     end
                  end

                  if not alreadyfound then
                     table.insert(collisions, col)
                  end
               end
            end
         end
      end
   end
   return collisions
end

local function getTriangleCentroid(triangle)
   local x = (triangle[1] + triangle[3] + triangle[5]) / 3
   local y = (triangle[2] + triangle[4] + triangle[6]) / 3
   return x, y
end

local function reTriangulatePolygon(poly, result)
   local p = poly
   local triangles = love.math.triangulate(p)
   for j = 1, #triangles do
      local t = triangles[j]
      local cx, cy = getTriangleCentroid(t)
      if hit.pointInPath(cx, cy, p) then
         table.insert(result, t)
      end
   end
end

mesh.decompose_complex_poly = function(poly, result)
   local intersections = get_collisions(poly)
   if #intersections == 0 then
      result = TableConcat(result, { poly })
   end
   if #intersections > 1 then
      local p1, p2 = split_poly(poly, intersections[1])
      local p1c, p2c = get_collisions(p1), get_collisions(p2)
      if (#p1c > 0) then
         result = mesh.decompose_complex_poly(p1, result)
      else
         result = TableConcat(result, { p1 })
      end

      if (#p2c > 0) then
         result = mesh.decompose_complex_poly(p2, result)
      else
         result = TableConcat(result, { p2 })
      end
   end
   if #intersections == 1 then
      local p1, p2 = split_poly(poly, intersections[1])
      result = TableConcat(result, { p1 })
      result = TableConcat(result, { p2 })
   end

   return result
end

mesh.makeVertices = function(shape)
   --local triangles = {}
   if (shape.type == 'meta') then return end
   if (shape.folder) then return end

   local points = shape.points
   local vertices = {}

   if shape.type == nil or shape.type == 'poly' then
      if (points and #points >= 2) then

         local scale = 1
         local coords = {}
         local ps = {}

         for l = 1, #points do
            table.insert(coords, points[l][1])
            table.insert(coords, points[l][2])
         end

         if (shape.color) then
            local polys = mesh.decompose_complex_poly(coords, {})
            local result = {}

            for k = 1, #polys do
               local p = polys[k]
               if (#p >= 6) then
                  -- if a import breaks on triangulation errors uncomment this
                  --	       print( #p, inspect(p))

                  reTriangulatePolygon(p, result)
               end
            end

            for j = 1, #result do
               table.insert(vertices, { result[j][1], result[j][2] })
               table.insert(vertices, { result[j][3], result[j][4] })
               table.insert(vertices, { result[j][5], result[j][6] })
            end
         end
      end
   else

      if (shape.type == 'rubberhose') then

         local start = {
            x = shape.points[1][1],
            y = shape.points[1][2]
         }
         local eind = {
            x = shape.points[2][1],
            y = shape.points[2][2]
         }

         local magic = 4.46
         local cp1, cp2 = bezier.positionControlPoints(start, eind, shape.data.length * magic, shape.data.flop,
            shape.data.borderRadius)
         local curve = love.math.newBezierCurve({ start.x, start.y, cp1.x, cp1.y, cp2.x, cp2.y, eind.x, eind.y })

         local coords = {}
         if (tostring(cp1.x) == 'nan') then
            coords = { shape.points[1], shape.points[2] }
         else
            local steps = shape.data.steps
            for i = 0, steps do
               local px, py = curve:evaluate(i / steps)
               table.insert(coords, { px, py })
            end
         end
         coords = unloop.unpackNodePoints(coords, false)
         local verts, indices, draw_mode = polyline('miter', coords, { shape.data.width })
         local h = 1 / (shape.data.steps - 1 or 1)
         local vertsWithUVs = {}

         for i = 1, #verts do
            local u = (i % 2 == 1) and 0 or 1
            local v = math.floor(((i - 1) / 2)) / (#verts / 2 - 1)
            vertsWithUVs[i] = { verts[i][1], verts[i][2], u, v }
         end

         vertices = vertsWithUVs
      elseif (shape.type == 'bezier') then
         local curvedata = unloop.unpackNodePoints(points, false)
         local curve = love.math.newBezierCurve(curvedata)
         local steps = shape.data.steps
         local coords = {}
         for i = 0, steps do
            local px, py = curve:evaluate(i / steps)
            table.insert(coords, { px, py })
         end
         coords = unloop.unpackNodePoints(coords, false)

         local verts, indices, draw_mode = polyline('miter', coords, { shape.data.width })
         local h = 1 / (shape.data.steps - 1 or 1)
         local vertsWithUVs = {}

         for i = 1, #verts do
            local u = (i % 2 == 1) and 0 or 1
            local v = math.floor(((i - 1) / 2)) / (#verts / 2 - 1)
            vertsWithUVs[i] = { verts[i][1], verts[i][2], u, v }
         end
         vertices = vertsWithUVs
      else

         local coords = unloop.unpackNodePoints(points, false)
         local verts, indices, draw_mode = polyline('miter', coords, { 10, 40, 20, 100, 10 })
         vertices = verts
      end
   end

   return vertices
end


mesh.makeMeshFromVertices = function(vertices, nodetype, usesTexture)
   --   print('make mesh called, by whom?', nodetype)

   local m = nil
   if nodetype == 'rubberhose' then

      m = love.graphics.newMesh(vertices, "strip")
   elseif nodetype == 'bezier' then
      m = love.graphics.newMesh(vertices, "strip")

   else
      if (vertices and vertices[1] and vertices[1][1]) then
         --local mesh

         if (usesTexture) then

            m = love.graphics.newMesh(vertices, "fan")
         else
            m = love.graphics.newMesh(formats.simple_format, vertices, "triangles")
         end

         --return mesh
      end
   end

   return m
end

mesh.remeshNode = function(node)
   --print('remesh node called, lets try and make a textured mesh', node, node.points, #node.points)
   local verts = mesh.makeVertices(node)

   if node.texture and (node.texture.url:len() > 0) and (node.type ~= 'rubberhose' and node.type ~= 'bezier') then
      print(node.texture.url, node.texture.url:len())

      local img = imageCache[node.texture.url];

      if (node.texture.squishable) then
         local v = makeSquishableUVsFromPoints(node.points)
         node.mesh = love.graphics.newMesh(v, 'fan')
      else
         addUVToVerts(verts, img, node.points, node.texture)
         if (node.texture.squishable == true) then
            print('need to make this a fan instead of trinagles I think')
         end
         node.mesh = love.graphics.newMesh(verts, 'triangles')
      end

      node.mesh:setTexture(img)
   else
      node.mesh = mesh.makeMeshFromVertices(verts, node.type, node.texture)
      if node.type == 'rubberhose' or node.type == 'bezier' and node.texture then
         local texture = imageCache[node.texture and node.texture.url]
         if texture then
            node.mesh:setTexture(texture)
         end
      end
   end

   if node.border then
      node.borderMesh = makeBorderMesh(node)
   end
end

mesh.meshAll = function(root) -- this needs to be done recursive
   if root.children then
      for i = 1, #root.children do
         if (root.children[i].points) then
            if root.children[i].type == 'meta' then
            else
               mesh.remeshNode(root.children[i])
            end
            if root.children[i].border then
               print('this border should be meshed here')
            end
         else
            mesh.meshAll(root.children[i])
         end
      end
   end
end



mesh.recursivelyAddOptimizedMesh = function(root)
   if root.folder then
      if root.url then
         root.optimizedBatchMesh = meshCache[root.url].optimizedBatchMesh
      end
   end

   if root.children then
      for i = 1, #root.children do
         if root.children[i].folder then
            mesh.recursivelyAddOptimizedMesh(root.children[i])
         end
      end
   end
end


mesh.makeOptimizedBatchMesh = function(folder)
   -- this one assumes all children are shapes, still need to think of what todo when
   -- folders are children
   if #folder.children == 0 then
      print("this was empty nothing to optimize")
      return
   end

   for i = 1, #folder.children do
      if (folder.children[i].folder) then
         print("could not optimize shape, it contained a folder!!", folder.name, folder.children[i].name)
         print('havent fetched the metatags either', folder.name, folder.children[i].name)
         return
      end
   end

   --for i=1, #folder.children do
   --   if (folder.children[i].type == 'meta') then
   --      print("could not optimize shape, it contained a meta tag",folder.name,folder.children[i].name)
   --      return
   --  end
   --end

   local lastColor = folder.children[1].color
   local allVerts = {}
   local batchIndex = 1

   local metaTags = {}
   for i = 1, #folder.children do
      if folder.children[i].type == 'meta' then
         local tagData = { name = folder.children[i].name, points = folder.children[i].points }
         table.insert(metaTags, tagData)
         print('skipping meta node in optimize round')
      else
         local thisColor = folder.children[i].color
         if (thisColor[1] ~= lastColor[1]) or
             (thisColor[2] ~= lastColor[2]) or
             (thisColor[3] ~= lastColor[3]) then

            if folder.optimizedBatchMesh == nil then
               folder.optimizedBatchMesh = {}
            end

            if #allVerts == 0 then
               -- this is possible since te last node could have been a meta one, then we skip some steps
               print('the last node was meta and that in itself was the first node')
            else
               local me = love.graphics.newMesh(formats.simple_format, allVerts, "triangles")
               folder.optimizedBatchMesh[batchIndex] = { mesh = me, color = lastColor }
               batchIndex = batchIndex + 1
            end

            lastColor = thisColor
            allVerts = {}
         end

         allVerts = TableConcat(allVerts, mesh.makeVertices(folder.children[i]))
      end
   end

   if #allVerts > 0 then
      if folder.optimizedBatchMesh == nil then
         folder.optimizedBatchMesh = {}
      end
      local m = love.graphics.newMesh(formats.simple_format, allVerts, "triangles")
      folder.optimizedBatchMesh[batchIndex] = { mesh = m, color = lastColor }
      --print('optimized: ', folder.name,)
   end

   if #metaTags > 0 then
      folder.metaTags = metaTags
   end

end



return mesh

local mesh = {}

local formats = require 'lib.formats'

function makeMeshFromVertices(vertices, nodetype, usesTexture)
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

function remeshNode(node)
   print('remesh node called, lets try and make a textured mesh', node, node.points, #node.points)
   local verts = makeVertices(node)

   if node.texture and (node.texture.url:len() > 0) and (node.type ~= 'rubberhose' and node.type ~= 'bezier') then
      print(node.texture.url, node.texture.url:len())

      local img = imageCache[node.texture.url];

      if (node.texture.squishable) then
         local verts = makeSquishableUVsFromPoints(node.points)
         node.mesh = love.graphics.newMesh(verts, 'fan')
      else
         addUVToVerts(verts, img, node.points, node.texture)
         if (node.texture.squishable == true) then
            print('need to make this a fan instead of trinagles I think')
         end
         node.mesh = love.graphics.newMesh(verts, 'triangles')
      end

      node.mesh:setTexture(img)
   else
      node.mesh = makeMeshFromVertices(verts, node.type, node.texture)
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
               remeshNode(root.children[i])
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

         allVerts = TableConcat(allVerts, makeVertices(folder.children[i]))
      end
   end

   if #allVerts > 0 then
      if folder.optimizedBatchMesh == nil then
         folder.optimizedBatchMesh = {}
      end
      local mesh = love.graphics.newMesh(formats.simple_format, allVerts, "triangles")
      folder.optimizedBatchMesh[batchIndex] = { mesh = mesh, color = lastColor }
      --print('optimized: ', folder.name,)
   end

   if #metaTags > 0 then
      folder.metaTags = metaTags
   end

end



return mesh

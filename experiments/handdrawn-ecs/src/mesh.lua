function createTexturedPolygon(image, polygon)
   
   local tlx, tly, brx, bry = getPointsBBoxFlat(polygon)
   -- tweak feat
   local ufunc = function(x) return mapInto(x, tlx, brx, 0,3) end
   local vfunc = function(y) return mapInto(y, tly, bry, 0,3) end

   -- this thing needs
   local p = {}
   reTriangulatePolygon(polygon, p)
   local vertices = {}
   
   -- for i = 1, #polygon, 2 do
   --    table.insert(
   --       vertices, {polygon[i+0], polygon[i+1],
   --                  ufunc(polygon[i+0]), vfunc(polygon[i+1])}
   --    )
   -- end

   
   for i = 1 , #p do
      local r = p[i]
--      print(inspect(r))
      table.insert(vertices, {r[1], r[2], ufunc(r[1]), vfunc(r[2])})
      table.insert(vertices, {r[3], r[4], ufunc(r[3]), vfunc(r[4])})
      table.insert(vertices, {r[5], r[6], ufunc(r[5]), vfunc(r[6])})
   end
   
   
   --print(inspect(vertices))
   local mesh = love.graphics.newMesh(vertices, "triangles")

   --local mesh = love.graphics.newMesh(vertices, "fan")
   mesh:setTexture(image)

   return mesh

end



function createTexturedRectangle(image)
   local w, h = image:getDimensions( )
   --print(w,h)
   local vertices = {}
   -- x,y,u,v,r,g,b,
   --table.insert(vertices, {0,     0,   0.5, 0.5, 0, 0, 0})

   table.insert(vertices, {0, 0, 0, 0})
   table.insert(vertices, { w, 0, 1, 0})
   table.insert(vertices, { w,  h, 1, 1})
   table.insert(vertices, {0,  h, 0, 1})
   
   --table.insert(vertices, {0, 0, 0, 0, 0, 0, 0})


   --simple_format = {
   --   {"VertexPosition", "float", 2}, -- The x,y position of each vertex.
   -- }
   
   local mesh = love.graphics.newMesh(vertices, "fan")
   mesh:setTexture(image)

   return mesh
end



function createTexturedTriangleStrip(image)
   -- this assumes an strip that is oriented vertically
   
   local w, h = image:getDimensions( )
   local vertices = {}
   local segments = 15
   local hPart = h / (segments-1)
   local hv = 1/ (segments-1)
   local runningHV = 0
   local runningHP = 0
   local index = 0
   for i =1, segments do
      
      vertices[index + 1] = {-w/2, runningHP, 0,runningHV }
      vertices[index +  2] = {w/2, runningHP, 1,runningHV }

      runningHV = runningHV + hv
      runningHP = runningHP + hPart
      index = index + 2
   end

   local mesh = love.graphics.newMesh(vertices, "strip")
   mesh:setTexture(image)

   return mesh
end

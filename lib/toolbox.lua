function parseFile(url)
   local contents, size = love.filesystem.read( url)
   if contents == nil then
      print(printC({fg='red'}, "file not found: ", url))
   end

   local parsed = (loadstring("return ".. contents)())

   local figuredItOut = false
   if (#parsed == 1 and parsed[1].folder) then
      parsed[1].origin = {path=url, index=-1}
      figuredItOut = true
   end
   if #parsed > 1 then
      -- first check if all descendants are folders
      local allAreFolders = true
      for i =1, #parsed do
         if (not parsed[i].folder) then
            allAreFolders = false
         end
      end
      if (allAreFolders) then
         for i =1, #parsed do
            parsed[i].origin = {path=url, index=i}
         end
         figuredItOut = true
      end
   end
   if (not figuredItOut) then
      print('I dont know what type of origin url to put in here', url)
   end
   return parsed
end

function stringSplit(str, sep)
   local result = {}
   local regex = ("([^%s]+)"):format(sep)
   for each in str:gmatch(regex) do
      table.insert(result, each)
   end
   return result
end

function stringFindLastSlash(str)
   --return str:match'^.*()'..char
   local index =  string.find(str, "/[^/]*$")
   if index == nil then -- windows ? i dunno?
      index = string.find(str, "\\[^\\]*$")
   end
   return index
   --index = string.find(your_string, "/[^/]*$")
end



function getDataFromFile(file)
   local filename = file:getFilename()
   local tab
   local _shapeName

   if ends_with(filename, '.svg') then
      local command = 'node '..'resources/svg_to_love/index.js '..filename..' '..simplifyValue
      print(command)
      if string.match(filename, " ") then
         print(":::ERROR::: path string should not contain any spaces")
      end

      local p = io.popen(command)
      local str = p:read('*all')
      p:close()
      local obj = ('{'..str..'}')
      tab = (loadstring("return ".. obj)())
      local charIndex = string.find(filename, "/[^/]*$")
      if charIndex == nil then
         charIndex = string.find(filename, "\\[^\\]*$")
      end

      _shapeName = filename:sub(charIndex+1, -5) -- cutting off .svg
      shapeName = _shapeName

   end

   if ends_with(filename, 'polygons.txt') then
      local str = file:read('string')
      tab = readStrAsShape(str, filename)
   end
   return tab
end

function readStrAsShape(str, filename )
      local tab = (loadstring("return ".. str)())

      local vsketchIndex = (string.find(filename, 'vector-sketch/', 1, true)) + #'vector-sketch/'
      local  lookFurther =  filename:sub(vsketchIndex)
      local index2 = stringFindLastSlash(lookFurther)
      local fname = lookFurther
      shapePath = ''
      if index2 then
	 fname = lookFurther:sub(index2+1)
	 shapePath =  lookFurther:sub(1, index2)
      end
      shapeName = fname:sub(1, -14)
      return tab
end


-- this was for a 3d experiment
function makeScaleFit(root, multipier)
   for i=1, #root.children do
      local child = root.children[i]
      if child.folder then
         child.transforms.l[1] = child.transforms.l[1] * multipier  --tx
         child.transforms.l[2] = child.transforms.l[2] * multipier  --ty
         child.transforms.l[6] = child.transforms.l[6] * multipier  --ox
         child.transforms.l[7] = child.transforms.l[7] * multipier  --oy

         makeScaleFit(child, multipier)
      else

      end
   end
end
-- this was for a 3d experiment
function extrudeShape(shape, border,thickness, startZ)
   -- input is a flat 2d image
   -- output is a front and back side spaced with the tickness


   local newShape = {}
   local extrudedSide = {}
   for i=1, #shape do
      newShape[i] = {shape[i][1]/100, shape[i][2]/100, startZ}
      extrudedSide[i] = {shape[i][1]/100, shape[i][2]/100, startZ + thickness}
   end

   local sides = {}
   for i=1, #border do
      local index = i
      local nextIndex = i < #border and i+1 or 1
      local t = thickness + startZ --* love.math.random()
      local p1 = {border[index][1]/100, border[index][2]/100, startZ}
      local p2 = {border[nextIndex][1]/100, border[nextIndex][2]/100, startZ}
      local p3 = {border[index][1]/100, border[index][2]/100, t}
      local p4 = {border[nextIndex][1]/100, border[nextIndex][2]/100, t}
      table.insert(sides, p3)
      table.insert(sides, p2)
      table.insert(sides, p1)

      table.insert(sides, p3)
      table.insert(sides, p4)
      table.insert(sides, p2)
   end

   return {shape=newShape, otherside=extrudedSide, sides=sides}
end

-- this was for a 3d experiment
function generate3dShapeFrom2d(shape, z)
   local result = {}
   for i = 1, #shape do
      result[i] = {shape[i][1]/100, shape[i][2]/100, z}
   end
   return result
end



function meshAll(root) -- this needs to be done recursive
   if root.children then
   for i=1, #root.children do
      if (root.children[i].points) then
         if root.children[i].type == 'meta' then
         else
            remeshNode(root.children[i])
         end
         if root.children[i].border then
            print('this border should be meshed here')
         end
      else
         meshAll(root.children[i])
      end
   end
   end
end


function addUVToVerts(verts, img, points, settings)
   --print('Im tweakibg around ion here atm, check the code for UV stuff')
   local tlx, tly, brx, bry = getPointsBBox(points)

   local keepAspect = settings.keepAspect ~= nil and settings.keepAspect or true
   local xFactor = 1
   local yFactor = 1

   assert(brx-tlx > 0 and bry-tly > 0)
   
   local xFactor = img:getWidth()/(brx-tlx)
   local yFactor = img:getHeight()/(bry-tly)
   
--   print(xFactor, yFactor)

   local mmin = math.min(xFactor, yFactor)
   local mmax = math.max(xFactor, yFactor)
   local xscale = keepAspect and  mmax or xFactor
   local yscale = keepAspect and mmax or yFactor
   
 --  local ufunc = function(x) return mapInto(x, tlx, brx, 0, 1/xFactor * xscale) end
 --  local vfunc = function(y) return mapInto(y, tly, bry, 0, 1/yFactor * yscale) end

   local ufunc = function(x) return mapInto(x, tlx, brx, 0, 1) end
   local vfunc = function(y) return mapInto(y, tly, bry, 0, 1) end
   
   --print(#verts)
   for i =1, #verts do
      local v =verts[i]
      verts[i] ={v[1], v[2], ufunc(v[1]), vfunc(v[2])}
   end
  
   -- todo should this return instead?

end


function makeSquishableUVsFromPoints(points)
   local verts = {}

   --assert(#points == 4)
   
   local v = points
   --for i =1, #points do
   local useMiddle = true
   local use8points = true
   
   if useMiddle then

      if (#v >= 5 ) then
      verts[1] = {v[1][1], v[1][2], 0.5, 0.5}
      verts[2] = {v[2][1], v[2][2], 0, 0}
      verts[3] = {v[3][1], v[3][2], 1, 0}
      verts[4] = {v[4][1], v[4][2], 1, 1}
      verts[5] = {v[5][1], v[5][2], 0,1 }
      verts[6] = {v[2][1], v[2][2], 0,0 } -- this is an extra one to make it go round
      end

      if (use8points and #v > 7) then
	 verts[1] = {v[1][1], v[1][2], 0.5, 0.5}
	 verts[2] = {v[2][1], v[2][2], 0, 0}
	 verts[3] = {v[3][1], v[3][2], .5, 0}
	 verts[4] = {v[4][1], v[4][2], 1, 0}
	 verts[5] = {v[5][1], v[5][2], 1, .5}
	 verts[6] = {v[6][1], v[6][2], 1, 1}
	 verts[7] = {v[7][1], v[7][2], .5, 1}
	 verts[8] = {v[8][1], v[8][2], 0, 1}
	 verts[9] = {v[9][1], v[9][2], 0, .5}
	 verts[10] = {v[2][1], v[2][2], 0,0 } -- this is an extra one to make it go round

      end
      
      
   --end
   else
      verts[1] = {v[1][1], v[1][2], 0, 0}
      verts[2] = {v[2][1], v[2][2], 1, 0}
      verts[3] = {v[3][1], v[3][2], 1, 1}
      verts[4] = {v[4][1], v[4][2], 0,1 }
   end
   
   return verts
end



function remeshNode(node)
   print('remesh node called, lets try and make a textured mesh', node, node.points, #node.points)
   local verts = makeVertices(node)

   if node.texture and (node.texture.url:len() > 0 ) and (node.type ~= 'rubberhose' and node.type ~= 'bezier') then
      print(node.texture.url, node.texture.url:len())

      local img = imageCache[node.texture.url];

      if (node.texture.squishable) then
	 -- print('yo hello!')

	 local verts = makeSquishableUVsFromPoints(node.points)
	 node.mesh = love.graphics.newMesh(verts, 'fan')
      else
      
	 
	 addUVToVerts(verts, img, node.points, node.texture )
	 if (node.texture.squishable == true) then
	    print('need to make this a fan instead of trinagles I think')
	 end
	 
	 node.mesh = love.graphics.newMesh(verts, 'triangles')
      end
      
      node.mesh:setTexture(img)

   else

      --if node.type ~= 'rubberhose' then
	 node.mesh = makeMeshFromVertices(verts, node.type, node.texture)
         --end

         if node.type == 'rubberhose' or node.type == 'bezier' then
	    node.mesh:setTexture(imageCache[node.texture.url])
         end
         
      

   end
   
   

   if node.border then
      node.borderMesh =  makeBorderMesh(node)
   end
end

simple_format = {
   {"VertexPosition", "float", 2}, -- The x,y position of each vertex.
}

function makeMeshFromVertices(vertices, nodetype, usesTexture)
   --   print('make mesh called, by whom?', nodetype)

   
   if nodetype == 'rubberhose' then
      local mesh = love.graphics.newMesh(vertices, "strip")
      return mesh
   --elseif nodetype == 'line' then
   --   local mesh = love.graphics.newMesh(vertices, "strip")
   --   return mesh
   elseif nodetype == 'bezier' then
      local mesh = love.graphics.newMesh(vertices, "strip")
      return mesh
   else
      --print(inspect(vertices))
      if (vertices and vertices[1] and vertices[1][1]) then
	 local mesh
	 
	 if (usesTexture) then
	    
	    mesh = love.graphics.newMesh(vertices, "fan")
	 else
	    mesh = love.graphics.newMesh(simple_format, vertices, "triangles")
	 end
	 
	 return mesh
      end
   end

   return nil
end


function makeBorderMesh(node)
   local work = unpackNodePointsLoop(node.points)

   local output = {}

   for i =50, 100 do
      local t = (i/100)
      if t >= 1 then t = 0.99999999 end

      local x,y = GetSplinePos(work, t, node.borderTension)
      table.insert(output, {x,y})
   end

   local rrr = {}
   local r2 = evenlySpreadPath(rrr, output, 1, 0, node.borderSpacing)

   output = unpackNodePoints(rrr)
   local verts, indices, draw_mode = polyline('miter',output, node.borderThickness, nil, nil, node.borderRandomizerMultiplier)
   local mesh = love.graphics.newMesh(simple_format, verts, draw_mode)
   return mesh
end

--[[
function meshAll3d(root) -- this needs to be done recursive

   for i=1, #root.children do
      local child = root.children[i]
      if (not child.folder) then
         --remeshNode(root.children[i])

         if child.border then
            print('this border should be meshed here')
         end

         -- i am not sure its needed to make normals
         local verts= makeVertices(child)
         local shape3d = generate3dShapeFrom2d(verts, i*0.00001)
         if #shape3d > 0 then

            local pt = child._parent.transforms._g
            --print(child._parent.transforms._g)
            local m = G4d.Model(shape3d, nil, {0,0,0}, nil,nil, pt)
            m:set_shader_data('color',  root.children[i].color)
            --m:makeNormals()
            root.children[i].m3d= m

            local thick = .05
            local a = extrudeShape(verts, child.points,thick, i*0.00)
            --print(inspect(a))
            local n = G4d.Model(a.sides, nil, {0,0,0},nil,nil, pt)
            --n:makeNormals()
            root.children[i].m3dSides = n
            local o = G4d.Model(shape3d, nil, {0,0,thick},nil,nil, pt)
             o:set_shader_data('color',  root.children[i].color)
            ---o:makeNormals()
            root.children[i].m3dOther=  o
            --print(a.sides)
            --extrudeShape(shape, border,thickness)
         end
      else
         meshAll(root.children[i])
      end
   end
end


function handleChild3d(shape, t)
   if shape.folder then
      renderThings3d(shape)
   else
      if shape.m3d then
         love.graphics.setColor(shape.color[1], shape.color[2], shape.color[3])
         --local t= love.math.newTransform(0,0,Timer,1,1,Timer % 4,0,0,0)
         --shape.m3d:draw2(shader )
         --print('yo shape:', shape)

         localX, localY = shape._parent.transforms._g:transformPoint( 0, 0)
         shape.m3d:move(localX, localY)
         shape.m3d:draw()
         if shape.m3dSides then
            shape.m3dSides:move(localX, localY)
           shape.m3dSides:draw(defaultShader)

         end
         if shape.m3dOther then
            shape.m3dOther:move(localX, localY)
            shape.m3dOther:draw(defaultShader)

         end

      end
   end


end


function renderThings3d(root)

   local tl = root.transforms.l
   local pg = nil
   if (root._parent) then
      pg = root._parent.transforms._g
   end
   root._localTransform =  love.math.newTransform( tl[1], tl[2], tl[3], tl[4], tl[5], tl[6],tl[7], tl[8],tl[9])


   root.transforms._g = pg and (pg * root._localTransform) or rootcalTransform

   for i = 1, #root.children do
      local shape = root.children[i]
      handleChild3d(shape)
   end
   lg.setColor(1,1,1,1)
end
]]--

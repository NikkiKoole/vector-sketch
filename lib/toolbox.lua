local numbers = require 'lib.numbers'
local bbox = require 'lib.bbox'


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



function addUVToVerts(verts, img, points, settings)
   --print('Im tweakibg around ion here atm, check the code for UV stuff')
   local tlx, tly, brx, bry = bbox.getPointsBBox(points)

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

   local ufunc = function(x) return numbers.mapInto(x, tlx, brx, 0, 1) end
   local vfunc = function(y) return numbers.mapInto(y, tly, bry, 0, 1) end
   
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
 
   if #v == 4  then
      verts[1] = {v[1][1], v[1][2], 0, 0}
      verts[2] = {v[2][1], v[2][2], 1, 0}
      verts[3] = {v[3][1], v[3][2], 1, 1}
      verts[4] = {v[4][1], v[4][2], 0,1 }
   end
   if #v == 5  then
      verts[1] = {v[1][1], v[1][2], 0.5, 0.5}
      verts[2] = {v[2][1], v[2][2], 0, 0}
      verts[3] = {v[3][1], v[3][2], 1, 0}
      verts[4] = {v[4][1], v[4][2], 1, 1}
      verts[5] = {v[5][1], v[5][2], 0,1 }
      verts[6] = {v[2][1], v[2][2], 0,0 } -- this is an extra one to make it go round
   end
   if #v == 9  then
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

         if node.type == 'rubberhose' or node.type == 'bezier' and node.texture then
            
	    local texture = imageCache[node.texture and node.texture.url]
	    if texture then
	       node.mesh:setTexture(texture)
	    end
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

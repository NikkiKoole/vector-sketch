
function getDataFromFile(file)
   local filename = file:getFilename()
   local tab
   local _shapeName


   if ends_with(filename, 'polygons.txt') then
      local str = file:read('string')
      tab = (loadstring("return ".. str)())

      local index = string.find(filename, "/[^/]*$")
      if index == nil then
         index = string.find(filename, "\\[^\\]*$")
      end

      print(index, filename)
      _shapeName = filename:sub(index+1, -14) --cutting off .polygons.txt
      shapeName = _shapeName
   end
   return tab
end

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


function generate3dShapeFrom2d(shape, z)
   local result = {}
   for i = 1, #shape do
      result[i] = {shape[i][1]/100, shape[i][2]/100, z}
   end
   return result
end


function meshAll(root) -- this needs to be done recursive

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

            local pt = child._parent._globalTransform
            --print(child._parent._globalTransform)
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

         localX, localY = shape._parent._globalTransform:transformPoint( 0, 0)
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
      pg = root._parent._globalTransform
   end
   root._localTransform =  love.math.newTransform( tl[1], tl[2], tl[3], tl[4], tl[5], tl[6],tl[7], tl[8],tl[9])


   root._globalTransform = pg and (pg * root._localTransform) or root._localTransform

   for i = 1, #root.children do
      local shape = root.children[i]
      handleChild3d(shape)
   end
   lg.setColor(1,1,1,1)
end


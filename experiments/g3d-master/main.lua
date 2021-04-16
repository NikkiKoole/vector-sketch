-- written by groverbuger for g3d
-- january 2021
-- MIT license

g3d = require "g3d"
require 'main-utils'
require 'util'
poly = require 'poly'
require 'generate-polygon'
require 'basics'
inspect = require 'inspect'
local shader = require "g3d/shader"
ProFi = require 'ProFi'


count = 0

function generate3dShapeFrom2d(shape, z)
   local result = {}
   for i = 1, #shape do
      result[i] = {shape[i][1]/100, shape[i][2]/100, z}
   end
   return result
end
function makeScaleFit(root)
   for i=1, #root.children do
      local child = root.children[i]
      if child.folder then
         child.transforms.l[1] = child.transforms.l[1] / 100  --tx
         child.transforms.l[2] = child.transforms.l[2] / 100  --ty
         child.transforms.l[6] = child.transforms.l[6] / 100  --ox
         child.transforms.l[7] = child.transforms.l[7] / 100  --oy
            
         makeScaleFit(child)
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

function meshAll(root) -- this needs to be done recursive
   
   for i=1, #root.children do
      local child = root.children[i]
      if (not child.folder) then
         --remeshNode(root.children[i])
         
         if child.border then
            print('this border should be meshed here')
         end
       
         -- i am not sure its needed to make normals
         local verts= poly.makeVertices(child)
         local shape3d = generate3dShapeFrom2d(verts, i*0.00001)
         if #shape3d > 0 then

            local pt = child._parent._globalTransform
            --print(child._parent._globalTransform)
            local m = g3d.newModel(shape3d, nil, {0,0,0}, nil,nil, pt)
            --m:makeNormals()
            root.children[i].m3d= m

            local thick = .05
            local a = extrudeShape(verts, child.points,thick, i*0.00)
            --print(inspect(a))
            local n = g3d.newModel(a.sides, nil, {0,0,0},nil,nil, pt)
            --n:makeNormals()
            root.children[i].m3dSides = n
            local o = g3d.newModel(shape3d, nil, {0,0,thick},nil,nil, pt)
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

function love.load()
   profiling = false

  local generated = generatePolygon(0,0, 40, .05, .02 , 45)
   local points = {}
   for i = 1, #generated, 2 do
      table.insert(points, {generated[i], generated[i+1]})
   end

   
   
   
   root = {
      folder = true,
      name = 'root',
      transforms =  {l={0,0,0,1,1,0,0,0,0}},
      children = {
         { 
            children = { {
                  color = { 0.867, 0.239, 0.055, 1 },
                  name = "orange",
                  points = { { 270, 290 }, { 469, 335 }, { 341, 140 } }
            } },
            folder = true,
            name = "orange parent",
            transforms = {
               l = { 0, 0, 0, 1, 1, 0, 0, 0, 0 }
            }
         }, {
            children = { {
                  color = { 0.161, 0.678, 1, 1 },
                  name = "blue",
                  points = { { 270, 290 }, { 469, 335 }, { 341, 140 } }
            } },
            folder = true,
            name = " blue parent",
            transforms = {
               l = { 9, 269, 0, 1, 1, 0, 0, 0, 0 }
            }
            }, {
            children = { {
                  color = { 0, 0.529, 0.318, 1 },
                  name = "green",
                  points = { { 605, 339 }, { 749, 403 }, { 682, 135 } }
            } },
            folder = true,
            name = "green parent",
            transforms = {
               l = { 0, 0, 0, 1, 1, 0, 0, 0, 0 }
            }
               }, {
            children = { {
                  color = { 0.514, 0.463, 0.612, 1 },
                  name = "purple",
                  points = { { 605, 339 }, { 749, 403 }, { 682, 135 } }
            } },
            folder = true,
            name = " purple parent",
            transforms = {
               l = { -27, 281, 0, 1, 1, 0, 0, 0, 0 }
            }
      } }
      
   }

   makeScaleFit(root)
   parentize(root)
   renderThings3d(root)
   meshAll(root)
  
    Earth = g3d.newModel("assets/sphere.obj", "assets/earth.png", {0,0,4})
    Moon = g3d.newModel("assets/sphere.obj", "assets/moon.png", {5,0,4}, nil, {0.5,0.5,0.5})
    Background = g3d.newModel("assets/sphere.obj", "assets/iper.jpeg", {0,0,0}, nil, {500,500,500})
    Timer = 0
    love.mouse.setVisible( true)
end


function love.keypressed(k)
   if k == "escape" then love.event.quit() end
   if (k == 'p') then
    if not profiling then
	 ProFi:start()
      else
	 ProFi:stop()
	 ProFi:writeReport( 'rofilingReport.txt' )
      end
      profiling = not profiling
   end
end

function recursiveRayIntersection(root, x,y,z, pos)
   -- todo this doenst check other and sides
   if root.m3d then
     if (root._parent._globalTransform) then
         local dx, dy = root._parent._globalTransform:inverseTransformPoint(0,0)
         local hit = root.m3d:rayIntersectionAABB(pos[1], pos[2], pos[3], x, y, z)

         if hit then
            print(root.name, root._parent.name)
         end
         
     end
   else
      if root.children then
      for i = 1, #root.children do
         recursiveRayIntersection(root.children[i], x,y,z, pos)
      end
      end
   end
   
end


function love.mousemoved(x,y, dx,dy)
   g3d.camera.firstPersonLook(dx,dy)
   --print(inspect(g3d.camera.position))
   
   local x,y,z = g3d.camera:getLookVector()
   local pos = g3d.camera.position

   local hit = Earth:rayIntersectionAABB(pos[1], pos[2], pos[3], x, y, z)
   print('earth hit', hit)
   local hit = Moon:rayIntersectionAABB(pos[1], pos[2], pos[3], x, y, z)
   print('moon hit', hit)
   recursiveRayIntersection(root, x,y,z, pos)

end

function love.update(dt)
    Timer = Timer + dt
    Moon:setTranslation(math.cos(Timer)*5, 0, math.sin(Timer)*5 +4)
    Moon:setRotation(0,-1*Timer,0)

    g3d.camera.firstPersonMovement(dt/10)
end

function handleChild3d(shape, t)
   if shape.folder then
      renderThings3d(shape)
   else
      if shape.m3d then
         love.graphics.setColor(shape.color[1], shape.color[2], shape.color[3])
         --local t= love.math.newTransform(0,0,Timer,1,1,Timer % 4,0,0,0)
         --shape.m3d:draw2(shader )
         
         shape.m3d:draw2(shader, shape._parent._globalTransform )
         if shape.m3dSides then
            shape.m3dSides:draw2(shader, shape._parent._globalTransform )

         end
          if shape.m3dOther then
            shape.m3dOther:draw2(shader, shape._parent._globalTransform )

         end
         
      end
   end
   
   
end

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

function love.filedropped(file)
   fileDropPopup = file

    local tab = getDataFromFile(file)
    root.children = tab -- TableConcat(root.children, tab)
    parentize(root)
    renderThings3d(root)
    meshAll(root)
    makeScaleFit(root)

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
end


function love.draw()
    love.graphics.setColor(1,1,1)
    Earth:draw()
    Moon:draw()

    
    Background:draw()
    love.graphics.setShader(shader)
    renderThings3d(root)
    love.graphics.setShader()
    love.graphics.setColor(1,1,1)
    love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 0, 30)

    love.graphics.rectangle('fill', 1024/2, 768/2,2,2)
end

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

function generate3dShapeFrom2d(shape)
   local result = {}
   for i = 1, #shape do
      result[i] = {shape[i][1]/100, shape[i][2]/100, count}
      count = count + 0.0000001
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

function meshAll(root) -- this needs to be done recursive
   
   for i=1, #root.children do
      local child = root.children[i]
      if (not child.folder) then
         --remeshNode(root.children[i])
         
         if child.border then
            print('this border should be meshed here')
         end
       
         
         local verts= poly.makeVertices(child)
         local shape3d = generate3dShapeFrom2d(verts)
         local m = g3d.newModel(shape3d,  "assets/whitepixel.png", {0,0,0})
         root.children[i].m3d= m
         print(child.name)
         print(inspect(child.points))
         print(inspect(verts))
         print(inspect(shape3d))
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
            folder = true,
            transforms =  {l={0,0,0,1,1,100,0,0,0}},
            name="rood",
            children ={
               {
                  name="roodchild:"..1,
                  color = {.5,1,0, 0.8},
                  points = points,

               },
               {
                  folder = true,
                  transforms =  {l={200,200,0,1,1,100,0,0,0}},
                  name="yellow",
                  children ={
                     {
                        name="chi22ld:"..1,
                        color = {1,1,0, 0.8},
                        points = {{0,0},{200,0},{200,200},{0,200}},

                     },
                     {
                        folder = true,
                        transforms =  {l={200,200,0,1,1,100,0,0,0}},
                        name="blue",
                        children ={



                           {
                              name="bluechild:"..1,
                              color = {0,0,1, 0.8},
                              points = {{0,0},{200,0},{200,200},{0,200}},

                           },
                           {
                              folder = true,
                              transforms =  {l={200,200,0,1,1,0,0,0,0}},
                              name="endhandle",
                              children ={

                                 {
                                    name="endhandlechild:"..1,
                                    color = {0,1,0, 0.8},
                                    points = {{0,0},{20,0},{20,20},{0,20}},

                                 }

                              }
                           }



                        }
                     }
                  }
               }
            },
         },
      }
   }

   makeScaleFit(root)
   parentize(root)
   meshAll(root)
   --print(inspect(root))
   
   local derp = { { 294, 363 }, { 269, 322 }, { 276, 272 }, { 294, 363 }, { 276, 272 }, { 349, 219 }, { 294, 363 }, { 349, 219 }, { 403, 221 }, { 294, 363 }, { 403, 221 }, { 458, 270 }, { 294, 363 }, { 458, 270 }, { 461, 336 }, { 294, 363 }, { 461, 336 }, { 423, 386 }, { 423, 386 }, { 383, 469 }, { 356, 464 }, { 423, 386 }, { 356, 464 }, { 359, 385 }, { 423, 386 }, { 359, 385 }, { 332, 383 }, { 332, 383 }, { 270, 430 }, { 240, 416 }, { 332, 383 }, { 240, 416 }, { 294, 363 }, { 332, 383 }, { 294, 363 }, { 423, 386 } }
   
   local derp2 = { { -132.65313720703, 149.34225463867 }, { -234.65313720703, 84.342254638672 }, { -217.65313720703, 12.342254638672 }, { -132.65313720703, 149.34225463867 }, { -217.65313720703, 12.342254638672 }, { -81.653137207031, -4.6577453613281 }, { -132.65313720703, 149.34225463867 }, { -81.653137207031, -4.6577453613281 }, { -29.653137207031, 67.342254638672 }, { -132.65313720703, 149.34225463867 }, { -29.653137207031, 67.342254638672 }, { 51.346862792969, 49.342254638672 }, { 92.346862792969, -25.657745361328 }, { 133.68267822266, -367.34225463867 }, { 234.65313720703, -344.90438842773 }, { 92.346862792969, -25.657745361328 }, { 234.65313720703, -344.90438842773 }, { 186.57196044922, -17.952301025391 }, { 92.346862792969, -25.657745361328 }, { 186.57196044922, -17.952301025391 }, { 178.34686279297, 73.342254638672 }, { 92.346862792969, -25.657745361328 }, { 178.34686279297, 73.342254638672 }, { 132.34686279297, 157.34225463867 }, { 92.346862792969, -25.657745361328 }, { 132.34686279297, 157.34225463867 }, { 74.346862792969, 367.34225463867 }, { 92.346862792969, -25.657745361328 }, { 74.346862792969, 367.34225463867 }, { 53.346862792969, 145.34225463867 }, { -38.653137207031, 171.34225463867 }, { -81.653137207031, 348.34225463867 }, { -132.65313720703, 149.34225463867 }, { -38.653137207031, 171.34225463867 }, { -132.65313720703, 149.34225463867 }, { 51.346862792969, 49.342254638672 }, { 51.346862792969, 49.342254638672 }, { 92.346862792969, -25.657745361328 }, { 53.346862792969, 145.34225463867 }, { 51.346862792969, 49.342254638672 }, { 53.346862792969, 145.34225463867 }, { -38.653137207031, 171.34225463867 } }
   
   --Thing = g3d.newModel({{0,0,0},{5,0,0},{2,2,0}},  "assets/whitepixel.png", {0,0,0})
   Thing = g3d.newModel(generate3dShapeFrom2d(derp2),  "assets/whitepixel.png", {0,0,.002})

   Thing2 = g3d.newModel(generate3dShapeFrom2d(derp2),  "assets/whitepixel.png", {0,0,0})

    Earth = g3d.newModel("assets/sphere.obj", "assets/earth.png", {0,0,0})
    Moon = g3d.newModel("assets/sphere.obj", "assets/moon.png", {5,0,4}, nil, {0.5,0.5,0.5})
    Background = g3d.newModel("assets/sphere.obj", "assets/iper.jpeg", {0,0,0}, nil, {500,500,500})
    Timer = 0
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

function love.mousemoved(x,y, dx,dy)
    g3d.camera.firstPersonLook(dx,dy)
end

function love.update(dt)
    Timer = Timer + dt
    Moon:setTranslation(math.cos(Timer)*5, 0, math.sin(Timer)*5 +4)
    Moon:setRotation(0,-1*Timer,0)
   -- Thing:setRotation(0,-1*Timer,0)
    g3d.camera.firstPersonMovement(dt/10)
    --Thing2:setTranslation(0.3+Timer,0,0)
    --root.children[1].transforms.l[1] = Timer % 10
    --root.children[1].children[2].transforms.l[9] = Timer % 4
end

function handleChild3d(shape, t)
   if shape.folder then
      renderThings3d(shape)
   else
      if shape.m3d then
         love.graphics.setColor(shape.color[1], shape.color[2], shape.color[3])
         --local t= love.math.newTransform(0,0,Timer,1,1,Timer % 4,0,0,0)
         shape.m3d:draw2(shader, shape._parent._globalTransform )
      end
   end
   
   
end

function getDataFromFile(file)
   local filename = file:getFilename()
   local tab
   local _shapeName

   if ends_with(filename, '.svg') then
      local command = 'node '..'resources/svg_to_love/index.js '..filename..' '..simplifyValue
      print(command)
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
   --  love.graphics.setColor(1,0,0)
   --  Thing:setRotation(0,0,Timer)
   --  Thing:draw()
   --  love.graphics.setColor(1,1,0)
   --  --Thing2:setTranslation(100,0,0)
   --  --local m = g3d.newMatrix()
   --  --print(m)
   --  --Thing2:setTransform({-10,0,0}, {0,0,Timer}, {1,1,1})
   --  --Thing2:setRotation(0,0,Timer)
   --  --Thing2:setScale(Timer % 4,Timer % 4,1)
   --  --Thing2:setTranslation(0,0,0)

   --  local t= love.math.newTransform(0,0,Timer,1,1,Timer % 4,0,0,0)
   --  Thing2:draw(nil, t)
   --  love.graphics.setColor(1,1,1)

    
    Background:draw()
    love.graphics.setShader(shader)
    renderThings3d(root)
    love.graphics.setShader()
    
    love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 0, 30)
end

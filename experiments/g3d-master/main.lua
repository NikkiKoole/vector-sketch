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
local newMatrix = require "g3d/matrices"
ProFi = require 'ProFi'
local cpml = require 'cpml'


-- do this
-- https://stackoverflow.com/questions/31613832/converting-screen-2d-to-world-3d-coordinates

count = 0


local shadersimple = love.graphics.newShader [[
    uniform mat4 projectionMatrix;
    uniform mat4 viewMatrix;

    varying vec4 vertexColor;

    #ifdef VERTEX
        vec4 position(mat4 transform_projection, vec4 vertex_position)
        {
            vertexColor = VertexColor;
            return projectionMatrix  * viewMatrix * vertex_position;
        }
    #endif

    #ifdef PIXEL
        vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 pixcoord)
        {
            vec4 texcolor = Texel(tex, texcoord);
            if (texcolor.a == 0.0) { discard; }
            return vec4(texcolor)*color*vertexColor;
        }
    #endif
]]



function generate3dShapeFrom2d(shape, z)
   local result = {}
   for i = 1, #shape do
      result[i] = {shape[i][1]/100, shape[i][2]/100, z}
   end
   return result
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

   makeScaleFit(root, 1.0/100)
   parentize(root)
   renderThings3d(root)
   meshAll(root)

    Earth = g3d.newModel("assets/monu10.obj", _, {0,0,0})
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

function recursiveRayIntersection(root, x,y,z, pos)
   -- todo this doenst check other and sides
   if root.m3d then
     if (root._parent._globalTransform) then
         local dx, dy = root._parent._globalTransform:inverseTransformPoint(0,0)
         local hit = root.m3d:rayIntersectionAABB(pos[1], pos[2], pos[3], x, y, z)

         if hit then
            print(root.name, root._parent.name, hit)
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


function getRayAt(x,y)
   local w,h = love.graphics.getDimensions()

   local ndcX = -1 + 2 * x / w 
   local ndcY = 1 - 2 * y / h

   local lineStart = {ndcX, ndcY, -1.0, 1}
   local lineEnd = {ndcX, ndcY, 1.0, 1}

   local v = cpml.mat4.new(g3d.camera.viewMatrix)
   local p = cpml.mat4.new(g3d.camera.projectionMatrix)
      
   local tmp = cpml.mat4.new()
   tmp:mul(p, v):invert(tmp)


   cpml.mat4.mul_vec4(lineStart, tmp, lineStart)
   cpml.mat4.mul_vec4(lineEnd, tmp, lineEnd)

   --print(inspect(lineStart), inspect(lineEnd))

   local s = cpml.vec3(lineStart[1], lineStart[2],lineStart[3] )
   local e = cpml.vec3(lineEnd[1], lineEnd[2],lineEnd[3] )

   --print(x,y, '->', s/lineStart[4], e/lineEnd[4])

   return s/lineStart[4], e/lineEnd[4]
end


function love.mousemoved(x,y, dx,dy)
   --https://stackoverflow.com/questions/51375630/screenpointtoray-whats-behind-the-function

      if love.mouse.isDown( 3 ) then
         g3d.camera.firstPersonLook(dx,dy)
      else
         love.mouse.setRelativeMode(false)
      end
      
      local v = cpml.mat4.new(g3d.camera.viewMatrix)
      local p = cpml.mat4.new(g3d.camera.projectionMatrix)
      
      local mx, my = love.mouse.getPosition()
      local s,e = getRayAt(mx,my)
      local es = e - s
      
      local pos = g3d.camera.position
      local x,y,z = g3d.camera:getLookVector()
      --print(x,y,z, (e-s), es)
      --local v = cpml.vec3(x,y,z)
      --local n = es + v
      --print(mx,my,es,n,inspect(pos))
      --local result = (cpml.mat4.unproject({x=mx, y=my, z=pos[3]}, v, p, {0,0,1024,768}))
      --print(result)
      --g3d.camera.lookAt(x,y,z, n.x,n.y,n.z)
      
      --print(n, x,y,z)
      local hit = Earth:rayIntersectionAABB(pos[1], pos[2], pos[3], e.x,e.y,e.z)

      --local hit = Earth:rayIntersectionAABB(pos[1],pos[2],pos[3], n.x, n.y, n.z)
      Earth.hit = hit


      local hit = Moon:rayIntersectionAABB(pos[1], pos[2], pos[3], x, y, z)
      Moon.hit = hit

      recursiveRayIntersection(root, x,y,z, pos)

   --


   -- 

   -- local v = cpml.mat4.new(g3d.camera.viewMatrix)
   -- local p = cpml.mat4.new(g3d.camera.projectionMatrix)
   -- local ip = p:invert(p)
   -- local vp =  cpml.mat4.new(v * p)
   -- local ivp = vp:invert(vp)
   -- --print(vp)
   -- --cpml.mat4.invert(ip, g3d.camera.projectionMatrix)
   -- local mx, my = love.mouse.getPosition()
   -- local s,e = getRayAt(mx,my)
   -- print(s, e)

   -- function getLookVector(target, position)
   --  local vx = target.x - position.x
   --  local vy = target.y - position.y
   --  local vz = target.z - position.z
   --  local length = math.sqrt(vx^2 + vy^2 + vz^2)

   --  -- make sure not to divide by 0
   --  if length > 0 then
   --     return vx/length, vy/length, vz/length
   --  end
   --  return vx,vy,vz
   -- end

   --local looksie = getLookVector(e, s)
   --print(looksie)
  -- print(s - e)
   --print(s, e)
   --print(mx,my)
   --local result = (cpml.mat4.unproject({x=1024/2, y=768/2, z=1}, v, p, {0,0,1024,768}))
   --result = result * cpml.vec3.new(mx,my,1)
   --local result2 = (cpml.mat4.unproject({x=mx, y=my, z=1}, v, p, {0,0,1024,768}))

  -- print(result2)
   --print(result - result2)
   --print('unporejct call', result)
   --print((ip) * result)
   
   --local ok = result --- cpml.vec3.new(pos[1], pos[2], pos[3])
   --local ok = result
   --ok = cpml.vec3.normalize(ok)
   --print(vp * ok)


   --print(inspect(g3d.camera.target))
   ---

  
   -- local x,y,z = getLookVector(e,s)
  -- print('look1', x,y,z)
   --local dir = s - e
   --dir = cpml.vec3.normalize(dir)
   --print(x,y,z, dir.x,dir.y,dir.z)
   --x = dir.x
   --y = dir.y
   --z = dir.z
   --print('look2', x,y,z)

   --local x = ok.x
   ---local y = ok.y
   --local z = ok.z
   --print(cpml.vec3.normalize(result), x,y,z)
   --print()
   --print('x', ok.x,  x)
   --print('y', ok.y,  y)
   --print('z', ok.z,  z)

      --print('look', x,y,z)
     

   ---

   --local t = cpml.vec3(pos) - cpml.vec3(result)
   --Earth:setTranslation(t.x, t.y, t.z +2)

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
    makeScaleFit(root, 1.0/100)

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
   local mx, my = love.mouse.getPosition()
   love.graphics.setColor(1,1,1)
   if Earth.hit then love.graphics.setColor(1,0,0) end

   Earth:draw()
   love.graphics.setColor(1,1,1)
   if Moon.hit then love.graphics.setColor(1,0,0) end
   Moon:draw()
   love.graphics.setColor(1,1,1)


    --Background:draw()
    love.graphics.setShader(shader)
    renderThings3d(root)

    -- debug draw
    
    --love.graphics.setShader()
    --love.graphics.rectangle('fill', 0,0,100,100)


    local s,e = getRayAt(mx,my)
    local diff = e - s
    --print(diff)
    local p = g3d.camera.position
    --local p = {s.x,s.y,s.z}
    local e2 = {x=p[1]+diff.x, y=p[2]+diff.y, z=p[3]+diff.z }
    --local t = {e.x,e.y,e.z}
    local t = g3d.camera.target
    --local x,y,z = g3d.camera:getLookVector()



   -- local plane = makePlane(p[1],p[2],p[3],t[1],t[2],t[3])


    --local t1  = {{p[1], p[2]-2, p[3]}, {p[1], p[2]+2, p[3]},  {t[1], t[2], t[3]+2}}
    -- local t1  = {{t[1], t[2]-.10, t[3]}, {t[1], t[2]+.10, t[3]},  {p[1]+.04, p[2], p[3]}}
    -- local t2  = {{t[1]-.10, t[2], t[3]}, {t[1]+.10, t[2], t[3]},  {p[1], p[2], p[3] +.4}}
    -- local t12 = {{t[1], t[2]-.10, t[3]}, {t[1], t[2]+.10, t[3]},  {p[1]+.04, p[2], p[3]}, {t[1]-.10, t[2], t[3]}, {t[1]+.10, t[2], t[3]},  {p[1], p[2], p[3] +.4}}
    --print(inspect(p))
    -- print(inspect(plane), inspect(t12))


    local t = g3d.newModel("assets/cube.obj", nil, {t[1], t[2], t[3]}, nil, {1,1,1})
    local p = g3d.newModel("assets/cube.obj", nil, {p[1], p[2], p[3]}, nil, {1,1,1})

     local s1 = g3d.newModel("assets/cube.obj", nil, {s.x, s.y, s.z}, nil, {1,1,1})
     local e1 = g3d.newModel("assets/cube.obj", nil, {e.x, e.y, e.z}, nil, {1,1,1})
      --local e1 = g3d.newModel("assets/cube.obj", nil, {e2.x, e2.y, e2.z}, nil, {1,1,1})

    --local m = g3d.newModel(plane, nil, {0,0,0})
    love.graphics.setWireframe(true)
    love.graphics.setColor(1,0,0)
    t:draw()
    love.graphics.setColor(1,0,1)
    p:draw()
    love.graphics.setColor(0,1,1)
    s1:draw()
    love.graphics.setColor(0,1,0)
    e1:draw()

    love.graphics.setWireframe(false)

     --love.graphics.setColor(1,1,1)


    love.graphics.setShader()


    love.graphics.setColor(1,1,1)
    love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 0, 30)

    love.graphics.rectangle('fill', (1024/2), (768/2) - 4.5,1,10)
    love.graphics.rectangle('fill', (1024/2) - 4.5, (768/2) ,10,1)
end

function makePlane(x1,y1,z1,x2,y2,z2)
   -- id have to return 2 triangles

  --  ....x....
  -- ...     .
  -- . ...   .
  -- .    .. .
  -- .      ..
  -- .. .x2......
   local w = .1
   return {
      {x1,y1-w,z1}, {x1,y1+w,z1}, {x2+w, y2, z2},
      {x1,y1-w,z1},{x2,y2+w,z2},{x2+w,y2,z2}
   }

end

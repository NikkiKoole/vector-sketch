-- written by groverbuger for g3d
-- january 2021
-- MIT license

g3d = require "g3d"
cpml = require 'cpml'
inspect = require 'inspect'

function love.keypressed(k)
   if k == "escape" then love.event.quit() end
end

function love.load()
   Earth = g3d.newModel("assets/sphere.obj", "assets/earth.png", {1,0,4})
   Cubes = {}
   for i = 1, 250 do
      Cubes[i] = g3d.newModel("assets/cube.obj", nil, {love.math.random()*50 - 25, love.math.random()*50 - 25,4})
   end
   --Cube2 = g3d.newModel("assets/cube.obj", nil, {-15,0,4})
   
   Moon = g3d.newModel("assets/sphere.obj", "assets/moon.png", {5,0,4}, nil, {0.5,0.5,0.5})
   Background = g3d.newModel("assets/sphere.obj", "assets/starfield.png", {0,0,0}, nil, {500,500,500})
   Timer = 0
end

function love.mousemoved(x,y, dx,dy)
    if love.mouse.isDown(1) or love.mouse.isDown(3) then
       g3d.camera.firstPersonLook(dx,dy)
    else
       love.mouse.setRelativeMode(false)
    end
    local mx, my = love.mouse.getPosition()
    local pos = g3d.camera.position
    local x,y,z = g3d.camera:getMouseLookVector(mx,my)
    local xo,yo,zo = g3d.camera:getLookVector(mx,my)
    
    Earth.hit = Earth:rayIntersectionAABB(pos[1], pos[2], pos[3], x,y,z)
    Moon.hit =  Moon:rayIntersectionAABB(pos[1], pos[2], pos[3], x, y, z) 

    for i = 1, #Cubes do
       Cubes[i].hit = Cubes[i]:rayIntersectionAABB(pos[1], pos[2], pos[3], x, y, z)
       Cubes[i].hito = Cubes[i]:rayIntersectionAABB(pos[1], pos[2], pos[3], xo, yo, zo) 
    end
    
end

function love.update(dt)
    Timer = Timer + dt
    Moon:setTranslation(math.cos(Timer)*5, 0, math.sin(Timer)*5 +4)
    Moon:setRotation(0,-1*Timer,0)
    g3d.camera.firstPersonMovement(dt)
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


   local s = cpml.vec3(lineStart[1], lineStart[2],lineStart[3] )
   local e = cpml.vec3(lineEnd[1], lineEnd[2],lineEnd[3] )

   return s/lineStart[4], e/lineEnd[4]
end



function love.draw()
   local w,h = love.graphics.getDimensions()
   local mx, my = love.mouse.getPosition()

   love.graphics.clear(1,1,1)
   
   love.graphics.setColor(1,1,1)
   if Earth.hit then love.graphics.setColor(1,0,0) end
   Earth:draw()

   love.graphics.setColor(1,1,1)
   if Moon.hit then love.graphics.setColor(1,0,0) end

   Moon:draw()

   for i = 1, #Cubes do
      love.graphics.setColor(1,1,1, .7)
      if Cubes[i].hit and Cubes[i].hito then
         love.graphics.setColor(0,1,0, .7)
      else
         if Cubes[i].hit then love.graphics.setColor(1,0,0, .7) end
         if Cubes[i].hito then love.graphics.setColor(1,0,1, .7) end
      end
      Cubes[i]:draw()
   end

   
   
   love.graphics.setColor(1,1,1, 0.7)
   Background:draw()
   love.graphics.setColor(1,1,1,1)

   local p = g3d.camera.position
   local t = g3d.camera.target
    

   --local s, e = getRayAt(mx,my)
   --local diff = e - s  

   --local view = cpml.mat4.new(g3d.camera.viewMatrix)
   --local proj = cpml.mat4.new(g3d.camera.projectionMatrix)
   --local unprojected = (cpml.mat4.unproject({x=mx, y=my, z=-p[3]}, view, proj, {0,0,w,h}))
   --local unprojectedm = (cpml.mat4.unproject({x=w/2, y=h/2, z=-p[3]}, view, proj, {0,0,w,h}))
   --unprojectd = unprojected - unprojectedm
   
   --local lx,ly,lz = g3d.camera:getLookVector()

   local lx2, ly2, lz2 = g3d.camera:getMouseLookVector(mx,my)
   local lx2t, ly2t, lz2t = g3d.camera:getMouseLookTarget(mx,my)
   
   -- local e2 = {x=p[1] + lx + unprojected.x,
   --             y=p[2] + ly + unprojected.y,
   --             z=p[3] + lz + unprojected.z }
   
   
   t = g3d.newModel("assets/cube.obj", nil, {t[1], t[2], t[3]})
   p = g3d.newModel("assets/cube.obj", nil, {p[1], p[2], p[3]})

   --s = g3d.newModel("assets/cube.obj", nil, {s.x, s.y, s.z}, nil, {1,1,1})
   --e = g3d.newModel("assets/cube.obj", nil, {e.x, e.y, e.z}, nil, {1,1,1})
   --e2 = g3d.newModel("assets/cube.obj", nil, {e2.x, e2.y, e2.z}, nil, {1,1,1})
   --l = g3d.newModel("assets/cube.obj", nil, {lx, ly, lz}, nil, {1,1,1})
   --l2 = g3d.newModel("assets/cube.obj", nil, {lx2, ly2, lz2}, nil, {1,1,1})
   l2t = g3d.newModel("assets/cube.obj", nil, {lx2t, ly2t, lz2t}, nil, {1,1,1})
 
   drawWireModelAndName(t, {1,0,0}, "camera.target", 10, 10)
   drawWireModelAndName(p, {0,0,1}, "camera.position", 10, 30)
   
   --drawWireModelAndName(s, {0,1,1}, "ray.start", 10, 50)
   --drawWireModelAndName(e, {1,1,0}, "ray.end", 10, 70)
   --drawWireModelAndName(e2, {1,1,1}, "e2", 10, 90)
   --drawWireModelAndName(l, {1,0,1}, "look", 10, 110)
   --drawWireModelAndName(l2, {0,1,0}, "look2", 10, 130)
   drawWireModelAndName(l2t, {0,1,1}, "look2target", 10, 130)

   
   love.graphics.setWireframe(false)
   love.graphics.setColor(1,1,1)
   love.graphics.circle('line', (w/2), (h/2) , 5)
   drawString([[a block lights up pink if the vanilla collision check is true, 
red if the new mouseposition one hits (which is not correct) 
or green when they hit both]], w-400, 0)
  
   --local nx,ny = getUnitPos(mx,my)
   
   --print(nx *, ny * g3d.camera.fov/2)
   
end

function drawString(str, x, y)
   love.graphics.setColor(0,0,0)
   love.graphics.print(str,x,y)
   love.graphics.setColor(1,1,1)
   love.graphics.print(str,x+1,y+1)

end


 function drawWireModelAndName(model, color, name, nameX, nameY)
      love.graphics.setColor(color[1], color[2], color[3])
      love.graphics.print(name, nameX, nameY)
      love.graphics.setWireframe(true)
      model:draw()
      love.graphics.setWireframe(false)
 end

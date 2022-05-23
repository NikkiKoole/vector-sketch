
-- comes from basics.lua
function getPerpOfLine(x1,y1,x2,y2)
   local nx = x2 - x1
   local ny = y2 - y1
   local len = math.sqrt(nx * nx + ny * ny)
   nx = nx/len
   ny = ny/len
   return ny, nx
end

function distance(x1,y1,x2,y2)
   local nx = x2 - x1
   local ny = y2 - y1
   return math.sqrt(nx * nx + ny * ny)
end
function lerp(v0, v1, t)
   return v0*(1-t)+v1*t
end

function mapInto(x, in_min, in_max, out_min, out_max)
   return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end


function lerpLine(x1,y1, x2,y2, t)
   return {x=lerp(x1, x2, t), y= lerp(y1, y2, t)}
end

function getEllipseWidth(circumf, h)
   return math.sqrt((circumf*circumf) - (2* (h*h))) / math.sqrt(2)
end

function pointInCircle(x,y, cx, cy, cr)
   local dx = x - cx
   local dy = y - cy
   local d  = math.sqrt ((dx*dx) + (dy*dy))

   return cr > d
end


-- end comes from basics

-- comes from rubberhose main
function positionControlPoints(start, eind, hoseLength, flop)
   local pxm,pym = getPerpOfLine(start.x,start.y, eind.x, eind.y)
   pxm = pxm * flop
   pym = pym * -flop
   local d = distance(start.x,start.y, eind.x, eind.y)
   --   print(hoseLength, d)
   local b = getEllipseWidth(hoseLength/math.pi, d)
   local perpL = b /2 -- why am i dividing this?

   local sp2 = lerpLine(start.x,start.y, eind.x, eind.y, borderRadius)
   local ep2 = lerpLine(start.x,start.y, eind.x, eind.y, 1 - borderRadius)

   local startP = {x= sp2.x +(pxm*perpL), y= sp2.y + (pym*perpL)}
   local endP = {x= ep2.x +(pxm*perpL), y= ep2.y + (pym*perpL)}
   return startP, endP
end

-- end comes from rubberhose main


function CreateTexturedCircle(image, segments)
   segments = segments or 40
   local vertices = {}
   
   -- The first vertex is at the center, and has a red tint. We're centering the circle around the origin (0, 0).
   table.insert(vertices, {0, 0, 0.5, 0.5, 255, 255,255})
   
   -- Create the vertices at the edge of the circle.
   for i=0, segments do
      local angle = (i / segments) * math.pi * 2

      -- Unit-circle.
      local x = math.cos(angle)
      local y = math.sin(angle)
      
      -- Our position is in the range of [-1, 1] but we want the texture coordinate to be in the range of [0, 1].
      local u = (x + 1) * 0.5
      local v = (y + 1) * 0.5
      
      -- The per-vertex color defaults to white.
      table.insert(vertices, {x, y, u, v})
   end
   
   -- The "fan" draw mode is perfect for our circle.
   local mesh = love.graphics.newMesh(vertices, "fan")
   mesh:setTexture(image)

   return mesh
end

function createTexturedRectangle(image)
   local w, h = image:getDimensions( )
   --print(w,h)
   local vertices = {}
   -- x,y,u,v,r,g,b,
   --table.insert(vertices, {0,     0,   0.5, 0.5, 0, 0, 0})
   table.insert(vertices, {-w/2, -h/2, 0, 0})
   table.insert(vertices, { w/2, -h/2, 1, 0})
   table.insert(vertices, { w/2,  h/2, 1, 1})
   table.insert(vertices, {-w/2,  h/2, 0, 1})
   --table.insert(vertices, {-w/2, -h/2, 0, 0, 0, 0, 0})


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


function love.keypressed(key)
   if (key == 'escape') then love.event.quit() end
end

function love.mousepressed(mx,my,button)
   if flip == 1 then flip = -1 else flip = 1 end
    for i = 1, #hoses do
      if pointInCircle(hoses[i].start.x, hoses[i].start.y, mx,my,10) then
         hoses[i].start.dragging = true
         return
      end
      if pointInCircle(hoses[i].eind.x, hoses[i].eind.y, mx,my,10) then
         hoses[i].eind.dragging = true
         return
      end
   end
end

function love.mousereleased()
   for i = 1, #hoses do
      hoses[i].start.dragging = false
      hoses[i].eind.dragging = false
   end

end

function love.mousemoved(x,y, dx, dy)
   for i = 1, #hoses do
      if (hoses[i].start.dragging) then
         hoses[i].start.x =hoses[i].start.x  +  dx
         hoses[i].start.y = hoses[i].start.y  + dy
      end
      if (hoses[i].eind.dragging) then
         hoses[i].eind.x =hoses[i].eind.x  +  dx
         hoses[i].eind.y = hoses[i].eind.y  + dy
      end
   end
end



function love.load()
   success = love.window.setMode( 1024,768, {highdpi=true, vsync=false} )

   magic = 4.46

   hoses = {
      {start={x=325, y=125}, eind={x=325, y=400}, hoseLength=550, flop=1}
   }
   borderRadius = 0.25
   lineWidth = 10
   
   
   image = love.graphics.newImage("dogman3.png", {mipmaps=true})
   image:setMipmapFilter( 'nearest', 1 )
   mesh = createTexturedRectangle(image)

   image2 = love.graphics.newImage("kleed2.jpg", {mipmaps=true})
   image2:setMipmapFilter( 'nearest', 1 )
   mesh2 = createTexturedRectangle(image2)

   image3 = love.graphics.newImage("blup.png", {mipmaps=true})
   image3:setMipmapFilter( 'nearest', 1 )
   mesh3 = createTexturedTriangleStrip(image3)
   flip = 1
   time = 0
end




function love.update(dt)
   time = time + dt
end


function love.draw()
   local mx, my = love.mouse.getPosition()
   mx = mx + 400
   love.graphics.clear(.4,.5,.4)

   local w, h = image3:getDimensions( )
   print(w,h)

   local offsetW = math.sin(time*5)*120
   --print(offsetW)
   
   local curveL = love.math.newBezierCurve({0, 0, 0+offsetW, h/2, 0, h})
   local dl = curveL:getDerivative()
   --local curveR = love.math.newBezierCurve({w, 0, w+offsetW, h/2, w, h})
   --local dr = curveR:getDerivative()

   
   
   --local curve = love.math.newBezierCurve({mx, my,  mx+50, my + 100, mx, my + 5})
   for i =1, 1 do


      local count = mesh3:getVertexCount( )

      for j =1, count, 2 do

         local index = (j-1)/ (count-2)
         local xl,yl = curveL:evaluate(index)
         --local xr,yr = curveR:evaluate(index) 

         local dx, dy = dl:evaluate(index)
         local a = math.atan2(dy,dx) + math.pi/2
         local a2 = math.atan2(dy,dx) - math.pi/2

         local line  = 160/2  -- w/2
         local x2 =   xl + line * math.cos(a)
         local y2 =  yl + line * math.sin(a)
         local x3 =   xl + line * math.cos(a2)
         local y3 =  yl + line * math.sin(a2)
         
         love.graphics.line(xl,yl, x2, y2)
         love.graphics.line(xl,yl, x3, y3)


         
         local x, y, u, v, r, g, b, a = mesh3:getVertex(j )
         mesh3:setVertex(j, {x2, y2, u,v})
         x, y, u, v, r, g, b, a = mesh3:getVertex(j +1)
         mesh3:setVertex(j+1, {x3, y3, u,v})
      end
      
      --love.graphics.draw(mesh2, mx, my, 0, flip, .5)
      --love.graphics.draw(mesh2, mx+488, my, 0, flip, .5)
      love.graphics.draw(mesh, mx, my, 0, flip, 1)

      --mesh3:setVertex(1, {0, 0})
      --local x, y, u, v, r, g, b, a = mesh3:getVertex( 2 )
      --mesh3:setVertex(2, {x, y + love.math.random()*20 -10, u,v})
      love.graphics.draw(mesh3, mx, my, 0, .5, .5)
      love.graphics.draw(mesh3, mx+100, my, 0, .5, .5)

   end


   love.graphics.line(curveL:render())
   --love.graphics.line(curveR:render())

   --	love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)

   local stats = love.graphics.getStats()
   love.graphics.print('fps: '..tostring(love.timer.getFPS( )).." "..'#draws: '..stats.drawcalls, 10, 10)





   for i = 1, #hoses do
      local hose = hoses[i]
      local start = hose.start
      local cp, cp2 =  positionControlPoints(hose.start, hose.eind, hose.hoseLength, hose.flop)
      local eind = hoses[i].eind
      local d = distance(start.x,start.y, eind.x, eind.y)
      local curve = love.math.newBezierCurve({start.x,start.y,cp.x,cp.y,cp2.x,cp2.y,eind.x,eind.y})
      love.graphics.setColor(1,0,0)
      love.graphics.circle('fill', start.x, start.y, 10)

      love.graphics.setColor(1,0,0)
      love.graphics.circle('fill', eind.x, eind.y, 10)

      love.graphics.setColor(1,1,1)
--      love.graphics.setLineWidth(lineWidth)

      local feetLength = 40
      if hose.flop > 0 then
	 feetLength = feetLength * -1
      end


      if (tostring(cp.x) == 'nan') then
         -- i want the linewidth to be stretchy
         --print(d, hoseLength/magic)
         local dd = mapInto(d - hose.hoseLength/magic, 0, 100, lineWidth, 1)
         if dd < 1 then dd = 1 end
         love.graphics.setLineWidth(dd)
         love.graphics.setColor(1,.5,.5)
         love.graphics.line(start.x, start.y, eind.x, eind.y)
         love.graphics.setColor(1,1,1)
         love.graphics.setLineWidth(5)
         local ex = eind.x
         local ey = eind.y
         local dx = eind.x - start.x
         local dy = eind.y - start.y
         local angle = math.atan2(dy,dx) + math.pi/2  -- why isnt this the same as teh one

         local ex2 = ex + feetLength * math.cos(angle);
         local ey2 = ey + feetLength * math.sin(angle);
         love.graphics.line(ex,ey,ex2,ey2)
      else
         local c = curve:render()
         love.graphics.line(c)

         love.graphics.setLineWidth(5)
         love.graphics.setColor(1,1,1)


      end


      
   end
   



   
   --	print('#images', stats.images)-
   --	print('img mem', stats.texturememory)-
   --	print('#draw calls', stats.drawcalls)
   --	print(stats.drawcallsbatched)

end




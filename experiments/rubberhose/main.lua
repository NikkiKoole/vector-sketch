-- inspired by https://www.battleaxe.co/rubberhose
Vector = require "brinevector"
local inspect = require 'inspect'


Segment = {}
Segment.__index = Segment


function Segment:create(x,y,angle, length)
   local s = {}             -- our new object
   setmetatable(s,Segment)  -- make Account handle lookup
   s.a = Vector(x,y)      -- initialize our object
   s.b = Vector(x,y)
   s.angle = angle
   s.length = length
   return s
end
function Segment:updateB()
   local dx = self.length * math.cos(self.angle)
   local dy = self.length * math.sin(self.angle)
   self.b.x = self.a.x + dx
   self.b.y = self.a.y + dy
end
function Segment:setA(x,y)
   self.a = Vector(x,y)
end

function Segment:follow(tx, ty)
   local target = Vector(tx, ty)
   local dir = target - self.a
   self.angle = dir:getAngle()
   dir = dir:getNormalized()*self.length * -1
   self.a = target + dir
   --print(dir:getNormalized()*self.length * -1)
end






function love.keypressed(k)
   if k == 'escape' then
      love.event.quit()
   end
end

function mapInto(x, in_min, in_max, out_min, out_max)
   return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end


function pointInRect(x,y, rx, ry, rw, rh)
   if x < rx or y < ry then return false end
   if x > rx+rw or y > ry+rh then return false end
   return true
end

function pointInCircle(x,y, cx, cy, cr)
   local dx = x -cx
   local dy = y -cy
   local d  = math.sqrt ((dx*dx) + (dy*dy))
   return cr > d
end

function handleMouseClickStart()
   mouseState.hoveredSomething = false
   mouseState.down = love.mouse.isDown(1 )
   mouseState.click = false
   mouseState.released = false
   if mouseState.down ~= mouseState.lastDown then
      if mouseState.down  then
         mouseState.click  = true
      else
	 mouseState.released = true
      end
   end
   mouseState.lastDown =  mouseState.down
end

function getUIRect(id, x,y,w,h)
  local result = false
  if mouseState.click then
     local mx, my = love.mouse.getPosition( )
     if pointInRect(mx,my,x,y,w,h) then
        result = true
     end
   end
  
   return {
      clicked=result
   }
end


function h_slider(id, x, y, width, v, min, max)
   love.graphics.setColor(0.3, 0.3, 0.3)
   love.graphics.rectangle('fill',x,y+8,width,3 )
   love.graphics.setColor(0, 0, 0)
   local xOffset = mapInto(v, min, max, 0, width-20)
   love.graphics.rectangle('fill',xOffset + x,y,20,20 )
   love.graphics.setColor(1,1,1,1)
   love.graphics.rectangle("line", xOffset + x,y,20,20)

   local result= nil
   local draggedResult = false
   local mx, my = love.mouse.getPosition( )
   local hover = false
   
   if pointInRect(mx,my, xOffset+x,y,20,20) then
      hover = true
   end

   if hover then
      mouseState.hoveredSomething = true
      love.mouse.setCursor(cursors.hand)
      if mouseState.click then
         lastDraggedElement = {id=id}
	 mouseState.hoveredSomething = true
	 mouseState.offset = {x=(xOffset+x) - mx, y=my-y}
      end
      love.graphics.setColor(.7,.8,0,1)
      love.graphics.rectangle("line", xOffset + x,y,20,20)
      love.graphics.setColor(1,1,1,1)
   end

   if love.mouse.isDown(1 ) then
      if lastDraggedElement and lastDraggedElement.id == id then
	 mouseState.hoveredSomething = true
	 love.mouse.setCursor(cursors.hand)
         local mx, my = love.mouse.getPosition( )
         result = mapInto(mx + mouseState.offset.x, x, x+width-20, min, max)
	 if result < min then
	    result = nil
	 else
         result = math.max(result, min)
         result = math.min(result, max)
	 end
      end
   end
   
   return {
      value=result
   }
end

function positionLegsFromBody()
   local w2 = body.w*7/9
   local h2 = body.h*6/9
   
   hoses[1].start.x = body.x - w2
   hoses[1].start.y = body.y + h2
   hoses[1].eind.x = body.x  - w2
   hoses[1].eind.y = body.y + h2 + hoses[1].hoseLength/magic

   hoses[2].start.x = body.x  + w2
   hoses[2].start.y = body.y  + h2
   hoses[2].eind.x = body.x  + w2
   hoses[2].eind.y = body.y + h2 + hoses[1].hoseLength/magic
end



                      

function love.load()
   love.window.setMode(1024, 768, {resizable=true, vsync=false, minwidth=400, minheight=300})

   body = {x=1024/2,y=768/2, w=40,h=70,rotation=0}
   magic = 4.46
   hoses = {
      {start={x=325, y=125}, eind={x=325, y=400},  hoseLength = 550},
      {start={x=425, y=125}, eind={x=425, y=400},  hoseLength = 550}
   }
   positionLegsFromBody()
   mouseState = {
      hoveredSomething = false,
      down = false,
      lastDown = false,
      click = false,
      offset = {x=0, y=0}
   }
   lastDraggedElement = {}
    cursors = {
      hand= love.mouse.getSystemCursor("hand"),
      arrow= love.mouse.getSystemCursor("arrow")
   }

   
   borderRadius = 0
   lineWidth = 10
   flop = -1

   ----
   -- ik stuff

  
   segments = {}
   for i = 1, 10 do
      segments[i] = Segment:create(200,300,0,15)
   end

   --segments2 = {}
   --for i = 1, 20 do
   --   segments2[i] = Segment:create(200,300,0,20)
   --end
  
end

function isInCircle(x,y, x2,y2,r)
    local dx = x - x2
    local dy = y - y2
    local distance = math.sqrt( (dx*dx) + (dy*dy))
    if distance < r then
       return true
    end
    return false
end


function love.mousepressed(mx, my)
   for i = 1, #hoses do
      if isInCircle(hoses[i].start.x, hoses[i].start.y, mx,my,10) then
         hoses[i].start.dragging = true
         return
      end
      if isInCircle(hoses[i].eind.x, hoses[i].eind.y, mx,my,10) then
         hoses[i].eind.dragging = true
         return
      end
   end
end

function love.mousereleased()
   lastDraggedElement = nil
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

function love.update()
  
end


function getPerpOfLine(x1,y1,x2,y2)
    local nx = x2 - x1
    local ny = y2 - y1
    local len = math.sqrt(nx * nx + ny * ny) 
    nx = nx/len
    ny = ny/len
    return flop * ny, -flop * nx
end

function distance(x1,y1,x2,y2)
   local nx = x2 - x1  
   local ny = y2 - y1 
   return math.sqrt(nx * nx + ny * ny)
end

function lerp(v0, v1, t) 
  return (1 - t) * v0 + t * v1
end

function lerpLine(x1,y1, x2,y2, t)
   return {x=lerp(x1, x2, t), y= lerp(y1, y2, t)}
end

function getEllipseCircumference(w, h)
   return 2 * math.pi * math.sqrt(((w*w) + (h*h))/2)
end

function getEllipseWidth(circumf, h) 
   return math.sqrt((circumf*circumf) - (2* (h*h))) / math.sqrt(2)
end


function pointInEllipse (px, py, cx, cy, rx, ry, rotation) 
    local rotation = rotation or 0
    local cos = math.cos(rotation)
    local sin = math.sin(rotation)
    local dx  = (px - cx)
    local dy  = (py - cy)
    local tdx = cos * dx + sin * dy
    local tdy = sin * dx - cos * dy

    return (tdx * tdx) / (rx * rx) + (tdy * tdy) / (ry * ry) <= 1;
end


function positionControlPoints(start, eind, hoseLength)
   local pxm,pym = getPerpOfLine(start.x,start.y, eind.x, eind.y)
   local d = distance(start.x,start.y, eind.x, eind.y)
   local b = getEllipseWidth(hoseLength/math.pi, d)
   local perpL = b/2 -- why am i dividing this?

   local sp2 = lerpLine(start.x,start.y, eind.x, eind.y, borderRadius)
   local ep2 = lerpLine(start.x,start.y, eind.x, eind.y, 1 - borderRadius)
   
   local startP = {x= sp2.x +(pxm*perpL), y= sp2.y + (pym*perpL)}
   local endP = {x= ep2.x +(pxm*perpL), y= ep2.y + (pym*perpL)}
   return startP, endP
end

 -- function doIk(segments)
 --   local last = segments[#segments]
 --   last:updateB()
 --   last:follow(mx,my)
 --   last:updateB()
   
 --   for i = #segments-1, 1 , -1 do
 --      segments[i]:follow( segments[i+1].a.x, segments[i+1].a.y)
 --      segments[i]:updateB()
 --   end

 --   segments[1]:setA(400,400)
 --   segments[1]:updateB()
   
 --   for i = 2, #segments do
 --       segments[i]:setA(segments[i-1].b.x, segments[i-1].b.y)
 --       segments[i]:updateB()
 --   end
   
   
 --   for i = 1, #segments do
 --      love.graphics.setColor(1,i * 0.1,i * 0.1)
 --      love.graphics.line(segments[i].a.x,
 --                         segments[i].a.y,
 --                         segments[i].b.x,
 --                         segments[i].b.y)
 --   end
 --   return segments
 --   end

function love.draw()
   
   handleMouseClickStart()

   --- some ui
   love.graphics.print('hose length: '..hoses[1].hoseLength, 30, 30 - 20)
   local slider = h_slider('hose', 30, 30, 100, hoses[1].hoseLength, 0,800)
   if slider.value ~= nil then
      hoses[1].hoseLength = slider.value
      hoses[2].hoseLength = slider.value
      positionLegsFromBody()
   end
   love.graphics.print('border radius: '..borderRadius, 30, 70 - 20)
   slider = h_slider('bradius', 30, 70, 100, borderRadius, -2, 2)
   if slider.value ~= nil then
      borderRadius = slider.value
   end
   love.graphics.print('line width: '..lineWidth, 30, 110 - 20)
   slider = h_slider('lw', 30, 110, 100, lineWidth, 0.1, 100)
   if slider.value ~= nil then
      lineWidth = slider.value
   end
   love.graphics.print('flop: '..flop, 30, 150 - 20)
   slider = h_slider('flop', 30, 150, 100, flop, -1, 1)
   if slider.value ~= nil then
      flop = slider.value
   end
   love.graphics.print('body w: '..body.w, 30, 190 - 20)
   slider = h_slider('bodyw', 30, 190, 100, body.w, 1, 100)
   if slider.value ~= nil then
      body.w = slider.value
      positionLegsFromBody()
   end

  local mx, my = love.mouse.getPosition()

   
   love.graphics.setColor(0,1,.5)

   if pointInEllipse (mx, my, body.x, body.y, body.w, body.h, body.rotation) then
      love.graphics.setColor(1,1,.5)

   end

 
   love.graphics.ellipse( 'fill', body.x, body.y, body.w, body.h)


   

 



   

   

   love.graphics.setColor(1,0,0)


   local last = segments[#segments]
   last:updateB()
   last:follow(mx,my)
   last:updateB()
   
   for i = #segments-1, 1 , -1 do
      segments[i]:follow( segments[i+1].a.x, segments[i+1].a.y)
      segments[i]:updateB()
   end


   -- this is like a robot arm attached to pos
   --segments[1]:setA(400,400)
   --segments[1]:updateB()
   
   -- for i = 2, #segments do
   --     segments[i]:setA(segments[i-1].b.x, segments[i-1].b.y)
   --     segments[i]:updateB()
   -- end

   -- this is like a rope attahced to mouse
   for i = 1, #segments do
      segments[i]:setA(segments[i].a.x,segments[i].a.y + 2)
      segments[1]:updateB()
   end
   
   for i = 1, #segments do
      love.graphics.setColor(1,i * 0.1,i * 0.1)
      love.graphics.line(segments[i].a.x,
                         segments[i].a.y,
                         segments[i].b.x,
                         segments[i].b.y)
   end


   
   
   
   for i = 1, #hoses do
      local hose = hoses[i]
      local start = hose.start
      local cp, cp2 =  positionControlPoints(hose.start, hose.eind, hose.hoseLength)
      local eind = hoses[i].eind
      local d = distance(start.x,start.y, eind.x, eind.y)
      local curve = love.math.newBezierCurve({start.x,start.y,cp.x,cp.y,cp2.x,cp2.y,eind.x,eind.y})
      love.graphics.setColor(1,0,0)
      love.graphics.circle('fill', start.x, start.y, 10)

      love.graphics.setColor(1,0,0)
      love.graphics.circle('fill', eind.x, eind.y, 10)

      love.graphics.setLineWidth(lineWidth)
     
      local feetLength = 40

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

          local bx, by = curve:evaluate(.6)
          local ex, ey = curve:evaluate(1)

          --local derivate = curve:getDerivative()
          --local dx, dy = derivate:evaluate(1)

          local dx = ex - bx
          local dy = ey - by
          local angle = math.atan2(dy,dx)  +math.pi/2 --  here

          local ex2 = ex + feetLength * math.cos(angle);
          local ey2 = ey + feetLength * math.sin(angle);
          love.graphics.line(ex,ey,ex2,ey2)
      end
       love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 200)

      -- the feet 
     

   end
end

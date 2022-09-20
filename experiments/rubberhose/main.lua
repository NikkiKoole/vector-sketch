package.path = package.path .. ";../../?.lua"

-- inspired by https://www.battleaxe.co/rubberhose
-- todo have a lok at FABRIK
-- https://www.youtube.com/watch?v=UNoX65PRehA&t=1180s
-- https://github.com/datlass/fabrik-ik-motor6d/blob/master/src/ReplicatedStorage/LimbChain/FabrikSolver.lua

local inspect = require 'vendor.inspect'
require 'lib.basics'
require 'lib.toolbox'
require 'lib.ui'
require 'lib.segment'
require 'lib.poly'

local numbers = require 'lib.numbers'

require 'lib.polyline'


function love.keypressed(k)
   if k == 'escape' then
      love.event.quit()
   end
end


function love.load()
   body = {x=1024/2,y=768/2, w=40,h=70,rotation=0}
   magic = 4.46
   hoses = {
      {start={x=325, y=125}, eind={x=325, y=400},  hoseLength = 550, flop=1},
      {start={x=425, y=125}, eind={x=425, y=400},  hoseLength = 550, flop=-1}
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
   --flop = -1
   dt = 0

   segments = {}
   for i = 1, 23 do
      segments[i] = Segment:create(200,300,0,12)
   end

end


function love.mousepressed(mx, my)
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

function love.update(dt2)
   dt = dt2
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




function love.draw()

   handleMouseClickStart()

   --- some ui
   love.graphics.print('hose length: '..hoses[1].hoseLength, 30, 30 - 20)
   local slider = h_slider('hose', 30, 30, 200, hoses[1].hoseLength, 0,800)
   if slider.value ~= nil then
      hoses[1].hoseLength = slider.value
      hoses[2].hoseLength = slider.value
      positionLegsFromBody()
   end
   love.graphics.print('border radius: '..borderRadius, 30, 70 - 20)
   slider = h_slider('bradius', 30, 70, 200, borderRadius, -2, 2)
   if slider.value ~= nil then
      borderRadius = slider.value
   end
   love.graphics.print('line width: '..lineWidth, 30, 110 - 20)
   slider = h_slider('lw', 30, 110, 100, lineWidth, 0.1, 100)
   if slider.value ~= nil then
      lineWidth = slider.value
   end
   love.graphics.print('flop1: '.. hoses[1].flop, 30, 150 - 20)
   slider = h_slider('flop1', 30, 150, 100, hoses[1].flop, -1, 1)
   if slider.value ~= nil then
      hoses[1].flop = slider.value
   end
   love.graphics.print('flop2: '..hoses[2].flop, 30, 190 - 20)
   slider = h_slider('flop2', 30, 190, 100, hoses[2].flop, -1, 1)
   if slider.value ~= nil then
      hoses[2].flop = slider.value
   end

   love.graphics.print('body w: '..body.w, 30, 230 - 20)
   slider = h_slider('bodyw', 30, 230, 100, body.w, 1, 100)
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

   love.graphics.setLineWidth(10)

   love.graphics.setColor(1,0,0)

   local robot = false

   local last = segments[#segments]
   last:follow(mx,my)
   last:updateB()

   for i = #segments-1, 1 , -1 do
      segments[i]:follow( segments[i+1].a.x, segments[i+1].a.y)
      segments[i]:updateB()
   end



   if robot then

      -- this is like a robot arm attached to pos
      segments[1]:setA(400,400)
      segments[1]:updateB()

      for i = 2, #segments do
         segments[i]:setA(segments[i-1].b.x, segments[i-1].b.y )  -- rmeove the +10dt to get rid of gravity
         segments[i]:updateB()
      end
   else

      --   this is like a rope attahced to mouse
      for i = 1, #segments do
         segments[i]:setA(segments[i].a.x, segments[i].a.y + 600*dt)
         segments[1]:updateB()
      end
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
      local cp, cp2 =  positionControlPoints(hose.start, hose.eind, hose.hoseLength, hose.flop, borderRadius)
      local eind = hoses[i].eind
      local d = distance(start.x,start.y, eind.x, eind.y)
      local curve = love.math.newBezierCurve({start.x,start.y,cp.x,cp.y,cp2.x,cp2.y,eind.x,eind.y})
      love.graphics.setColor(1,0,0)
      love.graphics.circle('fill', start.x, start.y, 10)

      love.graphics.setColor(1,0,0)
      love.graphics.circle('fill', eind.x, eind.y, 10)

      love.graphics.setLineWidth(lineWidth)

      local feetLength = 40
      if hose.flop > 0 then
	 feetLength = feetLength * -1
      end

      if (tostring(cp.x) == 'nan') then
         -- i want the linewidth to be stretchy
         --print(d, hoseLength/magic)
         local dd = numbers.mapInto(d - hose.hoseLength/magic, 0, 100, lineWidth, 1)
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
	  local result = {}
	  local steps = 14
          for i =0, steps do
             --local derivate = curve:getDerivative()
             --local dx, dy = derivate:evaluate(i/10)

             local px, py = curve:evaluate(i/steps)
             love.graphics.setColor(0.5, 1, 0)

             --love.graphics.circle('fill', px, py, 5)
--             love.graphics.setColor(0.5, 1, .5)
  --           love.graphics.circle('fill', dx, dy, 5)

	     table.insert(result, px)
	     table.insert(result, py)
          end
	  --print(inspect(result))
	  --print(#result)
	  local widths = {}
	  for i =1, #result/2 do
	     widths[i] = (#result/2+1)-i
	  end
	  --print(#widths)
	  --widths = {10,10,10,10,10,10,10,10,10,14,
	--	    13,11,10,10,8, 6, 5, 3, 3, 3}
	  local verts, indices, draw_mode = polyline('bevel',result, widths)
	  --print(draw_mode)
	  local mesh = love.graphics.newMesh(simple_format, verts, draw_mode)


	  love.graphics.draw(mesh)
	 -- love.graphics.setColor(0.5, 1, .5)

          --love.graphics.line(curve:renderSegment(0, .75))

      end
       love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 200)

      -- the feet

       -- love.timer.sleep(0.2 )
   end
end




function pointInRect(x,y, rx, ry, rw, rh)
   if x < rx or y < ry then return false end
   if x > rx+rw or y > ry+rh then return false end
   return true
end
function lerp(a, b, t)
   return a + (b - a) * t
end
function mapInto(x, in_min, in_max, out_min, out_max)
   return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end

function rgbbutton(id, rgb, x, y, scale)
   scale = scale or 1
   local mx, my = love.mouse:getPosition()
   local w, h = 64, 64
   local clicked = false

   love.graphics.setColor(rgb[1] ,rgb[2],rgb[3], 1)
   love.graphics.rectangle("fill", x-4*scale, y-4*scale, (8+ w)*scale,(8+ h)*scale)

   if (pointInRect(mx, my,  x-4*scale, y-4*scale, (8+ w)*scale,(8+ h)*scale)) then
      mouseState.hoveredSomething = true
      love.mouse.setCursor(cursors.hand)
      if (mouseState.click) then
	 clicked = true
      end

      love.graphics.setColor(1,1,1,1)
      love.graphics.rectangle("line", x-4*scale, y-4*scale, (8+ w)*scale,(8+ h)*scale)
   end
   if (editingMode == id) then
   end
   if (editingModeSub == id) then
   end

   return {
      clicked = clicked
   }
end



function iconlabelbutton(id, img, color, active, label, x, y, scale)
  
   scale = scale or 1
   local mx, my = love.mouse:getPosition()
   local w, h = img:getDimensions()

   local clicked = false
   local hover = false
   local released = false

   love.graphics.setColor(0,0,0,.75)
   --love.graphics.rectangle("fill", x-4*scale, y-4*scale, (8+ w)*scale,(8+ h)*scale)
   love.graphics.rectangle("fill", x-4*scale, y-4*scale, (8+ w + 500)*scale,(8+ h)*scale)
   love.graphics.setColor(1,1,1,1)
   --
   love.graphics.rectangle("line", x-4*scale, y-4*scale, (8+ w + 500)*scale,(8+ h)*scale)
   if color then
      love.graphics.setColor(color[1],color[2],color[3],1)
      love.graphics.rectangle("fill", x, y, (w*scale),( h * scale))
       love.graphics.setColor(1,1,1,1)
   end


   if (pointInRect(mx, my,  x-4*scale, y-4*scale, (8+ w + 500)*scale,(8+ h)*scale)) then
      mouseState.hoveredSomething = true
      love.graphics.setColor(1,1,1,1)
      love.mouse.setCursor(cursors.hand)
      hover = true
      if (mouseState.click) then
	 clicked = true
      end
      if (mouseState.released) then
	 released = true
      end
   else
      love.graphics.setColor(1,1,1, .5)
   end
   if (editingMode == id) then
      love.graphics.setColor(1,1,1,1)
   end
   if (editingModeSub == id) then
      love.graphics.setColor(1,1,1,1)
   end
   if (active) then
      love.graphics.setColor(1,1,1,1)

   end

   if (disabled) then
      love.graphics.setColor(1,0,1,.5)
      clicked = false
   end

   love.graphics.print(label,  x-4*scale + 64*scale + 16*scale, y-4*scale )
   love.graphics.draw(img, x, y, 0, scale, scale)

   return {
      clicked = clicked,
      hover = hover,
      released = released
   }
end


function imgbutton(id, img, x, y, scale, disabled)
   scale = scale or 1
   local mx, my = love.mouse:getPosition()
   local w, h = img:getDimensions()

   local clicked = false

   love.graphics.setColor(0,0,0,.75)
   love.graphics.rectangle("fill", x-4*scale, y-4*scale, (8+ w)*scale,(8+ h)*scale)
   love.graphics.setColor(1,1,1,1)
   love.graphics.rectangle("line", x-4*scale, y-4*scale, (8+ w)*scale,(8+ h)*scale)

   if (pointInRect(mx, my,  x-4*scale, y-4*scale, (8+ w)*scale,(8+ h)*scale)) then
      mouseState.hoveredSomething = true
      love.graphics.setColor(1,1,1,.5)
      love.mouse.setCursor(cursors.hand)
      if (mouseState.click) then
	 clicked = true
      end
   else
      love.graphics.setColor(1,1,1, .3)
   end
   if (editingMode == id) then
      love.graphics.setColor(1,1,1,1)
   end
   if (editingModeSub == id) then
      love.graphics.setColor(1,1,1,1)
   end
   if (disabled) then
      love.graphics.setColor(1,0,1,.3)
      clicked = false

   end

   love.graphics.draw(img, x, y, 0, scale, scale)

   return {
      clicked = clicked
   }
end
function v_slider(id, x, y, height, v, min, max)
   love.graphics.setColor(0.3, 0.3, 0.3)
   love.graphics.rectangle('fill',x+8,y,3,height )
   love.graphics.setColor(0, 0, 0)
   local yOffset = mapInto(v, min, max, 0, height)
   love.graphics.rectangle('fill',x, yOffset + y,20,20 )
   love.graphics.setColor(1,1,1,1)
   love.graphics.rectangle("line", x,yOffset + y,20,20)

   local result= nil
   local draggedResult = false
   local mx, my = love.mouse.getPosition( )
   local hover = false
   if pointInRect(mx,my, x, yOffset +y,20,20) then
      hover = true
   end

   if hover then
      mouseState.hoveredSomething = true
      love.mouse.setCursor(cursors.hand)
      if mouseState.click then
         lastDraggedElement = {id=id}
	 mouseState.hoveredSomething = true
      end
   end

   if love.mouse.isDown(1 ) then
      if lastDraggedElement and lastDraggedElement.id == id then
	 mouseState.hoveredSomething = true
	 love.mouse.setCursor(cursors.hand)

         local mx, my = love.mouse.getPosition( )
         result = mapInto(my, y, y+height, min, max)
	 if result < min then
	    result = min
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

function h_slider(id, x, y, width, v, min, max)
   love.graphics.setColor(0.3, 0.3, 0.3)
   love.graphics.rectangle('fill',x,y+8,width,3 )
   love.graphics.setColor(0, 0, 0)
   local xOffset = mapInto(v, min, max, 0, width)
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
      end
   end

   if love.mouse.isDown(1 ) then
      if lastDraggedElement and lastDraggedElement.id == id then
	 mouseState.hoveredSomething = true
	 love.mouse.setCursor(cursors.hand)

         local mx, my = love.mouse.getPosition( )
         result = mapInto(mx, x, x+width, min, max)
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

require 'basics'

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


function rgbbutton(id, rgb, x, y, scale)
   scale = scale or 1
   local mx, my = love.mouse:getPosition()
   local w, h = 48, 48
   local clicked = false

   love.graphics.setColor(rgb[1] ,rgb[2],rgb[3], 1)
   love.graphics.rectangle("fill", x*scale, y*scale, (w)*scale,( h)*scale)

   if (pointInRect(mx, my,  x*scale, y*scale, (w)*scale,( h)*scale)) then
      mouseState.hoveredSomething = true
      love.mouse.setCursor(cursors.hand)
      if (mouseState.click) then
	 clicked = true
      end

      love.graphics.setColor(1,1,1,1)
      love.graphics.rectangle("line", x*scale, y*scale, (8)*scale,(8)*scale)
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

   if (active) then
      love.graphics.setColor(0.2,0.2,0.2,.75)
   else
      love.graphics.setColor(0,0,0,.75)
    end

   --love.graphics.rectangle("fill", x-4*scale, y-4*scale, (8+ w)*scale,(8+ h)*scale)
   love.graphics.rectangle("fill", x-4*scale, y-4*scale, (8+ w + 500)*scale,(8+ h)*scale)
   love.graphics.setColor(1,1,1,1)
   --
    if (active) then
       love.graphics.setLineWidth(3)

    else
       love.graphics.setLineWidth(1)
    end

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
      hover = hover
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
   local yOffset = mapInto(v, min, max, 0, height-20)
   love.graphics.rectangle('fill',x, yOffset + y,20,20 )
   love.graphics.setColor(1,1,1,1)
   love.graphics.rectangle("line", x,yOffset + y,20,20)

   local result= nil
   local draggedResult = false
   local mx, my = love.mouse.getPosition( )
   local hover = false
   if pointInRect(mx,my, x, (yOffset +y),20,20) then
      hover = true
   end

   if hover then
      mouseState.hoveredSomething = true
      love.mouse.setCursor(cursors.hand)
      if mouseState.click then
         lastDraggedElement = {id=id}
	 mouseState.hoveredSomething = true
	 mouseState.offset = {x=x - mx, y=(yOffset+y)-my}
      end
   end

   if love.mouse.isDown(1 ) then
      if lastDraggedElement and lastDraggedElement.id == id then
	 mouseState.hoveredSomething = true
	 love.mouse.setCursor(cursors.hand)

         local mx, my = love.mouse.getPosition( )
         result = mapInto(my + mouseState.offset.y, y, y+height-20, min, max)
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

function joystick(id, x, y, size, vx, vy, min, max)
   love.graphics.setColor(0.3, 0.3, 0.3)
   love.graphics.rectangle('fill',x,y,size,size )
   local result = nil

   local thumbX =  mapInto(vx, min, max, 0, size-20)
   local thumbY =  mapInto(vy, min, max, 0, size-20)
   love.graphics.setColor(0, 0, 0)

   love.graphics.line(x + size/2, y, x + size/2, y + size)
   love.graphics.line(x , y + size/2, x +size, y + size/2)
   love.graphics.rectangle('fill',thumbX + x, thumbY + y,20,20 )
   love.graphics.setColor(1,1,1,1)
   love.graphics.rectangle("line", thumbX + x, thumbY + y,20,20)

   local result= nil
   local draggedResult = false
   local mx, my = love.mouse.getPosition( )
   local hover = false

   if pointInRect(mx,my,  thumbX + x, thumbY + y,20,20) then
      hover = true
   end


   if hover then
      mouseState.hoveredSomething = true
      love.mouse.setCursor(cursors.hand)
      if mouseState.click then
         lastDraggedElement = {id=id}
	 mouseState.hoveredSomething = true

	 mouseState.offset = {x=( thumbX + x) - mx, y=( thumbY + y) - my}
      end
   end

   if love.mouse.isDown(1 ) then
      if lastDraggedElement and lastDraggedElement.id == id then
	 mouseState.hoveredSomething = true
	 love.mouse.setCursor(cursors.hand)
         local mx, my = love.mouse.getPosition( )
         local resultX = mapInto(mx + mouseState.offset.x, x, x+size-20, min, max)
	 local resultY = mapInto(my + mouseState.offset.y, y, y+size-20, min, max)

	 if resultX < min then
	    resultX = min
	 else

	    resultX = math.max(resultX, min)
	    resultX = math.min(resultX, max)
	 end

	 if resultY < min then
	    resultY = min
	 else

	    resultY = math.max(resultY, min)
	    resultY = math.min(resultY, max)
	 end
	 result = {
	    x = resultX, y= resultY
	 }

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

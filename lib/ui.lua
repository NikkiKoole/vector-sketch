--require 'basics'

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
function getUICircle(id, x,y,r)
   local clicked = false
   local hover = false
   local mx, my = love.mouse.getPosition( )

   if pointInCircle(mx, my, x, y, r) then
      hover = true
   end
   if mouseState.click and hover then
      clicked = true
   end

   return {
      clicked=clicked,
      hover=hover
   }
end

function rgbbutton(id, rgb, x, y, scale)
   scale = scale or 1
   local mx, my = love.mouse:getPosition()
   local w, h = 24, 24
   local clicked = false

   love.graphics.setColor(rgb[1] ,rgb[2],rgb[3], 1)
   love.graphics.rectangle("fill", x*scale, y*scale, (w)*scale,( h)*scale)

   if (pointInRect(mx, my,  x*scale, y*scale, (w)*scale,( h)*scale)) then
      mouseState.hoveredSomething = true
      love.mouse.setCursor(cursors.hand)
      if (mouseState.click) then
	 clicked = true
         mouseState.clickedId = id
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

function doubleiconlabelbutton(id, img1,img2, x, y)
   local mx, my = love.mouse:getPosition()
   local img1W, img1H = img1:getDimensions()
   local margin = 16
   local w1 = 24
   local h1 = 24
   local imgScale1 = h1/img1H

   local img2W, img2H = img2:getDimensions()
   local w2 = 24
   local h2 = 24
   local imgScale2 = h2/img2H


   local buttonWidth = w1 +margin + w2

   love.graphics.setColor(0,0,0,.75)
   love.graphics.rectangle("fill", x, y, buttonWidth, h1)
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(img1, x, y, 0, imgScale1, imgScale1)

    love.graphics.draw(img2, x+margin+w1, y, 0, imgScale2, imgScale2)
end


function iconlabelbutton(id, img, color, active, label, x, y, buttonWidth, buttonOffsetHeight)
   local mx, my = love.mouse:getPosition()
   local imgW, imgH = img:getDimensions()
   local w = 24
   local h = 24 + (buttonOffsetHeight or 0)
   local imgScale = h/imgH
   local buttonWidth = buttonWidth or 200
   local clicked = false
   local hover = false
   local fontHeight = love.graphics.getFont():getHeight(label)

   if (active) then
      love.graphics.setColor(0.2,0.2,0.2,.75)
   else
      love.graphics.setColor(0,0,0,.75)
    end

   love.graphics.rectangle("fill", x, y, buttonWidth, h)
   love.graphics.setColor(1,1,1,1)
   --
   if color then
      love.graphics.setColor(color[1],color[2],color[3],1)
      love.graphics.rectangle("fill", x, y, w, h )
      love.graphics.setColor(1,1,1,1)
   end

   if (active) then
      love.graphics.setLineWidth(3)

   else
      love.graphics.setLineWidth(1)
   end



   love.graphics.rectangle("line", x, y, buttonWidth,h)

   if (pointInRect(mx, my,  x, y, buttonWidth,h)) then
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

   love.graphics.print(label,  x + 32 + 4, y + (h- fontHeight)/2 )
   love.graphics.draw(img, x, y, 0, imgScale, imgScale)

   return {
      clicked = clicked,
      hover = hover
   }
end


function imgbutton(id, img, x, y, scale, disabled)
   scale = scale or 1
   local mx, my = love.mouse:getPosition()
   local imgW, h = img:getDimensions()
   local w = 24
   h = 24
   local imgScale = w/imgW

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

   love.graphics.draw(img, x, y, 0, imgScale, imgScale)

   return {
      clicked = clicked
   }
end

function scrollbarV(id, x,y, height, contentHeight, scrollOffset)


   -- the thumb
   local scrollBarThumbH = height
   if contentHeight > height then
      scrollBarThumbH = (height / contentHeight) * height
   end

   local pxScrollOffset = mapInto(scrollOffset, 0, contentHeight-height, 0, height-scrollBarThumbH)

   local result= nil
   local draggedResult = false
   local mx, my = love.mouse.getPosition( )
   local hover = false
   if pointInRect(mx, my, x, y+pxScrollOffset,32,scrollBarThumbH) then
       hover = true
   end

   local alpha =  (lastDraggedElement and lastDraggedElement.id == id or hover ) and 0.8 or 0.5
   love.graphics.setColor(1,1,1,alpha)
   love.graphics.setLineWidth(2)
   love.graphics.rectangle("line",x, y, 32, height)
   love.graphics.rectangle("fill", x, y+pxScrollOffset, 32, scrollBarThumbH)



   if hover then
      mouseState.hoveredSomething = true
      love.mouse.setCursor(cursors.hand)
      if mouseState.click then
         lastDraggedElement = {id=id}
	 mouseState.hoveredSomething = true
	 mouseState.offset = {x=x - mx, y=(pxScrollOffset+y)-my}
      end
   end

    if love.mouse.isDown(1 ) then
      if lastDraggedElement and lastDraggedElement.id == id then
	 mouseState.hoveredSomething = true
	 love.mouse.setCursor(cursors.hand)

         local mx, my = love.mouse.getPosition( )
         result = mapInto(my + mouseState.offset.y,
                          y, y+height-scrollBarThumbH,
                          0, height-scrollBarThumbH)
	 if result < 0 then
	     result = 0
	 end
         if result > height-scrollBarThumbH then
            result = height-scrollBarThumbH
         end

         result = mapInto(result, 0, height-scrollBarThumbH, 0, contentHeight-height )
      end


    end



 return {
    value=result,
    scrollBarThumbH=scrollBarThumbH
   }



end




function v_slider(id, x, y, height, v, min, max)
   love.graphics.setColor(0.3, 0.3, 0.3)
   love.graphics.rectangle('fill',x+8,y,3,height )
   love.graphics.setColor(0, 0, 0)
   local yOffset = mapInto(v, min, max, 0, height-20)
   love.graphics.rectangle('fill',x, yOffset + y,20,20 )


   love.graphics.rectangle("line", x,yOffset + y,20,20)

   local result= nil
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

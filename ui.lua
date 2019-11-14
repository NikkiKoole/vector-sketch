


function pointInRect(x,y, rx, ry, rw, rh)
   if x < rx or y < ry then return false end
   if x > rx+rw or y > ry+rh then return false end
   return true
end



function imgbutton(id, img, x, y, scale)
   scale = scale or 1
   local mx, my = love.mouse:getPosition()
   local w, h = img:getDimensions()
   local clicked = false
   
   if (pointInRect(mx, my, x, y, w*scale, h*scale)) then
      love.graphics.setColor(1,1,1,.5)
		     
      love.mouse.setCursor(cursors.hand)
      if (mouseState.click) then
	 clicked = true
      end
   else
      love.graphics.setColor(1,1,1, .1)
   end
   if (editingMode == id) then
      love.graphics.setColor(1,1,1,.75)
   end
   
   love.graphics.draw(img, x, y, 0, scale, scale)

   return {
      clicked = clicked
   }
end



require 'ui'
require 'basics'

function love.keypressed(key)
   if key == 'escape' then
      love.event.quit()
   end
end

function love.load()
   bgColor = {r,g,b}
   bgColor.r, bgColor.g, bgColor.b = hex2rgb('af9f5e')
   font = love.graphics.newFont( "WindsorBT-Roman.otf", 24)
   love.graphics.setFont(font)

   mouseState = {
      hoveredSomething = false,
      down = false,
      lastDown = false,
      click = false,
      offset = {x=0, y=0}
   }
   cursors = {
      hand= love.mouse.getSystemCursor("hand"),
      arrow= love.mouse.getSystemCursor("arrow")
   }
   activeButton = nil
end

function love.mousereleased()
   if mouseState.hoveredSomething == false then
      activeButton = nil
   end
   
end

function love.draw()
   handleMouseClickStart()
   love.graphics.clear(bgColor.r, bgColor.g, bgColor.b)

   local types = {"file", "prop", "backdrop", "vehicle", "room"}
   local buttonMarginSide = 20
   local buttonHeight = 40
   local runningX = 10
   
   for i = 1, #types do
      if labelbutton(types[i], types[i], runningX, 10, font:getWidth(types[i]) + buttonMarginSide, buttonHeight).clicked then
	 if activeButton == types[i] then
	    activeButton = nil
	 else
	    activeButton = types[i]
	 end
      end

      if activeButton == types[i] then
	 local internalTypes = {"new", "load", "edit", "preferences"}
	 for j = 1, #internalTypes do
	    local id = types[i].." "..internalTypes[j]
	    local width =  math.max( font:getWidth(internalTypes[j]), font:getWidth(types[i])  )+ buttonMarginSide
	    if labelbutton(id, internalTypes[j], runningX, 10+j*buttonHeight, width, buttonHeight).clicked then
	       print(id)
	    end
	 end
      end
      

      runningX = runningX + font:getWidth(types[i]) + buttonMarginSide + buttonMarginSide
   end

end


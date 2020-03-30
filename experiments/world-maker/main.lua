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

   types = {
      ["add"] = {"room", "actor", "object", "decal"},
      ["world"]=  {"edit", "load", "save"},
   }
   order = {"add", "world"}
end

function love.mousereleased()
   if mouseState.hoveredSomething == false then
      activeButton = nil
   end
end

function eventBus(event)
   local calls = {
      ["add room"] = function() print("poep!") end
   }
   if calls[event] then calls[event]() end
end


function drawUI()
   local buttonMarginSide = 20
   local buttonHeight = 40
   local runningX = 10
   
   for i=1, #order do
      local str = order[i]
      local w = font:getWidth(str) + buttonMarginSide
      if labelbutton(str, str, runningX, 10,w , buttonHeight).clicked then
      	 if activeButton == str then
      	    activeButton = nil
      	 else
      	    activeButton = str
      	 end
      end

      if activeButton == str then
      	 for j = 1, #types[str] do
	    local id = str.." "..types[str][j]
	    local width =  math.max( font:getWidth(types[str][j]), font:getWidth(str)  )+ buttonMarginSide
	    if labelbutton(id, types[str][j], runningX, 10+j*buttonHeight, width, buttonHeight).clicked then
	       eventBus(id)
	    end
      	 end
      end
      runningX = runningX + w + buttonMarginSide
   end
end


function love.draw()
   handleMouseClickStart()
   love.graphics.clear(bgColor.r, bgColor.g, bgColor.b)
   drawUI()
end


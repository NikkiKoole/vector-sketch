local mylib = require('tool')
--print(inspect(mylib))
--https://blog.separateconcerns.com/2014-01-03-lua-module-policy.html
--print(getDimensions())

local part=.5

function love.load(arg)
   local w,h = love.graphics.getDimensions()
   mylib:setDimensions(w*part,h)
   mylib:load(arg)
end


function love.draw()
   local w, h = love.graphics.getDimensions( )
   love.graphics.setScissor( 0, 0, w, h )
   love.graphics.clear(.3,0,0)

   mylib:draw()
   love.graphics.setColor(1,1,1,0.5)
   love.graphics.rectangle("fill", w*part,0,20,h)
end

function love.resize(w,h)
   mylib:setDimensions(w*part,h)

end

function love.filedropped(file)
   mylib:filedropped(file)
   --fileDropPopup = file
end

function love.keypressed(key, scancode, isrepeat)
   mylib:keypressed(key, scancode, isrepeat)
end

function love.textinput(t)
   mylib:textinput(t)
end

function love.mousemoved(x,y, dx, dy)
   mylib:mousemoved(x,y, dx, dy)
end

function love.mousereleased(x,y,button)
   mylib:mousereleased(x,y, button)
end

function love.mousepressed(x,y,button)
   local w,h = love.graphics.getDimensions()
   if x <= w*part then
      mylib:mousepressed(x,y, button)
   end
   
end

function love.wheelmoved(x,y)
   mylib:wheelmoved(x,y)
end


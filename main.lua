local mylib = require('tool')
--print(inspect(mylib))
--https://blog.separateconcerns.com/2014-01-03-lua-module-policy.html
--print(getDimensions())

local part=.85


local tw = 290
local th = 180

local root = {
      folder = true,
      name = 'root',
      transforms =  {l={0,0,0,1,1,0,0,0,0}},
      children = {

         {
            folder = true,
            transforms =  {l={0,0,0,1,1,100,0,0,0}},
            name="rood folder",
            children ={
               {
                  name="textured rope:"..1,
                  color = {1,1,1, 1},
                  points = {{200,200},{200,100},{200,0}},
                  --texture = {data='here'},
                  type='line'
	       },
               {
                  name="ropey thing",
                  color={.5,.5,1},
                  points={{200,200}, {300,300}},
                  data={length=100, flop=-1, borderRadius=0, width=10},
                  type='ropey'
               },

	       {
                  name="meta label"..1,
                  type='meta',
                  color = {1,0,0, 0.8},
                  points = {{0,0}},

               },
            },
         },
      }
   }


function love.load(arg)
   img = love.graphics.newImage('experiments/handdrawn-ecs/assets/ding.png', {mipmaps=true})
   img:setWrap( 'repeat' )
   img:setFilter('linear')
   print(inspect(img))

   local w,h = love.graphics.getDimensions()
   mylib:setRoot(root)

   mylib:setDimensions(w*part,h)
   mylib:load(arg)
end


function love.draw()
   local w, h = love.graphics.getDimensions( )
   love.graphics.setScissor( 0, 0, w, h )
   love.graphics.clear(1,1,1)

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

   local w,h = love.graphics.getDimensions()
   if x <= w*part then
      mylib:mousereleased(x,y, button)
   end

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


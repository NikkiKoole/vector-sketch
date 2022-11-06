if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
   require("lldebugger").start()
 end
local mesh = require 'lib.mesh'
local mylib = require('tool')
--print(inspect(mylib))
--https://blog.separateconcerns.com/2014-01-03-lua-module-policy.html
--print(getDimensions())

local part = 0.8


local tw = 290
local th = 180

local magic = 4.46

local root = {
   folder = true,
   name = 'root',
   transforms = { l = { 0, 0, 0, 1, 1, 0, 0, 0, 0 } },

   children = {

      {
         folder = true,
         transforms = { l = { 0, 0, 0, 1, 1, 100, 0, 0, 0 } },
         name = "rood folder",
         children = {
            {
               name = "animals3" .. 1,
               color = { 1, 1, 1, 1 },
               points = { { 200, 200 }, { 202, 100 }, { 200, 0 }, { 100, 100 }, { 300, 200 } },
               texture = {
                  url = 'experiments/handdrawn-ecs/assets/animals3.png',
                  wrap = 'clamp', filter = 'linear', squishable = true
               },
            },
            {
               name = "plant" .. 1,
               color = { 1, 1, 1, 1 },
               points = { { 200, 200 }, { 202, 100 }, { 200, 0 }, { 100, 100 }, { 300, 200 } },
               texture = {
                  url = 'experiments/handdrawn-ecs/assets/plant.png',
                  wrap = 'clamp', filter = 'linear', squishable = true
               },
               data = { width = 45, steps = 15 },
               type = 'bezier'
            },

            {
               name = "house texture squish" .. 1,
               color = { 1, 1, 1, 1 },
               points = { { 250, 250 }, { 200, 200 }, { 300, 200 }, { 300, 300 }, { 300, 200 } },
               texture = {
                  url = 'experiments/handdrawn-ecs/assets/house.png',
                  wrap = 'clamp', filter = 'linear', keepAspect = true, squishable = true
               },
            },
            {
               name = "house texture2" .. 1,
               color = { 1, 1, 1, 1 },
               points = { { 400, 200 }, { 402, 100 }, { 400, 0 } },
               texture = {
                  url = 'experiments/handdrawn-ecs/assets/house.png',
                  wrap = 'repeat', filter = 'linear', keepAspect = true
               },
            },
            {
               name = "rubberhose leg",
               color = { .5, .5, 1, 1 },
               points = { { 200, 200 }, { 1200, 300 } },
               data = { length = 423 * magic, flop = -1, borderRadius = 0, width = 357 * 2, steps = 10 },
               texture = {
                  url = 'experiments/handdrawn-ecs/assets/leg3.png',
                  wrap = 'repeat', filter = 'linear'
               },
               type = 'rubberhose'
            },
            {
               name = "rubberhose ding",
               color = { .5, .5, 1, 1 },
               points = { { 400, 400 }, { 400, 500 } },
               data = { length = 194 * magic, flop = -1, borderRadius = 0.15, width = 45 * 2, steps = 35 },
               texture = {
                  url = 'experiments/handdrawn-ecs/assets/ding3.png',
                  wrap = 'repeat', filter = 'linear'
               },
               type = 'rubberhose'
            },
            {
               name = "beziered",
               color = { .5, .5, .1, 1 },
               points = { { 200, 200 }, { 1200, 300 } },
               data = { width = 45, steps = 15 },
               texture = {
                  url = 'experiments/handdrawn-ecs/assets/leg3.png',
                  wrap = 'repeat', filter = 'linear'
               },
               type = 'bezier'
            },
            {
               name = "beziered",
               color = { .5, .5, .1, 1 },
               points = { { 400, 400 }, { 500, 100 }, { 600, 600 } },
               data = { width = 350, steps = 15 },
               texture = {
                  url = 'experiments/handdrawn/assets/plant.png',
                  wrap = 'repeat', filter = 'linear'
               },

               type = 'bezier'
            },

            {
               name = "meta label" .. 1,
               type = 'meta',
               color = { 1, 0, 0, 0.8 },
               points = { { 0, 0 } },

            },
         },
      },
   }
}





function love.load(arg)

   --img = love.graphics.newImage('experiments/handdrawn-ecs/assets/ding.png', {mipmaps=true})
   --img:setWrap( 'repeat' )
   --img:setFilter('linear')
   --   print(inspect(img))
   mesh.recursivelyMakeTextures(root)
   local w, h = love.graphics.getDimensions()
   print('setting root node to dirty')
   root.dirty = true
   mylib:setRoot(root)

   mylib:resize(w * part, h)
   mylib:load(arg)
end
function love.update()
   require("vendor.lurker").update()
end


function love.draw()
   local w, h = love.graphics.getDimensions()
   love.graphics.setScissor(0, 0, w, h)
   love.graphics.clear(1, 1, 1)

   mylib:draw()
   love.graphics.setColor(1, 1, 1, 0.5)
   love.graphics.rectangle("fill", w * part, 0, 20, h)
end

function love.resize(w, h)
   mylib:resize(w * part, h)

end

function love.filedropped(file)
   mylib:filedropped(file)
end

function love.keypressed(key, scancode, isrepeat)
   mylib:keypressed(key, scancode, isrepeat)
end

function love.textinput(t)
   mylib:textinput(t)
end

function love.mousemoved(x, y, dx, dy)
   mylib:mousemoved(x, y, dx, dy)
end

function love.mousereleased(x, y, button)

   local w, h = love.graphics.getDimensions()
   if x <= w * part then
      mylib:mousereleased(x, y, button)
   end

end

function love.mousepressed(x, y, button)
   local w, h = love.graphics.getDimensions()
   if x <= w * part then
      mylib:mousepressed(x, y, button)
   end

end

function love.wheelmoved(x, y)
   mylib:wheelmoved(x, y)
end

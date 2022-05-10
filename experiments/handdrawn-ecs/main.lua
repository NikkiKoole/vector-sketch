package.path = package.path .. ";../../?.lua"

Camera = require 'custom-vendor.brady'

require 'lib.scene-graph'
require 'lib.editor-utils'
require 'lib.poly'
require 'lib.basics'
require 'lib.main-utils'
require 'lib.toolbox'

inspect = require 'vendor.inspect'
flux = require "vendor.flux"

require 'src.camera'


Concord = require 'vendor.concord.init'

local myWorld = Concord.world()


function centerCameraOnPosition(x,y,vw, vh)
   local cw, ch = cam:getContainerDimensions()
   local targetScale = math.min(cw/vw, ch/vh)
   cam:setScale(targetScale)
   --cam:setTranslation(x + vw/2, y + vh/2)
   cam:setTranslation(x , y)
end

function love.keypressed(key)
   if key == "escape" then love.event.quit() end
end

function love.load()
   love.window.setMode(1024, 768, {resizable=true, vsync=true, minwidth=0, minheight=0, msaa=2, highdpi=true})

   cam = createCamera()
   --setCameraViewport(cam, 100,100)
   centerCameraOnPosition(150,150, 200,200)
end

function love.update(dt)
   myWorld:emit("update", dt)
   manageCameraTween(dt)
   cam:update()
end

function love.wheelmoved( dx, dy )
   local newScale = cam.scale * (1 + dy / 10)
   if (newScale > 0.01 and newScale < 50) then
      cam:scaleToPoint(  1 + dy / 10)
   end
end

function love.resize(w, h)
   setCameraViewport(cam, 100,100)
--   centerCameraOnPosition(50,50, 200,200)
   centerCameraOnPosition(150,150, 200,200)
   cam:update(w,h)
end

function love.draw()
   cam:push()
   
   love.graphics.setColor(1,1,1)
   love.graphics.rectangle('fill', 100,100,100,100)
   love.graphics.setColor(1,0,0)
   love.graphics.rectangle('fill', 100,100,20,20)

   cam:pop()
end


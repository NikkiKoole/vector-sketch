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
require 'src.mesh'

Concord = require 'vendor.concord.init'

local myWorld = Concord.world()

--[[
   the process of geting the right handdrawn images
   draw an image with pencil, the size of my hand is roughly the size of a person
   scan this in, black and white 200 dpi, PNG
   in gimp, add alpha layer, convert white to transparent
   resize the image to 50%


]]--

function centerCameraOnPosition(x,y,vw, vh)
   local cw, ch = cam:getContainerDimensions()
   local targetScale = math.min(cw/vw, ch/vh)
   cam:setScale(targetScale)
   --cam:setTranslation(x + vw/2, y + vh/2)
   cam:setTranslation(x , y)
end

function makeMipmapImg(path)
   local imageData = love.image.newImageData( path )
   --print(imageData:getWidth(), imageData:getHeight())
   local img = love.graphics.newImage(imageData, {mipmaps=true})
   img:setMipmapFilter('nearest', 0)
   --img:setFilter("nearest", "nearest")
   return img
end


function love.keypressed(key)
   if key == "escape" then love.event.quit() end
end

function love.load()
   love.window.setMode(1024, 768, {resizable=true, vsync=true, minwidth=0, minheight=0, msaa=2, highdpi=true})

   cam = createCamera()
   m = createTexturedRectangle(makeMipmapImg('assets/animals2.png'))
   -- x, y, angle, sx, sy, ox, oy, kx, ky
   local t = m:getTexture()
   local w,h = t:getDimensions()
   transform = love.math.newTransform( 100, 100, 0, 1, 1, w/2, h, 0, 0 )
   -- 105, 117

   m2 = createTexturedRectangle(makeMipmapImg('assets/dogmanhaar.png'))
   w,h = m2:getTexture():getDimensions()

   transform2 = love.math.newTransform( 130, 130, 0, 1, 1, w/2, h, 0, 0 )
   transform3 = transform * transform2
   
   
   
   --setCameraViewport(cam, 100,100)
   centerCameraOnPosition(150,-500, 1200,1200)
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
   centerCameraOnPosition(150,150, 600,600)
   cam:update(w,h)
end

function love.draw()
   love.graphics.clear(.5,.5,.3)
   local mx, my = love.mouse.getPosition()
--   print(mx,my)
   
   cam:push()

   love.graphics.setColor(1,1,1)

   
   love.graphics.draw(m, transform)

   love.graphics.draw(m2, transform3)

   --love.graphics.setColor(1,1,1)
   --love.graphics.rectangle('fill', 100,100,100,100)
   love.graphics.setColor(1,0,0)
   love.graphics.rectangle('fill', 100,100,5,5)

   cam:pop()
end


local flux = require "vendor.flux"
local cron = require 'vendor.cron'

local fluxObject = {blobScale=0, blobOffset=0, headerOffset=0}

local scene = {}
local header = love.graphics.newImage('assets/splash-header.png' )
local blob = love.graphics.newImage('assets/splash-blob.png')

local clock1 = nil
local clock2 = nil

function scene.modify(obj)
end

function gotoNext()
   SM.load("intro")
end
 
function scene.load()
  
   splashSound:setVolume(.25) 
   clock1 = cron.after(.5, function() splashSound:play() end)
   clock2 = cron.after(7, gotoNext)

   flux.to(fluxObject, 3, {blobScale=1}):ease("elasticout"):delay(.2)
   flux.to(fluxObject, 1, {blobOffset=1}):delay(.2)
   flux.to(fluxObject, 3, {headerOffset=1}):ease("elasticout"):delay(.1)
end

function scene.update(dt)
   function love.keypressed(key, unicode)
      if key == 'escape' then love.event.quit() end
      gotoNext()
   end

   function love.touchpressed(key, unicode)
      gotoNext()
   end

   function love.mousepressed(key, unicode)
      gotoNext()
   end

   flux.update(dt)
   clock1:update(dt)
   clock2:update(dt)
end


function scene.draw()
   love.graphics.clear(238/255,226/255,188/255)

   screenWidth, screenHeight = love.graphics.getDimensions( )

   blobWidth, blobHeight = blob:getDimensions()
   local scaleX = screenWidth/blobWidth
   local scaleY = screenHeight/blobHeight
   local scale = math.min(scaleX, scaleY)
   scale = scale * 0.8
   scale = scale * fluxObject.blobScale
   love.graphics.setColor(0,0,0, 0.1)
   love.graphics.draw(blob,screenWidth/2,(screenHeight/2)+((1-fluxObject.blobOffset)*blobHeight),0,scale,scale, blobWidth/2, blobHeight/2)

   headerWidth, headerHeight = header:getDimensions( )

   scaleX = screenWidth/headerWidth
   scaleY = screenHeight/headerHeight
   scale = math.min(scaleX, scaleY)
   scale = scale * 0.8
   love.graphics.setColor(222/255,166/255,40/255, .25)
   love.graphics.draw(header,screenWidth/2,screenHeight+(1-fluxObject.headerOffset)*headerHeight,0,scale,scale, headerWidth/2, headerHeight)
 
end

return scene



local scene = {}
local poppetjeMaker = love.graphics.newImage('assets/puppetmaker.png' )
local doggie = love.graphics.newImage('assets/doggie.png' )
local time = 0

local Timer = require 'vendor.timer'
local fluxObject = {headerOffset=0, guyY=0}
local numbers = require 'lib.numbers'

function scene.load()
  
   introSound:setLooping(true)
   introSound:play()
   
   Timer.after(
      .1,
      function()
         Timer.tween(3, fluxObject, {headerOffset = 1}, 'out-elastic')
      end
   )
   Timer.after(
      1,
      function()
         Timer.tween(2, fluxObject, {guyY = 1}, 'out-elastic')
      end
   )

   guyFacing = -1

   guyX = 0.75
end

function gotoNext()
   Timer.clear()
   SM.load("mainPage")
end

function scene.update(dt)
   if splashSound:isPlaying() then
      local volume = splashSound:getVolume()
      splashSound:setVolume(volume * .90)
   end
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
   time = time + dt
   --flux.update(dt)
   Timer.update(dt)

   print(fluxObject.guyY)
   if (math.floor(fluxObject.guyY) == 1) then
      
      guyX = guyX + (0.007 * guyFacing)
      if (guyX < -0.1 or guyX > 1.1) then
	 guyFacing = guyFacing * -1
      end
      
   end
   
end

function scene.draw()

   love.graphics.clear(238/255,226/255,188/255)
   screenWidth, screenHeight = love.graphics.getDimensions( )
   blobWidth, blobHeight = doggie:getDimensions()
   
   local scaleX = screenWidth/blobWidth
   local scaleY = screenHeight/blobHeight
   local scale = math.min(scaleX, scaleY)
   scale = scale * 0.7

   love.graphics.setColor(1,1,1,1)
   love.graphics.draw(doggie, screenWidth*guyX, (screenHeight*1.15) + (1-fluxObject.guyY)*blobHeight,  0, scale*(guyFacing*-1), scale, blobWidth/2, blobHeight)
   
   
   blobWidth, blobHeight = poppetjeMaker:getDimensions()
   scaleX = screenWidth/blobWidth
   scaleY = screenHeight/blobHeight
   scale = math.min(scaleX, scaleY)
   scale = scale * 0.8
   scale = scale + (math.sin(time)* 0.01)


   love.graphics.setColor(1,1,1, 0.5 * (fluxObject.headerOffset))
   love.graphics.draw(poppetjeMaker,5+ (screenWidth/2.5) - ((1-fluxObject.headerOffset)*screenWidth/1.5),5 + screenHeight/2 ,0,scale,scale, blobWidth/2, blobHeight/2)


   local r = 0
   local g = 0
   local b = 0
   local value = (math.sin(time)) -- [-1,1]

   r = numbers.mapInto(value, -1, 1, 224/255, 222/255)
   g = numbers.mapInto(value, -1, 1, 167/255, 166/255)
   b = numbers.mapInto(value, -1, 1, 43/255, 40/255)

   love.graphics.setColor(r,g,b, 1)
   love.graphics.draw(poppetjeMaker, (screenWidth/2.5) - ((1-fluxObject.headerOffset)*screenWidth/1.5), screenHeight/2 ,0,scale,scale, blobWidth/2, blobHeight/2)

  
   
end


return scene

local scene = {}

local vivid = require 'vendor.vivid'
local Timer = require 'vendor.timer'

local numbers = require 'lib.numbers'

local creamColor = {238/255, 226/255, 188/255, 1}

function scene.load()
   
   bgColor = creamColor
   

   Timer.after(
      1,
      function()
         Timer.during(
            .3,
            function(dt)
               local h,s,l,a = vivid.RGBtoHSL(bgColor) 
               l = l*0.99
               local r,g,b,a = vivid.HSLtoRGB(h,s,l,a)
               bgColor = {r,g,b,a}
            end
         )
      end
   )
end

function scene.update(dt)
   if introSound:isPlaying() then
      local volume = introSound:getVolume()
      introSound:setVolume(volume * .90)
      if (volume < 0) then
	 introSound:stop()
      end
   end
   function love.keypressed(key, unicode)
      if key == 'escape' then love.event.quit() end
      
   end

   function love.touchpressed(key, unicode)

   end

   function love.mousepressed(key, unicode)

   end
   Timer.update(dt)
end

function scene.draw()
   love.graphics.clear(bgColor)
end

return scene

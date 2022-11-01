local scene = {}
local poppetjeMaker = love.graphics.newImage('assets/puppetmaker.png' )
local time = 0
function scene.load()
  
   introSound = love.audio.newSource("assets/introloop.mp3", "static")
   introSound:setLooping(true)
   introSound:play()
   
end

function scene.update(dt)
   if splashSound:isPlaying() then
      local volume = splashSound:getVolume()
      splashSound:setVolume(volume * .90)
   end
   function love.keypressed(key, unicode)
      if key == 'escape' then love.event.quit() end
      
   end

   function love.touchpressed(key, unicode)

   end

   function love.mousepressed(key, unicode)

   end
   time = time + dt
end

function scene.draw()
   love.graphics.clear(238/255,226/255,188/255)
   screenWidth, screenHeight = love.graphics.getDimensions( )
   blobWidth, blobHeight = poppetjeMaker:getDimensions()
   local scaleX = screenWidth/blobWidth
   local scaleY = screenHeight/blobHeight
   local scale = math.min(scaleX, scaleY)
   scale = scale * 0.8
   scale = scale + (math.sin(time)* 0.01)
   love.graphics.setColor(0,0,0,0.5)
   love.graphics.draw(poppetjeMaker, screenWidth/2, screenHeight/2,0,scale,scale, blobWidth/2, blobHeight/2)
end


return scene

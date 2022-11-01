local scene = {}
local header = love.graphics.newImage('assets/splash-header.png' )
local blob = love.graphics.newImage('assets/splash-blob.png')

function scene.modify(obj)
end

function scene.load()
   splashSound = love.audio.newSource("assets/mipolailoop.mp3", "static")
   splashSound:setVolume(.25)
   splashSound:play()
end

function scene.update()
   function gotoNext()
       SM.load("intro")
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
end


function scene.draw()
   love.graphics.clear(238/255,226/255,188/255)

   screenWidth, screenHeight = love.graphics.getDimensions( )

   blobWidth, blobHeight = blob:getDimensions()
   local scaleX = screenWidth/blobWidth
   local scaleY = screenHeight/blobHeight
   local scale = math.min(scaleX, scaleY)
   scale = scale * 0.8
   love.graphics.setColor(0,0,0, 0.1)
   love.graphics.draw(blob,screenWidth/2,screenHeight/2,0,scale,scale, blobWidth/2, blobHeight/2)

   headerWidth, headerHeight = header:getDimensions( )

   scaleX = screenWidth/headerWidth
   scaleY = screenHeight/headerHeight
   scale = math.min(scaleX, scaleY)
   scale = scale * 0.8
   love.graphics.setColor(222/255,166/255,40/255, .25)
   love.graphics.draw(header,screenWidth/2,screenHeight,0,scale,scale, headerWidth/2, headerHeight)
 
end

return scene

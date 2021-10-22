local scene = {}

function scene.modify(obj)
end

function scene.load()
   font = love.graphics.newFont( "assets/adlib.ttf", 32)

   love.graphics.setFont(font)
   local timeIndex = math.floor(1 + love.math.random()*24)

   skygradient = gradientMesh(
      "vertical",
      gradients[timeIndex].from, gradients[timeIndex].to
   )


end

function scene.update(dt)
   function love.keypressed(key, unicode)
      if key == 'escape' then love.event.quit() end
      SM.load("world")
   end
   function love.touchpressed(key, unicode)
--      if key == 'escape' then love.event.quit() end
      SM.load("world")
   end
   function love.mousepressed(key, unicode)
--      if key == 'escape' then love.event.quit() end
      SM.load("world")
   end

end

function scene.draw()
   love.graphics.clear(1,1,1)
   love.graphics.setColor(1,1,1)

   love.graphics.draw(skygradient, 0, 0, 0, love.graphics.getDimensions())

   love.graphics.setColor(0,0,0)
   love.graphics.print("This is the cave, press any key to go back to the world.", 10,10)
end

return scene

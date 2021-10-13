local scene = {}

function scene.modify(obj)
end

function scene.load()
   font = love.graphics.newFont( "assets/adlib.ttf", 32)

   love.graphics.setFont(font)

end

function scene.update(dt)
   function love.keypressed(key, unicode)
      if key == 'escape' then love.event.quit() end
      SM.load("world")
   end
end

function scene.draw()
   love.graphics.clear(1,1,1)
   love.graphics.setColor(0,0,0)
   love.graphics.print("This is the intro, press any key to go to the world.", 10,10)
end

return scene


 

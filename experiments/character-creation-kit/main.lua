
function love.keypressed(key)
   if key == "escape" then love.event.quit() end
end

function love.load()
   love.window.setMode(1024, 768, { resizable = true, vsync = true, minwidth = 400, minheight = 300, msaa = 2, highdpi = true })
   love.window.setTitle('☺♥ character creation kit ♥☺')
 

end

   

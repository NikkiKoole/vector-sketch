package.path = package.path .. ";../../?.lua"

require 'lib.basic-tools'

local camera = require 'lib.camera'
local cam = require('lib.cameraBase').getInstance()


function love.keypressed(key)
   if key == "escape" then love.event.quit() end
end

function love.load()
   love.window.setMode(1024, 768, { resizable = true, vsync = true, minwidth = 400, minheight = 300, msaa = 2, highdpi = true })
   love.window.setTitle('☺♥ character creation kit ♥☺')

end



   
function love.resize(w, h)
   camera.setCameraViewport(cam, 1000, 1000)
   cam:update(w, h)
end


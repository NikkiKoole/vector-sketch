package.path = package.path .. ";../../?.lua"
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
   require("lldebugger").start()
end

SM = require 'vendor.SceneMgr'

require 'lib.basic-tools'

local camera = require 'lib.camera'
local cam = require('lib.cameraBase').getInstance()


function love.keypressed(key)
   if key == "escape" then love.event.quit() end
end

function love.load()
   love.window.setMode(1024, 768, { resizable = true, vsync = true, minwidth = 400, minheight = 300, msaa = 2, highdpi = true })
   love.window.setTitle('☺♥ Puppet Maker ♥☺')

   splashSound = love.audio.newSource("assets/mipolailoop.mp3", "static")
   introSound = love.audio.newSource("assets/introloop.mp3", "static")
   
   SM.setPath("scenes/")
   SM.load("splash")
end


function love.update(dt)
   SM.update(dt)
end

function love.draw()
   SM.draw() 
end

   
function love.resize(w, h)
   camera.setCameraViewport(cam, 1000, 1000)
   cam:update(w, h)
end


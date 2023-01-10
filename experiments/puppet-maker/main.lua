package.path = package.path .. ";../../?.lua"
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
   require("lldebugger").start()
end

-- cool webdeveloper doing lots of nice generative stuff
--https://codepen.io/georgedoescode/pens/popular?cursor=ZD0xJm89MCZwPTQ=

-- get inner rectangle from rotated outer rectangle
-- https://stackoverflow.com/questions/5789239/calculate-largest-inscribed-rectangle-in-a-rotated-rectangle


--https://nl.pinterest.com/pin/568086940505956798/

-- async image loading
--https://github.com/MikuAuahDark/lily

SM = require 'vendor.SceneMgr'

require 'lib.basic-tools'
gesture = require 'lib.gesture'
Concord = require 'vendor.concord.init'

inspect = require 'vendor.inspect'

PROF_CAPTURE = true
prof = require("jprof")

--local camera = require 'lib.camera'
--local cam = require('lib.cameraBase').getInstance()


function love.keypressed(key)
   if key == "escape" then love.event.quit() end
end

function love.load()
   love.window.setMode(1024, 768,
      { resizable = true, vsync = true, minwidth = 400, minheight = 300, msaa = 2, highdpi = true })
   love.window.setTitle('☺ Puppet Maker')

   splashSound = love.audio.newSource("assets/mipolailoop.mp3", "static")
   introSound = love.audio.newSource("assets/introloop.mp3", "static")

   SM.setPath("scenes/")
   SM.load("mainPage")
   print(love.filesystem.getIdentity())
   focussed = true
end

function love.focus(f)
   focussed = f
end

function love.update(dt)
   if focussed then
      gesture.update(dt)
      SM.update(dt)
   end
end

function love.draw()
   SM.draw()
end

function love.resize(w, h)
   --camera.setCameraViewport(cam, 1000, 1000)
   --cam:update(w, h)
end

function love.quit()
   prof.write("prof.mpack")
end

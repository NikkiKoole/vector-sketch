package.path = package.path .. ";../../?.lua"

local manual_gc = require 'vendor.batteries.manual_gc'

if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
   require("lldebugger").start()
end
-- wooooohoooo
-- todo this takes out all the weird jumpiness of the GC !!!
--https://love2d.org/forums/viewtopic.php?t=91198
jit.off()
--jit.opt.start(3, '-loop', 'maxtrace=5000', 'hotloop=100')


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
prof = require 'vendor.jprof'


--local camera = require 'lib.camera'
--local cam = require('lib.cameraBase').getInstance()


function love.keypressed(key)
   if key == "escape" then love.event.quit() end
end

function love.load()
   --	1180 , 820
   -- iphone 1334, 750
   love.window.setMode(1024, 768,
       { resizable = true, vsync = true, minwidth = 400, minheight = 300, msaa = 2, highdpi = true })
   love.window.setTitle('☺ Puppet Maker')

   local os = love.system.getOS()
   if os == 'iOS' or os == 'Android' then
      love.window.setFullscreen(true)
   end
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
   --require("vendor.lurker").update()

   if focussed then
      gesture.update(dt)
      SM.update(dt)
   end
   --collectgarbage()
   manual_gc(0.002, 2)
end

function love.draw()
   SM.draw()
end

function love.resize(w, h)
   --camera.setCameraViewport(cam, 1000, 1000)
   --cam:update(w, h)
end

function love.quit()
   -- this takes annoyingly long
   time = love.timer.getTime()
   prof.write("prof.mpack")
   print('writing took', love.timer.getTime() - time, 'seconds')
end

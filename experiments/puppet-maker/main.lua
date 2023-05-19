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


-- working ios payment stufff !!!!
-- https://love2d.org/forums/viewtopic.php?f=5&t=83107


SM = require 'vendor.SceneMgr'

require 'lib.basic-tools'
gesture = require 'lib.gesture'
Concord = require 'vendor.concord.init'
myWorld = Concord.world()
inspect = require 'vendor.inspect'

PROF_CAPTURE = false
prof = require 'vendor.jprof'
ProFi = require 'vendor.ProFi'
local mesh = require "lib.mesh"
focussed = false
function findPart(name)
   for i = 1, #parts do
      --print(parts[i].name)
      if parts[i].name == name then
         return parts[i]
      end
   end
end

require 'src.generatePuppet'
local bodypartsGenerate = require 'src.puppetDNA'

if true then
   local a, b, c, d, e
   repeat
      a, b, c, d, e = love.event.wait()
      --print(a, b, c, d, e)
   until a == "focus"
end
--local a, b, c, d, e
--repeat
--   a, b, c, d, e = love.event.wait()
--   print(a, b, c, d, e)
--until a == "keypressed"

--local camera = require 'lib.camera'
--local cam = require('lib.cameraBase').getInstance()



nullFolder = {
    folder = true,
    name = 'nullFolder',
    transforms = { l = { 0, 0, 0, 1, 1, 0, 0 } },
    children = {}
}
-- im sure it sometimes needs to just be the simplest ofunrenderables
nullChild = {
    name = 'nullChild',
    points = { { 0, 0 }, { 0, 0 }, { 0, 0 } }
}


function love.keypressed(key)
   if key == "escape" then love.event.quit() end
end

function love.load()
   --	1180 , 820
   -- iphone 1334, 750
   love.window.setMode(1024 / 2, 768 / 2,
       { resizable = true, vsync = true, minwidth = 400, minheight = 300, msaa = 2, highdpi = true })
   love.window.setTitle('☺ Puppet Maker')

   local os = love.system.getOS()
   print(os)
   if os == 'iOS' or os == 'Android' or (not (os == 'OS X')) then
      love.window.setFullscreen(true)
   end


   miSound2 = love.audio.newSource("assets/sounds/mi2.wav", "static")
   poSound2 = love.audio.newSource("assets/sounds/po2.wav", "static")
   miSound1 = love.audio.newSource("assets/sounds/mi.wav", "static")
   poSound1 = love.audio.newSource("assets/sounds/po.wav", "static")
   splashSound = love.audio.newSource("assets/sounds/music/mipolailoop.mp3", "static")
   introSound = love.audio.newSource("assets/sounds/music/introloop.mp3", "static")


   textures = {
       love.graphics.newImage('assets/img/bodytextures/texture-type0.png'),
       love.graphics.newImage('assets/img/bodytextures/texture-type2t.png'),
       love.graphics.newImage('assets/img/bodytextures/texture-type1.png'),
       love.graphics.newImage('assets/img/bodytextures/texture-type3.png'),
       love.graphics.newImage('assets/img/bodytextures/texture-type4.png'),
       love.graphics.newImage('assets/img/bodytextures/texture-type5.png'),
       love.graphics.newImage('assets/img/bodytextures/texture-type6.png'),
       love.graphics.newImage('assets/img/bodytextures/texture-type7.png'),
       love.graphics.newImage('assets/img/tiles/tiles2.png'),
       love.graphics.newImage('assets/img/tiles/tiles.png'),

   }

   for i = 1, #textures do
      textures[i]:setWrap('mirroredrepeat', 'mirroredrepeat')
   end

   palettes = {}
   local base = {
       '020202', '333233', '814800', 'e6c800', 'efebd8',
       '808b1c', '1a5f8f', '66a5bc', '87727b', 'a23d7e',
       'f0644d', 'fa8a00', 'f8df00', 'ff7376', 'fef1d0',
       'ffa8a2', '6e614c', '418090', 'b5d9a4', 'c0b99e',
       '4D391F', '4B6868', '9F7344', '9D7630', 'D3C281',
       'CB433A', '8F4839', '8A934E', '69445D', 'EEC488',
       'C77D52', 'C2997A', '9C5F43', '9C8D81', '965D64',
       '798091', '4C5575', '6E4431', '626964', '613D41',
   }

   transition = nil

   for i = 1, #base do
      local r, g, b = hex2rgb(base[i])
      table.insert(palettes, { r, g, b })
   end

   fiveGuys = {} -- here we keep the 5 differnt guys around, I might as well just generate them here to begin with

   parts, _ = generate()
   amountOfGuys = 5

   prof.push('frame')
   prof.push('creating-guys')
   if (PROF_CAPTURE) then ProFi:start() end


   -- todp move this to the DNA code I thinkk
   for i = 1, amountOfGuys do
      local parts, values = generate()

      values = partRandomize(values, false)
      fiveGuys[i] = {
          values = copy3(values),
          head = copyAndRedoGraphic('head', values),
          neck = createNeckRubberhose(values),
          body = copyAndRedoGraphic('body', values),
          hair = createHairVanillaLine(values),
          arm1 = createArmRubberhose(1, values),
          arm2 = createArmRubberhose(2, values),
          armhair1 = createArmHairRubberhose(1, values),
          armhair2 = createArmHairRubberhose(2, values),
          hand1 = copyAndRedoGraphic('hands', values),
          hand2 = copyAndRedoGraphic('hands', values),
          leg1 = createLegRubberhose(1, values),
          leg2 = createLegRubberhose(2, values),
          leghair1 = createLegHairRubberhose(1, values),
          leghair2 = createLegHairRubberhose(2, values),
          feet1 = copyAndRedoGraphic('feet', values),
          feet2 = copyAndRedoGraphic('feet', values),
          eye1 = copyAndRedoGraphic('eyes', values),
          eye2 = copyAndRedoGraphic('eyes', values),
          pupil1 = copyAndRedoGraphic('pupils', values),
          pupil2 = copyAndRedoGraphic('pupils', values),
          brow1 = createBrowBezier(values),
          brow2 = createBrowBezier(values),
          mouth = makeMouthParentThing(),
          teeth = copyAndRedoGraphic('teeth', values),
          upperlip = createUpperlipBezier(values),
          lowerlip = createLowerlipBezier(values),
          ear1 = copyAndRedoGraphic('ears', values),
          ear2 = copyAndRedoGraphic('ears', values),
          nose = copyAndRedoGraphic('nose', values),
      }

      -- maybe we can do a cleanuop phase for the leg and arm hair here.


      local guy = {
          folder = true,
          name = 'guy',
          transforms = { l = { 0, 0, 0, 1, 1, 0, 0, 0, 0 } },
          children = {}
      }


      fiveGuys[i].guy = guy



      fiveGuys[i].body.transforms.l[2] = -700
      guy.children = guyChildren(fiveGuys[i])
   end
   if (PROF_CAPTURE) then
      ProFi:stop()
      ProFi:writeReport('profilingReportInit.txt')
   end


   prof.pop('creating-guys')
   prof.pop('frame')



   editingGuy = fiveGuys[1]

   SM.setPath("scenes/")
   SM.load("splash")
   print(love.graphics.getStats().texturememory / (1024 * 1024) .. ' MB of texture memory, for ' .. #fiveGuys .. ' guys.')
   print(love.filesystem.getIdentity())

   love.event.wait()
   love.event.wait()

   local success = love.window.updateMode(1024 / 2, 768 / 2,
           { resizable = true, vsync = true, minwidth = 400, minheight = 300, msaa = 2, highdpi = true })
end

function partRandomize(values, applyChangeDirectly)
   local parts = { 'head', 'ears', 'neck', 'nose', 'body', 'arms', 'hands', 'feet', 'legs', 'hair', 'leghair', 'armhair',
       'brows', 'upperlip', 'lowerlip', 'skinPatchSnout', 'teeth' }


   values.overBite = love.math.random() < .5 and true or false

   values.legLength = math.ceil(love.math.random() * 7)
   values.armLength = math.ceil(love.math.random() * 7)
   values.legDefaultStance =  0.25 +  math.floor(love.math.random()*4) * 0.25   --0.25--  0--0.75 + (love.math.random() / 4.0)

   for i = 1, #parts do
      if values.potatoHead and parts[i] == 'neck' then

      else
         local p = findPart(parts[i])
         values[parts[i]].shape = math.ceil(love.math.random() * #(p.imgs))
         if (parts[i] == 'leghair' or parts[i] == 'armhair' or parts[i] == 'hair') then
            --   values[parts[i]].shape = #p.imgs
         end
         values[parts[i]].fgPal = math.ceil(love.math.random() * #palettes)
         values[parts[i]].bgPal = math.ceil(love.math.random() * #palettes)
         --values[parts[i]].linePal = 13 --math.ceil(love.math.random() * #palettes)
         values[parts[i]].texScale = math.ceil(love.math.random() * 9)
         if (parts[i] == 'head' or parts[i] == 'body') then
            values[parts[i]].flipx = love.math.random() < .5 and -1 or 1
            values[parts[i]].flipy = love.math.random() < .5 and -1 or 1
         end
         if (parts[i] == 'nose') then
            --values[parts[i]].shape = #(p.imgs)
         end
         if (parts[i] == 'teeth') then
            values[parts[i]].fgPal = 5
            values[parts[i]].bgPal = 5
         end
         if applyChangeDirectly then
            changePart(parts[i])
         end
      end
   end
   return values
end

function love.focus(f)
   focussed = f
end

function love.update(dt)
   prof.push('frame')
   --require("vendor.lurker").update()
   if not focussed then
      -- print('this app is unfocessed!')
   end
   if focussed then
      gesture.update(dt)
      SM.update(dt)
   end
   --collectgarbage()
   manual_gc(0.002, 2)
   prof.pop('frame')
end

function love.draw()
   prof.push('frame')
   SM.draw()
   prof.pop('frame')
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

function love.mousepressed(x, y, button, istouch, presses)
   --print('mousepressed', button)
   --if not istouch then
   --   pointerPressed(x, y, 'mouse')
   --end
end

function love.lowmemory()
   print('LOW MEMORY!!!')
end

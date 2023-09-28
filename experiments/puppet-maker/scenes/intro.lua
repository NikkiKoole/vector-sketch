local scene         = {}
local poppetjeMaker = love.graphics.newImage('assets/intro/puppetmaker2.png')
local doggie        = love.graphics.newImage('assets/intro/doggie.png')
local darkness      = love.graphics.newImage('assets/img/worldparts/darkness.png')
local time          = 0

local Timer         = require 'vendor.timer'
local fluxObject    = { headerOffset = 0, guyY = 0, darknessAlpha = 0, puppetMakerAlpha = 0 }
local numbers       = require 'lib.numbers'

local Components    = {}
local Systems       = {}

local parentize     = require 'lib.parentize'
local mesh          = require 'lib.mesh'
local render        = require 'lib.render'
local camera        = require 'lib.camera'
local cam           = require('lib.cameraBase').getInstance()
local bbox          = require 'lib.bbox'
local parse         = require 'lib.parse-file'
local bbox          = require 'lib.bbox'
require 'src.screen-transitions'
myWorld = Concord.world()
local audioHelper = require 'lib.audio-helper'
require 'src.generatePuppet'
require 'src.puppet-maker-ui'
require 'src.reuse'


function getCameraDataZoomOnHeadAndBody()
   local bbHead             = bbox.getBBoxRecursive(editingGuy.head)
   local bbBody             = bbox.getBBoxRecursive(editingGuy.body)
   local bbFeet1            = bbox.getBBoxRecursive(editingGuy.feet1)
   local bbFeet2            = bbox.getBBoxRecursive(editingGuy.feet2)
   local bbHand1            = bbox.getBBoxRecursive(editingGuy.hand1)
   local bbHand2            = bbox.getBBoxRecursive(editingGuy.hand2)

   local tlx, tly, brx, bry = bbox.combineBboxes(bbHead, bbBody, bbFeet1, bbFeet2, bbHand1, bbHand2)
   local x2, y2, w2, h2     = bbox.getMiddleAndDimsOfBBox(tlx, tly, brx, bry)

   --return x2, y2, w, h * 1.2
   local w, h               = love.graphics.getDimensions()
   return 0, y2 + -h2 / 4, w, h2 * 1.5
end

Concord.utils.loadNamespace("src/components", Components)
Concord.utils.loadNamespace("src/systems", Systems)
myWorld:addSystems(Systems.BipedSystem, Systems.PotatoHeadSystem, Systems.MouthSystem)

function scene.load()
   creamColor = { 238 / 255, 226 / 255, 188 / 255 }
   blueColor = { 0x0a / 0xff, 0, 0x4b / 0xff }
   bgColor = creamColor
   introSound:setVolume(.5)
   introSound:setLooping(true)
   introSound:play()

   for i = 1, #fiveGuys do
      fiveGuys[i].guy.transforms.l[1] = 0
   end
   Timer.after(.1, function()
      Timer.tween(1, bgColor, { [1] = blueColor[1],[2] = blueColor[2],[3] = blueColor[3] }, 'out-cubic')
   end)

   Timer.after(1, function()
      Timer.tween(1, fluxObject, { darknessAlpha = .25 }, 'out-cubic')
   end)
   Timer.after(3, function()
      Timer.tween(3, fluxObject, { puppetMakerAlpha = 1 }, 'out-cubic')
   end)
   Timer.after(
       .1,
       function()
          Timer.tween(3, fluxObject, { headerOffset = 1 }, 'out-elastic')
       end
   )
   Timer.after(
       1,
       function()
          Timer.tween(2, fluxObject, { guyY = 1 }, 'out-elastic')
       end
   )

   guyFacing = -1

   guyX = 0.75

   root = {
       folder = true,
       name = 'root',
       transforms = { l = { 0, 0, 0, 1, 1, 0, 0 } },
       children = {}
   }

   parts = generateParts()

   biped = Concord.entity()
   potato = Concord.entity()
   mouth = Concord.entity()

   myWorld:addEntity(biped)
   myWorld:addEntity(potato)
   myWorld:addEntity(mouth)

   biped:give('biped', bipedArguments(editingGuy))
   potato:give('potato', potatoArguments(editingGuy))
   mouth:give('mouth', mouthArguments(editingGuy))


   mipo = parse.parseFile('/assets/mipo.polygons.txt')[1]
   root.children = { mipo, editingGuy.guy }




   local guybb = bbox.getBBoxRecursive(editingGuy.guy)




   attachAllFaceParts(editingGuy)
   --  changePart('hair')

   -- a bit of a cheap fix to fic teh null objects hair stuff
   if isNullObject('leghair', editingGuy.values) then
      changePart('leghair')
   end
   if isNullObject('armhair', editingGuy.values) then
      changePart('armhair')
   end
   if isNullObject('hair', editingGuy.values) then
      changePart('hair')
   end
   changePart('hair')

   stripPath(root, '/experiments/puppet%-maker/')
   parentize.parentize(root)
   mesh.meshAll(root)
   render.renderThings(root)

   -- ok i have to call this before the init, weird!!!!!
   -- todo look at this better
   myWorld:emit('keepFeetPlantedAndStraightenLegs', biped)
   myWorld:emit("bipedInit", biped)



   myWorld:emit("potatoInit", potato)
   myWorld:emit("mouthInit", mouth)

   render.renderThings(root, true)

   local w, h = love.graphics.getDimensions()


   local x1, y1, w1, h1 = getCameraDataZoomOnHeadAndBody()
   tweenCameraData = { x = x1, y = y1, w = w1, h = h1 }

   camera.setCameraViewport(cam, w, h)
   camera.centerCameraOnPosition(x1, y1, w1, h1)

   mipobb = bbox.getBBoxRecursive(mipo)

   local mw = mipobb[4] - mipobb[2]
   local mh = mipobb[3] - mipobb[1]
   local sx = w1 / mw
   local sy = h1 / mh
   mipo.transforms.l[2] = y1 - 100
   mipo.transforms.l[4] = math.max(sx, sy)
   mipo.transforms.l[5] = math.max(sx, sy)

   cam:update(w, h)

   for i = 1, #mipo.children do
      local letter = mipo.children[i]
      if letter.children then
         for j = 1, #letter.children do
            letter.children[j].color[4] = 0
         end
      end
   end


   myWorld:emit('birthGuy', biped)

   Timer.after(15, function()
      Timer.tween(1, fluxObject, { darknessAlpha = 0, puppetMakerAlpha = 0 })
   end)
   Timer.after(1.5, doTheMipoAnimation)
end

function playSound(sound, p, volumeMultiplier)
   local s = sound:clone()


   s:setPitch(p)

   love.audio.play(s)
   return s
end

function doTheMipoAnimation()
   -- show mipo letters

   local M = mipo.children[2]
   local originM = {}
   local I = mipo.children[3]
   local originI = {}
   local P = mipo.children[4]
   local originP = {}
   local O = mipo.children[5]
   local originO = {}

   local letter = M
   for i = 1, #letter.children do
      for j = 1, #letter.children[i].points do
         table.insert(originM, { letter.children[i].points[j][1], letter.children[i].points[j][2] })
      end
   end
   local letter = I
   for i = 1, #letter.children do
      for j = 1, #letter.children[i].points do
         table.insert(originI, { letter.children[i].points[j][1], letter.children[i].points[j][2] })
      end
   end
   local letter = P
   for i = 1, #letter.children do
      for j = 1, #letter.children[i].points do
         table.insert(originP, { letter.children[i].points[j][1], letter.children[i].points[j][2] })
      end
   end
   local letter = O
   for i = 1, #letter.children do
      for j = 1, #letter.children[i].points do
         table.insert(originO, { letter.children[i].points[j][1], letter.children[i].points[j][2] })
      end
   end



   -- MI
   Timer.after(0.5, function()
      local M = mipo.children[2]
      local I = mipo.children[3]
      for i = 1, #M.children do
         Timer.tween(0.5, M.children[i].color, { [4] = 1 })
      end
      Timer.after(0.1, function()
         for i = 1, #I.children do
            Timer.tween(0.5, I.children[i].color, { [4] = 1 })
         end
      end)
      local sound = miSound1
      if love.math.random() < 0.2 then
         sound = miSound2
      end
      playSound(sound, .7 + love.math.random() * 0.5)
      myWorld:emit('mouthSaySomething', mouth, editingGuy, 1)

      --  Timer.during(15, function()
      Timer.every(.5, function()
         local M = mipo.children[2]
         local I = mipo.children[3]

         --  local P = mipo.children[4]
         --  local O = mipo.children[5]

         local letters = { M, I }
         local origins = { originM, originI }

         for k = 1, #letters do
            local l           = letters[k]
            local originIndex = 1
            for i = 1, #l.children do
               for j = 1, #l.children[i].points do
                  Timer.tween(0.4, l.children[i].points[j],
                      {
                          [1] = origins[k][originIndex][1] + love.math.random() * 100 - 5,
                          [2] = origins[k][originIndex][2] + love.math.random() * 40 - 20
                      })
                  --  l.children[i].points[j][1] = origins[k][originIndex][1] + love.math.random() * 40 - 20
                  --  l.children[i].points[j][2] = origins[k][originIndex][2] + love.math.random() * 10 - 5
                  originIndex = originIndex + 1
               end
            end
         end
         mesh.meshAll(mipo)
      end)
      --  end)
   end)


   -- PO
   Timer.after(1, function()
      local P = mipo.children[4]
      local O = mipo.children[5]
      for i = 1, #P.children do
         Timer.tween(0.5, P.children[i].color, { [4] = 1 })
      end
      Timer.after(0.1, function()
         for i = 1, #O.children do
            Timer.tween(0.5, O.children[i].color, { [4] = 1 })
         end
      end)

      local sound = poSound1
      if love.math.random() < 0.2 then
         sound = poSound2
      end
      playSound(sound, .7 + love.math.random() * 0.5)


      myWorld:emit('mouthSaySomething', mouth, editingGuy, 1)
      -- Timer.during(15, function()
      Timer.every(.5, function()
         local M = mipo.children[2]
         local I = mipo.children[3]
         local P = mipo.children[4]
         local O = mipo.children[5]

         local letters = { P, O }
         local origins = { originP, originO }
         for k = 1, #letters do
            local l = letters[k]
            local originIndex = 1
            for i = 1, #l.children do
               for j = 1, #l.children[i].points do
                  Timer.tween(0.4, l.children[i].points[j],
                      {
                          [1] = origins[k][originIndex][1] + love.math.random() * 100 - 5,
                          [2] = origins[k][originIndex][2] + love.math.random() * 40 - 20
                      })
                  --l.children[i].points[j][1] = origins[k][originIndex][1] + love.math.random() * 100 - 5
                  --l.children[i].points[j][2] = origins[k][originIndex][2] + love.math.random() * 40 - 20
                  originIndex = originIndex + 1
               end
            end
         end
         mesh.meshAll(mipo)
      end)
      -- end)
   end)

   Timer.after(2, function()
      myWorld:emit('doinkBody', biped)
   end)

   Timer.after(3.5, function()
      myWorld:emit('breath', biped)
   end)
   Timer.after(5, function()
      myWorld:emit('breath', biped)
   end)
   Timer.after(7, function()
      myWorld:emit('breath', biped)
   end)
   Timer.after(9.5, function()
      myWorld:emit('breath', biped)
   end)
   Timer.after(12, function()
      myWorld:emit('breath', biped)
   end)
   Timer.after(15, function()
      local w, h = love.graphics.getDimensions()
      fadeOutTransition(function()
         gotoNext()
      end)
      -- gotoNext()
   end)
end

function scene.handleAudioMessage()

end

function scene.unload()
   print('unload')
   Timer.clear()
   myWorld:emit('finishBirth', biped)
end

function gotoNext()
   audioHelper.sendMessageToAudioThread({ type = "paused", data = false });
   Timer.clear()
   SM.unload('intro')
   SM.load("editGuy")
end

function scene.update(dt)
   if splashSound:isPlaying() then
      local volume = splashSound:getVolume()
      splashSound:setVolume(volume * .90)
      if volume < 0.01 then
         splashSound:stop()
      end
   end
   function love.keypressed(key, unicode)
      if key == 'escape' then love.event.quit() end
      if key == 'space' then
         gotoNext()
      end
      if key == 'b' then
         -- myWorld:emit('blinkEyes', potato)
         myWorld:emit('birthGuy', biped)
      end
      if key == 'f' then
         myWorld:emit('keepFeetPlantedAndStraightenLegs', biped)
      end

         if key== 'm' then
            makeMarketingScreenshots('intro')
         end

      
   end

   function love.touchpressed(key, unicode)
      gotoNext()
   end

   function love.mousepressed(key, unicode)
      gotoNext()
   end

   time = time + dt
   --flux.update(dt)
   Timer.update(dt)

   -- print(fluxObject.guyY)
   if (math.floor(fluxObject.guyY) == 1) then
      guyX = guyX + (0.007 * guyFacing)
      if (guyX < -0.1 or guyX > 1.1) then
         guyFacing = guyFacing * -1
      end
   end

   function love.resize(w, h)
      local w, h = love.graphics.getDimensions()

      local x1, y1, w1, h1 = getCameraDataZoomOnHeadAndBody()
      tweenCameraData = { x = x1, y = y1, w = w1, h = h1 }

      camera.setCameraViewport(cam, w, h)
      camera.centerCameraOnPosition(x1, y1, w1, h1)
      cam:update(w, h)
   end
end

function scene.draw()
   --love.graphics.clear(238 / 255, 226 / 255, 188 / 255)
   love.graphics.clear(bgColor)

   screenWidth, screenHeight = love.graphics.getDimensions()

   darkWidth, darkHeight = darkness:getDimensions()

   local scaleX = screenWidth / blobWidth
   local scaleY = screenHeight / blobHeight
   local scale = math.min(scaleX, scaleY)
   scale = scale * 0.7

   love.graphics.setColor(1, 1, 1, fluxObject.darknessAlpha)
   local dscaleX = screenWidth / darkWidth
   local dscaleY = screenHeight / darkHeight
   love.graphics.draw(darkness, 0, 0, 0, dscaleX, dscaleY)




   cam:push()
   render.renderThings(root, true)
   cam:pop()





   blobWidth, blobHeight = poppetjeMaker:getDimensions()
   scaleX = screenWidth / blobWidth
   scaleY = screenHeight / blobHeight
   scale = math.min(scaleX, scaleY)
   scale = scale * 0.5
   scale = scale + (math.sin(time) * 0.01)


   love.graphics.setColor(1, 1, 1, 0.5 * (fluxObject.headerOffset) * fluxObject.puppetMakerAlpha)
   love.graphics.draw(poppetjeMaker, 1 + (screenWidth / 2) - ((1 - fluxObject.headerOffset) * screenWidth / 2),
       screenHeight - (blobHeight * scale), 0, scale, scale, blobWidth / 2, blobHeight / 2)

   love.graphics.setColor(1, 1, 1, fluxObject.puppetMakerAlpha)


   love.graphics.draw(poppetjeMaker, (screenWidth / 2) - ((1 - fluxObject.headerOffset) * screenWidth / 2),
       screenHeight - (blobHeight * scale), 0, scale, scale, blobWidth / 2, blobHeight / 2)


   if transition then
      renderTransition(transition)
   end
end

return scene

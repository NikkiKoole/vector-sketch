-- https://medium.com/@chrisgaul/https-medium-com-chrisgaul-is-this-language-without-letters-the-future-of-global-communication-15fc54909c12
-- http://bamanda.com/locos/locos_subsite/locos_gallery.html
-- https://ai.facebook.com/blog/using-ai-to-bring-childrens-drawings-to-life/
local scene             = {}

local vivid             = require 'vendor.vivid'
local Timer             = require 'vendor.timer'
local inspect           = require 'vendor.inspect'
local Signal            = require 'vendor.signal'

local text              = require 'lib.text'
local render            = require 'lib.render'
local mesh              = require 'lib.mesh'
local parentize         = require 'lib.parentize'
local node              = require 'lib.node'
local parse             = require 'lib.parse-file'
local bbox              = require 'lib.bbox'
local hit               = require 'lib.hit'
local transforms        = require 'lib.transform'
local numbers           = require 'lib.numbers'
local ui                = require 'lib.ui'
local gradient          = require 'lib.gradient'
local audioHelper       = require 'lib.audio-helper'

local bodypartsGenerate = require 'src.puppetDNA'
local camera            = require 'lib.camera'
local cam               = require('lib.cameraBase').getInstance()
local creamColor        = { 238 / 255, 226 / 255, 188 / 255, 1 }

local Components        = {}
local Systems           = {}


--assets = require('vendor.cargo').init('assets')

myWorld = Concord.world()

require 'src.generatePuppet'
require 'src.puppet-maker-ui'
require 'src.reuse'
require 'src.screen-transitions'


Concord.utils.loadNamespace("src/components", Components)
Concord.utils.loadNamespace("src/systems", Systems)
myWorld:addSystems(Systems.BipedSystem, Systems.PotatoHeadSystem, Systems.MouthSystem)

--Concord.utils.loadNamespace("src/components", Components)
--Concord.utils.loadNamespace("src/systems", Systems)
--myWorld:addSystems(Systems.BipedSystem, Systems.PotatoHeadSystem, Systems.MouthSystem)


-- instead of having these here for alays, i want to precisely add and remove them at the right times

local pointerInteractees = {}



--local timeIndex = math.floor(1 + love.math.random() * 24)
local skygradient = gradient.makeSkyGradient(16)



-- sometimes the nullobject has to behave as a folder (? does it?)



local function sign(x)
   return x > 0 and 1 or x < 0 and -1 or 0
end



function addChild(parent, elem)
   node._parent = parent
   table.insert(parent.children, elem)
end

function addChildAt(parent, elem, index)
   node._parent = parent
   table.insert(parent.children, index, elem)
end

function addChildBefore(beforeThis, elem)
   local p = beforeThis._parent
   local index = node.getIndex(beforeThis)
   elem._parent = p
   table.insert(p.children, index, elem)
end

function getSiblingBefore(before)
   local index = node.getIndex(before)
   if index > 0 then
      return before._parent.children[index - 1]
   end
   return nil
end

function playSound(sound, optionalPitch, volumeMultiplier)
   local s = sound:clone()

   local p = optionalPitch == nil and (.99 + .02 * love.math.random()) or optionalPitch
   s:setPitch(p)
   s:setVolume(.25 * (volumeMultiplier == nil and 1 or volumeMultiplier))
   love.audio.play(s)
   return s
end

local findSample = function(path)
   for i = 1, #samples do
      if samples[i].p == path then
         return samples[i]
      end
   end
end

function hittestPixel()
   local mx, my = love.mouse.getPosition()
   local wx, wy = cam:getWorldCoordinates(mx, my)
   local xx, yy = node.transforms.g:inverseTransformPoint(wx, wy)
   love.graphics.setColor(0, 0, 0)
   if (xx > 0 and xx < node.graphic.w and yy > 0 and yy < node.graphic.h) then
      love.graphics.setColor(.5, .5, .5)
      local r, g, b, a = node.graphic.imageData:getPixel(xx, yy)
      if (a > 0) then
         love.graphics.setColor(1, 1, 1, 1)
      end
   end
end

local function pointerMoved(x, y, dx, dy, id)
   local somethingWasDragged = false
   for i = 1, #pointerInteractees do
      if pointerInteractees[i].id == id then
         local scale = cam:getScale()

         if love.mouse.isDown(1) then
            myWorld:emit("itemDrag", pointerInteractees[i], dx, dy, scale)
            somethingWasDragged = true
         end
         if love.mouse.isDown(2) then
            myWorld:emit("itemRotate", pointerInteractees[i], dx, dy, scale)
            somethingWasDragged = true
         end
      end
   end

   -- only do this when the scroll ui is visible (always currently)
   if scrollerIsDragging and not somethingWasDragged then
      local w, h = love.graphics.getDimensions()
      local oldScrollPos = scroller.position
      scroller.position = scroller.position + dy / (h / scrollItemsOnScreen)
      local newScrollPos = scroller.position
      if (math.floor(oldScrollPos) ~= math.floor(newScrollPos)) then
         -- play sound
         playSound(scrollTickSample)
      end
   end

   if settingsScrollAreaIsDragging and not somethingWasDragged then
      local old = settingsScrollPosition
      settingsScrollPosition = settingsScrollPosition + dy / settingsScrollArea[5]

      if math.floor(old) ~= math.floor(settingsScrollPosition) then
         if not settingsScrollArea[8] then
            playSound(scrollTickSample)
         end
      end
   end
end

function pointerReleased(x, y, id)
   for i = #pointerInteractees, 1, -1 do
      if pointerInteractees[i].id == id then
         myWorld:emit('itemReleased', pointerInteractees[i])
         if (pointerInteractees[i].item and pointerInteractees[i].item == editingGuy.body) then
            local soundArray = hum;
            local pitch = love.math.random() * 0.25 + 0.8
            local index = math.ceil(love.math.random() * #soundArray)
            local sndLength = soundArray[math.ceil(index)]:getDuration() / pitch
            playingSound = playSound(soundArray[math.ceil(index)], pitch, 2)

            myWorld:emit('mouthSaySomething', mouth, editingGuy, sndLength)
            myWorld:emit('blinkEyes', potato)
         else
            local item = pointerInteractees[i].item
            if (item and item == editingGuy.hand1 or item == editingGuy.hand2) then
               local sfx = pickRandomFrom(rubberplonks)
               local pitch = 1
               playSound(sfx, pitch, sfx:getDuration() / pitch)
            end
            -- playSOund(rubberplonks[math.ceil(math.random)])
         end

         table.remove(pointerInteractees, i)
      end
   end

   scrollerIsDragging = false
   settingsScrollAreaIsDragging = false

   gesture.maybeTrigger(id, x, y)
   -- I probably need to add the xyoffset too, so this panel can be tweened in and out the screen
   partSettingsSurroundings(false, x, y)
   --collectgarbage()
end

--[[
if node.graphic then
   local mx, my = love.mouse.getPosition()
   local wx, wy = cam:getWorldCoordinates(mx, my)
   local xx, yy = node.transforms.g:inverseTransformPoint(wx, wy)
   love.graphics.setColor(0, 0, 0)
   if (xx > 0 and xx < node.graphic.w and yy > 0 and yy < node.graphic.h) then
      love.graphics.setColor(.5, .5, .5)
      local r, g, b, a = node.graphic.imageData:getPixel(xx, yy)
      if (a > 0) then
         love.graphics.setColor(1, 1, 1, 1)
      end
   end


   love.graphics.draw(node.graphic.mesh, node.transforms.g)
end
--]]
--getPNGMaskUrl


local function pointerPressed(x, y, id)
   local wx, wy = cam:getWorldCoordinates(x, y)
   for j = 1, #root.children do
      local guy = root.children[j]
      if guy.children then
         for i = 1, #guy.children do
            local item = guy.children[i]
            local b = bbox.getBBoxRecursiveVersion2(item) --- this is breaking now because i have smaller children that end up becoming the bbox
            if b and item.folder then
               local mx, my = item.transforms._g:inverseTransformPoint(wx, wy)
               local tlx, tly = item.transforms._g:inverseTransformPoint(b[1], b[2])
               local brx, bry = item.transforms._g:inverseTransformPoint(b[3], b[4])

               if (hit.pointInRect(mx, my, tlx, tly, brx - tlx, bry - tly)) then
                  local romp = hasChildNamedRomp(item)
                  if romp then
                     local maskUrl = (getPNGMaskUrl(romp.texture.url))
                     local mask = mesh.getImage(maskUrl)
                     local imageData = love.image.newImageData(maskUrl)

                     local imgW, imgH = imageData:getDimensions()
                     local xx = numbers.mapInto(mx, tlx, brx, 0, imgW)
                     local yy = numbers.mapInto(my, tly, bry, 0, imgH)

                     if xx > 0 and xx < imgW then
                        if yy > 0 and my < imgH then
                           local r, g, b, a = imageData:getPixel(xx, yy)
                           if (r + g + b > 1.5) then
                              table.insert(pointerInteractees, { state = 'pressed', item = item, x = x, y = y, id = id })
                           end
                        end
                     end
                  else
                     table.insert(pointerInteractees, { state = 'pressed', item = item, x = x, y = y, id = id })
                  end
               end
            end
         end
      end
   end
   if false then
      for _, v in pairs(cameraPoints) do
         if hit.pointInRect(wx, wy, v.x, v.y, v.width, v.height) then
            local cw, ch = cam:getContainerDimensions()
            local targetScale = math.min(cw / v.width, ch / v.height)

            cam:setScale(targetScale)
            cam:setTranslation(v.x + v.width / 2, v.y + v.height / 2)
         end
      end
   end

   local w, h = love.graphics.getDimensions()
   -- local x, y = love.mouse.getPosition()

   if x >= 0 and x <= scrollListXPosition then
      -- this could be clicking in the head or body buttons
      --  headOrBody(false, x, y)
   end

   if x >= scrollListXPosition and x < scrollListXPosition + (h / scrollItemsOnScreen) then
      scrollerIsDragging = true
      scrollListIsThrown = nil
      gesture.add('scroll-list', id, love.timer.getTime(), x, y)
   end
   if (settingsScrollArea) then
      if (hit.pointInRect(x, y,
              settingsScrollArea[1], settingsScrollArea[2], settingsScrollArea[3], settingsScrollArea[4])
          ) then
         settingsScrollAreaIsDragging = true
         settingsScrollAreaIsThrown = nil
         gesture.add('settings-scroll-area', id, love.timer.getTime(), x, y)
      end
   end

   local size = (h / 8) -- margin around panel
   if (hit.pointInRect(x, y, w - size, 0, size, size)) then
      local sx, sy = getPointToCenterTransitionOn()
      SM.unload('editGuy')
      Timer.clear()

      doCircleInTransition(sx, sy, function() if scene then SM.load('fiveGuys') end end)

      --transitionHead(true, 'fiveGuys')
   end
   if (hit.pointInRect(x, y, w - size, h - size, size, size)) then
      local s = findSample('mp7/Quijada')
      if s then
         playSound(s.s, 1, 1)
      end
      partRandomize(editingGuy.values, true)

      tweenCameraToHeadAndBody()
      myWorld:emit("tweenIntoDefaultStance", biped, true)
   end
   myWorld:emit("eyeLookAtPoint", x, y)
end



local function hex2rgb(hex)
   hex = hex:gsub("#", "")
   return tonumber("0x" .. hex:sub(1, 2)) / 255, tonumber("0x" .. hex:sub(3, 4)) / 255,
       tonumber("0x" .. hex:sub(5, 6)) / 255
end

local function rgbToHex(r, g, b)
   local rgb = (r * 0x10000) + (g * 0x100) + b
   return string.format("%x", rgb)
end



function scene.handleAudioMessage(msg)
   if msg.type == 'played' then
      local path = msg.data.path

      if path == 'Triangles 101' or path == 'Triangles 103' or path == 'babirhodes/rhodes2' then
         myWorld:emit('breath', biped)
      end
   end
   --print('handling audio message from editGuy')
end

function scene.unload()
   Signal.clear('click-settings-scroll-area-item')
   Signal.clear('click-scroll-list-item')
   Signal.clear('throw-settings-scroll-area')
   Signal.clear('throw-scroll-list')
   Signal.clearPattern('.*') -- clear all signals

   myWorld:clear()
end

function scene.load()
   -- prof.push('frame')
   for i = 1, #fiveGuys do
      fiveGuys[i].guy.transforms.l[1] = 0
   end
   bgColor = creamColor

   --[[
   Timer.after(
       1,
       function()
          Timer.during(
              .3,
              function(dt)
                 local h, s, l, a = vivid.RGBtoHSL(bgColor)
                 l = l * 0.99
                 local r, g, b, a = vivid.HSLtoRGB(h, s, l, a)
                 bgColor = { r, g, b, a }
              end
          )
       end
   )
   --]]
   tiles = love.graphics.newImage('assets/img/tiles/tiles.png')
   tiles2 = love.graphics.newImage('assets/img/tiles/tiles2.png')


   whiterects = {
       love.graphics.newImage('assets/ui/panels/whiterect1.png'),
       love.graphics.newImage('assets/ui/panels/whiterect2.png'),
       love.graphics.newImage('assets/ui/panels/whiterect3.png'),
       love.graphics.newImage('assets/ui/panels/whiterect4.png'),
       love.graphics.newImage('assets/ui/panels/whiterect5.png'),
       love.graphics.newImage('assets/ui/panels/whiterect6.png'),
       love.graphics.newImage('assets/ui/panels/whiterect7.png'),
   }


   bigbuttons        = {
       --head = love.graphics.newImage('assets/ui/big-button-head.png'),
       --headmask = love.graphics.newImage('assets/ui/big-button-head-mask.png'),
       --body = love.graphics.newImage('assets/ui/big-button-body.png'),
       --bodymask = love.graphics.newImage('assets/ui/big-button-body-mask.png'),
       fiveguys = love.graphics.newImage('assets/ui/big-button-fiveguys.png'),
       fiveguysmask = love.graphics.newImage('assets/ui/big-button-fiveguys-mask.png'),
       editguys = love.graphics.newImage('assets/ui/big-button-editguys.png'),
       editguysmask = love.graphics.newImage('assets/ui/big-button-editguys-mask.png'),
       dice = love.graphics.newImage('assets/ui/big-button-dice.png'),
       dicemask = love.graphics.newImage('assets/ui/big-button-dice-mask.png'),
   }
   dots              = {
       love.graphics.newImage('assets/ui/colorpick/c1.png'),
       love.graphics.newImage('assets/ui/colorpick/c2.png'),
       love.graphics.newImage('assets/ui/colorpick/c3.png'),
       love.graphics.newImage('assets/ui/colorpick/c4.png'),
       love.graphics.newImage('assets/ui/colorpick/c5.png'),
       love.graphics.newImage('assets/ui/colorpick/c6.png'),
       love.graphics.newImage('assets/ui/colorpick/c7.png'),
   }

   uiheaders         = {
       love.graphics.newImage('assets/ui/panels/ui-header2.png', { linear = true }),
       love.graphics.newImage('assets/ui/panels/ui-header3.png', { linear = true }),
       love.graphics.newImage('assets/ui/panels/ui-header4.png', { linear = true })
   }
   tabui             = {
       love.graphics.newImage('assets/ui/panels/tab1.png'),
       love.graphics.newImage('assets/ui/panels/tab2.png'),
       love.graphics.newImage('assets/ui/panels/tab3.png'),
   }
   tabuimask         = {
       love.graphics.newImage('assets/ui/panels/tab1-mask.png'),
       love.graphics.newImage('assets/ui/panels/tab2-mask.png'),
       love.graphics.newImage('assets/ui/panels/tab3-mask.png'),
   }
   tabuilogo         = {
       love.graphics.newImage('assets/ui/panels/tab1-logo.png'),
       love.graphics.newImage('assets/ui/panels/tab2-logoC2.png'),
       love.graphics.newImage('assets/ui/panels/tab3-logo.png'),
   }
   colorpickerui     = {
       love.graphics.newImage('assets/ui/colorpick/uifill.png', { linear = true }),
       love.graphics.newImage('assets/ui/colorpick/uipattern.png', { linear = true }),
       love.graphics.newImage('assets/ui/colorpick/uiline.png', { linear = true }),
   }
   colorpickeruimask = {
       love.graphics.newImage('assets/ui/colorpick/uifill-mask.png', { linear = true }),
       love.graphics.newImage('assets/ui/colorpick/uipattern-mask.png', { linear = true }),
       love.graphics.newImage('assets/ui/colorpick/uiline-mask.png', { linear = true }),
   }
   circles           = {
       love.graphics.newImage('assets/ui/circle1.png'),
       love.graphics.newImage('assets/ui/circle2.png'),
       love.graphics.newImage('assets/ui/circle3.png'),
       love.graphics.newImage('assets/ui/circle4.png'),

   }
   rects             = {
       love.graphics.newImage('assets/ui/rect1.png'),
       love.graphics.newImage('assets/ui/rect2.png'),

   }



   sliderimg = {
       track1 = love.graphics.newImage('assets/ui/interfaceparts/slider-track1.png'),
       thumb1 = love.graphics.newImage('assets/ui/interfaceparts/slider-thumb1.png'),
       thumb1Mask = love.graphics.newImage('assets/ui/interfaceparts/slider-thumb1-mask.png'),
       track2 = love.graphics.newImage('assets/ui/interfaceparts/slider-track2.png'),
       thumb2 = love.graphics.newImage('assets/ui/interfaceparts/slider-thumb2.png'),
       thumb2Mask = love.graphics.newImage('assets/ui/interfaceparts/slider-thumb2-mask.png'),
       thumb3 = love.graphics.newImage('assets/ui/interfaceparts/slider-thumb3.png'),
       thumb4 = love.graphics.newImage('assets/ui/interfaceparts/slider-thumb4.png'),
       thumb5 = love.graphics.newImage('assets/ui/interfaceparts/slider-thumb5.png'),
   }
   toggle    = {
       body1 = love.graphics.newImage('assets/ui/interfaceparts/togglebody1.png'),
       body2 = love.graphics.newImage('assets/ui/interfaceparts/togglebody2.png'),
       body3 = love.graphics.newImage('assets/ui/interfaceparts/togglebody3.png'),
       thumb1 = love.graphics.newImage('assets/ui/interfaceparts/togglethumb1.png'),
       thumb2 = love.graphics.newImage('assets/ui/interfaceparts/togglethumb2.png'),
       thumb3 = love.graphics.newImage('assets/ui/interfaceparts/togglethumb3.png'),
   }


   icons       = {
       handspinned = love.graphics.newImage('assets/ui/icons/hands-pinned.png'),
       handsfree = love.graphics.newImage('assets/ui/icons/hands-free.png'),
       feetpinned = love.graphics.newImage('assets/ui/icons/feet-pinned.png'),
       feetfree = love.graphics.newImage('assets/ui/icons/feet-free.png'),
       mouthsmall = love.graphics.newImage('assets/ui/icons/mouth-small.png'),
       mouthtall = love.graphics.newImage('assets/ui/icons/mouth-tall.png'),
       mouthnarrow = love.graphics.newImage('assets/ui/icons/mouth-narrow.png'),
       mouthwide = love.graphics.newImage('assets/ui/icons/mouth-wide.png'),
       browsup = love.graphics.newImage('assets/ui/icons/brows-up.png'),
       browsdown = love.graphics.newImage('assets/ui/icons/brows-down.png'),
       facesmall = love.graphics.newImage('assets/ui/icons/face-small.png'),
       facebig = love.graphics.newImage('assets/ui/icons/face-big.png'),
       bodyfliph1 = love.graphics.newImage('assets/ui/icons/body-fliph1.png'),
       bodyfliph2 = love.graphics.newImage('assets/ui/icons/body-fliph2.png'),
       bodyflipv1 = love.graphics.newImage('assets/ui/icons/body-flipv1.png'),
       bodyflipv2 = love.graphics.newImage('assets/ui/icons/body-flipv2.png'),
       headfliph1 = love.graphics.newImage('assets/ui/icons/head-fliph1.png'),
       headfliph2 = love.graphics.newImage('assets/ui/icons/head-fliph2.png'),
       headflipv1 = love.graphics.newImage('assets/ui/icons/head-flipv1.png'),
       headflipv2 = love.graphics.newImage('assets/ui/icons/head-flipv2.png'),
       headsmall = love.graphics.newImage('assets/ui/icons/head-small.png'),
       headtall = love.graphics.newImage('assets/ui/icons/head-tall.png'),
       headnarrow = love.graphics.newImage('assets/ui/icons/head-narrow.png'),
       headwide = love.graphics.newImage('assets/ui/icons/head-wide.png'),
       bodysmall = love.graphics.newImage('assets/ui/icons/body-small.png'),
       bodytall = love.graphics.newImage('assets/ui/icons/body-tall.png'),
       bodynarrow = love.graphics.newImage('assets/ui/icons/body-narrow.png'),
       bodywide = love.graphics.newImage('assets/ui/icons/body-wide.png'),
       bodypotato = love.graphics.newImage('assets/ui/icons/body-potato.png'),
       bodynonpotato = love.graphics.newImage('assets/ui/icons/body-nonpotato.png'),
       brow1 = love.graphics.newImage('assets/ui/icons/brow-1.png'),
       brow10 = love.graphics.newImage('assets/ui/icons/brow-10.png'),
       brownarrow = love.graphics.newImage('assets/ui/icons/brow-narrow.png'),
       browwide = love.graphics.newImage('assets/ui/icons/brow-wide.png'),
       browthick = love.graphics.newImage('assets/ui/icons/brow-thick.png'),
       browthin = love.graphics.newImage('assets/ui/icons/brow-thin.png'),
       hairthin = love.graphics.newImage('assets/ui/icons/hair-thin.png'),
       hairthick = love.graphics.newImage('assets/ui/icons/hair-thick.png'),
       hairtloose = love.graphics.newImage('assets/ui/icons/hair-loose.png'),
       hairthight = love.graphics.newImage('assets/ui/icons/hair-thight.png'),
       nosedown = love.graphics.newImage('assets/ui/icons/nose-down.png'),
       noseup = love.graphics.newImage('assets/ui/icons/nose-up.png'),
       nosenarrow = love.graphics.newImage('assets/ui/icons/nose-narrow.png'),
       nosewide = love.graphics.newImage('assets/ui/icons/nose-wide.png'),
       nosesmall = love.graphics.newImage('assets/ui/icons/nose-small.png'),
       nosetall = love.graphics.newImage('assets/ui/icons/nose-tall.png'),
       mouthup = love.graphics.newImage('assets/ui/icons/mouth-up.png'),
       mouthdown = love.graphics.newImage('assets/ui/icons/mouth-down.png'),
       pupilsmall = love.graphics.newImage('assets/ui/icons/pupil-small.png'),
       pupilbig = love.graphics.newImage('assets/ui/icons/pupil-big.png'),
       eyesmall1 = love.graphics.newImage('assets/ui/icons/eye-small.png'),
       eyesmall2 = love.graphics.newImage('assets/ui/icons/eye-small2.png'),
       eyewide = love.graphics.newImage('assets/ui/icons/eye-wide.png'),
       eyetall = love.graphics.newImage('assets/ui/icons/eye-tall.png'),
       eyeccw = love.graphics.newImage('assets/ui/icons/eye-ccw.png'),
       eyecw = love.graphics.newImage('assets/ui/icons/eye-cw.png'),
       eyedown = love.graphics.newImage('assets/ui/icons/eye-down.png'),
       eyeup = love.graphics.newImage('assets/ui/icons/eye-up.png'),
       eyefar = love.graphics.newImage('assets/ui/icons/eye-far.png'),
       eyeclose = love.graphics.newImage('assets/ui/icons/eye-close.png'),
       earccw = love.graphics.newImage('assets/ui/icons/ear-ccw.png'),
       earcw = love.graphics.newImage('assets/ui/icons/ear-cw.png'),
       earback = love.graphics.newImage('assets/ui/icons/ear-back.png'),
       earfront = love.graphics.newImage('assets/ui/icons/ear-front.png'),
       earup = love.graphics.newImage('assets/ui/icons/ear-up.png'),
       eardown = love.graphics.newImage('assets/ui/icons/ear-down.png'),
       earsmall = love.graphics.newImage('assets/ui/icons/ear-small.png'),
       earbig = love.graphics.newImage('assets/ui/icons/ear-big.png'),
       patternccw = love.graphics.newImage('assets/ui/icons/pattern-ccw.png'),
       patterncw = love.graphics.newImage('assets/ui/icons/pattern-cw.png'),
       patternfine = love.graphics.newImage('assets/ui/icons/pattern-fine.png'),
       patterncoarse = love.graphics.newImage('assets/ui/icons/pattern-coarse.png'),
       patterntransparent = love.graphics.newImage('assets/ui/icons/pattern-transparent.png'),
       patternopaque = love.graphics.newImage('assets/ui/icons/pattern-opaque.png'),
       legthin = love.graphics.newImage('assets/ui/icons/legs-thin.png'),
       legthick = love.graphics.newImage('assets/ui/icons/legs-thick.png'),
       legflip1 = love.graphics.newImage('assets/ui/icons/legs-flipy1.png'),
       legflip2 = love.graphics.newImage('assets/ui/icons/legs-flipy2.png'),
       legshort = love.graphics.newImage('assets/ui/icons/legs-short.png'),
       leglong = love.graphics.newImage('assets/ui/icons/legs-long.png'),
       legnarrow = love.graphics.newImage('assets/ui/icons/legs-narrow.png'),
       legwide = love.graphics.newImage('assets/ui/icons/legs-wide.png'),
       legstance1 = love.graphics.newImage('assets/ui/icons/legs-stance1.png'),
       legstance2 = love.graphics.newImage('assets/ui/icons/legs-stance2.png'),
       armsshort = love.graphics.newImage('assets/ui/icons/arms-short.png'),
       armslong = love.graphics.newImage('assets/ui/icons/arms-long.png'),
       armsthin = love.graphics.newImage('assets/ui/icons/arms-thin.png'),
       armsthick = love.graphics.newImage('assets/ui/icons/arms-thick.png'),
       armsflip1 = love.graphics.newImage('assets/ui/icons/arms-flip1.png'),
       armsflip2 = love.graphics.newImage('assets/ui/icons/arms-flip2.png'),
       neckshort = love.graphics.newImage('assets/ui/icons/neck-short.png'),
       necklong = love.graphics.newImage('assets/ui/icons/neck-long.png'),
       neckthin = love.graphics.newImage('assets/ui/icons/neck-thin.png'),
       neckthick = love.graphics.newImage('assets/ui/icons/neck-thick.png'),
       footwide = love.graphics.newImage('assets/ui/icons/foot-wide.png'),
       footnarrow = love.graphics.newImage('assets/ui/icons/foot-narrow.png'),
       footshort = love.graphics.newImage('assets/ui/icons/foot-short.png'),
       foottall = love.graphics.newImage('assets/ui/icons/foot-tall.png'),
       handwide = love.graphics.newImage('assets/ui/icons/hand-wide.png'),
       handnarrow = love.graphics.newImage('assets/ui/icons/hand-narrow.png'),
       handshort = love.graphics.newImage('assets/ui/icons/hand-short.png'),
       handtall = love.graphics.newImage('assets/ui/icons/hand-tall.png'),
       patchXless = love.graphics.newImage('assets/ui/icons/patch-Xless.png'),
       patchXmore = love.graphics.newImage('assets/ui/icons/patch-Xmore.png'),
       patchYless = love.graphics.newImage('assets/ui/icons/patch-Yless.png'),
       patchYmore = love.graphics.newImage('assets/ui/icons/patch-Ymore.png'),
       patchAngleless = love.graphics.newImage('assets/ui/icons/patch-Angleless.png'),
       patchAnglemore = love.graphics.newImage('assets/ui/icons/patch-Anglemore.png'),
       patchScaleXless = love.graphics.newImage('assets/ui/icons/patch-ScaleXless.png'),
       patchScaleXmore = love.graphics.newImage('assets/ui/icons/patch-ScaleXmore.png'),
       patchScaleYless = love.graphics.newImage('assets/ui/icons/patch-ScaleYless.png'),
       patchScaleYmore = love.graphics.newImage('assets/ui/icons/patch-ScaleYmore.png'),
   }

   scrollIcons = {
       body = love.graphics.newImage('assets/ui/icons/body.png'),
       bodyMask = love.graphics.newImage('assets/ui/icons/body-mask.png'),
       neck = love.graphics.newImage('assets/ui/icons/neck.png'),
       neckMask = love.graphics.newImage('assets/ui/icons/neck-mask.png'),
       arms2 = love.graphics.newImage('assets/ui/icons/arm.png'),
       arms2Mask = love.graphics.newImage('assets/ui/icons/arm-mask.png'),
       arms = love.graphics.newImage('assets/ui/icons/arm.png'),
       armsMask = love.graphics.newImage('assets/ui/icons/arm-mask.png'),
       armhair = love.graphics.newImage('assets/ui/icons/armhair.png'),
       armhairMask = love.graphics.newImage('assets/ui/icons/armhair-mask.png'),
       legs = love.graphics.newImage('assets/ui/icons/leg.png'),
       legsMask = love.graphics.newImage('assets/ui/icons/leg-mask.png'),
       legs2 = love.graphics.newImage('assets/ui/icons/leg.png'),
       legs2Mask = love.graphics.newImage('assets/ui/icons/leg-mask.png'),
       leghair = love.graphics.newImage('assets/ui/icons/leghair.png'),
       leghairMask = love.graphics.newImage('assets/ui/icons/leghair-mask.png'),
       hands = love.graphics.newImage('assets/ui/icons/hands.png'),
       handsMask = love.graphics.newImage('assets/ui/icons/hands-mask.png'),
       feet = love.graphics.newImage('assets/ui/icons/feet.png'),
       feetMask = love.graphics.newImage('assets/ui/icons/feet-mask.png'),
       eyes = love.graphics.newImage('assets/ui/icons/eyes.png'),
       eyesMask = love.graphics.newImage('assets/ui/icons/eyes-mask.png'),
       nose = love.graphics.newImage('assets/ui/icons/nose.png'),
       noseMask = love.graphics.newImage('assets/ui/icons/nose-mask.png'),
       ears = love.graphics.newImage('assets/ui/icons/ears.png'),
       earsMask = love.graphics.newImage('assets/ui/icons/ears-mask.png'),
       brows = love.graphics.newImage('assets/ui/icons/brows.png'),
       browsMask = love.graphics.newImage('assets/ui/icons/brows-mask.png'),
       hair = love.graphics.newImage('assets/ui/icons/hair.png'),
       hairMask = love.graphics.newImage('assets/ui/icons/hair-mask.png'),
       skinPatchEye1 = love.graphics.newImage('assets/ui/icons/skinpatchEye1.png'),
       skinPatchEye1Mask = love.graphics.newImage('assets/ui/icons/skinpatchEye1-mask.png'),
       skinPatchEye2 = love.graphics.newImage('assets/ui/icons/skinpatchEye2.png'),
       skinPatchEye2Mask = love.graphics.newImage('assets/ui/icons/skinpatchEye2-mask.png'),
       skinPatchSnout = love.graphics.newImage('assets/ui/icons/skinpatchSnout.png'),
       skinPatchSnoutMask = love.graphics.newImage('assets/ui/icons/skinpatchSnout-mask.png'),
       teeth = love.graphics.newImage('assets/ui/icons/teeth.png'),
       teethMask = love.graphics.newImage('assets/ui/icons/teeth-mask.png'),
       lowerlip = love.graphics.newImage('assets/ui/icons/lowerlip.png'),
       lowerlipMask = love.graphics.newImage('assets/ui/icons/lowerlip-mask.png'),
       upperlip = love.graphics.newImage('assets/ui/icons/upperlip.png'),
       upperlipMask = love.graphics.newImage('assets/ui/icons/upperlip-mask.png'),
       head = love.graphics.newImage('assets/ui/icons/head.png'),
       headMask = love.graphics.newImage('assets/ui/icons/head-mask.png'),
       pupils = love.graphics.newImage('assets/ui/icons/pupil.png'),
       pupilsMask = love.graphics.newImage('assets/ui/icons/pupil-mask.png'),
       patches = love.graphics.newImage('assets/ui/icons/patches.png'),
       patchesMask = love.graphics.newImage('assets/ui/icons/patches-mask.png'),
       mouth = love.graphics.newImage('assets/ui/icons/mouth.png'),
       mouthMask = love.graphics.newImage('assets/ui/icons/mouth-mask.png'),
       eyes2 = love.graphics.newImage('assets/ui/icons/eyes.png'),
       eyes2Mask = love.graphics.newImage('assets/ui/icons/eyes-mask.png'),
   }


   scroller            = {
       position = 5
   }

   --scrollPosition      = 7.5
   scrollItemsOnScreen = 5
   scrollListXPosition = 0


   settingsScrollAreaIsDragging = false
   settingsScrollArea = nil
   settingsScrollPosition = 0

   scrollTickSample = love.audio.newSource('assets/sounds/fx/BD-perc.wav', 'static')
   scrollItemClickSample = love.audio.newSource('assets/sounds/fx/CasioMT70-Bassdrum.wav', 'static')
   selectedRootButton = 'body' -- could be head or body or nil
   selectedTab = 'part'
   selectedCategory = 'body'
   selectedColoringLayer = 'bgPal' --- bg fg, line


   hum = {
       love.audio.newSource('assets/sounds/fx/humup1.wav', 'static'),
       love.audio.newSource('assets/sounds/fx/humup2.wav', 'static'),
       love.audio.newSource('assets/sounds/fx/humup3.wav', 'static'),
       love.audio.newSource('assets/sounds/fx/blah1.wav', 'static'),
       love.audio.newSource('assets/sounds/fx/blah2.wav', 'static'),
       love.audio.newSource('assets/sounds/fx/blah3.wav', 'static'),
       -- love.audio.newSource('assets/sounds/blah4.wav', 'static'),
       love.audio.newSource('assets/sounds/fx/huh.wav', 'static'),
       love.audio.newSource('assets/sounds/fx/huh2.wav', 'static'),
       love.audio.newSource('assets/sounds/fx/tsk.wav', 'static'),
       love.audio.newSource('assets/sounds/fx/tsk2.wav', 'static'),

   }
   biep = {
       love.audio.newSource('assets/instruments/babirhodes/ba.wav', 'static'),
       love.audio.newSource('assets/instruments/babirhodes/bi.wav', 'static'),
       love.audio.newSource('assets/instruments/babirhodes/biep2.wav', 'static'),
       love.audio.newSource('assets/instruments/babirhodes/biep3.wav', 'static'),
   }

   headz = {}
   for i = 1, 8 do
      headz[i] = {
          img = love.graphics.newImage('assets/blups/headz' .. i .. '.png'),
          x = love.math.random(),
          y = love.math.random(),
          r = love.math.random() * math.pi * 2
      }
   end

   delta = 0

   root = {
       folder = true,
       name = 'root',
       transforms = { l = { 0, 0, 0, 1, 1, 0, 0 } },
       children = {}
   }




   parts, _ = generate()


   biped = Concord.entity()
   potato = Concord.entity()
   mouth = Concord.entity()

   myWorld:addEntity(biped)
   myWorld:addEntity(potato)
   myWorld:addEntity(mouth)

   biped:give('biped', bipedArguments(editingGuy))
   potato:give('potato', potatoArguments(editingGuy))
   mouth:give('mouth', mouthArguments(editingGuy))

   root.children = { editingGuy.guy }

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

   if false then
      cameraPoints = {}
      local W, H = love.graphics.getDimensions()
      for i = 1, 10 do
         table.insert(
             cameraPoints,
             {
                 x = love.math.random( -W * 2, W * 2),
                 y = love.math.random( -H * 2, H * 2),
                 width = love.math.random(200, 500),
                 height = love.math.random(200, 500),
                 color = { 1, 1, 1 },
             }
         )
      end
   end

   stripPath(root, '/experiments/puppet%-maker/')
   parentize.parentize(root)
   mesh.meshAll(root)
   render.renderThings(root)

   myWorld:emit("bipedInit", biped)
   myWorld:emit("potatoInit", potato)
   myWorld:emit("mouthInit", mouth)

   render.renderThings(root, true)

   attachCallbacks()
   categories = {}
   setCategories(selectedRootButton)

   --local bx, by = editingGuy.body.transforms._g:transformPoint(0, 0)
   local w, h = love.graphics.getDimensions()

   local x1, y1, w1, h1 = getCameraDataZoomOnHeadAndBody()
   tweenCameraData = { x = x1, y = y1, w = w1, h = h1 }

   camera.setCameraViewport(cam, w, h)
   camera.centerCameraOnPosition(x1, y1, w1, h1)
   cam:update(w, h)


   --doCircleOutTransition(love.math.random() * w, love.math.random() * h, function() print('done!') end)
   local sx, sy = getPointToCenterTransitionOn()
   doRectOutTransition(sx, sy, function()
   end)

   Timer.tween(.5, scroller, { position = 7 })


   audioHelper.sendMessageToAudioThread({ type = "paused", data = false });
   audioHelper.sendMessageToAudioThread({ type = "pattern", data = song.pages[2] });
end

function getPointToCenterTransitionOn()
   local w, h = love.graphics.getDimensions()
   local focusOn = editingGuy.values.potatoHead and editingGuy.body or editingGuy.head
   --getHeadPoints(editingGuy.potato)
   local newPoints = getHeadPointsFromValues(editingGuy.values, focusOn,
           editingGuy.values.potatoHead and 'body' or 'head')

   local tX = numbers.mapInto(editingGuy.values.noseXAxis, -2, 2, 0, 1)
   local tY = numbers.mapInto(editingGuy.values.noseYAxis, -3, 3, 0, 1)

   local x = numbers.lerp(newPoints[7][1], newPoints[3][1], tX)
   local y = numbers.lerp(newPoints[1][2], newPoints[5][2], tY)
   local bx, by = focusOn.transforms._g:transformPoint(x, y)

   local sx, sy = cam:getScreenCoordinates(bx, by)
   return sx, sy
end

function skinColorize(bgPal, values)
   local parts = { 'head', 'ears', 'neck', 'nose', 'body', 'arms', 'hands', 'feet', 'legs' }
   for i = 1, #parts do
      if values.potatoHead and parts[i] == 'neck' then

      else
         values[parts[i]].bgPal = bgPal
         changePart(parts[i], values)
      end
   end
end

function hairColorize(fgPal, values)
   local parts = { 'hair', 'leghair', 'armhair', 'brows' }
   for i = 1, #parts do
      values[parts[i]].fgPal = fgPal
      values[parts[i]].linePal = fgPal
      changePart(parts[i], values)
   end
end

local function findPart(name)
   for i = 1, #parts do
      if parts[i].name == name then
         return parts[i]
      end
   end
end

function setCategories(rootButton)
   categories = {}
   if rootButton ~= nil then
      for i = 1, #parts do
         if editingGuy.values.potatoHead and (parts[i].name == 'head' or parts[i].name == 'neck') then
            -- we dont want these categories when we are a potatohead!
         else
            if parts[i].child ~= true then
               -- if rootButton == parts[i].kind and parts[i].child ~= true then
               table.insert(categories, parts[i].name)
            end
         end
      end
   end
end

function getCameraDataZoomOnJustHead()
   local bb = nil
   if editingGuy.values.potatoHead then
      bb = bbox.getBBoxRecursive(editingGuy.body)
   else
      bb = bbox.getBBoxRecursive(editingGuy.head)
   end

   local tlx, tly, brx, bry = bbox.combineBboxes(bb)
   local x2, y2, w2, h2     = bbox.getMiddleAndDimsOfBBox(tlx, tly, brx, bry)
   --return x2, y2, w * 3, h * 3
   local w, h               = love.graphics.getDimensions()
   return 0, y2 + -h2 / 4, w, h2 * 1.5
end

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

function tweenCameraTo(x, y, w, h)
   --tweenCameraData = {x=x, y=y, w=w, h=h}
   --Timer.tween()
   -- Timer.clear()
   Timer.tween(0.2, tweenCameraData, { x = x, y = y, w = w, h = h }, 'in-circ')

   Timer.during(0.3, function()
      camera.centerCameraOnPosition(tweenCameraData.x, tweenCameraData.y, tweenCameraData.w, tweenCameraData.h)
   end)
end

function tweenCameraToHead()
   local x, y, w, h = getCameraDataZoomOnJustHead()
   tweenCameraTo(x, y, w, h)
end

function tweenCameraToHeadAndBody()
   local x, y, w, h = getCameraDataZoomOnHeadAndBody()
   --camera.centerCameraOnPosition(tweenCameraData.x, tweenCameraData.y, tweenCameraData.w, tweenCameraData.h)
   --print(x, y, w, h)
   --camera.centerCameraOnPosition(x, y, w, h)
   tweenCameraTo(x, y, w, h)
end

function backToIntro()
   SM.unload('editGuy')
   SM.load('intro')
end

function attachCallbacks()
   Signal.register('click-settings-scroll-area-item', function(x, y)
      partSettingsScrollable(false, x, y)
   end)

   Signal.register('click-scroll-list-item', function(x, y)
      scrollList(false, x, y)
   end)

   Signal.register('throw-settings-scroll-area', function(dxn, dyn, speed)
      if (math.abs(dyn) > math.abs(dxn)) then
         settingsScrollAreaIsThrown = { velocity = speed / 10, direction = sign(dyn) }
      end
   end)

   Signal.register('throw-scroll-list', function(dxn, dyn, speed)
      if (math.abs(dyn) > math.abs(dxn)) then
         scrollListIsThrown = { velocity = speed / 10, direction = sign(dyn) }
      end
   end)
   --Signal.clearPattern('.*') -- clear all signals

   function love.keypressed(key, unicode)
      local values = editingGuy.values
      if key== 'm' then
         makeMarketingScreenshots('editor')
      end
      if key == 'escape' then
         love.event.quit()
      end
      -- todo make some keys to change bodyparts
      local partToChange = 'feet'
      if key == 'left' then
         values.leg1flop = -1
         values.leg2flop = -1
         myWorld:emit('bipedDirection', biped, 'left')
      end
      if key == 'right' then
         values.leg1flop = 1
         values.leg2flop = 1
         myWorld:emit('bipedDirection', biped, 'right')
      end
      if key == 'down' then
         values.leg1flop = -1
         values.leg2flop = 1
         myWorld:emit('bipedDirection', biped, 'down')
      end
      if key == '1' then
         tweenCameraToHead()
      end
      if key == '2' then
         tweenCameraToHeadAndBody()
      end

      if key == 's' then
         --  local bgPal = math.ceil(love.math.random() * #palettes)
         --  skinColorize(bgPal, values)
      end
      if key == 'h' then
         local fgPal = math.ceil(love.math.random() * #palettes)
         hairColorize(fgPal, values)
      end
      if key == 'p' then
         --local offset = getBodyYOffsetForDefaultStance(biped)
         --editingGuy.guy.transforms.l[2] = offset
         partRandomize(values, true)
         --
         --

         -- myWorld:emit('bipedInit', biped)

         tweenCameraToHeadAndBody()
         myWorld:emit("tweenIntoDefaultStance", biped, true)
      end
      if key == 'f' then
         myWorld:emit('keepFeetPlantedAndStraightenLegs', biped)
      end
      if key == '5' then
         values.faceScale = values.faceScale * 0.75
         values.faceScale = values.faceScale * 0.75
         myWorld:emit('rescaleFaceparts', potato)
      end
      if key == '6' then
         values.faceScale = values.faceScale * 1.25
         values.faceScale = values.faceScale * 1.25
         myWorld:emit('rescaleFaceparts', potato)
      end
      if key == '3' then
         values.mouthScaleX = values.mouthScaleX * 0.75
         --values.mouthScaleY = values.mouthScaleY * 0.75
         myWorld:emit('rescaleFaceparts', potato)
      end
      if key == '4' then
         values.mouthScaleX = values.mouthScaleX * 1.25
         --values.mouthScaleY = values.mouthScaleY * 1.25
         myWorld:emit('rescaleFaceparts', potato)
      end
      if key == 'b' then
         -- myWorld:emit('blinkEyes', potato)
         --myWorld:emit('birthGuy', biped)
         myWorld:emit('breath', biped)
      end

      if key == 'v' then
         myWorld:emit('blinkEyes', potato)
         --myWorld:emit('birthGuy', biped)
         --myWorld:emit('breath', biped)
      end

      if key == 'd' then
         myWorld:emit('doinkBody', biped)
      end
      --if key == 'm' then
         --myWorld:emit('mouthSaySomething', mouth, love.math.random())
         --myWorld:emit('mouthOpener', potato, love.math.random())
      --end
      --if k == 'm' then
         -- print('M')
         -- myWorld:emit('mouthSaySomething', mouth, 1)
      --end
      if key == 's' then
         grabShot()
      end
      if key == 'i' then
         backToIntro()
      end
   end

   function love.touchpressed(id, x, y, dx, dy, pressure)
      pointerPressed(x, y, id)
      ui.addToPressedPointers(x, y, id)
   end

   function love.mousepressed(x, y, button, istouch, presses)
      if not istouch then
         pointerPressed(x, y, 'mouse')
         ui.addToPressedPointers(x, y, 'mouse')
      end
   end

   function love.mousemoved(x, y, dx, dy, istouch)
      if not istouch then
         pointerMoved(x, y, dx, dy, 'mouse')
      end
   end

   function love.touchmoved(id, x, y, dx, dy, pressure)
      pointerMoved(x, y, dx, dy, id)
   end

   function love.mousereleased(x, y, button, istouch)
      lastDraggedElement = nil
      if not istouch then
         pointerReleased(x, y, 'mouse')
         ui.removeFromPressedPointers('mouse')
      end
   end

   function love.touchreleased(id, x, y, dx, dy, pressure)
      pointerReleased(x, y, id)
      ui.removeFromPressedPointers(id)
   end

   function love.resize(w, h)
      local w, h = love.graphics.getDimensions()

      --local x1, y1, w1, h1 = getCameraDataZoomOnHeadAndBody()
      local x1, y1, w1, h1 = getCameraDataZoomOnJustHead()
      tweenCameraData = { x = x1, y = y1, w = w1, h = h1 }

      camera.setCameraViewport(cam, w, h)
      camera.centerCameraOnPosition(x1, y1, w1, h1)
      cam:update(w, h)
   end

   function love.wheelmoved(dx, dy)
      if true then
         local newScale = cam.scale * (1 + dy / 10)
         if (newScale > 0.01 and newScale < 50) then
            cam:scaleToPoint(1 + dy / 10)
         end
      end
   end
end

local function updateTheScrolling(dt, thrown, pos)
   local oldPos = pos
   if (thrown) then
      thrown.velocity = thrown.velocity * .9

      pos = pos + ((thrown.velocity * thrown.direction) * .1 * dt)

      if (math.floor(oldPos) ~= math.floor(pos)) then
         if not settingsScrollArea[8] then
            playSound(scrollTickSample)
         end
      end
      if (thrown.velocity < 0.01) then
         thrown.velocity = 0
         thrown = nil
      end
   end
   return pos
end

function grabShot()
   for i = 1, #editingGuy.head.children do
      --    editingGuy.head.children[i].hidden = true
   end

   render.renderThings(editingGuy.head, true)
   local part = math.ceil(love.math.random() * 1000)
   render.renderNodeIntoCanvas(editingGuy.head, love.graphics.newCanvas(1024, 1024), part .. ".png", 0.5)
   local openURL = "file://" .. love.filesystem.getSaveDirectory()
   love.system.openURL(openURL)
end

function scene.update(dt)
   --prof.push("frame")

   if introSound:isPlaying() then
      local volume = introSound:getVolume()
      introSound:setVolume(volume * .90)
      if (volume < 0.01) then
         introSound:stop()
      end
   end
   if splashSound:isPlaying() then
      local volume = splashSound:getVolume()
      splashSound:setVolume(volume * .90)
      if volume < 0.01 then
         splashSound:stop()
      end
   end


   delta = delta + dt
   Timer.update(dt)


   if settingsScrollArea and settingsScrollArea[6] then
      if settingsScrollPosition > settingsScrollArea[6] then
         settingsScrollPosition = settingsScrollArea[6]
      end
      if settingsScrollPosition < settingsScrollArea[7] then
         settingsScrollPosition = settingsScrollArea[7]
      end
   end



   scroller.position = updateTheScrolling(dt, scrollListIsThrown, scroller.position)
   settingsScrollPosition = updateTheScrolling(dt, settingsScrollAreaIsThrown, settingsScrollPosition)



   --myWorld:emit("update", dt) -- this one is leaking the most actually
   --prof.pop("frame")
end

function scene.draw()
   --   prof.enabled(false)
   --prof.push("frame")


   if true then
      local w, h = love.graphics.getDimensions()

      if true then
         ui.handleMouseClickStart()
         love.graphics.clear(bgColor)

         love.graphics.setColor(1, 1, 1, 0.5)
         love.graphics.draw(skygradient, 0, 0, 0, love.graphics.getDimensions())
         love.graphics.setColor(0, 0, 0)

         -- do these via vector sketch snf the scene graph
         love.graphics.setColor(0, 0, 0, 0.05)
         love.graphics.draw(tiles, 400, 0, .1)
         love.graphics.setColor(1, 0, 0, 0.05)
         love.graphics.draw(tiles2, 1000, 300, math.pi / 2, 2, 2)

         for i = 1, #headz do
            love.graphics.setColor(0, 0, 0, 0.05)
            love.graphics.draw(headz[i].img, headz[i].x * w, headz[i].y * h, headz[i].r)
         end

         love.graphics.setColor(1, 1, 1)
      end

      love.graphics.setColor(0, 0, 0)
      --headOrBody(true)
      scrollList(true)

      partSettingsPanel()

      prof.push("cam-render")
      cam:push()



      --      for i =1 , #editingGuy.head.children do
      --          editingGuy.head.children[i].hidden = true
      --      end
      --      for i =1 , #editingGuy.body.children do
      --       editingGuy.body.children[i].hidden = true
      --   end
      --      editingGuy.head.hidden = true
      --      editingGuy.hair.hidden = false
      -- render.renderThings(editingGuy.head, true)
      -- render.renderThings(editingGuy.eye1, true)


      render.renderThings(root, true)



      if false then
         for i = 1, #root.children do
            local px, py = root.children[i].transforms._g:transformPoint(0, 0)
            love.graphics.rectangle('fill', px - 25, py - 25, 50, 50)
         end
      end

      if false then
         for _, v in pairs(cameraPoints) do
            love.graphics.setColor(v.color)
            love.graphics.rectangle('line', v.x, v.y, v.width, v.height)
         end
      end

      cam:pop()
      --drawBBoxDebug()
      prof.pop("cam-render")


      if false then -- this is leaking too
         local stats = love.graphics.getStats()
         local str = string.format("texture memory used: %.2f MB", stats.texturememory / (1024 * 1024))
         love.graphics.setColor(1, 1, 1, 1)
         love.graphics.print(inspect(stats), 10, 30)
         love.graphics.setColor(0, 0, 0, 1)
         love.graphics.print(inspect(stats), 11, 31)

         love.graphics.print("FPS: " .. tostring(love.timer.getFPS()), 10, 10)
      end
   end


   local w, h = love.graphics.getDimensions()


   if true then
      local size = (h / 8) -- margin around panel
      local x = w - size
      local y = 0

      love.graphics.setColor(0, 0, 0, 0.5)
      local sx, sy = createFittingScale(circles[1], size, size)
      love.graphics.draw(circles[1], x, y, 0, sx, sy)

      --love.graphics.rectangle('fill', w - size, 0, size, size)
      --love.graphics.setColor(1, 0, 1)
      local sx, sy = createFittingScale(bigbuttons.fiveguys, size, size)
      love.graphics.setColor(1, 1, 1)
      love.graphics.draw(bigbuttons.fiveguysmask, x, y, 0, sx, sy)
      love.graphics.setColor(0, 0, 0)
      love.graphics.draw(bigbuttons.fiveguys, x, y, 0, sx, sy)
   end


   if true then
      local size = (h / 8) -- margin around panel
      local x = w - size
      local y = h - size

      love.graphics.setColor(0, 0, 0, 0.5)
      local sx, sy = createFittingScale(circles[1], size, size)
      love.graphics.draw(circles[1], x, y, 0, sx, sy)

      --love.graphics.rectangle('fill', w - size, 0, size, size)
      --love.graphics.setColor(1, 0, 1)
      local sx, sy = createFittingScale(bigbuttons.dice, size, size)
      love.graphics.setColor(1, 1, 1)
      love.graphics.draw(bigbuttons.dicemask, x, y, 0, sx, sy)
      love.graphics.setColor(0, 0, 0)
      love.graphics.draw(bigbuttons.dice, x, y, 0, sx, sy)
   end

   if transition then
      renderTransition(transition)
   end

   --local w, h = love.graphics.getDimensions()
   --love.graphics.rectangle('fill', w - 25, 0, 25, 25)
   -- prof.pop("frame")
   --collectgarbage()
end

function drawBBoxDebug()
   if true then
      love.graphics.push() -- stores the default coordinate system
      local w, h = love.graphics.getDimensions()
      love.graphics.translate(w / 2, h / 2)
      love.graphics.scale(.5) -- zoom the camera
      if love.mouse.isDown(1) then
         local mx, my = love.mouse:getPosition()
         local wx, wy = cam:getWorldCoordinates(mx, my)

         for j = 1, #root.children do
            local guy = root.children[j]

            for i = 1, #guy.children do
               local item = guy.children[i]
               local b = bbox.getBBoxRecursiveVersion2(item)


               if b then
                  local mx1, my1 = item.transforms._g:inverseTransformPoint(wx, wy)
                  local tlx2, tly2 = item.transforms._g:inverseTransformPoint(b[1], b[2])
                  local brx2, bry2 = item.transforms._g:inverseTransformPoint(b[3], b[4])

                  love.graphics.print(item.name, mx1, my1)
                  love.graphics.circle('line', mx1, my1, 10)

                  love.graphics.print(item.name, tlx2, tly2)
                  love.graphics.rectangle('line', tlx2, tly2, brx2 - tlx2, bry2 - tly2)

                  if item.children then
                     if (item.children[1].name == 'generated') then
                        -- todo this part is still not correct?
                        local tlx, tly, brx, bry = bbox.getPointsBBox(item.children[1].points)

                        love.graphics.setColor(1, 0, 0, 0.5)
                        love.graphics.rectangle('line', tlx, tly, brx - tlx, bry - tly)
                        love.graphics.setColor(0, 0, 0)
                        -- how to map that location ino the texture dimensions ?
                        local imgW, imgH = item.children[1].texture.imageData:getDimensions()
                        local xx = numbers.mapInto(mx1, tlx, brx, 0, imgW)
                        local yy = numbers.mapInto(my1, tly, bry, 0, imgH)
                        if (xx >= 0 and xx < imgW and yy >= 0 and yy < imgH) then
                           local r, g, b, a = item.children[1].texture.imageData:getPixel(xx, yy)
                           if (a > 0) then
                              love.graphics.setColor(1, 0, 1, 1)
                              love.graphics.rectangle('line', tlx, tly, brx - tlx, bry - tly)
                              love.graphics.setColor(0, 0, 0)
                           end
                        end
                     end
                  end
               end
            end
         end
      end
      love.graphics.pop() -- stores the default coordinate system
   end
end

return scene

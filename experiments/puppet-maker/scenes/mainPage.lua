-- https://medium.com/@chrisgaul/https-medium-com-chrisgaul-is-this-language-without-letters-the-future-of-global-communication-15fc54909c12
-- http://bamanda.com/locos/locos_subsite/locos_gallery.html
-- https://ai.facebook.com/blog/using-ai-to-bring-childrens-drawings-to-life/
local scene      = {}

local vivid      = require 'vendor.vivid'
local Timer      = require 'vendor.timer'
local inspect    = require 'vendor.inspect'
local Signal     = require 'vendor.signal'

local text       = require 'lib.text'
local render     = require 'lib.render'
local mesh       = require 'lib.mesh'
local parentize  = require 'lib.parentize'
local node       = require 'lib.node'
local parse      = require 'lib.parse-file'
local bbox       = require 'lib.bbox'
local hit        = require 'lib.hit'
local transforms = require 'lib.transform'
local numbers    = require 'lib.numbers'
local ui         = require 'lib.ui'
local gradient   = require 'lib.gradient'

local camera     = require 'lib.camera'
local cam        = require('lib.cameraBase').getInstance()
local creamColor = { 238 / 255, 226 / 255, 188 / 255, 1 }

local Components = {}
local Systems    = {}

myWorld          = Concord.world()

require 'src.generatePuppet'
require 'src.puppet-maker-ui'

Concord.utils.loadNamespace("src/components", Components)
Concord.utils.loadNamespace("src/systems", Systems)
myWorld:addSystems(Systems.BipedSystem, Systems.PotatoHeadSystem)


local pointerInteractees = {}


nullObject = {
    folder = true,
    name = 'nullObject',
    transforms = { l = { 0, 0, 0, 1, 1, 0, 0 } },
    children = {}
}


local function sign(x)
   return x > 0 and 1 or x < 0 and -1 or 0
end

function stripPath(root, path)
   if root and root.texture and root.texture.url and #root.texture.url > 0 then
      local str = root.texture.url
      local shortened = string.gsub(str, path, '')
      root.texture.url = shortened
      --print(shortened)
   end

   if root.children then
      for i = 1, #root.children do
         stripPath(root.children[i], path)
      end
   end

   return root
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

function removeChild(elem)
   if elem._parent then
      local index = node.getIndex(elem)
      if index >= 0 then table.remove(elem._parent.children, index) end
   end
end

function getPNGMaskUrl(url)
   return text.replace(url, '.png', '-mask.png')
end

function playSound(sound)
   local s = sound:clone()
   s:setPitch(.99 + .02 * love.math.random())
   s:setVolume(.25)
   love.audio.play(s)
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

function pointerMoved(x, y, dx, dy, id)
   for i = 1, #pointerInteractees do
      if pointerInteractees[i].id == id then
         local scale = cam:getScale()

         if love.mouse.isDown(1) then
            myWorld:emit("itemDrag", pointerInteractees[i], dx, dy, scale)
         end
         if love.mouse.isDown(2) then
            myWorld:emit("itemRotate", pointerInteractees[i], dx, dy, scale)
         end
      end
   end

   -- only do this when the scroll ui is visible (always currently)
   if scrollerIsDragging then
      local w, h = love.graphics.getDimensions()
      local oldScrollPos = scrollPosition
      scrollPosition = scrollPosition + dy / (h / scrollItemsOnScreen)
      local newScrollPos = scrollPosition
      if (math.floor(oldScrollPos) ~= math.floor(newScrollPos)) then
         -- play sound
         playSound(scrollTickSample)
      end
   end

   if settingsScrollAreaIsDragging then
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
         table.remove(pointerInteractees, i)
      end
   end

   scrollerIsDragging = false
   settingsScrollAreaIsDragging = false

   gesture.maybeTrigger(id, x, y)
   -- I probably need to add the xyoffset too, so this panel can be tweened in and out the screen
   partSettingsSurroundings(false, x, y)
   collectgarbage()
end

function pointerPressed(x, y, id)
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
                  table.insert(pointerInteractees, { state = 'pressed', item = item, x = x, y = y, id = id })
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
   local x, y = love.mouse.getPosition()

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

local function loadGroupFromFile(url, groupName)
   local imgs = {}
   local parts = {}

   local whole = parse.parseFile(url)
   local group = node.findNodeByName(whole, groupName) or {}
   for i = 1, #group.children do
      local p = group.children[i]
      stripPath(p, '/experiments/puppet%-maker/')
      for j = 1, #p.children do
         if p.children[j].texture then
            imgs[i] = p.children[j].texture.url
            parts[i] = group.children[i]
         end
      end
   end
   return imgs, parts
end

function attachAllFaceParts()
   removeChild(eye1)
   removeChild(eye2)
   removeChild(pupil1)
   removeChild(pupil2)
   removeChild(nose)
   removeChild(brow1)
   removeChild(brow2)
   removeChild(ear1)
   removeChild(ear2)
   removeChild(hair)
   removeChild(upperlip)
   removeChild(lowerlip)

   local addTo = values.potatoHead and body or head

   table.insert(addTo.children, eye1)
   table.insert(addTo.children, eye2)
   table.insert(addTo.children, pupil1)
   table.insert(addTo.children, pupil2)

   if (values.earUnderHead == true) then
      table.insert(addTo.children, 1, ear1)
      table.insert(addTo.children, 1, ear2)
   else
      table.insert(addTo.children, ear1)
      table.insert(addTo.children, ear2)
   end

   table.insert(addTo.children, lowerlip)
   table.insert(addTo.children, upperlip)

   table.insert(addTo.children, brow1)
   table.insert(addTo.children, brow2)
   table.insert(addTo.children, nose)
   table.insert(addTo.children, hair)

   changePart('hair', values)
end

function scene.load()
   bgColor = creamColor

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

   blup0 = love.graphics.newImage('assets/blups/blup1.png')
   blup1 = love.graphics.newImage('assets/blups/blup5.png')
   blup2 = love.graphics.newImage('assets/blups/blup2.png')
   blup3 = love.graphics.newImage('assets/blups/blup3.png')
   blup4 = love.graphics.newImage('assets/blups/blup4.png')
   tiles = love.graphics.newImage('assets/layered/tiles.145.png')
   tiles2 = love.graphics.newImage('assets/layered/tiles2.150.png')


   tab1 = love.graphics.newImage('assets/tab1.png')
   tab2 = love.graphics.newImage('assets/tab2.png')
   tab3 = love.graphics.newImage('assets/tab3.png')
   textures = {

       love.graphics.newImage('assets/layered/texture-type0.png'),
       love.graphics.newImage('assets/layered/texture-type2t.png'),
       love.graphics.newImage('assets/layered/texture-type1.png'),
       love.graphics.newImage('assets/layered/texture-type3.png'),
       love.graphics.newImage('assets/layered/texture-type4.png'),
       love.graphics.newImage('assets/layered/texture-type5.png'),
       love.graphics.newImage('assets/layered/texture-type6.png'),
       love.graphics.newImage('assets/layered/texture-type7.png'),


   }
   for i = 1, #textures do
      textures[i]:setWrap('mirroredrepeat', 'mirroredrepeat')
   end

   whiterects = {
       love.graphics.newImage('assets/whiterect1.png'),
       love.graphics.newImage('assets/whiterect2.png'),
       love.graphics.newImage('assets/whiterect3.png'),
       love.graphics.newImage('assets/whiterect4.png'),
       love.graphics.newImage('assets/whiterect5.png'),
       love.graphics.newImage('assets/whiterect6.png'),
       love.graphics.newImage('assets/whiterect7.png'),
   }

   dots = {
       love.graphics.newImage('assets/blups/dot1.150.png'),
       love.graphics.newImage('assets/blups/dot2.150.png'),
       love.graphics.newImage('assets/blups/dot3.150.png'),
       love.graphics.newImage('assets/blups/dot4.150.png'),
       love.graphics.newImage('assets/blups/dot5.150.png'),
       love.graphics.newImage('assets/blups/dot6.150.png'),
       love.graphics.newImage('assets/blups/dot7.150.png'),
       love.graphics.newImage('assets/blups/dot8.150.png'),
       love.graphics.newImage('assets/blups/dot9.150.png'),
       love.graphics.newImage('assets/blups/dot10.150.png'),
       love.graphics.newImage('assets/blups/dot11.150.png'),
       love.graphics.newImage('assets/blups/dot12.150.png'),
   }

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

   for i = 1, #base do
      local r, g, b = hex2rgb(base[i])
      table.insert(palettes, { r, g, b })
   end

   local timeIndex = math.floor(1 + love.math.random() * 24)
   skygradient = gradient.makeSkyGradient(16)

   scrollPosition = .5
   scrollItemsOnScreen = 5
   scrollListXPosition = 20

   settingsScrollAreaIsDragging = false
   settingsScrollArea = nil
   settingsScrollPosition = 0
   scrollTickSample = love.audio.newSource(love.sound.newSoundData('assets/sounds/BD-perc.wav'), 'static')
   scrollItemClickSample = love.audio.newSource(love.sound.newSoundData('assets/sounds/CasioMT70-Bassdrum.wav'), 'static')


   selectedTab = 'part'
   selectedCategory = 'body'
   selectedColoringLayer = 1 --- bg fg, line





   uiBlup = love.graphics.newImage('assets/blups/blup8.png')

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





   legUrls = { 'assets/parts/leg1.png', 'assets/parts/leg2.png', 'assets/parts/leg3.png', 'assets/parts/leg4.png',
       'assets/parts/leg5.png' }

   hairUrls = { 'assets/parts/hair1.png', 'assets/parts/hair2.png', 'assets/parts/hair3.png', 'assets/parts/hair4.png',
       'assets/parts/hair5.png', 'assets/parts/hair6.png', 'assets/parts/hair7.png', 'assets/parts/hair8.png' }

   --bodyImgUrls = {}
   --bodyParts = {}
   -- bodies use the same shapes as the heads
   --[[
   local bparts = parse.parseFile('assets/bodies.polygons.txt')

   for i = 1, #bparts do
      local p = bparts[i]
      stripPath(p, '/experiments/puppet%-maker/')
      for j = 1, #p.children do
         if p.children[j].texture then
            bodyImgUrls[i] = p.children[j].texture.url
            bodyParts[i] = bparts[i]
         end
      end
   end
   --]]
   bodyImgUrls, bodyParts = loadGroupFromFile('assets/bodies.polygons.txt', 'bodies')
   feetImgUrls, feetParts = loadGroupFromFile('assets/bodies.polygons.txt', 'feet')
   handParts = feetParts
   headImgUrls = bodyImgUrls
   headParts = bodyParts

   -- a working nullobject implentation!
   if false then
      local p = #bodyParts + 1
      bodyParts[p] = copy3(nullObject)
      bodyImgUrls[p] = 'assets/null.png'
   end



   --local faceparts = parse.parseFile('assets/faceparts.polygons.txt')

   eyeImgUrls, eyeParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'eyes')
   pupilImgUrls, pupilParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'pupils')
   noseImgUrls, noseParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'noses')
   browImgUrls, browParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'eyebrows')
   earImgUrls, earParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'ears')
   upperlipImgUrls, upperlipParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'upperlips')
   lowerlipImgUrls, lowerlipParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'lowerlips')
   texscales = { 0.06, 0.12, 0.24, 0.48, 0.64, 0.96, 1.28, 1.64, 2.56 }

   biped = Concord.entity()
   potato = Concord.entity()


   parts = {
       { name = 'head',     imgs = headImgUrls,     p = headParts },
       { name = 'hair',     imgs = hairUrls },
       { name = 'brows',    imgs = browImgUrls,     p = browParts },
       { name = 'pupils',   imgs = pupilImgUrls,    p = pupilParts },
       { name = 'eyes',     imgs = eyeImgUrls,      p = eyeParts },
       { name = 'ears',     imgs = earImgUrls,      p = earParts },
       { name = 'neck',     imgs = legUrls },
       { name = 'nose',     imgs = noseImgUrls,     p = noseParts },
       { name = 'upperlip', imgs = upperlipImgUrls, p = upperlipParts },
       { name = 'lowerlip', imgs = lowerlipImgUrls, p = lowerlipParts },
       { name = 'body',     imgs = bodyImgUrls,     p = bodyParts },
       { name = 'arms',     imgs = legUrls },
       { name = 'hands',    imgs = feetImgUrls,     p = feetParts },
       { name = 'legs',     imgs = legUrls },
       { name = 'feet',     imgs = feetImgUrls,     p = feetParts }

   }


   values = {
       potatoHead              = false,
       upperlip                = {
           shape     = 1,
           bgPal     = 4,
           fgPal     = 5,
           bgTex     = 1,
           fgTex     = 1,
           linePal   = 1,
           bgAlpha   = 5,
           fgAlpha   = 5,
           lineAlpha = 5,
           texRot    = 0,
           texScale  = 1,
       },
       upperlipWidthMultiplier = 1,
       lowerlip                = {
           shape     = 1,
           bgPal     = 4,
           fgPal     = 5,
           bgTex     = 1,
           fgTex     = 1,
           linePal   = 1,
           bgAlpha   = 5,
           fgAlpha   = 5,
           lineAlpha = 5,
           texRot    = 0,
           texScale  = 1,
       },
       lowerlipWidthMultiplier = 1,
       mouthXAxis              = 0,
       mouthYAxis              = 1,
       eyes                    = {
           shape     = 1,
           bgPal     = 4,
           fgPal     = 5,
           bgTex     = 1,
           fgTex     = 1,
           linePal   = 1,
           bgAlpha   = 5,
           fgAlpha   = 5,
           lineAlpha = 5,
           texRot    = 0,
           texScale  = 1,
       },
       eyeWidthMultiplier      = 1,
       eyeHeightMultiplier     = 1,
       eyeRotation             = 0,
       eyeYAxis                = 0,
       pupils                  = {
           shape     = 1,
           bgPal     = 4,
           fgPal     = 5,
           bgTex     = 1,
           fgTex     = 1,
           linePal   = 1,
           bgAlpha   = 5,
           fgAlpha   = 5,
           lineAlpha = 5,
           texRot    = 0,
           texScale  = 1,
       },
       pupilSizeMultiplier     = 1,
       ears                    = {
           shape     = 1,
           bgPal     = 4,
           fgPal     = 1,
           bgTex     = 1,
           fgTex     = 2,
           linePal   = 1,
           bgAlpha   = 5,
           fgAlpha   = 5,
           lineAlpha = 5,
           texRot    = 0,
           texScale  = 1,
       },
       earUnderHead            = false,
       earWidthMultiplier      = 1,
       earHeightMultiplier     = 1,
       earRotation             = 0,
       earYAxis                = 0, -- -2,-1,0,1,2
       brows                   = {
           shape     = 1,
           bgPal     = 4,
           fgPal     = 1,
           bgTex     = 1,
           fgTex     = 2,
           linePal   = 1,
           bgAlpha   = 5,
           fgAlpha   = 5,
           lineAlpha = 5,
           texRot    = 0,
           texScale  = 1,
       },
       browsWidthMultiplier    = .5,
       browsWideMultiplier     = 1,
       browsDefaultBend        = 1,
       nose                    = {
           shape     = 1,
           bgPal     = 4,
           fgPal     = 1,
           bgTex     = 1,
           fgTex     = 2,
           linePal   = 1,
           bgAlpha   = 5,
           fgAlpha   = 5,
           lineAlpha = 5,
           texRot    = 0,
           texScale  = 1,

       },
       noseXAxis               = 0, --  -2,-1,0,1,2
       noseYAxis               = 0, --  -3, -2,-1,0,1,2, 3
       noseWidthMultiplier     = 1,
       noseHeightMultiplier    = 1,
       legs                    = {
           shape     = 1,
           bgPal     = 4,
           fgPal     = 1,
           bgTex     = 1,
           fgTex     = 2,
           linePal   = 1,
           bgAlpha   = 5,
           fgAlpha   = 5,
           lineAlpha = 5,
           texRot    = 0,
           texScale  = 1,
       },
       legLength               = 700,
       legWidthMultiplier      = 1,
       leg1flop                = -1,
       leg2flop                = 1,
       legXAxis                = 0,
       arms                    = {
           shape     = 1,
           bgPal     = 4,
           fgPal     = 1,
           bgTex     = 1,
           fgTex     = 2,
           linePal   = 1,
           bgAlpha   = 5,
           fgAlpha   = 5,
           lineAlpha = 5,
           texRot    = 0,
           texScale  = 1,
       },
       armLength               = 700,
       armWidthMultiplier      = 1,
       arm1flop                = 1,
       arm2flop                = -1,
       hands                   = {
           shape     = 1,
           bgPal     = 4,
           fgPal     = 1,
           bgTex     = 1,
           fgTex     = 2,
           linePal   = 1,
           bgAlpha   = 5,
           fgAlpha   = 5,
           lineAlpha = 5,
           texRot    = 0,
           texScale  = 1,
       },
       body                    = {
           shape     = 1,
           bgPal     = 4,
           fgPal     = 1,
           bgTex     = 1,
           fgTex     = 2,
           linePal   = 1,
           flipy     = 1,
           bgAlpha   = 5,
           fgAlpha   = 1,
           lineAlpha = 5,
           texRot    = 0,
           texScale  = 1,
       },
       bodyWidthMultiplier     = 1,
       bodyHeightMultiplier    = 1,
       head                    = {
           shape     = 1,
           bgPal     = 4,
           fgPal     = 1,
           bgTex     = 1,
           fgTex     = 2,
           linePal   = 1,
           flipx     = 1,
           flipy     = 1,
           bgAlpha   = 5,
           fgAlpha   = 1,
           lineAlpha = 5,
           texRot    = 0,
           texScale  = 1,
       },
       headWidthMultiplier     = 1,
       headHeightMultiplier    = 1,
       hair                    = {
           shape     = 1,
           bgPal     = 4,
           fgPal     = 5,
           bgTex     = 1,
           fgTex     = 1,
           linePal   = 1,
           bgAlpha   = 5,
           fgAlpha   = 5,
           lineAlpha = 5,
           texRot    = 0,
           texScale  = 1,
           flipx     = 1,
           flipy     = -1
       },
       hairWidthMultiplier     = 1,
       hairTension             = 0.001,
       neck                    = {
           shape     = 1,
           bgPal     = 4,
           fgPal     = 1,
           bgTex     = 1,
           fgTex     = 2,
           linePal   = 1,
           bgAlpha   = 5,
           fgAlpha   = 5,
           lineAlpha = 5,
           texRot    = 0,
           texScale  = 1,
       },
       neckLength              = 700,
       neckWidthMultiplier     = 1,
       feet                    = {
           shape     = 1,
           bgPal     = 4,
           fgPal     = 1,
           bgTex     = 1,
           fgTex     = 2,
           linePal   = 1,
           bgAlpha   = 5,
           fgAlpha   = 5,
           lineAlpha = 5,
           texRot    = 0,
           texScale  = 1,
       },
   }



   head = copyAndRedoGraphic('head', values) --copy3(headParts[values.head.shape])

   neck = createNeckRubberhose(values)
   body = copyAndRedoGraphic('body', values) --copy3(bodyParts[values.body.shape])
   hair = createHairVanillaLine(values)

   arm1 = createArmRubberhose(1, values)
   arm2 = createArmRubberhose(2, values)
   hand1 = copyAndRedoGraphic('hands', values)
   hand2 = copyAndRedoGraphic('hands', values)

   leg1 = createLegRubberhose(1, values)
   leg2 = createLegRubberhose(2, values)
   feet1 = copyAndRedoGraphic('feet', values)
   feet2 = copyAndRedoGraphic('feet', values)

   eye1 = copyAndRedoGraphic('eyes', values)
   eye2 = copyAndRedoGraphic('eyes', values)
   pupil1 = copyAndRedoGraphic('pupils', values)
   pupil2 = copyAndRedoGraphic('pupils', values)
   brow1 = createBrowBezier(values)
   brow2 = createBrowBezier(values)

   upperlip = createUpperlipBezier(values)
   lowerlip = createLowerlipBezier(values)

   ear1 = copyAndRedoGraphic('ears', values)
   ear2 = copyAndRedoGraphic('ears', values)

   nose = copy3(noseParts[values.nose.shape])

   biped:give('biped', bipedArguments(values))
   potato:give('potato', potatoArguments(values))

   guy = {
       folder = true,
       name = 'guy',
       transforms = { l = { 0, 0, 0, 1, 1, 0, 0, 0, 0 } },
       children = {}
   }

   guy.children = guyChildren(biped)
   root.children = { guy }


   attachAllFaceParts()


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

   myWorld:addEntity(biped)
   myWorld:addEntity(potato)

   myWorld:emit("bipedInit", biped)
   myWorld:emit("potatoInit", potato)

   render.renderThings(root, true)
   attachCallbacks()

   categories = {}
   setCategories()

   local bx, by = body.transforms._g:transformPoint(0, 0)
   local w, h = love.graphics.getDimensions()

   camera.setCameraViewport(cam, w, h)
   camera.centerCameraOnPosition(bx, by, w * 1, h * 4)
   cam:update(w, h)
end

function findPart(name)
   for i = 1, #parts do
      if parts[i].name == name then
         return parts[i]
      end
   end
end

function setCategories()
   categories = {}
   for i = 1, #parts do
      if values.potatoHead and (parts[i].name == 'head' or parts[i].name == 'neck') then
         -- we dont want these categories when we are a potatohead!
      else
         table.insert(categories, parts[i].name)
      end
   end
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
      if key == 'escape' then
         collectgarbage()
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
         local x2, y2, w, h = bbox.getMiddleOfContainer(head)
         camera.centerCameraOnPosition(x2, y2, w * 1.61, h * 1.61)
      end
      if key == '2' then
         local bbBody = bbox.getBBoxRecursive(body)
         local bbFeet1 = bbox.getBBoxRecursive(feet1)
         local bbFeet2 = bbox.getBBoxRecursive(feet2)
         local tlx, tly, brx, bry = bbox.combineBboxes(bbBody, bbFeet1, bbFeet2)
         local x2, y2, w, h = bbox.getMiddleAndDimsOfBBox(tlx, tly, brx, bry)

         camera.centerCameraOnPosition(x2, y2, w * 1.61, h * 1.61)
         --print('focus camera on second other shape', x, y)
      end
      if key == '3' then
         local bbHead             = bbox.getBBoxRecursive(head)
         local bbBody             = bbox.getBBoxRecursive(body)
         local bbFeet1            = bbox.getBBoxRecursive(feet1)
         local bbFeet2            = bbox.getBBoxRecursive(feet2)

         local points             = {
             { head.transforms.l[1],  head.transforms.l[2] },
             { feet2.transforms.l[1], feet2.transforms.l[2] },
             { feet1.transforms.l[1], feet1.transforms.l[2] },
         }

         local tlx, tly, brx, bry = bbox.getPointsBBox(points)
         local x2, y2, w, h       = bbox.getMiddleAndDimsOfBBox(tlx, tly, brx, bry)

         camera.centerCameraOnPosition(x2, y2, w * 1.61, h * 1.61)
         print('focus camera on third other shape', x, y)
      end
   end

   function love.touchpressed(id, x, y, dx, dy, pressure)
      pointerPressed(x, y, id)
   end

   function love.mousepressed(x, y, button, istouch, presses)
      if not istouch then
         pointerPressed(x, y, 'mouse')
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
      end
   end

   function love.touchreleased(id, x, y, dx, dy, pressure)
      pointerReleased(x, y, id)
   end

   function love.resize(w, h)
      local bx, by = body.transforms._g:transformPoint(0, 0)
      camera.setCameraViewport(cam, w, h)
      camera.centerCameraOnPosition(bx, by, w * 1, h * 4)
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

function scene.update(dt)
   prof.push("frame")

   if introSound:isPlaying() then
      local volume = introSound:getVolume()
      introSound:setVolume(volume * .90)
      if (volume < 0) then
         introSound:stop()
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



   scrollPosition = updateTheScrolling(dt, scrollListIsThrown, scrollPosition)
   settingsScrollPosition = updateTheScrolling(dt, settingsScrollAreaIsThrown, settingsScrollPosition)



   myWorld:emit("update", dt) -- this one is leaking the most actually
   prof.pop("frame")
end

function scene.draw()
   --   prof.enabled(false)
   prof.push("frame")


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
         love.graphics.draw(tiles, 400, 0, .1, .5, .5)
         love.graphics.setColor(1, 0, 0, 0.05)
         love.graphics.draw(tiles2, 1000, 300, math.pi / 2, .5, .5)

         for i = 1, #headz do
            love.graphics.setColor(0, 0, 0, 0.05)
            love.graphics.draw(headz[i].img, headz[i].x * w, headz[i].y * h, headz[i].r)
         end

         love.graphics.setColor(1, 1, 1)
      end

      love.graphics.setColor(0, 0, 0)

      scrollList(true)
      -- love.graphics.setColor(1, 1, 1)
      -- love.graphics.draw(tab1)
      --love.graphics.draw(tab2, 100, 100)
      --love.graphics.draw(tab3, 100, 500)
      partSettingsPanel(0, 0)

      prof.push("cam-render")
      cam:push()
      render.renderThings(root, true)

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
         --   print(inspect(stats))
         love.graphics.setColor(1, 1, 1, 1)
         love.graphics.print(inspect(stats), 10, 30)
         love.graphics.setColor(0, 0, 0, 1)
         love.graphics.print(inspect(stats), 11, 31)

         love.graphics.print("FPS: " .. tostring(love.timer.getFPS()), 10, 10)
      end
   end
   prof.pop("frame")
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

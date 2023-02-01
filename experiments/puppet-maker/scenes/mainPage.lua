-- https://medium.com/@chrisgaul/https-medium-com-chrisgaul-is-this-language-without-letters-the-future-of-global-communication-15fc54909c12
-- http://bamanda.com/locos/locos_subsite/locos_gallery.html
-- https://ai.facebook.com/blog/using-ai-to-bring-childrens-drawings-to-life/



local scene = {}

local vivid   = require 'vendor.vivid'
local Timer   = require 'vendor.timer'
local inspect = require 'vendor.inspect'
local Signal  = require 'vendor.signal'

local text       = require 'lib.text'
local render     = require 'lib.render'
local mesh       = require 'lib.mesh'
local parentize  = require 'lib.parentize'
local geom       = require 'lib.geom'
local node       = require 'lib.node'
local parse      = require 'lib.parse-file'
local bbox       = require 'lib.bbox'
local hit        = require 'lib.hit'
local transforms = require 'lib.transform'
local numbers    = require 'lib.numbers'
local ui         = require 'lib.ui'
local canvas     = require 'lib.canvas'

local camera     = require 'lib.camera'
local cam        = require('lib.cameraBase').getInstance()
local creamColor = { 238 / 255, 226 / 255, 188 / 255, 1 }

local Components = {}
local Systems    = {}

myWorld = Concord.world()

require 'src.generatePuppet'

Concord.utils.loadNamespace("src/components", Components)
Concord.utils.loadNamespace("src/systems", Systems)
myWorld:addSystems(Systems.BipedSystem, Systems.PotatoHeadSystem)


local pointerInteractees = {}


local function sign(x)
   return x > 0 and 1 or x < 0 and -1 or 0
end

function stripPath(root, path)

   if root and root.texture and #root.texture.url > 0 then
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
   local index = node.getIndex(elem)
   if index >= 0 then table.remove(elem._parent.children, index) end
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
      settingsScrollPosition = settingsScrollPosition + dy / settingsScrollArea[5]
      --print(settingsScrollPosition)
      --settingsScrollPosition = math.max(0, settingsScrollPosition)
      --print(settingsScrollPosition)
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
               --else
               --   print(inspect(item))
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
      --scrollerIsPressed = { time = love.timer.getTime(), pointerX = x, pointerY = y }
      gesture.add('scroll-list', id, love.timer.getTime(), x, y)
   end
   if (settingsScrollArea) then
      if (hit.pointInRect(x, y,
         settingsScrollArea[1], settingsScrollArea[2], settingsScrollArea[3], settingsScrollArea[4])
          ) then
         settingsScrollAreaIsDragging = true
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
   --print(inspect(eyes))
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

   textures = {
      1,
      love.graphics.newImage('assets/layered/texture-type2t.png'),
      love.graphics.newImage('assets/layered/texture-type1.png'),
      love.graphics.newImage('assets/layered/texture-type3.png'),
      love.graphics.newImage('assets/layered/texture-type4.png'),
      love.graphics.newImage('assets/layered/texture-type5.png'),
      love.graphics.newImage('assets/layered/texture-type6.png'),
      love.graphics.newImage('assets/layered/texture-type7.png'),
      nil
   }

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


   scrollPosition = 0
   scrollItemsOnScreen = 4
   scrollListXPosition = 20
   settingsScrollAreaIsDragging = false
   settingsScrollArea = nil
   settingsScrollPosition = 0

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


   scrollTickSample = love.audio.newSource(love.sound.newSoundData('assets/sounds/BD-perc.wav'), 'static')
   scrollItemClickSample = love.audio.newSource(love.sound.newSoundData('assets/sounds/CasioMT70-Bassdrum.wav'), 'static')

   feetImgUrls = { 'assets/parts/feet1.png', 'assets/parts/feet2.png', 'assets/parts/feet3.png' }
   feetUrls = { 'assets/feet1.polygons.txt', 'assets/feet2.polygons.txt', 'assets/feet3.polygons.txt' }
   feetParts = {}
   for i = 1, #feetUrls do
      feetParts[i] = parse.parseFile(feetUrls[i])[1]
      stripPath(feetParts[i], '/experiments/puppet%-maker/')
   end

   handParts = feetParts

   legUrls = { 'assets/parts/leg1.png', 'assets/parts/leg2.png', 'assets/parts/leg3.png', 'assets/parts/leg4.png',
      'assets/parts/leg5.png' }


   bodyImgUrls = {}
   bodyParts = {}
   -- bodies use the same shapes as the heads
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
   headImgUrls = bodyImgUrls
   headParts = bodyParts

   local faceparts = parse.parseFile('assets/faceparts.polygons.txt')



   eyeImgUrls, eyeParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'eyes')
   noseImgUrls, noseParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'noses')
   browImgUrls, browParts = loadGroupFromFile('assets/faceparts.polygons.txt', 'eyebrows')


   values = {
      potatoHead = true,

      eyes = {
         shape   = 1,
         bgPal   = 4,
         fgPal   = 1,
         bgTex   = 1,
         fgTex   = 2,
         linePal = 1

      },
      eyeWidthMultiplier = 1,
      eyeHeightMultiplier = 1,
      eyeRotation = 0,
      brows = {
         shape   = 1,
         bgPal   = 4,
         fgPal   = 1,
         bgTex   = 1,
         fgTex   = 2,
         linePal = 1

      },
      nose = {
         shape   = 1,
         bgPal   = 4,
         fgPal   = 1,
         bgTex   = 1,
         fgTex   = 2,
         linePal = 1

      },
      noseWidthMultiplier = 1,
      noseHeightMultiplier = 1,

      legs = {
         shape   = 1,
         bgPal   = 4,
         fgPal   = 1,
         bgTex   = 1,
         fgTex   = 2,
         linePal = 1
      },
      legLength = 700,
      legWidthMultiplier = 1,
      leg1flop = -1,
      leg2flop = 1,

      arms = {
         shape   = 1,
         bgPal   = 4,
         fgPal   = 1,
         bgTex   = 1,
         fgTex   = 2,
         linePal = 1
      },
      armLength = 700,
      armWidthMultiplier = 1,
      arm1flop = -1,
      arm2flop = 1,
      hands = {
         shape   = 1,
         bgPal   = 4,
         fgPal   = 1,
         bgTex   = 1,
         fgTex   = 2,
         linePal = 1
      },
      body = {
         shape   = 9,
         bgPal   = 4,
         fgPal   = 1,
         bgTex   = 1,
         fgTex   = 2,
         linePal = 1,
         flipy   = -1
      },
      bodyWidthMultiplier = 1,
      bodyHeightMultiplier = 1,
      head = {
         shape   = 1,
         bgPal   = 4,
         fgPal   = 1,
         bgTex   = 1,
         fgTex   = 2,
         linePal = 1,
         flipx   = 1,
         flipy   = -1
      },
      headWidthMultiplier = 1,
      headHeightMultiplier = 1,

      neck = { -- todo
         shape   = 1,
         bgPal   = 4,
         fgPal   = 1,
         bgTex   = 1,
         fgTex   = 2,
         linePal = 1
      },
      neckLength = 700,
      neckWidthMultiplier = 1,
      feet = {
         shape   = 1,
         bgPal   = 4,
         fgPal   = 1,
         bgTex   = 1,
         fgTex   = 2,
         linePal = 1
      },
   }

   head = copy3(headParts[values.head.shape])
   neck = createNeckRubberhose(values)
   body = copy3(bodyParts[values.body.shape])

   arm1 = createArmRubberhose(1, values)
   arm2 = createArmRubberhose(2, values)
   hand1 = copy3(feetParts[values.hands.shape])
   hand2 = copy3(feetParts[values.hands.shape])

   leg1 = createLegRubberhose(1, values)
   leg2 = createLegRubberhose(2, values)
   feet1 = copy3(feetParts[values.feet.shape])
   feet2 = copy3(feetParts[values.feet.shape])


   eye1 = copy3(eyeParts[values.eyes.shape])
   eye2 = copy3(eyeParts[values.eyes.shape])
   brow1 = copy3(browParts[values.brows.shape])
   brow2 = copy3(browParts[values.brows.shape])


   nose = copy3(noseParts[values.nose.shape])

   guy = {
      folder = true,
      name = 'guy',
      transforms = { l = { 0, 0, 0, 1, 1, 0, 0, 0, 0 } },
      children = {}
   }

   biped = Concord.entity()
   biped:give('biped',
      { guy = guy, body = body, neck = neck, head = head,
         leg1 = leg1, leg2 = leg2, feet1 = feet1, feet2 = feet2,
         arm1 = arm1, hand1 = hand1, arm2 = arm2, hand2 = hand2,
         values = values
      })

   --biped:give('biped', bipedArguments(biped, values))
   guy.children = guyChildren(biped)

   redoFeet(biped, values)
   redoHands(biped, values)
   redoBody(biped, values)
   redoHead(biped, values)


   --print(#head.children)

   potato = Concord.entity()
   potato:give('potato', { head = values.potatoHead and body or head,
      eye1 = eye1, eye2 = eye2, nose = nose, brow1 = brow1, brow2 = brow2,
      values = values })

   local faceContainer = values.potatoHead and body or head

   table.insert(faceContainer.children, eye1)
   table.insert(faceContainer.children, eye2)
   table.insert(faceContainer.children, brow1)
   table.insert(faceContainer.children, brow2)
   table.insert(faceContainer.children, nose)


   root.children = { guy }

   redoEyes(potato, values)
   redoBrows(potato, values)
   redoNose(potato, values)
   changeNose(potato, values)
   if false then
      cameraPoints = {}
      local W, H = love.graphics.getDimensions()
      for i = 1, 10 do
         table.insert(
            cameraPoints,
            {
               x = love.math.random(-W * 2, W * 2),
               y = love.math.random(-H * 2, H * 2),
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

   local bx, by = body.transforms._g:transformPoint(0, 0)
   local w, h = love.graphics.getDimensions()

   camera.setCameraViewport(cam, w, h)
   camera.centerCameraOnPosition(bx, by, w * 1, h * 4)
   cam:update(w, h)

end

function attachCallbacks()
   Signal.register('click-scroll-list-item', function(x, y)
      scrollList(false, x, y)
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
         local bbHead = bbox.getBBoxRecursive(head)
         local bbBody = bbox.getBBoxRecursive(body)
         local bbFeet1 = bbox.getBBoxRecursive(feet1)
         local bbFeet2 = bbox.getBBoxRecursive(feet2)

         local points = {
            { head.transforms.l[1], head.transforms.l[2] },
            { feet2.transforms.l[1], feet2.transforms.l[2] },
            { feet1.transforms.l[1], feet1.transforms.l[2] },
         }

         local tlx, tly, brx, bry = bbox.getPointsBBox(points)
         local x2, y2, w, h       = bbox.getMiddleAndDimsOfBBox(tlx, tly, brx, bry)

         camera.centerCameraOnPosition(x2, y2, w * 1.61, h * 1.61)
         print('focus camera on third other shape', x, y)
      end
      if key == 'b' then

         -- local removeFrom = values.potatoHead and body or head


         values.potatoHead = not values.potatoHead
         attachAllFaceParts()
      end
   end

   function attachAllFaceParts()
      removeChild(eye1)
      removeChild(eye2)
      removeChild(nose)
      removeChild(brow1)
      removeChild(brow2)
      local addTo = values.potatoHead and body or head



      table.insert(addTo.children, eye1)
      table.insert(addTo.children, eye2)
      table.insert(addTo.children, brow1)
      table.insert(addTo.children, brow2)
      table.insert(addTo.children, nose)


      myWorld:emit('bipedUsePotatoHead', biped, values.potatoHead)
      myWorld:emit('potatoInit', potato)
      changeNose(potato, values)
      changeEyes(potato, values)
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
      if false then
         local newScale = cam.scale * (1 + dy / 10)
         if (newScale > 0.01 and newScale < 50) then
            cam:scaleToPoint(1 + dy / 10)
         end
      end
   end
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

   if scrollListIsThrown then
      scrollListIsThrown.velocity = scrollListIsThrown.velocity * .90

      local oldScrollPos = scrollPosition
      scrollPosition = scrollPosition + ((scrollListIsThrown.velocity * scrollListIsThrown.direction) * .1 * dt)
      local newScrollPos = scrollPosition
      if (math.floor(oldScrollPos) ~= math.floor(newScrollPos)) then
         -- play sound
         playSound(scrollTickSample)

      end
      if (scrollListIsThrown.velocity < 0.01) then
         scrollListIsThrown.velocity = 0
         scrollListIsThrown = nil
      end
   end
   myWorld:emit("update", dt) -- this one is leaking the most actually
   prof.pop("frame")
end

function drawCirclesAroundCenterCircle(cx, cy, label, buttonRadius, r, smallButtonRadius)
   love.graphics.circle('line', cx, cy, buttonRadius)
   love.graphics.print(label, cx, cy)

   local other = { 'hair', 'headshape', 'eyes', 'ears', 'nose', 'mouth', 'chin' }
   local angleStep = (180 / (#other - 1))
   local angle = -90
   for i = 1, #other do

      local px = cx + r * math.cos(angle * math.pi / 180)
      local py = cy + r * math.sin(angle * math.pi / 180)
      angle = angle + angleStep
      love.graphics.circle('line', px, py, smallButtonRadius)
   end
end

function createFittingScale(img, desired_w, desired_h)
   local w, h = img:getDimensions()
   local sx, sy = desired_w / w, desired_h / h
   --   print(sx, sy)
   return sx, sy
end

function getScaleAndOffsetsForImage(img, desiredW, desiredH)
   local sx, sy = createFittingScale(img, desiredW, desiredH)
   local scale = math.min(sx, sy)
   local xOffset = 0
   local yOffset = 0
   if scale == sx then
      xOffset = -desiredW / 2 -- half the height
      local something = sx * img:getHeight()
      local something2 = sy * img:getHeight()
      yOffset = -desiredH / 2 - (something - something2) / 2
   elseif scale == sy then
      --print('y')
      yOffset = -desiredH / 2 -- half the height
      local something = sx * img:getWidth()
      local something2 = sy * img:getWidth()
      xOffset = -desiredW / 2 + (something - something2) / 2
   end
   return scale, xOffset, yOffset
end

--local res = { clicked = false }

function bigButtonWithSmallAroundIt(x, y, textureOrColors)
   prof.push('big-bitton-small-around')
   local biggestRadius = 70
   local bigRadius = 40
   local radius = 20
   local diam = radius * 2
   local rad = -math.pi / 2
   local number = 4
   local step = (math.pi / 1.5) / (number - 1)

   love.graphics.setColor(0, 0, 0)
   love.graphics.circle("line", x, y, bigRadius)

   local first, second, third, fourth, fifth = nil, nil, nil, nil, nil

   if (type(textureOrColors[1]) == "table") then
      love.graphics.setColor(textureOrColors[1])
   else

      local img = mesh.getImage(textureOrColors[1])
      local scale, xOffset, yOffset = getScaleAndOffsetsForImage(img, diam * 2, diam * 2)

      love.graphics.draw(img, x + xOffset, y + yOffset, 0, scale, scale)

   end
   first = ui.getUICircle(x, y, bigRadius)

   for i = 2, #textureOrColors do
      local new_x = x + math.cos(rad) * biggestRadius
      local new_y = y + math.sin(rad) * biggestRadius
      love.graphics.setColor(0, 0, 0)
      love.graphics.circle("line", new_x, new_y, radius)

      if (type(textureOrColors[i]) == "table") then
         love.graphics.setColor(textureOrColors[i])
         love.graphics.circle("fill", new_x, new_y, radius - 2)
      else
         scale, xOffset, yOffset = getScaleAndOffsetsForImage(blup2, 40, 40)
         prof.push('render-masked-texture')
         canvas.renderMaskedTexture(blup2, textureOrColors[i], new_x + xOffset, new_y + yOffset, scale, scale)
         prof.pop('render-masked-texture')
      end

      local b = ui.getUICircle(new_x, new_y, 30)
      if (i == 2) then second = b end
      if (i == 3) then third = b end
      if (i == 4) then fourth = b end
      if (i == 5) then fifth = b end
      rad = rad + step
   end
   prof.pop('big-bitton-small-around')
   return first, second, third, fourth, fifth

end

function buttonHelper(button, bodyPart, param, maxAmount, func, firstParam)
   if button then
      values[bodyPart][param] = values[bodyPart][param] + 1
      if values[bodyPart][param] > maxAmount then
         values[bodyPart][param] = 1
      end
      func(firstParam, values)
   end
end

function tweenCategoriesAndSettings()
   --function()
   --Timer.tween(1, fluxObject, { scrollX = -1 }, 'out-elastic')
   --end
end

-- this is the panel that contains all ui for changing a certain body part or general change
-- for each category we have a optionally unique panel
function partSettingsPanel()
   local w, h = love.graphics.getDimensions()

   local margin = (h / 16)
   local width = (w / 3)
   local height = (h - margin * 2)
   local startX = w - width - margin
   local startY = margin

   -- main panel
   love.graphics.setColor(0, 0, 0)
   love.graphics.rectangle('line', startX, startY, width, height)

   -- top tabs (part, bg, fg, line)
   local tabs = { 'part', 'bg', 'fg', 'pattern', 'line' }
   local tabWidth = (width / #tabs)
   local tabHeight = math.max((tabWidth / 1.5), 32)
   local marginBetweenTabs = tabWidth / 16
   for i = 1, #tabs do
      love.graphics.rectangle('line', startX + (i - 1) * tabWidth, startY, tabWidth - marginBetweenTabs, tabHeight)
      love.graphics.print(tabs[i], startX + (i - 1) * tabWidth, startY)
   end

   -- top header for custom sliders etc.
   local minimumHeight = 32
   local currentY = startY + tabHeight
   love.graphics.rectangle('line', startX, currentY, width, minimumHeight)
   love.graphics.print('ruimte voor sliders', startX + 6, currentY + 6)

   -- now the scrolling part.
   -- this has optional scrolling, optional round scrolling or bounds, parameter amount of columns


   local columns = 2
   local rows = 6

   local cellMargin = width / 48

   local useWidth = width - (2 * cellMargin) - (columns - 1) * cellMargin
   local cellWidth = (useWidth / columns)
   local cellHeight = cellWidth
   local currentX = startX + cellMargin
   currentY = currentY + minimumHeight + cellMargin

   -- todo weird use of a 'global'
   -- the 5th is the cellsize/rowheight
   settingsScrollArea = { startX, currentY - cellMargin, width, height - minimumHeight - tabHeight,
      (cellHeight + cellMargin) }
   love.graphics.setScissor(settingsScrollArea[1], settingsScrollArea[2], settingsScrollArea[3], settingsScrollArea[4])

   local rowsInPanel = math.ceil((height - minimumHeight - tabHeight) / cellHeight)


   local endlesssScroll = true -- false


   local offset = settingsScrollPosition % 1

   for j = -1, rowsInPanel - 1 do
      for i = 1, columns do
         local newScroll = j + offset
         local yPosition = currentY + (newScroll * (cellHeight + cellMargin)) --(cellHeight + cellMargin) * (j - 1)
         local index = math.ceil(-settingsScrollPosition) + j
         love.graphics.rectangle('line',
            currentX + (i - 1) * (cellWidth + cellMargin),
            yPosition,
            cellWidth, cellHeight)
      end
   end


   love.graphics.setScissor()

   if false then
      local dotWidth = useWidth / 5
      local dotHeight = (height - minimumHeight - tabHeight) / 8
      for i = 1, #palettes do

         local index = (i % #dots) + 1
         local dot = dots[index]
         local j = i - 1
         local w, h = dot:getDimensions()
         local sx = dotWidth / w
         local sy = dotWidth / h

         love.graphics.setColor(0, 0, 0, .1)
         love.graphics.draw(dot, -2 + currentX + (j % 5) * dotWidth, -2 + currentY + math.floor(j / 5) * dotWidth, 0,
            sx * 1.1, sy * 1.1)


         love.graphics.setColor(palettes[i])
         love.graphics.draw(dot, currentX + (j % 5) * dotWidth, currentY + math.floor(j / 5) * dotWidth, 0, sx, sy)
      end
   end

end

-- scroll list is the main thing that has all categories
function scrollList(draw, clickX, clickY)

   local w, h = love.graphics.getDimensions()
   local margin = 20

   local marginHeight = 2
   local size = (h / scrollItemsOnScreen) - marginHeight * 2

   local elements = { 'voeten ', 'benen', 'romp', 'armen', 'handen', 'nek', 'hoofd', 'neus', 'ogen', 'oren',
      'hoofdhaar' }

   local offset = scrollPosition % 1

   for i = -1, (scrollItemsOnScreen - 1) do

      local newScroll = i + offset
      local yPosition = marginHeight + (newScroll * (h / scrollItemsOnScreen))

      local index = math.ceil(-scrollPosition) + i
      index = (index % #elements) + 1
      if index < 1 then index = index + #elements end
      if index > #elements then index = 1 end

      local whiterectIndex = math.ceil(-scrollPosition) + i
      whiterectIndex = (whiterectIndex % #whiterects) + 1
      local wrw, wrh = whiterects[whiterectIndex]:getDimensions()
      local scaleX = size / wrw
      local scaleY = size / wrh

      if draw then
         love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], .8)

         love.graphics.setColor(.1, .1, .1, .2)
         love.graphics.draw(whiterects[whiterectIndex], scrollListXPosition + 4, yPosition + 4, 0, scaleX, scaleY)

         love.graphics.setColor(255 / 255, 240 / 255, 200 / 255)
         love.graphics.draw(whiterects[whiterectIndex], scrollListXPosition, yPosition, 0, scaleX, scaleY)

         love.graphics.setColor(0, 0, 0)
         love.graphics.print(elements[index], 20, yPosition)
      else
         if (hit.pointInRect(clickX, clickY, 20, yPosition, size, size)) then
            playSound(scrollItemClickSample)
         end
      end
   end
end

function bigButtonHelper(x, y, param, imgArray, changeFunc, redoFunc, firstParam)
   shapeButton, BGButton, FGTexButton, FGButton, LinePalButton = bigButtonWithSmallAroundIt(
      x, y, {
      imgArray[values[param].shape],
      palettes[values[param].bgPal],
      textures[values[param].fgTex],
      palettes[values[param].fgPal],
      palettes[values[param].linePal]
   }
   )

   -- todo maybe parametrize palettes and textures?
   buttonHelper(shapeButton, param, 'shape', #imgArray, changeFunc, firstParam)
   buttonHelper(BGButton, param, 'bgPal', #palettes, redoFunc, firstParam)
   buttonHelper(FGTexButton, param, 'fgTex', #textures, redoFunc, firstParam)
   buttonHelper(FGButton, param, 'fgPal', #palettes, redoFunc, firstParam)
   buttonHelper(LinePalButton, param, 'linePal', #palettes, redoFunc, firstParam)
end

function scene.draw()
   --   prof.enabled(false)
   prof.push("frame")
   if true then
      local w, h = love.graphics.getDimensions()
      if true then
         ui.handleMouseClickStart()
         love.graphics.clear(bgColor)
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

      --scrollList(true)
      --partSettingsPanel()

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

      prof.push("render-ui")
      if true then

         bigButtonHelper(50, 100, 'head', headImgUrls, changeHead, redoHead, biped)
         bigButtonHelper(225, 100, 'eyes', eyeImgUrls, changeEyes, redoEyes, potato)

         bigButtonHelper(50, 250, 'neck', legUrls, changeNeck, redoNeck, biped)
         bigButtonHelper(225, 250, 'nose', noseImgUrls, changeNose, redoNose, potato)

         bigButtonHelper(50, 400, 'body', bodyImgUrls, changeBody, redoBody, biped)
         bigButtonHelper(225, 400, 'arms', legUrls, changeArms, redoArms, biped)
         bigButtonHelper(225, 550, 'hands', feetImgUrls, changeHands, redoHands, biped)
         bigButtonHelper(50, 550, 'legs', legUrls, changeLegs, redoLegs, biped)
         bigButtonHelper(50, 700, 'feet', feetImgUrls, changeFeet, redoFeet, biped)

         if true then
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle('fill', 150, 550, 10)
            local b = ui.getUICircle(150, 550, 10)
            if b then
               values.legs.flipy = values.legs.flipy == -1 and 1 or -1
               redoLegs(biped, values)

            end
         end

         if true then
            local v = h_slider("eye-width", 325 - 25, 100 - 75, 50, values.eyeWidthMultiplier, .1, 5)
            if v.value then
               values.eyeWidthMultiplier = v.value
               eye1.transforms.l[4] = v.value
               eye2.transforms.l[4] = v.value * -1
            end
            local v = h_slider("eye-height", 325 - 25, 100 - 50, 50, values.eyeHeightMultiplier, .1, 5)
            if v.value then
               values.eyeHeightMultiplier = v.value
               eye1.transforms.l[5] = v.value
               eye2.transforms.l[5] = v.value
            end
            local v = h_slider("eye-rotation", 325 - 25, 100 - 25, 50, values.eyeRotation, 0, 2 * math.pi)
            if v.value then
               values.eyeRotation = v.value
               eye1.transforms.l[3] = v.value
               eye2.transforms.l[3] = -v.value
            end
         end

         if true then
            local v = h_slider("nose-width", 325 - 25, 250 - 75, 50, values.noseWidthMultiplier, .1, 5)
            if v.value then
               values.noseWidthMultiplier = v.value
               nose.transforms.l[4] = v.value
            end
            local v = h_slider("nose-height", 325 - 25, 250 - 50, 50, values.noseHeightMultiplier, .1, 5)
            if v.value then
               values.noseWidthMultiplier = v.value
               nose.transforms.l[5] = v.value

            end

         end

         if true then
            local v = h_slider("head-width", 150 - 25, 100 - 75, 50, values.headWidthMultiplier, .1, 5)
            if v.value then
               values.headWidthMultiplier = v.value
               head.transforms.l[4] = v.value
               head.dirty = true
               transforms.setTransforms(head)
               myWorld:emit("bipedAttachHead", biped)
            end
            v = h_slider("head-height", 150 - 25, 100 - 50, 50, values.headHeightMultiplier, .1, 5)
            if v.value then
               values.headHeightMultiplier = v.value
               head.transforms.l[5] = v.value
               head.dirty = true
               transforms.setTransforms(head)
               myWorld:emit("bipedAttachHead", biped)
            end
            love.graphics.circle('fill', 150, 100, 10)
            local b = ui.getUICircle(150, 100, 10)
            if b then
               values.head.flipy = values.head.flipy == -1 and 1 or -1
               redoHead(biped, values)
               myWorld:emit('potatoInit', potato)
            end
            love.graphics.circle('fill', 170, 100, 10)
            local b = ui.getUICircle(170, 100, 10)
            if b then
               values.head.flipx = values.head.flipx == -1 and 1 or -1
               redoHead(biped, values)
               myWorld:emit('potatoInit', potato)
            end
         end

         if true then
            local v = h_slider("body-width", 150 - 25, 400 - 75, 50, values.bodyWidthMultiplier, .1, 5)
            if v.value then
               values.bodyWidthMultiplier = v.value
               body.transforms.l[4] = v.value
               body.dirty = true
               transforms.setTransforms(body)
               myWorld:emit('potatoInit', potato)
               myWorld:emit("bipedAttachHead", biped)
               myWorld:emit("bipedAttachLegs", biped)
               myWorld:emit("bipedAttachArms", biped)
               myWorld:emit("bipedAttachHands", biped)

            end
            v = h_slider("body-height", 150 - 25, 400 - 50, 50, values.bodyHeightMultiplier, .1, 5)
            if v.value then
               values.bodyHeightMultiplier = v.value
               body.transforms.l[5] = v.value
               body.dirty = true
               transforms.setTransforms(body)
               myWorld:emit('potatoInit', potato)
               myWorld:emit("bipedAttachHead", biped)
               myWorld:emit("bipedAttachLegs", biped)
               myWorld:emit("bipedAttachArms", biped)
               myWorld:emit("bipedAttachHands", biped)
            end
            love.graphics.circle('fill', 150, 400, 10)
            local b = ui.getUICircle(150, 400, 10)
            if b then
               values.body.flipy = values.body.flipy == -1 and 1 or -1
               redoBody(biped, values)
               myWorld:emit('potatoInit', potato)
               myWorld:emit("bipedAttachHead", biped)
               myWorld:emit("bipedAttachLegs", biped)
               myWorld:emit("bipedAttachArms", biped)
               myWorld:emit("bipedAttachHands", biped)
            end
            love.graphics.circle('fill', 170, 400, 10)
            local b = ui.getUICircle(170, 400, 10)
            if b then
               values.body.flipx = values.body.flipx == -1 and 1 or -1
               redoBody(biped, values)
               myWorld:emit('potatoInit', potato)
               myWorld:emit("bipedAttachHead", biped)
               myWorld:emit("bipedAttachLegs", biped)
               myWorld:emit("bipedAttachArms", biped)
               myWorld:emit("bipedAttachHands", biped)
            end
         end

         if true then
            v = h_slider("leg-length", 150 - 25, 550 - 75, 50, values.legLength, 200, 2000)
            if v.value then
               values.legLength = v.value
               redoLegs(biped, values)
            end
            v = h_slider("leg-width-multiplier", 150 - 25, 550 - 50, 50, values.legWidthMultiplier, 0.1, 2)
            if v.value then
               values.legWidthMultiplier = v.value
               redoLegs(biped, values)
            end
         end
      end
      prof.pop("render-ui")

      if true then -- this is leaking too

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

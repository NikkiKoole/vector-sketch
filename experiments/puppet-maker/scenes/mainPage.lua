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

myWorld          = Concord.world()

require 'src.generatePuppet'

Concord.utils.loadNamespace("src/components", Components)
Concord.utils.loadNamespace("src/systems", Systems)
myWorld:addSystems(Systems.BasicSystem, Systems.BipedSystem)


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
            local b = bbox.getBBoxRecursive(item)
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


   --uiImg = love.graphics.newImage('assets/ui2.png')
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

   eyeUrls = { 'assets/eye1.polygons.txt' }
   eyeParts = {}
   for i = 1, #eyeUrls do
      eyeParts[i] = parse.parseFile(eyeUrls[i])[1]
      stripPath(eyeParts[i], '/experiments/puppet%-maker/')
   end

   legUrls = { 'assets/parts/leg1.png', 'assets/parts/leg2.png', 'assets/parts/leg3.png', 'assets/parts/leg4.png',
      'assets/parts/leg5.png' }


   bodyImgUrls = {}
   bodyParts = {}
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

   headImgUrls = { 'assets/parts/shapes1.png', 'assets/parts/head3.png', 'assets/parts/head4.png' }
   headUrls = { 'assets/head5.polygons.txt', 'assets/head3.polygons.txt', 'assets/head4.polygons.txt' }
   headParts = {}

   for i = 1, #headUrls do
      headParts[i] = parse.parseFile(headUrls[i])[1]
      stripPath(headParts[i], '/experiments/puppet%-maker/')
   end

   values = {
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
      leg1flop = 1,
      leg2flop = 1,

      body = {
         shape   = 1,
         bgPal   = 4,
         fgPal   = 1,
         bgTex   = 1,
         fgTex   = 2,
         linePal = 1
      },
      bodyWidthMultiplier = 1,
      bodyHeightMultiplier = 1,
      head = {
         shape   = 1,
         bgPal   = 4,
         fgPal   = 1,
         bgTex   = 1,
         fgTex   = 2,
         linePal = 1
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
      neckLength = 200,
      neckWidthMultiplier = 1,
      feet = {
         shape   = 1,
         bgPal   = 4,
         fgPal   = 1,
         bgTex   = 1,
         fgTex   = 2,
         linePal = 1
      },
        eyeTypeIndex = 1,

   }

   body = copy3(bodyParts[values.body.shape])

   redoBody()



   -- DRAW SOME EYES!

   head = copy3(headParts[values.head.shape])
   redoHead()

   neck = createNeckRubberhose()
   
   --stripPath(head, '/experiments/puppet%-maker/')



   --eye1 = copy3(eyeParts[values.eyeTypeIndex])
   --eye2 = copy3(eyeParts[values.eyeTypeIndex])

   --addChild(head, eye1)
   --addChild(head, eye2)

   leg1 = createLegRubberhose(1)
   leg2 = createLegRubberhose(2)

   feet1 = copy3(feetParts[values.feet.shape])
   feet2 = copy3(feetParts[values.feet.shape])
   redoFeet()

   guy = {
      folder = true,
      name = 'guy',
      transforms = { l = { 0, 0, 0, 1, 1, 0, 0, 0, 0 } },
      children = {}
   }
   guy.children = { body, leg1, leg2, feet1, feet2, neck, head }

   root.children = { guy }

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
   --render.justDoTransforms(root, true)
   --mesh.recursivelyMakeTextures(root)
   render.renderThings(root)


   biped = Concord.entity()
   biped:give('biped', { guy = guy, body = body, leg1 = leg1, leg2 = leg2, feet1 = feet1, feet2 = feet2, neck = neck, head = head })


   myWorld:addEntity(biped)
   myWorld:emit("bipedInit", biped)
   render.renderThings(root, true)
   attachCallbacks()

   -- dont understand how imma gonna center on head, body and legs yet
   local bx, by = head.transforms._g:transformPoint(0, 0)
   --local gx, gy = guy.transforms._g:transformPoint(bx, by)
   local w, h = love.graphics.getDimensions()
   --local lw, lh = lineart:getDimensions()

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
         print('focus camera on second other shape', x, y)
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
         --local bb                 = bbox.transformFromParent(guy, { tlx, tly, brx, bry })
         --local x2, y2, w, h       = bbox.getMiddleAndDimsOfBBox(bb[1], bb[2], bb[3], bb[4])
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
         pointerPressed(x, y, 'mouse', button)
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

--

function scene.update(dt)
   prof.push("frame")
   --require("vendor.lurker").update()
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
   local bigRadius = 60
   local radius = 50
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
      local scale, xOffset, yOffset = getScaleAndOffsetsForImage(img, diam, diam)
      love.graphics.draw(img, x + xOffset, y + yOffset, 0, scale, scale)

   end
   first = ui.getUICircle(x, y, bigRadius)

   for i = 2, #textureOrColors do
      local new_x = x + math.cos(rad) * 100
      local new_y = y + math.sin(rad) * 100
      love.graphics.setColor(0, 0, 0)
      love.graphics.circle("line", new_x, new_y, 30)

      if (type(textureOrColors[i]) == "table") then
         love.graphics.setColor(textureOrColors[i])
         love.graphics.circle("fill", new_x, new_y, 28)
      else
         scale, xOffset, yOffset = getScaleAndOffsetsForImage(blup2, 60, 60)
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

function buttonHelper(button, bodyPart, param, maxAmount, func)
   if button then
      values[bodyPart][param] = values[bodyPart][param] + 1
      if values[bodyPart][param] > maxAmount then
         values[bodyPart][param] = 1
      end
      func()
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
      prof.pop("cam-render")

      prof.push("render-ui")
      if true then -- this block leaks memory still...

         -- body

         local bodyShapeButton, bodyBGButton, bodyFGTexButton, bodyFGButton, bodyLinePalButton = bigButtonWithSmallAroundIt(
            100, 150,
            {
               bodyImgUrls[values.body.shape],
               palettes[values.body.bgPal],
               textures[values.body.fgTex],
               palettes[values.body.fgPal],
               palettes[values.body.linePal]
            }
         )
         buttonHelper(bodyShapeButton, 'body', 'shape', #bodyParts, changeBody)
         buttonHelper(bodyBGButton, 'body', 'bgPal', #palettes, redoBody)
         buttonHelper(bodyFGTexButton, 'body', 'fgTex', #textures, redoBody)
         buttonHelper(bodyFGButton, 'body', 'fgPal', #palettes, redoBody)
         buttonHelper(bodyLinePalButton, 'body', 'linePal', #palettes, redoBody)

         if true then
            local v = h_slider("body-width", 250, 150, 50, values.bodyWidthMultiplier, .1, 5)
            if v.value then
               values.bodyWidthMultiplier = v.value
               body.transforms.l[4] = v.value
               body.dirty = true
               transforms.setTransforms(body)
               myWorld:emit("bipedAttachHead", biped)
               myWorld:emit("bipedAttachLegs", biped) -- todo
            end
            v = h_slider("body-height", 250, 200, 50, values.bodyHeightMultiplier, .1, 5)
            if v.value then
               values.bodyHeightMultiplier = v.value
               body.transforms.l[5] = v.value
               body.dirty = true
               transforms.setTransforms(body)
               myWorld:emit("bipedAttachHead", biped)
               myWorld:emit("bipedAttachLegs", biped) -- todo
            end
         end


         local legShapeButton, legBGButton, legFGTexButton, legFGButton, legLinePalButton = bigButtonWithSmallAroundIt(
            100, 400,
            {
               legUrls[values.legs.shape],
               palettes[values.legs.bgPal],
               textures[values.legs.fgTex],
               palettes[values.legs.fgPal],
               palettes[values.legs.linePal]
            }
         )
         buttonHelper(legShapeButton, 'legs', 'shape', #legUrls, changeLegs)
         buttonHelper(legBGButton, 'legs', 'bgPal', #palettes, redoLegs)
         buttonHelper(legFGTexButton, 'legs', 'fgTex', #textures, redoLegs)
         buttonHelper(legFGButton, 'legs', 'fgPal', #palettes, redoLegs)
         buttonHelper(legLinePalButton, 'legs', 'linePal', #palettes, redoLegs)


         -- legs
         --  ColoredPatternLegs(100, 400)
         if true then
            v = h_slider("leg-length", 250, 400, 50, values.legLength, 200, 2000)

            if v.value then
               values.legLength = v.value
               redoLegs()
            end
            v = h_slider("leg-width-multiplier", 250, 450, 50, values.legWidthMultiplier, 0.1, 2)
            if v.value then
               values.legWidthMultiplier = v.value
               redoLegs()
            end
         end
         -- feet

         local feetShapeButton, feetBGButton, feetFGTexButton, feetFGButton, feetLinePalButton = bigButtonWithSmallAroundIt(
            100, 650,
            {
               feetImgUrls[values.feet.shape],
               palettes[values.feet.bgPal],
               textures[values.feet.fgTex],
               palettes[values.feet.fgPal],
               palettes[values.feet.linePal]
            }
         )
         buttonHelper(feetShapeButton, 'feet', 'shape', #feetUrls, changeFeet)
         buttonHelper(feetBGButton, 'feet', 'bgPal', #palettes, redoFeet)
         buttonHelper(feetFGTexButton, 'feet', 'fgTex', #textures, redoFeet)
         buttonHelper(feetFGButton, 'feet', 'fgPal', #palettes, redoFeet)
         buttonHelper(feetLinePalButton, 'feet', 'linePal', #palettes, redoFeet)


         local headShapeButton, headBGButton, headFGTexButton, headFGButton, headLinePalButton = bigButtonWithSmallAroundIt(
            350, 150,
            {
               headImgUrls[values.head.shape],
               palettes[values.head.bgPal],
               textures[values.head.fgTex],
               palettes[values.head.fgPal],
               palettes[values.head.linePal]
            }
         )
         buttonHelper(headShapeButton, 'head', 'shape', #headUrls, changeHead)
         buttonHelper(headBGButton, 'head', 'bgPal', #palettes, redoHead)
         buttonHelper(headFGTexButton, 'head', 'fgTex', #textures, redoHead)
         buttonHelper(headFGButton, 'head', 'fgPal', #palettes, redoHead)
         buttonHelper(headLinePalButton, 'head', 'linePal', #palettes, redoHead)

         if true then
            local v = h_slider("head-width", 500, 150, 50, values.headWidthMultiplier, .1, 5)
            if v.value then
               values.headWidthMultiplier = v.value
               head.transforms.l[4] = v.value
               head.dirty = true
               transforms.setTransforms(head)
               myWorld:emit("bipedAttachHead", biped)
            end
            v = h_slider("head-height", 500, 200, 50, values.headHeightMultiplier, .1, 5)
            if v.value then
               values.headHeightMultiplier = v.value
               head.transforms.l[5] = v.value
               head.dirty = true
               transforms.setTransforms(head)
               myWorld:emit("bipedAttachHead", biped)
            end
         end

         local neckShapeButton, neckBGButton, neckFGTexButton, neckFGButton, neckLinePalButton = bigButtonWithSmallAroundIt(
            350, 400,
            {
               legUrls[values.neck.shape],
               palettes[values.neck.bgPal],
               textures[values.neck.fgTex],
               palettes[values.neck.fgPal],
               palettes[values.neck.linePal]
            }
         )
         buttonHelper(neckShapeButton, 'neck', 'shape', #legUrls, changeNeck)
         buttonHelper(neckBGButton, 'neck', 'bgPal', #palettes, redoNeck)
         buttonHelper(neckFGTexButton, 'neck', 'fgTex', #textures, redoNeck)
         buttonHelper(neckFGButton, 'neck', 'fgPal', #palettes, redoNeck)
         buttonHelper(neckLinePalButton, 'neck', 'linePal', #palettes, redoNeck)



      end
      prof.pop("render-ui")

      if true then -- this is leaking too
         love.graphics.setColor(0, 0, 0, .5)
         local stats = love.graphics.getStats()
         local str = string.format("texture memory used: %.2f MB", stats.texturememory / (1024 * 1024))
         --   print(inspect(stats))
         love.graphics.print(inspect(stats), 10, 30)

         love.graphics.print("FPS: " .. tostring(love.timer.getFPS()), 10, 10)
      end
   end
   prof.pop("frame")
   --collectgarbage()
end

return scene

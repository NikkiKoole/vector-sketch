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

local camera = require 'lib.camera'
local cam    = require('lib.cameraBase').getInstance()
local creamColor = { 238 / 255, 226 / 255, 188 / 255, 1 }

local Components = {}
local Systems    = {}
local myWorld    = Concord.world()

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
      print(shortened)
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

   palettes = {
      { 0, 0, 0, 1 },
      { 0.18, 0.176, 0.18, 1 },
      { 0.447, 0.255, 0.043, 1 },
      { 0.882, 0.753, 0.133, 1 },
      { 0.929, 0.91, 0.835, 1 },
      { 0.467, 0.498, 0.176, 1 },
      { 0.137, 0.333, 0.502, 1 },
      { 0.396, 0.604, 0.698, 1 },
      { 0.475, 0.408, 0.439, 1 },
      { 0.561, 0.247, 0.443, 1 },
      { 0.89, 0.388, 0.294, 1 },
      { 0.941, 0.518, 0.122, 1 },
      -- start of volkskrant palette
      { 246 / 255, 217 / 255, 58 / 255 },
      { 41 / 255, 33 / 255, 30 / 255 },
      { 246 / 255, 113 / 255, 110 / 255 },
      { 253 / 255, 239 / 255, 205 / 255 },
      { 252 / 255, 163 / 255, 154 / 255 },
      { 98 / 255, 86 / 255, 69 / 255 },
      { 66 / 255, 115 / 255, 131 / 255 },
      { 178 / 255, 209 / 255, 159 / 255 },
      { 184 / 255, 176 / 255, 150 / 255 }

      --- llast one beore pico8

      --[[
      { 29 / 255, 43 / 255, 83 / 255 },
      { 126 / 255, 37 / 255, 83 / 255 },
      { 0 / 255, 135 / 255, 81 / 255 },
      { 171 / 255, 82 / 255, 54 / 255 },
      { 95 / 255, 87 / 255, 79 / 255 },
      { 194 / 255, 195 / 255, 199 / 255 },
      { 255 / 255, 241 / 255, 232 / 255 },
      { 255 / 255, 0 / 255, 77 / 255 },
      { 255 / 255, 163 / 255, 0 },
      { 255 / 255, 236 / 255, 39 / 255 },
      { 0 / 255, 228 / 255, 54 / 255 },
      { 41 / 255, 173 / 255, 255 / 255 },
      { 131 / 255, 118 / 255, 156 / 255 },
      { 255 / 255, 119 / 255, 168 / 255 },
      { 255 / 255, 204 / 255, 170 / 255 },
      { 41 / 255, 24 / 255, 20 / 255 },
      { 17 / 255, 29 / 255, 53 / 255 },
      { 66 / 255, 33 / 255, 54 / 255 },
      { 18 / 255, 3 / 255, 89 / 255 },
      { 116 / 255, 47 / 255, 41 / 255 },
      { 73 / 255, 51 / 255, 59 / 255 },
      { 162 / 255, 136 / 255, 121 / 255 },
      { 243 / 255, 239 / 255, 125 / 255 },
      { 190 / 255, 18 / 255, 80 / 255 },
      { 255 / 255, 108 / 255, 36 / 255 },
      { 168 / 255, 231 / 255, 46 / 255 },
      { 0 / 255, 181 / 255, 67 / 255 },
      { 6 / 255, 90 / 255, 181 / 255 },
      { 117 / 255, 70 / 255, 101 / 255 },
      { 255 / 255, 110 / 255, 89 / 255 },
      { 255 / 255, 157 / 255, 129 / 255 }
      --]]
   }


   scrollPosition = 0
   scrollItemsOnScreen = 4
   --fluxObject = {
   --   scrollX = 0
   --}
   scrollListXPosition = 20
   settingsScrollAreaIsDragging = false
   settingsScrollArea = nil
   settingsScrollPosition = 0


   uiImg = love.graphics.newImage('assets/ui2.png')
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
   

   scrollItemClickSample = love.audio.newSource(love.sound.newSoundData('assets/sounds/BD-SNARE-TOM.wav'), 'static')


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

   bodyImgUrls = { 'assets/parts/romp1.png', 'assets/parts/romp2.png', 'assets/parts/romp3.png' }
   bodyUrls = { 'assets/body1.polygons.txt', 'assets/body2.polygons.txt', 'assets/body3.polygons.txt' }
   bodyParts = {}
   for i = 1, #bodyUrls do
      bodyParts[i] = parse.parseFile(bodyUrls[i])[1]
      stripPath(bodyParts[i], '/experiments/puppet%-maker/')
   end

   headImgUrls = { 'assets/parts/head3.png', 'assets/parts/head4.png' }
   headUrls = { 'assets/head3.polygons.txt', 'assets/head4.polygons.txt' }
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
      body = {
         shape   = 3,
         bgPal   = 4,
         fgPal   = 1,
         bgTex   = 1,
         fgTex   = 2,
         linePal = 1
      },
      head = {
         shape   = 1,
         bgPal   = 4,
         fgPal   = 1,
         bgTex   = 1,
         fgTex   = 2,
         linePal = 1
      },
      feet = {
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

      bodyWidthMultiplier = 1,
      bodyHeightMultiplier = 1,
      eyeTypeIndex = 1,
   }

   body = copy3(bodyParts[values.body.shape])

   redoBody()



   -- DRAW SOME EYES!

   head = copy3(headParts[values.head.shape])
   redoHead()

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
   guy.children = { body, leg1, leg2, feet1, feet2, head }

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
   biped:give('biped', { guy = guy, body = body, leg1 = leg1, leg2 = leg2, feet1 = feet1, feet2 = feet2, head = head })


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
   --myWorld:emit("update", dt) -- this one is leaking the most actually
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

   --if true then
   --   settingsScrollPosition = math.max(0, settingsScrollPosition)

   --end

   local offset = settingsScrollPosition % 1



   -- print(rowsInPanel)
   for j = -1, rowsInPanel - 1 do
      for i = 1, columns do
         local newScroll = j + offset
         --settingsScrollPosition
         local yPosition = currentY + (newScroll * (cellHeight + cellMargin)) --(cellHeight + cellMargin) * (j - 1)
         --local yPosition = currentY + (cellHeight + cellMargin) * (j - 1)
         local index = math.ceil(-settingsScrollPosition) + j
         --if (index <= rows) then
         --print(index, rows)
         love.graphics.rectangle('line',
            currentX + (i - 1) * (cellWidth + cellMargin),
            yPosition,
            cellWidth, cellHeight)

         --end
      end
   end

   --   love.graphics.setColor(1, 0, 0, .5)


   -- love.graphics.rectangle('fill', settingsScrollArea[1], settingsScrollArea[2], settingsScrollArea[3],
   --   settingsScrollArea[4])

   love.graphics.setScissor()
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
      end

      love.graphics.setColor(0, 0, 0)

      scrollList(true)
      partSettingsPanel()

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

         if false then
            local v = h_slider("body-width", 250, 150, 50, values.bodyWidthMultiplier, .1, 3)
            if v.value then
               values.bodyWidthMultiplier = v.value
               body.transforms.l[4] = v.value
               body.dirty = true
            end
            v = h_slider("body-height", 250, 200, 50, values.bodyHeightMultiplier, .1, 3)
            if v.value then
               values.bodyHeightMultiplier = v.value
               body.transforms.l[5] = v.value
               body.dirty = true
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

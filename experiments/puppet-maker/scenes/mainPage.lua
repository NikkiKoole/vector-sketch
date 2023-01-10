-- https://medium.com/@chrisgaul/https-medium-com-chrisgaul-is-this-language-without-letters-the-future-of-global-communication-15fc54909c12
-- http://bamanda.com/locos/locos_subsite/locos_gallery.html
-- https://ai.facebook.com/blog/using-ai-to-bring-childrens-drawings-to-life/
local scene = {}

local render    = require 'lib.render'
local mesh      = require 'lib.mesh'
local parentize = require 'lib.parentize'
local geom      = require 'lib.geom'

local node = require 'lib.node'
local parse = require 'lib.parse-file'
local bbox = require 'lib.bbox'
local hit = require 'lib.hit'
local vivid = require 'vendor.vivid'
local Timer = require 'vendor.timer'
local inspect = require 'vendor.inspect'
local transforms = require 'lib.transform'
local numbers = require 'lib.numbers'
local creamColor = { 238 / 255, 226 / 255, 188 / 255, 1 }


local ui = require 'lib.ui'
local camera = require 'lib.camera'
local cam = require('lib.cameraBase').getInstance()


local Components = {}
local Systems = {}
local myWorld = Concord.world()

local canvas = require('lib.canvas')

Concord.utils.loadNamespace("src/components", Components)
Concord.utils.loadNamespace("src/systems", Systems)
myWorld:addSystems(Systems.BasicSystem, Systems.BipedSystem)


local pointerInteractees = {}

function getPNGMaskUrl(url)

   -- we want to get the mask file, same url except it ends in -mask.png
   local index = string.find(url, ".png")
   local result = nil
   if index ~= nil then
      local newString = url:sub(1, index - 1) .. "-mask.png"
      result = newString
   end
   return result

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

local function getScreenBBoxForItem(c, bbox)

   local stlx, stly = c.transforms._g:transformPoint(bbox[1], bbox[2])
   local strx, stry = c.transforms._g:transformPoint(bbox[3], bbox[2])
   local sblx, sbly = c.transforms._g:transformPoint(bbox[1], bbox[4])
   local sbrx, sbry = c.transforms._g:transformPoint(bbox[3], bbox[4])

   local tlx, tly = cam:getScreenCoordinates(stlx, stly)
   local brx, bry = cam:getScreenCoordinates(sbrx, sbry)
   local trx, try = cam:getScreenCoordinates(strx, stry)
   local blx, bly = cam:getScreenCoordinates(sblx, sbly)

   local smallestX = math.min(tlx, brx, trx, blx)
   local smallestY = math.min(tly, bry, try, bly)
   local biggestX = math.max(tlx, brx, trx, blx)
   local biggestY = math.max(tly, bry, try, bly)

   return smallestX, smallestY, biggestX, biggestY

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
      scrollPosition = scrollPosition + dy / (h / scrollItemsOnScreen)
   end

   if scrollerIsPressed and not scrollerIsDragging then
      scrollerIsDragging = true
   end

end

function pointerReleased(x, y, id)
   for i = #pointerInteractees, 1, -1 do
      if pointerInteractees[i].id == id then
         table.remove(pointerInteractees, i)
      end
   end

   local clickDistance = geom.distance(x, y, scrollerIsPressed.pointerX, scrollerIsPressed.pointerY)
   print(clickDistance)
   if (scrollerIsPressed and (not scrollerIsDragging or clickDistance < 32)) then
      local now = love.timer.getTime()
      if ((now - scrollerIsPressed.time) < .5) then
         scroller(false, x, y)
      end
   end

   scrollerIsDragging = false
   scrollerIsPressed = false

   local function poep() print('poep') end

   gesture.maybeTrigger(id, x, y, poep)
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
   if x < (h / scrollItemsOnScreen) then

      scrollerIsPressed = { time = love.timer.getTime(), pointerX = x, pointerY = y }
      gesture.add('scroll-list', id, love.timer.getTime(), x, y)
   end

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

function createRubberHoseFromImage(url, bg, fg, bgp, fgp, flop, length, widthMultiplier, optionalPoints)
   local img = mesh.getImage(url)
   local width, height = img:getDimensions()
   local magic = 4.46

   local currentNode = {}
   currentNode.type = 'rubberhose'
   currentNode.data = currentNode.data or {}
   currentNode.texture = {}
   currentNode.texture.url = url
   currentNode.texture.wrap = 'repeat'
   currentNode.texture.filter = 'linear'
   currentNode.data.length = height * magic
   currentNode.data.width = width * 2 * widthMultiplier
   currentNode.data.flop = flop
   currentNode.data.borderRadius = .5
   currentNode.data.steps = 20
   currentNode.color = { 1, 1, 1 }
   currentNode.data.scaleX = 1
   currentNode.data.scaleY = length / height
   currentNode.points = optionalPoints or { { 0, 0 }, { 0, height / 2 } }

   if (true) then

      local lineart = img
      local maskUrl = getPNGMaskUrl(url)
      local mask = mesh.getImage(maskUrl)
      if mask then
         local cnv = canvas.makeTexturedCanvas(
            lineart, mask,
            bgp, bg or palettes[values.body.bgPal],
            fgp, fg or palettes[values.body.fgPal], palettes[values.legs.linePal])


         currentNode.texture.retexture = love.graphics.newImage(cnv)
      end
   end
   return currentNode
end

function makeDynamicCanvas(imageData, mymesh)
   local w, h = imageData:getDimensions()
   local w2 = w / 2
   local h2 = h / 2

   local result = {}
   result.color = { 1, 1, 1 }
   result.name = 'generated'
   result.points = { { -w2, -h2 }, { w2, -h2 }, { w2, h2 }, { -w2, h2 } }
   result.texture = {
      filter = "linear",
      canvas = mymesh,
      wrap = "repeat",
   }

   return result
end

function createRectangle(x, y, w, h, r, g, b)
   print(x, y, w, h)
   local w2 = w / 2
   local h2 = h / 2

   local result = {}
   result.folder = true
   result.transforms = {
      l = { x, y, 0, 1, 1, 0, 0 }
   }
   result.children = { {

      name = 'rectangle',
      points = { { -w2, -h2 }, { w2, -h2 }, { w2, h2 }, { -w2, h2 } },
      color = { r or 1, g or 0.91, b or 0.15, 1 }
   } }
   return result
end

function makeMeshFromSibling(sib, imageData)
   local img = love.graphics.newImage(imageData)
   local editing = mesh.makeVertices(sib)

   mesh.addUVToVerts(editing, img, sib.points, sib.texture)
   local result = mesh.makeMeshFromVertices(editing, sib.type, sib.texture)

   result:setTexture(img)
   return result
end

function redoTheGraphicInPart(part, bg, fg, bgp, fgp, lineColor)

   local p
   if part.children then
      p = part.children[1]
   else
      p = part
   end

   local lineartUrl = p.texture.url
   local lineart = mesh.getImage(lineartUrl, p.texture)
   local mask


   mask = mesh.getImage(getPNGMaskUrl(lineartUrl))
   if mask == nil then
      print('no mask found', lineartUrl, getPNGMaskUrl(lineartUrl))
   end

   if (lineart and mask) then
      local canvas = canvas.makeTexturedCanvas(
         lineart, mask,
         bgp, bg,
         fgp, fg, lineColor)
      if p.texture.canvas then
         p.texture.canvas:release()
      end
      local m = makeMeshFromSibling(p, canvas)
      canvas:release()
      p.texture.canvas = m
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

   -------


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
   -- print(inspect(head))
   -- print(inspect(body))


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
   function love.keypressed(key, unicode)
      if key == 'escape' then love.event.quit() end
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
         --local t = r1._parent.transforms._g

         ---local x, y = r1.transforms._g:transformPoint(0, 0)
         --local pivx = head.transforms.l[6]
         --local pivy = head.transforms.l[7]
         --local x, y = head.transforms._g:transformPoint(pivx, pivy)
         local x2, y2, w, h = bbox.getMiddleOfContainer(head)

         --local x, y = r1._parent.transforms._g:inverseTransformPoint(x, y)
         --camera.setCameraViewport(cam, 200,200)
         --cam:update(2000, 2000)

         camera.centerCameraOnPosition(x2, y2, w * 1.61, h * 1.61)
         --  cam:update(2000,2000)

         --print('focus camera on first other shape', x, y)
      end
      if key == '2' then

         local bbBody = bbox.getBBoxRecursive(body)
         --local bbLeg1 = bbox.getBBoxRecursive(leg1) -- these are empty
         -- local bbLeg2 = bbox.getBBoxRecursive(leg2) -- this is empty too
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
         --local bbLeg1 = bbox.getBBoxRecursive(leg1) -- these are empty
         -- local bbLeg2 = bbox.getBBoxRecursive(leg2) -- this is empty too
         local bbFeet1 = bbox.getBBoxRecursive(feet1)
         local bbFeet2 = bbox.getBBoxRecursive(feet2)

         local tlx, tly, brx, bry = bbox.combineBboxes(bbHead, bbBody, bbFeet1, bbFeet2)
         local x2, y2, w, h = bbox.getMiddleAndDimsOfBBox(tlx, tly, brx, bry)
         --local x, y = r3.transforms._g:transformPoint(0, 0)
         --  local x2,y2 = cam:getScreenCoordinates(x,y)
         -- local x1,y1 = cam:getWorldCoordinates(x2,y2)


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

function createLegRubberhose(legNr, points)
   local flop = legNr == 1 and values.leg1flop or values.leg2flop

   return createRubberHoseFromImage(
      legUrls[values.legs.shape],
      palettes[values.legs.bgPal], palettes[values.legs.fgPal],
      textures[values.legs.bgTex], textures[values.legs.fgTex], flop
      , values.legLength,
      values.legWidthMultiplier,
      points)
end

local mask_shader = love.graphics.newShader [[
      vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
         if (Texel(texture, texture_coords).rgba != vec4(1.0)) {
            // a discarded pixel wont be applied as the stencil.
            discard;
         }
         return vec4(1.0);
      }
   ]]



function renderMaskedTexture(maskShape, texture, x, y, sx, sy)
   if not texture or not maskShape then return end
   if texture == 1 then return end

   local bw, bh = maskShape:getDimensions()
   local iw, ih = texture:getDimensions()
   local s = math.max(bw / iw, bh / ih)

   local function myStencilFunction()
      love.graphics.setShader(mask_shader)
      love.graphics.draw(maskShape, x, y, 0, sx, sy)
      love.graphics.setShader()
   end

   love.graphics.stencil(myStencilFunction, "replace", 1)
   love.graphics.setStencilTest("greater", 0)
   love.graphics.draw(texture, x, y, 0, s * sx, s * sy)
   love.graphics.setStencilTest()

end

function createFittingScale(img, desired_w, desired_h)
   local w, h = img:getDimensions()
   local sx, sy = desired_w / w, desired_h / h
   --   print(sx, sy)
   return sx, sy
end

function drawBBoxDebug()
   if true then
      love.graphics.push() -- stores the default coordinate system
      local w, h = love.graphics.getDimensions()
      love.graphics.translate(w / 2, h / 2)
      love.graphics.scale(.25) -- zoom the camera
      if love.mouse.isDown(1) then
         local mx, my = love.mouse:getPosition()
         local wx, wy = cam:getWorldCoordinates(mx, my)

         for j = 1, #root.children do
            local guy = root.children[j]

            for i = 1, #guy.children do
               local item = guy.children[i]
               local b = bbox.getBBoxRecursive(item)


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
         renderMaskedTexture(blup2, textureOrColors[i], new_x + xOffset, new_y + yOffset, scale, scale)
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

function changeBody()
   local temp_x, temp_y = body.transforms.l[1], body.transforms.l[2]
   body = copy3(bodyParts[values.body.shape])

   body.transforms.l[1] = temp_x
   body.transforms.l[2] = temp_y
   body.transforms.l[4] = values.bodyWidthMultiplier
   body.transforms.l[5] = values.bodyHeightMultiplier
   guy.children = { body, leg1, leg2, feet1, feet2, head }

   parentize.parentize(root)

   redoBody() --- this position is very iportant, if i move redoBody under the meshall we get these borders aorund images
   mesh.meshAll(root)

   render.justDoTransforms(root)

   biped:give('biped', { guy = guy, body = body, leg1 = leg1, leg2 = leg2, feet1 = feet1, feet2 = feet2, head = head })
end

function changeLegs()
   for i = 1, #guy.children do
      if (guy.children[i] == leg1) then
         leg1 = createLegRubberhose(1, leg1.points)
         guy.children[i] = leg1
      end
      if (guy.children[i] == leg2) then
         leg2 = createLegRubberhose(2, leg2.points)
         guy.children[i] = leg2
      end
   end
   parentize.parentize(root)

   -- graphic.
   mesh.meshAll(root)
   biped:give('biped',
      { guy = guy, body = body, leg1 = leg1, leg2 = leg2, feet1 = feet1, feet2 = feet2, head = head })
   myWorld:emit("bipedAttachFeet", biped)
end

function redoLegs()
   leg1 = createLegRubberhose(1, leg1.points)
   leg2 = createLegRubberhose(2, leg2.points)

   guy.children = { body, leg1, leg2, feet1, feet2, head }
   parentize.parentize(root)
   biped:give('biped',
      { guy = guy, body = body, leg1 = leg1, leg2 = leg2, feet1 = feet1, feet2 = feet2, head = head })
   myWorld:emit("bipedAttachFeet", biped)
   mesh.meshAll(root)
end

function redoBody()
   redoTheGraphicInPart(
      body,
      palettes[values.body.bgPal],
      palettes[values.body.fgPal],
      textures[values.body.bgTex],
      textures[values.body.fgTex],
      palettes[values.body.linePal]
   )
end

function redoFeet()
   redoTheGraphicInPart(
      feet1,
      palettes[values.feet.bgPal],
      palettes[values.feet.fgPal],
      textures[values.feet.bgTex],
      textures[values.feet.fgTex],
      palettes[values.feet.linePal]
   )
   redoTheGraphicInPart(
      feet2,
      palettes[values.feet.bgPal],
      palettes[values.feet.fgPal],
      textures[values.feet.bgTex],
      textures[values.feet.fgTex],
      palettes[values.feet.linePal]
   )
end

function changeFeet()

   for i = 1, #guy.children do
      if (guy.children[i] == feet1) then
         local r = feet1.transforms.l[3]
         local sx = feet1.transforms.l[4]
         feet1 = copy3(feetParts[values.feet.shape])
         feet1.transforms.l[3] = r
         feet1.transforms.l[4] = sx
         guy.children[i] = feet1
      end

      if (guy.children[i] == feet2) then
         local r = feet2.transforms.l[3]
         local sx = feet2.transforms.l[4]
         feet2 = copy3(feetParts[values.feet.shape])
         feet2.transforms.l[3] = r
         feet2.transforms.l[4] = sx
         guy.children[i] = feet2
      end
   end
   parentize.parentize(root)
   redoFeet()
   biped:give('biped',
      { guy = guy, body = body, leg1 = leg1, leg2 = leg2, feet1 = feet1, feet2 = feet2, head = head })
   myWorld:emit("bipedAttachFeet", biped)

   mesh.meshAll(root)
   --redoFeet()
end

function changeHead()
   head = copy3(headParts[values.head.shape])

   guy.children = { body, leg1, leg2, feet1, feet2, head }
   parentize.parentize(root)
   redoHead()

   biped:give('biped',
      { guy = guy, body = body, leg1 = leg1, leg2 = leg2, feet1 = feet1, feet2 = feet2, head = head })
   myWorld:emit("bipedAttachFeet", biped)

   mesh.meshAll(root)

end

function redoHead()
   redoTheGraphicInPart(head, palettes[values.head.bgPal], palettes[values.head.fgPal],
      textures[values.head.bgTex], textures[values.head.fgTex], palettes[values.head.linePal])
   head.dirty = true
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

function scroller(render, clickX, clickY)

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
      --love.graphics.setColor(0.2, 0.2, 0.2, .9)
      --love.graphics.rectangle('fill', 20, yPosition, size, size)
      local index = math.ceil(-scrollPosition) + i
      index = (index % #elements) + 1

      local whiterectIndex = math.ceil(-scrollPosition) + i
      whiterectIndex = (whiterectIndex % #whiterects) + 1
      local wrw, wrh = whiterects[whiterectIndex]:getDimensions()
      local scaleX = size / wrw
      local scaleY = size / wrh

      if render then
         love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], .8)

         love.graphics.setColor(.1, .1, .1, .2)
         love.graphics.draw(whiterects[whiterectIndex], 20 + 4, yPosition + 4, 0, scaleX, scaleY)

         love.graphics.setColor(255 / 255, 240 / 255, 200 / 255)
         love.graphics.draw(whiterects[whiterectIndex], 20, yPosition, 0, scaleX, scaleY)

         love.graphics.setColor(0, 0, 0)
         love.graphics.print(elements[index], 20, yPosition)
      else
         if (hit.pointInRect(clickX, clickY, 20, yPosition, size, size)) then
            print('click on the thingie', elements[index])
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

      scroller(true)

      prof.push("cam-render")
      cam:push()
      render.renderThings(root, false)

      if false then
         for _, v in pairs(cameraPoints) do
            love.graphics.setColor(v.color)

            love.graphics.rectangle('line', v.x, v.y, v.width, v.height)
         end
      end

      cam:pop()
      prof.pop("cam-render")


      prof.push("render-ui")
      if false then -- this block leaks memory still...

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
         if false then
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

      if false then -- this is leaking too
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

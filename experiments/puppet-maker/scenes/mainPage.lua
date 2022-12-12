-- https://medium.com/@chrisgaul/https-medium-com-chrisgaul-is-this-language-without-letters-the-future-of-global-communication-15fc54909c12
-- http://bamanda.com/locos/locos_subsite/locos_gallery.html

local scene = {}

local render = require 'lib.render'
local mesh = require 'lib.mesh'
local parentize = require 'lib.parentize'

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

end

function pointerReleased(x, y, id)
   for i = #pointerInteractees, 1, -1 do
      if pointerInteractees[i].id == id then
         table.remove(pointerInteractees, i)
      end
   end
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
   --print('remove index', index)
   if index >= 0 then table.remove(elem._parent.children, index) end
end

-- todo how todo the combined canvas rubberhose thing (the filled in images?)

function createRubberHoseFromImage(url, bg, fg, bgp, fgp, flop, length, widthMultiplier, optionalPoints)
   local img = mesh.getImage(url)
   local width, height = img:getDimensions()
   local magic = 4.46

   local currentNode = {}
   currentNode.type = 'rubberhose'
   currentNode.data = currentNode.data or {}
   currentNode.texture = {}
   currentNode.texture.url = url -- 'assets/parts/leg2-mask.png' --url
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
      local maskUrls = {
         ['assets/parts/leg1.png'] = 'assets/parts/leg1-mask.png',
         ['assets/parts/leg2.png'] = 'assets/parts/leg2-mask.png',
         ['assets/parts/leg3.png'] = 'assets/parts/leg3-mask.png',
         ['assets/parts/leg4.png'] = 'assets/parts/leg4-mask.png',
         ['assets/parts/leg5.png'] = 'assets/parts/leg5-mask.png',

      }
      local lineart = img
      print(url)
      local mask = mesh.getImage(maskUrls[url])
      local canvas = canvas.makeTexturedCanvas(
         lineart, mask,
         bgp, bg or palettes[values.bodyBGPalIndex],
         fgp, fg or palettes[values.bodyFGPalIndex])

      currentNode.texture.retexture = love.graphics.newImage(canvas)
      --canvas:release()
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

function makeMeshFromSibling(sib, imageData)

   local img = love.graphics.newImage(imageData)
   local editing = mesh.makeVertices(sib)

   mesh.addUVToVerts(editing, img, sib.points, sib.texture)
   local made = mesh.makeMeshFromVertices(editing, sib.type, sib.texture)

   made:setTexture(img)
   return made
end

function redoTheGraphicInPart(part, bg, fg, bgp, fgp)

   local lineartToMask = {
      ['assets/parts/romp1.png'] = 'assets/parts/romp1-mask.png',
      ['assets/parts/leg2.png'] = 'assets/parts/leg2-mask.png',
      ['assets/parts/headshapebuff.png'] = 'assets/parts/headshapebuff-mask.png'
   }

   local p
   if part.children then
      p = part.children[1]
   else
      p = part
   end


   local lineartUrl = p.texture.url
   local lineart = (mesh.getImage(lineartUrl, p.texture))

   local mask
   if lineartToMask[lineartUrl] then
      mask = mesh.getImage(lineartToMask[lineartUrl])
   end
   --print(lineart, mask)
   if (lineart and mask) then
      local canvas = canvas.makeTexturedCanvas(
         lineart, mask,
         bgp, bg,
         fgp, fg)

      local m = makeMeshFromSibling(p, canvas)
      p.texture.canvas = m
   end
   --   part.children[1].texture.

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

   mask = love.graphics.newImage("assets/parts/romp1-mask.png")
   lineart = love.graphics.newImage('assets/parts/romp1.png')
   --grunge = love.graphics.newImage('assets/layered/ice.jpg')


   blup0 = love.graphics.newImage('assets/blups/blup1.png')
   blup1 = love.graphics.newImage('assets/blups/blup5.png')
   blup2 = love.graphics.newImage('assets/blups/blup2.png')
   blup3 = love.graphics.newImage('assets/blups/blup3.png')
   blup4 = love.graphics.newImage('assets/blups/blup4.png')

   textures = {
      1,

      love.graphics.newImage('assets/layered/texture-type2t.png'),
      love.graphics.newImage('assets/layered/texture-type1.png'),
      love.graphics.newImage('assets/layered/texture-type3.png'),
      love.graphics.newImage('assets/layered/texture-type4.png'),
      love.graphics.newImage('assets/layered/texture-type5.png'),
      love.graphics.newImage('assets/layered/texture-type6.png'),
      nil
   }

   palettes = {
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
      { 0.941, 0.518, 0.122, 1 }
   }

   uiImg = love.graphics.newImage('assets/ui2.png')
   uiBlup = love.graphics.newImage('assets/blups/blup8.png')

   delta = 0

   root = {
      folder = true,
      name = 'root',
      transforms = { l = { 0, 0, 0, 1, 1, 0, 0 } },
      children = {}
   }

   -------


   values = {
      legImgIndex = 2,
      legLength = 700,
      legWidthMultiplier = 1,
      leg1flop = 1,
      leg2flop = 1,
      feetTypeIndex = 1,
      legBGPalIndex = 4,
      legFGPalIndex = 1,
      legBGTexIndex = 1,
      legFGTexIndex = 2,

      bodyBGPalIndex = 4,
      bodyFGPalIndex = 1,
      bodyBGTexIndex = 1,
      bodyFGTexIndex = 3,

      eyeTypeIndex = 1,
   }

   feetUrls = { 'assets/feet1.polygons.txt', 'assets/feet3.polygons.txt', 'assets/feet4.polygons.txt' }
   feetParts = {}
   for i = 1, #feetUrls do
      feetParts[i] = parse.parseFile(feetUrls[i])[1]
      stripPath(feetParts[i], '/experiments/puppet%-maker/')
   end

   eyeUrls = { 'assets/eye1.polygons.txt' }
   eyeParts = {}
   for i = 1, #eyeUrls do
      eyeParts[i] = parse.parseFile(eyeUrls[i])[1]
      stripPath(feetParts[i], '/experiments/puppet%-maker/')
   end
   --   print(inspect(eyeParts))

   legUrls = { 'assets/parts/leg1.png', 'assets/parts/leg2.png', 'assets/parts/leg3.png', 'assets/parts/leg4.png',
      'assets/parts/leg5.png' }

   bodyUrls = { 'assets/body.polygons.txt', 'assets/body2.polygons.txt' }
   bodyParts = {}
   for i = 1, #bodyUrls do
      bodyParts[i] = parse.parseFile(bodyUrls[i])[1]
      stripPath(bodyParts[i], '/experiments/puppet%-maker/')
   end
   body = copy3(bodyParts[1])

   redoTheGraphicInPart(body, palettes[values.bodyBGPalIndex], palettes[values.bodyFGPalIndex],
      textures[values.bodyBGTexIndex], textures[values.bodyFGTexIndex])

   head = parse.parseFile('assets/head4.polygons.txt')[1]
   --   print(inspect(head))

   eye1 = copy3(eyeParts[values.eyeTypeIndex])
   eye2 = copy3(eyeParts[values.eyeTypeIndex])

   addChild(head, eye1)
   addChild(head, eye2)
   -- DRAW SOME EYES!


   stripPath(head, '/experiments/puppet%-maker/')
   redoTheGraphicInPart(head, palettes[values.bodyBGPalIndex], palettes[values.bodyFGPalIndex],
      textures[values.bodyBGTexIndex], textures[values.bodyFGTexIndex])

   leg1 = createLegRubberhose(1)
   leg2 = createLegRubberhose(2)

   feet1 = copy3(feetParts[values.feetTypeIndex])
   feet2 = copy3(feetParts[values.feetTypeIndex])

   guy = {
      folder = true,
      name = 'guy',
      transforms = { l = { 0, 0, 0, 1, 1, 0, 0 } },
      children = {}
   }
   guy.children = { body, leg1, leg2, feet1, feet2, head }
   root.children = { guy }

   stripPath(root, '/experiments/puppet%-maker/')

   parentize.parentize(root)
   mesh.meshAll(root)
   --mesh.recursivelyMakeTextures(root)
   render.renderThings(root)


   biped = Concord.entity()
   biped:give('biped', { guy = guy, body = body, leg1 = leg1, leg2 = leg2, feet1 = feet1, feet2 = feet2, head = head })


   myWorld:addEntity(biped)
   myWorld:emit("bipedInit", biped)
   attachCallbacks()

   -- dont understand how imma gonna center on head, body and legs yet
   local bx, by = head.transforms._g:transformPoint(0, 0)
   --local gx, gy = guy.transforms._g:transformPoint(bx, by)
   local w, h = love.graphics.getDimensions()
   local lw, lh = lineart:getDimensions()
   camera.setCameraViewport(cam, w, h)
   camera.centerCameraOnPosition(bx, by, w * 1, lh * 4)
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

      if key == 'f' then
         values.feetTypeIndex = values.feetTypeIndex + 1
         if (values.feetTypeIndex > #feetParts) then values.feetTypeIndex = 1 end

         for i = 1, #guy.children do
            if (guy.children[i] == feet1) then
               local r = feet1.transforms.l[3]
               local sx = feet1.transforms.l[4]

               feet1 = copy3(feetParts[values.feetTypeIndex])
               feet1.transforms.l[3] = r
               feet1.transforms.l[4] = sx

               guy.children[i] = feet1
               biped:give('biped',
                  { guy = guy, body = body, leg1 = leg1, leg2 = leg2, feet1 = feet1, feet2 = feet2, head = head })
               myWorld:emit("bipedAttachFeet", biped)
               parentize.parentize(root)
               mesh.meshAll(root)
            end

            if (guy.children[i] == feet2) then
               local r = feet2.transforms.l[3]
               local sx = feet2.transforms.l[4]

               feet2 = copy3(feetParts[values.feetTypeIndex])
               feet2.transforms.l[3] = r
               feet2.transforms.l[4] = sx

               guy.children[i] = feet2
               biped:give('biped',
                  { guy = guy, body = body, leg1 = leg1, leg2 = leg2, feet1 = feet1, feet2 = feet2, head = head })
               myWorld:emit("bipedAttachFeet", biped)
               parentize.parentize(root)
               mesh.meshAll(root)

            end
         end
      end
      if key == 'l' then


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
      local lw, lh = lineart:getDimensions()

      local bx, by = body.transforms._g:transformPoint(0, 0)
      --      local w, h = love.graphics.getDimensions()
      camera.setCameraViewport(cam, w, h)
      camera.centerCameraOnPosition(bx, by, w * 1, lh * 4)
      cam:update(w, h)


   end

   function love.wheelmoved(dx, dy)
      local newScale = cam.scale * (1 + dy / 10)
      if (newScale > 0.01 and newScale < 50) then
         cam:scaleToPoint(1 + dy / 10)
      end
   end

end

--

function scene.update(dt)
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
   myWorld:emit("update", dt)

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

function pointerPressed(x, y, id)
   local wx, wy = cam:getWorldCoordinates(x, y)
   for j = 1, #root.children do
      local guy = root.children[j]
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

function createLegRubberhose(legNr, points)
   local flop = legNr == 1 and values.leg1flop or values.leg2flop

   return createRubberHoseFromImage(
      legUrls[values.legImgIndex],
      palettes[values.legBGPalIndex], palettes[values.legFGPalIndex],
      textures[values.legBGTexIndex], textures[values.legFGTexIndex], flop
      , values.legLength,
      values.legWidthMultiplier,
      points)
end

function renderMaskedTexture(maskShape, texture, x, y, sx, sy)
   if not texture or not maskShape then return end
   if texture == 1 then return end

   local bw, bh = maskShape:getDimensions()
   local iw, ih = texture:getDimensions()
   local s = math.max(bw / iw, bh / ih)

   local mask_shader = love.graphics.newShader [[
      vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
         if (Texel(texture, texture_coords).rgb != vec3(1.0)) {
            // a discarded pixel wont be applied as the stencil.
            discard;
         }
         return vec4(1.0);
      }
   ]]

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

function scene.draw()
   local stats = love.graphics.getStats()
   ui.handleMouseClickStart()
   love.graphics.clear(bgColor)
   love.graphics.setColor(0, 0, 0)

   cam:push()
   render.renderThings(root)
   cam:pop()

   local str = string.format("Estimated amount of texture memory used: %.2f MB", stats.texturememory / 1024 / 1024)
   love.graphics.print(str, 10, 10)
   love.graphics.print("FPS: " .. tostring(love.timer.getFPS()), 10, 30)

   --drawBBoxAroundItems()
   if false then
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





   love.graphics.setColor(0, 0, 0, .25)
   local b = newImageButton(blup4, 50, 400, .2, .2)
   renderMaskedTexture(blup4, textures[values.bodyBGTexIndex], 40, 410, .2, .2)

   if b.clicked then
      values.bodyBGTexIndex = values.bodyBGTexIndex + 1
      if (values.bodyBGTexIndex > #textures) then values.bodyBGTexIndex = 1 end
      redoTheGraphicInPart(body, palettes[values.bodyBGPalIndex], palettes[values.bodyFGPalIndex],
         textures[values.bodyBGTexIndex], textures[values.bodyFGTexIndex])
   end

   love.graphics.setColor(0, 0, 0, .25)
   b = newImageButton(blup2, 150, 400, .2, .2)
   renderMaskedTexture(blup2, textures[values.bodyFGTexIndex], 140, 410, .2, .2)

   if b.clicked then
      values.bodyFGTexIndex = values.bodyFGTexIndex + 1
      if (values.bodyFGTexIndex > #textures) then values.bodyFGTexIndex = 1 end
      redoTheGraphicInPart(body, palettes[values.bodyBGPalIndex], palettes[values.bodyFGPalIndex],
         textures[values.bodyBGTexIndex], textures[values.bodyFGTexIndex])
   end



   --love.graphics.setColor(0, 0, 0, 1)

   -- draw the pattern
   love.graphics.setColor(palettes[values.bodyBGPalIndex])
   b = newImageButton(blup2, 250, 400, .2, .2)
   if b.clicked then
      values.bodyBGPalIndex = values.bodyBGPalIndex + 1
      if (values.bodyBGPalIndex > #palettes) then values.bodyBGPalIndex = 1 end
      redoTheGraphicInPart(body, palettes[values.bodyBGPalIndex], palettes[values.bodyFGPalIndex],
         textures[values.bodyBGTexIndex], textures[values.bodyFGTexIndex])
   end


   love.graphics.setColor(palettes[values.bodyFGPalIndex])
   b = newImageButton(blup2, 350, 400, .2, .2)
   if b.clicked then
      values.bodyFGPalIndex = values.bodyFGPalIndex + 1
      if (values.bodyFGPalIndex > #palettes) then values.bodyFGPalIndex = 1 end
      redoTheGraphicInPart(body, palettes[values.bodyBGPalIndex], palettes[values.bodyFGPalIndex],
         textures[values.bodyBGTexIndex], textures[values.bodyFGTexIndex])
      --updateBodyGeneratedCanvas()
   end

   love.graphics.setColor(0, 0, 0, .5)
   b = newImageButton(blup2, 50, 500, .2, .2)
   local img = mesh.getImage(legUrls[values.legImgIndex])
   love.graphics.setColor(0, 0, 0, .75)
   love.graphics.draw(img, 50 + 25, 500, 0, .2, .2)

   if b.clicked then

      values.legImgIndex = values.legImgIndex + 1
      if values.legImgIndex > #legUrls then values.legImgIndex = 1 end

      for i = 1, #guy.children do
         if (guy.children[i] == leg1) then
            leg1 = createLegRubberhose(1, leg1.points)

            guy.children[i] = leg1
            biped:give('biped',
               { guy = guy, body = body, leg1 = leg1, leg2 = leg2, feet1 = feet1, feet2 = feet2, head = head })
            myWorld:emit("bipedAttachFeet", biped)
            parentize.parentize(root)
            mesh.meshAll(root)
         end
         if (guy.children[i] == leg2) then
            leg2 = createLegRubberhose(2, leg2.points)

            guy.children[i] = leg2
            biped:give('biped',
               { guy = guy, body = body, leg1 = leg1, leg2 = leg2, feet1 = feet1, feet2 = feet2, head = head })
            myWorld:emit("bipedAttachFeet", biped)
            parentize.parentize(root)
            mesh.meshAll(root)
         end

      end
   end



   love.graphics.setColor(palettes[values.legBGPalIndex])
   b = newImageButton(blup2, 150, 500, .2, .2)
   if b.clicked then
      values.legBGPalIndex = values.legBGPalIndex + 1
      if (values.legBGPalIndex > #palettes) then values.legBGPalIndex = 1 end
      --redoTheGraphicInPart(body, palettes[values.legBGPalIndex], palettes[values.legFGPalIndex])
      leg1 = createLegRubberhose(1, leg1.points)
      leg2 = createLegRubberhose(2, leg2.points)

      guy.children = { body, leg1, leg2, feet1, feet2, head }
      parentize.parentize(root)
      biped:give('biped',
         { guy = guy, body = body, leg1 = leg1, leg2 = leg2, feet1 = feet1, feet2 = feet2, head = head })

      mesh.meshAll(root)

   end

   love.graphics.setColor(palettes[values.legFGPalIndex])
   b = newImageButton(blup2, 250, 500, .2, .2)
   if b.clicked then
      values.legFGPalIndex = values.legFGPalIndex + 1
      if (values.legFGPalIndex > #palettes) then values.legFGPalIndex = 1 end
      leg1 = createLegRubberhose(1, leg1.points)
      leg2 = createLegRubberhose(2, leg2.points)

      guy.children = { body, leg1, leg2, feet1, feet2, head }
      parentize.parentize(root)
      biped:give('biped',
         { guy = guy, body = body, leg1 = leg1, leg2 = leg2, feet1 = feet1, feet2 = feet2, head = head })

      mesh.meshAll(root)

   end

   --drawCirclesAroundCenterCircle(30, h / 3, 'head', h / 20, h / 6, h / 24)
   --drawCirclesAroundCenterCircle(30, (h / 3) * 2, 'body', h / 20, h / 6, h / 24)

   love.graphics.setColor(0, 0, 0, .5)
   love.graphics.draw(blup2, 350, 500, 0, .2, .2)

   local v = h_slider("leg-length", 380, 520, 50, values.legLength, 200, 2000)

   if v.value then
      values.legLength = v.value
      leg1 = createLegRubberhose(1, leg1.points)
      leg2 = createLegRubberhose(2, leg2.points)

      guy.children = { body, leg1, leg2, feet1, feet2, head }
      parentize.parentize(root)
      biped:give('biped',
         { guy = guy, body = body, leg1 = leg1, leg2 = leg2, feet1 = feet1, feet2 = feet2, head = head })
      myWorld:emit("bipedAttachFeet", biped)
      mesh.meshAll(root)
   end
   local v = h_slider("leg-width-multiplier", 380, 550, 50, values.legWidthMultiplier, 0.1, 2)
   if v.value then
      values.legWidthMultiplier = v.value
      leg1 = createLegRubberhose(1, leg1.points)
      leg2 = createLegRubberhose(2, leg2.points)

      guy.children = { body, leg1, leg2, feet1, feet2, head }
      parentize.parentize(root)
      biped:give('biped',
         { guy = guy, body = body, leg1 = leg1, leg2 = leg2, feet1 = feet1, feet2 = feet2, head = head })
      myWorld:emit("bipedAttachFeet", biped)
      mesh.meshAll(root)
   end

   -- love.graphics.print("TMEM: " .. tostring(stats.canvasswitches), 10, 30)
   --print('img mem', stats.texturememory)
   --  print('Memory actually used (in kB): ' .. collectgarbage('count'))
end

return scene

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

local makeTexturedCanvas = require('lib.canvas').makeTexturedCanvas
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

function pointerPressed(x, y, id)
   local wx, wy = cam:getWorldCoordinates(x, y)
   for j = 1, #root.children do
      local guy = root.children[j]
      for i = 1, #guy.children do

         local item = guy.children[i]
         local b = bbox.getBBoxRecursive(item)
         --print(inspect(b))
         if b and item.folder then

            local mx, my = item.transforms._g:inverseTransformPoint(wx, wy)
            local tlx, tly = item.transforms._g:inverseTransformPoint(b[1], b[2])
            local brx, bry = item.transforms._g:inverseTransformPoint(b[3], b[4])

            --print(wx, wy, tlx, tly, brx - tlx, bry - tly)

            if (hit.pointInRect(mx, my, tlx, tly, brx - tlx, bry - tly)) then
               --print('bbox hit', item.name)

               table.insert(pointerInteractees, { state = 'pressed', item = item, x = x, y = y, id = id })
            end
         end
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

function createRubberHoseFromImage(url, flop, length, widthMultiplier, optionalPoints)
   -- we should be able to make it of a specific height/length

   local img = mesh.getImage(url)
   local width, height = img:getDimensions()
   --print(height, length)
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
   currentNode.color = { 0, 0, 0 }
   currentNode.data.scaleX = 1
   currentNode.data.scaleY = length / height
   currentNode.points = optionalPoints or { { 0, 0 }, { 0, height / 2 } }
   mesh.remeshNode(currentNode)
   return currentNode
end

function makeDynamicCanvas(canvas, mymesh)
   local w, h = canvas:getDimensions()
   local w2 = w / 2
   local h2 = h / 2

   local result = {}
   result.color = { 1, 1, 1 }
   result.name = 'generated'
   result.points = { { -w2, -h2 }, { w2, -h2 }, { w2, h2 }, { -w2, h2 } }
   result.texture = {
      filter = "linear",
      canvas = mymesh,
      imageData = canvas:newImageData(),
      wrap = "repeat",
      dimensions = { w, h }
   }

   return result
end

function makeMeshFromSibling(sib, canvas)
   local texture = canvas
   local data = texture:newImageData()
   local img = love.graphics.newImage(data)

   local editing = mesh.makeVertices(sib)

   mesh.addUVToVerts(editing, img, sib.points, sib.texture)
   local made = mesh.makeMeshFromVertices(editing, sib.type, sib.texture)

   made:setTexture(img)
   return made
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

   mask = love.graphics.newImage("assets/layered/romp1-mask.png")
   lineart = love.graphics.newImage('assets/layered/romp1.png')
   --grunge = love.graphics.newImage('assets/layered/ice.jpg')
   grunge2 = love.graphics.newImage('assets/layered/grunge.png')
   texture1 = love.graphics.newImage('assets/layered/texture-type1.png')
   blup1 = love.graphics.newImage('assets/blups/blup1.png')
   blup2 = love.graphics.newImage('assets/blups/blup5.png')


   local lw, lh = lineart:getDimensions()
   canvas = love.graphics.newCanvas(lw, lh)


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

   skinFurHSL = { vivid.RGBtoHSL(0.396, 0.604, 0.698) }
   skinBackHSL = { vivid.RGBtoHSL(0.396, 0.604, 0.698) }

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
      legLength = 700,
      legWidthMultiplier = 1,
      leg1flop = 1,
      leg2flop = 1,
   }

   body = parse.parseFile('assets/body.polygons.txt')[1]
   head = parse.parseFile('assets/head4.polygons.txt')[1]
   leg1 = createRubberHoseFromImage('assets/parts/leg5.png', values.leg1flop, values.legLength, values.legWidthMultiplier)
   --leg2 = createRubberHoseFromImage('assets/parts/neck.png', 1)
   leg2 = createRubberHoseFromImage('assets/parts/leg3.png', values.leg2flop, values.legLength, values.legWidthMultiplier)


   feet1 = parse.parseFile('assets/feet1.polygons.txt')[1]
   feet2 = copy3(feet1) --parse.parseFile('assets/feet2.polygons.txt')[1]

   feet3 = parse.parseFile('assets/feet3.polygons.txt')[1]
   stripPath(feet3, '/experiments/puppet%-maker/')
   guy = {
      folder = true,
      name = 'guy',
      transforms = { l = { 0, 0, 0, 1, 1, 0, 0 } },
      children = {}
   }
   guy.children = { body, leg1, leg2, feet1, feet2, head }
   root.children = { guy }

   --root.children = { leg1, leg2, feet1, feet2, body, head }
   stripPath(root, '/experiments/puppet%-maker/')

   parentize.parentize(root)
   mesh.meshAll(root)
   mesh.recursivelyMakeTextures(root)
   render.renderThings(root)

   --- custom background
   if true then
      local canvas = makeTexturedCanvas(canvas,
         lineart, mask,
         grunge2, { vivid.HSLtoRGB(skinBackHSL) },
         texture1, { vivid.HSLtoRGB(skinFurHSL) })

      local romp = node.findNodeByName(body, 'romp')
      local m = makeMeshFromSibling(romp, canvas)
      local dynamic = makeDynamicCanvas(canvas, m)

      addChildBefore(romp, dynamic)

   end

   biped = Concord.entity()
   biped:give('biped', { guy = guy, body = body, leg1 = leg1, leg2 = leg2, feet1 = feet1, feet2 = feet2, head = head })

   myWorld:addEntity(biped)
   myWorld:emit("bipedInit", biped)
   attachCallbacks()

   -- dont understand how imma gonna center on head, body and legs yet
   local bx, by = head.transforms._g:transformPoint(0, 0)
   --local gx, gy = guy.transforms._g:transformPoint(bx, by)
   local w, h = love.graphics.getDimensions()
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
         --print('changing?', inspect(guy.children))
         for i = 1, #guy.children do
            if (guy.children[i] == feet1) then
               guy.children[i] = feet3
               biped:give('biped',
                  { guy = guy, body = body, leg1 = leg1, leg2 = leg2, feet1 = feet3, feet2 = feet2, head = head })
               myWorld:emit("bipedAttachFeet", biped)
               parentize.parentize(root)
               mesh.meshAll(root)

            elseif (guy.children[i] == feet3) then
               guy.children[i] = feet1
               biped:give('biped',
                  { guy = guy, body = body, leg1 = leg1, leg2 = leg2, feet1 = feet1, feet2 = feet2, head = head })
               myWorld:emit("bipedAttachFeet", biped)
               parentize.parentize(root)
               mesh.meshAll(root)

            end
         end

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

function love.mousereleased()
   lastDraggedElement = nil
end

function drawUI()
   local stats = love.graphics.getStats()


   --love.graphics.print('hose length: ' .. (redB), 30, 30 - 20)
   local slider = h_slider('skin hue', 30, 30, 200, skinBackHSL[1], 0, 1)
   if slider.value ~= nil then
      skinBackHSL[1] = slider.value
   end
   local slider = h_slider('skin sat', 30, 70, 200, skinBackHSL[2], 0, 1)
   if slider.value ~= nil then
      skinBackHSL[2] = math.floor((slider.value) * 3) / 3
   end
   local slider = h_slider('skin light', 30, 100, 200, skinBackHSL[3], 0, 1)
   if slider.value ~= nil then

      skinBackHSL[3] = math.floor((slider.value) * 7) / 7
   end

   local slider = h_slider('fur hue', 330, 30, 200, skinFurHSL[1], 0, 1)
   if slider.value ~= nil then
      skinFurHSL[1] = slider.value
   end
   local slider = h_slider('fur sat', 330, 70, 200, skinFurHSL[2], 0, 1)
   if slider.value ~= nil then
      skinFurHSL[2] = math.floor((slider.value) * 3) / 3
   end
   local slider = h_slider('fur light', 330, 100, 200, skinFurHSL[3], 0, 1)
   if slider.value ~= nil then
      skinFurHSL[3] = math.floor((slider.value) * 7) / 7
   end

   for i = 1, #palettes do
      love.graphics.setColor(palettes[i])
      love.graphics.draw(blup2, i * 50, 400, 0, .2, .2)
      --love.graphics.circle('fill', i*50, 400, 50)
   end
end

function scene.draw()
   local stats = love.graphics.getStats()
   ui.handleMouseClickStart()
   love.graphics.clear(bgColor)
   love.graphics.setColor(0, 0, 0)
   love.graphics.print("Let's create the layered furry skin thing", 400, 10)

   cam:push()
   render.renderThings(root)


   cam:pop()
   --drawUI()

   local str = string.format("Estimated amount of texture memory used: %.2f MB", stats.texturememory / 1024 / 1024)
   love.graphics.print(str, 10, 10)

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

                     --local tlx, tly, brx, bry = bbox.getPointsBBox(node.children[i].points)
                  end
               end
               --print(item)

            end
         end
      end
      love.graphics.pop() -- stores the default coordinate system
   end

   local imgW, imgH = uiImg:getDimensions()
   local w, h = love.graphics:getDimensions()
   local smallestScale = (w / imgW) / 4 --math.min(w / imgW, h / imgH)


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

   --drawCirclesAroundCenterCircle(30, h / 3, 'head', h / 20, h / 6, h / 24)
   --drawCirclesAroundCenterCircle(30, (h / 3) * 2, 'body', h / 20, h / 6, h / 24)


   local v = h_slider("leg-length", 100, 100, 200, values.legLength, 200, 1000)
   if v.value then
      values.legLength = v.value
      leg1 = createRubberHoseFromImage('assets/parts/leg5.png', values.leg1flop, values.legLength,
         values.legWidthMultiplier,
         leg1.points)
      leg2 = createRubberHoseFromImage('assets/parts/leg5.png', values.leg2flop, values.legLength,
         values.legWidthMultiplier,
         leg2.points)
      guy.children = { body, leg1, leg2, feet1, feet2, head }
      parentize.parentize(root)
      biped:give('biped',
         { guy = guy, body = body, leg1 = leg1, leg2 = leg2, feet1 = feet1, feet2 = feet2, head = head })
      myWorld:emit("bipedAttachFeet", biped)
      mesh.meshAll(root)
   end
   local v = h_slider("leg-width-multiplier", 100, 200, 200, values.legWidthMultiplier, 0.1, 2)
   if v.value then
      values.legWidthMultiplier = v.value
      leg1 = createRubberHoseFromImage('assets/parts/leg5.png', values.leg1flop, values.legLength,
         values.legWidthMultiplier,
         leg1.points)
      leg2 = createRubberHoseFromImage('assets/parts/leg5.png', values.leg2flop, values.legLength,
         values.legWidthMultiplier,
         leg2.points)
      guy.children = { body, leg1, leg2, feet1, feet2, head }
      parentize.parentize(root)
      biped:give('biped',
         { guy = guy, body = body, leg1 = leg1, leg2 = leg2, feet1 = feet1, feet2 = feet2, head = head })
      myWorld:emit("bipedAttachFeet", biped)
      mesh.meshAll(root)
   end
   --   love.graphics.print("FPS: " .. tostring(love.timer.getFPS()), 10, 10)
   -- love.graphics.print("TMEM: " .. tostring(stats.canvasswitches), 10, 30)
   --print('img mem', stats.texturememory)
   --  print('Memory actually used (in kB): ' .. collectgarbage('count'))
end

return scene

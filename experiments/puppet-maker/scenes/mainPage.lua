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
   for i = 1, #root.children do

      local item = root.children[i]
      local b = bbox.getBBoxRecursive(item)
      --print(inspect(b))
      if b and item.folder then


         local c = item._parent
         --print(getScreenBBoxForItem(item, b))
         local stlx, stly = c.transforms._g:transformPoint(b[1], b[2])
         local strx, stry = c.transforms._g:transformPoint(b[3], b[2])
         local sblx, sbly = c.transforms._g:transformPoint(b[1], b[4])
         local sbrx, sbry = c.transforms._g:transformPoint(b[3], b[4])

         local smallestX = math.min(stlx, sbrx, strx, sblx)
         local smallestY = math.min(stly, sbry, stry, sbly)
         local biggestX = math.max(stlx, sbrx, strx, sblx)
         local biggestY = math.max(stly, sbry, stry, sbly)

         --local smallestX, smallestY, biggestX, biggestY = getScreenBBoxForItem(c, b)

         local tlx, tly = smallestX, smallestY
         local brx, bry = biggestX, biggestY

         --print(wx, wy, tlx, tly, brx - tlx, bry - tly)
         if (hit.pointInRect(wx, wy, tlx, tly, brx - tlx, bry - tly)) then
            --print('bbox hit', item.name)
            if (false and
                item.children and item.children[1].texture and item.children[1].texture.canvas and
                item.children[1].texture.imageData) then
               -- item == body
               print(item.name)
               local texture = item.children[1].texture
               local imgData = texture.imageData
               local canvas = texture.canvas
               --print('hittesting pixels ?')
               --print(item.transforms._g)
               --rint(item.children[1])
               --local px, py = item.transforms._g:transformPoint(0, 0)
               local xx, yy = item.transforms._g:inverseTransformPoint(wx, wy)
               --print(inspect(item.transforms.l))
               -- print('xy', xx, yy)
               -- print('dims', texture.dimensions[1], texture.dimensions[2])
               --print(xx, yy, wx, wy)
               --local r, g, b, a = item.children[1].texture.imageData:getPixel(xx, yy)
               --print(xx, yy, r, g, b, a)
            end

            --table.insert(pointerInteractees, { state = 'pressed', item = item, x = x, y = y, id = id })
         end
      end
   end
end

function pointerMoved(x, y, dx, dy, id)
   for i = 1, #pointerInteractees do
      if pointerInteractees[i].id == id then
         local scale = cam:getScale()
         myWorld:emit("itemDrag", pointerInteractees[i], dx, dy, scale)
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

function createRubberHoseFromImage(url, flop)
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
   currentNode.data.width = width * 2
   currentNode.data.flop = flop
   currentNode.data.borderRadius = .2
   currentNode.data.steps = 20
   currentNode.color = { 0, 0, 0 }
   currentNode.data.scale = 1
   currentNode.data.scaleY = 1.5
   currentNode.points = { { 0, 0 }, { 0, height / 2 } }
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

   skinFurHSL = { vivid.RGBtoHSL(238 / 255, 173 / 255, 25 / 255) }
   skinBackHSL = { vivid.RGBtoHSL(154 / 255, 65 / 255, 22 / 255) }


   delta = 0

   root = {
      folder = true,
      name = 'root',
      transforms = { l = { 0, 0, 0, 1, 1, 0, 0 } },
      children = {}
   }

   -------

   body = parse.parseFile('assets/body.polygons.txt')[1]
   head = parse.parseFile('assets/head1.polygons.txt')[1]
   leg1 = createRubberHoseFromImage('assets/parts/line1.png', -1)
   leg2 = createRubberHoseFromImage('assets/parts/line2.png', 1)
   feet1 = parse.parseFile('assets/feet1.polygons.txt')[1]
   feet2 = copy3(feet1) --parse.parseFile('assets/feet2.polygons.txt')[1]

   --guy = makeContainerFolder('guy')
   --guy.children = { body, leg1, leg2, feet1, feet2, head }

   root.children = { body, leg1, leg2, feet1, feet2, head }
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

   local biped = Concord.entity()
   biped:give('biped', body, leg1, leg2, feet1, feet2, head)

   myWorld:addEntity(biped)
   myWorld:emit("bipedInit", biped)
   attachCallbacks()


   local bx, by = body.transforms._g:transformPoint(0, 0)
   local w, h = love.graphics.getDimensions()
   camera.setCameraViewport(cam, w, h)
   camera.centerCameraOnPosition(bx, by, w * 10, lh * 10)
   cam:update(w, h)

end

function attachCallbacks()
   function love.keypressed(key, unicode)
      if key == 'escape' then love.event.quit() end

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
      --lastDraggedElement = nil
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
      camera.centerCameraOnPosition(bx, by, w * 10, lh * 10)
      cam:update(w, h)


   end
end

--

function scene.update(dt)
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
   love.graphics.push() -- stores the default coordinate system
   local w, h = love.graphics.getDimensions()
   love.graphics.translate(w / 2, h / 2)
   love.graphics.scale(.5) -- zoom the camera
   if love.mouse.isDown(1) then
      local mx, my = love.mouse:getPosition()
      local wx, wy = cam:getWorldCoordinates(mx, my)
      --print(mx, my)

      for i = 1, #root.children do
         local item = root.children[i]
         local b = bbox.getBBoxRecursive(item)
         --print(inspect(b))



         if b then
            local c = item
            local stlx, stly = c.transforms._g:transformPoint(b[1], b[2])
            local strx, stry = c.transforms._g:transformPoint(b[3], b[2])
            local sblx, sbly = c.transforms._g:transformPoint(b[1], b[4])
            local sbrx, sbry = c.transforms._g:transformPoint(b[3], b[4])

            local smallestX = math.min(stlx, sbrx, strx, sblx)
            local smallestY = math.min(stly, sbry, stry, sbly)
            local biggestX = math.max(stlx, sbrx, strx, sblx)
            local biggestY = math.max(stly, sbry, stry, sbly)

            local tlx, tly = smallestX, smallestY
            local brx, bry = biggestX, biggestY

            local mx1, my1 = item.transforms._g:inverseTransformPoint(wx, wy)
            local tlx2, tly2 = item.transforms._g:inverseTransformPoint(b[1], b[2])
            local brx2, bry2 = item.transforms._g:inverseTransformPoint(b[3], b[4])
            --local tlx1, tly1 = item.transforms._g:inverseTransformPoint(b[1], b[2])
            --local brx1, bry1 = item.transforms._g:inverseTransformPoint(b[3], b[4])
            --print(tlx1, tly1)
            --local tlx, tly, brx, bry = getScreenBBoxForItem(item, b)
            --love.graphics.print(item.name, b[1], b[2])
            --love.graphics.rectangle('line', tlx, tly, brx - tlx, bry - tly)
            --love.graphics.rectangle('line', b[1], b[2], b[3] - b[1], b[4] - b[2])

            --love.graphics.circle('line', wx, wy, 10)
            love.graphics.print(item.name, mx1, my1)
            love.graphics.circle('line', mx1, my1, 10)
            --love.graphics.circle('line', tlx2, tly2, 10)
            love.graphics.print(item.name, tlx2, tly2)
            love.graphics.rectangle('line', tlx2, tly2, brx2 - tlx2, bry2 - tly2)
            print(mx1, my1)
            --love.graphics.circle('line', mx, my, 10)
         end
         --print(item)

      end
   end
   love.graphics.pop() -- stores the default coordinate system
   --   love.graphics.print("FPS: " .. tostring(love.timer.getFPS()), 10, 10)
   -- love.graphics.print("TMEM: " .. tostring(stats.canvasswitches), 10, 30)
   --print('img mem', stats.texturememory)
   --  print('Memory actually used (in kB): ' .. collectgarbage('count'))
end

return scene

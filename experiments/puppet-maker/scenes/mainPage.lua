-- https://medium.com/@chrisgaul/https-medium-com-chrisgaul-is-this-language-without-letters-the-future-of-global-communication-15fc54909c12
-- http://bamanda.com/locos/locos_subsite/locos_gallery.html

local scene = {}

local render = require 'lib.render'
local mesh = require 'lib.mesh'
local parentize = require 'lib.parentize'

local node = require 'lib.node'
local parse = require 'lib.parse-file'
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
myWorld:addSystems(Systems.BasicSystem)

local function makeContainerFolder(name)
   return {
      folder = true,
      name = name,
      transforms = { l = { 0, 0, 0, 1, 1, 0, 0, 0, 0 } },
      children = {}
   }
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

-- todo
function addChildBefore(beforeThis, elem)
   local p = beforeThis._parent
   local index = node.getIndex(beforeThis)
   elem._parent = p
   table.insert(p.children, index, elem)

end

function createRubberHoseFromImage(url)
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
   currentNode.data.flop = 1
   currentNode.data.borderRadius = .25
   currentNode.data.steps = 20
   currentNode.color = { 0, 0, 0 }
   currentNode.data.scale = 1
   --      currentNode.data.scaleY = 2
   currentNode.points = { { 0, 0 }, { 0, height / 2 } }
   mesh.remeshNode(currentNode)
   return currentNode
end

function makeDynamicCanvas(canvas, mesh)
   local w, h = canvas:getDimensions()
   local w2 = w / 2
   local h2 = h / 2




   local result = {}
   result.color = { 1, 1, 1 }
   result.name = 'generated'
   result.points = { { -w2, -h2 }, { w2, -h2 }, { w2, h2 }, { -w2, h2 } }
   result.texture = {
      filter = "linear",
      canvas = mesh,
      wrap = "repeat"
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
   grunge = love.graphics.newImage('assets/layered/ice.jpg')
   grunge2 = love.graphics.newImage('assets/layered/grunge.png')
   texture1 = love.graphics.newImage('assets/layered/texture-type1.png')
   blup1 = love.graphics.newImage('assets/blup1.png')
   blup2 = love.graphics.newImage('assets/blup5.png')



   m = 0
   tx = 0
   ty = 0
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
   leg1 = createRubberHoseFromImage('assets/parts/line1.png')
   leg2 = createRubberHoseFromImage('assets/parts/line2.png')


   root.children = { body, leg1, leg2 }

   stripPath(root, '/experiments/puppet%-maker/')


   parentize.parentize(root)
   mesh.meshAll(root)
   mesh.recursivelyMakeTextures(root)
   render.renderThings(root)

   -- shoul
   canvas = makeTexturedCanvas(canvas,
      lineart, mask,
      grunge2, { vivid.HSLtoRGB(skinBackHSL) },
      texture1, { vivid.HSLtoRGB(skinFurHSL) })



   local romp = node.findNodeByName(body, 'romp')
   local m = makeMeshFromSibling(romp, canvas)
   local dynamic = makeDynamicCanvas(canvas, m)

   addChildBefore(romp, dynamic)

   --print(inspect(romp))




   --addChildAt(body, dynamic, 1)


   --[[
   transforms.setTransforms(root)
   transforms.setTransforms(body)

   local leg1connector = node.findNodeByName(body, 'leg1')

   print(inspect(leg1connector))
   --print(mesh.getImage('assets/parts/line1.png'))
   leg1 = createRubberHoseFromImage('assets/parts/line1.png')

   local dx1, dy1 = body.transforms._g:transformPoint(leg1connector.points[1][1], leg1connector.points[1][2])

   leg1.points[1][1] = dx1
   leg1.points[1][2] = dy1

   leg1.data.flop = -1
   mesh.remeshNode(leg1)

   leg2 = createRubberHoseFromImage('assets/parts/line2.png')
   local leg2connector = node.findNodeByName(body, 'leg2')
   local dx1, dy1 = body.transforms._g:transformPoint(leg2connector.points[1][1], leg1connector.points[1][2])

   leg2.points[1][1] = dx1
   leg2.points[1][2] = dy1


   --print(inspect(body))
   root.children = { body, leg1, leg2 }
   parentize.parentize(root)
   render.renderThings(root)

   -- al lot of charcaters int he replcace string need escaping
   local function replace(str, what, with)
      what = string.gsub(what, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1") -- escape pattern
      with = string.gsub(with, "[%%]", "%%%%") -- escape replacement
      return string.gsub(str, what, with)
   end

   local path = 'experiments/puppet-maker/'
   print(string.gsub(path, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")) -- this generates the % in the right place
   --print(replace(path))
   stripPath(root, '/experiments/puppet%-maker/')
   --table.insert(root.children, body)



   canvas = makeTexturedCanvas(canvas,
      lineart, mask,
      grunge2, { vivid.HSLtoRGB(skinBackHSL) },
      texture1, { vivid.HSLtoRGB(skinFurHSL) })

   local dynamic = makeDynamicCanvas(canvas)

   addChildAt(body, dynamic, 1)
   --print(inspect(body.transforms.g))
   --print(inspect(body.transforms))
   --print(inspect(body))


   --foregroundLayer.children = again


   parentize.parentize(root)
   mesh.meshAll(root)
   mesh.recursivelyMakeTextures(root)
   --mesh.recursivelyAddOptimizedMesh(foregroundLayer)

   attachCallbacks()

   local myEntity = Concord.entity()
   myEntity
       :give('basic')
       :give('texturedBody', lineart, mask, grunge2)

   print(myWorld)
   myWorld:addEntity(myEntity)

   local w, h = love.graphics.getDimensions()





   transforms.setTransforms(root)
   transforms.setTransforms(body)
   -- transforms.setTransforms(leg1)
   local bx, by = body.transforms._g:transformPoint(0, 0)
   --print(bx, by)
   camera.setCameraViewport(cam, w, h)
   camera.centerCameraOnPosition(bx, by, w, lh * 2)
   cam:update(w, h)

   function recursiveCheck(node)
      if node.points then
         print(node.name, inspect(node.points))
      end
      if node.children then
         for i = 1, #node.children do
            recursiveCheck(node.children[i])
         end
      end

   end

   recursiveCheck(root)
--]]

   attachCallbacks()

   local bx, by = body.transforms._g:transformPoint(0, 0)
   local w, h = love.graphics.getDimensions()
   camera.setCameraViewport(cam, w, h)
   camera.centerCameraOnPosition(bx, by, w, lh * 2)
   cam:update(w, h)

end

function attachCallbacks()
   function love.keypressed(key, unicode)
      if key == 'escape' then love.event.quit() end

   end

   function love.touchpressed(key, unicode)

   end

   function love.mousepressed(key, unicode)

   end

   function love.mousemoved(x, y, dx, dy)
      --print('yoyo')
      if love.mouse.isDown(1) then
         tx = tx + dx
         ty = ty + dy
      end

   end

   function love.resize(w, h)
      local lw, lh = lineart:getDimensions()



      local bx, by = body.transforms._g:transformPoint(0, 0)
      local w, h = love.graphics.getDimensions()
      camera.setCameraViewport(cam, w, h)
      camera.centerCameraOnPosition(bx, by, w, lh * 2)
      cam:update(w, h)


   end
end

function scene.update(dt)
   if introSound:isPlaying() then
      local volume = introSound:getVolume()
      introSound:setVolume(volume * .90)
      if (volume < 0) then
         introSound:stop()
      end
   end

   --leg2.points[2][1] = love.math.random() * 800
   --leg2.points[2][2] = love.math.random() * 800
   --mesh.remeshNode(leg2)


   delta = delta + dt
   Timer.update(dt)
   myWorld:emit("update", dt)

end

function love.mousereleased()
   lastDraggedElement = nil
end

-- hallo obs does this work ?
-- ok i havent seen it working, does it work now?
-- why wasnt it working, does it just need more time or something ?
--  still no joy, this is gonna be something?

function drawUI()
   local stats = love.graphics.getStats()
   --print('img mem', stats.texturememory)
   --  print('Memory actually used (in kB): ' .. collectgarbage('count'))

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

   ui.handleMouseClickStart()
   love.graphics.clear(bgColor)
   love.graphics.setColor(0, 0, 0)
   love.graphics.print("Let's create the layered furry skin thing", 400, 10)

   cam:push()
   render.renderThings(root)
   cam:pop()
   drawUI()
end

return scene

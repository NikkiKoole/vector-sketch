-- https://medium.com/@chrisgaul/https-medium-com-chrisgaul-is-this-language-without-letters-the-future-of-global-communication-15fc54909c12
-- http://bamanda.com/locos/locos_subsite/locos_gallery.html

local scene = {}

local render = require 'lib.render'
local mesh = require 'lib.mesh'
local parentize = require 'lib.parentize'

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
   --print(root, root.children)
   --    print(inspect(root))
   if root and root.texture and #root.texture.url > 0 then
      local str = root.texture.url
      local shortened = string.gsub(str, path, '')
      root.texture.url = shortened
      print(shortened)
      --print(str, path, str2)

   end
   if root.children then
      for i = 1, #root.children do
         stripPath(root.children[i], path)
      end
   end
   return root
end

function recursiveStripPath(root, path)

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

   --skinFurHSL = {vivid.RGBtoHSL( 0.89, 0.388, 0.294)}

   --print(inspect(skinBackHSL))
   --redB = 154/255
   delta = 0
   --foregroundLayer = makeContainerFolder('foregroundLayer')
   root = {
      folder = true,
      name = 'root',
      transforms = { l = { 0, 0, 0, 1, 1, 0, 0 } },
      children = {}
   }

   body = parse.parseFile('assets/body.polygons.txt')[1]

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
      currentNode.data.steps = 10
      currentNode.color = { 0.094, 0.102, 0.09, 1 }
      currentNode.data.scale = 1
      --      currentNode.data.scaleY = 2
      currentNode.points = { { 0, 0 }, { 0, height / 1.5 } }
      mesh.remeshNode(currentNode)
      return currentNode
   end

   --print(mesh.getImage('assets/parts/line1.png'))
   leg1 = createRubberHoseFromImage('assets/parts/line1.png')
   leg1.points[1][1] = -100
   leg1.points[2][1] = -100
   leg1.data.flop = -1
   mesh.remeshNode(leg1)
   leg2 = createRubberHoseFromImage('assets/parts/line2.png')

   --print(inspect(body))
   root.children = { body, leg1, leg2 }


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

   --local sx, sy = cam:getScreenCoordinates(-512, -768 / 2)
   transforms.setTransforms(root)
   transforms.setTransforms(body)
   local dx, dy = body.transforms._g:transformPoint(0, 0)
   print(dx, dy)
   --transforms.setTransforms(foregroundLayer.children[1])
   --transforms.setTransforms(foregroundLayer.children[1].children[1])
   --local ax, ay = foregroundLayer.children[1].children[1].transforms._g:inverseTransformPoint(0, 0)
   --print(ax, ay)
   --local wx, wy = cam:getScreenCoordinates(0, 0)
   --print(wx, wy)
   --camera.setCameraViewport(cam, w, h)
   --camera.centerCameraOnPosition(ax, ay, w, h)

   print(inspect(body.transforms))
   camera.setCameraViewport(cam, w, h)
   camera.centerCameraOnPosition(dx, dy, w, h * 2)
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
      --local w, h = love.graphics.getDimensions()
      print(w, h)

      camera.setCameraViewport(cam, w, h)
      camera.centerCameraOnPosition(0, 0, w, h)
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

   delta = delta + dt
   Timer.update(dt)
   myWorld:emit("update", dt)
end

local mask_effect = love.graphics.newShader [[
   vec4 effect (vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
      if (Texel(texture, texture_coords).rgb == vec3(0.0)) {
         // a discarded pixel wont be applied as the stencil.
         discard;
      }
      return vec4(1.0);
   }
]]
function myStencilFunction(mask)
   love.graphics.setShader(mask_effect)
   love.graphics.draw(mask, 0, 0)
   love.graphics.setShader()
end

function love.mousereleased()
   lastDraggedElement = nil
end

function calculateLargestRect(angle, origWidth, origHeight)
   local w0, h0;
   if (origWidth <= origHeight) then
      w0 = origWidth;
      h0 = origHeight;

   else
      w0 = origHeight;
      h0 = origWidth;
   end

   --// Angle normalization in range [-PI..PI)
   local ang = angle - math.floor((angle + math.pi) / (2 * math.pi)) * 2 * math.pi;
   ang = math.abs(ang);
   if (ang > math.pi / 2) then
      ang = math.pi - ang
   end

   local sina = math.sin(ang);
   local cosa = math.cos(ang);
   local sinAcosA = sina * cosa;
   local w1 = w0 * cosa + h0 * sina;
   local h1 = w0 * sina + h0 * cosa;
   local c = h0 * sinAcosA / (2 * h0 * sinAcosA + w0);
   local x = w1 * c;
   local y = h1 * c;
   local w, h;
   if (origWidth <= origHeight) then
      w = w1 - 2 * x;
      h = h1 - 2 * y;

   else
      w = h1 - 2 * y;
      h = w1 - 2 * x;
   end

   return x, y, w, h
end

-- hallo obs does this work ?
-- ok i havent seen it working, does it work now?
-- why wasnt it working, does it just need more time or something ?
--  still no joy, this is gonna be something?

function drawUI()
   local stats = love.graphics.getStats()
   --   print('img mem', stats.texturememory)
   --   print('Memory actually used (in kB): ' .. collectgarbage('count'))

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

-- make order the same as the
function makeTexturedCanvas(lw, lh, texture, mask, color, canvas)
   love.graphics.setCanvas({ canvas, stencil = true }) --<<<
   love.graphics.clear(0, 0, 0, 0) ---<<<<
   love.graphics.setBlendMode("alpha") ---<<<<
   love.graphics.setStencilTest("greater", 0)
   love.graphics.stencil(function() myStencilFunction(mask) end)

   --local ow, oh = grunge:getDimensions()
   local gw, gh = texture:getDimensions()
   local rotation = 0 --delta
   local rx, ry, rw, rh = calculateLargestRect(rotation, gw, gh)

   local scaleX = .5
   local scaleY = .5

   local xMin = lw + -((gw / 2) * scaleX) + (rx * scaleX)
   local xMax = (gw / 2) * scaleX - (ry * scaleX)
   local xOffset = xMin

   local yMin = lh + -((gh / 2) * scaleY) + (rx * scaleY)
   local yMax = (gh / 2) * scaleY - (ry * scaleY)
   local yOffset = yMin

   love.graphics.setColor(color)
   love.graphics.draw(texture, xOffset, yOffset, rotation, scaleX, scaleY, gw / 2, gh / 2)

   -- second texture
   local gw, gh = texture1:getDimensions()
   local rotation = 0 --delta
   local rx, ry, rw, rh = calculateLargestRect(rotation, gw, gh)

   local scaleX = 2
   local scaleY = 2

   local xMin = lw + -((gw / 2) * scaleX) + (rx * scaleX)
   local xMax = (gw / 2) * scaleX - (ry * scaleX)
   local xOffset = xMin

   local yMin = lh + -((gh / 2) * scaleY) + (rx * scaleY)
   local yMax = (gh / 2) * scaleY - (ry * scaleY)
   local yOffset = yMin



   -- height of these images is not big enough, redraw them bigger lazy bum

   love.graphics.setColor({ vivid.HSLtoRGB(skinBackHSL) })
   love.graphics.setColor(1, 1, 1)

   love.graphics.draw(texture1, xOffset, yOffset, rotation, scaleX, scaleY, gw / 2, gh / 2)

   --love.graphics.draw(texture1, m*-maxT1Width,0,0,1.5,1.5)


   love.graphics.setStencilTest()


   love.graphics.setCanvas() --- <<<<<
   return canvas
end

function scene.draw()

   ui.handleMouseClickStart()
   love.graphics.clear(bgColor)
   love.graphics.setColor(0, 0, 0)
   love.graphics.print("Let's create the layered furry skin thing", 400, 10)



   local lw, lh = lineart:getDimensions()
   canvas = makeTexturedCanvas(lw, lh, grunge2, mask, { vivid.HSLtoRGB(skinBackHSL) }, canvas)

   cam:push()
   love.graphics.setColor(1, 1, 1)
   love.graphics.draw(canvas)

   love.graphics.setColor({ vivid.HSLtoRGB(skinFurHSL) })
   --love.graphics.draw(lineart)


   render.renderThings(root)
   cam:pop()
   --drawUI()
end

return scene

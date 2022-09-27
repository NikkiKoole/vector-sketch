package.path = package.path .. ";../../?.lua"


require 'lib.generate-polygon'
require 'lib.camera'

inspect = require 'vendor.inspect'
flux = require "vendor.flux"

--require 'src.mesh'
require 'src.outwardRectangle'

Concord = require 'vendor.concord.init'

local mesh = require 'lib.mesh'
local parentize = require 'lib.parentize'
local mesh = require 'lib.mesh'
local render = require 'lib.render'

local myWorld = Concord.world()
local cam = require('lib.cameraBase').getInstance()
--local cam = getCamera()
--[[
   the process of geting the right handdrawn images
   draw an image with pencil, the size of my hand is roughly the size of a person
   scan this in, black and white 200 dpi, PNG
   in gimp, add alpha layer, convert white to transparent
   resize the image to 50%

   pushing them through https://tinypng.com/  shaves a lot off.
   https://www.imgonline.com.ua/eng/make-seamless-texture.php

   this breaks the alpha layer though so put them through experiments/alpha-padder afterwards

   -- inflate polygon
   https://stackoverflow.com/questions/1109536/an-algorithm-for-inflating-deflating-offsetting-buffering-polygons

]]
--

function centerCameraOnPosition(x, y, vw, vh)
   local cw, ch = cam:getContainerDimensions()
   local targetScale = math.min(cw / vw, ch / vh)
   cam:setScale(targetScale)
   --cam:setTranslation(x + vw/2, y + vh/2)
   cam:setTranslation(x, y)
end

function makeNode(graphic, tl)
   local tl = tl or { 0, 0, 0, 1, 1, graphic.w / 2, graphic.h, 0, 0 }
   return {
      _parent = nil,
      children = {},
      graphic = graphic,
      dirty = true,
      -- x, y, angle, sx, sy, ox, oy, kx, ky
      transforms = { tl = tl,
         l = love.math.newTransform(tl[1], tl[2], tl[3], tl[4], tl[5], tl[6], tl[7], tl[8], tl[9]) }
   }
end

function addChild(parent, node)
   node._parent = parent
   table.insert(parent.children, node)
end

--- is this a doc
-- @ asoapsoj

function makeGraphic(path)
   local imageData = love.image.newImageData(path)
   local img = love.graphics.newImage(imageData, { mipmaps = true })
   img:setMipmapFilter('nearest', 0)
   local m = mesh.createTexturedRectangle(img)
   local w, h = m:getTexture():getDimensions()

   return { imageData = imageData, img = img, mesh = m, path = path, w = w, h = h }
end

function love.mousemoved(x, y, dx, dy)
   if love.mouse.isDown(1) then
      local s = cam:getScale()
      cam:translate(-dx / s, -dy / s)
   end

end

function love.keypressed(key)
   if key == "escape" then love.event.quit() end

   if key == 'up' then
      cam:translate(0, -5)
   end
   if key == 'down' then
      cam:translate(0, 5)
   end
   if key == 'left' then
      cam:translate(-5, 0)
   end
   if key == 'right' then
      cam:translate(5, 0)
   end
   love.keyboard.setKeyRepeat(true)

end

function love.load()
   --require("vendor.lurker").path = '../..'

   --cam = getCamera()--createCamera()

   depthMinMax = { min = -1.0, max = 1.0 }
   -- foregroundFactors = { far=.5, near=1}
   --backgroundFactors = { far=.4, near=.7}
   tileSize = 400


   --backgroundFar = generateCameraLayer('backgroundFar', backgroundFactors.far)
   --backgroundNear = generateCameraLayer('backgroundNear', backgroundFactors.near)
   foregroundFar = generateCameraLayer('foregroundFar', .1)
   foregroundNear = generateCameraLayer('foregroundNear', 1)
   --   foregroundNearer = generateCameraLayer('foregroundNearer', .7)
   --   foregroundNearer = generateCameraLayer('foregroundNearest', 1.2)

   --dynamic = generateCameraLayer('dynamic', 1)

   --animals =  makeGraphic('assets/animals4.png')
   --dogmanhaar =  makeGraphic('assets/dogmanhaar.png')

   groundimg1 = love.graphics.newImage('assets/blub1b.png', { mipmaps = true })
   groundimg1:setWrap('repeat')
   groundimg2 = love.graphics.newImage('assets/blub2.png', { mipmaps = true })
   groundimg3 = love.graphics.newImage('assets/blub3.png', { mipmaps = true })
   groundimg4 = love.graphics.newImage('assets/blub4.png', { mipmaps = true })
   groundimg5 = love.graphics.newImage('assets/blub5.png', { mipmaps = true })
   groundimg6 = love.graphics.newImage('assets/ground1.png', { mipmaps = true })
   groundimg6b = love.graphics.newImage('assets/ground1.png', { mipmaps = true })

   groundimg7 = love.graphics.newImage('assets/ground2.png', { mipmaps = true })
   groundimg8 = love.graphics.newImage('assets/ground3.png', { mipmaps = true })
   groundimg9 = love.graphics.newImage('assets/ground4.png', { mipmaps = true })
   groundimg10 = love.graphics.newImage('assets/ground5.png', { mipmaps = true })
   groundimg11 = love.graphics.newImage('assets/ground6.png', { mipmaps = true })
   groundimg12 = love.graphics.newImage('assets/ground7.png', { mipmaps = true })
   groundimg13 = love.graphics.newImage('assets/ground8.png', { mipmaps = true })

   ding = love.graphics.newImage('assets/ground52.png', { mipmaps = true })


   -- groundimg = makeGraphic('assets/kleed2.jpg')

   root = makeNode(nil, { 0, 0, 0, 1, 1, 0, 0, 0, 0 })




   local ani = {
      children = { {
         color = { 1, 1, 1, 1 },
         data = {
            steps = 15,
            width = 178.5
         },
         name = "plant1",
         points = { { 0, 0 }, { 0, 311.5 }, { 0, 623 } },
         texture = {
            filter = "linear",
            squishable = true,
            url = "assets/plant.png",
            wrap = "clamp"
         },
         type = "bezier"
      } },
      folder = true,
      name = "plant container",
      transforms = {
         l = { 0, 0, 0, 1, 1, 100, 0, 0, 0 }
      }
   }

   addChild(root, ani)

   -- ]]--




   local animals1 = makeNode(makeGraphic('assets/animals3.png'))
   local animals2 = makeNode(makeGraphic('assets/plant.png'))

   animals2.transforms.tl[1] = animals2.transforms.tl[1]
   --animals2.transforms.l:translate(400,0)
   --addChild(animals1, animals2)
   addChild(root, animals1)
   parentize.parentize(root)
   mesh.recursivelyMakeTextures(root)
   mesh.meshAll(root)


   centerCameraOnPosition(150, -500, 1200, 1200)
   count = 0


   p = generatePolygon(200, 200, 1000, .15, .15, 14)
   d = mesh.createTexturedPolygon(groundimg1, p)
   totaldt = 0

   heights = {}
   for i = -1000, 1000 do
      heights[i] = love.math.random() * 100
   end

   love.window.setTitle('handdrawn joy')
end

function love.update(dt)
   require("vendor.lovebird").update()
   require("vendor.lurker").update()
   myWorld:emit("update", dt)
   manageCameraTween(dt)
   cam:update()

   updateBlobShape()
   totaldt = totaldt + dt

end

function love.wheelmoved(dx, dy)
   local newScale = cam.scale * (1 + dy / 10)
   if (newScale > 0.01 and newScale < 50) then
      cam:scaleToPoint(1 + dy / 10)
   end
end

function updateBlobShape()
   if totaldt % 2 < 0.1 then
      p = generatePolygon(200, 200, 1200, .15, .15, 14)
      d = mesh.createTexturedPolygon(groundimg1, p)
   end
end

function love.resize(w, h)
   setCameraViewport(cam, 100, 100)
   --   centerCameraOnPosition(50,50, 200,200)
   centerCameraOnPosition(150, 150, 600, 600)
   cam:update(w, h)
end

function updateTransformsRecursive(node, dirty)

end

function renderRecursive(node, dirty)
   -- if we get a dirty tag somewhere, that means all transforms from that point on need to be redone

   local isDirty = dirty or node.dirty
   --setTransforms(node)


   if isDirty then
      local tl = node.transforms.tl
      node.transforms.l = love.math.newTransform(tl[1], tl[2], tl[3], tl[4], tl[5], tl[6], tl[7], tl[8], tl[9])
      if (node._parent) then
         node.transforms.g = node._parent.transforms.g * node.transforms.l
      else
         node.transforms.g = node.transforms.l
      end
      node.dirty = false
   else

   end

   -- todo this logic needs to be moved into the general code, but what is a graphics really ?
   -- something with a texture urll ?
   if node.graphic then

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


      love.graphics.draw(node.graphic.mesh, node.transforms.g)
   end

   for i = 1, #node.children do
      renderRecursive(node.children[i], isDirty)
   end


end

function drawGroundPlaneLinesSimple(cam, far, near)

   love.graphics.setColor(1, 1, 1)
   love.graphics.setLineWidth(2)
   local W, H = love.graphics.getDimensions()

   local x1, y1 = cam:getWorldCoordinates(0, 0, far)
   local x2, y2 = cam:getWorldCoordinates(W, 0, far)

   local s = math.floor(x1 / tileSize) * tileSize
   local e = math.ceil(x2 / tileSize) * tileSize

   --[[
   local imgarr = {groundimg1, groundimg2, groundimg3, groundimg4, groundimg5,
                   groundimg6, groundimg7, groundimg8, groundimg9, groundimg10,
                   groundimg10, groundimg11, groundimg12,groundimg12,groundimg12,
                   groundimg12,groundimg13,groundimg13,groundimg13}
   ]] --
   local imgarr = { groundimg6b, groundimg3, groundimg8, groundimg9, groundimg10 }

   local woohoo = 1

   for i = s, e, tileSize do
      local groundIndex = (i / tileSize)
      local tileIndex = (groundIndex % (#imgarr)) + 1
      --      print(tileIndex)
      local index = (i - s) / tileSize
      local height1 = heights[groundIndex]
      local height2 = heights[groundIndex + 1]
      local s = cam:getScale() -- 50 -> 0.01


      local x4, y4 = cam:getScreenCoordinates(i + 0.0001, height1 * woohoo, near)
      local x3, y3 = cam:getScreenCoordinates(i + tileSize + .0001, height2 * woohoo, near)
      local x1, y1 = x4, y4 - s * tileSize
      local x2, y2 = x3, y3 - s * tileSize

      local m = mesh.createTexturedRectangle(imgarr[tileIndex])

      m:setVertex(1, { x1, y1, 0, 0, 1, 1, 1, .5 })
      m:setVertex(2, { x2, y2, 1, 0, 1, 1, 1, .5 })
      m:setVertex(3, { x3, y3, 1, 1 })
      m:setVertex(4, { x4, y4, 0, 1 })

      love.graphics.setColor(.3, 0.3, 0.3, 0.6)
      love.graphics.draw(m)

      local o = 200
      m:setVertex(1, { x1, y1 + o, 0, 0, 1, 1, 1, .5 })
      m:setVertex(2, { x2, y2 + o, 1, 0, 1, 1, 1, .5 })
      m:setVertex(3, { x3, y3 + o, 1, 1 })
      m:setVertex(4, { x4, y4 + o, 0, 1 })

      local newuvs = { .05, .08, -- tl x and y}
         .92, .95 - .09 } --width and height

      local rect1 = { x1, y1, x2, y2, x3, y3, x4, y4 }
      local outward = coloredOutsideTheLines(rect1, newuvs)

      local m = mesh.createTexturedRectangle(ding)
      m:setVertex(1, { outward[1], outward[2], 0, 0 })
      m:setVertex(2, { outward[3], outward[4], 1, 0 })
      m:setVertex(3, { outward[5], outward[6], 1, 1 })
      m:setVertex(4, { outward[7], outward[8], 0, 1 })


      love.graphics.setColor(168 / 255, 175 / 255, 97 / 255, 0.6)
      love.graphics.draw(m)

   end
end

function love.draw()
   love.graphics.clear(.3, .5, .8)
   drawGroundPlaneLinesSimple(cam, 'foregroundFar', 'foregroundNear')

   cam:push()
   love.graphics.setColor(1, 1, 1)
   love.graphics.draw(d)

   render.renderThings(root)
   --renderRecursive(root)

   love.graphics.setColor(1, 1, 1)
   love.graphics.setColor(1, 0, 0)
   love.graphics.rectangle('fill', 0, 0, 20, 20)

   cam:pop()


   love.graphics.setColor(1, 1, 1)
   love.graphics.print("Current FPS: " .. tostring(love.timer.getFPS()), 10, 10)
   love.graphics.print(inspect(love.graphics.getStats()), 10, 40)
   love.graphics.print('Memory actually used (in kB): ' .. collectgarbage('count'), 400, 40)
end

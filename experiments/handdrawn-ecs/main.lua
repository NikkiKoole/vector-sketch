package.path = package.path .. ";../../?.lua"

Camera = require 'custom-vendor.brady'

require 'lib.scene-graph'
require 'lib.generate-polygon'
require 'lib.bbox'

require 'lib.editor-utils'
require 'lib.poly'
require 'lib.basics'
require 'lib.main-utils'
require 'lib.toolbox'

inspect = require 'vendor.inspect'
flux = require "vendor.flux"

require 'src.camera'
require 'src.mesh'

Concord = require 'vendor.concord.init'

local myWorld = Concord.world()

--[[
   the process of geting the right handdrawn images
   draw an image with pencil, the size of my hand is roughly the size of a person
   scan this in, black and white 200 dpi, PNG
   in gimp, add alpha layer, convert white to transparent
   resize the image to 50%

   pushing them through https://tinypng.com/  shaves a lot off.
   https://www.imgonline.com.ua/eng/make-seamless-texture.php
]]--


function centerCameraOnPosition(x,y,vw, vh)
   local cw, ch = cam:getContainerDimensions()
   local targetScale = math.min(cw/vw, ch/vh)
   cam:setScale(targetScale)
   --cam:setTranslation(x + vw/2, y + vh/2)
   cam:setTranslation(x , y)
end



function makeNode(graphic, tl)
   local tl = tl or {0, 0, 0, 1, 1, graphic.w/2, graphic.h, 0, 0}
   return {
      _parent = nil,
      children = {},
      graphic = graphic,
      dirty = true,
      -- x, y, angle, sx, sy, ox, oy, kx, ky
      transforms = {tl = tl,
		    l = love.math.newTransform(tl[1], tl[2], tl[3], tl[4], tl[5], tl[6], tl[7], tl[8], tl[9])}
   }
end


function addChild(parent, node)
   node._parent = parent
   table.insert(parent.children, node)
end



function makeGraphic(path)
   local imageData = love.image.newImageData( path )
   local img = love.graphics.newImage(imageData, {mipmaps=true})
   img:setMipmapFilter('nearest', 0)
   local mesh = createTexturedRectangle(img)
   local w,h = mesh:getTexture():getDimensions()
   -- x, y, angle, sx, sy, ox, oy, kx, ky

   return {imageData=imageData, img=img,  mesh=mesh, path=path, w=w, h=h}
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
   love.keyboard.setKeyRepeat( true )

end


function love.load()


   cam = createCamera()

   depthMinMax =       {min=-1.0, max=1.0}
   foregroundFactors = { far=.5, near=1}
   --backgroundFactors = { far=.4, near=.7}
   tileSize = 800


   --backgroundFar = generateCameraLayer('backgroundFar', backgroundFactors.far)
   --backgroundNear = generateCameraLayer('backgroundNear', backgroundFactors.near)
   foregroundFar = generateCameraLayer('foregroundFar', foregroundFactors.far)
   foregroundNear = generateCameraLayer('foregroundNear', foregroundFactors.near)

   --dynamic = generateCameraLayer('dynamic', 1)

   --animals =  makeGraphic('assets/animals4.png')
   --dogmanhaar =  makeGraphic('assets/dogmanhaar.png')

   groundimg1 = love.graphics.newImage('assets/blub1.png', {mipmaps=true})
   groundimg2 = love.graphics.newImage('assets/blub2.png', {mipmaps=true})
   groundimg3 = love.graphics.newImage('assets/blub3.png', {mipmaps=true})
   groundimg4 = love.graphics.newImage('assets/blub4.png', {mipmaps=true})
   groundimg5 = love.graphics.newImage('assets/blub5.png', {mipmaps=true})
   groundimg6 = love.graphics.newImage('assets/ground1.png', {mipmaps=true})
   groundimg6b = love.graphics.newImage('assets/ground1b.png', {mipmaps=true})

   groundimg7 = love.graphics.newImage('assets/ground2.png', {mipmaps=true})
   groundimg8 = love.graphics.newImage('assets/ground3.png', {mipmaps=true})
   groundimg9 = love.graphics.newImage('assets/ground4.png', {mipmaps=true})
   groundimg10 = love.graphics.newImage('assets/ground5.png', {mipmaps=true})
   groundimg11 = love.graphics.newImage('assets/ground6.png', {mipmaps=true})
   groundimg12 = love.graphics.newImage('assets/ground7.png', {mipmaps=true})
   groundimg13 = love.graphics.newImage('assets/ground8.png', {mipmaps=true})

   
   -- groundimg = makeGraphic('assets/kleed2.jpg')
   
   root = makeNode(nil,  { 0, 0, 0, 1, 1, 0, 0, 0, 0 })

   local animals1 =  makeNode(makeGraphic('assets/animals4.png'))
   local animals2 =  makeNode(makeGraphic('assets/animals4.png'))

   animals2.transforms.tl[1] = animals2.transforms.tl[1]
   --animals2.transforms.l:translate(400,0)
   addChild(root, animals1)
   addChild(animals1, animals2)
   
   --addNodeTo(animals, root)
   --addNodeTo(dogmanhaar, animals)
   


   
   
   --setCameraViewport(cam, 100,100)
   centerCameraOnPosition(150,-500, 1200,1200)

   count = 0


   p = generatePolygon(200,200,300,0,5,14)
   d = createTexturedPolygon(groundimg1, p)


   love.window.setTitle( 'handdrawn joy' )
end

function love.update(dt)
   myWorld:emit("update", dt)
   manageCameraTween(dt)
   cam:update()



   --root.transforms.tl[3] = root.transforms.tl[3] + 1 * dt

   --root.transforms.l:rotate(count )

   --root.children[1].children[1].transforms.tl[3] = root.children[1].children[1].transforms.tl[3] - 1*dt
   --root.dirty = true
   
end

function love.wheelmoved( dx, dy )
   local newScale = cam.scale * (1 + dy / 10)
   if (newScale > 0.01 and newScale < 50) then
      cam:scaleToPoint(  1 + dy / 10)
   end
end



function love.resize(w, h)
   setCameraViewport(cam, 100,100)
   --   centerCameraOnPosition(50,50, 200,200)
   centerCameraOnPosition(150,150, 600,600)
   cam:update(w,h)
end


function updateTransformsRecursive(node, dirty)
   
end


function renderRecursive(node, dirty)
   -- if we get a dirty tag somewhere, that means all transforms from that point on need to be redone

   local isDirty = dirty or node.dirty

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

   if node.graphic then

      local mx, my = love.mouse.getPosition()
      local wx, wy = cam:getWorldCoordinates(mx, my)
      local xx, yy = node.transforms.g:inverseTransformPoint(wx, wy )
      love.graphics.setColor(0,0,0)
      if (xx > 0 and xx < node.graphic.w and yy >0 and yy< node.graphic.h) then
	 love.graphics.setColor(.25,.25,.25)
	 local r, g, b, a = node.graphic.imageData:getPixel( xx, yy )
	 if (a > 0) then
	    love.graphics.setColor(.25,.25,.5)
	 end
      end

      
      love.graphics.draw(node.graphic.mesh, node.transforms.g)
   end
   
   for i =1, #node.children do
      renderRecursive(node.children[i], isDirty)
   end
   
   
end


function drawGroundPlaneLinesSimple(cam, far, near)

   love.graphics.setColor(1,1,1)
   love.graphics.setLineWidth(2)
   local W, H = love.graphics.getDimensions()

   local x1,y1 = cam:getWorldCoordinates(0,0, far)
   local x2,y2 = cam:getWorldCoordinates(W,0, far)

   local s = math.floor(x1/tileSize)*tileSize
   local e = math.ceil(x2/tileSize)*tileSize

   local imgarr = {groundimg1, groundimg2, groundimg3, groundimg4, groundimg5,
                   groundimg6, groundimg7, groundimg8, groundimg9, groundimg10,
                   groundimg10, groundimg11, groundimg12,groundimg12,groundimg12,
                   groundimg12,groundimg13,groundimg13,groundimg13}

   local imgarr = {groundimg6b, groundimg6b}

   for i = s, e, tileSize do
      local groundIndex = (i/tileSize)

      local tileIndex = (groundIndex % (#imgarr)) + 1
--      print(tileIndex)
      local index = (i - s)/tileSize
      local height1 = 0
      local height2 = 0

      local s = cam:getScale() -- 50 -> 0.01
      
      --local v = mapInto(cam:getScale(), 0, 50, 0.9, 1)
      --local ffar = {scale=0.9, relativeScale=1}
      --local fnear = {scale=1, relativeScale=1}

      local x1,y1 = cam:getScreenCoordinates(i+0.0001, height1, far)
      local x2,y2 = cam:getScreenCoordinates(i+0.0001, 0, near)

      
      local x3, y3 = cam:getScreenCoordinates(i+tileSize + .0001, height2, far)
      local x4, y4 = cam:getScreenCoordinates(i+tileSize+ .0001, 0, near)

--      y2 = y2+tileIndex-50
--      y4 = y4+tileIndex*50
      
      local x1,y1 = x2, y2-s*tileSize/1

      local x3,y3 = x4, y4-s*tileSize/1


      


      local mesh = createTexturedRectangle(imgarr[tileIndex])

   --   mesh:setVertex(1, {x1,y1, 0.5,0.5,1,1,1})

      mesh:setVertex(1, {x1,y1, 0,0,1,1,1,.5})
      mesh:setVertex(2, {x3,y3, 1,0,1,1,1,.5})
      mesh:setVertex(3, {x4,y4, 1,1})
      mesh:setVertex(4, {x2,y2, 0,1})

     -- mesh:setVertex(6, {x1,y1, 0,0,.5,.5,1})

      love.graphics.setColor(.6,0.3,0.15,0.9)

      love.graphics.polygon('line', p)
      love.graphics.draw(mesh)
      
      --love.graphics.setColor(0.25,1-(0.05*tileIndex),0.25,.5)
      --love.graphics.polygon("fill", {x1,y1, x3,y3,x4,y4,x2,y2})
      ---love.graphics.setColor(0.25,.5,0.25)

      --love.graphics.line(x1,y1, x2,y2)
      --love.graphics.line(x1,y1, x3,y3)
   end
end


function love.draw()
   love.graphics.clear(.3,.5,.8)
   
   
   
   
   --root.transforms.l:setTransformation( 0,0,count )
   
   --root.children[1].dirty = true

   -- root.children[1].children[1].transforms.l:rotate( -count )
   --  root.children[1].children[1].dirty = true
   drawGroundPlaneLinesSimple( cam, 'foregroundFar', 'foregroundNear')
   cam:push()

   renderRecursive(root)

   -- render a textured polygon

--   local poly = {}
--   poly = p
--   print(inspect(poly))

   -- love.graphics.polygon('line', poly)
   love.graphics.setColor(1,1,1)
   love.graphics.draw(d)
   love.graphics.setColor(1,0,0)
   love.graphics.rectangle('fill', 0, 0, 20,20)
   
   cam:pop()
   love.graphics.setColor(1,1,1)
   love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)
   love.graphics.print(inspect(love.graphics.getStats()), 10, 40)
end


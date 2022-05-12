package.path = package.path .. ";../../?.lua"

Camera = require 'custom-vendor.brady'

require 'lib.scene-graph'
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
]]--


function centerCameraOnPosition(x,y,vw, vh)
   local cw, ch = cam:getContainerDimensions()
   local targetScale = math.min(cw/vw, ch/vh)
   cam:setScale(targetScale)
   --cam:setTranslation(x + vw/2, y + vh/2)
   cam:setTranslation(x , y)
end



function makeNode(graphic, transform)
   return {
      _parent = nil,
      children = {},
      graphic = graphic,
      dirty = true,
      
      transforms = {l = transform or love.math.newTransform( 0, 0, 0, 1, 1, graphic.w/2, graphic.h, 0, 0 )}
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
end


function love.load()
   love.window.setMode(1024, 768, {resizable=true, vsync=true, minwidth=0, minheight=0, msaa=2, highdpi=true})

   cam = createCamera()



   --animals =  makeGraphic('assets/animals4.png')
   --dogmanhaar =  makeGraphic('assets/dogmanhaar.png')

   
   root = makeNode(nil,  love.math.newTransform( 0, 0, 0, 1, 1, 0, 0, 0, 0 ))

   local animals1 =  makeNode(makeGraphic('assets/animals4.png'))
   local animals2 =  makeNode(makeGraphic('assets/animals4.png'))

   animals2.transforms.l:translate(400,0)
   addChild(root, animals1)
   addChild(animals1, animals2)
   
   --addNodeTo(animals, root)
   --addNodeTo(dogmanhaar, animals)
   


   
   
   --setCameraViewport(cam, 100,100)
   centerCameraOnPosition(150,-500, 1200,1200)

   count = 0

   print(love.math.newTransform( 1,2,3,4,5,6,7,8,9 ):getMatrix())
end

function love.update(dt)
   myWorld:emit("update", dt)
   manageCameraTween(dt)
   cam:update()

   count = count + dt/10
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


function love.draw()
   love.graphics.clear(.5,.5,.3)
  
   
   
   --root.transforms.l:rotate(count )
   --root.dirty = true
   
   --root.transforms.l:setTransformation( 0,0,count )
   
   --root.children[1].dirty = true

  -- root.children[1].children[1].transforms.l:rotate( -count )
 --  root.children[1].children[1].dirty = true
    
   cam:push()

   renderRecursive(root)

   love.graphics.setColor(1,0,0)
   love.graphics.rectangle('fill', 0, 0, 20,20)
  
   cam:pop()
end


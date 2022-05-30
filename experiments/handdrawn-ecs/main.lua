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

   -- inflate polygon
   https://stackoverflow.com/questions/1109536/an-algorithm-for-inflating-deflating-offsetting-buffering-polygons

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


function love.mousemoved(x,y,dx,dy)
   if love.mouse.isDown(1) then
      local s=cam:getScale()
      cam:translate(-dx/s,-dy/s)
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
   love.keyboard.setKeyRepeat( true )

end


function love.load()


   cam = createCamera()

   depthMinMax =       {min=-1.0, max=1.0}
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

   groundimg1 = love.graphics.newImage('assets/blub1b.png', {mipmaps=true})
   groundimg1:setWrap( 'repeat' )
   groundimg2 = love.graphics.newImage('assets/blub2.png', {mipmaps=true})
   groundimg3 = love.graphics.newImage('assets/blub3.png', {mipmaps=true})
   groundimg4 = love.graphics.newImage('assets/blub4.png', {mipmaps=true})
   groundimg5 = love.graphics.newImage('assets/blub5.png', {mipmaps=true})
   groundimg6 = love.graphics.newImage('assets/ground1.png', {mipmaps=true})
   groundimg6b = love.graphics.newImage('assets/ground1.png', {mipmaps=true})

   groundimg7 = love.graphics.newImage('assets/ground2.png', {mipmaps=true})
   groundimg8 = love.graphics.newImage('assets/ground3.png', {mipmaps=true})
   groundimg9 = love.graphics.newImage('assets/ground4.png', {mipmaps=true})
   groundimg10 = love.graphics.newImage('assets/ground5.png', {mipmaps=true})
   groundimg11 = love.graphics.newImage('assets/ground6.png', {mipmaps=true})
   groundimg12 = love.graphics.newImage('assets/ground7.png', {mipmaps=true})
   groundimg13 = love.graphics.newImage('assets/ground8.png', {mipmaps=true})

   ding = love.graphics.newImage('assets/Naamloos2.png', {mipmaps=true})
   
   
   -- groundimg = makeGraphic('assets/kleed2.jpg')
   
   root = makeNode(nil,  { 0, 0, 0, 1, 1, 0, 0, 0, 0 })

   local animals1 =  makeNode(makeGraphic('assets/animals3.png'))
   local animals2 =  makeNode(makeGraphic('assets/plant.png'))

   animals2.transforms.tl[1] = animals2.transforms.tl[1]
   --animals2.transforms.l:translate(400,0)
   addChild(root, animals1)
   addChild(animals1, animals2)
   
   --addNodeTo(animals, root)
   --addNodeTo(dogmanhaar, animals)
   


   
   
   --setCameraViewport(cam, 100,100)
   centerCameraOnPosition(150,-500, 1200,1200)

   count = 0


   p = generatePolygon(200,200,1000,.15,.15,14)
   d = createTexturedPolygon(groundimg1, p)
   totaldt =0

   heights = {}
   for i =-1000, 1000 do
      heights[i] = love.math.random()* 100
   end
   
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

   

   if totaldt % 2 < 0.1 then
      p = generatePolygon(200,200,1200,.15,.15,14)
      d = createTexturedPolygon(groundimg1, p)

   end
   totaldt = totaldt + dt
   
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
	 love.graphics.setColor(.5,.5,.5)
	 local r, g, b, a = node.graphic.imageData:getPixel( xx, yy )
	 if (a > 0) then
	    love.graphics.setColor(1,1,1,1)
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
      local height1 =  heights[groundIndex]
      local height2 = heights[groundIndex+1]
      local s = cam:getScale() -- 50 -> 0.01
      
      
      local x4,y4 = cam:getScreenCoordinates(i+0.0001, height1, near)
      local x3, y3 = cam:getScreenCoordinates(i+tileSize+ .0001, height2, near)
      local x1,y1 = x4, y4-s*tileSize
      local x2,y2 = x3, y3-s*tileSize

      local mesh = createTexturedRectangle(imgarr[tileIndex])

   --   mesh:setVertex(1, {x1,y1, 0.5,0.5,1,1,1})

      mesh:setVertex(1, {x1,y1, 0,0,1,1,1,.5})
      mesh:setVertex(2, {x2,y2, 1,0,1,1,1,.5})
      mesh:setVertex(3, {x3,y3, 1,1})
      mesh:setVertex(4, {x4,y4, 0,1})

     -- mesh:setVertex(6, {x1,y1, 0,0,.5,.5,1})

      love.graphics.setColor(.6,0.3,0.3)

--      love.graphics.polygon('line', p)
      love.graphics.draw(mesh)

      local o = 200
      
      mesh:setVertex(1, {x1,y1+o, 0,0,1,1,1,.5})
      mesh:setVertex(2, {x2,y2+o, 1,0,1,1,1,.5})
      mesh:setVertex(3, {x3,y3+o, 1,1})
      mesh:setVertex(4, {x4,y4+o, 0,1})
--      love.graphics.draw(mesh)


      
      
      
      local newuvs = {.05, .08, -- tl x and y}
			 .92, .95-.14} --width and height



      local rect1 = {x1,y1,x2,y2,x3,y3,x4,y4}
      local outward = drawTheShizzle(rect1, newuvs)

      local m = createTexturedRectangle(ding)
      m:setVertex(1, {outward[1], outward[2], 0,0})
      m:setVertex(2, {outward[3], outward[4], 1,0})
      m:setVertex(3, {outward[5], outward[6], 1,1})
      m:setVertex(4, {outward[7], outward[8], 0,1})

     
      love.graphics.setColor(168/255, 175/255, 97/255)
      --love.graphics.setColor(.5,1,.5,0.7)
      love.graphics.draw(m)
      
      
      --love.graphics.setColor(0.25,1-(0.05*tileIndex),0.25,.5)
      --love.graphics.polygon("fill", {x1,y1, x3,y3,x4,y4,x2,y2})
      ---love.graphics.setColor(0.25,.5,0.25)

      --love.graphics.line(x1,y1, x2,y2)
      --love.graphics.line(x1,y1, x3,y3)
   end
end




function calculateOuterTexture(points, uvShape)
   -- we generate the 4 points at uv=0 en uv=1
   --local tlx, tly,brx,bry = getPointsBBoxFlat(points)
   --local middleX = mapInto(.5, 0, 1, tlx, brx)
   --local middleY = mapInto(.5, 0, 1, tly, bry)

--   print(inspect(uvShape))

  -- print(inspect(points))

   local uvW = uvShape[1]+uvShape[3]
   local uvH = uvShape[2]+uvShape[4]

   local p1 = {
      x= mapInto(0, uvShape[1], uvW, points[1], points[5] ),
      y= mapInto(0, uvShape[2], uvH, points[2], points[6] )
   }
   local p2 = {
      x= mapInto(1, uvW, uvShape[1], points[3], points[7] ),
      y= mapInto(0, uvShape[2],uvH, points[4], points[8] )
   }
   local p3 = {
      x= mapInto(1, uvW, uvShape[1], points[5], points[1] ),
      y= mapInto(1, uvH, uvShape[2], points[6], points[2] )
   }
   local p4 = {
      x= mapInto(0, uvShape[1], uvW, points[7], points[3] ),
      y= mapInto(1, uvH, uvShape[2], points[8], points[4] )
   }

   return {p1.x,p1.y,p2.x,p2.y,p3.x,p3.y,p4.x,p4.y}
end


function makeParallelLine(line, offset)
   local x1 = line[1]
   local y1 = line[2]
   local x2 = line[3]
   local y2 = line[4]
   local L = math.sqrt((x1-x2)*(x1-x2)+(y1-y2)*(y1-y2))

   local x1p = x1 + offset * (y2-y1)/L
   local x2p = x2 + offset * (y2-y1)/L
   local y1p = y1 + offset * (x1-x2)/L
   local y2p = y2 + offset * (x1-x2)/L
   return {x1p, y1p, x2p, y2p}

end

function isectLineLine(line1, line2) 
    --local a = line1.a
    --local b = line1.b
    --local c = line2.a
   --local d = line2.b
   local ax = line1[1]
   local bx = line1[3]
   local cx = line2[1]
   local dx = line2[3]

   
   local ay = line1[2]
   local by = line1[4]
   local cy = line2[2]
   local dy = line2[4]

   
    local dx12 = ax - bx;
    local dx34 = cx - dx;
    local dy12 = ay - by;
    local dy34 = cy - dy;
    local den = dx12 * dy34 - dy12 * dx34;
    local EPSILON = 0.000001
    
    if (math.abs(den) < EPSILON) then
        return undefined
    else 
        local det12 = ax * by - ay * bx
        local det34 = cx * dy - cy * dx
        local numx = det12 * dx34 - dx12 * det34
        local numy = det12 * dy34 - dy12 * det34
        return {x= numx / den, y= numy / den}
    end
end

   function wildstuff()   
   local sin = function(a) return math.sin(totaldt)*100*(a or 1) end
  -- local points = {100+sin(),100, 200, 100, 200+sin(),200-sin(.5),100+sin(-1),200}
   local margin = .1
--   local uvs = {0+margin,0+margin,
--                1-margin,0+margin,
--                1-margin,1-margin,
--                0+margin,1-margin}

   local newuvs = {.05, .08, -- tl x and y}
                   .92, .95-.14} --width and height



   local rect1 = {400,400+sin(), 600,400+sin(), 600+sin(1),600, 400+sin(), 600}
   local outward = drawTheShizzle(rect1, newuvs)

   --love.graphics.polygon('line', rect1)
   --love.graphics.polygon('line', outward)


    local m = createTexturedRectangle(ding)
    m:setVertex(1, {outward[1], outward[2], 0,0})
    m:setVertex(2, {outward[3], outward[4], 1,0})
    m:setVertex(3, {outward[5], outward[6], 1,1})
    m:setVertex(4, {outward[7], outward[8], 0,1})
   
    
  

    love.graphics.setColor(0,0,0,0.9)
    love.graphics.draw(m)


    local offset = 200
    local rect1 = {400+offset,400+sin(), 600+offset,400+sin(), 600+offset+sin(),600, 400+offset+sin(), 600}
   local outward = drawTheShizzle(rect1, newuvs)

--   love.graphics.polygon('line', rect1)
--   love.graphics.polygon('line', outward)


   local m = createTexturedRectangle(ding)

   for j = 1, 4 do
       local _,_, u, v  = m:getVertex(j)
       m:setVertex(j, {outward[((j-1)*2)+1],outward[((j-1)*2)+2], u,v})
    end

   love.graphics.setColor(1,0,0)
   love.graphics.draw(m)
   
   end


function drawTheShizzle(rect, uvData)
  -- love.graphics.setColor(1,0,0)
   -- love.graphics.line(rect[1], rect[2], rect[3], rect[4])
   -- love.graphics.line(rect[3], rect[4], rect[5], rect[6])
   -- love.graphics.line(rect[5], rect[6], rect[7], rect[8])
   -- love.graphics.line(rect[7], rect[8], rect[1], rect[2])

   -- middle lines
  -- love.graphics.setColor(0,0,1)
   local hx1 = lerp(rect[1], rect[7], 0.5)
   local hy1 = lerp(rect[2], rect[8], 0.5)
   local hx2 = lerp(rect[3], rect[5], 0.5)
   local hy2 = lerp(rect[4], rect[6], 0.5)
   
  -- love.graphics.line(hx1, hy1, hx2, hy2)

   local vx1 = lerp(rect[1], rect[3], 0.5)
   local vy1 = lerp(rect[2], rect[4], 0.5)
   local vx2 = lerp(rect[7], rect[5], 0.5)
   local vy2 = lerp(rect[8], rect[6], 0.5)

  -- love.graphics.line(vx1, vy1, vx2, vy2)

   -- ok so the top and bottom lines, where will the new ones be?
   --print(uvData[2], uvData[4])
   local vertd = (distance(vx1, vy1, vx2, vy2))
   --print(vertd)
   local totalv = 1/uvData[4] * vertd
   --print(totalv)

   local topOff = uvData[2] * totalv
   local bottomOff = (1-(uvData[4]+uvData[2])) * totalv

   local pTop = makeParallelLine({rect[1], rect[2], rect[3], rect[4]}, topOff)
   local pBottom = makeParallelLine({ rect[5], rect[6], rect[7], rect[8]}, bottomOff)
  


   local hord = (distance(hx1, hy1, hx2, hy2))
   local totalh = 1/uvData[3] * hord
   local leftOff = uvData[1] * totalh
   local rightOff = (1-(uvData[3]+uvData[1])) * totalh
   --print(leftOff + rightOff + hord, totalh)
   local pLeft = makeParallelLine({ rect[7], rect[8], rect[1], rect[2]}, leftOff)
   local pRight = makeParallelLine({ rect[3], rect[4], rect[5], rect[6]}, rightOff)
   
   function connectAtIntersection(l1, l2)
      local i1 = isectLineLine(l1, l2)
      l1[3] = i1.x
      l1[4] = i1.y
      l2[1] = i1.x
      l2[2] = i1.y
   end
   
   connectAtIntersection(pTop, pRight)
   connectAtIntersection(pRight, pBottom)
   connectAtIntersection(pBottom, pLeft)
   connectAtIntersection(pLeft, pTop)

   
   
   --love.graphics.line(pLeft[1], pLeft[2], pLeft[3], pLeft[4])
   --love.graphics.line(pRight[1], pRight[2], pRight[3], pRight[4])
   --love.graphics.line(pTop[1], pTop[2], pTop[3], pTop[4])
   --love.graphics.line(pBottom[1], pBottom[2], pBottom[3], pBottom[4])
   --print(topOff+bottomOff + vertd)
   --print(uvData[2] * totalv)
   --print((1-(uvData[4]+uvData[2])) * totalv)
   return {pTop[1], pTop[2], pRight[1], pRight[2], pBottom[1], pBottom[2], pLeft[1], pLeft[2]}
end


function love.draw()
   love.graphics.clear(.3,.5,.8)
   --root.transforms.l:setTransformation( 0,0,count )
   
   --root.children[1].dirty = true

   -- root.children[1].children[1].transforms.l:rotate( -count )
   --  root.children[1].children[1].dirty = true
   drawGroundPlaneLinesSimple( cam, 'foregroundFar', 'foregroundNear')
--   drawGroundPlaneLinesSimple( cam, 'foregroundNear', 'foregroundNearer')
--   drawGroundPlaneLinesSimple( cam, 'foregroundNearer', 'foregroundNearest')
   
   cam:push()
   love.graphics.setColor(1,1,1)
   love.graphics.draw(d)

   renderRecursive(root)

   love.graphics.setColor(1,1,1)
   love.graphics.setColor(1,0,0)
   love.graphics.rectangle('fill', 0, 0, 20,20)
   
   cam:pop()


   wildstuff()
   love.graphics.setColor(1,1,1)
   love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)
   love.graphics.print(inspect(love.graphics.getStats()), 10, 40)
end


local render = {}

local numbers = require 'lib.numbers'
local bbox = require 'lib.bbox'
local transform = require 'lib.transform'
local unloop = require 'lib.unpack-points'
local formats = require 'lib.formats'
local mesh = require 'lib.mesh'
local node = require 'lib.node'
local parentize = require 'lib.parentize'
local polyline = require 'lib.polyline'
local border = require 'lib.border-mesh'
require 'lib.camera'
--local cam = getCamera()
local cam = require('lib.cameraBase').getInstance()
-- todo @global GLOBALS.parallax

local lerp = numbers.lerp

local function lerpColor(c1, c2, t)
   return { lerp(c1[1], c2[1], t),
      lerp(c1[2], c2[2], t),
      lerp(c1[3], c2[3], t),
      lerp(c1[4], c2[4], t) }
end

local function lerpArray(a1, a2, t)
   local result = {}
   for i = 1, #a1 do
      table.insert(result, lerp(a1[i], a2[i], t))
   end
   return result
end

local function lerpPoints(p1, p2, t)
   if (#p1 == #p2) then
      local result = {}
      for i = 1, #p1 do
         table.insert(result, {
            lerp(p1[i][1], p2[i][1], t),
            lerp(p1[i][2], p2[i][2], t)
         })
      end
      return result
   end
   print('lerping two arrays thta rent the same length')
   return p1
end

local function lerpNodes(left, right, root, t)
   if (left.folder and right.folder) then
      root.folder = true
      root.transforms = {
         l = lerpArray(left.transforms.l, right.transforms.l, t),
         --g = lerpArray(left.transforms.g, right.transforms.g, t)
      }
      root.children = {}
      --      print(#left.children, #right.children)
      if (#left.children == #right.children) then
         for i = 1, #left.children do
            root.children[i] = {}
            lerpNodes(left.children[i], right.children[i], root.children[i], t)
         end
      end
      --root._parent = left._parent
   elseif (left.points and right.points) then
      if (left.mask and right.mask) then
         root.mask = true
      end
      if (left.hole and right.hole) then
         root.hole = true
      end

      if (left.closeStencil and right.closeStencil) then
         --print('check!')
         root.closeStencil = true
      end


      root.color = lerpColor(left.color, right.color, t)
      root.points = lerpPoints(left.points, right.points, t)
      --root._parent = left._parent
      --print('make mesh from vertices lerp stuff' )
      root.mesh = mesh.makeMeshFromVertices(mesh.makeVertices(root), root.type, root.texture)
   end

   return root
end

local function createLerpedChild(ex1, ex2, t)

   local result = {}
   lerpNodes(ex1, ex2, result, t)
   result._parent = ex1._parent
   parentize.parentize(result)
   return result

end

render.renderThingsWithKeyFrames = function(root)

   -- if (root.keyframes) then
   if (root.keyframes == 2) then
      if currentNode == root then
         local lerped = createLerpedChild(root.children[1], root.children[2], root.lerpValue)

         if lerped then handleChild(lerped) end
      elseif (not root.lastLerp or root.needsLerp) then
         local lerped = createLerpedChild(root.children[1], root.children[2], root.lerpValue)
         if lerped then handleChild(lerped) end
         root.lastLerp = lerped

      else

         handleChild(root.children[root.frame])
      end
   end


   -- https://answers.unity.com/questions/1252260/lerp-color-between-4-corners.html
   --[[

      assuming a coordinate system something like this,
      with a different color at each corner,
      what's the color at u, v ?


      0, 1                     1, 1
      *-----------------------*
      |                       |
      |                       |
      |             *         |
      |             u, v      |
      |                       |
      |                       |
      |                       |
      |                       |
      *-----------------------*
      0, 0                     1, 0

      Color bilinear(Color[,] corners, Vector2 uv) {
      Color cTop = Color.lerp(corners[0, 1], corners[1, 1], uv.x);
      Color cBot = Color.lerp(corners[0, 0], corners[1, 0], uv.x);
      Color cUV  = Color.lerp(cBot, cTop, uv.y);
      return cUV;
      }

   ]] --

   if (root.keyframes == 4) then
      if currentNode == root then
         local cTop = createLerpedChild(root.children[1], root.children[2], root.lerpX)
         local cBot = createLerpedChild(root.children[3], root.children[4], root.lerpX)
         local lerped = createLerpedChild(cTop, cBot, root.lerpY)
         --print(root.lerpX, root.lerpY)
         --local lerped = createLerpedChild(root.children[1], root.children[2], 0.5)

         if lerped then handleChild(lerped) end
      else
         handleChild(root.children[root.frame])
      end
   end
   if (root.keyframes == 5) then
      if currentNode == root then
         print("doing the 5 way")
         local lerpX = root.lerpX or 0.5
         local lerpY = root.lerpY or 0.5
         local newLerpX = 0
         local newLerpY = 0
         if lerpX == .5 and lerpY == .5 then
            handleChild(root.children[1])
         else
            local tl, tr, bl, br
            if (lerpX < 0.5 and lerpY < 0.5) then
               tl = root.children[2]
               tr = createLerpedChild(root.children[2], root.children[3], 0.5)
               bl = createLerpedChild(root.children[2], root.children[4], 0.5)
               br = root.children[1]
               newLerpX = lerpX * 2
               newLerpY = lerpY * 2

            end
            if (lerpX >= 0.5 and lerpY < 0.5) then
               tl = createLerpedChild(root.children[2], root.children[3], 0.5)
               tr = root.children[3]
               bl = root.children[1]
               br = createLerpedChild(root.children[3], root.children[5], 0.5)
               newLerpX = (lerpX - 0.5) * 2
               newLerpY = lerpY * 2

            end
            if (lerpX < 0.5 and lerpY >= 0.5) then
               tl = createLerpedChild(root.children[2], root.children[4], 0.5)
               tr = root.children[1]
               bl = root.children[4]
               br = createLerpedChild(root.children[4], root.children[5], 0.5)

               newLerpX = (lerpX) * 2
               newLerpY = (lerpY - 0.5) * 2

            end
            if (lerpX >= 0.5 and lerpY >= 0.5) then
               tl = root.children[1]
               tr = createLerpedChild(root.children[3], root.children[5], 0.5)
               bl = createLerpedChild(root.children[4], root.children[5], 0.5)
               br = root.children[5]

               newLerpX = (lerpX - 0.5) * 2
               newLerpY = (lerpY - 0.5) * 2

            end
            local cTop = createLerpedChild(tl, tr, newLerpX)
            local cBot = createLerpedChild(bl, br, newLerpX)
            local lerped = createLerpedChild(cTop, cBot, newLerpY)
            if lerped then handleChild(lerped) end
         end
         --if lerped then handleChild(lerped) end
      else
         handleChild(root.children[root.frame])
      end
   end
end



render.renderThings = function(root, dirty)

   local isDirty = dirty or root.dirty
   if (isDirty) then
      -- print(root.name,root.url,  dirty, root.dirty)
   end
   --print(inspect(transform))
   transform.setTransforms(root, isDirty)

   if root.keyframes then
      -- todo this needs to be fed isDirty too
      --print('am i getting here already?')
      render.renderThingsWithKeyFrames(root)
   else
      --love.graphics.setStencilTest()
      for i = 1, #root.children do
         local shape = root.children[i]
         if (isDirty) then
            --print('dirty child', root.name, shape.name)
         end

         handleChild(shape, isDirty)
      end
      --love.graphics.setStencilTest()
   end



   if root._parent == nil then
      love.graphics.setStencilTest()
   end

end


local function renderNormallyOrOptimized(shape, isDirty)
   if true then
      if (shape.optimizedBatchMesh) then
         transform.setTransforms(shape, isDirty)
         -- todo this transform can be kept somewhere on shape and only recalculated when dirty
         local transform = shape._parent.transforms._g * shape.transforms._l
         for i = 1, #shape.optimizedBatchMesh do
            love.graphics.setColor(shape.optimizedBatchMesh[i].color)
            love.graphics.draw(shape.optimizedBatchMesh[i].mesh, transform)
            if renderCount then
               renderCount.optimized = renderCount.optimized + 1 --= {normal=0, optimized=0}
            end
         end
      else
         if renderCount then
            renderCount.normal = renderCount.normal + 1
         end
         --print(shape.name, isDirty)
         render.renderThings(shape, isDirty)
      end
   end

end

local maskIndex = 0

function handleChild(shape, isDirty)
   -- TODO i dont want to directly depend on my parents global transform that is not correct
   -- this gets in the way of lerping between nodes...
   --print(shape.name, isDirty)
   if not shape then return end
   --   print(shape.type)

   if shape.mask or shape.hole then
      local m
      if currentNode ~= shape then
         m = shape.mesh -- the standard way of rendering
      else
         --print('making mesh in handlechild')
         --remeshNode(shape)
         m = mesh.makeMeshFromVertices(mesh.makeVertices(shape), shape.type, shape.texture) -- realtime iupdating the thingie
      end

      local parentIndex = node.getIndex(shape._parent)
      maskIndex = maskIndex + 1
      local thisIndex = (maskIndex % 255) + 1

      if shape.hole and m then
         love.graphics.stencil(
            function()
               love.graphics.draw(m, shape._parent.transforms._g)
            end, "replace", parentIndex, true)

      end

      if shape.mask and m then
         love.graphics.stencil(
            function()
               love.graphics.draw(m, shape._parent.transforms._g)
            end, "replace", thisIndex, true)
      end

      if shape.hole then
         love.graphics.setStencilTest("notequal", parentIndex)
      else
         love.graphics.setStencilTest("equal", thisIndex)
      end
   end

   if shape.closeStencil then
      love.graphics.setStencilTest()
   end





   if shape.folder then

      if (shape.depth ~= nil) and GLOBALS and GLOBALS.parallax then

         GLOBALS.parallax.camera.scale = numbers.mapInto(
            shape.depth,
            GLOBALS.parallax.p.minmax.min, GLOBALS.parallax.p.minmax.max,
            GLOBALS.parallax.p.factors.far, GLOBALS.parallax.p.factors.near
         )

         GLOBALS.parallax.camera.relativeScale = 1
         GLOBALS.parallax.camera.push()

      end

      -- if (shape.depth ~= nil and (shape.depthLayer == 'hack')) then
      --    print(inspect(hack))
      --    hack.scale = mapInto(shape.depth, depthMinMax.min, depthMinMax.max, depthScaleFactors.min, depthScaleFactors.max)
      --    hack.relativeScale = (1.0/ hack.scale) * hack.scale
      --    hack.push()
      -- end


      if shape.generatedMeshes then
         transform.setTransforms(shape, isDirty)

         --print('there are some generatedMeshes here, are these rubberhose legs?')
         for i = 1, #shape.generatedMeshes do
            love.graphics.setColor(shape.generatedMeshes[i].color)
            love.graphics.draw(shape.generatedMeshes[i].mesh, shape.transforms._g)
         end
      end


      if shape.bbox then
         -- no need to repeat this calc
         local minX = cam.translationX - ((cam.w / 2) / cam.scale)
         local maxX = cam.translationX + ((cam.w / 2) / cam.scale)
         local extraOffset = tileSize
         minX = minX - extraOffset
         maxX = maxX + extraOffset

         local tlx = shape.transforms.l[1] + (shape.bbox[1])
         local tly = shape.transforms.l[2] + shape.bbox[2]
         local brx = shape.transforms.l[1] + (shape.bbox[3])
         local bry = shape.transforms.l[2] + shape.bbox[4]

         if brx >= minX and tlx <= maxX then
            --print('yes')
            renderNormallyOrOptimized(shape, isDirty)
         else

            --print('not')
            --print(tlx,tly, brx, bry, inspect(shape.bbox))
         end

         --print(tlx, tly, brx, bry)
         --print(shape.transforms.l[2] + shape.transforms.l[7])

      else
         renderNormallyOrOptimized(shape, isDirty)

      end



      if false and shape.aabb then
         local minX = cam.translationX - ((cam.w / 2) / cam.scale)
         local maxX = cam.translationX + ((cam.w / 2) / cam.scale)
         local extraOffset = 100
         if shape.aabb > minX - extraOffset and shape.aabb < maxX + extraOffset then
            renderNormallyOrOptimized(shape, isDirty)
         else
            print('not rendering someting cause of the aabb', inspect(shape.aabb), minX, maxX)
         end

      else
         renderNormallyOrOptimized(shape, isDirty)
      end

      if false then
         if shape.generatedMeshes then
            transform.setTransforms(shape, isDirty)

            --print('there are some generatedMeshes here, are these rubberhose legs?')
            for i = 1, #shape.generatedMeshes do
               love.graphics.setColor(shape.generatedMeshes[i].color)
               love.graphics.draw(shape.generatedMeshes[i].mesh, shape.transforms._g)
            end
         end
      end



      --love.graphics.setStencilTest()
   end

   if currentNode ~= shape then



      if (shape.mesh and not shape.mask) then

         love.graphics.setColor(shape.color)
         --print('this is drawing the mesh, can we texture it?')
         --image = love.graphics.newImage(  )
         --shape.mesh:setTexture( ui.backdrop )
         love.graphics.draw(shape.mesh, shape._parent.transforms._g)

         if (shape.borderMesh) then
            love.graphics.setColor(0, 0, 0)
            love.graphics.draw(shape.borderMesh, shape._parent.transforms._g)
         end


         if false and shape.points then
            -- render outline!!!!!
            local work = unloop.unpackNodePoints(shape.points)
            local verts, indices, draw_mode = polyline.render('bevel', work, 10, 1, true)
            local m = love.graphics.newMesh(formats.simple_format, verts, draw_mode)
            love.graphics.setColor(shape.color[1] - .2, shape.color[2] - .2, shape.color[3] - .2, shape.color[4])
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(m, shape._parent.transforms._g)
         end


      end
   end
   if currentNode == shape then

      local editing = mesh.makeVertices(shape)
      if (editing and #editing > 0) then
         --print('makemesh in handlechild custom, this doenst do textured polygons yet', currentNode.type)


         if shape.texture and (shape.type ~= 'rubberhose' and shape.type ~= 'bezier') then
            --	    print('yo guys!')
            if (shape.texture.url and shape.texture.url:len() > 0) then
               if (shape.texture.squishable) then
                  editing = mesh.makeSquishableUVsFromPoints(shape.points)
               else

                  mesh.addUVToVerts(editing, mesh.getImage(shape.texture.url), shape.points, shape.texture)
               end
            end
         end
         --	 print(inspect(editing))
         local editingMesh = mesh.makeMeshFromVertices(editing, currentNode.type, currentNode.texture)
         --print(inspect(editingMesh))

         -- so the data here doesnt contain UV pairss
         -- that logic is in remeshNode, but works on another type of object (the parent)

         -- this is now fixed, but its still not working
         -- i still dont get it realtime updating wat the hell


         if shape.texture and shape.texture.url then
            --	    print('using texture')

            editingMesh:setTexture(mesh.getImage(shape.texture.url))
         end
         love.graphics.setColor(shape.color)
         --love.graphics.setColor(1,1,1)
         love.graphics.draw(editingMesh, shape._parent.transforms._g)

         --love.graphics.draw(shape.mesh, shape._parent.transforms._g )
      end
      if currentNode.border and #currentNode.points > 2 then
         local borderMesh = border.makeBorderMesh(currentNode)
         love.graphics.setColor(0, 0, 0)
         love.graphics.draw(borderMesh, shape._parent.transforms._g)
         --print('need to mesh the direct one too')
      end

   end

   if (shape.depth ~= nil and GLOBALS and GLOBALS.parallax) then
      GLOBALS.parallax.camera:pop()
   end

end

render.renderNodeIntoCanvas = function(n, canvas, filename)

   love.graphics.setCanvas({ canvas, stencil = true })
   love.graphics.clear()
   -- this is the default already
   --love.graphics.setBlendMode("alpha")

   drawNodeIntoRect(n, 0, 0, canvas:getWidth(), canvas:getHeight())

   love.graphics.setCanvas()

   canvas:newImageData():encode("png", filename)
end

function drawNodeIntoRect(node, x, y, w, h)
   -- first get the nodes bbox
   local bboxbefore = bbox.getBBoxRecursive(node)
   local cw = bboxbefore[3] - bboxbefore[1]
   local ch = bboxbefore[4] - bboxbefore[2]

   local oldScaleW = node.transforms.l[4]
   local oldScaleH = node.transforms.l[5]

   local newScaleW = oldScaleW / (cw / w)
   local newScaleH = oldScaleH / (ch / h)

   local biggestRatio = math.max(cw, ch)
   local newScaleW2 = oldScaleW / (biggestRatio / w)
   local newScaleH2 = oldScaleH / (biggestRatio / h)


   -- here i am scaling the original
   node.transforms.l[4] = newScaleW
   node.transforms.l[5] = newScaleH
   local bboxafter = bbox.getBBoxRecursive(node) -- this bbox describes the squashed image


   -- here i am scaling the original
   node.transforms.l[4] = newScaleW2
   node.transforms.l[5] = newScaleH2
   local bboxafter2 = bbox.getBBoxRecursive(node) -- this bbox descirbes the image at the same ratio as original

   -- now i need to calculate the offset, which is the same as the difference between the 2 bounding boxes

   local w1 = bboxafter[3] - bboxafter[1]
   local w2 = bboxafter2[3] - bboxafter2[1]
   local h1 = bboxafter[4] - bboxafter[2]
   local h2 = bboxafter2[4] - bboxafter2[2]
   local offsetX = (w1 - w2) / 2
   local offsetY = (h1 - h2) / 2

   love.graphics.push()
   love.graphics.translate(-bboxafter2[1] + x + offsetX, -bboxafter2[2] + y + offsetY)
   render.renderThings(node)
   love.graphics.pop()



   -- here i am restoring the original
   node.transforms.l[4] = oldScaleW
   node.transforms.l[5] = oldScaleH


end

return render

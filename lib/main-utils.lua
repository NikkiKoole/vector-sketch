-- these utils are used when you wanna use the shapes and all in another application



function renderNodeIntoCanvas(node, canvas, filename)

   love.graphics.setCanvas({canvas, stencil=true})
   love.graphics.clear()
   love.graphics.setBlendMode("alpha")

   drawNodeIntoRect(node, 0,0,canvas:getWidth(),canvas:getHeight())

   love.graphics.setCanvas()

   canvas:newImageData():encode("png",filename)
end




function drawNodeIntoRect(node, x,y,w,h)
   -- first get the nodes bbox
   local bboxbefore = getBBoxRecursive(node)
   local cw = bboxbefore[3] - bboxbefore[1]
   local ch = bboxbefore[4] - bboxbefore[2]

   local oldScaleW = node.transforms.l[4]
   local oldScaleH = node.transforms.l[5]

   local newScaleW = oldScaleW / (cw/w)
   local newScaleH = oldScaleH / (ch/h)

   local biggestRatio = math.max(cw, ch)
   local newScaleW2 = oldScaleW / (biggestRatio/w)
   local newScaleH2 = oldScaleH / (biggestRatio/h)


   -- here i am scaling the original
   node.transforms.l[4] = newScaleW
   node.transforms.l[5] = newScaleH
   local bboxafter = getBBoxRecursive(node) -- this bbox describes the squashed image


   -- here i am scaling the original
   node.transforms.l[4] = newScaleW2
   node.transforms.l[5] = newScaleH2
   local bboxafter2 = getBBoxRecursive(node) -- this bbox descirbes the image at the same ratio as original

   -- now i need to calculate the offset, which is the same as the difference between the 2 bounding boxes

   local w1 = bboxafter[3] - bboxafter[1]
   local w2 = bboxafter2[3] - bboxafter2[1]
   local h1 = bboxafter[4] - bboxafter[2]
   local h2 = bboxafter2[4] - bboxafter2[2]
   local offsetX = (w1 - w2)/2
   local offsetY = (h1 - h2)/2

   love.graphics.push()
   love.graphics.translate(-bboxafter2[1] + x + offsetX, -bboxafter2[2] + y + offsetY)
   renderThings(node)
   love.graphics.pop()



      -- here i am restoring the original
   node.transforms.l[4] = oldScaleW
   node.transforms.l[5] = oldScaleH


end


function transferPoint (xI, yI, source, destination)

    local ADDING = 0.00001 -- to avoid dividing by zero

    local xA = source[1]
    local yA = source[2]

    local xC = source[3]
    local yC = source[4]

    local xAu = destination[1][1]
    local yAu = destination[1][2]

    local xBu = destination[2][1]
    local yBu = destination[2][2]

    local xCu = destination[3][1]
    local yCu = destination[3][2]

    local xDu = destination[4][1]
    local yDu = destination[4][2]
    --print(xA,yA,xC,yC)
    --print(xAu,yAu,xBu,yBu,xCu,yCu,xDu,yDu)
    -- Calcultations
    -- if points are the same, have to add a ADDING to avoid dividing by zero
    if (xBu==xCu) then xC = xC + ADDING end
    if (xAu==xDu) then xDu= xDu+ ADDING end
    if (xAu==xBu) then xBu =xBu + ADDING end
    if (xDu==xCu) then xCu = xCu + ADDING end
    --print(xC,xDu,xBu,xCu)
    local kBC = (yBu-yCu)/(xBu-xCu)
    local kAD = (yAu-yDu)/(xAu-xDu)
    local kAB = (yAu-yBu)/(xAu-xBu)
    local kDC = (yDu-yCu)/(xDu-xCu)

    if (kBC==kAD) then kAD =kAD + ADDING end
    local xE = (kBC*xBu - kAD*xAu + yAu - yBu) / (kBC-kAD)
    local yE = kBC*(xE - xBu) + yBu

    if (kAB==kDC) then kDC = kDC + ADDING end
    local xF = (kAB*xBu - kDC*xCu + yCu - yBu) / (kAB-kDC)
    local yF = kAB*(xF - xBu) + yBu

    if (xE==xF) then xF = xF + ADDING end
    local kEF = (yE-yF) / (xE-xF)

    if (kEF==kAB) then kAB = kAB + ADDING end
    local xG = (kEF*xDu - kAB*xAu + yAu - yDu) / (kEF-kAB)
    local yG = kEF*(xG - xDu) + yDu

    if (kEF==kBC) then kBC = kBC + ADDING end
    local xH = (kEF*xDu - kBC*xBu + yBu - yDu) / (kEF-kBC)
    local yH = kEF*(xH - xDu) + yDu

    local rG = (yC-yI)/(yC-yA)
    local rH = (xI-xA)/(xC-xA)

    local xJ = (xG-xDu)*rG + xDu
    local yJ = (yG-yDu)*rG + yDu

    local xK = (xH-xDu)*rH + xDu
    local yK = (yH-yDu)*rH + yDu

    if (xF==xJ) then xJ = xJ + ADDING end
    if (xE==xK) then xK =xK + ADDING end
    local kJF = (yF-yJ) / (xF-xJ) --//23
    local kKE = (yE-yK) / (xE-xK) --//12

    local xKE
    if (kJF==kKE) then kKE= kKE + ADDING end
    local xIu = (kJF*xF - kKE*xE + yE - yF) / (kJF-kKE)
    local yIu = kJF * (xIu - xJ) + yJ

    local b={x=xIu,y=yIu}
    --b.x=math.round(b.x)
    --b.y=math.round(b.y)
    return b
end



function makeOptimizedBatchMesh(folder)
   -- this one assumes all children are shapes, still need to think of what todo when
   -- folders are children
    if #folder.children == 0 then
      print("this was empty nothing to optimize")
      return
    end

    for i=1, #folder.children do
       if (folder.children[i].folder) then
          print("could not optimize shape, it contained a folder!!",folder.name,folder.children[i].name)
          print('havent fetched the metatags either',folder.name,folder.children[i].name)
          return
      end
    end

    --for i=1, #folder.children do
    --   if (folder.children[i].type == 'meta') then
    --      print("could not optimize shape, it contained a meta tag",folder.name,folder.children[i].name)
    --      return
    --  end
    --end

   local lastColor = folder.children[1].color
   local allVerts = {}
   local batchIndex = 1

   local metaTags = {}
   for i=1, #folder.children do
      if folder.children[i].type == 'meta' then
         local tagData = {name=folder.children[i].name,points=folder.children[i].points }
         table.insert(metaTags, tagData)
         print('skipping meta node in optimize round')
      else
         local thisColor = folder.children[i].color
         if (thisColor[1] ~= lastColor[1]) or
            (thisColor[2] ~= lastColor[2]) or
            (thisColor[3] ~= lastColor[3]) then

            if folder.optimizedBatchMesh == nil then
               folder.optimizedBatchMesh = {}
            end

            if #allVerts == 0 then
               -- this is possible since te last node could have been a meta one, then we skip some steps
               print('the last node was meta and that in itself was the first node')
            else
               local mesh = love.graphics.newMesh(simple_format, allVerts, "triangles")
               folder.optimizedBatchMesh[batchIndex] = {mesh=mesh, color=lastColor}
               batchIndex = batchIndex + 1
            end

            lastColor = thisColor
            allVerts = {}
         end
         
         allVerts = TableConcat(allVerts, makeVertices(folder.children[i]))
      end
   end
   
   if #allVerts  >0 then
      if  folder.optimizedBatchMesh == nil then
	 folder.optimizedBatchMesh = {}
      end
      local mesh = love.graphics.newMesh(simple_format, allVerts, "triangles")
      folder.optimizedBatchMesh[batchIndex] = {mesh=mesh, color=lastColor}
      --print('optimized: ', folder.name,)
   end

   if #metaTags > 0 then
      folder.metaTags = metaTags
   end
   
end

function signT(p1, p2, p3)
   return (p1[1] - p3[1]) * (p2[2] - p3[2]) - (p2[1] - p3[1]) * (p1[2] - p3[2])
end

function pointInTriangle(p, t1, t2, t3)
   local b1, b2, b3
   b1 = signT(p, t1, t2) < 0.0
   b2 = signT(p, t2, t3) < 0.0
   b3 = signT(p, t3, t1) < 0.0

   return ((b1 == b2) and (b2 == b3))
end

function isMouseInMesh(mx, my, body, mesh)
   if mesh and body then
      local count = mesh:getVertexCount()
      if body._globalTransform then



      local px,py = body._globalTransform:inverseTransformPoint(mx, my)
      for i = 1, count, 3 do
         if i+2 <= count then
            if pointInTriangle({px,py}, {mesh:getVertex(i)}, {mesh:getVertex(i+1)}, {mesh:getVertex(i+2)}) then
               return true
            end
         end

      end
      end
   end
   return false
end



function recursiveHitCheck(x,y, node)
   -- you want to check the first child IF IT HAS POINTS
   if not node then return false end

   if node.points then
      local body = node
      local mesh = body.mesh
      if (body and mesh) then
	 if isMouseInMesh(x,y, body._parent, mesh) then
	    -- imma looking for hitareas
	    if string.find(node.name, "-hitarea") then
	       return node.name
	    else
	       return true
	    end

         end
      end
   else
      if  node.optimizedBatchMesh then
	 for i = 1, #node.optimizedBatchMesh do
	    if isMouseInMesh(x,y, node, node.optimizedBatchMesh[i].mesh) then
	       print(2)
	       return true
	    end
	 end

      elseif node.children then
	 local result = false
	 for i = 1, #node.children do
	    local result =  recursiveHitCheck(x,y, node.children[i])
	    if result then
	       return result
	    end
         end
      end
   end
   return false
end

function findMeshThatsHit(parent, mx, my, order)
   -- order decides which way we will walk,
   -- order = false will return the firts hitted one (usually below everything)
   -- order = true will return the last hitted
   local result = nil
   for i = 1, #parent.children do
      if parent.children[i].children then
         if order then
            local temp = findMeshThatsHit(parent.children[i], mx, my, order)
            if temp then
               result = temp
            end
         else
            return findMeshThatsHit(parent.children[i], mx, my, order)
         end

      else

         local hit = isMouseInMesh(mx, my, parent,  parent.children[i].mesh)
         if hit then
            if order then
               result = parent.children[i]
            else
               return parent.children[i]
            end
         end
      end
   end
   if (order) then
      return result
   else
      return nil
   end
end




function renderNormallyOrOptimized(shape)
   if true then
      if (shape.optimizedBatchMesh) then
	 setTransforms(shape)
	 for i=1, #shape.optimizedBatchMesh do
	    love.graphics.setColor(shape.optimizedBatchMesh[i].color)
	    love.graphics.draw(shape.optimizedBatchMesh[i].mesh, shape._parent._globalTransform *  shape._localTransform)
            if renderCount then
               renderCount.optimized =  renderCount.optimized +1 --= {normal=0, optimized=0}
            end

	 end
      else
         if renderCount then
            renderCount.normal = renderCount.normal + 1
         end

	 renderThings(shape)
      end
   end

end

function handleChild(shape,parallax)
   -- TODO i dont want to directly depend on my parents global transform that is not correct
   -- this gets in the way of lerping between nodes...

   if not shape then return end

   if shape.mask or shape.hole then
      local mesh
      if currentNode ~= shape then
	 mesh = shape.mesh -- the standard way of rendering
      else
	 mesh =  makeMeshFromVertices(makeVertices(shape)) -- realtime iupdating the thingie
      end

      local parentIndex = getIndex(shape._parent)
      if shape.hole then
	 love.graphics.stencil(
	 function()
	    love.graphics.draw(mesh, shape._parent._globalTransform )
	 end, "replace", parentIndex, true)

      end
      if shape.mask then
         love.graphics.stencil(
	 function()
	    love.graphics.draw(mesh, shape._parent._globalTransform )
	 end, "replace", 255, true)
      end

      if shape.hole then
	 love.graphics.setStencilTest("notequal", parentIndex)
      else
	 love.graphics.setStencilTest("equal", 255)
      end
   end

   if shape.folder then

      if (shape.depth ~= nil) and parallax then
         parallax.camera.scale = mapInto(
            shape.depth,
            parallax.p.minmax.min, parallax.p.minmax.max,
            parallax.p.factors.far, parallax.p.factors.near
         )
         parallax.camera.relativeScale = 1
         --(1.0/ parallax.camera.scale) * parallax.camera.scale
         parallax.camera.push()

      end


      -- if (shape.depth ~= nil and (shape.depthLayer == 'hack')) then
      --    print(inspect(hack))
      --    hack.scale = mapInto(shape.depth, depthMinMax.min, depthMinMax.max, depthScaleFactors.min, depthScaleFactors.max)
      --    hack.relativeScale = (1.0/ hack.scale) * hack.scale
      --    hack.push()
      -- end


      if shape.aabb then
	 local minX = cam.translationX - ((cam.w/2) / cam.scale)
	 local maxX = cam.translationX + ((cam.w/2) / cam.scale)
	 local extraOffset = 100
	 if shape.aabb > minX - extraOffset and shape.aabb < maxX + extraOffset then
	    renderNormallyOrOptimized(shape)
	 end
      else
	 renderNormallyOrOptimized(shape)
      end


      love.graphics.setStencilTest()
   end

   if currentNode ~= shape then
      if (shape.mesh and not shape.mask) then

	 love.graphics.setColor(shape.color)
         love.graphics.draw(shape.mesh, shape._parent._globalTransform )

         if (shape.borderMesh) then
            love.graphics.setColor(0,0,0)
            love.graphics.draw(shape.borderMesh, shape._parent._globalTransform )
         end


         if false and shape.points then
            -- render outline!!!!!
            local work =  unpackNodePoints(shape.points)
            local verts, indices, draw_mode = polyline('bevel',work, 10, 1, true)
            local mesh = love.graphics.newMesh(simple_format, verts, draw_mode)
            love.graphics.setColor(shape.color[1]-.2,shape.color[2]-.2,shape.color[3]-.2,shape.color[4])
            love.graphics.setColor(1,1,1)
            love.graphics.draw(mesh, shape._parent._globalTransform )
         end


      end
   end
   if currentNode == shape then
      local editing = makeVertices(shape)
      if (editing and #editing > 0) then
	 local editingMesh = makeMeshFromVertices(editing)
	 love.graphics.setColor(shape.color)
	 love.graphics.draw(editingMesh,  shape._parent._globalTransform )
      end
      if currentNode.border then
         local borderMesh = makeBorderMesh(currentNode)
	 love.graphics.setColor(0,0,0)
         love.graphics.draw(borderMesh,  shape._parent._globalTransform )
         --print('need to mesh the direct one too')
      end

   end

   if (shape.depth ~= nil  and parallax) then
      parallax.camera:pop()
   end

end

function unpackNodePointsLoop(points)
   local unpacked = {}

   for i = 0, #points do
      local nxt = i == #points and 1 or i+1
      unpacked[1 + (i*2)] = points[nxt][1]
      unpacked[2 + (i*2)] =  points[nxt][2]
   end

   for i = 0, #points do
      local nxt = i == #points and 1 or i+1
      unpacked[(#points*2) + 1 + (i*2)] = points[nxt][1]
      unpacked[(#points*2) + 2 + (i*2)] =  points[nxt][2]
   end

   return unpacked
end

function unpackNodePoints(points)
   local unpacked = {}
   if #points >= 1 then
      for i = 0, #points-1 do
         unpacked[1 + (i*2)] = points[i+1][1]
         unpacked[2 + (i*2)] =  points[i+1][2]
      end

      -- make it go round
      unpacked[(#points*2)+1] =   points[1][1]
      unpacked[(#points*2)+2] =   points[1][2]

   end

   return unpacked

end


function lerpColor(c1, c2, t)
   return {lerp(c1[1], c2[1], t),
	   lerp(c1[2], c2[2], t),
	   lerp(c1[3], c2[3], t),
	   lerp(c1[4], c2[4], t)}
end

function lerpArray(a1, a2, t)
   local result = {}
   for i =1, #a1 do
      table.insert(result, lerp(a1[i], a2[i], t))
   end
   return result
end

function lerpPoints(p1, p2, t)
   assert(#p1 == #p2)
   local result = {}
   for i=1, #p1 do
      table.insert(result, {
		      lerp(p1[i][1], p2[i][1], t),
		      lerp(p1[i][2], p2[i][2], t)
      })
   end
   return result
end



function lerpNodes(left, right, root, t)
   if (left.folder and right.folder) then
      root.folder = true
      root.transforms = {
	 l = lerpArray(left.transforms.l, right.transforms.l, t),
	 --g = lerpArray(left.transforms.g, right.transforms.g, t)
      }
      root.children = {}
      assert(#left.children == #right.children)
      for i=1, #left.children do
	 root.children[i] = {}
	 lerpNodes(left.children[i], right.children[i], root.children[i], t)
      end
      --root._parent = left._parent
   elseif (left.points and right.points) then
      if (left.mask and right.mask) then
	 root.mask = true
      end
      if (left.hole and right.hole) then
	 root.hole = true
      end

      root.color = lerpColor(left.color, right.color, t)
      root.points = lerpPoints(left.points, right.points, t)
      --root._parent = left._parent
      root.mesh = makeMeshFromVertices(makeVertices(root))
   end

   return root
end

function createLerpedChild(ex1, ex2, t)

   local result = {}
   lerpNodes(ex1, ex2, result, t)
   result._parent = ex1._parent
   parentize(result)
   return result

end


-- this function is just for the bacthMeshcurrently
---- these calculations are only needed when some local transforms have changed
-- they ought t o be more optimized
-- in short: this needs a isDirty flag of sorts




function renderThings(root, parallax)

   setTransforms(root)

   if root.keyframes then
      renderThingsWithKeyFrames(root)
   else
      love.graphics.setStencilTest()
      for i = 1, #root.children do
	 local shape = root.children[i]
	 handleChild(shape, parallax)
      end
      --love.graphics.setStencilTest()
   end
   love.graphics.setStencilTest()


end


function renderThingsWithKeyFrames(root)
  -- if (root.keyframes) then
   if (root.keyframes == 2 ) then
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

   ]]--

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
	    local newLerpX =0
	    local newLerpY =0
	    if lerpX == .5 and lerpY == .5 then
	       handleChild(root.children[1])
	    else
	       local tl, tr, bl, br
	       if (lerpX < 0.5 and lerpY < 0.5) then
		  tl = root.children[2]
		  tr = createLerpedChild(root.children[2], root.children[3], 0.5)
		  bl = createLerpedChild(root.children[2], root.children[4], 0.5)
		  br =  root.children[1]
		  newLerpX = lerpX *2
		  newLerpY = lerpY *2

	       end
	       if (lerpX >= 0.5 and lerpY < 0.5) then
		  tl = createLerpedChild(root.children[2], root.children[3], 0.5)
		  tr = root.children[3]
		  bl =  root.children[1]
		  br = createLerpedChild(root.children[3], root.children[5], 0.5)
		  newLerpX = (lerpX-0.5) *2
		  newLerpY = lerpY *2

	       end
	       if (lerpX < 0.5 and lerpY >= 0.5) then
		  tl =  createLerpedChild(root.children[2], root.children[4], 0.5)
		  tr = root.children[1]
		  bl = root.children[4]
		  br =  createLerpedChild(root.children[4], root.children[5], 0.5)

		  newLerpX = (lerpX) *2
		  newLerpY = (lerpY-0.5) *2

	       end
	       if (lerpX >= 0.5 and lerpY >= 0.5) then
		  tl =   root.children[1]
		  tr = createLerpedChild(root.children[3], root.children[5], 0.5)
		  bl =  createLerpedChild(root.children[4], root.children[5], 0.5)
		  br =  root.children[5]

		  newLerpX = (lerpX-0.5) *2
		  newLerpY = (lerpY-0.5) *2

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

-- these utils are used when you wanna use the shapes and all in another application

function findNodeByName(root, name)
   if (root.name == name) then
      return root
   end
   if root.children then
      for i=1, #root.children do
	 local result = findNodeByName(root.children[i], name)
	 if result then return result end
      end
   end
   return nil
end

function parentize(node)
   if (node.children) then
   for i = 1, #node.children do
      node.children[i]._parent = node
      if (node.children[i].folder) then
	 parentize(node.children[i])
      end
   end
   end
end

function handleChild(shape)
   -- TODO i dont want to directly depend on my parents global transform that is not correct
   -- this gets in the way of lerping between nodes...
   if not shape then return end
   
   if shape.mask or shape.hole then
      local mesh
      if currentNode ~= shape then
	 mesh = shape.mesh -- the standard way of rendering
      else
	 mesh =  makeMeshFromVertices(poly.makeVertices(shape)) -- realtime iupdating the thingie
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
      renderThings(shape)
      love.graphics.setStencilTest()
   end
   --if ( shape.hole) then
   --   love.graphics.setStencilTest()
   --end

   --local fovy = 100
   --local aspect = 1
   --local near  = 0.1
   --local far = 100.0
   --print( inspect(mat4from_perspective(fovy, aspect, near, far)))
   
   if currentNode ~= shape then
      if (shape.mesh and not shape.mask) then
         
         --local perpectiveMatrix = mat4from_perspective(fovy, aspect, near, far)
         --local transform = love.math.newTransform( )
         --transform:setMatrix(perpectiveMatrix)

         -- look here https://stackoverflow.com/questions/51691482/how-to-create-a-2d-perspective-transform-matrix-from-individual-components

         
         --shape._parent._globalTransform
	 love.graphics.setColor(shape.color)
	 --love.graphics.draw(shape.mesh, shape._parent._globalTransform)
         --print( shape._parent._globalTransform[1])
         --local m = { shape._parent._globalTransform:getMatrix()}
         --groundShader:send("camera", m)
         love.graphics.draw(shape.mesh, shape._parent._globalTransform )
      end
   end
   if currentNode == shape then
      local editing = poly.makeVertices(shape)
      if (editing and #editing > 0) then
	 local editingMesh = makeMeshFromVertices(editing)
	 love.graphics.setColor(shape.color)
	 love.graphics.draw(editingMesh,  shape._parent._globalTransform )
      end
   end

   
end


-- function mat4from_perspective(fovy, aspect, near, far)
-- 	assert(aspect ~= 0)
-- 	assert(near   ~= far)

--         local new = function()
--            return {
-- 		0, 0, 0, 0,
-- 		0, 0, 0, 0,
-- 		0, 0, 0, 0,
-- 		0, 0, 0, 0
-- 	}
--         end
        
        
-- 	local t   = math.tan(math.rad(fovy) / 2)
-- 	local out = new()
-- 	out[1]    =  1 / (t * aspect)
-- 	out[6]    =  1 / t
-- 	out[11]   = -(far + near) / (far - near)
-- 	out[12]   = -1
-- 	out[15]   = -(2 * far * near) / (far - near)
-- 	out[16]   =  0

-- 	return out
-- end


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
      root.mesh = makeMeshFromVertices(poly.makeVertices(root))
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

function renderThings(root)

   ---- these calculations are only needed when some local transforms have changed

   --local tg = root.transforms.g
   local tl = root.transforms.l
   local pg = nil
   if (root._parent) then
      pg = root._parent._globalTransform
   end
   root._localTransform =  love.math.newTransform( tl[1], tl[2], tl[3], tl[4], tl[5], tl[6],tl[7], tl[8],tl[9])
   root._globalTransform = pg and (pg * root._localTransform) or root._localTransform
   ----

   if (root.keyframes) then
      if (root.keyframes == 2) then
	 if currentNode == root then
	    local lerped = createLerpedChild(root.children[1], root.children[2], root.lerpValue)

	    if lerped then handleChild(lerped) end
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
	    if lerped then handleChild(lerped) end
	 else
	    handleChild(root.children[root.frame])
	 end
      end
   else
      love.graphics.setStencilTest()
      for i = 1, #root.children do
	 local shape = root.children[i]
	 handleChild(shape)
      end
      --love.graphics.setStencilTest()
   end
   love.graphics.setStencilTest()


end

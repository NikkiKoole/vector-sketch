-- these utils are used when you wanna use the shapes and all in another application


--https://love2d.org/forums/viewtopic.php?t=1401
function GetSplinePos(tab, percent, tension)		--returns the position at 'percent' distance along the spline.
	if(tab and (#tab >= 4)) then
		local pos = (((#tab)/2) - 1) * percent
		local lowpnt, percent_2 = math.modf(pos)
		
		local i = (1+lowpnt*2)
		local p1x = tab[i]
		local p1y = tab[i+1]
		local p2x = tab[i+2]
		local p2y = tab[i+3]

		local p0x = tab[i-2]
		local p0y = tab[i-1]
		local p3x = tab[i+4]
		local p3y = tab[i+5]

                local tension = tension or .5
		local t1x = 0
		local t1y = 0
		if(p0x and p0y) then
                   t1x = (1.0 - tension) * (p2x - p0x)
                   t1y =  (1.0 - tension) * (p2y - p0y)
		end
		local t2x = 0
		local t2y = 0
		if(p3x and p3y) then
			t2x =  (1.0 - tension) * (p3x - p1x)
			t2y =  (1.0 - tension) * (p3y - p1y)
		end
			
		local s = percent_2
		local s2 = s*s
		local s3 = s*s*s
		local h1 = 2*s3 - 3*s2 + 1
		local h2 = -2*s3 + 3*s2
		local h3 = s3 - 2*s2 + s
		local h4 = s3 - s2
		local px = (h1*p1x) + (h2*p2x) + (h3*t1x) + (h4*t2x)
		local py = (h1*p1y) + (h2*p2y) + (h3*t1y) + (h4*t2y)
		
		return px, py
	end
end



function lerp(v0, v1, t) 
    return v0*(1-t)+v1*t
end

function evenlySpreadPath(result, path, index, running, spacing)
   local here = path[index]
   if index == #path then return end
   
   local nextIndex = index+1
   local there = path[nextIndex]
   local d = getDistance(here[1], here[2], there[1], there[2])
   if (d + running) < spacing then

      running = running + d
      return evenlySpreadPath(result, path, index+1, running, spacing)
   else
      if running >= d then
         --print('missing one here i think', running/d)
         local x = lerp(here[1], there[1], 1 or running/d)
         local y = lerp(here[2], there[2], 1 or running/d)
         --if index < #path-2 then
            table.insert(result, {x,y, {1,0,0}} )
         --end
         --running = d
      end
      
      while running <= d do

         local x = lerp(here[1], there[1], running/d)
         local y = lerp(here[2], there[2], running/d)
         table.insert(result, {x,y, {1,0,1}})
      
         running = running + spacing
      end
      
      if running >= d then
         running = running - d
         return evenlySpreadPath(result, path, index+1, running, spacing)
      end
   end
   

end


function getLengthOfPath(path)
   local result = 0
   for i = 1, #path-1 do
      local a = path[i]
      local b = path[i+1]
      result = result + getDistance(a[1], a[2], b[1], b[2])

   end
   return result
end


function getDistance(x1,y1,x2,y2)
      local dx = x1 - x2
      local dy = y1 - y2
      local distance =  math.sqrt ((dx*dx) + (dy*dy))

      return distance
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
   local count = mesh:getVertexCount()
   local px,py = body._globalTransform:inverseTransformPoint(mx, my)
   for i = 1, count, 3 do
      
      if pointInTriangle({px,py}, {mesh:getVertex(i)}, {mesh:getVertex(i+1)}, {mesh:getVertex(i+2)}) then
	 return true
      end
      
   end
   return false
end

function getIndex(item)
   if (item) then
      for k,v in ipairs(item._parent.children) do
         if v == item then return k end
      end
   end
   return -1
end



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

   if (shape.depth ~= nil) then
      hack.scale = mapInto(shape.depth, depthMinMax.min, depthMinMax.max, depthScaleFactors.min, depthScaleFactors.max)
      hack.relativeScale = (1.0/ hack.scale) * hack.scale
      hack.push()
   end
   
   
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
      renderThings(shape)
      love.graphics.setStencilTest()
   --else
     -- print()
      --print(inspect(poly.makeVertices(shape)))
   end

   if currentNode ~= shape then
      if (shape.mesh and not shape.mask) then


         
	 love.graphics.setColor(shape.color)
         love.graphics.draw(shape.mesh, shape._parent._globalTransform )

         if (shape.borderMesh) then
            love.graphics.setColor(0,0,0)
            love.graphics.draw(shape.borderMesh, shape._parent._globalTransform )
         end
         
         
         --print('main-utils todo')
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
      local editing = poly.makeVertices(shape)
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

   if (shape.depth ~= nil) then
      hack:pop()
   end
   
   
end

function unpackNodePointsLoop(points)
   local unpacked = {}
   --unpacked[1] = points[#points][1]
   --unpacked[2] = points[#points][2]
      
   for i = 0, #points do
      local nxt = i == #points and 1 or i+1
      unpacked[1 + (i*2)] = points[nxt][1]
      unpacked[2 + (i*2)] =  points[nxt][2]
   end

   -- the catmul splines look better when wrapped around
   -- so i double up and use .5 -> 1 t
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
      --unpacked[(#points*2)+3] =   points[2][1]
      -- unpacked[(#points*2)+4] =   points[2][2]
   end

   return unpacked
   
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
      print('got here?')
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

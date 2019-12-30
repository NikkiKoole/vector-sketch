require 'util'
flux = require "flux"

poly = require 'poly'
inspect = require 'inspect'

function love.keypressed(key)
   if key == "escape" then love.event.quit() end
end

function parseFile(url)
   local contents, size = love.filesystem.read( url)
   local parsed = (loadstring("return ".. contents)())
   return parsed
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

function mapInto(x, in_min, in_max, out_min, out_max)
   return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end


function love.draw()
   love.graphics.clear(0.52,0.56,0.28)
   renderThings(root)
end

function love.update(dt)
   flux.update(dt)

   if love.math.random() < 0.09 then
      --for i = 1, #tomatoes do
      local index = math.floor((love.math.random() * #root.children + 1))
      local firstMouth = findNodeByName(root.children[index], 'mond')
      if firstMouth.needsLerp == false or firstMouth.needsLerp == nil then
	 firstMouth.needsLerp = true
	 local d1 = 0.1 + love.math.random()*0.2
	 local d2 = 0.1 + love.math.random()*0.2
	 local close = love.math.random() * 0.2 + 0.1
	 local open = love.math.random() * 0.2 + 0.1

	 local tween = flux.to(firstMouth, close, {lerpValue=1}):delay(d1)
	    :after(firstMouth, open, {lerpValue=0}):delay(d2)

	 :oncomplete(function() firstMouth.needsLerp = false end)
      end
   --end
   
      
   end
   
end

---

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


function meshAll(root) -- this needs to be done recursive
   for i=1, #root.children do
      if (not root.children[i].folder) then
	 root.children[i].mesh = makeMeshFromVertices(makeVertices(root.children[i]))
      else
	 meshAll(root.children[i])
      end
   end
end

function handleChild(shape)
   -- TODO i dont want to directly depend on my parents global transform that is not correct
   -- this gets in the way of lerping between nodes...
   if not shape then return end
   if shape.mask then
      local mesh
      if currentNode ~= shape then
	 mesh = shape.mesh -- the standard way of rendering
      else
	 mesh =  makeMeshFromVertices(makeVertices(shape)) -- realtime iupdating the thingie
      end
      
      love.graphics.stencil(
	 function()
	    love.graphics.draw(mesh, shape._parent._globalTransform )
	 end, "replace", 1)
      love.graphics.setStencilTest("equal", 1)
   end
   if shape.folder then
      renderThings(shape)
   end

   if currentNode ~= shape then 
      if (shape.mesh and not shape.mask) then
	 love.graphics.setColor(shape.color)
	 love.graphics.draw(shape.mesh, shape._parent._globalTransform )
      end
   end
   if currentNode == shape then
      local editing = makeVertices(shape)
      if (editing and #editing > 0) then
	 local editingMesh = makeMeshFromVertices(editing)
	 love.graphics.setColor(shape.color)
	 love.graphics.draw(editingMesh,  shape._parent._globalTransform )
      end
   end
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


function renderThings(root)

   ---- these calculations are only needed when some local transforms have changed

   local tg = root.transforms.g
   local tl = root.transforms.l
   local pg = nil
   if (root._parent) then
      pg = root._parent._globalTransform
   end
   root._localTransform =  love.math.newTransform( tl[1], tl[2], tl[3], tl[4], tl[5], tl[6],tl[7])
   root._globalTransform = pg and (pg * root._localTransform) or root._localTransform
   ----
   
   if (root.keyframes) then
      --print("coming in here!", root.lerpValue)
      -- if currentNode == root then
      -- 	 local lerped = createLerpedChild(root.children[1], root.children[2], root.lerpValue)
      -- 	 if lerped then handleChild(lerped) end
      -- else
      -- 	 handleChild(root.children[root.frame])
      -- end

      -- TODO finda way to cache teh result and reuse , alos whne not tweening i dont wanna
      -- do all the unneeded calcs here
      if (not root.lastLerp or root.needsLerp) then
	 --print('doing the lerping calcs')
       local lerped = createLerpedChild(root.children[1], root.children[2], root.lerpValue)
       if lerped then handleChild(lerped) end
       root.lastLerp = lerped
      else
	 --print('reusing lastlerp')
	  handleChild(root.lastLerp)
      end
      
      
   else
      for i = 1, #root.children do
	 local shape = root.children[i]
	 handleChild(shape)   
      end
   end
   
   love.graphics.setStencilTest()
end

----

function love.mousemoved(x,y)
   local tomatoes = root.children
   for i =1, #tomatoes do
   --local i = 6
   local body = tomatoes[i]
   if body._globalTransform then
      
      local linkerOog = findNodeByName(tomatoes[i], 'linkeroog')
      local linkerPupil = findNodeByName(linkerOog, 'pupil')
      if (linkerPupil._globalTransform) then
	 local lx, ly =  (linkerPupil._globalTransform):inverseTransformPoint(x, y)
	 local r = math.atan2 (ly, lx)
	 local distance = math.sqrt((lx *lx) + (ly * ly))
	 local radius = math.min(3, distance)
	 local dx = radius * math.cos(r)
	 local dy = radius * math.sin(r)
	 linkerPupil.transforms.l[1] = startPos[i].leftEye[1]+dx
	 linkerPupil.transforms.l[2] = startPos[i].leftEye[2]+dy
      end
      local rechterOog = findNodeByName(tomatoes[i], 'rechteroog')
      local rechterPupil = findNodeByName(rechterOog, 'pupil')
      if (rechterPupil._globalTransform) then
	 local lx, ly =  (rechterPupil._globalTransform):inverseTransformPoint(x, y)
	 local r = math.atan2 (ly, lx)
	 local distance = math.sqrt((lx *lx) + (ly * ly))
	 local radius = math.min(3, distance)
	 local dx = radius * math.cos(r)
	 local dy = radius * math.sin(r)
	 rechterPupil.transforms.l[1] = startPos[i].rightEye[1]+dx
	 rechterPupil.transforms.l[2] = startPos[i].rightEye[2]+dy
      end
   end
 
   end
end


function love.load()
   love.window.setMode(1024, 768, {resizable=true, vsync=true, minwidth=400, minheight=300, msaa=2, highdpi=true})

   root = {
      folder = true,
      name = 'root',
      transforms =  {g={0,0,0,1,1,0,0},l={600,800,0,4,4,0,0}},
      
   }

   local tomatoes = parseFile('tomatoes.txt')
   root.children = tomatoes

   startPos = {}
   for i =1, #tomatoes do
      local linkerOog = findNodeByName(tomatoes[i], 'linkeroog')
      local linkerPupil = findNodeByName(linkerOog, 'pupil')
      local rechterOog = findNodeByName(tomatoes[i], 'rechteroog')
      local rechterPupil = findNodeByName(rechterOog, 'pupil')
      startPos[i] = {leftEye = {linkerPupil.transforms.l[1], linkerPupil.transforms.l[2]},
		     rightEye = {rechterPupil.transforms.l[1], rechterPupil.transforms.l[2]}}
   end

     

   parentize(root)
   meshAll(root)
end

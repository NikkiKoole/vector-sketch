-- these utils are used when you wanna use the shapes and all in another application

local numbers = require 'lib.numbers'
local lerp = numbers.lerp
local parentize = require 'lib.parentize'
local hit = require 'lib.hit'
local mesh = require 'lib.mesh'





function recursiveLookForHitArea(node)
   if not node then return false end
   print('recusricve looking', node.name)

   if node.points then
      if string.find(node.name, "-hitarea") then
         return true
      end

   else
      if node.children then
         for i = 1, #node.children do
            local result = recursiveLookForHitArea(node.children[i])
            if result then
               return result
            end
         end
      end
   end
   return false
end


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

function lerpNodes(left, right, root, t)
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

-- this function is just for the bacthMeshcurrently
---- these calculations are only needed when some local transforms have changed
-- they ought t o be more optimized
-- in short: this needs a isDirty flag of sorts
-- take the logic from the handdrawn-ecs renderrecursive



function renderThingsWithKeyFrames(root)

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

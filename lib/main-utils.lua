-- these utils are used when you wanna use the shapes and all in another application

local numbers = require 'lib.numbers'
local lerp = numbers.lerp
local parentize = require 'lib.parentize'


function transferPoint(xI, yI, source, destination)

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
   if (xBu == xCu) then xC = xC + ADDING end
   if (xAu == xDu) then xDu = xDu + ADDING end
   if (xAu == xBu) then xBu = xBu + ADDING end
   if (xDu == xCu) then xCu = xCu + ADDING end
   --print(xC,xDu,xBu,xCu)
   local kBC = (yBu - yCu) / (xBu - xCu)
   local kAD = (yAu - yDu) / (xAu - xDu)
   local kAB = (yAu - yBu) / (xAu - xBu)
   local kDC = (yDu - yCu) / (xDu - xCu)

   if (kBC == kAD) then kAD = kAD + ADDING end
   local xE = (kBC * xBu - kAD * xAu + yAu - yBu) / (kBC - kAD)
   local yE = kBC * (xE - xBu) + yBu

   if (kAB == kDC) then kDC = kDC + ADDING end
   local xF = (kAB * xBu - kDC * xCu + yCu - yBu) / (kAB - kDC)
   local yF = kAB * (xF - xBu) + yBu

   if (xE == xF) then xF = xF + ADDING end
   local kEF = (yE - yF) / (xE - xF)

   if (kEF == kAB) then kAB = kAB + ADDING end
   local xG = (kEF * xDu - kAB * xAu + yAu - yDu) / (kEF - kAB)
   local yG = kEF * (xG - xDu) + yDu

   if (kEF == kBC) then kBC = kBC + ADDING end
   local xH = (kEF * xDu - kBC * xBu + yBu - yDu) / (kEF - kBC)
   local yH = kEF * (xH - xDu) + yDu

   local rG = (yC - yI) / (yC - yA)
   local rH = (xI - xA) / (xC - xA)

   local xJ = (xG - xDu) * rG + xDu
   local yJ = (yG - yDu) * rG + yDu

   local xK = (xH - xDu) * rH + xDu
   local yK = (yH - yDu) * rH + yDu

   if (xF == xJ) then xJ = xJ + ADDING end
   if (xE == xK) then xK = xK + ADDING end
   local kJF = (yF - yJ) / (xF - xJ) --//23
   local kKE = (yE - yK) / (xE - xK) --//12

   local xKE
   if (kJF == kKE) then kKE = kKE + ADDING end
   local xIu = (kJF * xF - kKE * xE + yE - yF) / (kJF - kKE)
   local yIu = kJF * (xIu - xJ) + yJ

   local b = { x = xIu, y = yIu }
   --b.x=math.round(b.x)
   --b.y=math.round(b.y)
   return b
end





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

         local hit = isMouseInMesh(mx, my, parent, parent.children[i].mesh)
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

function unpackNodePointsLoop(points)
   local unpacked = {}

   for i = 0, #points do
      local nxt = i == #points and 1 or i + 1
      unpacked[1 + (i * 2)] = points[nxt][1]
      unpacked[2 + (i * 2)] = points[nxt][2]
   end

   for i = 0, #points do
      local nxt = i == #points and 1 or i + 1
      unpacked[(#points * 2) + 1 + (i * 2)] = points[nxt][1]
      unpacked[(#points * 2) + 2 + (i * 2)] = points[nxt][2]
   end

   return unpacked
end

function unpackNodePoints(points, noloop)
   local unpacked = {}
   if #points >= 1 then
      for i = 0, #points - 1 do
         unpacked[1 + (i * 2)] = points[i + 1][1]
         unpacked[2 + (i * 2)] = points[i + 1][2]
      end

      -- make it go round
      if noloop == nil then
         unpacked[(#points * 2) + 1] = points[1][1]
         unpacked[(#points * 2) + 2] = points[1][2]
      end
   end

   return unpacked

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
      root.mesh = makeMeshFromVertices(makeVertices(root), root.type, root.texture)
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

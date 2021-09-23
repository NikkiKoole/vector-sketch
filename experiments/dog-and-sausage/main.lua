package.path = package.path .. ";../../?.lua"

require 'editor-utils'
require 'poly'
require 'basics'
require 'main-utils'
require 'toolbox'

--require 'util'
--poly = require 'poly'
inspect = require 'vendor.inspect'
flux = require "vendor.flux"

function love.keypressed(key)
   if key == "escape" then love.event.quit() end
end


-- function parseFile(url)
--    local contents, size = love.filesystem.read( url)
--    local parsed = (loadstring("return ".. contents)())
--    return parsed
-- end

-- function parentize(node)
--    for i = 1, #node.children do
--       node.children[i]._parent = node
--       if (node.children[i].folder) then
-- 	 parentize(node.children[i])
--       end
--    end
-- end
-- function meshAll(root) -- this needs to be done recursive

--    for i=1, #root.children do
--       if (not root.children[i].folder) then
-- 	 local vertices = makeVertices(root.children[i])
-- 	 root.children[i].mesh = makeMeshFromVertices(vertices)
--       else
-- 	 meshAll(root.children[i])
--       end
--    end
-- end

-- function renderThings(root)

--    ---- these calculations are only needed when some local transforms have changed
--    local tg = root.transforms.g
--    local tl = root.transforms.l
--    local pg = nil
--    if (root._parent) then
--       pg = root._parent._globalTransform
--    end

--    root._localTransform =  love.math.newTransform( tl[1], tl[2], tl[3], tl[4], tl[5], tl[6],tl[7])
--    root._globalTransform = pg and (pg * root._localTransform) or root._localTransform
--    ----

--    for i = 1, #root.children do

--       local shape = root.children[i]

--       if shape.folder then
-- 	 renderThings(shape)
--       end
--       if currentNode ~= shape then
-- 	 if (shape.mesh) then
-- 	    love.graphics.setColor(shape.color)
-- 	    love.graphics.draw(shape.mesh, shape._parent._globalTransform)
-- 	 end
--       end
--       if currentNode == shape then
-- 	 local editing = makeVertices(shape)
-- 	 if (editing and #editing > 0) then
-- 	    local editingMesh = makeMeshFromVertices(editing)
-- 	    love.graphics.setColor(shape.color)
-- 	    love.graphics.draw(editingMesh,  shape._parent._globalTransform)
-- 	 end
--       end
--    end
-- end

function love.update(dt)
   flux.update(dt)
   worst.transforms.l[3] = worst.transforms.l[3] + .0001/dt
end

function love.draw()
   local m = makeBackdropMesh()
   love.graphics.draw(m)
   renderThings(root)
end


-- function findNodeByName(root, name)
--    if (root.name == name) then
--       return root
--    end
--    if root.children then
--       for i=1, #root.children do
-- 	 local result = findNodeByName(root.children[i], name)
-- 	 if result then return result end
--       end
--    end
--    return nil
   
-- end
-- function mapInto(x, in_min, in_max, out_min, out_max)
--    return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
-- end

function love.mousemoved(x,y)
   if (leftPupil._globalTransform) then
      local lx, ly = leftPupil._globalTransform:inverseTransformPoint( x , y )
      local r = math.atan2 (ly, lx)
      local dx = 2 * math.cos(r)
      local dy = 2 * math.sin(r)
      local newScale = love.math.random() * 0.5 + 0.75
      flux.to(leftPupil.transforms.l, 1/(math.abs(dx) + math.abs(dy)), {[1]= leftPupil.startPos[1]+dx, [2]= leftPupil.startPos[2]+dy, [4]=newScale, [5]=newScale})
   end
   if (rightPupil._globalTransform) then
      local rx, ry = rightPupil._globalTransform:inverseTransformPoint( x , y )
      local r = math.atan2 (ry, rx)
      local dx = 3 * math.cos(r)
      local dy = 2 * math.sin(r)
      local newScale = love.math.random() * 0.5 + 0.75
      flux.to(rightPupil.transforms.l, 1/(math.abs(dx) + math.abs(dy)), {[1]= rightPupil.startPos[1]+dx, [2]= rightPupil.startPos[2]+dy, [4]=newScale, [5]=newScale})
   end
   if (root._globalTransform) then
      local rx, ry = root._globalTransform:inverseTransformPoint( x , y )
      worst.transforms.l[1] = rx
      worst.transforms.l[2] = ry
   end

   if (snuit._globalTransform) then
      local rx, ry = snuit._globalTransform:inverseTransformPoint( x , y )
      local distance = math.sqrt((rx *rx) + (ry * ry))
      local diff2 = mapInto(distance, 0, 150, 1.1, 1)
      local diff = mapInto(love.math.random(), 0, 1, -0.01, 0.01)
      local newAngle = diff
      
      flux.to(snuit.transforms.l, 0.3, {[3]=newAngle, [4]=diff2, [5]=diff2})
   end
   
end


function makeBackdropMesh()
   local format = {
    {"VertexPosition", "float", 2}, -- The x,y position of each vertex.
    {"VertexColor", "byte", 4} -- The r,g,b,a color of each vertex.
   }
   local w,h = love.graphics.getDimensions()
   
   local vertices = {
      {
   	 -- top-left corner (red-tinted)
   	 0, 0, -- position of the vertex
   	 1, 0, 0, -- color of the vertex
      },
      {
   	 -- top-right corner (green-tinted)
   	w, 0,
   	0, 1, 0
      },
      {
   	 -- bottom-right corner (blue-tinted)
   	 w, h,
   	 0, 0, 1
      },
      {
   	 -- bottom-left corner (yellow-tinted)
   	 0, h,
   	 1, 1, 0
      },
   }
   local mesh = love.graphics.newMesh(format, vertices)
   return mesh
end


function love.load()
   love.window.setMode(1024, 768, {resizable=true, vsync=true, minwidth=400, minheight=300, msaa=2, highdpi=true})


   root = {
      folder = true,
      name = 'root',
      transforms =  {g={0,0,0,1,1,0,0},l={1024/2,768/2,0,4,4,0,0}},
      
   }

   local doggo = parseFile('doggo__.polygons.txt')
   local worst_ =  parseFile('worst.polygons.txt')

   root.children = {doggo[1], worst_[1]}
   parentize(root)
   meshAll(root)

   worst = findNodeByName(root, 'worst')
   leftEye = findNodeByName(root, 'left eye')
   leftPupil = findNodeByName(leftEye, 'pupil')
   leftPupil.startPos = {leftPupil.transforms.l[1], leftPupil.transforms.l[2]}
   rightEye = findNodeByName(root, 'right eye')
   rightPupil = findNodeByName(rightEye, 'pupil')
   rightPupil.startPos = {rightPupil.transforms.l[1], rightPupil.transforms.l[2]}

   snuit = findNodeByName(root, 'snuit')
   
   -- flux.to(leftEye.transforms.l, 1, {[4]= 2, [5]= 2})
   --    :after(leftEye.transforms.l, 1, {[4]= 1, [5]= 1})
   -- flux.to(rightEye.transforms.l, 1, {[4]= 2, [5]= 2})
   --    :after(rightEye.transforms.l, 1, {[4]= 1, [5]= 1})

end

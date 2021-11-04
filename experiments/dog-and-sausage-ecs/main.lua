package.path = package.path .. ";../../?.lua"

require 'lib.scene-graph'
require 'lib.editor-utils'
require 'lib.poly'
require 'lib.basics'
require 'lib.main-utils'
require 'lib.toolbox'

inspect = require 'vendor.inspect'
flux = require "vendor.flux"


Concord = require 'vendor.concord.init'

--local Entity     = Concord.entity
--local Component  = Concord.component
--local System     = Concord.system
--local World      = Concord.world

-- Containers
--local Components  = Concord.components

Concord.component("drawable")
Concord.component("pupil")


local myWorld = Concord.world()

Concord.component(
   'transforms',
   function(c, value)
      c.transforms = value
   end
)

Concord.component(
   "startPos",
   function(c, x, y)
      c.x =x
      c.y =y
   end
)


local MoveWithMouseSystem = Concord.system({pool = {'transforms', 'drawable'}})
function MoveWithMouseSystem:update(dt)
   local mx,my =love.mouse.getPosition()

   if root.transforms._g then
      local rx, ry = root.transforms._g:inverseTransformPoint( mx , my )
      for _, e in ipairs(self.pool) do
	 print(inspect(e.transforms))
         e.transforms.transforms.l[1] = rx
         e.transforms.transforms.l[2] = ry
      end
   end
end

local MovePupilToMouseSystem = Concord.system({pool = {'transforms', 'pupil', 'startPos'}})
function MovePupilToMouseSystem:update(dt)
   local mx,my =love.mouse.getPosition()
   print('yohoo')
   for _, e in ipairs(self.pool) do
               --setTransforms(e)

      if (e.transforms.transforms._g) then
         --print('e.transforms._g',inspect(e.transforms._g))

         --print('jowes',mx,my)
         local lx, ly = e.transforms.transforms._g:inverseTransformPoint( mx , my )
         local r = math.atan2(ly, lx) --* 2*math.pi -math.pi/2
         print(r)
--         print(r, 'pos',mx,my, 'brok')

         local dx = 2 * math.cos(r)
         local dy = 2 * math.sin(r)
         local newScale = love.math.random() * 0.5 + 0.75
         e.transforms.transforms.l[1]= e.startPos.x+dx
         e.transforms.transforms.l[2]= e.startPos.y+dy
         --e.transforms.l[4] = newScale
         --e.transforms.l[5] = newScale
      --else
        -- setTransforms(e)
      end
   end

end



myWorld:addSystems(MoveWithMouseSystem, MovePupilToMouseSystem)


function love.keypressed(key)
   if key == "escape" then love.event.quit() end
end



function love.mousemoved(x,y)
   if (false and leftPupil.transforms._g) then
      print('leftPupil.transforms._g',leftPupil.transforms._g)
      local lx, ly = leftPupil.transforms._g:inverseTransformPoint( x , y )

      local r = math.atan2 (ly, lx)
      print(r, 'pos',x,y)
      local dx = 2 * math.cos(r)
      local dy = 2 * math.sin(r)
      local newScale = love.math.random() * 0.5 + 0.75
      leftPupil.transforms.l[1] = leftPupil.startPos[1]+dx
      leftPupil.transforms.l[2] = leftPupil.startPos[2]+dy
--      flux.to(leftPupil.transforms.l, 1/(math.abs(dx) + math.abs(dy)), {[1]= leftPupil.startPos[1]+dx, [2]= leftPupil.startPos[2]+dy, [4]=newScale, [5]=newScale})
   end
   -- if (rightPupil.transforms._g) then
   --    local rx, ry = rightPupil.transforms._g:inverseTransformPoint( x , y )
   --    local r = math.atan2 (ry, rx)
   --    local dx = 2 * math.cos(r)
   --    local dy = 2 * math.sin(r)
   --    local newScale = love.math.random() * 0.5 + 0.75
   --    flux.to(rightPupil.transforms.l, 1/(math.abs(dx) + math.abs(dy)), {[1]= rightPupil.startPos[1]+dx, [2]= rightPupil.startPos[2]+dy, [4]=newScale, [5]=newScale})
   -- end
   if (snuit.transforms._g) then
      local rx, ry = snuit.transforms._g:inverseTransformPoint( x , y )
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
      transforms =  {l={1024/2,768/2,0,4,4,0,0}},

   }

   local doggo = parseFile('assets/doggo___.polygons.txt')
   local worst_ =  parseFile('assets/worst_.polygons.txt')

   root.children = {doggo[1], worst_[1]}
   parentize(root)
   meshAll(root)

   worst = findNodeByName(root, 'worst')
--   print(inspect(worst.transforms))
   leftEye = findNodeByName(root, 'left eye')
   leftPupil = findNodeByName(leftEye, 'pupil')
   leftPupil.startPos = {leftPupil.transforms.l[1], leftPupil.transforms.l[2]}
   rightEye = findNodeByName(root, 'right eye')
   rightPupil = findNodeByName(rightEye, 'pupil')
   rightPupil.startPos = {rightPupil.transforms.l[1], rightPupil.transforms.l[2]}

   snuit = findNodeByName(root, 'snuit')

   --setTransforms(worst)
   --setTransforms(leftPupil)
   print('init', leftPupil.transforms._g)


   --print((MoveSystem:getName()))
 --   local myEntity1 = Concord.entity(myWorld)
 --      :give('transforms', leftPupil)
 --      :give('startPos', leftPupil.transforms.l[1], leftPupil.transforms.l[2])
-- --      :give('transforms._g', leftPupil.transforms._g)

  --     :give('pupil')

  -- local myEntity1 = Concord.entity(myWorld)
  --    :give('transforms', rightPupil.transforms)
  --    :give('startPos', rightPupil.transforms.l[1], rightPupil.transforms.l[2])
--      :give('pupil')

   local myEntity1 = Concord.entity(myWorld)
      :give('transforms', worst.transforms)
      :give('drawable')



end

function myWorld:onEntityAdded(e)
   -- Do something
   print('added something!')
end

function love.update(dt)
   myWorld:emit("update", dt)
   --print(inspect(myWorld:getEntities()))
--   flux.update(dt)
--   worst.transforms.l[3] = worst.transforms.l[3] + 0.01/dt
end

function love.draw()
   local m = makeBackdropMesh()
   love.graphics.draw(m)
   renderThings(root)
   myWorld:emit("draw")

end

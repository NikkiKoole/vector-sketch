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


Concord.component("mousefollowing")
Concord.component("snoutbehaviour")
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


local MoveWithMouseSystem = Concord.system({pool = {'transforms', 'mousefollowing'}})
function MoveWithMouseSystem:update(dt)
   local mx,my =love.mouse.getPosition()

   if root.transforms._g then
      local rx, ry = root.transforms._g:inverseTransformPoint( mx , my )
      for _, e in ipairs(self.pool) do
	 local transforms = e.transforms.transforms
         transforms.l[1] = rx
         transforms.l[2] = ry
      end
   end
end

local MovePupilToMouseSystem = Concord.system({pool = {'transforms', 'pupil', 'startPos'}})
function MovePupilToMouseSystem:update(dt)
   local mx,my =love.mouse.getPosition()

   for _, e in ipairs(self.pool) do
      local transforms = e.transforms.transforms
      if (transforms._g) then
         local lx, ly = transforms._g:inverseTransformPoint( mx , my )
         local r = math.atan2(ly, lx)
         local dx = 2 * math.cos(r)
         local dy = 2 * math.sin(r)
         transforms.l[1] = e.startPos.x + dx
         transforms.l[2] = e.startPos.y + dy
      end
   end

end
function MovePupilToMouseSystem:pressed(x,y, elem)
   --print('movepupil sytem receiving click', x,y)
   local newScale = love.math.random()*2 -1 + 1
   for _, e in ipairs(self.pool) do
      local transforms = e.transforms.transforms
      transforms.l[4] = newScale
      transforms.l[5] = newScale
   end
end


local SnoutWithMouseSystem = Concord.system({pool = {'transforms', 'snoutbehaviour'}})
function SnoutWithMouseSystem:update(dt)
   local mx,my =love.mouse.getPosition()

   if root.transforms._g then
      local rx, ry = root.transforms._g:inverseTransformPoint( mx , my )
      for _, e in ipairs(self.pool) do
	 local transforms = e.transforms.transforms
	 local distance = math.sqrt((rx *rx) + (ry * ry))
	 local newScale = mapInto(distance, 0, 150, 1.1, 1)
	 local diff = mapInto(love.math.random(), 0, 1, -0.01, 0.01)
	 local newAngle = diff

         transforms.l[3] = newAngle
	 transforms.l[4] = newScale
         transforms.l[5] = newScale
      end
   end
end


myWorld:addSystems(MoveWithMouseSystem, MovePupilToMouseSystem, SnoutWithMouseSystem)


function love.keypressed(key)
   if key == "escape" then love.event.quit() end
end



function love.mousemoved(x,y)


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
   	 0, 1, 1
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

   leftEye = findNodeByName(root, 'left eye')
   leftPupil = findNodeByName(leftEye, 'pupil')

   rightEye = findNodeByName(root, 'right eye')
   rightPupil = findNodeByName(rightEye, 'pupil')

   snuit = findNodeByName(root, 'snuit')


   Concord.entity(myWorld)
      :give('transforms', leftPupil.transforms)
      :give('startPos', leftPupil.transforms.l[1], leftPupil.transforms.l[2])
      :give('pupil')

   Concord.entity(myWorld)
      :give('transforms', rightPupil.transforms)
      :give('startPos', rightPupil.transforms.l[1], rightPupil.transforms.l[2])
      :give('pupil')

   Concord.entity(myWorld)
      :give('transforms', worst.transforms)
      :give('mousefollowing')

   Concord.entity(myWorld)
      :give('transforms', snuit.transforms)
      :give('snoutbehaviour')

end

function myWorld:onEntityAdded(e)
   -- Do something
   print('added something!')
end

function love.mousepressed(x,y)
   --print('mousepressed', x,y)
   myWorld:emit('pressed',x,y, leftPupil)
end

function love.update(dt)
   myWorld:emit("update", dt)
end

function love.draw()
   local m = makeBackdropMesh()
   love.graphics.draw(m)
   renderThings(root)
--   myWorld:emit("draw")
end
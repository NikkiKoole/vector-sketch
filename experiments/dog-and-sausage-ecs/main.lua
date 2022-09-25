package.path = package.path .. ";../../?.lua"

local inspect = require 'vendor.inspect'
local flux = require "vendor.flux"

local numbers = require 'lib.numbers'
local parse = require 'lib.parse-file'
local render = require 'lib.render'
local mesh = require 'lib.mesh'
local parentize = require 'lib.parentize'
local formats = require 'lib.formats'
local node = require 'lib.node'
local gradient = require 'lib.gradient'

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
      c.x = x
      c.y = y
   end
)


local MoveWithMouseSystem = Concord.system({ pool = { 'transforms', 'mousefollowing' } })
function MoveWithMouseSystem:update(dt)
   local mx, my = love.mouse.getPosition()

   if root.transforms._g then
      local rx, ry = root.transforms._g:inverseTransformPoint(mx, my)
      for _, e in ipairs(self.pool) do
         local transforms = e.transforms.transforms
         transforms.l[1] = rx
         transforms.l[2] = ry
      end
   end
end

local MovePupilToMouseSystem = Concord.system({ pool = { 'transforms', 'pupil', 'startPos' } })
function MovePupilToMouseSystem:update(dt)
   local mx, my = love.mouse.getPosition()

   for _, e in ipairs(self.pool) do
      local transforms = e.transforms.transforms
      if (transforms._g) then
         local lx, ly = transforms._g:inverseTransformPoint(mx, my)
         local r = math.atan2(ly, lx)
         local dx = 2 * math.cos(r)
         local dy = 2 * math.sin(r)
         transforms.l[1] = e.startPos.x + dx
         transforms.l[2] = e.startPos.y + dy
      end
   end

end

function MovePupilToMouseSystem:pressed(x, y, elem)
   --print('movepupil sytem receiving click', x,y)
   local newScale = love.math.random() * 2 - 1 + 1
   for _, e in ipairs(self.pool) do
      local transforms = e.transforms.transforms
      transforms.l[4] = newScale
      transforms.l[5] = newScale
   end
end

local SnoutWithMouseSystem = Concord.system({ pool = { 'transforms', 'snoutbehaviour' } })
function SnoutWithMouseSystem:update(dt)
   local mx, my = love.mouse.getPosition()

   if root.transforms._g then
      local rx, ry = root.transforms._g:inverseTransformPoint(mx, my)
      for _, e in ipairs(self.pool) do
         local transforms = e.transforms.transforms
         local distance = math.sqrt((rx * rx) + (ry * ry))
         local newScale = numbers.mapInto(distance, 0, 150, 1.1, 1)
         local diff = numbers.mapInto(love.math.random(), 0, 1, -0.01, 0.01)
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

function love.mousemoved(x, y)


end

function love.load()
   love.window.setMode(1024, 768, { resizable = true, vsync = true, minwidth = 400, minheight = 300, msaa = 2,
      highdpi = true })


   root = {
      folder = true,
      name = 'root',
      transforms = { l = { 1024 / 2, 768 / 2, 0, 4, 4, 0, 0 } },
   }

   backdrop = gradient.makeBackdropMesh()
   local doggo = parse.parseFile('assets/doggo___.polygons.txt')[1]
   local worst_ = parse.parseFile('assets/worst_.polygons.txt')[1]
   --   print(inspect(worst_))
   root.children = { doggo, worst_ }
   parentize.parentize(root)
   mesh.meshAll(root)

   worst = node.findNodeByName(root, 'worst')

   leftEye = node.findNodeByName(root, 'left eye')
   leftPupil = node.findNodeByName(leftEye, 'pupil')

   rightEye = node.findNodeByName(root, 'right eye')
   rightPupil = node.findNodeByName(rightEye, 'pupil')

   snuit = node.findNodeByName(root, 'snuit')


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

   local myEntity = Concord.entity()
   myEntity
       :give('transforms', snuit.transforms)
       :give('snoutbehaviour')

   myWorld:addEntity(myEntity)

   --Concord.entity(myWorld)
   --   :give('transforms', snuit.transforms)
   --   :give('snoutbehaviour')

end

function myWorld:onEntityAdded(e)
   -- Do something
   print('added something!')
end

function love.mousepressed(x, y)
   --print('mousepressed', x,y)
   myWorld:emit('pressed', x, y, leftPupil)
end

function love.update(dt)
   myWorld:emit("update", dt)
end

function love.draw()

   love.graphics.draw(backdrop)
   render.renderThings(root)
   --   myWorld:emit("draw")
end

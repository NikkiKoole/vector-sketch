package.path = package.path .. ";../../?.lua"

local inspect = require 'vendor.inspect'
local flux = require "vendor.flux"

local numbers = require 'lib.numbers'
local parentize = require 'lib.parentize'
local parse = require 'lib.parse-file'
local render = require 'lib.render'
local mesh = require 'lib.mesh'
local formats = require 'lib.formats'
local node = require 'lib.node'
local gradient = require 'lib.gradient'

function love.keypressed(key)
   if key == "escape" then love.event.quit() end
end

function love.update(dt)
   flux.update(dt)
   worst.transforms.l[3] = worst.transforms.l[3] + 0.001 / dt
end

function love.draw()

   love.graphics.draw(backdrop)
   render.renderThings(root)
end

function love.mousemoved(x, y)
   if (leftPupil.transforms._g) then
      local lx, ly = leftPupil.transforms._g:inverseTransformPoint(x, y)
      local r = math.atan2(ly, lx)
      local dx = 2 * math.cos(r)
      local dy = 2 * math.sin(r)
      local newScale = love.math.random() * 0.5 + 0.75
      flux.to(leftPupil.transforms.l, 1 / (math.abs(dx) + math.abs(dy)),
         { [1] = leftPupil.startPos[1] + dx, [2] = leftPupil.startPos[2] + dy, [4] = newScale, [5] = newScale })
   end
   if (rightPupil.transforms._g) then
      local rx, ry = rightPupil.transforms._g:inverseTransformPoint(x, y)
      local r = math.atan2(ry, rx)
      local dx = 3 * math.cos(r)
      local dy = 2 * math.sin(r)
      local newScale = love.math.random() * 0.5 + 0.75
      flux.to(rightPupil.transforms.l, 1 / (math.abs(dx) + math.abs(dy)),
         { [1] = rightPupil.startPos[1] + dx, [2] = rightPupil.startPos[2] + dy, [4] = newScale, [5] = newScale })
   end
   if (root.transforms._g) then
      local rx, ry = root.transforms._g:inverseTransformPoint(x, y)
      worst.transforms.l[1] = rx
      worst.transforms.l[2] = ry
   end
   if (snuit.transforms._g) then
      local rx, ry = snuit.transforms._g:inverseTransformPoint(x, y)
      local distance = math.sqrt((rx * rx) + (ry * ry))
      local diff2 = numbers.mapInto(distance, 0, 150, 1.1, 1)
      local diff = numbers.mapInto(love.math.random(), 0, 1, -0.01, 0.01)
      local newAngle = diff

      flux.to(snuit.transforms.l, 0.3, { [3] = newAngle, [4] = diff2, [5] = diff2 })
   end
end

function love.load()
   love.window.setMode(1024, 768, { resizable = true, vsync = true, minwidth = 400, minheight = 300, msaa = 2,
      highdpi = true })


   root = {
      folder = true,
      name = 'root',
      transforms = { g = { 0, 0, 0, 1, 1, 0, 0 }, l = { 1024 / 2, 768 / 2, 0, 4, 4, 0, 0 } },

   }

   local doggo = parse.parseFile('assets/doggo__.polygons.txt')
   local worst_ = parse.parseFile('assets/worst.polygons.txt')

   backdrop = gradient.makeBackdropMesh()
   root.children = { doggo[1], worst_[1] }
   parentize.parentize(root)
   mesh.meshAll(root)

   worst = node.findNodeByName(root, 'worst')
   leftEye = node.findNodeByName(root, 'left eye')
   leftPupil = node.findNodeByName(leftEye, 'pupil')
   leftPupil.startPos = { leftPupil.transforms.l[1], leftPupil.transforms.l[2] }
   rightEye = node.findNodeByName(root, 'right eye')
   rightPupil = node.findNodeByName(rightEye, 'pupil')
   rightPupil.startPos = { rightPupil.transforms.l[1], rightPupil.transforms.l[2] }

   snuit = node.findNodeByName(root, 'snuit')

   print(inspect(_G))
end

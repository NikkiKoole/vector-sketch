package.path = package.path .. ";../../?.lua"

require 'lib.scene-graph'
require 'lib.poly'
require 'lib.main-utils'
require 'lib.toolbox'

inspect = require 'vendor.inspect'
flux = require "vendor.flux"

local numbers = require 'lib.numbers'
local parentize = require 'lib.parentize'
local parse = require 'lib.parse-file'
local render = require 'lib.render'
local mesh = require 'lib.mesh'

function love.keypressed(key)
   if key == "escape" then love.event.quit() end
end

function love.update(dt)
   flux.update(dt)
   worst.transforms.l[3] = worst.transforms.l[3] + 0.001 / dt
end

function love.draw()
   local m = makeBackdropMesh()
   love.graphics.draw(m)
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

function makeBackdropMesh()
   local format = {
      { "VertexPosition", "float", 2 }, -- The x,y position of each vertex.
      { "VertexColor", "byte", 4 } -- The r,g,b,a color of each vertex.
   }
   local w, h = love.graphics.getDimensions()

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
   love.window.setMode(1024, 768, { resizable = true, vsync = true, minwidth = 400, minheight = 300, msaa = 2,
      highdpi = true })


   root = {
      folder = true,
      name = 'root',
      transforms = { g = { 0, 0, 0, 1, 1, 0, 0 }, l = { 1024 / 2, 768 / 2, 0, 4, 4, 0, 0 } },

   }

   local doggo = parse.parseFile('assets/doggo__.polygons.txt')
   local worst_ = parse.parseFile('assets/worst.polygons.txt')

   root.children = { doggo[1], worst_[1] }
   parentize.parentize(root)
   mesh.meshAll(root)

   worst = findNodeByName(root, 'worst')
   leftEye = findNodeByName(root, 'left eye')
   leftPupil = findNodeByName(leftEye, 'pupil')
   leftPupil.startPos = { leftPupil.transforms.l[1], leftPupil.transforms.l[2] }
   rightEye = findNodeByName(root, 'right eye')
   rightPupil = findNodeByName(rightEye, 'pupil')
   rightPupil.startPos = { rightPupil.transforms.l[1], rightPupil.transforms.l[2] }

   snuit = findNodeByName(root, 'snuit')
end

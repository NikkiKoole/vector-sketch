local numbers = require 'lib.numbers'
local bbox = require 'lib.bbox'
local unloop = require 'lib.unpack-points'
local formats = require 'lib.formats'
local text = require 'lib.text'

function stringSplit(str, sep)
   local result = {}
   local regex = ("([^%s]+)"):format(sep)
   for each in str:gmatch(regex) do
      table.insert(result, each)
   end
   return result
end




function readStrAsShape(str, filename)
   local tab = (loadstring("return " .. str)())

   local vsketchIndex = (string.find(filename, 'vector-sketch/', 1, true)) + #'vector-sketch/'
   local lookFurther = filename:sub(vsketchIndex)
   local index2 = text.stringFindLastSlash(lookFurther)
   local fname = lookFurther
   shapePath = ''
   if index2 then
      fname = lookFurther:sub(index2 + 1)
      shapePath = lookFurther:sub(1, index2)
   end
   shapeName = fname:sub(1, -14)
   return tab
end

-- this was for a 3d experiment
function makeScaleFit(root, multipier)
   for i = 1, #root.children do
      local child = root.children[i]
      if child.folder then
         child.transforms.l[1] = child.transforms.l[1] * multipier --tx
         child.transforms.l[2] = child.transforms.l[2] * multipier --ty
         child.transforms.l[6] = child.transforms.l[6] * multipier --ox
         child.transforms.l[7] = child.transforms.l[7] * multipier --oy

         makeScaleFit(child, multipier)
      else

      end
   end
end

-- this was for a 3d experiment
function extrudeShape(shape, border, thickness, startZ)
   -- input is a flat 2d image
   -- output is a front and back side spaced with the tickness


   local newShape = {}
   local extrudedSide = {}
   for i = 1, #shape do
      newShape[i] = { shape[i][1] / 100, shape[i][2] / 100, startZ }
      extrudedSide[i] = { shape[i][1] / 100, shape[i][2] / 100, startZ + thickness }
   end

   local sides = {}
   for i = 1, #border do
      local index = i
      local nextIndex = i < #border and i + 1 or 1
      local t = thickness + startZ --* love.math.random()
      local p1 = { border[index][1] / 100, border[index][2] / 100, startZ }
      local p2 = { border[nextIndex][1] / 100, border[nextIndex][2] / 100, startZ }
      local p3 = { border[index][1] / 100, border[index][2] / 100, t }
      local p4 = { border[nextIndex][1] / 100, border[nextIndex][2] / 100, t }
      table.insert(sides, p3)
      table.insert(sides, p2)
      table.insert(sides, p1)

      table.insert(sides, p3)
      table.insert(sides, p4)
      table.insert(sides, p2)
   end

   return { shape = newShape, otherside = extrudedSide, sides = sides }
end

-- this was for a 3d experiment
function generate3dShapeFrom2d(shape, z)
   local result = {}
   for i = 1, #shape do
      result[i] = { shape[i][1] / 100, shape[i][2] / 100, z }
   end
   return result
end



function makeBorderMesh(node)
   local work = unloop.unpackNodePointsLoop(node.points)

   local output = {}

   for i = 50, 100 do
      local t = (i / 100)
      if t >= 1 then t = 0.99999999 end

      local x, y = GetSplinePos(work, t, node.borderTension)
      table.insert(output, { x, y })
   end

   local rrr = {}
   local r2 = evenlySpreadPath(rrr, output, 1, 0, node.borderSpacing)

   output = unloop.unpackNodePoints(rrr)
   local verts, indices, draw_mode = polyline('miter', output, node.borderThickness, nil, nil,
      node.borderRandomizerMultiplier)
   local mesh = love.graphics.newMesh(formats.simple_format, verts, draw_mode)
   return mesh
end

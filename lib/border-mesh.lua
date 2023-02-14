local numbers = require 'lib.numbers'
local lerp = numbers.lerp
local unloop = require 'lib.unpack-points'
local formats = require 'lib.formats'
local polyline = require 'lib.polyline'

local bordermesh = {}

local function getDistance(x1, y1, x2, y2)
   local dx = x1 - x2
   local dy = y1 - y2
   local distance = math.sqrt((dx * dx) + (dy * dy))

   return distance
end

local function getLengthOfPath(path)
   local result = 0
   for i = 1, #path - 1 do
      local a = path[i]
      local b = path[i + 1]
      result = result + getDistance(a[1], a[2], b[1], b[2])
   end
   return result
end

local function evenlySpreadPath(result, path, index, running, spacing)
   local here = path[index]
   if index == #path then return end

   local nextIndex = index + 1
   local there = path[nextIndex]
   local d = getDistance(here[1], here[2], there[1], there[2])
   if (d + running) < spacing then
      running = running + d
      return evenlySpreadPath(result, path, index + 1, running, spacing)
   else
      if running >= d then
         --print('missing one here i think', running/d)
         local x = lerp(here[1], there[1], 1 or running / d)
         local y = lerp(here[2], there[2], 1 or running / d)
         --if index < #path-2 then
         table.insert(result, { x, y, { 1, 0, 0 } })
         --end
         --running = d
      end

      while running <= d do
         local x = lerp(here[1], there[1], running / d)
         local y = lerp(here[2], there[2], running / d)
         table.insert(result, { x, y, { 1, 0, 1 } })

         running = running + spacing
      end

      if running >= d then
         running = running - d
         return evenlySpreadPath(result, path, index + 1, running, spacing)
      end
   end
end

--https://love2d.org/forums/viewtopic.php?t=1401
local function GetSplinePos(tab, percent, tension) --returns the position at 'percent' distance along the spline.
   if (tab and (#tab >= 4)) then
      local pos = (((#tab) / 2) - 1) * percent
      local lowpnt, percent_2 = math.modf(pos)

      local i = (1 + lowpnt * 2)
      local p1x = tab[i]
      local p1y = tab[i + 1]
      local p2x = tab[i + 2]
      local p2y = tab[i + 3]

      local p0x = tab[i - 2]
      local p0y = tab[i - 1]
      local p3x = tab[i + 4]
      local p3y = tab[i + 5]

      local tension = tension or .5
      local t1x = 0
      local t1y = 0
      if (p0x and p0y) then
         t1x = (1.0 - tension) * (p2x - p0x)
         t1y = (1.0 - tension) * (p2y - p0y)
      end
      local t2x = 0
      local t2y = 0
      if (p3x and p3y) then
         t2x = (1.0 - tension) * (p3x - p1x)
         t2y = (1.0 - tension) * (p3y - p1y)
      end

      local s = percent_2
      local s2 = s * s
      local s3 = s * s * s
      local h1 = 2 * s3 - 3 * s2 + 1
      local h2 = -2 * s3 + 3 * s2
      local h3 = s3 - 2 * s2 + s
      local h4 = s3 - s2
      local px = (h1 * p1x) + (h2 * p2x) + (h3 * t1x) + (h4 * t2x)
      local py = (h1 * p1y) + (h2 * p2y) + (h3 * t1y) + (h4 * t2y)

      return px, py
   end
end

bordermesh.unloosenVanillaline = function(points, tension, spacing)
   local work = unloop.unpackNodePoints(points, true)
   local output = {}
   for i = 0, 100 do
      local t = (i / 100)
      if t >= 1 then t = 0.99999999 end
      local x, y = GetSplinePos(work, t, tension)
      table.insert(output, { x, y })
   end
   local rrr = {}
   local r2 = evenlySpreadPath(rrr, output, 1, 0, spacing)
   output = unloop.unpackNodePoints(rrr)
   return output
end

bordermesh.makeBorderMesh = function(node)
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
   local verts, indices, draw_mode = polyline.render('miter', output, node.borderThickness, nil, nil,
      node.borderRandomizerMultiplier)
   local mesh = love.graphics.newMesh(formats.simple_format, verts, draw_mode)
   return mesh
end


return bordermesh

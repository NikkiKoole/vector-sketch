local geom = require 'lib.geom'
--local bezier = require 'lib.bezier'
local unloop = require 'lib.unpack-points'
local hit = require 'lib.hit'

require 'lib.basics' --vanwege tableconcat

--[[
local function triangulate(type, poly)
   local result = {}

   if type == "mesh3d" then
      for x = 1, poly.width do
         for y = 1, poly.height do
            local p1 = { x = poly.cells[x][y].x, y = poly.cells[x][y].y }
            local p2 = { x = poly.cells[x + 1][y].x, y = poly.cells[x + 1][y].y }
            local p3 = { x = poly.cells[x + 1][y + 1].x, y = poly.cells[x + 1][y + 1].y }
            local p4 = { x = poly.cells[x][y + 1].x, y = poly.cells[x][y + 1].y }

            p1.x = p1.x + poly.cx
            p2.x = p2.x + poly.cx
            p3.x = p3.x + poly.cx
            p4.x = p4.x + poly.cx

            p1.y = p1.y + poly.cy
            p2.y = p2.y + poly.cy
            p3.y = p3.y + poly.cy
            p4.y = p4.y + poly.cy

            local triangle1, triangle2

            if x % 2 == 1 then
               if y % 2 == 1 then
                  triangle1 = { p1.x, p1.y, p2.x, p2.y, p3.x, p3.y }
                  triangle2 = { p1.x, p1.y, p3.x, p3.y, p4.x, p4.y }
               else
                  triangle1 = { p4.x, p4.y, p1.x, p1.y, p2.x, p2.y }
                  triangle2 = { p4.x, p4.y, p3.x, p3.y, p2.x, p2.y }
               end
            else
               if y % 2 == 1 then
                  triangle1 = { p4.x, p4.y, p1.x, p1.y, p2.x, p2.y }
                  triangle2 = { p4.x, p4.y, p3.x, p3.y, p2.x, p2.y }
               else
                  triangle1 = { p1.x, p1.y, p2.x, p2.y, p3.x, p3.y }
                  triangle2 = { p1.x, p1.y, p3.x, p3.y, p4.x, p4.y }
               end
            end

            table.insert(result, triangle1)
            table.insert(result, triangle2)
         end
      end

   elseif type == "polyline" or type == "rope" or type == "smartline" then
      assert(poly.draw_mode)
      if (poly.draw_mode == "triangles") then
         for i = 1, #poly.indices, 3 do
            local i1 = poly.indices[i]
            local i2 = poly.indices[i + 1]
            local i3 = poly.indices[i + 2]
            table.insert(result, { poly.vertices[i1][1], poly.vertices[i1][2],
               poly.vertices[i2][1], poly.vertices[i2][2],
               poly.vertices[i3][1], poly.vertices[i3][2] })
         end
      elseif (poly.draw_mode == "strip") then
         -- this is quite dumb, the input data is very efficient and now i go and make separate triangles from it again
         -- this is only for as long as I am not using meshes.

         --print(#poly.vertices)
         for i = 1, #poly.vertices - 2 do
            if (i % 2 == 0) then
               -- 0 1 2
               table.insert(result, { poly.vertices[i + 0][1], poly.vertices[i + 0][2],
                  poly.vertices[i + 1][1], poly.vertices[i + 1][2],
                  poly.vertices[i + 2][1], poly.vertices[i + 2][2] })

            else
               -- 0 2 1
               table.insert(result, { poly.vertices[i + 0][1], poly.vertices[i + 0][2],
                  poly.vertices[i + 2][1], poly.vertices[i + 2][2],
                  poly.vertices[i + 1][1], poly.vertices[i + 1][2] })

            end

         end

      end
   else
      local polys = decompose_complex_poly(poly, {})

      for i = 1, #polys do
         local p = polys[i]
         reTriangulatePolygon(p, result)
      end
   end
   return result
end

--]]

-- for the boyonce i prolly need thi algo:
-- http://rosettacode.org/wiki/Sutherland-Hodgman_polygon_clipping#Lua
-- http://rosettacode.org/wiki/Sutherland-Hodgman_polygon_clipping#JavaScript

function inside(p, cp1, cp2)
   return (cp2.x - cp1.x) * (p.y - cp1.y) > (cp2.y - cp1.y) * (p.x - cp1.x)
end

function intersection(cp1, cp2, s, e)
   local dcx, dcy = cp1.x - cp2.x, cp1.y - cp2.y
   local dpx, dpy = s.x - e.x, s.y - e.y
   local n1 = cp1.x * cp2.y - cp1.y * cp2.x
   local n2 = s.x * e.y - s.y * e.x
   local n3 = 1 / (dcx * dpy - dcy * dpx)
   local x = (n1 * dpx - n2 * dcx) * n3
   local y = (n1 * dpy - n2 * dcy) * n3
   return { x = x, y = y }
end

function polygonClip(a, b) -- accepts 2 lists like {{x=1,y=y}, ...} with possible duplicated end

   local aList = {}
   local aEnd = (a.points[#a.points].x == a.points[1].x) and (a.points[#a.points].y == a.points[1].y) and #a.points - 1
       or #a.points
   for i = 1, aEnd do
      table.insert(aList, { x = a.points[i].x, y = a.points[i].y })
   end

   local bList = {}
   local bEnd = (b.points[#b.points].x == b.points[1].x) and (b.points[#b.points].y == b.points[1].y) and #b.points - 1
       or #b.points
   for i = 1, bEnd do
      table.insert(bList, { x = b.points[i].x, y = b.points[i].y })
   end

   local outputList = aList
   local cp1 = bList[#bList]
   for _, cp2 in ipairs(bList) do -- WP clipEdge is cp1,cp2 here
      local inputList = outputList
      outputList = {}
      local s = inputList[#inputList]
      for _, e in ipairs(inputList) do
         if inside(e, cp1, cp2) then
            if not inside(s, cp1, cp2) then
               outputList[#outputList + 1] = intersection(cp1, cp2, s, e)
            end
            outputList[#outputList + 1] = e
         elseif inside(s, cp1, cp2) then
            outputList[#outputList + 1] = intersection(cp1, cp2, s, e)
         end
         s = e
      end
      cp1 = cp2
   end
   --print(inspect(outputList))
   return outputList

end

function getPolygonCentroid(pts) -- accepts a flat array {x,y,x,y,x,y ...}
   -- https://stackoverflow.com/questions/9692448/how-can-you-find-the-centroid-of-a-concave-irregular-polygon-in-javascript

   local first = { pts[1], pts[2] }
   local last = { pts[#pts - 1], pts[#pts] }
   if (first[1] ~= last[1] or first[2] ~= last[2]) then
      assert('getPolygon centroid should be fed an array with duplicate')
      table.insert(pts, first[1], first[2])
   end

   local twicearea = 0
   local x = 0
   local y = 0
   for i = 1, #pts, 2 do
      local prev = (i == 1 and #pts - 2) or i - 2
      local p1 = { pts[i], pts[i + 1] }
      local p2 = { pts[prev], pts[prev + 1] }

      assert(prev >= 1)
      assert(p1)
      assert(p1[1])
      assert(p1[2])
      assert(p2)
      assert(p2[1])
      assert(p2[2])
      assert(first)
      assert(first[1])
      assert(first[2])

      local f = (p1[2] - first[2]) * (p2[1] - first[1]) - (p2[2] - first[2]) * (p1[1] - first[1])
      twicearea = twicearea + f
      x = x + (p1[1] + p2[1] - 2 * first[1]) * f
      y = y + (p1[2] + p2[2] - 2 * first[2]) * f;
   end

   f = twicearea * 3

   return { x / f + first[1], y / f + first[2] }

end

return {
   polygonClip = polygonClip,
   getPolygonCentroid = getPolygonCentroid,


}

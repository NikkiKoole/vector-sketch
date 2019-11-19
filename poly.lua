
function split_poly(poly, intersection)
   local biggestIndex = math.max(intersection.i1, intersection.i2)
   local smallestIndex = math.min(intersection.i1, intersection.i2)
   local wrap = {}
   local bb = biggestIndex

   while bb ~= smallestIndex do
      bb = bb + 2
      if bb > #poly-1 then
         bb = 1

      end
      table.insert(wrap, poly[bb])
      table.insert(wrap, poly[bb+1])
   end

   table.insert(wrap, intersection.x)
   table.insert(wrap, intersection.y)

   local back = {}
   local bk = biggestIndex

   while bk ~= smallestIndex do
      table.insert(back, poly[bk])
      table.insert(back, poly[bk+1])
      bk = bk -2
   end

   table.insert(back, intersection.x)
   table.insert(back, intersection.y)

   return wrap, back
end

function TableConcat(t1,t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
    return t1
end


function get_line_intersection(p0_x, p0_y, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y)
   local s1_x, s1_y, s2_x, s2_y
   local s1_x = p1_x - p0_x
   local s1_y = p1_y - p0_y
   local s2_x = p3_x - p2_x
   local s2_y = p3_y - p2_y

   local s, t
   s = (-s1_y * (p0_x - p2_x) + s1_x * (p0_y - p2_y)) / (-s2_x * s1_y + s1_x * s2_y)
   t = ( s2_x * (p0_y - p2_y) - s2_y * (p0_x - p2_x)) / (-s2_x * s1_y + s1_x * s2_y)

   if (s >= 0 and s <= 1 and t >= 0 and t <= 1) then
      return p0_x + (t * s1_x), p0_y + (t * s1_y)
   end

   return 0
end


function get_collisions(poly)
   local collisions = {}

   for outeri = 1, #poly, 2 do
      local ax = poly[outeri]
      local ay = poly[outeri+1]
      local ni = outeri+2
      if outeri == #poly-1 then ni = 1 end
      local bx = poly[ni]
      local by = poly[ni+1]

      for inneri = 1, #poly, 2 do
         local cx = poly[inneri]
         local cy = poly[inneri+1]
         local ni = inneri+2
         if inneri==#poly-1 then ni =1 end
         local dx = poly[ni]
         local dy = poly[ni+1]

         if inneri ~= outeri then
            local result, opt = get_line_intersection(ax,ay,bx,by,cx,cy,dx,dy)
            if (ax == cx and ay == cy) or (ax == dx and ay == dy) or
            (bx == cx and by == cy) or (bx == dx and by == dy) then
              -- print("share corner")
            else
               if result ~= 0 then
                  local col = {i1=outeri, i2=inneri, x=result, y=opt }
                  local alreadyfound = false

                  for i=1, #collisions do
                     if (collisions[i].i1 == inneri and collisions[i].i2 == outeri) then
                        alreadyfound=true
                     else
                     end
                  end

                  if not alreadyfound then
                     table.insert(collisions, col)
                  end
               end
            end
         end
      end
   end
   return collisions
end


function decompose_complex_poly(poly, result)
   local intersections = get_collisions(poly)
   if #intersections == 0 then
      result = TableConcat(result, {poly})
   end
   if #intersections > 1 then
      local p1, p2 = split_poly(poly, intersections[1])
      local p1c, p2c = get_collisions(p1),get_collisions(p2)
      if (#p1c > 0) then
         result = decompose_complex_poly(p1, result)
      else
         result = TableConcat(result, {p1})
      end

      if (#p2c > 0) then
         result = decompose_complex_poly(p2, result)
      else
         result = TableConcat(result, {p2})
      end
   end
   if #intersections == 1 then
      local p1, p2 = split_poly(poly, intersections[1])
      result = TableConcat(result, {p1})
      result = TableConcat(result, {p2})
   end

   return result
end

function getCentroid(triangle)
   local x = (triangle[1] + triangle[3] + triangle[5])/3
   local y = (triangle[2] + triangle[4] + triangle[6])/3
   return x, y
end

function isPointInPath(x,y, poly)
   local num = #poly
   local j = num - 1
   local c = false
   for i=1, #poly,2 do
      if ((poly[i+1] > y) ~= (poly[j+1] > y)) and
      (x < (poly[j+0] - poly[i+0]) * (y - poly[i+1]) / (poly[j+1] - poly[i+1]) + poly[i+0]) then
          c = not c
      end
      j = i
   end
   return c
end


function triangulate(type, poly)
   local result = {}

   if type=="mesh3d" then
      for x=1, poly.width do
         for y=1,poly.height do
            local p1 = {x=poly.cells[x][y].x,     y=poly.cells[x][y].y}
            local p2 = {x=poly.cells[x+1][y].x,   y=poly.cells[x+1][y].y}
            local p3 = {x=poly.cells[x+1][y+1].x, y=poly.cells[x+1][y+1].y}
            local p4 = {x=poly.cells[x][y+1].x,   y=poly.cells[x][y+1].y}

            p1.x = p1.x + poly.cx
            p2.x = p2.x + poly.cx
            p3.x = p3.x + poly.cx
            p4.x = p4.x + poly.cx

            p1.y = p1.y + poly.cy
            p2.y = p2.y + poly.cy
            p3.y = p3.y + poly.cy
            p4.y = p4.y + poly.cy

            local triangle1, triangle2

            if x%2==1 then
               if y%2==1 then
                  triangle1 = {p1.x,p1.y,p2.x,p2.y,p3.x,p3.y}
                  triangle2 = {p1.x,p1.y,p3.x,p3.y,p4.x,p4.y}
               else
                  triangle1 = {p4.x,p4.y,p1.x,p1.y,p2.x,p2.y}
                  triangle2 = {p4.x,p4.y,p3.x,p3.y,p2.x,p2.y}
               end
            else
               if y%2==1 then
                  triangle1 = {p4.x,p4.y,p1.x,p1.y,p2.x,p2.y}
                  triangle2 = {p4.x,p4.y,p3.x,p3.y,p2.x,p2.y}
               else
                  triangle1 = {p1.x,p1.y,p2.x,p2.y,p3.x,p3.y}
                  triangle2 = {p1.x,p1.y,p3.x,p3.y,p4.x,p4.y}
               end
            end

            table.insert(result, triangle1)
            table.insert(result, triangle2)
         end
      end

   elseif type=="polyline" or type=="rope" or type=="smartline" then
      assert(poly.draw_mode)
      if (poly.draw_mode == "triangles") then
         for i=1, #poly.indices, 3 do
            local i1 = poly.indices[i]
            local i2 = poly.indices[i+1]
            local i3 = poly.indices[i+2]
            table.insert(result, {poly.vertices[i1][1], poly.vertices[i1][2],
                                  poly.vertices[i2][1], poly.vertices[i2][2],
                                  poly.vertices[i3][1], poly.vertices[i3][2]})
         end
      elseif (poly.draw_mode == "strip") then
         -- this is quite dumb, the input data is very efficient and now i go and make separate triangles from it again
         -- this is only for as long as I am not using meshes.

         --print(#poly.vertices)
         for i=1, #poly.vertices-2 do
            if (i % 2 == 0) then
               -- 0 1 2
            table.insert(result, {poly.vertices[i+0][1], poly.vertices[i+0][2],
                                  poly.vertices[i+1][1], poly.vertices[i+1][2],
                                  poly.vertices[i+2][1], poly.vertices[i+2][2]})

            else
               -- 0 2 1
            table.insert(result, {poly.vertices[i+0][1], poly.vertices[i+0][2],
                                  poly.vertices[i+2][1], poly.vertices[i+2][2],
                                  poly.vertices[i+1][1], poly.vertices[i+1][2]})

            end

         end

      end
   else
      local polys = decompose_complex_poly(poly, {})

      for i=1 , #polys do
         local p = polys[i]
         --print(type)
         --printArray(p)
         --print(#p)

         local triangles = love.math.triangulate(p)
         for j = 1, #triangles do
            local t = triangles[j]
            local cx, cy = getCentroid(t)
            if isPointInPath(cx,cy, p) then
               table.insert(result, t)
            end
         end
      end
   end
   --print("abba", #result)
   return result
end


function printArray(a)
   -- just print 10 values on a row

   print("Array: #",#a)

   for i=1, #a, 10 do
      local str = ""
      for j=0, math.min((#a-i),9) do
         --print(i,j,i+j)
         str = str..a[i+j]
         str = str..", "
      end
      print(str)
   end
   print()
   print()


end

return {
   triangulate=triangulate
}

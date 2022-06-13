
function TableConcat(t1,t2)
   for i=1,#t2 do
      t1[#t1+1] = t2[i]
   end
   return t1
end


local function split_poly(poly, intersection)
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



local function get_line_intersection(p0_x, p0_y, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y)
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


local function get_collisions(poly)
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

function getTriangleCentroid(triangle)
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
         reTriangulatePolygon(p, result)
         -- local triangles = love.math.triangulate(p)
         -- for j = 1, #triangles do
         --    local t = triangles[j]
         --    local cx, cy = getTriangleCentroid(t)
         --    if isPointInPath(cx,cy, p) then
         --       table.insert(result, t)
         --    end
         -- end
      end
   end
   return result
end

function reTriangulatePolygon(poly, result)
   local p = poly
   local triangles = love.math.triangulate(p)
   for j = 1, #triangles do
      local t = triangles[j]
      local cx, cy = getTriangleCentroid(t)
      if isPointInPath(cx,cy, p) then
         table.insert(result, t)
      end
   end
end



-- for the boyonce i prolly need thi algo:
-- http://rosettacode.org/wiki/Sutherland-Hodgman_polygon_clipping#Lua
-- http://rosettacode.org/wiki/Sutherland-Hodgman_polygon_clipping#JavaScript

function inside(p, cp1, cp2)
   return (cp2.x-cp1.x)*(p.y-cp1.y) > (cp2.y-cp1.y)*(p.x-cp1.x)
end

function intersection(cp1, cp2, s, e)
   local dcx, dcy = cp1.x-cp2.x, cp1.y-cp2.y
   local dpx, dpy = s.x-e.x, s.y-e.y
   local n1 = cp1.x*cp2.y - cp1.y*cp2.x
   local n2 = s.x*e.y - s.y*e.x
   local n3 = 1 / (dcx*dpy - dcy*dpx)
   local x = (n1*dpx - n2*dcx) * n3
   local y = (n1*dpy - n2*dcy) * n3
   return {x=x, y=y}
end

function polygonClip(a, b) -- accepts 2 lists like {{x=1,y=y}, ...} with possible duplicated end

   local aList = {}
   local aEnd = (a.points[#a.points].x == a.points[1].x) and (a.points[#a.points].y == a.points[1].y) and #a.points -1 or  #a.points
   for i = 1, aEnd do
      table.insert(aList, {x=a.points[i].x, y=a.points[i].y})
   end

   local bList = {}
   local bEnd = (b.points[#b.points].x == b.points[1].x) and (b.points[#b.points].y == b.points[1].y) and #b.points -1 or  #b.points
   for i = 1, bEnd do
      table.insert(bList, {x=b.points[i].x, y=b.points[i].y})
   end

   local outputList = aList
   local cp1 = bList[#bList]
   for _, cp2 in ipairs(bList) do  -- WP clipEdge is cp1,cp2 here
      local inputList = outputList
      outputList = {}
      local s = inputList[#inputList]
      for _, e in ipairs(inputList) do
	 if inside(e, cp1, cp2) then
	    if not inside(s, cp1, cp2) then
	       outputList[#outputList+1] = intersection(cp1, cp2, s, e)
	    end
	    outputList[#outputList+1] = e
	 elseif inside(s, cp1, cp2) then
	    outputList[#outputList+1] = intersection(cp1, cp2, s, e)
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

   local first = {pts[1], pts[2]}
   local last = {pts[#pts-1], pts[#pts]}
   if (first[1] ~= last[1] or first[2] ~= last[2]) then
      assert('getPolygon centroid should be fed an array with duplicate')
      table.insert(pts, first[1], first[2])
   end

   local twicearea = 0
   local x = 0
   local y = 0
   for i = 1, #pts, 2 do
      local prev = (i == 1 and #pts-2) or i - 2
      local p1 = {pts[i], pts[i+1]}
      local p2 = {pts[prev], pts[prev+1]}

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
      x = x +  (p1[1] + p2[1] - 2 * first[1]) * f
      y = y +  (p1[2] + p2[2] - 2 * first[2]) * f;
   end

   f = twicearea * 3

   return {x/f + first[1], y/f + first[2]}

end

function makeVertices(shape)
   --local triangles = {}
   if (shape.type == 'meta') then return end
   if (shape.folder) then return end
   
   local points = shape.points
   local vertices = {}

   if shape.type == nil or shape.type == 'poly' then
      if (points and #points >= 2 ) then
         
         local scale = 1
         local coords = {}
         local ps = {}
         
         for l=1, #points do
            table.insert(coords, points[l][1])
            table.insert(coords, points[l][2])
         end

         if (shape.color) then
            local polys = decompose_complex_poly(coords, {})
            
            local result = {}
            for k=1 , #polys do
               local p = polys[k]
               if (#p >= 6) then
                  -- if a import breaks on triangulation errors uncomment this
                  --	       print( #p, inspect(p))

                  reTriangulatePolygon(p, result)

                  -- local triangles = love.math.triangulate(p)
                  -- for j = 1, #triangles do
                  --    local t = triangles[j]
                  --    local cx, cy = getTriangleCentroid(t)
                  --    if isPointInPath(cx,cy, p) then
                  --       table.insert(result, t)
                  --    end
                  -- end
               end
            end
            
            for j = 1, #result do
               table.insert(vertices, {result[j][1], result[j][2]})
               table.insert(vertices, {result[j][3], result[j][4]})
               table.insert(vertices, {result[j][5], result[j][6]})
            end
         end
      end
   else
      --print(shape.mesh)
      if (shape.type == 'rubberhose') then
	 --print('create the vertices for this babe')
	 --print(inspect(shape.data))
	 --print(inspect(shape.points))
	 local start = {
	    x=shape.points[1][1],
	    y=shape.points[1][2]
	 }
	 local eind = {
	    x=shape.points[2][1],
	    y=shape.points[2][2]
	 }

	 local   magic = 4.46
	 local cp1, cp2 = positionControlPoints(start, eind, shape.data.length * magic, shape.data.flop, shape.data.borderRadius)
	 local curve = love.math.newBezierCurve({start.x,start.y,cp1.x,cp1.y,cp2.x,cp2.y,eind.x,eind.y})

	
	 -- let nbegin describing the vertices i need, should i just put the middle ones in ?
	 local coords = {}
	 if (tostring(cp1.x) == 'nan') then
	    coords = {shape.points[1], shape.points[2]}
	 else
	    
	    local steps = shape.data.steps
	    for i = 0, steps do
	       local px, py = curve:evaluate(i/steps)
	       table.insert(coords, {px, py})
	    end
	 end
	 --print(inspect(coords))
	 local verts, indices, draw_mode = polyline('miter',unpackNodePoints(coords, false), {shape.data.width})

	 
	 vertices = verts
	 
      else
	 --print(inspect(points))
	 local coords = unpackNodePoints(points, false)
	 --      print(inspect(coords))
	 local verts, indices, draw_mode = polyline('miter',coords, {10,40,20,100, 10})
      

	 vertices = verts
      end
   end

   return vertices
end

function positionControlPoints(start, eind, hoseLength, flop, borderRadius)
   local pxm,pym = getPerpOfLine(start.x,start.y, eind.x, eind.y)
   pxm = pxm * flop
   pym = pym * -flop
   local d = distance(start.x,start.y, eind.x, eind.y)

   --   print(hoseLength, d)
   -- why does this return nan?
   -- it returns nan if the length is too small
   local b = getEllipseWidth(hoseLength/math.pi, d)
   --print(hoseLength/math.pi, d, b)
   local perpL = b /2 -- why am i dividing this?

   local sp2 = lerpLine(start.x,start.y, eind.x, eind.y, borderRadius)
   local ep2 = lerpLine(start.x,start.y, eind.x, eind.y, 1 - borderRadius)

   local startP = {x= sp2.x +(pxm*perpL), y= sp2.y + (pym*perpL)}
   local endP = {x= ep2.x +(pxm*perpL), y= ep2.y + (pym*perpL)}
   return startP, endP
end


return {
   polygonClip = polygonClip,
   getPolygonCentroid = getPolygonCentroid,
   triangulate=triangulate,
   makeVertices = makeVertices
}

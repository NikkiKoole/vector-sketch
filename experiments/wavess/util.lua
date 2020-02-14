
function clamp(x, min, max)
  return x < min and min or (x > max and max or x)
end

function lerp(a, b, amount)
  return a + (b - a) * clamp(amount, 0, 1)
end


function distancePointSegment(x,y, x1,y1, x2, y2)
   local A = x - x1
   local B = y - y1
   local C = x2 - x1
   local D = y2 - y1
   local dot    = A * C + B * D
   local len_sq = C * C + D * D
   local param = -1

   if (len_sq ~= 0) then
      param = dot / len_sq
   end

   local xx, yy
   if (param < 0) then
      xx = x1
      yy = y1
   elseif (param > 1) then
      xx = x2
      yy = y2
   else
      xx = x1 + param * C
      yy = y1 + param * D
   end

   local dx = x - xx
   local dy = y - yy
   return math.sqrt(dx * dx + dy*dy)
end

function getClosestEdgeIndex(wx, wy, points)
   local closestEdgeIndex = 0
   local closestDistance = 99999999999999
   for j = 1, #points do
      local next = (j == #points and 1) or j+1
      local d = distancePointSegment(wx, wy, points[j][1], points[j][2], points[next][1], points[next][2])
      if (d < closestDistance) then
	 closestDistance = d
	 closestEdgeIndex = j
      end
   end
   return closestEdgeIndex
end

function starts_with(str, start)
   return str:sub(1, #start) == start
end

function ends_with(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end

function split(str, pos)
   local offset = utf8.offset(str, pos) or 0
   return str:sub(1, offset-1), str:sub(offset)
end

function copyArray(original)
   local result = {}
   for i=1, #original do
      table.insert(result, round2(original[i], 3))
   end
   return result
end


function copyShape(shape)
   if (shape.folder) then
      local result = {
	 folder = true,
	 name = shape.name or "",
	 transforms = {
	    l = copyArray(shape.transforms.l),
	    --g = copyArray(shape.transforms.g)
	 },
	 children = {}
      }
      if (shape.keyframes) then
	 result.frame = shape.frame
	 result.keyframes = shape.keyframes
	 result.lerpValue = shape.lerpValue
      end

      for i=1, #shape.children do
	 result.children[i] = copyShape(shape.children[i])
      end

      return result
   else
	 local result = {
	    name = shape.name or "",
	    color = {},
	    points = {}
	 }
	 if shape.mask then
	    result.mask = true
	 end
	 if shape.hole then
	    result.hole = true
	 end
	 if (shape.color) then
	    for i=1, #shape.color do
	       result.color[i] = round2(shape.color[i],3)
	    end
	 else
	    result.color = {0,0,0,0}
	 end

	 for i=1, #shape.points do
	    result.points[i]= {round2(shape.points[i][1], 3), round2(shape.points[i][2], 3)}
	 end
	 return result
   end

end

function round2(num, numDecimalPlaces)
  return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end

function makeVertices(shape)
   local triangles = {}
   local vertices = {}
   if (shape.folder) then return end
   local points = shape.points
   if (#points >= 2 ) then

      local scale = 1
      local coords = {}
      --local coordsRound = {}
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
	       --print(shapes[i].name, #p, inspect(p))
	       local triangles = love.math.triangulate(p)
	       for j = 1, #triangles do
		  local t = triangles[j]
		  local cx, cy = getTriangleCentroid(t)
		  if isPointInPath(cx,cy, p) then
		     table.insert(result, t)
		  end
	       end
	    end
	 end

	 for j = 1, #result do
	    table.insert(vertices, {result[j][1], result[j][2]})
	    table.insert(vertices, {result[j][3], result[j][4]})
	    table.insert(vertices, {result[j][5], result[j][6]})
	 end

      end
   end
   return vertices
end

function makeMeshFromVertices(vertices)
   if (vertices and vertices[1] and vertices[1][1]) then
      local mesh = love.graphics.newMesh(simple_format, vertices, "triangles")
      return mesh
   end
   return nil
end

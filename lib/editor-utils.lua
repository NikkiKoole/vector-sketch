
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
	 if shape.keyframes == 2 then
	 result.lerpValue = shape.lerpValue
	 end
	 if shape.keyframes == 4 or shape.keyframes == 5 then
	    result.lerpX = shape.lerpX
	    result.lerpY = shape.lerpY
	 end
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
	 if shape.closeStencil then
	    result.closeStencil = true
	 end
         if shape.type then
	    result.type = shape.type
	 end

         if shape.border then
	    result.border = true
	 end
         if shape.borderTension then
	    result.borderTension = shape.borderTension
	 end
         if shape.borderSpacing then
	    result.borderSpacing = shape.borderSpacing
	 end
         if shape.borderThickness then
	    result.borderThickness = shape.borderThickness
	 end
         if shape.borderRandomizerMultiplier then
	    result.borderRandomizerMultiplier = shape.borderRandomizerMultiplier
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



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
	 if shape.data then
	    result.data = deepcopy(shape.data)
	 end
	 if shape.texture then
	    result.texture = deepcopy(shape.texture)
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

local WheelSystem = Concord.system({pool = {'wheelCircumference', 'rotatingPart'}})
function WheelSystem:itemDrag( c, l, x, y, invx, invy)
   
   if (c.entity and c.entity.wheelCircumference and c.pressed) then
      local rotateStep = invx - c.pressed.dx
	local rx, ry = c.transforms._g:transformPoint( rotateStep, 0)
	local rx2, ry2 = c.transforms._g:transformPoint( 0, 0)
	local rxdelta = rx - rx2
        
	c.entity.rotatingPart.value.transforms.l[3] =
           c.entity.rotatingPart.value.transforms.l[3]  +
	   (rxdelta/c.entity.wheelCircumference.value)*(math.pi*2)

	c.transforms.l[1] = c.transforms.l[1] + rotateStep
   end
end

return WheelSystem

local DraggableSystem = Concord.system({pool = {'transforms', 'bbox', 'vanillaDraggable'}})
function DraggableSystem:update(dt)
end
function DraggableSystem:itemDrag( c, l, x, y, invx, invy)
   if (c.entity and c.entity.vanillaDraggable and c.pressed) then
      local dx = (invx - c.pressed.dx)
      local dy = (invy - c.pressed.dy)
      
      c.transforms.l[1] = c.transforms.l[1] + dx
      c.transforms.l[2] = c.transforms.l[2] + dy


      if (c.entity.inStack) then
	 local nextLink = c.entity.inStack.next
	 while nextLink do
	    nextLink.transforms.l[1] = nextLink.transforms.l[1] + dx
	    nextLink.transforms.l[2] = nextLink.transforms.l[2] + dy
	    if nextLink.entity.inStack then
	       nextLink = nextLink.entity.inStack.next
	    end
	 end
      end
      
   end
end

function DraggableSystem:pressed(x,y)
end

return DraggableSystem

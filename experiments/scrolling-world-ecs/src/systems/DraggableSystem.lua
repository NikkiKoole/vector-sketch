local DraggableSystem = Concord.system({pool = {'transforms', 'bbox', 'vanillaDraggable'}})
function DraggableSystem:update(dt)
end
function DraggableSystem:itemDrag( c, l, x, y, invx, invy)
   if (c.entity and c.entity.vanillaDraggable and c.pressed) then
      c.transforms.l[1] = c.transforms.l[1] + (invx - c.pressed.dx)
      c.transforms.l[2] = c.transforms.l[2] + (invy - c.pressed.dy)
   end
end

function DraggableSystem:pressed(x,y)
end

return DraggableSystem

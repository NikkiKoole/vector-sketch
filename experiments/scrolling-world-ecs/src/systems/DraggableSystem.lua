local DraggableSystem = Concord.system({pool = {'transforms', 'bbox', 'vanillaDraggable'}})
function DraggableSystem:update(dt)
end
function DraggableSystem:itemDrag( c, l, x, y, dx, dy)
   if (c.entity and c.entity.vanillaDraggable and c.pressed) then

      c.transforms.l[1] = c.transforms.l[1] + dx
      c.transforms.l[2] = c.transforms.l[2] + dy

      if (c.entity.inStack) then
         positionAllInStack(c.entity, dx, dy)
      end
      
   end
end

function DraggableSystem:pressed(x,y)
end

return DraggableSystem

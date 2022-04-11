local HitAreaEventSystem = Concord.system({pool={'hitAreaEvent'}})
function HitAreaEventSystem:itemPressed(item, l, x,y, hitcheck)
   if item.entity and item.entity.hitAreaEvent then
      eventBus(hitcheck)
   end
end
return HitAreaEventSystem

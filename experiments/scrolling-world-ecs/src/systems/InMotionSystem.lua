local InMotionSystem = Concord.system({pool={'inMotion', 'transforms'}})
function InMotionSystem:update(dt)
   -- applying half the velocity before position
   -- other half after positioning
   --https://web.archive.org/web/20150322180858/http://www.niksula.hut.fi/~hkankaan/Homepages/gravity.html

   for _, e in ipairs(self.pool) do

      local transforms = e.transforms.transforms

      e.inMotion.velocity = e.inMotion.velocity + e.inMotion.acceleration/2

      local dx = (e.inMotion.velocity.x * dt)
      local dy = (e.inMotion.velocity.y * dt)
      
      transforms.l[1] = transforms.l[1] + dx
      transforms.l[2] = transforms.l[2] + dy


      if (e.inStack) then
         positionAllInStack(e, dx, dy)
      end

      e.inMotion.velocity = e.inMotion.velocity + e.inMotion.acceleration/2
      e.inMotion.acceleration = e.inMotion.acceleration * 0

      -- make things not go below the floor!
      local bottomY = 0
      -- figure out the tile of the world i am in

      local h = getGlobalHeight(transforms.l[1])
      bottomY = h--groundTiles[tileX].height
      if e.actor then
         bottomY = h -e.actor.value.body.leglength
      end

      if e.vehicle then
--         print(e.vehicle.radius1)
         --bottomY = h -e.vehicle.radius1
      end
      

      if transforms.l[2] >= bottomY then
         local dy2 = bottomY - transforms.l[2] 
         transforms.l[2] = transforms.l[2] + dy2
--         print('this causing it ?', transforms.l[2], bottomY, dy2)

         if (e.inStack) then
            positionAllInStack(e, 0, dy2)
         end

         e:remove('inMotion')

         if e.actor then
            e.actor.value.originalX = transforms.l[1]
            e.actor.value.originalY = transforms.l[2]
         end
      end
   end
end

function InMotionSystem:itemThrow(target, dxn, dyn, speed)
   if target.entity then
      target.entity
         :ensure('inMotion', 1)

      local mass = target.entity.inMotion.mass
      local d = (dxn*dxn)+(dyn*dyn)
      local throwStrength = 1 --* math.sqrt(d)
      if mass < 0 then throwStrength = throwStrength / 100 end

      local impulse = Vector(dxn * speed * throwStrength ,
                             dyn * speed * throwStrength )

      applyForce(target.entity.inMotion, impulse)
   end
end
return InMotionSystem

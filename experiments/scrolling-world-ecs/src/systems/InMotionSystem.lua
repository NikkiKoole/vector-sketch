local InMotionSystem = Concord.system({pool={'inMotion', 'transforms'}})
function InMotionSystem:update(dt)
   -- applying half the velocity before position
   -- other half after positioning
   --https://web.archive.org/web/20150322180858/http://www.niksula.hut.fi/~hkankaan/Homepages/gravity.html

   for _, e in ipairs(self.pool) do

      local transforms = e.transforms.transforms

      e.inMotion.velocity = e.inMotion.velocity + e.inMotion.acceleration/2

      transforms.l[1] = transforms.l[1] + (e.inMotion.velocity.x * dt)
      transforms.l[2] = transforms.l[2] + (e.inMotion.velocity.y * dt)

      e.inMotion.velocity = e.inMotion.velocity + e.inMotion.acceleration/2
      e.inMotion.acceleration = e.inMotion.acceleration * 0

      -- temp do the floor
      local bottomY = 0
      if e.actor then
--         print(inspect(e.actor.value.leglength))
         bottomY = -e.actor.value.body.leglength
      end

      if transforms.l[2] >= bottomY then
         transforms.l[2] = bottomY
         e:remove('inMotion')

         if e.actor then
            e.actor.value.originalX = transforms.l[1]
            e.actor.value.originalY = transforms.l[2]
         end
      end
   end
end

function InMotionSystem:itemThrow(target, dxn, dyn, speed)
   target.entity
      :ensure('inMotion', 1)

   local mass = target.entity.inMotion.mass

   local throwStrength = 1
   if mass < 0 then throwStrength = throwStrength / 100 end

   local impulse = Vector(dxn * speed * throwStrength ,
                          dyn * speed * throwStrength )

   applyForce(target.entity.inMotion, impulse)
end
return InMotionSystem

function updateMotionItems(layer, dt)
   for i=1, #layer.children do
      local thing = layer.children[i]
      if thing.inMotion and not thing.pressed then

         --local gy = (6*980)
	 local gy = uiState.gravityValue * thing.inMotion.mass * dt
	 local gravity = Vector(0, gy);

	 applyForce(thing.inMotion, gravity)

         -- applying half the velocity before position
         -- other half after positioning
         --https://web.archive.org/web/20150322180858/http://www.niksula.hut.fi/~hkankaan/Homepages/gravity.html

	 thing.inMotion.velocity = thing.inMotion.velocity + thing.inMotion.acceleration/2

	 thing.transforms.l[1] = thing.transforms.l[1] + (thing.inMotion.velocity.x * dt)
	 thing.transforms.l[2] = thing.transforms.l[2] + (thing.inMotion.velocity.y * dt)



	 thing.inMotion.velocity = thing.inMotion.velocity + thing.inMotion.acceleration/2
	 thing.inMotion.acceleration = thing.inMotion.acceleration * 0;

	 if thing.transforms.l[2] >= 0 then
	    thing.transforms.l[2] = 0
	    thing.inMotion = nil
	 end
      end
   end
end

function applyForce(motionObject, force)
   local f = force / motionObject.mass
   if motionObject.mass < 1 then
      f = f * motionObject.mass
   end

   motionObject.acceleration =  motionObject.acceleration + f
end

function makeMotionObject()
   return {
      velocity = Vector(0,0),
      acceleration = Vector(0,0),
      mass = 1
   }
end
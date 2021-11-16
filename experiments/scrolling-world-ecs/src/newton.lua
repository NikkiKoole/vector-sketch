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

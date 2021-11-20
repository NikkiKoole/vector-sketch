Concord.component(
   'inMotion',
   function(c, mass, velocity, acceleration)
      c.mass = mass
      c.velocity = velocity or Vector(0,0)
      c.acceleration = acceleration or Vector(0,0)
   end
)

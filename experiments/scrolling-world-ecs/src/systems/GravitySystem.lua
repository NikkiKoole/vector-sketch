local GravitySystem = Concord.system({pool={'inMotion'}})
function GravitySystem:update(dt)
   for _, e in ipairs(self.pool) do
      local gy = uiState.gravityValue * e.inMotion.mass * dt
      local gravity = Vector(0, gy)
      applyForce(e.inMotion, gravity)
   end
end

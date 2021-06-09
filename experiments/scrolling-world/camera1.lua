camera = {}
camera._x = 0
camera._y = 0
camera.scaleX = 1
camera.scaleY = 1
camera.rotation = 0
camera.smoothing = 3

function math.clamp(x, min, max)
  return x < min and min or (x > max and max or x)
end


function camera:set(w,h)
   love.graphics.push()
   --love.graphics.translate(-w/2, -h/2)
   love.graphics.rotate(-self.rotation)
   love.graphics.scale(1 / self.scaleX, 1 / self.scaleY)
   love.graphics.translate(-self._x, -self._y)
end

function camera:unset()
  love.graphics.pop()
end

function camera:move(dx, dy)
  self._x = self._x + (dx or 0)
  self._y = self._y + (dy or 0)
end

function camera:rotate(dr)
  self.rotation = self.rotation + dr
end

function camera:scale(sx, sy)
  sx = sx or 1
  self.scaleX = self.scaleX * sx
  self.scaleY = self.scaleY * (sy or sx)
end

function camera:setXSmooth(value, dt)
   local newPos = nil
   --if self._bounds then
   --   print('x', value, self._bounds.x1, self._bounds.x2)

   --   newPos = math.clamp(value,
   --                       self._bounds.x1 ,
   --                       self._bounds.x2 )
   --   print(newPos)
   --else
      newPos = value
      --end
   local deltaX = newPos - self._x
   
   self._x = self._x + deltaX * self.smoothing * dt

   if (math.abs(deltaX) < 0.1) then
      self._x = newPos
   end
end

function camera:setYSmooth(value, dt)
   local newPos = nil
   --if self._bounds then
   --   print('y', value, self._bounds.y1, self._bounds.y2)
   --   newPos = math.clamp(value, self._bounds.y1, self._bounds.y2)
   --else
      newPos = value
   --end
   local deltaY = newPos - self._y
   
   self._y = self._y + deltaY * self.smoothing * dt
   if (math.abs(deltaY) < 0.1) then
      self._y = newPos
   end
end

function camera:setPositionSmooth(x, y, dt)
  if x then self:setXSmooth(x, dt) end
  if y then self:setYSmooth(y, dt) end
end

function camera:setX(value)
  if self._bounds then
    self._x = math.clamp(value, self._bounds.x1, self._bounds.x2)
  else
    self._x = value
  end
end

function camera:setY(value)
  if self._bounds then
    self._y = math.clamp(value, self._bounds.y1, self._bounds.y2)
  else
    self._y = value
  end
end

function camera:setPosition(x, y)
  if x then self:setX(x) end
  if y then self:setY(y) end
end


function camera:setScale(sx, sy)
  self.scaleX = sx or self.scaleX
  self.scaleY = sy or self.scaleY
end

function camera:getBounds()
  return unpack(self._bounds)
end

function camera:setBounds(x1, y1, x2, y2)
   self._bounds = { x1 = x1 ,
                    y1 = y1 ,
                    x2 = x2 ,
                    y2 = y2 }
end

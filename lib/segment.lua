local Segment = {}
Segment.__index = Segment

Vector = require "vendor.brinevector"

function Segment:create(x, y, angle, length)
   local s = {} -- our new object
   setmetatable(s, Segment) -- make Account handle lookup
   s.a = Vector(x, y) -- initialize our object
   s.b = Vector(x, y)
   s.angle = angle
   s.length = length
   return s
end

function Segment:updateB()
   local dx = self.length * math.cos(self.angle)
   local dy = self.length * math.sin(self.angle)
   self.b.x = self.a.x + dx
   self.b.y = self.a.y + dy
end

function Segment:setA(x, y)
   self.a = Vector(x, y)
end

function Segment:follow(tx, ty)
   local target = Vector(tx, ty)
   local dir = target - self.a
   self.angle = dir:getAngle()
   dir = dir:getNormalized() * self.length * -1
   self.a = target + dir
end

return Segment

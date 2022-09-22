local geom = require 'lib.geom'
local numbers = require 'lib.numbers'
local bezier = require 'lib.bezier'
local transform = require 'lib.transform'
local formats = require 'lib.formats'


require 'lib.segment'

Actor = {}
Actor.__index = Actor



function makeRubberHoseLeg(a, b, length, steps, lineData, flip)
   local start = a
   local eind = b

   local d = geom.distance(a.x, a.y, b.x, b.y)

   -- if upside down the flop th flip
   if eind.y < start.y then
      --      print('jo?', flip)
      flip = -1
      -- if flip == 1 then flip = -1 else flip = 1 end
   else
      --    print('not jo?')
   end


   local cp, cp2 = bezier.positionControlPoints(a, b, length, flip, .25)
   local result = {}

   local widths = {}
   local widths2 = {}
   local wasBroken = false
   if d > length / 4.46 then
      --      print('i am too long!',a,b)
      wasBroken = true

   end





   for i = 0, steps do
      local w = numbers.mapInto(i, 0, steps, lineData.outer[1], lineData.outer[2])
      local w2 = numbers.mapInto(i, 0, steps, lineData.inner[1], lineData.inner[2])
      widths[i] = w
      widths2[i] = w2
   end


   if tostring(cp.x) == 'nan' or wasBroken then

      -- here i create straight legs that are too long
      wasBroken = true
      result = {}
      local dx = start.x - eind.x
      local dy = start.y - eind.y

      for i = 0, steps do
         table.insert(result, start.x + (dx / steps) * i * -1)
         table.insert(result, start.y + (dy / steps) * i * -1)
      end

   else
      local curve = love.math.newBezierCurve({ start.x, start.y, cp.x, cp.y, cp2.x, cp2.y, eind.x, eind.y })
      for i = 0, steps do
         local px, py = curve:evaluate(i / steps)
         table.insert(result, px)
         table.insert(result, py)
      end



   end
   return result, widths, widths2, wasBroken

end

function Actor:getWidths()
   local lineData = {
      outer = { 20, 5 },
      inner = { 16, 3 }
   }
   local widths = {}
   local widths2 = {}

   for i = 0, self.steps do
      local w = numbers.mapInto(i, 0, self.steps, lineData.outer[1], lineData.outer[2])
      local w2 = numbers.mapInto(i, 0, self.steps, lineData.inner[1], lineData.inner[2])
      widths[i] = w
      widths2[i] = w2
   end

   return widths, widths2
end

function Actor:create(bodyparts)
   local a = {} -- our new object
   setmetatable(a, Actor) -- make Account handle lookup

   a.body = bodyparts.body

   --   a.body.transforms.l[2] =    a.body.transforms.l[2] - 100

   a.lfoot = bodyparts.lfoot
   a.rfoot = bodyparts.rfoot

   a.leg1_connector = a.body.metaTags[1]
   a.leg2_connector = a.body.metaTags[2]

   a.magic = 4.46 -- dont touch

   a.leglength = 200 + love.math.random() * 100


   a.body.leglength = a.leglength / a.magic
   a.steps = 23
   segments = {}
   for i = 1, 23 do
      segments[i] = Segment:create(0, 0, 0, a.body.leglength / a.steps)
   end
   a.segments = segments



   a.body.transforms.l[2] = a.body.transforms.l[2] - a.body.leglength


   a.originalX = a.body.transforms.l[1]
   a.originalY = a.body.transforms.l[2]

   a.body.actor = a
   a:straightenLegs()
   a.body.generatedMeshes = {} -- we can put the line meshes in here
   a.time = 0

   table.insert(a.body.children, 1, a.lfoot)
   table.insert(a.body.children, 1, a.rfoot)

   a.useRubber = true --false --math.random() < 0.5 and true or false
   a:doTheLegs()


   return a
end

function Actor:straightenLegs()
   self.lfoot.transforms.l[1] = self.leg1_connector.points[1][1]
   self.lfoot.transforms.l[2] = self.leg1_connector.points[1][2] + self.leglength / self.magic

   self.rfoot.transforms.l[1] = self.leg2_connector.points[1][1]
   self.rfoot.transforms.l[2] = self.leg2_connector.points[1][2] + self.leglength / self.magic

   self:doTheLegs()

end

function Actor:setRandPos()
   self.lfoot.transforms.l[1] = self.lfoot.transforms.l[1] + math.sin(self.time) / 120
   self.lfoot.transforms.l[2] = self.lfoot.transforms.l[2] + math.cos(self.time) / 20
end

function Actor:oneLeg(connector, transforms, flip)
   --   print('callin gone leg')
   local useRubber = self.useRubber
   local steps = self.steps


   local lineData = {
      outer = { 20, 5 },
      inner = { 16, 3 }
   }

   local result, widths, widths2, wasBroken = makeRubberHoseLeg(
      { x = connector.points[1][1],
         y = connector.points[1][2] },
      { x = transforms.l[1],
         y = transforms.l[2] },
      self.leglength,
      steps,
      lineData,
      flip
   )



   if not useRubber then
      result = {}
      local dx = transforms.l[1] - connector.points[1][1]
      local dy = transforms.l[2] - connector.points[1][2]

      for i = 0, steps do
         table.insert(result, connector.points[1][1] + (dx / steps) * i)
         table.insert(result, connector.points[1][2] + (dy / steps) * i)
      end
   end

   local verts, indices, draw_mode = polyline('bevel', result, widths)
   local mesh = love.graphics.newMesh(formats.simple_format, verts, draw_mode)
   table.insert(self.body.generatedMeshes, { mesh = mesh, color = { 0, 0, 0 } })


   local verts, indices, draw_mode = polyline('bevel', result, widths2)
   local mesh = love.graphics.newMesh(formats.simple_format, verts, draw_mode)
   table.insert(self.body.generatedMeshes, { mesh = mesh, color = { 0.67, 0.32, 0.21, 1 } })

end

function Actor:doTheLegs()
   self.body.generatedMeshes = {}

   local useRubber = self.useRubber


   if false and useRubber then
      local m = math.sin(self.time * 13)
      local o = numbers.mapInto(m, -1, 1, 0, 0.5)
      self.lfoot.transforms.l[2] = self.leg1_connector.points[1][2] + (self.leglength / self.magic) -
          (self.leglength / self.magic) * o

      local m = math.sin(self.time * 13)
      local o = numbers.mapInto(m, -1, 1, 0, 0.5)
      self.rfoot.transforms.l[2] = self.leg2_connector.points[1][2] + (self.leglength / self.magic) -
          (self.leglength / self.magic) * o
   else
      self.lfoot.transforms.l[2] = self.leg1_connector.points[1][2] + (self.leglength / self.magic)
      self.rfoot.transforms.l[2] = self.leg2_connector.points[1][2] + (self.leglength / self.magic)

   end



   self:oneLeg(self.leg1_connector, self.lfoot.transforms, -1)
   self:oneLeg(self.leg2_connector, self.rfoot.transforms, 1)

end

--function transposition(x, y, direction, distance)
--   return distance*math.cos(direction)+x, distance*math.sin(direction)+y
--end

--local time = 0
function Actor:update(dt)
   self.time = self.time or 0
   self.time = self.time + dt

   if not self.body.pressed then
      if self.beingPressed == true then
         --print('actor re;leased from drag should add some force')

         local oldLeftFootY = self.lfoot.transforms.l[2]
         local oldLeftFootX = self.lfoot.transforms.l[1]

         --self.beingPressed = false ??????
         
         self:straightenLegs()
         local newLeftFootY = self.lfoot.transforms.l[2]
         local newLeftFootX = self.lfoot.transforms.l[1]

         local dy = oldLeftFootY - newLeftFootY
         local dx = oldLeftFootX - newLeftFootX

         if dy ~= 0 or dx ~= 0 then
            --dx=0
            print(inspect(self.body), self.body.entity)
            self.body.inMotion = makeMotionObject()
            local impulse = Vector(dx * 11, dy * 11)
            applyForce(self.body.inMotion, impulse)
         end

      end

   end

   if self.disabledFunnyLegs and not self.body.pressed then
      if self.disabledFunnyLegs then
         self.disabledFunnyLegs = false
      end

   end

   if self.body.pressed then
      self.beingPressed = true
      transform.setTransforms(self.body)
      local pivx = self.body.transforms.l[6]
      local pivy = self.body.transforms.l[7]
      local px, py = self.body.transforms._g:transformPoint(pivx, pivy)

      -- i need to know if i am too far from feet

      local dist = (math.sqrt((px - self.originalX) ^ 2 + (py - self.originalY) ^ 2))

      local tooFar = dist > (self.leglength / self.magic)
      --      print('tooFar', tooFar)
      -- this causes the 'walk' it alos cause some fake elasticity
      if tooFar then
         --print('I need todo something!', self.disabledFunnyLegs)
         --local disallow_funny_walk = true
         --if allow_funny_walk then
         self.disabledFunnyLegs = true
         --end
         self.originalX = self.body.transforms.l[1]
         self.originalY = self.body.transforms.l[2]

      end




      if py <= -self.body.leglength then
         if self.useRubber == true then
            --print('transitioning from rubber to straight')
            self:straightenLegs()
         end

         self.useRubber = false
         --------
         ---
         -- do the gravitylegs
         local useGravityLegs = false
         if useGravityLegs then
            local segments = self.segments
            local last = segments[#segments]
            self.body.generatedMeshes = {}


            local fx = self.leg1_connector.points[1][1]
            local fy = self.leg1_connector.points[1][2]

            transform.setTransforms(self.body)

            last:follow(self.body.transforms.l[1] + fx, self.body.transforms.l[2] + fy)
            last:updateB()

            for i = #segments - 1, 1, -1 do
               segments[i]:follow(segments[i + 1].a.x, segments[i + 1].a.y)
               segments[i]:updateB()
            end

            for i = 1, #segments do
               segments[i]:setA(segments[i].a.x, segments[i].a.y + 100 * dt)
               segments[1]:updateB()
            end


            local result = {}
            --print(inspect(segments))
            for i = 1, #segments do
               table.insert(result, segments[i].a.x - self.body.transforms.l[1])
               table.insert(result, segments[i].a.y - self.body.transforms.l[2])
            end


            local verts, indices, draw_mode = polyline('bevel', result, 3)
            local mesh = love.graphics.newMesh(formats.simple_format, verts, draw_mode)
            table.insert(self.body.generatedMeshes, { mesh = mesh, color = { 0, 0, 0 } })


            local px2, py2 = self.body.transforms._g:inverseTransformPoint(segments[1].a.x, segments[1].a.y)
            print(segments[1].a.x, segments[1].a.y)

            self.lfoot.transforms.l[1] = px2
            self.lfoot.transforms.l[2] = py2

         end




         --self:oneLeg(self.leg1_connector, self.lfoot.transforms, -1)
         --self:oneLeg(self.leg2_connector, self.rfoot.transforms, 1)

         --self:doTheLegs()
      else
         if self.useRubber == false then
            self.originalX = self.body.transforms.l[1]
            self.originalY = self.body.transforms.l[2]

            print('transitioning from straight to rubber', self.originalX, self.originalY)
         end

         self.useRubber = true

         self.lfoot.transforms.l[2] = self.leg1_connector.points[1][2] - py --+ self.originalY
         self.lfoot.transforms.l[1] = self.leg1_connector.points[1][1] - px + self.originalX

         self.rfoot.transforms.l[2] = self.leg2_connector.points[1][2] - py --+ self.originalY
         self.rfoot.transforms.l[1] = self.leg2_connector.points[1][1] - px + self.originalX



         self.body.generatedMeshes = {}

         self:oneLeg(self.leg1_connector, self.lfoot.transforms, -1)
         self:oneLeg(self.leg2_connector, self.rfoot.transforms, 1)




      end


      -- flipping the true false equal allow semi footwalking
      local allowFunnyWalk = true
      if allowFunnyWalk then
      else

         if self.disabledFunnyLegs == true then
            --print('getting here!')
            self:straightenLegs()
            --print('is this another gravity one?')

         end
      end


   end

end

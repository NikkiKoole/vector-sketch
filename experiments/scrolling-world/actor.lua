Actor = {}
Actor.__index = Actor


function positionControlPoints(start, eind, hoseLength, flop)
   local borderRadius = 0

   local pxm,pym = getPerpOfLine(start.x,start.y, eind.x, eind.y)
   pxm = pxm * flop
   pym = pym * -flop
   local d = distance(start.x,start.y, eind.x, eind.y)
   -- theze caluclations are off but i am using some magic numebr here and there
   local b = getEllipseWidth(hoseLength/math.pi, d)
   local perpL = b /2 -- why am i dividing this?

   local sp2 = lerpLine(start.x,start.y, eind.x, eind.y, borderRadius)
   local ep2 = lerpLine(start.x,start.y, eind.x, eind.y, 1 - borderRadius)

   local startP = {x= sp2.x +(pxm*perpL), y= sp2.y + (pym*perpL)}
   local endP = {x= ep2.x +(pxm*perpL), y= ep2.y + (pym*perpL)}
   return startP, endP
end


function makeRubberHoseLeg(a, b, length, steps, lineData, flip)
   local start = a
   local eind = b

   local d = distance(a.x,a.y, b.x, b.y)
   --print(d, length)

   local cp, cp2 = positionControlPoints(a, b, length, flip)
   if tostring(cp.x) == 'nan' then
      print('now its broken')
   end

   local curve = love.math.newBezierCurve({start.x,start.y,cp.x,cp.y,cp2.x,cp2.y,eind.x,eind.y})
   local result = {}


   for i =0, steps do
      local px, py = curve:evaluate(i/steps)
      table.insert(result, px)
      table.insert(result, py)
   end

   
   local widths = {}
   local widths2 = {}
   
   for i =0, steps do
      local w = mapInto(i, 0,steps,lineData.outer[1], lineData.outer[2] )
      local w2 = mapInto(i, 0,steps,lineData.inner[1], lineData.inner[2] )
      widths[i] = w
      widths2[i] = w2

   end
   
   
   

   --local widths = {}
   --for i =1, #result/2 do
     -- widths[i] = (#result/2+4)-i
   --end

   --local widths2 = {}
   --for i =1, #result/2 do
      --widths2[i] = (#result/2+1)-i
   --end

   return result, widths, widths2
end


function Actor:create(bodyparts)
   local a = {}             -- our new object
   setmetatable(a,Actor)    -- make Account handle lookup

   a.body = bodyparts.body
--   a.body.transforms.l[2] =    a.body.transforms.l[2] - 100

   a.lfoot = bodyparts.lfoot
   a.rfoot = bodyparts.rfoot

   a.leg1_connector = a.body.metaTags[1]
   a.leg2_connector = a.body.metaTags[2]

   a.magic = 4.46 -- dont touch

   a.leglength = 100 + love.math.random()*300

   a.body.leglength = a.leglength/a.magic
   a.body.transforms.l[2] =    a.body.transforms.l[2] - a.body.leglength 

      
   a.lfoot.transforms.l[1] = a.leg1_connector.points[1][1] 
   a.lfoot.transforms.l[2] = a.leg1_connector.points[1][2] + a.leglength/a.magic 

   a.rfoot.transforms.l[1] = a.leg2_connector.points[1][1] 
   a.rfoot.transforms.l[2] = a.leg2_connector.points[1][2] + a.leglength/a.magic 


--   a.lfoot.transforms.l[1] =    a.lfoot.transforms.l[1] - 30
  -- a.lfoot.transforms.l[2] =    a.lfoot.transforms.l[2] - 40

   --a.rfoot.transforms.l[2] =    a.rfoot.transforms.l[2] - 30


   a.body.generatedMeshes = {} -- we can put the line meshes in here
   a.time= 0
   table.insert(a.body.children, a.lfoot)
   table.insert(a.body.children, a.rfoot)


   a.useRubber = false --math.random() < 0.5 and true or false
   a:doTheLegs()


   return a
end

function Actor:setRandPos()
   self.lfoot.transforms.l[1] = self.lfoot.transforms.l[1] + math.sin(self.time)/120
   self.lfoot.transforms.l[2] = self.lfoot.transforms.l[2] + math.cos(self.time)/20

end


function Actor:doTheLegs()
   self.body.generatedMeshes = {}

   local useRubber = self.useRubber

   
   if useRubber then
      local m = math.sin(self.time*13)
      local o = mapInto(m, -1, 1, 0, 0.5)
      self.lfoot.transforms.l[2] = self.leg1_connector.points[1][2] + (self.leglength/self.magic) - (self.leglength/self.magic)*o 
      
      local m = math.sin(self.time*13)
      local o = mapInto(m, -1, 1, 0, 0.5)
      self.rfoot.transforms.l[2] = self.leg2_connector.points[1][2] + (self.leglength/self.magic) - (self.leglength/self.magic)*o 
   else
      self.lfoot.transforms.l[2] = self.leg1_connector.points[1][2] + (self.leglength/self.magic) 
      self.rfoot.transforms.l[2] = self.leg2_connector.points[1][2] + (self.leglength/self.magic) 

   end
   
   
   function oneLeg(connector, transforms, flip)
      local rnd = love.math.random()*30
      local lineData = {
         outer = {20, 5},
         inner = {16, 3}
      }
      local steps = 10
      local result, widths, widths2 = makeRubberHoseLeg(
         {x=connector.points[1][1],
          y=connector.points[1][2]},
         {x=transforms.l[1],
          y=transforms.l[2]},
         self.leglength,
         steps,
         lineData,
         flip
      )
      
      if not useRubber then
         result = {}
         local dx =  transforms.l[1] - connector.points[1][1] 
         local dy =  transforms.l[2] - connector.points[1][2]  

         for i = 0, steps do
            table.insert(result, connector.points[1][1] + (dx/steps) * i)
            table.insert(result, connector.points[1][2] + (dy/steps) * i)
         end
      end
      
      local verts, indices, draw_mode = polyline('bevel',result, widths)
      local mesh = love.graphics.newMesh(simple_format, verts, draw_mode)
      table.insert(self.body.generatedMeshes, {mesh=mesh, color = { 0,0,0 }})

      
      local verts, indices, draw_mode = polyline('bevel',result, widths2)
      local mesh = love.graphics.newMesh(simple_format, verts, draw_mode)
      table.insert(self.body.generatedMeshes, {mesh=mesh, color = { 0.67, 0.32, 0.21, 1 }})
      
   end

   
  -- if self.body._globalTransform then
    --  print(inspect(self.body._globalTransform))
   --end

   --self.lfoot.transforms[2]=500
   
   oneLeg(self.leg1_connector, self.lfoot.transforms, -1)
   oneLeg(self.leg2_connector, self.rfoot.transforms, 1)

   
   -- local result, widths, widths2 = makeRubberHoseLeg(
   --    {x=self.leg1_connector.points[1][1],
   --     y=self.leg1_connector.points[1][2]},
   --    {x=self.lfoot.transforms.l[1],
   --     y=self.lfoot.transforms.l[2]},
   --    self.leglength+0,
   --    -1
   -- )

   -- local verts, indices, draw_mode = polyline('bevel',result, widths)
   -- local mesh = love.graphics.newMesh(simple_format, verts, draw_mode)

   -- table.insert(self.body.generatedMeshes, {mesh=mesh, color = { 0,0,0 }})

   -- local verts, indices, draw_mode = polyline('bevel',result, widths2)
   -- local mesh = love.graphics.newMesh(simple_format, verts, draw_mode)
   -- table.insert(self.body.generatedMeshes, {mesh=mesh, color = { 0.67, 0.32, 0.21, 1 }})

   --  local result, widths, widths2 = makeRubberHoseLeg(
   --    {x=self.leg2_connector.points[1][1],
   --     y=self.leg2_connector.points[1][2]},
   --    {x=self.rfoot.transforms.l[1],
   --     y=self.rfoot.transforms.l[2]},
   --    self.leglength+0,
   --    1
   -- )

   -- local verts, indices, draw_mode = polyline('bevel',result, widths)
   -- local mesh = love.graphics.newMesh(simple_format, verts, draw_mode)

   -- table.insert(self.body.generatedMeshes, {mesh=mesh, color = { 0,0,0}})

   -- local verts, indices, draw_mode = polyline('bevel',result, widths2)
   -- local mesh = love.graphics.newMesh(simple_format, verts, draw_mode)
   -- table.insert(self.body.generatedMeshes, {mesh=mesh, color = { 0.67, 0.32, 0.21, 1 }})


end


--function transposition(x, y, direction, distance)
--   return distance*math.cos(direction)+x, distance*math.sin(direction)+y
--end

--local time = 0
function Actor:update(dt)
   self.time = self.time or 0
   self.time = self.time + dt
   --print(self.time, math.sin(self.time))
   --local x2,y2 = transposition()

   --self.leg1_connector.points[1][2] = 50 --+ self.leglength/self.magic
   --self.lfoot.transforms.l[2] = self.lfoot.transforms.l[2] + (math.sin(self.time)/145)
   --self.rfoot.transforms.l[2] = self.rfoot.transforms.l[2] + (math.sin(self.time)/45)  

   --self.lfoot.transforms.l[1] = self.lfoot.transforms.l[1] + dt*10
   if self.body.pressed then
      --      self:setRandPos()
      local pivx = self.body.transforms.l[6]
      local pivy = self.body.transforms.l[7]
      local px,py = self.body._globalTransform:transformPoint(pivx, pivy)

      print(py, self.body.leglength)
      if py <= -self.body.leglength then
         self.useRubber = false
      else
         self.useRubber = true
      end
      
      --print('maybe we have something here?', inspect(self.body.pressed))
--      local  l = self.body.transforms.l
 --     if l[2] < (self.leglength / self.magic) then
   --      print('above')
     --else
      --   print('below')
     -- end
      
      --print(inspect(self.body.transforms.l))
      
      --print(self.leglength / self.magic)
      --self.rfoot.transforms.l[1] = self.rfoot.transforms.l[1] + self.body.pressed.dx
      --self.lfoot.transforms.l[2] = self.lfoot.transforms.l[2] + self.body.pressed.dy

   end
   
   --self.lfoot.transforms.l[3] = self.lfoot.transforms.l[3] + 0.01
   --self.rfoot.transforms.l[2] = self.rfoot.transforms.l[2] + love.math.random() -0.5

   self:doTheLegs()
   -- do some stuff to the feet here
end

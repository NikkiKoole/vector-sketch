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


function makeRubberHoseLeg(a, b, length, flip)
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
   local steps = 14
   for i =0, steps do
      local px, py = curve:evaluate(i/steps)
      table.insert(result, px)
      table.insert(result, py)
   end

   local widths = {}
   for i =1, #result/2 do
      widths[i] = (#result/2+4)-i
   end

   local widths2 = {}
   for i =1, #result/2 do
      widths2[i] = (#result/2+1)-i
   end

   return result, widths, widths2
end


function Actor:create(bodyparts)
   local a = {}             -- our new object
   setmetatable(a,Actor)    -- make Account handle lookup

   a.body = bodyparts.body
   a.lfoot = bodyparts.lfoot
   a.rfoot = bodyparts.rfoot

   a.leg1_connector = a.body.metaTags[1]
   a.leg2_connector = a.body.metaTags[2]

   local magic = 4.46

   a.leglength = 100

   a.lfoot.transforms.l[1] = a.leg1_connector.points[1][1]
   a.lfoot.transforms.l[2] = a.leg1_connector.points[1][2] + a.leglength/magic

   a.rfoot.transforms.l[1] = a.leg2_connector.points[1][1]
   a.rfoot.transforms.l[2] = a.leg2_connector.points[1][2] + a.leglength/magic




   a.body.generatedMeshes = {} -- we can put the line meshes in here

   table.insert(a.body.children, a.lfoot)
   table.insert(a.body.children, a.rfoot)



   a:doTheLegs()


   return a
end

function Actor:doTheLegs()
   self.body.generatedMeshes = {}
   local result, widths, widths2 = makeRubberHoseLeg(
      {x=self.leg1_connector.points[1][1],
       y=self.leg1_connector.points[1][2]},
      {x=self.lfoot.transforms.l[1],
       y=self.lfoot.transforms.l[2]},
      self.leglength+0,
      -1
   )

   local verts, indices, draw_mode = polyline('bevel',result, widths)
   local mesh = love.graphics.newMesh(simple_format, verts, draw_mode)

   table.insert(self.body.generatedMeshes, {mesh=mesh, color = { 0,0,0 }})

   local verts, indices, draw_mode = polyline('bevel',result, widths2)
   local mesh = love.graphics.newMesh(simple_format, verts, draw_mode)
   table.insert(self.body.generatedMeshes, {mesh=mesh, color = { 0.67, 0.32, 0.21, 1 }})

    local result, widths, widths2 = makeRubberHoseLeg(
      {x=self.leg2_connector.points[1][1],
       y=self.leg2_connector.points[1][2]},
      {x=self.rfoot.transforms.l[1],
       y=self.rfoot.transforms.l[2]},
      self.leglength+0,
      1
   )

   local verts, indices, draw_mode = polyline('bevel',result, widths)
   local mesh = love.graphics.newMesh(simple_format, verts, draw_mode)

   table.insert(self.body.generatedMeshes, {mesh=mesh, color = { 0,0,0}})

   local verts, indices, draw_mode = polyline('bevel',result, widths2)
   local mesh = love.graphics.newMesh(simple_format, verts, draw_mode)
   table.insert(self.body.generatedMeshes, {mesh=mesh, color = { 0.67, 0.32, 0.21, 1 }})


end




function Actor:update()

   self.lfoot.transforms.l[2] = self.leg1_connector.points[1][2] + (self.leglength/4.46)
   --self.lfoot.transforms.l[1] = self.lfoot.transforms.l[1] + love.math.random() -0.5
   --self.lfoot.transforms.l[2] = self.lfoot.transforms.l[2] + love.math.random() -0.5
   --self.lfoot.transforms.l[3] = self.lfoot.transforms.l[3] + 0.01
   --self.rfoot.transforms.l[1] = self.rfoot.transforms.l[1] + love.math.random() -0.5
   --self.rfoot.transforms.l[2] = self.rfoot.transforms.l[2] + love.math.random() -0.5

  -- self:doTheLegs()
   -- do some stuff to the feet here
end

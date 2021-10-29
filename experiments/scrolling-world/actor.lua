Actor = {}
Actor.__index = Actor


function positionControlPoints(start, eind, hoseLength, flop)
   local borderRadius = 0

   local pxm,pym = getPerpOfLine(start.x,start.y, eind.x, eind.y)
   pxm = pxm * flop
   pym = pym * -flop
   local d = distance(start.x,start.y, eind.x, eind.y)

   -- this is breaking needs some asserts
   print(math.sqrt(-1000))
   --print((hoseLength*hoseLength) - (2* (d*d)))
   --print(math.sqrt((hoseLength*hoseLength) - (2* (d*d)) ))
   --print(math.sqrt((hoseLength*hoseLength) - (2* (d*d))) / math.sqrt(2))

   local b = getEllipseWidth(hoseLength, d)
   print('b', b, hoseLength, d)
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
   print(d, length)
   if d < length then
      print('is this an error!')
   end
   
   local cp, cp2 = positionControlPoints(a, b, length, flip)
   if tostring(cp.x) == 'nan' then
      print('now its broken')
   end
   
   local curve = love.math.newBezierCurve({start.x,start.y,cp.x,cp.y,cp2.x,cp2.y,eind.x,eind.y})


   local result = {}
   local steps = 6
   for i =0, steps do
      local px, py = curve:evaluate(i/steps)
      table.insert(result, px)
      table.insert(result, py)
   end
   
   local widths = {}
   for i =1, #result/2 do
      widths[i] = (#result/2+4)-i
   end

   return result, widths
end


function Actor:create(bodyparts)
   local a = {}             -- our new object
   setmetatable(a,Actor)    -- make Account handle lookup

   a.body = bodyparts.body
   a.lfoot = bodyparts.lfoot
   a.rfoot = bodyparts.rfoot

   a.leg1_connector = a.body.metaTags[1]
   a.leg2_connector = a.body.metaTags[2]


   local offset = 45
   a.lfoot.transforms.l[1] = a.leg1_connector.points[1][1]
   a.lfoot.transforms.l[2] = a.leg1_connector.points[1][2] + offset

   a.rfoot.transforms.l[1] = a.leg2_connector.points[1][1]
   a.rfoot.transforms.l[2] = a.leg2_connector.points[1][2] + offset

   
--   a.lfoot.transforms.l[2] = 37

   a.body.generatedMeshes = {} -- we can put the line meshes in here

   table.insert(a.body.children, a.lfoot)
   table.insert(a.body.children, a.rfoot)

   

   local result, widths = makeRubberHoseLeg(
      {x=a.leg1_connector.points[1][1],
       y=a.leg1_connector.points[1][2]},
      {x=a.lfoot.transforms.l[1],
       y=a.lfoot.transforms.l[2]},
      offset+10,
      -1

   )
   --print(inspect(result))

   
   local verts, indices, draw_mode = polyline('bevel',result, widths)
   local mesh = love.graphics.newMesh(simple_format, verts, draw_mode)
   table.insert(a.body.generatedMeshes, mesh)

   
   return a
end



function Actor:update()
   --self.lfoot.transforms.l[1] = self.lfoot.transforms.l[1] + love.math.random() -0.5
   --self.lfoot.transforms.l[3] = self.lfoot.transforms.l[3] + 0.01
   --self.rfoot.transforms.l[1] = self.rfoot.transforms.l[1] + love.math.random() -0.5

   -- do some stuff to the feet here 
end



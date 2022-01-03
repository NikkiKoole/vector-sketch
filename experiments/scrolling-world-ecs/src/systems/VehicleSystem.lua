local VehicleSystem = Concord.system({pool = {'vehicle'}})

function VehicleSystem:update(dt)

   for _, e in ipairs(self.pool) do

      local base = e.transforms.transforms.l[1]
      local baseY = e.transforms.transforms.l[2]
      local x1 = e.vehicle.wheel1.transforms.l[1]
      local y1 = getGlobalHeight(base + x1) + e.vehicle.radius1
      local x2 = e.vehicle.wheel2.transforms.l[1]
      local y2 = getGlobalHeight(base + x2) + e.vehicle.radius2

      



      local stuckOnFloor = false
      if stuckOnFloor then
         e.vehicle.body.transforms.l[2]= getGlobalHeight(base) -- e.vehicle.radius1
         e.vehicle.body.transforms.l[3]= math.atan2(y2-y1,x2-x1)
      else
         --print(math.abs(e.transforms.transforms.l[2] - getGlobalHeight(e.transforms.transforms.l[1]) ))

         if  e.vehicle.body.transforms.l[2] > getGlobalHeight(base) then

            local dy2 = e.vehicle.body.transforms.l[2] - getGlobalHeight(base)
            e.vehicle.body.transforms.l[2] = getGlobalHeight(base)
            
            if (e.inStack) then
               positionAllInStack(e, 0, dy2*-1)
            end

            
         end
         


         

         
         local distanceFromOptimal = math.abs(baseY - getGlobalHeight(base) )
         
         local v = mapInto(clamp(distanceFromOptimal,0,100), 0, 100, math.atan2(y2-y1,x2-x1), 0)
--         print(v)
--         if  distanceFromOptimal <= 100 then
  --          e.vehicle.body.transforms.l[3]= math.atan2(y2-y1,x2-x1)
    --     else
            e.vehicle.body.transforms.l[3]= v

      --   end

      end
      



      
      
   end
end

-- unused
function VehicleSystem:draw(dt)
   for _, e in ipairs(self.pool) do
      local x = e.transforms.transforms.l[1]
      local y = e.transforms.transforms.l[2]

      love.graphics.rectangle('fill', x,y ,10,10)
   end
   
end


-- maybe cache lastPos for vehicle somewhere

function VehicleSystem:itemDrag( c, l, x, y, dx, dy)

   if c.entity and c.entity.vehicle then
      local rotateStep = dx
      local rx, ry = c.transforms._g:transformPoint( rotateStep, 0)
      local rx2, ry2 = c.transforms._g:transformPoint( 0, 0)
      local rxdelta = rx - rx2
      local dd1 = (rxdelta/c.entity.vehicle.circum1) * (math.pi*2) 
      local dd2 = (rxdelta/c.entity.vehicle.circum2) * (math.pi*2) 

      c.entity.vehicle.wheel1.transforms.l[3] =
         c.entity.vehicle.wheel1.transforms.l[3] + dd1
      
      c.entity.vehicle.wheel2.transforms.l[3] =
         c.entity.vehicle.wheel2.transforms.l[3] + dd2


   end
   
   
end

return VehicleSystem

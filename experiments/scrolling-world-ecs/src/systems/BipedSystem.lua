local BipedSystem = Concord.system({pool={'biped', 'actor'}})

function BipedSystem:update(dt)
   -- todo
   -- what exactly is that originalX originalY ?
   -- try and just use biped or actor, not both
   -- get rid of all functions on Actor

   for _, e in ipairs(self.pool) do

      if(not e.biped.body.pressed and e.actor.value.wasPressed) then
	 e.actor.value.wasPressed = false
         local oldLeftFootY = e.biped.lfoot.transforms.l[2]
         local oldLeftFootX = e.biped.lfoot.transforms.l[1]

	 e.actor.value:straightenLegs()

         local newLeftFootY = e.biped.lfoot.transforms.l[2]
         local newLeftFootX = e.biped.lfoot.transforms.l[1]

         local dy = oldLeftFootY- newLeftFootY
         local dx = oldLeftFootX- newLeftFootX

         if dy ~= 0 or dx ~= 0 then
	    e:getWorld():emit("itemThrow", e.biped.body, dx, dy, 11)
         end

      end

      if (e.biped.body.pressed) then
	 e.actor.value.wasPressed = true
	 setTransforms(e.biped.body)

	 local pivx = e.biped.body.transforms.l[6]
	 local pivy = e.biped.body.transforms.l[7]
	 local px,py = e.biped.body.transforms._g:transformPoint(pivx, pivy)

         local bodyHY = getGlobalHeight(e.biped.body.transforms.l[1])

         
	 local dist = (math.sqrt((px - e.actor.value.originalX)^2 + (py - e.actor.value.originalY)^2   ))

	 local tooFar = dist > (e.actor.value.leglength / e.actor.value.magic)
	 if tooFar then
	    e.actor.value.originalX = e.biped.body.transforms.l[1]
	    e.actor.value.originalY = e.biped.body.transforms.l[2]
	 end


	 if py <= -e.biped.body.leglength + bodyHY then
	    e.actor.value:straightenLegs()
	 else

                       
	    e.biped.lfoot.transforms.l[1] = e.actor.value.leg1_connector.points[1][1] - px + e.actor.value.originalX
            e.biped.lfoot.transforms.l[2] = e.actor.value.leg1_connector.points[1][2] - py


            
            local gh = getGlobalHeight(px + e.biped.lfoot.transforms.l[1])
            e.biped.lfoot.transforms.l[2] = e.biped.lfoot.transforms.l[2] + gh

            

	    e.biped.rfoot.transforms.l[1] = e.actor.value.leg2_connector.points[1][1] - px + e.actor.value.originalX
	    e.biped.rfoot.transforms.l[2] = e.actor.value.leg2_connector.points[1][2] - py



            gh = getGlobalHeight(px + e.biped.rfoot.transforms.l[1])
            e.biped.rfoot.transforms.l[2] = e.biped.rfoot.transforms.l[2] + gh

            
	    e.biped.body.generatedMeshes = {}

	    e.actor.value:oneLeg(e.actor.value.leg1_connector, e.biped.lfoot.transforms, -1)
	    e.actor.value:oneLeg(e.actor.value.leg2_connector, e.biped.rfoot.transforms, 1)
	 end
      end
   end

end

return BipedSystem

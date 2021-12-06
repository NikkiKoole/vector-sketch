local RotateOnMoveSystem = Concord.system({pool={'rotateOnMove'}})

function RotateOnMoveSystem:update(dt)
      for _, e in ipairs(self.pool) do
         local transforms = e.transforms.transforms
         --transforms.l[3] = transforms.l[3] + 0.01
         --print('yoohoo!')
	 --if e.pressed then
	--     transforms.l[3] = transforms.l[3] + 0.01
	 --end
	 
         
      end
      

end

function RotateOnMoveSystem:itemDrag( c, l, x, y, invx, invy)
   --print('RotateOnMoveSystem drag')print
   --   print(c.children[1].transforms.l[3])

--   prparentint(c.name)
 --  print(#c._parent.name)
   --local thing = 
   --c.transforms.l[3] = c.transforms.l[3] + 0.01

 --  c.transforms.l[3] = c.transforms.l[3] + 0.01
--   C.transforms.l[3]  =  c.transforms.l[3] - 0.001
  -- setTransforms(c)
end




return RotateOnMoveSystem

--   c.transforms.l[3]  =  c.transforms.l[3] - 0
--   c.transforms.l[3]  =  c.transforms.l[3] - 0

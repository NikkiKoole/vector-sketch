local RotateOnMoveSystem = Concord.system({pool={'rotateOnMove'}})

function RotateOnMoveSystem:update(dt)
end

function RotateOnMoveSystem:itemDrag( c, l, x, y, invx, invy)
   --print('RotateOnMoveSystem drag')print
   print(c.transforms.l[3])
   c.transforms.l[3]  =  c.transforms.l[3] - 0.001
   setTransforms(c)
end



return RotateOnMoveSystem

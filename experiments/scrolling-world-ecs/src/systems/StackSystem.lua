--[[

stackable:  means this is a normal item that is allowed to be placed in a stack
inStack  : means this thing is in a stack, inStack has a prev & next link (double linked list)
]]--
local StackSystem = Concord.system({pool = {'stackable'}})





--function StackSystem:update(dt)
--end
--function StackSystem:itemDrag( c, l, x, y, invx, invy)
-- if (c.entity and c.entity.vanillaDraggable and c.pressed) then
--    c.transforms.l[1] = c.transforms.l[1] + (invx - c.pressed.dx)
--    c.transforms.l[2] = c.transforms.l[2] + (invy - c.pressed.dy)
-- end
--end

local MAX_DISTANCE_TO_CONNECT = 20

function StackSystem:itemThrow(target, dxn, dyn, speed)
   -- an item has been released and might want to end up in a stack.
   
   if target.entity.stackable then
      local foundOneToConnectMyselfTo = nil

      -- figure out if anything is near i can connect myself to
      
      if target.entity.layer  then
	 local layer, pdata = retrieveLayerAndParallax(target.entity.layer.index)
	 local checkAgainst = getItemsInLayerThatHaveSpecificMeta(layer, 'connector')
	 local nearest = {distance=math.huge, elem=nil}

	 local px, py = target.transforms._g:transformPoint( target.transforms.l[6], target.transforms.l[7])
	 local camData = createCamData(target, pdata)
	 local pivx, pivy = cam:getScreenCoordinates(px, py, camData)
	 
	 for j =1, #checkAgainst do
	    for k = 1, #checkAgainst[j].metaTags do
	       local tag = checkAgainst[j].metaTags[k]

	       if (tag.name == 'connector' and checkAgainst[j] ~= target) then
		  local pos = tag.points[1] -- there is just one point in this collection
		  local kx, ky = checkAgainst[j].transforms._g:transformPoint(pos[1], pos[2])
		  local camData = createCamData(checkAgainst[j], pdata)
		  local kx2, ky2 = cam:getScreenCoordinates(kx, ky, camData)

		  local dis = distance(pivx, pivy, kx2, ky2)
		  if dis < nearest.distance then
		     nearest.distance = dis
		     nearest.elem = checkAgainst[j]
		  end
	       end
	    end
	 end

	 --print('the nearest connection possibile is ', nearest.distance)
	 if (nearest.distance <= MAX_DISTANCE_TO_CONNECT) then
	    foundOneToConnectMyselfTo = nearest.elem
	 end
	 
	
	 -- found one to connect myself to
	 if foundOneToConnectMyselfTo then
	    target.entity:remove('inMotion')

	    local changeDepth = true
	    if changeDepth then
	       target.depth = foundOneToConnectMyselfTo.depth + 0.01
	       local layer, pdata = retrieveLayerAndParallax(target.entity.layer.index)
	       sortOnDepth(layer.children)
	    end
	 end

	 -- the next step is, the one i am connecting to, is that already a stack or not
	 -- if not, we need to create the newly made stack now

	 -- todo when do we remove the inStack component ?

	 if foundOneToConnectMyselfTo then
	    if foundOneToConnectMyselfTo.entity.inStack then
	       foundOneToConnectMyselfTo.entity.inStack.next = target
	       target.entity:give('inStack', foundOneToConnectMyselfTo, nil)
	    else
	       foundOneToConnectMyselfTo.entity:give('inStack', nil, target)
	       target.entity:give('inStack', foundOneToConnectMyselfTo, nil)
	    end
	 end

	 if not foundOneToConnectMyselfTo then
	    if target.entity.inStack then
	       --print('this thing is in a stack, but we didnt find anything to connect too')
	       -- atleast remove the inStack prev link from both sides
	       local prev = target.entity.inStack.prev
	       if prev then
		  prev.entity.inStack.next = nil
	       end
	       target.entity.inStack.prev = nil
	       
	    end
	 end
	 
	 
         
	 
	 
      end
      
   end
end

--function StackSystem:pressed(x,y)
--end

return StackSystem

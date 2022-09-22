local geom = require 'lib.geom'
local parallax = require 'lib.parallax'
local cam = getCamera()
--[[
stackable :  means this is a normal item that is allowed to be placed in a stack
inStack   :  means this thing is in a stack, inStack has a prev & next link (double linked list)
]]--
local StackSystem = Concord.system({pool = {'stackable'}})


local MAX_DISTANCE_TO_CONNECT = 20

function StackSystem:itemThrow(target, dxn, dyn, speed)
   -- an item has been released and might want to end up in a stack.
   
   if target.entity.stackable then
      local connectTo = nil

      -- figure out if anything is near i can connect myself to
      
      if target.entity.layer  then
	 local layer, pdata, data = retrieveLayerAndParallax(target.entity.layer.index)
	 local checkAgainst = getItemsInLayerThatHaveSpecificMeta(layer, 'connector')
	 local nearest = {distance=math.huge, elem=nil}

	 local px, py = target.transforms._g:transformPoint( target.transforms.l[6], target.transforms.l[7])
	 local camData = createCamData(target, pdata)
	 local pivx, pivy = cam:getScreenCoordinates(px, py, camData)
	 
	 for j =1, #checkAgainst do
	    for k = 1, #checkAgainst[j].metaTags do
	       local tag = checkAgainst[j].metaTags[k]

	       if (tag.name == 'connector' and checkAgainst[j] ~= target) then
		  -- todo you cant connect to items that already have an inStack & next
		  -- those are taken already

		  if checkAgainst[j].entity.inStack and checkAgainst[j].entity.inStack.next then
		  else
		     local pos = tag.points[1] -- there is just one point in this collection
		     local kx, ky = checkAgainst[j].transforms._g:transformPoint(pos[1], pos[2])
		     local camData = createCamData(checkAgainst[j], pdata)
		     local kx2, ky2 = cam:getScreenCoordinates(kx, ky, camData)

		     local dis = geom.distance(pivx, pivy, kx2, ky2)
		     if dis < nearest.distance then
			nearest.distance = dis
			nearest.elem = checkAgainst[j]
                        nearest.tag = tag
		     end
		  end
	       end
	    end
	 end

	 --print('the nearest connection possibile is ', nearest.distance)
	 if (nearest.distance <= MAX_DISTANCE_TO_CONNECT) then
	    connectTo = nearest.elem
	 end

	 -- if the one i am connecting to is still in assetbook remove it from there
	 if (connectTo) then
	    if connectTo.entity.assetBook then
	       removeFromAssetBook(connectTo, data)
	    end
	 end
   
	 
	 -----  this is the real stack stuff aka thedouble linked list of items
	 removeNode(target)
	 if (connectTo) then
	    insertNodeAfter(target, connectTo, nearest.tag.name)
	 end
	 -----  end this is the real stack stuff aka thedouble linked list of items


   

         if connectTo then
	    target.entity:remove('inMotion')

	    local changeDepth = true
            arrangeDepthOfStack(target)
	    if changeDepth then
	       local layer, pdata = retrieveLayerAndParallax(target.entity.layer.index)
	       parallax.sortOnDepth(layer.children)
	    end
	   

	 end

	 -- todo, make the connection hard (actually position the thing at the connnector)
	 
      end
      
   end
end

-- when you connect something (stack or item) to something else (stack or item)
function insertNodeAfter(node, after, connectorName)
   
   if (not node.entity.inStack) then
      node.entity:give('inStack', after, nil, connectorName)
   else
      node.entity.inStack.prev = after
   end
   
   if (not after.entity.inStack) then
      after.entity:give('inStack', nil, node, connectorName)
   else
      after.entity.inStack.next = node
   end
   
   
end

-- when you remove something (stack or item) from a stack
function removeNode(node)
   if (node.entity and node.entity.inStack) then
      if node.entity.inStack then
	 local prev = node.entity.inStack.prev
	 if prev then
	    prev.entity.inStack.next = nil

	    if (prev.entity.inStack.prev == nil) then
	       prev.entity:remove('inStack') 
	    end
	    
	 end
	 node.entity.inStack.prev = nil
      end
      
   end
   
end






return StackSystem

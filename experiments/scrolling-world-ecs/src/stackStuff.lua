
function positionAllInStack(element, dx, dy)
   local nextLink = element.inStack.next
   while nextLink do
      nextLink.transforms.l[1] = nextLink.transforms.l[1] + dx
      nextLink.transforms.l[2] = nextLink.transforms.l[2] + dy
      if nextLink.entity.inStack then
         nextLink = nextLink.entity.inStack.next
      end
   end
end

function findInArrayOnName(array, name)
   for i =1, #array do
      if array[i].name == name then
	 return array[i]
      end
   end
end

function getPositionForNext(current)
   local connectorName = current.entity.inStack.connectorName
   local realConnector = findInArrayOnName(current.metaTags, connectorName)
   local points = realConnector.points[1]
   local x, y = current.transforms._g:transformPoint(points[1],points[2])
   return x,y
end

function arrangeDepthOfStack(someNode)
   -- i dont know the root of the stack in advance first find it
   local root = someNode

   while root.entity.inStack and root.entity.inStack.prev do
      root = root.entity.inStack.prev
   end

   -- now i have the root.
   -- lets walk from the root, to the end and increase the depth everytime

   
   local current = root
   local depth = current.depth
   local nextX, nextY = getPositionForNext(current)
   local counter = 0
   
   while current.entity.inStack and current.entity.inStack.next do
      current = current.entity.inStack.next
      
      current.transforms.l[1] = nextX
      current.transforms.l[2] = nextY
      current.transforms.l[3] = counter*0.1
      setTransforms(current)  -- this was needed!!!!!!
      
      nextX, nextY = getPositionForNext(current)
      depth = depth + 0.000001
      current.depth = depth

      counter = counter + 1
   end
   
end


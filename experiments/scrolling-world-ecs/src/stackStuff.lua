


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



function arrangeDepthOfStack(someNode)
   -- i dont know the root of the stack in advance first find it
   local root = someNode

   while root.entity.inStack and root.entity.inStack.prev do
      root = root.entity.inStack.prev
   end

   -- now i have the root.
   -- lets walk from the root, to the end and increase the depth everytime
   -- todo: i also need to position the things to the connector node I think
   local current = root
   local depth = current.depth
   while current.entity.inStack and current.entity.inStack.next do
      current = current.entity.inStack.next
      depth = depth + 0.000001
      current.depth = depth
   end
   
end


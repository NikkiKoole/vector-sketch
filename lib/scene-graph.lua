-- scene graph function are functions that are related to the child.parent relation of nodes
-- or to the transformation stuff inside of them

-- a bunch of global functions in editor need to go here


function parentize(node)
   if (node.children) then
   for i = 1, #node.children do
      node.children[i]._parent = node
      if (node.children[i].folder) then
	 parentize(node.children[i])
      end
   end
   end
end

function getIndex(item)
   if (item and item._parent) then
      for k,v in ipairs(item._parent.children) do
         if v == item then return k end
      end
   end
   return -1
end


function findNodeByName(root, name)
   if (root.name == name) then
      return root
   end
   if root.children then
      for i=1, #root.children do
	 local result = findNodeByName(root.children[i], name)
	 if result then return result end
      end
   end
   return nil
end

function addNodeInGroup(node, group)
   node._parent = group
   table.insert(group.children, node)
end

function addAfterNode(element, after)
   element._parent = after._parent
   table.insert(after._parent.children, getIndex(after), element)
end

function removeNodeFrom(element, from)
   assert(getIndex(element))
   return table.remove(from.children, getIndex(element))
end

function setTransforms(root)
   
   -- todo this is not right
   -- instead of always making new transforms I need to only do this onDirty (which will be passed alonb the graph)
   local tl = root.transforms.l
   local pg = nil
   if (root._parent) then
      pg = root._parent.transforms._g
   end
   root.transforms._l = love.math.newTransform( tl[1], tl[2], tl[3], tl[4], tl[5], tl[6], tl[7], tl[8],tl[9])
   root.transforms._g = pg and (pg * root.transforms._l) or root.transforms._l
end

function getLocalizedDelta(element, dx, dy)
   local x1,y1 = element._parent.transforms._g:inverseTransformPoint(dx,dy)
   local x0, y0 = element._parent.transforms._g:inverseTransformPoint(0,0)
   return x1-x0, y1-y0
end

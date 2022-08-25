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

function setX(node, x)
   node.transforms.l[1] = x
end
function setY(node, y)
   node.transforms.l[2] = y
end
function setPos(node, x,y)
   node.transforms.l[1] = x
   node.transforms.l[2] = y
end
function setRotation(node, r)
   node.transforms.l[3] = r
end
function setScale(node, s)
   node.transforms.l[4] = 3
   node.transforms.l[5] = 3
end
function setScaleX(node, sx)
   node.transforms.l[4] = sx
end
function setScaleY(node, sy)
   node.transforms.l[5] = sy
end
function setPivotX(node, px)
   node.transforms.l[6] = px
end
function setPivotY(node, py)
   node.transforms.l[7] = py
end
function setPivot(node, px, py)
   node.transforms.l[6] = px
   node.transforms.l[7] = py
end






function setTransforms(root, isDirty)
   -- instead of always making new transforms I need to only do this onDirty (which will be passed alonb the graph)

   -- some items have issues with this, mostly things that have a _parent
   -- I think the issue has todo with the hittesting returning a child of the thing instead of the thing itself
   
   
  --if  (isDirty==true) or (isDirty==nil) then -- isdirty == nil check so unset dirty flags are also treated as true
      local tl = root.transforms.l
      local pg = nil
      if (root._parent) then
	 pg = root._parent.transforms._g
      end
      
      if (root.transforms._l == nil) then
	 root.transforms._l = love.math.newTransform( tl[1], tl[2], tl[3], tl[4], tl[5], tl[6], tl[7], tl[8],tl[9])
      else -- this works but doesnt really improve anything measurable at this time
	 root.transforms._l:setTransformation( tl[1], tl[2], tl[3], tl[4], tl[5], tl[6], tl[7], tl[8],tl[9])
      end
      
      root.transforms._g = pg and (pg * root.transforms._l) or root.transforms._l
      
      root.dirty = false
    --end
   
end

function getLocalizedDelta(element, dx, dy)
   local x1,y1 = element._parent.transforms._g:inverseTransformPoint(dx,dy)
   local x0, y0 = element._parent.transforms._g:inverseTransformPoint(0,0)
   return x1-x0, y1-y0
end

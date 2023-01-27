local node = {}

node.getIndex = function(item)
   if (item and item._parent) then
      for k, v in ipairs(item._parent.children) do
         if v == item then return k end
      end
   end
   return -1
end

node.findNodeByName = function(root, name)
   if (root.name == name) then
      return root
   end
   if root.children then
      for i = 1, #root.children do
         local result = node.findNodeByName(root.children[i], name)
         if result then return result end
      end
   end
   if #root then
      for i = 1, #root do
         local result = node.findNodeByName(root[i], name)
         if result then return result end
      end
   end
   return nil
end

node.addNodeInGroup = function(n, group)
   n._parent = group
   table.insert(group.children, n)
end

node.addAfterNode = function(element, after)
   element._parent = after._parent
   table.insert(after._parent.children, node.getIndex(after), element)
end

node.removeNodeFrom = function(element, from)
   assert(node.getIndex(element))
   return table.remove(from.children, node.getIndex(element))
end

node.setX = function(n, x)
   n.transforms.l[1] = x
end

node.setY = function(n, y)
   n.transforms.l[2] = y
end

node.setPos = function(n, x, y)
   n.transforms.l[1] = x
   n.transforms.l[2] = y
end

node.movePos = function(n, dx, dy)
   n.transforms.l[1] = n.transforms.l[1] + dx
   n.transforms.l[2] = n.transforms.l[2] + dy
end

node.setRotation = function(n, r)
   n.transforms.l[3] = r
end

node.setScale = function(n, s)
   n.transforms.l[4] = s
   n.transforms.l[5] = s
end

node.setScaleX = function(n, sx)
   n.transforms.l[4] = sx
end

node.setScaleY = function(n, sy)
   n.transforms.l[5] = sy
end

node.setPivotX = function(n, px)
   n.transforms.l[6] = px
end

node.setPivotY = function(n, py)
   n.transforms.l[7] = py
end

node.setPivot = function(n, px, py)
   n.transforms.l[6] = px
   n.transforms.l[7] = py
end

node.setSkewX = function(n, x)
   n.transforms.l[8] = x
end

node.setSkewY = function(n, y)
   n.transforms.l[9] = y
end

return node

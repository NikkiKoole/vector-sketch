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


return node
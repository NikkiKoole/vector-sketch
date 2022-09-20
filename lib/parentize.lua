local p = {}
p.parentize = function(node)
   if (node.children) then
      for i = 1, #node.children do
         node.children[i]._parent = node
         if (node.children[i].folder) then
            p.parentize(node.children[i])
         end
      end
   end
end
return p

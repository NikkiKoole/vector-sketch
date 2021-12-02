Concord.component(
   'stack',
   function(c, itemsInStack)
      c.items = itemsInStack
   end
)


--Concord.component("inStack")

Concord.component(
   'inStack',
   function(c, prev, next)
      c.prev = prev
      c.next = next
   end
   
)

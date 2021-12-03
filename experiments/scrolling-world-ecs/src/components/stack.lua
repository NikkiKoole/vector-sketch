Concord.component(
   'stack',
   function(c, itemsInStack)
      c.items = itemsInStack
   end
)


--Concord.component("inStack")

Concord.component(
   'inStack',
   function(c, prev, next, connectorName)
      c.prev = prev
      c.next = next
      c.connectorName = connectorName
   end
   
)

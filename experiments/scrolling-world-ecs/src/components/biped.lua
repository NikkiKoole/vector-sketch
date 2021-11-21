Concord.component(
   'biped',
   function(c, body, lfoot, rfoot)
      c.body = body
      c.lfoot = lfoot
      c.rfoot = rfoot
   end
)
Concord.component(
   'actor',
   function(c, value)
      c.value = value
   end
)

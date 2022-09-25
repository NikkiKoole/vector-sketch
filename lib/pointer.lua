local pointer = {}
pointer.getPosition = function(id)
   local x, y
   if id == 'mouse' then
      x, y = love.mouse.getPosition()
      return x, y, true
   else
      local touches = love.touch.getTouches()
      for i = 1, #touches do
         if touches[i] == id then
            x, y = love.touch.getPosition(id)
            return x, y, true
         end
      end
   end
   return nil, nil, false
end

return pointer

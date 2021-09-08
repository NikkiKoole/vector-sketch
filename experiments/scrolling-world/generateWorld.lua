function test()
   local start = love.timer.getTime()
   for x = 1, 100 do
      for y = 1, 100 do
         love.math.noise((x/100) * 200, (y/100) * 200)
      end
   end
   local result = love.timer.getTime() - start
   print(string.format("generate world took %.9f millisecs.", result * 1000))
end

local numbers = {}

numbers.mapInto = function(x, in_min, in_max, out_min, out_max)
   return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end

numbers.clamp = function(x, min, max)
  return x < min and min or (x > max and max or x)
end
--function lerp(a, b, amount)
--  return a + (b - a) * clamp(amount, 0, 1)
--end

-- todo move all lerp things into its own file (a few more in main-utils)
numbers.lerp = function(v0, v1, t)
   return v0*(1-t)+v1*t
end

numbers.randomSign = function()
   return love.math.random() < 0.5 and 1 or -1
end

--unused
local function round2durp(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
   return math.floor(num * mult + 0.5) / mult
end

function round2(num, numDecimalPlaces)
   local r = tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
   return r
end

return numbers

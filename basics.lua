function mapInto(x, in_min, in_max, out_min, out_max)
   return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end

function clamp(x, min, max)
  return x < min and min or (x > max and max or x)
end

function lerp(a, b, amount)
  return a + (b - a) * clamp(amount, 0, 1)
end
function starts_with(str, start)
   return str:sub(1, #start) == start
end
function pointInRect(x,y, rx, ry, rw, rh)
   if x < rx or y < ry then return false end
   if x > rx+rw or y > ry+rh then return false end
   return true
end
function pointInCircle(x,y, cx, cy, cr)
   local dx = x - cx
   local dy = y - cy
   local d  = math.sqrt ((dx*dx) + (dy*dy))
         
   return cr > d
end


function ends_with(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end

function split(str, pos)
   local offset = utf8.offset(str, pos) or 0
   return str:sub(1, offset-1), str:sub(offset)
end

function copyArray(original)
print('copyaray')
   local result = {}
   for i=1, #original do
      table.insert(result, round2(original[i], 3))
   end
   return result
end

function round2durp(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
   return math.floor(num * mult + 0.5) / mult
 end
 

function round2(num, numDecimalPlaces)
local r = tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
return r
end

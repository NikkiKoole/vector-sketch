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
   return v0 * (1 - t) + v1 * t
end

numbers.randomSign = function()
   return love.math.random() < 0.5 and 1 or -1
end

--unused
local function round2durp(num, numDecimalPlaces)
   local mult = 10 ^ (numDecimalPlaces or 0)
   return math.floor(num * mult + 0.5) / mult
end

numbers.round2 = function(num, numDecimalPlaces)
   local r = tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
   return r
end

numbers.transferPoint = function(xI, yI, source, destination)

   local ADDING = 0.00001 -- to avoid dividing by zero

   local xA = source[1]
   local yA = source[2]

   local xC = source[3]
   local yC = source[4]

   local xAu = destination[1][1]
   local yAu = destination[1][2]

   local xBu = destination[2][1]
   local yBu = destination[2][2]

   local xCu = destination[3][1]
   local yCu = destination[3][2]

   local xDu = destination[4][1]
   local yDu = destination[4][2]
   --print(xA,yA,xC,yC)
   --print(xAu,yAu,xBu,yBu,xCu,yCu,xDu,yDu)
   -- Calcultations
   -- if points are the same, have to add a ADDING to avoid dividing by zero
   if (xBu == xCu) then xC = xC + ADDING end
   if (xAu == xDu) then xDu = xDu + ADDING end
   if (xAu == xBu) then xBu = xBu + ADDING end
   if (xDu == xCu) then xCu = xCu + ADDING end
   --print(xC,xDu,xBu,xCu)
   local kBC = (yBu - yCu) / (xBu - xCu)
   local kAD = (yAu - yDu) / (xAu - xDu)
   local kAB = (yAu - yBu) / (xAu - xBu)
   local kDC = (yDu - yCu) / (xDu - xCu)

   if (kBC == kAD) then kAD = kAD + ADDING end
   local xE = (kBC * xBu - kAD * xAu + yAu - yBu) / (kBC - kAD)
   local yE = kBC * (xE - xBu) + yBu

   if (kAB == kDC) then kDC = kDC + ADDING end
   local xF = (kAB * xBu - kDC * xCu + yCu - yBu) / (kAB - kDC)
   local yF = kAB * (xF - xBu) + yBu

   if (xE == xF) then xF = xF + ADDING end
   local kEF = (yE - yF) / (xE - xF)

   if (kEF == kAB) then kAB = kAB + ADDING end
   local xG = (kEF * xDu - kAB * xAu + yAu - yDu) / (kEF - kAB)
   local yG = kEF * (xG - xDu) + yDu

   if (kEF == kBC) then kBC = kBC + ADDING end
   local xH = (kEF * xDu - kBC * xBu + yBu - yDu) / (kEF - kBC)
   local yH = kEF * (xH - xDu) + yDu

   local rG = (yC - yI) / (yC - yA)
   local rH = (xI - xA) / (xC - xA)

   local xJ = (xG - xDu) * rG + xDu
   local yJ = (yG - yDu) * rG + yDu

   local xK = (xH - xDu) * rH + xDu
   local yK = (yH - yDu) * rH + yDu

   if (xF == xJ) then xJ = xJ + ADDING end
   if (xE == xK) then xK = xK + ADDING end
   local kJF = (yF - yJ) / (xF - xJ) --//23
   local kKE = (yE - yK) / (xE - xK) --//12

   local xKE
   if (kJF == kKE) then kKE = kKE + ADDING end
   local xIu = (kJF * xF - kKE * xE + yE - yF) / (kJF - kKE)
   local yIu = kJF * (xIu - xJ) + yJ

   local b = { x = xIu, y = yIu }
   --b.x=math.round(b.x)
   --b.y=math.round(b.y)
   return b
end



return numbers

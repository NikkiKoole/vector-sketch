local unloop = {}

unloop.unpackNodePointsLoop = function(points)
   local unpacked = {}

   for i = 0, #points do
      local nxt = i == #points and 1 or i + 1
      unpacked[1 + (i * 2)] = points[nxt][1]
      unpacked[2 + (i * 2)] = points[nxt][2]
   end

   for i = 0, #points do
      local nxt = i == #points and 1 or i + 1
      unpacked[(#points * 2) + 1 + (i * 2)] = points[nxt][1]
      unpacked[(#points * 2) + 2 + (i * 2)] = points[nxt][2]
   end

   return unpacked
end

unloop.unpackNodePoints = function(points, noloop)
   local unpacked = {}
   if #points >= 1 then
      for i = 0, #points - 1 do
         unpacked[1 + (i * 2)] = points[i + 1][1]
         unpacked[2 + (i * 2)] = points[i + 1][2]
      end

      -- make it go round
      if noloop == nil then
         unpacked[(#points * 2) + 1] = points[1][1]
         unpacked[(#points * 2) + 2] = points[1][2]
      end
   end

   return unpacked

end


return unloop


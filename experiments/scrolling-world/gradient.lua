function hex2rgb(hex)
   hex = hex:gsub("#","")
   return tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))
end

function hex2rgb1(hex)
   hex = hex:gsub("#","")
   return tonumber("0x"..hex:sub(1,2))/255, tonumber("0x"..hex:sub(3,4))/255, tonumber("0x"..hex:sub(5,6))/255
end


gradients = {
   {from={hex2rgb1('#012459')}, to={hex2rgb1('#001322')}},
   {from={hex2rgb1('#003972')}, to={hex2rgb1('#001322')}},
   {from={hex2rgb1('#003972')}, to={hex2rgb1('#001322')}},
   {from={hex2rgb1('#004372')}, to={hex2rgb1('#00182b')}},

   {from={hex2rgb1('#004372')}, to={hex2rgb1('#011d34')}},
   {from={hex2rgb1('#016792')}, to={hex2rgb1('#00182b')}},
   {from={hex2rgb1('#07729f')}, to={hex2rgb1('#042c47')}},
   {from={hex2rgb1('#12a1c0')}, to={hex2rgb1('#07506e')}},

   {from={hex2rgb1('#74d4cc')}, to={hex2rgb1('#1386a6')}},
   {from={hex2rgb1('#efeebc')}, to={hex2rgb1('#61d0cf')}},
   {from={hex2rgb1('#fee154')}, to={hex2rgb1('#a3dec6')}},
   {from={hex2rgb1('#fdc352')}, to={hex2rgb1('#e8ed92')}},

   {from={hex2rgb1('#ffac6f')}, to={hex2rgb1('#ffe467')}},
   {from={hex2rgb1('#fda65a')}, to={hex2rgb1('#ffe467')}},
   {from={hex2rgb1('#fd9e58')}, to={hex2rgb1('#ffe467')}},
   {from={hex2rgb1('#f18448')}, to={hex2rgb1('#ffd364')}},

   {from={hex2rgb1('#f06b7e')}, to={hex2rgb1('#f9a856')}},
   {from={hex2rgb1('#ca5a92')}, to={hex2rgb1('#f4896b')}},
   {from={hex2rgb1('#5b2c83')}, to={hex2rgb1('#d1628b')}},
   {from={hex2rgb1('#371a79')}, to={hex2rgb1('#713684')}},

   {from={hex2rgb1('#28166b')}, to={hex2rgb1('#45217c')}},
   {from={hex2rgb1('#192861')}, to={hex2rgb1('#372074')}},
   {from={hex2rgb1('#040b3c')}, to={hex2rgb1('#233072')}},
   {from={hex2rgb1('#040b3c')}, to={hex2rgb1('#012459')}}

}



function gradientMesh(dir, ...)
   local COLOR_MUL = love._version >= "11.0" and 1 or 255
   -- Check for direction
   local isHorizontal = true
   if dir == "vertical" then
      isHorizontal = false
   elseif dir ~= "horizontal" then
      error("bad argument #1 to 'gradient' (invalid value)", 2)
   end

   -- Check for colors
   local colorLen = select("#", ...)
   if colorLen < 2 then
      error("color list is less than two", 2)
   end

   -- Generate mesh
   local meshData = {}
   if isHorizontal then
      for i = 1, colorLen do
         local color = select(i, ...)
         local x = (i - 1) / (colorLen - 1)

         meshData[#meshData + 1] = {x, 1, x, 1, color[1], color[2], color[3], color[4] or (1 * COLOR_MUL)}
         meshData[#meshData + 1] = {x, 0, x, 0, color[1], color[2], color[3], color[4] or (1 * COLOR_MUL)}
      end
   else
      for i = 1, colorLen do
         local color = select(i, ...)
         local y = (i - 1) / (colorLen - 1)

         meshData[#meshData + 1] = {1, y, 1, y, color[1], color[2], color[3], color[4] or (1 * COLOR_MUL)}
         meshData[#meshData + 1] = {0, y, 0, y, color[1], color[2], color[3], color[4] or (1 * COLOR_MUL)}
      end
   end

   -- Resulting Mesh has 1x1 image size
   return love.graphics.newMesh(meshData, "strip", "static")
end

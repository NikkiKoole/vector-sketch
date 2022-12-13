local lib = {}
local vivid = require 'vendor.vivid'
local geom = require 'lib.geom'
local mask_effect = love.graphics.newShader [[
   vec4 effect (vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
      if (Texel(texture, texture_coords).rgb == vec3(0.0)) {
         // a discarded pixel wont be applied as the stencil.
         discard;
      }
      return vec4(1.0);
   }
]]
local function myStencilFunction(mask)
   love.graphics.setShader(mask_effect)
   love.graphics.draw(mask, 0, 0)
   love.graphics.setShader()
end

-- lifted from alpha padder
local function smoocheCanvas(canvas)

   local imageData = canvas:newImageData()
   local width, height = imageData:getDimensions()
   local format = imageData:getFormat()
   local result = love.image.newImageData(width, height, format)
   local count = 0

   for y = 0, height - 1 do
      for x = 0, width - 1 do
         local r, g, b, a = imageData:getPixel(x, y)
         --if a > biggestAlpha then biggestAlpha = a end

         if a == 0 then
            for x2 = -1, 1 do
               for y2 = -1, 1 do
                  if (x + x2) >= 0 and (x + x2) <= width - 1 then
                     if (y + y2) >= 0 and (y + y2) <= height - 1 then
                        local r, g, b, a = imageData:getPixel(x + x2, y + y2)
                        if (a > 0) then
                           count = count + 1
                           result:setPixel(x, y, r, g, b, 0)
                        end
                     end
                  end
               end
            end
         else

            result:setPixel(x, y, r, g, b, a * 1)
         end

      end
   end
   return result
end

lib.makeTexturedCanvas = function(lineart, mask, texture1, color1, texture2, color2, lineColor)
   local lineartColor = lineColor or { 0, 0, 0, 1 }
   local lw, lh = lineart:getDimensions()
   local canvas = love.graphics.newCanvas(lw, lh)

   love.graphics.setCanvas({ canvas, stencil = true }) --<<<
   --love.graphics.clear(0, 0, 0, 0) ---<<<<
   love.graphics.clear(lineartColor[1], lineartColor[2], lineartColor[3], 0) ---<<<<
   love.graphics.setBlendMode("alpha") ---<<<<
   love.graphics.setStencilTest("greater", 0)
   love.graphics.stencil(function() myStencilFunction(mask) end)

   --local ow, oh = grunge:getDimensions()
   if texture1 and texture1 ~= 1 then
      local gw, gh = texture1:getDimensions()
      local rotation = 0 --delta
      local rx, ry, rw, rh = geom.calculateLargestRect(rotation, gw, gh)

      local scaleX = 2
      local scaleY = 2

      local xMin = lw + -((gw / 2) * scaleX) + (rx * scaleX)
      local xMax = (gw / 2) * scaleX - (ry * scaleX)
      local xOffset = xMin

      local yMin = lh + -((gh / 2) * scaleY) + (rx * scaleY)
      local yMax = (gh / 2) * scaleY - (ry * scaleY)
      local yOffset = yMin



      -- this works too, and like this i dont need to put in big images



      love.graphics.setColor(color1)
      love.graphics.draw(texture1, xOffset, yOffset, rotation, scaleX, scaleY, gw / 2, gh / 2)
   end

   if texture1 == 1 then
      love.graphics.setColor(color1)
      love.graphics.rectangle('fill', 0, 0, 1024, 1024)
   end

   -- second texture
   if texture2 and texture2 ~= 1 then
      local gw, gh = texture2:getDimensions()
      local rotation = 0 --delta
      local rx, ry, rw, rh = geom.calculateLargestRect(rotation, gw, gh)

      local scaleX = 2
      local scaleY = 2

      local xMin = lw + -((gw / 2) * scaleX) + (rx * scaleX)
      local xMax = (gw / 2) * scaleX - (ry * scaleX)
      local xOffset = xMin

      local yMin = lh + -((gh / 2) * scaleY) + (rx * scaleY)
      local yMax = (gh / 2) * scaleY - (ry * scaleY)
      local yOffset = yMin



      -- height of these images is not big enough, redraw them bigger lazy bum
      -- print(inspect(color2))
      love.graphics.setColor(color2)
      -- love.graphics.setColor(0, 0, 0)

      love.graphics.draw(texture2, xOffset, yOffset, rotation, scaleX, scaleY, gw / 2, gh / 2)

      --love.graphics.draw(texture1, m*-maxT1Width,0,0,1.5,1.5)


   end

   if texture2 == 1 then
      love.graphics.setColor(color2)
      love.graphics.rectangle('fill', 0, 0, 1024, 1024)
   end



   love.graphics.setStencilTest()

   -- experimenting with drawing the outline in the canvas itself.
   -- this works perfectly, maybe we can even do the smoothing from alphapadder on the thing before.
   love.graphics.setColor(lineartColor)
   love.graphics.draw(lineart)

   love.graphics.setCanvas() --- <<<<<

   -- how to smooch the canvas ?

   --return result
   -- smooche is slow!!!!
   --local imageData = smoocheCanvas(canvas) --
   local imageData = canvas:newImageData()
   return imageData
end



return lib;

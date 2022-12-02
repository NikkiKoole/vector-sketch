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


lib.makeTexturedCanvas = function(canvas, lineart, mask, texture1, color1, texture2, color2)
   local lw, lh = lineart:getDimensions()
   love.graphics.setCanvas({ canvas, stencil = true }) --<<<
   love.graphics.clear(0, 0, 0, 0) ---<<<<
   love.graphics.setBlendMode("alpha") ---<<<<
   love.graphics.setStencilTest("greater", 0)
   love.graphics.stencil(function() myStencilFunction(mask) end)

   --local ow, oh = grunge:getDimensions()
   local gw, gh = texture1:getDimensions()
   local rotation = 0 --delta
   local rx, ry, rw, rh = geom.calculateLargestRect(rotation, gw, gh)

   local scaleX = .5
   local scaleY = .5

   local xMin = lw + -((gw / 2) * scaleX) + (rx * scaleX)
   local xMax = (gw / 2) * scaleX - (ry * scaleX)
   local xOffset = xMin

   local yMin = lh + -((gh / 2) * scaleY) + (rx * scaleY)
   local yMax = (gh / 2) * scaleY - (ry * scaleY)
   local yOffset = yMin

   love.graphics.setColor(color1)
   love.graphics.draw(texture1, xOffset, yOffset, rotation, scaleX, scaleY, gw / 2, gh / 2)

   -- second texture
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

   love.graphics.setColor(color2)
   --love.graphics.setColor(1, 1, 1)

   love.graphics.draw(texture2, xOffset, yOffset, rotation, scaleX, scaleY, gw / 2, gh / 2)

   --love.graphics.draw(texture1, m*-maxT1Width,0,0,1.5,1.5)


   love.graphics.setStencilTest()


   love.graphics.setCanvas() --- <<<<<
   return canvas
end



return lib;

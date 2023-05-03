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

local ShapeShader = love.graphics.newShader [[
	
	// Effect that renders the shape of a image
	vec4 effect(vec4 Color, Image Texture, vec2 textureCoord, vec2 pixelCoord) {
		
		// Get the pixel color at the given texture
		vec4 pixel = Texel(Texture, textureCoord);
		
		// If it's alpha is higher than zero
		if ( pixel.a > 0.0 ) {
			
			// If it's not black
			if ( pixel.r > 0.0 || pixel.g > 0.0 || pixel.b > 0.0 ) {
				
				// Return the setColor value
				return Color;
				
			}
			
		}
		
		// Return invisible color
		return vec4(0.0, 0.0, 0.0, 0.0);
		
	}
	
]]




-- only used for some ui thing
lib.renderMaskedTexture = function(maskShape, texture, x, y, sx, sy)
   if not texture or not maskShape then return end
   if texture == 1 then return end

   local bw, bh = maskShape:getDimensions()
   local iw, ih = texture:getDimensions()
   local s = math.max(bw / iw, bh / ih)

   local function myStencilFunction()
      love.graphics.setShader(mask_effect)
      love.graphics.draw(maskShape, x, y, 0, sx, sy)
      love.graphics.setShader()
   end

   love.graphics.stencil(myStencilFunction, "replace", 1)
   love.graphics.setStencilTest("greater", 0)
   love.graphics.draw(texture, x, y, 0, s * sx, s * sy)
   love.graphics.setStencilTest()
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

local function getDrawParams(flipx, flipy, imgw, imgh)
   local sx = flipx
   local sy = flipy

   local ox = flipx == -1 and imgw or 0
   local oy = flipy == -1 and imgh or 0

   return sx, sy, ox, oy
end

local function myStencilFunction(mask, flipx, flipy, imgw, imgh)
   love.graphics.setShader(mask_effect)
   local sx, sy, ox, oy = getDrawParams(flipx, flipy, imgw, imgh)
   love.graphics.draw(mask, 0, 0, 0, sx, sy, ox, oy)
   love.graphics.setShader()
end


-- only thing thats no longer possible == using an alpha for the background color
local maskShader = love.graphics.newShader([[
	uniform Image fill;
    uniform vec4 backgroundColor;
    uniform mat2 uvTransform;

	vec4 effect(vec4 color, Image mask, vec2 uv, vec2 fc) {
        vec2 transformedUV = uv * uvTransform;

        vec3 patternMix = mix(backgroundColor.rgb, color.rgb, Texel(fill, transformedUV).a * color.a);
      // multiplying here with backgroundCOlor makes everything transparent....
      // not exactly what I'm after, but better then nothing. (I suppose)
        return vec4(patternMix, Texel(mask, uv).r * backgroundColor.a  );
	}
]])


lib.makeTexturedCanvas = function(lineart, mask, texture1, color1, alpha1, texture2, color2, alpha2, texRot, texScale,
                                  lineColor, lineAlpha,
                                  flipx, flipy, renderPatch)
   if true then
      local lineartColor = lineColor or { 0, 0, 0, 1 }
      local lw, lh = lineart:getDimensions()
      local canvas = love.graphics.newCanvas(lw, lh)

      love.graphics.setCanvas({ canvas, stencil = false }) --<<<
      --

      -- the reason for outline ghost stuff is this color
      -- its not a simple fix, you could make it so we use color A if some layer is lpha 0 etc
      love.graphics.clear(lineartColor[1], lineartColor[2], lineartColor[3], 0) ---<<<<


      love.graphics.setShader(maskShader)
      local transform = love.math.newTransform()
      transform:rotate((texRot * math.pi) / 8)
      transform:scale(texScale, texScale)
      local m1, m2, _, _, m5, m6 = transform:getMatrix()

      maskShader:send('fill', texture2)
      maskShader:send('backgroundColor', { color1[1], color1[2], color1[3], alpha1 / 5 })
      maskShader:send('uvTransform', { { m1, m2 }, { m5, m6 } })
      if mask then
         local sx, sy, ox, oy = getDrawParams(flipx, flipy, lw, lh)
         love.graphics.setColor(color2[1], color2[2], color2[3], alpha2 / 5)
         love.graphics.draw(mask, 0, 0, 0, sx, sy, ox, oy)
      end
      love.graphics.setShader()


      local shrinkFactor = 4

      -- I want to know If we do this or not..
      if (renderPatch) then
         love.graphics.setColorMask(true, true, true, false)
         for i = 1, #renderPatch do
            local p = renderPatch[i]

            love.graphics.setColor(1, 1, 1, 1)
            local image = love.graphics.newImage(p.imageData)
            local imgw, imgh = image:getDimensions();
            local xOffset = p.tx * (imgw / 6) * shrinkFactor
            local yOffset = p.ty * (imgh / 6) * shrinkFactor
            love.graphics.draw(image, (lw) / 2 + xOffset, (lh) / 2 + yOffset, p.r * ((math.pi * 2) / 16),
                p.sx * shrinkFactor,
                p.sy * shrinkFactor,
                imgw / 2, imgh / 2)
            --print(lw, lh)
            if false then
               --local img = love.graphics.newImage('assets/parts/eye4.png')
               -- local img = love.graphics.newImage('assets/test1.png')
               --love.graphics.setBlendMode('subtract')

               for i = 1, 100 do
                  love.graphics.setColor(love.math.random(), love.math.random(), love.math.random(), 0.4)
                  local s = love.math.random() * 3
                  love.graphics.draw(img, lw * love.math.random(), lh * love.math.random(),
                      love.math.random() * math.pi * 2,
                      s)
               end

               --love.graphics.setBlendMode("alpha")
            end
         end
         love.graphics.setColorMask(true, true, true, true)
      end


      love.graphics.setColor(lineartColor[1], lineartColor[2], lineartColor[3], lineAlpha / 5)
      local sx, sy, ox, oy = getDrawParams(flipx, flipy, lw, lh)
      love.graphics.draw(lineart, 0, 0, 0, sx, sy, ox, oy)

      love.graphics.setColor(0, 0, 0) --- huh?!
      love.graphics.setCanvas() --- <<<<<

      -- how to smooch the canvas ?

      --return result
      -- smooche is slow!!!!
      --local imageData = smoocheCanvas(canvas) --





      local otherCanvas = love.graphics.newCanvas(lw / shrinkFactor, lh / shrinkFactor)
      love.graphics.setCanvas({ otherCanvas, stencil = false }) --<<<
      love.graphics.clear(lineartColor[1], lineartColor[2], lineartColor[3], 0) ---<<<<
      love.graphics.setColor(1, 1, 1) --- huh?!
      love.graphics.draw(canvas, 0, 0, 0, 1 / shrinkFactor, 1 / shrinkFactor)
      love.graphics.setCanvas() --- <<<<<
      local imageData = otherCanvas:newImageData()
      love.graphics.setColor(0, 0, 0) --- huh?!
      --local imageData = canvas:newImageData()



      canvas:release()
      otherCanvas:release()
      return imageData
   end
   -- return lineart:getData()
   -- return nil -- love.image.newImageData(mask)
end



return lib;

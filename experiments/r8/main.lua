local ffi = require("ffi")


local shrinkFactor = 3.3
function love.load()
   local url = 'pupil11.png'
   defaultImage = love.graphics.newImage(url)
   r8Image = makeR8Image(url)


   ear1 = love.graphics.newImage('earx1.png')
   ear1mask = love.graphics.newImage('earx1-maskT2.png')
   r8Maks = makeR8Image('earx1-maskT2.png')
   

   
   --  ear1mask = makeR8Image('earx1-mask.png')

   tex1 =  love.graphics.newImage('texture-type0.png')
   tex2 =  love.graphics.newImage('texture-type1.png')
   canvas =  love.graphics.newImage( makeTexturedCanvas(ear1, ear1mask, nil, {1,1,1}, 5, tex2, {0,0,1}, 5, 0, 1,
                                                        {1,0,0}, 5,
                                                        1, 1, nil))

   --(maskTex, bgColor, bgAlpha, fgTex, fgColor, fgAlpha, patternRotation, patternScale, flipx, flipy, renderPatch
   canvas2 = combineMaskAndPattern(ear1mask, {1,1,1}, 5, tex2, {0,0,1}, 5, 0, 1,1, 1, nil)
   canvas3 = love.graphics.newImage(canvas2)
   
end


function love.draw()
   love.graphics.clear(1,0,1)
   love.graphics.setColor(1,1,1)
   if defaultImage then 
   --   love.graphics.draw(defaultImage)
   end
   if (canvas2) then
      love.graphics.setColor(1-love.math.random()*0.2, 1-love.math.random()*0.5, 1-love.math.random()*0.5)
      
       love.graphics.draw(canvas3, 0,0,0,shrinkFactor, shrinkFactor)
       love.graphics.setColor(0+love.math.random(), 0, 0)
           love.graphics.draw(ear1, 0)
     -- love.graphics.draw(r8Image, r8Image:getWidth())
   end
   if (canvas) then
   --   love.graphics.draw(canvas, canvas:getWidth()*2)
   end
   --print(love.graphics.getStats().texturememory)
end

function love.keypressed(key)
   if (key == 'escape') then love.event.quit() end
end


local function getDrawParams(flipx, flipy, imgw, imgh)
   local sx = flipx
   local sy = flipy

   local ox = flipx == -1 and imgw or 0
   local oy = flipy == -1 and imgh or 0

   return sx, sy, ox, oy
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
// CHANGED here  Texel(mask, uv).r *  --- >   Texel(mask, uv).a *
   return vec4(patternMix, Texel(mask, uv).a * backgroundColor.a  );
}
]])


local params = {
   
}

-- this function will be given a mask image, and a pattern image and will combine them.
-- dont fuss about outlines we will do that somewhere else.
combineMaskAndPattern = function(maskTex, bgColor, bgAlpha, fgTex, fgColor, fgAlpha, patternRotation, patternScale, flipx, flipy, renderPatch)
   local lw, lh = maskTex:getDimensions()
   local canvas = love.graphics.newCanvas(lw, lh, { dpiscale = 1 })
   love.graphics.setCanvas({ canvas, stencil = false }) --<<<

   love.graphics.clear(bgColor[1], bgColor[2], bgColor[3], 0) ---<<<<

   love.graphics.setShader(maskShader)
   local transform = love.math.newTransform()
   transform:rotate((patternRotation * math.pi) / 8)
   transform:scale(patternScale, patternScale)
   local m1, m2, _, _, m5, m6 = transform:getMatrix()
   maskShader:send('fill', fgTex)
   maskShader:send('backgroundColor', { bgColor[1], bgColor[2], bgColor[3], bgAlpha / 5 })
   maskShader:send('uvTransform', { { m1, m2 }, { m5, m6 } })


   if maskTex then
     -- print(flipx, flipy)
      local sx, sy, ox, oy = getDrawParams(flipx, flipy, lw, lh)
      love.graphics.setColor(fgColor[1], fgColor[2], fgColor[3], fgAlpha / 5)
      print(fgColor[1], fgColor[2], fgColor[3], fgAlpha / 5)
      love.graphics.draw(maskTex, 0, 0, 0, sx, sy, ox, oy)
   end
   love.graphics.setShader()
   
   love.graphics.setCanvas() --- <<<<<


    local otherCanvas = love.graphics.newCanvas(lw / shrinkFactor, lh / shrinkFactor)
    love.graphics.setCanvas({ otherCanvas, stencil = false }) --<<<

      love.graphics.clear(bgColor[1], bgColor[2], bgColor[3], 0) ---<<<<
      love.graphics.setColor(1, 1, 1) --- huh?!
      love.graphics.draw(canvas, 0, 0, 0, 1 / shrinkFactor, 1 / shrinkFactor)
      love.graphics.setCanvas() --- <<<<<
      local imageData = otherCanvas:newImageData()


   
   return imageData
end


makeTexturedCanvas = function(lineart, mask, texture1, color1, alpha1, texture2, color2, alpha2, texRot, texScale,
                              lineColor, lineAlpha,
                              flipx, flipy, renderPatch)
   if true then
      local lineartColor = lineColor or { 0, 0, 0, 1 }
      local lw, lh = lineart:getDimensions()
      --  local dpiScale = 1 --love.graphics.getDPIScale()
      local canvas = love.graphics.newCanvas(lw, lh, { dpiscale = 1 })

      love.graphics.setCanvas({ canvas, stencil = false }) --<<<
      --

      -- the reason for outline ghost stuff is this color
      -- its not a simple fix, you could make it so we use color A if some layer is lpha 0 etc
      love.graphics.clear(lineartColor[1], lineartColor[2], lineartColor[3], 0) ---<<<<
      love.graphics.clear(color1[1], color1[2], color1[3], 0) ---<<<<



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


      
      local sx, sy, ox, oy = getDrawParams(flipx, flipy, lw, lh)
      love.graphics.setColor(lineartColor[1], lineartColor[2], lineartColor[3], lineAlpha / 5)
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
      love.graphics.clear(color1[1], color1[2], color1[3], 0) ---<<<<
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


function makeR8Image(url)
   local imageData     = love.image.newImageData(url)
   local width, height = imageData:getDimensions()



   
   
   local components = 1
   local mem = love.data.newByteData(width * height * components )
   local pointer    = ffi.cast("uint8_t*", imageData:getFFIPointer()) -- imageData has one byte per channel per pixel.
   local uint8array = ffi.cast('uint8_t*', mem:getFFIPointer()) 



   
   -- faster!
   if true then
      local startTime = love.timer.getTime()
      local pixelCount = width * height
      for i = 0, 4*pixelCount-1, 4 do -- Loop through the pixels, four values at a time (RGBA).
         local a =  255-pointer[i+3] 
         uint8array[math.floor(i/4)] = a * 255
      end

      local time1 = love.timer.getTime() - startTime
      print('pointer into imageData', time1)

   end

   -- slower
   if true then
      local startTime = love.timer.getTime()
      for y = 0, height-1  do
         for x = 0, width-1 do
            local r, g, b, a = imageData:getPixel(x, y)
            
            local index = y * width + x
            uint8array[index + 0] = a * 255
         end
      end
      local time1 = love.timer.getTime() - startTime
      print('getPixel', time1)
   end
   
   local imageData = love.image.newImageData( width, height, 'r8', mem )
   return  love.graphics.newImage( imageData )
   
end


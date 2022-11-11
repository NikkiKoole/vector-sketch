local scene = {}

local vivid = require 'vendor.vivid'
local Timer = require 'vendor.timer'
local inspect = require 'vendor.inspect'

local numbers = require 'lib.numbers'
local creamColor = {238/255, 226/255, 188/255, 1}

local ui = require 'lib.ui'
-- https://medium.com/@chrisgaul/https-medium-com-chrisgaul-is-this-language-without-letters-the-future-of-global-communication-15fc54909c12
-- http://bamanda.com/locos/locos_subsite/locos_gallery.html
function scene.load()
   
   bgColor = creamColor

   Timer.after(
      1,
      function()
         Timer.during(
            .3,
            function(dt)
               local h,s,l,a = vivid.RGBtoHSL(bgColor) 
               l = l*0.99
               local r,g,b,a = vivid.HSLtoRGB(h,s,l,a)
               bgColor = {r,g,b,a}
            end
         )
      end
   )

   mask = love.graphics.newImage("assets/layered/romp1-mask.png")
   lineart = love.graphics.newImage('assets/layered/romp1.png')
   grunge = love.graphics.newImage('assets/layered/ice.jpg')
   --grunge = love.graphics.newImage('assets/layered/fur2.jpg')
   texture1 = love.graphics.newImage('assets/layered/texture-type1.png')
   blup1 = love.graphics.newImage('assets/blup1.png')
   m = 0
   tx = 0
   ty = 0
   local lw, lh = lineart:getDimensions()

   canvas = love.graphics.newCanvas(lw, lh)


   palettes = {
      { 0.18, 0.176, 0.18, 1 },
      { 0.447, 0.255, 0.043, 1 },
      { 0.882, 0.753, 0.133, 1 },
      { 0.929, 0.91, 0.835, 1 },
      { 0.467, 0.498, 0.176, 1 },
      { 0.137, 0.333, 0.502, 1 },
      { 0.396, 0.604, 0.698, 1 },
      { 0.475, 0.408, 0.439, 1 },
      { 0.561, 0.247, 0.443, 1 },
      { 0.89, 0.388, 0.294, 1 },
      { 0.941, 0.518, 0.122, 1 }
   }
   
   

   
   
   skinFurHSL = {vivid.RGBtoHSL(238/255,173/255,25/255)}
   skinBackHSL = {vivid.RGBtoHSL(154/255, 65/255,22/255)}

   --skinFurHSL = {vivid.RGBtoHSL( 0.89, 0.388, 0.294)}
   
   --print(inspect(skinBackHSL))
   --redB = 154/255
   delta = 0
end

function scene.update(dt)
   if introSound:isPlaying() then
      local volume = introSound:getVolume()
      introSound:setVolume(volume * .90)
      if (volume < 0) then
	 introSound:stop()
      end
   end
   function love.keypressed(key, unicode)
      if key == 'escape' then love.event.quit() end
      
   end

   function love.touchpressed(key, unicode)

   end

   function love.mousepressed(key, unicode)

   end
   function love.mousemoved(x,y,dx,dy)
      print('yoyo')
      if love.mouse.isDown(1) then
	 tx = tx + dx
	 ty = ty + dy
      end
      
   end
   delta = delta + dt
   Timer.update(dt)
end

local mask_effect = love.graphics.newShader[[
   vec4 effect (vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
      if (Texel(texture, texture_coords).rgb == vec3(0.0)) {
         // a discarded pixel wont be applied as the stencil.
         discard;
      }
      return vec4(1.0);
   }
]]
function myStencilFunction()
   love.graphics.setShader(mask_effect)
   love.graphics.draw(mask, 0, 0)
   love.graphics.setShader()
end


local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
--local b='ABCDEF'
-- encoding
function enc(data)
   return ((data:gsub('.', function(x) 
			 local r,b='',x:byte()
			 for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
			 return r;
		     end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
					   if (#x < 6) then return '' end
					   local c=0
					   for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
					   return b:sub(c+1,c+1)
				       end)..({ '', '==', '=' })[#data%3+1])
end

-- decoding
function dec(data)
   data = string.gsub(data, '[^'..b..'=]', '')
   return (data:gsub('.', function(x)
			if (x == '=') then return '' end
			local r,f='',(b:find(x)-1)
			for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
			return r;
		    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
				 if (#x ~= 8) then return '' end
				 local c=0
				 for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
				 return string.char(c)
   end))
end

function love.mousereleased()
   lastDraggedElement = nil
end




function calculateLargestRect(angle, origWidth, origHeight) 
   local w0, h0;
   if (origWidth <= origHeight) then
      w0 = origWidth;
      h0 = origHeight;
      
   else 
      w0 = origHeight;
      h0 = origWidth;
   end
   
   --// Angle normalization in range [-PI..PI)
   local ang = angle - math.floor((angle + math.pi) / (2*math.pi)) * 2*math.pi; 
   ang = math.abs(ang);      
   if (ang > math.pi / 2) then
      ang = math.pi - ang
   end
   
   local sina = math.sin(ang);
   local cosa = math.cos(ang);
   local sinAcosA = sina * cosa;
   local w1 = w0 * cosa + h0 * sina;
   local h1 = w0 * sina + h0 * cosa;
   local c = h0 * sinAcosA / (2 * h0 * sinAcosA + w0);
   local x = w1 * c;
   local y = h1 * c;
   local w, h;
   if (origWidth <= origHeight) then
      w = w1 - 2 * x;
      h = h1 - 2 * y;
      
   else 
      w = h1 - 2 * y;
      h = w1 - 2 * x;
   end

   return x,y,w,h
end

function scene.draw()
   love.graphics.push()
   --love.graphics.scale(1,1)
   --love.graphics.translate(tx,ty)
   ui.handleMouseClickStart()
   love.graphics.clear(bgColor)
   love.graphics.setColor(0,0,0)
   love.graphics.print("Let's create the layered furry skin thing", 400,10)

   local lw, lh = lineart:getDimensions()
   --print(lw, lh)

   --canvas = love.graphics.newCanvas(lw, lh)  
   love.graphics.setCanvas({canvas,   stencil = true })  --<<<
   love.graphics.clear(0, 0, 0, 0)  ---<<<<
   love.graphics.setBlendMode("alpha") ---<<<< 
   local ow, oh = grunge:getDimensions()
   local gw, gh = grunge:getDimensions()
   local rotation = delta
   local rx, ry, rw, rh = calculateLargestRect(rotation, gw,gh)

   --gw = rw
   --gh = rh
   
   if not love.mouse.isDown(1) then
      m = love.math.random()
   end

   local scaleX = 1
   local scaleY = 1 

   love.graphics.setColor(1,1,1)
   
   love.graphics.setColor({vivid.HSLtoRGB(skinBackHSL)})
   
   
   -- love.graphics.setStencilTest("greater", 0)
   --love.graphics.stencil(myStencilFunction)


   local xMin = lw+ -((gw/2) *  scaleX) + (rx*scaleX)
   local xMax = (gw/2)*scaleX - (ry*scaleX)
   local xOffset = xMin  

   local yMin = lh+ -((gh/2) *  scaleY) + (rx * scaleY)
   local yMax =  (gh/2)*scaleY - (ry*scaleY)
   local yOffset = yMin
   
   print('offsets', xOffset, yOffset)
   

   
   love.graphics.draw(grunge, xOffset, yOffset, rotation, scaleX, scaleY, gw/2, gh/2)

   local tw, th = texture1:getDimensions()
   local maxT1Width = tw - lw
   local maxT1Height = th - lh
   -- height of these images is not big enough, redraw them bigger lazy bum

   love.graphics.setColor(0,0,0)
   love.graphics.setColor({vivid.HSLtoRGB(skinFurHSL)})

   --

   

   
   --love.graphics.draw(texture1, m*-maxT1Width,0,0,1.5,1.5)
   love.graphics.setStencilTest()

   
   love.graphics.setCanvas()  --- <<<<<

   -- woohoo!
   love.graphics.setColor(1,0,1)
   love.graphics.draw(canvas)

   -- temp
   love.graphics.setColor(1,1,1,.5)
   love.graphics.draw(grunge, xOffset, yOffset, rotation, scaleX, scaleY, gw/2, gh/2)
   
   love.graphics.setColor({vivid.HSLtoRGB(skinFurHSL)})
   -- love.graphics.draw(lineart)
   local stats = love.graphics.getStats()
   print('img mem', stats.texturememory)
   print('Memory actually used (in kB): ' .. collectgarbage('count'))

   --love.graphics.print('hose length: ' .. (redB), 30, 30 - 20)
   local slider = h_slider('skin hue', 30, 30, 200, skinBackHSL[1], 0, 1)
   if slider.value ~= nil then
      skinBackHSL[1] = slider.value
   end
   local slider = h_slider('skin sat', 30, 70, 200, skinBackHSL[2], 0, 1)
   if slider.value ~= nil then
      skinBackHSL[2] = math.floor((slider.value)*3) / 3
   end
   local slider = h_slider('skin light', 30, 100, 200, skinBackHSL[3], 0, 1)
   if slider.value ~= nil then

      skinBackHSL[3] = math.floor((slider.value)*7) / 7
   end

   local slider = h_slider('fur hue', 330, 30, 200, skinFurHSL[1], 0, 1)
   if slider.value ~= nil then
      skinFurHSL[1] = slider.value
   end
   local slider = h_slider('fur sat', 330, 70, 200, skinFurHSL[2], 0, 1)
   if slider.value ~= nil then
      skinFurHSL[2] =math.floor((slider.value)*3) / 3
   end
   local slider = h_slider('fur light', 330, 100, 200, skinFurHSL[3], 0, 1)
   if slider.value ~= nil then
      skinFurHSL[3] = math.floor((slider.value)*7) / 7
   end

   for i =1, #palettes do
      love.graphics.setColor(palettes[i])   
      love.graphics.draw(blup1, i*50, 400, 0, .1, .1)
   end
   
   --local encoded = (enc('122445678905102202'))
   --print(encoded, dec(encoded))
   
   -- go and implement it on a canvas
   -- https://love2d.org/wiki/Canvas
   love.graphics.pop() 
end

return scene

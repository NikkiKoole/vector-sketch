local scene = {}

local vivid = require 'vendor.vivid'
local Timer = require 'vendor.timer'
local inspect = require 'vendor.inspect'

local numbers = require 'lib.numbers'
local creamColor = {238/255, 226/255, 188/255, 1}

local ui = require 'lib.ui'


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
   --grunge = love.graphics.newImage('assets/layered/grunge kopie.png')
   grunge = love.graphics.newImage('assets/layered/fur2.jpg')
   texture1 = love.graphics.newImage('assets/layered/texture-type1.png')
   m = 0
    local lw, lh = lineart:getDimensions()

    canvas = love.graphics.newCanvas(lw, lh)


    
    skinFurHSL = {vivid.RGBtoHSL(238/255,173/255,25/255)}
    skinBackHSL = {vivid.RGBtoHSL(154/255, 65/255,22/255)}
    
    --print(inspect(skinBackHSL))
    --redB = 154/255
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


function scene.draw()

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
   
   local gw, gh = grunge:getDimensions()
   --print(gw, gh)

   local maxGrungeWidth = gw - lw
   local maxGrungeHeight = gh - lh
   
   love.graphics.setColor(1,1,1)
   
   love.graphics.setColor({vivid.HSLtoRGB(skinBackHSL)})

   love.graphics.setStencilTest("greater", 0)
   love.graphics.stencil(myStencilFunction)

   if not love.mouse.isDown(1) then
      m = love.math.random()
   end
   
   love.graphics.draw(grunge, m*-maxGrungeWidth, m*-maxGrungeHeight)

   local tw, th = texture1:getDimensions()
   local maxT1Width = tw - lw
   local maxT1Height = th - lh
   -- height of these images is not big enough, redraw them bigger lazy bum

   love.graphics.setColor(0,0,0)
   love.graphics.setColor({vivid.HSLtoRGB(skinFurHSL)})

   --
   love.graphics.draw(texture1, m*-maxT1Width,0,0,1.5,1.5)
   love.graphics.setStencilTest()

   
   love.graphics.setCanvas()  --- <<<<<

   -- woohoo!
   love.graphics.setColor(1,1,1)
   love.graphics.draw(canvas)
   
   love.graphics.setColor({vivid.HSLtoRGB(skinFurHSL)})
   love.graphics.draw(lineart)
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

   
   
   --local encoded = (enc('122445678905102202'))
   --print(encoded, dec(encoded))
   
   -- go and implement it on a canvas
   -- https://love2d.org/wiki/Canvas
end

return scene

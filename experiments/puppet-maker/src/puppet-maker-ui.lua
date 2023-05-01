-- this is the panel that contains all ui for changing a certain body part or general change
-- for each category we have a optionally unique panel

local hit = require "lib.hit"
local canvas = require "lib.canvas"
local mesh = require "lib.mesh"
local ui = require "lib.ui"
local transforms = require "lib.transform"
local text = require 'lib.text'
local numbers = require 'lib.numbers'

imageCache = {} -- tjo save all the parts inages in


local pink = { 201 / 255, 135 / 255, 155 / 255 }
local yellow = { 239 / 255, 219 / 255, 145 / 255 }
local green = { 192 / 255, 212 / 255, 171 / 255 }
local colors = { pink, yellow, green }
local tabs = { "part", "colors", "pattern" }

local playingSound = nil

local function getPNGMaskUrl(url)
   return text.replace(url, '.png', '-mask.png')
end

function growl(pitch)
   local index = math.ceil(love.math.random()*#hum) 
      local sndLength = hum[math.ceil(index)]:getDuration() / pitch
      playingSound = playSound(hum[math.ceil(index)], pitch)
    
      myWorld:emit('mouthSaySomething', mouth, sndLength)
end


function createFittingScale(img, desired_w, desired_h)
   local w, h = img:getDimensions()
   local sx, sy = desired_w / w, desired_h / h
   --   print(sx, sy)
   return sx, sy
end

local function getScaleAndOffsetsForImage(img, desiredW, desiredH)
   local sx, sy = createFittingScale(img, desiredW, desiredH)
   local scale = math.min(sx, sy)
   local xOffset = 0
   local yOffset = 0
   if scale == sx then
      xOffset = -desiredW / 2 -- half the height
      local something = sx * img:getHeight()
      local something2 = sy * img:getHeight()
      yOffset = -desiredH / 2 - (something - something2) / 2
   elseif scale == sy then
      --print('y')
      yOffset = -desiredH / 2 -- half the height
      local something = sx * img:getWidth()
      local something2 = sy * img:getWidth()
      xOffset = -desiredW / 2 + (something - something2) / 2
   end
   return scale, xOffset, yOffset
end

-- this function will be a called from draw
function partSettingsPanel()
   partSettingsSurroundings(true)
   partSettingsScrollable(true)
end

function partSettingsPanelDimensions()
   -- thise returns the basic dimensions valeus of the panel (x,y,w,h)
   local w, h = love.graphics.getDimensions()
   local margin = (h / 16) -- margin around panel
   local width = (w / 3) -- width of panel
   local height = (h - margin * 2) -- height of panel
   local beginX = 0
   local beginY = 0
   local startX = beginX + w - width - margin
   local startY = beginY + margin

   return startX, startY, width, height
end

function partSettingsTabsDimensions(tabs, width)
   local tabWidth = (width / #tabs)
   local tabHeight = math.max((tabWidth / 2.5), 32)
   local marginBetweenTabs = tabWidth / 16

   return tabWidth, tabHeight, marginBetweenTabs
end

function drawTapesForBackground(x, y, w, h)
   local index = 2

   -- if h > 100 then index = 2 end
   local imgw, imgh = uiheaders[index]:getDimensions()
   local sx, sy = createFittingScale(uiheaders[index], w, h)
   love.graphics.setColor(1, 1, 1, .4)
   --love.graphics.draw(uiheaders[index], x, y + h / 2, 0, sx, sy * -1, 0, imgh / 2)
   love.graphics.draw(uiheaders[index], x, y, 0, sx, sy, 0, 0)
end

function newtoggle(id, img, x, y, w, toggled)
   local togw, togh = img:getDimensions()
   local s = (w) / togw
   local h = toggled and s or -s

   love.graphics.draw(img, x + (togw / 2) * s, y, 0, h, s, togw / 2, 0)
   -- i retun a differnt hitarea depending on the toggled state
   local h = nil
   h = ui.getUIRect(id, x, y, (togw) * s, togh * s)

   if false then
      if not toggled then
         h = ui.getUIRect(id, x, y, (togw / 2) * s, togh * s)
      else
         h = ui.getUIRect(id, x + (togw / 2) * s, y, (togw / 2) * s, togh * s)
      end
   end
   --print(toggled)
   return h
end

function toggle2(id, trackimg, thumbimg, x, y, w, toggled)

end

function changeValue(name, step, min, max)
   local values = editingGuy.values
   local splitted = text.stringSplit(name, '.')
   if #splitted == 1 then
      values[name] = values[name] + step
      local m = math.ceil(1 / math.abs(step))
      values[name] = math.floor(values[name] * m) / m
      values[name] = math.max(values[name], min)
      values[name] = math.min(values[name], max)
   end
   if #splitted == 2 then
      local cat = splitted[1]
      local prop = splitted[2]
      values[cat][prop] = values[cat][prop] + step
      local m = math.ceil(1 / math.abs(step))
      values[cat][prop] = math.floor(values[cat][prop] * m) / m
      values[cat][prop] = math.max(values[cat][prop], min)
      values[cat][prop] = math.min(values[cat][prop], max)
   end
end

function getValueMaybeNested(prop)
   local values = editingGuy.values
   local splitted = text.stringSplit(prop, '.')
   if #splitted == 1 then
      return values[prop]
   end
   if #splitted == 2 then
      return values[splitted[1]][splitted[2]]
   end
end

function setValueMaybeNested(prop, v)
   local values = editingGuy.values
   local splitted = text.stringSplit(prop, '.')
   if #splitted == 1 then
      values[prop] = v
   end
   if #splitted == 2 then
      values[splitted[1]][splitted[2]] = v
   end
end

function draw_slider_with_2_buttons(prop, startX, currentY, buttonSize, sliderWidth, propupdate, update,
                                    valmin, valmax, valstep, img1, img2)
   local values = editingGuy.values
   local sx, sy = createFittingScale(rects[1], buttonSize, buttonSize)
   love.graphics.setColor(0, 0, 0, .1)
   love.graphics.draw(rects[1], startX, currentY, 0, sx, sy)
   if img1 then
      love.graphics.setColor(0, 0, 0, 1)
      local imgsx, imgsy = createFittingScale(img1, buttonSize, buttonSize)
      love.graphics.draw(img1, startX, currentY, 0, imgsx, imgsy)
   end
   local less = ui.getUIRect('less-' .. prop, startX, currentY, buttonSize, buttonSize)
   if less then
      changeValue(prop, -valstep, valmin, valmax)
      propupdate(getValueMaybeNested(prop))
      if update then update() end
      print('shrinkng')

      local value = getValueMaybeNested(prop)
      local pitch = numbers.mapInto(value, valmin, valmax, 1, 3)
      growl(pitch)
      
   end

   local sx, sy = createFittingScale(rects[1], buttonSize, buttonSize)
   love.graphics.setColor(0, 0, 0, .1)
   love.graphics.draw(rects[1], startX + buttonSize + sliderWidth, currentY, 0, sx, sy)
   if img2 then
      love.graphics.setColor(0, 0, 0, 1)
      local imgsx, imgsy = createFittingScale(img2, buttonSize, buttonSize)
      love.graphics.draw(img2, startX + buttonSize + sliderWidth, currentY, 0, imgsx, imgsy)
   end
   local more = ui.getUIRect('more-' .. prop, startX + buttonSize + sliderWidth, currentY, buttonSize,
           buttonSize)
   if more then
      changeValue(prop, valstep, valmin, valmax)
      propupdate(getValueMaybeNested(prop))
      if update then update() end
      print('growing')

      local value = getValueMaybeNested(prop)
      local pitch = numbers.mapInto(value, valmin, valmax, 1, 3)
        growl(pitch)
    
   end

   local v = h_slider_textured("slider-" .. prop, startX + buttonSize, currentY + (buttonSize / 4), sliderWidth,
           sliderimg.track2,
           sliderimg.thumb3,
           nil, getValueMaybeNested(prop), valmin, valmax)
   if v.value then
      local m = math.ceil(1 / math.abs(valstep))
      v.value = math.floor(v.value * m) / m -- round to .5
      if (v.value > getValueMaybeNested(prop)) then
         print('growing')
      else
         print('shrinkng')
      end
      local changed = (v.value ~= getValueMaybeNested(prop))
      print(v.value, getValueMaybeNested(prop))
      --values[prop] = v.value
      setValueMaybeNested(prop, v.value)
      propupdate(getValueMaybeNested(prop))
      if (changed) then

      if playingSound then playingSound:stop() end
      growl(1+love.math.random()*2)
      
      end
      if update then update() end
   end
end

function draw_toggle_with_2_buttons(prop, startX, currentY, buttonSize, sliderWidth, toggleValue, toggleFunc, img1, img2)
   local sx, sy = createFittingScale(rects[1], buttonSize, buttonSize)

   love.graphics.setColor(0, 0, 0, .1)
   love.graphics.draw(rects[1], startX, currentY, 0, sx, sy)
   if img1 then
      love.graphics.setColor(0, 0, 0, 1)
      -- if toggleValue then
      --    love.graphics.setColor(1, 1, 1, 1)
      -- end
      local imgsx, imgsy = createFittingScale(img1, buttonSize, buttonSize)
      love.graphics.draw(img1, startX, currentY, 0, imgsx, imgsy)
   end
   love.graphics.setColor(0, 0, 0, 1)
   local less = ui.getUIRect('less-' .. prop, startX, currentY, buttonSize, buttonSize)
   if less then
      growl(1+love.math.random()*2)
     
      toggleFunc(false)
   end
   local offset = buttonSize

   local sx, sy = createFittingScale(toggle.body3, sliderWidth, buttonSize)
   local scale = math.min(sx, sy)

   local tbw, tbh = toggle.body3:getDimensions()

   local extraOffset = 0
   if tbw * scale < sliderWidth then
      extraOffset = (sliderWidth - (tbw * scale)) / 2
      offset = offset
   end
   local yOff = (buttonSize - (tbh * scale)) / 2
   local yOffThumb = (scale * toggle.thumb3:getHeight() / 2)
   love.graphics.draw(toggle.body3, offset + extraOffset + startX, yOff + currentY, 0, scale, scale)
   if toggleValue then
      love.graphics.draw(toggle.thumb3, offset + extraOffset + startX + (15 * scale),
          yOff + currentY + yOffThumb,
          0,
          scale,
          scale)
   else
      love.graphics.draw(toggle.thumb3,
          offset + extraOffset + startX + -(15 * scale) +
          (((tbw * scale)) - (toggle.thumb3:getWidth() * scale)),
          yOff + currentY + yOffThumb,
          0,
          scale,
          scale)
   end
   local sx, sy = createFittingScale(rects[1], buttonSize, buttonSize)
   love.graphics.setColor(0, 0, 0, .1)
   love.graphics.draw(rects[1], offset + startX + sliderWidth, currentY, 0, sx, sy)
   if img2 then
      love.graphics.setColor(0, 0, 0, 1)
      -- if not toggleValue then
      --    love.graphics.setColor(1, 1, 1, 1)
      -- end
      local imgsx, imgsy = createFittingScale(img2, buttonSize, buttonSize)
      love.graphics.draw(img2, offset + startX + sliderWidth, currentY, 0, imgsx, imgsy)
   end
   local more = ui.getUIRect('more-' .. prop, offset + startX + sliderWidth, currentY,
           buttonSize, buttonSize)
   if more then
      growl(1+love.math.random()*2)
 
      toggleFunc(true)
   end
   local w, h = toggle.body3:getDimensions()
   local t = ui.getUIRect('t-' .. prop, offset + startX, yOff + currentY, w * scale, h * scale)
   if t then
      growl(1+love.math.random()*2)
   
      toggleFunc(toggleValue)
   end
end

function drawImmediateSlidersEtc(draw, startX, currentY, width)
   local values = editingGuy.values
   local currentHeight = 20

   -- if small then buttonSize == 24
   -- if big then double (48)
   --   print(width)
   local buttonSize = width < 320 and 24 or 48

   width = width - buttonSize
   local columnsCells = (math.ceil(width / buttonSize))
   local sliderWidth = (width / math.ceil((columnsCells / 6))) - (buttonSize * 2)

   local elementWidth = (sliderWidth + (buttonSize * 2))
   local elementsInRow = width / elementWidth
   local runningElem = 0
   width = width + buttonSize
   startX = startX + buttonSize / 2

   function updateRowStuff()
      runningElem = runningElem + 1
      if runningElem >= elementsInRow then
         runningElem = 0
         currentY = currentY + buttonSize
      end
      return runningElem, currentY
   end

   function calcCurrentHeight(itemsHere)
      local rowsInUse = math.ceil(itemsHere / elementsInRow)
      return rowsInUse * (buttonSize)
   end

   if selectedTab == 'part' then
      if selectedCategory == 'body' then
         -- we have 5 ui elements, how many will fit on 1 row ?
         local update = function()
            editingGuy.body.dirty = true
            transforms.setTransforms(editingGuy.body)
            if values.potatoHead then
               myWorld:emit('rescaleFaceparts', potato)
            end
            changePart('body', values)

            myWorld:emit('potatoInit', potato)
            myWorld:emit("bipedAttachHead", biped)
            myWorld:emit("bipedAttachLegs", biped)
            myWorld:emit("bipedAttachArms", biped)
            myWorld:emit("bipedAttachHands", biped)
         end

         currentHeight = calcCurrentHeight(5)

         if draw then
            drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

            local propupdate = function(v)
               editingGuy.body.transforms.l[4] = v
            end
            runningElem = 0

            draw_slider_with_2_buttons('bodyWidthMultiplier', startX + (runningElem * elementWidth), currentY, buttonSize,
                sliderWidth, propupdate,
                update, .5, 3, .5, icons.bodynarrow, icons.bodywide)

            runningElem, currentY = updateRowStuff()


            local propupdate = function(v)
               editingGuy.body.transforms.l[5] = v
            end

            draw_slider_with_2_buttons('bodyHeightMultiplier', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                update, .5, 3, .5, icons.bodysmall, icons.bodytall)

            runningElem, currentY = updateRowStuff()


            local f = function(v)
               values.body.flipy = v and -1 or 1
               update()
            end
            draw_toggle_with_2_buttons('bodyflipy', startX + (runningElem * elementWidth), currentY, buttonSize,
                sliderWidth, (values.body.flipy == 1),
                f, icons.bodyflipv1, icons.bodyflipv2)
            runningElem, currentY = updateRowStuff()

            local f = function(v)
               values.body.flipx = v and -1 or 1
               update()
            end
            draw_toggle_with_2_buttons('bodyflipx', startX + (runningElem * elementWidth), currentY, buttonSize,
                sliderWidth, (values.body.flipx == 1),
                f, icons.bodyfliph1, icons.bodyfliph2)
            runningElem, currentY = updateRowStuff()

            local f = function(v)
               values.potatoHead = v
               myWorld:emit('bipedUsePotatoHead', biped, values.potatoHead)
               editingGuy.body.transforms.l[4] = values.bodyWidthMultiplier
               editingGuy.body.transforms.l[5] = values.bodyHeightMultiplier

               attachAllFaceParts(editingGuy)
               changePart('head', values)
               changePart('body', values)
               myWorld:emit('rescaleFaceparts', potato)
               setCategories()
               update()
            end
            draw_toggle_with_2_buttons('bipedUsePotatoHead', startX + (runningElem * elementWidth), currentY, buttonSize,
                sliderWidth,
                not (values.potatoHead),
                f, icons.bodynonpotato, icons.bodypotato)
         end
      end

      if selectedCategory == 'upperlip' or selectedCategory == 'lowerlip' then
         currentHeight = calcCurrentHeight(1)

         if draw then
            drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

            local propupdate = function(v)
               values.mouthYAxis = v
               myWorld:emit('potatoInit', potato)
            end
            draw_slider_with_2_buttons('mouthYAxis', startX, currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, -1, 3, .5, icons.mouthup, icons.mouthdown)
         end
      end


      if selectedCategory == 'hair' then
         currentHeight = calcCurrentHeight(2)
         if draw then
            drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

            local propupdate = function(v)
               changePart('hair', values)
            end
            runningElem = 0

            draw_slider_with_2_buttons('hairWidthMultiplier', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, .00001, 2, .25, icons.hairthin, icons.hairthick)

            runningElem, currentY = updateRowStuff()

            draw_slider_with_2_buttons('hairTension', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, .00001, 1, .25, icons.hairtloose, icons.hairthight)

            runningElem, currentY = updateRowStuff()
         end
      end


      if selectedCategory == 'brows' then
         currentHeight = calcCurrentHeight(3)
         if draw then
            drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

            local propupdate = function(v)
               arrangeBrows()
               changePart('brows', values)
            end

            runningElem = 0

            draw_slider_with_2_buttons('browsWidthMultiplier', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, .5, 2, .5, icons.browthin, icons.browthick)

            runningElem, currentY = updateRowStuff()

            draw_slider_with_2_buttons('browsWideMultiplier', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, .5, 2, .5, icons.brownarrow, icons.browwide)

            runningElem, currentY = updateRowStuff()


            draw_slider_with_2_buttons('browsDefaultBend', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, 1, 10, 1, icons.brow1, icons.brow10)

            runningElem, currentY = updateRowStuff()
         end
      end

      if selectedCategory == 'nose' then
         currentHeight = calcCurrentHeight(3)
         if draw then
            drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)
            runningElem = 0

            local propupdate = function(v)
               myWorld:emit('rescaleFaceparts', potato)
               myWorld:emit('potatoInit', potato)
            end

            draw_slider_with_2_buttons('noseWidthMultiplier', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, .5, 3, .5, icons.nosenarrow, icons.nosewide)

            runningElem, currentY = updateRowStuff()

            draw_slider_with_2_buttons('noseHeightMultiplier', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, .5, 3, .5, icons.nosesmall, icons.nosetall)

            runningElem, currentY = updateRowStuff()

            draw_slider_with_2_buttons('noseYAxis', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, -1, 1, .25, icons.noseup, icons.nosedown)
         end
      end



      if selectedCategory == 'pupils' then
         currentHeight = calcCurrentHeight(1)
         if draw then
            drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)
            runningElem = 0

            local propupdate = function(v)
               myWorld:emit('rescaleFaceparts', potato)
            end

            draw_slider_with_2_buttons('pupilSizeMultiplier', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, .125, 2, .125, icons.pupilsmall, icons.pupilbig)
         end
      end


      if selectedCategory == 'eyes' then
         currentHeight = calcCurrentHeight(5)
         if draw then
            runningElem = 0
            drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)
            local propupdate = function(v)
               myWorld:emit('rescaleFaceparts', potato)
               myWorld:emit('potatoInit', potato)
            end

            draw_slider_with_2_buttons('eyeWidthMultiplier', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, .125, 3, .125, icons.eyesmall1, icons.eyewide)

            runningElem, currentY = updateRowStuff()

            draw_slider_with_2_buttons('eyeHeightMultiplier', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, .125, 3, .125, icons.eyesmall2, icons.eyetall)

            runningElem, currentY = updateRowStuff()


            local rotUpdate = function(v)
               editingGuy.eye1.transforms.l[3] = v
               editingGuy.eye2.transforms.l[3] = -v
            end
            draw_slider_with_2_buttons('eyeRotation', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, rotUpdate,
                nil, -.5, .5, .25, icons.eyeccw, icons.eyecw)

            runningElem, currentY = updateRowStuff()

            draw_slider_with_2_buttons('eyeYAxis', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, -3, 3, 1, icons.eyedown, icons.eyeup)

            runningElem, currentY = updateRowStuff()

            draw_slider_with_2_buttons('eyeXAxisBetween', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, -3, 3, 1, icons.eyefar, icons.eyeclose)

            runningElem, currentY = updateRowStuff()
         end
      end

      if selectedCategory == 'ears' then
         currentHeight = calcCurrentHeight(5)
         if draw then
            runningElem = 0
            drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

            local rotupdate = function(v)
               editingGuy.ear1.transforms.l[3] = v
               editingGuy.ear2.transforms.l[3] = -v
            end
            local propupdate = function(v)
               myWorld:emit('rescaleFaceparts', potato)
               myWorld:emit('potatoInit', potato)
            end

            draw_slider_with_2_buttons('earRotation', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, rotupdate,
                nil, -1.5, 1.5, .25, icons.earccw, icons.earcw)

            runningElem, currentY = updateRowStuff()

            draw_slider_with_2_buttons('earWidthMultiplier', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, .5, 3, .5, icons.earsmall, icons.earbig)

            runningElem, currentY = updateRowStuff()

            draw_slider_with_2_buttons('earYAxis', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, -3, 3, 1, icons.earup, icons.eardown)

            runningElem, currentY = updateRowStuff()

            local f = function()
               values.earUnderHead = not values.earUnderHead
               attachAllFaceParts(editingGuy)
               myWorld:emit('rescaleFaceparts', potato)
            end

            draw_toggle_with_2_buttons('earUnderHead', startX + (runningElem * elementWidth), currentY, buttonSize,
                sliderWidth,
                not (values.earUnderHead),
                f, icons.earback, icons.earfront)
         end
      end

      if selectedCategory == 'legs' then
         currentHeight = calcCurrentHeight(5)
         if draw then
            runningElem = 0
            drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

            local propupdate = function(v)
               changePart('legs', values)
               myWorld:emit("bipedAttachLegs", biped)
            end

            draw_slider_with_2_buttons('legXAxis', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, 0, 1, .25, icons.legwide, icons.legnarrow)

            runningElem, currentY = updateRowStuff()

            draw_slider_with_2_buttons('legLength', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, 1, #leglengths, 1, icons.legshort, icons.leglong)

            runningElem, currentY = updateRowStuff()

            draw_slider_with_2_buttons('legWidthMultiplier', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, 0.5, 3, .5, icons.legthin, icons.legthick)

            runningElem, currentY = updateRowStuff()

            draw_slider_with_2_buttons('legDefaultStance', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, 0.25, 1, .25, icons.legstance2, icons.legstance1)

            runningElem, currentY = updateRowStuff()

            local f = function(v)
               print(values.legs.flipy)
               values.legs.flipy = v == false and -1 or 1
               changePart('legs', values)
               --myWorld:emit("bipedAttachLegs", biped)
            end

            draw_toggle_with_2_buttons('legsflipy', startX + (runningElem * elementWidth), currentY, buttonSize,
                sliderWidth,
                (values.legs.flipy == -1),
                f, icons.legflip2, icons.legflip1)
         end
      end

      if selectedCategory == 'arms' then
         currentHeight = calcCurrentHeight(3)
         if draw then
            runningElem = 0
            drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

            local propupdate = function(v)
               changePart('arms', values)
            end

            draw_slider_with_2_buttons('armLength', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, 1, #leglengths, 1, icons.armsshort, icons.armslong)

            runningElem, currentY = updateRowStuff()


            draw_slider_with_2_buttons('armWidthMultiplier', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, 0.5, 3, .5, icons.armsthin, icons.armsthick)

            runningElem, currentY = updateRowStuff()

            local f = function(v)
               values.arms.flipy = v == false and -1 or 1
               changePart('arms', values)
            end

            draw_toggle_with_2_buttons('arms.flipy', startX + (runningElem * elementWidth), currentY, buttonSize,
                sliderWidth,
                (values.arms.flipy == -1),
                f, icons.armsflip1, icons.armsflip2)
         end
      end

      if selectedCategory == 'neck' then
         currentHeight = calcCurrentHeight(2)
         if draw then
            runningElem = 0
            drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

            local propupdate = function(v)
               changePart('neck', values)
            end

            -- todo neck neds to show its change somehow, move the head further if need grows for example....
            draw_slider_with_2_buttons('neckLength', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, 1, #necklengths, 1, icons.neckshort, icons.necklong)

            runningElem, currentY = updateRowStuff()

            draw_slider_with_2_buttons('neckWidthMultiplier', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, 0.5, 3, .5, icons.neckthin, icons.neckthick)
         end
      end

      if selectedCategory == 'hands' then
         currentHeight = calcCurrentHeight(2)
         if draw then
            runningElem = 0
            drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

            local propupdateLength = function(v)
               changePart('hands', values)
               editingGuy.hand1.transforms.l[4] = v
               editingGuy.hand2.transforms.l[4] = -v
            end
            local propupdateWidth = function(v)
               changePart('hands', values)
               editingGuy.hand1.transforms.l[5] = v
               editingGuy.hand2.transforms.l[5] = v
            end

            draw_slider_with_2_buttons('handLengthMultiplier', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdateLength,
                nil, 0.5, 3, .5, icons.handshort, icons.handtall)

            runningElem, currentY = updateRowStuff()

            draw_slider_with_2_buttons('handWidthMultiplier', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdateWidth,
                nil, 0.5, 3, .5, icons.handnarrow, icons.handwide)

            runningElem, currentY = updateRowStuff()
         end
      end

      if selectedCategory == 'feet' then
         currentHeight = calcCurrentHeight(2)
         if draw then
            runningElem = 0
            drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

            local propupdateLength = function(v)
               changePart('feet', values)
               editingGuy.feet1.transforms.l[4] = v
               editingGuy.feet2.transforms.l[4] = -v
            end
            local propupdateWidth = function(v)
               changePart('feet', values)
               editingGuy.feet1.transforms.l[5] = v
               editingGuy.feet2.transforms.l[5] = v
            end


            draw_slider_with_2_buttons('feetLengthMultiplier', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdateLength,
                nil, 0.5, 3, .5, icons.footshort, icons.foottall)
            runningElem, currentY = updateRowStuff()

            draw_slider_with_2_buttons('feetWidthMultiplier', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdateWidth,
                nil, 0.5, 3, .5, icons.footnarrow, icons.footwide)

            runningElem, currentY = updateRowStuff()
         end
      end


      if selectedCategory == 'skinPatchSnout' or selectedCategory == 'skinPatchEye1' or selectedCategory == 'skinPatchEye2' then
         local posts = { 'ScaleX', 'ScaleY', 'Angle', 'X', 'Y' }
         local mins = { .25, .25, 0, -6, -6 }
         local maxs = { 3, 3, 15, 6, 6 }
         local fs = { 4.0, 4.0, 1, 1, 1 }

         currentHeight = calcCurrentHeight(#posts)
         if draw then
            runningElem = 0
            drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

            local propupdate = function(v)
               changePart('head', values)
            end

            for i = 1, #posts do
               local p = posts[i]
               local vv = selectedCategory .. p

               draw_slider_with_2_buttons(vv, startX + (runningElem * elementWidth), currentY,
                   buttonSize,
                   sliderWidth, propupdate,
                   nil, mins[i], maxs[i], 1.0 / fs[i], icons['patch' .. p .. 'less'], icons['patch' .. p .. 'more'])

               runningElem, currentY = updateRowStuff()
            end
         end
      end


      if selectedCategory == 'head' then
         local update = function()
            editingGuy.head.dirty = true
            transforms.setTransforms(editingGuy.head)
            changePart('head', values)
            myWorld:emit("bipedAttachHead", biped)
         end

         currentHeight = calcCurrentHeight(4)

         if draw then
            runningElem = 0
            drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

            local propupdate = function(v)
               changePart('head', values)
               myWorld:emit('rescaleFaceparts', potato)
               update()
            end


            draw_slider_with_2_buttons('headWidthMultiplier', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, 0.5, 3, .5, icons.headnarrow, icons.headwide)

            runningElem, currentY = updateRowStuff()

            draw_slider_with_2_buttons('headHeightMultiplier', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, 0.5, 3, .5, icons.headsmall, icons.headtall)

            runningElem, currentY = updateRowStuff()


            local f = function(v)
               values.head.flipy = v == false and -1 or 1
               update()
            end

            draw_toggle_with_2_buttons('head.flipy', startX + (runningElem * elementWidth), currentY, buttonSize,
                sliderWidth,
                (values.head.flipy == -1),
                f, icons.headflipv1, icons.headflipv2)

            runningElem, currentY = updateRowStuff()

            local f = function(v)
               values.head.flipx = v == false and -1 or 1
               update()
            end

            draw_toggle_with_2_buttons('head.flipx', startX + (runningElem * elementWidth), currentY, buttonSize,
                sliderWidth,
                (values.head.flipx == -1),
                f, icons.headfliph1, icons.headfliph2)
            runningElem, currentY = updateRowStuff()
         end
      end
   end

   if selectedTab == 'pattern' then
      currentHeight = calcCurrentHeight(3)

      if draw then
         drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

         local propupdate = function(v)
            changePart(selectedCategory)
         end
         runningElem = 0

         draw_slider_with_2_buttons(selectedCategory .. '.texScale', startX + (runningElem * elementWidth), currentY,
             buttonSize,
             sliderWidth, propupdate,
             nil, 1, 9, 1, icons.patterncoarse, icons.patternfine)

         runningElem, currentY = updateRowStuff()

         draw_slider_with_2_buttons(selectedCategory .. '.texRot', startX + (runningElem * elementWidth), currentY,
             buttonSize,
             sliderWidth, propupdate,
             nil, 0, 15, 1, icons.patternccw, icons.patterncw)

         runningElem, currentY = updateRowStuff()

         draw_slider_with_2_buttons(selectedCategory .. '.fgAlpha', startX + (runningElem * elementWidth), currentY,
             buttonSize,
             sliderWidth, propupdate,
             nil, 0, 5, 1, icons.patterntransparent, icons.patternopaque)

         runningElem, currentY = updateRowStuff()
      end
   end


   if selectedTab == 'colors' then
      local pickedColors = {
          palettes[values[selectedCategory].bgPal],
          palettes[values[selectedCategory].fgPal],
          palettes[values[selectedCategory].linePal],
      }

      local colorkeys = { 'bgPal', 'fgPal', 'linePal' }

      local amount = #pickedColors

      local buttonWidth = (width / amount) * 0.8
      local originY = currentY
      local originX = startX
      currentY = currentY + 10

      startX = startX + (width / amount) * 0.3
      local rowStartX = startX
      currentHeight = buttonWidth + 10 -- width / 3 --math.max(60, 50 + (buttonWidth / 2))
      if draw then
         --         buttonSize / 2
         drawTapesForBackground(originX, originY, width - (buttonSize / 2), currentHeight)
      end
      for i = 1, 3 do
         --love.graphics.setColor(0, 0, 0)
         --love.graphics.rectangle('line', startX, currentY, buttonWidth, buttonWidth)
         if draw then
            local sx, sy = createFittingScale(colorpickerui[i], buttonWidth, buttonWidth)
            if selectedColoringLayer == colorkeys[i] then
               local offset = math.sin(love.timer.getTime() * 5) * 0.02
               sx = sx * (1.0 + offset)
               sy = sy * (1.0 + offset)
            end
            love.graphics.setColor(0, 0, 0)
            love.graphics.draw(colorpickerui[i], startX, currentY, 0, sx, sy)
            love.graphics.setColor(pickedColors[i])
            love.graphics.draw(colorpickeruimask[i], startX, currentY, 0, sx, sx)
         end
         if ui.getUIRect('r' .. i, startX, currentY, buttonWidth, buttonWidth) then
            selectedColoringLayer = colorkeys[i]
         end
         startX = startX + buttonWidth
      end
   end
   return currentHeight
end

function partSettingsSurroundings(draw, clickX, clickY)
   -- this thing will render the panel where the big scrollable area is in
   -- also the tabs on top and the sliders/other settngs in the header.
   --   basically everything except the scrollable thing itself..

   local startX, startY, width, height = partSettingsPanelDimensions()
   local tabWidth, tabHeight, marginBetweenTabs = partSettingsTabsDimensions(tabs, width)

   local currentY = startY + tabHeight
   local tabWidthMultipliers = { 0.85, 1.05, 1.10 }

   if draw then
      -- main panel

      --love.graphics.setColor(0, 0, 0)
      --love.graphics.rectangle("line", startX, startY, width, height)
      --love.graphics.setColor(255 / 255, 240 / 255, 200 / 255)
      --love.graphics.rectangle("fill", startX, startY, width, height)
      --love.graphics.setColor(0, 0, 0)

      -- instead of getting the imae data I need to use some transaprencey too, ive measured it out the imag
      local iw = 650
      local ih = 1240
      --local iw, ih = tabui[1]:getDimensions()
      --print(iw, ih, width, height)
      local scaleX = width / iw
      local scaleY = height / ih

      local uiOffX = 18 * scaleX
      local uiOffY = 40 * scaleY



      local drawunder = { { 2, 3, 1 }, { 1, 3, 2 }, { 1, 2, 3 } }

      local selectedTabIndex = -1
      for i = 1, #tabs do
         if selectedTab == tabs[i] then
            selectedTabIndex = i
         end
      end

      for i = 1, #drawunder[selectedTabIndex] do
         local index = drawunder[selectedTabIndex][i]
         love.graphics.setColor(colors[index][1], colors[index][2], colors[index][3], 1)
         love.graphics.draw(tabuimask[index], startX - uiOffX, startY - uiOffY, 0, scaleX, scaleY)
         love.graphics.setColor(0, 0, 0)
         love.graphics.draw(tabui[index], startX - uiOffX, startY - uiOffY, 0, scaleX, scaleY)


         if true then
            local w1 = (tabWidth) - marginBetweenTabs
            local h1 = tabHeight

            local x = nil
            if (index == 1) then
               x = startX
            elseif (index == 2) then
               x = startX + tabWidthMultipliers[1] * tabWidth
            elseif (index == 3) then
               x = startX + (tabWidthMultipliers[1] + tabWidthMultipliers[2]) * tabWidth
            end


            local sx, sy = createFittingScale(tabuilogo[index], w1 * 0.9, h1 * 0.9)
            if index == 2 then
               if selectedTabIndex == index then
                  love.graphics.setColor(1, 1, 1, 0.9)
               else
                  love.graphics.setColor(1, 1, 1, 0.3)
               end
            else
               if selectedTabIndex == index then
                  love.graphics.setColor(0, 0, 0, 0.9)
               else
                  love.graphics.setColor(0, 0, 0, 0.3)
               end
            end
            love.graphics.draw(tabuilogo[index], x + w1 * 0.05, startY + h1 * 0.05, 0, sx, sy)
         end
      end
   end


   for i = 1, #tabs do
      local x = nil
      if (i == 1) then
         x = startX
      elseif (i == 2) then
         x = startX + tabWidthMultipliers[1] * tabWidth
      elseif (i == 3) then
         x = startX + (tabWidthMultipliers[1] + tabWidthMultipliers[2]) * tabWidth
      end
      --local x = startX + (i - 1) * tabWidth
      local y = startY
      local w1 = (tabWidth * tabWidthMultipliers[i]) - marginBetweenTabs
      local h1 = tabHeight

      if draw then
         --love.graphics.rectangle("line", x, y, w1, h1)
         if (selectedTab == tabs[i]) then
            -- love.graphics.setColor(1, 1, 1)
            -- love.graphics.rectangle("fill", x, y, w1, h1)
            -- love.graphics.setColor(0, 0, 0)
         end
         --love.graphics.print(tabs[i], x, y)
      else
         if (hit.pointInRect(clickX, clickY, x, y, w1, h1)) then
            print("clicked", tabs[i])
            selectedTab = tabs[i]
            playSound(scrollItemClickSample)
         end
      end
   end

   if draw then
      --local extraOffsetToTapes = tabHeight / 5
      local minimumHeight = drawImmediateSlidersEtc(false, startX, currentY, width)
      --love.graphics.rectangle("line", startX, currentY, width, minimumHeight)
      --love.graphics.print("ruimte voor sliders", startX + 6, currentY + 6)
      -- maybe   can use another weird global like settingsScrollArea
   end
end

function partSettingCellDimensions(amount, columns, width)
   local rows = math.ceil(amount / columns)
   local cellMargin = width / 48
   local useWidth = width - (2 * cellMargin) - (columns - 1) * cellMargin
   local cellWidth = (useWidth / columns)
   local cellSize = cellWidth + cellMargin
   return rows, cellWidth, cellMargin, cellSize
end

local function renderElement(type, value, container, x, y, w, h)
   if (type == "test") then
      love.graphics.rectangle("line", x, y, w, h)
      love.graphics.print(value, x, y)
   end
   if (type == "dot") then
      if (value <= #container) then
         local dotindex = (value % #dots)
         local pickedBG = editingGuy.values[selectedCategory].bgPal == value
         local pickedFG = editingGuy.values[selectedCategory].fgPal == value
         local pickedLP = editingGuy.values[selectedCategory].linePal == value
         if dotindex == 0 then
            dotindex = #dots
         end

         local dot = dots[dotindex]
         -- local scale, xoff, yoff = getScaleAndOffsetsForImage(dot, w, h)



         --  if pickedBG then
         --     love.graphics.setColor(0, 0, 0, .8)
         --     local r = (math.sin(love.timer.getTime() * 5)) * math.pi * 2
         --     love.graphics.draw(dot, -2 + x + (xoff + w / 2), -2 + y + (yoff + h / 2), r, scale, scale )
         --  end
         if pickedBG or pickedFG or pickedLP then
            love.graphics.setColor(1, 1, 1, 1)
            local scale, xoff, yoff = getScaleAndOffsetsForImage(dot, w * 1.5, h * 1.5)
            scale = scale + math.sin(love.timer.getTime() * 5) * 0.01
            love.graphics.draw(dot, -2 + x + (xoff + w / 2), -2 + y + (yoff + h / 2), 0, scale, scale)
            love.graphics.setColor(container[value])
            love.graphics.draw(dot, x + (xoff + w / 2), y + (yoff + h / 2), 0, scale, scale)
         else
            love.graphics.setColor(0, 0, 0, .8)
            local scale, xoff, yoff = getScaleAndOffsetsForImage(dot, w, h)
            love.graphics.draw(dot, -2 + x + (xoff + w / 2), -2 + y + (yoff + h / 2), 0, scale, scale)
            love.graphics.setColor(container[value])
            love.graphics.draw(dot, x + (xoff + w / 2), y + (yoff + h / 2), 0, scale, scale)
         end
         --love.graphics.rectangle("line", x, y, w, h)
      end
   end
   if (type == "img") then
      if (value <= #container) then
         local dotindex = (value % #container)
         if dotindex == 0 then
            dotindex = #container
         end
         local url = container[dotindex]

         local dot = imageCache[url] or love.graphics.newImage(url)
         imageCache[url] = dot
         local scale, xoff, yoff = getScaleAndOffsetsForImage(dot, w, h)

         local maskUrl = getPNGMaskUrl(url)

         local info = love.filesystem.getInfo(maskUrl)

         local picked = editingGuy.values[selectedCategory].shape == dotindex
         if picked then
            scale = scale + (math.sin(love.timer.getTime() * 5) * (scale / 20))
         end


         if info then
            local mask = imageCache[maskUrl] or love.graphics.newImage(maskUrl)
            imageCache[maskUrl] = mask

            love.graphics.setBlendMode('subtract')
            local pal = (palettes[editingGuy.values[selectedCategory].bgPal])
            --print(inspect(pal))
            --love.graphics.setColor(.5, .5, .5)
            if picked then
               love.graphics.setColor(1 - pal[1], 1 - pal[2], 1 - pal[3], 1)
            else
               love.graphics.setColor(1 - pal[1], 1 - pal[2], 1 - pal[3], 0.5)
            end
            love.graphics.draw(mask, -2 + x + (xoff + w / 2), -2 + y + (yoff + h / 2), 0, scale, scale, 0, 0)
            love.graphics.setBlendMode('alpha')
         end
         --love.graphics.setColor(0, 0, 0, .1)
         --love.graphics.rectangle("line", x, y, w, h)
         --love.graphics.draw(dot, -2 + x + (xoff + w / 2), -2 + y + (yoff + h / 2), 0, scale, scale, 0, 0)

         love.graphics.setColor(0, 0, 0, 1)
         love.graphics.draw(dot, x + (xoff + w / 2), y + (yoff + h / 2), 0, scale, scale, 0, 0)
         --love.graphics.print(value, x, y)
      end
   end
   if (type == "texture") then
      if (value <= #container) then
         local dotindex = (value % #container)
         if dotindex == 0 then
            dotindex = #container
         end
         local circleindex = (value % #circles) + 1
         local picked = editingGuy.values[selectedCategory].fgTex == dotindex
         local bpal = (palettes[editingGuy.values[selectedCategory].bgPal])
         local pal = (palettes[editingGuy.values[selectedCategory].fgPal])
         local lpal = (palettes[editingGuy.values[selectedCategory].linePal])
         local dot = container[dotindex]
         local scale, xoff, yoff = getScaleAndOffsetsForImage(dot, w, h)

         if picked then
            scale = scale + (math.sin(love.timer.getTime() * 5) * (scale / 20))
         end

         local function myStencilFunction()
            local r = w / 2
            if picked then
               r = r + (math.sin(love.timer.getTime() * 5) * (r / 20))
            end
            love.graphics.circle('fill', x + r, y + r, r)
         end

         love.graphics.stencil(myStencilFunction, "replace", 1)
         love.graphics.setStencilTest("greater", 0)

         love.graphics.setColor(bpal[1], bpal[2], bpal[3], 1)
         love.graphics.rectangle('fill', x, y, w, h)
         love.graphics.setColor(pal[1], pal[2], pal[3], 1)
         love.graphics.draw(dot, x + (xoff + w / 2), y + (yoff + h / 2), 0, scale, scale)


         love.graphics.setStencilTest()

         local scale, xoff, yoff = getScaleAndOffsetsForImage(circles[circleindex], w * 1.2, h * 1.2)
         love.graphics.setColor(lpal[1], lpal[2], lpal[3], 1)
         if picked then
            scale = scale + (math.sin(love.timer.getTime() * 5) * (scale / 20))
         end
         love.graphics.draw(circles[circleindex], x + (xoff + w / 2), y + (yoff + h / 2), 0, scale,
             scale)
      end
   end
end

local function buttonClickHelper(value)
   print('buttonClickHelper', value, selectedCategory)
   --print(value)
   --print(selectedTab, selectedCategory)
   local values = editingGuy.values
   local f = findPart(selectedCategory)
   if selectedTab == 'part' then
      values[selectedCategory]['shape'] = value
      changePart(selectedCategory, values)
      print(f.kind)
      if (f.kind == 'body') then
         tweenCameraToHeadAndBody()
      else
         tweenCameraToHead()
      end

      growl(1+love.math.random()*2)
     -- local pitch = 1+love.math.random()*2
     -- local index = math.ceil(love.math.random()*#hum) -- numbers.mapInto(value, valmin, valmax, 1, #hum)

     -- playingSound = playSound(hum[math.ceil(index)], 1+love.math.random()*2)
     -- local sndLength = hum[math.ceil(index)]:getDuration() / pitch

     -- myWorld:emit('mouthSaySomething', mouth, sndLength)

      --playSound(scrollItemClickSample)
   end
   if selectedTab == 'colors' then
      --local whichPart = { 'bgPal', 'fgPal', 'linePal' }
      --print(selectedColoringLayer)
      values[selectedCategory][selectedColoringLayer] = value
      changePart(selectedCategory, values)

      playSound(scrollItemClickSample)
   end
   if selectedTab == 'pattern' then
      values[selectedCategory]['fgTex'] = value
      changePart(selectedCategory, values)
      --local func = f.funcs[2]
      --func(f.funcs[3], values)
      playSound(scrollItemClickSample)
   end
end

function partSettingsScrollable(draw, clickX, clickY)
   local startX, startY, width, height = partSettingsPanelDimensions()
   if selectedTab == 'pattern' then
      startX = startX + (width / 20)
      width = width - (width / 10)
   end
   --local tabs = { 'part', 'bg', 'fg', 'pattern', 'line' }
   local tabWidth, tabHeight, marginBetweenTabs = partSettingsTabsDimensions(tabs, width)

   local currentY = startY + tabHeight

   local amount = #palettes
   local renderType = "dot"
   local renderContainer = palettes

   local columns = 3



   if selectedTab == "fg" or selectedTab == "bg" or selectedTab == "line" or selectedTab == "colors" then
      amount = #palettes
      renderType = "dot"
      columns = 5
      renderContainer = palettes
   end
   if selectedTab == "part" then
      local p = findPart(selectedCategory)
      --print(inspect(p))
      amount = #p.imgs
      renderType = "img"
      renderContainer = p.imgs
   end
   if selectedTab == "pattern" then
      amount = #textures
      renderType = "texture"
      renderContainer = textures
   end

   local rows, cellWidth, cellMargin, cellSize = partSettingCellDimensions(amount, columns, width)

   local cellHeight = cellWidth
   local currentX = startX + cellMargin

   local extraOffsetToTapes = tabHeight / 5
   local minimumHeight = drawImmediateSlidersEtc(draw, startX, currentY, width)
   currentY = currentY + minimumHeight + cellMargin
   local scrollAreaHeight = (height - minimumHeight - tabHeight)

   -- todo weird use of a 'global'
   -- the 5th is the cellsize/rowheight
   settingsScrollArea = {
       startX,
       currentY - cellMargin,
       width,
       scrollAreaHeight,
       (cellSize)
   }
   if draw then
      love.graphics.setScissor(settingsScrollArea[1], settingsScrollArea[2], settingsScrollArea[3], settingsScrollArea
      [4])
   end
   local rowsInPanel = math.ceil((scrollAreaHeight - cellMargin) / (cellSize))
   local endlesssScroll = true

   if rowsInPanel > rows then
      settingsScrollArea[8] = true -- 8 = true means we dont want scrolling at all!
      for j = -1, rows - 1 do
         for i = 1, columns do
            local newScroll = j --+ offset
            local yPosition = currentY + (newScroll * (cellSize))
            local xPosition = currentX + (i - 1) * (cellSize)
            local index = math.ceil(0) + j

            if (index >= 0 and index <= rows - 1) then
               local value = ((index % rows) * columns) + i
               if draw then
                  renderElement(
                      renderType,
                      value,
                      renderContainer,
                      xPosition,
                      yPosition,
                      cellWidth,
                      cellHeight
                  )
               else
                  if (hit.pointInRect(clickX, clickY, xPosition, yPosition, cellWidth, cellHeight)) then
                     if value <= #renderContainer then buttonClickHelper(value) end
                  end
               end
            end
         end
      end
   else
      local offset = settingsScrollPosition % 1
      if endlesssScroll == true then
         for j = -1, rowsInPanel - 1 do
            for i = 1, columns do
               local newScroll = j + offset
               local yPosition = currentY + (newScroll * (cellSize))
               local xPosition = currentX + (i - 1) * (cellSize)
               local index = math.ceil( -settingsScrollPosition) + j
               local value = ((index % rows) * columns) + i
               if draw then
                  renderElement(
                      renderType,
                      value,
                      renderContainer,
                      xPosition,
                      yPosition,
                      cellWidth,
                      cellHeight
                  )
               else
                  if (hit.pointInRect(clickX, clickY, xPosition, yPosition, cellWidth, cellHeight)) then
                     if value <= #renderContainer then buttonClickHelper(value) end
                  end
               end
            end
         end
      else
         local mx = (((rows * (cellHeight + (cellMargin))) - (scrollAreaHeight - cellMargin)) / (cellSize))

         --h ere i'm saving the min and max for scrolling behaviour, so i can use those in love.update
         settingsScrollArea[6] = 0
         settingsScrollArea[7] = -mx

         for j = -1, rows - 1 do
            for i = 1, columns do
               local newScroll = j + offset
               local yPosition = currentY + (newScroll * (cellSize))
               local xPosition = currentX + (i - 1) * (cellSize)
               local index = math.ceil( -settingsScrollPosition) + j

               if (index >= 0 and index <= rows - 1) then
                  local value = ((index % rows) * columns) + i
                  if draw then
                     renderElement(
                         renderType,
                         value,
                         renderContainer,
                         xPosition,
                         yPosition,
                         cellWidth,
                         cellHeight
                     )
                  else
                     if (hit.pointInRect(clickX, clickY, xPosition, yPosition, cellWidth, cellHeight)) then
                        if value <= #renderContainer then buttonClickHelper(value) end
                     end
                  end
               end
            end
         end
      end
   end
   if draw then
      love.graphics.setScissor()
   end
end

function headOrBody(draw, clickX, clickY)
   local w, h = love.graphics.getDimensions()
   local margin = w / 80

   local marginHeight = 2
   local size = (h / scrollItemsOnScreen) - marginHeight * 2
   local buttonHeight = size * 2 --(h / 2)

   local topY = (h / 2) - buttonHeight - margin


   local tabIndex = nil
   for i = 1, #tabs do
      if selectedTab == tabs[i] then
         tabIndex = i
      end
   end


   if draw then
      local maskAlpha = 0
      if selectedRootButton == 'head' then
         love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], 1)
         maskAlpha = 1
      else
         love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], .8)
         maskAlpha = .25
      end
      love.graphics.rectangle('fill', margin, topY, size, buttonHeight)

      local sx, sy = createFittingScale(bigbuttons.head, size, buttonHeight)
      love.graphics.setColor(colors[tabIndex][1], colors[tabIndex][2], colors[tabIndex][3], maskAlpha)

      love.graphics.draw(bigbuttons.headmask, margin, topY, 0, sx, sy)
      love.graphics.setColor(0, 0, 0, maskAlpha)



      love.graphics.draw(bigbuttons.head, margin, topY, 0, sx, sy)

      --love.graphics.print('head', margin, topY)


      if selectedRootButton == 'body' then
         love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], 1)
         maskAlpha = 1
      else
         love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], .8)
         maskAlpha = .25
      end

      love.graphics.rectangle('fill', margin, (h / 2), size, buttonHeight)

      local sx, sy = createFittingScale(bigbuttons.body, size, buttonHeight)

      love.graphics.setColor(colors[tabIndex][1], colors[tabIndex][2], colors[tabIndex][3], maskAlpha)
      love.graphics.draw(bigbuttons.bodymask, margin, (h / 2), 0, sx, sy)

      love.graphics.setColor(0, 0, 0, maskAlpha)


      love.graphics.draw(bigbuttons.body, margin, (h / 2), 0, sx, sy)


      --love.graphics.print('body', margin, (h / 2))
   else
      if (hit.pointInRect(clickX, clickY, margin, topY, size, buttonHeight)) then
         print('clicked in head button')
         playSound(scrollItemClickSample)
         if selectedRootButton == 'head' then
            selectedRootButton = nil
            tweenCameraToHeadAndBody()
         else
            selectedRootButton = 'head'
            tweenCameraToHead()
         end
         setCategories(selectedRootButton)
      end
      if (hit.pointInRect(clickX, clickY, margin, h / 2, size, buttonHeight)) then
         print('clicked in button button')
         if selectedRootButton == 'body' then
            selectedRootButton = nil
            tweenCameraToHeadAndBody()
         else
            selectedRootButton = 'body'
            tweenCameraToHeadAndBody()
         end
         playSound(scrollItemClickSample)
         setCategories(selectedRootButton)
      end
   end
end

-- scroll list is the main thing that has all categories
function scrollList(draw, clickX, clickY)
   local w, h = love.graphics.getDimensions()
   local margin = w / 80

   local marginHeight = 2
   local size = (h / scrollItemsOnScreen) - marginHeight * 2

   scrollListXPosition = size + margin * 2 -- this is updating a global!!!
   local offset = scrollPosition % 1
   if #categories > 0 then
      for i = -1, (scrollItemsOnScreen - 1) do
         local newScroll = i + offset
         local yPosition = marginHeight + (newScroll * (h / scrollItemsOnScreen))

         local index = math.ceil( -scrollPosition) + i
         index = (index % #categories) + 1
         if index < 1 then
            index = index + #categories
         end
         if index > #categories then
            index = 1
         end

         local whiterectIndex = math.ceil( -scrollPosition) + i
         whiterectIndex = (whiterectIndex % #whiterects) + 1
         local wrw, wrh = whiterects[whiterectIndex]:getDimensions()
         local scaleX = size / wrw
         local scaleY = size / wrh

         if draw then
            love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], .8)

            love.graphics.setColor(.1, .1, .1, .2)
            love.graphics.draw(whiterects[whiterectIndex], scrollListXPosition + 4, yPosition + 4, 0, scaleX, scaleY)

            love.graphics.setColor(255 / 255, 240 / 255, 200 / 255)
            love.graphics.draw(whiterects[whiterectIndex], scrollListXPosition, yPosition, 0, scaleX, scaleY)

            love.graphics.setColor(0, 0, 0)
            love.graphics.print(categories[index], scrollListXPosition, yPosition)
         else
            if (hit.pointInRect(clickX, clickY, scrollListXPosition, yPosition, size, size)) then
               print("clicked", categories[index])
               selectedCategory = categories[index]
               playSound(scrollItemClickSample)
            end
         end
      end
   end
end

local function drawCirclesAroundCenterCircle(cx, cy, label, buttonRadius, r, smallButtonRadius)
   love.graphics.circle("line", cx, cy, buttonRadius)
   love.graphics.print(label, cx, cy)

   local other = { "hair", "headshape", "eyes", "ears", "nose", "mouth", "chin" }
   local angleStep = (180 / (#other - 1))
   local angle = -90
   for i = 1, #other do
      local px = cx + r * math.cos(angle * math.pi / 180)
      local py = cy + r * math.sin(angle * math.pi / 180)
      angle = angle + angleStep
      love.graphics.circle("line", px, py, smallButtonRadius)
   end
end

--local res = { clicked = false }

local function bigButtonWithSmallAroundIt(x, y, textureOrColors)
   prof.push("big-bitton-small-around")
   local biggestRadius = 70
   local bigRadius = 40
   local radius = 20
   local diam = radius * 2
   local rad = -math.pi / 2
   local number = 4
   local step = (math.pi / 1.5) / (number - 1)

   love.graphics.setColor(0, 0, 0)
   love.graphics.circle("line", x, y, bigRadius)

   local first, second, third, fourth, fifth = nil, nil, nil, nil, nil

   if (type(textureOrColors[1]) == "table") then
      love.graphics.setColor(textureOrColors[1])
   else
      local img = mesh.getImage(textureOrColors[1])
      local scale, xOffset, yOffset = getScaleAndOffsetsForImage(img, diam * 2, diam * 2)

      love.graphics.draw(img, x + xOffset, y + yOffset, 0, scale, scale)
   end
   first = ui.getUICircle(x, y, bigRadius)

   for i = 2, #textureOrColors do
      local new_x = x + math.cos(rad) * biggestRadius
      local new_y = y + math.sin(rad) * biggestRadius
      love.graphics.setColor(0, 0, 0)
      love.graphics.circle("line", new_x, new_y, radius)

      if (type(textureOrColors[i]) == "table") then
         love.graphics.setColor(textureOrColors[i])
         love.graphics.circle("fill", new_x, new_y, radius - 2)
      else
         scale, xOffset, yOffset = getScaleAndOffsetsForImage(blup2, 40, 40)
         prof.push("render-masked-texture")
         canvas.renderMaskedTexture(blup2, textureOrColors[i], new_x + xOffset, new_y + yOffset, scale, scale)
         prof.pop("render-masked-texture")
      end

      local b = ui.getUICircle(new_x, new_y, 30)
      if (i == 2) then
         second = b
      end
      if (i == 3) then
         third = b
      end
      if (i == 4) then
         fourth = b
      end
      if (i == 5) then
         fifth = b
      end
      rad = rad + step
   end
   prof.pop("big-bitton-small-around")
   return first, second, third, fourth, fifth
end

local function buttonHelper(button, bodyPart, param, maxAmount, func, firstParam)
   if button then
      values[bodyPart][param] = values[bodyPart][param] + 1
      if values[bodyPart][param] > maxAmount then
         values[bodyPart][param] = 1
      end
      func(firstParam, values)
   end
end

local function bigButtonHelper(x, y, param, imgArray, changeFunc, redoFunc, firstParam)
   shapeButton, BGButton, FGTexButton, FGButton, LinePalButton =
       bigButtonWithSmallAroundIt(
           x,
           y,
           {
               imgArray[values[param].shape],
               palettes[values[param].bgPal],
               textures[values[param].fgTex],
               palettes[values[param].fgPal],
               palettes[values[param].linePal]
           }
       )

   -- todo maybe parametrize palettes and textures?
   buttonHelper(shapeButton, param, "shape", #imgArray, changeFunc, firstParam)
   buttonHelper(BGButton, param, "bgPal", #palettes, redoFunc, firstParam)
   buttonHelper(FGTexButton, param, "fgTex", #textures, redoFunc, firstParam)
   buttonHelper(FGButton, param, "fgPal", #palettes, redoFunc, firstParam)
   buttonHelper(LinePalButton, param, "linePal", #palettes, redoFunc, firstParam)
end

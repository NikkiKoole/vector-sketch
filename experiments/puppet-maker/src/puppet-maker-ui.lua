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

function setSecondaryColor(alpha)
   --0xf8 / 255, 0xa0 / 255, 0x67 / 255,
   love.graphics.setColor(pink[1], pink[2], pink[3], alpha)
end

function setTernaryColor(alpha)
   love.graphics.setColor(green[1], green[2], green[3], alpha)
end

function growl(pitch)
   local index = math.ceil(love.math.random() * #hum)
   local sndLength = hum[math.ceil(index)]:getDuration() / pitch
   playingSound = playSound(hum[math.ceil(index)], pitch)

   myWorld:emit('mouthSaySomething', mouth, sndLength)
end

function createFittingScale(img, desired_w, desired_h)
   local w, h = img:getDimensions()
   local sx, sy = desired_w / w, desired_h / h
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
   local ratio = h / w
   local index = ratio < 0.3 and 1 or 2

   local sx, sy = createFittingScale(uiheaders[index], w, h)
   love.graphics.setColor(1, 1, 1, .4)

   love.graphics.draw(uiheaders[index], x, y, 0, sx, sy, 0, 0)
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

      local changed = (v.value ~= getValueMaybeNested(prop))

      --values[prop] = v.value
      setValueMaybeNested(prop, v.value)
      propupdate(getValueMaybeNested(prop))
      if (changed) then
         if playingSound then playingSound:stop() end
         growl(1 + love.math.random() * 2)
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
      growl(1 + love.math.random() * 2)

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
      growl(1 + love.math.random() * 2)

      toggleFunc(true)
   end
   local w, h = toggle.body3:getDimensions()
   local t = ui.getUIRect('t-' .. prop, offset + startX, yOff + currentY, w * scale, h * scale)
   if t then
      growl(1 + love.math.random() * 2)

      toggleFunc(toggleValue)
   end
end

function drawImmediateSlidersEtc(draw, startX, currentY, width, category)
   local values = editingGuy.values
   local currentHeight = 0

   -- if small then buttonSize == 24
   -- if big then double (48)
   local buttonSize = width < 320 and 24 or 48

   width = width - buttonSize
   local columnsCells = (math.ceil(width / buttonSize))
   local sliderWidth = (width / math.ceil((columnsCells / 6))) - (buttonSize * 2)

   local elementWidth = (sliderWidth + (buttonSize * 2))
   local elementsInRow = width / elementWidth
   local runningElem = 0
   width = width + buttonSize
   startX = startX + buttonSize / 2

   local rowMultiplier = 1.3
   -- print('startX', startX)
   function updateRowStuff()
      runningElem = runningElem + 1
      if runningElem >= elementsInRow then
         runningElem = 0
         currentY = currentY + buttonSize * rowMultiplier
      end
      return runningElem, currentY
   end

   function calcCurrentHeight(itemsHere)
      local rowsInUse = math.ceil(itemsHere / elementsInRow)
      return rowsInUse * (buttonSize) * rowMultiplier
   end

   if selectedTab == 'part' then
      if category == 'body' then
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

         currentHeight = calcCurrentHeight(values.potatoHead and 6 or 5)

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
            runningElem, currentY = updateRowStuff()


            if values.potatoHead then
               local propupdate = function(v)
                  --editingGuy.body.transforms.l[5] = v
               end
               draw_slider_with_2_buttons('faceScale', startX + (runningElem * elementWidth), currentY,
                   buttonSize,
                   sliderWidth, propupdate,
                   update, 0.25, 2, .25, icons.facesmall, icons.facebig)

               runningElem, currentY = updateRowStuff()
            end
         end
      end

      if category == 'upperlip' or category == 'lowerlip' then
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


      if category == 'hair' then
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


      if category == 'brows' then
         currentHeight = calcCurrentHeight(4)
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

            draw_slider_with_2_buttons('browYAxis', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, -3, 3, 1, icons.browsdown, icons.browsup)

            runningElem, currentY = updateRowStuff()
         end
      end

      if category == 'nose' then
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



      if category == 'pupils' then
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


      if category == 'eyes' then
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

      if category == 'ears' then
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

      if category == 'legs' then
         currentHeight = calcCurrentHeight(5)
         if draw then
            runningElem = 0
            drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

            local propupdate = function(v)
               changePart('legs', values)
               myWorld:emit("bipedAttachLegs", biped)
               myWorld:emit("tweenIntoDefaultStance", biped)
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

      if category == 'arms' then
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

      if category == 'neck' then
         currentHeight = calcCurrentHeight(2)
         if draw then
            runningElem = 0
            drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

            local propupdate = function(v)
               changePart('neck', values)
               myWorld:emit('bipedAttachHeadKeepAngleChangeDistance', biped)
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

      if category == 'hands' then
         currentHeight = calcCurrentHeight(3)
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

            local f = function(v)
               values.handsPinned = not v
            end

            draw_toggle_with_2_buttons('handsPinned', startX + (runningElem * elementWidth), currentY, buttonSize,
                sliderWidth,
                (values.handsPinned),
                f, icons.handspinned, icons.handsfree)

            runningElem, currentY = updateRowStuff()
         end
      end

      if category == 'feet' then
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

            if false then
               local f = function(v)
                  values.feetPinned = not v
               end

               draw_toggle_with_2_buttons('feetPinned', startX + (runningElem * elementWidth), currentY, buttonSize,
                   sliderWidth,
                   (values.feetPinned),
                   f, icons.feetpinned, icons.feetfree)

               runningElem, currentY = updateRowStuff()
            end
         end
      end


      if category == 'skinPatchSnout' or category == 'skinPatchEye1' or category == 'skinPatchEye2' then
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
               local vv = category .. p

               draw_slider_with_2_buttons(vv, startX + (runningElem * elementWidth), currentY,
                   buttonSize,
                   sliderWidth, propupdate,
                   nil, mins[i], maxs[i], 1.0 / fs[i], icons['patch' .. p .. 'less'], icons['patch' .. p .. 'more'])

               runningElem, currentY = updateRowStuff()
            end
         end
      end


      if category == 'head' then
         local update = function()
            editingGuy.head.dirty = true
            transforms.setTransforms(editingGuy.head)
            changePart('head', values)
            myWorld:emit("bipedAttachHead", biped)
         end

         currentHeight = calcCurrentHeight(5)

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

            draw_slider_with_2_buttons('faceScale', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, 0.25, 2, .25, icons.facesmall, icons.facebig)

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
      local isPatch = category == 'skinPatchSnout' or category == 'skinPatchEye1' or category == 'skinPatchEye2'
      -- category == 'patches' or category == 'mouth' or category == 'eyes2' or category == 'arms2' or category == 'legs2'
      if findPart(category).children then
         currentHeight = 0
      else
         currentHeight = isPatch and calcCurrentHeight(5) or calcCurrentHeight(3)

         if draw then
            drawTapesForBackground(startX - buttonSize / 2, currentY, width, currentHeight)

            local propupdate = function(v)
               changePart(category)
            end
            runningElem = 0

            draw_slider_with_2_buttons(category .. '.texScale', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, 1, 9, 1, icons.patterncoarse, icons.patternfine)

            runningElem, currentY = updateRowStuff()

            draw_slider_with_2_buttons(category .. '.texRot', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, 0, 15, 1, icons.patternccw, icons.patterncw)

            runningElem, currentY = updateRowStuff()

            draw_slider_with_2_buttons(category .. '.fgAlpha', startX + (runningElem * elementWidth), currentY,
                buttonSize,
                sliderWidth, propupdate,
                nil, 0, 5, 1, icons.patterntransparent, icons.patternopaque)


            runningElem, currentY = updateRowStuff()


            if isPatch then
               draw_slider_with_2_buttons(category .. '.bgAlpha', startX + (runningElem * elementWidth), currentY,
                   buttonSize,
                   sliderWidth, propupdate,
                   nil, 0, 5, 1, icons.patterntransparent, icons.patternopaque)


               runningElem, currentY = updateRowStuff()

               draw_slider_with_2_buttons(category .. '.lineAlpha', startX + (runningElem * elementWidth), currentY,
                   buttonSize,
                   sliderWidth, propupdate,
                   nil, 0, 5, 1, icons.patterntransparent, icons.patternopaque)


               runningElem, currentY = updateRowStuff()
            end
         end
      end
   end


   if selectedTab == 'colors' then
      -- category == 'patches' or category == 'mouth' or category == 'eyes2' or category == 'arms2' or category == 'legs2'
      if findPart(category).children then
         currentHeight = 0
      else
         local colorkeys = { 'bgPal', 'fgPal', 'linePal' }


         local pickedColors = {
             palettes[values[category].bgPal],
             palettes[values[category].fgPal],
             palettes[values[category].linePal],
         }

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
      local iw = 650
      local ih = 1240
      --local iw, ih = tabui[1]:getDimensions()

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

      else
         if (hit.pointInRect(clickX, clickY, x, y, w1, h1)) then
            selectedTab = tabs[i]
            playSound(scrollItemClickSample)
         end
      end
   end

   --if draw then

   local minimumHeight = drawImmediateSlidersEtc(false, startX, currentY, width, selectedCategory)
   currentY = currentY + minimumHeight
   drawChildPicker(draw, startX, currentY, width, clickX, clickY)

   if findPart(selectedCategory).children then
      local minimumHeight = drawImmediateSlidersEtc(false, startX, currentY, width, selectedChildCategory)
      currentY = currentY + minimumHeight
   end
   --end

   --if clickX ~= nil then
   --print('part settings surroundings', clickX, clickY)
   --end
end

function partSettingCellDimensions(amount, columns, width)
   local rows = math.ceil(amount / columns)
   local cellMargin = width / 48
   local useWidth = width - (2 * cellMargin) - (columns - 1) * cellMargin
   local cellWidth = (useWidth / columns)
   local cellSize = cellWidth + cellMargin
   return rows, cellWidth, cellMargin, cellSize
end

local function renderElement(category, type, value, container, x, y, w, h)
   if (type == "test") then
      love.graphics.rectangle("line", x, y, w, h)
      love.graphics.print(value, x, y)
   end
   if (type == "dot") then
      if (value <= #container) then
         local dotindex = (value % #dots)
         local pickedBG = editingGuy.values[category].bgPal == value
         local pickedFG = editingGuy.values[category].fgPal == value
         local pickedLP = editingGuy.values[category].linePal == value
         if dotindex == 0 then
            dotindex = #dots
         end

         local dot = dots[dotindex]

         if pickedBG or pickedFG or pickedLP then
            local scale, xoff, yoff = getScaleAndOffsetsForImage(dot, w * 1.5, h * 1.5)
            local offset = (0.1 * scale * w) / 2

            love.graphics.setColor(container[value])
            love.graphics.draw(dot, x + (xoff + w / 2), y + (yoff + h / 2), 0, scale, scale)

            love.graphics.setColor(0, 0, 0, .99)
            local sx, sy = createFittingScale(circles[1], w * 1.5, h * 1.5)
            love.graphics.draw(circles[1], x + (xoff + w / 2), y + (yoff + h / 2), 0, sx, sy)
         else
            local scale, xoff, yoff = getScaleAndOffsetsForImage(dot, w, h)
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

         local picked = editingGuy.values[category].shape == dotindex
         if picked then
            scale = scale + (math.sin(love.timer.getTime() * 5) * (scale / 20))
         end


         if info then
            local mask = imageCache[maskUrl] or love.graphics.newImage(maskUrl)
            imageCache[maskUrl] = mask

            love.graphics.setBlendMode('subtract')
            local pal = (palettes[editingGuy.values[category].bgPal])

            if picked then
               love.graphics.setColor(1 - pal[1], 1 - pal[2], 1 - pal[3], 1)
            else
               love.graphics.setColor(1 - pal[1], 1 - pal[2], 1 - pal[3], 0.5)
            end
            love.graphics.draw(mask, -2 + x + (xoff + w / 2), -2 + y + (yoff + h / 2), 0, scale, scale, 0, 0)
            love.graphics.setBlendMode('alpha')
         end

         love.graphics.setColor(0, 0, 0, 1)
         love.graphics.draw(dot, x + (xoff + w / 2), y + (yoff + h / 2), 0, scale, scale, 0, 0)
      end
   end
   if (type == "texture") then
      if (value <= #container) then
         local dotindex = (value % #container)
         if dotindex == 0 then
            dotindex = #container
         end
         --local category = selectedCategory
         --if not editingGuy.values[category] then
         --   category = 'skinPatchSnout'
         --end
         local circleindex = (value % #circles) + 1
         local picked = editingGuy.values[category].fgTex == dotindex
         local bpal = (palettes[editingGuy.values[category].bgPal])
         local pal = (palettes[editingGuy.values[category].fgPal])
         local lpal = (palettes[editingGuy.values[category].linePal])
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

local function buttonClickHelper(category, value)
   local values = editingGuy.values
   --local category = selectedCategory
   --if not editingGuy.values[category] then
   --   category = 'skinPatchSnout'
   --end


   local f = findPart(category)
   if selectedTab == 'part' then
      values[category]['shape'] = value
      changePart(category, values)

      if (f.kind == 'body') then
         tweenCameraToHeadAndBody()
      else
         tweenCameraToHead()
      end

      growl(1 + love.math.random() * 2)
   end
   if selectedTab == 'colors' then
      values[category][selectedColoringLayer] = value
      changePart(category, values)

      playSound(scrollItemClickSample)
   end
   if selectedTab == 'pattern' then
      values[category]['fgTex'] = value
      changePart(category, values)

      playSound(scrollItemClickSample)
   end
end

function childPickerDimensions(width)
   local p = findPart(selectedCategory)
   local childrenTabHeight = 0
   if p.children then
      childrenTabHeight = width / 5
   end
   return childrenTabHeight * 1.2
end

function drawChildPicker(draw, startX, currentY, width, clickX, clickY)
   local childrenTabHeight = 0

   local p = findPart(selectedCategory)
   if p.children then
      childrenTabHeight = width / 5 --((width-cellMargin*2)/(#p.children * 1.5))
      if draw then
         drawTapesForBackground(startX, currentY, width, childrenTabHeight * 1.2)
      end

      local offset = childrenTabHeight * 0.1
      for i = 1, #p.children do
         local xPosition = offset + startX + ((i - 1) * childrenTabHeight)
         local yPosition = currentY + offset
         if draw then
            local sx, sy = createFittingScale(whiterects[1], childrenTabHeight, childrenTabHeight)



            --love.graphics.setColor(0xf8 / 255, 0xa0 / 255, 0x67 / 255, .5)
            --love.graphics.setColor(1, 1, 1, .5)

            love.graphics.setColor(0, 0, 0, 0.1)
            love.graphics.draw(whiterects[1], xPosition + 2, yPosition + 2, 0, sx, sy)

            love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], 1)
            love.graphics.draw(whiterects[1], xPosition, yPosition, 0, sx, sy)

            if selectedChildCategory == p.children[i] then
               love.graphics.setColor(0, 0, 0, .8)
               local sx, sy = createFittingScale(rects[1], childrenTabHeight, childrenTabHeight)
               love.graphics.draw(rects[1], xPosition, yPosition, 0, sx, sy)
            end

            sx, sy = createFittingScale(scrollIcons[p.children[i]], childrenTabHeight, childrenTabHeight)

            setSecondaryColor(1)
            love.graphics.draw(scrollIcons[p.children[i] .. 'Mask'], xPosition, yPosition, 0, sx, sy)
            love.graphics.setColor(0, 0, 0, .8)
            love.graphics.draw(scrollIcons[p.children[i]], xPosition, yPosition, 0, sx, sy)
         else
            -- todo this isnt working because the scrollarea is not correct so this will only be called whne i click in the scrollarea

            -- print(clickX, clickY,  xPosition, yPosition, childrenTabHeight, childrenTabHeight)
            if (hit.pointInRect(clickX, clickY, xPosition, yPosition, childrenTabHeight, childrenTabHeight)) then
               print(p.children[i])
               selectedChildCategory = p.children[i]
            end
         end
      end
   end
   return childrenTabHeight * 1.2
end

function partSettingsScrollable(draw, clickX, clickY)
   local startX, startY, width, height = partSettingsPanelDimensions()
   --if true or selectedTab == 'pattern' then
   --   startX = startX + (width / 20)
   --   width = width - (width / 10)
   --end
   --local tabs = { 'part', 'bg', 'fg', 'pattern', 'line' }
   local tabWidth, tabHeight, marginBetweenTabs = partSettingsTabsDimensions(tabs, width)

   local currentY = startY + tabHeight

   local amount = #palettes
   local renderType = "dot"
   local renderContainer = palettes

   local columns = 3

   local category = selectedCategory
   local p = findPart(selectedCategory)
   if p.children then
      p = findPart(selectedChildCategory)
      category = selectedChildCategory
   end


   if selectedTab == "fg" or selectedTab == "bg" or selectedTab == "line" or selectedTab == "colors" then
      amount = #palettes
      renderType = "dot"
      columns = 5
      renderContainer = palettes
   end
   if selectedTab == "part" then
      amount = p.imgs and #p.imgs or 0
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
   local minimumHeight = drawImmediateSlidersEtc(draw, startX, currentY, width, selectedCategory)

   local otherHeight = 0
   ---------

   -- todo drawChildSpecificSLidersEtc
   --



   local childrenTabHeight = childPickerDimensions(width) --drawChildPicker(draw, startX, currentY , width, clickX, clickY)

   if findPart(selectedCategory).children then
      -- print(selectedChildCategory)
      currentY = currentY + childrenTabHeight
      otherHeight = drawImmediateSlidersEtc(draw, startX, currentY, width, selectedChildCategory)
      currentY = currentY + otherHeight
   end

   currentY = currentY + minimumHeight + cellMargin




   local scrollAreaHeight = (height - minimumHeight - otherHeight - tabHeight - childrenTabHeight)

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
      --   love.graphics.rectangle('line', settingsScrollArea[1], settingsScrollArea[2], settingsScrollArea[3], settingsScrollArea[4])
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
                      category,
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
                     if value <= #renderContainer then buttonClickHelper(category, value) end
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
                      category,
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
                     if value <= #renderContainer then buttonClickHelper(category, value) end
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
                         category,
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
                        if value <= #renderContainer then buttonClickHelper(category, value) end
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

      local sx1, sy1 = createFittingScale(whiterects[1], size, buttonHeight)
      love.graphics.draw(whiterects[1], margin, topY, 0, sx1, sy1)



      --love.graphics.rectangle('fill', margin, topY, size, buttonHeight)

      setSecondaryColor(maskAlpha)
      if (selectedRootButton == 'head') then
         local sx2, sy2 = createFittingScale(rects[1], size, buttonHeight)
         love.graphics.draw(rects[1], margin, topY, 0, sx2, sy2)
      end

      local sx, sy = createFittingScale(bigbuttons.head, size, buttonHeight)


      love.graphics.draw(bigbuttons.headmask, margin, topY, 0, sx, sy)
      love.graphics.setColor(0, 0, 0, maskAlpha)



      love.graphics.draw(bigbuttons.head, margin, topY, 0, sx, sy)


      if selectedRootButton == 'body' then
         love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], 1)
         maskAlpha = 1
      else
         love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], .8)
         maskAlpha = .25
      end

      local sx2, sy2 = createFittingScale(whiterects[1], size, buttonHeight)
      love.graphics.draw(whiterects[1], margin, (h / 2), 0, sx2, sy2)


      --love.graphics.rectangle('fill', margin, (h / 2), size, buttonHeight)

      local sx, sy = createFittingScale(bigbuttons.body, size, buttonHeight)


      setSecondaryColor(maskAlpha)
      if (selectedRootButton == 'body') then
         local sx2, sy2 = createFittingScale(rects[1], size, buttonHeight)
         love.graphics.draw(rects[1], margin, (h / 2), 0, sx2, sy2)
      end

      love.graphics.draw(bigbuttons.bodymask, margin, (h / 2), 0, sx, sy)

      love.graphics.setColor(0, 0, 0, maskAlpha)


      love.graphics.draw(bigbuttons.body, margin, (h / 2), 0, sx, sy)
   else
      if (hit.pointInRect(clickX, clickY, margin, topY, size, buttonHeight)) then
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

   scrollListXPosition = h / 12 ----margin * 2 -- this is updating a global!!!
   local offset = scrollPosition % 1

   local tabIndex = nil
   for i = 1, #tabs do
      if selectedTab == tabs[i] then
         tabIndex = i
      end
   end

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
         local alpha = 0.8

         local whiterectIndex = math.ceil( -scrollPosition) + i
         whiterectIndex = (whiterectIndex % #whiterects) + 1
         local marginb = size / 10
         local scaleX, scaleY = createFittingScale(whiterects[whiterectIndex], size, size)


         if draw then
            local sm = 1
            if selectedCategory == categories[index] then
               local offset = math.sin(love.timer.getTime() * 5) * 0.02
               sm = sm + offset
               alpha = 1
            end


            love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], alpha)

            if selectedCategory == categories[index] then
               love.graphics.setColor(.1, .1, .1, 0.2)
               love.graphics.draw(whiterects[whiterectIndex], scrollListXPosition + 4, yPosition + 4, 0,
                   scaleX, scaleY)
            end
            love.graphics.setColor(255 / 255, 240 / 255, 200 / 255, alpha)
            love.graphics.draw(whiterects[whiterectIndex], scrollListXPosition, yPosition, 0, scaleX, scaleY)

            love.graphics.setColor(0.5, 0.5, 0.5, alpha)
            if selectedCategory == categories[index] then
               --setSecondaryColor(alpha)
               love.graphics.setColor(0, 0, 0, alpha)
               local sx, sy = createFittingScale(rects[1], size, size)
               love.graphics.draw(rects[1], scrollListXPosition, yPosition, 0, sx * sm, sy * sm)
               love.graphics.setColor(0, 0, 0, alpha)
            end


            if (scrollIcons[categories[index]]) then
               local sx, sy = createFittingScale(scrollIcons[categories[index]], size, size)
               love.graphics.draw(scrollIcons[categories[index]], scrollListXPosition, yPosition, 0, sx * sm, sy * sm,
                   alpha)

               local m = scrollIcons[categories[index] .. 'Mask']

               if (m) then
                  if findPart(categories[index]).kind == 'body' then
                     setTernaryColor(alpha)
                  else
                     setSecondaryColor(alpha)
                  end

                  local sx, sy = createFittingScale(m, size, size)
                  love.graphics.draw(m, scrollListXPosition, yPosition, 0, sx * sm, sy * sm)
               end
            else
               love.graphics.print(categories[index], scrollListXPosition, yPosition)
            end
         else
            if (hit.pointInRect(clickX, clickY, scrollListXPosition, yPosition, size, size)) then
               selectedCategory = categories[index]
               local f = findPart(selectedCategory)
               if f.children then
                  selectedChildCategory = f.children[1]
               end
               if f.kind == 'body' then
                  tweenCameraToHeadAndBody()
               end
               if f.kind == 'head' then
                  tweenCameraToHead()
               end
               playSound(scrollItemClickSample)
            end
         end
      end
   end
end

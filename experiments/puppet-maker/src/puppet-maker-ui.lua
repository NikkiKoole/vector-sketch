-- this is the panel that contains all ui for changing a certain body part or general change
-- for each category we have a optionally unique panel

local hit = require "lib.hit"
local canvas = require "lib.canvas"
local mesh = require "lib.mesh"
local ui = require "lib.ui"
local transforms = require "lib.transform"
local text = require 'lib.text'

imageCache = {} -- tjo save all the parts inages in



local tabs = { "part", "colors", "pattern" }

local function getPNGMaskUrl(url)
   return text.replace(url, '.png', '-mask.png')
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
   love.graphics.draw(uiheaders[index], x, y + h / 2, 0, sx, sy, 0, imgh / 2)
end

function drawImmediateSlidersEtc(draw, startX, currentY, width)
   local values = editingGuy.values
   local currentHeight = 20

   if selectedTab == 'part' then
      currentHeight = 130

      if draw then
         drawTapesForBackground(startX, currentY, width, currentHeight)
      end

      if selectedCategory == 'upperlip' then
         if draw then
            local v = h_slider("mouth-yAxis", startX, currentY, 50, values.mouthYAxis, -1, 3)
            if v.value then
               v.value = math.floor(v.value * 2) / 2.0 -- round to 1
               values.mouthYAxis = v.value
               myWorld:emit('potatoInit', potato)
            end
         end
      end
      if selectedCategory == 'lowerlip' then
         if draw then
            local v = h_slider("mouth-yAxis", startX, currentY, 50, values.mouthYAxis, -1, 3)
            if v.value then
               v.value = math.floor(v.value * 2) / 2.0 -- round to 1
               values.mouthYAxis = v.value
               myWorld:emit('potatoInit', potato)
            end
         end
      end


      if selectedCategory == 'hair' then
         if draw then
            local v = h_slider("hair-width", startX, currentY, 150, values.hairWidthMultiplier, .00005, 2)
            if v.value then
               v.value = v.value --math.floor(v.value * 100) / 200.0 -- round to .5
               values.hairWidthMultiplier = v.value

               changePart('hair', values)
            end
            currentY = currentY + 25
            local v = h_slider("hair-tension", startX, currentY, 150, values.hairTension, .00005, 1)
            if v.value then
               v.value = v.value --math.floor(v.value * 100) / 200.0 -- round to .5
               values.hairTension = v.value

               changePart('hair', values)
            end
         end
      end


      if selectedCategory == 'brows' then
         if draw then
            local v = h_slider("brow-width", startX, currentY, 50, values.browsWidthMultiplier, .5, 2)
            if v.value then
               v.value = math.floor(v.value * 2) / 2.0 -- round to .5
               values.browsWidthMultiplier = v.value
               arrangeBrows()
               changePart('brows', values)
            end

            currentY = currentY + 25
            local v = h_slider("brow-wide", startX, currentY, 50, values.browsWideMultiplier, .5, 2)
            if v.value then
               v.value = math.floor(v.value * 2) / 2.0 -- round to .5
               values.browsWideMultiplier = v.value
               print(values.browsWideMultiplier)
               arrangeBrows()
               changePart('brows', values)
            end

            currentY = currentY + 25

            local v = h_slider("brow-movement", startX, currentY, 50, values.browsDefaultBend, 1, 10)
            if v.value then
               local p = findPart('brows').imgs
               local img = mesh.getImage(p[values.brows.shape])
               local width, height = img:getDimensions()
               values.browsDefaultBend = math.floor(v.value)
               arrangeBrows()
               changePart('brows', values)
            end
         end
      end

      if selectedCategory == 'nose' then
         if draw then
            local v = h_slider("nose-width", startX, currentY, 50, values.noseWidthMultiplier, .5, 3)
            if v.value then
               v.value = math.floor(v.value * 2) / 2.0 -- round to .5
               values.noseWidthMultiplier = v.value
               --nose.transforms.l[4] = v.value
               myWorld:emit('rescaleFaceparts', potato)
            end
            currentY = currentY + 25
            local v = h_slider("nose-height", startX, currentY, 50, values.noseHeightMultiplier, .5, 3)
            if v.value then
               v.value = math.floor(v.value * 2) / 2.0 -- round to .5
               values.noseHeightMultiplier = v.value
               -- nose.transforms.l[5] = v.value
               myWorld:emit('rescaleFaceparts', potato)
            end
            currentY = currentY + 25
            local v = h_slider("nose-yAxis", startX, currentY, 50, values.noseYAxis, -1, 1)
            if v.value then
               v.value = math.floor(v.value * 2) / 2.0 -- round to 1
               values.noseYAxis = v.value
               myWorld:emit('potatoInit', potato)
            end
         end
      end



      if selectedCategory == 'pupils' then
         if draw then
            local v = h_slider("pupil-size", startX, currentY, 50, values.pupilSizeMultiplier, .125, 2)
            if v.value then
               v.value = math.floor(v.value * 8) / 8.0 -- round to .125
               values.pupilSizeMultiplier = v.value
               myWorld:emit('rescaleFaceparts', potato)
            end
         end
      end


      if selectedCategory == 'eyes' then
         if draw then
            local v = h_slider("eye-width", startX, currentY, 50, values.eyeWidthMultiplier, .125, 3)
            if v.value then
               v.value = math.floor(v.value * 8) / 8.0 -- round to .5
               values.eyeWidthMultiplier = v.value
               myWorld:emit('rescaleFaceparts', potato)
            end
            currentY = currentY + 25
            local v = h_slider("eye-height", startX, currentY, 50, values.eyeHeightMultiplier, .125, 3)
            if v.value then
               v.value = math.floor(v.value * 8) / 8.0 -- round to .5
               values.eyeHeightMultiplier = v.value
               myWorld:emit('rescaleFaceparts', potato)
            end
            currentY = currentY + 25
            local v = h_slider("eye-rotation", startX, currentY, 50, values.eyeRotation, -math.pi / 6, math.pi / 6)
            if v.value then
               v.value = math.floor(v.value * 4) / 4.0 -- round to .5
               values.eyeRotation = v.value
               editingGuy.eye1.transforms.l[3] = v.value
               editingGuy.eye2.transforms.l[3] = -v.value
            end
            currentY = currentY + 25
            local v = h_slider("eye-YAxis", startX, currentY, 50, values.eyeYAxis, -3, 3)
            if v.value then
               v.value = math.floor(v.value)
               values.eyeYAxis = v.value
               myWorld:emit('potatoInit', potato)
            end
            currentY = currentY + 25
            local v = h_slider("eye-XAxisBetween", startX, currentY, 50, values.eyeXAxisBetween, -3, 3)
            if v.value then
               v.value = math.floor(v.value)
               values.eyeXAxisBetween = v.value
               myWorld:emit('potatoInit', potato)
            end
         end
      end

      if selectedCategory == 'ears' then
         if draw then
            local v = h_slider("ear-rotation", startX, currentY, 50, values.earRotation, -math.pi / 2, math.pi / 2)
            if v.value then
               values.earRotation = v.value
               editingGuy.ear1.transforms.l[3] = v.value
               editingGuy.ear2.transforms.l[3] = -v.value
            end
            currentY = currentY + 25
            local v = h_slider("ear-width", startX, currentY, 50, values.earWidthMultiplier, .5, 3)
            if v.value then
               v.value = math.floor(v.value * 2) / 2.0 -- round to .5
               values.earWidthMultiplier = v.value
               myWorld:emit('rescaleFaceparts', potato)
            end
            currentY = currentY + 25
            local v = h_slider("ear-yAxis", startX, currentY, 50, values.earYAxis, -3, 3)
            if v.value then
               v.value = math.floor(v.value)
               values.earYAxis = v.value
               myWorld:emit('potatoInit', potato)
            end
            currentY = currentY + 50
            startX = startX + 20
            love.graphics.setColor(1, 0, 1)
            love.graphics.circle('fill', startX, currentY, 10)
            local b = ui.getUICircle(startX, currentY, 10)
            if b then
               values.earUnderHead = not values.earUnderHead
               attachAllFaceParts(editingGuy)
               myWorld:emit('rescaleFaceparts', potato)
            end
         end
      end

      if selectedCategory == 'legs' then
         if draw then
            v = h_slider("leg-axis", startX, currentY, 50, values.legXAxis, 0, 1)
            if v.value then
               values.legXAxis = math.floor(v.value * 4) / 4.0
               changePart('legs', values)
               myWorld:emit("bipedAttachLegs", biped)
            end
            currentY = currentY + 25
            v = h_slider("leg-length", startX, currentY, 50, values.legLength, 1, #leglengths)
            if v.value then
               values.legLength = math.floor(v.value)
               print(values.legLength)
               changePart('legs', values)
               changePart('leghair', values)
            end
            currentY = currentY + 25
            v = h_slider("leg-width-multiplier", startX, currentY, 50, values.legWidthMultiplier, 0.5, 3)
            if v.value then
               v.value = math.floor(v.value * 2) / 2.0 -- round to .5
               values.legWidthMultiplier = v.value
               changePart('legs', values)
            end
            currentY = currentY + 25
            startX = startX + 10
            love.graphics.setColor(1, 0, 1)
            love.graphics.circle('fill', startX, currentY, 10)
            local b = ui.getUICircle(startX, currentY, 10)
            if b then
               values.legs.flipy = values.legs.flipy == -1 and 1 or -1
               changePart('legs', values)
            end
         end
      end

      if selectedCategory == 'arms' then
         if draw then
            v = h_slider("arm-length", startX, currentY, 50, values.armLength, 1, #leglengths)
            if v.value then
               values.armLength = math.floor(v.value)
               print(values.armLength)
               changePart('arms', values)
               changePart('armhair', values)
            end
            currentY = currentY + 25
            v = h_slider("leg-width-multiplier", startX, currentY, 50, values.armWidthMultiplier, 0.5, 3)
            if v.value then
               v.value = math.floor(v.value * 2) / 2.0 -- round to .5
               values.armWidthMultiplier = v.value
               changePart('arms', values)
            end
            currentY = currentY + 25

            startX = startX + 10
            love.graphics.setColor(1, 0, 1)
            love.graphics.circle('fill', startX, currentY, 10)
            local b = ui.getUICircle(startX, currentY, 10)
            if b then
               values.arms.flipy = values.arms.flipy == -1 and 1 or -1
               changePart('arms', values)
            end
         end
      end

      if selectedCategory == 'neck' then
         if draw then
            v = h_slider("neck-length", startX, currentY, 50, values.neckLength, 1, #necklengths)
            if v.value then
               values.neckLength = math.floor(v.value)
               print(values.armLength)
               changePart('neck', values)
               --changePart('armhair', values)
            end
            currentY = currentY + 25
            v = h_slider("neck-width-multiplier", startX, currentY, 50, values.neckWidthMultiplier, 0.5, 3)
            if v.value then
               v.value = math.floor(v.value * 2) / 2.0 -- round to .5
               values.neckWidthMultiplier = v.value
               changePart('neck', values)
            end
            currentY = currentY + 25
         end
      end

      if selectedCategory == 'hands' then
         if draw then
            v = h_slider("hand-length", startX, currentY, 50, values.handLengthMultiplier, .5, 3)
            if v.value then
               v.value = math.floor(v.value * 2) / 2.0 -- round to .5
               values.handLengthMultiplier = v.value
               changePart('hands', values)
               editingGuy.hand1.transforms.l[4] = v.value
               editingGuy.hand2.transforms.l[4] = -v.value
            end
            currentY = currentY + 25
            v = h_slider("hand-width", startX, currentY, 50, values.handWidthMultiplier, .5, 3)
            if v.value then
               v.value = math.floor(v.value * 2) / 2.0 -- round to .5
               values.handWidthMultiplier = v.value
               changePart('hands', values)
               editingGuy.hand1.transforms.l[5] = v.value
               editingGuy.hand2.transforms.l[5] = v.value
            end
            currentY = currentY + 25
         end
      end

      if selectedCategory == 'feet' then
         if draw then
            v = h_slider("feet-length", startX, currentY, 50, values.feetLengthMultiplier, .5, 3)
            if v.value then
               v.value = math.floor(v.value * 2) / 2.0 -- round to .5
               values.feetLengthMultiplier = v.value
               changePart('feet', values)
               editingGuy.feet1.transforms.l[4] = v.value
               editingGuy.feet2.transforms.l[4] = -v.value
            end
            currentY = currentY + 25
            v = h_slider("feet-width", startX, currentY, 50, values.feetWidthMultiplier, .5, 3)
            if v.value then
               v.value = math.floor(v.value * 2) / 2.0 -- round to .5
               values.feetWidthMultiplier = v.value
               changePart('feet', values)
               editingGuy.feet1.transforms.l[5] = v.value
               editingGuy.feet2.transforms.l[5] = v.value
            end
            currentY = currentY + 25
         end
      end


      if selectedCategory == 'skinPatchSnout' or selectedCategory == 'skinPatchEye1' or selectedCategory == 'skinPatchEye2' then
         local posts = { 'ScaleX', 'ScaleY', 'Angle', 'X', 'Y' }
         local mins = { .25, .25, 0, -6, -6 }
         local maxs = { 3, 3, 15, 6, 6 }
         local fs = { 4.0, 4.0, 1, 1, 1 }
         if draw then
            for i = 1, #posts do
               local p = posts[i]
               local vv = selectedCategory .. p
               local v = h_slider(vv, startX, currentY, 50, values[vv], mins[i], maxs[i])
               if v.value then
                  v.value = math.floor(v.value * fs[i]) / fs[i] -- round to .5
                  print(vv, v.value)
                  values[vv] = v.value
                  changePart('head', values)
               end
               currentY = currentY + 25
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

         if draw then
            local v = h_slider("head-width", startX, currentY, 50, values.headWidthMultiplier, .5, 3)
            if v.value then
               v.value = math.floor(v.value * 2) / 2.0 -- round to .5
               values.headWidthMultiplier = v.value
               myWorld:emit('rescaleFaceparts', potato)
               --head.transforms.l[4] = v.value
               update()
            end
            currentY = currentY + 25

            v = h_slider("head-height", startX, currentY, 50, values.headHeightMultiplier, .5, 3)
            if v.value then
               v.value = math.floor(v.value * 2) / 2.0 -- round to .5
               values.headHeightMultiplier = v.value
               myWorld:emit('rescaleFaceparts', potato)
               --head.transforms.l[5] = v.value
               update()
            end
            currentY = currentY + 50
            startX = startX + 10
            love.graphics.circle('fill', startX, currentY, 10)
            local b = ui.getUICircle(startX, currentY, 10)
            if b then
               values.head.flipy = values.head.flipy == -1 and 1 or -1
               update()
            end
            startX = startX + 25
            love.graphics.circle('fill', startX, currentY, 10)
            local b = ui.getUICircle(startX, currentY, 10)
            if b then
               values.head.flipx = values.head.flipx == -1 and 1 or -1
               update()
            end
         end
      end
      if selectedCategory == 'body' then
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
         if draw then
            local v = h_slider("body-width", startX, currentY, 50, values.bodyWidthMultiplier, .5, 3)
            if v.value then
               v.value = math.floor(v.value * 2) / 2.0 -- round to .5

               values.bodyWidthMultiplier = v.value
               --  values.bodyHeightMultiplier = v.value
               --body.transforms.l[5] = v.value
               editingGuy.body.transforms.l[4] = v.value
               update()
            end
            currentY = currentY + 25
            v = h_slider("body-height", startX, currentY, 50, values.bodyHeightMultiplier, .5, 3)
            if v.value then
               v.value = math.floor(v.value * 2) / 2.0 -- round to .5
               values.bodyHeightMultiplier = v.value
               editingGuy.body.transforms.l[5] = v.value
               update()
            end
            currentY = currentY + 50
            startX = startX + 10
            love.graphics.setColor(0, 0, 0)
            love.graphics.circle('fill', startX, currentY, 10)

            local b = ui.getUICircle(startX, currentY, 10)
            if b then
               values.body.flipy = values.body.flipy == -1 and 1 or -1
               update()
            end

            startX = startX + 25
            love.graphics.circle('fill', startX, currentY, 10)
            local b = ui.getUICircle(startX, currentY, 10)
            if b then
               values.body.flipx = values.body.flipx == -1 and 1 or -1
               update()
            end

            currentY = currentY + 25
            love.graphics.setColor(0, 0, 0)
            love.graphics.circle('fill', startX, currentY, 10)

            local b = ui.getUICircle(startX, currentY, 10)
            if b then
               values.potatoHead = not values.potatoHead
               myWorld:emit('bipedUsePotatoHead', biped, values.potatoHead)
               --if values.potatoHead then
               editingGuy.body.transforms.l[4] = values.bodyWidthMultiplier
               editingGuy.body.transforms.l[5] = values.bodyHeightMultiplier
               --end

               attachAllFaceParts(editingGuy)
               changePart('head', values)
               changePart('body', values)
               myWorld:emit('rescaleFaceparts', potato)
               setCategories()
            end
         end
      end
   end




   if selectedTab == 'pattern' then
      currentHeight = 150
      currentY = currentY + 10
      local originY = currentY
      local originX = startX

      if draw then
         drawTapesForBackground(originX, originY, width, currentHeight)

         local v = h_slider("pattern-scale", startX, currentY, 200, values[selectedCategory].texScale, 1, 9)
         if v.value then
            v.value = math.floor(v.value)
            values[selectedCategory].texScale = v.value
            changePart(selectedCategory, values)
         end
         currentY = currentY + 50
         local v = h_slider("pattern-rotation", startX, currentY, 200, values[selectedCategory].texRot, 0, 15)
         if v.value then
            v.value = math.floor(v.value)
            values[selectedCategory].texRot = v.value
            changePart(selectedCategory, values)
         end
         currentY = currentY + 50
         local v = h_slider("pattern-opacity", startX, currentY, 200, values[selectedCategory].fgAlpha, 0, 5)
         if v.value then
            values[selectedCategory].fgAlpha = math.floor(v.value)
            --selectedColoringLayer = colorkeys[i]
            changePart(selectedCategory, values)
         end
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
         drawTapesForBackground(originX, originY, width, currentHeight)
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

      local pink = { 201 / 255, 135 / 255, 155 / 255 }
      local yellow = { 239 / 255, 219 / 255, 145 / 255 }
      local green = { 192 / 255, 212 / 255, 171 / 255 }

      local colors = { pink, yellow, green }
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
      end
   end
   local tabWidthMultipliers = { 0.85, 1.05, 1.10 }

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

      playSound(scrollItemClickSample)
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

   if draw then
      if selectedRootButton == 'head' then
         love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], 1)
      else
         love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], .8)
      end
      love.graphics.rectangle('fill', margin, topY, size, buttonHeight)
      love.graphics.setColor(0, 0, 0)
      love.graphics.print('head', margin, topY)


      if selectedRootButton == 'body' then
         love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], 1)
      else
         love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], .8)
      end

      love.graphics.rectangle('fill', margin, (h / 2), size, buttonHeight)
      love.graphics.setColor(0, 0, 0)
      love.graphics.print('body', margin, (h / 2))
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

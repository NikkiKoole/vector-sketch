-- this is the panel that contains all ui for changing a certain body part or general change
-- for each category we have a optionally unique panel

local hit = require 'lib.hit'
local canvas = require 'lib.canvas'
local mesh = require 'lib.mesh'
local ui = require 'lib.ui'



function partSettingsPanel()
   partSettingsSurroundings()
   partSettingsScrollable()
end

function partSettingsSurroundings()
   -- this thing will render the panel where the big scrollable area is in
   -- also the tabs on top and the sliders/other settngs in the header.
   --   basically everything except the scrollable thing itself..
   local w, h = love.graphics.getDimensions()

   local margin = (h / 16)
   local width = (w / 3)
   local height = (h - margin * 2)
   local beginX = 0
   local beginY = 0
   local startX = beginX + w - width - margin
   local startY = beginY + margin
   -- main panel
   love.graphics.setColor(0, 0, 0)
   love.graphics.rectangle('line', startX, startY, width, height)

   -- top tabs (part, bg, fg, line)
   local tabs = { 'part', 'bg', 'fg', 'pattern', 'line' }
   local tabWidth = (width / #tabs)
   local tabHeight = math.max((tabWidth / 1.5), 32)
   local marginBetweenTabs = tabWidth / 16
   for i = 1, #tabs do
      love.graphics.rectangle('line', startX + (i - 1) * tabWidth, startY, tabWidth - marginBetweenTabs, tabHeight)
      love.graphics.print(tabs[i], startX + (i - 1) * tabWidth, startY)
   end

   -- top header for custom sliders etc.
   local minimumHeight = 132
   local currentY = startY + tabHeight
   love.graphics.rectangle('line', startX, currentY, width, minimumHeight)
   love.graphics.print('ruimte voor sliders', startX + 6, currentY + 6)


end

function partSettingsScrollable(draw, clickX, clickY)
   local w, h = love.graphics.getDimensions()
   local margin = (h / 16)
   local width = (w / 3)
   local height = (h - margin * 2)
   local margin = (h / 16)
   local beginX = 0
   local beginY = 0
   local startX = beginX + w - width - margin
   local tabs = { 'part', 'bg', 'fg', 'pattern', 'line' }
   local tabWidth = (width / #tabs)
   local tabHeight = math.max((tabWidth / 1.5), 32)
   local minimumHeight = 132
   local startY = beginY + margin
   local currentY = startY + tabHeight

   -- now the scrolling part.
   -- this has optional scrolling, optional round scrolling or bounds, parameter amount of columns

   local amount = 48
   local columns = 3
   local rows = math.ceil(amount / columns)
   local cellMargin = width / 48
   local useWidth = width - (2 * cellMargin) - (columns - 1) * cellMargin
   local cellWidth = (useWidth / columns)
   local cellHeight = cellWidth
   local currentX = startX + cellMargin
   currentY = currentY + minimumHeight + cellMargin

   -- todo weird use of a 'global'
   -- the 5th is the cellsize/rowheight
   settingsScrollArea = { startX, currentY - cellMargin, width, height - minimumHeight - tabHeight,
      (cellHeight + cellMargin) }
   love.graphics.setScissor(settingsScrollArea[1], settingsScrollArea[2], settingsScrollArea[3], settingsScrollArea[4])

   local rowsInPanel = math.ceil((height - minimumHeight - tabHeight) / (cellHeight + cellMargin))
   local endlesssScroll = true

   if rowsInPanel >= rows then
      for j = -1, rows - 1 do
         for i = 1, columns do
            local newScroll = j --+ offset
            local yPosition = currentY + (newScroll * (cellHeight + cellMargin))
            local index = math.ceil(0) + j

            if (index >= 0 and index <= rows - 1) then
               local value = ((index % rows) * columns) + i
               love.graphics.rectangle('line',
                  currentX + (i - 1) * (cellWidth + cellMargin),
                  yPosition,
                  cellWidth, cellHeight
               )
               love.graphics.print(value,
                  currentX + (i - 1) * (cellWidth + cellMargin),
                  yPosition
               )
            end
         end
      end

   else


      local offset = settingsScrollPosition % 1
      if endlesssScroll == true then
         for j = -1, rowsInPanel - 1 do
            for i = 1, columns do
               local newScroll = j + offset
               local yPosition = currentY + (newScroll * (cellHeight + cellMargin)) --(cellHeight + cellMargin) * (j - 1)
               local index = math.ceil(-settingsScrollPosition) + j

               local value = ((index % rows) * columns) + i
               love.graphics.rectangle('line',
                  currentX + (i - 1) * (cellWidth + cellMargin),
                  yPosition,
                  cellWidth, cellHeight
               )
               love.graphics.print(value,
                  currentX + (i - 1) * (cellWidth + cellMargin),
                  yPosition
               )
            end
         end
      else


         local mx = (
             ((rows * (cellHeight + (cellMargin))) - (height - minimumHeight - tabHeight - cellMargin)) /
                 (cellHeight + cellMargin))

         --h ere i'm saving the min and max for scrolling behaviour, so i can use those in love.update
         settingsScrollArea[6] = 0
         settingsScrollArea[7] = -mx

         for j = -1, rows - 1 do
            for i = 1, columns do
               local newScroll = j + offset
               local yPosition = currentY + (newScroll * (cellHeight + cellMargin))
               local index = math.ceil(-settingsScrollPosition) + j

               if (index >= 0 and index <= rows - 1) then
                  local value = ((index % rows) * columns) + i
                  love.graphics.rectangle('line',
                     currentX + (i - 1) * (cellWidth + cellMargin),
                     yPosition,
                     cellWidth, cellHeight
                  )
                  love.graphics.print(value,
                     currentX + (i - 1) * (cellWidth + cellMargin),
                     yPosition
                  )
               end
            end
         end
      end

   end

   love.graphics.setScissor()

   if false then
      local dotWidth = useWidth / 5
      local dotHeight = (height - minimumHeight - tabHeight) / 8
      for i = 1, #palettes do

         local index = (i % #dots) + 1
         local dot = dots[index]
         local j = i - 1
         local w, h = dot:getDimensions()
         local sx = dotWidth / w
         local sy = dotWidth / h

         love.graphics.setColor(0, 0, 0, .1)
         love.graphics.draw(dot, -2 + currentX + (j % 5) * dotWidth, -2 + currentY + math.floor(j / 5) * dotWidth, 0,
            sx * 1.1, sy * 1.1)


         love.graphics.setColor(palettes[i])
         love.graphics.draw(dot, currentX + (j % 5) * dotWidth, currentY + math.floor(j / 5) * dotWidth, 0, sx, sy)
      end
   end

end

-- scroll list is the main thing that has all categories
function scrollList(draw, clickX, clickY)

   local w, h = love.graphics.getDimensions()
   local margin = 20

   local marginHeight = 2
   local size = (h / scrollItemsOnScreen) - marginHeight * 2

   local elements = { 'voeten ', 'benen', 'romp', 'armen', 'handen', 'nek', 'hoofd', 'neus', 'ogen', 'oren',
      'hoofdhaar' }

   local offset = scrollPosition % 1

   for i = -1, (scrollItemsOnScreen - 1) do

      local newScroll = i + offset
      local yPosition = marginHeight + (newScroll * (h / scrollItemsOnScreen))

      local index = math.ceil(-scrollPosition) + i
      index = (index % #elements) + 1
      if index < 1 then index = index + #elements end
      if index > #elements then index = 1 end

      local whiterectIndex = math.ceil(-scrollPosition) + i
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
         love.graphics.print(elements[index], 20, yPosition)
      else
         if (hit.pointInRect(clickX, clickY, 20, yPosition, size, size)) then
            print('clicked', elements[index])
            playSound(scrollItemClickSample)
         end
      end
   end
end

function drawCirclesAroundCenterCircle(cx, cy, label, buttonRadius, r, smallButtonRadius)
   love.graphics.circle('line', cx, cy, buttonRadius)
   love.graphics.print(label, cx, cy)

   local other = { 'hair', 'headshape', 'eyes', 'ears', 'nose', 'mouth', 'chin' }
   local angleStep = (180 / (#other - 1))
   local angle = -90
   for i = 1, #other do

      local px = cx + r * math.cos(angle * math.pi / 180)
      local py = cy + r * math.sin(angle * math.pi / 180)
      angle = angle + angleStep
      love.graphics.circle('line', px, py, smallButtonRadius)
   end
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

--local res = { clicked = false }

function bigButtonWithSmallAroundIt(x, y, textureOrColors)
   prof.push('big-bitton-small-around')
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
         prof.push('render-masked-texture')
         canvas.renderMaskedTexture(blup2, textureOrColors[i], new_x + xOffset, new_y + yOffset, scale, scale)
         prof.pop('render-masked-texture')
      end

      local b = ui.getUICircle(new_x, new_y, 30)
      if (i == 2) then second = b end
      if (i == 3) then third = b end
      if (i == 4) then fourth = b end
      if (i == 5) then fifth = b end
      rad = rad + step
   end
   prof.pop('big-bitton-small-around')
   return first, second, third, fourth, fifth

end

function buttonHelper(button, bodyPart, param, maxAmount, func, firstParam)
   if button then
      values[bodyPart][param] = values[bodyPart][param] + 1
      if values[bodyPart][param] > maxAmount then
         values[bodyPart][param] = 1
      end
      func(firstParam, values)
   end
end

function bigButtonHelper(x, y, param, imgArray, changeFunc, redoFunc, firstParam)
   shapeButton, BGButton, FGTexButton, FGButton, LinePalButton = bigButtonWithSmallAroundIt(
      x, y, {
      imgArray[values[param].shape],
      palettes[values[param].bgPal],
      textures[values[param].fgTex],
      palettes[values[param].fgPal],
      palettes[values[param].linePal]
   }
   )

   -- todo maybe parametrize palettes and textures?
   buttonHelper(shapeButton, param, 'shape', #imgArray, changeFunc, firstParam)
   buttonHelper(BGButton, param, 'bgPal', #palettes, redoFunc, firstParam)
   buttonHelper(FGTexButton, param, 'fgTex', #textures, redoFunc, firstParam)
   buttonHelper(FGButton, param, 'fgPal', #palettes, redoFunc, firstParam)
   buttonHelper(LinePalButton, param, 'linePal', #palettes, redoFunc, firstParam)
end

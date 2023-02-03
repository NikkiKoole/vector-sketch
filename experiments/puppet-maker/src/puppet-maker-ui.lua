-- this is the panel that contains all ui for changing a certain body part or general change
-- for each category we have a optionally unique panel

local hit = require 'lib.hit'
function partSettingsPanel()
   local w, h = love.graphics.getDimensions()

   local margin = (h / 16)
   local width = (w / 3)
   local height = (h - margin * 2)
   local startX = w - width - margin
   local startY = margin

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
   local minimumHeight = 32
   local currentY = startY + tabHeight
   love.graphics.rectangle('line', startX, currentY, width, minimumHeight)
   love.graphics.print('ruimte voor sliders', startX + 6, currentY + 6)

   -- now the scrolling part.
   -- this has optional scrolling, optional round scrolling or bounds, parameter amount of columns

   local amount = 60
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
   local endlesssScroll = false


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

         -- also make a case for when you dont need to scroll at all (rowsInPanel >= rows)

         -- if we need to scroll we do this.
         if (settingsScrollPosition > 0) then
            settingsScrollPosition = 0
         end

         local mx = (
             ((rows * (cellHeight + (cellMargin))) - (height - minimumHeight - tabHeight - cellMargin)) /
                 (cellHeight + cellMargin))
         if (settingsScrollPosition < -mx) then
            settingsScrollPosition = -mx
         end

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
            playSound(scrollItemClickSample)
         end
      end
   end
end

-- this is the panel that contains all ui for changing a certain body part or general change
-- for each category we have a optionally unique panel

local hit = require 'lib.hit'
local canvas = require 'lib.canvas'
local mesh = require 'lib.mesh'
local ui = require 'lib.ui'



imageCache = {} -- tjo save all the parts inages in

local function findPart(name)

   for i = 1, #parts do
      if parts[i].name == name then
         return parts[i]
      end
   end
end




local tabs = { 'part', 'colors', 'pattern' }

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

function partSettingsSurroundings(draw, clickX, clickY)
   -- this thing will render the panel where the big scrollable area is in
   -- also the tabs on top and the sliders/other settngs in the header.
   --   basically everything except the scrollable thing itself..

   local startX, startY, width, height = partSettingsPanelDimensions()

   local tabWidth, tabHeight, marginBetweenTabs = partSettingsTabsDimensions(tabs, width)
   local minimumHeight = 132
   local currentY = startY + tabHeight

   if draw then
      -- main panel
      love.graphics.setColor(0, 0, 0)
      love.graphics.rectangle('line', startX, startY, width, height)

      --local wr = whiterects[5]
      --local wrw, wrh = wr:getDimensions()
      --local scaleX = width / wrw
      --local scaleY = height / wrh
      --love.graphics.setColor(0, 0, 0)
      love.graphics.setColor(255 / 255, 240 / 255, 200 / 255)
      love.graphics.rectangle('fill', startX, startY, width, height)
      love.graphics.setColor(0, 0, 0)

   end
   for i = 1, #tabs do
      local x = startX + (i - 1) * tabWidth
      local y = startY
      local w1 = tabWidth - marginBetweenTabs
      local h1 = tabHeight

      if draw then
         love.graphics.rectangle('line', x, y, w1, h1)
         if (selectedTab == tabs[i]) then
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle('fill', x, y, w1, h1)
            love.graphics.setColor(0, 0, 0)
         end
         love.graphics.print(tabs[i], x, y)
      else
         if (hit.pointInRect(clickX, clickY, x, y, w1, h1)) then
            print('clicked', tabs[i])
            selectedTab = tabs[i]
            playSound(scrollItemClickSample)
         end
      end
   end

   if draw then
      love.graphics.rectangle('line', startX, currentY, width, minimumHeight)
      love.graphics.print('ruimte voor sliders', startX + 6, currentY + 6)
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

function renderElement(type, value, container, x, y, w, h)
   if (type == 'test') then
      love.graphics.rectangle('line', x, y, w, h)
      love.graphics.print(value, x, y)
   end
   if (type == 'dot') then
      if (value <= #container) then
         local dotindex = (value % #dots) + 1
         local dot = dots[dotindex]
         local scale, xoff, yoff = getScaleAndOffsetsForImage(dot, w, h)

         love.graphics.setColor(0, 0, 0, .1)
         love.graphics.rectangle('line', x, y, w, h)
         love.graphics.draw(dot, -2 + x + (xoff + w / 2), -2 + y + (yoff + h / 2), 0, scale, scale)

         love.graphics.setColor(container[value])
         love.graphics.draw(dot, x + (xoff + w / 2), y + (yoff + h / 2), 0, scale, scale)
      end
   end
   if (type == 'img') then
      if (value <= #container) then
         local dotindex = (value % #container) + 1
         local url = container[dotindex]
         
         local dot = imageCache[url] or love.graphics.newImage(url)
         imageCache[url] = dot
         local scale, xoff, yoff = getScaleAndOffsetsForImage(dot, w, h)


         love.graphics.setColor(0, 0, 0, .1)
         love.graphics.rectangle('line', x, y, w, h)
         love.graphics.draw(dot, -2 + x + (xoff + w / 2), -2 + y + (yoff + h / 2), 0, scale, scale, 0, 0)


         love.graphics.setColor(0, 0, 0, 1)
         love.graphics.draw(dot, x + (xoff + w / 2), y + (yoff + h / 2), 0, scale, scale, 0, 0)
         love.graphics.print(value, x, y)
      end
   end
   if (type == 'texture') then
      if (value <= #container) then
         local dotindex = (value % #container) + 1
         local dot = container[dotindex]
         local scale, xoff, yoff = getScaleAndOffsetsForImage(dot, w, h)

         love.graphics.setColor(0, 0, 0, .1)
         love.graphics.rectangle('line', x, y, w, h)
         love.graphics.draw(dot, -2 + x + (xoff + w / 2), -2 + y + (yoff + h / 2), 0, scale, scale, 0, 0)


         love.graphics.setColor(0, 0, 0, 1)
         love.graphics.draw(dot, x + (xoff + w / 2), y + (yoff + h / 2), 0, scale, scale, 0, 0)
         love.graphics.print(value, x, y)
      end
   end
end

function partSettingsScrollable(draw, clickX, clickY)


   local startX, startY, width, height = partSettingsPanelDimensions()

   --local tabs = { 'part', 'bg', 'fg', 'pattern', 'line' }
   local tabWidth, tabHeight, marginBetweenTabs = partSettingsTabsDimensions(tabs, width)
   local minimumHeight = 132
   local currentY = startY + tabHeight


   local amount = #palettes
   local renderType = 'dot'
   local renderContainer = palettes

   local columns = 3

   if selectedTab == 'fg' or selectedTab == 'bg' or selectedTab == 'line' or selectedTab == 'colors' then
      amount = #palettes
      renderType = 'dot'
      columns = 5
      renderContainer = palettes
   end
   if selectedTab == 'part' then
      local p = findPart(selectedCategory)
      --print(inspect(p))
      amount = #p.imgs
      renderType = 'img'
      renderContainer = p.imgs
   end
   if selectedTab == 'pattern' then
      amount = #textures
      renderType = 'texture'
      renderContainer = textures
   end



   local rows, cellWidth, cellMargin, cellSize = partSettingCellDimensions(amount, columns, width)
   local cellHeight = cellWidth
   local currentX = startX + cellMargin
   currentY = currentY + minimumHeight + cellMargin
   local scrollAreaHeight = (height - minimumHeight - tabHeight)

   -- todo weird use of a 'global'
   -- the 5th is the cellsize/rowheight
   settingsScrollArea = { startX, currentY - cellMargin, width, scrollAreaHeight,
      (cellSize) }
   love.graphics.setScissor(settingsScrollArea[1], settingsScrollArea[2], settingsScrollArea[3], settingsScrollArea[4])

   local rowsInPanel = math.ceil((scrollAreaHeight - cellMargin) / (cellSize))
   local endlesssScroll = true



   if rowsInPanel > rows then
      for j = -1, rows - 1 do
         for i = 1, columns do
            local newScroll = j --+ offset
            local yPosition = currentY + (newScroll * (cellSize))
            local index = math.ceil(0) + j

            if (index >= 0 and index <= rows - 1) then
               local value = ((index % rows) * columns) + i
               renderElement(renderType, value, renderContainer, currentX + (i - 1) * (cellSize), yPosition, cellWidth,
                  cellHeight)
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
               local index = math.ceil(-settingsScrollPosition) + j
               local value = ((index % rows) * columns) + i
               renderElement(renderType, value, renderContainer, currentX + (i - 1) * (cellSize), yPosition, cellWidth,
                  cellHeight)

            end
         end
      else

         local mx = (
             ((rows * (cellHeight + (cellMargin))) - (scrollAreaHeight - cellMargin)) /
                 (cellSize))

         --h ere i'm saving the min and max for scrolling behaviour, so i can use those in love.update
         settingsScrollArea[6] = 0
         settingsScrollArea[7] = -mx

         for j = -1, rows - 1 do
            for i = 1, columns do
               local newScroll = j + offset
               local yPosition = currentY + (newScroll * (cellSize))
               local index = math.ceil(-settingsScrollPosition) + j

               if (index >= 0 and index <= rows - 1) then
                  local value = ((index % rows) * columns) + i
                  renderElement(renderType, value, renderContainer, currentX + (i - 1) * (cellSize), yPosition, cellWidth
                     , cellHeight)
               end
            end
         end
      end

   end

   love.graphics.setScissor()

end

-- scroll list is the main thing that has all categories
function scrollList(draw, clickX, clickY)

   local w, h = love.graphics.getDimensions()
   local margin = 20

   local marginHeight = 2
   local size = (h / scrollItemsOnScreen) - marginHeight * 2


   local offset = scrollPosition % 1

   for i = -1, (scrollItemsOnScreen - 1) do

      local newScroll = i + offset
      local yPosition = marginHeight + (newScroll * (h / scrollItemsOnScreen))

      local index = math.ceil(-scrollPosition) + i
      index = (index % #categories) + 1
      if index < 1 then index = index + #categories end
      if index > #categories then index = 1 end

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
         love.graphics.print(categories[index], 20, yPosition)
      else
         if (hit.pointInRect(clickX, clickY, 20, yPosition, size, size)) then
            print('clicked', categories[index])
            selectedCategory = categories[index]
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

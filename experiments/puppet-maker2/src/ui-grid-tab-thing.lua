local hit    = require 'lib.hit'

local pink   = { 201 / 255, 135 / 255, 155 / 255 }
local yellow = { 239 / 255, 219 / 255, 145 / 255 }
local green  = { 192 / 255, 212 / 255, 171 / 255 }
local colors = { pink, yellow, green }
local tabs   = { "part", "colors", "pattern" }

imageCache   = {} -- tjo save all the parts inages in

local text   = require 'lib.text'

local function getPNGMaskUrl(url)
    return text.replace(url, '.png', '-mask.png')
end
function drawChildPicker(draw, startX, currentY, width, clickX, clickY)
    local childrenTabHeight = 0

    local p = findPart(uiState.selectedCategory)
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
                local sx, sy = createFittingScale(ui2.whiterects[1], childrenTabHeight, childrenTabHeight)

                love.graphics.setColor(0, 0, 0, 0.1)
                love.graphics.draw(ui2.whiterects[1], xPosition + 2, yPosition + 2, 0, sx, sy)
                love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], 1)
                love.graphics.draw(ui2.whiterects[1], xPosition, yPosition, 0, sx, sy)

                if selectedChildCategory == p.children[i] then
                    love.graphics.setColor(0, 0, 0, .8)
                    local sx, sy = createFittingScale(ui2.rects[1], childrenTabHeight, childrenTabHeight)
                    love.graphics.draw(ui2.rects[1], xPosition, yPosition, 0, sx, sy)
                end

                sx, sy = createFittingScale(ui2.scrollIcons[p.children[i]], childrenTabHeight, childrenTabHeight)

                setSecondaryColor(1)
                love.graphics.draw(ui2.scrollIcons[p.children[i] .. 'Mask'], xPosition, yPosition, 0, sx, sy)
                love.graphics.setColor(0, 0, 0, .8)
                love.graphics.draw(ui2.scrollIcons[p.children[i]], xPosition, yPosition, 0, sx, sy)
            else
                -- todo this isnt working because the scrollarea is not correct so this will only be called whne i click in the scrollarea
                -- print(clickX, clickY,  xPosition, yPosition, childrenTabHeight, childrenTabHeight)
                if (hit.pointInRect(clickX, clickY, xPosition, yPosition, childrenTabHeight, childrenTabHeight)) then
                    selectedChildCategory = p.children[i]
                    playSound(uiClickSound)
                end
            end
        end
    end
    return childrenTabHeight * 1.2
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

        local scaleX = width / iw
        local scaleY = height / ih

        local uiOffX = 18 * scaleX
        local uiOffY = 40 * scaleY

        local drawunder = { { 2, 3, 1 }, { 1, 3, 2 }, { 1, 2, 3 } }

        local selectedTabIndex = -1
        for i = 1, #tabs do
            if uiState.selectedTab == tabs[i] then
                selectedTabIndex = i
            end
        end

        for i = 1, #drawunder[selectedTabIndex] do
            local index = drawunder[selectedTabIndex][i]
            love.graphics.setColor(colors[index][1], colors[index][2], colors[index][3], 1)
            love.graphics.draw(ui2.tabuimask[index], startX - uiOffX, startY - uiOffY, 0, scaleX, scaleY)
            love.graphics.setColor(0, 0, 0)
            love.graphics.draw(ui2.tabui[index], startX - uiOffX, startY - uiOffY, 0, scaleX, scaleY)

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

                local sx, sy = createFittingScale(ui2.tabuilogo[index], w1 * 0.9, h1 * 0.9)
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
                love.graphics.draw(ui2.tabuilogo[index], x + w1 * 0.05, startY + h1 * 0.05, 0, sx, sy)
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

        local y = startY
        local w1 = (tabWidth * tabWidthMultipliers[i]) - marginBetweenTabs
        local h1 = tabHeight

        if draw then

        else
            if (hit.pointInRect(clickX, clickY, x, y, w1, h1)) then
                uiState.selectedTab = tabs[i]
                playSound(uiClickSound)
            end
        end
    end

    local minimumHeight = 100 --drawImmediateSlidersEtc(false, startX, currentY, width, uiState.selectedCategory)
    currentY = currentY + minimumHeight
    drawChildPicker(draw, startX, currentY, width, clickX, clickY)

    if findPart(uiState.selectedCategory).children then
        local minimumHeight = 100 --drawImmediateSlidersEtc(false, startX, currentY, width, selectedChildCategory)
        currentY = currentY + minimumHeight
    end
end

function drawTapesForBackground(x, y, w, h)
    local ratio = h / w
    local index = ratio < 0.3 and 1 or 2

    local sx, sy = createFittingScale(ui2.uiheaders[index], w, h)
    love.graphics.setColor(1, 1, 1, .4)

    love.graphics.draw(ui2.uiheaders[index], x, y, 0, sx, sy, 0, 0)
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
            local dotindex = (value % #ui2.dots)

            local pickedBG = editingGuy.values[category].bgPal == value
            local pickedFG = editingGuy.values[category].fgPal == value
            local pickedLP = editingGuy.values[category].linePal == value
            if dotindex == 0 then
                dotindex = #ui2.dots
            end

            local dot = ui2.dots[dotindex]

            if pickedBG or pickedFG or pickedLP then
                local scale, xoff, yoff = getScaleAndOffsetsForImage(dot, w * 1.5, h * 1.5)
                local offset = (0.1 * scale * w) / 2

                love.graphics.setColor(container[value])
                love.graphics.draw(dot, x + (xoff + w / 2), y + (yoff + h / 2), 0, scale, scale)
                love.graphics.setColor(0, 0, 0, .99)
                local sx, sy = createFittingScale(ui2.circles[1], w * 1.5, h * 1.5)
                love.graphics.draw(ui2.circles[1], x + (xoff + w / 2), y + (yoff + h / 2), 0, sx, sy)
            else
                local scale, xoff, yoff = getScaleAndOffsetsForImage(dot, w, h)
                love.graphics.setColor(container[value])
                love.graphics.draw(dot, x + (xoff + w / 2), y + (yoff + h / 2), 0, scale, scale)
            end
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
            local picked = false --editingGuy.values[category].shape == dotindex
            if picked then
                scale = scale + (math.sin(love.timer.getTime() * 5) * (scale / 20))
            end

            if info then
                print('joj!')
                local mask = imageCache[maskUrl] or love.graphics.newImage(maskUrl)
                imageCache[maskUrl] = mask

                love.graphics.setBlendMode('subtract')
                local pal = { 0, 1, 1 } --(palettes[editingGuy.values[category].bgPal])

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

            local circleindex = (value % #ui2.circles) + 1
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

            local scale, xoff, yoff = getScaleAndOffsetsForImage(ui2.circles[circleindex], w * 1.2, h * 1.2)
            love.graphics.setColor(lpal[1], lpal[2], lpal[3], 1)
            if picked then
                scale = scale + (math.sin(love.timer.getTime() * 5) * (scale / 20))
            end
            love.graphics.draw(ui2.circles[circleindex], x + (xoff + w / 2), y + (yoff + h / 2), 0, scale,
                scale)
        end
    end
end

local function buttonClickHelper(category, value)
    local values = editingGuy.values
    local f = findPart(category)

    if uiState.selectedTab == 'part' then
        values[category]['shape'] = value
        changePart(category)

        if (f.kind == 'body') then
            tweenCameraToHeadAndBody()
        else
            tweenCameraToHead()
        end

        growl(1 + love.math.random() * 2)
    end
    if uiState.selectedTab == 'colors' then
        values[category][uiState.selectedColoringLayer] = value
        changePart(category)
        playSound(uiClickSound)
    end

    if uiState.selectedTab == 'pattern' then
        values[category]['fgTex'] = value
        changePart(category)
        playSound(uiClickSound)
    end
end



function childPickerDimensions(width)
    local p = findPart(uiState.selectedCategory)
    local childrenTabHeight = 0
    if p.children then
        childrenTabHeight = width / 5
    end
    return childrenTabHeight * 1.2
end

function partSettingsScrollable(draw, clickX, clickY)
    local startX, startY, width, height = partSettingsPanelDimensions()
    local tabWidth, tabHeight, marginBetweenTabs = partSettingsTabsDimensions(tabs, width)
    local currentY = startY + tabHeight
    local amount = #palettes
    local renderType = "dot"
    local renderContainer = palettes
    local columns = 3
    local category = uiState.selectedCategory
    local p = findPart(uiState.selectedCategory)

    if p.children then
        p = findPart(selectedChildCategory)
        category = selectedChildCategory
    end

    if uiState.selectedTab == "fg" or uiState.selectedTab == "bg" or uiState.selectedTab == "line" or uiState.selectedTab == "colors" then
        amount = #palettes
        renderType = "dot"
        columns = 5
        renderContainer = palettes
    end

    if uiState.selectedTab == "part" then
        amount = p.imgs and #p.imgs or 0
        renderType = "img"
        renderContainer = p.imgs
    end

    if uiState.selectedTab == "pattern" then
        amount = #textures
        renderType = "texture"
        renderContainer = textures
    end

    local rows, cellWidth, cellMargin, cellSize = partSettingCellDimensions(amount, columns, width)
    local cellHeight = cellWidth
    local currentX = startX + cellMargin
    local extraOffsetToTapes = tabHeight / 5
    local minimumHeight = 100 -- drawImmediateSlidersEtc(draw, startX, currentY, width, uiState.selectedCategory)
    local otherHeight = 0
    local childrenTabHeight = childPickerDimensions(width) --drawChildPicker(draw, startX, currentY , width, clickX, clickY)

    if findPart(uiState.selectedCategory).children then
        currentY = currentY + childrenTabHeight
        otherHeight = 100 --drawImmediateSlidersEtc(draw, startX, currentY, width, selectedChildCategory)
        currentY = currentY + otherHeight
    end

    currentY = currentY + minimumHeight + cellMargin
    local scrollAreaHeight = (height - minimumHeight - otherHeight - tabHeight - childrenTabHeight)

    grid.data = {
        x = startX,
        y = currentY - cellMargin,
        w = width,
        h = scrollAreaHeight,
        cellsize = cellSize,
    }

    if draw then
        love.graphics.setScissor(grid.data.x, grid.data.y, grid.data.w, grid.data.h)
    end

    local rowsInPanel = math.ceil((scrollAreaHeight - cellMargin) / (cellSize))
    local endlesssScroll = true

    renderFunc = function(xPosition, yPosition, value)
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
    end

    if rowsInPanel > rows then
        grid.data.noScroll = true
        for j = -1, rows - 1 do
            for i = 1, columns do
                local newScroll = j --+ offset
                local yPosition = currentY + (newScroll * (cellSize))
                local xPosition = currentX + (i - 1) * (cellSize)
                local index = math.ceil(0) + j

                if (index >= 0 and index <= rows - 1) then
                    local value = ((index % rows) * columns) + i

                    if true or renderContainer[value] ~= 'assets/parts/null.png' then
                        if draw then
                            renderFunc(xPosition, yPosition, value)
                        else
                            if (hit.pointInRect(clickX, clickY, xPosition, yPosition, cellWidth, cellHeight)) then
                                if value <= #renderContainer then buttonClickHelper(category, value) end
                            end
                        end
                    end
                end
            end
        end
    else
        local offset = grid.position % 1
        if endlesssScroll == true then
            for j = -1, rowsInPanel - 1 do
                for i = 1, columns do
                    local newScroll = j + offset
                    local yPosition = currentY + (newScroll * (cellSize))
                    local xPosition = currentX + (i - 1) * (cellSize)
                    local index = math.ceil( -grid.position) + j
                    local value = ((index % rows) * columns) + i
                    --print(inspect(renderContainer[value]))
                    if true or renderContainer[value] ~= 'assets/parts/null.png' then
                        if draw then
                            renderFunc(xPosition, yPosition, value)
                        else
                            if (hit.pointInRect(clickX, clickY, xPosition, yPosition, cellWidth, cellHeight)) then
                                if value <= #renderContainer then buttonClickHelper(category, value) end
                            end
                        end
                    end
                end
            end
        else
            local mx = (((rows * (cellHeight + (cellMargin))) - (scrollAreaHeight - cellMargin)) / (cellSize))

            grid.data.min = 0
            grid.data.max = -mx

            for j = -1, rows - 1 do
                for i = 1, columns do
                    local newScroll = j + offset
                    local yPosition = currentY + (newScroll * (cellSize))
                    local xPosition = currentX + (i - 1) * (cellSize)
                    local index = math.ceil( -grid.position) + j

                    if (index >= 0 and index <= rows - 1) then
                        local value = ((index % rows) * columns) + i
                        if true or renderContainer[value] ~= 'assets/parts/null.png' then
                            if draw then
                                renderFunc(xPosition, yPosition, value)
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
    end

    if draw then
        love.graphics.setScissor()
    end
end

function tabbedGridScroller()
    partSettingsSurroundings(true)
    partSettingsScrollable(true)
end

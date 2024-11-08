-- main.lua
package.path = package.path .. ";../../?.lua"
local ui = require 'whisper-ui' -- Assuming 'ui.lua' is in the same directory

-- Initialize Love2D
function love.load()
    -- Load and set the font
    font = love.graphics.newFont('cooper_bold_bt.ttf', 32)
    love.graphics.setFont(font)

    -- Initialize UI
    ui.init()

    -- Initialize variables
    add_shape_opened = false
    add_joint_opened = false

    value = 50
    checked = true
    settingsSlider = 44
    settingsSlider2 = 9.8
    settingsSlider3 = 56
    settingsCheck = true
    sharedValue = 50
    text = ''
end

-- Update function
function love.update(dt)
    -- Reserved for future UI updates
end

-- Draw UI and Handle Interactions
function love.draw()
    ui.startFrame() -- Start a new UI frame

    -- "Add Shape" Button
    local addShapeClicked, _ = ui.button(10, 10, 200, 'add shape')
    if addShapeClicked then
        add_shape_opened = not add_shape_opened
    end

    if add_shape_opened then
        local types = { 'rectangle', 'circle', 'chain', 'edge', 'polygon' }

        local titleHeight = font:getHeight() + 10
        local startX = 10
        local startY = 60
        local panelWidth = 200
        local buttonSpacing = 10
        local buttonHeight = ui.theme.button.height
        local panelHeight = titleHeight + (#types * (buttonHeight + buttonSpacing)) + buttonSpacing

        ui.panel(startX, startY, panelWidth, panelHeight, 'drag »', function()
            local layout = ui.createLayout({
                type = 'columns',
                spacing = buttonSpacing,
                startX = startX + 10,
                startY = startY + titleHeight + 10
            })
            for i = 1, #types do
                local width = panelWidth - 20
                local height = buttonHeight
                local x, y = ui.nextLayoutPosition(layout, width, height)
                local spawnClicked, spawnPressed, spawnReleased = ui.button(x, y, width, types[i])
                if spawnClicked then
                    print('Hello ' .. types[i] .. ' is clicked! Now I say World!')
                end
                if spawnPressed then
                    -- Track which element is being dragged
                    ui.draggingActive = ui.activeElementID
                    print('Hello ' .. types[i] .. ' is pressed! Now I say World!')
                end
                if spawnReleased then
                    ui.draggingActive = nil
                    print('Hello ' .. types[i] .. ' is released! Now I say World!')
                end
            end
        end)
    end

    -- "Add Joint" Button
    local addJointClicked, _ = ui.button(220, 10, 200, 'add joint')
    if addJointClicked then
        add_joint_opened = not add_joint_opened
    end

    if add_joint_opened then
        local types = { 'distance', 'friction', 'gear', 'mouse', 'prismatic', 'pulley', 'revolute', 'rope', 'weld',
            'motor', 'wheel' }

        local titleHeight = font:getHeight() + 10
        local startX = 220
        local startY = 60
        local panelWidth = 200
        local buttonSpacing = 10
        local buttonHeight = ui.theme.button.height
        local panelHeight = titleHeight + (#types * (buttonHeight + buttonSpacing)) + buttonSpacing

        ui.panel(startX, startY, panelWidth, panelHeight, 'drag »', function()
            local layout = ui.createLayout({
                type = 'columns',
                spacing = buttonSpacing,
                startX = startX + 10,
                startY = startY + titleHeight + 10
            })
            for i = 1, #types do
                local width = panelWidth - 20
                local height = buttonHeight
                local x, y = ui.nextLayoutPosition(layout, width, height)
                local spawnClicked, spawnPressed, spawnReleased = ui.button(x, y, width, types[i])
                if spawnClicked then
                    print('Hello ' .. types[i] .. ' is clicked! Now I say World!')
                end
                if spawnPressed then
                    -- Track which element is being dragged
                    ui.draggingActive = ui.activeElementID
                    print('Hello ' .. types[i] .. ' is pressed! Now I say World!')
                end
                if spawnReleased then
                    ui.draggingActive = nil
                    print('Hello ' .. types[i] .. ' is released! Now I say World!')
                end
            end
        end)
    end

    -- Example Label and Slider with Input
    ui.label(430, 180, 'gravity m/s²')
    local ab = ui.sliderWithInput(410, 230, 100, -10, 40, settingsSlider2)
    if ab then
        settingsSlider2 = ab
    end

    local t = ui.textinput(200, 200, 200, 200, 'poep', text)

    -- Render Dragged Element
    if ui.draggingActive then
        love.graphics.setColor(ui.theme.draggedElement.fill) -- Dragged element color
        local x, y = love.mouse.getPosition()
        love.graphics.circle('fill', x, y, 10)
        love.graphics.setColor(1, 1, 1) -- Reset color
    end
end

-- Handle text input globally and delegate to the focused TextInput
function love.textinput(t)
    ui.handleTextInput(t)
end

-- Handle key presses globally and delegate to the focused TextInput
function love.keypressed(key)
    ui.handleKeyPress(key)

    -- Exit the game when 'escape' key is pressed
    if key == 'escape' then
        love.event.quit()
    end
end

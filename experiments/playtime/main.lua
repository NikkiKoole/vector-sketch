-- main.lua
package.path = package.path .. ";../../?.lua"
inspect = require 'inspect'
local ui = require 'ui-all' -- Assuming 'ui.lua' is in the same directory

-- Initialize Love2D
function love.load()
    -- Load and set the font
    local font = love.graphics.newFont('cooper_bold_bt.ttf', 32)
    love.keyboard.setKeyRepeat(true)
    love.graphics.setFont(font)

    -- Initialize UI
    ui.init(font)

    -- Initialize variables
    add_shape_opened = false
    add_joint_opened = false
    world_settings_opened = false
    gravity = 9.81

    value = 50
    checked = true
    settingsSlider = 44

    settingsSlider3 = 56
    settingsCheck = true
    sharedValue = 50
    text = ''

    pickedoption = 'dynamic'
    gravityState = true
end

-- Update function
function love.update(dt)
    -- Reserved for future UI updates
end

-- Draw UI and Handle Interactions
function love.draw()
    local w, h = love.graphics.getDimensions()
    love.graphics.rectangle('line', 10, 10, w - 20, h - 20, 20, 20)

    ui.startFrame() -- Start a new UI frame

    -- "Add Shape" Button
    local addShapeClicked, _ = ui.button(20, 20, 200, 'add shape')
    if addShapeClicked then
        add_shape_opened = not add_shape_opened
    end

    if add_shape_opened then
        local types = { 'rectangle', 'circle', 'chain', 'edge', 'polygon' }
        local titleHeight = ui.font:getHeight() + 10
        local startX = 20
        local startY = 70
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
    local addJointClicked, _ = ui.button(230, 20, 200, 'add joint')
    if addJointClicked then
        add_joint_opened = not add_joint_opened
    end

    if add_joint_opened then
        local types = { 'distance', 'friction', 'gear', 'mouse', 'prismatic', 'pulley', 'revolute', 'rope', 'weld',
            'motor', 'wheel' }

        local titleHeight = ui.font:getHeight() + 10
        local startX = 230
        local startY = 70
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

    local worldSettingsClicked, _ = ui.button(440, 20, 300, 'world settings')
    if worldSettingsClicked then
        world_settings_opened = not world_settings_opened
    end
    if world_settings_opened then
        local startX = 440
        local startY = 70
        local panelWidth = 300
        local panelHeight = 400
        local buttonSpacing = 10
        local titleHeight = ui.font:getHeight() + 10

        ui.panel(startX, startY, panelWidth, panelHeight, '• ∫ƒF world •', function()
            local layout = ui.createLayout({
                type = 'columns',
                spacing = buttonSpacing,
                startX = startX + 10,
                startY = startY + titleHeight + 10
            })
            local width = panelWidth - 20

            local x, y = ui.nextLayoutPosition(layout, width, 50)
            ui.label(x, y, 'gravity m/s²')
            local clicked, checkstate = ui.checkbox(x + ui.font:getWidth('gravity m/s²') + 10, y, gravityState, '')
            if clicked then
                gravityState = checkstate
            end
            local x, y = ui.nextLayoutPosition(layout, width, 50)
            local grav = ui.sliderWithInput(x, y, 160, -10, 40, gravity)
            if grav then gravity = grav end
            local x, y = ui.nextLayoutPosition(layout, width, 50)
            local t = ui.textinput(x, y, 280, 200, 'poep', text)
        end)
    end

    if ui.draggingActive then
        love.graphics.setColor(ui.theme.draggedElement.fill) -- Dragged element color
        local x, y = love.mouse.getPosition()
        love.graphics.circle('fill', x, y, 10)
        love.graphics.setColor(1, 1, 1) -- Reset color
    end

    if false then
        local toggled, value = ui.toggleButton(30, 500, 200, 40, "Gravity On", "Gravity Off", gravityState)
        if toggled then
            gravityState = value
        end

        local options = { "dynamic", "static", "kinematic" }
        local dropd, dropPressed, dropReleased = ui.dropdown(100, 100, 200, options, pickedoption)
        if dropd then
            pickedoption = dropd
        end
        if dropPressed then
            -- Track which element is being dragged
            ui.draggingActive = ui.activeElementID
            print('Hello ' .. pickedoption .. ' is pressed! Now I say World!')
        end
        if dropReleased then
            ui.draggingActive = nil
            print('Hello ' .. pickedoption .. ' is released! Now I say World!')
        end
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

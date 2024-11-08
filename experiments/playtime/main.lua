-- main.lua
package.path = package.path .. ";../../?.lua"
local ui = require 'whisper-ui'

-- Initialize Love2D
function love.load()
    -- Load and set the font
    font = love.graphics.newFont('cooper_bold_bt.ttf', 32)
    love.graphics.setFont(font)

    -- Initialize UI
    ui.init()

    -- Initialize variables
    value = 50
    checked = true
    settingsSlider = 44
    settingsSlider2 = 48
    settingsSlider3 = 56
    settingsCheck = true
    sharedValue = 50
end

-- Update function (currently not used)
function love.update(dt)
    -- Reserved for future UI updates
end

-- Draw UI and Handle Interactions
function love.draw()
    ui.startFrame() -- Start a new UI frame

    -- Horizontal Slider
    local slide = ui.slider(50, 300, 200, ui.theme.slider.height, 'horizontal', 0, 100, value)
    if slide then
        value = slide
    end

    -- Checkbox
    local clicked, newChecked = ui.checkbox(100, 100, checked, 'Weird Stuff')
    if clicked then
        checked = newChecked
    end

    -- Vertical Slider
    local slideV = ui.slider(350, 100, 200, ui.theme.slider.height, 'vertical', 0, 100, value)
    if slideV then
        value = slideV
    end

    -- "Press Me" Button
    local buttonClicked, buttonPressed = ui.button(50, 50, 200, 'Press Me')
    if buttonClicked then
        print('Hello button is clicked! Now I say World!')
    end
    if buttonPressed then
        print('Hello button is pressed! Now I say World!')
    end

    -- "Spawn" Button
    local spawnClicked, spawnPressed, spawnReleased = ui.button(50, 150, 200, 'Spawn')
    if spawnClicked then
        print('Hello spawn is clicked! Now I say World!')
    end
    if spawnPressed then
        -- Track which element is being dragged
        ui.draggingActive = ui.activeElementID
        print('Hello spawn is pressed! Now I say World!')
    end
    if spawnReleased then
        ui.draggingActive = nil
        print('Hello spawn is released! Now I say World!')
    end

    -- Panel with UI elements inside it
    ui.panel(400, 50, 300, 450, "• Settings •", function()
        -- Example Checkbox inside the panel
        local panelClicked, panelChecked = ui.checkbox(410, 130, settingsCheck, 'Panel Checkbox')
        if panelClicked then
            settingsCheck = panelChecked
            print('Panel Checkbox toggled!')
        end

        -- Example Button inside the panel
        local panelButtonClicked, panelButtonPressed = ui.button(410, 370, 280, 'Panel Button')
        if panelButtonClicked then
            print('Panel Button clicked!')
        end
        if panelButtonPressed then
            print('Panel Button pressed!')
        end

        -- Sliders with Input inside the panel
        local aa = ui.sliderWithInput(410, 180, 100, 0, 100, settingsSlider)
        if aa then
            settingsSlider = aa
        end

        local ab = ui.sliderWithInput(410, 230, 100, -100, 100, settingsSlider2)
        if ab then
            settingsSlider2 = ab
        end

        local ac = ui.sliderWithInput(410, 280, 100, 0, 100, settingsSlider3)
        if ac then
            settingsSlider3 = ac
        end
    end)

    -- Example TextInput outside the panel (Non-numeric)
    local inputText = ui.textinput(50, 400, 200, 40, "Enter text...", "Initial Text", false)
    ui.label(50, 450, "You entered: " .. inputText)

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

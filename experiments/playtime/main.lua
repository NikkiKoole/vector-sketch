-- main.lua

local ui = {}

-- Theme Configuration
local theme = {
    button = {
        default = { 188 / 255, 175 / 255, 156 / 255 },   -- Default fill color
        hover = { 105 / 255, 98 / 255, 109 / 255 },      -- Hover fill color
        pressed = { 217 / 255, 189 / 255, 197 / 255 },   -- Pressed fill color
        outline = { 1, 1, 1 },                           -- Outline color
        text_default = { 1, 1, 1 },                      -- Default text color
        text_hover = { 244 / 255, 189 / 255, 94 / 255 }, -- Text color on hover
        radius = 2,
        height = 40
    },
    checkbox = {
        checked = { 1, 1, 1 },
        label = { 1, 1, 1 }, -- Label text color
    },
    slider = {
        track = { 0.5, 0.5, 0.5 }, -- Slider track color
        thumb = { 0.2, 0.6, 1 },   -- Slider thumb color
        outline = { 1, 1, 1 },
        track_radius = 2,
        height = 32
    },
    draggedElement = {
        fill = { 1, 1, 1 }, -- Color of the dragged element
    },
    general = {
        text = { 1, 1, 1 }, -- General text color
    },
    panel = {
        background = { 50 / 255, 50 / 255, 50 / 255 }, -- Panel background color
        outline = { 1, 1, 1 },                         -- Panel outline color
        label = { 1, 1, 1 },                           -- Panel label text color
    },
    textinput = {
        background = { 0.1, 0.1, 0.1 },                          -- Background color of the TextInput
        outline = { 1, 1, 1 },                                   -- Default outline color
        text = { 1, 1, 1 },                                      -- Text color
        placeholder = { 0.5, 0.5, 0.5 },                         -- Placeholder text color
        cursor = { 1, 1, 1 },                                    -- Cursor color
        focusedBorderColor = { 244 / 255, 189 / 255, 94 / 255 }, -- Border color when focused
    },
    lineWidth = 3,                                               -- General line width
}

-- Initialize Love2D
function love.load()
    -- Load a custom font (ensure 'cooper_bold_bt.ttf' is in your project directory)
    font = love.graphics.newFont('cooper_bold_bt.ttf', 32)
    love.graphics.setFont(font)

    -- Initialize UI
    ui.nextID = 1 -- Initialize unique ID counter once
    ui.dragOffset = { x = 0, y = 0 }
    value = 50
    checked = true
    settingsSlider = 44
    settingsCheck = true
    sharedValue = 50
    -- Initialize TextInput States
    textInputs = {}          -- Table to store state of each TextInput
    focusedTextInputID = nil -- Tracks the currently focused TextInput
end

-- Reset UI state at the start of each frame
function ui.startFrame()
    ui.nextID = 1           -- Reset unique ID counter at the start of each frame

    ui.mousePressed = false -- Reset click state
    ui.mouseReleased = false

    local down = love.mouse.isDown(1)
    if not ui.mouseIsDown and down then
        ui.mousePressed = true
    end
    if ui.mouseIsDown and not down then
        ui.mouseReleased = true
    end
    ui.mouseIsDown = down

    ui.mouseX, ui.mouseY = love.mouse.getPosition()
end

function ui.generateID()
    local id = ui.nextID
    ui.nextID = ui.nextID + 1
    return id
end

-- Panel Function
-- x, y: Position of the panel
-- width, height: Size of the panel
-- label: Optional label text
-- drawFunc: Function to draw UI elements inside the panel
function ui.panel(x, y, width, height, label, drawFunc)
    -- Draw panel background
    love.graphics.setColor(theme.panel.background)
    love.graphics.rectangle("fill", x, y, width, height, theme.button.radius, theme.button.radius)

    -- Draw panel outline
    love.graphics.setColor(theme.panel.outline)
    love.graphics.setLineWidth(theme.lineWidth)
    love.graphics.rectangle("line", x, y, width, height, theme.button.radius, theme.button.radius)

    -- Draw panel label if provided
    if label then
        love.graphics.setColor(theme.panel.label)
        local labelHeight = font:getHeight()
        love.graphics.print(label, x + 10, y + 5) -- Adjust position as needed
    end

    -- Enable scissor to clip UI elements within the panel
    love.graphics.setScissor(x, y, width, height)

    -- Call the provided draw function to render UI elements inside the panel
    if drawFunc then
        drawFunc()
    end

    -- Disable scissor
    love.graphics.setScissor()

    -- Reset color to white
    love.graphics.setColor(1, 1, 1)
end

-- Checkbox Function
function ui.checkbox(x, y, size, checked, label)
    -- Determine the label to display inside the checkbox
    local checkmark = checked and "x" or ""

    -- Render the checkbox square using the existing button function
    local clicked, pressed, released = ui.button(x, y, size, size, '')

    -- Toggle the checked state if the checkbox was clicked
    if clicked then
        checked = not checked
    end
    local radius = size / 4
    if checked then
        love.graphics.setColor(theme.checkbox.checked) -- Use checkbox's checked color
        love.graphics.circle('fill', x + size / 2, y + size / 2, radius)
    end
    -- Draw the label text next to the checkbox
    love.graphics.setColor(theme.checkbox.label)    -- Label text color
    local textY = y + (size - font:getHeight()) / 2 -- Vertically center the text
    love.graphics.print(label, x + size + 10, textY)

    -- Reset color to white
    love.graphics.setColor(1, 1, 1)

    -- Return the updated checked state
    return clicked, checked
end

-- Immediate Mode Button Function
-- Returns clicked, pressed, released    (click triggers when mouse is released after being pressed)
function ui.button(x, y, width, height, label)
    local id = ui.generateID() -- Generate unique ID
    local isHover = ui.mouseX >= x and ui.mouseX <= x + width and
        ui.mouseY >= y and ui.mouseY <= y + height
    local pressed = isHover and ui.mousePressed

    if pressed then
        ui.activeElementID = id
    end
    -- Draw the button with state-based colors
    if ui.activeElementID == id then
        love.graphics.setColor(theme.button.pressed) -- Pressed state
    elseif isHover then
        love.graphics.setColor(theme.button.hover)   -- Hover state
    else
        love.graphics.setColor(theme.button.default) -- Default state
    end
    local rxry = 0
    if theme.button.radius > 0 then
        rxry = math.min(width, height) / theme.button.radius
    end

    love.graphics.rectangle("fill", x, y, width, height, rxry, rxry)

    -- Draw button outline
    love.graphics.setColor(theme.button.outline) -- Outline color
    love.graphics.setLineWidth(theme.lineWidth)
    love.graphics.rectangle("line", x, y, width, height, rxry, rxry)

    -- Draw button label with state-based color
    if isHover then
        love.graphics.setColor(theme.button.text_hover)   -- Text color on hover
    else
        love.graphics.setColor(theme.button.text_default) -- Default text color
    end
    local textHeight = font:getHeight()
    love.graphics.printf(label, x, y + (height - textHeight) / 2, width, "center")

    -- Reset color
    love.graphics.setColor(1, 1, 1)

    local clicked = false
    local released = ui.mouseReleased and ui.activeElementID == id

    if ui.activeElementID == id and released and isHover then
        clicked = true
    end
    if released then
        -- Reset the active element ID
        ui.activeElementID = nil
    end
    return clicked, pressed, released
end

-- Slider Function
function ui.slider(x, y, length, thickness, orientation, min, max, value)
    local inValue = value
    local sliderID = ui.generateID()
    local isHorizontal = orientation == 'horizontal'

    -- Calculate proportion and initial thumb position
    local proportion = (value - min) / (max - min)
    local thumbX, thumbY
    if isHorizontal then
        thumbX = x + proportion * (length - thickness)
        thumbY = y
    else
        thumbX = x
        thumbY = y + (1 - proportion) * (length - thickness)
    end

    -- Render the track
    love.graphics.setColor(theme.slider.track) -- Slider track color

    local rxry = 0
    if theme.slider.track_radius > 0 then
        rxry = math.min(length, thickness) / theme.slider.track_radius
    end
    if isHorizontal then
        love.graphics.rectangle("fill", x, y, length, thickness, rxry, rxry)
    else
        love.graphics.rectangle("fill", x, y, thickness, length, rxry, rxry)
    end

    -- Draw track outline
    love.graphics.setColor(theme.slider.outline) -- Slider track outline color
    love.graphics.setLineWidth(theme.lineWidth)
    if isHorizontal then
        love.graphics.rectangle("line", x, y, length, thickness, rxry, rxry)
    else
        love.graphics.rectangle("line", x, y, thickness, length, rxry, rxry)
    end

    -- Render the thumb using the existing button function
    local thumbLabel = ''
    local clicked, pressed, released = ui.button(thumbX, thumbY, thickness, thickness, thumbLabel)

    -- Handle dragging
    if pressed then
        ui.draggingSliderID = sliderID
        -- Calculate and store the offset
        if isHorizontal then
            ui.dragOffset.x = ui.mouseX - thumbX
            ui.dragOffset.y = 0 -- Not needed for horizontal
        else
            ui.dragOffset.x = 0 -- Not needed for vertical
            ui.dragOffset.y = ui.mouseY - thumbY
        end
    end

    if ui.draggingSliderID == sliderID then
        local mouseX, mouseY = ui.mouseX, ui.mouseY
        if isHorizontal then
            -- Clamp thumbX within the track boundaries
            thumbX = math.max(x, math.min(mouseX - ui.dragOffset.x, x + length - thickness))
            proportion = (thumbX - x) / (length - thickness)
        else
            -- Clamp thumbY within the track boundaries
            thumbY = math.max(y, math.min(mouseY - ui.dragOffset.y, y + length - thickness))
            proportion = 1 - ((thumbY - y) / (length - thickness))
        end
        value = min + proportion * (max - min)
    end

    if released and ui.draggingSliderID == sliderID then
        ui.draggingSliderID = nil
        -- Reset the drag offset
        ui.dragOffset.x = 0
        ui.dragOffset.y = 0
    end
    -- Reset color
    love.graphics.setColor(1, 1, 1)

    -- Return the updated value if it has changed
    if inValue ~= value then
        return value
    else
        return false
    end
end

-- TextInput Function
-- x, y: Position of the TextInput
-- width, height: Size of the TextInput
-- placeholder: Optional placeholder text
-- currentText: The current text (to be updated)
-- isNumeric: Optional boolean to restrict input to numeric only
-- Returns the updated text
function ui.textinput(x, y, width, height, placeholder, currentText, isNumeric, reparse)
    local id = ui.generateID()

    -- Initialize state for this TextInput if not already done
    if not textInputs[id] then
        textInputs[id] = {
            text = currentText or "",
            cursorPosition = 0,
            cursorTimer = 0,
            cursorVisible = true,
            isNumeric = isNumeric or false, -- Store the isNumeric flag
        }
    end

    local state = textInputs[id]
    if reparse then
        textInputs[id].text = currentText
    end
    -- Determine if the TextInput is hovered
    local isHover = ui.mouseX >= x and ui.mouseX <= x + width and
        ui.mouseY >= y and ui.mouseY <= y + height

    -- Handle focus and cursor positioning
    if ui.mousePressed then
        if isHover then
            focusedTextInputID = id

            -- Calculate the relative X position within the TextInput
            local relativeX = ui.mouseX - x - 5 -- Subtracting padding (5 pixels)

            -- Clamp relativeX to ensure it's within the TextInput boundaries
            relativeX = math.max(0, math.min(relativeX, width - 10)) -- 10 accounts for padding on both sides

            -- Initialize cursorPosition
            local newCursorPosition = 0

            -- Iterate through each character to find the cursor position
            for i = 1, #state.text do
                local subText = state.text:sub(1, i)
                local textWidth = font:getWidth(subText)

                if textWidth > relativeX then
                    newCursorPosition = i - 1
                    break
                end
            end

            -- If the click is beyond the last character, set cursor to the end
            if relativeX > font:getWidth(state.text) then
                newCursorPosition = #state.text
            end

            -- Update the cursor position
            state.cursorPosition = newCursorPosition
        else
            if focusedTextInputID == id then
                focusedTextInputID = nil
            end
        end
    end

    -- Check if this TextInput is focused
    local isFocused = (focusedTextInputID == id)

    -- Update cursor blinking
    if isFocused then
        state.cursorTimer = state.cursorTimer + love.timer.getDelta()
        if state.cursorTimer >= 0.5 then
            state.cursorVisible = not state.cursorVisible
            state.cursorTimer = 0
        end
    else
        state.cursorVisible = false
        state.cursorTimer = 0
    end

    -- Draw TextInput background
    love.graphics.setColor(theme.textinput.background)
    love.graphics.rectangle("fill", x, y, width, height, theme.button.radius, theme.button.radius)

    -- Draw TextInput outline
    if isFocused then
        love.graphics.setColor(theme.textinput.focusedBorderColor)
    else
        love.graphics.setColor(theme.textinput.outline)
    end
    love.graphics.setLineWidth(theme.lineWidth)
    love.graphics.rectangle("line", x, y, width, height, theme.button.radius, theme.button.radius)

    -- Draw placeholder or text
    if state.text == "" and not isFocused and placeholder then
        love.graphics.setColor(theme.textinput.placeholder)
        love.graphics.print(placeholder, x + 5, y + (height - font:getHeight()) / 2)
    else
        love.graphics.setColor(theme.textinput.text)
        love.graphics.print(state.text, x + 5, y + (height - font:getHeight()) / 2)
    end

    -- Draw cursor if focused
    if isFocused and state.cursorVisible then
        -- Calculate cursor position
        local textBeforeCursor = state.text:sub(1, state.cursorPosition)
        local cursorX = x + 5 + font:getWidth(textBeforeCursor)
        local cursorY = y + (height - font:getHeight()) / 2
        love.graphics.setColor(theme.textinput.cursor)
        love.graphics.line(cursorX, cursorY, cursorX, cursorY + font:getHeight())
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1)

    return state.text, state.text ~= currentText
end

-- Update function
function love.update(dt)
    -- Currently not used, but reserved for future UI updates
end

-- Draw UI and Handle Interactions
function love.draw()
    -- Draw a greeting message
    love.graphics.setColor(theme.general.text) -- General text color
    if true then
        love.graphics.print(
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk\n" ..
            "lmnopqrstuvwxyz\n" ..
            "àáâãäåæçèéêëìíîïðñòóôõöøùúûüýÿ\n" ..
            "ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝŸ\n" ..
            "¡¢£¤¥¦§¨©ª«¬®¯°¹²³±´µ¶·¸º»¼½¾¿‘’“”•\n" ..
            "–—˜™š›œžŸ‚ƒ„…†‡ˆ‰Š‹ŒŽ‰\n" ..
            "!#$%&()*+,-./:;?@[\\]^_`{|}~\n" ..
            "0123456789¥¢₤₣₱\n" ..
            "× ÷ ≠ ≈ ≤ ≥ ∞ ∑ ∏ ∫\n" ..
            "ÞþÐðßøØåÅœŒÆæπ\n" ..
            "\n" ..
            "ß π µ Ω ∞ »««¬®¥¦§\n",
            0, 0
        )
    end
    -- Position adjusted for visibility
    love.graphics.setColor(1, 1, 1) -- Reset color

    -- Start a new UI frame
    ui.startFrame()

    -- Horizontal Slider
    local slide = ui.slider(50, 300, 200, theme.slider.height, 'horizontal', 0, 100, value)
    if slide then
        value = slide
    end

    -- Checkbox
    local clicked, newChecked = ui.checkbox(100, 100, theme.slider.height, checked, 'Weird Stuff')
    if clicked then
        checked = newChecked
    end

    -- Vertical Slider
    local slideV = ui.slider(350, 100, 200, theme.slider.height, 'vertical', 0, 100, value)
    if slideV then
        value = slideV
    end

    -- "Press Me" Button
    local buttonClicked, buttonPressed = ui.button(50, 50, 200, theme.button.height, 'Press Me')
    if buttonClicked then
        print('Hello button is clicked! Now I say World!')
    end
    if buttonPressed then
        print('Hello button is pressed! Now I say World!')
    end

    -- "Spawn" Button
    local spawnClicked, spawnPressed, spawnReleased = ui.button(50, 150, 200, theme.button.height, 'Spawn')
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
    ui.panel(400, 50, 300, 450, "Settings Panel", function()
        -- UI elements inside the panel should have positions relative to the panel's top-left corner

        -- Example Button inside the panel
        local panelButtonClicked, panelButtonPressed = ui.button(410, 370, 280, theme.button.height, 'Panel Button')
        if panelButtonClicked then
            print('Panel Button clicked!')
        end
        if panelButtonPressed then
            print('Panel Button pressed!')
        end

        -- Example Checkbox inside the panel
        local panelClicked, panelChecked = ui.checkbox(410, 130, theme.slider.height, settingsCheck, 'Panel Checkbox')
        if panelClicked then
            settingsCheck = panelChecked
            print('Panel Checkbox toggled!')
        end

        ui.sliderWithInput(410, 180, 100, 0, 100, settingsSlider)
    end)

    -- Example TextInput outside the panel (Non-numeric)
    local inputText = ui.textinput(50, 400, 200, 40, "Enter text...", "Initial Text", false)
    love.graphics.setColor(theme.general.text)
    love.graphics.print("You entered: " .. inputText, 50, 450)
    love.graphics.setColor(1, 1, 1)

    -- Render Dragged Element
    if ui.draggingActive then
        love.graphics.setColor(theme.draggedElement.fill) -- Dragged element color
        local x, y = love.mouse.getPosition()
        love.graphics.circle('fill', x, y, 10)
        love.graphics.setColor(1, 1, 1) -- Reset color
    end
end

ui.sliderWithInput = function(x, y, w, min, max, value)
    local yOffset = (40 - theme.slider.height) / 2
    local panelSlider = ui.slider(x, y + yOffset, w, theme.slider.height, 'horizontal', min, max, settingsSlider)
    local valueHasChangedViaSlider = false
    local returnValue = nil
    if panelSlider then
        settingsSlider = string.format(
            "%.2f", panelSlider)
        valueHasChangedViaSlider = true
        returnValue = settingsSlider
        --print('Panel Slider value:', panelSlider)
    end
    -- Example TextInput inside the panel (Numeric)
    local numericInputText, dirty = ui.textinput(x + w + 20, y, 110, 40, "Enter number...", "" .. settingsSlider,
        true,
        valueHasChangedViaSlider)
    if dirty then
        --print(numericInputText, dirty)
        settingsSlider = tonumber(numericInputText)
        returnValue = settingsSlider
    end
    if returnValue then
        return returnValue
    end
end
-- Handle text input globally and delegate to the focused TextInput
function love.textinput(t)
    if focusedTextInputID and textInputs[focusedTextInputID] then
        local state = textInputs[focusedTextInputID]

        if state.isNumeric then
            -- Define allowed characters: digits (0-9)
            -- Modify the pattern if you want to allow decimals or negative signs
            --
            if t:match("^[%d%.%-]$") then
                -- Additional logic to prevent multiple decimals or multiple minus signs can be added here
                state.text = state.text:sub(1, state.cursorPosition) .. t .. state.text:sub(state.cursorPosition + 1)
                state.cursorPosition = state.cursorPosition + #t
                -- if t:match("^%d$") then
                -- Insert the numeric character
                --     state.text = state.text:sub(1, state.cursorPosition) .. t .. state.text:sub(state.cursorPosition + 1)
                --     state.cursorPosition = state.cursorPosition + #t
            else
                -- Optionally, provide feedback for invalid input
                -- Example: print("Only numeric input is allowed.")
            end
        else
            -- For non-numeric TextInputs, allow all characters
            state.text = state.text:sub(1, state.cursorPosition) .. t .. state.text:sub(state.cursorPosition + 1)
            state.cursorPosition = state.cursorPosition + #t
        end
    end
end

-- Handle key presses globally and delegate to the focused TextInput
function love.keypressed(key)
    if focusedTextInputID and textInputs[focusedTextInputID] then
        local state = textInputs[focusedTextInputID]
        if key == "backspace" then
            if state.cursorPosition > 0 then
                state.text = state.text:sub(1, state.cursorPosition - 1) .. state.text:sub(state.cursorPosition + 1)
                state.cursorPosition = state.cursorPosition - 1
            end
        elseif key == "delete" then
            if state.cursorPosition < #state.text then
                state.text = state.text:sub(1, state.cursorPosition) .. state.text:sub(state.cursorPosition + 2)
                -- No change to cursorPosition
            end
        elseif key == "left" then
            if state.cursorPosition > 0 then
                state.cursorPosition = state.cursorPosition - 1
            end
        elseif key == "right" then
            if state.cursorPosition < #state.text then
                state.cursorPosition = state.cursorPosition + 1
            end
        elseif key == "home" then
            state.cursorPosition = 0
        elseif key == "end" then
            state.cursorPosition = #state.text
        elseif key == "return" or key == "kpenter" then
            -- Optionally handle 'enter' key (e.g., lose focus)
            focusedTextInputID = nil
        end
    end

    -- Existing key handling (e.g., escape key)
    if key == 'escape' then
        love.event.quit()
    end
end

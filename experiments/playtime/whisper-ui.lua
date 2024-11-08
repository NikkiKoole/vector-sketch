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

ui.theme = theme

--- Initializes the UI module.
-----
function ui.init()
    -- Initialize UI
    ui.nextID = 1               -- Initialize unique ID counter once
    ui.dragOffset = { x = 0, y = 0 }
    ui.focusedTextInputID = nil -- Tracks the currently focused TextInput
    ui.textInputs = {}
end

--- Resets UI state at the start of each frame.
-----
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

--- Creates a horizontal slider with a numeric input field.
------
-- @param x The x-coordinate of the slider.
-- @param y The y-coordinate of the slider.
-- @param w The width of the slider.
-- @param min The minimum value of the slider.
-- @param max The maximum value of the slider.
-- @param value The current value of the slider.
-- @return The updated value if it has changed, otherwise nil.
function ui.sliderWithInput(x, y, w, min, max, value)
    local yOffset = (40 - theme.slider.height) / 2
    local panelSlider = ui.slider(x, y + yOffset, w, ui.theme.slider.height, 'horizontal', min, max, value)
    local valueHasChangedViaSlider = false
    local returnValue = nil
    if panelSlider then
        value = string.format(
            "%.2f", panelSlider)
        valueHasChangedViaSlider = true
        returnValue = value
        --print('Panel Slider value:', panelSlider)
    end
    -- Example TextInput inside the panel (Numeric)
    local numericInputText, dirty = ui.textinput(x + w + 20, y, 110, 40, "Enter number...", "" .. value,
        true,
        valueHasChangedViaSlider)
    if dirty then
        --print(numericInputText, dirty)
        value = tonumber(numericInputText)
        returnValue = value
    end
    if returnValue then
        return returnValue
    end
end

--- Draws a panel with optional label and content.
------
-- @param x The x-coordinate of the panel.
-- @param y The y-coordinate of the panel.
-- @param width The width of the panel.
-- @param height The height of the panel.
-- @param label Optional label text.
-- @param drawFunc Function to draw UI elements inside the panel.
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
        --love.graphics.print(label, x + 10, y + 5) -- Adjust position as needed
        love.graphics.printf(label, x, y + 5, width, "center")
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

--- Creates a checkbox with a label.
------
-- @param x The x-coordinate of the checkbox.
-- @param y The y-coordinate of the checkbox.
-- @param checked The initial checked state.
-- @param label The label text.
-- @return clicked, checked - whether the checkbox was clicked, and the updated checked state.
function ui.checkbox(x, y, checked, label)
    local size = theme.slider.height
    -- Determine the label to display inside the checkbox
    local checkmark = checked and "x" or ""

    -- Render the checkbox square using the existing button function
    local clicked, pressed, released = ui.button(x, y, size, '', size)

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

--- Creates a button.
------
-- @param x The x-coordinate of the button.
-- @param y The y-coordinate of the button.
-- @param width The width of the button.
-- @param label The text label of the button.
-- @param[opt] optionalHeight The height of the button. Defaults to theme.button.height if not provided.
-- @return clicked, pressed, released - Booleans indicating the button state.
function ui.button(x, y, width, label, optionalHeight)
    local height = optionalHeight and optionalHeight or theme.button.height

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

--- Creates a slider (horizontal or vertical).
------
-- @param x The x-coordinate of the slider.
-- @param y The y-coordinate of the slider.
-- @param length The length of the slider.
-- @param thickness The thickness of the slider.
-- @param orientation The orientation ('horizontal' or 'vertical').
-- @param min The minimum value of the slider.
-- @param max The maximum value of the slider.
-- @param value The current value of the slider.
-- @return The updated value if it has changed, otherwise false.
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
    local clicked, pressed, released = ui.button(thumbX, thumbY, thickness, thumbLabel, thickness)

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

--- Handles key presses for the UI, particularly for text inputs.
------
-- @param key The key that was pressed.
function ui.handleKeyPress(key)
    if ui.focusedTextInputID and ui.textInputs[ui.focusedTextInputID] then
        local state = ui.textInputs[ui.focusedTextInputID]
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
            ui.focusedTextInputID = nil
        end
    end
end

--- Handles text input for the UI, particularly for text inputs.
------
-- @param t The text input.
function ui.handleTextInput(t)
    if ui.focusedTextInputID and ui.textInputs[ui.focusedTextInputID] then
        local state = ui.textInputs[ui.focusedTextInputID]

        if state.isNumeric then
            -- Define allowed characters: digits (0-9)
            -- Modify the pattern if you want to allow decimals or negative signs
            --
            if t:match("^[%d%.%-]$") then
                -- Additional logic to prevent multiple decimals or multiple minus signs can be added here
                state.text = state.text:sub(1, state.cursorPosition) .. t .. state.text:sub(state.cursorPosition + 1)
                state.cursorPosition = state.cursorPosition + #t
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

--- Creates a text input field.
------
-- @param x The x-coordinate of the text input.
-- @param y The y-coordinate of the text input.
-- @param width The width of the text input.
-- @param height The height of the text input.
-- @param placeholder Optional placeholder text.
-- @param currentText The current text content.
-- @param isNumeric Optional boolean to restrict input to numeric only.
-- @param reparse Optional boolean indicating if the text should be reparsed.
-- @return The updated text and a boolean indicating if the text has changed.
function ui.textinput(x, y, width, height, placeholder, currentText, isNumeric, reparse)
    local id = ui.generateID()

    -- Initialize state for this TextInput if not already done
    if not ui.textInputs[id] then
        ui.textInputs[id] = {
            text = currentText or "",
            cursorPosition = 0,
            cursorTimer = 0,
            cursorVisible = true,
            isNumeric = isNumeric or false, -- Store the isNumeric flag
        }
    end

    local state = ui.textInputs[id]
    if reparse then
        ui.textInputs[id].text = currentText
    end
    -- Determine if the TextInput is hovered
    local isHover = ui.mouseX >= x and ui.mouseX <= x + width and
        ui.mouseY >= y and ui.mouseY <= y + height

    -- Handle focus and cursor positioning
    if ui.mousePressed then
        if isHover then
            ui.focusedTextInputID = id

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
            if ui.focusedTextInputID == id then
                ui.focusedTextInputID = nil
            end
        end
    end

    -- Check if this TextInput is focused
    local isFocused = (ui.focusedTextInputID == id)

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

--- Draws a text label at the specified position.
-----
-- @param x The x-coordinate of the label.
-- @param y The y-coordinate of the label.
-- @param text The text to display.
function ui.label(x, y, text)
    love.graphics.setColor(ui.theme.general.text)
    love.graphics.print(text, x, y)
    love.graphics.setColor(1, 1, 1)
end

return ui

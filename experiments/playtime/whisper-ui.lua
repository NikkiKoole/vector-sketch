-- ui.lua
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
        selectionBackground = { 0.2, 0.4, 0.8, 0.5 },            -- Selection highlight color
    },
    lineWidth = 3,                                               -- General line width
}

ui.theme = theme

--- Initializes the UI module.
function ui.init()
    ui.nextID = 1               -- Unique ID counter
    ui.dragOffset = { x = 0, y = 0 }
    ui.focusedTextInputID = nil -- Tracks the currently focused TextInput
    ui.textInputs = {}
end

--- Resets UI state at the start of each frame.
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

--- Helper function to calculate cursor position within a line based on mouse X coordinate.
function ui.calculateCursorPositionInLine(text, relativeX)
    local newCursorPosition = 0
    for i = 1, #text do
        local subText = text:sub(1, i)
        local textWidth = font:getWidth(subText)
        if textWidth > relativeX then
            newCursorPosition = i - 1
            break
        end
    end
    if relativeX > font:getWidth(text) then
        newCursorPosition = #text
    end
    return newCursorPosition
end

--- Function to reconstruct the text from lines.
function ui.reconstructText(lines)
    return table.concat(lines, "\n")
end

--- Function to split text into lines.
function ui.splitTextIntoLines(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    return lines
end

--- Function to check if the selection is empty.
function ui.isSelectionEmpty(state)
    return state.selectionStart.line == state.selectionEnd.line and state.selectionStart.char == state.selectionEnd.char
end

--- Function to get the selected text.
function ui.getSelectedText(state)
    local selStartLine = state.selectionStart.line
    local selStartChar = state.selectionStart.char
    local selEndLine = state.selectionEnd.line
    local selEndChar = state.selectionEnd.char

    -- Normalize selection indices
    if selStartLine > selEndLine or (selStartLine == selEndLine and selStartChar > selEndChar) then
        selStartLine, selEndLine = selEndLine, selStartLine
        selStartChar, selEndChar = selEndChar, selStartChar
    end

    local selectedText = {}
    for i = selStartLine, selEndLine do
        local lineText = state.lines[i]
        local startChar = (i == selStartLine) and selStartChar + 1 or 1
        local endChar = (i == selEndLine) and selEndChar or #lineText
        table.insert(selectedText, lineText:sub(startChar, endChar))
    end
    return table.concat(selectedText, "\n")
end

--- Function to delete the selected text.
function ui.deleteSelection(state)
    local selStartLine = state.selectionStart.line
    local selStartChar = state.selectionStart.char
    local selEndLine = state.selectionEnd.line
    local selEndChar = state.selectionEnd.char

    -- Normalize selection indices
    if selStartLine > selEndLine or (selStartLine == selEndLine and selStartChar > selEndChar) then
        selStartLine, selEndLine = selEndLine, selStartLine
        selStartChar, selEndChar = selEndChar, selStartChar
    end

    if selStartLine == selEndLine then
        -- Selection within a single line
        local line = state.lines[selStartLine]
        state.lines[selStartLine] = line:sub(1, selStartChar) .. line:sub(selEndChar + 1)
    else
        -- Selection spans multiple lines
        local startLineText = state.lines[selStartLine]:sub(1, selStartChar)
        local endLineText = state.lines[selEndLine]:sub(selEndChar + 1)
        -- Remove middle lines
        for i = selStartLine + 1, selEndLine do
            table.remove(state.lines, selStartLine + 1)
        end
        -- Merge start and end lines
        state.lines[selStartLine] = startLineText .. endLineText
    end
    -- Update cursor position
    state.cursorPosition = { line = selStartLine, char = selStartChar }
    -- Clear selection
    state.selectionStart = { line = selStartLine, char = selStartChar }
    state.selectionEnd = { line = selStartLine, char = selStartChar }
    -- Reconstruct text
    state.text = ui.reconstructText(state.lines)
end

--- Creates a layout context for arranging UI elements.
function ui.createLayout(params)
    local layout = {
        type = params.type or 'rows',
        margin = params.margin or 0,
        spacing = params.spacing or 0,
        curX = params.startX or 0,
        curY = params.startY or 0,
    }
    return layout
end

--- Calculates the next position in the layout and updates the layout context.
function ui.nextLayoutPosition(layout, elementWidth, elementHeight)
    local x = layout.curX
    local y = layout.curY

    -- Update positions for the next element
    if layout.type == 'rows' then
        layout.curX = layout.curX + elementWidth + layout.spacing
    elseif layout.type == 'columns' then
        layout.curY = layout.curY + elementHeight + layout.spacing
    end

    return x, y
end

--- Helper function to calculate cursor position based on mouse X coordinate.
function ui.calculateCursorPosition(text, relativeX)
    local newCursorPosition = 0
    for i = 1, #text do
        local subText = text:sub(1, i)
        local textWidth = font:getWidth(subText)
        if textWidth > relativeX then
            newCursorPosition = i - 1
            break
        end
    end
    if relativeX > font:getWidth(text) then
        newCursorPosition = #text
    end
    return newCursorPosition
end

--- Creates a horizontal slider with a numeric input field.
function ui.sliderWithInput(x, y, w, min, max, value)
    local yOffset = (40 - theme.slider.height) / 2
    local panelSlider = ui.slider(x, y + yOffset, w, ui.theme.slider.height, 'horizontal', min, max, value)
    local valueHasChangedViaSlider = false
    local returnValue = nil
    if panelSlider then
        value = string.format("%.2f", panelSlider)
        valueHasChangedViaSlider = true
        returnValue = value
    end
    -- TextInput for numeric input
    local numericInputText, dirty = ui.textinput(x + w + 10, y, 110, 40, "Enter number...", "" .. value,
        true, valueHasChangedViaSlider)
    if dirty then
        value = tonumber(numericInputText)
        returnValue = value
    end
    if returnValue then
        return returnValue
    end
end

--- Draws a panel with optional label and content.
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

function ui.textinput(x, y, width, height, placeholder, currentText, isNumeric, reparse)
    local id = ui.generateID()

    -- Initialize state for this TextInput if not already done
    if not ui.textInputs[id] then
        ui.textInputs[id] = {
            text = currentText or "",
            lines = {}, -- Stores text broken into lines
            cursorPosition = { line = 1, char = 0 },
            cursorTimer = 0,
            cursorVisible = true,
            isNumeric = isNumeric or false,
            selectionStart = { line = 1, char = 0 },
            selectionEnd = { line = 1, char = 0 },
            isSelecting = false,
        }
        -- Split initial text into lines
        ui.textInputs[id].lines = ui.splitTextIntoLines(ui.textInputs[id].text)
    end

    local state = ui.textInputs[id]
    if reparse then
        state.text = currentText
        state.lines = ui.splitTextIntoLines(state.text)
    end

    local isHover = ui.mouseX >= x and ui.mouseX <= x + width and
        ui.mouseY >= y and ui.mouseY <= y + height

    -- Handle focus and cursor positioning
    if ui.mousePressed then
        if isHover then
            ui.focusedTextInputID = id
            local relativeX = ui.mouseX - x - 5 -- Subtracting padding
            local relativeY = ui.mouseY - y
            local lineIndex = math.floor(relativeY / font:getHeight()) + 1
            lineIndex = math.max(1, math.min(lineIndex, #state.lines))
            local lineText = state.lines[lineIndex]
            local charIndex = ui.calculateCursorPositionInLine(lineText, relativeX)
            state.cursorPosition = { line = lineIndex, char = charIndex }
            state.selectionStart = { line = lineIndex, char = charIndex }
            state.selectionEnd = { line = lineIndex, char = charIndex }
            state.isSelecting = true
        else
            if ui.focusedTextInputID == id then
                ui.focusedTextInputID = nil
            end
        end
    end

    -- Handle text selection with mouse dragging
    if ui.focusedTextInputID == id and ui.mouseIsDown and state.isSelecting then
        local relativeX = ui.mouseX - x - 5
        local relativeY = ui.mouseY - y
        local lineIndex = math.floor(relativeY / font:getHeight()) + 1
        lineIndex = math.max(1, math.min(lineIndex, #state.lines))
        local lineText = state.lines[lineIndex]
        local charIndex = ui.calculateCursorPositionInLine(lineText, relativeX)
        state.cursorPosition = { line = lineIndex, char = charIndex }
        state.selectionEnd = { line = lineIndex, char = charIndex }
    elseif ui.mouseReleased and state.isSelecting then
        state.isSelecting = false
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

    local lineHeight = font:getHeight()

    -- Set up scissor to clip text inside the TextInput area
    love.graphics.setScissor(x, y, width, height)

    -- Draw selection background
    local selStartLine = state.selectionStart.line
    local selStartChar = state.selectionStart.char
    local selEndLine = state.selectionEnd.line
    local selEndChar = state.selectionEnd.char

    -- Normalize selection indices
    if selStartLine > selEndLine or (selStartLine == selEndLine and selStartChar > selEndChar) then
        selStartLine, selEndLine = selEndLine, selStartLine
        selStartChar, selEndChar = selEndChar, selStartChar
    end

    if not (selStartLine == selEndLine and selStartChar == selEndChar) then
        for i = selStartLine, selEndLine do
            local lineText = state.lines[i]
            local startChar = (i == selStartLine) and selStartChar or 0
            local endChar = (i == selEndLine) and selEndChar or #lineText
            local selectionWidth = font:getWidth(lineText:sub(startChar + 1, endChar))
            local selectionX = x + 5 + font:getWidth(lineText:sub(1, startChar))
            local selectionY = y + (i - 1) * lineHeight
            love.graphics.setColor(theme.textinput.selectionBackground)
            love.graphics.rectangle('fill', selectionX, selectionY, selectionWidth, lineHeight)
        end
    end

    -- Draw text
    for i, line in ipairs(state.lines) do
        local textY = y + (i - 1) * lineHeight
        love.graphics.setColor(theme.textinput.text)
        love.graphics.print(line, x + 5, textY)
    end

    -- Draw cursor if focused
    if isFocused and state.cursorVisible then
        local pos = state.cursorPosition
        local lineText = state.lines[pos.line]:sub(1, pos.char)
        local cursorX = x + 5 + font:getWidth(lineText)
        local cursorY = y + (pos.line - 1) * lineHeight
        love.graphics.setColor(theme.textinput.cursor)
        love.graphics.line(cursorX, cursorY, cursorX, cursorY + lineHeight)
    end

    -- Remove scissor
    love.graphics.setScissor()

    -- Reset color
    love.graphics.setColor(1, 1, 1)

    return state.text, state.text ~= currentText
end

--- Handles text input for the UI, particularly for text inputs.
function ui.handleTextInput(t)
    if ui.focusedTextInputID and ui.textInputs[ui.focusedTextInputID] then
        local state = ui.textInputs[ui.focusedTextInputID]

        if state.isNumeric and not tonumber(t) and t ~= "." and t ~= "-" then
            -- Ignore non-numeric input
            return
        end

        if not ui.isSelectionEmpty(state) then
            ui.deleteSelection(state)
        end

        local pos = state.cursorPosition
        local line = state.lines[pos.line]
        if t == "\n" or t == "\r" then
            -- Handle new line
            local beforeCursor = line:sub(1, pos.char)
            local afterCursor = line:sub(pos.char + 1)
            state.lines[pos.line] = beforeCursor
            table.insert(state.lines, pos.line + 1, afterCursor)
            pos.line = pos.line + 1
            pos.char = 0
        else
            -- Regular character input
            state.lines[pos.line] = line:sub(1, pos.char) .. t .. line:sub(pos.char + 1)
            pos.char = pos.char + #t
        end
        -- Update selection
        state.selectionStart = { line = pos.line, char = pos.char }
        state.selectionEnd = { line = pos.line, char = pos.char }
        -- Reconstruct text
        state.text = ui.reconstructText(state.lines)
    end
end

--- Handles key presses for the UI, particularly for text inputs.
function ui.handleKeyPress(key)
    if ui.focusedTextInputID and ui.textInputs[ui.focusedTextInputID] then
        local state = ui.textInputs[ui.focusedTextInputID]
        local isCtrlDown = love.keyboard.isDown('lctrl', 'rctrl')
        local isShiftDown = love.keyboard.isDown('lshift', 'rshift')

        if isCtrlDown then
            if key == 'c' then
                -- Copy
                if not ui.isSelectionEmpty(state) then
                    local selectedText = ui.getSelectedText(state)
                    love.system.setClipboardText(selectedText)
                end
            elseif key == 'v' then
                -- Paste
                local clipboardText = love.system.getClipboardText() or ""
                if clipboardText ~= "" then
                    -- Delete selected text if any
                    if not ui.isSelectionEmpty(state) then
                        ui.deleteSelection(state)
                    end
                    -- Insert clipboard text
                    local pos = state.cursorPosition
                    local linesToInsert = ui.splitTextIntoLines(clipboardText)
                    if #linesToInsert == 1 then
                        -- Insert into current line
                        local line = state.lines[pos.line]
                        state.lines[pos.line] = line:sub(1, pos.char) .. linesToInsert[1] .. line:sub(pos.char + 1)
                        pos.char = pos.char + #linesToInsert[1]
                    else
                        -- Insert multiple lines
                        local line = state.lines[pos.line]
                        local beforeCursor = line:sub(1, pos.char)
                        local afterCursor = line:sub(pos.char + 1)
                        state.lines[pos.line] = beforeCursor .. linesToInsert[1]
                        for i = 2, #linesToInsert - 1 do
                            table.insert(state.lines, pos.line + i - 1, linesToInsert[i])
                        end
                        table.insert(state.lines, pos.line + #linesToInsert - 1,
                            linesToInsert[#linesToInsert] .. afterCursor)
                        pos.line = pos.line + #linesToInsert - 1
                        pos.char = #linesToInsert[#linesToInsert]
                    end
                    -- Clear selection
                    state.selectionStart = { line = pos.line, char = pos.char }
                    state.selectionEnd = { line = pos.line, char = pos.char }
                    -- Reconstruct text
                    state.text = ui.reconstructText(state.lines)
                end
            elseif key == 'x' then
                -- Cut
                if not ui.isSelectionEmpty(state) then
                    local selectedText = ui.getSelectedText(state)
                    love.system.setClipboardText(selectedText)
                    ui.deleteSelection(state)
                end
            end
        else
            -- Handle other keys
            local pos = state.cursorPosition
            if key == "backspace" then
                if not ui.isSelectionEmpty(state) then
                    ui.deleteSelection(state)
                elseif pos.char > 0 then
                    -- Delete character before cursor
                    local line = state.lines[pos.line]
                    state.lines[pos.line] = line:sub(1, pos.char - 1) .. line:sub(pos.char + 1)
                    pos.char = pos.char - 1
                elseif pos.line > 1 then
                    -- Merge with previous line
                    local prevLine = state.lines[pos.line - 1]
                    pos.char = #prevLine
                    state.lines[pos.line - 1] = prevLine .. state.lines[pos.line]
                    table.remove(state.lines, pos.line)
                    pos.line = pos.line - 1
                end
                -- Update selection
                state.selectionStart = { line = pos.line, char = pos.char }
                state.selectionEnd = { line = pos.line, char = pos.char }
                state.text = ui.reconstructText(state.lines)
            elseif key == "delete" then
                if not ui.isSelectionEmpty(state) then
                    ui.deleteSelection(state)
                elseif pos.char < #state.lines[pos.line] then
                    -- Delete character after cursor
                    local line = state.lines[pos.line]
                    state.lines[pos.line] = line:sub(1, pos.char) .. line:sub(pos.char + 2)
                elseif pos.line < #state.lines then
                    -- Merge with next line
                    state.lines[pos.line] = state.lines[pos.line] .. state.lines[pos.line + 1]
                    table.remove(state.lines, pos.line + 1)
                end
                -- Update selection
                state.selectionStart = { line = pos.line, char = pos.char }
                state.selectionEnd = { line = pos.line, char = pos.char }
                state.text = ui.reconstructText(state.lines)
            elseif key == "left" then
                if pos.char > 0 then
                    pos.char = pos.char - 1
                elseif pos.line > 1 then
                    pos.line = pos.line - 1
                    pos.char = #state.lines[pos.line]
                end
                if isShiftDown then
                    state.selectionEnd = { line = pos.line, char = pos.char }
                else
                    state.selectionStart = { line = pos.line, char = pos.char }
                    state.selectionEnd = { line = pos.line, char = pos.char }
                end
            elseif key == "right" then
                if pos.char < #state.lines[pos.line] then
                    pos.char = pos.char + 1
                elseif pos.line < #state.lines then
                    pos.line = pos.line + 1
                    pos.char = 0
                end
                if isShiftDown then
                    state.selectionEnd = { line = pos.line, char = pos.char }
                else
                    state.selectionStart = { line = pos.line, char = pos.char }
                    state.selectionEnd = { line = pos.line, char = pos.char }
                end
            elseif key == "up" then
                if pos.line > 1 then
                    pos.line = pos.line - 1
                    pos.char = math.min(pos.char, #state.lines[pos.line])
                end
                if isShiftDown then
                    state.selectionEnd = { line = pos.line, char = pos.char }
                else
                    state.selectionStart = { line = pos.line, char = pos.char }
                    state.selectionEnd = { line = pos.line, char = pos.char }
                end
            elseif key == "down" then
                if pos.line < #state.lines then
                    pos.line = pos.line + 1
                    pos.char = math.min(pos.char, #state.lines[pos.line])
                end
                if isShiftDown then
                    state.selectionEnd = { line = pos.line, char = pos.char }
                else
                    state.selectionStart = { line = pos.line, char = pos.char }
                    state.selectionEnd = { line = pos.line, char = pos.char }
                end
            elseif key == "home" then
                pos.char = 0
                if isShiftDown then
                    state.selectionEnd = { line = pos.line, char = pos.char }
                else
                    state.selectionStart = { line = pos.line, char = pos.char }
                    state.selectionEnd = { line = pos.line, char = pos.char }
                end
            elseif key == "end" then
                pos.char = #state.lines[pos.line]
                if isShiftDown then
                    state.selectionEnd = { line = pos.line, char = pos.char }
                else
                    state.selectionStart = { line = pos.line, char = pos.char }
                    state.selectionEnd = { line = pos.line, char = pos.char }
                end
            elseif key == "return" or key == "kpenter" then
                -- Handle new line on enter key
                ui.handleTextInput("\n")
            elseif key == "escape" then
                ui.focusedTextInputID = nil
            end
        end
    end
end

--- Draws a text label at the specified position.
function ui.label(x, y, text)
    love.graphics.setColor(ui.theme.general.text)
    love.graphics.print(text, x, y)
    love.graphics.setColor(1, 1, 1)
end

return ui

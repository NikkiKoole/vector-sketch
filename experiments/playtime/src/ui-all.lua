-- ui-all.lua
local ui = {}

require('src.ui-textinput')(ui)

local creamy = { 245 / 255, 245 / 255, 220 / 255 } --#F5F5DC Creamy White:
local orange = { 242 / 255, 133 / 255, 0 }
-- Theme Configuration
local theme  = {
    lineHeight = 25,
    button = {
        default = { 188 / 255, 175 / 255, 156 / 255 },   -- Default fill color
        hover = { 105 / 255, 98 / 255, 109 / 255 },      -- Hover fill color
        pressed = { 217 / 255, 189 / 255, 197 / 255 },   -- Pressed fill color
        outline = creamy,                                -- Outline color
        text_default = creamy,                           -- Default text color
        text_hover = { 244 / 255, 189 / 255, 94 / 255 }, -- Text color on hover
        radius = 2,
        height = 25
    },
    checkbox = {
        checked = { 1, 1, 1 },
        label = { 1, 1, 1 }, -- Label text color
    },
    toggleButton = {
        onFill = { 0.1, 0.6, 0.1 },  -- Green fill when toggled on
        offFill = { 0.6, 0.1, 0.1 }, -- Red fill when toggled off
        onText = creamy,             -- Text color when toggled on
        offText = creamy,            -- Text color when toggled off
        outline = creamy,            -- Outline color
    },
    slider = {
        track = { 0.5, 0.5, 0.5 }, -- Slider track color
        thumb = { 0.2, 0.6, 1 },   -- Slider thumb color
        outline = creamy,
        track_radius = 2,
        height = 25
    },
    draggedElement = {
        fill = { 1, 1, 1 }, -- Color of the dragged element
    },
    general = {
        text = creamy, -- General text color
    },
    panel = {
        background = { 50 / 255, 50 / 255, 50 / 255 }, -- Panel background color
        outline = creamy,                              -- Panel outline color
        label = creamy,                                -- Panel label text color
    },
    textinput = {
        background = { 0.1, 0.1, 0.1 },                          -- Background color of the TextInput
        outline = creamy,                                        -- Default outline color
        text = creamy,                                           -- Text color
        placeholder = { 0.5, 0.5, 0.5 },                         -- Placeholder text color
        cursor = { 1, 1, 1 },                                    -- Cursor color
        focusedBorderColor = { 244 / 255, 189 / 255, 94 / 255 }, -- Border color when focused
        selectionBackground = { 0.2, 0.4, 0.8, 0.5 },            -- Selection highlight color
    },
    header = {
        active = orange
    },
    lineWidth = 3, -- General line width
}

ui.theme     = theme

--- Initializes the UI module.
function ui.init(font, fontHeight)
    ui.nextID = 1               -- Unique ID counter
    ui.dragOffset = { x = 0, y = 0 }
    ui.focusedTextInputID = nil -- Tracks the currently focused TextInput
    ui.textInputs = {}
    ui.fontHeight = fontHeight
    ui.font = font or love.graphics.getFont()
    ui.mouseWheelDy = 0
    ui.mouseWheelDx = 0
    ui.overPanel = false
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
    --  print('setting to false')
    ui.overPanel = false
end

function ui.generateID()
    local id = ui.nextID
    ui.nextID = ui.nextID + 1
    return id
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

ui._scrollers = {}


function ui.scrollableList(id, x, y, w, h, drawFunc)
    local scrollY = ui._scrollers[id] or { value = 0 }
    ui.panel(x, y, w + 20, h, '', function()
        local contentHeight = ui.scrollArea(id, x, y, w, h, scrollY, drawFunc) --  drawFunc(x, y, w, h, -scrollY.value)
        --  print(contentHeight)
        --print(id)
        if contentHeight > h then
            local result = ui.slider(x + w, y, h, 20, 'vertical', (contentHeight) - h, 0, scrollY
                .value,
                id)
            if result then
                scrollY.value = result
            end
            ui._scrollers[id] = scrollY
        end
    end)
end

function ui.scrollArea(_id, x, y, w, h, scrollY, drawFunc)
    local isHover = ui.mouseX >= x and ui.mouseX <= x + w and
        ui.mouseY >= y and ui.mouseY <= y + h

    love.graphics.setScissor(x, y, w, h)

    local maxContentY = drawFunc(x, y, w, h, -scrollY.value)

    if isHover and maxContentY > h and ui.mouseWheelDy ~= 0 then
        local contentHeight = maxContentY
        scrollY.value = math.max(0, scrollY.value - ui.mouseWheelDy * 20)
        scrollY.value = math.min(scrollY.value, contentHeight - h)
        ui.mouseWheelDy = 0
    end
    scrollY.value = math.max(0, math.min(scrollY.value, maxContentY - h))
    love.graphics.setScissor()
    return maxContentY
    -- -- love.graphics.pop()
end

--- Creates a horizontal slider with a numeric input field.
function ui.sliderWithInput(_id, x, y, w, min, max, value, changed)
    local yOffset = (40 - theme.slider.height) / 2
    local panelSlider = ui.slider(x, y + yOffset, w, ui.theme.slider.height, 'horizontal', min, max, value, _id)
    local valueHasChangedViaSlider = false
    local returnValue = nil

    if panelSlider then
        value = string.format("%.2f", panelSlider)
        valueHasChangedViaSlider = true
        returnValue = value
    end

    local valueChangeFromOutside = valueHasChangedViaSlider or changed

    -- TextInput for numeric input
    local numericInputText, dirty = ui.textinput(_id, x + w + 10, y + yOffset, 80, ui.theme.slider.height,
        "Enter number...",
        "" .. value,
        true, valueChangeFromOutside)


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
    --
    local isHover = ui.mouseX >= x and ui.mouseX <= x + width and
        ui.mouseY >= y and ui.mouseY <= y + height
    if isHover then
        ui.overPanel = true
    end
    local rxry = 0
    if theme.button.radius > 0 then
        rxry = math.min(width / 6, height / 6) / theme.button.radius
    end
    love.graphics.setColor(theme.panel.background)
    love.graphics.rectangle("fill", x, y, width, height, rxry, rxry)

    -- Draw panel outline
    love.graphics.setColor(theme.panel.outline)
    love.graphics.setLineWidth(theme.lineWidth)
    love.graphics.rectangle("line", x, y, width, height, rxry, rxry)

    -- Draw panel label if provided
    if label then
        love.graphics.setColor(theme.panel.label)
        local labelHeight = ui.font:getHeight()
        love.graphics.printf(label, x, y + 5, width, "center")
    end

    -- Enable scissor to clip UI elements within the panel
    if width > 0 and height > 0 then
        --  love.graphics.setScissor(x, y, width, height)
    end
    -- Call the provided draw function to render UI elements inside the panel
    if drawFunc then
        drawFunc()
    end

    -- Disable scissor
    -- love.graphics.setScissor()

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
    love.graphics.setColor(theme.checkbox.label)       -- Label text color
    local textY = y + (size - ui.font:getHeight()) / 2 -- Vertically center the text
    love.graphics.print(label, x + size + 10, textY)

    -- Reset color to white
    love.graphics.setColor(1, 1, 1)

    -- Return the updated checked state
    return clicked, checked
end

--- Creates a toggle button that maintains an on/off state.
--- however i like the checkbox better though.......
function ui.toggleButton(x, y, width, height, labelOn, labelOff, isToggled)
    local id = ui.generateID()
    local isHover = ui.mouseX >= x and ui.mouseX <= x + width and
        ui.mouseY >= y and ui.mouseY <= y + height
    local pressed = isHover and ui.mousePressed

    if pressed then
        ui.activeElementID = id
    end

    -- Toggle state handling
    local used = false
    if ui.activeElementID == id and ui.mouseReleased and isHover then
        isToggled = not isToggled
        ui.activeElementID = nil
        used = true
    end

    -- Determine the label and colors based on the toggle state
    local label = isToggled and labelOn or labelOff
    local fillColor = isToggled and ui.theme.toggleButton.onFill or ui.theme.toggleButton.offFill
    local textColor = isToggled and ui.theme.toggleButton.onText or ui.theme.toggleButton.offText

    local rxry = 0
    if theme.button.radius > 0 then
        rxry = math.min(width, height) / theme.button.radius
    end
    -- Draw the button background
    love.graphics.setColor(fillColor)
    love.graphics.rectangle("fill", x, y, width, height, rxry, rxry)

    -- Draw button outline
    love.graphics.setColor(ui.theme.toggleButton.outline)
    love.graphics.setLineWidth(ui.theme.lineWidth)
    love.graphics.rectangle("line", x, y, width, height, rxry, rxry)

    -- Draw the label
    love.graphics.setColor(textColor)
    local textHeight = ui.font:getHeight()
    love.graphics.printf(label, x, y + (height - textHeight) / 2, width, "center")

    -- Reset color
    love.graphics.setColor(1, 1, 1)

    return used, isToggled
end

--- Creates a button.
function ui.header_button(x, y, width, label, opened)
    -- header button doenst have a button radius (its rectangular, and the lanbel is not centered..)
    local height = theme.button.height

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
    if opened then
        love.graphics.setColor(theme.header.active)
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
    local textHeight = ui.font:getHeight()
    love.graphics.print(label, x, y + (height - textHeight) / 2)
    -- love.graphics.printf(label, x, y + (height - textHeight) / 2, width, "center")

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)

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

function ui.coloredRect(x, y, color, size)
    local id = ui.generateID()
    local isHover = ui.mouseX >= x and ui.mouseX <= x + size and
        ui.mouseY >= y and ui.mouseY <= y + size
    local pressed = isHover and ui.mousePressed
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x, y, size, size)
    if pressed then
        ui.activeElementID = id
    end

    local clicked = false
    local released = ui.mouseReleased and ui.activeElementID == id

    if ui.activeElementID == id and released and isHover then
        clicked = true
    end
    if released then
        -- Reset the active element ID
        ui.activeElementID = nil
    end




    return clicked, pressed, released, isHover
end

--- Creates a button.
function ui.button(x, y, width, label, optionalHeight, optionalFillColor)
    local height = optionalHeight and optionalHeight or theme.button.height

    local id = ui.generateID() -- Generate unique ID
    local isHover = ui.mouseX >= x and ui.mouseX <= x + width and
        ui.mouseY >= y and ui.mouseY <= y + height
    local pressed = isHover and ui.mousePressed

    if pressed then
        ui.activeElementID = id
        print("Button pressed" .. id)
    end
    -- Draw the button with state-based colors
    if ui.activeElementID == id then
        love.graphics.setColor(theme.button.pressed) -- Pressed state
    elseif isHover then
        love.graphics.setColor(theme.button.hover)   -- Hover state
    else
        if (optionalFillColor) then
            love.graphics.setColor(optionalFillColor)
        else
            love.graphics.setColor(theme.button.default) -- Default state
        end
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
    local textHeight = ui.font:getHeight()
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
    return clicked, pressed, released, isHover
end

--- Creates a slider (horizontal or vertical).
function ui.slider(x, y, length, thickness, orientation, min, max, value, extraId)
    local inValue = value

    local sliderID
    if (extraId) then
        sliderID = extraId
    else
        sliderID = ui.generateID()
    end
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


    -- Set scissor to restrict rendering to the track area
    love.graphics.setScissor(x, y, isHorizontal and length or thickness, isHorizontal and thickness or length)

    -- Render the thumb using the existing button function
    local thumbLabel = ''
    local clicked, pressed, released = ui.button(thumbX, thumbY, thickness, thumbLabel, thickness)

    -- Remove scissor after rendering the thumb
    love.graphics.setScissor()



    -- -- Render the thumb using the existing button function
    -- local thumbLabel = ''
    -- local clicked, pressed, released = ui.button(thumbX, thumbY, thickness, thumbLabel, thickness)

    -- Handle dragging
    --  logger:info(ui.draggingSliderID)
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

--- Handles text input for the UI, particularly for text inputs.
function ui.handleTextInput(t)
    local textinputstate = ui.focusedTextInputID and ui.textInputs[ui.focusedTextInputID]
    if textinputstate then
        ui.handleTextInputForTextInput(t, textinputstate)
    end
end

--- Handles key presses for the UI, particularly for text inputs.
function ui.handleKeyPress(key)
    local textinputstate = ui.focusedTextInputID and ui.textInputs[ui.focusedTextInputID]

    if textinputstate then
        ui.handleKeyPressForTextInput(key, textinputstate)
    end
end

--- Draws a text label at the specified position.
function ui.centeredLabel(x, y, width, text)
    love.graphics.setColor(ui.theme.general.text)

    love.graphics.printf(text, x, y, width, "center")
    love.graphics.setColor(1, 1, 1)
end

function ui.label(x, y, text, color)
    love.graphics.setColor(color or ui.theme.general.text)
    local yOffset = 0 --ui.font:getHeight(text) / 2
    love.graphics.print(text, x, y + yOffset)
    love.graphics.setColor(1, 1, 1)
end

--- Creates a dropdown menu.
function ui.dropdown(x, y, width, options, currentSelection)
    local id = ui.generateID()
    local isOpen = ui.dropdownStates and ui.dropdownStates[id] or false
    -- Draw the dropdown box
    local clicked, pressed, released = ui.button(x, y, width, currentSelection)

    -- Toggle dropdown state
    if clicked then
        isOpen = not isOpen
    end
    ui.dropdownStates = ui.dropdownStates or {}
    ui.dropdownStates[id] = isOpen

    -- Draw options if open
    if isOpen then
        for i, option in ipairs(options) do
            local optionY = y + i * (theme.button.height + 10)
            local optionClicked = ui.button(x + width, optionY, width, option)
            if optionClicked then
                currentSelection = option
                ui.dropdownStates[id] = false -- Close dropdown
                return currentSelection
            end
        end
    end
    return false, pressed, released
end

return ui

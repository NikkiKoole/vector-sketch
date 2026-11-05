--ui-text-input.lua
local mathutils = require('src.math-utils')
return function(ui)
    --- Helper function to calculate cursor position within a line based on mouse X coordinate.
    function ui.calculateCursorPositionInLine(text, relativeX)
        local newCursorPosition = 0
        for i = 1, #text do
            local subText = text:sub(1, i)
            local textWidth = ui.font:getWidth(subText)
            if textWidth > relativeX then
                newCursorPosition = i - 1
                break
            end
        end
        if relativeX > ui.font:getWidth(text) then
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
        return state.selectionStart.line == state.selectionEnd.line and
            state.selectionStart.char == state.selectionEnd.char
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
            for _ = selStartLine + 1, selEndLine do
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

    --- Helper function to calculate cursor position based on mouse X coordinate.
    function ui.calculateCursorPosition(text, relativeX)
        local newCursorPosition = 0
        for i = 1, #text do
            local subText = text:sub(1, i)
            local textWidth = ui.font:getWidth(subText)
            if textWidth > relativeX then
                newCursorPosition = i - 1
                break
            end
        end
        if relativeX > ui.font:getWidth(text) then
            newCursorPosition = #text
        end
        return newCursorPosition
    end

    -- the selection collapsed onto pos
    local function collapseSelection(state, pos)
        state.selectionStart = { line = pos.line, char = pos.char }
        state.selectionEnd = { line = pos.line, char = pos.char }
    end

    function ui.handleTextInputForTextInput(t, state)

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
        collapseSelection(state, pos)
        -- Reconstruct text
        state.text = ui.reconstructText(state.lines)
    end

    -- after the cursor moved: with shift the selection grows to it, else it collapses there
    local function afterMove(state, pos, isShiftDown)
        if isShiftDown then
            state.selectionEnd = { line = pos.line, char = pos.char }
        else
            collapseSelection(state, pos)
        end
    end

    local function paste(state)
        local clipboardText = love.system.getClipboardText() or ""
        if clipboardText == "" then return end
        if not ui.isSelectionEmpty(state) then
            ui.deleteSelection(state)
        end
        local pos = state.cursorPosition -- after the delete: where the selection was
        local linesToInsert = ui.splitTextIntoLines(clipboardText)
        local line = state.lines[pos.line]
        if #linesToInsert == 1 then
            state.lines[pos.line] = line:sub(1, pos.char) .. linesToInsert[1] .. line:sub(pos.char + 1)
            pos.char = pos.char + #linesToInsert[1]
        else
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
        collapseSelection(state, pos)
        state.text = ui.reconstructText(state.lines)
    end

    -- with ctrl / cmd held
    local shortcuts = {
        c = function(state) -- copy
            if not ui.isSelectionEmpty(state) then
                love.system.setClipboardText(ui.getSelectedText(state))
            end
        end,
        v = paste,
        x = function(state) -- cut
            if not ui.isSelectionEmpty(state) then
                love.system.setClipboardText(ui.getSelectedText(state))
                ui.deleteSelection(state)
            end
        end,
    }

    -- the other keys: key(state, pos, isShiftDown), pos the cursor as it was when the key came
    -- (backspace and delete set the selection from it even after deleteSelection replaced it)
    local keys = {}
    keys.backspace = function(state, pos)
        if not ui.isSelectionEmpty(state) then
            ui.deleteSelection(state)
        elseif pos.char > 0 then -- the character before the cursor
            local line = state.lines[pos.line]
            state.lines[pos.line] = line:sub(1, pos.char - 1) .. line:sub(pos.char + 1)
            pos.char = pos.char - 1
        elseif pos.line > 1 then -- merge with the previous line
            local prevLine = state.lines[pos.line - 1]
            pos.char = #prevLine
            state.lines[pos.line - 1] = prevLine .. state.lines[pos.line]
            table.remove(state.lines, pos.line)
            pos.line = pos.line - 1
        end
        collapseSelection(state, pos)
        state.text = ui.reconstructText(state.lines)
    end
    keys.delete = function(state, pos)
        if not ui.isSelectionEmpty(state) then
            ui.deleteSelection(state)
        elseif pos.char < #state.lines[pos.line] then -- the character after the cursor
            local line = state.lines[pos.line]
            state.lines[pos.line] = line:sub(1, pos.char) .. line:sub(pos.char + 2)
        elseif pos.line < #state.lines then -- merge with the next line
            state.lines[pos.line] = state.lines[pos.line] .. state.lines[pos.line + 1]
            table.remove(state.lines, pos.line + 1)
        end
        collapseSelection(state, pos)
        state.text = ui.reconstructText(state.lines)
    end
    keys.left = function(state, pos, isShiftDown)
        if pos.char > 0 then
            pos.char = pos.char - 1
        elseif pos.line > 1 then
            pos.line = pos.line - 1
            pos.char = #state.lines[pos.line]
        end
        afterMove(state, pos, isShiftDown)
    end
    keys.right = function(state, pos, isShiftDown)
        if pos.char < #state.lines[pos.line] then
            pos.char = pos.char + 1
        elseif pos.line < #state.lines then
            pos.line = pos.line + 1
            pos.char = 0
        end
        afterMove(state, pos, isShiftDown)
    end
    keys.up = function(state, pos, isShiftDown)
        if pos.line > 1 then
            pos.line = pos.line - 1
            pos.char = math.min(pos.char, #state.lines[pos.line])
        end
        afterMove(state, pos, isShiftDown)
    end
    keys.down = function(state, pos, isShiftDown)
        if pos.line < #state.lines then
            pos.line = pos.line + 1
            pos.char = math.min(pos.char, #state.lines[pos.line])
        end
        afterMove(state, pos, isShiftDown)
    end
    keys.home = function(state, pos, isShiftDown)
        pos.char = 0
        afterMove(state, pos, isShiftDown)
    end
    keys['end'] = function(state, pos, isShiftDown)
        pos.char = #state.lines[pos.line]
        afterMove(state, pos, isShiftDown)
    end
    keys['return'] = function(state) ui.handleTextInputForTextInput("\n", state) end -- a new line
    keys.kpenter = keys['return']
    keys.escape = function() ui.focusedTextInputID = nil end

    function ui.handleKeyPressForTextInput(key, state)
        local isCtrlDown = love.keyboard.isDown('lctrl', 'rctrl')
        local isShiftDown = love.keyboard.isDown('lshift', 'rshift')
        local isCMDDown = love.keyboard.isDown('lgui', 'rgui')
        if isCtrlDown or isCMDDown then
            if shortcuts[key] then shortcuts[key](state) end
        elseif keys[key] then
            keys[key](state, state.cursorPosition, isShiftDown)
        end
    end

    function ui.textinput(inputId, x, y, width, height, _placeholder, currentText, isNumeric, _reparse)
        local id = inputId or ui.generateID()

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

        -- Auto-sync from external value when not focused
        local isFocused = (ui.focusedTextInputID == id)
        if not isFocused and state.text ~= currentText then
            state.text = currentText
            state.lines = ui.splitTextIntoLines(state.text)
        end

        local isHover = ui.mouseX >= x and ui.mouseX <= x + width and
            ui.mouseY >= y and ui.mouseY <= y + height

        -- Handle focus and cursor positioning
        if ui.mousePressed then
            if isHover then
                -- Check for double-click
                local currentTime = love.timer.getTime()
                local isDoubleClick = false

                if ui.lastClickID == id and (currentTime - ui.lastClickTime) < ui.doubleClickThreshold then
                    isDoubleClick = true
                end

                ui.lastClickTime = currentTime
                ui.lastClickID = id

                ui.focusedTextInputID = id

                if isDoubleClick then
                    -- Select all text on double-click
                    state.selectionStart = { line = 1, char = 0 }
                    state.selectionEnd = { line = #state.lines, char = #state.lines[#state.lines] }
                    state.cursorPosition = { line = #state.lines, char = #state.lines[#state.lines] }
                else
                    -- Single click - position cursor
                    local relativeX = ui.mouseX - x - 5 -- Subtracting padding
                    local relativeY = ui.mouseY - y
                    local lineIndex = math.floor(relativeY / ui.font:getHeight()) + 1
                    lineIndex = mathutils.clamp(lineIndex, 1, #state.lines)
                    local lineText = state.lines[lineIndex]
                    local charIndex = ui.calculateCursorPositionInLine(lineText, relativeX)
                    state.cursorPosition = { line = lineIndex, char = charIndex }
                    state.selectionStart = { line = lineIndex, char = charIndex }
                    state.selectionEnd = { line = lineIndex, char = charIndex }
                    state.isSelecting = true
                end
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
            local lineIndex = math.floor(relativeY / ui.font:getHeight()) + 1
            lineIndex = mathutils.clamp(lineIndex, 1, #state.lines)
            local lineText = state.lines[lineIndex]
            local charIndex = ui.calculateCursorPositionInLine(lineText, relativeX)
            state.cursorPosition = { line = lineIndex, char = charIndex }
            state.selectionEnd = { line = lineIndex, char = charIndex }
        elseif ui.mouseReleased and state.isSelecting then
            state.isSelecting = false
        end

        -- Re-check focus (may have changed via mouse click above)
        isFocused = (ui.focusedTextInputID == id)
        if isFocused then ui.focusedTextInputDrawn = true end -- see ui.startFrame

        -- Update cursor blinking
        if isFocused then
            state.cursorTimer = state.cursorTimer + 1.0 / 90 --love.timer.getDelta()
            if state.cursorTimer >= 0.5 then
                state.cursorVisible = not state.cursorVisible
                state.cursorTimer = 0
            end
        else
            state.cursorVisible = false
            state.cursorTimer = 0
        end

        -- Draw TextInput background
        love.graphics.setColor(ui.theme.textinput.background)
        love.graphics.rectangle("fill", x, y, width, height, ui.theme.button.radius, ui.theme.button.radius)

        -- Draw TextInput outline
        if isFocused then
            love.graphics.setColor(ui.theme.textinput.focusedBorderColor)
        else
            love.graphics.setColor(ui.theme.textinput.outline)
        end
        love.graphics.setLineWidth(ui.theme.lineWidth)
        love.graphics.rectangle("line", x, y, width, height, ui.theme.button.radius, ui.theme.button.radius)

        local lineHeight = ui.font:getHeight()

        -- Set up scissor to clip text inside the TextInput area
        ui.pushClip(x, y, width, height)

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
                local selectionWidth = ui.font:getWidth(lineText:sub(startChar + 1, endChar))
                local selectionX = x + 5 + ui.font:getWidth(lineText:sub(1, startChar))
                local selectionY = y + (i - 1) * lineHeight
                love.graphics.setColor(ui.theme.textinput.selectionBackground)
                love.graphics.rectangle('fill', selectionX, selectionY, selectionWidth, lineHeight)
            end
        end

        -- Draw text
        for i, line in ipairs(state.lines) do
            local textY = y + (i - 1) * lineHeight
            love.graphics.setColor(ui.theme.textinput.text)
            love.graphics.print(line, x + 5, textY)
        end

        -- Draw cursor if focused
        if isFocused and state.cursorVisible then
            local pos = state.cursorPosition
            local lineText = state.lines[pos.line]:sub(1, pos.char)
            local cursorX = x + 5 + ui.font:getWidth(lineText)
            local cursorY = y + (pos.line - 1) * lineHeight
            love.graphics.setColor(ui.theme.textinput.cursor)
            love.graphics.line(cursorX, cursorY, cursorX, cursorY + lineHeight)
        end

        -- Remove scissor
        ui.popClip()

        -- Reset color
        love.graphics.setColor(1, 1, 1)

        ui.setCursor(x, y, width, height)
        return state.text, state.text ~= currentText
    end
end

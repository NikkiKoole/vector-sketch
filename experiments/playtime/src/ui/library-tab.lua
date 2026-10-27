-- The "library" tab of the right column: save the selection as a prefab
-- (src/library.lua), and press a prefab to drop a copy: it spawns at the
-- mouse, drag to place, release to drop (like the toys in add shape).
local lib = {}

local ui = require('src.ui.all')
local state = require('src.state')
local camera = require('src.camera')
local library = require('src.library')

local message = ''

local function selectedThings()
    local selection = state.selection
    if selection.selectedBodies and #selection.selectedBodies > 0 then return selection.selectedBodies end
    if selection.selectedObj then return { selection.selectedObj } end
    return {}
end

local function spawn(name)
    local mx, my = love.mouse.getPosition()
    local things = library.place(name, camera.getInstance():getWorldCoordinates(mx, my))
    if things[1] then
        state.interaction.draggingObj = things[1]
        state.interaction.offsetDragging = { 0, 0 }
        state.selection.selectedBodies = things
    else
        message = 'could not place ' .. name
    end
end

function lib.draw(x, y, w, h)
    local rowH = ui.theme.button.height
    ui.panel(x, y, w, h, 'library', function()
        ui.scrollPanel('library-panel', x, y + 40, w, h - 45, function()
            local rowX, rowY, rowW = x + 10, y + 50, w - 20

            ui.alignedLabel(rowX, rowY, 'name')
            local name = ui.textinput('prefab-name', rowX + 60, rowY, rowW - 60, rowH, 'prefab name...',
                state.rightColumn.prefabName or '')
            if name then state.rightColumn.prefabName = name end
            rowY = rowY + rowH + 6

            local count = #selectedThings()
            local saveLabel = count > 0 and ('save selection (' .. count .. ')') or 'select something to save'
            if ui.button(rowX, rowY, rowW, saveLabel) and count > 0 then
                local ok, result = library.save(state.rightColumn.prefabName, selectedThings())
                message = ok and ('saved ' .. result) or ('not saved: ' .. tostring(result))
            end
            rowY = rowY + rowH + 6
            if message ~= '' then
                ui.label(rowX, rowY, message)
                rowY = rowY + rowH + 6
            end

            ui.label(rowX, rowY, 'prefabs')
            rowY = rowY + rowH + 4
            local names = library.list()
            if #names == 0 then
                ui.label(rowX, rowY, '(none yet)')
            end
            for _, prefabName in ipairs(names) do
                local _, pressed, released = ui.button(rowX, rowY, rowW, prefabName)
                if pressed then
                    ui.draggingActive = ui.activeElementID
                    spawn(prefabName)
                end
                if released then ui.draggingActive = nil; state.selection.selectedBodies = nil end
                rowY = rowY + rowH + 4
            end
        end)
    end)
end

return lib

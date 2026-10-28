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

-- A .playtime.json dropped on this tab becomes a prefab (instead of loading
-- as a scene, src/main.lua). Returns true when it took the file.
function lib.fileDropped(file, x, y, w, h)
    local mx, my = love.mouse.getPosition()
    if mx < x or mx > x + w or my < y or my > y + h then return false end
    local filename = file:getFilename()
    if not filename:find('%.playtime%.json$') then return false end
    file:open('r')
    local contents = file:read()
    file:close()
    local ok, result = library.import(filename, contents)
    message = ok and ('added ' .. result) or ('not added: ' .. tostring(result))
    return true
end

function lib.draw(x, y, w, h)
    local rowH = ui.theme.button.height
    ui.panel(x, y, w, h, 'library', function()
        ui.scrollPanel('library-panel', x, y + ui.theme.panelHeader, w, h - ui.theme.panelHeader - 5, function()
            local rowX, rowY, rowW = x + 10, y + ui.theme.panelHeader + ui.theme.spacing, w - 20

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

            ui.alignedLabel(rowX, rowY, 'prefabs')
            -- rename or delete prefabs in Finder
            if ui.button(rowX + rowW - 110, rowY, 110, 'open folder') then
                love.filesystem.createDirectory(library.DIR)
                love.system.openURL('file://' .. love.filesystem.getSaveDirectory() .. '/' .. library.DIR)
            end
            rowY = rowY + rowH + 4
            local names = library.list()
            if #names == 0 then
                ui.label(rowX, rowY, '(none yet)')
            end
            for _, prefabName in ipairs(names) do
                -- flat list rows, like the on-stage list
                local _, pressed, released = ui.header_button(rowX, rowY, rowW, ' ' .. prefabName)
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

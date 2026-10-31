-- The "scenes" tab of the right column: every scene in scripts/ (src/scene-catalog.lua), grouped,
-- each with a line saying what it is. Pick one, then 'load' or 'load + play'; a script without a
-- scene of its own (tufts) runs on the scene that's open. Loading replaces what's on the stage.
local lib = {}

local ui = require('src.ui.all')
local state = require('src.state')
local catalog = require('src.scene-catalog')

local DIM = { 0.75, 0.72, 0.66, 1 }

-- the list, read again when the tab opens (a new scene shows up without a restart)
local scenes = nil
local wasOpen = false

local function groupsOpen()
    state.rightColumn.sceneGroups = state.rightColumn.sceneGroups
        or { rooms = true, spikes = true, tests = false, tech = false }
    return state.rightColumn.sceneGroups
end

-- `text` cut to fit `width` in the UI font, with an ellipsis
local function fit(text, width)
    if ui.font:getWidth(text) <= width then return text end
    while #text > 1 and ui.font:getWidth(text .. '…') > width do text = text:sub(1, -2) end
    return text .. '…'
end

-- called every frame the right column draws; true while this tab is the one shown
function lib.tick(open)
    if open and not wasOpen then scenes = nil end
    wasOpen = open
end

function lib.draw(x, y, w, h)
    scenes = scenes or catalog.list()
    local rowH = ui.theme.button.height
    local gap = ui.theme.spacing
    local open = groupsOpen()
    local picked = state.rightColumn.pickedScene
    ui.panel(x, y, w, h, 'scenes', function()
        ui.scrollPanel('scenes-panel', x, y + ui.theme.panelHeader, w, h - ui.theme.panelHeader - 5, function()
            local rowX, rowY, rowW = x + 10, y + ui.theme.panelHeader + gap, w - 20
            ui.label(rowX, rowY, fit('now: ' .. tostring(state.scene.id or '?'), rowW), DIM)
            rowY = rowY + ui.fontHeight + gap * 2
            local group = nil
            for _, scene in ipairs(scenes) do
                if scene.group ~= group then
                    group = scene.group
                    local note = catalog.folderNote(group)
                    if ui.header_button(rowX, rowY, rowW, ' ' .. group .. (note and ('  ' .. note) or ''),
                            open[group]) then
                        open[group] = not open[group]
                    end
                    rowY = rowY + rowH + gap
                end
                if open[group] then
                    local label = ' ' .. scene.name .. (scene.scriptOnly and '  (runs on this scene)' or '')
                    if ui.button(rowX, rowY, rowW, fit(label, rowW - 10), nil,
                            picked == scene.id and ui.theme.header.active or nil) then
                        state.rightColumn.pickedScene = (picked ~= scene.id) and scene.id or nil
                        picked = state.rightColumn.pickedScene
                    end
                    rowY = rowY + rowH + 2
                    if scene.note ~= '' then
                        ui.label(rowX + 8, rowY, fit(scene.note, rowW - 8), DIM)
                        rowY = rowY + ui.fontHeight + 2
                    end
                    if picked == scene.id then
                        local bw = math.floor((rowW - gap) / 2)
                        local first = scene.scriptOnly and 'run on this scene' or 'load'
                        if ui.button(rowX, rowY, bw, first) then
                            catalog.request(scene, false)
                            state.rightColumn.pickedScene = nil
                        end
                        if ui.button(rowX + bw + gap, rowY, bw, scene.scriptOnly and 'run + play' or 'load + play') then
                            catalog.request(scene, true)
                            state.rightColumn.pickedScene = nil
                        end
                        rowY = rowY + rowH + 2
                        if not scene.scriptOnly then
                            ui.label(rowX + 8, rowY, fit('replaces what is on the stage now', rowW - 8), DIM)
                            rowY = rowY + ui.fontHeight + 2
                        end
                    end
                    rowY = rowY + gap
                end
            end
        end)
    end)
end

return lib

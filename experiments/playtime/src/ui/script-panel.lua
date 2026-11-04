-- script-panel.lua — the panel a scene script draws (its own sliders: the sea, the clouds, the
-- burrow...), with a button to fold it away. Scene scripts get this as `ui.panel` (src/script.lua);
-- the editor's own panels keep the plain one. Folded, the panel is a small tab with its name, at
-- its bottom corner for a panel in the bottom half of the screen, else at its top; a click on the
-- tab opens it again. Which panels are folded is kept on state by label, so it survives a hot
-- reload and a scene reload.
local ui = require('src.ui.all')
local state = require('src.state')

local lib = {}

state.scriptPanels = state.scriptPanels or {}
local folded = state.scriptPanels

local BUTTON = 28
local TAB_H = 36

function lib.isFolded(label)
    return label ~= nil and folded[label] == true
end

function lib.panel(x, y, width, height, label, drawFunc, optionalFillColor)
    local key = label or '?'
    if folded[key] then
        local text = (label or 'panel') .. '  +'
        local tabW = ui.font:getWidth(text) + 30
        local _, sh = ui.getDimensions()
        local ty = (y + height / 2 > sh / 2) and (y + height - TAB_H) or y
        if ui.button(x, ty, tabW, text, TAB_H) then folded[key] = nil end
        return
    end
    ui.panel(x, y, width, height, label, function()
        if drawFunc then drawFunc() end
        if ui.button(x + width - BUTTON - 6, y + 4, BUTTON, '–', BUTTON) then folded[key] = true end
    end, optionalFillColor)
end

return lib

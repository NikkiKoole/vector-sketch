local lib = {}

local ui = require('src.ui.all')
local state = require('src.state')
local inspector = require('src.ui.inspector')
local worldParams = require('src.world-params')

local PANEL_WIDTH = ui.theme.panelWidth
local START_X, START_Y = 440, 70

local usedHeight = 300 -- last frame's content height; the panel grows/shrinks with the fold

function lib.drawWorldSettingsUI()
    local _, h = love.graphics.getDimensions()
    local panelHeight = math.min(usedHeight + 70, h - START_Y - 20)
    worldParams.tick(state.world)
    ui.panel(START_X, START_Y, PANEL_WIDTH, panelHeight, '• ∫ƒF§ world •', function()
        local header = ui.theme.panelHeader
        ui.scrollPanel('world-panel', START_X, START_Y + header, PANEL_WIDTH, panelHeight - header - 5, function()
            usedHeight = inspector.drawParams('world', worldParams.rows, state.world, nil,
                START_X + 10, START_Y + ui.theme.panelHeader + 10, PANEL_WIDTH - 20)
        end)
    end)
end

return lib

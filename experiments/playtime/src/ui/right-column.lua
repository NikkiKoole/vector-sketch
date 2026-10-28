-- The right column: a fixed rect on the right with tabs on top
-- (properties | on stage | library). The tab choice lives on state, so it
-- survives hot reload. See docs/EDITOR-INSPECTOR-LIBRARY.md.
local lib = {}

local ui = require('src.ui.all')
local state = require('src.state')
local onStage = require('src.ui.on-stage')
local libraryTab = require('src.ui.library-tab')

lib.TABS = { 'properties', 'on stage', 'library' }

-- the whole column: x, y, w, h
function lib.rect()
    local w, h = love.graphics.getDimensions()
    local top, width = ui.theme.columnTop, ui.theme.panelWidth -- below the toolbar row
    return w - width - 20, top, width, h - top - 20
end

-- the area under the tab bar, where a tab draws its panel
function lib.contentRect()
    local x, y, w, h = lib.rect()
    local tabH = ui.theme.button.height + ui.theme.spacing
    return x, y + tabH, w, h - tabH
end

local function drawTabBar()
    local x, y, w = lib.rect()
    local tabW = w / #lib.TABS
    ui.panel(x, y, w, ui.theme.button.height, nil) -- so clicks on the bar don't reach the stage
    for i, name in ipairs(lib.TABS) do
        if ui.header_button(x + (i - 1) * tabW, y, tabW, ' ' .. name, state.rightColumn.tab == name) then
            state.rightColumn.tab = name
        end
    end
end

-- a short panel, so an empty tab doesn't hide the stage
local function drawNote(title, text)
    local x, y, w = lib.contentRect()
    ui.panel(x, y, w, 80, title, function()
        ui.label(x + 10, y + 40, text)
    end)
end

-- while a scene script plays, a click drags instead of selecting
-- (src/input-manager.lua), so the empty properties tab offers a pause button
local function drawPauseToEdit()
    local x, y, w = lib.contentRect()
    ui.panel(x, y, w, 120, 'properties', function()
        ui.label(x + 10, y + 40, 'pause to edit')
        if ui.button(x + 10, y + 75, w - 20, 'pause') then
            state.world.paused = true
        end
    end)
end

-- a file dropped on the open library tab goes to the library; true when taken
function lib.fileDropped(file)
    if state.rightColumn.tab ~= 'library' then return false end
    local x, y, w, h = lib.rect()
    return libraryTab.fileDropped(file, x, y, w, h)
end

-- drawProperties(x, y, w, h) draws the selection's panel and returns true,
-- or returns false when nothing is selected
function lib.draw(drawProperties)
    drawTabBar()
    local tab = state.rightColumn.tab
    if tab == 'properties' then
        if not drawProperties(lib.contentRect()) then
            if state.scene.sceneScript and not state.world.paused then
                drawPauseToEdit()
            else
                drawNote('properties', 'click something on the stage')
            end
        end
    elseif tab == 'on stage' then
        onStage.draw(lib.contentRect())
    elseif tab == 'library' then
        libraryTab.draw(lib.contentRect())
    end
end

return lib

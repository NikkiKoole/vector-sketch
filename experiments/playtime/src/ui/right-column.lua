-- The right column: a fixed rect on the right with tabs on top
-- (properties | on stage | library). The tab choice lives on state, so it
-- survives hot reload. See docs/EDITOR-INSPECTOR-LIBRARY.md.
local lib = {}

local ui = require('src.ui.all')
local state = require('src.state')

lib.TABS = { 'properties', 'on stage', 'library' }
lib.WIDTH = 300
local TOP = 70 -- below the toolbar row, like the other panels
local GAP = 10

-- the whole column: x, y, w, h
function lib.rect()
    local w, h = love.graphics.getDimensions()
    return w - lib.WIDTH - 20, TOP, lib.WIDTH, h - TOP - 20
end

-- the area under the tab bar, where a tab draws its panel
function lib.contentRect()
    local x, y, w, h = lib.rect()
    local tabH = ui.theme.button.height + GAP
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

-- drawProperties(x, y, w, h) draws the selection's panel and returns true,
-- or returns false when nothing is selected
function lib.draw(drawProperties)
    drawTabBar()
    local tab = state.rightColumn.tab
    if tab == 'properties' then
        if not drawProperties(lib.contentRect()) then
            drawNote('properties', 'click something on the stage')
        end
    elseif tab == 'on stage' then
        drawNote('on stage', 'coming soon')
    elseif tab == 'library' then
        drawNote('library', 'coming soon')
    end
end

return lib

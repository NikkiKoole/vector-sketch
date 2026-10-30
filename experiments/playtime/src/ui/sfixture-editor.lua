-- ui/sfixture-editor.lua
-- The panel for the selected sfixture: label and destroy for every kind, the simple kinds from
-- src/sfixture-params.lua, TEXFIXTURE in accordions from src/texfixture-params.lua, MESHUSERT in
-- src/ui/meshusert-panel.lua and RESOURCE in src/ui/resource-panel.lua.
local lib = {}

local ui = require('src.ui.all')
local state = require('src.state')
local subtypes = require('src.subtypes')
local inspector = require('src.ui.inspector')
local sfixtureParams = require('src.sfixture-params')
local meshusertPanel = require('src.ui.meshusert-panel')
local resourcePanel = require('src.ui.resource-panel')
local texfixtureParams = require('src.texfixture-params')

local PANEL_WIDTH = ui.theme.panelWidth
local BUTTON_HEIGHT = ui.theme.lineHeight
local ROW_WIDTH = ui.theme.rowWidth
local BUTTON_SPACING = ui.theme.spacing

local accordionStatesSF = {
    ['position'] = false,
    ['texture'] = true,
    ['patch1'] = false,
    ['patch2'] = false,
    ['patch3'] = false,
}

local lastSFixtureForCleanup = nil

-- Draw every accordion open (spec/ui-overflow_spec.lua measures the fully open panel).
local forceOpen = false
function lib.setAllAccordions(open) forceOpen = open end
-- the triangle painter's, kept here for whoever called them from the editor
lib.assignTrianglesToGroup = meshusertPanel.assignTrianglesToGroup
lib.assignTrianglesToBone = meshusertPanel.assignTrianglesToBone

-- panelX, panelY, panelWidth, panelH: the panel rect (default: the right edge, full height)
function lib.drawSelectedSFixture(panelX, panelY, panelWidth, panelH)
    local w, h = love.graphics.getDimensions()
    panelWidth = panelWidth or PANEL_WIDTH
    panelX, panelY, panelH = panelX or (w - panelWidth - 20), panelY or 20, panelH or (h - 40)
    if lastSFixtureForCleanup ~= state.selection.selectedSFixture then
        lastSFixtureForCleanup = state.selection.selectedSFixture
        if state.panelVisibility.showPalette then
            state.panelVisibility.showPalette = nil
            state.showPaletteFunc = nil
        end
        state.texFixtureEdit.tempVerts = nil
        state.texFixtureEdit.centroid = nil
        state.texFixtureEdit.lockedVerts = true
        state.texFixtureEdit.dragIdx = 0
    end
    if state.selection.selectedSFixture:isDestroyed() then return end
    local ud = state.selection.selectedSFixture:getUserData()

    local sfixtureType = ud.subtype or ud.type -- the panel title: what kind of fixture
    local x, y
    -- Function to create an accordion
    local function drawAccordion(key, contentFunc)
        -- Draw the accordion header

        local clicked = ui.header_button(x, y, PANEL_WIDTH - 40, (accordionStatesSF[key] and " ÷  " or " •") ..
            ' ' .. key, accordionStatesSF[key])
        if clicked then
            accordionStatesSF[key] = not accordionStatesSF[key]
        end
        y = y + BUTTON_HEIGHT + BUTTON_SPACING

        if accordionStatesSF[key] or forceOpen then
            contentFunc(clicked)
        end
    end

    local function drawContent()
        local padding = BUTTON_SPACING
        local layout = ui.createLayout({
            type = 'columns',
            spacing = BUTTON_SPACING,
            startX = panelX + 20,
            startY = panelY + ui.theme.contentTop + padding
        })
        x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
        local nextRow = function()
            x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
        end
        -- for the MESHUSERT and RESOURCE panels: the next row's x, y
        local function advance()
            nextRow()
            return x, y
        end

        local myID = state.selection.selectedSFixture:getUserData().id
        -- label + destroy for every kind; the simple kinds draw all their settings
        -- from src/sfixture-params.lua, the rest keep their hand-made sections below
        local subtypeRows = sfixtureParams.bySubtype[ud.subtype]
        local rows = {}
        for _, row in ipairs(sfixtureParams.header) do rows[#rows + 1] = row end
        for _, row in ipairs(subtypeRows or {}) do rows[#rows + 1] = row end
        for _, row in ipairs(sfixtureParams.footer) do rows[#rows + 1] = row end
        local used, replaced = inspector.drawParams('sfixture_' .. tostring(myID), rows,
            state.selection.selectedSFixture, nil, x, y, 270)
        if replaced ~= nil or subtypeRows then return end
        layout.curY = y + used
        nextRow()

        if subtypes.is(ud, subtypes.TEXFIXTURE) then
            -- every setting from src/texfixture-params.lua, one inspector list per accordion
            local fixture = state.selection.selectedSFixture
            local function section(name, sectionRows)
                local gone
                drawAccordion(name, function()
                    local height, newFixture = inspector.drawParams('texfix_' .. name .. '_' .. tostring(myID),
                        sectionRows, fixture, nil, x, y, 270)
                    y = y + height
                    gone = newFixture ~= nil
                end)
                layout.curY = y
                nextRow()
                return gone
            end
            if section('position', texfixtureParams.position) then return end
            if section('texture', texfixtureParams.texture) then return end
            local e = fixture:getUserData().extra
            if e.hairs and section('hairs', texfixtureParams.hairs) then return end
            if e.plasticine and section('plasticine', texfixtureParams.plasticine) then return end
            for _, layer in ipairs({ 'patch1', 'patch2', 'patch3' }) do
                if section(layer, texfixtureParams.patch(layer)) then return end
            end
        elseif subtypes.is(ud, subtypes.MESHUSERT) then
            meshusertPanel.draw(ud, myID, x, y, advance)
        elseif subtypes.is(ud, subtypes.RESOURCE) then
            resourcePanel.draw(ud, myID, x, y, advance)
        end

        nextRow()
    end

    ui.panel(panelX, panelY, panelWidth, panelH, '∞ ' .. sfixtureType .. ' ∞', function()
        -- content scrolls when it doesn't fit (spec/ui-overflow_spec.lua)
        local header = ui.theme.panelHeader
        ui.scrollPanel('sfixture-panel', panelX, panelY + header, panelWidth, panelH - header - 5, drawContent)
    end)
end

return lib

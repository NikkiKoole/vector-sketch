local lib = {}

-- The Mipo editor panel, the front (CODE-SPLITS-2026-10.md SPLIT3): the title, the symmetric toggle
-- and the order of the accordions. They are drawn by src/ui/mipo/body-panel.lua (creation,
-- positioners, actions, shape, dims, randomize), look-panel.lua (skin, bodyhair, haircut, connected
-- skin and hair) and face-panel.lua; widgets.lua holds what they share.
local widgets = require('src.ui.mipo.widgets')
local bodyPanel = require('src.ui.mipo.body-panel')
local lookPanel = require('src.ui.mipo.look-panel')
local facePanel = require('src.ui.mipo.face-panel')
local ui = widgets.ui
local accordionStates = widgets.accordionStates

local PANEL_WIDTH = ui.theme.panelWidth
local BUTTON_HEIGHT = ui.theme.lineHeight
local BUTTON_SPACING = ui.theme.spacing

function lib.shapePartFor(...) return bodyPanel.shapePartFor(...) end

function lib.drawMipoEditor(instance, partName, panelX, panelY, panelWidth, panelH)
    local w, h = ui.getDimensions()
    panelWidth = panelWidth or PANEL_WIDTH
    panelX, panelY, panelH = panelX or (w - panelWidth - 20), panelY or 20, panelH or (h - 40)
    widgets.setEditing(instance)
    ui.scrollableList('mipo_scroll', panelX, panelY, panelWidth, panelH,
        function(_sx, _sy, _sw, _sh, scrollOffset)
        local padding = BUTTON_SPACING
        local x = panelX + padding
        local y = panelY + padding + (scrollOffset or 0)
        local ROW = BUTTON_HEIGHT + BUTTON_SPACING
        local startY = y

        -- Title
        ui.label(x, y, 'mipo: ' .. (partName or '?'))
        y = y + ROW

        -- Header info
        local partCount = 0
        for _ in pairs(instance.parts) do partCount = partCount + 1 end
        ui.label(x, y, 'parts: ' .. partCount .. '  scale: ' .. string.format('%.2f', instance.scale or 1))
        y = y + ROW

        -- Symmetric editing toggle
        local symClicked, symChecked = ui.checkbox(x, y, accordionStates.symmetricEditing, 'symmetric')
        if symClicked then accordionStates.symmetricEditing = symChecked end
        y = y + ROW

        local p = { instance = instance, partName = partName, x = x, panelX = panelX, panelWidth = panelWidth,
            ROW = ROW }
        y = bodyPanel.drawCreation(p, y)
        y = bodyPanel.drawPositioners(p, y)
        y = bodyPanel.drawActions(p, y)
        y = bodyPanel.drawShape(p, y)
        y = bodyPanel.drawDims(p, y)
        p.partData = instance.dna.parts[partName] -- after creation, shape and dims: they rebuild
        y = lookPanel.drawSkin(p, y)
        y = lookPanel.drawBodyhair(p, y)
        y = facePanel.draw(p, y)
        y = lookPanel.drawHaircut(p, y)
        y = lookPanel.drawConnectedSkin(p, y)
        y = lookPanel.drawConnectedHair(p, y)
        y = bodyPanel.drawRandomize(p, y)

        return y - startY
    end)
end

lib._test = { accordionStates = accordionStates, -- for specs
    partAndMirror = widgets.partAndMirror, editPartAndMirror = widgets.editPartAndMirror,
    bodyhairParts = widgets.bodyhairParts }

return lib

local lib = {}

-- The Mipo editor panel, the front (CODE-SPLITS-2026-10.md SPLIT3): the order of its rows. The whole
-- Mipo first, then the part, then the workshop (docs/KINDS.md). Drawn by src/ui/mipo/kind-panel.lua
-- (breed, roll, actions, copy, delete; the part row; the workshop), body-panel.lua (proportions, build,
-- shape, dims), look-panel.lua (skin, bodyhair, haircut, connected skin and hair) and face-panel.lua;
-- widgets.lua holds what they share.
local widgets = require('src.ui.mipo.widgets')
local bodyPanel = require('src.ui.mipo.body-panel')
local lookPanel = require('src.ui.mipo.look-panel')
local facePanel = require('src.ui.mipo.face-panel')
local faceHandles = require('src.ui.mipo.face-handles')
local kindPanel = require('src.ui.mipo.kind-panel')
local mipoRegistry = require('src.mipo-registry')
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

        local p = { instance = instance, partName = partName, x = x, panelX = panelX, panelWidth = panelWidth,
            ROW = ROW }
        -- the whole Mipo first, the same whichever part was clicked (docs/KINDS.md)
        local gone
        y, gone = kindPanel.drawHead(p, y)
        if gone then return y - startY end -- deleted

        -- then the part: < name > to any part, its own sections
        y = kindPanel.drawPartRow(p, y)
        local ghost = kindPanel.ghostView(p)
        if ghost == 'neck' then
            y = bodyPanel.drawNeck(p, y) -- a faint part picked: no body to select, its settings
        elseif ghost == 'nose' then
            y = bodyPanel.drawNose(p, y)
        elseif partName then
            y = kindPanel.drawTabs(p, y) -- the sections' headers as small buttons
            widgets.beginTabs()
            if partName:match('^neck%d') then y = bodyPanel.drawNeck(p, y, true) end
            if partName:match('^nose%d') then y = bodyPanel.drawNose(p, y, true) end
            y = bodyPanel.drawTorso(p, y)
            y = bodyPanel.drawPlace(p, y)
            y = bodyPanel.drawShape(p, y)
            y = bodyPanel.drawDims(p, y)
            p.partData = instance.dna.parts[partName] -- after creation, shape and dims: they rebuild
            y = lookPanel.drawSkin(p, y)
            y = lookPanel.drawBodyhair(p, y)
            y = facePanel.draw(p, y)
            y = lookPanel.drawHaircut(p, y)
            y = lookPanel.drawConnectedSkin(p, y)
            y = lookPanel.drawConnectedHair(p, y)
            widgets.endTabs(partName)
            y = kindPanel.drawPartRandomize(p, y)
        end

        y = kindPanel.drawWorkshop(p, y)
        return y - startY
    end)
    -- the face's handles on the Mipo itself while its face section is open (BESPOKE-UI BU3), after
    -- the list (it clips to itself)
    if partName and widgets.isOpen(partName .. ' face') and mipoRegistry.getById(instance.id) then
        faceHandles.draw(instance)
    end
end

lib._test = { accordionStates = accordionStates, -- for specs
    partAndMirror = widgets.partAndMirror, editPartAndMirror = widgets.editPartAndMirror,
    bodyhairParts = widgets.bodyhairParts }

return lib

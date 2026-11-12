-- src/ui/kind-editor.lua: the properties panel for a part of a kind's instance (src/kinds.lua, docs/KINDS.md
-- KD4a): the whole first (its name, copy, delete), then which part was clicked, and dissolve (plain bodies,
-- the workshop's). Its own settings and a picture to pick parts on come in KD4b, shaped like the Mipo's.
local lib = {}

local ui = require('src.ui.all')
local state = require('src.state')
local kinds = require('src.kinds')
local library = require('src.library')

local function selectThing(thing)
    local sel = state.selection
    sel.selectedObj, sel.selectedBodies, sel.selectedJoint, sel.selectedSFixture = thing, nil, nil, nil
end

function lib.draw(instance, partName, panelX, panelY, panelWidth, panelH)
    ui.scrollableList('kind_scroll', panelX, panelY, panelWidth, panelH, function(_, _, _, _, scrollOffset)
        local pad = ui.theme.spacing
        local ROW = ui.theme.lineHeight + ui.theme.spacing
        local x, y = panelX + pad, panelY + pad + (scrollOffset or 0)
        local startY = y
        local W = panelWidth - 40
        local bw = math.floor(W / 3)

        ui.label(x, y, instance.kind .. ': ' .. kinds.label(instance))
        local thing = state.selection.selectedObj
        if thing and ui.button(x + W - 2 * bw - 4, y, bw, 'copy') then
            -- library.clone brings the whole instance; the copy's same part gets selected
            for _, copy in ipairs(library.clone({ thing })) do
                if copy.kindPart == partName then selectThing(copy) break end
            end
        end
        if ui.button(x + W - bw, y, bw, 'delete') then
            kinds.remove(instance)
            selectThing(nil)
            return y + ROW - startY
        end
        y = y + ROW

        ui.label(x, y, 'part: ' .. tostring(partName))
        y = y + ROW
        ui.label(x, y, 'its settings and parts: next (KINDS KD4b)')
        y = y + ROW

        -- dissolve: the parts become plain bodies, to change in the workshop
        if ui.button(x, y, math.floor(W / 2) - 2, 'dissolve') then
            kinds.dissolve(instance)
        end
        y = y + ROW
        return y - startY
    end)
end

return lib

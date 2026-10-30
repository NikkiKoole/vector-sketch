-- ui/resource-panel.lua
-- The RESOURCE part of the sfixture panel (src/ui/sfixture-editor.lua): which backdrop's picture it
-- uses (outlined on stage), its mesh kept fresh (src/cdt.lua), clear splits, centre on the body.
-- Split out of sfixture-editor.lua (CODE-SPLITS-2026-10.md SPLIT4).
local mathutils = require('src.math-utils')
local ui = require('src.ui.all')
local camera = require('src.camera')
local cam = camera.getInstance()
local fixtures = require('src.fixtures')
local state = require('src.state')
local resourceLink = require('src.resource-link')
local cdt = require('src.cdt')
local utils = require('src.utils')

local lib = {}

local BUTTON_HEIGHT = ui.theme.lineHeight
local ROW_WIDTH = ui.theme.rowWidth

-- Draws the rows from x, y down; advance() moves to the next row and returns its x, y.
function lib.draw(ud, myID, x, y, advance)
    local function nextRow() x, y = advance() end
        do
            ui.label(x, y, 'backdrop index (for uvmap)')
            nextRow()
            -- shows the backdrop with this RESOURCE's image (0: not on stage);
            -- typing another index makes that backdrop's image its picture
            local b = resourceLink.backdrop(ud)
            local shownIndex = 0
            for i, bd in ipairs(state.backdrops) do
                if bd == b then shownIndex = i end
            end
            local numericInputText, changed = ui.textinput(myID .. 'backdropindex', x, y, 90, BUTTON_HEIGHT, ".",
                "" .. shownIndex, true)
            local typedIndex = changed and tonumber(numericInputText)
            if typedIndex and state.backdrops[typedIndex] then
                b = state.backdrops[typedIndex]
                ud.extra.imageURL = b.url
                ud.extra.selectedBGIndex = typedIndex
            end
            if b then

                -- first we draw a YELLOW border around the backdrop
                ui.onStage(function()
                    local x1, y1 = cam:getScreenCoordinates(b.x, b.y)
                    local x2, y2 = cam:getScreenCoordinates(b.x + b.w, b.y + b.h)
                    love.graphics.setColor(1, 1, 0)
                    love.graphics.rectangle('line', x1, y1, x2 - x1, y2 - y1)
                    love.graphics.setColor(1, 1, 1)
                end)

                local bod = state.selection.selectedSFixture:getBody()

                -- UVs + triangles from `src/cdt.lua` (strip for ribbons, authored with
                -- split points, else ear-clip), made again only when the body, the
                -- backdrop, the outline or the splits changed
                cdt.refreshResourceMesh(ud, bod, b)
            end
        end
        nextRow()

        -- Path B: Steiners live on the body, not the RESOURCE.
        local resBody = state.selection.selectedSFixture:getBody()
        local resBodyThing = resBody and utils.thingOf(resBody)
        if resBodyThing and resBodyThing.extraSteiner and #resBodyThing.extraSteiner > 0 then
            local numSplits = #resBodyThing.extraSteiner / 2
            if ui.button(x, y, ROW_WIDTH + 50, 'clear splits (' .. numSplits .. ')') then
                resBodyThing.extraSteiner = nil
                local bd = resourceLink.backdrop(ud)
                if bd then
                    cdt.computeResourceMesh(ud, resBody, bd, mathutils)
                end
            end
            nextRow()
        end

        if ui.button(x, y, 50, 'c') then
            local body = state.selection.selectedSFixture:getBody()
            state.selection.selectedSFixture = fixtures.updateSFixturePosition(state.selection.selectedSFixture,
                body:getX(), body:getY())
        end
        nextRow()
end

return lib

local lib = {}

local ui = require('src.ui.all')
local state = require('src.state')
local modes = require('src.modes')
local objectManager = require('src.object-manager')
local camera = require('src.camera')
local cam = camera.getInstance()
local box2dPointerJoints = require('src.physics.box2d-pointerjoints')
local fixtures = require('src.fixtures')
local mathutils = require('src.math-utils')
local ST = require('src.shape-types')

local getCenterAndDimensions = mathutils.getCenterAndDimensions

local BUTTON_HEIGHT = ui.theme.lineHeight
local BUTTON_SPACING = 10

local accordeonStatesAS = {
    ['more'] = false
}

function lib.drawAddShapeUI()
    local shapeTypesLess = { ST.RECTANGLE, ST.CIRCLE, ST.CAPSULE, ST.RIBBON }
    local shapeTypesMore = { ST.RECTANGLE, ST.CIRCLE, ST.CAPSULE, ST.TRIANGLE,
        ST.ITRIANGLE, ST.TORSO, ST.TRAPEZIUM, ST.PENTAGON,
        ST.HEXAGON,
        ST.HEPTAGON,
        ST.OCTAGON }
    local shapeTypes = accordeonStatesAS['more'] and shapeTypesMore or shapeTypesLess
    local titleHeight = ui.font:getHeight() + BUTTON_SPACING
    local startX = 20
    local startY = 70
    local panelWidth = 200
    local buttonSpacing = BUTTON_SPACING
    local buttonHeight = ui.theme.button.height
    local panelHeight = titleHeight + ((#shapeTypes + 10) * (buttonHeight + buttonSpacing)) + buttonSpacing

    ui.panel(startX, startY, panelWidth, panelHeight, '', function()
        local layout = ui.createLayout({
            type = 'columns',
            spacing = BUTTON_SPACING,
            startX = startX + BUTTON_SPACING,
            startY = startY + BUTTON_SPACING
        })

        local x, y = ui.nextLayoutPosition(layout, panelWidth - 20, buttonHeight)

        local nextRow = function()
            x, y = ui.nextLayoutPosition(layout, panelWidth - 20, buttonHeight)
        end

        local function drawAccordion(key, contentFunc)
            -- Draw the accordion header

            local clicked = ui.header_button(x, y, panelWidth - 40, (accordeonStatesAS[key] and " ÷  " or " •") ..
                ' ' .. key, accordeonStatesAS[key])
            if clicked then
                accordeonStatesAS[key] = not accordeonStatesAS[key]
            end
            y = y + BUTTON_HEIGHT + BUTTON_SPACING


            if accordeonStatesAS[key] then
                contentFunc(clicked)
            end
        end
        if ui.button(x, y, panelWidth - 20, 'add mipo') then
            local mx, my = love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)
            local CharacterManager = require('src.character-manager')
            local uiMipoEditor = require('src.ui.mipo-editor')
            local instance = CharacterManager.createCharacter("humanoid", wx, wy, 0.3)
            if instance then
                uiMipoEditor.randomizeMipo(instance)
            end
        end
        nextRow()
        drawAccordion('more', function() end)
        nextRow()
        for _, shape in ipairs(shapeTypes) do
            local width = panelWidth - 20

            local _, pressed, released = ui.button(x, y, width, shape)
            if pressed then
                ui.draggingActive = ui.activeElementID
                local mx, my = love.mouse.getPosition()
                local wx, wy = cam:getWorldCoordinates(mx, my)
                objectManager.startSpawn(shape, wx, wy)
            end
            if released then
                ui.draggingActive = nil
            end
            nextRow()
        end
        love.graphics.line(x, y + 20, x + 20 + panelWidth - 40, y + 20)

        local width = panelWidth - 20
        nextRow()

        local minDist = ui.sliderWithInput('minDistance', x, y, 80, 1, 150,
            state.editorPreferences.minPointDistance or 10)
        ui.alignedLabel(x, y, '  dis')
        if minDist then
            state.editorPreferences.minPointDistance = minDist
        end


        nextRow()
        local freePathColor = modes.is(modes.DRAW_FREE_PATH) and { 1, 0, 0 } or nil
        local _, _, freePathReleased = ui.button(x, y, width, 'freepath', buttonHeight, freePathColor)
        if freePathReleased then
            modes.set(modes.DRAW_FREE_PATH)
            state.interaction.polyVerts = {}
            state.interaction.lastPolyPt = nil
        end
        -- Add a button for custom polygon
        nextRow()
        local freePolyColor = modes.is(modes.DRAW_FREE_POLY) and { 1, 0, 0 } or nil
        local _, _, freePolyReleased = ui.button(x, y, width, 'freeform', buttonHeight, freePolyColor)
        if freePolyReleased then
            modes.set(modes.DRAW_FREE_POLY)
            state.interaction.polyVerts = {}
            state.interaction.lastPolyPt = nil
        end
        nextRow()
        local clickModeColor = modes.is(modes.DRAW_CLICK) and { 1, 0, 0 } or nil
        if ui.button(x, y, width, 'click', buttonHeight, clickModeColor) then
            modes.set(modes.DRAW_CLICK)
            state.interaction.polyVerts = {}
            state.interaction.lastPolyPt = nil
        end
        nextRow()

        -- width already defined above as panelWidth - 20

        local function handleFixtureButton(bx, by, bw, label, shapeType, extraDataFunc)
            local _, pressed, released = ui.button(bx, by, bw, label)

            if pressed then
                ui.draggingActive = ui.activeElementID
                state.interaction.offsetDragging = { 0, 0 }
            end

            if released then
                local mx, my = love.mouse.getPosition()
                local wx, wy = cam:getWorldCoordinates(mx, my)
                local _, hitted = box2dPointerJoints.handlePointerPressed(wx, wy, 'mouse', {}, not state.world.paused)
                if #hitted > 0 then
                    local body = hitted[#hitted]:getBody()
                    local localX, localY = body:getLocalPoint(wx, wy)
                    local extraData = extraDataFunc and extraDataFunc(body, localX, localY) or { radius = 30 }
                    local fixture = fixtures.createSFixture(body, localX, localY, shapeType, extraData)
                    state.selection.selectedSFixture = fixture
                end
                ui.draggingActive = nil
            end

            nextRow()
        end

        handleFixtureButton(x, y, width, 'snapfixture', 'snap')
        handleFixtureButton(x, y, width, 'anchorfixture', 'anchor')
        handleFixtureButton(x, y, width, 'texturefixture', 'texfixture', function(body)
            local _, _, w, h = getCenterAndDimensions(body)
            return { width = w, height = h }
        end)
        handleFixtureButton(x, y, width, 'connectedtexture', 'connected-texture')
        handleFixtureButton(x, y, width, 'trace-vertices', 'trace-vertices')
        handleFixtureButton(x, y, width, 'tile-repeat', 'tile-repeat')
        handleFixtureButton(x, y, width, 'uvusert', 'uvusert')
        handleFixtureButton(x, y, width, 'resource', 'resource')
        handleFixtureButton(x, y, width, 'meshusert', 'meshusert')
        if ui.button(x, y, width, 'auto-ropify') then
            -- todo make this work
            modes.set(modes.PICK_AUTO_ROPIFY)
        end
        nextRow()
        love.graphics.line(x, y + 10, x + panelWidth - 40, y + 10)
        nextRow()
    end)
end

return lib

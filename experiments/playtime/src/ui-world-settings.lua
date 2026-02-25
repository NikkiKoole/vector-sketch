local lib = {}

local ui = require('src.ui-all')
local state = require('src.state')
local registry = require('src.registry')
local ProFi = require('vendor.ProFi')

local PANEL_WIDTH = 300
local BUTTON_HEIGHT = ui.theme.lineHeight
local ROW_WIDTH = 160
local BUTTON_SPACING = 10

local profileFrameCounter = 0

function lib.drawWorldSettingsUI()
    local startX = 440
    local startY = 70
    local panelWidth = PANEL_WIDTH
    --local panelHeight = 255
    local buttonHeight = ui.theme.button.height

    local titleHeight = ui.font:getHeight() + BUTTON_SPACING
    local panelHeight = titleHeight + titleHeight + (14 * (buttonHeight + BUTTON_SPACING) + BUTTON_SPACING)
    ui.panel(startX, startY, panelWidth, panelHeight, '• ∫ƒF§ world •', function()
        local layout = ui.createLayout({
            type = 'columns',
            spacing = BUTTON_SPACING,
            startX = startX + BUTTON_SPACING,
            startY = startY + titleHeight + BUTTON_SPACING
        })
        local width = panelWidth - BUTTON_SPACING * 2

        local x, y = ui.nextLayoutPosition(layout, width, BUTTON_HEIGHT)
        local nextRow = function()
            x, y = ui.nextLayoutPosition(layout, width, BUTTON_HEIGHT)
        end
        --  x, y = ui.nextLayoutPosition(layout, width, 50)
        --  local grav = ui.sliderWithInput('grav', x, y, ROW_WIDTH, -10, BUTTON_HEIGHT, state.world.gravity)
        ui.createSliderWithId('', 'grav', x, y, ROW_WIDTH, -10, 20, state.world.gravity, function(v)
            state.world.gravity = v
            if state.physicsWorld then
                state.physicsWorld:setGravity(0, state.world.gravity * state.world.meter)
            end
        end)

        nextRow()

        local gridChanged, gridValue = ui.checkbox(x, y, state.editorPreferences.showGrid, 'grid')
        if gridChanged then
            state.editorPreferences.showGrid = gridValue
        end
        local slx, sly = ui.sameLine()
        local drawChanged, drawValue = ui.checkbox(slx, sly, state.world.debugDrawMode, 'draw')
        if drawChanged then
            state.world.debugDrawMode = drawValue
        end
        slx, sly = ui.sameLine()
        local modeChanged, modeValue = ui.checkbox(slx, sly, state.world.darkMode, 'mode')
        if modeChanged then
            state.world.darkMode = modeValue
        end
        nextRow()


        ui.createSliderWithId('', 'debugalpha', x, y, ROW_WIDTH, 0, 1, state.world.debugAlpha,
            function(v)
                state.world.debugAlpha = v
            end)

        nextRow()
        if ui.button(x, y, ROW_WIDTH, 'debugids') then
            state.world.showDebugIds = not state.world.showDebugIds
        end
        nextRow()

        ui.createSliderWithId('', 'mouse F', x, y, ROW_WIDTH, 0, 1000000, state.world.mouseForce,
            function(v)
                state.world.mouseForce = v
            end)

        nextRow()

        ui.createSliderWithId('', 'damp', x, y, ROW_WIDTH, 0.001, 1, state.world.mouseDamping, function(v)
            state.world.mouseDamping = v
        end)

        -- Add Speed Multiplier Slider

        nextRow()
        ui.createSliderWithId('', 'speed', x, y, ROW_WIDTH, 0.1, 10.0, state.world.speedMultiplier,
            function(v)
                state.world.speedMultiplier = v
            end)

        nextRow()

        ui.label(x, y, registry.print())
        nextRow()

        if ui.button(x, y, ROW_WIDTH, 'textures') then
            state.world.showTextures = not state.world.showTextures
        end
        nextRow()
        if ui.button(x, y, ROW_WIDTH, 'drawsfixtures') then
            state.world.drawFixtures = not state.world.drawFixtures
        end
        nextRow()
        if ui.button(x, y, ROW_WIDTH, 'drawoutline') then
            state.world.drawOutline = not state.world.drawOutline
        end
        nextRow()
        if ui.button(x, y, ROW_WIDTH, 'dbodies') then
            state.world.debugDrawBodies = not state.world.debugDrawBodies
        end
        nextRow()

        if ui.button(x, y, ROW_WIDTH, 'djoints') then
            state.world.debugDrawJoints = not state.world.debugDrawJoints
        end
        nextRow()

        if ui.button(x, y, ROW_WIDTH, state.world.profiling and 'profiling' or 'profile') then
            if state.world.profiling then
                ProFi:stop()
                ProFi:writeReport('profilingReport.txt')
                state.world.profiling = false
                profileFrameCounter = 0
            else
                profileFrameCounter = 0
                ProFi:start()
                state.world.profiling = true
            end
        end
        if state.world.profiling then
            profileFrameCounter = profileFrameCounter + 1
            print(profileFrameCounter)
            if profileFrameCounter >= 60 then
                ProFi:stop()
                ProFi:writeReport('profilingReport.txt')
                state.world.profiling = false
                profileFrameCounter = 0
            end
        end


        nextRow()


        ui.label(x, y, string.format("%.2f", love.graphics.getStats().texturememory / 1000000) .. ' MB')
        ui.label(x + 150, y, love.graphics.getStats().drawcallsbatched .. 'batched')
    end)
end

return lib

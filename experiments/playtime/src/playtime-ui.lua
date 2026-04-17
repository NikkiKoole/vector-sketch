local lib = {}
local logger = require 'src.logger'

local sceneIO = require 'src.io'

local ui = require('src.ui.all')
local joints = require 'src.joints'
local objectManager = require 'src.object-manager'
local camera = require 'src.camera'
local cam = camera.getInstance()
local utils = require 'src.utils'

local fixtures = require 'src.fixtures'
local snap = require 'src.physics.snap'
local box2dDrawTextured = require 'src.physics.box2d-draw-textured'

local state = require 'src.state'
local modes = require 'src.modes'
local script = require 'src.script'
local sceneLoader = require 'src.scene-loader'
local subtypes = require 'src.subtypes'
local SE = require('src.script-events')
local behaviors = require 'src.behaviors'
local uiWorldSettings = require('src.ui.world-settings')
local uiJointUpdate = require('src.ui.joint-update')
local uiShapePanel = require('src.ui.shape-panel')
local uiRecordingPanel = require('src.ui.recording-panel')
local uiSFixtureEditor = require('src.ui.sfixture-editor')
local uiBodyEditor = require('src.ui.body-editor')
local uiMipoEditor = require('src.ui.mipo-editor')
local mipoRegistry = require('src.mipo-registry')
local PANEL_WIDTH = 300
local BUTTON_HEIGHT = ui.theme.lineHeight
local ROW_WIDTH = 160
local BUTTON_SPACING = 10



function lib.assignTrianglesToGroup(...) return uiSFixtureEditor.assignTrianglesToGroup(...) end


function lib.drawJointCreateUI(panelX, panelY, w, h)
    ui.panel(panelX, panelY, w, h, '∞ ' .. state.jointParams.jointType .. ' ∞', function()
        local layout = ui.createLayout({
            type = 'columns',
            spacing = 10,
            startX = panelX + 10,
            startY = panelY + 10
        })

        local width = 180
        local x, y = ui.nextLayoutPosition(layout, 160, BUTTON_HEIGHT)
        local nextRow = function()
            x, y = ui.nextLayoutPosition(layout, 160, BUTTON_HEIGHT)
        end
        nextRow()
        if ui.button(x, y, width, 'Create') then
            local joint = joints.createJoint(state.jointParams)
            state.selection.selectedJoint = joint
            state.selection.selectedObject = nil
            state.jointParams = nil
            modes.clear()
        end

        if ui.button(x + width + 10, y, width, 'Cancel') then
            state.jointParams = nil
            modes.clear()
        end
    end)
end

function lib.drawJointUpdateUI(...) return uiJointUpdate.drawJointUpdateUI(...) end

function lib.drawAddShapeUI(...) return uiShapePanel.drawAddShapeUI(...) end

function lib.drawAddJointUI()
    local JT = require 'src.joint-types'
    local jointTypes = { JT.DISTANCE, JT.WELD, JT.ROPE, JT.REVOLUTE, JT.WHEEL, JT.MOTOR, JT.PRISMATIC, JT.PULLEY,
        JT.FRICTION }
    local startX = 230
    local startY = 70
    local panelWidth = 200
    local buttonSpacing = BUTTON_SPACING
    local buttonHeight = ui.theme.button.height
    local panelHeight = (#jointTypes * (buttonHeight + BUTTON_SPACING) + BUTTON_SPACING)

    ui.panel(startX, startY, panelWidth, panelHeight, '', function()
        local layout = ui.createLayout({
            type = 'columns',
            spacing = buttonSpacing,
            startX = startX + BUTTON_SPACING,
            startY = startY + BUTTON_SPACING
        })
        for _, joint in ipairs(jointTypes) do
            local width = panelWidth - 20
            local height = buttonHeight
            local x, y = ui.nextLayoutPosition(layout, width, height)
            local jointStarted = ui.button(x, y, width, joint)
            if jointStarted then
                state.jointParams = { body1 = nil, body2 = nil, jointType = joint }
                modes.set(modes.JOINT_CREATION)
            end
        end
    end)
end

function lib.drawRecordingUI(...) return uiRecordingPanel.drawRecordingUI(...) end
function lib.drawWorldSettingsUI(...) return uiWorldSettings.drawWorldSettingsUI(...) end

function lib.drawSelectedSFixture(...) return uiSFixtureEditor.drawSelectedSFixture(...) end

function lib.drawSelectedBodiesUI()
    local panelWidth = PANEL_WIDTH
    local w, h = love.graphics.getDimensions()
    ui.panel(w - panelWidth - 20, 20, panelWidth, h - 40, '∞ selection ∞', function()
        local padding = BUTTON_SPACING
        local layout = ui.createLayout({
            type = 'columns',
            spacing = BUTTON_SPACING,
            startX = w - panelWidth,
            startY = 100 + padding
        })

        local x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
        local nextRow = function()
            x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
        end

        if ui.button(x, y, 260, 'clone') then
            local cloned = sceneIO.cloneSelection(state.selection.selectedBodies, state.physicsWorld)
            state.selection.selectedBodies = cloned
        end
        nextRow()

        if ui.button(x, y, 260, 'clone x 10') then
            for _ = 1, 10 do
                local cloned = sceneIO.cloneSelection(state.selection.selectedBodies, state.physicsWorld)
                state.selection.selectedBodies = cloned
            end
            --
        end
        nextRow()

        if ui.button(x, y, 260, 'destroy') then
            for i = #state.selection.selectedBodies, 1, -1 do
                snap.destroySnapJointAboutBody(state.selection.selectedBodies[i].body)
                --print('destroybody doesnt destroy the joint on it ?')
                objectManager.destroyBody(state.selection.selectedBodies[i].body)
            end

            state.selection.selectedBodies = nil
        end
        nextRow()

        if state.selection.selectedBodies and #state.selection.selectedBodies > 0 then
            local fb = state.selection.selectedBodies[1].body
            local fbFixtures = fb:getFixtures()
            local ff = fbFixtures[1]
            local groupIndex = ff:getGroupIndex()
            local groupIndexSlider = ui.sliderWithInput('groupIndex', x, y, 160, -32768, 32767, groupIndex, false, 1)

            if groupIndexSlider then
                local value = math.floor(groupIndexSlider)
                local count = 0
                for i = 1, #state.selection.selectedBodies do
                    local b = state.selection.selectedBodies[i].body
                    local bFixtures = b:getFixtures()
                    for j = 1, #bFixtures do
                        bFixtures[j]:setGroupIndex(value)
                        count = count + 1
                    end
                end
            end
            ui.alignedLabel(x, y, ' groupid')
        end
        -- end
        nextRow()
    end)
end

function lib.drawUpdateSelectedObjectUI(...) return uiBodyEditor.drawUpdateSelectedObjectUI(...) end

function lib.drawBGSettingsUI()
    local startX = 540
    local startY = 70
    local panelWidth = PANEL_WIDTH
    --local panelHeight = 255
    local buttonHeight = ui.theme.button.height

    local titleHeight = ui.font:getHeight() + BUTTON_SPACING
    local panelHeight = titleHeight + titleHeight + (14 * (buttonHeight + BUTTON_SPACING) + BUTTON_SPACING)

    ui.panel(startX, startY, panelWidth, panelHeight, '• backdrops •', function()
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
        local toDelete -- or nil
        local selectedBD
        for i = 1, #state.backdrops do
            if ui.button(x, y, ROW_WIDTH, state.backdrops[i].url) then
                if not state.backdrops[i].selected then
                    for j = 1, #state.backdrops do
                        state.backdrops[j].selected = false
                    end
                end
                state.backdrops[i].selected = not state.backdrops[i].selected
            end
            if ui.button(x + ROW_WIDTH + 10, y, 50, 'x') then
                -- want to delete from the array.
                toDelete = i
            end
            if state.backdrops[i].selected then selectedBD = state.backdrops[i] end
            nextRow()
        end
        if toDelete then
            table.remove(state.backdrops, toDelete)
        end

        -- Per-backdrop controls for the selected one.
        if selectedBD then
            nextRow()
            local newScale = ui.sliderWithInput('bdScale', x, y, ROW_WIDTH, 0.05, 3, selectedBD.scale or 1)
            ui.alignedLabel(x, y, ' scale')
            if newScale then selectedBD.scale = tonumber(newScale) or selectedBD.scale end
            nextRow()
            local fgChanged, fgValue = ui.checkbox(x, y, selectedBD.foreground or false, 'foreground')
            if fgChanged then selectedBD.foreground = fgValue end
            nextRow()
            local borderChanged, borderValue = ui.checkbox(x, y, selectedBD.border or false, 'border')
            if borderChanged then selectedBD.border = borderValue end
        end
    end
    )
end

function lib.drawUI()
    ui.startFrame()
    local w, h = love.graphics.getDimensions()
    if state.world.paused then
        love.graphics.setColor({ 244 / 255, 164 / 255, 97 / 255 })
        love.graphics.setColor({ 1, 0, 0, .5 })
    else
        love.graphics.setColor({ 245 /
        255, 245 / 255, 220 / 255 })
    end

    love.graphics.rectangle('line', 10, 10, w - 20, h - 20, 20, 20)
    love.graphics.setColor(1, 1, 1)

    -- "Add Shape" Button
    if ui.button(20, 20, 200, 'add shape') then
        state.panelVisibility.addShapeOpened = not state.panelVisibility.addShapeOpened
    end

    if state.panelVisibility.addShapeOpened then
        lib.drawAddShapeUI()
    end

    -- "Add Joint" Button
    if ui.button(230, 20, 200, 'add joint') then
        state.panelVisibility.addJointOpened = not state.panelVisibility.addJointOpened
    end

    if state.panelVisibility.addJointOpened then
        lib.drawAddJointUI()
    end

    -- "World Settings" Button
    if ui.button(440, 20, 120, 'settings') then
        state.panelVisibility.worldSettingsOpened = not state.panelVisibility.worldSettingsOpened
    end
    if state.panelVisibility.worldSettingsOpened then
        lib.drawWorldSettingsUI()
    end
    if ui.button(570, 20, 70, 'bg') then
        state.panelVisibility.bgSettingsOpened = not state.panelVisibility.bgSettingsOpened
    end
    if state.panelVisibility.bgSettingsOpened then
        lib.drawBGSettingsUI()
    end


    -- Play/Pause Button
    if ui.button(650, 20, 150, state.world.paused and 'play' or 'pause') then
        state.world.paused = not state.world.paused
    end

    if ui.button(810, 20, 150, state.world.isRecordingPointers and 'recording' or 'record') then
        state.panelVisibility.recordingPanelOpened = not state.panelVisibility.recordingPanelOpened
        -- state.world.isRecordingPointers = not state.world.isRecordingPointers
    end
    if state.panelVisibility.recordingPanelOpened then
        lib.drawRecordingUI()
    end

    if state.scene.sceneScript and state.scene.sceneScript.onStart then
        if ui.button(970, 20, 50, 'R') then
            -- todo actually reread the file itself!
            sceneLoader.loadAndRunScript(state.scene.scriptPath)
            script.call(SE.ON_START) --state.scene.sceneScript.onStart()
        end
    end




    if modes.is(modes.PICK_AUTO_ROPIFY) then
        local panelWidth = PANEL_WIDTH
        w, h = love.graphics.getDimensions()
        ui.panel(w - panelWidth - 20, 20, panelWidth, h - 40, '∞ autoropify ∞', function()
            local padding = BUTTON_SPACING
            local layout = ui.createLayout({
                type = 'columns',
                spacing = BUTTON_SPACING,
                startX = w - panelWidth,
                startY = 100 + padding
            })
            local x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
            if state.pickAutoRopifyModeHitted then
                if ui.button(x, y, 260, 'yes!') then
                    objectManager.autoRopify(state.pickAutoRopifyModeHitted)
                    state.pickAutoRopifyModeHitted = nil
                    modes.clear()
                end
            end
        end)
    end


    if modes.is(modes.DRAW_CLICK) then
        local panelWidth = PANEL_WIDTH
        w, h = love.graphics.getDimensions()
        ui.panel(w - panelWidth - 20, 20, panelWidth, h - 40, '∞ click draw vertex polygon ∞', function()
            local padding = BUTTON_SPACING
            local layout = ui.createLayout({
                type = 'columns',
                spacing = BUTTON_SPACING,
                startX = w - panelWidth,
                startY = 100 + padding
            })
            local x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)


            if ui.button(x, y, 260, 'finalize') then
                logger:info('finalize clicked')
                objectManager.finalizePolygon()
            end
            x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
            if ui.button(x, y, 260, 'soft-surface') then
                objectManager.finalizePolygonAsSoftSurface()
            end
            x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
            if ui.button(x, y, 260, 'uv-mappert') then
                local thing = objectManager.finalizePolygon()
                --logger:inspect(thing)
                -- local body =
                if thing and thing.body then
                    fixtures.createSFixture(thing.body, 0, 0, subtypes.RESOURCE,
                        { width = 20, height = 20 })
                end
                --objectManager.finalizePolygonAsSoftSurface()
            end
            -- x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
            -- if ui.button(x, y, 260, 'blob') then
            --     objectManager.finalizePolygonAsBlob()
            -- end
        end)
    end

    if state.selection.selectedObj and not state.selection.selectedJoint and not state.selection.selectedSFixture then
        local body = state.selection.selectedObj.body
        local mipoInstance, mipoPartName = mipoRegistry.getFromBody(body)
        if mipoInstance then
            uiMipoEditor.drawMipoEditor(mipoInstance, mipoPartName)
        else
            lib.drawUpdateSelectedObjectUI()
        end
    end

    if state.selection.selectedBodies and #state.selection.selectedBodies > 0 then
        lib.drawSelectedBodiesUI()
    end

    if modes.is(modes.JOINT_CREATION) and state.jointParams.body1 and state.jointParams.body2 then
        lib.drawJointCreateUI(500, 100, 400, 150)
    end

    if state.selection.selectedSFixture then
        lib.drawSelectedSFixture()
    end

    if state.selection.selectedObj and state.selection.selectedJoint then
        -- (w - panelWidth - 20, 20, panelWidth, h - 40
        lib.drawJointUpdateUI(state.selection.selectedJoint, w - PANEL_WIDTH - 20, 20, PANEL_WIDTH, h - 40)
    end

    if modes.is(modes.SET_OFFSET_A) or modes.is(modes.SET_OFFSET_B)
        or modes.is(modes.POSITIONING_SFIXTURE) then
        ui.panel(500, 100, 300, 60, '• click point ∆', function()
        end)
    end

    if modes.is(modes.ADD_NODE_CONNECTED_TEX) or modes.is(modes.ADD_NODE_MESHUSERT) then
        ui.panel(500, 100, 400, 60, '• click anchor or joint to add ', function()
        end)
    end


    if modes.is(modes.JOINT_CREATION)
        and ((state.jointParams.body1 == nil) or (state.jointParams.body2 == nil)) then
        if (state.jointParams.body1 == nil) then
            ui.panel(500, 100, 300, 100, '• pick 1st body •', function()
                local x = 510
                local y = 150
                local width = 280
                if ui.button(x, y, width, 'cancel') then
                    state.jointParams = nil
                    modes.clear()
                end
            end)
        elseif (state.jointParams.body2 == nil) then
            ui.panel(500, 100, 300, 100, '• pick 2nd body •', function()
                local x = 510
                local y = 150
                local width = 280
                if ui.button(x, y, width, 'cancel') then
                    state.jointParams = nil
                    modes.clear()
                end
            end)
        end
    end

    if state.panelVisibility.showPalette then
        w, h = love.graphics.getDimensions()
        ui.panel(10, h - 400, w - 300, 400, '• pick color •', function()
            --ui.coloredRect()
            local cellHeight = 50
            local itemsPerRow = math.floor((w - 300) / cellHeight)

            for i = 1, #box2dDrawTextured.palette do
                local row = math.floor((i - 1) / itemsPerRow)
                local column = (i - 1) % itemsPerRow
                local x = column * cellHeight
                local y = row * cellHeight

                -- ui.coloredRect(0, 0, { 255, 0, 0 }, 40)
                if ui.coloredRect(10 + x, h - 300 + y,
                    { box2dDrawTextured.hexToColor(box2dDrawTextured.palette[i]) }, 40) then
                    state.showPaletteFunc(box2dDrawTextured.palette[i])
                end
            end
        end)
    end

    if state.panelVisibility.saveDialogOpened then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle('fill', 0, 0, w, h)
        love.graphics.setColor(1, 1, 1)
        ui.panel(300, 300, w - 600, h - 600, '»»» save «««', function()
            local t = ui.textinput('savename', 320, 350, w - 640, 40, 'add text...', state.editorPreferences.saveName)
            if t then
                state.editorPreferences.saveName = utils.sanitizeString(t)
            end
            if ui.button(320, 500, 200, 'save') then
                state.panelVisibility.saveDialogOpened = false
                sceneIO.save(state.physicsWorld, cam, state.editorPreferences.saveName)
            end
            if ui.button(540, 500, 200, 'cancel') then
                state.panelVisibility.saveDialogOpened = false
                love.system.openURL("file://" .. love.filesystem.getSaveDirectory())
            end
        end)
    end

    if state.panelVisibility.quitDialogOpened then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle('fill', 0, 0, w, h)
        love.graphics.setColor(1, 1, 1)

        local header = ' » really quit ? « '
        local minW = ui.font:getWidth(header)
        local panelW = math.max(minW, w - 600)
        local panelH = math.max(ui.font:getHeight() * 6, h - 600)
        local offW = w - panelW
        local offH = h - panelH
        ui.panel(offW / 2, offH / 2, panelW, panelH, header, function()
            ui.label(offW / 2 + 20, offH / 2 + 40, '[esc] to quit')
            ui.label(offW / 2 + 20, offH / 2 + 80, '[space] to cancel')
        end)
    end

    --state.panelVisibility.customBehavior = { body = body, name = behavior.name }



    if state.panelVisibility.customBehavior then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle('fill', 0, 0, w, h)
        love.graphics.setColor(1, 1, 1)

        ui.panel(50, 50, 300, 300, state.panelVisibility.customBehavior.name,

            function()
                local lookup = utils.findByField(behaviors.allBehaviors, 'name',
                    state.panelVisibility.customBehavior.name)
                --print(inspect(lookedup))
                if lookup then
                    if ui.button(50, 50, 50, '?') then
                        if state.panelVisibility.customBehaviorDescription then
                            state.panelVisibility.customBehaviorDescription = false
                        else
                            state.panelVisibility.customBehaviorDescription = lookup.description
                        end
                    end
                end


                ui.scrollableList('custombehaviors', 50, 100, 280, 250,
                    function(baseX, baseY, _w, _h, offsetY)
                        if state.panelVisibility.customBehavior.name == 'KEEP_ANGLE' then
                            local myID        = state.selection.selectedObj.id
                            local myUD        = state.panelVisibility.customBehavior.body:getUserData()
                            local myBehaviors = myUD.thing.behaviors or {}
                            local b           = nil
                            for i = 1, #myBehaviors do
                                if (myBehaviors[i].name == 'KEEP_ANGLE') then
                                    b = myBehaviors[i]
                                end
                            end
                            --logger:inspect(myBehaviors)

                            if b then
                                ui.createSliderWithId(myID, 'speed', 100, 100, 100, 0, 500,
                                    b.speed or 0,
                                    function(v) b.speed = v end)
                            end

                            if b then
                                ui.createSliderWithId(myID, 'angle', 100, 150, 100, -360, 360,
                                    b.angle or 0,
                                    function(v) b.angle = v end)
                            end
                            if b then
                                if ui.button(100, 200, 150, 'remove') then
                                    myUD.thing.behaviors = {}
                                end
                            end
                        end


                        if state.panelVisibility.customBehavior.name == 'LIMB_HUB' then
                            -- we can assume all these type of other things are attached via revolute joints
                            local me = state.panelVisibility.customBehavior.body
                            local bodyJoints = me:getJoints()
                            local names = {}
                            for i = 1, #bodyJoints do
                                local bodyA, bodyB = bodyJoints[i]:getBodies()
                                local otherBody = bodyA == me and bodyB or bodyA
                                --print(inspect(otherBody:getUserData().thing.label))
                                table.insert(names, otherBody:getUserData().thing.label)
                            end

                            local maxY = 0
                            local lineHeight = 30
                            for i = 1, #names do
                                local elementY = (baseY + offsetY) + (i - 1) * lineHeight
                                ui.button(baseX, elementY, 100, names[i])
                                ui.textinput('limb_hub_vertexpicker' .. names[i], baseX + 100, elementY,
                                    50, BUTTON_HEIGHT, "vertex", 0)
                                -- _id, x, y, width, height, placeholder, currentText
                                --  ui.textinput()
                                maxY = maxY + lineHeight
                            end
                            return maxY
                        end
                        -- local maxY = 0
                        -- local lineHeight = 40
                        -- for i = 1, 28 do
                        --     local elementY = (baseY + offsetY) + (i - 1) * lineHeight
                        --     if elementY + lineHeight < baseY then
                        --     elseif elementY > baseY + h then
                        --     else
                        --         ui.button(baseX, elementY, 100, 'test2' .. i)
                        --     end
                        --     maxY = maxY + lineHeight
                        -- end

                        -- return maxY
                    end
                )
            end
        )
    end

    if state.panelVisibility.customBehaviorDescription then
        ui.panel(100, 50, 300, 300, '', function()
            love.graphics.printf(state.panelVisibility.customBehaviorDescription, 110, 100, 280)
        end, { .5, .5, .9 })
    end


    if state.panelVisibility.addBehavior then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle('fill', 0, 0, w, h)
        love.graphics.setColor(1, 1, 1)

        -- local all_options = {
        --     'KEEP_ANGLE',
        --     'LIMB_HUB'
        -- }




        local myUD = utils.deepCopy(state.panelVisibility.addBehavior.body:getUserData())
        --logger:inspect(myUD)
        local myBehaviors = myUD.thing.behaviors or {}

        local function updatePossibleOptions()
            local possible_options = {}
            for _, behavior in ipairs(behaviors.allBehaviors) do
                local isIn = false
                for j = 1, #myBehaviors do
                    if myBehaviors[j].name == behavior.name then
                        isIn = true
                        break
                    end
                end
                if not isIn then
                    table.insert(possible_options, behavior.name)
                end
            end
            return possible_options
        end

        local possible_options = updatePossibleOptions()

        ui.panel(50, 50, 300, 300, 'add behavior',
            function()
                for i, option in ipairs(possible_options) do
                    if ui.button(50, 100 + (i - 1) * 40, 200, option) then
                        --local newUD = utils.deepCopy(myUD)
                        if not myUD.thing.behaviors then
                            myUD.thing.behaviors = {}
                        end
                        table.insert(myUD.thing.behaviors, { name = option })
                        state.panelVisibility.addBehavior.body:setUserData(myUD)
                        local body = state.panelVisibility.addBehavior.body
                        state.panelVisibility.addBehavior = false
                        --table.insert(myBehaviors, {name = option})
                        --
                        state.panelVisibility.customBehavior = { name = option, body = body }
                    end
                end
            end
        )
    end

    if ui.draggingActive then
        love.graphics.setColor(ui.theme.draggedElement.fill)
        local x, y = love.mouse.getPosition()
        love.graphics.circle('fill', x, y, 10)
        love.graphics.setColor(1, 1, 1)
    end
end

return lib

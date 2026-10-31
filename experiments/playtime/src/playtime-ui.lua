local lib = {}
local logger = require('src.logger')

local sceneIO = require('src.io')

local ui = require('src.ui.all')
local joints = require('src.joints')
local objectManager = require('src.object-manager')
local polyEdit = require('src.poly-edit')
local library = require('src.library')
local color = require('src.color')
local camera = require('src.camera')
local cam = camera.getInstance()
local utils = require('src.utils')
local mathutils = require('src.math-utils')

local fixtures = require('src.fixtures')
local snap = require('src.physics.snap')

local state = require('src.state')
local modes = require('src.modes')
local subtypes = require('src.subtypes')
local behaviors = require('src.behaviors')
local uiWorldSettings = require('src.ui.world-settings')
local uiJointUpdate = require('src.ui.joint-update')
local uiRecordingPanel = require('src.ui.recording-panel')
local uiSFixtureEditor = require('src.ui.sfixture-editor')
local uiBodyEditor = require('src.ui.body-editor')
local fileBrowser  = require('src.file-browser')
local uiMipoEditor = require('src.ui.mipo-editor')
local playMode = require('src.play-mode')
local inspector = require('src.ui.inspector')
local mipoRegistry = require('src.mipo-registry')
local rightColumn = require('src.ui.right-column')
local toolRail = require('src.ui.tool-rail')
local PANEL_WIDTH = ui.theme.panelWidth
local BUTTON_HEIGHT = ui.theme.lineHeight
local ROW_WIDTH = ui.theme.rowWidth
local BUTTON_SPACING = ui.theme.spacing

function lib.drawJointCreateUI()
    local text = '• ' .. (state.jointParams.jointType or 'joint') .. ': both bodies picked •'
    local clicked = ui.topPrompt(text, { 'create', 'cancel' })
    if clicked == 'create' then
        local joint = joints.createJoint(state.jointParams)
        state.selection.selectedJoint = joint
        state.selection.selectedObject = nil
        state.jointParams = nil
        modes.clear()
    elseif clicked == 'cancel' then
        state.jointParams = nil
        modes.clear()
    end
end

function lib.drawJointUpdateUI(...) return uiJointUpdate.drawJointUpdateUI(...) end

function lib.drawRecordingUI(...) return uiRecordingPanel.drawRecordingUI(...) end
function lib.drawWorldSettingsUI(...) return uiWorldSettings.drawWorldSettingsUI(...) end

function lib.drawSelectedSFixture(...) return uiSFixtureEditor.drawSelectedSFixture(...) end

-- panelX, panelY, panelWidth, panelH: the panel rect (default: the right edge, full height)
function lib.drawSelectedBodiesUI(panelX, panelY, panelWidth, panelH)
    local w, h = ui.getDimensions()
    panelWidth = panelWidth or PANEL_WIDTH
    panelX, panelY, panelH = panelX or (w - panelWidth - 20), panelY or 20, panelH or (h - 40)
    ui.panel(panelX, panelY, panelWidth, panelH, '∞ selection ∞', function()
        local padding = BUTTON_SPACING
        local layout = ui.createLayout({
            type = 'columns',
            spacing = BUTTON_SPACING,
            startX = panelX + 20,
            startY = panelY + ui.theme.contentTop + padding
        })

        local x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
        local nextRow = function()
            x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
        end

        if ui.button(x, y, 260, 'clone') then
            local cloned = library.clone(state.selection.selectedBodies)
            state.selection.selectedBodies = cloned
        end
        nextRow()

        if ui.button(x, y, 260, 'clone x 10') then
            for _ = 1, 10 do
                local cloned = library.clone(state.selection.selectedBodies)
                state.selection.selectedBodies = cloned
            end
            --
        end
        nextRow()

        if ui.button(x, y, 260, 'destroy') then
            for i = #state.selection.selectedBodies, 1, -1 do
                snap.destroySnapJointAboutBody(state.selection.selectedBodies[i].body)
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
        nextRow()
    end)
end

-- the properties tab of the right column: the panel for what's selected, in the
-- given rect. Returns false when nothing is selected.
function lib.drawSelectionProperties(x, y, panelWidth, panelH)
    local selection = state.selection
    if selection.selectedSFixture then
        lib.drawSelectedSFixture(x, y, panelWidth, panelH)
    elseif selection.selectedObj and selection.selectedJoint then
        lib.drawJointUpdateUI(selection.selectedJoint, x, y, panelWidth, panelH)
    elseif selection.selectedBodies and #selection.selectedBodies > 0 then
        lib.drawSelectedBodiesUI(x, y, panelWidth, panelH)
    elseif selection.selectedObj then
        local mipoInstance, mipoPartName = mipoRegistry.getFromBody(selection.selectedObj.body)
        if mipoInstance then
            uiMipoEditor.drawMipoEditor(mipoInstance, mipoPartName, x, y, panelWidth, panelH)
        else
            lib.drawUpdateSelectedObjectUI(x, y, panelWidth, panelH)
        end
    else
        return false
    end
    return true
end

function lib.drawUpdateSelectedObjectUI(...) return uiBodyEditor.drawUpdateSelectedObjectUI(...) end

function lib.drawUI()
    ui.startFrame()
    local w, h = ui.getDimensions()
    if state.world.paused then
        love.graphics.setColor({ 244 / 255, 164 / 255, 97 / 255 })
        love.graphics.setColor({ 1, 0, 0, .5 })
    else
        love.graphics.setColor({ 245 /
        255, 245 / 255, 220 / 255 })
    end

    love.graphics.rectangle('line', 10, 10, w - 20, h - 20, 20, 20)
    love.graphics.setColor(1, 1, 1)

    -- into play mode (tab does the same): above the rail, so a phone has a way in
    if ui.button(10, 18, 76, 'play', 36) then playMode.enter() end

    -- the left tool rail: shapes, draw, joints, attach, mipos (toys are on the library tab)
    toolRail.draw()

    -- settings (world, backdrops, music) opens from the rail's settings button
    if state.panelVisibility.worldSettingsOpened then
        lib.drawWorldSettingsUI()
    end
    -- play / record / restart script live on the rail's play button
    if state.panelVisibility.recordingPanelOpened then
        lib.drawRecordingUI()
    end

    if modes.is(modes.PICK_AUTO_ROPIFY) then
        local panelWidth = PANEL_WIDTH
        w, h = ui.getDimensions()
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
        local clicked = ui.topPrompt('• click to place points •', { 'finalize', 'uv-mappert' }, 140)
        if clicked == 'finalize' then
            logger:info('finalize clicked')
            polyEdit.finalizePolygon()
        elseif clicked == 'uv-mappert' then
            local thing = polyEdit.finalizePolygon()
            if thing and thing.body then
                fixtures.createSFixture(thing.body, 0, 0, subtypes.RESOURCE, { width = 20, height = 20 })
            end
        end
    end

    -- the (parked) autoropify panel above uses the right edge itself
    if not modes.is(modes.PICK_AUTO_ROPIFY) then
        rightColumn.draw(lib.drawSelectionProperties)
    end

    if modes.is(modes.JOINT_CREATION) and state.jointParams.body1 and state.jointParams.body2 then
        lib.drawJointCreateUI()
    end

    if modes.is(modes.SET_OFFSET_A) or modes.is(modes.SET_OFFSET_B)
        or modes.is(modes.POSITIONING_SFIXTURE) then
        ui.topPrompt('• click point ∆')
    end

    if modes.is(modes.ADD_NODE_CONNECTED_TEX) or modes.is(modes.ADD_NODE_MESHUSERT) then
        ui.topPrompt('• click anchor or joint to add •')
    end

    if modes.is(modes.JOINT_CREATION)
        and ((state.jointParams.body1 == nil) or (state.jointParams.body2 == nil)) then
        local which = state.jointParams.body1 == nil and '1st' or '2nd'
        local jointType = state.jointParams.jointType or 'joint'
        if ui.topPrompt('• ' .. jointType .. ': pick ' .. which .. ' body •', { 'cancel' }) then
            state.jointParams = nil
            modes.clear()
        end
    end

    if state.panelVisibility.showPalette then
        w, h = ui.getDimensions()
        ui.panel(10, h - 400, w - 300, 400, '• pick color •', function()
            local cellHeight = 50
            local itemsPerRow = math.floor((w - 300) / cellHeight)

            for i = 1, #color.palette do
                local row = math.floor((i - 1) / itemsPerRow)
                local column = (i - 1) % itemsPerRow
                local x = column * cellHeight
                local y = row * cellHeight

                if ui.coloredRect(10 + x, h - 300 + y,
                    { color.hexToColor(color.palette[i]) }, 40) then
                    state.showPaletteFunc(color.palette[i])
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

    if state.panelVisibility.customBehavior then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle('fill', 0, 0, w, h)
        love.graphics.setColor(1, 1, 1)

        -- top centre, like the other prompts; '?' sits in the title band, the description opens beside
        local panelW, panelH = 420, 320
        local px, py = ui.topCenter(panelW)
        ui.panel(px, py, panelW, panelH, state.panelVisibility.customBehavior.name,

            function()
                local lookup = utils.findByField(behaviors.allBehaviors, 'name',
                    state.panelVisibility.customBehavior.name)
                if lookup then
                    if ui.button(px + panelW - 40, py + 4, 30, '?') then
                        if state.panelVisibility.customBehaviorDescription then
                            state.panelVisibility.customBehaviorDescription = false
                        else
                            state.panelVisibility.customBehaviorDescription = lookup.description
                        end
                    end
                end

                ui.scrollableList('custombehaviors', px + 10, py + ui.theme.contentTop, panelW - 20,
                    panelH - ui.theme.contentTop - 10,
                    function(baseX, baseY, listW, _h, offsetY)
                        local behaviorBody = state.panelVisibility.customBehavior.body
                        if lookup and lookup.params then
                            local bodyThing = utils.thingOf(behaviorBody)
                            local target
                            for _, behavior in ipairs(bodyThing.behaviors or {}) do
                                if behavior.name == lookup.name then target = behavior end
                            end
                            if not target then return 0 end
                            local x, y = baseX + 10, baseY + offsetY + 5
                            local used = inspector.drawParams(lookup.name .. '_' .. tostring(bodyThing.id),
                                lookup.params, target, behaviorBody, x, y, listW - 20)
                            if ui.button(x + inspector.labelWidth, y + used + 7, listW - 20 - inspector.labelWidth,
                                    'remove') then
                                local kept = {}
                                for _, behavior in ipairs(bodyThing.behaviors) do
                                    if behavior ~= target then table.insert(kept, behavior) end
                                end
                                bodyThing.behaviors = kept
                                state.panelVisibility.customBehavior = false
                            end
                            return used + inspector.rowHeight + 10
                        end
                        if state.panelVisibility.customBehavior.name == 'LIMB_HUB' then
                            -- we can assume all these type of other things are attached via revolute joints
                            local me = state.panelVisibility.customBehavior.body
                            local bodyJoints = me:getJoints()
                            local names = {}
                            for i = 1, #bodyJoints do
                                local bodyA, bodyB = bodyJoints[i]:getBodies()
                                local otherBody = bodyA == me and bodyB or bodyA
                                table.insert(names, utils.thingOf(otherBody).label)
                            end

                            local maxY = 0
                            local lineHeight = 30
                            for i = 1, #names do
                                local elementY = (baseY + offsetY) + (i - 1) * lineHeight
                                ui.button(baseX, elementY, 100, names[i])
                                ui.textinput('limb_hub_vertexpicker' .. names[i], baseX + 100, elementY,
                                    50, BUTTON_HEIGHT, "vertex", 0)
                                -- _id, x, y, width, height, placeholder, currentText
                                maxY = maxY + lineHeight
                            end
                            return maxY
                        end

                    end
                )
            end
        )
    end

    if state.panelVisibility.customBehaviorDescription then
        local editorX = ui.topCenter(420)
        local dx, dy = editorX + 420 + BUTTON_SPACING, 20
        ui.panel(dx, dy, 300, 320, '', function()
            love.graphics.printf(state.panelVisibility.customBehaviorDescription, dx + 10, dy + 10, 280)
        end, { .5, .5, .9 })
    end

    if state.panelVisibility.addBehavior then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle('fill', 0, 0, w, h)
        love.graphics.setColor(1, 1, 1)

        local body = state.panelVisibility.addBehavior.body
        local myBehaviors = utils.thingOf(body).behaviors or {}

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

        -- wide, not tall: the options in a grid of up to 4 columns, top centre
        local columns = mathutils.clamp(#possible_options, 1, 4)
        local optionW = 200
        local rows = math.ceil(#possible_options / columns)
        local panelW = columns * (optionW + BUTTON_SPACING) + BUTTON_SPACING
        local panelH = ui.theme.contentTop + rows * (BUTTON_HEIGHT + BUTTON_SPACING) + BUTTON_SPACING
        local px, py = ui.topCenter(panelW)
        ui.panel(px, py, panelW, panelH, 'add behavior',
            function()
                for i, option in ipairs(possible_options) do
                    local column, row = (i - 1) % columns, math.floor((i - 1) / columns)
                    local ox = px + BUTTON_SPACING + column * (optionW + BUTTON_SPACING)
                    local oy = py + ui.theme.contentTop + row * (BUTTON_HEIGHT + BUTTON_SPACING)
                    if ui.button(ox, oy, optionW, option) then
                        behaviors.add(body, option)
                        state.panelVisibility.addBehavior = false
                        state.panelVisibility.customBehavior = { name = option, body = body }
                    end
                end
            end
        )
    end

    if ui.draggingActive then
        love.graphics.setColor(ui.theme.draggedElement.fill)
        love.graphics.circle('fill', ui.mouseX, ui.mouseY, 10)
        love.graphics.setColor(1, 1, 1)
    end

    fileBrowser:draw()
end

return lib

local lib = {}

local eio = require 'src.io'
local registry = require 'src.registry'
local mathutils = require 'src.math-utils'
local ui = require 'src.ui-all'
local joints = require 'src.joints'
local objectManager = require 'src.object-manager'
local camera = require 'src.camera'
local cam = camera.getInstance()
local box2dPointerJoints = require 'src.box2d-pointerjoints'
local utils = require 'src.utils'
local ProFi = require 'vendor.ProFi'
local fixtures = require 'src.fixtures'
local snap = require 'src.snap'
local box2dDrawTextured = require 'src.box2d-draw-textured'
local Peeker = require 'vendor.peeker'
local recorder = require 'src.recorder'
local state = require 'src.state'
local script = require 'src.script'
local sceneLoader = require 'src.scene-loader'

local PANEL_WIDTH = 300
local BUTTON_HEIGHT = ui.theme.lineHeight
local ROW_WIDTH = 160
local BUTTON_SPACING = 10
local FPS = 60

local offsetHasChangedViaOutside
local BGcolorHasChangedViaPalette
local FGcolorHasChangedViaPalette
local PatternColorHasChangedViaPalette
local Patch1ColorHasChangedViaPalette

local colorpickers = {
    bg = false
}


local function createSliderWithId(id, label, x, y, width, min, max, value, callback, changed)
    local newValue = ui.sliderWithInput(id .. "::" .. label, x, y, width, min, max, value, changed)
    if newValue then
        callback(newValue)
    end
    ui.label(x, y, label)
    return newValue
end
-- Helper function to create a checkbox with an associated label
local function createCheckbox(labelText, x, y, value, callback)
    local changed, newValue = ui.checkbox(x, y, value, labelText)
    if changed then
        callback(newValue)
    end
    return newValue
end

local function rect(w, h, x, y)
    return {
        x - w / 2, y - h / 2,
        x + w / 2, y - h / 2,
        x + w / 2, y + h / 2,
        x - w / 2, y + h / 2
    }
end

function lib.doJointCreateUI(_x, _y, w, h)
    ui.panel(_x, _y, w, h, '∞ ' .. state.jointParams.jointType .. ' ∞', function()
        local layout = ui.createLayout({
            type = 'columns',
            spacing = 10,
            startX = _x + 10,
            startY = _y + 10
        })

        local width = 180
        local x, y = ui.nextLayoutPosition(layout, 160, BUTTON_HEIGHT)
        local nextRow = function()
            x, y = ui.nextLayoutPosition(layout, 160, BUTTON_HEIGHT)
        end
        nextRow()
        if ui.button(x, y, width, 'Create') then
            local j = joints.createJoint(state.jointParams)
            state.selection.selectedJoint = j
            state.selection.selectedObject = nil
            state.jointParams = nil
            state.currentMode = nil
        end

        if ui.button(x + width + 10, y, width, 'Cancel') then
            state.jointParams = nil
            state.currentMode = nil
        end
    end)
end

function lib.doJointUpdateUI(j, _x, _y, w, h)
    if not j:isDestroyed() then
        ui.panel(_x, _y, w, h, '∞ ' .. j:getType() .. ' ∞', function()
            local bodyA, bodyB = j:getBodies()

            local layout = ui.createLayout({
                type = 'columns',
                spacing = 10,
                startX = _x + 10,
                startY = _y + 10
            })
            local jointType = j:getType()
            local jointId = joints.getJointId(j)
            local x, y = ui.nextLayoutPosition(layout, 160, BUTTON_HEIGHT)

            local nextRow = function()
                x, y = ui.nextLayoutPosition(layout, 160, BUTTON_HEIGHT)
            end
            nextRow()
            local width = 280


            if ui.button(x, y, width, 'destroy') then
                local setId = joints.getJointId(j)
                registry.unregisterJoint(setId)
                j:destroy()
                return;
            end

            local function axisFunctionality(j)
                local axisEnabled = createCheckbox(' axis', x, y,
                    state.editorPreferences.axisEnabled or false,
                    function(val)
                        state.editorPreferences.axisEnabled = val
                    end
                )

                if axisEnabled then
                    local _x, _y = j:getAxis()
                    --_x, _y = normalizeAxis(_x, _y)
                    nextRow()
                    local axisX = createSliderWithId(jointId, ' axisX', x, y, 160, -1, 1,
                        _x or 0,
                        function(val)
                            state.selection.selectedJoint = joints.recreateJoint(j, { axisX = val, axisY = _y })
                            j = state.selection.selectedJoint
                        end
                    )
                    nextRow()
                    local axisY = createSliderWithId(jointId, ' axisY', x, y, 160, -1, 1,
                        _y or 1,
                        function(val)
                            state.selection.selectedJoint = joints.recreateJoint(j, { axisX = _x, axisY = val })
                            j = state.selection.selectedJoint
                        end
                    )
                    nextRow()
                    if ui.button(x, y, 160, 'normalize') then
                        local _x, _y = j:getAxis()
                        _x, _y = mathutils.normalizeAxis(_x, _y)
                        state.selection.selectedJoint = joints.recreateJoint(j, { axisX = _x, axisY = _y })
                        j = state.selection.selectedJoint
                    end
                end
                return j
            end

            local function collideFunctionality(j)
                local collideEnabled = createCheckbox(' collide', x, y,
                    j:getCollideConnected(),
                    function(val)
                        state.selection.selectedJoint = joints.recreateJoint(j, { collideConnected = val })
                        j = state.selection.selectedJoint
                    end
                )
                return j
            end

            local function motorFunctionality(j, settings)
                local motorEnabled = createCheckbox(' motor', x, y,
                    j:isMotorEnabled(),
                    function(val)
                        j:setMotorEnabled(val)
                    end
                )
                nextRow()
                if j:isMotorEnabled() then
                    local motorSpeed = createSliderWithId(jointId, ' speed', x, y, 160, -1000, 1000,
                        j:getMotorSpeed(),
                        function(val) j:setMotorSpeed(val) end
                    )
                    nextRow()
                    if (settings and settings.useTorque) then
                        local maxMotorTorque = createSliderWithId(jointId, ' max T', x, y, 160, 0, 100000,
                            j:getMaxMotorTorque(),
                            function(val) j:setMaxMotorTorque(val) end
                        )
                        nextRow()
                    end
                    if (settings and settings.useForce) then
                        local maxMotorForce = createSliderWithId(jointId, ' max F', x, y, 160, 0, 100000,
                            j:getMaxMotorForce(),
                            function(val) j:setMaxMotorForce(val) end
                        )
                        nextRow()
                    end
                end
            end

            local function limitsFunctionalityAngular(j)
                local limitsEnabled = createCheckbox(' limits', x, y,
                    j:areLimitsEnabled(),
                    function(val)
                        j:setLimitsEnabled(val)
                    end
                )

                if (j:areLimitsEnabled()) then
                    nextRow()
                    local up = math.deg(j:getUpperLimit())
                    local lowerLimit = createSliderWithId(jointId, ' lower', x, y, 160, -180, up,
                        math.deg(j:getLowerLimit()),
                        function(val)
                            local newValue = math.rad(val)

                            j:setLowerLimit(newValue)
                        end
                    )
                    nextRow()
                    local low = math.deg(j:getLowerLimit())
                    local upperLimit = createSliderWithId(jointId, ' upper', x, y, 160, low, 180,
                        math.deg(j:getUpperLimit()),
                        function(val)
                            local newValue = math.rad(val)
                            j:setUpperLimit(newValue)
                        end
                    )
                end
            end

            local function limitsFunctionalityLinear(j)
                local limitsEnabled = createCheckbox(' limits', x, y,
                    j:areLimitsEnabled(),
                    function(val)
                        j:setLimitsEnabled(val)
                    end
                )

                if (j:areLimitsEnabled()) then
                    nextRow()
                    local up = (j:getUpperLimit())
                    local lowerLimit = createSliderWithId(jointId, ' lower', x, y, 160, -1000, up,
                        j:getLowerLimit(),
                        function(val)
                            j:setLowerLimit(val)
                        end
                    )
                    nextRow()
                    local low = j:getLowerLimit()
                    local upperLimit = createSliderWithId(jointId, ' upper', x, y, 160, low, 1000,
                        j:getUpperLimit(),
                        function(val)
                            j:setUpperLimit(val)
                        end
                    )
                end
            end

            local function offsetSliders(j)
                if not joints.getJointMetaSetting(j, 'offsetA') then
                    joints.setJointMetaSetting(j, 'offsetA', { x = 0, y = 0 })
                end
                local offsetA = joints.getJointMetaSetting(j, 'offsetA') or 0

                if not joints.getJointMetaSetting(j, 'offsetB') then
                    joints.setJointMetaSetting(j, 'offsetB', { x = 0, y = 0 })
                end
                local offsetB = joints.getJointMetaSetting(j, 'offsetB') or 0

                function updateOffsetA(x, y)
                    --local rx, ry = rotatePoint(x, y, 0, 0, bodyA:getAngle())

                    offsetA.x = x
                    offsetA.y = y
                    joints.setJointMetaSetting(j, 'offsetA', { x = offsetA.x, y = offsetA.y })
                    state.selection.selectedJoint = joints.recreateJoint(j)
                    j = state.selection.selectedJoint


                    offsetHasChangedViaOutside = true
                    return j
                end

                function updateOffsetB(x, y)
                    --local rx, ry = rotatePoint(x, y, 0, 0, bodyA:getAngle())

                    offsetB.x = x
                    offsetB.y = y
                    joints.setJointMetaSetting(j, 'offsetB', { x = offsetB.x, y = offsetB.y })
                    state.selection.selectedJoint = joints.recreateJoint(j)
                    j = state.selection.selectedJoint


                    offsetHasChangedViaOutside = true
                    return j
                end

                -- Ensure offsets exist


                nextRow()
                if ui.button(x, y, BUTTON_HEIGHT, '∆') then
                    state.currentMode = 'setOffsetA'
                end
                if jointType ~= 'revolute' then
                    if ui.button(x + 50, y, BUTTON_HEIGHT, 'b  ') then
                        state.currentMode = 'setOffsetB'
                    end
                end
                nextRow()
                if (offsetHasChangedViaOutside) then offsetHasChangedViaOutside = false end

                local bodyA, bodyB = j:getBodies()
                local ud = bodyA:getUserData()


                if false and ud and ud.thing then
                    --print(inspect(ud.thing))
                    if ud.thing.width and ud.thing.height then
                        if ui.button(x, y, 30, '0', 30) then
                            updateOffsetA(0, -ud.thing.height / 2)
                        end
                        if ui.button(x + 30, y, 30, '1', 30) then
                            updateOffsetA(ud.thing.width / 2, -ud.thing.height / 2)
                        end
                        if ui.button(x + 60, y, 30, '2', 30) then
                            updateOffsetA(ud.thing.width / 2, 0)
                        end
                        if ui.button(x + 90, y, 30, '3', 30) then
                            updateOffsetA(ud.thing.width / 2, ud.thing.height / 2)
                        end
                        if ui.button(x + 120, y, 30, '4', 30) then
                            updateOffsetA(0, ud.thing.height / 2)
                        end
                        if ui.button(x + 150, y, 30, '5', 30) then
                            updateOffsetA(-ud.thing.width / 2, ud.thing.height / 2)
                        end
                        if ui.button(x + 180, y, 30, '6', 30) then
                            updateOffsetA(-ud.thing.width / 2, 0)
                        end
                        if ui.button(x + 210, y, 30, '7', 30) then
                            updateOffsetA(-ud.thing.width / 2, -ud.thing.height / 2)
                        end
                    end
                    if ui.button(x + 240, y, 30, '8', 30) then
                        updateOffsetA(0, 0)
                    end
                end

                nextRow()



                return j
            end

            if jointType == 'distance' then
                nextRow()
                j = collideFunctionality(j)
                nextRow()
                j = offsetSliders(j)
                nextRow()
                -- local bodyA, bodyB = j:getBodies()
                local x1, y1 = bodyA:getPosition()
                local x2, y2 = bodyB:getPosition()
                local myLength = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
                local length = createSliderWithId(jointId, ' length', x, y, 160, 0.1, 500,
                    state.jointLengthParams.length or myLength,
                    function(val)
                        j:setLength(val)
                        state.jointLengthParams.length = val
                    end
                )
                nextRow()

                local frequency = createSliderWithId(jointId, ' freq', x, y, 160, 0, 20,
                    j:getFrequency(),
                    function(val) j:setFrequency(val) end
                )
                nextRow()
                local damping = createSliderWithId(jointId, ' damp', x, y, 160, 0, 20,
                    j:getDampingRatio(),
                    function(val) j:setDampingRatio(val) end
                )

                nextRow()
                nextRow()
            elseif jointType == 'weld' then
                nextRow()
                j = collideFunctionality(j)
                nextRow()
                j = offsetSliders(j)
                nextRow()
                local frequency = createSliderWithId(jointId, ' freq', x, y, 160, 0, 20,
                    j:getFrequency(),
                    function(val) j:setFrequency(val) end
                )
                nextRow()
                local damping = createSliderWithId(jointId, ' damp', x, y, 160, 0, 20,
                    j:getDampingRatio(),
                    function(val) j:setDampingRatio(val) end
                )
                nextRow()
            elseif jointType == 'rope' then
                nextRow()
                j = collideFunctionality(j)
                nextRow()
                j = offsetSliders(j)
                nextRow()
                -- local bodyA, bodyB = j:getBodies()
                local x1, y1 = bodyA:getPosition()
                local x2, y2 = bodyB:getPosition()
                local myLength = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
                local length = createSliderWithId(jointId, ' length', x, y, 160, 0.1, 500,
                    state.jointLengthParams.maxLength or myLength,
                    function(val)
                        j:setMaxLength(val)
                        state.jointLengthParams.maxLength = val
                    end
                )
                nextRow()
            elseif jointType == 'revolute' then
                nextRow()
                j = collideFunctionality(j)
                nextRow()
                j = offsetSliders(j)
                nextRow()
                limitsFunctionalityAngular(j)
                nextRow()
                motorFunctionality(j, { useTorque = true })
            elseif jointType == 'wheel' then
                nextRow()
                j = collideFunctionality(j)
                nextRow()
                j = offsetSliders(j)
                nextRow()
                j = axisFunctionality(j)
                nextRow()
                -- if not j:isDestroyed() then
                local springFrequency = createSliderWithId(jointId, ' spring F', x, y, 160, 0, 100,
                    j:getSpringFrequency(),
                    function(val)
                        j:setSpringFrequency(val)
                    end
                )
                nextRow()
                local springDamping = createSliderWithId(jointId, ' spring D', x, y, 160, 0, 1,
                    j:getSpringDampingRatio(),
                    function(val) j:setSpringDampingRatio(val) end
                )
                nextRow()
                motorFunctionality(j, { useTorque = true })
                -- axisFunctionality(j)
                nextRow()
                --  end
            elseif jointType == 'motor' then
                nextRow()
                j = collideFunctionality(j)
                nextRow()
                j = offsetSliders(j)
                nextRow()
                local angularOffset = createSliderWithId(jointId, ' angular o', x, y, 160, -180, 180,
                    math.deg(j:getAngularOffset()),
                    function(val) j:setAngularOffset(math.rad(val)) end
                )
                nextRow()
                local correctionF = createSliderWithId(jointId, ' corr.', x, y, 160, 0, 1,
                    j:getCorrectionFactor(),
                    function(val) j:setCorrectionFactor(val) end
                )
                nextRow()
                local lx, ly = j:getLinearOffset()
                local lxOff = createSliderWithId(jointId, ' lx', x, y, 160, -1000, 1000,
                    lx,
                    function(val) j:setLinearOffset(val, ly) end
                )
                nextRow()
                local lyOff = createSliderWithId(jointId, ' ly', x, y, 160, -1000, 1000,
                    ly,
                    function(val) j:setLinearOffset(lx, val) end
                )
                nextRow()
                local maxForce = createSliderWithId(jointId, ' force', x, y, 160, 0, 100000,
                    j:getMaxForce(),
                    function(val) j:setMaxForce(val) end
                )
                nextRow()
                local maxTorque = createSliderWithId(jointId, ' torque', x, y, 160, 0, 100000,
                    j:getMaxTorque(),
                    function(val) j:setMaxTorque(val) end
                )
                nextRow()
            elseif jointType == 'friction' then
                j = offsetSliders(j)
                nextRow()
                local maxForce = createSliderWithId(jointId, ' force', x, y, 160, 0, 100000,
                    j:getMaxForce(),
                    function(val) j:setMaxForce(val) end
                )
                nextRow()
                local maxTorque = createSliderWithId(jointId, ' torque', x, y, 160, 0, 100000,
                    j:getMaxTorque(),
                    function(val) j:setMaxTorque(val) end
                )
                nextRow()
            elseif jointType == 'prismatic' then
                nextRow()
                j = collideFunctionality(j)
                nextRow()
                j = offsetSliders(j)
                nextRow()
                j = axisFunctionality(j)
                nextRow()
                limitsFunctionalityLinear(j)
                nextRow()
                motorFunctionality(j, { useForce = true })
            end
        end)
    end
end

function lib.drawAddShapeUI()
    local shapeTypes = { 'rectangle', 'circle', 'triangle', 'itriangle', 'capsule', 'torso', 'trapezium', 'pentagon',
        'hexagon',
        'heptagon',
        'octagon' }
    local titleHeight = ui.font:getHeight() + BUTTON_SPACING
    local startX = 20
    local startY = 70
    local panelWidth = 200
    local buttonSpacing = BUTTON_SPACING
    local buttonHeight = ui.theme.button.height
    local panelHeight = titleHeight + ((#shapeTypes + 5) * (buttonHeight + buttonSpacing)) + buttonSpacing

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

        for _, shape in ipairs(shapeTypes) do
            local width = panelWidth - 20
            local height = buttonHeight

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
        love.graphics.line(x - 20, y + 20, x + panelWidth + 20, y + 20)

        local width = panelWidth - 20
        local height = buttonHeight
        nextRow()

        local minDist = ui.sliderWithInput('minDistance', x, y, 80, 1, 150,
            state.editorPreferences.minPointDistance or 10)
        ui.label(x, y, 'dis')
        if minDist then
            state.editorPreferences.minPointDistance = minDist
        end

        -- Add a button for custom polygon
        nextRow()
        if ui.button(x, y, width, 'freeform') then
            state.currentMode = 'drawFreePoly'
            state.interaction.polyVerts = {}
            state.interaction.lastPolyPt = nil
        end
        nextRow()

        if ui.button(x, y, width, 'click') then
            state.currentMode = 'drawClickMode'
            state.interaction.polyVerts = {}
            state.interaction.lastPolyPt = nil
        end
        nextRow()

        local width = panelWidth - 20
        local height = buttonHeight

        local _, pressed, released = ui.button(x, y, width, 'sfixture')
        if pressed then
            ui.draggingActive = ui.activeElementID
            local mx, my = love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)

            state.interaction.offsetDragging = { 0, 0 }
        end
        if released then
            local mx, my = love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)
            local _, hitted = box2dPointerJoints.handlePointerPressed(wx, wy, 'mouse', {}, not state.world.paused)
            if (#hitted > 0) then
                local body = hitted[#hitted]:getBody()
                local localX, localY = body:getLocalPoint(wx, wy)
                local fixture = fixtures.createSFixture(body, localX, localY, { label = 'snap', radius = 30 })
                state.selection.selectedSFixture = fixture
            end
            ui.draggingActive = nil
        end
        nextRow()


        local _, pressed, released = ui.button(x, y, width, 'texfixture')
        if pressed then
            ui.draggingActive = ui.activeElementID
            local mx, my = love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)

            state.interaction.offsetDragging = { 0, 0 }
        end
        if released then
            local mx, my = love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)
            local _, hitted = box2dPointerJoints.handlePointerPressed(wx, wy, 'mouse', {}, not state.world.paused)
            if (#hitted > 0) then
                local body = hitted[#hitted]:getBody()

                local verts = body:getUserData().thing.vertices
                local cx, cy, w, h = mathutils.getCenterOfPoints(verts)

                local localX, localY = body:getLocalPoint(wx, wy)
                local fixture = fixtures.createSFixture(body, localX, localY,
                    { label = 'texfixture', width = w, height = h })
                state.selection.selectedSFixture = fixture
            end
            ui.draggingActive = nil
        end
        nextRow()
    end)
end

function lib.drawAddJointUI()
    local jointTypes = { 'distance', 'weld', 'rope', 'revolute', 'wheel', 'motor', 'prismatic', 'pulley',
        'friction' }
    local titleHeight = ui.font:getHeight() + BUTTON_SPACING
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
                state.currentMode = 'jointCreationMode'
            end
        end
    end)
end

function lib.drawRecordingUI()
    local startX = 800
    local startY = 70
    local panelWidth = PANEL_WIDTH
    --local panelHeight = 255
    local buttonHeight = ui.theme.button.height

    local buttonSpacing = BUTTON_SPACING
    local titleHeight = ui.font:getHeight() + BUTTON_SPACING
    local panelHeight = titleHeight + titleHeight + (9 * (buttonHeight + BUTTON_SPACING) + BUTTON_SPACING)
    ui.panel(startX, startY, panelWidth, panelHeight, '• recording stuff •', function()
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

        local function startFromCurrentCheckpoint()
            state.selection.selectedJoint = nil
            state.selection.selectedObj = nil
            eio.buildWorld(state.scene.checkpoints[state.scene.activeCheckpointIndex].saveData, state.physicsWorld, cam,
                true)
            --

            if state.scene.sceneScript then state.scene.sceneScript.onStart() end
        end

        local addcheckpointbutton = ui.button(x, y, width, 'add checkpoint')
        if addcheckpointbutton then
            local saveData = eio.gatherSaveData(state.physicsWorld, cam)
            table.insert(state.scene.checkpoints, { saveData = saveData, recordings = {} })
        end
        nextRow()
        local chars = { 'A', 'B', 'C', 'D', 'E', 'F' }
        for i = 1, #state.scene.checkpoints do
            if ui.button(x + (i - 1) * 45, y, 40, chars[i]) then
                if state.scene.activeCheckpointIndex > 0 then
                    state.scene.checkpoints[state.scene.activeCheckpointIndex].recordings = utils.deepCopy(recorder
                        .recordings)
                end

                state.scene.activeCheckpointIndex = i

                recorder.recordings = utils.deepCopy(state.scene.checkpoints[state.scene.activeCheckpointIndex]
                    .recordings)
                startFromCurrentCheckpoint()
            end
        end
        y = y + 15
        love.graphics.line(x - 20, y + 20, x + panelWidth + 20, y + 20)
        nextRow()




        local function videoing()
            if Peeker.get_status() then
                Peeker.isProcessing = true
                Peeker.stop()
            else
                Peeker.isProcessing = false
                Peeker.start({
                    --w = 320,   --optional
                    --h = 320,   --optional
                    scale = 1, --this overrides w, h above, this is preferred to keep aspect ratio
                    --n_threads = 1,
                    fps = FPS,
                    out_dir = string.format("awesome_video"), --optional
                    -- format = "mkv", --optional
                    overlay = "circle",                       --or "text"
                    post_clean_frames = false,
                    total_frames = 1000,
                })
            end
        end

        if state.scene.activeCheckpointIndex > 0 and ((not recorder.isRecording and state.world.paused) or recorder.isRecording) then
            local pointerbutton = ui.button(x, y, width,
                recorder.isRecording and 'RECORDING gestures' or 'record gestures')
            if pointerbutton then
                if recorder.isRecording then
                    recorder:stopRecording()
                else
                    startFromCurrentCheckpoint()
                    recorder:startRecording()
                    recorder:startReplay() -- needed to replay earlier recordings if any.
                end
            end
            if #recorder.recordings > 0 then
                nextRow()

                local replaybutton = ui.button(x, y, width, 'replay gestures')
                if replaybutton then
                    startFromCurrentCheckpoint()
                    recorder:startReplay()
                end
            end
        end
        y = y + 15
        love.graphics.line(x - 20, y + 20, x + panelWidth + 20, y + 20)
        nextRow()
        nextRow()


        -- only allowed to start recording from pause
        if state.scene.activeCheckpointIndex > 0 then
            local peekerbutton = ui.button(x, y, width,
                Peeker.get_status() and 'RECORDING gesture video' or 'record gesture video')
            if peekerbutton then
                if not Peeker.get_status() then
                    state.world.paused = true -- it starts recording from pause so should start playing like that too
                    startFromCurrentCheckpoint()
                    recorder:startReplay()
                end
                videoing()
            end
            nextRow()
        end
        local saveloc = ui.button(x, y, width, 'open savedir')
        if saveloc then
            love.system.openURL("file://" .. love.filesystem.getSaveDirectory())
        end

        nextRow()
        -- local peekerbutton2 = ui.button(x, y, width,
        --     Peeker.get_status() and 'RECORDING video' or 'record vanilla video')
        -- if peekerbutton2 then
        --     videoing(false)
        -- end
        nextRow()
    end)
end

function lib.drawWorldSettingsUI()
    local startX = 440
    local startY = 70
    local panelWidth = PANEL_WIDTH
    --local panelHeight = 255
    local buttonHeight = ui.theme.button.height

    local buttonSpacing = BUTTON_SPACING
    local titleHeight = ui.font:getHeight() + BUTTON_SPACING
    local panelHeight = titleHeight + titleHeight + (9 * (buttonHeight + BUTTON_SPACING) + BUTTON_SPACING)
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
        local grav = ui.sliderWithInput('grav', x, y, ROW_WIDTH, -10, BUTTON_HEIGHT, state.world.gravity)
        if grav then
            state.world.gravity = grav
            if state.physicsWorld then
                state.physicsWorld:setGravity(0, state.world.gravity * state.world.meter)
            end
        end
        ui.label(x, y, ' gravity')
        nextRow()

        local g, value = ui.checkbox(x, y, state.editorPreferences.showGrid, 'grid') --showGrid = true,
        if g then
            state.editorPreferences.showGrid = value
        end
        local g, value = ui.checkbox(x + 150, y, state.world.debugDrawMode, 'draw') --showGrid = true,
        if g then
            state.world.debugDrawMode = value
        end
        nextRow()



        local debugAlpha = ui.sliderWithInput('debugalpha', x, y, ROW_WIDTH, 0, 1, state.world.debugAlpha)
        if debugAlpha then
            state.world.debugAlpha = debugAlpha
        end
        ui.label(x, y, ' dbgAlpha')
        nextRow()
        nextRow()

        local mouseForce = ui.sliderWithInput(' mouse F', x, y, ROW_WIDTH, 0, 1000000, state.world.mouseForce)
        if mouseForce then
            state.world.mouseForce = mouseForce
        end
        ui.label(x, y, ' mouse F')
        nextRow()

        local mouseDamp = ui.sliderWithInput(' damp', x, y, ROW_WIDTH, 0.001, 1, state.world.mouseDamping)
        if mouseDamp then
            state.world.mouseDamping = mouseDamp
        end
        ui.label(x, y, ' damp')


        -- Add Speed Multiplier Slider

        nextRow()
        local newSpeed = ui.sliderWithInput('speed', x, y, ROW_WIDTH, 0.1, 10.0, state.world.speedMultiplier)
        if newSpeed then
            state.world.speedMultiplier = newSpeed
        end
        ui.label(x, y, ' speed')

        nextRow()

        ui.label(x, y, registry.print())
        nextRow()

        if ui.button(x, y, ROW_WIDTH, state.world.profiling and 'profiling' or 'profile') then
            if state.world.profiling then
                ProFi:stop()
                ProFi:writeReport('profilingReport.txt')
                state.world.profiling = false
            else
                ProFi:start()
                state.world.profiling = true
            end
        end
    end)
end

local hadBeenDraggingObj = false
local accordionStatesSF = {
    ['texture'] = true,
    ['patch1'] = false,
    ['patch2'] = false,
}

function lib.drawSelectedSFixture()
    local panelWidth = PANEL_WIDTH
    local w, h = love.graphics.getDimensions()
    if state.interaction.draggingObj then
        hadBeenDraggingObj = true
    end
    local ud = state.selection.selectedSFixture:getUserData()
    local sfixtureType = (ud and ud.extra and ud.extra.type == 'texfixture') and 'texfixture' or 'sfixture'

    -- Function to create an accordion
    local function drawAccordion(key, contentFunc)
        -- Draw the accordion header

        local clicked = ui.header_button(x, y, PANEL_WIDTH - 40, (accordionStatesSF[key] and " ÷  " or " •") ..
            ' ' .. key, accordionStatesSF[key])
        if clicked then
            accordionStatesSF[key] = not accordionStatesSF[key]
        end
        y = y + BUTTON_HEIGHT + BUTTON_SPACING


        if accordionStatesSF[key] then
            contentFunc(clicked)
        end
    end



    ui.panel(w - panelWidth - 20, 20, panelWidth, h - 40, '∞ ' .. sfixtureType .. ' ∞', function()
        local padding = BUTTON_SPACING
        local layout = ui.createLayout({
            type = 'columns',
            spacing = BUTTON_SPACING,
            startX = w - panelWidth,
            startY = 100 + padding
        })
        x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
        local nextRow = function()
            x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
        end

        local myID = state.selection.selectedSFixture:getUserData().id
        local myLabel = state.selection.selectedSFixture:getUserData().label or ''


        local newLabel = ui.textinput(myID .. ' label', x, y, 260, BUTTON_HEIGHT, "", myLabel)
        if newLabel and newLabel ~= myLabel then
            local oldUD = utils.shallowCopy(state.selection.selectedSFixture:getUserData())
            oldUD.label = newLabel

            state.selection.selectedSFixture:setUserData(oldUD)
        end
        nextRow()


        if ui.button(x, y, ROW_WIDTH, 'destroy') then
            fixtures.destroyFixture(state.selection.selectedSFixture)
            state.selection.selectedSFixture = nil
            return
        end
        nextRow()




        if ui.button(x, y, BUTTON_HEIGHT, '∆') then
            state.currentMode = 'positioningSFixture'
            --  state.interaction.setUpdateSFixturePosFunc = updateSFixturePosFunc
        end
        if ui.button(x + 150, y, ROW_WIDTH - 100, 'c') then
            local body = state.selection.selectedSFixture:getBody()
            state.selection.selectedSFixture = fixtures.updateSFixturePosition(state.selection.selectedSFixture,
                body:getX(), body:getY())
            local oldTexFixUD = state.selection.selectedSFixture:getUserData()
            state.texFixtureEdit.tempVerts = utils.shallowCopy(oldTexFixUD.extra.vertices)
        end
        if ui.button(x + 210, y, ROW_WIDTH - 100, 'd') then
            local body = state.selection.selectedSFixture:getBody()

            local verts = body:getUserData().thing.vertices
            local cx, cy, w, h = mathutils.getCenterOfPoints(verts)
            fixtures.updateSFixtureDimensionsFunc(w, h)
            local oldTexFixUD = state.selection.selectedSFixture:getUserData()
            state.texFixtureEdit.tempVerts = utils.shallowCopy(oldTexFixUD.extra.vertices)
        end
        nextRow()



        if sfixtureType == 'texfixture' then
            local oldTexFixUD = state.selection.selectedSFixture:getUserData()
            local points = oldTexFixUD.extra.vertices or{  state.selection.selectedSFixture:getShape():getPoints() }
            local w, h   = mathutils.getPolygonDimensions(points)

            if ui.checkbox(x, y, state.editorPreferences.showTexFixtureDim, 'dims') then
                state.editorPreferences.showTexFixtureDim = not state.editorPreferences.showTexFixtureDim
            end
            nextRow()

            if ui.button(x, y, 200, state.texFixtureEdit.lockedVerts and 'verts locked' or 'verts unlocked') then
                  local oldTexFixUD = state.selection.selectedSFixture:getUserData()
                state.texFixtureEdit.lockedVerts = not state.texFixtureEdit.lockedVerts

                if state.texFixtureEdit.lockedVerts == false then

                    state.texFixtureEdit.tempVerts = utils.shallowCopy(oldTexFixUD.extra.vertices)

                else
                    state.texFixtureEdit.tempVerts = nil
                    state.texFixtureEdit.centroid = nil
                end
            end

            if ui.button(x + 220, y,40, oldTexFixUD.extra.vertexCount  ) then
            if  oldTexFixUD.extra.vertexCount == 4 then
                oldTexFixUD.extra.vertexCount = 8
                 elseif oldTexFixUD.extra.vertexCount == 8 then
                  oldTexFixUD.extra.vertexCount = 4

            end
            end

             nextRow()

            if (state.editorPreferences.showTexFixtureDim) then
                local newWidth = ui.sliderWithInput(myID .. 'texfix width', x, y, ROW_WIDTH, 1, 1000, w)
                ui.label(x, y, ' width')
                nextRow()

                local newHeight = ui.sliderWithInput(myID .. ' texfix height', x, y, ROW_WIDTH, 1, 1000, h)
                ui.label(x, y, ' height')
                nextRow()

                if newWidth and math.abs(newWidth - w) > 1 then
                    updateSFixtureDimensionsFunc(newWidth, h)
                    w, h = mathutils.getPolygonDimensions(points)
                end
                if newHeight and math.abs(newHeight - h) > 1 then
                    updateSFixtureDimensionsFunc(w, newHeight)
                    w, h = mathutils.getPolygonDimensions(points)
                end
            end

            local newZOffset = ui.sliderWithInput(myID .. 'texfixzOffset', x, y, ROW_WIDTH, -180, 180,
                math.floor(oldTexFixUD.extra.zOffset or 0),
                (not state.world.paused) or dirtyBodyChange)
            if newZOffset and oldTexFixUD.extra.zOffset ~= newZOffset then
                oldTexFixUD.extra.zOffset = math.floor(newZOffset)
            end
            ui.label(x, y, ' zOffset')
            nextRow()

            drawAccordion("texture", function()
                nextRow()
                local e = state.selection.selectedSFixture:getUserData().extra
                if ui.checkbox(x, y, true, (e.OMP == false or e.OMP == nil) and 'BG + FG' or 'OMP') then
                    e.OMP = not e.OMP
                end

                nextRow()

                --lineart, mask, pattern

                function handlePaletteAndHex(idPrefix, postFix, x, y, currentHex, onColorChange)
                    local r, g, b, a = box2dDrawTextured.hexToColor(currentHex)
                    local paletteShow = ui.button(x, y, 40, '', BUTTON_HEIGHT, { r, g, b, a })
                    if paletteShow then
                        if state.panelVisibility.showPalette then
                            state.panelVisibility.showPalette = nil
                            state.showPaletteFunc = nil
                        else
                            state.panelVisibility.showPalette = true
                            state.showPaletteFunc = function(color)
                                currentHex = color
                                oldTexFixUD.extra.dirty = true
                                colorpickers[postFix] = true
                                onColorChange(color)
                            end
                        end
                    end
                    local hex = ui.textinput(idPrefix .. postFix, x + 50, y, 210, BUTTON_HEIGHT, "", currentHex or '',
                        false, colorpickers[postFix])
                    if hex and hex ~= currentHex then
                        currentHex = hex
                        onColorChange(hex)
                        oldTexFixUD.extra.dirty = true
                    end

                    if colorpickers[postFix] then
                        colorpickers[postFix] = false
                    end
                    ui.label(x + 50, y, postFix, { 1, 1, 1, 0.2 })
                    return currentHex
                end

                function handleURLInput(id, labelText, x, y, currentValue, updateCallback)
                    local newValue = ui.textinput(id .. labelText, x, y, 260, BUTTON_HEIGHT, "", currentValue or '')
                    if newValue and newValue ~= currentValue then
                        updateCallback(newValue)
                        oldTexFixUD.extra.dirty = true
                        state.selection.selectedSFixture:setUserData(oldTexFixUD)
                    end
                    ui.label(x, y, labelText, { 1, 1, 1, 0.2 })
                    return newValue or currentValue
                end

                if not e.OMP then
                    handleURLInput(myID, 'bgURL', x, y, oldTexFixUD.extra.bgURL,
                        function(u) oldTexFixUD.extra.bgURL = u end)
                    nextRow()
                    handlePaletteAndHex(myID, 'bgHex', x, y, oldTexFixUD.extra.bgHex,
                        function(c) oldTexFixUD.extra.bgHex = c end)
                    nextRow()
                    handleURLInput(myID, 'fgURL', x, y, oldTexFixUD.extra.fgURL,
                        function(u) oldTexFixUD.extra.fgURL = u end)
                    nextRow()
                    handlePaletteAndHex(myID, 'fgHex', x, y, oldTexFixUD.extra.fgHex,
                        function(c) oldTexFixUD.extra.fgHex = c end)
                    nextRow()
                end
                if e.OMP then
                    handleURLInput(myID, 'bgURL', x, y, oldTexFixUD.extra.bgURL,
                        function(u) oldTexFixUD.extra.bgURL = u end)
                    nextRow()
                    handlePaletteAndHex(myID, 'bgHex', x, y, oldTexFixUD.extra.bgHex,
                        function(color) oldTexFixUD.extra.bgHex = color end)
                    nextRow()
                    handleURLInput(myID, 'fgURL', x, y, oldTexFixUD.extra.fgURL,
                        function(u) oldTexFixUD.extra.fgURL = u end)
                    nextRow()
                    handlePaletteAndHex(myID, 'fgHex', x, y, oldTexFixUD.extra.fgHex,
                        function(c) oldTexFixUD.extra.fgHex = c end)
                    nextRow()
                    ---
                    handleURLInput(myID, 'patternURL', x, y, oldTexFixUD.extra.patternURL,
                        function(u) oldTexFixUD.extra.patternURL = u end)
                    nextRow()
                    handlePaletteAndHex(myID, 'patternHex', x, y, oldTexFixUD.extra.patternHex,
                        function(color) oldTexFixUD.extra.patternHex = color end)
                    nextRow()

                    -----
                    local newRotation = ui.sliderWithInput(myID .. ' texrotation', x, y, ROW_WIDTH, 0, math.pi * 2,
                        oldTexFixUD.extra.texRotation or 0)
                    ui.label(x, y, ' texrot')
                    if newRotation and newRotation ~= oldTexFixUD.extra.texRotation then
                        oldTexFixUD.extra.texRotation = newRotation
                        oldTexFixUD.extra.dirty = true
                    end
                    nextRow()
                    local newScale = ui.sliderWithInput(myID .. ' texscale', x, y, ROW_WIDTH, 0.01, 3,
                        oldTexFixUD.extra.texScale or 0)
                    ui.label(x, y, ' texscale')
                    if newScale and newScale ~= oldTexFixUD.extra.texScale then
                        oldTexFixUD.extra.texScale = newScale
                        oldTexFixUD.extra.dirty = true
                    end
                    nextRow()
                    local newXOff = ui.sliderWithInput(myID .. ' texXOffscale', x, y, ROW_WIDTH, 0, 1,
                        oldTexFixUD.extra.texXOff or 0)
                    ui.label(x, y, ' xoff')
                    if newXOff and newXOff ~= oldTexFixUD.extra.texXOff then
                        oldTexFixUD.extra.texXOff = newXOff
                        oldTexFixUD.extra.dirty = true
                    end
                    nextRow()
                    local newYOff = ui.sliderWithInput(myID .. ' texYOffscale', x, y, ROW_WIDTH, 0, 1,
                        oldTexFixUD.extra.texYOff or 0)
                    ui.label(x, y, ' yoff')
                    if newYOff and newYOff ~= oldTexFixUD.extra.texYOff then
                        oldTexFixUD.extra.texYOff = newYOff
                        oldTexFixUD.extra.dirty = true
                    end
                    nextRow()
                    local dirtyX, checkedX = ui.checkbox(x, y, e.texFlipX == -1, 'flipx')
                    if dirtyX then
                        oldTexFixUD.extra.texFlipX = checkedX and -1 or 1
                        oldTexFixUD.extra.dirty = true
                        state.selection.selectedSFixture:setUserData(oldTexFixUD)
                    end
                    local dirtyY, checkedY = ui.checkbox(x + 150, y, e.texFlipY == -1, 'flipy')
                    if dirtyY then
                        oldTexFixUD.extra.texFlipY = checkedY and -1 or 1
                        oldTexFixUD.extra.dirty = true
                        state.selection.selectedSFixture:setUserData(oldTexFixUD)
                    end

                    nextRow()
                end
            end)
            nextRow()
            drawAccordion('patch1', function()
                -- 2 patches will be made here for now.
                local patch1URL = ui.textinput(myID .. 'patchURL1', x + 40, y, 220, BUTTON_HEIGHT, "",
                    oldTexFixUD.extra.patch1URL or '')
                if patch1URL and patch1URL ~= oldTexFixUD.extra.patch1URL then
                    oldTexFixUD.extra.patch1URL = patch1URL
                    oldTexFixUD.extra.dirty = true
                    state.selection.selectedSFixture:setUserData(oldTexFixUD)
                end

                ui.label(x + 50, y, 'patchURL1', { 1, 1, 1, 0.2 })
                nextRow()
                nextRow()
                local paletteShow = ui.button(x, y, 40, 'p', BUTTON_HEIGHT)
                if paletteShow then
                    if state.panelVisibility.showPalette then
                        state.panelVisibility.showPalette = nil
                        state.showPaletteFunc = nil
                    else
                        state.panelVisibility.showPalette = true
                        state.showPaletteFunc = function(color)
                            oldTexFixUD.extra.patch1Hex = color
                            oldTexFixUD.extra.dirty = true
                            PatternColorHasChangedViaPalette = true
                        end
                    end
                end
                local patch1Hex = ui.textinput(myID .. ' patchHex1', x + 50, y, 210, BUTTON_HEIGHT, "",
                    oldTexFixUD.extra.patch1Hex or '',
                    false,
                    PatternColorHasChangedViaPalette)
                if patch1Hex and patch1Hex ~= oldTexFixUD.extra.patch1Hex then
                    oldTexFixUD.extra.patch1Hex = patch1Hex
                    oldTexFixUD.extra.dirty = true
                end
                if PatternColorHasChangedViaPalette then
                    PatternColorHasChangedViaPalette = false
                end
                ui.label(x + 50, y, 'patchHex1', { 1, 1, 1, 0.2 })
                nextRow()

                local patch1TX = ui.sliderWithInput(myID .. ' patch1TX', x, y, 50, -1, 1,
                    oldTexFixUD.extra.patch1TX or 0)
                ui.label(x, y, 'TX')
                if patch1TX and patch1TX ~= oldTexFixUD.extra.patch1TX then
                    oldTexFixUD.extra.patch1TX = patch1TX
                    oldTexFixUD.extra.dirty = true
                end
                -- nextRow()
                local patch1TY = ui.sliderWithInput(myID .. ' patch1TY', x + 140, y, 50, -1, 1,
                    oldTexFixUD.extra.patch1TY or 0)
                ui.label(x + 140, y, 'TY')
                if patch1TY and patch1TY ~= oldTexFixUD.extra.patch1TY then
                    oldTexFixUD.extra.patch1TY = patch1TY
                    oldTexFixUD.extra.dirty = true
                end


                nextRow()

                local patch1SX = ui.sliderWithInput(myID .. ' patch1SX', x, y, 50, -1, 1,
                    oldTexFixUD.extra.patch1SX or 1)
                ui.label(x, y, 'SX')
                if patch1SX and patch1SX ~= oldTexFixUD.extra.patch1SX then
                    oldTexFixUD.extra.patch1SX = patch1SX
                    oldTexFixUD.extra.dirty = true
                end
                -- nextRow()
                local patch1SY = ui.sliderWithInput(myID .. ' patch1SY', x + 140, y, 50, -1, 1,
                    oldTexFixUD.extra.patch1SY or 1)
                ui.label(x + 140, y, 'SY')
                if patch1SY and patch1SY ~= oldTexFixUD.extra.patch1SY then
                    oldTexFixUD.extra.patch1SY = patch1SY
                    oldTexFixUD.extra.dirty = true
                end
                nextRow()
                local patch1r = ui.sliderWithInput(myID .. ' patch1r', x, y, ROW_WIDTH, -math.pi, math.pi,
                    oldTexFixUD.extra.patch1r or 1)
                ui.label(x, y, ' patch1r')
                if patch1r and patch1r ~= oldTexFixUD.extra.patch1r then
                    oldTexFixUD.extra.patch1r = patch1r
                    oldTexFixUD.extra.dirty = true
                end
                nextRow()
            end)
            nextRow()
            drawAccordion('patch2', function()
                -- 2 patches will be made here for now.
                local patchURL2 = ui.textinput(myID .. 'patchURL2', x + 40, y, 220, BUTTON_HEIGHT, "",
                    oldTexFixUD.extra.patchURL2 or '')
                if patchURL2 and patchURL2 ~= oldTexFixUD.extra.patchURL2 then
                    oldTexFixUD.extra.patchURL1 = patchURL2
                    oldTexFixUD.extra.dirty = true
                    state.selection.selectedSFixture:setUserData(oldTexFixUD)
                end

                ui.label(x + 50, y, 'patchURL2', { 1, 1, 1, 0.2 })
                nextRow()
                nextRow()
                local paletteShow = ui.button(x, y, 40, 'p', BUTTON_HEIGHT)
                if paletteShow then
                    if state.panelVisibility.showPalette then
                        state.panelVisibility.showPalette = nil
                        state.showPaletteFunc = nil
                    else
                        state.panelVisibility.showPalette = true
                        state.showPaletteFunc = function(color)
                            oldTexFixUD.extra.patchHex2 = color
                            oldTexFixUD.extra.dirty = true
                            PatternColorHasChangedViaPalette = true
                        end
                    end
                end
                local patchHex2 = ui.textinput(myID .. ' patchHex2', x + 50, y, 210, BUTTON_HEIGHT, "",
                    oldTexFixUD.extra.patchHex2 or '',
                    false,
                    PatternColorHasChangedViaPalette)
                if patchHex2 and patchHex2 ~= oldTexFixUD.extra.patchHex2 then
                    oldTexFixUD.extra.patchHex2 = patchHex2
                    oldTexFixUD.extra.dirty = true
                end
                if PatternColorHasChangedViaPalette then
                    PatternColorHasChangedViaPalette = false
                end
                ui.label(x + 50, y, 'patchHex2', { 1, 1, 1, 0.2 })
                nextRow()
                local patch2TX = ui.sliderWithInput(myID .. ' patch2TX', x, y, ROW_WIDTH, -1, 1,
                    oldTexFixUD.extra.patch2TX or 0)
                ui.label(x, y, ' patch2TX')
                if patch2TX and patch2TX ~= oldTexFixUD.extra.patch2TX then
                    oldTexFixUD.extra.patch2TX = patch2TX
                end
                nextRow()
                local patch2TY = ui.sliderWithInput(myID .. ' patch2TY', x, y, ROW_WIDTH, -1, 1,
                    oldTexFixUD.extra.patch2TY or 0)
                ui.label(x, y, ' patch2TY')
                if patch2TY and patch2TY ~= oldTexFixUD.extra.patch2TY then
                    oldTexFixUD.extra.patch2TY = patch2TY
                end


                local patch2SX = ui.sliderWithInput(myID .. ' patch2SX', x, y, ROW_WIDTH, -1, 1,
                    oldTexFixUD.extra.patch2SX or 1)
                ui.label(x, y, ' patch2SX')
                if patch2SX and patch2SX ~= oldTexFixUD.extra.patch2SX then
                    oldTexFixUD.extra.patch2SX = patch2SX
                end
                nextRow()
                local patch2SY = ui.sliderWithInput(myID .. ' patch2SY', x, y, ROW_WIDTH, -1, 1,
                    oldTexFixUD.extra.patch2SY or 1)
                ui.label(x, y, ' patch2SY')
                if patch2SY and patch2SY ~= oldTexFixUD.extra.patch2SY then
                    oldTexFixUD.extra.patch2SY = patch2SY
                end
                nextRow()
                local patch2r = ui.sliderWithInput(myID .. ' patch2r', x, y, ROW_WIDTH, -1, 1,
                    oldTexFixUD.extra.patch2r or 1)
                ui.label(x, y, ' patch2r')
                if patch2r and patch2r ~= oldTexFixUD.extra.patch2r then
                    oldTexFixUD.extra.patch2r = patch2r
                end
                nextRow()
            end)
        else
            local points = { state.selection.selectedSFixture:getShape():getPoints() }
            local dim = mathutils.getPolygonDimensions(points)
            local newRadius = ui.sliderWithInput(myID .. ' radius', x, y, ROW_WIDTH, 1, 200, dim)
            ui.label(x, y, ' radius')
            if newRadius and newRadius ~= dim then
                updateSFixtureDimensionsFunc(newRadius, newRadius)
                snap.rebuildSnapFixtures(registry.sfixtures)
            end
        end
        nextRow()

        local function handleOffset(xMultiplier, yMultiplier)
            local body = state.selection.selectedSFixture:getBody()
            local parentVerts = body:getUserData().thing.vertices
            local allFixtures = body:getUserData().thing.body:getFixtures()
            local points = { state.selection.selectedSFixture:getShape():getPoints() }
            local centerX, centerY = mathutils.getCenterOfPoints(points)
            local bounds = mathutils.getBoundingRect(parentVerts)
            local relativePoints = mathutils.makePolygonRelativeToCenter(points, centerX, centerY)
            local newShape = mathutils.makePolygonAbsolute(relativePoints,
                ((bounds.width / 2) * xMultiplier),
                ((bounds.height / 2) * yMultiplier))

            local oldUD = utils.shallowCopy(state.selection.selectedSFixture:getUserData())
            state.selection.selectedSFixture:destroy()

            local shape = love.physics.newPolygonShape(newShape)
            local newfixture = love.physics.newFixture(body, shape)
            newfixture:setSensor(true) -- Sensor so it doesn't collide
            newfixture:setUserData(oldUD)
            state.selection.selectedSFixture = newfixture
        end

        if sfixtureType ~= 'texfixture' then
            if ui.button(x, y, 40, 'N') then
                handleOffset(0, -1)
            end
            if ui.button(x + 50, y, 40, 'E') then
                handleOffset(1, 0)
            end
            if ui.button(x + 100, y, 40, 'S') then
                handleOffset(0, 1)
            end
            if ui.button(x + 150, y, 40, 'W') then
                handleOffset(-1, 0)
            end
            if ui.button(x + 200, y, 40, 'C') then
                handleOffset(0, 0)
            end
        end
    end)
end

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

        x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
        local nextRow = function()
            x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
        end

        if ui.button(x, y, 260, 'clone') then
            local cloned = eio.cloneSelection(state.selection.selectedBodies, state.physicsWorld)
            state.selection.selectedBodies = cloned
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
            local fixtures = fb:getFixtures()
            local ff = fixtures[1]
            local groupIndex = ff:getGroupIndex()
            local groupIndexSlider = ui.sliderWithInput('groupIndex', x, y, 160, -32768, 32767, groupIndex)
            ui.label(x, y, ' groupid')
            if groupIndexSlider then
                local value = math.floor(groupIndexSlider)
                local count = 0
                for i = 1, #state.selection.selectedBodies do
                    local b = state.selection.selectedBodies[i].body
                    local fixtures = b:getFixtures()
                    for j = 1, #fixtures do
                        fixtures[j]:setGroupIndex(value)
                        count = count + 1
                    end
                end
            end
        end
        -- end
        nextRow()
    end)
end

local accordionStatesSO = {
    tags = false,
    position = false,
    transform = true,
    physics = false,
    motion = false,
    joints = false,
    sfixtures = false,
    textured = false,
}
function lib.drawUpdateSelectedObjectUI()
    -- Define a table to keep track of accordion states

    if recorder.isRecording then return end
    local panelWidth = PANEL_WIDTH
    local w, h = love.graphics.getDimensions()
    ui.panel(w - panelWidth - 20, 20, panelWidth, h - 40, '∞ body props ∞', function()
        local body = state.selection.selectedObj.body
        -- local angleDegrees = body:getAngle() * 180 / math.pi
        local myID = state.selection.selectedObj.id

        -- Initialize Layout
        local padding = BUTTON_SPACING
        local layout = ui.createLayout({
            type = 'columns',
            spacing = BUTTON_SPACING,
            startX = w - panelWidth,
            startY = 100 + padding
        })

        -- Toggle Body Type Button
        -- Retrieve the current body type
        local currentBodyType = body:getType() -- 'static', 'dynamic', or 'kinematic'

        -- Determine the next body type in the cycle
        local nextBodyType
        if currentBodyType == 'static' then
            nextBodyType = 'dynamic'
        elseif currentBodyType == 'dynamic' then
            nextBodyType = 'kinematic'
        elseif currentBodyType == 'kinematic' then
            nextBodyType = 'static'
        end

        -- Add a button to toggle the body type
        x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
        local nextRow = function()
            x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
        end
        -- Function to create an accordion
        local function drawAccordion(key, contentFunc)
            -- Draw the accordion header

            local clicked = ui.header_button(x, y, PANEL_WIDTH - 40, (accordionStatesSO[key] and " ÷  " or " •") ..
                ' ' .. key, accordionStatesSO[key])
            if clicked then
                accordionStatesSO[key] = not accordionStatesSO[key]
            end
            y = y + BUTTON_HEIGHT + BUTTON_SPACING

            -- If the accordion is expanded, draw the content
            if accordionStatesSO[key] then
                contentFunc(clicked)
            end
        end


        if ui.button(x, y, 100, 'clone') then
            state.selection.selectedBodies = { state.selection.selectedObj }
            local cloned = eio.cloneSelection(state.selection.selectedBodies, state.physicsWorld)
            state.selection.selectedBodies = cloned
            state.selection.selectedObj = nil
        end

        if ui.button(x + 120, y, 140, 'destroy') then
            snap.destroySnapJointAboutBody(body)
            objectManager.destroyBody(body)
            state.selection.selectedObj = nil
            return
        end
        nextRow()

        if ui.button(x, y, 260, currentBodyType) then
            body:setType(nextBodyType)
            body:setAwake(true)
        end
        nextRow()

        local userData = body:getUserData()
        local thing = userData and userData.thing

        local dirtyBodyChange = false
        if (state.selection.lastSelectedBody ~= body) then
            dirtyBodyChange = true
            state.selection.lastSelectedBody = body
        end

        if thing then
            -- Shape Properties
            local shapeType = thing.shapeType

            local newLabel = ui.textinput(myID .. ' label', x, y, 260, BUTTON_HEIGHT, "", thing.label)
            if newLabel and newLabel ~= thing.label then
                thing.label = newLabel -- Update the label
            end

            nextRow()


            nextRow()
            if false then
                drawAccordion("tags", function(clicked)
                    local w = love.graphics.getFont():getWidth('straight') + 20
                    -- ui.button(x, y, w, 'straight')
                    ui.toggleButton(x, y, w, BUTTON_HEIGHT, 'straight', 'straight', false)
                    nextRow()
                end)
                nextRow()
            end
            drawAccordion("position", function(clicked)
                nextRow()
                local value = thing.body:getX()
                local numericInputText, dirty = ui.textinput(myID .. 'x', x, y, 120, BUTTON_HEIGHT, ".", "" .. value,
                    true,
                    clicked or not state.world.paused or state.interaction.draggingObj)
                if hadBeenDraggingObj then
                    dirty = true
                end
                if (dirty) then
                    local numericPosX = tonumber(numericInputText)
                    if numericPosX then
                        thing.body:setX(numericPosX)
                    else
                        -- Handle invalid input, e.g., reset to previous value or show an error
                        logger:error("Invalid X position input!")
                    end
                end
                local value = thing.body:getY()
                local numericInputText, dirty = ui.textinput(myID .. 'y', x + 140, y, 120, BUTTON_HEIGHT, ".",
                    "" .. value, true,
                    clicked or not state.world.paused or state.interaction.draggingObj)
                if hadBeenDraggingObj then
                    dirty = true
                end
                if (dirty) then
                    local numericPosY = tonumber(numericInputText)
                    if numericPosY then
                        thing.body:setY(numericPosY)
                    else
                        -- Handle invalid input, e.g., reset to previous value or show an error
                        logger:error("Invalid Y position input!")
                    end
                end
                if hadBeenDraggingObj then
                    hadBeenDraggingObj = false
                end

                nextRow()

                local dirty, checked = ui.checkbox(x, y, body:isFixedRotation(), 'fixed angle')
                if dirty then
                    body:setFixedRotation(not body:isFixedRotation())
                end

                -- Angle Slider
                nextRow()

                local newAngle = ui.sliderWithInput(myID .. 'angle', x, y, ROW_WIDTH, -180, 180,
                    (body:getAngle() * 180 / math.pi),
                    (body:isAwake() and not state.world.paused) or dirtyBodyChange)
                if newAngle and (body:getAngle() * 180 / math.pi) ~= newAngle then
                    body:setAngle(newAngle * math.pi / 180)
                end
                ui.label(x, y, ' angle')


                nextRow()

                -- local newZOffset = ui.sliderWithInput(myID .. 'zOffset', x, y, ROW_WIDTH, -180, 180,
                --     math.floor(thing.zOffset),
                --     (body:isAwake() and not state.world.paused) or dirtyBodyChange)
                -- if newZOffset and thing.zOffset ~= newZOffset then
                --     thing.zOffset = math.floor(newZOffset)
                -- end
                -- ui.label(x, y, ' zOffset')
            end
            )
            nextRow()

            drawAccordion("transform", function(clicked)
                nextRow()

                if ui.button(x, y, 120, 'flipX') then
                    state.selection.selectedObj = objectManager.flipThing(thing, 'x', true)
                    dirtyBodyChange = true
                end
                if ui.button(x + 140, y, 120, 'flipY') then
                    state.selection.selectedObj = objectManager.flipThing(thing, 'y', true)
                    dirtyBodyChange = true
                end


                nextRow()
                if shapeType == 'circle' then
                    -- Show radius control for circles


                    local newRadius = ui.sliderWithInput(myID .. ' radius', x, y, ROW_WIDTH, 1, 200, thing.radius)
                    ui.label(x, y, ' radius')
                    if newRadius and newRadius ~= thing.radius then
                        state.selection.selectedObj = objectManager.recreateThingFromBody(body,
                            { shapeType = "circle", radius = newRadius })
                        state.editorPreferences.lastUsedRadius = newRadius
                        body = state.selection.selectedObj.body
                    end
                elseif shapeType == 'rectangle' or shapeType == 'itriangle' then
                    -- Show width and height controls for these shapes


                    local newWidth = ui.sliderWithInput(myID .. ' width', x, y, ROW_WIDTH, 1, 800, thing.width)
                    ui.label(x, y, ' width')
                    nextRow()

                    local newHeight = ui.sliderWithInput(myID .. ' height', x, y, ROW_WIDTH, 1, 800, thing.height)
                    ui.label(x, y, ' height')

                    if (newWidth and newWidth ~= thing.width) or (newHeight and newHeight ~= thing.height) then
                        state.editorPreferences.lastUsedWidth = newWidth
                        state.editorPreferences.lastUsedHeight = newHeight
                        state.selection.selectedObj = objectManager.recreateThingFromBody(body, {
                            shapeType = shapeType,
                            width = newWidth or thing.width,
                            height = newHeight or thing.height,
                        })
                        body = state.selection.selectedObj.body
                    end
                elseif shapeType == 'torso' then
                    local newWidth = ui.sliderWithInput(myID .. ' width', x, y, ROW_WIDTH, 1, 800, thing.width)
                    ui.label(x, y, ' width')
                    nextRow()

                    local newWidth2 = ui.sliderWithInput(myID .. ' width2', x, y, ROW_WIDTH, 1, 800, thing.width2)
                    ui.label(x, y, ' width2')
                    nextRow()

                    local newWidth3 = ui.sliderWithInput(myID .. ' width3', x, y, ROW_WIDTH, 1, 800, thing.width3)
                    ui.label(x, y, ' width3')
                    nextRow()

                    local newHeight = ui.sliderWithInput(myID .. ' height', x, y, ROW_WIDTH, 1, 800, thing.height)
                    ui.label(x, y, ' height')
                    nextRow()
                    local newHeight2 = ui.sliderWithInput(myID .. ' height2', x, y, ROW_WIDTH, 1, 800, thing.height2)
                    ui.label(x, y, ' height2')
                    nextRow()
                    local newHeight3 = ui.sliderWithInput(myID .. ' height3', x, y, ROW_WIDTH, 1, 800, thing.height3)
                    ui.label(x, y, ' height3')
                    nextRow()
                    local newHeight4 = ui.sliderWithInput(myID .. ' height4', x, y, ROW_WIDTH, 1, 800, thing.height4)
                    ui.label(x, y, ' height4')
                    nextRow()

                    if (newWidth and newWidth ~= thing.width) or
                        (newWidth2 and newWidth2 ~= thing.width2) or
                        (newWidth3 and newWidth3 ~= thing.width3) or
                        (newHeight and newHeight ~= thing.height) or
                        (newHeight2 and newHeight2 ~= thing.height2) or
                        (newHeight3 and newHeight3 ~= thing.height3) or
                        (newHeight4 and newHeight4 ~= thing.height4) then
                        state.editorPreferences.lastUsedWidth = newWidth
                        state.editorPreferences.lastUsedWidth2 = newWidth2
                        state.editorPreferences.lastUsedWidth3 = newWidth3
                        state.editorPreferences.lastUsedHeight = newHeight
                        state.editorPreferences.lastUsedHeight2 = newHeight2
                        state.editorPreferences.lastUsedHeight3 = newHeight3
                        state.editorPreferences.lastUsedHeight4 = newHeight4

                        state.selection.selectedObj = objectManager.recreateThingFromBody(body, {
                            shapeType = shapeType,
                            width = newWidth or thing.width,
                            width2 = newWidth2 or thing.width2,
                            width3 = newWidth3 or thing.width3,
                            height = newHeight or thing.height,
                            height2 = newHeight2 or thing.height2,
                            height3 = newHeight3 or thing.height3,
                            height4 = newHeight4 or thing.height4,
                        })
                        body = state.selection.selectedObj.body
                    end
                elseif shapeType == 'trapezium' or shapeType == 'capsule' then
                    -- Show width and height controls for these shapes


                    local newWidth = ui.sliderWithInput(myID .. ' width', x, y, ROW_WIDTH, 1, 800, thing.width)
                    ui.label(x, y, ' width')
                    nextRow()

                    local newWidth2 = ui.sliderWithInput(myID .. ' width2', x, y, ROW_WIDTH, 1, 800, (thing.width2 or 5))
                    ui.label(x, y, ' width2')
                    nextRow()

                    local newHeight = ui.sliderWithInput(myID .. ' height', x, y, ROW_WIDTH, 1, 800, thing.height)
                    ui.label(x, y, ' height')

                    if (newWidth and newWidth ~= thing.width) or (newWidth2 and newWidth2 ~= thing.width2) or (newHeight and newHeight ~= thing.height) then
                        state.editorPreferences.lastUsedWidth2 = newWidth2
                        state.editorPreferences.lastUsedWidth = newWidth
                        state.editorPreferences.lastUsedHeight = newHeight
                        state.selection.selectedObj = objectManager.recreateThingFromBody(body, {
                            shapeType = shapeType,
                            width = newWidth or thing.width,
                            width2 = newWidth2 or thing.width2,

                            height = newHeight or thing.height,
                        })
                        body = state.selection.selectedObj.body
                    end
                else
                    -- For polygonal or other custom shapes, only allow radius control if applicable
                    if shapeType == 'triangle' or shapeType == 'pentagon' or shapeType == 'hexagon' or
                        shapeType == 'heptagon' or shapeType == 'octagon' then
                        nextRow()

                        local newRadius = ui.sliderWithInput(myID .. ' radius', x, y, ROW_WIDTH, 1, 200, thing.radius,
                            dirtyBodyChange)
                        ui.label(x, y, ' radius')
                        if newRadius and newRadius ~= thing.radius then
                            state.selection.selectedObj = objectManager.recreateThingFromBody(body,
                                { shapeType = shapeType, radius = newRadius })
                            state.editorPreferences.lastUsedRadius = newRadius
                            body = state.selection.selectedObj.body
                        end
                    else
                        -- No UI controls for custom or unsupported shapes
                        --ui.label(x, y, 'custom')
                        if ui.button(x, y, 260, state.polyEdit.lockedVerts and 'verts locked' or 'verts unlocked') then
                            state.polyEdit.lockedVerts = not state.polyEdit.lockedVerts
                            if state.polyEdit.lockedVerts == false then
                                state.polyEdit.tempVerts = utils.shallowCopy(state.selection.selectedObj.vertices)
                                local cx, cy = mathutils.computeCentroid(state.selection.selectedObj.vertices)
                                state.polyEdit.centroid = { x = cx, y = cy }
                            else
                                state.polyEdit.tempVerts = nil
                                state.polyEdit.centroid = nil
                            end
                        end
                    end
                end

                nextRow()
            end)


            nextRow()

            drawAccordion("physics", function()
                local fixtures = body:getFixtures()
                if #fixtures >= 1 then
                    local density = fixtures[1]:getDensity()

                    nextRow()
                    local newDensity = ui.sliderWithInput(myID .. 'density', x, y, ROW_WIDTH, 0, 10, density)
                    if newDensity and density ~= newDensity then
                        for i = 1, #fixtures do
                            fixtures[i]:setDensity(newDensity)
                        end
                    end
                    ui.label(x, y, ' density')

                    -- Bounciness Slider
                    local bounciness = fixtures[1]:getRestitution()
                    nextRow()

                    local newBounce = ui.sliderWithInput(myID .. 'bounce', x, y, ROW_WIDTH, 0, 1, bounciness)
                    if newBounce and bounciness ~= newBounce then
                        for i = 1, #fixtures do
                            fixtures[i]:setRestitution(newBounce)
                        end
                    end
                    ui.label(x, y, ' bounce')

                    -- Friction Slider
                    local friction = fixtures[1]:getFriction()
                    nextRow()

                    local newFriction = ui.sliderWithInput(myID .. 'friction', x, y, ROW_WIDTH, 0, 1, friction)
                    if newFriction and friction ~= newFriction then
                        for i = 1, #fixtures do
                            fixtures[i]:setFriction(newFriction)
                        end
                    end
                    ui.label(x, y, ' friction')
                    nextRow()


                    local fb = thing.body
                    local fixtures = fb:getFixtures()
                    local ff = fixtures[1]
                    local groupIndex = ff:getGroupIndex()
                    local groupIndexSlider = ui.sliderWithInput(myID .. 'groupIndex', x, y, 160, -32768, 32767,
                        groupIndex)
                    ui.label(x, y, ' groupid')
                    if groupIndexSlider then
                        local value = math.floor(groupIndexSlider)
                        local count = 0

                        local b = thing.body
                        local fixtures = b:getFixtures()
                        for j = 1, #fixtures do
                            fixtures[j]:setGroupIndex(value)
                            count = count + 1
                        end
                    end
                end
                nextRow()
            end)
            nextRow()
            drawAccordion("motion", function()
                -- set sleeping allowed
                nextRow()
                local dirty, checked = ui.checkbox(x, y, body:isSleepingAllowed(), 'sleep ok')
                if dirty then
                    body:setSleepingAllowed(not body:isSleepingAllowed())
                end
                nextRow()
                -- angukar veloicity
                local angleDegrees = tonumber(math.deg(body:getAngularVelocity()))
                if math.abs(angleDegrees) < 0.001 then angleDegrees = 0 end
                local newAngle = ui.sliderWithInput(myID .. 'angv', x, y, ROW_WIDTH, -180, 180, angleDegrees,
                    body:isAwake() and not state.world.paused)
                if newAngle and angleDegrees ~= newAngle then
                    body:setAngularVelocity(math.rad(newAngle))
                end
                ui.label(x, y, ' ang-vel')

                nextRow()
                local dirty, checked = ui.checkbox(x, y, body:isBullet(), 'bullet')
                if dirty then
                    body:setBullet(not body:isBullet())
                end

                nextRow()
            end
            )
            nextRow()
            if not body:isDestroyed() then
                local attachedJoints = body:getJoints()
                if attachedJoints and #attachedJoints > 0 and not (#attachedJoints == 1 and attachedJoints[1]:getType() == 'mouse') then
                    drawAccordion("joints", function()
                        for _, joint in ipairs(attachedJoints) do
                            -- Display joint type and unique identifier for identification
                            local jointType = joint:getType()
                            local jointID = tostring(joint)

                            if (jointType ~= 'mouse') then
                                -- Display joint button
                                x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT - 10)
                                local jointLabel = string.format("%s %s", jointType,
                                    string.sub(joint:getUserData().id, 1, 3))

                                if ui.button(x, y, 260, jointLabel) then
                                    state.selection.selectedJoint = joint
                                    --  state.selection.selectedObj = nil
                                end

                                local clicked, _, _, isHover = ui.button(x, y, 260, jointLabel)

                                if clicked then
                                    state.selection.selectedJoint = joint
                                end
                                if isHover then
                                    --print(inspect(joint:getUserData()))
                                    local ud = joint:getUserData()
                                    local x1, y1, x2, y2 = joint:getAnchors()
                                    -- local centroid = fixtures.getCentroidOfFixture(body, myfixtures[i])
                                    --  local x2, y2 = body:getLocalPoint(ud.offsetA.x, ud.offsetA.y)
                                    local x3, y3 = cam:getScreenCoordinates(x1, y1)
                                    love.graphics.circle('line', x3, y3, 6)
                                    local x3, y3 = cam:getScreenCoordinates(x2, y2)
                                    love.graphics.circle('line', x3, y3, 3)
                                end
                            end
                        end
                    end)
                    nextRow()
                end
            end
            local myfixtures = body:getFixtures()
            local ok, index  = fixtures.hasFixturesWithUserDataAtBeginning(myfixtures)
            if ok and index > 0 then
                drawAccordion("sfixtures", function()
                    for i = 1, index do
                        nextRow()
                        local fixLabel = string.format("%s %s", 'sf',
                            string.sub(myfixtures[i]:getUserData().id, 1, 3))
                        local clicked, _, _, isHover = ui.button(x, y, 260, fixLabel)

                        if clicked then
                            state.selection.selectedJoint = nil
                            state.selection.selectedObj = nil
                            state.selection.selectedSFixture = myfixtures[i]
                        end
                        if isHover then
                            local centroid = fixtures.getCentroidOfFixture(body, myfixtures[i])
                            local x2, y2 = body:getWorldPoint(centroid[1], centroid[2])
                            local x3, y3 = cam:getScreenCoordinates(x2, y2)
                            love.graphics.circle('line', x3, y3, 3)
                        end
                    end
                end)
                nextRow()
            end
        end
        nextRow()



        -- List Attached Joints Using Body:getJoints()
    end)
end

function lib.drawUI()
    ui.startFrame()
    local w, h = love.graphics.getDimensions()
    if state.world.paused then
        love.graphics.setColor({ 244 / 255, 164 / 255, 97 / 255 })
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
    if ui.button(440, 20, 200, 'settings') then
        state.panelVisibility.worldSettingsOpened = not state.panelVisibility.worldSettingsOpened
    end

    if state.panelVisibility.worldSettingsOpened then
        lib.drawWorldSettingsUI()
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
            script.call('onStart') --state.scene.sceneScript.onStart()
        end
    end

    if state.currentMode == 'drawClickMode' then
        local panelWidth = PANEL_WIDTH
        local w, h = love.graphics.getDimensions()
        ui.panel(w - panelWidth - 20, 20, panelWidth, h - 40, '∞ click draw vertex polygon ∞', function()
            local padding = BUTTON_SPACING
            local layout = ui.createLayout({
                type = 'columns',
                spacing = BUTTON_SPACING,
                startX = w - panelWidth,
                startY = 100 + padding
            })
            x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
            if ui.button(x, y, 260, 'finalize') then
                objectManager.finalizePolygon()
            end
            x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
            if ui.button(x, y, 260, 'soft-surface') then
                objectManager.finalizePolygonAsSoftSurface()
            end
        end)
    end

    if state.selection.selectedObj and not state.selection.selectedJoint and not state.selection.selectedSFixture then
        lib.drawUpdateSelectedObjectUI()
    end

    if state.selection.selectedBodies and #state.selection.selectedBodies > 0 then
        lib.drawSelectedBodiesUI()
    end

    if (state.currentMode == 'jointCreationMode') and state.jointParams.body1 and state.jointParams.body2 then
        lib.doJointCreateUI(500, 100, 400, 150)
    end

    if state.selection.selectedSFixture then
        lib.drawSelectedSFixture()
    end

    if state.selection.selectedObj and state.selection.selectedJoint then
        -- (w - panelWidth - 20, 20, panelWidth, h - 40
        lib.doJointUpdateUI(state.selection.selectedJoint, w - PANEL_WIDTH - 20, 20, PANEL_WIDTH, h - 40)
    end

    if (state.currentMode == 'setOffsetA') or (state.currentMode == 'setOffsetB') or state.currentMode == 'positioningSFixture' then
        ui.panel(500, 100, 300, 60, '• click point ∆', function()
        end)
    end

    if (state.currentMode == 'jointCreationMode') and ((state.jointParams.body1 == nil) or (state.jointParams.body2 == nil)) then
        if (state.jointParams.body1 == nil) then
            ui.panel(500, 100, 300, 100, '• pick 1st body •', function()
                local x = 510
                local y = 150
                local width = 280
                if ui.button(x, y, width, 'cancel') then
                    state.jointParams = nil
                    state.currentMode = nil
                end
            end)
        elseif (state.jointParams.body2 == nil) then
            ui.panel(500, 100, 300, 100, '• pick 2nd body •', function()
                local x = 510
                local y = 150
                local width = 280
                if ui.button(x, y, width, 'cancel') then
                    state.jointParams = nil
                    state.currentMode = nil
                end
            end)
        end
    end

    if state.panelVisibility.showPalette then
        local w, h = love.graphics.getDimensions()
        ui.panel(10, h - 400, w - 300, 400, '• pick color •', function()
            --ui.coloredRect()
            local cellHeight = 50
            local itemsPerRow = math.floor((w - 300) / cellHeight)
            local numRows = math.ceil(110 / itemsPerRow)
            -- assume a similar height for each swatch cell
            local maxRows = math.floor(400 / cellHeight)




            for i = 1, #box2dDrawTextured.palette do
                local row = math.floor((i - 1) / itemsPerRow)
                local column = (i - 1) % itemsPerRow
                local x = column * cellHeight
                local y = row * cellHeight

                -- ui.coloredRect(0, 0, { 255, 0, 0 }, 40)
                if ui.coloredRect(10 + x, h - 300 + y, { box2dDrawTextured.hexToColor(box2dDrawTextured.palette[i]) }, 40) then
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
                eio.save(state.physicsWorld, cam, state.editorPreferences.saveName)
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
        local m = panelW - minW
        ui.panel(offW / 2, offH / 2, panelW, panelH, header, function()
            ui.label(offW / 2 + 20, offH / 2 + 40, '[esc] to quit')
            ui.label(offW / 2 + 20, offH / 2 + 80, '[space] to cancel')
        end)
    end


    if ui.draggingActive then
        love.graphics.setColor(ui.theme.draggedElement.fill)
        local x, y = love.mouse.getPosition()
        love.graphics.circle('fill', x, y, 10)
        love.graphics.setColor(1, 1, 1)
    end
end

return lib

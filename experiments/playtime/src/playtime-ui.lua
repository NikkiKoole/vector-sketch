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

local PANEL_WIDTH = 300
local BUTTON_HEIGHT = 40
local ROW_WIDTH = 160
local BUTTON_SPACING = 10

local offsetHasChangedViaOutside

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

function lib.doJointCreateUI(uiState, _x, _y, w, h)
    ui.panel(_x, _y, w, h, '∞ ' .. uiState.jointCreationMode.jointType .. ' ∞', function()
        local layout = ui.createLayout({
            type = 'columns',
            spacing = 10,
            startX = _x + 10,
            startY = _y + 10
        })

        local width = 180
        local x, y = ui.nextLayoutPosition(layout, 160, 50)
        local nextRow = function()
            x, y = ui.nextLayoutPosition(layout, 160, 50)
        end
        nextRow()
        if ui.button(x, y, width, 'Create') then
            local j = joints.createJoint(uiState.jointCreationMode)
            uiState.selectedJoint = j
            uiState.selectedObject = nil
            uiState.jointCreationMode = nil
        end

        if ui.button(x + width + 10, y, width, 'Cancel') then
            uiState.jointCreationMode = nil
        end
    end)
end

function lib.doJointUpdateUI(uiState, j, _x, _y, w, h)
    if not j:isDestroyed() then
        ui.panel(_x, _y, w, h, '∞ ' .. j:getType() .. ' ∞', function()
            local bodyA, bodyB = j:getBodies()
            if uiState.jointUpdateMode == nil then
                uiState.jointUpdateMode = { body1 = bodyA, body2 = bodyB, jointType = j:getType() }
            end
            local layout = ui.createLayout({
                type = 'columns',
                spacing = 10,
                startX = _x + 10,
                startY = _y + 10
            })
            local jointType = j:getType()
            local jointId = joints.getJointId(j)
            local x, y = ui.nextLayoutPosition(layout, 160, 50)

            local nextRow = function()
                x, y = ui.nextLayoutPosition(layout, 160, 50)
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
                    uiState.axisEnabled or false,
                    function(val)
                        uiState.axisEnabled = val
                    end
                )

                if axisEnabled then
                    local _x, _y = j:getAxis()
                    --_x, _y = normalizeAxis(_x, _y)
                    nextRow()
                    local axisX = createSliderWithId(jointId, ' axisX', x, y, 160, -1, 1,
                        _x or 0,
                        function(val)
                            uiState.selectedJoint = joints.recreateJoint(j, { axisX = val, axisY = _y })
                            j = uiState.selectedJoint
                        end
                    )
                    nextRow()
                    local axisY = createSliderWithId(jointId, ' axisY', x, y, 160, -1, 1,
                        _y or 1,
                        function(val)
                            uiState.selectedJoint = joints.recreateJoint(j, { axisX = _x, axisY = val })
                            j = uiState.selectedJoint
                        end
                    )
                    nextRow()
                    if ui.button(x, y, 160, 'normalize') then
                        local _x, _y = j:getAxis()
                        _x, _y = mathutils.normalizeAxis(_x, _y)
                        uiState.selectedJoint = joints.recreateJoint(j, { axisX = _x, axisY = _y })
                        j = uiState.selectedJoint
                    end
                end
                return j
            end

            local function collideFunctionality(j)
                local collideEnabled = createCheckbox(' collide', x, y,
                    j:getCollideConnected(),
                    function(val)
                        uiState.selectedJoint = joints.recreateJoint(j, { collideConnected = val })
                        j = uiState.selectedJoint
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
                    uiState.selectedJoint = joints.recreateJoint(j)
                    j = uiState.selectedJoint


                    offsetHasChangedViaOutside = true
                    return j
                end

                function updateOffsetB(x, y)
                    --local rx, ry = rotatePoint(x, y, 0, 0, bodyA:getAngle())

                    offsetB.x = x
                    offsetB.y = y
                    joints.setJointMetaSetting(j, 'offsetB', { x = offsetB.x, y = offsetB.y })
                    uiState.selectedJoint = joints.recreateJoint(j)
                    j = uiState.selectedJoint


                    offsetHasChangedViaOutside = true
                    return j
                end

                -- Ensure offsets exist


                nextRow()
                if ui.button(x, y, 40, '∆') then
                    uiState.setOffsetAFunc = function(x, y)
                        local fx, fy = mathutils.rotatePoint(x - bodyA:getX(), y - bodyA:getY(), 0, 0, -bodyA:getAngle())
                        -- print(fx, fy)
                        return updateOffsetA(fx, fy)
                    end
                end
                if ui.button(x + 50, y, 40, 'b  ') then
                    uiState.setOffsetBFunc = function(x, y)
                        local fx, fy = mathutils.rotatePoint(x - bodyB:getX(), y - bodyB:getY(), 0, 0, -bodyB:getAngle())
                        -- print(fx, fy)
                        return updateOffsetB(fx, fy)
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
                    uiState.jointUpdateMode.length or myLength,
                    function(val)
                        j:setLength(val)
                        uiState.jointUpdateMode.length = val
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
                    uiState.jointUpdateMode.maxLength or myLength,
                    function(val)
                        j:setMaxLength(val)
                        uiState.jointUpdateMode.maxLength = val
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

        local minDist = ui.sliderWithInput('minDistance', x, y, 80, 1, 150, uiState.minPointDistance or 10)
        ui.label(x, y, 'dis')
        if minDist then
            uiState.minPointDistance = minDist
        end

        -- Add a button for custom polygon
         nextRow()
        if ui.button(x, y, width, 'freeform') then
            uiState.drawFreePoly = true
            uiState.polyVerts = {}
            uiState.lastPolyPt = nil
        end
        nextRow()

        if ui.button(x, y, width, 'click') then
            uiState.drawClickPoly = true
            uiState.polyVerts = {}
            uiState.lastPolyPt = nil
        end
        nextRow()

        local width = panelWidth - 20
        local height = buttonHeight

        local _, pressed, released = ui.button(x, y, width, 'sfixture')
        if pressed then
            ui.draggingActive = ui.activeElementID
            local mx, my = love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)

            uiState.offsetDragging = { 0, 0 }
        end
        if released then
            local mx, my = love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)
            local _, hitted = box2dPointerJoints.handlePointerPressed(wx, wy, 'mouse', {}, not worldState.paused)
            if (#hitted > 0) then
                local body = hitted[#hitted]:getBody()
                local localX, localY = body:getLocalPoint(wx, wy)
                local fixture = fixtures.createSFixture(body, localX, localY, { label = 'snap', radius = 30 })
                uiState.selectedSFixture = fixture
            end
            ui.draggingActive = nil
        end
        nextRow()


        local _, pressed, released = ui.button(x, y, width, 'texfixture')
        if pressed then
            ui.draggingActive = ui.activeElementID
            local mx, my = love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)

            uiState.offsetDragging = { 0, 0 }
        end
        if released then
            local mx, my = love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)
            local _, hitted = box2dPointerJoints.handlePointerPressed(wx, wy, 'mouse', {}, not worldState.paused)
            if (#hitted > 0) then
                local body = hitted[#hitted]:getBody()

                local verts = body:getUserData().thing.vertices
                local cx, cy, w, h = mathutils.getCenterOfPoints(verts)
                print(cx, cy, w, h)
                local localX, localY = body:getLocalPoint(wx, wy)
                local fixture = fixtures.createSFixture(body, localX, localY,
                    { label = 'texfixture', width = w, height = h })
                uiState.selectedSFixture = fixture
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
                uiState.jointCreationMode = { body1 = nil, body2 = nil, jointType = joint }
            end
        end
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
    ui.panel(startX, startY, panelWidth, panelHeight, '• ∫ƒF world •', function()
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
        local grav = ui.sliderWithInput('grav', x, y, ROW_WIDTH, -10, BUTTON_HEIGHT, worldState.gravity)
        if grav then
            worldState.gravity = grav
            if world then
                world:setGravity(0, worldState.gravity * worldState.meter)
            end
        end
        ui.label(x, y, ' gravity')
        nextRow()

        local g, value = ui.checkbox(x, y, uiState.showGrid, 'grid') --showGrid = true,
        if g then
            uiState.showGrid = value
        end
        local g, value = ui.checkbox(x + 150, y, worldState.debugDrawMode, 'draw') --showGrid = true,
        if g then
            worldState.debugDrawMode = value
        end
         nextRow()



        local debugAlpha = ui.sliderWithInput('debugalpha', x, y, ROW_WIDTH, 0, 1, worldState.debugAlpha)
        if debugAlpha then
            worldState.debugAlpha = debugAlpha
        end
        ui.label(x, y, ' dbgAlpha')
         nextRow()
          nextRow()

        local mouseForce = ui.sliderWithInput(' mouse F', x, y, ROW_WIDTH, 0, 1000000, worldState.mouseForce)
        if mouseForce then
            worldState.mouseForce = mouseForce
        end
        ui.label(x, y, ' mouse F')
         nextRow()

        local mouseDamp = ui.sliderWithInput(' damp', x, y, ROW_WIDTH, 0.001, 1, worldState.mouseDamping)
        if mouseDamp then
            worldState.mouseDamping = mouseDamp
        end
        ui.label(x, y, ' damp')


        -- Add Speed Multiplier Slider

         nextRow()
        local newSpeed = ui.sliderWithInput('speed', x, y, ROW_WIDTH, 0.1, 10.0, worldState.speedMultiplier)
        if newSpeed then
            worldState.speedMultiplier = newSpeed
        end
        ui.label(x, y, ' speed')

         nextRow()

        ui.label(x, y, registry.print())
         nextRow()

        if ui.button(x, y, ROW_WIDTH, worldState.profiling and 'profiling' or 'profile') then
            if worldState.profiling then
                ProFi:stop()
                ProFi:writeReport('profilingReport.txt')
                worldState.profiling = false
            else
                ProFi:start()
                worldState.profiling = true
            end
        end
    end)
end

local hadBeenDraggingObj = false

function lib.drawSelectedSFixture()
    local panelWidth = PANEL_WIDTH
    local w, h = love.graphics.getDimensions()
    if uiState.draggingObj then
        hadBeenDraggingObj = true
    end
    local ud = uiState.selectedSFixture:getUserData()
    local sfixtureType = (ud and ud.extra and ud.extra.type == 'texfixture') and 'texfixture' or 'sfixture'
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

        local myID = uiState.selectedSFixture:getUserData().id
        local myLabel = uiState.selectedSFixture:getUserData().label or ''
        --print(myID)

        local newLabel = ui.textinput(myID .. ' label', x, y, 260, 40, "", myLabel)
        if newLabel and newLabel ~= myLabel then
            local oldUD = utils.shallowCopy(uiState.selectedSFixture:getUserData())
            oldUD.label = newLabel

            uiState.selectedSFixture:setUserData(oldUD)
        end
        nextRow()


        if ui.button(x, y, ROW_WIDTH, 'destroy') then
            fixtures.destroyFixture(uiState.selectedSFixture)
            uiState.selectedSFixture = nil
            return
        end
        nextRow()


        local updateSFixturePosFunc = function(x, y)
            local body = uiState.selectedSFixture:getBody()
            local beforeIndex = 0
            local myfixtures = body:getFixtures()

            for i = 1, #myfixtures do
                if myfixtures[i] == uiState.selectedSFixture then
                    beforeIndex = i
                end
            end
            local localX, localY = body:getLocalPoint(x, y)
            local points = { uiState.selectedSFixture:getShape():getPoints() }
            local centerX, centerY = mathutils.getCenterOfPoints(points)
            local relativePoints = mathutils.makePolygonRelativeToCenter(points, centerX, centerY)
            local newShape = mathutils.makePolygonAbsolute(relativePoints, localX, localY)
            local oldUD = utils.shallowCopy(uiState.selectedSFixture:getUserData())
            uiState.selectedSFixture:destroy()

            local shape = love.physics.newPolygonShape(newShape)
            local newfixture = love.physics.newFixture(body, shape)
            newfixture:setSensor(true) -- Sensor so it doesn't collide

            newfixture:setUserData(oldUD)
            local afterIndex = 0
            local myfixtures = body:getFixtures()
            for i = 1, #myfixtures do
                if myfixtures[i] == newfixture then
                    afterIndex = i
                end
            end
            --print(beforeIndex, afterIndex)
            registry.registerSFixture(oldUD.id, newfixture)

            return newfixture
        end



        if ui.button(x, y, 40, '∆') then
            uiState.setUpdateSFixturePosFunc = updateSFixturePosFunc
        end
        nextRow()


        if sfixtureType == 'texfixture' then
            local points = { uiState.selectedSFixture:getShape():getPoints() }
            local w, h   = mathutils.getPolygonDimensions(points)
            -- print(w, h)
            --

            if ui.checkbox(x, y, uiState.showTexFixtureDim, 'dims') then
                uiState.showTexFixtureDim = not uiState.showTexFixtureDim
            end
            if ui.button(x + 150, y, ROW_WIDTH - 100, 'c') then
                local body = uiState.selectedSFixture:getBody()

                uiState.selectedSFixture = updateSFixturePosFunc(body:getX(), body:getY())
            end
            nextRow()

            if ui.button(x, y, 260, uiState.texFixtureLockedVerts and 'verts locked' or 'verts unlocked') then
                uiState.texFixtureLockedVerts = not uiState.texFixtureLockedVerts
                if uiState.texFixtureLockedVerts == false then
                    uiState.texFixtureTempVerts = utils.shallowCopy(points)
                    --local cx, cy = mathutils.computeCentroid(points)
                    --uiState.texFixtureCentroid = { x = cx, y = cy }
                else
                    uiState.texFixtureTempVerts = nil
                    --uiState.polyCentroid = nil
                end
            end

            if (uiState.showTexFixtureDim) then
                local newWidth = ui.sliderWithInput(myID .. ' width', x, y, ROW_WIDTH, 1, 1000, w)
                ui.label(x, y, ' width')
                nextRow()
                  local newHeight = ui.sliderWithInput(myID .. ' height', x, y, ROW_WIDTH, 1, 1000, h)
                ui.label(x, y, ' height')
                nextRow()

            end
            nextRow()

                local oldTexFixUD = uiState.selectedSFixture:getUserData()
            local newZOffset = ui.sliderWithInput(myID .. 'texfixzOffset', x, y, ROW_WIDTH, -180, 180,
                math.floor(oldTexFixUD.extra.zOffset or 0),
                (not worldState.paused) or dirtyBodyChange)
            if newZOffset and oldTexFixUD.extra.zOffset ~= newZOffset then
                 oldTexFixUD.extra.zOffset = math.floor(newZOffset)
            end
            ui.label(x, y, ' zOffset')


             nextRow()



            local dirty, checked = ui.checkbox(x, y, oldTexFixUD.extra.bgEnabled, '')
            if dirty then
                oldTexFixUD.extra.bgEnabled = not oldTexFixUD.extra.bgEnabled
                uiState.selectedSFixture:setUserData(oldTexFixUD)
            end
            local bgURL = ui.textinput(myID .. ' texfixbgURL', x + 40, y, 220, 40, "", oldTexFixUD.extra.bgURL or '')
            if bgURL and bgURL ~= oldTexFixUD.extra.bgURL then
                oldTexFixUD.extra.bgURL = bgURL
                uiState.selectedSFixture:setUserData(oldTexFixUD)
            end
             nextRow()

            local bgHex = ui.textinput(myID .. ' texfixbgHex', x, y, 260, 40, "", oldTexFixUD.extra.bgHex)
            if bgHex and bgHex ~= oldTexFixUD.extra.bgHex then
                oldTexFixUD.extra.bgHex = bgHex
            end
        else
            local points = { uiState.selectedSFixture:getShape():getPoints() }
            local dim = mathutils.getPolygonDimensions(points)
            local newRadius = ui.sliderWithInput(myID .. ' radius', x, y, ROW_WIDTH, 1, 200, dim)
            ui.label(x, y, ' radius')
            if newRadius and newRadius ~= dim then
                local oldUD = utils.shallowCopy(uiState.selectedSFixture:getUserData())
                local body = uiState.selectedSFixture:getBody()
                uiState.selectedSFixture:destroy()

                local centerX, centerY = mathutils.getCenterOfPoints(points)
                local shape = love.physics.newPolygonShape(rect(newRadius, newRadius, centerX, centerY))
                local newfixture = love.physics.newFixture(body, shape)
                newfixture:setSensor(true) -- Sensor so it doesn't collide

                newfixture:setUserData(oldUD)

                uiState.selectedSFixture = newfixture
                --snap.updateFixture(newfixture)
                registry.registerSFixture(oldUD.id, newfixture)
                snap.rebuildSnapFixtures(registry.sfixtures)
                -- uiState.selectedSFixture
            end
        end
         nextRow()



        local function handleOffset(xMultiplier, yMultiplier)
            local body = uiState.selectedSFixture:getBody()
            -- print('body position:', body:getPosition())
            local parentVerts = body:getUserData().thing.vertices


            local allFixtures = body:getUserData().thing.body:getFixtures()
            --local offsetX, offsetY = getCenterOfShapeFixtures(allFixtures)
            --  print(offsetX, offsetY)
            --  local testShape = { allFixtures[2]:getShape():getPoints() }
            ---  local centerX2, centerY2 = mathutils.getCenterOfPoints(testShape)
            -- print(inspect(testShape), centerX2, centerY2)

            local points = { uiState.selectedSFixture:getShape():getPoints() }
            local centerX, centerY = mathutils.getCenterOfPoints(points)

            --print('parentVerts', inspect(parentVerts))
            local bounds = mathutils.getBoundingRect(parentVerts)
            local relativePoints = mathutils.makePolygonRelativeToCenter(points, centerX, centerY)

            local newShape = mathutils.makePolygonAbsolute(relativePoints,
                ((bounds.width / 2) * xMultiplier),
                ((bounds.height / 2) * yMultiplier))

            local oldUD = utils.shallowCopy(uiState.selectedSFixture:getUserData())
            uiState.selectedSFixture:destroy()

            local shape = love.physics.newPolygonShape(newShape)

            local newfixture = love.physics.newFixture(body, shape)
            newfixture:setSensor(true) -- Sensor so it doesn't collide
            newfixture:setUserData(oldUD)
            uiState.selectedSFixture = newfixture
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
        -- local mx, my = love.mouse.getPosition()
        --local wx, wy = cam:getWorldCoordinates(mx, my)
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
            local cloned = eio.cloneSelection(uiState.selectedBodies, world)
            uiState.selectedBodies = cloned
        end
        nextRow()

        if ui.button(x, y, 260, 'destroy') then
            for i = #uiState.selectedBodies, 1, -1 do
                snap.destroySnapJointAboutBody(uiState.selectedBodies[i].body)
                objectManager.destroyBody(uiState.selectedBodies[i].body)
            end

            uiState.selectedBodies = nil
        end
         nextRow()

        if uiState.selectedBodies and #uiState.selectedBodies > 0 then
            local fb = uiState.selectedBodies[1].body
            local fixtures = fb:getFixtures()
            local ff = fixtures[1]
            local groupIndex = ff:getGroupIndex()
            local groupIndexSlider = ui.sliderWithInput('groupIndex', x, y, 160, -32768, 32767, groupIndex)
            ui.label(x, y, ' groupid')
            if groupIndexSlider then
                local value = math.floor(groupIndexSlider)
                local count = 0
                for i = 1, #uiState.selectedBodies do
                    local b = uiState.selectedBodies[i].body
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

-- Define a table to keep track of accordion states
local accordionStates = {
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
    local panelWidth = PANEL_WIDTH
    local w, h = love.graphics.getDimensions()
    ui.panel(w - panelWidth - 20, 20, panelWidth, h - 40, '∞ body props ∞', function()
        local body = uiState.selectedObj.body
        -- local angleDegrees = body:getAngle() * 180 / math.pi
        local myID = uiState.selectedObj.id

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

            local clicked = ui.header_button(x, y, PANEL_WIDTH - 40, (accordionStates[key] and " ÷  " or " •") ..
                ' ' .. key, accordionStates[key])
            if clicked then
                accordionStates[key] = not accordionStates[key]
            end
            y = y + BUTTON_HEIGHT + BUTTON_SPACING

            -- If the accordion is expanded, draw the content
            if accordionStates[key] then
                contentFunc(clicked)
            end
        end


        if ui.button(x, y, 100, 'clone') then
            --print(uiState.selectedObj)
            uiState.selectedBodies = { uiState.selectedObj }
            local cloned = eio.cloneSelection(uiState.selectedBodies, world)
            uiState.selectedBodies = cloned
            uiState.selectedObj = nil
        end

        if ui.button(x + 120, y, 140, 'destroy') then
            snap.destroySnapJointAboutBody(body)
            objectManager.destroyBody(body)
            uiState.selectedObj = nil
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
        if (uiState.lastSelectedBody ~= body) then
            dirtyBodyChange = true
            uiState.lastSelectedBody = body
        end

        if thing then
            -- Shape Properties
            local shapeType = thing.shapeType

            local newLabel = ui.textinput(myID .. ' label', x, y, 260, 40, "", thing.label)
            if newLabel and newLabel ~= thing.label then
                thing.label = newLabel -- Update the label
            end

            nextRow()


            nextRow()
            if false then
                drawAccordion("tags", function(clicked)
                    local w = love.graphics.getFont():getWidth('straight') + 20
                    -- ui.button(x, y, w, 'straight')
                    ui.toggleButton(x, y, w, 40, 'straight', 'straight', false)
                    nextRow()
                end)
                nextRow()
            end
            drawAccordion("position", function(clicked)
                nextRow()
                local value = thing.body:getX()
                local numericInputText, dirty = ui.textinput(myID .. 'x', x, y, 120, 40, ".", "" .. value, true,
                    clicked or not worldState.paused or uiState.draggingObj)
                if hadBeenDraggingObj then
                    dirty = true
                end
                if (dirty) then
                    local numericPosX = tonumber(numericInputText)
                    if numericPosX then
                        print('setting x')
                        thing.body:setX(numericPosX)
                    else
                        -- Handle invalid input, e.g., reset to previous value or show an error
                        print("Invalid X position input!")
                    end
                end
                local value = thing.body:getY()
                local numericInputText, dirty = ui.textinput(myID .. 'y', x + 140, y, 120, 40, ".", "" .. value, true,
                    clicked or not worldState.paused or uiState.draggingObj)
                if hadBeenDraggingObj then
                    dirty = true
                end
                if (dirty) then
                    local numericPosY = tonumber(numericInputText)
                    if numericPosY then
                        print('setting y')
                        thing.body:setY(numericPosY)
                    else
                        -- Handle invalid input, e.g., reset to previous value or show an error
                        print("Invalid Y position input!")
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
                    (body:isAwake() and not worldState.paused) or dirtyBodyChange)
                if newAngle and (body:getAngle() * 180 / math.pi) ~= newAngle then
                    body:setAngle(newAngle * math.pi / 180)
                end
                ui.label(x, y, ' angle')


                nextRow()

                local newZOffset = ui.sliderWithInput(myID .. 'zOffset', x, y, ROW_WIDTH, -180, 180,
                    math.floor(thing.zOffset),
                    (body:isAwake() and not worldState.paused) or dirtyBodyChange)
                if newZOffset and thing.zOffset ~= newZOffset then
                    thing.zOffset = math.floor(newZOffset)
                end
                ui.label(x, y, ' zOffset')
            end
            )
            nextRow()

            drawAccordion("transform", function(clicked)
                nextRow()

                if ui.button(x, y, 120, 'flipX') then
                    uiState.selectedObj = objectManager.flipThing(thing, 'x', true)
                    dirtyBodyChange = true
                end
                if ui.button(x + 140, y, 120, 'flipY') then
                    uiState.selectedObj = objectManager.flipThing(thing, 'y', true)
                    dirtyBodyChange = true
                end


                nextRow()
                if shapeType == 'circle' then
                    -- Show radius control for circles


                    local newRadius = ui.sliderWithInput(myID .. ' radius', x, y, ROW_WIDTH, 1, 200, thing.radius)
                    ui.label(x, y, ' radius')
                    if newRadius and newRadius ~= thing.radius then
                        uiState.selectedObj = objectManager.recreateThingFromBody(body,
                            { shapeType = "circle", radius = newRadius })
                        uiState.lastUsedRadius = newRadius
                        body = uiState.selectedObj.body
                    end
                elseif shapeType == 'rectangle' or shapeType == 'itriangle' then
                    -- Show width and height controls for these shapes


                    local newWidth = ui.sliderWithInput(myID .. ' width', x, y, ROW_WIDTH, 1, 800, thing.width)
                    ui.label(x, y, ' width')
                    nextRow()

                    local newHeight = ui.sliderWithInput(myID .. ' height', x, y, ROW_WIDTH, 1, 800, thing.height)
                    ui.label(x, y, ' height')

                    if (newWidth and newWidth ~= thing.width) or (newHeight and newHeight ~= thing.height) then
                        uiState.lastUsedWidth = newWidth
                        uiState.lastUsedHeight = newHeight
                        uiState.selectedObj = objectManager.recreateThingFromBody(body, {
                            shapeType = shapeType,
                            width = newWidth or thing.width,
                            height = newHeight or thing.height,
                        })
                        body = uiState.selectedObj.body
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
                        uiState.lastUsedWidth = newWidth
                        uiState.lastUsedWidth2 = newWidth2
                        uiState.lastUsedWidth3 = newWidth3
                        uiState.lastUsedHeight = newHeight
                        uiState.lastUsedHeight2 = newHeight2
                        uiState.lastUsedHeight3 = newHeight3
                        uiState.lastUsedHeight4 = newHeight4

                        uiState.selectedObj = objectManager.recreateThingFromBody(body, {
                            shapeType = shapeType,
                            width = newWidth or thing.width,
                            width2 = newWidth2 or thing.width2,
                            width3 = newWidth3 or thing.width3,
                            height = newHeight or thing.height,
                            height2 = newHeight2 or thing.height2,
                            height3 = newHeight3 or thing.height3,
                            height4 = newHeight4 or thing.height4,
                        })
                        body = uiState.selectedObj.body
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
                        uiState.lastUsedWidth2 = newWidth2
                        uiState.lastUsedWidth = newWidth
                        uiState.lastUsedHeight = newHeight
                        uiState.selectedObj = objectManager.recreateThingFromBody(body, {
                            shapeType = shapeType,
                            width = newWidth or thing.width,
                            width2 = newWidth2 or thing.width2,

                            height = newHeight or thing.height,
                        })
                        body = uiState.selectedObj.body
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
                            uiState.selectedObj = objectManager.recreateThingFromBody(body,
                                { shapeType = shapeType, radius = newRadius })
                            uiState.lastUsedRadius = newRadius
                            body = uiState.selectedObj.body
                        end
                    else
                        -- No UI controls for custom or unsupported shapes
                        --ui.label(x, y, 'custom')
                        if ui.button(x, y, 260, uiState.polyLockedVerts and 'verts locked' or 'verts unlocked') then
                            uiState.polyLockedVerts = not uiState.polyLockedVerts
                            if uiState.polyLockedVerts == false then
                                uiState.polyTempVerts = utils.shallowCopy(uiState.selectedObj.vertices)
                                local cx, cy = mathutils.computeCentroid(uiState.selectedObj.vertices)
                                uiState.polyCentroid = { x = cx, y = cy }
                            else
                                uiState.polyTempVerts = nil
                                uiState.polyCentroid = nil
                            end
                        end
                    end
                end

                nextRow()
            end)
            nextRow()

            drawAccordion("textures", function(clicked)
                nextRow()
                local dirty, checked = ui.checkbox(x, y, thing.textures.bgEnabled, '')
                if dirty then
                    thing.textures.bgEnabled = not thing.textures.bgEnabled
                end
                local bgURL = ui.textinput(myID .. ' bgURL', x + 40, y, 220, 40, "", thing.textures.bgURL)
                if bgURL and bgURL ~= thing.textures.bgURL then
                    --local oldUD = utils.shallowCopy(uiState.selectedSFixture:getUserData())
                    -- oldUD.label = newLabel
                    -- uiState.selectedSFixture:setUserData(oldUD)
                    --local info = love.filesystem.getInfo('textures/' .. thing.textures.bgURL)
                    --if (info and info.type == 'file') then else thing.textures.bgEnabled = false end
                    thing.textures.bgURL = bgURL
                end
                nextRow()
                local bgHex = ui.textinput(myID .. ' bgHex', x, y, 260, 40, "", thing.textures.bgHex)
                if bgHex and bgHex ~= thing.textures.bgHex then
                    thing.textures.bgHex = bgHex
                end


                nextRow()
                local dirty, checked = ui.checkbox(x, y, thing.textures.fgEnabled, '')
                if dirty then
                    thing.textures.fgEnabled = not thing.textures.fgEnabled
                end
                local fgURL = ui.textinput(myID .. ' fgURL', x + 40, y, 220, 40, "", thing.textures.fgURL)
                if fgURL and fgURL ~= thing.textures.fgURL then
                    --local oldUD = utils.shallowCopy(uiState.selectedSFixture:getUserData())
                    -- oldUD.label = newLabel
                    -- uiState.selectedSFixture:setUserData(oldUD)
                    --local info = love.filesystem.getInfo('textures/' .. thing.textures.bgURL)
                    --if (info and info.type == 'file') then else thing.textures.bgEnabled = false end
                    thing.textures.fgURL = fgURL
                end
                nextRow()
                local fgHex = ui.textinput(myID .. ' fgHex', x, y, 260, 40, "", thing.textures.fgHex)
                if fgHex and fgHex ~= thing.textures.fgHex then
                    thing.textures.fgHex = fgHex
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
                    body:isAwake() and not worldState.paused)
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
                                    uiState.selectedJoint = joint
                                    --  uiState.selectedObj = nil
                                end

                                local clicked, _, _, isHover = ui.button(x, y, 260, jointLabel)

                                if clicked then
                                    uiState.selectedJoint = joint
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
                            uiState.selectedJoint = nil
                            uiState.selectedObj = nil
                            uiState.selectedSFixture = myfixtures[i]
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

return lib

local lib = {}

local ui = require('src.ui.all')
local state = require('src.state')
local modes = require('src.modes')
local registry = require('src.registry')
local joints = require('src.joints')
local mathutils = require('src.math-utils')
local JT = require('src.joint-types')

local BUTTON_HEIGHT = ui.theme.lineHeight

-- Helper function to create a checkbox with an associated label
local function createCheckbox(labelText, x, y, value, callback)
    local changed, newValue = ui.checkbox(x, y, value, labelText)
    if changed then
        callback(newValue)
    end
    return newValue
end

function lib.drawJointUpdateUI(joint, panelX, panelY, w, h)
    if not joint:isDestroyed() then
        ui.panel(panelX, panelY, w, h, '∞ ' .. joint:getType() .. ' ∞', function()
            local bodyA, bodyB = joint:getBodies()

            local layout = ui.createLayout({
                type = 'columns',
                spacing = 10,
                startX = panelX + 10,
                startY = panelY + 10
            })
            local jointType = joint:getType()
            local jointId = joints.getJointId(joint)
            local x, y = ui.nextLayoutPosition(layout, 160, BUTTON_HEIGHT)

            local nextRow = function()
                x, y = ui.nextLayoutPosition(layout, 160, BUTTON_HEIGHT)
            end
            nextRow()
            local width = 280


            if ui.button(x, y, width, 'destroy') then
                local setId = joints.getJointId(joint)
                registry.unregisterJoint(setId)
                joint:destroy()
                return;
            end

            local function axisFunctionality()
                createCheckbox(' axis', x, y,
                    state.editorPreferences.axisEnabled or false,
                    function(val)
                        state.editorPreferences.axisEnabled = val
                    end
                )

                if state.editorPreferences.axisEnabled then
                    local _x, _y = joint:getAxis()
                    --_x, _y = normalizeAxis(_x, _y)
                    nextRow()
                    ui.createSliderWithId(jointId, ' axisX', x, y, 160, -1, 1,
                        _x or 0,
                        function(val)
                            state.selection.selectedJoint = joints.recreateJoint(joint, { axisX = val, axisY = _y })
                            joint = state.selection.selectedJoint
                        end
                    )
                    nextRow()
                    ui.createSliderWithId(jointId, ' axisY', x, y, 160, -1, 1,
                        _y or 1,
                        function(val)
                            state.selection.selectedJoint = joints.recreateJoint(joint, { axisX = _x, axisY = val })
                            joint = state.selection.selectedJoint
                        end
                    )
                    nextRow()
                    if ui.button(x, y, 160, 'normalize') then
                        local ax, ay = joint:getAxis()
                        ax, ay = mathutils.normalizeAxis(ax, ay)
                        state.selection.selectedJoint = joints.recreateJoint(joint, { axisX = ax, axisY = ay })
                        joint = state.selection.selectedJoint
                    end
                end
                return joint
            end

            local function collideFunctionality()
                createCheckbox(' collide', x, y,
                    joint:getCollideConnected(),
                    function(val)
                        state.selection.selectedJoint = joints.recreateJoint(joint, { collideConnected = val })
                        joint = state.selection.selectedJoint
                    end
                )
                return joint
            end

            local function motorFunctionality(settings)
                createCheckbox(' motor', x, y,
                    joint:isMotorEnabled(),
                    function(val)
                        joint:setMotorEnabled(val)
                    end
                )
                nextRow()
                if joint:isMotorEnabled() then
                    ui.createSliderWithId(jointId, ' speed', x, y, 160, -1000, 1000,
                        joint:getMotorSpeed(),
                        function(val) joint:setMotorSpeed(val) end
                    )
                    nextRow()
                    if (settings and settings.useTorque) then
                        ui.createSliderWithId(jointId, ' max T', x, y, 160, 0, 100000,
                            joint:getMaxMotorTorque(),
                            function(val) joint:setMaxMotorTorque(val) end
                        )
                        nextRow()
                    end
                    if (settings and settings.useForce) then
                        ui.createSliderWithId(jointId, ' max F', x, y, 160, 0, 100000,
                            joint:getMaxMotorForce(),
                            function(val) joint:setMaxMotorForce(val) end
                        )
                        nextRow()
                    end
                end
            end

            local function limitsFunctionalityAngular()
                createCheckbox(' limits', x, y,
                    joint:areLimitsEnabled(),
                    function(val)
                        joint:setLimitsEnabled(val)
                    end
                )

                if (joint:areLimitsEnabled()) then
                    nextRow()
                    local up = math.deg(joint:getUpperLimit())
                    ui.createSliderWithId(jointId, ' lower', x, y, 160, -180, up,
                        math.deg(joint:getLowerLimit()),
                        function(val)
                            local newValue = math.rad(val)

                            joint:setLowerLimit(newValue)
                        end
                    )
                    nextRow()
                    local low = math.deg(joint:getLowerLimit())
                    ui.createSliderWithId(jointId, ' upper', x, y, 160, low, 180,
                        math.deg(joint:getUpperLimit()),
                        function(val)
                            local newValue = math.rad(val)
                            joint:setUpperLimit(newValue)
                        end
                    )
                end
            end

            local function limitsFunctionalityLinear()
                createCheckbox(' limits', x, y,
                    joint:areLimitsEnabled(),
                    function(val)
                        joint:setLimitsEnabled(val)
                    end
                )

                if (joint:areLimitsEnabled()) then
                    nextRow()
                    local up = (joint:getUpperLimit())
                    ui.createSliderWithId(jointId, ' lower', x, y, 160, -1000, up,
                        joint:getLowerLimit(),
                        function(val)
                            joint:setLowerLimit(val)
                        end
                    )
                    nextRow()
                    local low = joint:getLowerLimit()
                    ui.createSliderWithId(jointId, ' upper', x, y, 160, low, 1000,
                        joint:getUpperLimit(),
                        function(val)
                            joint:setUpperLimit(val)
                        end
                    )
                end
            end

            local function offsetSliders()
                if not joints.getJointMetaSetting(joint, 'offsetA') then
                    joints.setJointMetaSetting(joint, 'offsetA', { x = 0, y = 0 })
                end
                local offsetA = joints.getJointMetaSetting(joint, 'offsetA') or 0

                if not joints.getJointMetaSetting(joint, 'offsetB') then
                    joints.setJointMetaSetting(joint, 'offsetB', { x = 0, y = 0 })
                end

                local function updateOffsetA(ox, oy)
                    --local rx, ry = rotatePoint(ox, oy, 0, 0, bodyA:getAngle())

                    offsetA.x = ox
                    offsetA.y = oy
                    joints.setJointMetaSetting(joint, 'offsetA', { x = offsetA.x, y = offsetA.y })
                    state.selection.selectedJoint = joints.recreateJoint(joint)
                    joint = state.selection.selectedJoint


                    return joint
                end

                -- Ensure offsets exist


                nextRow()
                if ui.button(x, y, BUTTON_HEIGHT, '∆') then
                    modes.set(modes.SET_OFFSET_A)
                end
                if jointType ~= JT.REVOLUTE then
                    if ui.button(x + 50, y, BUTTON_HEIGHT, 'b  ') then
                        modes.set(modes.SET_OFFSET_B)
                    end
                end
                nextRow()

                local bodyARef = joint:getBodies()
                local ud = bodyARef:getUserData()


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



                return joint
            end

            if jointType == JT.DISTANCE then
                nextRow()
                collideFunctionality()
                nextRow()
                offsetSliders()
                nextRow()
                -- local bodyA, bodyB = joint:getBodies()
                local x1, y1 = bodyA:getPosition()
                local x2, y2 = bodyB:getPosition()
                local myLength = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
                ui.createSliderWithId(jointId, ' length', x, y, 160, 0.1, 500,
                    state.jointLengthParams.length or myLength,
                    function(val)
                        joint:setLength(val)
                        state.jointLengthParams.length = val
                    end
                )
                nextRow()

                ui.createSliderWithId(jointId, ' freq', x, y, 160, 0, 20,
                    joint:getFrequency(),
                    function(val) joint:setFrequency(val) end
                )
                nextRow()
                ui.createSliderWithId(jointId, ' damp', x, y, 160, 0, 20,
                    joint:getDampingRatio(),
                    function(val) joint:setDampingRatio(val) end
                )

                nextRow()
                nextRow()
            elseif jointType == JT.WELD then
                nextRow()
                collideFunctionality()
                nextRow()
                offsetSliders()
                nextRow()
                ui.createSliderWithId(jointId, ' freq', x, y, 160, 0, 20,
                    joint:getFrequency(),
                    function(val) joint:setFrequency(val) end
                )
                nextRow()
                ui.createSliderWithId(jointId, ' damp', x, y, 160, 0, 20,
                    joint:getDampingRatio(),
                    function(val) joint:setDampingRatio(val) end
                )
                nextRow()
            elseif jointType == JT.ROPE then
                nextRow()
                collideFunctionality()
                nextRow()
                offsetSliders()
                nextRow()
                -- local bodyA, bodyB = joint:getBodies()
                local x1, y1 = bodyA:getPosition()
                local x2, y2 = bodyB:getPosition()
                local myLength = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
                ui.createSliderWithId(jointId, ' length', x, y, 160, 0.1, 500,
                    state.jointLengthParams.maxLength or myLength,
                    function(val)
                        joint:setMaxLength(val)
                        state.jointLengthParams.maxLength = val
                    end
                )
                nextRow()
            elseif jointType == JT.REVOLUTE then
                nextRow()
                collideFunctionality()
                nextRow()
                offsetSliders()
                nextRow()
                limitsFunctionalityAngular()
                nextRow()
                motorFunctionality({ useTorque = true })
            elseif jointType == JT.WHEEL then
                nextRow()
                collideFunctionality()
                nextRow()
                offsetSliders()
                nextRow()
                axisFunctionality()
                nextRow()
                -- if not joint:isDestroyed() then
                ui.createSliderWithId(jointId, ' spring F', x, y, 160, 0, 100,
                    joint:getSpringFrequency(),
                    function(val)
                        joint:setSpringFrequency(val)
                    end
                )
                nextRow()
                ui.createSliderWithId(jointId, ' spring D', x, y, 160, 0, 1,
                    joint:getSpringDampingRatio(),
                    function(val) joint:setSpringDampingRatio(val) end
                )
                nextRow()
                motorFunctionality({ useTorque = true })
                -- axisFunctionality(joint)
                nextRow()
                --  end
            elseif jointType == JT.MOTOR then
                nextRow()
                collideFunctionality()
                nextRow()
                offsetSliders()
                nextRow()
                ui.createSliderWithId(jointId, ' angular o', x, y, 160, -180, 180,
                    math.deg(joint:getAngularOffset()),
                    function(val) joint:setAngularOffset(math.rad(val)) end
                )
                nextRow()
                ui.createSliderWithId(jointId, ' corr.', x, y, 160, 0, 1,
                    joint:getCorrectionFactor(),
                    function(val) joint:setCorrectionFactor(val) end
                )
                nextRow()
                local lx, ly = joint:getLinearOffset()
                ui.createSliderWithId(jointId, ' lx', x, y, 160, -1000, 1000,
                    lx,
                    function(val) joint:setLinearOffset(val, ly) end
                )
                nextRow()
                ui.createSliderWithId(jointId, ' ly', x, y, 160, -1000, 1000,
                    ly,
                    function(val) joint:setLinearOffset(lx, val) end
                )
                nextRow()
                ui.createSliderWithId(jointId, ' force', x, y, 160, 0, 100000,
                    joint:getMaxForce(),
                    function(val) joint:setMaxForce(val) end
                )
                nextRow()
                ui.createSliderWithId(jointId, ' torque', x, y, 160, 0, 100000,
                    joint:getMaxTorque(),
                    function(val) joint:setMaxTorque(val) end
                )
                nextRow()
            elseif jointType == JT.FRICTION then
                offsetSliders()
                nextRow()
                ui.createSliderWithId(jointId, ' force', x, y, 160, 0, 100000,
                    joint:getMaxForce(),
                    function(val) joint:setMaxForce(val) end
                )
                nextRow()
                ui.createSliderWithId(jointId, ' torque', x, y, 160, 0, 100000,
                    joint:getMaxTorque(),
                    function(val) joint:setMaxTorque(val) end
                )
                nextRow()
            elseif jointType == JT.PRISMATIC then
                nextRow()
                collideFunctionality()
                nextRow()
                offsetSliders()
                nextRow()
                axisFunctionality()
                nextRow()
                limitsFunctionalityLinear()
                nextRow()
                motorFunctionality({ useForce = true })
            end
        end)
    end
end

return lib

--joints.lua
local ui = require 'src.ui-all'
local lib = {}
local inspect = require 'vendor.inspect'
local uuid = require 'src.uuid'
local jointHandlers = require 'src.joint-handlers'
local registry = require 'src.registry'
local mathutils = require 'src.math-utils'

local offsetHasChangedViaOutside
-- Helper function to create a slider with an associated label
local function createSlider(labelText, x, y, width, min, max, value, callback, changed)
    local newValue = ui.sliderWithInput(labelText, x, y, width, min, max, value, changed)
    if newValue then
        callback(newValue)
    end
    ui.label(x, y, labelText)
    return newValue
end

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


local function getJointId(joint)
    local ud = joint:getUserData()
    if ud then
        return ud.id
    end
    print('THIS IS WRONG WHY THIS JOINT HAS NO ID!!', tostring(joint:getType()))
    return nil
end

local function setJointMetaSetting(joint, settingKey, settingValue)
    -- Get the existing userdata
    local ud = joint:getUserData() or {}

    -- Ensure userdata is a table
    if type(ud) ~= "table" then
        ud = {} -- Initialize as a table if not already
    end

    -- Update or add the specific setting
    ud[settingKey] = settingValue

    -- Set the updated userdata back on the joint
    joint:setUserData(ud)
end

local function getJointMetaSetting(joint, settingKey)
    -- Get the existing userdata
    local ud = joint:getUserData()

    -- Check if userdata exists and is a table
    if type(ud) == "table" then
        return ud[settingKey] -- Return the specific setting
    else
        print('could not find meta settting ' .. settingKey .. ' on joint with type ' .. tostring(joint:getType()))
        return nil -- Return nil if userdata is not a table or doesn't exist
    end
end



function lib.createJoint(data)
    local bodyA = data.body1
    local bodyB = data.body2
    local jointType = data.jointType

    local joint

    local x1, y1 = bodyA:getPosition()
    local x2, y2 = bodyB:getPosition()
    local offsetA = data.offsetA or { x = 0, y = 0 }
    local rx, ry = mathutils.rotatePoint(offsetA.x, offsetA.y, 0, 0, bodyA:getAngle())
    x1, y1 = x1 + rx, y1 + ry

    local offsetB = data.offsetB or { x = 0, y = 0 }
    local rx, ry = mathutils.rotatePoint(offsetB.x, offsetB.y, 0, 0, bodyB:getAngle())
    x2, y2 = x2 + rx, y2 + ry

    local handler = jointHandlers[jointType]

    if handler and handler.create then
        joint = handler.create(data, x1, y1, x2, y2)
    else
        print("Joint type '" .. jointType .. "' is not implemented yet.")
        return
    end

    local setId = data.id or uuid.generateID()
    joint:setUserData({ id = setId })
    setJointMetaSetting(joint, 'offsetA', offsetA)
    setJointMetaSetting(joint, 'offsetB', offsetB)

    registry.registerJoint(setId, joint)
    return joint
end

function lib.extractJoints(body)
    local joints = body:getJoints()
    local jointData = {}

    for _, joint in ipairs(joints) do
        local bodyA, bodyB = joint:getBodies()
        local otherBody = (bodyA == body) and bodyB or bodyA -- Determine the other connected body
        local jointType = joint:getType()
        local isBodyA = (bodyA == body)

        local data = {
            offsetA = getJointMetaSetting(joint, "offsetA"),
            offsetB = getJointMetaSetting(joint, "offsetB"),
            id = getJointId(joint),
            jointType = jointType,
            otherBody = otherBody,
            collideConnected = joint:getCollideConnected(),
            originalBodyOrder = isBodyA and "bodyA" or "bodyB",
        }

        local handler = jointHandlers[jointType]
        if not handler or not handler.extract then
            print("extract: Unsupported joint type: " .. jointType)
            goto continue
        end

        -- Extract additional data using the handler
        local additionalData = handler.extract(joint)
        for key, value in pairs(additionalData) do
            data[key] = value
        end

        table.insert(jointData, data)
        ::continue::
    end

    return jointData
end

function lib.recreateJoint(joint, newSettings)
    if joint:isDestroyed() then
        print("The joint is already destroyed.")
        return nil
    end

    local bodyA, bodyB = joint:getBodies()
    local jointType = joint:getType()

    local id = getJointId(joint)
    local offsetA = getJointMetaSetting(joint, "offsetA") or { x = 0, y = 0 }
    local offsetB = getJointMetaSetting(joint, "offsetB") or { x = 0, y = 0 }
    --  print(inspect(offsetA), inspect(offsetB))
    local data = {
        body1 = bodyA,
        body2 = bodyB,
        jointType = jointType,
        id = id,
        offsetA = offsetA,
        offsetB = offsetB,
        collideConnected =
            joint:getCollideConnected()
    }

    -- Add new settings to the data
    for key, value in pairs(newSettings or {}) do
        data[key] = value
    end

    local handler = jointHandlers[jointType]
    if not handler or not handler.extract then
        print("recreate extract: Unsupported joint type: " .. jointType)
    end

    -- Extract additional data using the handler
    local additionalData = handler.extract(joint)
    for key, value in pairs(additionalData) do
        data[key] = value
    end

    joint:destroy()

    -- Create a new joint with the updated data
    bodyA:setAwake(true)
    bodyB:setAwake(true)
    --  print(inspect(data))
    return lib.createJoint(data)
end

function lib.reattachJoints(jointData, newBody)
    for _, data in ipairs(jointData) do
        local jointType = data.jointType
        local otherBody = data.otherBody

        if data.originalBodyOrder == "bodyA" then
            data.body1 = newBody
            data.body2 = data.otherBody
        else
            data.body1 = data.otherBody
            data.body2 = newBody
        end

        -- Create the joint using the existing createJoint method
        lib.createJoint(data)
    end
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
            local j = lib.createJoint(uiState.jointCreationMode)
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
            local jointId = getJointId(j)
            local x, y = ui.nextLayoutPosition(layout, 160, 50)

            local nextRow = function()
                x, y = ui.nextLayoutPosition(layout, 160, 50)
            end
            nextRow()
            local width = 280


            if ui.button(x, y, width, 'destroy') then
                local setId = getJointId(j)
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
                            uiState.selectedJoint = lib.recreateJoint(j, { axisX = val, axisY = _y })
                            j = uiState.selectedJoint
                        end
                    )
                    nextRow()
                    local axisY = createSliderWithId(jointId, ' axisY', x, y, 160, -1, 1,
                        _y or 1,
                        function(val)
                            uiState.selectedJoint = lib.recreateJoint(j, { axisX = _x, axisY = val })
                            j = uiState.selectedJoint
                        end
                    )
                    nextRow()
                    if ui.button(x, y, 160, 'normalize') then
                        local _x, _y = j:getAxis()
                        _x, _y = mathutils.normalizeAxis(_x, _y)
                        uiState.selectedJoint = lib.recreateJoint(j, { axisX = _x, axisY = _y })
                        j = uiState.selectedJoint
                    end
                end
                return j
            end

            local function collideFunctionality(j)
                local collideEnabled = createCheckbox(' collide', x, y,
                    j:getCollideConnected(),
                    function(val)
                        uiState.selectedJoint = lib.recreateJoint(j, { collideConnected = val })
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
                if not getJointMetaSetting(j, 'offsetA') then
                    setJointMetaSetting(j, 'offsetA', { x = 0, y = 0 })
                end
                local offsetA = getJointMetaSetting(j, 'offsetA') or 0

                if not getJointMetaSetting(j, 'offsetB') then
                    setJointMetaSetting(j, 'offsetB', { x = 0, y = 0 })
                end
                local offsetB = getJointMetaSetting(j, 'offsetB') or 0

                function updateOffsetA(x, y)
                    --local rx, ry = rotatePoint(x, y, 0, 0, bodyA:getAngle())

                    offsetA.x = x
                    offsetA.y = y
                    setJointMetaSetting(j, 'offsetA', { x = offsetA.x, y = offsetA.y })
                    uiState.selectedJoint = lib.recreateJoint(j)
                    j = uiState.selectedJoint


                    offsetHasChangedViaOutside = true
                    return j
                end

                function updateOffsetB(x, y)
                    --local rx, ry = rotatePoint(x, y, 0, 0, bodyA:getAngle())

                    offsetB.x = x
                    offsetB.y = y
                    setJointMetaSetting(j, 'offsetB', { x = offsetB.x, y = offsetB.y })
                    uiState.selectedJoint = lib.recreateJoint(j)
                    j = uiState.selectedJoint


                    offsetHasChangedViaOutside = true
                    return j
                end

                -- Ensure offsets exist


                nextRow()
                if ui.button(x, y, 40, 'O') then
                    uiState.setOffsetAFunc = function(x, y)
                        local fx, fy = mathutils.rotatePoint(x - bodyA:getX(), y - bodyA:getY(), 0, 0, -bodyA:getAngle())
                        -- print(fx, fy)
                        return updateOffsetA(fx, fy)
                    end
                end
                if ui.button(x + 50, y, 40, '+') then
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

return lib

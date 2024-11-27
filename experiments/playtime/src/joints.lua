local ui = require 'src.ui-all'
local lib = {}
local inspect = require 'vendor.inspect'
local uuid = require 'src.uuid'

local registry = require 'src.registry'

local function generateID()
    return uuid.uuid()
end

local offsetHasChangedViaOutside
-- Helper function to create a slider with an associated label
local function createSlider(labelText, x, y, width, min, max, value, callback, changed)
    if not _id then _id = '' end
    local newValue = ui.sliderWithInput(_id .. labelText, x, y, width, min, max, value, changed)
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

local function calculateDistance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
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

local function normalizeAxis(x, y)
    local magnitude = math.sqrt(x ^ 2 + y ^ 2)
    if magnitude == 0 then
        return 1, 0 -- Default to (1, 0) if the vector is zero
    else
        --   print('normalizing', x / magnitude, y / magnitude)
        return x / magnitude, y / magnitude
    end
end
function rotatePoint(x, y, originX, originY, angle)
    -- Translate the point to the origin
    local translatedX = x - originX
    local translatedY = y - originY

    -- Apply rotation
    local rotatedX = translatedX * math.cos(angle) - translatedY * math.sin(angle)
    local rotatedY = translatedX * math.sin(angle) + translatedY * math.cos(angle)

    -- Translate back to the original position
    local finalX = rotatedX + originX
    local finalY = rotatedY + originY

    return finalX, finalY
end

function lib.createJoint(data)
    local bodyA = data.body1
    local bodyB = data.body2
    local jointType = data.jointType

    local joint
    local world = bodyA:getWorld() -- Assuming both bodies are in the same world
    local x1, y1 = bodyA:getPosition()
    local x2, y2 = bodyB:getPosition()
    local offsetA = data.offsetA or { x = 0, y = 0 }
    local rx, ry = rotatePoint(offsetA.x, offsetA.y, 0, 0, bodyA:getAngle())

    --x1, y1 = x1 + offsetA.x, y1 + offsetA.y
    x1, y1 = x1 + rx, y1 + ry
    if jointType == 'distance' then
        -- Create a Distance Joint

        local length = data.length or math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        joint = love.physics.newDistanceJoint(bodyA, bodyB, x1, y1, x2, y2, data.collideConnected)
        joint:setLength(length)
    elseif jointType == 'weld' then
        -- Create a Weld Joint at the first body's position

        joint = love.physics.newWeldJoint(bodyA, bodyB, x1, y1, data.collideConnected)
        --joint = love.physics.newWeldJoint(bodyA, bodyB, x1, y1, x2, y2, data.collideConnected)
        -- Weld joints don't have frequency or damping ratio by default, but you can simulate similar behavior if needed.
    elseif jointType == 'rope' then
        -- Create a Rope Joint

        local maxLength = data.maxLength or math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        joint = love.physics.newRopeJoint(bodyA, bodyB, x1, y1, x2, y2, maxLength, data.collideConnected)
    elseif jointType == 'revolute' then
        -- Create a Revolute Joint at the first body's position

        -- joint = love.physics.newRevoluteJoint(bodyA, bodyB, x1, y1, x2, y2, data.collideConnected)
        joint = love.physics.newRevoluteJoint(bodyA, bodyB, x1, y1, data.collideConnected)
    elseif jointType == 'wheel' then
        -- Create a Wheel Joint



        joint = love.physics.newWheelJoint(bodyA, bodyB, x1, y1, data.axisX or 0, data.axisY or 1, data.collideConnected)
    elseif jointType == 'motor' then
        -- Create a Motor Joint
        joint = love.physics.newMotorJoint(bodyA, bodyB, data.correctionFactor or .3, data.collideConnected)
    elseif jointType == 'prismatic' then
        -- Create a Prismatic Joint


        joint = love.physics.newPrismaticJoint(bodyA, bodyB, x1, y1, data.axisX or 0, data.axisY or 1,
            data.collideConnected)
        --joint = love.physics.newPrismaticJoint(bodyA, bodyB, x1, y1, x2, y2, data.axisX or 0, data.axisX or 1,
        --    data.collideConnected)
        joint:setLowerLimit(0)
        joint:setUpperLimit(0)
    elseif jointType == 'pulley' then
        -- Create a Pulley Joint
        -- Ground anchors are typically fixed points; adjust as necessary
        --  local x1, y1 = data.groundAnchor1 or { 0, 0 }, data.groundAnchor2 or { 0, 0 }
        local groundAnchorA = data.groundAnchor1 or { 0, 0 }
        local groundAnchorB = data.groundAnchor2 or { 0, 0 }
        local bodyA_centerX, bodyA_centerY = bodyA:getWorldCenter()
        local bodyB_centerX, bodyB_centerY = bodyB:getWorldCenter()
        local ratio = data.ratio or 1

        joint = love.physics.newPulleyJoint(
            bodyA, bodyB,
            bodyA_centerX or groundAnchorA[1], groundAnchorA[2],
            bodyB_centerX or groundAnchorB[1], groundAnchorB[2],
            bodyA_centerX, bodyA_centerY,
            bodyB_centerX, bodyB_centerY,
            ratio,
            false
        )
    elseif jointType == 'friction' then
        -- Create a Friction Joint
        local x, y = bodyA:getPosition()
        joint = love.physics.newFrictionJoint(bodyA, bodyB, x1, y1, false)

        if data.maxForce then
            joint:setMaxForce(data.maxForce)
        end
        if data.maxTorque then
            joint:setMaxTorque(data.maxTorque)
        end
    else
        -- Handle other joints or unimplemented types
        print("Joint type '" .. jointType .. "' is not implemented yet.")
        -- uiState.jointCreationMode = nil
        return
    end
    local setId = data.id or generateID()
    joint:setUserData({ id = setId })
    setJointMetaSetting(joint, 'offsetA', offsetA)
    --print('joint' .. setId)
    -- print(inspect(getmetatable(joint)))
    registry.registerJoint(setId, joint)
    return joint
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
    local data = { body1 = bodyA, body2 = bodyB, jointType = jointType, id = id, offsetA = offsetA }

    -- Add new settings to the data
    for key, value in pairs(newSettings or {}) do
        data[key] = value
    end

    -- Extract settings based on the joint type
    if jointType == 'distance' then
        data.length = joint:getLength()
        data.frequency = joint:getFrequency()
        data.dampingRatio = joint:getDampingRatio()
    elseif jointType == 'weld' then
        data.frequency = joint:getFrequency()
        data.dampingRatio = joint:getDampingRatio()
    elseif jointType == 'rope' then
        data.maxLength = joint:getMaxLength()
    elseif jointType == 'revolute' then
        data.motorEnabled = joint:isMotorEnabled()
        if data.motorEnabled then
            data.motorSpeed = joint:getMotorSpeed()
            data.maxMotorTorque = joint:getMaxMotorTorque()
        end
        data.limitsEnabled = joint:areLimitsEnabled()
        if data.limitsEnabled then
            data.lowerLimit = joint:getLowerLimit()
            data.upperLimit = joint:getUpperLimit()
        end
    elseif jointType == 'wheel' then
        data.springFrequency = joint:getSpringFrequency()
        data.springDampingRatio = joint:getSpringDampingRatio()
    elseif jointType == 'motor' then
        data.correctionFactor = joint:getCorrectionFactor()
        data.angularOffset = joint:getAngularOffset()
        data.linearOffsetX, data.linearOffsetY = joint:getLinearOffset()
        data.maxForce = joint:getMaxForce()
        data.maxTorque = joint:getMaxTorque()
    elseif jointType == 'prismatic' then
        data.motorEnabled = joint:isMotorEnabled()
        if data.motorEnabled then
            data.motorSpeed = joint:getMotorSpeed()
            data.maxMotorForce = joint:getMaxMotorForce()
        end
        data.limitsEnabled = joint:areLimitsEnabled()
        if data.limitsEnabled then
            data.lowerLimit = joint:getLowerLimit()
            data.upperLimit = joint:getUpperLimit()
        end
    elseif jointType == 'pulley' then
        data.groundAnchor1 = { joint:getGroundAnchors() }
        data.ratio = joint:getRatio()
    elseif jointType == 'friction' then
        data.maxForce = joint:getMaxForce()
        data.maxTorque = joint:getMaxTorque()
    else
        print("Unsupported joint type: " .. jointType)
        return nil
    end

    -- Destroy the existing joint
    joint:destroy()

    -- Create a new joint with the updated data
    bodyA:setAwake(true)
    bodyB:setAwake(true)
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
            uiState.currentlySelectedJoint = j
            uiState.currentlySelectedObject = nil
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
                            uiState.currentlySelectedJoint = lib.recreateJoint(j, { axisX = val, axisY = _y })
                            j = uiState.currentlySelectedJoint
                        end
                    )
                    nextRow()
                    local axisY = createSliderWithId(jointId, ' axisY', x, y, 160, -1, 1,
                        _y or 1,
                        function(val)
                            uiState.currentlySelectedJoint = lib.recreateJoint(j, { axisX = _x, axisY = val })
                            j = uiState.currentlySelectedJoint
                        end
                    )
                    nextRow()
                    if ui.button(x, y, 160, 'normalize') then
                        local _x, _y = j:getAxis()
                        _x, _y = normalizeAxis(_x, _y)
                        uiState.currentlySelectedJoint = lib.recreateJoint(j, { axisX = _x, axisY = _y })
                        j = uiState.currentlySelectedJoint
                    end
                end
                return j
            end

            local function collideFunctionality(j)
                local collideEnabled = createCheckbox(' collide', x, y,
                    j:getCollideConnected(),
                    function(val)
                        uiState.currentlySelectedJoint = lib.recreateJoint(j, { collideConnected = val })
                        j = uiState.currentlySelectedJoint
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
                -- Ensure offsets exist

                if not getJointMetaSetting(j, 'offsetA') then
                    setJointMetaSetting(j, 'offsetA', { x = 0, y = 0 })
                end
                local offsetA = getJointMetaSetting(j, 'offsetA') or 0

                nextRow()
                if (offsetHasChangedViaOutside) then offsetHasChangedViaOutside = false end

                local bodyA, bodyB = j:getBodies()
                local ud = bodyA:getUserData()

                function updateOffset(x, y)
                    --local rx, ry = rotatePoint(x, y, 0, 0, bodyA:getAngle())

                    offsetA.x = x
                    offsetA.y = y
                    setJointMetaSetting(j, 'offsetA', { x = offsetA.x, y = offsetA.y })
                    uiState.currentlySelectedJoint = lib.recreateJoint(j)
                    j = uiState.currentlySelectedJoint

                    if false then
                        -- keep this around because it will make offsetA unneeded.
                        local ax1, ay1, b1x2, b1y2 = j:getAnchors()
                        local fx, fy = rotatePoint(ax1 - bodyA:getX(), ay1 - bodyA:getY(), 0, 0, -bodyA:getAngle())
                        print('GREAT', fx, fy, x, y)
                    end
                    offsetHasChangedViaOutside = true
                end

                if ud and ud.thing then
                    --print(inspect(ud.thing))
                    if ui.button(x, y, 30, '0', 30) then
                        updateOffset(0, -ud.thing.height / 2)
                    end
                    if ui.button(x + 30, y, 30, '1', 30) then
                        updateOffset(ud.thing.width / 2, -ud.thing.height / 2)
                    end
                    if ui.button(x + 60, y, 30, '2', 30) then
                        updateOffset(ud.thing.width / 2, 0)
                    end
                    if ui.button(x + 90, y, 30, '3', 30) then
                        updateOffset(ud.thing.width / 2, ud.thing.height / 2)
                    end
                    if ui.button(x + 120, y, 30, '4', 30) then
                        updateOffset(0, ud.thing.height / 2)
                    end
                    if ui.button(x + 150, y, 30, '5', 30) then
                        updateOffset(-ud.thing.width / 2, ud.thing.height / 2)
                    end
                    if ui.button(x + 180, y, 30, '6', 30) then
                        updateOffset(-ud.thing.width / 2, 0)
                    end
                    if ui.button(x + 210, y, 30, '7', 30) then
                        updateOffset(-ud.thing.width / 2, -ud.thing.height / 2)
                    end
                    if ui.button(x + 240, y, 30, '8', 30) then
                        updateOffset(0, 0)
                    end
                end
                nextRow()

                -- Sliders for offsetA.x
                local offsetX = createSliderWithId(jointId, 'Offset A X', x, y, 160, -200, 200,
                    offsetA.x,
                    function(val)
                        offsetA.x = val

                        setJointMetaSetting(j, 'offsetA', { x = offsetA.x, y = offsetA.y })
                        uiState.currentlySelectedJoint = lib.recreateJoint(j)
                        j = uiState.currentlySelectedJoint
                    end,
                    offsetHasChangedViaOutside

                )
                nextRow()
                -- Move to the next row for offsetA.y
                local offsetY = createSliderWithId(jointId, 'Offset A Y', x, y, 160, -200, 200,
                    offsetA.y,

                    function(val)
                        offsetA.y = val

                        setJointMetaSetting(j, 'offsetA', { x = offsetA.x, y = offsetA.y })
                        uiState.currentlySelectedJoint = lib.recreateJoint(j)
                        j = uiState.currentlySelectedJoint
                    end,
                    offsetHasChangedViaOutside

                )
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
            id = getJointId(joint),
            jointType = jointType,
            otherBody = otherBody,
            collideConnected = joint:getCollideConnected(),
            originalBodyOrder = isBodyA and "bodyA" or "bodyB",
        }

        -- Extract settings based on joint type
        if jointType == 'distance' then
            data.length = joint:getLength()
            data.frequency = joint:getFrequency()
            data.dampingRatio = joint:getDampingRatio()
        elseif jointType == 'weld' then
            data.frequency = joint:getFrequency()
            data.dampingRatio = joint:getDampingRatio()
        elseif jointType == 'rope' then
            data.maxLength = joint:getMaxLength()
        elseif jointType == 'revolute' then
            data.motorEnabled = joint:isMotorEnabled()
            if data.motorEnabled then
                data.motorSpeed = joint:getMotorSpeed()
                data.maxMotorTorque = joint:getMaxMotorTorque()
            end
            data.limitsEnabled = joint:areLimitsEnabled()
            if data.limitsEnabled then
                data.lowerLimit = joint:getLowerLimit()
                data.upperLimit = joint:getUpperLimit()
            end
        elseif jointType == 'wheel' then
            data.springFrequency = joint:getSpringFrequency()
            data.springDampingRatio = joint:getSpringDampingRatio()
        elseif jointType == 'motor' then
            data.correctionFactor = joint:getCorrectionFactor()
            data.angularOffset = joint:getAngularOffset()
            data.linearOffsetX, data.linearOffsetY = joint:getLinearOffset()
            data.maxForce = joint:getMaxForce()
            data.maxTorque = joint:getMaxTorque()
        elseif jointType == 'prismatic' then
            data.motorEnabled = joint:isMotorEnabled()
            if data.motorEnabled then
                data.motorSpeed = joint:getMotorSpeed()
                data.maxMotorForce = joint:getMaxMotorForce()
            end
            data.limitsEnabled = joint:areLimitsEnabled()
            if data.limitsEnabled then
                data.lowerLimit = joint:getLowerLimit()
                data.upperLimit = joint:getUpperLimit()
            end
        elseif jointType == 'pulley' then
            data.groundAnchor1, data.groundAnchor2 = joint:getGroundAnchors()
            data.ratio = joint:getRatio()
        elseif jointType == 'friction' then
            data.maxForce = joint:getMaxForce()
            data.maxTorque = joint:getMaxTorque()
        else
            print("Unsupported joint type: " .. jointType)
        end

        table.insert(jointData, data)
    end

    return jointData
end

return lib

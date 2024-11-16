local ui = require 'src.ui-all'
local lib = {}
local inspect = require 'vendor.inspect'


-- Helper function to create a slider with an associated label
local function createSlider(labelText, x, y, width, min, max, value, callback)
    local newValue = ui.sliderWithInput(labelText, x, y, width, min, max, value)
    if newValue then
        callback(newValue)
    end
    ui.label(x, y, labelText)
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


function lib.createJoint(data)
    local bodyA = data.body1
    local bodyB = data.body2
    local jointType = data.jointType

    local joint
    local world = bodyA:getWorld() -- Assuming both bodies are in the same world

    if jointType == 'distance' then
        -- Create a Distance Joint
        local x1, y1 = bodyA:getPosition()
        local x2, y2 = bodyB:getPosition()
        local length = data.length or math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        joint = love.physics.newDistanceJoint(bodyA, bodyB, x1, y1, x2, y2, false)
        joint:setLength(length)
        if data.frequency then
            print('setting distance frequency ', data.frequency)
            joint:setFrequency(data.frequency)
        end
        if data.dampingRatio then
            print('setting distance damping ratio ', data.dampingRatio)
            joint:setDampingRatio(data.dampingRatio)
        end
    elseif jointType == 'revolute' then
        -- Create a Revolute Joint at the first body's position
        local x, y = bodyA:getPosition()
        joint = love.physics.newRevoluteJoint(bodyA, bodyB, x, y, false)

        -- Enable Limits if specified
        if data.limitsEnabled then
            joint:setLimits((data.lowerLimit or 0) * (math.pi / 180), (data.upperLimit or 0) * (math.pi / 180))
            joint:setLimitsEnabled(true)
        end

        -- Enable Motor if specified
        if data.motorEnabled then
            joint:setMotorEnabled(true)
            joint:setMotorSpeed(data.motorSpeed or 0)
            joint:setMaxMotorTorque(data.maxMotorTorque or 0)
        end
    elseif jointType == 'prismatic' then
        -- Create a Prismatic Joint
        local x, y = bodyA:getPosition()
        local axis = data.axis or { 1, 0 } -- Default axis (horizontal)
        joint = love.physics.newPrismaticJoint(bodyA, bodyB, x, y, axis[1], axis[2], false)

        -- Enable Limits if specified
        if data.limitsEnabled then
            joint:setLimits(data.lowerLimit or 0, data.upperLimit or 0)
            joint:setLimitsEnabled(true)
        end

        -- Enable Motor if specified
        if data.motorEnabled then
            joint:setMotorEnabled(true)
            joint:setMotorSpeed(data.motorSpeed or 0)
            joint:setMaxMotorForce(data.maxMotorForce or 0)
        end
    elseif jointType == 'weld' then
        -- Create a Weld Joint at the first body's position
        local x, y = bodyA:getPosition()
        joint = love.physics.newWeldJoint(bodyA, bodyB, x, y, false)

        -- Weld joints don't have frequency or damping ratio by default, but you can simulate similar behavior if needed.
    elseif jointType == 'motor' then
        -- Create a Motor Joint
        joint = love.physics.newMotorJoint(bodyA, bodyB, data.correctionFactor or 1)
        joint:setMotorEnabled(true)
        if data.maxForce then
            joint:setMaxForce(data.maxForce)
        end
        if data.maxTorque then
            joint:setMaxTorque(data.maxTorque)
        end
    elseif jointType == 'wheel' then
        -- Create a Wheel Joint
        local x, y = bodyA:getPosition()
        local axisX, axisY = 0, 1 -- Vertical axis by default; adjust as needed
        joint = love.physics.newWheelJoint(bodyA, bodyB, x, y, axisX, axisY, false)

        if data.frequency then
            joint:setSpringFrequency(data.frequency)
        end
        if data.dampingRatio then
            joint:setSpringDampingRatio(data.dampingRatio)
        end

        -- Enable Motor if specified
        if data.motorEnabled then
            joint:setMotorEnabled(true)
            joint:setMotorSpeed(data.motorSpeed or 0)
            joint:setMaxMotorTorque(data.maxMotorTorque or 0)
        end
    elseif jointType == 'rope' then
        -- Create a Rope Joint
        local x1, y1 = bodyA:getPosition()
        local x2, y2 = bodyB:getPosition()
        local maxLength = data.maxLength or math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        joint = love.physics.newRopeJoint(bodyA, bodyB, x1, y1, x2, y2, maxLength)
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
        joint = love.physics.newFrictionJoint(bodyA, bodyB, x, y, false)

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

    -- Optionally, set additional properties common to all joints here
    -- For example, you might want to set user data or collision filtering

    -- Store the joint
    -- worldState.joints = worldState.joints or {}
    -- table.insert(worldState.joints, joint)

    -- Clear joint creation mode
    -- uiState.jointCreationMode = nil
end

function lib.doJointCreateUI(uiState, _x, _y, w, h)
    ui.panel(_x, _y, w, h, '∞ ' .. uiState.jointCreationMode.jointType .. ' ∞', function()
        local layout = ui.createLayout({
            type = 'columns',
            spacing = 10,
            startX = _x + 10,
            startY = _y + 10
        })


        local width = 280
        local jointType = uiState.jointCreationMode.jointType
        local x, y = ui.nextLayoutPosition(layout, 160, 50)
        x, y = ui.nextLayoutPosition(layout, 160, 50)

        local nextRow = function()
            x, y = ui.nextLayoutPosition(layout, 160, 50)
        end

        -- Function to handle joint-specific UI
        local function handleJointUI()
            if jointType == 'distance' then
                -- Length
                local x1, y1 = uiState.jointCreationMode.body1:getPosition()
                local x2, y2 = uiState.jointCreationMode.body2:getPosition()
                local defaultLength = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
                local length = createSlider(' length', x, y, 160, 0.1, 500,
                    uiState.jointCreationMode.length or defaultLength,
                    function(val) uiState.jointCreationMode.length = val end
                )
                nextRow()

                local frequency = createSlider(' freq', x, y, 160, 0, 20,
                    uiState.jointCreationMode.frequency or 0,
                    function(val) uiState.jointCreationMode.frequency = val end
                )
                nextRow()

                local dampingRatio = createSlider(' damp', x, y, 160, 0, 1,
                    uiState.jointCreationMode.dampingRatio or 0,
                    function(val) uiState.jointCreationMode.dampingRatio = val end
                )
                nextRow()
            elseif jointType == 'revolute' then
                -- Enable Limitl
                nextRow()

                local limitsEnabled = createCheckbox(' limits', x, y,
                    uiState.jointCreationMode.limitsEnabled or false,
                    function(val) uiState.jointCreationMode.limitsEnabled = val end
                )

                nextRow()

                if uiState.jointCreationMode.limitsEnabled then
                    local lowerLimit = createSlider(' lower', x, y, 160, -180, 180,
                        uiState.jointCreationMode.lowerLimit or 0,
                        function(val) uiState.jointCreationMode.lowerLimit = val end
                    )
                    nextRow()

                    local upperLimit = createSlider(' upper', x, y, 160, -180, 180,
                        uiState.jointCreationMode.upperLimit or 0,
                        function(val) uiState.jointCreationMode.upperLimit = val end
                    )
                    nextRow()
                end

                -- Enable Motor
                local motorEnabled = createCheckbox(' motor', x, y,
                    uiState.jointCreationMode.motorEnabled or false,
                    function(val) uiState.jointCreationMode.motorEnabled = val end
                )
                nextRow()

                if uiState.jointCreationMode.motorEnabled then
                    -- Motor Speed
                    local motorSpeed = createSlider(' speed', x, y, 160, -100, 100,
                        uiState.jointCreationMode.motorSpeed or 0,
                        function(val) uiState.jointCreationMode.motorSpeed = val end
                    )
                    nextRow()

                    -- Max Motor Torque
                    local maxMotorTorque = createSlider(' max T', x, y, 160, 0, 10000,
                        uiState.jointCreationMode.maxMotorTorque or 0,
                        function(val) uiState.jointCreationMode.maxMotorTorque = val end
                    )
                    nextRow()
                end
            elseif jointType == 'prismatic' then
                print('PRISMATIC ISNT WORKING YET!!!')
                -- Axis (Display Only)
                --local ax, ay = uiState.jointCreationMode.axis or { 1, 0 } -- Default axis
                --ui.label(x, y, string.format("Axis: (%.2f, %.2f)", ax, ay))
                nextRow()

                local limitsEnabled = createCheckbox(' limits', x, y,
                    uiState.jointCreationMode.limitsEnabled or false,
                    function(val) uiState.jointCreationMode.limitsEnabled = val end
                )
                nextRow()

                if uiState.jointCreationMode.limitsEnabled then
                    -- Lower Limit
                    local lowerLimit = createSlider(' lower', x, y, 160, -100, 100,
                        uiState.jointCreationMode.lowerLimit or 0,
                        function(val) uiState.jointCreationMode.lowerLimit = val end
                    )
                    nextRow()

                    local upperLimit = createSlider(' upper', x, y, 160, -100, 100,
                        uiState.jointCreationMode.upperLimit or 0,
                        function(val) uiState.jointCreationMode.upperLimit = val end
                    )
                    nextRow()
                end

                -- Enable Motor
                local motorEnabled = createCheckbox(' motor', x, y,
                    uiState.jointCreationMode.motorEnabled or false,
                    function(val) uiState.jointCreationMode.motorEnabled = val end
                )
                nextRow()

                if uiState.jointCreationMode.motorEnabled then
                    -- Motor Speed
                    local motorSpeed = createSlider(' speed', x, y, 160, -100, 100,
                        uiState.jointCreationMode.motorSpeed or 0,
                        function(val) uiState.jointCreationMode.motorSpeed = val end
                    )
                    nextRow()


                    local maxMotorForce = createSlider('max f', x, y, 160, 0, 10000,
                        uiState.jointCreationMode.maxMotorForce or 0,
                        function(val) uiState.jointCreationMode.maxMotorForce = val end
                    )
                    nextRow()
                end
            elseif jointType == 'wheel' then
                -- Frequency
                local frequency = createSlider(' freq', x, y, 160, 0, 20,
                    uiState.jointCreationMode.frequency or 0,
                    function(val) uiState.jointCreationMode.frequency = val end
                )
                nextRow()

                local dampingRatio = createSlider(' damp', x, y, 160, 0, 1,
                    uiState.jointCreationMode.dampingRatio or 0,
                    function(val) uiState.jointCreationMode.dampingRatio = val end
                )
                nextRow()

                local motorEnabled = createCheckbox(' motor', x, y,
                    uiState.jointCreationMode.motorEnabled or false,
                    function(val) uiState.jointCreationMode.motorEnabled = val end
                )
                nextRow()

                if uiState.jointCreationMode.motorEnabled then
                    -- Motor Speed
                    local motorSpeed = createSlider(' speed', x, y, 160, -100, 100,
                        uiState.jointCreationMode.motorSpeed or 0,
                        function(val) uiState.jointCreationMode.motorSpeed = val end
                    )
                    nextRow()

                    local maxMotorTorque = createSlider(' max t', x, y, 160, 0, 10000,
                        uiState.jointCreationMode.maxMotorTorque or 0,
                        function(val) uiState.jointCreationMode.maxMotorTorque = val end
                    )
                    nextRow()
                end
            elseif jointType == 'pulley' then
                -- Ratio
                local ratio = createSlider('Ratio', x, y, 160, 0.1, 10,
                    uiState.jointCreationMode.ratio or 1,
                    function(val) uiState.jointCreationMode.ratio = val end
                )
                nextRow()

                -- Ground Anchors (Display Only)
                local gx1, gy1, gx2, gy2 = uiState.jointCreationMode.groundAnchor1 or 0, 0, 0, 0
                --print(inspect(uiState.jointCreationMode.groundAnchor1))
                ui.label(x, y, string.format("Ground Anchors: (%.1f, %.1f), (%.1f, %.1f)", gx1, gy1, gx2, gy2))

                nextRow()
            elseif jointType == 'rope' then
                -- Max Length
                local x1, y1 = uiState.jointCreationMode.body1:getPosition()
                local x2, y2 = uiState.jointCreationMode.body2:getPosition()
                local defaultLength = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
                local maxLength = createSlider('Max Len', x, y, 160, 0.1, 500,
                    uiState.jointCreationMode.maxLength or defaultLength,
                    function(val) uiState.jointCreationMode.maxLength = val end
                )
                nextRow()
            elseif jointType == 'weld' then
                -- Frequency
                local frequency = createSlider('Freq', x, y, 160, 0, 20,
                    uiState.jointCreationMode.frequency or 0,
                    function(val) uiState.jointCreationMode.frequency = val end
                )
                nextRow()

                -- Damping Ratio
                local dampingRatio = createSlider('Damp', x, y, 160, 0, 1,
                    uiState.jointCreationMode.dampingRatio or 0,
                    function(val) uiState.jointCreationMode.dampingRatio = val end
                )
                nextRow()
            elseif jointType == 'motor' then
                -- Max Force
                local maxForce = createSlider('Max F', x, y, 160, 0, 10000,
                    uiState.jointCreationMode.maxForce or 1000,
                    function(val) uiState.jointCreationMode.maxForce = val end
                )
                nextRow()

                -- Max Torque
                local maxTorque = createSlider('Max T', x, y, 160, 0, 10000,
                    uiState.jointCreationMode.maxTorque or 1000,
                    function(val) uiState.jointCreationMode.maxTorque = val end
                )
                nextRow()

                local correctionFactor = createSlider('Corr Fac', x, y, 160, 0, 1,
                    uiState.jointCreationMode.correctionFactor or 1,
                    function(val) uiState.jointCreationMode.correctionFactor = val end
                )
                nextRow()
            elseif jointType == 'friction' then
                -- Max Force
                local maxForce = createSlider('Max F', x, y, 160, 0, 1000,
                    uiState.jointCreationMode.maxForce or 10,
                    function(val) uiState.jointCreationMode.maxForce = val end
                )
                nextRow()

                local maxTorque = createSlider('Max T', x, y, 160, 0, 1000,
                    uiState.jointCreationMode.maxTorque or 10,
                    function(val) uiState.jointCreationMode.maxTorque = val end
                )
                nextRow()
            end
        end

        handleJointUI()

        -- "Create Joint" and "Cancel" Buttons
        --x, y = ui.nextLayoutPosition(layout, 160, 50)
        nextRow()


        if ui.button(x, y, width, 'Create') then
            lib.createJoint(uiState.jointCreationMode)
            uiState.jointCreationMode = nil
        end
        nextRow()
        if ui.button(x, y, width, 'Cancel') then
            uiState.jointCreationMode = nil
        end
    end)
end

function lib.doJointUpdateUI(uiState, j, _x, _y, w, h)
    ui.panel(_x, _y, w, h, '∞ ' .. j:getType() .. ' ∞', function() end)
end

return lib


-- function createJointOLD(data)
--     local bodyA = data.body1
--     local bodyB = data.body2
--     local jointType = data.jointType

--     local joint
--     if jointType == 'distance' then
--         -- Create a Distance Joint
--         local x1, y1 = bodyA:getPosition()
--         local x2, y2 = bodyB:getPosition()
--         local length = data.length or ((x2 - x1) ^ 2 + (y2 - y1) ^ 2) ^ 0.5
--         joint = love.physics.newDistanceJoint(bodyA, bodyB, x1, y1, x2, y2, false)
--         joint:setLength(length)
--     elseif jointType == 'revolute' then
--         -- Create a Revolute Joint at the first body's position
--         local x, y = bodyA:getPosition()
--         joint = love.physics.newRevoluteJoint(bodyA, bodyB, x, y, false)
--     elseif jointType == 'weld' then
--         -- Create a Weld Joint at the first body's position
--         local x, y = bodyA:getPosition()
--         joint = love.physics.newWeldJoint(bodyA, bodyB, x, y, false)
--     elseif jointType == 'motor' then
--         -- Create a Motor Joint
--         local correctionFactor = data.correctionFactor or 1
--         joint = love.physics.newMotorJoint(bodyA, bodyB, correctionFactor, false)
--         if data.maxForce then
--             joint:setMaxForce(data.maxForce)
--         end
--         if data.maxTorque then
--             joint:setMaxTorque(data.maxTorque)
--         end
--     elseif jointType == 'wheel' then
--         -- Create a Wheel Joint
--         local x, y = bodyA:getPosition()
--         local axisX, axisY = 0, 1 -- Vertical axis
--         joint = love.physics.newWheelJoint(bodyA, bodyB, x, y, axisX, axisY, false)
--         if data.frequency then
--             joint:setSpringFrequency(data.frequency)
--         end
--         if data.dampingRatio then
--             joint:setSpringDampingRatio(data.dampingRatio)
--         end
--     elseif jointType == 'rope' then
--         -- Create a Rope Joint
--         local x1, y1 = bodyA:getPosition()
--         local x2, y2 = bodyB:getPosition()
--         local maxLength = data.maxLength or ((x2 - x1) ^ 2 + (y2 - y1) ^ 2) ^ 0.5
--         joint = love.physics.newRopeJoint(bodyA, bodyB, x1, y1, x2, y2, maxLength, false)
--     elseif jointType == 'pulley' then
--         -- Create a Pulley Joint
--         local x1, y1 = bodyA:getWorldCenter()
--         local x2, y2 = bodyB:getWorldCenter()
--         local gx1, gy1 = x1, y1 - 100
--         local gx2, gy2 = x2, y2 - 100
--         local ratio = data.ratio or 1
--         joint = love.physics.newPulleyJoint(bodyA, bodyB, gx1, gy1, gx2, gy2, x1, y1, x2, y2, ratio, false)
--     elseif jointType == 'friction' then
--         -- Create a Friction Joint
--         local x, y = bodyA:getPosition()
--         joint = love.physics.newFrictionJoint(bodyA, bodyB, x, y, false)
--         if data.maxForce then
--             joint:setMaxForce(data.maxForce)
--         end
--         if data.maxTorque then
--             joint:setMaxTorque(data.maxTorque)
--         end
--     else
--         -- Handle other joints or unimplemented types
--         print("Joint type '" .. jointType .. "' is not implemented yet.")
--         uiState.jointCreationMode = nil
--         return
--     end

--     -- Store the joint
--     worldState.joints = worldState.joints or {}
--     table.insert(worldState.joints, joint)

--     -- Clear joint creation mode
--     uiState.jointCreationMode = nil
-- end

-- function createJoint(data)
--     local bodyA = data.body1
--     local bodyB = data.body2
--     local jointType = data.jointType

--     local joint
--     local world = bodyA:getWorld() -- Assuming both bodies are in the same world

--     if jointType == 'distance' then
--         -- Create a Distance Joint
--         local x1, y1 = bodyA:getPosition()
--         local x2, y2 = bodyB:getPosition()
--         local length = data.length or math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
--         joint = love.physics.newDistanceJoint(bodyA, bodyB, x1, y1, x2, y2, false)
--         joint:setLength(length)
--         if data.frequency then
--             joint:setFrequency(data.frequency)
--         end
--         if data.dampingRatio then
--             joint:setDampingRatio(data.dampingRatio)
--         end
--     elseif jointType == 'revolute' then
--         -- Create a Revolute Joint at the first body's position
--         local x, y = bodyA:getPosition()
--         joint = love.physics.newRevoluteJoint(bodyA, bodyB, x, y, false)

--         -- Enable Limits if specified
--         if data.limitsEnabled then
--             joint:setLimits(data.lowerLimit or 0, data.upperLimit or 0)
--             joint:setLimitsEnabled(true)
--         end

--         -- Enable Motor if specified
--         if data.motorEnabled then
--             joint:setMotorEnabled(true)
--             joint:setMotorSpeed(data.motorSpeed or 0)
--             joint:setMaxMotorTorque(data.maxMotorTorque or 0)
--         end
--     elseif jointType == 'prismatic' then
--         -- Create a Prismatic Joint
--         local x, y = bodyA:getPosition()
--         local axis = data.axis or { 1, 0 } -- Default axis (horizontal)
--         joint = love.physics.newPrismaticJoint(bodyA, bodyB, x, y, axis[1], axis[2], false)

--         -- Enable Limits if specified
--         if data.limitsEnabled then
--             joint:setLimits(data.lowerLimit or 0, data.upperLimit or 0)
--             joint:setLimitsEnabled(true)
--         end

--         -- Enable Motor if specified
--         if data.motorEnabled then
--             joint:setMotorEnabled(true)
--             joint:setMotorSpeed(data.motorSpeed or 0)
--             joint:setMaxMotorForce(data.maxMotorForce or 0)
--         end
--     elseif jointType == 'weld' then
--         -- Create a Weld Joint at the first body's position
--         local x, y = bodyA:getPosition()
--         joint = love.physics.newWeldJoint(bodyA, bodyB, x, y, false)

--         -- Weld joints don't have frequency or damping ratio by default, but you can simulate similar behavior if needed.
--     elseif jointType == 'motor' then
--         -- Create a Motor Joint
--         joint = love.physics.newMotorJoint(bodyA, bodyB, data.correctionFactor or 1)
--         joint:setMotorEnabled(true)
--         if data.maxForce then
--             joint:setMaxForce(data.maxForce)
--         end
--         if data.maxTorque then
--             joint:setMaxTorque(data.maxTorque)
--         end
--     elseif jointType == 'wheel' then
--         -- Create a Wheel Joint
--         local x, y = bodyA:getPosition()
--         local axisX, axisY = 0, 1 -- Vertical axis by default; adjust as needed
--         joint = love.physics.newWheelJoint(bodyA, bodyB, x, y, axisX, axisY, false)

--         if data.frequency then
--             joint:setSpringFrequency(data.frequency)
--         end
--         if data.dampingRatio then
--             joint:setSpringDampingRatio(data.dampingRatio)
--         end

--         -- Enable Motor if specified
--         if data.motorEnabled then
--             joint:setMotorEnabled(true)
--             joint:setMotorSpeed(data.motorSpeed or 0)
--             joint:setMaxMotorTorque(data.maxMotorTorque or 0)
--         end
--     elseif jointType == 'rope' then
--         -- Create a Rope Joint
--         local x1, y1 = bodyA:getPosition()
--         local x2, y2 = bodyB:getPosition()
--         local maxLength = data.maxLength or math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
--         joint = love.physics.newRopeJoint(bodyA, bodyB, x1, y1, x2, y2, maxLength)
--     elseif jointType == 'pulley' then
--         -- Create a Pulley Joint
--         -- Ground anchors are typically fixed points; adjust as necessary
--         local x1, y1 = data.groundAnchor1 or { 0, 0 }, data.groundAnchor2 or { 0, 0 }
--         local groundAnchorA = data.groundAnchor1 or { 0, 0 }
--         local groundAnchorB = data.groundAnchor2 or { 0, 0 }
--         local bodyA_center = bodyA:getWorldCenter()
--         local bodyB_center = bodyB:getWorldCenter()
--         local ratio = data.ratio or 1

--         joint = love.physics.newPulleyJoint(
--             bodyA, bodyB,
--             groundAnchorA[1], groundAnchorA[2],
--             groundAnchorB[1], groundAnchorB[2],
--             bodyA_center.x, bodyA_center.y,
--             bodyB_center.x, bodyB_center.y,
--             ratio,
--             false
--         )
--     elseif jointType == 'friction' then
--         -- Create a Friction Joint
--         local x, y = bodyA:getPosition()
--         joint = love.physics.newFrictionJoint(bodyA, bodyB, x, y, false)

--         if data.maxForce then
--             joint:setMaxForce(data.maxForce)
--         end
--         if data.maxTorque then
--             joint:setMaxTorque(data.maxTorque)
--         end
--     else
--         -- Handle other joints or unimplemented types
--         print("Joint type '" .. jointType .. "' is not implemented yet.")
--         uiState.jointCreationMode = nil
--         return
--     end

--     -- Optionally, set additional properties common to all joints here
--     -- For example, you might want to set user data or collision filtering

--     -- Store the joint
--     worldState.joints = worldState.joints or {}
--     table.insert(worldState.joints, joint)

--     -- Clear joint creation mode
--     uiState.jointCreationMode = nil
-- end

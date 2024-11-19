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
        joint = love.physics.newDistanceJoint(bodyA, bodyB, x1, y1, x2, y2, data.collideConnected)
        joint:setLength(length)
    elseif jointType == 'weld' then
        -- Create a Weld Joint at the first body's position
        local x1, y1 = bodyA:getPosition()
        local x2, y2 = bodyB:getPosition()
        joint = love.physics.newWeldJoint(bodyA, bodyB, x1, y1, data.collideConnected)
        --joint = love.physics.newWeldJoint(bodyA, bodyB, x1, y1, x2, y2, data.collideConnected)
        -- Weld joints don't have frequency or damping ratio by default, but you can simulate similar behavior if needed.
    elseif jointType == 'rope' then
        -- Create a Rope Joint
        local x1, y1 = bodyA:getPosition()
        local x2, y2 = bodyB:getPosition()
        local maxLength = data.maxLength or math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        joint = love.physics.newRopeJoint(bodyA, bodyB, x1, y1, x2, y2, maxLength, data.collideConnected)
    elseif jointType == 'revolute' then
        -- Create a Revolute Joint at the first body's position
        local x1, y1 = bodyA:getPosition()
        local x2, y2 = bodyB:getPosition()
        -- joint = love.physics.newRevoluteJoint(bodyA, bodyB, x1, y1, x2, y2, data.collideConnected)
        joint = love.physics.newRevoluteJoint(bodyA, bodyB, x1, y1, data.collideConnected)
    elseif jointType == 'wheel' then
        -- Create a Wheel Joint

        local x1, y1 = bodyA:getPosition()
        -- local axisX, axisY = data.axisX, data.axisY -- Vertical axis by default; adjust as needed
        joint = love.physics.newWheelJoint(bodyA, bodyB, x1, y1, data.axisX or 0, data.axisY or 1, data.collideConnected)
    elseif jointType == 'motor' then
        -- Create a Motor Joint
        joint = love.physics.newMotorJoint(bodyA, bodyB, data.correctionFactor or .3, data.collideConnected)
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
    return joint
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

        local function collideFunctionality()
            local collideEnabled = createCheckbox(' collide', x, y,
                uiState.jointCreationMode.collideConnected or false,
                function(val) uiState.jointCreationMode.collideConnected = (val) end
            )
        end
        -- Function to handle joint-specific UI
        local function handleJointUI()
            if jointType == 'distance' then
                collideFunctionality()
            elseif jointType == 'weld' then
                collideFunctionality()
            elseif jointType == 'rope' then
                collideFunctionality()
            elseif jointType == 'revolute' then
                collideFunctionality()
            elseif jointType == 'wheel' then
                collideFunctionality()

                local function normalizeAxis(x, y)
                    local magnitude = math.sqrt(x ^ 2 + y ^ 2)
                    if magnitude == 0 then
                        return 1, 0 -- Default to (1, 0) if the vector is zero
                    else
                        print('normalizing', x / magnitude, y / magnitude)
                        return x / magnitude, y / magnitude
                    end
                end
                nextRow()
                local axisX = createSlider(' axisX', x, y, 160, -1, 1,
                    uiState.jointCreationMode.axisX or 0,
                    function(val)
                        uiState.jointCreationMode.axisX = val
                        uiState.jointCreationMode.axisX, uiState.jointCreationMode.axisY =
                            normalizeAxis(uiState.jointCreationMode.axisX or 0, uiState.jointCreationMode.axisY or 1)
                    end
                )
                nextRow()
                local axisY = createSlider(' axisY', x, y, 160, -1, 1,
                    uiState.jointCreationMode.axisY or 1,
                    function(val)
                        uiState.jointCreationMode.axisY = val
                        uiState.jointCreationMode.axisX, uiState.jointCreationMode.axisY =
                            normalizeAxis(uiState.jointCreationMode.axisX or 0, uiState.jointCreationMode.axisY or 1)
                    end
                )
            elseif jointType == 'motor' then
                collideFunctionality()
            elseif jointType == 'prismatic' then
                print('PRISMATIC ISNT WORKING YET!!!')

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
            elseif jointType == 'pulley' then
                -- Ratio
                local ratio = createSlider('Ratio', x, y, 160, 0.1, 10,
                    uiState.jointCreationMode.ratio or 1,
                    function(val) uiState.jointCreationMode.ratio = val end
                )
                nextRow()

                -- Ground Anchors (Display Only)
                local gx1, gy1, gx2, gy2 = uiState.jointCreationMode.groundAnchor1 or 0, 0, 0, 0

                ui.label(x, y, string.format("Ground Anchors: (%.1f, %.1f), (%.1f, %.1f)", gx1, gy1, gx2, gy2))

                nextRow()
            elseif jointType == 'motorOLD' then
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
            local j = lib.createJoint(uiState.jointCreationMode)
            uiState.currentlySelectedJoint = j
            uiState.currentlySelectedObject = nil
            uiState.jointCreationMode = nil
        end
        nextRow()
        if ui.button(x, y, width, 'Cancel') then
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
            local x, y = ui.nextLayoutPosition(layout, 160, 50)
            x, y = ui.nextLayoutPosition(layout, 160, 50)
            local width = 280
            local nextRow = function()
                x, y = ui.nextLayoutPosition(layout, 160, 50)
            end

            if ui.button(x, y, width, 'destroy') then
                j:destroy()
                return;
            end

            local function motorFunctionality(j)
                local motorEnabled = createCheckbox(' motor', x, y,
                    j:isMotorEnabled(),
                    function(val)
                        j:setMotorEnabled(val)
                    end
                )
                nextRow()
                if j:isMotorEnabled() then
                    local motorSpeed = createSlider(' speed', x, y, 160, -1000, 1000,
                        j:getMotorSpeed(),
                        function(val) j:setMotorSpeed(val) end
                    )
                    nextRow()
                    local maxMotorTorque = createSlider(' max T', x, y, 160, 0, 100000,
                        j:getMaxMotorTorque(),
                        function(val) j:setMaxMotorTorque(val) end
                    )
                    nextRow()
                end
            end

            local function collideFunctionality(j)
                local collideEnabled = createCheckbox(' collide', x, y,
                    j:getCollideConnected(),
                    function(val) end
                )
            end

            local function limitsFunctionality(j)
                local limitsEnabled = createCheckbox(' limits', x, y,
                    j:areLimitsEnabled(),
                    function(val)
                        j:setLimitsEnabled(val)
                    end
                )

                if (j:areLimitsEnabled()) then
                    nextRow()
                    local up = math.deg(j:getUpperLimit())
                    local lowerLimit = createSlider(' lower', x, y, 160, -180, up,
                        math.deg(j:getLowerLimit()),
                        function(val)
                            local newValue = math.rad(val)
                            j:setLowerLimit(newValue)
                        end
                    )
                    nextRow()
                    local low = math.deg(j:getLowerLimit())
                    local upperLimit = createSlider(' upper', x, y, 160, low, 180,
                        math.deg(j:getUpperLimit()),
                        function(val)
                            local newValue = math.rad(val)
                            j:setUpperLimit(newValue)
                        end
                    )
                end
            end

            if jointType == 'distance' then
                nextRow()
                collideFunctionality(j)
                nextRow()
                -- local bodyA, bodyB = j:getBodies()
                local x1, y1 = bodyA:getPosition()
                local x2, y2 = bodyB:getPosition()
                local myLength = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
                local length = createSlider(' length', x, y, 160, 0.1, 500,
                    uiState.jointUpdateMode.length or myLength,
                    function(val)
                        j:setLength(val)
                        uiState.jointUpdateMode.length = val
                    end
                )
                nextRow()

                local frequency = createSlider(' freq', x, y, 160, 0, 20,
                    j:getFrequency(),
                    function(val) j:setFrequency(val) end
                )
                nextRow()
                local damping = createSlider(' damp', x, y, 160, 0, 20,
                    j:getDampingRatio(),
                    function(val) j:setDampingRatio(val) end
                )
                nextRow()
                nextRow()
            elseif jointType == 'weld' then
                nextRow()
                collideFunctionality(j)
                nextRow()
                local frequency = createSlider(' freq', x, y, 160, 0, 20,
                    j:getFrequency(),
                    function(val) j:setFrequency(val) end
                )
                nextRow()
                local damping = createSlider(' damp', x, y, 160, 0, 20,
                    j:getDampingRatio(),
                    function(val) j:getDampingRatio(val) end
                )
                nextRow()
            elseif jointType == 'rope' then
                nextRow()
                collideFunctionality(j)
                nextRow()
                -- local bodyA, bodyB = j:getBodies()
                local x1, y1 = bodyA:getPosition()
                local x2, y2 = bodyB:getPosition()
                local myLength = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
                local length = createSlider(' length', x, y, 160, 0.1, 500,
                    uiState.jointUpdateMode.maxLength or myLength,
                    function(val)
                        j:setMaxLength(val)
                        uiState.jointUpdateMode.maxLength = val
                    end
                )
                nextRow()
            elseif jointType == 'revolute' then
                nextRow()
                collideFunctionality(j)
                nextRow()
                limitsFunctionality(j)
                nextRow()
                motorFunctionality(j)
            elseif jointType == 'wheel' then
                nextRow()
                collideFunctionality(j)
                nextRow()

                local springFrequency = createSlider(' spring F', x, y, 160, 0, 100,
                    j:getSpringFrequency(),
                    function(val) j:setSpringFrequency(val) end
                )
                nextRow()
                local springDamping = createSlider(' spring D', x, y, 160, 0, 1,
                    j:getSpringDampingRatio(),
                    function(val) j:setSpringDampingRatio(val) end
                )
                nextRow()
                motorFunctionality(j)
            elseif jointType == 'motor' then
                nextRow()
                collideFunctionality(j)
                nextRow()
                local angularOffset = createSlider(' angular o', x, y, 160, -180, 180,
                    math.deg(j:getAngularOffset()),
                    function(val) j:setAngularOffset(math.rad(val)) end
                )
                nextRow()
                local correctionF = createSlider(' corr.', x, y, 160, 0, 1,
                    j:getCorrectionFactor(),
                    function(val) j:setCorrectionFactor(val) end
                )

                local lx, ly = j:getLinearOffset()
                local lxOff = createSlider(' lx', x, y, 160, -1000, 1000,
                    lx,
                    function(val) j:setLinearOffset(val, ly) end
                )
                nextRow()
                local lyOff = createSlider(' ly', x, y, 160, -1000, 1000,
                    ly,
                    function(val) j:setLinearOffset(lx, val) end
                )
                nextRow()
                local maxForce = createSlider(' force', x, y, 160, 0, 100000,
                    j:getMaxForce(),
                    function(val) j:setMaxForce(val) end
                )
                nextRow()
                local maxTorque = createSlider(' torque', x, y, 160, 0, 100000,
                    j:getMaxTorque(),
                    function(val) j:setMaxTorque(val) end
                )
                nextRow()
            end
        end)
    end
end

return lib

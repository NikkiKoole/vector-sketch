local s            = {}

local desiredAngle = 0
local divider      = 32
local smarter      = 1

local Kp           = 50 -- Proportional gain
local Kd           = 10 -- Derivative gain


function rotateToHorizontalPD(body, desiredAngle, Kp, Kd, dt)
    -- Normalize angle to range [-pi, pi]
    local function normalizeAngle(angle)
        angle = math.fmod(angle + math.pi, 2 * math.pi)
        if angle < 0 then
            angle = angle + (2 * math.pi)
        end
        return angle - math.pi
    end

    -- Get current state
    local currentAngle = body:getAngle()
    local angularVelocity = body:getAngularVelocity()
    local inertia = body:getInertia()

    -- Calculate angle error
    local angleError = normalizeAngle(desiredAngle - currentAngle)

    -- PD Controller: Proportional term + Derivative term
    local proportional = Kp * angleError
    local derivative = Kd * angularVelocity
    local controlSignal = proportional - derivative

    -- Calculate torque: Torque = Inertia * Control Signal
    local torque = inertia * controlSignal

    -- Apply torque to the body
    body:applyTorque(torque)
end

function rotateToHorizontalAdjusted(body, desiredAngle, divider, smarter, dt)
    local function normalizeAngle(angle)
        angle = math.fmod(angle + math.pi, 2 * math.pi)
        if angle < 0 then
            angle = angle + (2 * math.pi)
        end
        return angle - math.pi
    end

    local currentAngle = body:getAngle()
    local angularVelocity = body:getAngularVelocity()
    local inertia = body:getInertia()

    -- Predict the next angle based on current angular velocity
    local predictedAngle = currentAngle + angularVelocity / divider
    local angleDifference = normalizeAngle(desiredAngle - predictedAngle)

    -- Calculate desired angular velocity
    local desiredAngularVelocity = angleDifference * divider
    if smarter then
        local maxAngularVelocity = (1 / dt) * smarter
        desiredAngularVelocity = angleDifference * math.min(divider, maxAngularVelocity)
    end

    -- Torque calculation matching the original formula
    local torque = inertia * desiredAngularVelocity * divider

    if smarter then
        local maxTorqueDivider = math.min(divider, (1 / dt) * smarter)
        torque = inertia * desiredAngularVelocity * maxTorqueDivider
    end

    body:applyTorque(torque)
end

function s.onStart()
    keepStraights = {}
    keepStraights = getObjectsByLabel('straight')
end

function s.update(dt)
    for i = 1, #keepStraights do
        --print(keepStraights[i].body:getMass())
        --  local m = keepStraights[i].body:getMass()
        rotateToHorizontalPD(keepStraights[i].body, desiredAngle, Kp, Kd, dt)
        rotateToHorizontalAdjusted(keepStraights[i].body, desiredAngle, divider, smarter, dt)
    end
end

function s.drawUI()
    local w, h = love.graphics.getDimensions()
    local BUTTON_SPACING = 10
    local BUTTON_HEIGHT = 40
    local margin = 20
    local startX = margin
    local panelWidth = 350 --w - margin * 2

    local panelHeight = BUTTON_HEIGHT * 6
    local startY = h - panelHeight - margin


    ui.panel(startX, startY, panelWidth, panelHeight, '•• straights ••', function()
        local layout = ui.createLayout({
            type = 'columns',
            spacing = BUTTON_SPACING,
            startX = startX + BUTTON_SPACING,
            startY = startY + BUTTON_SPACING
        })
        local x, y = ui.nextLayoutPosition(layout, panelWidth - 20, BUTTON_HEIGHT)
        local x, y = ui.nextLayoutPosition(layout, panelWidth - 20, BUTTON_HEIGHT)

        local newAngle = ui.sliderWithInput(' drag', x, y, 200, -math.pi, math.pi, desiredAngle)
        if newAngle then
            desiredAngle = newAngle
        end
        ui.label(x, y, ' angle')

        local x, y = ui.nextLayoutPosition(layout, panelWidth - 20, BUTTON_HEIGHT)
        local newKp = ui.sliderWithInput(' kp', x, y, 200, 10, 100, Kp)
        if newKp then
            Kp = newKp
        end
        ui.label(x, y, ' Prop. Gain.')

        local x, y = ui.nextLayoutPosition(layout, panelWidth - 20, BUTTON_HEIGHT)
        local newKd = ui.sliderWithInput(' fdensity', x, y, 200, 1, 20, Kd)
        if newKd then
            Kd = newKd
        end
        ui.label(x, y, ' Der. Gain.')
    end)
end

return s
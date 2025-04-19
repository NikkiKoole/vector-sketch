local s = {}

-- --- User-Configurable Parameters ---
local globalDesiredAngle = 0 -- The ultimate angle we want all bodies to reach
local timeToReachAngle = 0.5 -- Approximate time (in seconds) to rotate towards the target. Smaller = faster.
------------------------------------

-- --- Internal Tuning (Less user-facing, find good defaults) ---
-- These control how "tightly" the body follows its *internal* smoothed target.
-- They might need less variation across object types now.
local stiffnessFactor = 1500        -- How strongly it corrects towards the internal target (related to Kp*I)
local dampingFactor = 5             -- How much it resists angular velocity (related to Kd*I)
local maxCorrectiveTorque = 1000000 -- Still need a safety cap per body
------------------------------------


-- Keep this utility function
local function normalizeAngle(angle)
    -- Normalize angle to the range [-pi, pi] for shortest path calculation
    angle = angle % (2 * math.pi)
    if angle > math.pi then
        angle = angle - 2 * math.pi
    elseif angle <= -math.pi then
        angle = angle + 2 * math.pi
    end
    return angle
end

-- Basic interpolation for angles (handles wrapping)
local function lerpAngle(a, b, t)
    local diff = normalizeAngle(b - a)
    return normalizeAngle(a + diff * t)
end


---
-- Applies torque to make the body track its *current* internal target angle.
-- This is a simplified stabilizer.
-- @param body The physics body object.
-- @param internalTargetAngle The immediate angle this body should aim for.
-- @param stiffness How strongly to pull towards the target.
-- @param damping How much to resist current velocity.
-- @param maxTorque Maximum allowed torque.
-- @param dt Time step.
--
function applyTrackingTorque(body, internalTargetAngle, stiffness, damping, maxTorque, dt)
    local currentAngle = body:getAngle()
    local angularVelocity = body:getAngularVelocity()
    local inertia = body:getInertia()

    if inertia <= 0 then return end

    -- Error relative to the *internal* target
    local angleError = normalizeAngle(internalTargetAngle - currentAngle)

    -- Simplified Scaled PD-like control (using factors instead of omega/zeta)
    -- Stiffness term (Proportional): Pulls towards target angle
    local proportionalTorque = inertia * stiffness * angleError

    -- Damping term (Derivative): Resists existing motion
    local derivativeTorque = inertia * damping * angularVelocity

    -- Total Torque
    local totalTorque = proportionalTorque - derivativeTorque

    -- Apply torque limits
    totalTorque = math.max(-maxTorque, math.min(maxTorque, totalTorque))

    body:applyTorque(totalTorque)
end

-- Store bodies with their individual state
-- Format: { { body = body1, internalAngle = angle1 }, { body = body2, internalAngle = angle2 }, ... }
local bodiesToStabilize = {}

function s.onStart()
    bodiesToStabilize = {}
    local foundObjects = getObjectsByLabel('straight') or {}
    print("Found " .. #foundObjects .. " bodies to stabilize.")
    for _, obj in ipairs(foundObjects) do
        if obj and obj.body then
            -- Initialize internal angle to the body's current angle
            table.insert(bodiesToStabilize, {
                body = obj.body,
                internalAngle = obj.body:getAngle() -- Start at current angle
            })
        end
    end
end

local sign = function(v)
    if v < 0 then return -1 else return 1 end
end

function s.update(dt)
    -- Determine the maximum angular speed based on timeToReachAngle
    -- Let's define it such that reaching halfway around the circle (pi radians)
    -- would take approximately timeToReachAngle. Adjust this definition if needed.
    local maxAngularSpeed = 0
    if timeToReachAngle > 0.01 then
        maxAngularSpeed = math.pi / timeToReachAngle -- Radians per second
    else
        maxAngularSpeed = math.huge                  -- Effectively infinite speed for near-zero time
    end

    -- Calculate the maximum angle change allowed in this frame
    local maxAngleChangeThisFrame = maxAngularSpeed * dt

    for i = 1, #bodiesToStabilize do
        local data = bodiesToStabilize[i]
        if data and data.body then
            -- Calculate the difference to the global target
            local angleDifference = normalizeAngle(globalDesiredAngle - data.internalAngle)

            -- Determine the actual change for this frame
            -- It's the smaller of the max allowed change and the remaining difference
            local actualAngleChange = math.min(maxAngleChangeThisFrame, math.abs(angleDifference))

            -- Apply the change in the correct direction
            if math.abs(angleDifference) > 0.001 then -- Avoid tiny adjustments if already very close
                data.internalAngle = normalizeAngle(data.internalAngle + actualAngleChange * sign(angleDifference))
            else
                -- Optional: Snap if very close? Or just let it be.
                data.internalAngle = globalDesiredAngle
            end

            -- Apply torque to make the body follow its (now updated) internal target angle
            applyTrackingTorque(data.body, data.internalAngle, stiffnessFactor, dampingFactor, maxCorrectiveTorque, dt)
        else
            -- Optional cleanup
            -- table.remove(bodiesToStabilize, i); i = i - 1
        end
    end
end

function s.updateOLD(dt)
    -- 1. Update the internal target angle for each body, moving it towards the global desired angle
    local smoothingFactor = 0
    if timeToReachAngle > 0.01 then -- Avoid division by zero or excessively fast smoothing
        -- Calculate how much to move this frame. Clamp prevents overshooting in one step.
        smoothingFactor = math.min(dt / timeToReachAngle, 1.0)
    else
        smoothingFactor = 1.0 -- If time is near zero, snap instantly
    end

    for i = 1, #bodiesToStabilize do
        local data = bodiesToStabilize[i]
        if data and data.body then
            -- Smoothly interpolate the internal angle towards the global target
            data.internalAngle = lerpAngle(data.internalAngle, globalDesiredAngle, smoothingFactor)

            -- 2. Apply torque to make the body follow its (now updated) internal target angle
            applyTrackingTorque(data.body, data.internalAngle, stiffnessFactor, dampingFactor, maxCorrectiveTorque, dt)
        else
            -- Optional cleanup if body becomes invalid
            -- table.remove(bodiesToStabilize, i); i = i - 1
        end
    end
end

function s.drawUI()
    if not ui then return end

    local w, h = love.graphics.getDimensions()
    local BUTTON_SPACING = 10
    local BUTTON_HEIGHT = 30
    local margin = 20
    local panelWidth = 350
    -- Reduced height: Angle, Time + (maybe hidden advanced later)
    local panelHeight = BUTTON_HEIGHT * 3 + BUTTON_SPACING * 4
    local startX = margin
    local startY = h - panelHeight - margin

    ui.panel(startX, startY, panelWidth, panelHeight, '•• Simple Stabilization ••', function()
        local layout = ui.createLayout({
            type = 'columns',
            spacing = BUTTON_SPACING,
            startX = startX + BUTTON_SPACING,
            startY = startY + BUTTON_SPACING + 15
        })

        -- Desired Angle Slider
        local x, y = ui.nextLayoutPosition(layout, panelWidth - 20, BUTTON_HEIGHT)
        local newAngle = ui.sliderWithInput('Target Angle', x, y, panelWidth * 0.6, -math.pi, math.pi,
            globalDesiredAngle)
        if newAngle then
            globalDesiredAngle = newAngle
        end
        local angleLabelValue = globalDesiredAngle or 0
        --ui.label(x + panelWidth * 0.6 + 5, y + BUTTON_HEIGHT / 4, string.format("%.2f rad", angleLabelValue))

        -- Time to Reach Angle Slider
        local x, y = ui.nextLayoutPosition(layout, panelWidth - 20, BUTTON_HEIGHT)
        -- Range: e.g., 0.1s (fast) to 5s (slow). Adjust as needed.
        local newTime = ui.sliderWithInput('Reach Time (s)', x, y, panelWidth * 0.6, 0.05, 5.0,
            timeToReachAngle)
        if newTime then
            -- Ensure time doesn't go too close to zero if slider allows it
            timeToReachAngle = math.max(newTime, 0.01)
        end
        local timeLabelValue = timeToReachAngle or 0.01
        --ui.label(x + panelWidth * 0.6 + 5, y + BUTTON_HEIGHT / 4, string.format("%.2f s", timeLabelValue))

        -- Optional: Add a button here later to reveal Stiffness/Damping/MaxTorque sliders if needed for advanced tuning
    end)
end

return s

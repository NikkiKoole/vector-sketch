local s = {}
local snapPoints = {}             -- List of all snap points
local snapDistance = 40           -- Maximum distance to snap
local joints = {}                 -- Store created joints
local jointBreakThreshold = 80000 -- Force threshold for breaking the joint
local cooldownTime = .5           -- Time in seconds to prevent immediate reconnection
local cooldownList = {}           -- Table to track cooldown for each snap point


--todo:

-- i want an option that can be turned on or off that enables a feature
-- to just break or connect snapPoints at my currently interacted with body
-- so snapJoints can only be broken when interacted on (pulled) or connected when interacted on (positioned properly)
--and not accidnetly in the distance



-- Add a snap point as a fixture to a body
local function rect(w, h, x, y)
    return {
        x - w / 2, y - h / 2,
        x + w / 2, y - h / 2,
        x + w / 2, y + h / 2,
        x - w / 2, y + h / 2
    }
end

function addSnapPoint(body, x, y)
    -- Create a tiny rectangle fixture to represent the snap point
    local shape = love.physics.newPolygonShape(rect(20, 20, x, y))
    local fixture = love.physics.newFixture(body, shape)
    fixture:setSensor(true) -- Sensor so it doesn't collide
    fixture:setUserData({ type = "snapPoint", xOffset = x, yOffset = y, connected = false })
    table.insert(snapPoints, fixture)
end

function s.onStart()
    snaps = getObjectsByLabel('havesnap')
    -- Create snap points on the body of each object
    for i = 1, #snaps do
        local it = snaps[i]
        addSnapPoint(it.body, it.width / 2, 0)
        addSnapPoint(it.body, -it.width / 2, 0)
    end
end

-- Check for nearby snap points and create a joint if two are close enough
function checkForSnapsOLD()
    for i, fixture1 in ipairs(snapPoints) do
        local data1 = fixture1:getUserData()
        local body1 = fixture1:getBody()

        local x1, y1 = body1:getWorldPoint(data1.xOffset, data1.yOffset)

        -- Skip this snap point if it's already connected to a body or in cooldown
        if data1.connected or isInCooldown(fixture1) then
            goto continue
        end

        for j, fixture2 in ipairs(snapPoints) do
            if i ~= j then
                local data2 = fixture2:getUserData()
                local body2 = fixture2:getBody()
                local x2, y2 = body2:getWorldPoint(data2.xOffset, data2.yOffset)

                local distance = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)

                -- Check if the snap points are close enough, neither is already connected, and neither is on cooldown
                if distance <= snapDistance and not data2.connected and not isInCooldown(fixture2) then
                    -- Snap and create a joint if not already connected
                    createRevoluteJoint(body1, body2, x1, y1, x2, y2)
                    -- Mark both snap points as connected
                    fixture1:getUserData().connected = true
                    fixture2:getUserData().connected = true
                    print('true', inspect(fixture1:getUserData()))
                    break -- Break after snapping, since this snap point can only connect to one
                end
            end
        end

        ::continue::
    end
end

function checkForSnaps()
    for i, fixture1 in ipairs(snapPoints) do
        local data1 = fixture1:getUserData()
        local body1 = fixture1:getBody()
        local x1, y1 = body1:getWorldPoint(data1.xOffset, data1.yOffset)

        if data1.connected or isInCooldown(fixture1) then
            goto continue
        end

        for j, fixture2 in ipairs(snapPoints) do
            if i ~= j then
                local data2 = fixture2:getUserData()
                local body2 = fixture2:getBody()
                local x2, y2 = body2:getWorldPoint(data2.xOffset, data2.yOffset)

                local distance = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)

                if distance <= snapDistance and not data2.connected and not isInCooldown(fixture2) then
                    if not validateSnapPair(body1, body2, fixture1, fixture2) then
                        goto continue_inner
                    end

                    createRevoluteJoint(body1, body2, x1, y1, x2, y2)
                    local d = fixture1:getUserData()
                    d.connected = true
                    fixture1:setUserData(d)
                    local d = fixture2:getUserData()
                    d.connected = true
                    fixture2:setUserData(d)
                    --print(string.format("Connected SnapPoints: Body1 (%d) <-> Body2 (%d)", i, j))
                    break
                end
            end

            ::continue_inner::
        end

        ::continue::
    end
end

-- Validate if two snap points should connect (extend as needed)
function validateSnapPair(body1, body2, fixture1, fixture2)
    -- Prevent snapping the same body to itself
    if body1 == body2 then
        return false
    end

    -- Add other validation logic here if needed
    return true
end

-- Create a revolute joint between two bodies
function createRevoluteJoint(body1, body2, x, y, x2, y2)
    -- Prevent duplicate joints
    for _, joint in ipairs(joints) do
        local bodyA, bodyB = joint:getBodies()
        if (bodyA == body1 and bodyB == body2) or
            (bodyA == body2 and bodyB == body1) then
            return
        end
    end

    local joint = love.physics.newRevoluteJoint(body1, body2, x, y, x2, y2)
    table.insert(joints, joint)
end

function checkForJointBreaks(dt)
    for i, joint in ipairs(joints) do
        -- Check if the force exceeds the threshold
        local xf, yf = joint:getReactionForce(1 / dt)
        --local torque = joint:getReactionTorque(1 / dt)
        --print(xf, yf, torque)
        -- print(math.max(xf, yf))
        if math.max(math.abs(xf), math.abs(yf)) > jointBreakThreshold then
            -- Break the joint
            -- Cleanup: Mark the snap points as disconnected
            local body1, body2 = joint:getBodies()
            --local b1found = false
            -- local b2found = false
            for _, fixture in ipairs(snapPoints) do
                if fixture:getBody() == body1 then
                    local data = fixture:getUserData()
                    data.connected = false
                    fixture:setUserData(data)
                    print(inspect(fixture:getUserData()))
                    addCooldown(fixture) -- Add cooldown after breaking the joint
                    --b1found = true
                elseif fixture:getBody() == body2 then
                    local data = fixture:getUserData()
                    data.connected = false
                    fixture:setUserData(data)
                    print(inspect(fixture:getUserData()))
                    addCooldown(fixture) -- Add cooldown after breaking the joint
                    --b2found = true
                end
            end
            --print(b1found and b2found)
            joint:destroy()
            -- Remove the joint from the list of joints
            table.remove(joints, i)
        end
    end
end

-- Add cooldown to a snap point
function addCooldown(fixture)
    local currentTime = love.timer.getTime()
    cooldownList[fixture] = currentTime + cooldownTime
end

-- Check if a snap point is in cooldown
function isInCooldown(fixture)
    local currentTime = love.timer.getTime()
    return cooldownList[fixture] and currentTime < cooldownList[fixture]
end

function s.update(dt)
    checkForSnaps()
    checkForJointBreaks(dt) -- Check for joint breaks every frame
    -- print(#joints)
end

return s

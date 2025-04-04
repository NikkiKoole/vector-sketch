local s = {}

local snapPoints = {}              -- List of all snap points
local snapDistance = 40            -- Maximum distance to snap
local mySnapJoints = {}            -- Store created joints
local jointBreakThreshold = 100000 -- Force threshold for breaking the joint
local cooldownTime = .5            -- Time in seconds to prevent immediate reconnection
local cooldownList = {}            -- Table to track cooldown for each snap point
local onlyConnectWhenInteracted = true
local onlyBreakWhenInteracted = true

local function rect(w, h, x, y)
    return {
        x - w / 2, y - h / 2,
        x + w / 2, y - h / 2,
        x + w / 2, y + h / 2,
        x - w / 2, y + h / 2
    }
end

local function oneOfThemIsInteractedWith(b1, b2, list)
    for i = 1, #list do
        if list[i] == b1 or list[i] == b2 then
            return true
        end
    end
    return false
end

function addSnapPoint(body, x, y)
    -- Create a tiny rectangle fixture to represent the snap point
    local shape = love.physics.newPolygonShape(rect(20, 20, x, y))
    local fixture = love.physics.newFixture(body, shape)
    fixture:setSensor(true) -- Sensor so it doesn't collide
    table.insert(snapPoints, { type = "snapPoint", fixture = fixture, xOffset = x, yOffset = y, at = body, to = nil })
end

function s.onSceneUnload()
    snaps = {}
    snapPoints = {}
end

function calculateDistance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

function s.onSceneLoaded()
    -- Retrieve all objects labeled with 'havesnap'
    snaps = getObjectsByLabel('havesnap')

    -- Create snap points on the body of each snap-capable object
    for i = 1, #snaps do
        local it = snaps[i]
        it.body:setBullet(true)
        -- Add a snap point to the right edge
        addSnapPoint(it.body, it.width / 2, 0)
        -- Add a snap point to the left edge
        addSnapPoint(it.body, -it.width / 2, 0)
    end

    -- Iterate through all existing joints in the registry
    for k, value in pairs(registry.joints) do
        local ud = value:getUserData()

        -- Check if the joint is a snap-type joint
        if ud and ud.scriptmeta and ud.scriptmeta.type and ud.scriptmeta.type == 'snap' then
            -- Get the two bodies connected by the joint
            local bodyA, bodyB = value:getBodies()
            -- Get the anchor points of the joint
            local x1, y1, x2, y2 = value:getAnchors()
            -- Retrieve unique IDs for both bodies
            local id1 = bodyA:getUserData().thing.id
            local id2 = bodyB:getUserData().thing.id
            -- Tables to store possible snap point indices for each body
            local indx1Options = {}
            local indx2Options = {}

            -- Find all snap points associated with bodyA and bodyB
            for i = 1, #snapPoints do
                local atId = snapPoints[i].at:getUserData().thing.id
                if (atId == id1) then
                    table.insert(indx1Options, i)
                end
                if (atId == id2) then
                    table.insert(indx2Options, i)
                end
            end

            -- Initialize variables to find the closest snap point for bodyA
            local indx1
            local indx1dist = math.huge

            -- Determine the closest snap point for bodyA to the joint's first anchor
            for i = 1, #indx1Options do
                local index = indx1Options[i]
                local wx, wy = snapPoints[index].at:getLocalPoint(x1, y1)
                local distance = calculateDistance(snapPoints[index].xOffset, snapPoints[index].yOffset, wx, wy)
                if distance < indx1dist then
                    indx1dist = distance
                    indx1 = index
                end
            end

            -- Initialize variables to find the closest snap point for bodyB
            local indx2
            local indx2dist = math.huge

            -- Determine the closest snap point for bodyB to the joint's second anchor
            for i = 1, #indx2Options do
                local index = indx2Options[i]
                local wx, wy = snapPoints[index].at:getLocalPoint(x2, y2)
                local distance = calculateDistance(snapPoints[index].xOffset, snapPoints[index].yOffset, wx, wy)
                if distance < indx2dist then
                    indx2dist = distance
                    indx2 = index
                end
            end

            -- Link the two closest snap points by setting their 'to' references
            snapPoints[indx1].to = snapPoints[indx2].at
            snapPoints[indx2].to = snapPoints[indx1].at

            -- Add the joint to the list of active snap joints
            table.insert(mySnapJoints, value)
        end
    end
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

function checkForSnaps(interacted)
    for i = 1, #snapPoints do
        local it1 = snapPoints[i]
        if it1.to == nil and not isInCooldown(it1.fixture) then -- else this snap point is already connected and it cannot be connected more then once
            local body1 = it1.at
            local x1, y1 = body1:getWorldPoint(it1.xOffset, it1.yOffset)

            for j = 1, #snapPoints do
                if j ~= i then                                              -- else you check it against it
                    local it2 = snapPoints[j]
                    if it2.to == nil and not isInCooldown(it2.fixture) then -- else it2 is already connected,
                        local body2 = it2.at
                        local x2, y2 = body2:getWorldPoint(it2.xOffset, it2.yOffset)

                        local distance = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)

                        if distance <= snapDistance then
                            if (not onlyConnectWhenInteracted or (oneOfThemIsInteractedWith(body1, body2, interacted))) then
                                if not areBodiesConnected(body1, body2) then -- else these bodies are already connected..
                                    createRevoluteJoint(body1, body2, x1, y1, x2, y2, i, j)
                                    it1.to = body2
                                    it2.to = body1
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function areBodiesConnected(body1, body2)
    for i = 1, #snapPoints do
        local it = snapPoints[i]
        if (it.to == body1 and it.at == body2) or (it.to == body2 and it.at == body1) then
            return true
        end
    end
    return false
end

-- Create a revolute joint between two bodies
function createRevoluteJoint(body1, body2, x, y, x2, y2, index1, index2)
    local id = generateID()

    local joint = love.physics.newRevoluteJoint(body1, body2, x, y, x2, y2)
    joint:setUserData({ id = id, scriptmeta = { type = 'snap' } })
    --  joint:setUserData({ id = id, scriptmeta = { type = 'snap', index1 = index1, index2 = index2 } })
    table.insert(mySnapJoints, joint)
end

function checkForJointBreaks(dt, interacted)
    for i = #mySnapJoints, 1, -1 do
        local joint = mySnapJoints[i]

        -- Check if the force exceeds the threshold
        local xf, yf = joint:getReactionForce(1 / dt)

        if math.max(math.abs(xf), math.abs(yf)) > jointBreakThreshold then
            -- Break the joint
            -- Cleanup: Mark the snap points as disconnected
            local body1, body2 = joint:getBodies()
            if (not onlyBreakWhenInteracted or (oneOfThemIsInteractedWith(body1, body2, interacted))) then
                for j = 1, #snapPoints do
                    if snapPoints[j].to == body1 and snapPoints[j].at == body2 then
                        snapPoints[j].to = nil
                        addCooldown(snapPoints[j].fixture)
                    elseif snapPoints[j].to == body2 and snapPoints[j].at == body1 then
                        snapPoints[j].to = nil
                        addCooldown(snapPoints[j].fixture)
                    end
                end

                joint:destroy()
                -- Remove the joint from the list of joints
                table.remove(mySnapJoints, i)
            end
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
    local interacted = getInteractedWithPointer()

    checkForJointBreaks(dt, interacted) -- Check for joint breaks every frame
    checkForSnaps(interacted)

    -- print(#joints)
end

return s

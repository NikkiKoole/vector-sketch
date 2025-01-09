-- general usage snap logic
--
local uuid = require 'src.uuid'
local utils = require 'src.utils'
local box2dPointerJoints = require 'src.box2d-pointerjoints'
local mathutils = require 'src.math-utils'

local snapFixtures = {}
local snapDistance = 40            -- Maximum distance to snap
local mySnapJoints = {}            -- Store created joints
local jointBreakThreshold = 100000 -- Force threshold for breaking the joint
local cooldownTime = .5            -- Time in seconds to prevent immediate reconnection
local cooldownList = {}            -- Table to track cooldown for each snap point
local onlyConnectWhenInteracted = true
local onlyBreakWhenInteracted = true

local lib = {}

-- Add cooldown to a snap point
local function addCooldown(fixture)
    local currentTime = love.timer.getTime()
    cooldownList[fixture] = currentTime + cooldownTime
end

-- Check if a snap point is in cooldown
local function isInCooldown(fixture, currentTime)
    return cooldownList[fixture] and currentTime < cooldownList[fixture]
end


local function oneOfThemIsInteractedWith(b1, b2, list)
    for i = 1, #list do
        if list[i] == b1 or list[i] == b2 then
            return true
        end
    end
    return false
end
-- Create a revolute joint between two bodies
local function createRevoluteJoint(body1, body2, x, y, x2, y2, index1, index2)
    local id = uuid.generateID()
    -- print(id)
    local joint = love.physics.newRevoluteJoint(body1, body2, x, y, x2, y2)

    local xa, ya = body1:getLocalPoint(x, y)
    local offsetA = { x = xa, y = ya }

    local xb, yb = body1:getLocalPoint(x2, y2)

    local offsetB = { x = xb, y = yb }

    joint:setUserData({ id = id, offsetA = offsetA, offsetB = offsetB, scriptmeta = { type = 'snap' } })
    --  joint:setUserData({ id = id, scriptmeta = { type = 'snap', index1 = index1, index2 = index2 } })
    table.insert(mySnapJoints, joint)
    registry.registerJoint(id, joint)
    --print('todo save tis joint in registry')
end

local function areBodiesConnected2(body1, body2, snapFixtures)
    for i = 1, #snapFixtures do
        local it = snapFixtures[i]:getUserData().extra
        if (it.to == body1 and it.at == body2) or (it.to == body2 and it.at == body1) then
            return true
        end
    end
    return false
end


function checkForJointBreaks(dt, interacted, snapFixtures)
    -- print(#mySnapJoints)
    --for k, v in pairs(registry.joints) do
    --    print(k, v:isDestroyed())
    --end
    --for i = #mySnapJoints, 1, -1 do
    --    print(i, mySnapJoints[i]:isDestroyed())
    --end


    for i = #mySnapJoints, 1, -1 do
        local joint = mySnapJoints[i]

        -- Check if the force exceeds the threshold
        local xf, yf = joint:getReactionForce(1 / dt)

        if math.max(math.abs(xf), math.abs(yf)) > jointBreakThreshold then
            -- Break the joint
            -- Cleanup: Mark the snap points as disconnected
            local body1, body2 = joint:getBodies()
            if (not onlyBreakWhenInteracted or (oneOfThemIsInteractedWith(body1, body2, interacted))) then
                for j = 1, #snapFixtures do
                    local extra = snapFixtures[j]:getUserData().extra
                    if extra.to == body1 and extra.at == body2 then
                        extra.to = nil
                        local ud = snapFixtures[j]:getUserData()
                        ud.extra = extra
                        snapFixtures[j]:setUserData(ud)
                        addCooldown(snapFixtures[j])
                    elseif extra.to == body2 and extra.at == body1 then
                        extra.to = nil
                        local ud = snapFixtures[j]:getUserData()
                        ud.extra = extra
                        snapFixtures[j]:setUserData(ud)
                        addCooldown(snapFixtures[j])
                    end
                end
                registry.unregisterJoint(joint:getUserData().id)

                joint:destroy()
                -- Remove the joint from the list of joints
                table.remove(mySnapJoints, i)

                --print('todo remove joint from registry')
            end
        end
    end
end

local function checkForSnaps(interacted, snapFixtures)
    -- print(#interacted, #snapFixtures)
    local currentTime = love.timer.getTime()

    for i = 1, #snapFixtures do
        local it1 = snapFixtures[i]:getUserData().extra

        if it1.to == nil and not isInCooldown(it1.fixture, currentTime) then -- else this snap point is already connected and it cannot be connected more then once
            local body1 = it1.at
            if not body1 then
                print('body1 is nil!    ')
                print(inspect(it1))
            end
            local x1, y1 = body1:getWorldPoint(it1.xOffset, it1.yOffset)

            for j = 1, #snapFixtures do
                if j ~= i then                                                           -- else you check it against it
                    local it2 = snapFixtures[j]:getUserData().extra
                    if it2.to == nil and not isInCooldown(it2.fixture, currentTime) then -- else it2 is already connected,
                        local body2 = it2.at
                        local x2, y2 = body2:getWorldPoint(it2.xOffset, it2.yOffset)

                        local distance = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
                        if distance <= snapDistance then
                            if (not onlyConnectWhenInteracted or (oneOfThemIsInteractedWith(body1, body2, interacted))) then
                                if not areBodiesConnected2(body1, body2, snapFixtures) then -- else these bodies are already connected..
                                    createRevoluteJoint(body1, body2, x1, y1, x2, y2, i, j)
                                    it1.to = body2
                                    local ud1 = snapFixtures[i]:getUserData()
                                    ud1.extra = it1
                                    snapFixtures[i]:setUserData(ud1)

                                    it2.to = body1
                                    local ud2 = snapFixtures[j]:getUserData()
                                    ud2.extra = it2
                                    snapFixtures[j]:setUserData(ud2)
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


function lib.update(dt)
    --print(count)
    if #snapFixtures > 0 then
        --print('amount of snapfixtures: ', #snapFixtures)
        local interacted = box2dPointerJoints.getInteractedWithPointer()
        checkForSnaps(interacted, snapFixtures)
        checkForJointBreaks(dt, interacted, snapFixtures) -- Check for joint breaks every frame
    end
end

function lib.maybeUpdateSFixture(id)
    for i = 1, #snapFixtures do
        if (snapFixtures[i]:isDestroyed() or snapFixtures[i]:getUserData().id == id) then
            snapFixtures[i] = registry.getSFixtureByID(id)
        end
    end
end

function lib.rebuildSnapFixtures(sfix)
    snapFixtures = {}
    local count = 0
    for k, v in pairs(sfix) do
        if not v:isDestroyed() then
            local ud = v:getUserData()

            if ud and utils.sanitizeString(ud.label) == 'snap' then
                local centroid = { mathutils.getCenterOfPoints({ v:getShape():getPoints() }) }
                local ud = v:getUserData()
                --print(count, ud.extra, v:getBody(), k)
                ud.extra.xOffset = centroid[1]
                ud.extra.yOffset = centroid[2]
                ud.extra.at = v:getBody()
                ud.extra.fixture = v
                v:setUserData(ud)
                table.insert(snapFixtures, v)
            else
                --     --print('what is wrong ?', not v:isDestroyed(), ud, ud.label == 'snap',
                --     --    ud.label)
            end
            count = count + 1
        end
    end
    print('we now have ', #snapFixtures, 'snapfixtures')
end

function calculateDistance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

function lib.onSceneLoaded()
    --print('should build snapjoints array', #mySnapJoints)

    for k, value in pairs(registry.joints) do
        local ud = value:getUserData()

        -- Check if the joint is a snap-type joint
        --if ud and ud.scriptmeta and ud.scriptmeta.type and ud.scriptmeta.type == 'snap' then
        --    print('wowzers')
        --end

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

            --print(#snapFixtures)
            -- Find all snap points associated with bodyA and bodyB
            for i = 1, #snapFixtures do
                local extra = snapFixtures[i]:getUserData().extra
                local atId = extra.at:getUserData().thing.id
                --print(atId, id1, id2)
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
                local extra = snapFixtures[index]:getUserData().extra
                local wx, wy = extra.at:getLocalPoint(x1, y1)
                local distance = calculateDistance(extra.xOffset, extra.yOffset, wx, wy)
                if distance < indx1dist then
                    indx1dist = distance
                    indx1 = index
                end
            end

            --print(indx1, indx1dist)
            -- Initialize variables to find the closest snap point for bodyB
            local indx2
            local indx2dist = math.huge

            -- Determine the closest snap point for bodyB to the joint's second anchor
            for i = 1, #indx2Options do
                local index = indx2Options[i]
                local extra = snapFixtures[index]:getUserData().extra
                local wx, wy = extra.at:getLocalPoint(x2, y2)
                local distance = calculateDistance(extra.xOffset, extra.yOffset, wx, wy)
                if distance < indx2dist then
                    indx2dist = distance
                    indx2 = index
                end
            end

            -- Link the two closest snap points by setting their 'to' references

            local i1ud = snapFixtures[indx1]:getUserData()
            local i2ud = snapFixtures[indx2]:getUserData()

            i1ud.extra.to = i2ud.extra.at
            i2ud.extra.to = i1ud.extra.at
            snapFixtures[indx1]:setUserData(i1ud)
            snapFixtures[indx2]:setUserData(i2ud)


            table.insert(mySnapJoints, value)
        end
    end
end

function lib.resetList()
    -- print('should reset snapjoints array', #mySnapJoints)
    mySnapJoints = {}
end

function lib.addSnapJoint(j)
    table.insert(mySnapJoints, j)
end

function lib.maybeUpdateSnapJoints(joints)
    for i = 1, #mySnapJoints do
        local msj = mySnapJoints[i]
        local lookForId = msj:getUserData().id

        for j = 1, #joints do
            local newer = joints[j]

            if (lookForId == newer.id) then
                mySnapJoints[i] = registry.getJointByID(newer.id)
            end
        end
    end
end

function lib.maybeUpdateSnapJointWithId(id)
    for i = 1, #mySnapJoints do
        local msj = mySnapJoints[i]
        if msj:isDestroyed() or msj:getUserData().id == id then
            mySnapJoints[i] = registry.getJointByID(id)
        end
        --if snap.maybeUpdateSnapJointWithId(id)
    end
end

function lib.destroySnapJointAboutBody(body)
    --print('should remove things from snapjoints array maybe')
    for i = #mySnapJoints, 1, -1 do
        local joint = mySnapJoints[i]
        local body1, body2 = joint:getBodies()
        if (body:getUserData().thing.id == body1:getUserData().thing.id) then
            registry.unregisterJoint(joint:getUserData().id)
            joint:destroy()
            table.remove(mySnapJoints, i)
        end
        if (body:getUserData().thing.id == body2:getUserData().thing.id) then
            registry.unregisterJoint(joint:getUserData().id)

            joint:destroy()
            table.remove(mySnapJoints, i)
        end
    end
end

return lib
-- end general snap

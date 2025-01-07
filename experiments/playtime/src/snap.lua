-- general usage snap logic
--

local uuid = require 'src.uuid'
--local fixtures = require 'src.fixtures'
local utils = require 'src.utils'
local box2dPointerJoints = require 'src.box2d-pointerjoints'
local mathutils = require 'src.math-utils'
--local snapPoints = {}              -- List of all snap points

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
local function isInCooldown(fixture)
    local currentTime = love.timer.getTime()
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
    joint:setUserData({ id = id, scriptmeta = { type = 'snap' } })
    --  joint:setUserData({ id = id, scriptmeta = { type = 'snap', index1 = index1, index2 = index2 } })
    table.insert(mySnapJoints, joint)
end

local function areBodiesConnected2(body1, body2, snapFixtures)
    for i = 1, #snapFixtures do
        local it = snapFixtures[i]:getUserData()
        if (it.to == body1 and it.at == body2) or (it.to == body2 and it.at == body1) then
            return true
        end
    end
    return false
end


function checkForJointBreaks(dt, interacted, snapFixtures)
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

                joint:destroy()
                -- Remove the joint from the list of joints
                table.remove(mySnapJoints, i)
            end
        end
    end
end

local function checkForSnaps(interacted, snapFixtures)
    -- print(#interacted, #snapFixtures)
    for i = 1, #snapFixtures do
        local it1 = snapFixtures[i]:getUserData().extra

        --print(body1)
        if it1.to == nil and not isInCooldown(it1.fixture) then -- else this snap point is already connected and it cannot be connected more then once
            local body1 = it1.at
            local x1, y1 = body1:getWorldPoint(it1.xOffset, it1.yOffset)

            for j = 1, #snapFixtures do
                if j ~= i then -- else you check it against it
                    local it2 = snapFixtures[j]:getUserData().extra
                    --print(snapFixtures[i] == snapFixtures[j])
                    if it2.to == nil and not isInCooldown(it2.fixture) then -- else it2 is already connected,
                        local body2 = it2.at
                        local x2, y2 = body2:getWorldPoint(it2.xOffset, it2.yOffset)

                        local distance = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
                        --  print(distance, body1 == body2, it1 == it2, i, j, snapFixtures[i]:getUserData(),
                        --     snapFixtures[j]:getUserData())
                        if distance <= snapDistance then
                            -- print(distance, snapDistance)
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


function lib.collectAndUseSnapList(dt)
    --print(count)
    if #snapFixtures > 0 then
        print('amount of snapfixtures: ', #snapFixtures)
        local interacted = box2dPointerJoints.getInteractedWithPointer()
        checkForSnaps(interacted, snapFixtures)
        checkForJointBreaks(dt, interacted, snapFixtures) -- Check for joint breaks every frame
    end
end

function lib.rebuildSnapFixtures(sfix)
    snapFixtures = {}
    local count = 0
    for k, v in pairs(sfix) do
        local ud = v:getUserData()

        if not v:isDestroyed() and ud and utils.sanitizeString(ud.label) == 'snap' then
            local centroid = { mathutils.getCenterOfPoints({ v:getShape():getPoints() }) }
            local ud = v:getUserData()
            print(count, ud.extra, v:getBody(), k)
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

function lib.onSceneLoaded()
    print('should build snapjoints array', #mySnapJoints)
end

function lib.resetList()
    print('should reset snapjoints array', #mySnapJoints)
    mySnapJoints = {}
end

function lib.destroySnapJointAboutBody(body)
    print('should remove things from snapjoints array maybe')
    for i = #mySnapJoints, 1, -1 do
        local joint = mySnapJoints[i]
        local body1, body2 = joint:getBodies()
        if (body:getUserData().thing.id == body1:getUserData().thing.id) then
            joint:destroy()
            table.remove(mySnapJoints, i)
        end
        if (body:getUserData().thing.id == body2:getUserData().thing.id) then
            joint:destroy()
            table.remove(mySnapJoints, i)
        end
    end
end

return lib
-- end general snap

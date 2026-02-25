-- general usage snap logic
--
local logger = require 'src.logger'
local inspect = require 'vendor.inspect'
local registry = require 'src.registry'
local uuid = require 'src.uuid'
local utils = require 'src.utils'
local box2dPointerJoints = require 'src.physics.box2d-pointerjoints'
local mathutils = require 'src.math-utils'

local snapFixtures = {}
local snapDistance = 140           -- Maximum distance to snap
local activeSnapJoints = {}            -- Store created joints
local jointBreakThreshold = 100000 -- Force threshold for breaking the joint
local cooldownTime = .5            -- Time in seconds to prevent immediate reconnection
local cooldownList = {}            -- Table to track cooldown for each snap point
local onlyConnectWhenInteracted = true
local onlyBreakWhenInteracted = true

local lib = {}


-- todo currently snap is a bit broken.. (snap fixtures dont seem to have the at and to in the xtra data set ?)
-- the script 'snap.playtime.lua' is wroking investigate this further in the near future

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
local function createRevoluteJoint(body1, body2, x, y, x2, y2, _index1, _index2)
    local id = uuid.generateID()

    local joint = love.physics.newRevoluteJoint(body1, body2, x, y, x2, y2)

    local xa, ya = body1:getLocalPoint(x, y)
    local offsetA = { x = xa, y = ya }

    local xb, yb = body1:getLocalPoint(x2, y2)

    local offsetB = { x = xb, y = yb }

    joint:setUserData({ id = id, offsetA = offsetA, offsetB = offsetB, scriptmeta = { type = 'snap' } })
    --  joint:setUserData({ id = id, scriptmeta = { type = 'snap', index1 = index1, index2 = index2 } })
    table.insert(activeSnapJoints, joint)
    registry.registerJoint(id, joint)
end

local function areBodiesConnected2(body1, body2, snapFix)
    for i = 1, #snapFix do
        local snapInfo = snapFix[i]:getUserData().extra
        if (snapInfo.to == body1 and snapInfo.at == body2) or (snapInfo.to == body2 and snapInfo.at == body1) then
            return true
        end
    end
    return false
end


local function checkForJointBreaks(dt, interacted, snapFix)
    for i = #activeSnapJoints, 1, -1 do
        local joint = activeSnapJoints[i]

        -- Check if the force exceeds the threshold
        local xf, yf = joint:getReactionForce(1 / dt)

        if math.max(math.abs(xf), math.abs(yf)) > jointBreakThreshold then
            -- Break the joint
            -- Cleanup: Mark the snap points as disconnected
            local body1, body2 = joint:getBodies()
            if (not onlyBreakWhenInteracted or (oneOfThemIsInteractedWith(body1, body2, interacted))) then
                for j = 1, #snapFix do
                    local extra = snapFix[j]:getUserData().extra
                    if extra.to == body1 and extra.at == body2 then
                        extra.to = nil
                        local ud = snapFix[j]:getUserData()
                        ud.extra = extra
                        snapFix[j]:setUserData(ud)
                        addCooldown(snapFix[j])
                    elseif extra.to == body2 and extra.at == body1 then
                        extra.to = nil
                        local ud = snapFix[j]:getUserData()
                        ud.extra = extra
                        snapFix[j]:setUserData(ud)
                        addCooldown(snapFix[j])
                    end
                end
                registry.unregisterJoint(joint:getUserData().id)

                joint:destroy()
                -- Remove the joint from the list of joints
                table.remove(activeSnapJoints, i)
            end
        end
    end
end

local function checkForSnaps(interacted, snapFix)
    local currentTime = love.timer.getTime()

    for i = 1, #snapFix do
        local snapInfoA = snapFix[i]:getUserData().extra

        -- else this snap point is already connected and it cannot be connected more then once
        if snapInfoA.to == nil and not isInCooldown(snapInfoA.fixture, currentTime) then
            local body1 = snapInfoA.at
            if not body1 then
                logger:error('body1 is nil!    ')
                logger:info(inspect(snapInfoA))
            end

            -- todo , src/snap.lua:119: attempt to call method 'getWorldPoint' (a nil value)

            local x1, y1 = body1:getWorldPoint(snapInfoA.xOffset, snapInfoA.yOffset)

            for j = 1, #snapFix do
                if j ~= i then                                                           -- else you check it against it
                    local snapInfoB = snapFix[j]:getUserData().extra
                    -- else snapInfoB is already connected,
                    if snapInfoB.to == nil and not isInCooldown(snapInfoB.fixture, currentTime) then
                        local body2 = snapInfoB.at
                        local x2, y2 = body2:getWorldPoint(snapInfoB.xOffset, snapInfoB.yOffset)

                        local distance = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
                        if distance <= snapDistance then
                            if (not onlyConnectWhenInteracted
                                    or (oneOfThemIsInteractedWith(body1, body2, interacted))) then
                                -- else these bodies are already connected..
                                if not areBodiesConnected2(body1, body2, snapFix) then
                                    createRevoluteJoint(body1, body2, x1, y1, x2, y2, i, j)
                                    snapInfoA.to = body2
                                    local ud1 = snapFix[i]:getUserData()
                                    ud1.extra = snapInfoA
                                    snapFix[i]:setUserData(ud1)

                                    snapInfoB.to = body1
                                    local ud2 = snapFix[j]:getUserData()
                                    ud2.extra = snapInfoB
                                    snapFix[j]:setUserData(ud2)
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
    if #snapFixtures > 0 then
        --print('amount of snapfixtures: ', #snapFixtures)
        local interacted = box2dPointerJoints.getInteractedWithPointer()
        checkForSnaps(interacted, snapFixtures)
        checkForJointBreaks(dt, interacted, snapFixtures) -- Check for joint breaks every frame
    end
end

function lib.maybeUpdateSFixture(id)
    for i = 1, #snapFixtures do
        -- TODO snapFixtures should bbecome a key value map keyed on IDs
        if (snapFixtures[i]:isDestroyed() or snapFixtures[i]:getUserData().id == id) then
            snapFixtures[i] = registry.getSFixtureByID(id)
        end
    end
end

function lib.rebuildSnapFixtures(sfix)
    snapFixtures = {}
    local count = 0
    for _, v in pairs(sfix) do
        if not v:isDestroyed() then
            local ud = v:getUserData()
            --logger:inspect(ud)
            if ud and utils.sanitizeString(ud.subtype) == 'snap' then
                local centroid = { mathutils.getCenterOfPoints({ v:getShape():getPoints() }) }

                ud.extra.xOffset = centroid[1]
                ud.extra.yOffset = centroid[2]
                ud.extra.at = v:getBody()
                ud.extra.fixture = v
                v:setUserData(ud)
                table.insert(snapFixtures, v)
            end
            count = count + 1
        end
    end
    --print('we now have ', #snapFixtures, 'snapfixtures')
end

local calculateDistance = mathutils.calculateDistance

function lib.onSceneLoaded()
    --print('should build snapjoints array', #activeSnapJoints)

    for _, value in pairs(registry.joints) do
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


            for i = 1, #snapFixtures do
                local extra = snapFixtures[i]:getUserData().extra
                local atId = extra.at:getUserData().thing.id

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


            table.insert(activeSnapJoints, value)
        end
    end
end

function lib.resetList()
    activeSnapJoints = {}
end

function lib.addSnapJoint(joint)
    table.insert(activeSnapJoints, joint)
end

function lib.maybeUpdateSnapJoints(joints)
    for i = 1, #activeSnapJoints do
        local msj = activeSnapJoints[i]
        local lookForId = msj:getUserData().id

        for j = 1, #joints do
            local newer = joints[j]

            if (lookForId == newer.id) then
                activeSnapJoints[i] = registry.getJointByID(newer.id)
            end
        end
    end
end

function lib.maybeUpdateSnapJointWithId(id)
    for i = 1, #activeSnapJoints do
        local msj = activeSnapJoints[i]
        -- TODO activeSnapJoints should bbecome a key value map keyed on IDs
        if msj:isDestroyed() or msj:getUserData().id == id then
            activeSnapJoints[i] = registry.getJointByID(id)
        end
        --if snap.maybeUpdateSnapJointWithId(id)
    end
end

function lib.destroySnapJointAboutBody(body)
    for i = #activeSnapJoints, 1, -1 do
        local joint = activeSnapJoints[i]
        local body1, body2 = joint:getBodies()
        if (body:getUserData().thing.id == body1:getUserData().thing.id) then
            registry.unregisterJoint(joint:getUserData().id)
            joint:destroy()
            table.remove(activeSnapJoints, i)
        end
        if (body:getUserData().thing.id == body2:getUserData().thing.id) then
            registry.unregisterJoint(joint:getUserData().id)

            joint:destroy()
            table.remove(activeSnapJoints, i)
        end
    end
end

return lib
-- end general snap

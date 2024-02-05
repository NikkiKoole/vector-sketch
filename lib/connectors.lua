local Vector          = require 'vendor.brinevector'
local inspect = require 'vendor.inspect'
local lib = {}


local connectorCooldownList = {}
local connectors = {}

-- will need the lisyts connector and connetorcooldown lisyt
-- function to add connection , breka connection

-- copy pasta
local function makeUserData(bodyType, moreData)
    local result = {
        bodyType = bodyType,
    }
    if moreData then
        result.data = moreData
    end
    return result
end

-- copy pasta
local makeRectPoly2 = function(w, h, x, y)
    local cx = x
    local cy = y
    return love.physics.newPolygonShape(
            cx - w / 2, cy - h / 2,
            cx + w / 2, cy - h / 2,
            cx + w / 2, cy + h / 2,
            cx - w / 2, cy + h / 2
        )
end


lib.breakAllConnectionsAtBody = function(thing)
    for i = 1, #connectors do 
        
        if (connectors[i].at:getBody() ==  thing) then 
            if connectors[i].joint then 
                connectors[i].joint:destroy()
                connectors[i].joint = nil
                connectors[i].to = nil
            end
        end

        -- connection couldve been made the oher way around..
        -- those need breaking too
        if (connectors[i].to and connectors[i].to:getBody() ==  thing) then 
            if connectors[i].joint then 
                connectors[i].joint:destroy()
                connectors[i].joint = nil
            end
        end
    end
end


lib.makeAndAddConnector = function(parent, x, y, data, size, size2)
    size = size or 10
    size2 = size2 or size
    local bandshape2 = makeRectPoly2(size, size2, x, y)
    local fixture = love.physics.newFixture(parent, bandshape2, 0)
    fixture:setUserData(makeUserData('connector', data))
    fixture:setSensor(true)
    table.insert(connectors, { at = fixture, to = nil, joint = nil })
    --print('jo hello!', #connectors)
end

lib.getRecreateConnectorData = function(allAttachedFixtures)
    local result = nil
    for i = 1, #allAttachedFixtures do
        local f = allAttachedFixtures[i]
        if f:getUserData() and f:getUserData().bodyType == 'connector' then
            for j = 1, #connectors do
                if connectors[j].at == f then
                    result = { oldFixture = f, userData = f:getUserData() }
                    return result
                end
            end
        end
    end
    return result
end

lib.makeAndReplaceConnector = function(recreate, parent, x, y, data, size, size2)
    size = size or 10
    size2 = size2 or size
    local bandshape2 = makeRectPoly2(size, size, x, y)
    local fixture = love.physics.newFixture(parent, bandshape2, 1)

    fixture:setUserData(makeUserData('connector', data))
    fixture:setSensor(true)

    -- we are remaking a connector, keep all its connections working here!
    for i = 1, #connectors do
        if connectors[i].at and connectors[i].at == recreate.oldFixture then
            connectors[i].at = fixture
            if connectors[i].to then
                local j = lib.getJointBetween2Connectors(connectors[i].to, connectors[i].at)
                connectors[i].joint = j
            end
        end

        if connectors[i].to and connectors[i].to == recreate.oldFixture then
            connectors[i].to = fixture

            local j = lib.getJointBetween2Connectors(connectors[i].to, connectors[i].at)
            connectors[i].joint = j
        end
    end
end

lib.resetConnectors = function() 
    connectors = {}
    connectorCooldownList = {}
end

local function getCenterOfPoints(points)
    local tlx = math.huge
    local tly = math.huge
    local brx = -math.huge
    local bry = -math.huge
    for ip = 1, #points, 2 do
        if points[ip + 0] < tlx then tlx = points[ip + 0] end
        if points[ip + 1] < tly then tly = points[ip + 1] end
        if points[ip + 0] > brx then brx = points[ip + 0] end
        if points[ip + 1] > bry then bry = points[ip + 1] end
    end
    --return tlx, tly, brx, bry
    local w = brx - tlx
    local h = bry - tly
    return tlx + w / 2, tly + h / 2
end

local function getCentroidOfFixture(body, fixture)
    return { getCenterOfPoints({ body:getWorldPoints(fixture:getShape():getPoints()) }) }
end

lib.getJointBetween2Connectors = function(to, at)
    local pos1 = getCentroidOfFixture(to:getBody(), to)
    local pos2 = getCentroidOfFixture(at:getBody(), at)
    local j = love.physics.newRevoluteJoint(at:getBody(), to:getBody(),
            pos2[1],
            pos2[2], pos1[1], pos1[2])
    return j
end

lib.maybeConnectThisConnector = function(f, mj)
    local found = false

    -- we dont want to do anything with connectors of sleeping bodies, it crashes when trying to get the bbox
    if f:getBody():isActive() == false then
         
        found = true
    end

    for j = 1, #connectors do
        if connectors[j].to and connectors[j].to == f then
            found = true
        end
    end
   
    if found == false then
        local pos1 = getCentroidOfFixture(f:getBody(), f)
        local done = false

        for j = 1, #connectors do
            if (connectors[j].at:isDestroyed()) then
                print('THIS IS A DESTROYED CONNECTOR, WHY IS IT  STILL HEREE??')
            end
            local theOtherBody = connectors[j].at:getBody()

            -- maybe verify that both connector dont point to the same agent (as in are both part of the same character)
            local skipCausePointingToSameAgent = false
            if (f:getUserData().data and connectors[j].at:getUserData() and connectors[j].at:getUserData().data) then
                if f:getUserData().data.id and connectors[j].at:getUserData().data.id then
                    if f:getUserData().data.id == connectors[j].at:getUserData().data.id then
                        skipCausePointingToSameAgent = true
                    end
                end
            end
            if theOtherBody:isActive() == false then
                -- we also want to skip because this will assert and break in box2d
                skipCausePointingToSameAgent = true
            end
            if not skipCausePointingToSameAgent and theOtherBody ~= f:getBody() and connectors[j].to == nil then
                local pos2 = getCentroidOfFixture(theOtherBody, connectors[j].at)

                local a = pos1[1] - pos2[1]
                local b = pos1[2] - pos2[2]
                local d = math.sqrt(a * a + b * b)

                local isOnCooldown = false

                for p = 1, #connectorCooldownList do
                    if connectorCooldownList[p].index == j then
                        isOnCooldown = true
                    end
                end

                local topLeftX, topLeftY, bottomRightX, bottomRightY = f:getBoundingBox(1)
                local w1 = bottomRightX - topLeftX
                local topLeftX, topLeftY, bottomRightX, bottomRightY = theOtherBody:getFixtures()[1]
                    :getBoundingBox(1)
                local w2 = bottomRightX - topLeftX
                local maxD = (w1 + w2) / 2

                if d < maxD and not isOnCooldown then
                    connectors[j].to = f --mj.jointBody
                    local joint = lib.getJointBetween2Connectors(connectors[j].to, connectors[j].at)
                    connectors[j].joint = joint
                end
            end
        end
    end
end



lib.maybeBreakAnyConnectorBecauseForce = function(dt) 
    if true then
        if connectors then
            for i = #connectors, 1, -1 do
                -- we can only break a  joint if we have one

                if connectors[i].joint then
                    local reaction2 = { connectors[i].joint:getReactionForce(1 / dt) }
                    local delta = Vector(reaction2[1], reaction2[2])
                    local l = delta:getLength()
                    local found = false

                    for j = 1, #pointerJoints do
                        local mj = pointerJoints[j]
                        if mj.jointBody == connectors[i].to:getBody() or mj.jointBody == connectors[i].at:getBody() then
                            found = true
                        end
                    end

                    local b1, b2 = connectors[i].joint:getBodies()
                    local breakForce = 100000 * math.max(1, (b1:getMass() * b2:getMass()))
                    local breakForceWhenNotMouseJointed = 2000000 * (b1:getMass() * b2:getMass())

                    if ((found and l > breakForce) or (not found and l > breakForceWhenNotMouseJointed)) then
                       -- print('broke when foudn', found, inspect(connectors[i]))
                        connectors[i].joint:destroy()
                        connectors[i].joint = nil

                        connectors[i].to = nil
                        print('broke it', i, l, breakForce)
                        table.insert(connectorCooldownList, { runningFor = 0, index = i })
                    end
                end
            end
        end
    end
end

lib.cleanupCoolDownList = function(dt) 
    local now = love.timer.getTime()
    for i = #connectorCooldownList, 1, -1 do
        connectorCooldownList[i].runningFor = connectorCooldownList[i].runningFor + dt
        if (connectorCooldownList[i].runningFor > 0.5) then
            table.remove(connectorCooldownList, i)
        end
    end
end




return lib
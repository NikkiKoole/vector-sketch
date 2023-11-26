
local generatePolygon = require('lib.generate-polygon').generatePolygon


function killMouseJointIfPossible(id)
    local index = -1
    for i = 1, #pointerJoints do
        if pointerJoints[i].id == id then
            index = i
            if (pointerJoints[i].joint and not pointerJoints[i].joint:isDestroyed()) then
                pointerJoints[i].joint:destroy()
            end
            pointerJoints[i].joint     = nil
            pointerJoints[i].jointBody = nil
        end
    end
    table.remove(pointerJoints, index)
end


local function makePointerJoint(id, bodyToAttachTo, wx, wy)
    local pointerJoint = {}
    pointerJoint.id = id
    pointerJoint.jointBody = bodyToAttachTo
    pointerJoint.joint = love.physics.newMouseJoint(pointerJoint.jointBody, wx, wy)
    pointerJoint.joint:setDampingRatio(.5)
    pointerJoint.joint:setMaxForce(5000000)
    return pointerJoint
end


local function makePrio(fixture)
    local ud = fixture:getUserData()
    if ud then
        if string.match(ud.bodyType, 'hand') then
            return 3
        end

        if string.match(ud.bodyType, 'arm') then
            return 2
        end
    end
    return 1
end



local function getPointerPosition(id)
    if id == 'mouse' then
        return love.mouse.getPosition()
    else
        return love.touch.getPosition(id)
    end
end

function handleUpdate(dt, cam) 
    for i = 1, #pointerJoints do
        local mj = pointerJoints[i]
        if (mj.joint) then
            local mx, my = getPointerPosition(mj.id) --love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)
            mj.joint:setTarget(wx, wy)

            local fixtures = mj.jointBody:getFixtures();
            for k = 1, #fixtures do
                local f = fixtures[k]
                if f:getUserData() and f:getUserData().bodyType then
                    if f:getUserData().bodyType == 'connector' then
                        maybeConnectThisConnector(f)
                    end

                    if f:getUserData().bodyType == 'carbody' then
                        local body = mj.jointBody
                        if body then
                            -- i dont have a cartouching per car, its global so wont work for all
                            --if (carIsTouching < 1) then
                            rotateToHorizontal(body, 0, 30)
                            --end
                        end
                    end
                end
            end
        end
    end
end

function handlePointerPressed(x,y,id, cam) 
    
        local wx, wy = cam:getWorldCoordinates(x, y)
        local bodies = world:getBodies()
        local temp = {}
        for _, body in ipairs(bodies) do
            if body:getType() ~= 'kinematic' then
                local fixtures = body:getFixtures()
                for _, fixture in ipairs(fixtures) do
                    local hitThisOne = fixture:testPoint(wx, wy)
                    local isSensor = fixture:isSensor()
                    if (hitThisOne and not isSensor) then
                        table.insert(temp, { id = id, body = body, wx = wx, wy = wy, prio = makePrio(fixture) })
                    end
                end
            end
        end
        if #temp > 0 then
            table.sort(temp, function(k1, k2) return k1.prio > k2.prio end)
            killMouseJointIfPossible(id)
            table.insert(pointerJoints, makePointerJoint(temp[1].id, temp[1].body, temp[1].wx, temp[1].wy))
        end
    
        if #temp == 0 then killMouseJointIfPossible(id) end
  
        return #temp > 0 
end


function handlePointerReleased(x, y, id)
    for i = 1, #pointerJoints do
        local mj = pointerJoints[i]
        -- if false then
        if mj.id == id then
            if (mj.joint) then   --- UNUSED 
                if false then   -- this is to shoot objects when you drag then below the groud (pim pam pet effect])
                if (mj.jointBody and objects.ground) then
                    local points = { objects.ground.body:getWorldPoints(objects.ground.shape:getPoints()) }
                    local tl = { points[1], points[2] }
                    local tr = { points[3], points[4] }
                    -- fogure out if we are below the ground, and if so whatthe ange is we want to be shot at.
                    -- oh wait, this is actually kinda good enough-ish (tm)
                    if (mj.bodyLastDisabledContact and mj.bodyLastDisabledContact:getBody() == mj.jointBody) then
                        local x1, y1 = mj.jointBody:getPosition()
                        if (#mj.positionOfLastDisabledContact > 0) then
                            local x2 = mj.positionOfLastDisabledContact[1]
                            local y2 = mj.positionOfLastDisabledContact[2]

                            local delta = Vector(x1 - x2, y1 - y2)
                            local l = delta:getLength()

                            local v = delta:getNormalized() * l * -2
                            if v.y > 0 then
                                v.y = 0
                                v.x = 0
                            end -- i odnt want  you shoooting downward!
                            mj.bodyLastDisabledContact:getBody():applyLinearImpulse(v.x, v.y)
                        end
                        mj.bodyLastDisabledContact = nil
                        mj.positionOfLastDisabledContact = nil
                        --
                    end
                end end
            end
            --   end
        end
    end
    killMouseJointIfPossible(id)
end




function getRandomConvexPoly(radius, numVerts)
    local vertices = generatePolygon(0, 0, radius, 0.1, 0.1, numVerts)
    while not love.math.isConvex(vertices) do
        vertices = generatePolygon(0, 0, radius, 0.1, 0.1, numVerts)
    end
    return vertices
end

local function getBodyColor(body)
    if body:getType() == 'kinematic' then
        return {1,0,0,1}--palette[colors.peach]
    end
    if body:getType() == 'dynamic' then
        return {0,1,0,1}--palette[colors.blue]
    end
    if body:getType() == 'static' then
        return {1,1,0,1}--palette[colors.green]
    end
end

function drawWorld(world)
    -- get the current color values to reapply
    local r, g, b, a = love.graphics.getColor()
    -- alpha value is optional
    local alpha = .8
    -- Colliders debug
    love.graphics.setColor(0, 0, 0, alpha)
    local bodies = world:getBodies()
    love.graphics.setLineWidth(10)
    for _, body in ipairs(bodies) do
        local fixtures = body:getFixtures()
        for _, fixture in ipairs(fixtures) do
            if fixture:getShape():type() == 'PolygonShape' then
                local color = getBodyColor(body)
                love.graphics.setColor(color[1], color[2], color[3], alpha)
                love.graphics.polygon("fill", body:getWorldPoints(fixture:getShape():getPoints()))
                love.graphics.setColor(0, 0, 0, alpha)
                love.graphics.polygon('line', body:getWorldPoints(fixture:getShape():getPoints()))
            elseif fixture:getShape():type() == 'EdgeShape' or fixture:getShape():type() == 'ChainShape' then
                local points = { body:getWorldPoints(fixture:getShape():getPoints()) }
                for i = 1, #points, 2 do
                    if i < #points - 2 then love.graphics.line(points[i], points[i + 1], points[i + 2], points[i + 3]) end
                end
            elseif fixture:getShape():type() == 'CircleShape' then
                local body_x, body_y = body:getPosition()
                local shape_x, shape_y = fixture:getShape():getPoint()
                local r = fixture:getShape():getRadius()
                local color = getBodyColor(body)
                love.graphics.setColor(color[1], color[2], color[3], alpha)
                love.graphics.circle('fill', body_x + shape_x, body_y + shape_y, r, 360)
                love.graphics.setColor(0, 0, 0, alpha)
                love.graphics.circle('line', body_x + shape_x, body_y + shape_y, r, 360)
            end
        end
    end
    love.graphics.setColor(255, 255, 255, alpha)
    -- Joint debug
    love.graphics.setColor(1, 0, 0, alpha)
    local joints = world:getJoints()
    for _, joint in ipairs(joints) do
        local x1, y1, x2, y2 = joint:getAnchors()
        if x1 and y1 then love.graphics.circle('line', x1, y1, 4) end
        if x2 and y2 then love.graphics.circle('line', x2, y2, 4) end
    end

    love.graphics.setColor(r, g, b, a)
end

local function contactShouldBeDisabled(a, b, contact)
    local ab = a:getBody()
    local bb = b:getBody()

    local fixtureA, fixtureB = contact:getFixtures()
    local result = false

    -- for some reason the other way around doesnt happen so fixtureA is the ground and the other one might be ball
    -- this disables contact between a dragged item and the ground
    for i = 1, #pointerJoints do
        local mj = pointerJoints[i]
        if (mj.jointBody) then
            if (bb == mj.jointBody and fixtureA:getUserData() and fixtureA:getUserData().bodyType == 'ground') then
                result = true
            end
        end
    end
    -- this disables contact between  balls and the ground if ballcenterY < collisionY (ball below ground)
    if fixtureA:getUserData() and fixtureB:getUserData() then
        if fixtureA:getUserData().bodyType == 'ground' and fixtureB:getUserData().bodyType == 'ball' then
            local x1, y1 = contact:getPositions()
            if y1 < bb:getY() then
                result = true
            end
        end
    end
    --return result

    return false
end

local function isContactThatShouldJustAffectOneParty(contact)
    local fixtureA, fixtureB = contact:getFixtures()
    if fixtureA:getUserData() and fixtureB:getUserData() then
        if fixtureA:getUserData().bodyType == 'no-effect' then
            --print('jo!')
            return true
        end
        --print(fixtureA:getUserData().bodyType, fixtureB:getUserData().bodyType)
    else
    end
end

local function beginContact(a, b, contact)
    isContactThatShouldJustAffectOneParty(contact)
    if contactShouldBeDisabled(a, b, contact) then
        contact:setEnabled(false)
        local point = { contact:getPositions() }
        -- i also should keep around what body (cirlcle) this is about,
        -- and also eventually probably also waht touch id or mouse this is..

        for i = 1, #pointerJoints do
            local mj = pointerJoints[i]

            local bodyLastDisabledContact = nil
            if mj.jointBody == a:getBody() then
                bodyLastDisabledContact = a
            end
            if mj.jointBody == b:getBody() then
                bodyLastDisabledContact = b
            end
            if bodyLastDisabledContact then
                pointerJoints[i].bodyLastDisabledContact = bodyLastDisabledContact
                pointerJoints[i].positionOfLastDisabledContact = point
                table.insert(disabledContacts, contact)
            end
        end
    end
    --if isContactBetweenGroundAndCarGroundSensor(contact) then
    --    carIsTouching = carIsTouching + 1
    --end
end


local function endContact(a, b, contact)
    for i = #disabledContacts, 1, -1 do
        if disabledContacts[i] == contact then
            table.remove(disabledContacts, i)
        end
    end
   -- if isContactBetweenGroundAndCarGroundSensor(contact) then
   --     carIsTouching = carIsTouching - 1
   -- end
end

local function preSolve(a, b, contact)
    -- this is so contacts keep on being disabled if they are on that list (sadly they are being re-enabled by box2d.... )
    for i = 1, #disabledContacts do
        disabledContacts[i]:setEnabled(false)
    end
end

local function postSolve(a, b, contact, normalimpulse, tangentimpulse)

end




function setupWorld() 
    love.physics.setMeter(500)
    world = love.physics.newWorld(0, 9.81 * love.physics.getMeter(), true)
    world:setCallbacks(beginContact, endContact, preSolve, postSolve)
    disabledContacts = {}
    pointerJoints = {}
    connectorCooldownList = {}

end
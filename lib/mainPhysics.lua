local bbox            = require 'lib.bbox'
local generatePolygon = require('lib.generate-polygon').generatePolygon
local Vector          = require 'vendor.brinevector'
local camera          = require 'lib.camera'
local numbers         = require 'lib.numbers'
local cam             = require('lib.cameraBase').getInstance()
local lib             = {}
local inspect = require 'vendor.inspect'
local connect = require 'lib.connectors'

local function makeUserData(bodyType, moreData)
    local result = {
        bodyType = bodyType,
    }
    if moreData then
        result.data = moreData
    end
    return result
end

local function makeRectPoly(w, h, x, y)
    return love.physics.newPolygonShape(
            x, y,
            x + w, y,
            x + w, y + h,
            x, y + h
        )
end

local function makeRuitPoly(w, h, x, y)
    return love.physics.newPolygonShape(
            x, y - h / 2,
            x + w / 2, y,
            x, y + h / 2,
            x - w / 2, y
        )
end
local function makeRectPoly2(w, h, x, y)
    return love.physics.newPolygonShape(
            x - w / 2, y - h / 2,
            x + w / 2, y - h / 2,
            x + w / 2, y + h / 2,
            x - w / 2, y + h / 2
        )
end

local function capsuleXY(w, h, cs, x, y)
    -- cs == cornerSize
    local w2 = w / 2
    local h2 = h / 2

    local bt = -h2 + cs
    local bb = h2 - cs
    local bl = -w2 + cs
    local br = w2 - cs

    local result = {
        x + -w2, y + bt,
        x + bl, y + -h2,
        x + br, y + -h2,
        x + w2, y + bt,
        x + w2, y + bb,
        x + br, y + h2,
        x + bl, y + h2,
        x + -w2, y + bb
    }
    return result
end

local function makeTrapeziumPoly(w, w2, h, x, y)
    local cx = x
    local cy = y
    return love.physics.newPolygonShape(
            cx - w / 2, cy - h / 2,
            cx + w / 2, cy - h / 2,
            cx + w2 / 2, cy + h / 2,
            cx - w2 / 2, cy + h / 2
        )
end

local function makePointerJoint(id, bodyToAttachTo, wx, wy, force)
    local pointerJoint = {}
    pointerJoint.id = id

    -- local ud = fixture:getUserData()
    -- TODO parametrtize this...!
    -- local force = 100 -- ud and ud.bodyType == 'torso' and 5000000 or 50000

    pointerJoint.jointBody = bodyToAttachTo
    pointerJoint.joint = love.physics.newMouseJoint(pointerJoint.jointBody, wx, wy)
    pointerJoint.joint:setDampingRatio(.5)
    pointerJoint.joint:setMaxForce(force)
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

local function getRandomConvexPoly(radius, numVerts)
    local vertices = generatePolygon(0, 0, radius, 0.1, 0.1, numVerts)
    while not love.math.isConvex(vertices) do
        vertices = generatePolygon(0, 0, radius, 0.1, 0.1, numVerts)
    end
    return vertices
end

local function getBodyColor(body)
    if body:getType() == 'kinematic' then
        return { 1, 0, 0, 1 } --palette[colors.peach]
    end
    if body:getType() == 'dynamic' then
        return { 0, 1, 0, 1 } --palette[colors.blue]
    end
    if body:getType() == 'static' then
        return { 1, 1, 0, 1 } --palette[colors.green]
    end
end

lib.setupBox2dScene = function(onlyThisGuyIndex, makeFunc)
    local w, h = love.graphics.getDimensions()
    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(w / 2, h / 2 - 1000, 3000, 3000)


    for i = 1, #fiveGuys do
        fiveGuys[i].b2d = nil
    end
    -- box2dGuys = {}

    lib.rebuildPhysicsBorderForScreen()

    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)
    local boxWorldWidth = cambrx - camtlx
    local stepSize = boxWorldWidth / (#fiveGuys + 1)


    for i = 1, #fiveGuys do
        local xPos = onlyThisGuyIndex and (camtlx + 3 * stepSize) or (camtlx + i * stepSize)
        if onlyThisGuyIndex and i == onlyThisGuyIndex or not onlyThisGuyIndex then
            fiveGuys[i].b2d = makeFunc(xPos, camtly, fiveGuys[i])
        end
    end
end

lib.rebuildPhysicsBorderForScreen = function()
    if borders then
        for i = 1, #borders do
            if not borders[i]:isDestroyed() then
                borders[i]:destroy()
            end
        end
    end
    borders = {}
    local w, h = love.graphics.getDimensions()
    -- camera.setCameraViewport(cam, w, h)
    -- camera.centerCameraOnPosition(w / 2, h / 2 - 1000, 3000, 3000)
    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)
    local boxWorldWidth = cambrx - camtlx
    local boxWorldHeight = cambry - camtly

    local wallThick = 4000
    local sideHigh = 20000
    local half = wallThick / 2

    local top = love.physics.newBody(world, w / 2, camtly - sideHigh, "static")
    local topshape = love.physics.newRectangleShape(boxWorldWidth, 3000)
    local topfixture = love.physics.newFixture(top, topshape, 1)
    topfixture:setUserData(makeUserData('border', {}))


    local bottom = love.physics.newBody(world, w / 2, cambry + half, "static")
    local bottomshape = love.physics.newRectangleShape(boxWorldWidth, wallThick)
    local bottomfixture = love.physics.newFixture(bottom, bottomshape, 1)
    bottomfixture:setUserData(makeUserData('border', {}))

    local left = love.physics.newBody(world, camtlx - half, 2500 - 15000, "static")
    local leftshape = love.physics.newRectangleShape(wallThick, 30000)
    local leftfixture = love.physics.newFixture(left, leftshape, 1)
    leftfixture:setUserData(makeUserData('border', {}))

    local right = love.physics.newBody(world, cambrx + half, 2500 - 15000, "static")
    local rightshape = love.physics.newRectangleShape(wallThick, 30000)
    local rightfixture = love.physics.newFixture(right, rightshape, 1)
    rightfixture:setUserData(makeUserData('border', {}))

    borders = { topfixture, bottomfixture, leftfixture, rightfixture }
end



lib.makeRectPoly2 = function(w, h, x, y)
    local cx = x
    local cy = y
    return love.physics.newPolygonShape(
            cx - w / 2, cy - h / 2,
            cx + w / 2, cy - h / 2,
            cx + w / 2, cy + h / 2,
            cx - w / 2, cy + h / 2
        )
end

lib.killMouseJointIfPossible = function(id)
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

lib.makeShapeFromCreationPart = function(part)
    if part.metaPoints then
        local tlx, tly, brx, bry = bbox.getPointsBBox(part.metaPoints)
        local bbw = (brx - tlx)
        local bbh = (bry - tly)
        local wscale = part.w / bbw
        local hscale = part.h / bbh
        local flatted = {}

        local offsetX = 0
        local offsetY = 0

        if part.metaOffsetX or part.metaOfsetY then
            offsetX = part.metaOffsetX
            offsetY = part.metaOffsetY
        end

        for i = 1, #part.metaPoints do
            table.insert(flatted, (offsetX + part.metaPoints[i][1]) * wscale)
            table.insert(flatted, (offsetY + part.metaPoints[i][2]) * hscale)
        end
        return love.physics.newPolygonShape(flatted)
    else
        return lib.makeShape(part.shape, part.w, part.h)
    end
end

lib.makeShape = function(shapeType, w, h)
    if (shapeType == 'rect2') then
        return makeRectPoly(w, h, 0, h / 2)
    elseif (shapeType == 'rect1') then
        return makeRectPoly(w, h, -w / 2, -h / 8)
    elseif (shapeType == 'rect3') then
        return makeRectPoly2(w, h, 0, 0)
    elseif (shapeType == 'ruit') then
        return makeRuitPoly(w, h, 0, 0)
    elseif (shapeType == 'capsule') then
        return love.physics.newPolygonShape(capsuleXY(w, h, w / 5, 0, h / 2))
    elseif (shapeType == 'capsule2') then
        return love.physics.newPolygonShape(capsuleXY(w, h, w / 5, 0, 0))
    elseif (shapeType == 'capsule3') then
        return love.physics.newPolygonShape(capsuleXY(w, h, w / 5, 0, -h / 2))
    elseif (shapeType == 'trapezium') then
        return makeTrapeziumPoly(w, w * 1.2, h, 0, 0)
    elseif (shapeType == 'trapezium2') then
        return makeTrapeziumPoly(w, w * 1.2, h, 0, h / 2)
    elseif (shapeType == 'circle') then
        return love.physics.newCircleShape(0, 0, w)
    elseif (shapeType == 'octagon') then
        return love.physics.newPolygonShape(capsuleXY(w, h, w / 3, 0, 0))
    end
end

lib.setupWorld = function()
    love.physics.setMeter(500)
    world = love.physics.newWorld(0, 9.81 * love.physics.getMeter(), true)

    disabledContacts = {}
    pointerJoints = {}

    connect.resetConnectors()

    --connectorCooldownList = {}
    --connectors = {}
end

lib.resetLists = function()
    --connectors = {}
    connect.resetConnectors()
    pointerJoints = {}
end

lib.drawWorld = function(world)
    local r, g, b, a = love.graphics.getColor()
    local alpha = .8

    love.graphics.setColor(0, 0, 0, alpha)
    local bodies = world:getBodies()
    love.graphics.setLineWidth(10)
    for _, body in ipairs(bodies) do
        local fixtures = body:getFixtures()

        for _, fixture in ipairs(fixtures) do
            --if fixture:getUserData() then
            --     print(inspect(fixture:getUserData()))
            --end
            if fixture:getShape():type() == 'PolygonShape' then
                local color = getBodyColor(body)
                love.graphics.setColor(color[1], color[2], color[3], alpha)
                if (fixture:getUserData() ) then 
                if fixture:getUserData().bodyType == "connector" then 
                    love.graphics.setColor(1, 0, 0, alpha)
                end end
                love.graphics.polygon("fill", body:getWorldPoints(fixture:getShape():getPoints()))
                love.graphics.setColor(1, 1, 1, alpha)
                if (fixture:getUserData() ) then 
                    if fixture:getUserData().bodyType == "connector" then 
                        love.graphics.setColor(1, 0, 0, alpha)
                    end
                  --  print(inspect(fixture:getUserData() ))
                end
                love.graphics.polygon('line', body:getWorldPoints(fixture:getShape():getPoints()))
            elseif fixture:getShape():type() == 'EdgeShape' or fixture:getShape():type() == 'ChainShape' then
                love.graphics.setColor(1, 1, 1, alpha)
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
                love.graphics.setColor(1, 1, 1, alpha)
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
    love.graphics.setLineWidth(1)
end

lib.removeDeadPointerJoints = function()
    local index = -1
    for i = #pointerJoints, 1, -1 do
        if (pointerJoints[i].joint and pointerJoints[i].joint:isDestroyed()) then
            pointerJoints[i].joint     = nil
            pointerJoints[i].jointBody = nil
            table.remove(pointerJoints, i)
        end
    end
end


lib.handleUpdate = function(dt, cam)
    lib.removeDeadPointerJoints()
    -- connect connectors
    for i = 1, #pointerJoints do
        local mj = pointerJoints[i]
        if (mj.joint) then
            local mx, my = getPointerPosition(mj.id) --love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)
            mj.joint:setTarget(wx, wy)

            local fixtures = mj.jointBody:getFixtures()
            for k = 1, #fixtures do
                local f = fixtures[k]
                if f:getUserData() and f:getUserData().bodyType then
                    if f:getUserData().bodyType == 'connector' then
                        connect.maybeConnectThisConnector(f)
                        
                    end
                end
            end
        end
    end

    -- diconnect connectors
    connect.maybeBreakAnyConnectorBecauseForce(dt)

    connect.cleanupCoolDownList(dt)
   
end

lib.handlePointerReleased = function(x, y, id)
    for i = 1, #pointerJoints do
        local mj = pointerJoints[i]
        -- if false then
        if mj.id == id then
            if (mj.joint) then --- UNUSED
                if false then -- this is to shoot objects when you drag then below the groud (pim pam pet effect])
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
                    end
                end
            end
            --   end
        end
    end
    lib.killMouseJointIfPossible(id)
end

lib.handlePointerPressed = function(wx, wy, id, onPressedParams)
    -- local wx, wy = cam:getWorldCoordinates(x, y)
    local bodies = world:getBodies()
    local temp = {}
    for _, body in ipairs(bodies) do
        if body:getType() ~= 'kinematic' then
            local fixtures = body:getFixtures()
            for _, fixture in ipairs(fixtures) do
                local hitThisOne = fixture:testPoint(wx, wy)
                local isSensor = fixture:isSensor()

                -- something here needs to be parameterized.

                if (hitThisOne and not isSensor) then
                    table.insert(temp,
                        { id = id, body = body, wx = wx, wy = wy, prio = makePrio(fixture), fixture = fixture })

                    if onPressedParams then
                        if onPressedParams.onPressedFunc then
                            onPressedParams.onPressedFunc(body)
                        end
                    end
                end
            end
        end
    end
    if #temp > 0 then
        table.sort(temp, function(k1, k2) return k1.prio > k2.prio end)
        lib.killMouseJointIfPossible(id)
        local force = 100
        if onPressedParams and onPressedParams.pointerForceFunc then
            force = onPressedParams.pointerForceFunc(temp[1].fixture)
        end

        table.insert(pointerJoints, makePointerJoint(temp[1].id, temp[1].body, temp[1].wx, temp[1].wy, force))
    end
    -- print(#pointerJoints)
    if #temp == 0 then lib.killMouseJointIfPossible(id) end

    return #temp > 0
end



return lib

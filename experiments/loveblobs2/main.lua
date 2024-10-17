--[[
This is an example usage of the loveblobs library
use mouse 1 to grab objects
use mouse 2 to spawn softbodies
--]]

love.blobs = require "loveblobs"

local softbodies = {}
local mousejoint = nil

function love.load()
    -- init the physics world
    love.physics.setMeter(16)
    local texture = love.graphics.newImage("img.png")
    world = love.physics.newWorld(0, 9.81 * 16, true)

    -- make a floor out of a softsurface
    local points = {
        0, 500, 800, 500,
        800, 800, 0, 800
    }
    local b = love.blobs.softsurface(world, points, 64, "static")

    table.insert(softbodies, b)

    -- some random dynamic softsurface shape
    points = {
        400, 0, 550, 200,
        400, 300, 250, 200
    }


    b = love.blobs.softsurface(world, points, 16, "dynamic")
    table.insert(softbodies, b)

    -- a softbod

    local b = love.blobs.softbody(world, 400, -300, 102, 2, 4, nil, nil, texture)
    b:setFrequency(1)
    b:setDamping(0.1)
    b:setFriction(1)
    table.insert(softbodies, b)

    love.graphics.setBackgroundColor(255 / 255, 255 / 255, 255 / 255)
end

function love.update(dt)
    -- update the physics world
    for i = 1, 4 do
        world:update(dt)
    end

    --#region new functions added together with chatgpt
    -- 1) Simple to use impulses (rotate, push, etc.):
    if love.keyboard.isDown("up") then
        for i, v in ipairs(softbodies) do
            applyPushImpulse(v, 0, -50) -- push upwards
        end
    end
    -- Apply rotation to all softbodies if "r" key is pressed
    if love.keyboard.isDown("r") then
        for i, body in ipairs(softbodies) do
            applyRotationImpulse(body, -10) -- rotate clockwise
        end
    end
    -- 2)
    if love.keyboard.isDown("t") then
        for i, body in ipairs(softbodies) do
            --move(body, 500, 300)
            moveSmooth(body, 500, 300, .02)
        end
    end
    --#endregion

    local mx, my = love.mouse:getPosition()
    for i, v in ipairs(softbodies) do
        v:update(dt)

        local body = nil
        if tostring(v) == "softbody" then
            body = v.centerBody
        elseif tostring(v) == "softsurface" and v.phys then
            for i, v in ipairs(v.phys) do
                if math.dist(mx, my, v.body:getX(), v.body:getY()) < 16 and v.fixture:getUserData() == "softsurface" then
                    body = v.body
                end
            end
        end

        if body then
            if love.mouse.isDown(1) and math.dist(mx, my, body:getX(), body:getY()) < 128 then
                if mousejoint == nil then
                    mousejoint = physics.newMouseJoint(body, body:getPosition())
                    mousejoint:setMaxForce(50000)
                    mousejoint:setFrequency(5000)
                    mousejoint:setDampingRatio(1)
                end
            end
        end
    end

    if mousejoint then
        mousejoint:setTarget(mx, my)
    end

    if mousejoint ~= nil and not love.mouse.isDown(1) then
        mousejoint:destroy()
        mousejoint = nil
    end
end

function love.mousepressed(x, y, button)
    if button == 2 then
        local b = love.blobs.softbody(world, x, y, 102, 2, 4)
        b:setFrequency(1)
        b:setDamping(0.1)
        b:setFriction(1)

        table.insert(softbodies, b)
    end
end

function love.draw()
    for i, v in ipairs(softbodies) do
        love.graphics.setColor(50 * i / 255, 100 / 255, 200 * i / 255)
        if (tostring(v) == "softbody") then
            v:draw("fill", false)
        else
            v:draw(false)
        end
    end
end

--#region new functions added together with chatgpt
-- 1) Simple to use impulses (rotate, push, etc.):
-- PUSH
function applyPushImpulse(body, forceX, forceY)
    if body.nodes and #body.nodes > 0 then
        applyPushImpulseToSoftBody(body, forceX, forceY)
    end
    if body.phys and #body.phys > 0 then
        applyPushImpulseToSurface(body, forceX, forceY)
    end
end

function applyPushImpulseToSoftBody(body, forceX, forceY)
    if body.nodes and #body.nodes > 0 then
        for i, node in ipairs(body.nodes) do
            node.body:applyLinearImpulse(forceX, forceY)
        end
    end
end

function applyPushImpulseToSurface(surface, forceX, forceY)
    if surface.phys and #surface.phys > 0 then
        for i, physObj in ipairs(surface.phys) do
            physObj.body:applyLinearImpulse(forceX, forceY)
        end
    end
end

-- ROTATE
function applyRotationImpulse(body, torque)
    if body.centerBody then
        applyRotationImpulseToSoftBody(body, torque)
    end
    if body.phys and #body.phys > 0 then
        applyRotationImpulseToSurface(body, torque)
    end
end

function applyRotationImpulseToSoftBody(body, torque)
    if body.centerBody then
        body.centerBody:applyTorque(torque * 20)
    end
end

function applyRotationImpulseToSurface(surface, torque)
    if surface.phys and #surface.phys > 0 then
        -- Calculate the center of the surface
        local centerX, centerY = 0, 0
        for i, physObj in ipairs(surface.phys) do
            centerX = centerX + physObj.body:getX()
            centerY = centerY + physObj.body:getY()
        end
        centerX = centerX / #surface.phys
        centerY = centerY / #surface.phys

        -- Apply torque by pushing bodies at the edges in opposite directions
        for i, physObj in ipairs(surface.phys) do
            local body = physObj.body
            local bodyX, bodyY = body:getPosition()

            -- Calculate the vector from the center to the body
            local dx, dy = bodyX - centerX, bodyY - centerY
            local distance = math.sqrt(dx * dx + dy * dy)

            -- Apply force proportional to the torque
            local forceX = -dy / distance * torque
            local forceY = dx / distance * torque
            body:applyLinearImpulse(forceX, forceY)
        end
    end
end

-- 2) Move Softbody Function
function move(body, newX, newY)
    if body.centerBody then
        moveSoftbody(body, newX, newY)
    end
    if body.phys and #body.phys > 0 then
        moveSoftsurface(body, newX, newY)
    end
end

function moveSoftbody(body, newX, newY)
    if body.centerBody then
        -- Move the center body
        local oldX, oldY = body.centerBody:getPosition()
        body.centerBody:setPosition(newX, newY)

        -- Calculate the offset
        local offsetX = newX - oldX
        local offsetY = newY - oldY

        -- Move all the nodes relative to the new center position
        for i, node in ipairs(body.nodes) do
            local nodeX, nodeY = node.body:getPosition()
            node.body:setPosition(nodeX + offsetX, nodeY + offsetY)
        end
    end
end

function moveSoftsurface(surface, newX, newY)
    if surface.phys and #surface.phys > 0 then
        -- Calculate the current center of the surface
        local centerX, centerY = 0, 0
        for i, physObj in ipairs(surface.phys) do
            centerX = centerX + physObj.body:getX()
            centerY = centerY + physObj.body:getY()
        end
        centerX = centerX / #surface.phys
        centerY = centerY / #surface.phys

        -- Calculate the offset
        local offsetX = newX - centerX
        local offsetY = newY - centerY

        -- Move each body by the offset
        for i, physObj in ipairs(surface.phys) do
            local bodyX, bodyY = physObj.body:getPosition()
            physObj.body:setPosition(bodyX + offsetX, bodyY + offsetY)
        end
    end
end

-- 2b
function moveSmooth(body, targetX, targetY, speed)
    if body.centerBody then
        smoothMoveSoftbody(body, targetX, targetY, speed)
    end
    if body.phys and #body.phys > 0 then
        smoothMoveSoftsurface(body, targetX, targetY, speed)
    end
end

function smoothMoveSoftbody(body, targetX, targetY, speed)
    if body.centerBody then
        local oldX, oldY = body.centerBody:getPosition()
        local newX = oldX + (targetX - oldX) * speed
        local newY = oldY + (targetY - oldY) * speed

        moveSoftbody(body, newX, newY)
    end
end

function smoothMoveSoftsurface(surface, targetX, targetY, speed)
    if surface.phys and #surface.phys > 0 then
        -- Calculate the current center of the surface
        local centerX, centerY = 0, 0
        for i, physObj in ipairs(surface.phys) do
            centerX = centerX + physObj.body:getX()
            centerY = centerY + physObj.body:getY()
        end
        centerX = centerX / #surface.phys
        centerY = centerY / #surface.phys

        -- Smoothly move towards the target
        local newX = centerX + (targetX - centerX) * speed
        local newY = centerY + (targetY - centerY) * speed

        moveSoftsurface(surface, newX, newY)
    end
end

--#endregion

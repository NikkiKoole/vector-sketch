local lib = {}

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

local function getEndpoint(x, y, angle, length)
    local endX = x + length * math.cos(angle)
    local endY = y + length * math.sin(angle)
    return endX, endY
end

function lib.drawWorld(world)
    local r, g, b, a = love.graphics.getColor()
    local alpha = .8
    love.graphics.setLineJoin("none")
    love.graphics.setColor(0, 0, 0, alpha)
    local bodies = world:getBodies()
    -- love.graphics.setLineWidth(1)
    for _, body in ipairs(bodies) do
        local fixtures = body:getFixtures()

        for _, fixture in ipairs(fixtures) do
            --if fixture:getUserData() then
            --     print(inspect(fixture:getUserData()))
            --end
            if fixture:getShape():type() == 'PolygonShape' then
                local color = getBodyColor(body)
                love.graphics.setColor(color[1], color[2], color[3], alpha)
                if (fixture:getUserData()) then
                    if fixture:getUserData().bodyType == "connector" then
                        love.graphics.setColor(1, 0, 0, alpha)
                    end
                end
                love.graphics.polygon("fill", body:getWorldPoints(fixture:getShape():getPoints()))
                love.graphics.setColor(1, 1, 1, alpha)
                if (fixture:getUserData()) then
                    if fixture:getUserData().bodyType == "connector" then
                        love.graphics.setColor(1, 0, 0, alpha)
                    end
                    --  print(inspect(fixture:getUserData() ))
                end
                love.graphics.polygon('line', body:getWorldPoints(fixture:getShape():getPoints()))
            elseif fixture:getShape():type() == 'EdgeShape' or fixture:getShape():type() == 'ChainShape' then
                love.graphics.setColor(0, 1, 1, alpha)
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

    local joints = world:getJoints()
    for _, joint in ipairs(joints) do
        local x1, y1, x2, y2 = joint:getAnchors()

        if (x1 and y1 and x2 and y2) then
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.line(x1, y1, x2, y2)
        end
        love.graphics.setColor(1, 0, 0, alpha)
        love.graphics.setLineJoin("miter")
        if x1 and y1 then love.graphics.circle('line', x1, y1, 4) end
        if x2 and y2 then love.graphics.circle('line', x2, y2, 4) end
        love.graphics.setLineJoin("none")

        local jointType = joint:getType()
        if jointType == 'pulley' then
            local gx1, gy1, gx2, gy2 = joint:getGroundAnchors()
            love.graphics.setColor(1, 1, 0, alpha)
            love.graphics.line(x1, y1, gx1, gy1)
            love.graphics.line(x2, y2, gx2, gy2)
            love.graphics.line(gx1, gy1, gx2, gy2)
        end
        if jointType == 'prismatic' then
            local x, y = joint:getAnchors()
            local ax, ay = joint:getAxis()
            local length = 50
            love.graphics.setColor(1, 0.5, 0) -- Orange
            love.graphics.line(x, y, x + ax * length, y + ay * length)
            if joint:areLimitsEnabled() then
                local lower, upper = joint:getLimits()
                love.graphics.setColor(1, 1, 0) -- Yellow
                love.graphics.line(x + ax * lower, y + ay * lower, x + ax * lower + ax * 10, y + ay * lower + ay * 10)
                love.graphics.line(x + ax * upper, y + ay * upper, x + ax * upper + ax * 10, y + ay * upper + ay * 10)
            end
            love.graphics.setColor(1, 1, 1) -- Reset
        end
        if jointType == 'revolute' then
            if joint:areLimitsEnabled() then
                local lower = joint:getLowerLimit()
                local upper = joint:getUpperLimit()

                local bodyA, bodyB = joint:getBodies()
                local b1A = bodyA:getAngle()

                love.graphics.setColor(1, 1, 1, alpha)
                love.graphics.setLineJoin("miter")
                love.graphics.arc('line', x1, y1, 15, math.pi / 2 + b1A + lower, math.pi / 2 + b1A + upper)
                love.graphics.setLineJoin("none")


                local b1B = bodyB:getAngle()

                local angleBetween = b1A - b1B

                local endX, endY = getEndpoint(x1, y1, (b1B + math.pi / 2), 15)

                love.graphics.setColor(0.5, 0.5, 0.5, alpha)
                love.graphics.line(x1, y1, endX, endY)
            end
        end
        if jointType == 'wheel' then
            -- Draw wheel joint axis
            local axisX, axisY = joint:getAxis()
            if x1 and y1 and axisX and axisY then
                local axisLength = 50                   -- Scale factor for visualizing the axis
                love.graphics.setColor(0, .5, 0, alpha) -- Green for axis
                love.graphics.line(x1, y1, x1 + axisX * axisLength, y1 + axisY * axisLength)
                love.graphics.setColor(1, 1, 1, alpha)
            end
        end
    end
    love.graphics.setLineJoin("miter")
    love.graphics.setColor(r, g, b, a)
    --   love.graphics.setLineWidth(1)
end

function lib.drawBodies(bodies)
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(6)
    love.graphics.setColor(1, 0, 1) -- Red outline for selection
    for i = 1, #bodies do
        --for _, thing in ipairs(uiState.selectedBodies) do
        --local fixtures = body:getFixtures()
        local body = bodies[i]
        for _, fixture in ipairs(body:getFixtures()) do
            --for fixture in pairs(fixtures) do
            local shape = fixture:getShape()
            love.graphics.push()
            love.graphics.translate(body:getX(), body:getY())
            love.graphics.rotate(body:getAngle())
            if shape:typeOf("CircleShape") then
                love.graphics.circle("line", 0, 0, shape:getRadius())
            elseif shape:typeOf("PolygonShape") then
                local points = { shape:getPoints() }
                love.graphics.polygon("line", points)
            elseif shape:typeOf("EdgeShape") then
                local x1, y1, x2, y2 = shape:getPoints()
                love.graphics.line(x1, y1, x2, y2)
            end
            love.graphics.pop()
        end
    end
    love.graphics.setLineWidth(lw)
    love.graphics.setColor(1, 1, 1) -- Reset color
end

return lib

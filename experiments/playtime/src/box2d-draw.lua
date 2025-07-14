--box2d-draw.lua

local lib = {}

local state = require 'src.state'
local pal = {
    ['orange']  = { 242 / 255, 133 / 255, 0 },         --#F28500  tangerine orange
    ['sun']     = { 253 / 255, 215 / 255, 4 / 255 },   --#FFD700  sunshine yellow
    ['rust']    = { 183 / 255, 64 / 255, 13 / 255 },   --#b7410e  rust otange
    ['avocado'] = { 106 / 255, 144 / 255, 32 / 255 },  --#568203  avocado graan
    ['gold']    = { 219 / 255, 145 / 255, 0 },         --#da9100  harvest gold
    ['lime']    = { 69 / 255, 205 / 255, 50 / 255 },   --#32CD32  lime green
    ['creamy']  = { 245 / 255, 245 / 255, 220 / 255 }, --#F5F5DC Creamy White:
    ['dark']    = { 50 / 255, 30 / 255, 30 / 255 },    -- dark
    ['choco']   = { 123 / 255, 64 / 255, 0 },          --#7B3F00 Chocolate Brown:
    ['beige']   = { 244 / 255, 164 / 255, 97 / 255 },  --#F4A460 Sand Beige:
    ['red']     = { 217 / 255, 73 / 255, 56 / 255 },   --#D94A38 Adobe Red:
}

local function getBodyColor(body)
    if body:getType() == 'kinematic' then
        return pal.red
    end
    if body:getType() == 'dynamic' then
        return pal.lime
    end
    if body:getType() == 'static' then
        return pal.sun
    end
end

local function getEndpoint(x, y, angle, length)
    local endX = x + length * math.cos(angle)
    local endY = y + length * math.sin(angle)
    return endX, endY
end



function lib.drawWorld(world, drawOutline)
    if drawOutline == nil then drawOutline = true end
    if drawOutline == true then
        if state.world.drawOutline == false then
            drawOutline = false
        end
    end
    local r, g, b, a = love.graphics.getColor()
    local alpha = .8 * state.world.debugAlpha
    love.graphics.setLineJoin("none")
    love.graphics.setColor(0, 0, 0, alpha)
    local bodies = world:getBodies()
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
                    if fixture:getUserData().type then
                        local color = pal.orange
                        love.graphics.setColor(color[1], color[2], color[3], alpha)
                    end
                    --else
                    if state.world.drawFixtures then
                        love.graphics.polygon("fill", body:getWorldPoints(fixture:getShape():getPoints()))
                    end
                else
                    love.graphics.polygon("fill", body:getWorldPoints(fixture:getShape():getPoints()))
                end


                local color = state.world.darkMode and pal.creamy or pal.dark
                love.graphics.setColor(color[1], color[2], color[3], alpha)
                if (fixture:getUserData()) then
                    if fixture:getUserData().bodyType == "connector" then
                        love.graphics.setColor(1, 0, 0, alpha)
                    end
                    --  print(inspect(fixture:getUserData() ))
                end
                if drawOutline then love.graphics.polygon('line', body:getWorldPoints(fixture:getShape():getPoints())) end
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
                local segments = 180
                love.graphics.setColor(color[1], color[2], color[3], alpha)
                love.graphics.circle('fill', body_x + shape_x, body_y + shape_y, r, segments)

                local color = pal.creamy
                love.graphics.setColor(color[1], color[2], color[3], alpha)
                if drawOutline then love.graphics.circle('line', body_x + shape_x, body_y + shape_y, r, segments) end
            end
        end
    end
    love.graphics.setColor(255, 255, 255, alpha)
    -- Joint debug

    local joints = world:getJoints()
    for _, joint in ipairs(joints) do
        local x1, y1, x2, y2 = joint:getAnchors()

        if (x1 and y1 and x2 and y2) then
            local color = pal.creamy
            love.graphics.setColor(color[1], color[2], color[3], alpha)
            love.graphics.line(x1, y1, x2, y2)
        end
        local color = pal.orange
        love.graphics.setColor(color[1], color[2], color[3], alpha)

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
        if jointType == 'revolute' and joint:areLimitsEnabled() then
            local lower = joint:getLowerLimit()
            local upper = joint:getUpperLimit()
            local referenceAngle = joint:getReferenceAngle()

            local bodyA, bodyB = joint:getBodies()
            local angleA = bodyA:getAngle()
            local angleB = bodyB:getAngle()

            -- Use the joint's reference frame to compute world-space zero angle
            local zeroAngle = angleA + referenceAngle

            local startAngle = zeroAngle + lower
            local endAngle = zeroAngle + upper
            if endAngle < startAngle then
                endAngle = endAngle + 2 * math.pi
            end

            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.setLineJoin("miter")
            love.graphics.arc('line', x1, y1, 15, startAngle, endAngle)
            love.graphics.setLineJoin("none")

            -- draw current angle of bodyB relative to bodyA (via reference frame)
            local currentRelative = angleB - zeroAngle
            local dirAngle = zeroAngle + currentRelative
            local endX, endY = getEndpoint(x1, y1, dirAngle, 15)
            love.graphics.setColor(0.5, 0.5, 0.5, alpha)
            love.graphics.line(x1, y1, endX, endY)
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

function lib.drawJointAnchors(joint)
    local color = pal.creamy
    love.graphics.setColor(color[1], color[2], color[3], 1)
    local x1, y1, x2, y2 = joint:getAnchors()
    love.graphics.circle('line', x1, y1, 10)
    love.graphics.line(x2 - 10, y2, x2 + 10, y2)
    love.graphics.line(x2, y2 - 10, x2, y2 + 10)
end

function lib.drawBodies(bodies)
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(6)
    love.graphics.setColor(1, 0, 1) -- Red outline for selection
    for i = 1, #bodies do
        --for _, thing in ipairs(state.selection.selectedBodies) do
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

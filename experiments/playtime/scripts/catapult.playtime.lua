local s = {}

function s.onStart()
    cup = getObjectsByLabel('catapult-cup')[1]
    base = getObjectsByLabel('catapult-frame')[1]
    frictionJoint = nil
    local joints = cup.body:getJoints()
    for i = 1, #joints do
        if joints[i]:getType() == 'friction' then
            frictionJoint = joints[i]
        end
    end
    reactionForce = {}
    isHoldingCup = false
end

function s.update(dt)
    --print(isHoldingCup)
    local rfx, rfy = frictionJoint:getReactionForce(1 / dt)
    local rt = frictionJoint:getReactionTorque(1 / dt)
    reactionForce = { rfx, rfy, rt }
end

function s.draw()
    if (isHoldingCup) then
        love.graphics.circle('fill', 100, 100, 50)
        love.graphics.print(string.format("(%.2f, %.2f, %.2f)", reactionForce[1], reactionForce[2], reactionForce[3]),
            100, 0)
    end

    local mx, my = mouseWorldPos()
    love.graphics.setColor(1, 0, 1, .5)
    love.graphics.circle('fill', mx, my, 20)

    local bx, by = base.body:getPosition()
    love.graphics.line(mx, my, bx, by)
    love.graphics.setColor(1, 0, 0, 1)
end

function s.onPressed(objs)
    for i = 1, #objs do
        if objs[i] == cup then
            isHoldingCup = true
        end
    end
end

function s.onReleased(objs)
    for i = 1, #objs do
        if objs[i] == cup then
            isHoldingCup = false
        end
    end
end

return s

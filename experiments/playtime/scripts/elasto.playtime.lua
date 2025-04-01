local s = {}

local freq = 5.0
local damp = 0.3
local linkdensity = 10
local count = 20
local length = 200

function createElasticChain(startNode, endNode, linkCount, length)
    local links = {}
    local prev = startNode
    local x, y = startNode:getX(), startNode:getY()

    for i = 1, linkCount do
        local link = love.physics.newBody(state.physicsWorld, x + i * length / (linkCount + 1), y, "dynamic")
        local shape = love.physics.newRectangleShape(10, 10)
        love.physics.newFixture(link, shape, linkdensity)

        if prev then
            local joint = love.physics.newDistanceJoint(prev, link, prev:getX(), prev:getY(), link:getX(), link:getY())
            joint:setLength(math.sqrt((link:getX() - prev:getX()) ^ 2 + (link:getY() - prev:getY()) ^ 2))
            joint:setDampingRatio(damp)
            joint:setFrequency(freq)
            table.insert(links, { body = link, joint = joint })
        end

        prev = link
    end

    if endNode then
        endNode:setPosition(prev:getX() + length / (linkCount + 1), prev:getY())
        local joint = love.physics.newDistanceJoint(prev, endNode, prev:getX(), prev:getY(), endNode:getX(),
            endNode:getY())
        joint:setLength(length / linkCount)
        joint:setDampingRatio(damp)
        joint:setFrequency(freq)
        table.insert(links, { body = endNode, joint = joint })
    end

    return links
end

function s.onStart()
    elastoStart = getObjectsByLabel('elasto-start')[1]
    elastoEnd = getObjectsByLabel('elasto-end')[1]
    local start = elastoStart.body
    local eind = elastoEnd.body

    links = createElasticChain(start, eind, count, length)
end

return s

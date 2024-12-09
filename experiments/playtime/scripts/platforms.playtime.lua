local s = {}


local function removeConsecutiveDuplicates(vertices)
    local result = {}

    for i = 1, #vertices, 2 do
        local x, y = vertices[i], vertices[i + 1]

        -- Add the first vertex or if it is different from the last in the result
        if #result == 0 or result[#result - 1] ~= x or result[#result] ~= y then
            table.insert(result, x)
            table.insert(result, y)
        end
    end

    return result
end

local function generateChainShapesFromPolygonWithNormals(polygon, yOffset)
    local function calculateNormal(x1, y1, x2, y2)
        -- Compute the normal vector
        local dx, dy = x2 - x1, y2 - y1
        local length = math.sqrt(dx ^ 2 + dy ^ 2)
        return -dy / length, dx / length -- Perpendicular vector (dx, -dy rotated 90 degrees CCW)
    end

    local bottomChains = {}
    local topChains = {}

    local currentBottomChain = {}
    local currentTopChain = {}

    local numVertices = #polygon

    for i = 1, numVertices - 2, 2 do
        local x1, y1 = polygon[i], polygon[i + 1]
        local x2, y2 = polygon[i + 2], polygon[i + 3]

        -- Compute the normal vector
        local nx, ny = calculateNormal(x1, y1, x2, y2)

        if ny > 0 then
            -- This is a bottom edge, offset the vertices downward
            currentBottomChain[#currentBottomChain + 1] = x1
            currentBottomChain[#currentBottomChain + 1] = y1 + yOffset
            currentBottomChain[#currentBottomChain + 1] = x2
            currentBottomChain[#currentBottomChain + 1] = y2 + yOffset
            -- Finalize top chain if transitioning from a top edge
            if #currentTopChain > 0 then
                table.insert(topChains, currentTopChain)
                currentTopChain = {}
            end
        else
            -- This is a top edge, offset the vertices upward
            currentTopChain[#currentTopChain + 1] = x1
            currentTopChain[#currentTopChain + 1] = y1 -- yOffset
            currentTopChain[#currentTopChain + 1] = x2
            currentTopChain[#currentTopChain + 1] = y2 -- yOffset
            -- Finalize bottom chain if transitioning from a bottom edge
            if #currentBottomChain > 0 then
                table.insert(bottomChains, currentBottomChain)
                currentBottomChain = {}
            end
        end
    end

    -- Handle the closing edge (last vertex to first vertex)
    local x1, y1 = polygon[numVertices - 1], polygon[numVertices]
    local x2, y2 = polygon[1], polygon[2]
    local nx, ny = calculateNormal(x1, y1, x2, y2)

    if ny > 0 then
        currentBottomChain[#currentBottomChain + 1] = x1
        currentBottomChain[#currentBottomChain + 1] = y1 + yOffset
        currentBottomChain[#currentBottomChain + 1] = x2
        currentBottomChain[#currentBottomChain + 1] = y2 + yOffset
        if #currentTopChain > 0 then
            table.insert(topChains, currentTopChain)
            currentTopChain = {}
        end
    else
        currentTopChain[#currentTopChain + 1] = x1
        currentTopChain[#currentTopChain + 1] = y1 -- yOffset
        currentTopChain[#currentTopChain + 1] = x2
        currentTopChain[#currentTopChain + 1] = y2 -- yOffset
        if #currentBottomChain > 0 then
            table.insert(bottomChains, currentBottomChain)
            currentBottomChain = {}
        end
    end

    -- Finalize any remaining chains
    if #currentBottomChain > 0 then
        table.insert(bottomChains, currentBottomChain)
    end
    if #currentTopChain > 0 then
        table.insert(topChains, currentTopChain)
    end

    return bottomChains, topChains
end

function s.onStart()
    platform = getObjectsByLabel('platform')[1]
    local lverts = mathutils.localVerts(platform)
    bottomchains, topchains = generateChainShapesFromPolygonWithNormals(lverts, 1)

    for i = 1, #bottomchains do
        local body = love.physics.newBody(world, 0, 0)
        local shape = love.physics.newChainShape(false, unpack(removeConsecutiveDuplicates(bottomchains[i])))
        local fixture = love.physics.newFixture(body, shape)
        fixture:setSensor(true)
        body:setUserData({ permission = 'true' })
    end

    for i = 1, #topchains do
        local body = love.physics.newBody(world, 0, 0)
        local shape = love.physics.newChainShape(false, unpack(removeConsecutiveDuplicates(topchains[i])))
        local fixture = love.physics.newFixture(body, shape)
        fixture:setSensor(true)
        body:setUserData({ permission = 'false' })
    end

    isAllowedToPass = false
end

function s.draw()
    love.graphics.setColor(1, 0, 0)

    for j = 1, #bottomchains do
        local chainverts = bottomchains[j]
        for i = 1, #chainverts / 4 do
            local index = (i - 1) * 4
            local c = chainverts
            love.graphics.line(c[index + 1], c[index + 2], c[index + 3], c[index + 4])
        end
    end

    love.graphics.setColor(1, 1, 0)
    for j = 1, #topchains do
        local chainverts = topchains[j]
        for i = 1, #chainverts / 4 do
            local index = (i - 1) * 4
            local c = chainverts
            love.graphics.line(c[index + 1], c[index + 2], c[index + 3], c[index + 4])
        end
    end
    love.graphics.setColor(1, 1, 1)
end

function s.preSolve(a, b, contact)
    if (a:getBody() == platform.body) then
        if isAllowedToPass then
            contact:setEnabled(false)
        else
            contact:setEnabled(true)
        end
    end
    if (b:getBody() == platform.body) then
        if isAllowedToPass then
            contact:setEnabled(false)
        else
            contact:setEnabled(true)
        end
    end
end

function s.beginContact(a, b, contact)
    if a:getBody():getUserData() and a:getBody():getUserData().permission == 'true' then
        isAllowedToPass = true
    end
    if b:getBody():getUserData() and b:getBody():getUserData().permission == 'true' then
        isAllowedToPass = true
    end
end

function s.endContact(a, b)
    if a:getBody():getUserData() and a:getBody():getUserData().permission == 'false' then
        isAllowedToPass = false
    end
    if a:getBody():getUserData() and a:getBody():getUserData().permission == 'false' then
        isAllowedToPass = false
    end
end

return s

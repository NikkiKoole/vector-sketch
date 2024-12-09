local s = {}

function s.onStart()
    platform = getObjectsByLabel('platform')[1]

    local lverts = mathutils.localVerts(platform)

    chains = generateBottomChainShapesFromPolygonWithNormals(lverts, 20)

    --print(#chains, #topchains)
    for i = 1, #chains do
        local body = love.physics.newBody(world, 0, 0)
        local shape = love.physics.newChainShape(false, unpack(removeConsecutiveDuplicates(chains[i])))
        local fixture = love.physics.newFixture(body, shape)
        fixture:setSensor(true)
        body:setUserData({ permission = true })
    end

    isAllowedToPass = false
end

function removeConsecutiveDuplicates(vertices)
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

function s.draw()
    love.graphics.setColor(1, 0, 0)

    for j = 1, #chains do
        local chainverts = chains[j]
        for i = 1, #chainverts / 4 do
            local index = (i - 1) * 4
            local c = chainverts
            love.graphics.line(c[index + 1], c[index + 2], c[index + 3], c[index + 4])
        end
    end

    love.graphics.setColor(1, 1, 0)
    -- for j = 1, #topchains do
    --     local chainverts = topchains[j]
    --     for i = 1, #chainverts / 4 do
    --         local index = (i - 1) * 4
    --         local c = chainverts
    --         love.graphics.line(c[index + 1], c[index + 2], c[index + 3], c[index + 4])
    --     end
    -- end
    love.graphics.setColor(1, 1, 1)
end

function s.preSolve(a, b, contact)
    --  print(a:getBody(), b:getBody())


    if (a:getBody() == platform.body) then
        if isAllowedToPass then
            -- print(inspect(platform), a:getBody():getUserData().thing)
            contact:setEnabled(false)
            --print('setting enabled false')
        else
            contact:setEnabled(true)
        end
    end
    if (b:getBody() == platform.body) then
        if isAllowedToPass then
            -- print('setting enabled false')
            contact:setEnabled(false)
            -- print('now we have permission anymore to move through the platform')
        else
            contact:setEnabled(true)
        end
    end
end

function s.postSolve(a, b, contact)

end

function s.beginContact(a, b, contact)
    if a:getBody():getUserData() and a:getBody():getUserData().permission then
        print('now we habve permission to move through the platform')
        isAllowedToPass = true
    end
    if b:getBody():getUserData() and b:getBody():getUserData().permission then
        print('now we habve permission to move through the platform')
        isAllowedToPass = true
    end
end

function s.endContact(a, b, col)
    if a:getBody():getUserData() and a:getBody():getUserData().permission then
        print('now we dont have permission anymore to move through the platform')

        isAllowedToPass = false
    end
    if a:getBody():getUserData() and a:getBody():getUserData().permission then
        print('now we dont have permission anymore to move through the platform')

        isAllowedToPass = false
    end
end

function generateBottomChainShapesFromPolygonWithNormals(polygon, yOffset)
    local function calculateNormal(x1, y1, x2, y2)
        -- Compute the normal vector
        local dx, dy = x2 - x1, y2 - y1
        local length = math.sqrt(dx ^ 2 + dy ^ 2)
        return -dy / length, dx / length -- Perpendicular vector (dx, -dy rotated 90 degrees CCW)
    end

    local chains = {}
    local currentChain = {}

    for i = 1, #polygon - 2, 2 do
        local x1, y1 = polygon[i], polygon[i + 1]
        local x2, y2 = polygon[i + 2], polygon[i + 3]

        -- Compute the normal vector
        local nx, ny = calculateNormal(x1, y1, x2, y2)

        -- Check if this edge is facing downward (positive y in Love2D)
        if ny > 0 then
            -- This is a bottom edge, offset the vertices downward
            currentChain[#currentChain + 1] = x1
            currentChain[#currentChain + 1] = y1 + yOffset
            currentChain[#currentChain + 1] = x2
            currentChain[#currentChain + 1] = y2 + yOffset
        else
            -- If not a bottom edge, finalize the current chain (if any)
            if #currentChain > 0 then
                table.insert(chains, currentChain)
                currentChain = {}
            end
        end
    end

    -- Finalize the last chain if there are remaining edges
    if #currentChain > 0 then
        table.insert(chains, currentChain)
    end

    return chains
end

return s

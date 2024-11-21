-- Function to generate vertices of a regular polygon
local decompose = require 'src.decompose'
local shapes = {}

local function makePolygonVertices(sides, radius)
    local vertices = {}
    local angleStep = (2 * math.pi) / sides
    local rotationOffset = math.pi / 2 -- Rotate so one vertex is at the top
    for i = 0, sides - 1 do
        local angle = i * angleStep - rotationOffset
        local x = radius * math.cos(angle)
        local y = radius * math.sin(angle)
        table.insert(vertices, x)
        table.insert(vertices, y)
    end
    return vertices
end

local function capsuleXY(w, h, cs, x, y)
    -- cs == cornerSize
    local w2 = w / 2
    local h2 = h / 2

    local bt = -h2 + cs
    local bb = h2 - cs
    local bl = -w2 + cs
    local br = w2 - cs

    return {
        x - w2, y + bt,
        x + bl, y - h2,
        x + br, y - h2,
        x + w2, y + bt,
        x + w2, y + bb,
        x + br, y + h2,
        x + bl, y + h2,
        x - w2, y + bb
    }
end

local function makeTrapezium(w, w2, h, x, y)
    return {
        x - w / 2, y - h / 2,
        x + w / 2, y - h / 2,
        x + w2 / 2, y + h / 2,
        x - w2 / 2, y + h / 2
    }
end

local function makeITriangle(w, h, x, y)
    return {
        x - w / 2, y + h / 2,
        x + w / 2, y + h / 2,
        x, y - h / 2
    }
end

function shapes.createShape(shapeType, radius, width, height)
    if (radius == 0) then radius = 1 end
    if (width == 0) then width = 1 end
    if (height == 0) then height = 1 end
    if shapeType == 'circle' then
        return love.physics.newCircleShape(radius)
    elseif shapeType == 'rectangle' then
        return love.physics.newRectangleShape(width, height)
    elseif shapeType == 'capsule' then
        local vertices = capsuleXY(width, height, width / 5, 0, 0)
        return love.physics.newPolygonShape(vertices), vertices
    elseif shapeType == 'trapezium' then
        local vertices = makeTrapezium(width, width * 1.2, height, 0, 0)
        return love.physics.newPolygonShape(vertices), vertices
    elseif shapeType == 'itriangle' then
        local vertices = makeITriangle(width, height, 0, 0)
        return love.physics.newPolygonShape(vertices), vertices
    else
        local sides = ({
            triangle = 3,
            pentagon = 5,
            hexagon = 6,
            heptagon = 7,
            octagon = 8,
        })[shapeType]

        if sides then
            local vertices = makePolygonVertices(sides, radius)
            return love.physics.newPolygonShape(vertices), vertices
        else
            error("Unknown shape type: " .. tostring(shapeType))
        end
    end
end

local function tableConcat(t1, t2)
    for i = 1, #t2 do
        table.insert(t1, t2[i])
    end
    return t1
end

function shapes.createPolygonShapeUNSAFE(vertices)
    -- Convert vertices to a format suitable for love.math.triangulate()

    local polygon = {}
    for _, vertex in ipairs(vertices) do
        table.insert(polygon, vertex.x)
        table.insert(polygon, vertex.y)
    end

    local allowComplex = true -- todo parametrize this
    local triangles

    if allowComplex then
        local result = {}
        decompose.decompose_complex_poly(polygon, result)
        triangles = {}
        for i = 1, #result do
            local tris = love.math.triangulate(result[i])
            tableConcat(triangles, tris)
        end
    else
        triangles = love.math.triangulate(polygon)
    end
    if #triangles == 0 then
        print("Failed to triangulate polygon.")
        return
    end

    -- Create the physics body
    local bodyType = 'dynamic'
    -- Compute centroid for body position
    local centroidX, centroidY = computeCentroid(vertices)
    local body = love.physics.newBody(world, centroidX, centroidY, bodyType)

    -- Create fixtures for each triangle
    for _, triangle in ipairs(triangles) do
        -- Adjust triangle vertices relative to body position
        local localVertices = {}
        for i = 1, #triangle, 2 do
            local x = triangle[i] - centroidX
            local y = triangle[i + 1] - centroidY
            table.insert(localVertices, x)
            table.insert(localVertices, y)
        end
        local shape = love.physics.newPolygonShape(localVertices)
        local fixture = love.physics.newFixture(body, shape, 1)
        fixture:setRestitution(0.3)
    end

    -- Store the body in your simulation
    body:setUserData({ thing = { id = generateID(), shapeType = 'custom', body = body } })
end

function shapes.createPolygonShape(vertices)
    -- Convert vertices to a format suitable for love.math.triangulate()
    local polygon = {}
    for _, vertex in ipairs(vertices) do
        table.insert(polygon, vertex.x)
        table.insert(polygon, vertex.y)
    end

    local allowComplex = true -- TODO: parameterize this
    local triangles = {}

    if allowComplex then
        local result = {}
        local success, err = pcall(function()
            decompose.decompose_complex_poly(polygon, result)
        end)

        if not success then
            print("Error in decompose_complex_poly: " .. err)
            return nil -- Exit early if decomposition fails
        end

        for i = 1, #result do
            local success, tris = pcall(love.math.triangulate, result[i])
            if success then
                tableConcat(triangles, tris)
            else
                print("Failed to triangulate part of the polygon: " .. tris)
            end
        end
    else
        local success, result = pcall(love.math.triangulate, polygon)
        if success then
            triangles = result
        else
            print("Failed to triangulate polygon: " .. result)
            return nil -- Exit early if triangulation fails
        end
    end

    if #triangles == 0 then
        print("No valid triangles were created.")
        return nil
    end

    -- Create the physics body
    local bodyType = 'dynamic'
    -- Compute centroid for body position
    local centroidX, centroidY = computeCentroid(vertices)
    local body = love.physics.newBody(world, centroidX, centroidY, bodyType)

    -- Create fixtures for each triangle
    for _, triangle in ipairs(triangles) do
        -- Adjust triangle vertices relative to body position
        local localVertices = {}
        for i = 1, #triangle, 2 do
            local x = triangle[i] - centroidX
            local y = triangle[i + 1] - centroidY
            table.insert(localVertices, x)
            table.insert(localVertices, y)
        end

        local shapeSuccess, shape = pcall(love.physics.newPolygonShape, localVertices)
        if shapeSuccess then
            local fixture = love.physics.newFixture(body, shape, 1)
            fixture:setRestitution(0.3)
        else
            print("Failed to create shape for triangle: " .. shape)
        end
    end

    -- Store the body in your simulation
    body:setUserData({ thing = { id = generateID(), shapeType = 'custom', body = body } })
    return body
end

function computeCentroid(vertices)
    local sumX, sumY = 0, 0
    for _, vertex in ipairs(vertices) do
        sumX = sumX + vertex.x
        sumY = sumY + vertex.y
    end
    local count = #vertices
    return sumX / count, sumY / count
end

return shapes

-- shapes.lua

local mathutils = require 'src.math-utils'
local utils = require 'src.utils'
local inspect = require 'vendor.inspect'
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

local function capsuleXY(w, h, csw, x, y)
    -- cs == cornerSize
    local w2 = w / 2
    local h2 = h / 2

    local bt = -h2 + csw --* 2
    local bb = h2 - csw  --* 2
    local bl = -w2 + csw
    local br = w2 - csw

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

local function torso(w1, w2, w3, h1, h2, h3, h4, x, y)
    return {
        x, y - h1 - h2,
        x + w1 / 2, y - h2,
        x + w2 / 2, y,
        x + w3 / 2, y + h3,
        x, y + h3 + h4,
        x - w3 / 2, y + h3,
        x - w2 / 2, y,
        x - w1 / 2, y - h2,
    }
end


local function approximateCircle(radius, centerX, centerY, segments)
    segments = segments or 32 -- Default to 32 segments if not specified
    local vertices = {}
    local angleIncrement = (2 * math.pi) / segments

    for i = 0, segments - 1 do
        local angle = i * angleIncrement
        local x = centerX + radius * math.cos(angle)
        local y = centerY + radius * math.sin(angle)
        table.insert(vertices, x)
        table.insert(vertices, y)
    end

    return vertices
end

local function rect(w, h, x, y)
    return {
        x - w / 2, y - h / 2,
        x + w / 2, y - h / 2,
        x + w / 2, y + h / 2,
        x - w / 2, y + h / 2
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

function shapes.makeTrianglesFromPolygon(polygon)
    -- when this is true we also solve, self intersecting and everythign
    local triangles = {}
    local result = {}
    local success, err = pcall(function()
        mathutils.decompose(polygon, result)
    end)

    if not success then
        logger:error("Error in decompose_complex_poly: " .. err)
        return nil -- Exit early if decomposition fails
    end

    for i = 1, #result do
        local success, tris = pcall(love.math.triangulate, result[i])
        if success then
            utils.tableConcat(triangles, tris)
        else
            logger:error("Failed to triangulate part of the polygon: " .. tris)
        end
    end
    return triangles
end

local function makeShapeListFromPolygon(polygon)
    local shapesList = {}
    local allowComplex = true -- TODO: parameterize this
    local triangles = {}

    -- first figure out if we are maybe a simple polygon we can use -as is- by box2d
    if #polygon <= 16 and love.math.isConvex(polygon) then
        --print('cause its simple!')
        local centroidX, centroidY = mathutils.computeCentroid(polygon)
        local localVertices = {}
        for i = 1, #polygon, 2 do
            local x = polygon[i] - centroidX
            local y = polygon[i + 1] - centroidY
            table.insert(localVertices, x)
            table.insert(localVertices, y)
        end
        table.insert(shapesList, love.physics.newPolygonShape(localVertices))
    else                     -- ok we are not the simplest polygons we need more work,
        if allowComplex then -- when this is true we also solve, self intersecting and everythign
            local result = {}
            local success, err = pcall(function()
                mathutils.decompose(polygon, result)
            end)

            if not success then
                logger:error("Error in decompose_complex_poly: " .. err)
                return nil -- Exit early if decomposition fails
            end

            for i = 1, #result do
                local success, tris = pcall(love.math.triangulate, result[i])
                if success then
                    utils.tableConcat(triangles, tris)
                else
                    logger:error("Failed to triangulate part of the polygon: " .. tris)
                end
            end
        else -- this is a bit of a nono, its no longer really in use and doenst fix all werid cases. faster though.
            local success, result = pcall(love.math.triangulate, polygon)
            if success then
                triangles = result
            else
                logger:error("Failed to triangulate polygon: " .. result)
                return nil -- Exit early if triangulation fails
            end
        end

        if #triangles == 0 then
            logger:error("No valid triangles were created.")
            return nil
        end
        local centroidX, centroidY = mathutils.computeCentroid(polygon)
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
                table.insert(shapesList, shape)
            else
                logger:error("Failed to create shape for triangle: " .. shape)
            end
        end
    end
    return shapesList
end

-- function shapes.getTriangles(polygon)
--     local triangles = {}
--     local result = {}
--     local success, err = pcall(function()
--         mathutils.decompose(polygon, result)
--     end)


--     for i = 1, #result do
--         local success, tris = pcall(love.math.triangulate, result[i])
--         if success then
--             utils.tableConcat(triangles, tris)
--         else
--             print("Failed to triangulate part of the polygon: " .. tris)
--         end
--     end
--     return triangles
-- end




function shapes.createShape(shapeType, settings)
    if (settings.radius == 0) then settings.radius = 1 end
    if (settings.width == 0) then settings.width = 1 end
    if (settings.height == 0) then settings.height = 1 end

    local shapesList = {}
    local vertices = nil

    if shapeType == 'circle' then
        vertices = approximateCircle(settings.radius, 0, 0, 20)
        --table.insert(shapesList, love.physics.newPolygonShape(vertices))
        table.insert(shapesList, love.physics.newCircleShape(settings.radius))
    elseif shapeType == 'rectangle' then
        vertices = rect(settings.width, settings.height, 0, 0)
        table.insert(shapesList, love.physics.newRectangleShape(settings.width, settings.height))
    elseif shapeType == 'torso' then
        vertices = torso(settings.width, settings.width2, settings.width3, settings.height,
            settings.height2,
            settings.height3, settings.height4, 0, 0)
        shapesList = makeShapeListFromPolygon(vertices) or {}
        --table.insert(shapesList, love.physics.newPolygonShape(vertices))
    elseif shapeType == 'capsule' then
        local radius = math.min(settings.width / (settings.width2 or 1), settings.height / (settings.width2 or 1))
        vertices = capsuleXY(settings.width, settings.height, radius, 0, 0)
        table.insert(shapesList, love.physics.newPolygonShape(vertices))
    elseif shapeType == 'trapezium' then
        vertices = makeTrapezium(settings.width, settings.width2 or (settings.width * 1.2), settings.height, 0, 0)
        table.insert(shapesList, love.physics.newPolygonShape(vertices))
    elseif shapeType == 'itriangle' then
        vertices = makeITriangle(settings.width, settings.height, 0, 0)
        table.insert(shapesList, love.physics.newPolygonShape(vertices))
    elseif shapeType == 'shape8' then
        --local v = makeTransformedVertices(settings.optionalVertices)
        vertices = settings.optionalVertices

        shapesList = makeShapeListFromPolygon(vertices) or {}
        -- logger:info('lets start to make a thingie', inspect(settings))
    else
        local sides = ({
            triangle = 3,
            pentagon = 5,
            hexagon = 6,
            heptagon = 7,
            octagon = 8,
        })[shapeType]

        if sides then
            vertices = makePolygonVertices(sides, settings.radius)
            local cx, cy = mathutils.getCenterOfPoints(vertices)
            local rel = mathutils.makePolygonRelativeToCenter(vertices, cx, cy)
            vertices = mathutils.makePolygonAbsolute(rel, 0, 0)
            table.insert(shapesList, love.physics.newPolygonShape(vertices))
        elseif shapeType == 'custom' then
            if settings.optionalVertices then
                local polygon = settings.optionalVertices

                shapesList = makeShapeListFromPolygon(polygon) or {}

                vertices = polygon
            else
                error('shapetype custom needs optionalVertices!')
            end
        else
            --print(shapeType, radius, width, height, optionalVertices)
            error("Unknown shape type: " .. tostring(shapeType))
        end
    end
    return shapesList, vertices
end

return shapes

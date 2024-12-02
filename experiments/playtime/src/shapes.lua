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
                print("Error in decompose_complex_poly: " .. err)
                return nil -- Exit early if decomposition fails
            end

            for i = 1, #result do
                local success, tris = pcall(love.math.triangulate, result[i])
                if success then
                    utils.tableConcat(triangles, tris)
                else
                    print("Failed to triangulate part of the polygon: " .. tris)
                end
            end
        else -- this is a bit of a nono, its no longer really in use and doenst fix all werid cases. faster though.
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
                print("Failed to create shape for triangle: " .. shape)
            end
        end
    end
    return shapesList
end

function shapes.createShape(shapeType, radius, width, height, optionalVertices)
    if (radius == 0) then radius = 1 end
    if (width == 0) then width = 1 end
    if (height == 0) then height = 1 end

    local shapesList = {}
    local vertices = nil

    if shapeType == 'circle' then
        table.insert(shapesList, love.physics.newCircleShape(radius))
    elseif shapeType == 'rectangle' then
        table.insert(shapesList, love.physics.newRectangleShape(width, height))
    elseif shapeType == 'capsule' then
        vertices = capsuleXY(width, height, width / 5, 0, 0)
        table.insert(shapesList, love.physics.newPolygonShape(vertices))
    elseif shapeType == 'trapezium' then
        vertices = makeTrapezium(width, width * 1.2, height, 0, 0)
        table.insert(shapesList, love.physics.newPolygonShape(vertices))
    elseif shapeType == 'itriangle' then
        vertices = makeITriangle(width, height, 0, 0)
        table.insert(shapesList, love.physics.newPolygonShape(vertices))
    else
        local sides = ({
            triangle = 3,
            pentagon = 5,
            hexagon = 6,
            heptagon = 7,
            octagon = 8,
        })[shapeType]

        if sides then
            vertices = makePolygonVertices(sides, radius)
            table.insert(shapesList, love.physics.newPolygonShape(vertices))
        elseif shapeType == 'custom' then
            if optionalVertices then
                local polygon = optionalVertices
                print(inspect(polygon))
                shapesList = makeShapeListFromPolygon(polygon) or {}
                print(#shapesList)
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

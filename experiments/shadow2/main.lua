package.path  = package.path .. ";../../?.lua"
local inspect = require 'vendor.inspect'

function love.load()
    -- Load images for the character and its shadow
    character = love.graphics.newImage("character.png")
    shadow = love.graphics.newImage("shadow.png")
    -- Example light source position
    lightSource = { x = 400, y = 100 }

    guys = { { x = 100, y = 100 }, { x = 300, y = 100 }, { x = 500, y = 100 } }
end

-- Function to perform perspective projection of a polygon
function perspective_projection(vertices, light_source)
    local projected_vertices = {}

    for i, vertex in ipairs(vertices) do
        -- Direction vector from the light source to the vertex
        local direction = {
            vertex[1] - light_source[1],
            vertex[2] - light_source[2],
            vertex[3] - light_source[3]
        }

        -- Parameter t for the projection onto the z=0 plane
        local t = -light_source[3] / direction[3]

        -- Projected point calculation
        local projected_vertex = {
            light_source[1] + t * direction[1],
            light_source[2] + t * direction[2],
            light_source[3] + t * direction[3]
        }

        table.insert(projected_vertices, projected_vertex)
    end

    return projected_vertices
end

--local projected_polygon = perspective_projection(polygon_vertices, light_source)

-- Print the projected polygon vertices
--print("Projected Polygon Vertices:")
----for i, vertex in ipairs(projected_polygon) do
--    print(string.format("{%.2f, %.2f, %.2f}", vertex[1], vertex[2], vertex[3]))
--end

function calculateShadowVertices(x, y, width, height, lightX, lightY)
    local polygon_vertices = {
        { x,         y,          0 },
        { x + width, y,          0 },
        { x + width, y + height, 0 },
        { x,         y + height, 0 },
    }
    local light_source = { lightX, lightY, 10 }
    local result = perspective_projection(polygon_vertices, light_source)
    return result
end

-- Function to calculate the shadow vertices
function calculateShadowVerticesPoep(x, y, width, height, lightX, lightY)
    local shadowLength = 100 -- Length of the shadow
    local vertices = {}

    local function addVertex(offsetX, offsetY)
        -- Position of the corner of the character
        local vx = x + offsetX
        local vy = y + offsetY
        -- Vector from light source to the corner
        local lx = vx - lightX
        local ly = vy - lightY
        -- Calculate length and scale it for shadow length
        local length = math.sqrt(lx * lx + ly * ly)
        local scale = shadowLength / length
        -- Add the shadow vertex position to the vertices table
        table.insert(vertices, vx + lx * scale)
        table.insert(vertices, vy + ly * scale)
    end

    -- Add all four corners of the character
    addVertex(0, 0)
    addVertex(width, 0)
    addVertex(width, height)
    addVertex(0, height)

    return vertices
end

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
end

function love.mousemoved(x, y)
    lightSource = { x = x, y = y }
end

function makeTexturedPolygon(vertices, image)
    local v = vertices
    local data = {
        {
            -- top-left corner (red-tinted)
            v[1], v[2], -- position of the vertex
            0, 0,       -- texture coordinate at the vertex position
            1, 1, 1,    -- color of the vertex
        },
        {
            -- top-right corner (green-tinted)
            v[3], v[4],
            1, 0, -- texture coordinates are in the range of [0, 1]
            1, 1, 1
        },
        {
            -- bottom-right corner (blue-tinted)
            v[5], v[6],
            1, 1,
            1, 1, 1
        },
        {
            -- bottom-left corner (yellow-tinted)
            v[7], v[8],
            0, 1,
            1, 1, 1
        },
    }
    print(inspect(data))
    -- the Mesh DrawMode "fan" works well for 4-vertex Meshes.
    mesh = love.graphics.newMesh(data, "fan")
    mesh:setTexture(image)
    return mesh
end

function love.draw()
    love.graphics.clear(1, 1, 1)
    for i = 1, #guys do
        local it            = guys[i]

        local x, y          = it.x, it.y
        local width, height = character:getWidth(), character:getHeight()

        -- Calculate shadow vertices
        local vertices      = calculateShadowVerticesPoep(x, y, width, height, lightSource.x, lightSource.y)

        -- local vertices      = projected_polygon
        -- Draw the shadow
        love.graphics.setColor(0, 0, 0, 0.5) -- Shadow color and opacity
        -- love.graphics.polygon("fill", vertices)

        local mesh = makeTexturedPolygon(vertices, shadow)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.draw(mesh, 0, 0)

        -- Draw the main character
        love.graphics.setColor(1, 1, 1, 1) -- Reset to full opacity
        love.graphics.draw(character, x, y)
    end

    love.graphics.setColor(1, 0, 0, 0.5)
    love.graphics.circle('fill', lightSource.x, lightSource.y, 10, 10)
end

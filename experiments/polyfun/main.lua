package.path          = package.path .. ";../../?.lua"
local generatePolygon = require('lib.generate-polygon').generatePolygon
local mesh            = require('lib.mesh')
local inspect         = require 'vendor.inspect'
local phys            = require 'lib.mainPhysics'
HC                    = require 'HC'
Polygon               = require 'HC.polygon'
local cam             = require('lib.cameraBase').getInstance()
local camera          = require 'lib.camera'

function getRandomConvexPoly(radius, numVerts)
    local irregularity = 0.5
    local spikeyness = 0.2

    local vertices = {}
    if love.math.random() < 0.15 then
        vertices = generatePolygon(0, 0, radius, irregularity, spikeyness, numVerts)
    else
        vertices = generatePolygon(0, 0, radius, irregularity, spikeyness, 8)
        while not love.math.isConvex(vertices) do
            vertices = generatePolygon(0, 0, radius * love.math.random() * 2, irregularity, spikeyness, 8)
        end
    end
    return vertices
end

function makeRandomPoly(x, y, radius)
    local body = love.physics.newBody(world, x, y, "dynamic")
    local shape = love.physics.newPolygonShape(getRandomConvexPoly(radius, 8)) --love.physics.newRectangleShape(width, height / 4)
    local fixture = love.physics.newFixture(body, shape, .1)
    return body
end

function mergePolygons(polygon1, polygon2)
    local mergedPolygon = {}

    -- Find the common edge vertices
    local commonVertexIndex1
    local commonVertexIndex2
    for i = 1, #polygon1 do
        local p1 = polygon1[i]
        local p2 = polygon1[i % #polygon1 + 1] -- Next vertex in polygon1

        for j = 1, #polygon2 do
            local q1 = polygon2[j]
            local q2 = polygon2[j % #polygon2 + 1] -- Next vertex in polygon2

            -- Check if the edges share common vertices
            if (p1 == q1 and p2 == q2) or (p1 == q2 and p2 == q1) then
                commonVertexIndex1 = i
                commonVertexIndex2 = j
                break
            end
        end
        if commonVertexIndex1 and commonVertexIndex2 then
            break
        end
    end

    -- Combine vertices in correct order
    for i = 1, #polygon1 do
        table.insert(mergedPolygon, polygon1[(i + commonVertexIndex1) % #polygon1 + 1])
    end

    for i = 1, #polygon2 do
        table.insert(mergedPolygon, polygon2[(i + commonVertexIndex2) % #polygon2 + 1])
    end

    return mergedPolygon
end

function polygonsAdjacent(polygon1, polygon2)
    for i = 1, #polygon1 do
        local p1 = polygon1[i]
        local p2 = polygon1[i % #polygon1 + 1] -- Next vertex in polygon1

        for j = 1, #polygon2 do
            local q1 = polygon2[j]
            local q2 = polygon2[j % #polygon2 + 1] -- Next vertex in polygon2

            -- Check if the edges share common vertices
            if (p1 == q1 and p2 == q2) or (p1 == q2 and p2 == q1) then
                return true
            end
        end
    end

    return false
end

function mergeAdjacentConvexPolygons(convexPolygons)
    local mergedPolygons = convexPolygons
    local merged = true

    while merged do
        merged = false

        for i = 1, #mergedPolygons - 1 do
            for j = i + 1, #mergedPolygons do
                local polygon1 = mergedPolygons[i]
                local polygon2 = mergedPolygons[j]

                --if (#polygon1 + #polygon2 < 18) then
                if polygonsAdjacent(polygon1, polygon2) then
                    local mergedPolygon = mergePolygons(polygon1, polygon2)
                    mergedPolygons[i] = mergedPolygon
                    table.remove(mergedPolygons, j)
                    merged = true
                    break
                end
                --end
            end

            if merged then
                break
            end
        end
    end

    return mergedPolygons
end

function makeMeshFromConcavePoints(points)
    local result = {}

    local polys = mesh.decompose_complex_poly(points, {})
    --print(#polys)
    local vertices = {}
    for k = 1, #polys do
        local p = polys[k]
        if (#p >= 6) then
            mesh.reTriangulatePolygon(p, result)
        end
    end
    --local tris = {}
    for j = 1, #result do
        table.insert(vertices, { result[j][1], result[j][2] })
        table.insert(vertices, { result[j][3], result[j][4] })
        table.insert(vertices, { result[j][5], result[j][6] })

        --table.insert(tris, { result[j][1], result[j][2], result[j][3], result[j][4], result[j][5], result[j][6] })
    end

    --local tris2 = {}

    --for i = 1, #vertices, 6 do
    --    table.insert(tris2, { vertices[i + 0], vertices[i + 1], vertices[i + 2], vertices[i + 3], vertices[i + 4],
    --        vertices[i + 5] })
    --end
    -- print(inspect(tris2))
    return love.graphics.newMesh(vertices, "triangles") --, tris, tris2
end

function getRandomPolyAndMore()
    local result = {}
    result.points = getRandomConvexPoly(100, 18)

    local polys = mesh.decompose_complex_poly(result.points, {}) -- this will  get rid of self interecting

    if false then
        result.shapes = {}

        for i = 1, #polys do
            local poly = Polygon(unpack(polys[i]))
            local r = poly:splitConvex()
            for j = 1, #r do
                local simple = {}
                for k = 1, #r[j].vertices do
                    table.insert(simple, r[j].vertices[k].x)
                    table.insert(simple, r[j].vertices[k].y)
                end

                table.insert(result.shapes, simple)
            end
        end
    end

    result.triangles = {}
    for k = 1, #polys do
        local p = polys[k]
        if (#p >= 6) then
            mesh.reTriangulatePolygon(p, result.triangles)
        end
    end

    result.mesh = makeMeshFromConcavePoints(result.points)
    --smaller = mergeAdjacentConvexPolygons(tris)
    return result
end

function love.load()
    phys.setupWorld()
    polygons   = {}
    local w, h = love.graphics.getDimensions()
    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(0, 0, 2000, 2000)
    local itemsPerRow = 10
    local space = 200
    for i = 1, 300 do
        local thing = getRandomPolyAndMore()
        -- now make the thing physical
        --local x = love.math.random() * 4000
        --local y = -500

        local x = ((i - 1) % itemsPerRow) * space
        local y = -1000 + (math.floor((i - 1) / itemsPerRow)) * space

        local body = love.physics.newBody(world, x, y, "dynamic")

        if (#thing.points / 2 <= 8 and love.math.isConvex(thing.points)) then
            local shape = love.physics.newPolygonShape(thing.points)
            local fixture = love.physics.newFixture(body, shape, 1)
        else
            for i = 1, #thing.triangles do
                local shape = love.physics.newPolygonShape(thing.triangles[i])
                local fixture = love.physics.newFixture(body, shape, 1)
            end
        end
        --for i = 1, #thing.shapes do
        --local shape = love.physics.newPolygonShape(thing.shapes[i])
        --local fixture = love.physics.newFixture(body, shape, 1)
        --end
        thing.body = body
        --body:setPosition(x, y)
        table.insert(polygons, thing)
    end

    local body    = love.physics.newBody(world, w / 2, h, "static")
    local shape   = love.physics.newRectangleShape(w * 10, 20)
    local fixture = love.physics.newFixture(body, shape, 1)
end

function flattenNonFlat(nonFlatArray)
    local flatArray = {}
    for _, pair in ipairs(nonFlatArray) do
        table.insert(flatArray, pair[1])
        table.insert(flatArray, pair[2])
    end
    return flatArray
end

function love.draw()
    love.graphics.clear(1, 1, 1)

    if false then
        for i = 1, #polygons do
            local it = polygons[i]
            love.graphics.setColor(1, 0, 0)
            love.graphics.draw(it.mesh)

            for i = 1, #it.shapes do
                love.graphics.setColor(0, 1, 1, 0.25)
                love.graphics.polygon('fill', it.shapes[i])
                love.graphics.setColor(0, 0, 0)
                love.graphics.polygon('line', it.shapes[i])
            end

            for i = 1, #it.triangles do
                love.graphics.setColor(0, 0, 1, 0.25)
                love.graphics.polygon('fill', it.triangles[i])
                love.graphics.setColor(1, 1, 1, 0.2)
                love.graphics.polygon('line', it.triangles[i])
            end

            love.graphics.setColor(0, 0, 0)
            for i = 1, #it.points, 2 do
                love.graphics.circle('fill', it.points[i], it.points[i + 1], 2)
            end
        end
    end
    cam:push()
    phys.drawWorld(world)
    for i = 1, #polygons do
        local it = polygons[i]
        love.graphics.setColor(1, 0, 0)

        local x, y = it.body:getPosition()
        local a = it.body:getAngle()
        love.graphics.draw(it.mesh, x, y, a)
    end
    cam:pop()
    --love.graphics.print('using ' .. #tris3 .. ' triangles', 0, 0)
    ---love.graphics.print('using ' .. #splitted .. ' simplified shapes', 0, 20)
    --love.graphics.print('for ' .. #polyPoints / 2 .. ' points', 0, 40)
    --  love.graphics.polygon('fill', poly)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print(tostring(love.timer.getFPS()) .. 'fps')
end

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
end

local function pointerPressed(x, y, id)
    local w, h = love.graphics.getDimensions()
    local cx, cy = cam:getWorldCoordinates(x, y)
    local onPressedParams = {
        pointerForceFunc = function(fixture)
            local ud = fixture:getUserData()
            --print(inspect(ud))
            local force =
                (ud and ud.bodyType == 'torso' and 1000000) or
                (ud and ud.bodyType == 'frame' and 1000000) or
                50000
            -- print(force)
            return force
        end
        --pointerForceFunc = function(fixture) return 1400 end
    }
    local interacted = phys.handlePointerPressed(cx, cy, id, { pointerForceFunc = function() return 500000 end })
    --ui.addToPressedPointers(x, y, id)
end

function love.mousepressed(x, y, button, istouch)
    -- print('mousepresed')
    if not istouch then
        if button == 1 then
            pointerPressed(x, y, 'mouse')
        end
    end
end

local function pointerReleased(x, y, id)
    phys.handlePointerReleased(x, y, id)
    -- ui.removeFromPressedPointers(id)
end

function love.mousereleased(x, y, button, istouch)
    --  lastDraggedElement = nil
    if not istouch then
        pointerReleased(x, y, 'mouse')
    end
end

function love.update(dt)
    world:update(dt)
    phys.handleUpdate(dt)
end

function love.wheelmoved(dx, dy)
    local newScale = cam.scale * (1 + dy / 10)
    if (newScale > 0.01 and newScale < 50) then
        cam:scaleToPoint(1 + dy / 10)
    end
end

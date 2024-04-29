package.path          = package.path .. ";../../?.lua"
local generatePolygon = require('lib.generate-polygon').generatePolygon
local mesh            = require('lib.mesh')
local inspect         = require 'vendor.inspect'
local phys            = require 'lib.mainPhysics'
HC                    = require 'HC'
Polygon               = require 'HC.polygon'
local cam             = require('lib.cameraBase').getInstance()
local camera          = require 'lib.camera'
local parentize       = require 'lib.parentize'
local parse           = require 'lib.parse-file'
local render          = require 'lib.render'

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

function getTriangles(points)
    local polys = mesh.decompose_complex_poly(points, {})
    local triangles = {}
    for k = 1, #polys do
        local p = polys[k]
        if (#p >= 6) then
            mesh.reTriangulatePolygon(p, triangles)
        end
    end
    return triangles
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

function getBox2dAndVectorSketchPair(things)
    things.transforms.l[1] = 0
    things.transforms.l[2] = 0
    things.transforms.l[3] = 0

    local box2dThing = {}

    if things.children and things.children[1] and things.children[1].type == 'meta' then
        --print('looking good!')
        --print(things.children[1].name)
        if (things.children[1].name == 'box2d-hitarea') then
            -- now we must assert this shape has 8 or less points AND is convex
            local it = things.children[1]
            local points = flattenNonFlat(it.points)

            local x = love.math.random() * 2000
            local y = -5000 + love.math.random() * 4000
            box2dThing.body = love.physics.newBody(world, x, y, "dynamic")
            if (#points / 2 <= 8 and love.math.isConvex(points)) then
                --print('safe to use this', #points / 2)
                box2dThing.shape = love.physics.newPolygonShape(points)
                box2dThing.fixture = love.physics.newFixture(box2dThing.body, box2dThing.shape, 1)
                --box2dThing.fixture:setGroupIndex(-1 * #dings)
            else
                --print(#points / 2 <= 8, love.math.isConvex(points))
                local triangles = getTriangles(points)
                for i = 1, #triangles do
                    box2dThing.shape = love.physics.newPolygonShape(triangles[i])
                    box2dThing.fixture = love.physics.newFixture(box2dThing.body, box2dThing.shape, 1)
                    --   box2dThing.fixture:setGroupIndex(-1)
                end
                --print('not safe to use this', #points / 2)
            end
            --  box2dThing.body:setPosition(0, 0)
        end
    end
    return { things = things, box2dThing = box2dThing }
end

local shadowCache = {}

function makeOrGetShadow(url, index)
    if not shadowCache[url .. index] then
        shadowCache[url .. index] = makeShadowImage(url, index)
    end
    return shadowCache[url .. index]
end

local function getPolygonThatNeedsShadowing(vsketch)
    if vsketch.children and vsketch.children[1] and vsketch.children[1].type == 'meta' then
        --print('ok')
        --print(inspect(vsketch.children[2]))
        local colorAt2 = vsketch.children[2].color
        --print(inspect(colorAt2))
        --  if (colorAt2[1] + colorAt2[2] + colorAt2[3] == 0) then
        --print('jojo@')
        return vsketch.children[2].points
        -- end
    end
    print('failed at getting the poolygon that needs shadowing')
end

function flattenNonFlat(nonFlatArray)
    local flatArray = {}
    for _, pair in ipairs(nonFlatArray) do
        table.insert(flatArray, pair[1])
        table.insert(flatArray, pair[2])
    end
    return flatArray
end

function makeShadowImage(url, index)
    -- lets assume the first child is meta,
    -- the second one is the all encomappsing black outline (I NEED THIS ONE)
    local vsketch = parse.parseFile(url, true)[index]
    local poly = flattenNonFlat(getPolygonThatNeedsShadowing(vsketch))
    local triangles = getTriangles(poly)
    --print(inspect(triangles))
    --print(inspect(poly))
    -- print(inspect(flattenNonFlat(poly)))
    local shadow = makeSingleShadow(poly, triangles)
    --return
    return shadow
end

function getBBoxOfPolygon(poly)
    local minX = math.huge
    local minY = math.huge
    local maxX = -math.huge
    local maxY = -math.huge

    for i = 1, #poly, 2 do
        if minX > poly[i] then minX = poly[i] end
        if maxX < poly[i] then maxX = poly[i] end
        if minY > poly[i + 1] then minY = poly[i + 1] end
        if maxY < poly[i + 1] then maxY = poly[i + 1] end
    end

    local width = maxX - minX
    local height = maxY - minY
    return minX, minY, maxX, maxY
end

function applyBlur(imageData, radius)
    local blurredImageData = imageData:clone()

    for x = 0, blurredImageData:getWidth() - 1 do
        for y = 0, blurredImageData:getHeight() - 1 do
            local totalR, totalG, totalB, totalA = 0, 0, 0, 0
            local count = 0

            -- Apply the blur filter within the specified radius
            for dx = -radius, radius do
                for dy = -radius, radius do
                    local nx, ny = x + dx, y + dy
                    if nx >= 0 and nx < blurredImageData:getWidth() and ny >= 0 and ny < blurredImageData:getHeight() then
                        local r, g, b, a = imageData:getPixel(nx, ny)
                        totalR = totalR + r
                        totalG = totalG + g
                        totalB = totalB + b
                        totalA = totalA + a
                        count = count + 1
                    end
                end
            end

            -- Average the colors within the radius
            totalR = totalR / count
            totalG = totalG / count
            totalB = totalB / count
            totalA = totalA / count

            -- Set the pixel color in the blurred image
            blurredImageData:setPixel(x, y, totalR, totalG, totalB, totalA)
        end
    end

    return blurredImageData
end

function makeSingleShadow(thing, triangles)
    local minX, minY, maxX, maxY = getBBoxOfPolygon(thing)
    local centerX = minX + (maxX - minX) / 2
    local centerY = minY + (maxY - minY) / 2
    local width = maxX - minX
    local height = maxY - minY

    -- print(minX, minY, maxX, maxY)

    local margin = width / 5
    local canvasWidth, canvasHeight = (width + margin * 2) * scale, (height + margin * 2) * scale
    local canvas = love.graphics.newCanvas(canvasWidth, canvasHeight, { dpiscale = 1 })
    --local canvas = love.graphics.newCanvas(width * scale, height * scale)
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    love.graphics.setColor(1, 1, 1)
    -- Scale and draw the polygon
    love.graphics.push()
    --love.graphics.translate(-minX * scale, -minY * scale)
    love.graphics.translate((-minX + margin) * scale, (-minY + margin) * scale)
    love.graphics.scale(scale)
    for i = 1, #triangles do
        love.graphics.polygon("fill", triangles[i])
    end
    love.graphics.pop()
    love.graphics.setCanvas()

    -- Get the ImageData from the canvas
    local imageData = canvas:newImageData()

    -- Apply blur filter to the ImageData
    local blurredImageData = applyBlur(imageData, 1)

    -- Convert blurred ImageData back to Love2D image
    local blurredImage = love.graphics.newImage(blurredImageData)

    return blurredImage
end

function love.load()
    --love.window.setMode(600, 600)
    scale = .2
    phys.setupWorld(100)
    polygons = {}

    local w, h = love.graphics.getDimensions()
    camera.setCameraViewport(cam, 1000, 1000)
    camera.centerCameraOnPosition(0, 0, w, h)

    root = {
        folder = true,
        name = 'root',
        transforms = { g = { 0, 0, 0, 1, 1, 0, 0 }, l = { 0, 0, 0, cam.scale, cam.scale, 0, 0 } },
        children = {}
    }

    dings = {}
    for i = 1, 5 do
        local vsketch = parse.parseFile('assets/dontevenknow.polygons.txt', true)[1]
        local ding2 = getBox2dAndVectorSketchPair(vsketch)
        --local shadow = makeOrGetShadow('assets/mipo.polygons.txt', 1)
        --ding2.shadow = shadow
        table.insert(root.children, ding2.things)
        table.insert(dings, ding2)
    end
    for i = 1, 5 do
        local vsketch = parse.parseFile('assets/ziekevogel.polygons.txt', true)[1]
        local ding2 = getBox2dAndVectorSketchPair(vsketch)
        --local shadow = makeOrGetShadow('assets/mipo.polygons.txt', 1)
        --ding2.shadow = shadow
        table.insert(root.children, ding2.things)
        table.insert(dings, ding2)
    end
    for i = 1, 5 do
        local vsketch = parse.parseFile('assets/mipo.polygons.txt', true)[1]
        local ding2 = getBox2dAndVectorSketchPair(vsketch)
        local shadow = makeOrGetShadow('assets/mipo.polygons.txt', 1)
        ding2.shadow = shadow
        table.insert(root.children, ding2.things)
        table.insert(dings, ding2)
    end
    for i = 1, 5 do
        local vsketch = parse.parseFile('assets/die2.polygons.txt', true)[1]
        local ding2 = getBox2dAndVectorSketchPair(vsketch)
        local shadow = makeOrGetShadow('assets/die2.polygons.txt', 1)
        ding2.shadow = shadow
        table.insert(root.children, ding2.things)
        table.insert(dings, ding2)
    end
    for i = 1, 5 do
        local vsketch = parse.parseFile('assets/die2.polygons.txt', true)[2]
        local ding2 = getBox2dAndVectorSketchPair(vsketch)
        local shadow = makeOrGetShadow('assets/die2.polygons.txt', 2)
        ding2.shadow = shadow
        table.insert(root.children, ding2.things)
        table.insert(dings, ding2)
    end
    for i = 1, 5 do
        local vsketch = parse.parseFile('assets/cola.polygons.txt', true)[1]
        local ding2 = getBox2dAndVectorSketchPair(vsketch)
        local shadow = makeOrGetShadow('assets/cola.polygons.txt', 1)
        ding2.shadow = shadow
        table.insert(root.children, ding2.things)
        table.insert(dings, ding2)
    end
    for i = 1, 5 do
        local vsketch = parse.parseFile('assets/kroko.polygons.txt', true)[1]
        local ding2 = getBox2dAndVectorSketchPair(vsketch)
        local shadow = makeOrGetShadow('assets/kroko.polygons.txt', 1)
        ding2.shadow = shadow
        table.insert(root.children, ding2.things)
        table.insert(dings, ding2)
    end
    for i = 1, 5 do
        local vsketch = parse.parseFile('assets/groen.polygons.txt', true)[1]
        local ding2 = getBox2dAndVectorSketchPair(vsketch)
        local shadow = makeOrGetShadow('assets/groen.polygons.txt', 1)
        ding2.shadow = shadow
        table.insert(root.children, ding2.things)
        table.insert(dings, ding2)
    end
    for i = 1, 5 do
        local vsketch = parse.parseFile('assets/theosding2.polygons.txt', true)[1]
        local ding2 = getBox2dAndVectorSketchPair(vsketch)
        local shadow = makeOrGetShadow('assets/theosding2.polygons.txt', 1)
        ding2.shadow = shadow
        table.insert(root.children, ding2.things)
        table.insert(dings, ding2)
    end
    for i = 1, 5 do
        local vsketch = parse.parseFile('assets/theosding2.polygons.txt', true)[2]
        local ding2 = getBox2dAndVectorSketchPair(vsketch)
        table.insert(root.children, ding2.things)
        table.insert(dings, ding2)
    end
    for i = 1, 5 do
        local vsketch = parse.parseFile('assets/theosding.polygons.txt', true)[1]
        local ding2 = getBox2dAndVectorSketchPair(vsketch)
        table.insert(root.children, ding2.things)
        table.insert(dings, ding2)
    end
    for i = 1, 5 do
        local vsketch = parse.parseFile('assets/theosding.polygons.txt', true)[2]
        local ding2 = getBox2dAndVectorSketchPair(vsketch)
        table.insert(root.children, ding2.things)
        table.insert(dings, ding2)
    end
    for i = 1, 5 do
        local vsketch = parse.parseFile('assets/broodenpoes.polygons.txt', true)[1]
        local ding2 = getBox2dAndVectorSketchPair(vsketch)
        table.insert(root.children, ding2.things)
        table.insert(dings, ding2)
    end
    for i = 1, 5 do
        local vsketch = parse.parseFile('assets/broodenpoes.polygons.txt', true)[2]
        local ding2 = getBox2dAndVectorSketchPair(vsketch)
        table.insert(root.children, ding2.things)
        table.insert(dings, ding2)
    end

    if false then
        for i = 1, 20 do
            local vsketch = parse.parseFile('assets/weirdshapes.polygons.txt', true)[1]
            local ding2 = getBox2dAndVectorSketchPair(vsketch)
            table.insert(root.children, ding2.things)
            table.insert(dings, ding2)
        end
        for i = 1, 20 do
            local vsketch = parse.parseFile('assets/weirdshapes.polygons.txt', true)[2]
            local ding1 = getBox2dAndVectorSketchPair(vsketch)
            table.insert(root.children, ding1.things)
            --  print((ding1.things))
            table.insert(dings, ding1)
        end

        for i = 1, 20 do
            local vsketch = parse.parseFile('assets/weirdshapes.polygons.txt', true)[3]
            local ding2 = getBox2dAndVectorSketchPair(vsketch)
            table.insert(root.children, ding2.things)
            table.insert(dings, ding2)
        end
        for i = 1, 20 do
            local vsketch = parse.parseFile('assets/weirdshapes.polygons.txt', true)[4]
            local ding2 = getBox2dAndVectorSketchPair(vsketch)
            table.insert(root.children, ding2.things)
            table.insert(dings, ding2)
        end
        for i = 1, 20 do
            local vsketch = parse.parseFile('assets/weirdshapes.polygons.txt', true)[5]
            local ding2 = getBox2dAndVectorSketchPair(vsketch)
            table.insert(root.children, ding2.things)
            table.insert(dings, ding2)
        end
        for i = 1, 20 do
            local vsketch = parse.parseFile('assets/weirdshapes.polygons.txt', true)[6]
            local ding2 = getBox2dAndVectorSketchPair(vsketch)
            table.insert(root.children, ding2.things)
            table.insert(dings, ding2)
        end
    end








    parentize.parentize(root)
    mesh.meshAll(root)
    render.renderThings(root)
    -- print(inspect(things[1]))


    local itemsPerRow = 10
    local space = 200
    for i = 1, 1 do
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

    local body    = love.physics.newBody(world, w / 2, h - 100, "static")
    local shape   = love.physics.newRectangleShape(w * 50, 20)
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
    --phys.drawWorld(world)

    for i = 1, #polygons do
        local it = polygons[i]
        love.graphics.setColor(1, 0, 0)

        local x, y = it.body:getPosition()
        local a = it.body:getAngle()
        love.graphics.draw(it.mesh, x, y, a)
    end
    love.graphics.setColor(0, 0, 0, 0.5)
    for i = 1, #dings do
        local it = dings[i]
        local bx, by = it.box2dThing.body:getPosition()
        local angle = it.box2dThing.body:getAngle()
        it.things.transforms.l[1] = bx
        it.things.transforms.l[2] = by
        it.things.transforms.l[3] = angle

        if (it.shadow) then
            --print(it.shadow)
            love.graphics.draw(it.shadow, bx, by, angle, 1 / scale, 1 / scale, it.shadow:getWidth() / 2,
                it.shadow:getHeight() / 2)
        end
    end
    render.renderThings(root)



    cam:pop()




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

function love.mousemoved(x, y, dx, dy)
    if love.mouse.isDown(3) then
        cam:increaseTranslation(-dx / cam.scale, -dy / cam.scale)
    end
end

function love.update(dt)
    world:update(dt)
    phys.handleUpdate(dt)
end

local function getGlobalDelta(transform, dx, dy)
    -- this one is only used in the wheel moved offset stuff
    local dx1, dy1 = transform:transformPoint(0, 0)
    local dx2, dy2 = transform:transformPoint(dx, dy)
    local dx3 = dx2 - dx1
    local dy3 = dy2 - dy1
    return dx3, dy3
end

function love.wheelmoved(dx, dy)
    local newScale = cam.scale * (1 + dy / 10)
    if (newScale > .1 and newScale < 10) then
        cam:scaleToPoint(1 + dy / 10)
    end
end

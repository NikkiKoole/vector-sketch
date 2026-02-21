-- spec/shapes_spec.lua
-- Tests for src/shapes.lua — geometry builders + Box2D shape creation
-- Pure geometry tests work standalone; createShape tests need LÖVE.

package.loaded['src.shapes'] = nil
local shapes = require('src.shapes')
local t = shapes._test

-- ─── Helper functions ───

local function vertexCount(flatVerts)
    return #flatVerts / 2
end

local function getVertex(flatVerts, index)
    return flatVerts[index * 2 - 1], flatVerts[index * 2]
end

local function assertVertexNear(flatVerts, index, expectedX, expectedY, tol)
    tol = tol or 0.001
    local x, y = getVertex(flatVerts, index)
    assert.is_near(expectedX, x, tol, "vertex " .. index .. " x")
    assert.is_near(expectedY, y, tol, "vertex " .. index .. " y")
end

local function boundingBox(flatVerts)
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    for i = 1, #flatVerts, 2 do
        minX = math.min(minX, flatVerts[i])
        maxX = math.max(maxX, flatVerts[i])
        minY = math.min(minY, flatVerts[i + 1])
        maxY = math.max(maxY, flatVerts[i + 1])
    end
    return minX, minY, maxX, maxY
end

-- ─── Pure geometry tests (no LÖVE needed) ───

describe("shapes._test (pure geometry)", function()

    describe("rect", function()
        it("creates a 4-vertex rectangle centered at origin", function()
            local v = t.rect(100, 50, 0, 0)
            assert.are.equal(4, vertexCount(v))
            assertVertexNear(v, 1, -50, -25)
            assertVertexNear(v, 2, 50, -25)
            assertVertexNear(v, 3, 50, 25)
            assertVertexNear(v, 4, -50, 25)
        end)

        it("offsets by center position", function()
            local v = t.rect(100, 50, 200, 300)
            assertVertexNear(v, 1, 150, 275)
            assertVertexNear(v, 2, 250, 275)
            assertVertexNear(v, 3, 250, 325)
            assertVertexNear(v, 4, 150, 325)
        end)

        it("handles zero-size gracefully", function()
            local v = t.rect(0, 0, 0, 0)
            assert.are.equal(4, vertexCount(v))
        end)
    end)

    describe("makePolygonVertices", function()
        it("creates a triangle with 3 vertices", function()
            local v = t.makePolygonVertices(3, 100)
            assert.are.equal(3, vertexCount(v))
        end)

        it("creates a hexagon with 6 vertices", function()
            local v = t.makePolygonVertices(6, 50)
            assert.are.equal(6, vertexCount(v))
        end)

        it("all vertices are at the specified radius", function()
            local radius = 75
            local v = t.makePolygonVertices(8, radius)
            for i = 1, vertexCount(v) do
                local x, y = getVertex(v, i)
                local dist = math.sqrt(x * x + y * y)
                assert.is_near(radius, dist, 0.001, "vertex " .. i .. " radius")
            end
        end)

        it("first vertex is at the top (rotation offset = pi/2)", function()
            local v = t.makePolygonVertices(4, 100)
            local x, y = getVertex(v, 1)
            assert.is_near(0, x, 0.001)
            assert.is_near(-100, y, 0.001) -- top = negative y
        end)
    end)

    describe("capsuleXY", function()
        it("creates 8 vertices", function()
            local v = t.capsuleXY(100, 200, 20, 0, 0)
            assert.are.equal(8, vertexCount(v))
        end)

        it("bounding box matches width and height", function()
            local v = t.capsuleXY(100, 200, 20, 0, 0)
            local minX, minY, maxX, maxY = boundingBox(v)
            assert.is_near(100, maxX - minX, 0.001, "width")
            assert.is_near(200, maxY - minY, 0.001, "height")
        end)

        it("offsets by center position", function()
            local v = t.capsuleXY(100, 200, 20, 50, 100)
            local minX, minY, maxX, maxY = boundingBox(v)
            assert.is_near(50, (minX + maxX) / 2, 0.001, "center x")
            assert.is_near(100, (minY + maxY) / 2, 0.001, "center y")
        end)

        it("corner size affects the shape", function()
            local v1 = t.capsuleXY(100, 200, 10, 0, 0)
            local v2 = t.capsuleXY(100, 200, 40, 0, 0)
            -- Different corner sizes should produce different vertex positions
            -- (the corners get more rounded with larger csw)
            local x1_1, y1_1 = getVertex(v1, 1)
            local x2_1, y2_1 = getVertex(v2, 1)
            -- Same x (left edge), but different y (corner inset)
            assert.are.equal(x1_1, x2_1) -- both at -w/2
            assert.are_not.equal(y1_1, y2_1) -- different corner offset
        end)
    end)

    describe("torso", function()
        it("creates 8 vertices", function()
            local v = t.torso(80, 100, 90, 30, 50, 40, 30, 0, 0)
            assert.are.equal(8, vertexCount(v))
        end)

        it("top vertex is on center x", function()
            local v = t.torso(80, 100, 90, 30, 50, 40, 30, 0, 0)
            local x, y = getVertex(v, 1)
            assert.are.equal(0, x)
        end)

        it("bottom vertex is on center x", function()
            local v = t.torso(80, 100, 90, 30, 50, 40, 30, 0, 0)
            local x, y = getVertex(v, 5)
            assert.are.equal(0, x)
        end)

        it("is symmetric horizontally", function()
            local v = t.torso(80, 100, 90, 30, 50, 40, 30, 0, 0)
            -- vertex 2 and 8 should be symmetric (shoulders)
            local x2, y2 = getVertex(v, 2)
            local x8, y8 = getVertex(v, 8)
            assert.is_near(-x2, x8, 0.001, "shoulder symmetry x")
            assert.is_near(y2, y8, 0.001, "shoulder symmetry y")
            -- vertex 3 and 7 (waist)
            local x3, y3 = getVertex(v, 3)
            local x7, y7 = getVertex(v, 7)
            assert.is_near(-x3, x7, 0.001, "waist symmetry x")
            assert.is_near(y3, y7, 0.001, "waist symmetry y")
            -- vertex 4 and 6 (hips)
            local x4, y4 = getVertex(v, 4)
            local x6, y6 = getVertex(v, 6)
            assert.is_near(-x4, x6, 0.001, "hip symmetry x")
            assert.is_near(y4, y6, 0.001, "hip symmetry y")
        end)

        it("widths control the horizontal extent at each level", function()
            local v = t.torso(80, 100, 60, 30, 50, 40, 30, 0, 0)
            -- vertex 2 is at w1/2 (shoulder right)
            local x2 = getVertex(v, 2)
            assert.is_near(40, x2, 0.001, "w1/2 = shoulder")
            -- vertex 3 is at w2/2 (waist right)
            local x3 = getVertex(v, 3)
            assert.is_near(50, x3, 0.001, "w2/2 = waist")
            -- vertex 4 is at w3/2 (hip right)
            local x4 = getVertex(v, 4)
            assert.is_near(30, x4, 0.001, "w3/2 = hip")
        end)
    end)

    describe("approximateCircle", function()
        it("creates the default 32 segments", function()
            local v = t.approximateCircle(50, 0, 0)
            assert.are.equal(32, vertexCount(v))
        end)

        it("respects custom segment count", function()
            local v = t.approximateCircle(50, 0, 0, 16)
            assert.are.equal(16, vertexCount(v))
        end)

        it("all vertices are at the specified radius from center", function()
            local cx, cy, r = 100, 200, 75
            local v = t.approximateCircle(r, cx, cy, 20)
            for i = 1, vertexCount(v) do
                local x, y = getVertex(v, i)
                local dist = math.sqrt((x - cx)^2 + (y - cy)^2)
                assert.is_near(r, dist, 0.001, "vertex " .. i)
            end
        end)
    end)

    describe("ribbon", function()
        it("creates correct vertex count for horizontal ribbon", function()
            local v = t.ribbon(200, 50, 0, 0, 4, "horizontal")
            -- 4 segments = 5 top + 5 bottom = 10 vertices
            assert.are.equal(10, vertexCount(v))
        end)

        it("creates correct vertex count for vertical ribbon", function()
            local v = t.ribbon(50, 200, 0, 0, 6, "vertical")
            -- 6 segments = 7 left + 7 right = 14 vertices
            assert.are.equal(14, vertexCount(v))
        end)

        it("horizontal ribbon has correct bounding box", function()
            local v = t.ribbon(200, 50, 0, 0, 4, "horizontal")
            local minX, minY, maxX, maxY = boundingBox(v)
            assert.is_near(200, maxX - minX, 0.001, "width")
            assert.is_near(50, maxY - minY, 0.001, "height")
        end)

        it("vertical ribbon has correct bounding box", function()
            local v = t.ribbon(50, 200, 0, 0, 4, "vertical")
            local minX, minY, maxX, maxY = boundingBox(v)
            assert.is_near(50, maxX - minX, 0.001, "width")
            assert.is_near(200, maxY - minY, 0.001, "height")
        end)

        it("defaults to horizontal with 4 segments", function()
            local v = t.ribbon(200, 50, 0, 0)
            assert.are.equal(10, vertexCount(v)) -- 5+5
        end)

        it("errors on invalid direction", function()
            assert.has_error(function()
                t.ribbon(100, 50, 0, 0, 4, "diagonal")
            end)
        end)

        it("offsets by center position", function()
            local v = t.ribbon(200, 50, 300, 400, 4, "horizontal")
            local minX, minY, maxX, maxY = boundingBox(v)
            assert.is_near(300, (minX + maxX) / 2, 0.001, "center x")
            assert.is_near(400, (minY + maxY) / 2, 0.001, "center y")
        end)
    end)

    describe("makeTrapezium", function()
        it("creates 4 vertices", function()
            local v = t.makeTrapezium(100, 60, 80, 0, 0)
            assert.are.equal(4, vertexCount(v))
        end)

        it("top edge uses w, bottom edge uses w2", function()
            local v = t.makeTrapezium(100, 60, 80, 0, 0)
            -- top left, top right
            local x1 = getVertex(v, 1)
            local x2 = getVertex(v, 2)
            assert.is_near(100, x2 - x1, 0.001, "top width")
            -- bottom left, bottom right
            local x3 = getVertex(v, 3)
            local x4 = getVertex(v, 4)
            assert.is_near(60, x3 - x4, 0.001, "bottom width")
        end)
    end)

    describe("makeITriangle", function()
        it("creates 3 vertices", function()
            local v = t.makeITriangle(100, 80, 0, 0)
            assert.are.equal(3, vertexCount(v))
        end)

        it("apex is at center top, base is at bottom", function()
            local v = t.makeITriangle(100, 80, 0, 0)
            -- vertex 3 is the apex (0, -h/2)
            local x3, y3 = getVertex(v, 3)
            assert.is_near(0, x3, 0.001, "apex x")
            assert.is_near(-40, y3, 0.001, "apex y")
            -- vertices 1,2 are the base
            local x1, y1 = getVertex(v, 1)
            local x2, y2 = getVertex(v, 2)
            assert.is_near(40, y1, 0.001, "base y")
            assert.is_near(100, x2 - x1, 0.001, "base width")
        end)
    end)

    describe("cross", function()
        it("returns zero for collinear points", function()
            assert.are.equal(0, t.cross(0, 0, 1, 0, 2, 0))
        end)

        it("returns positive for CCW turn", function()
            assert.is_true(t.cross(0, 0, 1, 0, 1, 1) > 0)
        end)

        it("returns negative for CW turn", function()
            assert.is_true(t.cross(0, 0, 1, 0, 1, -1) < 0)
        end)
    end)

    describe("pointInTriangle", function()
        it("returns true for point inside", function()
            assert.is_true(t.pointInTriangle(0.5, 0.5, 0, 0, 2, 0, 0, 2))
        end)

        it("returns false for point outside", function()
            assert.is_false(t.pointInTriangle(3, 3, 0, 0, 2, 0, 0, 2))
        end)

        it("returns true for point at vertex", function()
            assert.is_true(t.pointInTriangle(0, 0, 0, 0, 2, 0, 0, 2))
        end)
    end)

    describe("splitTriangle", function()
        it("replaces one triangle with three", function()
            local tris = {
                { 0, 0, 10, 0, 0, 10 }
            }
            t.splitTriangle(tris, 1, 3, 3)
            assert.are.equal(3, #tris)
        end)

        it("all new triangles share the split point", function()
            local tris = {
                { 0, 0, 10, 0, 0, 10 }
            }
            local px, py = 3, 3
            t.splitTriangle(tris, 1, px, py)
            for i, tri in ipairs(tris) do
                local found = false
                for j = 1, 5, 2 do
                    if tri[j] == px and tri[j + 1] == py then
                        found = true
                        break
                    end
                end
                assert.is_true(found, "triangle " .. i .. " should contain split point")
            end
        end)
    end)

    describe("triangulateRibbon", function()
        it("creates correct number of triangles", function()
            -- 4-segment ribbon = 10 vertices = 5 per edge = 4 quads = 8 triangles
            local v = t.ribbon(200, 50, 0, 0, 4, "horizontal")
            local tris = t.triangulateRibbon(v)
            assert.are.equal(8, #tris)
        end)

        it("each triangle has 6 values (3 vertices)", function()
            local v = t.ribbon(100, 50, 0, 0, 2, "horizontal")
            local tris = t.triangulateRibbon(v)
            for i, tri in ipairs(tris) do
                assert.are.equal(6, #tri, "triangle " .. i .. " should have 6 values")
            end
        end)

        it("works with vertical ribbons", function()
            local v = t.ribbon(50, 200, 0, 0, 3, "vertical")
            local tris = t.triangulateRibbon(v)
            -- 3 segments = 4 per edge = 3 quads = 6 triangles
            assert.are.equal(6, #tris)
        end)

        it("errors on odd vertex count", function()
            assert.has_error(function()
                t.triangulateRibbon({ 0, 0, 1, 0, 2, 0 }) -- 3 vertices, not even
            end)
        end)
    end)
end)

-- ─── LÖVE integration tests (createShape with real Box2D) ───

if not love then return end

describe("shapes.createShape (LÖVE integration)", function()

    local world

    before_each(function()
        world = love.physics.newWorld(0, 0, true)
    end)

    after_each(function()
        if world and not world:isDestroyed() then
            world:destroy()
        end
    end)

    local function makeBody()
        return love.physics.newBody(world, 0, 0, "dynamic")
    end

    local function attachShapes(shapesList, body)
        local fixtures = {}
        for _, shape in ipairs(shapesList) do
            fixtures[#fixtures + 1] = love.physics.newFixture(body, shape)
        end
        return fixtures
    end

    describe("circle", function()
        it("returns one shape and circle vertices", function()
            local shapesList, vertices = shapes.createShape('circle', { radius = 50, width = 1, height = 1 })
            assert.are.equal(1, #shapesList)
            assert.are.equal("circle", shapesList[1]:getType())
            assert.is_near(50, shapesList[1]:getRadius(), 0.001)
            assert.is_not_nil(vertices)
        end)

        it("can be attached to a body", function()
            local shapesList = shapes.createShape('circle', { radius = 30, width = 1, height = 1 })
            local body = makeBody()
            local fixtures = attachShapes(shapesList, body)
            assert.are.equal(1, #fixtures)
        end)
    end)

    describe("rectangle", function()
        it("returns one shape and 4 vertices", function()
            local shapesList, vertices = shapes.createShape('rectangle', { radius = 1, width = 100, height = 50 })
            assert.are.equal(1, #shapesList)
            assert.are.equal("polygon", shapesList[1]:getType())
            assert.are.equal(8, #vertices) -- 4 vertices * 2 coords
        end)

        it("vertices match requested dimensions", function()
            local _, vertices = shapes.createShape('rectangle', { radius = 1, width = 100, height = 50 })
            local minX, minY, maxX, maxY = boundingBox(vertices)
            assert.is_near(100, maxX - minX, 0.001)
            assert.is_near(50, maxY - minY, 0.001)
        end)
    end)

    describe("capsule", function()
        it("returns one shape and 8 vertices", function()
            local shapesList, vertices = shapes.createShape('capsule', {
                radius = 1, width = 60, height = 120, width2 = 3
            })
            assert.are.equal(1, #shapesList)
            assert.are.equal(16, #vertices) -- 8 vertices
        end)

        it("can be attached to a body and simulated", function()
            local shapesList = shapes.createShape('capsule', {
                radius = 1, width = 60, height = 120, width2 = 3
            })
            local body = makeBody()
            local fixtures = attachShapes(shapesList, body)
            assert.are.equal(1, #fixtures)
            world:update(1/60) -- shouldn't crash
        end)
    end)

    describe("torso", function()
        it("returns multiple shapes (triangulated) and 8 vertices", function()
            local shapesList, vertices = shapes.createShape('torso', {
                radius = 1, width = 80, width2 = 100, width3 = 90,
                height = 30, height2 = 50, height3 = 40, height4 = 30
            })
            assert.is_true(#shapesList >= 1, "should create at least 1 shape")
            assert.are.equal(16, #vertices) -- 8 vertices
        end)

        it("shapes can be attached and simulated", function()
            local shapesList = shapes.createShape('torso', {
                radius = 1, width = 80, width2 = 100, width3 = 90,
                height = 30, height2 = 50, height3 = 40, height4 = 30
            })
            local body = makeBody()
            local fixtures = attachShapes(shapesList, body)
            assert.is_true(#fixtures >= 1)
            world:update(1/60)
        end)
    end)

    describe("trapezium", function()
        it("returns one shape and 4 vertices", function()
            local shapesList, vertices = shapes.createShape('trapezium', {
                radius = 1, width = 100, width2 = 60, height = 80
            })
            assert.are.equal(1, #shapesList)
            assert.are.equal(8, #vertices)
        end)
    end)

    describe("itriangle", function()
        it("returns one shape and 3 vertices", function()
            local shapesList, vertices = shapes.createShape('itriangle', {
                radius = 1, width = 100, height = 80
            })
            assert.are.equal(1, #shapesList)
            assert.are.equal(6, #vertices)
        end)
    end)

    describe("regular polygons", function()
        local polygonTypes = {
            { name = "triangle", sides = 3 },
            { name = "pentagon", sides = 5 },
            { name = "hexagon", sides = 6 },
            { name = "heptagon", sides = 7 },
            { name = "octagon", sides = 8 },
        }

        for _, pt in ipairs(polygonTypes) do
            it(pt.name .. " creates " .. pt.sides .. " vertices", function()
                local shapesList, vertices = shapes.createShape(pt.name, {
                    radius = 50, width = 1, height = 1
                })
                assert.are.equal(1, #shapesList)
                assert.are.equal(pt.sides * 2, #vertices)
            end)
        end
    end)

    describe("ribbon", function()
        it("returns multiple shapes from triangulated ribbon", function()
            local shapesList, vertices = shapes.createShape('ribbon', {
                radius = 1, width = 50, height = 20  -- height*10 = 200
            })
            assert.is_true(#shapesList >= 1, "should create at least 1 shape")
            assert.is_not_nil(vertices)
        end)

        it("shapes can be attached and simulated", function()
            local shapesList = shapes.createShape('ribbon', {
                radius = 1, width = 50, height = 20
            })
            local body = makeBody()
            local fixtures = attachShapes(shapesList, body)
            assert.is_true(#fixtures >= 1)
            world:update(1/60)
        end)
    end)

    describe("custom (shape8)", function()
        it("accepts optionalVertices for shape8", function()
            -- Simple convex quad
            local verts = { -50, -50, 50, -50, 50, 50, -50, 50 }
            local shapesList, vertices = shapes.createShape('shape8', {
                radius = 1, width = 1, height = 1,
                optionalVertices = verts
            })
            assert.is_true(#shapesList >= 1)
            assert.are.same(verts, vertices)
        end)
    end)

    describe("error handling", function()
        it("errors on unknown shape type", function()
            assert.has_error(function()
                shapes.createShape('nonexistent', { radius = 50, width = 50, height = 50 })
            end)
        end)

        it("errors on custom without optionalVertices", function()
            assert.has_error(function()
                shapes.createShape('custom', { radius = 1, width = 1, height = 1 })
            end)
        end)

        it("treats zero radius as 1", function()
            local shapesList = shapes.createShape('circle', { radius = 0, width = 1, height = 1 })
            assert.are.equal(1, #shapesList)
            assert.is_near(1, shapesList[1]:getRadius(), 0.001)
        end)
    end)
end)

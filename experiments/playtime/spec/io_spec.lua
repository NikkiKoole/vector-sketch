-- spec/io_spec.lua
-- Tests for src/io.lua — save/load, clone, dimension gating
-- io.lua requires love (via uuid.lua), so all tests need LÖVE.
-- Run with: love . --specs

if not love then return end

-- registry.reset() calls global 'snap.rebuildSnapFixtures' — provide stubs in _G
if not rawget(_G, 'snap') then
    rawset(_G, 'snap', { rebuildSnapFixtures = function() end, resetList = function() end, onSceneLoaded = function() end })
end
if not rawget(_G, 'logger') then
    rawset(_G, 'logger', { info = function() end, error = function() end, debug = function() end, trace = function() end })
end
if not rawget(_G, 'registry') then
    rawset(_G, 'registry', require('src.registry'))
end

package.loaded['src.io'] = nil
local eio = require('src.io')
local t = eio._test
local registry = require('src.registry')
local utils = require('src.utils')

-- ─── needsDimProperty (pure logic, but loaded via LÖVE) ───

describe("io._test.needsDimProperty", function()

    -- All shape types in the system
    local radiusShapes = { 'circle', 'triangle', 'pentagon', 'hexagon', 'heptagon', 'octagon' }
    local dimShapes = { 'rectangle', 'capsule', 'torso', 'trapezium', 'ribbon', 'itriangle', 'shape8' }

    describe("radius", function()
        for _, shape in ipairs(radiusShapes) do
            it("is needed for " .. shape, function()
                assert.is_truthy(t.needsDimProperty('radius', shape))
            end)
        end

        for _, shape in ipairs(dimShapes) do
            it("is NOT needed for " .. shape, function()
                assert.is_falsy(t.needsDimProperty('radius', shape))
            end)
        end
    end)

    describe("width and height", function()
        for _, shape in ipairs(radiusShapes) do
            it("width is NOT needed for " .. shape, function()
                assert.is_falsy(t.needsDimProperty('width', shape))
            end)
            it("height is NOT needed for " .. shape, function()
                assert.is_falsy(t.needsDimProperty('height', shape))
            end)
        end

        it("width is NOT needed for custom", function()
            assert.is_falsy(t.needsDimProperty('width', 'custom'))
        end)

        for _, shape in ipairs({ 'rectangle', 'capsule', 'torso', 'trapezium' }) do
            it("width is needed for " .. shape, function()
                assert.is_truthy(t.needsDimProperty('width', shape))
            end)
            it("height is needed for " .. shape, function()
                assert.is_truthy(t.needsDimProperty('height', shape))
            end)
        end
    end)

    describe("width2", function()
        it("is needed for torso", function()
            assert.is_truthy(t.needsDimProperty('width2', 'torso'))
        end)

        it("is needed for trapezium", function()
            assert.is_truthy(t.needsDimProperty('width2', 'trapezium'))
        end)

        it("is NOT needed for rectangle", function()
            assert.is_falsy(t.needsDimProperty('width2', 'rectangle'))
        end)

        it("is NOT needed for capsule", function()
            assert.is_falsy(t.needsDimProperty('width2', 'capsule'))
        end)
    end)

    describe("height2", function()
        it("is needed for torso", function()
            assert.is_truthy(t.needsDimProperty('height2', 'torso'))
        end)

        it("is needed for capsule", function()
            assert.is_truthy(t.needsDimProperty('height2', 'capsule'))
        end)

        it("is NOT needed for rectangle", function()
            assert.is_falsy(t.needsDimProperty('height2', 'rectangle'))
        end)
    end)

    describe("torso-only properties", function()
        local torsoOnly = { 'width3', 'height3', 'height4' }
        for _, prop in ipairs(torsoOnly) do
            it(prop .. " is needed for torso", function()
                assert.is_truthy(t.needsDimProperty(prop, 'torso'))
            end)

            it(prop .. " is NOT needed for rectangle", function()
                assert.is_falsy(t.needsDimProperty(prop, 'rectangle'))
            end)

            it(prop .. " is NOT needed for capsule", function()
                assert.is_falsy(t.needsDimProperty(prop, 'capsule'))
            end)
        end
    end)

    describe("edge cases", function()
        it("returns nil for unknown properties", function()
            assert.is_nil(t.needsDimProperty('nonexistent', 'rectangle'))
        end)

        it("returns false for unknown shapes on radius", function()
            assert.is_false(t.needsDimProperty('radius', 'unknownShape'))
        end)
    end)
end)

-- ─── remapAndRestoreInfluences (ID remapping portion) ───

describe("io._test.remapAndRestoreInfluences (ID remapping)", function()

    it("remaps nodeId through idMapping", function()
        local influences = {
            [1] = {
                { nodeId = "old1", nodeType = "anchor", side = nil },
                { nodeId = "old2", nodeType = "joint", side = "A" },
            },
            [2] = {
                { nodeId = "old1", nodeType = "anchor", side = nil },
            },
        }
        local idMapping = { old1 = "new1", old2 = "new2" }

        t.remapAndRestoreInfluences(influences, idMapping)

        assert.are.equal("new1", influences[1][1].nodeId)
        assert.are.equal("new2", influences[1][2].nodeId)
        assert.are.equal("new1", influences[2][1].nodeId)
    end)

    it("sets nodeId to nil when mapping is missing", function()
        local influences = {
            [1] = {
                { nodeId = "old1", nodeType = "anchor", side = nil },
            },
        }
        local idMapping = {}

        t.remapAndRestoreInfluences(influences, idMapping)

        assert.is_nil(influences[1][1].nodeId)
    end)

    it("handles nil influences gracefully", function()
        assert.has_no.errors(function()
            t.remapAndRestoreInfluences(nil, { a = "b" })
        end)
    end)

    it("handles empty influences", function()
        assert.has_no.errors(function()
            t.remapAndRestoreInfluences({}, { a = "b" })
        end)
    end)
end)

-- ─── gatherSaveData integration tests ───

describe("io.gatherSaveData (LÖVE integration)", function()

    local world
    local cam = {
        getTranslation = function() return 0, 0 end,
        getScale = function() return 1 end,
        getRotation = function() return 0 end
    }

    before_each(function()
        world = love.physics.newWorld(0, 9.81 * 100, true)
        registry.reset()
    end)

    after_each(function()
        if world and not world:isDestroyed() then
            world:destroy()
        end
    end)

    it("returns valid structure for empty world", function()
        local data = eio.gatherSaveData(world, cam)
        assert.is_not_nil(data)
        assert.is_not_nil(data.bodies)
        assert.is_not_nil(data.joints)
        assert.is_not_nil(data.camera)
        assert.are.equal(0, #data.bodies)
    end)

    it("captures body with thing userData", function()
        local body = love.physics.newBody(world, 100, 200, "dynamic")
        love.physics.newFixture(body, love.physics.newRectangleShape(50, 50))
        body:setUserData({
            thing = {
                id = "test1", label = "torso", shapeType = "rectangle",
                width = 50, height = 50, radius = 25, mirrorX = 1, mirrorY = 1,
            }
        })
        registry.registerBody("test1", body)

        local data = eio.gatherSaveData(world, cam)

        assert.are.equal(1, #data.bodies)
        assert.are.equal("test1", data.bodies[1].id)
        assert.are.equal("torso", data.bodies[1].label)
        assert.are.equal("rectangle", data.bodies[1].shapeType)
        assert.is_near(100, data.bodies[1].position[1], 0.01)
        assert.is_near(200, data.bodies[1].position[2], 0.01)
    end)

    it("gates dims by shape type", function()
        local body = love.physics.newBody(world, 0, 0, "dynamic")
        love.physics.newFixture(body, love.physics.newCircleShape(30))
        body:setUserData({
            thing = {
                id = "circ1", label = "ball", shapeType = "circle",
                radius = 30, width = 999, height = 999,
            }
        })
        registry.registerBody("circ1", body)

        local data = eio.gatherSaveData(world, cam)

        assert.are.equal(30, data.bodies[1].dims.radius)
        assert.is_nil(data.bodies[1].dims.width)
        assert.is_nil(data.bodies[1].dims.height)
    end)

    it("saves shared fixture data from non-userData fixture", function()
        local body = love.physics.newBody(world, 0, 0, "dynamic")
        local fixture = love.physics.newFixture(body, love.physics.newRectangleShape(50, 50))
        fixture:setDensity(2.5)
        fixture:setFriction(0.7)
        fixture:setRestitution(0.3)
        body:setUserData({
            thing = {
                id = "box1", label = "box", shapeType = "rectangle",
                width = 50, height = 50, radius = 1,
            }
        })
        registry.registerBody("box1", body)

        local data = eio.gatherSaveData(world, cam)

        assert.is_near(2.5, data.bodies[1].sharedFixtureData.density, 0.01)
        assert.is_near(0.7, data.bodies[1].sharedFixtureData.friction, 0.01)
        assert.is_near(0.3, data.bodies[1].sharedFixtureData.restitution, 0.01)
    end)

    it("skips bodies without thing userData", function()
        -- Body without userData
        local body1 = love.physics.newBody(world, 0, 0, "dynamic")
        love.physics.newFixture(body1, love.physics.newCircleShape(10))

        -- Body with userData
        local body2 = love.physics.newBody(world, 0, 0, "dynamic")
        love.physics.newFixture(body2, love.physics.newCircleShape(10))
        body2:setUserData({
            thing = { id = "b2", label = "kept", shapeType = "circle", radius = 10 }
        })
        registry.registerBody("b2", body2)

        local data = eio.gatherSaveData(world, cam)

        assert.are.equal(1, #data.bodies)
        assert.are.equal("b2", data.bodies[1].id)
    end)

    it("preserves body type", function()
        for _, bodyType in ipairs({ "dynamic", "static", "kinematic" }) do
            local body = love.physics.newBody(world, 0, 0, bodyType)
            love.physics.newFixture(body, love.physics.newCircleShape(10))
            local id = "bt_" .. bodyType
            body:setUserData({
                thing = { id = id, label = bodyType, shapeType = "circle", radius = 10 }
            })
            registry.registerBody(id, body)
        end

        local data = eio.gatherSaveData(world, cam)
        assert.are.equal(3, #data.bodies)

        local types = {}
        for _, b in ipairs(data.bodies) do types[b.label] = b.bodyType end
        assert.are.equal("dynamic", types["dynamic"])
        assert.are.equal("static", types["static"])
        assert.are.equal("kinematic", types["kinematic"])
    end)

    it("saves camera state", function()
        local myCam = {
            getTranslation = function() return 500, 300 end,
            getScale = function() return 2.5 end,
            getRotation = function() return 0 end
        }

        local data = eio.gatherSaveData(world, myCam)

        assert.are.equal(500, data.camera.x)
        assert.are.equal(300, data.camera.y)
        assert.are.equal(2.5, data.camera.scale)
    end)
end)

-- spec/polygon-safety_spec.lua
-- Points in a line can crash LÖVE 11.5's Box2D outright, past any pcall (docs/MEASURING.md M6), so
-- every polygon goes to Box2D through shapes.newPolygon (polygon.dropCollinear first). Here a guard in
-- front of love.physics.newPolygonShape refuses, with a plain error, a polygon that still has such
-- points, and each path that makes polygons is fed one: a custom shape, a capsule whose corners
-- meet, a sensor's outline edited by hand, a saved scene.
-- Run with: love . --specs spec/polygon-safety_spec.lua

if not love then return end

local polygon = require('src.polygon')
local shapes = require('src.shapes')
local ST = require('src.shape-types')
local fixtures = require('src.fixtures')
local state = require('src.state')
local registry = require('src.registry')
local sceneIO = require('src.io')
local camera = require('src.camera')

describe('polygons reaching Box2D', function()
    local realNew, world

    before_each(function()
        realNew = love.physics.newPolygonShape
        love.physics.newPolygonShape = function(...)
            local points = type((...)) == 'table' and (...) or { ... }
            local cleaned = polygon.dropCollinear(points)
            if #cleaned < #points then
                error('in-line points reached Box2D: ' .. table.concat(points, ','), 2)
            end
            return realNew(...)
        end
        registry.reset()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
    end)

    after_each(function()
        love.physics.newPolygonShape = realNew
        world:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    -- a box with an extra point halfway along its top edge
    local BOX = { -40, -30, 0, -30, 40, -30, 40, 30, -40, 30 }

    it('makes a custom shape from an outline with a point halfway along an edge', function()
        local list = shapes.createShape(ST.CUSTOM, { optionalVertices = BOX, width = 80, height = 60 })
        assert.are.equal(1, #list)
        assert.are.equal(4, select('#', list[1]:getPoints()) / 2)
    end)

    it('makes a capsule whose rounded corners meet', function()
        local list = shapes.createShape(ST.CAPSULE, { width = 40, height = 40, width2 = 2 })
        assert.are.equal(1, #list)
    end)

    it('takes a hand-edited sensor outline with a point halfway along an edge', function()
        local body = love.physics.newBody(world, 0, 0, 'dynamic')
        local fixture = fixtures.createSFixture(body, 0, 0, 'texfixture', { label = 'x', width = 80, height = 60 })
        local replaced = fixtures.replaceShape(fixture, BOX)
        assert.are.equal(4, select('#', replaced:getShape():getPoints()) / 2)
    end)

    it('loads a saved polygon with a point halfway along an edge', function()
        local data = love.filesystem.read('scripts/tests/meta.playtime.json')
        local json = require('vendor.dkjson')
        local scene = json.decode(data)
        local body = scene.bodies[1]
        local fixture
        for _, f in ipairs(body.fixtures) do
            if not f.userData and f.points then fixture = f end
        end
        assert.is_truthy(fixture, 'the scene has a plain polygon fixture to change')
        local p = fixture.points
        -- a point halfway between the first two
        table.insert(p, 3, (p[1] + p[3]) / 2)
        table.insert(p, 4, (p[2] + p[4]) / 2)
        sceneIO.load(json.encode(scene), world, camera.getInstance())
        local loaded = registry.getBodyByID(body.id)
        assert.is_truthy(loaded, 'the body loaded')
        local polygons = 0
        for _, f in ipairs(loaded:getFixtures()) do
            if f:getShape():typeOf('PolygonShape') and not f:getUserData() then polygons = polygons + 1 end
        end
        assert.is_true(polygons > 0, 'the polygon came back, not dropped')
    end)
end)

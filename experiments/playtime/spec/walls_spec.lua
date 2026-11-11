-- spec/walls_spec.lua
-- Walls as things (src/walls.lua): a 'wall' sfixture makes its body a wall that touches nothing and stays
-- put, grouped by how far behind it is (a shadow pass per distance); the light's 'falls on' picks the
-- walls by itself when a scene has any (src/scene-light.lua), each distance its own shadow length.
-- Run with: love . --specs spec/walls_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')
local walls = require('src.walls')
local sceneLight = require('src.scene-light')

local function makeWall(x, behind)
    local thing = objectManager.addThing('rectangle', { x = x, y = 0, width = 400, height = 300,
        bodyType = 'dynamic' })
    local fixture = fixtures.createSFixture(thing.body, 0, 0, subtypes.WALL, { radius = 20 })
    fixture:getUserData().extra.behind = behind
    return thing
end

describe('walls', function()
    before_each(function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        sceneLight.load(nil)
    end)

    after_each(function()
        sceneLight.load(nil)
        state.backdropShadows = nil
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it('a wall touches nothing and stays put', function()
        local thing = makeWall(0, 90)
        walls.update()
        assert.are.equal('static', thing.body:getType())
        for _, fixture in ipairs(thing.body:getFixtures()) do
            assert.is_true(fixture:isSensor())
        end
        assert.is_true(walls.isWallBody(thing.body))
    end)

    it('groups walls by how far behind they are, nearest first', function()
        makeWall(0, 400)
        makeWall(500, 90)
        makeWall(1000, 90)
        local layers, key = walls.layers()
        assert.are.equal(2, #layers)
        assert.are.equal(90, layers[1].behind)
        assert.are.equal(400, layers[2].behind)
        assert.is_true(#key > 0)
    end)

    it("the light's shadows fall on the walls, a further wall's longer", function()
        makeWall(0, 90)
        makeWall(500, 400)
        sceneLight.load({ level = 'shadows' })
        sceneLight.apply()
        assert.are.equal('walls', sceneLight.wallOf(sceneLight.settings()))
        local layers = state.backdropShadows and state.backdropShadows.layers
        assert.is_truthy(layers)
        assert.are.equal(2, #layers)
        local near, far = layers[1].offset, layers[2].offset
        assert.is_true(math.abs(far[1]) > math.abs(near[1]), 'further back, a longer shadow')
        assert.is_true(layers[2].blur > layers[1].blur, 'and softer')
    end)
end)

-- spec/depth-layers_spec.lua
-- Back / play / front for bodies (src/depth-layers.lua, DEPTH-LAYERS DL1), with real Box2D: what moves around
-- passes in front of a back body but stands on its top, never touches a front body, and layered bodies stand
-- on the ground.
-- Run with: love . --specs spec/depth-layers_spec.lua

if not love then return end

local depthLayers = require('src.depth-layers')

local function box(world, x, y, w, h, kind, layer)
    local body = love.physics.newBody(world, x, y, kind)
    love.physics.newFixture(body, love.physics.newRectangleShape(w, h), 1)
    body:setUserData({ thing = { layer = layer } })
    return body
end

local function run(world, seconds)
    for _ = 1, math.floor(seconds * 60) do world:update(1 / 60) end
end

describe('depth layers', function()
    local world

    before_each(function()
        world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        world:setCallbacks(nil, function(a, b) depthLayers.onEndContact(a, b) end,
            function(a, b, contact) depthLayers.onPreSolve(a, b, contact) end, nil)
        box(world, 0, 500, 4000, 100, 'static', nil) -- the ground, its top at 450
    end)

    after_each(function() world:destroy() end)

    it('stands a toy on a back block\'s top', function()
        box(world, 0, 350, 400, 200, 'static', 'back') -- top at 250
        local toy = box(world, 0, 100, 60, 60, 'dynamic', nil)
        run(world, 2)
        local _, y = toy:getPosition()
        assert.is_true(math.abs(y - 220) < 6, 'on the top (y 220), at ' .. y)
    end)

    it('lets a toy pass in front of a back block from the side', function()
        box(world, 0, 350, 400, 200, 'static', 'back')
        local toy = box(world, -400, 420, 60, 60, 'dynamic', nil) -- on the ground, left of the block
        toy:setLinearVelocity(600, 0)
        run(world, 1.5)
        local x = toy:getPosition()
        assert.is_true(x > 0, 'went past the block\'s middle, at x ' .. x)
    end)

    it('never lets a toy touch a front block', function()
        box(world, 0, 350, 400, 200, 'static', 'front')
        local toy = box(world, 0, 100, 60, 60, 'dynamic', nil)
        run(world, 2)
        local _, y = toy:getPosition()
        assert.is_true(math.abs(y - 420) < 6, 'fell through to the ground (y 420), at ' .. y)
    end)

    it('stands a loose back block on the ground', function()
        local block = box(world, 0, 300, 200, 100, 'dynamic', 'back')
        run(world, 2)
        local _, y = block:getPosition()
        assert.is_true(math.abs(y - 400) < 6, 'on the ground (y 400), at ' .. y)
    end)

    it('draws back pictures below and front ones above the Mipos', function()
        local back = box(world, 0, 0, 10, 10, 'static', 'back')
        local front = box(world, 0, 0, 10, 10, 'static', 'front')
        local play = box(world, 0, 0, 10, 10, 'static', nil)
        assert.is_true(depthLayers.zOffset(back) < -100000)
        assert.is_true(depthLayers.zOffset(front) > 100000)
        assert.are.equal(0, depthLayers.zOffset(play))
    end)

    it('stands a toy on a turned back plank\'s top, not on its side', function()
        local plank = box(world, 0, 250, 400, 60, 'static', 'back') -- turned upright: its top at 50
        plank:setAngle(math.pi / 2)
        local toy = box(world, 0, -200, 40, 40, 'dynamic', nil)
        run(world, 2)
        local _, y = toy:getPosition()
        assert.is_true(math.abs(y - 30) < 6, 'on the upright plank\'s end (y 30), at ' .. y)
        local side = box(world, 0, 150, 40, 40, 'dynamic', nil) -- dropped in front of its middle
        run(world, 2)
        local _, sy = side:getPosition()
        assert.is_true(math.abs(sy - 430) < 6, 'fell past to the ground (y 430), at ' .. sy)
    end)

    -- one body in several layers (a plank boat): a fixture's own layer
    it('gives one fixture of a body its own layer', function()
        local boat = love.physics.newBody(world, 0, 400, 'static')
        love.physics.newFixture(boat, love.physics.newRectangleShape(-300, 0, 200, 40), 1) -- play: solid
        local back = love.physics.newFixture(boat, love.physics.newRectangleShape(0, -100, 200, 240), 1)
        local front = love.physics.newFixture(boat, love.physics.newRectangleShape(300, -100, 200, 240), 1)
        depthLayers.setFixtureLayer(back, 'back')
        depthLayers.setFixtureLayer(front, 'front')
        local onPlay = box(world, -300, 200, 40, 40, 'dynamic', nil)
        local onBack = box(world, 0, 0, 40, 40, 'dynamic', nil)
        local throughFront = box(world, 300, 0, 40, 40, 'dynamic', nil)
        run(world, 2)
        local _, y1 = onPlay:getPosition()
        local _, y2 = onBack:getPosition()
        local _, y3 = throughFront:getPosition()
        assert.is_true(math.abs(y1 - 360) < 6, 'on the play fixture (y 360), at ' .. y1)
        assert.is_true(math.abs(y2 - 160) < 6, 'on the back fixture\'s top (y 160), at ' .. y2)
        assert.is_true(math.abs(y3 - 430) < 6, 'through the front fixture to the ground (y 430), at ' .. y3)
        depthLayers.setFixtureLayer(back, nil)
        depthLayers.setFixtureLayer(front, nil)
    end)

    -- DL3: Fabuland's parts get their layer when made (src/fabuland.lua PARTS)
    it('makes Fabuland\'s blocks back, its railing front, its planks play', function()
        local state = require('src.state')
        local registry = require('src.registry')
        local fabuland = require('src.fabuland')
        registry.reset()
        local was = state.physicsWorld
        state.physicsWorld = world
        local door = fabuland.make('door block', 0, 0, 'red')
        local railing = fabuland.make('railing', 2000, 0, 'white')
        local plank = fabuland.make('plank', 4000, 0, 'brown')
        state.physicsWorld = was
        assert.are.equal('back', depthLayers.of(door.body))
        assert.are.equal('front', depthLayers.of(railing.body))
        assert.are.equal('play', depthLayers.of(plank.body))
        registry.reset()
    end)
end)

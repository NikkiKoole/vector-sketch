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
end)

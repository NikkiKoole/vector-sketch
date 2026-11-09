-- spec/light-pick_spec.lua
-- Each part gets the lights that reach it most (src/render/shaders.lua pickLights, LIGHT-AND-SHADOW
-- LS27): with up to 8 on, every one as before; with more, the ones without falloff (sky, a sun) always,
-- then the nearest and strongest; one that doesn't reach the part is left out; a part no light reaches
-- gets one dark light (not the shader's own default); a ribbon (no body) picks by the place it's given.
-- Run with: love . --specs spec/light-pick_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')
local shaders = require('src.render.shaders')

local function lamp(x, y, extra)
    local holder = objectManager.addThing('rectangle', { x = x, y = y, width = 10, height = 10, bodyType = 'static' })
    local light = fixtures.createSFixture(holder.body, 0, 0, subtypes.LIGHT, { radius = 10 })
    for k, v in pairs(extra) do light:getUserData().extra[k] = v end
    return light:getUserData().extra
end

-- the intensities and colours handed over, copied out (the buffers are reused)
local function gather(body, at)
    local count, _, colour, intensity = shaders.gatherLightsForBody(body, 1, 1, at)
    local out = { count = count }
    for i = 1, count do out[i] = { r = colour[i][1], intensity = intensity[i] } end
    return out
end

local function has(got, intensity)
    for i = 1, got.count do
        if math.abs(got[i].intensity - intensity) < 1e-9 then return true end
    end
    return false
end

describe('each part gets the lights that reach it most', function()
    before_each(function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
    end)

    after_each(function()
        shaders.frameCaching = nil
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    local function part(x, y)
        return objectManager.addThing('rectangle', { x = x, y = y, width = 50, height = 50, bodyType = 'dynamic' }).body
    end

    it('up to 8 lights: all of them, near or far', function()
        for i = 1, 6 do lamp(i * 5000, 0, { lightType = 'point', intensity = i / 10, range = 300 }) end
        lamp(0, -600, { lightType = 'sky', intensity = 0.5 })
        local got = gather(part(0, 0))
        assert.are.equal(7, got.count)
    end)

    it('more than 8: the sky and a sun always, then the nearest; the far ones left out', function()
        lamp(0, -600, { lightType = 'sky', intensity = 0.5 })
        lamp(-900, -900, { lightType = 'directional', intensity = 1.1, range = 0 }) -- a sun: no falloff
        -- twelve bulbs in a row, 1000 apart, each reaching 1600
        for i = 1, 12 do lamp(i * 1000, -300, { lightType = 'point', intensity = 1 + i / 100, range = 1600 }) end
        local got = gather(part(1000, 0))
        assert.is_true(got.count <= 8)
        assert.is_true(has(got, 0.5))
        assert.is_true(has(got, 1.1))
        assert.is_true(has(got, 1.01)) -- the bulb right above
        assert.is_true(has(got, 1.02)) -- its neighbour
        assert.is_false(has(got, 1.12)) -- 11000 away
    end)

    it('the strongest win when more reach than fit', function()
        for i = 1, 12 do lamp(i, 0, { lightType = 'point', intensity = i / 10, range = 2000 }) end
        local got = gather(part(0, 0))
        assert.are.equal(8, got.count)
        assert.is_true(has(got, 1.2))
        assert.is_true(has(got, 0.5))
        assert.is_false(has(got, 0.4))
    end)

    it('a part none of the lights reach: one dark light', function()
        for i = 1, 9 do lamp(i * 10, 0, { lightType = 'point', intensity = 1, range = 300 }) end
        local got = gather(part(50000, 0))
        assert.are.equal(1, got.count)
        assert.are.equal(0, got[1].intensity)
    end)

    it('a ribbon picks by the place it is given', function()
        for i = 1, 12 do lamp(i * 1000, 0, { lightType = 'point', intensity = 1 + i / 100, range = 1600 }) end
        local near = gather(nil, { 12000, 0 })
        assert.is_true(has(near, 1.12))
        assert.is_false(has(near, 1.01))
        -- no place: the first 8 (the material picker's swatch)
        assert.are.equal(8, gather(nil).count)
    end)
end)

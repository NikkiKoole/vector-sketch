-- spec/light-cache_spec.lua
-- The lights worked out once a frame (src/render/shaders.lua newFrame / gatherLightsForBody): each lit
-- part gets exactly the numbers it got when every part worked them out itself, for a turned body and a
-- ribbon (no body); a light added within the frame is seen; a new frame sees a light that moved.
-- Run with: love . --specs spec/light-cache_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')
local shaders = require('src.render.shaders')

local function lamp(x, y, angle, extra)
    local holder = objectManager.addThing('rectangle', { x = x, y = y, width = 10, height = 10, bodyType = 'static' })
    holder.body:setAngle(angle or 0)
    local light = fixtures.createSFixture(holder.body, 0, 0, subtypes.LIGHT, { radius = 10 })
    for k, v in pairs(extra) do light:getUserData().extra[k] = v end
    return holder.body
end

-- what gather hands the shader, copied out (the buffers are reused)
local function snapshot(body, fx, fy)
    local count, dir, colour, intensity = shaders.gatherLightsForBody(body, fx, fy)
    local out = { count = count }
    for i = 1, count do
        out[i] = { dir[i][1], dir[i][2], colour[i][1], colour[i][2], colour[i][3], intensity[i] }
    end
    return out
end

local function same(a, b)
    assert.are.equal(a.count, b.count)
    for i = 1, a.count do
        for k = 1, 6 do assert.is_true(math.abs(a[i][k] - b[i][k]) < 1e-9) end
    end
end

describe('lights worked out once a frame', function()
    local part

    before_each(function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        lamp(-300, -200, 0.7, { lightType = 'directional', intensity = 1.2, colorHex = 'ffd890ff' })
        lamp(250, 50, 0, { lightType = 'point', intensity = 0.8, colorHex = 'a8c0ffff', range = 900 })
        lamp(0, -600, 0, { lightType = 'sky', intensity = 0.5, colorHex = '9cc8ffff', groundHex = '8a7a50ff' })
        part = objectManager.addThing('rectangle', { x = 40, y = 30, width = 50, height = 50, bodyType = 'dynamic' })
        part.body:setAngle(1.1)
    end)

    after_each(function()
        shaders.frameCaching = nil
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it('hands a part the same numbers as working them out per part', function()
        shaders.frameCaching = nil
        local perPart = snapshot(part.body, -1, 1)
        local ribbonPerPart = snapshot(nil)
        shaders.newFrame()
        same(perPart, snapshot(part.body, -1, 1))
        same(ribbonPerPart, snapshot(nil))
        same(perPart, snapshot(part.body, -1, 1)) -- the second part in the frame, from the cache
    end)

    it('sees a light added within the frame, and one moved in the next frame', function()
        shaders.newFrame()
        local before = snapshot(part.body)
        local moved = lamp(600, 300, 0, { lightType = 'point', intensity = 1, range = 2000 })
        assert.are.equal(before.count + 1, snapshot(part.body).count)
        moved:setPosition(-600, 300)
        shaders.newFrame()
        local _, _, _, _ = shaders.gatherLightsForBody(part.body)
        shaders.frameCaching = nil
        local fresh = snapshot(part.body)
        shaders.newFrame()
        same(fresh, snapshot(part.body))
    end)
end)

describe('uniforms sent only when they change', function()
    after_each(function()
        shaders.frameCaching = nil
        if state.physicsWorld then state.physicsWorld:destroy() end
        state.physicsWorld = nil
        registry.reset()
    end)

    -- one part drawn alone vs after a run of differently set parts: the same pixels, so a skipped
    -- send never leaves a part with another's setting
    it('a part draws the same after other parts with other settings', function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        lamp(-300, -200, 0.7, { lightType = 'directional', intensity = 1.2, colorHex = 'ffd890ff' })
        local img = love.graphics.newImage('textures/mipo/body/body-03-mask.png')
        local canvas = love.graphics.newCanvas(64, 64)
        local function drawWith(extra)
            love.graphics.setCanvas(canvas)
            love.graphics.clear(0, 0, 0, 0)
            love.graphics.setColor(0.8, 0.5, 0.4, 1)
            local shaded = shaders.setSurfaceShader(extra, nil)
            love.graphics.draw(img, 0, 0, 0, 64 / img:getWidth(), 64 / img:getHeight())
            if shaded then love.graphics.setShader() end
            love.graphics.setCanvas()
            return canvas:newImageData():encode('png'):getString()
        end
        local target = { plasticine = true, plasticineStrength = 0.3, plasticineWarmHex = 'ffaa88ff' }
        local alone = drawWith(target)
        drawWith({ plasticine = true, plasticineStrength = 0.05, plasticineWarmHex = '88aaffff', material = 'brass' })
        drawWith({ hairs = true })
        drawWith({ material = 'velvet', plasticineLightAdd = true })
        assert.are.equal(alone, drawWith(target))
    end)
end)

-- spec/camera-follow_spec.lua
-- The follow camera (src/camera-follow.lua): it follows a pinned body while
-- playing, stays put while paused or switched off, leaves the camera to you after
-- a manual pan; bounds, zoom limits, edge pan, scripted zoom/shake, save/load.
-- Run with: love . --specs spec/camera-follow_spec.lua

if not love then return end

local state = require('src.state')
local camera = require('src.camera')
local cameraFollow = require('src.camera-follow')

describe('camera follow', function()
    local world, body, cam
    local saved

    before_each(function()
        saved = { paused = state.world.paused, settings = state.cameraSettings }
        world = love.physics.newWorld(0, 0, true)
        body = love.physics.newBody(world, 2000, 0, 'dynamic')
        love.physics.newFixture(body, love.physics.newCircleShape(20))
        cam = camera.getInstance()
        cam:setScale(1)
        cam:setTranslation(0, 0)
        state.world.paused = false
        cameraFollow.loadSettings(nil)
        cameraFollow.pin(body)
    end)

    after_each(function()
        cameraFollow.pin(nil)
        state.cameraFollow.last = nil
        state.world.paused, state.cameraSettings = saved.paused, saved.settings
        world:destroy()
    end)

    local function run(seconds)
        for _ = 1, math.floor(seconds * 60) do cameraFollow.update(1 / 60) end
        return cam:getTranslation()
    end

    it('follows a pinned body while playing, up to the dead zone', function()
        local x, y = run(5)
        local w = love.graphics.getDimensions()
        assert.is_true(x > 2000 - w * cameraFollow.settings().deadZone - 5, 'x ' .. x)
        assert.is_true(x <= 2000, 'x ' .. x)
        assert.is_true(math.abs(y) < 1)
        assert.is_true(cameraFollow.isPinned(body))
    end)

    it('stays put while paused', function()
        state.world.paused = true
        assert.are.equal(0, (run(2)))
    end)

    it('stays put when switched off', function()
        cameraFollow.settings().follow = false
        assert.are.equal(0, (run(2)))
    end)

    it('leaves the camera alone after a manual pan', function()
        cameraFollow.notePan()
        assert.are.equal(0, (run(2)))
    end)

    it('unpinned and untouched, follows nothing', function()
        cameraFollow.pin(nil)
        state.cameraFollow.last = nil
        assert.are.equal(0, (run(2)))
    end)

    it('keeps the view inside the bounds while playing', function()
        local w, h = love.graphics.getDimensions()
        cameraFollow.script.setBounds(-1000, -500, 1000, 500)
        local x = run(5)
        assert.is_true(math.abs(x - (1000 - w / 2)) < 0.01, 'x ' .. x)
        -- the bounds also set the smallest zoom: the view can't be bigger than them
        cam:setScale(0.01)
        run(0.1)
        assert.is_true(cam.scale >= math.max(w / 2000, h / 1000) - 1e-6)
    end)

    it('ignores the bounds while paused (editing)', function()
        cameraFollow.script.setBounds(-100, -100, 100, 100)
        state.world.paused = true
        cam:setTranslation(5000, 0)
        assert.are.equal(5000, (run(1)))
    end)

    it('pans when the mouse is in the edge margin', function()
        local w, h = love.graphics.getDimensions()
        local dx, dy = cameraFollow.edgePan(1 / 60, w - 1, h / 2)
        assert.is_true(dx > 0 and dy == 0)
        dx = cameraFollow.edgePan(1 / 60, 0, h / 2)
        assert.is_true(dx < 0)
        dx, dy = cameraFollow.edgePan(1 / 60, w / 2, h / 2)
        assert.are.equal(0, dx); assert.are.equal(0, dy)
        cameraFollow.settings().edgePan = false
        assert.are.equal(0, (cameraFollow.edgePan(1 / 60, w - 1, h / 2)))
    end)

    it('stops edge panning when the dragged thing is stuck behind the cursor', function()
        local w, h = love.graphics.getDimensions()
        local mx, my = w - 1, h / 2
        local atX, atY = cam:getWorldCoordinates(mx, my)
        assert.is_true((cameraFollow.edgePan(1 / 60, mx, my, atX, atY)) > 0)       -- held at the cursor
        local farX, farY = cam:getWorldCoordinates(mx - 400, my)
        assert.are.equal(0, (cameraFollow.edgePan(1 / 60, mx, my, farX, farY)))  -- stuck 400px back
    end)

    it('zooms to a scale over time and shakes back to rest', function()
        cameraFollow.pin(nil); state.cameraFollow.last = nil
        cameraFollow.script.zoomTo(2, 0.5)
        run(1)
        assert.is_true(math.abs(cam.scale - 2) < 1e-6)
        cameraFollow.script.shake(30, 0.3)
        run(0.1)
        run(0.5)
        local x, y = cam:getTranslation()
        assert.are.equal(0, x); assert.are.equal(0, y)
    end)

    it('round-trips its settings, and a scene without any gets the defaults', function()
        cameraFollow.settings().speed = 7
        cameraFollow.script.setBounds(0, 0, 10, 20)
        local data = cameraFollow.saveSettings()
        cameraFollow.loadSettings(nil)
        assert.are.equal(cameraFollow.defaults.speed, cameraFollow.settings().speed)
        assert.is_nil(cameraFollow.settings().bounds)
        cameraFollow.loadSettings(data)
        assert.are.equal(7, cameraFollow.settings().speed)
        assert.are.same({ 0, 0, 10, 20 }, cameraFollow.settings().bounds)
    end)
end)

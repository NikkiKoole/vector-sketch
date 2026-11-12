-- spec/vehicle-rides_spec.lua: Mipos in vehicles, and driving them (src/vehicle-rides.lua, docs/KINDS.md KD4c):
-- let go over a vehicle a Mipo gets in, each type seats it, driving moves it, an empty one doesn't drive,
-- turning round, the rider out, a deleted vehicle lets its rider go.
-- Run with: love . --specs spec/vehicle-rides_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local kinds = require('src.kinds')
local rides = require('src.vehicle-rides')
local CM = require('src.character-manager')
local mipoRegistry = require('src.mipo-registry')

describe('vehicle rides', function()
    local world

    local function step(seconds)
        for _ = 1, math.floor(seconds * 60) do
            world:update(1 / 60)
            rides.update(1 / 60)
        end
    end

    before_each(function()
        world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        state.physicsWorld = world
        registry.reset()
        mipoRegistry.reset()
        kinds.reset()
        rides.unload()
        local floor = love.physics.newBody(world, 0, 400, 'static')
        love.physics.newFixture(floor, love.physics.newRectangleShape(60000, 40))
    end)

    after_each(function()
        rides.unload()
        kinds.reset()
        mipoRegistry.reset()
        registry.reset()
        if world and not world:isDestroyed() then world:destroy() end
        state.physicsWorld = nil
        state.playMode = nil
    end)

    local function mipoAt(x, y)
        local inst = CM.createCharacter('humanoid', x, y, 0.3)
        assert.is_not_nil(inst)
        return inst
    end

    it('gets a Mipo in that was let go over it', function()
        local kart = kinds.make('vehicle', { type = 'kart' }, 0, 300)
        step(0.5)
        local fx, fy = kart.parts.frame.body:getPosition()
        local inst = mipoAt(fx, fy - 250)
        state.vehicleRidesHeld = { [inst] = true } -- held last frame, not now: let go
        rides.update(1 / 60)
        assert.are.equal(inst, rides.riderOf(kart))
        step(1)
        assert.are.equal(inst, rides.riderOf(kart)) -- still in after settling
    end)

    it('seats a Mipo in each type', function()
        local x = -6000
        for _, name in ipairs(require('src.vehicles').order) do
            local v = kinds.make('vehicle', { type = name }, x, 300)
            local inst = mipoAt(x, 0)
            assert.is_true(rides.seat(v, inst), name)
            assert.are.equal(inst, rides.riderOf(v), name)
            x = x + 3000
        end
        step(1)
        for _, v in ipairs(kinds.all()) do
            assert.is_not_nil(rides.riderOf(v), v.settings.type .. ' lost its rider')
        end
    end)

    it('drives with a Mipo in it, and coasts when stopped', function()
        local car = kinds.make('vehicle', { type = 'car' }, 0, 300)
        local inst = mipoAt(0, 0)
        rides.seat(car, inst)
        step(0.5)
        local x0 = car.parts.frame.body:getX()
        rides.setGoing(car, true)
        step(2)
        local x1 = car.parts.frame.body:getX()
        assert.is_true(x1 - x0 > 300, 'moved ' .. (x1 - x0))
        assert.are.equal(inst, rides.riderOf(car))
        -- stopped, it coasts (as the spike: the motor lets go, a little rolling drag), slowing
        rides.setGoing(car, false)
        local v0 = car.parts.frame.body:getLinearVelocity()
        step(2)
        local v1 = car.parts.frame.body:getLinearVelocity()
        assert.is_true(math.abs(v1) < math.abs(v0) - 50, 'not slowing: ' .. v0 .. ' -> ' .. v1)
    end)

    it("doesn't drive empty", function()
        local kart = kinds.make('vehicle', { type = 'kart' }, 0, 300)
        step(0.5)
        local x0 = kart.parts.frame.body:getX()
        rides.setGoing(kart, true)
        step(1)
        assert.is_false(rides.isGoing(kart))
        assert.is_true(math.abs(kart.parts.frame.body:getX() - x0) < 20)
    end)

    it('turns round, the rider facing the new way, and lets the rider out', function()
        local kart = kinds.make('vehicle', { type = 'kart' }, 0, 300)
        local inst = mipoAt(0, 0)
        rides.seat(kart, inst)
        rides.turnAround(kart)
        assert.are.equal(inst, rides.riderOf(kart))
        assert.are.equal('left', require('src.mipo-facing').get(inst))
        rides.riderOut(kart)
        assert.is_nil(rides.riderOf(kart))
        assert.is_nil(inst._vehicle)
    end)

    it('a tap drives it in play mode', function()
        local kart = kinds.make('vehicle', { type = 'kart' }, 0, 300)
        local inst = mipoAt(0, 0)
        rides.seat(kart, inst)
        step(0.3)
        state.playMode = true
        local ride = state.vehicleRides[kart.id]
        ride.press = { id = 'test', sx = 0, sy = 0, t = 0.1, lx = 100 } -- pressed on its front, let go
        rides.update(1 / 60)
        assert.is_true(rides.isGoing(kart))
        ride.press = { id = 'test', sx = 0, sy = 0, t = 0.1, lx = 100 } -- its front again: stops
        rides.update(1 / 60)
        assert.is_false(rides.isGoing(kart))
    end)

    it('lets its rider go when the vehicle is deleted', function()
        local kart = kinds.make('vehicle', { type = 'kart' }, 0, 300)
        local inst = mipoAt(0, 0)
        rides.seat(kart, inst)
        kinds.remove(kart)
        rides.update(1 / 60)
        assert.is_nil(inst._vehicle)
        assert.is_nil(state.vehicleRides[kart.id])
    end)
end)

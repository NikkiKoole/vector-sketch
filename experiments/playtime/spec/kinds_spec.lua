-- spec/kinds_spec.lua: things made of bodies (src/kinds.lua, docs/KINDS.md KD4a), with the kart
-- (src/vehicles.lua): made of ordinary things, whole again after a save and load, copied whole with a
-- new id, dissolved to plain bodies, removed with its bodies.
-- Run with: love . --specs spec/kinds_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local kinds = require('src.kinds')
local sceneIO = require('src.io')
local library = require('src.library')
local camera = require('src.camera')

describe('kinds', function()
    local world

    before_each(function()
        world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        state.physicsWorld = world
        registry.reset()
        kinds.reset()
    end)

    after_each(function()
        kinds.reset()
        registry.reset()
        if world and not world:isDestroyed() then world:destroy() end
        state.physicsWorld = nil
    end)

    local function partCount(instance)
        local n = 0
        for _ in pairs(instance.parts) do n = n + 1 end
        return n
    end

    it('makes a kart of a frame and two wheels, each part knowing its instance', function()
        local kart = kinds.make('vehicle', { type = 'kart' }, 0, 0)
        assert.is_not_nil(kart)
        assert.are.equal(3, partCount(kart))
        for name, thing in pairs(kart.parts) do
            local instance, partName = kinds.ofBody(thing.body)
            assert.are.equal(kart, instance)
            assert.are.equal(name, partName)
        end
        assert.are.equal(2, #kart.parts.frame.body:getJoints()) -- the wheels on their joints
        assert.are.equal('kart', kinds.label(kart))
    end)

    it('is whole again after a save and a load', function()
        local kart = kinds.make('vehicle', { type = 'kart', size = 1.5 }, 100, 0)
        local data = sceneIO.gatherSaveData(world, camera.getInstance())
        assert.are.equal(1, #data.kinds)
        assert.are.equal('vehicle', data.kinds[1].kind)
        assert.are.equal(1.5, data.kinds[1].settings.size)
        local id = kart.id
        -- the file's round trip: encoded and decoded, then built into a fresh world
        local json = require('vendor.dkjson')
        local loaded = json.decode(json.encode(data))
        sceneIO.buildWorld(loaded, world, camera.getInstance())
        local again = kinds.getById(id)
        assert.is_not_nil(again)
        assert.are.equal(3, partCount(again))
        assert.are.equal(1.5, again.settings.size)
        assert.are.equal(again, (kinds.ofBody(again.parts.backWheel.body)))
    end)

    it('copies whole, with a new id, from any of its parts', function()
        local kart = kinds.make('vehicle', { type = 'kart' }, 0, 0)
        local copies = library.clone({ kart.parts.frontWheel })
        assert.are.equal(3, #copies)
        local copy = kinds.ofBody(copies[1].body)
        assert.is_not_nil(copy)
        assert.are_not.equal(kart.id, copy.id)
        assert.are.equal(3, partCount(copy))
        assert.are.equal(2, #kinds.all())
        assert.are.equal(kart, (kinds.ofBody(kart.parts.frame.body))) -- the first one is still itself
    end)

    it('dissolves to plain bodies, and is removed with its bodies', function()
        local kart = kinds.make('vehicle', { type = 'kart' }, 0, 0)
        local frame = kart.parts.frame
        kinds.dissolve(kart)
        assert.is_nil(kinds.ofBody(frame.body))
        assert.is_nil(frame.kindId)
        assert.is_false(frame.body:isDestroyed())
        assert.is_nil(sceneIO.gatherSaveData(world, camera.getInstance()).kinds)

        local other = kinds.make('vehicle', { type = 'kart' }, 0, 0)
        local bodies = kinds.bodies(other)
        kinds.remove(other)
        for _, body in ipairs(bodies) do assert.is_true(body:isDestroyed()) end
        assert.are.equal(0, #kinds.all())
    end)

    it('makes each of the four types, a frame and two wheels', function()
        for _, name in ipairs(require('src.vehicles').order) do
            local v = kinds.make('vehicle', { type = name }, 0, 0)
            assert.is_not_nil(v, name)
            assert.are.equal(3, partCount(v), name)
            assert.are.equal(name, v.parts.frame.label)
        end
    end)

    it('is made again in place with new settings: the same id, where it was, its part still selected', function()
        local kart = kinds.make('vehicle', { type = 'kart' }, 300, 50)
        local id = kart.id
        local fx, fy = kart.parts.frame.body:getPosition()
        local oldWheel = kart.parts.frontWheel.body
        state.selection.selectedObj = kart.parts.frontWheel
        local again = kinds.rebuild(kart, { type = 'banana', size = 1.4 })
        assert.are.equal(kart, again)
        assert.are.equal(id, again.id)
        assert.are.equal('banana', again.settings.type)
        assert.is_true(oldWheel:isDestroyed())
        local nx, ny = again.parts.frame.body:getPosition()
        assert.is_near(fx, nx, 0.01)
        assert.is_near(fy, ny, 0.01)
        assert.are.equal(again.parts.frontWheel, state.selection.selectedObj)
        assert.are.equal(again, (kinds.ofBody(again.parts.backWheel.body)))
        assert.are.equal(1, #kinds.all())
        state.selection.selectedObj = nil
    end)

    it('rolls another of its kind: a type it has, a size near the usual', function()
        local vehicles = require('src.vehicles')
        for _ = 1, 20 do
            local settings = vehicles.roll()
            assert.is_not_nil(vehicles.TYPES[settings.type])
            assert.is_true(settings.size >= 0.8 and settings.size <= 1.3)
        end
    end)

    it('rolls when pushed', function()
        local floor = love.physics.newBody(world, 0, 200, 'static')
        love.physics.newFixture(floor, love.physics.newRectangleShape(20000, 40))
        local kart = kinds.make('vehicle', { type = 'kart' }, 0, 0)
        for _ = 1, 60 do world:update(1 / 60) end -- settle on its wheels
        local x0 = kart.parts.frame.body:getX()
        kart.parts.frame.body:setLinearVelocity(400, 0)
        for _ = 1, 60 do world:update(1 / 60) end
        assert.is_true(kart.parts.frame.body:getX() - x0 > 150)
        assert.is_true(math.abs(kart.parts.backWheel.body:getAngularVelocity()) > 0.5) -- its wheels turn
    end)
end)

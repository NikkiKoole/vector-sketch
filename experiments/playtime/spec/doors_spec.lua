-- spec/doors_spec.lua
-- Doors (src/doors.lua, docs/WORLDS-AND-DOORS.md W1) with the test rooms in
-- scripts/ (claudetools/make-door-rooms.lua): a tap opens a door, a second tap
-- with a Mipo on it takes the Mipo into the room, out of the arrival door. The
-- room you left is kept in memory, so going back finds it as you left it.
-- Run with: love . --specs spec/doors_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local sceneLoader = require('src.scene-loader')
local mipoRegistry = require('src.mipo-registry')
local doors = require('src.doors')

describe('doors', function()
    local world

    setup(function()
        world = love.physics.newWorld(0, 9.81 * 100, true)
        state.physicsWorld = world
        registry.reset()
        state.rooms.saved, state.rooms.openDoor, state.rooms.pending = {}, nil, nil
        sceneLoader.loadScriptAndScene('overworld')
    end)

    teardown(function()
        state.rooms.saved, state.rooms.openDoor, state.rooms.pending, state.rooms.fade = {}, nil, nil, 0
        world:destroy()
    end)

    -- the one Mipo in these rooms
    local function theMipo()
        return next(mipoRegistry.getAll())
    end

    -- move every part of the Mipo so its torso sits in the middle of the body
    local function putOn(instance, body)
        local tx, ty = instance.parts['torso1'].body:getPosition()
        local x, y = body:getPosition()
        for _, part in pairs(instance.parts) do
            local px, py = part.body:getPosition()
            part.body:setPosition(px + x - tx, py + y - ty)
        end
    end

    local function countBodies()
        local n = 0
        for _ in pairs(registry.bodies) do n = n + 1 end
        return n
    end

    it('the overworld has its doors and a Mipo', function()
        assert.are.equal('overworld', state.scene.id)
        assert.is_not_nil(doors.findDoor('bakery'))
        assert.is_not_nil(doors.findDoor('treehouse'))
        assert.is_not_nil(theMipo())
    end)

    it('a tap opens a door, a tap without a Mipo on it closes it again', function()
        local door = doors.findDoor('treehouse')
        assert.is_nil(doors.mipoOn(door))
        doors.onPressed({ door })
        assert.is_not_nil(state.rooms.openDoor)
        doors.onPressed({ door })
        assert.is_nil(state.rooms.openDoor)
        assert.is_nil(state.rooms.pending)
    end)

    local overworldBodies

    it('open, Mipo on it, tap: the Mipo goes into the bakery', function()
        local mipoId, instance = theMipo()
        local door = doors.findDoor('bakery')
        overworldBodies = countBodies()
        doors.onPressed({ door })
        putOn(instance, door)
        assert.are.equal(mipoId, doors.mipoOn(door))
        doors.onPressed({ door })
        assert.is_not_nil(state.rooms.pending)
        doors.update(0.016)

        assert.are.equal('bakery', state.scene.id)
        assert.is_not_nil(state.rooms.saved.overworld)
        local arrivedId, arrived = theMipo()
        assert.are.equal(mipoId, arrivedId)
        -- out of the arrival door
        local front = doors.findDoor('front')
        assert.are.equal(mipoId, doors.mipoOn(front))
        assert.is_not_nil(arrived.parts['torso1'].body)
    end)

    it('and back out: the overworld as it was, the Mipo at the bakery door', function()
        local mipoId, instance = theMipo()
        local front = doors.findDoor('front')
        doors.onPressed({ front })
        putOn(instance, front)
        doors.onPressed({ front })
        doors.update(0.016)

        assert.are.equal('overworld', state.scene.id)
        assert.are.equal(overworldBodies, countBodies())
        assert.are.equal(mipoId, (theMipo()))
        assert.are.equal(mipoId, doors.mipoOn(doors.findDoor('bakery')))
        assert.is_not_nil(state.rooms.saved.bakery)
    end)
end)

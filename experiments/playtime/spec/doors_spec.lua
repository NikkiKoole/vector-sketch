-- spec/doors_spec.lua
-- Doors (src/doors.lua, docs/WORLDS-AND-DOORS.md) with the test rooms in scripts/
-- (claudetools/make-door-rooms.lua): a tap on a door takes you in as a spectator. A Mipo
-- dropped on a door goes through by itself and steps out of the arrival door when you get
-- there; several step out together and drift apart, not in a knot. The room you left is kept in memory,
-- so going back finds it as you left it.
-- Run with: love . --specs spec/doors_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local sceneLoader = require('src.scene-loader')
local mipoRegistry = require('src.mipo-registry')
local doors = require('src.doors')

describe('doors', function()
    local world

    local function reset()
        state.rooms.saved, state.rooms.arrivals, state.rooms.swing = {}, {}, {}
        state.rooms.pending, state.rooms.sends, state.rooms.fade = nil, nil, 0
    end

    setup(function()
        world = love.physics.newWorld(0, 9.81 * love.physics.getMeter(), true)
        state.physicsWorld = world
        registry.reset()
        reset()
        state.world.paused = false
        sceneLoader.loadScriptAndScene('overworld')
    end)

    teardown(function()
        reset()
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

    local function centre(body)
        local x1, y1, x2, y2 = doors.box(body)
        return (x1 + x2) / 2, (y1 + y2) / 2
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

    it('grabbing a Mipo in front of a door leaves the door alone', function()
        local _, instance = theMipo()
        local door = doors.findDoor('treehouse')
        assert.is_false(doors.onPressed({ instance.parts['torso1'].body }, centre(door)))
        assert.is_nil(state.rooms.pending)
    end)

    it('a Mipo taken off the door before it is open stays; the door just swings', function()
        local mipoId, instance = theMipo()
        local door = doors.findDoor('treehouse')
        local x, y = instance.parts['torso1'].body:getPosition()
        putOn(instance, door)
        doors.onReleased({ instance.parts['torso1'].body })
        doors.update(0.05) -- the door starts opening, the Mipo still here
        assert.is_not_nil(mipoRegistry.getAll()[mipoId])
        putOn(instance, { getPosition = function() return x, y end }) -- off the door again
        doors.update(0.3)
        assert.is_not_nil(mipoRegistry.getAll()[mipoId])
        assert.are.equal(0, doors.waiting('treehouse'))
        assert.are.equal('overworld', state.scene.id) -- nobody went, so neither did you
    end)

    local overworldBodies

    it('a Mipo dropped on a door goes through, and you follow it', function()
        local mipoId, instance = theMipo()
        local door = doors.findDoor('bakery')
        overworldBodies = countBodies()
        putOn(instance, door)
        assert.are.equal(mipoId, doors.mipoOn(door))
        doors.onReleased({ instance.parts['torso1'].body })
        doors.update(0.3) -- the door is open: the Mipo goes
        doors.update(0.1) -- and you after it

        assert.are.equal('bakery', state.scene.id)
        assert.is_not_nil(state.rooms.saved.overworld)
        assert.are.equal(0, doors.waiting('bakery'))
        local _, arrived = theMipo()
        assert.is_not_nil(arrived)
        assert.are.equal(mipoId, arrived.id)
        assert.are.equal(arrived.id, doors.mipoOn(doors.findDoor('front')))
        -- standing in the room, not with its legs in the floor (bakery floor top: 550)
        for name, part in pairs(arrived.parts) do
            assert.is_true(part.body:getY() < 550, name .. ' arrived under the floor')
        end
    end)

    it('a tap takes you alone: the Mipo stays where it is', function()
        local mipoId = theMipo()
        assert.is_true(doors.onPressed({}, centre(doors.findDoor('front'))))
        doors.update(0.3)
        assert.are.equal('overworld', state.scene.id)
        assert.is_nil(mipoRegistry.getAll()[mipoId])
        assert.is_not_nil(state.rooms.saved.bakery)
    end)

    it('fetch it: go to it alone, drop it on the door back, both out', function()
        assert.is_true(doors.onPressed({}, centre(doors.findDoor('bakery'))))
        doors.update(0.3)
        assert.are.equal('bakery', state.scene.id)
        local mipoId, instance = theMipo()
        assert.is_not_nil(mipoId)
        putOn(instance, doors.findDoor('front'))
        doors.onReleased({ instance.parts['torso1'].body })
        doors.update(0.3)
        doors.update(0.1)

        assert.are.equal('overworld', state.scene.id)
        assert.are.equal(overworldBodies, countBodies())
        assert.are.equal(mipoId, (theMipo()))
        assert.are.equal(mipoId, doors.mipoOn(doors.findDoor('bakery')))
    end)

    it('Mipos sent together drift apart: no knot, nobody through the floor', function()
        -- three copies of the Mipo's save data, as if three were sent to the bakery
        local sceneIO = require('src.io')
        local json = require('vendor.dkjson')
        local mipoId = theMipo()
        local _, traveler = doors.split(sceneIO.gatherSaveData(state.physicsWorld, require('src.camera').getInstance()),
            mipoId)
        local text = json.encode(traveler)
        state.rooms.arrivals.bakery = {}
        for i = 1, 3 do
            local copy = text:gsub(mipoId, 'copy' .. i)
            table.insert(state.rooms.arrivals.bakery, { traveler = json.decode(copy), arrive = 'front' })
        end
        doors.onPressed({}, centre(doors.findDoor('bakery')))
        doors.update(0.3)
        assert.are.equal('bakery', state.scene.id)
        -- let them drift apart: the game's physics callbacks (preSolve passes them through each
        -- other), the joint guard every step, real time going by (its checks run on the clock)
        local callbacks = require('src.physics.physics-callbacks')
        local guard = require('src.mipo-joint-guard')
        world:setCallbacks(callbacks[1], callbacks[2], callbacks[3], callbacks[4])
        local t0 = love.timer.getTime()
        while love.timer.getTime() - t0 < 3 do
            world:update(1 / 60)
            guard.update()
            love.timer.sleep(1 / 120)
        end
        world:setCallbacks(nil, nil, nil, nil)
        -- no limb of one through another (the guard's hooks), torsos well apart, all standing
        assert.are.equal(0, #guard.hooks())
        local xs = {}
        for i = 1, 3 do
            local torso = mipoRegistry.getAll()['copy' .. i].parts['torso1'].body
            assert.is_true(torso:getY() < 550, 'copy' .. i .. ' fell through the floor')
            xs[i] = torso:getX()
        end
        table.sort(xs)
        for i = 2, 3 do
            assert.is_true(xs[i] - xs[i - 1] > 60, 'two Mipos still on top of each other')
        end
    end)

    it('a Mipo dazed (limp) when it is sent arrives upright', function()
        local mipoActions = require('src.mipo-actions')
        local function limpParts(instance)
            local n = 0
            for name, part in pairs(instance.parts) do
                for _, b in ipairs(part.behaviors or {}) do
                    if b.name == 'KEEP_ANGLE' and b.enabled == false and not name:find('arm') then n = n + 1 end
                end
            end
            return n
        end
        local mipoId, instance = theMipo()
        mipoActions.onHardImpact(instance, 5000)
        assert.is_true(mipoActions.isDazed(instance))
        assert.is_true(limpParts(instance) > 0)
        local here = state.scene.id
        local door = here == 'bakery' and doors.findDoor('front') or doors.findDoor('bakery')
        putOn(instance, door)
        doors.onReleased({ instance.parts['torso1'].body })
        doors.update(0.3)
        doors.update(0.1)
        local arrived = mipoRegistry.getAll()[mipoId]
        assert.is_not_nil(arrived)
        assert.are.equal(0, limpParts(arrived))
        assert.is_false(mipoActions.isDazed(arrived))
    end)
end)

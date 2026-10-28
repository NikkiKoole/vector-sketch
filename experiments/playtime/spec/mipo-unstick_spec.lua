-- spec/mipo-unstick_spec.lua
-- A Mipo standing on a thin floor with one foot pushed through it (the stuck
-- case: a part on the wrong side of a wall, the rest on the other). Without
-- unstick the joint pulls the foot against the floor's underside forever; with
-- it the foot becomes a ghost, comes back up, and is solid again.
-- Run with: love . --specs spec/mipo-unstick_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local guard = require('src.mipo-joint-guard')

describe('mipo unstick', function()
    local world, instance
    local FLOOR_TOP = 580

    local function setUp()
        world = love.physics.newWorld(0, 9.81 * 100, true)
        state.physicsWorld = world
        registry.reset()
        objectManager.addThing('rectangle', { x = 0, y = 600, width = 3000, height = 40, bodyType = 'static',
            label = 'floor' })
        local CM = require('src.character-manager')
        instance = CM.createCharacter('humanoid', 0, FLOOR_TOP - 440, 0.3)
        CM.poseTpose(instance)
        -- settle on the floor
        for _ = 1, 60 do world:update(1 / 60) end
    end

    -- push the left foot straight down through the floor
    local function footThroughFloor()
        local foot = instance.parts['lfoot'].body
        local x = foot:getX()
        foot:setPosition(x, 600 + 20 + 40)
        foot:setLinearVelocity(0, 0)
        return foot
    end

    local function run(frames)
        for _ = 1, frames do
            world:update(1 / 60)
            guard.update()
        end
    end

    after_each(function()
        guard.unstick = true
        for key in pairs(state.mipoGhosts) do state.mipoGhosts[key] = nil end
        world:destroy()
    end)

    it('a Mipo just standing on the floor is left alone', function()
        setUp()
        local before = guard.stats.unstuck
        run(180)
        assert.are.equal(before, guard.stats.unstuck)
    end)

    it('without unstick the foot stays under the floor (the bug)', function()
        setUp()
        guard.unstick = false
        local foot = footThroughFloor()
        run(120)
        assert.is_true(foot:getY() > FLOOR_TOP, 'foot came back on its own at y ' .. foot:getY())
    end)

    it('with unstick the foot comes back up and is solid again', function()
        setUp()
        local before = guard.stats.unstuck
        local foot = footThroughFloor()
        run(120)
        assert.is_true(guard.stats.unstuck > before)
        assert.is_true(foot:getY() < FLOOR_TOP, 'foot still under the floor at y ' .. foot:getY())
        for _, fixture in ipairs(foot:getFixtures()) do
            if not fixture:getUserData() then assert.is_false(fixture:isSensor()) end
        end
        assert.is_nil(next(state.mipoGhosts))
    end)
end)

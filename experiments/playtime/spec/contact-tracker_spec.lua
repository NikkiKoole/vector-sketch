-- spec/contact-tracker_spec.lua
-- src/physics/contact-tracker.lua knows what touches what from beginContact/endContact;
-- it must agree with Box2D's own contact list (body:getContacts) every step.
-- Run with: love . --specs spec/contact-tracker_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local CM = require('src.character-manager')
local contactTracker = require('src.physics.contact-tracker')

local DT = 1 / 60

-- touching fixture pairs of a body, as "own|other" strings
local function fromBox2D(body)
    local out = {}
    for _, contact in ipairs(body:getContacts()) do
        if contact:isTouching() then
            local a, b = contact:getFixtures()
            local own, other = a, b
            if a:getBody() ~= body then own, other = b, a end
            out[tostring(own) .. '|' .. tostring(other)] = true
        end
    end
    return out
end

local function fromTracker(body)
    local out = {}
    contactTracker.any(body, function(own, other)
        out[tostring(own) .. '|' .. tostring(other)] = true
        return false
    end)
    return out
end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

describe('contact tracker', function()
    it('agrees with Box2D about every touching pair in a falling pile of Mipos', function()
        local world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        world:setCallbacks(contactTracker.beginContact, contactTracker.endContact)
        state.physicsWorld = world
        registry.reset()
        mipoRegistry.reset()
        contactTracker.reset()
        local box = love.physics.newBody(world, 0, 0, 'static')
        love.physics.newFixture(box, love.physics.newEdgeShape(-600, 1000, 600, 1000))
        love.physics.newFixture(box, love.physics.newEdgeShape(-600, -2000, -600, 1000))
        love.physics.newFixture(box, love.physics.newEdgeShape(600, -2000, 600, 1000))
        love.math.setRandomSeed(3)
        math.randomseed(3)
        local mipos = {}
        for i = 1, 4 do
            local instance = CM.createCharacter('humanoid', (i - 2.5) * 120, 400 - i * 500, 0.3)
            CM.randomizeMipoConstrained(instance)
            mipos[i] = instance
        end
        local checked, touching = 0, 0
        for step = 1, 240 do
            world:update(DT)
            if step == 120 then
                -- a part deleted with the callbacks off (as the bridge does): no endContact
                world:setCallbacks()
                mipos[4].parts.lhand.body:destroy()
                world:setCallbacks(contactTracker.beginContact, contactTracker.endContact)
            end
            for _, body in ipairs(world:getBodies()) do
                local want, got = fromBox2D(body), fromTracker(body)
                for key in pairs(want) do
                    assert.is_true(got[key] ~= nil, 'step ' .. step .. ': tracker misses ' .. key)
                end
                assert.are.equal(count(want), count(got), 'step ' .. step .. ': tracker has extra pairs')
                checked = checked + 1
                touching = touching + count(want)
            end
        end
        assert.is_true(touching > 1000, 'the pile hardly touched (' .. touching .. ' pairs)')
        world:destroy()
    end)
end)

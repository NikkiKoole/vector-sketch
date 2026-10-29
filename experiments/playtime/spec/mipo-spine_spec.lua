-- spec/mipo-spine_spec.lua
-- The spine test room (scripts/spine.playtime.json): P4re5, a Mipo with a tall torso, on a
-- floor between two walls (docs/MIPO-SPINE.md).
-- Run with: love . --specs spec/mipo-spine_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local sceneLoader = require('src.scene-loader')
local contactTracker = require('src.physics.contact-tracker')
local keepAngle = require('src.keep-angle')
local jointGuard = require('src.mipo-joint-guard')
local mipoActions = require('src.mipo-actions')
local CM = require('src.character-manager')
local subtypes = require('src.subtypes')

-- the game's step at this meter (60 a second at 100 px per metre, 85 at 200): at 1/60 the
-- tall P4re5 sagged onto its knees on 200 and hopped back up over and over
local DT = 1 / require('src.physics-units').stepsPerSecond()

describe('the spine room', function()
    local world, simTime, realGetTime

    before_each(function()
        love.math.setRandomSeed(1)
        math.randomseed(1)
        simTime = 0
        realGetTime = love.timer.getTime
        love.timer.getTime = function() return simTime end
        world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        state.physicsWorld = world
        registry.reset()
        mipoRegistry.reset()
        sceneLoader.loadScriptAndScene('spine')
        world = state.physicsWorld
        world:setCallbacks(contactTracker.beginContact, contactTracker.endContact)
    end)

    after_each(function()
        love.timer.getTime = realGetTime
        if world and not world:isDestroyed() then world:destroy() end
    end)

    local function simulate(seconds)
        for _ = 1, math.floor(seconds / DT) do
            simTime = simTime + DT
            world:update(DT)
            jointGuard.update()
            mipoActions.update()
            keepAngle.update(DT, {})
        end
    end

    -- (saved mid-step in the scene it came from: it lands ~110 lower and hops up once)
    it('has P4re5 standing on the floor', function()
        local instance = mipoRegistry.getAll().P4re5
        assert.is_truthy(instance, 'P4re5 is not in the room')
        local torso = instance.parts.torso1.body
        simulate(2)
        local _, y0 = torso:getPosition()
        simulate(3)
        local _, y1 = torso:getPosition()
        assert.is_true(math.abs(y1 - y0) < 30, string.format('torso moved from %d to %d', y0, y1))
        assert.is_true(math.abs(torso:getAngle()) < math.rad(20),
            string.format('torso leans %.0f degrees', math.deg(torso:getAngle())))
    end)

    describe('with a spine', function()
        local instance

        local function spineJoint()
            for _, joint in ipairs(instance.parts.torso2.body:getJoints()) do
                local a, b = joint:getBodies()
                if a == instance.parts.torso1.body and b == instance.parts.torso2.body then return joint end
            end
        end

        local function textures(name)
            local n = 0
            for _, f in ipairs(instance.parts[name].body:getFixtures()) do
                local ud = f:getUserData()
                if ud and subtypes.is(ud, subtypes.TEXFIXTURE) then n = n + 1 end
            end
            return n
        end

        before_each(function()
            instance = mipoRegistry.getAll().P4re5
            CM.rebuildFromCreation(instance, { torsoSpine = true, torsoSegments = 2, spineSway = 0, spineBend = 15 })
            CM.addTexturesFromInstance2(instance)
        end)

        it('is two bands of one torso, joined where they meet, bending 15 degrees', function()
            local t1, t2 = instance.parts.torso1.body, instance.parts.torso2.body
            assert.is_true(t2:getY() < t1:getY(), 'the second band is not above the first')
            local joint = spineJoint()
            assert.is_truthy(joint)
            simulate(0.5) -- the room was saved mid-sway; the rebuild keeps that pose
            local x1, y1, x2, y2 = joint:getAnchors()
            assert.is_true(math.abs(x1 - x2) + math.abs(y1 - y2) < 1,
                string.format('joint halves %.1f apart', math.abs(x1 - x2) + math.abs(y1 - y2)))
            assert.is_near(math.rad(15), joint:getUpperLimit(), 1e-6)
            -- the two bands together are about as tall as one whole torso
            local function height(body)
                local top, bottom = math.huge, -math.huge
                for _, f in ipairs(body:getFixtures()) do
                    if not f:getUserData() then
                        local _, ty, _, by = f:getBoundingBox()
                        top, bottom = math.min(top, ty), math.max(bottom, by)
                    end
                end
                return top, bottom
            end
            local top2 = height(t2)
            local _, bottom1 = height(t1)
            local dims = instance.dna.parts.torso1.dims
            local whole = CM.shape8Dict[instance.dna.parts.torso1.shape8URL].dimensions[2] * math.abs(dims.sy)
                * instance.scale
            assert.is_true(math.abs((bottom1 - top2) - whole) < whole * 0.15,
                string.format('bands span %d, the torso is %d', bottom1 - top2, whole))
            -- one picture: drawn by the lowest band only
            assert.is_true(textures('torso1') >= 1)
            assert.are.equal(0, textures('torso2'))
            assert.are.equal(0, #(instance.dna.parts.torso2.behaviors or {}))
        end)

        it('stands, and bends no further than its limit when it lands, then straightens', function()
            simulate(3)
            for _, part in pairs(instance.parts) do
                local x, y = part.body:getPosition()
                part.body:setPosition(x, y - 1200)
                part.body:setLinearVelocity(0, 0)
            end
            local joint, most = spineJoint(), 0
            for _ = 1, math.floor(2 / DT) do
                simulate(DT)
                most = math.max(most, math.abs(joint:getJointAngle()))
            end
            assert.is_true(most > math.rad(1), 'it never bent (' .. math.deg(most) .. ' degrees)')
            assert.is_true(most < math.rad(15) + 0.05, 'it bent ' .. math.deg(most) .. ' degrees')
            simulate(2)
            assert.is_true(math.abs(joint:getJointAngle()) < math.rad(5),
                'still bent ' .. math.deg(joint:getJointAngle()) .. ' degrees')
            local torso = instance.parts.torso1.body
            assert.is_true(math.abs(torso:getAngle()) < math.rad(20), 'fell over')
        end)

        it('turned off again: whole torsos that each keep their angle', function()
            CM.rebuildFromCreation(instance, { torsoSpine = false })
            assert.is_nil(instance.dna.parts.torso2.spineBand)
            assert.are.equal('KEEP_ANGLE', instance.dna.parts.torso2.behaviors[1].name)
        end)
    end)
end)

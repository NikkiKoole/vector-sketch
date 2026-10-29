-- Specs for src/physics/snap.lua: snap-joint creation, force breaking,
-- cooldowns, destroyed bodies, loading old scenes, and the bugs the old
-- design had (stuck partner points after a delete, links lost on recreate).

if not love then return end

local snap = require('src.physics.snap')
local fixtures = require('src.fixtures')
local registry = require('src.registry')
local state = require('src.state')
local subtypes = require('src.subtypes')
local joints = require('src.joints')
local objectManager = require('src.object-manager')
local CharacterManager = require('src.character-manager')
local mipoRegistry = require('src.mipo-registry')

describe('snap core', function()
    local world
    local prevSnapConfig
    local simTime, realGetTime

    local function makeBody(id, x, y)
        local body = love.physics.newBody(world, x, y, 'dynamic')
        love.physics.newFixture(body, love.physics.newCircleShape(10), 1)
        body:setUserData({ thing = { id = id, body = body } })
        registry.registerBody(id, body)
        return body
    end

    local function addSnapPoint(body, lx, ly)
        local fixture = fixtures.createSFixture(body, lx or 0, ly or 0, subtypes.SNAP, { radius = 8 })
        return fixture:getUserData().id
    end

    local function step(seconds)
        simTime = simTime + (seconds or 1 / 60)
        snap.update(1 / 60)
    end

    before_each(function()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        registry.reset()
        mipoRegistry.reset() -- Mipo hands are snap points too: none left over from other specs
        snap.reset()
        simTime = 0
        realGetTime = love.timer.getTime
        love.timer.getTime = function() return simTime end -- luacheck: ignore 122
        prevSnapConfig = {
            onlyConnect = state.snap.onlyConnectWhenInteracted,
            onlyBreak = state.snap.onlyBreakWhenInteracted,
            threshold = state.snap.jointBreakThreshold,
        }
        state.snap.onlyConnectWhenInteracted = false
        state.snap.onlyBreakWhenInteracted = false
    end)

    after_each(function()
        love.timer.getTime = realGetTime -- luacheck: ignore 122
        state.snap.onlyConnectWhenInteracted = prevSnapConfig.onlyConnect
        state.snap.onlyBreakWhenInteracted = prevSnapConfig.onlyBreak
        state.snap.jointBreakThreshold = prevSnapConfig.threshold
        snap.reset()
        if state.physicsWorld and not state.physicsWorld:isDestroyed() then
            state.physicsWorld:destroy()
        end
        state.physicsWorld = nil
        registry.reset()
    end)

    describe('snapping', function()
        it('joins two nearby free snap points with a revolute joint naming both', function()
            local a, b = makeBody('A', 0, 0), makeBody('B', 30, 0)
            local pa, pb = addSnapPoint(a), addSnapPoint(b)
            step()
            local js = snap.joints()
            assert.are.equal(1, #js)
            assert.are.equal('revolute', js[1]:getType())
            local meta = js[1]:getUserData().scriptmeta
            local ids = { [meta.a] = true, [meta.b] = true }
            assert.is_true(ids[pa] and ids[pb])
        end)

        it('does not join snap points beyond snapDistance', function()
            local a, b = makeBody('A', 0, 0), makeBody('B', state.snap.snapDistance + 50, 0)
            addSnapPoint(a)
            addSnapPoint(b)
            step()
            assert.are.equal(0, #snap.joints())
        end)

        it('does not join two snap points on the same body', function()
            local a = makeBody('A', 0, 0)
            addSnapPoint(a, -5, 0)
            addSnapPoint(a, 5, 0)
            step()
            assert.are.equal(0, #snap.joints())
        end)

        it('respects onlyConnectWhenInteracted', function()
            state.snap.onlyConnectWhenInteracted = true
            local a, b = makeBody('A', 0, 0), makeBody('B', 30, 0)
            addSnapPoint(a)
            addSnapPoint(b)
            step()
            assert.are.equal(0, #snap.joints())
        end)

        it('a linked snap point does not link a second time', function()
            local a, b, c = makeBody('A', 0, 0), makeBody('B', 30, 0), makeBody('C', -30, 0)
            addSnapPoint(a)
            addSnapPoint(b)
            addSnapPoint(c)
            step()
            step()
            assert.are.equal(1, #snap.joints())
        end)
    end)

    describe('breaking', function()
        it('breaks an overstressed snap joint, cools its points down, then they snap again', function()
            local a, b = makeBody('A', 0, 0), makeBody('B', 30, 0)
            addSnapPoint(a)
            addSnapPoint(b)
            step()
            assert.are.equal(1, #snap.joints())
            state.snap.jointBreakThreshold = -1 -- any force breaks it
            step()
            assert.are.equal(0, #snap.joints())
            state.snap.jointBreakThreshold = 1e12
            step() -- still cooling down
            assert.are.equal(0, #snap.joints())
            step(state.snap.cooldownTime + 0.1)
            assert.are.equal(1, #snap.joints())
        end)
    end)

    describe('destroyed bodies', function()
        it('a snap point on a destroyed body is skipped', function()
            local a, b = makeBody('A', 0, 0), makeBody('B', 30, 0)
            addSnapPoint(a)
            addSnapPoint(b)
            b:destroy()
            step()
            assert.are.equal(0, #snap.joints())
        end)

        it('deleting a body frees its partner point (old design left it stuck as linked)', function()
            local a, b, c = makeBody('A', 0, 0), makeBody('B', 30, 0), makeBody('C', -300, 0)
            addSnapPoint(a)
            addSnapPoint(b)
            addSnapPoint(c)
            step()
            assert.are.equal(1, #snap.joints())
            snap.destroySnapJointAboutBody(b)
            b:destroy()
            c:setPosition(-30, 0)
            step(state.snap.cooldownTime + 0.1)
            assert.are.equal(1, #snap.joints()) -- A snapped to C
            local ja, jb = snap.joints()[1]:getBodies()
            assert.is_true((ja == a and jb == c) or (ja == c and jb == a))
        end)
    end)

    describe('joint recreate', function()
        it('a recreated snap joint keeps naming its snap points (scriptmeta survives)', function()
            local a, b = makeBody('A', 0, 0), makeBody('B', 30, 0)
            addSnapPoint(a)
            addSnapPoint(b)
            step()
            local meta = snap.joints()[1]:getUserData().scriptmeta
            local recreated = joints.recreateJoint(snap.joints()[1], {})
            local m2 = recreated:getUserData().scriptmeta
            assert.are.equal('snap', m2.type)
            assert.are.equal(meta.a, m2.a)
            assert.are.equal(meta.b, m2.b)
        end)
    end)

    describe('onSceneLoaded (scenes saved by the old design)', function()
        it('names the nearest snap points for an old { type = snap } joint and drops at/to', function()
            local a, b = makeBody('A', 0, 0), makeBody('B', 60, 0)
            local near = addSnapPoint(a, 25, 0)
            addSnapPoint(a, -25, 0) -- a second point on A, further from the joint
            local pb = addSnapPoint(b, -25, 0)
            local sf = registry.getSFixtureByID(near)
            sf:getUserData().extra.at = 'A' -- leftover old link data
            local joint = love.physics.newRevoluteJoint(a, b, 30, 0, 30, 0)
            joint:setUserData({ id = 'J1', scriptmeta = { type = 'snap' } })
            registry.registerJoint('J1', joint)
            snap.onSceneLoaded()
            local meta = joint:getUserData().scriptmeta
            local ids = { [meta.a] = true, [meta.b] = true }
            assert.is_true(ids[near] and ids[pb])
            assert.is_nil(sf:getUserData().extra.at)
        end)

        it('ignores non-snap joints', function()
            local a, b = makeBody('A', 0, 0), makeBody('B', 60, 0)
            local joint = love.physics.newRevoluteJoint(a, b, 30, 0, 30, 0)
            joint:setUserData({ id = 'J2' })
            registry.registerJoint('J2', joint)
            snap.onSceneLoaded()
            assert.are.equal(0, #snap.joints())
        end)
    end)

    it('works with objectManager bodies too (snap points via the editor path)', function()
        local t1 = objectManager.addThing('rectangle', { x = 0, y = 0, width = 40, height = 40 })
        local t2 = objectManager.addThing('rectangle', { x = 60, y = 0, width = 40, height = 40 })
        addSnapPoint(t1.body, 20, 0)
        addSnapPoint(t2.body, -20, 0)
        step()
        assert.are.equal(1, #snap.joints())
    end)

    describe('Mipo hands', function()
        before_each(function() mipoRegistry.reset() end)

        local function moveMipo(instance, dx, dy)
            for _, part in pairs(instance.parts) do
                local x, y = part.body:getPosition()
                part.body:setPosition(x + dx, y + dy)
            end
        end

        it('two Mipos hold hands when a hand comes near the other one', function()
            local a = CharacterManager.createCharacter('humanoid', 0, 0, 0.3)
            local b = CharacterManager.createCharacter('humanoid', 0, 0, 0.3)
            local ax, ay = a.parts.lhand.body:getWorldCenter()
            local bx, by = b.parts.rhand.body:getWorldCenter()
            moveMipo(b, ax - bx + 20, ay - by)
            step()
            local found = false
            for _, joint in ipairs(snap.joints()) do
                local j1, j2 = joint:getBodies()
                if (j1 == a.parts.lhand.body and j2 == b.parts.rhand.body)
                    or (j2 == a.parts.lhand.body and j1 == b.parts.rhand.body) then found = true end
            end
            assert.is_true(found)
        end)

        it('hands that only touch edge to edge (solid, big) still hold hands', function()
            local a = CharacterManager.createCharacter('humanoid', 0, 0, 0.3)
            local b = CharacterManager.createCharacter('humanoid', 0, 0, 0.3)
            local ax, ay = a.parts.lhand.body:getWorldCenter()
            local bx, by = b.parts.rhand.body:getWorldCenter()
            local gap = snap.reachRadius(a.parts.lhand.body, ax, ay) + snap.reachRadius(b.parts.rhand.body, bx, by)
            moveMipo(b, ax - bx + gap, ay - by)
            step()
            -- small Mipos have both hands within reach of the other's hands, so one or
            -- two pairs hold on; every joint is between a hand of each Mipo, held where
            -- they touch (not pulled into each other)
            assert.is_true(#snap.joints() >= 1)
            for _, joint in ipairs(snap.joints()) do
                local j1, j2 = joint:getBodies()
                local m1, m2 = mipoRegistry.getFromBody(j1), mipoRegistry.getFromBody(j2)
                assert.is_true(m1 ~= m2)
                local x1, y1, x2, y2 = joint:getAnchors()
                assert.is_near(0, math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2), 1)
            end
        end)

        it("a Mipo's hands never grab its own Mipo", function()
            local a = CharacterManager.createCharacter('humanoid', 0, 0, 0.3)
            local rx, ry = a.parts.rhand.body:getWorldCenter()
            a.parts.lhand.body:setPosition(rx + 10, ry)
            step()
            assert.are.equal(0, #snap.joints())
        end)

        it('a hand grabs a fixed hold and lets go when pulled past handLetGo', function()
            local a = CharacterManager.createCharacter('humanoid', 0, 0, 0.3)
            local hx, hy = a.parts.lhand.body:getWorldCenter()
            local hold = love.physics.newBody(world, hx + 30, hy, 'static')
            local f = love.physics.newFixture(hold, love.physics.newCircleShape(10))
            f:setSensor(true)
            hold:setUserData({ thing = { id = 'HOLD', body = hold } })
            registry.registerBody('HOLD', hold)
            addSnapPoint(hold)
            step()
            assert.are.equal(1, #snap.joints())
            local before = snap.handLetGo
            snap.handLetGo = -1 -- any pull: a hand lets go
            step()
            snap.handLetGo = before
            assert.are.equal(0, #snap.joints())
        end)
    
        it('dragging a Mipo by its torso lets its hand grab a hold (per-Mipo interaction)', function()
            state.snap.onlyConnectWhenInteracted = true
            local pointerJoints = require('src.physics.box2d-pointerjoints')
            pointerJoints.resetPointerJoints()
            local a = CharacterManager.createCharacter('humanoid', 0, 0, 0.3)
            local hx, hy = a.parts.lhand.body:getWorldCenter()
            local hold = love.physics.newBody(world, hx + 30, hy, 'static')
            love.physics.newFixture(hold, love.physics.newCircleShape(10)):setSensor(true)
            hold:setUserData({ thing = { id = 'HOLD2', body = hold } })
            registry.registerBody('HOLD2', hold)
            addSnapPoint(hold)
            step()
            assert.are.equal(0, #snap.joints()) -- nobody holds the Mipo
            local tx, ty = a.parts.torso1.body:getPosition()
            pointerJoints.handlePointerPressed(tx, ty, 'mouse')
            step()
            assert.are.equal(1, #snap.joints())
            pointerJoints.resetPointerJoints()
        end)
    end)
end)

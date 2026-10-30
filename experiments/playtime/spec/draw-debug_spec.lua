-- spec/draw-debug_spec.lua
-- Small drawing bugs from docs/CODE-BUGS-2026-10.md:
-- BUG8:  debug ids + joints on, no textured body: the joint part indexed a nil table.
-- BUG12: the MESHUSERT wireframe (a debug view) was on by default.
-- BUG18: blink states held on to every thing ever drawn.
-- BUG11: two of three hairs-shader setups never sent the mottle.
-- BUG13: a circle off the body's centre was drawn as if the body never turned.
-- Run with: love . --specs spec/draw-debug_spec.lua

if not love then return end
-- luacheck: ignore 122 (a spy swaps love.graphics.circle and puts it back)

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local joints = require('src.joints')
local box2dDraw = require('src.physics.box2d-draw')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')

describe('drawing: debug views', function()
    local world

    before_each(function()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        registry.reset()
    end)

    after_each(function()
        state.world.showDebugIds = false
        state.world.debugDrawJoints = false
        if world and not world:isDestroyed() then world:destroy() end
        state.physicsWorld = nil
        registry.reset()
    end)

    it('draws debug ids for a joint (BUG8)', function()
        local a = objectManager.addThing('rectangle', { x = 0, y = 0, width = 40, height = 40 })
        local b = objectManager.addThing('rectangle', { x = 100, y = 0, width = 40, height = 40 })
        joints.createJoint({ body1 = a.body, body2 = b.body, jointType = 'revolute' })
        state.world.showDebugIds = true
        state.world.debugDrawJoints = true
        assert.has_no.errors(function() box2dDraw.drawWorld(world) end)
    end)

    it('draws an offset circle where it is on a turned body (BUG13)', function()
        local body = love.physics.newBody(world, 100, 50, 'dynamic')
        love.physics.newFixture(body, love.physics.newCircleShape(20, 0, 5)) -- 20 to the right
        body:setAngle(math.pi / 2) -- now 20 down
        local centres = {}
        local circle = love.graphics.circle
        love.graphics.circle = function(mode, x, y, ...)
            centres[#centres + 1] = { x, y }
            return circle(mode, x, y, ...)
        end
        local ok, err = pcall(box2dDraw.drawWorld, world)
        love.graphics.circle = circle
        assert.is_true(ok, tostring(err))
        assert.is_true(#centres > 0)
        for _, c in ipairs(centres) do
            assert.is_near(100, c[1], 1e-3)
            assert.is_near(70, c[2], 1e-3)
        end
    end)

    it('has the MESHUSERT wireframe off unless asked for (BUG12)', function()
        assert.is_false(box2dDrawTextured.drawMeshOutline)
    end)

    -- Spy on Shader:send (one method table for every shader) to see what gets sent.
    local function sentBy(extra)
        local methods = getmetatable(love.graphics.newShader('vec4 effect(vec4 c, Image t, vec2 uv, vec2 s) { return c; }')).__index
        local send, sent = methods.send, {}
        methods.send = function(shader, name, ...)
            sent[name] = true
            return send(shader, name, ...)
        end
        local ok, err = pcall(box2dDrawTextured._test.setSurfaceShader, extra, nil)
        methods.send = send
        love.graphics.setShader()
        assert.is_true(ok, tostring(err))
        return sent
    end

    it('sends hairs and plasticine everything, mottle included (BUG11)', function()
        local hairs = sentBy({ hairs = true })
        assert.is_true(hairs.mottleStrength and hairs.mottleScale and hairs.density)
        local plasticine = sentBy({ plasticine = true })
        assert.is_true(plasticine.mottleStrength and plasticine.rimStyle and plasticine.bumpAmp)
        assert.is_false(box2dDrawTextured._test.setSurfaceShader({}, nil))
    end)

    it('lets blink states go with their thing (BUG18)', function()
        local blinkStates = require('src.mipo-face')._test.blinkStates
        local thing = {}
        blinkStates[thing] = { expiresAt = 0 }
        thing = nil -- luacheck: ignore 311
        collectgarbage('collect')
        assert.is_nil(next(blinkStates))
    end)
end)

-- spec/transform-handles_spec.lua
-- The turn knob and size square on a selected body (src/transform-handles.lua), and
-- objectManager.scaleThing behind the square: the outline, the size fields, the sfixtures and
-- their pictures all grow together, the joints stay on.
-- Run with: love . --specs spec/transform-handles_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local joints = require('src.joints')
local camera = require('src.camera')
local handles = require('src.transform-handles')

local function collisionBounds(body)
    local minX, maxX
    for _, fixture in ipairs(body:getFixtures()) do
        if not fixture:getUserData() then
            local points = { fixture:getShape():getPoints() }
            for i = 1, #points, 2 do
                minX, maxX = math.min(minX or points[i], points[i]), math.max(maxX or points[i], points[i])
            end
        end
    end
    return minX, maxX
end

local function stone()
    local vertices = { -100, -60, 0, -90, 100, -60, 110, 40, 0, 70, -110, 40 }
    local thing = objectManager.addThing('custom', { x = 300, y = 200, vertices = vertices,
        optionalVertices = vertices, bodyType = 'static' })
    fixtures.createSFixture(thing.body, 0, 0, 'texfixture', { label = 'pic', width = 200, height = 160 })
    return thing
end

describe('scaleThing', function()
    local world

    before_each(function()
        registry.reset()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
    end)

    after_each(function()
        world:destroy()
        state.physicsWorld = nil
        state.selection.selectedObj = nil
        state.interaction.transformDrag = nil
        registry.reset()
    end)

    it('grows a custom polygon, its picture and keeps the sfixture first and a sensor', function()
        local thing = stone()
        local pic = thing.body:getFixtures()[1]:getUserData()
        local picVerts = { unpack(pic.extra.vertices) }
        thing.body:setAngle(0.5)

        local scaled = objectManager.scaleThing(thing, 2)
        local body = scaled.body
        assert.is_false(body:isDestroyed())
        assert.is_near(0.5, body:getAngle(), 1e-6)
        assert.are.equal(-220, (collisionBounds(body)))
        assert.are.equal(-200, scaled.vertices[1])

        local first = body:getFixtures()[1]
        local ud = first:getUserData()
        assert.is_truthy(ud, 'the sfixture still comes first')
        assert.is_true(first:isSensor())
        for i = 1, #picVerts do assert.is_near(picVerts[i] * 2, ud.extra.vertices[i], 1e-6) end
        assert.are.equal(first, registry.getSFixtureByID(ud.id))
    end)

    it('grows a rectangle by its width and height, and a circle by its radius', function()
        local box = objectManager.addThing('rectangle', { x = 0, y = 0, width = 50, height = 20 })
        box = objectManager.scaleThing(box, 3)
        assert.are.equal(150, box.width)
        assert.are.equal(60, box.height)
        local ball = objectManager.addThing('circle', { x = 0, y = 0, radius = 10 })
        ball = objectManager.scaleThing(ball, 0.5)
        assert.are.equal(5, ball.radius)
    end)

    it('keeps a joint on the body', function()
        local a = stone()
        local b = objectManager.addThing('rectangle', { x = 300, y = 400, width = 40, height = 40 })
        joints.createJoint({ jointType = 'revolute', body1 = a.body, body2 = b.body })
        a = objectManager.scaleThing(a, 1.5)
        assert.are.equal(1, #a.body:getJoints())
    end)
end)

describe('the handles', function()
    local world, cam

    before_each(function()
        registry.reset()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        state.world.paused = true
        cam = camera.getInstance()
        cam:setScale(1)
        cam:setTranslation(0, 0)
    end)

    after_each(function()
        world:destroy()
        state.physicsWorld = nil
        state.selection.selectedObj = nil
        state.interaction.transformDrag = nil
        registry.reset()
    end)

    -- a handle's screen point: press around it until one grabs
    local function grabAt(kind, thing)
        for sy = 0, 768, 2 do
            for sx = 0, 1200, 2 do
                if handles.pressed(sx, sy) then
                    if state.interaction.transformDrag.kind == kind then return sx, sy end
                    state.interaction.transformDrag = nil
                end
            end
        end
        error('no ' .. kind .. ' handle on ' .. tostring(thing.label))
    end

    it('turn the body with the knob and size it with the square', function()
        local thing = stone()
        state.selection.selectedObj = thing
        assert.are.equal(thing, handles.target())

        -- the knob is above the body: dragging it to the right of the body turns it a quarter
        grabAt('turn', thing)
        local ox, oy = cam:getScreenCoordinates(thing.body:getPosition())
        handles.moved(ox + 200, oy)
        assert.is_true(handles.released())
        assert.is_near(math.pi / 2, thing.body:getAngle(), 0.1) -- the scan grabs it a few px off

        -- the square: dragging it twice as far from the middle doubles the size
        local sx, sy = grabAt('size', thing)
        local minBefore = collisionBounds(thing.body)
        handles.moved(ox + (sx - ox) * 2, oy + (sy - oy) * 2)
        assert.is_near(2, state.interaction.transformDrag.factor, 0.05)
        handles.released()
        local selected = state.selection.selectedObj
        assert.is_near(minBefore * 2, (collisionBounds(selected.body)), 5)
    end)

    it('are not there for a Mipo part or while running', function()
        local thing = stone()
        state.selection.selectedObj = thing
        state.world.paused = false
        assert.is_nil(handles.target())
    end)
end)

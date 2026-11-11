-- spec/track_spec.lua
-- Coaster tracks (src/track.lua, docs/COASTER.md CO1): a drawn stroke becomes a smoothed line and a
-- static body with a chain along it; where the line crosses itself the later stretch is front, the
-- earlier back, and a mover of one lane passes through the other lane's rail near the crossing.
-- Saved, loaded and cloned with its chain and its { closed, flips }.
-- Run with: love . --specs spec/track_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local library = require('src.library')
local track = require('src.track')
local callbacks = require('src.physics.physics-callbacks')

-- a stroke along straight pieces, a point every 5 (as a hand would give)
local function stroke(corners)
    local flat = {}
    for k = 1, #corners - 1 do
        local a, b = corners[k], corners[k + 1]
        local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
        local steps = math.max(1, math.floor(len / 5))
        for s = 0, steps - 1 do
            flat[#flat + 1] = a[1] + (b[1] - a[1]) * s / steps
            flat[#flat + 1] = a[2] + (b[2] - a[2]) * s / steps
        end
    end
    local last = corners[#corners]
    flat[#flat + 1], flat[#flat + 2] = last[1], last[2]
    return flat
end

local function makeTrack(corners)
    local vertices, closed = track.fromStroke(stroke(corners))
    local polygon = require('src.polygon')
    local cx, cy = polygon.getCenterOfPoints(vertices)
    local thing = objectManager.addThing('track', {
        x = cx, y = cy, bodyType = 'static', vertices = vertices, track = { closed = closed, flips = {} },
    })
    for _, f in ipairs(thing.body:getFixtures()) do f:setRestitution(0) end
    return thing
end

-- right along y = 0, then up to the right and back down through it: one crossing near (100, 0)
local CROSSING = { { -500, 0 }, { 500, 0 }, { 300, -400 }, { 0, 400 } }

local function ball(x, y)
    local thing = objectManager.addThing('circle', { x = x, y = y, radius = 15 })
    thing.body:setBullet(true)
    return thing.body
end

local function run(seconds)
    for _ = 1, math.floor(seconds * 60) do
        state.physicsWorld:update(1 / 60)
        track.update(1 / 60)
    end
end

describe('track', function()
    before_each(function()
        state.physicsWorld = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        state.physicsWorld:setCallbacks(unpack(callbacks))
        state.trackMovers = nil
        registry.reset()
    end)

    after_each(function()
        state.physicsWorld:setCallbacks()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        state.trackMovers = nil
        registry.reset()
    end)

    it('smooths a stroke into evenly spaced points, closing it when it ends near its start', function()
        local open, openClosed = track.fromStroke(stroke({ { 0, 0 }, { 400, 0 }, { 400, 300 } }))
        assert.is_false(openClosed)
        for i = 3, #open - 2, 2 do
            local d = math.sqrt((open[i] - open[i - 2]) ^ 2 + (open[i + 1] - open[i - 1]) ^ 2)
            assert.is_near(track.SPACING, d, 0.5)
        end
        local _, loopClosed = track.fromStroke(stroke({ { 0, 0 }, { 400, 0 }, { 400, 400 }, { 0, 400 }, { 10, 30 } }))
        assert.is_true(loopClosed)
        assert.is_nil(track.fromStroke(stroke({ { 0, 0 }, { 30, 0 } }))) -- too short
    end)

    it('is a static body with one chain, a loop when closed', function()
        local thing = makeTrack({ { 0, 0 }, { 400, 0 }, { 400, 400 }, { 0, 400 }, { 10, 30 } })
        assert.are.equal('static', thing.body:getType())
        local fixtures = thing.body:getFixtures()
        assert.are.equal(1, #fixtures)
        assert.are.equal('chain', fixtures[1]:getType())
        local layout = track.layout(thing)
        assert.is_true(layout.closed)
        assert.are.equal(layout.n, fixtures[1]:getShape():getChildCount()) -- a loop: as many edges as points
    end)

    it('puts the later stretch in front at a crossing, solid only for its own lane near it', function()
        local thing = makeTrack(CROSSING)
        local layout = track.layout(thing)
        assert.are.equal(1, #layout.crossings)
        local c = layout.crossings[1]
        assert.are.equal(track.BACK, layout.lane[c.e1])
        assert.are.equal(track.FRONT, layout.lane[c.e2])
        assert.are.equal(track.BACK, layout.mask[c.e1])
        assert.are.equal(track.FRONT, layout.mask[c.e2])
        assert.are.equal(3, layout.mask[1]) -- the start, far from the crossing: both lanes
        -- flipped: the other way round
        thing.track.flips[c.key] = true
        local flipped = track.layout(thing)
        assert.are.equal(track.FRONT, flipped.lane[c.e1])
        assert.are.equal(track.BACK, flipped.lane[c.e2])
    end)

    it('lets a back-lane ball fall through the front rail near the crossing, a front one lands', function()
        local thing = makeTrack(CROSSING)
        local layout = track.layout(thing)
        local c = layout.crossings[1]
        -- a point on the later (front) stretch, past the crossing toward its end, within the margin
        local e = c.e2 + 3
        local wx, wy = thing.body:getWorldPoint(layout.xs[e], layout.ys[e])
        local back, front = ball(wx, wy - 40), ball(wx + 0.5, wy - 40)
        -- `front` would hit `back`: keep them apart
        for _, f in ipairs(back:getFixtures()) do f:setGroupIndex(-7) end
        for _, f in ipairs(front:getFixtures()) do f:setGroupIndex(-7) end
        state.trackMovers = setmetatable({}, { __mode = 'k' })
        state.trackMovers[back] = { thing = thing, idx = c.e1, lane = track.BACK, away = 0 }
        state.trackMovers[front] = { thing = thing, idx = e, lane = track.FRONT, away = 0 }
        for _ = 1, 30 do state.physicsWorld:update(1 / 60) end -- no lane updates: they stay as set
        assert.is_true(back:getY() > wy + 100, 'the back ball fell through')
        -- the front ball landed: it's on the line (rolling down it), not below it
        assert.is_true(track.hits(thing.body:getFixtures()[1], front:getX(), front:getY(), 20), 'the front ball is on the rail')
    end)

    it('reads the chain edge a contact is on counting from 1 (as layout.mask is indexed)', function()
        local thing = makeTrack({ { 0, 0 }, { 400, 0 } })
        local layout = track.layout(thing)
        local wx, wy = thing.body:getWorldPoint((layout.xs[1] + layout.xs[2]) / 2, layout.ys[1])
        local body = ball(wx, wy - 16)
        local seen = nil
        state.physicsWorld:setCallbacks(nil, nil, function(a, b, contact)
            local ca, cb = contact:getChildren()
            seen = (a:getType() == 'chain') and ca or cb
        end)
        for _ = 1, 10 do state.physicsWorld:update(1 / 60) end
        assert.are.equal(1, seen)
        assert.is_truthy(body)
    end)

    it('gives a ball dropped on it the lane where it lands, and it rolls down the track', function()
        local thing = makeTrack({ { -400, -200 }, { 400, 200 } })
        local layout = track.layout(thing)
        local wx, wy = thing.body:getWorldPoint(layout.xs[3], layout.ys[3])
        local body = ball(wx, wy - 30)
        run(1)
        assert.are.equal(track.FRONT, track.laneOf(body))
        assert.is_true(body:getX() > wx + 50, 'rolled down to the right')
        assert.is_true(body:getY() < thing.body:getY() + 300, 'still on it, not fallen through')
    end)

    it('is cloned (through save data) with its chain, its loop and its track settings', function()
        local thing = makeTrack({ { 0, 0 }, { 400, 0 }, { 400, 400 }, { 0, 400 }, { 10, 30 } })
        thing.track.flips['1:9'] = true
        local copies = library.clone({ thing })
        assert.are.equal(1, #copies)
        local copy = copies[1]
        assert.are.equal('track', copy.shapeType)
        assert.is_true(copy.track.closed)
        assert.is_true(copy.track.flips['1:9'])
        local shape = copy.body:getFixtures()[1]:getShape()
        local original = thing.body:getFixtures()[1]:getShape()
        assert.are.equal('chain', shape:getType())
        assert.are.equal(original:getChildCount(), shape:getChildCount())
        assert.is_true(track.hits(copy.body:getFixtures()[1], copy.body:getWorldPoint(track.layout(copy).xs[1],
            track.layout(copy).ys[1])))
    end)

    it('keeps its settings when a point is dragged (the body is made again)', function()
        local thing = makeTrack(CROSSING)
        local verts = {}
        for i = 1, #thing.vertices do verts[i] = thing.vertices[i] end
        verts[1] = verts[1] - 40
        local again = objectManager.recreateThingFromBody(thing.body, { optionalVertices = verts })
        assert.are.equal(thing, again)
        assert.are.equal('chain', again.body:getFixtures()[1]:getType())
        assert.is_false(again.track.closed)
        assert.are.equal(1, #track.layout(again).crossings)
    end)
end)

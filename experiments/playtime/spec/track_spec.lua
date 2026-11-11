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

    it('swaps over and under where a crossing marker is clicked, and back again', function()
        local thing = makeTrack(CROSSING)
        local c = track.layout(thing).crossings[1]
        local wx, wy = thing.body:getWorldPoint(c.x, c.y)
        assert.is_nil(track.crossingAt(thing, wx + 40, wy, 20)) -- beside it: nothing
        local hit = track.crossingAt(thing, wx + 5, wy - 5, 20)
        assert.are.equal(c.key, hit.key)
        track.flipCrossing(thing, hit)
        local flipped = track.layout(thing)
        assert.are.equal(track.FRONT, flipped.lane[c.e1])
        assert.are.equal(track.BACK, flipped.lane[c.e2])
        assert.are.equal(track.FRONT, flipped.mask[c.e1])
        track.flipCrossing(thing, flipped.crossings[1])
        assert.is_nil(thing.track.flips[c.key]) -- back as drawn: nothing kept
        assert.are.equal(track.BACK, track.layout(thing).lane[c.e1])
    end)

    it('bends around a dragged point: neighbours follow, less further along, none past the reach', function()
        local verts = {}
        for i = 0, 40 do verts[#verts + 1] = i * 20; verts[#verts + 1] = 0 end -- 41 points, 20 apart
        local i = 21 -- the middle, at x 400
        verts[i * 2] = verts[i * 2] - 100 -- dragged up 100
        track.dragNeighbours(verts, i, 0, -100, false, 160)
        assert.is_near(-100 * 0.5 * (1 + math.cos(math.pi * 20 / 160)), verts[22 * 2], 1e-6)
        assert.is_true(verts[22 * 2] < verts[24 * 2] and verts[24 * 2] < 0, 'less further along')
        assert.is_near(verts[22 * 2], verts[20 * 2], 1e-6) -- the same both ways
        assert.are.equal(0, verts[30 * 2]) -- 180 along: past the reach
        assert.are.equal(0, verts[1 * 2])
    end)

    it('inserts and removes points with the painted zones kept in step', function()
        local thing = makeTrack({ { 0, 0 }, { 400, 0 } })
        thing.track.marks = '..ll' -- points 3 and 4 lift
        local verts = {}
        for k = 1, #thing.vertices do verts[k] = thing.vertices[k] end
        local n = #verts / 2
        -- a point between 1 and 2: the marks move up by one, the new point takes point 1's zone
        assert.is_true(track.insertPoint(thing, verts, (verts[1] + verts[3]) / 2, verts[2] + 3))
        assert.are.equal(n + 1, #verts / 2)
        assert.are.equal('...ll', thing.track.marks)
        -- point 4 (was 3) gone
        assert.is_true(track.removePoint(thing, verts, verts[7], verts[8], 5))
        assert.are.equal('...l', thing.track.marks)
        assert.is_false(track.removePoint(thing, verts, verts[7] + 500, verts[8], 5)) -- nothing near
        -- an open track has no edge from its end to its start: a point near that gap goes on a real edge
        assert.is_true(track.insertPoint(thing, verts, verts[1] - 30, verts[2]))
        assert.are.equal(verts[1], verts[1]) -- (still a list of numbers)
    end)

    it('closes into a loop with a bridge back to the start, and opens again', function()
        local thing = makeTrack({ { 0, 0 }, { 600, 0 }, { 600, -400 } }) -- an L: its ends ~720 apart
        local n = track.layout(thing).n
        local verts = track.setClosed(thing, true)
        assert.is_true(#verts / 2 > n + 30, 'bridged with points')
        local again = objectManager.recreateThingFromBody(thing.body, { optionalVertices = verts })
        local layout = track.layout(again)
        assert.is_true(layout.closed)
        assert.are.equal(layout.n, again.body:getFixtures()[1]:getShape():getChildCount()) -- a loop
        -- open: the same points, the chain open again
        local opened = objectManager.recreateThingFromBody(again.body, { optionalVertices = track.setClosed(again, false) })
        assert.is_false(track.layout(opened).closed)
        assert.are.equal(track.layout(opened).n - 1, opened.body:getFixtures()[1]:getShape():getChildCount())
    end)

    it('paints the stretch drawn with a key held: the zone lands at the same share of the way along', function()
        local flat = stroke({ { 0, 0 }, { 900, 0 } })
        local brushes = {}
        local n = #flat / 2
        for i = 1, n do
            local x = flat[i * 2 - 1]
            brushes[i] = (x >= 300 and x < 600) and 'lift' or false -- h held over the middle third
        end
        local vertices, closed, marks = track.fromStroke(flat, brushes)
        assert.is_false(closed)
        assert.is_truthy(marks)
        for i = 1, #vertices / 2 do
            local x = vertices[i * 2 - 1]
            local c = marks:sub(i, i)
            if x < 280 or x > 620 then
                assert.is_true(c == '' or c == '.', 'plain at x ' .. x)
            elseif x > 320 and x < 580 then
                assert.are.equal('l', c, 'lift at x ' .. x)
            end
        end
        assert.is_nil(select(3, track.fromStroke(flat, {}))) -- nothing held: no marks
    end)

    it('paints zones on the points under the brush, kept as a character per point, and clears them', function()
        local thing = makeTrack({ { 0, 0 }, { 1000, 0 } })
        local layout = track.layout(thing)
        local wx, wy = thing.body:getWorldPoint(layout.xs[10], layout.ys[10])
        assert.is_true(track.paint(thing, wx, wy, 45, 'lift'))
        assert.is_false(track.paint(thing, wx, wy, 45, 'lift')) -- nothing new
        local painted = track.layout(thing)
        assert.are_not.equal(layout, painted) -- made again
        assert.are.equal('lift', painted.zone[10])
        assert.are.equal('lift', painted.zone[8])
        assert.is_nil(painted.zone[5])
        assert.are.equal('.......lllll', thing.track.marks)
        track.paint(thing, wx, wy, 1000, 'clear')
        assert.is_nil(thing.track.marks)
        -- rolls: a run of roll points is one roll, pi along it
        track.paint(thing, wx, wy, 45, 'roll')
        local rolled = track.layout(thing)
        assert.are.equal(1, #rolled.rolls)
        assert.are.equal(0, track.rollAt(rolled, rolled.rolls[1].s0 - 5))
        assert.is_near(math.pi / 2, track.rollAt(rolled, (rolled.rolls[1].s0 + rolled.rolls[1].s1) / 2), 1e-6)
        assert.is_near(math.pi, track.rollAt(rolled, rolled.rolls[1].s1 + 5), 1e-6)
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

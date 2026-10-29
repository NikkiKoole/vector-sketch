-- spec/liquid_spec.lua
-- The water maths of the LIQUID sfixture (src/liquid.lua): area, clipping below a
-- line, and finding the level that holds an amount, upright and tilted.
-- Pure: busted spec/liquid_spec.lua (also runs under love . --specs).

local liquid = require('src.liquid')

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-3) end

-- a 100 x 200 box, top at y = 0, bottom at y = 200 (y points down)
local BOX = { 0, 0, 100, 0, 100, 200, 0, 200 }

-- rotate a flat polygon around (cx, cy)
local function rotated(poly, angle, cx, cy)
    local out = {}
    local c, s = math.cos(angle), math.sin(angle)
    for i = 1, #poly, 2 do
        local x, y = poly[i] - cx, poly[i + 1] - cy
        out[i], out[i + 1] = cx + x * c - y * s, cy + x * s + y * c
    end
    return out
end

describe('liquid', function()
    it('measures an area whatever the winding', function()
        assert.is_true(near(20000, liquid.area(BOX)))
        assert.is_true(near(20000, liquid.area({ 0, 0, 0, 200, 100, 200, 100, 0 })))
    end)

    it('clips a polygon to the part below a line', function()
        local below = liquid.clipBelow(BOX, 150)
        assert.is_true(near(100 * 50, liquid.area(below)))
        assert.are.equal(0, #liquid.clipBelow(BOX, 250))
        assert.is_true(near(20000, liquid.area(liquid.clipBelow(BOX, -10))))
    end)

    it('finds the level that holds an amount, upright', function()
        local level, water = liquid.levelFor(BOX, 100 * 50)
        assert.is_true(near(150, level, 1e-2), 'level ' .. tostring(level))
        assert.is_true(near(5000, liquid.area(water), 0.5))
    end)

    it('keeps the amount and a level surface when tilted', function()
        local tilted = rotated(BOX, math.rad(30), 50, 100)
        local level, water = liquid.levelFor(tilted, 5000)
        assert.is_true(near(5000, liquid.area(water), 0.5))
        for i = 2, #water, 2 do
            assert.is_true(water[i] >= level - 1e-6, 'every water point is on or below the surface')
        end
        -- tilting moves the low corner down, so the surface sits lower than the box's centre
        assert.is_true(level > 100)
    end)

    it('is empty with nothing in it, and the whole cavity when over full', function()
        assert.is_nil(liquid.levelFor(BOX, 0))
        local level, water = liquid.levelFor(BOX, 99999)
        assert.are.equal(0, level)
        assert.are.equal(BOX, water)
    end)

    it('holds only what fits below the lower end of its mouth', function()
        -- the box's mouth is its first edge (the top); upright it holds all of it
        assert.is_true(near(20000, liquid.capacity(BOX)))
        -- tilted a bit it keeps some: the level sits at the mouth's lower corner
        local tilted = rotated(BOX, math.rad(30), 50, 100)
        local capacity = liquid.capacity(tilted)
        assert.is_true(capacity > 0 and capacity < 20000)
        local level = liquid.levelFor(tilted, capacity)
        assert.is_true(near(math.max(tilted[2], tilted[4]), level, 0.01))
        -- on its side the mouth reaches all the way down: it all runs out
        assert.is_true(near(0, liquid.capacity(rotated(BOX, math.rad(90), 50, 100)), 1))
        -- upside down the mouth is at the bottom: nothing stays in
        assert.is_true(near(0, liquid.capacity(rotated(BOX, math.pi, 50, 100)), 1))
    end)

    -- a U: walls 10 thick in a 100 x 100 box, as three convex pieces (like Box2D fixtures)
    local U = {
        { 0, 0, 10, 0, 10, 100, 0, 100 },     -- left wall
        { 90, 0, 100, 0, 100, 100, 90, 100 }, -- right wall
        { 10, 90, 90, 90, 90, 100, 10, 100 }, -- bottom
    }
    local function hullOf(pieces)
        local points = {}
        for _, piece in ipairs(pieces) do for i = 1, #piece do points[#points + 1] = piece[i] end end
        return liquid.hull(points)
    end

    it('finds a U-shape\'s hollow: its hull less the body, open across the top', function()
        local hull = hullOf(U)
        assert.is_true(near(10000, liquid.area(hull)))
        assert.is_true(near(80 * 90, liquid.volume(hull, U)))
        local open = liquid.openEdges(hull, U)
        assert.are.equal(1, #open)
        local i = open[1]
        local j = (i + 2 > #hull) and 1 or i + 2
        assert.are.equal(0, hull[i + 1]); assert.are.equal(0, hull[j + 1]) -- the top edge
        -- half full: the water stands 45 deep on the bottom (at y = 90)
        local level = liquid.levelFor(hull, 80 * 45, U)
        assert.is_true(near(45, level, 0.01), 'level ' .. tostring(level))
    end)

    it('finds a curved bowl\'s hollow and mouth', function()
        -- a half ring below y = 0, radius 90 to 100, in 12 quads (like a drawn ribbon)
        local pieces = {}
        local steps = 12
        for k = 0, steps - 1 do
            local a1, a2 = math.pi * k / steps, math.pi * (k + 1) / steps
            pieces[#pieces + 1] = {
                math.cos(a1) * 90, math.sin(a1) * 90, math.cos(a1) * 100, math.sin(a1) * 100,
                math.cos(a2) * 100, math.sin(a2) * 100, math.cos(a2) * 90, math.sin(a2) * 90,
            }
        end
        local hull = hullOf(pieces)
        local inner = math.pi * 90 * 90 / 2
        local volume = liquid.volume(hull, pieces)
        assert.is_true(volume > inner * 0.95 and volume < inner * 1.01, 'volume ' .. volume)
        local open = liquid.openEdges(hull, pieces)
        assert.are.equal(1, #open, 'only the line across the top is open')
        -- upright it holds it all; on its side the mouth reaches the bottom and it empties
        assert.is_true(near(volume, liquid.capacity(hull, pieces, 0), 1))
    end)
end)

-- The kitchen test scene (scripts/kitchen.playtime.json): cups on the table, a bath.
if not love or not love.physics then return end

describe('liquid in the kitchen scene', function()
    local state = require('src.state')
    local sceneLoader = require('src.scene-loader')
    local subtypes = require('src.subtypes')

    local function liquids()
        local found = {}
        for _, body in ipairs(state.physicsWorld:getBodies()) do
            for _, fixture in ipairs(body:getFixtures()) do
                local ud = fixture:getUserData()
                if type(ud) == 'table' and subtypes.is(ud, subtypes.LIQUID) then
                    found[#found + 1] = { body = body, extra = ud.extra, label = body:getUserData().thing.label }
                end
            end
        end
        return found
    end

    it('loads with two cups and a bath, and their water keeps its amount as a cup tilts', function()
        if not state.physicsWorld or state.physicsWorld:isDestroyed() then
            state.physicsWorld = love.physics.newWorld(0, 980, true)
        end
        sceneLoader.loadScriptAndScene('kitchen')
        local all = liquids()
        local labels = {}
        for _, l in ipairs(all) do labels[l.label] = (labels[l.label] or 0) + 1 end
        assert.are.equal(2, labels.cup)
        assert.are.equal(1, labels.bath)

        for _ = 1, 120 do state.physicsWorld:update(1 / 60) end -- the cups settle on the table

        local cup
        for _, l in ipairs(all) do if l.label == 'cup' then cup = l end end
        local c = liquid.container(cup.extra, cup.body)
        local volume = liquid.volume(c.hull, c.holes)
        assert.is_true(volume > 0, 'the cup has a hollow')
        local amount = cup.extra.fill * volume
        local level0, _, hull0, holes0 = liquid.water(cup.extra, cup.body)
        assert.is_true(near(amount, liquid.areaBelow(hull0, holes0, level0), 1))
        assert.is_true(math.abs(cup.body:getAngle()) < 0.1, 'the cup stands on the table')

        cup.body:setAngle(math.rad(35))
        local level, tilted, hull, holes = liquid.water(cup.extra, cup.body)
        assert.is_true(near(amount, liquid.areaBelow(hull, holes, level), 1))
        for i = 2, #tilted, 2 do assert.is_true(tilted[i] >= level - 1e-6) end

        -- tipped further it spills while playing (not while paused), down to the mouth's lower end
        cup.body:setAngle(math.rad(80))
        local fill = cup.extra.fill
        liquid.update(true)
        assert.are.equal(fill, cup.extra.fill)
        liquid.update(false)
        assert.is_true(cup.extra.fill < fill)
        local level2, _, hull2, holes2 = liquid.water(cup.extra, cup.body)
        assert.is_true(near(cup.extra.fill * volume, liquid.areaBelow(hull2, holes2, level2), 1))
        -- upside down: empty
        cup.body:setAngle(math.pi)
        liquid.update(false)
        assert.is_true(cup.extra.fill < 0.001)

        -- and it all draws, through the textured world's z-sorted drawables
        local canvas = love.graphics.newCanvas(64, 64)
        local ok, err = pcall(function()
            love.graphics.setCanvas({ canvas, stencil = true })
            require('src.physics.box2d-draw-textured').drawTexturedWorld(state.physicsWorld)
            love.graphics.setCanvas()
        end)
        love.graphics.setCanvas()
        assert.is_true(ok, tostring(err))
    end)
end)


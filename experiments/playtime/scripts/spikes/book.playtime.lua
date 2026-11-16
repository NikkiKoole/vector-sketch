-- book: a Mipo picture book with the mechanics of children's books — flaps, a pull tab, a wheel, a pop-up, press here.
-- An open two-page spread on a table, with real physics Mipos living on the pages (Nikki: "shall we do a spike with
-- all sorts of flaps, pulls, wheels and the children book stuff?"; the list: STORY-IDEAS.md "Book mechanics").
-- Each spread shows a mechanic or two, one at a time so each can be judged:
--   1 lift the flap: a house with a door, two windows, a bush and a mailbox; under each a Mipo or a thing.
--     Lift a Mipo out and put it under another flap.
--   2 a pull tab (a Mipo comes up out of the chimney) and a wheel behind the page (day turns to night in the window)
--   3 a pop-up: a tree and a house fold up out of the page as it opens, Mipos riding up on them; down as you turn on
--   4 press here: tap a dot and it multiplies; tilt (left/right arrows, a phone's accelerometer) and it all slides
-- Turning the page is itself a big flap (scripts/spikes/book-flaps.lua, shared with the belly spike): drag the right
-- page's bottom corner over to the left, or the left one back.
-- Plain paper shapes and flat colours with a wobbly line; the real pictures are Nikki's to draw.
--
-- play mode (tab): drag corners, flaps, the tab, the wheel; grab Mipos as always.
-- keys: n next page   b back a page   left/right tilt (spread 4)   m a Mipo at the mouse   r this spread again
local s = {}

local flap = love.filesystem.load('scripts/spikes/book-flaps.lua')()

local PW, TOP, BOTTOM = 2600, -3000, 0 -- a page is PW wide; the spread runs from -PW to PW
local GROUND = -320                     -- the ground drawn on the pages, where Mipos stand
local PAPER = { 0.97, 0.94, 0.86 }
local PAPER_BACK = { 0.90, 0.86, 0.77 }
local INK = { 0.22, 0.16, 0.13 }

------------------------------------------------------------------------------------------------- helpers

local function alive(body) return body and not body:isDestroyed() end

local function book()
    state.book = state.book or { spread = 1, flaps = {}, mipos = {}, bodies = {}, hidden = {} }
    return state.book
end

local function hide(b, body)
    state.hiddenBodies = state.hiddenBodies or {}
    state.hiddenBodies[body] = true
    b.hidden[#b.hidden + 1] = body
end

-- a body this spread owns (destroyed when the page turns), hidden from the engine's plain drawing
local function own(b, body)
    b.bodies[#b.bodies + 1] = body
    hide(b, body)
    return body
end

local function edgeBody(b, kind, x, y, pts)
    local body = love.physics.newBody(world, x, y, kind)
    for i = 1, #pts - 3, 2 do
        local f = love.physics.newFixture(body, love.physics.newEdgeShape(pts[i], pts[i + 1], pts[i + 2], pts[i + 3]))
        f:setFriction(0.9)
    end
    return own(b, body)
end

-- a hand-made line: the points of a polygon with a small fixed wobble (the same every frame, no boil)
local function wobbly(poly, amount)
    local out, n = {}, #poly / 2
    amount = amount or 14
    for i = 1, n do
        local ax, ay = poly[2 * i - 1], poly[2 * i]
        local k = i % n + 1
        local bx, by = poly[2 * k - 1], poly[2 * k]
        local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
        local steps = math.max(1, math.floor(len / 120))
        for j = 0, steps - 1 do
            local t = j / steps
            local x, y = ax + (bx - ax) * t, ay + (by - ay) * t
            out[#out + 1] = x + (love.math.noise(x * 0.004, y * 0.004, 1) - 0.5) * amount * 2
            out[#out + 1] = y + (love.math.noise(x * 0.004, y * 0.004, 7) - 0.5) * amount * 2
        end
    end
    return out
end

local function fillPoly(poly)
    local ok, tris = pcall(love.math.triangulate, poly)
    if not ok then return end
    for _, t in ipairs(tris) do love.graphics.polygon('fill', t) end
end

-- a paper shape: a flat fill and an ink line
local function shape(poly, colour, line)
    love.graphics.setColor(colour)
    fillPoly(poly)
    if line ~= false then
        love.graphics.setColor(INK)
        love.graphics.setLineWidth(line or 12)
        local closed = { unpack(poly) }
        closed[#closed + 1], closed[#closed + 2] = poly[1], poly[2]
        love.graphics.line(closed)
        love.graphics.setLineWidth(1)
    end
end

local function rect(x1, y1, x2, y2) return { x1, y1, x2, y1, x2, y2, x1, y2 } end

local function circlePoly(cx, cy, r, n)
    local out = {}
    n = n or 24
    for i = 0, n - 1 do
        local a = i / n * math.pi * 2
        out[#out + 1], out[#out + 2] = cx + math.cos(a) * r, cy + math.sin(a) * r
    end
    return out
end

-- a kinematic body moved toward y, no faster than a Mipo standing on it can ride (else it's flung off)
local function rideTo(body, y, dt, maxSpeed)
    local v = (y - body:getY()) / math.max(dt, 1 / 240)
    maxSpeed = maxSpeed or 1400
    body:setLinearVelocity(0, math.max(-maxSpeed, math.min(maxSpeed, v)))
end

local function spawnMipo(b, x, y)
    return mipoKit.spawn(b.mipos, x, y)
end

local function ground()
    love.graphics.setColor(0.62, 0.78, 0.45)
    love.graphics.rectangle('fill', -PW + 60, GROUND, PW * 2 - 120, -GROUND - 60)
    love.graphics.setColor(INK)
    love.graphics.setLineWidth(10)
    love.graphics.line(wobbly({ -PW + 60, GROUND, PW - 60, GROUND }, 8))
    love.graphics.setLineWidth(1)
end

------------------------------------------------------------------------------------------------- spreads

local spreads = {}

-- 1. Lift the flap ------------------------------------------------------------------------------------
do
    local DOOR = rect(-1750, GROUND - 920, -1100, GROUND)
    local WIN_L = rect(-2150, -1650, -1800, -1300)
    local WIN_R = rect(-1000, -1650, -650, -1300)
    local BUSH = wobbly({ 650, GROUND, 1500, GROUND, 1560, GROUND - 350, 1420, GROUND - 650, 1150, GROUND - 780,
        850, GROUND - 700, 620, GROUND - 420 }, 30)
    local BOX = rect(1820, -1350, 2280, -1050)
    local FLAPS = {
        { key = 'door', poly = DOOR, def = { hingeX = -1750, from = GROUND, to = GROUND - 920, angle = math.pi * 0.8,
            spread = 0.1, drag = 650, pull = { -1, 0 }, height = 650,
            outside = { 0.80, 0.25, 0.20 }, inside = { 0.62, 0.45, 0.36 }, edge = INK } },
        { key = 'winL', poly = WIN_L, def = { hingeY = -1650, from = -2150, to = -1800, angle = math.pi * 0.85,
            spread = 0.15, drag = 350, pull = { 0, -1 }, height = 350,
            outside = { 0.35, 0.55, 0.80 }, inside = { 0.70, 0.62, 0.50 }, edge = INK } },
        { key = 'winR', poly = WIN_R, def = { hingeY = -1650, from = -650, to = -1000, angle = math.pi * 0.85,
            spread = 0.15, drag = 350, pull = { 0, -1 }, height = 350,
            outside = { 0.35, 0.55, 0.80 }, inside = { 0.70, 0.62, 0.50 }, edge = INK } },
        { key = 'bush', poly = BUSH, def = { hingeY = GROUND, from = 600, to = 1600, angle = math.pi * 0.7,
            spread = 0.4, drag = 700, pull = { 0, 1 }, height = 780,
            outside = { 0.30, 0.62, 0.30 }, inside = { 0.55, 0.70, 0.45 }, edge = INK } },
        { key = 'box', poly = BOX, def = { hingeY = -1050, from = 1820, to = 2280, angle = math.pi * 0.75,
            spread = 0.1, drag = 300, pull = { 0, 1 }, height = 300,
            outside = { 0.95, 0.78, 0.25 }, inside = { 0.70, 0.58, 0.40 }, edge = INK } },
    }
    local HOUSE = wobbly(rect(-2350, GROUND - 2050, -450, GROUND))
    local ROOF = wobbly({ -2550, GROUND - 2000, -1400, GROUND - 2750, -250, GROUND - 2000 })

    -- under the windows and the mailbox: a cat, a cake, a sock (drawn things)
    local function under(key, st)
        if st.open < 0.03 then return end
        if key == 'winL' then -- a cat
            love.graphics.setColor(0.25, 0.22, 0.30)
            love.graphics.rectangle('fill', -2150, -1650, 350, 350)
            shape(circlePoly(-1975, -1400, 110, 16), { 0.95, 0.65, 0.30 }, 8)
            shape({ -2060, -1480, -2040, -1580, -1990, -1500 }, { 0.95, 0.65, 0.30 }, 8)
            shape({ -1960, -1500, -1910, -1580, -1890, -1480 }, { 0.95, 0.65, 0.30 }, 8)
            love.graphics.setColor(INK)
            love.graphics.circle('fill', -2010, -1420, 12)
            love.graphics.circle('fill', -1940, -1420, 12)
        elseif key == 'winR' then -- a cake
            love.graphics.setColor(0.25, 0.22, 0.30)
            love.graphics.rectangle('fill', -1000, -1650, 350, 350)
            shape(rect(-930, -1440, -720, -1330), { 0.95, 0.85, 0.75 }, 8)
            shape(rect(-930, -1480, -720, -1440), { 0.95, 0.55, 0.65 }, 8)
            love.graphics.setColor(0.9, 0.2, 0.2)
            love.graphics.circle('fill', -825, -1510, 22)
        elseif key == 'box' then -- a sock
            love.graphics.setColor(0.30, 0.22, 0.12)
            love.graphics.rectangle('fill', 1820, -1350, 460, 300)
            shape({ 1950, -1320, 2050, -1320, 2050, -1160, 2160, -1140, 2160, -1080, 1950, -1080 },
                { 0.85, 0.30, 0.55 }, 8)
        end
    end

    spreads[1] = {
        name = 'lift the flap',
        flaps = FLAPS,
        build = function(b)
            spawnMipo(b, -1420, GROUND - 450) -- behind the door
            spawnMipo(b, 1080, GROUND - 450)  -- behind the bush
            spawnMipo(b, 350, GROUND - 450)   -- out on the page: put it under a flap
        end,
        drawBelow = function()
            ground()
            shape(ROOF, { 0.70, 0.30, 0.25 })
            shape(HOUSE, { 0.96, 0.85, 0.62 })
            love.graphics.setColor(0.18, 0.13, 0.12) -- the hall behind the door
            love.graphics.rectangle('fill', -1750, GROUND - 920, 650, 920)
            -- the mailbox's post
            shape(rect(2010, -1050, 2090, GROUND), { 0.55, 0.40, 0.25 }, 8)
        end,
        drawUnder = under,
    }
end

-- 2. A pull tab and a wheel ---------------------------------------------------------------------------
do
    local WHEEL = { -1400, -1400 }    -- the wheel's centre, behind the left page
    local WHEEL_R = 1300              -- it sticks out a little past the page's outer edge
    local WINDOW = { -1400, -1950, 480 } -- the round window in the page: x, y, r
    local CHIMNEY = { 1300, 1900, -2150 } -- x1, x2, top
    local LIFT_BASE, LIFT = GROUND - 650, 1250 -- up: its feet just over the chimney top
    local TAB = { PW - 40, -1000, 300, 200 } -- x, y, length out of the page, height

    local wheelCanvas
    local function makeWheel()
        local size = 1024
        wheelCanvas = love.graphics.newCanvas(size, size)
        love.graphics.push('all')
        love.graphics.setCanvas(wheelCanvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.origin()
        local c, r = size / 2, size / 2 - 4
        -- day on the top half, night on the bottom half, soft between
        for i = 0, 179 do
            local a1, a2 = i / 180 * math.pi * 2, (i + 1) / 180 * math.pi * 2
            local up = -math.sin((a1 + a2) / 2) -- 1 at the top
            local day = math.max(0, math.min(1, up * 3 + 0.5))
            love.graphics.setColor(0.10 + 0.45 * day, 0.12 + 0.62 * day, 0.30 + 0.62 * day)
            love.graphics.polygon('fill', c, c, c + math.cos(a1) * r, c + math.sin(a1) * r,
                c + math.cos(a2) * r, c + math.sin(a2) * r)
        end
        love.graphics.setColor(1, 0.85, 0.25)
        love.graphics.circle('fill', c, c - r * 0.62, 70)
        for k = 0, 11 do
            local a = k / 12 * math.pi * 2
            love.graphics.setLineWidth(10)
            love.graphics.line(c + math.cos(a) * 85, c - r * 0.62 + math.sin(a) * 85,
                c + math.cos(a) * 115, c - r * 0.62 + math.sin(a) * 115)
        end
        love.graphics.setColor(0.95, 0.93, 0.80)
        love.graphics.circle('fill', c, c + r * 0.62, 62)
        love.graphics.setColor(0.10, 0.12, 0.30)
        love.graphics.circle('fill', c + 28, c + r * 0.62 - 18, 52)
        love.graphics.setColor(1, 1, 0.85)
        for k = 1, 40 do
            local a = math.pi * (0.1 + 0.8 * love.math.noise(k, 1))
            local d = r * (0.25 + 0.7 * love.math.noise(k, 2))
            love.graphics.circle('fill', c + math.cos(a) * d, c + math.sin(a) * d, 5 + 6 * love.math.noise(k, 3))
        end
        -- the cardboard rim with notches, the part that sticks out of the page
        love.graphics.setColor(0.78, 0.62, 0.42)
        love.graphics.setLineWidth(60)
        love.graphics.circle('line', c, c, r - 30)
        love.graphics.setColor(0.55, 0.40, 0.25)
        love.graphics.setLineWidth(8)
        for k = 0, 47 do
            local a = k / 48 * math.pi * 2
            love.graphics.line(c + math.cos(a) * (r - 58), c + math.sin(a) * (r - 58), c + math.cos(a) * r,
                c + math.sin(a) * r)
        end
        love.graphics.pop()
    end

    -- the left page's paper with the round window cut out: rectangles round it and four corner fans
    local function paperWithWindow()
        local wx, wy, wr = WINDOW[1], WINDOW[2], WINDOW[3]
        love.graphics.setColor(PAPER)
        love.graphics.rectangle('fill', -PW, TOP, PW, wy - wr - TOP)
        love.graphics.rectangle('fill', -PW, wy + wr, PW, BOTTOM - (wy + wr))
        love.graphics.rectangle('fill', -PW, wy - wr, wx - wr + PW, wr * 2)
        love.graphics.rectangle('fill', wx + wr, wy - wr, -(wx + wr), wr * 2)
        for q = 0, 3 do
            local a0 = q * math.pi / 2
            local cx = wx + (math.cos(a0 + math.pi / 4) > 0 and wr or -wr)
            local cy = wy + (math.sin(a0 + math.pi / 4) > 0 and wr or -wr)
            local poly = { cx, cy }
            for k = 0, 8 do
                local a = a0 + k / 8 * math.pi / 2
                poly[#poly + 1], poly[#poly + 2] = wx + math.cos(a) * wr, wy + math.sin(a) * wr
            end
            fillPoly(poly)
        end
        love.graphics.setColor(INK)
        love.graphics.setLineWidth(16)
        love.graphics.circle('line', wx, wy, wr)
        love.graphics.setLineWidth(1)
    end

    local HOUSE = wobbly(rect(500, GROUND - 1250, 2100, GROUND))
    local ROOF = wobbly({ 380, GROUND - 1200, 1300, GROUND - 1850, 2220, GROUND - 1200 })
    local CHIM = wobbly(rect(CHIMNEY[1], CHIMNEY[3], CHIMNEY[2], GROUND - 1500))

    spreads[2] = {
        name = 'pull tab and wheel',
        wholeLeftPage = true, -- it draws its own left page (with the window)
        build = function(b)
            b.s2 = { pull = 0, rot = b.s2 and b.s2.rot or 0 }
            if not wheelCanvas then makeWheel() end
            -- the chimney: its walls, and a lift inside that the tab pushes up
            edgeBody(b, 'static', 0, 0, { CHIMNEY[1], GROUND, CHIMNEY[1], CHIMNEY[3] })
            edgeBody(b, 'static', 0, 0, { CHIMNEY[2], GROUND, CHIMNEY[2], CHIMNEY[3] })
            b.s2.lift = edgeBody(b, 'kinematic', 0, LIFT_BASE, { CHIMNEY[1] + 10, 0, CHIMNEY[2] - 10, 0 })
            spawnMipo(b, (CHIMNEY[1] + CHIMNEY[2]) / 2, LIFT_BASE - 400) -- down the chimney
            spawnMipo(b, -1300, GROUND - 450)                         -- under the sky
        end,
        press = function(b, mx, my, grabbed)
            if grabbed then return false end
            local t = TAB
            if mx > t[1] - 120 and mx < t[1] + t[3] + b.s2.pull * 700 + 80 and my > t[2] - 60 and my < t[2] + t[4] + 60 then
                b.s2.tabDrag = { x = mx, pull = b.s2.pull }
                return true
            end
            local dx, dy = mx - WHEEL[1], my - WHEEL[2]
            local inWindow = (mx - WINDOW[1]) ^ 2 + (my - WINDOW[2]) ^ 2 < WINDOW[3] ^ 2
            local onRim = mx < -PW and dx * dx + dy * dy < WHEEL_R ^ 2
            if inWindow or onRim then
                b.s2.wheelDrag = { a = math.atan2(dy, dx), rot = b.s2.rot }
                return true
            end
            return false
        end,
        release = function(b)
            b.s2.tabDrag, b.s2.wheelDrag = nil, nil
        end,
        update = function(b, dt, mx, my)
            local s2 = b.s2
            if s2.tabDrag then
                s2.pull = math.max(0, math.min(1, s2.tabDrag.pull + (mx - s2.tabDrag.x) / 700))
            else
                s2.pull = math.max(0, s2.pull - dt * 0.6) -- the tab slides slowly back in
            end
            if s2.wheelDrag then
                local a = math.atan2(my - WHEEL[2], mx - WHEEL[1])
                s2.rot = s2.wheelDrag.rot + (a - s2.wheelDrag.a)
            end
            local lift = s2.lift
            if alive(lift) then
                rideTo(lift, LIFT_BASE - s2.pull * LIFT, dt)
            end
            s2.night = (1 - math.cos(s2.rot)) / 2
        end,
        drawBelow = function(b)
            local s2 = b.s2
            love.graphics.setColor(1, 1, 1)
            local sc = WHEEL_R * 2 / wheelCanvas:getWidth()
            love.graphics.draw(wheelCanvas, WHEEL[1], WHEEL[2], s2.rot, sc, sc, wheelCanvas:getWidth() / 2,
                wheelCanvas:getHeight() / 2)
            paperWithWindow()
            love.graphics.setColor(PAPER)
            love.graphics.rectangle('fill', 0, TOP, PW, BOTTOM - TOP)
            ground()
            -- the tab: out of the page's edge, pulled out further
            local t = TAB
            local out = t[3] + s2.pull * 700
            shape(wobbly(rect(t[1], t[2], t[1] + out, t[2] + t[4]), 6), { 0.95, 0.55, 0.30 }, 10)
            love.graphics.setColor(INK)
            love.graphics.setLineWidth(12)
            local ax = t[1] + out - 90
            love.graphics.line(ax - 80, t[2] + t[4] / 2, ax + 40, t[2] + t[4] / 2)
            love.graphics.line(ax, t[2] + t[4] / 2 - 40, ax + 40, t[2] + t[4] / 2, ax, t[2] + t[4] / 2 + 40)
            love.graphics.setLineWidth(1)
        end,
        -- the house front and the chimney over the Mipo inside; the night over everything
        draw = function(b)
            shape(ROOF, { 0.40, 0.45, 0.70 })
            shape(HOUSE, { 0.92, 0.78, 0.60 })
            shape(CHIM, { 0.75, 0.35, 0.28 })
            shape(wobbly(rect(900, GROUND - 600, 1200, GROUND - 300), 6), { 0.98, 0.88, 0.45 }, 10)
            love.graphics.setColor(0.08, 0.10, 0.30, 0.45 * (b.s2.night or 0))
            love.graphics.rectangle('fill', -PW, TOP, PW * 2, BOTTOM - TOP)
        end,
    }
end

-- 3. A pop-up ------------------------------------------------------------------------------------------
do
    local BRANCH = { -2000, -1100, GROUND - 1250 } -- x1, x2, y: a flat branch Mipos stand on
    local BALCONY = { 700, 1900, GROUND - 1050 }
    local TRUNK = wobbly(rect(-1500, GROUND - 1600, -1250, GROUND))
    local CROWN = wobbly(circlePoly(-1380, GROUND - 2000, 650, 20), 30)
    local HOUSE = wobbly(rect(800, GROUND - 1950, 1800, GROUND))
    local ROOF = wobbly({ 650, GROUND - 1900, 1300, GROUND - 2500, 1950, GROUND - 1900 })

    -- the pop-up: everything squashed down to the page and standing up as p goes 0 -> 1
    local function up(b) return math.sin(math.max(0, math.min(1.1, b.s3.p)) * math.pi / 2) end
    local function popped(b, poly)
        local k = up(b)
        local out = {}
        for i = 1, #poly, 2 do
            out[#out + 1] = poly[i] + (poly[i + 1] - GROUND) * 0.12 * (1 - k)
            out[#out + 1] = GROUND + (poly[i + 1] - GROUND) * k
        end
        return out
    end

    spreads[3] = {
        name = 'pop-up',
        build = function(b)
            b.s3 = { p = 0, t = 0 }
            b.s3.branch = edgeBody(b, 'kinematic', 0, GROUND, { BRANCH[1], 0, BRANCH[2], 0 })
            b.s3.balcony = edgeBody(b, 'kinematic', 0, GROUND, { BALCONY[1], 0, BALCONY[2], 0 })
            spawnMipo(b, (BRANCH[1] + BRANCH[2]) / 2, GROUND - 450)
            spawnMipo(b, (BALCONY[1] + BALCONY[2]) / 2, GROUND - 450)
        end,
        update = function(b, dt, _, _, turning)
            local s3 = b.s3
            s3.t = s3.t + dt
            -- it stands up after the page lands (a spring, a little overshoot); a turn starting folds it down
            local target = turning > 0.02 and math.max(0, 1 - turning * 3) or 1
            s3.v = (s3.v or 0) + (30 * (target - s3.p) - 6.5 * (s3.v or 0)) * dt
            s3.p = math.max(0, s3.p + s3.v * dt)
            local k = up(b)
            for _, pair in ipairs({ { s3.branch, BRANCH }, { s3.balcony, BALCONY } }) do
                local body, def = pair[1], pair[2]
                if alive(body) then
                    rideTo(body, GROUND + (def[3] - GROUND) * k, dt, 2500)
                end
            end
        end,
        drawBelow = function(b)
            ground()
            local k = up(b)
            -- the fold's shadow on the page, growing as it stands up
            love.graphics.setColor(0, 0, 0, 0.12 * k)
            love.graphics.ellipse('fill', -1380, GROUND + 30, 800 * k + 50, 60)
            love.graphics.ellipse('fill', 1300, GROUND + 30, 700 * k + 50, 60)
            shape(popped(b, TRUNK), { 0.55, 0.38, 0.22 })
            shape(popped(b, CROWN), { 0.35 + 0.1 * (1 - k), 0.62, 0.32 })
            shape(popped(b, ROOF), { 0.80, 0.35, 0.30 })
            shape(popped(b, HOUSE), { 0.95, 0.88, 0.70 })
            shape(popped(b, rect(1100, GROUND - 1700, 1500, GROUND - 1350)), { 0.45, 0.65, 0.85 }, 10)
            -- the branch and the balcony Mipos stand on
            shape(popped(b, rect(BRANCH[1], BRANCH[3] - 20, BRANCH[2], BRANCH[3] + 60)), { 0.50, 0.34, 0.20 }, 10)
            shape(popped(b, rect(BALCONY[1], BALCONY[3] - 20, BALCONY[2], BALCONY[3] + 70)), { 0.75, 0.55, 0.40 }, 10)
        end,
    }
end

-- 4. Press here, and tilt -------------------------------------------------------------------------------
do
    local COLOURS = { { 0.90, 0.30, 0.30 }, { 0.95, 0.80, 0.25 }, { 0.30, 0.55, 0.85 }, { 0.40, 0.75, 0.40 },
        { 0.80, 0.45, 0.75 } }
    local R = 130

    local function addDot(b, x, y, c)
        local body = love.physics.newBody(world, x, y, 'dynamic')
        local f = love.physics.newFixture(body, love.physics.newCircleShape(R), 0.6)
        f:setFriction(0.5)
        f:setRestitution(0.3)
        own(b, body)
        b.s4.dots[#b.s4.dots + 1] = { body = body, c = c or random(#COLOURS) }
    end

    local function tiltFromDevice()
        for _, j in ipairs(love.joystick.getJoysticks()) do
            local name = (j:getName() or ''):lower()
            if name:find('accel') then return j:getAxis(1) end
        end
        return nil
    end

    spreads[4] = {
        name = 'press here, tilt',
        build = function(b)
            b.s4 = { dots = {}, tilt = 0 }
            for k = 0, 4 do addDot(b, -1800 + k * 900, -1600, k + 1) end
            -- a lid over the pages, so nothing leaves the book when it's tipped
            edgeBody(b, 'static', 0, 0, { -PW + 40, TOP + 40, PW - 40, TOP + 40 })
            spawnMipo(b, -900, GROUND - 450)
            spawnMipo(b, 1200, GROUND - 450)
        end,
        teardown = function(b)
            if b.g0 then world:setGravity(b.g0[1], b.g0[2]) end
        end,
        press = function(b, _, _, grabbed, now)
            for _, d in ipairs(b.s4.dots) do
                if grabbed == d.body then
                    b.s4.tap = { dot = d, t = now, x = d.body:getX(), y = d.body:getY() }
                    return false -- the pointer keeps it: it can be dragged too
                end
            end
            return false
        end,
        release = function(b, now)
            local tap = b.s4.tap
            b.s4.tap = nil
            if not (tap and alive(tap.dot.body)) then return end
            local x, y = tap.dot.body:getPosition()
            if now - tap.t < 0.35 and math.abs(x - tap.x) + math.abs(y - tap.y) < 120 and #b.s4.dots < 40 then
                tap.dot.c = tap.dot.c % #COLOURS + 1 -- a new colour, and one more of it
                addDot(b, x + (random() - 0.5) * 300, y - 2 * R - 40, tap.dot.c)
            end
        end,
        update = function(b, dt)
            local s4 = b.s4
            local device = s4.holdTilt or tiltFromDevice() -- holdTilt: from the bridge
            if device then
                s4.tilt = device * 0.8
            else
                local d = (love.keyboard.isDown('right') and 1 or 0) - (love.keyboard.isDown('left') and 1 or 0)
                if d ~= 0 then
                    s4.tilt = math.max(-0.7, math.min(0.7, s4.tilt + d * dt * 0.9))
                else
                    s4.tilt = s4.tilt * (1 - math.min(1, dt * 1.5)) -- back to level when let go
                end
            end
            local g = b.g0 and math.sqrt(b.g0[1] ^ 2 + b.g0[2] ^ 2) or 1960
            world:setGravity(math.sin(s4.tilt) * g, math.cos(s4.tilt) * g)
            for _, d in ipairs(s4.dots) do
                if alive(d.body) then d.body:setAwake(true) end
            end
        end,
        drawBelow = function(b)
            ground()
            love.graphics.setColor(INK)
            love.graphics.print('press here', -PW + 260, TOP + 260, 0, 9, 9)
            love.graphics.print('tilt the book', 300, TOP + 260, 0, 9, 9)
            for _, d in ipairs(b.s4.dots) do
                if alive(d.body) then
                    local x, y = d.body:getPosition()
                    shape(circlePoly(x, y, R, 20), COLOURS[d.c], 10)
                end
            end
        end,
    }
end

------------------------------------------------------------------------------------------------- the book

-- the page turn: the right page folding over the hinge to the left (forward), or the left back (back)
local TURN_FWD = { hingeX = 0, from = BOTTOM, to = TOP, angle = math.pi, spread = 0.5, drag = 2400, pull = { -1, 0 },
    stiffness = 14, damping = 6.5, -- a page turns slower than a flap
    height = PW, outside = PAPER, inside = PAPER_BACK, edge = { 0.55, 0.48, 0.40 }, edgeWidth = 8 }
TURN_FWD.grab = function(_, st, x, y) return st.open < 0.5 and x > PW - 650 and x < PW + 100 and y > -800 and y < 100 end
local TURN_BACK = { hingeX = 0, from = BOTTOM, to = TOP, angle = math.pi, spread = 0.5, drag = 2400, pull = { 1, 0 },
    stiffness = 14, damping = 6.5,
    height = PW, outside = PAPER, inside = PAPER_BACK, edge = { 0.55, 0.48, 0.40 }, edgeWidth = 8 }
TURN_BACK.grab = function(_, st, x, y) return st.open < 0.5 and x < -PW + 650 and x > -PW - 100 and y > -800 and y < 100 end
local RIGHT_PAGE = rect(0, TOP, PW, BOTTOM)
local LEFT_PAGE = rect(-PW, TOP, 0, BOTTOM)

local function flapsOf(b)
    b.flaps = b.flaps or {}
    return b.flaps
end

local function teardown(b)
    local sp = spreads[b.spread]
    if sp and sp.teardown then sp.teardown(b) end
    for _, inst in ipairs(mipoKit.alive(b.mipos)) do
        for _, part in pairs(inst.parts) do
            if alive(part.body) then objectManager.destroyBody(part.body) end
        end
    end
    for _, body in ipairs(b.bodies) do
        if alive(body) then body:destroy() end
    end
    for _, body in ipairs(b.hidden) do
        if state.hiddenBodies then state.hiddenBodies[body] = nil end
    end
    b.mipos, b.bodies, b.hidden = {}, {}, {}
    local f = flapsOf(b)
    for k in pairs(f) do f[k] = nil end
end

local function frame(b)
    -- the pages' floor and outer walls, for every spread
    edgeBody(b, 'static', 0, 0, { -PW + 40, TOP - 1500, -PW + 40, GROUND, PW - 40, GROUND, PW - 40, TOP - 1500 })
end

local function build(b, n)
    teardown(b)
    b.spread = math.max(1, math.min(#spreads, n))
    frame(b)
    spreads[b.spread].build(b)
end

local function turn(b, dir)
    if dir > 0 and b.spread < #spreads then flap.state(flapsOf(b), 'turnFwd').target = 1 end
    if dir < 0 and b.spread > 1 then flap.state(flapsOf(b), 'turnBack').target = 1 end
end

local BOUNDS = { -3600, -4900, 3600, 1300 }
local function lookAtBook()
    local w, h = love.graphics.getDimensions()
    local scale = math.max(w / (BOUNDS[3] - BOUNDS[1]), h / (BOUNDS[4] - BOUNDS[2]), math.min(w / 6200, h / 3900))
    cam:setScale(scale)
    cam:setTranslation(0, -1450)
end

function s.onStart()
    worldState.paused = false
    local b = book()
    b.g0 = b.g0 or { world:getGravity() }
    world:setGravity(b.g0[1], b.g0[2])
    b.mipos = mipoKit.alive(b.mipos or {})
    if #b.bodies == 0 or not alive(b.bodies[1]) or #b.mipos == 0 then build(b, b.spread or 1) end
    camera.setBounds(BOUNDS[1], BOUNDS[2], BOUNDS[3], BOUNDS[4])
    lookAtBook()
end

function s.onUnload()
    local b = state.book
    if not b then return end
    if b.g0 then world:setGravity(b.g0[1], b.g0[2]) end
    for _, body in ipairs(b.bodies) do
        if alive(body) then body:destroy() end
    end
    for _, body in ipairs(b.hidden) do
        if state.hiddenBodies then state.hiddenBodies[body] = nil end
    end
    b.bodies, b.hidden = {}, {}
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local b = book()
    if key == 'n' then turn(b, 1)
    elseif key == 'b' then turn(b, -1)
    elseif key == 'r' then build(b, b.spread)
    elseif key == 'm' then
        local mx, my = mouseWorldPos()
        spawnMipo(b, mx, my)
    end
end

-- From the bridge: s.goTo(n) builds spread n (next frame: a build spawns Mipos, too much for one eval); s.turn(1 | -1)
function s.goTo(n) book().goTo = n end
function s.turn(dir) turn(book(), dir) end

local panelRect = { 0, 20, 300, 0 }
local function overPanel()
    if ui.isPanelFolded('•• book ••') then return false end
    local mx, my = love.mouse.getPosition()
    local r = panelRect
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

function s.update(dt)
    local b = book()
    if #b.bodies == 0 then return end
    b.t = (b.t or 0) + dt
    local now = b.t
    if b.goTo then
        local n = b.goTo
        b.goTo = nil
        build(b, n)
    end
    local sp = spreads[b.spread]
    local f = flapsOf(b)
    local fwd, back = flap.state(f, 'turnFwd'), flap.state(f, 'turnBack')
    local mx, my = mouseWorldPos()
    local down = state.playMode and love.mouse.isDown(1)

    if down and not b.pressing then
        b.pressing = true
        local grabbed = getInteractedWithPointer()[1]
        if not overPanel() then
            local taken = sp.press and sp.press(b, mx, my, grabbed, now)
            if not taken then
                -- the spread's flaps: a press on a closed flap opens it, even when it grabbed the Mipo under it
                for _, fl in ipairs(sp.flaps or {}) do
                    local st = flap.state(f, fl.key)
                    if flap.contains(fl.def, st, fl.poly, mx, my) then
                        if grabbed then
                            if st.open < 0.5 then st.target = 1 end
                        else
                            flap.press(st, mx, my, now)
                        end
                        taken = true
                        break
                    end
                end
            end
            if not taken and not grabbed then
                if b.spread < #spreads and flap.contains(TURN_FWD, fwd, RIGHT_PAGE, mx, my) then
                    flap.press(fwd, mx, my, now)
                elseif b.spread > 1 and flap.contains(TURN_BACK, back, LEFT_PAGE, mx, my) then
                    flap.press(back, mx, my, now)
                end
            end
        end
    elseif not down and b.pressing then
        b.pressing = nil
        if sp.release then sp.release(b, now) end
        for _, fl in ipairs(sp.flaps or {}) do flap.release(flap.state(f, fl.key), now) end
        flap.release(fwd, now)
        flap.release(back, now)
    end

    for _, fl in ipairs(sp.flaps or {}) do flap.update(fl.def, flap.state(f, fl.key), dt, mx, my) end
    flap.update(TURN_FWD, fwd, dt, mx, my)
    flap.update(TURN_BACK, back, dt, mx, my)
    if sp.update then sp.update(b, dt, mx, my, math.max(fwd.open, back.open)) end

    -- a page that has gone over: the next (or the last) spread
    if fwd.open > 0.97 and not fwd.drag then
        build(b, b.spread + 1)
    elseif back.open > 0.97 and not back.drag then
        build(b, b.spread - 1)
    end
end

function s.drawBelow()
    local b = state.book
    if not (b and #b.bodies > 0) then return end
    local sp = spreads[b.spread]
    -- the table, the cover under the pages, the pages and the gutter's shadow
    love.graphics.setColor(0.55, 0.38, 0.24)
    love.graphics.rectangle('fill', -9000, -9000, 18000, 18000)
    love.graphics.setColor(0.50, 0.34, 0.20)
    for k = -30, 30 do love.graphics.rectangle('fill', -9000, k * 300, 18000, 40) end
    love.graphics.setColor(0.35, 0.12, 0.12)
    love.graphics.rectangle('fill', -PW - 90, TOP - 90, PW * 2 + 180, BOTTOM - TOP + 180, 40)
    love.graphics.setColor(PAPER)
    if not sp.wholeLeftPage then love.graphics.rectangle('fill', -PW, TOP, PW, BOTTOM - TOP) end
    love.graphics.rectangle('fill', 0, TOP, PW, BOTTOM - TOP)
    if sp.drawBelow then sp.drawBelow(b) end
    for _, fl in ipairs(sp.flaps or {}) do
        if sp.drawUnder then sp.drawUnder(fl.key, flap.state(flapsOf(b), fl.key)) end
    end
    for k = 1, 8 do
        love.graphics.setColor(0, 0, 0, 0.035)
        love.graphics.rectangle('fill', -k * 30, TOP, k * 60, BOTTOM - TOP)
    end
    love.graphics.setColor(INK[1], INK[2], INK[3], 0.6)
    love.graphics.print(tostring(b.spread * 2 - 1), -PW + 120, BOTTOM - 260, 0, 5, 5)
    love.graphics.print(tostring(b.spread * 2), PW - 220, BOTTOM - 260, 0, 5, 5)
    -- the corners to turn by: a little curl
    love.graphics.setColor(PAPER_BACK)
    if b.spread < #spreads then love.graphics.polygon('fill', PW, BOTTOM - 260, PW, BOTTOM, PW - 260, BOTTOM) end
    if b.spread > 1 then love.graphics.polygon('fill', -PW, BOTTOM - 260, -PW, BOTTOM, -PW + 260, BOTTOM) end
    love.graphics.setColor(1, 1, 1, 1)
end

function s.draw()
    local b = state.book
    if not (b and #b.bodies > 0) then return end
    local sp = spreads[b.spread]
    local f = flapsOf(b)
    for _, fl in ipairs(sp.flaps or {}) do flap.draw(fl.def, flap.state(f, fl.key), fl.poly) end
    if sp.draw then sp.draw(b) end
    -- a page turning: what's on it fades as it lifts (it goes with the page), then the sheet itself
    local fwd, back = flap.state(f, 'turnFwd'), flap.state(f, 'turnBack')
    if fwd.open > 0.01 then
        love.graphics.setColor(PAPER[1], PAPER[2], PAPER[3], math.min(1, fwd.open * 4))
        love.graphics.rectangle('fill', 0, TOP, PW, BOTTOM - TOP)
        flap.draw(TURN_FWD, fwd, RIGHT_PAGE)
    end
    if back.open > 0.01 then
        love.graphics.setColor(PAPER[1], PAPER[2], PAPER[3], math.min(1, back.open * 4))
        love.graphics.rectangle('fill', -PW, TOP, PW, BOTTOM - TOP)
        flap.draw(TURN_BACK, back, LEFT_PAGE)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local b = state.book
    if not (b and state.playMode) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 300
    local rows = 4
    local h = BH * rows + pad * (rows + 1) + 20
    local sw = love.graphics.getDimensions()
    local x0, y0 = sw / ui.scale - w - 20, 20
    panelRect[1], panelRect[3], panelRect[4] = x0, w, h
    ui.panel(x0, y0, w, h, '•• book ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, string.format('%d/%d  %s', b.spread, #spreads, spreads[b.spread].name))
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        local half = (w - 20 - pad) / 2
        if ui.button(x, y, half, '< back (b)') then turn(b, -1) end
        if ui.button(x + half + pad, y, half, 'next (n) >') then turn(b, 1) end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'this spread again (r)') then build(b, b.spread) end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        local tilt = b.s4 and b.spread == 4 and b.s4.tilt or 0
        ui.label(x, y, string.format('tilt %.2f (left/right)', tilt))
    end)
end

return s

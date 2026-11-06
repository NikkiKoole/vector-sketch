-- tracks: marbles and carts rolling through a glass pipe on two depth layers, a knikkerbaan to watch (docs/TRACKS.md)
-- The pipe is a closed loop: a centre line (waypoints with rounded corners, resampled to an even
-- step: arc length, nearest point), its walls as chains offset either side. Every stretch is in a
-- track layer, a collision category: the zigzag down is layer A (front); a loop at the bottom
-- turns to layer B over its top, so its way out passes behind its way in; the riser up through
-- the middle and the way back over the top are B too, crossing the zigzag three times. Where the
-- layer changes, both layers' walls run side by side for a stretch; a mover's filter switches at
-- its middle by arc position (rolling back switches it back), and only the drawn depth eases
-- across: smaller toward a vanishing point, hazier. Stretches can drive (achtbaan's flags, here
-- forces along the pipe, not set speeds): a tyre drive holding the speed into the loop, a brake after it, and the
-- riser a hoist that pulls everything up and over the top, like a buizenpost.
-- A cart: a box on four wheels, two on each wall of the pipe, so a loop can't drop it; only its
-- wheels touch the walls. No buttons: it runs on its own.
-- Two courses (n switches): the knikkerbaan above, and a classic out-and-back coaster.
-- keys: m a marble   c a cart   r start over   n the next course   f the camera follows the cart   p pause

local s = {}

-- Track layers are collision categories (TRACKS.md): 2..6 reserved for them (16: hair tufts).
local TRACK_LAYERS = { A = 2, B = 3, C = 4, D = 5, E = 6 }
local DEFAULT_DEPTH = { A = 0, B = 1, C = 2, D = 3, E = 4 } -- drawn depth: 0 in front
local LAYER_DEPTH = DEFAULT_DEPTH -- the course's own (set with the course)

local HALF = 70           -- the pipe's inside half width
local CORNER = 200        -- corner radius (well over HALF, or the inner wall folds)
local STEP = 15           -- centre line sample spacing (px of arc length)
local TRANSITION = 600    -- length of a layer change, both layers' walls side by side (360 showed a jog)
local WALL = 8            -- drawn wall thickness
local MARBLE_R = 40        -- two side by side would need 160: more than the pipe (30 wedged across it in pairs)
local MAX_MOVERS = 14
-- the cart: wheels at both ends, on both walls, with a little play across (a bend widens the
-- pipe along the cart's normal, so it never jams; the box stays clear of the walls)
local CART_LENGTH = 160
local CART_HALF_HEIGHT = 30
local WHEEL_R = 20
local AXLE_ALONG = 55     -- axles this far before and behind the middle
local AXLE_ACROSS = HALF - WHEEL_R - 3 -- 3 px of play on each wall
local CART_DENSITY = 3
local WHEEL_DENSITY = 4   -- near the box's mass: light wheels under a heavy box let the joints stretch
-- driving stretches: { speed, gain (1/s) }; hoist cancels gravity along the pipe and holds the
-- speed both ways, pace holds it both ways (a coaster's tyre drive), a brake only slows down to it
local DRIVES = {
    hoist = { speed = 700, gain = 4 },
    pace = { speed = 2000, gain = 3 }, -- a rolling marble needs ~1800 for the loop (1750 and they rolled back)
    brake = { speed = 500, gain = 3 },
}
local STILL_FOR = 6       -- seconds stopped outside the hoist: nudged along the pipe
-- drawn depth: a layer one deeper is drawn this much smaller toward the vanishing point, hazier
local DEPTH_SHRINK = 0.16
local DEPTH_HAZE = 0.4
local VANISH_X, VANISH_Y = 950, 1000 -- the course's own (set with the course)
-- the cart drawn as a box in 3D: depth 1 is this far back (px), which makes the shrink a
-- perspective with the eye at VANISH, DEPTH_Z / DEPTH_SHRINK in front of the screen
local DEPTH_Z = 600
local CART_WIDTH = 110    -- across, into the screen (Box2D has only its length and height)

local COLORS = {
    { 0.85, 0.25, 0.2 }, { 0.2, 0.45, 0.85 }, { 0.95, 0.75, 0.2 }, { 0.25, 0.65, 0.35 },
    { 0.6, 0.35, 0.75 }, { 0.95, 0.5, 0.2 }, { 0.3, 0.75, 0.8 }, { 0.9, 0.45, 0.6 },
}

local function newStats() return { escapes = 0, topSpeed = 0, switches = 0, cartTop = 0, loops = 0 } end

local function check() -- on state: a script hot reload keeps them rolling
    state.tracksSpike = state.tracksSpike or { movers = {}, stats = newStats() }
    return state.tracksSpike
end

local function alive(body) return body and not body:isDestroyed() end

-- ─── The track: waypoints → centre line → walls per layer ───

-- the course, in the direction of travel, y down. Each waypoint starts a straight stretch to the
-- next one, in a layer, maybe driving. Waypoints on a straight line split a stretch (a layer
-- change in the middle of one).
local KNIKKERBAAN = {
    { -300, 0, 'A' },
    { 2200, 300, 'A' },       -- the zigzag down, in front
    { 2200, 750, 'A' },
    { 100, 1000, 'A' },
    { 100, 1450, 'A' },
    { 2200, 1700, 'A' },      -- then a drop
    { 2200, 2500, 'A', drive = 'pace' }, -- the run-in to the loop, held at its speed
    -- the loop: a square with corners as big as can be, so a circle (with 200 px corners at
    -- ~2000 px/s the cart took ~10 g, wedged sideways and everything piled up behind it)
    -- up, driven too: a train of bunched movers stalled halfway up, and what rolled back blocked the rest
    { 1300, 2500, 'A', r = 300, drive = 'pace' },
    { 1300, 1900, 'A', r = 300 }, -- over the top (turning to the back layer),
    { 1600, 1900, 'B' },
    { 1900, 1900, 'B', r = 300 }, -- and down, behind the run-in
    { 1900, 2700, 'B', drive = 'brake' }, -- the run-out, braked
    { 1000, 2700, 'B', drive = 'hoist' }, -- the riser, behind the zigzag, crossing it
    { 1000, -800, 'B', roll = 1 }, -- over the top, back to the left, behind: a corkscrew
    { -300, -650, 'B' },
    { -300, -325, 'A' },      -- halfway down the drop: to the front again
}
-- (a stretch must be longer than the corners at its ends take, ~CORNER each for a right angle,
-- or the arcs overlap and the walls fold: a Box2D chain assertion)

-- a classic out-and-back coaster, seen from the side: a station, a lift hill, a steep first drop
-- straight into a loop (where the speed is: with a camelback and an airtime hill before it, the
-- carts rocked in the valley in front of it), the loop turning to B over its top so its way out
-- passes behind its way in, back to the front for a camelback and an airtime hill, a turnaround
-- up into C (furthest back) and home through C, behind everything, then a U-turn back to the
-- front into the station. Waypoint speed: that stretch's drive speed (else DRIVES').
local COASTER = {
    { 0, 0, 'A', drive = 'pace', speed = 300 },          -- the station: rolled out slowly
    { 600, 0, 'A', drive = 'hoist', speed = 450, r = 300 }, -- the lift hill, a chain lift
    { 2000, -1400, 'A', r = 400 },                       -- the crest, then the first drop
    -- (r 400 here lost the most of the whole ride: ~600 px of height at ~2500 px/s)
    { 3000, 600, 'A', r = 700 },                         -- into the loop: up,
    { 3800, 600, 'A', r = 300 },
    { 3800, 0, 'A', r = 300 },                           -- over the top (to the back layer),
    { 3450, 0, 'B' },
    { 3100, 0, 'B', r = 300 },                           -- and down, behind the way in
    { 3100, 800, 'B', r = 300 },
    { 4300, 800, 'A' },                                  -- clear of the loop: to the front again
    { 4800, 800, 'A', r = 400 },
    { 5700, 0, 'A', r = 600 },                           -- the camelback
    { 6700, 700, 'A', r = 450 },
    { 7500, 200, 'A', r = 600 },                         -- an airtime hill
    { 8300, 700, 'A', r = 400 },
    -- the turnaround and the way home kept low: by here a cart has lost ~1000 px of height to the
    -- bends (an 800 px climb up a turnaround stopped it, rocking in the valley before it)
    { 9300, 700, 'A', r = 200 },                         -- the turnaround: up,
    { 9300, 500, 'C' },                                  -- into the furthest layer,
    { 9300, 300, 'C', r = 180 },                         -- and home, behind everything:
    { 7500, 400, 'C', r = 700 },                         -- bunny hops
    { 6000, 650, 'C', r = 700 },
    { 4500, 500, 'C', r = 700 },
    { 2500, 750, 'C', drive = 'brake', speed = 400, r = 600 }, -- braked,
    { -700, 750, 'C', drive = 'hoist', speed = 300, r = 300 }, -- tyres lift it round a U-turn to the front
    { -700, 375, 'A', drive = 'hoist', speed = 300 },
    { -700, 0, 'A', drive = 'pace', speed = 300, r = 300 }, -- into the station
}

local COURSES = {
    knikkerbaan = {
        waypoints = KNIKKERBAAN, vanish = { 950, 1000 }, camera = { 950, 980, 0.2 },
        carts = 1, marbles = 4,
    },
    coaster = {
        waypoints = COASTER, vanish = { 4300, -300 }, camera = { 4300, -350, 0.11 },
        depth = { A = 0, B = 0.6, C = 1.2, D = 1.8, E = 2.4 },
        carts = 2, marbles = 0, follow = true,
    },
}
local COURSE_ORDER = { 'knikkerbaan', 'coaster' }
local WAYPOINTS = KNIKKERBAAN -- the course being built (set from state on start)

-- the centre line, dense: straight stretches with arcs at the corners; each point knows its
-- stretch's layer and drive (an arc belongs to the stretch after it; a hoist carries on through
-- the corner after it, over the top)
local function cornerPoints()
    local pts = {}
    local n = #WAYPOINTS
    local function add(x, y, w, drive, roll, speed)
        pts[#pts + 1] = { x = x, y = y, layer = w[3], drive = drive, roll = roll or 0,
            speed = speed or (drive == w.drive and w.speed) or nil }
    end
    -- each corner's arc: from where it leaves the stretch before to where it joins the next
    local arcs = {}
    for i = 1, n do
        local a, p, b = WAYPOINTS[(i - 2) % n + 1], WAYPOINTS[i], WAYPOINTS[i % n + 1]
        local ux, uy = p[1] - a[1], p[2] - a[2]
        local ul = math.sqrt(ux * ux + uy * uy)
        ux, uy = ux / ul, uy / ul
        local vx, vy = b[1] - p[1], b[2] - p[2]
        local vl = math.sqrt(vx * vx + vy * vy)
        vx, vy = vx / vl, vy / vl
        local turn = math.acos(math.max(-1, math.min(1, ux * vx + uy * vy)))
        local radius = p.r or CORNER
        if turn < 1e-3 then
            arcs[i] = { x0 = p[1], y0 = p[2], x1 = p[1], y1 = p[2] }
        else
            local t = radius * math.tan(turn / 2)
            local cross = ux * vy - uy * vx
            local nx, ny = -uy, ux
            if cross < 0 then nx, ny = uy, -ux end
            local x0, y0 = p[1] - ux * t, p[2] - uy * t
            local cx, cy = x0 + nx * radius, y0 + ny * radius
            arcs[i] = { r = radius,
                x0 = x0, y0 = y0, x1 = p[1] + vx * t, y1 = p[2] + vy * t,
                cx = cx, cy = cy, a0 = math.atan2(y0 - cy, x0 - cx), sweep = cross < 0 and -turn or turn,
            }
        end
    end
    for i = 1, n do
        local w, prev = WAYPOINTS[i], WAYPOINTS[(i - 2) % n + 1]
        local arc = arcs[i]
        if arc.cx then
            local drive = prev.drive == 'hoist' and 'hoist' or w.drive
            local speed = prev.drive == 'hoist' and prev.speed or w.speed
            local count = math.max(2, math.floor(math.abs(arc.sweep) * arc.r / 5))
            for k = 0, count do
                local ang = arc.a0 + arc.sweep * k / count
                add(arc.cx + math.cos(ang) * arc.r, arc.cy + math.sin(ang) * arc.r, w, drive, 0, speed)
            end
        else
            add(arc.x0, arc.y0, w, w.drive)
        end
        -- the straight stretch to the next corner's arc
        local nextArc = arcs[i % n + 1]
        local dx, dy = nextArc.x0 - arc.x1, nextArc.y0 - arc.y1
        local count = math.max(1, math.floor(math.sqrt(dx * dx + dy * dy) / 5))
        for k = 1, count - 1 do
            -- a stretch with roll = n turns the cart round n times along it (drawn only: a corkscrew)
            add(arc.x1 + dx * k / count, arc.y1 + dy * k / count, w, w.drive, (w.roll or 0) * 2 * math.pi * k / count)
        end
    end
    return pts
end

-- resample a closed line at an even step: { x, y, s, tx, ty, nx, ny, layer, drive }
local function resample(pts, step)
    local n = #pts
    local total = 0
    local cum = { 0 }
    for i = 1, n do
        local a, b = pts[i], pts[i % n + 1]
        total = total + math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
        cum[i + 1] = total
    end
    local count = math.floor(total / step)
    step = total / count
    local out, j = {}, 1
    for k = 0, count - 1 do
        local d = k * step
        while cum[j + 1] < d do j = j + 1 end
        local a, b = pts[j], pts[j % n + 1]
        local t = (d - cum[j]) / math.max(1e-9, cum[j + 1] - cum[j])
        out[#out + 1] = { x = a.x + (b.x - a.x) * t, y = a.y + (b.y - a.y) * t, s = d,
            layer = a.layer, drive = a.drive, speed = a.speed, roll = a.roll } -- roll not blended: wraps at 2 pi
    end
    -- tangents (central difference) and normals (to the right of travel: y down, so (-ty, tx))
    local m = #out
    for i = 1, m do
        local a, b = out[(i - 2) % m + 1], out[i % m + 1]
        local dx, dy = b.x - a.x, b.y - a.y
        local len = math.sqrt(dx * dx + dy * dy)
        out[i].tx, out[i].ty = dx / len, dy / len
        out[i].nx, out[i].ny = -dy / len, dx / len
    end
    return out, total
end

local function smoothstep(t)
    t = math.max(0, math.min(1, t))
    return t * t * (3 - 2 * t)
end

-- the layer changes: which layers' walls each point has, and its drawn depth (eased across)
local function transitions(line, length)
    local n = #line
    local changes = {}
    for i = 1, n do
        local a, b = line[i], line[i % n + 1]
        if a.layer ~= b.layer then
            changes[#changes + 1] = { s = b.s ~= 0 and b.s or length, from = a.layer, to = b.layer }
        end
    end
    for _, p in ipairs(line) do
        p.walls = { [p.layer] = true }
        p.depth = LAYER_DEPTH[p.layer]
        for _, ch in ipairs(changes) do
            local d = p.s - ch.s -- signed, around the loop
            if d > length / 2 then d = d - length elseif d < -length / 2 then d = d + length end
            if math.abs(d) <= TRANSITION / 2 then
                p.walls[ch.from], p.walls[ch.to] = true, true
                local t = smoothstep(d / TRANSITION + 0.5)
                p.depth = LAYER_DEPTH[ch.from] + (LAYER_DEPTH[ch.to] - LAYER_DEPTH[ch.from]) * t
            end
        end
    end
end

-- runs of consecutive indices where keep(i), around a closed loop: { {i, i+1, ...}, ... }
local function runs(n, keep)
    local start
    for i = 1, n do
        if not keep(i) then start = i break end
    end
    if not start then -- all of it
        local all = {}
        for i = 1, n do all[i] = i end
        all[#all + 1] = 1
        return { all }
    end
    local out, cur = {}, nil
    for k = 1, n do
        local i = (start + k - 1) % n + 1
        if keep(i) then
            cur = cur or {}
            cur[#cur + 1] = i
        elseif cur then
            out[#out + 1] = cur
            cur = nil
        end
    end
    if cur then out[#out + 1] = cur end
    return out
end

local function buildTrack()
    local line, length = resample(cornerPoints(), STEP)
    transitions(line, length)
    for _, p in ipairs(line) do
        p.lx, p.ly = p.x - p.nx * HALF, p.y - p.ny * HALF
        p.rx, p.ry = p.x + p.nx * HALF, p.y + p.ny * HALF
    end
    local layers = {}
    for _, p in ipairs(line) do layers[p.layer] = true end
    return { line = line, length = length, layers = layers }
end

local function makeTrack()
    local c = check()
    if c.track and alive(c.track.body) then return end
    local track = buildTrack()
    track.body = love.physics.newBody(world, 0, 0, 'static')
    local line = track.line
    for layer in pairs(track.layers) do
        for _, run in ipairs(runs(#line, function(i) return line[i].walls[layer] end)) do
            if #run >= 2 then
                for _, side in ipairs({ 'l', 'r' }) do
                    local points = {}
                    for _, i in ipairs(run) do
                        points[#points + 1] = line[i][side .. 'x']
                        points[#points + 1] = line[i][side .. 'y']
                    end
                    -- Box2D 2.3 chains collide on both sides: no winding to get right (TRACKS.md)
                    local f = love.physics.newFixture(track.body, love.physics.newChainShape(false, points))
                    f:setFriction(0.6)
                    f:setCategory(TRACK_LAYERS[layer])
                end
            end
        end
    end
    c.track = track
end

-- the nearest centre line point to (x, y): a search around the last one (so at a crossing it
-- stays on its own stretch), all of it when lost
local function nearest(track, x, y, hint)
    local line = track.line
    local n = #line
    local best, bestD = nil, math.huge
    local function try(i)
        local p = line[i]
        local d = (p.x - x) ^ 2 + (p.y - y) ^ 2
        if d < bestD then best, bestD = i, d end
    end
    if hint then
        for k = -20, 20 do try((hint - 1 + k) % n + 1) end
    end
    if not best or bestD > (HALF * 2) ^ 2 then
        for i = 1, n do try(i) end
    end
    return best, math.sqrt(bestD)
end

-- ─── Movers: marbles and carts ───
-- { kind, body (the one followed), bodies, fixtures, mass, out (off the line further than this:
-- through a wall), index, layer, still, color }

-- a mover in a layer: its own category, every other track layer masked out
local function setLayer(m, layer)
    if m.layer == layer then return end
    local others = {}
    for name, category in pairs(TRACK_LAYERS) do
        if name ~= layer then others[#others + 1] = category end
    end
    for _, f in ipairs(m.fixtures) do
        f:setCategory(TRACK_LAYERS[layer])
        f:setMask(unpack(others))
    end
    m.layer = layer
end

-- a free spot near the start: behind whatever is there already
local function startIndex(c, room)
    local line = c.track.line
    local i = 1
    for _ = 1, 40 do
        local free = true
        for _, m in ipairs(c.movers) do
            if alive(m.body) then
                local x, y = m.body:getPosition()
                local dx, dy = x - line[i].x, y - line[i].y
                if dx * dx + dy * dy < (room + (m.kind == 'cart' and CART_LENGTH / 2 or MARBLE_R) + 10) ^ 2 then
                    free = false
                end
            end
        end
        if free then return i end
        i = (i - 4 - 1) % #line + 1
    end
    return nil
end

local function addMover(c, m, i)
    m.index, m.still = i, 0
    m.mass = 0
    for _, b in ipairs(m.bodies) do
        b:setBullet(true)
        m.mass = m.mass + b:getMass()
    end
    setLayer(m, c.track.line[i].layer)
    c.movers[#c.movers + 1] = m
end

local function addMarble()
    local c = check()
    if #c.movers >= MAX_MOVERS then return end
    local i = startIndex(c, MARBLE_R)
    if not i then return end
    local p = c.track.line[i]
    local body = love.physics.newBody(world, p.x, p.y, 'dynamic')
    local f = love.physics.newFixture(body, love.physics.newCircleShape(MARBLE_R), 1)
    f:setFriction(0.6)
    f:setRestitution(0.2)
    addMover(c, {
        kind = 'marble', body = body, bodies = { body }, fixtures = { f },
        out = HALF + MARBLE_R, color = COLORS[#c.movers % #COLORS + 1],
    }, i)
end

local function addCart()
    local c = check()
    if #c.movers >= MAX_MOVERS then return end
    local i = startIndex(c, CART_LENGTH / 2)
    if not i then return end
    local p = c.track.line[i]
    local angle = math.atan2(p.ty, p.tx)
    local body = love.physics.newBody(world, p.x, p.y, 'dynamic')
    body:setAngle(angle)
    local box = love.physics.newFixture(body,
        love.physics.newRectangleShape(CART_LENGTH - 2 * WHEEL_R, 2 * CART_HALF_HEIGHT), CART_DENSITY)
    box:setFriction(0.3)
    local bodies, fixtures, wheels = { body }, { box }, {}
    for _, along in ipairs({ -AXLE_ALONG, AXLE_ALONG }) do
        for _, across in ipairs({ -AXLE_ACROSS, AXLE_ACROSS }) do
            local wx = p.x + p.tx * along + p.nx * across
            local wy = p.y + p.ty * along + p.ny * across
            local wheel = love.physics.newBody(world, wx, wy, 'dynamic')
            local wf = love.physics.newFixture(wheel, love.physics.newCircleShape(WHEEL_R), WHEEL_DENSITY)
            wf:setFriction(0.05) -- low: grippy wheels skid each time the cart swaps walls (not the main loss, though)
            love.physics.newRevoluteJoint(body, wheel, wx, wy, false)
            bodies[#bodies + 1], fixtures[#fixtures + 1] = wheel, wf
            wheels[#wheels + 1] = wheel
        end
    end
    addMover(c, {
        kind = 'cart', body = body, bodies = bodies, fixtures = fixtures, wheels = wheels,
        out = HALF, color = COLORS[#c.movers % #COLORS + 1],
    }, i)
end

local function removeMovers()
    local c = check()
    for _, m in ipairs(c.movers) do
        for _, b in ipairs(m.bodies) do
            if alive(b) then b:destroy() end -- its joints go with it
        end
    end
    c.movers = {}
end

local function startOver()
    local c = check()
    removeMovers()
    c.stats = newStats()
    local course = COURSES[c.course] or COURSES.knikkerbaan
    for _ = 1, course.carts do addCart() end
    for _ = 1, course.marbles do addMarble() end
end

-- every body of a mover to (x, y), lined up with the pipe there, at rest
local function putBack(m, p)
    local x0, y0 = m.body:getPosition()
    local a0 = m.body:getAngle()
    local a1 = math.atan2(p.ty, p.tx)
    local cs, sn = math.cos(a1 - a0), math.sin(a1 - a0)
    for _, b in ipairs(m.bodies) do
        local bx, by = b:getPosition()
        local dx, dy = bx - x0, by - y0
        b:setPosition(p.x + dx * cs - dy * sn, p.y + dx * sn + dy * cs)
        b:setAngle(b:getAngle() + a1 - a0)
        b:setLinearVelocity(0, 0)
        b:setAngularVelocity(0)
    end
end

-- along the pipe: drive to a speed (DRIVES), the whole mover's mass at its main body
local function drive(m, p, vt, gy)
    local d = DRIVES[p.drive]
    local a = d.gain * ((p.speed or d.speed) - vt)
    if p.drive == 'hoist' then
        a = a - gy * p.ty
    elseif p.drive == 'brake' then
        a = math.min(0, a)
    end
    m.body:applyForce(p.tx * a * m.mass, p.ty * a * m.mass)
end

local function updateMover(c, m, dt, gy)
    local body = m.body
    local x, y = body:getPosition()
    local i, dist = nearest(c.track, x, y, m.index)
    local before = m.index
    m.index = i
    local p = c.track.line[i]
    m.s = p.s
    local vx, vy = body:getLinearVelocity()
    local speed = math.sqrt(vx * vx + vy * vy)
    if speed > c.stats.topSpeed then c.stats.topSpeed = speed end
    if m.kind == 'cart' and speed > c.stats.cartTop then c.stats.cartTop = speed end
    -- out of the pipe (through a wall): counted, put back at the start
    if dist > m.out then
        c.stats.escapes = c.stats.escapes + 1
        print(('tracks: a %s got out at s=%d, %d px off the line, %d px/s'):format(m.kind, p.s, dist, speed))
        putBack(m, c.track.line[1])
        m.index = 1
        setLayer(m, c.track.line[1].layer)
        return
    end
    -- the layer by arc position: the point's own layer changes at a transition's middle, where
    -- both layers' walls are; done here after the step, not in a contact callback (world locked)
    if p.layer ~= m.layer then
        m.wasLayer = m.layer
        setLayer(m, p.layer)
        c.stats.switches = c.stats.switches + 1
        -- a cart that made it over the loop's top (A to B there)
        -- (both courses go from A to B only over a loop's top)
        if m.kind == 'cart' and p.layer == 'B' and m.wasLayer == 'A' and i > before then
            c.stats.loops = c.stats.loops + 1
        end
    end
    local vt = vx * p.tx + vy * p.ty
    if p.drive then
        drive(m, p, vt, gy)
    end
    if p.drive == 'hoist' then
        m.still = 0
    elseif speed < 5 then
        m.still = m.still + dt
        if m.still > STILL_FOR then -- stuck on a flat: a push along
            body:applyLinearImpulse(p.tx * 200 * m.mass, p.ty * 200 * m.mass)
            m.still = 0
        end
    else
        m.still = 0
    end
end

-- ─── Drawing ───

local GLASS = { 0.75, 0.88, 0.95, 0.35 }
local GLASS_DRIVE = {
    hoist = { 0.95, 0.85, 0.6, 0.4 },
    pace = { 0.65, 0.95, 0.6, 0.4 },
    brake = { 0.95, 0.6, 0.55, 0.4 },
}
local RIM = { 0.35, 0.5, 0.6 }
local HAZE = { 0.1, 0.18, 0.12 } -- toward the background
local LIGHT_X, LIGHT_Y = -0.6, -0.8 -- toward the light
local CART_WOOD = { 0.78, 0.58, 0.36 }
local CART_DARK = { 0.45, 0.32, 0.2 }

-- a world point at a drawn depth: smaller toward the vanishing point
local function project(x, y, depth)
    local k = 1 - DEPTH_SHRINK * depth
    return VANISH_X + (x - VANISH_X) * k, VANISH_Y + (y - VANISH_Y) * k, k
end

local function hazed(col, depth, alpha)
    local h = math.min(1, DEPTH_HAZE * depth)
    return col[1] + (HAZE[1] - col[1]) * h, col[2] + (HAZE[2] - col[2]) * h, col[3] + (HAZE[3] - col[3]) * h,
        alpha or col[4] or 1
end

-- per layer: the glass as a triangle mesh (each segment drawn in its first point's layer) and the
-- rims and highlight as runs of lines; built once per track
local function layerLook(track, layer)
    track.looks = track.looks or {}
    if track.looks[layer] then return track.looks[layer] end
    local line = track.line
    local n = #line
    local verts = {}
    local function vert(p, x, y)
        local px, py = project(x, y, p.depth)
        local r, g, b, a = hazed(p.drive and GLASS_DRIVE[p.drive] or GLASS, p.depth)
        verts[#verts + 1] = { px, py, 0, 0, r, g, b, a }
    end
    local look = { rims = {} }
    for i = 1, n do
        local p, q = line[i], line[i % n + 1]
        if p.layer == layer then
            vert(p, p.lx, p.ly); vert(p, p.rx, p.ry); vert(q, q.lx, q.ly)
            vert(q, q.lx, q.ly); vert(p, p.rx, p.ry); vert(q, q.rx, q.ry)
        end
    end
    if #verts > 0 then look.mesh = love.graphics.newMesh(verts, 'triangles', 'static') end
    for _, run in ipairs(runs(n, function(i) return line[i].layer == layer end)) do
        run[#run + 1] = run[#run] % n + 1 -- on to the next point: no gap where the layer changes
        local left, right, glint, depth = {}, {}, {}, 0
        for _, i in ipairs(run) do
            local p = line[i]
            local x, y = project(p.lx, p.ly, p.depth)
            left[#left + 1], left[#left + 2] = x, y
            x, y = project(p.rx, p.ry, p.depth)
            right[#right + 1], right[#right + 2] = x, y
            -- the glint toward the light, smoothly: through the middle where the pipe points at it
            local side = p.nx * LIGHT_X + p.ny * LIGHT_Y
            x, y = project(p.x + p.nx * HALF * 0.6 * side, p.y + p.ny * HALF * 0.6 * side, p.depth)
            glint[#glint + 1], glint[#glint + 2] = x, y
            depth = math.max(depth, p.depth)
        end
        look.rims[#look.rims + 1] = { left = left, right = right, glint = glint, depth = depth }
    end
    track.looks[layer] = look
    return look
end

local function drawMarble(m, depth)
    local body = m.body
    local wx, wy = body:getPosition()
    local x, y, k = project(wx, wy, depth)
    local r = MARBLE_R * k
    local a = body:getAngle()
    local col = m.color
    love.graphics.setColor(hazed(col, depth, 1))
    love.graphics.circle('fill', x, y, r)
    -- a swirl inside that turns with the marble (to see it roll)
    love.graphics.setColor(1, 1, 1, 0.6 * (1 - 0.5 * math.min(1, depth)))
    love.graphics.setLineWidth(5 * k)
    love.graphics.arc('line', 'open', x, y, r * 0.55, a, a + 2.2)
    love.graphics.setColor(hazed({ col[1] * 0.5, col[2] * 0.5, col[3] * 0.5 }, depth, 1))
    love.graphics.setLineWidth(3 * k)
    love.graphics.circle('line', x, y, r)
    -- the glint stays up-left (the light)
    love.graphics.setColor(1, 1, 1, 0.85 * (1 - 0.4 * math.min(1, depth)))
    love.graphics.circle('fill', x - r * 0.35, y - r * 0.35, r * 0.18)
end

-- the cart as a box in 3D (TR5). Its frame: forward from the body's angle plus how fast the
-- track's depth changes there (it turns into the screen where the layer changes), up from the
-- body's up with the forward part taken out, then the track's roll about forward (corkscrew).
-- Corners projected like the layers (smaller toward the vanishing point); only the faces turned
-- toward the eye are drawn (a convex box: they never overlap), shaded from the light. Box2D's box
-- stays flat: drawn turned it's shorter, physics doesn't notice (TRACKS.md).
local EYE_Z = -DEPTH_Z / DEPTH_SHRINK
local LIGHT3 = { -0.45, -0.75, -0.5 } -- toward the light: up, left, toward us
do
    local l = math.sqrt(LIGHT3[1] ^ 2 + LIGHT3[2] ^ 2 + LIGHT3[3] ^ 2)
    LIGHT3 = { LIGHT3[1] / l, LIGHT3[2] / l, LIGHT3[3] / l }
end

local function project3(x, y, z)
    local k = 1 - DEPTH_SHRINK * z / DEPTH_Z
    return VANISH_X + (x - VANISH_X) * k, VANISH_Y + (y - VANISH_Y) * k
end

local function norm3(x, y, z)
    local l = math.sqrt(x * x + y * y + z * z)
    return x / l, y / l, z / l
end

-- the cart's frame: centre, forward, up and side (side = forward x up)
local function cartFrame(c, m)
    local line, n = c.track.line, #c.track.line
    local i = m.index
    local p = line[i]
    local ahead, behind = line[(i + 2) % n + 1], line[(i - 4) % n + 1]
    local dDepth = (ahead.depth - behind.depth) / (6 * STEP) -- per px along the track
    local x, y = m.body:getPosition()
    local a = m.body:getAngle()
    local fx, fy = math.cos(a), math.sin(a)
    -- the track's depth change, the way the cart points
    local dz = dDepth * DEPTH_Z * ((fx * p.tx + fy * p.ty) >= 0 and 1 or -1)
    fx, fy, dz = norm3(fx, fy, dz)
    local ux, uy, uz = math.sin(a), -math.cos(a), 0
    local d = ux * fx + uy * fy + uz * dz
    ux, uy, uz = norm3(ux - d * fx, uy - d * fy, uz - d * dz)
    local sx, sy, sz = fy * uz - dz * uy, dz * ux - fx * uz, fx * uy - fy * ux
    local cr, sr = math.cos(p.roll or 0), math.sin(p.roll or 0)
    ux, uy, uz, sx, sy, sz =
        ux * cr + sx * sr, uy * cr + sy * sr, uz * cr + sz * sr,
        sx * cr - ux * sr, sy * cr - uy * sr, sz * cr - uz * sr
    return { x = x, y = y, z = p.depth * DEPTH_Z, f = { fx, fy, dz }, u = { ux, uy, uz }, s = { sx, sy, sz },
        depth = p.depth }
end

-- a point at (along, up, side) in the cart's frame, in the world
local function at(fr, a, b, cc)
    return fr.x + a * fr.f[1] + b * fr.u[1] + cc * fr.s[1],
        fr.y + a * fr.f[2] + b * fr.u[2] + cc * fr.s[2],
        fr.z + a * fr.f[3] + b * fr.u[3] + cc * fr.s[3]
end

-- does the side of the frame with this normal face the eye, at this point?
local function facing(nx, ny, nz, px, py, pz)
    return nx * (px - VANISH_X) + ny * (py - VANISH_Y) + nz * (pz - EYE_Z) < 0
end

-- a flat shape in the cart's frame: points as {along, up, side}, filled with a colour shaded by n
local function quad3(fr, pts, col, n)
    local flat = {}
    for _, q in ipairs(pts) do
        local x, y, z = at(fr, q[1], q[2], q[3])
        flat[#flat + 1], flat[#flat + 2] = project3(x, y, z)
    end
    local light = math.max(0, n[1] * LIGHT3[1] + n[2] * LIGHT3[2] + n[3] * LIGHT3[3])
    local shade = 0.5 + 0.5 * light
    love.graphics.setColor(hazed({ col[1] * shade, col[2] * shade, col[3] * shade }, fr.depth, 1))
    love.graphics.polygon('fill', flat)
    return flat
end

local WHEEL_SIDES = 14
local function drawWheel3(fr, wheel, body, side)
    local lx, ly = body:getLocalPoint(wheel:getPosition())
    -- body local y is down: up is -y
    local spin = wheel:getAngle()
    local pts = {}
    for k = 0, WHEEL_SIDES - 1 do
        local t = k / WHEEL_SIDES * 2 * math.pi
        pts[#pts + 1] = { lx + math.cos(t) * WHEEL_R, -ly + math.sin(t) * WHEEL_R, side }
    end
    local n = side > 0 and fr.s or { -fr.s[1], -fr.s[2], -fr.s[3] }
    quad3(fr, pts, { 0.25, 0.23, 0.22 }, n)
    -- a spoke, to see it turn
    local x0, y0 = project3(at(fr, lx, -ly, side))
    local x1, y1 = project3(at(fr, lx + math.cos(spin) * WHEEL_R * 0.8, -ly - math.sin(spin) * WHEEL_R * 0.8, side))
    love.graphics.setColor(hazed({ 0.75, 0.75, 0.72 }, fr.depth, 1))
    love.graphics.setLineWidth(3)
    love.graphics.line(x0, y0, x1, y1)
end

local function drawCart(c, m)
    local fr = cartFrame(c, m)
    local hl, hh, hw = CART_LENGTH / 2, CART_HALF_HEIGHT + 6, CART_WIDTH / 2
    -- which side is toward the eye: the wheels there go over the box, the far ones under it
    local near = facing(fr.s[1], fr.s[2], fr.s[3], fr.x, fr.y, fr.z) and hw or -hw
    for _, wheel in ipairs(m.wheels) do drawWheel3(fr, wheel, m.body, -near) end
    -- the six faces: normal in the frame (along, up, side) and corners (signs of hl, hh, hw)
    local function makeFace(n, col, side, signs)
        local pts = {}
        for _, q in ipairs(signs) do pts[#pts + 1] = { q[1] * hl, q[2] * hh, q[3] * hw } end
        return { n = n, col = col, side = side, pts = pts }
    end
    local faces = {
        makeFace({ 0, 1, 0 }, CART_WOOD, false, { { -1, 1, -1 }, { 1, 1, -1 }, { 1, 1, 1 }, { -1, 1, 1 } }),
        makeFace({ 0, -1, 0 }, CART_DARK, false, { { -1, -1, -1 }, { 1, -1, -1 }, { 1, -1, 1 }, { -1, -1, 1 } }),
        makeFace({ 1, 0, 0 }, CART_WOOD, false, { { 1, -1, -1 }, { 1, 1, -1 }, { 1, 1, 1 }, { 1, -1, 1 } }),
        makeFace({ -1, 0, 0 }, CART_WOOD, false, { { -1, -1, -1 }, { -1, 1, -1 }, { -1, 1, 1 }, { -1, -1, 1 } }),
        makeFace({ 0, 0, 1 }, CART_WOOD, true, { { -1, -1, 1 }, { 1, -1, 1 }, { 1, 1, 1 }, { -1, 1, 1 } }),
        makeFace({ 0, 0, -1 }, CART_WOOD, true, { { -1, -1, -1 }, { 1, -1, -1 }, { 1, 1, -1 }, { -1, 1, -1 } }),
    }
    love.graphics.setLineJoin('bevel')
    for _, face in ipairs(faces) do
        local a, b, cc = face.n[1], face.n[2], face.n[3]
        local n = {
            a * fr.f[1] + b * fr.u[1] + cc * fr.s[1],
            a * fr.f[2] + b * fr.u[2] + cc * fr.s[2],
            a * fr.f[3] + b * fr.u[3] + cc * fr.s[3],
        }
        local mid = face.pts[1]
        local px, py, pz = at(fr, a * hl, b * hh, cc * hw)
        if facing(n[1], n[2], n[3], px, py, pz) then
            local flat = quad3(fr, face.pts, face.col, n)
            if face.side then -- the stripe along the side, in the cart's colour
                local z = mid[3]
                local h = hh * 0.25
                quad3(fr, { { -hl, -h, z }, { hl, -h, z }, { hl, h, z }, { -hl, h, z } }, m.color, n)
            end
            love.graphics.setColor(hazed(CART_DARK, fr.depth, 1))
            love.graphics.setLineWidth(3)
            love.graphics.polygon('line', flat)
        end
    end
    for _, wheel in ipairs(m.wheels) do drawWheel3(fr, wheel, m.body, near) end
end

-- one layer: its glass, the movers in it, its rims and glint over them
local function drawLayer(c, layer)
    local look = layerLook(c.track, layer)
    if look.mesh then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(look.mesh)
    end
    for _, m in ipairs(c.movers) do
        if alive(m.body) and m.layer == layer then
            local depth = c.track.line[m.index].depth
            if m.kind == 'cart' then drawCart(c, m) else drawMarble(m, depth) end
        end
    end
    love.graphics.setLineJoin('bevel')
    for _, rim in ipairs(look.rims) do
        local k = 1 - DEPTH_SHRINK * rim.depth
        love.graphics.setColor(hazed(RIM, rim.depth, 1))
        love.graphics.setLineWidth(WALL * k)
        if #rim.left >= 4 then
            love.graphics.line(rim.left)
            love.graphics.line(rim.right)
        end
        love.graphics.setColor(1, 1, 1, 0.35 * (1 - 0.5 * math.min(1, rim.depth)))
        love.graphics.setLineWidth(4 * k)
        if #rim.glint >= 4 then love.graphics.line(rim.glint) end
    end
end

function s.drawBelow()
    local c = check()
    if state.playMode then -- in play the script draws the pipe and movers itself
        c.savedDrawBodies = state.world.debugDrawBodies
        state.world.debugDrawBodies = false
    end
end

function s.draw()
    local c = check()
    if c.track and alive(c.track.body) then
        -- back to front
        local order = {}
        for layer in pairs(c.track.layers) do order[#order + 1] = layer end
        table.sort(order, function(a, b) return LAYER_DEPTH[a] > LAYER_DEPTH[b] end)
        for _, layer in ipairs(order) do drawLayer(c, layer) end
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
    if c.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = c.savedDrawBodies
        c.savedDrawBodies = nil
    end
end

-- ─── Scene ───

-- the course from state.tracksSpike.course: its waypoints, vanishing point, depths
local function useCourse(c)
    c.course = COURSES[c.course] and c.course or 'knikkerbaan'
    local course = COURSES[c.course]
    WAYPOINTS = course.waypoints
    VANISH_X, VANISH_Y = course.vanish[1], course.vanish[2]
    LAYER_DEPTH = course.depth or DEFAULT_DEPTH
    return course
end

local function showWhole(course)
    cam:setScale(course.camera[3])
    cam:setTranslation(course.camera[1], course.camera[2])
end

local function destroyAll(c)
    for _, m in ipairs(c.movers or c.marbles or {}) do
        for _, b in ipairs(m.bodies or { m.body }) do
            if alive(b) then b:destroy() end
        end
    end
    c.movers = {}
    if c.track and alive(c.track.body) then c.track.body:destroy() end
    c.track = nil
end

function s.onStart()
    worldState.paused = false
    local c = check()
    -- a track from an older version of this script (marbles only, a narrower pipe): built again
    if not c.movers or (c.track and (c.track.half ~= HALF or c.track.course ~= c.course)) then
        destroyAll(c)
    end
    local course = useCourse(c)
    if not c.track then showWhole(course) end
    if c.follow == nil then c.follow = course.follow or false end
    makeTrack()
    c.track.half, c.track.course = HALF, c.course
    if #c.movers == 0 then startOver() end
end

function s.onUnload()
    local c = state.tracksSpike
    if not c then return end
    removeMovers()
    if c.track and alive(c.track.body) then c.track.body:destroy() end
    state.tracksSpike = nil
end

-- the camera rides with the first cart (until you touch, drag or zoom)
local function follow(c)
    if not c.follow or love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0 then return end
    for _, m in ipairs(c.movers) do
        if m.kind == 'cart' and alive(m.body) then
            local x, y = m.body:getPosition()
            local k = 1 - DEPTH_SHRINK * c.track.line[m.index].depth
            x, y = VANISH_X + (x - VANISH_X) * k, VANISH_Y + (y - VANISH_Y) * k
            cam:setScale(0.35)
            local tx, ty = cam:getTranslation()
            cam:setTranslation(tx + (x - tx) * 0.08, ty + (y - ty) * 0.08)
            return
        end
    end
end

function s.update()
    local c = check()
    if not (c.track and alive(c.track.body)) then return end
    if worldState.paused then return end
    local dt = math.min(love.timer.getDelta(), 0.05)
    local _, gy = world:getGravity()
    for _, m in ipairs(c.movers) do
        if alive(m.body) then updateMover(c, m, dt, gy) end
    end
    follow(c)
end

function s.onKeyPress(key)
    local c = check()
    if key == 'm' then addMarble() end
    if key == 'c' then addCart() end
    if key == 'r' then startOver() end
    if key == 'p' then worldState.paused = not worldState.paused end
    if key == 'f' then
        c.follow = not c.follow
        if not c.follow then showWhole(COURSES[c.course]) end
    end
    if key == 'n' then -- the next course
        local index = 1
        for k, name in ipairs(COURSE_ORDER) do if name == c.course then index = k end end
        destroyAll(c)
        c.course = COURSE_ORDER[index % #COURSE_ORDER + 1]
        c.follow = nil
        s.onStart()
    end
end

return s

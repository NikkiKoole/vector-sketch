-- tracks: marbles rolling through a glass pipe on two depth layers, a knikkerbaan to watch (docs/TRACKS.md)
-- The pipe is a closed loop: a centre line (waypoints with rounded corners, resampled to an even
-- step: arc length, nearest point), its walls as chains offset either side. Every stretch is in a
-- track layer, a collision category: the zigzag down is layer A (front), the riser up through the
-- middle and the way back over the top are layer B (behind), so the riser crosses the zigzag three
-- times and the marbles pass behind each other. Where the layer changes, both layers' walls run
-- side by side for a stretch; a marble's filter switches at its middle by arc position (rolling
-- back switches it back), and only the drawn depth eases across: smaller toward a vanishing point,
-- hazier. The riser is a hoist stretch (achtbaan's hoist flag, here a force along the pipe):
-- it pulls the marbles up and over the top, like a buizenpost. No buttons: it runs on its own.
-- keys: m another marble   r start over   p pause

local s = {}

-- Track layers are collision categories (TRACKS.md): 2..6 reserved for them (16: hair tufts).
local TRACK_LAYERS = { A = 2, B = 3, C = 4, D = 5, E = 6 }
local LAYER_DEPTH = { A = 0, B = 1, C = 2, D = 3, E = 4 } -- drawn depth: 0 in front

local MARBLE_R = 30
local HALF = 46           -- the pipe's inside half width: a marble has 16 px to spare a side
local CORNER = 200        -- corner radius (well over HALF, or the inner wall folds)
local STEP = 15           -- centre line sample spacing (px of arc length)
local TRANSITION = 600    -- length of a layer change, both layers' walls side by side (360 showed a jog)
local WALL = 8            -- drawn wall thickness
local MARBLES = 4         -- at the start
local MAX_MARBLES = 12
local HOIST_SPEED = 700   -- px a second up the riser
local HOIST_GAIN = 4      -- 1/s: how quickly it gets a marble to that speed
local STILL_FOR = 6       -- seconds stopped outside the hoist: nudged along the pipe
-- drawn depth: a layer one deeper is drawn this much smaller toward the vanishing point, hazier
local DEPTH_SHRINK = 0.16
local DEPTH_HAZE = 0.4
local VANISH_X, VANISH_Y = 950, 900

local COLORS = {
    { 0.85, 0.25, 0.2 }, { 0.2, 0.45, 0.85 }, { 0.95, 0.75, 0.2 }, { 0.25, 0.65, 0.35 },
    { 0.6, 0.35, 0.75 }, { 0.95, 0.5, 0.2 }, { 0.3, 0.75, 0.8 }, { 0.9, 0.45, 0.6 },
}

local function check() -- on state: a script hot reload keeps the marbles rolling
    state.tracksSpike = state.tracksSpike or { marbles = {}, stats = { escapes = 0, topSpeed = 0, switches = 0 } }
    return state.tracksSpike
end

local function alive(body) return body and not body:isDestroyed() end

-- ─── The track: waypoints → centre line → walls per layer ───

-- the course, in the direction of travel, y down. Each waypoint starts a straight stretch to the
-- next one, in a layer, maybe a hoist. Waypoints on a straight line split a stretch (a layer
-- change in the middle of one).
local WAYPOINTS = {
    { -300, 0, 'A' },
    { 2200, 300, 'A' },       -- the zigzag down, in front
    { 2200, 750, 'A' },
    { 100, 1000, 'A' },
    { 100, 1450, 'A' },
    { 2200, 1700, 'A' },
    { 2200, 2150, 'A' },
    { 1600, 2225, 'B' },      -- halfway along the bottom run: into the back layer
    { 1000, 2300, 'B', hoist = true }, -- the riser, behind the zigzag, crossing it
    { 1000, -800, 'B' },      -- over the top, back to the left, behind
    { -300, -650, 'B' },
    { -300, -325, 'A' },      -- halfway down the drop: to the front again
}
-- (a stretch must be longer than the corners at its ends take, ~CORNER each for a right angle,
-- or the arcs overlap and the walls fold: a Box2D chain assertion)

-- the centre line, dense: straight stretches with arcs at the corners; each point knows its
-- stretch's layer and hoist (an arc belongs to the stretch after it, and is hoist when either is)
local function cornerPoints()
    local pts = {}
    local n = #WAYPOINTS
    local function add(x, y, w, hoist) pts[#pts + 1] = { x = x, y = y, layer = w[3], hoist = hoist } end
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
        if turn < 1e-3 then
            arcs[i] = { x0 = p[1], y0 = p[2], x1 = p[1], y1 = p[2] }
        else
            local t = CORNER * math.tan(turn / 2)
            local cross = ux * vy - uy * vx
            local nx, ny = -uy, ux
            if cross < 0 then nx, ny = uy, -ux end
            local x0, y0 = p[1] - ux * t, p[2] - uy * t
            local cx, cy = x0 + nx * CORNER, y0 + ny * CORNER
            arcs[i] = {
                x0 = x0, y0 = y0, x1 = p[1] + vx * t, y1 = p[2] + vy * t,
                cx = cx, cy = cy, a0 = math.atan2(y0 - cy, x0 - cx), sweep = cross < 0 and -turn or turn,
            }
        end
    end
    for i = 1, n do
        local w, prev = WAYPOINTS[i], WAYPOINTS[(i - 2) % n + 1]
        local arc = arcs[i]
        if arc.cx then
            local hoist = w.hoist or prev.hoist
            local count = math.max(2, math.floor(math.abs(arc.sweep) * CORNER / 5))
            for k = 0, count do
                local ang = arc.a0 + arc.sweep * k / count
                add(arc.cx + math.cos(ang) * CORNER, arc.cy + math.sin(ang) * CORNER, w, hoist)
            end
        else
            add(arc.x0, arc.y0, w, w.hoist)
        end
        -- the straight stretch to the next corner's arc
        local nextArc = arcs[i % n + 1]
        local dx, dy = nextArc.x0 - arc.x1, nextArc.y0 - arc.y1
        local count = math.max(1, math.floor(math.sqrt(dx * dx + dy * dy) / 5))
        for k = 1, count - 1 do add(arc.x1 + dx * k / count, arc.y1 + dy * k / count, w, w.hoist) end
    end
    return pts
end

-- resample a closed line at an even step: { x, y, s, tx, ty, nx, ny, layer, hoist }
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
            layer = a.layer, hoist = a.hoist }
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

-- ─── Marbles ───

-- a marble in a layer: its own category, every other track layer masked out
local function setLayer(m, layer)
    if m.layer == layer then return end
    local others = {}
    for name, category in pairs(TRACK_LAYERS) do
        if name ~= layer then others[#others + 1] = category end
    end
    m.fixture:setCategory(TRACK_LAYERS[layer])
    m.fixture:setMask(unpack(others))
    m.layer = layer
end

local function addMarble()
    local c = check()
    if #c.marbles >= MAX_MARBLES then return end
    local line = c.track.line
    -- at the start, behind any marble already there
    local i = 1
    for _, m in ipairs(c.marbles) do
        if alive(m.body) then
            local x, y = m.body:getPosition()
            local dx, dy = x - line[i].x, y - line[i].y
            if dx * dx + dy * dy < (MARBLE_R * 2.2) ^ 2 then i = (i - 6 - 1) % #line + 1 end
        end
    end
    local p = line[i]
    local body = love.physics.newBody(world, p.x, p.y, 'dynamic')
    local f = love.physics.newFixture(body, love.physics.newCircleShape(MARBLE_R), 1)
    f:setFriction(0.6)
    f:setRestitution(0.2)
    body:setBullet(true)
    local m = { body = body, fixture = f, index = i, still = 0, color = COLORS[(#c.marbles) % #COLORS + 1] }
    setLayer(m, p.layer)
    c.marbles[#c.marbles + 1] = m
end

local function removeMarbles()
    local c = check()
    for _, m in ipairs(c.marbles) do
        if alive(m.body) then m.body:destroy() end
    end
    c.marbles = {}
end

local function startOver()
    local c = check()
    removeMarbles()
    c.stats = { escapes = 0, topSpeed = 0, switches = 0 }
    for _ = 1, MARBLES do addMarble() end
end

local function updateMarble(c, m, dt, gy)
    local body = m.body
    local x, y = body:getPosition()
    local i, dist = nearest(c.track, x, y, m.index)
    m.index = i
    local p = c.track.line[i]
    m.s = p.s
    local vx, vy = body:getLinearVelocity()
    local speed = math.sqrt(vx * vx + vy * vy)
    if speed > c.stats.topSpeed then c.stats.topSpeed = speed end
    -- out of the pipe (tunnelled through a wall): counted, put back at the start
    if dist > HALF + MARBLE_R then
        c.stats.escapes = c.stats.escapes + 1
        print(('tracks: a marble got out at s=%d, %d px off the line, %d px/s'):format(p.s, dist, speed))
        local start = c.track.line[1]
        body:setPosition(start.x, start.y)
        body:setLinearVelocity(0, 0)
        m.index = 1
        setLayer(m, start.layer)
        return
    end
    -- the layer by arc position: the point's own layer changes at a transition's middle, where
    -- both layers' walls are; done here after the step, not in a contact callback (world locked)
    if p.layer ~= m.layer then
        setLayer(m, p.layer)
        c.stats.switches = c.stats.switches + 1
    end
    local vt = vx * p.tx + vy * p.ty
    local mass = body:getMass()
    if p.hoist then
        -- the hoist: cancel gravity along the pipe, then pull up to speed
        local a = -gy * p.ty + HOIST_GAIN * (HOIST_SPEED - vt)
        body:applyForce(p.tx * a * mass, p.ty * a * mass)
        m.still = 0
    elseif speed < 5 then
        m.still = m.still + dt
        if m.still > STILL_FOR then -- stuck on a flat: a push along
            body:applyLinearImpulse(p.tx * 200 * mass, p.ty * 200 * mass)
            m.still = 0
        end
    else
        m.still = 0
    end
end

-- ─── Drawing ───

local GLASS = { 0.75, 0.88, 0.95, 0.35 }
local GLASS_HOIST = { 0.95, 0.85, 0.6, 0.4 }
local RIM = { 0.35, 0.5, 0.6 }
local HAZE = { 0.1, 0.18, 0.12 } -- toward the background
local LIGHT_X, LIGHT_Y = -0.6, -0.8 -- toward the light

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
        local r, g, b, a = hazed(p.hoist and GLASS_HOIST or GLASS, p.depth)
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

-- one layer: its glass, the marbles in it, its rims and glint over them
local function drawLayer(c, layer)
    local look = layerLook(c.track, layer)
    if look.mesh then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(look.mesh)
    end
    for _, m in ipairs(c.marbles) do
        if alive(m.body) and m.layer == layer then
            drawMarble(m, c.track.line[m.index].depth)
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
    if state.playMode then -- in play the script draws the pipe and marbles itself
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

function s.onStart()
    worldState.paused = false
    local c = check()
    -- a track from before this script changed shape: built again
    if c.track and alive(c.track.body) and not c.track.layers then
        removeMarbles()
        c.track.body:destroy()
        c.track = nil
    end
    makeTrack()
    if #c.marbles == 0 then startOver() end
end

function s.onUnload()
    local c = state.tracksSpike
    if not c then return end
    removeMarbles()
    if c.track and alive(c.track.body) then c.track.body:destroy() end
    state.tracksSpike = nil
end

function s.update()
    local c = check()
    if not (c.track and alive(c.track.body)) then return end
    if worldState.paused then return end
    local dt = math.min(love.timer.getDelta(), 0.05)
    local _, gy = world:getGravity()
    for _, m in ipairs(c.marbles) do
        if alive(m.body) then updateMarble(c, m, dt, gy) end
    end
end

function s.onKeyPress(key)
    if key == 'm' then addMarble() end
    if key == 'r' then startOver() end
    if key == 'p' then worldState.paused = not worldState.paused end
end

return s

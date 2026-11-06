-- tracks: marbles rolling through a glass pipe, a knikkerbaan to watch (docs/TRACKS.md TR1)
-- The pipe is a closed loop: a centre line (pieces of lines and arcs, smoothed, resampled to an
-- even step: arc length, nearest point), its two walls as closed chains offset either side, in
-- track layer A's collision category. Marbles zigzag down by gravity; at the bottom a hoist
-- stretch (achtbaan's hoist flag, here a force along the pipe, not a set speed) pulls them up the
-- riser and over the top, like a buizenpost. No buttons: it runs on its own.
-- keys: m another marble   r start over   p pause

local s = {}

-- Track layers are collision categories (TRACKS.md): 2..6 reserved for them (16: hair tufts).
local TRACK_LAYERS = { A = 2, B = 3, C = 4, D = 5, E = 6 }

local MARBLE_R = 30
local HALF = 46           -- the pipe's inside half width: a marble has 16 px to spare a side
local STEP = 15           -- centre line sample spacing (px of arc length)
local SMOOTH = 4          -- smoothing passes over the centre line (rounds the line/arc joins)
local WALL = 8            -- drawn wall thickness
local MARBLES = 4         -- at the start
local MAX_MARBLES = 12
local HOIST_SPEED = 700   -- px a second up the riser
local HOIST_GAIN = 4      -- 1/s: how quickly it gets a marble to that speed
local STILL_FOR = 6       -- seconds stopped outside the hoist: nudged along the pipe

local COLORS = {
    { 0.85, 0.25, 0.2 }, { 0.2, 0.45, 0.85 }, { 0.95, 0.75, 0.2 }, { 0.25, 0.65, 0.35 },
    { 0.6, 0.35, 0.75 }, { 0.95, 0.5, 0.2 }, { 0.3, 0.75, 0.8 }, { 0.9, 0.45, 0.6 },
}

local function check() -- on state: a script hot reload keeps the marbles rolling
    state.tracksSpike = state.tracksSpike or { marbles = {}, stats = { escapes = 0, topSpeed = 0 } }
    return state.tracksSpike
end

local function alive(body) return body and not body:isDestroyed() end

-- ─── The track: pieces → centre line → walls ───

-- the course, in the direction of travel. y down. Runs zigzag down, U-turns of radius 200 (well
-- over HALF, or the inner wall folds), the bottom bend into the riser, the riser and the top bend
-- are the hoist.
local PIECES = {
    { 'line', -400, 0 },
    { 'line', 0, 0 },
    { 'line', 2000, 300 },
    { 'arc', 2000, 500, -math.pi / 2, math.pi / 2 },      -- centre, from angle, to angle
    { 'line', 300, 1000 },
    { 'arc', 300, 1200, -math.pi / 2, -3 * math.pi / 2 },
    { 'line', 2000, 1700 },
    { 'arc', 2000, 1900, -math.pi / 2, math.pi / 2 },
    { 'line', -400, 2400 },
    { 'arc', -400, 2200, math.pi / 2, math.pi, hoist = true },
    { 'line', -600, 200, hoist = true },
    { 'arc', -400, 200, math.pi, 3 * math.pi / 2, hoist = true },
}

-- the pieces as dense points, each with its piece's hoist flag
local function piecePoints()
    local pts = {}
    local function add(x, y, hoist) pts[#pts + 1] = { x = x, y = y, hoist = hoist } end
    for _, p in ipairs(PIECES) do
        if p[1] == 'line' then
            local last = pts[#pts]
            if last then -- the points between the last one and here
                local dx, dy = p[2] - last.x, p[3] - last.y
                local n = math.max(1, math.floor(math.sqrt(dx * dx + dy * dy) / 5))
                for i = 1, n do add(last.x + dx * i / n, last.y + dy * i / n, p.hoist) end
            else
                add(p[2], p[3], p.hoist)
            end
        else
            local cx, cy, a0, a1 = p[2], p[3], p[4], p[5]
            local r = 200
            local n = math.max(2, math.floor(math.abs(a1 - a0) * r / 5))
            for i = 1, n do
                local a = a0 + (a1 - a0) * i / n
                add(cx + math.cos(a) * r, cy + math.sin(a) * r, p.hoist)
            end
        end
    end
    return pts
end

-- Laplacian smoothing on a closed line (rounds the kinks where lines meet arcs)
local function smooth(pts, passes)
    local n = #pts
    for _ = 1, passes do
        local out = {}
        for i = 1, n do
            local a, b, c = pts[(i - 2) % n + 1], pts[i], pts[i % n + 1]
            out[i] = { x = (a.x + 2 * b.x + c.x) / 4, y = (a.y + 2 * b.y + c.y) / 4, hoist = b.hoist }
        end
        pts = out
    end
    return pts
end

-- resample a closed line at an even step: { x, y, s, tx, ty, nx, ny, hoist }
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
        out[#out + 1] = { x = a.x + (b.x - a.x) * t, y = a.y + (b.y - a.y) * t, s = d, hoist = a.hoist }
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

local function buildTrack()
    local line, length = resample(smooth(piecePoints(), SMOOTH), STEP)
    local left, right = {}, {}
    for _, p in ipairs(line) do
        left[#left + 1] = p.x - p.nx * HALF
        left[#left + 1] = p.y - p.ny * HALF
        right[#right + 1] = p.x + p.nx * HALF
        right[#right + 1] = p.y + p.ny * HALF
    end
    return { line = line, length = length, left = left, right = right, layer = 'A' }
end

local function makeTrack()
    local c = check()
    if c.track and alive(c.track.body) then return end
    local track = buildTrack()
    track.body = love.physics.newBody(world, 0, 0, 'static')
    for _, points in ipairs({ track.left, track.right }) do
        -- Box2D 2.3 chains collide on both sides: no winding to get right (TRACKS.md)
        local f = love.physics.newFixture(track.body, love.physics.newChainShape(true, points))
        f:setFriction(0.6)
        f:setCategory(TRACK_LAYERS[track.layer])
    end
    c.track = track
end

-- the nearest centre line point to (x, y): a search around the last one, all of it when lost
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

local function addMarble(at)
    local c = check()
    if #c.marbles >= MAX_MARBLES then return end
    local line = c.track.line
    -- at the start, behind any marble already there
    local i = at or 1
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
    f:setCategory(TRACK_LAYERS[c.track.layer])
    body:setBullet(true)
    c.marbles[#c.marbles + 1] = {
        body = body, index = i, still = 0,
        color = COLORS[(#c.marbles) % #COLORS + 1],
    }
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
    c.stats = { escapes = 0, topSpeed = 0 }
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
        body:setPosition(c.track.line[1].x, c.track.line[1].y)
        body:setLinearVelocity(0, 0)
        m.index = 1
        return
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
local LIGHT_X, LIGHT_Y = -0.6, -0.8 -- toward the light

-- the pipe's inside as a strip mesh, built once per track
local function pipeMesh(track)
    if track.mesh then return track.mesh end
    local verts = {}
    local line = track.line
    for i = 1, #line + 1 do
        local k = (i - 1) % #line + 1
        local p = line[k]
        local col = p.hoist and GLASS_HOIST or GLASS
        verts[#verts + 1] = { track.left[2 * k - 1], track.left[2 * k], 0, 0, col[1], col[2], col[3], col[4] }
        verts[#verts + 1] = { track.right[2 * k - 1], track.right[2 * k], 0, 0, col[1], col[2], col[3], col[4] }
    end
    track.mesh = love.graphics.newMesh(verts, 'strip', 'static')
    return track.mesh
end

local function drawPipeBack(track)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(pipeMesh(track))
end

local function drawPipeFront(track)
    -- the walls, and a highlight along the upper part of the glass
    love.graphics.setColor(RIM)
    love.graphics.setLineWidth(WALL)
    love.graphics.setLineJoin('bevel')
    love.graphics.polygon('line', track.left)
    love.graphics.polygon('line', track.right)
    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.setLineWidth(4)
    local hl = {}
    for _, p in ipairs(track.line) do
        -- toward the light (up-left), smoothly: through the middle where the pipe points at it
        local side = p.nx * LIGHT_X + p.ny * LIGHT_Y
        hl[#hl + 1] = p.x + p.nx * HALF * 0.6 * side
        hl[#hl + 1] = p.y + p.ny * HALF * 0.6 * side
    end
    love.graphics.polygon('line', hl)
end

local function drawMarble(m)
    local body = m.body
    local x, y = body:getPosition()
    local a = body:getAngle()
    local col = m.color
    love.graphics.setColor(col[1], col[2], col[3], 1)
    love.graphics.circle('fill', x, y, MARBLE_R)
    -- a swirl inside that turns with the marble (to see it roll)
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.setLineWidth(5)
    love.graphics.arc('line', 'open', x, y, MARBLE_R * 0.55, a, a + 2.2)
    love.graphics.setColor(col[1] * 0.5, col[2] * 0.5, col[3] * 0.5, 1)
    love.graphics.setLineWidth(3)
    love.graphics.circle('line', x, y, MARBLE_R)
    -- the glint stays up-left (the light)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.circle('fill', x - MARBLE_R * 0.35, y - MARBLE_R * 0.35, MARBLE_R * 0.18)
end

function s.drawBelow()
    local c = check()
    if state.playMode then -- in play the script draws the pipe and marbles itself
        c.savedDrawBodies = state.world.debugDrawBodies
        state.world.debugDrawBodies = false
    end
    if c.track and alive(c.track.body) then drawPipeBack(c.track) end
    love.graphics.setColor(1, 1, 1, 1)
end

function s.draw()
    local c = check()
    for _, m in ipairs(c.marbles) do
        if alive(m.body) then drawMarble(m) end
    end
    if c.track and alive(c.track.body) then drawPipeFront(c.track) end
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
    makeTrack()
    local c = check()
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

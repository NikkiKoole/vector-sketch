-- Festoon lights: a wire hung in swags between hooks, bulbs in a few colours hanging from it
-- (LIGHT-AND-SHADOW LS26, spiked in light-grass-check). The wire is a small verlet rope per swag
-- (not Box2D: nothing touches it), swaying in a soft wind. This module only moves and draws it;
-- each bulb's real light (a LIGHT sfixture) is the scene's: lib.bulbs gives where each one is.
-- The festoon's state is a plain table the caller keeps (on `state`, so a hot swap keeps it).
local lib = {}

local GRAVITY = 1400
local DAMPING = 0.985
local ITERATIONS = 10

-- hooks: { {x, y}, ... } (two or more); opts: segments (per swag), slack (1 = taut), bulbsPerSwag,
-- colours (hex strings, cycled), wind (sideways push)
function lib.new(hooks, opts)
    opts = opts or {}
    local segments = opts.segments or 12
    local slack = opts.slack or 1.08
    local perSwag = opts.bulbsPerSwag or 3
    local colours = opts.colours or { 'ff5a40', 'ffb52e', '62d46a', '4f8cff', 'ff7ac0' }
    local f = { swags = {}, bulbs = {}, wind = opts.wind or 120, t = 0 }
    for s = 1, #hooks - 1 do
        local a, b = hooks[s], hooks[s + 1]
        local dx, dy = b[1] - a[1], b[2] - a[2]
        local points = {}
        for i = 0, segments do
            local x, y = a[1] + dx * i / segments, a[2] + dy * i / segments
            points[#points + 1] = { x = x, y = y, px = x, py = y }
        end
        f.swags[s] = { points = points, rest = math.sqrt(dx * dx + dy * dy) / segments * slack }
        for k = 1, perSwag do
            local node = 1 + math.floor(segments * k / (perSwag + 1) + 0.5)
            f.bulbs[#f.bulbs + 1] = { swag = s, node = node, colour = colours[(#f.bulbs % #colours) + 1],
                x = 0, y = 0, angle = 0 }
        end
    end
    -- let it hang before anyone sees it
    for _ = 1, 180 do lib.step(f, 1 / 60) end
    return f
end

local function solve(sw)
    local p, rest = sw.points, sw.rest
    local last = #p
    for _ = 1, ITERATIONS do
        for i = 1, last - 1 do
            local a, b = p[i], p[i + 1]
            local dx, dy = b.x - a.x, b.y - a.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d > 0 then
                local diff = (d - rest) / d
                -- the ends are on their hooks: the other point takes the whole correction
                local wa = (i == 1) and 0 or ((i + 1 == last) and 1 or 0.5)
                local wb = (i + 1 == last) and 0 or ((i == 1) and 1 or 0.5)
                a.x, a.y = a.x + dx * diff * wa, a.y + dy * diff * wa
                b.x, b.y = b.x - dx * diff * wb, b.y - dy * diff * wb
            end
        end
    end
end

function lib.step(f, dt)
    dt = math.min(dt or 0, 1 / 30)
    if dt <= 0 then return end
    f.t = f.t + dt
    -- a soft, uneven wind: two slow waves
    local wind = (math.sin(f.t * 0.7) * 0.6 + math.sin(f.t * 1.9 + 1.3) * 0.4) * f.wind
    for _, sw in ipairs(f.swags) do
        local p = sw.points
        for i = 2, #p - 1 do
            local q = p[i]
            local vx, vy = (q.x - q.px) * DAMPING, (q.y - q.py) * DAMPING
            q.px, q.py = q.x, q.y
            -- the wind pushes the low middle of a swag more than near its hooks
            local along = math.sin((i - 1) / (#p - 1) * math.pi)
            q.x = q.x + vx + wind * along * dt * dt
            q.y = q.y + vy + GRAVITY * dt * dt
        end
        solve(sw)
    end
    -- each bulb hangs below its node, swinging a little with how the wire moves
    for _, bulb in ipairs(f.bulbs) do
        local q = f.swags[bulb.swag].points[bulb.node]
        local swing = math.max(-0.6, math.min(0.6, -(q.x - q.px) / math.max(dt, 1e-3) * 0.004))
        bulb.angle = bulb.angle + (swing - bulb.angle) * 0.2
        bulb.x = q.x - math.sin(bulb.angle) * 30
        bulb.y = q.y + math.cos(bulb.angle) * 30
    end
end

-- a disc whose alpha falls from 1 in the middle to 0 at its rim (radius 1)
local disc
local function glowDisc()
    if disc then return disc end
    local verts = { { 0, 0, 0.5, 0.5, 1, 1, 1, 1 } }
    for i = 0, 32 do
        local a = i / 32 * math.pi * 2
        verts[#verts + 1] = { math.cos(a), math.sin(a), 0.5, 0.5, 1, 1, 1, 0 }
    end
    disc = love.graphics.newMesh(verts, 'fan', 'static')
    return disc
end

local colourCache = {}
local function rgb(hex)
    local c = colourCache[hex]
    if not c then
        c = { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
        colourCache[hex] = c
    end
    return c
end
lib.rgb = rgb

-- the light each bulb throws on the wall behind it (added on: draw after the wall, before the things);
-- dark: 0 by day .. 1 at night
function lib.drawPools(f, dark)
    if dark <= 0.01 then return end
    love.graphics.setBlendMode('add')
    for _, bulb in ipairs(f.bulbs) do
        local c = rgb(bulb.colour)
        love.graphics.setColor(c[1], c[2], c[3], 0.16 * dark)
        love.graphics.draw(glowDisc(), bulb.x, bulb.y + 40, 0, 300, 260)
    end
    love.graphics.setBlendMode('alpha')
    love.graphics.setColor(1, 1, 1, 1)
end

-- the wire, the sockets and the bulbs; lit: 0 (off, coloured glass) .. 1 (glowing)
function lib.draw(f, lit)
    love.graphics.setColor(0.1, 0.08, 0.07, 1)
    love.graphics.setLineWidth(5)
    love.graphics.setLineJoin('bevel')
    for _, sw in ipairs(f.swags) do
        local line = {}
        for _, q in ipairs(sw.points) do
            line[#line + 1] = q.x
            line[#line + 1] = q.y
        end
        love.graphics.line(line)
    end
    love.graphics.setLineWidth(1)
    for _, bulb in ipairs(f.bulbs) do
        local q = f.swags[bulb.swag].points[bulb.node]
        local c = rgb(bulb.colour)
        love.graphics.push()
        love.graphics.translate(q.x, q.y)
        love.graphics.rotate(bulb.angle)
        -- the socket
        love.graphics.setColor(0.12, 0.1, 0.09, 1)
        love.graphics.rectangle('fill', -9, 0, 18, 16, 3)
        -- the bulb: coloured glass, towards white in its middle when it glows
        local k = 0.55 + 0.45 * lit
        love.graphics.setColor(c[1] * k, c[2] * k, c[3] * k, 1)
        love.graphics.ellipse('fill', 0, 32, 15, 19)
        love.graphics.setColor(1, 1, 1, 0.25 + 0.6 * lit)
        love.graphics.ellipse('fill', 0, 34, 6 + 2 * lit, 9 + 3 * lit)
        love.graphics.pop()
    end
    -- the glow round each bulb
    if lit > 0.01 then
        love.graphics.setBlendMode('add')
        for _, bulb in ipairs(f.bulbs) do
            local c = rgb(bulb.colour)
            love.graphics.setColor(c[1], c[2], c[3], 0.5 * lit)
            love.graphics.draw(glowDisc(), bulb.x, bulb.y, 0, 75, 75)
        end
        love.graphics.setBlendMode('alpha')
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return lib

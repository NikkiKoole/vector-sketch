-- Hair locks: long hair that swings (a spike, scripts/hair.playtime.lua; parked, docs/HAIR-LOCKS.md).
-- A lock is a chain of points rooted on the head's outline, moved by a small verlet step of its
-- own (not Box2D: hair can't snag, weigh a Mipo down or upset the solver), and drawn as a ribbon
-- along the chain with a hair picture (src/render/ribbon.lua). Each step: the root follows the
-- head; the other points keep their momentum (damped) and fall; each is pulled toward its rest
-- shape (straight out of the head, curled by `curl`) by `stiffness`, stiffer at the root; then
-- held at its length from the point before it, and kept out of the head (an oval its size), so
-- hanging hair drapes over the head and falls past its sides. Low stiffness hangs, high sticks
-- out and wobbles. Two layers: the back (behind the Mipo) and the front (over its face): bangs,
-- short locks along the top that hang inward over the forehead, and the outermost long locks.
local lib = {}

local state = require('src.state')
local utils = require('src.utils')
local ribbon = require('src.render.ribbon')
local color = require('src.color')

lib.defaults = {
    count = 12,      -- locks
    points = 10,     -- points per lock (longer hair: more points)
    segment = 24,    -- px between points
    stiffness = 0.1, -- 0 hangs .. 1 keeps its rest shape; it fades out toward the tip, so tips hang
    droop = 0.6,     -- radians each lock leans from straight out toward its own side, so none balances on top
    curl = 0.1,      -- radians a segment bends from the one before (wild: big and mixed)
    wild = 0.5,      -- 0 every lock alike .. 1 each its own length, curl and width
    damping = 0.96,  -- of the velocity each step (1 = never settles)
    width = 0.2,     -- ribbon half-width as a share of the picture's width
    spread = 1.9,    -- radians of the head's outline the roots cover, around the top
    texture = 7,     -- hairN.png (and hairN-mask.png when there is one)
    frontLocks = 2,  -- the outermost long locks drawn in front, framing the face
    bangs = 5,       -- short locks over the forehead
    bangPoints = 3,
    bangSegment = 18,
    bangSpread = 1.2, -- radians of the top the bangs cover
}

local images = {}
local function image(path)
    if images[path] == nil then
        local ok, img = pcall(love.graphics.newImage, path)
        images[path] = ok and img or false
    end
    return images[path] or nil
end

-- Where a ray from the body's origin at `angle` leaves the polygon `vertices` (flat, local).
local function outlinePoint(vertices, angle)
    local dx, dy = math.cos(angle), math.sin(angle)
    local best = nil
    local n = #vertices / 2
    for i = 1, n do
        local ax, ay = vertices[2 * i - 1], vertices[2 * i]
        local j = i % n + 1
        local bx, by = vertices[2 * j - 1], vertices[2 * j]
        local ex, ey = bx - ax, by - ay
        local denom = dx * ey - dy * ex
        if math.abs(denom) > 1e-9 then
            local t = (ax * ey - ay * ex) / denom -- along the ray
            local u = (ax * dy - ay * dx) / denom -- along the edge
            if t > 0 and u >= 0 and u <= 1 and (not best or t < best) then best = t end
        end
    end
    best = best or 50
    return dx * best, dy * best
end

local function headOf(instance)
    local part = instance.parts and (instance.parts.head or instance.parts.torso1)
    return part and part.body
end

-- Give `instance` locks (opts over lib.defaults); again to change them.
function lib.attach(instance, opts)
    local o = {}
    for k, v in pairs(lib.defaults) do o[k] = (opts and opts[k] ~= nil) and opts[k] or v end
    local body = headOf(instance)
    if not body or body:isDestroyed() then return end
    local thing = utils.thingOf(body)
    local vertices = thing and thing.vertices
    if not vertices or #vertices < 6 then return end
    local rng = love.math.newRandomGenerator(o.seed or 1)
    local locks = {}
    for k = 1, o.count do
        local f = o.count > 1 and (k - 1) / (o.count - 1) or 0.5
        local angle = -math.pi / 2 + (f - 0.5) * o.spread
        local rx, ry = outlinePoint(vertices, angle)
        local w = o.wild
        local lock = {
            rx = rx * 0.85, ry = ry * 0.85, -- a little inside, under the head
            -- leaning toward its side (the middle one too, by turns): falls instead of balancing on top
            restAngle = angle + ((f < 0.5 or (f == 0.5 and k % 2 == 0)) and -o.droop or o.droop),
            n = o.points, drape = true,
            front = k <= o.frontLocks / 2 or k > o.count - o.frontLocks / 2,
            segment = o.segment * (1 + w * (rng:random() - 0.5) * 0.8),
            curl = o.curl * (1 - w + w * (rng:random() * 2 - 1) * 2),
            width = o.width * (1 + w * (rng:random() - 0.5) * 0.6),
            points = {}, prev = {},
        }
        locks[k] = lock
    end
    for k = 1, o.bangs do
        local f = o.bangs > 1 and (k - 1) / (o.bangs - 1) or 0.5
        local angle = -math.pi / 2 + (f - 0.5) * o.bangSpread
        local rx, ry = outlinePoint(vertices, angle)
        local w = o.wild
        locks[#locks + 1] = {
            rx = rx * 0.95, ry = ry * 0.95,
            restAngle = angle + math.pi, n = o.bangPoints, drape = false, front = true, -- inward, over the face
            segment = o.bangSegment * (1 + w * (rng:random() - 0.5) * 0.6),
            curl = o.curl * 0.5 * (1 - w + w * (rng:random() * 2 - 1) * 2),
            width = o.width * (1 + w * (rng:random() - 0.5) * 0.6),
            points = {}, prev = {},
        }
    end
    -- the head as an oval (body space) for the locks to drape over
    local ex, ey = 1, 1
    for i = 1, #vertices, 2 do
        ex, ey = math.max(ex, math.abs(vertices[i])), math.max(ey, math.abs(vertices[i + 1]))
    end
    instance.hairLocks = { opts = o, locks = locks, body = body, ovalX = ex * 0.9, ovalY = ey * 0.9 }
    lib.reset(instance)
end

-- Lay every lock straight out of the head (after a teleport, or new locks).
function lib.reset(instance)
    local h = instance.hairLocks
    if not h then return end
    local body = h.body
    local a = body:getAngle()
    for _, lock in ipairs(h.locks) do
        local x, y = body:getWorldPoint(lock.rx, lock.ry)
        local dx, dy = math.cos(lock.restAngle + a), math.sin(lock.restAngle + a)
        for i = 1, lock.n do
            local px, py = x + dx * lock.segment * (i - 1), y + dy * lock.segment * (i - 1)
            lock.points[2 * i - 1], lock.points[2 * i] = px, py
            lock.prev[2 * i - 1], lock.prev[2 * i] = px, py
        end
        for i = 2 * lock.n + 1, #lock.points do lock.points[i], lock.prev[i] = nil, nil end
    end
end

local function stepLock(lock, o, body, gx, gy, dt, ovalX, ovalY)
    local p, q = lock.points, lock.prev
    local n = lock.n
    local a = body:getAngle()
    local rootX, rootY = body:getWorldPoint(lock.rx, lock.ry)
    p[1], p[2], q[1], q[2] = rootX, rootY, rootX, rootY
    local ddx, ddy = gx * dt * dt, gy * dt * dt
    for i = 2, n do
        local ix, iy = 2 * i - 1, 2 * i
        local x, y = p[ix], p[iy]
        p[ix] = x + (x - q[ix]) * o.damping + ddx
        p[iy] = y + (y - q[iy]) * o.damping + ddy
        q[ix], q[iy] = x, y
    end
    -- rest shape and length, root outward
    local dirX, dirY = math.cos(lock.restAngle + a), math.sin(lock.restAngle + a)
    local c, s = math.cos(lock.curl), math.sin(lock.curl)
    local L = lock.segment
    for i = 2, n do
        local ix, iy = 2 * i - 1, 2 * i
        local px, py = p[ix - 2], p[iy - 2]
        if i > 2 then
            local ex, ey = px - p[ix - 4], py - p[iy - 4]
            local len = math.sqrt(ex * ex + ey * ey)
            if len > 1e-6 then dirX, dirY = ex / len, ey / len end
            dirX, dirY = dirX * c - dirY * s, dirX * s + dirY * c
        end
        -- pulled toward the rest shape at the root, not at all at the tip (falls); applied every
        -- step (120 a second), so a tenth of the slider is plenty
        local fade = 1 - (i - 2) / math.max(1, n - 1)
        local k = o.stiffness * 0.1 * fade * fade
        local tx, ty = px + dirX * L, py + dirY * L
        local x, y = p[ix] + (tx - p[ix]) * k, p[iy] + (ty - p[iy]) * k
        local ex, ey = x - px, y - py
        local len = math.sqrt(ex * ex + ey * ey)
        if len > 1e-6 then x, y = px + ex / len * L, py + ey / len * L end
        if i > 2 and ovalX and lock.drape then -- out of the head
            local lx, ly = body:getLocalPoint(x, y)
            local d = (lx / ovalX) ^ 2 + (ly / ovalY) ^ 2
            if d < 1 then
                local f = 1 / math.sqrt(math.max(d, 1e-6))
                x, y = body:getWorldPoint(lx * f, ly * f)
            end
        end
        p[ix], p[iy] = x, y
    end
end

function lib.update(dt)
    local gx, gy = state.physicsWorld:getGravity()
    local steps = math.max(1, math.ceil(dt * 120 - 0.01))
    local h = dt / steps
    for _, instance in pairs(state.mipoInstances) do
        local hair = instance.hairLocks
        if hair then
            if hair.body:isDestroyed() then
                instance.hairLocks = nil
            elseif not hair.ovalX or (hair.locks[1] and not hair.locks[1].n) then
                lib.attach(instance, hair.opts) -- made by an older version of this file (hot reload)
            else
                for _ = 1, steps do
                    for _, lock in ipairs(hair.locks) do
                        stepLock(lock, hair.opts, hair.body, gx, gy, h, hair.ovalX, hair.ovalY)
                    end
                end
            end
        end
    end
end

-- The locks of every Mipo that has them, in the colours of its haircut: layer 'back' (behind the
-- Mipos) or 'front' (over their faces).
function lib.draw(layer)
    local wantFront = layer == 'front'
    for _, instance in pairs(state.mipoInstances) do
        local hair = instance.hairLocks
        if hair and not hair.body:isDestroyed() then
            local o = hair.opts
            local line = image('textures/hair' .. o.texture .. '.png')
            local mask = image('textures/hair' .. o.texture .. '-mask.png')
            local cut = instance.dna and instance.dna.parts and instance.dna.parts.head
                and instance.dna.parts.head.appearance and instance.dna.parts.head.appearance.haircut
            local main = cut and cut.main or {}
            local fr, fg, fb = color.hexToColor(main.fgHex or 'bf1a2dff')
            local lr, lg, lb = color.hexToColor(main.bgHex or '000000ff')
            for _, lock in ipairs(hair.locks) do
                if (lock.front or false) == wantFront then
                    if mask then
                        love.graphics.setColor(fr, fg, fb, 1)
                        love.graphics.draw(ribbon.ownStrip(lock, 'fill', mask, lock.width, lock.points, 1, 0,
                            nil, true))
                    end
                    if line then
                        love.graphics.setColor(lr, lg, lb, 1)
                        love.graphics.draw(ribbon.ownStrip(lock, 'line', line, lock.width, lock.points, 1, 0,
                            nil, true))
                    end
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return lib

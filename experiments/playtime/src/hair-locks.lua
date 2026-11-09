-- Hair locks: long hair that swings (a spike, scripts/spikes/hair.playtime.lua; parked, docs/HAIR-LOCKS.md).
-- A lock is a chain of points rooted on the head's outline, moved by a small verlet step of its
-- own (not Box2D: hair can't snag, weigh a Mipo down or upset the solver), and drawn as a strip
-- of its own through the chain's points with a hair picture, around it a corkscrew for ringlets
-- (pijpenkrullen: the chain is the ringlet's axis, a spring). Each step: the root follows the
-- head; the other points keep their momentum (damped) and fall; each is pulled toward its rest
-- shape (straight out of the head, curled by `curl`) by `stiffness`, stiffer at the root; then
-- held at its length from the point before it, and kept out of the head (an oval its size), so
-- hanging hair drapes over the head and falls past its sides. Low stiffness hangs, high sticks
-- out and wobbles. Two layers: the back (behind the Mipo) and the front (over its face): bangs,
-- short locks along the top that hang inward over the forehead, and the outermost long locks.
local lib = {}

-- Each point is pulled to its length behind the one before it ("follow the leader"); that pull
-- counts as speed, piles up along the lock and the tips whip like an angry octopus. DFTL (Mueller,
-- "Fast Simulation of Inextensible Hair and Fur", 2012) gives part of each pull back to the point
-- before: 0 whips, 1 can still thrash at high curl; 0.5 swings and settles (2026-11-09).
local DFTL = 0.5

local state = require('src.state')
local utils = require('src.utils')
local color = require('src.color')
local textureNames = require('src.texture-names')

lib.defaults = {
    count = 17,      -- locks
    points = 16,     -- points per lock (longer hair: more points)
    segment = 24,    -- px between points
    stiffness = 0.1, -- 0 hangs .. 1 keeps its rest shape; it fades out toward the tip, so tips hang
    droop = 0.6,     -- radians each lock leans from straight out toward its own side, so none balances on top
    curl = 0.1,      -- radians a segment bends from the one before (wild: big and mixed)
    wild = 0.5,      -- 0 every lock alike .. 1 each its own length, curl and width
    damping = 0.96,  -- of the velocity each step (1 = never settles)
    stand = 0,       -- 0 hangs .. 1 stands up: the rest shape holds all along the lock, less gravity and droop
    curly = 0,       -- 0 straight .. 1 curls: a wave along each lock, held tip to root
    cut = 0,         -- the haircut: px below the head's centre where the long locks end (a blunt line); 0 = by points
    lenMiddle = 1,   -- length of the middle locks, times ..
    lenSides = 1,    -- .. and of the outer ones; blended in between (short middle + long sides, or the other way)
    part = 0,        -- where the hair parts: -1 far left .. 0 the middle .. 1 far right
    ringlets = 0,      -- pijpenkrullen: the corkscrew's radius, px (0 = none)
    ringletPitch = 30, -- px of lock per turn; below ~3x the radius the turns show as loops
    springy = 0,       -- 0 keeps its length .. 1 stretches and bounces back like a spring (ringlets do)
    weight = 3,      -- gravity on the hair, times the world's: at 1 the stiffness held the locks out like a fountain
    width = 0.06,    -- ribbon half-width as a share of the picture's width
    spread = 1.9,    -- radians of the head's outline the roots cover, around the top
    texture = 7,     -- mipo/hair/hair-NN.png (and its -mask when there is one)
    frontLocks = 2,  -- the outermost long locks drawn in front, framing the face
    bangs = 10,      -- short locks over the forehead
    bangPoints = 3,
    bangSegment = 20.5,
    bangSpread = 2.57, -- radians of the top the bangs cover
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
    -- the head as an oval (body space) for the locks to drape over
    local ovalX, ovalY = 1, 1
    for i = 1, #vertices, 2 do
        ovalX, ovalY = math.max(ovalX, math.abs(vertices[i])), math.max(ovalY, math.abs(vertices[i + 1]))
    end
    ovalX, ovalY = ovalX * 0.9, ovalY * 0.9
    local partF = (o.part + 1) / 2
    local locks = {}
    for k = 1, o.count do
        local f = o.count > 1 and (k - 1) / (o.count - 1) or 0.5
        local angle = -math.pi / 2 + (f - 0.5) * o.spread
        local rx, ry = outlinePoint(vertices, angle)
        local w = o.wild
        local lock = {
            rx = rx * 0.85, ry = ry * 0.85, -- a little inside, under the head
            -- leaning toward its side (the middle one too, by turns): falls instead of balancing on top
            restAngle = angle + ((f < partF or (f == partF and k % 2 == 0)) and -1 or 1) * o.droop * (1 - o.stand),
            n = o.points, drape = true,
            front = k <= o.frontLocks / 2 or k > o.count - o.frontLocks / 2,
            segment = o.segment * (1 + w * (rng:random() - 0.5) * 0.8),
            curl = o.curl * (1 - w + w * (rng:random() * 2 - 1) * 2),
            width = o.width * (1 + w * (rng:random() - 0.5) * 0.6),
            points = {}, prev = {},
        }
        -- its length: down to the cut line (over the head to its side, then straight down), or by
        -- points; then the middle / sides profile
        local len = (o.points - 1) * o.segment
        if o.cut > 0 then
            local sideX = rx < 0 and -ovalX or ovalX
            len = math.sqrt((rx - sideX) ^ 2 + ry ^ 2) + o.cut
        end
        local t = math.min(1, math.abs(f - 0.5) * 2)
        len = len * (o.lenMiddle + (o.lenSides - o.lenMiddle) * t)
        lock.n = math.max(2, math.min(40, math.floor(len / lock.segment + 0.5) + 1))
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
    -- each lock's bend per segment at rest: the curl, plus the curly wave (its own phase per lock)
    for _, lock in ipairs(locks) do
        local phase, amp = rng:random() * 2 * math.pi, o.curly * (lock.drape and 1.1 or 0.5)
        lock.phase = phase
        lock.bends = {}
        for i = 3, lock.n do lock.bends[i] = lock.curl + amp * math.sin((i - 2) * 0.9 + phase) end
    end
    instance.hairLocks = { opts = o, locks = locks, body = body, ovalX = ovalX, ovalY = ovalY }
    lib.reset(instance)
end

-- Lay every lock out of the head in its rest shape (after a teleport, or new locks).
function lib.reset(instance)
    local h = instance.hairLocks
    if not h then return end
    local body = h.body
    local a = body:getAngle()
    for _, lock in ipairs(h.locks) do
        local x, y = body:getWorldPoint(lock.rx, lock.ry)
        local dir = lock.restAngle + a
        for i = 1, lock.n do
            if i > 2 then dir = dir + lock.bends[i] end
            if i > 1 then x, y = x + math.cos(dir) * lock.segment, y + math.sin(dir) * lock.segment end
            lock.points[2 * i - 1], lock.points[2 * i] = x, y
            lock.prev[2 * i - 1], lock.prev[2 * i] = x, y
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
    -- curly: points two apart held at their rest distance (2 L cos(bend / 2)), pushed or pulled
    -- both ways (a one-sided pull is what made the octopus), so the wave holds out to the tip
    local kc = o.curly * 0.5
    if kc > 0 then
        local L2 = lock.segment * 2
        for i = 3, n do
            local ax, ay, cx, cy = 2 * i - 5, 2 * i - 4, 2 * i - 1, 2 * i
            local ex, ey = p[cx] - p[ax], p[cy] - p[ay]
            local len = math.sqrt(ex * ex + ey * ey)
            if len > 1e-6 then
                local corr = (len - L2 * math.cos(lock.bends[i] / 2)) / len * kc
                if i == 3 then -- the root stays put
                    p[cx], p[cy] = p[cx] - ex * corr, p[cy] - ey * corr
                else
                    p[ax], p[ay] = p[ax] + ex * corr * 0.5, p[ay] + ey * corr * 0.5
                    p[cx], p[cy] = p[cx] - ex * corr * 0.5, p[cy] - ey * corr * 0.5
                end
            end
        end
    end
    -- rest shape and length, root outward
    local dirX, dirY = math.cos(lock.restAngle + a), math.sin(lock.restAngle + a)
    local L = lock.segment
    for i = 2, n do
        local ix, iy = 2 * i - 1, 2 * i
        local px, py = p[ix - 2], p[iy - 2]
        -- the rest shape is fixed in the head's frame: each segment `curl` more than the last rest
        -- segment, not than the chain's current one (that one-sided pull wound the locks round
        -- and round instead of letting them hang, 2026-11-09)
        if i > 2 then
            local c, s = math.cos(lock.bends[i]), math.sin(lock.bends[i])
            dirX, dirY = dirX * c - dirY * s, dirX * s + dirY * c
        end
        -- pulled toward the rest shape at the root, not at all at the tip (falls); applied every
        -- step (120 a second), so a tenth of the slider is plenty
        -- (stand keeps it all along the lock)
        local fade = 1 - (1 - o.stand) * (i - 2) / math.max(1, n - 1)
        local k = math.max(o.stiffness, o.stand) * 0.1 * fade * fade
        local tx, ty = px + dirX * L, py + dirY * L
        local x, y = p[ix] + (tx - p[ix]) * k, p[iy] + (ty - p[iy]) * k
        local ex, ey = x - px, y - py
        local len = math.sqrt(ex * ex + ey * ey)
        if len > 1e-6 then
            -- springy: only part of the way back to its length each step (between 0.9 and 1.8 L)
            local want = L
            if o.springy > 0 then
                want = len + (L - len) * (1 - o.springy * 0.85)
                want = math.max(L * 0.9, math.min(L * 1.8, want))
            end
            x, y = px + ex / len * want, py + ey / len * want
        end
        if i > 2 and ovalX and lock.drape then -- out of the head
            local lx, ly = body:getLocalPoint(x, y)
            local d = (lx / ovalX) ^ 2 + (ly / ovalY) ^ 2
            if d < 1 then
                local f = 1 / math.sqrt(math.max(d, 1e-6))
                x, y = body:getWorldPoint(lx * f, ly * f)
            end
        end
        if i > 2 then -- DFTL (Mueller 2012): the parent gives back the pull it made, else tips whip
            q[ix - 2] = q[ix - 2] + (x - p[ix]) * DFTL
            q[iy - 2] = q[iy - 2] + (y - p[iy]) * DFTL
        end
        p[ix], p[iy] = x, y
    end
end

function lib.update(dt)
    local gx, gy = state.physicsWorld:getGravity()
    -- fixed steps: verlet carries velocity as the last step's move, so a step that changes size
    -- with the frame time flings points (80-120 px a step with uneven frames, 2026-11-09)
    local h = 1 / 120
    for _, instance in pairs(state.mipoInstances) do
        local hair = instance.hairLocks
        if hair then
            if hair.body:isDestroyed() then
                instance.hairLocks = nil
            elseif not hair.ovalX or (hair.locks[1] and not hair.locks[1].bends) then
                lib.attach(instance, hair.opts) -- made by an older version of this file (hot reload)
            else
                local w = hair.opts.weight * (1 - hair.opts.stand)
                hair.acc = math.min((hair.acc or 0) + dt, 0.1)
                while hair.acc >= h do
                    hair.acc = hair.acc - h
                    for _, lock in ipairs(hair.locks) do
                        stepLock(lock, hair.opts, hair.body, gx * w, gy * w, h, hair.ovalX, hair.ovalY)
                    end
                end
            end
        end
    end
end

-- The drawn path of a lock: a Catmull-Rom curve through its points (passes through them, so a
-- curl shows; one Bezier over them all smoothed it away), and for ringlets a corkscrew around
-- it, seen from the side and a little from above so the turns loop. The turns follow the lock's
-- rest length, so a stretched ringlet opens up like a spring. Fills `out` with x, y, shade.
local TILT = 0.5   -- how much of the turn is seen from above (its loops)
local MAXSAMPLES = 400
local function lockPath(lock, o, out)
    local p, n, L = lock.points, lock.n, lock.segment
    local R, pitch = o.ringlets, math.max(4, o.ringletPitch)
    local per = R > 0 and math.max(4, math.ceil(L / pitch * 12)) or 4
    per = math.max(1, math.min(per, math.floor((MAXSAMPLES - 1) / math.max(1, n - 1))))
    local count = 0
    local function at(i) -- with the ends mirrored
        if i < 1 then return 2 * p[1] - p[3], 2 * p[2] - p[4] end
        if i > n then return 2 * p[2 * n - 1] - p[2 * n - 3], 2 * p[2 * n] - p[2 * n - 2] end
        return p[2 * i - 1], p[2 * i]
    end
    for j = 1, n - 1 do
        local x0, y0 = at(j - 1)
        local x1, y1 = at(j)
        local x2, y2 = at(j + 1)
        local x3, y3 = at(j + 2)
        for s = 0, (j == n - 1) and per or per - 1 do
            local t = s / per
            local t2, t3 = t * t, t * t * t
            local x = 0.5 * (2 * x1 + (x2 - x0) * t + (2 * x0 - 5 * x1 + 4 * x2 - x3) * t2
                + (3 * x1 - x0 - 3 * x2 + x3) * t3)
            local y = 0.5 * (2 * y1 + (y2 - y0) * t + (2 * y0 - 5 * y1 + 4 * y2 - y3) * t2
                + (3 * y1 - y0 - 3 * y2 + y3) * t3)
            count = count + 1
            out[3 * count - 2], out[3 * count - 1], out[3 * count] = x, y, (j - 1 + t) * L
        end
    end
    -- the corkscrew: around the axis, growing in over the first turn
    for c = 1, count do
        local x, y, s = out[3 * c - 2], out[3 * c - 1], out[3 * c]
        local shade = 1
        if R > 0 then
            local a, b = math.max(1, c - 1), math.min(count, c + 1)
            local tx, ty = out[3 * b - 2] - out[3 * a - 2], out[3 * b - 1] - out[3 * a - 1]
            local tl = math.sqrt(tx * tx + ty * ty)
            if tl > 1e-6 then tx, ty = tx / tl, ty / tl else tx, ty = 0, 1 end
            local r = R * math.min(1, s / pitch)
            local th = s / pitch * 2 * math.pi + (lock.phase or 0)
            local sn, cs = math.sin(th), math.cos(th)
            x, y = x - ty * r * sn + tx * r * TILT * cs, y + tx * r * sn + ty * r * TILT * cs
            shade = 0.72 + 0.28 * (0.5 + 0.5 * cs) -- the back of each turn darker
        end
        out[3 * c - 2], out[3 * c - 1], out[3 * c] = x, y, shade
    end
    return count
end

local pathBuf = {}
local MESH_FORMAT = {
    { 'VertexPosition', 'float', 2 }, { 'VertexTexCoord', 'float', 2 }, { 'VertexColor', 'byte', 4 },
}
-- A textured strip along the path, the picture's width across (times `width`), its length along.
local function stripMesh(lock, slot, img, count)
    lock.meshes = lock.meshes or {}
    local m = lock.meshes[slot]
    if not m or m.img ~= img then
        m = { mesh = love.graphics.newMesh(MESH_FORMAT, MAXSAMPLES * 2, 'strip', 'stream'), img = img, verts = {} }
        m.mesh:setTexture(img)
        lock.meshes[slot] = m
    end
    local hw = img:getWidth() * lock.width
    local v, buf = m.verts, pathBuf
    for c = 1, count do
        local a, b = math.max(1, c - 1), math.min(count, c + 1)
        local tx, ty = buf[3 * b - 2] - buf[3 * a - 2], buf[3 * b - 1] - buf[3 * a - 1]
        local tl = math.sqrt(tx * tx + ty * ty)
        if tl > 1e-6 then tx, ty = tx / tl, ty / tl else tx, ty = 0, 1 end
        local x, y, sh = buf[3 * c - 2], buf[3 * c - 1], buf[3 * c]
        local tv = (c - 1) / math.max(1, count - 1)
        local l, r = v[2 * c - 1] or {}, v[2 * c] or {}
        l[1], l[2], l[3], l[4], l[5], l[6], l[7], l[8] = x - ty * hw, y + tx * hw, 0, tv, sh, sh, sh, 1
        r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8] = x + ty * hw, y - tx * hw, 1, tv, sh, sh, sh, 1
        v[2 * c - 1], v[2 * c] = l, r
    end
    for i = 2 * count + 1, #v do v[i] = nil end
    m.mesh:setVertices(v)
    m.mesh:setDrawRange(1, 2 * count)
    return m.mesh
end

-- The locks of every Mipo that has them, in the colours of its haircut: layer 'back' (behind the
-- Mipos) or 'front' (over their faces).
function lib.draw(layer)
    local wantFront = layer == 'front'
    for _, instance in pairs(state.mipoInstances) do
        local hair = instance.hairLocks
        if hair and not hair.body:isDestroyed() then
            local o = hair.opts
            local line = image('textures/' .. textureNames.part('hair', o.texture) .. '.png')
            local mask = image('textures/' .. textureNames.part('hair', o.texture) .. '-mask.png')
            local cut = instance.dna and instance.dna.parts and instance.dna.parts.head
                and instance.dna.parts.head.appearance and instance.dna.parts.head.appearance.haircut
            local main = cut and cut.main or {}
            local fr, fg, fb = color.hexToColor(main.fgHex or 'bf1a2dff')
            local lr, lg, lb = color.hexToColor(main.bgHex or '000000ff')
            for _, lock in ipairs(hair.locks) do
                if (lock.front or false) == wantFront then
                    local count = lockPath(lock, o, pathBuf)
                    if count >= 2 then
                        if mask then
                            love.graphics.setColor(fr, fg, fb, 1)
                            love.graphics.draw(stripMesh(lock, 'fill', mask, count))
                        end
                        if line then
                            love.graphics.setColor(lr, lg, lb, 1)
                            love.graphics.draw(stripMesh(lock, 'line', line, count))
                        end
                    end
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return lib

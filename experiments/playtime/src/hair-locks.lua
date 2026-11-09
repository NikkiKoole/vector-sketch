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

lib.useNative = true -- the strips from native/desound/hair.c when the library has it

-- Each point is pulled to its length behind the one before it ("follow the leader"); that pull
-- counts as speed, piles up along the lock and the tips whip like an angry octopus. DFTL (Mueller,
-- "Fast Simulation of Inextensible Hair and Fur", 2012) gives part of each pull back to the point
-- before: 0 whips, 1 can still thrash at high curl; 0.5 swings and settles (2026-11-09).
local DFTL = 0.5

local state = require('src.state')
local utils = require('src.utils')
local color = require('src.color')
local textureNames = require('src.texture-names')
local hairNative = require('src.hair-native')
local spineSkin = require('src.spine-skin')

lib.defaults = {
    count = 11,      -- locks
    points = 16,     -- points per lock (longer hair: more points)
    segment = 21.2,  -- px between points
    stiffness = 0.1, -- 0 hangs .. 1 keeps its rest shape; it fades out toward the tip, so tips hang
    droop = 0.6,     -- radians each lock leans from straight out toward its own side, so none balances on top
    curl = 0.1,      -- radians a segment bends from the one before (wild: big and mixed)
    wild = 0.5,      -- 0 every lock alike .. 1 each its own length, curl and width
    damping = 0.96,  -- of the velocity each step (1 = never settles)
    stand = 0,       -- 0 hangs .. 1 stands up: the rest shape holds all along the lock, less gravity and droop
    curly = 0,       -- 0 straight .. 1 curls: a wave drawn along each lock (16 px at 1, a wave every 5 segments)
    cut = 0,         -- the haircut: px below the head's centre where the long locks end (a blunt line); 0 = by points
    lenMiddle = 1,   -- length of the middle locks, times ..
    lenSides = 1,    -- .. and of the outer ones; blended in between (short middle + long sides, or the other way)
    part = 0,        -- where the hair parts: -1 far left .. 0 the middle .. 1 far right
    ringlets = 0,      -- pijpenkrullen: the corkscrew's radius, px (0 = none)
    ringletPitch = 30, -- px of lock per turn; below ~3x the radius the turns show as loops
    springy = 0,       -- 0 keeps its length .. 1 stretches and bounces back like a spring (ringlets do)
    surface = 0,       -- a coat: this many short locks rooted over the body (chest hair), off the face
    surfaceLength = 22, -- px, root to tip
    surfaceWidth = 0.35, -- times `width`: thin, or the picture squashes into a square
    surfaceCurly = 0,  -- 0 straight .. 1 the coat in small coils (5 px across, a turn every 9 px)
    weight = 3,      -- gravity on the hair, times the world's: at 1 the stiffness held the locks out like a fountain
    width = 0.28,    -- ribbon half-width as a share of the picture's width
    inset = 0.85,    -- the long locks' roots this share of the way out to the outline (fur: almost on it)
    spread = 1.9,    -- radians of the head's outline the roots cover, around the top
    texture = 3,     -- mipo/hair/hair-NN.png (and its -mask when there is one)
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

local WAVE_AMP = 16  -- px: the curly wave's height at curly 1 (bangs half)
local COAT_RING, COAT_PITCH = 5, 9 -- px: a coat's coils at surfaceCurly 1 (radius, a turn)
local WAVE_SEGMENTS = 5 -- segments a wave

-- How far down the head (its frame, y down) the bangs may reach: the top of the brows, else of the
-- eyes (the face's decals on the body: lbrow / rbrow, lpupil / rpupil); nil without a face. On a
-- potato head the face sits high on the body, and bangs as long as on a head hung to the mouth.
local function decalExtra(body, label)
    for _, f in ipairs(body:getFixtures()) do
        local ud = f:getUserData()
        if ud and ud.label == label and ud.extra then return ud.extra end
    end
end
local function browLine(body)
    local y
    for _, label in ipairs({ 'lbrow', 'rbrow' }) do
        local d = decalExtra(body, label)
        if d and d.oy then y = math.min(y or math.huge, d.oy - (d.h or 0) * 0.5) end
    end
    if y then return y end
    for _, label in ipairs({ 'lpupil', 'rpupil' }) do
        local d = decalExtra(body, label)
        if d and d.oy then y = math.min(y or math.huge, d.oy - (d.eyeH or d.h or 20) * 0.6) end
    end
    return y
end

-- The head's outline as it's drawn: the texfixture with the most points (a Mipo head's 8-point
-- shape), else the body's own shape. A potato head is drawn about twice its physics shape (-185..76
-- against -57..56 px): on the physics outline the hair grew from the middle of its face.
local function drawnOutline(body)
    local best
    for _, f in ipairs(body:getFixtures()) do
        local ud = f:getUserData()
        local v = ud and ud.subtype == 'texfixture' and ud.extra and ud.extra.vertices
        if v and #v >= 12 and (not best or #v > #best) then best = v end
    end
    if best then return best end
    local thing = utils.thingOf(body)
    return thing and thing.vertices
end

-- Whether (x, y) is inside the closed outline (flat list).
local function inside(vertices, x, y)
    local n, isIn = #vertices / 2, false
    local j = n
    for i = 1, n do
        local xi, yi, xj, yj = vertices[2 * i - 1], vertices[2 * i], vertices[2 * j - 1], vertices[2 * j]
        if (yi > y) ~= (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi then isIn = not isIn end
        j = i
    end
    return isIn
end

-- The face a coat keeps clear, as an oval { x, y, rx, ry } in the body's frame: round the eyes,
-- brows, nose and mouth (the face decals) with room to spare; nil without a face. On a potato head
-- the body is the face, and a coat kept only off the eyes and mouth grew a beard over the rest.
local FACE_LABELS = { 'lpupil', 'rpupil', 'leye', 'reye', 'lbrow', 'rbrow', 'nose', 'upperlip', 'lowerlip' }
local function faceOval(body)
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for _, label in ipairs(FACE_LABELS) do
        local d = decalExtra(body, label)
        if d and d.ox and d.oy then
            local hw, hh = (d.w or d.eyeW or 20) * 0.5, (d.h or d.eyeH or 20) * 0.5
            x0, x1 = math.min(x0, d.ox - hw), math.max(x1, d.ox + hw)
            y0, y1 = math.min(y0, d.oy - hh), math.max(y1, d.oy + hh)
        end
    end
    if x0 > x1 then return nil end
    -- an oval through the box's corners is sqrt(2) its half sides; a little more for room
    return { x = (x0 + x1) / 2, y = (y0 + y1) / 2, rx = (x1 - x0) / 2 * 1.6, ry = (y1 - y0) / 2 * 1.6 }
end

-- A coat's locks (o.surface of them): roots on a jittered grid over the outline (pulled in a
-- little from its edge), none on the face, hanging down, drawn in front.
local function surfaceLocks(o, vertices, body, rng, locks)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for i = 1, #vertices, 2 do
        minX, maxX = math.min(minX, vertices[i]), math.max(maxX, vertices[i])
        minY, maxY = math.min(minY, vertices[i + 1]), math.max(maxY, vertices[i + 1])
    end
    local step = math.sqrt((maxX - minX) * (maxY - minY) / o.surface)
    if step < 1 then return end
    local face, w = faceOval(body), o.wild
    local n = 3
    for gy = minY + step / 2, maxY, step do
        for gx = minX + step / 2, maxX, step do
            local x = gx + (rng:random() - 0.5) * step * 0.8
            local y = gy + (rng:random() - 0.5) * step * 0.8
            local clear = inside(vertices, x / 0.9, y / 0.9)
            if clear and face and ((x - face.x) / face.rx) ^ 2 + ((y - face.y) / face.ry) ^ 2 < 1 then
                clear = false
            end
            if clear then
                locks[#locks + 1] = {
                    rx = x, ry = y, restAngle = math.pi / 2 + (rng:random() - 0.5) * 0.8,
                    n = n, drape = false, front = true, surface = true,
                    segment = o.surfaceLength / (n - 1) * (1 + w * (rng:random() - 0.5) * 0.6),
                    curl = o.curl * 0.3 * (1 - w + w * (rng:random() * 2 - 1) * 2),
                    width = o.width * o.surfaceWidth * (1 + w * (rng:random() - 0.5) * 0.6),
                    points = {}, prev = {},
                }
            end
        end
    end
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
    local vertices = drawnOutline(body)
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
            rx = rx * o.inset, ry = ry * o.inset, -- a little inside, under the head
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
    local browY = browLine(body)
    for k = 1, o.bangs do
        local f = o.bangs > 1 and (k - 1) / (o.bangs - 1) or 0.5
        local angle = -math.pi / 2 + (f - 0.5) * o.bangSpread
        local rx, ry = outlinePoint(vertices, angle)
        local w = o.wild
        local segment = o.bangSegment * (1 + w * (rng:random() - 0.5) * 0.6)
        if browY and o.bangPoints > 1 then -- no lower than the brows: room from its root down to them
            local room = math.max(6, browY - ry * 0.95)
            segment = math.min(segment, room / (o.bangPoints - 1))
        end
        locks[#locks + 1] = {
            rx = rx * 0.95, ry = ry * 0.95,
            restAngle = angle + math.pi, n = o.bangPoints, drape = false, front = true, -- inward, over the face
            segment = segment,
            curl = o.curl * 0.5 * (1 - w + w * (rng:random() * 2 - 1) * 2),
            width = o.width * (1 + w * (rng:random() - 0.5) * 0.6),
            points = {}, prev = {},
        }
    end
    if o.surface > 0 then surfaceLocks(o, vertices, body, rng, locks) end
    -- each lock's bend per segment at rest (the curl); its curly wave and ringlet turns are only
    -- drawn (lockPath), each lock at its own phase: held by the physics, the wave fought the rest
    -- shape and the tips never stopped moving (7 px a frame on a still head, 2026-11-09)
    for _, lock in ipairs(locks) do
        lock.phase = rng:random() * 2 * math.pi
        lock.wave = o.curly * WAVE_AMP * (lock.drape and 1 or 0.5)
        -- its ringlet: the haircut's, or a coat's own small coils (chest hair curls)
        if lock.surface then
            lock.ring = o.surfaceCurly * COAT_RING * (1 + o.wild * (rng:random() - 0.5) * 0.6)
            lock.ringPitch = COAT_PITCH
        else
            lock.ring, lock.ringPitch = o.ringlets, o.ringletPitch
        end
        lock.bends = {}
        for i = 3, lock.n do lock.bends[i] = lock.curl end
    end
    local rootRest = {}
    for k, lock in ipairs(locks) do rootRest[2 * k - 1], rootRest[2 * k] = lock.rx, lock.ry end
    instance.hairLocks = { opts = o, locks = locks, body = body, ovalX = ovalX, ovalY = ovalY, rootRest = rootRest }
    lib.reset(instance)
end

-- Hair on any body (a box to pick up): `key` names it (again with the same key: new hair). Kept on
-- state, so a hot reload keeps it; drawn and moved with the Mipos' hair.
function lib.attachBody(body, opts, key)
    state.hairHolders = state.hairHolders or {}
    local holder = { parts = { head = { body = body } } }
    state.hairHolders[key or body] = holder
    lib.attach(holder, opts)
    return holder
end

-- The hair off the body attachBody gave it under `key`.
function lib.detachBody(key)
    if state.hairHolders then state.hairHolders[key] = nil end
end

-- The hair off every body that got it with attachBody (a scene's unload).
function lib.detachBodies()
    state.hairHolders = nil
end

-- Everything that wears hair: the Mipos, and the bodies given it with attachBody.
local holderList = {}
local function holders()
    local list, n = holderList, 0
    for _, instance in pairs(state.mipoInstances) do
        n = n + 1
        list[n] = instance
    end
    for key, holder in pairs(state.hairHolders or {}) do
        if holder.hairLocks then
            n = n + 1
            list[n] = holder
        else
            state.hairHolders[key] = nil -- its body is gone
        end
    end
    for i = n + 1, #list do list[i] = nil end
    return list
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

-- The floor under a haircut: one ray straight down from its body a frame, the nearest static
-- body it hits (a flat floor: hair lies on it instead of hanging through; nothing else stops hair).
local GROUND_RAY, GROUND_GAP = 4000, 2
local hitY
local function rayHit(fixture, _, y, _, _, fraction)
    if fixture:isSensor() or fixture:getBody():getType() ~= 'static' then return -1 end
    hitY = y
    return fraction -- only nearer ones from here on
end
local function groundBelow(x, y)
    hitY = nil
    state.physicsWorld:rayCast(x, y, x, y + GROUND_RAY, rayHit)
    return hitY
end

local function stepLock(lock, o, body, gx, gy, dt, ovalX, ovalY, groundY)
    local p, q = lock.points, lock.prev
    local n = lock.n
    local a = body:getAngle()
    local rootX, rootY = body:getWorldPoint(lock.bx or lock.rx, lock.by or lock.ry)
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
            if o.springy > 0 and lock.drape then -- (bangs keep their length: they end above the brows)
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
        if groundY and y > groundY - GROUND_GAP then -- on the floor: no further, and it drags
            y = groundY - GROUND_GAP
            q[ix], q[iy] = x - (x - q[ix]) * 0.5, y
        end
        p[ix], p[iy] = x, y
    end
end

-- Sleep: hair that has settled on a head that holds still isn't simulated (nor its strips built
-- again) until the head moves: most Mipos stand around most of the time.
local SLEEP_MOVE = 0.05  -- px a frame: no point of any lock moved more, the locks have settled
local STILL_MOVE, STILL_TURN = 0.05, 0.0005 -- px and radians a frame: the head holds still
local SLEEP_AFTER = 0.5  -- seconds settled and still: asleep
local WAKE_MOVE, WAKE_TURN = 0.5, 0.005 -- the head this far from where the hair fell asleep: awake

-- Whether no point moved more than SLEEP_MOVE since the last frame (from where they were then,
-- kept in hair.snap: points - prev isn't the move, DFTL writes into prev). Takes the new snapshot.
local function settled(hair)
    local limit, snap, k, still = SLEEP_MOVE * SLEEP_MOVE, hair.snap or {}, 0, true
    for _, lock in ipairs(hair.locks) do
        local p = lock.points
        for i = 1, 2 * lock.n, 2 do
            local x, y = p[i], p[i + 1]
            local sx, sy = snap[k + 1], snap[k + 2]
            if not sx or (x - sx) * (x - sx) + (y - sy) * (y - sy) > limit then still = false end
            snap[k + 1], snap[k + 2] = x, y
            k = k + 2
        end
    end
    for i = k + 1, #snap do snap[i] = nil end
    hair.snap = snap
    return still
end

-- Where each lock's root is on a torso drawn bent or pushed (a spine, lobes, the drawn jiggle:
-- spineSkin.torsoBones, the bones the torso picture is drawn with): its rest point moved as the
-- picture has it, into lock.bx / by (torso1's frame). Without such a torso the roots stay put.
-- Returns whether a root moved more than WAKE_MOVE from where it was when the hair fell asleep.
local function bendRoots(hair)
    local bones = hair.body and spineSkin.torsoBones(hair.body)
    if not bones then return false end
    local bent = (bones.deform or spineSkin.deform)(hair.rootRest, bones, hair.rootBent)
    hair.rootBent = bent
    local moved = false
    local slept = hair.asleep and hair.asleep.roots
    for k, lock in ipairs(hair.locks) do
        local bx, by = bent[2 * k - 1], bent[2 * k]
        lock.bx, lock.by = bx, by
        if slept and math.abs(bx - slept[2 * k - 1]) + math.abs(by - slept[2 * k]) > WAKE_MOVE then moved = true end
    end
    return moved
end

function lib.update(dt)
    local gx, gy = state.physicsWorld:getGravity()
    -- fixed steps: verlet carries velocity as the last step's move, so a step that changes size
    -- with the frame time flings points (80-120 px a step with uneven frames, 2026-11-09)
    local h = 1 / 120
    for _, instance in ipairs(holders()) do
        local hair = instance.hairLocks
        if hair then
            if hair.body:isDestroyed() then
                instance.hairLocks = nil
            elseif not hair.ovalX or not hair.rootRest or (hair.locks[1] and not hair.locks[1].ringPitch) then
                lib.attach(instance, hair.opts) -- made by an older version of this file (hot reload)
            else
                local body = hair.body
                local x, y = body:getPosition()
                local a = body:getAngle()
                local rootsMoved = bendRoots(hair)
                local s = hair.asleep
                if s and (rootsMoved or math.abs(x - s.x) + math.abs(y - s.y) > WAKE_MOVE
                        or math.abs(a - s.a) > WAKE_TURN) then
                    hair.asleep, hair.stillTime, hair.acc = nil, 0, 0
                end
                if not hair.asleep then
                    local groundY = groundBelow(x, y)
                    local w = hair.opts.weight * (1 - hair.opts.stand)
                    hair.acc = math.min((hair.acc or 0) + dt, 0.1)
                    local stepped = false
                    while hair.acc >= h do
                        hair.acc = hair.acc - h
                        stepped = true
                        for _, lock in ipairs(hair.locks) do
                            stepLock(lock, hair.opts, body, gx * w, gy * w, h, hair.ovalX, hair.ovalY, groundY)
                        end
                    end
                    if stepped then hair.version = (hair.version or 0) + 1 end
                    -- asleep once the locks have settled and the head held still for a while
                    local headStill = hair.lastX and math.abs(x - hair.lastX) + math.abs(y - hair.lastY) < STILL_MOVE
                        and math.abs(a - hair.lastA) < STILL_TURN
                    if stepped and headStill and settled(hair) then
                        hair.stillTime = (hair.stillTime or 0) + dt
                        if hair.stillTime >= SLEEP_AFTER then
                            hair.asleep = { x = x, y = y, a = a, roots = hair.rootBent and { unpack(hair.rootBent) } }
                        end
                    elseif stepped then
                        hair.stillTime = 0
                    end
                end
                hair.lastX, hair.lastY, hair.lastA = x, y, a
            end
        end
    end
end

-- The drawn path of a lock: a Catmull-Rom curve through its points (passes through them, so a
-- curl shows; one Bezier over them all smoothed it away), and for ringlets a corkscrew around
-- it, seen from the side and a little from above so the turns loop. The turns follow the lock's
-- rest length, so a stretched ringlet opens up like a spring. Fills `out` with x, y, shade.
local TILT = 0.5   -- how much of the turn is seen from above (its loops)
local MAXSAMPLES = hairNative.MAX_SAMPLES
local cork = {}
local restS = {} -- each sample's rest length along its lock: the picture's v, so it can't slide
local PLAIN_PER = 4 -- samples a segment of a lock without ringlets or a wave
local function lockPath(lock, o, out)
    local p, n, L = lock.points, lock.n, lock.segment
    local R, pitch = lock.ring or o.ringlets, math.max(4, lock.ringPitch or o.ringletPitch)
    local W, wavePitch = lock.wave or 0, L * WAVE_SEGMENTS
    -- samples per segment: ~10 a ringlet turn or wave; plain locks only as many as the bend needs
    local maxPer = math.max(1, math.floor((MAXSAMPLES - 1) / math.max(1, n - 1)))
    local ringPer = nil
    if R > 0 then ringPer = math.max(3, math.ceil(L / pitch * 10)) end
    if W > 0 then ringPer = math.max(ringPer or 0, math.ceil(10 / WAVE_SEGMENTS)) end
    ringPer = ringPer and math.min(maxPer, ringPer)
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
        -- a fixed count a segment: counting by the bend, a lock's samples changed as it moved and its
        -- picture slid along it (the hair jumped, 2026-11-09)
        local per = ringPer or math.min(maxPer, PLAIN_PER)
        for s = 0, (j == n - 1) and per or per - 1 do
            local t = s / per
            local t2, t3 = t * t, t * t * t
            local x = 0.5 * (2 * x1 + (x2 - x0) * t + (2 * x0 - 5 * x1 + 4 * x2 - x3) * t2
                + (3 * x1 - x0 - 3 * x2 + x3) * t3)
            local y = 0.5 * (2 * y1 + (y2 - y0) * t + (2 * y0 - 5 * y1 + 4 * y2 - y3) * t2
                + (3 * y1 - y0 - 3 * y2 + y3) * t3)
            count = count + 1
            out[3 * count - 2], out[3 * count - 1], out[3 * count] = x, y, (j - 1 + t) * L
            restS[count] = (j - 1 + t) * L
        end
    end
    -- the corkscrew and the wave: around the axis (tangents from the axis, so worked out before
    -- any point moves), growing in over the first turn / wave
    if R <= 0 and W <= 0 then
        for c = 1, count do out[3 * c] = 1 end
        return count
    end
    local moved = cork
    for c = 1, count do
        local x, y, s = out[3 * c - 2], out[3 * c - 1], out[3 * c]
        local a, b = math.max(1, c - 1), math.min(count, c + 1)
        local tx, ty = out[3 * b - 2] - out[3 * a - 2], out[3 * b - 1] - out[3 * a - 1]
        local tl = math.sqrt(tx * tx + ty * ty)
        if tl > 1e-6 then tx, ty = tx / tl, ty / tl else tx, ty = 0, 1 end
        local phase = lock.phase or 0
        local side, along, shade = 0, 0, 1
        if R > 0 then
            local r = R * math.min(1, s / pitch)
            local th = s / pitch * 2 * math.pi + phase
            local cs = math.cos(th)
            side, along = r * math.sin(th), r * TILT * cs
            shade = 0.72 + 0.28 * (0.5 + 0.5 * cs) -- the back of each turn darker
        end
        if W > 0 then
            side = side + W * math.min(1, s / wavePitch) * math.sin(s / wavePitch * 2 * math.pi + phase + 1)
        end
        moved[3 * c - 2] = x - ty * side + tx * along
        moved[3 * c - 1] = y + tx * side + ty * along
        moved[3 * c] = shade
    end
    for i = 1, 3 * count do out[i] = moved[i] end
    return count
end

local pathBuf = {}
local MESH_FORMAT = { -- as hair.c writes
    { 'VertexPosition', 'float', 2 }, { 'VertexTexCoord', 'float', 2 }, { 'VertexColor', 'float', 4 },
}

-- One lock's strip in Lua (lockPath, then the picture's width across, its length along) into
-- `verts` from index `start`, { x, y, u, v, r, g, b, a } each; returns how many it wrote.
-- The widest the strip can be at sample c without its inner edge folding over in a bend (as the
-- limb ribbons clamp, src/render/ribbon.lua): about twice the bend's radius there.
local function miterLimit(buf, c)
    local ax, ay = buf[3 * c - 2] - buf[3 * c - 5], buf[3 * c - 1] - buf[3 * c - 4]
    local bx, by = buf[3 * c + 1] - buf[3 * c - 2], buf[3 * c + 2] - buf[3 * c - 1]
    local la, lb = math.sqrt(ax * ax + ay * ay), math.sqrt(bx * bx + by * by)
    if la < 1e-9 or lb < 1e-9 then return math.huge end
    local dot = (ax * bx + ay * by) / (la * lb)
    if dot >= 0.9999 then return math.huge end
    dot = math.max(-1, math.min(1, dot))
    return math.min(la, lb) * math.tan((math.pi - math.acos(dot)) * 0.5)
end

local function luaLockVertices(lock, o, hw, verts, start)
    local count = lockPath(lock, o, pathBuf)
    local buf = pathBuf
    local total = math.max(1e-6, (lock.n - 1) * lock.segment)
    for c = 1, count do
        local a, b = math.max(1, c - 1), math.min(count, c + 1)
        local tx, ty = buf[3 * b - 2] - buf[3 * a - 2], buf[3 * b - 1] - buf[3 * a - 1]
        local tl = math.sqrt(tx * tx + ty * ty)
        if tl > 1e-6 then tx, ty = tx / tl, ty / tl else tx, ty = 0, 1 end
        local x, y, sh = buf[3 * c - 2], buf[3 * c - 1], buf[3 * c]
        local tv = restS[c] / total
        local w = hw
        if c > 1 and c < count then w = math.min(w, miterLimit(buf, c)) end
        local i = start + 2 * c - 2
        local l, r = verts[i] or {}, verts[i + 1] or {}
        l[1], l[2], l[3], l[4], l[5], l[6], l[7], l[8] = x - ty * w, y + tx * w, 0, tv, sh, sh, sh, 1
        r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8] = x + ty * w, y - tx * w, 1, tv, sh, sh, sh, 1
        verts[i], verts[i + 1] = l, r
    end
    return count >= 2 and 2 * count or 0
end

-- The most vertices a lock's strip can take, with the two that join it to the one before.
local function capacityFor(lock, o)
    local per = 5
    local ring, pitch = lock.ring or o.ringlets, lock.ringPitch or o.ringletPitch
    if ring > 0 then per = math.max(per, math.ceil(lock.segment / math.max(4, pitch) * 10)) end
    return 2 * math.min(MAXSAMPLES, (lock.n - 1) * per + 1) + 2
end

local nativeData -- one ByteData every layer takes turns writing (setVertices copies it); grows

-- All the locks of one layer of a Mipo's hair in one strip, joined by two repeated vertices
-- (triangles with no area): one mesh, drawn once a picture, instead of one a lock (27 locks were
-- 54 draws). Built again only when the hair moved since (asleep, it's kept as it is).
local function layerMesh(hair, wantFront, pic)
    hair.layers = hair.layers or {}
    local key = wantFront and 'front' or 'back'
    local L = hair.layers[key]
    if L and L.version == hair.version and L.pic == pic then return L.mesh end
    local o, cap = hair.opts, 0
    for _, lock in ipairs(hair.locks) do
        if (lock.front or false) == wantFront then cap = cap + capacityFor(lock, o) end
    end
    if cap == 0 then return nil end
    if not L or L.cap < cap then
        if L then L.mesh:release() end
        local size = math.max(cap, L and L.cap * 2 or 0)
        L = { mesh = love.graphics.newMesh(MESH_FORMAT, size, 'strip', 'stream'), cap = size, verts = {} }
        hair.layers[key] = L
    end
    local picW, count = pic:getWidth(), 0
    if lib.useNative and hairNative.available() then
        local bytes = cap * hairNative.BYTES_PER_VERTEX
        if not nativeData or nativeData:getSize() < bytes then
            nativeData = love.data.newByteData(math.max(bytes, nativeData and nativeData:getSize() * 2 or 0))
        end
        for _, lock in ipairs(hair.locks) do
            if (lock.front or false) == wantFront then
                local at = count > 0 and count + 2 or 0
                local c = hairNative.strip(lock.points, lock.n, lock.segment, lock.ring or o.ringlets,
                    lock.ringPitch or o.ringletPitch,
                    lock.wave or 0, lock.segment * WAVE_SEGMENTS, lock.phase or 0, TILT, picW * lock.width,
                    nativeData, at)
                if c > 0 then
                    if count > 0 then -- the join: the last vertex again, then the next strip's first
                        hairNative.copyVertex(nativeData, count - 1, count)
                        hairNative.copyVertex(nativeData, at, count + 1)
                    end
                    count = at + c
                end
            end
        end
        if count > 0 then L.mesh:setVertices(nativeData, 1, count) end
    else
        local v = L.verts
        for _, lock in ipairs(hair.locks) do
            if (lock.front or false) == wantFront then
                local at = count > 0 and count + 2 or 0
                local c = luaLockVertices(lock, o, picW * lock.width, v, at + 1)
                if c > 0 then
                    if count > 0 then
                        local last, first = v[count], v[at + 1]
                        local gap1, gap2 = v[count + 1] or {}, v[count + 2] or {}
                        for k = 1, 8 do gap1[k], gap2[k] = last[k], first[k] end
                        v[count + 1], v[count + 2] = gap1, gap2
                    end
                    count = at + c
                end
            end
        end
        for i = count + 1, #v do v[i] = nil end
        if count > 0 then L.mesh:setVertices(v) end
    end
    if count < 4 then return nil end
    L.mesh:setDrawRange(1, count)
    L.version, L.pic = hair.version, pic
    return L.mesh
end

-- The locks of every Mipo that has them, in the colours of its haircut: layer 'back' (behind the
-- Mipos) or 'front' (over their faces).
function lib.draw(layer)
    local wantFront = layer == 'front'
    for _, instance in ipairs(holders()) do
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
            local pic = line or mask
            local mesh = pic and layerMesh(hair, wantFront, pic)
            if mesh then
                if mask then
                    love.graphics.setColor(fr, fg, fb, 1)
                    mesh:setTexture(mask)
                    love.graphics.draw(mesh)
                end
                if line then
                    love.graphics.setColor(lr, lg, lb, 1)
                    mesh:setTexture(line)
                    love.graphics.draw(mesh)
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- One lock's strip built in Lua, { x, y, u, v, r, g, b, a } each (spec/hair-native_spec.lua).
function lib.luaStripVertices(lock, o, hw)
    local out = {}
    local n = luaLockVertices(lock, o, hw, out, 1)
    for i = n + 1, #out do out[i] = nil end
    return out
end

-- Whether a Mipo's hair is asleep (settled, its head still: not simulated, its strips kept).
function lib.isAsleep(instance)
    return instance.hairLocks and instance.hairLocks.asleep ~= nil or false
end

return lib

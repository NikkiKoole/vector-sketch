-- tree-grow: a whole tree grown from its kind (tree-kinds.lua), not a scene. Loaded with
-- love.filesystem.load('scripts/spikes/tree-grow.lua')() -> { grow, TWIG }.
-- grow(kind, rng, x, y, angle, scale, env) -> branches: each { pts = { {x, y, w, wl, wr, along, a}, ... },
-- depth (0 the trunk), isTrunk, outlineTrim }. rng a love RandomGenerator (the same seed grows the same
-- tree; the caller can go on drawing from it, as the bark scene does for the eyes). env, the world it grew
-- up in: organic 0..2 (0 straight and even, 1 as tuned, 2 wild), wind -1..1 (the prevailing wind over its
-- life, the sign its way: it leans with it, its crown combed to the lee side), sun -1..1 (where its light
-- came from: left, overhead, right; it reaches for it), crowd 0..1 with left/right (how much room to the
-- next tree on each side, world units; nil: none): its branches keep out of a neighbour's space, turning
-- up instead. From the bark spike (docs/BARK.md: BK1d-BK8).
local lib = {}

local STEP_LEN = 26 -- world units per step along a branch
local MAX_BRANCHES = 400
local TWIG = 5 -- thinnest a branch gets (world units)

-- turn angle a toward target by k of the way (the short way round)
local function turnToward(a, target, k)
    local d = math.atan2(math.sin(target - a), math.cos(target - a))
    return a + d * k
end

-- One branch, walked from (x, y) at angle a for len, w0 wide at its foot; then its side branches and, for a
-- trunk that forks, its limbs. Every branch goes into out: its middle line (points with width and length so
-- far) and depth.
-- Widths add up (da Vinci's rule, BARK BK4): each side branch takes its share of the wood where it leaves,
-- the branch goes on with what's left (a child's width is the parent's times the square root of its share),
-- and a fork splits what's left between its limbs. Bends have reasons (BK5): a limb sags more the further
-- out it reaches (its weight, more if thin), past recoverFrom its tip turns back up toward the light (the
-- elbow), thin tips can hang (droop: weeping); the slow wander is a little on top. Wind (BK7): the tree
-- grows toward a sky leaning downwind, its branches combed to the lee side, those reaching into the wind
-- shorter, those downwind longer.
local function grow(k, rng, out, x, y, a, len, w0, depth, isTrunk, scale, env)
    if #out >= MAX_BRANCHES then return end
    local organic, wind, sun, crowd = env.organic, env.wind, env.sun, env.crowd
    local sky = -math.pi / 2 + wind * 0.35 + sun * 0.15 -- where 'up' is for a tree in this wind and light
    local lee = wind > 0 and 0 or math.pi
    local n = math.max(3, math.floor(len / STEP_LEN))
    local wander = (isTrunk and k.trunkWander or k.wander) * organic
    local thin = 1 - math.min(1, w0 / (k.w * scale))
    -- how much of a branch's length fits before the neighbour's space on its side (1: all; crowd 0: all)
    local function roomFor(bx, ba, blen)
        if crowd <= 0 then return 1 end
        local dirx = math.cos(ba)
        local room = dirx > 0 and env.right or env.left
        if not room then return 1 end
        local left = room - (bx - env.x0) * (dirx > 0 and 1 or -1)
        local reach = blen * math.abs(dirx)
        if reach <= left then return 1 end
        return 1 - crowd * (1 - math.max(0.3, left / reach))
    end
    local bends = math.min(1.5, organic) -- the sag and the elbow, with the slider (0: straight)
    -- its side branches first, where they leave and how much wood each takes: the widths come from them
    local kids = {}
    if depth < k.depth and w0 > TWIG * 2 then
        local range = isTrunk and k.trunkKids or k.kids
        local count = rng:random(range[1], range[2])
        local from = isTrunk and k.trunkStart or k.start
        local side = rng:random() < 0.5 and 1 or -1
        for c = 1, count do
            local t = from + (1 - from) * (c - 1 + 0.3 + rng:random() * 0.5) / count
            if not k.fork and isTrunk then t = math.min(t, 0.96) end
            kids[#kids + 1] = { t = t, side = side, share = k.share * (0.7 + 0.6 * rng:random()) }
            side = -side
        end
    end
    -- a side branch starts a little inside its parent, so its collar grows out of the wood
    if not isTrunk then
        local back = w0 * 0.4 * math.min(1, organic)
        x, y = x - math.cos(a) * back, y - math.sin(a) * back
    end
    -- the walk
    local seed = rng:random() * 1000
    local line = { { x, y } }
    local step = len / n
    -- zigzag (BK6): where the tip bud dies each year and a side bud takes over, a twig kinks at every
    -- year's growth, the other way each time; most on thin wood (on old limbs the bark has grown over it)
    local year = math.max(45, math.min(130, len * 0.2))
    local nextYear = year * (0.6 + 0.6 * rng:random())
    local zigSide = rng:random() < 0.5 and 1 or -1
    local zig = isTrunk and 0 or (k.zigzag or 0) * bends * (0.25 + 0.75 * thin)
    for i = 1, n do
        if zig > 0 and i * step >= nextYear then
            a = a + zigSide * zig * (0.7 + 0.6 * rng:random())
            zigSide = -zigSide
            nextYear = nextYear + year * (0.8 + 0.4 * rng:random())
        end
        local u = (i - 1) / n
        local bend = (love.math.noise(seed, (i - 1) * step / 220) - 0.5) * 2.2 + (rng:random() - 0.5) * 0.25
        if organic == 0 then bend = 0 end
        a = a + bend * wander
        a = turnToward(a, sky, k.up * (isTrunk and 3 or 1))
        if not isTrunk then
            a = turnToward(a, math.pi / 2, k.sag * bends * u * (0.5 + thin)) -- its weight
            if u > k.recoverFrom then a = turnToward(a, sky, k.recover * bends) end -- the tip back up
            a = turnToward(a, math.pi / 2, k.droop * thin) -- thin tips hanging
            if wind ~= 0 then a = turnToward(a, lee, math.abs(wind) * 0.05 * (0.4 + thin)) end -- combed
            -- in a neighbour's space (past 60% of the room on that side): up instead, the further in the more
            if crowd > 0 then
                local dx = x - env.x0
                local room = dx > 0 and env.right or env.left
                if room and math.abs(dx) > room * 0.6 then
                    a = turnToward(a, sky, crowd * 0.12 * math.min(1, (math.abs(dx) - room * 0.6) / (room * 0.4)))
                end
            end
        end
        x, y = x + math.cos(a) * step, y + math.sin(a) * step
        line[#line + 1] = { x, y }
    end
    -- rounded off (corners cut twice, the ends kept)
    for _ = 1, 2 do
        local sm = { line[1] }
        for i = 1, #line - 1 do
            local p, q = line[i], line[i + 1]
            if i > 1 then sm[#sm + 1] = { p[1] * 0.75 + q[1] * 0.25, p[2] * 0.75 + q[2] * 0.25 } end
            if i < #line - 1 then sm[#sm + 1] = { p[1] * 0.25 + q[1] * 0.75, p[2] * 0.25 + q[2] * 0.75 } end
        end
        sm[#sm + 1] = line[#line]
        line = sm
    end
    local pts, along = {}, 0
    for i, q in ipairs(line) do
        if i > 1 then
            local o = line[i - 1]
            along = along + math.sqrt((q[1] - o[1]) ^ 2 + (q[2] - o[2]) ^ 2)
        end
        local nx = line[math.min(#line, i + 1)]
        local pv = line[math.max(1, i - 1)]
        pts[i] = { x = q[1], y = q[2], along = along, a = math.atan2(nx[2] - pv[2], nx[1] - pv[1]) }
    end
    local total = math.max(1, along)
    -- the wood left at u: after each side branch it's (1 - share) of what it was (eased over a short
    -- stretch, no step); the wood itself thins a little along the way
    local function woodAt(u)
        local rem = 1
        for _, kid in ipairs(kids) do
            local e = math.max(0, math.min(1, (u - kid.t + 0.03) / 0.06))
            rem = rem * (1 - kid.share * e * e * (3 - 2 * e))
        end
        return rem
    end
    local function widthAt(u) return w0 * math.sqrt(woodAt(u)) * (1 - 0.2 * u) end
    for _, p in ipairs(pts) do
        local u = p.along / total
        local w = widthAt(u)
        if not (isTrunk and k.fork) then w = w * (1 - 0.65 * math.max(0, (u - 0.7) / 0.3) ^ 2) end -- the tip
        if isTrunk then
            w = w * (1 + k.flare * (1 - math.min(1, u * 6)) ^ 2) -- roots flaring at the foot
        else
            w = w * (1 + 0.45 * organic * (1 - math.min(1, u * 5)) ^ 2) -- the collar
        end
        w = math.max(TWIG, w)
        p.w = w
        p.wl = w * (1 + 0.16 * organic * (love.math.noise(seed + 7, p.along / 90) - 0.5))
        p.wr = w * (1 + 0.16 * organic * (love.math.noise(seed + 13, p.along / 90) - 0.5))
    end
    a = pts[#pts].a
    local wEnd = widthAt(1)
    -- a trunk that forks narrows to a point in its last stretch, hidden between its limbs (a crotch, not a
    -- flat top)
    if isTrunk and k.fork and #pts >= 3 then
        for j, f in ipairs({ 0.3, 0.6, 0.85 }) do
            local p = pts[#pts - j + 1]
            p.w, p.wl, p.wr = p.w * f, p.wl * f, p.wr * f
        end
    end
    n = #pts - 1
    -- (its outline stops where it narrows: else the outline draws a V across the limbs)
    out[#out + 1] = { pts = pts, depth = depth, isTrunk = isTrunk, outlineTrim = (isTrunk and k.fork) and 4 or 0 }
    -- the side branches, each as wide as its share of the wood there
    for _, kid in ipairs(kids) do
        local p = pts[math.floor(kid.t * n) + 1]
        local spread = (isTrunk and k.firstSpread) or k.spread
        local ca = p.a + kid.side * (spread[1] + (spread[2] - spread[1]) * rng:random())
        local clen = len * k.len * (0.8 + 0.4 * rng:random())
        if k.cone and isTrunk then clen = clen * (1 - kid.t * (k.coneTop or 0.85)) end -- shorter toward the top
        if wind ~= 0 then clen = clen * (1 + 0.45 * wind * math.cos(ca)) end -- short into the wind, long with it
        if sun ~= 0 then clen = clen * (1 + 0.5 * sun * math.cos(ca)) end -- long on the sunny side (lopsided)
        clen = clen * roomFor(p.x, ca, clen)
        local cw = widthAt(kid.t - 0.04) * math.sqrt(kid.share)
        grow(k, rng, out, p.x, p.y, ca, clen, math.max(TWIG, cw), depth + 1, false, scale, env)
    end
    -- a trunk that forks: what's left of its wood split between its limbs, fanned out from a step below the
    -- top (they overlap the trunk's end: no notch)
    if isTrunk and k.fork then
        local nf, fan, flen = k.fork[1], k.fork[2], k.fork[3]
        local top = pts[math.max(1, #pts - 1)]
        local weights, sum = {}, 0
        for f = 1, nf do weights[f] = 0.7 + 0.6 * rng:random(); sum = sum + weights[f] end
        for f = 1, nf do
            local fa = a + (f - (nf + 1) / 2) * fan + (rng:random() - 0.5) * 0.2
            local fw = wEnd * math.sqrt(weights[f] / sum)
            local flenHere = len * flen * (0.85 + 0.3 * rng:random())
            if wind ~= 0 then flenHere = flenHere * (1 + 0.45 * wind * math.cos(fa)) end
            if sun ~= 0 then flenHere = flenHere * (1 + 0.5 * sun * math.cos(fa)) end
            flenHere = flenHere * roomFor(top.x, fa, flenHere)
            grow(k, rng, out, top.x, top.y, fa, flenHere, fw, depth + 1, false, scale, env)
        end
    end
end

function lib.grow(kind, rng, x, y, angle, scale, env)
    local branches = {}
    scale = scale or 1
    env = env or {}
    env = { organic = env.organic or 1, wind = env.wind or 0, sun = env.sun or 0, crowd = env.crowd or 0,
        left = env.left, right = env.right, x0 = x }
    grow(kind, rng, branches, x, y, angle, kind.trunk * scale, kind.w * scale, 0, true, scale, env)
    return branches
end

lib.TWIG = TWIG

return lib

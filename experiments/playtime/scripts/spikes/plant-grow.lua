-- plant-grow: a whole plant grown from its kind (plant-kinds.lua), not a scene. Loaded with
-- love.filesystem.load('scripts/spikes/plant-grow.lua')() -> { grow, expand }.
-- grow(kind, rng, x, y, env) -> plant { stems, organs, height, x0, y0, colors }
--   stems:  { pts = { {x, y, w, along}, ... }, depth } (drawn deepest first)
--   organs: leaves { type = 'leaf', x, y, a, len, wk, droop, z, shape, over, petiole }, heads { type = 'head',
--           x, y, a, size, open, over, z, def } (def: the kind's head table; a pendant head hangs)
-- rng a love RandomGenerator (the same seed grows the same plant). env: organic 0..2 (0 the bare L-system:
-- straight segments, textbook angles, leaves flat left and right; 1 as tuned; 2 wild), age 0..2 (0 a seed,
-- 1 grown and flowering, 2 gone over: seed heads, yellowing leaves from below, leaning), wind -1..1 (the
-- wind it grew up in: leans with it), sun -1..1 (where its light came from: it bends that way).
-- docs/FLORA.md. The tree grower's ideas (tree-grow.lua, BARK.md) for plants:
--   * the L-system gives the structure (internodes, branches, leaves, heads), not the drawing: the walk
--     turns it into stems in small steps that wander by smooth noise, ease into their branch angle, and
--     reach for the light
--   * weight: each stem knows what it carries (the stems, leaves and heads above it); it bends under that
--     the more it leans and the thinner it is: heavy heads nod, long stems arch, pedicels hang
--   * widths add up (the pipe model, da Vinci): a stem is as thick as the square root of what it carries
--   * internodes short at the foot, long in the middle, short again under the flower
--   * phyllotaxis: leaves go round the stem (spiral 137.5 degrees, alternate, opposite crossing pairs) and
--     are seen in 3D: one pointing at you looks short and sits in front, one pointing away behind the stem
--   * leaves older lower down: bigger, drooping more, the first to yellow
--   * growth from the foot up, heads last; fern fronds unroll from a curl
local lib = {}

local STEP = 8 -- world units per step along a stem
local DRAW_STEP = 22 -- and between the points it's drawn through
local MAX_TOKENS = 4000
local GOLDEN = 2.39996323 -- 137.5 degrees
local UP, DOWN = -math.pi / 2, math.pi / 2

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end
local function smooth(x)
    x = clamp(x, 0, 1)
    return x * x * (3 - 2 * x)
end
local function wrap(d) return math.atan2(math.sin(d), math.cos(d)) end
-- turn a toward target by k of the way (the short way round; side breaks a tie when it's straight opposite)
local function turnToward(a, target, k, side)
    local d = wrap(target - a)
    if side and math.abs(d) > math.pi - 0.02 then d = math.abs(d) * side end
    return a + d * k
end

---------------------------------------------------------------- the L-system

-- the kind's axiom rewritten iter times (rules with several weighted choices: stochastic), then its final
-- rules; every symbol with its own random numbers, kept
function lib.expand(kind, rng)
    local str = kind.axiom
    local rules = kind.rules or {}
    for _ = 1, kind.iter or 0 do
        local out = {}
        for c in str:gmatch('.') do
            local choices = rules[c]
            if choices then
                local total = 0
                for _, ch in ipairs(choices) do total = total + ch[2] end
                local r = rng:random() * total
                local pick = choices[#choices][1]
                for _, ch in ipairs(choices) do
                    r = r - ch[2]
                    if r <= 0 then pick = ch[1]; break end
                end
                out[#out + 1] = pick
            else
                out[#out + 1] = c
            end
        end
        str = table.concat(out)
        if #str > MAX_TOKENS then break end
    end
    local final = kind.final or {}
    local tokens = {}
    for c in str:gmatch('.') do
        local f = final[c] or c
        for c2 in f:gmatch('.') do
            tokens[#tokens + 1] = { c = c2, r1 = rng:random(), r2 = rng:random(), r3 = rng:random() }
        end
    end
    return tokens
end

---------------------------------------------------------------- the structure

-- Symbols: F an internode, f a short one, + - turn by the kind's angle, [ ] a branch, L a leaf at this node
-- (round the stem by the phyllotaxis), O a pair of opposite leaves, and any letter in kind.heads a head
-- there (a flower, a bell, a seed spike). Anything else is ignored (X and friends, the rewriting's own).
-- A stem: { segs = { { len, turn, organs, kids }, ... }, base = { organs, kids }, depth, nodes }.
local function newStem(depth) return { segs = {}, base = { organs = {}, kids = {} }, depth = depth, nodes = 0 } end

local function parse(tokens, kind, organicJ)
    local root = newStem(0)
    local cur, stack, pending = root, {}, 0
    local function here() return cur.segs[#cur.segs] or cur.base end
    local angle = math.rad(kind.angle or 25)
    for _, tok in ipairs(tokens) do
        local c = tok.c
        if c == 'F' or c == 'f' then
            local seg = { len = c == 'F' and 1 or 0.45, turn = pending, organs = {}, kids = {}, tok = tok }
            pending = 0
            cur.segs[#cur.segs + 1] = seg
        elseif c == '+' then pending = pending + angle * (1 + (tok.r1 - 0.5) * 0.6 * organicJ)
        elseif c == '-' then pending = pending - angle * (1 + (tok.r1 - 0.5) * 0.6 * organicJ)
        elseif c == '[' then
            local kid = newStem(cur.depth + 1)
            local h = here()
            h.kids[#h.kids + 1] = kid
            stack[#stack + 1] = { cur, pending }
            cur = kid
        elseif c == ']' then
            local top = table.remove(stack)
            if top then cur, pending = top[1], top[2] end
        elseif c == 'L' or c == 'O' then
            local h = here()
            h.organs[#h.organs + 1] = { c = c, tok = tok, node = cur.nodes }
            cur.nodes = cur.nodes + 1
        elseif kind.heads and kind.heads[c] then
            local h = here()
            h.organs[#h.organs + 1] = { c = c, tok = tok, node = cur.nodes, head = kind.heads[c] }
        end
    end
    return root
end

-- internode length along a stem (u 0 at its foot, 1 at its tip): short, long in the lower middle, shorter
-- under the flower
local function profile(p, u)
    p = p or { 0.5, 1, 0.6 }
    if u < 0.35 then return p[1] + (p[2] - p[1]) * smooth(u / 0.35) end
    return p[2] + (p[3] - p[2]) * smooth((u - 0.35) / 0.65)
end

-- nominal lengths, how much each stem carries (stem wood, leaves, heads and everything above), and where
-- along the plant each part is (0 the foot .. 1 the furthest tip: when it grows)
local function measure(stem, kind, scale, path, rng, organicJ)
    local n = #stem.segs
    local lenK = (kind.len or 40) * scale * ((kind.branchLen or 0.8) ^ stem.depth)
    local maxPath = path
    stem.side = rng:random() < 0.5 and -1 or 1
    stem.phi0 = rng:random() * math.pi * 2
    stem.seed = rng:random() * 1000
    for i, seg in ipairs(stem.segs) do
        local u = n > 1 and (i - 1) / (n - 1) or 0
        seg.u = u
        seg.nominal = lenK * seg.len * profile(kind.profile, u) * (1 + (seg.tok.r2 - 0.5) * 0.35 * organicJ)
    end
    local function organsAt(holder, p)
        for _, o in ipairs(holder.organs) do o.path = p end
        for _, kid in ipairs(holder.kids) do
            local m = measure(kid, kind, scale, p, rng, organicJ)
            maxPath = math.max(maxPath, m)
        end
    end
    organsAt(stem.base, path)
    for _, seg in ipairs(stem.segs) do
        seg.path = path
        path = path + seg.nominal
        maxPath = math.max(maxPath, path)
        organsAt(seg, path)
    end
    -- the load, from the tip down
    local function organMass(o)
        if o.head then return (o.head.mass or 1) * scale end
        return (o.c == 'O' and 2 or 1) * (kind.leafMass or 0.3) * scale
    end
    local function holderLoad(holder)
        local m = 0
        for _, o in ipairs(holder.organs) do m = m + organMass(o) end
        for _, kid in ipairs(holder.kids) do m = m + kid.load end
        return m
    end
    local above = 0
    for i = n, 1, -1 do
        local seg = stem.segs[i]
        above = above + holderLoad(seg) + seg.nominal * 0.01 * (kind.stemMass or 1)
        seg.load = above
    end
    stem.load = above + holderLoad(stem.base)
    stem.ownLoad = above
    return maxPath
end

---------------------------------------------------------------- the walk

-- leaves seen in 3D: a leaf leaves the stem at insertion angle theta (from the stem's axis), round it at
-- azimuth phi (0 to the right, pi/2 toward you). Its direction on the screen, how long it looks and how
-- far in front of the stem it is.
local function project(theta, phi, organic)
    local c = math.cos(phi)
    local f = math.min(1, organic)
    local side = c >= 0 and 1 or -1
    c = side + (c - side) * f -- organic 0: flat, left and right
    local across = math.sin(theta) * c
    local along = math.cos(theta)
    local depth = math.sin(theta) * math.sin(phi) * f
    return math.atan2(across, along), math.sqrt(across * across + along * along), depth, side
end

-- L: the leaf's kind (the kind's leaf, or its rosette's); size nil: by kind.leafProfile along the stem
local function leafAt(ctx, o, x, y, a, phi, u, L, size)
    local kind = ctx.kind
    L = L or kind.leaf
    if not L then return end
    local tok = o.tok
    local birth = o.path / ctx.maxPath
    local k = smooth((ctx.T - birth - 0.08) / 0.3)
    if k <= 0 then return end
    if ctx.organic > 0 and tok.r3 < (kind.leafMissing or 0.06) * math.min(1, ctx.organic) then return end
    local theta = (o.angle or L.angle) * (1 + (tok.r1 - 0.5) * 0.4 * ctx.organicJ)
    -- older leaves lower down stand out further and droop more
    theta = theta + (L.ageOpen or 0.3) * (1 - u) * math.min(1, ctx.organic)
    local off, lenK, z, side = project(theta, phi, ctx.organic)
    -- size along the stem: kind.leafProfile { at the foot, middle, top }
    size = size or profile(kind.leafProfile or { 1, 1, 0.5 }, u)
    local len = L.len * ctx.scale * size * (1 + (tok.r2 - 0.5) * 0.4 * ctx.organicJ) * k
    local over = clamp(ctx.over * 1.6 - u * 0.9 + (tok.r3 - 0.5) * 0.3, 0, 1)
    local droop = (L.droop or 0.4) * ctx.bends * (0.6 + 0.8 * (1 - u)) * (0.6 + 0.4 * k) * (1 + over)
    local wk = (L.wk or 0.6) * (0.4 + 0.6 * math.abs(math.sin(phi)) ^ (0.5 + 0.5 * (1 - math.min(1, ctx.organic))))
    if ctx.organic == 0 then wk = L.wk or 0.6 end
    local shape = L.shapes[1 + math.floor(tok.r1 * #L.shapes * 0.999)]
    local la = a + off
    -- leaves turn their blades flat to the light: level pulls them toward lying sideways
    if L.level and ctx.organic > 0 then
        la = turnToward(la, math.cos(la) >= 0 and -0.15 or math.pi + 0.15, L.level * math.min(1, ctx.organic))
    end
    ctx.organs[#ctx.organs + 1] = { type = 'leaf', x = x, y = y, a = la, len = len * lenK, wk = wk,
        lie = L.lie, leaflets = L.leaflets, tint = L.oldColor, tintK = o.tintK or (1 - u),
        droop = droop, z = z, shape = shape, over = over, side = side, petiole = (L.petiole or 0) * len,
        flat = lenK, h = ctx.y0 - y, seed = tok.r2, back = z < 0 }
end

local function headAt(ctx, o, x, y, a, phi, u)
    local H = o.head
    local tok = o.tok
    local birth = o.path / ctx.maxPath
    local k = smooth((ctx.T - birth - 0.05) / 0.25)
    if k <= 0 then return end
    -- heads open last, the lower and earlier ones first
    local open = smooth((ctx.T - birth - 0.3 - tok.r1 * 0.15 * ctx.organicJ) / 0.3)
    local over = clamp(ctx.over * 1.5 - (1 - birth) * 0.5 + (tok.r2 - 0.5) * 0.4 * ctx.organicJ, 0, 1)
    local z = 0.2
    local ha = a
    if H.pendant then
        -- hangs off the stem round it (or all to one side: a foxglove), turned down as it opens
        local p = H.oneSided and (ctx.stemSide * 0.4) or phi
        local off, _, depth = project(H.angle or 1.2, p, ctx.organic)
        if H.oneSided then off = ctx.stemSide * math.abs(off) end
        ha = a + off
        ha = turnToward(ha, DOWN, (H.hang or 0.8) * (0.25 + 0.75 * open) * math.min(1, 0.4 + ctx.bends), ctx.stemSide)
        z = depth
    end
    ctx.organs[#ctx.organs + 1] = { type = 'head', x = x, y = y, a = ha, stemA = a,
        size = (H.size or 60) * ctx.scale * (1 + (tok.r3 - 0.5) * 0.3 * ctx.organicJ) * (0.35 + 0.65 * k),
        open = open, over = over, z = z, def = H, seed = tok.r3, colorI = tok.r1, h = ctx.y0 - y, u = u }
end

-- the organs on one node: leaves round the stem by its phyllotaxis, heads
local function organsOn(ctx, stem, holder, x, y, a, u, w)
    local kind = ctx.kind
    local phyllo = kind.phyllo or 'spiral'
    for _, o in ipairs(holder.organs) do
        local n = o.node
        local jit = (o.tok.r2 - 0.5) * 0.5 * ctx.organicJ
        if o.head then
            headAt(ctx, o, x, y, a, stem.phi0 + n * GOLDEN + jit, u)
        elseif o.c == 'O' then
            local phi = stem.phi0 + (phyllo == 'flat' and 0 or n * math.pi / 2) + jit * 0.5
            if phyllo == 'flat' then phi = 0.25 * ctx.organicJ * (o.tok.r3 - 0.5) end
            leafAt(ctx, o, x, y, a, phi, u)
            leafAt(ctx, o, x, y, a, phi + math.pi, u)
        else
            local div = (phyllo == 'alternate' or phyllo == 'flat') and math.pi or GOLDEN
            local phi = stem.phi0 + n * div + jit
            if phyllo == 'flat' then phi = (n % 2) * math.pi + stem.side * 0.3 * ctx.organicJ * (o.tok.r3 - 0.2) end
            leafAt(ctx, o, x, y, a, phi, u)
        end
    end
    -- (w kept for later: leaves sitting on the stem's edge)
    return w
end

local function widthFor(ctx, load)
    local kind = ctx.kind
    local w0, tip = kind.width * ctx.scale, (kind.tip or 2) * ctx.scale
    return tip + (w0 - tip) * math.sqrt(clamp(load / ctx.rootLoad, 0, 1))
end

local function walk(ctx, stem, x, y, a, out)
    local kind = ctx.kind
    local pts = { { x = x, y = y, w = widthFor(ctx, stem.load) * ctx.thick, along = 0 } }
    local along = 0
    local stemSide = stem.side
    ctx.stemSide = stemSide
    organsOn(ctx, stem, stem.base, x, y, a, 0, pts[1].w)
    for _, kid in ipairs(stem.base.kids) do walk(ctx, kid, x, y, a, out); ctx.stemSide = stemSide end
    local wander = (stem.depth == 0 and (kind.trunkWander or kind.wander) or kind.wander or 0.1) * ctx.organic
    local nSegs = #stem.segs
    local lastHead
    for i, seg in ipairs(stem.segs) do
        local birth = seg.path / ctx.maxPath
        local k = smooth((ctx.T - birth) / 0.18)
        if k <= 0 then break end
        local len = seg.nominal * k
        local n = math.max(1, math.ceil(len / STEP))
        local step = len / n
        local turnSteps = ctx.organic > 0 and math.max(1, math.floor(n * 0.5)) or 1
        local w = widthFor(ctx, seg.load) * ctx.thick * (0.45 + 0.55 * k)
        -- a head at this segment's end: its weight already counts in seg.load; nod is the head's own
        -- habit on top (a poppy bud hangs, a sunflower droops when it's heavy with seed)
        local nod = 0
        if i == nSegs then
            for _, o in ipairs(seg.organs) do
                if o.head and not o.head.pendant then lastHead = o end
            end
            if lastHead then
                local H = lastHead.head
                local birthH = lastHead.path / ctx.maxPath
                local open = smooth((ctx.T - birthH - 0.3) / 0.3)
                nod = ((H.budNod or 0) * (1 - open) * smooth((ctx.T - birthH) / 0.2) + (H.oldNod or 0) * ctx.over)
                    * math.min(1, ctx.bends)
            end
        end
        local wPrev = pts[#pts].w
        for s = 1, n do
            local u = (s - 0.5) / n
            if s <= turnSteps then a = a + seg.turn / turnSteps end
            -- slow wander (smooth noise along the stem, as the trees)
            if wander > 0 then
                a = a + (love.math.noise(stem.seed, (along + s * step) / 160) - 0.5) * 2 * wander * step / 30
            end
            -- toward the light (more where it's young and thin)
            local thin = 1 - clamp(w / (kind.width * ctx.scale), 0, 1)
            a = turnToward(a, ctx.sky, (kind.up or 0.05) * (0.4 + thin) * step / 30, stemSide)
            -- its weight: what it carries, the more it leans and the thinner it is (stiffness ~ w^2)
            if ctx.bends > 0 and kind.sag then
                local lean = math.abs(math.cos(a)) + 0.12
                local stiff = clamp(w / (kind.width * ctx.scale), 0.08, 1) ^ 2
                local load = seg.load / ctx.rootLoad
                local bend = kind.sag * ctx.bends * load * lean / stiff * step / 30 * (1 + ctx.over * 0.6)
                local side = math.cos(a) >= 0 and 1 or -1
                if math.abs(math.cos(a)) < 0.05 then side = stemSide end
                a = turnToward(a, DOWN, clamp(bend, 0, 0.2), side)
            end
            if nod > 0 then a = turnToward(a, DOWN, nod * u * u * step / 30, stemSide) end
            -- a fern frond unrolls: its tip curled while it's young
            if kind.curl and ctx.bends > 0 then
                local young = 1 - smooth((ctx.T - birth - 0.05) / 0.5)
                local f = (seg.path + seg.nominal * u) / math.max(1, ctx.stemNominal[stem] or 1)
                a = a + stemSide * kind.curl * (0.08 + young) * f ^ 3 * step / 10
            end
            x, y = x + math.cos(a) * step, y + math.sin(a) * step
            along = along + step
            -- walked in small steps, drawn through fewer points (every DRAW_STEP and each node)
            if s == n or along - pts[#pts].along >= DRAW_STEP then
                pts[#pts + 1] = { x = x, y = y, w = wPrev + (w - wPrev) * (s / n), along = along }
            end
        end
        organsOn(ctx, stem, seg, x, y, a, seg.u, w)
        for _, kid in ipairs(seg.kids) do
            walk(ctx, kid, x, y, a, out)
            ctx.stemSide = stemSide
        end
    end
    -- a stem ends in a point (unless a head sits there)
    if #pts >= 3 and not lastHead then
        pts[#pts].w = pts[#pts].w * 0.5
    end
    if #pts >= 2 then out[#out + 1] = { pts = pts, depth = stem.depth } end
end

---------------------------------------------------------------- a plant

local function shift(c, d)
    return { clamp(c[1] + d[1], 0, 1), clamp(c[2] + d[2], 0, 1), clamp(c[3] + d[3], 0, 1) }
end

-- rosette: a ring of leaves round the foot (spiral), the outer ones older, lying lower. pups: small rosettes
-- round it (a houseleek's offsets), each its own ring
local function rosette(ctx, x, y, R, sizeK)
    if not R then return end
    local rng = ctx.rng
    sizeK = sizeK or 1
    local count = R.count + math.floor((rng:random() - 0.5) * 2 * (R.vary or 1) * ctx.organicJ + 0.5)
    if sizeK < 1 then count = math.max(4, math.floor(count * (0.4 + 0.6 * sizeK))) end
    local phi0 = rng:random() * math.pi * 2
    for i = 1, math.max(1, count) do
        local u = (i - 1) / math.max(1, count - 1) -- 0 the outer (oldest), 1 the inner
        local tok = { r1 = rng:random(), r2 = rng:random(), r3 = rng:random() }
        -- outer leaves lie flatter
        local o = { tok = tok, path = u * 0.15 * ctx.maxPath, angle = (R.angle or 1.2) * (1 - (R.closing or 0.35) * u),
            tintK = 1 - u }
        leafAt(ctx, o, x + (tok.r3 - 0.5) * 6 * sizeK, y, UP + (tok.r2 - 0.5) * 0.1 * ctx.organicJ,
            phi0 + i * GOLDEN, 0, R.leaf or ctx.kind.leaf, (R.size or 1) * (1 - 0.3 * u) * sizeK)
    end
end

local function pups(ctx, x, y)
    local R = ctx.kind.rosette
    local P = R and R.pups
    if not P then return end
    local rng = ctx.rng
    local n = rng:random(P[1], P[2])
    local side = rng:random() < 0.5 and -1 or 1
    for i = 1, n do
        local d = P[3] * ctx.scale * (0.7 + 0.6 * rng:random())
        local k = P[4] * (0.6 + 0.6 * rng:random())
        rosette(ctx, x + side * d * (1 + (i - 1) * 0.35), y, R, k)
        side = -side
    end
end

-- Every plant its own: the kind's numbers nudged (lengths, angles), its greens shifted together, its
-- flowers' colour picked; how many stems out of the foot and at what angles.
function lib.grow(kind, rng, x, y, env)
    env = env or {}
    local organic = env.organic or 1
    local organicJ = math.min(1, organic) + math.max(0, organic - 1) * 1.5 -- jitter: more past 1
    local age = env.age or 1
    local scale = (env.scale or 1) * (1 + (rng:random() - 0.5) * 0.3 * math.min(1, organic))
    local wind, sun = env.wind or 0, env.sun or 0
    local ctx = {
        kind = kind, env = env, rng = rng, organic = organic, organicJ = organicJ,
        bends = math.min(1.6, organic), scale = scale, organs = {}, y0 = y,
        sky = UP + wind * 0.3 + sun * (kind.sunny or 0.3),
        -- growth clock: everything grown and open at age 1 (heads open ~0.6 after their place)
        T = math.min(1, age) * 1.65,
        over = math.max(0, age - 1),
        thick = 0.55 + 0.45 * math.min(1, age) + 0.1 * math.max(0, age - 1),
    }
    -- a colour per plant: greens together, the flowers on their own
    local dg = { (rng:random() - 0.5) * 0.08, (rng:random() - 0.5) * 0.1, (rng:random() - 0.5) * 0.06 }
    local colors = {
        stem = shift(kind.stemColor or { 0.38, 0.55, 0.25 }, dg),
        leaf = shift(kind.leafColor or { 0.36, 0.56, 0.24 }, dg),
        flower = rng:random(),
    }
    -- the stems out of the foot, each its own expansion
    local stems = kind.stems or { 1, 1, 0 }
    local count = rng:random(stems[1], stems[2])
    local roots = {}
    for i = 1, count do
        local tokens = lib.expand(kind, rng)
        local root = parse(tokens, kind, organicJ)
        local f = count > 1 and (i - 1) / (count - 1) - 0.5 or 0
        root.angle = UP + f * (stems[3] or 0) * 2 + (rng:random() - 0.5) * 0.3 * organicJ
            + (kind.lean or 0) * (rng:random() < 0.5 and -1 or 1) * math.min(1, organic)
        roots[i] = root
    end
    ctx.maxPath = 1
    ctx.stemNominal = {}
    for _, root in ipairs(roots) do
        ctx.maxPath = math.max(ctx.maxPath, measure(root, kind, scale, 0, rng, organicJ))
    end
    -- each stem's own length (the fern's curl reads how far along its frond it is)
    local function nominal(stem)
        local t = 0
        for _, seg in ipairs(stem.segs) do t = t + seg.nominal end
        ctx.stemNominal[stem] = math.max(1, t + (stem.segs[1] and stem.segs[1].path or 0))
        for _, seg in ipairs(stem.segs) do for _, kid in ipairs(seg.kids) do nominal(kid) end end
        for _, kid in ipairs(stem.base.kids) do nominal(kid) end
    end
    for _, root in ipairs(roots) do nominal(root) end
    -- the thickest root sets the widths (the others in proportion)
    ctx.rootLoad = 0.001
    for _, root in ipairs(roots) do ctx.rootLoad = math.max(ctx.rootLoad, root.load) end
    local out = {}
    pups(ctx, x, y) -- (behind the mother: drawn first)
    rosette(ctx, x, y, kind.rosette)
    for i, root in ipairs(roots) do
        local spread = count > 1 and ((i - 1) / (count - 1) - 0.5) * (kind.footSpread or 20) * scale or 0
        walk(ctx, root, x + spread, y, root.angle, out)
    end
    table.sort(out, function(p, q) return p.depth > q.depth end)
    -- how far it reaches (for culling: organs by their full length)
    local top, left, right = y, x, x
    for _, st in ipairs(out) do
        for _, p in ipairs(st.pts) do top, left, right = math.min(top, p.y), math.min(left, p.x), math.max(right, p.x) end
    end
    for _, o in ipairs(ctx.organs) do
        local r = o.len or o.size or 0
        top, left, right = math.min(top, o.y - r), math.min(left, o.x - r), math.max(right, o.x + r)
    end
    return { stems = out, organs = ctx.organs, height = math.max(40, y - top), x0 = x, y0 = y, colors = colors,
        kind = kind, over = ctx.over, box = { left, top, right, y } }
end

return lib

-- bark: tree trunks in real bark (15 scanned barks: colour, normal, height), lit by the mouse's light, crayon outlines
-- BARK.md (2026-11-08). Two rows of bare trees, each grown by its kind (KINDS: an oak's wide crooked
-- limbs, an elm's vase, a pine's whorls, aspens bare below), every branch wrapped in the bark as a round stem: the
-- bark squeezes toward the edges as it turns away, and its normal map takes the light on top of the
-- stem's own roundness. The barks are CC0 scans from ambientCG (textures/world/bark/bark-NN.jpg,
-- -normal, -height; 512 px). The outline is Nikki's crayon strokes (drawn-stroke.lua).
-- Three looks, to see how much of the photo the drawn world can take:
--   photo   the bark as photographed
--   tinted  the bark's light and dark in the tree's own colour (one colour, the photo's grain)
--   relief  a flat colour; only the bark's bumps and cracks take the light (the craft-table look)
-- keys:
--   v the look: photo / tinted / relief      p painted: the light in a few steps / smooth
--   o outlines on / off      c light: sun / candle / moon      f the light follows the mouse / stays
--   d bark detail (how strongly the bumps take the light): flat / soft / normal / deep
--   s the bark's size: small / middle / big      g what the shader sees: off / normals / light alone
--   e the eyes on / off (branch scars from photos: aspens and the birch have several, other trees now and then)
--   m Mipo eyes instead of the scars (the Mipos' own eye drawings, a round pupil), in the same places
-- the panel's 'organic' slider: 0 straight, even branches, 1 as tuned (slow turns, collars, bumpy edges), 2 wild
local s = {}

local STROKE = love.filesystem.load('scripts/spikes/drawn-stroke.lua')()

-- the two rows' ground lines (world y) and where they start; trunks every STEP
local ROWS = { { ground = 0, x = -3120, count = 9 }, { ground = 1750, x = -3120, count = 9 } }
local STEP = 780
local LOOKS = { 'photo', 'tinted', 'relief' }
local DETAILS = { { 'flat', 0 }, { 'soft', 0.6 }, { 'normal', 1.1 }, { 'deep', 2 } }
local SIZES = { { 'small', 220 }, { 'middle', 340 }, { 'big', 520 } } -- world units per bark picture's width
local LIGHTS = {
    { name = 'sun', colour = { 1.0, 0.95, 0.86 }, ambient = { 0.36, 0.38, 0.44 }, wall = { 0.9, 0.86, 0.76 },
        ground = { 0.55, 0.47, 0.34 } },
    { name = 'candle', colour = { 1.0, 0.66, 0.34 }, ambient = { 0.17, 0.14, 0.16 }, wall = { 0.5, 0.39, 0.32 },
        ground = { 0.33, 0.25, 0.18 } },
    { name = 'moon', colour = { 0.62, 0.72, 1.0 }, ambient = { 0.1, 0.12, 0.2 }, wall = { 0.27, 0.3, 0.4 },
        ground = { 0.17, 0.18, 0.24 } },
}
local DEBUGS = { 'off', 'normals', 'light alone' }

-- The eyes: branch scars from photos (Wikimedia Commons, CC0: textures/world/bark/bark-eyes.png, BARK.md),
-- cells side by side, each eye's white made 1 so it multiplies into any bark: 1 the aspen eye, 2 the
-- birch's big scar, 3 its small one; 4-10 the Mipo eyes (eye-01..07, outline in ink, a round pupil), for
-- m. EYE_CELL: a cell's height over its width.
local EYE_CELLS = 10
local MIPO_EYE_CELLS = { 4, 10 }
local EYE_CELL = 320 / 512
local MAX_EYES = 6
local eyeAtlas

-- How each kind grows (the L-system idea: every branch makes side branches by its kind's rules, those make
-- their own, down to twigs), seen from the side, in world units:
--   trunk     length, width at the foot, roots flaring (wider at the very bottom), how far it wanders
--   fork      the trunk ends in this many limbs (an oak, an elm's vase), spread between them, their length;
--             none: the trunk runs on to the top (a pine, a poplar, an aspen)
--   kids      side branches per branch (min, max), from how far along (the trunk's own: trunkKids, bare below
--             trunkStart: aspens and birches drop their lower branches, the eyes are where they were)
--   spread    angle from the parent (min, max, radians), len a child's length over its parent's, cone: shorter
--             toward the top (a pine), width a child's width over its parent's where it starts
--   depth     how many times branches branch; up: how much a branch turns toward the sky, droop: toward the
--             ground (more on thinner ones: weeping twigs), wander: crookedness per step
local KINDS = {
    oak = { trunk = 560, w = 250, flare = 0.7, trunkWander = 0.08, fork = { 3, 0.55, 0.85 },
        trunkKids = { 1, 2 }, trunkStart = 0.45, kids = { 2, 3 }, start = 0.25, spread = { 0.55, 1.05 },
        len = 0.62, width = 0.55, depth = 4, up = 0.03, droop = 0.03, wander = 0.32 },
    elm = { trunk = 480, w = 190, flare = 0.4, trunkWander = 0.05, fork = { 4, 0.2, 1.3 },
        trunkKids = { 0, 1 }, trunkStart = 0.5, kids = { 2, 2 }, start = 0.35, spread = { 0.35, 0.6 },
        len = 0.55, width = 0.55, depth = 4, up = 0.035, droop = 0.05, wander = 0.14 },
    beech = { trunk = 620, w = 190, flare = 0.55, trunkWander = 0.04, fork = { 2, 0.5, 0.95 },
        trunkKids = { 1, 2 }, trunkStart = 0.5, kids = { 3, 3 }, start = 0.25, spread = { 0.5, 0.85 },
        len = 0.55, width = 0.5, depth = 4, up = 0.06, droop = 0.02, wander = 0.12 },
    plane = { trunk = 580, w = 180, flare = 0.35, trunkWander = 0.1, fork = { 3, 0.65, 0.85 },
        trunkKids = { 1, 1 }, trunkStart = 0.55, kids = { 2, 3 }, start = 0.25, spread = { 0.6, 1.1 },
        len = 0.58, width = 0.52, depth = 4, up = 0.02, droop = 0.03, wander = 0.38 },
    olive = { trunk = 380, w = 260, flare = 0.5, trunkWander = 0.35, fork = { 3, 0.8, 0.95 },
        trunkKids = { 0, 1 }, trunkStart = 0.5, kids = { 2, 3 }, start = 0.25, spread = { 0.6, 1.15 },
        len = 0.52, width = 0.5, depth = 3, up = 0.02, droop = 0.05, wander = 0.42 },
    pine = { trunk = 1450, w = 170, flare = 0.3, trunkWander = 0.02, trunkKids = { 14, 16 }, trunkStart = 0.35,
        kids = { 4, 5 }, start = 0.15, spread = { 0.6, 0.9 }, firstSpread = { 1.3, 1.55 }, len = 0.4, cone = true,
        width = 0.35, depth = 2, up = 0.0, droop = 0.025, wander = 0.08 },
    poplar = { trunk = 1450, w = 140, flare = 0.2, trunkWander = 0.03, trunkKids = { 11, 13 }, trunkStart = 0.22,
        kids = { 1, 2 }, start = 0.3, spread = { 0.2, 0.35 }, len = 0.42, cone = true, coneTop = 0.55,
        width = 0.4, depth = 2, up = 0.1, droop = 0.0, wander = 0.08 },
    aspen = { trunk = 1400, w = 150, flare = 0.15, trunkWander = 0.03, trunkKids = { 8, 10 }, trunkStart = 0.55,
        kids = { 2, 3 }, start = 0.3, spread = { 0.45, 0.8 }, len = 0.5, cone = true, coneTop = 0.6,
        width = 0.4, depth = 3, up = 0.1, droop = 0.0, wander = 0.15 },
    birch = { trunk = 1350, w = 170, flare = 0.3, trunkWander = 0.04, trunkKids = { 7, 9 }, trunkStart = 0.45,
        kids = { 2, 3 }, start = 0.3, spread = { 0.55, 0.9 }, len = 0.42, cone = true, coneTop = 0.45,
        width = 0.38, depth = 3, up = 0.04, droop = 0.16, wander = 0.15 },
}

-- The trees: which bark, a name for it, how it grows (KINDS), its own lean, and the eyes (how many
-- branch-scar eyes, else one tree in three gets one; which kinds, the eye cells 1-3). tint: the colour for
-- tinted and relief, picked from the bark's photo; mirrored: a photo that doesn't tile, repeated
-- mirror-wise. size scales the whole tree (an old one low and wide).
local TREES = {
    { bark = 'aspen-01', name = 'aspen', kind = 'aspen', lean = -0.04, eyes = 5, kinds = { 1, 1, 1, 2 },
        mirrored = true, tint = { 0.88, 0.88, 0.84 } },
    { bark = '01', name = 'oak', kind = 'oak', lean = 0.03, tint = { 0.42, 0.4, 0.37 } },
    { bark = '02', name = 'elm', kind = 'elm', lean = 0.02, tint = { 0.52, 0.45, 0.35 } },
    { bark = '03', name = 'smooth brown', kind = 'beech', lean = -0.05, tint = { 0.55, 0.42, 0.3 } },
    { bark = '04', name = 'pine', kind = 'pine', lean = 0.0, tint = { 0.6, 0.5, 0.47 } },
    { bark = '06', name = 'lichen', kind = 'oak', lean = 0.07, size = 0.9, tint = { 0.55, 0.56, 0.58 } },
    { bark = '07', name = 'cracked', kind = 'elm', lean = -0.06, tint = { 0.66, 0.66, 0.5 } },
    { bark = '08', name = 'olive', kind = 'olive', lean = 0.05, tint = { 0.56, 0.5, 0.28 } },
    { bark = '09', name = 'plane', kind = 'plane', lean = -0.03, tint = { 0.8, 0.8, 0.66 } },
    { bark = 'birch-01', name = 'birch', kind = 'birch', lean = 0.05, eyes = 3, kinds = { 2, 3 },
        mirrored = true, tint = { 0.9, 0.89, 0.86 } },
    { bark = 'aspen-01', name = 'aspen', kind = 'aspen', lean = 0.03, eyes = 4, kinds = { 1, 1, 3 },
        mirrored = true, size = 0.9, tint = { 0.86, 0.87, 0.84 } },
    { bark = '10', name = 'beech', kind = 'beech', lean = 0.0, tint = { 0.58, 0.6, 0.53 } },
    { bark = '11', name = 'grey', kind = 'poplar', lean = 0.04, tint = { 0.62, 0.64, 0.6 } },
    { bark = '12', name = 'cork', kind = 'olive', lean = -0.04, size = 1.15, tint = { 0.56, 0.45, 0.28 } },
    { bark = '13', name = 'mossy', kind = 'oak', lean = -0.02, tint = { 0.47, 0.5, 0.33 } },
    { bark = '14', name = 'red', kind = 'pine', lean = -0.03, size = 0.95, tint = { 0.5, 0.33, 0.26 } },
    { bark = '15', name = 'striped', kind = 'beech', lean = 0.05, tint = { 0.55, 0.47, 0.33 } },
    { bark = '16', name = 'old mossy', kind = 'oak', lean = -0.05, size = 0.8, tint = { 0.4, 0.4, 0.3 } },
}

local function lab()
    state.barkSpike = state.barkSpike or { look = 1, painted = false, outlines = true, light = 1, frozen = false,
        detail = 3, size = 2, debug = 1, lx = 0, ly = -600, lightUp = 450 }
    if state.barkSpike.eyes == nil then state.barkSpike.eyes = true end -- added later: a live state lacks it
    state.barkSpike.organic = state.barkSpike.organic or 1
    return state.barkSpike
end

---------------------------------------------------------------- the barks

local barks = {}
local function barkOf(id, mirrored)
    if barks[id] then return barks[id] end
    local function load(path)
        local image = love.graphics.newImage(path, { mipmaps = true })
        local wrap = mirrored and 'mirroredrepeat' or 'repeat'
        image:setWrap(wrap, wrap)
        image:setMipmapFilter('linear')
        image:setFilter('linear', 'linear', 8)
        return image
    end
    local base = 'textures/world/bark/' .. (id:match('^%d') and ('bark-' .. id) or id)
    local b = { colour = load(base .. '.jpg'), normal = load(base .. '-normal.jpg'),
        height = load(base .. '-height.jpg') }
    -- its average brightness, for tinted (every bark as bright as its tint, whatever the photo's exposure)
    local data = love.image.newImageData(base .. '.jpg')
    local w, h = data:getDimensions()
    local sum, n = 0, 0
    for y = 0, h - 1, 16 do
        for x = 0, w - 1, 16 do
            local r, g, bl = data:getPixel(x, y)
            sum = sum + r * 0.3 + g * 0.59 + bl * 0.11
            n = n + 1
        end
    end
    b.meanLum = sum / n
    b.aspect = h / w
    barks[id] = b
    return b
end

---------------------------------------------------------------- the shader

-- A stem is a strip along its middle line. Per vertex: Across (-1 left edge .. 1 right edge, the stem's
-- radius there) and Frame (the way up the stem, x y; how far up it, along the line; a seed that turns
-- the bark round so neighbours differ). The fragment turns across into the angle round the stem
-- (asin), so the bark squeezes toward the edges and the stem's normal leans out there; the bark's
-- normal map tilts that normal, the light at the mouse lights it.
local barkShader = love.graphics.newShader([[
    attribute vec2 Across;
    attribute vec4 Frame;
    varying vec2 vAcross;
    varying vec4 vFrame;
    varying vec2 vWorld;
    vec4 position(mat4 transform_projection, vec4 vertex_position) {
        vAcross = Across;
        vFrame = Frame;
        vWorld = vertex_position.xy;
        return transform_projection * vertex_position;
    }
]], [[
    varying vec2 vAcross;
    varying vec4 vFrame;
    varying vec2 vWorld;
    uniform Image normalMap;
    uniform Image heightMap;
    uniform float barkWidth;   // world units per bark picture's width
    uniform float aspect;      // the picture's height / width
    uniform vec3 lightPos;     // world x, y, and how far in front of the trees
    uniform vec3 lightColour;
    uniform vec3 ambient;
    uniform float detail;
    uniform int look;          // 0 photo, 1 tinted, 2 relief
    uniform vec3 tint;
    uniform float meanLum;
    uniform float bands;       // 0 smooth, else the light in this many steps
    uniform int debugView;     // 0 off, 1 normals, 2 the light alone
    uniform Image eyeMap;      // the eyes, side by side
    uniform vec4 eyes[6];      // round the stem (angle), up it, how wide, which
    uniform int eyeCount;
    uniform float eyeCell;     // a cell's height / width
    uniform float eyeCells;    // how many cells
    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        float a = clamp(vAcross.x, -0.995, 0.995);
        float th = asin(a);
        float r = vAcross.y;
        vec2 uv = vec2(th * r / barkWidth + vFrame.w, -vFrame.z / (barkWidth * aspect));
        vec3 albedo = Texel(tex, uv).rgb;
        vec3 nm = Texel(normalMap, uv).rgb * 2.0 - 1.0;
        float h = Texel(heightMap, uv).r;
        // the stem's frame: across (round the stem), along (up it), out (toward us)
        vec3 N0 = vec3(sin(th), 0.0, cos(th));
        vec3 T = vec3(cos(th), 0.0, -sin(th));
        vec3 N = normalize(T * nm.x * detail + vec3(0.0, 1.0, 0.0) * nm.y * detail + N0 * max(nm.z, 0.3));
        // into the world: across is the strip's right, along its way up
        vec2 up = vFrame.xy;
        vec2 right = vec2(-up.y, up.x);
        vec3 Nw = vec3(right * N.x + up * N.y, N.z);
        vec3 L = normalize(vec3(lightPos.xy - vWorld, lightPos.z));
        float d = max(dot(Nw, L), 0.0);
        if (bands > 0.5) d = floor(d * bands + 0.5) / bands;
        // the cracks: darker deep in, more so in relief (no photo to carry them)
        float crack = smoothstep(0.0, 0.55, h);
        vec3 col;
        if (look == 0) {
            col = albedo;
            col *= mix(1.0, 0.75 + 0.25 * crack, detail * 0.4);
        } else if (look == 1) {
            float lum = dot(albedo, vec3(0.3, 0.59, 0.11));
            col = tint * clamp(lum / max(meanLum, 0.05), 0.0, 1.8);
        } else {
            col = tint * mix(1.0, 0.55 + 0.45 * crack, min(detail, 1.5) * 0.6);
        }
        // the eyes: each in the stem's own frame, so one round the side is squeezed like the bark
        for (int i = 0; i < 6; ++i) {
            if (i >= eyeCount) break;
            vec4 e = eyes[i];
            float ex = (th - e.x) * r / e.z;
            float ey = (vFrame.z - e.y) / (e.z * eyeCell);
            if (abs(ex) < 0.5 && abs(ey) < 0.5) {
                vec4 t = Texel(eyeMap, vec2((e.w + ex + 0.5) / eyeCells, 0.5 - ey));
                col *= mix(vec3(1.0), t.rgb, t.a);
            }
        }
        vec3 light = ambient + lightColour * d * 1.1;
        if (debugView == 1) return vec4(Nw * 0.5 + 0.5, 1.0) * color.a;
        if (debugView == 2) return vec4(light * 0.8, 1.0) * color.a;
        return vec4(col * light, 1.0) * color.a;
    }
]])

---------------------------------------------------------------- the trees

local MESH_FORMAT = {
    { 'VertexPosition', 'float', 2 },
    { 'Across', 'float', 2 },
    { 'Frame', 'float', 4 },
}
local STEP_LEN = 26 -- world units per step along a branch
local MAX_BRANCHES = 400
-- how organic (the panel's slider, 0..2): how much branches turn and wander, their collars, their edges'
-- bumps; 0 straight and even, 1 as tuned, 2 wild. Set before a build.
local organic = 1
local TWIG = 5 -- thinnest a branch gets (world units)

-- turn angle a toward target by k of the way (the short way round)
local function turnToward(a, target, k)
    local d = math.atan2(math.sin(target - a), math.cos(target - a))
    return a + d * k
end

-- One branch: walked from (x, y) at angle a for len, w0 to w1 wide, turning toward the sky (up) or the
-- ground (droop, more on thin ones) and wandering a little each step; then its side branches and, for a
-- trunk that forks, its limbs. Every branch goes into out: its middle line (points with width and length
-- so far) and depth.
local function grow(k, rng, out, x, y, a, len, w0, w1, depth, isTrunk, scale)
    if #out >= MAX_BRANCHES then return end
    local n = math.max(3, math.floor(len / STEP_LEN))
    local wander = (isTrunk and k.trunkWander or k.wander) * organic
    local thin = 1 - math.min(1, w0 / (k.w * scale))
    -- a side branch starts a little inside its parent, so its collar grows out of the wood
    if not isTrunk then
        x, y = x - math.cos(a) * w0 * 0.4 * math.min(1, organic), y - math.sin(a) * w0 * 0.4 * math.min(1, organic)
    end
    -- the walk: it turns slowly (smooth noise along its length, not a kink per step), toward the sky or the
    -- ground
    local seed = rng:random() * 1000
    local line = { { x, y } }
    local step = len / n
    for i = 1, n do
        local along = (i - 1) * step
        local bend = (love.math.noise(seed, along / 220) - 0.5) * 2.2 + (rng:random() - 0.5) * 0.25
        if organic == 0 then bend = 0 end
        a = a + bend * wander
        a = turnToward(a, -math.pi / 2, k.up * (isTrunk and 3 or 1))
        if not isTrunk then a = turnToward(a, math.pi / 2, k.droop * thin) end
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
    -- the points: way, length so far, width; the width eases off (thick for longer, then thin), the roots
    -- flare, a side branch swells into a collar where it leaves its parent, and each edge has its own slow
    -- bumps (a branch is never quite even, nor mirror-alike)
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
    for _, p in ipairs(pts) do
        local u = p.along / total
        local w = w0 + (w1 - w0) * u ^ 0.75
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
    if depth >= k.depth or w1 <= TWIG then return end
    -- side branches, alternating sides, spaced along it (the trunk's: bare below trunkStart)
    local range = isTrunk and k.trunkKids or k.kids
    local count = rng:random(range[1], range[2])
    local from = isTrunk and k.trunkStart or k.start
    local side = rng:random() < 0.5 and 1 or -1
    for c = 1, count do
        local t = from + (1 - from) * (c - 1 + 0.3 + rng:random() * 0.5) / count
        if not k.fork and isTrunk then t = math.min(t, 0.96) end
        local p = pts[math.floor(t * n) + 1]
        local spread = (isTrunk and k.firstSpread) or k.spread
        local ca = p.a + side * (spread[1] + (spread[2] - spread[1]) * rng:random())
        local clen = len * k.len * (0.8 + 0.4 * rng:random())
        if k.cone and isTrunk then clen = clen * (1 - t * (k.coneTop or 0.85)) end -- shorter toward the top
        local cw = p.w * k.width
        grow(k, rng, out, p.x, p.y, ca, clen, cw, math.max(TWIG, cw * 0.35), depth + 1, false, scale)
        side = -side
    end
    -- a trunk that forks: its limbs from the top, fanned out
    if isTrunk and k.fork then
        local nf, fan, flen = k.fork[1], k.fork[2], k.fork[3]
        -- from a step below the top, so the limbs overlap the trunk's end (no notch where they meet)
        local top = pts[math.max(1, #pts - 1)]
        x, y = top.x, top.y
        for f = 1, nf do
            local fa = a + (f - (nf + 1) / 2) * fan + (rng:random() - 0.5) * 0.2
            local fw = w1 * (0.75 + 0.1 * rng:random())
            grow(k, rng, out, x, y, fa, len * flen * (0.85 + 0.3 * rng:random()), fw, math.max(TWIG, fw * 0.3),
                depth + 1, false, scale)
        end
    end
end

-- a branch's strip as triangles into verts (two vertices per point, its way up and its length so far), its
-- edges as lines for the outline (no line across its end: a trunk's limbs grow out of it there)
local function addStrip(pts, seed, verts, lines, trim)
    local left, right = {}, {}
    local prevL, prevR
    for i, p in ipairs(pts) do
        local a, b = pts[math.max(1, i - 1)], pts[math.min(#pts, i + 1)]
        local ux, uy = b.x - a.x, b.y - a.y
        local len = math.sqrt(ux * ux + uy * uy)
        ux, uy = ux / len, uy / len
        local rx, ry = -uy, ux -- the strip's right (as the shader's)
        local hl, hr = (p.wl or p.w) / 2, (p.wr or p.w) / 2
        local half = (hl + hr) / 2
        local L = { p.x - rx * hl, p.y - ry * hl, -1, half, ux, uy, p.along, seed }
        local R = { p.x + rx * hr, p.y + ry * hr, 1, half, ux, uy, p.along, seed }
        if prevL then
            verts[#verts + 1] = prevL; verts[#verts + 1] = prevR; verts[#verts + 1] = L
            verts[#verts + 1] = prevR; verts[#verts + 1] = R; verts[#verts + 1] = L
        end
        prevL, prevR = L, R
        left[#left + 1] = { L[1], L[2] }
        right[#right + 1] = { R[1], R[2] }
    end
    -- the crayon line as thick as suits the branch (a twig's thinner, the thinnest none)
    local w = math.min(13, pts[1].w * 0.1)
    for _ = 1, math.min(trim or 0, #left - 2) do
        left[#left] = nil
        right[#right] = nil
    end
    if w >= 2.5 then
        lines[#lines + 1] = { pts = left, width = w }
        lines[#lines + 1] = { pts = right, width = w }
    end
end

-- every tree grown and made into meshes once: one part per depth (all its branches in one mesh, one
-- outline), drawn deepest first, so twigs go behind their branches and branches behind the trunk
local built
local function build(howOrganic)
    organic = howOrganic or 1
    built = { organic = organic }
    local i = 0
    for _, row in ipairs(ROWS) do
        for col = 1, row.count do
            i = i + 1
            local t = TREES[i]
            if not t then break end
            local k = KINDS[t.kind]
            local scale = t.size or 1
            local x0 = row.x + (col - 1) * STEP
            local rng = love.math.newRandomGenerator(i * 7919 + 13)
            local branches = {}
            local trunkLen = k.trunk * scale
            grow(k, rng, branches, x0, row.ground, -math.pi / 2 + t.lean, trunkLen, k.w * scale,
                k.w * scale * (k.fork and 0.7 or 0.12), 0, true, scale)
            local byDepth, maxDepth = {}, 0
            for b, br in ipairs(branches) do
                local d = br.depth
                maxDepth = math.max(maxDepth, d)
                byDepth[d] = byDepth[d] or { verts = {}, lines = {} }
                addStrip(br.pts, i * 0.61 + b * 0.173, byDepth[d].verts, byDepth[d].lines, br.outlineTrim)
            end
            local tree = { def = t, x = x0, ground = row.ground, parts = {}, branchCount = #branches }
            for d = maxDepth, 0, -1 do
                local g = byDepth[d]
                if g and #g.verts >= 3 then
                    tree.parts[#tree.parts + 1] = {
                        mesh = love.graphics.newMesh(MESH_FORMAT, g.verts, 'triangles', 'static'),
                        strokes = STROKE.meshes(g.lines, 0.6, 0, true), isStem = d == 0 }
                end
            end
            -- its eyes, the same every time: up the trunk (the bare part, where branches were), round it
            -- either way, about as wide as the trunk there (laid round the curve, they show narrower)
            local trunk = branches[1].pts
            local count = t.eyes or (rng:random() < 0.35 and 1 or 0)
            local top = k.fork and 0.9 or (k.trunkStart + 0.1)
            tree.eyes, tree.mipoEyes = {}, {}
            for e = 1, math.min(count, MAX_EYES) do
                local u = 0.1 + (top - 0.1) * (e - 1 + rng:random()) / math.max(1, count)
                local p = trunk[math.floor(u * (#trunk - 1)) + 1]
                local kinds = t.kinds or { 1, 2, 3 }
                local eye = { (rng:random() - 0.5) * 1.7, p.along, p.w * (0.7 + 0.8 * rng:random()),
                    kinds[rng:random(1, #kinds)] - 1 }
                tree.eyes[#tree.eyes + 1] = eye
                -- the same eye as a Mipo's (m): a little smaller, they're rounder than the scars
                tree.mipoEyes[#tree.mipoEyes + 1] = { eye[1], eye[2], eye[3] * 0.8,
                    rng:random(MIPO_EYE_CELLS[1], MIPO_EYE_CELLS[2]) - 1 }
            end
            built[#built + 1] = tree
        end
    end
end

---------------------------------------------------------------- the scene

local function overPanel()
    local r = lab().panelRect
    if not r or r.folded then return false end
    local mx, my = love.mouse.getPosition()
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

function s.onStart()
    worldState.paused = false
    cam:setScale(0.135)
    cam:setTranslation(0, 200)
    build(lab().organic)
end

function s.onUnload()
    barks = {}
    eyeAtlas = nil
    built = nil
end

function s.update()
    local c = lab()
    if not c.frozen and not overPanel() then c.lx, c.ly = mouseWorldPos() end
end

function s.onKeyPress(key)
    local c = lab()
    if key == 'v' then c.look = c.look % #LOOKS + 1
    elseif key == 'p' then c.painted = not c.painted
    elseif key == 'o' then c.outlines = not c.outlines
    elseif key == 'c' then c.light = c.light % #LIGHTS + 1
    elseif key == 'f' then c.frozen = not c.frozen
    elseif key == 'd' then c.detail = c.detail % #DETAILS + 1
    elseif key == 's' then c.size = c.size % #SIZES + 1
    elseif key == 'g' then c.debug = c.debug % #DEBUGS + 1
    elseif key == 'e' then c.eyes = not c.eyes
    elseif key == 'm' then c.mipoEyes = not c.mipoEyes
    end
end

-- the paper wall, the ground under each row
function s.drawBelow()
    local L = LIGHTS[lab().light]
    local x0, y0 = cam:getWorldCoordinates(0, 0)
    local x1, y1 = cam:getWorldCoordinates(love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(L.wall[1], L.wall[2], L.wall[3], 1)
    love.graphics.rectangle('fill', x0, y0, x1 - x0, y1 - y0)
    for _, row in ipairs(ROWS) do
        love.graphics.setColor(L.ground[1], L.ground[2], L.ground[3], 1)
        love.graphics.rectangle('fill', x0, row.ground - 10, x1 - x0, 130)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function label(text, x, y)
    local font = love.graphics.getFont()
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(text, x - font:getWidth(text) * 1.25 + 3, y + 3, 0, 2.5, 2.5)
    love.graphics.setColor(1, 0.97, 0.9, 1)
    love.graphics.print(text, x - font:getWidth(text) * 1.25, y, 0, 2.5, 2.5)
end

function s.draw()
    local c = lab()
    -- a regrow takes ~0.1 s: while the slider moves, wait until it rests a moment
    local now = love.timer.getTime()
    if c.organic ~= c.organicSeen then c.organicSeen, c.organicAt = c.organic, now end
    if not built or (built.organic ~= c.organic and now - (c.organicAt or 0) > 0.15) then build(c.organic) end
    local L = LIGHTS[c.light]
    barkShader:send('lightPos', { c.lx, c.ly, c.lightUp })
    barkShader:send('lightColour', L.colour)
    barkShader:send('ambient', L.ambient)
    barkShader:send('detail', DETAILS[c.detail][2])
    barkShader:send('look', c.look - 1)
    barkShader:send('bands', c.painted and 4 or 0)
    barkShader:send('debugView', c.debug - 1)
    barkShader:send('barkWidth', SIZES[c.size][2])
    if not eyeAtlas then
        -- no mipmaps: it's looked up only inside an eye's box, and at the box's edge the GPU picks a far
        -- too blurred level (a faint box round every eye)
        eyeAtlas = love.graphics.newImage('textures/world/bark/bark-eyes.png')
        eyeAtlas:setFilter('linear', 'linear')
    end
    barkShader:send('eyeMap', eyeAtlas)
    barkShader:send('eyeCell', EYE_CELL)
    barkShader:send('eyeCells', EYE_CELLS)
    for _, tree in ipairs(built) do
        local b = barkOf(tree.def.bark, tree.def.mirrored)
        barkShader:send('normalMap', b.normal)
        barkShader:send('heightMap', b.height)
        barkShader:send('aspect', b.aspect)
        barkShader:send('meanLum', b.meanLum)
        barkShader:send('tint', tree.def.tint)
        for _, part in ipairs(tree.parts) do
            love.graphics.setShader(barkShader)
            local eyeCount = (part.isStem and c.eyes) and #tree.eyes or 0
            barkShader:send('eyeCount', eyeCount)
            if eyeCount > 0 then barkShader:send('eyes', unpack(c.mipoEyes and tree.mipoEyes or tree.eyes)) end
            love.graphics.setColor(1, 1, 1, 1)
            part.mesh:setTexture(b.colour)
            love.graphics.draw(part.mesh)
            love.graphics.setShader()
            if c.outlines then
                love.graphics.setColor(0.13, 0.1, 0.09, 1)
                for _, mesh in ipairs(part.strokes) do love.graphics.draw(mesh) end
            end
        end
    end
    for _, tree in ipairs(built) do
        local id = tree.def.bark
        label(id:match('^%d') and (id .. ' ' .. tree.def.name) or tree.def.name, tree.x, tree.ground + 30)
    end
    -- the light: a small sun where the mouse is
    love.graphics.setColor(L.colour[1], L.colour[2], L.colour[3], 0.9)
    love.graphics.circle('fill', c.lx, c.ly, 28)
    love.graphics.setColor(1, 1, 1, 1)
end

-- the panel: the keys as buttons and sliders
local PANEL = { w = 330, row = 36, pad = 6 }
function s.drawUI()
    local c = lab()
    ui.startFrame()
    local sw, sh = love.graphics.getDimensions()
    local w, h = PANEL.w, PANEL.row * 8 + 34
    local x0, y0 = sw - w - 12, math.max(12, sh - h - 12)
    c.panelRect = { x0, y0, w, h, folded = ui.isPanelFolded('•• bark ••') }
    local half = (w - PANEL.pad * 3) / 2
    ui.panel(x0, y0, w, h, '•• bark ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = 0, startX = x0 + PANEL.pad, startY = y0 + 28 })
        local function row() return ui.nextLayoutPosition(layout, w - PANEL.pad * 2, PANEL.row) end
        local function cycle(x, y, text) return ui.button(x, y, half, text, PANEL.row - 6) end
        local function check(x, y, key, text)
            local clicked, v = ui.checkbox(x, y, c[key], text)
            if clicked then c[key] = v end
        end
        local x, y = row()
        if cycle(x, y, 'look: ' .. LOOKS[c.look]) then c.look = c.look % #LOOKS + 1 end
        if cycle(x + half + PANEL.pad, y, 'light: ' .. LIGHTS[c.light].name) then c.light = c.light % #LIGHTS + 1 end
        x, y = row()
        if cycle(x, y, 'detail: ' .. DETAILS[c.detail][1]) then c.detail = c.detail % #DETAILS + 1 end
        if cycle(x + half + PANEL.pad, y, 'size: ' .. SIZES[c.size][1]) then c.size = c.size % #SIZES + 1 end
        x, y = row()
        check(x, y, 'painted', 'painted')
        check(x + half + PANEL.pad, y, 'outlines', 'outlines')
        x, y = row()
        check(x, y, 'eyes', 'eyes')
        check(x + half + PANEL.pad, y, 'mipoEyes', 'mipo eyes')
        x, y = row()
        local followClicked, follow = ui.checkbox(x, y, not c.frozen, 'follows mouse')
        if followClicked then c.frozen = not follow end
        if cycle(x + half + PANEL.pad, y, 'sees: ' .. DEBUGS[c.debug]) then c.debug = c.debug % #DEBUGS + 1 end
        x, y = row()
        ui.label(x, y + 4, 'light out')
        local v = ui.sliderWithInput('bark-lightUp', x + 118, y - 2, 120, 60, 1500, c.lightUp, nil, 1)
        if v then c.lightUp = v + 0 end
        x, y = row()
        ui.label(x, y + 4, 'organic')
        local o = ui.sliderWithInput('bark-organic', x + 118, y - 2, 120, 0, 2, c.organic, nil, 0.05)
        if o then c.organic = o + 0 end
    end)
end

return s

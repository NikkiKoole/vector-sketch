-- clouds: a spike for clouds made by a shader: the real kinds, each at its own height.
-- Started from Puppetmaker 2's brushy clouds (../puppet-maker2/assets/world/clouds1.png), then the
-- real ones (the WMO cloud atlas): low clouds under 2 km (cumulus with flat bases all at the same
-- height, stratocumulus in lumpy rows, the cumulonimbus tower with its anvil), middle ones at 2-7 km
-- (altocumulus, a patch of small cells in rows; altostratus, a grey veil the sun shines through),
-- high ones at 5-13 km (cirrus, thin white strands with hooked ends, on faster winds).
-- No pictures: each cloud is one quad and the shader paints it from a seed. Lobes breathe and drift,
-- so a cloud slowly changes shape. Six layers at different distances move with parallax; the far
-- ones are paler (haze) and, like real ones, crowd towards the horizon, which is at eye level:
-- far hills in between. The front layer goes in front of the Mipos. Drag a Mipo up and you go
-- through the low clouds, then see them from above.
--
-- play mode (tab): drag a cloud and fling it; shake it to wring it out (it goes grey and rains);
-- tap one to poof it in two.
-- keys: w the weather (fair, mackerel sky, grey, storm)   c a cumulus at the pointer   g a gust
--       m a Mipo   r new clouds   h the panel

local s = {}

local GROUND_Y = 0
local GROUND_W = 40000
local SUN = { 0.78, 0.17 }   -- on the screen, as parts of width and height
local WIND = 150             -- layer units a second at wind 1
local KM = 1000              -- world units per km of altitude (squeezed: a Mipo is ~600)

-- The kinds. kind is the shader's; base = the flat bottom's height for the heaped ones (all of one
-- kind share it, as real cumulus do: the height where the air's water condenses), alt = a range
-- for the others; hw = half width; aspect = width / height; baseLine = where the bottom is in
-- the cloud's own box (0 middle, 1 bottom); wind = how much faster than the ground wind.
local GENERA = {
    cumulus       = { kind = 0, base = 1.2, hw = { 900, 1600 }, aspect = { 1.4, 2.0 }, baseLine = 0.55, wind = 1 },
    stratocumulus = { kind = 1, base = 1.5, hw = { 2000, 3200 }, aspect = { 3.5, 5 }, baseLine = 0.5, wind = 1 },
    altocumulus   = { kind = 2, alt = { 3.5, 6 }, hw = { 1600, 2800 }, aspect = { 2, 3 }, wind = 1.5 },
    altostratus   = { kind = 3, alt = { 3.5, 6 }, hw = { 4000, 6500 }, aspect = { 5, 8 }, wind = 1.5 },
    cirrus        = { kind = 4, alt = { 8, 12 }, hw = { 2200, 4200 }, aspect = { 4, 7 }, wind = 2.5 },
    cumulonimbus  = { kind = 5, base = 1.2, hw = { 2600, 3400 }, aspect = { 0.8, 0.95 }, baseLine = 0.85, wind = 0.8 },
}

-- how many of each kind per layer
local WEATHERS = {
    { name = 'fair',          mix = { cumulus = 3, cirrus = 1 } },
    { name = 'mackerel sky',  mix = { altocumulus = 2, cirrus = 1, cumulus = 0.7 } },
    { name = 'grey',          mix = { stratocumulus = 2.2, altostratus = 1 } },
    { name = 'storm',         mix = { cumulonimbus = 0.35, cumulus = 1.2, stratocumulus = 1 } },
}

-- far to near; f is the parallax (1 = moves with the world); m = how many (more far away: real
-- clouds bunch up towards the horizon); size a little bigger far away, or they'd be specks
local LAYERS = {
    { f = 0.1,  m = 1.6, size = 1.5 },
    { f = 0.18, m = 1.4, size = 1.3 },
    { f = 0.28, m = 1.2, size = 1.15 },
    { f = 0.42, m = 1.0, size = 1.05 },
    { f = 0.6,  m = 0.8, size = 1.0 },
    { f = 1.1,  m = 0.3, size = 0.8, front = true },
}
local MARGIN = 1.15 -- the box around a layer's camera, in screens (half width)

-- far hills between the cloud layers: the ground far away, at eye level
local HILLS = {
    { f = 0.12, amp = 1300, haze = 0.75, seed = 3.1 },
    { f = 0.3,  amp = 450, haze = 0.55, seed = 8.4 },
    { f = 0.5,  amp = 220,  haze = 0.35, seed = 1.7 },
}

-- growing clouds (CG1): the air, how fast the sky's time runs (x real), the wind; the panel's
-- 'defaults' puts these back
local GROW_DEFAULTS = { groundT = 22, groundRH = 70, aloftRH = 45, lapse = 7.5, lidKm = 3.5, lidK = 4,
    speed = 25, wind = 1, morph = 1, light = 2, cotton = 1 }

local function clouds()
    local b = state.clouds or {}
    state.clouds = b
    b.list = b.list or {}
    b.drops = b.drops or {}
    b.splashes = b.splashes or {}
    b.mipos = b.mipos or {}
    b.time = b.time or 0
    b.gust = b.gust or 0
    b.weather = b.weather or 1
    b.settings = b.settings or {}
    -- Nikki's settings (2026-11-03): no strokes, hairs or grain, strong light
    local defaults = { wind = 1, morph = 1, strokes = 0, hair = 0, grain = 0, light = 2, cotton = 1,
        back = 0.84, front = 1.12, behind = 40, infront = 110, blades = 1 }
    for key, v in pairs(GROW_DEFAULTS) do defaults[key] = v end
    for key, v in pairs(defaults) do
        if b.settings[key] == nil then b.settings[key] = v end
    end
    if b.showPanel == nil then b.showPanel = true end
    b.thermals = b.thermals or {}
    if b.grow == nil then b.grow = true end
    return b
end

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

local function between(range, u) return range[1] + (range[2] - range[1]) * u end

local function groundAt(x)
    return GROUND_Y + 260 * (love.math.noise(x * 0.00012, 1.3) - 0.5) + 70 * (love.math.noise(x * 0.0006, 7.7) - 0.5)
end

---------------------------------------------------------------- the view

local function view()
    local w, h = love.graphics.getDimensions()
    local cx, cy = cam:getWorldCoordinates(w / 2, h / 2)
    return w, h, cx, cy, cam:getScale()
end

-- Each layer has its own camera: it follows the real one by its f (parallax), and zooms by a
-- power of f, so far clouds hardly grow when the camera zooms in on a Mipo, near ones almost
-- like the world. REF is the scene's own zoom. A layer's y = 0 is the ground's height, so the
-- far layers' ground ends up at the middle of the screen: eye level, the horizon.
local REF = 0.25
local function zoomOf(f, scale)
    return REF * (scale / REF) ^ math.min(f, 1) * f
end
local function layerCam(f, cx, cy, scale)
    return cx * f, cy * f, zoomOf(f, scale)
end

-- a cloud's middle on the screen, and its half size there
local function onScreen(c, w, h, cx, cy, scale)
    local lx, ly, k = layerCam(c.f, cx, cy, scale)
    return w / 2 + (c.x - lx) * k, h / 2 + (c.y - ly) * k, c.hw * k, c.hh * k
end

local function worldToScreen(x, y, w, h, cx, cy, scale)
    return w / 2 + (x - cx) * scale, h / 2 + (y - cy) * scale
end

---------------------------------------------------------------- clouds

local function newCloud(layerIndex, genus, x)
    local layer = LAYERS[layerIndex]
    local g = GENERA[genus]
    local rnd = love.math.random
    local c = { layer = layerIndex, f = layer.f, front = layer.front, genus = genus, kind = g.kind,
        x = x, vx = 0, vy = 0, rain = 0, seed = rnd() * 50, baseLine = g.baseLine or 0.35 }
    c.hw = between(g.hw, rnd()) * layer.size
    c.hh = c.hw / between(g.aspect, rnd())
    if g.base then
        -- flat bottoms in a line, a little up and down
        c.y = -(g.base + (rnd() - 0.5) * 0.12) * KM - c.hh * g.baseLine
    else
        c.y = -between(g.alt, rnd()) * KM
    end
    c.homeY = c.y
    if genus == 'cumulonimbus' then c.storm = true end
    return c
end

-- the half width of a layer's box, around its camera; never smaller than at the scene's own zoom,
-- or zooming in would crowd the same clouds into less sky
local function boxOf(f, w, scale)
    local k = math.min(zoomOf(f, scale), zoomOf(f, REF))
    return (w / 2) / k * MARGIN
end

local function fillSky(b)
    b.list = {}
    local w, _, cx, cy, scale = view()
    local rnd = love.math.random
    local weather = WEATHERS[b.weather]
    for i, layer in ipairs(LAYERS) do
        local lx = layerCam(layer.f, cx, cy, scale)
        local hx = boxOf(layer.f, w, scale)
        for genus, per in pairs(weather.mix) do
            local n = per * layer.m
            local count = math.floor(n) + ((rnd() < n % 1) and 1 or 0)
            for j = 1, count do
                local x = lx - hx + (j - 1 + rnd()) / count * 2 * hx
                b.list[#b.list + 1] = newCloud(i, genus, x)
            end
        end
    end
end

-- front-most first
local function sortedFront(b)
    local out = {}
    for i = 1, #b.list do out[i] = b.list[i] end
    table.sort(out, function(p, q) return p.f > q.f end)
    return out
end

local function pickCloud(b, mx, my)
    local w, h, cx, cy, scale = view()
    for _, c in ipairs(sortedFront(b)) do
        local sx, sy, hw, hh = onScreen(c, w, h, cx, cy, scale)
        local qx, qy = (mx - sx) / hw, (my - sy) / hh
        if qx * qx + qy * qy < 0.55 then return c end
    end
end

local function mouseInLayer(c)
    local w, h, cx, cy, scale = view()
    local mx, my = love.mouse.getPosition()
    local lx, ly, k = layerCam(c.f, cx, cy, scale)
    return lx + (mx - w / 2) / k, ly + (my - h / 2) / k
end

local function removeCloud(b, c)
    for i = #b.list, 1, -1 do
        if b.list[i] == c then table.remove(b.list, i) end
    end
end

-- poof: a big cloud parts in two, a small one hops
local function poof(b, c)
    if c.hw < 650 then
        c.vy = c.vy - 500
        return
    end
    removeCloud(b, c)
    for side = -1, 1, 2 do
        local n = newCloud(c.layer, c.genus, c.x + side * c.hw * 0.42)
        n.hw, n.hh = c.hw * 0.66, c.hh * 0.82
        n.y, n.homeY = c.y, c.homeY
        n.vx, n.vy = c.vx + side * 420, c.vy - 120
        n.rain = c.rain * 0.6
        b.list[#b.list + 1] = n
    end
end

---------------------------------------------------------------- the ground and Mipos

local function destroyGround(b)
    if b.ground and not b.ground:isDestroyed() then b.ground:destroy() end
    b.ground = nil
end

local GROUND_STEP = 200
local function buildGround(b)
    destroyGround(b)
    local flat = {}
    for x = -GROUND_W / 2, GROUND_W / 2, GROUND_STEP do
        flat[#flat + 1], flat[#flat + 2] = x, groundAt(x)
    end
    b.ground = love.physics.newBody(world, 0, 0, 'static')
    local fixture = love.physics.newFixture(b.ground, love.physics.newChainShape(false, unpack(flat)))
    fixture:setFriction(0.8)
end

-- The ground a little 2.5D, as in physics-testbed's downhill (renderJoy.lua drawHillGround): the
-- top of the ground seen from a little above, then the side face down, in Nikki's grass patterns
-- over a light grass colour; a row of grass blades at the back (behind the Mipos) and one at the
-- front edge (in front of their feet). And the perspective of scrolling-world's ground plane
-- (src/groundplane.lua: the back edge through a far camera layer, the front through a near one):
-- the back edge is further away, so it's drawn pulled in towards the middle of the view (K_BACK),
-- the front edge nearer, pushed out (K_FRONT); the line the Mipos stand on in between stays. A pan
-- moves the back slower than the front, and from higher up you see more of the top.
-- set each frame from the panel (planeFrom): the depths of the back and front edges, how far
-- behind and in front of the line they are (a little ground even at eye level), the blades' size
local K_BACK, K_FRONT = 0.84, 1.12
local BACK, FRONT = 40, 110
local BLADE_SIZE = 1
local function planeFrom(set)
    K_BACK, K_FRONT = set.back, set.front
    BACK, FRONT, BLADE_SIZE = set.behind, set.infront, set.blades
end
local LIGHT_GRASS = { 0x86 / 255, 0xa5 / 255, 0x42 / 255 }
local DARK_GRASS = { 0x2a / 255, 0x5b / 255, 0x3e / 255 }
local topPattern = love.graphics.newImage('textures/world/grasspattern2.png')
local sidePattern = love.graphics.newImage('textures/world/grasspattern4.png')
topPattern:setWrap('repeat', 'repeat')
sidePattern:setWrap('repeat', 'repeat')
local blades = love.graphics.newImage(grass.ATLAS)
local BLADES = grass.QUADS -- the atlas's quads and base pivots (src/grass.lua)
local bladeQuads = {}
for i, q in ipairs(BLADES) do bladeQuads[i] = love.graphics.newQuad(q[1], q[2], q[3], q[4], blades:getDimensions()) end
local backBlades = love.graphics.newSpriteBatch(blades, 1000, 'stream')
local frontBlades = love.graphics.newSpriteBatch(blades, 1000, 'stream')

local STRIP_MAX = 200
local topMesh = love.graphics.newMesh(STRIP_MAX * 2, 'strip', 'stream')
local sideMesh = love.graphics.newMesh(STRIP_MAX * 2, 'strip', 'stream')
local BAND_DEPTH = 700             -- how deep the top is, for its pattern (foreshortened by the strip)

-- a point at depth k (1 = the line the Mipos stand on), as it shows through the real camera
local function project(x, y, k, cx, cy)
    return cx + (x - cx) * k, cy + (y - cy) * k
end

-- the x's to make the ground at: wide enough that the pulled-in back edge still fills the view
local function groundXs(k)
    local w, _, cx, _, scale = view()
    local half = w / 2 / scale / k + GROUND_STEP
    local step = math.max(100, 2 * half / (STRIP_MAX - 2))
    return math.floor((cx - half) / step) * step, cx + half, step
end

local function drawGround()
    local _, _, cx, cy = view()
    local x0, x1, step = groundXs(K_BACK)
    local tw, th = topPattern:getWidth() * 1.6, topPattern:getHeight() * 1.6
    local sw, sh = sidePattern:getWidth() * 1.4, sidePattern:getHeight() * 1.4
    local top, side = {}, {}
    for x = x0, x1, step do
        local y = groundAt(x)
        local bx, by = project(x, y - BACK, K_BACK, cx, cy)
        local fx, fy = project(x, y + FRONT, K_FRONT, cx, cy)
        top[#top + 1] = { bx, by, x / tw, 0, 1, 1, 1, 1 }
        top[#top + 1] = { fx, fy, x / tw, BAND_DEPTH / th, 1, 1, 1, 1 }
        side[#side + 1] = { fx, fy, fx / sw, fy / sh, 1, 1, 1, 1 }
        side[#side + 1] = { fx, fy + 2600, fx / sw, (fy + 2600) / sh, 1, 1, 1, 1 }
    end
    topMesh:setVertices(top)
    topMesh:setDrawRange(1, #top)
    sideMesh:setVertices(side)
    sideMesh:setDrawRange(1, #side)
    -- the side face: a little darker than the top, the pattern twice
    sideMesh:setTexture()
    love.graphics.setColor(LIGHT_GRASS[1] * 0.82, LIGHT_GRASS[2] * 0.85, LIGHT_GRASS[3] * 0.8, 1)
    love.graphics.draw(sideMesh)
    sideMesh:setTexture(sidePattern)
    love.graphics.setColor(DARK_GRASS[1], DARK_GRASS[2], DARK_GRASS[3], 0.55)
    love.graphics.draw(sideMesh)
    love.graphics.setColor(DARK_GRASS[1], DARK_GRASS[2], DARK_GRASS[3], 0.3)
    love.graphics.draw(sideMesh)
    -- the top
    topMesh:setTexture()
    love.graphics.setColor(LIGHT_GRASS[1], LIGHT_GRASS[2], LIGHT_GRASS[3], 1)
    love.graphics.draw(topMesh)
    topMesh:setTexture(topPattern)
    love.graphics.setColor(DARK_GRASS[1], DARK_GRASS[2], DARK_GRASS[3], 0.8)
    love.graphics.draw(topMesh)
    love.graphics.setColor(1, 1, 1, 1)
end

-- a row of blades along the ground at depth k, yOff from the line; their height and drawing from
-- noise on x, so they stay put; further back is smaller
local function bladeRow(batch, k, yOff, seedP, size, time)
    local _, _, cx, cy = view()
    local x0, x1, step = groundXs(k)
    step = math.max(55, step / 3)
    batch:clear()
    for x = math.floor(x0 / step) * step, x1, step do
        local px, py = project(x, groundAt(x) + yOff, k, cx, cy)
        local hh = 0.3 + love.math.noise(x / 1000, seedP) * 0.9
        local i = math.min(#BLADES, 1 + math.floor(love.math.noise(x * 0.37, seedP * 3.1) * #BLADES))
        local q = BLADES[i]
        local ang = math.sin(hh * 9) * 0.1 + math.sin(time * 1.3 + x * 0.003) * 0.06
        local sz = size * k * BLADE_SIZE
        batch:add(bladeQuads[i], px, py, ang, sz, sz * hh, q[5], q[6])
    end
    love.graphics.draw(batch)
end

local function aliveMipos(b) return mipoKit.alive(b.mipos) end -- src/mipo-kit.lua

local function spawnMipo(b, x, y) mipoKit.spawn(b.mipos, x, y) end -- src/mipo-kit.lua

---------------------------------------------------------------- shaders

local skyShader = love.graphics.newShader([[
uniform vec2 sunPos;     // screen pixels
uniform float horizonY;  // screen pixels: eye level

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    float hgt = clamp((horizonY - sc.y) / love_ScreenSize.y, -0.5, 1.5);
    vec3 hor = vec3(0.937, 0.933, 0.737);   // Puppetmaker 2's sky: #efeebc at the horizon
    vec3 top = vec3(0.380, 0.816, 0.812);   // ... to #61d0cf
    vec3 col = mix(hor, top, smoothstep(0.0, 0.55, hgt));
    col = mix(col, vec3(0.27, 0.62, 0.80), smoothstep(0.45, 1.3, hgt) * 0.7);
    float d = length(sc - sunPos) / love_ScreenSize.y;
    col += vec3(1.0, 0.93, 0.75) * (exp(-d * 6.0) * 0.30 + exp(-d * 30.0) * 0.25);
    col = mix(col, vec3(1.0, 0.99, 0.92), smoothstep(0.042, 0.036, d));
    return vec4(col, 1.0);
}
]])

-- One cloud on a quad from (-1,-1) to (1,1), y down. Noise and hashes written here (value noise,
-- a fract hash); nothing copied.
local cloudShader = love.graphics.newShader([[
#ifdef GL_ES
precision highp float;
#endif
uniform float seed;
uniform float aspect;    // half width / half height
uniform float kind;      // 0 cumulus, 1 stratocumulus, 2 altocumulus, 3 altostratus, 4 cirrus, 5 cumulonimbus
uniform float baseLine;  // the flat bottom, in the box (y down)
uniform float time;
uniform vec2 sunDir;     // towards the sun, in the cloud's own space (y down)
uniform float sunNear;   // 0..1, how close it is to the sun on the screen
uniform float haze;      // 0 near .. 1 far
uniform vec3 hazeColor;
uniform float rain;      // 0..1, greyer
uniform float strokes;
uniform float grain;
uniform float light;
uniform float alphaMul;
uniform float cotton;    // 0 real clouds .. 1 cotton wool balls
varying vec2 q0;

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    q0 = vertex_position.xy;
    return transform_projection * vertex_position;
}
#endif

#ifdef PIXEL
float h11(float n) { return fract(sin(n * 12.9898 + 4.1414) * 43758.5453); }
float h21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float vn(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x),
               mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
    float s = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        s += a * vn(p);
        p = p * 2.03 + vec2(17.1, 9.2);
        a *= 0.5;
    }
    return s / 0.9375;
}

// cotton wool: soft strands in three wandering directions, broad enough to be fibres, not specks
float wisps(vec2 p) {
    float s = 0.0;
    // short and tangled: the direction turns quickly, the strands are only a little longer than wide
    for (int i = 0; i < 4; i++) {
        float a = float(i) * 1.57 + seed + (vn(p * 3.0 + float(i) * 3.0) - 0.5) * 6.0;
        vec2 d = vec2(cos(a), sin(a));
        vec2 r = vec2(dot(p, d), dot(p, vec2(-d.y, d.x)));
        s += vn(r * vec2(9.0, 22.0) + float(i) * 11.0);
    }
    return s / 4.0;
}

#define LOBES 7

// where lobe i of a heaped cloud sits, and how big it is
void lobe(float fi, out vec2 c, out vec2 r) {
    float A = aspect;
    float u1 = h11(seed + fi * 1.37);
    float u2 = h11(seed * 1.7 + fi * 2.91);
    float u3 = h11(seed * 2.3 + fi * 0.71);
    if (kind < 0.5) {
        // cumulus: three wide lobes along the bottom, smaller ones heaped on top (the cauliflower)
        if (fi < 3.0) {
            c = vec2((fi - 1.0) * 0.45 * A + (u1 - 0.5) * 0.2 * A, 0.18 + 0.08 * u2);
            r = vec2((0.36 + 0.12 * u3) * A, 0.42 + 0.08 * u2);
        } else {
            float up = (fi - 3.0) / 3.0;
            c = vec2((u1 - 0.5) * 0.9 * A * (1.0 - 0.5 * up), -0.15 - 0.45 * up + 0.1 * u2);
            r = vec2((0.26 - 0.08 * up + 0.08 * u3) * A, 0.36 - 0.1 * up + 0.08 * u3);
        }
    } else if (kind < 1.5) {
        // stratocumulus: a row of lumps side by side
        c = vec2((-1.0 + 2.0 * (fi + 0.5) / 7.0) * 0.8 * A + (u1 - 0.5) * 0.12 * A, (u2 - 0.5) * 0.25 - 0.05);
        r = vec2((0.17 + 0.07 * u3) * A, 0.38 + 0.15 * u2);
    } else {
        // cumulonimbus: a tower of lobes, the anvil spread flat on top
        if (fi < 6.0) {
            c = vec2((u1 - 0.5) * 0.22 * A, 0.62 - fi * 0.24);
            r = vec2((0.44 - fi * 0.02 + 0.08 * u3) * A, 0.3 + 0.06 * u2);
        } else {
            c = vec2(0.15 * A, -0.78);
            r = vec2(0.98 * A, 0.17);
        }
    }
}

// the heaped shape: how far inside the nearest lobe (1 in the middle, 0 at the edge)
float heap(vec2 q, vec2 sp, float t) {
    float rag = fbm(vec2(sp.x * 2.0 + t * 0.05, sp.y * 4.5 - t * 0.03)) - 0.5;
    float E = -1.0;
    for (int i = 0; i < LOBES; i++) {
        float fi = float(i);
        vec2 c;
        vec2 r;
        lobe(fi, c, r);
        r *= 1.0 + 0.06 * sin(t * 0.35 + fi * 2.1 + seed);
        c += vec2(0.04 * aspect * sin(t * 0.21 + fi * 1.3 + seed), 0.03 * sin(t * 0.17 + fi * 2.7));
        vec2 d = (q - c) / r;
        E = max(E, 1.0 - dot(d, d));
    }
    return E + rag * 0.6;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 q = vec2(q0.x * aspect, q0.y);
    vec2 sp = q + vec2(seed * 3.1, seed * 1.7);
    float t = time;
    float rag = fbm(vec2(sp.x * 2.0 + t * 0.05, sp.y * 4.5 - t * 0.03)) - 0.5;

    vec3 top = mix(vec3(1.0, 1.0, 0.98), vec3(0.72, 0.74, 0.78), rain);
    vec3 belly = mix(vec3(0.70, 0.79, 0.90), vec3(0.42, 0.46, 0.53), rain);
    vec3 lining = vec3(1.0, 0.92, 0.72);
    if (kind > 0.5 && kind < 1.5) { top *= 0.93; belly *= 0.85; }            // stratocumulus: greyer
    if (kind > 4.5) { belly = mix(belly, vec3(0.33, 0.36, 0.44), 0.8); }      // a storm's dark base

    vec3 col = vec3(0.0);
    float a = 0.0;

    if (kind > 1.5 && kind < 2.5) {
        // altocumulus: a patch of small rounded cells, in slanted rows (a mackerel sky)
        vec2 pq = q / vec2(aspect * 0.85, 0.8);
        float patch = smoothstep(0.0, 0.5, 1.0 - dot(pq, pq) + rag * 0.9);
        vec2 g = vec2(q.x, q.y + q.x * 0.22) * vec2(3.2, 4.2) + seed;
        vec2 gi = floor(g);
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                vec2 cell = gi + vec2(float(i), float(j));
                float u = h21(cell);
                if (u < 0.82) {
                    vec2 cc = cell + 0.5 + (vec2(h21(cell + 7.1), h21(cell + 3.3)) - 0.5) * 0.5;
                    vec2 d = (g - cc) / (0.34 + 0.14 * h21(cell + 1.9));
                    float e = 1.0 - dot(d, d) + rag * 0.4;
                    float dens = smoothstep(0.0, 0.45, e) * patch * 0.85;
                    float lit = clamp(0.62 + light * (dot(d, sunDir) * 0.25 - d.y * 0.22), 0.0, 1.0);
                    vec3 ci = mix(belly, top, lit) + lining * sunNear * (1.0 - smoothstep(0.0, 0.5, e)) * 0.5;
                    col = ci * dens + col * (1.0 - dens);
                    a = dens + a * (1.0 - dens);
                }
            }
        }
    } else if (kind > 2.5 && kind < 3.5) {
        // altostratus: a grey veil, thicker and thinner, the sun showing through it
        vec2 pq = q / vec2(aspect * 0.9, 0.85);
        float veil = smoothstep(0.0, 0.7, 1.0 - dot(pq, pq) + rag * 0.8);
        float thick = 0.55 + 0.45 * fbm(vec2(sp.x * 0.5 + t * 0.02, sp.y * 2.2));
        a = veil * thick * 0.42;
        col = mix(vec3(0.80, 0.84, 0.90), vec3(0.95, 0.96, 0.97), thick - 0.3) * a;
        col += lining * sunNear * a * 0.8;
    } else if (kind > 3.5 && kind < 4.5) {
        // cirrus: thin white strands, combed out by the wind, hooked at the end (mares' tails)
        for (int i = 0; i < 5; i++) {
            float fi = float(i);
            float u1 = h11(seed + fi * 1.9);
            float u2 = h11(seed * 1.3 + fi * 3.7);
            float u3 = h11(seed * 0.7 + fi * 5.1);
            float x0 = (u1 - 0.5) * 0.8 * aspect;            // where the hook starts
            float len = (0.35 + 0.35 * u2) * aspect;
            float y0 = (u3 - 0.5) * 1.1;
            float dx = q.x - x0;
            float hook = max(dx, 0.0);
            float yl = y0 + 0.06 * sin(q.x * 1.3 + seed + fi) - (0.9 + 0.6 * u2) * hook * hook / aspect;
            float wdt = 0.07 + 0.08 * u1 + 0.05 * max(-dx, 0.0) / aspect;   // fraying out behind
            float dy = (q.y - yl) / wdt;
            float along = smoothstep(len, len * 0.3, abs(dx + len * 0.5)) * smoothstep(0.35 * aspect, 0.0, hook);
            float fib = 0.55 + 0.45 * vn(vec2(q.x * 1.2 + fi * 7.0, dy * 1.6));
            float dens = exp(-dy * dy) * along * fib * 0.75;
            col = top * dens + col * (1.0 - dens);
            a = dens + a * (1.0 - dens);
        }
        col += lining * sunNear * a * 0.4;
    } else {
        // heaped: cumulus, stratocumulus, cumulonimbus: one shape from the lobes (their union),
        // lit as a whole, so the lobes don't show as stacked plates
        float E = heap(q, sp, t);
        float Esun = heap(q + sunDir * 0.16, sp + sunDir * 0.16, t);
        float Eup = heap(q + vec2(0.0, -0.16), sp + vec2(0.0, -0.16), t);
        // cotton: the edge pulled in and out by the fibres, softer, a few loose ones just past it
        float wv = wisps(sp);
        float lumps = fbm(sp * 3.5 + t * 0.02) - 0.5;              // a lumpy, pulled outline
        float Ec = E + cotton * (lumps * 0.35 + (wv - 0.5) * 0.3);
        float dens = smoothstep(0.0, mix(0.3, 0.45, cotton), Ec);
        float halo = cotton * smoothstep(-0.18, 0.0, Ec) * (1.0 - smoothstep(0.0, 0.12, Ec))
                   * smoothstep(0.5, 0.75, wv) * 0.6;
        dens = max(dens, halo);
        float st0 = fbm(vec2(sp.x * 0.8, sp.y * 8.0));
        dens *= mix(1.0, smoothstep(0.12, 0.85, st0) * 1.35, 0.6 * strokes);
        // the flat bottom of a real cloud; a cotton ball is round all over
        float cut = smoothstep(baseLine + 0.06, baseLine - 0.04, q.y + rag * 0.05);
        dens *= mix(cut, 1.0, cotton * 0.85);
        dens = clamp(dens, 0.0, 1.0) * mix(0.92, 0.97, cotton);
        // lit where the shape ends towards the sun and on top; grey towards the bottom
        float lit = 0.55 + light * ((E - Esun) * 0.9 + (E - Eup) * 0.6);
        lit -= smoothstep(-0.2, baseLine, q.y) * 0.3 * light;
        // cotton: white on top, a soft warm grey underneath and in the folds, not a blue belly
        lit = mix(lit, 0.68 + (lit - 0.55) * 0.75 + (E - 0.4) * 0.25, cotton);
        belly = mix(belly, mix(vec3(0.83, 0.82, 0.84), vec3(0.6, 0.62, 0.66), rain), cotton);
        col = mix(belly, top, clamp(lit, 0.0, 1.0));
        col *= 1.0 - cotton * 0.1 * (1.0 - wv);
        col += lining * sunNear * (1.0 - smoothstep(0.0, 0.4, E)) * 0.55;
        col *= dens;
        a = dens;
    }

    // paper: a broad, soft unevenness in the paint (no specks: Nikki doesn't like loose pixels)
    float g = vn(q * 9.0 + seed) * 0.6 + vn(q * 21.0 + seed * 2.0) * 0.4;
    float speck = 1.0 - 0.35 * grain * smoothstep(0.45, 0.9, g);
    col *= speck;
    a *= speck;

    // far away: paler, into the sky
    col = mix(col, hazeColor * a, haze * 0.5);
    a *= 1.0 - haze * 0.3;
    float m = alphaMul * color.a;
    return vec4(col * m, a * m);
}
#endif
]])

local quad = love.graphics.newMesh({
    { -1, -1, 0, 0 }, { 1, -1, 1, 0 }, { 1, 1, 1, 1 }, { -1, 1, 0, 1 },
}, 'fan', 'static')

local panelRect = { 20, 0, 400, 0 }
local function overPanel(b)
    if not b.showPanel or ui.isPanelFolded('•• clouds ••') then return false end
    local mx, my = love.mouse.getPosition()
    local r = panelRect
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

---------------------------------------------------------------- growing clouds (CG1, CG2)
-- Paint clouds with a finger: they float where they're put. Pull one up: it cools, makes more
-- cloud, and past the line where it gets warmer than the air it goes on by itself, up to the lid. The physics is
-- src/cloud-air.lua; each thermal is a lobe of one cloud shape (a sum of soft balls) drawn here.
-- The thermals live in one layer (GROW_LAYER), 1 unit = 1 m, y = -height.

local GROW_LAYER = 5
local MAX_THERMALS = 260
local MAXL = 64        -- lobes the shader takes

local grownShader = love.graphics.newShader([[
#ifdef GL_ES
precision highp float;
#endif
#define MAXL 64
uniform vec4 lobes[MAXL];      // screen pixels: x, y, radius, how much cloud (0..1)
uniform float lobeBase[MAXL];  // screen y of its own base (where it turned to cloud)
uniform int count;
uniform vec3 toLayer;          // metres in the layer = (sc - xy) * z
uniform float pxPerM;
uniform float time;
uniform vec2 sunDir;
uniform float light;
uniform float cotton;

float h21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float vn(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x),
               mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
    float s = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        s += a * vn(p);
        p = p * 2.03 + vec2(17.1, 9.2);
        a *= 0.5;
    }
    return s / 0.9375;
}

// the cloud's field: soft balls added up (lobes melt together), each fading out below its base
float field(vec2 p, float rag) {
    float F = 0.0;
    for (int i = 0; i < MAXL; i++) {
        if (i >= count) break;
        vec4 L = lobes[i];
        vec2 d = (p - L.xy) / L.z;
        float f = exp(-dot(d, d) * 1.5) * L.w;
        float below = (p.y + rag * 18.0 * pxPerM - lobeBase[i]) / (60.0 * pxPerM);
        f *= 1.0 - smoothstep(0.0, 1.0, below) * (1.0 - cotton * 0.85);
        F += f;
    }
    return F;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 lp = (sc - toLayer.xy) * toLayer.z;
    float t = time;
    float rag = fbm(vec2(lp.x / 260.0 + t * 0.05, lp.y / 160.0 - t * 0.03)) - 0.5;
    float lumps = fbm(lp / 110.0 + t * 0.02) - 0.5;
    float F = field(sc, rag);
    float E = F - 0.42 + rag * 0.22 + lumps * 0.12 * (0.4 + cotton);
    float dens = smoothstep(0.0, 0.22, E);
    if (dens <= 0.001) return vec4(0.0);
    float sh = 90.0 * pxPerM;
    float Fs = field(sc + sunDir * sh, rag);
    float Fu = field(sc + vec2(0.0, -sh), rag);
    // lit where it ends towards the sun and on top, grey where there's a lot of cloud above it
    float lit = 0.6 + light * ((F - Fs) * 0.55 + (F - Fu) * 0.45);
    lit -= light * clamp(Fu - 0.5, 0.0, 1.0) * 0.18;
    vec3 top = vec3(1.0, 1.0, 0.98);
    vec3 belly = mix(vec3(0.70, 0.79, 0.90), vec3(0.83, 0.82, 0.84), cotton);
    vec3 col = mix(belly, top, clamp(lit, 0.0, 1.0));
    col += vec3(1.0, 0.92, 0.72) * (1.0 - smoothstep(0.0, 0.25, E)) * 0.25;
    dens *= 0.95;
    return vec4(col * dens, dens) * color.a;
}
]])

-- a soft round dab for the moist air that isn't cloud yet
local vapourImage = (function()
    local n = 64
    local data = love.image.newImageData(n, n)
    data:mapPixel(function(x, y)
        local dx, dy = (x + 0.5) / n * 2 - 1, (y + 0.5) / n * 2 - 1
        local a = math.max(0, 1 - (dx * dx + dy * dy))
        return 1, 1, 1, a * a
    end)
    return love.graphics.newImage(data)
end)()

local function airOf(set)
    local a = { groundT = set.groundT, groundRH = set.groundRH, aloftRH = set.aloftRH,
        lapse = set.lapse, lidZ = set.lidKm * 1000, lidK = set.lidK }
    a.key = table.concat({ a.groundT, a.groundRH, a.aloftRH, a.lapse, a.lidZ, a.lidK }, ' ')
    return a
end

-- the lines (condensation level, free convection, the top), worked out again when the air changes
local function levelsOf(b, air)
    if b.levelsKey ~= air.key then
        b.levelsKey = air.key
        b.lcl, b.lfc, b.top = cloudAir.levels(air)
    end
    return b.lcl, b.lfc, b.top
end

local function growMouse()
    local w, h, cx, cy, scale = view()
    local mx, my = love.mouse.getPosition()
    local lx, ly, k = layerCam(LAYERS[GROW_LAYER].f, cx, cy, scale)
    return lx + (mx - w / 2) / k, ly + (my - h / 2) / k, k
end

local function thermalAt(b, x, y)
    local best, bestD
    for _, p in ipairs(b.thermals) do
        -- only what shows: a leftover that's no cloud any more doesn't catch the finger
        if p.qc > 0.05 then
            local d = math.sqrt((p.x - x) ^ 2 + (-p.z - y) ^ 2)
            if d < p.r * 1.1 and (not bestD or d < bestD) then best, bestD = p, d end
        end
    end
    return best
end

-- full: the least cloud goes, so painting always paints
local function makeRoom(b)
    if #b.thermals < MAX_THERMALS then return end
    local weakest, wi
    for i, p in ipairs(b.thermals) do
        if not weakest or p.qc < weakest.qc then weakest, wi = p, i end
    end
    table.remove(b.thermals, wi)
end

-- everything touching it, and touching those: the cloud it's part of
local function clusterOf(b, first)
    local inside, list = { [first] = true }, { first }
    local i = 1
    while list[i] do
        local p = list[i]
        for _, q in ipairs(b.thermals) do
            if not inside[q] and (p.x - q.x) ^ 2 + (p.z - q.z) ^ 2 < ((p.r + q.r) * 0.9) ^ 2 then
                inside[q] = true
                list[#list + 1] = q
            end
        end
        i = i + 1
    end
    return list
end

-- a dab of cloud at (x, y): a new one that floats where it's put, or more in one that's there;
-- its bottom a little under its middle, flat (Nikki: "i just want to paint clouds and have them
-- be friendly")
local function paint(b, air, x, y)
    local z = math.max(0, -y)
    local near = thermalAt(b, x, y)
    if near and math.sqrt((near.x - x) ^ 2 + (near.z - z) ^ 2) < near.r * 0.5 then
        near.qc = math.min(1.5, near.qc + 0.3)
        return
    end
    makeRoom(b)
    local p = cloudAir.newCloud(air, x, z, 0.7, 280 + love.math.random() * 120)
    p.seed = love.math.random()
    p.baseZ = math.max(0, z - p.r * 0.35)
    b.thermals[#b.thermals + 1] = p
end

local function growInput(b, air, dt)
    local set = b.settings
    local down = state.playMode and love.mouse.isDown(1)
    local mx, my = growMouse()
    if down and not b.wasDown and not overPanel(b) and #getInteractedWithPointer() == 0 then
        local p = thermalAt(b, mx, my)
        if p then
            -- pull: the whole cloud comes along
            b.pulled = {}
            for _, q in ipairs(clusterOf(b, p)) do
                b.pulled[#b.pulled + 1] = { p = q, dx = q.x - mx, dy = -q.z - my }
            end
            b.pullVX, b.pullVY = 0, 0
        else
            b.painting = true
            b.lastPaintX, b.lastPaintY = mx, my
            paint(b, air, mx, my)
        end
        b.lastGrowX, b.lastGrowY = mx, my
    end
    b.wasDown = down
    if not down then
        if b.pulled then
            -- let go: it keeps the speed it was pulled at (in the sky's own time)
            local w = clamp(-b.pullVY / set.speed, -12, 12)
            local u = clamp(b.pullVX / set.speed, -12, 12)
            for _, e in ipairs(b.pulled) do
                e.p.w, e.p.u = w, u
                -- a painted cloud let go gently, not lighter than the air, stays where it's put;
                -- flung, or lifted past the take-off line, the air takes over
                if e.p.floats and math.abs(w) < 1 and cloudAir.buoyancyK(air, e.p) <= 0 then
                    e.p.w, e.p.u = 0, 0
                else
                    e.p.floats = nil
                end
            end
        end
        b.pulled, b.painting = nil, nil
        return
    end
    if b.pulled and dt > 0 then
        local vx, vy = (mx - b.lastGrowX) / dt, (my - b.lastGrowY) / dt
        b.pullVX = b.pullVX + (vx - b.pullVX) * 0.3
        b.pullVY = b.pullVY + (vy - b.pullVY) * 0.3
        for _, e in ipairs(b.pulled) do
            e.p.x = mx + e.dx
            cloudAir.moveTo(e.p, math.max(0, -(my + e.dy)))
            e.p.w, e.p.u = 0, 0
        end
    elseif b.painting then
        local d = math.sqrt((mx - b.lastPaintX) ^ 2 + (my - b.lastPaintY) ^ 2)
        if d > 220 then
            paint(b, air, mx, my)
            b.lastPaintX, b.lastPaintY = mx, my
        end
    end
    b.lastGrowX, b.lastGrowY = mx, my
end

local function isPulled(b, p)
    if not b.pulled then return false end
    for _, e in ipairs(b.pulled) do if e.p == p then return true end end
    return false
end

-- touching thermals push apart (a cloud spreads instead of stacking up in one spot) and drag
-- each other along up and down, so a cloud goes up as one
local function together(b, dt)
    local list = b.thermals
    for i = 1, #list do
        local p = list[i]
        for j = i + 1, #list do
            local q = list[j]
            local dx, dz = q.x - p.x, q.z - p.z
            local reach = (p.r + q.r) * 0.75
            local d2 = dx * dx + dz * dz
            -- painted ones stay as painted
            if d2 < reach * reach and not (p.floats and q.floats) then
                local d = math.sqrt(d2) + 1e-3
                local overlap = 1 - d / reach
                local push = overlap * 10 * dt
                local nx = d > 1 and dx / d or (love.math.random() - 0.5)
                p.x, q.x = p.x - nx * push, q.x + nx * push
                local k = math.min(0.5, overlap * 0.08 * dt)
                local dw = (q.w - p.w) * k
                p.w, q.w = p.w + dw, q.w - dw
            end
        end
    end
end

local function growUpdate(b, dt)
    local set = b.settings
    local air = airOf(set)
    b.air = air
    growInput(b, air, dt)
    -- the wind carries them all along, on the screen's time (like the old sky); out of the layer's
    -- box on one side, back in on the other
    local w, _, cx, cy, scale = view()
    local f = LAYERS[GROW_LAYER].f
    local lx = layerCam(f, cx, cy, scale)
    local hx = boxOf(f, w, scale) + 500
    local windV = WIND * set.wind * (1 + b.gust)
    for _, p in ipairs(b.thermals) do
        if not isPulled(b, p) then
            p.x = p.x + windV * dt
            if p.x - lx > hx then p.x = p.x - 2 * hx elseif p.x - lx < -hx then p.x = p.x + 2 * hx end
        end
    end
    local simDt = dt * set.speed
    local steps = math.max(1, math.ceil(simDt / 2))
    local h = simDt / steps
    for _ = 1, steps do
        for _, p in ipairs(b.thermals) do
            local wasCloud = p.qc > 0
            cloudAir.step(air, p, h, isPulled(b, p))
            -- its own base: where it turned to cloud; lower if it sinks while still cloud
            if p.qc > 0 then
                if not wasCloud or not p.baseZ or p.z < p.baseZ then p.baseZ = p.z end
            else
                p.baseZ = nil
            end
        end
        together(b, h)
    end
    local keep = {}
    for _, p in ipairs(b.thermals) do
        if isPulled(b, p) or not cloudAir.spent(p) then
            keep[#keep + 1] = p
        end
    end
    b.thermals = keep
end

local function drawGrown(b, w, h, cx, cy, scale)
    local lx, ly, k = layerCam(LAYERS[GROW_LAYER].f, cx, cy, scale)
    local dpi = love.graphics.getDPIScale()
    local function sx(x) return w / 2 + (x - lx) * k end
    local function sy(y) return h / 2 + (y - ly) * k end
    local air = b.air
    -- the lines: where the ground's air turns to cloud, goes on alone, the lid
    if air then
        local lcl, lfc = levelsOf(b, air)
        local font = love.graphics.getFont()
        local function line(z, label, a, dash)
            if not z then return end
            local y = sy(-z)
            if y < -10 or y > h + 10 then return end
            love.graphics.setColor(1, 1, 1, a)
            if dash then
                for x = 0, w, 24 do love.graphics.line(x, y, x + 12, y) end
            else
                love.graphics.line(0, y, w, y)
            end
            love.graphics.print(label, w - font:getWidth(label) - 12, y - font:getHeight() - 2)
        end
        love.graphics.setLineWidth(1)
        line(lcl, string.format('cloud base %.1f km', lcl and lcl / 1000 or 0), 0.35)
        -- (its label only where it isn't on top of the base's)
        line(lfc, (lcl and lfc and lfc - lcl < 150) and ''
            or string.format('goes on by itself %.1f km', lfc and lfc / 1000 or 0), 0.25, true)
        line(air.lidZ, string.format('lid %.1f km', air.lidZ / 1000), 0.3)
    end
    -- moist air not cloud yet: a faint shimmer, stronger the closer it is to turning to cloud
    love.graphics.setBlendMode('add')
    for _, p in ipairs(b.thermals) do
        local near = clamp((cloudAir.rh(p) - cloudAir.SPENT_RH) / (0.97 - cloudAir.SPENT_RH), 0, 1)
        local a = near * near * 0.1 * (1 - clamp(p.qc / 0.3, 0, 1))
        if a > 0.005 then
            local wob = 1 + 0.06 * math.sin(b.time * 2.3 + p.seed * 20)
            local r = p.r * k * 1.25 * wob
            love.graphics.setColor(0.85, 0.92, 1, a)
            love.graphics.draw(vapourImage, sx(p.x), sy(-p.z), 0, 2 * r / 64, 2 * r / 64, 32, 32)
        end
    end
    love.graphics.setBlendMode('alpha')
    -- the clouds: the thermals with cloud water as lobes, only those on the screen; the ones that
    -- touch drawn together as one shape, MAXL lobes at most a draw
    local shown = {}
    for _, p in ipairs(b.thermals) do
        local amount = clamp(p.qc / 0.5, 0, 1)
        if amount > 0.02 then
            local r = p.r * k * (0.75 + 0.35 * amount)
            -- breathing: each lobe swells and drifts a little, slowly
            local t, sd = b.time * b.settings.morph, (p.seed or 0) * 40
            r = r * (1 + 0.07 * math.sin(t * 0.4 + sd))
            local px = sx(p.x + p.r * 0.08 * math.sin(t * 0.23 + sd * 1.3))
            local py = sy(-p.z + p.r * 0.06 * math.sin(t * 0.31 + sd * 0.7))
            if px + r * 1.3 > 0 and px - r * 1.3 < w and py + r * 1.3 > 0 and py - r * 1.3 < h then
                shown[#shown + 1] = { px = px, py = py, r = r, amount = amount,
                    base = sy(-(p.baseZ or p.z)) }
            end
        end
    end
    if #shown == 0 then return end
    -- which touch: a union-find, then each group in order along x
    local parent = {}
    for i = 1, #shown do parent[i] = i end
    local function root(i)
        while parent[i] ~= i do parent[i] = parent[parent[i]]; i = parent[i] end
        return i
    end
    for i = 1, #shown do
        local a = shown[i]
        for j = i + 1, #shown do
            local c = shown[j]
            local reach = (a.r + c.r) * 1.3
            if (a.px - c.px) ^ 2 + (a.py - c.py) ^ 2 < reach * reach then parent[root(i)] = root(j) end
        end
    end
    local groups, order = {}, {}
    for i, l in ipairs(shown) do
        local g = root(i)
        if not groups[g] then groups[g] = {}; order[#order + 1] = g end
        table.insert(groups[g], l)
    end
    love.graphics.setShader(grownShader)
    grownShader:send('toLayer', { (w / 2 - lx * k) * dpi, (h / 2 - ly * k) * dpi, 1 / (k * dpi) })
    grownShader:send('pxPerM', k * dpi)
    grownShader:send('time', b.time * b.settings.morph)
    grownShader:send('light', b.settings.light)
    grownShader:send('cotton', b.settings.cotton)
    love.graphics.setBlendMode('alpha', 'premultiplied')
    love.graphics.setColor(1, 1, 1, 1)
    local sunX, sunY = SUN[1] * w, SUN[2] * h
    local function drawGroup(list, from, to)
        local lobes, bases = {}, {}
        local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
        for i = from, to do
            local l = list[i]
            lobes[#lobes + 1] = { l.px * dpi, l.py * dpi, l.r * dpi, l.amount }
            bases[#bases + 1] = l.base * dpi
            x0, y0 = math.min(x0, l.px - l.r * 1.3), math.min(y0, l.py - l.r * 1.3)
            x1, y1 = math.max(x1, l.px + l.r * 1.3), math.max(y1, l.py + l.r * 1.3)
        end
        local dx, dy = sunX - (x0 + x1) / 2, sunY - (y0 + y1) / 2
        local len = math.sqrt(dx * dx + dy * dy) + 1e-3
        grownShader:send('lobes', unpack(lobes))
        grownShader:send('lobeBase', unpack(bases))
        grownShader:send('count', #lobes)
        grownShader:send('sunDir', { dx / len, dy / len })
        love.graphics.rectangle('fill', x0, y0, x1 - x0, y1 - y0)
    end
    for _, g in ipairs(order) do
        local list = groups[g]
        table.sort(list, function(p, q) return p.px < q.px end)
        for from = 1, #list, MAXL do drawGroup(list, from, math.min(#list, from + MAXL - 1)) end
    end
    love.graphics.setBlendMode('alpha')
    love.graphics.setShader()
end

local shadowMesh = love.graphics.newMesh(128, 'strip', 'stream')
local HILL_MAX = 600
local hillMesh = love.graphics.newMesh(HILL_MAX * 2, 'strip', 'stream')

---------------------------------------------------------------- hooks

function s.onStart()
    worldState.paused = false
    local b = clouds()
    buildGround(b)
    b.mipos = aliveMipos(b)
    if #b.mipos == 0 then
        spawnMipo(b, -900, -1400)
        spawnMipo(b, 700, -1400)
    end
    if #b.list == 0 or not b.list[1].genus then fillSky(b) end
end

function s.onUnload()
    local b = state.clouds
    if not b then return end
    destroyGround(b)
    if b.savedDrawBodies ~= nil then state.world.debugDrawBodies = b.savedDrawBodies end
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local b = clouds()
    if key == 'c' then
        local c = newCloud(4, 'cumulus', 0)
        local x, y = mouseInLayer(c)
        c.x, c.y, c.homeY = x, y, y
        b.list[#b.list + 1] = c
    elseif key == 'w' then
        b.weather = b.weather % #WEATHERS + 1
        fillSky(b)
        b.drops = {}
    elseif key == 'g' then b.gust = 5
    elseif key == 'm' then
        local mx, my = mouseWorldPos()
        spawnMipo(b, mx, my)
    elseif key == 'r' and b.grow then b.thermals = {}
    elseif key == 'r' then fillSky(b); b.drops = {}
    elseif key == 'e' then b.grow = not b.grow
    elseif key == 'h' then b.showPanel = not b.showPanel
    end
end

local function holding(b, dt)
    local down = state.playMode and love.mouse.isDown(1)
    if down and not b.wasDown and not overPanel(b) and #getInteractedWithPointer() == 0 then
        local mx, my = love.mouse.getPosition()
        local c = pickCloud(b, mx, my)
        if c then
            local lx, ly = mouseInLayer(c)
            b.held = c
            c.grabDX, c.grabDY = lx - c.x, ly - c.y
            b.pressT, b.pressMoved = 0, 0
            b.lastMX, b.lastMY = mx, my
        end
    end
    b.wasDown = down
    local c = b.held
    if not c then return end
    if not down then
        b.held = nil
        if b.pressT < 0.25 and b.pressMoved < 12 then poof(b, c) end
        return
    end
    local _, _, _, _, scale = view()
    local mx, my = love.mouse.getPosition()
    b.pressT = b.pressT + dt
    b.pressMoved = b.pressMoved + math.abs(mx - b.lastMX) + math.abs(my - b.lastMY)
    b.lastMX, b.lastMY = mx, my
    local lx, ly = mouseInLayer(c)
    local tx, ty = lx - c.grabDX, ly - c.grabDY
    if dt > 0 then
        local nvx, nvy = (tx - c.x) / dt, (ty - c.y) / dt
        -- shaking wrings it out: count the change of speed on the screen
        local k = zoomOf(c.f, scale)
        local dv = math.sqrt((nvx - c.vx) ^ 2 + (nvy - c.vy) ^ 2) * k
        if dv > 60 then c.rain = math.min(1.4, c.rain + dv * 0.00035) end
        c.vx = c.vx + (nvx - c.vx) * 0.5
        c.vy = c.vy + (nvy - c.vy) * 0.5
    end
    c.x, c.y = tx, ty
    c.homeY = ty
end

local function rainFrom(b, c, dt, scale)
    if c.storm then c.rain = math.max(c.rain, 0.6) end
    if c.rain < 0.15 then return end
    local n = c.rain * 70 * dt
    local k = zoomOf(c.f, scale)
    local spread = c.storm and 0.4 or 0.75
    while n > 0 do
        if love.math.random() < n then
            local u = (love.math.random() * 2 - 1) * spread
            b.drops[#b.drops + 1] = { f = c.f, layer = c.layer, front = c.front,
                x = c.x + u * c.hw, y = c.y + c.hh * (c.baseLine - 0.1 + love.math.random() * 0.1),
                vy = (650 + love.math.random() * 250) / k, vx = c.vx * 0.3 }
        end
        n = n - 1
    end
    if not c.storm then c.rain = c.rain - dt * 0.1 end
end

local function dropsUpdate(b, dt)
    local w, h, cx, cy, scale = view()
    local keep = {}
    for _, d in ipairs(b.drops) do
        d.x, d.y = d.x + d.vx * dt, d.y + d.vy * dt
        local lx, ly, k = layerCam(d.f, cx, cy, scale)
        local sx, sy = w / 2 + (d.x - lx) * k, h / 2 + (d.y - ly) * k
        -- far rain stops at its own ground (the layer's y = 0); near rain at the real ground
        local wx = cx + (sx - w / 2) / scale
        local gy
        if d.f < 0.6 then
            gy = h / 2 + (0 - ly) * k
        else
            local _, y = worldToScreen(wx, groundAt(wx), w, h, cx, cy, scale)
            gy = y
        end
        if sy >= gy then
            if d.f >= 0.6 and #b.splashes < 300 then
                b.splashes[#b.splashes + 1] = { x = wx, y = groundAt(wx), life = 0.25 }
            end
        elseif sy < h + 50 then
            keep[#keep + 1] = d
        end
    end
    b.drops = keep
    local alive = {}
    for _, p in ipairs(b.splashes) do
        p.life = p.life - dt
        if p.life > 0 then alive[#alive + 1] = p end
    end
    b.splashes = alive
end

function s.update(dt)
    local b = clouds()
    local set = b.settings
    b.time = b.time + dt
    b.gust = b.gust * math.max(0, 1 - dt * 0.8)
    if b.grow then
        growUpdate(b, dt)
        return
    end
    holding(b, dt)
    local w, _, cx, cy, scale = view()
    for _, c in ipairs(b.list) do
        if c ~= b.held then
            -- higher up, faster wind
            local windV = WIND * set.wind * (1 + b.gust) * GENERA[c.genus].wind
            c.vx = c.vx + (windV - c.vx) * math.min(1, dt * 0.6)
            c.vy = c.vy + (0 - c.vy) * math.min(1, dt * 0.8)
            c.x = c.x + c.vx * dt
            c.y = c.y + c.vy * dt
            c.y = c.y + (c.homeY - c.y) * math.min(1, dt * 0.05)
            -- out of its layer's box on one side, back in at the other as a new cloud of its kind
            local lx = layerCam(c.f, cx, cy, scale)
            local hx = boxOf(c.f, w, scale) + c.hw
            local nx
            if c.x - lx > hx then nx = c.x - 2 * hx elseif c.x - lx < -hx then nx = c.x + 2 * hx end
            if nx then
                local n = newCloud(c.layer, c.genus, nx)
                for key, v in pairs(n) do c[key] = v end
                c.vx = windV
            end
        end
        rainFrom(b, c, dt, scale)
    end
    dropsUpdate(b, dt)
end

---------------------------------------------------------------- drawing

local function sendCommon(b)
    local set = b.settings
    cloudShader:send('time', b.time * set.morph)
    cloudShader:send('strokes', set.strokes)
    cloudShader:send('grain', set.grain)
    cloudShader:send('light', set.light)
    cloudShader:send('cotton', set.cotton)
    cloudShader:send('hazeColor', { 0.85, 0.92, 0.86 })
end

local function drawCloud(c, w, h, cx, cy, scale, dpi)
    local sx, sy, hw, hh = onScreen(c, w, h, cx, cy, scale)
    if sx + hw < 0 or sx - hw > w or sy + hh < 0 or sy - hh > h then return end
    local sunX, sunY = SUN[1] * w, SUN[2] * h
    local dx, dy = sunX - sx, sunY - sy
    local len = math.sqrt(dx * dx + dy * dy) + 1e-3
    cloudShader:send('seed', c.seed)
    cloudShader:send('aspect', c.hw / c.hh)
    cloudShader:send('kind', c.kind)
    cloudShader:send('baseLine', c.baseLine)
    cloudShader:send('sunDir', { dx / len, dy / len })
    cloudShader:send('sunNear', math.exp(-len / (hw * 0.9 + 60)))
    cloudShader:send('haze', clamp((0.65 - c.f) / 0.55, 0, 1))
    cloudShader:send('rain', clamp(c.rain, 0, 1))
    cloudShader:send('alphaMul', c.front and 0.85 or 1)
    love.graphics.draw(quad, sx, sy, 0, hw, hh)
end

local function drawDrop(d, w, h, cx, cy, scale)
    local lx, ly, k = layerCam(d.f, cx, cy, scale)
    local sx, sy = w / 2 + (d.x - lx) * k, h / 2 + (d.y - ly) * k
    local len = 10 + 12 * d.f
    love.graphics.setColor(0.75, 0.85, 0.95, 0.3 + 0.4 * math.min(1, d.f))
    love.graphics.line(sx, sy, sx - d.vx * k * 0.012, sy - len)
end

-- a far hill band: the layer's ground with bumps, down to the bottom of the screen
local function drawHill(hill, w, h, cx, cy, scale)
    local lx, ly, k = layerCam(hill.f, cx, cy, scale)
    local green, sky = { 0.30, 0.56, 0.30 }, { 0.80, 0.88, 0.80 }
    local r = green[1] + (sky[1] - green[1]) * hill.haze
    local g = green[2] + (sky[2] - green[2]) * hill.haze
    local bl = green[3] + (sky[3] - green[3]) * hill.haze
    -- the points sit at fixed places along the hills (a step in the layer, not on the screen), so
    -- panning slides the hills instead of sliding the points along them (which made them jump);
    -- five points per small bump
    local step = hill.amp / 1.6 / 5
    local x1, x2 = lx - (w / 2) / k, lx + (w / 2) / k
    while (x2 - x1) / step > HILL_MAX - 3 do step = step * 2 end
    local verts = {}
    for i = math.floor(x1 / step), math.ceil(x2 / step) do
        local x = i * step
        local sx = w / 2 + (x - lx) * k
        local bump = love.math.noise(x * 0.4 / hill.amp, hill.seed) * 0.75
            + love.math.noise(x * 1.6 / hill.amp, hill.seed + 5) * 0.25
        local sy = h / 2 + (-hill.amp * bump - ly) * k
        verts[#verts + 1] = { sx, sy, 0, 0, r, g, bl, 1 }
        verts[#verts + 1] = { sx, h + 10, 0, 0, r * 0.9, g * 0.9, bl * 0.9, 1 }
    end
    hillMesh:setVertices(verts)
    hillMesh:setDrawRange(1, #verts)
    love.graphics.draw(hillMesh)
end

-- far to near: hills and clouds of the layers behind the world (or the front layer only)
local function drawSky(b, front)
    local w, h, cx, cy, scale = view()
    local dpi = love.graphics.getDPIScale()
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setLineWidth(1.5)
    local byLayer = {}
    for _, c in ipairs(b.list) do
        byLayer[c.layer] = byLayer[c.layer] or {}
        table.insert(byLayer[c.layer], c)
    end
    local dropsByLayer = {}
    for _, d in ipairs(b.drops) do
        dropsByLayer[d.layer] = dropsByLayer[d.layer] or {}
        table.insert(dropsByLayer[d.layer], d)
    end
    local nextHill = 1
    for i, layer in ipairs(LAYERS) do
        if (layer.front and true or false) == front then
            while not front and HILLS[nextHill] and HILLS[nextHill].f <= layer.f do
                love.graphics.setColor(1, 1, 1, 1)
                drawHill(HILLS[nextHill], w, h, cx, cy, scale)
                nextHill = nextHill + 1
            end
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setBlendMode('alpha', 'premultiplied')
            love.graphics.setShader(cloudShader)
            sendCommon(b)
            if not b.grow then
                for _, c in ipairs(byLayer[i] or {}) do drawCloud(c, w, h, cx, cy, scale, dpi) end
            end
            love.graphics.setShader()
            love.graphics.setBlendMode('alpha')
            if not b.grow then
                for _, d in ipairs(dropsByLayer[i] or {}) do drawDrop(d, w, h, cx, cy, scale) end
            elseif i == GROW_LAYER then
                drawGrown(b, w, h, cx, cy, scale)
            end
        end
    end
    while not front and HILLS[nextHill] do
        love.graphics.setColor(1, 1, 1, 1)
        drawHill(HILLS[nextHill], w, h, cx, cy, scale)
        nextHill = nextHill + 1
    end
    love.graphics.pop()
end

-- the shadow of each near cloud on the ground: a soft dark band along the top of the grass
local function drawShadows(b)
    local w, h, cx, cy, scale = view()
    local sunX = SUN[1] * w
    for _, c in ipairs(b.list) do
        if c.f >= 0.5 and not c.front and c.kind ~= 4 then
            local sx, _, hw = onScreen(c, w, h, cx, cy, scale)
            -- a bit away from the sun, the further the cloud is from it
            local wx = cx + (sx - w / 2 - (sunX - sx) * 0.15) / scale
            local rx = hw / scale * 0.85
            local strength = 0.16 * c.f * (1 - clamp(c.rain, 0, 1) * 0.3) + 0.12 * clamp(c.rain, 0, 1)
            if c.kind == 3 then strength = strength * 0.4 end
            local verts, steps = {}, 40
            for i = 0, steps do
                local x = wx - rx + 2 * rx * i / steps
                local u = (x - wx) / rx
                local al = strength * (1 - u * u) ^ 1.5
                local y = groundAt(x)
                local _, by = project(x, y - BACK, K_BACK, cx, cy)
                local _, fy = project(x, y + FRONT, K_FRONT, cx, cy)
                verts[#verts + 1] = { x, by, 0, 0, 0.02, 0.1, 0.05, al }
                verts[#verts + 1] = { x, fy + 520, 0, 0, 0.02, 0.1, 0.05, 0 }
            end
            shadowMesh:setVertices(verts)
            shadowMesh:setDrawRange(1, #verts)
            love.graphics.draw(shadowMesh)
        end
    end
end

function s.drawBelow()
    local b = state.clouds
    if not b then return end
    local w, h = love.graphics.getDimensions()
    local dpi = love.graphics.getDPIScale()
    -- the sky, straight on the screen; its horizon at eye level
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setShader(skyShader)
    skyShader:send('sunPos', { SUN[1] * w * dpi, SUN[2] * h * dpi })
    skyShader:send('horizonY', h / 2 * dpi)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.setShader()
    love.graphics.pop()
    drawSky(b, false)
    -- the ground, in the world
    planeFrom(b.settings)
    drawGround()
    if not b.grow then drawShadows(b) end
    love.graphics.setColor(DARK_GRASS[1], DARK_GRASS[2], DARK_GRASS[3], 1)
    bladeRow(backBlades, K_BACK + 0.02, -BACK, 1, 1.5, b.time)
    love.graphics.setColor(1, 1, 1, 1)
    -- the Mipos draw themselves; the plain ground line would show
    if state.playMode then
        b.savedDrawBodies = state.world.debugDrawBodies
        state.world.debugDrawBodies = false
    end
    b.drawing = true
end

function s.draw()
    local b = state.clouds
    if not (b and b.drawing) then return end
    b.drawing = nil
    if b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
    for _, p in ipairs(b.splashes) do
        love.graphics.setColor(0.85, 0.92, 1, p.life * 2.4)
        love.graphics.ellipse('fill', p.x, p.y - 6, 22 * (1.3 - p.life * 2), 7)
    end
    -- the front row a little lighter than the band, so it stands out in front of it
    love.graphics.setColor(LIGHT_GRASS[1] * 1.15, LIGHT_GRASS[2] * 1.12, LIGHT_GRASS[3] * 0.95, 1)
    bladeRow(frontBlades, K_FRONT, FRONT, 2, 2.0, b.time)
    drawSky(b, true)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function s.drawUI()
    local b = state.clouds
    if not (b and state.playMode and b.showPanel) then return end
    ui.startFrame()
    local BH, pad, w = 36, 8, 400
    local rows = {
        { 'wind', -3, 3 }, { 'morph', 0, 4 }, { 'strokes', 0, 2 },
        { 'grain', 0, 2 }, { 'light', 0, 2 }, { 'cotton', 0, 1 },
        { 'back', 0.5, 1 }, { 'front', 1, 1.6 }, { 'behind', 0, 400, 1 }, { 'infront', 0, 400, 1 }, { 'blades', 0, 3 },
    }
    -- growing (CG1): the air; label, low, high, whole numbers
    if b.grow then
        rows = {
            { 'groundT', 0, 40, 1, 'ground °C' }, { 'groundRH', 20, 100, 1, 'ground humidity %' },
            { 'aloftRH', 10, 100, 1, 'humidity up high %' }, { 'lapse', 4, 10, nil, 'cools °C per km' },
            { 'lidKm', 1, 10, nil, 'lid km' }, { 'lidK', 0, 8, nil, 'lid warmer °C' },
            { 'speed', 1, 200, 1, 'time x real' }, { 'wind', -3, 3 }, { 'morph', 0, 4, nil, 'breathing' },
            { 'light', 0, 2 }, { 'cotton', 0, 1 },
        }
    end
    local h = (BH + pad) * (#rows + 3) + pad + 24
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    panelRect[2], panelRect[4] = y0, h
    ui.panel(x0, y0, w, h, '•• clouds ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local cx, cy = ui.nextLayoutPosition(layout, w - 20, BH)
        local changed, on = ui.checkbox(cx, cy, b.grow, 'grow clouds (e)')
        if changed then b.grow = on end
        for _, row in ipairs(rows) do
            local key = row[1]
            local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            -- row[4] = 1: whole numbers; else two decimals
            local v = ui.sliderWithInput('clouds' .. key, x, y, 180, row[2], row[3], b.settings[key], nil, row[4])
            if v then b.settings[key] = v + 0 end
            ui.label(x + 280, y, row[5] or key)
        end
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if b.grow then
            if ui.button(x, y, 110, 'defaults') then
                for key, v in pairs(GROW_DEFAULTS) do b.settings[key] = v end
            end
            ui.label(x + 125, y, 'paint clouds, pull one up')
            x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            ui.label(x, y, 'r clears   m a Mipo   h the panel')
        else
            ui.label(x, y, 'weather: ' .. WEATHERS[b.weather].name .. '  (w)')
            x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            ui.label(x, y, 'drag, shake, tap a cloud   c g m r h')
        end
    end)
end

return s

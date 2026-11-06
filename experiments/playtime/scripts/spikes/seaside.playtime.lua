-- seaside: the water spikes in one place: the sea (sea spike) and water kept in cups and a bath
-- (the LIQUID sfixture, src/liquid.lua), all of it drawn with the sea's shader: see-through,
-- bending what's behind it, tinted with depth, caustics and a bright surface line.
-- The cups' water comes to us through state.liquidDrawHook (only while this scene is on).
-- Built on scripts/spikes/sea.playtime.lua; docs/WATER.md, docs/SEA.md.
--
-- play mode (tab): throw things in; press on open water and pull to make a wave; pick up a cup.
-- keys: m a Mipo   b a boat   c a crate   o a ball   u a cup   w a big wave   r reset   h the panel

local s = {}

local SEA_Y = 0              -- the still surface
local WORLD_W = 14000
local X0 = -WORLD_W / 2
local DX = 50                -- between surface columns
local COLS = math.floor(WORLD_W / DX)
local DEEP = 2600            -- the lagoon's deepest floor below the surface
local SAND_BOTTOM = 5200
local BAND = 260             -- the far sea: from the horizon down to the near surface
local SUN_X, SUN_Y = 1800, -1250
local LAND_W = 6000          -- the beach right of the lagoon, with the table and the bath
local BEACH_Y = SEA_Y - 380  -- the beach's height (the lagoon's ends)
local LAND_X = X0 + WORLD_W

-- Kept on state so a hot reload of this script keeps the sea and what's in it.
local function sea()
    local b = state.seaside or {}
    state.seaside = b
    b.h = b.h or {}
    b.v = b.v or {}
    b.foam = b.foam or {}
    b.surf = b.surf or {}
    b.surfVel = b.surfVel or {}
    b.props = b.props or {}
    b.mipos = b.mipos or {}
    b.drops = b.drops or {}
    b.bubbles = b.bubbles or {}
    b.wet = b.wet or {}
    b.time = b.time or 0
    b.settings = b.settings or {
        swell = 1, density = 1.6, drag = 1.2, clarity = 1, refraction = 1, caustics = 1, rays = 1,
    }
    local defaults = { mirror = 1, blur = 1, specks = 1, cupCaustics = 0.3, cupView = 60, cupBend = 0.3 }
    for key, v in pairs(defaults) do
        if b.settings[key] == nil then b.settings[key] = v end
    end
    if b.showPanel == nil then b.showPanel = true end
    return b
end

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

local function floorAt(x)
    if x >= LAND_X then return BEACH_Y end
    local u = (x - X0) / WORLD_W
    local e = math.abs(2 * u - 1)
    local bowl = 1 - e * e * e * e
    local n = 220 * (love.math.noise(u * 4, 3.7) - 0.5) + 90 * (love.math.noise(u * 13, 9.1) - 0.5)
    return SEA_Y - 380 + (DEEP + 380) * bowl + n * bowl
end

local function colX(i) return X0 + i * DX end

-- how much swell a column gets: none on the beach, all of it in deep water
local shoal = {}
for i = 0, COLS do
    shoal[i] = clamp((floorAt(colX(i)) - SEA_Y) / 700, 0, 1)
end

-- the swell, up positive: three travelling waves with deep-water speeds (w = sqrt(g k)),
-- each with a bit of its second harmonic for sharper crests and flatter troughs
local SWELLS = {
    { a = 38, len = 2100, phase = 0.0, dir = 1 },
    { a = 20, len = 950,  phase = 1.3, dir = -1 },
    { a = 9,  len = 410,  phase = 2.1, dir = 1 },
}
local function swellUp(x, t, scale)
    local g = 9.8 * love.physics.getMeter()
    local up = 0
    for _, w in ipairs(SWELLS) do
        local k = 2 * math.pi / w.len
        local th = k * x - w.dir * math.sqrt(g * k) * 0.6 * t + w.phase
        up = up + w.a * (math.sin(th) - 0.22 * math.cos(2 * th))
    end
    return up * scale
end

local function surfaceAt(b, x)
    local f = (x - X0) / DX
    local i = math.floor(f)
    if i < 0 then return b.surf[0] or SEA_Y end
    if i >= COLS then return b.surf[COLS] or SEA_Y end
    local t = f - i
    return (b.surf[i] or SEA_Y) * (1 - t) + (b.surf[i + 1] or SEA_Y) * t
end

local function surfaceVelAt(b, x)
    local i = clamp(math.floor((x - X0) / DX + 0.5), 0, COLS)
    return b.surfVel[i] or 0
end

-- push the columns between x1 and x2 (y-down velocity)
local function pushColumns(b, x1, x2, dv)
    local i1 = clamp(math.floor((x1 - X0) / DX), 0, COLS)
    local i2 = clamp(math.ceil((x2 - X0) / DX), 0, COLS)
    for i = i1, i2 do
        if shoal[i] > 0 then b.v[i] = (b.v[i] or 0) + dv end
    end
end

---------------------------------------------------------------- shaders

local VARY = [[
varying vec2 wpos;
]]

local skyShader = love.graphics.newShader(VARY .. [[
extern float time;
extern vec2 sun;
extern float horizon;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
    float v = 0.0; float a = 0.5;
    for (int i = 0; i < 5; i++) { v += a * vnoise(p); p *= 2.03; a *= 0.5; }
    return v;
}
#ifdef PIXEL
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    float t = clamp((horizon - wpos.y) / 2600.0, 0.0, 1.0);
    vec3 zenith = vec3(0.16, 0.40, 0.76);
    vec3 low = vec3(0.80, 0.88, 0.92);
    vec3 col = mix(low, zenith, pow(t, 0.45));
    float d = length(wpos - sun);
    col += vec3(1.0, 0.92, 0.75) * (smoothstep(190.0, 150.0, d) + exp(-d / 260.0) * 0.5 + exp(-d / 1600.0) * 0.18);
    float c = fbm(vec2(wpos.x * 0.00032 + time * 0.004, wpos.y * 0.0011));
    c = smoothstep(0.52, 0.78, c) * smoothstep(0.03, 0.25, t);
    col = mix(col, vec3(0.97, 0.97, 0.98), c * 0.85);
    return vec4(col, 1.0);
}
#endif
#ifdef VERTEX
vec4 position(mat4 tp, vec4 vp) { wpos = vp.xy; return tp * vp; }
#endif
]])

-- the far sea: the top of the water, seen at a slant, from the horizon to the near surface
local farShader = love.graphics.newShader(VARY .. [[
varying float vTop;
varying float vBot;
extern float time;
extern float sunX;
#ifdef VERTEX
attribute float Top;
attribute float Bot;
vec4 position(mat4 tp, vec4 vp) { wpos = vp.xy; vTop = Top; vBot = Bot; return tp * vp; }
#endif
#ifdef PIXEL
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    float t = clamp((wpos.y - vTop) / max(vBot - vTop, 1.0), 0.0, 1.0); // 0 horizon .. 1 near
    float persp = 1.0 / (0.08 + t * 0.92);                                // farther = squashed
    vec3 horizonCol = vec3(0.62, 0.76, 0.82);
    vec3 nearCol = vec3(0.07, 0.33, 0.45);
    vec3 col = mix(horizonCol, nearCol, pow(t, 0.7));
    // wave streaks: long in x, packed tighter towards the horizon
    vec2 p = vec2(wpos.x * 0.0035, (wpos.y - vTop) * 0.06 * persp * 0.25);
    float streak = vnoise(p + vec2(time * 0.05, -time * 0.35)) * 0.6 + vnoise(p * 2.7 + vec2(-time * 0.08, -time * 0.6)) * 0.4;
    col += vec3(0.75, 0.85, 0.9) * (streak - 0.5) * 0.16 * (1.0 - t * 0.5);
    // the sun's glitter path: a column under the sun, wider near you
    float g = exp(-pow((wpos.x - sunX) / (250.0 + 1300.0 * t), 2.0));
    float n = vnoise(vec2(wpos.x * 0.03, (wpos.y - vTop) * 0.35 * persp) + vec2(time * 0.7, -time * 2.0));
    float spark = smoothstep(0.80, 0.93, n) * g;
    col += vec3(1.0, 0.95, 0.82) * (spark * 1.4 + g * 0.18 * (1.0 - t));
    // a thin haze at the horizon
    col = mix(col, vec3(0.84, 0.9, 0.92), smoothstep(0.12, 0.0, t) * 0.7);
    return vec4(col, 1.0);
}
#endif
]])

local sandShader = love.graphics.newShader(VARY .. [[
varying float vTop;
#ifdef VERTEX
attribute float Top;
vec4 position(mat4 tp, vec4 vp) { wpos = vp.xy; vTop = Top; return tp * vp; }
#endif
#ifdef PIXEL
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    float d = wpos.y - vTop; // below the sand's top
    vec3 top = vec3(0.86, 0.76, 0.56);
    vec3 under = vec3(0.55, 0.43, 0.30);
    vec3 col = mix(top, under, smoothstep(0.0, 900.0, d));
    float grain = hash(floor(wpos / 6.0)) * 0.10 + vnoise(wpos * 0.01) * 0.12 + vnoise(wpos * 0.0025) * 0.1;
    col *= 0.88 + grain;
    float layers = vnoise(vec2(wpos.x * 0.002, wpos.y * 0.02));
    col *= 0.94 + 0.08 * smoothstep(0.4, 0.6, layers);
    col *= 1.0 - 0.25 * smoothstep(0.0, 18.0, d) * smoothstep(60.0, 18.0, d); // a darker lip under the top
    return vec4(col, 1.0);
}
#endif
]])

-- the phone gets one caustic sample and no colour fringes (PHONE), the desktop three
local PHONE = love.system.getOS() == 'iOS' or love.system.getOS() == 'Android'
local waterShader = love.graphics.newShader((PHONE and '#define PHONE\n' or '') .. VARY .. [[
varying float vSurf;
varying float vFoam;
varying float vSlope;
extern Image scene;
extern float time;
extern float pxPerWorld;
extern float clarity;
extern float refraction;
extern float caustics;
extern float rays;
extern float mirror;
extern float blur;
extern float specks;
extern float causticSize; // 1 in the sea, smaller in a cup
extern float viewDepth;   // how much water we look through: the sea is deep, a cup thin
extern float bend;        // how much it bends what's behind: less in a thin cup
#ifdef VERTEX
attribute float SurfY;
attribute float Foam;
attribute float Slope;
vec4 position(mat4 tp, vec4 vp) { wpos = vp.xy; vSurf = SurfY; vFoam = Foam; vSlope = Slope; return tp * vp; }
#endif
#ifdef PIXEL
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
// the well-known tileable water caustic (after Dave Hoskins / joltz0r)
float caustic(vec2 uv, float t) {
    vec2 p = mod(uv * 6.28318, 6.28318) - 250.0;
    vec2 i = p;
    float c = 1.0;
    float inten = 0.005;
    for (int n = 0; n < 4; n++) {
        float tt = t * (1.0 - (3.5 / float(n + 1)));
        i = p + vec2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));
        c += 1.0 / length(vec2(p.x / (sin(i.x + tt) / inten), p.y / (cos(i.y + tt) / inten)));
    }
    c /= 4.0;
    c = 1.17 - pow(c, 1.4);
    return pow(abs(c), 8.0);
}
const vec3 ABSORB = vec3(0.00105, 0.00030, 0.00017);
vec3 waterColAt(float depth) {
    return mix(vec3(0.10, 0.52, 0.58), vec3(0.005, 0.05, 0.13), 1.0 - exp(-depth / (1300.0 * clarity)));
}
// a scene sample (premultiplied) as seen at this depth: light lost on the way down and back
vec3 shade(vec4 c, float depth, vec3 caus) {
    vec3 T = exp(-ABSORB / clarity * depth);
    vec3 Tv = exp(-ABSORB / clarity * viewDepth);
    vec3 lit = c.rgb * T * (1.0 + caus * 1.4) + caus * 0.25 * c.a * T;
    return waterColAt(depth) * (1.0 - c.a * Tv) + lit * Tv;
}
// the scene, softer the deeper it is (light scatters on the way)
vec4 sceneAt(vec2 uv, float r) {
    vec2 ss = love_ScreenSize.xy;
    vec4 c = Texel(scene, uv) * 0.4;
    c += Texel(scene, uv + vec2(r, r * 0.6) / ss) * 0.15;
    c += Texel(scene, uv + vec2(-r, -r * 0.6) / ss) * 0.15;
    c += Texel(scene, uv + vec2(r * 0.6, -r) / ss) * 0.15;
    c += Texel(scene, uv + vec2(-r * 0.6, r) / ss) * 0.15;
    return c;
}
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    float depth = max(wpos.y - vSurf, 0.0);
    float near = exp(-depth / 500.0);
    vec2 ss = love_ScreenSize.xy;
    // refraction: bend the scene by a moving wobble, more near the surface
    vec2 wob = vec2(sin(wpos.y * 0.011 + time * 1.9 + wpos.x * 0.004) + 0.5 * sin(wpos.x * 0.027 - time * 2.6),
                    cos(wpos.x * 0.009 + time * 1.5) + 0.5 * cos(wpos.y * 0.023 + time * 2.2));
    vec2 off = wob * (7.0 + 16.0 * near) * pxPerWorld * refraction * bend;
    off.y = max(off.y, -depth * pxPerWorld); // never pull the picture from above the surface
    vec2 uv = (sc + off) / ss;
    float br = blur * clamp(depth / 2200.0, 0.0, 1.0) * 30.0 * pxPerWorld;
    vec4 sceneC = sceneAt(uv, br);
#ifndef PHONE
    // red and blue bend a little apart
    sceneC.r = mix(sceneC.r, Texel(scene, (sc + off * 1.35) / ss).r, 0.6);
    sceneC.b = mix(sceneC.b, Texel(scene, (sc + off * 0.65) / ss).b, 0.6);
#endif
    vec3 T = exp(-ABSORB / clarity * depth);
    // caustics on the things in the water
    vec2 cuv = vec2(wpos.x + sin(wpos.y * 0.002) * 120.0, wpos.y) / (1100.0 * causticSize);
    float ct = time * 0.55 + 23.0;
#ifdef PHONE
    vec3 caus = vec3(caustic(cuv, ct)) * vec3(0.9, 1.0, 1.0);
#else
    vec3 caus = vec3(caustic(cuv + vec2(0.004, 0.0), ct), caustic(cuv, ct), caustic(cuv - vec2(0.004, 0.0), ct));
#endif
    caus = min(caus, vec3(1.0)) * caustics * 1.1 * smoothstep(0.0, 120.0, depth);
    vec3 col = shade(sceneC, depth, caus);
    // the underside of the surface: a silvery mirror of what's below it
    float M = 150.0;
    if (depth < M && mirror > 0.0) {
        float rd = 2.0 * M - depth;
        vec2 ruv = (sc + vec2(off.x * 1.8, (rd - depth) * pxPerWorld + off.y * 2.5)) / ss;
        vec3 refl = shade(Texel(scene, ruv), rd, vec3(0.0));
        refl = refl * 1.25 + vec3(0.03, 0.06, 0.07);
        float w = pow(1.0 - depth / M, 1.6) * 0.6 * mirror;
        col = mix(col, refl, w);
    }
    // light shafts: slanted, slow, fading with depth
    float q = wpos.x + wpos.y * 0.32;
    float r = sin(q * 0.0021 + time * 0.13) * sin(q * 0.0057 - time * 0.21) * sin(q * 0.00093 + time * 0.05 + 1.0);
    float shaft = pow(max(r, 0.0), 1.2) * exp(-depth / 1700.0) * smoothstep(0.0, 200.0, depth);
    col += vec3(0.55, 0.85, 0.85) * shaft * 0.32 * rays;
    // specks drifting in the water, brighter in the shafts and near the top
    if (specks > 0.0) {
        for (int l = 0; l < 2; l++) {
            float cell = l == 0 ? 70.0 : 130.0;
            vec2 sp = wpos / cell + vec2(time * 0.04 * (1.0 + float(l)), time * 0.06);
            vec2 id = floor(sp);
            float h = hash(id + float(l) * 17.0);
            if (h > 0.9) {
                vec2 at = id + vec2(hash(id + 3.1), hash(id + 7.7)) * 0.8 + 0.1;
                float d = length(sp - at) * cell * pxPerWorld; // in pixels
                float dot = smoothstep(1.8 + float(l), 0.4, d);
                col += vec3(0.75, 0.9, 0.85) * dot * (0.12 + shaft * 1.2) * exp(-depth / 1800.0) * specks;
            }
        }
    }
    // just under the surface: a sheen, then the bright line itself, with glints on the crests
    col += vec3(0.10, 0.16, 0.16) * exp(-depth / 70.0);
    float lineW = 3.5 / pxPerWorld;
    float lip = 1.0 - smoothstep(lineW * 0.6, lineW * 1.6, depth);
    float crest = clamp(0.6 - vSlope * 6.0, 0.0, 1.0); // facing up to the sun
    col = mix(col, vec3(0.88, 0.97, 1.0), lip * (0.7 + 0.3 * crest));
    float gl = smoothstep(0.78, 0.92, vnoise(vec2(wpos.x * 0.018 - time * 1.3, time * 0.9)));
    float glBand = 1.0 - smoothstep(lineW, lineW * 3.0, depth);
    col += vec3(1.0, 0.97, 0.85) * gl * glBand * (0.4 + crest);
    // foam where the water was stirred
    vec2 fp = vec2(wpos.x * 0.06, depth * 0.12) + vec2(time * 0.5, 0.0);
    float fn = vnoise(fp) * 0.5 + vnoise(fp * 2.3 + vec2(-time, 0.0)) * 0.3 + hash(floor(wpos / 4.0)) * 0.2;
    float foamBand = exp(-depth / (10.0 + 40.0 * vFoam));
    float foam = smoothstep(0.72 - vFoam * 0.25, 0.80 - vFoam * 0.25, fn) * foamBand * clamp(vFoam * 1.5, 0.0, 1.0);
    col = mix(col, vec3(0.93, 0.97, 1.0), foam * 0.6);
    return vec4(col, 1.0);
}
#endif
]])

-- Poured water and splash drops: soft blobs added up in a field canvas, then shown as water
-- where the field is over the line. Its slope bends what's behind it (the glass spike's trick:
-- roundness from the shape), a bright edge, a highlight from the top left.
local streamShader = love.graphics.newShader([[
extern Image scene;
extern Image field;
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec2 ss = love_ScreenSize.xy;
    vec2 uv = sc / ss;
    float f = Texel(field, uv).r;
    if (f < 0.3) discard;
    vec2 d = 2.0 / ss;
    vec2 n = vec2(Texel(field, uv + vec2(d.x, 0.0)).r - Texel(field, uv - vec2(d.x, 0.0)).r,
                  Texel(field, uv + vec2(0.0, d.y)).r - Texel(field, uv - vec2(0.0, d.y)).r);
    float thick = smoothstep(0.3, 1.0, f);
    vec3 c = Texel(scene, uv - n * 6.0 * (1.0 - thick * 0.5)).rgb;
    c = c * vec3(0.86, 0.95, 0.98) + vec3(0.03, 0.08, 0.10) * thick;
    float edge = 1.0 - smoothstep(0.3, 0.5, f);
    c = mix(c, vec3(0.88, 0.97, 1.0), edge * 0.75);
    vec3 N = normalize(vec3(-n * 3.0, 0.35));
    float hi = pow(max(dot(N, normalize(vec3(-0.5, -0.6, 0.6))), 0.0), 18.0);
    c += vec3(1.0, 0.98, 0.92) * hi * 0.8;
    return vec4(c, smoothstep(0.3, 0.36, f));
}
]])

local blobImage
do
    local size = 64
    local data = love.image.newImageData(size, size)
    data:mapPixel(function(x, y)
        local dx, dy = (x + 0.5) / size * 2 - 1, (y + 0.5) / size * 2 - 1
        local v = math.max(0, 1 - (dx * dx + dy * dy))
        v = v * v
        return v, v, v, v
    end)
    blobImage = love.graphics.newImage(data)
end
local BLOB = 2.4 -- a drop's blob reaches this many radii, so neighbours run together

---------------------------------------------------------------- meshes

local waterMesh = love.graphics.newMesh({
    { 'VertexPosition', 'float', 2 }, { 'VertexTexCoord', 'float', 2 },
    { 'SurfY', 'float', 1 }, { 'Foam', 'float', 1 }, { 'Slope', 'float', 1 },
}, (COLS + 1) * 2, 'strip', 'stream')

local farMesh = love.graphics.newMesh({
    { 'VertexPosition', 'float', 2 }, { 'VertexTexCoord', 'float', 2 },
    { 'Top', 'float', 1 }, { 'Bot', 'float', 1 },
}, (COLS + 1) * 2, 'strip', 'stream')

local sandMesh
local function buildSand()
    local verts = {}
    local SX0, SX1 = X0 - 4000, LAND_X + LAND_W + 4000
    local n = math.floor((SX1 - SX0) / DX)
    for i = 0, n do
        local x = SX0 + i * DX
        local top = floorAt(math.max(x, X0))
        verts[#verts + 1] = { x, top, 0, 0, top }
        verts[#verts + 1] = { x, SAND_BOTTOM, 0, 0, top }
    end
    sandMesh = love.graphics.newMesh({
        { 'VertexPosition', 'float', 2 }, { 'VertexTexCoord', 'float', 2 }, { 'Top', 'float', 1 },
    }, verts, 'strip', 'static')
end
buildSand()

local waterVerts, farVerts = {}, {}
local function updateMeshes(b)
    for i = 0, COLS do
        local x = colX(i)
        local surf = b.surf[i] or SEA_Y
        local bottom = math.max(surf, floorAt(x) + 220)
        local foam = b.foam[i] or 0
        -- the slope, down to the right positive; where the sun is (right) a crest faces it
        local slope = ((b.surf[i + 1] or surf) - (b.surf[i - 1] or surf)) / (2 * DX)
        local k = i * 2
        waterVerts[k + 1] = waterVerts[k + 1] or {}
        waterVerts[k + 2] = waterVerts[k + 2] or {}
        local top, bot = waterVerts[k + 1], waterVerts[k + 2]
        top[1], top[2], top[3], top[4], top[5], top[6], top[7] = x, surf, 0, 0, surf, foam, math.abs(slope)
        bot[1], bot[2], bot[3], bot[4], bot[5], bot[6], bot[7] = x, bottom, 0, 1, surf, foam, math.abs(slope)
        -- the far sea's back line moves slower and less (it's far away)
        local back = SEA_Y - BAND - swellUp(x * 0.35 + 900, b.time * 0.5, b.settings.swell) * 0.15
        farVerts[k + 1] = farVerts[k + 1] or {}
        farVerts[k + 2] = farVerts[k + 2] or {}
        local ft, fb = farVerts[k + 1], farVerts[k + 2]
        ft[1], ft[2], ft[3], ft[4], ft[5], ft[6] = x, back, 0, 0, back, SEA_Y
        fb[1], fb[2], fb[3], fb[4], fb[5], fb[6] = x, surf + 1, 0, 1, back, SEA_Y
    end
    waterMesh:setVertices(waterVerts)
    farMesh:setVertices(farVerts)
end

---------------------------------------------------------------- the world in it

local function destroyFloor(b)
    if b.floor and not b.floor:isDestroyed() then b.floor:destroy() end
    b.floor = nil
end

local function buildFloor(b)
    destroyFloor(b)
    local flat = {}
    flat[#flat + 1], flat[#flat + 2] = X0 - 400, SEA_Y - 3000
    for i = 0, COLS, 2 do
        local x = colX(i)
        flat[#flat + 1], flat[#flat + 2] = x, floorAt(x)
    end
    flat[#flat + 1], flat[#flat + 2] = LAND_X + LAND_W, BEACH_Y
    flat[#flat + 1], flat[#flat + 2] = LAND_X + LAND_W + 400, SEA_Y - 3000
    b.floor = love.physics.newBody(world, 0, 0, 'static')
    local fixture = love.physics.newFixture(b.floor, love.physics.newChainShape(false, unpack(flat)))
    fixture:setFriction(0.8)
end

local function aliveMipos(b)
    local alive = {}
    for _, inst in ipairs(b.mipos) do
        local torso = inst.parts and inst.parts.torso1
        if torso and torso.body and not torso.body:isDestroyed() then alive[#alive + 1] = inst end
    end
    return alive
end

local function spawnMipo(b, x, y)
    local inst = characterManager.createCharacter('humanoid', x, y, 0.3)
    if inst then characterManager.randomizeMipoConstrained(inst) end
    if inst then b.mipos[#b.mipos + 1] = inst end
end

local PROPS = {
    boat = function(x, y)
        return objectManager.addThing('trapezium', { x = x, y = y, width = 1300, width2 = 900, height = 220,
            bodyType = 'dynamic', label = 'sea-boat', density = 0.6 })
    end,
    crate = function(x, y)
        return objectManager.addThing('rectangle', { x = x, y = y, width = 260, height = 260,
            bodyType = 'dynamic', label = 'sea-crate', density = 0.5 })
    end,
    ball = function(x, y)
        return objectManager.addThing('circle', { x = x, y = y, radius = 140,
            bodyType = 'dynamic', label = 'sea-ball', density = 0.15 })
    end,
}

-- the outline of a custom-shape vessel in body coordinates (its vertices are where it was made)
local function localOutline(thing)
    local v = thing.vertices
    if not v then return nil end
    local out = {}
    for i = 1, #v, 2 do
        out[i], out[i + 1] = thing.body:getLocalPoint(v[i], v[i + 1])
    end
    return out
end

local function liquidExtra(body)
    for _, f in ipairs(body:getFixtures()) do
        local ud = f:getUserData()
        if ud and ud.extra and ud.subtype == 'liquid' then return ud.extra end
    end
end

-- on the beach: a table with cups, a bath on the sand, a bucket by the water
local TABLE_X, TABLE_TOP = LAND_X + 1800, BEACH_Y - 700
local function spawnTable(b)
    local top = objectManager.addThing('rectangle', { x = TABLE_X, y = TABLE_TOP + 40, width = 2000, height = 80,
        bodyType = 'static', label = 'seaside-table' })
    local legs = {}
    for _, dx in ipairs({ -850, 850 }) do
        legs[#legs + 1] = objectManager.addThing('rectangle', { x = TABLE_X + dx, y = (TABLE_TOP + 80 + BEACH_Y) / 2,
            width = 80, height = BEACH_Y - TABLE_TOP - 80, bodyType = 'static', label = 'seaside-table' })
    end
    if top then b.props[#b.props + 1] = { kind = 'table', body = top.body } end
    for _, leg in ipairs(legs) do b.props[#b.props + 1] = { kind = 'table', body = leg.body } end
end

local CUP_SCALE = 2.4
local function spawnCup(b, x, y, fill)
    local thing = props.makeCup(x, y, CUP_SCALE)
    if not thing then return end
    local extra = liquidExtra(thing.body)
    if fill and extra then extra.fill = fill end
    b.props[#b.props + 1] = { kind = 'cup', body = thing.body, outline = localOutline(thing), extra = liquidExtra(thing.body) }
end

local function spawnBath(b)
    local thing = props.makeBath(LAND_X + 4400, BEACH_Y - 380 * 1.5 / 2, 1.5)
    if thing then
        b.props[#b.props + 1] = { kind = 'bath', body = thing.body, outline = localOutline(thing), extra = liquidExtra(thing.body) }
    end
end

-- how much more than a Mipo each one floats (the floating force is mass-relative)
local LIGHTER = { boat = 2.2, crate = 1.5, ball = 5 }

local function spawnProp(b, kind, x, y)
    local thing = PROPS[kind](x, y)
    if thing then b.props[#b.props + 1] = { kind = kind, body = thing.body } end
end

local function aliveProps(b)
    local alive = {}
    for _, p in ipairs(b.props) do
        if p.body and not p.body:isDestroyed() then alive[#alive + 1] = p end
    end
    return alive
end

local function clearThings(b)
    for _, p in ipairs(aliveProps(b)) do objectManager.destroyBody(p.body) end
    for _, inst in ipairs(aliveMipos(b)) do
        for _, part in pairs(inst.parts) do
            if part.body and not part.body:isDestroyed() then objectManager.destroyBody(part.body) end
        end
    end
    b.props, b.mipos = {}, {}
end

local function stock(b)
    spawnProp(b, 'boat', -1200, -500)
    spawnProp(b, 'crate', 900, -800)
    spawnProp(b, 'ball', 2600, -700)
    spawnMipo(b, -1200, -1300)
    spawnMipo(b, 1800, -1200)
    spawnTable(b)
    local cupY = TABLE_TOP - 170 * CUP_SCALE / 2 - 2
    spawnCup(b, TABLE_X - 500, cupY, 0.75)
    spawnCup(b, TABLE_X + 300, cupY, 0.4)
    spawnCup(b, LAND_X + 500, BEACH_Y - 170 * CUP_SCALE / 2 - 2, 0.6)
    spawnBath(b)
    spawnMipo(b, LAND_X + 3000, BEACH_Y - 900)
end

local function resetWater(b)
    for i = 0, COLS do b.h[i], b.v[i], b.foam[i] = 0, 0, 0 end
    b.drops, b.bubbles = {}, {}
    if b.pour then
        for i = b.pour.n - 1, 0, -1 do fluid.remove(b.pour, i) end
    end
end

---------------------------------------------------------------- floating

-- the part of a polygon (flat x,y list) under the line through (x1,y1)-(x2,y2): y-down,
-- so "under" is y > the line
local clipOut = {}
local function clipUnder(poly, n, x1, y1, x2, y2)
    local slope = (x2 ~= x1) and (y2 - y1) / (x2 - x1) or 0
    local m = 0
    local px, py = poly[n * 2 - 1], poly[n * 2]
    local pf = py - (y1 + (px - x1) * slope)
    for k = 1, n do
        local cx, cy = poly[k * 2 - 1], poly[k * 2]
        local cf = cy - (y1 + (cx - x1) * slope)
        if cf >= 0 then
            if pf < 0 then
                local t = pf / (pf - cf)
                clipOut[m + 1], clipOut[m + 2] = px + (cx - px) * t, py + (cy - py) * t
                m = m + 2
            end
            clipOut[m + 1], clipOut[m + 2] = cx, cy
            m = m + 2
        elseif pf >= 0 then
            local t = pf / (pf - cf)
            clipOut[m + 1], clipOut[m + 2] = px + (cx - px) * t, py + (cy - py) * t
            m = m + 2
        end
        px, py, pf = cx, cy, cf
    end
    return clipOut, m / 2
end

local function areaCentroid(poly, n)
    local a, cx, cy = 0, 0, 0
    for k = 1, n do
        local x1, y1 = poly[k * 2 - 1], poly[k * 2]
        local j = (k % n) + 1
        local x2, y2 = poly[j * 2 - 1], poly[j * 2]
        local cr = x1 * y2 - x2 * y1
        a = a + cr
        cx = cx + (x1 + x2) * cr
        cy = cy + (y1 + y2) * cr
    end
    if math.abs(a) < 1e-6 then return 0, 0, 0 end
    return math.abs(a) / 2, cx / (3 * a), cy / (3 * a)
end

local polyBuf = {}
local function fixturePolygon(body, shape)
    local kind = shape:type()
    if kind == 'PolygonShape' then
        local pts = { body:getWorldPoints(shape:getPoints()) }
        for k = 1, #pts do polyBuf[k] = pts[k] end
        return polyBuf, #pts / 2
    elseif kind == 'CircleShape' then
        local cx, cy = body:getWorldPoint(shape:getPoint())
        local r = shape:getRadius()
        for k = 0, 11 do
            local a = k / 12 * math.pi * 2
            polyBuf[k * 2 + 1], polyBuf[k * 2 + 2] = cx + math.cos(a) * r, cy + math.sin(a) * r
        end
        return polyBuf, 12
    end
    return nil, 0
end

local function splash(b, x, y, width, vy, into)
    local strength = clamp(math.abs(vy), 0, 2500)
    pushColumns(b, x - width / 2, x + width / 2, (into and 1 or -0.5) * vy * 0.35 * clamp(width / 400, 0.3, 1))
    local count = math.floor(strength / 90)
    for _ = 1, count do
        local sx = x + (love.math.random() - 0.5) * width
        local side = (sx - x) / math.max(width, 1)
        b.drops[#b.drops + 1] = {
            x = sx, y = surfaceAt(b, sx) - 5,
            vx = side * strength * 0.9 + (love.math.random() - 0.5) * 300,
            vy = -strength * (0.35 + love.math.random() * 0.5),
            r = 8 + love.math.random() * 18, life = 2,
        }
    end
    if into then
        for _ = 1, math.floor(strength / 60) do
            b.bubbles[#b.bubbles + 1] = {
                x = x + (love.math.random() - 0.5) * width, y = y + love.math.random() * 300,
                r = 6 + love.math.random() * 22, phase = love.math.random() * 6, life = 6,
            }
        end
    end
end

local function float(b, dt)
    local _, gy = world:getGravity()
    local set = b.settings
    local lighter = {}
    for _, p in ipairs(b.props) do
        if not p.body:isDestroyed() then lighter[p.body] = LIGHTER[p.kind] end
    end
    for _, body in ipairs(world:getBodies()) do repeat
        if body:getType() ~= 'dynamic' or body:isDestroyed() then break end
        local bx, by = body:getPosition()
        if bx < X0 or bx > X0 + WORLD_W then break end
        local wetArea, totalArea = 0, 0
        local minX, maxX = math.huge, -math.huge
        for _, fixture in ipairs(body:getFixtures()) do repeat
            if fixture:isSensor() then break end
            local _, _, mass = fixture:getMassData()
            if mass <= 0 then break end
            local poly, n = fixturePolygon(body, fixture:getShape())
            if n < 3 then break end
            local x1, x2, maxY = math.huge, -math.huge, -math.huge
            for k = 1, n do
                local x, y = poly[k * 2 - 1], poly[k * 2]
                if x < x1 then x1 = x end
                if x > x2 then x2 = x end
                if y > maxY then maxY = y end
            end
            local full = areaCentroid(poly, n)
            totalArea = totalArea + full
            local s1, s2 = surfaceAt(b, x1), surfaceAt(b, x2)
            if maxY <= math.min(s1, s2) then break end -- all of it above the water
            local clipped, m = clipUnder(poly, n, x1, s1, x2, s2)
            if m < 3 then break end
            local area, cx, cy = areaCentroid(clipped, m)
            if area <= 0 or full <= 0 then break end
            local frac = math.min(area / full, 1)
            wetArea = wetArea + area
            if x1 < minX then minX = x1 end
            if x2 > maxX then maxX = x2 end
            -- floating, at the middle of the wet part (that's what rights a boat)
            local up = mass * gy * frac * set.density * (lighter[body] or 1)
            -- drag against the water, which moves up and down with the waves near the top
            local vx, vy = body:getLinearVelocityFromWorldPoint(cx, cy)
            local depth = cy - surfaceAt(b, cx)
            local wvy = surfaceVelAt(b, cx) * math.exp(-math.max(depth, 0) / 400)
            local k = mass * frac * set.drag
            body:applyForce(-vx * k, -up - (vy - wvy) * k, cx, cy)
        until true end
        local wetFrac = totalArea > 0 and wetArea / totalArea or 0
        if wetFrac > 0 then
            body:applyTorque(-body:getInertia() * body:getAngularVelocity() * set.drag * 0.8 * wetFrac)
        end
        -- going in or coming out: a splash
        local was = b.wet[body] or 0
        if wetFrac > 0 and was == 0 then
            local _, vy = body:getLinearVelocity()
            if vy > 250 then splash(b, bx, by, math.max(maxX - minX, 100), vy, true) end
        elseif wetFrac == 0 and was > 0 then
            local _, vy = body:getLinearVelocity()
            if vy < -400 then splash(b, bx, by, 200, vy, false) end
        elseif wetFrac > 0 and wetFrac < 0.95 and maxX > minX then
            -- bobbing about at the surface stirs it a little
            local _, vy = body:getLinearVelocity()
            pushColumns(b, minX, maxX, vy * dt * 0.8 * wetFrac)
        end
        b.wet[body] = wetFrac
    until true end
end

---------------------------------------------------------------- waves

local STEP = 1 / 120
local function waves(b, dt)
    local c2 = 1300 * 1300 / (DX * DX)
    b.acc = (b.acc or 0) + math.min(dt, 0.05)
    while b.acc >= STEP do
        b.acc = b.acc - STEP
        local h, v = b.h, b.v
        for i = 0, COLS do
            if shoal[i] > 0 then
                local l = h[i - 1] or 0
                local r = h[i + 1] or 0
                if shoal[i - 1] == 0 or i == 0 then l = h[i] end -- the beach reflects
                if shoal[i + 1] == nil or shoal[i + 1] == 0 then r = h[i] end
                local a = c2 * (l + r - 2 * h[i]) - 6 * h[i] - 1.4 * v[i]
                v[i] = v[i] + a * STEP
            end
        end
        for i = 0, COLS do
            if shoal[i] > 0 then h[i] = clamp(h[i] + v[i] * STEP, -600, 600) else h[i], v[i] = 0, 0 end
        end
    end
    local swell = b.settings.swell
    for i = 0, COLS do
        local x = colX(i)
        local prev = b.surf[i]
        local surf = SEA_Y + b.h[i] - swellUp(x, b.time, swell) * shoal[i]
        b.surf[i] = surf
        b.surfVel[i] = prev and (surf - prev) / math.max(dt, 1e-3) or 0
        local stir = math.abs(b.v[i]) / 700
        -- swell crests foam a bit when they're steep
        local slope = math.abs(((b.surf[i - 1] or surf) - surf) / DX)
        b.foam[i] = math.max((b.foam[i] or 0) * math.exp(-dt * 0.7), clamp(stir + math.max(slope - 0.13, 0) * 3, 0, 1))
    end
end

---------------------------------------------------------------- pouring

local FLOW = 40000      -- area units a second through a rim at most
local POUR_H = 30       -- poured water is points of particle water (src/fluid.lua, WATERJAR WJ4)
local POINT_AREA = (0.62 * POUR_H) ^ 2 -- the water one point carries (they sit 0.62 h apart)
local POINT_R = 21      -- a point drawn as a drop this big (overlapping its neighbours: one stream)
local SOAK = 2.5        -- s a still point lies on the sand or the table before it soaks away

-- the poured water: one fluid for all the cups, made when first needed (kept on state)
local function pourWater(b)
    if not b.pour then
        b.pour = fluid.new({ h = POUR_H, floorY = BEACH_Y, dataNames = { 'from', 'age', 'still' } })
        fluid.calibrate(b.pour)
    end
    return b.pour
end

-- the vessels' water this frame: world hull, level, how much a full one holds
local function vesselWater(b)
    local out = {}
    for _, p in ipairs(aliveProps(b)) do
        if p.extra then
            local level, _, hull = liquid.water(p.extra, p.body)
            local c = liquid.container(p.extra, p.body)
            out[#out + 1] = { p = p, level = level, hull = hull, full = liquid.volume(c.hull, c.holes) }
        end
    end
    return out
end

local function insideConvex(poly, x, y)
    local n, sign = #poly, 0
    for i = 1, n, 2 do
        local j = (i + 2 > n) and 1 or i + 2
        local cross = (poly[j] - poly[i]) * (y - poly[i + 1]) - (poly[j + 1] - poly[i + 1]) * (x - poly[i])
        if cross ~= 0 then
            local sg = cross > 0 and 1 or -1
            if sign == 0 then sign = sg elseif sg ~= sign then return false end
        end
    end
    return true
end

-- What spills over a rim (liquid.update hands it to s.onSpill through state.liquidSpillHook)
-- leaves as drops from the rim's low corner, at most FLOW a second; the rest goes back in, so a
-- pouring cup stays full to the brim.
function s.onSpill(extra, body, spilled)
    local b = state.seaside
    if not b then return end
    local p
    for _, q in ipairs(b.props) do
        if q.extra == extra then p = q; break end
    end
    local c = liquid.container(extra, body)
    local full = liquid.volume(c.hull, c.holes)
    if not p or full <= 0 then return end
    local dt = math.min(love.timer.getDelta(), 1 / 30)
    local out = math.min(spilled, FLOW * dt)
    extra.fill = extra.fill + (spilled - out) / full
    p.carry = (p.carry or 0) + out
    local mx, my = liquid.mouthPoint(extra, body)
    if not mx then return end
    local cx, cy = body:getWorldCenter()
    local ox, oy = mx - cx, my - cy
    local len = math.max(math.sqrt(ox * ox + oy * oy), 1)
    local vx, vy = body:getLinearVelocityFromWorldPoint(mx, my)
    local push = 90 + 260 * math.min(out / (FLOW * dt), 1)
    local f = pourWater(b)
    local sp = 0.62 * POUR_H
    while p.carry >= POINT_AREA do
        p.carry = p.carry - POINT_AREA
        local j = love.math.random() - 0.5
        local i = fluid.add(f, mx + ox / len * sp + j * sp, my + j * sp * 0.5,
            vx + ox / len * push + j * 30, vy + oy / len * push * 0.3)
        if not i then -- no room for more points: it stays in the cup
            extra.fill = extra.fill + (p.carry + POINT_AREA) / full
            p.carry = 0
            break
        end
        f.data.from[i], f.data.age[i], f.data.still[i] = body, 0, 0
    end
end

-- The poured points: into a cup or the bath they join its water, into the sea they join it; on
-- the sand or the table they puddle, and a puddle soaks away.
local function pourPoints(b, dt, vessels)
    local f = b.pour
    if not f or f.n == 0 then return end
    fluid.update(f, dt)
    local from, age, still = f.data.from, f.data.age, f.data.still
    for i = f.n - 1, 0, -1 do repeat
        local x, y = f.x[i], f.y[i]
        local vx, vy = x - f.px[i], y - f.py[i]
        age[i] = (age[i] or 0) + dt
        local gone = false
        if vy >= 0 then
            for _, v in ipairs(vessels) do
                if v.full > 0 and (v.p.body ~= from[i] or age[i] > 0.4) and insideConvex(v.hull, x, y)
                    and (not v.level or y > v.level - POINT_R) then
                    v.p.extra.fill = math.min(1, v.p.extra.fill + POINT_AREA / v.full)
                    gone = true
                    break
                end
            end
        end
        if not gone and x < LAND_X and y > surfaceAt(b, x) then
            pushColumns(b, x, x, POINT_R * 1.5) -- into the sea
            gone = true
        end
        if not gone and vx * vx + vy * vy < 1 then
            still[i] = (still[i] or 0) + dt
            gone = still[i] > SOAK + (i % 7) * 0.3
        elseif not gone then
            still[i] = 0
        end
        if gone or y > SEA_Y + DEEP + 600 then fluid.remove(f, i) end
    until true end
end

local function particles(b, dt)
    local _, gy = world:getGravity()
    local keep = {}
    local drops = b.drops
    b.drops = {}
    for _, d in ipairs(drops) do repeat
        d.vy = d.vy + gy * dt
        d.x, d.y = d.x + d.vx * dt, d.y + d.vy * dt
        d.life = d.life - dt
        if d.life <= 0 then break end
        if d.vy > 0 and d.x < LAND_X and d.y > surfaceAt(b, d.x) then
            pushColumns(b, d.x, d.x, d.r * 1.5) -- into the sea
            break
        end
        if d.y > floorAt(d.x) then break end
        keep[#keep + 1] = d
    until true end
    b.drops = keep
    keep = {}
    for _, bb in ipairs(b.bubbles) do
        bb.y = bb.y - (120 + bb.r * 9) * dt
        bb.x = bb.x + math.sin(b.time * 5 + bb.phase) * 60 * dt
        bb.life = bb.life - dt
        if bb.y > surfaceAt(b, bb.x) + bb.r and bb.life > 0 then keep[#keep + 1] = bb end
    end
    b.bubbles = keep
end

---------------------------------------------------------------- callbacks

function s.onStart()
    worldState.paused = false
    state.liquidSpillHook = function(...) return s.onSpill(...) end -- pour it out (s.onSpill)
    state.liquidDrawHook = function(w) -- the cups' water, drawn in s.draw (drawCupWater)
        local sb = state.seaside
        if sb and sb.cupWater then sb.cupWater[#sb.cupWater + 1] = w end
    end
    local b = sea()
    if #b.h == 0 then resetWater(b) end
    buildFloor(b)
    b.props = aliveProps(b)
    b.mipos = aliveMipos(b)
    if #b.props == 0 and #b.mipos == 0 then stock(b) end
    waves(b, 0)
    camera.setBounds(X0, SEA_Y - 4500, LAND_X + LAND_W, SEA_Y + DEEP + 600)
end

function s.onUnload()
    state.liquidDrawHook = nil
    state.liquidSpillHook = nil
    local b = state.seaside
    if not b then return end
    destroyFloor(b)
    if b.savedDrawBodies ~= nil then state.world.debugDrawBodies = b.savedDrawBodies end
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local b = sea()
    local mx, my = mouseWorldPos()
    if key == 'm' then spawnMipo(b, mx, my)
    elseif key == 'b' then spawnProp(b, 'boat', mx, my)
    elseif key == 'c' then spawnProp(b, 'crate', mx, my)
    elseif key == 'o' then spawnProp(b, 'ball', mx, my)
    elseif key == 'u' then spawnCup(b, mx, my, 0.6)
    elseif key == 'w' then pushColumns(b, X0 + 600, X0 + 1500, 900)
    elseif key == 'h' then b.showPanel = not b.showPanel
    elseif key == 'r' then
        clearThings(b)
        b.wet = {}
        resetWater(b)
        stock(b)
    end
end

local panelRect = { 20, 0, 400, 0 }
local function overPanel(b)
    if not b.showPanel or ui.isPanelFolded('•• seaside ••') then return false end
    local mx, my = love.mouse.getPosition()
    local r = panelRect
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

function s.update(dt)
    local b = sea()
    b.time = b.time + dt
    -- a press on open water (not on a thing) pulls the surface along
    local down = state.playMode and love.mouse.isDown(1)
    if down and not b.stirring and #getInteractedWithPointer() == 0 and not overPanel(b) then
        b.stirring = true
        local _, my = mouseWorldPos()
        b.lastMY = my
    elseif not down then
        b.stirring = nil
    end
    if b.stirring then
        local mx, my = mouseWorldPos()
        local surf = surfaceAt(b, mx)
        if math.abs(my - surf) < 700 then
            pushColumns(b, mx - 120, mx + 120, (my - b.lastMY) * 4)
        end
        b.lastMY = my
    end
    waves(b, dt)
    float(b, dt)
    particles(b, dt)
    pourPoints(b, dt, vesselWater(b))
end

---------------------------------------------------------------- drawing

local sceneCanvas, prevCanvas, fieldCanvas
local function ensureCanvas()
    local w, h = love.graphics.getDimensions()
    if not sceneCanvas or sceneCanvas:getWidth() ~= w or sceneCanvas:getHeight() ~= h then
        local _, _, flags = love.window.getMode()
        sceneCanvas = love.graphics.newCanvas(w, h, { msaa = flags.msaa or 0 })
        fieldCanvas = love.graphics.newCanvas(w, h)
    end
end

local function viewRect()
    local w, h = love.graphics.getDimensions()
    local x1, y1 = cam:getWorldCoordinates(0, 0)
    local x2, y2 = cam:getWorldCoordinates(w, h)
    return math.min(x1, x2), math.min(y1, y2), math.max(x1, x2), math.max(y1, y2)
end

local KELP = {}
do
    local rng = love.math.newRandomGenerator(7)
    for _ = 1, 26 do
        local x = X0 + 1500 + rng:random() * (WORLD_W - 3000)
        local fl = floorAt(x)
        if fl > SEA_Y + 900 then
            KELP[#KELP + 1] = { x = x, base = fl + 20, len = (fl - SEA_Y) * (0.35 + rng:random() * 0.45),
                phase = rng:random() * 6, w = 18 + rng:random() * 16, shade = 0.8 + rng:random() * 0.3 }
        end
    end
end

local function drawKelp(t)
    love.graphics.setLineJoin('bevel')
    for _, k in ipairs(KELP) do
        local pts = {}
        local segs = 14
        for j = 0, segs do
            local f = j / segs
            local y = k.base - f * k.len
            local sway = (math.sin(t * 0.9 + k.phase + f * 2.2) * 120 + math.sin(t * 1.7 + k.phase * 2 + f * 4) * 30) * f * f
            pts[#pts + 1] = k.x + sway
            pts[#pts + 1] = y
        end
        love.graphics.setColor(0.22 * k.shade, 0.38 * k.shade, 0.12 * k.shade, 1)
        love.graphics.setLineWidth(k.w)
        love.graphics.line(pts)
        love.graphics.setColor(0.32 * k.shade, 0.5 * k.shade, 0.18 * k.shade, 1)
        love.graphics.setLineWidth(k.w * 0.35)
        love.graphics.line(pts)
    end
    love.graphics.setLineWidth(1)
end

local INK = { 0.17, 0.12, 0.09, 1 }

-- a striped windbreak behind the table, so there's something to see bent through the cups
local function drawWindbreak(t)
    local x1, x2 = LAND_X + 700, LAND_X + 3300
    local top, n = BEACH_Y - 1050, 8
    local w = (x2 - x1) / n
    for i = 0, n - 1 do
        local a, c = x1 + i * w, x1 + (i + 1) * w
        local sag = math.sin(t * 1.3 + i) * 18
        if i % 2 == 0 then love.graphics.setColor(0.86, 0.3, 0.26, 1) else love.graphics.setColor(0.97, 0.94, 0.86, 1) end
        love.graphics.polygon('fill', a, top + sag, c, top - sag, c, BEACH_Y - 40, a, BEACH_Y - 40)
    end
    love.graphics.setColor(INK)
    love.graphics.setLineWidth(10)
    for i = 0, n do
        local x = x1 + i * w
        love.graphics.line(x, top - 60, x, BEACH_Y + 30)
    end
    love.graphics.setLineWidth(1)
end
local POTTERY = { cup = { 0.86, 0.52, 0.36, 1 }, bath = { 0.95, 0.93, 0.86, 1 }, table = { 0.62, 0.42, 0.24, 1 } }
local function drawVessel(p)
    local body = p.body
    love.graphics.setColor(POTTERY[p.kind])
    for _, fixture in ipairs(body:getFixtures()) do
        local shape = fixture:getShape()
        if not fixture:isSensor() and shape:type() == 'PolygonShape' then
            love.graphics.polygon('fill', body:getWorldPoints(shape:getPoints()))
        end
    end
    local verts = p.outline
    love.graphics.setColor(INK)
    love.graphics.setLineWidth(12)
    love.graphics.setLineJoin('bevel')
    if verts and #verts >= 6 then
        love.graphics.polygon('line', body:getWorldPoints(unpack(verts)))
    else
        for _, fixture in ipairs(body:getFixtures()) do
            local shape = fixture:getShape()
            if not fixture:isSensor() and shape:type() == 'PolygonShape' then
                love.graphics.polygon('line', body:getWorldPoints(shape:getPoints()))
            end
        end
    end
end

local function drawProps(b)
    for _, p in ipairs(aliveProps(b)) do
        local body = p.body
        if POTTERY[p.kind] then drawVessel(p) else
        for _, fixture in ipairs(body:getFixtures()) do
            local shape = fixture:getShape()
            if shape:type() == 'PolygonShape' then
                local pts = { body:getWorldPoints(shape:getPoints()) }
                if p.kind == 'boat' then love.graphics.setColor(0.62, 0.34, 0.18, 1)
                else love.graphics.setColor(0.78, 0.58, 0.32, 1) end
                love.graphics.polygon('fill', pts)
                love.graphics.setColor(INK)
                love.graphics.setLineWidth(14)
                love.graphics.polygon('line', pts)
                if p.kind == 'crate' then
                    love.graphics.setLineWidth(10)
                    love.graphics.line(pts[1], pts[2], pts[5], pts[6])
                    love.graphics.line(pts[3], pts[4], pts[7], pts[8])
                end
            elseif shape:type() == 'CircleShape' then
                local cx, cy = body:getWorldPoint(shape:getPoint())
                local r = shape:getRadius()
                local a = body:getAngle()
                local colors = { { 0.92, 0.25, 0.2 }, { 0.98, 0.95, 0.88 }, { 0.2, 0.45, 0.85 }, { 0.98, 0.95, 0.88 }, { 0.98, 0.8, 0.2 }, { 0.98, 0.95, 0.88 } }
                for j = 1, 6 do
                    love.graphics.setColor(colors[j])
                    love.graphics.arc('fill', cx, cy, r, a + (j - 1) * math.pi / 3, a + j * math.pi / 3)
                end
                love.graphics.setColor(INK)
                love.graphics.setLineWidth(12)
                love.graphics.circle('line', cx, cy, r)
            end
        end
        end
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

-- The cups' and the bath's water: liquid.draw hands it to us (state.liquidDrawHook) while the
-- world draws into the canvas, and s.draw draws it with the water shader once the canvas is done.
local CUP_FORMAT = {
    { 'VertexPosition', 'float', 2 }, { 'VertexTexCoord', 'float', 2 },
    { 'SurfY', 'float', 1 }, { 'Foam', 'float', 1 }, { 'Slope', 'float', 1 },
}
local cupMeshes = {} -- by the liquid's extra (a handful of cups)
local cupVerts = {}
local function drawCupWater(b)
    for _, w in ipairs(b.cupWater) do
        local line, n = w.line, #w.line / 2
        if n >= 2 then
            local mesh = cupMeshes[w.extra]
            if not mesh or mesh:getVertexCount() ~= n * 2 then
                mesh = love.graphics.newMesh(CUP_FORMAT, n * 2, 'strip', 'stream')
                cupMeshes[w.extra] = mesh
            end
            for i = 1, n do
                local x, y = line[i * 2 - 1], line[i * 2]
                local a, c = math.max(i - 1, 1), math.min(i + 1, n)
                local slope = math.abs((line[c * 2] - line[a * 2]) / math.max(line[c * 2 - 1] - line[a * 2 - 1], 1e-3))
                cupVerts[i * 2 - 1] = cupVerts[i * 2 - 1] or {}
                cupVerts[i * 2] = cupVerts[i * 2] or {}
                local top, bot = cupVerts[i * 2 - 1], cupVerts[i * 2]
                top[1], top[2], top[3], top[4], top[5], top[6], top[7] = x, y, 0, 0, y, 0, slope
                bot[1], bot[2], bot[3], bot[4], bot[5], bot[6], bot[7] = x, w.bottom, 0, 1, y, 0, slope
            end
            for i = n * 2 + 1, #cupVerts do cupVerts[i] = nil end
            mesh:setVertices(cupVerts)
            -- the hollow: the hull less the vessel itself
            love.graphics.stencil(function() love.graphics.polygon('fill', w.hull) end, 'replace', 1)
            love.graphics.stencil(function()
                for _, hole in ipairs(w.holes) do
                    if #hole >= 6 then love.graphics.polygon('fill', hole) end
                end
            end, 'replace', 0, true)
            love.graphics.setStencilTest('equal', 1)
            love.graphics.draw(mesh)
            love.graphics.setStencilTest()
        end
    end
    b.cupWater = {}
end

-- the drops (poured and splashed) as one water: blobs into the field, then the stream shader
local function drawStream(b)
    local f = b.pour
    local points = f and f.n or 0
    if #b.drops == 0 and points == 0 then return end
    local canvas = love.graphics.getCanvas()
    love.graphics.setCanvas(fieldCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode('add')
    love.graphics.setColor(1, 1, 1, 1)
    local half = blobImage:getWidth() / 2
    for _, d in ipairs(b.drops) do
        local speed = math.sqrt(d.vx * d.vx + d.vy * d.vy)
        local stretch = 1 + math.min(speed / 1400, 1.2)
        local sc = d.r * BLOB / half * math.min(d.life * 3, 1)
        love.graphics.draw(blobImage, d.x, d.y, math.atan2(d.vy, d.vx), sc * stretch, sc / math.sqrt(stretch), half, half)
    end
    -- the poured points (px a frame: their speed is 60 times that)
    local sc = POINT_R * BLOB / half
    for i = 0, points - 1 do
        local vx, vy = (f.x[i] - f.px[i]) * 60, (f.y[i] - f.py[i]) * 60
        local stretch = 1 + math.min(math.sqrt(vx * vx + vy * vy) / 1400, 1.2)
        love.graphics.draw(blobImage, f.x[i], f.y[i], math.atan2(vy, vx), sc * stretch, sc / math.sqrt(stretch), half, half)
    end
    love.graphics.setBlendMode('alpha')
    if canvas then love.graphics.setCanvas({ canvas, stencil = true }) else love.graphics.setCanvas() end
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setShader(streamShader)
    streamShader:send('scene', sceneCanvas)
    streamShader:send('field', fieldCanvas)
    local w, h = love.graphics.getDimensions()
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.setShader()
    love.graphics.pop()
end

function s.drawBelow()
    local b = state.seaside
    if not b or not b.surf[0] then return end
    b.cupWater = {}
    updateMeshes(b)
    local x1, y1, x2, y2 = viewRect()
    -- the world into a canvas, so the water can bend it; the sky too (the cups stand in front of it)
    ensureCanvas()
    prevCanvas = love.graphics.getCanvas()
    love.graphics.setCanvas({ sceneCanvas, stencil = true })
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setShader(skyShader)
    skyShader:send('time', b.time)
    skyShader:send('sun', { SUN_X, SUN_Y })
    skyShader:send('horizon', SEA_Y - BAND)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle('fill', x1 - 10, y1 - 10, x2 - x1 + 20, y2 - y1 + 20)
    love.graphics.setShader(farShader)
    farShader:send('time', b.time)
    farShader:send('sunX', SUN_X)
    love.graphics.draw(farMesh)
    love.graphics.setShader(sandShader)
    love.graphics.draw(sandMesh)
    love.graphics.setShader()
    drawKelp(b.time)
    drawWindbreak(b.time)
    love.graphics.setColor(1, 1, 1, 1)
    -- our props draw themselves; the plain body shapes would be lime green
    if state.playMode then
        b.savedDrawBodies = state.world.debugDrawBodies
        state.world.debugDrawBodies = false
    end
    b.drawing = true
end

function s.draw()
    local b = state.seaside
    if not (b and b.drawing) then return end
    b.drawing = nil
    if b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
    local set = b.settings
    drawProps(b)
    -- the world as it is, then the water over the part of it that's under the surface
    -- back to the caller's canvas, with a stencil for the cups' hollows (the smoke spec's has none)
    if prevCanvas then love.graphics.setCanvas({ prevCanvas, stencil = true }) else love.graphics.setCanvas() end
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode('alpha', 'premultiplied')
    love.graphics.draw(sceneCanvas, 0, 0)
    love.graphics.setBlendMode('alpha')
    love.graphics.pop()

    love.graphics.setShader(waterShader)
    waterShader:send('scene', sceneCanvas)
    waterShader:send('time', b.time)
    waterShader:send('pxPerWorld', cam:getScale() * love.graphics.getDPIScale())
    waterShader:send('clarity', set.clarity)
    waterShader:send('refraction', set.refraction)
    waterShader:send('caustics', set.caustics)
    waterShader:send('rays', set.rays)
    waterShader:send('mirror', set.mirror)
    waterShader:send('blur', set.blur)
    waterShader:send('specks', set.specks)
    waterShader:send('causticSize', 1)
    waterShader:send('viewDepth', 450)
    waterShader:send('bend', 1)
    love.graphics.draw(waterMesh)
    -- a cup is thin water: little tint, little bending, no silver underside, shafts or specks
    waterShader:send('causticSize', set.cupCaustics)
    waterShader:send('viewDepth', set.cupView)
    waterShader:send('bend', set.cupBend)
    waterShader:send('caustics', set.caustics * 0.5)
    waterShader:send('mirror', 0)
    waterShader:send('rays', 0)
    waterShader:send('specks', 0)
    drawCupWater(b)
    love.graphics.setShader()
    drawStream(b)

    -- bubbles rising, drops flying
    for _, bb in ipairs(b.bubbles) do
        love.graphics.setColor(0.8, 0.95, 1, 0.25)
        love.graphics.circle('fill', bb.x, bb.y, bb.r)
        love.graphics.setColor(0.9, 1, 1, 0.7)
        love.graphics.setLineWidth(3)
        love.graphics.circle('line', bb.x, bb.y, bb.r)
        love.graphics.circle('fill', bb.x - bb.r * 0.35, bb.y - bb.r * 0.35, bb.r * 0.22)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local b = state.seaside
    if not (b and state.playMode and b.showPanel) then return end
    ui.startFrame()
    local BH, pad, w = 36, 8, 400
    local rows = {
        { 'swell', 0, 3 }, { 'density', 0.3, 3 }, { 'drag', 0, 4 }, { 'clarity', 0.3, 3 },
        { 'refraction', 0, 3 }, { 'caustics', 0, 2 }, { 'rays', 0, 3 },
        { 'mirror', 0, 2 }, { 'blur', 0, 3 }, { 'specks', 0, 3 }, { 'cupCaustics', 0.05, 1 }, { 'cupView', 0, 450 }, { 'cupBend', 0, 1 },
    }
    local h = (BH + pad) * (#rows + 1) + pad + 24
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    panelRect[2], panelRect[4] = y0, h
    ui.panel(x0, y0, w, h, '•• seaside ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        for _, row in ipairs(rows) do
            local key = row[1]
            local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('seaside' .. key, x, y, 180, row[2], row[3], b.settings[key])
            if v then b.settings[key] = v + 0 end
            ui.label(x + 280, y, key)
        end
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'm b c o u: Mipo boat crate ball cup  w r h')
    end)
end

return s

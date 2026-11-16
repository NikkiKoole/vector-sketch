-- sea-looks: the sea's sky, far sea and sand shaders, shared by the sea and seaside spikes (they had the same
-- copies; 2026-11-16). Loaded with love.filesystem.load('scripts/spikes/sea-looks.lua')(): { sky, far, sand },
-- each a shader over a quad in world space (wpos). sky: time, sun {x, y}, horizon; far: time, sunX; sand.
-- The water itself is the engine's (src/render/water-shader.lua, waterLook in a scene script).
local lib = {}

local VARY = [[
varying vec2 wpos;
]]

lib.sky = love.graphics.newShader(VARY .. [[
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
lib.far = love.graphics.newShader(VARY .. [[
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

lib.sand = love.graphics.newShader(VARY .. [[
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

return lib

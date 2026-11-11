-- The see-through water shader (the sea spike's, SEA.md; seaside's, SEASIDE.md SS1): it bends the scene
-- behind it (refraction, a little blur deeper down), tints it by depth, caustics on what's in it, light
-- shafts and specks, a silver underside and a bright line at the surface, foam where it's stirred.
-- It reads the scene from a canvas (`scene`, the screen's size), so the world has to be drawn into one first,
-- and the water is drawn after, onto another target.
-- Vertex attributes: SurfY (the surface's y above this point: depth counts from it), Foam, Slope.
-- Per draw: viewDepth (how much water we look through: the sea 450, a cup 60), bend (how much it bends:
-- a cup 0.3), causticSize (1 in the sea, smaller in a cup), and clarity, refraction, caustics, rays,
-- mirror, blur, specks (0..). The phone gets one caustic sample and no colour fringes (PHONE).
-- Used by scripts/spikes/seaside (its sea, cups, bath) and src/water-look.lua (LIQUIDs in any scene).
local lib = {}

local PHONE = love.system.getOS() == 'iOS' or love.system.getOS() == 'Android'

lib.SOURCE = [[
varying vec2 wpos;
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
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
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
]]

local shader
-- made once, at first use
function lib.shader()
    if not shader then shader = love.graphics.newShader((PHONE and '#define PHONE\n' or '') .. lib.SOURCE) end
    return shader
end

-- Thin water (a cup, a bath): each { extra, line (the wavy surface: x, y, ...), hull, holes (the vessel
-- itself), bottom } as src/liquid.lua's draw hook hands it over, drawn as a strip from the surface down,
-- stencilled to the hollow. The shader set up before (lib.shader(), its scene and settings sent).
lib.CUP_FORMAT = {
    { 'VertexPosition', 'float', 2 }, { 'VertexTexCoord', 'float', 2 },
    { 'SurfY', 'float', 1 }, { 'Foam', 'float', 1 }, { 'Slope', 'float', 1 },
}
local cupMeshes = setmetatable({}, { __mode = 'k' }) -- by the liquid's extra (a handful of cups)
local cupVerts = {}
function lib.drawThin(list)
    for _, w in ipairs(list) do
        local line, n = w.line, #w.line / 2
        if n >= 2 then
            local mesh = cupMeshes[w.extra]
            if not mesh or mesh:getVertexCount() ~= n * 2 then
                mesh = love.graphics.newMesh(lib.CUP_FORMAT, n * 2, 'strip', 'stream')
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
end

return lib

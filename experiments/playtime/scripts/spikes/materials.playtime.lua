-- materials: a spike for the craft-table materials made by a shader only (felt, moss, cardboard, cellophane, candy, brass, jellybeans, crayon, paper)
-- After Nikki's AI mood pictures (docs/inspiration/ai-materials, docs/MATERIALS.md): Mipos in a
-- handmade diorama. No pictures here: every thing is one quad and the shader paints its
-- material from a seed. Most of the materials get their light from a fake height: how far in
-- from the edge a point is (round like a ball for felt, candy and brass, pillowy for a felt
-- block, sharp for cardboard). Edges carry the material: felt fuzz, moss clumps, torn paper
-- patches, cellophane creases.
--
-- The diorama: a paper wall with a crayon sun, a cardboard slab (its corrugated cut face showing)
-- with moss on top, cellophane water on the right. On it: a felt ball with dots, a felt block,
-- a cardboard box with collage patches, jingle bells, hard candies, jellybeans, two Mipos.
--
-- play mode (tab): drag things about.
-- keys: c a candy   b a bell   j a jellybean   m a Mipo   r new things   p the wall colour
--       t plain (flat colours, to compare)   h the panel

local s = {}

local SLAB = { x = -600, w = 3600, h = 120 }        -- its top at y = 0
local WATER = { x = 2200, w = 2000, top = 30, h = 560 }
local LIGHT = { -0.56, -0.83 }                     -- towards the light: the top left
local WALLS = {
    { 0.96, 0.86, 0.45 }, -- yellow
    { 0.78, 0.72, 0.88 }, -- lilac
    { 0.66, 0.86, 0.74 }, -- mint
    { 0.92, 0.6, 0.52 },  -- salmon
}
local CANDY = {
    { 0.92, 0.12, 0.12 }, { 0.98, 0.5, 0.08 }, { 0.98, 0.78, 0.12 }, { 0.45, 0.8, 0.15 },
    { 0.2, 0.55, 0.92 }, { 0.55, 0.25, 0.8 },
}
local BEANS = {
    { 0.9, 0.25, 0.25 }, { 0.98, 0.62, 0.2 }, { 0.98, 0.85, 0.3 }, { 0.4, 0.7, 0.35 },
    { 0.35, 0.55, 0.9 }, { 0.62, 0.42, 0.78 }, { 0.95, 0.55, 0.7 },
}
-- the shader's numbers for each material, and how far the quad reaches past the shape (fuzz,
-- clumps, waves)
local MAT = { felt = 0, moss = 1, cardboard = 2, cellophane = 3, candy = 4, brass = 5, bean = 6,
    wall = 7, crayon = 8, shadow = 9 }
local PAD = { felt = 40, moss = 60, cardboard = 6, cellophane = 50, candy = 6, brass = 4, bean = 4 }

local function materials()
    state.materials = state.materials or {
        things = {}, statics = {}, mipos = {}, wall = 1, plain = false, showPanel = true, time = 0,
        settings = { fuzz = 1, grain = 1, light = 1, crinkle = 1 },
    }
    return state.materials
end

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

local function pick(list) return list[love.math.random(#list)] end

---------------------------------------------------------------- the shader

local matShader = love.graphics.newShader([[
uniform float mat;      // 0 felt 1 moss 2 cardboard 3 cellophane 4 candy 5 brass 6 bean 7 wall 8 crayon 9 shadow
uniform float shape;    // 0 ellipse, 1 rounded box
uniform vec2 size;      // the shape's half size, world units
uniform vec2 ext;       // the quad's half size (the shape plus room for fuzz)
uniform float rr;       // the box's corner radius
uniform float puff;     // how far in from the edge it's round (the fake height)
uniform vec3 col1;
uniform vec3 col2;
uniform float seed;
uniform float time;
uniform vec2 lightDir;  // towards the light, in the thing's own frame
uniform float px;       // world units per screen pixel
uniform float flags;    // felt: 1 dots; cardboard: 1 collage patches, 2 corrugated cut face; bean: 1 stripes
uniform float alpha;    // the shadow's
uniform vec2 screen;    // pixels
uniform float fuzz;
uniform float grain;
uniform float light;
uniform float crinkle;
uniform float plain;
varying vec2 q0;

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    q0 = vertex_position.xy;
    return transform_projection * vertex_position;
}
#endif

#ifdef PIXEL
// hash without sine (Dave Hoskins, MIT)
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}
vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
               mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
    float s = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { s += a * vnoise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
    return s;
}
// cells: x = distance to the nearest centre, y = to the next; the cell and the way to its centre
vec2 voronoi(vec2 x, float t, out vec2 cellId, out vec2 toCentre) {
    vec2 n = floor(x), f = fract(x);
    float f1 = 8.0, f2 = 8.0;
    cellId = n; toCentre = vec2(0.0);
    for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
        vec2 g = vec2(float(i), float(j));
        vec2 o = hash22(n + g);
        o = 0.5 + 0.42 * sin(t + 6.2831 * o);
        vec2 r = g + o - f;
        float d = dot(r, r);
        if (d < f1) { f2 = f1; f1 = d; cellId = n + g; toCentre = r; }
        else if (d < f2) { f2 = d; }
    }
    return vec2(sqrt(f1), sqrt(f2));
}
// wool: stretched noise in three directions, so it's strands, not specks
float fibres(vec2 p) {
    float s = 0.0;
    for (int i = 0; i < 3; i++) {
        // the direction wanders over the thing, so the three don't make a triangle grid
        float a = float(i) * 2.09 + seed * 3.0 + (vnoise(p * 0.004 + float(i) * 5.1) - 0.5) * 5.0;
        vec2 d = vec2(cos(a), sin(a));
        vec2 q = vec2(dot(p, d), dot(p, vec2(-d.y, d.x)));
        s += vnoise(q * vec2(0.015, 0.09) + float(i) * 17.3);
    }
    return s / 3.0;
}

float sdBox(vec2 p, vec2 b, float r) {
    vec2 d = abs(p) - b + r;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}
float sdShape(vec2 p) {
    if (shape < 0.5) {
        float k0 = length(p / size);
        float k1 = length(p / (size * size));
        return k0 * (k0 - 1.0) / max(k1, 1e-4);
    }
    return sdBox(p, size, rr);
}
vec2 gradShape(vec2 p) {
    float e = 2.0 * px;
    float d = sdShape(p);
    return normalize(vec2(sdShape(p + vec2(e, 0.0)) - d, sdShape(p + vec2(0.0, e)) - d) + 1e-5);
}
// the fake height: round over the last `pf` units in from the edge
vec3 normalFrom(vec2 p, float d, float pf) {
    float t = clamp(-d / pf, 0.0, 1.0);
    float h = sqrt(max(1.0 - (1.0 - t) * (1.0 - t), 1e-3));
    float slope = (1.0 - t) / h;
    return normalize(vec3(gradShape(p) * slope, 1.0));
}
vec3 lightVec() { return normalize(vec3(lightDir, 0.9)); }
float diffuse(vec3 n) { return max(dot(n, lightVec()), 0.0); }
float specular(vec3 n, float k) { return pow(max(dot(reflect(-lightVec(), n), vec3(0.0, 0.0, 1.0)), 0.0), k); }
float cover(float d) { return clamp(0.5 - d / px, 0.0, 1.0); }

vec4 felt(vec2 p) {
    float d0 = sdShape(p);
    float d = d0 + (vnoise(p * 0.03 + seed) - 0.5) * 8.0;
    vec3 c = col1;
    if (flags > 0.5) {
        vec2 id; vec2 r;
        vec2 f = voronoi(p * 0.0055 + seed, 0.0, id, r);
        c = mix(c, col2 * (0.9 + 0.2 * hash12(id)), smoothstep(0.31, 0.27, f.x));
    }
    c *= 1.0 + (fibres(p) - 0.5) * 0.45 * grain;
    vec3 n = normalFrom(p, d0, puff);
    float lit = 0.62 + (0.55 * diffuse(n) - 0.12) * light;
    vec3 inside = c * lit;
    // loose fibres past the edge
    float reach = 28.0 * fuzz + 1e-3;
    float fz = fibres(p * 1.7 + 5.0);
    float strand = clamp((fz - 0.44 - d / reach * 0.35) * 5.0, 0.0, 1.0) * (1.0 - smoothstep(0.0, reach, d));
    float a = max(cover(d), strand * 0.85 * step(0.0, d) * step(0.01, fuzz));
    vec3 cl = mix(col1 * (0.75 + 0.2 * light), inside, cover(d));
    return vec4(cl * a, a);
}

vec4 moss(vec2 p) {
    vec2 id; vec2 r;
    vec2 f = voronoi(p * 0.022 + seed, 0.0, id, r);
    float dome = clamp(1.0 - f.x * 1.25, 0.0, 1.0);
    float d0 = sdShape(p);
    float d = d0 - dome * 42.0 * smoothstep(0.0, size.y, -p.y);  // clumps bump up the top
    float h = hash12(id);
    vec3 c = h < 0.3 ? vec3(0.33, 0.5, 0.16) : h < 0.6 ? vec3(0.45, 0.6, 0.2)
           : h < 0.85 ? vec3(0.26, 0.42, 0.18) : vec3(0.6, 0.68, 0.26);
    vec3 n = normalize(vec3(-r * 1.6, 1.0));
    c *= 0.6 + (0.65 * diffuse(n) - 0.1) * light;
    c *= 0.65 + 0.35 * dome;                                       // dark between the clumps
    c *= 1.0 + (vnoise(p * 0.09) - 0.5) * 0.3 * grain;             // flock
    // a few tiny flowers on top
    vec2 fid = floor(p * 0.012 + seed * 7.0);
    vec2 fc = (fid + 0.2 + 0.6 * hash22(fid + 3.0) - seed * 7.0) / 0.012;
    float fh = hash12(fid + 9.0);
    float fm = smoothstep(13.0, 9.0, length(p - fc)) * step(fh, 0.18) * step(p.y, 0.0);
    vec3 fcol = fh < 0.08 ? vec3(0.97, 0.83, 0.25) : vec3(0.7, 0.52, 0.88);
    c = mix(c, fcol * (0.8 + 0.25 * light), fm);
    float a = cover(d);
    return vec4(c * a, a);
}

vec3 pastel(float h) {
    return h < 0.2 ? vec3(0.93, 0.56, 0.63) : h < 0.4 ? vec3(0.47, 0.63, 0.86)
         : h < 0.6 ? vec3(0.96, 0.83, 0.47) : h < 0.8 ? vec3(0.56, 0.76, 0.52) : vec3(0.72, 0.62, 0.86);
}

vec4 cardboard(vec2 p) {
    float d0 = sdShape(p);
    float d = d0 + (vnoise(p * 0.05 + seed) - 0.5) * 3.0;
    vec3 c = col1 * (0.92 + 0.14 * (fbm(p * 0.02 + seed) - 0.5) * 2.0 * grain);
    c *= 1.0 + (fibres(p * 1.3) - 0.5) * 0.14 * grain;
    if (flags > 1.5) {
        // the cut face: a liner, the flutes, a liner
        float y = (p.y + size.y) / (2.0 * size.y);
        float liner = step(y, 0.16) + step(0.84, y);
        float wave = 0.5 + 0.5 * sin(p.x * 0.33 + sin(p.x * 0.013) * 0.6);
        vec3 inner = col1 * vec3(1.05, 1.0, 0.92) * (0.68 + 0.4 * wave);
        c = mix(inner, c, clamp(liner, 0.0, 1.0));
        c *= 1.0 - 0.3 * (smoothstep(0.03, 0.0, abs(y - 0.16)) + smoothstep(0.03, 0.0, abs(y - 0.84)));
    } else if (flags > 0.5) {
        // collage: torn paper patches, a white fringe where the paper tore
        float CELL = 230.0;
        vec2 k0 = floor(p / CELL + seed);
        for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
            vec2 k = k0 + vec2(float(i), float(j));
            float h = hash12(k + 11.0);
            if (h < 0.5) {
                vec2 hk = hash22(k);
                vec2 centre = (k + 0.5 - seed) * CELL + (hk - 0.5) * CELL * 0.35;
                float ang = (hash12(k + 5.0) - 0.5) * 0.6;
                vec2 q = mat2(cos(ang), -sin(ang), sin(ang), cos(ang)) * (p - centre);
                vec2 hb = (0.22 + 0.2 * hk.yx) * CELL;
                float torn = (vnoise(q * 0.06 + k * 3.1) - 0.5) * 12.0;
                float pd = sdBox(q, hb, 3.0) + torn;
                float wd = sdBox(q, hb, 3.0) + torn * 1.5 - 6.0;
                c = mix(c, vec3(0.96, 0.94, 0.9), cover(wd));
                vec3 pc = pastel(hash12(k + 21.0)) * (0.9 + 0.12 * vnoise(q * 0.04));
                c = mix(c, pc, cover(pd));
            }
        }
    }
    // the cut edge all round: lighter where it faces the light
    float edge = smoothstep(-14.0, -2.0, d0);
    float side = dot(gradShape(p), normalize(lightDir));
    c *= 1.0 + edge * (0.18 * side * light - 0.14);
    float a = cover(d);
    return vec4(c * a, a);
}

vec4 cellophane(vec2 p) {
    float d0 = sdShape(p);
    float wave = sin(p.x * 0.004 + time * 0.6) * 0.5 + (vnoise(vec2(p.x * 0.01, time * 0.3)) - 0.5);
    float d = d0 + wave * 28.0 * smoothstep(0.0, size.y, -p.y);
    vec2 id; vec2 r;
    vec2 f = voronoi(p * 0.0075 + seed, time * 0.35 * crinkle, id, r);
    vec2 tilt = hash22(id + 4.0) * 2.0 - 1.0;
    vec3 n = normalize(vec3(tilt * 0.75, 1.0));
    float df = diffuse(n);
    float sp = specular(n, 18.0);
    float depth = clamp((p.y + size.y) / (2.0 * size.y), 0.0, 1.0);
    vec3 c = mix(vec3(0.15, 0.55, 0.66), vec3(0.06, 0.22, 0.5), clamp(depth * 0.8 + hash12(id) * 0.5 - 0.15, 0.0, 1.0));
    c = mix(c, vec3(0.45, 0.78, 0.88), 0.25 * df * light);
    float crease = (1.0 - smoothstep(0.0, 0.06, f.y - f.x)) * step(0.68, hash12(id + 7.0));
    vec2 id2; vec2 r2;
    vec2 f2 = voronoi(p * 0.02 + seed + 3.0, time * 0.5 * crinkle, id2, r2);
    float crease2 = 1.0 - smoothstep(0.0, 0.06, f2.y - f2.x);
    c += vec3(0.9, 0.97, 1.0) * (sp * 0.7 + crease * 0.35 + crease2 * 0.05) * light;
    float a = clamp(0.58 + 0.3 * depth + 0.3 * sp + 0.2 * crease, 0.0, 0.95) * cover(d);
    return vec4(clamp(c, 0.0, 1.0) * a, a);
}

vec4 candy(vec2 p) {
    float d0 = sdShape(p);
    float d = d0 + (vnoise(p * 0.04 + seed) - 0.5) * 4.0;
    float rad = min(size.x, size.y);
    float t = clamp(-d0 / rad, 0.0, 1.0);
    float thick = sqrt(t);
    vec3 c = col1 * (0.45 + 0.75 * thick);
    c = mix(c, min(col1 * 1.5 + 0.1, vec3(1.0)), thick * thick * 0.5);
    vec2 id; vec2 r;
    vec2 f = voronoi(p * 0.03 + seed * 5.0, 0.0, id, r);
    float crack = (1.0 - smoothstep(0.0, 0.05, f.y - f.x)) * smoothstep(0.1, 0.4, t);
    c = mix(c, min(col1 * 1.6 + 0.25, vec3(1.0)), crack * 0.45 * grain);
    vec2 L2 = normalize(lightDir);
    float hl = smoothstep(rad * 0.26, rad * 0.06, length((p - L2 * rad * 0.45) * vec2(1.0, 1.25)));
    // light goes through and comes out on the far side
    float glow = smoothstep(0.1, 0.6, t) * smoothstep(0.2, 1.0, dot(-normalize(p + 1e-3), L2)) * (1.0 - t);
    c += col1 * glow * 0.6 * light;
    c = mix(c, vec3(1.0), hl * 0.85 * light);
    float a = 0.9 * cover(d);
    return vec4(clamp(c, 0.0, 1.0) * a, a);
}

vec4 brass(vec2 p) {
    float d0 = sdShape(p);
    float rad = min(size.x, size.y);
    vec3 n = normalFrom(p, d0, rad);
    vec3 c = mix(vec3(0.28, 0.17, 0.05), vec3(0.82, 0.62, 0.24),
                 smoothstep(-0.7, 0.5, dot(n.xy, normalize(lightDir)) + n.z * 0.3));
    c = mix(c, vec3(1.0, 0.93, 0.66), clamp(specular(n, 24.0) * 1.3 * light, 0.0, 1.0));
    c += vec3(0.08, 0.14, 0.04) * smoothstep(0.3, 0.9, n.y);       // the moss below, reflected
    // a jingle bell's slot and hole
    float slot = smoothstep(rad * 0.07, rad * 0.04, abs(p.y - rad * 0.28)) * step(abs(p.x), rad * 0.62);
    float hole = smoothstep(rad * 0.13, rad * 0.09, length(p - vec2(0.0, rad * 0.28)));
    c *= 1.0 - 0.85 * max(slot, hole);
    float a = cover(d0);
    return vec4(c * a, a);
}

vec4 bean(vec2 p) {
    float d0 = sdShape(p);
    vec3 n = normalFrom(p, d0, min(size.x, size.y));
    vec3 c = col1;
    if (flags > 0.5) {
        float st = sin(p.x * 0.12 + sin(p.y * 0.05) * 2.0);
        c = mix(c, col2, smoothstep(0.3, 0.5, st) * 0.8);
    }
    vec2 sid = floor(p * 0.04 + seed);
    vec2 sc = (sid + 0.2 + 0.6 * hash22(sid) - seed) / 0.04;
    float sh = hash12(sid + 2.0);
    float speck = smoothstep(7.0, 4.5, length(p - sc)) * step(0.35, sh);
    c = mix(c, sh > 0.7 ? c * 1.35 + 0.1 : c * 0.55, speck * grain * 0.8);
    c *= 0.55 + 0.6 * diffuse(n) * light;
    c = mix(c, vec3(1.0), specular(n, 12.0) * 0.25 * light);
    float a = cover(d0);
    return vec4(clamp(c, 0.0, 1.0) * a, a);
}

vec4 wall(vec2 sc) {
    vec3 c = col1 * (0.97 + 0.06 * fbm(sc * 0.01) * grain);
    c *= 1.0 + (fibres(sc * 2.0) - 0.5) * 0.06 * grain;
    c *= 1.06 - 0.14 * length(sc / screen - vec2(0.15, 0.1));       // lit from the top left
    return vec4(c, 1.0);
}

// a crayon sun: a spiral, a ring, rays; the wax skips on the paper's tooth
vec4 crayon(vec2 p, vec2 sc) {
    float R = size.x * 0.5;
    float len = length(p) + (vnoise(p * 0.05 + seed) - 0.5) * 4.0;
    float ang = atan(p.y, p.x);
    float gap = R * 0.24;
    float s = len - (ang / 6.2831 + 0.5) * gap;
    float ds = len < R ? abs(fract(s / gap) - 0.5) * gap : 1e3;
    float k = 11.0;
    float a2 = mod(ang + seed, 6.2831 / k) - 3.14159 / k;
    float dr = (len > R * 1.3 && len < R * 1.95) ? abs(a2) * len : 1e3;
    float d = min(min(ds, abs(len - R)), dr);
    float w = R * 0.065;
    float pressure = smoothstep(w, w * 0.3, d);
    float tooth = vnoise(sc * 0.45) * 0.6 + vnoise(sc * 0.11) * 0.4;
    float a = clamp((pressure - tooth * 0.75) * 3.0, 0.0, 1.0) * 0.9;
    return vec4(col1 * a, a);
}

vec4 shadow(vec2 p) {
    float a = (1.0 - smoothstep(0.15, 1.0, length(p / size))) * alpha;
    return vec4(col1 * a, a);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 p = q0 * ext;
    if (mat > 6.5 && mat < 7.5) return wall(sc);
    if (mat > 7.5 && mat < 8.5) return crayon(p, sc);
    if (mat > 8.5) return shadow(p);
    if (plain > 0.5) {
        float a = cover(sdShape(p)) * (mat > 2.5 && mat < 3.5 ? 0.7 : 1.0);
        return vec4(col1 * a, a);
    }
    if (mat < 0.5) return felt(p);
    if (mat < 1.5) return moss(p);
    if (mat < 2.5) return cardboard(p);
    if (mat < 3.5) return cellophane(p);
    if (mat < 4.5) return candy(p);
    if (mat < 5.5) return brass(p);
    return bean(p);
}
#endif
]])

local quad = love.graphics.newMesh({
    { -1, -1, 0, 0 }, { 1, -1, 1, 0 }, { 1, 1, 1, 1 }, { -1, 1, 0, 1 },
}, 'fan', 'static')

---------------------------------------------------------------- things

local function sizeOf(thing) return thing.radius or thing.width end

-- a thing rebuilt in the editor (the size square, src/transform-handles.lua) has a new body and
-- size: follow it, and grow the paint by as much
local function follow(t)
    local thing = t.thing
    if not thing or not thing.body or thing.body == t.body or thing.body:isDestroyed() then return end
    t.body = thing.body
    local f = sizeOf(thing) / t.baseSize
    t.baseSize = sizeOf(thing)
    t.hw, t.hh, t.rr = t.hw * f, t.hh * f, t.rr * f
    if t.puff then t.puff = t.puff * f end
end

local function alive(list)
    local out = {}
    for _, t in ipairs(list) do
        follow(t)
        if t.body and not t.body:isDestroyed() then out[#out + 1] = t end
    end
    return out
end

local function aliveMipos(b) return mipoKit.alive(b.mipos) end -- src/mipo-kit.lua

-- a thing: a body plus how to paint it
local function add(b, kind, x, y, look)
    local thing
    if look.shape == 'circle' then
        thing = objectManager.addThing('circle', { x = x, y = y, radius = look.hw, bodyType = 'dynamic',
            label = 'mat-' .. look.mat, density = look.density or 0.3 })
        look.hh, look.rr, look.shapeN = look.hw, 0, 0
    elseif look.shape == 'capsule' then
        thing = objectManager.addThing('capsule', { x = x, y = y, width = look.hw * 2, height = look.hh * 2,
            width2 = 2, bodyType = 'dynamic', label = 'mat-' .. look.mat, density = look.density or 0.3 })
        look.rr, look.shapeN = math.min(look.hw, look.hh), 1
    else
        thing = objectManager.addThing('rectangle', { x = x, y = y, width = look.hw * 2, height = look.hh * 2,
            bodyType = 'dynamic', label = 'mat-' .. look.mat, density = look.density or 0.3 })
        look.rr, look.shapeN = look.rr or 8, 1
    end
    if not thing then return end
    look.body, look.kind, look.thing, look.baseSize = thing.body, kind, thing, sizeOf(thing)
    look.seed = look.seed or love.math.random() * 50
    b.things[#b.things + 1] = look
end

local SPAWN = {
    candy = function(b, x, y)
        local r = 70 + love.math.random() * 45
        add(b, 'candy', x, y, { mat = 'candy', shape = 'circle', hw = r, col1 = pick(CANDY), density = 0.4 })
    end,
    bell = function(b, x, y)
        add(b, 'bell', x, y, { mat = 'brass', shape = 'circle', hw = 100, density = 0.6 })
    end,
    bean = function(b, x, y)
        local c1 = pick(BEANS)
        add(b, 'bean', x, y, { mat = 'bean', shape = 'capsule', hw = 78, hh = 48, col1 = c1, col2 = pick(BEANS),
            flags = love.math.random() < 0.25 and 1 or 0 })
    end,
}

local function stock(b)
    for _, t in ipairs(alive(b.things)) do objectManager.destroyBody(t.body) end
    b.things = {}
    add(b, 'ball', -1600, -500, { mat = 'felt', shape = 'circle', hw = 380, puff = 380,
        col1 = { 0.74, 0.62, 0.82 }, col2 = { 0.55, 0.44, 0.76 }, flags = 1, density = 0.1 })
    add(b, 'block', -850, -400, { mat = 'felt', shape = 'box', hw = 210, hh = 180, rr = 40, puff = 70,
        col1 = { 0.5, 0.74, 0.62 }, flags = 0, density = 0.15 })
    add(b, 'box', 550, -500, { mat = 'cardboard', shape = 'box', hw = 270, hh = 220, rr = 6,
        col1 = { 0.72, 0.58, 0.42 }, flags = 1 })
    for i = 1, 3 do SPAWN.bell(b, -300 + i * 230, -1200 - i * 150) end
    for i = 1, 16 do SPAWN.candy(b, -300 + (i % 5) * 140, -900 - i * 120) end
    for i = 1, 10 do SPAWN.bean(b, 900 + (i % 4) * 170, -1000 - i * 110) end
end

local function staticBox(b, x, y, w, h)
    local thing = objectManager.addThing('rectangle', { x = x, y = y, width = w, height = h,
        bodyType = 'static', label = 'mat-table' })
    if thing then
        for _, fixture in ipairs(thing.body:getFixtures()) do fixture:setFriction(0.8) end
        b.statics[#b.statics + 1] = { body = thing.body }
    end
end

local function buildTable(b)
    if #alive(b.statics) > 0 then return end
    b.statics = {}
    staticBox(b, SLAB.x, SLAB.h / 2, SLAB.w, SLAB.h)                       -- the slab
    staticBox(b, WATER.x, WATER.top + WATER.h + 20, WATER.w, 40)           -- the water's floor
    staticBox(b, SLAB.x - SLAB.w / 2 - 20, -900, 40, 1800)                  -- walls at the ends
    staticBox(b, WATER.x + WATER.w / 2 + 20, -600, 40, 2400)
end

local function spawnMipo(b, x, y) mipoKit.spawn(b.mipos, x, y) end -- src/mipo-kit.lua

---------------------------------------------------------------- hooks

function s.onStart()
    worldState.paused = false
    local b = materials()
    buildTable(b)
    b.things = alive(b.things)
    if #b.things == 0 then stock(b) end
    b.mipos = aliveMipos(b)
    if #b.mipos == 0 then
        spawnMipo(b, -200, -1500)
        spawnMipo(b, 1500, -1500)
    end
end

function s.onUnload()
    local b = state.materials
    if b and b.savedDrawBodies ~= nil then state.world.debugDrawBodies = b.savedDrawBodies end
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local b = materials()
    local mx, my = mouseWorldPos()
    if key == 'c' then SPAWN.candy(b, mx, my)
    elseif key == 'b' then SPAWN.bell(b, mx, my)
    elseif key == 'j' then SPAWN.bean(b, mx, my)
    elseif key == 'm' then spawnMipo(b, mx, my)
    elseif key == 'r' then stock(b)
    elseif key == 'p' then b.wall = b.wall % #WALLS + 1
    elseif key == 't' then b.plain = not b.plain
    elseif key == 'h' then b.showPanel = not b.showPanel
    end
end

function s.update(dt)
    local b = state.materials
    if not b then return end
    b.time = b.time + dt
end

---------------------------------------------------------------- drawing

local function sendCommon(b)
    local set = b.settings
    matShader:send('time', b.time)
    matShader:send('fuzz', set.fuzz)
    matShader:send('grain', set.grain)
    matShader:send('light', set.light)
    matShader:send('crinkle', set.crinkle)
    matShader:send('plain', b.plain and 1 or 0)
    matShader:send('px', 1 / cam:getScale())
    matShader:send('screen', { love.graphics.getPixelDimensions() })
end

local WHITE = { 1, 1, 1 }
-- paint one thing at (x, y) turned by angle
local function paint(t, x, y, angle)
    local pad = PAD[t.mat] or 4
    local c, sn = math.cos(-angle), math.sin(-angle)
    matShader:send('mat', MAT[t.mat])
    matShader:send('shape', t.shapeN or 1)
    matShader:send('size', { t.hw, t.hh })
    matShader:send('ext', { t.hw + pad, t.hh + pad })
    matShader:send('rr', t.rr or 0)
    matShader:send('puff', t.puff or math.min(t.hw, t.hh))
    matShader:send('col1', t.col1 or WHITE)
    matShader:send('col2', t.col2 or t.col1 or WHITE)
    matShader:send('seed', t.seed or 0)
    matShader:send('flags', t.flags or 0)
    matShader:send('lightDir', { LIGHT[1] * c - LIGHT[2] * sn, LIGHT[1] * sn + LIGHT[2] * c })
    love.graphics.draw(quad, x, y, angle, t.hw + pad, t.hh + pad)
end

local slabLook = { mat = 'cardboard', shapeN = 1, hw = SLAB.w / 2, hh = (SLAB.h - 30) / 2, rr = 4,
    col1 = { 0.76, 0.62, 0.45 }, flags = 2, seed = 4.2 }
local mossLook = { mat = 'moss', shapeN = 1, hw = SLAB.w / 2, hh = 24, rr = 10, seed = 1.3 }
local waterLook = { mat = 'cellophane', shapeN = 1, hw = WATER.w / 2, hh = WATER.h / 2, rr = 30,
    col1 = { 0.2, 0.5, 0.75 }, seed = 2.7 }
local sunLook = { mat = 'crayon', hw = 130, hh = 130, col1 = { 0.95, 0.66, 0.12 }, seed = 0.4 }

-- a soft shadow on the table under each thing, smaller and fainter the higher it is
local function shadows(b)
    matShader:send('mat', MAT.shadow)
    for _, t in ipairs(b.things) do
        local x, y = t.body:getPosition()
        local onSlab = x > SLAB.x - SLAB.w / 2 and x < SLAB.x + SLAB.w / 2
        local reach = math.max(t.hw, t.hh)
        local gap = (onSlab and 0 or WATER.top + WATER.h) - (y + reach)
        if gap > -reach and gap < 600 then
            local k = 1 - clamp(gap / 600, 0, 1)
            local hw, hh = reach * (1.15 - 0.3 * k), 26
            local tint = t.mat == 'candy' and t.col1 or { 0.12, 0.1, 0.06 }
            matShader:send('col1', tint)
            matShader:send('alpha', (t.mat == 'candy' and 0.45 or 0.35) * k)
            matShader:send('size', { hw, hh })
            matShader:send('ext', { hw, hh })
            love.graphics.draw(quad, x, (onSlab and 0 or WATER.top + WATER.h) - 4, 0, hw, hh)
        end
    end
end

function s.drawBelow()
    local b = state.materials
    if not b then return end
    b.things = alive(b.things)
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader(matShader)
    sendCommon(b)
    love.graphics.setBlendMode('alpha', 'premultiplied')
    -- the paper wall and the crayon sun, on the screen
    love.graphics.push()
    love.graphics.origin()
    matShader:send('mat', MAT.wall)
    matShader:send('col1', WALLS[b.wall])
    love.graphics.rectangle('fill', 0, 0, w, h)
    local px = 1 / cam:getScale()
    matShader:send('px', 1)
    paint(sunLook, 150, 130, 0)
    matShader:send('px', px)
    love.graphics.pop()
    -- the table
    paint(slabLook, SLAB.x, 15 + slabLook.hh, 0)
    paint(mossLook, SLAB.x, 10, 0)
    shadows(b)
    for _, t in ipairs(b.things) do
        local x, y = t.body:getPosition()
        paint(t, x, y, t.body:getAngle())
    end
    love.graphics.setBlendMode('alpha')
    love.graphics.setShader()
    -- the Mipos draw themselves; the plain outlines of our things would show (in the editor too:
    -- there they covered the materials while sizing and turning things)
    b.savedDrawBodies = state.world.debugDrawBodies
    state.world.debugDrawBodies = false
    b.drawing = true
end

function s.draw()
    local b = state.materials
    if not (b and b.drawing) then return end
    b.drawing = nil
    if b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
    -- the water goes in front: what falls in is seen through it
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader(matShader)
    sendCommon(b)
    love.graphics.setBlendMode('alpha', 'premultiplied')
    paint(waterLook, WATER.x, WATER.top + WATER.h / 2, 0)
    love.graphics.setBlendMode('alpha')
    love.graphics.setShader()
end

function s.drawUI()
    local b = state.materials
    if not (b and state.playMode and b.showPanel) then return end
    ui.startFrame()
    local BH, pad, w = 36, 8, 400
    local rows = { { 'fuzz', 0, 2 }, { 'grain', 0, 2 }, { 'light', 0, 2 }, { 'crinkle', 0, 3 } }
    local h = (BH + pad) * (#rows + 2) + pad + 24
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• materials ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        for _, row in ipairs(rows) do
            local key = row[1]
            local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('materials' .. key, x, y, 180, row[2], row[3], b.settings[key])
            if v then b.settings[key] = v + 0 end
            ui.label(x + 280, y, key)
        end
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, (b.plain and 'plain colours' or 'materials') .. '  (t)   wall (p)')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'c candy  b bell  j bean  m Mipo  r reset')
    end)
end

return s

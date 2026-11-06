-- material-check: materials on Nikki's own drawings, under one light: metal, velvet, a leaf the light shines through, smoke
-- MATERIALS take two (docs/MATERIALS.md, 2026-11-06). The first spike made its materials from noise
-- alone and read as "computer"; here every material is one of the drawn pictures (outline + mask),
-- its roundness baked from the mask (src/render/form-bake.lua), and the material is only how that
-- roundness takes the light. Each row is the same picture, so the material is the only difference.
-- One screen: the palette (every material on one shape, n another), a row of leaves under it (as drawn,
-- then lit: from the front waxy, from behind the light comes through, swaying), smoke on the right,
-- and a big striped shape sliding behind everything, so the see-through materials (glass, ice, a
-- soap bubble, clear candy, amber) show it, bent by their roundness.
-- The light is where the mouse is: in front of the pictures, or behind them (b).
-- The palette's materials are mostly one 'surface' model with settings (PALETTE): how far the light
-- wraps round, a shine (its size, strength, white or the colour's own), a clear coat (glaze, varnish,
-- wet), a sheen at the edges (cloth), the edges darkened (glaze pooling, worn leather), light coming
-- through (wax, jade, candy), a grain (sand, fibre, pebble, wood, crackle), a rainbow (pearl) and how
-- see-through it is (clear: how much, how far it bends, tinted, frosted).
-- keys:
--   k creases from the inner lines: off / on / deep (MT10: the strokes inside a shape, an ear's fold,
--     a snout's nostrils, dent its roundness; n for the shapes that have them: ears, a snout, a foot)
--   u a second material in the pattern: off / brass / gold / tin / velvet plum / glass / felt (each cell's
--     own material fills the pattern's dark parts, the second its light parts: velvet with brass stripes)
--   i which pattern (stripes, spots, the Mipo patterns)   y the pattern's size
--   x measure what each material costs the GPU (src/render/shader-cost.lua): under each name its cost
--     against 'as drawn', the status line the cheapest and dearest in ms per million pixels
--   j the shape behind slides / stays   hold h: the shape behind follows the mouse (the light stays)
--   b light in front / behind   f the light stays put / follows the mouse   c light: sun / candle / moon
--   p painted (the light in a few steps, like poster paint) / smooth   o outlines on / off
--   n another shape   l other leaves   s smoke: steam / smoke / soot   w wind
--   m the bake's rise: dome / cushion / pebble (how round the shapes are)
--   r a shower: everything gets wet (darker, a sharp shine, drops), then dries again
--   g what the shader sees: off / height / normals / the light alone (on white)
--   e the picture pass: grain, vignette, a soft glow and a grade by the light / off
--   t 12 frames a second for the whole picture (stop-motion), the leaves' sway too / smooth

local s = {}

-- the layout, in world units: the palette's top left cell, the leaves' row (their stems), the smoke's
-- chimney, the shape behind (its middle, how far it slides)
local GRID = { x = -1450, y = -1050, step = 340, rowStep = 330, cell = 250, columns = 6 }
local LEAF_ROW = 1130
local SMOKE = { x = 800, y = 1250 }
local BEHIND = { pic = 'mipo/body/body-13', x = -600, y = 250, size = 1250, slide = 700,
    colour = { 0.36, 0.42, 0.7 }, stripe = { 0.98, 0.84, 0.3 } }
local LEAF_SETS = {
    { 'plants/oval-02', 'plants/oval-04', 'plants/frond-01', 'plants/oval-03', 'plants/oval-01', 'plants/oval-05' },
    { 'plants/oval-03', 'plants/petal-02', 'plants/oval-02', 'plants/petal-05', 'plants/sprout-01', 'plants/oval-04' },
}
local LEAF_COLOURS = { { 0.36, 0.55, 0.18 }, { 0.3, 0.5, 0.22 }, { 0.42, 0.58, 0.16 }, { 0.5, 0.6, 0.2 },
    { 0.28, 0.46, 0.2 }, { 0.4, 0.52, 0.14 } }
local LIGHTS = {
    { name = 'sun', colour = { 1.0, 0.96, 0.88 }, ambient = { 0.42, 0.45, 0.52 }, wall = { 0.93, 0.88, 0.78 } },
    { name = 'candle', colour = { 1.0, 0.68, 0.36 }, ambient = { 0.22, 0.18, 0.2 }, wall = { 0.55, 0.42, 0.34 } },
    { name = 'moon', colour = { 0.66, 0.76, 1.0 }, ambient = { 0.12, 0.14, 0.24 }, wall = { 0.3, 0.33, 0.42 } },
}
local SMOKES = {
    { name = 'steam', colour = { 0.96, 0.96, 0.97 }, alpha = 0.55 },
    { name = 'smoke', colour = { 0.66, 0.64, 0.62 }, alpha = 0.7 },
    { name = 'soot', colour = { 0.2, 0.19, 0.19 }, alpha = 0.8 },
}
local PUFFS = { 'mipo/body/body-01', 'mipo/body/body-03', 'mipo/body/body-05', 'mipo/body/body-11',
    'mipo/body/body-13', 'mipo/body/body-16' }
-- two materials on one picture (MT3 without a drawn map): a pattern says which is where. Its value is
-- its alpha times its brightness (some are white on transparent, some opaque light on dark)
local SECONDS = { false, 'brass', 'gold', 'tin', 'velvet plum', 'glass', 'felt' }
local PATTERNS = { 'bee-stripes', 'type2t', 'ladybird-spots', 'type1', 'pattern4', 'type6', 'type8' }
local PATTERN_SIZES = { 3, 6, 1.5 } -- repeats over the picture's height
local CREASES = { { 'off', 0 }, { 'on', 1 }, { 'deep', 2.5 } }
local RISES = { { 'dome', 1 }, { 'cushion', 0.5 }, { 'pebble', 0.2 } }
local LIGHT_DEPTH = 420

-- The palette: one shape in every material. Fields (all optional, 0 when left out):
--   spec = { strength, size (higher: smaller, sharper), tint (0 white .. 1 the colour's own), clear coat }
--   surf = { wrap, sheen, edges darkened, light through }
--   grain = { kind, scale, depth, tone }  kind: 1 sand, 2 fibre, 3 pebble, 4 wood, 5 crackle
--   rainbow, rough (metal: 0 polished .. 1 dull)
local SAND, FIBRE, PEBBLE, WOOD, CRACKLE = 1, 2, 3, 4, 5
local PALETTE = {
    { name = 'as drawn', mode = 0, base = { 0.86, 0.55, 0.42 } },
    -- matte
    { name = 'clay', base = { 0.82, 0.5, 0.36 }, spec = { 0.08, 6 }, surf = { 0.35 }, grain = { SAND, 14, 0.25, 0.1 } },
    { name = 'plaster', base = { 0.92, 0.88, 0.8 }, surf = { 0.25, 0, 0.15 }, grain = { SAND, 40, 0.6, 0.25 } },
    { name = 'stucco', base = { 0.95, 0.78, 0.6 }, surf = { 0.2, 0, 0.2 }, grain = { PEBBLE, 22, 0.9, 0.35 } },
    { name = 'stone', base = { 0.62, 0.62, 0.6 }, surf = { 0.15, 0, 0.25 }, grain = { CRACKLE, 5, 0.6, 0.5 } },
    { name = 'paper', base = { 0.95, 0.93, 0.86 }, surf = { 0.6, 0, 0, 0.2 }, grain = { FIBRE, 30, 0.15, 0.12 } },
    { name = 'felt', base = { 0.86, 0.32, 0.3 }, surf = { 0.5, 0.25 }, grain = { FIBRE, 22, 0.5, 0.3 } },
    { name = 'cotton', base = { 0.42, 0.55, 0.78 }, surf = { 0.45, 0.2 }, grain = { FIBRE, 60, 0.35, 0.18 } },
    -- cloth and soft
    { name = 'velvet plum', mode = 2, base = { 0.45, 0.12, 0.3 } },
    { name = 'velvet moss', mode = 2, base = { 0.22, 0.36, 0.14 } },
    { name = 'satin', base = { 0.85, 0.66, 0.72 }, spec = { 0.5, 10 }, surf = { 0.3, 0.6 } },
    { name = 'suede', base = { 0.66, 0.46, 0.28 }, surf = { 0.4, 0.35, 0.1 }, grain = { FIBRE, 90, 0.2, 0.1 } },
    { name = 'leather', base = { 0.46, 0.25, 0.14 }, spec = { 0.35, 16, 0.2 }, surf = { 0.15, 0, 0.45 },
        grain = { PEBBLE, 45, 0.5, 0.15 } },
    { name = 'rubber', base = { 0.24, 0.24, 0.26 }, spec = { 0.18, 4 }, surf = { 0.2, 0.25 }, grain = { SAND, 50, 0.15, 0.05 } },
    { name = 'wax', base = { 0.96, 0.86, 0.62 }, spec = { 0.2, 12 }, surf = { 0.7, 0, 0, 0.55 } },
    -- shiny
    { name = 'toy plastic', base = { 0.92, 0.22, 0.2 }, spec = { 1.0, 70 }, surf = { 0.15 } },
    { name = 'glazed pot', base = { 0.2, 0.42, 0.55 }, spec = { 0.3, 20, 0.5, 1.0 }, surf = { 0.1, 0, 0.45 } },
    { name = 'candy', base = { 0.95, 0.35, 0.55 }, spec = { 0.2, 30, 0, 1.0 }, surf = { 0.4, 0, 0, 0.6 } },
    { name = 'jade', base = { 0.42, 0.7, 0.5 }, spec = { 0.2, 25, 0, 0.6 }, surf = { 0.5, 0, 0, 0.45 },
        grain = { SAND, 6, 0.1, 0.2 } },
    { name = 'pearl', base = { 0.93, 0.9, 0.86 }, spec = { 0.4, 30 }, surf = { 0.4, 0.3 }, rainbow = 0.8 },
    { name = 'wet stone', base = { 0.3, 0.3, 0.32 }, spec = { 0.2, 20, 0, 1.2 }, surf = { 0.15, 0, 0.2 },
        grain = { CRACKLE, 5, 0.4, 0.4 } },
    { name = 'mud', base = { 0.36, 0.25, 0.16 }, spec = { 0.1, 30, 0, 0.7 }, surf = { 0.2 }, grain = { PEBBLE, 12, 0.7, 0.25 } },
    -- wood and metal
    { name = 'wood', base = { 0.74, 0.52, 0.3 }, spec = { 0.1, 8 }, surf = { 0.3 }, grain = { WOOD, 7, 0.25, 0.35 } },
    { name = 'varnished', base = { 0.55, 0.3, 0.15 }, spec = { 0.15, 12, 0, 0.9 }, surf = { 0.2 }, grain = { WOOD, 7, 0.1, 0.4 } },
    { name = 'brass', mode = 1, base = { 0.95, 0.72, 0.3 } },
    { name = 'gold', mode = 1, base = { 1.0, 0.8, 0.28 }, spec = { 1.8, 90 } },
    { name = 'copper', mode = 1, base = { 0.93, 0.5, 0.32 }, rough = 0.2 },
    { name = 'tin', mode = 1, base = { 0.78, 0.8, 0.85 }, grain = { PEBBLE, 9, 0.35, 0 } },
    { name = 'plush fur', mode = 6, base = { 0.78, 0.6, 0.4 }, spec = { 0.35, 30 }, surf = { 0, 0.7 },
        fur = { 70, 0.1, 0.5 } },
    { name = 'shaggy fur', mode = 6, base = { 0.5, 0.36, 0.26 }, spec = { 0.5, 40 }, surf = { 0, 0.8 },
        fur = { 50, 0.8, 0.8 } },
    -- see-through: clear = { how much, how far it bends (px), tinted by its colour, frosted (px) }
    { name = 'glass', base = { 0.85, 0.93, 0.96 }, spec = { 0.7, 90 }, surf = { 0.1 }, clear = { 0.85, 30, 0.15 } },
    { name = 'ice', base = { 0.8, 0.9, 1.0 }, spec = { 0.4, 60 }, surf = { 0.3, 0.2 }, clear = { 0.7, 40, 0.3, 4 },
        grain = { CRACKLE, 4, 0.25, 0.1 } },
    { name = 'soap bubble', base = { 1, 1, 1 }, spec = { 0.9, 120 }, clear = { 0.95, 6 }, rainbow = 1.2 },
    { name = 'clear candy', base = { 0.95, 0.25, 0.45 }, spec = { 0.3, 40, 0, 1.0 }, surf = { 0.3, 0, 0, 0.4 },
        clear = { 0.6, 25, 0.9 } },
    { name = 'amber', base = { 0.95, 0.6, 0.15 }, spec = { 0.3, 50, 0, 0.8 }, surf = { 0.3, 0, 0, 0.5 },
        clear = { 0.55, 20, 0.95 } },
    { name = 'iron', mode = 1, base = { 0.45, 0.45, 0.48 }, spec = { 0.6, 14 }, rough = 0.8, grain = { SAND, 30, 0.3, 0.2 } },
}
local PALETTE_SHAPES = { 'mipo/body/body-12', 'mipo/ear/ear-06', 'mipo/nose/nose-07', 'mipo/foot/foot-01',
    'mipo/ear/ear-10', 'mipo/ear/ear-05', 'mipo/leg/leg-02', 'mipo/leg/leg-05', 'mipo/leg/leg-03', 'mipo/body/body-06', 'mipo/body/body-15', 'mipo/body/body-17',
    'mipo/body/body-03', 'mipo/patch/patch-01' } -- how far in front of (or behind) the pictures the light is

local function lab()
    state.materialCheck = state.materialCheck or {
        back = false, frozen = false, light = 1, painted = false, outlines = true, shape = 1, leaves = 1,
        smoke = 1, wind = 0, rise = 1, puffs = {}, spawn = 0, lx = 0, ly = -900,
    }
    -- added later: a live state lacks them (and time: a phone draws once before the first update)
    state.materialCheck.time = state.materialCheck.time or 0
    state.materialCheck.sinceFrame = state.materialCheck.sinceFrame or 0
    state.materialCheck.crease = state.materialCheck.crease or 2
    state.materialCheck.second = state.materialCheck.second or 1
    state.materialCheck.patternIndex = state.materialCheck.patternIndex or 1
    state.materialCheck.patternSize = state.materialCheck.patternSize or 1
    state.materialCheck.slide = state.materialCheck.slide == nil and true or state.materialCheck.slide
    state.materialCheck.behindX = state.materialCheck.behindX or BEHIND.x
    state.materialCheck.behindY = state.materialCheck.behindY or BEHIND.y
    state.materialCheck.paletteShape = state.materialCheck.paletteShape or 1
    return state.materialCheck
end

---------------------------------------------------------------- the shader

local shader
local function materialShader()
    shader = shader or love.graphics.newShader([[
        uniform Image form;      // the baked roundness: r height, g b the normal's x y (0.5 flat)
        uniform vec3 toLight;    // in the picture's own frame (y down), normalised
        uniform vec3 lightColour;
        uniform vec3 ambient;
        uniform vec3 baseColour;
        uniform float mode;      // 0 flat, 1 metal, 2 velvet, 3 leaf, 4 smoke, 5 surface, 6 fur
        uniform float bands;     // 0 smooth, else the light in this many steps
        uniform float seed;
        uniform float dissolve;  // smoke: 0 new, 1 gone
        uniform vec2 formTexel;  // one texel of the form map
        uniform vec4 spec;       // strength, size, tint (0 white .. 1 its colour), clear coat
        uniform vec4 surf;       // wrap, sheen, edges darkened, light through
        uniform vec4 grain;      // kind (1 sand 2 fibre 3 pebble 4 wood 5 crackle), scale, depth, tone
        uniform vec4 more;       // rainbow, the picture's aspect, metal roughness, -
        uniform vec4 fur;        // strands per picture, length (0 short .. 1 long), clumping, -
        uniform float wet;       // 0 dry .. 1 just rained on
        uniform float debug;     // 0 off, 1 height, 2 normals, 3 the light alone
        uniform vec4 clear;      // see-through: how much, how far it bends (px), tinted, frosted (px)
        uniform Image behind;    // what's behind everything (the wall and the striped shape)
        uniform vec2 screenSize; // its size in pixels
        uniform Image lines;     // the drawn outline picture (mipmapped: a blurred copy for free)
        uniform vec2 lineTexel;  // one texel of it
        uniform float crease;    // how deep the inner lines dent the roundness (0: not at all)
        uniform Image pattern;   // a second material's pattern: only where it's light (patternOn)
        uniform float patternOn;
        uniform float patternRepeat;

        float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
        float vnoise(vec2 p) {
            vec2 i = floor(p);
            vec2 f = fract(p);
            f = f * f * (3.0 - 2.0 * f);
            return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
                mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
        }
        // the nearest and second nearest cell point
        vec2 cells(vec2 p) {
            vec2 i = floor(p);
            vec2 f = fract(p);
            float d1 = 8.0;
            float d2 = 8.0;
            for (int y = -1; y <= 1; y++) {
                for (int x = -1; x <= 1; x++) {
                    vec2 o = vec2(float(x), float(y));
                    vec2 r = o + vec2(hash(i + o), hash(i + o + 17.0)) - f;
                    float d = dot(r, r);
                    if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
                }
            }
            return sqrt(vec2(d1, d2));
        }
        float grainAt(vec2 p) {
            float kind = grain.x;
            if (kind < 1.5) return hash(floor(p * 3.0)) * 0.45 + vnoise(p) * 0.55;
            if (kind < 2.5) {
                // fibres: noise stretched two ways, turned off the axes
                vec2 a = mat2(0.8, 0.6, -0.6, 0.8) * p;
                vec2 b = mat2(0.6, -0.8, 0.8, 0.6) * p;
                return vnoise(a * vec2(1.0, 7.0)) * 0.5 + vnoise(b * vec2(7.0, 1.0)) * 0.5;
            }
            if (kind < 3.5) { float d = cells(p).x; return 1.0 - d * d; }
            if (kind < 4.5) {
                float r = p.y * 0.7 + vnoise(p * vec2(0.25, 1.2)) * 2.2;
                return 0.5 + 0.5 * sin(r * 6.283);
            }
            vec2 e = cells(p);
            return smoothstep(0.0, 0.1, e.y - e.x);
        }
        float st(float x) { return bands > 0.5 ? floor(x * bands + 0.5) / bands : x; }

        vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 sc) {
            vec4 m4 = Texel(tex, uv);
            float m = m4.r * m4.a;
            if (m < 0.01) return vec4(0.0);
            // the bake's normal has small steps (whole-texel distances) that a mirror shows as
            // stripes: averaged over a few texels around
            vec4 f = vec4(0.0);
            for (int i = -1; i <= 1; i++) {
                for (int j = -1; j <= 1; j++) f += Texel(form, uv + vec2(float(i), float(j)) * formTexel * 1.6);
            }
            f /= 9.0;
            float h = f.r;
            vec2 nxy = (f.gb - 0.5) * 2.0;
            vec3 n = normalize(vec3(nxy, sqrt(max(0.0, 1.0 - dot(nxy, nxy)))));
            // creases: the strokes inside the shape (not its outline: only where the blurred mask is
            // well inside) are valleys; the blurred line is how deep, its slope tilts the normal
            float creaseShade = 0.0;
            if (crease > 0.0) {
                vec4 mb = Texel(tex, uv, 3.5);
                float inner = smoothstep(0.8, 0.97, mb.r * mb.a);
                vec2 e = lineTexel * 7.0;
                float cx = Texel(lines, uv + vec2(e.x, 0.0), 2.5).a - Texel(lines, uv - vec2(e.x, 0.0), 2.5).a;
                float cy = Texel(lines, uv + vec2(0.0, e.y), 2.5).a - Texel(lines, uv - vec2(0.0, e.y), 2.5).a;
                n = normalize(n + vec3(cx, cy, 0.0) * crease * 1.6 * inner);
                creaseShade = Texel(lines, uv, 3.0).a * inner * min(crease, 1.5);
            }
            // the grain: a small relief on the roundness, and a little in the colour
            float g = 0.5;
            if (grain.x > 0.5) {
                vec2 gp = uv * vec2(more.y, 1.0) * grain.y;
                g = grainAt(gp);
                float e = 0.15;
                float gx = grainAt(gp + vec2(e, 0.0)) - g;
                float gy = grainAt(gp + vec2(0.0, e)) - g;
                n = normalize(n - vec3(gx, gy, 0.0) / e * grain.z * 0.12);
            }
            vec3 L = normalize(toLight);
            float ndl = dot(n, L);
            float alpha = m;
            if (patternOn > 0.5) {
                vec4 pv = Texel(pattern, uv * vec2(more.y, 1.0) * patternRepeat);
                alpha *= smoothstep(0.35, 0.65, pv.a * dot(pv.rgb, vec3(0.333)));
            }
            vec3 base = baseColour * (1.0 + (g - 0.5) * grain.w * 2.0);
            if (mode > 0.5) base *= 1.0 - 0.3 * creaseShade; // a crease is darker inside: less light gets in
            // wet: porous things darken most, metal and glaze hardly
            float porous = mode > 0.5 && mode < 1.5 ? 0.15 : 1.0 - min(spec.w, 1.0) * 0.7;
            if (mode > 0.5 && mode != 4.0) base *= 1.0 - 0.42 * wet * porous;
            vec3 col = base;
            if (debug > 0.5) {
                if (debug < 1.5) return vec4(vec3(h), alpha) * colour;
                if (debug < 2.5) return vec4(n * 0.5 + 0.5, alpha) * colour;
                return vec4(ambient + max(ndl, 0.0) * lightColour, alpha) * colour;
            }

            if (mode < 0.5) {
                col = base;
            } else if (mode < 1.5) {
                // metal: the room reflected (a bright sky above, a dark band at the horizon, the
                // warm floor below), lit by the lamp, and its highlight in the metal's own colour
                vec3 R = vec3(2.0 * n.z * n.x, 2.0 * n.z * n.y, 2.0 * n.z * n.z - 1.0);
                float up = -R.y;
                float env = mix(0.42, 1.0, smoothstep(-0.05, 0.25, up));
                env -= 0.32 * (1.0 - smoothstep(0.0, 0.12, abs(up + 0.02)));
                env = mix(env, 0.6, 0.35 * n.z * n.z);
                env = mix(env, 0.62, more.z * 0.75);
                float lit = st(clamp(0.45 + 0.55 * ndl, 0.0, 1.0));
                float shine = st(pow(max(dot(R, L), 0.0), spec.y)) * spec.x + pow(max(dot(R, L), 0.0), 6.0) * 0.25;
                col = base * st(env) * (ambient * 0.6 + lightColour * lit) + shine * mix(base, vec3(1.0), 0.45) * lightColour;
            } else if (mode < 2.5) {
                // velvet: the middle soaks up the light, the edges where the pile lies over shine
                float wrap = max(0.0, (ndl + 0.4) / 1.4);
                float rim = pow(1.0 - n.z, 2.0);
                float side = 0.35 + 0.65 * max(0.0, dot(normalize(n.xy + 1e-4), normalize(L.xy + 1e-4)));
                float pile = 0.93 + 0.14 * hash(floor(uv * 260.0));
                float sheen = st(rim * side * (L.z < 0.0 ? 1.7 : 1.0));
                col = base * 0.55 * (ambient + st(wrap) * lightColour) * pile
                    + sheen * mix(base, vec3(1.0), 0.45) * lightColour * 0.9;
            } else if (mode < 3.5) {
                // leaf: from the front a soft waxy shine; from behind the light comes through,
                // most where it's thin (the edges), warmer and yellower than the leaf itself
                float back = clamp(-L.z * 2.0, 0.0, 1.0);
                float wrap = max(0.0, (ndl + 0.3) / 1.3);
                vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
                float wax = st(pow(max(dot(n, H), 0.0), 18.0)) * 0.3;
                vec3 front = base * (ambient + st(wrap) * lightColour) + wax * lightColour;
                float thin = 1.0 - 0.6 * h;
                vec3 glow = mix(base * 1.6, vec3(0.86, 0.95, 0.32), 0.45) * lightColour * st(thin);
                vec3 behind = base * ambient * 0.6 + glow;
                col = mix(front, behind, back);
            } else if (mode > 4.5 && mode < 5.5) {
                // the surface: wrapped light, edges darkened, a sheen, light coming through,
                // a shine, a clear coat, a rainbow
                float back = clamp(-L.z * 2.0, 0.0, 1.0);
                float d = st(max(0.0, (ndl + surf.x) / (1.0 + surf.x)));
                col = base * (ambient + d * lightColour);
                col *= 1.0 - surf.z * pow(1.0 - n.z, 1.5);
                float rim = pow(1.0 - n.z, 2.0);
                float side = 0.35 + 0.65 * max(0.0, dot(normalize(n.xy + 1e-4), normalize(L.xy + 1e-4)));
                col += st(rim * side * surf.y * (1.0 + back)) * mix(base, vec3(1.0), 0.5) * lightColour;
                float thin = 1.0 - 0.6 * h;
                col += surf.w * base * lightColour * (0.3 * d + 1.3 * back * thin);
                vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
                float nh = max(dot(n, H), 0.0);
                vec3 glints = vec3(0.0);
                if (spec.x > 0.0) glints += st(pow(nh, max(spec.y, 1.0))) * spec.x * mix(vec3(1.0), base * 1.4, spec.z) * lightColour;
                if (spec.w > 0.0) {
                    vec3 R = vec3(2.0 * n.z * n.x, 2.0 * n.z * n.y, 2.0 * n.z * n.z - 1.0);
                    float room = smoothstep(-0.05, 0.4, -R.y) * rim;
                    glints += spec.w * (st(pow(nh, 240.0)) * 1.6 + room * 0.35) * lightColour;
                }
                if (more.x > 0.0) {
                    vec3 bow = 0.5 + 0.5 * cos(6.283 * ((1.0 - n.z) * 1.3 + vec3(0.0, 0.33, 0.67)));
                    glints += more.x * bow * 0.3 * lightColour * (0.4 + 0.6 * d);
                }
                if (clear.x > 0.0) {
                    // see-through: what's behind, bent toward where it's thicker, more so at the
                    // edges (where it's seen through slantwise, less clear: a rim), tinted by its
                    // colour, blurred when frosted
                    float edge = pow(1.0 - n.z, 2.0);
                    float t = clear.x * (1.0 - edge * 0.75);
                    vec2 px = sc - n.xy * clear.y * (0.4 + h);
                    vec3 seen = Texel(behind, px / screenSize).rgb;
                    if (clear.w > 0.0) {
                        seen += Texel(behind, (px + vec2(clear.w, 0.0)) / screenSize).rgb;
                        seen += Texel(behind, (px - vec2(clear.w, 0.0)) / screenSize).rgb;
                        seen += Texel(behind, (px + vec2(0.0, clear.w)) / screenSize).rgb;
                        seen += Texel(behind, (px - vec2(0.0, clear.w)) / screenSize).rgb;
                        seen /= 5.0;
                    }
                    seen *= mix(vec3(1.0), base * 1.3, clear.z);
                    col = mix(col, seen, t);
                }
                col += glints;
            } else if (mode > 5.5) {
                // fur: strands running down the picture in clumps, dark at the root, light at the
                // tips; the shine a streak across the strands (not a spot), a soft strong rim, and
                // a frayed edge instead of a cut one
                vec2 q = uv * vec2(more.y, 1.0);
                float clump = vnoise(q * 5.0) * fur.z;
                float across = (q.x + clump * 0.1 + vnoise(q * vec2(2.0, 0.7)) * 0.04) * fur.x;
                float along = q.y * fur.x / (5.0 + 25.0 * fur.y);
                float strand = vnoise(vec2(across, along)) * 0.6 + vnoise(vec2(across * 2.3 + 5.0, along * 1.7)) * 0.4;
                strand = smoothstep(0.2, 0.8, strand);
                // clumps lighter where their tips gather, darker toward the skin between them
                float tip = smoothstep(0.3, 0.8, vnoise(q * vec2(fur.x * 0.25, fur.x * 0.06) + 11.0));
                float depth = mix(0.35, 1.2, strand * 0.65 + tip * 0.35);
                vec3 T = normalize(vec3(clump * 0.5 - 0.25, 1.0, 0.25 - h * 0.3));
                vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
                float th = dot(T, H);
                float streak = st(pow(sqrt(max(0.0, 1.0 - th * th)), spec.y)) * spec.x * (0.5 + strand);
                float wrap = st(max(0.0, (ndl + 0.5) / 1.5));
                float rim = pow(1.0 - n.z, 1.6);
                float side = 0.35 + 0.65 * max(0.0, dot(normalize(n.xy + 1e-4), normalize(L.xy + 1e-4)));
                float back = clamp(-L.z * 2.0, 0.0, 1.0);
                col = base * depth * (ambient + wrap * lightColour) + streak * mix(base, vec3(1.0), 0.5) * lightColour
                    + st(rim * side * surf.y * (1.0 + 1.5 * back)) * mix(base, vec3(1.0), 0.6) * lightColour;
                alpha = m * smoothstep(0.0, 0.35, h * 3.0 + strand * 0.6 - 0.35);
            } else {
                // smoke: soft, light wrapped far round, wearing away from its edges as it goes;
                // from behind, its thin edges glow
                float wear = vnoise(uv * 5.0 + seed) * 0.55 + h * 0.75;
                alpha = m * smoothstep(dissolve - 0.12, dissolve + 0.12, wear);
                float back = clamp(-L.z * 2.0, 0.0, 1.0);
                float wrap = st(0.55 + 0.45 * ndl);
                float glow = st((1.0 - h) * back);
                col = base * (ambient * 0.8 + wrap * lightColour * (1.0 - 0.5 * back)) + glow * lightColour * 0.7;
            }
            if (wet > 0.0 && mode > 0.5 && mode != 4.0) {
                // just rained on: a sharp wet shine and drops, each drop dark with a bright spot
                // toward the light
                vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
                col += wet * st(pow(max(dot(n, H), 0.0), 160.0)) * 1.1 * lightColour;
                vec2 dp = uv * vec2(more.y, 1.0) * 11.0 + seed;
                float drop = 1.0 - smoothstep(0.07, 0.11, cells(dp).x);
                float spark = 1.0 - smoothstep(0.015, 0.04, cells(dp - L.xy * 0.05).x);
                float keep = step(0.55, hash(floor(dp) + 7.0)) * smoothstep(0.3, 0.7, wet);
                col = mix(col, col * 0.72, drop * keep) + spark * keep * lightColour * 0.9;
            }
            return vec4(col, alpha) * colour;
        }
    ]])
    return shader
end

---------------------------------------------------------------- the pictures, baked once per rise

local looks = {}
local function lookOf(name)
    local rise = RISES[lab().rise][2]
    local key = name .. '|' .. rise
    if looks[key] == nil then
        local base = 'textures/' .. name
        if love.filesystem.getInfo(base .. '-mask.png', 'file') then
            local line = love.graphics.newImage(base .. '.png', { mipmaps = true })
            local mask = love.graphics.newImage(base .. '-mask.png', { mipmaps = true })
            line:setFilter('linear', 'linear')
            mask:setFilter('linear', 'linear')
            line:setMipmapFilter('linear')
            mask:setMipmapFilter('linear')
            local form = love.graphics.newImage(formBake.bakeData(love.image.newImageData(base .. '-mask.png'), rise))
            form:setFilter('linear', 'linear')
            looks[key] = { line = line, mask = mask, form = form }
        else
            looks[key] = false
        end
    end
    return looks[key] or nil
end

local function lightColour()
    return LIGHTS[lab().light]
end

-- toward the light from (x, y), turned into the picture's frame (its rotation)
local function toLightFrom(x, y, rot)
    local c = lab()
    local dx, dy = c.lx - x, c.ly - y
    local dz = c.back and -LIGHT_DEPTH or LIGHT_DEPTH
    local ca, sa = math.cos(-(rot or 0)), math.sin(-(rot or 0))
    local rx, ry = dx * ca - dy * sa, dx * sa + dy * ca
    local len = math.sqrt(rx * rx + ry * ry + dz * dz)
    return { rx / len, ry / len, dz / len }
end

-- one picture in a material at (x, y), its longer side `size`
local function drawPicture(name, mode, base, x, y, size, opts)
    local look = lookOf(name)
    if not look then return end
    opts = opts or {}
    local c, L = lab(), lightColour()
    local w, h = look.mask:getDimensions()
    local scale = size / math.max(w, h)
    local rot = opts.rot or 0
    local sh = materialShader()
    love.graphics.setShader(sh)
    sh:send('form', look.form)
    local fw, fh = look.form:getDimensions()
    sh:send('formTexel', { 1 / fw, 1 / fh })
    sh:send('toLight', toLightFrom(x, y, rot))
    sh:send('lightColour', L.colour)
    sh:send('ambient', L.ambient)
    sh:send('baseColour', base)
    sh:send('mode', mode)
    sh:send('bands', c.painted and 4 or 0)
    sh:send('seed', opts.seed or 0)
    sh:send('dissolve', opts.dissolve or 0)
    local p = opts.params or {}
    local function four(t, d)
        t = t or {}
        return { t[1] or d[1], t[2] or d[2], t[3] or d[3], t[4] or d[4] }
    end
    sh:send('spec', four(p.spec, mode == 1 and { 1.5, 70, 0, 0 } or { 0, 1, 0, 0 }))
    sh:send('surf', four(p.surf, { 0, 0, 0, 0 }))
    sh:send('grain', four(p.grain, { 0, 1, 0, 0 }))
    sh:send('more', { p.rainbow or 0, w / h, p.rough or 0, 0 })
    sh:send('fur', four(p.fur, { 40, 0.3, 0.6, 0 }))
    sh:send('wet', c.wet or 0)
    sh:send('debug', c.debug or 0)
    sh:send('clear', four(p.clear, { 0, 0, 0, 0 }))
    sh:send('lines', look.line)
    sh:send('lineTexel', { 1 / look.line:getWidth(), 1 / look.line:getHeight() })
    sh:send('crease', CREASES[c.crease][2])
    sh:send('patternOn', opts.pattern and 1 or 0)
    if opts.pattern then
        sh:send('pattern', opts.pattern)
        sh:send('patternRepeat', PATTERN_SIZES[c.patternSize])
    end
    if c.behind then
        sh:send('behind', c.behind)
        sh:send('screenSize', { c.behind:getPixelDimensions() })
    end
    love.graphics.setColor(1, 1, 1, opts.alpha or 1)
    -- a pivot at the bottom (a leaf swaying from its stem)
    local oy = opts.pivotBottom and h or h / 2
    love.graphics.draw(look.mask, x, y, rot, scale, scale, w / 2, oy)
    love.graphics.setShader()
    if c.outlines and (c.debug or 0) == 0 and not opts.noOutline then
        local ink = opts.ink or { 0.12, 0.09, 0.08 }
        love.graphics.setColor(ink[1], ink[2], ink[3], (opts.alpha or 1) * (opts.inkAlpha or 1))
        love.graphics.draw(look.line, x, y, rot, scale, scale, w / 2, oy)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

---------------------------------------------------------------- smoke

local function updateSmoke(dt)
    local c = lab()
    c.spawn = c.spawn - dt
    if c.spawn <= 0 then
        c.spawn = 0.45 + love.math.random() * 0.25
        c.puffs[#c.puffs + 1] = {
            x = SMOKE.x + (love.math.random() - 0.5) * 40, y = SMOKE.y,
            vx = (love.math.random() - 0.5) * 30, vy = -(110 + love.math.random() * 50),
            age = 0, life = 6 + love.math.random() * 2.5, size = 190 + love.math.random() * 90,
            rot = love.math.random() * math.pi * 2, spin = (love.math.random() - 0.5) * 0.5,
            pic = PUFFS[love.math.random(#PUFFS)], seed = love.math.random() * 100,
            wobble = love.math.random() * 6.28,
        }
    end
    local keep = {}
    for _, p in ipairs(c.puffs) do
        p.age = p.age + dt
        if p.age < p.life then
            local t = p.age / p.life
            -- rising slows as it spreads; the wind takes more of it higher up
            p.x = p.x + (p.vx + c.wind * (40 + 160 * t) + math.sin(p.age * 0.9 + p.wobble) * 25) * dt
            p.y = p.y + p.vy * (1 - 0.55 * t) * dt
            p.rot = p.rot + p.spin * dt
            keep[#keep + 1] = p
        end
    end
    c.puffs = keep
end

local function drawSmoke()
    local c = lab()
    local kind = SMOKES[c.smoke]
    for _, p in ipairs(c.puffs) do
        local t = p.age / p.life
        local size = p.size * (0.5 + 1.6 * t)
        local fadeIn = math.min(1, p.age / 0.5)
        drawPicture(p.pic, 4, kind.colour, p.x, p.y, size, {
            rot = p.rot, seed = p.seed, dissolve = 0.3 + t ^ 1.2 * 0.85, alpha = kind.alpha * fadeIn,
            inkAlpha = 0.25 * (1 - t), ink = { kind.colour[1] * 0.4, kind.colour[2] * 0.4, kind.colour[3] * 0.4 },
        })
    end
end

---------------------------------------------------------------- the scene

function s.onStart()
    worldState.paused = false
    cam:setScale(0.255)
    cam:setTranslation(-330, 60)
end

function s.onUnload()
    looks = {}
end

function s.update(dt)
    local c = lab()
    dt = dt or 0
    -- hold h: the shape behind follows the mouse, the light stays; else it slides (j) or stays
    c.slideTime = (c.slideTime or 0) + (c.slide and dt or 0)
    if love.keyboard.isDown('h') then
        c.behindX, c.behindY = mouseWorldPos()
    else
        if c.slide then c.behindX = BEHIND.x + math.sin(c.slideTime * 0.3) * BEHIND.slide end
        if not c.frozen then c.lx, c.ly = mouseWorldPos() end
    end
    updateSmoke(dt)
    -- a shower: wet in two seconds, dry again over twenty
    if c.shower then
        c.shower = c.shower + dt
        if c.shower < 2 then
            c.wet = math.max(c.wet or 0, c.shower / 2)
        else
            c.wet = math.max(0, 1 - (c.shower - 2) / 20)
            if c.wet == 0 then c.shower = nil end
        end
    end
    c.time = (c.time or 0) + dt
    c.sinceFrame = (c.sinceFrame or 0) + dt
end

function s.onKeyPress(key)
    local c = lab()
    if key == 'b' then
        c.back = not c.back
    elseif key == 'f' then
        c.frozen = not c.frozen
    elseif key == 'c' then
        c.light = c.light % #LIGHTS + 1
    elseif key == 'p' then
        c.painted = not c.painted
    elseif key == 'o' then
        c.outlines = not c.outlines
    elseif key == 'n' then
        c.paletteShape = c.paletteShape % #PALETTE_SHAPES + 1
    elseif key == 'l' then
        c.leaves = c.leaves % #LEAF_SETS + 1
    elseif key == 's' then
        c.smoke = c.smoke % #SMOKES + 1
    elseif key == 'w' then
        c.wind = (c.wind == 0 and 1) or (c.wind == 1 and -1) or 0
    elseif key == 'm' then
        c.rise = c.rise % #RISES + 1
    elseif key == 'u' then
        c.second = c.second % #SECONDS + 1
    elseif key == 'i' then
        c.patternIndex = c.patternIndex % #PATTERNS + 1
    elseif key == 'y' then
        c.patternSize = c.patternSize % #PATTERN_SIZES + 1
    elseif key == 'k' then
        c.crease = c.crease % #CREASES + 1
    elseif key == 'x' then
        c.measureNext = true
    elseif key == 'j' then
        c.slide = not c.slide
    elseif key == 'r' then
        c.shower = 0
    elseif key == 'g' then
        c.debug = ((c.debug or 0) + 1) % 4
    elseif key == 'e' then
        c.post = not c.post
    elseif key == 't' then
        c.stepped = not c.stepped
    end
end

-- the paper wall behind, in the light's mood
function s.drawBelow()
    local wall = lightColour().wall
    local x0, y0 = cam:getWorldCoordinates(0, 0)
    local x1, y1 = cam:getWorldCoordinates(love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(wall[1], wall[2], wall[3], 1)
    love.graphics.rectangle('fill', x0, y0, x1 - x0, y1 - y0)
    love.graphics.setColor(1, 1, 1, 1)
end

local function label(text, x, y)
    local font = love.graphics.getFont()
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.print(text, x - font:getWidth(text) * 1.25 + 3, y + 3, 0, 2.5, 2.5)
    love.graphics.setColor(1, 0.97, 0.9, 1)
    love.graphics.print(text, x - font:getWidth(text) * 1.25, y, 0, 2.5, 2.5)
end

local function drawLight()
    local c, L = lab(), lightColour()
    local r, g, b = L.colour[1], L.colour[2], L.colour[3]
    if c.back then
        love.graphics.setColor(r, g, b, 0.8)
        love.graphics.setLineWidth(6)
        love.graphics.circle('line', c.lx, c.ly, 40)
        love.graphics.setLineWidth(1)
    else
        for k = 4, 1, -1 do
            love.graphics.setColor(r, g, b, 0.12)
            love.graphics.circle('fill', c.lx, c.ly, 20 + k * 22)
        end
        love.graphics.setColor(r, g, b, 1)
        love.graphics.circle('fill', c.lx, c.ly, 22)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- every material on one shape, in rows of GRID.columns; under each, its cost once measured (x)
local function cellAt(i)
    local col, row = (i - 1) % GRID.columns, math.floor((i - 1) / GRID.columns)
    return GRID.x + col * GRID.step, GRID.y + row * GRID.rowStep
end

-- the second material (u) and its pattern (i), or nil
local function secondMaterial()
    local name = SECONDS[lab().second]
    if not name then return nil end
    for _, mat in ipairs(PALETTE) do
        if mat.name == name then return mat end
    end
end

local patternImages = {}
local function patternImage()
    local name = PATTERNS[lab().patternIndex]
    if not patternImages[name] then
        local image = love.graphics.newImage('textures/pat/' .. name .. '.png')
        image:setWrap('repeat', 'repeat')
        image:setFilter('linear', 'linear')
        patternImages[name] = image
    end
    return patternImages[name]
end

local function drawPalette()
    local c = lab()
    local shape = PALETTE_SHAPES[c.paletteShape]
    for i, mat in ipairs(PALETTE) do
        local x, y = cellAt(i)
        local second = secondMaterial()
        local ink = (mat.mode == 6 and 0.35) or (mat.clear and 0.55) or 1
        drawPicture(shape, mat.mode or 5, mat.base, x, y, GRID.cell, {
            params = mat, seed = i * 3.1, inkAlpha = ink, noOutline = second ~= nil,
        })
        if second then
            drawPicture(shape, second.mode or 5, second.base, x, y, GRID.cell, {
                params = second, seed = i * 3.1, inkAlpha = ink, pattern = patternImage(),
            })
        end
        label(mat.name, x, y - GRID.cell / 2 - 55)
        local cost = c.costs and c.costs[mat.name]
        if cost then
            local text = string.format('x%.1f', cost.relative)
            love.graphics.setColor(0.15, 0.1, 0.08, 0.85)
            love.graphics.print(text, x + GRID.cell / 2 - 10, y + GRID.cell / 2 - 50, 0, 1.8, 1.8)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

-- the big striped shape behind everything: what the see-through materials show
local behindShader
local function drawBehindShape()
    local c = lab()
    local look = lookOf(BEHIND.pic)
    if not look then return end
    behindShader = behindShader or love.graphics.newShader([[
        uniform Image pattern;
        uniform vec3 stripe;
        vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 sc) {
            vec4 m = Texel(tex, uv);
            float p = Texel(pattern, uv * 7.0).a;
            return vec4(mix(colour.rgb, stripe, p), m.r * m.a);
        }
    ]])
    c.pattern = c.pattern or love.graphics.newImage('textures/pat/bee-stripes.png')
    c.pattern:setWrap('repeat', 'repeat')
    local w, h = look.mask:getDimensions()
    local scale = BEHIND.size / math.max(w, h)
    love.graphics.setShader(behindShader)
    behindShader:send('pattern', c.pattern)
    behindShader:send('stripe', BEHIND.stripe)
    love.graphics.setColor(BEHIND.colour[1], BEHIND.colour[2], BEHIND.colour[3], 1)
    love.graphics.draw(look.mask, c.behindX, c.behindY, -0.15, scale, scale, w / 2, h / 2)
    love.graphics.setShader()
    love.graphics.setColor(0.12, 0.09, 0.08, 1)
    love.graphics.draw(look.line, c.behindX, c.behindY, -0.15, scale, scale, w / 2, h / 2)
    love.graphics.setColor(1, 1, 1, 1)
end

-- what each material costs: drawn over a square canvas, against 'as drawn' (the cheapest: no light)
local function measureCosts()
    local c = lab()
    local shape = PALETTE_SHAPES[c.paletteShape]
    local entries = {}
    for _, mat in ipairs(PALETTE) do
        entries[#entries + 1] = { name = mat.name, draw = function(size)
            drawPicture(shape, mat.mode or 5, mat.base, size / 2, size / 2, size, { params = mat, noOutline = true })
        end }
    end
    entries[#entries + 1] = { name = 'leaf', draw = function(size)
        drawPicture(LEAF_SETS[1][1], 3, LEAF_COLOURS[1], size / 2, size / 2, size, { noOutline = true })
    end }
    entries[#entries + 1] = { name = 'smoke', draw = function(size)
        drawPicture(PUFFS[1], 4, SMOKES[1].colour, size / 2, size / 2, size, { noOutline = true, dissolve = 0.5 })
    end }
    local results = shaderCost.measure(entries, { baseline = 'as drawn' })
    c.costs = {}
    local lines = {}
    for _, r in ipairs(results) do
        c.costs[r.name] = r
        lines[#lines + 1] = string.format('%s %.2f (x%.1f)', r.name, r.msPerMP, r.relative)
    end
    table.sort(results, function(a, b) return a.msPerMP < b.msPerMP end)
    c.costLine = string.format('cost in ms per million pixels: cheapest %s %.2f, dearest %s %.2f, as drawn %.2f',
        results[1].name, results[1].msPerMP, results[#results].name, results[#results].msPerMP,
        c.costs['as drawn'].msPerMP)
    print('[material-check] ' .. table.concat(lines, ', '))
end

-- the picture pass, over the whole picture: a soft glow from the bright parts, a grade by the light
-- (warm by the candle, cool by the moon), a vignette and a film grain that changes 12 times a second
local postShader
local function picturePass()
    postShader = postShader or love.graphics.newShader([[
        uniform vec2 texel;
        uniform vec3 grade;
        uniform float frame;
        float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
        vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 sc) {
            vec3 c = Texel(tex, uv).rgb;
            vec3 glow = vec3(0.0);
            for (int i = 0; i < 12; i++) {
                float a = float(i) * 0.5236;
                for (int r = 1; r <= 2; r++) {
                    vec3 s = Texel(tex, uv + vec2(cos(a), sin(a)) * texel * float(r) * 9.0).rgb;
                    glow += max(s - 0.78, 0.0);
                }
            }
            c += glow / 24.0 * 1.6;
            c = mix(c, c * grade, 0.6);
            c = mix(vec3(dot(c, vec3(0.3, 0.59, 0.11))), c, 1.08); // a little more colour
            vec2 d = uv - 0.5;
            c *= 1.0 - dot(d, d) * 0.7;
            c += (hash(floor(sc / 1.5) + frame) - 0.5) * 0.06;
            return vec4(c, 1.0) * colour;
        }
    ]])
    return postShader
end
local GRADES = { { 1.04, 1.0, 0.92 }, { 1.1, 0.96, 0.82 }, { 0.86, 0.94, 1.1 } }

-- Everything goes through two canvases: what's behind (the wall and the striped shape), which the
-- see-through materials read, and the picture, which the picture pass (e) draws, and which is only
-- redrawn 12 times a second when stepped (t).
local drawPage

function s.draw()
    local c = lab()
    if c.measureNext then
        c.measureNext = false
        measureCosts()
    end
    local outer = love.graphics.getCanvas()
    local W, H = love.graphics.getDimensions()
    if outer then W, H = outer:getDimensions() end
    if not c.canvas or c.canvas:getWidth() ~= W or c.canvas:getHeight() ~= H then
        c.canvas = love.graphics.newCanvas(W, H)
        c.behind = love.graphics.newCanvas(W, H)
        c.sinceFrame = 1
    end
    if not c.stepped or c.sinceFrame >= 1 / 12 then
        c.sinceFrame = 0
        local wall = lightColour().wall
        love.graphics.setCanvas(c.behind)
        love.graphics.clear(wall[1], wall[2], wall[3], 1)
        drawBehindShape()
        love.graphics.setCanvas(c.canvas)
        love.graphics.push()
        love.graphics.origin()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(c.behind, 0, 0)
        love.graphics.pop()
        drawPage()
        love.graphics.setCanvas(outer)
    end
    love.graphics.push()
    love.graphics.origin()
    if c.post then
        local sh = picturePass()
        love.graphics.setShader(sh)
        sh:send('texel', { 1 / W, 1 / H })
        sh:send('grade', GRADES[c.light])
        sh:send('frame', math.floor(c.time * 12) % 97)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(c.canvas, 0, 0)
    love.graphics.setShader()
    love.graphics.pop()
end

drawPage = function()
    local c = lab()
    drawPalette()
    for i = 1, GRID.columns do
        local x = GRID.x + (i - 1) * GRID.step
        local leaf = LEAF_SETS[c.leaves][i]
        -- a slow sway and a small quick flutter, from the stem
        local t = c.stepped and math.floor(c.time * 12) / 12 or c.time
        local push = 0.05 + 0.08 * math.abs(c.wind)
        local sway = math.sin(t * 1.1 + i * 1.7) * push + math.sin(t * 4.3 + i * 2.9) * push * 0.25 + c.wind * 0.12
        drawPicture(leaf, i == 1 and 0 or 3, LEAF_COLOURS[i], x, LEAF_ROW, 330, { rot = sway, pivotBottom = true })
    end
    label('leaf, as drawn', GRID.x, LEAF_ROW + 15)
    label('leaves lit (b: from behind)', GRID.x + 3 * GRID.step, LEAF_ROW + 15)
    drawSmoke()
    label(SMOKES[c.smoke].name, SMOKE.x, SMOKE.y + 20)
    drawLight()
end

function s.drawUI()
    local c = lab()
    local lines = {
        'u second material   i pattern   y size   k creases   x cost   j slide   h hold: move the shape behind   b light in front / behind   f light stays / follows the mouse   c sun / candle / moon   p painted   o outlines'
            .. '   n shape   l leaves   s steam / smoke / soot   w wind   m rise   r shower   g sees   e pass   t 12 fps',
        string.format('light: %s, %s%s   %s   rise: %s   smoke: %s, wind %s   outlines %s',
            LIGHTS[c.light].name, c.back and 'behind' or 'in front', c.frozen and ' (stays)' or '',
            c.painted and 'painted in 4 steps' or 'smooth', RISES[c.rise][1], SMOKES[c.smoke].name,
            c.wind == 0 and 'still' or (c.wind > 0 and 'to the right' or 'to the left'), c.outlines and 'on' or 'off')
            .. string.format('   second %s in %s x%s', SECONDS[c.second] or 'off', PATTERNS[c.patternIndex],
                PATTERN_SIZES[c.patternSize])
            .. string.format('   creases %s   wet %.1f   sees: %s   pass %s   %s', CREASES[c.crease][1], c.wet or 0,
                ({ 'off', 'height', 'normals', 'light alone' })[(c.debug or 0) + 1], c.post and 'on' or 'off',
                c.stepped and '12 fps' or 'smooth'),
        c.costLine or 'x: measure what each material costs',
    }
    for i, line in ipairs(lines) do
        local y = love.graphics.getHeight() - 20 - (#lines - i + 1) * 20
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.print(line, 121, y + 1)
        love.graphics.setColor(1, 0.95, 0.8, 1)
        love.graphics.print(line, 120, y)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return s

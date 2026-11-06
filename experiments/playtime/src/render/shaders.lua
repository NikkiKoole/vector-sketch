-- src/render/shaders.lua (split from physics/box2d-draw-textured.lua, SPLIT1)
local lib = {}
local registry = require('src.registry')
local subtypes = require('src.subtypes')
local color = require('src.color')
local formBake = require('src.render.form-bake')
local materials = require('src.render.materials')
local wet = require('src.wet')
local state = require('src.state')


-- Plasticine POC: procedural grain + soft edge darkening.
-- Noise samples in UV space so it rotates/translates with the body (noise stuck to
-- the character, not the screen). fBm approximates thumbprint texture without an
-- asset file. Tune via lib.plasticineStrength / lib.plasticineScale / lib.plasticineEdge.
local MAX_LIGHTS = 8
local plasticineShader = love.graphics.newShader([[
    #define MAX_LIGHTS 8
    uniform float strength;
    uniform float scale;
    uniform float edgeDark;
    uniform float bumpAmp;       // micro-normal tilt (thumb-dent depth)
    uniform float formStrength;  // macro-form tilt from alpha gradient (rounds the shape)
    uniform float formRadius;    // UV-space step for the alpha gradient sample
    uniform float useForm;       // 0/1 — gate macro-form contribution
    uniform Image formMap;       // the shape's roundness baked from its mask (src/render/form-bake.lua):
    uniform float useFormMap;    //   g b the normal's x y; 1 = use it instead of the alpha guess below
    uniform float rimStyle;      // 0=off, 1=silhouette, 2=UV vignette
    uniform float mottleStrength; // pigment mottling intensity (0 = off)
    uniform float mottleScale;   // mottling spatial frequency (low = big blobs)
    uniform float useLighting;   // 0 = disable all lighting (noise/bump only)
    uniform float specPow;       // specular shininess (Blinn-Phong exponent)
    uniform float specStrength;  // specular intensity scalar
    uniform float sssPow;        // SSS falloff: lower = wider softer scatter
    uniform float sssStrength;   // SSS intensity (replaces spec for clay look)
    uniform float terminatorPow; // lambert falloff exponent: higher = tighter shadow edge
    uniform float lightZ;        // how much the lights come from the front (0.9: mostly; lower: more from the side)
    uniform float lightGain;     // light's brightness swing, darkest 1-gain to brightest 1+gain (0: from strength)
    uniform float lightAdd;      // 1: lights add up (sky lights the base), a soft shoulder past full
    uniform vec3  warmColor;     // lit-side chromatic tint (e.g. amber)
    uniform vec3  coolColor;     // shadow-side chromatic tint = environment/ambient color
    uniform int   lightCount;    // number of active lights (0 → baked default)
    uniform vec2  lightDir[MAX_LIGHTS];       // body-local (CPU-rotated)
    uniform vec3  lightColor[MAX_LIGHTS];
    uniform float lightIntensity[MAX_LIGHTS];
    uniform int   lightType[MAX_LIGHTS];      // 0 = directional, 1 = point
    uniform vec2  lightLocalPos[MAX_LIGHTS];  // same coord space as vertex positions
    uniform float lightRange[MAX_LIGHTS];     // falloff distance (world or body-local units)
    uniform vec3  lightGround[MAX_LIGHTS];    // a sky light's ground colour (lightType 2)
    // A material instead of clay (src/render/materials.lua; 0 = clay, as always): 1 metal, 2 velvet,
    // 5 a surface. The part's own colours and pattern stay; the material is how they take the light.
    uniform float matKind;
    uniform vec4  matSpec;       // shine strength, size, tint by its colour, clear coat
    uniform vec4  matSurf;       // light wrap, sheen at the edges, edges darkened, rough (metal)
    uniform vec4  matTint;       // rgb: a metal's own colour (brass, gold); a: how much of it
    // Wet (src/wet.lua): spots in screen pixels (x, y, radius, how wet), up to MAX_WET
    #define MAX_WET 12
    uniform int   wetCount;
    uniform vec4  wetSpot[MAX_WET];

    // Passed from vertex shader: vertex position BEFORE the love.graphics transform.
    // For bodies drawn with draw(mesh, bx, by, ba) this is body-local space.
    // For CTs drawn with draw(mesh) this is world space.
    // lightLocalPos is computed in the same space, so distance math is always correct.
    varying vec2 varVertexPos;

    #ifdef VERTEX
    vec4 position(mat4 transform_projection, vec4 vertex_position) {
        varVertexPos = vertex_position.xy;
        return transform_projection * vertex_position;
    }
    #endif

    #ifdef PIXEL

    float hash(vec2 p) {
        return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
    }
    float vnoise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        float a = hash(i);
        float b = hash(i + vec2(1.0, 0.0));
        float c = hash(i + vec2(0.0, 1.0));
        float d = hash(i + vec2(1.0, 1.0));
        return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
    }
    float fbm(vec2 p) {
        float f = 0.0;
        f += 0.5   * vnoise(p);
        f += 0.25  * vnoise(p * 2.13 + vec2(3.7, 1.1));
        f += 0.125 * vnoise(p * 4.71 + vec2(1.3, 5.2));
        return f;
    }

    // light past full rounds off instead of clipping: as it is up to 0.8, then towards 1.35
    vec3 shoulder(vec3 x) {
        vec3 over = max(x - 0.8, 0.0);
        return min(x, vec3(0.8)) + over / (1.0 + over / 0.55);
    }

    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 fc) {
        vec4 base = Texel(tex, uv) * color;
        if (base.a < 0.01) return base;

        // --- Pigment mottling: coarse per-channel noise breaks flat paint fill ---
        if (mottleStrength > 0.001) {
            vec2 mp = uv * mottleScale;
            float mr = mix(1.0, vnoise(mp + vec2(0.00, 0.00)), mottleStrength);
            float mg = mix(1.0, vnoise(mp + vec2(3.73, 1.31)), mottleStrength);
            float mb = mix(1.0, vnoise(mp + vec2(1.13, 5.17)), mottleStrength);
            base.rgb *= vec3(mr, mg, mb);
        }

        // --- Micro-normal from fBm (thumb-dents): clay's only; a material skips the noise (9 lookups) ---
        float h = 0.5;
        vec2 microTilt = vec2(0.0);
        if (matKind < 0.5) {
            vec2 p = uv * scale;
            h  = fbm(p);
            float hx = fbm(p + vec2(0.5, 0.0));
            float hy = fbm(p + vec2(0.0, 0.5));
            microTilt = vec2(-(hx - h), -(hy - h)) * bumpAmp;
        }

        // --- Alpha neighborhood: gradient for form shading, average for rim ---
        // Sample the texture's own alpha at ±formRadius in UV space. The gradient
        // points outward at the silhouette (drives the macro-normal → rounded form).
        // The average smoothly goes from 1 in the deep interior to 0 at the edge —
        // use it for the rim so the darkening has a soft interior-to-edge falloff
        // (like the old UV vignette) but tracks the actual shape.
        float aR = Texel(tex, uv + vec2(formRadius, 0.0)).a;
        float aL = Texel(tex, uv - vec2(formRadius, 0.0)).a;
        float aU = Texel(tex, uv + vec2(0.0, formRadius)).a;
        float aD = Texel(tex, uv - vec2(0.0, formRadius)).a;
        vec2  gAlpha   = vec2(aR - aL, aU - aD) * 0.5;
        float avgAlpha = (aR + aL + aU + aD) * 0.25;
        vec2 macroTilt = (useForm > 0.5) ? (-gAlpha * formStrength) : vec2(0.0);
        if (useFormMap > 0.5) {
            // round all the way in, not only at the edge: the baked normal as a tilt (formStrength 2 = as baked)
            vec2 nxy = (Texel(formMap, uv).gb - 0.5) * 2.0;
            float nz = sqrt(max(1.0 - dot(nxy, nxy), 0.04));
            macroTilt = nxy / nz * formStrength * 0.5;
        }

        vec3 n = normalize(vec3(microTilt + macroTilt, 1.0));
        // the lights' main way, for a material's shine (weighted by how much each reaches it)
        vec3 Lmain = vec3(0.0);

        // --- Multi-light accumulation ---
        vec3  totalSpec  = vec3(0.0);
        vec3  totalSSS   = vec3(0.0);
        vec3  tint  = vec3(1.0);
        float shade = 1.0;
        if (useLighting > 0.5) {
            vec3  totalLight = vec3(0.0);
            float weightSum  = 0.0;
            vec3  V = vec3(0.0, 0.0, 1.0);
            // Thin-edge weight: silhouette areas scatter more (less avgAlpha = thinner clay)
            float thinEdge = 1.0 - avgAlpha;
            if (lightCount <= 0) {
                vec3 L = normalize(vec3(-0.7, -0.7, lightZ));
                float lambert = pow(dot(n, L) * 0.5 + 0.5, terminatorPow);
                totalLight = vec3(lambert);
                weightSum  = lambert;
                float backFace = pow(max(-dot(n, L) * 0.5 + 0.5, 0.0), sssPow);
                totalSSS = vec3(backFace * sssStrength * thinEdge);
            } else {
                for (int i = 0; i < MAX_LIGHTS; ++i) {
                    if (i >= lightCount) break;
                    if (lightType[i] == 3) {
                        // a back light: from behind, towards you. The shape's edges glow in its colour,
                        // most those facing where it comes from (lightDir: towards it); the middle,
                        // facing you, not at all. Added on top, like the sheen
                        float facing = length(n.xy) > 0.001
                            ? max(dot(normalize(n.xy), normalize(lightDir[i])), 0.0) : 0.0;
                        // its own narrow edge: the picture's alpha just around (the form's measure
                        // reaches far in), small see-through gaps (fur) not counted
                        float rr = lightRange[i]; // a back light's width (extra.rimWidth)
                        float near = (Texel(tex, uv + vec2(rr, 0.0)).a + Texel(tex, uv - vec2(rr, 0.0)).a
                            + Texel(tex, uv + vec2(0.0, rr)).a + Texel(tex, uv - vec2(0.0, rr)).a) * 0.25;
                        float edge = smoothstep(0.15, 0.6, 1.0 - near);
                        totalSpec += lightColor[i] * edge * facing * lightIntensity[i] * 0.3;
                        continue;
                    }
                    if (lightType[i] == 2) {
                        // a sky light: its colour from all of above, its ground colour from all of
                        // below (lightDir: up, body-local), wherever it is; no falloff, no sheen
                        float up = dot(n, normalize(vec3(lightDir[i], 0.0))) * 0.5 + 0.5;
                        float w = lightIntensity[i];
                        totalLight += mix(lightGround[i], lightColor[i], up) * w;
                        weightSum  += w;
                        continue;
                    }
                    vec3  L;
                    float atten = 1.0;
                    if (lightType[i] == 1) {
                        vec2  delta = lightLocalPos[i] - varVertexPos;
                        float dist  = length(delta);
                        atten = 1.0 - smoothstep(0.0, max(lightRange[i], 1.0), dist);
                        vec2 dir2D = delta / max(dist, 0.001);
                        L = normalize(vec3(dir2D, lightZ));
                    } else {
                        L = normalize(vec3(lightDir[i], lightZ));
                        if (lightRange[i] > 0.0) {
                            float dist = length(lightLocalPos[i] - varVertexPos);
                            atten = 1.0 - smoothstep(0.0, lightRange[i], dist);
                        }
                    }
                    float lambert = pow(dot(n, L) * 0.5 + 0.5, terminatorPow);
                    float w = lambert * lightIntensity[i] * atten;
                    Lmain += L * lightIntensity[i] * atten;
                    totalLight += lightColor[i] * w;
                    weightSum  += w;
                    vec3  H    = normalize(L + V);
                    float spec = pow(max(dot(n, H), 0.0), specPow) * specStrength * atten * lightIntensity[i];
                    totalSpec += lightColor[i] * spec;
                    // SSS: back-face scatter tinted by light color, strongest at thin edges
                    float backFace = pow(max(-dot(n, L) * 0.5 + 0.5, 0.0), sssPow);
                    totalSSS += lightColor[i] * backFace * sssStrength * atten * lightIntensity[i] * thinEdge;
                }
            }
            float attenBlend = clamp(weightSum, 0.0, 1.0);
            vec3 rawTint = (weightSum > 0.001) ? totalLight / weightSum : vec3(1.0);
            tint  = mix(coolColor, rawTint * warmColor, attenBlend);
            shade = (lightGain > 0.0) ? mix(1.0 - lightGain, 1.0 + lightGain, attenBlend)
                                      : mix(1.0 - strength, 1.0 + strength * 0.5, attenBlend);
            if (lightAdd > 0.5) {
                // every light's colour and strength added (the sky lights the base), not averaged
                tint  = shoulder(totalLight);
                shade = 1.0;
            }
        }

        float pit = mix(1.0 - strength * 0.25, 1.0, smoothstep(0.15, 0.55, h));

        // Rim darkening — switchable for A/B: silhouette (shape-tracking, smooth
        // via avgAlpha) vs old UV vignette (smooth but circle-shaped) vs off.
        float rim = 0.0;
        if (rimStyle > 1.5) {
            vec2 dc = uv - vec2(0.5);
            float r = clamp(length(dc) * 2.0, 0.0, 1.0);
            rim = smoothstep(0.55, 1.0, r);
        } else if (rimStyle > 0.5) {
            rim = 1.0 - avgAlpha;
        }
        float ao = mix(1.0, 1.0 - edgeDark, rim);

        // how wet here: the spots (screen pixels), each drying from its edge in
        float wet = 0.0;
        for (int i = 0; i < MAX_WET; ++i) {
            if (i >= wetCount) break;
            vec4 sp = wetSpot[i];
            float r = sp.z * sqrt(max(sp.w, 0.0));
            wet = max(wet, (1.0 - smoothstep(r * 0.7, r, length(fc - sp.xy))) * min(1.0, sp.w * 3.0));
        }
        vec3 Ld = length(Lmain) > 0.001 ? normalize(Lmain) : normalize(vec3(-0.7, -0.7, lightZ));
        vec3 Lc = (useLighting > 0.5 && lightCount > 0) ? tint : vec3(1.0);

        if (matKind > 0.5) {
            vec3 c0 = base.rgb;
            if (matTint.a > 0.0) {
                // a metal's own colour, the part's light and dark (its pattern) kept
                float lum = dot(c0, vec3(0.3, 0.59, 0.11));
                c0 = mix(c0, matTint.rgb * (0.45 + 0.75 * lum), matTint.a);
            }
            // wet: porous things darken most, metal and glaze hardly
            if (wet > 0.0) c0 *= 1.0 - 0.42 * wet * (matKind < 1.5 ? 0.15 : 1.0 - min(matSpec.w, 1.0) * 0.7);
            vec3 lit = shade * tint;
            float rimN = pow(1.0 - n.z, 2.0);
            float side = 0.35 + 0.65 * max(0.0, dot(normalize(n.xy + 1e-4), normalize(Ld.xy + 1e-4)));
            vec3 H = normalize(Ld + vec3(0.0, 0.0, 1.0));
            float nh = max(dot(n, H), 0.0);
            vec3 col;
            if (matKind < 1.5) {
                // metal: the room reflected (bright above, a dark band at the horizon, the warm floor),
                // lit by the lights, its highlight in its own colour
                vec3 R = vec3(2.0 * n.z * n.x, 2.0 * n.z * n.y, 2.0 * n.z * n.z - 1.0);
                float up = -R.y;
                float env = mix(0.42, 1.0, smoothstep(-0.05, 0.25, up));
                env -= 0.32 * (1.0 - smoothstep(0.0, 0.12, abs(up + 0.02)));
                env = mix(env, 0.6, 0.35 * n.z * n.z);
                env = mix(env, 0.62, matSurf.w * 0.75);
                float rl = max(dot(R, Ld), 0.0);
                float shine = pow(rl, max(matSpec.y, 1.0)) * matSpec.x + pow(rl, 6.0) * 0.25;
                col = c0 * env * (lit * 0.85 + 0.2) + shine * mix(c0, vec3(1.0), 0.45) * Lc;
            } else if (matKind < 2.5) {
                // velvet: the middle soaks up the light, the edges where the pile lies over shine
                col = c0 * 0.6 * lit + rimN * side * mix(c0, vec3(1.0), 0.45) * Lc * 0.9;
            } else {
                // a surface: the light, edges darkened, a sheen, a shine, a clear coat
                col = c0 * lit * (1.0 - matSurf.z * pow(1.0 - n.z, 1.5));
                col += rimN * side * matSurf.y * mix(c0, vec3(1.0), 0.5) * Lc;
                if (matSpec.x > 0.0)
                    col += pow(nh, max(matSpec.y, 1.0)) * matSpec.x * mix(vec3(1.0), c0 * 1.4, matSpec.z) * Lc;
                if (matSpec.w > 0.0) {
                    vec3 R = vec3(2.0 * n.z * n.x, 2.0 * n.z * n.y, 2.0 * n.z * n.z - 1.0);
                    col += matSpec.w * (pow(nh, 240.0) * 1.6 + smoothstep(-0.05, 0.4, -R.y) * rimN * 0.35) * Lc;
                }
            }
            base.rgb = col;
        } else {
            if (wet > 0.0) base.rgb *= 1.0 - 0.42 * wet;
            base.rgb *= shade * pit * ao * tint;
            base.rgb += (totalSpec + totalSSS) * base.a;
        }
        if (wet > 0.0) {
            // wet: a soft sheen where the light catches it (a tight one broke up into white
            // specks on bumpy parts, Nikki 2026-11-06)
            vec3 H = normalize(Ld + vec3(0.0, 0.0, 1.0));
            base.rgb += wet * pow(max(dot(n, H), 0.0), 40.0) * 0.55 * Lc * base.a;
        }
        return base;
    }
    #endif
]])

lib.plasticineStrength    = 0.18
lib.plasticineScale       = 28.0
lib.plasticineEdge        = 0.22
lib.plasticineBump        = 2.5
lib.plasticineLight       = { -0.7, -0.7 }
lib.plasticineFormStrength = 2.0
lib.plasticineFormRadius   = 0.08
lib.plasticineUseLighting  = true
lib.plasticineLightZ       = 0.9  -- lights mostly from the front; lower: the side they come from shows more
lib.plasticineLightGain    = 0    -- 0: the light swings brightness by strength (x0.82..x1.09); else x(1-g)..x(1+g)
lib.plasticineFormRise     = 1    -- a baked form's rise (form-bake): 1 a dome, 0.2 a pebble
lib.plasticineMottleStrength = 0.0
lib.plasticineMottleScale    = 3.0
lib.plasticineSpecPow      = 25.0
lib.plasticineSpecStrength = 0.2
lib.plasticineSSSpow       = 2.0
lib.plasticineSSSstrength  = 0.0
lib.plasticineTerminator   = 2.0
lib.plasticineWarmHex      = 'ffedccff'   -- amber: lit side
lib.plasticineCoolHex      = 'c8d8ffff'   -- steel blue: shadow/environment

-- Hairs POC: noise-based strand variation + noisy frayed alpha at the edges.
-- Stretched value-noise (low-freq along uv.x, high-freq along uv.y) gives "strand"
-- cells running along the ribbon. Near the uv.y boundaries alpha is modulated by
-- fresh noise so the silhouette looks frayed rather than cleanly cut. Assumes
-- uv.y = across width; on surfaces where the axes are swapped, strands simply
-- run the other way — tune density to taste.
local hairsShader = love.graphics.newShader([[
    #define MAX_LIGHTS 8
    uniform float strength;      // strand brightness variation
    uniform float density;       // strand density
    uniform float fuzz;          // edge frayness
    uniform float bush;          // silhouette growth
    uniform float formRadius;    // UV-space step for alpha-gradient normal
    uniform float formStrength;  // macro-normal tilt from alpha gradient
    uniform float mottleStrength;
    uniform float mottleScale;
    uniform float useLighting;
    uniform float specPow;
    uniform float specStrength;
    uniform float sssPow;
    uniform float sssStrength;
    uniform float terminatorPow;
    uniform float lightZ;
    uniform float lightGain;
    uniform float lightAdd;
    uniform vec3  warmColor;
    uniform vec3  coolColor;
    uniform int   lightCount;
    uniform vec2  lightDir[MAX_LIGHTS];
    uniform vec3  lightColor[MAX_LIGHTS];
    uniform float lightIntensity[MAX_LIGHTS];
    uniform int   lightType[MAX_LIGHTS];
    uniform vec2  lightLocalPos[MAX_LIGHTS];
    uniform float lightRange[MAX_LIGHTS];
    uniform vec3  lightGround[MAX_LIGHTS];

    varying vec2 varVertexPos;

    #ifdef VERTEX
    vec4 position(mat4 transform_projection, vec4 vertex_position) {
        varVertexPos = vertex_position.xy;
        return transform_projection * vertex_position;
    }
    #endif

    #ifdef PIXEL

    float hash(vec2 p) {
        return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
    }
    float vnoise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        float a = hash(i);
        float b = hash(i + vec2(1.0, 0.0));
        float c = hash(i + vec2(0.0, 1.0));
        float d = hash(i + vec2(1.0, 1.0));
        return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
    }

    // light past full rounds off instead of clipping: as it is up to 0.8, then towards 1.35
    vec3 shoulder(vec3 x) {
        vec3 over = max(x - 0.8, 0.0);
        return min(x, vec3(0.8)) + over / (1.0 + over / 0.55);
    }

    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 fc) {
        vec4 base = Texel(tex, uv) * color;

        // --- Bushy growth ---
        if (bush > 0.01 && base.a < 0.05) {
            float r = bush * 0.08;
            vec4 sR = Texel(tex, uv + vec2( r, 0.0));
            vec4 sL = Texel(tex, uv + vec2(-r, 0.0));
            vec4 sU = Texel(tex, uv + vec2(0.0,  r));
            vec4 sD = Texel(tex, uv + vec2(0.0, -r));
            float nearA = (sR.a + sL.a + sU.a + sD.a) * 0.25;
            if (nearA > 0.02) {
                float wSum = sR.a + sL.a + sU.a + sD.a;
                vec3 avgRGB = (sR.rgb * sR.a + sL.rgb * sL.a
                             + sU.rgb * sU.a + sD.rgb * sD.a) / wSum;
                float bushN = vnoise(uv * density * 2.0) * 0.6
                            + vnoise(uv * density * 8.0) * 0.4;
                float growA = smoothstep(0.45, 0.75, bushN) * nearA * bush;
                if (growA > base.a) {
                    base.rgb = avgRGB * color.rgb;
                    base.a   = growA;
                }
            }
        }

        if (base.a < 0.01) return base;

        // --- Pigment mottling ---
        if (mottleStrength > 0.001) {
            vec2 mp = uv * mottleScale;
            float mr = mix(1.0, vnoise(mp + vec2(0.00, 0.00)), mottleStrength);
            float mg = mix(1.0, vnoise(mp + vec2(3.73, 1.31)), mottleStrength);
            float mb = mix(1.0, vnoise(mp + vec2(1.13, 5.17)), mottleStrength);
            base.rgb *= vec3(mr, mg, mb);
        }

        // --- Alpha-gradient normal (rounds the hair bundle cross-section) ---
        float aR = Texel(tex, uv + vec2(formRadius, 0.0)).a;
        float aL = Texel(tex, uv - vec2(formRadius, 0.0)).a;
        float aU = Texel(tex, uv + vec2(0.0, formRadius)).a;
        float aD = Texel(tex, uv - vec2(0.0, formRadius)).a;
        float avgAlpha = (aR + aL + aU + aD) * 0.25;
        vec2 macroTilt = -vec2(aR - aL, aU - aD) * 0.5 * formStrength;
        vec3 n = normalize(vec3(macroTilt, 1.0));

        // --- Light accumulation ---
        vec3  totalSpec  = vec3(0.0);
        vec3  totalSSS   = vec3(0.0);
        vec3  tint       = vec3(1.0);
        float lightShade = 1.0;
        if (useLighting > 0.5) {
            vec3  totalLight = vec3(0.0);
            float weightSum  = 0.0;
            vec3  V = vec3(0.0, 0.0, 1.0);
            float thinEdge = 1.0 - avgAlpha;
            if (lightCount <= 0) {
                vec3 L = normalize(vec3(-0.7, -0.7, lightZ));
                float lambert = pow(dot(n, L) * 0.5 + 0.5, terminatorPow);
                totalLight = vec3(lambert);
                weightSum  = lambert;
                float backFace = pow(max(-dot(n, L) * 0.5 + 0.5, 0.0), sssPow);
                totalSSS = vec3(backFace * sssStrength * thinEdge);
            } else {
                for (int i = 0; i < MAX_LIGHTS; ++i) {
                    if (i >= lightCount) break;
                    if (lightType[i] == 3) {
                        // a back light: from behind, towards you. The shape's edges glow in its colour,
                        // most those facing where it comes from (lightDir: towards it); the middle,
                        // facing you, not at all. Added on top, like the sheen
                        float facing = length(n.xy) > 0.001
                            ? max(dot(normalize(n.xy), normalize(lightDir[i])), 0.0) : 0.0;
                        // its own narrow edge: the picture's alpha just around (the form's measure
                        // reaches far in), small see-through gaps (fur) not counted
                        float rr = lightRange[i]; // a back light's width (extra.rimWidth)
                        float near = (Texel(tex, uv + vec2(rr, 0.0)).a + Texel(tex, uv - vec2(rr, 0.0)).a
                            + Texel(tex, uv + vec2(0.0, rr)).a + Texel(tex, uv - vec2(0.0, rr)).a) * 0.25;
                        float edge = smoothstep(0.15, 0.6, 1.0 - near);
                        totalSpec += lightColor[i] * edge * facing * lightIntensity[i] * 0.3;
                        continue;
                    }
                    if (lightType[i] == 2) {
                        // a sky light: its colour from all of above, its ground colour from all of
                        // below (lightDir: up, body-local), wherever it is; no falloff, no sheen
                        float up = dot(n, normalize(vec3(lightDir[i], 0.0))) * 0.5 + 0.5;
                        float w = lightIntensity[i];
                        totalLight += mix(lightGround[i], lightColor[i], up) * w;
                        weightSum  += w;
                        continue;
                    }
                    vec3  L;
                    float atten = 1.0;
                    if (lightType[i] == 1) {
                        vec2  delta = lightLocalPos[i] - varVertexPos;
                        float dist  = length(delta);
                        atten = 1.0 - smoothstep(0.0, max(lightRange[i], 1.0), dist);
                        L = normalize(vec3(delta / max(dist, 0.001), lightZ));
                    } else {
                        L = normalize(vec3(lightDir[i], lightZ));
                        if (lightRange[i] > 0.0) {
                            float dist = length(lightLocalPos[i] - varVertexPos);
                            atten = 1.0 - smoothstep(0.0, lightRange[i], dist);
                        }
                    }
                    float lambert = pow(dot(n, L) * 0.5 + 0.5, terminatorPow);
                    float w = lambert * lightIntensity[i] * atten;
                    totalLight += lightColor[i] * w;
                    weightSum  += w;
                    vec3  H    = normalize(L + V);
                    float spec = pow(max(dot(n, H), 0.0), specPow) * specStrength * atten * lightIntensity[i];
                    totalSpec += lightColor[i] * spec;
                    float backFace = pow(max(-dot(n, L) * 0.5 + 0.5, 0.0), sssPow);
                    totalSSS += lightColor[i] * backFace * sssStrength * atten * lightIntensity[i] * thinEdge;
                }
            }
            float attenBlend = clamp(weightSum, 0.0, 1.0);
            vec3 rawTint = (weightSum > 0.001) ? totalLight / weightSum : vec3(1.0);
            tint       = mix(coolColor, rawTint * warmColor, attenBlend);
            lightShade = (lightGain > 0.0) ? mix(1.0 - lightGain, 1.0 + lightGain, attenBlend)
                                           : mix(1.0 - strength, 1.0 + strength * 0.5, attenBlend);
            if (lightAdd > 0.5) {
                tint       = shoulder(totalLight);
                lightShade = 1.0;
            }
        }

        // Rim darkening from alpha gradient
        float ao = mix(1.0, avgAlpha, 0.4);

        // Per-strand brightness variation layered on top of lighting
        float strandN = vnoise(vec2(uv.x * density * 0.2, uv.y * density));
        float strandMod = mix(0.85, 1.15, strandN);

        base.rgb *= lightShade * ao * tint * strandMod;
        base.rgb += (totalSpec + totalSSS) * base.a;

        // Frayed alpha near the uv.y edges
        float edgeY  = abs(uv.y - 0.5) * 2.0;
        float inFray = smoothstep(1.0 - fuzz, 1.0, edgeY);
        float frayN  = vnoise(vec2(uv.x * density * 3.0, uv.y * density * 3.0));
        base.a *= 1.0 - inFray * (1.0 - frayN);

        return base;
    }
    #endif
]])

lib.hairsStrength = 0.35
lib.hairsDensity  = 8.0
lib.hairsFuzz     = 0.15
lib.hairsBush     = 0.0

-- Reused per-draw buffers so we don't churn tables each frame.
-- One slot per light the shaders take (MAX_LIGHTS); lightTypeBuf 0 = directional, 1 = point, 2 = sky,
-- 3 = back (a rim from behind; its direction as a directional light's).
local lightDirBuf, lightColorBuf, lightInBuf, lightTypeBuf, lightPosBuf, lightRangeBuf = {}, {}, {}, {}, {}, {}
for i = 1, MAX_LIGHTS do
    lightDirBuf[i], lightColorBuf[i], lightInBuf[i] = { 0, 0 }, { 1, 1, 1 }, 0
    lightTypeBuf[i], lightPosBuf[i], lightRangeBuf[i] = 0, { 0, 0 }, 1
end
local lightGroundBuf = {}
for i = 1, MAX_LIGHTS do lightGroundBuf[i] = { 0, 0, 0 } end
local LIGHT_TYPES = { directional = 0, point = 1, sky = 2, back = 3 }

-- Uniforms sent only when they differ from what that shader last got (most lit parts share the clay's
-- defaults and the frame's lights; sending every one for every part was two thirds of setSurfaceShader
-- on an iPhone SE 2 once the lights were cached, LIGHT-AND-SHADOW LS23). Per shader: a uniform keeps
-- its value until sent again. Tables are compared by their numbers and kept as a copy.
local sentTo = setmetatable({}, { __mode = 'k' })
local function send(shader, name, v)
    local sent = sentTo[shader]
    if not sent then
        sent = {}
        sentTo[shader] = sent
    end
    local old = sent[name]
    if type(v) == 'table' then
        if old and #old == #v then
            local same = true
            for i = 1, #v do
                if old[i] ~= v[i] then same = false; break end
            end
            if same then return end
        end
        old = old or {}
        for i = 1, #v do old[i] = v[i] end
        for i = #v + 1, #old do old[i] = nil end
        sent[name] = old
    else
        if old == v then return end
        sent[name] = v
    end
    shader:send(name, v)
end

-- a colour string's numbers, parsed once
local hexColours = {}
local function hexColour(hex)
    local c = hexColours[hex]
    if not c then
        c = { color.hexToColor(hex) }
        c[4] = nil
        hexColours[hex] = c
    end
    return c
end

-- Send light arrays to any shader that exposes the standard light uniforms.
-- Honors the legacy per-fixture `extra.plasticineLight` override.
-- The way to each light and its place differ per part (its own frame); the lights' colours, strengths,
-- types, ranges and ground colours are the same for every part in a frame: sent once a frame per shader.
local function sendLightsToShader(shader, body, extra)
    local sent = sentTo[shader] or {}
    sentTo[shader] = sent
    if extra.plasticineLight then
        lightDirBuf[1][1]   = extra.plasticineLight[1]
        lightDirBuf[1][2]   = extra.plasticineLight[2]
        lightColorBuf[1][1] = 1
        lightColorBuf[1][2] = 1
        lightColorBuf[1][3] = 1
        lightInBuf[1]       = 1
        lightTypeBuf[1]     = 0
        lightPosBuf[1][1]   = 0
        lightPosBuf[1][2]   = 0
        lightRangeBuf[1]    = 1
        send(shader, 'lightCount', 1)
        sent.lightVersion = nil -- the buffers aren't the frame's lights: send them all, and next time too
    else
        local fx = (extra.main and extra.main.fx) or 1
        local fy = (extra.main and extra.main.fy) or 1
        local count, _, _, _, version = lib.gatherLightsForBody(body, fx, fy)
        send(shader, 'lightCount', count)
        shader:send('lightDir',      unpack(lightDirBuf))
        shader:send('lightLocalPos', unpack(lightPosBuf))
        if sent.lightVersion == version then return end
        sent.lightVersion = version
    end
    if extra.plasticineLight then
        shader:send('lightDir',      unpack(lightDirBuf))
        shader:send('lightLocalPos', unpack(lightPosBuf))
    end
    shader:send('lightColor',     unpack(lightColorBuf))
    shader:send('lightIntensity', unpack(lightInBuf))
    shader:send('lightType',      unpack(lightTypeBuf))
    shader:send('lightRange',     unpack(lightRangeBuf))
    shader:send('lightGround',    unpack(lightGroundBuf))
end

-- Send all lighting+material uniforms shared by plasticine and hairs shaders.
local function sendSharedLighting(shader, body, extra)
    local useLit = (extra.plasticineUseLighting ~= false) and
                   (lib.plasticineUseLighting ~= false)
    send(shader, 'useLighting',   useLit and 1 or 0)
    send(shader, 'specPow',       extra.plasticineSpecPow      or lib.plasticineSpecPow)
    send(shader, 'specStrength',  extra.plasticineSpecStrength or lib.plasticineSpecStrength)
    send(shader, 'sssPow',        extra.plasticineSSSpow       or lib.plasticineSSSpow)
    send(shader, 'sssStrength',   extra.plasticineSSSstrength  or lib.plasticineSSSstrength)
    send(shader, 'terminatorPow', extra.plasticineTerminator   or lib.plasticineTerminator)
    send(shader, 'lightZ',        extra.plasticineLightZ       or lib.plasticineLightZ)
    send(shader, 'lightGain',     extra.plasticineLightGain    or lib.plasticineLightGain)
    send(shader, 'lightAdd',      extra.plasticineLightAdd and 1 or 0)
    send(shader, 'warmColor', hexColour(extra.plasticineWarmHex or lib.plasticineWarmHex))
    send(shader, 'coolColor', hexColour(extra.plasticineCoolHex or lib.plasticineCoolHex))
    sendLightsToShader(shader, body, extra)
end

local rimStyles = { off = 0, silhouette = 1, vignette = 2 }

-- Set the hairs or plasticine shader for a drawable with these settings (hairs win
-- when both are on) and send it everything it reads. Returns true when it set one.
-- One place for texfixtures, ribbons and trace vertices: three copies had drifted,
-- two never sent the hairs mottle, so it kept the last ribbon's value (BUG11).
local function setSurfaceShader(extra, body)
    -- the shadows' silhouettes need only the outlines (src/shadow-silhouettes.lua): no lighting there
    -- (it lit every part a second time, LIGHT-AND-SHADOW LS23)
    if state.drawingOutlines then return false end
    if extra.hairs then
        local sh = hairsShader
        love.graphics.setShader(sh)
        send(sh, 'strength',       extra.hairsStrength            or lib.hairsStrength)
        send(sh, 'density',        extra.hairsDensity             or lib.hairsDensity)
        send(sh, 'fuzz',           extra.hairsFuzz                or lib.hairsFuzz)
        send(sh, 'bush',           extra.hairsBush                or lib.hairsBush)
        send(sh, 'formRadius',     extra.plasticineFormRadius     or lib.plasticineFormRadius)
        send(sh, 'formStrength',   extra.plasticineFormStrength   or lib.plasticineFormStrength)
        send(sh, 'mottleStrength', extra.plasticineMottleStrength or lib.plasticineMottleStrength)
        send(sh, 'mottleScale',    extra.plasticineMottleScale    or lib.plasticineMottleScale)
        sendSharedLighting(sh, body, extra)
        return true
    end
    if extra.plasticine or extra.material then
        local sh = plasticineShader
        love.graphics.setShader(sh)
        -- a material instead of clay (src/render/materials.lua), and what's wet (src/wet.lua)
        local m = materials.uniforms(extra.material)
        send(sh, 'matKind', m and m.kind or 0)
        if m then
            send(sh, 'matSpec', m.spec)
            send(sh, 'matSurf', m.surf)
            send(sh, 'matTint', m.tint)
        end
        local wetCount, wetSpots = wet.shaderSpots(body)
        send(sh, 'wetCount', wetCount)
        if wetCount > 0 then sh:send('wetSpot', unpack(wetSpots)) end
        local formMap = extra.plasticineFormBaked and formBake.map(extra, extra.plasticineFormRise)
        if formMap then send(sh, 'formMap', formMap) end
        send(sh, 'useFormMap', formMap and 1 or 0)
        send(sh, 'strength',       extra.plasticineStrength       or lib.plasticineStrength)
        send(sh, 'scale',          extra.plasticineScale          or lib.plasticineScale)
        send(sh, 'edgeDark',       extra.plasticineEdge           or lib.plasticineEdge)
        send(sh, 'bumpAmp',        extra.plasticineBump           or lib.plasticineBump)
        send(sh, 'formStrength',   extra.plasticineFormStrength   or lib.plasticineFormStrength)
        send(sh, 'formRadius',     extra.plasticineFormRadius     or lib.plasticineFormRadius)
        send(sh, 'mottleStrength', extra.plasticineMottleStrength or lib.plasticineMottleStrength)
        send(sh, 'mottleScale',    extra.plasticineMottleScale    or lib.plasticineMottleScale)
        send(sh, 'useForm',        (extra.plasticineForm ~= false) and 1 or 0)
        send(sh, 'rimStyle',       rimStyles[extra.plasticineRimStyle or 'silhouette'])
        sendSharedLighting(sh, body, extra)
        return true
    end
    return false
end

-- The scene's lights, worked out once a frame (lib.newFrame, from main.lua's love.draw): each one that's
-- on, with its world direction, parsed colours, position and range. Each lit part then only turns
-- these into its own frame. Before, every part did it per light: the angle, cos and sin, two colour
-- strings parsed, the position (60% of setSurfaceShader with 20 lit Mipos on an iPhone SE 2,
-- LIGHT-AND-SHADOW LS23). The numbers sent are the same as before.
local frameLights = { stale = true, count = 0, skipped = false }
for i = 1, MAX_LIGHTS do
    frameLights[i] = { wdx = 0, wdy = 0, r = 1, g = 1, b = 1, intensity = 0, type = 0, gr = 0, gg = 0, gb = 0,
        x = 0, y = 0, range = 1 }
end

function lib.newFrame()
    frameLights.stale = true
    lib.frameCaching = true -- from here on the game says when a frame starts
end

local function refreshFrameLights(list)
    local count, skipped = 0, false
    -- the light sfixtures only, a list the registry keeps until an sfixture comes or goes (LS23)
    for _, f in ipairs(list) do
        if count >= MAX_LIGHTS then break end
        if not f:isDestroyed() then
            local ud = f:getUserData()
            -- a light that's off adds nothing, but the shader would still loop over it per pixel
            local off = ud and subtypes.is(ud, subtypes.LIGHT) and (ud.extra.intensity or 1.0) <= 0
            if off then skipped = true end
            if ud and subtypes.is(ud, subtypes.LIGHT) and not off then
                local lb = f:getBody()
                local la = lb:getAngle()
                count = count + 1
                local L = frameLights[count]
                -- the body's +X is the way the light shines (its panel: aim); the shader's lambert wants
                -- the way to the light, so the other way round (spec/light-aim_spec.lua)
                L.wdx, L.wdy = -math.cos(la), -math.sin(la)
                if ud.extra.lightType == 'sky' then L.wdx, L.wdy = 0, -1 end -- a sky: the world's up
                L.r, L.g, L.b = color.hexToColor(ud.extra.colorHex or 'ffffffff')
                L.intensity = ud.extra.intensity or 1.0
                L.type = LIGHT_TYPES[ud.extra.lightType] or 0
                L.gr, L.gg, L.gb = color.hexToColor(ud.extra.groundHex or '6b5a40ff')
                L.x, L.y = lb:getPosition()
                L.range = ud.extra.range or 500
                -- a back light has no falloff: its slot carries how far in its rim reaches (uv)
                if ud.extra.lightType == 'back' then L.range = ud.extra.rimWidth or 0.045 end
            end
        end
    end
    frameLights.count, frameLights.skipped, frameLights.stale = count, skipped, false
    frameLights.version = (frameLights.version or 0) + 1 -- the shaders send the lights' colours etc. again
    frameLights.list, frameLights.listLength = list, #list
end

-- Gather scene LIGHT sfixtures and rotate each world-space direction into the
-- target body's local UV frame. Returns count + (buffers reused every call).
-- Capped at MAX_LIGHTS; extras silently ignored.
function lib.gatherLightsForBody(body, fx, fy)
    fx = fx or 1; fy = fy or 1
    -- outside the game's frames (a spec) nothing calls newFrame: worked out each time; within one,
    -- again when a light comes or goes
    local list = registry.sfixturesOf(subtypes.LIGHT)
    if frameLights.stale or not lib.frameCaching or list ~= frameLights.list or #list ~= frameLights.listLength then
        refreshFrameLights(list)
    end
    local cosA, sinA, bx, by
    if body then
        local a = body:getAngle()
        cosA, sinA = math.cos(-a), math.sin(-a)
        bx, by = body:getPosition()
    else
        cosA, sinA = 1, 0  -- identity: no rotation (for CT ribbons)
        bx, by = 0, 0
    end
    local count = frameLights.count
    for i = 1, count do
        local L = frameLights[i]
        lightDirBuf[i][1] = (L.wdx * cosA - L.wdy * sinA) * fx
        lightDirBuf[i][2] = (L.wdx * sinA + L.wdy * cosA) * fy
        lightColorBuf[i][1], lightColorBuf[i][2], lightColorBuf[i][3] = L.r, L.g, L.b
        lightInBuf[i] = L.intensity
        lightTypeBuf[i] = L.type
        lightGroundBuf[i][1], lightGroundBuf[i][2], lightGroundBuf[i][3] = L.gr, L.gg, L.gb
        -- the light's position in the body's own frame (world for ribbons): the falloff of point and
        -- directional lights alike
        local dxw, dyw = L.x - bx, L.y - by
        lightPosBuf[i][1] = (dxw * cosA - dyw * sinA) * fx
        lightPosBuf[i][2] = (dxw * sinA + dyw * cosA) * fy
        lightRangeBuf[i] = L.range
    end
    -- every light off: one dark light, not none (no light at all means the shader's own default light,
    -- which would light up a scene whose lights were all turned off)
    if count == 0 and frameLights.skipped then
        count = 1
        lightInBuf[1], lightTypeBuf[1], lightRangeBuf[1] = 0, 0, 0
    end
    return count, lightDirBuf, lightColorBuf, lightInBuf, frameLights.version
end


lib.setSurfaceShader = setSurfaceShader

return lib

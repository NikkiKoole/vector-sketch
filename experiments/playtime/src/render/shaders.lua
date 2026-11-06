-- src/render/shaders.lua (split from physics/box2d-draw-textured.lua, SPLIT1)
local lib = {}
local registry = require('src.registry')
local subtypes = require('src.subtypes')
local color = require('src.color')
local formBake = require('src.render.form-bake')


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

        // --- Micro-normal from fBm (thumb-dents) ---
        vec2 p = uv * scale;
        float h  = fbm(p);
        float hx = fbm(p + vec2(0.5, 0.0));
        float hy = fbm(p + vec2(0.0, 0.5));
        vec2 microTilt = vec2(-(hx - h), -(hy - h)) * bumpAmp;

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
                        float rr = 0.045;
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

        base.rgb *= shade * pit * ao * tint;
        base.rgb += (totalSpec + totalSSS) * base.a;
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
                        float rr = 0.045;
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

-- Send light arrays to any shader that exposes the standard light uniforms.
-- Honors the legacy per-fixture `extra.plasticineLight` override.
local function sendLightsToShader(shader, body, extra)
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
        shader:send('lightCount', 1)
    else
        local fx = (extra.main and extra.main.fx) or 1
        local fy = (extra.main and extra.main.fy) or 1
        local count = lib.gatherLightsForBody(body, fx, fy)
        shader:send('lightCount', count)
    end
    shader:send('lightDir',       unpack(lightDirBuf))
    shader:send('lightColor',     unpack(lightColorBuf))
    shader:send('lightIntensity', unpack(lightInBuf))
    shader:send('lightType',      unpack(lightTypeBuf))
    shader:send('lightLocalPos',  unpack(lightPosBuf))
    shader:send('lightRange',     unpack(lightRangeBuf))
    shader:send('lightGround',    unpack(lightGroundBuf))
end

-- Send all lighting+material uniforms shared by plasticine and hairs shaders.
local function sendSharedLighting(shader, body, extra)
    local useLit = (extra.plasticineUseLighting ~= false) and
                   (lib.plasticineUseLighting ~= false)
    shader:send('useLighting',   useLit and 1 or 0)
    shader:send('specPow',       extra.plasticineSpecPow      or lib.plasticineSpecPow)
    shader:send('specStrength',  extra.plasticineSpecStrength or lib.plasticineSpecStrength)
    shader:send('sssPow',        extra.plasticineSSSpow       or lib.plasticineSSSpow)
    shader:send('sssStrength',   extra.plasticineSSSstrength  or lib.plasticineSSSstrength)
    shader:send('terminatorPow', extra.plasticineTerminator   or lib.plasticineTerminator)
    shader:send('lightZ',        extra.plasticineLightZ       or lib.plasticineLightZ)
    shader:send('lightGain',     extra.plasticineLightGain    or lib.plasticineLightGain)
    shader:send('lightAdd',      extra.plasticineLightAdd and 1 or 0)
    local wr, wg, wb = color.hexToColor(extra.plasticineWarmHex or lib.plasticineWarmHex)
    local cr, cg, cb = color.hexToColor(extra.plasticineCoolHex or lib.plasticineCoolHex)
    shader:send('warmColor', {wr, wg, wb})
    shader:send('coolColor', {cr, cg, cb})
    sendLightsToShader(shader, body, extra)
end

local rimStyles = { off = 0, silhouette = 1, vignette = 2 }

-- Set the hairs or plasticine shader for a drawable with these settings (hairs win
-- when both are on) and send it everything it reads. Returns true when it set one.
-- One place for texfixtures, ribbons and trace vertices: three copies had drifted,
-- two never sent the hairs mottle, so it kept the last ribbon's value (BUG11).
local function setSurfaceShader(extra, body)
    if extra.hairs then
        love.graphics.setShader(hairsShader)
        hairsShader:send('strength',       extra.hairsStrength            or lib.hairsStrength)
        hairsShader:send('density',        extra.hairsDensity             or lib.hairsDensity)
        hairsShader:send('fuzz',           extra.hairsFuzz                or lib.hairsFuzz)
        hairsShader:send('bush',           extra.hairsBush                or lib.hairsBush)
        hairsShader:send('formRadius',     extra.plasticineFormRadius     or lib.plasticineFormRadius)
        hairsShader:send('formStrength',   extra.plasticineFormStrength   or lib.plasticineFormStrength)
        hairsShader:send('mottleStrength', extra.plasticineMottleStrength or lib.plasticineMottleStrength)
        hairsShader:send('mottleScale',    extra.plasticineMottleScale    or lib.plasticineMottleScale)
        sendSharedLighting(hairsShader, body, extra)
        return true
    end
    if extra.plasticine then
        love.graphics.setShader(plasticineShader)
        local formMap = extra.plasticineFormBaked and formBake.map(extra, extra.plasticineFormRise)
        if formMap then plasticineShader:send('formMap', formMap) end
        plasticineShader:send('useFormMap', formMap and 1 or 0)
        plasticineShader:send('strength',       extra.plasticineStrength       or lib.plasticineStrength)
        plasticineShader:send('scale',          extra.plasticineScale          or lib.plasticineScale)
        plasticineShader:send('edgeDark',       extra.plasticineEdge           or lib.plasticineEdge)
        plasticineShader:send('bumpAmp',        extra.plasticineBump           or lib.plasticineBump)
        plasticineShader:send('formStrength',   extra.plasticineFormStrength   or lib.plasticineFormStrength)
        plasticineShader:send('formRadius',     extra.plasticineFormRadius     or lib.plasticineFormRadius)
        plasticineShader:send('mottleStrength', extra.plasticineMottleStrength or lib.plasticineMottleStrength)
        plasticineShader:send('mottleScale',    extra.plasticineMottleScale    or lib.plasticineMottleScale)
        plasticineShader:send('useForm',        (extra.plasticineForm ~= false) and 1 or 0)
        plasticineShader:send('rimStyle',       rimStyles[extra.plasticineRimStyle or 'silhouette'])
        sendSharedLighting(plasticineShader, body, extra)
        return true
    end
    return false
end

-- Gather scene LIGHT sfixtures and rotate each world-space direction into the
-- target body's local UV frame. Returns count + (buffers reused every call).
-- Capped at MAX_LIGHTS; extras silently ignored.
function lib.gatherLightsForBody(body, fx, fy)
    fx = fx or 1; fy = fy or 1
    local cosA, sinA, bx, by
    if body then
        local a = body:getAngle()
        cosA, sinA = math.cos(-a), math.sin(-a)
        bx, by = body:getPosition()
    else
        cosA, sinA = 1, 0  -- identity: no rotation (for CT ribbons)
        bx, by = 0, 0
    end
    local count = 0
    for _, f in pairs(registry.sfixtures) do
        if count >= MAX_LIGHTS then break end
        if not f:isDestroyed() then
            local ud = f:getUserData()
            if ud and subtypes.is(ud, subtypes.LIGHT) then
                local lb = f:getBody()
                local la = lb:getAngle()
                -- the body's +X is the way the light shines (its panel: aim); the shader's lambert wants
                -- the way to the light, so the other way round (spec/light-aim_spec.lua)
                local wdx, wdy = -math.cos(la), -math.sin(la)
                if ud.extra.lightType == 'sky' then wdx, wdy = 0, -1 end -- the way to a sky: the world's up
                local ldx = (wdx * cosA - wdy * sinA) * fx
                local ldy = (wdx * sinA + wdy * cosA) * fy
                count = count + 1
                lightDirBuf[count][1] = ldx
                lightDirBuf[count][2] = ldy
                local r, g, b = color.hexToColor(ud.extra.colorHex or 'ffffffff')
                lightColorBuf[count][1] = r
                lightColorBuf[count][2] = g
                lightColorBuf[count][3] = b
                lightInBuf[count]       = ud.extra.intensity or 1.0

                -- Light position in the target body's local space (or world space for CTs).
                -- Used for distance falloff by both point and directional lights.
                lightTypeBuf[count] = LIGHT_TYPES[ud.extra.lightType] or 0
                local gr, gg, gb = color.hexToColor(ud.extra.groundHex or '6b5a40ff')
                lightGroundBuf[count][1], lightGroundBuf[count][2], lightGroundBuf[count][3] = gr, gg, gb
                -- Both point and directional lights send their body-local position
                -- so the shader can compute distance-based attenuation for both.
                local lwx, lwy = lb:getPosition()
                local dxw, dyw = lwx - bx, lwy - by
                local lpx = (dxw * cosA - dyw * sinA) * fx
                local lpy = (dxw * sinA + dyw * cosA) * fy
                lightPosBuf[count][1] = lpx
                lightPosBuf[count][2] = lpy
                lightRangeBuf[count]  = ud.extra.range or 500
            end
        end
    end
    return count, lightDirBuf, lightColorBuf, lightInBuf
end


lib.setSurfaceShader = setSurfaceShader

return lib

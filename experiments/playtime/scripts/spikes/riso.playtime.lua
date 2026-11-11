-- riso: the textures we use (soil, plaster, planks, bark …) as a risograph print (two or three spot inks) or a
-- photocopy (black toner, a copy of a copy) a watercolour (washes, edges, granulation)
-- a woodcut / linocut (carved lines, wood grain, colour blocks), a misprinted CMYK (dithered plates off register),
-- gouache (flat opaque poster paint) or cut paper (an Eric Carle kind of collage); for all: boil, paper on the world
-- (docs/RISO.md; Nikki 2026-11-11: "a riso-print shader, im wondering what that would do with some of the cc0
-- textures we use now, for soil etc, i hope it might end up looking more handmade").
-- Each colour is split into ink densities (the inks multiply on the paper, so in log space a colour is a sum
-- of inks: solved by least squares for the chosen inks), each ink screened on its own (grain: riso's
-- stochastic dots; or round dots at its own angle), each plate printed a little off (misregistration),
-- the ink a little uneven, on a paper with tooth. Views: 'textures' (a sheet of them) and 'scene' (the whole
-- world through it, Mipo and all). Hold space: the original. Keys: space, v view, h panel.
local s = {}

local GROUND_Y = 600

-- risograph inks (the drum colours as printers list them)
local INKS = {
    { 'black', '2b2b2e' }, { 'federal blue', '3d5588' }, { 'medium blue', '3255a4' }, { 'blue', '0078bf' },
    { 'aqua', '5ec8e5' }, { 'teal', '00838a' }, { 'green', '00a95c' }, { 'hunter green', '407060' },
    { 'yellow', 'ffe800' }, { 'orange', 'ff6c2f' }, { 'bright red', 'f15060' }, { 'fl. pink', 'ff48b0' },
    { 'burgundy', '914e72' }, { 'brown', '925f52' }, { 'mint', '82d8d5' }, { 'light grey', '88898a' },
}
local SETS = { -- a few pairings to start from
    { 'brown', 'hunter green', 'yellow' }, { 'medium blue', 'fl. pink' }, { 'federal blue', 'orange' },
    { 'black', 'yellow' }, { 'teal', 'bright red', 'yellow' }, { 'burgundy', 'aqua' },
}
local PAPERS = { { 'cream', 'f3ecda' }, { 'white', 'fbfaf6' }, { 'kraft', 'd9c4a0' } }

local TEXTURES = { 'ground/soil-01.jpg', 'ground/earth-01.jpg', 'ground/moss-01.jpg', 'ground/grass-01.jpg',
    'walls/plaster-02.jpg', 'walls/planks-01.jpg', 'walls/concrete-01.jpg', 'bark/bark-01.jpg' }

local function hex(h)
    return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 }
end
local function inkNamed(name)
    for i, ink in ipairs(INKS) do if ink[1] == name then return i end end
end

local function st()
    if not state.riso then
        state.riso = { showPanel = true, view = 'textures', inks = { inkNamed('brown'), inkNamed('hunter green'),
            inkNamed('yellow') }, paper = 1, mode = 'grain', dot = 2, offset = 2.5, grain = 0.6, density = 0.7,
            contrast = 1.3 }
    end
    return state.riso
end

local SHADER = [[
uniform vec3 inks[3];
uniform float nInks;
uniform mat3 unmix;       // log-absorption (per channel) -> density per ink (rows)
uniform vec2 offsets[3];  // each plate off by this many screen px
uniform vec2 texel;
uniform vec2 origin; // where the world's 0,0 is on the screen: the paper moves with the world
uniform vec2 boil;   // a jump every 1/fps s: redrawn, as hand-made animation is
uniform vec3 paper;
uniform float dotSize;
uniform float mode;       // 0 grain, 1 dots
uniform float grain;
uniform float density;
uniform float contrast;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
vec3 densities(Image tex, vec2 uv) {
    vec3 c = Texel(tex, uv).rgb;
    c = clamp((c - 0.5) * contrast + 0.5, 0.004, 1.0);
    vec3 a = max(-log(c / paper), 0.0);
    return clamp(unmix * a * density, 0.0, 1.0); // ink: how much of the colour each plate carries
}
float coverage(float d, vec2 sc, float k) {
    if (mode < 0.5) { // riso grain: a threshold per dot cell, the cells clumping a little
        vec2 cell = floor(sc / dotSize);
        float t = 0.65 * hash(cell + k * 31.7) + 0.35 * vnoise(sc / (dotSize * 3.0) + k * 7.1);
        return smoothstep(t - 0.04, t + 0.04, d);
    }
    float an = 0.26 + k * 0.52; // 15, 45, 75 degrees
    vec2 p = mat2(cos(an), -sin(an), sin(an), cos(an)) * sc / (dotSize * 2.5);
    float r = length(fract(p) - 0.5);
    float rad = sqrt(d / 3.14159);
    return 1.0 - smoothstep(rad - 0.06, rad + 0.06, r);
}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    sc = sc - origin + boil;
    float alpha = Texel(tex, uv).a;
    vec3 outc = paper * (1.0 - grain * 0.07 * vnoise(sc * 0.7)) * (1.0 - grain * 0.04 * vnoise(sc / 9.0));
    for (int k = 0; k < 3; k++) {
        if (float(k) >= nInks) break;
        vec3 d3 = densities(tex, uv + offsets[k] * texel);
        float d = (k == 0 ? d3.x : (k == 1 ? d3.y : d3.z));
        d *= 1.0 - grain * 0.3 * vnoise(sc / 45.0 + float(k) * 17.0); // the ink a little uneven on the drum
        float cov = coverage(d, sc, float(k));
        outc *= mix(vec3(1.0), inks[k], cov);
    }
    return vec4(outc, alpha) * color;
}
]]
local shader

-- the inks' unmixing: absorption a (per channel, -log(colour / paper)) = sum of density_k * A_k, A_k the ink's
-- own absorption; least squares (A^T A)^-1 A^T for 1..3 inks, as rows of a 3x3 (unused rows zero)
local function inv3(m)
    local a, b, c = m[1][1], m[1][2], m[1][3]
    local d, e, f = m[2][1], m[2][2], m[2][3]
    local g, h, i = m[3][1], m[3][2], m[3][3]
    local det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
    if math.abs(det) < 1e-9 then return nil end
    return { { (e * i - f * h) / det, (c * h - b * i) / det, (b * f - c * e) / det },
        { (f * g - d * i) / det, (a * i - c * g) / det, (c * d - a * f) / det },
        { (d * h - e * g) / det, (b * g - a * h) / det, (a * e - b * d) / det } }
end
local function unmixFor(inkColours, paper)
    local n = #inkColours
    local A = {} -- A[k] = absorption vector of ink k
    for k, col in ipairs(inkColours) do
        A[k] = {}
        for ch = 1, 3 do A[k][ch] = math.max(0.001, -math.log(math.max(0.004, col[ch]) / paper[ch])) end
    end
    local G = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } } -- A^T A (n x n), padded with identity
    for r = 1, n do
        for c = 1, n do
            local sum = 0
            for ch = 1, 3 do sum = sum + A[r][ch] * A[c][ch] end
            G[r][c] = sum
        end
    end
    local Gi = inv3(G) or { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
    local rows = { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }
    for r = 1, n do
        for ch = 1, 3 do
            local sum = 0
            for c = 1, n do sum = sum + Gi[r][c] * A[c][ch] end
            rows[r][ch] = sum
        end
    end
    return rows
end

-- ── for every process: boil and the paper moving with the world ──
-- boil (fps, 0 off): the grain, dots, strokes and paper drawn anew a few times a second, as hand-made
-- animation is (on twos: 12); the paper with the world: in 'scene' the patterns sit on the world, not on the
-- screen (else they stay still while the world moves under them: a filter on glass). Not the photocopy:
-- its dust and streaks are on the copier's glass.
local function common(sh)
    local c = st()
    local ox, oy = 0, 0
    if c.view == 'scene' and c.process ~= 'photocopy' and c.anchor ~= false then
        ox, oy = cam:getScreenCoordinates(0, 0)
    end
    local bx, by = 0, 0
    local fps = c.boil or 0
    if fps > 0 then
        local n = math.floor(love.timer.getTime() * fps)
        bx, by = (n * 37.17) % 1000, (n * 91.73) % 1000
    end
    if sh:hasUniform('origin') then sh:send('origin', { ox, oy }) end
    if sh:hasUniform('boil') then sh:send('boil', { bx, by }) end
end

local function applyRiso(texelW, texelH)
    local c = st()
    shader = shader or love.graphics.newShader(SHADER)
    local paper = hex(PAPERS[c.paper][2])
    local colours = {}
    for _, i in ipairs(c.inks) do if i then colours[#colours + 1] = hex(INKS[i][2]) end end
    while #colours < 1 do colours[1] = hex('2b2b2e') end
    local padded = { colours[1], colours[2] or { 1, 1, 1 }, colours[3] or { 1, 1, 1 } }
    shader:send('inks', padded[1], padded[2], padded[3])
    shader:send('nInks', #colours)
    shader:send('unmix', 'row', unmixFor(colours, paper))
    local o = c.offset
    shader:send('offsets', { 0, 0 }, { o, -o * 0.6 }, { -o * 0.7, o * 0.8 })
    shader:send('texel', { texelW, texelH })
    shader:send('paper', paper)
    shader:send('dotSize', c.dot)
    shader:send('mode', c.mode == 'dots' and 1 or 0)
    shader:send('grain', c.grain)
    shader:send('density', c.density)
    shader:send('contrast', c.contrast)
    common(shader)
    love.graphics.setShader(shader)
end

-- ── photocopy (Nikki 2026-11-11: "can we do a photocopier one next?") ──
-- Black toner on copy paper. A copier keeps the darks and the lights and loses the greys between, so the
-- picture goes through a steep curve and the greys break up into grit (the threshold jitters per pixel);
-- 'copies': a copy of a copy, each one blurrier (the lens), steeper and darker. The toner patchy over the
-- page, streaks down it from the drum, dust on the glass and pinholes in solid black. The specks and streaks
-- sit still on the screen, as on the copier's glass.
local COPY_PAPERS = { { 'white', 'fbfbf8' }, { 'recycled', 'e6e3d8' }, { 'pink', 'f7c9d4' }, { 'yellow', 'f9eba0' },
    { 'blue', 'c9dcf0' } }
local TONERS = { { 'black', '151515' }, { 'blue', '23305f' }, { 'sepia', '4a3427' } }
local COPY_SHADER = [[
uniform vec2 texel;
uniform vec2 origin; // where the world's 0,0 is on the screen: the paper moves with the world
uniform vec2 boil;   // a jump every 1/fps s: redrawn, as hand-made animation is
uniform vec3 paper;
uniform vec3 toner;
uniform float darkness;
uniform float contrast;
uniform float copies;
uniform float grit;
uniform float speckle;
uniform float streaks;
uniform float detail;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
float lum(Image tex, vec2 uv) { return dot(Texel(tex, uv).rgb, vec3(0.299, 0.587, 0.114)); }
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    sc = sc - origin + boil;
    float alpha = Texel(tex, uv).a;
    float r = 0.6 + copies * 0.7; // each copy a little blurrier
    float l = lum(tex, uv) * 0.4 + (lum(tex, uv + vec2(r, 0.0) * texel) + lum(tex, uv - vec2(r, 0.0) * texel)
        + lum(tex, uv + vec2(0.0, r) * texel) + lum(tex, uv - vec2(0.0, r) * texel)) * 0.15;
    // detail: dark against its surroundings (a wide blur), so a dark photo keeps its clods and grain
    // instead of going solid black (0: the plain picture, as a real copier takes it)
    float R = 14.0;
    float around = 0.0;
    for (int i = 0; i < 8; i++) {
        float a = float(i) * 0.785;
        around += lum(tex, uv + vec2(cos(a), sin(a)) * R * texel);
    }
    around /= 8.0;
    // (the tone softened toward the middle, the edges added on top: white stays white, a dark photo goes grey
    // with its edges dark)
    float tone = (1.0 - l) * (1.0 - detail * 0.55) + (around - l) * 3.0 * detail;
    float k = contrast * (1.0 + copies * 0.45); // and steeper: the greys go
    float dark = (tone - (1.0 - darkness)) * k + 0.5;
    dark += (vnoise(sc / 70.0) - 0.5) * 0.25 * (0.6 + copies * 0.25); // the toner patchy
    float streak = step(0.985, hash(vec2(floor(sc.x / 1.5), 3.7))) * 0.6 + (vnoise(vec2(sc.x / 6.0, 1.3)) - 0.5) * 0.3;
    dark += streak * streaks; // down the page, from the drum
    float t = 0.5 + (hash(floor(sc)) - 0.5) * grit * 0.8 + (vnoise(sc / 2.5) - 0.5) * grit * 0.4;
    float cov = smoothstep(t - 0.08, t + 0.08, dark);
    float speck = step(1.0 - 0.004 * speckle * (1.0 + copies), hash(floor(sc / 2.0) + 5.1)); // dust on the glass
    float hole = step(1.0 - 0.012 * speckle, hash(floor(sc) + 91.3));                     // pinholes
    cov = max(cov, speck) * (1.0 - hole * 0.8);
    vec3 outc = mix(paper * (1.0 - 0.03 * vnoise(sc * 0.5)), toner, cov * 0.94);
    return vec4(outc, alpha) * color;
}
]]
local copyShader
local function copySettings()
    local c = st()
    c.copy = c.copy or { paper = 1, toner = 1, darkness = 0.5, contrast = 1.6, copies = 1, grit = 0.5,
        speckle = 0.5, streaks = 0.4, detail = 0.7 }
    c.copy.detail = c.copy.detail or 0.7
    return c.copy
end
local function applyCopy(texelW, texelH)
    local k = copySettings()
    copyShader = copyShader or love.graphics.newShader(COPY_SHADER)
    copyShader:send('texel', { texelW, texelH })
    copyShader:send('paper', hex(COPY_PAPERS[k.paper][2]))
    copyShader:send('toner', hex(TONERS[k.toner][2]))
    for _, name in ipairs({ 'darkness', 'contrast', 'copies', 'grit', 'speckle', 'streaks', 'detail' }) do
        copyShader:send(name, k[name])
    end
    common(copyShader)
    love.graphics.setShader(copyShader)
end

-- ── watercolour (Nikki 2026-11-11: "can we do a watercolor one?") ──
-- After Bousseau et al. 2006 (interactive watercolor rendering) and Curtis 1997: the picture simplified
-- into washes ('soften'), their edges wandering like a hand ('wobble'), here and there wet-in-wet, a colour
-- running into the next ('bleed'); pigment darker where a wash ends ('edges'), uneven over a wash
-- ('pigment'), settled in the paper's dips ('granulation'); transparent, so lighter ('water') and laid
-- over the paper (multiplied). Density changes colour as pigment does: C' = C - (C - C^2)(d - 1).
local WATER_PAPERS = { { 'white', 'f8f5ee' }, { 'cream', 'f1e8d4' }, { 'toned', 'e6dcc6' } }
local WATER_SHADER = [[
uniform vec2 texel;
uniform vec2 origin; // where the world's 0,0 is on the screen: the paper moves with the world
uniform vec2 boil;   // a jump every 1/fps s: redrawn, as hand-made animation is
uniform vec3 paper;
uniform float wobble;
uniform float soften;
uniform float bleed;
uniform float edges;
uniform float pigment;
uniform float granulation;
uniform float water;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { v += a * vnoise(p); p = p * 2.03 + 11.7; a *= 0.5; }
    return v / 0.9375;
}
vec3 soft(Image tex, vec2 uv, float r) { // a disc of 8 around the centre, r screen px
    vec3 sum = Texel(tex, uv).rgb;
    for (int i = 0; i < 8; i++) {
        float a = float(i) * 0.785 + 0.39;
        sum += Texel(tex, uv + vec2(cos(a), sin(a)) * r * texel).rgb;
    }
    return sum / 9.0;
}
vec3 density(vec3 c, float d) { return clamp(c - (c - c * c) * (d - 1.0), 0.0, 1.0); }
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    sc = sc - origin + boil;
    vec2 w = vec2(fbm(sc / 55.0), fbm(sc / 55.0 + 17.3)) - 0.5; // the hand: wash edges wander
    vec2 uv2 = uv + w * wobble * 14.0 * texel;
    float alpha = Texel(tex, uv2).a;
    vec3 c = soft(tex, uv2, soften);
    vec3 wide = soft(tex, uv2, soften * 2.5 + 5.0);
    float wet = smoothstep(0.45, 0.75, fbm(sc / 140.0 + 3.1)); // wet-in-wet here and there
    c = mix(c, wide, wet * bleed);
    c = mix(c, vec3(1.0), water * 0.4); // transparent: lighter
    float e = clamp(length(soft(tex, uv2, soften + 1.0) - wide) * 3.0, 0.0, 1.0); // where a wash ends
    float tooth = fbm(sc / 2.6);
    float d = 1.0 + (fbm(sc / 80.0 + 9.0) - 0.5) * pigment * 1.6 + (tooth - 0.5) * granulation * 1.4 + e * edges;
    vec3 outc = density(c, d) * paper * (1.0 - (tooth - 0.5) * 0.07);
    return vec4(outc, alpha) * color;
}
]]
local waterShader
local function waterSettings()
    local c = st()
    c.water = c.water or { paper = 1, wobble = 0.8, soften = 2.5, bleed = 0.5, edges = 1.2, pigment = 0.7,
        granulation = 0.6, water = 0.4 }
    return c.water
end
local function applyWater(texelW, texelH)
    local k = waterSettings()
    waterShader = waterShader or love.graphics.newShader(WATER_SHADER)
    waterShader:send('texel', { texelW, texelH })
    waterShader:send('paper', hex(WATER_PAPERS[k.paper][2]))
    for _, name in ipairs({ 'wobble', 'soften', 'bleed', 'edges', 'pigment', 'granulation', 'water' }) do
        waterShader:send(name, k[name])
    end
    common(waterShader)
    love.graphics.setShader(waterShader)
end

-- ── woodcut / linocut (Nikki 2026-11-11: "can we now do a woodblock / gutsen one?") ──
-- The key block: the tone as carved lines, each as wide as the tone is dark (solid ink where it's very dark,
-- carved away to bare paper where it's light), the lines bending with the picture ('bend': a wide blur of
-- it pushes them, as an engraver's lines follow a form) and wandering a little, broken along their length
-- like gouge cuts ('chips'); the edges left standing ('outline'). Wood grain and the baren's uneven rub in
-- the ink ('grain'). Under it, if wanted, colour blocks: the picture's colours flattened to a few levels
-- ('levels'), printed a little off ('offset'), as in a Japanese woodblock print ('colour').
local WOOD_PAPERS = { { 'washi', 'f2ead6' }, { 'white', 'faf8f2' }, { 'kraft', 'd9c4a0' } }
local WOOD_INKS = { { 'black', '1b1a1a' }, { 'indigo', '2b3a67' }, { 'red', 'a8362a' }, { 'brown', '4a3020' } }
local WOOD_SHADER = [[
uniform vec2 texel;
uniform vec2 origin; // where the world's 0,0 is on the screen: the paper moves with the world
uniform vec2 boil;   // a jump every 1/fps s: redrawn, as hand-made animation is
uniform vec3 paper;
uniform vec3 ink;
uniform float spacing;
uniform float angle;
uniform float bend;
uniform float chips;
uniform float grain;
uniform float darkness;
uniform float outline;
uniform float colour;
uniform float levels;
uniform float offset;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { v += a * vnoise(p); p = p * 2.03 + 11.7; a *= 0.5; }
    return v / 0.9375;
}
float lum(Image tex, vec2 uv) { return dot(Texel(tex, uv).rgb, vec3(0.299, 0.587, 0.114)); }
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    sc = sc - origin + boil;
    float alpha = Texel(tex, uv).a;
    // the tone, a little smoothed (a block can't carve every pixel)
    float r = 1.5;
    float L = (lum(tex, uv) * 2.0 + lum(tex, uv + vec2(r, 0.0) * texel) + lum(tex, uv - vec2(r, 0.0) * texel)
        + lum(tex, uv + vec2(0.0, r) * texel) + lum(tex, uv - vec2(0.0, r) * texel)) / 6.0;
    float wide = 0.0;
    for (int i = 0; i < 8; i++) {
        float a = float(i) * 0.785;
        wide += lum(tex, uv + vec2(cos(a), sin(a)) * 12.0 * texel);
    }
    wide /= 8.0;
    float g = 2.5;
    float gx = lum(tex, uv + vec2(g, 0.0) * texel) - lum(tex, uv - vec2(g, 0.0) * texel);
    float gy = lum(tex, uv + vec2(0.0, g) * texel) - lum(tex, uv - vec2(0.0, g) * texel);
    float edge = length(vec2(gx, gy));
    // the cut lines: across them from the base angle, pushed by the picture and wandering
    vec2 dir = vec2(cos(angle), sin(angle));
    vec2 nrm = vec2(-dir.y, dir.x);
    float across = dot(sc, nrm) / spacing + (wide - 0.5) * bend + (fbm(sc / 260.0) - 0.5) * 2.0;
    float along = dot(sc, dir) / spacing;
    float t = clamp(((1.0 - L) - (1.0 - darkness)) * 1.8 + 0.5, 0.0, 1.0);
    float chip = (vnoise(vec2(along * 0.35, floor(across) * 3.1)) - 0.5) * chips * t * (1.0 - t) * 4.0; // mid tones
    float stripe = abs(fract(across) - 0.5) * 2.0;
    float key = 1.0 - smoothstep(t + chip - 0.08, t + chip + 0.08, stripe);
    key = max(key, smoothstep(0.86, 0.96, t + chip * 0.3));   // solid where very dark
    key *= smoothstep(0.04, 0.14, t);                           // carved away where light
    key = max(key, smoothstep(0.1, 0.25, edge * outline));     // the edges left standing
    // wood grain and the baren's rub in the ink
    float wood = fbm(vec2(sc.x / 240.0, sc.y / 4.0) + fbm(sc / 90.0) * 2.0);
    float rub = vnoise(sc * 0.9);
    key *= (1.0 - grain * 0.35 * wood) * (1.0 - grain * 0.3 * step(0.82, rub));
    // the colour blocks under it: the picture's colours flattened, a little off register
    vec3 cc = Texel(tex, uv + vec2(offset, -offset * 0.7) * texel).rgb;
    vec3 flatc = floor(cc * levels + 0.5) / levels;
    flatc = mix(vec3(1.0), flatc, 1.0 - grain * 0.3 * wood);
    vec3 base = paper * mix(vec3(1.0), flatc, colour);
    return vec4(mix(base, ink, key), alpha) * color;
}
]]
local woodShader
local function woodSettings()
    local c = st()
    c.wood = c.wood or { paper = 1, ink = 1, spacing = 5, angle = 0.35, bend = 4, chips = 0.5, grain = 0.6,
        darkness = 0.38, outline = 1.5, colour = 0, levels = 3, offset = 2 }
    return c.wood
end
local function applyWood(texelW, texelH)
    local k = woodSettings()
    woodShader = woodShader or love.graphics.newShader(WOOD_SHADER)
    woodShader:send('texel', { texelW, texelH })
    woodShader:send('paper', hex(WOOD_PAPERS[k.paper][2]))
    woodShader:send('ink', hex(WOOD_INKS[k.ink][2]))
    for _, name in ipairs({ 'spacing', 'angle', 'bend', 'chips', 'grain', 'darkness', 'outline', 'colour',
        'levels', 'offset' }) do
        woodShader:send(name, k[name])
    end
    common(woodShader)
    love.graphics.setShader(woodShader)
end

-- ── CMYK misprint (Nikki 2026-11-11: "can you do a dither misprint cmyk one") ──
-- The picture split into cyan, magenta, yellow and black plates (black taken from under the colours:
-- 'black'), each plate screened on its own: ordered dither (Bayer 8x8, each plate's matrix shifted so they
-- don't line up), noise dither, or round halftone dots at the printers' angles (C 15, M 75, Y 0, K 45);
-- 'pixel' the dither's cell. Misprinted: the plates out of register ('misregister', px), slipping a little
-- across the sheet ('slip'), a faint second hit of each ('ghost'), ink running out in bands along the
-- print direction ('starve'), dots spreading into the paper ('dot gain').
local CMYK_PAPERS = { { 'newsprint', 'e9e4d6' }, { 'white', 'faf9f5' }, { 'kraft', 'd9c4a0' } }
local CMYK_SHADER = [[
uniform vec2 texel;
uniform vec2 origin; // where the world's 0,0 is on the screen: the paper moves with the world
uniform vec2 boil;   // a jump every 1/fps s: redrawn, as hand-made animation is
uniform vec3 paper;
uniform float mode;
uniform float pixel;
uniform float misreg;
uniform float slip;
uniform float ghost;
uniform float starve;
uniform float gain;
uniform float blackgen;
uniform float contrast;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
float bayer2(vec2 a) { a = floor(a); return fract(dot(a, vec2(0.5, a.y * 0.75))); }
float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }
float bayer8(vec2 a) { return bayer4(0.5 * a) * 0.25 + bayer2(a); }
vec4 cmykAt(Image tex, vec2 uv) {
    vec3 c = clamp((Texel(tex, uv).rgb - 0.5) * contrast + 0.5, 0.0, 1.0);
    float k = (1.0 - max(c.r, max(c.g, c.b))) * blackgen;
    vec3 cmy = (1.0 - c - k) / max(1.0 - k, 0.001);
    return clamp(vec4(cmy, k), 0.0, 1.0);
}
float screen(float d, vec2 sc, float k) {
    d = clamp(d + gain * d * (1.0 - d) * 1.5, 0.0, 1.0); // dot gain: the middle tones spread most
    vec2 cell = floor(sc / pixel);
    if (mode < 0.5) return step(bayer8(cell + vec2(k * 3.0, k * 5.0)) + 0.001, d);
    if (mode < 1.5) return step(hash(cell + k * 17.3) + 0.001, d);
    float an = (k == 0.0 ? 0.26 : (k == 1.0 ? 1.31 : (k == 2.0 ? 0.0 : 0.785)));
    vec2 p = mat2(cos(an), -sin(an), sin(an), cos(an)) * sc / (pixel * 2.5);
    float r = length(fract(p) - 0.5);
    float rad = sqrt(d / 3.14159);
    return 1.0 - smoothstep(rad - 0.06, rad + 0.06, r);
}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    sc = sc - origin + boil;
    float alpha = Texel(tex, uv).a;
    vec3 inks[4];
    inks[0] = vec3(0.0, 0.68, 0.94);  // cyan
    inks[1] = vec3(0.93, 0.0, 0.55);  // magenta
    inks[2] = vec3(1.0, 0.95, 0.0);   // yellow
    inks[3] = vec3(0.14, 0.12, 0.13); // black
    vec2 dirs[4];
    dirs[0] = vec2(1.0, 0.4); dirs[1] = vec2(-0.6, 1.0); dirs[2] = vec2(0.3, -1.0); dirs[3] = vec2(-0.15, -0.2);
    vec3 outc = paper * (1.0 - 0.04 * vnoise(sc * 0.6));
    for (int i = 0; i < 4; i++) {
        float k = float(i);
        // each plate off by its own amount, slipping a little across the sheet
        vec2 off = dirs[i] * misreg + (vec2(vnoise(sc / 300.0 + k * 7.0), vnoise(sc / 300.0 + k * 13.0)) - 0.5) * slip * 12.0;
        vec4 d4 = cmykAt(tex, uv + off * texel);
        float d = (i == 0 ? d4.x : (i == 1 ? d4.y : (i == 2 ? d4.z : d4.w)));
        // ink running out in bands along the print direction
        d *= 1.0 - starve * 0.6 * smoothstep(0.55, 0.85, vnoise(vec2(sc.y / 35.0, k * 9.0 + sc.x / 900.0)));
        float cov = screen(d, sc, k);
        // a ghost: a faint second hit, further off
        vec4 g4 = cmykAt(tex, uv + (off + dirs[i] * 9.0) * texel);
        float gd = (i == 0 ? g4.x : (i == 1 ? g4.y : (i == 2 ? g4.z : g4.w)));
        cov = max(cov, screen(gd, sc + 0.5, k + 4.0) * ghost * 0.35);
        outc *= mix(vec3(1.0), inks[i], cov);
    }
    return vec4(outc, alpha) * color;
}
]]
local cmykShader
local function cmykSettings()
    local c = st()
    c.cmyk = c.cmyk or { paper = 1, mode = 1, pixel = 2, misreg = 4, slip = 0.5, ghost = 0.3, starve = 0.4,
        gain = 0.2, blackgen = 0.8, contrast = 1.1 }
    return c.cmyk
end
local CMYK_MODES = { 'bayer', 'noise', 'dots' }
local function applyCmyk(texelW, texelH)
    local k = cmykSettings()
    cmykShader = cmykShader or love.graphics.newShader(CMYK_SHADER)
    cmykShader:send('texel', { texelW, texelH })
    cmykShader:send('paper', hex(CMYK_PAPERS[k.paper][2]))
    cmykShader:send('mode', k.mode - 1)
    for _, name in ipairs({ 'pixel', 'misreg', 'slip', 'ghost', 'starve', 'gain', 'blackgen', 'contrast' }) do
        cmykShader:send(name, k[name])
    end
    common(cmykShader)
    love.graphics.setShader(cmykShader)
end

-- ── gouache (Nikki 2026-11-11: "y", after: gouache for the Childcraft look) ──
-- Opaque, flat, matte poster paint as in 70s picture books: the picture painted in calm patches (a
-- Kuwahara filter: of the four quarters around a point, the one that varies least gives its colour;
-- 'patches' its size), flattened toward a few values ('flat'), chalky (the white in gouache: 'chalk'),
-- brush strokes along a slowly turning direction ('brush'), the paper showing through thin dry strokes
-- ('dry'), the edges a little wobbly ('wobble'). No darker edges: it's opaque.
local GOUACHE_PAPERS = { { 'white', 'f7f4ec' }, { 'cream', 'efe5cf' }, { 'grey', 'd8d3c8' } }
local GOUACHE_SHADER = [[
uniform vec2 texel;
uniform vec2 origin;
uniform vec2 boil;
uniform vec3 paper;
uniform float radius;
uniform float flatness;
uniform float chalk;
uniform float brush;
uniform float dry;
uniform float wobble;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { v += a * vnoise(p); p = p * 2.03 + 11.7; a *= 0.5; }
    return v / 0.9375;
}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    sc = sc - origin + boil;
    vec2 w = vec2(fbm(sc / 70.0), fbm(sc / 70.0 + 5.2)) - 0.5;
    vec2 uv2 = uv + w * wobble * 10.0 * texel;
    float alpha = Texel(tex, uv2).a;
    vec3 best = Texel(tex, uv2).rgb;
    float bestVar = 1e9;
    for (int q = 0; q < 4; q++) {
        vec2 dir = vec2((q == 0 || q == 3) ? -1.0 : 1.0, (q < 2) ? -1.0 : 1.0);
        vec3 m = vec3(0.0), m2 = vec3(0.0);
        for (int i = 0; i < 3; i++) {
            for (int j = 0; j < 3; j++) {
                vec3 cs = Texel(tex, uv2 + dir * vec2(float(i), float(j)) * radius * 0.5 * texel).rgb;
                m += cs;
                m2 += cs * cs;
            }
        }
        m /= 9.0;
        vec3 v3 = m2 / 9.0 - m * m;
        float v = v3.r + v3.g + v3.b;
        if (v < bestVar) { bestVar = v; best = m; }
    }
    vec3 c = best;
    float lv = mix(24.0, 5.0, flatness);
    c = mix(c, floor(c * lv + 0.5) / lv, flatness);
    float l = dot(c, vec3(0.299, 0.587, 0.114));
    c = mix(c, vec3(l), chalk * 0.25);
    c = mix(c, vec3(1.0), chalk * 0.12);
    // brush strokes: one direction per patch of the sheet (a direction turning smoothly over the whole
    // screen bent them into marbling); bare paper stays bare
    float painted = 1.0 - smoothstep(0.86, 0.97, l);
    vec2 cell = floor((sc + (vec2(vnoise(sc / 40.0), vnoise(sc / 40.0 + 3.0)) - 0.5) * 30.0) / 70.0);
    float a = hash(cell) * 3.14;
    vec2 d = vec2(cos(a), sin(a));
    vec2 p = vec2(dot(sc, d) / 18.0, dot(sc, vec2(-d.y, d.x)) / 2.2);
    c *= 1.0 + (vnoise(p) - 0.5) * brush * 0.2 * painted;
    float thin = smoothstep(0.75, 0.95, vnoise(p * vec2(0.5, 1.0) + 7.0)) * dry * painted;
    c = mix(c, paper, thin * 0.7);
    c = mix(paper, c, max(painted, 0.0) * 0.85 + 0.15);
    c *= 1.0 - (fbm(sc / 2.5) - 0.5) * 0.05;
    return vec4(c, alpha) * color;
}
]]
local gouacheShader
local function gouacheSettings()
    local c = st()
    c.gouache = c.gouache or { paper = 1, radius = 6, flatness = 0.5, chalk = 0.5, brush = 0.7, dry = 0.4,
        wobble = 0.5 }
    return c.gouache
end
local function applyGouache(texelW, texelH)
    local k = gouacheSettings()
    gouacheShader = gouacheShader or love.graphics.newShader(GOUACHE_SHADER)
    gouacheShader:send('texel', { texelW, texelH })
    gouacheShader:send('paper', hex(GOUACHE_PAPERS[k.paper][2]))
    for _, name in ipairs({ 'radius', 'flatness', 'chalk', 'brush', 'dry', 'wobble' }) do
        gouacheShader:send(name, k[name])
    end
    common(gouacheShader)
    love.graphics.setShader(gouacheShader)
end

-- ── cut paper (the Eric Carle kind of collage) ──
-- The picture cut into a few flat shapes (its colours, softened, flattened to 'colours' levels), each
-- cut from a sheet of painted paper: strokes at the sheet's own angle and dabs of its colour, a little of
-- other colours in it ('paint'). The cut wanders and tears ('tear'), a torn edge shows a thin white
-- fringe ('fringe'), and a lighter piece lies on top of a darker one, casting a small shadow on it
-- ('shadow'). 'soften' how much detail is cut away.
local CUT_PAPERS = { { 'white', 'f7f4ec' }, { 'cream', 'efe5cf' }, { 'board', 'c9b48f' } }
local CUT_SHADER = [[
uniform vec2 texel;
uniform vec2 origin;
uniform vec2 boil;
uniform vec3 paper;
uniform float levels;
uniform float soften;
uniform float tear;
uniform float fringe;
uniform float shadow;
uniform float paint;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { v += a * vnoise(p); p = p * 2.03 + 11.7; a *= 0.5; }
    return v / 0.9375;
}
vec3 region(Image tex, vec2 uv) { // two rings of 6 around the point: busy photo textures cut into confetti
    vec3 c = Texel(tex, uv).rgb;
    for (int i = 0; i < 6; i++) {
        float a = float(i) * 1.047;
        c += Texel(tex, uv + vec2(cos(a), sin(a)) * soften * texel).rgb;
        c += Texel(tex, uv + vec2(cos(a + 0.52), sin(a + 0.52)) * soften * 0.5 * texel).rgb;
    }
    c /= 13.0;
    // snapped to the nearest of a box of painted papers (the first 'levels' of them); per channel levels gave
    // 64 colours, and photo noise flickered between them: confetti
    vec3 pal[12];
    pal[0] = vec3(0.96, 0.95, 0.92); pal[1] = vec3(0.15, 0.13, 0.13); pal[2] = vec3(0.45, 0.32, 0.22);
    pal[3] = vec3(0.80, 0.25, 0.20); pal[4] = vec3(0.20, 0.35, 0.65); pal[5] = vec3(0.30, 0.55, 0.30);
    pal[6] = vec3(0.95, 0.80, 0.25); pal[7] = vec3(0.60, 0.30, 0.55); pal[8] = vec3(0.70, 0.62, 0.52);
    pal[9] = vec3(0.55, 0.75, 0.85); pal[10] = vec3(0.90, 0.55, 0.30); pal[11] = vec3(0.92, 0.60, 0.70);
    vec3 best = pal[0];
    float bd = 99.0;
    for (int i = 0; i < 12; i++) {
        if (float(i) >= levels) break;
        float dd = distance(c, pal[i]);
        if (dd < bd) { bd = dd; best = pal[i]; }
    }
    return best;
}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    sc = sc - origin + boil;
    vec2 w = (vec2(fbm(sc / 25.0), fbm(sc / 25.0 + 9.1)) - 0.5) * tear * 10.0
        + (vec2(vnoise(sc / 3.0), vnoise(sc / 3.0 + 4.0)) - 0.5) * tear * 2.0;
    vec2 uvw = uv + w * texel;
    float alpha = Texel(tex, uvw).a;
    vec3 r = region(tex, uvw);
    if (min(r.r, min(r.g, r.b)) > 0.9) return vec4(paper, alpha) * color; // the white paper: the sheet itself
    // the painted sheet this piece is cut from
    float id = dot(r, vec3(12.9, 78.2, 37.7));
    float a = fract(sin(id) * 43758.5) * 3.14;
    vec2 d = vec2(cos(a), sin(a));
    vec2 p = vec2(dot(sc, d) / 22.0, dot(sc, vec2(-d.y, d.x)) / 3.0);
    vec3 col = r * (1.0 + ((vnoise(p) - 0.5) * 0.3 + (fbm(sc / 30.0 + id) - 0.5) * 0.25) * paint);
    col += (vec3(vnoise(p * 0.5 + id), vnoise(p * 0.5 + id + 3.0), vnoise(p * 0.5 + id + 6.0)) - 0.5) * paint * 0.07;
    // a torn edge: a thin white fringe, here and there
    float edge = 0.0;
    for (int i = 0; i < 4; i++) {
        float an = float(i) * 1.5708 + 0.4;
        vec3 o = region(tex, uvw + vec2(cos(an), sin(an)) * fringe * texel);
        edge = max(edge, step(0.01, length(o - r)));
    }
    edge *= step(0.4, vnoise(sc / 7.0));
    col = mix(col, paper * 1.03, edge * 0.85);
    // the shadow of a lighter piece lying on this one
    vec3 above = region(tex, uvw - vec2(1.0, 1.0) * shadow * 4.0 * texel);
    float under = step(0.01, length(above - r)) * step(dot(r, vec3(0.333)), dot(above, vec3(0.333)));
    col *= 1.0 - under * 0.2 * min(shadow, 1.5);
    return vec4(clamp(col, 0.0, 1.0), alpha) * color;
}
]]
local cutShader
local function cutSettings()
    local c = st()
    c.cut = c.cut or { paper = 1, levels = 9, soften = 9, tear = 0.6, fringe = 2, shadow = 0.8, paint = 0.8 }
    return c.cut
end
local function applyCut(texelW, texelH)
    local k = cutSettings()
    cutShader = cutShader or love.graphics.newShader(CUT_SHADER)
    cutShader:send('texel', { texelW, texelH })
    cutShader:send('paper', hex(CUT_PAPERS[k.paper][2]))
    for _, name in ipairs({ 'levels', 'soften', 'tear', 'fringe', 'shadow', 'paint' }) do
        cutShader:send(name, k[name])
    end
    common(cutShader)
    love.graphics.setShader(cutShader)
end

local function apply(texelW, texelH)
    local process = st().process
    if process == 'photocopy' then applyCopy(texelW, texelH)
    elseif process == 'watercolor' then applyWater(texelW, texelH)
    elseif process == 'woodcut' then applyWood(texelW, texelH)
    elseif process == 'cmyk' then applyCmyk(texelW, texelH)
    elseif process == 'gouache' then applyGouache(texelW, texelH)
    elseif process == 'cutpaper' then applyCut(texelW, texelH)
    else applyRiso(texelW, texelH) end
end
local function paperColour()
    if st().process == 'photocopy' then return hex(COPY_PAPERS[copySettings().paper][2]) end
    if st().process == 'watercolor' then return hex(WATER_PAPERS[waterSettings().paper][2]) end
    if st().process == 'woodcut' then return hex(WOOD_PAPERS[woodSettings().paper][2]) end
    if st().process == 'cmyk' then return hex(CMYK_PAPERS[cmykSettings().paper][2]) end
    if st().process == 'gouache' then return hex(GOUACHE_PAPERS[gouacheSettings().paper][2]) end
    if st().process == 'cutpaper' then return hex(CUT_PAPERS[cutSettings().paper][2]) end
    return hex(PAPERS[st().paper][2])
end

-- ── the scene: soil, a few textured blocks, a Mipo ──
local function mipo()
    for _, inst in pairs(mipoRegistry.getAll()) do
        if mipoKit.isAlive(inst) then return inst end
    end
end
local function block(label, x, y, w, h, url, tile)
    if getObjectsByLabel(label)[1] then return end
    local thing = objectManager.addThing('rectangle', { x = x, y = y, width = w, height = h, bodyType = 'static',
        label = label })
    if not thing then return end
    local extra = fixtures.createSFixture(thing.body, 0, 0, 'tile-repeat', { radius = 20 }):getUserData().extra
    extra.main = extra.main or {}
    extra.main.bgURL, extra.opacity, extra.tileWidthM, extra.tileHeightM = url, 1, tile, tile
end
local function ensureScene()
    block('ground', 0, GROUND_Y + 300, 6000, 600, 'world/ground/soil-01.jpg', 0.6)
    block('plaster', 450, GROUND_Y - 250, 500, 500, 'world/walls/plaster-02.jpg', 1)
    block('planks', -700, GROUND_Y - 150, 300, 300, 'world/walls/planks-01.jpg', 0.8)
    block('moss', 1000, GROUND_Y - 60, 400, 120, 'world/ground/moss-01.jpg', 0.5)
    if not mipo() then
        local inst = characterManager.createCharacter('humanoid', -150, GROUND_Y - 900, 0.9)
        if inst then characterManager.randomizeMipoConstrained(inst) end
    end
end

function s.onStart()
    worldState.paused = false
    st()
    ensureScene()
end

function s.onKeyPress(key)
    local c = st()
    if key == 'h' then c.showPanel = not c.showPanel end
    if key == 'v' then c.view = c.view == 'scene' and 'textures' or 'scene' end
end

local function original() return love.keyboard.isDown('space') end

-- 'scene': the world drawn into a canvas, then laid down through the print
local canvas, previous
function s.drawBelow()
    local c = st()
    c.capturing = false
    if c.view ~= 'scene' or original() then return end
    local w, h = love.graphics.getDimensions()
    if not canvas or canvas:getWidth() ~= w or canvas:getHeight() ~= h then
        canvas = love.graphics.newCanvas(w, h)
    end
    previous = love.graphics.getCanvas()
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(1, 1, 1, 1) -- the world's dark backdrop would print as solid ink: bare paper instead
    c.capturing = true
end

function s.draw()
    local c = st()
    if not c.capturing then return end
    c.capturing = false
    if previous then love.graphics.setCanvas({ previous, stencil = true }) else love.graphics.setCanvas() end
    previous = nil
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    apply(1 / canvas:getWidth(), 1 / canvas:getHeight())
    love.graphics.draw(canvas, 0, 0)
    love.graphics.setShader()
    love.graphics.pop()
end

-- 'textures': a sheet of them, each printed
local images = {}
local function image(path)
    if not images[path] then
        local img = love.graphics.newImage('textures/world/' .. path)
        img:setWrap('repeat', 'repeat')
        images[path] = img
    end
    return images[path]
end
local function drawSheet(sw, sh)
    local cols, rows, gap = 4, 2, 10
    local x0, y0 = 20, 20
    local tw = (sw - 460 - x0 - gap * (cols - 1)) / cols
    local th = (sh - 40 - gap) / rows
    love.graphics.setColor(paperColour())
    love.graphics.rectangle('fill', 0, 0, sw, sh)
    for i, path in ipairs(TEXTURES) do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        local x, y = x0 + col * (tw + gap), y0 + row * (th + gap)
        local img = image(path)
        local scale = 0.5 -- texture px per screen px x2: a 1024 texture over 512 px
        local quad = love.graphics.newQuad(0, 0, tw / scale, th / scale, img:getWidth(), img:getHeight())
        love.graphics.setColor(1, 1, 1, 1)
        if not original() then apply(1 / (img:getWidth() * scale), 1 / (img:getHeight() * scale)) end
        love.graphics.draw(img, quad, x, y, 0, scale, scale)
        love.graphics.setShader()
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.print(path:match('([^/]+)%.jpg$'), x + 6, y + th - 18)
    end
end

-- ── the panel ──
local P = { w = 420, row = 30, pad = 10 }
local SLIDERS = { { 'dot', 'dot size', 1, 8, 0.5 }, { 'offset', 'misregister', 0, 8, 0.5 },
    { 'grain', 'grain', 0, 1, 0.05 }, { 'density', 'ink', 0.3, 1.6, 0.05 }, { 'contrast', 'contrast', 0.5, 2.5, 0.05 } }
local COPY_SLIDERS = { { 'darkness', 'darkness', 0, 1, 0.02 }, { 'contrast', 'contrast', 0.5, 4, 0.05 },
    { 'copies', 'copies', 0, 5, 1 }, { 'grit', 'grit', 0, 1, 0.05 }, { 'speckle', 'dust', 0, 2, 0.05 },
    { 'streaks', 'streaks', 0, 1, 0.05 }, { 'detail', 'detail', 0, 1, 0.05 } }
local WATER_SLIDERS = { { 'wobble', 'wobble', 0, 2, 0.05 }, { 'soften', 'soften', 0, 8, 0.25 },
    { 'bleed', 'bleed', 0, 1, 0.05 }, { 'edges', 'edges', 0, 3, 0.05 }, { 'pigment', 'pigment', 0, 1.5, 0.05 },
    { 'granulation', 'granulation', 0, 1.5, 0.05 }, { 'water', 'water', 0, 1, 0.05 } }
local WOOD_SLIDERS = { { 'darkness', 'darkness', 0, 1, 0.02 }, { 'spacing', 'line gap', 2, 14, 0.5 },
    { 'angle', 'angle', 0, 3.14, 0.05 }, { 'bend', 'bend', 0, 12, 0.25 }, { 'chips', 'gouge', 0, 1.5, 0.05 },
    { 'outline', 'outline', 0, 4, 0.1 }, { 'grain', 'wood grain', 0, 1, 0.05 }, { 'colour', 'colour', 0, 1, 0.05 },
    { 'levels', 'colours', 2, 6, 1 }, { 'offset', 'off register', 0, 8, 0.5 } }
local CMYK_SLIDERS = { { 'pixel', 'pixel', 1, 8, 0.5 }, { 'misreg', 'misregister', 0, 16, 0.5 },
    { 'slip', 'slip', 0, 2, 0.05 }, { 'ghost', 'ghost', 0, 1, 0.05 }, { 'starve', 'ink runs out', 0, 1, 0.05 },
    { 'gain', 'dot gain', 0, 1, 0.05 }, { 'blackgen', 'black', 0, 1, 0.05 }, { 'contrast', 'contrast', 0.5, 2.5, 0.05 } }
local GOUACHE_SLIDERS = { { 'radius', 'patches', 1, 14, 0.5 }, { 'flatness', 'flat', 0, 1, 0.05 },
    { 'chalk', 'chalk', 0, 1, 0.05 }, { 'brush', 'brush', 0, 1.5, 0.05 }, { 'dry', 'dry', 0, 1, 0.05 },
    { 'wobble', 'wobble', 0, 2, 0.05 } }
local CUT_SLIDERS = { { 'levels', 'papers', 2, 12, 1 }, { 'soften', 'soften', 0, 24, 0.5 },
    { 'tear', 'tear', 0, 2, 0.05 }, { 'fringe', 'fringe', 0, 5, 0.25 }, { 'shadow', 'shadow', 0, 2, 0.05 },
    { 'paint', 'paint', 0, 1.5, 0.05 } }

local function buttonRow(x, y, inner, bh, names, picked, onPick)
    local bw = (inner - (#names - 1) * 4) / #names
    for i, name in ipairs(names) do
        if ui.button(x + (i - 1) * (bw + 4), y, bw, picked(i, name) and ('[' .. name .. ']') or name, bh) then
            onPick(i, name)
        end
    end
end
local function sliders(x, y, inner, list, values, prefix)
    for _, sl in ipairs(list) do
        ui.label(x, y + 5, sl[2])
        local value = ui.sliderWithInput(prefix .. sl[1], x + 100, y - 4, inner - 190, sl[3], sl[4], values[sl[1]],
            nil, sl[5])
        if value then values[sl[1]] = value + 0 end
        y = y + P.row
    end
    return y
end
local function names(list)
    local out = {}
    for i, item in ipairs(list) do out[i] = item[1] end
    return out
end

local function drawRisoControls(c, x, y, inner, bh)
    -- the three ink drums: < name >, '-' for none (not the first)
    for k = 1, 3 do
        local i = c.inks[k]
        local col = i and hex(INKS[i][2]) or { 0.5, 0.5, 0.5 }
        love.graphics.setColor(col[1], col[2], col[3], i and 1 or 0.3)
        love.graphics.rectangle('fill', x, y + 2, 22, bh - 2, 4, 4)
        local function step(d)
            local n = #INKS + (k > 1 and 1 or 0)
            local cur = i or (#INKS + 1)
            cur = (cur - 1 + d) % n + 1
            c.inks[k] = cur <= #INKS and cur or nil
        end
        if ui.button(x + 30, y, 34, '<', bh) then step(-1) end
        ui.label(x + 72, y + 5, 'ink ' .. k .. ': ' .. (i and INKS[i][1] or '-'))
        if ui.button(x + inner - 34, y, 34, '>', bh) then step(1) end
        y = y + P.row
    end
    local pairings = {}
    for i in ipairs(SETS) do pairings[i] = tostring(i) end
    buttonRow(x, y, inner, bh, pairings, function() return false end, function(i)
        local set = SETS[i]
        c.inks = { inkNamed(set[1]), inkNamed(set[2]), set[3] and inkNamed(set[3]) or nil }
    end)
    y = y + P.row
    buttonRow(x, y, inner, bh, names(PAPERS), function(i) return c.paper == i end, function(i) c.paper = i end)
    y = y + P.row
    buttonRow(x, y, inner, bh, { 'grain', 'dots' }, function(_, n) return c.mode == n end, function(_, n) c.mode = n end)
    y = y + P.row
    return sliders(x, y, inner, SLIDERS, c, 'riso-')
end

local function drawGouacheControls(x, y, inner, bh)
    local k = gouacheSettings()
    buttonRow(x, y, inner, bh, names(GOUACHE_PAPERS), function(i) return k.paper == i end, function(i) k.paper = i end)
    y = y + P.row
    return sliders(x, y, inner, GOUACHE_SLIDERS, k, 'gouache-')
end

local function drawCutControls(x, y, inner, bh)
    local k = cutSettings()
    buttonRow(x, y, inner, bh, names(CUT_PAPERS), function(i) return k.paper == i end, function(i) k.paper = i end)
    y = y + P.row
    return sliders(x, y, inner, CUT_SLIDERS, k, 'cut-')
end

local function drawCmykControls(x, y, inner, bh)
    local k = cmykSettings()
    buttonRow(x, y, inner, bh, names(CMYK_PAPERS), function(i) return k.paper == i end, function(i) k.paper = i end)
    y = y + P.row
    buttonRow(x, y, inner, bh, CMYK_MODES, function(i) return k.mode == i end, function(i) k.mode = i end)
    y = y + P.row
    return sliders(x, y, inner, CMYK_SLIDERS, k, 'cmyk-')
end

local function drawWoodControls(x, y, inner, bh)
    local k = woodSettings()
    buttonRow(x, y, inner, bh, names(WOOD_PAPERS), function(i) return k.paper == i end, function(i) k.paper = i end)
    y = y + P.row
    buttonRow(x, y, inner, bh, names(WOOD_INKS), function(i) return k.ink == i end, function(i) k.ink = i end)
    y = y + P.row
    return sliders(x, y, inner, WOOD_SLIDERS, k, 'wood-')
end

local function drawWaterControls(x, y, inner, bh)
    local k = waterSettings()
    buttonRow(x, y, inner, bh, names(WATER_PAPERS), function(i) return k.paper == i end, function(i) k.paper = i end)
    y = y + P.row
    return sliders(x, y, inner, WATER_SLIDERS, k, 'water-')
end

local function drawCopyControls(x, y, inner, bh)
    local k = copySettings()
    buttonRow(x, y, inner, bh, names(COPY_PAPERS), function(i) return k.paper == i end, function(i) k.paper = i end)
    y = y + P.row
    buttonRow(x, y, inner, bh, names(TONERS), function(i) return k.toner == i end, function(i) k.toner = i end)
    y = y + P.row
    return sliders(x, y, inner, COPY_SLIDERS, k, 'copy-')
end

function s.drawUI()
    local c = st()
    local sw, sh = ui.getDimensions()
    if c.view == 'textures' then drawSheet(sw, sh) end
    if not c.showPanel then return end
    ui.startFrame()
    local process = c.process or 'riso'
    local own = { riso = 3 + 1 + 2 + #SLIDERS, photocopy = 2 + #COPY_SLIDERS, watercolor = 1 + #WATER_SLIDERS,
        woodcut = 2 + #WOOD_SLIDERS, cmyk = 2 + #CMYK_SLIDERS, gouache = 1 + #GOUACHE_SLIDERS,
        cutpaper = 1 + #CUT_SLIDERS }
    local rows = 2 + own[process] + 2 + 2
    local w, h = P.w, P.row * rows + 40
    local x0, y0 = sw - w - 16, math.max(12, (sh - h) / 2)
    ui.panel(x0, y0, w, h, '•• ' .. process .. ' ••', function()
        local x, y = x0 + P.pad, y0 + 32
        local inner = w - P.pad * 2
        local bh = P.row - 6
        -- two rows: print, then paint and paper
        local ROWS = { { { 'riso', 'riso' }, { 'photocopy', 'copy' }, { 'woodcut', 'wood' }, { 'cmyk', 'cmyk' } },
            { { 'watercolor', 'water' }, { 'gouache', 'gouache' }, { 'cutpaper', 'cut paper' } } }
        for _, row in ipairs(ROWS) do
            local labels = {}
            for i, item in ipairs(row) do labels[i] = item[2] end
            buttonRow(x, y, inner, bh, labels, function(i) return process == row[i][1] end,
                function(i) c.process = row[i][1] end)
            y = y + P.row
        end
        if process == 'photocopy' then y = drawCopyControls(x, y, inner, bh)
        elseif process == 'watercolor' then y = drawWaterControls(x, y, inner, bh)
        elseif process == 'woodcut' then y = drawWoodControls(x, y, inner, bh)
        elseif process == 'cmyk' then y = drawCmykControls(x, y, inner, bh)
        elseif process == 'gouache' then y = drawGouacheControls(x, y, inner, bh)
        elseif process == 'cutpaper' then y = drawCutControls(x, y, inner, bh)
        else y = drawRisoControls(c, x, y, inner, bh) end
        -- for all of them: boil, and the paper moving with the world
        c.boil = c.boil or 0
        y = sliders(x, y, inner, { { 'boil', 'boil (fps)', 0, 15, 1 } }, c, 'all-')
        local ac, av = ui.checkbox(x, y + 2, c.anchor ~= false, 'the paper moves with the world (scene)')
        if ac then c.anchor = av end
        y = y + P.row
        buttonRow(x, y, inner, bh, { 'textures', 'scene' }, function(_, n) return c.view == n end,
            function(_, n) c.view = n end)
        y = y + P.row
        ui.label(x, y + 5, 'space: the original   v view   h panel')
    end)
end

return s

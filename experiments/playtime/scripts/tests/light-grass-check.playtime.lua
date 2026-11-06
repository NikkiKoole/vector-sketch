-- light-grass-check: working on light — a sun, a warm and a cool lamp to carry about, a turning lamp, over
-- six plasticine shapes and three Mipos; and grass on a spinning turf (its blades rebuilt every frame: the counter).
-- From the LITTLE-USED rounds (docs/LITTLE-USED.md, 2026-11-06). Up to 8 lights reach a shape
-- (src/render/shaders.lua MAX_LIGHTS); a light's colour tints, its intensity and nearness light.
-- The shapes start lit strongly and baked round (their settings, src/render/shaders.lua and
-- src/render/form-bake.lua; 0 shows them as other scenes draw them).
-- play mode (tab): drag the warm and the cool lamp about.
-- keys:
--   d the day-night cycle (a day in DAY_SECONDS: the sun rises on the left at 6, sets on the right at 18,
--     the moon the other way round the night; night, dawn, day, golden hour and dusk blended by the hour)
--   t the day faster: a day in 120 / 30 / 10 seconds (turns the cycle on)
--   , . an hour back / on   1 noon   2 dusk (19:00)   3 midnight   4 only the turning lamp (r: its range)
--   m the Mipos lit like the shapes / as drawn (their picture parts, limbs and torso; not the face)
--   c the Mipos' clay (grain, dents, sheen) off / on (on to start): off, the light and roundness only
--   h contact shadows off / on (src/contact-shadows.lua; how dark goes with the time of day)
--   w shadows on the back wall off / on (src/backdrop-shadows.lua: shifted the way the sun or moon
--     shines, short and crisp at noon, long and soft when it's low, fading with its light; only on the
--     wall, none on the open sky)
--   q the wall's surface: flat / smooth clay / fine plaster / coarse plaster (lit from the sun or moon)
--   the stones go from smooth clay to rough render (left to right), the fence is coarse plaster: their
--   roughness is the plasticine grain, dents, grain size and sheen (the shape's panel)
--   l the back light off / on (from behind: the edges glow; evening orange, night the moon's blue)
--   k the sky light off / on (light from all of above in the sky's colour, from below in the ground's)
--   g light swing   z how much the light comes from the front   f the quick form's depth
--   b baked form / the shader's quick guess   n baked rise (1 a dome, 0.5, 0.2 a pebble)
--   a lights add up (the sky lights the base, every lamp adds; LS3) / as before (how lit stops at full)
--   0 the shapes as other scenes draw them   s turf spinning or not
--   o everything back to the settings liked so far (all on, smooth clay wall, the cycle from 9:00)
--   v 3D shadows on / off (src/projected-shadows.lua, LS22): a floor appears between the wall and the
--     things, and the shadows are thrown from the light along it and up the wall, hard; with w's on too,
--     both (the soft ones on the wall only, a little lighter)
--   e the 3D shadows' lights: the sun or moon (a low sun stretches them long over the floor) / the warm
--     lamp (drag it in play mode; a torch: close to the things a big shadow on the wall, back it shrinks) /
--     the sun or moon and the warm lamp / and both lamps: each throws its own shadow
--   y how much the sun shines out of the wall: some / a little (shadows run far along the floor) / much
--   [ ] the lamp nearer the things / further towards you   j edges: hard / a small lamp / a big lamp

local s = {}

-- The day: five looks (after ../sky-atmosphere's timeline, WORLD-BUILDING G5, plus a golden hour), blended
-- by the hour. Each
-- sets the sky, the sun's and the moon's colour and strength (at their highest), the lamps, the sky
-- light (colour, ground colour, strength), the back light, and how dark the contact and wall shadows are.
local LOOKS = {
    night = { sky = { 0.08, 0.1, 0.22 }, sun = { 'fff2d9', 0 }, moon = { 'a8c0ff', 0.35 }, warm = 2.0, cool = 1.6,
        skyLight = { '3a4a80', '141420', 0.3 }, back = { 'a8c0ff', 1.8 }, shadows = 0.3, wallShadows = 0.2 },
    dawn = { sky = { 0.97, 0.68, 0.6 }, sun = { 'ffb070', 0.8 }, moon = { 'a8c0ff', 0.15 }, warm = 0.6, cool = 0,
        skyLight = { 'ffb0a0', '604050', 0.45 }, back = { 'ffc080', 2.0 }, shadows = 0.4, wallShadows = 0.3 },
    day = { sky = { 0.62, 0.78, 0.92 }, sun = { 'fff2d9', 1.2 }, moon = { 'a8c0ff', 0 }, warm = 0, cool = 0,
        skyLight = { '9cc8ff', '8a7a50', 0.6 }, back = { 'ffffff', 0.6 }, shadows = 0.5, wallShadows = 0.35 },
    -- the golden hour, between day and dusk: blue straight to orange went through a muddy grey
    golden = { sky = { 0.98, 0.84, 0.62 }, sun = { 'ffd890', 1.1 }, moon = { 'a8c0ff', 0 }, warm = 0.3, cool = 0,
        skyLight = { 'ffe0b0', '7a6040', 0.55 }, back = { 'ffd080', 1.8 }, shadows = 0.45, wallShadows = 0.33 },
    dusk = { sky = { 0.93, 0.62, 0.45 }, sun = { 'ff8a3c', 0.9 }, moon = { 'a8c0ff', 0.1 }, warm = 1.2, cool = 0,
        skyLight = { 'ffa080', '5a3848', 0.5 }, back = { 'ffa050', 2.4 }, shadows = 0.4, wallShadows = 0.3 },
}
local TIMELINE = { { 0, 'night' }, { 5, 'night' }, { 6.5, 'dawn' }, { 8.5, 'day' }, { 17, 'day' }, { 18, 'golden' },
    { 19, 'dusk' }, { 20.5, 'night' }, { 24, 'night' } }
local HOUR_KEYS = { ['1'] = 12, ['2'] = 19, ['3'] = 0 } -- day, dusk, night
local DAY_SECONDS = 120 -- a whole day, with the cycle running
-- t: the day faster (the sun swinging round to watch the shadows move), seconds a day
local DAY_SPEEDS = { 120, 30, 10 }
-- the sun and the moon on an arc over the scene: rising on the left, setting on the right, shining at
-- its middle
local ARC = { x = -300, y = 450, r = 1150, squash = 0.8 }
-- 4: only the turning lamp, no sky
local LAMP_ONLY = { shadows = 0.45, wallShadows = 0.3 }

-- the back wall (backdrop shadows fall on it, src/backdrop-shadows.lua; not on the open sky), and how
-- far it is behind the things in front of it (how far their shadows shift), per time of day how dark
local WALL = { x = -1600, y = -700, w = 3200, h = 1150, colour = { 0.91, 0.86, 0.75 } }
-- the wall's surface (q): flat, smooth clay, fine plaster, coarse plaster. grit: how much sand and pits,
-- scale: the size of its bumps (world units), relief: how deep they are under the light, sheen: a soft
-- shine where a bump faces the light (clay has it, plaster doesn't)
local GRITS = {
    { name = 'flat' },
    { name = 'smooth clay', grit = 0.12, scale = 90, relief = 1.6, sheen = 0.18 },
    { name = 'fine plaster', grit = 0.6, scale = 18, relief = 2.5, sheen = 0 },
    { name = 'coarse plaster', grit = 1.0, scale = 40, relief = 5, sheen = 0 },
}
local wallShader
local function plasterShader()
    wallShader = wallShader or love.graphics.newShader([[
        // LÖVE applies the camera to a rectangle's corners before the shader sees them (they're batched),
        // so the shader gets screen positions: back to the world with the camera's corner and zoom, or
        // the grit sticks to the screen while you drag the view
        uniform vec2 origin;
        uniform float zoom;
        varying vec2 wpos;
        #ifdef VERTEX
        vec4 position(mat4 t, vec4 v) { wpos = origin + v.xy / zoom; return t * v; }
        #endif
        #ifdef PIXEL
        uniform float grit;
        uniform float scale;
        uniform float relief;
        uniform vec2 toLight;
        uniform float lit;
        uniform float sheen;
        float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
        float vnoise(vec2 p) {
            vec2 i = floor(p);
            vec2 f = fract(p);
            f = f * f * (3.0 - 2.0 * f);
            return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
                mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
        }
        float fbm(vec2 p) {
            float v = 0.0;
            float a = 0.5;
            for (int k = 0; k < 4; k++) { v += a * vnoise(p); p *= 2.1; a *= 0.5; }
            return v;
        }
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
            vec2 p = wpos / scale;
            float h = fbm(p);
            float hx = fbm(p + vec2(0.15, 0.0));
            float hy = fbm(p + vec2(0.0, 0.15));
            vec3 n = normalize(vec3((h - hx) * relief, (h - hy) * relief, 1.0));
            // around the wall's own colour: a flat bit of wall stays as it is, the bumps lighter or
            // darker than that by the light, the pits and the sand a little
            vec3 L = normalize(vec3(toLight, 0.6));
            float light = dot(n, L) - L.z;
            float sand = hash(floor(wpos / 2.0));
            float shade = 1.0 + light * lit * 0.6 - grit * (0.5 - h) * 0.18
                - grit * step(0.93, sand) * 0.12 + grit * step(sand, 0.05) * 0.06;
            float shine = pow(max(dot(n, normalize(L + vec3(0.0, 0.0, 1.0))), 0.0), 24.0) * sheen * lit;
            return vec4(color.rgb * shade + shine, color.a);
        }
        #endif
    ]])
    return wallShader
end
local WALL_BEHIND = 90
local function wallShape() love.graphics.rectangle('fill', WALL.x, WALL.y, WALL.w, WALL.h) end

-- 3D shadows (v): the things stand SOLID_DEPTH in front of the wall, so its foot moves up that much and
-- the band between is the floor behind them (src/projected-shadows.lua). The sun's way towards it comes
-- SUN_TOWARDS out of the wall; the lamp starts LAMP_DEPTH in front of the things ([ ] move it).
local GROUND_TOP = 450 -- where everything stands (the grassy ground's top)
local SOLID_DEPTH = 400
local FLOOR_Y = GROUND_TOP - SOLID_DEPTH
-- y steps it: low, the shadows run far along the floor before they reach the wall; high, they climb it soon
local SUN_TOWARDS = { 0.2, 0.08, 0.5 }
local LAMP_DEPTH = 300
local LAMP_DEPTHS = { 40, 100, 200, 300, 500, 900, 1600, 3000 }
-- j: hard, a small lamp, a big one (world units; for the sun how wide, as a slope)
local SOFTNESS = { { name = 'hard', lamp = 0, sun = 0 }, { name = 'small lamp', lamp = 14, sun = 0.03 },
    { name = 'big lamp', lamp = 45, sun = 0.1 } }

-- The ground with 3D shadows on (after scripts/spikes/burrow's earth, Nikki 2026-11-06: "a sort of ground
-- to cast on too"): packed earth seen from a little above, from the wall's foot to the ground's front edge,
-- then the earth cut open below that edge (topsoil, clay, grain, fine roots), a drawn crayon rim along the
-- edge and a thinner one in the corner with the wall. The floor behind the things is drawn under the
-- shadows (drawBelow); the rest over the ground's plain shape, under the things (a draw split).
local GROUND_FRONT = 610 -- the grassy ground's front edge
local CUT_DEPTH = 240    -- how far the cut-open earth goes down
local GROUND_X0, GROUND_X1 = -2100, 2100 -- the grassy ground's ends
local RIM_COLOUR = { 0.25, 0.17, 0.11 }
local groundShader
local function earthShader()
    groundShader = groundShader or love.graphics.newShader([[
        uniform vec2 origin;
        uniform float zoom;
        varying vec2 wpos;
        #ifdef VERTEX
        vec4 position(mat4 t, vec4 v) { wpos = origin + v.xy / zoom; return t * v; }
        #endif
        #ifdef PIXEL
        uniform float floorY;  // the wall's foot: the floor goes from here
        uniform float frontY;  // the ground's front edge: the cut earth below it
        float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
        float vnoise(vec2 p) {
            vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
            return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
                mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
        }
        vec3 floorTop(vec2 w) {
            // seen from a little above: the ground's grain squashed in depth
            vec2 p = vec2(w.x, (w.y - floorY) * 2.5);
            vec3 col = vec3(0.56, 0.42, 0.29);
            col *= 0.86 + hash(floor(p / 7.0)) * 0.12 + vnoise(p * 0.012) * 0.12 + vnoise(p * 0.003) * 0.1;
            // worn paths and damp patches
            col = mix(col, vec3(0.42, 0.31, 0.21), smoothstep(0.55, 0.75, vnoise(p * 0.0015 + 9.0)) * 0.5);
            // pebbles: a few cells get a small stone, lit on top
            vec2 cell = floor(p / 46.0);
            float h = hash(cell);
            if (h > 0.86) {
                vec2 c = (cell + 0.25 + 0.5 * vec2(hash(cell + 3.1), hash(cell + 7.7))) * 46.0;
                vec2 d = (p - c) / vec2(9.0 + 8.0 * h, 6.0 + 6.0 * h);
                float r = dot(d, d);
                if (r < 1.0) col = mix(col, vec3(0.62, 0.55, 0.47) * (1.05 - 0.35 * d.y), 0.85);
            }
            // darker into the corner with the wall
            return col * mix(0.72, 1.0, smoothstep(0.0, 90.0, w.y - floorY));
        }
        vec3 cut(vec2 w) {
            float depth = w.y - frontY;
            float y = depth + (vnoise(vec2(w.x * 0.002, 3.0)) - 0.5) * 60.0;
            vec3 col = mix(vec3(0.36, 0.25, 0.16), vec3(0.62, 0.44, 0.28), smoothstep(40.0, 180.0, y));
            col *= 0.94 + 0.10 * smoothstep(0.45, 0.6, vnoise(vec2(w.x * 0.0015, w.y * 0.015)));
            col *= 0.86 + hash(floor(w / 7.0)) * 0.12 + vnoise(w * 0.012) * 0.12 + vnoise(w * 0.003) * 0.08;
            float rn = vnoise(vec2(w.x * 0.008, w.y * 0.004)) + vnoise(w * 0.03) * 0.15;
            float root = (1.0 - smoothstep(0.0, 0.025, abs(rn - 0.5))) * (1.0 - smoothstep(60.0, 200.0, depth));
            col = mix(col, vec3(0.22, 0.15, 0.10), root * 0.7);
            // the edge's overhang: darker just under it
            return col * mix(0.7, 1.0, smoothstep(0.0, 40.0, depth));
        }
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
            vec3 col = wpos.y < frontY ? floorTop(wpos) : cut(wpos);
            return vec4(col, 1.0) * color;
        }
        #endif
    ]])
    return groundShader
end

-- the crayon strokes (textures/strokes, as burrow's rim): line pictures run down the image, track pictures
-- across it; `from`..`to` is the part of the picture the stroke uses
local STROKE_KINDS = { line = { alongX = false, from = 0.1, to = 0.9 },
    track = { alongX = true, from = 0.02, to = 0.98 } }
local strokePictures
local function strokes()
    if strokePictures then return strokePictures end
    strokePictures = {}
    local files = love.filesystem.getDirectoryItems('textures/strokes')
    table.sort(files)
    for _, file in ipairs(files) do
        local kind = STROKE_KINDS[file:match('^(%a+)%d*%.png$') or '']
        if kind then
            local image = love.graphics.newImage('textures/strokes/' .. file, { mipmaps = true })
            image:setMipmapFilter('linear')
            strokePictures[#strokePictures + 1] = { image = image, alongX = kind.alongX, from = kind.from,
                to = kind.to }
        end
    end
    return strokePictures
end

-- a straight drawn line along y from x0 to x1, `width` wide: the pictures one after another, each mirrored
-- or backwards by chance, the line wobbling and its width breathing (a mesh per picture laid)
local function strokeLine(y, x0, x1, width, seed)
    local pictures = strokes()
    if #pictures == 0 then return {} end
    local meshes, x, k = {}, x0, 0
    local half = width / 2
    while x < x1 do
        local rng = love.math.newRandomGenerator(seed * 1000 + k)
        local pic = pictures[rng:random(#pictures)]
        local iw, ih = pic.image:getDimensions()
        local thick, long = pic.alongX and ih or iw, pic.alongX and iw or ih
        local length = long * (pic.to - pic.from) * (width / thick)
        local mirror, backwards = rng:random() < 0.5, rng:random() < 0.5
        local verts = {}
        local steps = math.max(2, math.ceil(length / 12))
        for i = 0, steps do
            local t = i / steps
            local px = x + length * t
            local wob = (love.math.noise(seed, px * 0.004) - 0.5) * half * 1.6
                + (love.math.noise(seed + 50, px * 0.02) - 0.5) * half * 0.5
            local w = half * (0.8 + love.math.noise(seed + 100, px * 0.004) * 0.4)
            local along = pic.from + (pic.to - pic.from) * (backwards and 1 - t or t)
            for side = 0, 1 do
                local across = mirror and 1 - side or side
                local u, v = across, along
                if pic.alongX then u, v = along, across end
                verts[#verts + 1] = { px, y + wob + (side == 0 and -w or w), u, v }
            end
        end
        local mesh = love.graphics.newMesh(verts, 'strip', 'static')
        mesh:setTexture(pic.image)
        meshes[#meshes + 1] = mesh
        x, k = x + length * 0.97, k + 1
    end
    return meshes
end

local rims
local function drawRims(which, tint)
    rims = rims or { front = strokeLine(GROUND_FRONT, GROUND_X0, GROUND_X1, 26, 3),
        corner = strokeLine(FLOOR_Y, WALL.x, WALL.x + WALL.w, 14, 11) }
    love.graphics.setColor(RIM_COLOUR[1] * tint[1], RIM_COLOUR[2] * tint[2], RIM_COLOUR[3] * tint[3], 1)
    for _, mesh in ipairs(rims[which]) do love.graphics.draw(mesh) end
end

-- the sky's light on the ground, as on the wall
local function groundTint()
    local now = state.lightLab and state.lightLab.now
    local sky = now and now.sky or { 0.4, 0.4, 0.45 }
    return { math.min(1, 0.2 + sky[1] * 0.9), math.min(1, 0.2 + sky[2] * 0.9), math.min(1, 0.2 + sky[3] * 0.9) }
end

-- the earth from y0 to y1 (floor above the front edge, cut earth below), the ground's width
local function drawEarth(y0, y1, tint)
    local shader = earthShader()
    love.graphics.setShader(shader)
    local ox, oy = cam:getWorldCoordinates(0, 0)
    local oneRight = cam:getWorldCoordinates(1, 0)
    shader:send('origin', { ox, oy })
    shader:send('zoom', 1 / (oneRight - ox))
    shader:send('floorY', FLOOR_Y)
    shader:send('frontY', GROUND_FRONT)
    love.graphics.setColor(tint[1], tint[2], tint[3], 1)
    love.graphics.rectangle('fill', GROUND_X0, y0, GROUND_X1 - GROUND_X0, y1 - y0)
    love.graphics.setShader()
end

-- over the ground's plain shape, under everything drawn on it (the textured world's first split)
local function drawGroundFront()
    local tint = groundTint()
    drawEarth(GROUND_TOP, GROUND_FRONT + CUT_DEPTH, tint)
    drawRims('front', tint)
    love.graphics.setColor(1, 1, 1, 1)
end
local GROUND_SPLITS = { { z = -math.huge, fn = drawGroundFront } }
local LIGHTS = { 'sun', 'moon', 'warm lamp', 'cool lamp', 'turning lamp', 'sky light', 'back light' }

-- each key steps through these on every shape; the first is how other scenes draw them
local TRIES = {
    g = { key = 'plasticineLightGain', name = 'swing', values = { 0, 0.3, 0.5 } },
    z = { key = 'plasticineLightZ', name = 'front', values = { 0.9, 0.6, 0.35 } },
    f = { key = 'plasticineFormRadius', name = 'quick form', values = { 0.08, 0.2, 0.35 } },
    b = { key = 'plasticineFormBaked', name = 'baked', values = { false, true } },
    n = { key = 'plasticineFormRise', name = 'rise', values = { 1, 0.5, 0.2 } },
    a = { key = 'plasticineLightAdd', name = 'adding up', values = { false, true } },
}
local TRY_ORDER = { 'a', 'g', 'z', 'f', 'b', 'n' }
-- o: the shapes' settings liked so far (and everything on, smooth clay wall, the cycle from 9:00)
local OPTIMAL_SHAPES = { a = true, g = 0.5, z = 0.35, f = 0.35, b = true, n = 1 }

local function lightOf(label)
    for _, thing in ipairs(getObjectsByLabel(label)) do
        for _, fixture in ipairs(thing.body:getFixtures()) do
            local ud = fixture:getUserData()
            if ud and ud.subtype == 'light' then return thing.body, ud.extra end
        end
    end
end

local function shapeExtras()
    local list = {}
    for _, thing in ipairs(getObjectsByLabel('lit box')) do
        for _, fixture in ipairs(thing.body:getFixtures()) do
            local ud = fixture:getUserData()
            if ud and ud.subtype == 'texfixture' then list[#list + 1] = ud.extra end
        end
    end
    return list
end

-- every Mipo part that takes the light: its picture parts, limb ribbons and torso skin (not the face's
-- decals: a face stays as drawn)
local LIT_PARTS = { texfixture = true, ['connected-texture'] = true, ['trace-vertices'] = true }
local function mipoExtras()
    local list = {}
    for _, body in ipairs(world:getBodies()) do
        local thing = body:getUserData() and body:getUserData().thing
        if thing and thing.mipoId then
            for _, fixture in ipairs(body:getFixtures()) do
                local ud = fixture:getUserData()
                if ud and LIT_PARTS[ud.subtype] and ud.extra and ud.extra.main then list[#list + 1] = ud.extra end
            end
        end
    end
    return list
end

local function current(try)
    local extra = shapeExtras()[1]
    local v = extra and extra[try.key]
    if v == nil then return try.values[1] end
    return v
end

local function setAll(try, v)
    for _, extra in ipairs(shapeExtras()) do extra[try.key] = v end
end

local function same(a, b)
    if a == b then return true end
    return tonumber(a) and tonumber(b) and math.abs(a - b) < 1e-6
end

local function step(try)
    local now, nextValue = current(try), try.values[1]
    for i, v in ipairs(try.values) do
        if same(v, now) then nextValue = try.values[i % #try.values + 1] end
    end
    setAll(try, nextValue)
end

-- the strongest of these lights that's on: its body
local function strongest(labels)
    local best, bestBody = 0, nil
    for _, label in ipairs(labels) do
        local body, extra = lightOf(label)
        if body and (extra.intensity or 1) > best then best, bestBody = extra.intensity or 1, body end
    end
    return bestBody
end

local function look()
    state.lightLab = state.lightLab or { hour = 12, made = 0, perSecond = 0, time = 0 }
    local c = state.lightLab
    c.hour = c.hour or 12 -- a state from before the clock
    return c
end

local function rgb(hex)
    return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
end

local function hex(c)
    local function byte(v) return math.floor(math.max(0, math.min(1, v)) * 255 + 0.5) end
    return string.format('%02x%02x%02xff', byte(c[1]), byte(c[2]), byte(c[3]))
end

local function mixColours(a, b, t)
    local ca, cb = rgb(a), rgb(b)
    return hex({ ca[1] + (cb[1] - ca[1]) * t, ca[2] + (cb[2] - ca[2]) * t, ca[3] + (cb[3] - ca[3]) * t })
end

-- two looks blended: numbers, colours (hex strings) and lists of them (no `type` in a scene script)
local function blend(a, b, t)
    if tonumber(a) == a then return a + (b - a) * t end
    local meta = getmetatable(a)
    if meta and meta.__index == string then return mixColours(a, b, t) end
    local out = {}
    for k, v in pairs(a) do out[k] = blend(v, b[k], t) end
    return out
end

-- the look at an hour (0..24)
local function lookAt(hour)
    for i = 1, #TIMELINE - 1 do
        local h0, h1 = TIMELINE[i][1], TIMELINE[i + 1][1]
        if hour >= h0 and hour <= h1 then
            local t = h1 > h0 and (hour - h0) / (h1 - h0) or 0
            t = t * t * (3 - 2 * t)
            return blend(LOOKS[TIMELINE[i][2]], LOOKS[TIMELINE[i + 1][2]], t)
        end
    end
    return LOOKS.night
end

-- where on the arc at theta (0 rising on the left, pi setting on the right), the way it shines (at the
-- scene's middle), and how much it's up (0 at the horizon or below, 1 well up)
local function onArc(theta)
    local x = ARC.x - ARC.r * math.cos(theta)
    local y = ARC.y - ARC.r * ARC.squash * math.sin(theta)
    local up = math.max(0, math.min(1, (math.sin(theta) + 0.05) / 0.2))
    return x, y, math.atan2(ARC.y - 200 - y, ARC.x - x), up * up * (3 - 2 * up)
end

local function setLight(label, colour, intensity, x, y, angle)
    local body, extra = lightOf(label)
    if not extra then return end
    if colour then extra.colorHex = colour end
    extra.intensity = intensity
    if x and body then body:setPosition(x, y) end
    if angle and body then body:setAngle(angle) end
end

-- The backdrop shadows: from the sun or the moon (whichever is stronger), else the turning lamp. By how
-- high it is on its arc: high, short and almost straight down, crisp; low, long and sideways, softer
-- (never up the wall). As strong as the leading light is stronger than the other, so the moon's fade out
-- and the sun's fade in at the handover, swapping sides while there's nothing to see (it jumped at 6:00;
-- and taken from where it aimed, the length stuck at its longest until 6:50). Returns the offset, the
-- blur and how much of the shadow's darkness is left (0..1).
local function wallShadow()
    local c = look()
    if c.lampOnly then
        local body = strongest({ 'turning lamp' })
        if not body then return nil end
        local a = body:getAngle()
        return { math.cos(a) * WALL_BEHIND, math.max(0, math.sin(a)) * WALL_BEHIND }, 10, 1
    end
    local _, sunExtra = lightOf('sun')
    local _, moonExtra = lightOf('moon')
    local sun, moon = sunExtra and sunExtra.intensity or 0, moonExtra and moonExtra.intensity or 0
    local theta = (sun >= moon) and (c.hour - 6) / 12 * math.pi or ((c.hour - 18) % 24) / 12 * math.pi
    local high = math.max(0, math.sin(theta))
    local length = WALL_BEHIND * math.min(4, 1 / (high + 0.25))
    local fade = math.min(1, math.abs(sun - moon) / 0.6)
    return { math.cos(theta) * length, high * length }, 5 + length * 0.06, fade
end

-- The 3D shadows' light: the sun or the moon (whichever leads, as the wall shadows; its way towards it on
-- the arc, a little out of the wall), or the warm lamp where it is, at the lamp's depth. Returns the light
-- and how much of the shadow's darkness is left.
-- e: which lights throw the 3D shadows; several, each its own shadow (Nikki 2026-11-06: the soft and the
-- hard together liked, then "lets try" shadows from more than one light)
local LIGHT_SETS = {
    { name = 'the sun or moon', sun = true },
    { name = 'the warm lamp', warm = true },
    { name = 'the sun or moon and the warm lamp', sun = true, warm = true },
    { name = 'the sun or moon and both lamps', sun = true, warm = true, cool = true },
}
local COOL_LAMP_DEPTH = 700 -- the cool lamp's distance in front of the things (the warm one's: [ ])

local function lightSet()
    local c = look()
    return LIGHT_SETS[c.lightSet or (c.solidLamp and 2) or 1]
end

-- a carried lamp as a 3D light: where it is on screen, `inFront` in front of the things
local function lampLight(label, inFront)
    local body = lightOf(label)
    if not body then return nil end
    local x, y = body:getPosition()
    local z = SOLID_DEPTH + inFront
    -- on screen the lamp sits at y = FLOOR_Y + z - h
    return { kind = 'point', x = x, h = math.max(4, FLOOR_Y + z - y), z = z }
end

-- The sun or the moon as a 3D light (whichever leads, as the wall shadows; its way towards it on the arc, a
-- little out of the wall), and how much of the shadow's darkness is left.
local function sunLight()
    local c = look()
    local _, sunExtra = lightOf('sun')
    local _, moonExtra = lightOf('moon')
    local sun, moon = sunExtra and sunExtra.intensity or 0, moonExtra and moonExtra.intensity or 0
    local theta = (sun >= moon) and (c.hour - 6) / 12 * math.pi or ((c.hour - 18) % 24) / 12 * math.pi
    local high = math.sin(theta)
    if high <= 0.02 then return nil end
    local towards = SUN_TOWARDS[c.sunTowards or 1]
    return { kind = 'sun', x = -math.cos(theta), h = high, z = towards }, math.min(1, math.abs(sun - moon) / 0.6)
end

-- every light of the set that's there, each with its shadow's strength and edge; with more than one a
-- little lighter each (where they cross, darker)
local function solidLights(wallShadows)
    local c = look()
    local set = lightSet()
    local soft = SOFTNESS[c.softness or 1]
    local list = {}
    if set.sun then
        local light, fade = sunLight()
        if light then
            list[#list + 1] = { light = light, strength = math.min(0.7, wallShadows * 1.5) * fade, softness = soft.sun }
        end
    end
    local lamps = { { set.warm, 'warm lamp', c.lampDepth or LAMP_DEPTH }, { set.cool, 'cool lamp', COOL_LAMP_DEPTH } }
    for _, lamp in ipairs(lamps) do
        local light = lamp[1] and lampLight(lamp[2], lamp[3])
        if light then list[#list + 1] = { light = light, strength = 0.55, softness = soft.lamp } end
    end
    if #list > 1 then
        for _, one in ipairs(list) do one.strength = one.strength * 0.75 end
    end
    return list
end

local function wallAboveFloor()
    love.graphics.rectangle('fill', WALL.x, WALL.y, WALL.w, FLOOR_Y - WALL.y)
end

local function solidArea()
    love.graphics.rectangle('fill', WALL.x, WALL.y, WALL.w, GROUND_TOP - WALL.y)
end

-- everything at the clock's hour (or only the turning lamp)
local function applyTime()
    local c = look()
    if c.lampOnly then
        for _, label in ipairs(LIGHTS) do setLight(label, nil, 0) end
        setLight('turning lamp', 'fff2d9ff', 1.0)
        c.now = nil
        return
    end
    local L = lookAt(c.hour)
    c.now = L
    local sx, sy, sa, sunUp = onArc((c.hour - 6) / 12 * math.pi)
    local mx, my, ma, moonUp = onArc(((c.hour - 18) % 24) / 12 * math.pi)
    setLight('sun', L.sun[1] .. 'ff', L.sun[2] * sunUp, sx, sy, sa)
    setLight('moon', L.moon[1] .. 'ff', L.moon[2] * moonUp, mx, my, ma)
    -- the warm lamp throwing the 3D shadows is on, whatever the hour
    local set = lightSet()
    setLight('warm lamp', nil, (c.solid and set.warm) and math.max(1.4, L.warm) or L.warm)
    setLight('cool lamp', nil, (c.solid and set.cool) and math.max(1.2, L.cool) or L.cool)
    setLight('turning lamp', nil, 0)
    setLight('sky light', L.skyLight[1] .. 'ff', c.skyOff and 0 or L.skyLight[3])
    local _, skyExtra = lightOf('sky light')
    if skyExtra then skyExtra.groundHex = L.skyLight[2] .. 'ff' end
    -- the back light comes from wherever the sun or the moon is (the stronger)
    local backAngle = (L.sun[2] * sunUp >= L.moon[2] * moonUp) and sa or ma
    setLight('back light', L.back[1] .. 'ff', c.backOff and 0 or L.back[2], nil, nil, backAngle)
end

function s.onStart()
    worldState.paused = false -- the turning lamp and the turf turn
    -- the carried lamps float where they're let go and push nothing
    for _, label in ipairs({ 'warm lamp', 'cool lamp' }) do
        for _, thing in ipairs(getObjectsByLabel(label)) do
            thing.body:setGravityScale(0)
            thing.body:setLinearDamping(4)
            thing.body:setFixedRotation(true)
            for _, fixture in ipairs(thing.body:getFixtures()) do fixture:setSensor(true) end
        end
    end
    applyTime()
    -- counting SpriteBatches made, per second (wrapped once; put back on unload)
    local c = look()
    if not c.original then
        c.original = love.graphics.newSpriteBatch
        love.graphics.newSpriteBatch = function(...)
            c.made = c.made + 1
            return c.original(...)
        end
    end
end

function s.onUnload()
    state.contactShadows = nil -- only in this scene
    state.backdropShadows = nil
    state.projectedShadows = nil
    state.drawSplits = nil
    local c = look()
    if c.original then
        love.graphics.newSpriteBatch = c.original
        c.original = nil
    end
end

-- the clay a plasticine surface also gets: grain, dents, sheen. On for the Mipos in this scene (Nikki
-- 2026-11-06); c takes it off: the light and the roundness only, the drawing's own strokes as they are
local CLAY_OFF = { plasticineStrength = 0, plasticineBump = 0, plasticineSpecStrength = 0, plasticineSSSstrength = 0 }

-- the Mipos lit like the shapes (a Mipo rebuilt from its DNA has new parts: set every frame)
local function lightMipos()
    local on, clay = not look().mipoLightOff, not look().mipoClayOff
    for _, extra in ipairs(mipoExtras()) do
        extra.plasticine = on or nil
        for _, k in ipairs(TRY_ORDER) do
            local try = TRIES[k]
            if on then extra[try.key] = current(try) else extra[try.key] = nil end
        end
        for key, v in pairs(CLAY_OFF) do
            if on and not clay then extra[key] = v else extra[key] = nil end
        end
    end
end

function s.update(dt)
    local c = look()
    local daySeconds = DAY_SPEEDS[c.daySpeed or 1] or DAY_SECONDS
    if c.cycle and not c.lampOnly then c.hour = (c.hour + (dt or 0) * 24 / daySeconds) % 24 end
    applyTime()
    lightMipos()
    local L = c.now or LAMP_ONLY
    state.contactShadows = not c.shadowsOff and { strength = L.shadows } or nil
    local offset, blur, fade = wallShadow()
    -- with the 3D shadows on too, the soft ones only on the wall above the floor, a little lighter:
    -- the two together (Nikki 2026-11-06: "combine multiple shadows")
    state.backdropShadows = (not c.wallShadowsOff and offset) and { wall = c.solid and wallAboveFloor or wallShape,
        offset = offset, blur = blur, strength = L.wallShadows * fade * (c.solid and 0.7 or 1) } or nil
    local lights = c.solid and solidLights(L.wallShadows) or {}
    state.drawSplits = c.solid and GROUND_SPLITS or nil
    state.projectedShadows = #lights > 0 and { area = solidArea, floorY = FLOOR_Y, depth = SOLID_DEPTH,
        lights = lights } or nil
    c.time = c.time + (dt or 0)
    if c.time >= 1 then
        c.perSecond, c.made, c.time = c.made, 0, c.time - 1
    end
end

function s.onKeyPress(key)
    local c = look()
    if HOUR_KEYS[key] then
        c.hour, c.lampOnly = HOUR_KEYS[key], false
    elseif key == '4' then
        c.lampOnly = true
    elseif key == 'd' then
        c.cycle, c.lampOnly = not c.cycle, false
    elseif key == ',' then
        c.hour = (c.hour - 1) % 24
    elseif key == '.' then
        c.hour = (c.hour + 1) % 24
    elseif TRIES[key] then
        step(TRIES[key])
    elseif key == '0' then
        for _, k in ipairs(TRY_ORDER) do setAll(TRIES[k], TRIES[k].values[1]) end
    elseif key == 'o' then
        -- everything built on, at the settings liked so far
        for _, k in ipairs({ 'lampOnly', 'skyOff', 'backOff', 'shadowsOff', 'wallShadowsOff', 'mipoLightOff',
            'mipoClayOff' }) do c[k] = nil end
        c.grit, c.hour, c.cycle = 2, 9, true
        for k, v in pairs(OPTIMAL_SHAPES) do setAll(TRIES[k], v) end
    elseif key == 'v' then
        c.solid = not c.solid
    elseif key == 'e' then
        c.lightSet = (c.lightSet or (c.solidLamp and 2) or 1) % #LIGHT_SETS + 1
    elseif key == '[' or key == ']' then
        local now, at = c.lampDepth or LAMP_DEPTH, 1
        for i, d in ipairs(LAMP_DEPTHS) do if d <= now then at = i end end
        at = math.max(1, math.min(#LAMP_DEPTHS, at + (key == ']' and 1 or -1)))
        c.lampDepth = LAMP_DEPTHS[at]
    elseif key == 't' then
        c.daySpeed = (c.daySpeed or 1) % #DAY_SPEEDS + 1
        c.cycle, c.lampOnly = true, false
    elseif key == 'y' then
        c.sunTowards = (c.sunTowards or 1) % #SUN_TOWARDS + 1
    elseif key == 'j' then
        c.softness = (c.softness or 1) % #SOFTNESS + 1
    elseif key == 'q' then
        look().grit = (look().grit or 2) % #GRITS + 1
    elseif key == 'w' then
        look().wallShadowsOff = not look().wallShadowsOff
    elseif key == 'h' then
        look().shadowsOff = not look().shadowsOff
    elseif key == 'm' then
        look().mipoLightOff = not look().mipoLightOff
    elseif key == 'c' then
        look().mipoClayOff = not look().mipoClayOff
    elseif key == 'l' then
        look().backOff = not look().backOff
    elseif key == 'k' then
        look().skyOff = not look().skyOff
    elseif key == 'r' then
        local _, extra = lightOf('turning lamp')
        if extra then extra.range = (extra.range or 500) == 500 and 5000 or 500 end
    elseif key == 's' then
        for _, thing in ipairs(getObjectsByLabel('spinning turf')) do
            local spinning = math.abs(thing.body:getAngularVelocity()) > 0
            thing.body:setAngularVelocity(spinning and 0 or 0.8)
        end
    end
end

-- the sky behind everything, in the hour's colour
function s.drawBelow()
    local now = look().now
    if not now then return end
    local sky = now.sky
    local x0, y0 = cam:getWorldCoordinates(0, 0)
    local x1, y1 = cam:getWorldCoordinates(love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(sky[1], sky[2], sky[3], 1)
    love.graphics.rectangle('fill', x0, y0, x1 - x0, y1 - y0)
    -- the back wall, the sky's light on it
    local c = WALL.colour
    love.graphics.setColor(c[1] * math.min(1, 0.2 + sky[1] * 0.9), c[2] * math.min(1, 0.2 + sky[2] * 0.9),
        c[3] * math.min(1, 0.2 + sky[3] * 0.9), 1)
    local grit = GRITS[look().grit or 2]
    if grit.grit then
        -- lit from wherever the sun or moon is (the way to it: against the way it shines)
        local body = strongest({ 'sun', 'moon' }) or strongest({ 'turning lamp' })
        local a = body and body:getAngle() or math.rad(60)
        local _, extra = lightOf((body and body:getUserData().thing or {}).label)
        local shader = plasterShader()
        love.graphics.setShader(shader)
        shader:send('grit', grit.grit)
        shader:send('scale', grit.scale)
        shader:send('relief', grit.relief)
        shader:send('sheen', grit.sheen)
        shader:send('toLight', { -math.cos(a), -math.sin(a) })
        shader:send('lit', math.min(1, extra and extra.intensity or 0))
        local ox, oy = cam:getWorldCoordinates(0, 0)
        local oneRight = cam:getWorldCoordinates(1, 0)
        shader:send('origin', { ox, oy })
        shader:send('zoom', 1 / (oneRight - ox))
    end
    wallShape()
    love.graphics.setShader()
    if look().solid then
        -- the floor behind the things, in the same light as the wall (the shadows land on it)
        local tint = groundTint()
        drawEarth(FLOOR_Y, GROUND_TOP, tint)
        drawRims('corner', tint)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function hexColor(text)
    local c = rgb(text)
    return c[1], c[2], c[3]
end

-- each light that's on: a glow in its colour, and (directional) the way it shines
function s.draw()
    for _, label in ipairs(LIGHTS) do
        local body, extra = lightOf(label)
        if body and (extra.intensity or 1) > 0 and extra.lightType ~= 'sky' and extra.lightType ~= 'back' then
            local x, y = body:getPosition()
            local r, g, b = hexColor(extra.colorHex or 'ffffffff')
            for k = 4, 1, -1 do
                love.graphics.setColor(r, g, b, 0.12 * (extra.intensity or 1))
                love.graphics.circle('fill', x, y, 30 + k * 28)
            end
            love.graphics.setColor(r, g, b, 1)
            love.graphics.circle('fill', x, y, 26)
            if extra.lightType ~= 'point' and label ~= 'sun' and label ~= 'moon' then
                local a = body:getAngle()
                love.graphics.setLineWidth(8)
                love.graphics.line(x, y, x + math.cos(a) * 260, y + math.sin(a) * 260)
                love.graphics.setLineWidth(1)
            end
        end
    end
    -- each stone's and the fence's roughness, small under it
    local font = love.graphics.getFont()
    for _, label in ipairs({ 'lit box', 'fence post' }) do
        for _, thing in ipairs(getObjectsByLabel(label)) do
            for _, fixture in ipairs(thing.body:getFixtures()) do
                local ud = fixture:getUserData()
                if ud and ud.extra and ud.extra.roughness and (label ~= 'fence post' or thing.body:getX() > 1400) then
                    local x = thing.body:getX()
                    local text = ud.extra.roughness
                    love.graphics.setColor(0, 0, 0, 0.6)
                    love.graphics.print(text, x - font:getWidth(text) * 1.25 + 3, 540 + 3, 0, 2.5, 2.5)
                    love.graphics.setColor(1, 0.97, 0.9, 1)
                    love.graphics.print(text, x - font:getWidth(text) * 1.25, 540, 0, 2.5, 2.5)
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local c = look()
    local tries = {}
    for _, k in ipairs(TRY_ORDER) do
        tries[#tries + 1] = string.format('%s %s %s', k, TRIES[k].name, tostring(current(TRIES[k])))
    end
    local lines = {
        'd day-night  , . hour  1 day 2 dusk 3 night 4 lamp  k sky  l back  h shadows  w wall  q grit  m Mipos  c clay',
        'now: ' .. (c.lampOnly and 'the turning lamp'
            or string.format('%02d:%02d%s', math.floor(c.hour), math.floor(c.hour % 1 * 60),
                c.cycle and string.format(' (cycle, a day in %ds, t)', DAY_SPEEDS[c.daySpeed or 1]) or ''))
            .. (c.skyOff and ', sky light off' or ', sky light on')
            .. (c.shadowsOff and ', no shadows' or ', shadows')
            .. (c.wallShadowsOff and ', none on the wall' or ', on the wall')
            .. ', wall ' .. GRITS[c.grit or 2].name
            .. (c.backOff and ', no back light' or ', back light')
            .. (c.mipoLightOff and ', Mipos as drawn'
                or (c.mipoClayOff and ', Mipos lit, no clay' or ', Mipos lit, clay'))
            .. '      shapes: ' .. table.concat(tries, '   ') .. '   (0 as elsewhere)',
        'v 3D shadows: ' .. (c.solid and ('on, from ' .. lightSet().name
            .. (lightSet().warm and string.format(', warm lamp %d in front', c.lampDepth or LAMP_DEPTH) or '')
            .. (lightSet().sun and string.format(', sun %.2f out of the wall', SUN_TOWARDS[c.sunTowards or 1]) or '')
            .. ', ' .. SOFTNESS[c.softness or 1].name) or 'off')
            .. '   (e which lights  y sun out of the wall  [ ] lamp depth  j edges)',
        string.format('grass: SpriteBatches made in the last second: %d', c.perSecond),
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

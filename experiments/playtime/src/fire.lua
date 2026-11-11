-- fire.lua — a campfire: flame tongues that rise and flicker, a warm glow round them, two logs with
-- embers, sparks drifting up, and a flicker for the fire's real light (Nikki 2026-11-11: "a fire, like
-- campfire, but with good light and flame"). Drawn, not a shader. Two styles (f.style):
-- 'drawn' (the default; Nikki: "weird shapes and blending", "drawn textures we already have"): licks made of
-- Nikki's drawn pictures, the grass blades (textures/world/sprieten.png, src/grass.lua's quads) and the
-- plants' petal and oval masks, rising from the logs, stretching, swaying, white-yellow -> orange -> dark
-- red -> gone, all added on: where they pile up the core goes near white, the edges stay ragged.
-- 'tongues': each tongue a shape of noise-driven points, in layers from a red-orange rim to a yellow-white
-- core. The light itself is the scene's (a LIGHT sfixture, src/render/shaders.lua): lib.light gives where
-- it is and how strong this frame. A fire is a plain table the caller keeps (on `state`: a hot swap
-- keeps it).
local lib = {}

-- each tongue: its place across the base (of the size), how tall, how wide, its own noise
local TONGUES = {
    { x = 0.00, h = 1.00, w = 0.55 },
    { x = -0.26, h = 0.68, w = 0.42 },
    { x = 0.28, h = 0.74, w = 0.40 },
    { x = -0.12, h = 0.86, w = 0.36 },
    { x = 0.14, h = 0.90, w = 0.34 },
    { x = -0.36, h = 0.45, w = 0.30 },
    { x = 0.38, h = 0.50, w = 0.30 },
}
-- the layers, outside in: how much of the tongue (width, height), colour, added on or laid over
local LAYERS = {
    { w = 1.00, h = 1.00, colour = { 0.86, 0.22, 0.06, 0.85 }, add = false },
    { w = 0.78, h = 0.86, colour = { 1.00, 0.48, 0.10, 0.90 }, add = false },
    { w = 0.55, h = 0.66, colour = { 1.00, 0.78, 0.28, 0.75 }, add = true },
    { w = 0.30, h = 0.42, colour = { 1.00, 0.96, 0.78, 0.70 }, add = true },
}
local POINTS = 9 -- per side of a tongue

local function noise(...) return love.math.noise(...) end

-- x, y: the middle of the fire's base (where the logs cross); size: how tall the biggest tongue stands
function lib.new(x, y, size)
    return { x = x, y = y, size = size or 300, t = math.random() * 100, sparks = {}, sparkClock = 0,
        flicker = 1, lightX = x, lightY = y, style = 'drawn', licks = {}, lickClock = 0 }
end

lib.STYLES = { 'drawn', 'tongues' }

---------------------------------------------------------------- the drawn licks

local BLOBS = { 'textures/plants/petal-01-mask.png', 'textures/plants/petal-03-mask.png',
    'textures/plants/petal-05-mask.png', 'textures/plants/oval-01-mask.png', 'textures/plants/oval-03-mask.png' }
local LICKS_PER_SECOND = 46 -- blades; the blobs half as many
local images -- { blades = image, quads = { quad, pivotX, pivotY, w, h }, blobs = { image } }, loaded once
local function pictures()
    if images then return images end
    local grass = require('src.grass')
    local atlas = love.graphics.newImage(grass.ATLAS)
    local quads = {}
    for _, q in ipairs(grass.QUADS) do
        quads[#quads + 1] = { quad = love.graphics.newQuad(q[1], q[2], q[3], q[4], atlas:getDimensions()),
            px = q[5], py = q[6], w = q[3], h = q[4] }
    end
    local blobs = {}
    for _, path in ipairs(BLOBS) do
        if love.filesystem.getInfo(path) then blobs[#blobs + 1] = love.graphics.newImage(path) end
    end
    images = { blades = atlas, quads = quads, blobs = blobs }
    return images
end

-- a little around the middle, more often near it
local function spread() return (math.random() + math.random() + math.random() - 1.5) / 1.5 end

local function newLick(f, blob)
    local size = f.size
    local p = pictures()
    local lick = {
        blob = blob, life = 0, seed = math.random() * 100,
        x = f.x + spread() * size * (blob and 0.3 or 0.46), y = f.y - size * (blob and 0.12 or 0.04),
        lean = spread() * 0.35, spin = (math.random() - 0.5) * 0.8,
    }
    if blob then
        lick.image = p.blobs[math.random(#p.blobs)]
        lick.maxLife = 0.45 + math.random() * 0.4
        lick.vy = -size * (1.1 + math.random() * 0.6)
        lick.r = size * (0.12 + math.random() * 0.1)
    else
        lick.q = p.quads[math.random(#p.quads)]
        lick.maxLife = 0.4 + math.random() * 0.45
        lick.vy = -size * (0.35 + math.random() * 0.45)
        lick.h = size * (0.55 + math.random() * 0.55) * (1 - 0.6 * math.abs(lick.x - f.x) / size)
        lick.w = size * (0.22 + math.random() * 0.18)
        lick.flip = math.random() < 0.5 and -1 or 1
    end
    return lick
end

local function updateLicks(f, dt)
    f.lickClock = f.lickClock + dt * LICKS_PER_SECOND * f.flicker
    while f.lickClock >= 1 do
        f.lickClock = f.lickClock - 1
        f.licks[#f.licks + 1] = newLick(f, false)
        if math.random() < 0.5 then f.licks[#f.licks + 1] = newLick(f, true) end
    end
    for i = #f.licks, 1, -1 do
        local l = f.licks[i]
        l.life = l.life + dt
        if l.life >= l.maxLife then
            table.remove(f.licks, i)
        else
            -- the draft: everything sways together, each a little its own way
            local sway = (noise(f.t * 1.3, 2.2) - 0.5) * 0.9 + (noise(l.seed, f.t * 3) - 0.5) * 0.5
            l.x = l.x + sway * f.size * 0.6 * dt
            l.y = l.y + l.vy * dt
            l.sway = sway
        end
    end
end

-- white-yellow at birth, orange, dark red, then gone
local RAMP = { { 0, 1, 0.82, 0.42 }, { 0.22, 1, 0.55, 0.14 }, { 0.55, 0.9, 0.26, 0.05 }, { 1, 0.42, 0.05, 0.02 } }
local function rampAt(k)
    for i = 2, #RAMP do
        local a, b = RAMP[i - 1], RAMP[i]
        if k <= b[1] then
            local t = (k - a[1]) / (b[1] - a[1])
            return a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] + (b[4] - a[4]) * t
        end
    end
    return RAMP[#RAMP][2], RAMP[#RAMP][3], RAMP[#RAMP][4]
end

-- A shared noise picture (tiling well enough: the fire is small next to it), made once.
local noiseImage
local function noisePicture()
    if noiseImage then return noiseImage end
    local n = 256
    local data = love.image.newImageData(n, n)
    for y = 0, n - 1 do
        for x = 0, n - 1 do
            local v = 0.65 * noise(x / 28, y / 28) + 0.35 * noise(x / 9 + 50, y / 9 + 50)
            data:setPixel(x, y, v, v, v, 1)
        end
    end
    noiseImage = love.graphics.newImage(data)
    noiseImage:setWrap('repeat', 'repeat')
    return noiseImage
end

-- Erosion (the stylized-fire way, docs: realtimevfx / vfxdoc 'alpha erosion'): a lick isn't faded but burnt
-- away from its edges inwards, its drawn picture times a noise field that scrolls up through the whole
-- fire (world space, so the licks share one draft), cut at a threshold that rises with its age; just
-- inside the cut a hot rim. The colour comes in the vertex colour (added on, so pre-multiplied), the
-- threshold in its alpha. bands > 0: the cut in that many flat steps (the hand-animated look).
local eroder
local function eroderShader()
    eroder = eroder or love.graphics.newShader([[
        uniform Image noiseTex;
        uniform vec2 origin;     // world point at the screen's top left
        uniform float perPixel;  // world units per screen pixel
        uniform float noiseSize; // world units one noise picture covers
        uniform float time;
        uniform float bands;
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
            vec4 p = Texel(tex, uv);
            float mask = p.a * dot(p.rgb, vec3(0.3333)); // the drawing (masks: white on black)
            vec2 w = (origin + sc * perPixel) / noiseSize;
            float n = Texel(noiseTex, w + vec2(0.0, time * 0.9)).r * 0.65
                    + Texel(noiseTex, w * 2.3 + vec2(0.37, time * 1.7)).r * 0.35;
            float v = mask * (0.3 + 0.7 * n);
            float cut = color.a;
            float soft = 0.07;
            float body = smoothstep(cut, cut + soft, v);
            if (bands > 0.0) body = floor(body * bands + 0.5) / bands;
            float rim = body * (1.0 - smoothstep(cut + soft, cut + soft * 3.0, v));
            vec3 c = color.rgb * body + vec3(1.0, 0.85, 0.5) * rim * 0.35 * length(color.rgb);
            return vec4(c, 1.0);
        }
    ]])
    return eroder
end

-- how far a lick is burnt away at age k (0..1): it grows in out of noisy bits, then burns away
local function erosionAt(k)
    if k < 0.12 then return 0.75 - 0.7 * (k / 0.12) end
    return 0.05 + 0.85 * ((k - 0.12) / 0.88) ^ 1.3
end

local function drawLicks(f)
    local p = pictures()
    local shader = eroderShader()
    local ox, oy = love.graphics.inverseTransformPoint(0, 0)
    local x1 = love.graphics.inverseTransformPoint(1, 0)
    local perPixel = math.abs(x1 - ox) / love.graphics.getDPIScale()
    local time = f.t
    if (f.fps or 0) > 0 then time = math.floor(time * f.fps) / f.fps end -- a flipbook's few frames a second
    love.graphics.setShader(shader)
    shader:send('noiseTex', noisePicture())
    shader:send('origin', { ox, oy })
    shader:send('perPixel', perPixel)
    shader:send('noiseSize', f.size * 0.9)
    shader:send('time', time * 0.35)
    shader:send('bands', f.bands or 0)
    love.graphics.setBlendMode('add')
    for _, l in ipairs(f.licks) do
        local k = l.life / l.maxLife
        local r, g, b = rampAt(k)
        local cut = erosionAt(k)
        if l.blob then
            local a = 0.22
            love.graphics.setColor(r * a, g * a, b * a, cut)
            local img = l.image
            local s = l.r * (1 - 0.6 * k) * 2 / img:getWidth()
            love.graphics.draw(img, l.x, l.y, l.spin * k + (l.sway or 0) * 0.3, s, s * 1.3,
                img:getWidth() / 2, img:getHeight() / 2)
        else
            local a = 0.5
            love.graphics.setColor(r * a, g * a, b * a, cut)
            local q = l.q
            local h = l.h * (0.7 + 0.8 * k) -- stretching as it goes up
            local w = l.w * (1 - 0.55 * k)
            love.graphics.draw(p.blades, q.quad, l.x, l.y, l.lean + (l.sway or 0) * 0.35 * k,
                l.flip * w / q.w, h / q.h, q.px, q.py)
        end
    end
    love.graphics.setShader()
    love.graphics.setBlendMode('alpha')
    love.graphics.setColor(1, 1, 1, 1)
end

function lib.update(f, dt)
    f.t = f.t + dt
    local t = f.t
    -- how bright this frame: a slow breath and a quick flutter
    f.flicker = 0.82 + 0.26 * noise(t * 2.1, 3.7) + 0.10 * noise(t * 9.3, 8.1)
    if f.style == 'drawn' then updateLicks(f, dt) end
    -- the light wanders a little with the flames
    f.lightX = f.x + (noise(t * 1.4, 1.1) - 0.5) * f.size * 0.18
    f.lightY = f.y - f.size * (0.42 + 0.08 * noise(t * 1.9, 5.5))
    -- sparks
    f.sparkClock = f.sparkClock + dt * 14 * f.flicker
    while f.sparkClock >= 1 do
        f.sparkClock = f.sparkClock - 1
        f.sparks[#f.sparks + 1] = {
            x = f.x + (math.random() - 0.5) * f.size * 0.45, y = f.y - f.size * (0.2 + math.random() * 0.3),
            vx = (math.random() - 0.5) * f.size * 0.25, vy = -f.size * (0.8 + math.random() * 0.9),
            life = 0, maxLife = 0.8 + math.random() * 1.2, r = f.size * (0.008 + math.random() * 0.012),
            seed = math.random() * 100,
        }
    end
    for i = #f.sparks, 1, -1 do
        local s = f.sparks[i]
        s.life = s.life + dt
        if s.life >= s.maxLife then
            table.remove(f.sparks, i)
        else
            s.vx = s.vx + (noise(s.seed, f.t * 2) - 0.5) * f.size * 2.5 * dt -- they drift and swirl
            s.vy = s.vy * (1 - 0.6 * dt)
            s.x, s.y = s.x + s.vx * dt, s.y + s.vy * dt
        end
    end
end

-- where the fire's light is and how strong (times its own strength)
function lib.light(f) return f.lightX, f.lightY, f.flicker end

---------------------------------------------------------------- drawing

local disc
local function glowDisc()
    if disc then return disc end
    local verts = { { 0, 0, 0.5, 0.5, 1, 1, 1, 1 } }
    for i = 0, 40 do
        local a = i / 40 * math.pi * 2
        verts[#verts + 1] = { math.cos(a), math.sin(a), 0.5, 0.5, 1, 1, 1, 0 }
    end
    disc = love.graphics.newMesh(verts, 'fan', 'static')
    return disc
end

-- one tongue's outline at this moment, a layer of it (wf, hf: how much of its width and height)
local function tongue(f, k, tg, wf, hf, out)
    local t, size = f.t, f.size
    local speed = 1.6 + k * 0.17
    local height = size * tg.h * hf * (0.75 + 0.45 * noise(t * speed, k * 3.1))
    local lean = (noise(t * 0.9, k * 7.3) - 0.5) * 0.7 * height
    local width = size * tg.w * wf
    local baseX, baseY = f.x + tg.x * size, f.y
    local n = 0
    local function point(side, s)
        -- the middle sways more higher up, a ripple runs up it
        local cx = baseX + lean * s * s + math.sin(t * 7 + s * 6 + k) * size * 0.035 * s
        local half = width * 0.5 * (1 - s) ^ 0.9 * (s < 0.2 and (0.65 + 1.75 * s) or 1)
        n = n + 2
        out[n - 1], out[n] = cx + side * half, baseY - height * s
    end
    for i = 0, POINTS - 1 do point(-1, i / POINTS) end
    n = n + 2
    out[n - 1], out[n] = baseX + lean, baseY - height -- the tip
    for i = POINTS - 1, 0, -1 do point(1, i / POINTS) end
    for i = n + 1, #out do out[i] = nil end
    return out
end

local scratch = {}
local function fillShape(points)
    local ok, tris = pcall(love.math.triangulate, points)
    if not ok then return end
    for _, tri in ipairs(tris) do love.graphics.polygon('fill', tri) end
end

-- the logs, crossed, charred at their ends, glowing where they burn
-- The firewood (Nikki 2026-11-11: "more organic, drawn tree trunk, firewood"): a tipi of logs leaning in over
-- the fire, two behind the flames and two in front, and one lying across the front. Each log an organic
-- shape (an outline that wobbles, tapers, has a knot and sometimes a branch stub), filled with bark
-- (textures/world/bark, the trees' CC0 scans, coarse), charred and glowing in its cracks the nearer the
-- fire's heart it is (the vertex alpha carries that heat), outlined in Nikki's crayon (src/drawn-stroke.lua).
-- The lying log's cut end shows its end grain.
local BARK = 'textures/world/bark/bark-07.jpg'
local barkImage
local function barkPicture()
    if barkImage == nil then
        barkImage = love.filesystem.getInfo(BARK) and love.graphics.newImage(BARK) or false
        if barkImage then barkImage:setWrap('repeat', 'repeat') end
    end
    return barkImage or nil
end

local burner
local function burnerShader()
    burner = burner or love.graphics.newShader([[
        uniform Image noiseTex;
        uniform float time;
        uniform float heat;
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
            vec3 c = Texel(tex, uv).rgb;
            float lum = dot(c, vec3(0.3, 0.59, 0.11));
            float hot = color.a;                      // 0 away from the fire .. 1 in its heart
            float charred = smoothstep(0.2, 0.85, hot);
            vec3 wood = mix(c * vec3(0.8, 0.6, 0.42), c * 0.26, charred);
            wood += vec3(0.24, 0.1, 0.03) * heat * hot; // the fire's light on it
            float crack = smoothstep(0.32, 0.1, lum) * charred;
            float n = Texel(noiseTex, vec2(uv.x * 0.6, uv.y * 0.25 + time * 0.12)).r;
            float glow = crack * (0.35 + n) * heat;
            return vec4(wood + vec3(1.0, 0.38, 0.08) * glow * 1.6, 1.0);
        }
    ]])
    return burner
end

-- a log's outline, along x from 0 to len, thick across (local; its base end at 0)
local function logOutline(len, thick, seed, stub)
    local top, bottom = {}, {}
    local n = 14
    local knot = 0.3 + 0.4 * noise(seed, 1.7)
    for i = 0, n do
        local s = i / n
        local half = thick / 2 * (1 - 0.25 * s) -- tapering
        half = half * (1 + 0.18 * math.exp(-((s - knot) / 0.07) ^ 2)) -- a knot
        local wt = (noise(seed + s * 3.1, 4.2) - 0.5) * thick * 0.16
        local wb = (noise(seed + s * 2.7, 9.6) - 0.5) * thick * 0.16
        top[#top + 1] = { s * len, -half + wt }
        bottom[#bottom + 1] = { s * len, half + wb }
    end
    local pts = {}
    for _, p in ipairs(top) do pts[#pts + 1] = p end
    -- the far end, a little round
    local endHalf = thick / 2 * 0.75
    for k = 1, 3 do
        local a = -math.pi / 2 + k * math.pi / 4
        pts[#pts + 1] = { len + math.cos(a) * endHalf * 0.25, math.sin(a) * endHalf }
    end
    for i = #bottom, 1, -1 do pts[#pts + 1] = bottom[i] end
    for k = 1, 3 do
        local a = math.pi / 2 + k * math.pi / 4
        pts[#pts + 1] = { math.cos(a) * thick / 2 * 0.25, math.sin(a) * thick / 2 }
    end
    local flat = {}
    for _, p in ipairs(pts) do flat[#flat + 1] = p[1]; flat[#flat + 1] = p[2] end
    local stubPts
    if stub then -- a short branch stub off its top, leaning towards the far end
        local s0 = 0.45 + 0.2 * noise(seed, 6.6)
        local x0, w = s0 * len, thick * 0.32
        stubPts = { x0 - w / 2, -thick * 0.38, x0 + w * 0.9, -thick * 0.95, x0 + w * 1.5, -thick * 0.82,
            x0 + w / 2, -thick * 0.38 }
    end
    return flat, stubPts
end

-- the firewood round a fire, made once per fire (local to the fire's base: x across, y down)
local function makeWood(f)
    local size = f.size
    local apexX, apexY = 0, -size * 0.78
    local thick = size * 0.15
    local wood = {}
    local function lean(bx, layer, seed, stub)
        local dx, dy = apexX - bx, apexY - 0
        local len = math.sqrt(dx * dx + dy * dy) * 1.12 -- a little past the point where they meet
        wood[#wood + 1] = { x = bx, y = 0, angle = math.atan2(dy, dx), len = len,
            thick = thick * (0.85 + 0.3 * noise(seed, 3)), layer = layer, seed = seed, stub = stub }
    end
    lean(-size * 0.5, 'back', 11.3, true)
    lean(size * 0.46, 'back', 23.9, false)
    lean(-size * 0.26, 'front', 37.1, false)
    lean(size * 0.3, 'front', 41.7, true)
    -- one lying across the front, its cut end towards you on the right
    wood[#wood + 1] = { x = -size * 0.62, y = -thick * 0.35, angle = -0.06, len = size * 1.25,
        thick = thick * 1.15, layer = 'front', seed = 55.5, stub = false, cutEnd = true }
    for _, log in ipairs(wood) do
        log.outline, log.stubPts = logOutline(log.len, log.thick, log.seed, log.stub)
    end
    return wood
end

-- a log's fill: its outline triangulated, bark across (coarse) and along, the heat per vertex from how
-- near the fire's heart it is (world: the fire's base and size)
local function logMesh(f, log)
    if log.mesh then return log.mesh end
    local ok, tris = pcall(love.math.triangulate, log.outline)
    if not ok then return nil end
    local verts = {}
    local hx, hy = 0, -f.size * 0.28 -- the heart, local to the fire's base
    local c, s = math.cos(log.angle), math.sin(log.angle)
    local function add(px, py)
        local wx, wy = log.x + px * c - py * s, log.y + px * s + py * c
        local d = math.sqrt((wx - hx) ^ 2 + (wy - hy) ^ 2) / (f.size * 0.6)
        local hot = math.max(0, math.min(1, 1.15 - d))
        verts[#verts + 1] = { px, py, (py / log.thick) * 0.35 + 0.5, px / (log.thick * 3.2), 1, 1, 1, hot }
    end
    for _, tri in ipairs(tris) do
        add(tri[1], tri[2]); add(tri[3], tri[4]); add(tri[5], tri[6])
    end
    if log.stubPts then
        local okS, stubTris = pcall(love.math.triangulate, log.stubPts)
        if okS then
            for _, tri in ipairs(stubTris) do add(tri[1], tri[2]); add(tri[3], tri[4]); add(tri[5], tri[6]) end
        end
    end
    log.mesh = love.graphics.newMesh(verts, 'triangles', 'static')
    return log.mesh
end

-- its crayon outline (Nikki's strokes), made once
local strokes
local function logStrokes(log)
    if log.strokes then return log.strokes end
    strokes = strokes or require('src.drawn-stroke')
    local pts = {}
    for i = 1, #log.outline, 2 do pts[#pts + 1] = { log.outline[i], log.outline[i + 1] } end
    local lines = { { pts = pts, loop = true, width = log.thick * 0.09 } }
    if log.stubPts then
        local sp = {}
        for i = 1, #log.stubPts, 2 do sp[#sp + 1] = { log.stubPts[i], log.stubPts[i + 1] } end
        lines[#lines + 1] = { pts = sp, loop = false, width = log.thick * 0.07 }
    end
    log.strokes = strokes.meshes(lines, 1.1, 0, true)
    return log.strokes
end

-- a cut end: a lighter face with rings, its rim dark
local function drawEndGrain(log)
    local r = log.thick / 2 * 0.75
    local x = log.len
    love.graphics.setColor(0.62, 0.46, 0.3, 1)
    love.graphics.ellipse('fill', x, 0, r * 0.42, r)
    love.graphics.setColor(0.42, 0.29, 0.18, 1)
    love.graphics.setLineWidth(r * 0.08)
    for k = 1, 3 do love.graphics.ellipse('line', x, 0, r * 0.42 * k / 4, r * k / 4) end
    love.graphics.setColor(0.18, 0.11, 0.07, 1)
    love.graphics.setLineWidth(r * 0.14)
    love.graphics.ellipse('line', x, 0, r * 0.42, r)
    love.graphics.setLineWidth(1)
end

local function drawLogs(f, layer)
    f.wood = f.wood or makeWood(f)
    local bark = barkPicture()
    local shader = burnerShader()
    for _, log in ipairs(f.wood) do
        if log.layer == layer then
            love.graphics.push()
            love.graphics.translate(f.x + log.x, f.y + log.y)
            love.graphics.rotate(log.angle)
            local mesh = bark and logMesh(f, log)
            if mesh then
                mesh:setTexture(bark)
                love.graphics.setShader(shader)
                shader:send('noiseTex', noisePicture())
                shader:send('time', f.t)
                shader:send('heat', f.flicker)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(mesh)
                love.graphics.setShader()
            end
            if log.cutEnd then drawEndGrain(log) end
            love.graphics.setColor(0.13, 0.08, 0.05, 1)
            for _, m in ipairs(logStrokes(log)) do love.graphics.draw(m) end
            love.graphics.pop()
        end
    end
    if layer == 'front' then
        -- embers at the foot: soft glows breathing
        local size = f.size
        love.graphics.setBlendMode('add')
        for i = 1, 6 do
            local glow = 0.4 + 0.6 * noise(f.t * 1.8, i * 4.2)
            local a = 0.35 * glow
            love.graphics.setColor(1 * a, 0.42 * a, 0.1 * a, 1)
            love.graphics.draw(glowDisc(), f.x + (i - 3.5) * size * 0.08, f.y - size * 0.02, 0,
                size * 0.09, size * 0.05)
        end
        love.graphics.setBlendMode('alpha')
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- behind the flames: the glow round the fire, and its pool on the ground (dark: 0 by day .. 1 at night)
function lib.drawGlow(f, dark)
    dark = dark or 1
    love.graphics.setBlendMode('add')
    local a = (0.18 + 0.22 * dark) * f.flicker
    love.graphics.setColor(1 * a, 0.55 * a, 0.2 * a, 1)
    love.graphics.draw(glowDisc(), f.x, f.y - f.size * 0.5, 0, f.size * 2.6, f.size * 2.2)
    local p = (0.10 + 0.25 * dark) * f.flicker
    love.graphics.setColor(1 * p, 0.6 * p, 0.25 * p, 1)
    love.graphics.draw(glowDisc(), f.x, f.y + f.size * 0.05, 0, f.size * 3.2, f.size * 0.55)
    love.graphics.setBlendMode('alpha')
    love.graphics.setColor(1, 1, 1, 1)
end

local drawTongues, drawSparks -- below

function lib.draw(f)
    drawLogs(f, 'back') -- the tipi's far logs, behind the flames
    if f.style == 'drawn' then
        drawLicks(f)
    else
        drawTongues(f)
    end
    -- the near logs over the flames' foot: the fire comes up from inside the tipi
    love.graphics.setBlendMode('alpha')
    drawLogs(f, 'front')
    drawSparks(f)
end

drawTongues = function(f)
    for li, layer in ipairs(LAYERS) do
        love.graphics.setBlendMode(layer.add and 'add' or 'alpha')
        local c = layer.colour
        local alpha = c[4] * (layer.add and math.min(1, f.flicker) or 1)
        love.graphics.setColor(c[1], c[2], c[3], alpha)
        for k, tg in ipairs(TONGUES) do
            if li <= 2 or tg.h > 0.6 then -- the small side tongues have no bright core
                fillShape(tongue(f, k, tg, layer.w, layer.h, scratch))
            end
        end
    end
end

drawSparks = function(f)
    -- sparks: bright when new, redder and smaller as they go
    love.graphics.setBlendMode('add')
    for _, s in ipairs(f.sparks) do
        local k = s.life / s.maxLife
        love.graphics.setColor(1, 0.85 - 0.5 * k, 0.4 - 0.35 * k, 1 - k)
        love.graphics.circle('fill', s.x, s.y, s.r * (1 - 0.6 * k))
    end
    love.graphics.setBlendMode('alpha')
    love.graphics.setColor(1, 1, 1, 1)
end

return lib

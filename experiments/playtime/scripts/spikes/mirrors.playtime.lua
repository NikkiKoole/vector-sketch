-- mirrors: a garden with mirrors and a pond that reflects, and ways to break up the reflection.
-- The picture is built in layers: the background (sky, hills, the wall, the ground) into one canvas,
-- the bodies and Mipos into a second; the two put together are what the mirrors see. The mirrors'
-- faces then draw onto the background, the bodies over them (a Mipo stands in front of the wall
-- mirror), and that whole picture is what the pond sees. So the pond shows the mirrors too.
-- A mirror flips what's around it across its long axis; `zoom` makes it convex (a wall mirror shows
-- a bit more than itself, the gazing ball the whole garden), the funhouse mirror wobbles.
-- The pond is the 2D-game kind of water mirror (what's above flipped under the surface line,
-- fading into the see-through water with depth), broken up by: a row of wave columns (the surface
-- line goes up and down), rings (a squashed circle per hit: seen at a slant they spread sideways
-- more than down), and wind (a choppy surface smears the reflection).
--
-- play mode (tab): press on the water and drag to stir it; throw things in.
-- keys: k skim a stone (from the mouse, towards the pond)   d drop a pebble   n rain on/off
--       m a Mipo   o a ball   g a hand mirror   r reset   h the panel

local s = {}

local GROUND_Y = 0           -- the grass
local SURF_Y = 70            -- the still water, a bit under the grass
local P1, P2 = -500, 1500    -- the pond
local POND_DEEP = 620
local DX = 25                -- between surface columns
local COLS = math.floor((P2 - P1) / DX)
local LEFT, RIGHT = -4200, 4600
local RING_MAX = 24

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

-- Kept on state so a hot reload keeps the pond and what's in it.
local function pond()
    local b = state.mirrors or {}
    state.mirrors = b
    b.h = b.h or {}
    b.v = b.v or {}
    b.surf = b.surf or {}
    b.rings = b.rings or {}
    b.drops = b.drops or {}
    b.stones = b.stones or {}
    b.props = b.props or {}
    b.mipos = b.mipos or {}
    b.wet = b.wet or {}
    b.time = b.time or 0
    b.settings = b.settings or {}
    local defaults = {
        reflect = 1, fade = 1, ripples = 1, wind = 0.15, rain = 0, clarity = 1, zoom = 1, wobble = 1,
    }
    for key, v in pairs(defaults) do
        if b.settings[key] == nil then b.settings[key] = v end
    end
    if b.showPanel == nil then b.showPanel = true end
    return b
end

-- the ground's top: flat grass, a bowl for the pond with soft banks
local function groundAt(x)
    if x <= P1 or x >= P2 then return GROUND_Y end
    local u = (x - P1) / (P2 - P1)
    local e = math.abs(2 * u - 1)
    local bowl = 1 - e * e * e * e * e * e
    return GROUND_Y + (POND_DEEP + 40) * bowl + 40 * (love.math.noise(u * 6, 2.3) - 0.5) * bowl
end

local function colX(i) return P1 + i * DX end

-- columns that are water (the banks above the surface aren't)
local wetCol = {}
for i = 0, COLS do wetCol[i] = groundAt(colX(i)) > SURF_Y + 10 end

local function inPond(x) return x > P1 and x < P2 end

local function surfaceAt(b, x)
    local f = (x - P1) / DX
    local i = math.floor(f)
    if i < 0 or i >= COLS then return SURF_Y end
    local t = f - i
    return (b.surf[i] or SURF_Y) * (1 - t) + (b.surf[i + 1] or SURF_Y) * t
end

local function pushColumns(b, x1, x2, dv)
    local i1 = clamp(math.floor((x1 - P1) / DX), 0, COLS)
    local i2 = clamp(math.ceil((x2 - P1) / DX), 0, COLS)
    for i = i1, i2 do
        if wetCol[i] then b.v[i] = (b.v[i] or 0) + dv end
    end
end

-- a ring on the water: at x, `y` under the surface (0 at the surface), strength `a`
local function ring(b, x, y, a)
    if not inPond(x) then return end
    local list = b.rings
    if #list >= RING_MAX then table.remove(list, 1) end
    list[#list + 1] = { x = x, y = y or 0, t = 0, a = a }
end

---------------------------------------------------------------- shaders

local VARY = [[
varying vec2 wpos;
]]

-- (rectangles, circles and polygons are batched: LÖVE moves their corners to the screen on the
-- CPU, so the vertex shader never sees world positions; the pixel works its own out instead)
local skyShader = love.graphics.newShader([[
extern float time;
extern vec2 viewOrigin;
extern float pxPerWorld;
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
    vec2 wpos = viewOrigin + sc / pxPerWorld;
    float t = clamp((-wpos.y) / 3000.0, 0.0, 1.0);
    vec3 col = mix(vec3(0.93, 0.88, 0.78), vec3(0.42, 0.62, 0.84), pow(t, 0.55));
    float c = fbm(vec2(wpos.x * 0.00035 + time * 0.006, wpos.y * 0.0012));
    c = smoothstep(0.5, 0.75, c) * smoothstep(0.05, 0.3, t);
    col = mix(col, vec3(0.99, 0.97, 0.94), c * 0.9);
    return vec4(col, 1.0);
}
#endif
#ifdef VERTEX
vec4 position(mat4 tp, vec4 vp) { return tp * vp; }
#endif
]])

-- A mirror's face: what's at the point flipped across the mirror's long axis (through `center`
-- along `axis`), `zoom` times farther out (convex), `fish` more so towards the rim (the ball),
-- `wobble` bending it like a funhouse mirror. Offsets in world units become screen pixels by the
-- camera's scale (the camera doesn't turn).
local mirrorShader = love.graphics.newShader([[
extern Image scene;
extern vec2 center;
extern vec2 axis;
extern float zoom;
extern float fish;
extern float radius;
extern float wobble;
extern float time;
extern float pxPerWorld;
extern vec3 tint;
extern vec2 viewOrigin;
#ifdef VERTEX
vec4 position(mat4 tp, vec4 vp) { return tp * vp; }
#endif
#ifdef PIXEL
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec2 wpos = viewOrigin + sc / pxPerWorld;
    vec2 d = wpos - center;
    float along = dot(d, axis);
    vec2 across = d - axis * along;
    float r = length(d) / max(radius, 1.0);
    float z = zoom * (1.0 + fish * r * r * r * 2.5);
    // the funhouse: the mirror's sheet bends in and out along its length
    float bend = 1.0 + wobble * (0.45 * sin(along * 0.0045 + time * 0.7) + 0.2 * sin(along * 0.011 - time * 1.1));
    float stretch = 1.0 + wobble * 0.25 * sin(length(across) * 0.006 + time * 0.5);
    vec2 refl = center + axis * along * z * stretch - across * z * bend;
    vec2 uv = (sc + (refl - wpos) * pxPerWorld) / love_ScreenSize.xy;
    vec4 c = Texel(scene, clamp(uv, 0.0, 1.0));
    // off the screen: no picture to show, the silver alone
    float inside = smoothstep(0.0, 0.03, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
    vec3 silver = vec3(0.72, 0.76, 0.78);
    vec3 col = mix(silver, c.rgb / max(c.a, 0.001), c.a * inside);
    col *= tint;
    // the glass: a soft sheen across, and a bright streak on the diagonal
    float diag = dot(d, normalize(vec2(1.0, -1.2))) / max(radius, 1.0);
    col += vec3(1.0) * 0.18 * exp(-pow((diag - 0.35) * 6.0, 2.0));
    col += vec3(1.0) * 0.08 * exp(-pow((diag + 0.1) * 12.0, 2.0));
    col = mix(col, col * 0.75, smoothstep(0.75, 1.05, r) * 0.6);
    return vec4(col, 1.0);
}
#endif
]])

-- The pond: under the surface line, the picture above it flipped (at the same depth over as
-- under), bent by the surface's slope, the rings and the wind, fading into the water itself
-- (what's in it, bent a little and tinted) the deeper you look.
local waterShader = love.graphics.newShader(VARY .. [[
varying float vSurf;
varying float vSlope;
extern Image scene;
extern float time;
extern float pxPerWorld;
extern float reflectAmt;
extern float fade;
extern float ripples;
extern float wind;
extern float clarity;
extern vec4 rings[24];
extern int ringCount;
#ifdef VERTEX
attribute float SurfY;
attribute float Slope;
vec4 position(mat4 tp, vec4 vp) { wpos = vp.xy; vSurf = SurfY; vSlope = Slope; return tp * vp; }
#endif
#ifdef PIXEL
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
vec4 at(vec2 worldOff, vec2 sc) {
    vec2 uv = (sc + worldOff * pxPerWorld) / love_ScreenSize.xy;
    return Texel(scene, clamp(uv, vec2(0.001), vec2(0.999)));
}
vec3 unpre(vec4 c) { return c.rgb / max(c.a, 0.001); }
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    float depth = max(wpos.y - vSurf, 0.0);
    // the rings: squashed circles (the surface seen at a slant), a short wave train at the front
    vec2 ringOff = vec2(0.0);
    float ringLight = 0.0;
    for (int k = 0; k < 24; k++) {
        if (k >= ringCount) break;
        vec4 R = rings[k];               // x, depth, age, strength
        vec2 dv = vec2(wpos.x - R.x, (depth - R.y) * 3.2);
        float r = length(dv);
        float front = R.z * 520.0;
        float u = r - front;
        float env = exp(-u * u / 22000.0) * exp(-R.z * 0.9) * R.w;
        float w = sin(u * 0.045) * env;
        ringOff += (dv / max(r, 1.0)) * w * 22.0;
        ringLight += cos(u * 0.045) * env;
    }
    ringOff *= ripples;
    ringLight *= ripples;
    // the wind: a choppy surface, more of it the further in you look (that's further away)
    vec2 wp = vec2(wpos.x * 0.012 - time * 1.7, depth * 0.05 - time * 0.4);
    vec2 chop = vec2(vnoise(wp) - 0.5, vnoise(wp + 13.7) - 0.5) * wind * (30.0 + depth * 0.25);
    // the surface's tilt where it slopes
    vec2 tilt = vec2(vSlope * depth * 0.8, 0.0);
    // the reflection: depth d under the surface shows what's d over it
    vec2 reflOff = vec2(0.0, -2.0 * depth) + ringOff + chop + tilt;
    vec4 rc = at(reflOff, sc);
    // a rough surface smears it (a few samples spread by the wind)
    float smear = wind * (8.0 + depth * 0.06);
    rc += at(reflOff + vec2(smear, -smear * 0.5), sc);
    rc += at(reflOff + vec2(-smear, smear * 0.4), sc);
    rc += at(reflOff + vec2(smear * 0.4, smear), sc);
    rc *= 0.25;
    vec3 refl = unpre(rc) * vec3(0.82, 0.9, 0.95) + vec3(0.0, 0.02, 0.04);
    // the water itself: what's in it, bent a little, tinted with depth
    vec2 bendOff = ringOff * 0.5 + chop * 0.3 + vec2(sin(wpos.y * 0.02 + time * 1.6), cos(wpos.x * 0.017 + time * 1.3)) * 4.0;
    vec4 under = at(bendOff, sc);
    vec3 deepCol = vec3(0.06, 0.20, 0.22);
    vec3 shallowCol = vec3(0.30, 0.52, 0.48);
    vec3 waterCol = mix(shallowCol, deepCol, 1.0 - exp(-depth / (420.0 * clarity)));
    float see = exp(-depth / (260.0 * clarity));
    vec3 inside = mix(waterCol, unpre(under) * vec3(0.7, 0.88, 0.85), under.a * see);
    // how much is mirror: most at the top, less deeper down (where you'd look into it)
    float m = reflectAmt * mix(1.0, exp(-depth / 380.0), fade) * 0.9;
    vec3 col = mix(inside, refl, clamp(m, 0.0, 1.0));
    col += vec3(0.9, 0.97, 1.0) * ringLight * 0.10;
    // the bright line where the surface meets the air
    float lineW = 3.0 / pxPerWorld;
    col = mix(col, vec3(0.92, 0.97, 1.0), 1.0 - smoothstep(lineW * 0.5, lineW * 1.6, depth));
    return vec4(col, 1.0);
}
#endif
]])

---------------------------------------------------------------- meshes

local groundMesh
do
    local verts = {}
    local n = math.floor((RIGHT - LEFT) / DX)
    for i = 0, n do
        local x = LEFT + i * DX
        local top = groundAt(x)
        verts[#verts + 1] = { x, top, 0.30, 0.48, 0.20, 1 }
        verts[#verts + 1] = { x, GROUND_Y + POND_DEEP + 900, 0.36, 0.27, 0.17, 1 }
    end
    groundMesh = love.graphics.newMesh({
        { 'VertexPosition', 'float', 2 }, { 'VertexColor', 'float', 4 },
    }, verts, 'strip', 'static')
end

local waterMesh = love.graphics.newMesh({
    { 'VertexPosition', 'float', 2 }, { 'VertexTexCoord', 'float', 2 },
    { 'SurfY', 'float', 1 }, { 'Slope', 'float', 1 },
}, (COLS + 1) * 2, 'strip', 'stream')

local waterVerts = {}
local function updateWaterMesh(b)
    for i = 0, COLS do
        local x = colX(i)
        local surf = b.surf[i] or SURF_Y
        local bottom = math.max(surf, groundAt(x) + 6)
        local slope = ((b.surf[i + 1] or surf) - (b.surf[i - 1] or surf)) / (2 * DX)
        local k = i * 2
        waterVerts[k + 1] = waterVerts[k + 1] or {}
        waterVerts[k + 2] = waterVerts[k + 2] or {}
        local top, bot = waterVerts[k + 1], waterVerts[k + 2]
        top[1], top[2], top[3], top[4], top[5], top[6] = x, surf, 0, 0, surf, slope
        bot[1], bot[2], bot[3], bot[4], bot[5], bot[6] = x, bottom, 0, 1, surf, slope
    end
    waterMesh:setVertices(waterVerts)
end

---------------------------------------------------------------- the mirrors

-- On the wall and on stands, no bodies: decor at fixed places.
local WALL = { x1 = -2750, x2 = -1050, top = -1050 }
local FIXED = {
    { kind = 'rect', x = -1950, y = -620, w = 640, h = 780, zoom = 1.5, label = 'wall mirror' },
    { kind = 'ball', x = 2000, y = -720, r = 210, zoom = 1.6, fish = 1, label = 'gazing ball' },
    { kind = 'rect', x = 2680, y = -700, w = 520, h = 1150, zoom = 1, wobble = 1, label = 'funhouse' },
}

local INK = { 0.17, 0.12, 0.09, 1 }

local function sendMirror(m, cx, cy, ax, ay, radius, set)
    mirrorShader:send('center', { cx, cy })
    mirrorShader:send('axis', { ax, ay })
    mirrorShader:send('zoom', 1 + ((m.zoom or 1) - 1) * set.zoom)
    mirrorShader:send('fish', (m.fish or 0) * set.zoom)
    mirrorShader:send('radius', radius)
    mirrorShader:send('wobble', (m.wobble or 0) * set.wobble)
    mirrorShader:send('tint', m.tint or { 0.96, 0.98, 1.0 })
end

-- a rectangle's corners, inset by `inset`, as a flat list
local function rectFace(cx, cy, w, h, angle, inset)
    local c, s_ = math.cos(angle), math.sin(angle)
    local hw, hh = w / 2 - inset, h / 2 - inset
    local pts = {}
    for _, p in ipairs({ { -hw, -hh }, { hw, -hh }, { hw, hh }, { -hw, hh } }) do
        pts[#pts + 1] = cx + p[1] * c - p[2] * s_
        pts[#pts + 1] = cy + p[1] * s_ + p[2] * c
    end
    return pts
end

local function drawFixedFrames()
    -- the garden wall behind the wall mirror
    love.graphics.setColor(0.80, 0.70, 0.58, 1)
    love.graphics.rectangle('fill', WALL.x1, WALL.top, WALL.x2 - WALL.x1, GROUND_Y - WALL.top)
    love.graphics.setColor(0.70, 0.60, 0.49, 1)
    for row = 0, 7 do
        local y = WALL.top + row * 135
        local shift = (row % 2) * 130
        for x = WALL.x1 + shift, WALL.x2, 260 do
            love.graphics.rectangle('fill', x + 6, y + 6, 248, 123)
        end
    end
    love.graphics.setColor(0.74, 0.64, 0.52, 1)
    love.graphics.rectangle('fill', WALL.x1 - 40, WALL.top - 60, WALL.x2 - WALL.x1 + 80, 70)
    love.graphics.setColor(INK)
    love.graphics.setLineWidth(12)
    love.graphics.rectangle('line', WALL.x1, WALL.top, WALL.x2 - WALL.x1, GROUND_Y - WALL.top)
    for _, m in ipairs(FIXED) do
        if m.kind == 'rect' then
            if m.wobble then -- legs
                love.graphics.setColor(0.55, 0.30, 0.42, 1)
                love.graphics.rectangle('fill', m.x - m.w / 2 + 30, m.y + m.h / 2 - 20, 50, GROUND_Y - m.y - m.h / 2 + 20)
                love.graphics.rectangle('fill', m.x + m.w / 2 - 80, m.y + m.h / 2 - 20, 50, GROUND_Y - m.y - m.h / 2 + 20)
            end
            -- a ring, not a panel: behind the glass is the wall, so the mirror doesn't show its own back
            love.graphics.setColor(m.wobble and { 0.86, 0.40, 0.55, 1 } or { 0.70, 0.52, 0.22, 1 })
            love.graphics.setLineWidth(80)
            love.graphics.rectangle('line', m.x - m.w / 2 - 15, m.y - m.h / 2 - 15, m.w + 30, m.h + 30, 45, 45)
            love.graphics.setColor(INK)
            love.graphics.setLineWidth(12)
            love.graphics.rectangle('line', m.x - m.w / 2 - 50, m.y - m.h / 2 - 50, m.w + 100, m.h + 100, 60, 60)
            if m.wobble then -- lightbulbs round the funhouse frame
                love.graphics.setColor(1, 0.92, 0.6, 1)
                for t = 0, 1, 1 / 9 do
                    love.graphics.circle('fill', m.x - m.w / 2 - 25, m.y - m.h / 2 + t * m.h, 18)
                    love.graphics.circle('fill', m.x + m.w / 2 + 25, m.y - m.h / 2 + t * m.h, 18)
                end
            end
        else -- the ball on its pedestal
            love.graphics.setColor(0.78, 0.76, 0.70, 1)
            love.graphics.polygon('fill', m.x - 70, m.y + m.r - 10, m.x + 70, m.y + m.r - 10,
                m.x + 120, GROUND_Y, m.x - 120, GROUND_Y)
            love.graphics.setColor(INK)
            love.graphics.polygon('line', m.x - 70, m.y + m.r - 10, m.x + 70, m.y + m.r - 10,
                m.x + 120, GROUND_Y, m.x - 120, GROUND_Y)
            love.graphics.circle('line', m.x, m.y, m.r + 6)
        end
    end
    love.graphics.setLineWidth(1)
end

local function drawFixedFaces(set)
    for _, m in ipairs(FIXED) do
        if m.kind == 'rect' then
            sendMirror(m, m.x, m.y, 0, 1, math.max(m.w, m.h) / 2, set)
            love.graphics.rectangle('fill', m.x - m.w / 2, m.y - m.h / 2, m.w, m.h, 30, 30)
            love.graphics.flushBatch() -- else the faces batch up and all draw with the last one's uniforms
        else
            sendMirror(m, m.x, m.y, 0, 1, m.r, set)
            love.graphics.circle('fill', m.x, m.y, m.r, 64)
            love.graphics.flushBatch()
        end
    end
end

-- the ones you can pick up: bodies, flipped across their own long axis
local PROPS = {
    stand = function(x, y)
        return objectManager.addThing('rectangle', { x = x, y = y, width = 340, height = 980,
            bodyType = 'dynamic', label = 'mirror-stand', density = 0.5 })
    end,
    hand = function(x, y)
        return objectManager.addThing('rectangle', { x = x, y = y, width = 260, height = 360,
            bodyType = 'dynamic', label = 'mirror-hand', density = 0.3 })
    end,
    ball = function(x, y)
        return objectManager.addThing('circle', { x = x, y = y, radius = 110,
            bodyType = 'dynamic', label = 'pond-ball', density = 0.15 })
    end,
}
local PROP_MIRROR = {
    stand = { zoom = 1 },
    hand = { zoom = 2.2, tint = { 1.0, 0.97, 0.93 } },
}

local function propRect(p)
    local fixture = p.body:getFixtures()[1]
    for _, f in ipairs(p.body:getFixtures()) do
        if f:getShape():type() == 'PolygonShape' then fixture = f end
    end
    return fixture and fixture:getShape()
end

local function drawPropFrames(b)
    for _, p in ipairs(b.props) do
        local body = p.body
        if body and not body:isDestroyed() then
            local shape = propRect(p)
            if shape and shape:type() == 'PolygonShape' then
                local pts = { body:getWorldPoints(shape:getPoints()) }
                local cx, cy = body:getPosition()
                local w = p.kind == 'hand' and 260 or 340
                local h = p.kind == 'hand' and 360 or 980
                -- a ring (the glass shows what's behind it, not the frame's own back)
                love.graphics.setColor(p.kind == 'hand' and { 0.45, 0.62, 0.78, 1 } or { 0.55, 0.36, 0.20, 1 })
                love.graphics.setLineWidth(40)
                love.graphics.setLineJoin('miter')
                love.graphics.polygon('line', rectFace(cx, cy, w, h, body:getAngle(), 18))
                love.graphics.setColor(INK)
                love.graphics.setLineWidth(12)
                love.graphics.polygon('line', pts)
            elseif shape and shape:type() == 'CircleShape' then
                local cx, cy = body:getWorldPoint(shape:getPoint())
                local r, a = shape:getRadius(), body:getAngle()
                local colors = { { 0.92, 0.25, 0.2 }, { 0.98, 0.95, 0.88 }, { 0.2, 0.45, 0.85 }, { 0.98, 0.95, 0.88 } }
                for j = 1, 4 do
                    love.graphics.setColor(colors[j])
                    love.graphics.arc('fill', cx, cy, r, a + (j - 1) * math.pi / 2, a + j * math.pi / 2)
                end
                love.graphics.setColor(INK)
                love.graphics.setLineWidth(10)
                love.graphics.circle('line', cx, cy, r)
            end
        end
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawPropFaces(b, set)
    for _, p in ipairs(b.props) do
        local m = PROP_MIRROR[p.kind]
        local body = p.body
        if m and body and not body:isDestroyed() then
            local cx, cy = body:getPosition()
            local a = body:getAngle()
            local w = p.kind == 'hand' and 260 or 340
            local h = p.kind == 'hand' and 360 or 980
            sendMirror(m, cx, cy, -math.sin(a), math.cos(a), h / 2, set)
            love.graphics.polygon('fill', rectFace(cx, cy, w, h, a, 34))
            love.graphics.flushBatch()
        end
    end
end

---------------------------------------------------------------- the garden

local TREE = { x = 1680, y = GROUND_Y }
local function drawGarden(t)
    -- hills far off
    love.graphics.setColor(0.62, 0.72, 0.62, 1)
    local pts = {}
    for x = LEFT - 500, RIGHT + 500, 200 do
        pts[#pts + 1] = x
        pts[#pts + 1] = GROUND_Y - 420 - 260 * love.math.noise(x * 0.0004, 1.1)
    end
    pts[#pts + 1], pts[#pts + 2] = RIGHT + 500, GROUND_Y + POND_DEEP
    pts[#pts + 1], pts[#pts + 2] = LEFT - 500, GROUND_Y + POND_DEEP
    for _, tri in ipairs(love.math.triangulate(pts)) do love.graphics.polygon('fill', tri) end
    -- a tree by the pond
    love.graphics.setColor(0.42, 0.28, 0.17, 1)
    love.graphics.polygon('fill', TREE.x - 55, TREE.y, TREE.x + 55, TREE.y, TREE.x + 30, TREE.y - 900, TREE.x - 30, TREE.y - 900)
    local sway = math.sin(t * 0.6) * 12
    local blobs = { { 0, -1150, 360 }, { -280, -950, 260 }, { 260, -980, 280 }, { -120, -1400, 230 }, { 180, -1330, 220 } }
    for k, bl in ipairs(blobs) do
        local g = 0.40 + 0.06 * (k % 3)
        love.graphics.setColor(0.22, g, 0.20, 1)
        love.graphics.circle('fill', TREE.x + bl[1] + sway * (k % 2 == 0 and 1 or 0.6), TREE.y + bl[2], bl[3])
    end
    love.graphics.setColor(0.86, 0.30, 0.25, 1)
    for k = 1, 9 do
        local a = k * 2.4
        love.graphics.circle('fill', TREE.x + math.cos(a) * 260 + sway, TREE.y - 1120 + math.sin(a) * 220, 28)
    end
    -- reeds at the banks
    love.graphics.setLineWidth(10)
    for k = 0, 11 do
        local x = (k < 6) and (P1 + 40 + k * 45) or (P2 - 300 + (k - 6) * 45)
        local base = groundAt(x)
        local h = 260 + 120 * love.math.noise(k * 0.7, 4.2)
        local bend = math.sin(t * 1.3 + k) * 20
        love.graphics.setColor(0.34, 0.50, 0.22, 1)
        love.graphics.line(x, base, x + bend * 0.5, base - h * 0.5, x + bend, base - h)
        if k % 3 == 0 then
            love.graphics.setColor(0.45, 0.30, 0.18, 1)
            love.graphics.ellipse('fill', x + bend, base - h + 20, 16, 50)
        end
    end
    love.graphics.setLineWidth(1)
end

---------------------------------------------------------------- the world in it

local function destroyGround(b)
    if b.ground and not b.ground:isDestroyed() then b.ground:destroy() end
    b.ground = nil
end

local function buildGround(b)
    destroyGround(b)
    local flat = { LEFT, GROUND_Y - 3000, LEFT, GROUND_Y }
    for x = P1 - DX, P2 + DX, DX do
        flat[#flat + 1], flat[#flat + 2] = x, groundAt(x)
    end
    flat[#flat + 1], flat[#flat + 2] = RIGHT, GROUND_Y
    flat[#flat + 1], flat[#flat + 2] = RIGHT, GROUND_Y - 3000
    b.ground = love.physics.newBody(world, 0, 0, 'static')
    local fixture = love.physics.newFixture(b.ground, love.physics.newChainShape(false, unpack(flat)))
    fixture:setFriction(0.8)
end

local function aliveMipos(b) return mipoKit.alive(b.mipos) end -- src/mipo-kit.lua

local function aliveProps(b)
    local alive = {}
    for _, p in ipairs(b.props) do
        if p.body and not p.body:isDestroyed() then alive[#alive + 1] = p end
    end
    return alive
end

local function spawnMipo(b, x, y) mipoKit.spawn(b.mipos, x, y) end -- src/mipo-kit.lua

local function spawnProp(b, kind, x, y)
    local thing = PROPS[kind](x, y)
    if thing then b.props[#b.props + 1] = { kind = kind, body = thing.body } end
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
    spawnProp(b, 'stand', -850, -520)
    spawnProp(b, 'hand', 1100, -700)
    spawnMipo(b, -1700, -700)
    spawnMipo(b, 2300, -700)
    spawnMipo(b, 150, -700)
end

local function resetWater(b)
    for i = 0, COLS do b.h[i], b.v[i], b.surf[i] = 0, 0, SURF_Y end
    b.rings, b.drops, b.stones = {}, {}, {}
end

---------------------------------------------------------------- floating (as in the sea spike)

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

local function splash(b, x, width, vy)
    local strength = clamp(math.abs(vy), 0, 2500)
    pushColumns(b, x - width / 2, x + width / 2, vy * 0.3 * clamp(width / 400, 0.3, 1))
    ring(b, x, 0, clamp(strength / 900, 0.4, 1.6))
    for _ = 1, math.floor(strength / 110) do
        local sx = x + (love.math.random() - 0.5) * width
        b.drops[#b.drops + 1] = {
            x = sx, y = surfaceAt(b, sx) - 5,
            vx = (sx - x) / math.max(width, 1) * strength * 0.8 + (love.math.random() - 0.5) * 250,
            vy = -strength * (0.3 + love.math.random() * 0.45),
            r = 7 + love.math.random() * 14, life = 2,
        }
    end
end

local LIGHTER = { stand = 1.6, hand = 2.5, ball = 5 }
local function float(b, dt)
    local _, gy = world:getGravity()
    local lighter = {}
    for _, p in ipairs(b.props) do
        if p.body and not p.body:isDestroyed() then lighter[p.body] = LIGHTER[p.kind] end
    end
    for _, body in ipairs(world:getBodies()) do repeat
        if body:getType() ~= 'dynamic' or body:isDestroyed() then break end
        local bx = body:getPosition()
        if not inPond(bx) then
            if b.wet[body] then b.wet[body] = nil end
            break
        end
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
            if maxY <= math.min(s1, s2) then break end
            local clipped, m = clipUnder(poly, n, x1, s1, x2, s2)
            if m < 3 then break end
            local area, cx, cy = areaCentroid(clipped, m)
            if area <= 0 or full <= 0 then break end
            local frac = math.min(area / full, 1)
            wetArea = wetArea + area
            if x1 < minX then minX = x1 end
            if x2 > maxX then maxX = x2 end
            local up = mass * gy * frac * 1.6 * (lighter[body] or 1)
            local vx, vy = body:getLinearVelocityFromWorldPoint(cx, cy)
            local k = mass * frac * 1.4
            body:applyForce(-vx * k, -up - vy * k, cx, cy)
        until true end
        local wetFrac = totalArea > 0 and wetArea / totalArea or 0
        if wetFrac > 0 then
            body:applyTorque(-body:getInertia() * body:getAngularVelocity() * wetFrac)
        end
        local was = b.wet[body] or 0
        local _, vy = body:getLinearVelocity()
        if wetFrac > 0 and was == 0 and vy > 200 then
            splash(b, bx, math.max(maxX - minX, 100), vy)
        elseif wetFrac > 0 and wetFrac < 0.95 and maxX > minX then
            -- bobbing at the surface stirs it, and now and then sends out a little ring
            pushColumns(b, minX, maxX, vy * dt * 0.8 * wetFrac)
            if math.abs(vy) > 60 and love.math.random() < dt * 3 then ring(b, bx, 0, clamp(math.abs(vy) / 600, 0.1, 0.5)) end
        end
        b.wet[body] = wetFrac
    until true end
end

---------------------------------------------------------------- waves, rings, stones, rain

local STEP = 1 / 120
local function waves(b, dt)
    local c2 = 900 * 900 / (DX * DX)
    b.acc = (b.acc or 0) + math.min(dt, 0.05)
    local h, v = b.h, b.v
    while b.acc >= STEP do
        b.acc = b.acc - STEP
        for i = 0, COLS do
            if wetCol[i] then
                local l = wetCol[i - 1] and h[i - 1] or h[i] -- the banks throw it back
                local r = wetCol[i + 1] and h[i + 1] or h[i]
                v[i] = v[i] + (c2 * (l + r - 2 * h[i]) - 8 * h[i] - 2.2 * v[i]) * STEP
            end
        end
        for i = 0, COLS do
            if wetCol[i] then h[i] = clamp(h[i] + v[i] * STEP, -160, 160) else h[i], v[i] = 0, 0 end
        end
    end
    -- the wind ruffles the line a little too
    local wind = b.settings.wind
    for i = 0, COLS do
        local x = colX(i)
        local ruffle = wind * 7 * (math.sin(x * 0.03 - b.time * 4.1) + 0.6 * math.sin(x * 0.071 - b.time * 6.3))
        b.surf[i] = SURF_Y + h[i] + (wetCol[i] and ruffle or 0)
    end
end

local function updateRings(b, dt)
    local keep = {}
    for _, r in ipairs(b.rings) do
        r.t = r.t + dt
        if r.t < 4.5 then keep[#keep + 1] = r end
    end
    b.rings = keep
end

local function particles(b, dt)
    local _, gy = world:getGravity()
    local keep = {}
    for _, d in ipairs(b.drops) do
        d.vy = d.vy + gy * dt
        d.x, d.y = d.x + d.vx * dt, d.y + d.vy * dt
        d.life = d.life - dt
        if d.vy > 0 and inPond(d.x) and d.y > surfaceAt(b, d.x) then
            pushColumns(b, d.x, d.x, d.r * 1.2)
            if d.r > 12 then ring(b, d.x, 0, 0.25) end
        elseif d.life > 0 and d.y < GROUND_Y + 50 then
            keep[#keep + 1] = d
        end
    end
    b.drops = keep
    -- skimming stones: off the water while they're fast and flat, in when they're slow
    keep = {}
    for _, st in ipairs(b.stones) do
        st.vy = st.vy + gy * dt
        st.x, st.y = st.x + st.vx * dt, st.y + st.vy * dt
        st.spin = st.spin + dt * 12
        local surf = surfaceAt(b, st.x)
        if inPond(st.x) and st.y > surf and st.vy > 0 then
            if math.abs(st.vx) > 450 and not st.sinking then
                st.y = surf
                st.vy = -st.vy * 0.55 - 120
                st.vx = st.vx * 0.78
                ring(b, st.x, 0, 0.8)
                pushColumns(b, st.x - 30, st.x + 30, 160)
                for _ = 1, 4 do
                    b.drops[#b.drops + 1] = { x = st.x, y = surf - 4, vx = st.vx * 0.4 + (love.math.random() - 0.5) * 300,
                        vy = -200 - love.math.random() * 400, r = 5 + love.math.random() * 7, life = 1.5 }
                end
            elseif not st.sinking then
                st.sinking = true
                ring(b, st.x, 0, 1.1)
                pushColumns(b, st.x - 40, st.x + 40, 300)
            end
        end
        if st.sinking then
            st.vx, st.vy = st.vx * 0.9, math.min(st.vy, 260)
        end
        local floor = groundAt(st.x)
        if st.y < floor and st.y > -6000 and st.x > LEFT and st.x < RIGHT then keep[#keep + 1] = st end
    end
    b.stones = keep
end

local function rain(b, dt)
    local amount = b.settings.rain
    if amount <= 0 then return end
    b.rainAcc = (b.rainAcc or 0) + dt * 14 * amount
    while b.rainAcc >= 1 do
        b.rainAcc = b.rainAcc - 1
        local x = P1 + 80 + love.math.random() * (P2 - P1 - 160)
        if wetCol[clamp(math.floor((x - P1) / DX), 0, COLS)] then
            -- far drops land lower in the picture (further off on the slanted surface)
            ring(b, x, love.math.random() * 260, 0.25 + love.math.random() * 0.3)
            pushColumns(b, x, x, 40)
        end
    end
end

local function throwStone(b, x, y)
    local dir = (x < (P1 + P2) / 2) and 1 or -1
    b.stones[#b.stones + 1] = { x = x, y = math.min(y, SURF_Y - 40), vx = dir * 1900, vy = 80, spin = 0 }
end

local function dropPebble(b, x, y)
    b.stones[#b.stones + 1] = { x = x, y = math.min(y, SURF_Y - 20), vx = 0, vy = 0, spin = 0, sinking = false }
end

---------------------------------------------------------------- callbacks

function s.onStart()
    worldState.paused = false
    local b = pond()
    if not b.surf[0] then resetWater(b) end
    buildGround(b)
    b.props = aliveProps(b)
    b.mipos = aliveMipos(b)
    if #b.props == 0 and #b.mipos == 0 then stock(b) end
    camera.setBounds(LEFT, GROUND_Y - 3200, RIGHT, GROUND_Y + POND_DEEP + 500)
end

function s.onUnload()
    local b = state.mirrors
    if not b then return end
    destroyGround(b)
    if b.savedDrawBodies ~= nil then state.world.debugDrawBodies = b.savedDrawBodies end
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local b = pond()
    local mx, my = mouseWorldPos()
    if key == 'k' then throwStone(b, mx, my)
    elseif key == 'd' then dropPebble(b, mx, my)
    elseif key == 'n' then b.settings.rain = (b.settings.rain > 0) and 0 or 1
    elseif key == 'm' then spawnMipo(b, mx, my)
    elseif key == 'o' then spawnProp(b, 'ball', mx, my)
    elseif key == 'g' then spawnProp(b, 'hand', mx, my)
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
    if not b.showPanel or ui.isPanelFolded('•• mirrors ••') then return false end
    local mx, my = love.mouse.getPosition()
    local r = panelRect
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

function s.update(dt)
    local b = pond()
    b.time = b.time + dt
    -- press on the water (not on a thing) and drag: the surface follows, rings trail behind
    local down = state.playMode and love.mouse.isDown(1)
    if down and not b.stirring and #getInteractedWithPointer() == 0 and not overPanel(b) then
        local mx, my = mouseWorldPos()
        if inPond(mx) and my > SURF_Y - 250 then
            b.stirring = true
            b.lastMX, b.lastMY = mx, my
            ring(b, mx, math.max(my - SURF_Y, 0) * 0.4, 0.9)
        end
    elseif not down then
        b.stirring = nil
    end
    if b.stirring then
        local mx, my = mouseWorldPos()
        local moved = math.sqrt((mx - b.lastMX) ^ 2 + (my - b.lastMY) ^ 2)
        pushColumns(b, mx - 60, mx + 60, (my - b.lastMY) * 3 + math.min(moved, 200) * 0.6)
        b.trail = (b.trail or 0) + moved
        if b.trail > 140 then
            b.trail = 0
            ring(b, mx, math.max(my - SURF_Y, 0) * 0.4, clamp(moved / 60, 0.3, 1))
        end
        b.lastMX, b.lastMY = mx, my
    end
    rain(b, dt)
    waves(b, dt)
    float(b, dt)
    particles(b, dt)
    updateRings(b, dt)
end

---------------------------------------------------------------- drawing

-- bg: sky, hills, wall, ground (and later the mirror faces); things: the bodies and Mipos;
-- both: the two together, what the mirrors see
local bgCanvas, thingsCanvas, bothCanvas, prevCanvas
local function ensureCanvases()
    local w, h = love.graphics.getDimensions()
    if not bgCanvas or bgCanvas:getWidth() ~= w or bgCanvas:getHeight() ~= h then
        local _, _, flags = love.window.getMode()
        local msaa = flags.msaa or 0
        bgCanvas = love.graphics.newCanvas(w, h, { msaa = msaa })
        thingsCanvas = love.graphics.newCanvas(w, h, { msaa = msaa })
        bothCanvas = love.graphics.newCanvas(w, h)
    end
end

local function viewRect()
    local w, h = love.graphics.getDimensions()
    local x1, y1 = cam:getWorldCoordinates(0, 0)
    local x2, y2 = cam:getWorldCoordinates(w, h)
    return math.min(x1, x2), math.min(y1, y2), math.max(x1, x2), math.max(y1, y2)
end

local function blitCanvas(c)
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode('alpha', 'premultiplied')
    love.graphics.draw(c, 0, 0)
    love.graphics.setBlendMode('alpha')
    love.graphics.pop()
end

function s.drawBelow()
    local b = state.mirrors
    if not b or not b.surf[0] then return end
    ensureCanvases()
    prevCanvas = love.graphics.getCanvas()
    local x1, y1, x2, y2 = viewRect()
    love.graphics.setCanvas({ bgCanvas, stencil = true })
    love.graphics.clear(0, 0, 0, 1)
    local ox, oy = cam:getWorldCoordinates(0, 0)
    love.graphics.setShader(skyShader)
    skyShader:send('time', b.time)
    skyShader:send('viewOrigin', { ox, oy })
    skyShader:send('pxPerWorld', cam:getScale() * love.graphics.getDPIScale())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle('fill', x1 - 10, y1 - 10, x2 - x1 + 20, y2 - y1 + 20)
    love.graphics.setShader()
    drawGarden(b.time)
    drawFixedFrames()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(groundMesh)
    love.graphics.setColor(0.24, 0.40, 0.16, 1)
    love.graphics.setLineWidth(18)
    love.graphics.line(LEFT, GROUND_Y, P1 + 10, GROUND_Y)
    love.graphics.line(P2 - 10, GROUND_Y, RIGHT, GROUND_Y)
    love.graphics.setLineWidth(1)
    -- the bodies and Mipos go into their own canvas
    love.graphics.setCanvas({ thingsCanvas, stencil = true })
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    if state.playMode then
        b.savedDrawBodies = state.world.debugDrawBodies
        state.world.debugDrawBodies = false
    end
    b.drawing = true
end

function s.draw()
    local b = state.mirrors
    if not (b and b.drawing) then return end
    b.drawing = nil
    if b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
    local set = b.settings
    drawPropFrames(b)
    -- stones in the air (and sinking ones, seen through the water)
    for _, st in ipairs(b.stones) do
        love.graphics.setColor(0.45, 0.43, 0.42, 1)
        love.graphics.ellipse('fill', st.x, st.y, 34, 20)
        love.graphics.setColor(INK)
        love.graphics.setLineWidth(6)
        love.graphics.ellipse('line', st.x, st.y, 34, 20)
    end
    love.graphics.setLineWidth(1)

    -- what the mirrors see: the background and the things
    love.graphics.setCanvas(bothCanvas)
    love.graphics.clear(0, 0, 0, 0)
    blitCanvas(bgCanvas)
    blitCanvas(thingsCanvas)

    -- the mirror faces onto the background, then the things over them
    local pxPerWorld = cam:getScale() * love.graphics.getDPIScale()
    love.graphics.setCanvas({ bgCanvas, stencil = true })
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader(mirrorShader)
    mirrorShader:send('scene', bothCanvas)
    mirrorShader:send('time', b.time)
    mirrorShader:send('pxPerWorld', pxPerWorld)
    mirrorShader:send('viewOrigin', { cam:getWorldCoordinates(0, 0) })
    drawFixedFaces(set)
    drawPropFaces(b, set)
    love.graphics.setShader()
    blitCanvas(thingsCanvas)

    -- the whole picture, then the pond over it, looking at it
    love.graphics.setCanvas(prevCanvas)
    blitCanvas(bgCanvas)
    updateWaterMesh(b)
    love.graphics.setShader(waterShader)
    waterShader:send('scene', bgCanvas)
    waterShader:send('time', b.time)
    waterShader:send('pxPerWorld', pxPerWorld)
    waterShader:send('reflectAmt', set.reflect)
    waterShader:send('fade', set.fade)
    waterShader:send('ripples', set.ripples)
    waterShader:send('wind', set.wind)
    waterShader:send('clarity', set.clarity)
    local list = {}
    for k, r in ipairs(b.rings) do list[k] = { r.x, r.y, r.t, r.a } end
    if #list == 0 then list[1] = { 0, 0, 99, 0 } end
    waterShader:send('rings', unpack(list))
    waterShader:send('ringCount', #b.rings)
    love.graphics.draw(waterMesh)
    love.graphics.setShader()

    for _, d in ipairs(b.drops) do
        love.graphics.setColor(0.88, 0.96, 1, clamp(d.life, 0, 1) * 0.85)
        love.graphics.circle('fill', d.x, d.y, d.r)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local b = state.mirrors
    if not (b and state.playMode and b.showPanel) then return end
    ui.startFrame()
    local BH, pad, w = 36, 8, 400
    local rows = {
        { 'reflect', 0, 1 }, { 'fade', 0, 1 }, { 'ripples', 0, 3 }, { 'wind', 0, 2 },
        { 'rain', 0, 4 }, { 'clarity', 0.3, 3 }, { 'zoom', 0, 2 }, { 'wobble', 0, 3 },
    }
    local h = (BH + pad) * (#rows + 2) + pad + 24
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    panelRect[2], panelRect[4] = y0, h
    ui.panel(x0, y0, w, h, '•• mirrors ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        for _, row in ipairs(rows) do
            local key = row[1]
            local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('mirrors' .. key, x, y, 180, row[2], row[3], b.settings[key])
            if v then b.settings[key] = v + 0 end
            ui.label(x + 280, y, key)
        end
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'drag on the water   k skim   d pebble   n rain')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'm Mipo   o ball   g hand mirror   r reset   h')
    end)
end

return s

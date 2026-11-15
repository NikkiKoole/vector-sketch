-- dirt-look.lua: Mipo parts getting dirty (mud, paint) and clean again, by shader (scene `dirty`, docs/DIRT.md).
--
-- Every part has its own dirt mask: small canvases in the part's own picture space (its UVs), so the dirt
-- sticks to the part: a leg dipped in mud keeps its mud line where it was, tilted with the leg when it
-- swings. Two canvases per part:
--   canvas: the pigment, as absorbance (premultiplied): rgb = how much each colour is soaked up * amount,
--           a = how much. Absorbances add up like real paint does: yellow over blue makes green, not grey.
--   wet:    r = how wet, g = how much of it is paint rather than mud (premultiplied like the pigment: g / a).
--
-- Painting: the part is drawn again, into its mask, through a shader that lays it out flat by its UVs
-- (the vertex shader puts each vertex at its UV) while still knowing where each pixel is in the world
-- (the vertex's place as drawn, back through the camera). So "below the bath's surface" or "under the
-- sponge" is decided per pixel in the world and written where that pixel lives on the part. Works for
-- any drawable whatever its kind (pictures, ribbon limbs, skinned meshes), as long as its UVs are its own.
--
-- Drawing: the part through a shader that reads its mask: mud in splotches where it's thin, all over
-- where it's thick, a darker tide mark at its edge, wet = darker and glinting, dry = lighter and cracked.
-- Paint is smoother: less grain, no cracks, glossy while wet.
--
-- The CPU keeps a rough copy per part (m.load, m.absorb, m.paint: what's on its lowest bit), for what the
-- scene does with it: drips and prints (scripts/spikes/paint-marks.lua).
local state = require('src.state')
local registry = require('src.registry')
local subtypes = require('src.subtypes')
local liquid = require('src.liquid')

local lib = {}

lib.MASK = 128 -- mask size (px, square)
lib.ABSORB = 4 -- absorbance stored / 4 (8 bits: 0..4 covers colours down to ~0.02)

lib.tuning = {
    soak = 1.5,       -- per second in a bath: how fast it gets dirty
    rinse = 0.8,      -- per second under clean water
    scrub = 3,        -- sponge: per second while rubbing
    sponge = 70,      -- sponge radius (world)
    dry = 20,         -- seconds from soaked to dry
    wobble = 14,      -- the mud line's waviness (world px)
    strength = 1,     -- how much the mud covers
    splotch = 0.6,    -- thin mud in splotches (0: an even film)
    grain = 0.5,      -- the mud's grain
    tide = 0.6,       -- the tide mark at the mud's edge
    shine = 0.7,      -- wet glints
    cracks = 0.5,     -- dried mud cracks
    lines = 0.6,      -- the drawing's lines showing through
    grainSize = 30,   -- grain scale (in the part's picture)
}

-- mud colours (0..1)
lib.MUDS = {
    { name = 'mud', color = { 0.36, 0.25, 0.15 } },
    { name = 'clay', color = { 0.62, 0.36, 0.22 } },
    { name = 'peat', color = { 0.17, 0.13, 0.10 } },
}

-- paint colours (0..1): the three primaries, mixed by absorbance
lib.PAINTS = {
    red = { 0.86, 0.10, 0.09 },
    yellow = { 0.99, 0.82, 0.06 },
    blue = { 0.07, 0.27, 0.86 },
}

local function data()
    if not state.dirtLook or state.dirtLook.v ~= 2 then -- (v2: two canvases a mask, pigment as absorbance)
        state.dirtLook = { v = 2, masks = setmetatable({}, { __mode = 'k' }), mud = 1 }
    end
    return state.dirtLook
end
lib.data = data

-- a colour's absorbance (/ ABSORB, 0..1 per channel), and back
function lib.absorbOf(c)
    local out = {}
    for i = 1, 3 do out[i] = math.min(1, -math.log(math.max(c[i], 0.018)) / lib.ABSORB) end
    return out
end
function lib.colorOfAbsorb(a)
    return math.exp(-a[1] * lib.ABSORB), math.exp(-a[2] * lib.ABSORB), math.exp(-a[3] * lib.ABSORB)
end
function lib.mudColor() return (lib.MUDS[data().mud] or lib.MUDS[1]).color end

local NOISE = [[
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
]]

-- is this world point in the bath (mode 0) or under the sponge (mode 1): shared by both paint passes.
-- op 0: write amount * inside (blended over), op 1: 1 - amount * inside (multiplied: washing off)
local INSIDE = [[
uniform float mode;      // 0: below a surface, 1: a round brush
uniform float level;
uniform vec2 xRange;
uniform float wobble;
uniform vec2 brush;
uniform float brushR;
uniform vec4 amount;
uniform float op;
float insideAt(vec2 worldPos) {
    if (mode < 0.5) {
        float line = level + wobble * (vnoise(vec2(worldPos.x / 40.0, 3.0)) - 0.5
            + 0.5 * (vnoise(vec2(worldPos.x / 9.0, 7.0)) - 0.5));
        return step(line, worldPos.y) * step(xRange.x, worldPos.x) * step(worldPos.x, xRange.y);
    }
    float r = brushR * (0.85 + 0.3 * vnoise(worldPos / 12.0));
    return smoothstep(r, r * 0.5, distance(worldPos, brush));
}
vec4 result(float inside) {
    return op > 0.5 ? vec4(1.0) - amount * inside : amount * inside;
}
]]

-- the paint pass: the part laid out flat by its UVs, each pixel knowing its world place
local PAINT = [[
#ifdef VERTEX
uniform vec2 maskSize;
uniform vec3 toWorldX;
uniform vec3 toWorldY;
varying vec2 worldPos;
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vec4 view = TransformMatrix * vertex_position;
    vec3 v = vec3(view.xy / view.w, 1.0);
    worldPos = vec2(dot(toWorldX, v), dot(toWorldY, v));
    return ProjectionMatrix * vec4(VertexTexCoord.xy * maskSize, 0.0, 1.0);
}
#endif
#ifdef PIXEL
]] .. NOISE .. INSIDE .. [[
varying vec2 worldPos;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    float inside = insideAt(worldPos);
    if (inside <= 0.001) discard;
    return result(inside);
}
#endif
]]

-- the hair's paint pass: its mask is a square around the head in the head's own space (all the locks are
-- one strip sharing one picture's UVs, so a UV mask would mix them); a quad over the mask, each pixel
-- turned into its world place
local PAINT_HEAD = NOISE .. INSIDE .. [[
uniform vec2 headPos;
uniform float headAngle;
uniform float headR;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 l = (uv * 2.0 - 1.0) * headR;
    float c = cos(headAngle), s = sin(headAngle);
    float inside = insideAt(headPos + vec2(c * l.x - s * l.y, s * l.x + c * l.y));
    if (inside <= 0.001) discard;
    return result(inside);
}
]]

-- the part as seen, with its dirt. HEADSPACE: the hair, its mask place from where it's drawn around the head
local LOOK = [[
varying vec2 mUV;
#ifdef VERTEX
#ifdef HEADSPACE
uniform vec3 toWorldX;
uniform vec3 toWorldY;
uniform vec2 headPos;
uniform float headAngle;
uniform float headR;
#endif
vec4 position(mat4 transform_projection, vec4 vertex_position) {
#ifdef HEADSPACE
    vec4 view = TransformMatrix * vertex_position;
    vec3 v = vec3(view.xy / view.w, 1.0);
    vec2 w = vec2(dot(toWorldX, v), dot(toWorldY, v)) - headPos;
    float c = cos(-headAngle), s = sin(-headAngle);
    mUV = vec2(c * w.x - s * w.y, s * w.x + c * w.y) / (2.0 * headR) + 0.5;
#else
    mUV = VertexTexCoord.xy;
#endif
    return transform_projection * vertex_position;
}
#endif
#ifdef PIXEL
]] .. NOISE .. [[
uniform Image dirtMask;
uniform Image wetMask;
uniform vec2 maskTexel;
uniform float absorbScale;
uniform float strength;
uniform float splotch;
uniform float grain;
uniform float tide;
uniform float shine;
uniform float cracks;
uniform float lines;
uniform float grainSize;
uniform float seed;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 t = Texel(tex, uv) * color;
    vec4 m = Texel(dirtMask, mUV);
    float d = m.a;
    if (d < 0.004 || t.a < 0.004) return t;
    vec4 wm = Texel(wetMask, mUV);
    float w = wm.r;
    float pt = clamp(wm.g / d, 0.0, 1.0);             // how much of it is paint
    vec3 pigment = exp(-m.rgb / d * absorbScale);
    vec2 p = uv * grainSize + seed;
    float n = vnoise(p * 0.35) * 0.6 + vnoise(p * 1.3) * 0.4;
    // thin mud in splotches, thick mud all over (paint goes on more evenly)
    float th = mix(0.0, n * 0.9, splotch * (1.0 - 0.7 * pt));
    float cover = smoothstep(th - 0.08, th + 0.12, d) * min(1.0, d * 3.0);
    // the stuff itself: grainy mud, smooth paint; mud darker wet and lighter dry
    float gr = grain * (1.0 - 0.85 * pt);
    float g = vnoise(p * 4.0) * 0.6 + vnoise(p * 11.0) * 0.4;
    float clump = vnoise(p * 0.5 + 17.0);
    vec3 mud = pigment * (1.0 + gr * 0.9 * (g - 0.5)) * (1.0 + gr * 0.35 * (clump - 0.5));
    mud *= mix(mix(1.25, 0.72, w), mix(1.0, 0.92, w), pt);
    // the tide mark: darker where the dirt ends (the mask's neighbours differ)
    float edge = 0.0;
    for (int i = 0; i < 6; i++) {
        float a = float(i) * 1.047;
        edge = max(edge, abs(d - Texel(dirtMask, mUV + vec2(cos(a), sin(a)) * maskTexel * 2.0).a));
    }
    mud *= 1.0 - tide * 0.45 * smoothstep(0.15, 0.6, edge);
    // dried cracks: thin dark lines in thick dry mud (not paint)
    float cr = abs(vnoise(p * 0.8 + 11.0) - 0.5) + abs(vnoise(p * 2.1 + 5.0) - 0.5) * 0.35;
    mud *= 1.0 - cracks * (1.0 - pt) * (1.0 - w) * smoothstep(0.5, 0.9, d) * (1.0 - smoothstep(0.015, 0.04, cr)) * 0.5;
    // the drawing's dark lines still show through
    float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
    mud *= mix(1.0, 0.35 + lum, lines * (1.0 - smoothstep(0.12, 0.35, lum)));
    vec3 col = mix(t.rgb, mud, clamp(cover * strength, 0.0, 1.0));
    // wet glints: speckled on mud, a broad gloss on paint
    float glint = pow(vnoise(p * 1.6 + 31.0), 5.0) * 2.0 + pow(clump, 3.0) * 0.4;
    float gloss = smoothstep(0.55, 0.9, vnoise(p * 0.25 + 41.0)) * 0.9;
    col += shine * w * cover * mix(glint, gloss, pt) * 0.35;
    return vec4(clamp(col, 0.0, 1.0), t.a);
}
#endif
]]

local paintShader, lookShader, paintHeadShader, hairShader

local function shaders()
    paintShader = paintShader or love.graphics.newShader(PAINT)
    lookShader = lookShader or love.graphics.newShader(LOOK)
    paintHeadShader = paintHeadShader or love.graphics.newShader(PAINT_HEAD)
    hairShader = hairShader or love.graphics.newShader('#define HEADSPACE\n' .. LOOK)
end

-- a drawable's body (the hair strip along a head's outline keeps it as d.thing.body)
local function bodyOf(d) return d.body or (d.thing and d.thing.body) end
lib.bodyOf = bodyOf

-- A Mipo part's mask is keyed by a name that outlives the part: turning round (characterManager.switchFacing,
-- which happens all the time while a Mipo is dragged) makes every part's extra table anew, and a mask keyed
-- by the table was lost with it (2026-11-13: "while dragging a mipo can become completely clean"). Mipo id,
-- part, the fixture's subtype and label (the two brows), and its rank among those by zOffset (a part's two
-- strips: zOffset itself changes with the facing, a leg going to the front layer, but their order doesn't).
-- Strings stay in the weak table. Not a Mipo part: the extra table, as before.
local stableKeys = setmetatable({}, { __mode = 'k' })
local function stableKey(d)
    local extra = d.extra
    if not extra then return bodyOf(d) end
    local cached = stableKeys[extra]
    if cached then return cached end
    local body = bodyOf(d)
    local ud = body and not body:isDestroyed() and body:getUserData()
    local thing = ud and ud.thing
    local key = extra
    if thing and thing.mipoId and thing.mipoPartName then
        local fixtures, mine, at = body:getFixtures(), nil, 0
        for i, f in ipairs(fixtures) do
            local fud = f:getUserData()
            if fud and fud.extra == extra then mine, at = fud, i break end
        end
        if mine then
            local z, rank = extra.zOffset or 0, 0
            for i, f in ipairs(fixtures) do
                local fud = f:getUserData()
                if fud and fud ~= mine and fud.subtype == mine.subtype and fud.label == mine.label and fud.extra then
                    local fz = fud.extra.zOffset or 0
                    if fz < z or (fz == z and i < at) then rank = rank + 1 end
                end
            end
            key = table.concat({ thing.mipoId, thing.mipoPartName, tostring(mine.subtype), mine.label or '', rank }, '|')
        end
    end
    stableKeys[extra] = key
    return key
end
lib.stableKey = stableKey

-- the hair's mask: per Mipo (its locks are made again on a turn too)
local function hairKey(hair)
    local ud = hair.body and not hair.body:isDestroyed() and hair.body:getUserData()
    local thing = ud and ud.thing
    return (thing and thing.mipoId) and ('hair|' .. thing.mipoId) or hair
end

local function newMaskCanvas()
    local canvas = love.graphics.newCanvas(lib.MASK, lib.MASK, { dpiscale = 1 })
    canvas:setFilter('linear', 'linear')
    love.graphics.push('all')
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.pop()
    return canvas
end

-- a drawable's mask (made on first use)
local function maskOf(d, make, key)
    key = key and hairKey(key) or stableKey(d)
    local masks = data().masks
    local m = masks[key]
    if not m and make then
        m = { canvas = newMaskCanvas(), wet = newMaskCanvas(), wetT = 0, dryAcc = 0, seed = (love.math.random() * 97),
            key = key, load = 0, absorb = { 0, 0, 0 }, paint = 0, dripT = 0 }
        masks[key] = m
    end
    return m
end
lib.maskOf = maskOf

-- what's on a part (its lowest bit, roughly): r, g, b, how much (0..1), how much of it is paint
function lib.colorOf(m)
    if not m or m.load < 0.01 then return 1, 1, 1, 0, 0 end
    local a = { m.absorb[1] / m.load, m.absorb[2] / m.load, m.absorb[3] / m.load }
    local r, g, b = lib.colorOfAbsorb(a)
    return r, g, b, m.load, m.paint / m.load
end

-- the CPU copy follows the same blends as the masks: k of (absorb, paint) over what's there, or k of it off
local function cpuOver(m, absorb, paint, k)
    for i = 1, 3 do m.absorb[i] = absorb[i] * k + m.absorb[i] * (1 - k) end
    m.paint = paint * k + m.paint * (1 - k)
    m.load = k + m.load * (1 - k)
end
local function cpuOff(m, k)
    for i = 1, 3 do m.absorb[i] = m.absorb[i] * (1 - k) end
    m.paint, m.load = m.paint * (1 - k), m.load * (1 - k)
end
lib.cpuOff = cpuOff

-- the current transform's inverse: view (where TransformMatrix puts things) -> world
local function sendToWorld(shader)
    local ox, oy = love.graphics.transformPoint(0, 0)
    local ax, ay = love.graphics.transformPoint(1, 0)
    local bx, by = love.graphics.transformPoint(0, 1)
    local a, b, c, e = ax - ox, bx - ox, ay - oy, by - oy -- view = [a b; c e] * world + o
    local det = a * e - b * c
    if math.abs(det) < 1e-12 then return false end
    local ia, ib, ic, ie = e / det, -b / det, -c / det, a / det
    shader:send('toWorldX', { ia, ib, -(ia * ox + ib * oy) })
    shader:send('toWorldY', { ic, ie, -(ic * ox + ie * oy) })
    return true
end

-- The passes, for a part (draw) or a haircut (the head quad). pass = { canvas = 'canvas' | 'wet', blend =
-- 'alpha' (over) | 'multiply' (off), op = 0 | 1, channels = { r, g, b, a }, amount = vec4 }
local function setPass(shader, m, pass, uniforms)
    love.graphics.setCanvas(m[pass.canvas])
    love.graphics.setScissor()
    love.graphics.setStencilTest()
    love.graphics.setShader(shader)
    shader:send('amount', pass.amount)
    shader:send('op', pass.op or 0)
    for k, v in pairs(uniforms) do shader:send(k, v) end
    love.graphics.setBlendMode(pass.blend, 'premultiplied')
    local ch = pass.channels
    love.graphics.setColorMask(ch[1], ch[2], ch[3], ch[4])
    love.graphics.setColor(1, 1, 1, 1)
end

local function paint(d, draw, m, pass, uniforms)
    shaders()
    love.graphics.push('all')
    if not sendToWorld(paintShader) then love.graphics.pop() return end
    paintShader:send('maskSize', { lib.MASK, lib.MASK })
    setPass(paintShader, m, pass, uniforms)
    local outlines = state.drawingOutlines
    state.drawingOutlines = true -- (no light or material shaders of the engine's own)
    local ok, err = pcall(draw, d) -- (a drawer's stencil can't work on the mask: it fails and draws without)
    if not ok then data().lastError = tostring(err) end
    state.drawingOutlines = outlines
    love.graphics.pop()
end
-- one pass over a part (a wipe where it touches something: paint-marks.lua's prints)
lib.paintPass = paint

local ALL, RG = { true, true, true, true }, { true, true, false, false }

-- the passes for: soaking in a bath (k of its absorb and paint over what's there, wet), washing k off
-- (wet, the paint share off with it: the sponge too)
local function soakPasses(w, k)
    local a = w.absorb
    return {
        { canvas = 'canvas', blend = 'alpha', channels = ALL, amount = { a[1] * k, a[2] * k, a[3] * k, k } },
        { canvas = 'wet', blend = 'alpha', channels = RG, amount = { 1, w.paint * k, 0, k } },
    }
end
local function washPasses(k, wets)
    local passes = { { canvas = 'canvas', blend = 'multiply', op = 1, channels = ALL, amount = { k, k, k, k } } }
    if wets ~= false then
        passes[2] = { canvas = 'wet', blend = 'alpha', channels = RG, amount = { 1, 0, 0, k } }
    else -- (the paint share off with the rest, staying as wet as it is)
        passes[2] = { canvas = 'wet', blend = 'multiply', op = 1, channels = { false, true, false, false },
            amount = { k, k, k, k } }
    end
    return passes
end
lib.washPasses = washPasses

-- the liquids this frame: { level, x1, x2, y2, kind, absorb, paint, color } (kind from extra.dirtKind:
-- 'mud', 'paint' (extra.paintColor, a name in lib.PAINTS) or 'clean')
function lib.liquids()
    local out = {}
    for _, fixture in ipairs(registry.sfixturesOf(subtypes.LIQUID)) do
        if not fixture:isDestroyed() then
            local ud = fixture:getUserData()
            local extra = type(ud) == 'table' and ud.extra
            if extra and extra.dirtKind then
                local level, poly = liquid.water(extra, fixture:getBody())
                if level and #poly >= 6 then
                    local x1, x2, y2 = math.huge, -math.huge, -math.huge
                    for i = 1, #poly, 2 do
                        x1, x2, y2 = math.min(x1, poly[i]), math.max(x2, poly[i]), math.max(y2, poly[i + 1])
                    end
                    local kind = extra.dirtKind
                    local color = kind == 'paint' and (lib.PAINTS[extra.paintColor] or lib.PAINTS.red)
                        or kind == 'mud' and lib.mudColor() or nil
                    out[#out + 1] = { level = level, x1 = x1, x2 = x2, y2 = y2, kind = kind, color = color,
                        absorb = color and lib.absorbOf(color), paint = kind == 'paint' and 1 or 0, extra = extra }
                end
            end
        end
    end
    return out
end

-- roughly how far a drawable's body reaches (for "is it near")
local reach = setmetatable({}, { __mode = 'k' })
local function reachOf(body)
    if reach[body] then return reach[body] end
    local far = 20
    for _, f in ipairs(body:getFixtures()) do
        local shape = f:getShape()
        if shape:getType() == 'circle' then
            far = math.max(far, shape:getRadius() + math.sqrt(shape:getPoint() ^ 2))
        elseif shape.getPoints then
            local pts = { shape:getPoints() }
            for i = 1, #pts, 2 do far = math.max(far, math.sqrt(pts[i] ^ 2 + pts[i + 1] ^ 2)) end
        end
    end
    reach[body] = far * 2.5 -- (a ribbon limb is drawn past its own body)
    return reach[body]
end
lib.reachOf = reachOf

-- how much of a part (by its reach around its body) is below a level: 0..1
local function under(by, r, level) return math.max(0, math.min(1, (by + r - level) / (2 * r))) end

-- Painting is done in update, outside the frame: switching canvases in the middle of drawing (the
-- frame is drawn into water-look's canvas) cost ~15 fps. The wrap only notes what it drew (lib.note);
-- lib.paint then draws those into their masks with no camera, so the paint shader's world is plain.
local noted = setmetatable({}, { __mode = 'k' })
function lib.note(d, draw) noted[d] = draw end

-- one thing's mask (a part or a haircut) in the baths and under the sponge this frame. run(m, pass,
-- uniforms) does a pass, make(yes) gets (or makes) its mask. Returns the mask
-- Painting in a bath is done BATH_HZ times a second, not every frame, catching up the time in between (each mask
-- its own clock, so parts take turns), and only for parts whose body (with a margin for a ribbon limb drawn past
-- it) reaches the water: every part near a bath every frame was ~44 ms a frame with 20 Mipos on the phone (DIRT D5,
-- D8). The sponge stays every frame: it follows the finger.
lib.BATH_HZ = 20
local NEAR = 1.3 / 2.5 -- of reachOf's reach (which is 2.5 times the body's, for a ribbon limb): the bath test's
local function soakAndWash(m, bx, by, r, frame, run, make)
    local t = lib.tuning
    local frameDt = frame.dt or 1 / 60
    local dt = frameDt
    local inBath
    local near = r * NEAR
    for _, w in ipairs(frame.liquids) do
        if bx + near > w.x1 and bx - near < w.x2 and by + near > w.level and by - near < w.y2 then
            m = m or make(w.kind ~= 'clean')
            -- its turn? (a new mask paints at once)
            local due = true
            if m then
                m.bathAcc = (m.bathAcc or 1) + frameDt
                if m.bathAcc < 1 / lib.BATH_HZ then due = false else dt, m.bathAcc = m.bathAcc, 0 end
            end
            if m and not due then
                inBath = w
                m.wetT = t.dry
            elseif m then
                inBath = w
                local uniforms = { mode = 0, level = w.level, xRange = { w.x1, w.x2 }, wobble = t.wobble }
                local passes
                if w.kind == 'clean' then
                    local k = math.min(1, t.rinse * dt)
                    passes = washPasses(k)
                    cpuOff(m, k * under(by, r, w.level))
                else
                    local k = math.min(1, t.soak * dt)
                    passes = soakPasses(w, k)
                    if under(by, r, w.level) > 0 then cpuOver(m, w.absorb, w.paint, k) end
                end
                for _, pass in ipairs(passes) do run(m, pass, uniforms) end
                m.wetT = t.dry
            end
        end
    end
    local brush = frame.brush
    if m and brush and brush.moved > 0 and math.sqrt((bx - brush.x) ^ 2 + (by - brush.y) ^ 2) < r + t.sponge then
        local uniforms = { mode = 1, brush = { brush.x, brush.y }, brushR = t.sponge }
        local k = math.min(1, t.scrub * frameDt * math.min(1, brush.moved / 8))
        for _, pass in ipairs(washPasses(k)) do run(m, pass, uniforms) end
        cpuOff(m, k * 0.5)
        m.wetT = t.dry
    end
    if m then -- just out of a bath: it drips a while (paint-marks.lua)
        if m.inBath and not inBath then m.dripT, m.dripKind = 2.5, m.inBath.kind end
        m.inBath = inBath
    end
    return m
end

-- frame = { liquids = lib.liquids(), dt, brush = { x, y, moved } or nil, onPart = fn(d, draw, body, m) or nil }
function lib.paintPart(d, draw, frame)
    local body = bodyOf(d)
    local bx, by = body:getPosition()
    local m = soakAndWash(maskOf(d, false), bx, by, reachOf(body), frame,
        function(mask, pass, uniforms) paint(d, draw, mask, pass, uniforms) end,
        function(make) return maskOf(d, make) end)
    if frame.onPart and m then frame.onPart(d, draw, body, m) end
end

function lib.paint(frame)
    love.graphics.push('all')
    love.graphics.origin()
    for d, draw in pairs(noted) do
        local body = bodyOf(d)
        if body and not body:isDestroyed() then lib.paintPart(d, draw, frame) end
        noted[d] = nil
    end
    love.graphics.pop()
end

local LOOK_KEYS = { 'strength', 'splotch', 'grain', 'tide', 'shine', 'cracks', 'lines', 'grainSize' }
local function sendLook(shader, m)
    local t = lib.tuning
    shader:send('dirtMask', m.canvas)
    shader:send('wetMask', m.wet)
    shader:send('maskTexel', { 1 / lib.MASK, 1 / lib.MASK })
    shader:send('absorbScale', lib.ABSORB)
    shader:send('seed', m.seed)
    for _, k in ipairs(LOOK_KEYS) do shader:send(k, t[k]) end
end

-- d drawn with its dirt (if it has a mask)
function lib.drawPart(d, draw)
    lib.note(d, draw)
    local m = maskOf(d, false)
    if not m then return draw(d) end
    shaders()
    local outlines = state.drawingOutlines
    state.drawingOutlines = true
    love.graphics.setShader(lookShader)
    sendLook(lookShader, m)
    draw(d)
    love.graphics.setShader()
    state.drawingOutlines = outlines
end

-- ── the head hair ──
-- One mask per haircut, a square 2 * headR across around the head, in the head's own space (it turns with
-- the head; a lock swinging slides a little through it). Painted in update like the parts (lib.paintHair).
local notedHair = setmetatable({}, { __mode = 'k' })
local one -- a 1x1 white picture: the quad drawn over a mask (its UVs 0..1)

local function headR(hair) return reachOf(hair.body) * 1.2 end

local function paintHead(hair, m, pass, uniforms)
    love.graphics.push('all')
    love.graphics.origin()
    setPass(paintHeadShader, m, pass, uniforms)
    local hx, hy = hair.body:getPosition()
    paintHeadShader:send('headPos', { hx, hy })
    paintHeadShader:send('headAngle', hair.body:getAngle())
    paintHeadShader:send('headR', headR(hair))
    love.graphics.draw(one, 0, 0, 0, lib.MASK, lib.MASK)
    love.graphics.pop()
end

function lib.paintHair(frame)
    shaders()
    if not one then
        local px = love.image.newImageData(1, 1)
        px:setPixel(0, 0, 1, 1, 1, 1)
        one = love.graphics.newImage(px)
    end
    for hair in pairs(notedHair) do
        notedHair[hair] = nil
        if hair.body and not hair.body:isDestroyed() then
            local bx, by = hair.body:getPosition()
            soakAndWash(maskOf(nil, false, hair), bx, by, headR(hair), frame,
                function(mask, pass, uniforms) paintHead(hair, mask, pass, uniforms) end,
                function(make) return maskOf(nil, make, hair) end)
        end
    end
end

-- a holder's hair drawn with its dirt (state.hairWrap, src/hair-locks.lua)
function lib.drawHair(instance, wantFront, draw)
    local hair = instance.hairLocks
    if not hair or not hair.body or hair.body:isDestroyed() then return draw(instance, wantFront) end
    notedHair[hair] = true
    local m = maskOf(nil, false, hair)
    if not m then return draw(instance, wantFront) end
    shaders()
    if not sendToWorld(hairShader) then return draw(instance, wantFront) end
    local hx, hy = hair.body:getPosition()
    hairShader:send('headPos', { hx, hy })
    hairShader:send('headAngle', hair.body:getAngle())
    hairShader:send('headR', headR(hair))
    sendLook(hairShader, m)
    local outlines = state.drawingOutlines
    state.drawingOutlines = true -- (no lit hair shader of its own)
    love.graphics.setShader(hairShader)
    draw(instance, wantFront)
    love.graphics.setShader()
    state.drawingOutlines = outlines
end

-- a haircut's mask made (for fill all)
function lib.ensureHairMask(instance)
    local hair = instance.hairLocks
    return hair and hair.body and maskOf(nil, true, hair)
end

-- drying: every wet mask loses some wet (in steps the 8-bit mask can hold)
function lib.update(dt)
    local t = lib.tuning
    for _, m in pairs(data().masks) do
        if m.dripT > 0 then m.dripT = math.max(0, m.dripT - dt) end
        if m.wetT > 0 then
            m.wetT = m.wetT - dt
            m.dryAcc = m.dryAcc + dt / math.max(0.5, t.dry)
            if m.dryAcc >= 2 / 255 then
                love.graphics.push('all')
                love.graphics.setCanvas(m.wet)
                love.graphics.setShader()
                love.graphics.setBlendMode('subtract', 'premultiplied')
                love.graphics.setColorMask(true, false, false, false)
                love.graphics.setColor(m.dryAcc, 0, 0, 0)
                love.graphics.rectangle('fill', 0, 0, lib.MASK, lib.MASK)
                love.graphics.pop()
                m.dryAcc = 0
            end
        end
    end
end

-- a mask filled all over: amount of the current mud (0: clean), wet or not
function lib.fillMask(m, amount, wet)
    local a = lib.absorbOf(lib.mudColor())
    love.graphics.push('all')
    love.graphics.setCanvas(m.canvas)
    love.graphics.clear(a[1] * amount, a[2] * amount, a[3] * amount, amount)
    love.graphics.setCanvas(m.wet)
    love.graphics.clear(wet, 0, 0, 0)
    love.graphics.pop()
    m.load, m.paint, m.dripT, m.inBath = amount, 0, 0, nil
    m.absorb = { a[1] * amount, a[2] * amount, a[3] * amount }
    m.wetT = wet > 0 and lib.tuning.dry or 0
end

-- every mask filled at once: muddy all over, or clean
function lib.fillAll(amount, wet)
    for _, m in pairs(data().masks) do lib.fillMask(m, amount, wet) end
end

-- a drawable's mask made (so fillAll reaches parts that never touched mud)
function lib.ensureMask(d) return maskOf(d, true) end

return lib

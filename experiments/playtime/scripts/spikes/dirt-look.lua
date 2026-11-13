-- dirt-look.lua: Mipo parts getting dirty and clean again, by shader only (scene `dirty`, docs/DIRT.md).
--
-- Every part has its own dirt mask: a small canvas in the part's own picture space (its UVs), so the dirt
-- sticks to the part: a leg dipped in mud keeps its mud line where it was, tilted with the leg when it
-- swings. Red = how dirty, green = how wet (fresh mud is dark and shiny, dry mud lighter and cracked).
--
-- Painting: the part is drawn again, into its mask, through a shader that lays it out flat by its UVs
-- (the vertex shader puts each vertex at its UV) while still knowing where each pixel is in the world
-- (the vertex's place as drawn, back through the camera). So "below the mud's surface" or "under the
-- sponge" is decided per pixel in the world and written where that pixel lives on the part. Works for
-- any drawable whatever its kind (pictures, ribbon limbs, skinned meshes), as long as its UVs are its own.
--
-- Drawing: the part through a shader that reads its mask: mud in splotches where it's thin, all over
-- where it's thick, a darker tide mark at its edge, wet = darker and glinting, dry = lighter and cracked.
local state = require('src.state')
local registry = require('src.registry')
local subtypes = require('src.subtypes')
local liquid = require('src.liquid')

local lib = {}

lib.MASK = 128 -- mask size (px, square)

lib.tuning = {
    soak = 1.5,       -- per second under mud: how fast it gets dirty
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
    { name = 'paint', color = { 0.20, 0.38, 0.72 } },
}

local function data()
    state.dirtLook = state.dirtLook or { masks = setmetatable({}, { __mode = 'k' }), mud = 1 }
    return state.dirtLook
end
lib.data = data

local NOISE = [[
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
]]

-- is this world point in the mud / water (mode 0) or under the sponge (mode 1): shared by both paint passes
local INSIDE = [[
uniform float mode;      // 0: below a surface, 1: a round brush
uniform float level;
uniform vec2 xRange;
uniform float wobble;
uniform vec2 brush;
uniform float brushR;
uniform vec4 amount;
float insideAt(vec2 worldPos) {
    if (mode < 0.5) {
        float line = level + wobble * (vnoise(vec2(worldPos.x / 40.0, 3.0)) - 0.5
            + 0.5 * (vnoise(vec2(worldPos.x / 9.0, 7.0)) - 0.5));
        return step(line, worldPos.y) * step(xRange.x, worldPos.x) * step(worldPos.x, xRange.y);
    }
    float r = brushR * (0.85 + 0.3 * vnoise(worldPos / 12.0));
    return smoothstep(r, r * 0.5, distance(worldPos, brush));
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
    return amount * inside;
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
    return amount * inside;
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
uniform vec2 maskTexel;
uniform vec3 mudColor;
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
    float d = m.r, w = m.g;
    if (d < 0.004 || t.a < 0.004) return t;
    vec2 p = uv * grainSize + seed;
    float n = vnoise(p * 0.35) * 0.6 + vnoise(p * 1.3) * 0.4;
    // thin mud in splotches, thick mud all over
    float th = mix(0.0, n * 0.9, splotch);
    float cover = smoothstep(th - 0.08, th + 0.12, d) * min(1.0, d * 3.0);
    // the mud itself: grainy, darker wet, lighter dry
    float g = vnoise(p * 4.0) * 0.6 + vnoise(p * 11.0) * 0.4;
    float clump = vnoise(p * 0.5 + 17.0);
    vec3 mud = mudColor * (1.0 + grain * 0.9 * (g - 0.5)) * (1.0 + grain * 0.35 * (clump - 0.5));
    mud *= mix(1.25, 0.72, w);
    // the tide mark: darker where the dirt ends (the mask's neighbours differ)
    float edge = 0.0;
    for (int i = 0; i < 6; i++) {
        float a = float(i) * 1.047;
        edge = max(edge, abs(d - Texel(dirtMask, mUV + vec2(cos(a), sin(a)) * maskTexel * 2.0).r));
    }
    mud *= 1.0 - tide * 0.45 * smoothstep(0.15, 0.6, edge);
    // dried cracks: thin dark lines in thick dry mud
    float cr = abs(vnoise(p * 0.8 + 11.0) - 0.5) + abs(vnoise(p * 2.1 + 5.0) - 0.5) * 0.35;
    mud *= 1.0 - cracks * (1.0 - w) * smoothstep(0.5, 0.9, d) * (1.0 - smoothstep(0.015, 0.04, cr)) * 0.5;
    // the drawing's dark lines still show through
    float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
    mud *= mix(1.0, 0.35 + lum, lines * (1.0 - smoothstep(0.12, 0.35, lum)));
    vec3 col = mix(t.rgb, mud, clamp(cover * strength, 0.0, 1.0));
    // wet glints
    float glint = pow(vnoise(p * 1.6 + 31.0), 5.0) * 2.0 + pow(clump, 3.0) * 0.4;
    col += shine * w * cover * glint * 0.35;
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

-- a drawable's mask (made on first use)
local function maskOf(d, make, key)
    key = key or d.extra or bodyOf(d)
    local masks = data().masks
    local m = masks[key]
    if not m and make then
        local canvas = love.graphics.newCanvas(lib.MASK, lib.MASK, { dpiscale = 1 })
        canvas:setFilter('linear', 'linear')
        love.graphics.push('all')
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.pop()
        m = { canvas = canvas, wetT = 0, dryAcc = 0, seed = (love.math.random() * 97) }
        masks[key] = m
    end
    return m
end
lib.maskOf = maskOf

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

-- one paint pass of drawable d into its mask. kind: 'add' or 'subtract'; mask channels { r, g }
local function paint(d, draw, m, kind, channels, amount, uniforms)
    shaders()
    love.graphics.push('all')
    if not sendToWorld(paintShader) then love.graphics.pop() return end
    love.graphics.setCanvas(m.canvas)
    love.graphics.setScissor()
    love.graphics.setStencilTest()
    love.graphics.setShader(paintShader)
    paintShader:send('maskSize', { lib.MASK, lib.MASK })
    paintShader:send('amount', amount)
    for k, v in pairs(uniforms) do paintShader:send(k, v) end
    love.graphics.setBlendMode(kind, 'premultiplied')
    love.graphics.setColorMask(channels[1], channels[2], false, false)
    love.graphics.setColor(1, 1, 1, 1)
    local outlines = state.drawingOutlines
    state.drawingOutlines = true -- (no light or material shaders of the engine's own)
    local ok, err = pcall(draw, d) -- (a drawer's stencil can't work on the mask: it fails and draws without)
    if not ok then data().lastError = tostring(err) end
    state.drawingOutlines = outlines
    love.graphics.pop()
end

-- the liquids this frame: { level, x1, x2, y2, kind } (kind from extra.dirtKind: 'mud' or 'clean')
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
                    out[#out + 1] = { level = level, x1 = x1, x2 = x2, y2 = y2, kind = extra.dirtKind }
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

-- Painting is done in update, outside the frame: switching canvases in the middle of drawing (the
-- frame is drawn into water-look's canvas) cost ~15 fps. The wrap only notes what it drew (lib.note);
-- lib.paint then draws those into their masks with no camera, so the paint shader's world is plain.
local noted = setmetatable({}, { __mode = 'k' })
function lib.note(d, draw) noted[d] = draw end

-- frame = { liquids = lib.liquids(), dt, brush = { x, y, moved } or nil }
function lib.paintPart(d, draw, frame)
    local t = lib.tuning
    local body = bodyOf(d)
    local bx, by = body:getPosition()
    local r = reachOf(body)
    local dt = frame.dt or 1 / 60
    for _, w in ipairs(frame.liquids) do
        if bx + r > w.x1 and bx - r < w.x2 and by + r > w.level and by - r < w.y2 then
            local m = maskOf(d, w.kind == 'mud')
            if m then
                local uniforms = { mode = 0, level = w.level, xRange = { w.x1, w.x2 }, wobble = t.wobble }
                if w.kind == 'mud' then
                    paint(d, draw, m, 'add', { true, true }, { t.soak * dt, 1, 0, 0 }, uniforms)
                else
                    paint(d, draw, m, 'subtract', { true, false }, { t.rinse * dt, 0, 0, 0 }, uniforms)
                    paint(d, draw, m, 'add', { false, true }, { 0, 1, 0, 0 }, uniforms)
                end
                m.wetT = t.dry
            end
        end
    end
    local brush = frame.brush
    if brush and brush.moved > 0 then
        local m = maskOf(d, false)
        if m and math.sqrt((bx - brush.x) ^ 2 + (by - brush.y) ^ 2) < r + t.sponge then
            local uniforms = { mode = 1, brush = { brush.x, brush.y }, brushR = t.sponge }
            local rub = t.scrub * dt * math.min(1, brush.moved / 8)
            paint(d, draw, m, 'subtract', { true, false }, { rub, 0, 0, 0 }, uniforms)
            paint(d, draw, m, 'add', { false, true }, { 0, 5 * dt, 0, 0 }, uniforms) -- a wet sponge
            m.wetT = t.dry
        end
    end
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

-- d drawn with its dirt (if it has a mask)
function lib.drawPart(d, draw)
    local t = lib.tuning
    lib.note(d, draw)
    local m = maskOf(d, false)
    if not m then return draw(d) end
    shaders()
    local mud = lib.MUDS[data().mud] or lib.MUDS[1]
    local outlines = state.drawingOutlines
    state.drawingOutlines = true
    love.graphics.setShader(lookShader)
    lookShader:send('dirtMask', m.canvas)
    lookShader:send('maskTexel', { 1 / lib.MASK, 1 / lib.MASK })
    lookShader:send('mudColor', mud.color)
    lookShader:send('seed', m.seed)
    for _, k in ipairs({ 'strength', 'splotch', 'grain', 'tide', 'shine', 'cracks', 'lines', 'grainSize' }) do
        lookShader:send(k, t[k])
    end
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

local function sendLook(shader, m)
    local t = lib.tuning
    local mud = lib.MUDS[data().mud] or lib.MUDS[1]
    shader:send('dirtMask', m.canvas)
    shader:send('maskTexel', { 1 / lib.MASK, 1 / lib.MASK })
    shader:send('mudColor', mud.color)
    shader:send('seed', m.seed)
    for _, k in ipairs({ 'strength', 'splotch', 'grain', 'tide', 'shine', 'cracks', 'lines', 'grainSize' }) do
        shader:send(k, t[k])
    end
end

local function paintHead(hair, m, kind, channels, amount, uniforms)
    love.graphics.push('all')
    love.graphics.origin()
    love.graphics.setCanvas(m.canvas)
    love.graphics.setScissor()
    love.graphics.setShader(paintHeadShader)
    local hx, hy = hair.body:getPosition()
    paintHeadShader:send('headPos', { hx, hy })
    paintHeadShader:send('headAngle', hair.body:getAngle())
    paintHeadShader:send('headR', headR(hair))
    paintHeadShader:send('amount', amount)
    for k, v in pairs(uniforms) do paintHeadShader:send(k, v) end
    love.graphics.setBlendMode(kind, 'premultiplied')
    love.graphics.setColorMask(channels[1], channels[2], false, false)
    love.graphics.setColor(1, 1, 1, 1)
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
    local t = lib.tuning
    local dt = frame.dt or 1 / 60
    for hair in pairs(notedHair) do
        notedHair[hair] = nil
        if hair.body and not hair.body:isDestroyed() then
            local bx, by = hair.body:getPosition()
            local r = headR(hair)
            for _, w in ipairs(frame.liquids) do
                if bx + r > w.x1 and bx - r < w.x2 and by + r > w.level and by - r < w.y2 then
                    local m = maskOf(nil, w.kind == 'mud', hair)
                    if m then
                        local uniforms = { mode = 0, level = w.level, xRange = { w.x1, w.x2 }, wobble = t.wobble }
                        if w.kind == 'mud' then
                            paintHead(hair, m, 'add', { true, true }, { t.soak * dt, 1, 0, 0 }, uniforms)
                        else
                            paintHead(hair, m, 'subtract', { true, false }, { t.rinse * dt, 0, 0, 0 }, uniforms)
                            paintHead(hair, m, 'add', { false, true }, { 0, 1, 0, 0 }, uniforms)
                        end
                        m.wetT = t.dry
                    end
                end
            end
            local brush = frame.brush
            local m = maskOf(nil, false, hair)
            if m and brush and brush.moved > 0 and math.sqrt((bx - brush.x) ^ 2 + (by - brush.y) ^ 2) < r + t.sponge then
                local uniforms = { mode = 1, brush = { brush.x, brush.y }, brushR = t.sponge }
                paintHead(hair, m, 'subtract', { true, false },
                    { t.scrub * dt * math.min(1, brush.moved / 8), 0, 0, 0 }, uniforms)
                paintHead(hair, m, 'add', { false, true }, { 0, 5 * dt, 0, 0 }, uniforms)
                m.wetT = t.dry
            end
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
        if m.wetT > 0 then
            m.wetT = m.wetT - dt
            m.dryAcc = m.dryAcc + dt / math.max(0.5, t.dry)
            if m.dryAcc >= 2 / 255 then
                love.graphics.push('all')
                love.graphics.setCanvas(m.canvas)
                love.graphics.setShader()
                love.graphics.setBlendMode('subtract', 'premultiplied')
                love.graphics.setColorMask(false, true, false, false)
                love.graphics.setColor(0, m.dryAcc, 0, 0)
                love.graphics.rectangle('fill', 0, 0, lib.MASK, lib.MASK)
                love.graphics.pop()
                m.dryAcc = 0
            end
        end
    end
end

-- every mask filled (r, g) at once: muddy all over, or clean
function lib.fillAll(r, g)
    for _, m in pairs(data().masks) do
        love.graphics.push('all')
        love.graphics.setCanvas(m.canvas)
        love.graphics.clear(r, g, 0, 0)
        love.graphics.pop()
        m.wetT = g > 0 and lib.tuning.dry or 0
    end
end

-- a drawable's mask made (so fillAll reaches parts that never touched mud)
function lib.ensureMask(d) return maskOf(d, true) end

return lib

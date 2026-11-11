-- felt: Mipo parts made of felt (docs/FELT.md; Nikki 2026-11-11: felt first of the earlier materials to look at on
-- its own, "y"). On the drawing hook (state.drawableWrap, CUT-PAPER.md). The palette's felt (MATERIALS MT1b) was
-- a grain inside the shape; here each part also gets its edge: a few short shells past the outline keep only
-- stray fibres (a fuzzy halo), then the part itself through a felt shader: fibres whose direction wanders (one
-- direction made a triangle grid in the first materials spike), soft mottling, puffy (lit softly by the distance
-- in from its own edge), small dark needle pokes, matte, the drawing's lines softened as much as 'drawn lines'
-- says. The face stays as drawn. Space: the original. Keys: space, h.
local s = {}

local GROUND_Y = 600
local FELTY = { texfixture = true, ['foot-back'] = true, ['foot-front'] = true, ['connected-texture'] = true }

local function st()
    if not state.feltSpike then
        state.feltSpike = { showPanel = true, on = true, fibres = 0.7, fibreSize = 3, mottle = 0.5, puff = 0.7,
            pokes = 0.5, lines = 0.4, fuzz = 0.7, fuzzLength = 5, fuzzLayers = 4, soft = 0.5 }
    end
    return state.feltSpike
end

local NOISE = [[
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
// fibres: noise stretched along a direction that wanders over the felt, three layers at other angles
float fibres(vec2 p, float size, float seed) {
    float v = 0.0;
    for (int i = 0; i < 3; i++) {
        float a = vnoise(p / 40.0 + seed + float(i) * 13.1) * 6.28 + float(i) * 2.1;
        vec2 d = vec2(cos(a), sin(a));
        vec2 q = vec2(dot(p, d) / (size * 3.5), dot(p, vec2(-d.y, d.x)) / (size * 0.6));
        v += vnoise(q + float(i) * 7.3 + seed);
    }
    return v / 3.0;
}
]]

-- the part itself
local FELT = NOISE .. [[
uniform float fibreAmount;
uniform float fibreSize;
uniform float mottle;
uniform float puff;
uniform float pokes;
uniform float lines;
uniform float soft;
uniform float seed;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 t = Texel(tex, uv) * color;
    if (t.a < 0.02) discard;
    vec2 dx = dFdx(uv), dy = dFdy(uv);
    vec2 px = uv / vec2(length(dx), length(dy)); // the picture's own space in screen px
    // the distance in from the edge (rings of 8, 2..14 px) and which way the edge is
    float edge = 14.0;
    vec2 out2 = vec2(0.0);
    vec3 around = vec3(0.0);
    float n = 0.0;
    for (int ring = 1; ring <= 7; ring++) {
        float r = float(ring) * 2.0;
        vec2 dir = vec2(0.0);
        float found = 0.0;
        for (int i = 0; i < 8; i++) {
            float an = float(i) * 0.785 + float(ring) * 0.2;
            vec2 o = vec2(cos(an), sin(an));
            vec4 sm = Texel(tex, uv + (o.x * dx + o.y * dy) * r) * color; // (rings 1-3 also give the colour around)
            float outside = step(sm.a, 0.5);
            dir += o * outside;
            found = max(found, outside);
            // the colour around, the drawing's dark lines left out of it (else the outline stays dark)
            float w = (ring <= 3 && sm.a > 0.5) ? smoothstep(0.15, 0.45, dot(sm.rgb, vec3(0.299, 0.587, 0.114))) : 0.0;
            around += sm.rgb * w;
            n += w;
        }
        if (found > 0.5 && edge > 13.0) { edge = r - 1.0; out2 = dir; }
    }
    // the drawing's lines softened: its colour mixed with the colour around (felt has no hard lines)
    vec3 base = n > 0.05 ? around / n : t.rgb;
    float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
    vec3 col = mix(base, t.rgb, mix(lines, 1.0, smoothstep(0.35, 0.6, lum)));
    // felt colour: a little lighter and duller than paint
    col = mix(col, vec3(dot(col, vec3(0.333))), 0.12 * soft) * (1.0 + 0.06 * soft);
    // mottled: the wool not quite even
    col *= 1.0 + mottle * 0.18 * (vnoise(px / 18.0 + seed) - 0.5) + mottle * 0.1 * (vnoise(px / 6.0 + seed * 2.0) - 0.5);
    // fibres
    float f = fibres(px, fibreSize, seed);
    col *= 1.0 + fibreAmount * 0.4 * (f - 0.5);
    // puffy: rounded by the distance in, lit softly from the top left
    float dome = smoothstep(0.0, 14.0, edge);
    vec2 outward = length(out2) > 0.01 ? normalize(out2) : vec2(0.0);
    float light = dot(outward * (1.0 - dome), normalize(vec2(-0.7, -0.7)));
    col *= 1.0 + puff * (0.22 * light - 0.18 * (1.0 - dome));
    // needle pokes: small dark dimples here and there
    vec2 cell = floor(px / 7.0);
    vec2 inCell = fract(px / 7.0) - 0.5 - (vec2(hash(cell + seed), hash(cell + seed + 3.0)) - 0.5) * 0.6;
    float poke = step(0.82, hash(cell + seed * 1.7)) * smoothstep(0.18, 0.0, length(inCell));
    col *= 1.0 - pokes * 0.35 * poke;
    return vec4(clamp(col, 0.0, 1.0), t.a);
}
]]

-- a fuzz shell: only stray fibres, fading out
local FUZZ = NOISE .. [[
uniform float h;
uniform float fade;
uniform float seed;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 t = Texel(tex, uv) * color;
    if (t.a < 0.5) discard;
    vec2 pxuv = vec2(length(dFdx(uv)), length(dFdy(uv)));
    vec2 px = uv / pxuv;
    float f = fibres(px * 1.6, 1.4, seed + h * 3.0);
    if (f < 0.55 + h * 0.25) discard;
    // the fibres' colour from a little further in (here at the edge it's the drawn outline, dark), the
    // drawing's dark lines skipped
    vec2 inward = normalize(vec2(0.5) - uv + 0.0001);
    vec4 fill = Texel(tex, uv + inward * pxuv * 7.0) * color;
    vec3 c = dot(fill.rgb, vec3(0.299, 0.587, 0.114)) > 0.2 && fill.a > 0.5 ? fill.rgb : t.rgb;
    return vec4(c * 0.95, fade);
}
]]

local feltShader, fuzzShader
local sizes = {}
local function sizeOf(body)
    if sizes[body] then return sizes[body] end
    local far = 10
    for _, f in ipairs(body:getFixtures()) do
        local shape = f:getShape()
        if shape:getType() == 'circle' then
            far = math.max(far, shape:getRadius())
        elseif shape.getPoints then
            local pts = { shape:getPoints() }
            for i = 1, #pts, 2 do far = math.max(far, math.sqrt(pts[i] ^ 2 + pts[i + 1] ^ 2)) end
        end
    end
    sizes[body] = far
    return far
end

local seeds, seedCount = {}, 0
local function seedOf(d)
    local key = d.extra or d
    if not seeds[key] then
        seedCount = seedCount + 1
        seeds[key] = (seedCount * 7.31) % 97
    end
    return seeds[key]
end

local function original() return love.keyboard.isDown('space') end

local function wrap(d, draw)
    local c = st()
    if not c.on or original() or (state.scene and state.scene.id ~= 'felt') or not FELTY[d.type]
        or not d.mipoThing or not d.body or d.body:isDestroyed() then
        return draw(d)
    end
    feltShader = feltShader or love.graphics.newShader(FELT)
    fuzzShader = fuzzShader or love.graphics.newShader(FUZZ)
    local seed = seedOf(d)
    local outlines = state.drawingOutlines
    state.drawingOutlines = true -- the material shaders stand back
    -- the fuzzy halo first: short shells, only stray fibres, fading
    if c.fuzz > 0 then
        local scale = cam.scale or 1
        local bx, by = d.body:getPosition()
        local size = sizeOf(d.body)
        local reach = c.fuzzLength / scale
        local n = math.max(1, math.floor(c.fuzzLayers))
        love.graphics.setShader(fuzzShader)
        fuzzShader:send('seed', seed)
        for i = 1, n do
            local h = i / n
            local grow = 1 + reach * h / size
            fuzzShader:send('h', h)
            fuzzShader:send('fade', c.fuzz * (1 - h * 0.7))
            love.graphics.push()
            love.graphics.translate(bx, by)
            love.graphics.scale(grow, grow)
            love.graphics.translate(-bx, -by)
            draw(d)
            love.graphics.pop()
        end
    end
    love.graphics.setShader(feltShader)
    feltShader:send('fibreAmount', c.fibres)
    for _, name in ipairs({ 'fibreSize', 'mottle', 'puff', 'pokes', 'lines', 'soft' }) do
        feltShader:send(name, c[name])
    end
    feltShader:send('seed', seed)
    draw(d)
    love.graphics.setShader()
    state.drawingOutlines = outlines
end

-- ── the scene: soil, two Mipos ──
local function mipos()
    local list = {}
    for _, inst in pairs(mipoRegistry.getAll()) do
        if mipoKit.isAlive(inst) then list[#list + 1] = inst end
    end
    return list
end
local function ensureScene()
    if not getObjectsByLabel('ground')[1] then
        local thing = objectManager.addThing('rectangle', { x = 0, y = GROUND_Y + 300, width = 6000, height = 600,
            bodyType = 'static', label = 'ground' })
        if thing then
            local extra = fixtures.createSFixture(thing.body, 0, 0, 'tile-repeat', { radius = 20 }):getUserData().extra
            extra.main = extra.main or {}
            extra.main.bgURL, extra.opacity, extra.tileWidthM, extra.tileHeightM = 'world/ground/soil-01.jpg', 1, 0.6, 0.6
        end
    end
    for i = #mipos() + 1, 2 do
        local inst = characterManager.createCharacter('humanoid', -300 + (i - 1) * 500, GROUND_Y - 900, 0.9)
        if inst then characterManager.randomizeMipoConstrained(inst) end
    end
end

function s.onStart()
    worldState.paused = false
    st()
    ensureScene()
    state.drawableWrap = wrap
end

function s.onSceneUnload()
    if state.drawableWrap == wrap then state.drawableWrap = nil end
end

function s.onKeyPress(key)
    if key == 'h' then st().showPanel = not st().showPanel end
end

function s.drawBelow()
    state.drawableWrap = wrap -- (again: a reload of this script makes a new function)
end

-- ── the panel ──
local P = { w = 400, row = 30, pad = 10 }
local SLIDERS = { { 'fibres', 'fibres', 0, 1.5, 0.05 }, { 'fibreSize', 'fibre size', 1, 8, 0.25 },
    { 'mottle', 'mottled', 0, 1.5, 0.05 }, { 'puff', 'puffy', 0, 1.5, 0.05 }, { 'pokes', 'needle pokes', 0, 1.5, 0.05 },
    { 'lines', 'drawn lines', 0, 1, 0.05 }, { 'soft', 'felt colour', 0, 1, 0.05 }, { 'fuzz', 'fuzzy edge', 0, 1, 0.05 },
    { 'fuzzLength', 'fuzz length (px)', 1, 16, 0.5 }, { 'fuzzLayers', 'fuzz layers', 1, 8, 1 } }
function s.drawUI()
    local c = st()
    if not c.showPanel then return end
    ui.startFrame()
    local sw, sh = ui.getDimensions()
    local w, h = P.w, P.row * (1 + #SLIDERS + 1) + 40
    local x0, y0 = sw - w - 16, math.max(12, (sh - h) / 2)
    ui.panel(x0, y0, w, h, '•• felt ••', function()
        local x, y = x0 + P.pad, y0 + 32
        local inner = w - P.pad * 2
        local oc, ov = ui.checkbox(x, y + 2, c.on, 'felt (space: the original)')
        if oc then c.on = ov end
        y = y + P.row
        for _, sl in ipairs(SLIDERS) do
            ui.label(x, y + 5, sl[2])
            local value = ui.sliderWithInput('felt-' .. sl[1], x + 130, y - 4, inner - 220, sl[3], sl[4], c[sl[1]],
                nil, sl[5])
            if value then c[sl[1]] = value + 0 end
            y = y + P.row
        end
        ui.label(x, y + 5, 'space: the original   h panel')
    end)
end

return s

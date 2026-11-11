-- stone: Mipo parts carved in stone (docs/STONE.md; Nikki 2026-11-11: "sounds like we need some stone", then
-- "Mipo as stone"). On the drawing hook (state.drawableWrap, CUT-PAPER.md), like leather: each part drawn once
-- through a stone shader. The stone is a real scan (ambientCG CC0, textures/world/stone, colour + normal map),
-- in the part's own space so it moves with it; the shader finds the part's edge (rings of samples) and carves
-- it: a bevel lit like a chisel cut (light from the top left, its normal tilting out toward the nearest edge),
-- the outline chipped, the drawing's own lines cut in as grooves, cracks, moss in the lower dips. 'tint': a grey
-- statue (0) or the Mipo's own colours painted on the stone (1). The earlier stone (the material palette's cell
-- pattern, the burrow's shader rocks) was noise; this one is a scan. The face stays as drawn. Space: original.
local s = {}

local GROUND_Y = 600
local STONY = { texfixture = true, ['foot-back'] = true, ['foot-front'] = true, ['connected-texture'] = true }
local STONES = { { 'granite', 'stone-01' }, { 'sandstone', 'stone-02' }, { 'limestone', 'stone-03' },
    { 'ochre', 'stone-04' } }

local function st()
    if not state.stoneSpike then
        state.stoneSpike = { showPanel = true, on = true, stone = 1, tint = 0.35, scale = 1, bevel = 7, depth = 0.8,
            chips = 0.5, lines = 0.6, cracks = 0.4, moss = 0.3, bumps = 0.6 }
    end
    return state.stoneSpike
end

local STONE = [[
uniform Image stone;
uniform Image stoneNormal;
uniform float scale;
uniform float tint;
uniform float bevel;
uniform float depth;
uniform float chips;
uniform float lines;
uniform float cracks;
uniform float moss;
uniform float bumps;
uniform float seed;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 t = Texel(tex, uv) * color;
    if (t.a < 0.02) discard;
    vec2 dx = dFdx(uv), dy = dFdy(uv);
    vec2 px = uv / vec2(length(dx), length(dy)); // the picture's own space in screen px
    // the nearest edge: how far (rings of 8, 2..16 px) and which way (the outside samples of the first ring
    // that leaves the picture)
    float edge = 16.0;
    vec2 out2 = vec2(0.0);
    for (int ring = 1; ring <= 8; ring++) {
        float r = float(ring) * 2.0;
        vec2 dir = vec2(0.0);
        float found = 0.0;
        for (int i = 0; i < 8; i++) {
            float an = float(i) * 0.785 + float(ring) * 0.2;
            vec2 o = vec2(cos(an), sin(an));
            float outside = step(Texel(tex, uv + (o.x * dx + o.y * dy) * r).a, 0.5);
            dir += o * outside;
            found = max(found, outside);
        }
        if (found > 0.5 && edge > 15.0) { edge = r - 1.0; out2 = dir; }
    }
    // chipped: near the edge, bits knocked off
    float chip = vnoise(px / 5.0 + seed) * 0.7 + vnoise(px / 2.0 + seed) * 0.3;
    if (edge < chips * 4.0 * chip) discard;
    // the stone, in the part's own space
    vec2 suv = px / (512.0 * scale) + seed * 0.37;
    vec3 rock = Texel(stone, suv).rgb;
    vec3 n = Texel(stoneNormal, suv).rgb * 2.0 - 1.0;
    // the drawing's colour painted on it as much as 'tint' says (by its lightness: stone stays stone)
    float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
    float rockLum = dot(rock, vec3(0.299, 0.587, 0.114));
    vec3 col = mix(rock, t.rgb * (rockLum / max(lum, 0.05)) * 0.55 + t.rgb * 0.45, tint);
    // the bevel: within 'bevel' px of the edge the surface tilts out toward it
    float b = 1.0 - smoothstep(0.0, bevel, edge);
    vec2 outward = length(out2) > 0.01 ? normalize(out2) : vec2(0.0);
    vec3 normal = normalize(vec3(outward * b * depth * 1.6 + n.xy * bumps * 0.6, 1.0));
    vec3 L = normalize(vec3(-0.6, -0.7, 0.8)); // the top left (screen y down)
    float lit = dot(normal, L);
    col *= 0.55 + 0.6 * lit;
    // the drawing's own lines cut in as grooves: dark where the picture is dark, a light lip beside
    float groove = smoothstep(0.45, 0.1, lum) * smoothstep(1.5, 4.0, edge);
    col *= 1.0 - lines * 0.55 * groove;
    // cracks: a few thin dark lines, a lighter edge on one side
    float cr = abs(vnoise(px / vec2(55.0, 30.0) + seed * 2.0) * 2.0 - 1.0);
    float crack = smoothstep(0.05, 0.0, cr) * smoothstep(0.4, 0.6, vnoise(px / 90.0 + seed));
    col *= 1.0 - cracks * 0.6 * crack;
    // moss: in the lower dips near the edge, where it's damp
    float damp = smoothstep(0.45, 0.7, vnoise(px / 14.0 + seed * 5.0)) * (0.4 + 0.6 * b)
        * smoothstep(-0.2, 0.6, outward.y);
    vec3 green = vec3(0.32, 0.42, 0.18) * (0.7 + 0.6 * vnoise(px / 2.5 + seed));
    col = mix(col, green, moss * damp);
    return vec4(clamp(col, 0.0, 1.0), t.a);
}
]]
local shader
local images = {}
local function stoneImages(name)
    if not images[name] then
        local a = love.graphics.newImage('textures/world/stone/' .. name .. '.jpg')
        local b = love.graphics.newImage('textures/world/stone/' .. name .. '-normal.jpg')
        a:setWrap('repeat', 'repeat')
        b:setWrap('repeat', 'repeat')
        images[name] = { a, b }
    end
    return images[name]
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
    if not c.on or original() or (state.scene and state.scene.id ~= 'stone') or not STONY[d.type]
        or not d.mipoThing then
        return draw(d)
    end
    shader = shader or love.graphics.newShader(STONE)
    local img = stoneImages(STONES[c.stone][2])
    shader:send('stone', img[1])
    shader:send('stoneNormal', img[2])
    for _, name in ipairs({ 'scale', 'tint', 'bevel', 'depth', 'chips', 'lines', 'cracks', 'moss', 'bumps' }) do
        shader:send(name, c[name])
    end
    shader:send('seed', seedOf(d))
    local outlines = state.drawingOutlines
    state.drawingOutlines = true -- the material shaders stand back
    love.graphics.setShader(shader)
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
local SLIDERS = { { 'tint', 'tint (own colours)', 0, 1, 0.05 }, { 'scale', 'stone scale', 0.2, 3, 0.05 },
    { 'bevel', 'bevel (px)', 1, 16, 0.5 }, { 'depth', 'carving depth', 0, 2, 0.05 }, { 'bumps', 'bumps', 0, 2, 0.05 },
    { 'chips', 'chipped edge', 0, 1.5, 0.05 }, { 'lines', 'lines cut in', 0, 1, 0.05 },
    { 'cracks', 'cracks', 0, 1.5, 0.05 }, { 'moss', 'moss', 0, 1, 0.05 } }
function s.drawUI()
    local c = st()
    if not c.showPanel then return end
    ui.startFrame()
    local sw, sh = ui.getDimensions()
    local w, h = P.w, P.row * (2 + #SLIDERS + 1) + 40
    local x0, y0 = sw - w - 16, math.max(12, (sh - h) / 2)
    ui.panel(x0, y0, w, h, '•• stone ••', function()
        local x, y = x0 + P.pad, y0 + 32
        local inner = w - P.pad * 2
        local oc, ov = ui.checkbox(x, y + 2, c.on, 'stone (space: the original)')
        if oc then c.on = ov end
        y = y + P.row
        local tw = (inner - (#STONES - 1) * 4) / #STONES
        for i, stone in ipairs(STONES) do
            local label = c.stone == i and ('[' .. stone[1] .. ']') or stone[1]
            if ui.button(x + (i - 1) * (tw + 4), y, tw, label, P.row - 6) then c.stone = i end
        end
        y = y + P.row
        for _, sl in ipairs(SLIDERS) do
            ui.label(x, y + 5, sl[2])
            local value = ui.sliderWithInput('stone-' .. sl[1], x + 140, y - 4, inner - 230, sl[3], sl[4], c[sl[1]],
                nil, sl[5])
            if value then c[sl[1]] = value + 0 end
            y = y + P.row
        end
        ui.label(x, y + 5, 'space: the original   h panel')
    end)
end

return s

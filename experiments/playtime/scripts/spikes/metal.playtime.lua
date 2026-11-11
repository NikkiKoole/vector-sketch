-- metal: Mipo parts made of metal (docs/METAL.md; Nikki 2026-11-12: "do the metal one", after felt from the
-- earlier materials shortlist). On the drawing hook (state.drawableWrap, CUT-PAPER.md), like stone: each part
-- drawn once through a metal shader that finds its own edge (rings of samples: how far, which way). The surface
-- is rounded from it (a cushion) and reflects a studio round it (bright sky above, a dark horizon band, a warm
-- floor: the bands that say metal), with a sharp highlight from the top left; hammered dents or brushed streaks;
-- rivets a few px inside the outline; the drawing's own lines as seams (a groove with a bright lip); patina in
-- the dips (verdigris on brass and copper, rust on iron); and 'paint': the Mipo's own colours printed on the
-- metal as on a tin toy, worn off at the edges. The face stays as drawn. Space: the original. Keys: space, h.
local s = {}

local GROUND_Y = 600
local METALLIC = { texfixture = true, ['foot-back'] = true, ['foot-front'] = true, ['connected-texture'] = true }
-- name, colour, patina colour
local METALS = { { 'brass', 'd9b45a', '4f9a83' }, { 'copper', 'd8845a', '3f9c8a' }, { 'tin', 'c9ccd0', '8a8f86' },
    { 'iron', '7d7f84', 'a0522d' }, { 'chrome', 'eef2f6', '8c9096' } }

local function hex(h)
    return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 }
end

local function st()
    if not state.metalSpike then
        state.metalSpike = { showPanel = true, on = true, metal = 1, finish = 'hammered', round = 0.8, shine = 0.8,
            surface = 0.5, rivets = 0.7, rivetIn = 5, rivetGap = 14, seams = 0.6, patina = 0.35, paint = 0 }
    end
    return state.metalSpike
end

local METAL = [[
uniform vec3 metal;
uniform vec3 patinaColour;
uniform float finish;    // 0 hammered, 1 brushed, 2 smooth
uniform float roundness;
uniform float shine;
uniform float surface;
uniform float rivets;
uniform float rivetIn;
uniform float rivetGap;
uniform float seams;
uniform float patina;
uniform float paint;
uniform float seed;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
// the studio round the metal: a reflection's direction (y down on screen) to a colour
vec3 studio(vec3 r) {
    float up = -r.y + 0.3; // seen a little from above: a face-on surface catches some sky (else dull brown)
    vec3 sky = vec3(1.0, 0.98, 0.95);
    vec3 horizon = vec3(0.28, 0.27, 0.27); // (0.12: mostly dark, busy)
    vec3 floorc = vec3(0.45, 0.36, 0.28);
    vec3 c = up > 0.0 ? mix(horizon, sky, smoothstep(0.02, 0.55, up)) : mix(horizon, floorc, smoothstep(0.0, 0.6, -up));
    c += vec3(0.25) * smoothstep(0.55, 0.9, r.x) * step(0.0, up); // a window to one side
    return c;
}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 t = Texel(tex, uv) * color;
    if (t.a < 0.02) discard;
    vec2 dx = dFdx(uv), dy = dFdy(uv);
    vec2 px = uv / vec2(length(dx), length(dy));
    // the nearest edge: how far (2..16 px) and which way
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
    vec2 outward = length(out2) > 0.01 ? normalize(out2) : vec2(0.0);
    float rim = 1.0 - smoothstep(0.0, 16.0, edge);
    // the surface's tilt: rounded toward the edge, plus hammered dents or brushed streaks
    vec2 tilt = outward * rim * roundness * 1.4;
    // the whole part rounded top to bottom too: its top catches the sky, its bottom the warm floor
    tilt.y += (uv.y - 0.5) * roundness * 1.2;
    if (finish < 0.5) {
        // smooth hollows: the slope of a soft bumpy field (faceted cells caught a studio band each: a woven grid)
        float hc = vnoise(px / 11.0 + seed) + 0.5 * vnoise(px / 5.0 + seed * 2.0);
        float hx = vnoise((px + vec2(1.5, 0.0)) / 11.0 + seed) + 0.5 * vnoise((px + vec2(1.5, 0.0)) / 5.0 + seed * 2.0);
        float hy = vnoise((px + vec2(0.0, 1.5)) / 11.0 + seed) + 0.5 * vnoise((px + vec2(0.0, 1.5)) / 5.0 + seed * 2.0);
        tilt += vec2(hx - hc, hy - hc) * surface * 2.0;
    } else if (finish < 1.5) {
        tilt.y += (vnoise(vec2(px.x / 60.0, px.y / 0.8) + seed) - 0.5) * surface * 0.5;
    }
    vec3 n = normalize(vec3(tilt, 1.0));
    vec3 r = reflect(vec3(0.0, 0.0, -1.0), n);
    vec3 col = studio(r) * metal;
    // a sharp highlight from the top left
    vec3 L = normalize(vec3(-0.5, -0.65, 0.6));
    float spec = pow(max(dot(reflect(-L, n), vec3(0.0, 0.0, 1.0)), 0.0), 40.0);
    col += vec3(1.0, 0.97, 0.9) * spec * shine;
    col = mix(metal * 0.45, col, 0.4 + 0.6 * shine);
    // painted like a tin toy: the drawing's colours on top, worn off at the edges and the dents
    float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
    float wear = smoothstep(2.5, 5.0, edge) * smoothstep(0.35, 0.6, vnoise(px / 7.0 + seed) + 0.25);
    vec3 painted = t.rgb * (0.75 + 0.5 * dot(n, L)) + vec3(spec * 0.5);
    col = mix(col, painted, paint * wear);
    // seams: the drawing's dark lines as grooves, a bright lip below each
    float groove = smoothstep(0.42, 0.12, lum) * smoothstep(1.5, 4.0, edge);
    col *= 1.0 - seams * 0.6 * groove;
    // rivets: little domes in a row a few px inside the outline (counted along by the angle round the middle)
    vec2 mid = (uv - 0.5) / vec2(length(dx), length(dy));
    float along = fract(length(mid) * atan(mid.y, mid.x) / rivetGap);
    float rv = smoothstep(1.6, 0.6, abs(edge - rivetIn)) * smoothstep(0.25, 0.1, abs(along - 0.5));
    float rivetLight = clamp(0.5 - (along - 0.5) * 2.0 - (edge - rivetIn) * 0.3, 0.0, 1.0);
    col = mix(col, metal * (0.35 + 1.1 * rivetLight) + vec3(0.4) * rivetLight * rivetLight, rv * rivets);
    // patina in the dips: toward the edges and low down, where water sits
    float dip = smoothstep(0.5, 0.75, vnoise(px / 16.0 + seed * 3.0)) * (0.35 + 0.65 * rim) * smoothstep(-0.3, 0.7, outward.y);
    col = mix(col, patinaColour * (0.8 + 0.4 * vnoise(px / 3.0 + seed)), patina * dip);
    return vec4(clamp(col, 0.0, 1.0), t.a);
}
]]
local shader

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
local FINISHES = { 'hammered', 'brushed', 'smooth' }

local function wrap(d, draw)
    local c = st()
    if not c.on or original() or (state.scene and state.scene.id ~= 'metal') or not METALLIC[d.type]
        or not d.mipoThing then
        return draw(d)
    end
    shader = shader or love.graphics.newShader(METAL)
    local m = METALS[c.metal]
    shader:send('metal', hex(m[2]))
    shader:send('patinaColour', hex(m[3]))
    local fi = 0
    for i, f in ipairs(FINISHES) do if f == c.finish then fi = i - 1 end end
    shader:send('finish', fi)
    shader:send('roundness', c.round)
    for _, name in ipairs({ 'shine', 'surface', 'rivets', 'rivetIn', 'rivetGap', 'seams', 'patina', 'paint' }) do
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
local SLIDERS = { { 'round', 'rounded', 0, 2, 0.05 }, { 'shine', 'shine', 0, 1.5, 0.05 },
    { 'surface', 'dents / streaks', 0, 1.5, 0.05 }, { 'rivets', 'rivets', 0, 1, 0.05 },
    { 'rivetIn', 'rivets in (px)', 2, 12, 0.5 }, { 'rivetGap', 'rivet gap (px)', 6, 40, 1 },
    { 'seams', 'seams (lines)', 0, 1, 0.05 }, { 'patina', 'patina / rust', 0, 1, 0.05 },
    { 'paint', 'painted (tin toy)', 0, 1, 0.05 } }
local function buttonRow(x, y, inner, labels, picked, onPick)
    local bw = (inner - (#labels - 1) * 4) / #labels
    for i, label in ipairs(labels) do
        if ui.button(x + (i - 1) * (bw + 4), y, bw, picked(i) and ('[' .. label .. ']') or label, P.row - 6) then
            onPick(i)
        end
    end
end
function s.drawUI()
    local c = st()
    if not c.showPanel then return end
    ui.startFrame()
    local sw, sh = ui.getDimensions()
    local w, h = P.w, P.row * (3 + #SLIDERS + 1) + 40
    local x0, y0 = sw - w - 16, math.max(12, (sh - h) / 2)
    ui.panel(x0, y0, w, h, '•• metal ••', function()
        local x, y = x0 + P.pad, y0 + 32
        local inner = w - P.pad * 2
        local oc, ov = ui.checkbox(x, y + 2, c.on, 'metal (space: the original)')
        if oc then c.on = ov end
        y = y + P.row
        local names = {}
        for i, m in ipairs(METALS) do names[i] = m[1] end
        buttonRow(x, y, inner, names, function(i) return c.metal == i end, function(i) c.metal = i end)
        y = y + P.row
        buttonRow(x, y, inner, FINISHES, function(i) return c.finish == FINISHES[i] end,
            function(i) c.finish = FINISHES[i] end)
        y = y + P.row
        for _, sl in ipairs(SLIDERS) do
            ui.label(x, y + 5, sl[2])
            local value = ui.sliderWithInput('metal-' .. sl[1], x + 140, y - 4, inner - 230, sl[3], sl[4], c[sl[1]],
                nil, sl[5])
            if value then c[sl[1]] = value + 0 end
            y = y + P.row
        end
        ui.label(x, y + 5, 'space: the original   h panel')
    end)
end

return s

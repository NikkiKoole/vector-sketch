-- leather: Mipo parts as stitched leather (docs/LEATHER.md; Nikki 2026-11-11: "some more shader fun, with a
-- more leathered look?"). On the drawing hook (state.drawableWrap, CUT-PAPER.md): each part drawn once through
-- a leather shader that finds its own edge (the distance in from the edge of its picture, sampled in rings),
-- and puts there what says leather: a stitched seam a few px inside the outline (the stitches counted along
-- the edge by their angle round the picture's middle), the cut edge burnished darker, grain (fine pores lit
-- from the top left), a soft sheen on the rounded middle, creases and lighter scuffs. Colours: the part's own,
-- or a leather tone over it. The face (eyes, mouth, brows) stays as drawn. Space: the original. Keys: space, h.
local s = {}

local GROUND_Y = 600
local LEATHERY = { texfixture = true, ['foot-back'] = true, ['foot-front'] = true, ['connected-texture'] = true }
local TONES = { { 'own', nil }, { 'tan', 'b5835a' }, { 'brown', '6b4430' }, { 'black', '2a2523' },
    { 'oxblood', '6e2a2a' } }

local function hex(h)
    return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 }
end

local function st()
    if not state.leatherSpike then
        state.leatherSpike = { showPanel = true, on = true, tone = 1, toneMix = 0.5, stitch = 1, stitchIn = 4,
            stitchLen = 5, burn = 0.6, burnWidth = 3, grain = 0.6, sheen = 0.5, creases = 0.4, scuffs = 0.4 }
    end
    return state.leatherSpike
end

local LEATHER = [[
uniform vec3 tone;
uniform float toneMix;
uniform float stitch;
uniform float stitchIn;
uniform float stitchLen;
uniform float burn;
uniform float burnWidth;
uniform float grain;
uniform float sheen;
uniform float creases;
uniform float scuffs;
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
    // how far in from the edge (screen px): rings of 8 at growing radii until one leaves the picture
    float edge = 14.0;
    for (int ring = 1; ring <= 7; ring++) {
        float r = float(ring) * 2.0;
        float outside = 0.0;
        for (int i = 0; i < 8; i++) {
            float an = float(i) * 0.785 + float(ring) * 0.2;
            outside = max(outside, step(Texel(tex, uv + (cos(an) * dx + sin(an) * dy) * r).a, 0.5));
        }
        if (outside > 0.5) { edge = min(edge, r - 1.0); }
    }
    // the picture's own space in screen px (moves with the part), and round its middle
    vec2 px = uv / vec2(length(dx), length(dy));
    vec2 mid = (uv - 0.5) / vec2(length(dx), length(dy));
    float radius = length(mid);
    float theta = atan(mid.y, mid.x);

    vec3 col = mix(t.rgb, tone * (0.6 + 0.6 * dot(t.rgb, vec3(0.299, 0.587, 0.114))), toneMix);
    // grain: fine pores, a little bump lit from the top left
    // (pebbled: cells ~4 px; a 1.6 px grain read as knitted fabric)
    float g0 = vnoise(px / 4.0 + seed) * 0.7 + vnoise(px / 1.8 + seed) * 0.3;
    float gx = vnoise((px + vec2(1.0, 0.0)) / 4.0 + seed) * 0.7 - vnoise(px / 4.0 + seed) * 0.7;
    float gy = vnoise((px + vec2(0.0, 1.0)) / 4.0 + seed) * 0.7 - vnoise(px / 4.0 + seed) * 0.7;
    col *= 1.0 + grain * (-(gx + gy) * 1.6 - smoothstep(0.7, 0.9, g0) * 0.12);
    // creases: thin soft folds, dark in the dip, a light ridge beside
    float fold = abs(vnoise(px / vec2(40.0, 9.0) + seed * 3.0) * 2.0 - 1.0);
    col *= 1.0 - creases * (smoothstep(0.08, 0.0, fold) * 0.35 - smoothstep(0.2, 0.1, fold) * smoothstep(0.08, 0.12, fold) * 0.15);
    // scuffs: worn lighter, a bit duller, more toward the edges
    float scuff = smoothstep(0.62, 0.85, vnoise(px / 22.0 + seed * 7.0)) * (0.6 + 0.4 * smoothstep(12.0, 2.0, edge));
    col = mix(col, mix(col, vec3(dot(col, vec3(0.333))), 0.5) * 1.35, scuff * scuffs);
    // sheen: the middle rounded like a cushion (by the distance in), lit from the top left
    float dome = smoothstep(0.0, 14.0, edge);
    vec2 slope = normalize(mid + 0.0001) * (1.0 - dome);
    float light = clamp(dot(-slope, normalize(vec2(-0.7, -0.7))), 0.0, 1.0);
    col += sheen * 0.25 * pow(dome, 3.0) * smoothstep(0.4, 1.0, 1.0 - length(mid) / (radius + 60.0)) ;
    col *= 1.0 + sheen * 0.15 * (light - 0.3);
    // the cut edge burnished: darker, a thin gloss line on its inner side
    float b = smoothstep(burnWidth, 0.0, edge);
    col *= 1.0 - burn * 0.5 * b;
    col += burn * 0.08 * smoothstep(burnWidth + 1.5, burnWidth, edge) * smoothstep(burnWidth - 1.0, burnWidth, edge);
    // the stitched seam: dashes along the edge (counted by the angle round the middle), a dark hole at each end
    float band = smoothstep(1.2, 0.4, abs(edge - stitchIn));
    float along = fract(radius * theta / stitchLen);
    float dash = smoothstep(0.15, 0.25, along) * smoothstep(0.75, 0.65, along);
    float hole = smoothstep(0.12, 0.02, abs(along - 0.1)) + smoothstep(0.12, 0.02, abs(along - 0.9));
    vec3 thread = vec3(0.93, 0.88, 0.78) * (0.85 + 0.15 * (1.0 - abs(along - 0.5) * 2.0));
    col = mix(col, thread, band * dash * stitch * 0.9);
    col *= 1.0 - band * hole * stitch * 0.5;
    // the groove the seam sits in
    col *= 1.0 - stitch * 0.12 * smoothstep(2.0, 0.0, abs(edge - stitchIn)) * (1.0 - dash);
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

local function wrap(d, draw)
    local c = st()
    if not c.on or original() or (state.scene and state.scene.id ~= 'leather') or not LEATHERY[d.type]
        or not d.mipoThing then
        return draw(d)
    end
    shader = shader or love.graphics.newShader(LEATHER)
    local tone = TONES[c.tone][2]
    shader:send('tone', tone and hex(tone) or { 0.5, 0.5, 0.5 })
    shader:send('toneMix', tone and c.toneMix or 0)
    for _, name in ipairs({ 'stitch', 'stitchIn', 'stitchLen', 'burn', 'burnWidth', 'grain', 'sheen', 'creases',
        'scuffs' }) do
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
local SLIDERS = { { 'toneMix', 'tone', 0, 1, 0.05 }, { 'stitch', 'stitching', 0, 1, 0.05 },
    { 'stitchIn', 'seam in (px)', 1, 12, 0.5 }, { 'stitchLen', 'stitch (px)', 2, 14, 0.5 },
    { 'burn', 'burnished edge', 0, 1, 0.05 }, { 'burnWidth', 'edge width', 0.5, 8, 0.25 },
    { 'grain', 'grain', 0, 1.5, 0.05 }, { 'sheen', 'sheen', 0, 1.5, 0.05 }, { 'creases', 'creases', 0, 1.5, 0.05 },
    { 'scuffs', 'scuffs', 0, 1, 0.05 } }
function s.drawUI()
    local c = st()
    if not c.showPanel then return end
    ui.startFrame()
    local sw, sh = ui.getDimensions()
    local w, h = P.w, P.row * (2 + #SLIDERS + 1) + 40
    local x0, y0 = sw - w - 16, math.max(12, (sh - h) / 2)
    ui.panel(x0, y0, w, h, '•• leather ••', function()
        local x, y = x0 + P.pad, y0 + 32
        local inner = w - P.pad * 2
        local oc, ov = ui.checkbox(x, y + 2, c.on, 'leather (space: the original)')
        if oc then c.on = ov end
        y = y + P.row
        local tw = (inner - (#TONES - 1) * 4) / #TONES
        for i, tone in ipairs(TONES) do
            local label = c.tone == i and ('[' .. tone[1] .. ']') or tone[1]
            if ui.button(x + (i - 1) * (tw + 4), y, tw, label, P.row - 6) then c.tone = i end
        end
        y = y + P.row
        for _, sl in ipairs(SLIDERS) do
            ui.label(x, y + 5, sl[2])
            local value = ui.sliderWithInput('leather-' .. sl[1], x + 120, y - 4, inner - 210, sl[3], sl[4], c[sl[1]],
                nil, sl[5])
            if value then c[sl[1]] = value + 0 end
            y = y + P.row
        end
        ui.label(x, y + 5, 'space: the original   h panel')
    end)
end

return s

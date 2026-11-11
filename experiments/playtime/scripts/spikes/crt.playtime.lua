-- crt: the world on an old cathode-ray TV (docs/CRT.md; Nikki 2026-11-12: "can we do a noise/tv/interlaced light,
-- cathode ray"). A picture over the whole screen, as the riso spike's scene view: the world drawn into a canvas,
-- added into a history canvas that fades (the phosphor's afterglow: moving Mipos leave a short trail), then
-- shown through a CRT shader: the screen curved and darker at its corners, scanlines, interlaced (every other
-- line the field before, dimmer, swapping each frame), a phosphor mask (aperture grille or dot mask), glow
-- round the bright parts, colour fringes toward the edges and colour bleeding sideways, snow, a hum bar rolling
-- up, lines jittering sideways and now and then a burst of static. Sets: colour, black and white, green, amber.
-- Space: the plain picture. Keys: space, h.
local s = {}

local GROUND_Y = 600
local SETS = { { 'colour', 0 }, { 'b&w', 1 }, { 'green', 2 }, { 'amber', 3 } }
local MASKS = { 'grille', 'dots', 'none' }

local function st()
    if not state.crtSpike then
        state.crtSpike = { showPanel = true, on = true, set = 1, mask = 1, curve = 0.25, scan = 0.5, interlace = 0.35,
            maskAmount = 0.35, glow = 0.5, fringe = 1.2, bleed = 0.5, snow = 0.15, humbar = 0.25, jitter = 0.3,
            static = 0.3, afterglow = 0.5, vignette = 0.5, lineSize = 3, brightness = 1.0 }
    end
    return state.crtSpike
end

local CRT = [[
uniform vec2 res;
uniform float time;
uniform float field;      // 0 / 1, swapping each frame
uniform float set;        // 0 colour, 1 b&w, 2 green, 3 amber
uniform float maskType;   // 0 grille, 1 dots, 2 none
uniform float curve;
uniform float scan;
uniform float interlace;
uniform float maskAmount;
uniform float glow;
uniform float fringe;
uniform float bleed;
uniform float snow;
uniform float humbar;
uniform float jitter;
uniform float staticBurst;
uniform float vignette;
uniform float lineSize;
uniform float brightness;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec3 sampleAt(Image tex, vec2 uv) { return Texel(tex, clamp(uv, 0.0, 1.0)).rgb; }
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    // the curved screen
    vec2 c = uv * 2.0 - 1.0;
    c *= 1.0 + curve * 0.25 * vec2(c.y * c.y, c.x * c.x);
    vec2 q = c * 0.5 + 0.5;
    if (q.x < 0.0 || q.x > 1.0 || q.y < 0.0 || q.y > 1.0) return vec4(0.0, 0.0, 0.0, 1.0);
    float line = floor(q.y * res.y / lineSize);
    // the signal: lines jittering sideways, more when the static bursts
    float burst = staticBurst * step(0.93, hash(vec2(floor(time * 6.0), 1.7)));
    float wob = (hash(vec2(line, floor(time * 30.0))) - 0.5) * (jitter * 0.004 + burst * 0.03);
    wob += sin(q.y * 40.0 + time * 3.0) * jitter * 0.0008;
    q.x += wob;
    // colour fringes toward the edges, and colour bleeding sideways (the chroma smeared)
    vec2 off = c * fringe / res;
    vec3 col;
    col.r = sampleAt(tex, q + off).r;
    col.g = sampleAt(tex, q).g;
    col.b = sampleAt(tex, q - off).b;
    vec3 smear = vec3(0.0);
    for (int i = 1; i <= 4; i++) {
        smear += sampleAt(tex, q - vec2(float(i) * 1.5 / res.x, 0.0));
    }
    smear /= 4.0;
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    float smearLum = dot(smear, vec3(0.299, 0.587, 0.114));
    col = mix(col, vec3(lum) + (smear - vec3(smearLum)), bleed * 0.6); // light sharp, colour soft
    // glow round the bright parts
    vec3 bloom = vec3(0.0);
    for (int i = 0; i < 8; i++) {
        float a = float(i) * 0.785;
        bloom += sampleAt(tex, q + vec2(cos(a), sin(a)) * 4.0 / res);
        bloom += sampleAt(tex, q + vec2(cos(a + 0.4), sin(a + 0.4)) * 9.0 / res);
    }
    bloom /= 16.0;
    col += max(bloom - 0.45, 0.0) * glow * 1.6;
    // the set's phosphor
    float l2 = dot(col, vec3(0.299, 0.587, 0.114));
    if (set > 0.5 && set < 1.5) col = vec3(l2);
    else if (set > 1.5 && set < 2.5) col = vec3(0.25, 1.0, 0.45) * l2 * 1.1;
    else if (set > 2.5) col = vec3(1.0, 0.68, 0.2) * l2 * 1.1;
    // scanlines: dark between the lines, the beam fatter where it's bright
    float within = fract(q.y * res.y / lineSize);
    float beam = mix(1.0, smoothstep(0.0, 0.5, within) * smoothstep(1.0, 0.5, within) * 1.6, scan * (1.0 - l2 * 0.4));
    col *= beam;
    // interlaced: every other line the field before, dimmer
    if (mod(line + field, 2.0) > 0.5) col *= 1.0 - interlace * 0.5;
    // the phosphor mask
    if (maskType < 0.5) {
        float m = mod(sc.x, 3.0);
        vec3 grille = m < 1.0 ? vec3(1.0, 0.35, 0.35) : (m < 2.0 ? vec3(0.35, 1.0, 0.35) : vec3(0.35, 0.35, 1.0));
        col *= mix(vec3(1.0), grille * 1.5, maskAmount);
    } else if (maskType < 1.5) {
        vec2 cell = floor(sc / vec2(3.0, 3.0));
        float m = mod(sc.x + mod(cell.y, 2.0) * 1.5, 3.0);
        vec3 dots = m < 1.0 ? vec3(1.0, 0.3, 0.3) : (m < 2.0 ? vec3(0.3, 1.0, 0.3) : vec3(0.3, 0.3, 1.0));
        float round1 = 1.0 - smoothstep(0.3, 0.5, length(fract(sc / 3.0) - 0.5));
        col *= mix(vec3(1.0), dots * (0.6 + 0.9 * round1), maskAmount);
    }
    // the hum bar rolling up
    float bar = smoothstep(0.0, 0.15, fract(q.y + time * 0.12)) * smoothstep(0.35, 0.15, fract(q.y + time * 0.12));
    col *= 1.0 - humbar * 0.25 * bar;
    // snow, and a burst of static now and then
    float n = hash(sc + fract(time) * 731.0);
    col = mix(col, vec3(n), clamp(snow * 0.35 + burst * 0.6, 0.0, 1.0));
    // darker toward the corners
    col *= 1.0 - vignette * 0.6 * pow(length(c) * 0.72, 2.5);
    return vec4(col * brightness, 1.0);
}
]]
local shader
local canvas, history, previous

local function original() return love.keyboard.isDown('space') end

local function canvases(w, h)
    if not canvas or canvas:getWidth() ~= w or canvas:getHeight() ~= h then
        canvas = love.graphics.newCanvas(w, h)
        history = love.graphics.newCanvas(w, h)
        love.graphics.setCanvas(history)
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.setCanvas()
    end
end

function s.drawBelow()
    local c = st()
    c.capturing = false
    if not c.on or original() then return end
    local w, h = love.graphics.getDimensions()
    canvases(w, h)
    previous = love.graphics.getCanvas()
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(love.graphics.getBackgroundColor())
    c.capturing = true
end

function s.draw()
    local c = st()
    if not c.capturing then return end
    c.capturing = false
    love.graphics.push('all')
    love.graphics.origin()
    -- the afterglow: this frame laid over the fading last ones
    love.graphics.setCanvas(history)
    love.graphics.setColor(1, 1, 1, 1 - c.afterglow * 0.85)
    love.graphics.draw(canvas, 0, 0)
    love.graphics.pop()
    if previous then love.graphics.setCanvas({ previous, stencil = true }) else love.graphics.setCanvas() end
    previous = nil
    shader = shader or love.graphics.newShader(CRT)
    local w, h = love.graphics.getDimensions()
    shader:send('res', { w, h })
    shader:send('time', love.timer.getTime() % 1000)
    c.frame = ((c.frame or 0) + 1) % 2
    shader:send('field', c.frame)
    shader:send('set', SETS[c.set][2])
    shader:send('maskType', c.mask - 1)
    shader:send('staticBurst', c.static)
    for _, name in ipairs({ 'curve', 'scan', 'interlace', 'maskAmount', 'glow', 'fringe', 'bleed', 'snow', 'humbar',
        'jitter', 'vignette', 'lineSize', 'brightness' }) do
        shader:send(name, c[name])
    end
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader(shader)
    love.graphics.draw(history, 0, 0)
    love.graphics.setShader()
    love.graphics.pop()
end

-- ── the scene: soil, a wall, two Mipos ──
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
    if not getObjectsByLabel('wall')[1] then
        local w, h = 5200, 1700
        local thing = objectManager.addThing('rectangle', { x = 0, y = GROUND_Y - h / 2, width = w, height = h,
            bodyType = 'static', label = 'wall' })
        if thing then
            local wall = fixtures.createSFixture(thing.body, 0, 0, 'wall', { radius = 20 }):getUserData().extra
            wall.main.bgURL, wall.behind = 'world/walls/plaster-02.jpg', 160
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
end

function s.onKeyPress(key)
    if key == 'h' then st().showPanel = not st().showPanel end
end

-- ── the panel ──
local P = { w = 400, row = 28, pad = 10 }
local SLIDERS = { { 'curve', 'curved screen', 0, 1, 0.05 }, { 'scan', 'scanlines', 0, 1, 0.05 },
    { 'lineSize', 'line size (px)', 2, 8, 0.5 }, { 'interlace', 'interlaced', 0, 1, 0.05 },
    { 'maskAmount', 'phosphor mask', 0, 1, 0.05 }, { 'glow', 'glow', 0, 2, 0.05 }, { 'fringe', 'colour fringe', 0, 5, 0.1 },
    { 'bleed', 'colour bleed', 0, 1, 0.05 }, { 'afterglow', 'afterglow', 0, 0.95, 0.05 }, { 'snow', 'snow', 0, 1, 0.05 },
    { 'humbar', 'hum bar', 0, 1, 0.05 }, { 'jitter', 'jitter', 0, 1, 0.05 }, { 'static', 'static bursts', 0, 1, 0.05 },
    { 'vignette', 'dark corners', 0, 1, 0.05 }, { 'brightness', 'brightness', 0.5, 2, 0.05 } }
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
    local x0, y0 = sw - w - 16, math.max(8, (sh - h) / 2)
    ui.panel(x0, y0, w, h, '•• crt ••', function()
        local x, y = x0 + P.pad, y0 + 30
        local inner = w - P.pad * 2
        local oc, ov = ui.checkbox(x, y + 2, c.on, 'tv (space: the plain picture)')
        if oc then c.on = ov end
        y = y + P.row
        local names = {}
        for i, set in ipairs(SETS) do names[i] = set[1] end
        buttonRow(x, y, inner, names, function(i) return c.set == i end, function(i) c.set = i end)
        y = y + P.row
        buttonRow(x, y, inner, MASKS, function(i) return c.mask == i end, function(i) c.mask = i end)
        y = y + P.row
        for _, sl in ipairs(SLIDERS) do
            ui.label(x, y + 4, sl[2])
            local value = ui.sliderWithInput('crt-' .. sl[1], x + 130, y - 5, inner - 220, sl[3], sl[4], c[sl[1]], nil,
                sl[5])
            if value then c[sl[1]] = value + 0 end
            y = y + P.row
        end
        ui.label(x, y + 4, 'space: the plain picture   h panel')
    end)
end

return s

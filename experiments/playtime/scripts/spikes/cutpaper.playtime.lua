-- cutpaper: every drawn part a piece of painted paper, laid down in draw order (docs/CUT-PAPER.md; Nikki
-- 2026-11-11: "the cutpaper not great, like your idea to see if run on draw order changes it, can we spike that").
-- The riso spike's cut paper worked on the finished picture and broke busy textures into confetti. Here the
-- engine hands each drawable to the scene (state.drawableWrap), which draws it three times: its shadow (a
-- dark copy, offset), a torn white fringe (the shape grown a little, the growth uneven and patchy: the torn
-- paper's white core), then the piece itself (its colours with the drawing's lines softened away as wanted,
-- strokes and dabs of a painted sheet at its own angle, its edge torn inward a little). Each part's shadow
-- lands on the parts already laid, so the layering is the draw order. Space: the original. Keys: space, h.
local s = {}

local GROUND_Y = 600
local PAPERS = { { 'white', 'f6f2e8' }, { 'cream', 'efe4cc' }, { 'board', 'c9b48f' }, { 'blue', 'cfdbe6' } }

local function hex(h)
    return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 }
end

local function st()
    if not state.cutpaper then
        state.cutpaper = { showPanel = true, on = true, paper = 1, shadow = 10, dark = 0.3, fringe = 3,
            tear = 0.6, paint = 0.8, lines = 0.6, boil = 0 }
    end
    state.cutpaper.simplify = state.cutpaper.simplify or 4 -- (added after the first look)
    return state.cutpaper
end

local NOISE = [[
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { v += a * vnoise(p); p = p * 2.03 + 11.7; a *= 0.5; }
    return v / 0.9375;
}
]]

-- the shadow: the part's shape only, dark
local SHADOW = [[
uniform vec4 shade;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    return vec4(shade.rgb, step(0.5, Texel(tex, uv).a * color.a) * shade.a);
}
]]

-- the fringe: the shape grown by a few screen px (the uv per screen px from the derivatives, so it works on
-- pictures and meshes alike), the growth uneven and here and there none: torn paper's white core
local FRINGE = NOISE .. [[
uniform vec3 paper;
uniform float width;
uniform float tear;
uniform float seed;
uniform float simplify;
uniform vec2 origin;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 p = sc - origin;
    vec2 dx = dFdx(uv), dy = dFdy(uv);
    float patchy = smoothstep(0.35, 0.55, vnoise(p / 18.0 + seed * 3.7));
    float w = width * (0.4 + vnoise(p / 5.0 + seed) * 1.2) * mix(0.3, 1.0, mix(1.0, patchy, tear));
    // the cut shape (smoothed over 'simplify' px: no single hairs), grown by w
    float a = Texel(tex, uv).a;
    for (int i = 0; i < 12; i++) {
        float an = float(i) * 0.5236;
        vec2 o = cos(an) * dx + sin(an) * dy;
        a += Texel(tex, uv + o * simplify).a + Texel(tex, uv + o * (simplify + w)).a;
    }
    return vec4(paper, step(0.3, a / 25.0) * color.a);
}
]]

-- the piece: its colours (the drawing's lines softened away by 1 - lines), a painted sheet's strokes at
-- its own angle and dabs, the edge torn inward a little
local PIECE = NOISE .. [[
uniform float seed;
uniform float paint;
uniform float lines;
uniform float tear;
uniform float simplify;
uniform vec2 origin;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 p = sc - origin;
    vec4 t = Texel(tex, uv) * color;
    vec2 dx = dFdx(uv), dy = dFdy(uv);
    vec3 avg = t.a > 0.5 ? t.rgb : vec3(0.0);
    float n = t.a > 0.5 ? 1.0 : 0.0;
    // the cut shape: smoothed over 'simplify' px (torn: the radius wanders), so thin strands become one piece
    float r = simplify * (1.0 + tear * 0.6 * (vnoise(p / 4.0 + seed * 5.1) - 0.5)) + 0.5;
    float a = Texel(tex, uv).a;
    for (int i = 0; i < 12; i++) {
        float an = float(i) * 0.5236 + 0.26;
        vec2 o = cos(an) * dx + sin(an) * dy;
        vec4 sm = Texel(tex, uv + o * (simplify + 4.0)) * color;
        if (sm.a > 0.5) { avg += sm.rgb; n += 1.0; }
        a += Texel(tex, uv + o * r).a;
    }
    avg = n > 0.0 ? avg / n : t.rgb;
    float eroded = step(0.5, a / 13.0);
    // inside the drawing: its colours, its lines as wanted; between strands: the piece's average colour
    vec3 col = t.a > 0.5 ? mix(avg, t.rgb, lines) : avg;
    float an = fract(sin(seed * 91.7) * 43758.5) * 3.14;
    vec2 d = vec2(cos(an), sin(an));
    vec2 q = vec2(dot(p, d) / 20.0, dot(p, vec2(-d.y, d.x)) / 2.5);
    col *= 1.0 + ((vnoise(q + seed) - 0.5) * 0.35 + (fbm(p / 28.0 + seed) - 0.5) * 0.3) * paint;
    col += (vec3(vnoise(q * 0.4 + seed), vnoise(q * 0.4 + seed + 3.0), vnoise(q * 0.4 + seed + 6.0)) - 0.5) * paint * 0.06;
    return vec4(clamp(col, 0.0, 1.0), eroded * color.a);
}
]]

local shaders
local function shaderSet()
    if not shaders then
        shaders = { shadow = love.graphics.newShader(SHADOW), fringe = love.graphics.newShader(FRINGE),
            piece = love.graphics.newShader(PIECE) }
    end
    return shaders
end

-- a number per drawable: its sheet's angle and noise
local seeds = {} -- (scene scripts have no setmetatable: a plain table, the parts are few)
local seedCount = 0
local function seedOf(d)
    local key = d.extra or d
    if not seeds[key] then
        seedCount = seedCount + 1
        seeds[key] = (seedCount * 7.31) % 97
    end
    return seeds[key]
end

local function original() return love.keyboard.isDown('space') end

-- per frame: what every piece shares
local frame = {}
local function prepare()
    local c = st()
    local sh = shaderSet()
    local ox, oy = cam:getScreenCoordinates(0, 0)
    local boil = 0
    if c.boil > 0 then boil = (math.floor(love.timer.getTime() * c.boil) * 13.7) % 50 end
    frame.boil = boil
    sh.shadow:send('shade', { 0.12, 0.08, 0.05, c.dark })
    sh.fringe:send('paper', hex(PAPERS[c.paper][2]))
    sh.fringe:send('width', c.fringe)
    sh.fringe:send('tear', c.tear)
    sh.fringe:send('origin', { ox, oy })
    sh.piece:send('paint', c.paint)
    sh.piece:send('lines', c.lines)
    sh.piece:send('tear', c.tear)
    sh.piece:send('simplify', c.simplify)
    sh.fringe:send('simplify', c.simplify)
    sh.piece:send('origin', { ox, oy })
end

local function wrap(d, draw)
    local c = st()
    if not c.on or original() or (state.scene and state.scene.id ~= 'cutpaper') then return draw(d) end
    local sh = shaderSet()
    local seed = seedOf(d) + frame.boil
    -- the engine's material shaders (hair, plasticine) would replace ours: drawing for outlines, they stand back
    local outlines = state.drawingOutlines
    state.drawingOutlines = true
    local scale = cam.scale or 1
    love.graphics.push()
    love.graphics.translate(c.shadow / scale, c.shadow / scale)
    love.graphics.setShader(sh.shadow)
    draw(d)
    love.graphics.pop()
    love.graphics.setShader(sh.fringe)
    sh.fringe:send('seed', seed)
    draw(d)
    love.graphics.setShader(sh.piece)
    sh.piece:send('seed', seed)
    draw(d)
    love.graphics.setShader()
    state.drawingOutlines = outlines
end

-- ── the scene: soil, a few blocks, two Mipos ──
local function mipos()
    local list = {}
    for _, inst in pairs(mipoRegistry.getAll()) do
        if mipoKit.isAlive(inst) then list[#list + 1] = inst end
    end
    return list
end
local function block(label, x, y, w, h, url, tile)
    if getObjectsByLabel(label)[1] then return end
    local thing = objectManager.addThing('rectangle', { x = x, y = y, width = w, height = h, bodyType = 'static',
        label = label })
    if not thing then return end
    local extra = fixtures.createSFixture(thing.body, 0, 0, 'tile-repeat', { radius = 20 }):getUserData().extra
    extra.main = extra.main or {}
    extra.main.bgURL, extra.opacity, extra.tileWidthM, extra.tileHeightM = url, 1, tile, tile
end
local function ensureScene()
    block('ground', 0, GROUND_Y + 300, 6000, 600, 'world/ground/soil-01.jpg', 0.6)
    block('planks', -800, GROUND_Y - 150, 300, 300, 'world/walls/planks-01.jpg', 0.8)
    block('moss', 900, GROUND_Y - 60, 400, 120, 'world/ground/moss-01.jpg', 0.5)
    local have = #mipos()
    for i = have + 1, 2 do
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

-- the paper under everything, and what every piece shares this frame
function s.drawBelow()
    state.drawableWrap = wrap -- (again: a reload of this script makes a new function)
    prepare()
    local c = st()
    if not c.on or original() then return end
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(hex(PAPERS[c.paper][2]))
    love.graphics.rectangle('fill', 0, 0, love.graphics.getDimensions())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.pop()
end

-- ── the panel ──
local P = { w = 400, row = 30, pad = 10 }
local SLIDERS = { { 'shadow', 'shadow', 0, 30, 0.5 }, { 'dark', 'shadow dark', 0, 0.8, 0.02 },
    { 'fringe', 'white fringe', 0, 8, 0.25 }, { 'tear', 'tear', 0, 1, 0.05 }, { 'paint', 'paint', 0, 1.5, 0.05 },
    { 'lines', 'drawn lines', 0, 1, 0.05 }, { 'simplify', 'simplify', 0, 12, 0.5 }, { 'boil', 'boil (fps)', 0, 15, 1 } }
function s.drawUI()
    local c = st()
    if not c.showPanel then return end
    ui.startFrame()
    local sw, sh = ui.getDimensions()
    local w, h = P.w, P.row * (2 + #SLIDERS + 1) + 40
    local x0, y0 = sw - w - 16, math.max(12, (sh - h) / 2)
    ui.panel(x0, y0, w, h, '•• cut paper ••', function()
        local x, y = x0 + P.pad, y0 + 32
        local inner = w - P.pad * 2
        local bh = P.row - 6
        local oc, ov = ui.checkbox(x, y + 2, c.on, 'cut paper (space: the original)')
        if oc then c.on = ov end
        y = y + P.row
        local pw = (inner - 3 * 4) / 4
        for i, paper in ipairs(PAPERS) do
            local label = c.paper == i and ('[' .. paper[1] .. ']') or paper[1]
            if ui.button(x + (i - 1) * (pw + 4), y, pw, label, bh) then c.paper = i end
        end
        y = y + P.row
        for _, sl in ipairs(SLIDERS) do
            ui.label(x, y + 5, sl[2])
            local value = ui.sliderWithInput('cutpaper-' .. sl[1], x + 110, y - 4, inner - 200, sl[3], sl[4], c[sl[1]],
                nil, sl[5])
            if value then c[sl[1]] = value + 0 end
            y = y + P.row
        end
        ui.label(x, y + 5, 'space: the original   h panel')
    end)
end

return s

-- fur: Mipos with fur past their outline, from shell layers (docs/FUR-SHELLS.md; Nikki 2026-11-11: "another sort
-- of effect, fur, i know we have sort of this material but can we play with it here too, might get better").
-- The fur material (MATERIALS MT7) is drawn inside the shape only; its "not yet" was tufts past the outline,
-- shell layers and the direction following the body. Here each Mipo part (the cutpaper spike's hook,
-- state.drawableWrap) is drawn as a dark root, then as shells: copies pushed a little further out from the
-- part's centre and drooping with gravity, each keeping only the strands long enough to reach it (strands as
-- cells in the picture's own space, so a strand moves out with its shell: it grows past the outline),
-- thinner toward the tip, lighter at the tips, clumped, swaying in the wind. The face (eyes, mouth, brows)
-- stays as it is. Space: the original. Keys: space, h.
local s = {}

local GROUND_Y = 600
local FURRY = { texfixture = true, ['foot-back'] = true, ['foot-front'] = true, ['connected-texture'] = true }

local function st()
    if not state.furSpike then
        state.furSpike = { showPanel = true, on = true, shells = 10, length = 14, density = 3, thick = 0.8,
            clump = 0.5, droop = 0.5, root = 0.55, tip = 0.25, wind = 0.4, boil = 0 }
    end
    local c = state.furSpike -- (added after the first look: the cost)
    c.parts, c.mode, c.rebake = c.parts or 'torso+head', c.mode or 'shift', c.rebake or 0
    c.bakeScale = c.bakeScale or 0.5 -- bake once: px per world unit (the scenes' usual zoom)
    return state.furSpike
end

local FUR = [[
uniform float h;        // 0 the root .. 1 the tips
uniform float base;     // 1: the root layer (everything, dark)
uniform float density;  // strand cell, screen px
uniform float thick;
uniform float clump;
uniform float root;
uniform float tip;
uniform float seed;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 t = Texel(tex, uv) * color;
    if (t.a < 0.5) discard;
    if (base > 0.5) return vec4(t.rgb * root, t.a);
    // the strands in the picture's own space (screen px at this zoom), so they move out with the shell
    vec2 px = uv / vec2(length(dFdx(uv)), length(dFdy(uv)));
    vec2 cellp = px / density;
    float n = hash(floor(cellp) + seed);
    float c = vnoise(px / (density * 7.0) + seed);       // clumps: neighbours long together
    float len = mix(n, c, clump) * 0.85 + 0.15 * n;
    float r = length(fract(cellp) - 0.5);
    float width = thick * 0.5 * (1.0 - h * 0.8);         // thinner toward the tip
    if (len < h || r > width) discard;
    vec3 col = t.rgb * mix(root, 1.0 + tip, h);           // dark at the root, light at the tips
    return vec4(col, t.a);
}
]]
local furShader

-- how big a part is (world units, the farthest corner of its body's shapes): how far a shell pushes it out
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

local function original() return love.keyboard.isDown('space') end
local seeds, seedCount = {}, 0
local function seedOf(d)
    local key = d.extra or d
    if not seeds[key] then
        seedCount = seedCount + 1
        seeds[key] = (seedCount * 7.31) % 97
    end
    return seeds[key]
end

-- root and shells of one part, in whatever transform is current (the world's, or a bake canvas's)
-- opts.shellsOnly: no root layer (shift mode draws the root live); opts.still: no droop, no sway (shift
-- mode moves the whole baked layer instead)
local function drawFur(d, draw, c, seed, opts)
    opts = opts or {}
    local sh = furShader
    sh:send('density', c.density)
    sh:send('thick', c.thick)
    sh:send('clump', c.clump)
    sh:send('root', c.root)
    sh:send('tip', c.tip)
    sh:send('seed', seed)
    love.graphics.setShader(sh)
    if not opts.shellsOnly then
        sh:send('base', 1)
        sh:send('h', 0)
        draw(d)
    end
    sh:send('base', 0)
    local scale = opts.scale or cam.scale or 1
    local bx, by = d.body:getPosition()
    local size = sizeOf(d.body)
    local len = c.length / scale -- world units
    local t = love.timer.getTime()
    local n = math.max(1, math.floor(c.shells))
    for i = 1, n do
        local h = i / n
        local grow = 1 + len * h / size
        local droop = opts.still and 0 or c.droop * len * h * h
        local sway = opts.still and 0 or math.sin(t * 2.3 + seed) * c.wind * len * 0.5 * h * h
        sh:send('h', h)
        love.graphics.push()
        love.graphics.translate(bx + sway, by + droop)
        love.graphics.scale(grow, grow)
        love.graphics.translate(-bx, -by)
        draw(d)
        love.graphics.pop()
    end
    love.graphics.setShader()
end

-- baked: a part's fur drawn once into its own canvas (in the part's own frame, at the screen's resolution),
-- then drawn as one picture each frame, like any part. Baked again when the part has turned more than
-- REBAKE_TURN (the droop is baked in), the zoom changed, the settings changed, or every 1/rebake s (wind, boil).
local REBAKE_TURN = 1.2 -- (0.35 at first: limbs turn all the time, 94 bakes a second for 10 Mipos; the droop turning
-- with the part a little is fine)
local bakes = {}
local function settingsKey(c)
    return table.concat({ c.shells, c.length, c.density, c.thick, c.clump, c.droop, c.root, c.tip }, ' ')
end
-- opts as drawFur's, and opts.fade: keep the old bake to fade from (shift mode), opts.key: the settings
-- it was baked with
local function bake(d, draw, c, seed, b, opts)
    opts = opts or {}
    local scale = opts.scale or cam.scale or 1
    local bx, by = d.body:getPosition()
    local angle = d.body:getAngle()
    local reach = sizeOf(d.body) * 1.6 + (c.length / scale) * (1.3 + c.droop) -- the picture can reach past its body
    -- at the screen's resolution, but at most 1024 px: zoomed in, a big part is baked at less (and drawn
    -- stretched) instead of cut off at the canvas's edge (it was: empty bands where the fur should be)
    local k = math.min(scale, 1024 / (reach * 2))
    local px = math.ceil(reach * 2 * k)
    if opts.fade and b.canvas then -- the old one stays to fade from
        if b.old then b.old:release() end
        b.old, b.oldScale, b.oldAngle, b.fadeAt = b.canvas, b.scale, b.angle, love.timer.getTime()
        b.canvas = nil
    end
    if not b.canvas or b.canvas:getWidth() < px or b.canvas:getWidth() > px * 1.5 then
        if b.canvas then b.canvas:release() end
        b.canvas = love.graphics.newCanvas(px, px)
    end
    local size = b.canvas:getWidth()
    love.graphics.push('all')
    love.graphics.setCanvas({ b.canvas, stencil = true })
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.origin()
    love.graphics.translate(size / 2, size / 2)
    love.graphics.scale(k)
    love.graphics.rotate(-angle)
    love.graphics.translate(-bx, -by)
    love.graphics.setColor(1, 1, 1, 1)
    drawFur(d, draw, c, seed, opts)
    love.graphics.pop()
    b.scale, b.camScale, b.angle, b.at, b.key = k, scale, angle, love.timer.getTime(), opts.key or settingsKey(c)
    state.furSpike.bakes = (state.furSpike.bakes or 0) + 1
end

-- shift (the recommendation, FUR-SHELLS "the re-bake pop" way 3): the shells baked without droop as their own
-- layer, the part's dark root drawn live under them, and the layer moved every frame toward the real ground
-- (droop) and side to side (wind): a turn never bakes. A zoom or a slider change bakes, and the new bake
-- fades in over FADE s instead of popping.
local FADE = 0.25
local shiftBakes = {}
local function shiftKey(c) -- droop and wind aren't in the bake
    return table.concat({ c.shells, c.length, c.density, c.thick, c.clump, c.root, c.tip,
        c.once and c.bakeScale or 0 }, ' ')
end
local function drawLayer(canvas, bscale, bangle, x, y, angle, alpha)
    local size = canvas:getWidth()
    love.graphics.setColor(alpha, alpha, alpha, alpha) -- premultiplied
    love.graphics.draw(canvas, x, y, angle - bangle, 1 / bscale, 1 / bscale, size / 2, size / 2)
end
local function drawShifted(d, draw, c, seed)
    local key = d.extra or d
    local b = shiftBakes[key]
    if not b then b = {} shiftBakes[key] = b end
    -- bake once (c.once): at the bake scale, then never again but for a slider; the fur's length is then the
    -- world's (it zooms with the Mipo), not the screen's
    local fixed = c.once and c.bakeScale or nil
    local scale = fixed or cam.scale or 1
    local now = love.timer.getTime()
    local every = (not c.once) and ((c.boil > 0 and 1 / c.boil) or (c.rebake > 0 and 1 / c.rebake)) or nil
    local why = (not b.canvas and 'new') or (not fixed and math.abs(scale / b.camScale - 1) > 0.2 and 'zoom')
        or (b.key ~= shiftKey(c) and 'settings') or (every and now - b.at > every and 'timer') or nil
    if why then
        c.why = c.why or {}
        c.why[why] = (c.why[why] or 0) + 1
        bake(d, draw, c, seed, b, { shellsOnly = true, still = true, fade = b.canvas ~= nil, key = shiftKey(c),
            scale = fixed })
    end
    -- the root, live: the part darkened (the fur shader's base layer)
    local sh = furShader
    sh:send('root', c.root)
    sh:send('base', 1)
    sh:send('h', 0)
    love.graphics.setShader(sh)
    draw(d)
    love.graphics.setShader()
    -- the fur layer, hanging toward the ground and swaying, whichever way the part has turned
    local len = c.length / scale
    local bx, by = d.body:getPosition()
    local x = bx + math.sin(now * 2.3 + seed) * c.wind * len * 0.25
    local y = by + c.droop * len * 0.45
    local angle = d.body:getAngle()
    local f = b.fadeAt and math.min(1, (now - b.fadeAt) / FADE) or 1
    love.graphics.setBlendMode('alpha', 'premultiplied')
    if b.old and f < 1 then drawLayer(b.old, b.oldScale, b.oldAngle, x, y, angle, 1 - f) end
    drawLayer(b.canvas, b.scale, b.angle, x, y, angle, f)
    love.graphics.setBlendMode('alpha')
    love.graphics.setColor(1, 1, 1, 1)
    if b.old and f >= 1 then
        b.old:release()
        b.old, b.fadeAt = nil, nil
    end
end

local function furry(d)
    if not FURRY[d.type] or not d.mipoThing or not d.body or d.body:isDestroyed() then return false end
    if st().parts ~= 'torso+head' then return true end
    local _, part = mipoRegistry.getFromBody(d.body)
    return part ~= nil and (part == 'head' or part:match('^torso') ~= nil)
end

local function wrap(d, draw)
    local c = st()
    if not c.on or original() or (state.scene and state.scene.id ~= 'fur') or not furry(d) then
        return draw(d)
    end
    furShader = furShader or love.graphics.newShader(FUR)
    local seed = seedOf(d) + ((c.boil > 0) and (math.floor(love.timer.getTime() * c.boil) * 13.7) % 50 or 0)
    local outlines = state.drawingOutlines
    state.drawingOutlines = true -- the material shaders stand back
    if c.mode == 'shift' then
        drawShifted(d, draw, c, seed)
    elseif c.mode ~= 'baked' then
        drawFur(d, draw, c, seed)
    else
        local b = bakes[d.extra or d]
        if not b then b = {} bakes[d.extra or d] = b end
        local scale = cam.scale or 1
        local angle = d.body:getAngle()
        local every = (c.boil > 0 and 1 / c.boil) or (c.rebake > 0 and 1 / c.rebake) or nil
        -- why it bakes, counted on state.furSpike.why (new / turn / zoom / settings / timer: over the bridge)
        local why = (not b.canvas and 'new') or (math.abs(angle - b.angle) > REBAKE_TURN and 'turn')
            or (math.abs(scale / b.camScale - 1) > 0.2 and 'zoom') or (b.key ~= settingsKey(c) and 'settings')
            or (every and love.timer.getTime() - b.at > every and 'timer') or nil
        if why then
            c.why = c.why or {}
            c.why[why] = (c.why[why] or 0) + 1
            bake(d, draw, c, seed, b)
        end
        local bx, by = d.body:getPosition()
        local size = b.canvas:getWidth()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setBlendMode('alpha', 'premultiplied')
        love.graphics.draw(b.canvas, bx, by, angle - b.angle, 1 / b.scale, 1 / b.scale, size / 2, size / 2)
        love.graphics.setBlendMode('alpha')
    end
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
local SLIDERS = { { 'shells', 'shells', 1, 24, 1 }, { 'length', 'length', 0, 40, 0.5 },
    { 'density', 'strand gap', 1, 8, 0.25 }, { 'thick', 'thickness', 0.2, 1, 0.05 }, { 'clump', 'clumps', 0, 1, 0.05 },
    { 'droop', 'droop', 0, 2, 0.05 }, { 'root', 'root dark', 0.2, 1, 0.05 }, { 'tip', 'tips light', 0, 0.8, 0.05 },
    { 'wind', 'wind', 0, 2, 0.05 }, { 'boil', 'boil (fps)', 0, 15, 1 } }
function s.drawUI()
    local c = st()
    if not c.showPanel then return end
    ui.startFrame()
    local sw, sh = ui.getDimensions()
    local w, h = P.w, P.row * (3 + #SLIDERS + 3) + 40
    local x0, y0 = sw - w - 16, math.max(12, (sh - h) / 2)
    ui.panel(x0, y0, w, h, '•• fur ••', function()
        local x, y = x0 + P.pad, y0 + 32
        local inner = w - P.pad * 2
        local oc, ov = ui.checkbox(x, y + 2, c.on, 'fur (space: the original)')
        if oc then c.on = ov end
        y = y + P.row
        local bw = (inner - 4) / 2
        for i, parts in ipairs({ 'torso+head', 'all parts' }) do
            local on = (c.parts == 'torso+head') == (i == 1)
            if ui.button(x + (i - 1) * (bw + 4), y, bw, on and ('[' .. parts .. ']') or parts, P.row - 6) then
                c.parts = i == 1 and 'torso+head' or 'all'
            end
        end
        y = y + P.row
        local mw = (inner - 2 * 4) / 3
        for i, mode in ipairs({ 'shift', 'baked', 'live' }) do
            local on = c.mode == mode
            if ui.button(x + (i - 1) * (mw + 4), y, mw, on and ('[' .. mode .. ']') or mode, P.row - 6) then c.mode = mode end
        end
        y = y + P.row
        for _, sl in ipairs(SLIDERS) do
            ui.label(x, y + 5, sl[2])
            local value = ui.sliderWithInput('fur-' .. sl[1], x + 110, y - 4, inner - 200, sl[3], sl[4], c[sl[1]], nil,
                sl[5])
            if value then c[sl[1]] = value + 0 end
            y = y + P.row
        end
        if c.mode == 'shift' then
            local oc2, ov2 = ui.checkbox(x, y + 2, c.once, 'bake once')
            if oc2 then c.once = ov2 end
            if c.once then
                ui.label(x + 120, y + 5, 'at')
                local value = ui.sliderWithInput('fur-bakescale', x + 150, y - 4, inner - 240, 0.1, 2, c.bakeScale, nil, 0.05)
                if value then c.bakeScale = value + 0 end
            end
            y = y + P.row
        end
        if c.mode ~= 'live' and not (c.mode == 'shift' and c.once) then
            ui.label(x, y + 5, 'rebake (fps)')
            local value = ui.sliderWithInput('fur-rebake', x + 110, y - 4, inner - 200, 0, 15, c.rebake, nil, 1)
            if value then c.rebake = value + 0 end
        end
        y = y + P.row
        local stats = love.graphics.getStats()
        c.lastCalls = stats.drawcalls -- (for the cost measurement over the bridge)
        ui.label(x, y + 5, string.format('draw calls %d   bakes %d   (space: original)', stats.drawcalls,
            c.bakes or 0))
    end)
end

return s

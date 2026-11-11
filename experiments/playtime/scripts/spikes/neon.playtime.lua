-- neon: Mipos that give off light (docs/NEON.md; Nikki 2026-11-11: "i was outside and thinking, a neon, or light
-- emitting material?"). On the drawing hook (state.drawableWrap, CUT-PAPER.md). The Mipos' drawables are held
-- back from the world pass and drawn after it, over a night (the world darkened by 'night'): first a pool of
-- their light on what's around them (a soft radial glow, added), then each part: 'neon' makes the drawing's
-- own dark lines the tubes (white-hot core, coloured edge) and the rest dark glass; 'glow' makes the whole part
-- shine. A halo past the outline (scaled copies, added, fading out), a hum and now and then a neon stutter.
-- The face (eyes, mouth, brows) is drawn as it is, dimmed with the night. Space: the original. Keys: space, h.
local s = {}

local GROUND_Y = 600
local GLOWING = { texfixture = true, ['foot-back'] = true, ['foot-front'] = true, ['connected-texture'] = true }
local COLOURS = { { 'own', nil }, { 'pink', 'ff3fa4' }, { 'cyan', '3ff0ff' }, { 'lime', '9dff3f' },
    { 'orange', 'ffa23f' }, { 'violet', 'b56bff' } }

local function hex(h)
    return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 }
end

local function st()
    if not state.neonSpike then
        state.neonSpike = { showPanel = true, on = true, mode = 'neon', colour = 2, night = 0.8, power = 1.4,
            halo = 0.8, haloSize = 18, shells = 6, glass = 0.35, flicker = 0.4, pool = 0.6, poolSize = 900 }
    end
    return state.neonSpike
end

local GLOW = [[
uniform vec3 glow;
uniform float own;
uniform float mode;   // 0 neon tubes, 1 the whole part
uniform float power;
uniform float glass;
uniform float flick;
uniform float halo;   // 1: drawing a halo shell (colour only, by its own alpha)
uniform float fade;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 t = Texel(tex, uv) * color;
    if (t.a < 0.02) discard;
    float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
    vec3 g = mix(glow, t.rgb / max(max(t.rgb.r, max(t.rgb.g, t.rgb.b)), 0.05), own); // its own colour, full
    float tube = mode < 0.5 ? smoothstep(0.5, 0.15, lum) : 1.0;
    if (halo > 0.5) return vec4(g * tube * fade * flick, 1.0);
    if (mode < 0.5) {
        vec3 core = mix(g, vec3(1.0), 0.65 * smoothstep(0.3, 0.05, lum)); // white-hot in the middle of a line
        vec3 col = mix(t.rgb * glass * 0.3, core * power * flick, tube);
        return vec4(col, t.a);
    }
    vec3 col = mix(g * (0.45 + lum), vec3(1.0), smoothstep(0.65, 1.0, lum) * 0.5) * power * flick;
    return vec4(col, t.a);
}
]]
local DIM = [[
uniform float dim;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 t = Texel(tex, uv) * color;
    return vec4(t.rgb * dim, t.a);
}
]]
local glowShader, dimShader, poolImage

-- a soft round light, white in the middle fading to nothing (added in the light's colour)
local function pool()
    if not poolImage then
        local n = 256
        local data = love.image.newImageData(n, n)
        data:mapPixel(function(x, y)
            local d = math.sqrt((x - n / 2) ^ 2 + (y - n / 2) ^ 2) / (n / 2)
            local a = math.max(0, 1 - d)
            a = a * a * (3 - 2 * a)
            return a, a, a, 1
        end)
        poolImage = love.graphics.newImage(data)
    end
    return poolImage
end

-- how big a part is (world units), for its halo
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

-- the Mipos' drawables this frame, held back from the world pass (drawn in s.draw, in their order)
local held = {}
local function wrap(d, draw)
    local c = st()
    if not c.on or original() or (state.scene and state.scene.id ~= 'neon') or not d.mipoThing then
        return draw(d)
    end
    held[#held + 1] = { d, draw }
end

-- each Mipo's flicker: a hum, and now and then (neon) a stutter
local function flickOf(mipoId, now, c)
    local seed = (tonumber(tostring(mipoId):match('%d+')) or 7) % 97
    local hum = 1 - 0.04 * c.flicker * (0.5 + 0.5 * math.sin(now * 120 + seed))
    local beat = math.floor(now * 9 + seed * 3.1)
    local r = (math.sin(beat * 12.9898 + seed) * 43758.5453) % 1
    local stutter = (c.mode == 'neon' and r > 1 - 0.03 * c.flicker) and 0.25 or 1
    return hum * stutter
end

function s.drawBelow()
    state.drawableWrap = wrap -- (again: a reload of this script makes a new function)
    for i = #held, 1, -1 do held[i] = nil end
end

function s.draw()
    local c = st()
    if #held == 0 then return end
    glowShader = glowShader or love.graphics.newShader(GLOW)
    dimShader = dimShader or love.graphics.newShader(DIM)
    local colour = COLOURS[c.colour][2]
    local glowColour = colour and hex(colour) or { 1, 1, 1 }
    local now = love.timer.getTime()
    -- the night over everything drawn so far
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(0.02, 0.03, 0.08, c.night)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getDimensions())
    love.graphics.pop()
    -- the light's pool on what's around each Mipo (added)
    local seen = {}
    love.graphics.setBlendMode('add')
    for _, h in ipairs(held) do
        local d = h[1]
        local id = d.mipoThing.mipoId
        if not seen[id] and d.body and not d.body:isDestroyed() and GLOWING[d.type] then
            seen[id] = true
            local instance = mipoRegistry.getFromBody(d.body)
            local torso = instance and instance.parts and instance.parts.torso1
            local bx, by = (torso and torso.body or d.body):getPosition()
            local img = pool()
            local k = flickOf(id, now, c) * c.pool
            love.graphics.setColor(glowColour[1] * k, glowColour[2] * k, glowColour[3] * k, 1)
            love.graphics.draw(img, bx, by, 0, c.poolSize / 128, c.poolSize / 128, 128, 128)
        end
    end
    love.graphics.setBlendMode('alpha')
    -- the Mipos, in their order: glowing parts with their halo, the face as it is, dimmed with the night
    local outlines = state.drawingOutlines
    state.drawingOutlines = true -- the material shaders stand back
    glowShader:send('glow', glowColour)
    glowShader:send('own', colour and 0 or 1)
    glowShader:send('mode', c.mode == 'neon' and 0 or 1)
    glowShader:send('power', c.power)
    glowShader:send('glass', c.glass)
    local scale = cam.scale or 1
    for _, h in ipairs(held) do
        local d, draw = h[1], h[2]
        if GLOWING[d.type] and d.body and not d.body:isDestroyed() then
            local flick = flickOf(d.mipoThing.mipoId, now, c)
            glowShader:send('flick', flick)
            love.graphics.setShader(glowShader)
            -- the halo: copies a little bigger each, fading, added
            local n = math.max(1, math.floor(c.shells))
            if c.halo > 0 then
                local bx, by = d.body:getPosition()
                local size = sizeOf(d.body)
                local reach = c.haloSize / scale
                glowShader:send('halo', 1)
                love.graphics.setBlendMode('add')
                for i = 1, n do
                    local f = i / n
                    local grow = 1 + reach * f / size
                    glowShader:send('fade', c.halo * (1 - f) * (1 - f) * 2.2 / n)
                    love.graphics.push()
                    love.graphics.translate(bx, by)
                    love.graphics.scale(grow, grow)
                    love.graphics.translate(-bx, -by)
                    draw(d)
                    love.graphics.pop()
                end
                love.graphics.setBlendMode('alpha')
            end
            glowShader:send('halo', 0)
            draw(d)
        else
            dimShader:send('dim', 1 - c.night * 0.6)
            love.graphics.setShader(dimShader)
            draw(d)
        end
        love.graphics.setShader()
    end
    state.drawingOutlines = outlines
    love.graphics.setColor(1, 1, 1, 1)
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
    state.drawableWrap = wrap
end

function s.onSceneUnload()
    if state.drawableWrap == wrap then state.drawableWrap = nil end
end

function s.onKeyPress(key)
    if key == 'h' then st().showPanel = not st().showPanel end
end

-- ── the panel ──
local P = { w = 400, row = 30, pad = 10 }
local SLIDERS = { { 'night', 'night', 0, 1, 0.05 }, { 'power', 'brightness', 0.3, 3, 0.05 },
    { 'glass', 'glass (neon)', 0, 1, 0.05 }, { 'halo', 'halo', 0, 2, 0.05 }, { 'haloSize', 'halo size (px)', 2, 60, 1 },
    { 'shells', 'halo layers', 1, 16, 1 }, { 'flicker', 'hum / flicker', 0, 1, 0.05 }, { 'pool', 'light pool', 0, 2, 0.05 },
    { 'poolSize', 'pool size', 100, 3000, 25 } }
function s.drawUI()
    local c = st()
    if not c.showPanel then return end
    ui.startFrame()
    local sw, sh = ui.getDimensions()
    local w, h = P.w, P.row * (3 + #SLIDERS + 1) + 40
    local x0, y0 = sw - w - 16, math.max(12, (sh - h) / 2)
    ui.panel(x0, y0, w, h, '•• neon ••', function()
        local x, y = x0 + P.pad, y0 + 32
        local inner = w - P.pad * 2
        local oc, ov = ui.checkbox(x, y + 2, c.on, 'light (space: the original)')
        if oc then c.on = ov end
        y = y + P.row
        local mw = (inner - 4) / 2
        for i, mode in ipairs({ 'neon', 'glow' }) do
            local label = c.mode == mode and ('[' .. mode .. ']') or mode
            if ui.button(x + (i - 1) * (mw + 4), y, mw, label, P.row - 6) then c.mode = mode end
        end
        y = y + P.row
        local cw = (inner - (#COLOURS - 1) * 4) / #COLOURS
        for i, col in ipairs(COLOURS) do
            local label = c.colour == i and ('[' .. col[1] .. ']') or col[1]
            if ui.button(x + (i - 1) * (cw + 4), y, cw, label, P.row - 6) then c.colour = i end
        end
        y = y + P.row
        for _, sl in ipairs(SLIDERS) do
            ui.label(x, y + 5, sl[2])
            local value = ui.sliderWithInput('neon-' .. sl[1], x + 130, y - 4, inner - 220, sl[3], sl[4], c[sl[1]],
                nil, sl[5])
            if value then c[sl[1]] = value + 0 end
            y = y + P.row
        end
        ui.label(x, y + 5, 'space: the original   h panel')
    end)
end

return s

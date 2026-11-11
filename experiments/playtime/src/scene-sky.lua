-- scene-sky.lua — the scene's sky: a gradient over altitude that changes with the hour, from the
-- horizon up to black space (docs/SKY.md SK1). After ../sky-atmosphere (WORLD-BUILDING G5): colour stops
-- over altitude, one palette per time of day (night, dawn, day, dusk) at the same heights, blended stop by
-- stop in linear RGB along a timeline of the day. No stars (Nikki 2026-11-11: "take the stars out";
-- the experiment's came in with the night and with altitude). Heights as there (Nikki 2026-11-11):
-- black space at SPACE world units above the horizon.
--
-- A scene setting, saved with the scene (nothing when off): on, the hour, whether the day runs and how
-- long a day takes, the horizon's y. The clock runs as an engine system (src/systems.lua) while the world
-- runs; lib.draw paints the sky first thing in love.draw, under the backdrops and everything else.
-- Drawn as one mesh over the screen whose corners carry their world coordinates, so the shader knows
-- each pixel's altitude at any zoom, pixel density or canvas (scene thumbnails).
local state = require('src.state')
local cam = require('src.camera').getInstance()

local lib = {}

lib.SPACE = 60000        -- world units above the horizon: black from here up
lib.MOON_ALTITUDE = 120000

-- 0 = the horizon, 1 = space (fractions of SPACE)
local POSITIONS = { 0, 0.03, 0.1, 0.22, 0.42, 0.7, 1 }
local PALETTES = {
    night = { '233072', '192861', '12195a', '0a0f3a', '060a28', '02040f', '000000' },
    dawn  = { 'ffe467', 'fda65a', 'f06b7e', '7b5aa6', '2c2c74', '0a0f30', '000000' },
    day   = { 'efeebc', 'a3dec6', '61d0cf', '2f9fd0', '1c5fa8', '0b1f4a', '000000' },
    dusk  = { 'ffd364', 'f18448', 'ca5a92', '5b2c83', '28166b', '0b0b2a', '000000' },
}
-- the day as keyframes { hour, palette }: between two the palettes blend
local TIMELINE = {
    { 0, 'night' }, { 5, 'night' }, { 6.5, 'dawn' }, { 8.5, 'day' },
    { 17, 'day' }, { 19, 'dusk' }, { 20.5, 'night' }, { 24, 'night' },
}
-- how much of the night shows: 0 by day, 1 at night (for the light, SK2)
local NIGHTNESS = { { 0, 1 }, { 5, 1 }, { 7, 0 }, { 18.5, 0 }, { 20.5, 1 }, { 24, 1 } }

local DEFAULTS = { on = false, hour = 12, runs = false, dayLength = 120, horizon = 0 }

---------------------------------------------------------------- settings

function lib.settings()
    if not state.sceneSky then
        state.sceneSky = {}
        for k, v in pairs(DEFAULTS) do state.sceneSky[k] = v end
    end
    return state.sceneSky
end

function lib.isOn() return lib.settings().on == true end

function lib.load(saved)
    state.sceneSky = nil
    local s = lib.settings()
    if saved then
        s.on = true
        s.hour = tonumber(saved.hour) or DEFAULTS.hour
        s.runs = saved.runs == true
        s.dayLength = tonumber(saved.dayLength) or DEFAULTS.dayLength
        s.horizon = tonumber(saved.horizon) or DEFAULTS.horizon
    end
    return s
end

-- for a scene file: nothing when off, so files stay as they were
function lib.save()
    local s = lib.settings()
    if not s.on then return nil end
    return { hour = s.hour, runs = s.runs or nil, dayLength = s.dayLength, horizon = s.horizon }
end

-- the horizon where the Mipos' feet are (the lowest foot); false without Mipos
function lib.horizonAtFeet()
    local lowest
    for _, instance in pairs(require('src.mipo-registry').getAll()) do
        for _, name in ipairs({ 'lfoot', 'rfoot' }) do
            local part = instance.parts and instance.parts[name]
            local body = part and part.body
            if body and not body:isDestroyed() then
                for _, fixture in ipairs(body:getFixtures()) do
                    local _, _, _, y2 = fixture:getBoundingBox()
                    lowest = math.max(lowest or y2, y2)
                end
            end
        end
    end
    if not lowest then return false end
    lib.settings().horizon = math.floor(lowest + 0.5)
    return true
end

---------------------------------------------------------------- the clock

-- the world runs (src/systems.lua): the hour goes round once a dayLength while the day runs
function lib.update(dt)
    local s = lib.settings()
    if not (s.on and s.runs) then return end
    s.hour = (s.hour + dt * 24 / math.max(1, s.dayLength)) % 24
end

---------------------------------------------------------------- the sky's colours

local function toLinear(c) return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
local function hexLinear(hex)
    return toLinear(tonumber(hex:sub(1, 2), 16) / 255), toLinear(tonumber(hex:sub(3, 4), 16) / 255),
        toLinear(tonumber(hex:sub(5, 6), 16) / 255)
end
local function lerp(a, b, t) return a + (b - a) * t end
local function smoothstep(t)
    t = math.max(0, math.min(1, t))
    return t * t * (3 - 2 * t)
end

-- a piecewise-linear lookup in { { x, y }, ... }
local function curve(points, x)
    for i = 2, #points do
        local a, b = points[i - 1], points[i]
        if x <= b[1] then return lerp(a[2], b[2], (x - a[1]) / (b[1] - a[1])) end
    end
    return points[#points][2]
end

-- the stops at an hour: colours (linear RGB) and positions, and how much night
function lib.stopsAt(hour)
    hour = hour % 24
    local a, b, t = TIMELINE[1], TIMELINE[1], 0
    for i = 2, #TIMELINE do
        if hour <= TIMELINE[i][1] then
            a, b = TIMELINE[i - 1], TIMELINE[i]
            t = smoothstep((hour - a[1]) / (b[1] - a[1]))
            break
        end
    end
    local pa, pb = PALETTES[a[2]], PALETTES[b[2]]
    local colors = {}
    for i = 1, #POSITIONS do
        local r1, g1, b1 = hexLinear(pa[i])
        local r2, g2, b2 = hexLinear(pb[i])
        colors[i] = { lerp(r1, r2, t), lerp(g1, g2, t), lerp(b1, b2, t) }
    end
    return colors, POSITIONS, curve(NIGHTNESS, hour)
end

---------------------------------------------------------------- drawing

local SHADER = ([[
    #define N %d
    extern vec3 stopColor[N];
    extern float stopPos[N];
    extern float horizon;
    extern float space;

    vec4 effect(vec4 color, Image tex, vec2 world, vec2 sc) {
        float alt = (horizon - world.y) / space;
        vec3 c = stopColor[0];
        for (int i = 1; i < N; i++) {
            if (alt >= stopPos[i - 1]) {
                float t = clamp((alt - stopPos[i - 1]) / (stopPos[i] - stopPos[i - 1]), 0.0, 1.0);
                c = mix(stopColor[i - 1], stopColor[i], t);
            }
        }
        return vec4(pow(c, vec3(1.0 / 2.2)), 1.0);
    }
]]):format(#POSITIONS)

-- made on first use (and again after a hot swap: module locals start empty)
local shader, mesh

function lib.draw()
    local s = lib.settings()
    if not s.on then return end
    if not shader then
        shader = love.graphics.newShader(SHADER)
        mesh = love.graphics.newMesh(4, 'fan', 'stream')
    end
    local w, h = love.graphics.getDimensions()
    local corners = { { 0, 0 }, { w, 0 }, { w, h }, { 0, h } }
    local vertices = {}
    for i, c in ipairs(corners) do
        local wx, wy = cam:getWorldCoordinates(c[1], c[2])
        vertices[i] = { c[1], c[2], wx, wy, 1, 1, 1, 1 }
    end
    mesh:setVertices(vertices)
    local colors, positions = lib.stopsAt(s.hour)
    shader:send('stopColor', unpack(colors))
    shader:send('stopPos', unpack(positions))
    shader:send('horizon', s.horizon)
    shader:send('space', lib.SPACE)
    love.graphics.push('all')
    love.graphics.origin()
    love.graphics.setShader(shader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(mesh)
    love.graphics.pop()
end

return lib

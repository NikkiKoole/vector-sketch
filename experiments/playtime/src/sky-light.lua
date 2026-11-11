-- sky-light.lua — the light at the sky's hour (docs/SKY.md SK2): a scene with a sky (src/scene-sky.lua) and
-- a light level (src/scene-light.lua) gets its sun, moon, sky light and back light from the clock, and its
-- shadows (contact, wall, 3D) turn and stretch with them. From light-grass-check (LIGHT-AND-SHADOW): five
-- looks blended by the hour (night, dawn, day, golden hour, dusk), the sun on an arc from 6:00 to 18:00
-- and the moon from 17:00 to 7:00 (they overlap an hour at each handover, so the light swings across
-- instead of going through a moment with almost none: Nikki 2026-11-06 "some transitions aren't
-- smooth"), the sun's and the moon's shadows blended by how strong each is, never "pick the stronger".
-- lib.fill writes the hour's values into the light level's own tables (made for a sky scene, not the
-- shared defaults), every frame, without making new ones.
local lib = {}

-- each: the sky light (colour, ground colour, strength), the sun's and moon's colour and strength at
-- their highest, the back light, how dark the contact and the wall shadows are (light-grass-check's,
-- its sky light at its 1.3 strength)
local LOOKS = {
    night = { sun = { 'fff2d9', 0 }, moon = { 'a8c0ff', 0.35 }, skyLight = { '3a4a80', '141420', 0.39 },
        back = { 'a8c0ff', 1.8 }, shadows = 0.3, wallShadows = 0.2 },
    dawn = { sun = { 'ffb070', 0.8 }, moon = { 'a8c0ff', 0.15 }, skyLight = { 'ffb0a0', '604050', 0.585 },
        back = { 'ffc080', 2.0 }, shadows = 0.4, wallShadows = 0.3 },
    day = { sun = { 'fff2d9', 1.2 }, moon = { 'a8c0ff', 0 }, skyLight = { '9cc8ff', '8a7a50', 0.78 },
        back = { 'ffffff', 0.6 }, shadows = 0.5, wallShadows = 0.35 },
    golden = { sun = { 'ffd890', 1.1 }, moon = { 'a8c0ff', 0 }, skyLight = { 'ffe0b0', '7a6040', 0.715 },
        back = { 'ffd080', 1.8 }, shadows = 0.45, wallShadows = 0.33 },
    dusk = { sun = { 'ff8a3c', 0.9 }, moon = { 'a8c0ff', 0.1 }, skyLight = { 'ffa080', '5a3848', 0.65 },
        back = { 'ffa050', 2.4 }, shadows = 0.4, wallShadows = 0.3 },
}
local TIMELINE = { { 0, 'night' }, { 5, 'night' }, { 6.5, 'dawn' }, { 8.5, 'day' }, { 17, 'day' },
    { 18, 'golden' }, { 19, 'dusk' }, { 20.5, 'night' }, { 24, 'night' } }
local SQUASH = 0.8   -- the arc lower than it is wide
local BACK_FULL = 0.5 -- the sun and moon together this share of the hour's strongest: the back light full
-- the light level's numbers at day (src/scene-light.lua), which the hour scales
local DAY_SHADOWS, DAY_WALL = LOOKS.day.shadows, LOOKS.day.wallShadows

---------------------------------------------------------------- the hour's look

local function rgb(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end
local function hex(r, g, b)
    local function c(v) return math.floor(math.max(0, math.min(1, v)) * 255 + 0.5) end
    return string.format('%02x%02x%02x', c(r), c(g), c(b))
end
local function mix(a, b, t)
    if type(a) == 'number' then return a + (b - a) * t end
    if type(a) == 'string' then
        local r1, g1, b1 = rgb(a)
        local r2, g2, b2 = rgb(b)
        return hex(r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t)
    end
    local out = {}
    for k, v in pairs(a) do out[k] = mix(v, b[k], t) end
    return out
end

-- the look at an hour (0..24), blended between its two keyframes
function lib.lookAt(hour)
    hour = hour % 24
    for i = 1, #TIMELINE - 1 do
        local h0, h1 = TIMELINE[i][1], TIMELINE[i + 1][1]
        if hour >= h0 and hour <= h1 then
            local t = h1 > h0 and (hour - h0) / (h1 - h0) or 0
            t = t * t * (3 - 2 * t)
            return mix(LOOKS[TIMELINE[i][2]], LOOKS[TIMELINE[i + 1][2]], t)
        end
    end
    return LOOKS.night
end

-- where the sun and the moon are on their arcs (0 rising on the left, pi setting on the right)
function lib.sunTheta(hour) return ((hour % 24) - 6) / 12 * math.pi end
function lib.moonTheta(hour) return (((hour % 24) - 17) % 24) / 14 * math.pi end

-- on its arc at theta: the way to it (world, y down: up is -y), and how much it's up (0 at or below
-- the horizon, 1 well up; it fades over about an hour and a half near the horizon)
local function arc(theta)
    local x, y = -math.cos(theta), -SQUASH * math.max(0.05, math.sin(theta))
    local len = math.sqrt(x * x + y * y)
    local up = math.max(0, math.min(1, (math.sin(theta) + 0.1) / 0.5))
    return x / len, y / len, up * up * (3 - 2 * up)
end

-- everything the hour sets: { sun = { x, y, hex, i }, moon = ..., sky = { hex, ground, i },
-- back = { x, y, hex, i }, cast = { x, y } (the way to the light the shadows come from, the sun's and
-- the moon's blended by strength), fade (how much of the shadows' darkness is left), shadows, wall
-- (the contact and wall shadows' darkness against the day's) }
function lib.at(hour)
    local L = lib.lookAt(hour)
    local sx, sy, sunUp = arc(lib.sunTheta(hour))
    local mx, my, moonUp = arc(lib.moonTheta(hour))
    local sunI, moonI = L.sun[2] * sunUp, L.moon[2] * moonUp
    local total = sunI + moonI
    local share = total > 0 and sunI / total or 0.5
    -- the way they shine blended through 'from above', never round the bottom
    local cx, cy = mx + (sx - mx) * share, my + (sy - my) * share
    local clen = math.sqrt(cx * cx + cy * cy)
    if clen < 0.2 then cx, cy, clen = 0, -1, 1 end -- straight across each other: from above
    cx, cy = cx / clen, cy / clen
    local peak = math.max(L.sun[2], L.moon[2], 0.01)
    local there = math.min(1, total / (BACK_FULL * peak))
    there = there * there * (3 - 2 * there)
    return {
        sun = { sx, sy, L.sun[1], sunI },
        moon = { mx, my, L.moon[1], moonI },
        sky = { L.skyLight[1], L.skyLight[2], L.skyLight[3] },
        back = { cx, cy, L.back[1], L.back[2] * there },
        cast = { cx, cy },
        fade = math.min(1, total / 0.6),
        shadows = L.shadows / DAY_SHADOWS,
        wall = L.wallShadows / DAY_WALL,
    }
end

-- How much light a flat thing gets at the hour (a wall, src/walls.lua): the sky light, the sun and the moon
-- added up by colour, as at noon = white: darker and bluer at night, warm at dusk. Never quite black.
local AMBIENT_SKY, AMBIENT_SUN, AMBIENT_FLOOR = 0.5, 0.55, 0.1
local noonAmbient
local function rawAmbient(now)
    local r, g, b = 0, 0, 0
    local function add(hexColour, amount)
        local cr, cg, cb = rgb(hexColour)
        r, g, b = r + cr * amount, g + cg * amount, b + cb * amount
    end
    add(now.sky[1], now.sky[3] * AMBIENT_SKY)
    add(now.sun[3], now.sun[4] * AMBIENT_SUN)
    add(now.moon[3], now.moon[4] * AMBIENT_SUN)
    return r, g, b
end
function lib.ambient(hour)
    if not noonAmbient then
        local r, g, b = rawAmbient(lib.at(12))
        noonAmbient = math.max(r, g, b)
    end
    local r, g, b = rawAmbient(lib.at(hour))
    local function f(v) return math.max(AMBIENT_FLOOR, math.min(1, v / noonAmbient)) end
    return f(r), f(g), f(b)
end

---------------------------------------------------------------- into the light level's tables

-- the default lights a sky scene's level starts with (filled by lib.fill): sun, moon, sky light, back light
function lib.newLights()
    return {
        withSceneLights = true, -- on beside the scene's own lamps (src/render/shaders.lua)
        { lightType = 'directional', toLight = { 0, -1 }, colorHex = 'fff2d9ff', intensity = 0 },
        { lightType = 'directional', toLight = { 0, -1 }, colorHex = 'a8c0ffff', intensity = 0 },
        { lightType = 'sky', toLight = { 0, -1 }, colorHex = '9cc8ffff', groundHex = '8a7a50ff', intensity = 0 },
        { lightType = 'back', toLight = { 0, -1 }, colorHex = 'ffffffff', intensity = 0 },
    }
end

local function setLight(d, x, y, colour, intensity)
    d.toLight[1], d.toLight[2] = x, y
    d.colorHex = colour .. 'ff'
    d.intensity = intensity
end

-- a wall shadow's offset and softness from the way to the light (as scene-light's wallShadowFrom)
local function castWall(shadow, cx, cy, strength)
    local behind = shadow.behind or 90
    local high = math.max(0, -cy)
    local length = behind * math.min(4, 1 / (high + 0.25))
    shadow.offset[1], shadow.offset[2] = -cx * length, high * length
    shadow.blur = 5 + length * 0.06
    shadow.strength = (shadow.baseStrength or 0.35) * strength
end

-- The hour into the level's shared settings (scene-light: its tables for a sky scene, made with
-- lib.newLights and with each shadow's behind and baseStrength). Every frame; nothing new made.
function lib.fill(shared, hour)
    local now = lib.at(hour)
    local lights = shared.sceneDefaultLights
    if lights and #lights >= 4 then
        setLight(lights[1], now.sun[1], now.sun[2], now.sun[3], now.sun[4])
        setLight(lights[2], now.moon[1], now.moon[2], now.moon[3], now.moon[4])
        setLight(lights[3], 0, -1, now.sky[1], now.sky[3])
        lights[3].groundHex = now.sky[2] .. 'ff'
        setLight(lights[4], now.back[1], now.back[2], now.back[3], now.back[4])
    end
    local contact = shared.contactShadows
    if contact then contact.strength = (contact.baseStrength or 0.45) * now.shadows end
    local walls = shared.backdropShadows
    if walls then
        local wallStrength = now.wall * now.fade
        for _, shadow in ipairs(walls.layers or { walls }) do
            if shadow.offset then castWall(shadow, now.cast[1], now.cast[2], wallStrength) end
        end
    end
    local projected = shared.projectedShadows
    if projected then
        for _, one in ipairs(projected.lights or {}) do
            local light = one.light
            if light and light.kind == 'sun' then
                light.x, light.h = now.cast[1], math.max(0, -now.cast[2])
                one.strength = (one.baseStrength or 0.5) * now.fade * now.shadows
            end
        end
    end
    return now
end

return lib

-- light-grass-check: working on light — a sun, a warm and a cool lamp to carry about, a turning lamp, over
-- six plasticine shapes; and grass on a spinning turf (its blades rebuilt every frame: the counter).
-- From the LITTLE-USED rounds (docs/LITTLE-USED.md, 2026-11-06). Up to 8 lights reach a shape
-- (src/render/shaders.lua MAX_LIGHTS); a light's colour tints, its intensity and nearness light.
-- The shapes start lit strongly and baked round (their settings, src/render/shaders.lua and
-- src/render/form-bake.lua; 0 shows them as other scenes draw them).
-- play mode (tab): drag the warm and the cool lamp about.
-- keys:
--   1 day   2 evening   3 night   4 only the turning lamp (its range: r 5000 / 500)
--   g light swing   z how much the light comes from the front   f the quick form's depth
--   b baked form / the shader's quick guess   n baked rise (1 a dome, 0.5, 0.2 a pebble)
--   0 the shapes as other scenes draw them   s turf spinning or not

local s = {}

-- the times of day: the sky, then per light its colour, intensity and (the sun) where it shines to and
-- where it is
local MOODS = {
    day = { sky = { 0.62, 0.78, 0.92 },
        sun = { 'fff2d9ff', 1.0, math.rad(60), -1250, -650 }, ['warm lamp'] = { 'ffb060ff', 0 },
        ['cool lamp'] = { '80a8ffff', 0 }, ['turning lamp'] = { 'ffffffff', 0 } },
    evening = { sky = { 0.93, 0.62, 0.45 },
        sun = { 'ff8a3cff', 0.9, math.rad(12), -1450, -100 }, ['warm lamp'] = { 'ffb060ff', 0.8 },
        ['cool lamp'] = { '80a8ffff', 0 }, ['turning lamp'] = { 'ffffffff', 0 } },
    night = { sky = { 0.08, 0.1, 0.22 },
        sun = { 'a8c0ffff', 0.35, math.rad(120), 600, -650 }, ['warm lamp'] = { 'ffb060ff', 1.0 },
        ['cool lamp'] = { '80a8ffff', 0.8 }, ['turning lamp'] = { 'ffffffff', 0 } },
    lamp = { sky = nil,
        sun = { 'fff2d9ff', 0, math.rad(60) }, ['warm lamp'] = { 'ffb060ff', 0 },
        ['cool lamp'] = { '80a8ffff', 0 }, ['turning lamp'] = { 'fff2d9ff', 1.0 } },
}
local MOOD_KEYS = { ['1'] = 'day', ['2'] = 'evening', ['3'] = 'night', ['4'] = 'lamp' }
local LIGHTS = { 'sun', 'warm lamp', 'cool lamp', 'turning lamp' }

-- each key steps through these on every shape; the first is how other scenes draw them
local TRIES = {
    g = { key = 'plasticineLightGain', name = 'swing', values = { 0, 0.3, 0.5 } },
    z = { key = 'plasticineLightZ', name = 'front', values = { 0.9, 0.6, 0.35 } },
    f = { key = 'plasticineFormRadius', name = 'quick form', values = { 0.08, 0.2, 0.35 } },
    b = { key = 'plasticineFormBaked', name = 'baked', values = { false, true } },
    n = { key = 'plasticineFormRise', name = 'rise', values = { 1, 0.5, 0.2 } },
}
local TRY_ORDER = { 'g', 'z', 'f', 'b', 'n' }

local function lightOf(label)
    for _, thing in ipairs(getObjectsByLabel(label)) do
        for _, fixture in ipairs(thing.body:getFixtures()) do
            local ud = fixture:getUserData()
            if ud and ud.subtype == 'light' then return thing.body, ud.extra end
        end
    end
end

local function shapeExtras()
    local list = {}
    for _, thing in ipairs(getObjectsByLabel('lit box')) do
        for _, fixture in ipairs(thing.body:getFixtures()) do
            local ud = fixture:getUserData()
            if ud and ud.subtype == 'texfixture' then list[#list + 1] = ud.extra end
        end
    end
    return list
end

local function current(try)
    local extra = shapeExtras()[1]
    local v = extra and extra[try.key]
    if v == nil then return try.values[1] end
    return v
end

local function setAll(try, v)
    for _, extra in ipairs(shapeExtras()) do extra[try.key] = v end
end

local function same(a, b)
    if a == b then return true end
    return tonumber(a) and tonumber(b) and math.abs(a - b) < 1e-6
end

local function step(try)
    local now, nextValue = current(try), try.values[1]
    for i, v in ipairs(try.values) do
        if same(v, now) then nextValue = try.values[i % #try.values + 1] end
    end
    setAll(try, nextValue)
end

local function look()
    state.lightLab = state.lightLab or { mood = 'day', made = 0, perSecond = 0, time = 0 }
    return state.lightLab
end

local function setMood(name)
    local mood = MOODS[name]
    look().mood = name
    for _, label in ipairs(LIGHTS) do
        local body, extra = lightOf(label)
        local m = mood[label]
        if extra and m then
            extra.colorHex, extra.intensity = m[1], m[2]
            if m[3] and body then body:setAngle(m[3]) end
            if m[4] and body then body:setPosition(m[4], m[5]) end
        end
    end
end

function s.onStart()
    worldState.paused = false -- the turning lamp and the turf turn
    -- the carried lamps float where they're let go and push nothing
    for _, label in ipairs({ 'warm lamp', 'cool lamp' }) do
        for _, thing in ipairs(getObjectsByLabel(label)) do
            thing.body:setGravityScale(0)
            thing.body:setLinearDamping(4)
            thing.body:setFixedRotation(true)
            for _, fixture in ipairs(thing.body:getFixtures()) do fixture:setSensor(true) end
        end
    end
    setMood(look().mood)
    -- counting SpriteBatches made, per second (wrapped once; put back on unload)
    local c = look()
    if not c.original then
        c.original = love.graphics.newSpriteBatch
        love.graphics.newSpriteBatch = function(...)
            c.made = c.made + 1
            return c.original(...)
        end
    end
end

function s.onUnload()
    local c = look()
    if c.original then
        love.graphics.newSpriteBatch = c.original
        c.original = nil
    end
end

function s.update(dt)
    local c = look()
    c.time = c.time + (dt or 0)
    if c.time >= 1 then
        c.perSecond, c.made, c.time = c.made, 0, c.time - 1
    end
end

function s.onKeyPress(key)
    if MOOD_KEYS[key] then
        setMood(MOOD_KEYS[key])
    elseif TRIES[key] then
        step(TRIES[key])
    elseif key == '0' then
        for _, k in ipairs(TRY_ORDER) do setAll(TRIES[k], TRIES[k].values[1]) end
    elseif key == 'r' then
        local _, extra = lightOf('turning lamp')
        if extra then extra.range = (extra.range or 500) == 500 and 5000 or 500 end
    elseif key == 's' then
        for _, thing in ipairs(getObjectsByLabel('spinning turf')) do
            local spinning = math.abs(thing.body:getAngularVelocity()) > 0
            thing.body:setAngularVelocity(spinning and 0 or 0.8)
        end
    end
end

-- the sky behind everything, in the mood's colour
function s.drawBelow()
    local sky = MOODS[look().mood].sky
    if not sky then return end
    local x0, y0 = cam:getWorldCoordinates(0, 0)
    local x1, y1 = cam:getWorldCoordinates(love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(sky[1], sky[2], sky[3], 1)
    love.graphics.rectangle('fill', x0, y0, x1 - x0, y1 - y0)
    love.graphics.setColor(1, 1, 1, 1)
end

local function hexColor(hex)
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255
    return r, g, b
end

-- each light that's on: a glow in its colour, and (directional) the way it shines
function s.draw()
    for _, label in ipairs(LIGHTS) do
        local body, extra = lightOf(label)
        if body and (extra.intensity or 1) > 0 then
            local x, y = body:getPosition()
            local r, g, b = hexColor(extra.colorHex or 'ffffffff')
            for k = 4, 1, -1 do
                love.graphics.setColor(r, g, b, 0.12 * (extra.intensity or 1))
                love.graphics.circle('fill', x, y, 30 + k * 28)
            end
            love.graphics.setColor(r, g, b, 1)
            love.graphics.circle('fill', x, y, 26)
            if extra.lightType ~= 'point' then
                local a = body:getAngle()
                love.graphics.setLineWidth(8)
                love.graphics.line(x, y, x + math.cos(a) * 260, y + math.sin(a) * 260)
                love.graphics.setLineWidth(1)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local c = look()
    local tries = {}
    for _, k in ipairs(TRY_ORDER) do
        tries[#tries + 1] = string.format('%s %s %s', k, TRIES[k].name, tostring(current(TRIES[k])))
    end
    local lines = {
        'light   1 day  2 evening  3 night  4 turning lamp (r range)   tab: play, drag the lamps   s turf',
        'now: ' .. c.mood .. '      shapes: ' .. table.concat(tries, '   ') .. '   (0 as elsewhere)',
        string.format('grass: SpriteBatches made in the last second: %d', c.perSecond),
    }
    for i, line in ipairs(lines) do
        local y = love.graphics.getHeight() - 20 - (#lines - i + 1) * 20
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.print(line, 121, y + 1)
        love.graphics.setColor(1, 0.95, 0.8, 1)
        love.graphics.print(line, 120, y)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return s

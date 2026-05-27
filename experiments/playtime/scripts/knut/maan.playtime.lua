-- Moon scene — drag a character with the mouse, fling them, the moon's
-- gravity pulls them into an elliptical orbit (or crashes them, or lets
-- them escape, depending on how hard you throw).
--
-- Setup expected in the scene:
--   - At least one static body labelled 'planet' (the moon).
--   - One or more dynamic bodies (knut, django, etc.) that should orbit.
--   - World gravity is zeroed in onStart so only the planet pulls.

local s = {}

-- Tuning. The force on a body at distance d from a planet is GRAVITY / d^2.
-- Bigger GRAVITY = stronger pull, faster orbits, more sensitive to throw
-- speed. INFLUENCE_RADIUS is just a perf cutoff so far-away bodies don't
-- get computed every frame; set huge if your scene is small.
local GRAVITY = 25000000
local INFLUENCE_RADIUS = 50000

local planets = {}

local function applyGravity(planet, body)
    local px, py = planet.body:getPosition()
    local bx, by = body:getPosition()
    local dx, dy = px - bx, py - by
    local d2 = dx * dx + dy * dy
    if d2 == 0 or d2 > planet.influenceRadius * planet.influenceRadius then
        return
    end
    local d = math.sqrt(d2)
    local f = planet.gravity / d2
    body:applyForce(dx / d * f, dy / d * f)
end

function s.onStart()
    worldState.paused = false
    -- Zero global gravity — only the planet(s) pull.
    state.world.gravity = 0
    state.physicsWorld:setGravity(0, 0)

    planets = getObjectsByLabel('planet')
    for i = 1, #planets do
        planets[i].gravity = GRAVITY
        planets[i].influenceRadius = INFLUENCE_RADIUS
    end

    -- Wake everything so it starts feeling gravity immediately.
    for _, body in ipairs(state.physicsWorld:getBodies()) do
        body:setAwake(true)
    end

    print(string.format('[maan] %d planet(s); drag a body and fling to orbit', #planets))
end

function s.update(dt)
    for _, planet in ipairs(planets) do
        for _, body in ipairs(state.physicsWorld:getBodies()) do
            if body:getType() == 'dynamic' then
                applyGravity(planet, body)
            end
        end
    end
end

-- Visual: faint ring at the planet's position (helps tune throws).
function s.draw()
    love.graphics.setColor(1, 1, 1, 0.2)
    for i = 1, #planets do
        local px, py = planets[i].body:getPosition()
        local r = planets[i].radius or 100
        -- a few "orbit guide" rings at multiples of the planet's radius
        love.graphics.circle('line', px, py, r * 2)
        love.graphics.circle('line', px, py, r * 4)
        love.graphics.circle('line', px, py, r * 6)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return s

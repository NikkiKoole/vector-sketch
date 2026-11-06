-- light-grass-check: two things to look at from the LITTLE-USED rounds (docs/LITTLE-USED.md, 2026-11-06).
-- Left: a lamp (a LIGHT sfixture, directional) turning slowly over four plasticine boxes at growing
-- distances. A directional light also fades with the distance from its lamp (range, 500 by default:
-- the shader's 1 - smoothstep(0, range, distance)), so the far boxes hardly see it turn. The label
-- under each box is the share of the light it gets.
-- Right: grass on still ground and on a turf spinning on the spot. The grass's cache key holds the
-- body's angle, so the turning turf builds its two SpriteBatches again every frame; the counter
-- top left shows how many are made per second (the still ground: none).
-- keys: r lamp range 500 / 5000   t directional / point   s turf spinning or not

local s = {}

local RANGES = { 500, 5000 }

local function lampLight()
    for _, thing in ipairs(getObjectsByLabel('lamp')) do
        for _, fixture in ipairs(thing.body:getFixtures()) do
            local ud = fixture:getUserData()
            if ud and ud.subtype == 'light' then return thing.body, ud.extra end
        end
    end
end

local function smoothstep(e0, e1, x)
    local t = math.max(0, math.min(1, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)
end

-- counting SpriteBatches made, per second (wrapped once; put back on unload)
local function counter()
    state.lightGrassCheck = state.lightGrassCheck or { made = 0, perSecond = 0, time = 0 }
    return state.lightGrassCheck
end

function s.onStart()
    worldState.paused = false -- the lamp and the turf turn
    local c = counter()
    if not c.original then
        c.original = love.graphics.newSpriteBatch
        love.graphics.newSpriteBatch = function(...)
            c.made = c.made + 1
            return c.original(...)
        end
    end
end

function s.onUnload()
    local c = counter()
    if c.original then
        love.graphics.newSpriteBatch = c.original
        c.original = nil
    end
end

function s.update(dt)
    local c = counter()
    c.time = c.time + (dt or 0)
    if c.time >= 1 then
        c.perSecond, c.made, c.time = c.made, 0, c.time - 1
    end
end

function s.onKeyPress(key)
    local body, extra = lampLight()
    if key == 'r' and extra then
        extra.range = (extra.range or 500) == RANGES[1] and RANGES[2] or RANGES[1]
    elseif key == 't' and extra then
        extra.lightType = (extra.lightType == 'point') and 'directional' or 'point'
    elseif key == 's' then
        for _, thing in ipairs(getObjectsByLabel('spinning turf')) do
            local spinning = math.abs(thing.body:getAngularVelocity()) > 0
            thing.body:setAngularVelocity(spinning and 0 or 0.8)
        end
    end
    if body then body:setAwake(true) end
end

-- world space: the light's direction from the lamp, and each box's share of it
function s.draw()
    local body, extra = lampLight()
    if not body then return end
    local lx, ly = body:getPosition()
    local a = body:getAngle()
    love.graphics.setColor(0.95, 0.75, 0.2, 1)
    love.graphics.setLineWidth(8)
    local ex, ey = lx + math.cos(a) * 260, ly + math.sin(a) * 260
    love.graphics.line(lx, ly, ex, ey)
    love.graphics.circle('fill', ex, ey, 18)
    love.graphics.setLineWidth(1)
    local range = extra.range or 500
    local font = love.graphics.getFont()
    for _, thing in ipairs(getObjectsByLabel('lit box')) do
        local bx, by = thing.body:getPosition()
        local d = math.sqrt((bx - lx) ^ 2 + (by - ly) ^ 2)
        local share = 1 - smoothstep(0, math.max(range, 1), d)
        local text = string.format('%d px: %d%%', math.floor(d), math.floor(share * 100 + 0.5))
        local tx, ty = bx - font:getWidth(text) * 1.5, by + 130
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.print(text, tx + 4, ty + 4, 0, 3, 3)
        love.graphics.setColor(1, 0.95, 0.8, 1)
        love.graphics.print(text, tx, ty, 0, 3, 3)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local _, extra = lampLight()
    local c = counter()
    local lines = {
        'light-grass-check   r lamp range   t directional / point   s turf spinning',
        string.format('lamp: %s, range %d', extra and (extra.lightType or 'directional') or '-',
            extra and (extra.range or 500) or 0),
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

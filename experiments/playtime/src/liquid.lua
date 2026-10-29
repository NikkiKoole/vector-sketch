-- liquid.lua — the LIQUID sfixture: water inside a container (docs/WATER.md W1).
-- The container is its body (a cup is a U-shaped custom polygon); the space inside
-- is the cavity, body-local. By default the cavity is the body's bounds less
-- `wall` on the sides and bottom (the top stays open at the rim). The water is an
-- amount (`fill` x the cavity's area), and its surface is always level in the
-- world: each frame the line is found where the part of the cavity below it holds
-- exactly that amount, so tilting a cup sloshes the water to the low side.
-- The cavity's first edge is its mouth (the open top): while playing, water above the
-- mouth's lower end spills out (lib.update), so a tipped cup empties and an upside-down
-- one holds nothing. W2 turns what spills into a stream, W3 a wobbling surface, W4 floating.
local lib = {}

lib.defaults = {
    fill = 0.6,               -- part of the cavity that's water (upright)
    wall = 12,                -- world units: the container's wall, side and bottom
    color = '3aa7d9b3',
    surfaceColor = 'cdeeffff',
    front = false,            -- drawn in front of the Mipos (a bath) instead of at its own z
}
lib.FRONT_Z = 1000000 + 500   -- above every Mipo z-group, like the grass's front layer

local function setting(extra, key)
    local v = extra[key]
    if v == nil then return lib.defaults[key] end
    return v
end
lib.setting = setting

-- Shoelace area of a flat polygon { x1, y1, x2, y2, ... } (always positive).
function lib.area(poly)
    local a, n = 0, #poly
    for i = 1, n, 2 do
        local j = (i + 2 > n) and 1 or i + 2
        a = a + poly[i] * poly[j + 1] - poly[j] * poly[i + 1]
    end
    return math.abs(a) / 2
end

-- The part of `poly` below the horizontal line y = level (y points down, so 'below'
-- is y >= level). Sutherland-Hodgman against one edge; fine for convex cavities,
-- and the area stays right for concave ones.
function lib.clipBelow(poly, level)
    local out = {}
    local n = #poly
    if n < 6 then return out end
    local px, py = poly[n - 1], poly[n]
    local pIn = py >= level
    for i = 1, n, 2 do
        local x, y = poly[i], poly[i + 1]
        local cIn = y >= level
        if cIn ~= pIn then
            local t = (level - py) / (y - py)
            out[#out + 1] = px + (x - px) * t
            out[#out + 1] = level
        end
        if cIn then
            out[#out + 1] = x
            out[#out + 1] = y
        end
        px, py, pIn = x, y, cIn
    end
    return out
end

-- Where the surface is when `poly` (world space) holds `amount`: the level (world y)
-- and the water polygon. nil when empty; the whole cavity when it's over full.
function lib.levelFor(poly, amount)
    if amount <= 0 or #poly < 6 then return nil end
    local top, bottom = math.huge, -math.huge
    for i = 2, #poly, 2 do
        top = math.min(top, poly[i]); bottom = math.max(bottom, poly[i])
    end
    if amount >= lib.area(poly) then return top, poly end
    local lo, hi = top, bottom -- the area below falls as the level goes down (y up)
    for _ = 1, 30 do
        local mid = (lo + hi) / 2
        if lib.area(lib.clipBelow(poly, mid)) > amount then lo = mid else hi = mid end
    end
    local level = (lo + hi) / 2
    return level, lib.clipBelow(poly, level)
end

-- The default cavity in a body's local bounds: in by `wall` on the sides and bottom.
function lib.cavityFromBounds(x1, y1, x2, y2, wall)
    local l, r = x1 + wall, x2 - wall
    local b = y2 - wall
    if r <= l then l, r = (x1 + x2) / 2 - 1, (x1 + x2) / 2 + 1 end
    if b <= y1 then b = y1 + 1 end
    return { l, y1, r, y1, r, b, l, b }
end

-- The body's local bounds from its colliding shapes (not the sfixtures).
local function localBounds(body)
    local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
    for _, fixture in ipairs(body:getFixtures()) do
        if not fixture:isSensor() then
            local shape = fixture:getShape()
            if shape:getType() == 'circle' then
                local cx, cy = shape:getPoint()
                local r = shape:getRadius()
                x1, y1 = math.min(x1, cx - r), math.min(y1, cy - r)
                x2, y2 = math.max(x2, cx + r), math.max(y2, cy + r)
            elseif shape.getPoints then
                local pts = { shape:getPoints() }
                for i = 1, #pts, 2 do
                    x1, y1 = math.min(x1, pts[i]), math.min(y1, pts[i + 1])
                    x2, y2 = math.max(x2, pts[i]), math.max(y2, pts[i + 1])
                end
            end
        end
    end
    if x1 == math.huge then return -50, -50, 50, 50 end
    return x1, y1, x2, y2
end

-- Cavity per sfixture, cached by its extra (weak). extra.cavity (body-local) wins when set.
local cache = setmetatable({}, { __mode = 'k' })

function lib.cavity(extra, body)
    if extra.cavity then return extra.cavity end
    local wall = setting(extra, 'wall')
    local entry = cache[extra]
    if entry and entry.wall == wall and entry.fixtureCount == #body:getFixtures() then
        return entry.cavity
    end
    local x1, y1, x2, y2 = localBounds(body)
    local cavity = lib.cavityFromBounds(x1, y1, x2, y2, wall)
    cache[extra] = { cavity = cavity, wall = wall, fixtureCount = #body:getFixtures() }
    return cavity
end

local function toWorld(body, poly)
    local out = {}
    for i = 1, #poly, 2 do
        out[i], out[i + 1] = body:getWorldPoint(poly[i], poly[i + 1])
    end
    return out
end

-- The water right now: level, water polygon (world), cavity (world). nil level when empty.
function lib.water(extra, body)
    local cavityLocal = lib.cavity(extra, body)
    local cavity = toWorld(body, cavityLocal)
    local amount = setting(extra, 'fill') * lib.area(cavityLocal)
    local level, poly = lib.levelFor(cavity, amount)
    return level, poly, cavity
end

local function hexColor(hex)
    local function byte(i) return (tonumber(hex:sub(i, i + 1), 16) or 255) / 255 end
    return byte(1), byte(3), byte(5), #hex >= 8 and byte(7) or 1
end

-- The two ends of the surface: the water polygon's points on the level line.
local function surfaceEnds(poly, level)
    local x1, x2 = math.huge, -math.huge
    for i = 1, #poly, 2 do
        if math.abs(poly[i + 1] - level) < 0.01 then
            x1, x2 = math.min(x1, poly[i]), math.max(x2, poly[i])
        end
    end
    if x1 > x2 then return nil end
    return x1, x2
end

function lib.draw(extra, body)
    if not body or body:isDestroyed() then return end
    local level, poly = lib.water(extra, body)
    if not level or #poly < 6 then return end
    love.graphics.setColor(hexColor(setting(extra, 'color')))
    local ok, triangles = pcall(love.math.triangulate, poly)
    if ok then
        for _, t in ipairs(triangles) do love.graphics.polygon('fill', t) end
    end
    local x1, x2 = surfaceEnds(poly, level)
    if x1 then
        love.graphics.setColor(hexColor(setting(extra, 'surfaceColor')))
        local lw = love.graphics.getLineWidth()
        love.graphics.setLineWidth(4)
        love.graphics.line(x1, level, x2, level)
        love.graphics.setLineWidth(lw)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- How much the cavity (world space) holds at its current angle: the part below the lower
-- end of its mouth (the first edge).
function lib.capacity(cavity)
    local mouthY = math.max(cavity[2], cavity[4])
    return lib.area(lib.clipBelow(cavity, mouthY))
end

-- Let water above the mouth run out. Returns the amount spilled (area units).
function lib.spill(extra, body)
    local cavityLocal = lib.cavity(extra, body)
    local full = lib.area(cavityLocal)
    if full <= 0 then return 0 end
    local amount = setting(extra, 'fill') * full
    local capacity = lib.capacity(toWorld(body, cavityLocal))
    if amount <= capacity then return 0 end
    extra.fill = capacity / full
    return amount - capacity
end

-- Once per frame after the physics step: while playing, every container spills what it can't hold.
function lib.update(paused)
    if paused then return end
    local subtypes = require('src.subtypes')
    for _, fixture in pairs(require('src.registry').sfixtures) do
        if not fixture:isDestroyed() then
            local ud = fixture:getUserData()
            if type(ud) == 'table' and subtypes.is(ud, subtypes.LIQUID) then
                lib.spill(ud.extra, fixture:getBody())
            end
        end
    end
end

-- What a new liquid sfixture starts with.
function lib.newExtra()
    local extra = { zOffset = 0, zGroupOffset = 0 }
    for k, v in pairs(lib.defaults) do extra[k] = v end
    return extra
end

return lib

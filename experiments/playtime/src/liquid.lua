-- liquid.lua — the LIQUID sfixture: water inside a container (docs/WATER.md W1).
-- The container is its body, whatever its shape: a U-shaped cup, a drawn bowl, a bath.
-- The space inside is the body's convex hull minus the body itself, so a curved bowl
-- holds water in its curve and nowhere else. The mouth is the part of the hull that
-- runs through air (not along the body): the line across the top of a bowl.
-- The water is an amount (`fill` x the hollow's area), and its surface is always level
-- in the world: each frame the line is found where the hollow below it holds exactly
-- that amount, so tilting a cup sloshes the water to the low side. It's drawn as the
-- hull below that line with the body masked out (a stencil), so it never covers a wall.
-- While playing, water above the mouth's lowest point spills out (lib.update), so a
-- tipped cup empties and an upside-down one holds nothing.
-- extra.cavity (a body-local polygon, first edge = mouth) replaces the hull when set.
-- The surface sloshes (W3): a row of springs across the container that moving, shaking or
-- rotating it sets rocking, and that settle again; a level change glides instead of
-- snapping. Visual only (not saved): it runs in lib.draw, playing or not.
-- W2 turns what spills into a stream, W4 floating.
local lib = {}
local mathutils = require('src.math-utils')

lib.defaults = {
    fill = 0.6,               -- part of the hollow that's water (upright)
    color = '3aa7d9b3',
    surfaceColor = 'cdeeffff',
    front = false,            -- drawn in front of the Mipos (a bath) instead of at its own z
    slosh = 1,                -- how much moving the container rocks the surface (0 = flat)
    settle = 1,               -- how quickly it calms down again
}
lib.SPRINGS = 24              -- points across the surface
lib.FRONT_Z = 1000000 + 500   -- above every Mipo z-group, like the grass's front layer

local CIRCLE_SIDES = 16
local NEAR = 0.5              -- world units: a hull edge this close to the body runs along it

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
-- is y >= level). Sutherland-Hodgman against one edge; exact for convex polygons,
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

-- The hollow's area below `level`: the polygon's, less the holes' (the body's own shapes).
function lib.areaBelow(poly, holes, level)
    local a = lib.area(lib.clipBelow(poly, level))
    for _, hole in ipairs(holes or {}) do a = a - lib.area(lib.clipBelow(hole, level)) end
    return math.max(0, a)
end

-- The hollow's whole area.
function lib.volume(poly, holes)
    local a = lib.area(poly)
    for _, hole in ipairs(holes or {}) do a = a - lib.area(hole) end
    return math.max(0, a)
end

-- Where the surface is when `poly` less `holes` (world space) holds `amount`: the level
-- (world y) and the polygon below it. nil when empty; the top when it's over full.
function lib.levelFor(poly, amount, holes)
    if amount <= 0 or #poly < 6 then return nil end
    local top, bottom = math.huge, -math.huge
    for i = 2, #poly, 2 do
        top = math.min(top, poly[i]); bottom = math.max(bottom, poly[i])
    end
    if amount >= lib.volume(poly, holes) then return top, poly end
    local lo, hi = top, bottom -- the area below falls as the level goes down (y up)
    for _ = 1, 30 do
        local mid = (lo + hi) / 2
        if lib.areaBelow(poly, holes, mid) > amount then lo = mid else hi = mid end
    end
    local level = (lo + hi) / 2
    return level, lib.clipBelow(poly, level)
end

-- Convex hull of flat points (monotone chain), as a flat polygon.
function lib.hull(points)
    local pts = {}
    for i = 1, #points, 2 do pts[#pts + 1] = { points[i], points[i + 1] } end
    table.sort(pts, function(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end)
    if #pts < 3 then return {} end
    local function cross(o, a, b) return (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1]) end
    local lower, upper = {}, {}
    for _, p in ipairs(pts) do
        while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], p) <= 0 do lower[#lower] = nil end
        lower[#lower + 1] = p
    end
    for i = #pts, 1, -1 do
        local p = pts[i]
        while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], p) <= 0 do upper[#upper] = nil end
        upper[#upper + 1] = p
    end
    local out = {}
    for i = 1, #lower - 1 do out[#out + 1] = lower[i][1]; out[#out + 1] = lower[i][2] end
    for i = 1, #upper - 1 do out[#out + 1] = upper[i][1]; out[#out + 1] = upper[i][2] end
    return out
end

-- Is (x, y) inside or within `near` of the convex polygon `poly`?
local function nearConvex(poly, x, y, near)
    local n = #poly
    local sign, inside = 0, true
    for i = 1, n, 2 do
        local j = (i + 2 > n) and 1 or i + 2
        local ax, ay, bx, by = poly[i], poly[i + 1], poly[j], poly[j + 1]
        local c = (bx - ax) * (y - ay) - (by - ay) * (x - ax)
        if c ~= 0 then
            local s = c > 0 and 1 or -1
            if sign == 0 then sign = s elseif s ~= sign then inside = false end
        end
        -- distance to this edge
        local dx, dy = bx - ax, by - ay
        local len2 = dx * dx + dy * dy
        local t = len2 > 0 and mathutils.clamp(((x - ax) * dx + (y - ay) * dy) / len2, 0, 1) or 0
        local ex, ey = ax + dx * t - x, ay + dy * t - y
        if ex * ex + ey * ey <= near * near then return true end
    end
    return inside
end

-- The hull's open edges: the ones whose middle isn't on or in the body (the mouth).
-- Returns a list of edge start indices into the flat hull.
function lib.openEdges(hull, holes)
    local open = {}
    local n = #hull
    for i = 1, n, 2 do
        local j = (i + 2 > n) and 1 or i + 2
        local mx, my = (hull[i] + hull[j]) / 2, (hull[i + 1] + hull[j + 1]) / 2
        local closed = false
        for _, hole in ipairs(holes) do
            if nearConvex(hole, mx, my, NEAR) then closed = true; break end
        end
        if not closed then open[#open + 1] = i end
    end
    return open
end

-- How much the hollow holds at its current angle (world space): the part below the
-- mouth's lowest point. `mouthY` defaults to the lower end of the first edge (an
-- explicit cavity's mouth); math.huge means closed (it never spills).
function lib.capacity(poly, holes, mouthY)
    mouthY = mouthY or math.max(poly[2], poly[4])
    if mouthY == math.huge then return lib.volume(poly, holes) end
    return lib.areaBelow(poly, holes, mouthY)
end

-- The body's colliding shapes as body-local convex polygons (circles as 16-gons).
local function bodyShapes(body)
    local shapes = {}
    for _, fixture in ipairs(body:getFixtures()) do
        if not fixture:isSensor() then
            local shape = fixture:getShape()
            if shape:getType() == 'circle' then
                local cx, cy = shape:getPoint()
                local r = shape:getRadius()
                local poly = {}
                for k = 0, CIRCLE_SIDES - 1 do
                    local a = k / CIRCLE_SIDES * math.pi * 2
                    poly[#poly + 1] = cx + math.cos(a) * r
                    poly[#poly + 1] = cy + math.sin(a) * r
                end
                shapes[#shapes + 1] = poly
            elseif shape:getType() == 'polygon' then
                shapes[#shapes + 1] = { shape:getPoints() }
            end
        end
    end
    return shapes
end

-- The container per sfixture, cached by its extra (weak) while the body's fixtures stay
-- the same: { hull, holes, open } body-local (open = the mouth's edge indices into hull).
local cache = setmetatable({}, { __mode = 'k' })

local function fixturesKey(body)
    local parts = {}
    for _, fixture in ipairs(body:getFixtures()) do parts[#parts + 1] = tostring(fixture) end
    return table.concat(parts, ',')
end

function lib.container(extra, body)
    if extra.cavity then
        return { hull = extra.cavity, holes = {}, open = { 1 } }
    end
    local key = fixturesKey(body)
    local entry = cache[extra]
    if entry and entry.key == key then return entry.container end
    local holes = bodyShapes(body)
    local points = {}
    for _, hole in ipairs(holes) do
        for i = 1, #hole do points[#points + 1] = hole[i] end
    end
    local hull = lib.hull(points)
    local container = { hull = hull, holes = holes, open = lib.openEdges(hull, holes) }
    cache[extra] = { key = key, container = container }
    return container
end

local function toWorld(body, poly)
    local out = {}
    for i = 1, #poly, 2 do
        out[i], out[i + 1] = body:getWorldPoint(poly[i], poly[i + 1])
    end
    return out
end

local function worldContainer(c, body)
    local holes = {}
    for i, hole in ipairs(c.holes) do holes[i] = toWorld(body, hole) end
    return toWorld(body, c.hull), holes
end

-- The mouth's lowest point (world y), or math.huge for a closed container.
local function mouthY(c, hull)
    local y = -math.huge
    local n = #hull
    for _, i in ipairs(c.open) do
        local j = (i + 2 > n) and 1 or i + 2
        y = math.max(y, hull[i + 1], hull[j + 1])
    end
    if y == -math.huge then return math.huge end
    return y
end

-- The water right now: level, the hull below it, the hull and holes (all world).
-- nil level when empty.
function lib.water(extra, body)
    local c = lib.container(extra, body)
    local hull, holes = worldContainer(c, body)
    local amount = setting(extra, 'fill') * lib.volume(c.hull, c.holes)
    local level, poly = lib.levelFor(hull, amount, holes)
    return level, poly, hull, holes
end

-- ---------------------------------------------------------------------------
-- The sloshing surface. `wave` = { h = {}, v = {} }: per spring the height above the
-- flat level (world units, up) and its speed. Each spring is pulled back to flat,
-- passes some of its height to its neighbours (so a push travels and rocks), and is
-- damped; the mean is kept at 0 so the water's amount doesn't change.

function lib.newWave(n)
    local wave = { h = {}, v = {} }
    for i = 1, n or lib.SPRINGS do wave.h[i], wave.v[i] = 0, 0 end
    return wave
end

-- One step. `stiffness` (1/s^2) sets how fast it rocks, `damping` (1/s) how fast it calms,
-- `maxHeight` caps it.
function lib.stepWave(wave, dt, stiffness, damping, maxHeight)
    local h, v = wave.h, wave.v
    local n = #h
    for i = 1, n do
        v[i] = v[i] + (-stiffness * h[i] - damping * v[i]) * dt
        h[i] = h[i] + v[i] * dt
    end
    local spread = math.min(0.5, stiffness * dt * dt * 4) -- neighbours pull on each other
    for _ = 1, 2 do
        for i = 1, n - 1 do
            local d = (h[i + 1] - h[i]) * spread
            v[i] = v[i] + d / dt * 0.5
            v[i + 1] = v[i + 1] - d / dt * 0.5
        end
    end
    local mean = 0
    for i = 1, n do mean = mean + h[i] end
    mean = mean / n
    -- a soft cap: it rounds off nearing maxHeight instead of going flat there
    for i = 1, n do
        local x = h[i] - mean
        if maxHeight <= 0 then
            h[i], v[i] = 0, 0
        elseif math.abs(x) > maxHeight * 0.5 then
            local sign = x > 0 and 1 or -1
            local over = (math.abs(x) - maxHeight * 0.5) / (maxHeight * 0.5)
            h[i] = sign * maxHeight * (0.5 + 0.5 * (over / (1 + over)))
            v[i] = v[i] * 0.8
        else
            h[i] = x
        end
    end
end

-- Rock it: a push that raises one side and lowers the other (`amount` in world units/s
-- at the ends; positive raises the left).
function lib.pushWave(wave, amount)
    local n = #wave.h
    for i = 1, n do
        local t = (i - 1) / (n - 1)
        wave.v[i] = wave.v[i] + amount * (1 - 2 * t)
    end
end

local function waveEnergy(wave)
    local e = 0
    for i = 1, #wave.h do e = e + wave.h[i] * wave.h[i] + wave.v[i] * wave.v[i] * 0.01 end
    return e
end
lib.waveEnergy = waveEnergy

-- Runtime surface per sfixture (weak by extra; a hot reload just starts it flat).
local waves = setmetatable({}, { __mode = 'k' })

-- Advance the surface for this frame from how the container moved since the last one.
local function updateWave(extra, body, level, width, maxHeight, dt)
    local entry = waves[extra]
    local x, y = body:getPosition()
    local angle = body:getAngle()
    if not entry then
        entry = { wave = lib.newWave(), x = x, y = y, angle = angle, vx = 0, omega = 0, shownLevel = level }
        waves[extra] = entry
    end
    if dt <= 0 then return entry end
    local vx = (x - entry.x) / dt
    local omega = (angle - entry.angle) / dt
    local ax = (vx - entry.vx) / dt
    local alpha = (omega - entry.omega) / dt
    entry.x, entry.y, entry.angle, entry.vx, entry.omega = x, y, angle, vx, omega

    local slosh = setting(extra, 'slosh')
    -- speeding up to the right leaves the water behind, up on the left; turning clockwise
    -- (the right side going down) leaves it up on the right
    local push = (ax * 0.5 - alpha * width * 0.25) * slosh * dt
    local limit = width * 4
    lib.pushWave(entry.wave, mathutils.clamp(push, -limit, limit))

    -- a real slosh is slow in a wide bath and quick in a cup: omega^2 ~ pi g / width
    local g = 980
    local stiffness = math.pi * g / math.max(20, width)
    local damping = 1.8 * setting(extra, 'settle')
    lib.stepWave(entry.wave, math.min(dt, 1 / 30), stiffness, damping, maxHeight)

    -- a level change (a spill, a new fill) glides in
    entry.shownLevel = entry.shownLevel + (level - entry.shownLevel) * (1 - math.exp(-dt * 10))
    return entry
end

local hexColor = require('src.color').hexToColor
local registry = require('src.registry')
local subtypes = require('src.subtypes')

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
    local level, poly, hull, holes = lib.water(extra, body)
    if not level or #poly < 6 then
        waves[extra] = nil
        return
    end
    local x1, x2 = surfaceEnds(poly, level)
    local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
    for i = 1, #hull, 2 do
        minX, maxX = math.min(minX, hull[i]), math.max(maxX, hull[i])
        minY, maxY = math.min(minY, hull[i + 1]), math.max(maxY, hull[i + 1])
    end
    local width = x1 and (x2 - x1) or (maxX - minX)
    -- the surface never rises past the mouth (no lid to cut it off), and only so far in a deep one
    local mouth = mouthY(lib.container(extra, body), hull) -- its lowest point; huge when closed
    local top = mouth == math.huge and minY or mouth
    local maxHeight = mathutils.clamp(level - top, 0, (maxY - minY) * 0.35)
    local entry = updateWave(extra, body, level, width, maxHeight, love.timer.getDelta())
    local h = entry.wave.h
    local n = #h
    local shown = entry.shownLevel

    -- the hollow: the hull less the body, as a stencil
    love.graphics.stencil(function()
        love.graphics.polygon('fill', hull)
    end, 'replace', 1)
    love.graphics.stencil(function()
        for _, hole in ipairs(holes) do
            if #hole >= 6 then love.graphics.polygon('fill', hole) end
        end
    end, 'replace', 0, true)
    local compare, value = love.graphics.getStencilTest()
    love.graphics.setStencilTest('equal', 1)

    -- the water: columns from the wavy surface down past the bottom, across the hull
    local line = {}
    for i = 1, n do
        local t = (i - 1) / (n - 1)
        line[#line + 1] = mathutils.lerp(minX, maxX, t)
        line[#line + 1] = shown - h[i]
    end
    love.graphics.setColor(hexColor(setting(extra, 'color')))
    local bottom = maxY + 1
    for i = 1, n - 1 do
        local ax, ay, bx, by = line[i * 2 - 1], line[i * 2], line[i * 2 + 1], line[i * 2 + 2]
        love.graphics.polygon('fill', ax, ay, bx, by, bx, bottom, ax, bottom)
    end
    love.graphics.setColor(hexColor(setting(extra, 'surfaceColor')))
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(4)
    love.graphics.line(line)
    love.graphics.setLineWidth(lw)

    if compare then love.graphics.setStencilTest(compare, value) else love.graphics.setStencilTest() end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Let water above the mouth run out. Returns the amount spilled (area units).
function lib.spill(extra, body)
    local c = lib.container(extra, body)
    local full = lib.volume(c.hull, c.holes)
    if full <= 0 then return 0 end
    local amount = setting(extra, 'fill') * full
    local hull, holes = worldContainer(c, body)
    local capacity = lib.capacity(hull, holes, mouthY(c, hull))
    if amount <= capacity then return 0 end
    extra.fill = capacity / full
    return amount - capacity
end

-- Once per frame after the physics step: while playing, every container spills what it can't hold.
function lib.update(paused)
    if paused then return end
    for _, fixture in ipairs(registry.sfixturesOf(subtypes.LIQUID)) do -- not all of them (registry)
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

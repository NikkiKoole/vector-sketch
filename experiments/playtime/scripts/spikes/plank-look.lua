-- plank-look: a drawn plank's look, one copy for the plank boat (scripts/spikes/plank-boat.lua) and the planks
-- treehouse (2026-11-16, Nikki: "is that also related to the tree houses? seeing they have planks too"; their two
-- copies were ~2/3 the same). Only the look: how a plank is held (its own body on nails, a piece of one boat
-- body, or drawing only) stays the scene's. Nikki's crayon outline (src/drawn-stroke.lua), and on a plank grain
-- lines along it and a knot now and then.
-- Loaded with love.filesystem.load('scripts/spikes/plank-look.lua')().
--   make(p)                 p.pts: its outline (x, y, ...) in its own coordinates; p.kind 'plank' (four corners,
--                           the first two along one long side) gets grain and knots, anything else only the outline
--                           (a trunk, the ground, leaves). p.seed: where in the stroke pictures it starts.
--   draw(p, set, step)      fill (p.color, times p.shade) and the outline, in p's coordinates (the caller places
--                           it). set: width, wobble, seamless (default on), grain (amount, default 1), drawn (false:
--                           a plain line instead). step: the boil frame (0 still).
local lib = {}

local STROKE = require('src.drawn-stroke')
lib.STROKE = STROKE
lib.OUTLINE = { 0.2, 0.13, 0.1 }

function lib.make(p)
    local ox, oy = p.seed * 997 % 20000, p.seed * 613 % 20000
    p.sox, p.soy = ox, oy
    local q = p.pts
    local outline = {}
    for i = 1, #q, 2 do outline[#outline + 1] = { q[i] + ox, q[i + 1] + oy } end
    p.outlinePts = outline
    p.grainLines = {}
    p.meshKey = nil
    if p.kind ~= 'plank' or #q ~= 8 then return end
    -- a point at u along (0..1) and v across (0..1)
    local function at(u, v)
        local x1, y1 = q[1] + (q[3] - q[1]) * u, q[2] + (q[4] - q[2]) * u
        local x2, y2 = q[7] + (q[5] - q[7]) * u, q[8] + (q[6] - q[8]) * u
        return { x1 + (x2 - x1) * v + ox, y1 + (y2 - y1) * v + oy }
    end
    local lenX, lenY = (q[3] + q[5] - q[1] - q[7]) / 2, (q[4] + q[6] - q[2] - q[8]) / 2
    local len = math.sqrt(lenX * lenX + lenY * lenY)
    local thX, thY = (q[7] + q[5] - q[1] - q[3]) / 2, (q[8] + q[6] - q[2] - q[4]) / 2
    local thick = math.sqrt(thX * thX + thY * thY)
    for i = 1, math.max(1, math.floor(thick / 30)) do
        local v = 0.2 + love.math.random() * 0.6
        local u0, u1 = 0.05 + love.math.random() * 0.35, 0.6 + love.math.random() * 0.35
        local line = {}
        for k = 0, 6 do
            local u = u0 + (u1 - u0) * k / 6
            line[#line + 1] = at(u, v + math.sin(u * 7 + i) * 0.04)
        end
        p.grainLines[#p.grainLines + 1] = { pts = line, loop = false, width = 5, wobble = 0.6 }
    end
    if love.math.random() < 0.3 and len > 200 then
        local c = at(0.15 + love.math.random() * 0.7, 0.35 + love.math.random() * 0.3)
        local ang = math.atan2(lenY, lenX)
        local knot = {}
        for k = 0, 9 do
            local a = k / 10 * math.pi * 2
            local x, y = math.cos(a) * 16, math.sin(a) * 7
            local ca, sa = math.cos(ang), math.sin(ang)
            knot[#knot + 1] = { c[1] + x * ca - y * sa, c[2] + x * sa + y * ca }
        end
        p.grainLines[#p.grainLines + 1] = { pts = knot, loop = true, width = 5, wobble = 0.3 }
    end
end

local function meshes(p, set, step)
    local seamless = set.seamless ~= false
    local key = table.concat({ set.width, set.wobble, step, tostring(seamless) }, ',')
    if p.meshKey ~= key then
        local width = set.width * (p.lineScale or 1)
        local line = { { pts = p.outlinePts, loop = true, width = width } }
        p.outlineMeshes = STROKE.meshes(line, set.wobble, step, seamless)
        p.grainMeshes = STROKE.meshes(p.grainLines, set.wobble, step, seamless)
        p.meshKey = key
    end
    return p.outlineMeshes, p.grainMeshes
end

function lib.draw(p, set, step)
    local c, k = p.color, p.shade or 1
    local O = lib.OUTLINE
    love.graphics.setColor(c[1] * k, c[2] * k, c[3] * k)
    love.graphics.polygon('fill', p.pts)
    if set.drawn == false or #STROKE.strokes == 0 then
        love.graphics.setColor(O[1], O[2], O[3], 1)
        love.graphics.setLineWidth(3)
        love.graphics.polygon('line', p.pts)
        love.graphics.setLineWidth(1)
        return
    end
    local outline, grain = meshes(p, set, step)
    love.graphics.push()
    love.graphics.translate(-p.sox, -p.soy)
    local amount = set.grain or 1
    if amount > 0 then
        love.graphics.setColor(c[1] * k * 0.6, c[2] * k * 0.55, c[3] * k * 0.5, 0.55 * amount)
        for _, mesh in ipairs(grain) do love.graphics.draw(mesh) end
    end
    love.graphics.setColor(O[1], O[2], O[3], 1)
    for _, mesh in ipairs(outline) do love.graphics.draw(mesh) end
    love.graphics.pop()
end

return lib

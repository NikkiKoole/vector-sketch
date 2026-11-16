-- plank-boat: the plank boat of the boat2 and drawn-sea spikes, one copy (2026-11-16; they had the same ~250
-- lines). A clinker hull (rows of planks overlapping), a deck, a cabin of upright planks with a window, a roof,
-- a tin chimney, a railing in front of the Mipos; each plank a quad with its own crayon outline and grain
-- (src/drawn-stroke.lua), nails where planks overlap. Layers back / mid / front per plank.
-- Loaded with love.filesystem.load('scripts/spikes/plank-boat.lua')(). The boat's state `b` is the scene's:
-- b.settings (width, wobble, boil, wonk), and the kit fills b.planks, b.nails, b.chimney. The body is the
-- scene's (boat2 kinematic, drawn-sea floating): buildPlanks(b, { ballast = true }) gives the planks weights.
--   buildPlanks(b, opts), placeNails(b)   the planks in the body's own coordinates (keel at 0, deck DECK_Y)
--   drawBoat(b, front)                    back and mid planks, or the front ones (b.body, b.chimneyBody)
local lib = {}


local STROKE = require('src.drawn-stroke')
local OUTLINE = { 0.2, 0.13, 0.1 }
local NAVY = { 0.17, 0.24, 0.44 }
local CREAM = { 0.9, 0.86, 0.76 }
local RED = { 0.72, 0.27, 0.22 }
local WOODS = { { 0.74, 0.56, 0.38 }, { 0.66, 0.48, 0.33 }, { 0.8, 0.64, 0.45 }, { 0.6, 0.45, 0.34 } }
local TIN = { 0.5, 0.5, 0.52 }
local DECK_Y = -560   -- the hull's top; the keel is at 0, the body's origin
local LAYER_ORDER = { back = 1, mid = 2, front = 3 }
-- the chimney's top, in the boat's frame
local CHIMNEY = { -455, -1215 }

local function jitter(c, k)
    local j = 1 + (love.math.random() - 0.5) * (k or 0.1)
    return { c[1] * j, c[2] * j, c[3] * j }
end

-- the hull's sides: the stern raked a little, the bow curving back to the keel
local function sternX(y) local t = math.max(0, (y - DECK_Y) / -DECK_Y); return -640 + 90 * t * t end
local function bowX(y) local t = math.max(0, (y - DECK_Y) / -DECK_Y); return 620 - 300 * t ^ 1.6 end

local function pointInPoly(x, y, poly)
    local inside = false
    local n = #poly / 2
    local j = n
    for i = 1, n do
        local xi, yi = poly[i * 2 - 1], poly[i * 2]
        local xj, yj = poly[j * 2 - 1], poly[j * 2]
        if (yi > y) ~= (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi then inside = not inside end
        j = i
    end
    return inside
end

-- a plank as four corners (along its length: 1 -> 2 on one side, 4 -> 3 on the other)
-- wonky: each plank turned a little about its middle (less for long ones, so the hull rows still
-- meet) and each corner pushed a little off true
local function wonky(pts, w)
    if w <= 0 then return pts end
    local cx, cy, n = 0, 0, #pts / 2
    for i = 1, #pts, 2 do cx, cy = cx + pts[i] / n, cy + pts[i + 1] / n end
    local lx, ly = pts[3] - pts[1], pts[4] - pts[2]
    local len = math.max(1, math.sqrt(lx * lx + ly * ly))
    local a = (love.math.random() * 2 - 1) * w * math.min(0.035, 20 / len)
    local ca, sa = math.cos(a), math.sin(a)
    local push = 5 * w
    local out = {}
    for i = 1, #pts, 2 do
        local x, y = pts[i] - cx, pts[i + 1] - cy
        out[i] = cx + x * ca - y * sa + (love.math.random() * 2 - 1) * push
        out[i + 1] = cy + x * sa + y * ca + (love.math.random() * 2 - 1) * push
    end
    return out
end

local function quad(b, pts, opts)
    opts = opts or {}
    if not opts.hidden then pts = wonky(pts, b.settings.wonk or 1) end
    local p = { pts = pts, layer = opts.layer or 'mid', color = opts.color or jitter(WOODS[love.math.random(#WOODS)]),
        solid = opts.solid, kind = opts.kind or 'plank', lineScale = opts.lineScale, seed = love.math.random() * 1000,
        hidden = opts.hidden, chimney = opts.chimney, ballast = opts.ballast }
    b.planks[#b.planks + 1] = p
    return p
end

-- a plank from (x1, y1) to (x2, y2), thick wide, its ends cut a bit skew
local function plank(b, x1, y1, x2, y2, thick, opts)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    local ux, uy = dx / len, dy / len
    local nx, ny = -uy * thick / 2, ux * thick / 2
    local sk = thick * 0.2
    local function at(x, y, s) return x + ux * s, y + uy * s end
    local ax, ay = at(x1, y1, (love.math.random() - 0.5) * sk)
    local bx, by = at(x2, y2, (love.math.random() - 0.5) * sk)
    local cx, cy = at(x2, y2, (love.math.random() - 0.5) * sk)
    local ex, ey = at(x1, y1, (love.math.random() - 0.5) * sk)
    return quad(b, { ax - nx, ay - ny, bx - nx, by - ny, cx + nx, cy + ny, ex + nx, ey + ny }, opts)
end

-- the look: the outline points and the grain (long thin lines along it, now and then a knot),
-- shifted by the plank's seed so its strokes are its own
local function makeLook(p)
    local ox, oy = p.seed * 997 % 20000, p.seed * 613 % 20000
    p.sox, p.soy = ox, oy
    local q = p.pts
    local outline = {}
    for i = 1, #q, 2 do outline[#outline + 1] = { q[i] + ox, q[i + 1] + oy } end
    p.outlinePts = outline
    p.grainLines = {}
    if p.kind ~= 'plank' then return end
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
            knot[#knot + 1] = { c[1] + x * math.cos(ang) - y * math.sin(ang), c[2] + x * math.sin(ang) + y * math.cos(ang) }
        end
        p.grainLines[#p.grainLines + 1] = { pts = knot, loop = true, width = 5, wobble = 0.3 }
    end
end

-- opts.ballast: the hull's bottom rows heavy, the rest light (drawn-sea's floating boat); else no weights
local function buildPlanks(b, opts)
    b.planks = {}
    -- the hull: six rows overlapping (clinker), cream on top, red at the bottom
    local rows = 6
    local h = -DECK_Y / rows
    for i = 0, rows - 1 do
        local yt = DECK_Y + i * h - 8
        local yb = math.min(0, yt + h + 16)
        local color = i == 0 and jitter(CREAM, 0.05) or (i == rows - 1 and jitter(RED, 0.08) or jitter(NAVY, 0.15))
        -- ballast: the bottom rows heavy, the rest light, so it sits upright and rights itself
        local ballast = opts and opts.ballast and ((i == rows - 1 and 3) or (i == rows - 2 and 1.2) or 0.2) or nil
        quad(b, { sternX(yt), yt, bowX(yt), yt, bowX(yb), yb, sternX(yb), yb },
            { color = color, solid = true, ballast = ballast })
    end
    -- stem and stern posts
    plank(b, 330, -10, 640, DECK_Y - 40, 40, { color = jitter(WOODS[2]) })
    plank(b, -548, -10, -652, DECK_Y - 40, 36, { color = jitter(WOODS[2]) })
    -- the deck
    plank(b, -670, DECK_Y - 16, 655, DECK_Y - 18, 34, { solid = true })
    -- the cabin: upright planks, a window in the middle two
    local top, bottom = -945, DECK_Y - 30
    local cabinFrom = #b.planks + 1
    local x = -560
    local i = 0
    while x < -250 do
        local w = 78 + love.math.random() * 16
        local mid = x + w / 2
        i = i + 1
        if i == 2 or i == 3 then
            plank(b, mid, bottom, mid, -705, w, { layer = 'back' })
            plank(b, mid, -830, mid, top, w, { layer = 'back' })
        else
            plank(b, mid, bottom, mid, top, w, { layer = 'back' })
        end
        x = x + w + 3
    end
    plank(b, -500, -705, -290, -707, 26, { layer = 'back' })
    plank(b, -500, -830, -290, -828, 26, { layer = 'back' })
    plank(b, -470, -690, -472, -845, 22, { layer = 'back' })
    plank(b, -320, -690, -318, -845, 22, { layer = 'back' })
    -- corner posts (the front one solid: the Mipos stay out of the cabin) and the roof
    plank(b, -575, bottom + 10, -578, top - 10, 40, {})
    plank(b, -232, bottom + 10, -230, top - 10, 40, { solid = true })
    plank(b, -620, -965, -170, -961, 42, { color = jitter(RED, 0.08), solid = true })
    plank(b, -595, -999, -205, -1002, 30, { color = jitter(RED, 0.08), solid = true })
    -- a tin chimney with a cap
    quad(b, { -480, -1190, -430, -1190, -428, -1010, -482, -1010 }, { color = TIN, kind = 'tin', solid = true, chimney = true })
    quad(b, { -497, -1215, -413, -1215, -413, -1188, -497, -1188 }, { color = jitter(TIN, 0.1), kind = 'tin', solid = true, chimney = true })
    -- the whole cabin leans a little, like a shed that's settled; the chimney's top with it
    local lean = (love.math.random() < 0.5 and -1 or 1) * (0.025 + love.math.random() * 0.02) * (b.settings.wonk or 1)
    for i = cabinFrom, #b.planks do
        local q = b.planks[i].pts
        for k = 1, #q, 2 do q[k] = q[k] + (q[k + 1] - DECK_Y) * lean end
    end
    b.chimney = { CHIMNEY[1] + (CHIMNEY[2] - DECK_Y) * lean, CHIMNEY[2] }
    -- the railing, in front of the Mipos
    for _, px in ipairs({ -150, 70, 290, 500 }) do
        plank(b, px, DECK_Y - 20, px + (love.math.random() - 0.5) * 8, -745, 22, { layer = 'front' })
    end
    plank(b, -180, -740, 560, -746, 24, { layer = 'front' })
    plank(b, -180, -672, 540, -668, 18, { layer = 'front' })
    -- a wall at the bow nobody sees, so a Mipo stays aboard
    quad(b, { 600, -780, 640, -780, 640, DECK_Y - 30, 600, DECK_Y - 30 }, { solid = true, hidden = true })
    for _, p in ipairs(b.planks) do makeLook(p) end
end

local function bbox(pts)
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for k = 1, #pts, 2 do
        x0, x1 = math.min(x0, pts[k]), math.max(x1, pts[k])
        y0, y1 = math.min(y0, pts[k + 1]), math.max(y1, pts[k + 1])
    end
    return x0, y0, x1, y1
end

-- nails where two planks overlap, on whichever is drawn on top, one every so far along the overlap
local function placeNails(b)
    b.nails = {}
    local list = b.planks
    for i = 1, #list do
        for j = i + 1, #list do
            local pa, pb = list[i], list[j]
            if pa.kind == 'plank' and pb.kind == 'plank' and not pa.hidden and not pb.hidden then
                local top = (LAYER_ORDER[pb.layer] >= LAYER_ORDER[pa.layer]) and pb or pa
                -- only where their boxes overlap
                local ax0, ay0, ax1, ay1 = bbox(pa.pts)
                local bx0, by0, bx1, by1 = bbox(pb.pts)
                local x0, y0 = math.max(ax0, bx0), math.max(ay0, by0)
                local x1, y1 = math.min(ax1, bx1), math.min(ay1, by1)
                local inside = {}
                for y = y0, y1, 10 do
                    for x = x0, x1, 10 do
                        if pointInPoly(x, y, pa.pts) and pointInPoly(x, y, pb.pts) then inside[#inside + 1] = { x, y } end
                    end
                end
                if #inside >= 3 then
                    local q = top.pts
                    local ux, uy = q[3] - q[1], q[4] - q[2]
                    local ul = math.sqrt(ux * ux + uy * uy)
                    ux, uy = ux / ul, uy / ul
                    local umin, umax, vsum = math.huge, -math.huge, 0
                    for _, pt in ipairs(inside) do
                        local u = pt[1] * ux + pt[2] * uy
                        umin, umax = math.min(umin, u), math.max(umax, u)
                        vsum = vsum + (-pt[1] * uy + pt[2] * ux)
                    end
                    local v = vsum / #inside
                    local n = math.max(1, math.floor((umax - umin) / 130))
                    for k = 1, n do
                        local u = umin + (umax - umin) * (k - 0.5) / n
                        b.nails[#b.nails + 1] = { x = u * ux - v * uy, y = u * uy + v * ux, layer = top.layer }
                    end
                end
            end
        end
    end
end

local function plankMeshes(b, p, step)
    local set = b.settings
    local key = table.concat({ set.width, set.wobble, step }, ',')
    if p.meshKey ~= key then
        local width = set.width * (p.lineScale or 1)
        p.outlineMeshes = STROKE.meshes({ { pts = p.outlinePts, loop = true, width = width } }, set.wobble, step, true)
        p.grainMeshes = STROKE.meshes(p.grainLines, set.wobble, step, true)
        p.meshKey = key
    end
    return p.outlineMeshes, p.grainMeshes
end

local function drawPlank(b, p, step)
    if p.hidden then return end
    local c = p.color
    love.graphics.setColor(c[1], c[2], c[3])
    love.graphics.polygon('fill', p.pts)
    if #STROKE.strokes == 0 then return end
    local outline, grain = plankMeshes(b, p, step)
    love.graphics.push()
    love.graphics.translate(-p.sox, -p.soy)
    love.graphics.setColor(c[1] * 0.6, c[2] * 0.55, c[3] * 0.5, 0.55)
    for _, mesh in ipairs(grain) do love.graphics.draw(mesh) end
    love.graphics.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], 1)
    for _, mesh in ipairs(outline) do love.graphics.draw(mesh) end
    love.graphics.pop()
end

local function drawNails(b, layer)
    for _, n in ipairs(b.nails or {}) do
        if n.layer == layer then
            love.graphics.setColor(0.25, 0.24, 0.26)
            love.graphics.circle('fill', n.x, n.y, 7)
            love.graphics.setColor(0.6, 0.6, 0.62)
            love.graphics.circle('fill', n.x - 2, n.y - 2, 3)
        end
    end
end

local function drawBoat(b, front)
    if not (b.body and not b.body:isDestroyed()) then return end
    local x, y = b.body:getPosition()
    local step = b.settings.boil and math.floor(love.timer.getTime() * 10) % 3 or 0
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(b.body:getAngle())
    for _, layer in ipairs(front and { 'front' } or { 'back', 'mid' }) do
        for _, p in ipairs(b.planks) do
            if p.layer == layer and not p.chimney then drawPlank(b, p, step) end
        end
        drawNails(b, layer)
    end
    love.graphics.pop()
    local cb = b.chimneyBody
    if not front and cb and not cb:isDestroyed() then
        local cx, cy = cb:getPosition()
        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.rotate(cb:getAngle())
        for _, p in ipairs(b.planks) do
            if p.chimney then drawPlank(b, p, step) end
        end
        love.graphics.pop()
    end
end

lib.STROKE, lib.CHIMNEY, lib.DECK_Y = STROKE, CHIMNEY, DECK_Y
lib.buildPlanks, lib.placeNails, lib.drawBoat = buildPlanks, placeNails, drawBoat

return lib

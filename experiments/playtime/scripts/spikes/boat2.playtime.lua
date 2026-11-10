-- boat2: the boat spike again, the boat built from planks with drawn outlines (as in the planks spike) instead of the vector line art
-- v2 of `boat` (after experiments/walter-boat): the same sea, sky, smoke, fish and buoy (Nikki's
-- drawings), but the boat is planks: a clinker hull (rows of planks overlapping, riveted), a deck,
-- a cabin of upright planks with a window, a roof, a tin chimney, a railing in front of the Mipos.
-- Each plank is a fixture of one kinematic body, drawn with its own crayon outline and grain
-- (src/drawn-stroke.lua), nails where planks overlap. The chimney is its own body on a
-- springy weld. Layers (back / mid / front) are by hand per plank; the boat still wants a real back
-- layer, its far side behind the Mipos: docs/DEPTH-LAYERS.md.
--
-- play mode (tab): drag the Mipos about (throw one overboard).
-- keys: left / right slower / faster   m a Mipo   b boil   r build again (the wonk slider)   h the panel

local s = {}

local SHAPES = love.filesystem.load('scripts/spikes/boat-shapes.lua')()
local SCROLL = 140           -- world units a second per step of speed
local WATER_Y = -60          -- the waves' middle line
local BOAT_Y = 80            -- where the boat's origin sits: its keel

local function boat()
    state.boat2 = state.boat2 or {
        mipos = {}, showPanel = true, speed = 1, target = 1, pos = 0, time = 0, accel = 0,
        smoke = {}, smokeTimer = 0, fish = {}, clouds = {}, buoyX = 1800,
        settings = { bob = 1, tip = 1, sway = 1, float = 1, width = 9, wobble = 1.2, boil = false },
    }
    state.boat2.settings.wonk = state.boat2.settings.wonk or 1 -- added later: live states lack it
    return state.boat2
end

local function rnd(a, b) return a + love.math.random() * (b - a) end

---------------------------------------------------------------- the drawings as meshes

local function meshesOf(group)
    local out = {}
    for _, poly in ipairs(group) do
        local ok, tris = pcall(love.math.triangulate, poly.p)
        if ok and tris and #tris > 0 then
            local verts = {}
            for _, t in ipairs(tris) do
                for i = 1, 6, 2 do verts[#verts + 1] = { t[i], t[i + 1] } end
            end
            local mesh = love.graphics.newMesh({ { 'VertexPosition', 'float', 2 } }, verts, 'triangles', 'static')
            out[#out + 1] = { mesh = mesh, color = poly.c }
        end
    end
    return out
end

local DRAW = {}
local function drawings()
    if DRAW.clouds then return DRAW end
    DRAW.buoy = meshesOf(SHAPES.buoy[1])
    DRAW.clouds, DRAW.smoke, DRAW.fish = {}, {}, {}
    for i, g in ipairs(SHAPES.clouds) do DRAW.clouds[i] = meshesOf(g) end
    for i, g in ipairs(SHAPES.smoke) do DRAW.smoke[i] = meshesOf(g) end
    for i, g in ipairs(SHAPES.fish) do DRAW.fish[i] = meshesOf(g) end
    return DRAW
end

local function drawShape(meshes, alpha, tint)
    for _, m in ipairs(meshes) do
        local c = m.color
        local r, g, b = c[1], c[2], c[3]
        if tint then r, g, b = r * tint[1], g * tint[2], b * tint[3] end
        love.graphics.setColor(r, g, b, (c[4] or 1) * (alpha or 1))
        love.graphics.draw(m.mesh)
    end
end

---------------------------------------------------------------- the water

-- the height of a wave layer at x: a few slow sines that scroll with the boat's travel
local function waveY(layer, x, b)
    local p = b.pos * layer.parallax
    local t = b.time
    local y = math.sin((x + p) * 0.004 + t * 0.9 + layer.phase) * 22
        + math.sin((x + p) * 0.0105 - t * 1.3 + layer.phase * 2) * 10
        + math.sin((x + p) * 0.021 + t * 2.1) * 4
    return WATER_Y + layer.y + y * layer.amp
end

local LAYERS = {
    { y = -90, amp = 0.6, parallax = 0.5, phase = 1.1, color = { 0.62, 0.78, 0.88 }, front = false },
    { y = -45, amp = 0.8, parallax = 0.75, phase = 2.3, color = { 0.42, 0.64, 0.82 }, front = false },
    { y = 0, amp = 1, parallax = 1, phase = 0, color = { 0.28, 0.5, 0.75 }, front = false },
    { y = 55, amp = 1.1, parallax = 1.25, phase = 3.7, color = { 0.2, 0.4, 0.66 }, front = true, alpha = 0.85 },
    { y = 120, amp = 1.2, parallax = 1.5, phase = 5.1, color = { 0.14, 0.3, 0.55 }, front = true, alpha = 0.6 },
}
local SURFACE = LAYERS[3] -- the boat rides on this one, and things float on it

-- a fixed hand-made wobble per point, like walter-boat's wave_offsets
local JITTER = {}
for i = 1, 400 do JITTER[i] = love.math.random() * 6 - 3 end

local function drawWave(layer, b, x0, x1, bottom)
    local step = 40
    local first = math.floor(x0 / step) - 1
    local pts = {}
    for i = first, math.ceil(x1 / step) + 1 do
        local x = i * step
        local j = JITTER[(i % #JITTER) + 1]
        pts[#pts + 1] = x
        pts[#pts + 1] = waveY(layer, x, b) + j
    end
    local c = layer.color
    love.graphics.setColor(c[1], c[2], c[3], layer.alpha or 1)
    -- a strip of quads down to the bottom of the screen
    local verts = {}
    for i = 1, #pts - 2, 2 do
        local ax, ay, cx, cy = pts[i], pts[i + 1], pts[i + 2], pts[i + 3]
        verts[#verts + 1] = { ax, ay }; verts[#verts + 1] = { cx, cy }; verts[#verts + 1] = { ax, bottom }
        verts[#verts + 1] = { cx, cy }; verts[#verts + 1] = { cx, bottom }; verts[#verts + 1] = { ax, bottom }
    end
    if #verts >= 3 then
        local mesh = love.graphics.newMesh({ { 'VertexPosition', 'float', 2 } }, verts, 'triangles', 'stream')
        love.graphics.draw(mesh)
        mesh:release()
    end
    -- a pale crest line
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.setLineWidth(4)
    love.graphics.line(pts)
end

---------------------------------------------------------------- the boat: planks

local STROKE = drawnStroke()
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
        hidden = opts.hidden, chimney = opts.chimney }
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

local function buildPlanks(b)
    b.planks = {}
    -- the hull: six rows overlapping (clinker), cream on top, red at the bottom
    local rows = 6
    local h = -DECK_Y / rows
    for i = 0, rows - 1 do
        local yt = DECK_Y + i * h - 8
        local yb = math.min(0, yt + h + 16)
        local color = i == 0 and jitter(CREAM, 0.05) or (i == rows - 1 and jitter(RED, 0.08) or jitter(NAVY, 0.15))
        quad(b, { sternX(yt), yt, bowX(yt), yt, bowX(yb), yb, sternX(yb), yb }, { color = color, solid = true })
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

local function makeBoat(b)
    if b.body and not b.body:isDestroyed() then return end
    buildPlanks(b)
    placeNails(b)
    local thing = objectManager.addThing('rectangle', { x = 0, y = BOAT_Y, width = 10, height = 10,
        bodyType = 'kinematic', label = 'boat2' })
    if not thing then return end
    local body = thing.body
    for _, fixture in ipairs(body:getFixtures()) do fixture:destroy() end
    for _, p in ipairs(b.planks) do
        local ok, shape = pcall(love.physics.newPolygonShape, p.pts)
        if ok and not p.chimney then
            local fixture = love.physics.newFixture(body, shape, 1)
            fixture:setFriction(0.9)
            if not p.solid then fixture:setSensor(true) end
        end
    end
    b.body = body
    -- the chimney: its own body, light, on a springy weld at the roof, so it wobbles when the
    -- boat rocks and a Mipo can bump it or tug it
    local chim = objectManager.addThing('rectangle', { x = 0, y = BOAT_Y, width = 10, height = 10,
        bodyType = 'dynamic', label = 'boat2-chimney' })
    if chim then
        local cb = chim.body
        for _, fixture in ipairs(cb:getFixtures()) do fixture:destroy() end
        for _, p in ipairs(b.planks) do
            if p.chimney then
                local ok, shape = pcall(love.physics.newPolygonShape, p.pts)
                if ok then
                    local fixture = love.physics.newFixture(cb, shape, 0.3)
                    fixture:setFriction(0.6)
                end
            end
        end
        local base = b.chimney and { b.chimney[1], -1010 } or { -455, -1010 }
        local wx, wy = body:getWorldPoint(base[1], base[2])
        local joint = love.physics.newWeldJoint(body, cb, wx, wy, false)
        joint:setFrequency(4)
        joint:setDampingRatio(0.35)
        local id = 'boat2-chimney-weld-' .. tostring(love.math.random(1e6))
        joint:setUserData({ id = id, label = 'chimney' })
        registry.registerJoint(id, joint)
        b.chimneyBody = cb
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

local function aliveMipos(b) return mipoKit.alive(b.mipos) end -- src/mipo-kit.lua

local function spawnMipo(b, x, y) mipoKit.spawn(b.mipos, x, y) end -- src/mipo-kit.lua

local function partBodies(inst)
    local out = {}
    for _, part in pairs(inst.parts or {}) do
        if part.body and not part.body:isDestroyed() then out[#out + 1] = part.body end
    end
    return out
end

---------------------------------------------------------------- hooks

function s.onStart()
    worldState.paused = false
    local b = boat()
    makeBoat(b)
    b.mipos = aliveMipos(b)
    if #b.mipos == 0 then
        spawnMipo(b, -60, -900)
        spawnMipo(b, 320, -900)
    end
    if #b.fish == 0 then
        for i = 1, 7 do
            local dir = love.math.random() < 0.5 and -1 or 1
            b.fish[i] = { kind = love.math.random(#SHAPES.fish), x = rnd(-1500, 1500), y = rnd(260, 520),
                dir = dir, speed = rnd(60, 140), size = rnd(1.4, 2.2), wiggle = rnd(0, 6) }
        end
    end
    if #b.clouds == 0 then
        for i = 1, 6 do
            b.clouds[i] = { kind = love.math.random(#SHAPES.clouds), x = rnd(-1800, 1800), y = rnd(-1500, -900),
                size = rnd(2.5, 4), drift = rnd(0.15, 0.35) }
        end
    end
end

function s.onUnload()
    local b = state.boat2
    if b and b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local b = boat()
    if key == 'right' then b.target = math.min(6, b.target + 1)
    elseif key == 'left' then b.target = math.max(-2, b.target - 1)
    elseif key == 'm' then local mx, my = mouseWorldPos(); spawnMipo(b, mx, my)
    elseif key == 'b' then b.settings.boil = not b.settings.boil
    elseif key == 'r' then -- build the boat again (another wonk)
        if b.chimneyBody and not b.chimneyBody:isDestroyed() then objectManager.destroyBody(b.chimneyBody) end
        if b.body and not b.body:isDestroyed() then objectManager.destroyBody(b.body) end
        b.body, b.chimneyBody = nil, nil
        makeBoat(b)
    elseif key == 'h' then b.showPanel = not b.showPanel
    end
end


function s.update(dt)
    local b = state.boat2
    if not b or dt <= 0 or worldState.paused then return end
    local set = b.settings
    b.time = b.time + dt
    -- the speed eases to the target (walter-boat: flux over 3 s)
    local before = b.speed
    b.speed = b.speed + (b.target - b.speed) * math.min(1, dt * 0.9)
    local accel = (b.speed - before) / dt
    b.accel = b.accel + (accel - b.accel) * math.min(1, dt * 4)
    b.pos = b.pos + b.speed * SCROLL * dt

    -- the boat rides the surface: up and down with it, tipped along its slope, and tipped back
    -- when it speeds up (nose up), forward when it slows down
    if b.body and not b.body:isDestroyed() then
        local front, back = 400, -440
        local yf, yb = waveY(SURFACE, front, b), waveY(SURFACE, back, b)
        local ty = BOAT_Y + ((yf + yb) / 2 - WATER_Y) * 0.8 * set.bob
        local ta = math.atan2(yf - yb, front - back) * 0.6 * set.bob - b.accel * 0.05 * set.tip
        local x, y = b.body:getPosition()
        local a = b.body:getAngle()
        b.body:setLinearVelocity((0 - x) / dt * 0.5, (ty - y) / dt * 0.5)
        b.body:setAngularVelocity((ta - a) / dt * 0.5)
    end

    local gx, gy = state.physicsWorld:getGravity()
    local g = math.sqrt(gx * gx + gy * gy)
    b.mipos = aliveMipos(b)
    for _, inst in ipairs(b.mipos) do
        for _, body in ipairs(partBodies(inst)) do
            local m = body:getMass()
            local px, py = body:getPosition()
            -- on board: a push against the change of speed, so they sway
            body:applyForce(-b.accel * m * g * 0.12 * set.sway, 0)
            -- in the water: float, slowed down, carried back by the boat's travel
            local depth = py - waveY(SURFACE, px, b)
            if depth > 0 then
                local vx, vy = body:getLinearVelocity()
                local up = m * g * math.min(depth / 80, 1.6) * set.float
                local flow = -b.speed * SCROLL
                body:applyForce((flow - vx) * m * 2, -up - vy * m * 2.5)
            end
        end
    end

    -- smoke: puffs from the chimney, more often when going faster, blown back by the travel
    b.smokeTimer = b.smokeTimer - dt
    if b.smokeTimer <= 0 and b.body and not b.body:isDestroyed() then
        b.smokeTimer = 1.6 / (1 + math.abs(b.speed))
        local top = b.chimney or CHIMNEY
        local from = (b.chimneyBody and not b.chimneyBody:isDestroyed()) and b.chimneyBody or b.body
        local x, y = from:getWorldPoint(top[1], top[2])
        b.smoke[#b.smoke + 1] = { kind = love.math.random(#SHAPES.smoke), x = x, y = y, age = 0,
            life = rnd(2.5, 3.5), spin = rnd(-0.6, 0.6), angle = rnd(0, 6) }
    end
    local kept = {}
    for _, p in ipairs(b.smoke) do
        p.age = p.age + dt
        p.x = p.x - (b.speed * SCROLL * 0.9 + 10) * dt
        p.y = p.y - 70 * dt
        p.angle = p.angle + p.spin * dt
        if p.age < p.life then kept[#kept + 1] = p end
    end
    b.smoke = kept

    -- fish swim both ways; the travel carries them back; past the edge they come round again
    for _, f in ipairs(b.fish) do
        f.x = f.x + (f.dir * f.speed - b.speed * SCROLL) * dt
        if f.x < -2200 or f.x > 2200 then
            f.dir = f.x < 0 and 1 or -1
            f.x = f.x < 0 and -2100 or 2100
            f.y = rnd(260, 520)
        end
    end
    for _, c in ipairs(b.clouds) do
        c.x = c.x - (b.speed * SCROLL * c.drift + 8) * dt
        if c.x < -2600 then c.x = 2600 elseif c.x > 2600 then c.x = -2600 end
    end
    b.buoyX = b.buoyX - b.speed * SCROLL * dt
    if b.buoyX < -2400 then b.buoyX = rnd(2400, 4000) elseif b.buoyX > 4200 then b.buoyX = -2300 end
end

---------------------------------------------------------------- drawing

local function view()
    local x0, y0 = cam:getWorldCoordinates(0, 0)
    local x1, y1 = cam:getWorldCoordinates(love.graphics.getDimensions())
    return x0, y0, x1, y1
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

local function drawFish(b, d)
    for _, f in ipairs(b.fish) do
        love.graphics.push()
        love.graphics.translate(f.x, f.y + math.sin(b.time * 2 + f.wiggle) * 8)
        love.graphics.rotate(math.sin(b.time * 3 + f.wiggle) * 0.08)
        love.graphics.scale(-f.dir * f.size, f.size) -- the drawings swim left
        drawShape(d.fish[f.kind], 0.9)
        love.graphics.pop()
    end
end

function s.drawBelow()
    local b = state.boat2
    if not b then return end
    local d = drawings()
    local x0, y0, x1, y1 = view()
    -- the sky
    love.graphics.push()
    love.graphics.origin()
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(0.67, 0.83, 0.92)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.pop()
    -- clouds, see-through like walter-boat's
    for _, c in ipairs(b.clouds) do
        love.graphics.push()
        love.graphics.translate(c.x + b.pos * 0, c.y)
        love.graphics.scale(c.size)
        drawShape(d.clouds[c.kind], 0.6)
        love.graphics.pop()
    end
    -- the far waves
    for _, layer in ipairs(LAYERS) do
        if not layer.front then drawWave(layer, b, x0, x1, y1 + 50) end
    end
    -- the buoy, bobbing on the surface
    love.graphics.push()
    local by = waveY(SURFACE, b.buoyX, b)
    love.graphics.translate(b.buoyX, by + 20)
    love.graphics.rotate(math.sin(b.time * 1.7) * 0.15)
    love.graphics.scale(2.2)
    drawShape(d.buoy)
    love.graphics.pop()
    drawBoat(b)
    -- smoke puffs: grow and fade
    for _, p in ipairs(b.smoke) do
        local t = p.age / p.life
        love.graphics.push()
        love.graphics.translate(p.x, p.y)
        love.graphics.rotate(p.angle)
        love.graphics.scale(0.8 + t * 2.2)
        drawShape(d.smoke[p.kind], (1 - t) * 0.8)
        love.graphics.pop()
    end
    if state.playMode then
        b.savedDrawBodies = state.world.debugDrawBodies
        state.world.debugDrawBodies = false
    end
    b.drawing = true
end

function s.draw()
    local b = state.boat2
    if not (b and b.drawing) then return end
    b.drawing = nil
    if b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
    local d = drawings()
    local x0, _, x1, y1 = view()
    -- the near waves in front of the hull and the Mipos' feet, the fish between them
    drawBoat(b, true)
    drawWave(LAYERS[4], b, x0, x1, y1 + 50)
    drawFish(b, d)
    drawWave(LAYERS[5], b, x0, x1, y1 + 50)
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local b = state.boat2 and boat()
    if not (b and state.playMode and b.showPanel) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 400
    local rows = { { 'bob', 0, 2 }, { 'tip', 0, 3 }, { 'sway', 0, 3 }, { 'float', 0, 2 }, { 'width', 2, 30 },
        { 'wobble', 0, 4 }, { 'wonk', 0, 3 } }
    local h = (BH + pad) * (#rows + 2) + pad + 24
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• boat2 ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        for _, row in ipairs(rows) do
            local key = row[1]
            local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('boat2' .. key, x, y, 180, row[2], row[3], b.settings[key], nil, 0.01)
            if v then b.settings[key] = v + 0 end
            ui.label(x + 280, y, key == 'wonk' and 'wonk (r: build)' or key)
        end
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, string.format('speed %d  (left / right)', b.target))
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'm a Mipo   b boil   r build again   h panel')
    end)
end

return s

-- oaktree: Mipos at mole size under and in one giant oak: a burrow to dig, treehouses, ladders, slides, a swing, balconies
-- Nikki 2026-11-16: "imagine mipos being like mole, groundsquirrel size, a burrow we can dig, a large tree,
-- tree houses, slides, ladders, balcony, etc". At this size a tree is ~15 Mipos tall (WORLD-METRICS: real
-- trees are 15-20), so the camera never shows it whole.
-- Made of the spikes' parts, nothing new underneath:
--   the earth        scripts/spikes/burrow.playtime.lua, loaded with options (its own state, a wider world,
--                    a burrow already dug: a molehill, a den, a tunnel under the tree, a pantry, a back door)
--   the oak          tree-kinds / tree-grow / tree-mesh / bark-look (the bark spike), grown big and old; the
--                    walkable limb and the roots are extra branches in the same bark
--   ladders, slides, the swing   scripts/spikes/rig-zones.lua (climbing rung to rung, sitting down a chute)
--   planks           the crayon outline from src/drawn-stroke.lua (the planks spike's look, static here)
-- play mode (tab): drag on the earth to dig (shift: put earth back), drag Mipos up ladders, onto slides.
-- keys: 1-4 the camera to the burrow / the ground / the treehouses / the top   n a Mipo at the mouse
--       z the zones   h the panel   (the burrow's own: [ ] brush, t o b i looks, r reset the earth)
local s = {}

local rig = love.filesystem.load('scripts/spikes/rig-zones.lua')()
local KINDS = love.filesystem.load('scripts/spikes/tree-kinds.lua')()
local treeGrow = love.filesystem.load('scripts/spikes/tree-grow.lua')()
local treeMesh = love.filesystem.load('scripts/spikes/tree-mesh.lua')()
local barkLook = love.filesystem.load('scripts/spikes/bark-look.lua')()
local STROKE = drawnStroke()

local WORLD_W = 20000
-- The tree is regrown from the panel (st().tree: kind, bark, seed, age, size, organic). Every kind is grown to
-- about the same height, ~15 Mipos (TALL / its storybook height in Mipos, WORLD-METRICS), so the treehouses
-- stay in its crown; 'size' scales that. Age above ~1.5 melted an oak's foot into waves.
local TALL = 14.4
local KIND_MIPOS = { oak = 4.5, elm = 5, beech = 5, plane = 5, olive = 2.5, pine = 6, poplar = 6, aspen = 4,
    birch = 4 }
local KIND_NAMES = { 'oak', 'elm', 'beech', 'plane', 'olive', 'pine', 'poplar', 'aspen', 'birch' }
-- the barks (textures/world/bark, the bark spike's picks): id, name, the tint for its look, and for the white
-- ones their eyes (branch scars) and that the photo repeats mirror-wise
local BARKS = {
    { bark = '16', name = 'old mossy', tint = { 0.4, 0.4, 0.3 } },
    { bark = '01', name = 'oak', tint = { 0.42, 0.4, 0.37 } },
    { bark = '13', name = 'mossy', tint = { 0.47, 0.5, 0.33 } },
    { bark = '02', name = 'elm', tint = { 0.52, 0.45, 0.35 } },
    { bark = '07', name = 'cracked', tint = { 0.66, 0.66, 0.5 } },
    { bark = '10', name = 'beech', tint = { 0.58, 0.6, 0.53 } },
    { bark = '03', name = 'smooth brown', tint = { 0.55, 0.42, 0.3 } },
    { bark = '15', name = 'striped', tint = { 0.55, 0.47, 0.33 } },
    { bark = '09', name = 'plane', tint = { 0.8, 0.8, 0.66 } },
    { bark = '08', name = 'olive', tint = { 0.56, 0.5, 0.28 } },
    { bark = '12', name = 'cork', tint = { 0.56, 0.45, 0.28 } },
    { bark = '04', name = 'pine', tint = { 0.6, 0.5, 0.47 } },
    { bark = '14', name = 'red', tint = { 0.5, 0.33, 0.26 } },
    { bark = '11', name = 'grey', tint = { 0.62, 0.64, 0.6 } },
    { bark = '06', name = 'lichen', tint = { 0.55, 0.56, 0.58 } },
    { bark = 'aspen-01', name = 'aspen', tint = { 0.88, 0.88, 0.84 }, mirrored = true, eyes = 5, kinds = { 1, 1, 1, 2 } },
    { bark = 'birch-01', name = 'birch', tint = { 0.9, 0.89, 0.86 }, mirrored = true, eyes = 3, kinds = { 2, 3 } },
}
-- each kind's own barks (for 'another tree')
local KIND_BARKS = { oak = { '16', '01', '13' }, elm = { '02', '07' }, beech = { '10', '03', '15' },
    plane = { '09' }, olive = { '08', '12' }, pine = { '04', '14' }, poplar = { '11', '06' }, aspen = { 'aspen-01' },
    birch = { 'birch-01' } }
local function barkIndex(id)
    for i, b in ipairs(BARKS) do if b.bark == id then return i end end
    return 1
end

---------------------------------------------------------------- the burrow, dug before they came

local function hump(x, cx, w, h) return h * math.exp(-((x - cx) / w) ^ 2) end

-- the grass line: the burrow's own wobble, flat near the tree, a molehill by each way in
local function surfaceAt(x, height)
    local flat = math.min(1, math.max(0, (math.abs(x) - 1500) / 2500))
    return height * flat - hump(x, -4900, 420, 230) - hump(x, 4100, 380, 180)
end

-- how far (cells) a point is inside a tunnel: a round-ended line from a to b, r wide each side
local function tunnel(x, y, ax, ay, bx, by, r, cell)
    local dx, dy = bx - ax, by - ay
    local t = math.max(0, math.min(1, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)))
    local px, py = ax + dx * t - x, ay + dy * t - y
    return (r - math.sqrt(px * px + py * py)) / cell
end

-- floors flat (WORLD-METRICS: from 10 degrees they walk downhill), rooms Mipo-high and more
local function hollow(x, y, cell, room)
    return math.max(
        tunnel(x, y, -4500, -150, -3900, 950, 380, cell),    -- the way in, under the west molehill
        room(x, y, -3000, 1450, 2400, 1000, 380),             -- the den
        tunnel(x, y, -1900, 1550, 1300, 1550, 400, cell),    -- under the tree
        room(x, y, 2200, 1450, 1700, 1000, 380),              -- the pantry
        tunnel(x, y, 2800, 1000, 3800, -150, 360, cell))     -- the back door, under the east molehill
end

-- the oak panel's rectangle on screen (drawUI keeps it), so a press on it doesn't dig
local oakPanelRect
local function overOakPanel()
    local r = oakPanelRect
    if not r then return false end
    local mx, my = love.mouse.getPosition()
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

-- loaded at each start: state and world reach a scene's names only then (scene-loader's setEnv)
local earth
local function loadEarth()
    return love.filesystem.load('scripts/spikes/burrow.playtime.lua')({
        -- the scene names it uses (it runs in the plain globals)
        env = { state = state, world = world, cam = cam, camera = camera, ui = ui, objectManager = objectManager,
            fixtures = fixtures, shape8Dict = shape8Dict, characterManager = characterManager, worldState = worldState,
            mouseWorldPos = mouseWorldPos, getInteractedWithPointer = getInteractedWithPointer, love = love,
            math = math, table = table, string = string, pairs = pairs, ipairs = ipairs, unpack = unpack,
            print = print, tostring = tostring, tonumber = tonumber, type = type, pcall = pcall },
        stateKey = 'oakEarth', w = WORLD_W, h = 4800, y0 = -1200, rocks = 40, noMipos = true,
        surfaceAt = surfaceAt, hollow = hollow,
        canDig = function(_, y) return y > -350 and not overOakPanel() end, -- (in the air a press is for the treehouses)
        sharedFrame = true,
        bounds = { -WORLD_W / 2, -13000, WORLD_W / 2, 3600 },
    })
end

---------------------------------------------------------------- state

local function st()
    state.oakTree = state.oakTree or { showPanel = true, showZones = false, mipos = {} }
    state.oakTree.tree = state.oakTree.tree or { kind = 'oak', bark = 1, seed = 4242, age = 1.2, size = 1,
        organic = 0.7 }
    return state.oakTree
end

---------------------------------------------------------------- bodies and zones (the rigzones scene's helpers)

local function box(x, y, w, h, label, friction, angle)
    local thing = objectManager.addThing('rectangle', { x = x, y = y, width = w, height = h,
        bodyType = 'static', label = label })
    if thing then
        if angle then thing.body:setAngle(angle) end
        for _, f in ipairs(thing.body:getFixtures()) do
            if not f:isSensor() then f:setFriction(friction or 0.9) end
        end
    end
    return thing
end

local function sensors(thing)
    if thing then for _, f in ipairs(thing.body:getFixtures()) do f:setSensor(true) end end
    return thing
end

-- a one-way floor (src/depth-layers.lua's back layer): a Mipo dragged up from below, or climbing a ladder,
-- passes through; dropped on it from above, it stands there
local function oneWay(thing)
    if thing then thing.layer = 'back' end
    return thing
end

local function rectZone(kind, body, x1, y1, x2, y2, extra)
    local z = extra or {}
    z.kind, z.body = kind, body
    z.inside = function(x, y) return x > x1 and x < x2 and y > y1 and y < y2 end
    z.outline = { x1, y1, x2, y1, x2, y2, x1, y2, x1, y1 }
    return rig.addZone(z)
end

---------------------------------------------------------------- planks: what's drawn

-- Every plank is a quad (a little crooked, ends cut skew) with a crayon outline; in three layers: back
-- (walls, roofs, ladders, braces: behind the Mipos), mid (floors: behind them, they stand on it), front
-- (railings, in front of them). Static: the planks spike's nails and falling planks aren't here.
local OUTLINE = { 0.2, 0.13, 0.1 }
local WOODS = {
    { 0.74, 0.56, 0.38 }, { 0.66, 0.48, 0.33 }, { 0.8, 0.64, 0.45 }, { 0.6, 0.45, 0.34 },
    { 0.7, 0.6, 0.48 }, { 0.56, 0.4, 0.28 },
}
local PAINTED = { { 0.5, 0.63, 0.7 }, { 0.74, 0.42, 0.36 }, { 0.55, 0.65, 0.45 }, { 0.88, 0.82, 0.66 } }
local LEAVES = { { 0.36, 0.56, 0.3 }, { 0.42, 0.62, 0.32 }, { 0.3, 0.48, 0.28 }, { 0.48, 0.66, 0.36 } }
-- needles darker and bluer, birch and aspen lighter
local KIND_LEAVES = {
    pine = { { 0.2, 0.36, 0.3 }, { 0.24, 0.4, 0.32 }, { 0.17, 0.32, 0.27 } },
    birch = { { 0.52, 0.7, 0.36 }, { 0.58, 0.74, 0.4 }, { 0.46, 0.64, 0.34 } },
    aspen = { { 0.55, 0.72, 0.38 }, { 0.62, 0.76, 0.42 }, { 0.5, 0.66, 0.35 } },
}
local CHUTE_COLOURS = { { 0.86, 0.36, 0.26 }, { 0.95, 0.74, 0.3 }, { 0.42, 0.6, 0.78 } }

local rng -- the build's own, so the treehouses come out the same every time
local function rnd(a, b) return a + rng:random() * (b - a) end
local function pick(list) return list[rng:random(1, #list)] end

local look -- { back = {planks}, mid = {...}, front = {...}, chutes = {...}, leavesBack, leavesFront }
local function plank(layer, x1, y1, x2, y2, thick, colour)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    local ux, uy = dx / len, dy / len
    local nx, ny = -uy, ux
    local h = thick / 2
    local function j() return rnd(-thick * 0.12, thick * 0.12) end
    local s1, s2 = rnd(-0.25, 0.25) * thick, rnd(-0.25, 0.25) * thick -- the skew cut at each end
    local verts = {
        x1 - nx * h + ux * s1 + j(), y1 - ny * h + uy * s1 + j(),
        x2 - nx * h + ux * s2 + j(), y2 - ny * h + uy * s2 + j(),
        x2 + nx * h - ux * s2 + j(), y2 + ny * h - uy * s2 + j(),
        x1 + nx * h - ux * s1 + j(), y1 + ny * h - uy * s1 + j(),
    }
    colour = colour or (rng:random() < 0.08 and pick(PAINTED) or pick(WOODS))
    local shade = rnd(0.92, 1.05)
    local p = { verts = verts, colour = { colour[1] * shade, colour[2] * shade, colour[3] * shade },
        thick = thick, x1 = x1, y1 = y1, x2 = x2, y2 = y2 }
    look[layer][#look[layer] + 1] = p
    return p
end

-- a run of planks along a line, each its own length, a little gap between
local function plankRun(layer, x1, y1, x2, y2, thick, minLen, maxLen)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    local d = 0
    while d < len - 1 do
        local l = math.min(len - d, rnd(minLen, maxLen))
        if len - d - l < minLen * 0.5 then l = len - d end
        local a, b = d / len, (d + l) / len
        plank(layer, x1 + dx * a, y1 + dy * a + rnd(-4, 4), x1 + dx * b - dx / len * 14, y1 + dy * b + rnd(-4, 4), thick)
        d = d + l
    end
end

---------------------------------------------------------------- the treehouse parts

-- a floor: solid along its top (`top` the y a Mipo stands at), planks seen edge-on and a beam under
local function deck(x1, x2, top)
    oneWay(box((x1 + x2) / 2, top + 40, x2 - x1, 80, 'oak-deck'))
    plankRun('mid', x1, top + 28, x2, top + 28, 56, 700, 1400)
    plankRun('mid', x1 + 80, top + 100, x2 - 80, top + 100, 90, 1200, 2200)
end

-- braces from under a floor in to the trunk (drawn: the trunk isn't a body)
local function braces(x1, x2, top, toTrunkX)
    for _, x in ipairs({ x1 + 200, x2 - 200 }) do
        local tx = toTrunkX + (x < toTrunkX and -1 or 1) * 300
        if math.abs(x - toTrunkX) > 500 then
            plank('back', x, top + 120, tx, top + 120 + math.min(1100, math.abs(x - tx) * 0.8), 70)
        end
    end
end

-- a house on a floor: a back wall of upright planks with a window, corner posts, a roof
local function house(x1, x2, top, height, windowAt)
    local wy = top - height
    local x = x1
    while x < x2 - 40 do
        local w = math.min(x2 - x, rnd(150, 230))
        local cx = x + w / 2
        local inWindow = windowAt and math.abs(cx - windowAt) < 260
        if inWindow then
            -- below and above the window
            plank('back', cx, top - 20, cx, top - height * 0.35, w - 16)
            plank('back', cx, top - height * 0.72, cx, wy, w - 16)
        else
            plank('back', cx + rnd(-6, 6), top - 10, cx + rnd(-6, 6), wy + rnd(-20, 20), w - 16)
        end
        x = x + w
    end
    if windowAt then
        local y1, y2 = top - height * 0.35, top - height * 0.72
        plank('back', windowAt - 300, y1, windowAt + 300, y1, 50)
        plank('back', windowAt - 300, y2, windowAt + 300, y2, 50)
        plank('back', windowAt, y1, windowAt, y2, 36)
    end
    plank('back', x1 + 30, top, x1 + 30, wy - 40, 80)
    plank('back', x2 - 30, top, x2 - 30, wy - 40, 80)
    -- the roof: two slopes of planks meeting over the middle, overhanging
    local mid, peak = (x1 + x2) / 2, wy - (x2 - x1) * 0.3
    local over = 220
    for k = 0, 2 do
        local dy = k * 60
        plank('back', x1 - over, wy + 60 - dy * 0.3 + 40, mid, peak + 40 - dy, 70, PAINTED[2])
        plank('back', mid, peak + 40 - dy, x2 + over, wy + 60 - dy * 0.3 + 40, 70, PAINTED[2])
    end
    -- something to stand on: each slope one-way along its top plank (put a Mipo up there; lifted from inside the
    -- house it passes through)
    local eaveY, ridgeY = wy + 100 - 36, peak + 40 - 120
    for _, side in ipairs({ { x1 - over, eaveY, mid, ridgeY }, { mid, ridgeY, x2 + over, eaveY } }) do
        local ax, ay, bx, by = side[1], side[2], side[3], side[4]
        local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
        oneWay(box((ax + bx) / 2, (ay + by) / 2, len, 70, 'oak-roof', 0.95, math.atan2(by - ay, bx - ax)))
    end
end

-- a railing along a floor's front, drawn in front of the Mipos (posts and a rail)
local function railing(x1, x2, top, height)
    height = height or 300
    local n = math.max(1, math.floor((x2 - x1) / 320))
    for i = 0, n do
        local x = x1 + (x2 - x1) * i / n
        plank('front', x + rnd(-10, 10), top + 20, x + rnd(-10, 10), top - height - 30, 50)
    end
    plank('front', x1 - 40, top - height, x2 + 40, top - height + rnd(-10, 10), 50)
    plank('front', x1, top - height * 0.5, x2, top - height * 0.5 + rnd(-10, 10), 34)
end

-- a solid post at a floor's open end: it stops feet (WORLD-METRICS: a lip of 70 is enough)
local function endPost(x, top)
    box(x, top - 110, 50, 220, 'oak-post')
    plank('mid', x, top + 10, x, top - 230, 60)
end

-- a ladder from a floor up past the next: the rig's rung grip (rigzones' ladder, any height)
local function ladder(x, bottom, topY)
    local height = bottom - topY
    local rail = sensors(box(x - 130, bottom - height / 2, 24, height, 'oak-ladder'))
    sensors(box(x + 130, bottom - height / 2, 24, height, 'oak-ladder'))
    local rungs = {}
    for y = bottom - 150, topY + 40, -140 do
        sensors(box(x, y, 260, 16, 'oak-ladder-rung'))
        rungs[#rungs + 1] = y
    end
    if rail then
        rectZone('ladder', rail.body, x - 170, topY - 100, x + 170, bottom + 10,
            { bar = { x1 = x - 120, x2 = x + 120, y = rungs[1], rungs = rungs }, pullAway = 260 })
    end
    plank('back', x - 130, bottom + 10, x - 130 + rnd(-8, 8), topY, 44)
    plank('back', x + 130, bottom + 10, x + 130 + rnd(-8, 8), topY, 44)
    for _, y in ipairs(rungs) do plank('back', x - 150, y, x + 150, y + rnd(-8, 8), 30) end
end

-- points from (x0, y0) to (x1, y1), eased (default flat at both ends)
local function curve(x0, y0, x1, y1, n, ease)
    local out = {}
    for i = 0, n do
        local t = i / n
        local e = ease and ease(t) or t * t * (3 - 2 * t)
        out[#out + 1] = { x0 + (x1 - x0) * t, y0 + (y1 - y0) * e }
    end
    return out
end

-- a slide along points (its top, from where you sit down to the end): rigzones' chute
local function chute(points, colour)
    local dir = points[#points][1] > points[1][1] and 1 or -1
    local verts = {}
    for _, p in ipairs(points) do verts[#verts + 1], verts[#verts + 2] = p[1], p[2] end
    for i = #points, 1, -1 do verts[#verts + 1], verts[#verts + 2] = points[i][1], points[i][2] + 30 end
    local cx, cy = mathutils.computeCentroid(verts)
    local thing = objectManager.addThing('ribbon', { x = cx, y = cy, vertices = verts, bodyType = 'static',
        label = 'oak-chute' })
    if not thing then return end
    for _, f in ipairs(thing.body:getFixtures()) do f:setFriction(0.06) end
    oneWay(thing) -- (the big one spans the grass: a Mipo can be lifted up through it)
    local sorted = {}
    for _, p in ipairs(points) do sorted[#sorted + 1] = p end
    table.sort(sorted, function(a, b) return a[1] < b[1] end)
    local function segment(px)
        for i = 1, #sorted - 1 do
            if px <= sorted[i + 1][1] then return sorted[i], sorted[i + 1] end
        end
        return sorted[#sorted - 1], sorted[#sorted]
    end
    local function surface(px)
        local a, b = segment(px)
        local t = (px - a[1]) / math.max(1e-6, b[1] - a[1])
        return a[2] + (b[2] - a[2]) * math.max(0, math.min(1, t))
    end
    local function slopeAt(px)
        local a, b = segment(px)
        return math.atan(dir * (b[2] - a[2]) / math.max(1e-6, b[1] - a[1]))
    end
    local x1, x2, band = sorted[1][1], sorted[#sorted][1], 560
    local outline = {}
    for i = 1, #sorted do outline[#outline + 1], outline[#outline + 2] = sorted[i][1], sorted[i][2] - band end
    for i = #sorted, 1, -1 do outline[#outline + 1], outline[#outline + 2] = sorted[i][1], sorted[i][2] + 10 end
    outline[#outline + 1], outline[#outline + 2] = outline[1], outline[2]
    rig.addZone({ kind = 'slide', body = thing.body, dir = dir, slopeAt = slopeAt, outline = outline,
        inside = function(px, py)
            if px < x1 or px > x2 then return false end
            local sy = surface(px)
            return py < sy + 10 and py > sy - band
        end })
    look.chutes[#look.chutes + 1] = { points = points, colour = colour }
    -- legs down to the ground every so often (drawn, behind)
    for i = 6, #points - 4, 8 do
        local p = points[i]
        if p[2] < -400 and p[2] > -3300 then plank('back', p[1], p[2] + 40, p[1] + rnd(-30, 30), 0, 50) end
    end
    return thing
end

-- a swing hanging from a body (the limb): rigzones' swing, without its frame
local function swing(pivotBody, px, py, ropeLength)
    local seat = objectManager.addThing('rectangle', { x = px, y = py + ropeLength, width = 300, height = 30,
        label = 'oak-swing-seat' })
    if not seat then return end
    local sb = seat.body
    for _, f in ipairs(sb:getFixtures()) do
        f:setCategory(rig.SEAT)
        f:setFriction(0.9)
    end
    local pivot = { px, py }
    love.physics.newRevoluteJoint(pivotBody, sb, px, py, false)
    sb:setAngularDamping(0.05)
    rig.addZone({ kind = 'swing', body = sb, pivot = pivot,
        inside = function(x, y)
            local lx, ly = sb:getLocalPoint(x, y)
            return lx > -170 and lx < 170 and ly > -560 and ly < 20
        end,
        seatNow = function()
            local cx, cy = sb:getPosition()
            return { x1 = cx - 150, x2 = cx + 150, top = cy - 15 }
        end,
        outlineNow = function()
            local out = {}
            for _, c in ipairs({ { -170, -560 }, { 170, -560 }, { 170, 20 }, { -170, 20 }, { -170, -560 } }) do
                local wx, wy = sb:getWorldPoint(c[1], c[2])
                out[#out + 1], out[#out + 2] = wx, wy
            end
            return out
        end })
    st().swing = { seat = sb, pivot = pivot }
end

---------------------------------------------------------------- the oak

-- A branch the grower didn't grow, in its format (tree-grow: points with width and length so far): the
-- walkable limb and the roots, so they come out in the same bark and outline.
local function extraBranch(points, depth)
    local pts, along = {}, 0
    for i, p in ipairs(points) do
        if i > 1 then along = along + math.sqrt((p[1] - points[i - 1][1]) ^ 2 + (p[2] - points[i - 1][2]) ^ 2) end
        local q = points[math.min(#points, i + 1)]
        local r = points[math.max(1, i - 1)]
        pts[#pts + 1] = { x = p[1], y = p[2], w = p[3], wl = p[3], wr = p[3], along = along,
            a = math.atan2(q[2] - r[2], q[1] - r[1]) }
    end
    return { pts = pts, depth = depth }
end

-- the limb: out of the trunk's left side, nearly level (a Mipo walks along it), thinning; its top line
local LIMB = { x1 = -900, y1 = -4700, x2 = -5800, y2 = -4960, w1 = 420, w2 = 200 }
local function limbTop(x)
    local t = (x - LIMB.x1) / (LIMB.x2 - LIMB.x1)
    return LIMB.y1 + (LIMB.y2 - LIMB.y1) * t
end

local tree, roots
local function treeKey(t) return table.concat({ t.kind, t.bark, t.seed, t.age, t.size, t.organic }, '|') end
local function growTree()
    local t = st().tree
    local TREE_DEF = BARKS[t.bark] or BARKS[1]
    local r = love.math.newRandomGenerator(t.seed)
    local branches, aged = treeGrow.grow(KINDS[t.kind], r, 0, 420, -math.pi / 2 + 0.02,
        -- (at most 4x: an olive at 5.8x was all trunk, it stands lower instead)
        math.min(4, TALL / KIND_MIPOS[t.kind]) * t.size,
        { organic = t.organic, wind = 0.15, sun = -0.2, crowd = 0, age = t.age })
    -- the limb, its middle line half its width under the top, a little bend
    local pts = {}
    for i = 0, 12 do
        local t = i / 12
        local x = LIMB.x1 + (LIMB.x2 - LIMB.x1) * t
        local w = LIMB.w1 + (LIMB.w2 - LIMB.w1) * t
        pts[#pts + 1] = { x + (i == 0 and 500 or 0), limbTop(x) + w / 2 - 20 + math.sin(t * 3) * 12, w }
    end
    pts[#pts + 1] = { LIMB.x2 - 500, LIMB.y2 - 300, 90 } -- its tip turning up
    branches[#branches + 1] = extraBranch(pts, 1)
    tree = { def = TREE_DEF, x = 0, ground = 0, parts = treeMesh.parts(branches, 0.61), key = treeKey(t) }
    tree.eyes, tree.mipoEyes = barkLook.placeEyes(TREE_DEF, aged, branches[1].pts, r, t.age)
    -- the roots: out of the trunk's foot above the grass (an old oak's flare), then down through the earth
    local rootBranches = {}
    for k = 1, 8 do
        local side = k % 2 == 0 and 1 or -1
        local deg = 6 + math.floor((k - 1) / 2) * 16 -- fanning out, steeper each pair
        local a = math.rad(side > 0 and deg or 180 - deg)
        local len = 1800 + r:random() * 1800
        local x, y, w = side * (120 + k * 50), -180, 380 - k * 20
        local rp = { { x, y, w } }
        for i = 1, 14 do
            a = a + (r:random() - 0.5) * 0.5 + (math.pi / 2 - a) * 0.03 -- wandering, pulled down
            x, y = x + math.cos(a) * len / 14, y + math.sin(a) * len / 14
            w = w * 0.86
            rp[#rp + 1] = { x, y, math.max(24, w) }
        end
        rootBranches[#rootBranches + 1] = extraBranch(rp, 1)
    end
    roots = { def = TREE_DEF, x = 0, ground = 0, parts = treeMesh.parts(rootBranches, 1.7), eyes = {}, mipoEyes = {} }
    -- leaves: a clump at the end of every outer branch, most behind the treehouses, a few in front
    look.leavesBack, look.leavesFront = {}, {}
    local deepest = 0
    for _, br in ipairs(branches) do deepest = math.max(deepest, br.depth) end
    local leafy = KIND_LEAVES[t.kind] or LEAVES
    for _, br in ipairs(branches) do
        if br.depth >= math.max(1, deepest - 1) then -- the outer twigs (a pine's whorls are shallower than an oak's)
            local p = br.pts[#br.pts]
            local clump = { x = p.x, y = p.y, r = 260 + r:random() * 340, colour = leafy[r:random(1, #leafy)] }
            local nearHouse = p.y > -9000 and p.x > -6500 and p.x < 3400 -- (the houses, the limb, the swing)
            if not nearHouse and r:random() < 0.3 then
                look.leavesFront[#look.leavesFront + 1] = clump
            else
                look.leavesBack[#look.leavesBack + 1] = clump
            end
        end
    end
end

---------------------------------------------------------------- the whole place

-- the floors (the y a Mipo stands at) and where things go: three treehouses up the trunk
local L1, L2, L3 = -2600, -5200, -7800

local function build()
    rig.clearZones()
    rng = love.math.newRandomGenerator(77)
    look = { back = {}, mid = {}, front = {}, chutes = {} }

    -- the first floor: a house on the left (a ladder up through it), a balcony on the right with the big slide
    deck(-2400, 2000, L1)
    braces(-2400, 2000, L1, 0)
    house(-2300, -250, L1, 1150, -1500) -- (lower: at 1400 its ridge ran along the limb)
    railing(-150, 1900, L1)
    ladder(-2700, 0, L1 - 300)                  -- up from the grass
    ladder(-550, L1, L2 - 300)                  -- through the house, up to the second
    chute(curve(2050, L1 - 50, 7200, -150, 40, function(t) return 0.25 * t + 0.75 * t * t * (3 - 2 * t) end),
        CHUTE_COLOURS[1])

    -- the second: a balcony on the left, a house on the right
    deck(-250, 2900, L2)
    braces(-250, 2900, L2, 0)
    house(900, 2800, L2, 1300, 1900)
    railing(-150, 800, L2)
    endPost(2880, L2)
    ladder(100, L2, L3 - 300)                   -- up to the crow's nest

    -- the crow's nest: a little roofed lookout, the long way down by the limb
    deck(-2200, -200, L3)
    braces(-2200, -200, L3, 0)
    house(-1900, -500, L3, 1100, nil)
    railing(-2100, -300, L3, 260)
    chute(curve(-2250, L3 - 60, -4700, limbTop(-4700) - 90, 30, function(t) return 1 - (1 - t) ^ 2 end),
        CHUTE_COLOURS[2])

    -- the limb: walk along it, a swing under it, a slide off its end to the grass
    local limb = box((LIMB.x1 + LIMB.x2) / 2, (LIMB.y1 + LIMB.y2) / 2 + 60,
        math.abs(LIMB.x2 - LIMB.x1), 120, 'oak-limb', 0.9,
        math.atan2(LIMB.y2 - LIMB.y1, LIMB.x2 - LIMB.x1) - math.pi)
    oneWay(limb) -- (from the swing or the grass under it, up through the limb)
    if limb then swing(limb.body, -3700, limbTop(-3700) + 180, 1700) end
    -- (starting flush with the limb's top over its last stretch: a lip above it stopped a Mipo at the tip)
    chute(curve(LIMB.x2 + 300, limbTop(LIMB.x2 + 300) - 4, -9400, -160, 36,
        function(t) return t * t * (3 - 2 * t) end), CHUTE_COLOURS[3])
    st().built = true
end

local OAK_LABELS = { 'oak-roof', 'oak-deck', 'oak-post', 'oak-ladder', 'oak-ladder-rung', 'oak-chute', 'oak-swing-seat',
    'oak-limb' }

local CAM_SPOTS = { { -400, 1300, 0.14 }, { 1500, -900, 0.12 }, { 300, -4200, 0.1 }, { -2200, -7000, 0.11 } }
local function goTo(i)
    local spot = CAM_SPOTS[i]
    cam:setScale(spot[3])
    cam:setTranslation(spot[1], spot[2])
end

local function spawnMipos(c)
    c.mipos = mipoKit.alive(c.mipos)
    local spots = { { -3300, 1500 }, { -2600, 1500 }, { 2200, 1500 }, { 4600, -900 }, { 1200, L1 - 800 },
        { 300, L2 - 800 }, { -1200, L3 - 800 } }
    for i = #c.mipos + 1, #spots do mipoKit.spawn(c.mipos, spots[i][1], spots[i][2]) end
end

function s.onStart()
    worldState.paused = false
    local c = st()
    earth = loadEarth()
    if not c.panelFolded then -- the burrow's big panel folded at first: the den is behind it
        state.scriptPanels = state.scriptPanels or {}
        state.scriptPanels['•• burrow ••'] = true
        c.panelFolded = true
    end
    earth.onStart()
    -- a script reload starts again: what the last start made goes first (the drawn planks were module-local)
    rig.clearZones()
    for _, label in ipairs(OAK_LABELS) do
        for _, thing in ipairs(getObjectsByLabel(label)) do
            if thing.body and not thing.body:isDestroyed() then objectManager.destroyBody(thing.body) end
        end
    end
    build()
    growTree()
    spawnMipos(c)
    goTo(c.spot or 2)
end

function s.onUnload()
    earth.onUnload()
    rig.unload()
    barkLook.reset()
end

function s.onKeyPress(key)
    local c = st()
    local n = tonumber(key)
    if n and CAM_SPOTS[n] then
        c.spot = n
        goTo(n)
    elseif key == 'n' then
        local mx, my = mouseWorldPos()
        mipoKit.spawn(c.mipos, mx, my)
    elseif key == 'z' then c.showZones = not c.showZones
    elseif key == 'h' then c.showPanel = not c.showPanel
    else
        earth.onKeyPress(key)
    end
end

function s.update(dt)
    if not earth then return end
    earth.update(dt)
    rig.update(dt or 1 / 60)
end

---------------------------------------------------------------- drawing

local function viewRect()
    local x0, y0 = cam:getWorldCoordinates(0, 0)
    local x1, y1 = cam:getWorldCoordinates(love.graphics.getWidth(), love.graphics.getHeight())
    return x0, y0, x1, y1
end

-- the planks' fills and outlines, made once per layer
local layerMeshes = {}
local function plankMeshes(layer)
    if layerMeshes[layer] and layerMeshes[layer].list == look[layer] then return layerMeshes[layer] end
    local lines, grain = {}, {}
    for _, p in ipairs(look[layer]) do
        local pts = {}
        for i = 1, #p.verts, 2 do pts[#pts + 1] = { p.verts[i], p.verts[i + 1] } end
        lines[#lines + 1] = { pts = pts, loop = true, width = 26 }
        -- a grain line along the longer ones
        local len = math.sqrt((p.x2 - p.x1) ^ 2 + (p.y2 - p.y1) ^ 2)
        if len > p.thick * 3 and p.thick > 40 then
            local nx, ny = -(p.y2 - p.y1) / len, (p.x2 - p.x1) / len
            local o = p.thick * 0.18
            grain[#grain + 1] = { pts = { { p.x1 + nx * o + (p.x2 - p.x1) * 0.1, p.y1 + ny * o + (p.y2 - p.y1) * 0.1 },
                { p.x1 + nx * o + (p.x2 - p.x1) * 0.7, p.y1 + ny * o + (p.y2 - p.y1) * 0.7 } }, loop = false, width = 10 }
        end
    end
    layerMeshes[layer] = { list = look[layer], outline = STROKE.meshes(lines, 1.2, 0, true),
        grain = STROKE.meshes(grain, 0.8, 0, true) }
    return layerMeshes[layer]
end

local function drawPlanks(layer)
    if not look then return end
    for _, p in ipairs(look[layer]) do
        love.graphics.setColor(p.colour)
        love.graphics.polygon('fill', p.verts)
    end
    local m = plankMeshes(layer)
    love.graphics.setColor(1, 1, 1, 0.22)
    for _, mesh in ipairs(m.grain) do love.graphics.draw(mesh) end
    love.graphics.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], 1)
    for _, mesh in ipairs(m.outline) do love.graphics.draw(mesh) end
end

local chuteMeshes
local function drawChutes()
    if not look then return end
    for _, c in ipairs(look.chutes) do
        local pts = c.points
        for i = 1, #pts - 1 do
            local a, b = pts[i], pts[i + 1]
            love.graphics.setColor(c.colour)
            love.graphics.polygon('fill', a[1], a[2] - 30, b[1], b[2] - 30, b[1], b[2] + 50, a[1], a[2] + 50)
            love.graphics.setColor(c.colour[1] * 0.75, c.colour[2] * 0.75, c.colour[3] * 0.75, 1)
            love.graphics.polygon('fill', a[1], a[2] + 20, b[1], b[2] + 20, b[1], b[2] + 50, a[1], a[2] + 50)
        end
    end
    if not chuteMeshes or chuteMeshes.list ~= look.chutes then
        local lines = {}
        for _, c in ipairs(look.chutes) do
            local top, bottom = {}, {}
            for _, p in ipairs(c.points) do
                top[#top + 1] = { p[1], p[2] - 30 }
                bottom[#bottom + 1] = { p[1], p[2] + 50 }
            end
            lines[#lines + 1] = { pts = top, loop = false, width = 26 }
            lines[#lines + 1] = { pts = bottom, loop = false, width = 22 }
        end
        chuteMeshes = { list = look.chutes, meshes = STROKE.meshes(lines, 1.2, 0, true) }
    end
    love.graphics.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], 1)
    for _, mesh in ipairs(chuteMeshes.meshes) do love.graphics.draw(mesh) end
end

local function drawLeaves(list, alpha)
    for _, l in ipairs(list or {}) do
        love.graphics.setColor(l.colour[1] * 0.8, l.colour[2] * 0.8, l.colour[3] * 0.8, alpha)
        love.graphics.circle('fill', l.x + l.r * 0.08, l.y + l.r * 0.1, l.r)
        love.graphics.setColor(l.colour[1], l.colour[2], l.colour[3], alpha)
        love.graphics.circle('fill', l.x, l.y, l.r * 0.9)
    end
end

local SKY_TOP, SKY_LOW = { 0.62, 0.78, 0.88 }, { 0.93, 0.9, 0.78 }
local BARK_LIGHT = { lightPos = { -7000, -16000, 6000 }, lightColour = { 1.0, 0.95, 0.86 },
    ambient = { 0.42, 0.42, 0.46 }, detail = 1.1, look = 1, bands = 0, debugView = 0, barkWidth = 900 }

local function drawSky()
    local x0, y0, x1, y1 = viewRect()
    local mesh = love.graphics.newMesh({
        { x0, y0, 0, 0, SKY_TOP[1], SKY_TOP[2], SKY_TOP[3], 1 }, { x1, y0, 0, 0, SKY_TOP[1], SKY_TOP[2], SKY_TOP[3], 1 },
        { x1, y1, 0, 0, SKY_LOW[1], SKY_LOW[2], SKY_LOW[3], 1 }, { x0, y1, 0, 0, SKY_LOW[1], SKY_LOW[2], SKY_LOW[3], 1 },
    }, 'fan', 'stream')
    -- the colours by height in the world, not the screen: blue up high, warm by the grass
    local function at(y)
        local t = math.max(0, math.min(1, (y + 11000) / 11000))
        return SKY_TOP[1] + (SKY_LOW[1] - SKY_TOP[1]) * t, SKY_TOP[2] + (SKY_LOW[2] - SKY_TOP[2]) * t,
            SKY_TOP[3] + (SKY_LOW[3] - SKY_TOP[3]) * t
    end
    local r0, g0, b0 = at(y0)
    local r1, g1, b1 = at(y1)
    mesh:setVertexAttribute(1, 3, r0, g0, b0, 1)
    mesh:setVertexAttribute(2, 3, r0, g0, b0, 1)
    mesh:setVertexAttribute(3, 3, r1, g1, b1, 1)
    mesh:setVertexAttribute(4, 3, r1, g1, b1, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(mesh)
    mesh:release()
end

-- behind the Mipos: the sky, the oak and its leaves, the earth (the burrow's: it hides the trunk's foot), the
-- roots in it, the treehouses' walls, ladders and floors, the slides
-- a regrow takes a moment: while a slider moves, wait till it rests (the bark scene's way)
local function regrowIfChanged()
    local t = st().tree
    local key, now = treeKey(t), love.timer.getTime()
    if key ~= t.seen then t.seen, t.changedAt = key, now end
    if tree and tree.key ~= key and now - (t.changedAt or 0) > 0.2 and not love.mouse.isDown(1) then growTree() end
end

-- a whole new tree: another kind in one of its barks, another seed and age
local function anotherTree()
    local t = st().tree
    local kind = t.kind
    while kind == t.kind do kind = KIND_NAMES[love.math.random(#KIND_NAMES)] end
    local barks = KIND_BARKS[kind]
    t.kind, t.bark = kind, barkIndex(barks[love.math.random(#barks)])
    t.seed, t.age = love.math.random(1, 99999), 0.9 + love.math.random() * 0.5
end

function s.drawBelow()
    regrowIfChanged()
    drawSky()
    if tree then
        drawLeaves(look and look.leavesBack, 1)
        barkLook.begin(BARK_LIGHT)
        barkLook.drawTree(tree, { eyes = true, outlines = true })
    end
    earth.drawBelow()
    if roots then
        barkLook.begin(BARK_LIGHT)
        barkLook.drawTree(roots, { outlines = true })
    end
    drawPlanks('back')
    drawChutes()
    drawPlanks('mid')
    love.graphics.setColor(1, 1, 1, 1)
end

-- in front of the Mipos: railings, a few leaves, the grass blades in front, the swing's ropes, the zones
function s.draw()
    earth.draw()
    local sw = st().swing
    if sw and sw.seat and not sw.seat:isDestroyed() then
        love.graphics.setColor(0.55, 0.45, 0.3, 1)
        love.graphics.setLineWidth(34)
        for _, side in ipairs({ -1, 1 }) do
            local ex, ey = sw.seat:getWorldPoint(side * 140, -15)
            love.graphics.line(sw.pivot[1] + side * 140, sw.pivot[2], ex, ey)
        end
        love.graphics.setLineWidth(1)
        -- the seat (the burrow turns the plain body drawing off in play mode)
        local corners = {}
        for _, c in ipairs({ { -160, -22 }, { 160, -22 }, { 160, 22 }, { -160, 22 } }) do
            local wx, wy = sw.seat:getWorldPoint(c[1], c[2])
            corners[#corners + 1], corners[#corners + 2] = wx, wy
        end
        love.graphics.setColor(WOODS[3])
        love.graphics.polygon('fill', corners)
        love.graphics.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], 1)
        love.graphics.setLineWidth(14)
        love.graphics.polygon('line', corners)
        love.graphics.setLineWidth(1)
    end
    drawPlanks('front')
    drawLeaves(look and look.leavesFront, 0.92)
    love.graphics.setColor(1, 1, 1, 1)
    if st().showZones then rig.drawZones() end
end

---------------------------------------------------------------- the panel

function s.drawUI()
    -- once a frame, for both panels; in the editor its own UI has started it (a second start wipes the click)
    if state.playMode then ui.startFrame() end
    if earth then earth.drawUI() end -- the burrow's panel, bottom left (play mode)
    local c = st()
    oakPanelRect = nil
    if not c.showPanel then return end
    local sw = ui.getDimensions()
    local w, row, pad = 320, 34, 8
    local h = row * 11 + 64
    local x0, y0 = sw - w - 16, 16
    if not ui.isPanelFolded('•• oak tree ••') then oakPanelRect = { x0, y0, w, h } end
    ui.panel(x0, y0, w, h, '•• oak tree ••', function()
        local x, y = x0 + pad, y0 + 32
        local inner = w - pad * 2
        local names = { 'burrow', 'ground', 'houses', 'top' }
        local bw = (inner - 18) / 4
        for i, name in ipairs(names) do
            if ui.button(x + (i - 1) * (bw + 6), y, bw, i .. ' ' .. name, nil, c.spot == i and { 0.5, 0.4, 0.3 } or nil) then
                c.spot = i
                goTo(i)
            end
        end
        y = y + row + 4
        ui.label(x, y + 5, 'drag a Mipo:')
        y = y + row
        local current = rig.data().drag
        local dw = (inner - (#rig.DRAGS - 1) * 6) / #rig.DRAGS
        for i, name in ipairs(rig.DRAGS) do
            if ui.button(x + (i - 1) * (dw + 6), y, dw, name, nil, current == name and { 0.5, 0.4, 0.3 } or nil) then
                rig.setDrag(name)
            end
        end
        y = y + row + 4
        local zc, zv = ui.checkbox(x, y + 2, c.showZones, 'zones (z)')
        if zc then c.showZones = zv end
        if ui.button(x + inner / 2, y, inner / 2, 'a Mipo (n)') then
            local cx, cy = cam:getTranslation()
            mipoKit.spawn(c.mipos, cx, cy)
        end
        y = y + row + 12
        -- the tree: regrown under the treehouses (they stay where they are)
        local t = c.tree
        if ui.button(x, y, inner, 'another tree') then anotherTree() end
        y = y + row + 4
        local half = (inner - 6) / 2
        if ui.button(x, y, half, 'kind: ' .. t.kind) then
            local i = 1
            for k, name in ipairs(KIND_NAMES) do if name == t.kind then i = k end end
            t.kind = KIND_NAMES[i % #KIND_NAMES + 1]
        end
        if ui.button(x + half + 6, y, half, 'bark: ' .. (BARKS[t.bark] or BARKS[1]).name) then
            t.bark = t.bark % #BARKS + 1
        end
        y = y + row + 4
        for _, sl in ipairs({ { 'age', 0.3, 1.8, 0.05 }, { 'size', 0.6, 1.4, 0.05 }, { 'organic', 0, 2, 0.05 } }) do
            ui.label(x, y + 5, sl[1])
            local v = ui.sliderWithInput('oak-' .. sl[1], x + 80, y - 2, inner - 170, sl[2], sl[3], t[sl[1]], nil, sl[4])
            if v then t[sl[1]] = v + 0 end
            y = y + row
        end
        if ui.button(x, y, inner / 2 - 3, 'new seed') then t.seed = love.math.random(1, 99999) end
        ui.label(x + inner / 2 + 6, y + 5, 'seed ' .. t.seed)
        y = y + row + 4
        ui.label(x, y + 5, 'dig: drag on earth, shift fills   h')
    end)
end

return s

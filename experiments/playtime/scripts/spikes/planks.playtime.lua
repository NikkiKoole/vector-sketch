-- planks: a spike for a treehouse nailed together from planks, each plank a body with a drawn outline (Nikki's crayon strokes)
-- The planked-together dwelling look: every plank is its own body, a little crooked, with its
-- ends cut a bit skew, outlined with the drawn strokes from textures/strokes (the burrow rim's
-- stroke: the pictures repeat along each side, broken at the corners, overshooting and tapering).
-- The grain is drawn with the same strokes, thin and pale, a knot now and then. Planks overlap
-- and are nailed where they do (a weld, and a nail head drawn there); pull a plank hard and the
-- nails pop, and it falls off.
--
-- Layers: the leaves and the trunk at the back, then the back wall (planks the Mipos stand in
-- front of, not on), the floor, posts and roof (solid), the Mipos, then the porch railing and a
-- few leaves in front.
--
-- play mode (tab): drag planks and Mipos about.
-- keys: r build it again   m a Mipo   o drawn outline / plain line   b boil   h the panel
--       s seamless (one stroke picture per side, repeated mirror-wise) / mixed (a picture per repeat)

local s = {}

local OUTLINE = { 0.2, 0.13, 0.1 }
local WOODS = {
    { 0.74, 0.56, 0.38 }, { 0.66, 0.48, 0.33 }, { 0.8, 0.64, 0.45 }, { 0.6, 0.45, 0.34 },
    { 0.7, 0.6, 0.48 }, { 0.56, 0.4, 0.28 },
}
local PAINTED = { -- an odd plank from somewhere else, the paint faded
    { 0.5, 0.63, 0.7 }, { 0.74, 0.42, 0.36 }, { 0.55, 0.65, 0.45 }, { 0.88, 0.82, 0.66 },
}
local LEAVES = { { 0.36, 0.56, 0.3 }, { 0.42, 0.62, 0.32 }, { 0.3, 0.48, 0.28 }, { 0.48, 0.66, 0.36 } }
local BARK = { 0.45, 0.32, 0.24 }
local GROUP = -77 -- the planks don't push each other; they're held by their nails

local function planks()
    state.planks = state.planks or {
        planks = {}, welds = {}, statics = {}, mipos = {}, showPanel = true,
        settings = { drawn = true, boil = false, seamless = true, width = 9, wobble = 1.2, grain = 1, nails = 6 },
    }
    if state.planks.settings.seamless == nil then state.planks.settings.seamless = true end
    return state.planks
end

local function rnd(a, b) return a + love.math.random() * (b - a) end
local function pick(list) return list[love.math.random(#list)] end

---------------------------------------------------------------- the drawn stroke

-- Nikki's crayon strokes (src/drawn-stroke.lua; this file had the same code, the module was copied from it)
local STROKE = drawnStroke()
local STROKES, strokeMeshes = STROKE.strokes, STROKE.meshes

---------------------------------------------------------------- a plank's look

-- the look in the plank's own frame, shifted by its seed so its strokes are its own
local function makeLook(p)
    local ox, oy = p.seed * 997 % 20000, p.seed * 613 % 20000
    p.sox, p.soy = ox, oy
    local pts = {}
    for i = 1, #p.verts, 2 do pts[#pts + 1] = { p.verts[i] + ox, p.verts[i + 1] + oy } end
    p.outlinePts = pts
    -- grain: a few long thin lines along the plank, a knot now and then
    local grain = {}
    if p.kind == 'plank' then
        local L, H = p.len, p.thick
        local along = p.alongY
        local function at(u, v) -- u along the length (-0.5..0.5), v across
            if along then return { v * H + ox, u * L + oy } end
            return { u * L + ox, v * H + oy }
        end
        local n = math.max(1, math.floor(H / 30))
        for i = 1, n do
            local v = rnd(-0.32, 0.32)
            local u0, u1 = rnd(-0.45, -0.1), rnd(0.1, 0.45)
            local line = {}
            for k = 0, 6 do
                local u = u0 + (u1 - u0) * k / 6
                line[#line + 1] = at(u, v + math.sin(u * 7 + i) * 0.04)
            end
            grain[#grain + 1] = { pts = line, loop = false, width = 5, wobble = 0.6 }
        end
        if love.math.random() < 0.35 and L > 200 then
            local u, v = rnd(-0.35, 0.35), rnd(-0.15, 0.15)
            local c = at(u, v)
            local rx, ry = 12 + love.math.random() * 10, 6 + love.math.random() * 4
            if along then rx, ry = ry, rx end
            local knot = {}
            for k = 0, 9 do
                local a = k / 10 * math.pi * 2
                knot[#knot + 1] = { c[1] + math.cos(a) * rx, c[2] + math.sin(a) * ry }
            end
            grain[#grain + 1] = { pts = knot, loop = true, width = 5, wobble = 0.3 }
        end
    end
    p.grainLines = grain
    p.meshKey = nil
end

local function plankMeshes(b, p, step)
    local set = b.settings
    local key = table.concat({ set.width, set.wobble, step, tostring(set.seamless) }, ',')
    if p.meshKey ~= key then
        local width = set.width * (p.lineScale or 1)
        p.outlineMeshes = strokeMeshes({ { pts = p.outlinePts, loop = true, width = width } }, set.wobble, step, set.seamless)
        p.grainMeshes = strokeMeshes(p.grainLines, set.wobble, step, set.seamless)
        p.meshKey = key
    end
    return p.outlineMeshes, p.grainMeshes
end

---------------------------------------------------------------- building

local function alive(list)
    local out = {}
    for _, t in ipairs(list) do
        if t.body and not t.body:isDestroyed() then out[#out + 1] = t end
    end
    return out
end

local function aliveMipos(b) return mipoKit.alive(b.mipos) end -- src/mipo-kit.lua

-- a plank from (x1, y1) to (x2, y2), thick wide: a crooked rectangle with its ends cut a bit skew
-- opts: layer ('back' 'mid' 'front'), solid (collides with the Mipos), static, color
local function plank(b, x1, y1, x2, y2, thick, opts)
    opts = opts or {}
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    local angle = math.atan2(dy, dx) + rnd(-0.015, 0.015)
    local cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
    local hl, ht = len / 2, thick / 2
    local skew = thick * 0.25
    local verts = {
        -hl + rnd(-skew, skew), -ht + rnd(-2, 2),
        hl + rnd(-skew, skew), -ht + rnd(-2, 2),
        hl + rnd(-skew, skew), ht + rnd(-2, 2),
        -hl + rnd(-skew, skew), ht + rnd(-2, 2),
    }
    local cxl, cyl = mathutils.computeCentroid(verts)
    for i = 1, #verts, 2 do verts[i] = verts[i] - cxl; verts[i + 1] = verts[i + 1] - cyl end
    local thing = objectManager.addThing('custom', { x = cx, y = cy, vertices = verts,
        bodyType = opts.static and 'static' or 'dynamic', label = 'plank', density = 0.6 })
    if not thing then return end
    thing.body:setAngle(angle)
    for _, fixture in ipairs(thing.body:getFixtures()) do
        fixture:setFriction(0.7)
        fixture:setRestitution(0.05)
        if not opts.static then fixture:setGroupIndex(GROUP) end
        if not opts.solid then fixture:setSensor(true) end
    end
    local color = opts.color or (love.math.random() < 0.12 and pick(PAINTED) or pick(WOODS))
    local j = rnd(0.94, 1.04)
    local p = { body = thing.body, verts = verts, len = len, thick = thick, alongY = false,
        layer = opts.layer or 'mid', color = { color[1] * j, color[2] * j, color[3] * j },
        shade = opts.layer == 'back' and 0.78 or 1, seed = love.math.random() * 1000,
        kind = opts.kind or 'plank', lineScale = opts.lineScale, solid = opts.solid }
    makeLook(p)
    b.planks[#b.planks + 1] = p
    return p
end

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

local function worldPoly(p)
    local out = {}
    for i = 1, #p.verts, 2 do
        local x, y = p.body:getWorldPoint(p.verts[i], p.verts[i + 1])
        out[#out + 1] = x; out[#out + 1] = y
    end
    return out
end

-- nail every two planks that overlap, where they overlap (and the house to the tree)
local function nailAll(b)
    local polys = {}
    for i, p in ipairs(b.planks) do polys[i] = worldPoly(p) end
    for i = 1, #b.planks do
        for j = i + 1, #b.planks do
            local pa, pb = b.planks[i], b.planks[j]
            local bothStatic = pa.body:getType() == 'static' and pb.body:getType() == 'static'
            if not bothStatic and pa.kind ~= 'leaves' and pb.kind ~= 'leaves' then
                -- sample a grid over the thinner one, keep the points inside the other
                -- (a tree or the ground has no length: the plank is the one sampled)
                local thin, otherPoly = pa, polys[j]
                local aPlank, bPlank = pa.kind == 'plank', pb.kind == 'plank'
                if (bPlank and not aPlank) or (aPlank and bPlank and pb.thick * pb.len < pa.thick * pa.len) then
                    thin, otherPoly = pb, polys[i]
                end
                local sx, sy, n = 0, 0, 0
                local nu = math.max(2, math.ceil(thin.len / 20))
                for iu = 0, nu do
                    local u = -0.48 + 0.96 * iu / nu
                    for v = -0.4, 0.41, 0.4 do
                        local x, y = thin.body:getWorldPoint(u * thin.len, v * thin.thick)
                        if pointInPoly(x, y, otherPoly) then sx, sy, n = sx + x, sy + y, n + 1 end
                    end
                end
                if n > 0 then
                    local x, y = sx / n, sy / n
                    local joint = love.physics.newWeldJoint(pa.body, pb.body, x, y, false)
                    local id = 'plank-weld-' .. tostring(#b.welds + 1) .. '-' .. tostring(love.math.random(1e6))
                    joint:setUserData({ id = id, label = 'nail' })
                    registry.registerJoint(id, joint)
                    -- the nail head goes on whichever is drawn on top
                    local top = (pa.layer == 'back' and pb) or (pb.layer == 'back' and pa) or (i > j and pa or pb)
                    local lx, ly = top.body:getLocalPoint(x, y)
                    b.welds[#b.welds + 1] = { joint = joint, a = pa, b = pb, top = top, lx = lx, ly = ly }
                end
            end
        end
    end
end

local function staticPoly(b, points, color, opts)
    local cx, cy = mathutils.computeCentroid(points)
    local rel = {}
    for i = 1, #points, 2 do rel[#rel + 1] = points[i] - cx; rel[#rel + 1] = points[i + 1] - cy end
    local thing = objectManager.addThing('custom', { x = cx, y = cy, vertices = rel, bodyType = 'static', label = 'plank-tree' })
    if not thing then return end
    for _, fixture in ipairs(thing.body:getFixtures()) do
        fixture:setFriction(0.8)
        if opts and opts.sensor then fixture:setSensor(true) end
    end
    local p = { body = thing.body, verts = rel, len = 0, thick = 0, layer = opts and opts.layer or 'tree', color = color,
        shade = 1, seed = love.math.random() * 1000, kind = opts and opts.kind or 'tree', lineScale = opts and opts.lineScale }
    makeLook(p)
    b.planks[#b.planks + 1] = p
    return p
end

-- a blob of leaves: a lumpy circle
local function leaves(b, x, y, r, layer)
    local pts = {}
    local n = 16
    for i = 0, n - 1 do
        local a = i / n * math.pi * 2
        local rr = r * (0.85 + love.math.random() * 0.25)
        pts[#pts + 1] = x + math.cos(a) * rr; pts[#pts + 1] = y + math.sin(a) * rr
    end
    return staticPoly(b, pts, pick(LEAVES), { sensor = true, layer = layer, kind = 'leaves', lineScale = 1.2 })
end

local GROUND_TOP = 0

local function build(b)
    for _, w in ipairs(b.welds) do
        if w.joint and not w.joint:isDestroyed() then
            local ud = w.joint:getUserData()
            if ud and ud.id then registry.unregisterJoint(ud.id) end
            w.joint:destroy()
        end
    end
    for _, p in ipairs(alive(b.planks)) do objectManager.destroyBody(p.body) end
    b.planks, b.welds = {}, {}

    -- the ground
    staticPoly(b, { -3000, GROUND_TOP, 3000, GROUND_TOP, 3000, 300, -3000, 300 }, { 0.5, 0.64, 0.36 }, { layer = 'tree', kind = 'ground' })
    -- leaves at the back
    for _, l in ipairs({ { -700, -2300, 520 }, { 400, -2500, 600 }, { -100, -2800, 480 }, { 900, -2000, 420 },
        { -1100, -1900, 380 } }) do
        leaves(b, l[1], l[2], l[3], 'leavesBack')
    end
    -- the tree: a trunk, a little crooked, and two branches
    local trunk = {}
    local segs = 7
    for i = 0, segs do
        local t = i / segs
        trunk[#trunk + 1] = 150 - 50 * t + rnd(-8, 8) + math.sin(t * 3) * 20
        trunk[#trunk + 1] = GROUND_TOP - t * 2500
    end
    for i = segs, 0, -1 do
        local t = i / segs
        trunk[#trunk + 1] = -150 + 50 * t + rnd(-8, 8) + math.sin(t * 3) * 20
        trunk[#trunk + 1] = GROUND_TOP - t * 2500
    end
    staticPoly(b, trunk, BARK, { layer = 'tree', lineScale = 1.3 })
    staticPoly(b, { 60, -2050, 700, -2350, 720, -2290, 80, -1950 }, BARK, { layer = 'tree', sensor = true })
    staticPoly(b, { -60, -2150, -620, -2500, -650, -2440, -70, -2050 }, BARK, { layer = 'tree', sensor = true })

    local floorY = -1000
    -- the floor: three planks end to end, a beam under them, braces down to the trunk
    plank(b, -720, floorY, -60, floorY + 4, 64, { solid = true })
    plank(b, -180, floorY - 2, 460, floorY, 64, { solid = true })
    plank(b, 360, floorY + 3, 980, floorY - 3, 64, { solid = true })
    plank(b, -640, floorY + 50, 640, floorY + 54, 56, { solid = false })
    plank(b, -110, -560, -560, floorY + 40, 52, { layer = 'back' })
    plank(b, 110, -540, 560, floorY + 44, 52, { layer = 'back' })
    -- the back wall: upright planks, side by side, a window gap
    local x = -640
    local i = 0
    while x < 600 do
        local w = rnd(92, 118)
        local mid = x + w / 2
        local top = -2015 + math.abs(mid) * (495 / 830) + 50 + rnd(-15, 15) -- just under the roof
        i = i + 1
        if i == 3 or i == 4 then
            plank(b, mid, floorY - 20, mid, -1250, w, { layer = 'back' })
            plank(b, mid, -1500, mid, top, w, { layer = 'back' })
        else
            plank(b, mid, floorY - 20, mid, top, w, { layer = 'back' })
        end
        x = x + w + rnd(-4, 10)
    end
    -- the window frame (on top of the wall)
    local wx0, wx1 = -640 + 2 * 100, -640 + 4 * 105
    plank(b, wx0 - 30, -1250, wx1 + 30, -1252, 36, { layer = 'back' })
    plank(b, wx0 - 30, -1500, wx1 + 30, -1497, 36, { layer = 'back' })
    plank(b, wx0 + 5, -1230, wx0 + 3, -1520, 30, { layer = 'back' })
    plank(b, wx1 - 5, -1230, wx1 - 3, -1520, 30, { layer = 'back' })
    plank(b, (wx0 + wx1) / 2, -1240, (wx0 + wx1) / 2 + 3, -1510, 24, { layer = 'back' })
    -- corner posts: solid, so a Mipo stays in
    plank(b, -640, floorY + 30, -650, -1500, 60, { solid = true })
    plank(b, 600, floorY + 30, 606, -1530, 60, { solid = true })
    -- the roof: two planks a side, end to end down the slope, and a ridge cap
    for side = -1, 1, 2 do
        plank(b, side * 830, -1520, side * 360, -1800 + rnd(-6, 6), 70, { solid = true })
        plank(b, side * 410, -1775, side * -15, -2015, 66, { solid = true })
    end
    plank(b, -90, -2025, 90, -2028, 40, { solid = true })
    -- the porch railing, in front of the Mipos
    plank(b, 760, floorY - 20, 762, -1290, 40, { layer = 'front' })
    plank(b, 950, floorY - 20, 948, -1280, 40, { layer = 'front' })
    plank(b, 700, -1260, 1000, -1268, 34, { layer = 'front' })
    plank(b, 700, -1130, 1000, -1135, 28, { layer = 'front' })
    -- a ladder down to the ground
    plank(b, -900, GROUND_TOP + 10, -780, floorY - 30, 30, { layer = 'back' })
    plank(b, -1060, GROUND_TOP + 10, -940, floorY - 30, 30, { layer = 'back' })
    for r = 1, 6 do
        local t = r / 7
        local y = GROUND_TOP + (floorY - GROUND_TOP) * t
        local xl, xr = -1060 + 120 * t, -900 + 120 * t
        plank(b, xl - 30, y, xr + 30, y + rnd(-6, 6), 30, { layer = 'back' })
    end
    -- leaves in front, a few
    leaves(b, 1150, -1650, 300, 'leavesFront')
    leaves(b, -950, -1700, 260, 'leavesFront')
    nailAll(b)
end

local function spawnMipo(b, x, y) mipoKit.spawn(b.mipos, x, y) end -- src/mipo-kit.lua

---------------------------------------------------------------- hooks

function s.onStart()
    worldState.paused = false
    local b = planks()
    b.planks = alive(b.planks)
    if #b.planks == 0 then build(b) end
    b.mipos = aliveMipos(b)
    if #b.mipos == 0 then
        spawnMipo(b, -200, -1500)
        spawnMipo(b, -1500, -500)
    end
end

function s.onUnload()
    local b = state.planks
    if b and b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local b = planks()
    local mx, my = mouseWorldPos()
    if key == 'r' then build(b)
    elseif key == 'm' then spawnMipo(b, mx, my)
    elseif key == 'o' then b.settings.drawn = not b.settings.drawn
    elseif key == 'b' then b.settings.boil = not b.settings.boil
    elseif key == 's' then b.settings.seamless = not b.settings.seamless
    elseif key == 'h' then b.showPanel = not b.showPanel
    end
end

-- a plank that's lost its nails falls free: it collides with the others again
local function loosen(p)
    for _, fixture in ipairs(p.body:getFixtures()) do fixture:setGroupIndex(0) end
    p.loose = true
end

local function pull(w)
    local ud = w.joint:getUserData()
    if ud and ud.id then registry.unregisterJoint(ud.id) end
    w.joint:destroy()
end

-- Nails pop only on a plank that's being dragged, and only when it's pulled hard: how hard is the
-- drag's own force against the plank's weight (a nail at rest can carry the whole house, so its
-- own force says nothing). One nail at a time, the most loaded first, so a plank tears off.
function s.update(dt)
    local b = state.planks
    if not b or dt <= 0 then return end
    local limit = b.settings.nails
    if limit >= 30 then return end -- the far end of the slider: nails never pop
    local now = love.timer.getTime()
    local gx, gy = state.physicsWorld:getGravity()
    local g = math.sqrt(gx * gx + gy * gy)
    local alive = {}
    for _, w in ipairs(b.welds) do
        if w.joint and not w.joint:isDestroyed() then alive[#alive + 1] = w end
    end
    b.welds = alive
    local popped = false
    for _, p in ipairs(b.planks) do
        local mj = p.body:getType() == 'dynamic' and getPJAttachedTo(p.body)
        if mj and mj.joint and not mj.joint:isDestroyed() and now >= (p.nextPop or 0) then
            local fx, fy = mj.joint:getReactionForce(1 / dt)
            if math.sqrt(fx * fx + fy * fy) > p.body:getMass() * g * limit then
                local worst, worstF
                for _, w in ipairs(b.welds) do
                    if w.a == p or w.b == p then
                        local wx, wy = w.joint:getReactionForce(1 / dt)
                        local f = wx * wx + wy * wy
                        if not worstF or f > worstF then worst, worstF = w, f end
                    end
                end
                if worst then
                    pull(worst)
                    worst.gone = true
                    popped = true
                    p.nextPop = now + 0.15
                end
            end
        end
    end
    if popped then
        local kept, held = {}, {}
        for _, w in ipairs(b.welds) do
            if not w.gone then kept[#kept + 1] = w; held[w.a] = true; held[w.b] = true end
        end
        b.welds = kept
        for _, p in ipairs(b.planks) do
            if not held[p] and not p.loose and p.body:getType() == 'dynamic' then loosen(p) end
        end
    end
end

---------------------------------------------------------------- drawing

local function drawPlank(b, p, step)
    local x, y = p.body:getPosition()
    local a = p.body:getAngle()
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(a)
    local c, k = p.color, p.shade
    love.graphics.setColor(c[1] * k, c[2] * k, c[3] * k)
    love.graphics.polygon('fill', p.verts)
    love.graphics.translate(-p.sox, -p.soy)
    if b.settings.drawn and #STROKES > 0 then
        local outline, grain = plankMeshes(b, p, step)
        if b.settings.grain > 0 then
            love.graphics.setColor(c[1] * k * 0.6, c[2] * k * 0.55, c[3] * k * 0.5, 0.55 * b.settings.grain)
            for _, mesh in ipairs(grain) do love.graphics.draw(mesh) end
        end
        love.graphics.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], 1)
        for _, mesh in ipairs(outline) do love.graphics.draw(mesh) end
    else
        love.graphics.translate(p.sox, p.soy)
        love.graphics.setColor(OUTLINE)
        love.graphics.setLineWidth(3)
        love.graphics.polygon('line', p.verts)
    end
    love.graphics.pop()
end

local function drawNails(b, layer)
    for _, w in ipairs(b.welds) do
        if w.top.layer == layer and w.joint and not w.joint:isDestroyed() then
            local x, y = w.top.body:getWorldPoint(w.lx, w.ly)
            love.graphics.setColor(0.25, 0.24, 0.26)
            love.graphics.circle('fill', x, y, 7)
            love.graphics.setColor(0.6, 0.6, 0.62)
            love.graphics.circle('fill', x - 2, y - 2, 3)
        end
    end
end

local BEHIND = { 'leavesBack', 'tree', 'back', 'mid' }
local INFRONT = { 'front', 'leavesFront' }

local function drawLayers(b, layers)
    local step = b.settings.boil and math.floor(love.timer.getTime() * 10) % 3 or 0
    for _, layer in ipairs(layers) do
        for _, p in ipairs(b.planks) do
            if p.layer == layer then drawPlank(b, p, step) end
        end
        if layer ~= 'leavesBack' and layer ~= 'leavesFront' and layer ~= 'tree' then drawNails(b, layer) end
    end
end

function s.drawBelow()
    local b = state.planks
    if not b then return end
    b.planks = alive(b.planks)
    -- the sky
    love.graphics.push()
    love.graphics.origin()
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(0.8, 0.88, 0.9)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.pop()
    drawLayers(b, BEHIND)
    if state.playMode then
        b.savedDrawBodies = state.world.debugDrawBodies
        state.world.debugDrawBodies = false
    end
    b.drawing = true
end

function s.draw()
    local b = state.planks
    if not (b and b.drawing) then return end
    b.drawing = nil
    if b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
    drawLayers(b, INFRONT)
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local b = state.planks
    if not (b and state.playMode and b.showPanel) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 400
    local rows = { { 'width', 2, 40, 1 }, { 'wobble', 0, 4, 0.01 }, { 'grain', 0, 1.5, 0.01 }, { 'nails', 1, 30, 0.1 } }
    local h = (BH + pad) * (#rows + 2) + pad + 24
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• planks ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        for _, row in ipairs(rows) do
            local key = row[1]
            local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('planks' .. key, x, y, 180, row[2], row[3], b.settings[key], nil, row[4])
            if v then b.settings[key] = v + 0 end
            ui.label(x + 280, y, key == 'nails' and 'nails (30: never pop)' or key)
        end
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, (b.settings.drawn and 'drawn' or 'plain') .. ' outline (o)  boil ' ..
            (b.settings.boil and 'on' or 'off') .. ' (b)  ' ..
            (b.settings.seamless and 'seamless' or 'mixed pictures') .. ' (s)')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'r build again  m Mipo  h panel')
    end)
end

return s

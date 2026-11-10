-- depth: a spike for depth layers (back / play / front), blocks drawn with depth, and Mipos in two lanes
-- DEPTH-LAYERS.md tried: a toy house of chunky blocks, each one drawn as a box (its sides and top
-- going back to a vanishing point near the top of the screen, so the house turns as the camera
-- moves; or oblique, a fixed slant). Every block has a layer:
--   back   the house's walls, floor and roof: Mipos walk in front of them; their tops are
--          one-way floors (set a Mipo on the floor between the storeys, or on the roof)
--   play   solid: the porch floor, crates
--   front  drawn over the Mipos, no collision with them: porch pillars and roof, the railing, the fence
-- Mipos get depth too: a soft contact shadow on whatever is under them, and two lanes. A Mipo in
-- the back lane walks on the path behind the house: drawn behind it, hazy, colliding only with
-- the path and the other back Mipos. The world's draw is split between the lanes
-- (state.drawSplits in src/physics/box2d-draw-textured.lua), the house drawn in between.
--
-- play mode (tab): drag Mipos and blocks about.
-- keys: l the Mipo under the mouse to the other lane   m a Mipo   n a Mipo in the back lane
--       k knock the house loose (static -> dynamic)   r build again   v perspective / oblique
--       o drawn / plain outline   s shadows   h the panel
-- Mipo bodies (sliders): mipo depth (its own, apart from the house's depth), a cut-out's edge going back (copies of the lane shrunk toward the
-- vanishing point, darker); round, a light edge toward the light and a shaded one away (a shader)

local s = {}

local STROKE = drawnStroke()

local OUTLINE = { 0.2, 0.14, 0.12 }
local SKY_TOP, SKY_LOW = { 0.62, 0.78, 0.9 }, { 0.9, 0.92, 0.86 }
local LIGHT_X, LIGHT_Y = -0.37, -0.93 -- light from the upper left: tops bright, right sides dark
local PATH_TOP = -130                 -- the back lane's floor
local SPLIT_Z = 450 * 1000            -- back lane Mipos draw below this z, front lane ones above
local FRONT_GROUP = 500               -- a front lane Mipo's z group: FRONT_GROUP + its number
local WORLD_W = 15000                 -- the ground reaches this far either way; a Mipo thrown off comes back

local function depthState()
    state.depthSpike = state.depthSpike or {
        blocks = {}, welds = {}, decor = {}, mipos = {}, lanes = {}, numbers = {}, nextNumber = 1,
        roles = {}, passing = {}, showPanel = true,
        settings = { depth = 1, persp = 0.0011, horizon = 0.22, haze = 0.3, width = 9,
            oblique = false, drawn = true, shadows = true },
    }
    return state.depthSpike
end

local function rnd(a, b) return a + love.math.random() * (b - a) end

local SHADOW
do
    local d = love.image.newImageData(64, 64)
    d:mapPixel(function(x, y)
        local dx, dy = (x - 31.5) / 32, (y - 31.5) / 32
        local a = math.max(0, 1 - math.sqrt(dx * dx + dy * dy))
        return 1, 1, 1, a * a * (3 - 2 * a)
    end)
    SHADOW = love.graphics.newImage(d)
end

---------------------------------------------------------------- the view

-- where a point depth units behind (x, y) is drawn: toward the vanishing point, or slanted
local function projector(b)
    local set = b.settings
    if set.oblique then
        return function(x, y, depth)
            local d = depth * set.depth
            return x + d * 0.42, y - d * 0.55
        end
    end
    local w, h = love.graphics.getDimensions()
    local vx, vy = cam:getWorldCoordinates(w / 2, h * set.horizon)
    local k = set.persp
    return function(x, y, depth)
        local sc = 1 / (1 + depth * set.depth * k)
        return vx + (x - vx) * sc, vy + (y - vy) * sc
    end
end

---------------------------------------------------------------- blocks

-- signed area, to keep every outline the same way round (the side normals point out)
local function clockwise(verts)
    local area = 0
    local n = #verts / 2
    for i = 1, n do
        local j = i % n + 1
        area = area + verts[i * 2 - 1] * verts[j * 2] - verts[j * 2 - 1] * verts[i * 2]
    end
    if area < 0 then
        local out = {}
        for i = n, 1, -1 do out[#out + 1] = verts[i * 2 - 1]; out[#out + 1] = verts[i * 2] end
        return out
    end
    return verts
end

local function makeLines(p)
    local ox, oy = p.seed * 997 % 20000, p.seed * 613 % 20000
    p.sox, p.soy = ox, oy
    local lines = {}
    local pts = {}
    for i = 1, #p.verts, 2 do pts[#pts + 1] = { p.verts[i] + ox, p.verts[i + 1] + oy } end
    lines[1] = { pts = pts, loop = true, width = 1 }
    local function rect(r, width)
        lines[#lines + 1] = { pts = { { r[1] + ox, r[2] + oy }, { r[1] + r[3] + ox, r[2] + oy },
            { r[1] + r[3] + ox, r[2] + r[4] + oy }, { r[1] + ox, r[2] + r[4] + oy } }, loop = true, width = width }
    end
    for _, r in ipairs(p.windows or {}) do rect(r, 0.75) end
    if p.door then rect(p.door, 0.75) end
    p.lines = lines
    p.meshKey = nil
end

-- a block from a list of world points (convex), or opts.rect = { x, y, w, h }
local function block(b, points, opts)
    local cx, cy = mathutils.computeCentroid(points)
    local verts = {}
    for i = 1, #points, 2 do verts[#verts + 1] = points[i] - cx; verts[#verts + 1] = points[i + 1] - cy end
    verts = clockwise(verts)
    local dynamic = opts.dynamic
    local thing = objectManager.addThing('custom', { x = cx, y = cy, vertices = verts,
        bodyType = dynamic and 'dynamic' or 'static', label = 'depth-' .. opts.layer, density = opts.density or 0.8 })
    if not thing then return end
    for _, fixture in ipairs(thing.body:getFixtures()) do
        fixture:setFriction(0.9)
        fixture:setRestitution(0.05)
    end
    local function rel(r) return r and { r[1] - cx, r[2] - cy, r[3], r[4] } end
    local windows
    if opts.windows then
        windows = {}
        for i, r in ipairs(opts.windows) do windows[i] = rel(r) end
    end
    local top = math.huge
    for i = 2, #verts, 2 do top = math.min(top, verts[i]) end
    local p = { body = thing.body, verts = verts, layer = opts.layer, depth = opts.depth or 150,
        color = opts.color, oneWay = opts.oneWay, windows = windows, door = rel(opts.door),
        doorColor = opts.doorColor, seed = love.math.random() * 1000, lineScale = opts.lineScale or 1, top = top }
    makeLines(p)
    b.blocks[#b.blocks + 1] = p
    return p
end

local function rectBlock(b, x, y, w, h, opts)
    return block(b, { x, y, x + w, y, x + w, y + h, x, y + h }, opts)
end

local function weld(b, pa, pb)
    if not (pa and pb) then return end
    local x1, y1 = pa.body:getPosition()
    local x2, y2 = pb.body:getPosition()
    local joint = love.physics.newWeldJoint(pa.body, pb.body, (x1 + x2) / 2, (y1 + y2) / 2, false)
    local id = 'depth-weld-' .. tostring(#b.welds + 1) .. '-' .. tostring(love.math.random(1e6))
    joint:setUserData({ id = id, label = 'depth-weld' })
    registry.registerJoint(id, joint)
    b.welds[#b.welds + 1] = joint
end

-- the top of a block at local x: the highest point of its outline straight above or below x
local function topAt(p, lx)
    local best
    local v = p.verts
    local n = #v / 2
    for i = 1, n do
        local j = i % n + 1
        local x1, y1, x2, y2 = v[i * 2 - 1], v[i * 2], v[j * 2 - 1], v[j * 2]
        if (lx >= x1 and lx <= x2) or (lx >= x2 and lx <= x1) then
            local y = (x1 == x2) and math.min(y1, y2) or y1 + (y2 - y1) * (lx - x1) / (x2 - x1)
            if not best or y < best then best = y end
        end
    end
    return best or p.top
end

---------------------------------------------------------------- decor (no bodies)

local function blob(x, y, r, n, squash)
    local pts = {}
    for i = 0, n - 1 do
        local a = i / n * math.pi * 2
        local rr = r * (0.86 + love.math.random() * 0.22)
        pts[#pts + 1] = x + math.cos(a) * rr
        pts[#pts + 1] = y + math.sin(a) * rr * (squash or 1)
    end
    return pts
end

local function decor(b, layer, points, color, depth)
    local seed = love.math.random() * 1000
    local ox, oy = seed * 997 % 20000, seed * 613 % 20000
    local pts = {}
    for i = 1, #points, 2 do pts[#pts + 1] = { points[i] + ox, points[i + 1] + oy } end
    local d = { layer = layer, points = points, color = color, depth = depth or 60, ox = ox, oy = oy,
        lines = { { pts = pts, loop = true, width = 1.1 } } }
    b.decor[#b.decor + 1] = d
    return d
end

---------------------------------------------------------------- building

local CREAM = { 0.94, 0.87, 0.68 }
local BLUE = { 0.66, 0.78, 0.86 }
local ROOF = { 0.8, 0.36, 0.28 }
local WOOD = { 0.72, 0.53, 0.36 }
local WHITE = { 0.95, 0.93, 0.87 }
local GREENS = { { 0.36, 0.56, 0.3 }, { 0.42, 0.62, 0.32 }, { 0.32, 0.5, 0.3 } }

local function destroyAll(b)
    for _, joint in ipairs(b.welds) do
        if not joint:isDestroyed() then
            local ud = joint:getUserData()
            if ud and ud.id then registry.unregisterJoint(ud.id) end
            joint:destroy()
        end
    end
    for _, p in ipairs(b.blocks) do
        if p.body and not p.body:isDestroyed() then objectManager.destroyBody(p.body) end
    end
    for _, body in ipairs(b.grounds or {}) do
        if not body:isDestroyed() then objectManager.destroyBody(body) end
    end
    b.blocks, b.welds, b.decor, b.grounds, b.passing = {}, {}, {}, {}, {}
end

local function ground(b, x, y, w, h, role)
    local thing = objectManager.addThing('custom', { x = x + w / 2, y = y + h / 2, bodyType = 'static', label = 'depth-' .. role,
        vertices = { -w / 2, -h / 2, w / 2, -h / 2, w / 2, h / 2, -w / 2, h / 2 } })
    if not thing then return end
    for _, fixture in ipairs(thing.body:getFixtures()) do fixture:setFriction(0.9) end
    b.grounds[#b.grounds + 1] = thing.body
    b.groundRoles = b.groundRoles or {}
    b.groundRoles[thing.body] = role
end

local function tint(c, k) return { c[1] * k, c[2] * k, c[3] * k } end

local function build(b)
    destroyAll(b)
    b.groundRoles = {}
    ground(b, -WORLD_W, 0, WORLD_W * 2, 600, 'ground')
    ground(b, -WORLD_W, PATH_TOP, WORLD_W * 2, 30, 'path')

    -- the house: two storeys of wall blocks, a floor between them, a roof
    local W, x0 = 260, -1300
    local lower = { 'wall', 'window', 'door', 'window', 'wall' }
    for i, kind in ipairs(lower) do
        local x = x0 + (i - 1) * W
        local opts = { layer = 'back', depth = 170, color = tint(CREAM, rnd(0.96, 1.03)) }
        if kind == 'window' then opts.windows = { { x + 55, -560, 150, 210 } } end
        if kind == 'door' then opts.door = { x + 45, -560, 170, 560 }; opts.doorColor = { 0.36, 0.56, 0.42 } end
        rectBlock(b, x, -760, W, 760, opts)
    end
    rectBlock(b, x0 - 60, -820, 5 * W + 120, 60, { layer = 'back', depth = 210, color = WOOD, oneWay = true })
    local upper = { 'window', 'wall', 'window', 'window', 'wall' }
    for i, kind in ipairs(upper) do
        local x = x0 + (i - 1) * W
        local opts = { layer = 'back', depth = 170, color = tint(BLUE, rnd(0.96, 1.03)) }
        if kind == 'window' then opts.windows = { { x + 55, -1330, 150, 200 } } end
        rectBlock(b, x, -1480, W, 660, opts)
    end
    block(b, { x0 - 110, -1480, x0 + 5 * W + 110, -1480, x0 + 2.5 * W, -2000 },
        { layer = 'back', depth = 240, color = ROOF, oneWay = true })
    rectBlock(b, x0 + 3.6 * W, -2000, 110, 300, { layer = 'back', depth = 110, color = tint(ROOF, 0.85) }) -- chimney

    -- the porch in front of the door: a floor to stand on, pillars, a roof and a railing in front
    rectBlock(b, -1110, -110, 900, 110, { layer = 'play', depth = 300, color = WOOD, oneWay = true })
    local pl = rectBlock(b, -1090, -660, 54, 660, { layer = 'front', depth = 54, color = WHITE })
    local pr = rectBlock(b, -270, -660, 54, 660, { layer = 'front', depth = 54, color = WHITE })
    local roof = rectBlock(b, -1170, -720, 1010, 60, { layer = 'front', depth = 310, color = ROOF })
    weld(b, roof, pl); weld(b, roof, pr)
    local rail = rectBlock(b, -1036, -430, 300, 30, { layer = 'front', depth = 30, color = WHITE })
    weld(b, rail, pl)
    for i = 0, 4 do
        local post = rectBlock(b, -1010 + i * 58, -400, 18, 290, { layer = 'front', depth = 18, color = WHITE, lineScale = 0.6 })
        weld(b, post, rail)
    end

    -- a picket fence in front, on the right
    local railA = rectBlock(b, 260, -300, 1280, 28, { layer = 'front', depth = 26, color = WHITE, lineScale = 0.7 })
    local railB = rectBlock(b, 260, -130, 1280, 28, { layer = 'front', depth = 26, color = WHITE, lineScale = 0.7 })
    weld(b, railA, railB)
    for i = 0, 10 do
        local x = 290 + i * 115
        local picket = block(b, { x, -340, x + 30, -390, x + 60, -340, x + 60, 0, x, 0 },
            { layer = 'front', depth = 26, color = tint(WHITE, rnd(0.95, 1.02)), lineScale = 0.7 })
        weld(b, picket, railA)
    end

    -- crates: play layer, loose (behind the fence, in front of the house)
    rectBlock(b, 620, -240, 230, 230, { layer = 'play', depth = 230, color = { 0.78, 0.6, 0.4 }, dynamic = true })
    rectBlock(b, -1900, -220, 210, 210, { layer = 'play', depth = 210, color = { 0.7, 0.52, 0.38 }, dynamic = true })
    rectBlock(b, -1860, -420, 190, 190, { layer = 'play', depth = 190, color = { 0.62, 0.66, 0.5 }, dynamic = true })

    -- decor: trees and a hedge by the back lane, bushes in front
    for _, t in ipairs({ { 1250, 520 }, { -2500, 600 }, { 2200, 450 } }) do
        decor(b, 'far', { t[1] - 40, PATH_TOP - 20, t[1] + 40, PATH_TOP - 20, t[1] + 30, PATH_TOP - t[2], t[1] - 30, PATH_TOP - t[2] },
            { 0.48, 0.36, 0.28 }, 40)
        decor(b, 'far', blob(t[1], PATH_TOP - t[2] - 180, 260, 18, 0.85), GREENS[love.math.random(#GREENS)], 90)
    end
    for _, h in ipairs({ { -2700, -1950 }, { 250, 1000 }, { 1700, 2600 } }) do
        local pts = {}
        local n = math.floor((h[2] - h[1]) / 70)
        for i = 0, n do pts[#pts + 1] = h[1] + i * 70; pts[#pts + 1] = PATH_TOP - 210 + rnd(-25, 25) end
        pts[#pts + 1] = h[2]; pts[#pts + 1] = PATH_TOP + 10
        pts[#pts + 1] = h[1]; pts[#pts + 1] = PATH_TOP + 10
        decor(b, 'hedge', pts, { 0.3, 0.47, 0.28 }, 70)
    end
    for _, bush in ipairs({ { -1560, 20, 230 }, { 100, 30, 190 }, { 1700, 20, 260 } }) do
        decor(b, 'front', blob(bush[1], bush[2] - bush[3] * 0.55, bush[3], 16, 0.7), GREENS[love.math.random(#GREENS)], 80)
    end
end

---------------------------------------------------------------- Mipos and lanes

local function aliveMipos(b) return mipoKit.alive(b.mipos) end -- src/mipo-kit.lua

local function setZ(b, inst)
    inst.lane = b.lanes[inst] or 'play' -- the joint guard: Mipos in other lanes can't hook (src/mipo-joint-guard.lua)
    local want = b.numbers[inst] + (b.lanes[inst] == 'back' and 0 or FRONT_GROUP)
    if inst.zGroupOffset == want then return end
    inst.zGroupOffset = want
    for _, part in pairs(inst.parts) do
        if part.body and not part.body:isDestroyed() then
            for _, fixture in ipairs(part.body:getFixtures()) do
                local ud = fixture:getUserData()
                if ud and ud.extra then ud.extra.zGroupOffset = want end
            end
        end
    end
end

local function moveMipo(inst, dy, dx)
    for _, part in pairs(inst.parts) do
        if part.body and not part.body:isDestroyed() then
            local x, y = part.body:getPosition()
            part.body:setPosition(x + (dx or 0), y + dy)
            part.body:setLinearVelocity(0, 0)
        end
    end
end

local function setLane(b, inst, lane)
    b.lanes[inst] = lane
    -- a Mipo going back is lifted over the path, so it lands on it (else it'd stand inside it)
    if lane == 'back' then moveMipo(inst, -260) end
    setZ(b, inst)
end

local function spawnMipo(b, x, y, lane)
    local inst = characterManager.createCharacter('humanoid', x, y, 0.3)
    if not inst then return end
    characterManager.randomizeMipoConstrained(inst)
    b.mipos[#b.mipos + 1] = inst
    b.numbers[inst] = b.nextNumber
    b.nextNumber = b.nextNumber % 400 + 1
    b.lanes[inst] = lane or 'play'
    setZ(b, inst)
end

local function mipoAt(b, x, y)
    local best, bestD
    for _, inst in ipairs(aliveMipos(b)) do
        for _, part in pairs(inst.parts) do
            if part.body and not part.body:isDestroyed() then
                local px, py = part.body:getPosition()
                local d = (px - x) ^ 2 + (py - y) ^ 2
                if not bestD or d < bestD then best, bestD = inst, d end
            end
        end
    end
    return best
end

-- who's who, for the contact rules: rebuilt every frame (Mipos get new bodies when rebuilt)
local function refreshRoles(b)
    local roles, passable = {}, {}
    for _, p in ipairs(b.blocks) do
        if p.body and not p.body:isDestroyed() then
            roles[p.body] = { kind = 'block', block = p }
            if p.layer ~= 'play' or p.oneWay then passable[p.body] = true end
        end
    end
    for body, role in pairs(b.groundRoles or {}) do
        roles[body] = { kind = role }
        if role == 'path' then passable[body] = true end
    end
    -- the joint guard's walls: a limb across these isn't stuck (src/mipo-joint-guard.lua)
    state.passableBodies = passable
    for _, inst in ipairs(b.mipos) do
        if b.numbers[inst] then setZ(b, inst) end
        local role = { kind = 'mipo', inst = inst, lane = b.lanes[inst] or 'play' }
        for _, part in pairs(inst.parts or {}) do
            if part.body and not part.body:isDestroyed() then roles[part.body] = role end
        end
    end
    b.roles = roles
end

---------------------------------------------------------------- contact rules

local PLAY_MIPO = { kind = 'mipo', lane = 'play' } -- anything else that moves counts as a play-lane toy

-- a one-way top: decided when the pair first touches (is the other's lowest point above the
-- block's top there, and not going up?), kept until they part
local function oneWaySolid(b, p, other, fBlock, fOther)
    local rec = b.passing[fBlock]
    if rec and rec[fOther] ~= nil then return rec[fOther] end
    local x1, _, x2, y2 = fOther:getBoundingBox()
    local lx, ly = p.body:getLocalPoint((x1 + x2) / 2, y2)
    local _, vy = other:getLinearVelocity()
    local solid = ly <= topAt(p, lx) + 24 and vy > -60
    if not rec then rec = {}; b.passing[fBlock] = rec end
    rec[fOther] = solid
    return solid
end

local function blockWithMipo(b, p, lane, fBlock, fOther)
    if lane == 'back' then return false end
    if p.layer == 'front' then return false end
    if p.oneWay then return oneWaySolid(b, p, fOther:getBody(), fBlock, fOther) end
    return p.layer == 'play'
end

local function allowed(b, ra, rb, fa, fb)
    if ra.kind == 'ground' or rb.kind == 'ground' then return true end
    if ra.kind == 'path' then return rb.kind == 'mipo' and rb.lane == 'back' end
    if rb.kind == 'path' then return ra.kind == 'mipo' and ra.lane == 'back' end
    if ra.kind == 'block' and rb.kind == 'block' then return ra.block.layer == rb.block.layer end
    if ra.kind == 'block' then return blockWithMipo(b, ra.block, rb.lane, fa, fb) end
    if rb.kind == 'block' then return blockWithMipo(b, rb.block, ra.lane, fb, fa) end
    return ra.lane == rb.lane
end

function s.preSolve(fa, fb, contact)
    local b = state.depthSpike
    if not b then return end
    local ra, rb = b.roles[fa:getBody()], b.roles[fb:getBody()]
    if not (ra or rb) then return end
    if not allowed(b, ra or PLAY_MIPO, rb or PLAY_MIPO, fa, fb) then contact:setEnabled(false) end
end

function s.endContact(fa, fb)
    local b = state.depthSpike
    if not b then return end
    if b.passing[fa] then b.passing[fa][fb] = nil end
    if b.passing[fb] then b.passing[fb][fa] = nil end
end

---------------------------------------------------------------- hooks

function s.onStart()
    worldState.paused = false
    local b = depthState()
    local alive = {}
    for _, p in ipairs(b.blocks) do if p.body and not p.body:isDestroyed() then alive[#alive + 1] = p end end
    if #alive == 0 then build(b) end
    b.mipos = aliveMipos(b)
    if #b.mipos == 0 then
        spawnMipo(b, -350, -700)
        spawnMipo(b, 450, -700)
        spawnMipo(b, -700, -1500)
        spawnMipo(b, -2000, -900, 'back')
        spawnMipo(b, 1300, -900, 'back')
    end
    refreshRoles(b)
end

function s.onUnload()
    state.drawSplits = nil
    state.passableBodies = nil
    local b = state.depthSpike
    if b and b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
end

function s.update()
    local b = state.depthSpike
    if not b then return end
    b.mipos = aliveMipos(b)
    for _, inst in ipairs(b.mipos) do
        local x, y = inst.parts.torso1.body:getPosition()
        if y > 3000 then moveMipo(inst, -1400 - y, rnd(-600, 400) - x) end -- off the edge: dropped by the house again
    end
    refreshRoles(b)
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local b = depthState()
    local mx, my = mouseWorldPos()
    local set = b.settings
    if key == 'r' then build(b); refreshRoles(b)
    elseif key == 'm' then spawnMipo(b, mx, my, 'play')
    elseif key == 'n' then spawnMipo(b, mx, my - 260, 'back')
    elseif key == 'l' then
        local inst = mipoAt(b, mx, my)
        if inst then setLane(b, inst, b.lanes[inst] == 'back' and 'play' or 'back') end
    elseif key == 'k' then
        for _, p in ipairs(b.blocks) do
            if p.body and not p.body:isDestroyed() and p.body:getType() == 'static' then
                p.body:setType('dynamic')
                p.body:resetMassData()
                p.body:setAwake(true)
            end
        end
    elseif key == 'v' then set.oblique = not set.oblique
    elseif key == 'o' then set.drawn = not set.drawn
    elseif key == 's' then set.shadows = not set.shadows
    elseif key == 'h' then b.showPanel = not b.showPanel
    end
end

---------------------------------------------------------------- drawing

local function lineMeshes(b, owner, step)
    local set = b.settings
    local width = set.width * (owner.lineScale or 1)
    local key = width .. ',' .. step
    if owner.meshKey ~= key then
        local lines = {}
        for i, l in ipairs(owner.lines) do lines[i] = { pts = l.pts, loop = l.loop, width = width * l.width } end
        owner.meshes = STROKE.meshes(lines, 1.2, step, true)
        owner.meshKey = key
    end
    return owner.meshes
end

local function worldVerts(p)
    local out = {}
    for i = 1, #p.verts, 2 do
        local x, y = p.body:getWorldPoint(p.verts[i], p.verts[i + 1])
        out[#out + 1] = x; out[#out + 1] = y
    end
    return out
end

-- the sides that face us: an edge's side shows when its back copy lies out past it
local function drawSides(points, depth, color, project, lineW)
    local n = #points / 2
    local back = {}
    for i = 1, n do back[i * 2 - 1], back[i * 2] = project(points[i * 2 - 1], points[i * 2], depth) end
    for i = 1, n do
        local j = i % n + 1
        local ax, ay, bx, by = points[i * 2 - 1], points[i * 2], points[j * 2 - 1], points[j * 2]
        local cx, cy, dx, dy = back[j * 2 - 1], back[j * 2], back[i * 2 - 1], back[i * 2]
        local ex, ey = bx - ax, by - ay
        local len = math.sqrt(ex * ex + ey * ey)
        if len > 0.01 then
            local nx, ny = ey / len, -ex / len
            local mx, my = (cx + dx - ax - bx) / 2, (cy + dy - ay - by) / 2
            if mx * nx + my * ny > 0.5 then
                local k = 0.7 + 0.3 * (nx * LIGHT_X + ny * LIGHT_Y)
                love.graphics.setColor(color[1] * k, color[2] * k, color[3] * k)
                love.graphics.polygon('fill', ax, ay, bx, by, cx, cy, dx, dy)
                if lineW then
                    love.graphics.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], 0.8)
                    love.graphics.setLineWidth(lineW)
                    love.graphics.polygon('line', ax, ay, bx, by, cx, cy, dx, dy)
                end
            end
        end
    end
end

-- a hole in the front face (a window, a door): the reveal, then what's at the back of it
local function hole(p, r, project, fill, angle)
    local wx, wy = p.body:getWorldPoint(r[1] + r[3] / 2, r[2] + r[4] / 2)
    local bx, by = project(wx, wy, 40)
    local dx, dy = bx - wx, by - wy
    local ca, sa = math.cos(-angle), math.sin(-angle)
    local lx, ly = dx * ca - dy * sa, dx * sa + dy * ca
    local c = p.color
    love.graphics.setColor(c[1] * 0.62, c[2] * 0.6, c[3] * 0.58)
    love.graphics.rectangle('fill', r[1], r[2], r[3], r[4])
    local x0, y0 = math.max(r[1], r[1] + lx), math.max(r[2], r[2] + ly)
    local x1, y1 = math.min(r[1] + r[3], r[1] + r[3] + lx), math.min(r[2] + r[4], r[2] + r[4] + ly)
    if x1 > x0 and y1 > y0 then fill(x0, y0, x1 - x0, y1 - y0) end
end

local function windowPane(x, y, w, h)
    love.graphics.setColor(0.3, 0.4, 0.5)
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(1, 1, 1, 0.14)
    love.graphics.polygon('fill', x, y + h * 0.55, x + w * 0.55, y, x + w * 0.85, y, x, y + h * 0.9)
    love.graphics.setColor(0.96, 0.94, 0.88)
    love.graphics.rectangle('fill', x + w / 2 - 6, y, 12, h)
    love.graphics.rectangle('fill', x, y + h * 0.45 - 6, w, 12)
end

local function drawFront(b, p, project, step)
    local x, y = p.body:getPosition()
    local a = p.body:getAngle()
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(a)
    local c = p.color
    love.graphics.setColor(c)
    love.graphics.polygon('fill', p.verts)
    for _, r in ipairs(p.windows or {}) do
        hole(p, r, project, windowPane, a)
        love.graphics.setColor(0.95, 0.93, 0.87)
        love.graphics.rectangle('fill', r[1] - 16, r[2] + r[4], r[3] + 32, 18)
    end
    if p.door then
        hole(p, p.door, project, function(dx, dy, dw, dh)
            love.graphics.setColor(p.doorColor or { 0.4, 0.5, 0.4 })
            love.graphics.rectangle('fill', dx, dy, dw, dh)
            love.graphics.setColor(0, 0, 0, 0.18)
            love.graphics.rectangle('line', dx + 20, dy + 24, dw - 40, dh * 0.38)
            love.graphics.rectangle('line', dx + 20, dy + dh * 0.5, dw - 40, dh * 0.4)
            love.graphics.setColor(0.9, 0.78, 0.35)
            love.graphics.circle('fill', dx + dw - 28, dy + dh * 0.5, 11)
        end, a)
    end
    if b.settings.drawn and #STROKE.strokes > 0 then
        love.graphics.translate(-p.sox, -p.soy)
        love.graphics.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], 1)
        for _, mesh in ipairs(lineMeshes(b, p, step)) do love.graphics.draw(mesh) end
    else
        love.graphics.setColor(OUTLINE)
        love.graphics.setLineWidth(4)
        love.graphics.polygon('line', p.verts)
        for _, r in ipairs(p.windows or {}) do love.graphics.rectangle('line', r[1], r[2], r[3], r[4]) end
        if p.door then love.graphics.rectangle('line', p.door[1], p.door[2], p.door[3], p.door[4]) end
    end
    love.graphics.pop()
end

local function drawBlocks(b, layer, project)
    local lineW = b.settings.drawn and 3.5 or 3
    local list = {}
    for _, p in ipairs(b.blocks) do
        if p.layer == layer and p.body and not p.body:isDestroyed() then list[#list + 1] = p end
    end
    -- all the sides first, then all the fronts: a neighbour's side never lands on a front
    for _, p in ipairs(list) do drawSides(worldVerts(p), p.depth, p.color, project, lineW) end
    for _, p in ipairs(list) do drawFront(b, p, project, 0) end
end

local function drawDecor(b, layer, project)
    for _, d in ipairs(b.decor) do
        if d.layer == layer then
            -- a back copy, darker, gives the blob its body
            d.tris = d.tris or love.math.triangulate(d.points)
            local c = d.color
            love.graphics.setColor(c[1] * 0.72, c[2] * 0.72, c[3] * 0.72)
            for _, t in ipairs(d.tris) do
                local bt = {}
                for i = 1, #t, 2 do bt[i], bt[i + 1] = project(t[i], t[i + 1], d.depth) end
                love.graphics.polygon('fill', bt)
            end
            drawSides(d.points, d.depth, tint(c, 0.85), project, nil)
            love.graphics.setColor(c)
            for _, t in ipairs(d.tris) do love.graphics.polygon('fill', t) end
            if b.settings.drawn and #STROKE.strokes > 0 then
                love.graphics.push()
                love.graphics.translate(-d.ox, -d.oy)
                love.graphics.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], 1)
                for _, mesh in ipairs(lineMeshes(b, d, 0)) do love.graphics.draw(mesh) end
                love.graphics.pop()
            end
        end
    end
end

local function screenRect(c, a)
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(c[1], c[2], c[3], a)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getDimensions())
    love.graphics.pop()
end

local function drawSky(b)
    love.graphics.push()
    love.graphics.origin()
    local w, h = love.graphics.getDimensions()
    if not b.skyMesh then
        b.skyMesh = love.graphics.newMesh({
            { 0, 0, 0, 0, SKY_TOP[1], SKY_TOP[2], SKY_TOP[3], 1 }, { 1, 0, 0, 0, SKY_TOP[1], SKY_TOP[2], SKY_TOP[3], 1 },
            { 1, 1, 0, 0, SKY_LOW[1], SKY_LOW[2], SKY_LOW[3], 1 }, { 0, 1, 0, 0, SKY_LOW[1], SKY_LOW[2], SKY_LOW[3], 1 },
        }, 'fan', 'static')
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(b.skyMesh, 0, 0, 0, w, h)
    love.graphics.pop()
end

-- hills far off: they move less than the world as the camera moves
local function drawHills(b)
    local w, h = love.graphics.getDimensions()
    local cx, cy = cam:getWorldCoordinates(w / 2, h / 2)
    for _, hill in ipairs({ { f = 0.8, y = -760, amp = 260, col = { 0.62, 0.74, 0.66 } }, { f = 0.55, y = -620, amp = 200, col = { 0.52, 0.68, 0.48 } } }) do
        love.graphics.push()
        love.graphics.translate(cx * hill.f, (cy + 750) * hill.f * 0.6)
        love.graphics.setColor(hill.col)
        local pts = {}
        for x = -9000, 9000, 300 do
            pts[#pts + 1] = x
            pts[#pts + 1] = hill.y - hill.amp * (0.5 + 0.5 * math.sin(x * 0.0011 + hill.f * 7) * math.cos(x * 0.0004 + hill.f))
        end
        pts[#pts + 1] = 9000; pts[#pts + 1] = 4000
        pts[#pts + 1] = -9000; pts[#pts + 1] = 4000
        for _, t in ipairs(love.math.triangulate(pts)) do love.graphics.polygon('fill', t) end
        love.graphics.pop()
    end
end

local function drawGround(b)
    -- the garden going back to the hills, then the soil cut open in front (a diorama)
    if not b.grassMesh then
        b.grassMesh = love.graphics.newMesh({
            { -9000, -560, 0, 0, 0.66, 0.76, 0.56, 1 }, { 9000, -560, 0, 0, 0.66, 0.76, 0.56, 1 },
            { 9000, 0, 0, 0, 0.5, 0.68, 0.38, 1 }, { -9000, 0, 0, 0, 0.5, 0.68, 0.38, 1 },
        }, 'fan', 'static')
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(b.grassMesh)
    love.graphics.setColor(0.74, 0.64, 0.48)
    love.graphics.rectangle('fill', -9000, PATH_TOP - 40, 18000, 70)
    love.graphics.setColor(0.62, 0.52, 0.4)
    love.graphics.rectangle('fill', -9000, PATH_TOP + 22, 18000, 8)
    love.graphics.setColor(0.52, 0.37, 0.27)
    love.graphics.rectangle('fill', -9000, 0, 18000, 4000)
    love.graphics.setColor(0.42, 0.29, 0.21)
    love.graphics.rectangle('fill', -9000, 0, 18000, 26)
    if not b.pebbles then
        b.pebbles = {}
        for _ = 1, 400 do b.pebbles[#b.pebbles + 1] = { rnd(-9000, 9000), rnd(60, 1600), rnd(10, 34) } end
    end
    love.graphics.setColor(0.6, 0.48, 0.38)
    for _, pb in ipairs(b.pebbles) do love.graphics.ellipse('fill', pb[1], pb[2], pb[3], pb[3] * 0.7) end
end

-- a soft shadow on whatever the Mipo stands over
local function drawShadows(b, lane)
    if not b.settings.shadows then return end
    for _, inst in ipairs(b.mipos) do
        if (b.lanes[inst] or 'play') == lane then
            local tx, ty = inst.parts.torso1.body:getPosition()
            local minX, maxX, footY = math.huge, -math.huge, -math.huge
            for _, part in pairs(inst.parts) do
                if part.body and not part.body:isDestroyed() then
                    local px, py = part.body:getPosition()
                    minX, maxX, footY = math.min(minX, px), math.max(maxX, px), math.max(footY, py)
                end
            end
            local hitY
            if lane == 'back' then
                hitY = PATH_TOP
            else
                state.physicsWorld:rayCast(tx, ty, tx, ty + 4000, function(fixture, _, hy, _, _, fraction)
                    if fixture:isSensor() then return -1 end
                    local role = b.roles[fixture:getBody()]
                    if not role then return -1 end
                    if role.kind == 'ground' or (role.kind == 'block' and role.block.layer ~= 'front') then
                        hitY = hy
                        return fraction
                    end
                    return -1
                end)
            end
            if hitY then
                local gap = math.max(0, hitY - footY - 70)
                local fade = math.max(0, 1 - gap / 900)
                if fade > 0 then
                    local width = (maxX - minX + 260) * (1 + gap / 1200)
                    love.graphics.setColor(0.12, 0.1, 0.14, 0.42 * fade)
                    love.graphics.draw(SHADOW, (minX + maxX) / 2, hitY - 6, 0, width / 64, 70 * (1 + gap / 1500) / 64, 32, 32)
                end
            end
        end
    end
end

---------------------------------------------------------------- Mipos with a body

-- Each lane's Mipos are drawn into a canvas of their own, then laid down on the world:
--   mipo depth copies of the canvas, each shrunk a little toward the vanishing point (or slid,
--              oblique) and darkened, back to front, the real one on top: every Mipo gets a
--              cut-out's edge going back in space, like the blocks' sides
--   roundness  the real one with a soft light edge on the side facing the light and a shaded
--              edge on the other (the silhouette's alpha looked up toward and away from it)
local THICK_COPIES = 8
local ROUND_SHADER = love.graphics.newShader([[
    uniform vec2 dir;       // one step toward the light, in texture coordinates
    uniform float amount;
    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
        vec4 c = Texel(tex, uv);
        if (c.a <= 0.0) return c * color;
        float towards = 0.0;
        float away = 0.0;
        for (int i = 1; i <= 4; i++) {
            towards += Texel(tex, uv + dir * float(i)).a;
            away += Texel(tex, uv - dir * float(i)).a;
        }
        float lit = 1.0 - towards / 4.0;   // near the edge that faces the light
        float shade = 1.0 - away / 4.0;    // near the edge turned away
        c.rgb += vec3(1.0, 0.97, 0.9) * lit * amount * 0.45 * c.a;
        c.rgb *= 1.0 - shade * amount * 0.5;
        return c * color;
    }
]])

local function laneCanvas(b, lane)
    local w, h = love.graphics.getDimensions()
    b.canvases = b.canvases or {}
    local c = b.canvases[lane]
    if not c or c:getWidth() ~= w or c:getHeight() ~= h then
        c = love.graphics.newCanvas(w, h)
        b.canvases[lane] = c
    end
    return c
end

local function beginLane(b, lane)
    b.outerCanvas = love.graphics.getCanvas()
    love.graphics.setCanvas({ laneCanvas(b, lane), stencil = true })
    love.graphics.clear(0, 0, 0, 0)
    b.openLane = lane
end

local function endLane(b)
    local lane = b.openLane
    if not lane then return end
    b.openLane = nil
    local outer = b.outerCanvas
    if outer then love.graphics.setCanvas({ outer, stencil = true }) else love.graphics.setCanvas() end
    local canvas = b.canvases[lane]
    local set = b.settings
    local w, h = love.graphics.getDimensions()
    local zoom = cam.scale or 1
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setBlendMode('alpha', 'premultiplied')
    if set.mipoDepth > 0 then -- its own slider: the house's depth doesn't change it
        local vx, vy = w / 2, h * set.horizon
        for i = THICK_COPIES, 1, -1 do
            local d = set.mipoDepth * i / THICK_COPIES
            local k = 0.78 - 0.2 * i / THICK_COPIES -- further back, darker
            love.graphics.setColor(k * 0.95, k * 0.88, k * 0.9, 1)
            if set.oblique then
                love.graphics.draw(canvas, d * 0.42 * zoom, -d * 0.55 * zoom)
            else
                local sc = 1 / (1 + d * set.persp)
                love.graphics.draw(canvas, vx, vy, 0, sc, sc, vx, vy)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    if set.round > 0 then
        local r = math.max(1, set.roundSize * zoom / 4)
        ROUND_SHADER:send('dir', { LIGHT_X * r / w, LIGHT_Y * r / h })
        ROUND_SHADER:send('amount', set.round)
        love.graphics.setShader(ROUND_SHADER)
    end
    love.graphics.draw(canvas)
    love.graphics.setShader()
    love.graphics.setBlendMode('alpha')
    love.graphics.pop()
end

-- between the back lane's Mipos and the front lane's: the hedge, the haze, the house, the porch
local function drawMiddle()
    local b = state.depthSpike
    if not b or b.middleDone then return end
    b.middleDone = true
    endLane(b)
    local project = b.project
    drawDecor(b, 'hedge', project)
    if b.settings.haze > 0 then screenRect(SKY_LOW, b.settings.haze) end
    drawBlocks(b, 'back', project)
    drawBlocks(b, 'play', project)
    drawShadows(b, 'play')
    love.graphics.setColor(1, 1, 1, 1)
end

local SPLITS = {
    { z = -1e12, fn = function() beginLane(state.depthSpike, 'back') end },
    { z = SPLIT_Z, fn = function() drawMiddle(); beginLane(state.depthSpike, 'play') end },
    { z = 1e12, fn = function() endLane(state.depthSpike) end }, -- after the last drawable
}

function s.drawBelow()
    local b = state.depthSpike
    if not b then return end
    local set = b.settings
    set.mipoDepth = set.mipoDepth or set.thick or 30 -- settings newer than a running scene's state
    set.round = set.round or 0.5
    set.roundSize = set.roundSize or 40
    b.project = projector(b)
    b.middleDone = false
    b.openLane = nil
    drawSky(b)
    drawHills(b)
    drawGround(b)
    drawDecor(b, 'far', b.project)
    drawShadows(b, 'back')
    state.drawSplits = SPLITS
    if state.playMode then
        b.savedDrawBodies = state.world.debugDrawBodies
        state.world.debugDrawBodies = false
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function s.draw()
    local b = state.depthSpike
    if not b then return end
    state.drawSplits = nil
    if b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
    endLane(b)  -- a lane left open (something in the draw reset the canvas, or the world drew nothing)
    drawMiddle() -- if the world drew nothing (textures off), the middle comes here
    drawBlocks(b, 'front', b.project)
    drawDecor(b, 'front', b.project)
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local b = state.depthSpike
    if not (b and state.playMode and b.showPanel) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 420
    local rows = { { 'depth', 0, 3, 0.01 }, { 'persp', 0, 0.004, 0.0001 }, { 'horizon', -0.5, 1.2, 0.01 },
        { 'haze', 0, 0.8, 0.01 }, { 'width', 2, 30, 1 }, { 'mipoDepth', 0, 120, 1 }, { 'round', 0, 1.5, 0.01 },
        { 'roundSize', 5, 120, 1 } }
    local h = (BH + pad) * (#rows + 3) + pad + 24
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• depth ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        for _, row in ipairs(rows) do
            local key = row[1]
            local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('depth' .. key, x, y, 180, row[2], row[3], b.settings[key], nil, row[4])
            if v then b.settings[key] = v + 0 end
            ui.label(x + 290, y, key == 'mipoDepth' and 'mipo depth' or key)
        end
        local set = b.settings
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, (set.oblique and 'oblique' or 'perspective') .. ' (v)  ' .. (set.drawn and 'drawn' or 'plain') ..
            ' (o)  shadows ' .. (set.shadows and 'on' or 'off') .. ' (s)')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'l lane swap (Mipo at mouse)  m / n Mipo front / back')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'k knock the house loose  r build again  h panel')
    end)
end

return s

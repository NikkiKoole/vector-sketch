-- diglive: the finger is a scoop: the earth you dig comes along, and pours out where you let go; the world answers
-- Nikki 2026-11-16: burrow felt boring; dig jobs (Mipos dig what you mark) was "finnicky and too systems like,
-- also not direct enough"; the plain finger digging "feels not nice". After looking around (Sago Mini Trucks and
-- Diggers: dirt you move "back and forth, over and over"; Where's My Water: earth that resists; the shovel's sound
-- in A Game About Digging a Hole):
--   the scoop   the finger digs in bites (a crunch each), slower the deeper the earth (topsoil, clay, deep ground:
--               the ring lags behind the finger); what it digs it carries, a lump of dirt growing on it, until the
--               scoop is full and it digs no more. Let go and it pours out as clumps (Box2D bodies); a clump that
--               lies still turns back into earth, so a pile is ground again: dig here, build a hill there
--   the Mipos   look at the finger; one near enough on the same level walks over and reaches for it; dug out from
--               under its feet it falls, surprised (a squeak, the face); earth coming down near it surprises it
--   the earth   a thin crust or a lump cut loose near where you dug shakes for a moment (crumbs trickle) and comes
--               down as clumps; that can leave another thin bit, so it can cascade a little
--   the pieces  wooden beams and toy blocks buried in the earth: dig one free, drag it up, stack a tower
--   the ground  (2026-11-19) dirt, clay and sand: a clay layer under the topsoil, clay and sand pockets, a sand band
--               deep down. Each digs, carries and pours as itself: clay slow and heavy, sand fast and running
--   the kiln    on the grass, left of the cave: drop clay in and it bakes into bricks that pop out over the rim
-- Made of: the earth   scripts/spikes/burrow.playtime.lua (its own state 'diglive', its cave, rocks, two Mipos)
-- play mode (tab): drag on the earth to dig, let go to pour. keys: h the panel
--   (the burrow's own: m Mipo  r reset  [ ] the scoop's size  t o b i looks)
local s = {}

-- the burrow's grid: its width and depth, with more sky above the grass to pour towers into (Nikki 2026-11-16:
-- "the top of where you can drop sand should be higher, i want us to also make towers"); dirt that settles
-- above the grid's top would be lost. GRID_ID: another grid starts the earth over (the old one doesn't fit).
local WORLD_W, WORLD_H, Y0 = 9600, 7600, -4000
local GRID_ID = 2
local X0 = -WORLD_W / 2

local CLUMP_MAX = 160
local CLUMP_COLORS = { { 0.36, 0.25, 0.16 }, { 0.3, 0.2, 0.13 }, { 0.62, 0.44, 0.28 }, { 0.5, 0.38, 0.3 },
    { 0.44, 0.31, 0.2 } }

local function st()
    state.digliveSpike = state.digliveSpike or { showPanel = true, come = true, crumble = true, thin = 2,
        shake = 0.6, crumbs = {}, clumps = {}, pending = {} }
    local c = state.digliveSpike
    -- the scoop (added after the first version: a hot reload keeps the old table)
    if c.scoopBites == nil then c.scoopBites, c.resist, c.settle = 12, 1, 1.0 end
    if (c.scoopV or 1) < 2 then c.scoopBites, c.scoopV = 12, 2 end -- 3 was too little per stroke ("weak")
    c.puffs = c.puffs or {}
    c.scoop = c.scoop or { carried = 0 }
    return c
end

---------------------------------------------------------------- the earth

local panelRect
local function overPanel()
    local r = panelRect
    if not r then return false end
    local mx, my = love.mouse.getPosition()
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

local function earthEnv()
    return { state = state, world = world, cam = cam, camera = camera, ui = ui, objectManager = objectManager,
        fixtures = fixtures, shape8Dict = shape8Dict, characterManager = characterManager, worldState = worldState,
        mouseWorldPos = mouseWorldPos, getInteractedWithPointer = getInteractedWithPointer, love = love,
        math = math, table = table, string = string, pairs = pairs, ipairs = ipairs, unpack = unpack,
        print = print, tostring = tostring, tonumber = tonumber, type = type, pcall = pcall }
end

---------------------------------------------------------------- what the earth is: dirt, clay, sand

-- Nikki 2026-11-19: "certain types of ground ... each with different properties, dirt is good for growing stuff
-- on, clay can be baked into bricks"; clay "in layers / pockets in the ground". Each place in the earth is dirt,
-- clay or sand (c.mat, on its own grid of MCELL, whatever the burrow's cell): it digs, carries and pours as what
-- it is, and the earth's shader colours it from a small picture of the grid (burrow's opts.materials).
--   dirt   the topsoil and most of the ground; digs easily
--   clay   a layer under the topsoil and pockets deeper; heavy, slow to dig, sticky clumps; the kiln bakes it
--   sand   pockets and a band deep down; digs fast, runs: it doesn't hold over a hole, its clumps slide
local MCELL = 40
local MCOLS, MROWS = math.floor(WORLD_W / MCELL), math.floor(WORLD_H / MCELL)
local MSW = MCOLS + 1
local MAT_ID = 3 -- another way of laying them out: made again
local DIRT, CLAY, SAND = 1, 2, 3
local KINDS = {
    [DIRT] = { name = 'dirt', bite = 0.06, pitch = 1.2, density = 0.8, friction = 0.9, size = 1,
        colors = { { 0.36, 0.25, 0.16 }, { 0.3, 0.2, 0.13 }, { 0.44, 0.31, 0.2 } } },
    [CLAY] = { name = 'clay', bite = 0.14, pitch = 0.75, density = 1.4, friction = 1.0, size = 1.1,
        colors = { { 0.72, 0.42, 0.27 }, { 0.65, 0.36, 0.23 }, { 0.78, 0.49, 0.32 } } },
    [SAND] = { name = 'sand', bite = 0.035, pitch = 1.7, density = 0.9, friction = 0.12, size = 0.7,
        colors = { { 0.86, 0.74, 0.5 }, { 0.8, 0.67, 0.43 }, { 0.91, 0.8, 0.58 } } },
}
local SHARE = { [DIRT] = { 255, 0, 0 }, [CLAY] = { 0, 255, 0 }, [SAND] = { 0, 0, 255 } }

local function kindColor(m)
    local colors = KINDS[m or DIRT].colors
    return colors[love.math.random(1, #colors)]
end

local function layOutMaterials(c)
    local seed = (c.matSeed or 0) * 13.7
    local noise = love.math.noise
    local mat = {}
    for j = 0, MROWS do
        for i = 0, MCOLS do
            local x, y = X0 + i * MCELL, Y0 + j * MCELL
            local d = y + (noise(x * 0.0007, 3.1 + seed) - 0.5) * 260
            local m = DIRT
            -- the clay layer under the topsoil, thicker and thinner along the way
            if d > 420 and d < 900 + (noise(x * 0.0013, 5.7 + seed) - 0.5) * 500 then m = CLAY end
            -- a sand band deep down, under the cave
            if d > 2650 and d < 2950 + (noise(x * 0.0011, 8.2 + seed) - 0.5) * 300 then m = SAND end
            -- pockets
            if y > 250 then
                if noise(x * 0.0015, y * 0.0015, 11.3 + seed) > 0.67 then
                    m = CLAY
                elseif noise(x * 0.0017, y * 0.0017, 23.9 + seed) > 0.7 then
                    m = SAND
                end
            end
            mat[j * MSW + i + 1] = m
        end
    end
    c.mat, c.matId = mat, MAT_ID
end

local matData, matImage, matDirty
local function materials()
    local c = st()
    if not c.mat then return nil end
    if not matImage then
        matData = love.image.newImageData(MSW, MROWS + 1)
        local mat = c.mat
        matData:mapPixel(function(i, j)
            local sh = SHARE[mat[j * MSW + i + 1]] or SHARE[DIRT]
            return sh[1] / 255, sh[2] / 255, sh[3] / 255, 1
        end)
        matImage = love.graphics.newImage(matData)
        matImage:setFilter('linear', 'linear')
        matImage:setWrap('clamp', 'clamp')
    elseif matDirty then
        matImage:replacePixels(matData)
    end
    matDirty = nil
    return { image = matImage, x0 = X0, y0 = Y0, cell = MCELL, w = MSW, h = MROWS + 1 }
end

local function forgetMaterialPicture() matImage, matData, matDirty = nil, nil, nil end

local function matAt(x, y)
    local mat = st().mat
    if not mat then return DIRT end
    local i = math.max(0, math.min(MCOLS, math.floor((x - X0) / MCELL + 0.5)))
    local j = math.max(0, math.min(MROWS, math.floor((y - Y0) / MCELL + 0.5)))
    return mat[j * MSW + i + 1] or DIRT
end

-- the earth within r of (x, y) becomes m (where a clump settles)
local function setMat(x, y, r, m)
    local mat = st().mat
    if not mat then return end
    local i0, i1 = math.max(0, math.floor((x - r - X0) / MCELL)), math.min(MCOLS, math.ceil((x + r - X0) / MCELL))
    local j0, j1 = math.max(0, math.floor((y - r - Y0) / MCELL)), math.min(MROWS, math.ceil((y + r - Y0) / MCELL))
    local sh = SHARE[m]
    for j = j0, j1 do
        for i = i0, i1 do
            local px, py = X0 + i * MCELL, Y0 + j * MCELL
            if (px - x) ^ 2 + (py - y) ^ 2 <= (r + MCELL * 0.5) ^ 2 then
                local k = j * MSW + i + 1
                if mat[k] ~= m then
                    mat[k] = m
                    if matData then
                        matData:setPixel(i, j, sh[1] / 255, sh[2] / 255, sh[3] / 255, 1)
                        matDirty = true
                    end
                end
            end
        end
    end
end

local earth
local function loadEarth()
    return love.filesystem.load('scripts/spikes/burrow.playtime.lua')({
        env = earthEnv(), stateKey = 'diglive', w = WORLD_W, h = WORLD_H, y0 = Y0,
        canDig = function() return false end, -- the scoop digs (below), not the burrow's own stroke
        rocks = 0, -- no rocks (Nikki 2026-11-16: not these, the borrowed Mipo body outlines)
        sharedFrame = true,
        materials = materials,
        -- grass grows on dirt open to the sky, not on clay or sand (2026-11-19)
        grassOn = function(x, y) return matAt(x, y) == DIRT end,
    })
end

local function field() return state.diglive end

-- the grid as the burrow keeps it (b.dens: samples on a CELL grid, row by row)
local function grid()
    local b = field()
    local cell = b.cell
    local cols, rows = math.floor(WORLD_W / cell), math.floor(WORLD_H / cell)
    return b.dens, cell, cols, rows, cols + 1
end

---------------------------------------------------------------- boards held against the earth

-- A loose beam or block let go of against the earth sticks there (Nikki 2026-11-16: "things that help making
-- straight walls, like a thing you can hold against it"): held still (kinematic) until a press pulls it off. While
-- it's stuck the scoop doesn't dig past it (the earth behind it, seen from the scoop, is put back after a bite;
-- the ring stops at its face) and dirt settling against it doesn't fill under it: dig along it or pour against it,
-- take it away, and the wall is straight.
local function stuckBoards()
    local list = {}
    for _, find in ipairs(st().finds or {}) do
        if find.stuck and find.body and not find.body:isDestroyed() then list[#list + 1] = find end
    end
    return list
end

-- where a point is in a board's frame: along its length, across it
local function boardFrame(find, x, y)
    local body = find.body
    local bx, by, a = body:getX(), body:getY(), body:getAngle()
    local ux, uy = math.cos(a), math.sin(a)
    local dx, dy = x - bx, y - by
    return dx * ux + dy * uy, dx * -uy + dy * ux
end

-- the samples within r of (x, y) a stuck board keeps: under it, and (with fromX, fromY: where the scoop is) the
-- ones on its far side; returned with their values, to be put back after a dig or a fill
local function guardedSamples(x, y, r, fromX, fromY)
    local boards = stuckBoards()
    if #boards == 0 then return nil end
    local dens, cell, cols, rows, sw = grid()
    local i0, i1 = math.max(0, math.floor((x - r - X0) / cell)), math.min(cols, math.ceil((x + r - X0) / cell))
    local j0, j1 = math.max(0, math.floor((y - r - Y0) / cell)), math.min(rows, math.ceil((y + r - Y0) / cell))
    local kept = {}
    for _, find in ipairs(boards) do
        local hl, ht = find.w / 2 + 10, find.h / 2 + 10
        local fromSide
        if fromX then
            local _, across = boardFrame(find, fromX, fromY)
            fromSide = across >= 0 and 1 or -1
        end
        for j = j0, j1 do
            for i = i0, i1 do
                local px, py = X0 + i * cell, Y0 + j * cell
                local along, across = boardFrame(find, px, py)
                if math.abs(along) <= hl then
                    local under = math.abs(across) <= ht
                    local beyond = fromSide and (across >= 0 and 1 or -1) ~= fromSide
                    if under or beyond then
                        local k = j * sw + i + 1
                        if kept[k] == nil then kept[k] = dens[k] end
                    end
                end
            end
        end
    end
    return kept
end

local function putBack(kept)
    if not kept then return end
    local dens = grid()
    for k, v in pairs(kept) do dens[k] = v end
end

-- would the ring, going from (x0, y0) to (x1, y1), cross a stuck board (or end up inside one)?
local function boardInTheWay(x0, y0, x1, y1, r)
    for _, find in ipairs(stuckBoards()) do
        local _, a0 = boardFrame(find, x0, y0)
        local along1, a1 = boardFrame(find, x1, y1)
        if math.abs(along1) <= find.w / 2 + r * 0.5 then
            if (a0 >= 0) ~= (a1 >= 0) or math.abs(a1) < find.h / 2 then return true end
        end
    end
    return false
end

---------------------------------------------------------------- sounds (made here; copied from the mole spike)

local sounds = {}
local function makeSound(name, seconds, fn)
    local rate = 44100
    local n = math.floor(seconds * rate)
    local data = love.sound.newSoundData(n, rate, 16, 1)
    local prev = 0
    for i = 0, n - 1 do
        local v
        v, prev = fn(i / rate, i / n, prev)
        data:setSample(i, math.max(-1, math.min(1, v)))
    end
    sounds[name] = love.audio.newSource(data, 'static')
end

local function ensureSounds()
    if sounds.crunch or not (love.audio and love.sound) then return end
    makeSound('crunch', 0.11, function(_, u, prev)
        local crackle = (love.math.random() < 0.25) and (love.math.random() * 2 - 1) or 0
        local v = prev * 0.55 + crackle * 0.9
        return v * (1 - u) ^ 2, v
    end)
    makeSound('scrape', 0.09, function(_, u, prev)
        local v = prev * 0.92 + (love.math.random() * 2 - 1) * 0.12
        return v * math.sin(u * math.pi) * 1.6, v
    end)
    -- under each bite: a low thud, the earth giving way; eased in over 12 ms (an instant start popped like a shot,
    -- Nikki 2026-11-17 "less shooting noise")
    makeSound('thud', 0.16, function(t, u)
        local f = 95 - 45 * u
        return math.sin(2 * math.pi * f * t) * math.min(1, t / 0.012) * (1 - u) ^ 2.5 * 0.9, 0
    end)
    -- a crust letting go: a low rumble
    makeSound('rumble', 0.5, function(_, u, prev)
        local v = prev * 0.985 + (love.math.random() * 2 - 1) * 0.05
        return v * math.sin(u * math.pi) * 3, v
    end)
end

-- the kiln's (2026-11-19): clay going in hisses, a brick done pops
local function ensureKilnSounds()
    if sounds.sizzle or not (love.audio and love.sound) then return end
    makeSound('sizzle', 0.35, function(_, u, prev)
        local v = (love.math.random() * 2 - 1) - prev * 0.6
        return v * 0.25 * math.min(1, u * 20) * (1 - u) ^ 1.5, v
    end)
    makeSound('pop', 0.12, function(t, u)
        local f = 520 - 300 * u
        return math.sin(2 * math.pi * f * t) * math.min(1, t / 0.004) * (1 - u) ^ 3 * 0.8, 0
    end)
end

local function play(name, pitch, volume)
    local src = sounds[name]
    if not src then return end
    local c = src:clone()
    c:setPitch((pitch or 1) * (0.93 + love.math.random() * 0.14))
    c:setVolume((volume or 1) * (mipoVoice.volume or 1) * (mipoVoice.masterVolume or 1))
    c:play()
end


---------------------------------------------------------------- clumps: poured and fallen earth

local function scoopRadius() return field().brush end
local function clumpSize() return math.max(25, math.min(70, scoopRadius() * 0.35)) end

local function crumbs(x, y, n, speed, m)
    local list = st().crumbs
    for _ = 1, n do
        local a = -math.pi / 2 + (love.math.random() - 0.5) * 2.6
        local v = (100 + love.math.random() * 300) * (speed or 1)
        list[#list + 1] = { x = x, y = y, vx = math.cos(a) * v, vy = math.sin(a) * v,
            r = 4 + love.math.random() * 7, life = 0.5 + love.math.random() * 0.5,
            color = m and kindColor(m) or CLUMP_COLORS[love.math.random(1, #CLUMP_COLORS)] }
    end
end

local function removeClump(list, i)
    local p = table.remove(list, i)
    if p and p.body and not p.body:isDestroyed() then objectManager.destroyBody(p.body) end
    return p
end

-- Loose earth: what clumps settled into (and the pockets filled in a pile), remembered per grid sample (c.loose):
-- it digs soft, faster than topsoil (Nikki 2026-11-16: digging felt really slow once a few had settled; down
-- there settled dirt was deep ground)
local function looseSet()
    local c = st()
    c.loose = c.loose or {}
    return c.loose
end

local function markLoose(x, y, r)
    local _, cell, cols, rows, sw = grid()
    local loose = looseSet()
    local i0, i1 = math.floor((x - r - X0) / cell), math.ceil((x + r - X0) / cell)
    local j0, j1 = math.floor((y - r - Y0) / cell), math.ceil((y + r - Y0) / cell)
    for j = math.max(0, j0), math.min(rows, j1) do
        for i = math.max(0, i0), math.min(cols, i1) do
            local px, py = X0 + i * cell, Y0 + j * cell
            if (px - x) ^ 2 + (py - y) ^ 2 <= (r + cell) ^ 2 then loose[j * sw + i] = true end
        end
    end
end

local function isLoose(x, y)
    local _, cell, _, _, sw = grid()
    return looseSet()[math.floor((y - Y0) / cell + 0.5) * sw + math.floor((x - X0) / cell + 0.5)] == true
end

-- the place where clumps are settling, looked over for pockets (fillPockets)
local function noteSettle(x, y, r)
    local c = st()
    local box = c.settleBox
    if box then
        box[1], box[2] = math.min(box[1], x - r), math.min(box[2], y - r)
        box[3], box[4] = math.max(box[3], x + r), math.max(box[4], y + r)
    else
        c.settleBox = { x - r, y - r, x + r, y + r }
    end
    c.settleAt = love.timer.getTime()
end

-- a clump turns back into earth where it lies (its body goes first: the burrow won't fill under a body)
local function settleClump(list, i)
    local p = list[i]
    local body = p.body
    local x, y
    if body and not body:isDestroyed() then x, y = body:getPosition() end
    removeClump(list, i)
    if x then
        local kept = guardedSamples(x, y, p.size * 1.05 + 60)
        earth.dig(x, y, x, y, true, p.size * 1.05)
        putBack(kept)
        setMat(x, y, p.size * 1.05, p.kind or DIRT)
        markLoose(x, y, p.size * 1.05)
        noteSettle(x, y, p.size * 2)
    end
end

-- Holes in a pile: clumps lie round, so the earth they settle into keeps air between them (Nikki: "when dropping
-- the sand somewhere you get these holes"). While a pile settles, small air pockets closed in by earth (not
-- reached from the edge of the settling place, at most POCKET_MAX samples) are filled; a closed-off cave is bigger
-- and stays.
local POCKET_MAX = 16
local function fillPockets(c)
    local dens, cell, cols, rows, sw = grid()
    local box, margin = c.settleBox, 4
    local i0 = math.max(1, math.floor((box[1] - X0) / cell) - margin)
    local i1 = math.min(cols - 1, math.ceil((box[3] - X0) / cell) + margin)
    local j0 = math.max(1, math.floor((box[2] - Y0) / cell) - margin)
    local j1 = math.min(rows - 1, math.ceil((box[4] - Y0) / cell) + margin)
    -- a pile settling outside the earth's grid (a clump flung off the side or above it): nothing to fill
    if i0 > i1 or j0 > j1 then return end
    local seen = {}
    local function flood(i, j, list)
        local stack = { i, j }
        seen[j * sw + i] = true
        while #stack > 0 do
            local y = table.remove(stack)
            local x = table.remove(stack)
            if list then list[#list + 1] = { x, y } end
            for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                local a, b = x + d[1], y + d[2]
                local key = b * sw + a
                if a >= i0 and a <= i1 and b >= j0 and b <= j1 and not seen[key] and dens[key + 1] < 0.5 then
                    seen[key] = true
                    stack[#stack + 1] = a
                    stack[#stack + 1] = b
                end
            end
        end
    end
    local function air(i, j) return dens[j * sw + i + 1] < 0.5 end
    for i = i0, i1 do
        if air(i, j0) and not seen[j0 * sw + i] then flood(i, j0) end
        if air(i, j1) and not seen[j1 * sw + i] then flood(i, j1) end
    end
    for j = j0, j1 do
        if air(i0, j) and not seen[j * sw + i0] then flood(i0, j) end
        if air(i1, j) and not seen[j * sw + i1] then flood(i1, j) end
    end
    for j = j0 + 1, j1 - 1 do
        for i = i0 + 1, i1 - 1 do
            if air(i, j) and not seen[j * sw + i] then
                local pocket = {}
                flood(i, j, pocket)
                if #pocket <= POCKET_MAX then
                    for _, q in ipairs(pocket) do
                        local x, y = X0 + q[1] * cell, Y0 + q[2] * cell
                        local kept = guardedSamples(x, y, cell * 2)
                        earth.dig(x, y, x, y, true, cell * 0.75)
                        putBack(kept)
                        markLoose(x, y, cell * 0.5)
                    end
                end
            end
        end
    end
end

local function clump(px, py, size, vx, vy, m)
    m = m or DIRT
    local kind = KINDS[m]
    local list = st().clumps
    local verts = {}
    local k = love.math.random(5, 7)
    for i = 1, k do
        local ang = (i - 1 + love.math.random() * 0.4) / k * math.pi * 2
        local rr = size * (0.8 + love.math.random() * 0.3)
        verts[#verts + 1], verts[#verts + 2] = math.cos(ang) * rr, math.sin(ang) * rr
    end
    local thing = objectManager.addThing('custom', { x = px, y = py, vertices = verts, label = 'clump' })
    if not thing then return end
    local body = thing.body
    for _, fixture in ipairs(body:getFixtures()) do
        fixture:setDensity(kind.density)
        fixture:setFriction(kind.friction)
        fixture:setRestitution(0.05)
    end
    body:resetMassData()
    body:setAngle(love.math.random() * math.pi * 2)
    local perM = love.physics.getMeter() / 100 -- speeds as at 100 px per metre
    body:setLinearVelocity((vx or (love.math.random() - 0.5) * 150) * perM, (vy or -love.math.random() * 100) * perM)
    body:setAngularVelocity((love.math.random() - 0.5) * 6)
    if #list >= CLUMP_MAX then -- too many: the oldest lying still becomes earth; none still, the oldest goes
        -- (settled in mid-air it left floating earth, sand that then crumbled: 2026-11-19)
        local oldest
        for n = 1, #list do
            if list[n].still > 0.1 then oldest = n; break end
        end
        if oldest then settleClump(list, oldest) else removeClump(list, 1) end
    end
    list[#list + 1] = { body = body, still = 0, size = size, kind = m, color = kindColor(m) }
end

local function heldBody(body)
    for _, b in ipairs(getInteractedWithPointer()) do
        if b == body then return true end
    end
    return false
end

local function clumpsUpdate(dt)
    local c = st()
    local list = c.clumps
    for i = #list, 1, -1 do
        local p = list[i]
        local body = p.body
        if not body or body:isDestroyed() then
            table.remove(list, i)
        else
            local vx, vy = body:getLinearVelocity()
            local perM = love.physics.getMeter() / 100
            p.still = (vx * vx + vy * vy < (25 * perM) ^ 2 and not heldBody(body)) and p.still + dt or 0
            local _, y = body:getPosition()
            if y > Y0 + WORLD_H + 2000 then
                removeClump(list, i)
            elseif p.still > c.settle and not p.onKiln then -- (on the kiln: it's flicked off, kilnUpdate)
                settleClump(list, i)
            end
        end
    end
    -- while a pile settles, and a moment after, its pockets fill
    if c.settleBox then
        local now = love.timer.getTime()
        if now - (c.settleAt or 0) > 2 then
            c.settleBox = nil
        elseif now >= (c.pocketAt or 0) then
            c.pocketAt = now + 0.3
            fillPockets(c)
        end
    end
end

---------------------------------------------------------------- the scoop

-- how hard the earth is here: seconds between bites, the crunch's pitch. By what it is (KINDS), a little harder
-- deeper down (up to 1.6x at 2000); settled earth (loose) digs at half (it was topsoil, clay, deep ground by depth
-- only until 2026-11-19)
local function materialAt(x, y)
    local m = matAt(x, y)
    local kind = KINDS[m]
    local bite = kind.bite * (1 + math.max(0, math.min(1, y / 2000)) * 0.6)
    if isLoose(x, y) then bite = kind.bite * 0.5 end
    return { bite = bite, pitch = kind.pitch, kind = m }
end

-- how much of a circle is earth (0..1), from 13 points
local RING = {}
for k = 0, 11 do RING[#RING + 1] = { math.cos(k / 12 * math.pi * 2) * 0.7, math.sin(k / 12 * math.pi * 2) * 0.7 } end
RING[#RING + 1] = { 0, 0 }
local function earthIn(x, y, r, kinds)
    local n = 0
    for _, p in ipairs(RING) do
        local px, py = x + p[1] * r, y + p[2] * r
        if earth.earthAt(px, py) > 0.5 then
            n = n + 1
            if kinds then
                local m = matAt(px, py)
                kinds[m] = kinds[m] + 1
            end
        end
    end
    return n / #RING
end

local function capacity(r) return st().scoopBites * math.pi * r * r end

-- Each bite lands (Nikki 2026-11-16: digging "really feels weak still"; too little per stroke, and no punch):
-- a bite a bit bigger than the ring, chunks flung back toward the finger, a puff of dust, the ring kicking out,
-- a small camera knock, and a thud under the crunch.
local BITE_SIZE = 1.15  -- a bite's radius, times the ring's
local function bite(c, sc, m, r, ux, uy)
    local kinds = { 0, 0, 0 }
    local frac = earthIn(sc.x, sc.y, r * BITE_SIZE, kinds)
    if frac <= 0 then return false end
    local rb = r * BITE_SIZE
    local kept = guardedSamples(sc.x, sc.y, rb + 60, sc.backX or sc.x, sc.backY or sc.y)
    earth.dig(sc.x, sc.y, sc.x, sc.y, false, rb)
    putBack(kept)
    local add = math.min(capacity(r), sc.carried + frac * math.pi * rb * rb) - sc.carried
    local total = kinds[1] + kinds[2] + kinds[3]
    sc.load = sc.load or { 0, 0, 0 }
    for k = 1, 3 do sc.load[k] = sc.load[k] + add * kinds[k] / total end
    sc.carried = sc.carried + add
    local most = (kinds[CLAY] >= kinds[DIRT] and kinds[CLAY] >= kinds[SAND]) and CLAY
        or (kinds[SAND] > kinds[DIRT] and SAND or DIRT)
    sc.bites = (sc.bites or 0) + 1
    sc.kick = 1
    crumbs(sc.x, sc.y, 4, 0.8, most)
    -- chunks: thrown back the way the finger came, and up
    local bx, by = -(ux or 0), -(uy or 1)
    local list = c.crumbs
    for _ = 1, 2 + math.floor(frac * 3) do
        local a = math.atan2(by - 0.8, bx) + (love.math.random() - 0.5) * 1.2
        local v = 450 + love.math.random() * 450
        list[#list + 1] = { x = sc.x + (love.math.random() - 0.5) * rb, y = sc.y + (love.math.random() - 0.5) * rb,
            vx = math.cos(a) * v, vy = math.sin(a) * v, r = 14 + love.math.random() * 16 * frac,
            life = 0.45 + love.math.random() * 0.3, chunk = true, color = kindColor(most) }
    end
    c.puffs[#c.puffs + 1] = { x = sc.x, y = sc.y, r = rb, t = 0, kind = most }
    -- kept subtle (Nikki 2026-11-17: "a bit more subtle, less screenshake, less shooting noise"; was 5 px for
    -- 0.09 s, crunch 0.55-1, thud 0.5-1)
    camera.shake(math.min(12, 1.5 / math.max(0.05, cam:getScale())), 0.06)
    play('crunch', m.pitch * (0.9 + love.math.random() * 0.2), 0.3 + frac * 0.2)
    play('thud', m.pitch * (0.85 + love.math.random() * 0.2), 0.2 + frac * 0.2)
    -- where it dug is looked over for earth that can't hold
    local reg = c.region
    if reg then
        reg[1], reg[2] = math.min(reg[1], sc.x - r), math.min(reg[2], sc.y - r)
        reg[3], reg[4] = math.max(reg[3], sc.x + r), math.max(reg[4], sc.y + r)
    else
        c.region = { sc.x - r, sc.y - r, sc.x + r, sc.y + r }
    end
    c.regionAt = love.timer.getTime()
    c.regionFrom = nil -- digging again: looked over afresh
    return true
end

-- let go: what it carries pours out, a few clumps a frame
-- (what it carries is kept per kind, sc.load: it pours out as clumps of each, mixed; a sand clump is smaller, so
-- there are more of them)
local function startPour(c, sc)
    local size = clumpSize()
    local load = sc.load or { sc.carried, 0, 0 }
    if sc.carried > math.pi * size * size * 0.5 then
        c.pour = { x = sc.x, y = sc.y, size = size, load = { load[1], load[2], load[3] } }
    end
    sc.carried, sc.load = 0, { 0, 0, 0 }
end

local function pourTick(c)
    local p = c.pour
    if not p then return end
    for _ = 1, 3 do
        local load = p.load
        local total = load[1] + load[2] + load[3]
        if total <= math.pi * p.size * p.size * 0.3 then break end
        local pick, m = love.math.random() * total, SAND
        if pick < load[DIRT] then m = DIRT elseif pick < load[DIRT] + load[CLAY] then m = CLAY end
        local s2 = p.size * KINDS[m].size * (0.75 + love.math.random() * 0.5)
        clump(p.x + (love.math.random() - 0.5) * p.size * 1.5, p.y + (love.math.random() - 0.5) * p.size,
            s2, (love.math.random() - 0.5) * 120, 40 + love.math.random() * 80, m)
        load[m] = math.max(0, load[m] - math.pi * s2 * s2)
    end
    local load = p.load
    if load[1] + load[2] + load[3] <= math.pi * p.size * p.size * 0.3 then
        c.pour = nil
        c.lastFall = { x = p.x, y = p.y, at = love.timer.getTime() }
    end
end

-- (Straight strokes that locked onto flat / upright / 45 degrees, with square bites: tried 2026-11-17, taken out:
-- Nikki "i like the sticks i dont like the locking angles". The boards make straight walls.)
local function scoopTick(c, dt, now)
    local sc = c.scoop
    local down = state.playMode and love.mouse.isDown(1)
    if down and not sc.active then
        -- a press that grabbed nothing (a Mipo or a clump makes a pointer joint first), not on a panel
        if #getInteractedWithPointer() == 0 and not overPanel() then
            local mx, my = mouseWorldPos()
            sc.active, sc.x, sc.y, sc.biteIn = true, mx, my, 0
        end
    elseif not down and sc.active then
        sc.active = nil
        startPour(c, sc)
    end
    if not sc.active then
        sc.press = nil
        return
    end
    local r = scoopRadius()
    local full = sc.carried >= capacity(r) * 0.999
    sc.biteIn = sc.biteIn - dt
    sc.kick = math.max(0, (sc.kick or 0) - dt * 9)
    -- the ring follows the finger: freely through air; into earth only a bite at a time (a step of 0.65 r every
    -- m.bite seconds: the harder the earth, the slower), and not at all once the scoop is full
    local mx, my = mouseWorldPos()
    local dx, dy = mx - sc.x, my - sc.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local canBite = not full and sc.biteIn <= 0
    if dist > 1 then
        local ux, uy = dx / dist, dy / dist
        local step = math.min(dist, r * 0.65)
        sc.backX, sc.backY = sc.x - ux * r, sc.y - uy * r -- the side it digs from (a board guards the other)
        if boardInTheWay(sc.x, sc.y, sc.x + ux * step, sc.y + uy * step, r) then
            sc.press = { ux = ux, uy = uy, amount = 1 } -- up against a board: it stops at its face
        elseif earthIn(sc.x + ux * step, sc.y + uy * step, r) > 0.05 then
            if canBite then
                sc.x, sc.y = sc.x + ux * step, sc.y + uy * step
                local m = materialAt(sc.x, sc.y)
                if bite(c, sc, m, r, ux, uy) then
                    sc.biteIn = m.bite * c.resist
                    sc.biteTotal = sc.biteIn
                end
                sc.press = nil
            else
                -- pushing into the earth: the ring squashes against it until the next bite gives (full: it stays)
                local amount = full and 1 or 1 - math.max(0, sc.biteIn) / math.max(0.001, sc.biteTotal or 0.1)
                sc.press = { ux = ux, uy = uy, amount = amount }
            end
        else
            step = math.min(dist, 8000 * dt)
            sc.x, sc.y = sc.x + ux * step, sc.y + uy * step
            sc.press = nil
        end
    elseif canBite and earthIn(sc.x, sc.y, r) > 0.05 then -- held still at an edge: it rubs a bit more off
        local m = materialAt(sc.x, sc.y)
        if bite(c, sc, m, r) then
            sc.biteIn = m.bite * c.resist
            sc.biteTotal = sc.biteIn
        end
        sc.press = nil
    else
        sc.press = nil
    end
    c.finger = { x = sc.x, y = sc.y, at = now }
end

---------------------------------------------------------------- the earth answering: crumbling

-- Earth near the dig that can't hold: a thin crust (air under it, and air again within `thin` samples above),
-- or a lump cut loose (not joined to the edge of the looked-over box). Returns sample indices {i, j}.
local function weakSamples(c)
    local dens, cell, cols, rows, sw = grid()
    local reg = c.region
    local margin = 6
    local i0 = math.max(1, math.floor((reg[1] - X0) / cell) - margin)
    local i1 = math.min(cols - 1, math.ceil((reg[3] - X0) / cell) + margin)
    local j0 = math.max(1, math.floor((reg[2] - Y0) / cell) - margin)
    local j1 = math.min(rows - 1, math.ceil((reg[4] - Y0) / cell) + margin)
    local function solid(i, j) return dens[j * sw + i + 1] >= 0.5 end
    local weak, seen = {}, {}
    -- thin crusts
    for i = i0, i1 do
        for j = j0, j1 do
            if solid(i, j) and not solid(i, j + 1) then
                local t = 1
                while t <= c.thin and j - t >= 0 and solid(i, j - t) do t = t + 1 end
                if t <= c.thin then
                    for k = 0, t - 1 do
                        local key = (j - k) * sw + i
                        if not seen[key] then seen[key] = true; weak[#weak + 1] = { i, j - k } end
                    end
                end
            end
        end
    end
    -- sand doesn't hold: sand with air under it, or at an edge steeper than about 45 degrees (air beside it and
    -- below that), comes down too, a quick trickle (pending at a third of the shake)
    for i = i0, i1 do
        for j = j0, j1 do
            local key = j * sw + i
            local px, py = X0 + i * cell, Y0 + j * cell
            -- (only sand that was there: settled sand runs again, its lumpy piles crumbling and settling over and
            -- over, 2026-11-19: 160 sand clumps and 300 waiting, for good)
            if not seen[key] and solid(i, j) and matAt(px, py) == SAND and not isLoose(px, py) then
                local over = not solid(i, j + 1)
                    or (not solid(i - 1, j) and not solid(i - 1, j + 1))
                    or (not solid(i + 1, j) and not solid(i + 1, j + 1))
                if over then
                    seen[key] = true
                    weak[#weak + 1] = { i, j, sand = true }
                end
            end
        end
    end
    -- lumps cut loose: earth inside the box not reached from earth on its edge
    local reached, stack = {}, {}
    local function push(i, j)
        if i < i0 or i > i1 or j < j0 or j > j1 then return end
        local key = j * sw + i
        if reached[key] or not solid(i, j) then return end
        reached[key] = true
        stack[#stack + 1] = i
        stack[#stack + 1] = j
    end
    for i = i0, i1 do push(i, j0); push(i, j1) end
    for j = j0, j1 do push(i0, j); push(i1, j) end
    while #stack > 0 do
        local j = table.remove(stack)
        local i = table.remove(stack)
        push(i + 1, j); push(i - 1, j); push(i, j + 1); push(i, j - 1)
    end
    for i = i0, i1 do
        for j = j0, j1 do
            local key = j * sw + i
            if solid(i, j) and not reached[key] and not seen[key] then
                seen[key] = true
                weak[#weak + 1] = { i, j }
            end
        end
    end
    return weak
end

-- the weak bits start shaking; each comes down a moment later (pendingKeys: not twice)
local function lookForWeakEarth(c, now)
    local _, cell, _, _, sw = grid()
    c.pendingKeys = c.pendingKeys or {}
    local added = 0
    for _, p in ipairs(weakSamples(c)) do
        local key = p[2] * sw + p[1]
        if not c.pendingKeys[key] and added < 300 then
            c.pendingKeys[key] = true
            added = added + 1
            c.pending[#c.pending + 1] = { x = X0 + p[1] * cell, y = Y0 + p[2] * cell, key = key,
                at = now + c.shake * (0.7 + love.math.random() * 0.6) * (p.sand and 0.3 or 1) }
        end
    end
    if added > 0 then play('rumble', 0.7 + love.math.random() * 0.3, math.min(1, 0.3 + added / 40)) end
end

local function crumbleTick(c, dt, now)
    local _, cell = grid()
    local fell, fx, fy = 0, 0, 0
    for k = #c.pending, 1, -1 do
        local p = c.pending[k]
        if now >= p.at then
            table.remove(c.pending, k)
            c.pendingKeys[p.key] = nil
            if earth.earthAt(p.x, p.y) > 0.5 then
                local m = matAt(p.x, p.y)
                earth.dig(p.x, p.y, p.x, p.y, false, cell * 0.8)
                -- sand runs: every bit of it comes down as a clump, the others half the time
                if (m == SAND or love.math.random() < 0.5) and #c.clumps < CLUMP_MAX * 0.75 then
                    clump(p.x, p.y, cell * (0.5 + love.math.random() * 0.4) * KINDS[m].size * (m == SAND and 1.4 or 1),
                        nil, nil, m)
                end
                fell, fx, fy = fell + 1, fx + p.x, fy + p.y
            end
        elseif love.math.random() < dt * 4 then
            crumbs(p.x, p.y + cell * 0.5, 1, 0.2, matAt(p.x, p.y)) -- trickling while it shakes
        end
    end
    if fell > 0 then
        play('crunch', 0.6 + love.math.random() * 0.3, math.min(1, 0.4 + fell / 10))
        c.regionAt = now -- what's left may be thin now: keep looking a little longer
        c.lastFall = { x = fx / fell, y = fy / fell, at = now }
    end
    -- look the dug place over a few times a second while digging, and a while after
    if c.region then
        c.regionFrom = c.regionFrom or now
        if now - (c.regionAt or 0) > 2.5 or now - c.regionFrom > 6 then -- (a fall keeps it going, but not forever)
            c.regionFrom = nil
            c.region = nil
        elseif now >= (c.lookAt or 0) then
            c.lookAt = now + 0.2
            lookForWeakEarth(c, now)
        end
    end
end

---------------------------------------------------------------- the Mipos answering

local WATCH = 2600   -- look at the finger from this far
local COME = 2200    -- walk over from this far (on about the same level)
local NEAR = 450     -- close enough: stop and reach for it
local LEVEL = 700    -- "the same level": the finger at most this far above or below

local function held(inst)
    local bodies = getInteractedWithPointer()
    for _, part in pairs(inst.parts) do
        for _, body in ipairs(bodies) do
            if part.body == body then return true end
        end
    end
    return false
end

local function fingerPos()
    local f = st().finger
    if f then return f.x, f.y end
    return 0, 0
end

local function stopAnswering(inst)
    local a = inst._dl
    if not a then return end
    if a.walking then mipoWalk.drive(inst, nil) end
    if a.looking then mipoActions.stopLooking(inst) end
    if a.reaching then mipoActions.stopPointing(inst) end
    inst._dl = nil
end

local function surprise(inst, now, squeak)
    local a = inst._dl or {}
    inst._dl = a
    if now - (a.surprisedAt or -10) < 2.5 then return end
    a.surprisedAt = now
    mipoEmotion.set(inst, 'surprised', 1, 0.9, false)
    if squeak then mipoVoice.squeak(inst, 'surprised') end
end

local function answerTick(inst, now)
    local c = st()
    local a = inst._dl or {}
    inst._dl = a
    local torso = inst.parts.torso1.body
    local tx, ty = torso:getPosition()
    -- falling: the floor went (dug away, crumbled)
    local _, vy = torso:getLinearVelocity()
    local perM = love.physics.getMeter() / 100
    if vy > 700 * perM and not held(inst) then surprise(inst, now, true) end
    -- earth coming down near it
    local fall = c.lastFall
    if fall and now - fall.at < 0.1 and (fall.x - tx) ^ 2 + (fall.y - ty) ^ 2 < 1200 * 1200 then
        surprise(inst, now, false)
    end

    local f = c.finger
    local recent = f and now - f.at < 1.5
    local dx, dy = f and f.x - tx or 0, f and f.y - ty or 0
    local d = math.sqrt(dx * dx + dy * dy)
    if not (recent and d < WATCH) or held(inst) then
        if a.walking then mipoWalk.drive(inst, nil); a.walking = nil end
        if a.looking then mipoActions.stopLooking(inst); a.looking = nil end
        if a.reaching then mipoActions.stopPointing(inst); a.reaching = nil end
        return
    end
    if not a.looking then mipoActions.lookAt(inst, fingerPos); a.looking = true end
    if not c.come then return end
    local sameLevel = math.abs(dy) < LEVEL
    local wantWalk = sameLevel and d < COME and math.abs(dx) > NEAR * 0.7 and now > (a.restUntil or 0)
    if wantWalk then
        mipoWalk.drive(inst, (dx > 0 and 1 or -1) * 1.8, 'walk')
        a.walking = true
        if mipoWalk.blocked(inst) then -- a wall or a drop: it waits and watches
            mipoWalk.drive(inst, nil)
            a.walking, a.restUntil = nil, now + 2
        end
    elseif a.walking then
        mipoWalk.drive(inst, nil)
        a.walking = nil
    end
    local reach = d < NEAR * 1.6
    if reach and not a.reaching then
        mipoActions.pointAt(inst, fingerPos)
        a.reaching = true
        if now - (a.happyAt or -10) > 4 then
            a.happyAt = now
            mipoEmotion.set(inst, 'happy', 0.8, 1.5, false)
        end
    elseif not reach and a.reaching then
        mipoActions.stopPointing(inst)
        a.reaching = nil
    end
end

local function mipos()
    local list = {}
    for _, inst in ipairs(field() and field().mipos or {}) do
        if mipoKit.isAlive(inst) then list[#list + 1] = inst end
    end
    return list
end


---------------------------------------------------------------- pieces buried in the earth: beams and blocks

-- Something to build with, dug out of the earth. Nikki 2026-11-16: first planks ("a bit useless"), then Fabuland's
-- big parts (a tower or castle "of what you are digging up"; too big: "maybe a bit much the big fabuland pieces"),
-- now "a few beams, maybe some diff sizes that worked better, some blocks". Plain wooden pieces, no snapping:
-- they stack by friction. Held (kinematic) while there's earth round them, darker in it; dig most of one free and
-- it shakes, its own footprint is dug out (it lay inside solid earth, whose edges ran through it: once loose it
-- fell through them, "the kinda fall through the chainshape") and it comes loose.
local PIECES = {
    -- kind, w, h, how many
    { 'beam', 1100, 70, 2 }, { 'beam', 800, 70, 3 }, { 'beam', 500, 60, 3 }, { 'beam', 320, 60, 2 },
    { 'block', 300, 300, 3 }, { 'block', 220, 220, 4 }, { 'block', 300, 150, 3 }, { 'block', 160, 160, 3 },
}
local WOOD = { { 0.66, 0.47, 0.27 }, { 0.58, 0.4, 0.22 }, { 0.72, 0.55, 0.33 } }
local PAINT = { { 0.81, 0.27, 0.2 }, { 0.95, 0.78, 0.25 }, { 0.2, 0.42, 0.68 }, { 0.3, 0.55, 0.33 },
    { 0.66, 0.47, 0.27 }, { 0.92, 0.88, 0.8 } }
local CAVE = { 300, 1050, 2700, 2350 } -- the burrow's starting cave (x1, y1, x2, y2), with a margin
local FINDS_KIND = 'pieces' -- what c.finds holds; others (planks, Fabuland parts) are cleared at start

local function rectVerts(w, h)
    local hw, hh = w / 2, h / 2
    return { -hw, -hh, hw, -hh, hw, hh, -hw, hh }
end

local function makePieceBody(find)
    local thing = objectManager.addThing('custom', { x = find.x, y = find.y, vertices = rectVerts(find.w, find.h),
        label = find.kind })
    if not thing then return end
    local body = thing.body
    body:setAngle(find.angle)
    for _, fixture in ipairs(body:getFixtures()) do
        fixture:setDensity(0.6)
        fixture:setFriction(0.9)
        fixture:setRestitution(0.05)
    end
    body:resetMassData()
    if find.free and not find.stuck then
        body:setType('dynamic')
    else
        body:setType('kinematic')
        body:setLinearVelocity(0, 0)
        body:setAngularVelocity(0)
    end
    find.body = body
end

local function destroyPieces(c, keep)
    for _, find in ipairs(c.finds or {}) do
        local body = find.body
        if body and not body:isDestroyed() then
            if keep then find.x, find.y, find.angle = body:getX(), body:getY(), body:getAngle() end
            objectManager.destroyBody(body)
        end
        find.body = nil
    end
    if not keep then c.finds = nil end
end

local function placePieces(c)
    c.findSeed = (c.findSeed or 0) + 1
    local rng = love.math.newRandomGenerator(900 + c.findSeed)
    c.finds, c.findsKind = {}, FINDS_KIND
    for _, kind in ipairs(PIECES) do
        local placed, tries = 0, 0
        while placed < kind[4] and tries < 60 do
            tries = tries + 1
            local w, h = kind[2], kind[3]
            local radius = math.sqrt(w * w + h * h) / 2
            local x = X0 + 400 + radius + rng:random() * (WORLD_W - 800 - radius * 2)
            local y = 250 + radius + rng:random() * 2600
            local angle = (rng:random() - 0.5) * 0.5
            if kind[1] == 'beam' and rng:random() < 0.25 then angle = angle + math.pi / 2 end -- now and then standing
            local m = radius
            local ok = not (x > CAVE[1] - m and x < CAVE[3] + m and y > CAVE[2] - m and y < CAVE[4] + m)
            for _, o in ipairs(c.finds) do
                if (o.x - x) ^ 2 + (o.y - y) ^ 2 < (o.radius + radius + 120) ^ 2 then ok = false end
            end
            if ok and earth.earthAt(x, y) > 0.5 then
                local colors = kind[1] == 'beam' and WOOD or PAINT
                local find = { kind = kind[1], w = w, h = h, x = x, y = y, angle = angle, radius = radius,
                    color = colors[rng:random(1, #colors)] }
                makePieceBody(find)
                c.finds[#c.finds + 1] = find
                placed = placed + 1
            end
        end
    end
end

-- how much earth holds a buried piece: points just outside its box, all round
local function pieceHeld(find)
    local body = find.body
    local hw, hh = find.w / 2 + 40, find.h / 2 + 40
    local n, inEarth = 0, 0
    for k = 0, 3 do
        local t = (k + 0.5) / 4
        for _, p in ipairs({ { -hw + 2 * hw * t, -hh }, { -hw + 2 * hw * t, hh }, { -hw, -hh + 2 * hh * t },
            { hw, -hh + 2 * hh * t } }) do
            n = n + 1
            if earth.earthAt(body:getWorldPoint(p[1], p[2])) > 0.5 then inEarth = inEarth + 1 end
        end
    end
    return inEarth / n
end

-- its footprint (and a little round it) dug out of the earth
local CARVE_MARGIN = 30
local function carveFootprint(find)
    local body = find.body
    local step = 70
    local r = step * 0.75 + CARVE_MARGIN
    local nx, ny = math.max(1, math.ceil(find.w / step)), math.max(1, math.ceil(find.h / step))
    for i = 0, nx - 1 do
        for j = 0, ny - 1 do
            local lx, ly = -find.w / 2 + (i + 0.5) * find.w / nx, -find.h / 2 + (j + 0.5) * find.h / ny
            local x, y = body:getWorldPoint(lx, ly)
            earth.dig(x, y, x, y, false, r)
        end
    end
end

-- a loose piece with its middle in earth (pushed in): its place is dug out, so it lands in a pocket
local function sunk(find)
    local body = find.body
    local n, inEarth = 0, 0
    for _, p in ipairs({ { 0, 0 }, { -0.3, -0.3 }, { 0.3, -0.3 }, { -0.3, 0.3 }, { 0.3, 0.3 } }) do
        n = n + 1
        if earth.earthAt(body:getWorldPoint(p[1] * find.w, p[2] * find.h)) > 0.5 then inEarth = inEarth + 1 end
    end
    return inEarth / n >= 0.6
end

-- a loose piece with earth inside its edges (a pour settled round it, the earth closed in): Box2D keeps pushing it
-- out of a dozen chain edges at once, ~400 contact calls a step for one block lying still (2026-11-19: half the
-- frame). Its place is dug out like a sunk one's.
local WEDGE_INSET = 15
local WEDGE_POINTS = { { -1, -1 }, { 0, -1 }, { 1, -1 }, { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 }, { -1, 0 } }
local function wedged(find)
    local body = find.body
    local hw, hh = find.w / 2 - WEDGE_INSET, find.h / 2 - WEDGE_INSET
    if hw <= 0 or hh <= 0 then return false end
    for _, p in ipairs(WEDGE_POINTS) do
        if earth.earthAt(body:getWorldPoint(p[1] * hw, p[2] * hh)) > 0.5 then return true end
    end
    return false
end

local function piecesUpdate(c, now)
    for _, find in ipairs(c.finds or {}) do
        local body = find.body
        if body and not body:isDestroyed() and find.free and now >= (find.checkAt or 0) then
            find.checkAt = now + 0.5
            if not find.stuck and (sunk(find) or wedged(find)) then
                carveFootprint(find)
                body:setAwake(true)
            end
        elseif body and not body:isDestroyed() and not find.free and now >= (find.checkAt or 0) then
            find.checkAt = now + 0.25
            if pieceHeld(find) < 0.35 then
                if not find.shakeAt then
                    find.shakeAt = now
                    play('rumble', 1.3, 0.4)
                elseif now - find.shakeAt > 0.5 and not find.carved then
                    carveFootprint(find) -- the earth is rebuilt round it before it moves (next check)
                    find.carved = true
                elseif find.carved then
                    find.free, find.shakeAt = true, nil
                    body:setType('dynamic')
                    body:setAwake(true)
                    crumbs(body:getX(), body:getY(), 6, 0.5)
                    play('crunch', 0.7, 0.8)
                end
            else
                find.shakeAt = nil
            end
        end
    end
end

local function drawPieces(c)
    local t = love.timer.getTime()
    for _, find in ipairs(c.finds or {}) do
        local body = find.body
        if body and not body:isDestroyed() then
            local x, y, a = body:getX(), body:getY(), body:getAngle()
            if find.shakeAt then x, y = x + math.sin(t * 60) * 6, y + math.cos(t * 47) * 4 end
            local col = find.color
            local dim = find.free and 1 or 0.55 -- still in the earth: darker
            local hw, hh = find.w / 2, find.h / 2
            love.graphics.push()
            love.graphics.translate(x, y)
            love.graphics.rotate(a)
            love.graphics.setColor(col[1] * dim, col[2] * dim, col[3] * dim, 1)
            love.graphics.rectangle('fill', -hw, -hh, find.w, find.h, 8, 8)
            if find.hotUntil and t < find.hotUntil then -- fresh from the kiln: glowing, cooling
                local heat = (find.hotUntil - t) / 4
                col = { col[1] + (1 - col[1]) * heat, col[2] + (0.62 - col[2]) * heat, col[3] + (0.2 - col[3]) * heat }
                love.graphics.setColor(col[1], col[2], col[3], 1)
                love.graphics.rectangle('fill', -hw, -hh, find.w, find.h, 8, 8)
            end
            if find.kind == 'brick' then -- a lighter top edge and a few specks
                love.graphics.setColor(math.min(1, col[1] * 1.15) * dim, math.min(1, col[2] * 1.15) * dim,
                    math.min(1, col[3] * 1.15) * dim, 1)
                love.graphics.rectangle('fill', -hw + 8, -hh + 6, find.w - 16, find.h * 0.22, 4, 4)
                love.graphics.setColor(col[1] * 0.7 * dim, col[2] * 0.7 * dim, col[3] * 0.7 * dim, 1)
                local rng = find.specks or {}
                find.specks = rng
                if #rng == 0 then
                    for k = 1, 5 do rng[k] = { (love.math.random() - 0.5) * 0.8, (love.math.random() - 0.3) * 0.6 } end
                end
                for _, q in ipairs(rng) do love.graphics.circle('fill', q[1] * find.w, q[2] * find.h, 4) end
            elseif find.kind == 'beam' then -- grain and a nail at each end
                love.graphics.setColor(0.25 * dim, 0.15 * dim, 0.08 * dim, 0.6)
                love.graphics.setLineWidth(3)
                love.graphics.line(-hw + 30, -hh * 0.3, hw - 40, -hh * 0.25)
                love.graphics.line(-hw + 60, hh * 0.35, hw - 20, hh * 0.3)
                love.graphics.setColor(0.2 * dim, 0.12 * dim, 0.06 * dim, 1)
                love.graphics.circle('fill', -hw + 24, 0, 6)
                love.graphics.circle('fill', hw - 24, 0, 6)
            else -- a toy block: a lighter face inside
                local inset = math.min(hw, hh) * 0.22
                love.graphics.setColor(math.min(1, col[1] * 1.12) * dim, math.min(1, col[2] * 1.12) * dim,
                    math.min(1, col[3] * 1.12) * dim, 1)
                love.graphics.rectangle('fill', -hw + inset, -hh + inset, find.w - inset * 2, find.h - inset * 2, 5, 5)
            end
            love.graphics.setColor(0.2 * dim, 0.12 * dim, 0.06 * dim, 1)
            love.graphics.setLineWidth(5)
            love.graphics.rectangle('line', -hw, -hh, find.w, find.h, 8, 8)
            if find.stuck then -- held against the earth: a pale edge and a peg at each end
                love.graphics.setColor(1, 0.95, 0.8, 0.8)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle('line', -hw + 6, -hh + 6, find.w - 12, find.h - 12, 5, 5)
                local peg = math.min(hw, hh) * 0.35
                love.graphics.circle('fill', -hw + math.max(peg, 20), 0, math.min(12, peg))
                love.graphics.circle('fill', hw - math.max(peg, 20), 0, math.min(12, peg))
            end
            love.graphics.pop()
        end
    end
    love.graphics.setLineWidth(1)
end

---------------------------------------------------------------- the kiln: clay in, bricks out

-- A kiln on the grass (Nikki 2026-11-19: "a kiln at the top surface where you can drop in your clumps"): a brick
-- box open at the top with a fire under it. Clay clumps that fall in hiss and go into the heap inside; every
-- KILN_PER_BRICK of them bake into a brick that pops out over the rim, glowing and cooling (a piece like the beams
-- and blocks: drag it, stack it, it sticks against the earth). Dirt and sand aren't for baking: the fire spits them
-- back out.
local KILN_X = -700
local KILN_W, KILN_H, KILN_WALL = 460, 420, 60
local KILN_PER_BRICK = 10
local KILN_BAKE = 1.6 -- seconds a brick bakes
local BRICK_W, BRICK_H = 200, 90
local BRICK_COLORS = { { 0.74, 0.33, 0.2 }, { 0.68, 0.3, 0.19 }, { 0.79, 0.4, 0.24 } }

local function kilnState(c)
    c.kiln = c.kiln or { clay = 0 }
    return c.kiln
end

-- where the earth's top is at x (the first earth from the sky down)
local function surfaceY(x)
    local y = Y0 + 200
    while y < Y0 + WORLD_H and earth.earthAt(x, y) < 0.5 do y = y + 10 end
    return y
end

-- the ground under it made flat, and nothing over its footprint (once; the burrow won't fill under a body, so
-- before the body is made)
local function shapeKilnGround(k)
    local base = -math.huge
    for _, dx in ipairs({ -KILN_W / 2, -KILN_W / 4, 0, KILN_W / 4, KILN_W / 2 }) do
        base = math.max(base, surfaceY(KILN_X + dx))
    end
    base = base - 30
    for dx = -KILN_W / 2 - 40, KILN_W / 2 + 40, 60 do
        earth.dig(KILN_X + dx, base + 70, KILN_X + dx, base + 70, true, 75)
    end
    for dx = -KILN_W / 2, KILN_W / 2, 60 do
        for up = 70, 520, 90 do earth.dig(KILN_X + dx, base - up, KILN_X + dx, base - up, false, 70) end
    end
    k.base, k.shaped = base, true
end

local function makeKilnBody(k)
    local body = love.physics.newBody(state.physicsWorld, KILN_X, k.base, 'static')
    local hw = KILN_W / 2
    local wallH = KILN_H
    love.physics.newFixture(body, love.physics.newRectangleShape(-hw + KILN_WALL / 2, -wallH / 2, KILN_WALL, wallH))
    love.physics.newFixture(body, love.physics.newRectangleShape(hw - KILN_WALL / 2, -wallH / 2, KILN_WALL, wallH))
    love.physics.newFixture(body, love.physics.newRectangleShape(0, -KILN_WALL / 2, KILN_W, KILN_WALL))
    body:setUserData({ diglive = 'kiln' })
    k.body = body
end

local function destroyKiln(c)
    local k = c.kiln
    if k and k.body and not k.body:isDestroyed() then k.body:destroy() end
    if k then k.body = nil end
end

local function placeKiln(c)
    local k = kilnState(c)
    if not k.shaped then shapeKilnGround(k) end
    if not k.body or k.body:isDestroyed() then makeKilnBody(k) end
end

-- inside the box: between the walls, under the rim, over the floor
local function inKiln(k, x, y)
    local hw = KILN_W / 2 - KILN_WALL
    return k.base and math.abs(x - KILN_X) < hw and y < k.base - KILN_WALL and y > k.base - KILN_H + 20
end

-- (it comes up over one rim, the other side each time, and hops off outside: from the middle they fell back in)
-- clay is taken in anywhere on the kiln, its rims too (a poured lump spreads; the mouth alone caught a fifth)
local function onKiln(k, x, y)
    return k.base and math.abs(x - KILN_X) < KILN_W / 2 + 50 and y < k.base and y > k.base - KILN_H - 110
end

local function popBrick(c, k, now)
    local side = k.side or 1
    k.side = -side
    local find = { kind = 'brick', w = BRICK_W, h = BRICK_H, x = KILN_X + side * (KILN_W / 2 - KILN_WALL / 2),
        y = k.base - KILN_H - BRICK_H, angle = 0,
        radius = math.sqrt(BRICK_W ^ 2 + BRICK_H ^ 2) / 2, free = true, hotUntil = now + 4,
        color = BRICK_COLORS[love.math.random(1, #BRICK_COLORS)] }
    makePieceBody(find)
    if not find.body then return end
    local perM = love.physics.getMeter() / 100
    find.body:setLinearVelocity(side * (350 + love.math.random() * 150) * perM,
        -(450 + love.math.random() * 150) * perM)
    find.body:setAngularVelocity(side * (1 + love.math.random() * 1.5))
    c.finds = c.finds or {}
    c.finds[#c.finds + 1] = find
    play('pop', 0.9 + love.math.random() * 0.2, 0.7)
    crumbs(find.x, find.y, 6, 0.6, CLAY)
    c.puffs[#c.puffs + 1] = { x = find.x, y = find.y, r = 140, t = 0, smoke = true }
end

local function kilnUpdate(c, dt, now)
    local k = c.kiln
    if not (k and k.body) then return end
    -- what falls in
    local list = c.clumps
    for i = #list, 1, -1 do
        local p = list[i]
        local body = p.body
        if body and not body:isDestroyed() and not heldBody(body) then
            local x, y = body:getPosition()
            p.onKiln = onKiln(k, x, y)
            if p.kind == CLAY and p.onKiln then
                removeClump(list, i)
                k.clay = k.clay + 1
                k.flare = 1
                play('sizzle', 0.9 + love.math.random() * 0.3, 0.35)
            elseif inKiln(k, x, y) or (p.onKiln and p.still > 0.2) then -- lying on a rim too: it'd turn to earth there
                if not p.spatAt or now - p.spatAt > 0.6 then -- not for baking: spat back out
                    p.spatAt = now
                    local perM = love.physics.getMeter() / 100
                    local side = x >= KILN_X and 1 or -1 -- away over the nearer rim
                    body:setLinearVelocity(side * (350 + love.math.random() * 120) * perM,
                        -(550 + love.math.random() * 150) * perM)
                    play('pop', 0.5 + love.math.random() * 0.2, 0.35)
                    c.puffs[#c.puffs + 1] = { x = x, y = y, r = 70, t = 0, smoke = true }
                end
            end
        end
    end
    -- baking: a brick at a time while there's clay for one
    k.flare = math.max(0, (k.flare or 0) - dt * 2)
    if k.bakeAt then
        if now >= k.bakeAt then
            k.bakeAt = nil
            popBrick(c, k, now)
        end
    elseif k.clay >= KILN_PER_BRICK then
        k.clay = k.clay - KILN_PER_BRICK
        k.bakeAt = now + KILN_BAKE
        k.bakeFrom = now
    end
end

local function drawKiln(c)
    local k = c.kiln
    if not (k and k.base) then return end
    local t = love.timer.getTime()
    local x0, base = KILN_X - KILN_W / 2, k.base
    local top = base - KILN_H
    local baking = k.bakeAt and (t - k.bakeFrom) / KILN_BAKE or 0
    local heat = math.min(1, 0.35 + (k.flare or 0) * 0.4 + baking * 0.5)
    -- the inside: dark, glowing from below
    love.graphics.setColor(0.18, 0.1, 0.07, 1)
    love.graphics.rectangle('fill', x0 + KILN_WALL, top, KILN_W - KILN_WALL * 2, KILN_H - KILN_WALL)
    love.graphics.setColor(1, 0.45, 0.12, 0.35 * heat)
    love.graphics.rectangle('fill', x0 + KILN_WALL, top + KILN_H * 0.4, KILN_W - KILN_WALL * 2,
        KILN_H * 0.6 - KILN_WALL)
    -- the clay heap inside
    if k.clay > 0 then
        local f = math.min(1, k.clay / KILN_PER_BRICK)
        local col = KINDS[CLAY].colors[1]
        local glow = baking
        love.graphics.setColor(col[1] + (1 - col[1]) * glow * 0.6, col[2] + (0.6 - col[2]) * glow * 0.6, col[3], 1)
        local hw = (KILN_W / 2 - KILN_WALL) * (0.5 + 0.45 * f)
        love.graphics.ellipse('fill', KILN_X, base - KILN_WALL, hw, 30 + 110 * f)
    end
    -- walls and floor: bricks
    local function brickWall(x, y, w, h)
        local bc = BRICK_COLORS[1]
        love.graphics.setColor(bc[1], bc[2], bc[3], 1)
        love.graphics.rectangle('fill', x, y, w, h, 6, 6)
        love.graphics.setColor(0.42, 0.2, 0.13, 1)
        love.graphics.setLineWidth(3)
        local row = 0
        for yy = y + 45, y + h - 5, 45 do
            love.graphics.line(x + 4, yy, x + w - 4, yy)
            row = row + 1
        end
        row = 0
        for yy = y, y + h - 45, 45 do
            local off = (row % 2) * 45
            for xx = x + 45 + off, x + w - 10, 90 do
                love.graphics.line(xx, yy + 4, xx, math.min(y + h, yy + 41))
            end
            row = row + 1
        end
        love.graphics.setColor(0.25, 0.12, 0.08, 1)
        love.graphics.setLineWidth(5)
        love.graphics.rectangle('line', x, y, w, h, 6, 6)
    end
    brickWall(x0, top, KILN_WALL, KILN_H)
    brickWall(x0 + KILN_W - KILN_WALL, top, KILN_WALL, KILN_H)
    brickWall(x0, base - KILN_WALL, KILN_W, KILN_WALL)
    -- the fire door in the floor's front, flames licking
    love.graphics.setColor(0.12, 0.06, 0.04, 1)
    love.graphics.arc('fill', KILN_X, base, 70, math.pi, math.pi * 2)
    for f = 0, 4 do
        local fx = KILN_X - 44 + f * 22
        local fh = (28 + 22 * heat) * (0.7 + 0.3 * math.sin(t * 13 + f * 1.7))
        love.graphics.setColor(1, 0.55 + 0.3 * heat, 0.15, 0.9)
        love.graphics.polygon('fill', fx - 11, base, fx + 11, base, fx + math.sin(t * 9 + f) * 5, base - fh)
    end
    -- a baking brick shows as a glow over the rim
    if k.bakeAt then
        love.graphics.setColor(1, 0.6, 0.2, 0.25 + 0.2 * math.sin(t * 10))
        love.graphics.circle('fill', KILN_X, top + 40, 90 + 30 * baking)
    end
    love.graphics.setLineWidth(1)
end

---------------------------------------------------------------- hooks

local function clearClumps()
    local list = st().clumps
    for i = #list, 1, -1 do removeClump(list, i) end
end

function s.onStart()
    worldState.paused = false
    local c = st()
    earth = loadEarth()
    if not c.panelFolded then -- the burrow's big panel folded at first
        state.scriptPanels = state.scriptPanels or {}
        state.scriptPanels['•• burrow ••'] = true
        c.panelFolded = true
    end
    if c.gridId ~= GRID_ID then
        -- an earth made on another grid: its chunks, rocks and Mipos go, a new landscape is made
        local old = field()
        if old then
            earth.onUnload()
            for _, inst in ipairs(old.mipos or {}) do
                for _, part in pairs(inst.parts or {}) do
                    if part.body and not part.body:isDestroyed() then objectManager.destroyBody(part.body) end
                end
            end
            state.diglive = nil
        end
        c.loose, c.settleBox, c.scoopSized, c.gridId = {}, nil, nil, GRID_ID
        destroyKiln(c)
        c.kiln = nil
        destroyPieces(c)
        local list = c.clumps
        for i = #list, 1, -1 do
            local p = table.remove(list, i)
            if p.body and not p.body:isDestroyed() then objectManager.destroyBody(p.body) end
        end
    end
    local b = field()
    if b and b.rocks and #b.rocks > 0 then -- rocks from before they were taken out: gone
        for _, rock in ipairs(b.rocks) do
            if rock.body and not rock.body:isDestroyed() then objectManager.destroyBody(rock.body) end
        end
        b.rocks = {}
    end
    earth.onStart()
    if c.matId ~= MAT_ID then layOutMaterials(c) end
    forgetMaterialPicture()
    placeKiln(c)
    if not c.scoopSized then -- the burrow's brush is the scoop: smaller than its digging brush
        field().brush = 160
        c.scoopSized = true
    end
    c.pending, c.pendingKeys, c.region, c.pour = {}, {}, nil, nil
    c.scoop = { carried = 0 }
    for _, beam in ipairs(c.beams or {}) do -- the planks from before: gone
        if beam.body and not beam.body:isDestroyed() then objectManager.destroyBody(beam.body) end
    end
    c.beams = nil
    if c.finds and c.findsKind ~= FINDS_KIND then destroyPieces(c) end -- Fabuland's parts from before: gone
    state.fabuland = nil
    if not c.finds then
        placePieces(c)
    else
        for _, find in ipairs(c.finds) do
            if not find.body or find.body:isDestroyed() then makePieceBody(find) end
        end
    end
    for _, inst in ipairs(mipos()) do inst._dl = nil end
    ensureSounds()
    ensureKilnSounds()
end

function s.onUnload()
    for _, inst in ipairs(mipos()) do stopAnswering(inst) end
    if earth then earth.onUnload() end
    clearClumps()
    destroyPieces(st(), true) -- remade where they are at the next start
    destroyKiln(st())
end

-- touching earth: a point just outside its outline, all round, in earth
local function againstEarth(find)
    local body = find.body
    local hw, hh = find.w / 2 + 25, find.h / 2 + 25
    for k = 0, 5 do
        local t = (k + 0.5) / 6
        for _, q in ipairs({ { -hw + 2 * hw * t, -hh }, { -hw + 2 * hw * t, hh }, { -hw, -hh + 2 * hh * t },
            { hw, -hh + 2 * hh * t } }) do
            if earth.earthAt(body:getWorldPoint(q[1], q[2])) > 0.5 then return true end
        end
    end
    return false
end

local function findOfBody(body)
    for _, find in ipairs(st().finds or {}) do
        if find.body == body then return find end
    end
end

function s.onReleased(things)
    for _, thing in ipairs(things or {}) do
        local find = thing and thing.body and findOfBody(thing.body)
        if find and find.free and not find.stuck and againstEarth(find) then
            find.stuck = true
            local body = find.body
            body:setType('kinematic')
            body:setLinearVelocity(0, 0)
            body:setAngularVelocity(0)
            play('thud', 1.4, 0.7)
            crumbs(body:getX(), body:getY(), 4, 0.3)
        end
    end
end

function s.onPressed(things)
    for _, thing in ipairs(things or {}) do
        local find = thing and thing.body and findOfBody(thing.body)
        if find and find.stuck then
            find.stuck = nil
            local body = find.body
            body:setType('dynamic')
            body:setAwake(true)
            local wx, wy = mouseWorldPos()
            pointerGrab('mouse', body, wx, wy)
            return
        end
    end
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local c = st()
    if key == 'h' then
        c.showPanel = not c.showPanel
    else
        if key == 'r' then
            clearClumps()
            c.pending, c.pendingKeys, c.region, c.pour = {}, {}, nil, nil
            c.scoop = { carried = 0 }
            c.loose, c.settleBox = {}, nil
        end
        if earth then earth.onKeyPress(key) end
        if key == 'r' then -- after the burrow's reset: new parts in the new earth, laid out anew, the kiln again
            destroyPieces(c)
            placePieces(c)
            c.matSeed = (c.matSeed or 0) + 1
            layOutMaterials(c)
            forgetMaterialPicture()
            destroyKiln(c)
            c.kiln = nil
            placeKiln(c)
        end
    end
end

local function puffsUpdate(c, dt)
    for i = #c.puffs, 1, -1 do
        local p = c.puffs[i]
        p.t = p.t + dt
        if p.t > 0.3 then table.remove(c.puffs, i) end
    end
end

-- NaN repair (2026-11-17): now and then a beam lying still against the earth comes out of a Box2D step as NaN
-- (burrow 2026-11-12 too; nothing dug, poured or moved there that frame, and replaying the pose alone in plain LOVE
-- doesn't do it, so it's Box2D's carried-over contact state). Contacts spread it to everything touching. The first
-- frame any body has a NaN place or speed: a clump goes (loose dirt), everything else goes back to where it was the
-- frame before, still; non-Mipos are switched off and on, which drops their contacts (a contact keeps its NaN push
-- and hands it back next step; never a Mipo part, see the reach spike). Printed, so it can be counted. Repairs
-- coming faster than one a second, three times running: the world pauses instead, to look at over the bridge.
local function badNumber(b)
    local x, y = b:getPosition()
    local vx, vy = b:getLinearVelocity()
    local a, w = b:getAngle(), b:getAngularVelocity()
    return x ~= x or y ~= y or vx ~= vx or vy ~= vy or a ~= a or w ~= w
end

local function nanRepair(c, now)
    if state.world.paused then return end
    local snap = c.nanSnap or {}
    local fixed, dropped, lost = {}, 0, 0
    for _, b in ipairs(state.physicsWorld:getBodies()) do
        if badNumber(b) then
            local ud = b:getUserData()
            local inst, part = mipoRegistry.getFromBody(b)
            local label = inst and ('mipo ' .. tostring(part)) or (ud and ud.thing and ud.thing.label)
                or (ud and ud.burrowChunk and 'earth') or '?'
            local p = snap[b]
            if ud and ud.burrowChunk then
                -- an earth chunk: a NaN body's push reaches it through a contact (0 mass x NaN is NaN), and put
                -- back it went NaN again every step, the contact keeping its NaN (2026-11-19, the world paused
                -- twice): its body goes, contacts and all, and the burrow builds it again
                b:destroy()
                field().dirty[ud.burrowChunk - 1] = true
                fixed[#fixed + 1] = 'earth (rebuilt)'
            elseif label == 'clump' then
                objectManager.destroyBody(b)
                dropped = dropped + 1
            elseif p then
                b:setPosition(p[1], p[2])
                b:setAngle(p[3])
                b:setLinearVelocity(0, 0)
                b:setAngularVelocity(0)
                if not inst then
                    b:setActive(false)
                    b:setActive(true)
                end
                fixed[#fixed + 1] = label
            else
                lost = lost + 1
            end
        end
    end
    if #fixed + dropped + lost == 0 then return end
    print(string.format('[diglive] NaN repaired: %d put back (%s), %d clumps dropped, %d unknown', #fixed,
        table.concat(fixed, ', ', 1, math.min(#fixed, 12)), dropped, lost))
    c.nanFast = (now - (c.nanLastAt or -10) < 1) and (c.nanFast or 0) + 1 or 0
    c.nanLastAt = now
    if c.nanFast >= 3 then
        state.world.paused = true
        print('[diglive] NaN keeps coming back: world paused')
    end
end

-- every body's place and speed, kept at the end of the script's update (the world steps next)
local function nanSnapshot(c)
    local snap = {}
    for _, b in ipairs(state.physicsWorld:getBodies()) do
        if not badNumber(b) then
            local x, y = b:getPosition()
            snap[b] = { x, y, b:getAngle() }
        end
    end
    c.nanSnap = snap
end

function s.update(dt)
    if not earth then return end
    local c = st()
    local now = love.timer.getTime()
    nanRepair(c, now)
    ensureSounds()
    scoopTick(c, dt, now)
    pourTick(c)
    if c.crumble then crumbleTick(c, dt, now) else c.region = nil end
    earth.update(dt) -- rebuilds what the scoop, the crumbles and the settled clumps changed
    clumpsUpdate(dt)
    kilnUpdate(c, dt, now)
    piecesUpdate(c, now)
    for _, inst in ipairs(mipos()) do answerTick(inst, now) end
    puffsUpdate(c, dt)
    nanSnapshot(c)
    for i = #c.crumbs, 1, -1 do
        local p = c.crumbs[i]
        p.vy = p.vy + (p.chunk and 2600 or 1800) * dt
        p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        p.life = p.life - dt
        if p.life <= 0 then table.remove(c.crumbs, i) end
    end
end

function s.drawBelow()
    if earth then earth.drawBelow() end
end

local function drawClumpBody(body, color)
    for _, fixture in ipairs(body:getFixtures()) do
        local shape = fixture:getShape()
        if shape:getType() == 'polygon' then
            local pts = { body:getWorldPoints(shape:getPoints()) }
            love.graphics.setColor(color[1], color[2], color[3], 1)
            love.graphics.polygon('fill', pts)
            love.graphics.setColor(0.16, 0.1, 0.07, 0.85)
            love.graphics.setLineWidth(4)
            love.graphics.polygon('line', pts)
        end
    end
end

-- the lump of dirt on the finger: a heap of round bits, as big as what it carries, wobbling a little
local LUMP = {}
do
    local rng = love.math.newRandomGenerator(11)
    for k = 1, 24 do
        local a, d = rng:random() * math.pi * 2, math.sqrt(k / 24)
        LUMP[k] = { math.cos(a) * d, math.sin(a) * d * 0.8, 0.35 + rng:random() * 0.3, rng:random(1, #CLUMP_COLORS) }
    end
end

local function drawScoop(c)
    local sc = c.scoop
    if not (sc.active and state.playMode) then return end
    local r = scoopRadius()
    local fill = sc.carried / capacity(r)
    local full = fill >= 0.999
    -- the ring where it digs; a faint line back to the finger when it lags
    local mx, my = mouseWorldPos()
    if (mx - sc.x) ^ 2 + (my - sc.y) ^ 2 > (r * 0.5) ^ 2 then
        love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.setLineWidth(4)
        love.graphics.line(sc.x, sc.y, mx, my)
    end
    local kick = sc.kick or 0
    love.graphics.setColor(1, full and 0.75 or 1, full and 0.6 or 1, 0.55 + kick * 0.4)
    love.graphics.setLineWidth(5 + kick * 6)
    local press = sc.press
    if press and press.amount > 0 then
        -- squashed against the earth ahead, nudged into it
        local amount = press.amount
        love.graphics.push()
        love.graphics.translate(sc.x + press.ux * r * 0.12 * amount, sc.y + press.uy * r * 0.12 * amount)
        love.graphics.rotate(math.atan2(press.uy, press.ux))
        love.graphics.scale(1 - 0.2 * amount, 1 + 0.12 * amount)
        love.graphics.circle('line', 0, 0, r)
        love.graphics.pop()
    else
        love.graphics.circle('line', sc.x, sc.y, r * (1 + kick * 0.14))
    end
    if fill <= 0 then return end
    local size = r * (0.25 + 0.75 * math.sqrt(fill)) * (1 + kick * 0.1)
    local t = love.timer.getTime()
    local n = math.max(3, math.floor(#LUMP * math.sqrt(fill)))
    local load = sc.load or { 1, 0, 0 }
    local total = math.max(1e-6, load[1] + load[2] + load[3])
    for k = 1, n do
        local p = LUMP[k]
        local u, m = (k - 0.5) / n, SAND -- the bits shared out by what it carries
        if u < load[DIRT] / total then m = DIRT elseif u < (load[DIRT] + load[CLAY]) / total then m = CLAY end
        local colors = KINDS[m].colors
        local col = colors[(p[4] - 1) % #colors + 1]
        local wob = math.sin(t * 7 + k) * 0.04
        local x, y, br = sc.x + p[1] * size * (1 + wob), sc.y + p[2] * size, p[3] * size * 0.6
        love.graphics.setColor(0.16, 0.1, 0.07, 1)
        love.graphics.circle('fill', x, y, br + 4)
        love.graphics.setColor(col[1], col[2], col[3], 1)
        love.graphics.circle('fill', x, y, br)
    end
end

function s.draw()
    if not earth then return end
    earth.draw()
    local c = st()
    for _, p in ipairs(c.clumps) do
        if p.body and not p.body:isDestroyed() then drawClumpBody(p.body, p.color) end
    end
    love.graphics.setLineWidth(1)
    drawKiln(c)
    for _, p in ipairs(c.puffs) do -- dust (smoke from the kiln: grey)
        local u = p.t / 0.3
        local col = p.smoke and { 0.7, 0.68, 0.66 } or (p.kind and KINDS[p.kind].colors[1]) or { 0.55, 0.42, 0.3 }
        love.graphics.setColor(col[1], col[2], col[3], 0.35 * (1 - u))
        love.graphics.circle('fill', p.x, p.y, p.r * (0.7 + u * 0.9))
    end
    for _, p in ipairs(c.crumbs) do
        local a = math.min(1, p.life * 3)
        if p.chunk then
            love.graphics.setColor(0.16, 0.1, 0.07, a)
            love.graphics.circle('fill', p.x, p.y, p.r + 4)
        end
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], a)
        love.graphics.circle('fill', p.x, p.y, p.r)
    end
    drawPieces(c)
    drawScoop(c)
    -- not digging: the scoop's ring at the mouse
    if state.playMode and not c.scoop.active and not overPanel() then
        local mx, my = mouseWorldPos()
        love.graphics.setColor(1, 1, 1, 0.35)
        love.graphics.setLineWidth(4)
        love.graphics.circle('line', mx, my, scoopRadius())
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

---------------------------------------------------------------- the panel

local PANEL = { w = 300, row = 32, pad = 6 }

function s.drawUI()
    if state.playMode then ui.startFrame() end -- once a frame, for both panels
    if earth then earth.drawUI() end
    local c = st()
    panelRect = nil
    if not (c.showPanel and state.playMode) then return end
    local sw = love.graphics.getDimensions()
    local w, h = PANEL.w, PANEL.row * 9 + 34
    local x0, y0 = sw - w - 12, 12
    panelRect = { x0, y0, w, h }
    ui.panel(x0, y0, w, h, '•• dig live ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = 0, startX = x0 + PANEL.pad, startY = y0 + 28 })
        local function row() return ui.nextLayoutPosition(layout, w - PANEL.pad * 2, PANEL.row) end
        local x, y = row()
        local changed, v = ui.checkbox(x, y, c.come, 'Mipos come to the finger')
        if changed then c.come = v end
        x, y = row()
        changed, v = ui.checkbox(x, y, c.crumble, 'the earth crumbles')
        if changed then c.crumble = v end
        x, y = row()
        local size = ui.sliderWithInput('diglivesize', x, y, 150, 60, 400, field() and field().brush or 160, nil, 1)
        if size and field() then field().brush = size end
        ui.label(x + 248, y + 4, 'size')
        for _, r in ipairs({ { 'scoopBites', 1, 30, 1, 'holds' }, { 'resist', 0.3, 3, nil, 'hard' },
            { 'settle', 0.2, 5, nil, 'settle' }, { 'thin', 1, 5, 1, 'thin' }, { 'shake', 0.1, 2, nil, 'shake' } }) do
            x, y = row()
            local val = ui.sliderWithInput('diglive' .. r[1], x, y, 150, r[2], r[3], c[r[1]], nil, r[4])
            if val then c[r[1]] = val + 0 end
            ui.label(x + 248, y + 4, r[5])
        end
        x, y = row()
        ui.label(x, y + 4, 'm Mipo  r reset  [ ] size  h panel')
    end)
end

return s

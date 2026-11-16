-- sand: a falling-sand spike — sand, water, oil, stone, wood, fire, lava, smoke and steam as cells, with Mipos in it.
-- A powder toy (the dreamengine sand cart, ~/Projects/dreamengine/tools/carts/sand.c, grown): every cell is one
-- material and makes one small local move a frame. Sand falls and piles, liquids find their level (oil floats on
-- water), fire climbs and spreads to wood and oil, water puts it out as steam, lava turns to stone in water.
--
-- The Mipos are in it through the physics: every cell a body covers counts as submerged in what's in it, and
-- that gives the body a lift (by the material's weight) and a drag. So Mipos float in water, sink a bit into
-- sand and stand on stone. Cells a body covers that are empty can't be moved into, so sand piles up on a head.
-- Inside a Mipo's outline the cells are drawn again over it (sand nearly solid, water see-through): buried, wet.
--
-- play mode (tab): drag on the empty to paint (grab a Mipo to carry it). The panel picks the material.
-- keys: 1-9 material   [ ] brush   m: a Mipo at the mouse   r: reset   c: clear   space: pause the sand

local s = {}

local W, H, CELL = 300, 170, 16     -- cells; world units per cell (a Mipo is ~40 cells tall)
local X0, Y0 = -W * CELL / 2, -H * CELL
local X1, Y1 = X0 + W * CELL, Y0 + H * CELL
local CH = 16                       -- chunk side, in cells: a chunk where nothing moved sleeps
local CW, CHH = math.ceil(W / CH), math.ceil(H / CH)
local N = W * H

-- materials
local EMPTY, SAND, WATER, OIL, STONE, WOOD, FIRE, LAVA, SMOKE, STEAM, BURNING, ASH = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
local STATIC, POWDER, LIQUID, GAS, FLAME = 0, 1, 2, 3, 4
local KIND = { [SAND] = POWDER, [WATER] = LIQUID, [OIL] = LIQUID, [STONE] = STATIC, [WOOD] = STATIC, [FIRE] = FLAME,
    [LAVA] = LIQUID, [SMOKE] = GAS, [STEAM] = GAS, [BURNING] = STATIC, [ASH] = POWDER }
-- how heavy a grain is against the liquids and gases it can sink through
local DENS = { [SAND] = 5, [WATER] = 3, [OIL] = 2, [STONE] = 9, [WOOD] = 9, [FIRE] = 0.1, [LAVA] = 4, [SMOKE] = 0.2,
    [STEAM] = 0.1, [BURNING] = 9, [ASH] = 2.5 }
local DISPERSE = { [WATER] = 6, [OIL] = 4, [LAVA] = 1 } -- how far a liquid looks sideways a frame
local FLAMMABLE = { [OIL] = 0.25, [WOOD] = 0.02 }       -- chance a fire next to it lights it, a frame
-- colours: base and how much a grain's shade varies it
local COLOR = {
    [SAND] = { 0.87, 0.74, 0.47, 0.10 }, [WATER] = { 0.27, 0.55, 0.85, 0.05 }, [OIL] = { 0.36, 0.25, 0.16, 0.05 },
    [STONE] = { 0.47, 0.46, 0.48, 0.12 }, [WOOD] = { 0.55, 0.37, 0.20, 0.12 }, [LAVA] = { 0.95, 0.38, 0.10, 0.15 },
    [SMOKE] = { 0.35, 0.34, 0.36, 0.10 }, [STEAM] = { 0.90, 0.92, 0.96, 0.05 }, [BURNING] = { 0.75, 0.30, 0.10, 0.20 },
    [ASH] = { 0.62, 0.60, 0.58, 0.10 },
}
local ALPHA = { [SMOKE] = 0.55, [STEAM] = 0.45, [WATER] = 0.85, [OIL] = 0.92 }       -- behind the bodies
local FRONT = { [SAND] = 0.93, [WATER] = 0.45, [OIL] = 0.65, [STONE] = 1, [WOOD] = 1, [FIRE] = 0.75, [LAVA] = 0.95,
    [SMOKE] = 0.3, [STEAM] = 0.25, [BURNING] = 0.9, [ASH] = 0.9 }                     -- over them, in their outline

-- for the bodies: the weight of what they're in (a Mipo part's density is ~1) and how thick it is
local tune = { water = 1.3, oil = 1.1, sand = 2.2, solid = 6, drag = 1, speed = 1 }
local function rhoOf(m)
    if m == WATER then return tune.water elseif m == OIL then return tune.oil
    elseif m == SAND or m == ASH then return tune.sand
    elseif m == STONE or m == WOOD or m == BURNING then return tune.solid
    elseif m == LAVA then return tune.sand end
    return 0
end
local DRAG = { [WATER] = 1.5, [OIL] = 3, [SAND] = 6, [ASH] = 5, [STONE] = 12, [WOOD] = 12, [BURNING] = 12, [LAVA] = 8 }

-- the brush's materials, in panel order (keys 1-9)
local PALETTE = {
    { SAND, 'sand' }, { WATER, 'water' }, { OIL, 'oil' }, { STONE, 'stone' }, { WOOD, 'wood' },
    { FIRE, 'fire' }, { LAVA, 'lava' }, { STEAM, 'steam' }, { EMPTY, 'eraser' },
}

local floor, random = math.floor, love.math.random

-- The grid lives on state, so a reload of this script keeps it.
local g
local function grid()
    local sd = state.sand
    if not sd then
        sd = { brush = 120, pick = SAND, mipos = {}, running = true }
        state.sand = sd
    end
    return sd
end

local mat, shade, life, moved, block, owner, changed, nchanged, awake, nextAwake
local F = 0 -- the frame stamp: a cell moved this frame isn't moved again
local ownerStamp = 0

local repaintAll
-- The module's locals onto the grid on state: once after a (re)load, then every update (cheap).
local function bind(sd)
    local fresh = g ~= sd
    mat, shade, life, moved, block, owner = sd.mat, sd.shade, sd.life, sd.moved, sd.block, sd.owner
    awake, nextAwake = sd.awake, sd.nextAwake
    changed = sd.changed
    ownerStamp = sd.ownerStamp or 0
    g = sd
    if fresh then
        nchanged = 0
        if sd.back then repaintAll() end -- after a hot reload: marks made before it are lost
    end
end

local function wakeAt(x, y)
    local cx, cy = floor(x / CH), floor(y / CH)
    local k = cy * CW + cx + 1
    nextAwake[k] = true
    local lx, ly = x - cx * CH, y - cy * CH
    if lx == 0 and cx > 0 then nextAwake[k - 1] = true elseif lx == CH - 1 and cx < CW - 1 then nextAwake[k + 1] = true end
    if ly == 0 and cy > 0 then nextAwake[k - CW] = true elseif ly == CH - 1 and cy < CHH - 1 then nextAwake[k + CW] = true end
end

local function mark(i)
    if changed.stamp[i] ~= F then
        changed.stamp[i] = F
        nchanged = nchanged + 1
        changed[nchanged] = i
    end
end

local function set(i, m, l)
    mat[i] = m
    shade[i] = random()
    life[i] = l or 0
    moved[i] = F
    mark(i)
    local i0 = i - 1
    wakeAt(i0 % W, floor(i0 / W))
end

local function swap(i, j)
    mat[i], mat[j] = mat[j], mat[i]
    shade[i], shade[j] = shade[j], shade[i]
    life[i], life[j] = life[j], life[i]
    moved[i], moved[j] = F, F
    mark(i)
    mark(j)
    local i0, j0 = i - 1, j - 1
    wakeAt(i0 % W, floor(i0 / W))
    wakeAt(j0 % W, floor(j0 / W))
end

-- Can a grain of m go into cell t? An empty cell (not covered by a body), or a lighter liquid or gas.
local function canEnter(t, m)
    local o = mat[t]
    if o == EMPTY then return block[t] ~= F end
    local k = KIND[o]
    return (k == LIQUID or k == GAS or k == FLAME) and DENS[o] < DENS[m]
end

-- powders and liquids: down, then a diagonal down, then (liquids) sideways to find the level
local function fall(i, x, y, m, k)
    if y < H - 1 then
        local b = i + W
        if canEnter(b, m) then swap(i, b) return end
        local l = x > 0 and canEnter(b - 1, m)
        local r = x < W - 1 and canEnter(b + 1, m)
        if l and r then
            if random() < 0.5 then swap(i, b - 1) else swap(i, b + 1) end
            return
        elseif l then swap(i, b - 1) return
        elseif r then swap(i, b + 1) return end
    end
    if k == LIQUID then
        local reach = DISPERSE[m]
        if m == LAVA and random() < 0.6 then return end -- thick
        local dir = random() < 0.5 and -1 or 1
        for _ = 1, 2 do
            local best, xx = nil, x
            for _ = 1, reach do
                xx = xx + dir
                if xx < 0 or xx >= W then break end
                local t = i + (xx - x)
                if not canEnter(t, m) then break end
                best = t
                -- step down off a ledge as soon as there is one
                if y < H - 1 and canEnter(t + W, m) then break end
            end
            if best then swap(i, best) return end
            dir = -dir
        end
    end
end

-- gases and fire: up, a diagonal up, or sideways, a bit at random
local function rise(i, x, y, m)
    if y > 0 then
        local a = i - W
        local d = random(-1, 1)
        if x + d >= 0 and x + d < W and canEnter(a + d, m) then swap(i, a + d) return end
        if canEnter(a, m) then swap(i, a) return end
    end
    local d = random() < 0.5 and -1 or 1
    if x + d >= 0 and x + d < W and canEnter(i + d, m) then swap(i, i + d) end
end

local function neighbour(i, x, y, n)
    if n == 1 then return y > 0 and i - W or nil
    elseif n == 2 then return y < H - 1 and i + W or nil
    elseif n == 3 then return x > 0 and i - 1 or nil
    else return x < W - 1 and i + 1 or nil end
end

-- fire, burning wood and lava act on their four neighbours
local function heat(i, x, y, m)
    for n = 1, 4 do
        local t = neighbour(i, x, y, n)
        if t then
            local o = mat[t]
            if o == WATER then
                if m == LAVA then
                    set(i, STONE)
                    set(t, STEAM, 120 + random(120))
                    return true
                end
                set(t, STEAM, 120 + random(120))
                if m == FIRE then set(i, EMPTY) return true end
                if m == BURNING then set(i, WOOD) return true end
            elseif FLAMMABLE[o] and random() < FLAMMABLE[o] * (m == LAVA and 0.3 or 1) then
                if o == WOOD then set(t, BURNING, 150 + random(250)) else set(t, FIRE, 25 + random(35)) end
            end
        end
    end
    return false
end

local function updateCell(i, x, y, m, k)
    if k == POWDER or k == LIQUID then
        if m == LAVA and heat(i, x, y, m) then return end
        fall(i, x, y, m, k)
    elseif k == GAS then
        local l = life[i] - 1
        if l <= 0 or (y == 0 and random() < 0.05) then
            if m == STEAM and random() < 0.35 then set(i, WATER) else set(i, EMPTY) end
            return
        end
        life[i] = l
        if m == SMOKE and l % 8 == 0 then mark(i) end
        if random() < 0.8 then rise(i, x, y, m) end
        local i0 = i - 1
        wakeAt(i0 % W, floor(i0 / W))
    elseif k == FLAME then
        if heat(i, x, y, m) then return end
        local l = life[i] - 1
        if l <= 0 then
            if random() < 0.3 then set(i, SMOKE, 60 + random(90)) else set(i, EMPTY) end
            return
        end
        life[i] = l
        mark(i)
        if random() < 0.7 then rise(i, x, y, m) end
        local i0 = i - 1
        wakeAt(i0 % W, floor(i0 / W))
    elseif m == BURNING then
        if heat(i, x, y, m) then return end
        local l = life[i] - 1
        if l <= 0 then
            if random() < 0.4 then set(i, ASH) else set(i, SMOKE, 60 + random(60)) end
            return
        end
        life[i] = l
        if l % 4 == 0 then mark(i) end
        if y > 0 and mat[i - W] == EMPTY and block[i - W] ~= F and random() < 0.15 then
            set(i - W, FIRE, 15 + random(25))
        end
        local i0 = i - 1
        wakeAt(i0 % W, floor(i0 / W))
    end
end

local function step()
    F = F + 1
    g.F = F
    awake, nextAwake = nextAwake, awake
    g.awake, g.nextAwake = awake, nextAwake
    for k = 1, CW * CHH do nextAwake[k] = false end
    for y = H - 1, 0, -1 do
        local crow = floor(y / CH) * CW
        local ltr = (y + F) % 2 == 0
        local base = y * W + 1
        for c = 0, CW - 1 do
            local cx = ltr and c or (CW - 1 - c)
            if awake[crow + cx + 1] then
                local xa, xb, dir = cx * CH, math.min(W - 1, cx * CH + CH - 1), 1
                if not ltr then xa, xb, dir = xb, xa, -1 end
                for x = xa, xb, dir do
                    local i = base + x
                    local m = mat[i]
                    if m ~= EMPTY and moved[i] ~= F then
                        local k = KIND[m]
                        if k ~= STATIC or m == BURNING then updateCell(i, x, y, m, k) end
                    end
                end
            end
        end
    end
end

-- The pictures: one cell a pixel, behind the bodies and (masked to their outlines) over them.
local function colourOf(i)
    local m = mat[i]
    if m == EMPTY then return 0, 0, 0, 0, 0 end
    local sh = shade[i] - 0.5
    local r, gg, b, a
    if m == FIRE then
        local t = math.min(1, life[i] / 40)
        r, gg, b, a = 1, 0.35 + 0.55 * t + sh * 0.2, 0.1 + 0.3 * t * t, 0.95
    else
        local c = COLOR[m]
        local v = c[4] * sh * 2
        r, gg, b, a = c[1] + v, c[2] + v, c[3] + v, ALPHA[m] or 1
        if m == SMOKE then a = a * math.min(1, life[i] / 60)
        elseif m == STEAM then a = a * math.min(1, life[i] / 80)
        elseif m == BURNING and random() < 0.5 then r, gg = 1, 0.5 + sh end
    end
    return r, gg, b, a, FRONT[m] or 1
end

local function repaint(i)
    local i0 = i - 1
    local x, y = i0 % W, floor(i0 / W)
    local r, gg, b, a, fa = colourOf(i)
    g.backData:setPixel(x, y, r, gg, b, a)
    g.frontData:setPixel(x, y, r, gg, b, a > 0 and fa or 0)
end

function repaintAll()
    for i = 1, N do repaint(i) end
    g.back:replacePixels(g.backData)
    g.front:replacePixels(g.frontData)
    nchanged = 0
end

local function flush()
    for n = 1, nchanged do repaint(changed[n]) end
    if nchanged > 0 then
        g.back:replacePixels(g.backData)
        g.front:replacePixels(g.frontData)
    end
    nchanged = 0
end

local function cellAt(wx, wy)
    return floor((wx - X0) / CELL), floor((wy - Y0) / CELL)
end

local function fill(x1, y1, x2, y2, m)
    for y = math.max(0, y1), math.min(H - 1, y2) do
        for x = math.max(0, x1), math.min(W - 1, x2) do set(y * W + x + 1, m) end
    end
end

-- The landscape at the start: a stone floor and two ledges, a heap of sand, a pond, a woodpile with oil.
local function landscape()
    for i = 1, N do
        mat[i], shade[i], life[i] = EMPTY, random(), 0
        mark(i)
    end
    fill(0, H - 4, W - 1, H - 1, STONE)
    for x = 20, 110 do fill(x, 110 - floor((x - 20) / 6), x, 111 - floor((x - 20) / 6), STONE) end
    for x = 190, 280 do fill(x, 80 + floor((x - 190) / 8), x, 81 + floor((x - 190) / 8), STONE) end
    fill(150, H - 56, 152, H - 5, STONE)       -- the pond's wall (deeper than a Mipo is tall)
    fill(153, H - 52, 236, H - 5, WATER)       -- the pond
    fill(40, 60, 80, 96, SAND)                 -- a heap on the left ledge, still to fall
    fill(60, H - 14, 110, H - 5, SAND)         -- a beach
    fill(250, H - 20, 280, H - 5, WOOD)        -- a woodpile
    fill(240, 40, 262, 60, OIL)                -- oil to pour over it
    for k = 1, CW * CHH do awake[k], nextAwake[k] = true, true end
end

local function newGrid(sd)
    sd.mat, sd.shade, sd.life, sd.moved, sd.block, sd.owner = {}, {}, {}, {}, {}, {}
    sd.changed = { stamp = {} }
    sd.awake, sd.nextAwake = {}, {}
    for i = 1, N do sd.moved[i], sd.block[i], sd.owner[i], sd.changed.stamp[i] = 0, 0, 0, -1 end
    sd.backData = love.image.newImageData(W, H)
    sd.frontData = love.image.newImageData(W, H)
    sd.back = love.graphics.newImage(sd.backData)
    sd.front = love.graphics.newImage(sd.frontData)
    sd.back:setFilter('nearest', 'nearest')
    sd.front:setFilter('nearest', 'nearest')
    sd.mask = love.graphics.newCanvas(W * 2, H * 2)
    F = sd.F or 0
    g = sd -- not fresh: there is nothing to repaint yet, landscape() marks every cell
    nchanged = 0
    bind(sd)
    landscape()
    flush()
end

-- The bodies: which cells they cover (those can't be moved into while empty), what they're in, and the lift
-- and drag that gives them, as impulses (the script's update runs after the physics steps).
local function bodiesInSand(dt)
    local meter = love.physics.getMeter()
    local _, gy = world:getGravity()
    local cellM2 = CELL * CELL / (meter * meter)
    for _, body in ipairs(world:getBodies()) do
        local kind = body:getType()
        if kind ~= 'static' and not body:isDestroyed() then
            local bx, by = body:getPosition()
            if bx > X0 - 800 and bx < X1 + 800 and by > Y0 - 800 and by < Y1 + 800 then
                ownerStamp = ownerStamp + 1
                g.ownerStamp = ownerStamp
                local n, sub, lift, lx, ly, drag = 0, 0, 0, 0, 0, 0
                local moving = body:isAwake()
                for _, fixture in ipairs(body:getFixtures()) do
                    if not fixture:isSensor() then
                        local ax, ay, bx2, by2 = fixture:getBoundingBox()
                        local cx1, cy1 = cellAt(ax, ay)
                        local cx2, cy2 = cellAt(bx2, by2)
                        cx1, cy1 = math.max(0, cx1), math.max(0, cy1)
                        cx2, cy2 = math.min(W - 1, cx2), math.min(H - 1, cy2)
                        for y = cy1, cy2 do
                            local wy = Y0 + (y + 0.5) * CELL
                            for x = cx1, cx2 do
                                local i = y * W + x + 1
                                if owner[i] ~= ownerStamp then
                                    local wx = X0 + (x + 0.5) * CELL
                                    if fixture:testPoint(wx, wy) then
                                        owner[i] = ownerStamp
                                        block[i] = F + 1 -- for the step that comes next
                                        n = n + 1
                                        if moving then wakeAt(x, y) end
                                        local m = mat[i]
                                        local r = rhoOf(m)
                                        if r > 0 then
                                            sub = sub + 1
                                            lift = lift + r
                                            lx, ly = lx + wx * r, ly + wy * r
                                            drag = drag + DRAG[m]
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                if sub > 0 and kind == 'dynamic' then
                    local up = lift * cellM2 * gy * dt
                    body:applyLinearImpulse(0, -up, lx / lift, ly / lift)
                    local f = math.min(1, (drag / sub) * (sub / n) * tune.drag * dt)
                    local vx, vy = body:getLinearVelocity()
                    local mass = body:getMass()
                    body:applyLinearImpulse(-vx * mass * f, -vy * mass * f)
                    body:setAngularVelocity(body:getAngularVelocity() * (1 - f))
                end
            end
        end
    end
end

local function paint(wx, wy, m)
    local cx, cy = cellAt(wx, wy)
    local r = math.max(1, floor(g.brush / CELL))
    for y = cy - r, cy + r do
        for x = cx - r, cx + r do
            if x >= 0 and x < W and y >= 0 and y < H and (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r then
                local i = y * W + x + 1
                local o = mat[i]
                if m == EMPTY then
                    if o ~= EMPTY then set(i, EMPTY) end
                elseif m == STONE or m == WOOD then
                    if o ~= m then set(i, m) end
                elseif m == FIRE then
                    if FLAMMABLE[o] then set(i, o == WOOD and BURNING or FIRE, 150 + random(150))
                    elseif o == EMPTY and random() < 0.3 then set(i, FIRE, 20 + random(40)) end
                elseif o == EMPTY and block[i] ~= F + 1 and random() < 0.35 then
                    set(i, m, (m == STEAM or m == SMOKE) and 150 + random(150) or 0)
                end
            end
        end
    end
end

-- From the bridge: s.paintAt(wx, wy, 'fire'[, brush]) — one dab of a palette material.
function s.paintAt(wx, wy, name, brush)
    local sd = grid()
    for _, entry in ipairs(PALETTE) do
        if entry[2] == name then
            local was = sd.brush
            sd.brush = brush or was
            paint(wx, wy, entry[1])
            sd.brush = was
        end
    end
end

local function makeWalls(sd)
    if sd.walls and not sd.walls:isDestroyed() then return end
    sd.walls = love.physics.newBody(world, 0, 0, 'static')
    local top = Y0 - 1500
    local shape = love.physics.newChainShape(false, X0, top, X0, Y1, X1, Y1, X1, top)
    love.physics.newFixture(sd.walls, shape):setFriction(0.9)
end

local function resetMipos(sd)
    for _, inst in ipairs(mipoKit.alive(sd.mipos)) do
        for _, part in pairs(inst.parts) do
            if part.body and not part.body:isDestroyed() then objectManager.destroyBody(part.body) end
        end
    end
    sd.mipos = {}
    mipoKit.spawn(sd.mipos, X0 + 85 * CELL, Y1 - 900)   -- on the beach
    mipoKit.spawn(sd.mipos, X0 + 195 * CELL, Y1 - 1400) -- over the pond
end

function s.onStart()
    worldState.paused = false
    local sd = grid()
    if not sd.mat then newGrid(sd) else bind(sd); F = sd.F or 0 end
    makeWalls(sd)
    sd.mipos = mipoKit.alive(sd.mipos)
    if #sd.mipos == 0 then resetMipos(sd) end
    camera.setBounds(X0, Y0 - 1500, X1, Y1 + 200)
    camera.zoomTo(0.21, 0.5)
end

function s.onUnload()
    local sd = state.sand
    if sd and sd.walls and not sd.walls:isDestroyed() then sd.walls:destroy() end
    if sd then sd.walls = nil end
end

local function clearAll(sd)
    for i = 1, N do
        if mat[i] ~= EMPTY then set(i, EMPTY) end
    end
    fill(0, H - 4, W - 1, H - 1, STONE)
    flush()
    sd.running = true
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local sd = grid()
    local n = tonumber(key)
    if n and PALETTE[n] then sd.pick = PALETTE[n][1]
    elseif key == '[' then sd.brush = math.max(CELL, sd.brush - 30)
    elseif key == ']' then sd.brush = math.min(600, sd.brush + 30)
    elseif key == 'm' then
        local mx, my = mouseWorldPos()
        mipoKit.spawn(sd.mipos, mx, my)
    elseif key == 'r' then
        landscape(); flush(); resetMipos(sd)
    elseif key == 'c' then clearAll(sd)
    elseif key == 'space' then sd.running = not sd.running end
end

local panelRect = { 20, 0, 300, 0 }
local function overPanel()
    if ui.isPanelFolded('•• sand ••') then return false end
    local mx, my = love.mouse.getPosition()
    local r = panelRect
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

function s.update(dt)
    local sd = grid()
    if not sd.mat then return end
    bind(sd)
    F = sd.F or F
    local t0 = love.timer.getTime()
    bodiesInSand(dt)
    local down = state.playMode and love.mouse.isDown(1)
    if down and not sd.stroke and #getInteractedWithPointer() == 0 and not overPanel() then
        sd.stroke = true
        sd.lastX, sd.lastY = mouseWorldPos()
    elseif not down then
        sd.stroke = nil
    end
    if sd.stroke then
        local mx, my = mouseWorldPos()
        local dx, dy = mx - sd.lastX, my - sd.lastY
        local steps = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy) / math.max(CELL, sd.brush * 0.5)))
        for k = 1, steps do paint(sd.lastX + dx * k / steps, sd.lastY + dy * k / steps, sd.pick) end
        sd.lastX, sd.lastY = mx, my
    end
    if sd.running then
        for _ = 1, tune.speed do step() end
    end
    flush()
    sd.ms = (sd.ms or 0) * 0.9 + (love.timer.getTime() - t0) * 1000 * 0.1
end

local maskShader = love.graphics.newShader([[
    uniform Image mask;
    vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 sc) {
        vec4 p = Texel(tex, uv);
        return vec4(p.rgb, p.a * Texel(mask, uv).r) * colour;
    }
]])

function s.drawBelow()
    local sd = state.sand
    if not (sd and sd.back) then return end
    love.graphics.setColor(0.96, 0.93, 0.86, 1)
    love.graphics.rectangle('fill', X0, Y0, X1 - X0, Y1 - Y0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sd.back, X0, Y0, 0, CELL, CELL)
end

-- the outlines of the bodies in the sand, in the mask's cells (two a cell)
local function drawMask(sd)
    love.graphics.push('all')
    love.graphics.setCanvas(sd.mask)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.origin()
    love.graphics.scale(2 / CELL)
    love.graphics.translate(-X0, -Y0)
    love.graphics.setColor(1, 1, 1, 1)
    for _, body in ipairs(world:getBodies()) do
        if body:getType() ~= 'static' then
            for _, fixture in ipairs(body:getFixtures()) do
                if not fixture:isSensor() then
                    local shape = fixture:getShape()
                    local st = shape:getType()
                    if st == 'polygon' then
                        love.graphics.polygon('fill', body:getWorldPoints(shape:getPoints()))
                    elseif st == 'circle' then
                        local cx, cy = body:getWorldPoint(shape:getPoint())
                        love.graphics.circle('fill', cx, cy, shape:getRadius())
                    end
                end
            end
        end
    end
    love.graphics.pop()
end

function s.draw()
    local sd = state.sand
    if not (sd and sd.front) then return end
    drawMask(sd)
    love.graphics.setShader(maskShader)
    maskShader:send('mask', sd.mask)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sd.front, X0, Y0, 0, CELL, CELL)
    love.graphics.setShader()
    if state.playMode and not overPanel() then
        local mx, my = mouseWorldPos()
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.circle('line', mx, my, sd.brush)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function s.drawUI()
    local sd = state.sand
    if not (sd and state.playMode) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 300
    local rows = #PALETTE + 4
    local h = BH * rows + pad * (rows + 1) + 20
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    panelRect[2], panelRect[4] = y0, h
    ui.panel(x0, y0, w, h, '•• sand ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        for n, entry in ipairs(PALETTE) do
            local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local c = (entry[1] == STEAM and { 0.6, 0.66, 0.76 }) or COLOR[entry[1]]
                or (entry[1] == FIRE and { 1, 0.55, 0.15 }) or { 0.45, 0.45, 0.45 }
            local label = n .. '  ' .. entry[2] .. (sd.pick == entry[1] and '   <' or '')
            if ui.button(x, y, w - 20, label, BH, { c[1], c[2], c[3], 1 }) then sd.pick = entry[1] end
        end
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        local v = ui.sliderWithInput('sandbrush', x, y, 140, CELL, 600, sd.brush, nil, 1)
        if v then sd.brush = v end
        ui.label(x + 240, y, 'brush')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        v = ui.sliderWithInput('sanddrag', x, y, 140, 0, 4, tune.drag)
        if v then tune.drag = v + 0 end
        ui.label(x + 240, y, 'drag')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        v = ui.sliderWithInput('sandwater', x, y, 140, 0.5, 3, tune.water)
        if v then tune.water = v + 0 end
        ui.label(x + 240, y, 'water lift')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, string.format('m Mipo  r reset  c clear  %.1f ms', sd.ms or 0))
    end)
end

return s

-- paint-marks.lua: what wet mud and paint leave behind (scene `dirty`, docs/DIRT.md): prints and smears on
-- the floor where a wet part touches it (a foot stepping: footprints; a Mipo dragged along: a brush), and
-- drops falling off a part just out of a bath, splatting on the floor.
--
-- The floor is a strip canvas in the world, along the ground's top: a print goes where the part's lowest
-- point touches, as wide as the part, a little deeper or shallower in the strip per part (two feet side by
-- side). Printing takes paint off the part where it touched (a wipe pass below the floor line, dirt-look's
-- washing) and off the CPU copy, so prints fade out over the steps and a brush stroke runs dry.
-- Needs dirt-look.lua (lib.init(dirtLook)): its masks carry what's on each part.
local state = require('src.state')

local lib = {}

lib.tuning = {
    print = 0.6,      -- how much a print takes (alpha at full load)
    wipe = 0.22,      -- how much paint a print takes off the part's sole
    every = 14,       -- a new print every so many world px slid (a smear is many prints)
    dripRate = 12,    -- drops a second, just out of a bath
    dropSize = 9,     -- drop radius (world)
}

local dirtLook

function lib.init(look) dirtLook = look end

local function data()
    state.paintMarks = state.paintMarks or { drops = {}, touch = {} }
    return state.paintMarks
end
lib.data = data

-- ── the stamp: a soft blob with a ragged edge and speckles (white, tinted when drawn) ──
local stampImage
local function stampPicture()
    if stampImage then return stampImage end
    local w, h = 96, 48
    local img = love.image.newImageData(w, h)
    love.math.setRandomSeed(7)
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local u, v = (x + 0.5) / w * 2 - 1, (y + 0.5) / h * 2 - 1
            local ang = math.atan2(v, u)
            local edge = 0.82 + 0.12 * love.math.noise(math.cos(ang) * 1.7 + 3, math.sin(ang) * 1.7 + 5)
            local r = math.sqrt(u * u + v * v)
            local a = math.max(0, math.min(1, (edge - r) / 0.12))
            a = a * (0.75 + 0.25 * love.math.noise(x / 6, y / 6))
            if r < edge + 0.2 and love.math.random() < 0.04 then a = math.max(a, 0.8) end -- speckles
            img:setPixel(x, y, 1, 1, 1, a)
        end
    end
    stampImage = love.graphics.newImage(img)
    stampImage:setFilter('linear', 'linear')
    return stampImage
end

-- ── the floor ──
-- the floor strip: from x0 to x1 along y (the ground's top), depth deep, texel world px a texel
function lib.setFloor(x0, x1, y, depth, texel)
    local f = data().floor
    texel = texel or 2
    if f and f.x0 == x0 and f.x1 == x1 and f.y == y and f.depth == depth then return f end
    f = { x0 = x0, x1 = x1, y = y, depth = depth, texel = texel }
    f.canvas = love.graphics.newCanvas(math.ceil((x1 - x0) / texel), math.ceil(depth / texel), { dpiscale = 1 })
    f.canvas:setFilter('linear', 'linear')
    data().floor = f
    lib.clearFloor()
    return f
end

function lib.clearFloor()
    local f = data().floor
    if not f then return end
    love.graphics.push('all')
    love.graphics.setCanvas(f.canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.pop()
end

-- a blob on the floor at world x, yIn deep into the strip, w by h (world), coloured
local function stamp(x, yIn, w, h, r, g, b, a, angle)
    local f = data().floor
    if not f or x < f.x0 or x > f.x1 then return end
    local pic = stampPicture()
    love.graphics.push('all')
    love.graphics.origin()
    love.graphics.setCanvas(f.canvas)
    love.graphics.setShader()
    love.graphics.setBlendMode('alpha', 'alphamultiply')
    love.graphics.setColor(r, g, b, a)
    local pw, ph = pic:getDimensions()
    love.graphics.draw(pic, (x - f.x0) / f.texel, yIn / f.texel, angle or 0,
        w / pw / f.texel, h / ph / f.texel, pw / 2, ph / 2)
    love.graphics.pop()
end

-- a part's place in the strip's depth (by its mask's name: the same every time, two feet apart)
local function depthOf(key)
    local s = tostring(key)
    local hsh = 0
    for i = 1, #s do hsh = (hsh * 31 + s:byte(i)) % 1000003 end
    return (hsh % 1000) / 1000
end

-- a body's collision shapes' lowest point and how wide they are (world)
local function lowest(body)
    local lx, ly, minX, maxX = nil, -math.huge, math.huge, -math.huge
    for _, f in ipairs(body:getFixtures()) do
        if not f:isSensor() then
            local shape = f:getShape()
            if shape:getType() == 'circle' then
                local cx, cy = body:getWorldPoint(shape:getPoint())
                local r = shape:getRadius()
                if cy + r > ly then lx, ly = cx, cy + r end
                minX, maxX = math.min(minX, cx - r), math.max(maxX, cx + r)
            elseif shape.getPoints then
                local pts = { body:getWorldPoints(shape:getPoints()) }
                for i = 1, #pts, 2 do
                    if pts[i + 1] > ly then lx, ly = pts[i], pts[i + 1] end
                    minX, maxX = math.min(minX, pts[i]), math.max(maxX, pts[i])
                end
            end
        end
    end
    return lx, ly, maxX - minX
end

local function overBath(x, liquids)
    for _, w in ipairs(liquids) do
        if x > w.x1 - 20 and x < w.x2 + 20 then return true end
    end
    return false
end

local WATER = { 0.78, 0.9, 1.0 }

-- each part, after its baths (dirt-look's frame.onPart): drips, and prints where it touches the floor.
-- frame = dirt-look's frame (liquids, dt)
local seen = setmetatable({}, { __mode = 'k' })
function lib.onPart(d, draw, body, m, frame)
    local t = lib.tuning
    local dt = frame.dt or 1 / 60
    local dat = data()
    local f = dat.floor
    if seen[body] == frame.n then return end -- (one per body a frame: a leg's two strips are one sole)
    seen[body] = frame.n
    local lx, ly, width = lowest(body)
    if not lx then return end
    local r, g, b, load, paint = dirtLook.colorOf(m)
    -- drips: just out of a bath, fewer and fewer
    if m.dripT > 0 and not m.inBath and (m.dripKind == 'clean' or load > 0.03) then
        local share = m.dripT / 2.5
        if love.math.random() < t.dripRate * share * share * dt and #dat.drops < 400 then
            local vx, vy = body:getLinearVelocityFromWorldPoint(lx, ly)
            local water = m.dripKind == 'clean'
            dat.drops[#dat.drops + 1] = { x = lx + (love.math.random() - 0.5) * width * 0.6, y = ly,
                vx = vx * 0.6, vy = vy * 0.6, r = water and WATER[1] or r, g = water and WATER[2] or g,
                b = water and WATER[3] or b, water = water, size = t.dropSize * (0.6 + 0.6 * love.math.random()),
                paint = paint }
            if not water then dirtLook.cpuOff(m, 0.01) end
        end
    end
    -- prints: a wet, dirty sole on the floor
    if not f then return end
    local touch = dat.touch[m.key] or {}
    dat.touch[m.key] = touch
    local touching = ly >= f.y - 10 and lx > f.x0 and lx < f.x1 and not overBath(lx, frame.liquids)
    local wet = math.max(0, math.min(1, m.wetT / math.max(0.5, dirtLook.look.dry)))
    if touching and load > 0.03 and wet > 0.03 then
        local fresh = not touch.on or not touch.x
        if fresh or math.abs(lx - touch.x) >= t.every then
            local w = math.max(18, math.min(140, width * 1.15))
            local yIn = f.depth * (0.15 + 0.45 * depthOf(m.key))
            local a = t.print * math.min(1, load * 1.4) * (0.35 + 0.65 * wet) * (fresh and 1 or 0.7)
            stamp(lx, yIn, w, f.depth * 0.32, r, g, b, a, (love.math.random() - 0.5) * 0.15)
            -- the sole gives some up: wiped below the floor line, on the part and its CPU copy
            local uniforms = { mode = 0, level = f.y - 16, xRange = { -1e7, 1e7 }, wobble = 6 }
            for _, pass in ipairs(dirtLook.washPasses(t.wipe, false)) do
                dirtLook.paintPass(d, draw, m, pass, uniforms)
            end
            dirtLook.cpuOff(m, t.wipe * 0.6)
            touch.x = lx
        end
    end
    touch.on = touching
end

-- the drops: falling, into a bath (gone) or onto the floor (a splat)
function lib.update(dt, liquids)
    local dat = data()
    local f = dat.floor
    local drops = dat.drops
    local gravity = 9.8 * love.physics.getMeter()
    for i = #drops, 1, -1 do
        local p = drops[i]
        p.vy = p.vy + gravity * dt
        p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        local gone = false
        for _, w in ipairs(liquids) do
            if p.x > w.x1 and p.x < w.x2 and p.y > w.level then gone = true end
        end
        if not gone and f and p.y >= f.y then
            gone = true
            if not p.water then
                stamp(p.x, f.depth * (0.1 + 0.5 * love.math.random()), p.size * 2.6, p.size * 1.1,
                    p.r, p.g, p.b, 0.75)
            end
        end
        if gone or p.y > 1e5 then table.remove(drops, i) end
    end
end

-- the floor's marks, then the drops in the air (world space)
function lib.draw()
    local dat = data()
    local f = dat.floor
    love.graphics.push('all')
    if f then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(f.canvas, f.x0, f.y, 0, f.texel, f.texel)
    end
    for _, p in ipairs(dat.drops) do
        local stretch = math.min(2.2, 1 + math.abs(p.vy) / 1500)
        love.graphics.setColor(p.r, p.g, p.b, p.water and 0.55 or 0.95)
        love.graphics.ellipse('fill', p.x, p.y, p.size / math.sqrt(stretch), p.size * stretch)
        love.graphics.setColor(1, 1, 1, p.water and 0.6 or 0.35 * (p.paint or 0) + 0.15)
        love.graphics.circle('fill', p.x - p.size * 0.3, p.y - p.size * 0.3, p.size * 0.28)
    end
    love.graphics.pop()
end

return lib

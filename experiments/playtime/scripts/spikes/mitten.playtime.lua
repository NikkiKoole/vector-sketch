-- mitten: The Mitten (Ukrainian tale, STORY-IDEAS.md) — squeeze Mipos into a soft mitten in the snow until it pops.
-- The mitten is a chain of wool beads (small circles on springy distance joints) from the cuff's bottom lip, along
-- the bottom, round the fingertips, over the thumb and back to the cuff's top: open at the cuff. Each bead is
-- pulled to its place in the mitten's rest shape (shape matching: the rest outline moved and turned to fit where
-- the beads are now), so it's soft: Mipos pushed in bulge it out, and it springs back.
-- When `capacity` Mipos are inside, the last one in winds up (ah... ah...) and sneezes: the mitten puffs up,
-- its beads stop touching Mipos for a moment and everyone inside is thrown out.
--
-- play mode (tab): drag Mipos in through the cuff (on the right). Drag the wool to pull the mitten about.
-- keys: m a Mipo at the mouse   p pop now   r reset
local s = {}

local GROUND_Y = 0
local BEAD_R, SPACING = 42, 66
local NODE_CAT, GROUND_CAT, MIPO_CAT = 14, 13, 1

local POP_OPEN = 1.0 -- seconds the wool lets Mipos through after a pop (longer while one is still inside it)
local tune = { stiffness = 30, damping = 0.6, capacity = 5, gravity = 0.25 }

-- The rest outline (world units, lying on the snow): from the cuff's bottom lip, leftwards along the bottom,
-- round the fingertips, back along the top over the thumb, to the cuff's top. Smoothed and resampled below.
local CONTROL = {
    { 1150, -330 }, { 1000, -120 }, { 600, -45 }, { -400, -45 }, { -1300, -60 }, { -1750, -300 },
    { -1850, -650 }, { -1700, -1000 }, { -1300, -1180 }, { -500, -1200 }, { -150, -1250 },
    { 0, -1550 }, { 250, -1700 }, { 500, -1600 }, { 520, -1300 }, { 800, -1180 }, { 1150, -1080 },
}

-- a bit smaller than drawn above, so four Mipos fill it and the fifth has to squeeze
local SHRINK_X, SHRINK_Y = 0.8, 0.82
for _, p in ipairs(CONTROL) do
    p[1], p[2] = p[1] * SHRINK_X, math.min(-45, p[2] * SHRINK_Y)
end

local function catmull(p0, p1, p2, p3, t)
    local t2, t3 = t * t, t * t * t
    local function c(a, b, cc, d)
        return 0.5 * ((2 * b) + (-a + cc) * t + (2 * a - 5 * b + 4 * cc - d) * t2 + (-a + 3 * b - 3 * cc + d) * t3)
    end
    return c(p0[1], p1[1], p2[1], p3[1]), c(p0[2], p1[2], p2[2], p3[2])
end

-- the outline as points SPACING apart
local function restOutline()
    local dense = {}
    for i = 1, #CONTROL - 1 do
        local p0, p1 = CONTROL[math.max(1, i - 1)], CONTROL[i]
        local p2, p3 = CONTROL[i + 1], CONTROL[math.min(#CONTROL, i + 2)]
        for k = 0, 19 do
            local x, y = catmull(p0, p1, p2, p3, k / 20)
            dense[#dense + 1] = { x, y }
        end
    end
    dense[#dense + 1] = { CONTROL[#CONTROL][1], CONTROL[#CONTROL][2] }
    local out, carry = { { dense[1][1], dense[1][2] } }, 0
    for i = 2, #dense do
        local ax, ay = dense[i - 1][1], dense[i - 1][2]
        local bx, by = dense[i][1], dense[i][2]
        local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
        local d = SPACING - carry
        while d <= len do
            local t = d / len
            out[#out + 1] = { ax + (bx - ax) * t, ay + (by - ay) * t }
            d = d + SPACING
        end
        carry = len - (d - SPACING)
    end
    return out
end

local function mitten()
    if not state.mitten then state.mitten = { mipos = {}, inside = {} } end
    return state.mitten
end

local function alive(body) return body and not body:isDestroyed() end

local function destroyMitten(m)
    for _, b in ipairs(m.beads or {}) do
        if alive(b) then b:destroy() end
    end
    m.beads = nil
end

local function setPop(m, popping)
    for _, b in ipairs(m.beads) do
        local f = b:getFixtures()[1]
        if popping then f:setMask(MIPO_CAT) else f:setMask() end
    end
end

local function makeMitten(m)
    destroyMitten(m)
    m.rest = restOutline()
    local cx, cy = 0, 0
    for _, p in ipairs(m.rest) do cx, cy = cx + p[1], cy + p[2] end
    m.restC = { cx / #m.rest, cy / #m.rest }
    m.beads = {}
    for i, p in ipairs(m.rest) do
        local b = love.physics.newBody(world, p[1], p[2], 'dynamic')
        local f = love.physics.newFixture(b, love.physics.newCircleShape(BEAD_R), 2)
        f:setGroupIndex(-4242) -- beads don't touch each other
        f:setCategory(NODE_CAT)
        f:setFriction(0.9)
        b:setGravityScale(tune.gravity)
        b:setLinearDamping(0.5)
        m.beads[i] = b
        if i > 1 then
            local a = m.beads[i - 1]
            local j = love.physics.newDistanceJoint(a, b, a:getX(), a:getY(), b:getX(), b:getY())
            j:setFrequency(6)
            j:setDampingRatio(0.5)
        end
    end
    m.scale, m.popT, m.windup = 1, nil, nil
end

local function makeGround(m)
    if alive(m.ground) then return end
    m.ground = love.physics.newBody(world, 0, 0, 'static')
    local f = love.physics.newFixture(m.ground, love.physics.newEdgeShape(-6000, GROUND_Y, 6000, GROUND_Y))
    f:setCategory(GROUND_CAT)
    f:setFriction(0.9)
    for _, x in ipairs({ -6000, 6000 }) do
        local w = love.physics.newFixture(m.ground, love.physics.newEdgeShape(x, GROUND_Y, x, GROUND_Y - 6000))
        w:setCategory(GROUND_CAT)
    end
end

-- the beads' positions as a flat polygon (closed by the cuff's opening)
local function outline(m)
    local pts = {}
    for _, b in ipairs(m.beads) do
        local x, y = b:getPosition()
        pts[#pts + 1] = x
        pts[#pts + 1] = y
    end
    return pts
end

local function inside(pts, x, y)
    local inPoly, n = false, #pts / 2
    local j = n
    for i = 1, n do
        local xi, yi, xj, yj = pts[2 * i - 1], pts[2 * i], pts[2 * j - 1], pts[2 * j]
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then inPoly = not inPoly end
        j = i
    end
    return inPoly
end

local function area(pts)
    local a, n = 0, #pts / 2
    for i = 1, n do
        local k = i % n + 1
        a = a + pts[2 * i - 1] * pts[2 * k] - pts[2 * k - 1] * pts[2 * i]
    end
    return math.abs(a) / 2
end

-- Shape matching: the rest outline, scaled by m.scale, turned and moved to fit the beads; each bead is
-- pulled to its place there by a damped spring (as an impulse: the script runs after the physics steps).
local function holdShape(m, dt)
    local n = #m.beads
    local cx, cy = 0, 0
    for _, b in ipairs(m.beads) do
        local x, y = b:getPosition()
        cx, cy = cx + x, cy + y
    end
    cx, cy = cx / n, cy / n
    local sdot, scross = 0, 0
    for i, b in ipairs(m.beads) do
        local x, y = b:getPosition()
        local px, py = x - cx, y - cy
        local rx, ry = m.rest[i][1] - m.restC[1], m.rest[i][2] - m.restC[2]
        sdot = sdot + rx * px + ry * py
        scross = scross + rx * py - ry * px
    end
    local ang = math.atan2(scross, sdot)
    local ca, sa = math.cos(ang), math.sin(ang)
    local k, c = tune.stiffness, 2 * tune.damping * math.sqrt(tune.stiffness)
    for i, b in ipairs(m.beads) do
        local rx, ry = (m.rest[i][1] - m.restC[1]) * m.scale, (m.rest[i][2] - m.restC[2]) * m.scale
        local tx, ty = cx + rx * ca - ry * sa, cy + rx * sa + ry * ca
        local x, y = b:getPosition()
        local vx, vy = b:getLinearVelocity()
        local mass = b:getMass()
        b:applyLinearImpulse(mass * (k * (tx - x) - c * vx) * dt, mass * (k * (ty - y) - c * vy) * dt)
    end
    m.target = { cx = cx, cy = cy, ca = ca, sa = sa }
end

local function torsoOf(inst)
    local t = inst.parts and inst.parts.torso1
    return t and alive(t.body) and t.body or nil
end

local function pop(m)
    local pts = outline(m)
    local cx, cy = 0, 0
    for i = 1, #pts, 2 do cx, cy = cx + pts[i], cy + pts[i + 1] end
    cx, cy = cx / (#pts / 2), cy / (#pts / 2)
    setPop(m, true)
    m.popT, m.windup, m.scale = 0, nil, 1.3
    for _, inst in ipairs(m.inside) do
        local torso = torsoOf(inst)
        if torso then
            local x, y = torso:getPosition()
            local dx, dy = x - cx, y - cy
            local d = math.max(1, math.sqrt(dx * dx + dy * dy))
            -- up and away from the middle: up is where there's room
            local vx, vy = dx / d * (1200 + random() * 700), -2600 - random() * 900
            for _, part in pairs(inst.parts) do
                if part.body and alive(part.body) then
                    part.body:setLinearVelocity(vx, vy)
                    part.body:setAngularVelocity((random() - 0.5) * 12)
                end
            end
            mipoVoice.squeak(inst, 'happy', 1.2)
        end
    end
    m.pops = (m.pops or 0) + 1
end

local function spawnMipo(m, x, y)
    mipoKit.spawn(m.mipos, x, y)
end

local function reset(m)
    for _, inst in ipairs(mipoKit.alive(m.mipos)) do
        for _, part in pairs(inst.parts) do
            if alive(part.body) then objectManager.destroyBody(part.body) end
        end
    end
    m.mipos, m.inside, m.order = {}, {}, {}
    makeMitten(m)
    for k = 0, 4 do spawnMipo(m, 1500 + k * 520, -700) end
end

function s.onStart()
    worldState.paused = false
    local m = mitten()
    makeGround(m)
    if not (m.beads and alive(m.beads[1])) then makeMitten(m) end
    m.mipos = mipoKit.alive(m.mipos)
    if #m.mipos == 0 then reset(m) end
    camera.setBounds(-3000, -3200, 4500, 600)
end

function s.onUnload()
    local m = state.mitten
    if not m then return end
    destroyMitten(m)
    if alive(m.ground) then m.ground:destroy() end
    m.ground = nil
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local m = mitten()
    if key == 'm' then
        local mx, my = mouseWorldPos()
        spawnMipo(m, mx, my)
    elseif key == 'p' then pop(m)
    elseif key == 'r' then reset(m) end
end

-- From the bridge: s.spawnAt(x, y), s.popNow(), s.status()
function s.spawnAt(x, y) spawnMipo(mitten(), x, y) end
function s.popNow() pop(mitten()) end
function s.status()
    local m = mitten()
    local pts = outline(m)
    return { inside = #m.inside, area = area(pts) / (m.restArea or 1), pops = m.pops or 0,
        popping = m.popT ~= nil, windup = m.windup }
end

function s.update(dt)
    local m = mitten()
    if not (m.beads and alive(m.beads[1])) then return end
    holdShape(m, dt)
    local pts = outline(m)
    if not m.restArea then
        local flat = {}
        for _, p in ipairs(m.rest) do flat[#flat + 1] = p[1]; flat[#flat + 1] = p[2] end
        m.restArea = area(flat)
    end
    m.stretch = area(pts) / m.restArea

    -- who's inside, in the order they came in
    m.mipos = mipoKit.alive(m.mipos)
    m.order = m.order or {}
    local now = {}
    for _, inst in ipairs(m.mipos) do
        local torso = torsoOf(inst)
        if torso and inside(pts, torso:getPosition()) then now[inst] = true end
    end
    local kept = {}
    for _, inst in ipairs(m.order) do
        if now[inst] then kept[#kept + 1] = inst; now[inst] = nil end
    end
    for _, inst in ipairs(m.mipos) do
        if now[inst] then kept[#kept + 1] = inst end
    end
    m.order = kept
    if not m.popT then m.inside = kept end
    m.anyIn = #kept > 0

    if m.popT then -- popping: the mitten puffed, its beads letting Mipos through, then back
        m.popT = m.popT + dt
        m.scale = 1 + 0.3 * math.max(0, 1 - m.popT / 0.5)
        if m.popT > POP_OPEN and (not m.anyIn or m.popT > 3) then
            setPop(m, false)
            m.popT, m.scale = nil, 1
            m.inside = {}
        end
    elseif #kept >= tune.capacity then
        m.windup = (m.windup or 0) + dt
        local last = kept[#kept]
        local w = m.windup
        if w - dt < 0.4 and w >= 0.4 then mipoVoice.squeak(last, 'curious', 1.3) end   -- ah...
        if w - dt < 1.1 and w >= 1.1 then mipoVoice.squeak(last, 'curious', 1.5) end   -- ah...
        m.scale = 1 + 0.06 * math.sin(w * 9) * math.min(1, w)                          -- the mitten trembles
        if w >= 1.8 then
            mipoVoice.squeak(last, 'annoyed', 1.6)                                    -- tchoo!
            pop(m)
        end
    else
        m.windup, m.scale = nil, 1
    end
end

-- the drawing --------------------------------------------------------------------------------------------

local WOOL = { 0.78, 0.22, 0.20 }
local WOOL_DARK = { 0.55, 0.13, 0.13 }
local LINING = { 0.45, 0.12, 0.12 }
local STRIPE = { 0.95, 0.88, 0.72 }

-- the outline pushed out by a bead's radius (so the wool covers the beads), as a closed flat polygon
local function woolEdge(pts, grow)
    local n, out = #pts / 2, {}
    for i = 1, n do
        local a = math.max(1, i - 1)
        local b = math.min(n, i + 1)
        local tx, ty = pts[2 * b - 1] - pts[2 * a - 1], pts[2 * b] - pts[2 * a]
        local l = math.max(1e-6, math.sqrt(tx * tx + ty * ty))
        -- the outline runs clockwise on screen (bottom leftwards, top rightwards): outward is (ty, -tx)
        out[#out + 1] = pts[2 * i - 1] + ty / l * grow
        out[#out + 1] = pts[2 * i] - tx / l * grow
    end
    return out
end

local function fillPoly(poly)
    local ok, tris = pcall(love.math.triangulate, poly)
    if not ok then return end
    for _, t in ipairs(tris) do love.graphics.polygon('fill', t) end
end

local snow = {}
for i = 1, 160 do snow[i] = { random() * 9000 - 4500, random() * 3600 - 3400, 6 + random() * 10, random() } end

function s.drawBelow()
    local m = state.mitten
    if not (m and m.beads and alive(m.beads[1])) then return end
    -- sky and snow
    love.graphics.setColor(0.80, 0.86, 0.92)
    love.graphics.rectangle('fill', -6000, -6000, 12000, 6000)
    love.graphics.setColor(0.97, 0.98, 1)
    love.graphics.rectangle('fill', -6000, GROUND_Y - 20, 12000, 3000)
    love.graphics.setColor(0.88, 0.92, 0.97)
    love.graphics.ellipse('fill', -300, GROUND_Y + 10, 2600, 60)
    -- the inside of the mitten: the dark lining
    local pts = outline(m)
    love.graphics.setColor(LINING)
    fillPoly(pts)
end

-- the wool over the Mipos: a thick knitted band along the beads, stripes across it, a ribbed cuff
function s.draw()
    local m = state.mitten
    if not (m and m.beads and alive(m.beads[1])) then return end
    local pts = outline(m)
    local n = #pts / 2
    local outer = woolEdge(pts, BEAD_R + 14)
    local inner = woolEdge(pts, -BEAD_R - 6)
    -- the band as quads between the inner and outer edge
    for i = 1, n - 1 do
        local quad = { inner[2 * i - 1], inner[2 * i], outer[2 * i - 1], outer[2 * i],
            outer[2 * i + 1], outer[2 * i + 2], inner[2 * i + 1], inner[2 * i + 2] }
        local cuff = i <= 4 or i >= n - 4
        if cuff then
            love.graphics.setColor(i % 2 == 0 and STRIPE or { 0.85, 0.78, 0.62 })
        elseif (i % 14) < 2 then
            love.graphics.setColor(STRIPE)
        else
            love.graphics.setColor(i % 2 == 0 and WOOL or { WOOL[1] * 0.93, WOOL[2] * 0.93, WOOL[3] * 0.93 })
        end
        fillPoly(quad)
    end
    -- stitches: a small v on every bead
    love.graphics.setLineWidth(6)
    love.graphics.setColor(WOOL_DARK)
    for i = 1, n do
        local x, y = pts[2 * i - 1], pts[2 * i]
        love.graphics.line(x - 14, y - 10, x, y + 8, x + 14, y - 10)
    end
    -- the edges
    love.graphics.setColor(0.25, 0.08, 0.08)
    love.graphics.setLineWidth(8)
    love.graphics.line(outer)
    love.graphics.line(inner)
    love.graphics.setLineWidth(1)
    -- falling snow
    local t = love.timer.getTime()
    love.graphics.setColor(1, 1, 1, 0.9)
    for _, f in ipairs(snow) do
        local y = (f[2] + t * (60 + f[4] * 60)) % 3600 - 3400
        love.graphics.circle('fill', f[1] + math.sin(t + f[4] * 6) * 40, y, f[3])
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local m = state.mitten
    if not (m and state.playMode) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 300
    local rows = 7
    local h = BH * rows + pad * (rows + 1) + 20
    local sw, sh = love.graphics.getDimensions()
    local x0, y0 = sw / ui.scale - w - 20, sh / ui.scale - h - 20 -- on the right: the mitten lies on the left
    ui.panel(x0, y0, w, h, '•• mitten ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'a Mipo') then spawnMipo(m, 1700, -900) end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'pop!') then pop(m) end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'reset') then reset(m) end
        for _, row in ipairs({ { 'capacity', 1, 8, 1 }, { 'stiffness', 5, 120 }, { 'damping', 0.1, 2 } }) do
            x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('mitten' .. row[1], x, y, 140, row[2], row[3], tune[row[1]], nil, row[4])
            if v then tune[row[1]] = v + 0 end
            ui.label(x + 240, y, row[1])
        end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, string.format('inside %d   stretch %.2f', #m.inside, m.stretch or 1))
    end)
end

return s

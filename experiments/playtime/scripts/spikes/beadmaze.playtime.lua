-- beadmaze: the wooden bead maze — coloured wires looping up out of a wooden base, chunky beads you push along them.
-- Nikki 2026-11-16: "could we do a bead maze next, like beads on rails?"
--
-- A bead is held on its wire, so it lives in one number: how far along the wire it is (s), and a speed along it.
-- Gravity pulls it along the wire's slope, the wire's friction slows it (a drag and a steady rub, so it stops on
-- a flat), the ends stop it, and beads on the same wire clack into each other and pass their speed on (1D, by
-- weight). Not Box2D carts (src/rail-cart.lua locks bodies to a track chain and lets go at its ends; a bead never
-- lets go): each bead has a kinematic body that follows it, so a Mipo standing by gets pushed.
-- Wires cross in front of and behind each other: a back wire and its beads are drawn before the bodies, a front
-- one after (as the track's lanes).
--
-- play mode (tab): drag a bead along its wire; let go and it carries on. Keys: space shake the toy,
-- r reset, m a Mipo at the mouse.

local s = {}

local FLOOR_Y = 0
local BASE = { x1 = -2050, x2 = 2050, y1 = -300, y2 = 0 }   -- the wooden block the wires stand in
local WIRE_W = 24

-- The wires: control points (a Catmull-Rom curve through them), colour, front or back.
local WIRES = {
    { name = 'red', color = { 0.86, 0.22, 0.18 }, front = false,
        pts = { { -1850, -300 }, { -1850, -1300 }, { -1500, -2050 }, { -1050, -2150 }, { -750, -1500 }, { -650, -300 } } },
    { name = 'blue', color = { 0.20, 0.40, 0.82 }, front = true,
        pts = { { -1450, -300 }, { -1350, -1000 }, { -950, -1450 }, { -500, -1250 }, { -650, -900 },
            { -1000, -1050 }, { -800, -1650 }, { -150, -1850 }, { 300, -1100 }, { 250, -300 } } },
    { name = 'yellow', color = { 0.96, 0.78, 0.16 }, front = false,
        pts = { { -250, -300 }, { -200, -1150 }, { 300, -1350 }, { -50, -1600 }, { 450, -1850 }, { 900, -1650 },
            { 1000, -300 } } },
    { name = 'green', color = { 0.20, 0.62, 0.32 }, front = true,
        pts = { { 600, -300 }, { 650, -950 }, { 1150, -1250 }, { 1550, -850 }, { 1300, -550 }, { 1000, -850 },
            { 1400, -1550 }, { 1900, -1300 }, { 1850, -300 } } },
    { name = 'orange', color = { 0.95, 0.52, 0.15 }, front = true,
        pts = { { -1950, -300 }, { -1100, -850 }, { 0, -650 }, { 1050, -1000 }, { 1950, -300 } } },
}

-- the beads on each wire: a shape and a paint colour; size is a radius in world units
local PAINT = { { 0.92, 0.30, 0.25 }, { 0.25, 0.55, 0.90 }, { 1.0, 0.82, 0.25 }, { 0.35, 0.75, 0.40 },
    { 0.70, 0.40, 0.80 }, { 0.98, 0.60, 0.25 }, { 0.95, 0.95, 0.90 } }
local BEADS = {
    red = { 'round', 'cube', 'flower', 'round' },
    blue = { 'cylinder', 'round', 'round', 'cube', 'flower' },
    yellow = { 'flower', 'cylinder', 'round' },
    green = { 'cube', 'round', 'cylinder', 'round', 'flower' },
    orange = { 'round', 'cube', 'round', 'cylinder', 'round', 'flower' },
}
local SIZE = { round = 82, cube = 78, cylinder = 74, flower = 96 }

local tune = { drag = 0.6, rub = 260, bounce = 0.55, push = 1 }

local function sd()
    state.beadmaze = state.beadmaze or { wires = {}, bodies = {}, mipos = {}, pending = {} }
    return state.beadmaze
end

---------------------------------------------------------------- sound: a wooden clack, made once

local clackSrc
local function clack(volume, pitch)
    if not clackSrc then
        local rate = 22050
        local data = love.sound.newSoundData(math.floor(rate * 0.09), rate, 16, 1)
        for i = 0, data:getSampleCount() - 1 do
            local t = i / rate
            local v = (love.math.random() * 2 - 1) * math.exp(-t * 180) * 0.45
                + math.sin(t * 2 * math.pi * 1150) * math.exp(-t * 70) * 0.45
                + math.sin(t * 2 * math.pi * 2630) * math.exp(-t * 110) * 0.2
            data:setSample(i, math.max(-1, math.min(1, v)))
        end
        clackSrc = love.audio.newSource(data, 'static')
    end
    local src = clackSrc:clone()
    src:setVolume(math.min(1, volume))
    src:setPitch(pitch or 1)
    src:play()
end

---------------------------------------------------------------- the wires as polylines with distances

local function catmull(p0, p1, p2, p3, t)
    local t2, t3 = t * t, t * t * t
    local function c(a, b, cc, d)
        return 0.5 * ((2 * b) + (-a + cc) * t + (2 * a - 5 * b + 4 * cc - d) * t2 + (-a + 3 * b - 3 * cc + d) * t3)
    end
    return c(p0[1], p1[1], p2[1], p3[1]), c(p0[2], p1[2], p2[2], p3[2])
end

local function sampleWire(def)
    local pts = def.pts
    local n = #pts
    local xs, ys, ss = {}, {}, {}
    local steps = 24
    for i = 1, n - 1 do
        local p0, p1, p2, p3 = pts[math.max(1, i - 1)], pts[i], pts[i + 1], pts[math.min(n, i + 2)]
        for k = (i == 1 and 0 or 1), steps do
            local x, y = catmull(p0, p1, p2, p3, k / steps)
            xs[#xs + 1], ys[#ys + 1] = x, y
        end
    end
    ss[1] = 0
    for i = 2, #xs do
        ss[i] = ss[i - 1] + math.sqrt((xs[i] - xs[i - 1]) ^ 2 + (ys[i] - ys[i - 1]) ^ 2)
    end
    local flat = {}
    for i = 1, #xs do flat[#flat + 1] = xs[i]; flat[#flat + 1] = ys[i] end
    return { xs = xs, ys = ys, ss = ss, len = ss[#ss], flat = flat }
end

-- the point and the unit tangent at distance d along a wire
local function at(w, d)
    local ss = w.ss
    d = math.max(0, math.min(w.len, d))
    local lo, hi = 1, #ss
    while hi - lo > 1 do
        local mid = math.floor((lo + hi) / 2)
        if ss[mid] <= d then lo = mid else hi = mid end
    end
    local seg = ss[hi] - ss[lo]
    local f = seg > 0 and (d - ss[lo]) / seg or 0
    local x = w.xs[lo] + (w.xs[hi] - w.xs[lo]) * f
    local y = w.ys[lo] + (w.ys[hi] - w.ys[lo]) * f
    local tx, ty = w.xs[hi] - w.xs[lo], w.ys[hi] - w.ys[lo]
    local tl = math.sqrt(tx * tx + ty * ty)
    if tl > 0 then tx, ty = tx / tl, ty / tl else tx, ty = 1, 0 end
    return x, y, tx, ty
end

-- the distance along the wire nearest to a point, searched only within `reach` of `around` (so a drag
-- doesn't jump to another part of the wire that passes close by)
local function nearest(w, px, py, around, reach)
    local best, bestD = around, math.huge
    for i = 1, #w.xs do
        if math.abs(w.ss[i] - around) <= reach then
            local d = (w.xs[i] - px) ^ 2 + (w.ys[i] - py) ^ 2
            if d < bestD then best, bestD = w.ss[i], d end
        end
    end
    return best, math.sqrt(bestD)
end

---------------------------------------------------------------- building

local function alive(body) return body and not body:isDestroyed() end

local function destroyAll()
    local d = sd()
    for _, body in ipairs(d.bodies) do
        if alive(body) then
            if state.hiddenBodies then state.hiddenBodies[body] = nil end
            body:destroy()
        end
    end
    d.bodies = {}
    for _, w in ipairs(d.wires) do
        for _, b in ipairs(w.beads or {}) do
            if alive(b.body) then b.body:destroy() end
        end
    end
    d.wires = {}
    for _, inst in ipairs(mipoKit.alive(d.mipos)) do
        for _, part in pairs(inst.parts) do
            if alive(part.body) then objectManager.destroyBody(part.body) end
        end
    end
    d.mipos = {}
end

local function hide(body)
    state.hiddenBodies = state.hiddenBodies or {}
    state.hiddenBodies[body] = true
end

local function build()
    local d = sd()
    destroyAll()
    -- the floor and the wooden base, real ground for the Mipos
    local floor = love.physics.newBody(world, 0, FLOOR_Y, 'static')
    love.physics.newFixture(floor, love.physics.newEdgeShape(-6000, 0, 6000, 0)):setFriction(0.9)
    local base = love.physics.newBody(world, (BASE.x1 + BASE.x2) / 2, (BASE.y1 + BASE.y2) / 2, 'static')
    love.physics.newFixture(base, love.physics.newRectangleShape(BASE.x2 - BASE.x1, BASE.y2 - BASE.y1)):setFriction(0.9)
    local walls = love.physics.newBody(world, 0, 0, 'static')
    love.physics.newFixture(walls, love.physics.newChainShape(false, -3600, -5000, -3600, 0, 3600, 0, 3600, -5000))
    for _, body in ipairs({ floor, base, walls }) do
        hide(body)
        d.bodies[#d.bodies + 1] = body
    end
    for wi, def in ipairs(WIRES) do
        local w = sampleWire(def)
        w.def = def
        w.beads = {}
        local kinds = BEADS[def.name]
        -- the beads start bunched at the low left end, a little apart
        local pos = 120
        for bi, kind in ipairs(kinds) do
            local r = SIZE[kind]
            pos = pos + r
            local bead = { kind = kind, r = r, s = pos, v = 0, mass = (r / 80) ^ 2,
                color = PAINT[(wi + bi * 2) % #PAINT + 1] }
            local x, y = at(w, pos)
            local body = love.physics.newBody(world, x, y, 'kinematic')
            love.physics.newFixture(body, love.physics.newCircleShape(r * 0.9)):setFriction(0.6)
            hide(body)
            bead.body = body
            w.beads[#w.beads + 1] = bead
            pos = pos + r + 6
        end
        d.wires[#d.wires + 1] = w
    end
    d.pending = { { -2550 }, { 2550 } }
end

---------------------------------------------------------------- the beads moving

local function stepWire(w, dt, gy)
    local beads = w.beads
    for _, b in ipairs(beads) do
        if not b.dragged then
            local _, _, _, ty = at(w, b.s)
            -- gravity along the wire (y down), the drag and the rub of the wire through the hole
            b.v = b.v + gy * ty * dt
            b.v = b.v * math.exp(-tune.drag * dt)
            local rub = tune.rub * dt
            if math.abs(b.v) <= rub and math.abs(ty) < 0.12 then
                b.v = 0 -- resting on a flat
            elseif math.abs(b.v) <= rub then
                b.v = b.v * 0.5
            else
                b.v = b.v - (b.v > 0 and rub or -rub)
            end
            b.v = math.max(-5000, math.min(5000, b.v))
            b.s = b.s + b.v * dt
        end
    end
    -- the ends of the wire, inside the base: a bead stops there with a knock
    for _, b in ipairs(beads) do
        if b.s < b.r then
            if b.v < -150 then clack(-b.v / 1500, 0.8) end
            b.s, b.v = b.r, -b.v * 0.2
        elseif b.s > w.len - b.r then
            if b.v > 150 then clack(b.v / 1500, 0.8) end
            b.s, b.v = w.len - b.r, -b.v * 0.2
        end
    end
    -- beads on the same wire: kept in order, they clack and pass their speed on (by weight)
    table.sort(beads, function(a, c) return a.s < c.s end)
    for _ = 1, 3 do
        for i = 1, #beads - 1 do
            local a, c = beads[i], beads[i + 1]
            local gap = (c.s - a.s) - (a.r + c.r)
            if gap < 0 then
                local rel = a.v - c.v
                if rel > 0 then
                    local m1, m2 = a.dragged and 1e6 or a.mass, c.dragged and 1e6 or c.mass
                    local e = tune.bounce
                    local va = (m1 * a.v + m2 * c.v - m2 * e * rel) / (m1 + m2)
                    local vc = (m1 * a.v + m2 * c.v + m1 * e * rel) / (m1 + m2)
                    if not a.dragged then a.v = va end
                    if not c.dragged then c.v = vc end
                    if rel > 120 then clack(rel / 1200, 0.9 + love.math.random() * 0.25) end
                end
                -- pushed apart; a dragged bead doesn't give way
                if a.dragged then c.s = c.s - gap
                elseif c.dragged then a.s = a.s + gap
                else
                    local wa = c.mass / (a.mass + c.mass)
                    a.s, c.s = a.s + gap * wa, c.s - gap * (1 - wa)
                end
            end
        end
    end
    for _, b in ipairs(beads) do b.s = math.max(b.r, math.min(w.len - b.r, b.s)) end
end

local function placeBodies(w, dt)
    for _, b in ipairs(w.beads) do
        if alive(b.body) then
            local x, y = at(w, b.s)
            local bx, by = b.body:getPosition()
            b.body:setLinearVelocity((x - bx) / dt, (y - by) / dt)
        end
    end
end

---------------------------------------------------------------- input: drag a bead along its wire

local panelRect = { 20, 20, 280, 0 }
local function overPanel()
    if ui.isPanelFolded('•• bead maze ••') then return false end
    local mx, my = love.mouse.getPosition()
    local r = panelRect
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

local function beadAt(d, mx, my)
    -- front wires first: what's drawn on top is picked first
    local best, bestW, bestD
    for pass = 1, 2 do
        for _, w in ipairs(d.wires) do
            if (pass == 1) == w.def.front then
                for _, b in ipairs(w.beads) do
                    local x, y = at(w, b.s)
                    local dist = math.sqrt((x - mx) ^ 2 + (y - my) ^ 2)
                    if dist < b.r * 1.3 and (not bestD or dist < bestD) then best, bestW, bestD = b, w, dist end
                end
            end
        end
        if best then return best, bestW end
    end
end

local function input(d, dt)
    local down = state.playMode and love.mouse.isDown(1)
    local mx, my = mouseWorldPos()
    if down and not d.drag and not d.pressed then
        d.pressed = true
        if not overPanel() then
            local b, w = beadAt(d, mx, my)
            if b then
                d.drag = { bead = b, wire = w }
                b.dragged = true
            end
        end
    elseif not down then
        d.pressed = nil
        if d.drag then
            local b = d.drag.bead
            b.dragged = nil
            b.v = math.max(-3500, math.min(3500, (d.drag.vel or 0) * tune.push))
            d.drag = nil
        end
    end
    if d.drag then
        local b, w = d.drag.bead, d.drag.wire
        local target = nearest(w, mx, my, b.s, 500)
        local step = target - b.s
        local maxStep = 4000 * dt
        step = math.max(-maxStep, math.min(maxStep, step))
        b.s = b.s + step
        local vel = step / math.max(dt, 1e-4)
        d.drag.vel = (d.drag.vel or 0) * 0.6 + vel * 0.4
        b.v = 0
    end
end

---------------------------------------------------------------- hooks

function s.onStart()
    worldState.paused = false
    local d = sd()
    local any = false
    for _, body in ipairs(d.bodies) do any = any or alive(body) end
    if not any then build() end
    -- the follow camera won't zoom out past what fits in its bounds: tall and wide enough for 0.14
    camera.setBounds(-4400, -4600, 4400, 900)
    camera.zoomTo(0.14, 0.4)
end

function s.onUnload()
    destroyAll()
end

function s.update(dt)
    local d = sd()
    if d.pending and #d.pending > 0 then -- one Mipo a frame
        local p = table.remove(d.pending, 1)
        mipoKit.spawn(d.mipos, p[1], FLOOR_Y - 700)
    end
    if dt <= 0 then return end
    input(d, dt)
    local _, gy = world:getGravity()
    -- small steps: a fast bead over a tight bend
    local n = 3
    for _ = 1, n do
        for _, w in ipairs(d.wires) do stepWire(w, dt / n, gy) end
    end
    for _, w in ipairs(d.wires) do placeBodies(w, dt) end
end

-- From the bridge: s.push(wireIndex, beadIndex, speed) and s.state()
function s.push(wi, bi, speed)
    local w = sd().wires[wi]
    local b = w and w.beads[bi]
    if b then b.v = speed end
end

function s.info()
    local out = {}
    for wi, w in ipairs(sd().wires) do
        local row = {}
        for _, b in ipairs(w.beads) do row[#row + 1] = string.format('%d@%d', math.floor(b.v), math.floor(b.s)) end
        out[wi] = w.def.name .. ' len ' .. math.floor(w.len) .. ': ' .. table.concat(row, ' ')
    end
    return out
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local d = sd()
    if key == 'space' then -- shake the toy: every bead a knock one way or the other
        for _, w in ipairs(d.wires) do
            for _, b in ipairs(w.beads) do b.v = b.v + (love.math.random() * 2 - 1) * 1600 end
        end
        clack(0.6, 0.7)
    elseif key == 'r' then
        build()
    elseif key == 'm' then
        local mx, my = mouseWorldPos()
        mipoKit.spawn(d.mipos, mx, my)
    end
end

---------------------------------------------------------------- drawing

local function outlineColor() love.graphics.setColor(0.18, 0.12, 0.08, 1) end

local function drawWire(w)
    local c = w.def.color
    love.graphics.setLineJoin('bevel')
    outlineColor()
    love.graphics.setLineWidth(WIRE_W + 8)
    love.graphics.line(w.flat)
    love.graphics.setColor(c[1], c[2], c[3], 1)
    love.graphics.setLineWidth(WIRE_W)
    love.graphics.line(w.flat)
    love.graphics.setColor(1, 1, 1, 0.35) -- the shine along the top of the wire
    love.graphics.setLineWidth(WIRE_W * 0.3)
    love.graphics.push()
    love.graphics.translate(-3, -5)
    love.graphics.line(w.flat)
    love.graphics.pop()
end

local function flowerPoly(x, y, r)
    local pts = {}
    for k = 0, 59 do
        local a = k / 60 * math.pi * 2
        local rr = r * (0.78 + 0.22 * math.cos(a * 5))
        pts[#pts + 1] = x + math.cos(a) * rr
        pts[#pts + 1] = y + math.sin(a) * rr
    end
    return pts
end

local function drawBead(w, b)
    local x, y, tx, ty = at(w, b.s)
    local c = b.color
    local r = b.r
    love.graphics.setLineWidth(7)
    if b.kind == 'round' then
        love.graphics.setColor(c[1], c[2], c[3], 1)
        love.graphics.circle('fill', x, y, r)
        outlineColor()
        love.graphics.circle('line', x, y, r)
    elseif b.kind == 'flower' then
        local pts = flowerPoly(x, y, r)
        love.graphics.setColor(c[1], c[2], c[3], 1)
        love.graphics.polygon('fill', pts)
        outlineColor()
        love.graphics.polygon('line', pts)
    else
        -- a cube stays upright; a cylinder lies along the wire (its hole is its axis)
        local ang = b.kind == 'cylinder' and math.atan2(ty, tx) or 0
        local hw, hh = r, b.kind == 'cylinder' and r * 0.72 or r
        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.rotate(ang)
        love.graphics.setColor(c[1], c[2], c[3], 1)
        love.graphics.rectangle('fill', -hw, -hh, hw * 2, hh * 2, r * 0.25)
        if b.kind == 'cylinder' then -- its rings
            love.graphics.setColor(c[1] * 0.8, c[2] * 0.8, c[3] * 0.8, 1)
            love.graphics.rectangle('fill', -hw * 0.55, -hh, hw * 0.18, hh * 2)
            love.graphics.rectangle('fill', hw * 0.37, -hh, hw * 0.18, hh * 2)
        end
        outlineColor()
        love.graphics.rectangle('line', -hw, -hh, hw * 2, hh * 2, r * 0.25)
        love.graphics.pop()
    end
    -- the paint's shine
    love.graphics.setColor(1, 1, 1, 0.45)
    love.graphics.ellipse('fill', x - r * 0.35, y - r * 0.4, r * 0.28, r * 0.17)
    -- the hole, where the wire goes in and out
    love.graphics.setColor(0.12, 0.08, 0.05, 0.75)
    local hr = WIRE_W * 0.75
    love.graphics.circle('fill', x - tx * r * 0.82, y - ty * r * 0.82, hr * 0.6)
    love.graphics.circle('fill', x + tx * r * 0.82, y + ty * r * 0.82, hr * 0.6)
end

local function drawLayer(front)
    local d = state.beadmaze
    if not d then return end
    for _, w in ipairs(d.wires) do
        if w.def.front == front then
            drawWire(w)
            for _, b in ipairs(w.beads) do drawBead(w, b) end
        end
    end
end

function s.drawBelow()
    local d = state.beadmaze
    if not d then return end
    -- the room: a wall and a floor
    love.graphics.setColor(0.93, 0.89, 0.80, 1)
    love.graphics.rectangle("fill", -6000, -7000, 12000, 7000)
    love.graphics.setColor(0.62, 0.50, 0.38, 1)
    love.graphics.rectangle('fill', -4000, FLOOR_Y, 8000, 1200)
    drawLayer(false)
    -- the wooden base, over the back wires' ends
    love.graphics.setColor(0.80, 0.60, 0.36, 1)
    love.graphics.rectangle('fill', BASE.x1, BASE.y1, BASE.x2 - BASE.x1, BASE.y2 - BASE.y1, 40)
    love.graphics.setColor(0.70, 0.50, 0.29, 1)
    for k = 1, 4 do -- the grain
        local yy = BASE.y1 + k * (BASE.y2 - BASE.y1) / 5
        love.graphics.setLineWidth(6)
        love.graphics.line(BASE.x1 + 60, yy, BASE.x2 - 60, yy + (k % 2 == 0 and 12 or -12))
    end
    outlineColor()
    love.graphics.setLineWidth(8)
    love.graphics.rectangle('line', BASE.x1, BASE.y1, BASE.x2 - BASE.x1, BASE.y2 - BASE.y1, 40)
end

function s.draw()
    drawLayer(true)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function s.drawUI()
    local d = state.beadmaze
    if not (d and state.playMode) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 280
    local rows = 5
    local h = BH * rows + pad * (rows + 1) + 20
    local x0, y0 = 20, 20
    panelRect[4] = h
    ui.panel(x0, y0, w, h, '•• bead maze ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'shake (space)') then s.onKeyPress('space') end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'reset (r)') then build() end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        local v = ui.sliderWithInput('beadrub', x, y, 130, 0, 1200, tune.rub)
        if v then tune.rub = v + 0 end
        ui.label(x + 220, y, 'rub')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        v = ui.sliderWithInput('beadbounce', x, y, 130, 0, 1, tune.bounce)
        if v then tune.bounce = v + 0 end
        ui.label(x + 220, y, 'bounce')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'drag a bead  m Mipo')
    end)
end

return s

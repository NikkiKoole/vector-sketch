-- rigzones: places that take over a Mipo's skeleton (slide, bench, bar, cushion; a table to crawl under, a beam, a ladder, wind, a swing; a slide park with sky slides; a trampoline for saltos, skipping ropes) and ways to drag one (scruff, by a hand, pose like a doll) (docs/RIG-ZONES.md)
-- The zones and the drag styles are scripts/spikes/rig-zones.lua. Keys: 1-4 drag style (normal, scruff, hand,
-- pose), left / right the two playgrounds, z show the zones, n a new Mipo, h panel.
local s = {}

-- (a change to rig-zones.lua alone doesn't reload this scene: save this file too, or the bridge's /reload)
local rig = love.filesystem.load('scripts/spikes/rig-zones.lua')()

local GROUND_Y = 600

local function st()
    if not state.rigSpike then
        state.rigSpike = { showPanel = true, showZones = true, mipos = {} }
    end
    return state.rigSpike
end

local function box(x, y, w, h, label, friction)
    local thing = objectManager.addThing('rectangle', { x = x, y = y, width = w, height = h,
        bodyType = 'static', label = label })
    if thing and friction then
        for _, f in ipairs(thing.body:getFixtures()) do
            if not f:isSensor() then f:setFriction(friction) end
        end
    end
    return thing
end

local function rectZone(kind, body, x1, y1, x2, y2, extra)
    local z = extra or {}
    z.kind, z.body = kind, body
    z.inside = function(x, y) return x > x1 and x < x2 and y > y1 and y < y2 end
    z.outline = { x1, y1, x2, y1, x2, y2, x1, y2, x1, y1 }
    return rig.addZone(z)
end

-- the slide (props.makeSlide's shape: a deck sloping 3 degrees, then a smoothstep chute), its zone a band
-- above the surface, the slope where the Mipo is
local function slide(x, scale)
    local made = props.makeSlide(x, GROUND_Y, scale)
    if not (made and made.deck) then return end
    local s_ = scale
    local height, deckLength = 700 * s_, 1000 * s_
    local deckDrop, chuteLength = deckLength * math.tan(math.rad(3)), 1400 * s_
    local left, top = x + 20 * s_, GROUND_Y - height
    local chuteHeight = height - deckDrop
    local function surface(px)
        if px < left + deckLength then return top + deckDrop * (px - left) / deckLength end
        local t = math.max(0, math.min(1, (px - left - deckLength) / chuteLength))
        return top + deckDrop + chuteHeight * t * t * (3 - 2 * t)
    end
    local function slopeAt(px)
        if px < left + deckLength then return math.rad(3) end
        local t = math.max(0, math.min(1, (px - left - deckLength) / chuteLength))
        return math.atan(chuteHeight * 6 * t * (1 - t) / chuteLength)
    end
    local band = 560
    local x2 = left + deckLength + chuteLength * 0.97
    local outline = {}
    for i = 0, 20 do
        local px = left + (x2 - left) * i / 20
        outline[#outline + 1], outline[#outline + 2] = px, surface(px) - band
    end
    for i = 20, 0, -1 do
        local px = left + (x2 - left) * i / 20
        outline[#outline + 1], outline[#outline + 2] = px, surface(px) + 10
    end
    outline[#outline + 1], outline[#outline + 2] = outline[1], outline[2]
    rig.addZone({ kind = 'slide', body = made.deck.body, dir = 1, slopeAt = slopeAt, outline = outline,
        inside = function(px, py)
            if px < left or px > x2 then return false end
            local sy = surface(px)
            return py < sy + 10 and py > sy - band
        end })
    for _, f in ipairs(made.deck.body:getFixtures()) do f:setFriction(0.06) end -- (slippery)
end

local function bench(x, w, seatH)
    local seat = box(x, GROUND_Y - seatH, w, 40, 'bench', 0.9)
    box(x - w / 2 + 30, GROUND_Y - seatH / 2 + 10, 30, seatH - 20, 'bench-leg')
    box(x + w / 2 - 30, GROUND_Y - seatH / 2 + 10, 30, seatH - 20, 'bench-leg')
    if seat then
        for _, f in ipairs(seat.body:getFixtures()) do f:setCategory(rig.SEAT) end
    end
    if seat then
        rectZone('bench', seat.body, x - w / 2, GROUND_Y - seatH - 520, x + w / 2, GROUND_Y - seatH + 30,
            { seat = { x1 = x - w / 2, x2 = x + w / 2, top = GROUND_Y - seatH - 20 } })
    end
end

local function bar(x, w, barH)
    local y = GROUND_Y - barH
    box(x - w / 2, GROUND_Y - barH / 2, 36, barH, 'bar-post')
    box(x + w / 2, GROUND_Y - barH / 2, 36, barH, 'bar-post')
    local rod = box(x, y, w, 20, 'bar')
    if not rod then return end
    for _, f in ipairs(rod.body:getFixtures()) do f:setSensor(true) end -- (Mipos pass through; hands grip it)
    rectZone('bar', rod.body, x - w / 2 + 20, y - 120, x + w / 2 - 20, y + 650,
        { bar = { x1 = x - w / 2 + 30, x2 = x + w / 2 - 30, y = y } })
end

local function cushion(x, w, h)
    local thing = box(x, GROUND_Y - h / 2, w, h, 'cushion', 0.9)
    if thing then
        for _, f in ipairs(thing.body:getFixtures()) do f:setRestitution(0.35) end
        rectZone('cushion', thing.body, x - w / 2, GROUND_Y - h - 800, x + w / 2, GROUND_Y - h + 40)
    end
end

-- ── the second playground ──

local function sensors(thing)
    if thing then for _, f in ipairs(thing.body:getFixtures()) do f:setSensor(true) end end
    return thing
end

-- something low to get under: its top `room` above the floor, legs you pass in front of
local function low(x, w, room, label)
    local top = box(x, GROUND_Y - room - 20, w, 40, label, 0.6)
    sensors(box(x - w / 2 + 25, GROUND_Y - room / 2, 24, room, label .. '-leg'))
    sensors(box(x + w / 2 - 25, GROUND_Y - room / 2, 24, room, label .. '-leg'))
    if top then
        -- under it, and just off its ends from higher up (a Mipo walking up to it, its torso above the top,
        -- ducks before its head hits); not above the top itself (one standing on the table)
        local x1, x2, ceiling, margin = x - w / 2, x + w / 2, GROUND_Y - room, 600
        rig.addZone({ kind = 'crawl', body = top.body, ceiling = ceiling, floor = GROUND_Y, x1 = x1, x2 = x2,
            margin = margin,
            inside = function(px, py)
                if py > GROUND_Y + 10 or px < x1 - margin or px > x2 + margin then return false end
                if px > x1 and px < x2 then return py > ceiling end
                return py > ceiling - 500
            end,
            outline = { x1 - margin, ceiling - 500, x1, ceiling - 500, x1, ceiling, x2, ceiling, x2, ceiling - 500,
                x2 + margin, ceiling - 500, x2 + margin, GROUND_Y, x1 - margin, GROUND_Y, x1 - margin, ceiling - 500 } })
    end
end

local function beam(x, w, height)
    local top = GROUND_Y - height
    local b = box(x, top + 15, w, 30, 'beam', 0.9)
    box(x - w / 2 + 30, GROUND_Y - height / 2, 30, height - 30, 'beam-post')
    box(x + w / 2 - 30, GROUND_Y - height / 2, 30, height - 30, 'beam-post')
    if b then rectZone('beam', b.body, x - w / 2, top - 800, x + w / 2, top + 10, { x1 = x - w / 2, x2 = x + w / 2 }) end
end

local function ladder(x, height)
    local top = GROUND_Y - height
    local rail = sensors(box(x - 130, GROUND_Y - height / 2, 24, height, 'ladder'))
    sensors(box(x + 130, GROUND_Y - height / 2, 24, height, 'ladder'))
    local rungs = {}
    for y = GROUND_Y - 150, top + 40, -140 do
        sensors(box(x, y, 260, 16, 'ladder-rung'))
        rungs[#rungs + 1] = y
    end
    if rail then
        rectZone('ladder', rail.body, x - 170, top - 100, x + 170, GROUND_Y + 10,
            { bar = { x1 = x - 120, x2 = x + 120, y = rungs[1], rungs = rungs }, pullAway = 260 })
    end
end

-- wind from a fan at the right end, blowing left over the box
local function wind(x1, x2, top)
    local fan = box(x2 + 60, GROUND_Y - 180, 120, 360, 'fan', 0.5)
    if fan then
        local z = rectZone('wind', fan.body, x1, top, x2, GROUND_Y + 10, { dir = -1 })
        z.box = { x1, top, x2, GROUND_Y }
    end
end

-- a swing: a seat hanging from a beam on two posts (a revolute joint at the pivot), its zone the room above the
-- seat, moving with it
local function swing(x, height, seatH)
    local beamY = GROUND_Y - height
    -- the frame touches nothing (Nikki 2026-11-14: "can the frame not collide with the swing"): in a side view
    -- the posts stand beside the seat, not in its way
    sensors(box(x - 380, GROUND_Y - height / 2, 36, height, 'swing-post'))
    sensors(box(x + 380, GROUND_Y - height / 2, 36, height, 'swing-post'))
    local top = sensors(box(x, beamY, 820, 36, 'swing-beam'))
    local seat = objectManager.addThing('rectangle', { x = x, y = GROUND_Y - seatH, width = 300, height = 30,
        label = 'swing-seat' })
    if not (top and seat) then return end
    local sb = seat.body
    for _, f in ipairs(sb:getFixtures()) do
        f:setCategory(rig.SEAT)
        f:setFriction(0.9)
    end
    local pivot = { x, beamY + 20 }
    love.physics.newRevoluteJoint(top.body, sb, pivot[1], pivot[2], false)
    sb:setAngularDamping(0.05)
    local z = rig.addZone({ kind = 'swing', body = sb, pivot = pivot,
        inside = function(px, py)
            local lx, ly = sb:getLocalPoint(px, py)
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
    st().swing = { seat = sb, pivot = pivot, zone = z }
end

-- ── the slide park (Nikki 2026-11-15: "can we add a few more slides, can also be in the sky") ──

-- A chute along `points` (its top surface, from the top end to the bottom: the way a Mipo slides), a ribbon
-- 30 thick, slippery, with a slide zone above it that knows the slope where the Mipo is (a bump going up
-- is a negative slope: the legs follow it)
local function chute(points, label)
    local dir = points[#points][1] > points[1][1] and 1 or -1
    local verts = {}
    for _, p in ipairs(points) do verts[#verts + 1], verts[#verts + 2] = p[1], p[2] end
    for i = #points, 1, -1 do verts[#verts + 1], verts[#verts + 2] = points[i][1], points[i][2] + 30 end
    local cx, cy = mathutils.computeCentroid(verts)
    local thing = objectManager.addThing('ribbon', { x = cx, y = cy, vertices = verts, bodyType = 'static',
        label = label or 'chute' })
    if not thing then return end
    for _, f in ipairs(thing.body:getFixtures()) do f:setFriction(0.06) end
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
    return thing
end

-- points from (x0, y0) to (x1, y1), n of them, eased (flat at both ends), with bumps: amp px high, waves of them
local function curve(x0, y0, x1, y1, n, amp, waves, ease)
    local out = {}
    for i = 0, n do
        local t = i / n
        local e = ease and ease(t) or t * t * (3 - 2 * t)
        local bump = (amp or 0) * math.sin(t * math.pi * 2 * (waves or 0)) * 4 * t * (1 - t)
        out[#out + 1] = { x0 + (x1 - x0) * t, y0 + (y1 - y0) * e - bump }
    end
    return out
end

-- a cloud to stand on (a flat white-ish box)
local function cloud(x, y, w)
    local thing = box(x, y, w, 40, 'cloud', 0.9)
    return thing
end

local function slidePark()
    -- the sky tower: a cloud, then three chutes zig-zagging down, a wall at each turn to bounce off
    cloud(12800, -2380, 320)
    -- (flat at the bottom a Mipo stopped there; the next chute's top too near, it got wedged between them,
    -- feet on the next one's flat start: the first steepens to its end, the middle one is one slope, the last
    -- steep at the top and flattening onto the ground, a big drop and the walls well out between them)
    chute(curve(12960, -2400, 14650, -1760, 24, 0, 0, function(t) return 0.3 * t + 0.7 * t * t end), 'sky-chute')
    box(15330, -1600, 40, 700, 'sky-wall')
    chute(curve(15290, -1340, 13150, -760, 28, 0, 0, function(t) return t end), 'sky-chute')
    box(12560, -650, 40, 700, 'sky-wall')
    chute(curve(12620, -400, 15250, 590, 30, 0, 0, function(t) return 1 - (1 - t) ^ 2 end), 'sky-chute')
    -- the bumpy one, from a cloud: long, with humps to fly over
    cloud(15560, -690, 300)
    chute(curve(15710, -700, 18300, 590, 48, 70, 4), 'bumpy-slide')
    -- the steep drop, from a high cloud: nearly straight down, flattening out to launch onto the bumpy one
    cloud(16250, -2590, 300)
    chute(curve(16400, -2600, 17350, -1050, 30, 0, 0, function(t) return math.sin(t * math.pi / 2) ^ 1.6 end),
        'drop-slide')
end

-- ── sports (Nikki 2026-11-15: "maybe some jumping sports to make saltos, skipping rope?") ──

-- a trampoline: a bed on legs (the legs touch nothing), its zone the air above it
local function trampoline(x, w, height)
    local top = GROUND_Y - height
    local bed = box(x, top + 10, w, 20, 'trampoline', 0.9)
    sensors(box(x - w / 2 + 40, GROUND_Y - height / 2, 30, height, 'trampoline-leg'))
    sensors(box(x + w / 2 - 40, GROUND_Y - height / 2, 30, height, 'trampoline-leg'))
    if bed then rectZone('trampoline', bed.body, x - w / 2 + 20, top - 2600, x + w / 2 - 20, top + 10, { top = top }) end
end

-- a skipping mat
local function ropeMat(x, w)
    local mat = box(x, GROUND_Y - 6, w, 12, 'skipping-mat', 0.9)
    if mat then rectZone('rope', mat.body, x - w / 2, GROUND_Y - 1100, x + w / 2, GROUND_Y + 10, { floor = GROUND_Y - 12 }) end
end

-- the playgrounds' middles (left / right arrow): x, y
local PAGES = { { 0, 250 }, { 7750, 250 }, { 15250, -900 }, { 21500, -350 } }

local function ensureScene()
    local c = st()
    if not getObjectsByLabel('ground')[1] then
        local thing = objectManager.addThing('rectangle', { x = 9500, y = GROUND_Y + 300, width = 32000, height = 600,
            bodyType = 'static', label = 'ground' })
        if thing then
            local extra = fixtures.createSFixture(thing.body, 0, 0, 'tile-repeat', { radius = 20 }):getUserData().extra
            extra.main = extra.main or {}
            extra.main.bgURL, extra.opacity, extra.tileWidthM, extra.tileHeightM = 'world/ground/soil-01.jpg', 1, 0.6, 0.6
        end
    end
    if not getObjectsByLabel('slide')[1] then
        rig.clearZones()
        slide(-2900, 1)
        bench(250, 600, 200)
        bar(1300, 700, 1150)
        cushion(2450, 700, 110)
        low(5250, 900, 360, 'table')
        low(6300, 650, 520, 'awning')
        beam(7350, 900, 260)
        ladder(8200, 1400)
        wind(8600, 9500, -900)
        swing(10250, 1400, 400)
        slidePark()
        trampoline(20000, 1100, 160)
        ropeMat(22300, 500)
        ropeMat(23300, 500)
    end -- (else a script reload: the bodies and their zones (on state) are still there)
    c.mipos = mipoKit.alive(c.mipos)
    local spots = { { -2650 }, { 250 }, { 1300 }, { 5800 }, { 9000 }, { 12800, -2800 }, { 15560, -1100 },
        { 16250, -3000 }, { 20000, -400 }, { 22300 }, { 23300 } }
    for i = #c.mipos + 1, #spots do
        mipoKit.spawn(c.mipos, spots[i][1], spots[i][2] or GROUND_Y - 900)
    end
end

local function goPage(i)
    local c = st()
    c.page = math.max(1, math.min(#PAGES, i))
    cam:setScale(0.2)
    cam:setTranslation(PAGES[c.page][1], PAGES[c.page][2])
end

function s.onStart()
    worldState.paused = false
    st()
    ensureScene()
    cam:setScale(0.2)
    goPage(st().page or 1)
end

function s.onUnload()
    rig.unload()
end

function s.onKeyPress(key)
    local c = st()
    if key == 'h' then c.showPanel = not c.showPanel
    elseif key == 'z' then c.showZones = not c.showZones
    elseif key == 'n' then
        local mx = mouseWorldPos()
        mipoKit.spawn(c.mipos, mx, GROUND_Y - 900)
    elseif key == 'left' then goPage((c.page or 1) - 1)
    elseif key == 'right' then goPage((c.page or 1) + 1)
    elseif rig.DRAGS[tonumber(key) or 0] then
        rig.setDrag(rig.DRAGS[tonumber(key)])
    end
end

function s.update(dt)
    rig.update(dt or 1 / 60)
end

-- the swing's ropes, the wind, the zones
function s.draw()
    local sw = st().swing
    if sw and sw.seat and not sw.seat:isDestroyed() then
        love.graphics.setColor(0.55, 0.45, 0.3, 1)
        love.graphics.setLineWidth(8)
        for _, side in ipairs({ -1, 1 }) do
            local ex, ey = sw.seat:getWorldPoint(side * 140, -15)
            love.graphics.line(sw.pivot[1] + side * 140, sw.pivot[2], ex, ey)
        end
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 1)
    end
    rig.drawWind()
    rig.drawRopes()
    if st().showZones then rig.drawZones() end
end

-- ── the panel ──
local P = { w = 400, row = 28, pad = 10 }
local SLIDERS = {
    { 'kp', 'pose muscles', 2, 40, 1 }, { 'maxOmega', 'pose speed', 1, 20, 0.5 }, { 'lean', 'slide: lean back', -20, 40, 1 },
    { 'reach', 'bar: grip reach', 10, 120, 5 }, { 'grip', 'bar: grip (x weight)', 0.5, 8, 0.1 },
    { 'pullAway', 'bar: pull away', 100, 1000, 10 }, { 'poseStiff', 'pose: stiffness', 0.02, 2, 0.01 },
    { 'crawlAt', 'crawl below (x height)', 0.2, 1.2, 0.02 }, { 'sway', 'beam: sway', 0, 20, 0.5 },
    { 'wind', 'wind (x weight)', 0, 1.5, 0.02 }, { 'pump', 'swing: push', 0, 0.6, 0.01 },
    { 'bounce', 'trampoline (x height)', 0.3, 3, 0.05 }, { 'saltoEvery', 'salto every n bounces', 0, 4, 1 },
    { 'ropeSpeed', 'rope turns / s', 0.3, 2.5, 0.05 },
}
function s.drawUI()
    local c = st()
    if not c.showPanel then return end
    ui.startFrame()
    local sw, sh = ui.getDimensions()
    local w, h = P.w, P.row * (#SLIDERS + 5) + 48
    local x0, y0 = sw - w - 16, math.max(12, (sh - h) / 2)
    ui.panel(x0, y0, w, h, '•• rig zones ••', function()
        local x, y = x0 + P.pad, y0 + 32
        local inner = w - P.pad * 2
        ui.label(x, y + 5, 'drag a Mipo:')
        y = y + P.row
        local n = #rig.DRAGS
        local bw = (inner - (n - 1) * 6) / n
        local current = rig.data().drag
        for i, name in ipairs(rig.DRAGS) do
            if ui.button(x + (i - 1) * (bw + 6), y, bw, i .. ' ' .. name, nil, current == name and { 0.5, 0.4, 0.3 } or nil) then
                rig.setDrag(name)
            end
        end
        y = y + P.row + 6
        local zc, zv = ui.checkbox(x, y + 2, c.showZones, 'show the zones (z)')
        if zc then c.showZones = zv end
        y = y + P.row
        local t = rig.tuning
        for _, sl in ipairs(SLIDERS) do
            ui.label(x, y + 5, sl[2])
            local value = ui.sliderWithInput('rig-' .. sl[1], x + 150, y - 4, inner - 240, sl[3], sl[4], t[sl[1]], nil, sl[5])
            if value then t[sl[1]] = value + 0 end
            y = y + P.row
        end
        local bw3 = (inner - 18) / 4
        for i, name in ipairs({ 'play', 'more', 'slides', 'sports' }) do
            if ui.button(x + (i - 1) * (bw3 + 6), y, bw3, name, nil, c.page == i and { 0.5, 0.4, 0.3 } or nil) then
                goPage(i)
            end
        end
        y = y + P.row + 4
        ui.label(x, y + 5, '1-4 drag  arrows  z zones  n Mipo  h')
    end)
end

return s

-- drawn-sea: the sea spike's water (wave columns, swell, real floating, splashes) drawn the boat's way (flat bands in layers, a crayon crest)
-- The best of the two seas: from `sea` the near water is a row of columns with the wave equation
-- and a swell, and everything floats for real (the wet part of each fixture pushes up at its
-- middle), so the plank boat (boat2's) rocks under the Mipos, rights itself, splashes; from `boat`
-- it's drawn: flat bands in layers (far ones with only the swell, the water just behind the boat,
-- the near water see-through over the hull, a deep band), the hand-made wobble on their edges,
-- the crest one of Nikki's crayon lines bent onto the water, foam and drops as drawn blobs. No
-- shader. The world flows by with the speed (the columns are moved along, so a splash or a Mipo
-- overboard drifts behind); an engine holds the boat in place, so speeding up makes it surge.
--
-- play mode (tab): drag the Mipos about, throw one in.
-- With the optics on (o), the near water is the sea spike's shader instead of a see-through band:
-- what's under the surface bent, tinted with depth, caustics, light shafts, the silvery underside.
-- keys: left / right slower / faster   m a Mipo   w a wave   o optics / drawn bands   c crayon crest   b boil
--       r build the boat again   h the panel

local s = {}

local SHAPES = love.filesystem.load('scripts/spikes/boat-shapes.lua')()
local SCROLL = 140           -- world units a second per step of speed
local WATER_Y = -60          -- the waves' middle line
local BOAT_Y = 60            -- where the boat starts (its keel); then it floats

local function boat()
    state.drawnSea = state.drawnSea or {
        mipos = {}, showPanel = true, speed = 1, target = 1, pos = 0, time = 0, accel = 0,
        smoke = {}, smokeTimer = 0, fish = {}, clouds = {}, buoyX = 1800,
        drops = {}, bubbles = {}, wet = {},
        settings = { swell = 1, density = 1.6, drag = 1.2, boatFloat = 1, sway = 1, clear = 0.55, crest = 10,
            width = 9, wobble = 1.2, wonk = 1, boil = false },
    }
    local set = state.drawnSea.settings -- the optics came later: live states lack them
    local optics = { optics = true, clarity = 1, refraction = 1, caustics = 1, rays = 1, mirror = 1, blur = 1, specks = 1,
        farLit = true, copyEach = false, farMurk = 0.72, farTint = 1.04, -- Nikki's, 2026-11-16
        horizonPale = 0.6, rampCurve = 1.14, nearTint = 0.7, nearMurk = 0.75 }
    for k, v in pairs(optics) do if set[k] == nil then set[k] = v end end
    return state.drawnSea
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

-- a fixed hand-made wobble per point, like walter-boat's wave_offsets
local JITTER = {}
for i = 1, 400 do JITTER[i] = love.math.random() * 6 - 3 end

---------------------------------------------------------------- the near water: columns (from the sea spike)

-- The water the boat floats in is a row of columns with the wave equation (a splash runs off both
-- ways) plus the sea spike's swell (three travelling waves, sharper crests than troughs). The
-- water flows past the boat with its speed: the columns are moved along, so a splash drifts
-- behind. The ends let waves out (the world goes on past the screen).
local DX = 40
local X0 = -3400
local COLS = 170
local SWELLS = {
    { a = 30, len = 2100, phase = 0.0, dir = 1 },
    { a = 16, len = 950, phase = 1.3, dir = -1 },
    { a = 7, len = 410, phase = 2.1, dir = 1 },
}

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

local function swellUp(x, t, scale)
    local g = 9.8 * love.physics.getMeter()
    local up = 0
    for _, w in ipairs(SWELLS) do
        local k = 2 * math.pi / w.len
        local th = k * x - w.dir * math.sqrt(g * k) * 0.6 * t + w.phase
        up = up + w.a * (math.sin(th) - 0.22 * math.cos(2 * th))
    end
    return up * scale
end

local function columns(b)
    b.h = b.h or {}
    b.v = b.v or {}
    b.surf = b.surf or {}
    b.surfVel = b.surfVel or {}
    b.foam = b.foam or {}
    for i = 0, COLS do
        b.h[i] = b.h[i] or 0
        b.v[i] = b.v[i] or 0
        b.foam[i] = b.foam[i] or 0
    end
end

local function surfaceAt(b, x)
    local f = (x - X0) / DX
    local i = math.floor(f)
    if i < 0 then return b.surf[0] or WATER_Y end
    if i >= COLS then return b.surf[COLS] or WATER_Y end
    local t = f - i
    return (b.surf[i] or WATER_Y) * (1 - t) + (b.surf[i + 1] or WATER_Y) * t
end

local function surfaceVelAt(b, x)
    local i = clamp(math.floor((x - X0) / DX + 0.5), 0, COLS)
    return b.surfVel[i] or 0
end

local function pushColumns(b, x1, x2, dv)
    local i1 = clamp(math.floor((x1 - X0) / DX), 0, COLS)
    local i2 = clamp(math.ceil((x2 - X0) / DX), 0, COLS)
    for i = i1, i2 do b.v[i] = b.v[i] + dv end
end

local STEP = 1 / 120
local function waves(b, dt)
    local c2 = 1300 * 1300 / (DX * DX)
    -- the flow: move the columns along with the travel
    b.shift = (b.shift or 0) + b.speed * SCROLL * dt / DX
    while b.shift >= 1 do
        for i = 0, COLS - 1 do b.h[i], b.v[i], b.foam[i] = b.h[i + 1], b.v[i + 1], b.foam[i + 1] end
        b.h[COLS], b.v[COLS], b.foam[COLS] = 0, 0, 0
        b.shift = b.shift - 1
    end
    while b.shift <= -1 do
        for i = COLS, 1, -1 do b.h[i], b.v[i], b.foam[i] = b.h[i - 1], b.v[i - 1], b.foam[i - 1] end
        b.h[0], b.v[0], b.foam[0] = 0, 0, 0
        b.shift = b.shift + 1
    end
    b.acc = (b.acc or 0) + math.min(dt, 0.05)
    while b.acc >= STEP do
        b.acc = b.acc - STEP
        local h, v = b.h, b.v
        for i = 0, COLS do
            local l = h[i - 1] or h[i]
            local r = h[i + 1] or h[i]
            -- near the ends the water calms, so waves leave instead of bouncing back
            local edge = math.min(i, COLS - i)
            local calm = edge < 12 and (12 - edge) * 0.8 or 0
            local a = c2 * (l + r - 2 * h[i]) - 6 * h[i] - (1.4 + calm) * v[i]
            v[i] = v[i] + a * STEP
        end
        for i = 0, COLS do h[i] = clamp(h[i] + v[i] * STEP, -500, 500) end
    end
    local swell = b.settings.swell
    for i = 0, COLS do
        local x = X0 + i * DX
        local prev = b.surf[i]
        local surf = WATER_Y + b.h[i] - swellUp(x + b.pos, b.time, swell)
        b.surf[i] = surf
        b.surfVel[i] = prev and (surf - prev) / math.max(dt, 1e-3) or 0
        local stir = math.abs(b.v[i]) / 600
        local slope = math.abs(((b.surf[i - 1] or surf) - surf) / DX)
        b.foam[i] = math.max(b.foam[i] * math.exp(-dt * 0.8), clamp(stir + math.max(slope - 0.12, 0) * 3, 0, 1))
    end
end

---------------------------------------------------------------- the optics (the sea spike's water shader)

-- Under the surface the world is seen through water: everything is drawn into a canvas first,
-- then the water shader draws the near water over it: what's under it bent, red then green taken out
-- with depth, caustics on things, slanted light shafts, specks, the silvery underside of the
-- surface. The engine's shader (src/render/water-shader.lua, `waterLook`; this was a copy of the sea
-- spike's, the same as the engine's at the sea's values: viewDepth 450, bend 1, causticSize 1, no tint).
-- The far layers too (f, Nikki 2026-11-16: "so the waves in the distance also get the shinyness"): each
-- far band through the shader, smaller with distance (caustics, bending), its own drawn colour as murk,
-- so it keeps the drawn look and gets the bright line, glints and specks; each one bends what was drawn
-- before it, which takes a copy of the canvas per layer (g: one copy for all, to see what that costs).
local function sendWater(sh, set, scene, o)
    sh:send('scene', scene)
    sh:send('time', state.drawnSea.time)
    sh:send('pxPerWorld', cam:getScale() * love.graphics.getDPIScale())
    sh:send('clarity', set.clarity)
    sh:send('refraction', set.refraction)
    sh:send('caustics', set.caustics)
    sh:send('rays', set.rays)
    sh:send('mirror', set.mirror)
    sh:send('blur', set.blur)
    sh:send('specks', set.specks)
    sh:send('viewDepth', o and o.viewDepth or 450)
    sh:send('bend', o and o.bend or 1)
    sh:send('causticSize', o and o.causticSize or 1)
    sh:send('tint', o and o.tint or { 1, 1, 1 })
    sh:send('tintAmount', o and o.tintAmount or 0)
    sh:send('murk', o and o.murk or 0)
end



local waterMesh = love.graphics.newMesh({
    { 'VertexPosition', 'float', 2 }, { 'VertexTexCoord', 'float', 2 },
    { 'SurfY', 'float', 1 }, { 'Foam', 'float', 1 }, { 'Slope', 'float', 1 },
}, (COLS + 1) * 2, 'strip', 'stream')
local waterVerts = {}
local function updateWaterMesh(b, bottom)
    for i = 0, COLS do
        local x = X0 + i * DX
        local surf = b.surf[i] or WATER_Y
        local foam = b.foam[i] or 0
        local slope = ((b.surf[i + 1] or surf) - (b.surf[i - 1] or surf)) / (2 * DX)
        local k = i * 2
        waterVerts[k + 1] = waterVerts[k + 1] or {}
        waterVerts[k + 2] = waterVerts[k + 2] or {}
        local top, bot = waterVerts[k + 1], waterVerts[k + 2]
        top[1], top[2], top[3], top[4], top[5], top[6], top[7] = x, surf, 0, 0, surf, foam, math.abs(slope)
        bot[1], bot[2], bot[3], bot[4], bot[5], bot[6], bot[7] = x, math.max(bottom, surf + 10), 0, 1, surf, foam, math.abs(slope)
    end
    waterMesh:setVertices(waterVerts)
end

local sceneCanvas, prevCanvas, farCopy
local function ensureCanvas()
    local w, h = love.graphics.getDimensions()
    if not sceneCanvas or sceneCanvas:getWidth() ~= w or sceneCanvas:getHeight() ~= h then
        local _, _, flags = love.window.getMode()
        sceneCanvas = love.graphics.newCanvas(w, h, { msaa = flags.msaa or 0 })
        farCopy = love.graphics.newCanvas(w, h)
    end
end

-- what's in the scene canvas so far, into farCopy (a shader can't read the canvas it draws on)
local function copyScene()
    love.graphics.push('all')
    love.graphics.setCanvas(farCopy)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode('replace', 'premultiplied')
    love.graphics.draw(sceneCanvas, 0, 0)
    love.graphics.pop()
end

---------------------------------------------------------------- floating (from the sea spike)

local clipOut = {}
local function clipUnder(poly, n, x1, y1, x2, y2)
    local slope = (x2 ~= x1) and (y2 - y1) / (x2 - x1) or 0
    local m = 0
    local px, py = poly[n * 2 - 1], poly[n * 2]
    local pf = py - (y1 + (px - x1) * slope)
    for k = 1, n do
        local cx, cy = poly[k * 2 - 1], poly[k * 2]
        local cf = cy - (y1 + (cx - x1) * slope)
        if cf >= 0 then
            if pf < 0 then
                local t = pf / (pf - cf)
                clipOut[m + 1], clipOut[m + 2] = px + (cx - px) * t, py + (cy - py) * t
                m = m + 2
            end
            clipOut[m + 1], clipOut[m + 2] = cx, cy
            m = m + 2
        elseif pf >= 0 then
            local t = pf / (pf - cf)
            clipOut[m + 1], clipOut[m + 2] = px + (cx - px) * t, py + (cy - py) * t
            m = m + 2
        end
        px, py, pf = cx, cy, cf
    end
    return clipOut, m / 2
end

local function areaCentroid(poly, n)
    local a, cx, cy = 0, 0, 0
    for k = 1, n do
        local x1, y1 = poly[k * 2 - 1], poly[k * 2]
        local j = (k % n) + 1
        local x2, y2 = poly[j * 2 - 1], poly[j * 2]
        local cr = x1 * y2 - x2 * y1
        a = a + cr
        cx = cx + (x1 + x2) * cr
        cy = cy + (y1 + y2) * cr
    end
    if math.abs(a) < 1e-6 then return 0, 0, 0 end
    return math.abs(a) / 2, cx / (3 * a), cy / (3 * a)
end

local polyBuf = {}
local function fixturePolygon(body, shape)
    local kind = shape:type()
    if kind == 'PolygonShape' then
        local pts = { body:getWorldPoints(shape:getPoints()) }
        for k = 1, #pts do polyBuf[k] = pts[k] end
        return polyBuf, #pts / 2
    elseif kind == 'CircleShape' then
        local cx, cy = body:getWorldPoint(shape:getPoint())
        local r = shape:getRadius()
        for k = 0, 11 do
            local a = k / 12 * math.pi * 2
            polyBuf[k * 2 + 1], polyBuf[k * 2 + 2] = cx + math.cos(a) * r, cy + math.sin(a) * r
        end
        return polyBuf, 12
    end
    return nil, 0
end

local function splash(b, x, y, width, vy, into)
    local strength = clamp(math.abs(vy), 0, 2500)
    pushColumns(b, x - width / 2, x + width / 2, (into and 1 or -0.5) * vy * 0.3 * clamp(width / 400, 0.3, 1))
    for _ = 1, math.floor(strength / 110) do
        local sx = x + (love.math.random() - 0.5) * width
        local side = (sx - x) / math.max(width, 1)
        b.drops[#b.drops + 1] = { x = sx, y = surfaceAt(b, sx) - 5,
            vx = side * strength * 0.9 + (love.math.random() - 0.5) * 300,
            vy = -strength * (0.35 + love.math.random() * 0.5), r = 8 + love.math.random() * 14, life = 2 }
    end
    if into then
        for _ = 1, math.floor(strength / 80) do
            b.bubbles[#b.bubbles + 1] = { x = x + (love.math.random() - 0.5) * width, y = y + love.math.random() * 250,
                r = 5 + love.math.random() * 14, phase = love.math.random() * 6, life = 5 }
        end
    end
end

-- every dynamic body: the wet part of each fixture pushes up at its middle (that rights the
-- boat); drag against the water, which moves with the waves and flows past with the travel (the
-- boat has its engine: no flow for it)
local function float(b, dt)
    local _, gy = state.physicsWorld:getGravity()
    local set = b.settings
    local flow = -b.speed * SCROLL
    for _, body in ipairs(state.physicsWorld:getBodies()) do repeat
        if body:getType() ~= 'dynamic' or body:isDestroyed() then break end
        local bx, by = body:getPosition()
        if bx < X0 - 2000 or bx > X0 + COLS * DX + 2000 then break end
        local isBoat = body == b.body or body == b.chimneyBody
        local wetArea, totalArea = 0, 0
        local minX, maxX = math.huge, -math.huge
        for _, fixture in ipairs(body:getFixtures()) do repeat
            if fixture:isSensor() then break end
            local _, _, mass = fixture:getMassData()
            if mass <= 0 then break end
            local poly, n = fixturePolygon(body, fixture:getShape())
            if n < 3 then break end
            local x1, x2, maxY = math.huge, -math.huge, -math.huge
            for k = 1, n do
                local x, y = poly[k * 2 - 1], poly[k * 2]
                if x < x1 then x1 = x end
                if x > x2 then x2 = x end
                if y > maxY then maxY = y end
            end
            local full = areaCentroid(poly, n)
            totalArea = totalArea + full
            local s1, s2 = surfaceAt(b, x1), surfaceAt(b, x2)
            if maxY <= math.min(s1, s2) then break end
            local clipped, m = clipUnder(poly, n, x1, s1, x2, s2)
            if m < 3 then break end
            local area, cx, cy = areaCentroid(clipped, m)
            if area <= 0 or full <= 0 then break end
            local frac = math.min(area / full, 1)
            wetArea = wetArea + area
            if x1 < minX then minX = x1 end
            if x2 > maxX then maxX = x2 end
            -- the boat is pushed by its wet area (the water it moves aside), not its mass: its
            -- ballast is heavy and its planks light; the rest by mass, as in the sea spike
            local up = (body == b.body and b.boatRho) and area * b.boatRho * gy * set.boatFloat
                or mass * gy * frac * set.density
            local vx, vy = body:getLinearVelocityFromWorldPoint(cx, cy)
            local depth = cy - surfaceAt(b, cx)
            local wvy = surfaceVelAt(b, cx) * math.exp(-math.max(depth, 0) / 400)
            local k = mass * frac * set.drag
            local wvx = isBoat and 0 or flow
            body:applyForce(-(vx - wvx) * k, -up - (vy - wvy) * k, cx, cy)
        until true end
        local wetFrac = totalArea > 0 and wetArea / totalArea or 0
        if wetFrac > 0 then
            body:applyTorque(-body:getInertia() * body:getAngularVelocity() * set.drag * 0.8 * wetFrac)
        end
        local was = b.wet[body] or 0
        if wetFrac > 0 and was == 0 then
            local _, vy = body:getLinearVelocity()
            if vy > 250 then splash(b, bx, by, math.max(maxX - minX, 100), vy, true) end
        elseif wetFrac == 0 and was > 0 then
            local _, vy = body:getLinearVelocity()
            if vy < -400 then splash(b, bx, by, 200, vy, false) end
        elseif wetFrac > 0 and wetFrac < 0.95 and maxX > minX then
            local _, vy = body:getLinearVelocity()
            pushColumns(b, minX, maxX, vy * dt * 0.5 * wetFrac)
        end
        b.wet[body] = wetFrac
    until true end
end

local function particles(b, dt)
    local _, gy = state.physicsWorld:getGravity()
    local keep = {}
    for _, d in ipairs(b.drops) do
        d.vy = d.vy + gy * dt
        d.x, d.y = d.x + (d.vx - b.speed * SCROLL * 0.5) * dt, d.y + d.vy * dt
        d.life = d.life - dt
        if d.vy > 0 and d.y > surfaceAt(b, d.x) then
            pushColumns(b, d.x, d.x, d.r * 1.5)
        elseif d.life > 0 then
            keep[#keep + 1] = d
        end
    end
    b.drops = keep
    keep = {}
    for _, bb in ipairs(b.bubbles) do
        bb.y = bb.y - (120 + bb.r * 9) * dt
        bb.x = bb.x + (math.sin(b.time * 5 + bb.phase) * 60 - b.speed * SCROLL) * dt
        bb.life = bb.life - dt
        if bb.y > surfaceAt(b, bb.x) + bb.r and bb.life > 0 then keep[#keep + 1] = bb end
    end
    b.bubbles = keep
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
        hidden = opts.hidden, chimney = opts.chimney, ballast = opts.ballast }
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
        -- ballast: the bottom rows heavy, the rest light, so it sits upright and rights itself
        local ballast = (i == rows - 1 and 3) or (i == rows - 2 and 1.2) or 0.2
        quad(b, { sternX(yt), yt, bowX(yt), yt, bowX(yb), yb, sternX(yb), yb },
            { color = color, solid = true, ballast = ballast })
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
        bodyType = 'dynamic', label = 'drawn-sea-boat' })
    if not thing then return end
    local body = thing.body
    for _, fixture in ipairs(body:getFixtures()) do fixture:destroy() end
    for _, p in ipairs(b.planks) do
        local ok, shape = pcall(love.physics.newPolygonShape, p.pts)
        if ok and not p.chimney then
            -- light planks above the ballast, so the Mipos' weight tips it; the sensors weigh nothing
            local fixture = love.physics.newFixture(body, shape, p.solid and (p.ballast or 0.1) or 0)
            fixture:setFriction(0.9)
            -- the cabin's back wall and the railing: the engine's depth layers, per fixture (one body): Mipos
            -- pass in front of the back wall and can stand on its tops, never touch the railing
            if p.layer == 'back' or p.layer == 'front' then
                depthLayers.setFixtureLayer(fixture, p.layer)
            elseif not p.solid then
                fixture:setSensor(true)
            end
        end
    end
    body:setAngularDamping(0.5)
    -- how much push per unit of wet area: enough that it floats about 40% of its solid area deep
    local solidArea = 0
    for _, fixture in ipairs(body:getFixtures()) do
        if fixture:getDensity() > 0 then -- the solid planks (the layered ones weigh nothing)
            local poly, n = fixturePolygon(body, fixture:getShape())
            if n >= 3 then solidArea = solidArea + areaCentroid(poly, n) end
        end
    end
    b.boatRho = solidArea > 0 and body:getMass() / (solidArea * 0.4) or nil
    b.body = body
    -- the chimney: its own body, light, on a springy weld at the roof, so it wobbles when the
    -- boat rocks and a Mipo can bump it or tug it
    local chim = objectManager.addThing('rectangle', { x = 0, y = BOAT_Y, width = 10, height = 10,
        bodyType = 'dynamic', label = 'drawn-sea-chimney' })
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
        local id = 'drawn-sea-chimney-weld-' .. tostring(love.math.random(1e6))
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
    columns(b)
    makeBoat(b)
    b.mipos = aliveMipos(b)
    if #b.mipos == 0 then
        spawnMipo(b, -60, -1000)
        spawnMipo(b, 320, -1000)
    end
    if #b.fish == 0 then
        for i = 1, 7 do
            local dir = love.math.random() < 0.5 and -1 or 1
            b.fish[i] = { kind = love.math.random(#SHAPES.fish), x = rnd(-1500, 1500), y = rnd(280, 540),
                dir = dir, speed = rnd(60, 140), size = rnd(1.4, 2.2), wiggle = rnd(0, 6) }
        end
    end
    if #b.clouds == 0 then
        for i = 1, 6 do
            b.clouds[i] = { kind = love.math.random(#SHAPES.clouds), x = rnd(-1800, 1800), y = rnd(-1600, -1000),
                size = rnd(2.5, 4), drift = rnd(0.15, 0.35) }
        end
    end
end

function s.onUnload()
    local b = state.drawnSea
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
    elseif key == 'w' then pushColumns(b, X0 + (COLS - 30) * DX, X0 + (COLS - 18) * DX, -700) -- a wave comes in
    elseif key == 'b' then b.settings.boil = not b.settings.boil
    elseif key == 'o' then
        b.settings.optics = not b.settings.optics
        b.settings.crestLine = not b.settings.optics
    elseif key == 'c' then b.settings.crestLine = not b.settings.crestLine
    elseif key == 'f' then b.settings.farLit = not b.settings.farLit
    elseif key == 'g' then b.settings.copyEach = not b.settings.copyEach
    elseif key == 'r' then -- build the boat again (another wonk)
        if b.chimneyBody and not b.chimneyBody:isDestroyed() then objectManager.destroyBody(b.chimneyBody) end
        if b.body and not b.body:isDestroyed() then objectManager.destroyBody(b.body) end
        b.body, b.chimneyBody = nil, nil
        makeBoat(b)
    elseif key == 'h' then b.showPanel = not b.showPanel
    end
end

function s.update(dt)
    local b = state.drawnSea
    if not b or dt <= 0 or worldState.paused then return end
    columns(b)
    local set = b.settings
    b.time = b.time + dt
    local before = b.speed
    b.speed = b.speed + (b.target - b.speed) * math.min(1, dt * 0.9)
    local accel = (b.speed - before) / dt
    b.accel = b.accel + (accel - b.accel) * math.min(1, dt * 4)
    b.pos = b.pos + b.speed * SCROLL * dt

    waves(b, dt)
    float(b, dt)
    particles(b, dt)

    local gx, gy = state.physicsWorld:getGravity()
    local g = math.sqrt(gx * gx + gy * gy)
    -- the engine holds the boat where it is (a spring on x); a change of speed pushes everything
    -- aboard the other way, so the boat surges and the Mipos sway
    local aboard = {}
    if b.body and not b.body:isDestroyed() then
        local body = b.body
        local m = body:getMass()
        local x = body:getPosition()
        local vx = body:getLinearVelocity()
        local cx, cy = body:getWorldCenter()
        body:applyForce((-x * 2.5 - vx * 2.5) * m, 0, cx, cy)
        aboard[#aboard + 1] = body
        if b.chimneyBody and not b.chimneyBody:isDestroyed() then aboard[#aboard + 1] = b.chimneyBody end
    end
    b.mipos = aliveMipos(b)
    for _, inst in ipairs(b.mipos) do
        for _, body in ipairs(partBodies(inst)) do aboard[#aboard + 1] = body end
    end
    for _, body in ipairs(aboard) do
        body:applyForce(-b.accel * body:getMass() * g * 0.12 * set.sway, 0)
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
    for _, f in ipairs(b.fish) do
        f.x = f.x + (f.dir * f.speed - b.speed * SCROLL) * dt
        if f.x < -2200 or f.x > 2200 then
            f.dir = f.x < 0 and 1 or -1
            f.x = f.x < 0 and -2100 or 2100
            f.y = rnd(280, 540)
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

-- a band of water from a line y(x) down to the bottom (a number, or a function of x), flat colour,
-- the hand-made wobble on its edge
local bandMesh
local function drawBand(yAt, color, alpha, x0, x1, bottom, step)
    step = step or 40
    local verts = {}
    local px, py, pb
    for i = math.floor(x0 / step) - 1, math.ceil(x1 / step) + 1 do
        local x = i * step
        local y = yAt(x) + JITTER[(i % #JITTER) + 1]
        local by = tonumber(bottom) or bottom(x) -- (no type() in a scene script)
        if px then
            verts[#verts + 1] = { px, py }; verts[#verts + 1] = { x, y }; verts[#verts + 1] = { px, pb }
            verts[#verts + 1] = { x, y }; verts[#verts + 1] = { x, by }; verts[#verts + 1] = { px, pb }
        end
        px, py, pb = x, y, by
    end
    if #verts < 3 then return end
    if not bandMesh or bandMesh:getVertexCount() < #verts then
        if bandMesh then bandMesh:release() end
        bandMesh = love.graphics.newMesh({ { 'VertexPosition', 'float', 2 } }, #verts + 60, 'triangles', 'stream')
    end
    bandMesh:setVertices(verts)
    bandMesh:setDrawRange(1, #verts)
    love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
    love.graphics.draw(bandMesh)
end

-- A far band through the water shader: from its line y(x) down to bottom(x), the shader reading `scene`
-- (what was drawn before it). far: 0 near .. 1 far, smaller caustics and bending; its colour as murk.
local litMesh
local litVerts = {}
local function drawLitBand(b, yAt, color, far, x0, x1, bottom, scene)
    local step = 40
    local first, last = math.floor(x0 / step) - 1, math.ceil(x1 / step) + 1
    local n = last - first + 1
    if not litMesh or litMesh:getVertexCount() < n * 2 then
        litMesh = love.graphics.newMesh(waterLook.CUP_FORMAT, n * 2 + 40, 'strip', 'stream')
    end
    local ys = {}
    for i = first - 1, last + 1 do ys[i] = yAt(i * step) + JITTER[(i % #JITTER) + 1] end
    for i = first, last do
        local x, y = i * step, ys[i]
        local slope = math.abs((ys[i + 1] - ys[i - 1]) / (2 * step))
        local k = (i - first) * 2
        litVerts[k + 1] = litVerts[k + 1] or {}
        litVerts[k + 2] = litVerts[k + 2] or {}
        local top, bot = litVerts[k + 1], litVerts[k + 2]
        top[1], top[2], top[3], top[4], top[5], top[6], top[7] = x, y, 0, 0, y, 0, slope
        bot[1], bot[2], bot[3], bot[4], bot[5], bot[6], bot[7] = x, math.max(bottom(x), y + 4), 0, 1, y, 0, slope
    end
    for k = n * 2 + 1, #litVerts do litVerts[k] = nil end
    litMesh:setVertices(litVerts)
    litMesh:setDrawRange(1, n * 2)
    local sh = waterLook.shader()
    love.graphics.setShader(sh)
    local scale = 1 - 0.6 * far
    sendWater(sh, b.settings, scene, { viewDepth = 450, bend = scale, causticSize = scale, tint = color,
        tintAmount = b.settings.farTint, murk = b.settings.farMurk })
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(litMesh)
    love.graphics.setShader()
end

-- the crest: one of Nikki's crayon lines along the near surface. Made once as a straight line,
-- bent onto the water every frame (its picture and wobble stay put, the water moves under them)
local crest
local function drawCrest(b)
    if #STROKE.strokes == 0 then return end
    local key = table.concat({ b.settings.crest, b.settings.wobble }, ',')
    if not crest or crest.key ~= key then
        local pts = {}
        for x = X0, X0 + COLS * DX, 12 do pts[#pts + 1] = { x, 0 } end
        local meshes = STROKE.meshes({ { pts = pts, loop = false, width = b.settings.crest, wobble = 0.5 } },
            b.settings.wobble, 0, true)
        crest = { key = key, parts = {} }
        for _, mesh in ipairs(meshes) do
            local base = {}
            for i = 1, mesh:getVertexCount() do
                local x, y, u, v = mesh:getVertex(i)
                base[i] = { x, y, u, v }
            end
            crest.parts[#crest.parts + 1] = { mesh = mesh, base = base, out = {} }
        end
    end
    love.graphics.setColor(0.93, 0.97, 1, 0.9)
    for _, part in ipairs(crest.parts) do
        local out = part.out
        for i, v in ipairs(part.base) do
            local o = out[i]
            if not o then o = {}; out[i] = o end
            o[1], o[2], o[3], o[4] = v[1], v[2] + surfaceAt(b, v[1]), v[3], v[4]
        end
        part.mesh:setVertices(out)
        love.graphics.draw(part.mesh)
    end
end

-- The waterline. A soft sheen of foam where the water's stirred (fading down into the water,
-- coming and going with the foam), a soft glow, and a smooth glassy line on top; or, on `c`
-- (the drawn bands' default), Nikki's crayon line.
local sheenMesh = love.graphics.newMesh({ { 'VertexPosition', 'float', 2 }, { 'VertexColor', 'byte', 4 } },
    (COLS + 1) * 2, 'strip', 'stream')
local sheenVerts = {}
local function drawSurface(b, x0, x1)
    local set = b.settings
    if set.crestLine == nil then set.crestLine = not set.optics end
    if set.crestLine then drawCrest(b) return end
    local px = 1 / cam:getScale()
    for i = 0, COLS do
        local x = X0 + i * DX
        local y = b.surf[i]
        local f = math.min(1, b.foam[i] * 1.3)
        local k = i * 2
        sheenVerts[k + 1] = sheenVerts[k + 1] or {}
        sheenVerts[k + 2] = sheenVerts[k + 2] or {}
        local t, u = sheenVerts[k + 1], sheenVerts[k + 2]
        t[1], t[2], t[3], t[4], t[5], t[6] = x, y - 2 * px, 1, 1, 1, 0.15 + f * 0.6
        u[1], u[2], u[3], u[4], u[5], u[6] = x, y + (10 + f * 40) * px, 1, 1, 1, 0
    end
    sheenMesh:setVertices(sheenVerts)
    love.graphics.setColor(0.92, 0.98, 1, 1)
    love.graphics.draw(sheenMesh)
    -- the line: points every half column, smoothed between them
    local pts = {}
    local step = DX / 2
    local first = math.max(0, math.floor((x0 - X0) / step) - 2)
    local last = math.min(COLS * 2, math.ceil((x1 - X0) / step) + 2)
    for j = first, last do
        local x = X0 + j * step
        pts[#pts + 1] = x
        pts[#pts + 1] = surfaceAt(b, x)
    end
    if #pts >= 4 then
        love.graphics.setLineStyle('smooth')
        love.graphics.setLineJoin('none')
        love.graphics.setColor(0.85, 0.96, 1, 0.25)
        love.graphics.setLineWidth(7 * px)
        love.graphics.line(pts)
        love.graphics.setColor(0.96, 1, 1, 0.85)
        love.graphics.setLineWidth(2.2 * px)
        love.graphics.line(pts)
        love.graphics.setLineJoin('miter')
        love.graphics.setLineWidth(1)
    end
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

local INK = { 0.17, 0.12, 0.1 }
local FAR_FIRST = { 0.62, 0.78, 0.88 } -- the far band's drawn colour (FAR[1])
-- The lit water's colours, one ramp from the horizon to the near water (Nikki 2026-11-16: "front is cyan, then
-- darker going to cyan" felt funky). As painters do it: at the horizon the sea takes the sky's colour (pale,
-- muted: it mostly mirrors the sky at that grazing angle), toward us deeper and more saturated, the near water
-- the deepest (its bright line and the see-through just under it stay). t: 0 horizon .. 1 near.
-- horizonPale: how close the horizon end goes to the sky; rampCurve: how soon it deepens.
local SKY = { 0.67, 0.83, 0.92 }
local DEEP_SEA = { 0.06, 0.2, 0.45 }
local function rampColor(set, t)
    local a = {}
    for k = 1, 3 do a[k] = FAR_FIRST[k] + (SKY[k] - FAR_FIRST[k]) * set.horizonPale end
    local u = t ^ set.rampCurve
    return { a[1] + (DEEP_SEA[1] - a[1]) * u, a[2] + (DEEP_SEA[2] - a[2]) * u, a[3] + (DEEP_SEA[3] - a[3]) * u }
end
local FAR = { { 0.62, 0.78, 0.88 }, { 0.46, 0.66, 0.84 } }
local BEHIND = { 0.33, 0.55, 0.79 }
local NEAR = { 0.18, 0.4, 0.7 }
local DEEP = { 0.12, 0.27, 0.52 }

function s.drawBelow()
    local b = state.drawnSea
    if not b then return end
    columns(b)
    local d = drawings()
    local x0, _, x1, y1 = view()
    -- with the optics, the world goes into a canvas the water can bend (the sky too: the lit far
    -- layers bend it)
    if b.settings.optics then
        ensureCanvas()
        prevCanvas = love.graphics.getCanvas()
        love.graphics.setCanvas({ sceneCanvas, stencil = true })
        love.graphics.clear(0, 0, 0, 0)
    end
    love.graphics.push()
    love.graphics.origin()
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(0.67, 0.83, 0.92)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.pop()
    for _, c in ipairs(b.clouds) do
        love.graphics.push()
        love.graphics.translate(c.x, c.y)
        love.graphics.scale(c.size)
        drawShape(d.clouds[c.kind], 0.6)
        love.graphics.pop()
    end
    -- far bands: only the swell, slower and smaller (parallax). With the optics they stop at the
    -- near surface: under it is the water's own (the shader lit them up like a wall)
    local bottom = b.settings.optics and function(x) return surfaceAt(b, x) + 4 end or y1 + 50
    local bands = {
        { function(x) return waveY(LAYERS[1], x, b) end, FAR[1], 1, 0 },
        { function(x) return waveY(LAYERS[2], x, b) end, FAR[2], 0.7, 0.25 },
        -- the water just behind the boat: the near surface, a little higher and calmer
        { function(x) return (surfaceAt(b, x) - WATER_Y) * 0.7 + WATER_Y - 38 end, BEHIND, 0.4, 0.5 },
    }
    local set = b.settings
    b.copies = 0
    for i, band in ipairs(bands) do
        if set.optics and set.farLit then
            if i == 1 or set.copyEach then copyScene(); b.copies = b.copies + 1 end
            drawLitBand(b, band[1], rampColor(set, band[4]), band[3], x0, x1, bottom, farCopy)
        else
            drawBand(band[1], band[2], 1, x0, x1, bottom)
        end
    end
    -- the buoy rides the near surface
    love.graphics.push()
    local by = surfaceAt(b, b.buoyX)
    love.graphics.translate(b.buoyX, by + 18)
    love.graphics.rotate(math.sin(b.time * 1.7) * 0.15)
    love.graphics.scale(2.2)
    drawShape(d.buoy)
    love.graphics.pop()
    drawBoat(b)
    if b.settings.optics then drawFish(b, d) end -- in the canvas, so they're seen through the water
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
    local b = state.drawnSea
    if not (b and b.drawing) then return end
    b.drawing = nil
    if b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
    local d = drawings()
    local x0, _, x1, y1 = view()
    drawBoat(b, true)
    local set = b.settings
    if set.optics and sceneCanvas then
        -- the world as it is, then the water over the part of it under the surface
        love.graphics.setCanvas(prevCanvas)
        love.graphics.push()
        love.graphics.origin()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setBlendMode('alpha', 'premultiplied')
        love.graphics.draw(sceneCanvas, 0, 0)
        love.graphics.setBlendMode('alpha')
        love.graphics.pop()
        updateWaterMesh(b, y1 + 50)
        local sh = waterLook.shader()
        love.graphics.setShader(sh)
        sendWater(sh, set, sceneCanvas, set.farLit and { tint = rampColor(set, 1), tintAmount = set.nearTint,
            murk = set.nearMurk } or nil)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(waterMesh)
        love.graphics.setShader()
    else
        -- the near water, see-through: the hull and a Mipo in it show, tinted
        drawBand(function(x) return surfaceAt(b, x) end, NEAR, set.clear, x0, x1, y1 + 50, DX)
        drawFish(b, d)
        drawBand(function(x) return waveY(LAYERS[5], x, b) + 60 end, DEEP, 0.6, x0, x1, y1 + 50)
    end
    drawSurface(b, x0, x1)
    -- splash drops: see-through, stretched along their flight, a highlight; no outline
    for _, dr in ipairs(b.drops) do
        local speed = math.sqrt(dr.vx * dr.vx + dr.vy * dr.vy)
        local stretch = 1 + math.min(speed / 1100, 1.4)
        local fade = math.min(1, dr.life * 2)
        love.graphics.push()
        love.graphics.translate(dr.x, dr.y)
        love.graphics.rotate(math.atan2(dr.vy, dr.vx))
        love.graphics.setColor(0.78, 0.92, 1, 0.55 * fade)
        love.graphics.ellipse('fill', 0, 0, dr.r * stretch, dr.r * 0.8)
        love.graphics.setColor(0.92, 0.98, 1, 0.5 * fade)
        love.graphics.ellipse('fill', -dr.r * 0.15 * stretch, 0, dr.r * 0.7 * stretch, dr.r * 0.5)
        love.graphics.setColor(1, 1, 1, 0.9 * fade)
        love.graphics.circle('fill', dr.r * 0.3 * stretch, -dr.r * 0.3, dr.r * 0.22)
        love.graphics.pop()
    end
    -- bubbles: a pale fill, a thin bright rim, a glint
    for _, bb in ipairs(b.bubbles) do
        love.graphics.setColor(0.8, 0.95, 1, 0.18)
        love.graphics.circle('fill', bb.x, bb.y, bb.r)
        love.graphics.setColor(0.9, 1, 1, 0.55)
        love.graphics.setLineWidth(2)
        love.graphics.circle('line', bb.x, bb.y, bb.r)
        love.graphics.circle('fill', bb.x - bb.r * 0.35, bb.y - bb.r * 0.35, bb.r * 0.22)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local b = state.drawnSea and boat()
    if not (b and state.playMode and b.showPanel) then return end
    ui.startFrame()
    local BH, pad, w = 28, 4, 400
    local rows = { { 'swell', 0, 3 }, { 'boatFloat', 0.5, 2 }, { 'sway', 0, 3 }, { 'crest', 0, 30 },
        { 'clarity', 0.2, 3 }, { 'refraction', 0, 3 }, { 'caustics', 0, 3 }, { 'rays', 0, 3 }, { 'mirror', 0, 1.5 },
        { 'specks', 0, 3 }, { 'farMurk', 0, 1 }, { 'farTint', 0, 1.2 },
        { 'horizonPale', 0, 1 }, { 'rampCurve', 0.3, 3 }, { 'nearTint', 0, 1.2 }, { 'nearMurk', 0, 1 },
        { 'wonk', 0, 3 } }
    local h = (BH + pad) * (#rows + 3) + pad + 24
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• drawn sea ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        for _, row in ipairs(rows) do
            local key = row[1]
            local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('drawnSea' .. key, x, y, 180, row[2], row[3], b.settings[key], nil, 0.01)
            if v then b.settings[key] = v + 0 end
            ui.label(x + 280, y, key == 'wonk' and 'wonk (r: build)' or key)
        end
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, string.format('speed %d  (left / right)', b.target))
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'm Mipo  w wave  o optics  c crayon line  r build')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, string.format('f far lit: %s  g copies: %s (%d)', b.settings.farLit and 'on' or 'off',
            b.settings.copyEach and 'each' or 'one', b.copies or 0))
    end)
end

return s

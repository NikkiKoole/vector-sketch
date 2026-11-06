-- bike: a Mipo on a bike rolling down a hill by itself, a knikkerbaan to watch (no buttons).
-- After physics-testbed's downhill (docs/REBUILD-IN-PLAYTIME.md). A real physics bike, two
-- wheels and a frame, sized from the Mipo. The pedals are drawn, turning with the back wheel;
-- the legs follow them by muscle (KEEP_ANGLE aimed where the knee must be for the foot to reach
-- its pedal). Pinned to physical pedals instead, hip, knee and pedal made a closed loop with a
-- dead spot: the pedals jammed, or turning tipped the bike over backwards (tried 2026-11-06).
-- The Mipo faces right (src/mipo-facing.lua: facing a side, hips swing forward and knees bend
-- back), held at the saddle, hands on the bars, torso kept upright on the bike. At the bottom
-- it's put back at the top for now (a lift is the next step).
-- keys: r: a new Mipo on the bike   p: pause

local s = {}

local SCALE = 0.3
local START_X, START_Y = -3000, 0
local END_X = 9000
local FRICTION = 0.9
local BIKE_DENSITY = 6    -- heavy enough that a big-bodied rider doesn't tip it over (2 did)
local AIR = 0.25          -- the bike's linear damping: a calmer top speed (without: ~2900 a second at the bottom)

local function check() -- on state: a script hot reload keeps the ride
    state.bikeSpike = state.bikeSpike or {}
    return state.bikeSpike
end

local function alive(body) return body and not body:isDestroyed() end

-- ─── The course: a long hill with humps, then flat ───

local function courseHeight(x)
    -- the end: a short rise to run out on, then flat
    if x > END_X - 1500 then
        local base = courseHeight(END_X - 1500)
        local u = math.min(x - (END_X - 1500), 900)
        return base - u * u / 900 * 0.35
    end
    local t = math.max(0, x - START_X)
    -- downhill from the start (a knikkerbaan: it rolls off by itself), humps along the way;
    -- 0.32 went far too fast (2900 a second at the bottom, into the end wall)
    return START_Y + t * 0.16 + math.sin(t / 700) * 90 + math.sin(t / 260) * 20
end

local function makeCourse()
    local c = check()
    if alive(c.ground) then return end
    local points = {}
    for x = START_X - 1500, END_X, 50 do
        points[#points + 1] = x
        points[#points + 1] = courseHeight(x)
    end
    -- walls at both ends
    table.insert(points, 1, START_Y - 1500)
    table.insert(points, 1, START_X - 1500)
    points[#points + 1] = END_X
    points[#points + 1] = courseHeight(END_X) - 1500
    c.ground = love.physics.newBody(world, 0, 0, 'static')
    love.physics.newFixture(c.ground, love.physics.newChainShape(false, points)):setFriction(FRICTION)
end

-- ─── Mipo helpers ───

-- where the joint between parent and part sits (hip, knee, ankle)
local function jointPoint(inst, parentName, partName)
    local part, parent = inst.parts[partName], inst.parts[parentName]
    if not (part and parent) then return nil end
    for _, joint in ipairs(part.body:getJoints()) do
        local a, b = joint:getBodies()
        if a == parent.body and b == part.body then
            local x, y = joint:getAnchors()
            return x, y
        end
    end
end

-- turn bodies rigidly about a point
local function turnBodies(bodies, px, py, delta)
    local cs, sn = math.cos(delta), math.sin(delta)
    for _, b in ipairs(bodies) do
        if alive(b) then
            local x, y = b:getPosition()
            local rx, ry = x - px, y - py
            b:setPosition(px + rx * cs - ry * sn, py + rx * sn + ry * cs)
            b:setAngle(b:getAngle() + delta)
        end
    end
end

-- the same for a Mipo's parts by name (as characterManager.poseTpose does with arms)
local function turnParts(inst, names, px, py, delta)
    local bodies = {}
    for _, name in ipairs(names) do
        if inst.parts[name] then bodies[#bodies + 1] = inst.parts[name].body end
    end
    turnBodies(bodies, px, py, delta)
end

local function moveAll(inst, dx, dy)
    for _, part in pairs(inst.parts) do
        local b = part.body
        if alive(b) then
            local px, py = b:getPosition()
            b:setPosition(px + dx, py + dy)
            b:setLinearVelocity(0, 0)
            b:setAngularVelocity(0)
        end
    end
end

-- ─── Pedalling by muscle ───

local PEDAL_RATIO = 0.5   -- the pedals turn with the back wheel at this share of its speed
local LEG_KP = 60         -- the leg muscles' strength while pedalling
local HIP_BACK = math.rad(35) -- facing a side the hips only swing forward (sitting); a pedalling
                              -- thigh goes a little behind the body at the back of the circle

local function partAngle(dx, dy) return math.atan2(dy, dx) - math.pi / 2 end -- 0 = pointing down

-- The legs ready to pedal: hips some room behind, ankles free, feet held flat by a muscle.
local function legsPedal(inst)
    for _, leg in ipairs({ 'luleg', 'ruleg' }) do
        local part, torso = inst.parts[leg], inst.parts.torso1
        for _, joint in ipairs(part and part.body:getJoints() or {}) do
            local a, b = joint:getBodies()
            if a == torso.body and b == part.body and joint:getType() == 'revolute' then
                local lo, up = joint:getLimits()
                joint:setLimits(lo, up + HIP_BACK) -- facing right: behind is the upper side
            end
        end
    end
    for _, foot in ipairs({ 'lfoot', 'rfoot' }) do
        local f = inst.parts[foot]
        for _, joint in ipairs(f and f.body:getJoints() or {}) do
            local _, b = joint:getBodies()
            if b == f.body and joint:getType() == 'revolute' then joint:setLimitsEnabled(false) end
        end
        local keep = mipoActions.ensureKeepAngle(f, -90, LEG_KP)
        if keep then keep.angle, keep.enabled = -90, nil end -- flat, toes forward (facing right)
    end
end

-- Each leg's muscles aimed so its foot reaches its pedal: the knee where a thigh and a shin of
-- these lengths meet between hip and pedal, the knee forward (it faces right). Out of reach,
-- the leg stretches toward it.
local function pedalLegs(inst, bike)
    local crank = bike.crankAngle or 0
    local cx, cy = bike.frame:getWorldPoint(bike.crankX, bike.crankY)
    for i, side in ipairs({ 'l', 'r' }) do
        local u, l = side .. 'uleg', side .. 'lleg'
        local hx, hy = jointPoint(inst, 'torso1', u)
        if hx then
            local a = crank + (i - 1) * math.pi
            local px, py = cx + math.cos(a) * bike.crankR, cy + math.sin(a) * bike.crankR
            local t, s2 = bike.thigh, bike.shin
            local dx, dy = px - hx, py - hy
            local d = math.max(math.abs(t - s2) + 1, math.min(t + s2 - 1, math.sqrt(dx * dx + dy * dy)))
            local toPedal = math.atan2(dy, dx)
            local atHip = math.acos(math.max(-1, math.min(1, (t * t + d * d - s2 * s2) / (2 * t * d))))
            local thighDir = toPedal - atHip -- the knee forward (toward +x)
            local kx, ky = hx + math.cos(thighDir) * t, hy + math.sin(thighDir) * t
            local upper = mipoActions.ensureKeepAngle(inst.parts[u], 0, LEG_KP)
            local lower = mipoActions.ensureKeepAngle(inst.parts[l], 0, LEG_KP)
            if upper then upper.angle, upper.enabled, upper.kp = math.deg(partAngle(kx - hx, ky - hy)), nil, LEG_KP end
            if lower then lower.angle, lower.enabled, lower.kp = math.deg(partAngle(px - kx, py - ky)), nil, LEG_KP end
        end
    end
end

-- ─── The bike, sized from the Mipo's legs ───

-- how tall the Mipo stands (its solid shapes, top to bottom)
local function mipoHeight(inst)
    local top, bottom = math.huge, -math.huge
    for _, part in pairs(inst.parts) do
        for _, fixture in ipairs(alive(part.body) and part.body:getFixtures() or {}) do
            if not fixture:isSensor() then
                local _, y0, _, y1 = fixture:getBoundingBox()
                top, bottom = math.min(top, y0), math.max(bottom, y1)
            end
        end
    end
    return bottom - top
end

local function makeBike(inst, x, y)
    -- Sized from the whole Mipo (from the legs alone, a Mipo that's mostly body and head got a
    -- bike "way too small"); a short-legged one's feet just rest higher.
    local size = mipoHeight(inst)
    -- (0.3 / 1.0 of its height: "way too" big the other way; a kid's bike)
    local leg = size * 0.33         -- the bike's own measure (saddle height, bars)
    local r = size * 0.2            -- wheel radius
    local base = size * 0.7         -- wheelbase
    local group = inst.groupIndex   -- the bike and its rider don't collide

    local bike = { leg = leg, r = r, base = base }
    local function fixture(body, shape, density)
        local f = love.physics.newFixture(body, shape, density)
        f:setGroupIndex(group)
        f:setFriction(FRICTION)
        return f
    end
    -- frame: rear axle at (x - base/2, y), front at (x + base/2, y); saddle and bars relative to it
    bike.frame = love.physics.newBody(world, x, y, 'dynamic')
    bike.frame:setLinearDamping(AIR)
    local seatX, seatY = -leg * 0.45, -r * 0.25 - leg * 0.8
    local barX, barY = base * 0.42, seatY - leg * 0.2
    bike.seatX, bike.seatY, bike.barX, bike.barY = seatX, seatY, barX, barY
    local rearTube = { -base / 2, -r * 0.2, seatX, seatY, seatX + 40, seatY, 0, -r * 0.1 }
    fixture(bike.frame, love.physics.newPolygonShape(unpack(rearTube)), BIKE_DENSITY)
    local frontTube = { 0, -r * 0.1, seatX + 40, seatY, barX, barY, base / 2, -r * 0.2 }
    fixture(bike.frame, love.physics.newPolygonShape(unpack(frontTube)), BIKE_DENSITY)
    fixture(bike.frame, love.physics.newRectangleShape(seatX, seatY - 15, 160, 30), 1) -- the saddle
    local function wheel(wx)
        local w = love.physics.newBody(world, x + wx, y, 'dynamic')
        fixture(w, love.physics.newCircleShape(r), BIKE_DENSITY / 2)
        love.physics.newRevoluteJoint(bike.frame, w, x + wx, y, false)
        return w
    end
    bike.back = wheel(-base / 2)
    bike.front = wheel(base / 2)
    return bike
end

local function bikeBodies(bike)
    return { bike.frame, bike.back, bike.front }
end

-- ─── The Mipo on it ───

-- legs folded into a sitting pose (thigh forward, shin down), the hips on the saddle
local function seatMipo(inst, bike)
    local forward = -math.pi / 2 * 0.7 -- the thighs most of the way forward (facing right)
    for _, side in ipairs({ 'l', 'r' }) do
        local u, l, f = side .. 'uleg', side .. 'lleg', side .. 'foot'
        local hx, hy = jointPoint(inst, 'torso1', u)
        if hx then
            turnParts(inst, { u, l, f }, hx, hy, forward - inst.parts[u].body:getAngle())
            local kx, ky = jointPoint(inst, u, l)
            turnParts(inst, { l, f }, kx, ky, -inst.parts[l].body:getAngle())
        end
    end
    local sx, sy = bike.frame:getWorldPoint(bike.seatX, bike.seatY - 20)
    local hx, hy = jointPoint(inst, 'torso1', 'luleg')
    moveAll(inst, sx - hx, sy - hy)
end

-- the hold: hips at the saddle, hands at the bars (pulled there over the first moments), feet on
-- footrests where the sitting pose put them
local function holdOn(inst, bike)
    local joints = {}
    local hx, hy = jointPoint(inst, 'torso1', 'luleg')
    local sx, sy = bike.frame:getWorldPoint(bike.seatX, bike.seatY - 20)
    local seat = love.physics.newWeldJoint(bike.frame, inst.parts.torso1.body, sx, sy, hx, hy, false)
    seat:setFrequency(6)
    seat:setDampingRatio(0.7)
    joints[#joints + 1] = seat
    local bx, by = bike.frame:getWorldPoint(bike.barX, bike.barY)
    for _, hand in ipairs({ 'lhand', 'rhand' }) do
        local h = inst.parts[hand]
        if h then
            local px, py = h.body:getPosition()
            joints[#joints + 1] = love.physics.newRevoluteJoint(bike.frame, h.body, bx, by, px, py, false)
        end
    end
    return joints
end

-- The crank where this Mipo's legs reach it well (the bike is sized from its height, the legs
-- vary): below and a little in front of the hips, the pedal circle within a bent leg's reach.
local function placeCrank(inst, bike)
    local hx, hy = jointPoint(inst, 'torso1', 'luleg')
    local kx, ky = jointPoint(inst, 'luleg', 'llleg')
    local ax, ay = jointPoint(inst, 'llleg', 'lfoot')
    bike.thigh = math.sqrt((kx - hx) ^ 2 + (ky - hy) ^ 2)
    bike.shin = math.sqrt((ax - kx) ^ 2 + (ay - ky) ^ 2)
    local leg = bike.thigh + bike.shin
    bike.crankR = leg * 0.12
    local lx, ly = bike.frame:getLocalPoint(hx, hy)
    bike.crankX, bike.crankY = lx + leg * 0.3, ly + leg * 0.72
end

local function removeRide()
    local c = check()
    for _, j in ipairs(c.joints or {}) do
        if not j:isDestroyed() then j:destroy() end
    end
    c.joints = nil
    if c.bike then
        for _, b in ipairs(bikeBodies(c.bike)) do
            if alive(b) then b:destroy() end
        end
    end
    c.bike = nil
    if c.mipo and c.mipo.parts and c.mipo.parts.torso1 and alive(c.mipo.parts.torso1.body) then
        characterManager.removeCharacter(c.mipo)
    end
    c.mipo = nil
end

local function newRide()
    local c = check()
    removeRide()
    local inst = characterManager.createCharacter('humanoid', START_X, courseHeight(START_X) - 2000, SCALE)
    if not inst then return end
    characterManager.randomizeMipo(inst)
    characterManager.switchFacing(inst, 'right')
    local bike = makeBike(inst, START_X, courseHeight(START_X))
    -- the bike's wheels on the ground
    for _, b in ipairs(bikeBodies(bike)) do
        local bx, by = b:getPosition()
        b:setPosition(bx, by - bike.r - 2)
    end
    seatMipo(inst, bike)
    placeCrank(inst, bike)
    legsPedal(inst)
    c.mipo, c.bike = inst, bike
    c.joints = holdOn(inst, bike)
end

-- back to the top: the bike and its rider moved as one (the lift comes next)
local function backToTop()
    local c = check()
    local frame = c.bike.frame
    local fx, fy = frame:getPosition()
    local dx = START_X - fx
    local dy = (courseHeight(START_X) - c.bike.r - 2) - fy
    local bodies = bikeBodies(c.bike)
    for _, part in pairs(c.mipo.parts) do bodies[#bodies + 1] = part.body end
    local angle = frame:getAngle()
    for _, b in ipairs(bodies) do
        if alive(b) then
            local x, y = b:getPosition()
            b:setPosition(x + dx, y + dy)
            b:setLinearVelocity(0, 0)
            b:setAngularVelocity(0)
        end
    end
    turnBodies(bodies, START_X, fy + dy, -angle) -- the bike level again, turned about its frame
end

-- ─── Drawing: tires of the rider's own leg picture, spokes, the frame, the course ───

local SPOKES = 8
local TIRE = 0.3      -- tire thickness, of the wheel radius
local TIRE_REPEAT = 3 -- the leg picture this many times round a tire
local TIRE_STEPS = 48
local TIRE_MIDDLE = { 0.2, 0.8 } -- the part of the leg picture used along the tire

-- the rider's composed leg picture (its connected skin on the upper leg, in its colours)
local function legPicture(inst)
    for _, name in ipairs({ 'luleg', 'ruleg' }) do
        local part = inst.parts[name]
        for _, fixture in ipairs(part and alive(part.body) and part.body:getFixtures() or {}) do
            local ud = fixture:getUserData()
            local e = ud and ud.subtype == 'connected-texture' and ud.extra
            if e and e.ompImage and e.main and not tostring(e.main.bgURL):find('hair') then return e.ompImage end
        end
    end
end

local tireMesh
local function drawTire(wheel, r, picture)
    local x, y = wheel:getPosition()
    local a0 = wheel:getAngle()
    local inner = r * (1 - TIRE)
    if picture then
        local verts = {}
        for i = 0, TIRE_STEPS do
            local a = a0 + i / TIRE_STEPS * math.pi * 2
            local cs, sn = math.cos(a), math.sin(a)
            -- only the leg picture's even middle (its ends are rounded: gaps), back and forth
            local t = (i / TIRE_STEPS * TIRE_REPEAT) % 2
            local v = TIRE_MIDDLE[1] + (TIRE_MIDDLE[2] - TIRE_MIDDLE[1]) * (t < 1 and t or 2 - t)
            verts[#verts + 1] = { x + cs * r, y + sn * r, 0, v }
            verts[#verts + 1] = { x + cs * inner, y + sn * inner, 1, v }
        end
        if not tireMesh or tireMesh:getVertexCount() ~= #verts then
            tireMesh = love.graphics.newMesh(#verts, 'strip', 'stream')
        end
        tireMesh:setVertices(verts)
        tireMesh:setTexture(picture)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(tireMesh)
    else
        love.graphics.setColor(0.15, 0.12, 0.1)
        love.graphics.setLineWidth(r * TIRE)
        love.graphics.circle('line', x, y, r * (1 - TIRE / 2))
    end
    -- spokes
    love.graphics.setColor(0.2, 0.17, 0.15, 0.9)
    love.graphics.setLineWidth(math.max(2, r * 0.025))
    for i = 1, SPOKES do
        local a = a0 + i / SPOKES * math.pi * 2
        love.graphics.line(x, y, x + math.cos(a) * inner, y + math.sin(a) * inner)
    end
    love.graphics.circle('fill', x, y, r * 0.08) -- the hub
end

-- the frame as tubes: rear axle - saddle - bars - front axle, and the bottom tube; the saddle
local function drawFrame(bike)
    local f = bike.frame
    local function p(x, y) return f:getWorldPoint(x, y) end
    local rx, ry = p(-bike.base / 2, 0)
    local fx, fy = p(bike.base / 2, 0)
    local sx, sy = p(bike.seatX, bike.seatY)
    local bx, by = p(bike.barX, bike.barY)
    local mx, my = p(0, -bike.r * 0.1)
    love.graphics.setColor(0.75, 0.3, 0.25)
    love.graphics.setLineWidth(bike.r * 0.09)
    love.graphics.setLineJoin('bevel')
    love.graphics.line(rx, ry, sx, sy, bx, by, fx, fy)
    love.graphics.line(rx, ry, mx, my, sx, sy)
    love.graphics.line(mx, my, bx, by)
    -- saddle and handlebar grip
    love.graphics.setColor(0.2, 0.15, 0.12)
    love.graphics.push()
    love.graphics.translate(sx, sy)
    love.graphics.rotate(f:getAngle())
    love.graphics.rectangle('fill', -bike.r * 0.35, -bike.r * 0.12, bike.r * 0.7, bike.r * 0.14, bike.r * 0.07)
    love.graphics.pop()
    love.graphics.circle('fill', bx, by, bike.r * 0.08)
end

local function drawCourse(ground)
    love.graphics.setColor(0.35, 0.25, 0.15)
    love.graphics.setLineWidth(14)
    for _, fixture in ipairs(ground:getFixtures()) do
        love.graphics.line(ground:getWorldPoints(fixture:getShape():getPoints()))
    end
end

-- the crank arm and the two pedals
local function drawCrank(bike)
    if not bike.crankX then return end
    local cx, cy = bike.frame:getWorldPoint(bike.crankX, bike.crankY)
    local a = bike.crankAngle or 0
    local r = bike.crankR
    local x1, y1 = cx + math.cos(a) * r, cy + math.sin(a) * r
    local x2, y2 = cx - math.cos(a) * r, cy - math.sin(a) * r
    love.graphics.setColor(0.25, 0.22, 0.2)
    love.graphics.setLineWidth(bike.r * 0.07)
    love.graphics.line(x1, y1, x2, y2)
    love.graphics.circle('fill', cx, cy, bike.r * 0.12) -- the chainring
    for _, p in ipairs({ { x1, y1 }, { x2, y2 } }) do
        love.graphics.rectangle('fill', p[1] - bike.r * 0.12, p[2] - bike.r * 0.03, bike.r * 0.24, bike.r * 0.06)
    end
end

function s.drawBelow()
    local c = check()
    -- in play the script draws the course and bike itself; the debug shapes off meanwhile
    if state.playMode then
        c.savedDrawBodies = state.world.debugDrawBodies
        state.world.debugDrawBodies = false
    end
    if alive(c.ground) then drawCourse(c.ground) end
    if c.bike and alive(c.bike.frame) then
        local picture = c.mipo and legPicture(c.mipo)
        drawTire(c.bike.back, c.bike.r, picture)
        drawTire(c.bike.front, c.bike.r, picture)
        drawFrame(c.bike)
        drawCrank(c.bike)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function s.draw()
    local c = check()
    if c.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = c.savedDrawBodies
        c.savedDrawBodies = nil
    end
end

-- ─── Scene ───

function s.onStart()
    worldState.paused = false
    makeCourse()
    local c = check()
    if not (c.mipo and c.mipo.parts and c.mipo.parts.torso1 and alive(c.mipo.parts.torso1.body)) then newRide() end
end

function s.onUnload()
    local c = state.bikeSpike
    if not c then return end
    removeRide()
    if alive(c.ground) then c.ground:destroy() end
    c.ground = nil
end

function s.update()
    local c = check()
    if not (c.bike and alive(c.bike.frame)) then return end
    local frame = c.bike.frame
    local fx, fy = frame:getPosition()
    -- the rider sits upright on the bike: its torso's muscle aims at the frame's angle
    -- the pedals turn with the back wheel, the legs follow them
    c.bike.crankAngle = c.bike.back:getAngle() * PEDAL_RATIO
    pedalLegs(c.mipo, c.bike)
    local torsoKeep = mipoActions.getKeepAngle(c.mipo.parts.torso1)
    if torsoKeep then torsoKeep.angle = math.deg(frame:getAngle()) end
    -- the camera rides along (until you touch, drag or zoom)
    if not (love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0) then
        cam:setScale(0.35)
        local tx, ty = cam:getTranslation()
        cam:setTranslation(tx + (fx - tx) * 0.1, ty + (fy - 250 - ty) * 0.1)
    end
    -- at the bottom and nearly stopped: up to the top again
    local vx = frame:getLinearVelocity()
    if fx > END_X - 1200 and math.abs(vx) < 30 then
        c.stillFor = (c.stillFor or 0) + love.timer.getDelta()
        if c.stillFor > 1 then
            c.stillFor = 0
            backToTop()
        end
    else
        c.stillFor = 0
    end
end

function s.onKeyPress(key)
    if key == 'r' then newRide() end
    if key == 'p' then worldState.paused = not worldState.paused end
end

return s

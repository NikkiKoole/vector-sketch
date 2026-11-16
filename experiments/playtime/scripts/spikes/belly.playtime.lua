-- belly: an enormous sleeping whale on the beach that Mipos walk into (Nikki: "a bit like the whale", after the mitten).
-- A picture-book cutaway: the whale lies on the sand with its mouth open, a tongue as a gentle ramp in, a big
-- mouth cave, a narrow throat and a stomach with ribs. Its back is a chain of beads on springs (the mitten's wool),
-- each pulled to its place in the animal's shape, so it's soft where Mipos push and it breathes: slowly swelling
-- and shrinking. The floor is one kinematic body that tilts a little with each breath (0 at the mouth, the most
-- at the back), so the Mipos inside rock gently. Too many inside (capacity) for a while and it hiccups: the floor
-- kicks, water spouts from the blowhole, the back lets Mipos through for a moment and they fly out onto the beach.
--
-- The animal is data (ANIMAL): its back's outline, its floor, the jaw's hinge, the blowhole, the eye, the tail
-- and its colours. Another sleeping animal (a bear, a cow) is another table.
--
-- play mode (tab): drag Mipos in through the mouth, or 'walk in' and they go by themselves.
-- keys: w walk in   h hiccup now   m a Mipo at the mouse   r reset
local s = {}

local walk = mipoWalk -- src/mipo-walk.lua
local GROUND_Y = 0
local BEAD_R, SPACING = 42, 66
local MIPO_CAT = 1
local GROUP = -4343 -- the beads and the floor never touch each other

local ANIMAL = {
    name = 'whale',
    -- the back, from the upper lip over the head, down into the throat, up over the stomach, down the back wall
    -- to the floor (world units, the whale lying on the sand at y = 0)
    back = {
        { -2560, -1060 }, { -2380, -1300 }, { -1900, -1500 }, { -1300, -1520 }, { -850, -1250 },
        { -600, -1000 }, { -250, -1000 }, { 50, -1350 }, { 550, -1720 }, { 1150, -1800 },
        { 1650, -1580 }, { 1950, -1100 }, { 2040, -560 }, { 1990, -190 },
    },
    -- the floor, from the foot of the tongue on the sand to the back wall: ~4.7° up the tongue, then flat
    floor = { { -2950, 4 }, { -1700, -100 }, { 1990, -100 }, { 2030, -330 } },
    hinge = { -1350, -900 },   -- the upper jaw turns about this point (the back of the mouth)
    jawUntil = -700,           -- back beads left of this turn with the jaw, fading out to here
    blowhole = { -1150, -1560 },
    eye = { -1950, -1180 },
    tail = {
        { 1900, -1250 }, { 2450, -760 }, { 2950, -560 }, { 3280, -760 }, { 3560, -1180 }, { 3640, -1080 },
        { 3460, -560 }, { 3700, -260 }, { 3560, -180 }, { 3100, -220 }, { 2500, -70 }, { 1950, 0 },
    },
    skin = { 0.36, 0.45, 0.58 }, skinDark = { 0.15, 0.19, 0.27 }, belly = { 0.80, 0.82, 0.84 },
    cave = { 0.40, 0.15, 0.19 }, stomach = { 0.50, 0.21, 0.24 }, tongue = { 0.86, 0.46, 0.52 },
    ribs = { 0.72, 0.48, 0.48 }, baleen = { 0.86, 0.80, 0.62 },
    stomachFrom = -250,        -- x where the stomach starts (the throat)
}

local tune = { capacity = 6, breath = 6, swell = 0.04, stiffness = 60, wander = 1 }

------------------------------------------------------------------------------------------------- the shape

local function catmull(p0, p1, p2, p3, t)
    local t2, t3 = t * t, t * t * t
    local function c(a, b, cc, d)
        return 0.5 * ((2 * b) + (-a + cc) * t + (2 * a - 5 * b + 4 * cc - d) * t2 + (-a + 3 * b - 3 * cc + d) * t3)
    end
    return c(p0[1], p1[1], p2[1], p3[1]), c(p0[2], p1[2], p2[2], p3[2])
end

-- the back's outline as points SPACING apart
local function restOutline(control)
    local dense = {}
    for i = 1, #control - 1 do
        local p0, p1 = control[math.max(1, i - 1)], control[i]
        local p2, p3 = control[i + 1], control[math.min(#control, i + 2)]
        for k = 0, 19 do
            local x, y = catmull(p0, p1, p2, p3, k / 20)
            dense[#dense + 1] = { x, y }
        end
    end
    dense[#dense + 1] = { control[#control][1], control[#control][2] }
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

local function alive(body) return body and not body:isDestroyed() end

local function belly()
    if not state.belly then state.belly = { mipos = {}, inside = {}, t = 0, drops = {}, zs = {} } end
    return state.belly
end

local function hide(b, body)
    state.hiddenBodies = state.hiddenBodies or {}
    state.hiddenBodies[body] = true
    b.hidden = b.hidden or {}
    b.hidden[#b.hidden + 1] = body
end

local function unhideAll(b)
    for _, body in ipairs(b.hidden or {}) do
        if state.hiddenBodies then state.hiddenBodies[body] = nil end
    end
    b.hidden = {}
end

local function destroyAnimal(b)
    for _, bead in ipairs(b.beads or {}) do
        if alive(bead) then bead:destroy() end
    end
    if alive(b.floor) then b.floor:destroy() end
    b.beads, b.floor = nil, nil
end

local function makeAnimal(b)
    destroyAnimal(b)
    local A = ANIMAL
    b.rest = restOutline(A.back)
    b.beads = {}
    for i, p in ipairs(b.rest) do
        local bead = love.physics.newBody(world, p[1], p[2], 'dynamic')
        local f = love.physics.newFixture(bead, love.physics.newCircleShape(BEAD_R), 20)
        f:setGroupIndex(GROUP)
        f:setFriction(0.9)
        bead:setGravityScale(0.25)
        bead:setLinearDamping(0.5)
        b.beads[i] = bead
        hide(b, bead)
        if i > 1 then
            local a = b.beads[i - 1]
            local j = love.physics.newDistanceJoint(a, bead, a:getX(), a:getY(), bead:getX(), bead:getY())
            j:setFrequency(6)
            j:setDampingRatio(0.5)
        end
    end
    -- the floor: a kinematic chain with its origin at the tongue's foot, so a breath tilts it about the mouth
    local fx, fy = A.floor[1][1], A.floor[1][2]
    b.floor = love.physics.newBody(world, fx, fy, 'kinematic')
    local flat = {}
    for _, p in ipairs(A.floor) do
        flat[#flat + 1] = p[1] - fx
        flat[#flat + 1] = p[2] - fy
    end
    local ff = love.physics.newFixture(b.floor, love.physics.newChainShape(false, unpack(flat)))
    ff:setGroupIndex(GROUP)
    ff:setFriction(0.9)
    b.floorLocal = flat
    hide(b, b.floor)
    b.hic, b.windup, b.jaw = nil, nil, 0
end

local function makeGround(b)
    if alive(b.ground) then return end
    b.ground = love.physics.newBody(world, 0, 0, 'static')
    local f = love.physics.newFixture(b.ground, love.physics.newEdgeShape(-6000, GROUND_Y, 6000, GROUND_Y))
    f:setFriction(0.9)
    for _, x in ipairs({ -6000, 6000 }) do
        love.physics.newFixture(b.ground, love.physics.newEdgeShape(x, GROUND_Y, x, GROUND_Y - 6000))
    end
    hide(b, b.ground)
end

------------------------------------------------------------------------------------------------- outlines

-- the back as a flat list of the beads' positions
local function backPoints(b)
    local pts = {}
    for _, bead in ipairs(b.beads) do
        local x, y = bead:getPosition()
        pts[#pts + 1] = x
        pts[#pts + 1] = y
    end
    return pts
end

-- the floor in the world, from the tongue's foot to the back wall
local function floorPoints(b)
    return { b.floor:getWorldPoints(unpack(b.floorLocal)) }
end

-- the inside: the back, then the floor from the back wall to the tongue's foot (the mouth closes it)
local function cavePolygon(b)
    local pts = backPoints(b)
    local fl = floorPoints(b)
    for i = #fl - 1, 1, -2 do
        pts[#pts + 1] = fl[i]
        pts[#pts + 1] = fl[i + 1]
    end
    return pts
end

local function insidePoly(pts, x, y)
    local inPoly, n = false, #pts / 2
    local j = n
    for i = 1, n do
        local xi, yi, xj, yj = pts[2 * i - 1], pts[2 * i], pts[2 * j - 1], pts[2 * j]
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then inPoly = not inPoly end
        j = i
    end
    return inPoly
end

-- the outline pushed out by `grow` (the back runs left to right over the top: outward is (ty, -tx))
local function grown(pts, grow)
    local n, out = #pts / 2, {}
    for i = 1, n do
        local a, c = math.max(1, i - 1), math.min(n, i + 1)
        local tx, ty = pts[2 * c - 1] - pts[2 * a - 1], pts[2 * c] - pts[2 * a]
        local l = math.max(1e-6, math.sqrt(tx * tx + ty * ty))
        out[#out + 1] = pts[2 * i - 1] + ty / l * grow
        out[#out + 1] = pts[2 * i] - tx / l * grow
    end
    return out
end

------------------------------------------------------------------------------------------------- breathing

local function breathAt(b) return math.sin(b.t * 2 * math.pi / tune.breath) end

-- each bead pulled to its place: the rest shape swollen by the breath (up from the floor), the jaw turned
local function holdShape(b, dt)
    local A = ANIMAL
    local br = breathAt(b)
    local swell = 1 + tune.swell * br + (b.puff or 0)
    local jaw = 0.025 * br + (b.jaw or 0)
    local hx, hy = A.hinge[1], A.hinge[2]
    local floorY = -100
    local k, c = tune.stiffness, 2 * 0.6 * math.sqrt(tune.stiffness)
    for i, bead in ipairs(b.beads) do
        local rx, ry = b.rest[i][1], b.rest[i][2]
        local tx, ty = rx, floorY + (ry - floorY) * swell
        -- the upper jaw: beads at the front turn about the hinge, fading out toward jawUntil
        local w = math.max(0, math.min(1, (A.jawUntil - rx) / (A.jawUntil - hx)))
        if w > 0 and jaw ~= 0 then
            local a = jaw * w
            local dx, dy = tx - hx, ty - hy
            tx = hx + dx * math.cos(a) - dy * math.sin(a)
            ty = hy + dx * math.sin(a) + dy * math.cos(a)
        end
        local x, y = bead:getPosition()
        local vx, vy = bead:getLinearVelocity()
        local mass = bead:getMass()
        bead:applyLinearImpulse(mass * (k * (tx - x) - c * vx) * dt, mass * (k * (ty - y) - c * vy) * dt)
    end
end

-- the floor tilts about the tongue's foot: up at the back with a breath in, a kick at a hiccup
local function moveFloor(b, dt)
    local target = -0.006 * (0.5 + 0.5 * breathAt(b)) - (b.kick or 0)
    b.floor:setAngularVelocity((target - b.floor:getAngle()) / math.max(dt, 1 / 240))
    b.floor:setLinearVelocity(0, 0)
end

------------------------------------------------------------------------------------------------- sounds

local hicSound
local function playHic()
    if not hicSound then
        local ok, src = pcall(function()
            local rate, len = 22050, 0.45
            local data = love.sound.newSoundData(math.floor(rate * len), rate, 16, 1)
            local phase = 0
            for i = 0, data:getSampleCount() - 1 do
                local t = i / rate
                local f = 150 * (1 - t * 1.2) -- a low hup that falls
                phase = phase + f / rate
                local env = math.min(1, t * 40) * math.exp(-t * 7)
                local v = math.sin(phase * 2 * math.pi) + 0.3 * math.sin(phase * 4 * math.pi)
                data:setSample(i, v * env * 0.5)
            end
            return love.audio.newSource(data, 'static')
        end)
        hicSound = ok and src or false
    end
    if hicSound then
        hicSound:stop()
        hicSound:play()
    end
end

------------------------------------------------------------------------------------------------- Mipos

local function torsoOf(inst)
    local t = inst.parts and inst.parts.torso1
    return t and alive(t.body) and t.body or nil
end

local function setOpen(b, open)
    for _, bead in ipairs(b.beads) do
        local f = bead:getFixtures()[1]
        if open then f:setMask(MIPO_CAT) else f:setMask() end
    end
end

-- the spout: drops from the blowhole
local function spout(b, n, speed)
    local bx, by = ANIMAL.blowhole[1], ANIMAL.blowhole[2]
    -- the blowhole sits on the nearest bead
    local best, bd = nil, math.huge
    for _, bead in ipairs(b.beads) do
        local x, y = bead:getPosition()
        local d = (x - bx) ^ 2 + (y - by) ^ 2
        if d < bd then best, bd = bead, d end
    end
    if best then bx, by = best:getPosition() end
    for _ = 1, n do
        b.drops[#b.drops + 1] = {
            x = bx + (random() - 0.5) * 60, y = by - BEAD_R,
            vx = (random() - 0.5) * speed * 0.35, vy = -speed * (0.6 + random() * 0.5),
            r = 10 + random() * 18, life = 2.5,
        }
    end
end

local function hiccup(b)
    playHic()
    setOpen(b, true)
    b.hic, b.windup = 0, nil
    spout(b, 160, 3200)
    camera.shake(25, 0.5)
    for _, inst in ipairs(b.inside) do
        local torso = torsoOf(inst)
        if torso then
            walk.drive(inst, nil)
            inst._belly = nil
            -- up and out toward the beach (the whale's mouth side)
            local vx, vy = -(900 + random() * 900), -2700 - random() * 900
            for _, part in pairs(inst.parts) do
                if part.body and alive(part.body) then
                    part.body:setLinearVelocity(vx, vy)
                    part.body:setAngularVelocity((random() - 0.5) * 10)
                end
            end
            mipoVoice.squeak(inst, 'happy', 1.2)
        end
    end
    b.hics = (b.hics or 0) + 1
end

local function spawnMipo(b, x, y)
    return mipoKit.spawn(b.mipos, x, y)
end

local function reset(b)
    for _, inst in ipairs(mipoKit.alive(b.mipos)) do
        for _, part in pairs(inst.parts) do
            if alive(part.body) then objectManager.destroyBody(part.body) end
        end
    end
    b.mipos, b.inside, b.order, b.drops = {}, {}, {}, {}
    makeAnimal(b)
    for k = 0, 3 do spawnMipo(b, -4600 + k * 480, -600) end
    spawnMipo(b, 900, -900) -- one already in the stomach
end

-- send every Mipo outside walking in, each to its own spot inside
local function walkIn(b)
    for _, inst in ipairs(mipoKit.alive(b.mipos)) do
        if not b.isIn[inst] then
            inst._belly = { mode = 'in', goal = -1900 + random() * 3000 }
        end
    end
end

-- each Mipo's own walking: going in to its spot, then pottering about inside
local function steer(b, now)
    for _, inst in ipairs(b.mipos) do
        local torso = torsoOf(inst)
        local plan = inst._belly
        if torso and plan then
            local x = torso:getX()
            if plan.mode == 'in' then
                if x >= plan.goal or (walk.blocked(inst) and b.isIn[inst]) then
                    walk.drive(inst, nil)
                    inst._belly = { mode = 'potter', untilT = now + 1 + random() * 3 }
                elseif walk.blocked(inst) and not b.isIn[inst] and now - (plan.blockedT or now) > 3 then
                    walk.drive(inst, nil) -- stuck outside: give up
                    inst._belly = nil
                else
                    if walk.blocked(inst) then plan.blockedT = plan.blockedT or now else plan.blockedT = nil end
                    walk.drive(inst, 1.4, 'walk')
                end
            elseif plan.mode == 'potter' then
                if tune.wander < 0.5 or not b.isIn[inst] then
                    walk.drive(inst, nil)
                elseif now >= plan.untilT or walk.blocked(inst) then
                    local r = random()
                    plan.untilT = now + 1.5 + random() * 3
                    if r < 0.45 then
                        plan.speed = 0
                    else
                        local dir = random() < 0.5 and -1 or 1
                        if walk.blocked(inst) and plan.speed then dir = -(plan.speed > 0 and 1 or -1) end
                        if x < -2200 then dir = 1 end -- not out of the mouth by themselves
                        plan.speed = dir * (0.6 + random() * 0.5)
                    end
                    walk.drive(inst, plan.speed ~= 0 and plan.speed or nil, 'walk')
                end
            end
        end
    end
end

------------------------------------------------------------------------------------------------- the scene

-- the whale and the beach where the Mipos wait, all in view, the sand low on the screen (the panel in the sky)
local BOUNDS = { -5600, -7000, 5600, 1100 } -- tall: the camera won't zoom out past what fits inside its bounds
local function lookAtWhale()
    local w, h = love.graphics.getDimensions()
    local scale = math.max(w / (BOUNDS[3] - BOUNDS[1]), h / (BOUNDS[4] - BOUNDS[2]), math.min(w / 8600, 0.2))
    cam:setScale(scale)
    cam:setTranslation(-650, GROUND_Y - 0.33 * h / scale)
end

function s.onStart()
    worldState.paused = false
    local b = belly()
    makeGround(b)
    if not (b.beads and alive(b.beads[1]) and alive(b.floor)) then makeAnimal(b) end
    b.mipos = mipoKit.alive(b.mipos)
    b.isIn = b.isIn or {}
    if #b.mipos == 0 then reset(b) end
    camera.setBounds(BOUNDS[1], BOUNDS[2], BOUNDS[3], BOUNDS[4])
    lookAtWhale()
end

function s.onUnload()
    local b = state.belly
    if not b then return end
    destroyAnimal(b)
    if alive(b.ground) then b.ground:destroy() end
    b.ground = nil
    unhideAll(b)
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local b = belly()
    if key == 'm' then
        local mx, my = mouseWorldPos()
        spawnMipo(b, mx, my)
    elseif key == 'h' then hiccup(b)
    elseif key == 'w' then walkIn(b)
    elseif key == 'r' then reset(b) end
end

-- From the bridge: s.spawnAt(x, y), s.hiccupNow(), s.walkIn(), s.status()
function s.spawnAt(x, y) spawnMipo(belly(), x, y) end
function s.hiccupNow() hiccup(belly()) end
function s.walkIn() walkIn(belly()) end
function s.status()
    local b = belly()
    local out = { inside = #b.inside, hics = b.hics or 0, hiccupping = b.hic ~= nil, windup = b.windup,
        floorAngle = b.floor and b.floor:getAngle(), mipos = {} }
    for _, inst in ipairs(b.mipos) do
        local torso = torsoOf(inst)
        if torso then
            local x, y = torso:getPosition()
            out.mipos[#out.mipos + 1] = string.format('%d,%d %s %s', x, y, b.isIn[inst] and 'in' or 'out',
                inst._belly and inst._belly.mode or '-')
        end
    end
    return out
end

function s.update(dt)
    local b = belly()
    if not (b.beads and alive(b.beads[1]) and alive(b.floor)) then return end
    b.t = b.t + dt
    local now = b.t

    -- a hiccup: the floor kicks and the jaw opens, the back lets Mipos through, then everything settles
    if b.hic then
        b.hic = b.hic + dt
        local u = b.hic
        b.kick = u < 0.12 and 0.035 or 0.035 * math.max(0, 1 - (u - 0.12) / 0.4)
        b.jaw = 0.18 * math.max(0, 1 - u / 1.2)
        b.puff = 0.08 * math.max(0, 1 - u / 0.6)
    else
        b.kick, b.jaw, b.puff = 0, 0, 0
    end
    holdShape(b, dt)
    moveFloor(b, dt)

    -- who's inside, in the order they came in
    local cave = cavePolygon(b)
    b.mipos = mipoKit.alive(b.mipos)
    b.isIn = {}
    local list = {}
    for _, inst in ipairs(b.mipos) do
        local torso = torsoOf(inst)
        if torso and insidePoly(cave, torso:getPosition()) then
            b.isIn[inst] = true
            list[#list + 1] = inst
        end
    end
    if not b.hic then b.inside = list end

    if b.hic then
        if b.hic > 1.0 and (#list == 0 or b.hic > 3) then
            setOpen(b, false)
            b.hic = nil
        end
    elseif #list >= tune.capacity then
        b.windup = (b.windup or 0) + dt
        -- the whale squirms: a quick shiver in its back
        b.puff = 0.02 * math.sin(b.windup * 14) * math.min(1, b.windup)
        if b.windup >= 2.5 then hiccup(b) end
    else
        b.windup = nil
    end

    steer(b, now)

    -- the drops of the spout, and a small puff of mist with each breath out
    local br = breathAt(b)
    if (b.lastBreath or 0) > 0.98 and br <= 0.98 and not b.hic then spout(b, 6, 700) end
    b.lastBreath = br
    local g = 1960
    local kept = {}
    for _, d in ipairs(b.drops) do
        d.vy = d.vy + g * dt
        d.x, d.y = d.x + d.vx * dt, d.y + d.vy * dt
        d.life = d.life - dt
        if d.life > 0 and d.y < GROUND_Y then kept[#kept + 1] = d end
    end
    b.drops = kept
    -- sleeping z's rising from the head
    b.zt = (b.zt or 0) + dt
    if b.zt > 1.6 and not b.hic then
        b.zt = 0
        b.zs[#b.zs + 1] = { x = ANIMAL.eye[1] + 150, y = ANIMAL.eye[2] - 350, age = 0, size = 0.8 + random() * 0.5 }
    end
    local zs = {}
    for _, z in ipairs(b.zs) do
        z.age = z.age + dt
        z.y, z.x = z.y - 90 * dt, z.x + 40 * math.sin(z.age * 2) * dt
        if z.age < 4 then zs[#zs + 1] = z end
    end
    b.zs = zs
end

------------------------------------------------------------------------------------------------- drawing

local function fillPoly(poly)
    local ok, tris = pcall(love.math.triangulate, poly)
    if not ok then return end
    for _, t in ipairs(tris) do love.graphics.polygon('fill', t) end
end

local function flatten(list)
    local out = {}
    for _, p in ipairs(list) do out[#out + 1] = p[1]; out[#out + 1] = p[2] end
    return out
end

-- the back's lowest y over x (its top run), for ribs
local function roofAt(pts, x)
    local best
    for i = 1, #pts / 2 - 1 do
        local ax, ay, bx, by = pts[2 * i - 1], pts[2 * i], pts[2 * i + 1], pts[2 * i + 2]
        if (ax - x) * (bx - x) <= 0 and ax ~= bx then
            local y = ay + (by - ay) * (x - ax) / (bx - ax)
            if not best or y > best then best = y end -- the lowest crossing: the inner roof at x
        end
    end
    return best
end

local font
function s.drawBelow()
    local b = state.belly
    if not (b and b.beads and alive(b.beads[1]) and alive(b.floor)) then return end
    local A = ANIMAL
    -- sky, the sea behind, the sand
    love.graphics.setColor(0.80, 0.89, 0.95)
    love.graphics.rectangle('fill', -7000, -7000, 14000, 7000)
    love.graphics.setColor(0.35, 0.60, 0.75)
    love.graphics.rectangle('fill', -7000, -900, 14000, 900)
    love.graphics.setColor(0.55, 0.75, 0.86)
    local t = love.timer.getTime()
    for k = 0, 40 do
        local x = -7000 + k * 360 + math.sin(t * 0.7 + k) * 40
        love.graphics.ellipse('fill', x, -880 + (k % 3) * 220, 120, 10)
    end
    love.graphics.setColor(0.93, 0.84, 0.63)
    love.graphics.rectangle('fill', -7000, GROUND_Y - 10, 14000, 3000)
    love.graphics.setColor(0.88, 0.78, 0.56)
    love.graphics.ellipse('fill', 0, GROUND_Y + 5, 3800, 40)

    -- the tail, the body, then the cutaway inside
    love.graphics.setColor(A.skin)
    fillPoly(flatten(A.tail))
    local back = backPoints(b)
    local outer = grown(back, BEAD_R + 120)
    local fl = floorPoints(b)
    local body = {}
    for i = 1, #outer do body[i] = outer[i] end
    body[#body + 1], body[#body + 2] = fl[#fl - 1] + 60, GROUND_Y
    body[#body + 1], body[#body + 2] = fl[1], GROUND_Y
    love.graphics.setColor(A.skin)
    fillPoly(body)
    -- the pale belly along the sand, with grooves
    love.graphics.setColor(A.belly)
    love.graphics.rectangle('fill', fl[1] + 200, -95, fl[#fl - 1] - fl[1] - 200, 95)
    love.graphics.setColor(A.skinDark[1], A.skinDark[2], A.skinDark[3], 0.35)
    love.graphics.setLineWidth(6)
    for x = fl[1] + 300, fl[#fl - 1] - 100, 110 do love.graphics.line(x, -85, x + 40, -10) end

    local cave = cavePolygon(b)
    love.graphics.setColor(A.cave)
    fillPoly(cave)
    -- the stomach a little lighter, behind the throat
    -- the back past the throat, down the back wall, and back along the floor to the throat
    local stomach = {}
    for i = 1, #back, 2 do
        if back[i] >= A.stomachFrom then stomach[#stomach + 1] = back[i]; stomach[#stomach + 1] = back[i + 1] end
    end
    stomach[#stomach + 1], stomach[#stomach + 2] = fl[#fl - 3], fl[#fl - 2]
    stomach[#stomach + 1], stomach[#stomach + 2] = A.stomachFrom, fl[4] + (fl[6] - fl[4])
        * (A.stomachFrom - fl[3]) / (fl[5] - fl[3])
    if #stomach >= 6 then
        love.graphics.setColor(A.stomach)
        fillPoly(stomach)
    end
    -- ribs in the stomach, behind the Mipos
    love.graphics.setColor(A.ribs[1], A.ribs[2], A.ribs[3], 0.55)
    love.graphics.setLineWidth(30)
    for x = 250, 1750, 300 do
        local top = roofAt(back, x)
        if top then
            local y0 = -110
            local pts = {}
            for k = 0, 8 do
                local u = k / 8
                pts[#pts + 1] = x + math.sin(u * math.pi) * 90
                pts[#pts + 1] = y0 + (top + 70 - y0) * u
            end
            love.graphics.line(pts)
        end
    end
    -- the tongue: a soft pink ramp along the floor of the mouth
    love.graphics.setColor(A.tongue)
    love.graphics.setLineWidth(70)
    local tongue = {}
    for i = 1, #fl - 2, 2 do
        if fl[i] <= A.stomachFrom then tongue[#tongue + 1] = fl[i]; tongue[#tongue + 1] = fl[i + 1] - 20 end
    end
    tongue[#tongue + 1], tongue[#tongue + 2] = A.stomachFrom, fl[4] - 20
    if #tongue >= 4 then love.graphics.line(tongue) end
    -- baleen: a comb hanging from the upper jaw
    love.graphics.setColor(A.baleen)
    love.graphics.setLineWidth(12)
    for i = 3, #back / 2 do
        local x, y = back[2 * i - 1], back[2 * i]
        if x > -1500 then break end
        love.graphics.line(x, y + BEAD_R, x - 10, y + BEAD_R + 170)
    end
    love.graphics.setLineWidth(1)
end

function s.draw()
    local b = state.belly
    if not (b and b.beads and alive(b.beads[1]) and alive(b.floor)) then return end
    local A = ANIMAL
    -- the skin over the beads: a thick band, over the Mipos
    local back = backPoints(b)
    local n = #back / 2
    local outer = grown(back, BEAD_R + 120)
    local inner = grown(back, -BEAD_R - 8)
    for i = 1, n - 1 do
        local quad = { inner[2 * i - 1], inner[2 * i], outer[2 * i - 1], outer[2 * i],
            outer[2 * i + 1], outer[2 * i + 2], inner[2 * i + 1], inner[2 * i + 2] }
        local shade = (i % 2 == 0) and 1 or 0.96
        love.graphics.setColor(A.skin[1] * shade, A.skin[2] * shade, A.skin[3] * shade)
        fillPoly(quad)
    end
    love.graphics.setColor(A.skinDark)
    love.graphics.setLineWidth(14)
    love.graphics.line(outer)
    love.graphics.setColor(A.skinDark[1], A.skinDark[2], A.skinDark[3], 0.6)
    love.graphics.setLineWidth(8)
    love.graphics.line(inner)
    -- the lower lip over the tongue's foot
    local fl = floorPoints(b)
    love.graphics.setColor(A.skin)
    love.graphics.setLineWidth(40)
    love.graphics.line(fl[1] - 40, 0, fl[1] + 500, fl[2] - 30 - (fl[2] - fl[4]) * 0.4)
    -- barnacles on the back
    love.graphics.setColor(0.86, 0.85, 0.80)
    for i = 6, n, 9 do
        local x, y = outer[2 * i - 1], outer[2 * i]
        love.graphics.circle('fill', x + (back[2 * i - 1] - x) * 0.25, y + (back[2 * i] - y) * 0.25, 16)
    end
    -- the sleeping eye on the head (closed: a curve with lashes), sitting in the skin band
    local ex, ey = A.eye[1], A.eye[2]
    local best, bd = 1, math.huge
    for i = 1, n do
        local d = (back[2 * i - 1] - ex) ^ 2 + (back[2 * i] - ey) ^ 2
        if d < bd then best, bd = i, d end
    end
    ex, ey = (back[2 * best - 1] + outer[2 * best - 1]) / 2, (back[2 * best] + outer[2 * best]) / 2
    love.graphics.setColor(A.skinDark)
    love.graphics.setLineWidth(12)
    local open = b.hic and math.max(0, 1 - b.hic / 1.5) or 0
    if open > 0 then
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle('fill', ex, ey, 45 * open + 10)
        love.graphics.setColor(A.skinDark)
        love.graphics.circle('fill', ex, ey, 18)
    else
        love.graphics.arc('line', 'open', ex, ey - 20, 55, 0.3, math.pi - 0.3)
        for k = -1, 1 do love.graphics.line(ex + k * 30, ey + 28, ex + k * 40, ey + 55) end
    end
    -- the spout and the mist
    for _, d in ipairs(b.drops) do
        love.graphics.setColor(0.75, 0.88, 0.98, math.min(1, d.life))
        love.graphics.circle('fill', d.x, d.y, d.r)
    end
    -- z z z
    font = font or love.graphics.newFont(160)
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(font)
    for _, z in ipairs(b.zs) do
        love.graphics.setColor(A.skinDark[1], A.skinDark[2], A.skinDark[3], math.max(0, 1 - z.age / 4))
        love.graphics.print('z', z.x, z.y, -0.2, z.size, z.size)
    end
    love.graphics.setFont(prevFont)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local b = state.belly
    if not (b and state.playMode) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 300
    local rows = 9
    local h = BH * rows + pad * (rows + 1) + 20
    local x0, y0 = 20, 20 -- top left: the sky over the head is empty, the back is high on the right
    ui.panel(x0, y0, w, h, '•• belly ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'walk in (w)') then walkIn(b) end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'hiccup (h)') then hiccup(b) end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'a Mipo on the beach') then spawnMipo(b, -4300, -700) end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'reset (r)') then reset(b) end
        for _, row in ipairs({ { 'capacity', 1, 10, 1 }, { 'breath', 2, 12 }, { 'swell', 0, 0.12 },
            { 'wander', 0, 1, 1 } }) do
            x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('belly' .. row[1], x, y, 140, row[2], row[3], tune[row[1]], nil, row[4])
            if v then tune[row[1]] = v + 0 end
            ui.label(x + 240, y, row[1])
        end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, string.format('inside %d   hiccups %d', #b.inside, b.hics or 0))
    end)
end

return s

-- activity: a Mipo activity board, a chunky plastic board full of gadgets that each do one thing with a sound.
-- In the spirit of the 1970s crib activity boxes, our own board: a rotary dial that springs back clicking, a
-- picture wheel that ticks to a stop, a bell on a button, a squeaker with a face, a peekaboo door with a Mipo
-- behind it, a drum of rattling beads, sliding beads on a rod, a clicker knob, and a string with a ring that
-- zips back in while the Mipos sing. The Mipos on the floor look at whatever made a sound and jump at the bell.
-- Physics where it matters: the drum and its beads, the rod's beads and the ring on its rope are bodies.
--
-- play mode: press, drag and turn the gadgets; grab the beads, the ring and the Mipos as always.
-- keys: r reset   m a Mipo at the mouse   o open/close the door

local s = {}

local flap = love.filesystem.load('scripts/spikes/book-flaps.lua')()
local gadgets = love.filesystem.load('scripts/spikes/activity-gadgets.lua')() -- sounds, reactions, dial, spinner...
gadgets.use({ mipoKit = mipoKit, mipoActions = mipoActions, mipoEmotion = mipoEmotion, mipoVoice = mipoVoice,
    getInteractedWithPointer = getInteractedWithPointer })
local windupKey = gadgets.windupKey

local TAU = math.pi * 2
local INK = { 0.16, 0.12, 0.14 }

-- the board, in world units (a Mipo is ~660 tall); the floor at y 0
local BX1, BX2, BY1, BY2 = -2700, 2700, -4700, -700
local FLOOR = 0

-- the gadgets' places
local DIAL = { x = -1750, y = -3950, r = 420 }
local WHEEL = { x = 0, y = -4020, r = 450 }
local BELL = { x = 1750, y = -4150, r = 330, bx = 1750, by = -3600, br = 150 }
local DRUM = { x = -1750, y = -2650, r = 400 }
local DOOR = { x1 = -450, y1 = -3250, x2 = 450, y2 = -2150 }
local SQUEAK = { x = 1750, y = -2650, r = 320 }
local ROD = { y = -1500, x1 = -2450, x2 = -650, r = 115 }
local KNOB = { x = 300, y = -1500, r = 240 }
local STRING = { x = 1750, y = -1500, r = 300, ax = 1750, ay = -1220, rest = 260, max = 1500 }

local TUNE = { 72, 74, 76, 79, 76, 74, 72, 67, 69, 72, 74, 72, 79, 77, 76, 74, 72 } -- the string's song

local function sd()
    state.activity = state.activity or { bodies = {}, mipos = {}, flaps = {}, pending = {} }
    return state.activity
end

local function alive(body) return body and not body:isDestroyed() end
local function hide(body)
    state.hiddenBodies = state.hiddenBodies or {}
    state.hiddenBodies[body] = true
end
local function wrap(a) return (a + math.pi) % TAU - math.pi end
local function dist(x1, y1, x2, y2) return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2) end

---------------------------------------------------------------- sounds and reactions (activity-gadgets.lua)

local play = gadgets.play
local function react(x, y, kind) gadgets.react(sd().mipos, x, y, kind) end
local function stopLooking() gadgets.stopLooking(sd().mipos) end

---------------------------------------------------------------- the bodies: frame, drum, rod beads, ring

local BEAD_COLOURS = { { 0.92, 0.25, 0.22 }, { 0.98, 0.78, 0.15 }, { 0.20, 0.55, 0.90 }, { 0.30, 0.72, 0.35 },
    { 0.95, 0.50, 0.15 }, { 0.65, 0.35, 0.80 }, { 0.98, 0.45, 0.65 }, { 0.25, 0.75, 0.75 }, { 0.95, 0.95, 0.90 } }

local function rectFixture(body, x1, y1, x2, y2)
    local f = love.physics.newFixture(body, love.physics.newRectangleShape((x1 + x2) / 2, (y1 + y2) / 2, x2 - x1, y2 - y1))
    f:setFriction(0.9)
    return f
end

local function build()
    local d = sd()
    local frame = love.physics.newBody(world, 0, 0, 'static')
    hide(frame)
    d.frame = frame
    d.bodies[#d.bodies + 1] = frame
    rectFixture(frame, -6000, FLOOR, 6000, FLOOR + 200)                       -- the floor
    rectFixture(frame, -4500, -6000, -4400, FLOOR)                            -- walls
    rectFixture(frame, 4400, -6000, 4500, FLOOR)
    rectFixture(frame, DOOR.x1, DOOR.y2, DOOR.x2, DOOR.y2 + 60)               -- the peekaboo hole's floor
    rectFixture(frame, DOOR.x1 - 40, DOOR.y1, DOOR.x1, DOOR.y2)               -- and its sides
    rectFixture(frame, DOOR.x2, DOOR.y1, DOOR.x2 + 40, DOOR.y2)
    rectFixture(frame, DOOR.x1 - 40, DOOR.y1 - 40, DOOR.x2 + 40, DOOR.y1)     -- and its top

    -- the drum: a ring that turns on its axle, beads loose inside it
    local drum, beads = gadgets.newDrum(world, frame, DRUM.x, DRUM.y, DRUM.r, 48, BEAD_COLOURS)
    hide(drum)
    d.drum, d.drumBeads = drum, beads
    d.bodies[#d.bodies + 1] = drum
    for _, bead in ipairs(beads) do
        hide(bead.body)
        d.bodies[#d.bodies + 1] = bead.body
    end

    -- the rod's beads: each slides on the rod (a prismatic joint), they knock into each other
    d.rodBeads = {}
    for i = 1, 6 do
        local x = ROD.x1 + ROD.r + (i - 1) * (ROD.r * 2 + 4)
        local b = love.physics.newBody(world, x, ROD.y, 'dynamic')
        local f = love.physics.newFixture(b, love.physics.newCircleShape(ROD.r), 1)
        f:setFriction(0.2)
        f:setRestitution(0.35)
        b:setLinearDamping(1.2)
        b:setFixedRotation(true)
        local j = love.physics.newPrismaticJoint(frame, b, x, ROD.y, 1, 0, false)
        j:setLimits(ROD.x1 + ROD.r - x, ROD.x2 - ROD.r - x)
        j:setLimitsEnabled(true)
        hide(b)
        d.rodBeads[i] = { body = b, colour = BEAD_COLOURS[i] }
        d.bodies[#d.bodies + 1] = b
    end
    d.touching = {}

    -- the ring on its string: a rope joint whose length grows as it's pulled and shrinks back
    d.str = gadgets.newString(world, frame, STRING.ax, STRING.ay, STRING.rest)
    hide(d.str.ring)
    d.bodies[#d.bodies + 1] = d.str.ring

    -- the gadgets' own state
    d.dial = gadgets.newDial()
    d.wheel = gadgets.newWheel()
    d.bell = { wobble = 0, press = 0 }
    d.squeak = { squash = 1, down = false }
    d.knob = { a = 0, notch = 0 }
    d.flaps = {}
    d.pending = { { -1700 }, { -200 }, { 1300 }, { 0, peek = true } }
end

local function destroyAll()
    local d = sd()
    for _, inst in ipairs(mipoKit.alive(d.mipos)) do
        for _, part in pairs(inst.parts) do
            if part.body and not part.body:isDestroyed() then objectManager.destroyBody(part.body) end
        end
    end
    d.mipos, d.peek = {}, nil
    for _, body in ipairs(d.bodies) do
        if alive(body) then
            if state.hiddenBodies then state.hiddenBodies[body] = nil end
            body:destroy()
        end
    end
    d.bodies = {}
end

---------------------------------------------------------------- the door

local DOOR_POLY = { DOOR.x1, DOOR.y1, DOOR.x2, DOOR.y1, DOOR.x2, DOOR.y2, DOOR.x1, DOOR.y2 }
local DOOR_DEF = { hingeX = DOOR.x1, from = DOOR.y2, to = DOOR.y1, angle = math.pi * 0.82, spread = 0.12, drag = 700,
    pull = { -1, 0 }, height = DOOR.x2 - DOOR.x1, outside = { 0.98, 0.80, 0.18 }, inside = { 0.85, 0.72, 0.40 },
    edge = INK, edgeWidth = 14 }
DOOR_DEF.decorate = function(def, st) -- a knob and a little window, on the outside
    local kx, ky, c = flap.fold(def, st, DOOR.x2 - 120, (DOOR.y1 + DOOR.y2) / 2)
    if c > 0.05 then
        love.graphics.setColor(0.85, 0.20, 0.18)
        love.graphics.ellipse('fill', kx, ky, 55 * c, 55)
        local wx1 = flap.fold(def, st, -200, 0)
        local wx2 = flap.fold(def, st, 200, 0)
        love.graphics.setColor(0.30, 0.65, 0.95)
        love.graphics.ellipse('fill', (wx1 + wx2) / 2, DOOR.y1 + 260, math.abs(wx2 - wx1) / 2, 150)
    end
end

---------------------------------------------------------------- the gadgets' input

local function inCircle(g, x, y, r) return dist(g.x, g.y, x, y) <= (r or g.r) end

local function pressGadget(d, mx, my, grabbed, now)
    local st = flap.state(d.flaps, 'door')
    if flap.contains(DOOR_DEF, st, DOOR_POLY, mx, my) then
        if grabbed then
            if st.open < 0.5 then st.target = 1 end
        else
            flap.press(st, mx, my, now)
            return 'door'
        end
        return nil
    end
    if grabbed then return nil end
    if inCircle(DIAL, mx, my) then
        gadgets.dialPress(d.dial, DIAL, mx, my)
        return 'dial'
    elseif inCircle(WHEEL, mx, my) then
        gadgets.wheelPress(d.wheel, WHEEL, mx, my)
        return 'wheel'
    elseif inCircle({ x = BELL.bx, y = BELL.by }, mx, my, BELL.br + 40) or inCircle(BELL, mx, my) then
        d.bell.press, d.bell.wobble = 1, 1
        play('bell', 0.9, 0.97 + love.math.random() * 0.06)
        react(BELL.x, BELL.y, 'bell')
        return 'bell'
    elseif inCircle(SQUEAK, mx, my) then
        d.squeak.down = true
        play('squeakIn', 0.8, 0.95 + love.math.random() * 0.1)
        react(SQUEAK.x, SQUEAK.y, 'squeak')
        return 'squeak'
    elseif inCircle(KNOB, mx, my, KNOB.r + 40) then
        d.knob.last = math.atan2(my - KNOB.y, mx - KNOB.x)
        return 'knob'
    elseif inCircle(DRUM, mx, my) then
        d.drumLast = math.atan2(my - DRUM.y, mx - DRUM.x)
        return 'drum'
    end
end

local DIAL_MAX = gadgets.DIAL_MAX

local function dragGadget(d, which, mx, my, dt)
    if which == 'dial' then
        gadgets.dialDrag(d.dial, DIAL, mx, my)
    elseif which == 'wheel' then
        gadgets.wheelDrag(d.wheel, WHEEL, mx, my, dt)
    elseif which == 'knob' then
        local a = math.atan2(my - KNOB.y, mx - KNOB.x)
        d.knob.a = d.knob.a + wrap(a - d.knob.last)
        d.knob.last = a
    elseif which == 'drum' and alive(d.drum) then
        local a = math.atan2(my - DRUM.y, mx - DRUM.x)
        local delta = wrap(a - d.drumLast)
        d.drumLast = a
        if dt > 0 then d.drum:setAngularVelocity(delta / dt) end
    end
end

local function releaseGadget(d, which, now)
    if which == 'door' then
        flap.release(flap.state(d.flaps, 'door'), now)
    elseif which == 'dial' then
        d.dial.back = true
    elseif which == 'wheel' then
        gadgets.wheelRelease(d.wheel)
    elseif which == 'squeak' then
        d.squeak.down = false
        play('squeakOut', 0.7, 0.95 + love.math.random() * 0.1)
    elseif which == 'drum' then
        react(DRUM.x, DRUM.y, 'drum')
    end
end

---------------------------------------------------------------- the gadgets running

local function updateDial(d, dt, held)
    gadgets.dialUpdate(d.dial, dt, held, function() react(DIAL.x, DIAL.y, 'dial') end)
end

local SECTORS = 6
local function updateWheel(d, dt, held)
    gadgets.wheelUpdate(d.wheel, dt, held, SECTORS, function(pick)
        d.wheel.stoppedAt = pick
        windupKey.note(({ 72, 74, 76, 79, 81, 84 })[pick], 0.6)
        react(WHEEL.x, WHEEL.y, 'wheel')
    end)
end

local function updateKnob(d)
    local n = gadgets.knobUpdate(d.knob)
    if n and n % 4 == 0 then react(KNOB.x, KNOB.y, 'knob') end
end

local function updateDrum(d)
    if alive(d.drum) then gadgets.drumRattle(d.drumBeads) end
end

local function updateRod(d)
    local beads = {}
    for _, b in ipairs(d.rodBeads) do beads[#beads + 1] = b end
    table.sort(beads, function(a, b) return a.body:getX() < b.body:getX() end)
    for i = 1, #beads - 1 do
        local a, b = beads[i], beads[i + 1]
        local gap = b.body:getX() - a.body:getX() - ROD.r * 2
        local key = tostring(a.body) .. tostring(b.body)
        local touching = gap < 8
        if touching and not d.touching[key] then
            local approach = math.abs(a.body:getLinearVelocity() - b.body:getLinearVelocity())
            if approach > 40 then
                play('clack', approach / 900, 0.85 + love.math.random() * 0.3)
                if approach > 500 then react(b.body:getX(), ROD.y, 'clack') end
            end
        end
        d.touching[key] = touching
    end
end

local function updateString(d, dt)
    gadgets.stringUpdate(d.str, STRING, dt, TUNE, function() react(STRING.x, STRING.y, 'sing') end)
end

---------------------------------------------------------------- the scene

local function spawnPending(d)
    local p = d.pending and table.remove(d.pending, 1)
    if not p then return end
    local inst = mipoKit.spawn(d.mipos, p[1], p.peek and (DOOR.y2 - 500) or (FLOOR - 700))
    if inst and p.peek then d.peek = inst end
end

function s.onStart()
    worldState.paused = false
    gadgets.makeSounds(TUNE)
    windupKey.preload({ 72, 74, 76, 79, 81, 84 })
    local d = sd()
    if not (alive(d.frame) and d.str) then
        destroyAll()
        build()
    end
    d.mipos = mipoKit.alive(d.mipos)
    camera.setBounds(-4400, -5800, 4400, 900)
    camera.zoomTo(0.14, 0.4)
end

function s.onUnload()
    destroyAll()
end

local panelRect = { 20, 20, 240, 0 }
local function overPanel()
    if ui.isPanelFolded('•• activity ••') then return false end
    local mx, my = love.mouse.getPosition()
    local r = panelRect
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

function s.update(dt)
    local d = sd()
    if not alive(d.frame) then return end
    spawnPending(d)
    local now = love.timer.getTime()
    local mx, my = mouseWorldPos()
    local down = state.playMode and love.mouse.isDown(1)
    if down and not d.pressing then
        d.pressing = true
        if not overPanel() then
            d.active = pressGadget(d, mx, my, getInteractedWithPointer()[1], now)
        end
    elseif not down and d.pressing then
        d.pressing = false
        if d.active then releaseGadget(d, d.active, now) end
        d.active = nil
    end
    if d.active then dragGadget(d, d.active, mx, my, dt) end

    local doorSt = flap.state(d.flaps, 'door')
    if flap.update(DOOR_DEF, doorSt, dt, mx, my) and d.peek and mipoKit.isAlive(d.peek) then
        mipoEmotion.set(d.peek, 'surprised', 1, 0.7)
        mipoVoice.squeak(d.peek, 'happy', 1.2)
        react(0, (DOOR.y1 + DOOR.y2) / 2, 'door')
    end
    updateDial(d, dt, d.active == 'dial')
    updateWheel(d, dt, d.active == 'wheel')
    updateKnob(d)
    updateDrum(d)
    updateRod(d)
    updateString(d, dt)
    d.bell.wobble = d.bell.wobble * math.exp(-3 * dt)
    d.bell.press = math.max(0, d.bell.press - dt * 5)
    local target = d.squeak.down and 0.72 or 1
    d.squeak.squash = d.squeak.squash + (target - d.squeak.squash) * math.min(1, dt * 18)
    stopLooking()
end

-- From the bridge: s.poke(name[, a, b]) presses a gadget: 'bell', 'squeak', 'door', 'wheel' (a spin of a),
-- 'dial' (turned a radians, then let go), 'knob' (a radians), 'drum' (spin a rad/s)
function s.poke(name, a)
    local d = sd()
    if name == 'bell' then
        d.bell.press, d.bell.wobble = 1, 1
        play('bell', 0.9)
        react(BELL.x, BELL.y, 'bell')
    elseif name == 'squeak' then
        play('squeakIn', 0.8)
        d.squeak.squash = 0.72
        react(SQUEAK.x, SQUEAK.y, 'squeak')
    elseif name == 'door' then
        flap.toggle(flap.state(d.flaps, 'door'))
    elseif name == 'wheel' then
        d.wheel.w, d.wheel.spinning = a or 9, true
    elseif name == 'dial' then
        d.dial.a, d.dial.back = math.min(DIAL_MAX, a or 4), true
    elseif name == 'knob' then
        d.knob.a = d.knob.a + (a or 1)
    elseif name == 'drum' and alive(d.drum) then
        d.drum:setAngularVelocity(a or 8)
    end
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local d = sd()
    if key == 'r' then
        destroyAll()
        build()
    elseif key == 'm' then
        local mx, my = mouseWorldPos()
        mipoKit.spawn(d.mipos, mx, my)
    elseif key == 'o' then
        flap.toggle(flap.state(d.flaps, 'door'))
    end
end

---------------------------------------------------------------- drawing

local function circle(mode, x, y, r, col, a)
    love.graphics.setColor(col[1], col[2], col[3], a or 1)
    love.graphics.circle(mode, x, y, r)
end

local function inked(x, y, r, col, width)
    circle('fill', x, y, r, col)
    love.graphics.setLineWidth(width or 14)
    circle('line', x, y, r, INK)
    love.graphics.setLineWidth(1)
end

-- a chunky plastic boss under each gadget: a ring with a bevel
local function boss(x, y, r, col)
    circle('fill', x + 18, y + 22, r + 40, { 0, 0, 0 }, 0.18)
    inked(x, y, r + 40, col, 12)
    circle('fill', x - r * 0.25, y - r * 0.3, r * 0.7, { 1, 1, 1 }, 0.10)
end

local function drawBoard()
    -- the room: a wall and a rug
    love.graphics.setColor(0.93, 0.89, 0.80)
    love.graphics.rectangle('fill', -6000, -7000, 12000, 7000)
    love.graphics.setColor(0.78, 0.66, 0.52)
    love.graphics.rectangle('fill', -6000, FLOOR, 12000, 1500)
    love.graphics.setColor(0.72, 0.38, 0.32)
    love.graphics.rectangle('fill', -3600, FLOOR, 7200, 140)
    -- its feet
    for _, x in ipairs({ -2100, 2100 }) do
        love.graphics.setColor(0.20, 0.45, 0.85)
        love.graphics.rectangle('fill', x - 220, BY2 - 50, 440, FLOOR - BY2 + 50, 60)
        love.graphics.setColor(INK)
        love.graphics.setLineWidth(12)
        love.graphics.rectangle('line', x - 220, BY2 - 50, 440, FLOOR - BY2 + 50, 60)
    end
    -- the board: a shadow, a thick rim, the face
    love.graphics.setColor(0, 0, 0, 0.2)
    love.graphics.rectangle('fill', BX1 + 50, BY1 + 70, BX2 - BX1, BY2 - BY1, 320)
    love.graphics.setColor(0.86, 0.18, 0.16)
    love.graphics.rectangle('fill', BX1, BY1, BX2 - BX1, BY2 - BY1, 320)
    love.graphics.setColor(0.98, 0.95, 0.86)
    love.graphics.rectangle('fill', BX1 + 130, BY1 + 130, BX2 - BX1 - 260, BY2 - BY1 - 260, 220)
    love.graphics.setColor(INK)
    love.graphics.setLineWidth(16)
    love.graphics.rectangle('line', BX1, BY1, BX2 - BX1, BY2 - BY1, 320)
    love.graphics.setLineWidth(8)
    love.graphics.rectangle('line', BX1 + 130, BY1 + 130, BX2 - BX1 - 260, BY2 - BY1 - 260, 220)
    love.graphics.setLineWidth(1)
    -- screws in the corners
    for _, p in ipairs({ { BX1 + 65, BY1 + 260 }, { BX2 - 65, BY1 + 260 }, { BX1 + 65, BY2 - 260 }, { BX2 - 65, BY2 - 260 } }) do
        circle('fill', p[1], p[2], 30, { 0.75, 0.75, 0.78 })
    end
end

local function drawDial(d)
    boss(DIAL.x, DIAL.y, DIAL.r, { 0.20, 0.55, 0.90 })
    -- the number dots under the holes
    for i = 1, 10 do
        local a = -math.pi * 0.35 - (i - 1) * 0.5
        circle('fill', DIAL.x + math.cos(a) * 300, DIAL.y + math.sin(a) * 300, 70, BEAD_COLOURS[(i - 1) % #BEAD_COLOURS + 1])
    end
    -- the finger wheel, turned
    local a0 = d.dial.a
    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.circle('fill', DIAL.x, DIAL.y, DIAL.r)
    for i = 1, 10 do
        local a = -math.pi * 0.35 - (i - 1) * 0.5 + a0
        local x, y = DIAL.x + math.cos(a) * 300, DIAL.y + math.sin(a) * 300
        circle('fill', x, y, 82, { 1, 1, 1 }, 0.25)
        love.graphics.setLineWidth(8)
        circle('line', x, y, 82, INK)
    end
    love.graphics.setLineWidth(12)
    circle('line', DIAL.x, DIAL.y, DIAL.r, INK)
    inked(DIAL.x, DIAL.y, 150, { 0.98, 0.80, 0.18 }, 10)
    -- a smile in the middle
    love.graphics.setColor(INK)
    love.graphics.circle('fill', DIAL.x - 50, DIAL.y - 30, 18)
    love.graphics.circle('fill', DIAL.x + 50, DIAL.y - 30, 18)
    love.graphics.setLineWidth(12)
    love.graphics.arc('line', 'open', DIAL.x, DIAL.y + 10, 70, 0.3, math.pi - 0.3)
    -- the finger stop
    local sa = math.pi * 0.42
    love.graphics.setColor(0.75, 0.75, 0.78)
    love.graphics.polygon('fill', DIAL.x + math.cos(sa) * 360, DIAL.y + math.sin(sa) * 360,
        DIAL.x + math.cos(sa - 0.12) * 470, DIAL.y + math.sin(sa - 0.12) * 470,
        DIAL.x + math.cos(sa + 0.12) * 470, DIAL.y + math.sin(sa + 0.12) * 470)
    love.graphics.setLineWidth(1)
end

local function drawPicture(i, x, y, a)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(a)
    if i == 1 then -- the sun
        love.graphics.setColor(0.98, 0.75, 0.10)
        for k = 0, 7 do
            local r = k / 8 * TAU
            love.graphics.polygon('fill', math.cos(r) * 60, math.sin(r) * 60, math.cos(r + 0.2) * 110, math.sin(r + 0.2) * 110,
                math.cos(r - 0.2) * 110, math.sin(r - 0.2) * 110)
        end
        love.graphics.circle('fill', 0, 0, 65)
    elseif i == 2 then -- the moon
        love.graphics.setColor(0.98, 0.92, 0.55)
        love.graphics.circle('fill', 0, 0, 90)
        love.graphics.setColor(0.25, 0.30, 0.60)
        love.graphics.circle('fill', 40, -25, 80)
    elseif i == 3 then -- a fish
        love.graphics.setColor(0.98, 0.55, 0.15)
        love.graphics.ellipse('fill', 0, 0, 90, 50)
        love.graphics.polygon('fill', -70, 0, -130, -50, -130, 50)
        love.graphics.setColor(INK)
        love.graphics.circle('fill', 45, -12, 12)
    elseif i == 4 then -- a star
        love.graphics.setColor(0.98, 0.85, 0.20)
        local pts = {}
        for k = 0, 9 do
            local r = k / 10 * TAU - math.pi / 2
            local len = k % 2 == 0 and 110 or 48
            pts[#pts + 1], pts[#pts + 2] = math.cos(r) * len, math.sin(r) * len
        end
        love.graphics.polygon('fill', pts)
    elseif i == 5 then -- a flower
        love.graphics.setColor(0.95, 0.40, 0.60)
        for k = 0, 5 do
            local r = k / 6 * TAU
            love.graphics.circle('fill', math.cos(r) * 55, math.sin(r) * 55, 45)
        end
        love.graphics.setColor(0.98, 0.85, 0.20)
        love.graphics.circle('fill', 0, 0, 40)
    else -- a Mipo face
        love.graphics.setColor(0.45, 0.75, 0.55)
        love.graphics.ellipse('fill', 0, 0, 85, 100)
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle('fill', -30, -20, 26)
        love.graphics.circle('fill', 30, -20, 26)
        love.graphics.setColor(INK)
        love.graphics.circle('fill', -26, -16, 11)
        love.graphics.circle('fill', 34, -16, 11)
        love.graphics.setLineWidth(8)
        love.graphics.arc('line', 'open', 0, 20, 35, 0.3, math.pi - 0.3)
        love.graphics.setLineWidth(1)
    end
    love.graphics.pop()
end

local SECTOR_COLOURS = { { 0.55, 0.80, 0.98 }, { 0.25, 0.30, 0.60 }, { 0.55, 0.85, 0.80 }, { 0.20, 0.30, 0.55 },
    { 0.70, 0.90, 0.55 }, { 0.98, 0.85, 0.60 } }

local function drawWheel(d)
    boss(WHEEL.x, WHEEL.y, WHEEL.r, { 0.30, 0.72, 0.35 })
    local a0 = d.wheel.a
    for i = 1, SECTORS do
        local s1 = a0 + (i - 1) / SECTORS * TAU
        love.graphics.setColor(SECTOR_COLOURS[i])
        love.graphics.arc('fill', WHEEL.x, WHEEL.y, WHEEL.r, s1, s1 + TAU / SECTORS)
        local mid = s1 + TAU / SECTORS / 2
        drawPicture(i, WHEEL.x + math.cos(mid) * 280, WHEEL.y + math.sin(mid) * 280, mid + math.pi / 2)
        -- the pegs
        circle('fill', WHEEL.x + math.cos(s1) * (WHEEL.r - 25), WHEEL.y + math.sin(s1) * (WHEEL.r - 25), 22, { 0.95, 0.95, 0.95 })
    end
    love.graphics.setLineWidth(12)
    circle('line', WHEEL.x, WHEEL.y, WHEEL.r, INK)
    inked(WHEEL.x, WHEEL.y, 70, { 0.86, 0.18, 0.16 }, 8)
    -- the pointer at the top, kicked by each peg
    local px, py = WHEEL.x, WHEEL.y - WHEEL.r - 40
    love.graphics.push()
    love.graphics.translate(px, py - 60)
    love.graphics.rotate(-d.wheel.kick * 0.35 * (d.wheel.w >= 0 and 1 or -1))
    love.graphics.setColor(0.86, 0.18, 0.16)
    love.graphics.polygon('fill', -50, 0, 50, 0, 0, 140)
    love.graphics.setColor(INK)
    love.graphics.setLineWidth(8)
    love.graphics.polygon('line', -50, 0, 50, 0, 0, 140)
    love.graphics.pop()
    love.graphics.setLineWidth(1)
end

local function drawBell(d)
    local b = d.bell
    boss(BELL.x, BELL.y + 120, BELL.r - 40, { 0.98, 0.80, 0.18 })
    -- the dome, wobbling after a ding
    love.graphics.push()
    love.graphics.translate(BELL.x, BELL.y + 150)
    love.graphics.rotate(math.sin(love.timer.getTime() * 38) * 0.05 * b.wobble)
    love.graphics.setColor(0.86, 0.86, 0.90)
    love.graphics.arc('fill', 0, 0, BELL.r, math.pi, TAU)
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.arc('fill', -90, -60, 120, math.pi * 1.1, math.pi * 1.5)
    love.graphics.setColor(INK)
    love.graphics.setLineWidth(12)
    love.graphics.arc('line', 'closed', 0, 0, BELL.r, math.pi, TAU)
    love.graphics.pop()
    -- rings in the air
    if b.wobble > 0.05 then
        love.graphics.setColor(INK[1], INK[2], INK[3], b.wobble * 0.6)
        love.graphics.setLineWidth(10)
        for k = 1, 2 do
            local r = BELL.r + 80 + k * 70 + (1 - b.wobble) * 120
            love.graphics.arc('line', 'open', BELL.x, BELL.y + 150, r, math.pi * 1.15, math.pi * 1.4)
            love.graphics.arc('line', 'open', BELL.x, BELL.y + 150, r, math.pi * 1.6, math.pi * 1.85)
        end
    end
    -- the button below it
    local press = b.press * 30
    circle('fill', BELL.bx, BELL.by + 20, BELL.br, { 0.55, 0.12, 0.10 })
    inked(BELL.bx, BELL.by + press, BELL.br, { 0.86, 0.18, 0.16 }, 12)
    circle('fill', BELL.bx - 40, BELL.by - 40 + press, 45, { 1, 1, 1 }, 0.35)
    love.graphics.setLineWidth(1)
end

local function drawSqueaker(d)
    boss(SQUEAK.x, SQUEAK.y, SQUEAK.r, { 0.65, 0.35, 0.80 })
    local sq = d.squeak.squash
    love.graphics.push()
    love.graphics.translate(SQUEAK.x, SQUEAK.y + (1 - sq) * 120)
    love.graphics.scale(1 + (1 - sq) * 0.4, sq)
    love.graphics.setColor(0.98, 0.55, 0.65)
    love.graphics.circle('fill', 0, 0, SQUEAK.r)
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.circle('fill', -90, -110, 90)
    -- a face: eyes shut tight while squeezed
    love.graphics.setColor(INK)
    love.graphics.setLineWidth(14)
    if sq < 0.85 then
        love.graphics.line(-130, -40, -70, -20, -130, 0)
        love.graphics.line(130, -40, 70, -20, 130, 0)
        love.graphics.ellipse('fill', 0, 90, 60, 50)
    else
        love.graphics.circle('fill', -95, -30, 30)
        love.graphics.circle('fill', 95, -30, 30)
        love.graphics.arc('line', 'open', 0, 40, 90, 0.3, math.pi - 0.3)
    end
    love.graphics.circle('line', 0, 0, SQUEAK.r)
    love.graphics.pop()
    love.graphics.setLineWidth(1)
end

local function drawKnob(d)
    boss(KNOB.x, KNOB.y, KNOB.r, { 0.98, 0.50, 0.15 })
    love.graphics.push()
    love.graphics.translate(KNOB.x, KNOB.y)
    love.graphics.rotate(d.knob.a)
    love.graphics.setColor(0.20, 0.55, 0.90)
    local pts = {}
    for k = 0, 23 do -- a grip with ridges
        local r = k / 24 * TAU
        local len = k % 2 == 0 and KNOB.r or KNOB.r - 30
        pts[#pts + 1], pts[#pts + 2] = math.cos(r) * len, math.sin(r) * len
    end
    love.graphics.polygon('fill', pts)
    love.graphics.setColor(INK)
    love.graphics.setLineWidth(10)
    love.graphics.polygon('line', pts)
    love.graphics.setColor(0.98, 0.95, 0.86)
    love.graphics.rectangle('fill', -25, -KNOB.r + 30, 50, KNOB.r - 40, 20)
    love.graphics.pop()
    love.graphics.setLineWidth(1)
end

local function drawDrumBack()
    boss(DRUM.x, DRUM.y, DRUM.r, { 0.25, 0.75, 0.75 })
    circle('fill', DRUM.x, DRUM.y, DRUM.r, { 0.85, 0.95, 0.98 })
end

local function drawDrumFront(d)
    if not alive(d.drum) then return end
    for _, bead in ipairs(d.drumBeads) do
        local x, y = bead.body:getPosition()
        inked(x, y, 48, bead.colour, 6)
    end
    -- the clear drum: spokes turning with it, a shine
    local a = d.drum:getAngle()
    love.graphics.setColor(1, 1, 1, 0.45)
    love.graphics.setLineWidth(16)
    for k = 0, 3 do
        local r = a + k / 4 * math.pi
        love.graphics.line(DRUM.x - math.cos(r) * DRUM.r, DRUM.y - math.sin(r) * DRUM.r,
            DRUM.x + math.cos(r) * DRUM.r, DRUM.y + math.sin(r) * DRUM.r)
    end
    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.arc('fill', DRUM.x, DRUM.y, DRUM.r * 0.85, math.pi * 1.1, math.pi * 1.45)
    love.graphics.setLineWidth(14)
    circle('line', DRUM.x, DRUM.y, DRUM.r, INK)
    inked(DRUM.x, DRUM.y, 60, { 0.86, 0.18, 0.16 }, 8)
    love.graphics.setLineWidth(1)
end

local function drawRod(d)
    love.graphics.setColor(0.75, 0.75, 0.78)
    love.graphics.rectangle('fill', ROD.x1 - 40, ROD.y - 22, ROD.x2 - ROD.x1 + 80, 44, 20)
    for _, x in ipairs({ ROD.x1 - 60, ROD.x2 + 60 }) do
        inked(x, ROD.y, 70, { 0.20, 0.45, 0.85 }, 10)
    end
    for _, bead in ipairs(d.rodBeads) do
        if alive(bead.body) then
            local x, y = bead.body:getPosition()
            love.graphics.setColor(0, 0, 0, 0.18)
            love.graphics.ellipse('fill', x + 15, y + 20, ROD.r, ROD.r * 0.95)
            inked(x, y, ROD.r, bead.colour, 10)
            love.graphics.setColor(1, 1, 1, 0.35)
            love.graphics.circle('fill', x - 35, y - 40, 32)
        end
    end
end

local function drawString(d)
    -- the box the string comes out of: a round speaker with a Mipo face
    boss(STRING.x, STRING.y, STRING.r - 40, { 0.30, 0.72, 0.35 })
    inked(STRING.x, STRING.y, STRING.r - 40, { 0.98, 0.95, 0.86 }, 10)
    love.graphics.setColor(INK)
    for k = -2, 2 do
        love.graphics.rectangle('fill', STRING.x - 140, STRING.y - 150 + (k + 2) * 45, 280, 14, 7)
    end
    if d.str then gadgets.drawString(d.str, STRING, { 0.86, 0.18, 0.16 }, INK) end
end

local function drawHole()
    love.graphics.setColor(0.86, 0.18, 0.16)
    love.graphics.rectangle('fill', DOOR.x1 - 80, DOOR.y1 - 80, DOOR.x2 - DOOR.x1 + 160, DOOR.y2 - DOOR.y1 + 140, 40)
    love.graphics.setColor(0.25, 0.14, 0.18)
    love.graphics.rectangle('fill', DOOR.x1, DOOR.y1, DOOR.x2 - DOOR.x1, DOOR.y2 - DOOR.y1)
    love.graphics.setColor(0.40, 0.25, 0.28)
    love.graphics.rectangle('fill', DOOR.x1, DOOR.y2 - 40, DOOR.x2 - DOOR.x1, 40)
end

function s.drawBelow()
    local d = state.activity
    if not (d and d.dial) then return end
    drawBoard()
    drawHole()
    drawDial(d)
    drawWheel(d)
    drawBell(d)
    drawSqueaker(d)
    drawKnob(d)
    drawDrumBack()
    drawString(d)
    drawRod(d)
    love.graphics.setColor(1, 1, 1)
end

function s.draw()
    local d = state.activity
    if not (d and d.dial) then return end
    drawDrumFront(d)
    flap.draw(DOOR_DEF, flap.state(d.flaps, 'door'), DOOR_POLY) -- over the Mipo behind it
    love.graphics.setColor(1, 1, 1)
end

function s.drawUI()
    local d = state.activity
    if not (d and state.playMode) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 240
    local h = BH * 3 + pad * 4 + 20
    panelRect[4] = h
    ui.panel(20, 20, w, h, '•• activity ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = 20 + pad, startY = 20 + pad + 20 })
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'reset (r)', BH) then
            destroyAll()
            build()
        end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'door (o)', BH) then flap.toggle(flap.state(d.flaps, 'door')) end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'm a Mipo  ' .. #d.mipos .. ' here')
    end)
end

return s

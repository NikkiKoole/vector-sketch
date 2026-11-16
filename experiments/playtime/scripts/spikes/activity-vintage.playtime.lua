-- activity-vintage: a Mipo activity board in the spirit of a 1970s crib activity center (our own board, our own pictures).
-- Yellowed ivory moulded plastic with a green carry handle and shallow relief (a vine, an egg Mipo on a wall, birds,
-- clouds, flowers, a mushroom), gadgets in saturated primaries:
--   left:    a chrome bell; a plunger in a tall slot; a big red push button that shoves the plunger up and rings it
--   second:  an arched window whose picture a red twist knob changes (the cow over the moon, Humpty, the whale, the
--            mitten); a red/yellow ball turning in its socket with beads rattling inside; a striped roller
--   centre:  an arched slider whose lever sails the rub-a-dub tub across a window; a name plate; a rotary dial
--   right:   a clear dome spinner with a rainbow swirl; a green flip door with a Mipo behind it (it squeaks);
--            a mirror; a candle in relief
--   bottom:  a slot where a turtle and a bunny race; a pull string with a ring on the right edge
-- The Mipos on the floor look at whatever made a sound, jump at the bell and sing along with the string.
-- Physics where it matters: the ball's beads, the turtle and bunny, the ring on its rope are bodies.
--
-- play mode: press, drag, turn and roll the gadgets; grab the turtle, the bunny, the ring and the Mipos as always.
-- keys: r reset   m a Mipo at the mouse   o open/close the door

local s = {}

local flap = love.filesystem.load('scripts/spikes/book-flaps.lua')()
local gadgets = love.filesystem.load('scripts/spikes/activity-gadgets.lua')() -- sounds, reactions, dial, spinner...
gadgets.use({ mipoKit = mipoKit, mipoActions = mipoActions, mipoEmotion = mipoEmotion, mipoVoice = mipoVoice,
    getInteractedWithPointer = getInteractedWithPointer })
local windupKey = gadgets.windupKey

local TAU = math.pi * 2
local INK = { 0.20, 0.15, 0.12 }
local IVORY = { 0.95, 0.90, 0.74 }
local RED, ORANGE, YELLOW = { 0.88, 0.20, 0.15 }, { 0.96, 0.52, 0.12 }, { 0.98, 0.80, 0.16 }
local GREEN, BLUE = { 0.18, 0.62, 0.30 }, { 0.25, 0.60, 0.92 }

-- the board, in world units (a Mipo is ~660 tall), about 1.3 : 1; the floor at y 0
local BX1, BX2, BY1, BY2 = -2800, 2800, -5000, -700
local FLOOR = 0

-- the gadgets' places
local BELL = { x = -2150, y = -4380, r = 280 }
local PLUNGER = { x = -2150, y1 = -3950, y2 = -2350 }               -- the slot
local BUTTON = { x = -2150, y = -1900, r = 230 }
local PICTURE = { x = -950, y = -4150, w = 640, h = 720 }           -- the arched window (y its middle)
local TWIST = { x = -950, y = -3570, r = 140 }
local DRUM = { x = -950, y = -2850, r = 330 }                       -- the half-and-half ball
local ROLLER = { x = -950, y = -1950, w = 720, h = 260 }
local ARC = { x = 300, y = -3900, r = 560, a1 = math.pi + 0.45, a2 = TAU - 0.45 }
local SCENE = { x = 300, y = -3780, w = 820, h = 420 }              -- the window under the arc
local PLATE = { x = 300, y = -3230, w = 900, h = 230 }
local DIAL = { x = 300, y = -2200, r = 520 }
local WHEEL = { x = 1750, y = -4250, r = 380 }                      -- the dome spinner
local DOOR = { x1 = 1300, y1 = -3650, x2 = 2200, y2 = -2550 }
local MIRROR = { x = 1750, y = -1950, w = 640, h = 560 }
local CANDLE = { x = 2480, y = -1150 }
local SLOT = { y = -1050, x1 = -2450, x2 = 2450, r = 125 }
local STRING = { ax = BX2 + 30, ay = -2700, rest = 300, max = 1500 }

local TUNE = { 72, 74, 76, 79, 76, 74, 72, 67, 69, 72, 74, 72, 79, 77, 76, 74, 72 } -- the string's song

local function sd()
    state.activityVintage = state.activityVintage or { bodies = {}, mipos = {}, flaps = {}, pending = {} }
    return state.activityVintage
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

---------------------------------------------------------------- the bodies: frame, the ball's beads, turtle and bunny, ring

local BEAD_COLOURS = { { 0.92, 0.25, 0.22 }, { 0.98, 0.78, 0.15 }, { 0.20, 0.55, 0.90 }, { 0.30, 0.72, 0.35 },
    { 0.95, 0.50, 0.15 }, { 0.65, 0.35, 0.80 }, { 0.98, 0.45, 0.65 }, { 0.25, 0.75, 0.75 } }

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
    rectFixture(frame, -4500, -6500, -4400, FLOOR)                            -- walls
    rectFixture(frame, 4400, -6500, 4500, FLOOR)
    rectFixture(frame, DOOR.x1, DOOR.y2, DOOR.x2, DOOR.y2 + 60)               -- the hole behind the door
    rectFixture(frame, DOOR.x1 - 40, DOOR.y1, DOOR.x1, DOOR.y2)
    rectFixture(frame, DOOR.x2, DOOR.y1, DOOR.x2 + 40, DOOR.y2)
    rectFixture(frame, DOOR.x1 - 40, DOOR.y1 - 40, DOOR.x2 + 40, DOOR.y1)

    -- the ball: a ring that turns in its socket, beads loose inside it
    local drum, beads = gadgets.newDrum(world, frame, DRUM.x, DRUM.y, DRUM.r, 42, BEAD_COLOURS)
    hide(drum)
    d.drum, d.drumBeads = drum, beads
    d.bodies[#d.bodies + 1] = drum
    for _, bead in ipairs(beads) do
        hide(bead.body)
        d.bodies[#d.bodies + 1] = bead.body
    end

    -- the racers: a turtle and a bunny sliding in the bottom slot (prismatic joints), knocking when they meet
    d.racers = {}
    for i, def in ipairs({ { 'turtle', SLOT.x1 + SLOT.r + 20 }, { 'bunny', SLOT.x2 - SLOT.r - 20 } }) do
        local b = love.physics.newBody(world, def[2], SLOT.y, 'dynamic')
        local f = love.physics.newFixture(b, love.physics.newCircleShape(SLOT.r), 1)
        f:setFriction(0.2)
        f:setRestitution(0.4)
        b:setLinearDamping(1.0)
        b:setFixedRotation(true)
        local j = love.physics.newPrismaticJoint(frame, b, def[2], SLOT.y, 1, 0, false)
        j:setLimits(SLOT.x1 + SLOT.r - def[2], SLOT.x2 - SLOT.r - def[2])
        j:setLimitsEnabled(true)
        hide(b)
        d.racers[i] = { body = b, kind = def[1] }
        d.bodies[#d.bodies + 1] = b
    end
    d.touching = {}

    -- the ring on its string, on the right edge: a rope joint that grows as it's pulled and shrinks back
    d.str = gadgets.newString(world, frame, STRING.ax, STRING.ay, STRING.rest, 60)
    hide(d.str.ring)
    d.bodies[#d.bodies + 1] = d.str.ring

    -- the gadgets' own state
    d.dial = gadgets.newDial()
    d.wheel = gadgets.newWheel()
    d.bell = { wobble = 0, plunger = 0, pushing = 0, button = 0 }
    d.twist = { a = 0, notch = 0, picture = 1 }
    d.roller = { offset = 0, stripe = 0 }
    d.lever = { t = 0.15, tick = 1 }
    d.mirror = { shine = -1 }
    d.flaps = {}
    d.pending = { { -1400 }, { 0 }, { 1400 }, { (DOOR.x1 + DOOR.x2) / 2, peek = true } }
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

---------------------------------------------------------------- the door (green, a squeaker pad on its front)

local DOOR_POLY = { DOOR.x1, DOOR.y1, DOOR.x2, DOOR.y1, DOOR.x2, DOOR.y2, DOOR.x1, DOOR.y2 }
local DOOR_DEF = { hingeX = DOOR.x2, from = DOOR.y2, to = DOOR.y1, angle = math.pi * 0.82, spread = 0.12, drag = 700,
    -- hinged on the right: open, it folds toward the board's edge, not over the dial
    pull = { 1, 0 }, height = DOOR.x2 - DOOR.x1, outside = GREEN, inside = { 0.55, 0.75, 0.50 },
    edge = INK, edgeWidth = 14 }
DOOR_DEF.decorate = function(def, st) -- the round squeaker pad with a face, and a knob, on the outside
    local cx, cy = (DOOR.x1 + DOOR.x2) / 2, (DOOR.y1 + DOOR.y2) / 2 - 60
    local px, py, c = flap.fold(def, st, cx, cy)
    if c > 0.05 then
        love.graphics.setColor(YELLOW)
        love.graphics.ellipse('fill', px, py, 280 * c, 280)
        love.graphics.setColor(INK)
        love.graphics.ellipse('fill', px - 90 * c, py - 40, 26 * c, 30)
        love.graphics.ellipse('fill', px + 90 * c, py - 40, 26 * c, 30)
        love.graphics.setLineWidth(12)
        love.graphics.arc('line', 'open', px, py + 30, 100 * c, 0.4, math.pi - 0.4)
        local kx, ky = flap.fold(def, st, DOOR.x1 + 90, DOOR.y2 - 260)
        love.graphics.setColor(RED)
        love.graphics.ellipse('fill', kx, ky, 50 * c, 50)
        love.graphics.setLineWidth(1)
    end
end

---------------------------------------------------------------- input

local function inCircle(g, x, y, r) return dist(g.x, g.y, x, y) <= (r or g.r) end
local function inRect(g, x, y) return math.abs(x - g.x) <= g.w / 2 and math.abs(y - g.y) <= g.h / 2 end

local LEVER_R = ARC.r
local function leverPoint(t)
    local a = ARC.a1 + (ARC.a2 - ARC.a1) * t
    return ARC.x + math.cos(a) * LEVER_R, ARC.y + math.sin(a) * LEVER_R
end

local function ringBell(d)
    d.bell.wobble = 1
    play('bell', 0.9, 0.97 + love.math.random() * 0.06)
    react(BELL.x, BELL.y, 'bell')
end

local function pressGadget(d, mx, my, grabbed, now)
    local st = flap.state(d.flaps, 'door')
    if flap.contains(DOOR_DEF, st, DOOR_POLY, mx, my) then
        if grabbed then
            if st.open < 0.5 then st.target = 1 end
        else
            flap.press(st, mx, my, now)
            play('squeakIn', 0.8, 0.95 + love.math.random() * 0.1)
            return 'door'
        end
        return nil
    end
    if grabbed then return nil end
    local lx, ly = leverPoint(d.lever.t)
    if inCircle(BUTTON, mx, my, BUTTON.r + 60) then
        d.bell.button, d.bell.pushing = 1, now -- the plunger goes up, the bell rings when it gets there
        windupKey.play('click', 0.8, 0.7)
        return 'button'
    elseif inCircle(BELL, mx, my) then
        ringBell(d)
        return 'bell'
    elseif inCircle(TWIST, mx, my, TWIST.r + 60) then
        d.twist.last = math.atan2(my - TWIST.y, mx - TWIST.x)
        return 'twist'
    elseif inCircle(DRUM, mx, my) then
        d.drumLast = math.atan2(my - DRUM.y, mx - DRUM.x)
        return 'drum'
    elseif inRect(ROLLER, mx, my) then
        d.roller.last = my
        return 'roller'
    elseif dist(lx, ly, mx, my) < 160 or (math.abs(dist(ARC.x, ARC.y, mx, my) - LEVER_R) < 120 and my < ARC.y) then
        return 'lever'
    elseif inCircle(DIAL, mx, my) then
        gadgets.dialPress(d.dial, DIAL, mx, my)
        return 'dial'
    elseif inCircle(WHEEL, mx, my) then
        gadgets.wheelPress(d.wheel, WHEEL, mx, my)
        return 'wheel'
    elseif inRect(MIRROR, mx, my) then
        d.mirror.shine = 0
        local list = mipoKit.alive(d.mipos)
        if #list > 0 then mipoVoice.squeak(list[love.math.random(#list)], 'happy') end
        react(MIRROR.x, MIRROR.y, 'mirror')
        return 'mirror'
    end
end

local DIAL_MAX = gadgets.DIAL_MAX

local function dragGadget(d, which, mx, my, dt)
    if which == 'dial' then
        gadgets.dialDrag(d.dial, DIAL, mx, my)
    elseif which == 'wheel' then
        gadgets.wheelDrag(d.wheel, WHEEL, mx, my, dt)
    elseif which == 'twist' then
        local a = math.atan2(my - TWIST.y, mx - TWIST.x)
        d.twist.a = d.twist.a + wrap(a - d.twist.last)
        d.twist.last = a
    elseif which == 'drum' and alive(d.drum) then
        local a = math.atan2(my - DRUM.y, mx - DRUM.x)
        local delta = wrap(a - d.drumLast)
        d.drumLast = a
        if dt > 0 then d.drum:setAngularVelocity(delta / dt) end
    elseif which == 'roller' then
        d.roller.offset = d.roller.offset + (my - d.roller.last)
        d.roller.last = my
    elseif which == 'lever' then
        local a = math.atan2(my - ARC.y, mx - ARC.x)
        if a < 0 then a = a + TAU end
        d.lever.t = math.max(0, math.min(1, (a - ARC.a1) / (ARC.a2 - ARC.a1)))
    end
end

local function releaseGadget(d, which, now)
    if which == 'door' then
        flap.release(flap.state(d.flaps, 'door'), now)
        play('squeakOut', 0.7, 0.95 + love.math.random() * 0.1)
    elseif which == 'dial' then
        d.dial.back = true
    elseif which == 'wheel' then
        gadgets.wheelRelease(d.wheel)
    elseif which == 'drum' then
        react(DRUM.x, DRUM.y, 'drum')
    end
end

---------------------------------------------------------------- the gadgets running

local function updateBell(d, dt, now)
    local b = d.bell
    if b.pushing then -- the plunger shoots up the slot and strikes the bell
        b.plunger = math.min(1, b.plunger + dt * 9)
        if b.plunger >= 1 then
            ringBell(d)
            b.pushing = nil
        end
    else
        b.plunger = math.max(0, b.plunger - dt * 3)
    end
    b.button = math.max(0, b.button - dt * 4)
    b.wobble = b.wobble * math.exp(-3 * dt)
    local _ = now
end

local function updateDial(d, dt, held)
    gadgets.dialUpdate(d.dial, dt, held, function() react(DIAL.x, DIAL.y, 'dial') end)
end

local SECTORS = 8
local function updateWheel(d, dt, held)
    gadgets.wheelUpdate(d.wheel, dt, held, SECTORS, function(pick)
        windupKey.note(({ 72, 74, 76, 79, 81, 84, 79, 76 })[pick], 0.6)
        react(WHEEL.x, WHEEL.y, 'wheel')
    end)
end

local PICTURES = 4
local function updateTwist(d)
    local tw = d.twist
    local n = math.floor(tw.a / (TAU / 12))
    if n ~= tw.notch then
        windupKey.play('click', 0.6, (n % 2 == 0) and 1.0 or 1.25)
        tw.notch = n
        local pic = math.floor(n / 3) % PICTURES + 1 -- a quarter turn, the next picture
        if pic ~= tw.picture then
            tw.picture = pic
            windupKey.note(({ 72, 76, 79, 84 })[pic], 0.6)
            react(PICTURE.x, PICTURE.y, 'picture')
        end
    end
end

local function updateRoller(d)
    local r = d.roller
    local n = math.floor(r.offset / 90)
    if n ~= r.stripe then
        r.stripe = n
        windupKey.play('tick', 0.5, 0.75 + love.math.random() * 0.1)
    end
end

local function updateLever(d)
    local l = d.lever
    local n = math.floor(l.t * 8 + 0.5)
    if n ~= l.tick then
        l.tick = n
        windupKey.play('tick', 0.5, 1.1)
        if n == 0 or n == 8 then
            windupKey.play('click', 0.8, 0.8)
            react(SCENE.x, SCENE.y, 'lever')
        end
    end
end

local function updateDrum(d)
    if alive(d.drum) then gadgets.drumRattle(d.drumBeads) end
end

local FANFARE = { 72, 76, 79, 84 }
local function updateRace(d)
    local t, b = d.racers[1], d.racers[2]
    if not (alive(t.body) and alive(b.body)) then return end
    local gap = b.body:getX() - t.body:getX() - SLOT.r * 2
    local touching = gap < 8
    if touching and not d.touching.racers then
        local approach = math.abs(t.body:getLinearVelocity() - b.body:getLinearVelocity())
        if approach > 40 then play('clack', approach / 900, 0.85 + love.math.random() * 0.3) end
    end
    d.touching.racers = touching
    -- a win: the turtle at the bunny's end, or the bunny at the turtle's
    local won = (t.body:getX() > SLOT.x2 - SLOT.r * 3 and 'turtle') or (b.body:getX() < SLOT.x1 + SLOT.r * 3 and 'bunny')
    if won and d.won ~= won then
        for i, m in ipairs(FANFARE) do d.fanfare = d.fanfare or {}; d.fanfare[i] = { at = love.timer.getTime() + i * 0.14, m = m } end
        react(won == 'turtle' and SLOT.x2 or SLOT.x1, SLOT.y, 'bell')
    end
    d.won = won
    if d.fanfare then
        local now, left = love.timer.getTime(), {}
        for _, f in ipairs(d.fanfare) do
            if now >= f.at then windupKey.note(f.m, 0.7) else left[#left + 1] = f end
        end
        d.fanfare = #left > 0 and left or nil
    end
end

local function updateString(d, dt)
    gadgets.stringUpdate(d.str, STRING, dt, TUNE, function() react(STRING.ax, STRING.ay, 'sing') end)
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
    camera.setBounds(-4400, -6200, 4400, 900)
    camera.zoomTo(0.125, 0.4)
end

function s.onUnload()
    destroyAll()
end

local PANEL_W = 200
local panelRect = { 0, 20, PANEL_W, 0 }
local function overPanel()
    if ui.isPanelFolded('•• vintage ••') then return false end
    local mx, my = love.mouse.getPosition()
    local r = panelRect
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

function s.update(dt)
    local d = sd()
    if not (alive(d.frame) and d.twist) then return end
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
        react((DOOR.x1 + DOOR.x2) / 2, (DOOR.y1 + DOOR.y2) / 2, 'door')
    end
    updateBell(d, dt, now)
    updateDial(d, dt, d.active == 'dial')
    updateWheel(d, dt, d.active == 'wheel')
    updateTwist(d)
    updateRoller(d)
    updateLever(d)
    updateDrum(d)
    updateRace(d)
    updateString(d, dt)
    if d.mirror.shine >= 0 then
        d.mirror.shine = d.mirror.shine + dt * 1.6
        if d.mirror.shine > 1.4 then d.mirror.shine = -1 end
    end
    stopLooking()
end

-- From the bridge: s.poke(name[, a]) works a gadget: 'button', 'bell', 'door', 'wheel' (spin a), 'dial' (a radians,
-- let go), 'twist' (a radians), 'drum' (spin a rad/s), 'roller' (a units), 'lever' (t 0..1), 'mirror'
function s.poke(name, a)
    local d = sd()
    local now = love.timer.getTime()
    if name == 'button' then
        d.bell.button, d.bell.pushing = 1, now
    elseif name == 'bell' then
        ringBell(d)
    elseif name == 'door' then
        flap.toggle(flap.state(d.flaps, 'door'))
        play('squeakIn', 0.8)
    elseif name == 'wheel' then
        d.wheel.w, d.wheel.spinning = a or 9, true
    elseif name == 'dial' then
        d.dial.a, d.dial.back = math.min(DIAL_MAX, a or 4), true
    elseif name == 'twist' then
        d.twist.a = d.twist.a + (a or TAU / 4)
    elseif name == 'drum' and alive(d.drum) then
        d.drum:setAngularVelocity(a or 8)
    elseif name == 'roller' then
        d.roller.offset = d.roller.offset + (a or 400)
    elseif name == 'lever' then
        d.lever.t = a or 1
    elseif name == 'mirror' then
        d.mirror.shine = 0
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

---------------------------------------------------------------- drawing helpers

local function setc(col, a) love.graphics.setColor(col[1], col[2], col[3], a or col[4] or 1) end

local function circle(mode, x, y, r, col, a)
    setc(col, a)
    love.graphics.circle(mode, x, y, r)
end

local function inked(x, y, r, col, width)
    circle('fill', x, y, r, col)
    love.graphics.setLineWidth(width or 14)
    circle('line', x, y, r, INK)
    love.graphics.setLineWidth(1)
end

local function worn(col, k) return { col[1] * k, col[2] * k, col[3] * k } end

-- a collar moulded round each gadget: the plastic raised a little, lit from the top left
local function collar(x, y, r)
    circle('fill', x + 14, y + 18, r, { 0.70, 0.62, 0.45 })
    circle('fill', x - 8, y - 10, r, { 1, 0.98, 0.90 })
    circle('fill', x, y, r, IVORY)
end

local function collarRect(x, y, w, h, rad)
    setc({ 0.70, 0.62, 0.45 })
    love.graphics.rectangle('fill', x - w / 2 + 14, y - h / 2 + 18, w, h, rad)
    setc({ 1, 0.98, 0.90 })
    love.graphics.rectangle('fill', x - w / 2 - 8, y - h / 2 - 10, w, h, rad)
    setc(IVORY)
    love.graphics.rectangle('fill', x - w / 2, y - h / 2, w, h, rad)
end

-- relief: a shape sculpted into the plastic, drawn three times (shadow, light, face), all in the board's colour
local function relief(fn)
    love.graphics.push()
    love.graphics.translate(9, 11)
    love.graphics.setColor(0.76, 0.69, 0.52)
    fn()
    love.graphics.translate(-15, -17)
    love.graphics.setColor(1, 0.98, 0.88)
    fn()
    love.graphics.translate(6, 6)
    love.graphics.setColor(0.91, 0.85, 0.67)
    fn()
    love.graphics.pop()
end

---------------------------------------------------------------- the board and its relief

local function drawRelief()
    -- a vine climbing the left side
    relief(function()
        local pts = {}
        for y = BY2 - 250, BY1 + 350, -60 do pts[#pts + 1], pts[#pts + 2] = BX1 + 210 + math.sin(y * 0.004) * 55, y end
        love.graphics.setLineWidth(26)
        love.graphics.line(pts)
        for y = BY2 - 400, BY1 + 500, -330 do
            local x = BX1 + 210 + math.sin(y * 0.004) * 55
            love.graphics.ellipse('fill', x + 70, y - 20, 75, 34)
            love.graphics.ellipse('fill', x - 70, y - 180, 75, 34)
        end
    end)
    -- clouds and birds along the top
    relief(function()
        for _, c in ipairs({ { -1550, -4790 }, { 950, -4800 }, { 2450, -4700 } }) do
            love.graphics.circle('fill', c[1], c[2], 70)
            love.graphics.circle('fill', c[1] + 80, c[2] - 30, 85)
            love.graphics.circle('fill', c[1] + 170, c[2], 65)
        end
        love.graphics.setLineWidth(18)
        for _, b in ipairs({ { -350, -4820 }, { -200, -4760 }, { 1250, -4650 } }) do
            love.graphics.arc('line', 'open', b[1] - 40, b[2], 40, math.pi * 1.1, math.pi * 1.9)
            love.graphics.arc('line', 'open', b[1] + 40, b[2], 40, math.pi * 1.1, math.pi * 1.9)
        end
    end)
    -- the wavy line along the bottom, flowers, a mushroom, an egg Mipo on a brick wall
    relief(function()
        local pts = {}
        for x = BX1 + 400, BX2 - 400, 50 do pts[#pts + 1], pts[#pts + 2] = x, -1380 + math.sin(x * 0.006) * 30 end
        love.graphics.setLineWidth(20)
        love.graphics.line(pts)
        for _, f in ipairs({ { -1750, -1460 }, { -1550, -1440 }, { 1050, -1450 }, { 2450, -1450 } }) do
            for k = 0, 4 do
                local a = k / 5 * TAU
                love.graphics.circle('fill', f[1] + math.cos(a) * 34, f[2] + math.sin(a) * 34, 26)
            end
        end
        love.graphics.arc('fill', -1200, -1430, 90, math.pi, TAU) -- the mushroom
        love.graphics.rectangle('fill', -1235, -1440, 70, 70)
        love.graphics.rectangle('fill', -600, -1560, 300, 170) -- the wall
        love.graphics.ellipse('fill', -450, -1660, 85, 110) -- the egg Mipo on it
    end)
    -- the candle in the corner
    relief(function()
        love.graphics.rectangle('fill', CANDLE.x - 40, CANDLE.y - 160, 80, 190, 10)
        love.graphics.ellipse('fill', CANDLE.x, CANDLE.y - 210, 26, 48)
        love.graphics.rectangle('fill', CANDLE.x - 80, CANDLE.y + 20, 160, 30, 10)
    end)
    -- the bricks and the egg's face, scratched in
    love.graphics.setColor(0.70, 0.62, 0.45)
    love.graphics.setLineWidth(8)
    for row = 0, 2 do
        local y = -1560 + row * 57
        love.graphics.line(-600, y, -300, y)
        for x = -600 + (row % 2) * 50, -300, 100 do love.graphics.line(x, y, x, y + 57) end
    end
    love.graphics.circle('fill', -480, -1690, 12)
    love.graphics.circle('fill', -420, -1690, 12)
    love.graphics.arc('line', 'open', -450, -1660, 35, 0.4, math.pi - 0.4)
    love.graphics.setLineWidth(1)
end

local function drawBoard()
    -- the room: a wall and a rug
    love.graphics.setColor(0.86, 0.90, 0.88)
    love.graphics.rectangle('fill', -6000, -7000, 12000, 7000)
    love.graphics.setColor(0.70, 0.58, 0.45)
    love.graphics.rectangle('fill', -6000, FLOOR, 12000, 1500)
    -- its stand
    for _, x in ipairs({ -2200, 2200 }) do
        setc(worn(GREEN, 0.9))
        love.graphics.rectangle('fill', x - 200, BY2 - 50, 400, FLOOR - BY2 + 50, 60)
        setc(INK)
        love.graphics.setLineWidth(12)
        love.graphics.rectangle('line', x - 200, BY2 - 50, 400, FLOOR - BY2 + 50, 60)
    end
    -- the green carry handle
    setc(GREEN)
    love.graphics.setLineWidth(150)
    love.graphics.arc('line', 'open', 0, BY1 + 120, 900, math.pi * 1.15, math.pi * 1.85)
    love.graphics.setLineWidth(1)
    -- the board: shadow, rim, face
    love.graphics.setColor(0, 0, 0, 0.18)
    love.graphics.rectangle('fill', BX1 + 60, BY1 + 80, BX2 - BX1, BY2 - BY1, 260)
    love.graphics.setColor(0.86, 0.79, 0.60)
    love.graphics.rectangle('fill', BX1, BY1, BX2 - BX1, BY2 - BY1, 260)
    setc(IVORY)
    love.graphics.rectangle('fill', BX1 + 70, BY1 + 70, BX2 - BX1 - 140, BY2 - BY1 - 140, 210)
    love.graphics.setColor(1, 0.98, 0.90, 0.6)
    love.graphics.setLineWidth(20)
    love.graphics.rectangle('line', BX1 + 80, BY1 + 80, BX2 - BX1 - 160, BY2 - BY1 - 160, 200)
    setc(INK)
    love.graphics.setLineWidth(14)
    love.graphics.rectangle('line', BX1, BY1, BX2 - BX1, BY2 - BY1, 260)
    love.graphics.setLineWidth(1)
    drawRelief()
end

---------------------------------------------------------------- the gadgets

local function drawBellColumn(d)
    local b = d.bell
    -- the slot and the brown plunger rod in it
    collarRect(PLUNGER.x, (PLUNGER.y1 + PLUNGER.y2) / 2, 200, PLUNGER.y2 - PLUNGER.y1 + 80, 60)
    love.graphics.setColor(0.25, 0.18, 0.14)
    love.graphics.rectangle('fill', PLUNGER.x - 55, PLUNGER.y1, 110, PLUNGER.y2 - PLUNGER.y1, 40)
    local up = b.plunger * 420
    love.graphics.setColor(0.55, 0.36, 0.20)
    love.graphics.rectangle('fill', PLUNGER.x - 35, PLUNGER.y1 + 350 - up, 70, PLUNGER.y2 - PLUNGER.y1 - 300, 30)
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.rectangle('fill', PLUNGER.x - 25, PLUNGER.y1 + 380 - up, 18, PLUNGER.y2 - PLUNGER.y1 - 380, 9)
    -- the chrome bell, wobbling after a ding
    collar(BELL.x, BELL.y + 40, BELL.r + 50)
    love.graphics.push()
    love.graphics.translate(BELL.x, BELL.y + 120)
    love.graphics.rotate(math.sin(love.timer.getTime() * 38) * 0.05 * b.wobble)
    love.graphics.setColor(0.80, 0.82, 0.86)
    love.graphics.arc('fill', 0, 0, BELL.r, math.pi, TAU)
    love.graphics.setColor(0.60, 0.62, 0.68)
    love.graphics.arc('fill', 0, 0, BELL.r, math.pi * 1.6, TAU)
    love.graphics.setColor(1, 1, 1, 0.75)
    love.graphics.arc('fill', -80, -40, 150, math.pi * 1.15, math.pi * 1.45)
    circle('fill', 0, -BELL.r - 20, 40, { 0.70, 0.72, 0.76 })
    setc(INK)
    love.graphics.setLineWidth(12)
    love.graphics.arc('line', 'closed', 0, 0, BELL.r, math.pi, TAU)
    love.graphics.pop()
    if b.wobble > 0.05 then -- rings in the air
        love.graphics.setColor(INK[1], INK[2], INK[3], b.wobble * 0.6)
        love.graphics.setLineWidth(10)
        for k = 1, 2 do
            local r = BELL.r + 60 + k * 70 + (1 - b.wobble) * 120
            love.graphics.arc('line', 'open', BELL.x, BELL.y + 120, r, math.pi * 1.15, math.pi * 1.4)
            love.graphics.arc('line', 'open', BELL.x, BELL.y + 120, r, math.pi * 1.6, math.pi * 1.85)
        end
    end
    -- the big red push button in its cream collar
    collar(BUTTON.x, BUTTON.y, BUTTON.r + 70)
    circle('fill', BUTTON.x, BUTTON.y + 30, BUTTON.r, worn(RED, 0.6))
    local press = b.button * 30
    inked(BUTTON.x, BUTTON.y + press, BUTTON.r, RED, 12)
    circle('fill', BUTTON.x - 70, BUTTON.y - 70 + press, 70, { 1, 1, 1 }, 0.3)
    love.graphics.setLineWidth(1)
end

-- the pictures in the arched window: our own stories
local function drawStoryPicture(i, x, y)
    love.graphics.push()
    love.graphics.translate(x, y)
    if i == 1 then -- the cow jumping over the moon
        love.graphics.setColor(0.18, 0.22, 0.45)
        love.graphics.rectangle('fill', -320, -360, 640, 720)
        love.graphics.setColor(0.98, 0.92, 0.55)
        love.graphics.circle('fill', 60, 80, 120)
        love.graphics.setColor(0.18, 0.22, 0.45)
        love.graphics.circle('fill', 110, 50, 105)
        love.graphics.setColor(1, 1, 1)
        love.graphics.ellipse('fill', -40, -120, 150, 80)
        love.graphics.setColor(INK)
        love.graphics.circle('fill', -80, -140, 30)
        love.graphics.circle('fill', 20, -100, 25)
        love.graphics.setLineWidth(18)
        for _, lx in ipairs({ -150, -80, 30, 90 }) do love.graphics.line(lx, -60, lx - 30, 10) end
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle('fill', 130, -170, 55)
    elseif i == 2 then -- the egg Mipo on the wall
        love.graphics.setColor(0.60, 0.82, 0.98)
        love.graphics.rectangle('fill', -320, -360, 640, 720)
        love.graphics.setColor(0.80, 0.30, 0.22)
        love.graphics.rectangle('fill', -250, 60, 500, 300)
        love.graphics.setColor(0.98, 0.94, 0.80)
        love.graphics.ellipse('fill', 0, -80, 130, 170)
        love.graphics.setColor(INK)
        love.graphics.circle('fill', -45, -110, 18)
        love.graphics.circle('fill', 45, -110, 18)
        love.graphics.setLineWidth(12)
        love.graphics.arc('line', 'open', 0, -60, 50, 0.4, math.pi - 0.4)
    elseif i == 3 then -- the whale
        love.graphics.setColor(0.60, 0.82, 0.98)
        love.graphics.rectangle('fill', -320, -360, 640, 720)
        love.graphics.setColor(0.20, 0.45, 0.80)
        love.graphics.rectangle('fill', -320, 150, 640, 210)
        love.graphics.setColor(0.35, 0.42, 0.60)
        love.graphics.ellipse('fill', 0, 120, 250, 140)
        love.graphics.polygon('fill', 220, 100, 330, 20, 330, 180)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setLineWidth(20)
        love.graphics.line(-60, -30, -60, -170)
        love.graphics.circle('fill', -100, -190, 35)
        love.graphics.circle('fill', -20, -190, 35)
    else -- the mitten in the snow
        love.graphics.setColor(0.85, 0.90, 0.96)
        love.graphics.rectangle('fill', -320, -360, 640, 720)
        love.graphics.setColor(0.82, 0.18, 0.18)
        love.graphics.ellipse('fill', 0, 40, 170, 230)
        love.graphics.ellipse('fill', -160, 40, 60, 110)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle('fill', -150, 220, 300, 80)
        love.graphics.rectangle('fill', -150, 0, 300, 40)
    end
    love.graphics.pop()
end

local function archPoly(x, y, w, h)
    local pts = { x - w / 2, y + h / 2, x + w / 2, y + h / 2 }
    local top = y - h / 2 + w / 2
    for k = 0, 16 do
        local a = k / 16 * math.pi
        pts[#pts + 1], pts[#pts + 2] = x + math.cos(a) * w / 2, top - math.sin(a) * w / 2
    end
    return pts
end

local function drawSecondColumn(d)
    -- the arched picture window and its twist knob
    local P = PICTURE
    local arch = archPoly(P.x, P.y, P.w, P.h)
    local collarPts = archPoly(P.x, P.y, P.w + 120, P.h + 120)
    love.graphics.setColor(0.70, 0.62, 0.45)
    love.graphics.push(); love.graphics.translate(14, 18); love.graphics.polygon('fill', collarPts); love.graphics.pop()
    setc(ORANGE)
    love.graphics.polygon('fill', collarPts)
    love.graphics.stencil(function() love.graphics.polygon('fill', arch) end, 'replace', 1)
    love.graphics.setStencilTest('greater', 0)
    drawStoryPicture(d.twist.picture, P.x, P.y)
    love.graphics.setStencilTest()
    setc(INK)
    love.graphics.setLineWidth(12)
    love.graphics.polygon('line', arch)
    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.polygon('fill', P.x - P.w / 2 + 40, P.y - P.h / 2 + P.w / 2, P.x - P.w / 2 + 110, P.y - P.h / 2 + P.w / 2,
        P.x - P.w / 2 + 110, P.y + P.h / 2 - 40, P.x - P.w / 2 + 40, P.y + P.h / 2 - 40)
    collar(TWIST.x, TWIST.y, TWIST.r + 40)
    love.graphics.push()
    love.graphics.translate(TWIST.x, TWIST.y)
    love.graphics.rotate(d.twist.a)
    inked(0, 0, TWIST.r, RED, 10)
    setc(worn(RED, 0.7))
    love.graphics.rectangle('fill', -30, -TWIST.r + 10, 60, TWIST.r * 2 - 20, 20)
    love.graphics.pop()
    -- the red/yellow ball turning in its socket, beads rattling inside (the top half is clear)
    collar(DRUM.x, DRUM.y, DRUM.r + 70)
    circle('fill', DRUM.x, DRUM.y, DRUM.r + 25, { 0.30, 0.22, 0.16 })
    if alive(d.drum) then
        local a = d.drum:getAngle()
        circle('fill', DRUM.x, DRUM.y, DRUM.r, { 1, 0.95, 0.80 })
        for _, bead in ipairs(d.drumBeads) do
            local x, y = bead.body:getPosition()
            inked(x, y, 42, bead.colour, 6)
        end
        love.graphics.setColor(RED[1], RED[2], RED[3], 0.9)
        love.graphics.arc('fill', DRUM.x, DRUM.y, DRUM.r, a, a + math.pi / 2)
        love.graphics.arc('fill', DRUM.x, DRUM.y, DRUM.r, a + math.pi, a + math.pi * 1.5)
        love.graphics.setColor(YELLOW[1], YELLOW[2], YELLOW[3], 0.55)
        love.graphics.arc('fill', DRUM.x, DRUM.y, DRUM.r, a + math.pi / 2, a + math.pi)
        love.graphics.arc('fill', DRUM.x, DRUM.y, DRUM.r, a + math.pi * 1.5, a + TAU)
        love.graphics.setColor(1, 1, 1, 0.4)
        love.graphics.arc('fill', DRUM.x, DRUM.y, DRUM.r * 0.85, math.pi * 1.1, math.pi * 1.45)
        love.graphics.setLineWidth(12)
        circle('line', DRUM.x, DRUM.y, DRUM.r, INK)
    end
    -- the green-and-white striped roller
    local R = ROLLER
    collarRect(R.x, R.y, R.w + 120, R.h + 120, 70)
    setc({ 0.30, 0.22, 0.16 })
    love.graphics.rectangle('fill', R.x - R.w / 2, R.y - R.h / 2, R.w, R.h, 30)
    love.graphics.stencil(function() love.graphics.rectangle('fill', R.x - R.w / 2, R.y - R.h / 2, R.w, R.h, 30) end,
        'replace', 1)
    love.graphics.setStencilTest('greater', 0)
    local off = d.roller.offset % 180
    for k = -2, 4 do
        local y = R.y - R.h / 2 + k * 180 + off
        setc(GREEN)
        love.graphics.rectangle('fill', R.x - R.w / 2, y, R.w, 90)
        love.graphics.setColor(0.97, 0.96, 0.92)
        love.graphics.rectangle('fill', R.x - R.w / 2, y + 90, R.w, 90)
    end
    love.graphics.setColor(0, 0, 0, 0.25) -- round: dark at its top and bottom
    love.graphics.rectangle('fill', R.x - R.w / 2, R.y - R.h / 2, R.w, 50)
    love.graphics.rectangle('fill', R.x - R.w / 2, R.y + R.h / 2 - 50, R.w, 50)
    love.graphics.setStencilTest()
    setc(INK)
    love.graphics.setLineWidth(12)
    love.graphics.rectangle('line', R.x - R.w / 2, R.y - R.h / 2, R.w, R.h, 30)
    love.graphics.setLineWidth(1)
end

local function drawTub(x, y)
    for k, col in ipairs({ { 0.95, 0.60, 0.70 }, { 0.50, 0.80, 0.55 }, { 0.60, 0.65, 0.95 } }) do -- three heads
        local hx = x + (k - 2) * 95
        local hy = y - 90 - math.abs(k - 2) * -10
        setc(col)
        love.graphics.circle('fill', hx, hy, 52)
        love.graphics.setColor(INK)
        love.graphics.circle('fill', hx - 17, hy - 8, 8)
        love.graphics.circle('fill', hx + 17, hy - 8, 8)
    end
    love.graphics.setColor(0.62, 0.40, 0.22)
    love.graphics.polygon('fill', x - 190, y - 60, x + 190, y - 60, x + 150, y + 60, x - 150, y + 60)
    love.graphics.setColor(0.45, 0.28, 0.15)
    love.graphics.setLineWidth(10)
    love.graphics.line(x - 175, y - 20, x + 175, y - 20)
    love.graphics.line(x - 160, y + 25, x + 160, y + 25)
    love.graphics.setLineWidth(1)
end

local function drawCentre(d)
    -- the orange arched slider track, its yellow lever
    setc(worn(ORANGE, 0.75))
    love.graphics.setLineWidth(150)
    love.graphics.arc('line', 'open', ARC.x + 12, ARC.y + 16, ARC.r, ARC.a1, ARC.a2)
    setc(ORANGE)
    love.graphics.arc('line', 'open', ARC.x, ARC.y, ARC.r, ARC.a1, ARC.a2)
    love.graphics.setColor(0.35, 0.20, 0.10)
    love.graphics.setLineWidth(30)
    love.graphics.arc('line', 'open', ARC.x, ARC.y, ARC.r, ARC.a1 + 0.05, ARC.a2 - 0.05)
    local lx, ly = leverPoint(d.lever.t)
    inked(lx, ly, 95, YELLOW, 10)
    circle('fill', lx - 30, ly - 30, 30, { 1, 1, 1 }, 0.4)
    -- the framed window: the tub sails across with the lever
    local S = SCENE
    collarRect(S.x, S.y, S.w + 110, S.h + 110, 40)
    setc(YELLOW)
    love.graphics.rectangle('fill', S.x - S.w / 2 - 40, S.y - S.h / 2 - 40, S.w + 80, S.h + 80, 30)
    love.graphics.stencil(function() love.graphics.rectangle('fill', S.x - S.w / 2, S.y - S.h / 2, S.w, S.h) end,
        'replace', 1)
    love.graphics.setStencilTest('greater', 0)
    love.graphics.setColor(0.60, 0.84, 0.98)
    love.graphics.rectangle('fill', S.x - S.w / 2, S.y - S.h / 2, S.w, S.h)
    love.graphics.setColor(0.98, 0.85, 0.30)
    love.graphics.circle('fill', S.x + S.w / 2 - 90, S.y - S.h / 2 + 80, 55)
    local t = d.lever.t
    local tx = S.x - S.w / 2 + 110 + t * (S.w - 220)
    local bob = math.sin(love.timer.getTime() * 3) * 12
    drawTub(tx, S.y + 70 + bob)
    love.graphics.setColor(0.20, 0.45, 0.85)
    local wave = {}
    for x = S.x - S.w / 2, S.x + S.w / 2, 20 do
        wave[#wave + 1], wave[#wave + 2] = x, S.y + 110 + math.sin(x * 0.03 + love.timer.getTime() * 2) * 14
    end
    wave[#wave + 1], wave[#wave + 2] = S.x + S.w / 2, S.y + S.h / 2
    wave[#wave + 1], wave[#wave + 2] = S.x - S.w / 2, S.y + S.h / 2
    local ok, tris = pcall(love.math.triangulate, wave)
    if ok then for _, tr in ipairs(tris) do love.graphics.polygon('fill', tr) end end
    love.graphics.setStencilTest()
    setc(INK)
    love.graphics.setLineWidth(12)
    love.graphics.rectangle('line', S.x - S.w / 2, S.y - S.h / 2, S.w, S.h)
    -- the raised name plate
    local Pl = PLATE
    collarRect(Pl.x, Pl.y, Pl.w, Pl.h, 60)
    setc(YELLOW)
    love.graphics.rectangle('fill', Pl.x - Pl.w / 2 + 25, Pl.y - Pl.h / 2 + 25, Pl.w - 50, Pl.h - 50, 45)
    local font = love.graphics.getFont()
    local text = 'MIPO'
    local sc = (Pl.h - 70) / font:getHeight()
    local tw = font:getWidth(text) * sc
    for _, l in ipairs({ { 8, 10, { 0.70, 0.52, 0.08 } }, { -6, -7, { 1, 0.95, 0.65 } }, { 0, 0, worn(YELLOW, 0.93) } }) do
        setc(l[3])
        love.graphics.print(text, Pl.x - tw / 2 + l[1], Pl.y - Pl.h / 2 + 30 + l[2], 0, sc, sc)
    end
    -- the blue rotary dial, 0-9
    collar(DIAL.x, DIAL.y, DIAL.r + 70)
    inked(DIAL.x, DIAL.y, DIAL.r, BLUE, 12)
    local digitScale = 90 / font:getHeight()
    for i = 1, 10 do
        local a = -math.pi * 0.35 - (i - 1) * 0.5
        local x, y = DIAL.x + math.cos(a) * 370, DIAL.y + math.sin(a) * 370
        love.graphics.setColor(1, 1, 1)
        local label = tostring(i % 10)
        love.graphics.print(label, x - font:getWidth(label) * digitScale / 2, y - 45, 0, digitScale, digitScale)
    end
    local a0 = d.dial.a
    for i = 1, 10 do
        local a = -math.pi * 0.35 - (i - 1) * 0.5 + a0
        local x, y = DIAL.x + math.cos(a) * 370, DIAL.y + math.sin(a) * 370
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.circle('fill', x, y, 80)
        love.graphics.setLineWidth(10)
        circle('line', x, y, 80, INK)
    end
    inked(DIAL.x, DIAL.y, 210, IVORY, 10)
    setc(INK)
    love.graphics.circle('fill', DIAL.x - 60, DIAL.y - 40, 20)
    love.graphics.circle('fill', DIAL.x + 60, DIAL.y - 40, 20)
    love.graphics.setLineWidth(14)
    love.graphics.arc('line', 'open', DIAL.x, DIAL.y + 10, 80, 0.3, math.pi - 0.3)
    local sa = math.pi * 0.42 -- the finger stop
    love.graphics.setColor(0.80, 0.82, 0.86)
    love.graphics.polygon('fill', DIAL.x + math.cos(sa) * 420, DIAL.y + math.sin(sa) * 420,
        DIAL.x + math.cos(sa - 0.1) * 560, DIAL.y + math.sin(sa - 0.1) * 560,
        DIAL.x + math.cos(sa + 0.1) * 560, DIAL.y + math.sin(sa + 0.1) * 560)
    love.graphics.setLineWidth(1)
end

local function drawRightColumn(d)
    -- the clear dome spinner: a rainbow swirl under a dome, a knob in the middle
    collar(WHEEL.x, WHEEL.y, WHEEL.r + 70)
    local a0 = d.wheel.a
    local rainbow = { RED, ORANGE, YELLOW, GREEN, BLUE, { 0.45, 0.30, 0.75 }, { 0.90, 0.40, 0.65 }, { 0.35, 0.80, 0.85 } }
    for i = 1, SECTORS do
        local pts = { WHEEL.x, WHEEL.y }
        local s1, s2 = a0 + (i - 1) / SECTORS * TAU, a0 + i / SECTORS * TAU
        for r = 30, WHEEL.r, 35 do
            local a = s1 + r * 0.004
            pts[#pts + 1], pts[#pts + 2] = WHEEL.x + math.cos(a) * r, WHEEL.y + math.sin(a) * r
        end
        for r = WHEEL.r, 30, -35 do
            local a = s2 + r * 0.004
            pts[#pts + 1], pts[#pts + 2] = WHEEL.x + math.cos(a) * r, WHEEL.y + math.sin(a) * r
        end
        setc(rainbow[i])
        local ok, tris = pcall(love.math.triangulate, pts)
        if ok then for _, tr in ipairs(tris) do love.graphics.polygon('fill', tr) end end
    end
    love.graphics.setColor(1, 1, 1, 0.25) -- the dome
    love.graphics.circle('fill', WHEEL.x, WHEEL.y, WHEEL.r)
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.arc('fill', WHEEL.x, WHEEL.y, WHEEL.r * 0.85, math.pi * 1.1, math.pi * 1.4)
    love.graphics.setLineWidth(12)
    circle('line', WHEEL.x, WHEEL.y, WHEEL.r, INK)
    inked(WHEEL.x, WHEEL.y, 85, RED, 8)
    -- the pointer at the top, kicked by each peg
    love.graphics.push()
    love.graphics.translate(WHEEL.x, WHEEL.y - WHEEL.r - 100)
    love.graphics.rotate(-d.wheel.kick * 0.35 * (d.wheel.w >= 0 and 1 or -1))
    setc(RED)
    love.graphics.polygon('fill', -45, 0, 45, 0, 0, 120)
    setc(INK)
    love.graphics.setLineWidth(8)
    love.graphics.polygon('line', -45, 0, 45, 0, 0, 120)
    love.graphics.pop()
    -- the hole behind the green door
    setc(GREEN)
    love.graphics.rectangle('fill', DOOR.x1 - 70, DOOR.y1 - 70, DOOR.x2 - DOOR.x1 + 140, DOOR.y2 - DOOR.y1 + 130, 40)
    love.graphics.setColor(0.22, 0.16, 0.14)
    love.graphics.rectangle('fill', DOOR.x1, DOOR.y1, DOOR.x2 - DOOR.x1, DOOR.y2 - DOOR.y1)
    -- the square mirror
    local M = MIRROR
    collarRect(M.x, M.y, M.w + 120, M.h + 120, 50)
    setc(BLUE)
    love.graphics.rectangle('fill', M.x - M.w / 2 - 35, M.y - M.h / 2 - 35, M.w + 70, M.h + 70, 40)
    love.graphics.setColor(0.78, 0.82, 0.86)
    love.graphics.rectangle('fill', M.x - M.w / 2, M.y - M.h / 2, M.w, M.h, 20)
    love.graphics.stencil(function() love.graphics.rectangle('fill', M.x - M.w / 2, M.y - M.h / 2, M.w, M.h, 20) end,
        'replace', 1)
    love.graphics.setStencilTest('greater', 0)
    love.graphics.setColor(1, 1, 1, 0.35)
    for _, k in ipairs({ -200, 40 }) do
        love.graphics.polygon('fill', M.x + k, M.y - M.h, M.x + k + 120, M.y - M.h, M.x + k - 300, M.y + M.h,
            M.x + k - 420, M.y + M.h)
    end
    if d.mirror.shine >= 0 then -- a flash sweeping across
        local sx = M.x - M.w + d.mirror.shine * M.w * 1.6
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.polygon('fill', sx, M.y - M.h, sx + 160, M.y - M.h, sx - 240, M.y + M.h, sx - 400, M.y + M.h)
    end
    love.graphics.setStencilTest()
    setc(INK)
    love.graphics.setLineWidth(12)
    love.graphics.rectangle('line', M.x - M.w / 2, M.y - M.h / 2, M.w, M.h, 20)
    love.graphics.setLineWidth(1)
end

local function drawTurtle(x, y)
    setc(worn(GREEN, 0.75))
    for _, l in ipairs({ -70, 70 }) do love.graphics.ellipse('fill', x + l, y + 70, 35, 28) end
    love.graphics.ellipse('fill', x + 125, y + 10, 45, 38)
    setc(GREEN)
    love.graphics.arc('fill', x, y + 40, 125, math.pi, TAU)
    setc(worn(GREEN, 0.7))
    love.graphics.setLineWidth(10)
    love.graphics.line(x - 50, y - 60, x, y - 10, x + 50, y - 60)
    love.graphics.line(x, y - 10, x, y + 40)
    setc(INK)
    love.graphics.circle('fill', x + 140, y, 9)
    love.graphics.setLineWidth(1)
end

local function drawBunny(x, y)
    setc(BLUE)
    love.graphics.ellipse('fill', x - 40, y - 130, 26, 80)
    love.graphics.ellipse('fill', x + 15, y - 135, 26, 80)
    love.graphics.ellipse('fill', x, y + 30, 110, 85)
    love.graphics.circle('fill', x - 30, y - 45, 70)
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle('fill', x + 100, y + 40, 32)
    setc(INK)
    love.graphics.circle('fill', x - 55, y - 55, 10)
end

local function drawSlot(d)
    collarRect(0, SLOT.y, SLOT.x2 - SLOT.x1 + 200, 160, 70)
    love.graphics.setColor(0.25, 0.18, 0.14)
    love.graphics.rectangle('fill', SLOT.x1, SLOT.y - 35, SLOT.x2 - SLOT.x1, 70, 35)
    if d.racers then
        local t, b = d.racers[1], d.racers[2]
        if alive(t.body) then drawTurtle(t.body:getX(), t.body:getY() - 50) end
        if alive(b.body) then drawBunny(b.body:getX(), b.body:getY() - 50) end
    end
end

local function drawString(d)
    if not d.str then return end
    inked(STRING.ax - 30, STRING.ay, 70, GREEN, 8)
    gadgets.drawString(d.str, STRING, RED, INK)
end

function s.drawBelow()
    local d = state.activityVintage
    if not (d and d.twist) then return end
    drawBoard()
    drawBellColumn(d)
    drawSecondColumn(d)
    drawCentre(d)
    drawRightColumn(d)
    drawSlot(d)
    drawString(d)
    love.graphics.setColor(1, 1, 1)
end

function s.draw()
    local d = state.activityVintage
    if not (d and d.twist) then return end
    flap.draw(DOOR_DEF, flap.state(d.flaps, 'door'), DOOR_POLY) -- over the Mipo behind it
    love.graphics.setColor(1, 1, 1)
end

function s.drawUI()
    local d = state.activityVintage
    if not (d and state.playMode) then return end
    ui.startFrame()
    local BH, pad = 34, 6
    local h = BH * 3 + pad * 4 + 20
    local sw = love.graphics.getWidth() / (ui.scale or 1)
    panelRect[1], panelRect[4] = sw - PANEL_W - 20, h
    ui.panel(panelRect[1], 20, PANEL_W, h, '•• vintage ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = panelRect[1] + pad, startY = 20 + pad + 20 })
        local x, y = ui.nextLayoutPosition(layout, PANEL_W - 20, BH)
        if ui.button(x, y, PANEL_W - 20, 'reset (r)', BH) then
            destroyAll()
            build()
        end
        x, y = ui.nextLayoutPosition(layout, PANEL_W - 20, BH)
        if ui.button(x, y, PANEL_W - 20, 'door (o)', BH) then flap.toggle(flap.state(d.flaps, 'door')) end
        x, y = ui.nextLayoutPosition(layout, PANEL_W - 20, BH)
        ui.label(x, y, 'm a Mipo  ' .. #d.mipos .. ' here')
    end)
end

return s

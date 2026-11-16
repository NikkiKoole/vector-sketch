-- activity-gadgets: what both activity boards share (scripts/spikes/activity, activity-vintage): the sounds made in
-- the script, the Mipos reacting, and how the gadgets work (a rotary dial that springs back, a spinner that ticks to
-- a stop, a drum of rattling beads, a string with a ring that zips back in singing, a knob that clicks per notch).
-- Each board draws them its own way. Loaded with love.filesystem.load('scripts/spikes/activity-gadgets.lua')(),
-- so it runs in the plain globals; the scene hands in the names only its env has (mipoKit, mipoActions, ...).
--   local gadgets = love.filesystem.load(...)()
--   gadgets.use{ mipoKit, mipoActions, mipoEmotion, mipoVoice, getInteractedWithPointer }

local lib = {}
local env = {}
local TAU = math.pi * 2

local windupKey = love.filesystem.load('scripts/spikes/windup-key.lua')() -- its click/tick and music-box notes
lib.windupKey = windupKey

function lib.use(names)
    for k, v in pairs(names) do env[k] = v end
end

local function wrap(a) return (a + math.pi) % TAU - math.pi end
lib.wrap = wrap
function lib.dist(x1, y1, x2, y2) return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2) end

---------------------------------------------------------------- sounds, made once

local sounds = {}
local function makeSound(len, fn)
    local rate = 22050
    local data = love.sound.newSoundData(math.floor(rate * len), rate, 16, 1)
    local phase = 0
    for i = 0, data:getSampleCount() - 1 do
        local v
        v, phase = fn(i / rate, phase, rate)
        data:setSample(i, math.max(-1, math.min(1, v)))
    end
    return love.audio.newSource(data, 'static')
end

-- make them all now (at a scene's start, not in the middle of play), and the notes the boards play
function lib.makeSounds(midis)
    windupKey.preload(midis)
    if sounds.bell or not love.audio then return end -- (no sound device: ./playtime.sh thumbs)
    sounds.bell = makeSound(1.6, function(t, ph) -- a bright bell: inharmonic partials, the high ones die first
        local f = 1180
        local e = math.min(1, t / 0.002)
        return (math.sin(TAU * f * t) * math.exp(-t * 2.2) + 0.6 * math.sin(TAU * f * 2.76 * t) * math.exp(-t * 4)
            + 0.35 * math.sin(TAU * f * 5.4 * t) * math.exp(-t * 7) + 0.2 * math.sin(TAU * f * 8.9 * t) * math.exp(-t * 12))
            * e * 0.32, ph
    end)
    local function squeak(f1, f2, len)
        return makeSound(len, function(t, ph, rate)
            local u = t / len
            local f = f1 + (f2 - f1) * u * (2 - u)
            ph = ph + f / rate
            local e = math.min(1, t / 0.01) * math.min(1, (len - t) / 0.03)
            local w = math.sin(ph * TAU)
            w = w / (0.35 + math.abs(w)) -- a squeezed, rubbery wave
            return (w * 0.5 + (love.math.random() * 2 - 1) * 0.06) * e * 0.5, ph
        end)
    end
    sounds.squeakIn = squeak(1400, 800, 0.2)
    sounds.squeakOut = squeak(900, 1600, 0.16)
    sounds.clack = makeSound(0.07, function(t, ph) -- wooden beads knocking
        return ((love.math.random() * 2 - 1) * 0.5 + math.sin(TAU * 1750 * t) * 0.7 + math.sin(TAU * 3100 * t) * 0.4)
            * math.exp(-t * 90) * 0.5, ph
    end)
    sounds.rattle = makeSound(0.05, function(t, ph) -- a plastic bead inside the drum
        return ((love.math.random() * 2 - 1) * 0.7 + math.sin(TAU * 4300 * t) * 0.3) * math.exp(-t * 160) * 0.35, ph
    end)
    sounds.zip = makeSound(0.12, function(t, ph) -- the string running in
        return (love.math.random() * 2 - 1) * math.exp(-t * 25) * 0.12, ph
    end)
end

-- 'bell', 'squeakIn', 'squeakOut', 'clack', 'rattle', 'zip'; and windupKey's 'click', 'tick'
function lib.play(name, volume, pitch)
    if not love.audio then return end
    if not sounds[name] then
        windupKey.play(name, volume, pitch)
        return
    end
    local src = sounds[name]:clone()
    src:setVolume(math.min(1, volume or 1))
    src:setPitch(pitch or 1)
    src:play()
end
lib.note = windupKey.note

---------------------------------------------------------------- the Mipos react

-- something made a sound at x, y: the Mipos look at it; the bell makes them jump, the string makes them sing
function lib.react(mipos, x, y, kind)
    local now = love.timer.getTime()
    for _, inst in ipairs(env.mipoKit.alive(mipos)) do
        env.mipoActions.lookAt(inst, function() return x, y end)
        inst._activityLookUntil = now + 2.5
        if kind == 'bell' then
            if env.mipoActions.isGrounded(inst) and love.math.random() < 0.8 then env.mipoActions.jump(inst, 0) end
            env.mipoEmotion.set(inst, 'happy', 1, 1.5)
            env.mipoVoice.squeak(inst, 'happy')
        elseif kind == 'loud' then
            env.mipoEmotion.set(inst, 'surprised', 1, 0.8)
            if love.math.random() < 0.5 then env.mipoVoice.squeak(inst, 'curious') end
        elseif kind == 'sing' then
            env.mipoVoice.flapMouth(inst, 0.22)
            env.mipoEmotion.set(inst, 'happy', 0.8, 1)
        elseif love.math.random() < 0.25 then
            env.mipoVoice.squeak(inst, 'curious')
        end
    end
end

-- the looks that have run their time
function lib.stopLooking(mipos)
    local now = love.timer.getTime()
    for _, inst in ipairs(env.mipoKit.alive(mipos)) do
        if inst._activityLookUntil and now > inst._activityLookUntil then
            inst._activityLookUntil = nil
            env.mipoActions.stopLooking(inst)
        end
    end
end

---------------------------------------------------------------- the rotary dial: drag it round, it springs back clicking

lib.DIAL_MAX, lib.DIAL_NOTCH = 5.4, TAU / 12

function lib.newDial() return { a = 0, notch = 0, back = false } end
function lib.dialPress(dial, g, mx, my) dial.back, dial.last = false, math.atan2(my - g.y, mx - g.x) end
function lib.dialDrag(dial, g, mx, my)
    local a = math.atan2(my - g.y, mx - g.x)
    local delta = wrap(a - dial.last)
    dial.last = a
    dial.a = math.max(0, math.min(lib.DIAL_MAX, dial.a + delta)) -- clockwise only, up to the finger stop
end
-- onHome() when it's back at rest
function lib.dialUpdate(dial, dt, held, onHome)
    if dial.back and not held then
        dial.a = math.max(0, dial.a - 3.2 * dt) -- the spring takes it home
        if dial.a == 0 then dial.back = false end
    end
    local n = math.floor(dial.a / lib.DIAL_NOTCH)
    if n ~= dial.notch then
        if dial.back and not held then
            lib.play('tick', 0.8, 1.15)
        else
            lib.play('click', 0.7, 0.9 + n * 0.03)
        end
        if n == 0 and dial.notch > 0 and onHome then onHome() end
        dial.notch = n
    end
end

---------------------------------------------------------------- the spinner: flick it, it ticks to a stop

function lib.newWheel() return { a = 0.3, w = 0, tick = 0, kick = 0 } end
function lib.wheelPress(w, g, mx, my) w.last, w.w, w.moved = math.atan2(my - g.y, mx - g.x), 0, 0 end
function lib.wheelDrag(w, g, mx, my, dt)
    local a = math.atan2(my - g.y, mx - g.x)
    local delta = wrap(a - w.last)
    w.last = a
    w.a = w.a + delta
    w.moved = w.moved + math.abs(delta)
    if dt > 0 then w.w = w.w * 0.6 + (delta / dt) * 0.4 end
end
function lib.wheelRelease(w)
    if w.moved < 0.15 then w.w = (love.math.random() < 0.5 and -1 or 1) * (6 + love.math.random() * 5) end -- a tap spins it
    w.w = math.max(-16, math.min(16, w.w))
    w.spinning = math.abs(w.w) > 0.3
end
-- onStop(sector) when it comes to rest; sector 1..sectors under the pointer at the top
function lib.wheelUpdate(w, dt, held, sectors, onStop)
    if not held then
        w.a = w.a + w.w * dt
        local sign = w.w > 0 and 1 or -1
        w.w = w.w * math.exp(-0.7 * dt) - sign * 0.5 * dt
        if w.w * sign <= 0 then
            w.w = 0
            if w.spinning then
                w.spinning = false
                if onStop then onStop(math.floor(((-math.pi / 2 - w.a) / TAU * sectors) % sectors) + 1) end
            end
        end
    end
    local t = math.floor(w.a / (TAU / sectors) + 0.5) -- a peg passes the pointer
    if t ~= w.tick then
        w.tick = t
        w.kick = 1
        lib.play('tick', 0.9, 0.9 + love.math.random() * 0.1)
    end
    w.kick = math.max(0, w.kick - dt * 8)
end

---------------------------------------------------------------- a knob that clicks per notch (12 a turn)

-- returns the new notch when it changed
function lib.knobUpdate(k)
    local n = math.floor(k.a / (TAU / 12))
    if n ~= k.notch then
        lib.play('click', 0.6, (n % 2 == 0) and 1.0 or 1.25)
        k.notch = n
        return n
    end
end

---------------------------------------------------------------- the drum: a ring on an axle, beads loose inside

-- the drum's bodies: { drum = body, beads = { { body, colour } } }
function lib.newDrum(world, frame, x, y, r, beadR, colours)
    local drum = love.physics.newBody(world, x, y, 'dynamic')
    local pts = {}
    for i = 0, 23 do
        local a = i / 24 * TAU
        pts[#pts + 1], pts[#pts + 2] = math.cos(a) * r, math.sin(a) * r
    end
    love.physics.newFixture(drum, love.physics.newChainShape(true, unpack(pts)))
    love.physics.newFixture(drum, love.physics.newCircleShape(r * 0.9), 0.4):setSensor(true) -- its weight
    drum:setAngularDamping(0.5)
    love.physics.newRevoluteJoint(frame, drum, x, y, false)
    local beads = {}
    for i, colour in ipairs(colours) do
        local a = i / #colours * TAU
        local b = love.physics.newBody(world, x + math.cos(a) * r * 0.45, y + math.sin(a) * r * 0.45, 'dynamic')
        local f = love.physics.newFixture(b, love.physics.newCircleShape(beadR), 1)
        f:setRestitution(0.3)
        f:setFriction(0.3)
        b:setBullet(true)
        beads[i] = { body = b, colour = colour, vx = 0, vy = 0 }
    end
    return drum, beads
end

-- a bead whose speed changed suddenly hit the rim or another bead: a rattle (three a frame at most)
function lib.drumRattle(beads)
    local sounded = 0
    for _, bead in ipairs(beads) do
        local vx, vy = bead.body:getLinearVelocity()
        local dv = math.sqrt((vx - bead.vx) ^ 2 + (vy - bead.vy) ^ 2)
        bead.vx, bead.vy = vx, vy
        if dv > 260 and sounded < 3 then
            sounded = sounded + 1
            lib.play('rattle', dv / 1400, 0.8 + love.math.random() * 0.5)
        end
    end
end

---------------------------------------------------------------- the string with a ring

-- the ring and its rope joint; st = { ring, rope, length, zipped, note } kept on state
function lib.newString(world, frame, ax, ay, rest, dx)
    local ring = love.physics.newBody(world, ax + (dx or 0), ay + rest, 'dynamic')
    love.physics.newFixture(ring, love.physics.newCircleShape(85), 2):setFriction(0.6)
    ring:setLinearDamping(0.8)
    local rope = love.physics.newRopeJoint(frame, ring, ax, ay, ax + (dx or 0), ay + rest, rest, false)
    return { ring = ring, rope = rope, length = rest, zipped = 0, note = 0 }
end

-- pulled out while held, it zips back in when let go, a note of the tune every 85 units: onNote()
function lib.stringUpdate(st, g, dt, tune, onNote)
    local ring, rope = st.ring, st.rope
    if not (ring and not ring:isDestroyed() and rope and not rope:isDestroyed()) then return end
    local held = false
    for _, body in ipairs(env.getInteractedWithPointer()) do held = held or body == ring end
    local rx, ry = ring:getPosition()
    local dd = lib.dist(g.ax, g.ay, rx, ry)
    if held then
        if dd > st.length - 15 then st.length = math.min(g.max, dd + 10) end
        st.zipped = 0
    elseif st.length > g.rest then
        local was = st.length
        st.length = math.max(g.rest, st.length - 520 * dt)
        st.zipped = st.zipped + (was - st.length)
        ring:setAwake(true) -- a ring at rest isn't pulled in otherwise
        if st.zipped >= 85 then
            st.zipped = st.zipped - 85
            st.note = (st.note % #tune) + 1
            lib.note(tune[st.note], 0.7)
            lib.play('zip', 0.6)
            if onNote then onNote() end
        end
        if st.length == g.rest then st.note = 0 end
    end
    rope:setMaxLength(st.length)
end

-- the string, sagging when slack, and the ring
function lib.drawString(st, g, colour, ink)
    local ring = st.ring
    if not (ring and not ring:isDestroyed()) then return end
    local rx, ry = ring:getPosition()
    local dd = lib.dist(g.ax, g.ay, rx, ry)
    love.graphics.setColor(0.95, 0.90, 0.78)
    love.graphics.setLineWidth(18)
    local slack = math.max(0, st.length - dd)
    if slack < 10 then
        love.graphics.line(g.ax, g.ay, rx, ry - 80)
    else
        local mx, my = (g.ax + rx) / 2, (g.ay + ry) / 2 + math.min(400, slack * 0.6)
        love.graphics.line(love.math.newBezierCurve(g.ax, g.ay, mx, my, rx, ry - 80):render())
    end
    love.graphics.setColor(colour)
    love.graphics.setLineWidth(36)
    love.graphics.circle('line', rx, ry, 70)
    love.graphics.setColor(ink)
    love.graphics.setLineWidth(6)
    love.graphics.circle('line', rx, ry, 90)
    love.graphics.circle('line', rx, ry, 50)
    love.graphics.setLineWidth(1)
end

return lib

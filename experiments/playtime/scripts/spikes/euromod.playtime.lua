-- euromod: a toy modular synth — modules with knobs and jacks, patch cables between them, Mipos listening.
-- Nikki 2026-11-16: "a sort of activity board slightly more ... you have these things with patches, and ropes/wires
-- between them, maybe lets make a sort of euromod thingie very basic?"
--
-- A wooden rack on a table, two rows of modules. Cables carry signals, not audio: beats (yellow jacks), notes
-- (blue), wobble (purple) and sound (red). The clock ticks eighth notes on the synth's own audio clock (notes
-- are booked a little ahead: scheduleAt), and each tick runs down the cables: the sequencer steps and sends its
-- step's note, the dice sends a random one, the drum plays its pattern's step. A voice that gets a note plays it
-- on its instrument, wobbled by the LFO if that's patched in, but only when its sound cable goes to the speaker.
-- Cables are verlet ropes that sag; an out can feed several cables, an in takes one. The background music is off
-- while the scene is open (back as it was when it closes).
--
-- play mode (tab): drag from a jack to another to patch (a wrong pair drops the cable), pull a cable off an in
-- jack to move or drop it, drag a knob up/down. keys: r the starting patch   c pull every cable
-- From the bridge: s.status(); s.patch(fromModule, fromJack, toModule, toJack); s.knob(module, knob, v)

local s = {}

local sound = love.filesystem.load('scripts/spikes/euromod-sound.lua')()
local synth, music = sound.synth, sound.music

local GROUND_W = 5000
local TABLE_Y = 0
local TOY_VERSION = 1
local JACK_R = 30
local KNOB_R = 40
local SCALE = { 0, 2, 4, 7, 9 } -- major pentatonic: anything sounds alright
local BASE = 60

local TYPES = {
    beat = { 0.98, 0.80, 0.18 },
    note = { 0.30, 0.62, 0.95 },
    wobble = { 0.68, 0.45, 0.90 },
    sound = { 0.92, 0.30, 0.25 },
}
local INSTRUMENTS = { 'marimba', 'kalimba', 'vibes', 'steelpan', 'tb303', 'flute', 'rhodes', 'pickBass' }
local DRUMS = {
    { kick = { 1, 5 }, snare = { 3, 7 }, hat = { 1, 2, 3, 4, 5, 6, 7, 8 } },
    { kick = { 1, 4, 7 }, snare = { 5 }, hat = { 1, 3, 5, 7 } },
    { kick = { 1, 3, 5, 7 } },
    { shaker = { 1, 2, 3, 4, 5, 6, 7, 8 }, rim = { 4, 8 }, kick = { 1 } },
}

-- the modules: a rect (x, y, w, h), a colour, jacks { name, dir, type, x, y } and knobs { name, x, y, value }
-- (positions inside the module, from its top-left)
local function defs()
    local R1, R2, H = -1210, -640, 540
    local seqKnobs = {}
    for i = 1, 8 do
        local start = ({ 0.1, 0.3, 0.5, 0.3, 0.7, 0.5, 0.3, 0.1 })[i]
        seqKnobs[i] = { name = 'step' .. i, x = 80 + (i - 1) * 86, y = 250, value = start, r = 32 }
    end
    table.insert(seqKnobs, { name = 'steps', x = 120, y = 430, value = 1 })
    return {
        { id = 'clock', label = 'CLOCK', x = -1090, y = R1, w = 250, h = H, color = { 0.95, 0.75, 0.25 },
            jacks = { { name = 'out1', dir = 'out', type = 'beat', x = 75, y = 440 },
                { name = 'out2', dir = 'out', type = 'beat', x = 175, y = 440 } },
            knobs = { { name = 'tempo', x = 125, y = 230, value = 0.45, r = 60 } } },
        { id = 'seq', label = 'STEPS', x = -830, y = R1, w = 760, h = H, color = { 0.45, 0.70, 0.95 },
            jacks = { { name = 'clock', dir = 'in', type = 'beat', x = 400, y = 440 },
                { name = 'note', dir = 'out', type = 'note', x = 640, y = 440 } },
            knobs = seqKnobs },
        { id = 'dice', label = 'DICE', x = -60, y = R1, w = 280, h = H, color = { 0.95, 0.55, 0.60 },
            jacks = { { name = 'clock', dir = 'in', type = 'beat', x = 75, y = 440 },
                { name = 'note', dir = 'out', type = 'note', x = 205, y = 440 } },
            knobs = { { name = 'often', x = 140, y = 230, value = 0.5 } } },
        { id = 'drum', label = 'DRUM', x = 230, y = R1, w = 330, h = H, color = { 0.90, 0.40, 0.30 },
            jacks = { { name = 'clock', dir = 'in', type = 'beat', x = 85, y = 440 },
                { name = 'sound', dir = 'out', type = 'sound', x = 245, y = 440 } },
            knobs = { { name = 'pattern', x = 165, y = 230, value = 0, r = 55 } } },
        { id = 'lfo', label = 'WOBBLE', x = 570, y = R1, w = 280, h = H, color = { 0.70, 0.55, 0.92 },
            jacks = { { name = 'out', dir = 'out', type = 'wobble', x = 140, y = 440 } },
            knobs = { { name = 'speed', x = 140, y = 230, value = 0.3 } } },
        { id = 'voiceA', label = 'VOICE A', x = -1090, y = R2, w = 440, h = H, color = { 0.45, 0.80, 0.55 },
            jacks = { { name = 'note', dir = 'in', type = 'note', x = 80, y = 440 },
                { name = 'wobble', dir = 'in', type = 'wobble', x = 220, y = 440 },
                { name = 'sound', dir = 'out', type = 'sound', x = 360, y = 440 } },
            knobs = { { name = 'instrument', x = 130, y = 230, value = 0, r = 55 },
                { name = 'octave', x = 310, y = 230, value = 0.5 } } },
        { id = 'voiceB', label = 'VOICE B', x = -640, y = R2, w = 440, h = H, color = { 0.40, 0.75, 0.75 },
            jacks = { { name = 'note', dir = 'in', type = 'note', x = 80, y = 440 },
                { name = 'wobble', dir = 'in', type = 'wobble', x = 220, y = 440 },
                { name = 'sound', dir = 'out', type = 'sound', x = 360, y = 440 } },
            knobs = { { name = 'instrument', x = 130, y = 230, value = 4 / 7, r = 55 },
                { name = 'octave', x = 310, y = 230, value = 0.15 } } },
        { id = 'speaker', label = 'SPEAKER', x = -190, y = R2, w = 640, h = H, color = { 0.30, 0.30, 0.34 },
            jacks = { { name = 'in1', dir = 'in', type = 'sound', x = 80, y = 440 },
                { name = 'in2', dir = 'in', type = 'sound', x = 200, y = 440 },
                { name = 'in3', dir = 'in', type = 'sound', x = 320, y = 440 } },
            knobs = { { name = 'volume', x = 540, y = 440, value = 0.7 } } },
    }
end

local function em()
    local p = state.euromod
    if not p then
        p = { mipos = {} }
        state.euromod = p
    end
    return p
end

local function modOf(p, id)
    for _, m in ipairs(p.mods) do if m.id == id then return m end end
end

local function jackOf(m, name)
    for _, j in ipairs(m.jacks) do if j.name == name then return j end end
end

local function knobOf(m, name)
    for _, k in ipairs(m.knobs) do if k.name == name then return k.value end end
    return 0
end

local function jackPos(m, j) return m.x + j.x, m.y + j.y end

---------------------------------------------------------------- cables (verlet ropes)

local SEGS = 16
local CABLE_COLORS = { { 0.95, 0.35, 0.30 }, { 0.98, 0.78, 0.20 }, { 0.30, 0.65, 0.95 }, { 0.45, 0.80, 0.40 },
    { 0.95, 0.55, 0.75 }, { 0.98, 0.98, 0.95 }, { 0.20, 0.20, 0.22 } }

local function newCable(p, ax, ay, bx, by)
    local c = { pts = {}, prev = {}, color = CABLE_COLORS[((p.cableN or 0) % #CABLE_COLORS) + 1] }
    p.cableN = (p.cableN or 0) + 1
    for i = 0, SEGS do
        local t = i / SEGS
        local x, y = ax + (bx - ax) * t, ay + (by - ay) * t
        c.pts[#c.pts + 1] = { x, y }
        c.prev[#c.prev + 1] = { x, y }
    end
    c.len = 300
    p.cables[#p.cables + 1] = c
    return c
end

local function endPos(p, e)
    if not e then return nil end
    if e.drag then return p.drag.x, p.drag.y end
    local m = modOf(p, e.mod)
    return jackPos(m, jackOf(m, e.jack))
end

local function stepCable(p, c, dt)
    local ax, ay = endPos(p, c.a)
    local bx, by = endPos(p, c.b)
    local d = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
    local want = math.max(220, d * 1.18 + 60)
    c.len = c.len + (want - c.len) * math.min(1, dt * 3)
    local seg = c.len / SEGS
    local g = 2400 * dt * dt
    for i = 2, SEGS do
        local pt, pv = c.pts[i], c.prev[i]
        local vx, vy = (pt[1] - pv[1]) * 0.96, (pt[2] - pv[2]) * 0.96
        pv[1], pv[2] = pt[1], pt[2]
        pt[1], pt[2] = pt[1] + vx, pt[2] + vy + g
    end
    for _ = 1, 8 do
        c.pts[1][1], c.pts[1][2] = ax, ay
        c.pts[SEGS + 1][1], c.pts[SEGS + 1][2] = bx, by
        for i = 1, SEGS do
            local p1, p2 = c.pts[i], c.pts[i + 1]
            local dx, dy = p2[1] - p1[1], p2[2] - p1[2]
            local dist = math.max(1e-3, math.sqrt(dx * dx + dy * dy))
            local diff = (dist - seg) / dist * 0.5
            local w1 = (i == 1) and 0 or 1
            local w2 = (i == SEGS) and 0 or 1
            local k = (w1 + w2 > 0) and (2 / (w1 + w2)) or 0
            p1[1], p1[2] = p1[1] + dx * diff * w1 * k, p1[2] + dy * diff * w1 * k
            p2[1], p2[2] = p2[1] - dx * diff * w2 * k, p2[2] - dy * diff * w2 * k
        end
    end
end

-- the cable plugged into an in jack, if any
local function cableAt(p, modId, jackName)
    for _, c in ipairs(p.cables) do
        for _, e in ipairs({ c.a, c.b }) do
            if e and not e.drag and e.mod == modId and e.jack == jackName then return c end
        end
    end
end

-- a finished cable: one end an out, the other an in of the same type, the in free
local function valid(p, c)
    if not (c.a and c.b) or c.a.drag or c.b.drag then return false end
    local ma, mb = modOf(p, c.a.mod), modOf(p, c.b.mod)
    local ja, jb = jackOf(ma, c.a.jack), jackOf(mb, c.b.jack)
    if ja.type ~= jb.type or ja.dir == jb.dir or c.a.mod == c.b.mod then return false end
    local inEnd = ja.dir == 'in' and c.a or c.b
    for _, o in ipairs(p.cables) do
        if o ~= c then
            for _, e in ipairs({ o.a, o.b }) do
                if e and not e.drag and e.mod == inEnd.mod and e.jack == inEnd.jack then return false end
            end
        end
    end
    return true
end

-- where an out goes: { { mod, jack }, ... } of the ins its cables reach
local function targets(p, modId, jackName)
    local out = {}
    for _, c in ipairs(p.cables) do
        if c.a and c.b and not c.a.drag and not c.b.drag then
            local other
            if c.a.mod == modId and c.a.jack == jackName then other = c.b end
            if c.b.mod == modId and c.b.jack == jackName then other = c.a end
            if other then out[#out + 1] = other end
        end
    end
    return out
end

function s.patch(fromMod, fromJack, toMod, toJack)
    local p = em()
    local ma, mb = modOf(p, fromMod), modOf(p, toMod)
    if not (ma and mb) then return false end
    local ax, ay = jackPos(ma, jackOf(ma, fromJack))
    local bx, by = jackPos(mb, jackOf(mb, toJack))
    local c = newCable(p, ax, ay, bx, by)
    c.a, c.b = { mod = fromMod, jack = fromJack }, { mod = toMod, jack = toJack }
    if not valid(p, c) then
        table.remove(p.cables)
        return false
    end
    return true
end

local function startPatch(p)
    p.cables = {}
    s.patch('clock', 'out1', 'seq', 'clock')
    s.patch('seq', 'note', 'voiceA', 'note')
    s.patch('voiceA', 'sound', 'speaker', 'in1')
end

---------------------------------------------------------------- sound

local function ready()
    return synth and synth.start and synth.start() and synth.audioTime()
end

local function flash(p, modId, what)
    p.flashes = p.flashes or {}
    p.flashes[modId .. (what or '')] = love.timer.getTime()
end

local function toSpeaker(p, modId, jackName)
    for _, t in ipairs(targets(p, modId, jackName)) do
        if t.mod == 'speaker' then return true end
    end
    return false
end

local function lfoAt(p, t)
    local speed = 0.1 + knobOf(modOf(p, 'lfo'), 'speed') * 4
    return math.sin(2 * math.pi * speed * t)
end

local function volume(p) return 1 + knobOf(modOf(p, 'speaker'), 'volume') * 5 end

local function playVoice(p, modId, degree, t)
    local m = modOf(p, modId)
    flash(p, modId)
    if not toSpeaker(p, modId, 'sound') then return end
    local inst = INSTRUMENTS[math.floor(knobOf(m, 'instrument') * (#INSTRUMENTS - 1) + 0.5) + 1]
    local octave = math.floor(knobOf(m, 'octave') * 2 + 0.5) - 1
    local midi = BASE + 12 * octave + 12 * math.floor(degree / #SCALE) + SCALE[degree % #SCALE + 1]
    local opts
    local wob = cableAt(p, modId, 'wobble')
    if wob then
        local v = lfoAt(p, t)
        opts = { timbre = v * 0.8, cutoff = v * 1.5 }
    end
    synth.scheduleAt(inst, t, midi, volume(p), 260, opts)
    p.speakerAt = love.timer.getTime()
    p.lastNote = love.timer.getTime()
end

local function sendNote(p, modId, degree, t)
    for _, target in ipairs(targets(p, modId, 'note')) do
        if target.mod == 'voiceA' or target.mod == 'voiceB' then playVoice(p, target.mod, degree, t) end
    end
end

-- what a beat does at the in jack it reaches
local function beatInto(p, target, t, tick)
    local m = modOf(p, target.mod)
    if target.mod == 'seq' then
        local steps = 2 + math.floor(knobOf(m, 'steps') * 6 + 0.5)
        p.seqStep = (p.seqStep or 0) % steps + 1
        local degree = math.floor(knobOf(m, 'step' .. p.seqStep) * 9 + 0.5)
        flash(p, 'seq')
        sendNote(p, 'seq', degree, t)
    elseif target.mod == 'dice' then
        flash(p, 'dice')
        if love.math.random() < knobOf(m, 'often') then
            p.diceShown = love.math.random(1, 6)
            sendNote(p, 'dice', love.math.random(0, 9), t)
        end
    elseif target.mod == 'drum' then
        local pat = DRUMS[math.floor(knobOf(m, 'pattern') * (#DRUMS - 1) + 0.5) + 1]
        local step = (tick - 1) % 8 + 1
        flash(p, 'drum')
        if toSpeaker(p, 'drum', 'sound') then
            for name, steps in pairs(pat) do
                for _, st in ipairs(steps) do
                    if st == step then
                        local loud = volume(p) * (name == 'hat' and 0.6 or 1)
                        synth.scheduleAt(name, t, name == 'hat' and 70 or 48, loud, 120)
                        p.speakerAt = love.timer.getTime()
                    end
                end
            end
        end
    end
end

local function clock(p)
    local now = ready()
    if not now then return end
    local bpm = 60 + knobOf(modOf(p, 'clock'), 'tempo') * 120
    local step = 60 / bpm / 2 -- eighth notes
    if not p.nextTick or p.nextTick < now or p.nextTick > now + 2 then p.nextTick = now + 0.1 end
    while p.nextTick < now + 0.08 do
        p.tick = (p.tick or 0) + 1
        flash(p, 'clock')
        for _, jn in ipairs({ 'out1', 'out2' }) do
            for _, target in ipairs(targets(p, 'clock', jn)) do beatInto(p, target, p.nextTick, p.tick) end
        end
        p.nextTick = p.nextTick + step
    end
end

---------------------------------------------------------------- scene

local function makeGround(p)
    if p.ground and not p.ground:isDestroyed() then return end
    p.ground = love.physics.newBody(world, 0, 0, 'static')
    love.physics.newFixture(p.ground, love.physics.newEdgeShape(-GROUND_W / 2, TABLE_Y, GROUND_W / 2, TABLE_Y))
    love.physics.newFixture(p.ground, love.physics.newEdgeShape(-GROUND_W / 2, TABLE_Y, -GROUND_W / 2, -3000))
    love.physics.newFixture(p.ground, love.physics.newEdgeShape(GROUND_W / 2, TABLE_Y, GROUND_W / 2, -3000))
    state.hiddenBodies = state.hiddenBodies or {}
    state.hiddenBodies[p.ground] = true
end

local function speakerTarget()
    local p = state.euromod
    local m = p and p.mods and modOf(p, 'speaker')
    if m then return m.x + m.w * 0.6, m.y + 200 end
    return 0, -600
end

local function addMipos(p)
    p.mipos = mipoKit.alive(p.mipos)
    if #p.mipos > 0 then return end
    for _, x in ipairs({ -1400, 1350 }) do
        local inst = mipoKit.spawn(p.mipos, x, TABLE_Y - 500)
        if inst then mipoActions.lookAt(inst, speakerTarget) end
    end
end

function s.onStart()
    worldState.paused = false
    local p = em()
    makeGround(p)
    if p.version ~= TOY_VERSION then
        p.mods = defs()
        startPatch(p)
        p.version = TOY_VERSION
    end
    addMipos(p)
    if music and p.musicWas == nil then
        p.musicWas = music.enabled
        music.enabled = false
    end
    camera.setBounds(-GROUND_W / 2, -2600, GROUND_W / 2, 400)
end

function s.onUnload()
    local p = state.euromod
    if not p then return end
    if music and p.musicWas ~= nil then
        music.enabled = p.musicWas
        p.musicWas = nil
    end
    if p.ground and not p.ground:isDestroyed() then p.ground:destroy() end
    p.ground = nil
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local p = em()
    if key == 'r' then startPatch(p)
    elseif key == 'c' then p.cables = {} end
end

function s.knob(modId, name, v)
    local m = modOf(em(), modId)
    for _, k in ipairs(m and m.knobs or {}) do if k.name == name then k.value = v end end
end

---------------------------------------------------------------- input

local function overPanel()
    local r = s._panelRect
    if not r then return false end
    local mx, my = love.mouse.getPosition()
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

local function jackUnder(p, x, y)
    for _, m in ipairs(p.mods) do
        for _, j in ipairs(m.jacks) do
            local jx, jy = jackPos(m, j)
            if (x - jx) ^ 2 + (y - jy) ^ 2 < (JACK_R * 1.6) ^ 2 then return m, j end
        end
    end
end

local function knobUnder(p, x, y)
    for _, m in ipairs(p.mods) do
        for _, k in ipairs(m.knobs) do
            local r = (k.r or KNOB_R) * 1.2
            if (x - m.x - k.x) ^ 2 + (y - m.y - k.y) ^ 2 < r * r then return k end
        end
    end
end

local function input(p)
    local down = state.playMode and love.mouse.isDown(1) and not overPanel()
    local mx, my = mouseWorldPos()
    if down and not p.wasDown then
        local m, j = jackUnder(p, mx, my)
        if m then
            local plugged = j.dir == 'in' and cableAt(p, m.id, j.name)
            p.drag = { x = mx, y = my }
            if plugged then
                -- pull this end out of the in jack
                if plugged.a.mod == m.id and plugged.a.jack == j.name then plugged.a = { drag = true }
                else plugged.b = { drag = true } end
                p.dragCable = plugged
            else
                local jx, jy = jackPos(m, j)
                local c = newCable(p, jx, jy, mx, my)
                c.a, c.b = { mod = m.id, jack = j.name }, { drag = true }
                p.dragCable = c
            end
        else
            local k = knobUnder(p, mx, my)
            if k then p.dragKnob, p.knobY, p.knobV = k, love.mouse.getY(), k.value end
        end
    elseif down then
        if p.dragCable then p.drag.x, p.drag.y = mx, my end
        if p.dragKnob then
            p.dragKnob.value = math.max(0, math.min(1, p.knobV + (p.knobY - love.mouse.getY()) / 220))
        end
    elseif p.wasDown then
        local c = p.dragCable
        if c then
            local m, j = jackUnder(p, mx, my)
            local e = c.a.drag and 'a' or 'b'
            if m then c[e] = { mod = m.id, jack = j.name } end
            if not (m and valid(p, c)) then
                for i, o in ipairs(p.cables) do if o == c then table.remove(p.cables, i) break end end
            end
        end
        p.dragCable, p.dragKnob = nil, nil
    end
    p.wasDown = down
end

function s.update(dt)
    local p = em()
    if p.version ~= TOY_VERSION or dt <= 0 then return end
    input(p)
    for _, c in ipairs(p.cables) do stepCable(p, c, dt) end
    clock(p)
    -- the Mipos like it when something plays
    local now = love.timer.getTime()
    if p.lastNote and now - p.lastNote < 0.3 and now - (p.cheeredAt or 0) > 6 then
        p.cheeredAt = now
        for _, inst in ipairs(mipoKit.alive(p.mipos)) do mipoEmotion.set(inst, 'happy', 1, 3) end
    end
end

---------------------------------------------------------------- drawing

local function setc(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

local WALL = { 0.20, 0.22, 0.30 }
local WALL_LINE = { 0.24, 0.26, 0.35 }
local TABLE = { 0.60, 0.42, 0.28 }
local TABLE_EDGE = { 0.44, 0.30, 0.19 }
local WOOD = { 0.72, 0.52, 0.32 }
local INK = { 0.12, 0.12, 0.14 }
local PANEL = { 0.86, 0.86, 0.84 }
local WHITE = { 1, 1, 1 }

local function lit(p, key, dur)
    local t = p.flashes and p.flashes[key]
    if not t then return 0 end
    return math.max(0, 1 - (love.timer.getTime() - t) / (dur or 0.15))
end

local function text(str, x, y, size, col)
    setc(col or INK)
    local f = love.graphics.getFont()
    local sc = size / f:getHeight()
    love.graphics.print(str, x - f:getWidth(str) * sc / 2, y - size / 2, 0, sc, sc)
end

function s.drawBelow()
    setc(WALL)
    love.graphics.rectangle('fill', -GROUND_W / 2, -3000, GROUND_W, 3000 + TABLE_Y)
    setc(WALL_LINE)
    for x = -GROUND_W / 2, GROUND_W / 2, 180 do love.graphics.rectangle('fill', x, -3000, 8, 3000 + TABLE_Y) end
    setc(TABLE)
    love.graphics.rectangle('fill', -GROUND_W / 2, TABLE_Y, GROUND_W, 110)
    setc(TABLE_EDGE)
    love.graphics.rectangle('fill', -GROUND_W / 2, TABLE_Y + 110, GROUND_W, 600)
    -- the rack: a wooden case
    setc(INK)
    love.graphics.rectangle('fill', -1140, -1260, 2040, 1230, 30, 30)
    setc(WOOD)
    love.graphics.rectangle('fill', -1128, -1248, 2016, 1206, 24, 24)
    setc(INK)
    love.graphics.rectangle('fill', -1100, -1222, 1960, 1160, 10, 10)
end

local function drawKnob(m, k)
    local x, y, r = m.x + k.x, m.y + k.y, k.r or KNOB_R
    local a = -math.pi * 1.25 + k.value * math.pi * 1.5
    setc(INK, 0.35)
    love.graphics.arc('line', 'open', x, y, r + 12, -math.pi * 1.25, -math.pi * 1.25 + math.pi * 1.5)
    setc(INK)
    love.graphics.circle('fill', x, y, r + 4)
    setc(m.color)
    love.graphics.circle('fill', x, y, r * 0.55)
    love.graphics.setLineWidth(r * 0.18)
    setc(WHITE)
    love.graphics.line(x + math.cos(a) * r * 0.3, y + math.sin(a) * r * 0.3, x + math.cos(a) * r * 0.95,
        y + math.sin(a) * r * 0.95)
    love.graphics.setLineWidth(1)
end

local function drawJack(m, j)
    local x, y = jackPos(m, j)
    setc(TYPES[j.type])
    love.graphics.circle('fill', x, y, JACK_R + 10)
    setc(INK)
    love.graphics.circle('fill', x, y, JACK_R)
    setc({ 0.55, 0.55, 0.58 })
    love.graphics.circle('fill', x, y, JACK_R * 0.6)
    setc(INK)
    love.graphics.circle('fill', x, y, JACK_R * 0.35)
    text(j.dir == 'out' and (j.name:gsub('%d', '') .. ' >') or ('> ' .. j.name), x, y + JACK_R + 34, 30)
end

local function drawModule(p, m)
    setc(INK)
    love.graphics.rectangle('fill', m.x - 4, m.y - 4, m.w + 8, m.h + 8, 12, 12)
    setc(PANEL)
    love.graphics.rectangle('fill', m.x, m.y, m.w, m.h, 10, 10)
    setc(m.color)
    love.graphics.rectangle('fill', m.x, m.y, m.w, 90, 10, 10)
    love.graphics.rectangle('fill', m.x, m.y + 60, m.w, 30)
    -- screws
    setc(INK, 0.5)
    for _, c in ipairs({ { 20, 20 }, { m.w - 20, 20 }, { 20, m.h - 20 }, { m.w - 20, m.h - 20 } }) do
        love.graphics.circle('fill', m.x + c[1], m.y + c[2], 8)
    end
    text(m.label, m.x + m.w / 2, m.y + 45, 46, WHITE)
    -- a light that blinks when it does something
    local l = lit(p, m.id)
    setc({ 0.3 + 0.7 * l, 0.15 + 0.6 * l, 0.1 })
    love.graphics.circle('fill', m.x + m.w - 40, m.y + 130, 14)
    for _, k in ipairs(m.knobs) do drawKnob(m, k) end
    for _, j in ipairs(m.jacks) do drawJack(m, j) end
    -- what the knobs mean
    if m.id == 'clock' then
        text(string.format('%d', math.floor(60 + knobOf(m, 'tempo') * 120)), m.x + m.w / 2, m.y + 330, 40)
    elseif m.id == 'seq' then
        local steps = 2 + math.floor(knobOf(m, 'steps') * 6 + 0.5)
        for i = 1, 8 do
            local on = (p.seqStep == i) and lit(p, 'seq', 0.25) > 0
            setc(i <= steps and (on and { 1, 0.85, 0.3 } or { 0.45, 0.40, 0.35 }) or { 0.75, 0.75, 0.72 })
            love.graphics.circle('fill', m.x + 80 + (i - 1) * 86, m.y + 160, 13)
        end
        text(steps .. ' steps', m.x + 230, m.y + 430, 34)
    elseif m.id == 'dice' then
        setc(WHITE)
        love.graphics.rectangle('fill', m.x + m.w / 2 - 34, m.y + 300, 68, 68, 12, 12)
        text(tostring(p.diceShown or 1), m.x + m.w / 2, m.y + 334, 46)
    elseif m.id == 'drum' then
        text('beat ' .. (math.floor(knobOf(m, 'pattern') * (#DRUMS - 1) + 0.5) + 1), m.x + m.w / 2, m.y + 330, 36)
    elseif m.id == 'lfo' then
        local v = lfoAt(p, love.timer.getTime())
        setc(m.color)
        love.graphics.circle('fill', m.x + m.w / 2 + v * 80, m.y + 340, 18)
    elseif m.id == 'voiceA' or m.id == 'voiceB' then
        local inst = INSTRUMENTS[math.floor(knobOf(m, 'instrument') * (#INSTRUMENTS - 1) + 0.5) + 1]
        text(inst, m.x + 130, m.y + 330, 34)
        local oct = math.floor(knobOf(m, 'octave') * 2 + 0.5) - 1
        text(({ 'low', 'mid', 'high' })[oct + 2], m.x + 310, m.y + 330, 34)
    elseif m.id == 'speaker' then
        local pulse = math.max(0, 1 - (love.timer.getTime() - (p.speakerAt or -9)) / 0.18)
        local cx, cy = m.x + 430, m.y + 240
        setc(INK)
        love.graphics.circle('fill', cx, cy, 140)
        setc({ 0.45, 0.45, 0.50 })
        love.graphics.circle('fill', cx, cy, 120 + pulse * 10)
        setc({ 0.25, 0.25, 0.28 })
        love.graphics.circle('fill', cx, cy, 55 + pulse * 14)
        text('volume', m.x + 540, m.y + 505, 28, WHITE)
    end
end

local function drawCable(c)
    local pts = {}
    for _, pt in ipairs(c.pts) do
        pts[#pts + 1], pts[#pts + 2] = pt[1], pt[2]
    end
    love.graphics.setLineJoin('bevel')
    love.graphics.setLineWidth(22)
    setc(INK)
    love.graphics.line(pts)
    love.graphics.setLineWidth(14)
    setc(c.color)
    love.graphics.line(pts)
    love.graphics.setLineWidth(1)
    -- the plugs
    for _, i in ipairs({ 1, SEGS + 1 }) do
        local pt = c.pts[i]
        setc(INK)
        love.graphics.circle('fill', pt[1], pt[2], 24)
        setc(c.color)
        love.graphics.circle('fill', pt[1], pt[2], 17)
    end
end

function s.draw()
    local p = state.euromod
    if not (p and p.version == TOY_VERSION) then return end
    for _, m in ipairs(p.mods) do drawModule(p, m) end
    for _, c in ipairs(p.cables) do drawCable(c) end
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local p = state.euromod
    if not (p and state.playMode and p.version == TOY_VERSION) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 330
    local rows = 3
    local ph = BH * rows + pad * (rows + 1) + 20
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - ph - 20
    s._panelRect = { x0, y0, w, ph }
    ui.panel(x0, y0, w, ph, '•• euromod ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, (w - 26) / 2, 'start patch (r)') then startPatch(p) end
        if ui.button(x + (w - 26) / 2 + 6, y, (w - 26) / 2, 'pull all (c)') then p.cables = {} end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'drag jack to jack, knobs up/down')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, ready() and string.format('%d cables', #p.cables) or 'no synth: silent')
    end)
end

-- From the bridge
function s.status()
    local p = em()
    local cs = {}
    for _, c in ipairs(p.cables) do
        local a, b = c.a or {}, c.b or {}
        cs[#cs + 1] = (a.mod or '?') .. '.' .. (a.jack or '?') .. '>' .. (b.mod or '?') .. '.' .. (b.jack or '?')
    end
    return { cables = table.concat(cs, ' '), tick = p.tick, step = p.seqStep, synth = ready() and true or false,
        music = music and music.enabled }
end

return s

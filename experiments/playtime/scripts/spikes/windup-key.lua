-- windup-key: a wind-up key and its spring, on any body (the windup spike: Mipos, a car, a top, a jack-in-the-box,
-- a music box). Loaded with love.filesystem.load('scripts/spikes/windup-key.lua')(), so it runs in the plain globals.
--
-- A key sticks out of a body at a spot, along a direction in the body's own frame. Turn it round (drag in circles
-- round the key; clockwise on the screen winds, the other way the ratchet slips): a click a notch, the spring
-- fills. Let go and it unwinds over time: each frame the key's `run(key, power, dt)` gets the spring's power 0..1
-- (more wound, more power), and `stop(key)` when it's empty. Wind past full: `overwind(key)` (a sproing).
--   key = windupKey.new{ body, x, y (the spot, body-local), out = { dx, dy } (body-local, the stem's way),
--         size (1: a loop ~70 wide), full (turns), unwind (turns a second), stem (length, at size 1),
--         notch (turns a click), run, stop, overwind, tense(key, fill) while wound and not let go,
--         onNotch(key, n) every click while winding (the jack-in-the-box's tune), keepWound (no unwinding: a
--         crank that only winds), colour }
--   windupKey.input(keys, store, canPress, mx, my, down)  a finger winding (store: a table kept on state)
--   windupKey.update(key, dt), windupKey.draw(key), windupKey.wind(key, radians), windupKey.release(key)
--   windupKey.play(name, volume, pitch): 'click', 'tick', 'sproing'; windupKey.note(midi, volume) a music-box note

local lib = {}

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

local makers = {}
local function ensureSounds()
    if sounds.pop then return end
    for name, make in pairs(makers) do
        if not sounds[name] then sounds[name] = make() end
    end
end
do
    makers.click = function() return makeSound(0.03, function(t, ph) -- a ratchet: a short noisy knock
        return (love.math.random() * 2 - 1) * math.exp(-t * 260) * 0.7
            + math.sin(t * 2 * math.pi * 1900) * math.exp(-t * 180) * 0.4, ph
    end) end
    makers.tick = function() return makeSound(0.02, function(t, ph) -- the clockwork running: higher, quieter
        return (love.math.random() * 2 - 1) * math.exp(-t * 400) * 0.35
            + math.sin(t * 2 * math.pi * 3200) * math.exp(-t * 300) * 0.25, ph
    end) end
    makers.sproing = function() return makeSound(0.7, function(t, ph, rate) -- a falling, wobbling twang
        local f = 520 * math.exp(-t * 1.6) * (1 + 0.08 * math.sin(t * 2 * math.pi * 18))
        ph = ph + f / rate
        local env = math.min(1, t / 0.004) * math.exp(-t * 4.5)
        return (math.sin(ph * 2 * math.pi) + 0.3 * math.sin(ph * 4 * math.pi)) * env * 0.45, ph
    end) end
    makers.pop = function() return makeSound(0.25, function(t, ph, rate) -- a cork pop and a boing up
        local f = 180 + 900 * t
        ph = ph + f / rate
        return ((love.math.random() * 2 - 1) * math.exp(-t * 120) * 0.8
            + math.sin(ph * 2 * math.pi) * math.exp(-t * 9) * 0.5), ph
    end) end
end

-- (no sound device, as in ./playtime.sh thumbs: love.audio is nil, nothing plays)
function lib.play(name, volume, pitch)
    if not love.audio then return end
    ensureSounds()
    local src = sounds[name]:clone()
    src:setVolume(volume or 1)
    src:setPitch(pitch or 1)
    src:play()
end

-- a music-box tine: a sine with a quick bright attack and a long ring (made once per note)
local notes = {}
function lib.note(midi, volume)
    if not love.audio then return end
    if not notes[midi] then
        local f = 440 * 2 ^ ((midi - 69) / 12)
        notes[midi] = makeSound(1.0, function(t, ph)
            local env = math.min(1, t / 0.002)
            return (math.sin(2 * math.pi * f * t) * math.exp(-t * 3)
                + 0.35 * math.sin(2 * math.pi * f * 2 * t) * math.exp(-t * 7)
                + 0.12 * math.sin(2 * math.pi * f * 4.2 * t) * math.exp(-t * 16)) * env * 0.4, ph
        end)
    end
    local src = notes[midi]:clone()
    src:setVolume(volume or 1)
    src:play()
end

-- make the sounds and these notes now (at a scene's load, not in the middle of play or a bridge eval)
function lib.preload(midis)
    if not love.audio then return end
    ensureSounds()
    for _, m in ipairs(midis or {}) do
        if not notes[m] then
            local src = lib.note
            src(m, 0)
        end
    end
end

---------------------------------------------------------------- a key

function lib.new(def)
    local key = def
    key.size = key.size or 1
    key.full = key.full or 6
    key.unwind = key.unwind or 0.75
    key.notchTurns = key.notch or 1 / 8
    key.stem = key.stem or 150
    key.out = key.out or { -1, 0 }
    key.spring, key.notchAt, key.running, key.turn = 0, 0, false, 0
    return key
end

local function alive(key) return key.body and not key.body:isDestroyed() end

-- the key's middle and where its stem goes in, in the world
function lib.point(key)
    local b = key.body
    local bx, by = b:getWorldPoint(key.x, key.y)
    local ox, oy = key.out[1], key.out[2]
    local len = math.sqrt(ox * ox + oy * oy)
    ox, oy = ox / len, oy / len
    local stem = key.stem * key.size
    local kx, ky = b:getWorldPoint(key.x + ox * stem, key.y + oy * stem)
    return kx, ky, bx, by
end

function lib.fill(key) return math.min(1, key.spring / key.full) end

-- turn the key by `delta` radians (clockwise on the screen winds; the other way the ratchet slips)
function lib.wind(key, delta)
    if delta <= 0 or not alive(key) then return end
    key.spring = key.spring + delta / (2 * math.pi)
    key.turn = key.turn + delta
    while key.spring >= (key.notchAt + 1) * key.notchTurns do
        key.notchAt = key.notchAt + 1
        lib.play('click', 0.5, 0.9 + lib.fill(key) * 0.5)
        if key.onNotch then key.onNotch(key, key.notchAt) end
    end
    if key.spring > key.full * 1.12 then
        key.spring = key.full
        key.notchAt = math.floor(key.spring / key.notchTurns)
        lib.play('sproing', 0.9, 0.9 + love.math.random() * 0.2)
        if key.overwind then key.overwind(key) end
        key.overwound = true
    end
end

function lib.release(key)
    if key.keepWound then return end
    if key.spring > 0.15 then
        key.running = true
        key.wound0 = key.spring
    end
end

function lib.update(key, dt)
    if not alive(key) then return end
    if not key.running then
        if key.spring > 0 and key.tense and not key.keepWound then key.tense(key, lib.fill(key)) end
        return
    end
    local was = key.spring
    key.spring = math.max(0, key.spring - key.unwind * dt)
    key.turn = key.turn - (was - key.spring) * 2 * math.pi -- the key turns back as it unwinds
    local n = math.floor(key.spring / key.notchTurns)
    if n < math.floor(was / key.notchTurns) and not key.quiet then lib.play('tick', 0.3, 1 + lib.fill(key) * 0.4) end
    key.notchAt = n
    if key.spring <= 0 then
        key.running, key.overwound = false, nil
        if key.stop then key.stop(key) end
        return
    end
    if key.run then key.run(key, lib.fill(key), dt) end
end

---------------------------------------------------------------- winding with a finger

local function wrap(a) return (a + math.pi) % (2 * math.pi) - math.pi end

-- keys: a list; store: a table on state (what's being wound); canPress(): false over a panel
function lib.input(keys, store, canPress, mx, my, down, radius)
    radius = radius or 300
    if down and not store.wasDown and canPress() then
        local best, bestD
        for _, key in ipairs(keys) do
            if alive(key) then
                local kx, ky = lib.point(key)
                local d = math.sqrt((mx - kx) ^ 2 + (my - ky) ^ 2)
                if d < radius * key.size / 2.2 and (not bestD or d < bestD) then best, bestD = key, d end
            end
        end
        if best then
            local kx, ky = lib.point(best)
            store.winding = { key = best, last = math.atan2(my - ky, mx - kx) }
            best.running = false -- a hand on the key holds the spring
        end
    end
    local w = store.winding
    if w and down and alive(w.key) then
        local kx, ky = lib.point(w.key)
        local a = math.atan2(my - ky, mx - kx)
        lib.wind(w.key, wrap(a - w.last))
        w.last = a
    elseif w and not down then
        lib.release(w.key)
        store.winding = nil
    end
    store.wasDown = down
    return store.winding ~= nil
end

function lib.beingWound(store, key) return store.winding ~= nil and store.winding.key == key end

---------------------------------------------------------------- drawing

-- The stem, then two loops across it spinning round it as the spring turns: from the side a bow tie that
-- narrows to a line and flips over (a fake 3D turn). A crank (def.crank) is drawn as a handle instead.
function lib.draw(key)
    if not alive(key) then return end
    local kx, ky, bx, by = lib.point(key)
    local s = key.size
    love.graphics.setLineWidth(24 * s)
    love.graphics.setColor(0.55, 0.5, 0.42)
    love.graphics.line(bx, by, kx, ky)
    local ang = key.body:getAngle() + math.atan2(key.out[2], key.out[1])
    local wide = math.cos(key.turn)
    love.graphics.push()
    love.graphics.translate(kx, ky)
    love.graphics.rotate(ang)
    love.graphics.scale(s)
    local c = key.colour or { 0.9, 0.76, 0.3 }
    if key.crank then -- a crank handle: an arm round the axle with a knob, turning in the screen's plane
        love.graphics.rotate(key.turn - ang)
        love.graphics.setColor(0.45, 0.33, 0.12)
        love.graphics.setLineWidth(18)
        love.graphics.line(0, 0, 0, -80)
        love.graphics.setColor(c)
        love.graphics.circle('fill', 0, -80, 22)
    else
        for _, side in ipairs({ -1, 1 }) do
            local cy = side * 62 * wide
            local ry = math.max(6, 50 * math.abs(wide))
            local lit = side * wide > 0 and 1 or 0.78
            love.graphics.setColor(c[1] * lit, c[2] * lit, c[3] * lit)
            love.graphics.ellipse('fill', 0, cy, 30, ry)
            love.graphics.setColor(0.45, 0.33, 0.12)
            love.graphics.setLineWidth(6)
            love.graphics.ellipse('line', 0, cy, 30, ry)
        end
    end
    love.graphics.setColor(c)
    love.graphics.circle('fill', 0, 0, 24)
    love.graphics.setColor(0.45, 0.33, 0.12)
    love.graphics.setLineWidth(6)
    love.graphics.circle('line', 0, 0, 24)
    love.graphics.pop()
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return lib

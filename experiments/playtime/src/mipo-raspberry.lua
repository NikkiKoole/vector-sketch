-- mipo-raspberry.lua: a Mipo blows a raspberry. The tongue slides out between pressed lips, lips
-- and tongue buzz, a pbbbbt plays, and the tongue goes back in (spike, 2026-11-04).
-- The face thing carries it while it runs: mouthShapeVec (the lips, like the voice's mouth flap),
-- tongueOut 0..1 and tongueBuzz 0..1, which src/render/mouth.lua's 'mouth-tongue' reads.
-- Nothing is saved: the tongue only exists while it's out.
-- Placeholders, both to be replaced: the tongue is drawn in code (a picture later, THINGS-TO-DRAW),
-- the sound is made in code (a recorded raspberry later, like the squeak samples).
local mipoVoice = require('src.mipo-voice')
local state = require('src.state')

local lib = {}

lib.outTime = 0.16     -- seconds for the tongue to come out (and the lips to press)
lib.inTime = 0.2       -- seconds to go back in
lib.lipBuzz = 6        -- how far the lips shake (mouth-shape units; a mouth is ~150 wide)
lib.wide = 1.15        -- the pressed mouth a bit wider than it rests
lib.press = 0.9        -- 0 = the resting mouth, 1 = the lips fully pressed together
lib.gap = 4            -- half the lips' gap in the middle, where the tongue comes through
lib.soundLength = 0.9  -- seconds of buzz at pitch 1 (a higher voice blows a shorter one)

-- [mipoId] = { thing, start, duration, from, target, restore }. On state so a hot reload
-- doesn't leave a tongue hanging out.
state.mipoRaspberries = state.mipoRaspberries or {}
local running = state.mipoRaspberries

local function now() return love.timer.getTime() end

-- The pbbbbt: the lips popping open ~90 times a second, unevenly (each period its own length and
-- strength), noise and a little buzz in each pop, darkened by a lowpass. Made once.
local soundData
local function makeSound()
    local rate = 22050
    local n = math.floor(rate * lib.soundLength)
    local data = love.sound.newSoundData(n, rate, 16, 1)
    local rng = love.math.newRandomGenerator(7)
    local phase, f, amp = 0, 90, 1
    local low, peak = 0, 0
    local out = {}
    for i = 0, n - 1 do
        local t = i / rate
        phase = phase + f / rate
        if phase >= 1 then
            phase = phase - 1
            f = 80 * (1 + 0.35 * t) * (0.8 + rng:random() * 0.4) -- rises a little as it goes
            amp = 0.6 + rng:random() * 0.4
        end
        local open = phase < 0.45 and math.sin(math.pi * phase / 0.45) ^ 2 or 0
        local x = open * amp * ((rng:random() * 2 - 1) * 0.8 + (1 - 2 * phase) * 0.6)
        low = low + (x - low) * 0.25 -- one-pole lowpass, ~1.4 kHz
        local env = math.min(1, t / 0.03) * math.min(1, (lib.soundLength - t) / 0.15)
        local s = low * env + (rng:random() * 2 - 1) * 0.03 * env -- a breath of air on top
        out[i] = s
        peak = math.max(peak, math.abs(s))
    end
    for i = 0, n - 1 do data:setSample(i, out[i] / peak * 0.9) end
    return data
end

local function playSound(pitch)
    if not (mipoVoice.enabled and love.audio) then return end
    soundData = soundData or makeSound()
    local source = love.audio.newSource(soundData)
    local fx = state.synth and state.synth.fxVolume or 1
    source:setVolume(mipoVoice.volume * mipoVoice.masterVolume * fx)
    source:setPitch(pitch)
    source:play()
end

-- Blow a raspberry. Returns false when the Mipo has no mouth.
function lib.blow(instance)
    local thing, lip = mipoVoice.findMouth(instance)
    if not thing then return false end
    local old = running[instance.id]
    local restore
    if old then
        restore = old.restore
    else
        local flapRestore, hadFlap = mipoVoice.cancelFlap(instance)
        restore = hadFlap and flapRestore or thing.mouthShapeVec
    end
    local from = restore or mipoVoice.restingShape(thing, lip)
    -- the lips pressed together along a line through the corners, a small gap in the middle for
    -- the tongue (the M_B_P shape stays open at the sides once normalized: no good)
    local cy = (from[2] + from[10]) / 2
    local pressedY = { cy, cy - lib.gap * 0.5, cy - lib.gap, cy - lib.gap * 0.5, -- upper p1-p4
        cy, cy + lib.gap * 0.5, cy + lib.gap, cy + lib.gap * 0.5 }             -- lower p5-p8
    local target = {}
    for k = 1, 8 do
        target[2 * k - 1] = from[2 * k - 1] * lib.wide
        target[2 * k] = from[2 * k] + (pressedY[k] - from[2 * k]) * lib.press
    end
    local pitch = mipoVoice.voiceFor(instance).pitch
    running[instance.id] = {
        thing = thing, start = now(), from = from, target = target, restore = restore,
        duration = lib.outTime + lib.soundLength / pitch + lib.inTime,
    }
    -- the buzz starts as the tongue is out
    running[instance.id].soundAt = now() + lib.outTime * 0.7
    running[instance.id].pitch = pitch
    return true
end

function lib.isBlowing(instance)
    return instance and running[instance.id] ~= nil
end

local function smooth(x) return x * x * (3 - 2 * x) end

-- After mipoVoice.update (whose mouth flaps would otherwise win).
function lib.update()
    local t = now()
    for id, r in pairs(running) do
        local age = t - r.start
        if age >= r.duration then
            r.thing.mouthShapeVec = r.restore
            r.thing.tongueOut, r.thing.tongueBuzz = nil, nil
            running[id] = nil
        else
            if r.soundAt and t >= r.soundAt then
                playSound(r.pitch)
                r.soundAt = nil
            end
            local out = math.min(1, age / lib.outTime, (r.duration - age) / lib.inTime)
            out = smooth(math.max(0, out))
            local buzzing = age > lib.outTime * 0.7 and age < r.duration - lib.inTime
            local buzz = buzzing and (0.5 + 0.5 * math.random()) or 0
            local sign = (math.floor(age * 60) % 2 == 0) and 1 or -1 -- a shake each frame
            local vec = {}
            for i = 1, 16 do vec[i] = r.from[i] + (r.target[i] - r.from[i]) * out end
            -- the lips' middles (upper p2-p4, lower p6-p8) shake against each other
            local shake = lib.lipBuzz * buzz * sign
            vec[4], vec[6], vec[8] = vec[4] - shake * 0.6, vec[6] - shake, vec[8] - shake * 0.6
            vec[12], vec[14], vec[16] = vec[12] + shake * 0.6, vec[14] + shake, vec[16] + shake * 0.6
            r.thing.mouthShapeVec = vec
            r.thing.tongueOut = out
            r.thing.tongueBuzz = buzz * sign
        end
    end
end

function lib.reset()
    for id, r in pairs(running) do
        r.thing.mouthShapeVec = r.restore
        r.thing.tongueOut, r.thing.tongueBuzz = nil, nil
        running[id] = nil
    end
end

return lib

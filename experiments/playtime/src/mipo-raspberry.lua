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

lib.closeTime = 0.3    -- seconds for the mouth to close, before the tongue comes
lib.outTime = 0.35     -- seconds for the tongue to slide out
lib.wait = 0.2         -- seconds with the tongue out before the buzz
lib.inTime = 0.45      -- seconds to go back in
lib.openTime = 0.3     -- seconds for the mouth to open again after
lib.shakeRate = 10     -- lip/tongue wobbles a second (each frame was far too fast)
lib.lipBuzz = 6        -- how far the lips shake (mouth-shape units; a mouth is ~150 wide)
lib.wide = 1.15        -- the pressed mouth a bit wider than it rests
lib.press = 1          -- 0 = the resting mouth, 1 = the lips fully pressed together
lib.gap = 10           -- half the lips' gap in the middle, where the tongue comes through
lib.closedGap = 1.5    -- closed, a hair apart: touching lips leave the mouth's hole no area
lib.soundLength = 1.3  -- seconds of buzz at pitch 1 (a higher voice blows a shorter one)

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
-- In order: the mouth closes, the tongue slides out from under the teeth (the lips part a little
-- in the middle to let it through), a beat, the buzz, the tongue back in, the mouth opens again.
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
    local pitch = mipoVoice.voiceFor(instance).pitch
    local buzzAt = lib.closeTime + lib.outTime + lib.wait
    running[instance.id] = {
        thing = thing, start = now(), from = from, restore = restore, pitch = pitch,
        cy = (from[2] + from[10]) / 2, -- the line through the corners the lips press onto
        buzzAt = buzzAt,
        soundAt = now() + buzzAt,
        duration = buzzAt + lib.soundLength / pitch + lib.inTime + lib.openTime,
    }
    return true
end

function lib.isBlowing(instance)
    return instance and running[instance.id] ~= nil
end

local function smooth(x) return x * x * (3 - 2 * x) end
local function ramp(x) return smooth(math.max(0, math.min(1, x))) end

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
            local left = r.duration - age -- seconds to go
            -- the mouth closes first and opens last; the tongue is out in between
            local press = math.min(ramp(age / lib.closeTime), ramp(left / lib.openTime)) * lib.press
            local out = math.min(ramp((age - lib.closeTime) / lib.outTime),
                ramp((left - lib.openTime) / lib.inTime))
            local buzzEnd = r.duration - lib.openTime - lib.inTime
            local buzzing = age > r.buzzAt and age < buzzEnd
            -- eased in and out over the buzz, a little uneven
            local buzz = buzzing and math.min(1, (age - r.buzzAt) / 0.1, (buzzEnd - age) / 0.15)
                * (0.75 + 0.25 * math.random()) or 0
            local sign = math.sin(2 * math.pi * lib.shakeRate * (age - r.buzzAt))
            -- pressed onto the corners' line, parted in the middle as far as the tongue is out
            local gap, cy = lib.closedGap + (lib.gap - lib.closedGap) * out, r.cy
            local pressedY = { cy, cy - gap * 0.5, cy - gap, cy - gap * 0.5, -- upper p1-p4
                cy, cy + gap * 0.5, cy + gap, cy + gap * 0.5 }             -- lower p5-p8
            local wide = 1 + (lib.wide - 1) * press / lib.press
            local vec = {}
            for k = 1, 8 do
                vec[2 * k - 1] = r.from[2 * k - 1] * wide
                vec[2 * k] = r.from[2 * k] + (pressedY[k] - r.from[2 * k]) * press
            end
            -- the lips' middles (upper p2-p4, lower p6-p8) shake against each other
            local shake = lib.lipBuzz * buzz * sign
            vec[4], vec[6], vec[8] = vec[4] - shake * 0.6, vec[6] - shake, vec[8] - shake * 0.6
            vec[12], vec[14], vec[16] = vec[12] + shake * 0.6, vec[14] + shake, vec[16] + shake * 0.6
            r.thing.mouthShapeVec = vec
            r.thing.tongueOut = out > 0 and out or nil
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

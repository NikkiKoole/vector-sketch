-- mipo-voice.lua
-- Squeaks for Mipos: one syllable or fx sample per reaction, pitched per Mipo.
-- Samples come from the mipomi-lang repo (~/Projects/love/mipomi-lang), copied
-- into assets/voices/{nikki,theo,herman,fx}. Full mipomi speech (say + lipsync)
-- is a later step, see docs/DOLL-PLAY.md "Voice".
-- Also: mouth flap while a squeak plays, and rubber plonks on impacts
-- (both after puppet-maker2's mouthSay() and postSolve plonks).
local mipoRegistry = require('src.mipo-registry')
local mouthShapes = require('src.mouth-shapes')

local lib = {}

lib.enabled = true
lib.volume = 0.8
lib.cooldown = 0.15      -- seconds between squeaks of the same Mipo
lib.impactCooldown = 0.5 -- seconds between impact 'oof's of the same Mipo
lib.impactSpeed = 1200   -- velocity change (world units/s) for an oof; measured: small hop ~550, 800-unit drop ~2500
lib.plonkSpeed = 400     -- velocity change for a rubber plonk (lower than oof: small hops plonk too)
lib.plonkHardSpeed = 4000 -- at and above this a plonk is lowest and loudest
lib.plonkVolume = 0.8
lib.plonkPairCooldown = 0.5 -- the same two bodies plonk at most this often
lib.mouthFlap = true

lib.voiceSets = { 'nikki', 'theo', 'herman' }

-- Each emotion: which samples to pick from, and a pitch multiplier on top of the Mipo's own pitch.
-- `syllables` filters the voice set by vowel; `fx` picks from assets/voices/fx.
lib.emotions = {
    poke      = { syllables = 'aio', pitch = 1.0 },
    -- same pool as puppet-maker2's growl() on grab (main.lua `hum` table)
    pickup    = { fx = { 'humup1', 'humup2', 'humup3', 'blah1', 'blah2', 'blah3',
                         'huh', 'huh2', 'tsk', 'tsk2' }, pitch = 1.0 },
    oof       = { fx = { 'humdown1', 'humdown2', 'humdown3', 'humdown4' }, pitch = 0.9 },
    happy     = { syllables = 'i', pitch = 1.15 },
    curious   = { fx = { 'humup1', 'humup2', 'humup3', 'humup4' }, pitch = 1.05 },
    annoyed   = { fx = { 'tsk', 'tsk2' }, pitch = 1.0 },
    blah      = { fx = { 'blah1', 'blah2', 'blah3' }, pitch = 1.0 },
}

local sampleCache = {} -- [setName] = { keys = {...}, sources = { [key] = Source } }
local lastSqueak = {}  -- [mipoId] = time
local lastImpact = {}  -- [mipoId] = time
local playing = {}     -- [mipoId] = Source; a Mipo says one thing at a time
local flaps = {}       -- [mipoId] = { thing, start, duration, from, target, amount, wide, restore }
local plonkPairs = {}  -- [pairKey] = time
local plonkSources = nil

local function now()
    return love and love.timer and love.timer.getTime() or os.clock()
end

local function loadSet(setName)
    if sampleCache[setName] then return sampleCache[setName] end
    local set = { keys = {}, sources = {} }
    if love and love.audio and love.filesystem then
        local dir = 'assets/voices/' .. setName
        for _, file in ipairs(love.filesystem.getDirectoryItems(dir)) do
            local key = file:match('^(.+)%.ogg$')
            if key then
                set.sources[key] = love.audio.newSource(dir .. '/' .. file, 'static')
                set.keys[#set.keys + 1] = key
            end
        end
        table.sort(set.keys)
    end
    sampleCache[setName] = set
    return set
end

local function hashString(s)
    local h = 0
    for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
    return h
end

-- The voice of a Mipo: dna.voice when set, otherwise derived from its id so the
-- same Mipo always sounds the same.
function lib.voiceFor(instance)
    local dnaVoice = instance and instance.dna and instance.dna.voice
    if dnaVoice and dnaVoice.set then
        return { set = dnaVoice.set, pitch = dnaVoice.pitch or 1 }
    end
    local h = hashString(tostring(instance and instance.id or ''))
    return {
        set = lib.voiceSets[(h % #lib.voiceSets) + 1],
        pitch = 0.85 + (math.floor(h / 7) % 41) / 100, -- 0.85 .. 1.25
    }
end

-- Candidate sample keys for an emotion, as { set, key } pairs.
function lib.candidates(voiceSet, emotionName)
    local emotion = lib.emotions[emotionName] or lib.emotions.poke
    local result = {}
    if emotion.fx then
        local fxSet = loadSet('fx')
        for _, key in ipairs(emotion.fx) do
            -- headless (specs): nothing loaded, so keep the listed names
            if fxSet.sources[key] or not fxSet.keys[1] then
                result[#result + 1] = { set = 'fx', key = key }
            end
        end
    end
    if emotion.syllables then
        local set = loadSet(voiceSet)
        for _, key in ipairs(set.keys) do
            local vowel = key:sub(2, 2)
            if emotion.syllables:find(vowel, 1, true) then
                result[#result + 1] = { set = voiceSet, key = key }
            end
        end
    end
    return result
end

local function play(setName, key, pitch)
    local source = loadSet(setName).sources[key]
    if not source then return nil end
    local clone = source:clone()
    clone:setPitch(pitch)
    clone:setVolume(lib.volume)
    clone:play()
    return clone
end

-- Play one squeak for a Mipo instance. Returns the playing Source, or nil when
-- muted, rate-limited or no sample matched.
function lib.squeak(instance, emotionName)
    if not lib.enabled or not instance then return nil end
    if not (love and love.audio) then return nil end
    local t = now()
    if lastSqueak[instance.id] and t - lastSqueak[instance.id] < lib.cooldown then return nil end

    local voice = lib.voiceFor(instance)
    local options = lib.candidates(voice.set, emotionName)
    if #options == 0 then return nil end
    local pick = options[love.math.random(#options)]
    local emotion = lib.emotions[emotionName] or lib.emotions.poke
    local jitter = 0.95 + love.math.random() * 0.1

    lastSqueak[instance.id] = t
    if playing[instance.id] then playing[instance.id]:stop() end
    local pitch = voice.pitch * emotion.pitch * jitter
    playing[instance.id] = play(pick.set, pick.key, pitch)
    if playing[instance.id] then
        lib.flapMouth(instance, playing[instance.id]:getDuration() / pitch)
    end
    return playing[instance.id]
end

-- The face-owner thing of a Mipo (head, or torso1 for potato heads) and its upper lip decal.
local function findMouth(instance)
    for _, partName in ipairs({ 'head', 'torso1' }) do
        local part = instance.parts and instance.parts[partName]
        local body = part and part.body
        if body and not body:isDestroyed() then
            for _, fixture in ipairs(body:getFixtures()) do
                local ud = fixture:getUserData()
                local extra = ud and ud.extra
                if extra and extra.mouthCurve == 'upper' and extra.curvePoints and extra.mouthScaleX then
                    return part, extra
                end
            end
        end
    end
    return nil, nil
end

local function shapeByName(name)
    for _, shape in ipairs(mouthShapes.normalized) do
        if shape.name == name then return shape.points end
    end
    return nil
end

local openShapes = { 'O_U_agh', 'open_tween', 'A_I' }

-- Open the mouth for `duration` seconds, then close it again:
-- rise over the first third, hold, fall over the last third (puppet-maker2 mouthSay).
function lib.flapMouth(instance, duration)
    if not lib.mouthFlap or not instance then return end
    local thing, lip = findMouth(instance)
    if not thing then return end
    local existing = flaps[instance.id]
    local restore = existing and existing.restore or thing.mouthShapeVec
    local from = restore
    if not from then
        -- the DNA mouth, recovered from the lip decal's scaled curve points
        from = {}
        local cp = lip.curvePoints
        for i = 1, 16, 2 do
            from[i] = (cp[i] - lip.mouthX) / lip.mouthScaleX
            from[i + 1] = (cp[i + 1] - lip.mouthY) / lip.mouthScaleY
        end
    end
    local target = shapeByName(openShapes[love.math.random(#openShapes)])
    if not target then return end
    flaps[instance.id] = {
        thing = thing,
        start = now(),
        duration = math.max(duration, 0.15),
        from = from,
        target = target,
        amount = 0.7 + love.math.random() * 0.3,
        wide = 0.8 + love.math.random() * 0.5,
        restore = restore,
    }
end

-- 0 → 1 → 0 over the duration, eased out on the way up and down.
function lib.flapEnvelope(t)
    if t <= 0 or t >= 1 then return 0 end
    local function outQuad(x) return 1 - (1 - x) * (1 - x) end
    if t < 1 / 3 then return outQuad(t * 3) end
    if t < 2 / 3 then return 1 end
    return 1 - outQuad((t - 2 / 3) * 3)
end

local function tickFlaps()
    local t = now()
    for id, flap in pairs(flaps) do
        local progress = (t - flap.start) / flap.duration
        if progress >= 1 then
            flap.thing.mouthShapeVec = flap.restore
            flaps[id] = nil
        else
            local e = lib.flapEnvelope(progress) * flap.amount
            local wide = 1 + (flap.wide - 1) * e
            local vec = {}
            for i = 1, 16 do
                vec[i] = flap.from[i] + (flap.target[i] - flap.from[i]) * e
            end
            for i = 1, 16, 2 do vec[i] = vec[i] * wide end
            flap.thing.mouthShapeVec = vec
        end
    end
end

function lib.update(_dt)
    tickFlaps()
    local t = now()
    for key, at in pairs(plonkPairs) do
        if t - at > lib.plonkPairCooldown then plonkPairs[key] = nil end
    end
end

function lib.squeakBody(body, emotionName)
    local instance = mipoRegistry.getFromBody(body)
    if instance then return lib.squeak(instance, emotionName) end
    return nil
end

local function mapInto(x, inMin, inMax, outMin, outMax)
    local t = (x - inMin) / (inMax - inMin)
    t = math.max(0, math.min(1, t))
    return outMin + (outMax - outMin) * t
end

local function plonk(body1, body2, speed)
    if not (love and love.audio) then return end
    local a, b = tostring(body1), tostring(body2)
    local key = a < b and (a .. b) or (b .. a)
    if plonkPairs[key] then return end
    plonkPairs[key] = now()
    if not plonkSources then
        plonkSources = {}
        for i = 1, 3 do
            local path = 'assets/sounds/rubber-plonk' .. i .. '.ogg'
            if love.filesystem.getInfo(path) then
                plonkSources[#plonkSources + 1] = love.audio.newSource(path, 'static')
            end
        end
    end
    if #plonkSources == 0 then return end
    local clone = plonkSources[love.math.random(#plonkSources)]:clone()
    -- harder hit = lower and louder (puppet-maker2: pitch 2 → 1, volume .2 → 1)
    clone:setPitch(mapInto(speed, lib.plonkSpeed, lib.plonkHardSpeed, 2, 1))
    clone:setVolume(mapInto(speed, lib.plonkSpeed, lib.plonkHardSpeed, 0.2, 1) * lib.plonkVolume)
    clone:play()
end

-- Called from postSolve. A Mipo part that changes velocity plonks; a hard
-- change also makes the Mipo say 'oof'. Collisions between parts of the same
-- Mipo are ignored.
function lib.onImpact(fix1, fix2, normalImpulse)
    if not lib.enabled or not normalImpulse then return end
    local body1, body2 = fix1:getBody(), fix2:getBody()
    local mipo1 = mipoRegistry.getFromBody(body1)
    local mipo2 = mipoRegistry.getFromBody(body2)
    if mipo1 and mipo1 == mipo2 then return end
    for _, pair in ipairs({ { mipo1, body1 }, { mipo2, body2 } }) do
        local instance, body = pair[1], pair[2]
        if instance then
            local mass = body:getMass()
            local speed = mass > 0 and normalImpulse / mass or 0
            if speed > lib.plonkSpeed then
                plonk(body1, body2, speed)
            end
            if speed > lib.impactSpeed then
                local t = now()
                if not lastImpact[instance.id] or t - lastImpact[instance.id] > lib.impactCooldown then
                    lastImpact[instance.id] = t
                    lib.squeak(instance, 'oof')
                end
            end
        end
    end
end

function lib.reset()
    lastSqueak = {}
    lastImpact = {}
    playing = {}
    for _, flap in pairs(flaps) do flap.thing.mouthShapeVec = flap.restore end
    flaps = {}
    plonkPairs = {}
end

return lib

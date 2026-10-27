-- mipo-voice.lua
-- Squeaks for Mipos: one syllable or fx sample per reaction, pitched per Mipo.
-- Samples come from the mipomi-lang repo (~/Projects/love/mipomi-lang), copied
-- into assets/voices/{nikki,theo,herman,fx}. Full mipomi speech (say + lipsync)
-- is a later step, see docs/DOLL-PLAY.md "Voice".
-- Also: mouth flap while a squeak plays, rubber plonks when Mipos hit things and
-- winegum kisses when SQUISHY-behavior bodies hit things (all after puppet-maker2's
-- mouthSay() and postSolve sounds).
local mipoRegistry = require('src.mipo-registry')
local mouthShapes = require('src.mouth-shapes')

local lib = {}

lib.enabled = true
lib.masterVolume = 0.5 -- scales every Mipo sound (voices, plonks, kisses)
lib.volume = 0.8       -- voices, before masterVolume
lib.cooldown = 0.15      -- seconds between squeaks of the same Mipo
lib.impactCooldown = 0.5 -- seconds between impact 'oof's of the same Mipo
lib.impactSpeed = 1200   -- velocity change (world units/s) for an oof; measured: small hop ~550, 800-unit drop ~2500
-- Impact sounds (files relative to assets/sounds/, see its README for sources).
-- Speeds are velocity changes (world units/s); a hit at `soft`
-- plays at pitch[1]/volume[1], at `hard` and above at pitch[2]/volume[2].
-- `synth` lists src/synth.lua patches to use instead of the files when synthImpacts is on
-- (`transpose` semitones on lib.plonkNotes, `durMs` how long the note is held, default 400;
-- `perBody`: the sounding body keeps one patch and its size picks the octave, see smallSize/bigSize).
lib.impactSounds = {
    -- rubber plonks mixed with Korg Minipops toms/wood block (short wooden 'toks')
    plonk = { files = { 'rubber-plonk1', 'rubber-plonk2', 'rubber-plonk3',
                        'korg-minipops/tom1', 'korg-minipops/tom2', 'korg-minipops/wood1' },
              soft = 400, hard = 4000, pitch = { 2, 1 }, volume = { 0.2, 0.8 },
              synth = { 'tom', 'wood' } },
    -- a ball bouncing off anything: the upright bass, two octaves down; rubber plonks without the synth
    ball  = { files = { 'rubber-plonk1', 'rubber-plonk2', 'rubber-plonk3' },
              soft = 300, hard = 3000, pitch = { 2, 1 }, volume = { 0.2, 0.8 },
              synth = { 'bass' }, transpose = -24, durMs = 150 },
    -- a box (label 'box') hitting anything: a drum skin. Each box keeps one drum (picked from
    -- its id); small boxes play an octave up, big ones an octave down.
    box   = { files = { 'korg-minipops/tom1', 'korg-minipops/tom2' },
              soft = 300, hard = 3000, pitch = { 2, 1 }, volume = { 0.2, 0.8 },
              synth = { 'conga', 'djembe', 'tabla' }, perBody = true, smallSize = 140, bigSize = 240 },
    kiss  = { files = { 'winegum-kiss1', 'winegum-kiss2', 'winegum-kiss3', 'winegum-kiss4', 'winegum-kiss5' },
              soft = 150, hard = 1500, pitch = { 2, 0.25 }, volume = { 0.2, 1 } },
}
lib.impactPairCooldown = 0.5 -- the same two bodies make the same impact sound at most this often
-- A contact only sounds when its parts approach faster than this. Measured: real
-- drops hit at 400-1100, tangled/jittering limbs re-touch at ~100 (90% under 360).
lib.minApproachSpeed = 350
lib.plonkMipoCooldown = 0.25 -- one Mipo plonks at most this often (catches jitter spikes)
lib.mouthFlap = true

-- Impacts from dreamengine's synth (src/synth.lua: modeled instruments placed in the
-- world) instead of the samples. Falls back to the samples when the library isn't built.
lib.synthImpacts = true
lib.plonkNotes = { 57, 60, 62, 64, 67, 69, 72, 74 } -- pentatonic: a pile of impacts sounds like a tune

-- Required lazily: src/synth.lua needs LuaJIT's ffi, which the pure busted specs don't have.
local function getSynth()
    if not lib.synthImpacts then return nil end
    local synth = require('src.synth')
    return synth.start() and synth or nil
end

-- Optional hook, called with (instance, speed) for every hit above impactSpeed
-- (main.lua wires it to mipoActions.onHardImpact for the daze).
lib.onHardImpact = nil

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
local impactPairs = {} -- [kind .. pairKey] = time
local freshContacts = {} -- [fixturePairKey] = approach speed, between beginContact and the first postSolve
local lastPlonk = {}     -- [mipoId] = time
local impactSources = {} -- [kind] = { Source, ... }

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
    clone:setVolume(lib.volume * lib.masterVolume)
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

function lib.update(dt)
    tickFlaps()
    local synth = getSynth()
    if synth then
        synth.update(dt, require('src.camera').getInstance())
        require('src.slide-sound').update(synth, now())
    end
    local t = now()
    for key, at in pairs(impactPairs) do
        if t - at > lib.impactPairCooldown then impactPairs[key] = nil end
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

-- `source` is the body making the sound (for perBody sounds).
local function playImpact(kind, body1, body2, speed, source)
    local sound = lib.impactSounds[kind]
    if not sound or speed < sound.soft or not (love and love.audio) then return end
    local a, b = tostring(body1), tostring(body2)
    local key = kind .. (a < b and (a .. b) or (b .. a))
    if impactPairs[key] then return end
    impactPairs[key] = now()
    local synth = sound.synth and getSynth()
    if synth then
        -- soft hits high, hard hits low (like the samples' pitch 2 -> 1), a step of jitter either way
        local notes = lib.plonkNotes
        local index = math.floor(mapInto(speed, sound.soft, sound.hard, #notes, 1) + 0.5) + love.math.random(-1, 1)
        index = math.max(1, math.min(#notes, index))
        local x1, y1 = body1:getPosition()
        local x2, y2 = body2:getPosition()
        local vol = mapInto(speed, sound.soft, sound.hard, sound.volume[1], sound.volume[2]) * lib.masterVolume * 14
        local patch = sound.synth[love.math.random(#sound.synth)]
        local transpose = sound.transpose or 0
        local thing = sound.perBody and source and source:getUserData().thing
        if thing then
            patch = sound.synth[hashString(thing.id or '') % #sound.synth + 1]
            local size = math.sqrt((thing.width or 0) * (thing.height or 0))
            if size < sound.smallSize then transpose = transpose + 12 end
            if size > sound.bigSize then transpose = transpose - 12 end
        end
        synth.hit(patch, notes[index] + transpose, vol, sound.durMs or 400, (x1 + x2) / 2, (y1 + y2) / 2)
        return
    end
    if not impactSources[kind] then
        impactSources[kind] = {}
        for _, name in ipairs(sound.files) do
            local path = 'assets/sounds/' .. name .. '.ogg'
            if love.filesystem.getInfo(path) then
                table.insert(impactSources[kind], love.audio.newSource(path, 'static'))
            end
        end
    end
    local sources = impactSources[kind]
    if #sources == 0 then return end
    local clone = sources[love.math.random(#sources)]:clone()
    clone:setPitch(mapInto(speed, sound.soft, sound.hard, sound.pitch[1], sound.pitch[2]))
    clone:setVolume(mapInto(speed, sound.soft, sound.hard, sound.volume[1], sound.volume[2]) * lib.masterVolume)
    clone:play()
end

local function fixturePairKey(fix1, fix2)
    local a, b = tostring(fix1), tostring(fix2)
    return a < b and (a .. b) or (b .. a)
end

-- Only the first solve of a new contact makes a sound. Bodies that stay pressed
-- together (tangled Mipos, a Mipo held into the floor) keep reporting big
-- impulses every step and would otherwise sound forever.
function lib.onBeginContact(fix1, fix2, contact)
    if fix1:isSensor() or fix2:isSensor() or not contact then return end
    local x, y = contact:getPositions()
    if not x then return end
    local nx, ny = contact:getNormal()
    local ax, ay = fix1:getBody():getLinearVelocityFromWorldPoint(x, y)
    local bx, by = fix2:getBody():getLinearVelocityFromWorldPoint(x, y)
    local approach = math.abs((ax - bx) * nx + (ay - by) * ny)
    if approach >= lib.minApproachSpeed then
        freshContacts[fixturePairKey(fix1, fix2)] = approach
    end
end

function lib.onEndContact(fix1, fix2)
    freshContacts[fixturePairKey(fix1, fix2)] = nil
end

local function hasLabel(body, label)
    local ud = body:getUserData()
    return ud and ud.thing and ud.thing.label == label
end

function lib.isSquishy(body)
    local ud = body:getUserData()
    local behaviors = ud and ud.thing and ud.thing.behaviors
    if not behaviors then return false end
    for _, behavior in ipairs(behaviors) do
        if behavior.name == 'SQUISHY' then return true end
    end
    return false
end

-- Called from postSolve (first solve of a new contact only). A Mipo part that changes velocity plonks, and a hard
-- change also makes the Mipo say 'oof'. A SQUISHY body kisses. Collisions
-- between parts of the same Mipo are ignored.
function lib.onImpact(fix1, fix2, normalImpulse)
    if not lib.enabled or not normalImpulse then return end
    local key = fixturePairKey(fix1, fix2)
    if not freshContacts[key] then return end
    freshContacts[key] = nil
    local body1, body2 = fix1:getBody(), fix2:getBody()
    local mipo1 = mipoRegistry.getFromBody(body1)
    local mipo2 = mipoRegistry.getFromBody(body2)
    if mipo1 and mipo1 == mipo2 then return end
    for _, pair in ipairs({ { mipo1, body1 }, { mipo2, body2 } }) do
        local instance, body = pair[1], pair[2]
        local mass = body:getMass()
        local speed = mass > 0 and normalImpulse / mass or 0
        if instance then
            local t = now()
            if not lastPlonk[instance.id] or t - lastPlonk[instance.id] > lib.plonkMipoCooldown then
                lastPlonk[instance.id] = t
                playImpact('plonk', body1, body2, speed)
            end
            if speed > lib.impactSpeed then
                if lib.onHardImpact then lib.onHardImpact(instance, speed) end
                if not lastImpact[instance.id] or t - lastImpact[instance.id] > lib.impactCooldown then
                    lastImpact[instance.id] = t
                    lib.squeak(instance, 'oof')
                end
            end
        elseif speed > 0 and hasLabel(body, 'ball') then -- squishy balls too
            playImpact('ball', body1, body2, speed)
        elseif speed > 0 and hasLabel(body, 'box') then
            playImpact('box', body1, body2, speed, body)
        elseif speed > 0 and lib.isSquishy(body) then
            playImpact('kiss', body1, body2, speed)
        end
    end
end

function lib.reset()
    lastSqueak = {}
    lastImpact = {}
    playing = {}
    for _, flap in pairs(flaps) do flap.thing.mouthShapeVec = flap.restore end
    flaps = {}
    impactPairs = {}
    freshContacts = {}
    lastPlonk = {}
end

return lib

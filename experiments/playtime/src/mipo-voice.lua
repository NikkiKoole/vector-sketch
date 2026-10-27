-- mipo-voice.lua
-- Squeaks for Mipos: one syllable or fx sample per reaction, pitched per Mipo.
-- Samples come from the mipomi-lang repo (~/Projects/love/mipomi-lang), copied
-- into assets/voices/{nikki,theo,herman,fx}. Full mipomi speech (say + lipsync)
-- is a later step, see docs/DOLL-PLAY.md "Voice".
local mipoRegistry = require('src.mipo-registry')

local lib = {}

lib.enabled = true
lib.volume = 0.8
lib.cooldown = 0.15      -- seconds between squeaks of the same Mipo
lib.impactCooldown = 0.5 -- seconds between impact 'oof's of the same Mipo
lib.impactSpeed = 1200   -- velocity change (world units/s) for an oof; measured: small hop ~550, 800-unit drop ~2500

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
    playing[instance.id] = play(pick.set, pick.key, voice.pitch * emotion.pitch * jitter)
    return playing[instance.id]
end

function lib.squeakBody(body, emotionName)
    local instance = mipoRegistry.getFromBody(body)
    if instance then return lib.squeak(instance, emotionName) end
    return nil
end

-- Called from postSolve: a Mipo part that changes velocity hard says 'oof'.
-- Collisions between parts of the same Mipo are ignored.
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
            if mass > 0 and normalImpulse / mass > lib.impactSpeed then
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
end

return lib

-- snap-sound.lua
-- A tiny wooden click whenever a snap joint forms (src/physics/snap.lua), played where it
-- formed. Watches snap.joints() from outside instead of hooking snap.lua: a joint it hasn't
-- seen before is a fresh snap. Driven by mipo-voice.update while synth impacts are on.

local state = require('src.state')
local snap = require('src.physics.snap')

local lib = {}

lib.patch = 'click'                -- src/synth.lua patch
lib.notes = { 86, 88, 91, 93, 96 } -- high pentatonic, one at random per click (when there's no music)
lib.vol = 5
lib.maxPerFrame = 3 -- more new snap joints than this in one frame is a scene load or clone, not a snap

-- On `state` so a hot reload doesn't click for every joint again. Weak keys: destroyed joints go away.
state.snapSound = state.snapSound or { known = setmetatable({}, { __mode = 'k' }), seeded = false }
local S = state.snapSound

function lib.update(synth)
    local fresh = {}
    for _, joint in ipairs(snap.joints()) do
        if not S.known[joint] then
            S.known[joint] = true
            fresh[#fresh + 1] = joint
        end
    end
    -- the first look only learns the joints that are already there
    if not S.seeded or #fresh > lib.maxPerFrame then
        S.seeded = true
        return
    end
    for _, joint in ipairs(fresh) do
        if not joint:isDestroyed() then
            local x, y = joint:getAnchors()
            local notes = require('src.music').chordNotes(84, 98) or lib.notes -- in the music's chord
            synth.hit(lib.patch, notes[love.math.random(#notes)], lib.vol, 30, x, y)
        end
    end
end

return lib

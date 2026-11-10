-- mipo-kit.lua — the few Mipo helpers every spike scene had its own copy of (docs/LANDING-2026-11.md
-- L4; the copies were identical): a random Mipo into a list, the ones still standing, is one alive.
-- In a scene script as `mipoKit` (src/script.lua). Scenes that do more (burrow's DNA, depth's lanes,
-- garden's "any part alive") keep their own.
local characterManager = require('src.character-manager')

local lib = {}

lib.SCALE = 0.3 -- the spikes' Mipo size

-- A random Mipo (randomizeMipoConstrained) at x, y, added to `list`; returns it (nil if it failed).
function lib.spawn(list, x, y)
    local inst = characterManager.createCharacter('humanoid', x, y, lib.SCALE)
    if inst then characterManager.randomizeMipoConstrained(inst) end
    if inst then list[#list + 1] = inst end
    return inst
end

-- A Mipo whose torso still has a body (not destroyed by a rebuild gone wrong, a scene clear).
function lib.isAlive(inst)
    local torso = inst and inst.parts and inst.parts.torso1
    return torso and torso.body and not torso.body:isDestroyed()
end

-- The Mipos of `list` that are alive, in order (a new list).
function lib.alive(list)
    local out = {}
    for _, inst in ipairs(list) do
        if lib.isAlive(inst) then out[#out + 1] = inst end
    end
    return out
end

return lib

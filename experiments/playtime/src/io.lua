-- io.lua — scene files, the front (CODE-SPLITS-2026-10.md SPLIT6). The work is in
-- src/scene-load.lua (load, prepareLoaded, buildWorld), src/scene-save.lua (gatherSaveData, save),
-- src/influences.lua (MESHUSERT influences in the file) and src/save-migrations.lua (old files).
-- These pass the call on instead of copying the functions, so a hot reload of those modules
-- reaches everyone who required io.
local sceneLoad = require('src.scene-load')
local sceneSave = require('src.scene-save')
local influences = require('src.influences')
local migrations = require('src.save-migrations')

local lib = {}

function lib.buildWorld(...) return sceneLoad.buildWorld(...) end
function lib.prepareLoaded(...) return sceneLoad.prepareLoaded(...) end
function lib.load(...) return sceneLoad.load(...) end
function lib.gatherSaveData(...) return sceneSave.gatherSaveData(...) end
function lib.save(...) return sceneSave.save(...) end

-- for spec/io_spec.lua (not part of the API)
lib._test = {
    clearWorld = function(...) return sceneLoad.clearWorld(...) end,
    restoreInfluenceBodies = function(...) return influences.restoreBodies(...) end,
    roundFloats = function(...) return sceneSave.roundFloats(...) end,
    stripInfluenceDist = function(...) return influences.stripDist(...) end,
    restoreInfluenceDist = function(...) return influences.restoreDist(...) end,
    pruneZeroWeightInfluences = function(...) return influences.pruneZeroWeight(...) end,
    normalizeBones = function(...) return influences.normalizeBones(...) end,
    restoreBones = function(...) return influences.restoreBones(...) end,
    migrateExtraSteinerToBody = function(...) return migrations.extraSteinerToBody(...) end,
}

return lib

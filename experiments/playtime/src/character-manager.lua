-- character-manager.lua: Mipos, the front (CODE-SPLITS-2026-10.md SPLIT2). The work is in
--   src/mipo-dna.lua         the DNA template: parts, joints, positioners, z order
--   src/mipo-appearance.lua  setting a part's look in its DNA (skin, hair, face, positioners)
--   src/mipo-textures.lua    the texture fixtures made from the DNA (skins, hair, ribbons, face)
--   src/mipo-balance.lua     masses, neck and trunk bend limits, the settled pose
--   src/mipo-build.lua       bodies and joints: create, rebuild a part or the Mipo, save and load
--   src/mipo-randomize.lua   random Mipos, parts and sizes
-- Requires point one way (dna <- appearance; dna <- textures; build <- dna, appearance, textures,
-- balance; randomize <- build). Calls are passed on, so a hot reload of a module reaches everyone.
local lib = {}

local mipoDna = require('src.mipo-dna')
local appearance = require('src.mipo-appearance')
local textures = require('src.mipo-textures')
local balance = require('src.mipo-balance')
local build = require('src.mipo-build')
local randomize = require('src.mipo-randomize')

function lib.updateSkinOfPart(...) return appearance.updateSkinOfPart(...) end
function lib.updateBodyhairOfPart(...) return appearance.updateBodyhairOfPart(...) end
function lib.updateHaircutOfPart(...) return appearance.updateHaircutOfPart(...) end
function lib.updateFaceOfPart(...) return appearance.updateFaceOfPart(...) end
function lib.updatePositioners(...) return appearance.updatePositioners(...) end
function lib.updateConnectedAppearance(...) return appearance.updateConnectedAppearance(...) end

function lib.rebuildTextures(...) return textures.rebuildTextures(...) end

function lib.balanceArms(...) return balance.balanceArms(...) end
function lib.balanceHead(...) return balance.balanceHead(...) end
function lib.balanceNeck(...) return balance.balanceNeck(...) end
function lib.applyTrunk(...) return balance.applyTrunk(...) end
function lib.applyNeck(...) return balance.applyNeck(...) end
function lib.settlePose(...) return balance.settlePose(...) end
function lib.balanceMasses(...) return balance.balanceMasses(...) end
function lib.applySpine(...) return balance.applySpine(...) end

function lib.updatePart(...) return build.updatePart(...) end
function lib.rebuildFromCreation(...) return build.rebuildFromCreation(...) end
function lib.createCharacterFromExistingDNA(...) return build.createCharacterFromExistingDNA(...) end
function lib.createCharacterFromJustDNA(...) return build.createCharacterFromJustDNA(...) end
function lib.poseTpose(...) return build.poseTpose(...) end
function lib.createCharacter(...) return build.createCharacter(...) end
function lib.serializeCharacters(...) return build.serializeCharacters(...) end
function lib.reconstructInstance(...) return build.reconstructInstance(...) end

function lib.armReach(...) return randomize.armReach(...) end
function lib.limitArmReach(...) return randomize.limitArmReach(...) end
function lib.randomizeMipo(...) return randomize.randomizeMipo(...) end
function lib.randomizeMipoConstrained(...) return randomize.randomizeMipoConstrained(...) end
function lib.randomizePart(...) return randomize.randomizePart(...) end
function lib.mutateSizes(...) return randomize.mutateSizes(...) end

-- Tuning values, to read (set them on their own module: these are copies or the same table)
lib.earSpring = mipoDna.earSpring
lib.minArmFactor = randomize.minArmFactor
lib.armRange = build.armRange
lib.footFriction = build.footFriction
lib.footRestitution = build.footRestitution
lib.armMinShare = balance.armMinShare
lib.headMaxShare = balance.headMaxShare
lib.neckMinShare = balance.neckMinShare
lib.neckBend = balance.neckBend
lib.trunkBend = balance.trunkBend

return lib

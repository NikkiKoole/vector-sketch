-- shape-catalogs.lua
-- Shared shape/texture catalogs used by both UI (thumbnail grids) and
-- character randomization logic.

local lib = {}

lib.torsoHeadShapes = {
    'mipo/body/body-01', 'mipo/body/body-02', 'mipo/body/body-03', 'mipo/body/body-04', 'mipo/body/body-05',
    'mipo/body/body-06', 'mipo/body/body-07', 'mipo/body/body-08', 'mipo/body/body-09', 'mipo/body/body-10',
    'mipo/body/body-11', 'mipo/body/body-12', 'mipo/body/body-13', 'mipo/body/body-14', 'mipo/body/body-15',
    'mipo/body/body-16', 'mipo/body/body-17', 'mipo/body/body-18'
}

lib.earShapes = {
    'mipo/ear/ear-01', 'mipo/ear/ear-02', 'mipo/ear/ear-03', 'mipo/ear/ear-04', 'mipo/ear/ear-05', 'mipo/ear/ear-06',
    'mipo/ear/ear-07', 'mipo/ear/ear-08', 'mipo/ear/ear-09', 'mipo/ear/ear-10', 'mipo/ear/ear-11', 'mipo/ear/ear-12',
    'mipo/ear/ear-13', 'mipo/ear/ear-14', 'mipo/ear/ear-15', 'mipo/ear/ear-16'
}

lib.feetShapes = {
    'mipo/foot/foot-01', 'mipo/foot/foot-02', 'mipo/foot/foot-03', 'mipo/foot/foot-04', 'mipo/foot/foot-05',
    'mipo/foot/foot-06', 'mipo/foot/foot-07'
}

lib.handShapes = {
    'mipo/hand/hand-01', 'mipo/foot/foot-01', 'mipo/foot/foot-02', 'mipo/foot/foot-03', 'mipo/foot/foot-04',
    'mipo/foot/foot-05', 'mipo/foot/foot-06', 'mipo/foot/foot-07'
}

-- What the randomizer draws a hand's and a foot's picture from: both the list above (a hand can
-- wear a foot picture, a foot the hand), separate names so a breed can narrow one of them
-- (src/mipo-breeds.lua).
lib.randomHandShapes = lib.handShapes
lib.randomFootShapes = lib.handShapes

lib.bodyhairTextures = {
    'mipo/chesthair/chesthair-01', 'mipo/chesthair/chesthair-02', 'mipo/chesthair/chesthair-03',
    'mipo/chesthair/chesthair-04', 'mipo/chesthair/chesthair-05', 'mipo/chesthair/chesthair-06',
    'mipo/chesthair/chesthair-07'
}

lib.haircutTextures = {
    'mipo/hair/hair-01', 'mipo/hair/hair-02', 'mipo/hair/hair-03', 'mipo/hair/hair-04', 'mipo/hair/hair-05',
    'mipo/hair/hair-06', 'mipo/hair/hair-07', 'mipo/hair/hair-08', 'mipo/hair/hair-09', 'mipo/hair/hair-10',
    'mipo/hair/hair-11'
}

lib.hairsWithMask = { ['mipo/hair/hair-07.png'] = true, ['mipo/hair/hair-08.png'] = true }

lib.limbSkinTextures = {
    'mipo/leg/leg-01', 'mipo/leg/leg-02', 'mipo/leg/leg-03', 'mipo/leg/leg-04', 'mipo/leg/leg-05', 'mipo/leg/leg-06'
}

lib.limbHairTextures = {
    'mipo/hair/hair-01', 'mipo/hair/hair-02', 'mipo/hair/hair-03', 'mipo/hair/hair-04', 'mipo/hair/hair-05',
    'mipo/hair/hair-06', 'mipo/hair/hair-07', 'mipo/hair/hair-08', 'mipo/hair/hair-09', 'mipo/hair/hair-10',
    'mipo/hair/hair-11'
}

lib.eyeShapes = {
    'mipo/eye/eye-01', 'mipo/eye/eye-02', 'mipo/eye/eye-03', 'mipo/eye/eye-04', 'mipo/eye/eye-05', 'mipo/eye/eye-06',
    'mipo/eye/eye-07'
}

lib.pupilShapes = {
    'mipo/pupil/pupil-01', 'mipo/pupil/pupil-02', 'mipo/pupil/pupil-03', 'mipo/pupil/pupil-04', 'mipo/pupil/pupil-05',
    'mipo/pupil/pupil-06', 'mipo/pupil/pupil-07', 'mipo/pupil/pupil-08', 'mipo/pupil/pupil-09', 'mipo/pupil/pupil-10',
    'mipo/pupil/pupil-11'
}

lib.browShapes = {
    'mipo/brow/brow-01', 'mipo/brow/brow-02', 'mipo/brow/brow-03', 'mipo/brow/brow-04', 'mipo/brow/brow-05',
    'mipo/brow/brow-06', 'mipo/brow/brow-07'
}

-- upperlip-04 (the duck beak) is out (2026-10-29): a landscape picture drawn in less than half
-- of it, so it sat and sized unlike the others; saved Mipos get upperlip-01 (mipo-build)
lib.upperLipShapes = { 'mipo/upperlip/upperlip-01', 'mipo/upperlip/upperlip-02', 'mipo/upperlip/upperlip-03' }
lib.lowerLipShapes = {
    'mipo/lowerlip/lowerlip-01', 'mipo/lowerlip/lowerlip-02', 'mipo/lowerlip/lowerlip-03', 'mipo/lowerlip/lowerlip-04'
}

lib.noseShapes = {
    'mipo/nose/nose-01', 'mipo/nose/nose-02', 'mipo/nose/nose-03', 'mipo/nose/nose-04', 'mipo/nose/nose-05',
    'mipo/nose/nose-06', 'mipo/nose/nose-07', 'mipo/nose/nose-08', 'mipo/nose/nose-09', 'mipo/nose/nose-10',
    'mipo/nose/nose-11', 'mipo/nose/nose-12', 'mipo/nose/nose-13', 'mipo/nose/nose-14', 'mipo/nose/nose-15'
}

lib.teethShapes = {
    'mipo/teeth/teeth-01', 'mipo/teeth/teeth-02', 'mipo/teeth/teeth-03', 'mipo/teeth/teeth-04', 'mipo/teeth/teeth-05',
    'mipo/teeth/teeth-06', 'mipo/teeth/teeth-07'
}

lib.patternTextures = {
    'pat/type0', 'pat/type1', 'pat/type2t', 'pat/type3_',
    'pat/type4', 'pat/type5', 'pat/type6', 'pat/type7', 'pat/type8',
}

-- A hand picture (in handShapes, not a foot picture): used as a foot it's mirrored, so the
-- thumb points up instead of the Mipo standing on it (mipo-build partSettings).
function lib.isHandPicture(url)
    local name = url and url:gsub('%.png$', '')
    for _, foot in ipairs(lib.feetShapes) do
        if foot == name then return false end
    end
    for _, hand in ipairs(lib.handShapes) do
        if hand == name then return true end
    end
    return false
end

return lib

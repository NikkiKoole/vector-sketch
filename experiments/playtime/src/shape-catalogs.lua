-- shape-catalogs.lua
-- Shared shape/texture catalogs used by both UI (thumbnail grids) and
-- character randomization logic.

local lib = {}

lib.torsoHeadShapes = {
    'shapeA1', 'shapeA2', 'shapeA3', 'shapeA4',
    'shapes1', 'shapes2', 'shapes3', 'shapes4', 'shapes5',
    'shapes6', 'shapes7', 'shapes8', 'shapes9', 'shapes10',
    'shapes11', 'shapes12', 'shapes13'
}

lib.earShapes = {
    'earx1r', 'earx2r', 'earx3r', 'earx4r', 'earx5r', 'earx6r',
    'earx7r', 'earx8r', 'earx9r', 'earx10r', 'earx11r', 'earx12r',
    'earx13r', 'earx14r', 'earx15r', 'earx16r'
}

lib.feetShapes = {
    'feet2r', 'feet3xr', 'feet5xr', 'feet6r', 'feet7r', 'feet7xr', 'feet8r'
}

lib.handShapes = {
    'hand3r', 'feet2r', 'feet3xr', 'feet5xr', 'feet6r', 'feet7r', 'feet7xr', 'feet8r'
}

lib.bodyhairTextures = {
    'borsthaar1', 'borsthaar2', 'borsthaar3', 'borsthaar4',
    'borsthaar5', 'borsthaar6', 'borsthaar7'
}

lib.haircutTextures = {
    'hair1', 'hair2', 'hair3', 'hair4', 'hair5',
    'hair6', 'hair7', 'hair8', 'hair9', 'hair10', 'hair11'
}

lib.hairsWithMask = { ['hair7.png'] = true, ['hair8.png'] = true }

lib.limbSkinTextures = {
    'leg1', 'leg2', 'leg3', 'leg4', 'leg5', 'leg7'
}

lib.limbHairTextures = {
    'hair1', 'hair2', 'hair3', 'hair4', 'hair5',
    'hair6', 'hair7', 'hair8', 'hair9', 'hair10', 'hair11'
}

lib.eyeShapes = {
    'eye1', 'eye2', 'eye3', 'eye4', 'eye5', 'eye6', 'eye7'
}

lib.pupilShapes = {
    'pupil1', 'pupil2', 'pupil3', 'pupil4', 'pupil5', 'pupil6',
    'pupil7', 'pupil8', 'pupil9', 'pupil10', 'pupil11'
}

lib.browShapes = {
    'brow1', 'brow2', 'brow3', 'brow4', 'brow5', 'brow6', 'brow7'
}

lib.upperLipShapes = { 'upperlip1', 'upperlip2', 'upperlip3', 'upperlip4' }
lib.lowerLipShapes = { 'lowerlip1', 'lowerlip2', 'lowerlip3', 'lowerlip4' }

lib.noseShapes = {
    'nose1', 'nose2', 'nose3', 'nose4', 'nose5', 'nose6', 'nose7', 'nose8',
    'nose9', 'nose10', 'nose11', 'nose12', 'nose13', 'nose14', 'nose15'
}

lib.teethShapes = {
    'teeth1', 'teeth2', 'teeth3', 'teeth4', 'teeth5', 'teeth6', 'teeth7'
}

lib.patternTextures = {
    'pat/type0', 'pat/type1', 'pat/type2t', 'pat/type3_',
    'pat/type4', 'pat/type5', 'pat/type6', 'pat/type7', 'pat/type8',
}

return lib

local lib = {}

local ObjectManager = require 'src.object-manager' -- To create the physical parts
local Joints = require 'src.joints'
local uuid = require 'src.uuid'
local utils = require 'src.utils'
local mathutils = require 'src.math-utils'
local fixtures = require 'src.fixtures'
local drawTextured = require 'src.physics.box2d-draw-textured'
local subtypes = require 'src.subtypes'
local ST = require 'src.shape-types'
local JT = require('src.joint-types')
local BT = require('src.body-types')
local NT = require('src.node-types')
local mipoRegistry = require('src.mipo-registry')
local mouthShapes = require('src.mouth-shapes')
local state = require('src.state')

-- todo,
-- the curves for the limbs need a grow parameter, now its just some hardcoded value in lib.drawTexturedWorld(world)
-- the torso images, or maybe every tex-fixture also needs a growvalue that describes
-- how much the w, h values will be grown.
-- next the chesthair has a grow too, the torso too and I also have a foot offset value that should be parametrized.

-- do lerping positioners (arm beginning, leg beginnnig, ear)
-- OMP images as limb hair (and chesthair) -- maybe we should just know which images have a mask and if they are OMP
-- do FACE PARTS


local function cyclicShift(arr, shift)
    local n = #arr
    local result = {}
    shift = shift % n -- handles overflow and negative values

    for i = 1, n do
        local new_index = ((i - 1 - shift) % n) + 1
        result[i] = arr[new_index]
    end

    return result
end

local function getBoundingBox(poly)
    assert(#poly % 2 == 0, "Polygon must have even number of coordinates")

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge

    for i = 1, #poly, 2 do
        local x, y = poly[i], poly[i + 1]
        if x < minX then minX = x end
        if x > maxX then maxX = x end
        if y < minY then minY = y end
        if y > maxY then maxY = y end
    end

    return {
        x = minX,
        y = minY,
        maxX = maxX,
        maxY = maxY,
        width = maxX - minX,
        height = maxY - minY
    }
end
local randomHexColor = utils.randomHexColor


local function createDefaultTextureDNABlock(shape, skipFG)
    --local r, g, b, a = drawTextured.hexToColor('ff0000ff')
    --print(r, g, b, a)

    local result = {
        bgURL = shape .. '.png',
        fgURL = skipFG and '' or shape .. '-mask.png',
        pURL = '',
        bgHex = '020202ff',
        fgHex = skipFG and '' or 'ff0000ff',
        pHex = 'ffff00ff',

    }

    drawTextured.makeCached(result)

    return result
end

local function initBlock(url)
    -- local r, g, b, a = drawTextured.hexToColor('ff0000ff')
    -- print(r, g, b, a)
    local result = {
        bgURL = (url or '') .. '.png',
        fgURL = (url or '') .. '-mask.png',
        pURL = '',
        bgHex = '020202ff',
        fgHex = randomHexColor(),
        pHex = randomHexColor(),

    }
    drawTextured.makeCached(result)

    return result
end

local function add(block, values)
    for k, v in pairs(values) do
        block[k] = v
    end
    return block
end

function lib.updateSkinOfPart(instance, partName, values, optionalPatchName)
    local p = instance.dna.parts[partName]
    if p then
        if p.appearance and p.appearance['skin'] then
            local patch = optionalPatchName or 'main'
            if p.appearance['skin'][patch] then
                for k, v in pairs(values) do
                    p.appearance['skin'][patch][k] = v
                end
                -- Clear cached RGB so makeCached() recalculates from the new hex values.
                -- Without this, deepCopy in addTexturesFromInstance2 copies stale cached
                -- values and makeCached skips recalculation (it only runs when cached is nil).
                p.appearance['skin'][patch].cached = nil
            end
        end
    end
end

function lib.updateBodyhairOfPart(instance, partName, values, optionalPatchName)
    local p = instance.dna.parts[partName]
    if p then
        if p.appearance and p.appearance['bodyhair'] then
            local patch = optionalPatchName or 'main'
            if p.appearance['bodyhair'][patch] then
                for k, v in pairs(values) do
                    p.appearance['bodyhair'][patch][k] = v
                end
                -- Clear cached RGB (same reason as updateSkinOfPart above)
                p.appearance['bodyhair'][patch].cached = nil
            end
        end
    end
end

function lib.updateHaircutOfPart(instance, partName, values)
    local p = instance.dna.parts[partName]
    if p and p.appearance and p.appearance['haircut'] then
        local hc = p.appearance['haircut']
        for k, v in pairs(values) do
            if k == 'bgURL' or k == 'fgURL' or k == 'bgHex' or k == 'fgHex' or k == 'pHex' or k == 'pURL' then
                if hc.main then
                    hc.main[k] = v
                    hc.main.cached = nil
                end
            else
                hc[k] = v
            end
        end
    end
end

-- Update face appearance (eye/pupil/brow/nose/mouth shape, colors, positions).
-- values can contain: eyeShape, eyeBgHex, eyeFgHex, eyeWMul, eyeHMul,
-- pupilShape, pupilBgHex, pupilFgHex, pupilWMul, pupilHMul, eyeX, eyeY,
-- browShape, browBgHex, browWMul, browHMul, browBend, browY,
-- noseShape, noseBgHex, noseFgHex, noseWMul, noseHMul, noseY,
-- mouthShape, mouthUpperLipShape, mouthLowerLipShape, mouthLipHex,
-- mouthBackdropHex, mouthLipScale, mouthWMul, mouthHMul, mouthY
function lib.updateFaceOfPart(instance, partName, values)
    local p = instance.dna.parts[partName]
    if not p or not p.appearance or not p.appearance['face'] then return end
    local face = p.appearance['face']
    if not face.eye then face.eye = {} end
    if not face.pupil then face.pupil = {} end
    if not face.mouth then
        face.mouth = {
            shape = 2, upperLipShape = 1, lowerLipShape = 1,
            lipHex = 'cc5555ff', backdropHex = '00000033',
            lipScale = 0.25, wMul = 1, hMul = 1,
        }
    end
    if not face.brow then face.brow = { shape = 1, bgHex = '000000ff', wMul = 1, hMul = 1, bend = 1 } end
    if not face.nose then face.nose = { shape = 0, bgHex = '000000ff', fgHex = 'ffffffff', wMul = 1, hMul = 1 } end
    if not face.positioners then face.positioners = { eye = { x = 0.2, y = 0.5 }, brow = { y = 0.3 }, nose = { y = 0.35 }, mouth = { y = 0.7 } } end
    if not face.positioners.eye then face.positioners.eye = { x = 0.2, y = 0.5 } end
    if not face.positioners.brow then face.positioners.brow = { y = 0.3 } end
    if not face.positioners.nose then face.positioners.nose = { y = 0.35 } end
    if not face.positioners.mouth then face.positioners.mouth = { y = 0.7 } end

    if values.eyeShape then face.eye.shape = values.eyeShape end
    if values.eyeBgHex then face.eye.bgHex = values.eyeBgHex end
    if values.eyeFgHex then face.eye.fgHex = values.eyeFgHex end
    if values.eyeWMul then face.eye.wMul = values.eyeWMul end
    if values.eyeHMul then face.eye.hMul = values.eyeHMul end
    if values.pupilShape then face.pupil.shape = values.pupilShape end
    if values.pupilBgHex then face.pupil.bgHex = values.pupilBgHex end
    if values.pupilFgHex then face.pupil.fgHex = values.pupilFgHex end
    if values.pupilWMul then face.pupil.wMul = values.pupilWMul end
    if values.pupilHMul then face.pupil.hMul = values.pupilHMul end
    if values.eyeX then face.positioners.eye.x = values.eyeX end
    if values.eyeY then face.positioners.eye.y = values.eyeY end

    if values.browShape then face.brow.shape = values.browShape end
    if values.browBgHex then face.brow.bgHex = values.browBgHex end
    if values.browWMul then face.brow.wMul = values.browWMul end
    if values.browHMul then face.brow.hMul = values.browHMul end
    if values.browBend then face.brow.bend = values.browBend end
    if values.browY then face.positioners.brow.y = values.browY end

    if values.noseShape then face.nose.shape = values.noseShape end
    if values.noseBgHex then face.nose.bgHex = values.noseBgHex end
    if values.noseFgHex then face.nose.fgHex = values.noseFgHex end
    if values.noseWMul then face.nose.wMul = values.noseWMul end
    if values.noseHMul then face.nose.hMul = values.noseHMul end
    if values.noseY then face.positioners.nose.y = values.noseY end

    if values.mouthShape then face.mouth.shape = values.mouthShape end
    if values.mouthUpperLipShape then face.mouth.upperLipShape = values.mouthUpperLipShape end
    if values.mouthLowerLipShape then face.mouth.lowerLipShape = values.mouthLowerLipShape end
    if values.mouthLipHex then face.mouth.lipHex = values.mouthLipHex end
    if values.mouthBackdropHex then face.mouth.backdropHex = values.mouthBackdropHex end
    if values.mouthLipScale then face.mouth.lipScale = values.mouthLipScale end
    if values.mouthWMul then face.mouth.wMul = values.mouthWMul end
    if values.mouthHMul then face.mouth.hMul = values.mouthHMul end
    if values.mouthY then face.positioners.mouth.y = values.mouthY end
end

-- Update connected-skin or connected-hair appearance colors.
-- Connected textures stretch between joint-linked body parts (used for arms/legs).
-- appearanceKey is 'connected-skin' (OMP composite) or 'connected-hair' (2-layer).
function lib.updateConnectedAppearance(instance, partName, appearanceKey, values)
    local p = instance.dna.parts[partName]
    if p and p.appearance and p.appearance[appearanceKey] then
        local main = p.appearance[appearanceKey].main
        if main then
            for k, v in pairs(values) do
                main[k] = v
            end
            -- Clear cached RGB so makeCached() recalculates from the new hex values
            main.cached = nil
        end
    end
end

-- 8-vertex polygon shapes for character body parts, keyed by texture filename
local shape8Dict = {
    ['shapeA1.png'] = { dimensions = { 339, 560 },
        vertices = { 1, -272, 112, -133, 154, 76, 123, 229, 1, 273, -134, 225, -145, 73, -91, -132 } },
    ['shapeA2.png'] = { dimensions = { 289, 468 },
        vertices = { 11, -224, 60, -144, 59, -20, 133, 135, 4, 224, -133, 131, -51, -20, -39, -147, } },
    ['shapeA3.png'] = { dimensions = { 370, 422 },
        vertices = { -6, -189, 135, -69, 160, 45, 123, 154, -6, 189, -92, 153, -164, 53, -155, -67 } },
    ['shapeA4.png'] = { dimensions = { 308, 414 },
        vertices = { 7, -194, 133, -56, 126, 45, 101, 190, -6, 195, -129, 185, -134, 40, -110, -66 } },
    ['shapes1.png'] = { dimensions = { 296, 495 },
        vertices = { 10, -244, 133, -56, 135, 48, 124, 221, -0, 231, -128, 215, -138, 41, -134, -62 } },
    ['shapes2.png'] = { dimensions = { 252, 461 },
        vertices = { -3, -223, 74, -78, 89, 51, 104, 196, -0, 231, -92, 202, -94, 54, -61, -80 } },
    ['shapes3.png'] = { dimensions = { 324, 442 },
        vertices = { -3, -206, 132, -137, 148, 12, 110, 186, -6, 216, -97, 192, -149, 7, -141, -141 } },
    ['shapes4.png'] = { dimensions = { 364, 266 },
        vertices = { 0, -123, 164, -98, 148, 12, 157, 112, -1, 117, -149, 105, -149, 7, -168, -87 } },
    ['shapes5.png'] = { dimensions = { 194, 338 },
        vertices = { 0, -162, 74, -132, 78, -4, 73, 148, -2, 156, -81, 142, -84, 1, -87, -126, } },
    ['shapes6.png'] = { dimensions = { 250, 384 },
        vertices = { 3, -178, 77, -118, 92, -0, 93, 143, -2, 160, -85, 141, -92, 0, -67, -119 } },
    ['shapes7.png'] = { dimensions = { 722, 929 },
        vertices = { -3, -452, 127, -245, 305, 19, 247, 384, -2, 451, -276, 378, -283, 15, -207, -238 } },
    ['shapes8.png'] = { dimensions = { 788, 708 },
        vertices = { 3, -154, 271, -307, 341, 26, 89, 298, -9, 332, -166, 299, -302, 34, -238, -319 } },
    ['shapes9.png'] = { dimensions = { 520, 468 },
        vertices = { -0, -236, 233, -191, 198, 24, 174, 206, -18, 216, -226, 205, -233, 19, -234, -198 } },
    ['shapes10.png'] = { dimensions = { 520, 856 },
        vertices = { 4, -407, 166, -232, 231, 24, 141, 344, -16, 418, -186, 332, -233, 19, -182, -233 } },
    ['shapes11.png'] = { dimensions = { 652, 932 },
        vertices = { 4, -451, 110, -405, 195, 6, 306, 408, 13, 436, -277, 417, -205, -3, -114, -417 } },
    ['shapes12.png'] = { dimensions = { 558, 323 },
        vertices = { 17, -129, 208, -76, 249, 11, 191, 109, 9, 142, -228, 103, -247, -1, -175, -91 } },
    ['shapes13.png'] = { dimensions = { 486, 556 },
        vertices = { 22, -239, 175, -101, 197, 11, 177, 219, 14, 260, -168, 210, -156, 12, -125, -105 } },
    ['feet2r.png'] = { dimensions = { 261, 475 },
        vertices = { 46, -189, 96, -184, 131, 48, 109, 180, 45, 234, -15, 176, -70, 53, -87, -193 } },
    ['feet6r.png'] = { dimensions = { 293, 612 },
        vertices = { -28, -264, 46, -180, 110, 42, 117, 167, -7, 274, -109, 268, -110, 47, -102, -182 } },
    ['feet5xr.png'] = { dimensions = { 174, 621 },
        vertices = { -4, -243, 25, -216, 46, 31, 66, 244, 3, 275, -69, 245, -71, 29, -41, -233 } },
    ['feet3xr.png'] = { dimensions = { 231, 505 },
        vertices = { 8, -199, 56, -154, 46, 31, 61, 196, 5, 245, -54, 191, -71, 29, -38, -150 } },
    ['feet7r.png'] = { dimensions = { 300, 546 },
        vertices = { -4, -243, 57, -227, 111, 6, 87, 218, 3, 256, -69, 213, -96, 10, -50, -223 } },
    ['feet8r.png'] = { dimensions = { 303, 465 },
        vertices = { -11, -200, 37, -151, 87, 6, 110, 180, -7, 203, -100, 176, -96, 10, -74, -149 } },
    ['hand3r.png'] = { dimensions = { 294, 489 },
        vertices = { -31, -215, 99, -111, 26, 52, 39, 192, -32, 242, -121, 188, -140, 50, -132, -110 } },
    ['feet7xr.png'] = { dimensions = { 216, 410 },
        vertices = { 4, -170, 71, -143, 77, -47, 45, 165, -11, 182, -71, 163, -67, -51, -42, -144 } },
    ['earx1r.png'] = { dimensions = { 312, 416 },
        vertices = { -32, -132, 71, -50, 92, 36, 36, 177, -23, 92, -74, 93, -117, 36, -140, -53 } },
    ['earx2r.png'] = { dimensions = { 354, 420 },
        vertices = { 23, -163, 125, -63, 135, 33, 116, 95, 16, 144, -74, 99, -112, 35, -89, -63 } },
    ['earx3r.png'] = { dimensions = { 369, 339 },
        vertices = { -111, -116, -23, -48, 36, 13, 96, 70, -11, 74, -94, 70, -107, 15, -114, -49 } },
    ['earx4r.png'] = { dimensions = { 306, 483 },
        vertices = { -15, -195, 85, -67, 69, 35, 54, 96, -13, 98, -74, 93, -92, 34, -108, -68 } },
    ['earx5r.png'] = { dimensions = { 240, 549 },
        vertices = { 9, -191, 49, -72, 69, 48, 82, 187, 10, 209, -61, 198, -69, 51, -54, -72 } },
    ['earx6r.png'] = { dimensions = { 240, 519 },
        vertices = { -15, -214, 79, -67, 92, 59, 73, 187, -4, 193, -66, 185, -88, 57, -94, -68 } },
    ['earx7r.png'] = { dimensions = { 204, 474 },
        vertices = { -49, -189, 48, -67, 69, 35, 54, 96, -13, 98, -74, 93, -92, 34, -81, -68 } },
    ['earx8r.png'] = { dimensions = { 402, 270 },
        vertices = { -22, -88, 85, -67, 128, 29, 120, 84, -13, 90, -153, 88, -160, 25, -108, -68 } },
    ['earx9r.png'] = { dimensions = { 231, 243 },
        vertices = { -4, -81, 38, -60, 66, 0, 62, 38, -7, 59, -73, 49, -82, 7, -57, -59 } },
    ['earx10r.png'] = { dimensions = { 168, 174 },
        vertices = { -3, -35, 29, -16, 32, 13, 35, 46, -7, 50, -50, 45, -45, 13, -37, -15 } },
    ['earx11r.png'] = { dimensions = { 177, 150 },
        vertices = { -1, -33, 29, -16, 32, 16, 14, 47, -16, 41, -50, 45, -45, 13, -37, -15 } },
    ['earx12r.png'] = { dimensions = { 240, 330 },
        vertices = { -19, -66, 39, -28, 76, 13, 49, 73, -9, 86, -45, 72, -57, 15, -62, -21 } },
    ['earx13r.png'] = { dimensions = { 225, 336 },
        vertices = { -33, -100, 12, -33, 29, 16, 43, 73, -9, 86, -54, 72, -57, 15, -62, -33 } },
    ['earx14r.png'] = { dimensions = { 270, 465 },
        vertices = { -54, -172, 47, -41, 76, 18, 102, 82, -39, 86, -105, 83, -117, 23, -104, -42 } },
    ['earx15r.png'] = { dimensions = { 132, 228 },
        vertices = { -20, -78, 15, -36, 26, 11, 21, 66, -16, 63, -37, 40, -43, 12, -48, -36 } },
    ['earx16r.png'] = { dimensions = { 312, 258 },
        vertices = { -57, -98, 25, -35, 54, 8, 69, 51, -50, 59, -89, 58, -99, 9, -95, -36 } },
}

local dna = {
    ['humanoid'] = {
        creation = {
            isPotatoHead = true,
            neckSegments = 0,
            torsoSegments = 1,
            noseSegments = 1, -- 0 = no nose; >0 = segmented nose/trunk
        },


        -- in the apppearance below we have a few options for types:
        -- skin = a skin that assumes a shape8 url to be present.
        -- bodyhair, = an overlay that assumes the shape8 url to be present, it will follow that
        -- connected-skin = a texture that will be drawn over a few connectd bodyparts
        -- connected-hair = an overlay that assumes a few parts to be there too.
        -- todo trace-hair, a texture that follows a few vertex indicises within 1 shape.
        parts = {
            ['nose-segment-template'] = {
                appearance = {

                    -- plain skin per segment; good first step
                    ['skin'] = {
                        zOffset = 3,
                        main = initBlock('shapeA2'), -- swap to a specific shape/texture if you prefer
                    },
                    -- ['connected-skin'] = {
                    --     main = add(initBlock('leg5'), {}),
                    --     zOffset = 3,
                    --     --endNode = 'tip'
                    -- },
                },
                -- small capsule by default; tweak as needed
                dims = { w = 40, h = 40, w2 = 4, sx = 1, sy = 1 },

                -- if we want the connected skin you probably want to use the capsule shape.
                -- if you want a normal txture you might want the shape8

                shape = ST.SHAPE8,
                shape8URL = 'shapeA2.png',

                --shape = ST.CAPSULE,
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 32, up = math.pi / 32 } }
            },
            ['torso-segment-template'] = {
                appearance = {
                    -- this will do the neck texturing (connecting torso and head)
                    ['connected-skin'] = {
                        main = add(initBlock('leg5'), {}),
                        endNode = 'head',
                        zOffset = 4,
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = 1 }),
                        endNode = 'head',
                        zOffset = 5,
                    },
                    ['skin'] = {
                        main = initBlock(),
                        patch1 = add(initBlock('patch2'), { tx = -0.33, ty = 0 }),
                        patch2 = add(initBlock('patch1'), { tx = 0.33, ty = 0 }),
                        patch3 = add(initBlock('patch1'), { tx = 0, ty = 0.83, sx = 2 })
                    },
                    ['bodyhair'] = { main = add(initBlock('borsthaar4'), {}) },
                    ['haircut'] = {
                        startIndex = 6,
                        endIndex = 2,
                        main = initBlock('hair7'),
                    },
                    ['face'] = {
                        eye = { shape = 1, bgHex = '000000ff', fgHex = 'ffffffff', wMul = 1, hMul = 1 },
                        pupil = { shape = 1, bgHex = '000000ff', fgHex = '', wMul = 0.5, hMul = 0.5 },
                        brow = { shape = 1, bgHex = '000000ff', wMul = 1, hMul = 1, bend = 1 },
                        nose = { shape = 0, bgHex = '000000ff', fgHex = 'ffffffff', wMul = 1, hMul = 1 },
                        mouth = {
                            shape = 2, upperLipShape = 1, lowerLipShape = 1,
                            lipHex = 'cc5555ff', backdropHex = '00000033',
                            lipScale = 0.25, wMul = 1, hMul = 1,
                        },
                        positioners = { eye = { x = 0.2, y = 0.5 }, brow = { y = 0.3 }, nose = { y = 0.35 }, mouth = { y = 0.7 } },
                    },
                },
                dims = { w = 280, w2 = 5, h = 300, sx = 1, sy = 1 },
                shape8URL = 'shapeA1.png',
                shape = ST.SHAPE8,
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },

            --['torso-segment-template'] = { dims = { w = 280, w2 = 5, h = 80 },
            --    shape = ST.CAPSULE, j = { type = JT.REVOLUTE, limits = { low = -math.pi / 16, up = math.pi / 16 } } },
            -- ['torso1'] = { dims = { w = 300, w2 = 4, h = 300 }, shape = 'trapezium' },
            ['neck-segment-template'] = {

                dims = { w = 80, w2 = 4, h = 150 },
                shape = ST.CAPSULE,
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            -- ['head'] = { dims = { w = 100, w2 = 4, h = 180 }, shape = ST.CAPSULE,
            --     j = { type = JT.REVOLUTE, limits = { low = -math.pi / 4, up = math.pi / 4 } } },
            ['head'] = {
                appearance = {
                    ['skin'] = {
                        zOffset = 2,
                        main = initBlock(),
                        patch1 = add(initBlock('patch1'), { tx = -0.33, ty = 0 }),
                        patch2 = add(initBlock('patch1'), { tx = 0.33, ty = 0 }),
                        patch3 = add(initBlock('patch1'), { tx = 0, ty = 0.83, sx = 2 })
                    },
                    ['bodyhair'] = { main = initBlock('borsthaar4') },
                    ['haircut'] = {
                        startIndex = 6,
                        endIndex = 2,
                        main = initBlock('hair6'),
                    },
                    ['face'] = {
                        eye = { shape = 1, bgHex = '000000ff', fgHex = 'ffffffff', wMul = 1, hMul = 1 },
                        pupil = { shape = 1, bgHex = '000000ff', fgHex = '', wMul = 0.5, hMul = 0.5 },
                        brow = { shape = 1, bgHex = '000000ff', wMul = 1, hMul = 1, bend = 1 },
                        nose = { shape = 0, bgHex = '000000ff', fgHex = 'ffffffff', wMul = 1, hMul = 1 },
                        mouth = {
                            shape = 2, upperLipShape = 1, lowerLipShape = 1,
                            lipHex = 'cc5555ff', backdropHex = '00000033',
                            lipScale = 0.25, wMul = 1, hMul = 1,
                        },
                        positioners = { eye = { x = 0.2, y = 0.5 }, brow = { y = 0.3 }, nose = { y = 0.35 }, mouth = { y = 0.7 } },
                    },
                },
                dims = { w = 100, w2 = 4, h = 180, sx = 1, sy = 1 },
                shape = ST.SHAPE8,
                shape8URL = 'shapeA2.png',
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 4, up = math.pi / 4 } }
            },
            ['luleg'] = {
                appearance = {
                    ['connected-skin'] = {
                        main = add(initBlock('leg5'), { dir = -1 }),
                        endNode = 'lfoot'
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = -1 }),
                        endNode = 'lfoot'
                    }
                },
                dims = { w = 80, h = 200, w2 = 4 },
                shape = ST.CAPSULE,
                j = { type = JT.REVOLUTE, limits = { low = 0, up = math.pi / 2 } }
            },
            ['ruleg'] = {
                appearance = {
                    ['connected-skin'] = {
                        main = add(initBlock('leg5'), { dir = 1 }),
                        endNode = 'rfoot'
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = 1 }),
                        endNode = 'rfoot'
                    }
                },
                dims = { w = 80, h = 200, w2 = 4 },
                shape = ST.CAPSULE,
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 2, up = 0 } }
            },
            ['llleg'] = { dims = { w = 80, h = 200, w2 = 4 }, shape = ST.CAPSULE,
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 2, up = 0 } } },
            ['rlleg'] = { dims = { w = 80, h = 200, w2 = 4 }, shape = ST.CAPSULE,
                j = { type = JT.REVOLUTE, limits = { low = 0, up = math.pi / 2 } } },
            ['luarm'] = {
                appearance = {
                    ['connected-skin'] = {
                        zOffset = 1,
                        main = add(initBlock('leg5'), { dir = -1 }),
                        endNode = 'lhand'
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = -1 }),
                        endNode = 'lhand'
                    }
                },
                dims = { w = 40, h = 200, w2 = 4 },
                shape = ST.CAPSULE,
                j = { type = JT.REVOLUTE, limits = { low = 0, up = math.pi } }
            },
            ['ruarm'] = {
                appearance = {
                    ['connected-skin'] = {
                        zOffset = 1,
                        main = add(initBlock('leg5'), { dir = 1 }),
                        endNode = 'rhand'
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = 1 }),
                        endNode = 'rhand'
                    }
                },
                dims = { w = 40, h = 200, w2 = 4 },
                shape = ST.CAPSULE,
                j = { type = JT.REVOLUTE, limits = { low = -math.pi, up = 0 } }
            },
            ['llarm'] = { dims = { w = 40, h = 200, w2 = 4 },
                shape = ST.CAPSULE, j = { type = JT.REVOLUTE, limits = {} } },
            ['rlarm'] = { dims = { w = 40, h = 200, w2 = 4 },
                shape = ST.CAPSULE, j = { type = JT.REVOLUTE, limits = {} } },
            ['lfoot'] = {
                appearance = {
                    ['skin'] = {
                        main = add(initBlock(), { dir = -1 }),
                    },

                },
                dims = { w = 80, h = 150, sx = 1, sy = 1 },
                shape = ST.SHAPE8,
                shape8URL = 'feet6r.png',
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            ['rfoot'] = {
                appearance = {
                    ['skin'] = {
                        main = add(initBlock(), { dir = 1 }),
                    },
                },
                dims = { w = 80, h = 150, sx = -1, sy = 1 },
                shape = ST.SHAPE8,
                shape8URL = 'feet6r.png',
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            -- TODO THIS IS SO WEIRD, BUT WHEN I DONT USE A SHAPE8 for THE FOOT THE ANGLE IS FLIPPED?!
            --['lfoot'] = { dims = { w = 80, h = 250 }, shape = ST.CAPSULE,
            --    j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            --['rfoot'] = { dims = { w = 80, h = 250 }, shape = ST.CAPSULE,
            --    j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            ['lhand'] = {
                appearance = {
                    ['skin'] = {
                        main = add(initBlock(), { dir = -1 }),
                    },
                },
                dims = { w = 40, h = 40, sx = 1, sy = 1 },
                shape = ST.SHAPE8,
                shape8URL = 'hand3r.png',
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            ['rhand'] = {
                appearance = {
                    ['skin'] = {
                        main = add(initBlock(), {}),
                    },
                },
                dims = { w = 40, h = 40, sx = -1, sy = 1 },
                shape = ST.SHAPE8,
                shape8URL = 'hand3r.png',
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            -- TODo same kind of weirdness for the hands!
            -- ['lhand'] = { dims = { w = 40, h = 400 }, shape = 'rectangle',
            --     j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            -- ['rhand'] = { dims = { w = 40, h = 400 }, shape = 'rectangle',
            --     j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            ['lear'] = {
                appearance = {
                    ['skin'] = {
                        zOffset = -1,
                        main = add(initBlock(), {}),
                        --patch1 = add(initBlock('patch2'), { tx = 0.3, ty = 0.3 }),
                        --patch2 = add(initBlock('patch1'), { tx = -0.3, ty = 0.3 })
                    }
                },
                dims = { w = 100, h = 300, sx = .5, sy = 1 },

                shape = ST.SHAPE8,
                shape8URL = 'earx1r.png',
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 16, up = math.pi / 16 } },
                stanceAngle = -math.pi / 2 + math.pi / 5
            },
            ['rear'] = {
                appearance = {
                    ['skin'] = {
                        zOffset = -1,
                        main = add(initBlock(), {}),
                        --patch1 = add(initBlock('patch2'), { tx = 0.3, ty = 0.3 }),
                        --patch2 = add(initBlock('patch1'), { tx = -0.3, ty = 0.3 })
                    }
                },
                dims = { w = 10, h = 100, sx = -.5, sy = 1 },

                shape = ST.SHAPE8,
                shape8URL = 'earx1r.png',
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 16, up = math.pi / 16 } },
                stanceAngle = math.pi / 2 - math.pi / 5
            }
        },

    }
}



function lib.updateShape8(instance, partName, newShape8Name)
    -- Update the physics part
    lib.updatePart(partName, { shape8URL = newShape8Name .. '.png' }, instance)

    -- Trigger a rebuild
    lib.rebuildFromCreation(instance, {})

    -- Update all visuals linked to that shape
    --lib.updateTextureGroupValue(instance, partName .. 'Skin', 'bgURL', newShape8Name .. '.png')
    --lib.updateTextureGroupValue(instance, partName .. 'Skin', 'fgURL', newShape8Name .. '-mask.png')
    --lib.updateTextureGroupValueInRoot(instance, partName .. 'Hair', 'followShape8', newShape8Name .. '.png')

    -- Recreate the actual texture fixtures
    --   lib.addTextureFixturesFromInstance(instance)
end

-- copy pasted from playtime-ui.lua
local getCenterAndDimensions = mathutils.getCenterAndDimensions

local function recenterPoints(vertices)
    local bbox = getBoundingBox(vertices)
    local result = {}
    for i = 1, #vertices, 2 do
        local x = vertices[i]
        local y = vertices[i + 1]
        local newX = x - (bbox.x + bbox.width / 2)
        local newY = y - (bbox.y + bbox.height / 2)
        table.insert(result, newX)
        table.insert(result, newY)
    end
    return result
end

local makeTransformedVertices = mathutils.scalePolygonPoints

local function getTransformedIndex(index, flipX, flipY)
    if flipY == -1 and flipX == 1 then
        local values = { 5, 4, 3, 2, 1, 8, 7, 6 }
        return values[index]
    end
    if flipX == -1 and flipY == 1 then
        local values = { 1, 8, 7, 6, 5, 4, 3, 2 }
        return values[index]
    end
    if flipX == -1 and flipY == -1 then
        local values = { 5, 6, 7, 8, 1, 2, 3, 4 }
        return values[index]
    end
    if flipX == 1 and flipY == 1 then
        local values = { 1, 2, 3, 4, 5, 6, 7, 8 }
        return values[index]
    end
end

local lerp = mathutils.clampedLerp

local function extractNeckIndex(name)
    local index = string.match(name, "^neck(%d+)$")
    return index and tonumber(index) or nil
end

local function extractTorsoIndex(name)
    local index = string.match(name, "^torso(%d+)$")
    return index and tonumber(index) or nil
end
local function extractNoseIndex(name)
    local index = string.match(name, "^nose(%d+)$")
    return index and tonumber(index) or nil
end
local function getParentAndChildrenFromPartName(partName, guy)
    local creation      = guy.dna.creation
    local neckSegments  = creation.neckSegments or 0
    local torsoSegments = creation.torsoSegments or 1
    local noseSegments  = creation.noseSegments or 0


    local highestTorso = 'torso' .. torsoSegments
    local lowestTorso  = 'torso1'

    local map          = {

        head = { p = (neckSegments > 0) and ('neck' .. neckSegments) or highestTorso, c = { 'lear', 'rear' } },
        lear = { p = 'head' },
        rear = { p = 'head' },
        luarm = { p = highestTorso, c = 'llarm' },
        llarm = { p = 'luarm', c = 'lhand' },
        lhand = { p = 'llarm' },
        ruarm = { p = highestTorso, c = 'rlarm' },
        rlarm = { p = 'ruarm', c = 'rhand' },
        rhand = { p = 'rlarm' },
        luleg = { p = lowestTorso, c = 'llleg' },
        llleg = { p = 'luleg', c = 'lfoot' },
        lfoot = { p = 'llleg' },
        ruleg = { p = lowestTorso, c = 'rlleg' },
        rlleg = { p = 'ruleg', c = 'rfoot' },
        rfoot = { p = 'rlleg' },

    }

    local neckIndex    = extractNeckIndex(partName)
    if neckIndex then
        if neckIndex == 1 then
            map[partName] = { p = highestTorso, c = (neckIndex == neckSegments) and 'head' or 'neck2' }
        else
            map[partName] = {
                p = 'neck' .. (neckIndex - 1),
                c = (neckIndex == neckSegments) and 'head' or
                    'neck' .. neckIndex + 1
            }
        end
    end

    local torsoIndex = extractTorsoIndex(partName)

    if torsoIndex then
        if torsoIndex then
            local children = {}
            -- Middle segments connect only to the next torso segment
            if torsoIndex < torsoSegments then
                table.insert(children, 'torso' .. (torsoIndex + 1))
            end

            -- Highest segment connects to arms and neck/head
            if torsoIndex == torsoSegments then
                if not creation.isPotatoHead then
                    table.insert(children, (neckSegments > 0) and 'neck1' or 'head')
                end
                table.insert(children, 'luarm')
                table.insert(children, 'ruarm')
                if creation.isPotatoHead then -- Potato ears attach to highest torso
                    table.insert(children, 'lear')
                    table.insert(children, 'rear')
                    if noseSegments then
                        table.insert(children, 'nose1')
                    end
                end
            end
            -- Lowest segment connects to legs
            if torsoIndex == 1 then
                table.insert(children, 'luleg')
                table.insert(children, 'ruleg')
            end
            if torsoIndex == 1 then
                map[partName] = { c = children } -- Torso1 has no parent
            else
                map[partName] = { p = 'torso' .. (torsoIndex - 1), c = children }
            end
        end
    end


    -- Nose: parent is head (or highest torso in potato mode)
    local noseIndex = extractNoseIndex(partName)
    if noseIndex then
        local parentName
        if noseIndex == 1 then
            parentName = creation.isPotatoHead and highestTorso or 'head'
        else
            parentName = 'nose' .. (noseIndex - 1)
        end

        local children
        if noseIndex < noseSegments then
            children = 'nose' .. (noseIndex + 1)
        end
        --  logger:info('NOSE', parentName)
        map[partName] = { p = parentName, c = children }
    end


    -- Overrides for special cases
    -- Head connects directly to highest torso if no neck

    if not creation.isPotatoHead then
        local headChildren = { 'lear', 'rear' }
        if noseSegments > 0 then
            table.insert(headChildren, 'nose1')
        end
        map.head = {
            p = (neckSegments > 0) and ('neck' .. neckSegments) or highestTorso,
            c = headChildren
        }
    end

    if partName == 'head' and neckSegments == 0 then
        local headChildren = { 'lear', 'rear' }
        if noseSegments > 0 then
            table.insert(headChildren, 'nose1')
        end

        -- todo nose
        --   logger:info('626')
        map['head'].c = headChildren
    end

    -- If Potato Head, ears parent is highest torso (head doesn't exist as parent)
    if creation.isPotatoHead then
        map['lear'] = { p = highestTorso }
        map['rear'] = { p = highestTorso }

        --logger:info('634')
        -- todo nose
        -- Remove head connection if it exists from map
        map['head'] = nil -- No head part in potato mode
    end

    -- If only one torso segment, it has all children directly
    if torsoSegments == 1 and partName == 'torso1' then
        local children
        if creation.isPotatoHead then
            children = { 'luarm', 'ruarm', 'luleg', 'ruleg', 'lear', 'rear' }
            if noseSegments > 0 then
                table.insert(children, 'nose1')
            end
        else
            children = { (neckSegments > 0) and 'neck1' or 'head', 'luarm', 'ruarm', 'luleg', 'ruleg' }
        end

        map[partName] = { c = children }
    end

    local result = map[partName]

    return result or {} -- Return empty table if partName not found
end

local sign = mathutils.sign

local function getOwnOffset(partName, guy)
    local parts = guy.dna.parts
    local scale = guy.scale

    -- upward
    if extractNeckIndex(partName) then
        return 0, (-parts[partName].dims.h / 2) * scale
    end
    if extractTorsoIndex(partName) then
        if parts[partName].shape == ST.SHAPE8 then
            --  print(parts[partName].shape8URL)
            local raw = shape8Dict[parts[partName].shape8URL].vertices
            local vertices = makeTransformedVertices(raw, parts[partName].dims.sx or 1, parts[partName].dims.sy or 1)
            local topIndex = getTransformedIndex(1, sign(parts[partName].dims.sx), sign(parts[partName].dims.sy))
            local bottomIndex = getTransformedIndex(5, sign(parts[partName].dims.sx), sign(parts[partName].dims.sy))
            return -vertices[(bottomIndex * 2) - 1] * scale, vertices[(topIndex * 2)] * scale
        else
            return 0, -parts[partName].dims.h / 2 * scale
        end
    end

    if partName == 'head' then
        if parts[partName].shape == ST.SHAPE8 then
            local raw = shape8Dict[parts[partName].shape8URL].vertices
            local vertices = makeTransformedVertices(raw, parts[partName].dims.sx or 1, parts[partName].dims.sy or 1)
            local topIndex = getTransformedIndex(1, sign(parts[partName].dims.sx), sign(parts[partName].dims.sy))
            local bottomIndex = getTransformedIndex(5, sign(parts[partName].dims.sx), sign(parts[partName].dims.sy))
            return -vertices[(bottomIndex * 2) - 1] * scale, vertices[(topIndex * 2)] * scale
        else
            return 0, -parts[partName].dims.h / 2 * scale
        end
    end
    -- if partName == 'lear' then
    --     return 0, -parts.lear.dims.h / 2
    -- end
    -- if partName == 'rear' then
    --     return 0, -parts.rear.dims.h / 2
    -- end
    if partName == 'lear' or partName == 'rear' then
        local part = parts[partName]
        if part.shape == ST.SHAPE8 then
            local raw = shape8Dict[part.shape8URL].vertices
            local rr = recenterPoints(raw)
            local vertices = makeTransformedVertices(rr, part.dims.sx or 1, part.dims.sy or 1)
            local index = getTransformedIndex(5, sign(part.dims.sx), sign(part.dims.sy)) -- or pick 5 or another

            --local footOffset = 0
            return -vertices[(index * 2) - 1] * scale, -vertices[(index * 2)] * scale
        else
            return 0, (-part.dims.h / 2) * scale
        end
    end
    -- downward
    if partName == 'luleg' then
        return 0, (parts.luleg.dims.h / 2) * scale
    end
    if partName == 'ruleg' then
        return 0, (parts.ruleg.dims.h / 2) * scale
    end
    if partName == 'llleg' then
        return 0, (parts.llleg.dims.h / 2) * scale
    end
    if partName == 'lfoot' or partName == 'rfoot' then
        local part = parts[partName]
        if part.shape == ST.SHAPE8 then
            local raw = shape8Dict[part.shape8URL].vertices
            local rr = recenterPoints(raw)
            local vertices = makeTransformedVertices(rr, part.dims.sx or 1, part.dims.sy or 1)
            local index = getTransformedIndex(1, sign(part.dims.sx), sign(part.dims.sy)) -- or pick 5 or another

            --local footOffset = 0
            return -vertices[(index * 2) - 1] * scale, -vertices[(index * 2)] * scale
        else
            return 0, (part.dims.h / 2) * scale
        end
    end
    if partName == 'rlleg' then
        return 0, (parts.rlleg.dims.h / 2) * scale
    end

    if partName == 'luarm' then
        return 0, (parts.luarm.dims.h / 2) * scale
    end
    if partName == 'ruarm' then
        return 0, (parts.ruarm.dims.h / 2) * scale
    end
    if partName == 'rhand' or partName == 'lhand' then
        local part = parts[partName]
        if part.shape == ST.SHAPE8 then
            local raw = shape8Dict[part.shape8URL].vertices
            local rr = recenterPoints(raw)
            local vertices = makeTransformedVertices(rr, part.dims.sx or 1, part.dims.sy or 1)
            local index = getTransformedIndex(1, sign(part.dims.sx), sign(part.dims.sy)) -- or pick 5 or another

            --local handOffset = 50
            return -vertices[(index * 2) - 1] * scale, -vertices[(index * 2)] * scale
        else
            return 0, (part.dims.h / 2) * scale
        end
    end
    if partName == 'llarm' then
        return 0, (parts.llarm.dims.h / 2) * scale
    end
    if partName == 'rlarm' then
        return 0, (parts.rlarm.dims.h / 2) * scale
    end
    if extractNoseIndex(partName) then
        local part = guy.dna.parts[partName]

        if part.shape == ST.SHAPE8 then
            local raw = shape8Dict[part.shape8URL].vertices
            local rr = recenterPoints(raw)
            local vertices = makeTransformedVertices(rr, part.dims.sx or 1, part.dims.sy or 1)
            local index = getTransformedIndex(1, sign(part.dims.sx), sign(part.dims.sy)) -- or pick 5 or another

            --local handOffset = 50
            return -vertices[(index * 2) - 1] * scale, -vertices[(index * 2)] * scale
        else
            --print('wowzers!')
            return 0, (part.dims.h / 2) * scale
        end

        -- push outward along local +Y (your code rotates this into parent space)
        -- return 0, (part.dims.h / 2) * guy.scale
    end
    return 0, 0
end

local function getOffsetFromParent(partName, guy)
    local parts         = guy.dna.parts
    local creation      = guy.dna.creation
    local positioners   = guy.dna.positioners
    getParentAndChildrenFromPartName(partName, guy)
    -- Define the name of the highest torso segment
    local torsoSegments = creation.torsoSegments or 1
    local highestTorso  = 'torso' .. torsoSegments
    -- Define the name of the lowest torso segment (always torso1)
    local lowestTorso   = 'torso1'
    local scale         = guy.scale




    local function getTorsoPart8FromSpecificTorso(index, torsoIndex)
        local torso = 'torso' .. torsoIndex
        local raw = shape8Dict[parts[torso].shape8URL].vertices
        local vertices = makeTransformedVertices(raw, parts[torso].dims.sx or 1, parts[torso].dims.sy or 1)
        local newIndex = getTransformedIndex(index, sign(parts[torso].dims.sx), sign(parts[torso].dims.sy))
        return vertices[(newIndex * 2) - 1] * scale, vertices[(newIndex * 2)] * scale
    end
    local function getNosePart8FromSpecificTorso(index, noseIndex)
        local torso = 'nose' .. noseIndex
        local raw = shape8Dict[parts[torso].shape8URL].vertices
        local vertices = makeTransformedVertices(raw, parts[torso].dims.sx or 1, parts[torso].dims.sy or 1)
        local newIndex = getTransformedIndex(index, sign(parts[torso].dims.sx), sign(parts[torso].dims.sy))
        return vertices[(newIndex * 2) - 1] * scale, vertices[(newIndex * 2)] * scale
    end

    local function getTorsoPart8FromHighest(index)
        return getTorsoPart8FromSpecificTorso(index, torsoSegments)
    end

    local function getTorsoPart8FromLowest(index)
        return getTorsoPart8FromSpecificTorso(index, 1)
    end

    local function hasTorso8()
        if parts[highestTorso].shape == ST.SHAPE8 then
            return true
        end
        return false
    end

    local function hasNose8()
        if parts['nose1'].shape == ST.SHAPE8 then
            return true
        end
        return false
    end


    local function hasHead8()
        if parts['head'].shape == ST.SHAPE8 then
            return true
        end
        return false
    end

    local function getHeadPart8(index)
        local raw = shape8Dict[parts['head'].shape8URL].vertices
        local vertices = makeTransformedVertices(raw, parts['head'].dims.sx or 1, parts['head'].dims.sy or 1)
        local newIndex = getTransformedIndex(index, sign(parts['head'].dims.sx), sign(parts['head'].dims.sy))

        return vertices[(newIndex * 2) - 1] * scale, vertices[(newIndex * 2)] * scale
    end

    local noseT = (positioners and positioners.nose and positioners.nose.t) or 0.35 -- 0=top, 1=bottom

    local function getMidlineLerpOnHead(t)
        local ax, ay = getHeadPart8(1) -- top center
        local bx, by = getHeadPart8(5) -- bottom center
        return lerp(ax, bx, t), lerp(ay, by, t)
    end
    local function getMidlineLerpOnTopTorso(t)
        local ax, ay = getTorsoPart8FromHighest(1)
        local bx, by = getTorsoPart8FromHighest(5)
        return lerp(ax, bx, t), lerp(ay, by, t)
    end


    local noseIndex = extractNoseIndex(partName)
    if noseIndex then
        if noseIndex == 1 then
            if creation.isPotatoHead then
                if hasTorso8() then
                    local rx, ry = getMidlineLerpOnTopTorso(noseT)
                    return rx, ry
                else
                    return 0, (-parts[highestTorso].dims.h) * scale
                end
            else
                if hasHead8() then
                    local rx, ry = getMidlineLerpOnHead(noseT)
                    return rx, ry
                else
                    return 0, (-parts.head.dims.h) * scale
                end
            end
        else
            if hasNose8() then
                return getNosePart8FromSpecificTorso(5, noseIndex)
            else
                return 0, (parts[partName].dims.h / 2) * scale
            end
            -- parent is previous nose segment; anchor at its tip (+Y half height)
            --local parentName = 'nose' .. (noseIndex - 1)
            --local pd = parts[parentName].dims
            --return 0, (pd.h) * scale
        end
    end



    if extractNeckIndex(partName) then
        local index = extractNeckIndex(partName)
        if index == 1 then
            if hasTorso8() then
                return getTorsoPart8FromHighest(1)
            else
                return 0, (-parts[highestTorso].dims.h / 2) * scale
            end
        else
            return 0, (-parts['neck' .. (index - 1)].dims.h / 2) * scale
        end
    elseif extractTorsoIndex(partName) then
        local index = extractTorsoIndex(partName)
        if index == 1 then
            return 0, 0
        else
            if hasTorso8() then
                return getTorsoPart8FromSpecificTorso(1, index - 1)
            else
                return 0, (-parts['torso' .. (index - 1)].dims.h / 2) * scale
            end
        end
        -- THESE SIMPLE ONES BELOW WORK BECAUSE LEGS AND ARMS ARE ALWAYS SIMPLE RECTANGLES
    elseif partName == 'llarm' then
        return 0, (parts.luarm.dims.h / 2) * scale
    elseif partName == 'rlarm' then
        return 0, (parts.ruarm.dims.h / 2) * scale
    elseif partName == 'llleg' then
        return 0, (parts.luleg.dims.h / 2) * scale
    elseif partName == 'lfoot' then
        return 0, (parts.llleg.dims.h / 2) * scale
    elseif partName == 'rlleg' then
        return 0, (parts.ruleg.dims.h / 2) * scale
    elseif partName == 'rfoot' then
        return 0, (parts.rlleg.dims.h / 2) * scale
    elseif partName == 'rhand' then
        return 0, (parts.rlarm.dims.h / 2) * scale
    elseif partName == 'lhand' then
        return 0, (parts.llarm.dims.h / 2) * scale
    elseif partName == 'luarm' then
        if hasTorso8() then
            if creation.isPotatoHead then
                return getTorsoPart8FromHighest(7)
            else
                return getTorsoPart8FromHighest(8)
            end
        else
            return (-parts[highestTorso].dims.w / 2) * scale, (-parts[highestTorso].dims.h / 2) * scale
        end
    elseif partName == 'ruarm' then
        if hasTorso8() then
            if creation.isPotatoHead then
                return getTorsoPart8FromHighest(3)
            else
                return getTorsoPart8FromHighest(2)
            end
        else
            return (parts[highestTorso].dims.w / 2) * scale, (-parts[highestTorso].dims.h / 2) * scale
        end
    elseif partName == 'luleg' then
        local t = 0.5 --positioners.leg.x
        if hasTorso8() then
            local ax, ay = getTorsoPart8FromLowest(6)
            local bx, by = getTorsoPart8FromLowest(5)
            local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
            return rx, ry
        else
            return (-parts[lowestTorso].dims.w / 2) * (1 - t) * scale, (parts[lowestTorso].dims.h / 2) * scale
        end
    elseif partName == 'ruleg' then
        local t = 0.5 -- positioners.leg.x

        if hasTorso8() then
            local ax, ay = getTorsoPart8FromLowest(4)
            local bx, by = getTorsoPart8FromLowest(5)
            local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
            return rx, ry
        else
            return (parts[lowestTorso].dims.w / 2) * (1 - t) * scale, (parts[lowestTorso].dims.h / 2) * scale
        end
    elseif partName == 'lear' then
        if creation.isPotatoHead then
            if hasTorso8() then
                local t = 0.5
                local ax, ay = getTorsoPart8FromHighest(8)
                local bx, by = getTorsoPart8FromHighest(7)
                local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
                return rx * scale, ry * scale
            else
                return (-parts[highestTorso].dims.w / 2) * scale, (-parts[highestTorso].dims.h / 2) * scale
            end
        else
            if hasHead8() then
                local t = 0.5
                local ax, ay = getHeadPart8(7)
                local bx, by = getHeadPart8(8)
                local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
                return rx, ry
            else
                return (-parts.head.dims.w / 2) * scale, (-parts.head.dims.h / 2) * scale
            end
        end
    elseif partName == 'rear' then
        if creation.isPotatoHead then
            if hasTorso8() then
                local t = 0.5
                local ax, ay = getTorsoPart8FromHighest(2)
                local bx, by = getTorsoPart8FromHighest(3)
                local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
                return rx, ry
            else
                return parts[highestTorso].dims.w / 2, -parts[highestTorso].dims.h / 2
            end
        else
            if hasHead8() then
                local t = 0.5
                local ax, ay = getHeadPart8(2)
                local bx, by = getHeadPart8(3)
                local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
                return rx, ry
            else
                return parts.head.dims.w / 2, -parts.head.dims.h / 2
            end
        end
    elseif (partName == 'head') then
        if creation.neckSegments == 0 then
            if hasTorso8() then
                return getTorsoPart8FromHighest(1)
            else
                return 0, (-parts[highestTorso].dims.h / 2) * scale
            end
        else
            local last = 'neck' .. creation.neckSegments
            return 0, -parts[last].dims.h / 2
        end
    else
        return 0, 0
    end
end

local function getAngleOffset(partName, guy)
    local parts = guy.dna.parts
    if partName == 'lfoot' then
        return math.pi / 2
    elseif partName == 'rfoot' then
        return -math.pi / 2
    elseif partName == 'lear' then
        return parts.lear.stanceAngle
    elseif partName == 'rear' then
        return parts.rear.stanceAngle
    elseif extractNoseIndex(partName) then
        return 0 -- or small per-segment curve like: (i-1)*0.08
    else
        return 0
    end
end


local function makePart(partName, instance, settings)
    local values = getParentAndChildrenFromPartName(partName, instance)
    local parent = values.p
    local prevA = 0

    if parent then
        if instance.parts[parent] then
            prevA = instance.parts[parent].body:getAngle()
            local parentOffsetX, parentOffsetY = getOffsetFromParent(partName, instance)
            local px, py = instance.parts[parent].body:getWorldPoint(parentOffsetX, parentOffsetY)
            settings.x = px
            settings.y = py
        end
    end

    local ownOffsetX, ownOffsetY = getOwnOffset(partName, instance)
    local xangle = getAngleOffset(partName, instance)

    -- Rotate own offset into parent space
    local rotatedOwnX, rotatedOwnY = mathutils.rotatePoint(ownOffsetX, ownOffsetY, 0, 0, prevA + xangle)

    settings.x = settings.x + rotatedOwnX
    settings.y = settings.y + rotatedOwnY

    local thing = ObjectManager.addThing(settings.shapeType, settings)

    if thing then
        thing.body:setAngle(prevA + xangle)
        thing.mipoId = instance.id
        thing.mipoPartName = partName

        if extractNeckIndex(partName) then
            thing.body:setAngularDamping(.1)
            thing.body:setLinearDamping(.1)
        end
        if extractTorsoIndex(partName) then
            thing.body:setAngularDamping(.1)
            thing.body:setLinearDamping(.1)
            local f = thing.body:getFixtures()
            for i = 1, #f do
                f[i]:setDensity(1)
            end
        end

        instance.parts[partName] = thing
    end

    if parent then
        local partA_thing = instance.parts[parent]
        local partB_thing = instance.parts[partName]

        if (partA_thing and partB_thing) then
            local jointData = instance.dna.parts[partName].j
            local jointCreationData = {
                body1 = partA_thing.body,
                body2 = partB_thing.body,
                jointType = jointData.type,
                collideConnected = false, -- Default to false
                id = uuid.generateID(),
                offsetA = { x = 0, y = 0 },
                offsetB = { x = 0, y = 0 },
            }
            -- logger:info('joint:', parent, partName)
            -- todo we dont really need this yet...
            instance.joints[parent .. '->' .. partName] = jointCreationData.id

            local offX, offY = getOffsetFromParent(partName, instance)
            jointCreationData.offsetA.x = jointCreationData.offsetA.x + offX
            jointCreationData.offsetA.y = jointCreationData.offsetA.y + offY
            local joint = Joints.createJoint(jointCreationData)
            local limits = jointData.limits

            if joint and limits and limits.low and limits.up then
                joint:setLimits(limits.low, limits.up)
                joint:setLimitsEnabled(true)
            end
        end
    end
end

local function getPoseCache(instance)
    local poseCache = {}
    for partName, part in pairs(instance.parts) do
        local body = part.body

        local groupIndex = body:getFixtures()[1]:getGroupIndex()
        poseCache[partName] = {
            pos = { body:getPosition() },
            angle = body:getAngle(),
            linearVelocity = { body:getLinearVelocity() },
            angularVelocity = body:getAngularVelocity(),
            groupIndex = groupIndex or 0
        }
    end
    return poseCache
end
local function applyPoseCache(instance, poseCache)
    -- using the cache
    for partName, pose in pairs(poseCache) do
        if instance.parts[partName] and pose then
            local body = instance.parts[partName].body
            --body:setPosition(pose.pos[1], pose.pos[2])
            body:setAngle(pose.angle)
            body:setLinearVelocity(pose.linearVelocity[1], pose.linearVelocity[2])
            body:setAngularVelocity(pose.angularVelocity)

            local bodyFixtures = body:getFixtures()
            for j = 1, #bodyFixtures do
                bodyFixtures[j]:setGroupIndex(pose.groupIndex)
            end
        end
    end
end

local function fixDrift(positionTorso, instance)
    if positionTorso then
        local newPosX, newPosY = instance.parts['torso1'].body:getPosition()
        local dx = positionTorso[1] - newPosX
        local dy = positionTorso[2] - newPosY

        for _, part in pairs(instance.parts) do
            local bx, by = part.body:getPosition()
            part.body:setPosition(bx + dx, by + dy)
        end
    end
end

local function updateSinglePart(partName, data, instance)
    local partData = instance.dna.parts[partName]
    if not partData then return end


    for k, v in pairs(data) do
        if (partData.dims[k]) then
            partData.dims[k] = v
        elseif partData[k] then
            partData[k] = v
        end
    end

    local oldPosX, oldPosY = 0, 0
    local oldAngle = 0

    -- Remove old body
    local wasSelected = false
    if instance.parts[partName] then
        local oldBody = instance.parts[partName].body
        oldPosX, oldPosY = oldBody:getPosition()
        oldAngle = oldBody:getAngle()
        wasSelected = (state.selection.selectedObj and state.selection.selectedObj.body == oldBody)
        ObjectManager.destroyBody(oldBody)
        instance.parts[partName] = nil
    end

    local scale = instance.scale or 1
    -- Recreate the part
    local settings = {
        x = oldPosX,
        y = oldPosY,
        bodyType = BT.DYNAMIC,
        shapeType = partData.shape,
        shape8URL = partData.shape8URL,
        label = partName,
        density = partData.density or 1,
        radius = (partData.dims.r or 0) * scale,
        width = (partData.dims.w or 0) * scale,
        width2 = (partData.dims.w2 or 0) * scale,
        width3 = (partData.dims.w3 or 0) * scale,
        height = (partData.dims.h or 0) * scale,
        height2 = (partData.dims.h2 or 0) * scale,
        height3 = (partData.dims.h3 or 0) * scale,
        height4 = (partData.dims.h4 or 0) * scale,
    }

    if partData.shape8URL and shape8Dict[partData.shape8URL] then
        local raw = shape8Dict[partData.shape8URL].vertices
        settings.vertices = makeTransformedVertices(
            raw, (partData.dims.sx or 1) * scale, (partData.dims.sy or 1) * scale)
    end

    local children = getParentAndChildrenFromPartName(partName, instance).c or {}
    if type(children) == 'string' then
        children = { children }
    end
    --logger:info('children :', partName, inspect(children))
    makePart(partName, instance, settings)

    -- after making a part set it to its angle so the children will be using that angle in their calculations.
    instance.parts[partName].body:setAngle(oldAngle)

    -- Re-select the new body if the old one was selected
    if wasSelected and instance.parts[partName] then
        local ud = instance.parts[partName].body:getUserData()
        if ud and ud.thing then
            state.selection.selectedObj = ud.thing
        end
    end

    for _, childName in ipairs(children) do
        local childData = instance.dna.parts[childName]
        if childData then
            updateSinglePart(childName, {}, instance) -- trigger rebuild
        end
    end
end

-- update part
function lib.updatePart(partName, data, instance)
    local positionTorso = nil
    if partName == 'torso1' then
        positionTorso = { instance.parts['torso1'].body:getPosition() }
    end

    -- filling the cache
    local poseCache = getPoseCache(instance)
    updateSinglePart(partName, data, instance)
    applyPoseCache(instance, poseCache)
    if positionTorso then fixDrift(positionTorso, instance) end
end

-- given an instance with dna and a new creation, this function is made to change
-- a creation of a humanoid during runtime.
-- its alos used by initially creating a character.
function lib.rebuildFromCreation(instance, newCreation)
    -- Step 1: Update the creation settings
    for k, v in pairs(newCreation) do
        instance.dna.creation[k] = v
    end

    local torsoX, torsoY = instance.parts['torso1'].body:getPosition()
    local torsoAngle = instance.parts['torso1'].body:getAngle()

    local poseCache = getPoseCache(instance)

    local positionTorso = { instance.parts['torso1'].body:getPosition() }

    -- Track which part was selected so we can re-select after rebuild
    local selectedPartName = nil
    local selectedObj = state.selection.selectedObj
    if selectedObj and selectedObj.body and not selectedObj.body:isDestroyed() then
        for pName, part in pairs(instance.parts) do
            if part == selectedObj then
                selectedPartName = pName
                break
            end
        end
    end

    -- Step 2: Remove all existing parts
    for _, part in pairs(instance.parts) do
        ObjectManager.destroyBody(part.body)
    end

    instance.parts = {}
    instance.joints = {}
    instance.textures = {}
    --print(instance.scale)
    lib.createCharacterFromExistingDNA(instance, torsoX, torsoY, torsoAngle)

    applyPoseCache(instance, poseCache)
    if positionTorso then fixDrift(positionTorso, instance) end

    -- Re-select the same part (or torso1 if the old part no longer exists)
    if selectedPartName then
        local newPart = instance.parts[selectedPartName] or instance.parts['torso1']
        if newPart then
            state.selection.selectedObj = newPart
        end
    end
end

function lib.addTexturesFromInstance2(instance)
    local scale = instance.scale
    for k, v in pairs(instance.dna.parts) do
        if v.appearance then
            --logger:info(k .. ' has appearance')
            local relevant = instance.parts[k]
            if (relevant) then
                --logger:info('relevant real thing found ' .. k)
                --logger:inspect(v.appearance)
                --
                --
                -- maybe i can jst remove all texture fixtures from the body right now?
                -- and then reattahc new ones below.

                local allFixtures = relevant.body:getFixtures()
                for fi = #allFixtures, 1, -1 do -- backwards to safely remove
                    local f = allFixtures[fi]
                    local ud = f:getUserData()
                    if ud then
                        if (subtypes.is(ud, subtypes.CONNECTED_TEXTURE)
                                or subtypes.is(ud, subtypes.TEXFIXTURE)
                                or subtypes.is(ud, subtypes.TRACE_VERTICES)
                                or subtypes.is(ud, subtypes.DECAL)) then
                            fixtures.destroyFixture(f)
                        end
                    end
                end

                for k2, v2 in pairs(v.appearance) do
                    if k2 == 'skin' then
                        local body = relevant.body


                        local _, _, w, h = getCenterAndDimensions(body)


                        -- WORK IN PROGRESS, this is correct now for feet and hands....
                        local documentSize = nil
                        if v.shape8URL then
                            if shape8Dict[v.shape8URL] then
                                if shape8Dict[v.shape8URL].dimensions then
                                    getBoundingBox(shape8Dict[v.shape8URL].vertices)
                                    -- logger:inspect(bbox)
                                    documentSize = {}
                                    documentSize.w = shape8Dict[v.shape8URL].dimensions[1] * math.abs(v.dims.sx)
                                    documentSize.h = shape8Dict[v.shape8URL].dimensions[2] * math.abs(v.dims.sy)
                                end
                            end
                        end

                        local growfactor = 1.1

                        local fixture
                        if (documentSize) then
                            fixture = fixtures.createSFixture(body, 0, 0,
                                subtypes.TEXFIXTURE,
                                {
                                    width = documentSize.w * growfactor * scale,
                                    height = documentSize.h * growfactor *
                                        scale
                                })
                        else
                            fixture = fixtures.createSFixture(body, 0, 0, subtypes.TEXFIXTURE,
                                { width = w * growfactor, height = h * growfactor })
                        end
                        local ud = fixture:getUserData()
                        ud.extra.OMP = true --it.OMP
                        ud.extra.dirty = true
                        ud.extra.main = utils.deepCopy(v2.main)
                        ud.extra.main.bgURL = v.shape8URL
                        ud.extra.main.fgURL = v.shape8URL:gsub('.png', '-mask.png')
                        ud.extra.zOffset = v2.zOffset or 0
                        if v.dims.sy ~= nil and v.dims.sy < 0 then
                            ud.extra.main.fy = -1
                        end
                        if v.dims.sx ~= nil and v.dims.sx < 0 then
                            ud.extra.main.fx = -1
                        end

                        if v2.patch1 then
                            ud.extra.patch1 = utils.deepCopy(v2.patch1)
                        end
                        if v2.patch2 then
                            ud.extra.patch2 = utils.deepCopy(v2.patch2)
                        end
                        if v2.patch3 then
                            ud.extra.patch3 = utils.deepCopy(v2.patch3)
                        end
                    elseif k2 == 'bodyhair' then
                        local body = relevant.body
                        local _, _, w, h = getCenterAndDimensions(body)
                        local growfactor = 1.2
                        local fixture = fixtures.createSFixture(body, 0, 0, subtypes.TEXFIXTURE,
                            { width = w * growfactor, height = h * growfactor })
                        local ud = fixture:getUserData()
                        ud.extra.OMP = false --it.OMP
                        ud.extra.zOffset = 40
                        ud.extra.dirty = true
                        ud.extra.main = utils.deepCopy(v2.main)

                        local raw = shape8Dict[v.shape8URL].vertices
                        --  local growfactor = 1.1
                        local vertices = makeTransformedVertices(raw, (v.dims.sx or 1) * growfactor * scale,
                            (v.dims.sy or 1) * growfactor * scale)
                        --   logger:inspect(vertices)
                        local newVertices = cyclicShift(vertices, 2)
                        if v.dims.sy < 0 then
                            newVertices = cyclicShift(newVertices, 8)
                        end


                        ud.extra.vertices = newVertices
                        ud.extra.vertexCount = #vertices / 2
                    elseif k2 == 'connected-skin' or k2 == 'connected-hair' then
                        local body          = relevant.body

                        -- depending on the start and end node. build the jointlabels
                        local torsoSegments = instance.dna.creation.torsoSegments or 1
                        local noseSegments  = instance.dna.creation.noseSegments or 0
                        local jointLabels   = {}

                        local fixture       = fixtures.createSFixture(body, 0, 0, subtypes.CONNECTED_TEXTURE,
                            { radius = 30 * scale })

                        local ud            = fixture:getUserData()

                        ud.extra            = {
                            attachTo = k,
                            OMP = true,
                            dirty = true,
                            main = utils.deepCopy(v2.main),
                            zOffset = v2.zOffset or 0,
                            nodes = {},
                            growExtra = 20 * scale,
                        }

                        -- wmul controls the rendered width of the connected texture.
                        -- Use DNA value if set, otherwise default to instance scale.
                        ud.extra.main.wmul  = v2.main.wmul or scale
                        if k:find('uleg') then
                            --print('this is an upper-leg, connect to torso1')
                            if k == 'luleg' then
                                jointLabels = { "torso1->luleg", "luleg->llleg", "llleg->lfoot" }
                            elseif k == 'ruleg' then
                                jointLabels = { "torso1->ruleg", "ruleg->rlleg", "rlleg->rfoot" }
                            end
                        end
                        if k:find('uarm') then
                            local top = 'torso' .. torsoSegments

                            --print('this is an upper-leg, connect to torso1')
                            if k == 'luarm' then
                                jointLabels = { top .. "->luarm", "luarm->llarm", "llarm->lhand" }
                            elseif k == 'ruarm' then
                                jointLabels = { top .. "->ruarm", "ruarm->rlarm", "rlarm->rhand" }
                            end
                        end
                        -- we only do neck stuff from the top torso to the head. (other torso segments are ignored)
                        if k == ('torso' .. torsoSegments) and v2.endNode == 'head' then
                            local neckSegments = instance.dna.creation.neckSegments or 0
                            local previous = 'torso' .. torsoSegments

                            for i = 1, neckSegments do
                                local current = 'neck' .. i
                                table.insert(jointLabels, previous .. '->' .. current)
                                previous = current
                            end
                            -- Final connection to head
                            table.insert(jointLabels, previous .. '->head')
                            --logger:inspect(jointLabels)

                            --print('this is about texturing the neck')
                        end

                        if k == 'nose1' and noseSegments > 0 then
                            local startParent = instance.dna.creation.isPotatoHead and ('torso' .. torsoSegments) or
                                'head'
                            table.insert(jointLabels, startParent .. '->nose1')
                            for i = 1, noseSegments - 1 do
                                table.insert(jointLabels, 'nose' .. i .. '->nose' .. (i + 1))
                            end
                        end

                        for j = 1, #jointLabels do
                            local jointID = jointLabels[j]
                            ud.extra.nodes[j] = { id = instance.joints[jointID], type = NT.JOINT }
                        end
                    elseif k2 == 'haircut' then
                        local rightPlaceForHaircut = false
                        if instance.dna.creation.isPotatoHead and k == 'torso1' then
                            rightPlaceForHaircut = true
                        end
                        if not instance.dna.creation.isPotatoHead and k == 'head' then
                            rightPlaceForHaircut = true
                        end


                        -- if instance.dna.creation.isPotatoHead and k ~= 'torso1' then
                        --     return
                        -- end
                        -- if not instance.dna.creation.isPotatoHead and k ~= 'head' then
                        --     return
                        -- end
                        if rightPlaceForHaircut then
                            local body = relevant.body


                            local fixture = fixtures.createSFixture(body, 0, 0, subtypes.TRACE_VERTICES,
                                { radius = 30, width = 100, height = 100 })
                            local ud = fixture:getUserData()
                            ud.extra.OMP = false --it.OMP
                            ud.extra.zOffset = 40
                            ud.extra.dirty = true
                            ud.extra.main = utils.deepCopy(v2.main)
                            ud.extra.width = (v2.width or 250) * scale
                            ud.extra.startIndex = v2.startIndex
                            ud.extra.endIndex = v2.endIndex

                            if v.dims.sy < 0 then
                                ud.extra.startIndex = v2.startIndex + 4
                                ud.extra.endIndex = v2.endIndex + 4
                            end
                        end
                    elseif k2 == 'face' then
                        -- Face decals (eyes + pupils) go on head (non-potato) or torso1 (potato)
                        local rightPlaceForFace = false
                        if instance.dna.creation.isPotatoHead and k == 'torso1' then
                            rightPlaceForFace = true
                        end
                        if not instance.dna.creation.isPotatoHead and k == 'head' then
                            rightPlaceForFace = true
                        end

                        if rightPlaceForFace and v.shape8URL and shape8Dict[v.shape8URL] then
                            local body = relevant.body
                            local face = v2
                            local eyePos = face.positioners and face.positioners.eye or { x = 0.2, y = 0.5 }

                            -- Get head shape vertices to compute eye positions
                            local raw = shape8Dict[v.shape8URL].vertices
                            local verts = makeTransformedVertices(raw,
                                (v.dims.sx or 1) * scale, (v.dims.sy or 1) * scale)

                            -- 8-vertex polygon: 1=top, 3=right-mid, 5=bottom, 7=left-mid
                            -- Indices are 1-based, pairs of x,y
                            -- Normalize so topY < botY and leftX < rightX even when shape is flipped
                            local topY = math.min(verts[2], verts[10])
                            local botY = math.max(verts[2], verts[10])
                            local leftX = math.min(verts[5], verts[13])
                            local rightX = math.max(verts[5], verts[13])

                            local leftEyeX = lerp(leftX, rightX, 0.5 - eyePos.x)
                            local rightEyeX = lerp(leftX, rightX, 0.5 + eyePos.x)
                            local eyeY = lerp(topY, botY, eyePos.y)

                            -- Compute base eye size from head dimensions
                            local headW = math.abs(rightX - leftX)
                            local headH = math.abs(botY - topY)
                            local baseEyeW = headW * 0.25
                            local baseEyeH = headH * 0.25

                            local eye = face.eye or {}
                            local pupil = face.pupil or {}

                            local eyeW = baseEyeW * (eye.wMul or 1)
                            local eyeH = baseEyeH * (eye.hMul or 1)
                            local pupilW = baseEyeW * (pupil.wMul or 0.5)
                            local pupilH = baseEyeH * (pupil.hMul or 0.5)

                            local eyeBgURL = 'eye' .. (eye.shape or 1) .. '.png'
                            local eyeFgURL = 'eye' .. (eye.shape or 1) .. '-mask.png'
                            local pupilBgURL = 'pupil' .. (pupil.shape or 1) .. '.png'
                            -- Only some pupils have masks
                            local pupilFgURL = ''
                            local pupilMaskPath = 'textures/pupil' .. (pupil.shape or 1) .. '-mask.png'
                            if love.filesystem.getInfo(pupilMaskPath) then
                                pupilFgURL = 'pupil' .. (pupil.shape or 1) .. '-mask.png'
                            end

                            -- Create eye decals (left and right)
                            -- Uses OMP compositing: outline + mask → pre-composited image
                            local eyeZOffset = 50
                            local eyeSides = {
                                { ox = leftEyeX, label = 'leye' },
                                { ox = rightEyeX, label = 'reye' },
                            }
                            for _, side in ipairs(eyeSides) do
                                local f = fixtures.createSFixture(body, 0, 0, subtypes.DECAL, { radius = 10 })
                                local ud = f:getUserData()
                                ud.label = side.label
                                ud.extra.ox = side.ox
                                ud.extra.oy = eyeY
                                ud.extra.w = eyeW
                                ud.extra.h = eyeH
                                ud.extra.zOffset = eyeZOffset
                                ud.extra.OMP = true
                                ud.extra.dirty = true
                                ud.extra.main = {
                                    bgURL = eyeBgURL,
                                    fgURL = eyeFgURL,
                                    pURL = '',
                                    bgHex = eye.bgHex or '000000ff',
                                    fgHex = eye.fgHex or 'ffffffff',
                                    pHex = 'ffffff00',
                                }
                                drawTextured.makeCached(ud.extra.main)
                            end

                            -- Create pupil decals (left and right)
                            -- Pupils with a mask use OMP compositing (2-color).
                            -- Pupils without a mask are single-color (just tinted outline).
                            local hasPupilMask = pupilFgURL ~= ''
                            local pupilZOffset = 51
                            local pupilSides = {
                                { ox = leftEyeX, label = 'lpupil' },
                                { ox = rightEyeX, label = 'rpupil' },
                            }
                            for _, side in ipairs(pupilSides) do
                                local f = fixtures.createSFixture(body, 0, 0, subtypes.DECAL, { radius = 10 })
                                local ud = f:getUserData()
                                ud.label = side.label
                                ud.extra.ox = side.ox
                                ud.extra.oy = eyeY
                                ud.extra.w = pupilW
                                ud.extra.h = pupilH
                                ud.extra.zOffset = pupilZOffset
                                if hasPupilMask then
                                    ud.extra.OMP = true
                                    ud.extra.dirty = true
                                    ud.extra.main = {
                                        bgURL = pupilBgURL,
                                        fgURL = pupilFgURL,
                                        pURL = '',
                                        bgHex = pupil.bgHex or '000000ff',
                                        fgHex = pupil.fgHex or '',
                                        pHex = 'ffffff00',
                                    }
                                    drawTextured.makeCached(ud.extra.main)
                                else
                                    ud.extra.OMP = false
                                    ud.extra.bgURL = pupilBgURL
                                    ud.extra.bgHex = pupil.bgHex or '000000ff'
                                end
                            end

                            -- Create brow decals (left and right)
                            local brow = face.brow or {}
                            local browPos = face.positioners and face.positioners.brow or { y = 0.3 }
                            local browY = lerp(topY, botY, browPos.y)
                            local browW = headW * 0.2 * (brow.wMul or 1)
                            local browH = headH * 0.1 * (brow.hMul or 1)
                            local browURL = 'brow' .. (brow.shape or 1) .. '.png'
                            local browZOffset = 49
                            local browSides = {
                                { ox = leftEyeX, label = 'lbrow', mirror = false },
                                { ox = rightEyeX, label = 'rbrow', mirror = true },
                            }
                            for _, side in ipairs(browSides) do
                                local f = fixtures.createSFixture(body, 0, 0, subtypes.DECAL, { radius = 10 })
                                local ud = f:getUserData()
                                ud.label = side.label
                                ud.extra.ox = side.ox
                                ud.extra.oy = browY
                                ud.extra.w = browW
                                ud.extra.h = browH
                                ud.extra.zOffset = browZOffset
                                ud.extra.browCurve = true
                                ud.extra.browBend = brow.bend or 1
                                ud.extra.browMirror = side.mirror
                                ud.extra.bgURL = browURL
                                ud.extra.bgHex = brow.bgHex or '000000ff'
                            end

                            -- Create nose decal (single, centered)
                            local nose = face.nose or {}
                            local noseShape = nose.shape or 0
                            if noseShape > 0 then
                                local nosePos = face.positioners and face.positioners.nose or { y = 0.35 }
                                local noseY = lerp(topY, botY, nosePos.y)
                                local noseX = (leftX + rightX) / 2
                                local noseW = headW * 0.15 * (nose.wMul or 1)
                                local noseH = headH * 0.15 * (nose.hMul or 1)
                                local noseBgURL = 'nose' .. noseShape .. '.png'
                                local noseMaskPath = 'textures/nose' .. noseShape .. '-mask.png'
                                local noseFgURL = ''
                                if love.filesystem.getInfo(noseMaskPath) then
                                    noseFgURL = 'nose' .. noseShape .. '-mask.png'
                                end
                                local hasNoseMask = noseFgURL ~= ''
                                local noseZOffset = 48

                                local f = fixtures.createSFixture(body, 0, 0, subtypes.DECAL, { radius = 10 })
                                local ud = f:getUserData()
                                ud.label = 'nose'
                                ud.extra.ox = noseX
                                ud.extra.oy = noseY
                                ud.extra.w = noseW
                                ud.extra.h = noseH
                                ud.extra.zOffset = noseZOffset
                                if hasNoseMask then
                                    ud.extra.OMP = true
                                    ud.extra.dirty = true
                                    ud.extra.main = {
                                        bgURL = noseBgURL,
                                        fgURL = noseFgURL,
                                        pURL = '',
                                        bgHex = nose.bgHex or '000000ff',
                                        fgHex = nose.fgHex or 'ffffffff',
                                        pHex = 'ffffff00',
                                    }
                                    drawTextured.makeCached(ud.extra.main)
                                else
                                    ud.extra.OMP = false
                                    ud.extra.bgURL = noseBgURL
                                    ud.extra.bgHex = nose.bgHex or '000000ff'
                                end
                            end

                            -- Create mouth decals (upper lip + lower lip)
                            local mouth = face.mouth or {}
                            local mouthPos = face.positioners and face.positioners.mouth or { y = 0.7 }
                            local mouthY = lerp(topY, botY, mouthPos.y)
                            local mouthX = 0 -- centered on head

                            -- Get the normalized shape points and scale to head
                            local shapeIdx = mouth.shape or 2
                            local mouthShape = mouthShapes.normalized[shapeIdx]
                            if mouthShape then
                                local mwMul = mouth.wMul or 1
                                local mhMul = mouth.hMul or 1
                                -- Scale mouth to ~40% of head width (adjustable via wMul/hMul)
                                local mouthScaleX = (headW * 0.004) * mwMul
                                local mouthScaleY = (headH * 0.004) * mhMul

                                -- Build scaled + offset curve points (16 floats)
                                local curvePoints = {}
                                for ci = 1, 16, 2 do
                                    curvePoints[ci] = mouthShape.points[ci] * mouthScaleX + mouthX
                                    curvePoints[ci + 1] = mouthShape.points[ci + 1] * mouthScaleY + mouthY
                                end

                                local upperLipURL = 'upperlip' .. (mouth.upperLipShape or 1) .. '.png'
                                local upperLipMaskURL = 'upperlip' .. (mouth.upperLipShape or 1) .. '-mask.png'
                                local lowerLipURL = 'lowerlip' .. (mouth.lowerLipShape or 1) .. '.png'
                                local lowerLipMaskURL = 'lowerlip' .. (mouth.lowerLipShape or 1) .. '-mask.png'

                                -- Lower lip decal (draws first, handles stencil interior)
                                local fLower = fixtures.createSFixture(body, 0, 0, subtypes.DECAL, { radius = 10 })
                                local udLower = fLower:getUserData()
                                udLower.label = 'lowerlip'
                                udLower.extra.ox = mouthX
                                udLower.extra.oy = mouthY
                                udLower.extra.zOffset = 52
                                udLower.extra.mouthCurve = 'lower'
                                udLower.extra.curvePoints = curvePoints
                                udLower.extra.lipScale = mouth.lipScale or 0.25
                                udLower.extra.backdropHex = mouth.backdropHex or '330000ff'
                                udLower.extra.OMP = true
                                udLower.extra.dirty = true
                                udLower.extra.main = {
                                    bgURL = lowerLipURL,
                                    fgURL = lowerLipMaskURL,
                                    pURL = '',
                                    bgHex = '000000ff',
                                    fgHex = mouth.lipHex or 'cc5555ff',
                                    pHex = 'ffffff00',
                                }
                                drawTextured.makeCached(udLower.extra.main)

                                -- Upper lip decal (draws on top)
                                local fUpper = fixtures.createSFixture(body, 0, 0, subtypes.DECAL, { radius = 10 })
                                local udUpper = fUpper:getUserData()
                                udUpper.label = 'upperlip'
                                udUpper.extra.ox = mouthX
                                udUpper.extra.oy = mouthY
                                udUpper.extra.zOffset = 53
                                udUpper.extra.mouthCurve = 'upper'
                                udUpper.extra.curvePoints = curvePoints
                                udUpper.extra.lipScale = mouth.lipScale or 0.25
                                udUpper.extra.OMP = true
                                udUpper.extra.dirty = true
                                udUpper.extra.main = {
                                    bgURL = upperLipURL,
                                    fgURL = upperLipMaskURL,
                                    pURL = '',
                                    bgHex = '000000ff',
                                    fgHex = mouth.lipHex or 'cc5555ff',
                                    pHex = 'ffffff00',
                                }
                                drawTextured.makeCached(udUpper.extra.main)
                            end
                        end
                    end
                end
                -- here we do stuff.
                -- i think we should haev some kind of helper function that know depending on
                -- what the body tye is how we will add
                -- sfiuxture or connected fixture etc..
            end
        end
    end
end

function lib.createCharacterFromExistingDNA(instance, x, y, optionalTorsoAngle)
    -- same logic as in createCharacter, but uses `instance.dna` and skips the `deepCopy`
    -- rebuilds the ordered list, generates torso/neck segments, limbs, etc.
    --
    local isPotato = instance.dna.creation.isPotatoHead
    local hasNeck = instance.dna.creation.neckSegments > 0
    local ordered = {}

    local torsoSegments = instance.dna.creation.torsoSegments or 1 -- Default to 1 torso segment
    -- 1. Add Torso Segments
    --logger:info('createCharacterFromExistingDNA', torsoSegments)
    for i = 1, torsoSegments do
        local partName = 'torso' .. i
        table.insert(ordered, partName)
        -- Copy template DNA for this segment if it doesn't exist (it shouldn't)
        if not instance.dna.parts[partName] then
            -- Ensure template exists
            if not instance.dna.parts['torso-segment-template'] then
                error("Missing 'torso-segment-template' in DNA parts")
            end

            instance.dna.parts[partName] = utils.deepCopy(instance.dna.parts['torso-segment-template'])

            -- if we have multiple torso parts i want to remove the data that is about neck.
            -- only the topmost torso may have that data.

            -- if i ~= torsoSegments then
            --     instance.dna.parts[partName].appearance['connected-skin'] = nil
            --     print('removed unneeded nexk texture data from a torso segemnt')
            -- end

            -- Optional: Modify dimensions/properties of specific segments here if needed
            -- e.g., make torso1 wider (pelvis) or torsoN narrower (shoulders)
            --instance.dna.parts[partName].dims.w = i * 100
            --logger:inspect(instance.dna.parts[partName])
            --  instance.dna.parts[partName].dims.w = ((torsoSegments + 1) - i) * 100
        end
    end

    if hasNeck and not isPotato then
        for i = 1, (instance.dna.creation.neckSegments or 2) do
            table.insert(ordered, 'neck' .. i)
            instance.dna.parts['neck' .. i] = utils.deepCopy(instance.dna.parts['neck-segment-template'])
        end
    end
    if not isPotato then
        table.insert(ordered, 'head')
    end


    local noseSegments = instance.dna.creation.noseSegments or 0
    if noseSegments > 0 then
        for i = 1, noseSegments do
            local partName = 'nose' .. i
            table.insert(ordered, partName)

            if not instance.dna.parts[partName] then
                instance.dna.parts[partName] = utils.deepCopy(instance.dna.parts['nose-segment-template'])
            end
        end
    end

    -- Common limbs
    local limbs = {
        'luleg', 'ruleg', 'llleg', 'rlleg', 'lfoot', 'rfoot',
        'luarm', 'ruarm', 'llarm', 'rlarm', 'lhand', 'rhand',
        'lear', 'rear'
    }
    for _, part in ipairs(limbs) do table.insert(ordered, part) end


    for i = 1, #ordered do
        local partName = ordered[i]
        local partData = instance.dna.parts[partName]
        --logger:info(partName, partData.shapeName)
        local settings = {
            x = x,
            y = y,
            bodyType = BT.DYNAMIC,      -- Start as dynamic, will be adjusted later if inactive
            shapeType = partData.shape, -- Use shape defined in template
            shape8URL = partData.shape8URL,
            label = partName,           --partName,           -- Use part name as initial label
            density = partData.density or 1,
            radius = (partData.dims.r or 0) * instance.scale,
            width = (partData.dims.w or 0) * instance.scale,
            width2 = (partData.dims.w2 or 0) * instance.scale,
            width3 = (partData.dims.w3 or 0) * instance.scale,
            height = (partData.dims.h or 0) * instance.scale,
            height2 = (partData.dims.h2 or 0) * instance.scale,
            height3 = (partData.dims.h3 or 0) * instance.scale,
            height4 = (partData.dims.h4 or 0) * instance.scale,

            -- Add other physics properties if needed (friction, restitution?)
        }

        if (partData.shape8URL) then
            if (shape8Dict[partData.shape8URL]) then
                local raw = shape8Dict[partData.shape8URL].vertices
                settings.vertices = makeTransformedVertices(raw, (partData.dims.sx or 1) * instance.scale,
                    (partData.dims.sy or 1) * instance.scale)
            end
        end
        --logger:info('getting offset for ', partName)



        makePart(partName, instance, settings)
        if optionalTorsoAngle and partName == 'torso1' then
            instance.parts['torso1'].body:setAngle(optionalTorsoAngle)
        end
    end


    -- here we will build up the sfixtures we need.
    --logger:info('calling defaultSetupTextures')


    lib.addTexturesFromInstance2(instance)
    --logger:info('calling addTextureFixturesFromInstance')
    mipoRegistry.register(instance)
    return instance
end

function lib.createCharacterFromJustDNA(mydna, x, y, scale)
    local instance = {
        id = uuid.generateID(),
        --templateName = template,
        dna = utils.deepCopy(mydna), -- Copy template data for potential instance modification
        parts = {},                  -- { [partName] = thingObject, ... }
        joints = {},                 -- unused...{ [connectionName] = jointObject, ... }
        --appearanceValues = {},     -- Will hold visual overrides (implement later)
        -- Add other instance-specific state if needed
        textures = {},   -- texture data: simple textures and connected textures
        positioners = {} -- lerp values describing how things are positioned..

    }
    instance.scale = scale or 1
    return lib.createCharacterFromExistingDNA(instance, x, y, false)
end

function lib.createCharacter(template, x, y, scale)
    if dna[template] then
        local instance = {
            id = uuid.generateID(),
            templateName = template,
            dna = utils.deepCopy(dna[template]), -- Copy template data for potential instance modification
            parts = {},              -- { [partName] = thingObject, ... }
            joints = {},             -- unused...{ [connectionName] = jointObject, ... }
            --appearanceValues = {}, -- Will hold visual overrides (implement later)
            -- Add other instance-specific state if needed
            textures = {},   -- texture data: simple textures and connected textures
            positioners = {} -- lerp values describing how things are positioned..

        }
        instance.scale = scale or 1
        return lib.createCharacterFromExistingDNA(instance, x, y, false)
    end
end

return lib

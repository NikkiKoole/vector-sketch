-- src/mipo-textures.lua (split from character-manager.lua, SPLIT2)
local lib = {}

local mipoDna = require('src.mipo-dna')
local shape8Dict = require('src.shape8-dict')
local utils = require('src.utils')
local mathutils = require('src.math-utils')
local fixtures = require('src.fixtures')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')
local subtypes = require('src.subtypes')
local NT = require('src.node-types')
local mouthShapes = require('src.mouth-shapes')
local D = require('src.dna-defaults')
local topology = require('src.character-topology')
local TORSO_HAIR_ABOVE_SKIN = mipoDna.TORSO_HAIR_ABOVE_SKIN
local getCenterAndDimensions = mathutils.getCenterAndDimensions
local makeTransformedVertices = mathutils.scalePolygonPoints
local lerp = mathutils.clampedLerp

-- todo,
-- the curves for the limbs need a grow parameter, now its just some hardcoded value in drawTexturedWorld
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
-- Where the whole torso picture sits on a spine band's body (its y offset): the band's
-- outline is centred on the band, the picture on the whole shape. 0 for anything else.
local function spinePictureOffset(partData, scale)
    local band = partData.spineBand
    if not band then return 0 end
    local _, middle = topology.spineBand(shape8Dict[partData.shape8URL].vertices, band[1], band[2],
        (partData.dims.sy or 1) < 0)
    return -middle * (partData.dims.sy or 1) * scale
end

local function addSkinTexture(body, partData, skinData, scale)
    local _, _, w, h = getCenterAndDimensions(body)
    local offsetY = spinePictureOffset(partData, scale)

    local documentSize = nil
    if partData.shape8URL then
        if shape8Dict[partData.shape8URL] then
            if shape8Dict[partData.shape8URL].dimensions then
                getBoundingBox(shape8Dict[partData.shape8URL].vertices)
                documentSize = {}
                documentSize.w = shape8Dict[partData.shape8URL].dimensions[1] * math.abs(partData.dims.sx)
                documentSize.h = shape8Dict[partData.shape8URL].dimensions[2] * math.abs(partData.dims.sy)
            end
        end
    end

    local growfactor = 1.1

    local fixture
    if (documentSize) then
        fixture = fixtures.createSFixture(body, 0, offsetY,
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
    ud.extra.OMP = true
    ud.extra.dirty = true
    ud.extra.main = utils.deepCopy(skinData.main)
    ud.extra.main.bgURL = partData.shape8URL
    ud.extra.main.fgURL = partData.shape8URL:gsub('.png', '-mask.png')
    ud.extra.zOffset = skinData.zOffset or 0
    if partData.dims.sy ~= nil and partData.dims.sy < 0 then
        ud.extra.main.fy = -1
    end
    if partData.dims.sx ~= nil and partData.dims.sx < 0 then
        ud.extra.main.fx = -1
    end

    if skinData.patch1 then
        ud.extra.patch1 = utils.deepCopy(skinData.patch1)
    end
    if skinData.patch2 then
        ud.extra.patch2 = utils.deepCopy(skinData.patch2)
    end
    if skinData.patch3 then
        ud.extra.patch3 = utils.deepCopy(skinData.patch3)
    end
end

local function addBodyhairTexture(body, partName, partData, bodyhairData, scale)
    local _, _, w, h = getCenterAndDimensions(body)
    local growfactor = bodyhairData.growfactor or 1.2
    local fixture = fixtures.createSFixture(body, 0, 0, subtypes.TEXFIXTURE,
        { width = w * growfactor, height = h * growfactor })
    local ud = fixture:getUserData()
    ud.extra.OMP = false
    -- Layer bodyhair above skin (skin zOffset is 200 for the head, 192 for torsos: see TORSO_SKIN_Z)
    local skinZ = (partData.appearance and partData.appearance['skin'] and partData.appearance['skin'].zOffset) or 200
    ud.extra.zOffset = skinZ + (partName:find('^torso%d') and TORSO_HAIR_ABOVE_SKIN or 10)
    ud.extra.dirty = true
    ud.extra.main = utils.deepCopy(bodyhairData.main)

    local raw = shape8Dict[partData.shape8URL].vertices
    local vertices = makeTransformedVertices(raw, (partData.dims.sx or 1) * growfactor * scale,
        (partData.dims.sy or 1) * growfactor * scale)
    local offsetY = spinePictureOffset(partData, scale) -- the whole torso's hair, on a spine's lowest band
    for i = 2, #vertices, 2 do vertices[i] = vertices[i] + offsetY end
    local newVertices = cyclicShift(vertices, 2)
    if partData.dims.sy < 0 then
        newVertices = cyclicShift(newVertices, 8)
    end

    ud.extra.vertices = newVertices
    ud.extra.vertexCount = #vertices / 2
end

local function addConnectedTexture(body, partName, _partData, connData, instance, scale)
    local torsoSegments = instance.dna.creation.torsoSegments
    local noseSegments  = instance.dna.creation.noseSegments
    local jointLabels   = {}

    local fixture       = fixtures.createSFixture(body, 0, 0, subtypes.CONNECTED_TEXTURE,
        { radius = 30 * scale })

    local ud            = fixture:getUserData()

    ud.extra            = {
        attachTo = partName,
        OMP = true,
        dirty = true,
        main = utils.deepCopy(connData.main),
        zOffset = connData.zOffset or 0,
        nodes = {},
        growExtra = 20 * scale,
    }

    -- wmul controls the rendered width of the connected texture.
    -- Use DNA value if set, otherwise default to instance scale.
    ud.extra.main.wmul  = connData.main.wmul or scale
    if partName:find('uleg') then
        if partName == 'luleg' then
            jointLabels = { "torso1->luleg", "luleg->llleg", "llleg->lfoot" }
        elseif partName == 'ruleg' then
            jointLabels = { "torso1->ruleg", "ruleg->rlleg", "rlleg->rfoot" }
        end
    end
    if partName:find('uarm') then
        local top = 'torso' .. torsoSegments

        if partName == 'luarm' then
            jointLabels = { top .. "->luarm", "luarm->llarm", "llarm->lhand" }
        elseif partName == 'ruarm' then
            jointLabels = { top .. "->ruarm", "ruarm->rlarm", "rlarm->rhand" }
        end
    end
    -- we only do neck stuff from the top torso to the head. (other torso segments are ignored)
    if partName == ('torso' .. torsoSegments) and connData.endNode == 'head' then
        local neckSegments2 = instance.dna.creation.neckSegments
        local previous = 'torso' .. torsoSegments

        for i = 1, neckSegments2 do
            local current = 'neck' .. i
            table.insert(jointLabels, previous .. '->' .. current)
            previous = current
        end
        -- Final connection to head
        table.insert(jointLabels, previous .. '->head')
    end

    if partName == 'nose1' and noseSegments > 0 then
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

    -- Add terminal anchor at the tip of the last nose segment
    if partName == 'nose1' and noseSegments > 0 then
        local lastNose = 'nose' .. noseSegments
        local lastBody = instance.parts[lastNose] and instance.parts[lastNose].body
        if lastBody then
            local lastDims = instance.dna.parts[lastNose].dims
            local tipY = (lastDims.h / 2) * scale
            local tipAnchor = fixtures.createSFixture(lastBody, 0, tipY, subtypes.ANCHOR,
                { radius = 5 * scale })
            if tipAnchor then
                local anchorId = tipAnchor:getUserData().id
                ud.extra.nodes[#ud.extra.nodes + 1] = { id = anchorId, type = NT.ANCHOR }
            end
        end
    end
end

local function addHaircutTexture(body, partName, partData, haircutData, instance, scale)
    local rightPlaceForHaircut = false
    if instance.dna.creation.isPotatoHead and partName == 'torso1' then
        rightPlaceForHaircut = true
    end
    if not instance.dna.creation.isPotatoHead and partName == 'head' then
        rightPlaceForHaircut = true
    end

    if rightPlaceForHaircut then
        local fixture = fixtures.createSFixture(body, 0, 0, subtypes.TRACE_VERTICES,
            { radius = 30, width = 100, height = 100 })
        local ud = fixture:getUserData()
        local hasMask = haircutData.main.fgURL and haircutData.main.fgURL ~= ''
        ud.extra.OMP = hasMask
        ud.extra.zOffset = 220
        ud.extra.dirty = true
        ud.extra.main = utils.deepCopy(haircutData.main)
        ud.extra.width = (haircutData.width or 250) * scale
        ud.extra.startIndex = haircutData.startIndex
        ud.extra.endIndex = haircutData.endIndex

        if partData.dims.sy < 0 then
            ud.extra.startIndex = haircutData.startIndex + 4
            ud.extra.endIndex = haircutData.endIndex + 4
        end
    end
end

-- Every fixture of the Mipo in its collision group (setGroup; a negative group never
-- collides with itself) and its sfixtures in its z-range (zGroupOffset * 1000 + zOffset).
local function applyGroupAndZ(instance, setGroup)
    for _, part in pairs(instance.parts) do
        if part.body and not part.body:isDestroyed() then
            for _, fixture in ipairs(part.body:getFixtures()) do
                if setGroup and instance.groupIndex then fixture:setGroupIndex(instance.groupIndex) end
                local ud = fixture:getUserData()
                if instance.zGroupOffset and ud and ud.extra then ud.extra.zGroupOffset = instance.zGroupOffset end
            end
        end
    end
end

-- Where the face's decals sit, front to back (zOffset, within the Mipo's z group).
local FACE_Z = { eye = 250, pupil = 251, teeth = 251, lowerLip = 252, brow = 252, teethOut = 252.5,
    upperLip = 253, nose = 254 } -- nose above the mouth, below the arms (402); was 490

-- An outline + mask (+ no pattern) colour block for a decal (extra.main).
local function omp(bgURL, fgURL, bgHex, fgHex)
    return { bgURL = bgURL, fgURL = fgURL, pURL = '', bgHex = bgHex, fgHex = fgHex, pHex = 'ffffff00' }
end

-- '<name>-mask.png' when that texture exists, else ''.
local function maskOf(name)
    local mask = name .. '-mask.png'
    return love.filesystem.getInfo('textures/' .. mask) and mask or ''
end

-- A decal on the body: label, its extra fields; a colour block (main) is composed when drawn.
local function addDecal(body, label, extra)
    local ud = fixtures.createSFixture(body, 0, 0, subtypes.DECAL, { radius = 10 }):getUserData()
    ud.label = label
    for k, v in pairs(extra) do ud.extra[k] = v end
    if extra.main then
        ud.extra.dirty = true
        box2dDrawTextured.makeCached(ud.extra.main)
    end
    return ud
end

-- Masked: a colour block; no mask: the outline picture in one colour.
local function maskedOrPlain(extra, name, bgHex, fgHex)
    local mask = maskOf(name)
    if mask ~= '' then
        extra.OMP = true
        extra.main = omp(name .. '.png', mask, bgHex, fgHex)
    else
        extra.OMP = false
        extra.bgURL = name .. '.png'
        extra.bgHex = bgHex
    end
    return extra
end

local imageSizes = {} -- [path] = { w, h }: a picture's size, without loading it on every rebuild
local function imageSize(path)
    if imageSizes[path] == nil then
        local ok, img = pcall(love.graphics.newImage, path)
        imageSizes[path] = ok and { img:getDimensions() } or false
        if ok then img:release() end
    end
    return imageSizes[path] or nil
end

local function placeEyes(body, face, box)
    local eye, pupil, eyeR = face.eye, face.pupil, face.positioners.eye.r
    local eyeW, eyeH = box.headW * 0.25 * box.fm * eye.wMul, box.headH * 0.25 * box.fm * eye.hMul
    local eyeName = 'eye' .. eye.shape
    for _, side in ipairs({ { x = box.leftEyeX, label = 'l', mirror = true, rot = -eyeR },
                            { x = box.rightEyeX, label = 'r', mirror = false, rot = eyeR } }) do
        addDecal(body, side.label .. 'eye', {
            ox = side.x, oy = box.eyeY, w = eyeW, h = eyeH, mirror = side.mirror, rot = side.rot,
            zOffset = FACE_Z.eye, isEye = true, OMP = true,
            main = omp(eyeName .. '.png', eyeName .. '-mask.png', eye.bgHex, eye.fgHex),
        })
        -- a pupil with a mask is two colours, without one a tinted outline
        addDecal(body, side.label .. 'pupil', maskedOrPlain({
            ox = side.x, oy = box.eyeY, w = eyeW * pupil.wMul, h = eyeH * pupil.hMul, mirror = side.mirror,
            zOffset = FACE_Z.pupil, isEye = true, eyeW = eyeW, eyeH = eyeH, eyeMaskURL = eyeName .. '-mask.png',
            eyeMirror = side.mirror, eyeRot = side.rot, lookAtMouse = eye.lookAtMouse,
        }, 'pupil' .. pupil.shape, pupil.bgHex, pupil.fgHex))
    end
end

local function placeBrows(body, face, box)
    local brow = face.brow
    for _, side in ipairs({ { x = box.leftEyeX, label = 'lbrow', mirror = false },
                            { x = box.rightEyeX, label = 'rbrow', mirror = true } }) do
        addDecal(body, side.label, {
            ox = side.x, oy = lerp(box.topY, box.botY, face.positioners.brow.y),
            w = box.headW * 0.2 * brow.wMul * box.fm, h = box.headH * 0.1 * brow.hMul * box.fm,
            zOffset = FACE_Z.brow, browCurve = true, browBend = brow.bend, browMirror = side.mirror,
            bgURL = 'brow' .. brow.shape .. '.png', bgHex = brow.bgHex,
        })
    end
end

local function placeNose(body, face, box)
    local nose = face.nose
    if nose.shape <= 0 then return end
    addDecal(body, 'nose', maskedOrPlain({
        ox = (box.leftX + box.rightX) / 2, oy = lerp(box.topY, box.botY, face.positioners.nose.y),
        w = box.headW * 0.15 * nose.wMul * box.fm, h = box.headH * 0.15 * nose.hMul * box.fm,
        zOffset = FACE_Z.nose,
    }, 'nose' .. nose.shape, nose.bgHex, nose.fgHex))
end

-- Lower lip (draws first, stencils the inside), upper lip, and teeth clipped to the mouth.
local function placeMouth(body, face, box)
    local mouth = face.mouth
    local mouthShape = mouthShapes.normalized[mouth.shape]
    if not mouthShape then return end
    local mouthX, mouthY = (box.leftX + box.rightX) / 2, lerp(box.topY, box.botY, face.positioners.mouth.y)
    -- about 40% of the head wide (wMul/hMul adjust)
    local scaleX = (box.headW * 0.004) * mouth.wMul * box.fm
    local scaleY = (box.headH * 0.004) * mouth.hMul * box.fm
    local curvePoints = {} -- the 8 shape points scaled and moved onto the face
    for ci = 1, 16, 2 do
        curvePoints[ci] = mouthShape.points[ci] * scaleX + mouthX
        curvePoints[ci + 1] = mouthShape.points[ci + 1] * scaleY + mouthY
    end
    local function mouthPart(curve, z)
        return { ox = mouthX, oy = mouthY, zOffset = z, mouthCurve = curve, curvePoints = curvePoints,
            mouthScaleX = scaleX, mouthScaleY = scaleY, mouthX = mouthX, mouthY = mouthY, OMP = true }
    end
    local lower = mouthPart('lower', FACE_Z.lowerLip)
    lower.lipScale = mouth.lowerLipScale or mouth.lipScale or 0.2
    lower.backdropHex = mouth.backdropHex
    lower.main = omp('lowerlip' .. mouth.lowerLipShape .. '.png', 'lowerlip' .. mouth.lowerLipShape .. '-mask.png',
        '000000ff', mouth.lipHex)
    addDecal(body, 'lowerlip', lower)
    local upper = mouthPart('upper', FACE_Z.upperLip)
    upper.lipScale = mouth.upperLipScale or mouth.lipScale or 0.15
    upper.main = omp('upperlip' .. mouth.upperLipShape .. '.png', 'upperlip' .. mouth.upperLipShape .. '-mask.png',
        '000000ff', mouth.lipHex)
    addDecal(body, 'upperlip', upper)

    local teeth = face.teeth
    if teeth.shape <= 0 then return end
    local teethName = 'teeth' .. teeth.shape
    local teethW = scaleX * 100 * (teeth.wMul or 1)
    local size = imageSize('textures/' .. teethName .. '.png')
    local aspect = size and (size[2] / size[1]) or 0.5 -- 2:1 when the picture is missing
    local part = mouthPart('teeth', teeth.stickOut and FACE_Z.teethOut or FACE_Z.teeth)
    part.w, part.h = teethW, teethW * aspect * teeth.hMul
    part.teethStickOut = teeth.stickOut
    part.main = omp(teethName .. '.png', teethName .. '-mask.png', teeth.bgHex, teeth.fgHex)
    addDecal(body, 'teeth', part)
end

-- Eyes, pupils, brows, nose and mouth, on the head (or torso1 on a potato head), placed by
-- the face's positioners within the head shape's box.
local function addFaceDecals(body, partName, partData, faceData, instance, scale)
    local faceOwner = instance.dna.creation.isPotatoHead and 'torso1' or 'head'
    if partName ~= faceOwner or not (partData.shape8URL and shape8Dict[partData.shape8URL]) then return end
    D.ensureDefaults(faceData, D.face)

    local verts = makeTransformedVertices(shape8Dict[partData.shape8URL].vertices,
        (partData.dims.sx or 1) * scale, (partData.dims.sy or 1) * scale)
    -- a spine's torso1 (potato head): the face is on the whole torso, like its picture
    local offsetY = spinePictureOffset(partData, scale)
    for i = 2, #verts, 2 do verts[i] = verts[i] + offsetY end

    -- 8 vertices: 1 top, 3 right, 5 bottom, 7 left; min/max so a flipped shape works too
    local box = {
        topY = math.min(verts[2], verts[10]), botY = math.max(verts[2], verts[10]),
        leftX = math.min(verts[5], verts[13]), rightX = math.max(verts[5], verts[13]),
        fm = instance.dna.faceMagnitude,
    }
    box.headW, box.headH = math.abs(box.rightX - box.leftX), math.abs(box.botY - box.topY)
    local eyePos = faceData.positioners.eye
    box.leftEyeX = lerp(box.leftX, box.rightX, 0.5 - eyePos.x)
    box.rightEyeX = lerp(box.leftX, box.rightX, 0.5 + eyePos.x)
    box.eyeY = lerp(box.topY, box.botY, eyePos.y)

    placeEyes(body, faceData, box)
    placeBrows(body, faceData, box)
    placeNose(body, faceData, box)
    placeMouth(body, faceData, box)
end

function lib.rebuildTextures(instance)
    local scale = instance.scale
    for k, v in pairs(instance.dna.parts) do
        if v.appearance then
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

                -- a spine's upper bands draw no picture of their own: torso1 draws the whole torso
                local upperBand = v.spineBand and v.spineBand[1] > 1
                for k2, v2 in pairs(v.appearance) do
                    if (k2 == 'skin' or k2 == 'bodyhair') and upperBand then -- luacheck: ignore 542
                    elseif k2 == 'skin' then
                        addSkinTexture(relevant.body, v, v2, scale)
                    elseif k2 == 'bodyhair' then
                        addBodyhairTexture(relevant.body, k, v, v2, scale)
                    elseif k2 == 'connected-skin' or k2 == 'connected-hair' then
                        if v2.main and v2.main.bgURL and v2.main.bgURL ~= '' then
                            addConnectedTexture(relevant.body, k, v, v2, instance, scale)
                        end
                    elseif k2 == 'haircut' then
                        addHaircutTexture(relevant.body, k, v, v2, instance, scale)
                    elseif k2 == 'face' then
                        addFaceDecals(relevant.body, k, v, v2, instance, scale)
                    end
                end
            end
        end
    end
    applyGroupAndZ(instance, false) -- the new texture fixtures in the Mipo's z-range
end


lib.applyGroupAndZ = applyGroupAndZ

return lib

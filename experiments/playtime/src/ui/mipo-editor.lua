local lib = {}

local ui = require('src.ui.all')
local state = require('src.state')
local CharacterManager = require('src.character-manager')
local mipoRegistry = require('src.mipo-registry')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')
local mouthShapes = require('src.mouth-shapes')
local ST = require('src.shape-types')

local C = require('src.shape-catalogs')

local PANEL_WIDTH = 300
local BUTTON_HEIGHT = ui.theme.lineHeight
local BUTTON_SPACING = 10

local imageCache = {}

local accordionStates = {}
accordionStates.symmetricEditing = true

-- Shape categories for thumbnail grids (shared with character-manager via shape-catalogs)
local torsoHeadShapes = C.torsoHeadShapes
local earShapes = C.earShapes
local feetShapes = C.feetShapes
local handShapes = C.handShapes
local bodyhairTextures = C.bodyhairTextures
local haircutTextures = C.haircutTextures
local hairsWithMask = C.hairsWithMask
local limbSkinTextures = C.limbSkinTextures
local eyeShapes = C.eyeShapes
local pupilShapes = C.pupilShapes
local browShapes = C.browShapes
local upperLipShapes = C.upperLipShapes
local lowerLipShapes = C.lowerLipShapes
local limbHairTextures = C.limbHairTextures
local noseShapes = C.noseShapes
local teethShapes = C.teethShapes

local patternTextures = C.patternTextures

local patchShapes = {
    'patch1', 'patch2', 'patch3', 'patch4'
}

local function getShapesForPart(partName)
    if partName == 'head' or partName:match('^torso') or partName:match('^nose') then
        return torsoHeadShapes
    elseif partName == 'lear' or partName == 'rear' then
        return earShapes
    elseif partName == 'lfoot' or partName == 'rfoot' then
        return feetShapes
    elseif partName == 'lhand' or partName == 'rhand' then
        return handShapes
    end
    return nil
end

-- Connected textures (skin/hair) are defined on the upper limb part but visually
-- cover the entire limb chain. This maps lower limb parts to the upper limb that
-- owns the connected-skin/connected-hair appearance data.
-- Hands/feet are excluded — they have their own skin appearance, not connected textures.
local function getLimbRoot(partName)
    local mapping = {
        llarm = 'luarm',
        rlarm = 'ruarm',
        llleg = 'luleg',
        rlleg = 'ruleg',
    }
    return mapping[partName]
end

local function getMirrorPart(partName)
    local mirrors = {
        lear = 'rear', rear = 'lear',
        lfoot = 'rfoot', rfoot = 'lfoot',
        lhand = 'rhand', rhand = 'lhand',
        luleg = 'ruleg', ruleg = 'luleg',
        llleg = 'rlleg', rlleg = 'llleg',
        luarm = 'ruarm', ruarm = 'luarm',
        llarm = 'rlarm', rlarm = 'llarm',
    }
    return mirrors[partName]
end

local function drawThumbnailGrid(items, currentURL, panelX, startY, cellSize, onSelect, showNone)
    local itemsPerRow = math.floor((PANEL_WIDTH - 20) / cellSize)
    local clicked = false
    local offset = 0

    -- Optional "none" cell at position 0
    if showNone then
        offset = 1
        local cx = panelX + 10
        local cy = startY
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
        love.graphics.rectangle('line', cx + 2, cy + 2, cellSize - 4, cellSize - 4)
        love.graphics.line(cx + 2, cy + 2, cx + cellSize - 4, cy + cellSize - 4)
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.print('x', cx + cellSize / 2 - 4, cy + cellSize / 2 - 6)
        if not currentURL or currentURL == '' then
            love.graphics.setColor(1, 0.6, 0, 1)
            love.graphics.rectangle('line', cx, cy, cellSize, cellSize)
        end
        love.graphics.setColor(1, 1, 1, 1)
        if ui.mouseX >= cx and ui.mouseX <= cx + cellSize and
            ui.mouseY >= cy and ui.mouseY <= cy + cellSize and
            ui.mouseReleased then
            onSelect(nil)
            clicked = true
        end
    end

    for i, item in ipairs(items) do
        local idx = (i - 1) + offset
        local row = math.floor(idx / itemsPerRow)
        local col = idx % itemsPerRow
        local cx = panelX + 10 + col * cellSize
        local cy = startY + row * cellSize

        local url = item .. '.png'
        local img = imageCache[url]
        if not img then
            local ok, loaded = pcall(love.graphics.newImage, 'textures/' .. url)
            if ok then
                imageCache[url] = loaded
                img = loaded
            end
        end

        if img then
            local imgW, imgH = img:getDimensions()
            local scale = math.min((cellSize - 4) / imgW, (cellSize - 4) / imgH)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(img, cx + 2, cy + 2, 0, scale, scale)
        end

        -- Selection highlight
        if currentURL == url then
            love.graphics.setColor(1, 0.6, 0, 1)
            love.graphics.rectangle('line', cx, cy, cellSize, cellSize)
            love.graphics.setColor(1, 1, 1)
        end

        -- Click detection
        if ui.mouseX >= cx and ui.mouseX <= cx + cellSize and
            ui.mouseY >= cy and ui.mouseY <= cy + cellSize and
            ui.mouseReleased then
            onSelect(url)
            clicked = true
        end
    end

    local totalItems = #items + offset
    local totalRows = math.ceil(totalItems / itemsPerRow)
    return totalRows * cellSize, clicked
end

local function handlePaletteButton(idPrefix, px, py, pw, currentHex, onColorChange)
    local r, g, b, a = box2dDrawTextured.hexToColor(currentHex or '000000ff')
    local paletteShow = ui.button(px - 10, py, 20, '', BUTTON_HEIGHT, { r, g, b, a })
    if paletteShow then
        if state.panelVisibility.showPalette then
            state.panelVisibility.showPalette = nil
            state.showPaletteFunc = nil
        else
            state.panelVisibility.showPalette = true
            state.showPaletteFunc = function(color)
                onColorChange(color)
            end
        end
    end
    local hex = ui.textinput(idPrefix, px + 10, py, pw, BUTTON_HEIGHT, "", currentHex or '')
    if hex and hex ~= currentHex then
        onColorChange(hex)
    end
end

-- Draw pattern controls (texture grid + transform sliders) for an OMP block.
-- block: the DNA texture block (e.g. skin.main, connected-skin.main)
-- idPrefix: unique prefix for slider IDs
-- panelX, startY: layout position
-- onUpdate: function(key, value) called when a field changes
-- Returns the new y position after all controls.
local function drawPatternControls(block, idPrefix, panelX, startY, onUpdate)
    local px = panelX + 10
    local yy = startY
    local ROW = BUTTON_HEIGHT + BUTTON_SPACING

    -- Pattern texture thumbnail grid
    local currentPURL = block.pURL or 'type0.png'
    if currentPURL == '' then currentPURL = 'type0.png' end
    -- Convert pURL (e.g. 'type0.png') to grid format ('pat/type0')
    local currentGridURL = 'pat/' .. currentPURL
    local cellSize = 40
    local gridHeight = drawThumbnailGrid(patternTextures, currentGridURL, panelX, yy, cellSize,
        function(url)
            -- url is 'pat/type0.png'; strip 'pat/' prefix for pURL
            local purl = url and url:gsub('^pat/', '') or 'type0.png'
            onUpdate('pURL', purl)
        end)
    yy = yy + gridHeight + BUTTON_SPACING

    -- Only show transform sliders if a pattern is selected
    if currentPURL ~= '' then
        handlePaletteButton(idPrefix .. '_pHex', px + 30, yy, 140, block.pHex, function(color)
            onUpdate('pHex', color)
        end)
        ui.alignedLabel(px + 180, yy, 'pattern')
        yy = yy + ROW

        local sliders = {
            { key = 'pr',  label = 'rot',  min = 0, max = 6.28, default = 0 },
            { key = 'psx', label = 'scaleX', min = 0.01, max = 3, default = 1 },
            { key = 'psy', label = 'scaleY', min = 0.01, max = 3, default = 1 },
            { key = 'ptx', label = 'offX', min = -1, max = 1, default = 0 },
            { key = 'pty', label = 'offY', min = -1, max = 1, default = 0 },
        }
        for _, s in ipairs(sliders) do
            local val = ui.sliderWithInput(idPrefix .. '_' .. s.key,
                px, yy, 120, s.min, s.max, block[s.key] or s.default)
            ui.alignedLabel(px, yy, '  ' .. s.label)
            val = val and tonumber(val)
            if val and val ~= (block[s.key] or s.default) then
                onUpdate(s.key, val)
            end
            yy = yy + ROW
        end
    end

    return yy
end

-- Draw eye/pupil shape grids, position sliders, size sliders, and color pickers.
local function drawFaceEyesUI(instance, faceOwner, partName, face, x, y, panelX, ROW)
    local eye = face.eye
    local pupil = face.pupil
    local eyePos = face.positioners.eye
    local cellSize = 50

    -- Eye shape thumbnail grid
    ui.label(x, y, 'eye shape')
    y = y + ROW
    local currentEyeURL = 'eye' .. eye.shape .. '.png'
    local gridHeight = drawThumbnailGrid(eyeShapes, currentEyeURL, panelX, y, cellSize, function(url)
        if url then
            local shapeNum = tonumber(url:match('eye(%d+)%.png'))
            if shapeNum then
                CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeShape = shapeNum })
                CharacterManager.addTexturesFromInstance2(instance)
            end
        end
    end)
    y = y + gridHeight + BUTTON_SPACING

    -- Pupil shape thumbnail grid
    ui.label(x, y, 'pupil shape')
    y = y + ROW
    local currentPupilURL = 'pupil' .. pupil.shape .. '.png'
    gridHeight = drawThumbnailGrid(pupilShapes, currentPupilURL, panelX, y, cellSize, function(url)
        if url then
            local shapeNum = tonumber(url:match('pupil(%d+)%.png'))
            if shapeNum then
                CharacterManager.updateFaceOfPart(instance, faceOwner, { pupilShape = shapeNum })
                CharacterManager.addTexturesFromInstance2(instance)
            end
        end
    end)
    y = y + gridHeight + BUTTON_SPACING

    -- Eye position sliders
    local eyeX = ui.sliderWithInput('mipo_eye_x', x, y, 120, 0, 0.5, eyePos.x)
    ui.alignedLabel(x, y, '  eye spacing')
    eyeX = eyeX and tonumber(eyeX)
    if eyeX and eyeX ~= eyePos.x then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeX = eyeX })
        CharacterManager.addTexturesFromInstance2(instance)
    end
    y = y + ROW

    local eyeY = ui.sliderWithInput('mipo_eye_y', x, y, 120, 0, 1, eyePos.y)
    ui.alignedLabel(x, y, '  eye vertical')
    eyeY = eyeY and tonumber(eyeY)
    if eyeY and eyeY ~= eyePos.y then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeY = eyeY })
        CharacterManager.addTexturesFromInstance2(instance)
    end
    y = y + ROW

    -- Eye rotation
    local eyeRVal = ui.sliderWithInput('mipo_eye_r', x, y, 120, -2, 2, eyePos.r)
    ui.alignedLabel(x, y, '  eye rotation')
    eyeRVal = eyeRVal and tonumber(eyeRVal)
    if eyeRVal and eyeRVal ~= eyePos.r then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeR = eyeRVal })
        CharacterManager.addTexturesFromInstance2(instance)
    end
    y = y + ROW

    -- Eye size sliders
    local ewMul = ui.sliderWithInput('mipo_eye_wmul', x, y, 120, 0.25, 2, eye.wMul)
    ui.alignedLabel(x, y, '  eye width')
    ewMul = ewMul and tonumber(ewMul)
    if ewMul and ewMul ~= eye.wMul then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeWMul = ewMul })
        CharacterManager.addTexturesFromInstance2(instance)
    end
    y = y + ROW

    local ehMul = ui.sliderWithInput('mipo_eye_hmul', x, y, 120, 0.25, 2, eye.hMul)
    ui.alignedLabel(x, y, '  eye height')
    ehMul = ehMul and tonumber(ehMul)
    if ehMul and ehMul ~= eye.hMul then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeHMul = ehMul })
        CharacterManager.addTexturesFromInstance2(instance)
    end
    y = y + ROW

    -- Pupil size sliders
    local pwMul = ui.sliderWithInput('mipo_pupil_wmul', x, y, 120, 0.1, 1, pupil.wMul)
    ui.alignedLabel(x, y, '  pupil width')
    pwMul = pwMul and tonumber(pwMul)
    if pwMul and pwMul ~= pupil.wMul then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { pupilWMul = pwMul })
        CharacterManager.addTexturesFromInstance2(instance)
    end
    y = y + ROW

    local phMul = ui.sliderWithInput('mipo_pupil_hmul', x, y, 120, 0.1, 1, pupil.hMul)
    ui.alignedLabel(x, y, '  pupil height')
    phMul = phMul and tonumber(phMul)
    if phMul and phMul ~= pupil.hMul then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { pupilHMul = phMul })
        CharacterManager.addTexturesFromInstance2(instance)
    end
    y = y + ROW

    -- Eye color
    handlePaletteButton('mipo_eye_bg_' .. partName,
        x + 30, y, 140, eye.bgHex, function(color)
            CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeBgHex = color })
            CharacterManager.addTexturesFromInstance2(instance)
        end)
    ui.alignedLabel(x + 180, y, 'eye outline')
    y = y + ROW

    handlePaletteButton('mipo_eye_fg_' .. partName,
        x + 30, y, 140, eye.fgHex, function(color)
            CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeFgHex = color })
            CharacterManager.addTexturesFromInstance2(instance)
        end)
    ui.alignedLabel(x + 180, y, 'eye fill')
    y = y + ROW

    -- Pupil color
    handlePaletteButton('mipo_pupil_bg_' .. partName,
        x + 30, y, 140, pupil.bgHex, function(color)
            CharacterManager.updateFaceOfPart(instance, faceOwner, { pupilBgHex = color })
            CharacterManager.addTexturesFromInstance2(instance)
        end)
    ui.alignedLabel(x + 180, y, 'pupil color')
    y = y + ROW

    local lookClicked, lookChecked = ui.checkbox(x, y, eye.lookAtMouse, 'pupils follow mouse')
    if lookClicked then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeLookAtMouse = lookChecked })
        CharacterManager.addTexturesFromInstance2(instance)
    end
    y = y + ROW

    return y
end

-- Draw brow shape grid, bend, size, position, and color controls.
local function drawFaceBrowsUI(instance, faceOwner, partName, face, x, y, panelX, ROW)
    local brow = face.brow
    local browPos = face.positioners.brow
    local cellSize = 50

    -- Brow shape thumbnail grid
    ui.label(x, y, 'brow shape')
    y = y + ROW
    local currentBrowURL = 'brow' .. brow.shape .. '.png'
    local gridHeight = drawThumbnailGrid(browShapes, currentBrowURL, panelX, y, cellSize, function(url)
        if url then
            local shapeNum = tonumber(url:match('brow(%d+)%.png'))
            if shapeNum then
                CharacterManager.updateFaceOfPart(instance, faceOwner, { browShape = shapeNum })
                CharacterManager.addTexturesFromInstance2(instance)
            end
        end
    end)
    y = y + gridHeight + BUTTON_SPACING

    -- Brow bend pattern
    local browBend = ui.sliderWithInput('mipo_brow_bend', x, y, 120, 1, 10, brow.bend)
    ui.alignedLabel(x, y, '  brow bend')
    browBend = browBend and tonumber(browBend)
    if browBend then browBend = math.floor(browBend + 0.5) end
    if browBend and browBend ~= brow.bend then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { browBend = browBend })
        CharacterManager.addTexturesFromInstance2(instance)
    end
    y = y + ROW

    -- Brow size
    local bwMul = ui.sliderWithInput('mipo_brow_wmul', x, y, 120, 0.25, 2, brow.wMul)
    ui.alignedLabel(x, y, '  brow width')
    bwMul = bwMul and tonumber(bwMul)
    if bwMul and bwMul ~= brow.wMul then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { browWMul = bwMul })
        CharacterManager.addTexturesFromInstance2(instance)
    end
    y = y + ROW

    local bhMul = ui.sliderWithInput('mipo_brow_hmul', x, y, 120, 0.25, 2, brow.hMul)
    ui.alignedLabel(x, y, '  brow height')
    bhMul = bhMul and tonumber(bhMul)
    if bhMul and bhMul ~= brow.hMul then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { browHMul = bhMul })
        CharacterManager.addTexturesFromInstance2(instance)
    end
    y = y + ROW

    -- Brow vertical position
    local browYVal = ui.sliderWithInput('mipo_brow_y', x, y, 120, 0.1, 0.5, browPos.y)
    ui.alignedLabel(x, y, '  brow vertical')
    browYVal = browYVal and tonumber(browYVal)
    if browYVal and browYVal ~= browPos.y then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { browY = browYVal })
        CharacterManager.addTexturesFromInstance2(instance)
    end
    y = y + ROW

    -- Brow color
    handlePaletteButton('mipo_brow_bg_' .. partName,
        x + 30, y, 140, brow.bgHex, function(color)
            CharacterManager.updateFaceOfPart(instance, faceOwner, { browBgHex = color })
            CharacterManager.addTexturesFromInstance2(instance)
        end)
    ui.alignedLabel(x + 180, y, 'brow color')
    y = y + ROW

    return y
end

-- Draw nose shape grid, size, position, and color controls.
local function drawFaceNoseUI(instance, faceOwner, partName, face, x, y, panelX, ROW)
    local nose = face.nose
    local nosePos = face.positioners.nose
    local cellSize = 50

    ui.label(x, y, 'nose (overlay)')
    y = y + ROW
    local currentNoseURL = nose.shape > 0 and ('nose' .. nose.shape .. '.png') or ''
    local gridHeight = drawThumbnailGrid(noseShapes, currentNoseURL, panelX, y, cellSize, function(url)
        if url then
            local shapeNum = tonumber(url:match('nose(%d+)%.png'))
            if shapeNum then
                CharacterManager.updateFaceOfPart(instance, faceOwner, { noseShape = shapeNum })
                CharacterManager.addTexturesFromInstance2(instance)
            end
        else
            CharacterManager.updateFaceOfPart(instance, faceOwner, { noseShape = 0 })
            CharacterManager.addTexturesFromInstance2(instance)
        end
    end, true)
    y = y + gridHeight + BUTTON_SPACING

    -- Nose size sliders
    local nwMul = ui.sliderWithInput('mipo_nose_wmul', x, y, 120, 0.5, 3, nose.wMul)
    ui.alignedLabel(x, y, '  nose width')
    nwMul = nwMul and tonumber(nwMul)
    if nwMul and nwMul ~= nose.wMul then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { noseWMul = nwMul })
        CharacterManager.addTexturesFromInstance2(instance)
    end
    y = y + ROW

    local nhMul = ui.sliderWithInput('mipo_nose_hmul', x, y, 120, 0.5, 3, nose.hMul)
    ui.alignedLabel(x, y, '  nose height')
    nhMul = nhMul and tonumber(nhMul)
    if nhMul and nhMul ~= nose.hMul then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { noseHMul = nhMul })
        CharacterManager.addTexturesFromInstance2(instance)
    end
    y = y + ROW

    -- Nose vertical position
    local noseYVal = ui.sliderWithInput('mipo_nose_y', x, y, 120, 0, 1, nosePos.y)
    ui.alignedLabel(x, y, '  nose vertical')
    noseYVal = noseYVal and tonumber(noseYVal)
    if noseYVal and noseYVal ~= nosePos.y then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { noseY = noseYVal })
        CharacterManager.addTexturesFromInstance2(instance)
    end
    y = y + ROW

    -- Nose colors
    handlePaletteButton('mipo_nose_bg_' .. partName,
        x + 30, y, 140, nose.bgHex, function(color)
            CharacterManager.updateFaceOfPart(instance, faceOwner, { noseBgHex = color })
            CharacterManager.addTexturesFromInstance2(instance)
        end)
    ui.alignedLabel(x + 180, y, 'nose outline')
    y = y + ROW

    handlePaletteButton('mipo_nose_fg_' .. partName,
        x + 30, y, 140, nose.fgHex, function(color)
            CharacterManager.updateFaceOfPart(instance, faceOwner, { noseFgHex = color })
            CharacterManager.addTexturesFromInstance2(instance)
        end)
    ui.alignedLabel(x + 180, y, 'nose fill')
    y = y + ROW

    return y
end

-- Draw mouth shape, lips, position, sizes, colors, and teeth controls.
local function drawFaceMouthUI(instance, faceOwner, partName, face, x, y, panelX, ROW)
    local mouth = face.mouth
    local mouthPos = face.positioners.mouth
    local cellSize = 50

    ui.label(x, y, 'mouth shape (' .. mouth.shape .. '/' .. #mouthShapes.normalized .. ')')
    y = y + ROW

    local mShape = ui.sliderWithInput('mipo_mouth_shape', x, y, 120, 1, #mouthShapes.normalized,
        mouth.shape)
    ui.alignedLabel(x, y, '  mouth preset')
    mShape = mShape and tonumber(mShape)
    if mShape then mShape = math.floor(mShape + 0.5) end
    if mShape and mShape ~= mouth.shape then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthShape = mShape })
        CharacterManager.addTexturesFromInstance2(instance)
    end
    y = y + ROW

    -- Upper lip texture grid
    ui.label(x, y, 'upper lip')
    y = y + ROW
    local currentUpperURL = 'upperlip' .. mouth.upperLipShape .. '.png'
    local gridHeight = drawThumbnailGrid(upperLipShapes, currentUpperURL, panelX, y, cellSize, function(url)
        if url then
            local num = tonumber(url:match('upperlip(%d+)%.png'))
            if num then
                CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthUpperLipShape = num })
                CharacterManager.addTexturesFromInstance2(instance)
            end
        end
    end)
    y = y + gridHeight + BUTTON_SPACING

    -- Lower lip texture grid
    ui.label(x, y, 'lower lip')
    y = y + ROW
    local currentLowerURL = 'lowerlip' .. mouth.lowerLipShape .. '.png'
    gridHeight = drawThumbnailGrid(lowerLipShapes, currentLowerURL, panelX, y, cellSize, function(url)
        if url then
            local num = tonumber(url:match('lowerlip(%d+)%.png'))
            if num then
                CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthLowerLipShape = num })
                CharacterManager.addTexturesFromInstance2(instance)
            end
        end
    end)
    y = y + gridHeight + BUTTON_SPACING

    -- Mouth position
    local mY = ui.sliderWithInput('mipo_mouth_y', x, y, 120, 0.5, 0.95, mouthPos.y)
    ui.alignedLabel(x, y, '  mouth vertical')
    mY = mY and tonumber(mY)
    if mY and mY ~= mouthPos.y then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthY = mY })
        CharacterManager.addTexturesFromInstance2(instance)
    end
    y = y + ROW

    -- Mouth size
    local mwMul = ui.sliderWithInput('mipo_mouth_wmul', x, y, 120, 0.3, 2, mouth.wMul)
    ui.alignedLabel(x, y, '  mouth width')
    mwMul = mwMul and tonumber(mwMul)
    if mwMul and mwMul ~= mouth.wMul then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthWMul = mwMul })
        CharacterManager.addTexturesFromInstance2(instance)
    end
    y = y + ROW

    local mhMul = ui.sliderWithInput('mipo_mouth_hmul', x, y, 120, 0.3, 2, mouth.hMul)
    ui.alignedLabel(x, y, '  mouth height')
    mhMul = mhMul and tonumber(mhMul)
    if mhMul and mhMul ~= mouth.hMul then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthHMul = mhMul })
        CharacterManager.addTexturesFromInstance2(instance)
    end
    y = y + ROW

    -- Lip thickness
    local lipScale = ui.sliderWithInput('mipo_lip_scale', x, y, 120, 0.05, 0.5, mouth.lipScale)
    ui.alignedLabel(x, y, '  lip thickness')
    lipScale = lipScale and tonumber(lipScale)
    if lipScale and lipScale ~= mouth.lipScale then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthLipScale = lipScale })
        CharacterManager.addTexturesFromInstance2(instance)
    end
    y = y + ROW

    -- Lip color
    handlePaletteButton('mipo_lip_color_' .. partName,
        x + 30, y, 140, mouth.lipHex, function(color)
            CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthLipHex = color })
            CharacterManager.addTexturesFromInstance2(instance)
        end)
    ui.alignedLabel(x + 180, y, 'lip color')
    y = y + ROW

    -- Backdrop color
    handlePaletteButton('mipo_mouth_backdrop_' .. partName,
        x + 30, y, 140, mouth.backdropHex, function(color)
            CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthBackdropHex = color })
            CharacterManager.addTexturesFromInstance2(instance)
        end)
    ui.alignedLabel(x + 180, y, 'mouth interior')
    y = y + ROW

    -- --- Teeth ---
    local teeth = face.teeth
    ui.label(x, y, 'teeth')
    y = y + ROW

    local currentTeethURL = teeth.shape and teeth.shape > 0 and ('teeth' .. teeth.shape .. '.png') or ''
    local teethGridHeight = drawThumbnailGrid(teethShapes, currentTeethURL, panelX, y, cellSize, function(url)
        if url then
            local num = tonumber(url:match('teeth(%d+)%.png'))
            if num then
                CharacterManager.updateFaceOfPart(instance, faceOwner, { teethShape = num })
                CharacterManager.addTexturesFromInstance2(instance)
            end
        else
            CharacterManager.updateFaceOfPart(instance, faceOwner, { teethShape = 0 })
            CharacterManager.addTexturesFromInstance2(instance)
        end
    end, true) -- showNone = true
    y = y + teethGridHeight + BUTTON_SPACING

    if teeth.shape and teeth.shape > 0 then
        local thMul = ui.sliderWithInput('mipo_teeth_hmul', x, y, 120, 0.5, 3, teeth.hMul)
        ui.alignedLabel(x, y, '  teeth height')
        thMul = thMul and tonumber(thMul)
        if thMul and thMul ~= teeth.hMul then
            CharacterManager.updateFaceOfPart(instance, faceOwner, { teethHMul = thMul })
            CharacterManager.addTexturesFromInstance2(instance)
        end
        y = y + ROW

        local soClicked, soChecked = ui.checkbox(x, y, teeth.stickOut, 'stick out')
        if soClicked then
            CharacterManager.updateFaceOfPart(instance, faceOwner, { teethStickOut = soChecked })
            CharacterManager.addTexturesFromInstance2(instance)
        end
        y = y + ROW

        handlePaletteButton('mipo_teeth_bg_' .. partName,
            x + 30, y, 140, teeth.bgHex, function(color)
                CharacterManager.updateFaceOfPart(instance, faceOwner, { teethBgHex = color })
                CharacterManager.addTexturesFromInstance2(instance)
            end)
        ui.alignedLabel(x + 180, y, 'teeth outline')
        y = y + ROW

        handlePaletteButton('mipo_teeth_fg_' .. partName,
            x + 30, y, 140, teeth.fgHex, function(color)
                CharacterManager.updateFaceOfPart(instance, faceOwner, { teethFgHex = color })
                CharacterManager.addTexturesFromInstance2(instance)
            end)
        ui.alignedLabel(x + 180, y, 'teeth fill')
        y = y + ROW
    end

    return y
end

function lib.drawMipoEditor(instance, partName)
    local panelWidth = PANEL_WIDTH
    local w, h = love.graphics.getDimensions()
    local panelX = w - panelWidth - 20

    local panelY = 20
    local panelH = h - 40
    ui.scrollableList('mipo_scroll', panelX, panelY, panelWidth, panelH,
        function(_sx, _sy, _sw, _sh, scrollOffset)
        local padding = BUTTON_SPACING
        local x = panelX + padding
        local y = panelY + padding + (scrollOffset or 0)
        local ROW = BUTTON_HEIGHT + BUTTON_SPACING
        local startY = y

        -- Title
        ui.label(x, y, 'mipo: ' .. (partName or '?'))
        y = y + ROW

        -- Header info
        local partCount = 0
        for _ in pairs(instance.parts) do partCount = partCount + 1 end
        ui.label(x, y, 'parts: ' .. partCount .. '  scale: ' .. string.format('%.2f', instance.scale or 1))
        y = y + ROW

        -- Symmetric editing toggle
        local symClicked, symChecked = ui.checkbox(x, y, accordionStates.symmetricEditing, 'symmetric')
        if symClicked then accordionStates.symmetricEditing = symChecked end
        y = y + ROW

        -- drawAccordion helper
        local function drawAccordion(key, contentFunc)
            local clicked = ui.header_button(x, y, panelWidth - 40, (accordionStates[key] and " ÷  " or " •") ..
                ' ' .. key, accordionStates[key])
            if clicked then
                accordionStates[key] = not accordionStates[key]
            end
            y = y + ROW
            if accordionStates[key] then
                contentFunc()
            end
        end

        -- === CREATION ACCORDION ===
        drawAccordion('creation', function()
            local creation = instance.dna.creation
            local changed = false

            -- isPotatoHead checkbox
            local cbClicked, cbChecked = ui.checkbox(x, y, creation.isPotatoHead or false, 'isPotatoHead')
            if cbClicked then
                changed = true
                CharacterManager.rebuildFromCreation(instance, { isPotatoHead = cbChecked })
                CharacterManager.addTexturesFromInstance2(instance)
            end
            y = y + ROW

            -- torsoSegments
            local ts = ui.sliderWithInput('mipo_torsoSeg', x, y, 120, 1, 5, creation.torsoSegments or 1, false, 1)
            ui.alignedLabel(x, y, '  torso segments')
            if ts then
                local val = math.floor(ts)
                if val ~= creation.torsoSegments then
                    changed = true
                    CharacterManager.rebuildFromCreation(instance, { torsoSegments = val })
                    CharacterManager.addTexturesFromInstance2(instance)
                end
            end
            y = y + ROW

            -- neckSegments
            local ns = ui.sliderWithInput('mipo_neckSeg', x, y, 120, 0, 5, creation.neckSegments or 0, false, 1)
            ui.alignedLabel(x, y, '  neck segments')
            if ns then
                local val = math.floor(ns)
                if val ~= creation.neckSegments then
                    changed = true
                    CharacterManager.rebuildFromCreation(instance, { neckSegments = val })
                    CharacterManager.addTexturesFromInstance2(instance)
                end
            end
            y = y + ROW

            -- neck height (adjusts all neck segments at once)
            if (creation.neckSegments or 0) > 0 then
                local firstNeck = instance.dna.parts['neck1']
                local currentH = firstNeck and firstNeck.dims and firstNeck.dims.h or 150
                local nh = ui.sliderWithInput('mipo_neckH', x, y, 120, 10, 500, currentH)
                ui.alignedLabel(x, y, '  neck height')
                nh = nh and tonumber(nh)
                if nh and nh ~= currentH then
                    for i = 1, creation.neckSegments do
                        CharacterManager.updatePart('neck' .. i, { h = nh }, instance)
                    end
                    CharacterManager.addTexturesFromInstance2(instance)
                end
                y = y + ROW
            end

            -- noseSegments
            local noses = ui.sliderWithInput('mipo_noseSeg', x, y, 120, 0, 5, creation.noseSegments or 0, false, 1)
            ui.alignedLabel(x, y, '  nose segments')
            if noses then
                local val = math.floor(noses)
                if val ~= creation.noseSegments then
                    local updates = { noseSegments = val }
                    if val == 0 then
                        -- No nose — nothing extra
                    elseif val == 1 then
                        -- Keep current noseMode; disable overlay if switching to physics
                        if (creation.noseMode or 'overlay') == 'physics' then
                            local startParent = creation.isPotatoHead and 'torso1' or 'head'
                            CharacterManager.updateFaceOfPart(instance, startParent, { noseShape = 0 })
                        end
                    else
                        -- 2+ → segmented, disable overlay
                        updates.noseMode = 'physics'
                        local startParent = creation.isPotatoHead and 'torso1' or 'head'
                        CharacterManager.updateFaceOfPart(instance, startParent, { noseShape = 0 })
                    end
                    CharacterManager.rebuildFromCreation(instance, updates)
                    CharacterManager.addTexturesFromInstance2(instance)
                end
            end
            y = y + ROW

            -- When noseSegments == 1, show physics toggle checkbox
            if (creation.noseSegments or 0) == 1 then
                local currentMode = creation.noseMode or 'overlay'
                local clicked, checked = ui.checkbox(x, y, currentMode == 'physics', 'physics nose')
                if clicked then
                    local newMode = checked and 'physics' or 'overlay'
                    if newMode == 'physics' then
                        local startParent = creation.isPotatoHead and 'torso1' or 'head'
                        CharacterManager.updateFaceOfPart(instance, startParent, { noseShape = 0 })
                    end
                    CharacterManager.rebuildFromCreation(instance, { noseMode = newMode })
                    CharacterManager.addTexturesFromInstance2(instance)
                end
                y = y + ROW
            end

            -- suppress unused warning
            local _ = changed
        end)

        -- === POSITIONERS ACCORDION ===
        drawAccordion('positioners', function()
            local pos = instance.dna.positioners

            -- Leg stance width
            local legX = ui.sliderWithInput('mipo_leg_x', x, y, 120, 0, 1, pos.leg.x)
            ui.alignedLabel(x, y, '  leg stance')
            legX = legX and tonumber(legX)
            if legX and legX ~= pos.leg.x then
                CharacterManager.updatePositioners(instance, { legX = legX })
                CharacterManager.rebuildFromCreation(instance, {})
                CharacterManager.addTexturesFromInstance2(instance)
            end
            y = y + ROW

            -- Ear vertical position
            local earY = ui.sliderWithInput('mipo_ear_y', x, y, 120, 0, 1, pos.ear.y)
            ui.alignedLabel(x, y, '  ear vertical')
            earY = earY and tonumber(earY)
            if earY and earY ~= pos.ear.y then
                CharacterManager.updatePositioners(instance, { earY = earY })
                CharacterManager.rebuildFromCreation(instance, {})
                CharacterManager.addTexturesFromInstance2(instance)
            end
            y = y + ROW

            -- Ear stance angle (left ear)
            local learPart = instance.dna.parts['lear']
            if learPart then
                local lAngle = learPart.stanceAngle or (-math.pi / 2 + math.pi / 5)
                local lVal = ui.sliderWithInput('mipo_lear_angle', x, y, 120, -math.pi, math.pi, lAngle)
                ui.alignedLabel(x, y, '  L ear angle')
                lVal = lVal and tonumber(lVal)
                if lVal and lVal ~= lAngle then
                    learPart.stanceAngle = lVal
                    CharacterManager.rebuildFromCreation(instance, {})
                    CharacterManager.addTexturesFromInstance2(instance)
                end
                y = y + ROW
            end

            -- Ear stance angle (right ear)
            local rearPart = instance.dna.parts['rear']
            if rearPart then
                local rAngle = rearPart.stanceAngle or (math.pi / 2 - math.pi / 5)
                local rVal = ui.sliderWithInput('mipo_rear_angle', x, y, 120, -math.pi, math.pi, rAngle)
                ui.alignedLabel(x, y, '  R ear angle')
                rVal = rVal and tonumber(rVal)
                if rVal and rVal ~= rAngle then
                    rearPart.stanceAngle = rVal
                    CharacterManager.rebuildFromCreation(instance, {})
                    CharacterManager.addTexturesFromInstance2(instance)
                end
                y = y + ROW
            end

            -- Ears over head checkbox
            local learSkin = instance.dna.parts['lear'] and instance.dna.parts['lear'].appearance
                and instance.dna.parts['lear'].appearance['skin']
            if learSkin then
                local earsOver = (learSkin.zOffset or 190) > 200
                local eohClicked, eohChecked = ui.checkbox(x, y, earsOver, 'ears over head')
                if eohClicked then
                    local newZ = eohChecked and 210 or 190
                    learSkin.zOffset = newZ
                    local rearSkin = instance.dna.parts['rear'] and instance.dna.parts['rear'].appearance
                        and instance.dna.parts['rear'].appearance['skin']
                    if rearSkin then rearSkin.zOffset = newZ end
                    CharacterManager.addTexturesFromInstance2(instance)
                end
                y = y + ROW
            end

            -- Face magnitude (global face feature scaler)
            local fmVal = ui.sliderWithInput('mipo_face_mag', x, y, 120, 0.25, 2, instance.dna.faceMagnitude or 1)
            ui.alignedLabel(x, y, '  face magnitude')
            fmVal = fmVal and tonumber(fmVal)
            if fmVal and fmVal ~= (instance.dna.faceMagnitude or 1) then
                CharacterManager.updatePositioners(instance, { faceMagnitude = fmVal })
                CharacterManager.addTexturesFromInstance2(instance)
            end
            y = y + ROW
        end)

        -- === SHAPE ACCORDION ===
        local shapes = getShapesForPart(partName)
        if shapes then
            drawAccordion(partName .. ' shape', function()
                local partData = instance.dna.parts[partName]
                if not partData then return end

                local currentURL = partData.shape8URL
                local cellSize = 50
                local gridHeight = drawThumbnailGrid(shapes, currentURL, panelX, y, cellSize, function(url)
                    local mirror = getMirrorPart(partName)
                    local sx = partData.dims.sx or 1
                    local sy = partData.dims.sy or 1
                    CharacterManager.updatePart(partName, { shape8URL = url, sx = sx, sy = sy }, instance)
                    if mirror then
                        local mirrorData = instance.dna.parts[mirror]
                        if mirrorData then
                            local msx = mirrorData.dims.sx or 1
                            local msy = mirrorData.dims.sy or 1
                            CharacterManager.updatePart(mirror, { shape8URL = url, sx = msx, sy = msy }, instance)
                        end
                    end
                    CharacterManager.addTexturesFromInstance2(instance)
                end)
                -- Advance y past the grid
                y = y + gridHeight + BUTTON_SPACING

                -- sx slider
                local sxVal = ui.sliderWithInput('mipo_sx', x, y, 120, -3, 3, partData.dims.sx or 1)
                ui.alignedLabel(x, y, '  sx')
                sxVal = sxVal and tonumber(sxVal)
                if sxVal and sxVal ~= (partData.dims.sx or 1) then
                    CharacterManager.updatePart(partName,
                        { shape8URL = partData.shape8URL, sx = sxVal, sy = partData.dims.sy or 1 }, instance)
                    if accordionStates.symmetricEditing then
                        local mirror = getMirrorPart(partName)
                        if mirror then
                            local mirrorData = instance.dna.parts[mirror]
                            if mirrorData then
                                CharacterManager.updatePart(mirror,
                                    { shape8URL = mirrorData.shape8URL, sx = sxVal,
                                      sy = mirrorData.dims.sy or 1 }, instance)
                            end
                        end
                    end
                    CharacterManager.addTexturesFromInstance2(instance)
                end
                y = y + ROW

                -- sy slider
                local syVal = ui.sliderWithInput('mipo_sy', x, y, 120, -3, 3, partData.dims.sy or 1)
                ui.alignedLabel(x, y, '  sy')
                syVal = syVal and tonumber(syVal)
                if syVal and syVal ~= (partData.dims.sy or 1) then
                    CharacterManager.updatePart(partName,
                        { shape8URL = partData.shape8URL, sx = partData.dims.sx or 1, sy = syVal }, instance)
                    if accordionStates.symmetricEditing then
                        local mirror = getMirrorPart(partName)
                        if mirror then
                            local mirrorData = instance.dna.parts[mirror]
                            if mirrorData then
                                CharacterManager.updatePart(mirror,
                                    { shape8URL = mirrorData.shape8URL,
                                      sx = mirrorData.dims.sx or 1, sy = syVal }, instance)
                            end
                        end
                    end
                    CharacterManager.addTexturesFromInstance2(instance)
                end
                y = y + ROW
                -- NOTE: h/w sliders are NOT shown here for SHAPE8 parts.
                -- SHAPE8 physics shapes come from pre-computed vertices in shape8Dict,
                -- scaled only by sx/sy. The dims.h and dims.w values are vestigial for
                -- SHAPE8 parts — they don't affect the physics shape, textures, or joint
                -- anchors. Only CAPSULE parts (arms, legs, neck) use h/w for their shape.
            end)
        end

        -- === CAPSULE DIMENSIONS (arms, legs, neck) ===
        -- Only CAPSULE parts use h/w for their physics shape. h controls the length
        -- of the capsule polygon and is used for joint anchor positioning (±h/2).
        -- w controls the width. SHAPE8 parts ignore h/w entirely — their shape comes
        -- from pre-computed vertices scaled by sx/sy.
        local limbData = instance.dna.parts[partName]
        if limbData and limbData.shape == ST.CAPSULE and limbData.dims then
            drawAccordion(partName .. ' dims', function()
                if limbData.dims.h then
                    local hVal = ui.sliderWithInput('mipo_limb_h', x, y, 120, 10, 1500, limbData.dims.h or 100)
                    ui.alignedLabel(x, y, '  h')
                    hVal = hVal and tonumber(hVal)
                    if hVal and hVal ~= limbData.dims.h then
                        CharacterManager.updatePart(partName, { h = hVal }, instance)
                        if accordionStates.symmetricEditing then
                            local mirror = getMirrorPart(partName)
                            if mirror and instance.dna.parts[mirror] then
                                CharacterManager.updatePart(mirror, { h = hVal }, instance)
                            end
                        end
                        CharacterManager.addTexturesFromInstance2(instance)
                    end
                    y = y + ROW
                end
                if limbData.dims.w then
                    local wVal = ui.sliderWithInput('mipo_limb_w', x, y, 120, 5, 500, limbData.dims.w or 40)
                    ui.alignedLabel(x, y, '  w')
                    wVal = wVal and tonumber(wVal)
                    if wVal and wVal ~= limbData.dims.w then
                        CharacterManager.updatePart(partName, { w = wVal }, instance)
                        if accordionStates.symmetricEditing then
                            local mirror = getMirrorPart(partName)
                            if mirror and instance.dna.parts[mirror] then
                                CharacterManager.updatePart(mirror, { w = wVal }, instance)
                            end
                        end
                        CharacterManager.addTexturesFromInstance2(instance)
                    end
                    y = y + ROW
                end
            end)
        end

        -- === SKIN ACCORDION ===
        local partData = instance.dna.parts[partName]
        if partData and partData.appearance and partData.appearance['skin'] then
            drawAccordion(partName .. ' skin', function()
                local skin = partData.appearance['skin']
                local patches = { 'main', 'patch1', 'patch2', 'patch3' }
                -- Skin uses full OMP (Outline + Mask + Pattern) composite rendering:
                --   bg/outline: tints the hand-drawn outline strokes
                --   fg/fill:    tints the interior via grayscale mask
                --   p/pattern:  tints the decorative pattern overlay (from textures/pat/)
                for _, patch in ipairs(patches) do
                    if skin[patch] then
                        -- Wrap patch1/2/3 in sub-accordions; main is always visible
                        local showPatch = true
                        if patch ~= 'main' then
                            local patchKey = partName .. '_skin_' .. patch
                            local clicked = ui.header_button(x, y, panelWidth - 40,
                                (accordionStates[patchKey] and " ÷  " or " •") .. ' ' .. patch,
                                accordionStates[patchKey])
                            if clicked then
                                accordionStates[patchKey] = not accordionStates[patchKey]
                            end
                            y = y + ROW
                            showPatch = accordionStates[patchKey]
                        else
                            ui.label(x, y, patch)
                            y = y + ROW
                        end

                        if showPatch then
                        -- Shape selection grid and transform sliders for patches (not main)
                        if patch ~= 'main' then
                            local currentBG = skin[patch].bgURL or ''
                            local cellSize = 50
                            local gridHeight = drawThumbnailGrid(patchShapes, currentBG, panelX, y, cellSize,
                                function(url)
                                    if url then
                                        local base = url:gsub('%.png$', '')
                                        local vals = { bgURL = base .. '.png', fgURL = base .. '-mask.png' }
                                        CharacterManager.updateSkinOfPart(instance, partName, vals, patch)
                                        if accordionStates.symmetricEditing then
                                            local mirror = getMirrorPart(partName)
                                            if mirror and instance.dna.parts[mirror] then
                                                CharacterManager.updateSkinOfPart(instance, mirror, vals, patch)
                                            end
                                        end
                                    else
                                        CharacterManager.updateSkinOfPart(instance, partName,
                                            { bgURL = '', fgURL = '' }, patch)
                                        if accordionStates.symmetricEditing then
                                            local mirror = getMirrorPart(partName)
                                            if mirror and instance.dna.parts[mirror] then
                                                CharacterManager.updateSkinOfPart(instance, mirror,
                                                    { bgURL = '', fgURL = '' }, patch)
                                            end
                                        end
                                    end
                                    CharacterManager.addTexturesFromInstance2(instance)
                                end, true)
                            y = y + gridHeight + 4

                            local patchId = partName .. '_' .. patch
                            local sliders = {
                                { id = 'tx',  label = 'x',    min = -6, max = 6, default = 0 },
                                { id = 'ty',  label = 'y',    min = -6, max = 6, default = 0 },
                                { id = 'sx',  label = 'sx',   min = 0.25, max = 3, default = 1 },
                                { id = 'sy',  label = 'sy',   min = 0.25, max = 3, default = 1 },
                                { id = 'r',   label = 'rot',  min = 0, max = 15, default = 0, step = 1 },
                            }
                            for _, s in ipairs(sliders) do
                                ui.alignedLabel(x, y, s.label)
                                local val = ui.sliderWithInput('mipo_' .. patchId .. '_' .. s.id,
                                    x + 30, y, 120, s.min, s.max, skin[patch][s.id] or s.default, false, s.step)
                                if val ~= (skin[patch][s.id] or s.default) then
                                    CharacterManager.updateSkinOfPart(instance, partName, { [s.id] = val }, patch)
                                    if accordionStates.symmetricEditing then
                                        local mirror = getMirrorPart(partName)
                                        if mirror and instance.dna.parts[mirror] then
                                            CharacterManager.updateSkinOfPart(instance, mirror, { [s.id] = val }, patch)
                                        end
                                    end
                                    CharacterManager.addTexturesFromInstance2(instance)
                                end
                                y = y + ROW
                            end
                        end

                        handlePaletteButton('mipo_bg_' .. partName .. '_' .. patch,
                            x + 30, y, 140, skin[patch].bgHex, function(color)
                                CharacterManager.updateSkinOfPart(instance, partName, { bgHex = color }, patch)
                                if accordionStates.symmetricEditing then
                                    local mirror = getMirrorPart(partName)
                                    if mirror and instance.dna.parts[mirror] then
                                        CharacterManager.updateSkinOfPart(instance, mirror, { bgHex = color }, patch)
                                    end
                                end
                                CharacterManager.addTexturesFromInstance2(instance)
                            end)
                        ui.alignedLabel(x + 180, y, 'outline')
                        y = y + ROW

                        handlePaletteButton('mipo_fg_' .. partName .. '_' .. patch,
                            x + 30, y, 140, skin[patch].fgHex, function(color)
                                CharacterManager.updateSkinOfPart(instance, partName, { fgHex = color }, patch)
                                if accordionStates.symmetricEditing then
                                    local mirror = getMirrorPart(partName)
                                    if mirror and instance.dna.parts[mirror] then
                                        CharacterManager.updateSkinOfPart(instance, mirror, { fgHex = color }, patch)
                                    end
                                end
                                CharacterManager.addTexturesFromInstance2(instance)
                            end)
                        ui.alignedLabel(x + 180, y, 'fill')
                        y = y + ROW

                        y = drawPatternControls(skin[patch], 'mipo_pat_' .. partName .. '_' .. patch, panelX, y,
                            function(key, value)
                                CharacterManager.updateSkinOfPart(instance, partName, { [key] = value }, patch)
                                if accordionStates.symmetricEditing then
                                    local mirror = getMirrorPart(partName)
                                    if mirror and instance.dna.parts[mirror] then
                                        CharacterManager.updateSkinOfPart(instance, mirror, { [key] = value }, patch)
                                    end
                                end
                                CharacterManager.addTexturesFromInstance2(instance)
                            end)
                        end -- if showPatch
                    end
                end
            end)
        end

        -- === BODYHAIR ACCORDION ===
        -- Bodyhair is per-part (head has its own, each torso segment has its own).
        -- For torso parts, changes propagate to all torso segments for consistency.
        -- For head (or other parts), changes only affect that part.
        if partData and partData.appearance and partData.appearance['bodyhair'] then
            local isTorso = partName:match('^torso')
            drawAccordion(partName .. ' bodyhair', function()
                local bh = partData.appearance['bodyhair']
                if bh['main'] then
                    local currentBG = bh['main'].bgURL or ''
                    local cellSize = 50
                    local gridHeight = drawThumbnailGrid(bodyhairTextures, currentBG, panelX, y, cellSize,
                        function(url)
                            local function clearOrSet(pn)
                                local bhPatch = instance.dna.parts[pn].appearance['bodyhair'].main
                                if url then
                                    bhPatch.bgURL = url
                                    bhPatch.fgURL = url:gsub('%.png', '-mask.png')
                                else
                                    bhPatch.bgURL = nil
                                    bhPatch.fgURL = nil
                                end
                                bhPatch.cached = nil
                            end
                            if isTorso then
                                local count = instance.dna.creation.torsoSegments or 1
                                for i = 1, count do
                                    clearOrSet('torso' .. i)
                                end
                            else
                                clearOrSet(partName)
                                if accordionStates.symmetricEditing then
                                    local mirror = getMirrorPart(partName)
                                    if mirror and instance.dna.parts[mirror]
                                        and instance.dna.parts[mirror].appearance
                                        and instance.dna.parts[mirror].appearance['bodyhair'] then
                                        clearOrSet(mirror)
                                    end
                                end
                            end
                            CharacterManager.addTexturesFromInstance2(instance)
                        end, true)
                    y = y + gridHeight + BUTTON_SPACING

                    -- bodyhair colors (2-layer: outline + fill, no pattern)
                    handlePaletteButton('mipo_bh_bg_' .. partName,
                        x + 30, y, 140, bh['main'].bgHex, function(color)
                            if isTorso then
                                local count = instance.dna.creation.torsoSegments or 1
                                for i = 1, count do
                                    CharacterManager.updateBodyhairOfPart(instance, 'torso' .. i, { bgHex = color })
                                end
                            else
                                CharacterManager.updateBodyhairOfPart(instance, partName, { bgHex = color })
                                if accordionStates.symmetricEditing then
                                    local mirror = getMirrorPart(partName)
                                    if mirror and instance.dna.parts[mirror] then
                                        CharacterManager.updateBodyhairOfPart(instance, mirror, { bgHex = color })
                                    end
                                end
                            end
                            CharacterManager.addTexturesFromInstance2(instance)
                        end)
                    ui.alignedLabel(x + 180, y, 'outline')
                    y = y + ROW

                    handlePaletteButton('mipo_bh_fg_' .. partName,
                        x + 30, y, 140, bh['main'].fgHex, function(color)
                            if isTorso then
                                local count = instance.dna.creation.torsoSegments or 1
                                for i = 1, count do
                                    CharacterManager.updateBodyhairOfPart(instance, 'torso' .. i, { fgHex = color })
                                end
                            else
                                CharacterManager.updateBodyhairOfPart(instance, partName, { fgHex = color })
                                if accordionStates.symmetricEditing then
                                    local mirror = getMirrorPart(partName)
                                    if mirror and instance.dna.parts[mirror] then
                                        CharacterManager.updateBodyhairOfPart(instance, mirror, { fgHex = color })
                                    end
                                end
                            end
                            CharacterManager.addTexturesFromInstance2(instance)
                        end)
                    ui.alignedLabel(x + 180, y, 'fill')
                    y = y + ROW

                    -- Growfactor slider (how much bigger bodyhair is relative to the body)
                    local currentGrow = bh.growfactor or 1.2
                    ui.alignedLabel(x, y, 'grow')
                    local newGrow = ui.slider(
                        x + 40, y, 200, 20, 'horizontal', 0.5, 2.5, currentGrow, 'mipo_bh_grow_' .. partName)
                    if newGrow then
                        local function setGrow(pn)
                            instance.dna.parts[pn].appearance['bodyhair'].growfactor = newGrow
                        end
                        if isTorso then
                            local count = instance.dna.creation.torsoSegments or 1
                            for i = 1, count do
                                setGrow('torso' .. i)
                            end
                        else
                            setGrow(partName)
                            if accordionStates.symmetricEditing then
                                local mirror = getMirrorPart(partName)
                                if mirror and instance.dna.parts[mirror]
                                    and instance.dna.parts[mirror].appearance
                                    and instance.dna.parts[mirror].appearance['bodyhair'] then
                                    setGrow(mirror)
                                end
                            end
                        end
                        CharacterManager.rebuildFromCreation(instance, {})
                    end
                    y = y + ROW
                end
            end)
        end

        -- === FACE ACCORDION (eyes + pupils) ===
        -- Face decals render on head (non-potato) or torso1 (potato).
        local faceOwner = nil
        if instance.dna.creation.isPotatoHead and partName:match('^torso') then
            faceOwner = 'torso1'
        elseif not instance.dna.creation.isPotatoHead and partName == 'head' then
            faceOwner = 'head'
        end
        local faceData = faceOwner and instance.dna.parts[faceOwner]
        if faceData and faceData.appearance and faceData.appearance['face'] then
            drawAccordion(partName .. ' face', function()
                local face = faceData.appearance['face']

                drawAccordion(partName .. ' face > eyes', function()
                    y = drawFaceEyesUI(instance, faceOwner, partName, face, x, y, panelX, ROW)
                end)

                drawAccordion(partName .. ' face > brows', function()
                    y = drawFaceBrowsUI(instance, faceOwner, partName, face, x, y, panelX, ROW)
                end)

                local noseSegs = instance.dna.creation.noseSegments or 0
                local nMode = instance.dna.creation.noseMode or 'overlay'
                local isPhysicsNose = (noseSegs >= 2) or (noseSegs == 1 and nMode == 'physics')
                if isPhysicsNose then
                    drawAccordion(partName .. ' face > nose (physics)', function()
                        local nose1Data = instance.dna.parts['nose1']
                        if not nose1Data then return end

                        -- Dimension sliders (w, h)
                        -- Uses rebuildFromCreation so nose chain repositions correctly
                        local currentW = nose1Data.dims and nose1Data.dims.w or 40
                        local nw = ui.sliderWithInput('mipo_nose_w', x, y, 120, 5, 500, currentW)
                        ui.alignedLabel(x, y, '  nose width')
                        nw = nw and tonumber(nw)
                        if nw and nw ~= currentW then
                            for i = 1, noseSegs do
                                instance.dna.parts['nose' .. i].dims.w = nw
                            end
                            CharacterManager.rebuildFromCreation(instance, {})
                            CharacterManager.addTexturesFromInstance2(instance)
                        end
                        y = y + ROW

                        local currentH = nose1Data.dims and nose1Data.dims.h or 40
                        local nh = ui.sliderWithInput('mipo_nose_h', x, y, 120, 5, 500, currentH)
                        ui.alignedLabel(x, y, '  nose height')
                        nh = nh and tonumber(nh)
                        if nh and nh ~= currentH then
                            for i = 1, noseSegs do
                                instance.dna.parts['nose' .. i].dims.h = nh
                            end
                            CharacterManager.rebuildFromCreation(instance, {})
                            CharacterManager.addTexturesFromInstance2(instance)
                        end
                        y = y + ROW

                        -- Connected-skin texture controls (segmented nose, 2+)
                        if noseSegs >= 2 and nose1Data.appearance and nose1Data.appearance['connected-skin'] then
                            local cs = nose1Data.appearance['connected-skin'].main
                            if cs then
                                ui.label(x, y, 'connected skin')
                                y = y + ROW

                                local currentURL = cs.bgURL or ''
                                local cellSize = 50
                                local gridHeight = drawThumbnailGrid(limbSkinTextures, currentURL, panelX, y, cellSize,
                                    function(url)
                                        local vals = { bgURL = url, fgURL = url:gsub('%.png', '-mask.png') }
                                        CharacterManager.updateConnectedAppearance(instance, 'nose1', 'connected-skin', vals)
                                        CharacterManager.addTexturesFromInstance2(instance)
                                    end)
                                y = y + gridHeight + BUTTON_SPACING

                                local currentWmul = cs.wmul or instance.scale or 1
                                local wmulVal = ui.sliderWithInput('mipo_nose_cs_wmul', x, y, 120, 0.1, 10, currentWmul)
                                ui.alignedLabel(x, y, '  width')
                                wmulVal = wmulVal and tonumber(wmulVal)
                                if wmulVal and wmulVal ~= currentWmul then
                                    CharacterManager.updateConnectedAppearance(instance, 'nose1', 'connected-skin',
                                        { wmul = wmulVal })
                                    CharacterManager.addTexturesFromInstance2(instance)
                                end
                                y = y + ROW

                                handlePaletteButton('mipo_nose_cs_bg',
                                    x + 30, y, 140, cs.bgHex, function(color)
                                        CharacterManager.updateConnectedAppearance(instance, 'nose1', 'connected-skin',
                                            { bgHex = color })
                                        CharacterManager.addTexturesFromInstance2(instance)
                                    end)
                                ui.alignedLabel(x + 180, y, 'outline')
                                y = y + ROW

                                handlePaletteButton('mipo_nose_cs_fg',
                                    x + 30, y, 140, cs.fgHex, function(color)
                                        CharacterManager.updateConnectedAppearance(instance, 'nose1', 'connected-skin',
                                            { fgHex = color })
                                        CharacterManager.addTexturesFromInstance2(instance)
                                    end)
                                ui.alignedLabel(x + 180, y, 'fill')
                                y = y + ROW

                                y = drawPatternControls(cs, 'mipo_nose_cs_pat', panelX, y,
                                    function(key, value)
                                        CharacterManager.updateConnectedAppearance(instance, 'nose1', 'connected-skin',
                                            { [key] = value })
                                        CharacterManager.addTexturesFromInstance2(instance)
                                    end)
                            end
                        end

                        -- Skin texture controls (single physics nose, noseSegments == 1)
                        if noseSegs == 1 and nose1Data.appearance and nose1Data.appearance['skin'] then
                            local skin = nose1Data.appearance['skin']
                            if skin.main then
                                ui.label(x, y, 'skin')
                                y = y + ROW

                                handlePaletteButton('mipo_nose_skin_bg',
                                    x + 30, y, 140, skin.main.bgHex, function(color)
                                        CharacterManager.updateSkinOfPart(instance, 'nose1', { bgHex = color }, 'main')
                                        CharacterManager.addTexturesFromInstance2(instance)
                                    end)
                                ui.alignedLabel(x + 180, y, 'outline')
                                y = y + ROW

                                handlePaletteButton('mipo_nose_skin_fg',
                                    x + 30, y, 140, skin.main.fgHex, function(color)
                                        CharacterManager.updateSkinOfPart(instance, 'nose1', { fgHex = color }, 'main')
                                        CharacterManager.addTexturesFromInstance2(instance)
                                    end)
                                ui.alignedLabel(x + 180, y, 'fill')
                                y = y + ROW

                                y = drawPatternControls(skin.main, 'mipo_nose_skin_pat', panelX, y,
                                    function(key, value)
                                        CharacterManager.updateSkinOfPart(instance, 'nose1', { [key] = value }, 'main')
                                        CharacterManager.addTexturesFromInstance2(instance)
                                    end)
                            end
                        end
                    end)
                else
                    drawAccordion(partName .. ' face > nose', function()
                        y = drawFaceNoseUI(instance, faceOwner, partName, face, x, y, panelX, ROW)
                    end)
                end

                drawAccordion(partName .. ' face > mouth', function()
                    y = drawFaceMouthUI(instance, faceOwner, partName, face, x, y, panelX, ROW)
                end)
            end)
        end

        -- === HAIRCUT ACCORDION ===
        -- Haircut renders on head (non-potato) or torso1 (potato). It traces along
        -- the shape outline between startIndex and endIndex with a hair texture.
        local haircutOwner = nil
        if instance.dna.creation.isPotatoHead and partName:match('^torso') then
            haircutOwner = 'torso1'
        elseif not instance.dna.creation.isPotatoHead and partName == 'head' then
            haircutOwner = 'head'
        end
        local haircutData = haircutOwner and instance.dna.parts[haircutOwner]
        if haircutData and haircutData.appearance and haircutData.appearance['haircut'] then
            drawAccordion(partName .. ' haircut', function()
                local hc = haircutData.appearance['haircut']
                local main = hc.main
                if main then
                    -- Texture thumbnail grid
                    local currentURL = main.bgURL or ''
                    local cellSize = 50
                    local gridHeight = drawThumbnailGrid(haircutTextures, currentURL, panelX, y, cellSize,
                        function(url)
                            if url then
                                local fgUrl = hairsWithMask[url] and url:gsub('%.png', '-mask.png') or ''
                                CharacterManager.updateHaircutOfPart(instance, haircutOwner,
                                    { bgURL = url, fgURL = fgUrl })
                            else
                                main.bgURL = nil
                                main.fgURL = nil
                                main.cached = nil
                            end
                            CharacterManager.addTexturesFromInstance2(instance)
                        end, true)
                    y = y + gridHeight + BUTTON_SPACING

                    -- width slider
                    local currentWidth = hc.width or 250
                    local wVal = ui.sliderWithInput('mipo_hc_w', x, y, 120, 10, 800, currentWidth)
                    ui.alignedLabel(x, y, '  width')
                    wVal = wVal and tonumber(wVal)
                    if wVal and wVal ~= currentWidth then
                        CharacterManager.updateHaircutOfPart(instance, haircutOwner, { width = wVal })
                        CharacterManager.addTexturesFromInstance2(instance)
                    end
                    y = y + ROW

                    -- startIndex / endIndex sliders
                    local si = ui.sliderWithInput('mipo_hc_si', x, y, 120, 0, 16, hc.startIndex or 6, false, 1)
                    ui.alignedLabel(x, y, '  start')
                    si = si and tonumber(si)
                    if si then
                        si = math.floor(si)
                        if si ~= hc.startIndex then
                            CharacterManager.updateHaircutOfPart(instance, haircutOwner, { startIndex = si })
                            CharacterManager.addTexturesFromInstance2(instance)
                        end
                    end
                    y = y + ROW

                    local ei = ui.sliderWithInput('mipo_hc_ei', x, y, 120, 0, 16, hc.endIndex or 2, false, 1)
                    ui.alignedLabel(x, y, '  end')
                    ei = ei and tonumber(ei)
                    if ei then
                        ei = math.floor(ei)
                        if ei ~= hc.endIndex then
                            CharacterManager.updateHaircutOfPart(instance, haircutOwner, { endIndex = ei })
                            CharacterManager.addTexturesFromInstance2(instance)
                        end
                    end
                    y = y + ROW

                    -- Color (tints the hair outline)
                    handlePaletteButton('mipo_hc_bg_' .. partName,
                        x + 30, y, 140, main.bgHex, function(color)
                            CharacterManager.updateHaircutOfPart(instance, haircutOwner, { bgHex = color })
                            CharacterManager.addTexturesFromInstance2(instance)
                        end)
                    ui.alignedLabel(x + 180, y, 'outline')
                    y = y + ROW

                    -- OMP controls (fill + pattern) only for masked hair textures
                    if main.fgURL and main.fgURL ~= '' then
                        handlePaletteButton('mipo_hc_fg_' .. partName,
                            x + 30, y, 140, main.fgHex or 'ffffffff', function(color)
                                CharacterManager.updateHaircutOfPart(instance, haircutOwner, { fgHex = color })
                                CharacterManager.addTexturesFromInstance2(instance)
                            end)
                        ui.alignedLabel(x + 180, y, 'fill')
                        y = y + ROW

                        y = drawPatternControls(main, 'mipo_hc_pat_' .. partName, panelX, y,
                            function(key, value)
                                CharacterManager.updateHaircutOfPart(instance, haircutOwner, { [key] = value })
                                CharacterManager.addTexturesFromInstance2(instance)
                            end)
                    end
                end
            end)
        end

        -- === CONNECTED-SKIN ACCORDION (arms, legs) ===
        -- Connected textures stretch between joint-linked parts (e.g. shoulder to hand).
        -- They're defined on the upper limb (luarm, ruleg, etc.) but we show them for
        -- any part in the limb chain (lower arm, hand, foot, etc.) via getLimbRoot().
        -- connected-skin uses OMP compositing (outline + fill + pattern).
        local connSkinOwner = partName
        if not (partData and partData.appearance and partData.appearance['connected-skin']) then
            connSkinOwner = getLimbRoot(partName)
        end
        local connSkinData = connSkinOwner and instance.dna.parts[connSkinOwner]
        -- Hide neck connected-skin when there are no neck segments
        local connSkinEndNode = connSkinData and connSkinData.appearance
            and connSkinData.appearance['connected-skin']
            and connSkinData.appearance['connected-skin'].endNode
        local hideConnSkin = connSkinEndNode == 'head'
            and instance.dna.creation.neckSegments == 0
        if not hideConnSkin and connSkinData and connSkinData.appearance and connSkinData.appearance['connected-skin'] then
            local connLabel = connSkinData.appearance['connected-skin'].endNode
                and (partName .. ' > ' .. connSkinData.appearance['connected-skin'].endNode .. ' skin')
                or (partName .. ' connected skin')
            drawAccordion(connLabel, function()
                local cs = connSkinData.appearance['connected-skin'].main
                if cs then
                    -- Texture thumbnail grid
                    local currentURL = cs.bgURL or ''
                    local cellSize = 50
                    local csMirror = accordionStates.symmetricEditing and getMirrorPart(connSkinOwner) or nil
                    local gridHeight = drawThumbnailGrid(limbSkinTextures, currentURL, panelX, y, cellSize,
                        function(url)
                            local vals = { bgURL = url, fgURL = url:gsub('%.png', '-mask.png') }
                            CharacterManager.updateConnectedAppearance(instance, connSkinOwner, 'connected-skin', vals)
                            if csMirror and instance.dna.parts[csMirror] then
                                CharacterManager.updateConnectedAppearance(instance, csMirror, 'connected-skin', vals)
                            end
                            CharacterManager.addTexturesFromInstance2(instance)
                        end)
                    y = y + gridHeight + BUTTON_SPACING

                    -- wmul (width multiplier) slider
                    local currentWmul = cs.wmul or instance.scale or 1
                    local wmulVal = ui.sliderWithInput('mipo_cs_wmul_' .. partName, x, y, 120, 0.1, 10,
                        currentWmul)
                    ui.alignedLabel(x, y, '  width')
                    wmulVal = wmulVal and tonumber(wmulVal)
                    if wmulVal and wmulVal ~= currentWmul then
                        CharacterManager.updateConnectedAppearance(instance, connSkinOwner, 'connected-skin',
                            { wmul = wmulVal })
                        if csMirror and instance.dna.parts[csMirror] then
                            CharacterManager.updateConnectedAppearance(instance, csMirror, 'connected-skin',
                                { wmul = wmulVal })
                        end
                        CharacterManager.addTexturesFromInstance2(instance)
                    end
                    y = y + ROW

                    handlePaletteButton('mipo_cs_bg_' .. partName,
                        x + 30, y, 140, cs.bgHex, function(color)
                            CharacterManager.updateConnectedAppearance(instance, connSkinOwner, 'connected-skin',
                                { bgHex = color })
                            if csMirror and instance.dna.parts[csMirror] then
                                CharacterManager.updateConnectedAppearance(instance, csMirror, 'connected-skin',
                                    { bgHex = color })
                            end
                            CharacterManager.addTexturesFromInstance2(instance)
                        end)
                    ui.alignedLabel(x + 180, y, 'outline')
                    y = y + ROW

                    handlePaletteButton('mipo_cs_fg_' .. partName,
                        x + 30, y, 140, cs.fgHex, function(color)
                            CharacterManager.updateConnectedAppearance(instance, connSkinOwner, 'connected-skin',
                                { fgHex = color })
                            if csMirror and instance.dna.parts[csMirror] then
                                CharacterManager.updateConnectedAppearance(instance, csMirror, 'connected-skin',
                                    { fgHex = color })
                            end
                            CharacterManager.addTexturesFromInstance2(instance)
                        end)
                    ui.alignedLabel(x + 180, y, 'fill')
                    y = y + ROW

                    y = drawPatternControls(cs, 'mipo_cs_pat_' .. partName, panelX, y,
                        function(key, value)
                            CharacterManager.updateConnectedAppearance(instance, connSkinOwner, 'connected-skin',
                                { [key] = value })
                            if csMirror and instance.dna.parts[csMirror] then
                                CharacterManager.updateConnectedAppearance(instance, csMirror, 'connected-skin',
                                    { [key] = value })
                            end
                            CharacterManager.addTexturesFromInstance2(instance)
                        end)
                end
            end)
        end

        -- === CONNECTED-HAIR ACCORDION (arms, legs) ===
        -- connected-hair is 2-layer by default; hair7/hair8 have masks (OMP with pattern).
        local connHairOwner = partName
        if not (partData and partData.appearance and partData.appearance['connected-hair']) then
            connHairOwner = getLimbRoot(partName)
        end
        local connHairData = connHairOwner and instance.dna.parts[connHairOwner]
        -- Hide neck connected-hair when there are no neck segments
        local connHairEndNode = connHairData and connHairData.appearance
            and connHairData.appearance['connected-hair']
            and connHairData.appearance['connected-hair'].endNode
        local hideConnHair = connHairEndNode == 'head'
            and instance.dna.creation.neckSegments == 0
        if not hideConnHair and connHairData and connHairData.appearance and connHairData.appearance['connected-hair'] then
            local connHairLabel = connHairData.appearance['connected-hair'].endNode
                and (partName .. ' > ' .. connHairData.appearance['connected-hair'].endNode .. ' hair')
                or (partName .. ' connected hair')
            drawAccordion(connHairLabel, function()
                local ch = connHairData.appearance['connected-hair'].main
                if ch then
                    -- Texture thumbnail grid
                    local currentURL = ch.bgURL or ''
                    local cellSize = 50
                    local chMirror = accordionStates.symmetricEditing and getMirrorPart(connHairOwner) or nil
                    local gridHeight = drawThumbnailGrid(limbHairTextures, currentURL, panelX, y, cellSize,
                        function(url)
                            local fgUrl = url and hairsWithMask[url] and url:gsub('%.png', '-mask.png') or ''
                            local vals = { bgURL = url or '', fgURL = fgUrl }
                            CharacterManager.updateConnectedAppearance(instance, connHairOwner, 'connected-hair', vals)
                            if chMirror and instance.dna.parts[chMirror] then
                                CharacterManager.updateConnectedAppearance(instance, chMirror, 'connected-hair', vals)
                            end
                            CharacterManager.addTexturesFromInstance2(instance)
                        end, true)
                    y = y + gridHeight + BUTTON_SPACING

                    -- wmul (width multiplier) slider
                    local currentWmul = ch.wmul or instance.scale or 1
                    local wmulVal = ui.sliderWithInput('mipo_ch_wmul_' .. partName, x, y, 120, 0.1, 10,
                        currentWmul)
                    ui.alignedLabel(x, y, '  width')
                    wmulVal = wmulVal and tonumber(wmulVal)
                    if wmulVal and wmulVal ~= currentWmul then
                        CharacterManager.updateConnectedAppearance(instance, connHairOwner, 'connected-hair',
                            { wmul = wmulVal })
                        if chMirror and instance.dna.parts[chMirror] then
                            CharacterManager.updateConnectedAppearance(instance, chMirror, 'connected-hair',
                                { wmul = wmulVal })
                        end
                        CharacterManager.addTexturesFromInstance2(instance)
                    end
                    y = y + ROW

                    -- Outline color
                    handlePaletteButton('mipo_ch_bg_' .. partName,
                        x + 30, y, 140, ch.bgHex, function(color)
                            CharacterManager.updateConnectedAppearance(instance, connHairOwner, 'connected-hair',
                                { bgHex = color })
                            if chMirror and instance.dna.parts[chMirror] then
                                CharacterManager.updateConnectedAppearance(instance, chMirror, 'connected-hair',
                                    { bgHex = color })
                            end
                            CharacterManager.addTexturesFromInstance2(instance)
                        end)
                    ui.alignedLabel(x + 180, y, 'outline')
                    y = y + ROW

                    -- OMP controls (fill + pattern) only for masked hair textures
                    if ch.fgURL and ch.fgURL ~= '' then
                        handlePaletteButton('mipo_ch_fg_' .. partName,
                            x + 30, y, 140, ch.fgHex or 'ffffffff', function(color)
                                CharacterManager.updateConnectedAppearance(instance, connHairOwner, 'connected-hair',
                                    { fgHex = color })
                                if chMirror and instance.dna.parts[chMirror] then
                                    CharacterManager.updateConnectedAppearance(instance, chMirror, 'connected-hair',
                                        { fgHex = color })
                                end
                                CharacterManager.addTexturesFromInstance2(instance)
                            end)
                        ui.alignedLabel(x + 180, y, 'fill')
                        y = y + ROW

                        y = drawPatternControls(ch, 'mipo_ch_pat_' .. partName, panelX, y,
                            function(key, value)
                                CharacterManager.updateConnectedAppearance(instance, connHairOwner, 'connected-hair',
                                    { [key] = value })
                                if chMirror and instance.dna.parts[chMirror] then
                                    CharacterManager.updateConnectedAppearance(instance, chMirror, 'connected-hair',
                                        { [key] = value })
                                end
                                CharacterManager.addTexturesFromInstance2(instance)
                            end)
                    end
                end
            end)
        end

        -- === RANDOMIZE BUTTON ===
        y = y + BUTTON_SPACING
        love.graphics.line(x, y, x + panelWidth - 40, y)
        y = y + BUTTON_SPACING
        if ui.button(x, y, panelWidth - 40, 'randomize') then
            CharacterManager.randomizeMipo(instance)
        end
        y = y + ROW

        -- === DISSOLVE BUTTON ===
        if ui.button(x, y, panelWidth - 40, 'dissolve') then
            for pName, part in pairs(instance.parts) do
                if part and part.body and not part.body:isDestroyed() then
                    local ud = part.body:getUserData()
                    if ud and ud.thing then
                        ud.thing.mipoId = nil
                        ud.thing.mipoPartName = nil
                    end
                end
                local _ = pName
            end
            mipoRegistry.unregister(instance.id)
        end
        y = y + ROW

        return y - startY
    end)
end

return lib

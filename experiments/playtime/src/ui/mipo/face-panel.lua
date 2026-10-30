-- src/ui/mipo/face-panel.lua (split from ui/mipo-editor.lua, SPLIT3)
local lib = {}

local CharacterManager = require('src.character-manager')
local mouthShapes = require('src.mouth-shapes')
local C = require('src.shape-catalogs')
local topology = require('src.character-topology')
local widgets = require('src.ui.mipo.widgets')
local ui = widgets.ui
local drawThumbnailGrid, handlePaletteButton = widgets.drawThumbnailGrid, widgets.handlePaletteButton
local drawPatternControls = widgets.drawPatternControls
local BUTTON_SPACING = ui.theme.spacing
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
                CharacterManager.rebuildTextures(instance)
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
                CharacterManager.rebuildTextures(instance)
            end
        end
    end)
    y = y + gridHeight + BUTTON_SPACING

    -- Eye position sliders
    local eyeX = ui.sliderWithInput('mipo_eye_x', x, y, 120, 0, 0.5, eyePos.x)
    ui.alignedLabel(x, y, '  eye spacing')
    if eyeX and eyeX ~= eyePos.x then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeX = eyeX })
        CharacterManager.rebuildTextures(instance)
    end
    y = y + ROW

    local eyeY = ui.sliderWithInput('mipo_eye_y', x, y, 120, 0, 1, eyePos.y)
    ui.alignedLabel(x, y, '  eye vertical')
    if eyeY and eyeY ~= eyePos.y then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeY = eyeY })
        CharacterManager.rebuildTextures(instance)
    end
    y = y + ROW

    -- Eye rotation
    local eyeRVal = ui.sliderWithInput('mipo_eye_r', x, y, 120, -2, 2, eyePos.r)
    ui.alignedLabel(x, y, '  eye rotation')
    if eyeRVal and eyeRVal ~= eyePos.r then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeR = eyeRVal })
        CharacterManager.rebuildTextures(instance)
    end
    y = y + ROW

    -- Eye size sliders
    local ewMul = ui.sliderWithInput('mipo_eye_wmul', x, y, 120, 0.25, 2, eye.wMul)
    ui.alignedLabel(x, y, '  eye width')
    if ewMul and ewMul ~= eye.wMul then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeWMul = ewMul })
        CharacterManager.rebuildTextures(instance)
    end
    y = y + ROW

    local ehMul = ui.sliderWithInput('mipo_eye_hmul', x, y, 120, 0.25, 2, eye.hMul)
    ui.alignedLabel(x, y, '  eye height')
    if ehMul and ehMul ~= eye.hMul then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeHMul = ehMul })
        CharacterManager.rebuildTextures(instance)
    end
    y = y + ROW

    -- Pupil size sliders
    local pwMul = ui.sliderWithInput('mipo_pupil_wmul', x, y, 120, 0.1, 1, pupil.wMul)
    ui.alignedLabel(x, y, '  pupil width')
    if pwMul and pwMul ~= pupil.wMul then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { pupilWMul = pwMul })
        CharacterManager.rebuildTextures(instance)
    end
    y = y + ROW

    local phMul = ui.sliderWithInput('mipo_pupil_hmul', x, y, 120, 0.1, 1, pupil.hMul)
    ui.alignedLabel(x, y, '  pupil height')
    if phMul and phMul ~= pupil.hMul then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { pupilHMul = phMul })
        CharacterManager.rebuildTextures(instance)
    end
    y = y + ROW

    -- Eye color
    handlePaletteButton('mipo_eye_bg_' .. partName,
        x + 30, y, 140, eye.bgHex, function(color)
            CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeBgHex = color })
            CharacterManager.rebuildTextures(instance)
        end)
    ui.alignedLabel(x + 180, y, 'eye outline')
    y = y + ROW

    handlePaletteButton('mipo_eye_fg_' .. partName,
        x + 30, y, 140, eye.fgHex, function(color)
            CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeFgHex = color })
            CharacterManager.rebuildTextures(instance)
        end)
    ui.alignedLabel(x + 180, y, 'eye fill')
    y = y + ROW

    -- Pupil color
    handlePaletteButton('mipo_pupil_bg_' .. partName,
        x + 30, y, 140, pupil.bgHex, function(color)
            CharacterManager.updateFaceOfPart(instance, faceOwner, { pupilBgHex = color })
            CharacterManager.rebuildTextures(instance)
        end)
    ui.alignedLabel(x + 180, y, 'pupil color')
    y = y + ROW

    local lookClicked, lookChecked = ui.checkbox(x, y, eye.lookAtMouse, 'pupils follow mouse')
    if lookClicked then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeLookAtMouse = lookChecked })
        CharacterManager.rebuildTextures(instance)
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
                CharacterManager.rebuildTextures(instance)
            end
        end
    end)
    y = y + gridHeight + BUTTON_SPACING

    -- Brow bend pattern
    local browBend = ui.sliderWithInput('mipo_brow_bend', x, y, 120, 1, 10, brow.bend)
    ui.alignedLabel(x, y, '  brow bend')
    if browBend then browBend = math.floor(browBend + 0.5) end
    if browBend and browBend ~= brow.bend then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { browBend = browBend })
        CharacterManager.rebuildTextures(instance)
    end
    y = y + ROW

    -- Brow size
    local bwMul = ui.sliderWithInput('mipo_brow_wmul', x, y, 120, 0.25, 2, brow.wMul)
    ui.alignedLabel(x, y, '  brow width')
    if bwMul and bwMul ~= brow.wMul then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { browWMul = bwMul })
        CharacterManager.rebuildTextures(instance)
    end
    y = y + ROW

    local bhMul = ui.sliderWithInput('mipo_brow_hmul', x, y, 120, 0.25, 2, brow.hMul)
    ui.alignedLabel(x, y, '  brow height')
    if bhMul and bhMul ~= brow.hMul then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { browHMul = bhMul })
        CharacterManager.rebuildTextures(instance)
    end
    y = y + ROW

    -- Brow vertical position
    local browYVal = ui.sliderWithInput('mipo_brow_y', x, y, 120, 0.1, 0.5, browPos.y)
    ui.alignedLabel(x, y, '  brow vertical')
    if browYVal and browYVal ~= browPos.y then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { browY = browYVal })
        CharacterManager.rebuildTextures(instance)
    end
    y = y + ROW

    -- Brow color
    handlePaletteButton('mipo_brow_bg_' .. partName,
        x + 30, y, 140, brow.bgHex, function(color)
            CharacterManager.updateFaceOfPart(instance, faceOwner, { browBgHex = color })
            CharacterManager.rebuildTextures(instance)
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
                CharacterManager.rebuildTextures(instance)
            end
        else
            CharacterManager.updateFaceOfPart(instance, faceOwner, { noseShape = 0 })
            CharacterManager.rebuildTextures(instance)
        end
    end, true)
    y = y + gridHeight + BUTTON_SPACING

    -- Nose size sliders
    local nwMul = ui.sliderWithInput('mipo_nose_wmul', x, y, 120, 0.5, 3, nose.wMul)
    ui.alignedLabel(x, y, '  nose width')
    if nwMul and nwMul ~= nose.wMul then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { noseWMul = nwMul })
        CharacterManager.rebuildTextures(instance)
    end
    y = y + ROW

    local nhMul = ui.sliderWithInput('mipo_nose_hmul', x, y, 120, 0.5, 3, nose.hMul)
    ui.alignedLabel(x, y, '  nose height')
    if nhMul and nhMul ~= nose.hMul then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { noseHMul = nhMul })
        CharacterManager.rebuildTextures(instance)
    end
    y = y + ROW

    -- Nose vertical position
    local noseYVal = ui.sliderWithInput('mipo_nose_y', x, y, 120, 0, 1, nosePos.y)
    ui.alignedLabel(x, y, '  nose vertical')
    if noseYVal and noseYVal ~= nosePos.y then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { noseY = noseYVal })
        CharacterManager.rebuildTextures(instance)
    end
    y = y + ROW

    -- Nose colors
    handlePaletteButton('mipo_nose_bg_' .. partName,
        x + 30, y, 140, nose.bgHex, function(color)
            CharacterManager.updateFaceOfPart(instance, faceOwner, { noseBgHex = color })
            CharacterManager.rebuildTextures(instance)
        end)
    ui.alignedLabel(x + 180, y, 'nose outline')
    y = y + ROW

    handlePaletteButton('mipo_nose_fg_' .. partName,
        x + 30, y, 140, nose.fgHex, function(color)
            CharacterManager.updateFaceOfPart(instance, faceOwner, { noseFgHex = color })
            CharacterManager.rebuildTextures(instance)
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
    if mShape then mShape = math.floor(mShape + 0.5) end
    if mShape and mShape ~= mouth.shape then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthShape = mShape })
        CharacterManager.rebuildTextures(instance)
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
                CharacterManager.rebuildTextures(instance)
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
                CharacterManager.rebuildTextures(instance)
            end
        end
    end)
    y = y + gridHeight + BUTTON_SPACING

    -- Mouth position
    local mY = ui.sliderWithInput('mipo_mouth_y', x, y, 120, 0.5, 0.95, mouthPos.y)
    ui.alignedLabel(x, y, '  mouth vertical')
    if mY and mY ~= mouthPos.y then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthY = mY })
        CharacterManager.rebuildTextures(instance)
    end
    y = y + ROW

    -- Mouth size
    local mwMul = ui.sliderWithInput('mipo_mouth_wmul', x, y, 120, 0.3, 2, mouth.wMul)
    ui.alignedLabel(x, y, '  mouth width')
    if mwMul and mwMul ~= mouth.wMul then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthWMul = mwMul })
        CharacterManager.rebuildTextures(instance)
    end
    y = y + ROW

    local mhMul = ui.sliderWithInput('mipo_mouth_hmul', x, y, 120, 0.3, 2, mouth.hMul)
    ui.alignedLabel(x, y, '  mouth height')
    if mhMul and mhMul ~= mouth.hMul then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthHMul = mhMul })
        CharacterManager.rebuildTextures(instance)
    end
    y = y + ROW

    -- Lip thickness
    local upperLipScale = ui.sliderWithInput('mipo_upper_lip_scale', x, y, 120, 0.02, 0.4,
        mouth.upperLipScale or mouth.lipScale or 0.15)
    ui.alignedLabel(x, y, '  upper lip')
    if upperLipScale and upperLipScale ~= mouth.upperLipScale then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthUpperLipScale = upperLipScale })
        CharacterManager.rebuildTextures(instance)
    end
    y = y + ROW

    local lowerLipScale = ui.sliderWithInput('mipo_lower_lip_scale', x, y, 120, 0.02, 0.4,
        mouth.lowerLipScale or mouth.lipScale or 0.25)
    ui.alignedLabel(x, y, '  lower lip')
    if lowerLipScale and lowerLipScale ~= mouth.lowerLipScale then
        CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthLowerLipScale = lowerLipScale })
        CharacterManager.rebuildTextures(instance)
    end
    y = y + ROW

    -- Lip color
    handlePaletteButton('mipo_lip_color_' .. partName,
        x + 30, y, 140, mouth.lipHex, function(color)
            CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthLipHex = color })
            CharacterManager.rebuildTextures(instance)
        end)
    ui.alignedLabel(x + 180, y, 'lip color')
    y = y + ROW

    -- Backdrop color
    handlePaletteButton('mipo_mouth_backdrop_' .. partName,
        x + 30, y, 140, mouth.backdropHex, function(color)
            CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthBackdropHex = color })
            CharacterManager.rebuildTextures(instance)
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
                CharacterManager.rebuildTextures(instance)
            end
        else
            CharacterManager.updateFaceOfPart(instance, faceOwner, { teethShape = 0 })
            CharacterManager.rebuildTextures(instance)
        end
    end, true) -- showNone = true
    y = y + teethGridHeight + BUTTON_SPACING

    if teeth.shape and teeth.shape > 0 then
        local twMul = ui.sliderWithInput('mipo_teeth_wmul', x, y, 120, 0.3, 3, teeth.wMul or 1)
        ui.alignedLabel(x, y, '  teeth width')
        if twMul and twMul ~= (teeth.wMul or 1) then
            CharacterManager.updateFaceOfPart(instance, faceOwner, { teethWMul = twMul })
            CharacterManager.rebuildTextures(instance)
        end
        y = y + ROW

        local thMul = ui.sliderWithInput('mipo_teeth_hmul', x, y, 120, 0.5, 3, teeth.hMul)
        ui.alignedLabel(x, y, '  teeth height')
        if thMul and thMul ~= teeth.hMul then
            CharacterManager.updateFaceOfPart(instance, faceOwner, { teethHMul = thMul })
            CharacterManager.rebuildTextures(instance)
        end
        y = y + ROW

        local soClicked, soChecked = ui.checkbox(x, y, teeth.stickOut, 'stick out')
        if soClicked then
            CharacterManager.updateFaceOfPart(instance, faceOwner, { teethStickOut = soChecked })
            CharacterManager.rebuildTextures(instance)
        end
        y = y + ROW

        handlePaletteButton('mipo_teeth_bg_' .. partName,
            x + 30, y, 140, teeth.bgHex, function(color)
                CharacterManager.updateFaceOfPart(instance, faceOwner, { teethBgHex = color })
                CharacterManager.rebuildTextures(instance)
            end)
        ui.alignedLabel(x + 180, y, 'teeth outline')
        y = y + ROW

        handlePaletteButton('mipo_teeth_fg_' .. partName,
            x + 30, y, 140, teeth.fgHex, function(color)
                CharacterManager.updateFaceOfPart(instance, faceOwner, { teethFgHex = color })
                CharacterManager.rebuildTextures(instance)
            end)
        ui.alignedLabel(x + 180, y, 'teeth fill')
        y = y + ROW
    end

    return y
end




-- panelX, panelY, panelWidth, panelH: the panel rect (default: the right edge, full height)
-- The part the shape panel edits for `partName`: a spine's bands all take torso1's shape
-- (CharacterManager.applySpine), so on a spine any torso band means torso1.
-- === FACE ACCORDION (eyes + pupils) ===
-- Face decals render on head (non-potato) or torso1 (potato).
function lib.draw(p, y)
    local instance, partName, x, panelX, ROW = p.instance, p.partName, p.x, p.panelX, p.ROW
    local function drawAccordion(key, content)
        y = widgets.accordionHeader(p, y, key)
        if widgets.isOpen(key) then content() end
    end
    local faceOwner = topology.faceOwner(instance, partName)
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
                    if nw and nw ~= currentW then
                        for i = 1, noseSegs do
                            instance.dna.parts['nose' .. i].dims.w = nw
                        end
                        CharacterManager.rebuildFromCreation(instance, {})
                        CharacterManager.rebuildTextures(instance)
                    end
                    y = y + ROW

                    local currentH = nose1Data.dims and nose1Data.dims.h or 40
                    local nh = ui.sliderWithInput('mipo_nose_h', x, y, 120, 5, 500, currentH)
                    ui.alignedLabel(x, y, '  nose height')
                    if nh and nh ~= currentH then
                        for i = 1, noseSegs do
                            instance.dna.parts['nose' .. i].dims.h = nh
                        end
                        CharacterManager.rebuildFromCreation(instance, {})
                        CharacterManager.rebuildTextures(instance)
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
                                    CharacterManager.updateConnectedAppearance(instance, 'nose1',
                                        'connected-skin', vals)
                                    CharacterManager.rebuildTextures(instance)
                                end)
                            y = y + gridHeight + BUTTON_SPACING

                            local currentWmul = cs.wmul or instance.scale or 1
                            local wmulVal = ui.sliderWithInput('mipo_nose_cs_wmul', x, y, 120, 0.1, 10, currentWmul)
                            ui.alignedLabel(x, y, '  width')
                            if wmulVal and wmulVal ~= currentWmul then
                                CharacterManager.updateConnectedAppearance(instance, 'nose1', 'connected-skin',
                                    { wmul = wmulVal })
                                CharacterManager.rebuildTextures(instance)
                            end
                            y = y + ROW

                            handlePaletteButton('mipo_nose_cs_bg',
                                x + 30, y, 140, cs.bgHex, function(color)
                                    CharacterManager.updateConnectedAppearance(instance, 'nose1', 'connected-skin',
                                        { bgHex = color })
                                    CharacterManager.rebuildTextures(instance)
                                end)
                            ui.alignedLabel(x + 180, y, 'outline')
                            y = y + ROW

                            handlePaletteButton('mipo_nose_cs_fg',
                                x + 30, y, 140, cs.fgHex, function(color)
                                    CharacterManager.updateConnectedAppearance(instance, 'nose1', 'connected-skin',
                                        { fgHex = color })
                                    CharacterManager.rebuildTextures(instance)
                                end)
                            ui.alignedLabel(x + 180, y, 'fill')
                            y = y + ROW

                            y = drawPatternControls(cs, 'mipo_nose_cs_pat', panelX, y,
                                function(key, value)
                                    CharacterManager.updateConnectedAppearance(instance, 'nose1', 'connected-skin',
                                        { [key] = value })
                                    CharacterManager.rebuildTextures(instance)
                                end)
                        end
                    end

                    -- Connected-hair texture controls (segmented nose, 2+)
                    if noseSegs >= 2 and nose1Data.appearance then
                        local ch = nose1Data.appearance['connected-hair']
                            and nose1Data.appearance['connected-hair'].main
                        ui.label(x, y, 'connected hair')
                        y = y + ROW

                        local currentURL = ch and ch.bgURL or ''
                        local cellSize = 50
                        local gridHeight = drawThumbnailGrid(limbHairTextures, currentURL, panelX, y, cellSize,
                            function(url)
                                if url then
                                    local fgUrl = hairsWithMask[url] and url:gsub('%.png', '-mask.png') or ''
                                    if not nose1Data.appearance['connected-hair'] then
                                        nose1Data.appearance['connected-hair'] = {
                                            main = {
                                                bgURL = url, fgURL = fgUrl,
                                                bgHex = '020202ff', fgHex = 'ff0000ff',
                                                pURL = 'type2t.png', pHex = 'ffff00ff',
                                            },
                                            zOffset = 491,
                                        }
                                    else
                                        CharacterManager.updateConnectedAppearance(instance, 'nose1',
                                            'connected-hair', { bgURL = url, fgURL = fgUrl })
                                    end
                                else
                                    nose1Data.appearance['connected-hair'] = nil
                                end
                                CharacterManager.rebuildFromCreation(instance, {})
                                CharacterManager.rebuildTextures(instance)
                            end, true)
                        y = y + gridHeight + BUTTON_SPACING

                        if ch then
                            local currentWmul = ch.wmul or instance.scale or 1
                            local wmulVal = ui.sliderWithInput('mipo_nose_ch_wmul', x, y, 120, 0.1, 10, currentWmul)
                            ui.alignedLabel(x, y, '  width')
                            if wmulVal and wmulVal ~= currentWmul then
                                CharacterManager.updateConnectedAppearance(instance, 'nose1', 'connected-hair',
                                    { wmul = wmulVal })
                                CharacterManager.rebuildTextures(instance)
                            end
                            y = y + ROW

                            handlePaletteButton('mipo_nose_ch_bg',
                                x + 30, y, 140, ch.bgHex, function(color)
                                    CharacterManager.updateConnectedAppearance(instance, 'nose1', 'connected-hair',
                                        { bgHex = color })
                                    CharacterManager.rebuildTextures(instance)
                                end)
                            ui.alignedLabel(x + 180, y, 'outline')
                            y = y + ROW

                            if ch.fgURL and ch.fgURL ~= '' then
                                handlePaletteButton('mipo_nose_ch_fg',
                                    x + 30, y, 140, ch.fgHex or 'ffffffff', function(color)
                                        CharacterManager.updateConnectedAppearance(instance, 'nose1',
                                            'connected-hair', { fgHex = color })
                                        CharacterManager.rebuildTextures(instance)
                                    end)
                                ui.alignedLabel(x + 180, y, 'fill')
                                y = y + ROW

                                y = drawPatternControls(ch, 'mipo_nose_ch_pat', panelX, y,
                                    function(key, value)
                                        CharacterManager.updateConnectedAppearance(instance, 'nose1',
                                            'connected-hair', { [key] = value })
                                        CharacterManager.rebuildTextures(instance)
                                    end)
                            end
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
                                    CharacterManager.rebuildTextures(instance)
                                end)
                            ui.alignedLabel(x + 180, y, 'outline')
                            y = y + ROW

                            handlePaletteButton('mipo_nose_skin_fg',
                                x + 30, y, 140, skin.main.fgHex, function(color)
                                    CharacterManager.updateSkinOfPart(instance, 'nose1', { fgHex = color }, 'main')
                                    CharacterManager.rebuildTextures(instance)
                                end)
                            ui.alignedLabel(x + 180, y, 'fill')
                            y = y + ROW

                            y = drawPatternControls(skin.main, 'mipo_nose_skin_pat', panelX, y,
                                function(key, value)
                                    CharacterManager.updateSkinOfPart(instance, 'nose1', { [key] = value }, 'main')
                                    CharacterManager.rebuildTextures(instance)
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
    return y
end

return lib

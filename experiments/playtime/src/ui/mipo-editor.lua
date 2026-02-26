local lib = {}

local ui = require('src.ui.all')
local state = require('src.state')
local utils = require('src.utils')
local randomHexColor = utils.randomHexColor
local CharacterManager = require('src.character-manager')
local mipoRegistry = require('src.mipo-registry')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')
local mouthShapes = require('src.mouth-shapes')
local ST = require('src.shape-types')

local PANEL_WIDTH = 300
local BUTTON_HEIGHT = ui.theme.lineHeight
local BUTTON_SPACING = 10

local imageCache = {}

local accordionStates = {}

-- Shape categories for thumbnail grids
local torsoHeadShapes = {
    'shapeA1', 'shapeA2', 'shapeA3', 'shapeA4',
    'shapes1', 'shapes2', 'shapes3', 'shapes4', 'shapes5',
    'shapes6', 'shapes7', 'shapes8', 'shapes9', 'shapes10',
    'shapes11', 'shapes12', 'shapes13'
}

local earShapes = {
    'earx1r', 'earx2r', 'earx3r', 'earx4r', 'earx5r', 'earx6r',
    'earx7r', 'earx8r', 'earx9r', 'earx10r', 'earx11r', 'earx12r',
    'earx13r', 'earx14r', 'earx15r', 'earx16r'
}

local feetShapes = {
    'feet2r', 'feet3xr', 'feet5xr', 'feet6r', 'feet7r', 'feet7xr', 'feet8r'
}

local handShapes = {
    'hand3r', 'feet2r', 'feet3xr', 'feet5xr', 'feet6r', 'feet7r', 'feet7xr', 'feet8r'
}

local bodyhairTextures = {
    'borsthaar1', 'borsthaar2', 'borsthaar3', 'borsthaar4',
    'borsthaar5', 'borsthaar6', 'borsthaar7'
}

-- Textures for haircut (trace-vertices along head outline)
local haircutTextures = {
    'hair1', 'hair2', 'hair3', 'hair4', 'hair5',
    'hair6', 'hair7', 'hair8', 'hair9', 'hair10', 'hair11'
}

-- Hair textures that have a mask (OMP-capable)
local hairsWithMask = { ['hair7.png'] = true, ['hair8.png'] = true }

-- Textures for connected-skin (OMP, has outline + mask pairs)
local limbSkinTextures = {
    'leg1', 'leg2', 'leg3', 'leg4', 'leg5', 'leg7'
}

-- Pattern textures for OMP compositing (textures/pat/)
local patternTextures = {
    'pat/type0', 'pat/type1', 'pat/type2t', 'pat/type3_',
    'pat/type4', 'pat/type5', 'pat/type6', 'pat/type7', 'pat/type8',
    'pat/pattern', 'pat/pattern2', 'pat/pattern3', 'pat/pattern4',
    'pat/pattern5', 'pat/pattern6', 'pat/pattern7', 'pat/lijnen'
}

-- Eye shape textures for face decals
local eyeShapes = {
    'eye1', 'eye2', 'eye3', 'eye4', 'eye5', 'eye6', 'eye7'
}

-- Pupil shape textures for face decals
local pupilShapes = {
    'pupil1', 'pupil2', 'pupil3', 'pupil4', 'pupil5', 'pupil6',
    'pupil7', 'pupil8', 'pupil9', 'pupil10', 'pupil11'
}

-- Brow shape textures for face decals
local browShapes = {
    'brow1', 'brow2', 'brow3', 'brow4', 'brow5', 'brow6', 'brow7', 'brow8'
}

-- Lip shape textures for mouth decals
local upperLipShapes = { 'upperlip1', 'upperlip2', 'upperlip3', 'upperlip4' }
local lowerLipShapes = { 'lowerlip1', 'lowerlip2', 'lowerlip3', 'lowerlip4' }

-- Textures for connected-hair (2-layer, outline only, no mask)
local limbHairTextures = {
    'hair1', 'hair2', 'hair3', 'hair4', 'hair5',
    'hair6', 'hair7', 'hair8', 'hair9', 'hair10', 'hair11'
}

local noseShapes = {
    'nose1', 'nose2', 'nose3', 'nose4', 'nose5', 'nose6', 'nose7', 'nose8',
    'nose9', 'nose10', 'nose11', 'nose12', 'nose13', 'nose14', 'nose15'
}

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
    if partName == 'lear' then return 'rear'
    elseif partName == 'rear' then return 'lear'
    elseif partName == 'lfoot' then return 'rfoot'
    elseif partName == 'rfoot' then return 'lfoot'
    elseif partName == 'lhand' then return 'rhand'
    elseif partName == 'rhand' then return 'lhand'
    end
    return nil
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
    local currentPURL = block.pURL or ''
    -- Convert pURL (e.g. 'type0.png') to grid format ('pat/type0')
    local currentGridURL = currentPURL ~= '' and ('pat/' .. currentPURL) or ''
    local cellSize = 40
    local gridHeight = drawThumbnailGrid(patternTextures, currentGridURL, panelX, yy, cellSize,
        function(url)
            -- url is 'pat/type0.png' or nil; strip 'pat/' prefix for pURL
            local purl = url and url:gsub('^pat/', '') or ''
            onUpdate('pURL', purl)
        end, true)
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
                    -- Disable face overlay nose when physics nose is enabled
                    if val > 0 then
                        local startParent = creation.isPotatoHead and 'torso1' or 'head'
                        CharacterManager.updateFaceOfPart(instance, startParent, { noseShape = 0 })
                    end
                    CharacterManager.rebuildFromCreation(instance, { noseSegments = val })
                    CharacterManager.addTexturesFromInstance2(instance)
                end
            end
            y = y + ROW

            -- suppress unused warning
            local _ = changed
        end)

        -- === POSITIONERS ACCORDION ===
        drawAccordion('positioners', function()
            local pos = instance.dna.positioners or {}

            -- Leg stance width
            local legX = ui.sliderWithInput('mipo_leg_x', x, y, 120, 0, 1, (pos.leg and pos.leg.x) or 0.5)
            ui.alignedLabel(x, y, '  leg stance')
            legX = legX and tonumber(legX)
            if legX and legX ~= ((pos.leg and pos.leg.x) or 0.5) then
                CharacterManager.updatePositioners(instance, { legX = legX })
                CharacterManager.rebuildFromCreation(instance, {})
                CharacterManager.addTexturesFromInstance2(instance)
            end
            y = y + ROW

            -- Ear vertical position
            local earY = ui.sliderWithInput('mipo_ear_y', x, y, 120, 0, 1, (pos.ear and pos.ear.y) or 0.5)
            ui.alignedLabel(x, y, '  ear vertical')
            earY = earY and tonumber(earY)
            if earY and earY ~= ((pos.ear and pos.ear.y) or 0.5) then
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
                        ui.label(x, y, patch)
                        y = y + ROW

                        -- Shape selection grid and transform sliders for patches (not main)
                        if patch ~= 'main' then
                            local currentBG = skin[patch].bgURL or ''
                            local cellSize = 50
                            local gridHeight = drawThumbnailGrid(patchShapes, currentBG, panelX, y, cellSize,
                                function(url)
                                    if url then
                                        local base = url:gsub('%.png$', '')
                                        CharacterManager.updateSkinOfPart(instance, partName,
                                            { bgURL = base .. '.png', fgURL = base .. '-mask.png' }, patch)
                                    else
                                        CharacterManager.updateSkinOfPart(instance, partName,
                                            { bgURL = '', fgURL = '' }, patch)
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
                                    CharacterManager.addTexturesFromInstance2(instance)
                                end
                                y = y + ROW
                            end
                        end

                        handlePaletteButton('mipo_bg_' .. partName .. '_' .. patch,
                            x + 30, y, 140, skin[patch].bgHex, function(color)
                                CharacterManager.updateSkinOfPart(instance, partName, { bgHex = color }, patch)
                                CharacterManager.addTexturesFromInstance2(instance)
                            end)
                        ui.alignedLabel(x + 180, y, 'outline')
                        y = y + ROW

                        handlePaletteButton('mipo_fg_' .. partName .. '_' .. patch,
                            x + 30, y, 140, skin[patch].fgHex, function(color)
                                CharacterManager.updateSkinOfPart(instance, partName, { fgHex = color }, patch)
                                CharacterManager.addTexturesFromInstance2(instance)
                            end)
                        ui.alignedLabel(x + 180, y, 'fill')
                        y = y + ROW

                        y = drawPatternControls(skin[patch], 'mipo_pat_' .. partName .. '_' .. patch, panelX, y,
                            function(key, value)
                                CharacterManager.updateSkinOfPart(instance, partName, { [key] = value }, patch)
                                CharacterManager.addTexturesFromInstance2(instance)
                            end)
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
                            end
                            CharacterManager.addTexturesFromInstance2(instance)
                        end)
                    ui.alignedLabel(x + 180, y, 'fill')
                    y = y + ROW

                    -- Growfactor slider (how much bigger bodyhair is relative to the body)
                    local currentGrow = bh.growfactor or 1.2
                    ui.alignedLabel(x, y, 'grow')
                    local changed, newGrow = ui.slider('mipo_bh_grow_' .. partName,
                        x + 40, y, 200, currentGrow, 0.5, 2.5)
                    if changed then
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
                local eye = face.eye or {}
                local pupil = face.pupil or {}
                local eyePos = (face.positioners and face.positioners.eye) or { x = 0.2, y = 0.5 }

                -- Eye shape thumbnail grid
                ui.label(x, y, 'eye shape')
                y = y + ROW
                local currentEyeURL = 'eye' .. (eye.shape or 1) .. '.png'
                local cellSize = 50
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
                local currentPupilURL = 'pupil' .. (pupil.shape or 1) .. '.png'
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
                local eyeRVal = ui.sliderWithInput('mipo_eye_r', x, y, 120, -2, 2, eyePos.r or 0)
                ui.alignedLabel(x, y, '  eye rotation')
                eyeRVal = eyeRVal and tonumber(eyeRVal)
                if eyeRVal and eyeRVal ~= (eyePos.r or 0) then
                    CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeR = eyeRVal })
                    CharacterManager.addTexturesFromInstance2(instance)
                end
                y = y + ROW

                -- Eye size sliders
                local ewMul = ui.sliderWithInput('mipo_eye_wmul', x, y, 120, 0.25, 2, eye.wMul or 1)
                ui.alignedLabel(x, y, '  eye width')
                ewMul = ewMul and tonumber(ewMul)
                if ewMul and ewMul ~= (eye.wMul or 1) then
                    CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeWMul = ewMul })
                    CharacterManager.addTexturesFromInstance2(instance)
                end
                y = y + ROW

                local ehMul = ui.sliderWithInput('mipo_eye_hmul', x, y, 120, 0.25, 2, eye.hMul or 1)
                ui.alignedLabel(x, y, '  eye height')
                ehMul = ehMul and tonumber(ehMul)
                if ehMul and ehMul ~= (eye.hMul or 1) then
                    CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeHMul = ehMul })
                    CharacterManager.addTexturesFromInstance2(instance)
                end
                y = y + ROW

                -- Pupil size sliders
                local pwMul = ui.sliderWithInput('mipo_pupil_wmul', x, y, 120, 0.1, 1, pupil.wMul or 0.5)
                ui.alignedLabel(x, y, '  pupil width')
                pwMul = pwMul and tonumber(pwMul)
                if pwMul and pwMul ~= (pupil.wMul or 0.5) then
                    CharacterManager.updateFaceOfPart(instance, faceOwner, { pupilWMul = pwMul })
                    CharacterManager.addTexturesFromInstance2(instance)
                end
                y = y + ROW

                local phMul = ui.sliderWithInput('mipo_pupil_hmul', x, y, 120, 0.1, 1, pupil.hMul or 0.5)
                ui.alignedLabel(x, y, '  pupil height')
                phMul = phMul and tonumber(phMul)
                if phMul and phMul ~= (pupil.hMul or 0.5) then
                    CharacterManager.updateFaceOfPart(instance, faceOwner, { pupilHMul = phMul })
                    CharacterManager.addTexturesFromInstance2(instance)
                end
                y = y + ROW

                -- Eye color
                handlePaletteButton('mipo_eye_bg_' .. partName,
                    x + 30, y, 140, eye.bgHex or 'ffffffff', function(color)
                        CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeBgHex = color })
                        CharacterManager.addTexturesFromInstance2(instance)
                    end)
                ui.alignedLabel(x + 180, y, 'eye outline')
                y = y + ROW

                handlePaletteButton('mipo_eye_fg_' .. partName,
                    x + 30, y, 140, eye.fgHex or '000000ff', function(color)
                        CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeFgHex = color })
                        CharacterManager.addTexturesFromInstance2(instance)
                    end)
                ui.alignedLabel(x + 180, y, 'eye fill')
                y = y + ROW

                -- Pupil color
                handlePaletteButton('mipo_pupil_bg_' .. partName,
                    x + 30, y, 140, pupil.bgHex or '000000ff', function(color)
                        CharacterManager.updateFaceOfPart(instance, faceOwner, { pupilBgHex = color })
                        CharacterManager.addTexturesFromInstance2(instance)
                    end)
                ui.alignedLabel(x + 180, y, 'pupil color')
                y = y + ROW

                -- === BROW SECTION ===
                local brow = face.brow or {}
                local browPos = (face.positioners and face.positioners.brow) or { y = 0.3 }

                -- Brow shape thumbnail grid
                ui.label(x, y, 'brow shape')
                y = y + ROW
                local currentBrowURL = 'brow' .. (brow.shape or 1) .. '.png'
                gridHeight = drawThumbnailGrid(browShapes, currentBrowURL, panelX, y, cellSize, function(url)
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
                local browBend = ui.sliderWithInput('mipo_brow_bend', x, y, 120, 1, 10, brow.bend or 1)
                ui.alignedLabel(x, y, '  brow bend')
                browBend = browBend and tonumber(browBend)
                if browBend then browBend = math.floor(browBend + 0.5) end
                if browBend and browBend ~= (brow.bend or 1) then
                    CharacterManager.updateFaceOfPart(instance, faceOwner, { browBend = browBend })
                    CharacterManager.addTexturesFromInstance2(instance)
                end
                y = y + ROW

                -- Brow size
                local bwMul = ui.sliderWithInput('mipo_brow_wmul', x, y, 120, 0.25, 2, brow.wMul or 1)
                ui.alignedLabel(x, y, '  brow width')
                bwMul = bwMul and tonumber(bwMul)
                if bwMul and bwMul ~= (brow.wMul or 1) then
                    CharacterManager.updateFaceOfPart(instance, faceOwner, { browWMul = bwMul })
                    CharacterManager.addTexturesFromInstance2(instance)
                end
                y = y + ROW

                local bhMul = ui.sliderWithInput('mipo_brow_hmul', x, y, 120, 0.25, 2, brow.hMul or 1)
                ui.alignedLabel(x, y, '  brow height')
                bhMul = bhMul and tonumber(bhMul)
                if bhMul and bhMul ~= (brow.hMul or 1) then
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
                    x + 30, y, 140, brow.bgHex or '000000ff', function(color)
                        CharacterManager.updateFaceOfPart(instance, faceOwner, { browBgHex = color })
                        CharacterManager.addTexturesFromInstance2(instance)
                    end)
                ui.alignedLabel(x + 180, y, 'brow color')
                y = y + ROW

                -- === NOSE OVERLAY SECTION ===
                local nose = face.nose or {}
                local nosePos = (face.positioners and face.positioners.nose) or { y = 0.35 }

                ui.label(x, y, 'nose (overlay)')
                y = y + ROW
                local currentNoseURL = (nose.shape or 0) > 0 and ('nose' .. nose.shape .. '.png') or ''
                gridHeight = drawThumbnailGrid(noseShapes, currentNoseURL, panelX, y, cellSize, function(url)
                    if url then
                        local shapeNum = tonumber(url:match('nose(%d+)%.png'))
                        if shapeNum then
                            CharacterManager.updateFaceOfPart(instance, faceOwner, { noseShape = shapeNum })
                            -- Disable physics nose when overlay nose is selected
                            CharacterManager.rebuildFromCreation(instance, { noseSegments = 0 })
                            CharacterManager.addTexturesFromInstance2(instance)
                        end
                    else
                        CharacterManager.updateFaceOfPart(instance, faceOwner, { noseShape = 0 })
                        CharacterManager.addTexturesFromInstance2(instance)
                    end
                end, true)
                y = y + gridHeight + BUTTON_SPACING

                -- Nose size sliders
                local nwMul = ui.sliderWithInput('mipo_nose_wmul', x, y, 120, 0.5, 3, nose.wMul or 1)
                ui.alignedLabel(x, y, '  nose width')
                nwMul = nwMul and tonumber(nwMul)
                if nwMul and nwMul ~= (nose.wMul or 1) then
                    CharacterManager.updateFaceOfPart(instance, faceOwner, { noseWMul = nwMul })
                    CharacterManager.addTexturesFromInstance2(instance)
                end
                y = y + ROW

                local nhMul = ui.sliderWithInput('mipo_nose_hmul', x, y, 120, 0.5, 3, nose.hMul or 1)
                ui.alignedLabel(x, y, '  nose height')
                nhMul = nhMul and tonumber(nhMul)
                if nhMul and nhMul ~= (nose.hMul or 1) then
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
                    x + 30, y, 140, nose.bgHex or '000000ff', function(color)
                        CharacterManager.updateFaceOfPart(instance, faceOwner, { noseBgHex = color })
                        CharacterManager.addTexturesFromInstance2(instance)
                    end)
                ui.alignedLabel(x + 180, y, 'nose outline')
                y = y + ROW

                handlePaletteButton('mipo_nose_fg_' .. partName,
                    x + 30, y, 140, nose.fgHex or 'ffffffff', function(color)
                        CharacterManager.updateFaceOfPart(instance, faceOwner, { noseFgHex = color })
                        CharacterManager.addTexturesFromInstance2(instance)
                    end)
                ui.alignedLabel(x + 180, y, 'nose fill')
                y = y + ROW

                -- === MOUTH SECTION ===
                local mouth = face.mouth or {}
                local mouthPos = (face.positioners and face.positioners.mouth) or { y = 0.7 }

                ui.label(x, y, 'mouth shape (' .. (mouth.shape or 2) .. '/' .. #mouthShapes.normalized .. ')')
                y = y + ROW

                local mShape = ui.sliderWithInput('mipo_mouth_shape', x, y, 120, 1, #mouthShapes.normalized,
                    mouth.shape or 2)
                ui.alignedLabel(x, y, '  mouth preset')
                mShape = mShape and tonumber(mShape)
                if mShape then mShape = math.floor(mShape + 0.5) end
                if mShape and mShape ~= (mouth.shape or 2) then
                    CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthShape = mShape })
                    CharacterManager.addTexturesFromInstance2(instance)
                end
                y = y + ROW

                -- Upper lip texture grid
                ui.label(x, y, 'upper lip')
                y = y + ROW
                local currentUpperURL = 'upperlip' .. (mouth.upperLipShape or 1) .. '.png'
                gridHeight = drawThumbnailGrid(upperLipShapes, currentUpperURL, panelX, y, cellSize, function(url)
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
                local currentLowerURL = 'lowerlip' .. (mouth.lowerLipShape or 1) .. '.png'
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
                local mwMul = ui.sliderWithInput('mipo_mouth_wmul', x, y, 120, 0.3, 2, mouth.wMul or 1)
                ui.alignedLabel(x, y, '  mouth width')
                mwMul = mwMul and tonumber(mwMul)
                if mwMul and mwMul ~= (mouth.wMul or 1) then
                    CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthWMul = mwMul })
                    CharacterManager.addTexturesFromInstance2(instance)
                end
                y = y + ROW

                local mhMul = ui.sliderWithInput('mipo_mouth_hmul', x, y, 120, 0.3, 2, mouth.hMul or 1)
                ui.alignedLabel(x, y, '  mouth height')
                mhMul = mhMul and tonumber(mhMul)
                if mhMul and mhMul ~= (mouth.hMul or 1) then
                    CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthHMul = mhMul })
                    CharacterManager.addTexturesFromInstance2(instance)
                end
                y = y + ROW

                -- Lip thickness
                local lipScale = ui.sliderWithInput('mipo_lip_scale', x, y, 120, 0.05, 0.5, mouth.lipScale or 0.25)
                ui.alignedLabel(x, y, '  lip thickness')
                lipScale = lipScale and tonumber(lipScale)
                if lipScale and lipScale ~= (mouth.lipScale or 0.25) then
                    CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthLipScale = lipScale })
                    CharacterManager.addTexturesFromInstance2(instance)
                end
                y = y + ROW

                -- Lip color
                handlePaletteButton('mipo_lip_color_' .. partName,
                    x + 30, y, 140, mouth.lipHex or 'cc5555ff', function(color)
                        CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthLipHex = color })
                        CharacterManager.addTexturesFromInstance2(instance)
                    end)
                ui.alignedLabel(x + 180, y, 'lip color')
                y = y + ROW

                -- Backdrop color
                handlePaletteButton('mipo_mouth_backdrop_' .. partName,
                    x + 30, y, 140, mouth.backdropHex or '330000ff', function(color)
                        CharacterManager.updateFaceOfPart(instance, faceOwner, { mouthBackdropHex = color })
                        CharacterManager.addTexturesFromInstance2(instance)
                    end)
                ui.alignedLabel(x + 180, y, 'mouth interior')
                y = y + ROW
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
        if connSkinData and connSkinData.appearance and connSkinData.appearance['connected-skin'] then
            local connLabel = connSkinData.appearance['connected-skin'].endNode
                and (partName .. ' > ' .. connSkinData.appearance['connected-skin'].endNode .. ' skin')
                or (partName .. ' connected skin')
            drawAccordion(connLabel, function()
                local cs = connSkinData.appearance['connected-skin'].main
                if cs then
                    -- Texture thumbnail grid
                    local currentURL = cs.bgURL or ''
                    local cellSize = 50
                    local gridHeight = drawThumbnailGrid(limbSkinTextures, currentURL, panelX, y, cellSize,
                        function(url)
                            CharacterManager.updateConnectedAppearance(instance, connSkinOwner, 'connected-skin',
                                { bgURL = url, fgURL = url:gsub('%.png', '-mask.png') })
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
                        CharacterManager.addTexturesFromInstance2(instance)
                    end
                    y = y + ROW

                    handlePaletteButton('mipo_cs_bg_' .. partName,
                        x + 30, y, 140, cs.bgHex, function(color)
                            CharacterManager.updateConnectedAppearance(instance, connSkinOwner, 'connected-skin',
                                { bgHex = color })
                            CharacterManager.addTexturesFromInstance2(instance)
                        end)
                    ui.alignedLabel(x + 180, y, 'outline')
                    y = y + ROW

                    handlePaletteButton('mipo_cs_fg_' .. partName,
                        x + 30, y, 140, cs.fgHex, function(color)
                            CharacterManager.updateConnectedAppearance(instance, connSkinOwner, 'connected-skin',
                                { fgHex = color })
                            CharacterManager.addTexturesFromInstance2(instance)
                        end)
                    ui.alignedLabel(x + 180, y, 'fill')
                    y = y + ROW

                    y = drawPatternControls(cs, 'mipo_cs_pat_' .. partName, panelX, y,
                        function(key, value)
                            CharacterManager.updateConnectedAppearance(instance, connSkinOwner, 'connected-skin',
                                { [key] = value })
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
        if connHairData and connHairData.appearance and connHairData.appearance['connected-hair'] then
            local connHairLabel = connHairData.appearance['connected-hair'].endNode
                and (partName .. ' > ' .. connHairData.appearance['connected-hair'].endNode .. ' hair')
                or (partName .. ' connected hair')
            drawAccordion(connHairLabel, function()
                local ch = connHairData.appearance['connected-hair'].main
                if ch then
                    -- Texture thumbnail grid
                    local currentURL = ch.bgURL or ''
                    local cellSize = 50
                    local gridHeight = drawThumbnailGrid(limbHairTextures, currentURL, panelX, y, cellSize,
                        function(url)
                            local fgUrl = url and hairsWithMask[url] and url:gsub('%.png', '-mask.png') or ''
                            CharacterManager.updateConnectedAppearance(instance, connHairOwner, 'connected-hair',
                                { bgURL = url, fgURL = fgUrl })
                            CharacterManager.addTexturesFromInstance2(instance)
                        end)
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
                        CharacterManager.addTexturesFromInstance2(instance)
                    end
                    y = y + ROW

                    -- Outline color
                    handlePaletteButton('mipo_ch_bg_' .. partName,
                        x + 30, y, 140, ch.bgHex, function(color)
                            CharacterManager.updateConnectedAppearance(instance, connHairOwner, 'connected-hair',
                                { bgHex = color })
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
                                CharacterManager.addTexturesFromInstance2(instance)
                            end)
                        ui.alignedLabel(x + 180, y, 'fill')
                        y = y + ROW

                        y = drawPatternControls(ch, 'mipo_ch_pat_' .. partName, panelX, y,
                            function(key, value)
                                CharacterManager.updateConnectedAppearance(instance, connHairOwner, 'connected-hair',
                                    { [key] = value })
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
            lib.randomizeMipo(instance)
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

function lib.randomizeMipo(instance)
    if not instance then return end

    -- Random torso/head shapes (from key 'y')
    local urls = torsoHeadShapes
    local urlIndex = math.ceil(math.random() * #urls)
    local url = urls[urlIndex]
    local creation = instance.dna.creation
    local count = creation.torsoSegments or 1
    local s = 1 + math.random() * 1

    for i = 1, count do
        CharacterManager.updatePart('torso' .. i,
            { shape8URL = url .. '.png', sy = s * (math.random() < 0.5 and -1 or 1), sx = s },
            instance)
    end

    local headScale = 1 + math.random() * 1
    local headUrlIndex = math.ceil(math.random() * #urls)
    local headUrl = urls[headUrlIndex]
    CharacterManager.updatePart('head',
        { shape8URL = headUrl .. '.png', sy = headScale * (math.random() < 0.5 and -1 or 1), sx = headScale },
        instance)

    -- Random colors (from key 'q') — shared across all torso segments + head
    local bgHex = '000000ff'
    local fgHex = randomHexColor()
    local pHex = randomHexColor()
    for i = 1, count do
        CharacterManager.updateSkinOfPart(instance, 'torso' .. i,
            { bgHex = bgHex, fgHex = fgHex, pHex = pHex })
        CharacterManager.updateSkinOfPart(instance, 'torso' .. i,
            { bgHex = bgHex, fgHex = fgHex, pHex = pHex }, 'patch1')
        CharacterManager.updateSkinOfPart(instance, 'torso' .. i,
            { bgHex = bgHex, fgHex = fgHex, pHex = pHex }, 'patch2')
    end
    CharacterManager.updateSkinOfPart(instance, 'head',
        { bgHex = bgHex, fgHex = fgHex, pHex = pHex })

    -- Clear skin patches (they're optional overlays, not always wanted)
    for _, patchName in ipairs({'patch1', 'patch2', 'patch3'}) do
        local headSkin = instance.dna.parts.head.appearance.skin
        if headSkin[patchName] then
            headSkin[patchName].bgURL = ''
            headSkin[patchName].fgURL = ''
        end
        for i = 1, count do
            local torsoSkin = instance.dna.parts['torso' .. i].appearance.skin
            if torsoSkin[patchName] then
                torsoSkin[patchName].bgURL = ''
                torsoSkin[patchName].fgURL = ''
            end
        end
    end

    -- Random ears (from key 'e')
    local earUrls = earShapes
    local earUrlIndex = math.ceil(math.random() * #earUrls)
    local earUrl = earUrls[earUrlIndex]
    local earSy = 0.5 + math.random() * 1.5
    local earSx = 0.5 + math.random() * 1.5
    -- Sync w/h between ears so they're always symmetric
    local earW = instance.dna.parts.lear.dims.w
    local earH = instance.dna.parts.lear.dims.h
    CharacterManager.updatePart('lear',
        { shape8URL = earUrl .. '.png', sy = earSy, sx = -earSx, w = earW, h = earH },
        instance)
    CharacterManager.updatePart('rear',
        { shape8URL = earUrl .. '.png', sy = earSy, sx = earSx, w = earW, h = earH },
        instance)

    local earBgHex = '000000ff'
    local earFgHex = randomHexColor()
    local earPHex = randomHexColor()
    CharacterManager.updateSkinOfPart(instance, 'lear',
        { bgHex = earBgHex, fgHex = earFgHex, pHex = earPHex })
    CharacterManager.updateSkinOfPart(instance, 'rear',
        { bgHex = earBgHex, fgHex = earFgHex, pHex = earPHex })

    -- Random feet/hands (from key 'r')
    local fhUrls = handShapes
    local fUrlIndex = math.ceil(math.random() * #fhUrls)
    local fUrl = fhUrls[fUrlIndex]
    local fS = 1 + math.random() * 1

    CharacterManager.updatePart('lfoot',
        { shape8URL = fUrl .. '.png', sy = fS, sx = fS },
        instance)
    CharacterManager.updatePart('rfoot',
        { shape8URL = fUrl .. '.png', sy = fS, sx = -fS },
        instance)

    local handScale = 1 + math.random() * 1
    local handUrlIndex = math.ceil(math.random() * #fhUrls)
    local handUrl = fhUrls[handUrlIndex]
    CharacterManager.updatePart('lhand',
        { shape8URL = handUrl .. '.png', sy = handScale, sx = handScale },
        instance)
    CharacterManager.updatePart('rhand',
        { shape8URL = handUrl .. '.png', sy = handScale, sx = -handScale },
        instance)

    -- Random feet skin colors
    local feetFgHex = randomHexColor()
    local feetPHex = randomHexColor()
    for _, part in ipairs({'lfoot', 'rfoot'}) do
        CharacterManager.updateSkinOfPart(instance, part,
            { bgHex = '000000ff', fgHex = feetFgHex, pHex = feetPHex })
    end

    -- Random hand skin colors
    local handFgHex = randomHexColor()
    local handPHex = randomHexColor()
    for _, part in ipairs({'lhand', 'rhand'}) do
        CharacterManager.updateSkinOfPart(instance, part,
            { bgHex = '000000ff', fgHex = handFgHex, pHex = handPHex })
    end

    -- Random haircut (update both head and torso1 since isPotatoHead flip changes owner)
    local hcUrl = haircutTextures[math.ceil(math.random() * #haircutTextures)]
    local hcBgURL = hcUrl .. '.png'
    local hcFgURL = hairsWithMask[hcBgURL] and hcBgURL:gsub('%.png', '-mask.png') or ''
    local hcValues = { bgURL = hcBgURL, fgURL = hcFgURL, bgHex = randomHexColor(), width = 100 + math.random() * 300 }
    CharacterManager.updateHaircutOfPart(instance, 'head', hcValues)
    CharacterManager.updateHaircutOfPart(instance, 'torso1', hcValues)

    -- Random bodyhair (from key 't')
    local bhUrls = bodyhairTextures
    local bhUrlIndex = math.ceil(math.random() * #bhUrls)
    local bhUrl = bhUrls[bhUrlIndex]
    local bhBgHex = randomHexColor()
    local bhFgHex = randomHexColor()
    local bhPHex = randomHexColor()
    for i = 1, count do
        CharacterManager.updateBodyhairOfPart(instance, 'torso' .. i,
            { bgURL = bhUrl .. '.png', fgURL = bhUrl .. '-mask.png', bgHex = bhBgHex, fgHex = bhFgHex, pHex = bhPHex })
    end

    -- Random arm connected-skin
    local armSkinUrl = limbSkinTextures[math.ceil(math.random() * #limbSkinTextures)]
    local armSkinFgHex = randomHexColor()
    local armSkinPHex = randomHexColor()
    for _, part in ipairs({'luarm', 'ruarm'}) do
        CharacterManager.updateConnectedAppearance(instance, part, 'connected-skin',
            { bgURL = armSkinUrl .. '.png', fgURL = armSkinUrl .. '-mask.png', fgHex = armSkinFgHex, pHex = armSkinPHex })
    end

    -- Random leg connected-skin
    local legSkinUrl = limbSkinTextures[math.ceil(math.random() * #limbSkinTextures)]
    local legSkinFgHex = randomHexColor()
    local legSkinPHex = randomHexColor()
    for _, part in ipairs({'luleg', 'ruleg'}) do
        CharacterManager.updateConnectedAppearance(instance, part, 'connected-skin',
            { bgURL = legSkinUrl .. '.png', fgURL = legSkinUrl .. '-mask.png', fgHex = legSkinFgHex, pHex = legSkinPHex })
    end

    -- Torso connected-skin (uses leg skin for continuity)
    for i = 1, count do
        CharacterManager.updateConnectedAppearance(instance, 'torso' .. i, 'connected-skin',
            { bgURL = legSkinUrl .. '.png', fgURL = legSkinUrl .. '-mask.png', fgHex = legSkinFgHex, pHex = legSkinPHex })
    end

    -- Random arm connected-hair
    local armHairUrl = limbHairTextures[math.ceil(math.random() * #limbHairTextures)]
    local armHairBgHex = randomHexColor()
    for _, part in ipairs({'luarm', 'ruarm'}) do
        CharacterManager.updateConnectedAppearance(instance, part, 'connected-hair',
            { bgURL = armHairUrl .. '.png', bgHex = armHairBgHex })
    end

    -- Random leg connected-hair
    local legHairUrl = limbHairTextures[math.ceil(math.random() * #limbHairTextures)]
    local legHairBgHex = randomHexColor()
    for _, part in ipairs({'luleg', 'ruleg'}) do
        CharacterManager.updateConnectedAppearance(instance, part, 'connected-hair',
            { bgURL = legHairUrl .. '.png', bgHex = legHairBgHex })
    end

    -- Torso connected-hair (uses leg hair for continuity)
    for i = 1, count do
        CharacterManager.updateConnectedAppearance(instance, 'torso' .. i, 'connected-hair',
            { bgURL = legHairUrl .. '.png', bgHex = legHairBgHex })
    end

    -- Random face (eyes + pupils)
    -- rebuildFromCreation below flips isPotatoHead, so update both head and torso1
    local randomEyeY = 0.3 + math.random() * 0.3
    local randomMouthY = randomEyeY + 0.15 + math.random() * 0.2
    local faceValues = {
        eyeShape = math.ceil(math.random() * #eyeShapes),
        pupilShape = math.ceil(math.random() * #pupilShapes),
        eyeX = 0.1 + math.random() * 0.3,
        eyeY = randomEyeY,
        eyeWMul = 0.5 + math.random() * 1.0,
        eyeHMul = 0.5 + math.random() * 1.0,
        pupilWMul = 0.2 + math.random() * 0.6,
        pupilHMul = 0.2 + math.random() * 0.6,
        eyeBgHex = '000000ff',
        eyeFgHex = 'ffffffff',
        pupilBgHex = '000000ff',
        mouthShape = math.ceil(math.random() * #mouthShapes.normalized),
        mouthUpperLipShape = math.ceil(math.random() * #upperLipShapes),
        mouthLowerLipShape = math.ceil(math.random() * #lowerLipShapes),
        mouthLipHex = 'cc5555ff',
        mouthBackdropHex = '00000033',
        mouthLipScale = 0.1 + math.random() * 0.3,
        mouthWMul = 0.5 + math.random() * 1.0,
        mouthHMul = 0.5 + math.random() * 1.0,
        mouthY = randomMouthY,
        browShape = math.ceil(math.random() * #browShapes),
        browBgHex = '000000ff',
        browWMul = 0.8 + math.random() * 0.5,
        browHMul = 0.6 + math.random() * 0.8,
        browBend = math.ceil(math.random() * 10),
        browY = 0.25 + math.random() * 0.1,
        noseShape = math.ceil(math.random() * #noseShapes),
        noseBgHex = '000000ff',
        noseFgHex = randomHexColor(),
        noseWMul = 0.5 + math.random() * 2,
        noseHMul = 0.5 + math.random() * 2,
        noseY = 0.3 + math.random() * 0.2,
    }
    CharacterManager.updateFaceOfPart(instance, 'head', faceValues)
    CharacterManager.updateFaceOfPart(instance, 'torso1', faceValues)

    -- Disable physics nose when overlay nose is randomized
    CharacterManager.rebuildFromCreation(instance, { isPotatoHead = not creation.isPotatoHead, noseSegments = 0 })
    CharacterManager.addTexturesFromInstance2(instance)
end

return lib

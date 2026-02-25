local lib = {}

local ui = require('src.ui.all')
local state = require('src.state')
local utils = require('src.utils')
local randomHexColor = utils.randomHexColor
local CharacterManager = require('src.character-manager')
local mipoRegistry = require('src.mipo-registry')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')
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

-- Textures for connected-skin (OMP, has outline + mask pairs)
local limbSkinTextures = {
    'leg1', 'leg2', 'leg3', 'leg4', 'leg5', 'leg7'
}

-- Textures for connected-hair (2-layer, outline only, no mask)
local limbHairTextures = {
    'hair1', 'hair2', 'hair3', 'hair4', 'hair5',
    'hair6', 'hair7', 'hair8', 'hair9', 'hair10', 'hair11'
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

local function drawThumbnailGrid(items, currentURL, panelX, startY, cellSize, onSelect)
    local itemsPerRow = math.floor((PANEL_WIDTH - 20) / cellSize)
    local clicked = false
    for i, item in ipairs(items) do
        local row = math.floor((i - 1) / itemsPerRow)
        local col = (i - 1) % itemsPerRow
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

    local totalRows = math.ceil(#items / itemsPerRow)
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

function lib.drawMipoEditor(instance, partName)
    local panelWidth = PANEL_WIDTH
    local w, h = love.graphics.getDimensions()
    local panelX = w - panelWidth - 20

    ui.panel(panelX, 20, panelWidth, h - 40, 'mipo: ' .. (partName or '?'), function()
        local padding = BUTTON_SPACING
        local x = panelX + padding
        local y = 60 + padding
        local ROW = BUTTON_HEIGHT + BUTTON_SPACING

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

            -- noseSegments
            local noses = ui.sliderWithInput('mipo_noseSeg', x, y, 120, 0, 5, creation.noseSegments or 0, false, 1)
            ui.alignedLabel(x, y, '  nose segments')
            if noses then
                local val = math.floor(noses)
                if val ~= creation.noseSegments then
                    CharacterManager.rebuildFromCreation(instance, { noseSegments = val })
                    CharacterManager.addTexturesFromInstance2(instance)
                end
            end
            y = y + ROW

            -- suppress unused warning
            local _ = changed
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
                local patches = { 'main', 'patch1', 'patch2' }
                -- Skin uses full OMP (Outline + Mask + Pattern) composite rendering:
                --   bg/outline: tints the hand-drawn outline strokes
                --   fg/fill:    tints the interior via grayscale mask
                --   p/pattern:  tints the decorative pattern overlay (from textures/pat/)
                for _, patch in ipairs(patches) do
                    if skin[patch] then
                        ui.label(x, y, patch)
                        y = y + ROW
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

                        handlePaletteButton('mipo_p_' .. partName .. '_' .. patch,
                            x + 30, y, 140, skin[patch].pHex, function(color)
                                CharacterManager.updateSkinOfPart(instance, partName, { pHex = color }, patch)
                                CharacterManager.addTexturesFromInstance2(instance)
                            end)
                        ui.alignedLabel(x + 180, y, 'pattern')
                        y = y + ROW
                    end
                end
            end)
        end

        -- === BODYHAIR ACCORDION ===
        if partData and partData.appearance and partData.appearance['bodyhair'] then
            drawAccordion(partName .. ' bodyhair', function()
                local bh = partData.appearance['bodyhair']
                if bh['main'] then
                    local currentBG = bh['main'].bgURL or ''
                    local cellSize = 50
                    local gridHeight = drawThumbnailGrid(bodyhairTextures, currentBG, panelX, y, cellSize,
                        function(url)
                            local count = instance.dna.creation.torsoSegments or 1
                            for i = 1, count do
                                CharacterManager.updateBodyhairOfPart(instance, 'torso' .. i,
                                    { bgURL = url, fgURL = url:gsub('%.png', '-mask.png') })
                            end
                            CharacterManager.addTexturesFromInstance2(instance)
                        end)
                    y = y + gridHeight + BUTTON_SPACING

                    -- bodyhair colors (2-layer: outline + fill, no pattern)
                    handlePaletteButton('mipo_bh_bg_' .. partName,
                        x + 30, y, 140, bh['main'].bgHex, function(color)
                            local count = instance.dna.creation.torsoSegments or 1
                            for i = 1, count do
                                CharacterManager.updateBodyhairOfPart(instance, 'torso' .. i, { bgHex = color })
                            end
                            CharacterManager.addTexturesFromInstance2(instance)
                        end)
                    ui.alignedLabel(x + 180, y, 'outline')
                    y = y + ROW

                    handlePaletteButton('mipo_bh_fg_' .. partName,
                        x + 30, y, 140, bh['main'].fgHex, function(color)
                            local count = instance.dna.creation.torsoSegments or 1
                            for i = 1, count do
                                CharacterManager.updateBodyhairOfPart(instance, 'torso' .. i, { fgHex = color })
                            end
                            CharacterManager.addTexturesFromInstance2(instance)
                        end)
                    ui.alignedLabel(x + 180, y, 'fill')
                    y = y + ROW
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
            drawAccordion(partName .. ' skin', function()
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

                    handlePaletteButton('mipo_cs_p_' .. partName,
                        x + 30, y, 140, cs.pHex, function(color)
                            CharacterManager.updateConnectedAppearance(instance, connSkinOwner, 'connected-skin',
                                { pHex = color })
                            CharacterManager.addTexturesFromInstance2(instance)
                        end)
                    ui.alignedLabel(x + 180, y, 'pattern')
                    y = y + ROW
                end
            end)
        end

        -- === CONNECTED-HAIR ACCORDION (arms, legs) ===
        -- connected-hair uses 2-layer rendering (outline + fill, no pattern).
        local connHairOwner = partName
        if not (partData and partData.appearance and partData.appearance['connected-hair']) then
            connHairOwner = getLimbRoot(partName)
        end
        local connHairData = connHairOwner and instance.dna.parts[connHairOwner]
        if connHairData and connHairData.appearance and connHairData.appearance['connected-hair'] then
            drawAccordion(partName .. ' hair', function()
                local ch = connHairData.appearance['connected-hair'].main
                if ch then
                    -- Texture thumbnail grid
                    local currentURL = ch.bgURL or ''
                    local cellSize = 50
                    local gridHeight = drawThumbnailGrid(limbHairTextures, currentURL, panelX, y, cellSize,
                        function(url)
                            -- Hair uses outline only (no mask), so only update bgURL
                            CharacterManager.updateConnectedAppearance(instance, connHairOwner, 'connected-hair',
                                { bgURL = url })
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

                    -- Hair is 2-layer (outline only, no mask/fill)
                    handlePaletteButton('mipo_ch_bg_' .. partName,
                        x + 30, y, 140, ch.bgHex, function(color)
                            CharacterManager.updateConnectedAppearance(instance, connHairOwner, 'connected-hair',
                                { bgHex = color })
                            CharacterManager.addTexturesFromInstance2(instance)
                        end)
                    ui.alignedLabel(x + 180, y, 'outline')
                    y = y + ROW
                end
            end)
        end

        -- === DISSOLVE BUTTON ===
        y = y + BUTTON_SPACING
        love.graphics.line(x, y, x + panelWidth - 40, y)
        y = y + BUTTON_SPACING
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

    -- Random colors (from key 'q')
    for i = 1, count do
        local bgHex = '000000ff'
        local fgHex = randomHexColor()
        local pHex = randomHexColor()
        CharacterManager.updateSkinOfPart(instance, 'torso' .. i,
            { bgHex = bgHex, fgHex = fgHex, pHex = pHex })
        CharacterManager.updateSkinOfPart(instance, 'torso' .. i,
            { bgHex = bgHex, fgHex = fgHex, pHex = pHex }, 'patch1')
        CharacterManager.updateSkinOfPart(instance, 'torso' .. i,
            { bgHex = bgHex, fgHex = fgHex, pHex = pHex }, 'patch2')
    end

    -- Random ears (from key 'e')
    local earUrls = earShapes
    local earUrlIndex = math.ceil(math.random() * #earUrls)
    local earUrl = earUrls[earUrlIndex]
    local earS = 1 + math.random() * 1
    local earSy = love.math.random()
    CharacterManager.updatePart('lear',
        { shape8URL = earUrl .. '.png', sy = earS, sx = -earS * earSy },
        instance)
    CharacterManager.updatePart('rear',
        { shape8URL = earUrl .. '.png', sy = earS, sx = earS * earSy },
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

    CharacterManager.rebuildFromCreation(instance, { isPotatoHead = not creation.isPotatoHead })
    CharacterManager.addTexturesFromInstance2(instance)
end

return lib

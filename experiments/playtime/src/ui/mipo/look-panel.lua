-- src/ui/mipo/look-panel.lua (split from ui/mipo-editor.lua, SPLIT3)
local lib = {}

local CharacterManager = require('src.character-manager')
local C = require('src.shape-catalogs')
local topology = require('src.character-topology')
local widgets = require('src.ui.mipo.widgets')
local ui = widgets.ui
local drawThumbnailGrid, handlePaletteButton = widgets.drawThumbnailGrid, widgets.handlePaletteButton
local drawPatternControls = widgets.drawPatternControls
local editPartAndMirror = widgets.editPartAndMirror
local bodyhairParts, patchShapes = widgets.bodyhairParts, widgets.patchShapes
local accordionStates = widgets.accordionStates
local BUTTON_SPACING = ui.theme.spacing
local bodyhairTextures = C.bodyhairTextures
local haircutTextures = C.haircutTextures
local hairsWithMask = C.hairsWithMask
local limbSkinTextures = C.limbSkinTextures
local limbHairTextures = C.limbHairTextures

-- === SKIN ACCORDION ===
function lib.drawSkin(p, y)
    local instance, partName, x, panelX, panelWidth, ROW = p.instance, p.partName, p.x, p.panelX, p.panelWidth, p.ROW
    local function drawAccordion(key, content)
        y = widgets.accordionHeader(p, y, key)
        if widgets.isOpen(key) then content() end
    end
    local partData = instance.dna.parts[partName]
    if partData and partData.appearance and partData.appearance['skin'] then
        drawAccordion(partName .. ' skin', function()
            local skin = partData.appearance['skin']
            local function setSkin(patch, vals)
                editPartAndMirror(instance, partName, function(name)
                    CharacterManager.updateSkinOfPart(instance, name, vals, patch)
                end)
            end
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
                                local base = url and url:gsub('%.png$', '')
                                setSkin(patch, base and { bgURL = base .. '.png', fgURL = base .. '-mask.png' }
                                    or { bgURL = '', fgURL = '' })
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
                            if val and val ~= (skin[patch][s.id] or s.default) then -- nil: untouched
                                setSkin(patch, { [s.id] = val })
                            end
                            y = y + ROW
                        end
                    end

                    handlePaletteButton('mipo_bg_' .. partName .. '_' .. patch,
                        x + 30, y, 140, skin[patch].bgHex, function(color)
                            setSkin(patch, { bgHex = color })
                        end)
                    ui.alignedLabel(x + 180, y, 'outline')
                    y = y + ROW

                    handlePaletteButton('mipo_fg_' .. partName .. '_' .. patch,
                        x + 30, y, 140, skin[patch].fgHex, function(color)
                            setSkin(patch, { fgHex = color })
                        end)
                    ui.alignedLabel(x + 180, y, 'fill')
                    y = y + ROW

                    y = drawPatternControls(skin[patch], 'mipo_pat_' .. partName .. '_' .. patch, panelX, y,
                        function(key, value)
                            setSkin(patch, { [key] = value })
                        end)
                    end -- if showPatch
                end
            end
        end)
    end
    return y
end

-- === BODYHAIR ACCORDION ===
-- Bodyhair is per-part (head has its own, each torso segment has its own).
-- For torso parts, changes propagate to all torso segments for consistency.
-- For head (or other parts), changes only affect that part.
function lib.drawBodyhair(p, y)
    local instance, partName, x, panelX, ROW = p.instance, p.partName, p.x, p.panelX, p.ROW
    local partData = p.partData
    local function drawAccordion(key, content)
        y = widgets.accordionHeader(p, y, key)
        if widgets.isOpen(key) then content() end
    end
    if partData and partData.appearance and partData.appearance['bodyhair'] then
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
                        for _, name in ipairs(bodyhairParts(instance, partName)) do clearOrSet(name) end
                        CharacterManager.rebuildTextures(instance)
                    end, true)
                y = y + gridHeight + BUTTON_SPACING

                -- bodyhair colors (2-layer: outline + fill, no pattern)
                handlePaletteButton('mipo_bh_bg_' .. partName,
                    x + 30, y, 140, bh['main'].bgHex, function(color)
                        for _, name in ipairs(bodyhairParts(instance, partName)) do
                            CharacterManager.updateBodyhairOfPart(instance, name, { bgHex = color })
                        end
                        CharacterManager.rebuildTextures(instance)
                    end)
                ui.alignedLabel(x + 180, y, 'outline')
                y = y + ROW

                handlePaletteButton('mipo_bh_fg_' .. partName,
                    x + 30, y, 140, bh['main'].fgHex, function(color)
                        for _, name in ipairs(bodyhairParts(instance, partName)) do
                            CharacterManager.updateBodyhairOfPart(instance, name, { fgHex = color })
                        end
                        CharacterManager.rebuildTextures(instance)
                    end)
                ui.alignedLabel(x + 180, y, 'fill')
                y = y + ROW

                -- Growfactor slider (how much bigger bodyhair is relative to the body)
                local currentGrow = bh.growfactor or 1.2
                ui.alignedLabel(x, y, 'grow')
                local newGrow = ui.slider(
                    x + 40, y, 200, 20, 'horizontal', 0.5, 2.5, currentGrow, 'mipo_bh_grow_' .. partName)
                if newGrow then
                    for _, name in ipairs(bodyhairParts(instance, partName)) do
                        instance.dna.parts[name].appearance['bodyhair'].growfactor = newGrow
                    end
                    CharacterManager.rebuildFromCreation(instance, {})
                end
                y = y + ROW
            end
        end)
    end
    return y
end

-- === HAIRCUT ACCORDION ===
-- Haircut renders on head (non-potato) or torso1 (potato). It traces along
-- the shape outline between startIndex and endIndex with a hair texture.
function lib.drawHaircut(p, y)
    local instance, partName, x, panelX, ROW = p.instance, p.partName, p.x, p.panelX, p.ROW
    local function drawAccordion(key, content)
        y = widgets.accordionHeader(p, y, key)
        if widgets.isOpen(key) then content() end
    end
    local haircutOwner = topology.faceOwner(instance, partName)
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
                        CharacterManager.rebuildTextures(instance)
                    end, true)
                y = y + gridHeight + BUTTON_SPACING

                -- width slider
                local currentWidth = hc.width or 250
                local wVal = ui.sliderWithInput('mipo_hc_w', x, y, 120, 10, 800, currentWidth)
                ui.alignedLabel(x, y, '  width')
                if wVal and wVal ~= currentWidth then
                    CharacterManager.updateHaircutOfPart(instance, haircutOwner, { width = wVal })
                    CharacterManager.rebuildTextures(instance)
                end
                y = y + ROW

                -- startIndex / endIndex sliders
                local si = ui.sliderWithInput('mipo_hc_si', x, y, 120, 0, 16, hc.startIndex or 6, false, 1)
                ui.alignedLabel(x, y, '  start')
                if si then
                    si = math.floor(si)
                    if si ~= hc.startIndex then
                        CharacterManager.updateHaircutOfPart(instance, haircutOwner, { startIndex = si })
                        CharacterManager.rebuildTextures(instance)
                    end
                end
                y = y + ROW

                local ei = ui.sliderWithInput('mipo_hc_ei', x, y, 120, 0, 16, hc.endIndex or 2, false, 1)
                ui.alignedLabel(x, y, '  end')
                if ei then
                    ei = math.floor(ei)
                    if ei ~= hc.endIndex then
                        CharacterManager.updateHaircutOfPart(instance, haircutOwner, { endIndex = ei })
                        CharacterManager.rebuildTextures(instance)
                    end
                end
                y = y + ROW

                -- Color (tints the hair outline)
                handlePaletteButton('mipo_hc_bg_' .. partName,
                    x + 30, y, 140, main.bgHex, function(color)
                        CharacterManager.updateHaircutOfPart(instance, haircutOwner, { bgHex = color })
                        CharacterManager.rebuildTextures(instance)
                    end)
                ui.alignedLabel(x + 180, y, 'outline')
                y = y + ROW

                -- OMP controls (fill + pattern) only for masked hair textures
                if main.fgURL and main.fgURL ~= '' then
                    handlePaletteButton('mipo_hc_fg_' .. partName,
                        x + 30, y, 140, main.fgHex or 'ffffffff', function(color)
                            CharacterManager.updateHaircutOfPart(instance, haircutOwner, { fgHex = color })
                            CharacterManager.rebuildTextures(instance)
                        end)
                    ui.alignedLabel(x + 180, y, 'fill')
                    y = y + ROW

                    y = drawPatternControls(main, 'mipo_hc_pat_' .. partName, panelX, y,
                        function(key, value)
                            CharacterManager.updateHaircutOfPart(instance, haircutOwner, { [key] = value })
                            CharacterManager.rebuildTextures(instance)
                        end)
                end
            end
        end)
    end
    return y
end

-- === CONNECTED-SKIN ACCORDION (arms, legs) ===
-- Connected textures stretch between joint-linked parts (e.g. shoulder to hand).
-- They're defined on the upper limb (luarm, ruleg, etc.) but we show them for
-- any part in the limb chain (lower arm, hand, foot, etc.) via topology.limbRoot().
-- connected-skin uses OMP compositing (outline + fill + pattern).
function lib.drawConnectedSkin(p, y)
    local instance, partName, x, panelX, ROW = p.instance, p.partName, p.x, p.panelX, p.ROW
    local partData = p.partData
    local function drawAccordion(key, content)
        y = widgets.accordionHeader(p, y, key)
        if widgets.isOpen(key) then content() end
    end
    local connSkinOwner = partName
    if not (partData and partData.appearance and partData.appearance['connected-skin']) then
        connSkinOwner = topology.limbRoot(partName)
    end
    local connSkinData = connSkinOwner and instance.dna.parts[connSkinOwner]
    -- Hide neck connected-skin when there are no neck segments
    local connSkinEndNode = connSkinData and connSkinData.appearance
        and connSkinData.appearance['connected-skin']
        and connSkinData.appearance['connected-skin'].endNode
    local hideConnSkin = connSkinEndNode == 'head'
        and instance.dna.creation.neckSegments == 0
    if not hideConnSkin and connSkinData and connSkinData.appearance
        and connSkinData.appearance['connected-skin'] then
        local connLabel = connSkinData.appearance['connected-skin'].endNode
            and (partName .. ' > ' .. connSkinData.appearance['connected-skin'].endNode .. ' skin')
            or (partName .. ' connected skin')
        drawAccordion(connLabel, function()
            local cs = connSkinData.appearance['connected-skin'].main
            if cs then
                -- Texture thumbnail grid
                local currentURL = cs.bgURL or ''
                local cellSize = 50
                local function setConnectedSkin(vals)
                    editPartAndMirror(instance, connSkinOwner, function(name)
                        CharacterManager.updateConnectedAppearance(instance, name, 'connected-skin', vals)
                    end)
                end
                local gridHeight = drawThumbnailGrid(limbSkinTextures, currentURL, panelX, y, cellSize,
                    function(url)
                        local vals = { bgURL = url, fgURL = url:gsub('%.png', '-mask.png') }
                        setConnectedSkin(vals)
                    end)
                y = y + gridHeight + BUTTON_SPACING

                -- wmul (width multiplier) slider
                local currentWmul = cs.wmul or instance.scale or 1
                local wmulVal = ui.sliderWithInput('mipo_cs_wmul_' .. partName, x, y, 120, 0.1, 10,
                    currentWmul)
                ui.alignedLabel(x, y, '  width')
                if wmulVal and wmulVal ~= currentWmul then
                    setConnectedSkin({ wmul = wmulVal })
                end
                y = y + ROW

                -- bendiness: 0 = rubbery (smooth across joints), 6 = crisp corners
                local currentBendiness = cs.bendiness or 2
                local bendVal = ui.sliderWithInput('mipo_cs_bend_' .. partName, x, y, 120, 0, 6,
                    currentBendiness)
                ui.alignedLabel(x, y, '  bendiness')
                if bendVal then bendVal = math.floor(bendVal + 0.5) end
                if bendVal and bendVal ~= currentBendiness then
                    setConnectedSkin({ bendiness = bendVal })
                end
                y = y + ROW

                handlePaletteButton('mipo_cs_bg_' .. partName,
                    x + 30, y, 140, cs.bgHex, function(color)
                        setConnectedSkin({ bgHex = color })
                    end)
                ui.alignedLabel(x + 180, y, 'outline')
                y = y + ROW

                handlePaletteButton('mipo_cs_fg_' .. partName,
                    x + 30, y, 140, cs.fgHex, function(color)
                        setConnectedSkin({ fgHex = color })
                    end)
                ui.alignedLabel(x + 180, y, 'fill')
                y = y + ROW

                y = drawPatternControls(cs, 'mipo_cs_pat_' .. partName, panelX, y,
                    function(key, value)
                        setConnectedSkin({ [key] = value })
                    end)
            end
        end)
    end
    return y
end

-- === CONNECTED-HAIR ACCORDION (arms, legs) ===
-- connected-hair is 2-layer by default; hair7/hair8 have masks (OMP with pattern).
function lib.drawConnectedHair(p, y)
    local instance, partName, x, panelX, ROW = p.instance, p.partName, p.x, p.panelX, p.ROW
    local partData = p.partData
    local function drawAccordion(key, content)
        y = widgets.accordionHeader(p, y, key)
        if widgets.isOpen(key) then content() end
    end
    local connHairOwner = partName
    if not (partData and partData.appearance and partData.appearance['connected-hair']) then
        connHairOwner = topology.limbRoot(partName)
    end
    local connHairData = connHairOwner and instance.dna.parts[connHairOwner]
    -- Hide neck connected-hair when there are no neck segments
    local connHairEndNode = connHairData and connHairData.appearance
        and connHairData.appearance['connected-hair']
        and connHairData.appearance['connected-hair'].endNode
    local hideConnHair = connHairEndNode == 'head'
        and instance.dna.creation.neckSegments == 0
    if not hideConnHair and connHairData and connHairData.appearance
        and connHairData.appearance['connected-hair'] then
        local connHairLabel = connHairData.appearance['connected-hair'].endNode
            and (partName .. ' > ' .. connHairData.appearance['connected-hair'].endNode .. ' hair')
            or (partName .. ' connected hair')
        drawAccordion(connHairLabel, function()
            local ch = connHairData.appearance['connected-hair'].main
            if ch then
                -- Texture thumbnail grid
                local currentURL = ch.bgURL or ''
                local cellSize = 50
                local function setConnectedHair(vals)
                    editPartAndMirror(instance, connHairOwner, function(name)
                        CharacterManager.updateConnectedAppearance(instance, name, 'connected-hair', vals)
                    end)
                end
                local gridHeight = drawThumbnailGrid(limbHairTextures, currentURL, panelX, y, cellSize,
                    function(url)
                        local fgUrl = url and hairsWithMask[url] and url:gsub('%.png', '-mask.png') or ''
                        local vals = { bgURL = url or '', fgURL = fgUrl }
                        setConnectedHair(vals)
                    end, true)
                y = y + gridHeight + BUTTON_SPACING

                -- wmul (width multiplier) slider
                local currentWmul = ch.wmul or instance.scale or 1
                local wmulVal = ui.sliderWithInput('mipo_ch_wmul_' .. partName, x, y, 120, 0.1, 10,
                    currentWmul)
                ui.alignedLabel(x, y, '  width')
                if wmulVal and wmulVal ~= currentWmul then
                    setConnectedHair({ wmul = wmulVal })
                end
                y = y + ROW

                -- Outline color
                handlePaletteButton('mipo_ch_bg_' .. partName,
                    x + 30, y, 140, ch.bgHex, function(color)
                        setConnectedHair({ bgHex = color })
                    end)
                ui.alignedLabel(x + 180, y, 'outline')
                y = y + ROW

                -- OMP controls (fill + pattern) only for masked hair textures
                if ch.fgURL and ch.fgURL ~= '' then
                    handlePaletteButton('mipo_ch_fg_' .. partName,
                        x + 30, y, 140, ch.fgHex or 'ffffffff', function(color)
                            setConnectedHair({ fgHex = color })
                        end)
                    ui.alignedLabel(x + 180, y, 'fill')
                    y = y + ROW

                    y = drawPatternControls(ch, 'mipo_ch_pat_' .. partName, panelX, y,
                        function(key, value)
                            setConnectedHair({ [key] = value })
                        end)
                end
            end
        end)
    end
    return y
end

return lib

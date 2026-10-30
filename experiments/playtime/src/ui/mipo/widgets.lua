-- src/ui/mipo/widgets.lua (split from ui/mipo-editor.lua, SPLIT3): what the Mipo panels share.
local lib = {}
local topology = require('src.character-topology')

local allUI = require('src.ui.all')
local state = require('src.state')
local mipoVoice = require('src.mipo-voice')
local mathutils = require('src.math-utils')

-- The Mipo being edited hmpfs on every change (docs/PUPPETMAKER-SOUND.md P1):
-- the editor draws through this ui, which reports slider and checkbox changes.
local editing
local ui = setmetatable({
    sliderWithInput = function(id, x, y, w, min, max, value, changed, step)
        local result = allUI.sliderWithInput(id, x, y, w, min, max, value, changed, step)
        local v = tonumber(result)
        if v and editing and max > min then
            mipoVoice.edited(editing, mathutils.remap(v, min, max, 0, 1))
        end
        return result
    end,
    checkbox = function(x, y, checked, label)
        local clicked, nowChecked = allUI.checkbox(x, y, checked, label)
        if clicked and editing then mipoVoice.edited(editing) end
        return clicked, nowChecked
    end,
}, { __index = allUI })
local CharacterManager = require('src.character-manager')
local colors = require('src.color')

local C = require('src.shape-catalogs')

local PANEL_WIDTH = ui.theme.panelWidth
local BUTTON_HEIGHT = ui.theme.lineHeight
local BUTTON_SPACING = ui.theme.spacing

local imageCache = {}

local accordionStates = {}
accordionStates.symmetricEditing = true
accordionStates.actions = true

-- Shape categories for thumbnail grids (shared with character-manager via shape-catalogs)
local torsoHeadShapes = C.torsoHeadShapes
local earShapes = C.earShapes
local feetShapes = C.feetShapes
local handShapes = C.handShapes

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

-- The part, and its mirror when symmetric editing is on (and the Mipo has one).
local function partAndMirror(instance, partName)
    local names = { partName }
    local mirror = accordionStates.symmetricEditing and topology.mirrorPart(partName)
    if mirror and instance.dna.parts[mirror] then names[2] = mirror end
    return names
end

-- fn(name) on the part and its mirror (see partAndMirror), then the textures once.
local function editPartAndMirror(instance, partName, fn)
    for _, name in ipairs(partAndMirror(instance, partName)) do fn(name) end
    CharacterManager.rebuildTextures(instance)
end

-- Bodyhair is edited on the whole torso (every segment), else on a part and its mirror.
local function bodyhairParts(instance, partName)
    local names = {}
    if partName:match('^torso') then
        for i = 1, instance.dna.creation.torsoSegments or 1 do names[i] = 'torso' .. i end
        return names
    end
    for _, name in ipairs(partAndMirror(instance, partName)) do
        local appearance = instance.dna.parts[name].appearance
        if appearance and appearance.bodyhair then names[#names + 1] = name end
    end
    return names
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
        if img == nil then -- false: tried, not there (so not tried again every frame)
            local ok, loaded = pcall(love.graphics.newImage, 'textures/' .. url)
            img = ok and loaded or false
            imageCache[url] = img
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
    if clicked and editing then mipoVoice.edited(editing) end

    local totalItems = #items + offset
    local totalRows = math.ceil(totalItems / itemsPerRow)
    return totalRows * cellSize, clicked
end

local function handlePaletteButton(idPrefix, px, py, pw, currentHex, onColorChange)
    local r, g, b, a = colors.hexToColor(currentHex or '000000ff')
    local paletteShow = ui.button(px - 10, py, 20, '', BUTTON_HEIGHT, { r, g, b, a })
    if paletteShow then
        if state.panelVisibility.showPalette then
            state.panelVisibility.showPalette = nil
            state.showPaletteFunc = nil
        else
            state.panelVisibility.showPalette = true
            local instance = editing
            state.showPaletteFunc = function(color)
                onColorChange(color)
                if instance then mipoVoice.edited(instance) end
            end
        end
    end
    local hex = ui.textinput(idPrefix, px + 10, py, pw, BUTTON_HEIGHT, "", currentHex or '')
    if hex and hex ~= currentHex then
        onColorChange(hex)
        if editing then mipoVoice.edited(editing) end
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
            if val and val ~= (block[s.key] or s.default) then
                onUpdate(s.key, val)
            end
            yy = yy + ROW
        end
    end

    return yy
end

-- The panel's accordions: a header row that opens and closes `key`, open state kept here.
function lib.accordionHeader(p, y, key)
    local clicked = ui.header_button(p.x, y, p.panelWidth - 40, (accordionStates[key] and " ÷  " or " •") ..
        ' ' .. key, accordionStates[key])
    if clicked then
        accordionStates[key] = not accordionStates[key]
    end
    return y + p.ROW
end

function lib.isOpen(key) return accordionStates[key] end

-- The Mipo that hmpfs when a slider, checkbox or thumbnail changes (mipoVoice.edited).
function lib.setEditing(instance) editing = instance end

lib.getShapesForPart = getShapesForPart
lib.partAndMirror = partAndMirror
lib.editPartAndMirror = editPartAndMirror
lib.bodyhairParts = bodyhairParts
lib.drawThumbnailGrid = drawThumbnailGrid
lib.handlePaletteButton = handlePaletteButton
lib.drawPatternControls = drawPatternControls
lib.patchShapes = patchShapes
lib.ui = ui
lib.accordionStates = accordionStates

return lib

-- src/ui/mipo/body-panel.lua (split from ui/mipo-editor.lua, SPLIT3)
local lib = {}

local mipoVoice = require('src.mipo-voice')
local utils = require('src.utils')
local CharacterManager = require('src.character-manager')
local mipoRegistry = require('src.mipo-registry')
local mipoActions = require('src.mipo-actions')
local ST = require('src.shape-types')
local C = require('src.shape-catalogs')
local widgets = require('src.ui.mipo.widgets')
local ui = widgets.ui
local drawThumbnailGrid = widgets.drawThumbnailGrid
local getShapesForPart = widgets.getShapesForPart
local editPartAndMirror = widgets.editPartAndMirror
local BUTTON_SPACING = ui.theme.spacing
local limbSkinTextures = C.limbSkinTextures

-- on a spine every band is cut from torso1's shape, so its shape panel edits torso1
local function shapePartFor(instance, partName)
    local creation = instance.dna and instance.dna.creation
    if creation and creation.torsoSpine and (creation.torsoSegments or 1) > 1 and partName:match('^torso%d') then
        return 'torso1'
    end
    return partName
end
lib.shapePartFor = shapePartFor

-- === CREATION ACCORDION ===
function lib.drawCreation(p, y)
    local instance, x, panelX, ROW = p.instance, p.x, p.panelX, p.ROW
    local function drawAccordion(key, content)
        y = widgets.accordionHeader(p, y, key)
        if widgets.isOpen(key) then content() end
    end
    drawAccordion('creation', function()
        local creation = instance.dna.creation
        local changed = false

        -- isPotatoHead checkbox
        local cbClicked, cbChecked = ui.checkbox(x, y, creation.isPotatoHead or false, 'isPotatoHead')
        if cbClicked then
            changed = true
            CharacterManager.rebuildFromCreation(instance, { isPotatoHead = cbChecked })
            CharacterManager.rebuildTextures(instance)
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
                CharacterManager.rebuildTextures(instance)
            end
        end
        y = y + ROW

        -- spine: the torso segments are bands of one torso that bend (docs/MIPO-SPINE.md)
        local spClicked, spChecked = ui.checkbox(x, y, creation.torsoSpine or false, 'spine')
        if spClicked then
            changed = true
            local patch = { torsoSpine = spChecked }
            if spChecked and (creation.torsoSegments or 1) < 2 then patch.torsoSegments = 2 end
            CharacterManager.rebuildFromCreation(instance, patch)
            CharacterManager.rebuildTextures(instance)
        end
        y = y + ROW
        if creation.torsoSpine then
            local bend = ui.sliderWithInput('mipo_spineBend', x, y, 120, 0, 45, creation.spineBend or 15, false, 1)
            ui.alignedLabel(x, y, '  spine bend')
            bend = bend and math.floor(tonumber(bend) or 0)
            if bend and bend ~= creation.spineBend then
                changed = true
                CharacterManager.rebuildFromCreation(instance, { spineBend = bend })
                CharacterManager.rebuildTextures(instance)
            end
            y = y + ROW
            local sway = ui.sliderWithInput('mipo_spineSway', x, y, 120, 0, 1, creation.spineSway or 0.3)
            ui.alignedLabel(x, y, '  spine sway')
            if sway and sway ~= creation.spineSway then creation.spineSway = sway end -- read live
            y = y + ROW
        end

        -- neckSegments
        local ns = ui.sliderWithInput('mipo_neckSeg', x, y, 120, 0, 5, creation.neckSegments or 0, false, 1)
        ui.alignedLabel(x, y, '  neck segments')
        if ns then
            local val = math.floor(ns)
            if val ~= creation.neckSegments then
                changed = true
                CharacterManager.rebuildFromCreation(instance, { neckSegments = val })
                CharacterManager.rebuildTextures(instance)
            end
        end
        y = y + ROW

        -- neck height (adjusts all neck segments at once)
        if (creation.neckSegments or 0) > 0 then
            local firstNeck = instance.dna.parts['neck1']
            local currentH = firstNeck and firstNeck.dims and firstNeck.dims.h or 150
            local nh = ui.sliderWithInput('mipo_neckH', x, y, 120, 10, 500, currentH)
            ui.alignedLabel(x, y, '  neck height')
            if nh and nh ~= currentH then
                for i = 1, creation.neckSegments do
                    CharacterManager.updatePart('neck' .. i, { h = nh }, instance)
                end
                CharacterManager.rebuildTextures(instance)
            end
            y = y + ROW
        end

        -- neck picture and width: the strip from the top torso segment to the head (its
        -- connected-skin; randomize gives it the leg skin), set on every torso segment so a
        -- change of segment count keeps it
        local topTorso = instance.dna.parts['torso' .. (creation.torsoSegments or 1)]
        local neckSkin = not creation.isPotatoHead and topTorso and topTorso.appearance
            and topTorso.appearance['connected-skin']
        if neckSkin and neckSkin.main then
            local function setNeck(values)
                for i = 1, creation.torsoSegments or 1 do
                    CharacterManager.updateConnectedAppearance(instance, 'torso' .. i, 'connected-skin', values)
                end
                CharacterManager.rebuildTextures(instance)
            end
            ui.label(x, y, 'neck skin')
            y = y + ROW
            local gridHeight = drawThumbnailGrid(limbSkinTextures, neckSkin.main.bgURL or '', panelX, y, 50,
                function(url)
                    setNeck({ bgURL = url, fgURL = url:gsub('%.png', '-mask.png') })
                end)
            y = y + gridHeight + BUTTON_SPACING
            local currentWmul = neckSkin.main.wmul or instance.scale or 1
            local neckW = ui.sliderWithInput('mipo_neck_wmul', x, y, 120, 0.1, 10, currentWmul)
            ui.alignedLabel(x, y, '  neck width')
            if neckW and neckW ~= currentWmul then setNeck({ wmul = neckW }) end
            y = y + ROW
        end

        -- noseSegments
        local noses = ui.sliderWithInput('mipo_noseSeg', x, y, 120, 0, 5, creation.noseSegments or 0, false, 1)
        ui.alignedLabel(x, y, '  nose segments')
        if noses then
            local val = math.floor(noses)
            if val ~= creation.noseSegments then
                local updates = { noseSegments = val }
                -- val == 0: no nose — nothing extra
                if val == 1 then
                    -- Keep current noseMode; disable overlay if switching to physics
                    if (creation.noseMode or 'overlay') == 'physics' then
                        local startParent = creation.isPotatoHead and 'torso1' or 'head'
                        CharacterManager.updateFaceOfPart(instance, startParent, { noseShape = 0 })
                    end
                elseif val >= 2 then
                    -- 2+ → segmented, disable overlay
                    updates.noseMode = 'physics'
                    local startParent = creation.isPotatoHead and 'torso1' or 'head'
                    CharacterManager.updateFaceOfPart(instance, startParent, { noseShape = 0 })
                end
                CharacterManager.rebuildFromCreation(instance, updates)
                CharacterManager.rebuildTextures(instance)
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
                CharacterManager.rebuildTextures(instance)
            end
            y = y + ROW
        end

        -- suppress unused warning
        local _ = changed
    end)
    return y
end

-- === POSITIONERS ACCORDION ===
function lib.drawPositioners(p, y)
    local instance, x, ROW = p.instance, p.x, p.ROW
    local function drawAccordion(key, content)
        y = widgets.accordionHeader(p, y, key)
        if widgets.isOpen(key) then content() end
    end
    drawAccordion('positioners', function()
        local pos = instance.dna.positioners

        -- Leg stance width
        local legX = ui.sliderWithInput('mipo_leg_x', x, y, 120, 0, 1, pos.leg.x)
        ui.alignedLabel(x, y, '  leg stance')
        if legX and legX ~= pos.leg.x then
            CharacterManager.updatePositioners(instance, { legX = legX })
            CharacterManager.rebuildFromCreation(instance, {})
            CharacterManager.rebuildTextures(instance)
        end
        y = y + ROW

        -- Ear vertical position
        local earY = ui.sliderWithInput('mipo_ear_y', x, y, 120, 0, 1, pos.ear.y)
        ui.alignedLabel(x, y, '  ear vertical')
        if earY and earY ~= pos.ear.y then
            CharacterManager.updatePositioners(instance, { earY = earY })
            CharacterManager.rebuildFromCreation(instance, {})
            CharacterManager.rebuildTextures(instance)
        end
        y = y + ROW

        -- Ear stance angle (left ear)
        local learPart = instance.dna.parts['lear']
        if learPart then
            local lAngle = learPart.stanceAngle or (-math.pi / 2 + math.pi / 5)
            local lVal = ui.sliderWithInput('mipo_lear_angle', x, y, 120, -math.pi, math.pi, lAngle)
            ui.alignedLabel(x, y, '  L ear angle')
            if lVal and lVal ~= lAngle then
                learPart.stanceAngle = lVal
                CharacterManager.rebuildFromCreation(instance, {})
                CharacterManager.rebuildTextures(instance)
            end
            y = y + ROW
        end

        -- Ear stance angle (right ear)
        local rearPart = instance.dna.parts['rear']
        if rearPart then
            local rAngle = rearPart.stanceAngle or (math.pi / 2 - math.pi / 5)
            local rVal = ui.sliderWithInput('mipo_rear_angle', x, y, 120, -math.pi, math.pi, rAngle)
            ui.alignedLabel(x, y, '  R ear angle')
            if rVal and rVal ~= rAngle then
                rearPart.stanceAngle = rVal
                CharacterManager.rebuildFromCreation(instance, {})
                CharacterManager.rebuildTextures(instance)
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
                CharacterManager.rebuildTextures(instance)
            end
            y = y + ROW
        end

        -- Face magnitude (global face feature scaler)
        local fmVal = ui.sliderWithInput('mipo_face_mag', x, y, 120, 0.25, 2, instance.dna.faceMagnitude or 1)
        ui.alignedLabel(x, y, '  face magnitude')
        if fmVal and fmVal ~= (instance.dna.faceMagnitude or 1) then
            CharacterManager.updatePositioners(instance, { faceMagnitude = fmVal })
            CharacterManager.rebuildTextures(instance)
        end
        y = y + ROW
    end)
    return y
end

-- === ACTIONS ACCORDION ===
function lib.drawActions(p, y)
    local instance, x, panelWidth, ROW = p.instance, p.x, p.panelWidth, p.ROW
    local function drawAccordion(key, content)
        y = widgets.accordionHeader(p, y, key)
        if widgets.isOpen(key) then content() end
    end
    drawAccordion('actions', function()
        -- two per row: one-shot actions as buttons, on/off states as checkboxes
        local hw = math.floor((panelWidth - 40) / 2) - 2
        if ui.button(x, y, hw, 'breathe') then
            mipoActions.breathe(instance)
        end
        local grounded = mipoActions.isGrounded(instance)
        if ui.button(x + hw + 4, y, hw, grounded and 'jump' or 'jump (air)') then
            mipoActions.jump(instance)
        end
        y = y + ROW

        local ragdollClicked = ui.checkbox(x, y, mipoActions.isRagdoll(instance), 'ragdoll')
        if ragdollClicked then mipoActions.setRagdoll(instance, not mipoActions.isRagdoll(instance)) end
        local flipClicked = ui.checkbox(x + hw + 4, y, mipoActions.isFlipped(instance), 'flip')
        if flipClicked then mipoActions.setFlipped(instance, not mipoActions.isFlipped(instance)) end
        y = y + ROW

        local isPointing = mipoActions.isPointing(instance)
        if ui.checkbox(x, y, isPointing, 'point at cursor') then
            if isPointing then mipoActions.stopPointing(instance) else mipoActions.pointAt(instance, 'cursor') end
        end
        y = y + ROW
    end)
    return y
end

-- === SHAPE ACCORDION ===
-- on a spine every band is cut from torso1's shape: whichever band was clicked, the
-- panel edits the whole torso (torso1); edits to an upper band were overwritten
function lib.drawShape(p, y)
    local instance, partName, x, panelX, ROW = p.instance, p.partName, p.x, p.panelX, p.ROW
    local function drawAccordion(key, content)
        y = widgets.accordionHeader(p, y, key)
        if widgets.isOpen(key) then content() end
    end
    local shapePart = shapePartFor(instance, partName)
    local shapes = getShapesForPart(shapePart)
    if shapes then
        local spineTorso = shapePart == 'torso1' and shapePartFor(instance, 'torso2') == 'torso1'
        drawAccordion((spineTorso and 'torso' or shapePart) .. ' shape', function()
            local partData = instance.dna.parts[shapePart]
            if not partData then return end

            local currentURL = partData.shape8URL
            local cellSize = 50
            local gridHeight = drawThumbnailGrid(shapes, currentURL, panelX, y, cellSize, function(url)
                editPartAndMirror(instance, shapePart, function(name)
                    local dims = instance.dna.parts[name].dims
                    CharacterManager.updatePart(name, { shape8URL = url, sx = dims.sx or 1, sy = dims.sy or 1 },
                        instance)
                end)
            end)
            -- Advance y past the grid
            y = y + gridHeight + BUTTON_SPACING

            -- sx slider
            local sxVal = ui.sliderWithInput('mipo_sx', x, y, 120, -10, 10, partData.dims.sx or 1)
            ui.alignedLabel(x, y, '  sx')
            if sxVal and sxVal ~= (partData.dims.sx or 1) then
                editPartAndMirror(instance, shapePart, function(name)
                    local data = instance.dna.parts[name]
                    CharacterManager.updatePart(name,
                        { shape8URL = data.shape8URL, sx = sxVal, sy = data.dims.sy or 1 }, instance)
                end)
            end
            y = y + ROW

            -- sy slider
            local syVal = ui.sliderWithInput('mipo_sy', x, y, 120, -10, 10, partData.dims.sy or 1)
            ui.alignedLabel(x, y, '  sy')
            if syVal and syVal ~= (partData.dims.sy or 1) then
                editPartAndMirror(instance, shapePart, function(name)
                    local data = instance.dna.parts[name]
                    CharacterManager.updatePart(name,
                        { shape8URL = data.shape8URL, sx = data.dims.sx or 1, sy = syVal }, instance)
                end)
            end
            y = y + ROW
            -- NOTE: h/w sliders are NOT shown here for SHAPE8 parts.
            -- SHAPE8 physics shapes come from pre-computed vertices in shape8Dict,
            -- scaled only by sx/sy. The dims.h and dims.w values are vestigial for
            -- SHAPE8 parts — they don't affect the physics shape, textures, or joint
            -- anchors. Only CAPSULE parts (arms, legs, neck) use h/w for their shape.
        end)
    end
    return y
end

-- === CAPSULE DIMENSIONS (arms, legs, neck) ===
-- Only CAPSULE parts use h/w for their physics shape. h controls the length
-- of the capsule polygon and is used for joint anchor positioning (±h/2).
-- w controls the width. SHAPE8 parts ignore h/w entirely — their shape comes
-- from pre-computed vertices scaled by sx/sy.
function lib.drawDims(p, y)
    local instance, partName, x, ROW = p.instance, p.partName, p.x, p.ROW
    local function drawAccordion(key, content)
        y = widgets.accordionHeader(p, y, key)
        if widgets.isOpen(key) then content() end
    end
    local limbData = instance.dna.parts[partName]
    if limbData and limbData.shape == ST.CAPSULE and limbData.dims then
        drawAccordion(partName .. ' dims', function()
            if limbData.dims.h then
                local hVal = ui.sliderWithInput('mipo_limb_h', x, y, 120, 10, 1500, limbData.dims.h or 100)
                ui.alignedLabel(x, y, '  h')
                if hVal and hVal ~= limbData.dims.h then
                    editPartAndMirror(instance, partName, function(name)
                        CharacterManager.updatePart(name, { h = hVal }, instance)
                    end)
                end
                y = y + ROW
            end
            if limbData.dims.w then
                local wVal = ui.sliderWithInput('mipo_limb_w', x, y, 120, 5, 500, limbData.dims.w or 40)
                ui.alignedLabel(x, y, '  w')
                if wVal and wVal ~= limbData.dims.w then
                    editPartAndMirror(instance, partName, function(name)
                        CharacterManager.updatePart(name, { w = wVal }, instance)
                    end)
                end
                y = y + ROW
            end
        end)
    end
    return y
end

-- === RANDOMIZE BUTTONS ===
function lib.drawRandomize(p, y)
    local instance, partName, x, panelWidth, ROW = p.instance, p.partName, p.x, p.panelWidth, p.ROW
    y = y + BUTTON_SPACING
    love.graphics.line(x, y, x + panelWidth - 40, y)
    y = y + BUTTON_SPACING

    local partLabel = partName
    if partName == 'lear' or partName == 'rear' then partLabel = 'ears'
    elseif partName == 'lfoot' or partName == 'rfoot' then partLabel = 'feet'
    elseif partName == 'lhand' or partName == 'rhand' then partLabel = 'hands'
    elseif partName:match('arm') then partLabel = 'arms'
    elseif partName:match('leg') then partLabel = 'legs'
    end
    if ui.button(x, y, panelWidth - 40, 'randomize ' .. partLabel) then
        CharacterManager.randomizePart(instance, partName)
        mipoVoice.dice(instance)
    end
    y = y + ROW
    local hw = math.floor((panelWidth - 40) / 2) - 2
    if ui.button(x, y, hw, 'randomize all') then
        CharacterManager.randomizeMipo(instance)
        mipoVoice.dice(instance)
    end
    if ui.button(x + hw + 4, y, hw, 'randomize *') then
        CharacterManager.randomizeMipoConstrained(instance)
        mipoVoice.dice(instance)
    end
    y = y + ROW
    if ui.button(x, y, hw, 'mutate sizes') then
        CharacterManager.mutateSizes(instance)
        mipoVoice.dice(instance)
    end

    -- === DISSOLVE BUTTON === (next to mutate sizes)
    if ui.button(x + hw + 4, y, hw, 'dissolve') then
        for pName, part in pairs(instance.parts) do
            if part and part.body and not part.body:isDestroyed() then
                local thing = utils.thingOf(part.body)
                if thing then
                    thing.mipoId = nil
                    thing.mipoPartName = nil
                end
            end
            local _ = pName
        end
        mipoRegistry.unregister(instance.id)
    end
    y = y + ROW
    return y
end

return lib

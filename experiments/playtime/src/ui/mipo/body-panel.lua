-- src/ui/mipo/body-panel.lua (split from ui/mipo-editor.lua, SPLIT3)
local lib = {}

local CharacterManager = require('src.character-manager')
local torsoLobes = require('src.torso-lobes')
local torsoJiggle = require('src.torso-jiggle')
local ST = require('src.shape-types')
local C = require('src.shape-catalogs')
local widgets = require('src.ui.mipo.widgets')
local ui = widgets.ui
local drawThumbnailGrid = widgets.drawThumbnailGrid
local getShapesForPart = widgets.getShapesForPart
local editPartAndMirror = widgets.editPartAndMirror
local BUTTON_SPACING = ui.theme.spacing
local limbSkinTextures = C.limbSkinTextures

-- a part's scale (sx / sy) kept at least MIN_SCALE from zero, its sign (the mirror) kept; nil stays nil
local MIN_SCALE = 0.1
local function awayFromZero(v)
    if v == nil or math.abs(v) >= MIN_SCALE then return v end
    return v < 0 and -MIN_SCALE or MIN_SCALE
end

-- on a spine every band is cut from torso1's shape, so its shape panel edits torso1
local function shapePartFor(instance, partName)
    local creation = instance.dna and instance.dna.creation
    if creation and creation.torsoSpine and (creation.torsoSegments or 1) > 1 and partName:match('^torso%d') then
        return 'torso1'
    end
    return partName
end
lib.shapePartFor = shapePartFor

-- === THE DNA'S CREATION: rows for the torso, neck and nose sections below ===
local function rebuild(instance, patch)
    CharacterManager.rebuildFromCreation(instance, patch)
    CharacterManager.rebuildTextures(instance)
end

-- the nose drawn on the face goes when the nose becomes a body (physics, or 2+ segments)
local function clearOverlayNose(instance, creation)
    local startParent = creation.isPotatoHead and 'torso1' or 'head'
    CharacterManager.updateFaceOfPart(instance, startParent, { noseShape = 0 })
end

-- back to a nose drawn on the face: going physics set its shape to none (clearOverlayNose), so it gets one
local function restoreOverlayNose(instance, creation)
    local owner = creation.isPotatoHead and 'torso1' or 'head'
    local part = instance.dna.parts[owner]
    local nose = part and part.appearance and part.appearance.face and part.appearance.face.nose
    if not (nose and (nose.shape or 0) > 0) then
        CharacterManager.updateFaceOfPart(instance, owner, { noseShape = math.random(#C.noseShapes) })
    end
end

-- potato head, torso segments, spine (bend, sway)
local function drawTorsoRows(instance, creation, x, y, ROW)
    local cbClicked, cbChecked = ui.checkbox(x, y, creation.isPotatoHead or false, 'potato head')
    if cbClicked then rebuild(instance, { isPotatoHead = cbChecked }) end
    y = y + ROW

    local ts = ui.sliderWithInput('mipo_torsoSeg', x, y, 120, 1, 5, creation.torsoSegments or 1, false, 1)
    ui.alignedLabel(x, y, '  torso segments')
    if ts and math.floor(ts) ~= creation.torsoSegments then
        rebuild(instance, { torsoSegments = math.floor(ts) })
    end
    y = y + ROW

    -- spine: the torso segments are bands of one torso that bend (docs/MIPO-SPINE.md)
    local spClicked, spChecked = ui.checkbox(x, y, creation.torsoSpine or false, 'spine')
    if spClicked then
        local patch = { torsoSpine = spChecked }
        if spChecked and (creation.torsoSegments or 1) < 2 then patch.torsoSegments = 2 end
        rebuild(instance, patch)
    end
    y = y + ROW
    if creation.torsoSpine then
        local bend = ui.sliderWithInput('mipo_spineBend', x, y, 120, 0, 45, creation.spineBend or 15, false, 1)
        ui.alignedLabel(x, y, '  spine bend')
        bend = bend and math.floor(tonumber(bend) or 0)
        if bend and bend ~= creation.spineBend then rebuild(instance, { spineBend = bend }) end
        y = y + ROW
        local sway = ui.sliderWithInput('mipo_spineSway', x, y, 120, 0, 1, creation.spineSway or 0.3)
        ui.alignedLabel(x, y, '  spine sway')
        if sway and sway ~= creation.spineSway then creation.spineSway = sway end -- read live
        y = y + ROW
    end

    -- lobes: soft round bodies at the torso's ends, found from its shape (src/torso-lobes.lua);
    -- with a spine each hangs from its own band
    local loClicked, loChecked = ui.checkbox(x, y, creation.torsoLobes or false, 'lobes')
    if loClicked then
        rebuild(instance, { torsoLobes = loChecked })
    end
    y = y + ROW
    if creation.torsoLobes then
        local depth = ui.sliderWithInput('mipo_lobeDepth', x, y, 120, 0.15, 0.6, creation.lobeDepth or 0.35)
        ui.alignedLabel(x, y, '  lobe depth')
        depth = depth and math.floor((tonumber(depth) or 0.35) * 20 + 0.5) / 20
        if depth and depth ~= creation.lobeDepth then rebuild(instance, { lobeDepth = depth }) end
        y = y + ROW
        -- softness: 0 firm .. 1 jelly, sets spring and damping below (live)
        local soft = ui.sliderWithInput('mipo_softness', x, y, 120, 0, 1, creation.softness or 0.5)
        ui.alignedLabel(x, y, '  softness')
        if soft and soft ~= creation.softness then
            torsoLobes.applySoftness(creation, soft)
            torsoLobes.setSprings(instance)
        end
        y = y + ROW
        local spring = ui.sliderWithInput('mipo_lobeSpring', x, y, 120, 0.5, 10, creation.lobeSpring or 5.5)
        ui.alignedLabel(x, y, '  lobe spring (Hz)')
        local damping = ui.sliderWithInput('mipo_lobeDamping', x, y + ROW, 120, 0, 1, creation.lobeDamping or 0.38)
        ui.alignedLabel(x, y + ROW, '  lobe damping')
        if (spring and spring ~= creation.lobeSpring) or (damping and damping ~= creation.lobeDamping) then
            creation.lobeSpring = spring or creation.lobeSpring
            creation.lobeDamping = damping or creation.lobeDamping
            torsoLobes.setSprings(instance) -- live, no rebuild
        end
        y = y + 2 * ROW
    end

    -- jiggle: the torso picture soft, drawn only (src/torso-jiggle.lua); all read live
    local jiClicked, jiChecked = ui.checkbox(x, y, creation.torsoJiggle or false, 'jiggle (drawn)')
    if jiClicked then creation.torsoJiggle = jiChecked end
    y = y + ROW
    if creation.torsoJiggle then
        local J = torsoJiggle.defaults
        local rows = {
            { 'jiggleAmount', 0, 3, 'jiggle amount' },
            { 'jiggleSpring', 0.5, 8, 'jiggle spring (Hz)' },
            { 'jiggleDamping', 0, 1, 'jiggle damping' },
            { 'headJiggle', 0, 1, 'head share' },
        }
        for _, row in ipairs(rows) do
            local key = row[1]
            local v = ui.sliderWithInput('mipo_' .. key, x, y, 120, row[2], row[3], creation[key] or J[key])
            ui.alignedLabel(x, y, '  ' .. row[4])
            if v and v ~= creation[key] then creation[key] = v end
            y = y + ROW
        end
    end
    return y
end

-- neck picture and width: the strip from the top torso segment to the head (its
-- connected-skin; randomize gives it the leg skin), set on every torso segment so a
-- change of segment count keeps it
local function drawNeckSkin(instance, creation, x, panelX, y, ROW)
    local topTorso = instance.dna.parts['torso' .. (creation.torsoSegments or 1)]
    local neckSkin = not creation.isPotatoHead and topTorso and topTorso.appearance
        and topTorso.appearance['connected-skin']
    if not (neckSkin and neckSkin.main) then return y end
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
    return y + ROW
end

-- neck segments, height (all segments at once), skin
local function drawNeckRows(instance, creation, x, panelX, y, ROW)
    local ns = ui.sliderWithInput('mipo_neckSeg', x, y, 120, 0, 5, creation.neckSegments or 0, false, 1)
    ui.alignedLabel(x, y, '  neck segments')
    if ns and math.floor(ns) ~= creation.neckSegments then
        rebuild(instance, { neckSegments = math.floor(ns) })
    end
    y = y + ROW

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
    return drawNeckSkin(instance, creation, x, panelX, y, ROW)
end

-- nose segments; with one, whether it's a body (physics) or drawn on the face (overlay)
local function drawNoseRows(instance, creation, x, y, ROW)
    local noses = ui.sliderWithInput('mipo_noseSeg', x, y, 120, 0, 5, creation.noseSegments or 0, false, 1)
    ui.alignedLabel(x, y, '  nose segments')
    local val = noses and math.floor(noses)
    if val and val ~= creation.noseSegments then
        local updates = { noseSegments = val }
        -- 0: no nose; 1: keeps its noseMode (a physics one has no overlay); 2+: segmented
        if val == 1 and (creation.noseMode or 'overlay') == 'physics' then
            clearOverlayNose(instance, creation)
        elseif val >= 2 then
            updates.noseMode = 'physics'
            clearOverlayNose(instance, creation)
        end
        rebuild(instance, updates)
    end
    y = y + ROW

    -- a body or drawn on the face; 2+ segments are always bodies, so unticking goes back to one drawn nose
    local segments = creation.noseSegments or 0
    if segments >= 1 then
        local physics = segments >= 2 or (creation.noseMode or 'overlay') == 'physics'
        local clicked, checked = ui.checkbox(x, y, physics, 'physics nose')
        if clicked then
            if checked then
                clearOverlayNose(instance, creation)
                rebuild(instance, { noseMode = 'physics' })
            else
                restoreOverlayNose(instance, creation)
                rebuild(instance, { noseSegments = 1, noseMode = 'overlay' })
            end
        end
        y = y + ROW
    end
    return y
end

-- === THE NECK (picked on the skeleton: a neck band's tab, or the faint neck of a Mipo without one) ===
-- on or off (off: no neck bodies, the strip from body to head stays), its segments, height and skin.
-- asTab: as a neck band's tab (a header the tab row collects); else drawn straight away.
function lib.drawNeck(p, y, asTab)
    local instance, x, panelX, ROW = p.instance, p.x, p.panelX, p.ROW
    if asTab then
        local key = p.partName .. ' neck'
        y = widgets.accordionHeader(p, y, key)
        if not widgets.isOpen(key) then return y end
    end
    local creation = instance.dna.creation -- read once: a rebuild may give the dna a new creation table
    if creation.isPotatoHead then
        ui.label(x, y, 'a potato head has no neck')
        return y + ROW
    end
    local on = (creation.neckSegments or 0) > 0
    local clicked, checked = ui.checkbox(x, y, on, 'neck')
    if clicked then rebuild(instance, { neckSegments = checked and 1 or 0 }) end
    y = y + ROW
    if on then return drawNeckRows(instance, creation, x, panelX, y, ROW) end
    return drawNeckSkin(instance, creation, x, panelX, y, ROW)
end

-- === THE TORSO'S BUILD (a torso band's 'body' tab): potato head, segments, spine, lobes, jiggle ===
function lib.drawTorso(p, y)
    local instance, x, ROW = p.instance, p.x, p.ROW
    if not (p.partName and p.partName:match('^torso%d')) then return y end
    local key = p.partName .. ' body'
    y = widgets.accordionHeader(p, y, key)
    if not widgets.isOpen(key) then return y end
    return drawTorsoRows(instance, instance.dna.creation, x, y, ROW) -- creation read once: a rebuild may replace it
end

-- === THE NOSE (picked on the skeleton: a nose band's tab, or the faint nose of a Mipo without a nose body) ===
-- its segments; with one, a body or drawn on the face (its look is in the face section's nose)
function lib.drawNose(p, y, asTab)
    local instance, x, ROW = p.instance, p.x, p.ROW
    if asTab then
        local key = p.partName .. ' nose'
        y = widgets.accordionHeader(p, y, key)
        if not widgets.isOpen(key) then return y end
    end
    return drawNoseRows(instance, instance.dna.creation, x, y, ROW)
end

-- === PLACE (a part's tab: where the legs and ears sit on the body, the dna's positioners) ===
-- the upper legs: their stance; the ears: height, this ear's angle (with symmetric the other ear mirrored),
-- over or behind the head
local EAR_ANGLE = { lear = -math.pi / 2 + math.pi / 5, rear = math.pi / 2 - math.pi / 5 } -- the defaults

function lib.drawPlace(p, y)
    local instance, partName, x, ROW = p.instance, p.partName, p.x, p.ROW
    local pos = instance.dna.positioners
    local isLeg, isEar = partName == 'luleg' or partName == 'ruleg', EAR_ANGLE[partName] ~= nil
    if not (isLeg or isEar) then return y end
    y = widgets.accordionHeader(p, y, partName .. ' place')
    if not widgets.isOpen(partName .. ' place') then return y end

    if isLeg then
        local legX = ui.sliderWithInput('mipo_leg_x', x, y, 120, 0, 1, pos.leg.x)
        ui.alignedLabel(x, y, '  leg stance')
        if legX and legX ~= pos.leg.x then
            CharacterManager.updatePositioners(instance, { legX = legX })
            rebuild(instance, {})
        end
        return y + ROW
    end

    local earY = ui.sliderWithInput('mipo_ear_y', x, y, 120, 0, 1, pos.ear.y)
    ui.alignedLabel(x, y, '  ear height')
    if earY and earY ~= pos.ear.y then
        CharacterManager.updatePositioners(instance, { earY = earY })
        rebuild(instance, {})
    end
    y = y + ROW

    local earPart = instance.dna.parts[partName]
    if earPart then
        local angle = earPart.stanceAngle or EAR_ANGLE[partName]
        local value = ui.sliderWithInput('mipo_ear_angle', x, y, 120, -math.pi, math.pi, angle)
        ui.alignedLabel(x, y, '  ear angle')
        if value and value ~= angle then
            earPart.stanceAngle = value
            local other = instance.dna.parts[partName == 'lear' and 'rear' or 'lear']
            if other and widgets.isOpen('symmetricEditing') then other.stanceAngle = -value end
            rebuild(instance, {})
        end
        y = y + ROW
    end

    local learSkin = instance.dna.parts['lear'] and instance.dna.parts['lear'].appearance
        and instance.dna.parts['lear'].appearance['skin']
    if learSkin then
        local earsOver = (learSkin.zOffset or 190) > 200
        local clicked, checked = ui.checkbox(x, y, earsOver, 'ears over head')
        if clicked then
            local newZ = checked and 210 or 190
            learSkin.zOffset = newZ
            local rearSkin = instance.dna.parts['rear'] and instance.dna.parts['rear'].appearance
                and instance.dna.parts['rear'].appearance['skin']
            if rearSkin then rearSkin.zOffset = newZ end
            CharacterManager.rebuildTextures(instance)
        end
        y = y + ROW
    end
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

            -- sx slider (negative mirrors the part; kept off zero: a part 0 wide is a shape Box2D refuses, and
            -- the Mipo was left half rebuilt, MEASURING M6)
            local sxVal = awayFromZero(ui.sliderWithInput('mipo_sx', x, y, 120, -10, 10, partData.dims.sx or 1))
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
            local syVal = awayFromZero(ui.sliderWithInput('mipo_sy', x, y, 120, -10, 10, partData.dims.sy or 1))
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

return lib

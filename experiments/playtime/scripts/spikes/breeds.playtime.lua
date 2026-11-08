-- breeds: a spike for Mipo breeds (docs/MIPO-BREEDS.md): a litter of Mipos of one breed on a
-- floor. A breed narrows the randomizer for its draw: number ranges (dna-defaults randomRanges),
-- shape lists (shape-catalogs, picked by eye: there are no tags yet, B1), a colour palette
-- (character-manager setRandomColor) and the body's build (neck segments). Everything else
-- stays random, so a litter shares a look and still varies.
-- Face patches (right panel): skin colouring under the hair, eyes on top: eye hollows, cheeks, a snout.
-- keys: r: a new litter   1-8: a breed   p: pause   h: hide/show the panels

local s = {}

local LITTER = 6
local SPACING = 520
local GROUND_Y = 900
local ZOOM = 0.42

-- Shapes, grouped by eye (scratch sheets of the masks, 2026-11-01).
local ROUND_BODY = { 'mipo/body/body-03', 'mipo/body/body-07', 'mipo/body/body-10', 'mipo/body/body-12', 'mipo/body/body-14', 'mipo/body/body-16', 'mipo/body/body-17' }
local SQUARE_BODY = { 'mipo/body/body-04', 'mipo/body/body-05', 'mipo/body/body-08', 'mipo/body/body-09', 'mipo/body/body-13', 'mipo/body/body-15' }
local TALL_BODY = { 'mipo/body/body-01', 'mipo/body/body-02', 'mipo/body/body-06', 'mipo/body/body-09', 'mipo/body/body-10', 'mipo/body/body-14' }
local POINTY_BODY = { 'mipo/body/body-01', 'mipo/body/body-11', 'mipo/body/body-15', 'mipo/body/body-17' }
local ROUND_EARS = { 'mipo/ear/ear-01', 'mipo/ear/ear-02', 'mipo/ear/ear-08', 'mipo/ear/ear-09', 'mipo/ear/ear-10', 'mipo/ear/ear-11', 'mipo/ear/ear-12', 'mipo/ear/ear-16' }
local POINTY_EARS = { 'mipo/ear/ear-03', 'mipo/ear/ear-04', 'mipo/ear/ear-05', 'mipo/ear/ear-06', 'mipo/ear/ear-07', 'mipo/ear/ear-13', 'mipo/ear/ear-14', 'mipo/ear/ear-15' }

-- hue in degrees, saturation and lightness 0..1; hues = several bands to draw from
local BREEDS = {
    { name = 'any', note = 'fully random, as today' },
    { name = 'teddy', note = 'round, short thick limbs, small round ears, browns, no teeth',
      ranges = { legH = { 60, 200 }, armH = { 60, 220 }, earScale = { 0.5, 0.8 }, limbWMul = { 0.4, 0.5 },
                 teethChance = 0 },
      lists = { torsoHeadShapes = ROUND_BODY, earShapes = ROUND_EARS },
      palette = { hues = { { 18, 40 } }, sat = { 0.3, 0.6 }, light = { 0.3, 0.55 } },
      creation = { neckSegments = 0 } },
    { name = 'fat', note = 'big round bodies, thick short limbs, soft pastels',
      ranges = { bodyScale = { 1.7, 2.3 }, legH = { 60, 260 }, armH = { 60, 300 }, limbWMul = { 0.45, 0.6 } },
      lists = { torsoHeadShapes = ROUND_BODY },
      palette = { hues = { { 0, 360 } }, sat = { 0.3, 0.5 }, light = { 0.6, 0.78 } },
      creation = { neckSegments = 0 } },
    { name = 'tall', note = 'long neck, long thin legs, narrow bodies, cool colours',
      ranges = { bodyScale = { 1, 1.3 }, legH = { 500, 800 }, armH = { 400, 700 }, limbWMul = { 0.2, 0.28 } },
      lists = { torsoHeadShapes = TALL_BODY },
      palette = { hues = { { 170, 260 } }, sat = { 0.3, 0.6 }, light = { 0.4, 0.65 } },
      creation = { neckSegments = 3 } },
    { name = 'hairy', note = 'everything one warm colour family: skin and hair belong together',
      ranges = { haircutWidth = { 300, 400 } },
      palette = { hues = { { 25, 55 } }, sat = { 0.4, 0.7 }, light = { 0.25, 0.6 } } },
    { name = 'bad', note = 'pointy, angry brows, teeth, sour greens and purples',
      ranges = { browBend = { 8, 10 }, teethChance = 1, teethStickOut = 0.8 },
      lists = { torsoHeadShapes = POINTY_BODY, earShapes = POINTY_EARS },
      palette = { hues = { { 70, 130 }, { 265, 300 } }, sat = { 0.25, 0.5 }, light = { 0.2, 0.42 } } },
    { name = 'geometric', note = 'square bodies, no pattern, bright flat colours',
      lists = { torsoHeadShapes = SQUARE_BODY, patternTextures = { 'pat/type0' } },
      palette = { hues = { { 0, 10 }, { 45, 55 }, { 200, 220 } }, sat = { 0.75, 0.9 }, light = { 0.45, 0.55 } } },
    { name = 'bathhouse', note = "randomizeMipoConstrained, today's Bathhouse Mipos", constrained = true },
}

local function check() -- on state: a script hot reload keeps the litter
    state.breeds = state.breeds or { litter = {}, breed = 2, showPanel = true }
    return state.breeds
end

local function alive(inst)
    local torso = inst and inst.parts and inst.parts.torso1
    return torso and torso.body and not torso.body:isDestroyed()
end

local function lerp(range) return range[1] + math.random() * (range[2] - range[1]) end

local function hslHex(h, s1, l)
    h = (h % 360) / 360
    local function channel(t)
        local q = l < 0.5 and l * (1 + s1) or l + s1 - l * s1
        local p = 2 * l - q
        t = t % 1
        if t < 1 / 6 then return p + (q - p) * 6 * t end
        if t < 1 / 2 then return q end
        if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
        return p
    end
    local function byte(v) return math.floor(math.max(0, math.min(1, v)) * 255 + 0.5) end
    return string.format('%02X%02X%02X%02X', byte(channel(h + 1 / 3)), byte(channel(h)), byte(channel(h - 1 / 3)), 255)
end

local function paletteColor(palette)
    local band = palette.hues[math.random(#palette.hues)]
    return hslHex(lerp(band), lerp(palette.sat), lerp(palette.light))
end

-- One Mipo of the breed: its ranges, lists and palette in place for the draw, then put back.
local function randomizeAs(inst, breed)
    local savedRanges, savedLists = {}, {}
    for key, r in pairs(breed.ranges or {}) do
        savedRanges[key] = dnaDefaults.randomRanges[key]
        dnaDefaults.randomRanges[key] = tonumber(r) or { min = r[1], max = r[2] } -- a chance, or a range
    end
    for key, list in pairs(breed.lists or {}) do
        savedLists[key] = shapeCatalogs[key]
        shapeCatalogs[key] = list
    end
    if breed.palette then
        characterManager.setRandomColor(function() return paletteColor(breed.palette) end)
    end
    if breed.constrained then
        characterManager.randomizeMipoConstrained(inst)
    else
        characterManager.randomizeMipo(inst)
    end
    if breed.creation then
        characterManager.rebuildFromCreation(inst, breed.creation)
        characterManager.limitArmReach(inst)
        characterManager.rebuildTextures(inst)
    end
    characterManager.setRandomColor(nil)
    for key, r in pairs(savedRanges) do dnaDefaults.randomRanges[key] = r end
    for key, list in pairs(savedLists) do shapeCatalogs[key] = list end
end

-- Face patches: skin colouring on the face, under the hair, the eyes on top (eye hollows, cheeks, a
-- snout, as a teddy's). Decals on the face's part between the skin (z 200) and its hair (210),
-- placed from the face's own decals (eyes, nose, mouth), so they sit where this Mipo's face is and
-- turn with it (mipoFacing.applyFace). The picture is baked white once, coloured from the Mipo's
-- skin when drawn (extra.tint): darker hollows, a lighter snout, warmer cheeks.
local PATCH_Z = 205
local PATCH_SHAPES = { 'mipo/patch/patch-01', 'mipo/patch/patch-02', 'mipo/patch/patch-03', 'mipo/patch/patch-04' }

local function patchSettings()
    local c = check()
    c.patches = c.patches or { eyes = true, cheeks = false, snout = true, shape = 1, alpha = 0.9,
        eyeDark = 0.35, eyeSize = 1.8, cheekBlush = 0.5, cheekSize = 1.0, snoutLight = 0.35, snoutSize = 1.0 }
    return c.patches
end

local function hexRGB(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

local function rgbToHsl(r, g, b)
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local l = (mx + mn) / 2
    if mx == mn then return 0, 0, l end
    local d = mx - mn
    local s1 = l > 0.5 and d / (2 - mx - mn) or d / (mx + mn)
    local h
    if mx == r then h = (g - b) / d + (g < b and 6 or 0)
    elseif mx == g then h = (b - r) / d + 2
    else h = (r - g) / d + 4 end
    return h * 60, s1, l
end

local function clamp01(v) return math.max(0, math.min(1, v)) end

local function hslTint(h, s1, l, a)
    local r, g, b = hexRGB(hslHex(h, clamp01(s1), clamp01(l)))
    return { r, g, b, a }
end

local function faceOwner(inst)
    local name = inst.dna.creation.isPotatoHead and 'torso1' or 'head'
    return name, inst.parts[name]
end

-- the face's decals by label, with their front-on place (applyFace keeps it in base*)
local function faceDecals(body)
    local found, mine = {}, {}
    for _, fixture in ipairs(body:getFixtures()) do
        local ud = fixture:getUserData()
        if ud and ud.subtype == 'decal' and ud.label then
            if ud.label:find('^fpatch') then mine[ud.label] = fixture else found[ud.label] = ud.extra end
        end
    end
    return found, mine
end

-- where each patch goes, front-on, in the face part's own frame: { label = {ox, oy, w, h, kind, mirror} }
local function patchPlaces(face, set)
    local places = {}
    local lp, rp = face.lpupil, face.rpupil
    if not (lp and rp) then return places end
    local function eye(p) return p.baseOx or p.ox, p.oy, p.baseEyeW or p.eyeW, p.eyeH end
    local lx, ly, ew, eh = eye(lp)
    local rx, ry = eye(rp)
    local nose, lip = face.nose, face.upperlip or face.lowerlip
    local mouthY = lip and lip.oy or (ly + eh * 2)
    if set.eyes then
        places.fpatchLeye = { lx, ly, ew * set.eyeSize, eh * set.eyeSize, 'eye', true }
        places.fpatchReye = { rx, ry, ew * set.eyeSize, eh * set.eyeSize, 'eye', false }
    end
    if set.cheeks then
        local cy = ly + (mouthY - ly) * 0.75
        local cw = ew * set.cheekSize
        places.fpatchLcheek = { lx * 1.25, cy, cw, cw * 0.75, 'cheek', true }
        places.fpatchRcheek = { rx * 1.25, cy, cw, cw * 0.75, 'cheek', false }
    end
    if set.snout and nose then
        local gap = rx - lx
        local noseX = nose.baseOx or nose.ox
        local h = math.max((mouthY - nose.oy) * 2.4, gap * 0.6) * set.snoutSize
        places.fpatchSnout = { noseX, (nose.oy + mouthY) / 2 + h * 0.1, gap * 0.9 * set.snoutSize, h, 'snout', false }
    end
    return places
end

local function patchTints(inst, set)
    local _, skin = nil, inst.dna.parts[faceOwner(inst)]
    skin = skin and skin.appearance and skin.appearance.skin and skin.appearance.skin.main
    local h, s1, l = rgbToHsl(hexRGB(skin and skin.fgHex or 'A07744FF'))
    local toRed = ((350 - h + 540) % 360) - 180
    return {
        eye = hslTint(h, s1, l * (1 - set.eyeDark), set.alpha),
        cheek = hslTint(h + toRed * set.cheekBlush, s1 + 0.35 * set.cheekBlush, l + 0.05 * set.cheekBlush, set.alpha),
        snout = hslTint(h, s1 * (1 - 0.4 * set.snoutLight), l + (1 - l) * set.snoutLight, set.alpha),
    }
end

local function placePatches(inst)
    if not alive(inst) then return end
    local _, part = faceOwner(inst)
    if not (part and part.body and not part.body:isDestroyed()) then return end
    local set = patchSettings()
    local shape = PATCH_SHAPES[set.shape]
    local face, mine = faceDecals(part.body)
    local places = patchPlaces(face, set)
    local tints = patchTints(inst, set)
    for label, fixture in pairs(mine) do -- gone, or another picture: made again
        if not places[label] or fixture:getUserData().extra.patchShape ~= shape then
            fixtures.destroyFixture(fixture)
            mine[label] = nil
        end
    end
    for label, at in pairs(places) do
        local fixture = mine[label]
        if not fixture then
            fixture = fixtures.createSFixture(part.body, 0, 0, 'decal', { radius = 10 })
            local ud = fixture:getUserData()
            ud.label = label
            local main = { bgURL = shape .. '.png', fgURL = shape .. '-mask.png', pURL = '',
                bgHex = 'ffffff00', fgHex = 'ffffffff', pHex = 'ffffff00' }
            ompBake.makeCached(main)
            ud.extra.main, ud.extra.OMP, ud.extra.dirty = main, true, true
            ud.extra.patchShape, ud.extra.zOffset = shape, PATCH_Z
            ud.extra.zGroupOffset = face.lpupil.zGroupOffset -- each Mipo draws in its own z range
        end
        local e = fixture:getUserData().extra
        e.ox, e.oy, e.w, e.h, e.mirror = at[1], at[2], at[3], at[4], at[6]
        e.baseOx, e.baseW = nil, nil -- front-on again; applyFace turns it as the face is
        e.tint = tints[at[5]]
    end
    mipoFacing.applyFace(inst)
end

local function placeAllPatches()
    for _, inst in ipairs(check().litter) do placePatches(inst) end
end

local function litter()
    local c = check()
    for _, inst in ipairs(c.litter) do
        if alive(inst) then characterManager.removeCharacter(inst) end
    end
    c.litter = {}
    local breed = BREEDS[c.breed]
    for i = 1, LITTER do
        local x = (i - (LITTER + 1) / 2) * SPACING
        local inst = characterManager.createCharacter('humanoid', x, GROUND_Y - 500, 0.3)
        if inst then
            randomizeAs(inst, breed)
            c.litter[i] = inst
        end
    end
    placeAllPatches()
end

local function makeGround()
    local c = check()
    if c.ground and not c.ground:isDestroyed() then return end
    c.ground = love.physics.newBody(world, 0, GROUND_Y + 50, 'static')
    love.physics.newFixture(c.ground, love.physics.newRectangleShape(SPACING * (LITTER + 2), 100)):setFriction(0.9)
end

local function lookAtAll()
    cam:setScale(ZOOM)
    cam:setTranslation(0, GROUND_Y - 380)
    check().hold = true
end

function s.onStart()
    worldState.paused = false
    makeGround()
    local c = check()
    local any = false
    for _, inst in ipairs(c.litter) do any = any or alive(inst) end
    if not any then litter() else placeAllPatches() end
    lookAtAll()
end

function s.onUnload()
    local c = state.breeds
    if c and c.ground and not c.ground:isDestroyed() then c.ground:destroy() end
    if c then c.ground = nil end
end

-- the follow camera moves the view: hold it on the litter until you touch, drag or zoom
function s.update()
    local c = check()
    if not c.hold then return end
    if love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0 or cam.scale ~= ZOOM then
        c.hold = false
    else
        lookAtAll()
    end
end

local function pickBreed(i)
    local c = check()
    c.breed = i
    litter()
    lookAtAll()
end

function s.onKeyPress(key)
    local c = check()
    if key == 'r' then litter() lookAtAll() end
    if key == 'p' then worldState.paused = not worldState.paused end
    if key == 'h' then c.showPanel = not c.showPanel end
    local n = tonumber(key)
    if n and BREEDS[n] then pickBreed(n) end
end

-- the face patches panel, on the right
local PATCH_SLIDERS = {
    { 'eyeDark', 'hollows dark', 0, 1 }, { 'eyeSize', 'hollows size', 1, 3 },
    { 'cheekBlush', 'cheeks blush', 0, 1 }, { 'cheekSize', 'cheeks size', 0.5, 2.5 },
    { 'snoutLight', 'snout light', 0, 1 }, { 'snoutSize', 'snout size', 0.5, 2 },
    { 'alpha', 'opacity', 0.1, 1 },
}
local function drawPatchPanel()
    local set = patchSettings()
    local sw, sh = love.graphics.getDimensions()
    local rowH, w = 32, 330
    local h = rowH * (#PATCH_SLIDERS + 3) + 50
    local x0, y0 = sw - w - 10, 10
    local changed = false
    ui.panel(x0, y0, w, h, '•• face patches ••', function()
        local x, y = x0 + 10, y0 + 34
        for _, key in ipairs({ 'eyes', 'cheeks', 'snout' }) do
            local clicked, checked = ui.checkbox(x, y, set[key], key)
            if clicked then set[key] = checked changed = true end
            x = x + 105
        end
        x, y = x0 + 10, y + rowH
        if ui.button(x, y, w - 20, 'picture: patch-0' .. set.shape .. ' (next)') then
            set.shape = set.shape % #PATCH_SHAPES + 1
            changed = true
        end
        y = y + rowH
        for _, sl in ipairs(PATCH_SLIDERS) do
            ui.alignedLabel(x, y, sl[2])
            local v = ui.sliderWithInput('fpatch_' .. sl[1], x + 115, y, 140, sl[3], sl[4], set[sl[1]])
            if v and v ~= set[sl[1]] then set[sl[1]] = v changed = true end
            y = y + rowH
        end
        if ui.button(x, y, w - 20, 'all off / on') then
            local on = not (set.eyes or set.cheeks or set.snout)
            set.eyes, set.cheeks, set.snout = on, on, on
            changed = true
        end
    end)
    if changed then placeAllPatches() end
end

function s.drawUI()
    local c = check()
    if not (state.playMode and c.showPanel) then return end
    ui.startFrame() -- play mode draws no editor UI, so nothing else starts the frame
    local BH, pad, w = 34, 6, 300
    local h = BH * (#BREEDS + 2) + pad * (#BREEDS + 3) + 24
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• breeds ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 24 })
        for i, breed in ipairs(BREEDS) do
            local x, y = ui.nextLayoutPosition(layout, w - 12, BH)
            local label = i .. '  ' .. breed.name .. (i == c.breed and '  <' or '')
            if ui.button(x, y, w - 12, label) then pickBreed(i) end
        end
        local x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        if ui.button(x, y, w - 12, 'a new litter (r)') then litter() lookAtAll() end
    end)
    local breed = BREEDS[c.breed]
    love.graphics.setColor(0.95, 0.92, 0.8)
    love.graphics.print(breed.name .. ': ' .. breed.note, x0 + w + 20, sh - 40, 0, 1.4, 1.4)
    love.graphics.setColor(1, 1, 1)
    drawPatchPanel()
end

return s

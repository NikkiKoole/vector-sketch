-- breeds: a spike for Mipo breeds (docs/MIPO-BREEDS.md): a litter of Mipos of one breed on a
-- floor. A breed narrows the randomizer for its draw: number ranges (dna-defaults randomRanges),
-- shape lists (shape-catalogs, picked by eye: there are no tags yet, B1), a colour palette
-- (character-manager setRandomColor) and the body's build (neck segments). Everything else
-- stays random, so a litter shares a look and still varies.
-- keys: r: a new litter   1-8: a breed   p: pause   h: hide/show the panel

local s = {}

local LITTER = 6
local SPACING = 520
local GROUND_Y = 900
local ZOOM = 0.42

-- Shapes, grouped by eye (scratch sheets of the masks, 2026-11-01).
local ROUND_BODY = { 'shapeA3', 'shapes3', 'shapes6', 'shapes8', 'shapes10', 'shapes12', 'shapes13' }
local SQUARE_BODY = { 'shapeA4', 'shapes1', 'shapes4', 'shapes5', 'shapes9', 'shapes11' }
local TALL_BODY = { 'shapeA1', 'shapeA2', 'shapes2', 'shapes5', 'shapes6', 'shapes10' }
local POINTY_BODY = { 'shapeA1', 'shapes7', 'shapes11', 'shapes13' }
local ROUND_EARS = { 'earx1r', 'earx2r', 'earx8r', 'earx9r', 'earx10r', 'earx11r', 'earx12r', 'earx16r' }
local POINTY_EARS = { 'earx3r', 'earx4r', 'earx5r', 'earx6r', 'earx7r', 'earx13r', 'earx14r', 'earx15r' }

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
    if not any then litter() end
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
end

return s

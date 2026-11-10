-- breeds: a spike for Mipo breeds (docs/MIPO-BREEDS.md): a litter of Mipos of one breed on a
-- floor. A breed (src/mipo-breeds.lua) narrows the randomizer for its draw: number ranges,
-- shape lists, a colour palette and the body's build. Everything else stays random, so a
-- litter shares a look and still varies.
-- Face patches (right panel): skin colouring under the hair, eyes on top: eye hollows, cheeks, a snout.
-- keys: r: a new litter   1-9: a breed   p: pause   h: hide/show the panels

local s = {}

local LITTER = 6
local SPACING = 520
local GROUND_Y = 900
local ZOOM = 0.42

-- The breeds live in src/mipo-breeds.lua (lib.breeds, lib.order); 'any' is fully random, to compare.
local BREEDS = { { name = 'any', note = 'fully random, as today' } }
for _, name in ipairs(mipoBreeds.order) do
    BREEDS[#BREEDS + 1] = { name = name, note = mipoBreeds.breeds[name].note or '' }
end

local function check() -- on state: a script hot reload keeps the litter
    state.breeds = state.breeds or { litter = {}, breed = 2, showPanel = true }
    return state.breeds
end

local alive = mipoKit.isAlive -- src/mipo-kit.lua

-- One Mipo of the breed ('any': as random as ever).
local function randomizeAs(inst, breed)
    if mipoBreeds.breeds[breed.name] then
        mipoBreeds.randomize(inst, breed.name)
    else
        characterManager.randomizeMipo(inst)
    end
end

-- Face patches (src/face-patches.lua): eye hollows, cheeks, a snout, on every Mipo of the litter,
-- all with the panel's settings (one table, shared).
local function patchSettings()
    local c = check()
    c.patches = c.patches or facePatches.defaults()
    if c.patches.snoutPink == nil then c.patches.snoutPink = facePatches.defaults().snoutPink end -- kept from before
    return c.patches
end

local function placeAllPatches()
    local set = patchSettings()
    for _, inst in ipairs(check().litter) do
        if alive(inst) then
            inst.facePatches = set
            facePatches.place(inst, true)
        end
    end
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
    { 'snoutLight', 'snout light', 0, 1 }, { 'snoutPink', 'snout pink', 0, 1 }, { 'snoutSize', 'snout size', 0.5, 2 },
    { 'alpha', 'opacity', 0.1, 1 },
}
local function drawPatchPanel()
    local set = patchSettings()
    local sw = love.graphics.getDimensions()
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
            set.shape = set.shape % #facePatches.SHAPES + 1
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

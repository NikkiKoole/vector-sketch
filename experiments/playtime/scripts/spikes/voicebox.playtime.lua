-- voicebox: a Mipo voice made from scratch (the synth's formant voice), vowels crossing on a chart, consonants, babble
-- (docs/VOICEBOX.md; Nikki 2026-11-11: "all sorts of vowels crossing visually and audible, the other settings
-- how we can adjust these sounds to make them more mipo and less just recorded people, and some consonants").
-- The panel: press and drag on the vowel chart (heard and seen on the Mipo's mouth while you hold), a
-- consonant button says it with the current vowel, babble says a little phrase, the presets and sliders
-- change who's talking. The left panel (VB3): a recorded take (the voice lab's), played bare / synth / sing
-- at the same pitch, or the same syllable made: A/B. Keys: space hold the vowel, b babble, h the panels.
-- Engine: src/voice-box.lua.
local s = {}

local GROUND_Y = 600
local MIPO_SCALE = 0.9

local function st()
    state.voiceboxScene = state.voiceboxScene or { showPanel = true }
    return state.voiceboxScene
end

local function mipo()
    for _, inst in pairs(mipoRegistry.getAll()) do
        if mipoKit.isAlive(inst) then return inst end
    end
end

local function ensureGround()
    if getObjectsByLabel('ground')[1] then return end
    local thing = objectManager.addThing('rectangle', { x = 0, y = GROUND_Y + 300, width = 6000, height = 600,
        bodyType = 'static', label = 'ground' })
    if not thing then return end
    local tile = fixtures.createSFixture(thing.body, 0, 0, 'tile-repeat', { radius = 20 }):getUserData().extra
    tile.main = tile.main or {}
    tile.main.bgURL, tile.opacity, tile.tileWidthM, tile.tileHeightM = 'world/ground/soil-01.jpg', 1, 0.6, 0.6
end

local function ensureMipo()
    if mipo() then return end
    local inst = characterManager.createCharacter('humanoid', -150, GROUND_Y - 900, MIPO_SCALE)
    if inst then characterManager.randomizeMipoConstrained(inst) end
end

function s.onStart()
    worldState.paused = false
    st()
    voiceBox.settings()
    ensureGround()
    ensureMipo()
end

function s.onSceneUnload() voiceBox.release() end

function s.onKeyPress(key)
    local c = st()
    if key == 'h' then c.showPanel = not c.showPanel end
    if key == 'b' then voiceBox.babble() end
    if key == 'space' and not st().spaceHeld then
        st().spaceHeld = true
        voiceBox.hold(nil)
    end
end

function s.update(dt)
    if st().spaceHeld and not love.keyboard.isDown('space') then
        st().spaceHeld = false
        voiceBox.release()
    end
    if st().padHeld and not love.mouse.isDown(1) then
        st().padHeld = false
        voiceBox.release()
    end
    voiceBox.update(dt, mipo())
end

-- the vowel chart: front on the left, open at the bottom; drag to move between the vowels
local wasDown = false
local function drawChart(x, y, w, h)
    local v = voiceBox.settings()
    love.graphics.setColor(0.13, 0.12, 0.11, 0.9)
    love.graphics.rectangle('fill', x, y, w, h, 8, 8)
    love.graphics.setColor(1, 1, 1, 0.12)
    for i = 1, 3 do
        love.graphics.line(x + w * i / 4, y + 4, x + w * i / 4, y + h - 4)
        love.graphics.line(x + 4, y + h * i / 4, x + w - 4, y + h * i / 4)
    end
    for _, vowel in ipairs(voiceBox.VOWELS) do
        local cx, cy = voiceBox.chartXY(vowel.f1, vowel.f2)
        love.graphics.setColor(1, 0.85, 0.6, 0.9)
        love.graphics.circle('fill', x + cx * w, y + cy * h, 4)
        love.graphics.print(vowel.name, x + cx * w + 6, y + cy * h - 9)
    end
    local px, py = voiceBox.chartXY(v.f1, v.f2)
    love.graphics.setColor(v.sounding and { 1, 0.4, 0.45, 1 } or { 0.6, 0.9, 1, 1 })
    love.graphics.circle('fill', x + px * w, y + py * h, v.sounding and 9 or 7)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.print('front', x + 6, y + h - 18)
    love.graphics.print('back', x + w - 36, y + h - 18)
    -- press and drag: hold the note, move the vowel
    local mx, my = ui.mouseX, ui.mouseY
    local down = love.mouse.isDown(1)
    local inside = mx >= x and mx <= x + w and my >= y and my <= y + h
    local c = st()
    if down and inside and not wasDown then
        c.padHeld = true
        voiceBox.setVowel(voiceBox.chartFormants((mx - x) / w, (my - y) / h))
        voiceBox.hold(c.padOnset and v.onset or nil)
    elseif down and c.padHeld then
        voiceBox.setVowel(voiceBox.chartFormants((mx - x) / w, (my - y) / h))
    end
    wasDown = down
end

local SLIDERS = {
    { 'pitch', 'pitch', 36, 84, 1 }, { 'size', 'size', 0, 1, 0.01 }, -- giant .. tiny
    { 'effort', 'effort', 0, 1, 0.01 }, { 'nasal', 'nasal', 0, 1, 0.01 }, -- soft .. pressed
    { 'buzz', 'buzz', 0, 1, 0.01 }, { 'jitter', 'jitter', 0, 1, 0.01 }, -- smooth .. buzzy
    { 'shimmer', 'shimmer', 0, 1, 0.01 }, { 'creak', 'creak', 0, 1, 0.01 },
    { 'vibDepth', 'vibrato', 0, 1, 0.01 }, { 'vibRate', 'vib. speed', 0, 1, 0.01 },
}
local PRESETS = { 'mipo', 'tiny', 'big', 'hum', 'plain' }

local PANEL = { w = 400, row = 28, pad = 8, chartH = 200 }
function s.drawUI()
    local c = st()
    if not c.showPanel then return end
    ui.startFrame()
    local v = voiceBox.settings()
    local sw, sh = ui.getDimensions()
    local consonantRows = math.ceil(#voiceBox.CONSONANTS / 6)
    local rows = 1 + #SLIDERS + consonantRows + 2
    local w, h = PANEL.w, PANEL.chartH + PANEL.row * rows + 50
    local x0, y0 = sw - w - 12, math.max(12, (sh - h) / 2)
    ui.panel(x0, y0, w, h, '•• voice box ••', function()
        local x = x0 + PANEL.pad
        local y = y0 + 28
        local inner = w - PANEL.pad * 2
        drawChart(x, y, inner, PANEL.chartH)
        y = y + PANEL.chartH + 8
        -- presets
        local bw = (inner - 4 * 4) / #PRESETS
        for i, name in ipairs(PRESETS) do
            if ui.button(x + (i - 1) * (bw + 4), y, bw, name, PANEL.row - 4) then voiceBox.preset(name) end
        end
        y = y + PANEL.row
        for _, sl in ipairs(SLIDERS) do
            ui.label(x, y + 4, sl[2])
            local value = ui.sliderWithInput('voicebox-' .. sl[1], x + 110, y - 6, inner - 200, sl[3], sl[4],
                v[sl[1]], nil, sl[5])
            if value then
                v[sl[1]] = value + 0
                voiceBox.refresh()
            end
            y = y + PANEL.row
        end
        -- consonants: say it with the current vowel; the last one pressed also opens the chart's notes
        local cw = (inner - 5 * 4) / 6
        for i, name in ipairs(voiceBox.CONSONANTS) do
            local col, row = (i - 1) % 6, math.floor((i - 1) / 6)
            local label = (c.padOnset and v.onset == name) and ('[' .. name .. ']') or name
            if ui.button(x + col * (cw + 4), y + row * PANEL.row, cw, label, PANEL.row - 4) then
                v.onset = name
                voiceBox.say(name)
            end
        end
        y = y + consonantRows * PANEL.row
        if ui.button(x, y, 120, 'babble (b)', PANEL.row - 4) then voiceBox.babble() end
        local oc, ov = ui.checkbox(x + 130, y, c.padOnset, 'chart: consonant first')
        if oc then c.padOnset = ov end
    end)
    s.drawTakePanel()
end

-- the recorded take (VB3): the voice lab's set and take, its sliders, played four ways on one note
local SETS = { 'theo', 'herman', 'nikki', 'puppetmaker' }
local TAKE_SLIDERS = { { 'speed', 'speed', -24, 24, 1 }, { 'shift', 'shift', -24, 24, 1 },
    { 'size', 'size', -12, 12, 1 }, { 'inflection', 'inflection', 0, 1, 0.05 } }
local TAKE = { w = 300, row = 28, pad = 8 }
function s.drawTakePanel()
    local voiceLab = voiceBox.lab
    local L = state.voiceLab
    local v = voiceBox.settings()
    local _, sh = ui.getDimensions()
    local rows = 4 + #TAKE_SLIDERS + 4
    local w, h = TAKE.w, TAKE.row * rows + 36
    local x0, y0 = 12, math.max(12, (sh - h) / 2)
    ui.panel(x0, y0, w, h, '•• recorded take ••', function()
        local x, y = x0 + TAKE.pad, y0 + 28
        local inner = w - TAKE.pad * 2
        local bw = (inner - 3 * 4) / 4
        for i, name in ipairs(SETS) do
            local short = name == 'puppetmaker' and 'pm' or name
            local label = L.set == name and ('[' .. short .. ']') or short
            if ui.button(x + (i - 1) * (bw + 4), y, bw, label, TAKE.row - 4) then L.set, L.index = name, 1 end
        end
        y = y + TAKE.row
        if ui.button(x, y, 30, '<', TAKE.row - 4) then voiceLab.step(-1) end
        if ui.button(x + inner - 30, y, 30, '>', TAKE.row - 4) then voiceLab.step(1) end
        local measured = voiceBox.takeMidi()
        ui.label(x + 40, y + 4, (voiceLab.takeName() or '-') ..
            (measured and string.format('  sung at %.1f', measured) or '  not measured'))
        y = y + TAKE.row
        local pc, pv = ui.checkbox(x, y, v.takeAtPitch ~= false, 'at the voice box pitch (' .. v.pitch .. ')')
        if pc then v.takeAtPitch = pv end
        y = y + TAKE.row
        local labels = { 'bare', 'synth', 'sing', 'made' }
        for i, how in ipairs(labels) do
            if ui.button(x + (i - 1) * (bw + 4), y, bw, how, TAKE.row - 4) then voiceBox.playTake(how) end
        end
        y = y + TAKE.row
        for _, sl in ipairs(TAKE_SLIDERS) do
            ui.label(x, y + 4, sl[2])
            local value = ui.sliderWithInput('voicebox-take-' .. sl[1], x + 85, y - 6, inner - 170, sl[3], sl[4],
                L[sl[1]], nil, sl[5])
            if value then L[sl[1]] = value + 0 end
            y = y + TAKE.row
        end
        ui.label(x, y + 4, 'bare: sped up to the pitch (the choir)')
        ui.label(x, y + 4 + TAKE.row, 'synth: shifted, size  sing: the synth sings it')
        ui.label(x, y + 4 + TAKE.row * 2, 'made: the same syllable, no recording')
        y = y + TAKE.row * 3.2
        ui.label(x, y, 'drag the chart  space hold  b babble  h panels')
    end)
end

return s

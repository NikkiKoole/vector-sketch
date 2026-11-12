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
    voiceBox.preloadVoices() -- the people's syllables: the engine's analysis freezes ~3 s, here at the start
    mipoEmotion.settings().play = false -- the feeling row's face only, no reactions to play (the 'feelings' system)
    ensureGround()
    ensureMipo()
end

function s.onSceneUnload() voiceBox.release() end

function s.onKeyPress(key)
    local c = st()
    if ui.focusedTextInputID then -- typing a line: the keys are the field's, return says it
        if key == 'return' or key == 'kpenter' then
            ui.focusedTextInputID = nil
            voiceBox.speak(voiceBox.settings().text or '')
        else
            ui.handleKeyPress(key)
        end
        return
    end
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

-- the vowel chart: front on the left, open at the bottom; drag to move between the vowels (the
-- shared pad, src/ui/pad.lua, came out of this chart)
local function drawChart(x, y, w, h)
    local v = voiceBox.settings()
    local spots = {}
    for _, vowel in ipairs(voiceBox.VOWELS) do
        local cu, cv = voiceBox.chartXY(vowel.f1, vowel.f2)
        spots[#spots + 1] = { u = cu, v = cv, label = vowel.name }
    end
    local pu, pv = voiceBox.chartXY(v.f1, v.f2)
    local changed, u, vv = pad.draw('vowels', x, y, w, h,
        { value = { pu, pv }, spots = spots, corners = { bl = 'front', br = 'back' }, lit = v.sounding })
    if changed then
        -- press and drag: hold the note, move the vowel
        voiceBox.setVowel(voiceBox.chartFormants(u, vv))
        local c = st()
        if pad.pressed('vowels') then
            c.padHeld = true
            -- a looping take: the chart only steers its vowel filter
            if not v.takeLoop then voiceBox.hold(c.padOnset and v.onset or nil) end
        end
    end
end

local SLIDERS = {
    { 'pitch', 'pitch', 36, 84, 1 }, { 'size', 'size', 0, 1, 0.01 }, -- giant .. tiny
    { 'effort', 'effort', 0, 1, 0.01 }, { 'nasal', 'nasal', 0, 1, 0.01 }, -- soft .. pressed
    { 'buzz', 'buzz', 0, 1, 0.01 }, { 'jitter', 'jitter', 0, 1, 0.01 }, -- smooth .. buzzy
    { 'shimmer', 'shimmer', 0, 1, 0.01 }, { 'creak', 'creak', 0, 1, 0.01 },
    { 'vibDepth', 'vibrato', 0, 1, 0.01 }, { 'vibRate', 'vib. speed', 0, 1, 0.01 },
}
local PRESETS = { 'mipo', 'tiny', 'big', 'hum', 'plain' }

-- the listen view (Nikki 2026-11-11: "the amount of ui in the scene is extreme ... i want a focused thing for
-- listening to the recent changes"): who says it, the feelings, babble / again, cute and ask, a few grunts.
-- 'again' says the same line once more: switch the voice or cute and hear the difference. The rest ('all
-- controls'): the chart, sliders, consonants, codas, the take panel.
local FEELINGS = { 'neutral', 'happy', 'sad', 'angry', 'scared', 'surprised', 'sleepy', 'shy' }
local LISTEN_GRUNTS = { 'humup', 'humdown', 'huh', 'tsk', 'blah', 'giggle', 'sigh', 'yay' }
local function setFeeling(name)
    voiceBox.settings().feeling = name ~= 'neutral' and name or nil
    local m = mipo()
    if m then mipoEmotion.set(m, name) end
end
local LISTEN = { w = 440, row = 34, pad = 10 }
local function drawListen()
    local c = st()
    local v = voiceBox.settings()
    local sw, sh = ui.getDimensions()
    local w, h = LISTEN.w, LISTEN.row * 8 + 44
    local x0, y0 = sw - w - 16, sh - h - 16
    ui.panel(x0, y0, w, h, '•• listen ••', function()
        local x, y = x0 + LISTEN.pad, y0 + 32
        local inner = w - LISTEN.pad * 2
        local bh = LISTEN.row - 6
        -- who says it
        local voices = { 'made', 'theo', 'nikki', 'herman' }
        local vw = (inner - 3 * 4) / 4
        for i, name in ipairs(voices) do
            local on = (v.takeVoice or 'made') == name
            if ui.button(x + (i - 1) * (vw + 4), y, vw, on and ('[' .. name .. ']') or name, bh) then
                voiceBox.useVoice(name ~= 'made' and name or nil)
                if v.text then voiceBox.speak(v.text) else voiceBox.babble() end
            end
        end
        y = y + LISTEN.row
        -- how it feels: the face, and a new line
        local fw = (inner - 3 * 4) / 4
        for i, name in ipairs(FEELINGS) do
            local on = (v.feeling or 'neutral') == name
            local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
            if ui.button(x + col * (fw + 4), y + row * LISTEN.row, fw, on and ('[' .. name .. ']') or name, bh) then
                setFeeling(name)
                voiceBox.babble()
            end
        end
        y = y + LISTEN.row * 2
        if ui.button(x, y, 110, 'new line (b)', bh) then voiceBox.babble() end
        if ui.button(x + 116, y, 80, 'again', bh) then
            if v.text then voiceBox.speak(v.text) else voiceBox.babble() end
        end
        local kc, kv = ui.checkbox(x + 210, y + 2, v.cute, 'cute')
        if kc then v.cute = kv end
        local ac, av = ui.checkbox(x + 290, y + 2, v.ask, 'ask?')
        if ac then v.ask = av end
        y = y + LISTEN.row
        -- the line it said (without the speaker block)
        local said = (v.text or '-'):gsub('^%s*%b{}%s*', '')
        ui.label(x, y + 6, said)
        y = y + LISTEN.row
        local gw = (inner - 3 * 4) / 4
        local GRUNT_LABEL = { humup = 'hum up', humdown = 'hum down' }
        for i, name in ipairs(LISTEN_GRUNTS) do
            local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
            if ui.button(x + col * (gw + 4), y + row * LISTEN.row, gw, GRUNT_LABEL[name] or name, bh) then
                voiceBox.grunt(name)
            end
        end
        y = y + LISTEN.row * 2
        if ui.button(x, y, 130, 'all controls', bh) then c.mode = 'all' end
        ui.label(x + 140, y + 6, 'b new line   h hide')
    end)
end

local PANEL = { w = 400, row = 26, pad = 8, chartH = 120 }
function s.drawUI()
    local c = st()
    if not c.showPanel then return end
    ui.startFrame()
    if c.mode ~= 'all' then drawListen() return end
    if ui.button(ui.getDimensions() / 2 - 70, 12, 140, 'back to listen', 26) then c.mode = nil end
    local v = voiceBox.settings()
    local sw, sh = ui.getDimensions()
    local consonantRows = math.ceil(#voiceBox.CONSONANTS / 6)
    local rows = 1 + #SLIDERS + consonantRows + 7
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
                voiceBox.say(name, v.coda)
            end
        end
        y = y + consonantRows * PANEL.row
        -- codas (VB4): what a said syllable closes on; then two whole words
        local codas = { false }
        for _, name in ipairs(voiceBox.CODAS) do codas[#codas + 1] = name end
        local kw = (inner - (#codas - 1) * 3) / #codas
        for i, name in ipairs(codas) do
            local label = name or '-'
            if (v.coda or false) == name then label = name and label:upper() or '=' end -- picked: capitals
            if ui.button(x + (i - 1) * (kw + 3), y, kw, label, PANEL.row - 4) then
                v.coda = name or nil
                voiceBox.say(v.onset, v.coda)
            end
        end
        y = y + PANEL.row
        local ww = (inner - 3 * 4) / 4
        for i, word in ipairs({ { 'm', 'i', 'p' }, { 'p', 'o', 'm' }, { 'm', 'i', 'n' }, { 'p', 'o', 'ng' } }) do
            if ui.button(x + (i - 1) * (ww + 4), y, ww, word[1] .. word[2] .. word[3], PANEL.row - 4) then
                voiceBox.word(word[1], word[2], word[3])
            end
        end
        y = y + PANEL.row
        -- feelings (VB4): the face, what it says in Mipomi, its voice and the consonant it ends on
        local feelings = { 'neutral', 'happy', 'sad', 'angry', 'scared', 'surprised', 'sleepy', 'shy' }
        local fw = (inner - 7 * 3) / 8
        for i, name in ipairs(feelings) do
            if ui.button(x + (i - 1) * (fw + 3), y, fw, name:sub(1, 4), PANEL.row - 4) then
                v.feeling = name ~= 'neutral' and name or nil
                local m = mipo()
                if m then mipoEmotion.set(m, name) end
                voiceBox.babble()
            end
        end
        y = y + PANEL.row
        -- the line it says, in the talking heads' notation: edit it and say it again (return or 'say')
        local text = ui.textinput('voicebox-line', x, y, inner - 54, PANEL.row - 4, nil, v.text or '')
        if text then v.text = text end
        if ui.button(x + inner - 50, y, 50, 'say', PANEL.row - 4) then voiceBox.speak(v.text or '') end
        y = y + PANEL.row
        -- the speaker: the talking heads' personalities (- none), on the babble
        local speakers = { false }
        for _, name in ipairs(voiceBox.PERSONALITY_NAMES) do speakers[#speakers + 1] = name end
        local pw = (inner - (#speakers - 1) * 3) / #speakers
        for i, name in ipairs(speakers) do
            if ui.button(x + (i - 1) * (pw + 3), y, pw, name and name:sub(1, 4) or '-', PANEL.row - 4) then
                v.personality = name or nil
                voiceBox.babble()
            end
        end
        y = y + PANEL.row
        if ui.button(x, y, 64, 'babble', PANEL.row - 4) then voiceBox.babble() end
        local ac, av = ui.checkbox(x + 70, y, v.ask, 'ask?')
        if ac then v.ask = av end
        local sc, sv = ui.checkbox(x + 132, y, v.soft, 'soft')
        if sc then v.soft = sv end
        local kc, kv = ui.checkbox(x + 194, y, v.cute, 'cute')
        if kc then v.cute = kv end
        local oc, ov = ui.checkbox(x + 256, y, c.padOnset, 'cons. first')
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
    local rows = 5 + #TAKE_SLIDERS + 12
    local w, h = TAKE.w, TAKE.row * rows + 36
    local x0, y0 = 12, math.max(12, (sh - h) / 2)
    ui.panel(x0, y0, w, h, '•• recorded take ••', function()
        local x, y = x0 + TAKE.pad, y0 + 28
        local inner = w - TAKE.pad * 2
        local bw = (inner - 3 * 4) / 4
        -- who the voice box speaks with: the made voice or a person's recorded syllables
        ui.label(x, y + 4, 'says it as:')
        local vw = (inner - 80 - 3 * 3) / 4
        for i, name in ipairs({ 'made', 'theo', 'nikki', 'herman' }) do
            local on = (v.takeVoice or 'made') == name
            if ui.button(x + 80 + (i - 1) * (vw + 3), y, vw, on and ('[' .. name .. ']') or name, TAKE.row - 4) then
                voiceBox.useVoice(name ~= 'made' and name or nil)
                voiceBox.babble()
            end
        end
        y = y + TAKE.row
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
        ui.label(x, y + 4, 'vowel filter')
        local fv = ui.sliderWithInput('voicebox-take-filter', x + 85, y - 6, inner - 170, 0, 1, v.takeFilter or 0,
            nil, 0.05)
        if fv then v.takeFilter = fv + 0 end
        y = y + TAKE.row
        local lc, lv = ui.checkbox(x, y, v.takeLoop, 'loop it (then the chart steers the filter)')
        if lc then
            v.takeLoop = lv
            if not lv then v.loopAt = nil end
        end
        y = y + TAKE.row
        ui.label(x, y + 4, 'bare: sped up to the pitch (the choir);')
        ui.label(x, y + 4 + TAKE.row, '  the vowel filter: bare only')
        ui.label(x, y + 4 + TAKE.row * 2, 'synth: shifted, size  sing: the synth sings it')
        ui.label(x, y + 4 + TAKE.row * 3, 'made: the same syllable, no recording')
        y = y + TAKE.row * 4.2
        -- grunts (VB7): made on the voice box's voice, not played; (name) in the line says one too
        ui.label(x, y + 4, v.takeVoice and 'grunts (hums, huhs, tsks, blahs recorded):' or
            'grunts, made on the voice box voice:')
        y = y + TAKE.row
        local gw = (inner - 3 * 3) / 4
        for i, name in ipairs(voiceBox.GRUNT_NAMES) do
            local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
            if ui.button(x + col * (gw + 3), y + row * TAKE.row, gw, name, TAKE.row - 4) then voiceBox.grunt(name) end
        end
        y = y + math.ceil(#voiceBox.GRUNT_NAMES / 4) * TAKE.row
        ui.label(x, y + 4, 'space hold  b babble  h panels')
    end)
end

return s

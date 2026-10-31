-- world-settings.lua — the settings panel, opened from the tool rail's settings
-- button. Folding sections: world (src/world-params.lua), camera (src/camera-params.lua), backdrops (the
-- list + the selected one's params; while open, dragging moves the selected
-- backdrop, main.lua), music (src/music-params.lua) and the voice lab (src/voice-lab-params.lua).
local lib = {}

local ui = require('src.ui.all')
local state = require('src.state')
local inspector = require('src.ui.inspector')
local worldParams = require('src.world-params')
local musicParams = require('src.music-params')
local cameraParams = require('src.camera-params')
local roomMusicParams = require('src.room-music-params')
local voiceLabParams = require('src.voice-lab-params')
local hairBounce = require('src.hair-bounce')

local PANEL_WIDTH = ui.theme.panelWidth
local START_X, START_Y = 102, 60 -- right of the tool rail

local usedHeight = 300 -- last frame's content height; the panel grows/shrinks with the folds

-- Which sections are open; backdrops is state.panelVisibility.bgSettingsOpened.
local function folds()
    state.settingsFolds = state.settingsFolds or { world = true, music = false }
    return state.settingsFolds
end

local function sectionHeader(x, y, w, label, open)
    local clicked = ui.header_button(x, y, w, (open and ' ÷  ' or ' •  ') .. label, open)
    return clicked, y + ui.theme.button.height + ui.theme.spacing
end

-- The backdrop list ('x' deletes), then the selected one's params. Returns the y below.
local function drawBackdrops(x, y, w)
    local rowH = ui.theme.button.height
    local gap = ui.theme.spacing
    local toDelete, selected
    if #state.backdrops == 0 then
        ui.label(x, y, '(none yet: drop an image)')
        y = y + rowH + gap
    end
    for i = 1, #state.backdrops do
        local backdrop = state.backdrops[i]
        local fill = backdrop.selected and ui.theme.header.active or nil
        if ui.button(x, y, w - 50 - gap, backdrop.url, nil, fill) then
            if not backdrop.selected then
                for j = 1, #state.backdrops do state.backdrops[j].selected = false end
            end
            backdrop.selected = not backdrop.selected
        end
        if ui.button(x + w - 50, y, 50, 'x') then toDelete = i end
        if backdrop.selected then selected = backdrop end
        y = y + rowH + gap
    end
    if toDelete then table.remove(state.backdrops, toDelete) end
    if selected then
        y = y + inspector.drawParams('backdrop', worldParams.backdropRows, selected, nil, x, y, w)
    end
    return y
end

function lib.drawWorldSettingsUI()
    local _, h = ui.getDimensions()
    local panelHeight = math.min(usedHeight + ui.theme.panelHeader + 20, h - START_Y - 20)
    worldParams.tick(state.world)
    ui.panel(START_X, START_Y, PANEL_WIDTH, panelHeight, '• settings •', function()
        local header = ui.theme.panelHeader
        ui.scrollPanel('world-panel', START_X, START_Y + header, PANEL_WIDTH, panelHeight - header - 5, function()
            local x, w = START_X + 10, PANEL_WIDTH - 30 -- room for the scrollbar
            local top = START_Y + header + 10
            local y = top
            local f = folds()
            local clicked

            clicked, y = sectionHeader(x, y, w, 'world', f.world)
            if clicked then f.world = not f.world end
            if f.world then
                y = y + inspector.drawParams('world', worldParams.rows, state.world, nil, x, y, w)
            end

            -- the scene's camera while playing (src/camera-follow.lua)
            clicked, y = sectionHeader(x, y, w, 'camera', f.camera)
            if clicked then f.camera = not f.camera end
            if f.camera then
                y = y + inspector.drawParams('camera', cameraParams.rows, cameraParams.target(), nil, x, y, w)
            end

            local pv = state.panelVisibility
            clicked, y = sectionHeader(x, y, w, 'backdrops', pv.bgSettingsOpened)
            if clicked then pv.bgSettingsOpened = not pv.bgSettingsOpened end
            if pv.bgSettingsOpened then y = drawBackdrops(x, y, w) end

            -- what this room's music turns into when you enter it (src/room-music.lua)
            clicked, y = sectionHeader(x, y, w, 'room music', f.roomMusic)
            if clicked then f.roomMusic = not f.roomMusic end
            if f.roomMusic then
                y = y + inspector.drawParams('roommusic', roomMusicParams.rows, roomMusicParams.target(), nil, x, y, w)
            end

            clicked, y = sectionHeader(x, y, w, 'music', f.music)
            if clicked then f.music = not f.music end
            if f.music then
                y = y + inspector.drawParams('music', musicParams.rows, musicParams.target(), nil, x, y, w)
            end

            -- haircuts that bounce and sag (src/hair-bounce.lua)
            clicked, y = sectionHeader(x, y, w, 'hair bounce', f.hairBounce)
            if clicked then f.hairBounce = not f.hairBounce end
            if f.hairBounce then
                y = y + inspector.drawParams('hairbounce', hairBounce.rows, hairBounce.settings, nil, x, y, w)
            end

            -- a test bench for Mipo voices on the synth (src/voice-lab.lua)
            clicked, y = sectionHeader(x, y, w, 'voice lab', f.voiceLab)
            if clicked then f.voiceLab = not f.voiceLab end
            if f.voiceLab then
                y = y + inspector.drawParams('voicelab', voiceLabParams.rows, voiceLabParams.target(), nil, x, y, w)
            end

            usedHeight = y - top
        end)
    end)
end

return lib

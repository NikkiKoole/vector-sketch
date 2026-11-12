-- The "scenes" tab of the right column: every scene in scripts/ (src/scene-catalog.lua), grouped,
-- two to a row as pictures (scripts/thumbs/, made by `./playtime.sh thumbs`, src/scene-thumbs.lua).
-- Pick one to see what it is, then 'load' or 'load + play'; a script without a scene of its own
-- (tufts) runs on the scene that's open. Loading replaces what's on the stage.
-- The search box on top finds scenes by name and description as you type (src/fuzzy-find.lua),
-- best first, groups set aside; enter loads the best one.
local utf8 = require('utf8')
local lib = {}

local ui = require('src.ui.all')
local state = require('src.state')
local catalog = require('src.scene-catalog')
local thumbs = require('src.scene-thumbs')
local fuzzy = require('src.fuzzy-find')

local DIM = { 0.75, 0.72, 0.66, 1 }
local COLUMNS = 2
local CARD = { 0, 0, 0, 0.25 } -- a tile's fill, neither hovered nor picked
local THUMB_ASPECT = 0.8 -- the pictures' height / width (the 1000x800 window, src/scene-thumbs.lua)

-- the list, read again when the tab opens (a new scene shows up without a restart)
local scenes = nil
local wasOpen = false

local function groupsOpen()
    state.rightColumn.sceneGroups = state.rightColumn.sceneGroups
        or { rooms = true, spikes = true, tests = false, tech = false }
    return state.rightColumn.sceneGroups
end

-- `text` cut to fit `width` in the UI font, with an ellipsis. Cut a character at a time, not a byte: a
-- byte off a '—' left half a character and the font threw (UTF-8 decoding error, 2026-11-12)
local function fit(text, width)
    if ui.font:getWidth(text) <= width then return text end
    while #text > 1 and ui.font:getWidth(text .. '…') > width do
        local last = utf8.offset(text, -1) -- where the last character starts
        if not last or last <= 1 then break end
        text = text:sub(1, last - 1)
    end
    return text .. '…'
end

-- called every frame the right column draws; true while this tab is the one shown
function lib.tick(open)
    if open and not wasOpen then
        scenes = nil
        thumbs.forget() -- new pictures show up too
    end
    wasOpen = open
end

-- one scene's tile: its picture (src/scene-thumbs.lua) with the name under it; true when clicked
local function tile(scene, x, y, w, imgH, picked)
    local h = imgH + ui.fontHeight + 10
    -- a plain card (ui.button's rounding is round blobs at this size), clicked as a button is
    local id = ui.generateID()
    local hover = ui.mouseX >= x and ui.mouseX <= x + w and ui.mouseY >= y and ui.mouseY <= y + h
    if hover and ui.mousePressed then ui.activeElementID = id end
    local released = ui.mouseReleased and ui.activeElementID == id
    local clicked = released and hover
    if released then ui.activeElementID = nil end
    love.graphics.setColor(picked and ui.theme.header.active or (hover and ui.theme.button.hover)
        or CARD)
    love.graphics.rectangle('fill', x, y, w, h, 6, 6)
    ui.setCursor(x, y, w, h)
    local img = thumbs.image(scene.id)
    if img then
        local s = math.min((w - 8) / img:getWidth(), imgH / img:getHeight())
        local iw, ih = img:getWidth() * s, img:getHeight() * s
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, x + (w - iw) / 2, y + 4 + (imgH - ih) / 2, 0, s, s)
    else
        love.graphics.setColor(0, 0, 0, 0.15)
        love.graphics.rectangle('fill', x + 4, y + 4, w - 8, imgH - 4)
        local text = scene.blank and 'start fresh' or scene.scriptOnly and 'script only' or 'no picture'
        ui.label(x + 10, y + imgH / 2 - ui.fontHeight / 2, fit(text, w - 20), DIM)
    end
    love.graphics.setColor(1, 1, 1, 1)
    ui.label(x + 6, y + imgH + 6, fit(scene.name, w - 12), (hover and not picked) and ui.theme.button.text_hover or nil)
    return clicked, h
end

-- a scene's texts for the search: its name counts double its description, then its group
local function searchFields(scene)
    return { scene.name, scene.note or '', scene.group or '' }, { 2, 1, 0.5 }
end

-- tiles for `list`, COLUMNS to a row, a picked one's row under it; the y after them
local function grid(list, rowX, rowY, rowW, rowH, gap, tileW, imgH)
    local picked = state.rightColumn.pickedScene
    for first = 1, #list, COLUMNS do
        local tallest, pickedHere = 0, nil
        for c = 0, COLUMNS - 1 do
            local scene = list[first + c]
            if scene then
                local clicked, th = tile(scene, rowX + c * (tileW + gap), rowY, tileW, imgH, picked == scene.id)
                if clicked then
                    state.rightColumn.pickedScene = (picked ~= scene.id) and scene.id or nil
                    picked = state.rightColumn.pickedScene
                end
                if picked == scene.id then pickedHere = scene end
                tallest = math.max(tallest, th)
            end
        end
        rowY = rowY + tallest + gap
        if pickedHere then rowY = lib.pickedRow(pickedHere, rowX, rowY, rowW, rowH, gap) end
    end
    return rowY
end

-- under a picked tile's row: what it is, and load / load + play
function lib.pickedRow(scene, x, y, w, rowH, gap)
    if scene.note ~= '' then
        ui.label(x + 4, y, fit(scene.note, w - 8), DIM)
        y = y + ui.fontHeight + 2
    end
    if scene.scriptOnly then
        ui.label(x + 4, y, fit('a script: runs on the scene that is open', w - 8), DIM)
        y = y + ui.fontHeight + 2
    end
    local bw = math.floor((w - gap) / 2)
    if ui.button(x, y, bw, scene.scriptOnly and 'run on this scene' or 'load') then
        catalog.request(scene, false)
        state.rightColumn.pickedScene = nil
    end
    if ui.button(x + bw + gap, y, bw, scene.scriptOnly and 'run + play' or 'load + play') then
        catalog.request(scene, true)
        state.rightColumn.pickedScene = nil
    end
    y = y + rowH + 2
    if not scene.scriptOnly then
        ui.label(x + 4, y, fit('replaces what is on the stage now', w - 8), DIM)
        y = y + ui.fontHeight + 2
    end
    return y + gap
end

function lib.draw(x, y, w, h)
    scenes = scenes or catalog.list()
    local rowH = ui.theme.button.height
    local gap = ui.theme.spacing
    local open = groupsOpen()
    ui.panel(x, y, w, h, 'scenes', function()
        -- the search box, above the list (it stays put while the list scrolls)
        local searchY = y + ui.theme.panelHeader + gap
        local text = ui.textinput('scene-search', x + 10, searchY, w - 20, rowH, 'search...',
            state.rightColumn.sceneSearch or '')
        if text then
            local entered = text:find('\n', 1, true) ~= nil -- enter types a newline: load the best one
            text = text:gsub('\n', '')
            if text ~= (state.rightColumn.sceneSearch or '') and ui._scrollers['scenes-panel'] then
                ui._scrollers['scenes-panel'].value = 0 -- a new search: its best at the top
            end
            state.rightColumn.sceneSearch = text
            if entered then
                ui.focusedTextInputID = nil
                local best = fuzzy.rank(text, scenes, searchFields)[1]
                if best then
                    catalog.request(best, false)
                    state.rightColumn.pickedScene = nil
                end
            end
        end
        local query = state.rightColumn.sceneSearch or ''
        local top = searchY + rowH + gap
        ui.scrollPanel('scenes-panel', x, top, w, h - (top - y) - 5, function()
            local rowX, rowY, rowW = x + 10, top + gap, w - 26 -- room for the scroll bar
            ui.label(rowX, rowY, fit('now: ' .. tostring(state.scene.id or '?'), rowW), DIM)
            rowY = rowY + ui.fontHeight + gap * 2
            local tileW = math.floor((rowW - gap * (COLUMNS - 1)) / COLUMNS)
            local imgH = math.floor((tileW - 8) * THUMB_ASPECT)
            if query:match('%S') then
                -- searching: the matches, best first, groups set aside
                local found = fuzzy.rank(query, scenes, searchFields)
                local note = #found == 0 and 'nothing found'
                    or (#found .. (#found == 1 and ' scene' or ' scenes') .. ', enter loads the first')
                ui.label(rowX, rowY, fit(note, rowW), DIM)
                rowY = rowY + ui.fontHeight + gap
                grid(found, rowX, rowY, rowW, rowH, gap, tileW, imgH)
                return
            end
            -- the scenes of each group
            local groups, order = {}, {}
            for _, scene in ipairs(scenes) do
                if not groups[scene.group] then
                    groups[scene.group] = {}
                    order[#order + 1] = scene.group
                end
                table.insert(groups[scene.group], scene)
            end
            for _, group in ipairs(order) do
                local note = catalog.folderNote(group)
                if ui.header_button(rowX, rowY, rowW, ' ' .. group .. (note and ('  ' .. note) or ''), open[group]) then
                    open[group] = not open[group]
                end
                rowY = rowY + rowH + gap
                if open[group] then rowY = grid(groups[group], rowX, rowY, rowW, rowH, gap, tileW, imgH) end
            end
        end)
    end)
end

return lib

-- music-arrange.lua — the arrangement grid in the music panel (BESPOKE-UI.md BU9): a row per part, a column
-- per stretch of the song; click a cell to turn that part off or on there. The column you hear is lit and
-- fills as its bars go by; a part's name gets a dot while it sounds. Drawn above the music rows in the
-- settings panel (src/ui/world-settings.lua). Two kinds of column:
--
--   passes  the loop styles (earth): one fixed loop played over and over, so a column is a pass of it (the
--           same in every song). Rows: the style's own roles; the solo row goes rest -> A (call) -> B
--           (answer). A bpm slider (from the next bar line). The style's module reads it per bar.
--   kinds   every other style: its songs are rolled fresh (intro, A, B, break, outro ...), so a column is a
--           kind of section ("no drums in any break"), which holds across songs. Rows: the parts the style
--           plays. Takes notes away only: a part the song doesn't write there stays silent. Read in
--           music-parts.lua's voiceOf.
--
-- Nikki 2026-11-12, with the earth session: "an arrangement grid for earth (a BPM slider + passes x parts
-- toggles)"; then "how does this translate to all our other songs". Kept in state.musicSettings.arrange[style]:
--   passes: { bpm = n | nil, passes = { { keys = bool, bass = bool, kit = bool, solo = false|'A'|'B' }, ... } }
--           nil until the first click, then filled from the style's own (FORM's roles, SOLO_ROUNDS)
--   kinds:  { kinds = { [sectionKind] = { [part] = false } } }   only false is stored (off)
-- Saved by setups (music-setups.lua CHOICES).
local ui = require('src.ui.all')
local state = require('src.state')

local lib = {}

-- the loop styles, and their module (its FORM, SOLO_ROUNDS)
local LOOPS = { earth = 'src.music-earth' }
local PASSES = 10 -- a 40-bar song of a 4-bar loop
local BARS_PER_PASS = 4
local LOOP_PARTS = { -- role (the module's), the name shown, the part it sounds as (music.playing())
    { role = 'keys', label = 'vibes', heard = 'keys', colour = { 0.55, 0.75, 0.95 } },
    { role = 'bass', label = 'bass', heard = 'bass', colour = { 0.85, 0.6, 0.4 } },
    { role = 'kit', label = 'drums', heard = 'drums', colour = { 0.9, 0.8, 0.45 } },
    { role = 'solo', label = 'solo', heard = 'lead', colour = { 0.6, 0.9, 0.6 } },
}
local SOLO_NEXT = { [false] = 'A', A = 'B', B = false }
-- a colour per part (the kinds grid), the rest grey
local PART_COLOUR = {
    lead = { 0.6, 0.9, 0.6 }, answer = { 0.5, 0.8, 0.7 }, keys = { 0.55, 0.75, 0.95 }, chord = { 0.6, 0.65, 0.95 },
    guitar = { 0.9, 0.65, 0.55 }, horns = { 0.95, 0.75, 0.4 }, strings = { 0.8, 0.6, 0.85 }, riff = { 0.95, 0.6, 0.7 },
    bass = { 0.85, 0.6, 0.4 }, drums = { 0.9, 0.8, 0.45 }, perc = { 0.8, 0.85, 0.5 }, sample = { 0.95, 0.85, 0.8 },
    vinyl = { 0.7, 0.7, 0.7 },
}
-- section kinds in the order they come in a song; others after, as first met
local KIND_ORDER = { 'intro', 'A', 'verse', 'B', 'C', 'break', 'bridge', 'outro', 'end' }

local LABEL_W, HEAD_H, ROW_H, GAP = 58, 18, 22, 2
local smallFont -- the grid's words, smaller than the panel's (made on first draw)
local BG = { 0.13, 0.12, 0.11, 0.9 }
local COLUMN_LIT = { 1, 0.85, 0.6, 0.16 }
local FILL_LIT = { 1, 0.85, 0.6, 0.6 }
local OFF = { 1, 1, 1, 0.08 }
local WORD = { 1, 1, 1, 0.55 }
local WORD_LIT = { 1, 0.9, 0.7, 1 }

local function music() return require('src.music') end

local function styleNow()
    local now = music().nowPlaying()
    return now and now.style or music().style
end

local function settingsOf(name, create)
    local s = state.musicSettings
    local a = s.arrange and s.arrange[name]
    if not a and create then
        s.arrange = s.arrange or {}
        a = {}
        s.arrange[name] = a
    end
    return a
end

-- the bar being heard (not booked: booking runs ahead) and how far into it, or nil
local function heardBar(name)
    local M = state.music
    local song = M.song
    if not (music().enabled and song and song.style == name and M.audioTime and M.barStart and song.barLength
            and song.bar and song.bars) then
        return nil
    end
    local behind = math.max(0, math.ceil((M.barStart - M.audioTime) / song.barLength - 1e-6))
    local bar = (song.bar - behind - 1) % song.bars + 1
    local into = (M.audioTime - (M.barStart - behind * song.barLength)) / song.barLength
    return bar, math.max(0, math.min(1, into))
end

local function sounding(part)
    for _, entry in ipairs(music().playing()) do
        if entry.part == part then
            for _, patch in ipairs(entry.patches or {}) do
                if patch.now then return true end
            end
        end
    end
    return false
end

local function inside(x, y, w, h)
    return ui.mouseX >= x and ui.mouseX <= x + w and ui.mouseY >= y and ui.mouseY <= y + h
end

-- A grid: what it shows and what a click does. { columns = { label ... }, rows = { label, heard, colour },
-- value(row, col), click(row, col), clickRow(row), lit = col | nil, fill = 0..1, extra(x, y, w) -> height }

-- the loop styles: passes
local function loopDefaults(name)
    local mod = require(LOOPS[name])
    local roles = mod.FORM and mod.FORM[1] and mod.FORM[1][3] or {}
    local rounds = mod.SOLO_ROUNDS or {}
    local passes = {}
    for p = 1, PASSES do
        passes[p] = { keys = roles.keys == true, bass = roles.bass == true, kit = roles.kit == true,
                      solo = roles.solo and #rounds > 0 and rounds[(p - 1) % #rounds + 1] or false }
    end
    return passes
end

local function passesGrid(name)
    local a = settingsOf(name)
    local passes = a and a.passes or loopDefaults(name)
    local function own()
        local s = settingsOf(name, true)
        s.passes = s.passes or loopDefaults(name)
        return s.passes
    end
    local grid = { columns = {}, rows = LOOP_PARTS }
    for p = 1, PASSES do grid.columns[p] = tostring(p) end
    local bar, into = heardBar(name)
    if bar then
        grid.lit = math.floor((bar - 1) / BARS_PER_PASS) % PASSES + 1
        grid.fill = ((bar - 1) % BARS_PER_PASS + into) / BARS_PER_PASS
    end
    function grid.value(row, p) return passes[p][row.role] end
    function grid.click(row, p)
        local list = own()
        if row.role == 'solo' then
            list[p].solo = SOLO_NEXT[list[p].solo or false]
        else
            list[p][row.role] = not list[p][row.role]
        end
    end
    function grid.clickRow(row) -- the whole row off, or (all off already) back to the style's own
        local list, fresh, any = own(), loopDefaults(name), false
        for q = 1, PASSES do any = any or list[q][row.role] end
        for q = 1, PASSES do list[q][row.role] = not any and fresh[q][row.role] or false end
    end
    function grid.extra(x, y, w) -- the tempo: the style's own until moved; it changes from the next bar line
        local style = music().styles[name]
        local bpm = a and a.bpm or style and style.bpm or 90
        ui.alignedLabel(x, y + 3, 'bpm')
        local v = ui.sliderWithInput('arrange bpm ' .. name, x + LABEL_W, y, w - LABEL_W - 90, 50, 140, bpm, nil, 1)
        if v and v ~= bpm then settingsOf(name, true).bpm = v end
        return ui.theme.inspector.rowHeight
    end
    return grid
end

-- every other style: section kinds. The kinds and parts it has shown are remembered (on state, so a hot swap
-- keeps them): a song rolls only some of the style's kinds, and a part rests now and then
local function seen(name)
    state.musicArrangeSeen = state.musicArrangeSeen or {}
    local s = state.musicArrangeSeen[name] or { kinds = {}, order = {} }
    state.musicArrangeSeen[name] = s
    return s
end

local function kindsGrid(name)
    local song = state.music.song
    local memory = seen(name)
    if song and song.style == name then
        for _, section in ipairs(song.sections or {}) do
            if section.kind and not memory.kinds[section.kind] then
                memory.kinds[section.kind] = true
                memory.order[#memory.order + 1] = section.kind
            end
        end
    end
    local columns = {}
    for _, kind in ipairs(KIND_ORDER) do if memory.kinds[kind] then columns[#columns + 1] = kind end end
    for _, kind in ipairs(memory.order) do
        local known = false
        for _, k in ipairs(KIND_ORDER) do known = known or k == kind end
        if not known then columns[#columns + 1] = kind end
    end
    local styleParts = (state.music.styleParts or {})[name] or {}
    local rows = {}
    for _, part in ipairs(music().parts) do
        if styleParts[part] then
            local colour = PART_COLOUR[part] or { 0.7, 0.7, 0.7 }
            rows[#rows + 1] = { role = part, label = part, heard = part, colour = colour }
        end
    end
    if #columns == 0 or #rows == 0 then return nil end

    local a = settingsOf(name)
    local kinds = a and a.kinds or {}
    local grid = { columns = columns, rows = rows }
    local bar, into = heardBar(name)
    local section = bar and song.barSection and song.barSection[bar]
    if section then
        for i, kind in ipairs(columns) do if kind == section.kind then grid.lit = i end end
        local j = song.barIndex and song.barIndex[bar] or 0 -- the bar's place in its section, from 0
        grid.fill = (j + into) / math.max(1, section.bars or 1)
    end
    local function setOff(kind, part, off)
        local s = settingsOf(name, true)
        s.kinds = s.kinds or {}
        s.kinds[kind] = s.kinds[kind] or {}
        s.kinds[kind][part] = off and false or nil
        if next(s.kinds[kind]) == nil then s.kinds[kind] = nil end
    end
    function grid.value(row, c) return not (kinds[columns[c]] and kinds[columns[c]][row.role] == false) end
    function grid.click(row, c) setOff(columns[c], row.role, grid.value(row, c)) end
    function grid.clickRow(row) -- the whole row off, or (all off already) all back on
        local any = false
        for c = 1, #columns do any = any or grid.value(row, c) end
        for c = 1, #columns do setOff(columns[c], row.role, any) end
    end
    return grid
end

-- a cell: on (the part's colour, a word in it if the value is one), off (faint), hover outlined
local function drawCell(cx, cy, cw, value, colour)
    local hover = inside(cx, cy, cw, ROW_H)
    if value then
        love.graphics.setColor(colour[1], colour[2], colour[3], 0.85)
    else
        love.graphics.setColor(OFF)
    end
    love.graphics.rectangle('fill', cx + 1, cy + 1, cw - 2, ROW_H - 2, 4, 4)
    if type(value) == 'string' then
        local font = love.graphics.getFont()
        love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
        love.graphics.print(value, cx + cw / 2 - font:getWidth(value) / 2, cy + ROW_H / 2 - font:getHeight() / 2)
    end
    if hover then
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.rectangle('line', cx + 1, cy + 1, cw - 2, ROW_H - 2, 4, 4)
    end
    return hover and ui.mousePressed
end

local function drawGrid(name, grid, x, y, w)
    local font = love.graphics.getFont()
    local fh = font:getHeight()
    local n = #grid.columns
    local gx, cw = x + LABEL_W, (w - LABEL_W) / n
    local gridH = HEAD_H + #grid.rows * (ROW_H + GAP)

    love.graphics.setColor(BG)
    love.graphics.rectangle('fill', x, y, w, gridH + 4, 6, 6)
    if grid.lit then -- the column being heard: lit, a line under its name filling as its bars go by
        local cx = gx + (grid.lit - 1) * cw
        love.graphics.setColor(COLUMN_LIT)
        love.graphics.rectangle('fill', cx, y, cw, gridH + 4, 4, 4)
        love.graphics.setColor(FILL_LIT)
        love.graphics.rectangle('fill', cx + 2, y + HEAD_H - 3, (cw - 4) * math.min(1, grid.fill or 0), 2)
    end
    for c, label in ipairs(grid.columns) do
        love.graphics.setColor(c == grid.lit and WORD_LIT or WORD)
        love.graphics.print(label, gx + (c - 0.5) * cw - font:getWidth(label) / 2, y + 1)
    end

    local clicked, clickedRow
    for i, row in ipairs(grid.rows) do
        local ry = y + HEAD_H + (i - 1) * (ROW_H + GAP)
        local lit = grid.lit and sounding(row.heard)
        love.graphics.setColor(lit and WORD_LIT or WORD)
        love.graphics.print(row.label .. (lit and ' •' or ''), x + 6, ry + ROW_H / 2 - fh / 2)
        if inside(x, ry, LABEL_W, ROW_H) and ui.mousePressed then clickedRow = row end
        for c = 1, n do
            if drawCell(gx + (c - 1) * cw, ry, cw, grid.value(row, c), row.colour) then clicked = { row, c } end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    if clicked then grid.click(clicked[1], clicked[2]) end
    if clickedRow then grid.clickRow(clickedRow) end

    local cy = y + gridH + 4 + ui.theme.spacing
    if grid.extra then cy = cy + grid.extra(x, cy, w) end
    if settingsOf(name) then -- back to the style's own
        if ui.button(x, cy, w, LOOPS[name] and 'the record\'s arrangement' or 'as the songs write it') then
            state.musicSettings.arrange[name] = nil
        end
        cy = cy + ui.theme.button.height + ui.theme.spacing
    end
    return cy - y
end

local function gridOf(name)
    if LOOPS[name] then return passesGrid(name) end
    return kindsGrid(name)
end

-- Draws the grid at x, y in width w; returns the height used (0 when there's nothing to show yet).
function lib.draw(x, y, w)
    local name = styleNow()
    if not name or not music().enabled then return 0 end
    local font = love.graphics.getFont()
    smallFont = smallFont or love.graphics.newFont('assets/Arial Narrow.ttf', 15)
    love.graphics.setFont(smallFont)
    local ok, h = pcall(function()
        local grid = gridOf(name)
        return grid and drawGrid(name, grid, x, y, w) or 0
    end)
    love.graphics.setFont(font)
    if not ok then error(h, 0) end
    return h
end

return lib

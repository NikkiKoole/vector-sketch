-- music-arrange.lua — the arrangement grid for the loop styles (BESPOKE-UI.md BU9): a column per pass of
-- the loop, a row per part; click a cell to turn that part on or off in that pass (the solo row goes
-- rest -> A (the call) -> B (the answer)). The column you hear is lit and fills as its bars go by; a part's
-- name lights while it sounds. A bpm slider under it. Drawn above the music rows in the settings panel
-- (src/ui/world-settings.lua) while a style with a grid plays.
--
-- Nikki 2026-11-12, with the earth session: "an arrangement grid for earth (a BPM slider + passes x parts
-- toggles)". Kept in state.musicSettings.arrange[style] = { bpm = n | nil, passes = { { keys = bool,
-- bass = bool, kit = bool, solo = false | 'A' | 'B' }, ... } }; nil until the first click, then filled from
-- the style's own (FORM's roles, SOLO_ROUNDS). The style's module reads it as it books each bar.
local ui = require('src.ui.all')
local state = require('src.state')

local lib = {}

-- the styles with a grid, and their module (its FORM, SOLO_ROUNDS, and what it plays as)
local STYLES = { earth = 'src.music-earth' }
local PASSES = 10 -- a 40-bar song of a 4-bar loop
local BARS_PER_PASS = 4
local PARTS = { -- role (the module's), the name shown, the part it sounds as (music.playing())
    { role = 'keys', label = 'vibes', heard = 'keys', colour = { 0.55, 0.75, 0.95 } },
    { role = 'bass', label = 'bass', heard = 'bass', colour = { 0.85, 0.6, 0.4 } },
    { role = 'kit', label = 'drums', heard = 'drums', colour = { 0.9, 0.8, 0.45 } },
    { role = 'solo', label = 'solo', heard = 'lead', colour = { 0.6, 0.9, 0.6 } },
}
local SOLO_NEXT = { [false] = 'A', A = 'B', B = false }

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

function lib.visible() return STYLES[styleNow()] ~= nil end

-- the style's own arrangement: every part its FORM plays, every pass; the solo by SOLO_ROUNDS
local function defaults(name)
    local mod = require(STYLES[name])
    local roles = mod.FORM and mod.FORM[1] and mod.FORM[1][3] or {}
    local rounds = mod.SOLO_ROUNDS or {}
    local passes = {}
    for p = 1, PASSES do
        passes[p] = { keys = roles.keys == true, bass = roles.bass == true, kit = roles.kit == true,
                      solo = roles.solo and #rounds > 0 and rounds[(p - 1) % #rounds + 1] or false }
    end
    return passes
end

-- the saved arrangement; create: make it (from the defaults) if there is none
local function arrangement(name, create)
    local s = state.musicSettings
    local a = s.arrange and s.arrange[name]
    if not a and create then
        s.arrange = s.arrange or {}
        a = { passes = defaults(name) }
        s.arrange[name] = a
    end
    if a and not a.passes then a.passes = defaults(name) end
    return a
end

-- the pass and the bar in it being heard (not booked: booking runs ahead), or nil
local function heard(name)
    local M = state.music
    local song = M.song
    if not (music().enabled and song and song.style == name and M.audioTime and M.barStart and song.barLength
            and song.bar and song.bars) then
        return nil
    end
    local behind = math.max(0, math.ceil((M.barStart - M.audioTime) / song.barLength - 1e-6))
    local bar = (song.bar - behind - 1) % song.bars + 1
    local into = (M.audioTime - (M.barStart - behind * song.barLength)) / song.barLength
    return math.floor((bar - 1) / BARS_PER_PASS) % PASSES + 1, (bar - 1) % BARS_PER_PASS, math.max(0, math.min(1, into))
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

-- a cell: on (the part's colour, the solo's round written in it), off (faint), hover outlined
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

local function drawGrid(x, y, w)
    local name = styleNow()
    if not STYLES[name] then return 0 end
    local a = arrangement(name)
    local passes = a and a.passes or defaults(name)
    local pass, barIn, into = heard(name)
    local font = love.graphics.getFont()
    local fh = font:getHeight()
    local gx, cw = x + LABEL_W, (w - LABEL_W) / PASSES
    local gridH = HEAD_H + #PARTS * (ROW_H + GAP)

    love.graphics.setColor(BG)
    love.graphics.rectangle('fill', x, y, w, gridH + 4, 6, 6)
    -- the pass being heard: its column lit, a line under its number filling as its bars go by
    if pass then
        local cx = gx + (pass - 1) * cw
        love.graphics.setColor(COLUMN_LIT)
        love.graphics.rectangle('fill', cx, y, cw, gridH + 4, 4, 4)
        love.graphics.setColor(FILL_LIT)
        love.graphics.rectangle('fill', cx + 2, y + HEAD_H - 3, (cw - 4) * (barIn + into) / BARS_PER_PASS, 2)
    end
    for p = 1, PASSES do
        local label = tostring(p)
        love.graphics.setColor(p == pass and WORD_LIT or WORD)
        love.graphics.print(label, gx + (p - 0.5) * cw - font:getWidth(label) / 2, y + 1)
    end

    local clicked -- { pass, part } or { nil, part } for a row's name
    for i, part in ipairs(PARTS) do
        local ry = y + HEAD_H + (i - 1) * (ROW_H + GAP)
        local lit = pass and sounding(part.heard)
        love.graphics.setColor(lit and WORD_LIT or WORD)
        love.graphics.print(part.label .. (lit and ' •' or ''), x + 6, ry + ROW_H / 2 - fh / 2)
        if inside(x, ry, LABEL_W, ROW_H) and ui.mousePressed then clicked = { nil, part } end
        for p = 1, PASSES do
            if drawCell(gx + (p - 1) * cw, ry, cw, passes[p][part.role], part.colour) then clicked = { p, part } end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)

    if clicked then
        local own = arrangement(name, true).passes
        local p, role = clicked[1], clicked[2].role
        if p then -- a cell: on <-> off; the solo: rest -> A -> B -> rest
            if role == 'solo' then
                own[p].solo = SOLO_NEXT[own[p].solo or false]
            else
                own[p][role] = not own[p][role]
            end
        else -- a row's name: the whole row off, or (all off already) back to the style's own
            local any = false
            for q = 1, PASSES do any = any or own[q][role] end
            local fresh = defaults(name)
            for q = 1, PASSES do own[q][role] = not any and fresh[q][role] or false end
        end
    end

    local cy = y + gridH + 4 + ui.theme.spacing
    -- the tempo: the style's own until moved; it changes from the next bar line
    local style = music().styles[name]
    local bpm = a and a.bpm or style and style.bpm or 90
    ui.alignedLabel(x, cy + 3, 'bpm')
    local v = ui.sliderWithInput('arrange bpm ' .. name, x + LABEL_W, cy, w - LABEL_W - 90, 50, 140, bpm, nil, 1)
    if v and v ~= bpm then arrangement(name, true).bpm = v end
    cy = cy + ui.theme.inspector.rowHeight
    -- back to the style's own
    if a and ui.button(x, cy, w, 'the record\'s arrangement') then state.musicSettings.arrange[name] = nil end
    if a then cy = cy + ui.theme.button.height + ui.theme.spacing end
    return cy - y
end

-- Draws the grid at x, y in width w; returns the height used (0 when the playing style has no grid).
function lib.draw(x, y, w)
    if not STYLES[styleNow()] then return 0 end
    local font = love.graphics.getFont()
    smallFont = smallFont or love.graphics.newFont('assets/Arial Narrow.ttf', 15)
    love.graphics.setFont(smallFont)
    local ok, h = pcall(drawGrid, x, y, w)
    love.graphics.setFont(font)
    if not ok then error(h, 0) end
    return h
end

return lib

-- palette.lua — the editor's colour palette: a colour swatch in a panel (inspector, sfixture editor,
-- Mipo panels) opens it with lib.toggle(currentHex, onPick). One row per family of colours, light
-- to dark (src/color.lua paletteRows), the recent picks on top, the current colour ringed, the
-- hovered one's hex at the bottom. Picking keeps it open, to try a few; a press outside it, escape,
-- the 'x' or the swatch again closes it. Drawn last (playtime-ui's drawUI), and the widgets under it
-- see no pointer (ui.blockRect, like the material picker).
-- Open/closed stays on state.panelVisibility.showPalette (input-manager closes every panel by name)
-- and the pick on state.showPaletteFunc; the rest on state.palette, so a hot reload keeps it.
local ui = require('src.ui.all')
local color = require('src.color')
local state = require('src.state')

local lib = {}

local CELL = 24     -- a swatch, px
local STEP = 27     -- swatch + gap
local PAD = 10
local TITLE = 28    -- the title line
local FOOT = 24     -- the hovered colour's hex
local LEFT = 76     -- right of the tool rail
local RIGHT = 300   -- left of the right column
local MAX_RECENT = 16

state.palette = state.palette or { recent = {} }
local mem = state.palette

local function norm(hex)
    if type(hex) ~= 'string' then return nil end
    hex = hex:gsub('#', ''):lower()
    return #hex >= 6 and hex:sub(1, 6) or hex
end

function lib.isOpen()
    return state.panelVisibility.showPalette and true or false
end

function lib.close()
    state.panelVisibility.showPalette = nil
    state.showPaletteFunc = nil
    mem.rect = nil
end

-- open it for a swatch showing `currentHex`, picks go to onPick(hex); open already: close it
function lib.toggle(currentHex, onPick)
    if lib.isOpen() then
        lib.close()
        return
    end
    state.panelVisibility.showPalette = true
    state.showPaletteFunc = onPick
    mem.current = norm(currentHex)
    mem.justOpened = true -- the release that opened it isn't a pick
end

-- whether (x, y), in UI units, is on the panel as last drawn
function lib.contains(x, y)
    local r = mem.rect
    if not (r and lib.isOpen()) then return false end
    return x >= r[1] and x <= r[1] + r[3] and y >= r[2] and y <= r[2] + r[4]
end

local function remember(hex)
    local recent = mem.recent
    for i = #recent, 1, -1 do
        if recent[i] == hex then table.remove(recent, i) end
    end
    table.insert(recent, 1, hex)
    while #recent > MAX_RECENT do table.remove(recent) end
end

local function pick(hex)
    mem.current = hex
    remember(hex)
    if state.showPaletteFunc then state.showPaletteFunc(hex) end
end

-- the lines to draw: { label, hexes }, a family longer than `cols` going on over two lines
local function layoutLines(cols)
    local lines = {}
    if #mem.recent > 0 then
        local recent = {}
        for i = 1, math.min(#mem.recent, cols) do recent[i] = mem.recent[i] end
        lines[#lines + 1] = { 'recent', recent }
    end
    for _, row in ipairs(color.paletteRows) do
        for start = 1, #row, cols do
            local part = {}
            for i = start, math.min(#row, start + cols - 1) do part[#part + 1] = row[i] end
            lines[#lines + 1] = { nil, part }
        end
    end
    return lines
end

local function swatch(hex, x, y, hovered)
    local r, g, b = color.hexToColor(hex)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle('fill', x, y, CELL, CELL, 4, 4)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0, 0, 0, 0.25) -- so the creams show on a light panel
    love.graphics.rectangle('line', x, y, CELL, CELL, 4, 4)
    if hex == mem.current then
        love.graphics.setLineWidth(3)
        love.graphics.setColor(ui.theme.header.active)
        love.graphics.rectangle('line', x - 3, y - 3, CELL + 6, CELL + 6, 6, 6)
    elseif hovered then
        love.graphics.setLineWidth(2)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.rectangle('line', x - 2, y - 2, CELL + 4, CELL + 4, 5, 5)
    end
end

function lib.draw()
    if not lib.isOpen() then
        mem.rect = nil
        return
    end
    local sw, sh = ui.getDimensions()
    local room = math.max(STEP * 6, sw - LEFT - RIGHT - 2 * PAD)
    local widest = 0
    for _, row in ipairs(color.paletteRows) do widest = math.max(widest, #row) end
    local cols = math.max(1, math.min(widest, math.floor(room / STEP)))
    local lines = layoutLines(cols)

    local pw = cols * STEP - (STEP - CELL) + 2 * PAD
    local ph = TITLE + #lines * STEP + FOOT + PAD
    local px = math.max(10, LEFT + math.floor((sw - LEFT - RIGHT - pw) / 2))
    local py = math.max(10, sh - ph - 10)
    mem.rect = { px, py, pw, ph }
    ui.blockRect = { px, py, pw, ph }

    -- the pointer as it is: startFrame hid it from the widgets under the panel
    ui.mouseX, ui.mouseY = ui.realMouseX or ui.mouseX, ui.realMouseY or ui.mouseY
    local mx, my = ui.mouseX, ui.mouseY
    local hoveredHex
    local picked

    ui.panel(px, py, pw, ph, 'pick a colour', function()
        for li, line in ipairs(lines) do
            local y = py + TITLE + (li - 1) * STEP
            for i, hex in ipairs(line[2]) do
                local x = px + PAD + (i - 1) * STEP
                local hovered = mx >= x and mx < x + CELL and my >= y and my < y + CELL
                if hovered then hoveredHex = hex end
                swatch(hex, x, y, hovered)
                if hovered and ui.mouseReleased then picked = hex end
            end
            if line[1] then -- the recent line: a little gap under it
                love.graphics.setColor(1, 1, 1, 0.15)
                love.graphics.setLineWidth(1)
                love.graphics.line(px + PAD, y + STEP - 2, px + pw - PAD, y + STEP - 2)
            end
        end
        local shown = hoveredHex or mem.current
        if shown then
            love.graphics.setColor(ui.theme.panel.label)
            love.graphics.print('#' .. shown .. (hoveredHex and '' or '  (current)'), px + PAD,
                py + ph - FOOT - 2)
        end
        if ui.button(px + pw - 34, py + 4, 28, 'x', 22) then lib.close() end
    end)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(1)

    if picked and lib.isOpen() and not mem.justOpened then pick(picked) end
    -- a release outside it closes it (the swatch that opened it toggles it itself, before this)
    if ui.mouseReleased and not mem.justOpened and lib.isOpen()
        and not (mx >= px and mx <= px + pw and my >= py and my <= py + ph) then
        lib.close()
    end
    mem.justOpened = false
end

return lib

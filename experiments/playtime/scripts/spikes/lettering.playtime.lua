-- lettering: hand-drawn letters, three drawings of each (Comic Sans, Windsor, Cooper redrawn by
-- claudetools/lettering-forge.py),
-- still or boiling (docs/HANDDRAWN-FONT.md; Nikki 2026-11-12: "3 slightly varying textures per glyph ... same
-- character next could pick a new 1 out of 3"). Views: 'text' (titles, a sign, a long line) and 'sheet' (all
-- the drawings). Keys: f font, v view, h panel, r new seed.
local s = {}
-- lettering: src/lettering.lua, handed to scripts by src/script.lua

local function st()
    if not state.lettering then
        state.lettering = { showPanel = true, view = 'text', font = 'comic', size = 72, boil = 0, jiggle = 0.5,
            seed = 1,
            text = 'Hola Mipo! llama aaa' }
    end
    return state.lettering
end

function s.onStart()
    worldState.paused = false
    st()
end

function s.onKeyPress(key)
    local c = st()
    if key == 'h' then c.showPanel = not c.showPanel end
    if key == 'v' then c.view = c.view == 'text' and 'sheet' or 'text' end
    if key == 'r' then c.seed = c.seed + 1 end
    if key == 'f' then
        local list, at = lettering.FONTS, 1
        for i, name in ipairs(list) do if name == c.font then at = i end end
        c.font = list[at % #list + 1]
    end
end

local PAPER, INK = { 0.96, 0.93, 0.87 }, { 0.17, 0.14, 0.12 }

local function drawText(c, sw)
    local o = { font = c.font, size = c.size, boil = c.boil, jiggle = c.jiggle, seed = c.seed }
    love.graphics.setColor(INK)
    lettering.draw(c.text, 40, 40, o)
    -- a title, centred, bigger
    o.size, o.align = c.size * 1.6, 'center'
    local w = lettering.measure('The Bathhouse', o)
    lettering.draw('The Bathhouse', (sw - w) / 2, 60 + c.size * 1.4, o)
    -- a sign: a board with two lines on it
    local sign = { font = c.font, size = c.size * 0.7, boil = c.boil, jiggle = c.jiggle, seed = c.seed + 7,
        align = 'center' }
    local text = 'MIPO SHOP\nopen 9 - 5'
    local tw, th = lettering.measure(text, sign)
    local sx, sy = 60, 120 + c.size * 3.4
    love.graphics.setColor(0.55, 0.36, 0.22)
    love.graphics.rectangle('fill', sx, sy, tw + 60, th + 40, 12)
    love.graphics.setColor(0.98, 0.93, 0.8)
    lettering.draw(text, sx + 30, sy + 20, sign)
    -- the alphabet, small
    love.graphics.setColor(INK)
    local small = { font = c.font, size = c.size * 0.45, boil = c.boil, jiggle = c.jiggle, seed = c.seed }
    lettering.draw('ABCDEFGHIJKLMNOPQRSTUVWXYZ\nabcdefghijklmnopqrstuvwxyz\n0123456789 !?.,:;\'"()+-=&@#%',
        sx + tw + 140, sy, small)
end

local function drawSheet(c, sw, sh)
    local f = lettering.font(c.font)
    local iw, ih = f.image:getDimensions()
    local k = math.min((sw - 40) / iw, (sh - 40) / ih)
    love.graphics.setColor(INK)
    love.graphics.draw(f.image, 20, 20, 0, k, k)
end

function s.drawUI()
    local c = st()
    local sw, sh = ui.getDimensions()
    love.graphics.setColor(PAPER)
    love.graphics.rectangle('fill', 0, 0, sw, sh)
    if c.view == 'sheet' then drawSheet(c, sw, sh) else drawText(c, sw) end
    love.graphics.setColor(1, 1, 1)
    if not c.showPanel then return end
    ui.startFrame()
    local w, row = 380, 30
    local h = row * 8 + 40
    local x0, y0 = sw - w - 16, sh - h - 16
    ui.panel(x0, y0, w, h, '•• lettering ••', function()
        local x, y, inner = x0 + 10, y0 + 36, w - 20
        local t = ui.textinput('lettering-text', x, y, inner, 26, 'text...', c.text)
        if t then c.text = t end
        y = y + row + 4
        local fonts = lettering.FONTS
        local bw = (inner - (#fonts - 1) * 4) / #fonts
        for i, name in ipairs(fonts) do
            local label = c.font == name and ('[' .. name .. ']') or name
            if ui.button(x + (i - 1) * (bw + 4), y, bw, label, row - 6) then
                c.font = name
            end
        end
        y = y + row
        for _, sl in ipairs({ { 'size', 'size', 16, 160, 1 }, { 'boil', 'boil (fps)', 0, 15, 1 },
            { 'jiggle', 'jiggle', 0, 2, 0.05 } }) do
            ui.label(x, y + 5, sl[2])
            local v = ui.sliderWithInput('lettering-' .. sl[1], x + 100, y - 4, inner - 190, sl[3], sl[4], c[sl[1]],
                nil, sl[5])
            if v then c[sl[1]] = v + 0 end
            y = y + row
        end
        if ui.button(x, y, 120, 'seed ' .. c.seed, row - 6) then c.seed = c.seed + 1 end
        if ui.button(x + 130, y, 120, c.view == 'text' and 'sheet' or 'text', row - 6) then
            c.view = c.view == 'text' and 'sheet' or 'text'
        end
        y = y + row
        ui.label(x, y + 5, 'f font   v view   r seed   h panel')
    end)
end

return s

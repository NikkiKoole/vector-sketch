-- lettering: hand-drawn letters, three drawings of each (Comic Sans, Windsor, Cooper redrawn by
-- claudetools/lettering-forge.py), still or boiling, plain or dressed up in a look (graffiti, candy, chrome …:
-- scripts/spikes/lettering-looks.lua, its numbers and hue on sliders) (docs/HANDDRAWN-FONT.md; Nikki
-- 2026-11-12: "3 slightly varying textures per glyph", "a pseudo 3d graffiti outline ... as an option,
-- tweakable"). Views: 'text' (titles, a sign, a long line) and 'sheet' (all the drawings).
-- Keys: f font, l look, v view, h panel, r new seed.
local s = {}
-- lettering: src/lettering.lua, handed to scripts by src/script.lua
local looks = love.filesystem.load('scripts/spikes/lettering-looks.lua')()(lettering)

local function st()
    if not state.lettering then
        state.lettering = { showPanel = true, view = 'text', font = 'comic', size = 72, boil = 0, jiggle = 0.5,
            seed = 1, text = 'Hola Mipo! llama aaa' }
    end
    local c = state.lettering
    c.look = c.look or 'plain'
    c.tweaks = c.tweaks or {}
    return c
end

-- the slider values of a look (its own defaults until moved)
local function tweaks(c, name)
    if not c.tweaks[name] then c.tweaks[name] = looks.defaults(name) end
    return c.tweaks[name]
end

local LOOK_NAMES = { 'plain' }
for _, name in ipairs(looks.NAMES) do LOOK_NAMES[#LOOK_NAMES + 1] = name end

function s.onStart()
    worldState.paused = false
    st()
end

local function cycle(list, current)
    local at = 1
    for i, name in ipairs(list) do if name == current then at = i end end
    return list[at % #list + 1]
end

function s.onKeyPress(key)
    local c = st()
    if key == 'h' then c.showPanel = not c.showPanel end
    if key == 'v' then c.view = c.view == 'text' and 'sheet' or 'text' end
    if key == 'r' then c.seed = c.seed + 1 end
    if key == 'f' then c.font = cycle(lettering.FONTS, c.font) end
    if key == 'l' then c.look = cycle(LOOK_NAMES, c.look) end
end

local PAPER, INK = { 0.96, 0.93, 0.87 }, { 0.17, 0.14, 0.12 }

local function drawText(c, sw)
    local look = c.look ~= 'plain' and looks.tweaked(c.look, tweaks(c, c.look)) or nil
    local function write(text, x, y, o)
        if look then return looks.draw(text, x, y, o, look) end
        return lettering.draw(text, x, y, o)
    end
    local o = { font = c.font, size = c.size, boil = c.boil, jiggle = c.jiggle, seed = c.seed }
    love.graphics.setColor(INK)
    write(c.text, 40, 40, o)
    -- a title, centred, bigger
    o.size, o.align = c.size * 1.6, 'center'
    local w = lettering.measure('The Bathhouse', o)
    love.graphics.setColor(INK)
    write('The Bathhouse', (sw - w) / 2, 60 + c.size * 1.4, o)
    -- a sign: a board with two lines on it, painted plain
    local sign = { font = c.font, size = c.size * 0.7, boil = c.boil, jiggle = c.jiggle, seed = c.seed + 7,
        align = 'center' }
    local text = 'MIPO SHOP\nopen 9 - 5'
    local tw, th = lettering.measure(text, sign)
    local sx, sy = 60, 140 + c.size * 3.6
    love.graphics.setColor(0.55, 0.36, 0.22)
    love.graphics.rectangle('fill', sx, sy, tw + 60, th + 40, 12)
    love.graphics.setColor(0.98, 0.93, 0.8)
    lettering.draw(text, sx + 30, sy + 20, sign)
    -- the alphabet, small, plain
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

local ROW = 30

local function buttonRows(x, y, inner, list, perRow, current, onPick)
    for start = 1, #list, perRow do
        local n = math.min(perRow, #list - start + 1)
        local bw = (inner - (perRow - 1) * 4) / perRow
        for i = 0, n - 1 do
            local name = list[start + i]
            if ui.button(x + i * (bw + 4), y, bw, current == name and ('[' .. name .. ']') or name, ROW - 6) then
                onPick(name)
            end
        end
        y = y + ROW
    end
    return y
end

local function sliders(x, y, inner, list, values, prefix)
    for _, sl in ipairs(list) do
        ui.label(x, y + 5, sl[2])
        local v = ui.sliderWithInput(prefix .. sl[1], x + 100, y - 4, inner - 190, sl[3], sl[4], values[sl[1]],
            nil, sl[5])
        if v then values[sl[1]] = v + 0 end
        y = y + ROW
    end
    return y
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
    local lookRows = math.ceil(#LOOK_NAMES / 4)
    local rows = 1 + 1 + lookRows + 3 + 1 + 1 + (c.look ~= 'plain' and #looks.TWEAKS + 1 or 0)
    local w = 380
    local h = ROW * rows + 50
    local x0, y0 = sw - w - 16, math.max(12, sh - h - 16)
    ui.panel(x0, y0, w, h, '•• lettering ••', function()
        local x, y, inner = x0 + 10, y0 + 36, w - 20
        local t = ui.textinput('lettering-text', x, y, inner, 26, 'text...', c.text)
        if t then c.text = t end
        y = y + ROW + 4
        y = buttonRows(x, y, inner, lettering.FONTS, 4, c.font, function(name) c.font = name end)
        y = buttonRows(x, y, inner, LOOK_NAMES, 4, c.look, function(name) c.look = name end)
        y = sliders(x, y, inner, { { 'size', 'size', 16, 160, 1 }, { 'boil', 'boil (fps)', 0, 15, 1 },
            { 'jiggle', 'jiggle', 0, 2, 0.05 } }, c, 'lettering-')
        if c.look ~= 'plain' then
            y = sliders(x, y, inner, looks.TWEAKS, tweaks(c, c.look), 'lettering-' .. c.look .. '-')
            if ui.button(x, y, 160, 'reset ' .. c.look, ROW - 6) then c.tweaks[c.look] = looks.defaults(c.look) end
            y = y + ROW
        end
        if ui.button(x, y, 120, 'seed ' .. c.seed, ROW - 6) then c.seed = c.seed + 1 end
        if ui.button(x + 130, y, 120, c.view == 'text' and 'sheet' or 'text', ROW - 6) then
            c.view = c.view == 'text' and 'sheet' or 'text'
        end
        y = y + ROW
        ui.label(x, y + 5, 'f font   l look   v view   r seed   h panel')
    end)
end

return s

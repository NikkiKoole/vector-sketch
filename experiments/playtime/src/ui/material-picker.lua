-- material-picker.lua — a part's material picked from swatches (MATERIALS MT6): the row is one button
-- with the material's little ball and its name; clicking it opens a popup with one ball per material
-- (src/render/materials.lua), each drawn once by the engine's own shader under one light from the
-- top left, so a swatch looks like the material does on a part. Click one to pick it; click outside
-- (or the button again) to close. 'none' is the part as drawn, without a material. 'edit' opens a pane
-- of the picked material's numbers (live on every part in it) with save into materials.lua.
-- The popup is drawn last (lib.drawPopup, from playtime-ui's drawUI) and the widgets under it see no
-- pointer (ui.blockRect, src/ui/all.lua). Its state lives on the ui table, so a hot reload keeps it.
local ui = require('src.ui.all')
local materials = require('src.render.materials')
local shaders = require('src.render.shaders')
local formBake = require('src.render.form-bake')
local sceneLight = require('src.scene-light')

local lib = {}

local SW = 128     -- a swatch's picture, px
local MASK = 256   -- the ball's mask (form-bake needs more pixels than its 96-cell grid)
local BALL = 52    -- a swatch drawn in the popup
local CELL_W, CELL_H = 86, 78
local COLS = 5
local PAD = 8
local LABEL_SCALE = 0.7
local BASE = { 0.84, 0.6, 0.52 } -- one colour for every swatch, so they compare (a metal's tint wins)

local ball, ballMap
local function ballImages()
    if ball then return end
    local data = love.image.newImageData(MASK, MASK)
    local r = MASK / 2 - 4
    data:mapPixel(function(x, y)
        local dx, dy = x + 0.5 - MASK / 2, y + 0.5 - MASK / 2
        local a = math.max(0, math.min(1, r - math.sqrt(dx * dx + dy * dy) + 0.5))
        return 1, 1, 1, a
    end)
    ball = love.graphics.newImage(data, { mipmaps = true })
    ball:setMipmapFilter('linear')
    ball:setFilter('linear', 'linear')
    ballMap = love.graphics.newImage(formBake.bakeData(data, 1), { mipmaps = true })
    ballMap:setFilter('linear', 'linear')
    ballMap:setMipmapFilter('linear')
end

-- one canvas per material, drawn the first time it's shown (a hot reload draws them again)
local swatches, stale = {}, {}
local function swatch(name)
    if name and not materials.PRESETS[name] then name = nil end -- a dropped preset: as drawn
    local key = name or 'none'
    if swatches[key] and not stale[key] then return swatches[key] end
    stale[key] = nil
    ballImages()
    local canvas = swatches[key] or love.graphics.newCanvas(SW, SW)
    love.graphics.push('all')
    love.graphics.setCanvas(canvas)
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode('alpha') -- the UI may be drawing premultiplied: that left a square round the ball
    love.graphics.setShader()
    if name then
        -- the look a material part gets in the game (scene-light's lit Mipo parts), the roundness ours
        local extra = { material = name, plasticineLight = { -0.7, -0.7 }, formMapImage = ballMap }
        for k, v in pairs(sceneLight.LEVELS[1].materialParts) do
            if extra[k] == nil and k ~= 'plasticineFormBaked' then extra[k] = v end
        end
        shaders.setSurfaceShader(extra, nil)
    end
    love.graphics.setColor(BASE)
    love.graphics.draw(ball, 0, 0, 0, SW / MASK, SW / MASK)
    love.graphics.pop()
    swatches[key] = canvas
    return canvas
end

local function drawSwatch(name, x, y, size)
    love.graphics.push('all')
    love.graphics.setColor(1, 1, 1)
    love.graphics.setBlendMode('alpha', 'premultiplied')
    love.graphics.draw(swatch(name), x, y, 0, size / SW, size / SW)
    love.graphics.pop()
end

local function inside(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

-- The row's button at x, y (w wide, h high): the current material's ball and name. id: unique per
-- row on screen (the thing it sets). Returns true, name when a material was picked for this row
-- (name nil: none), else nil.
function lib.button(id, x, y, w, h, current)
    if current == 'none' then current = nil end
    local popup = ui._materialPopup
    if popup and popup.id == id then
        popup.drawn = true
        if popup.apply then -- picked in the edit pane: on the part now, the popup stays open
            popup.apply = false
            return true, popup.value
        end
        if popup.picked then
            ui._materialPopup = nil
            return true, popup.value
        end
    end
    local clicked = ui.button(x, y, w, '', h)
    local size = h - 4
    drawSwatch(current, x + 4, y + 2, size)
    love.graphics.setColor(ui.theme.button.text_default)
    love.graphics.printf(current or 'none', x + size + 8, y + (h - ui.font:getHeight()) / 2, w - size - 12, 'left')
    if clicked then
        if popup and popup.id == id then
            ui._materialPopup = nil
        else
            -- where the button is on screen: a scroll panel draws its content shifted up
            ui._materialPopup = { id = id, x = x, y = y - (ui._scrollShift or 0), w = w, h = h,
                current = current, drawn = true, justOpened = true }
        end
    end
end

-- The edit pane (the popup's 'edit' toggle): the picked material's numbers as sliders, live on its
-- swatch and every part in it; 'save' writes them into src/render/materials.lua, 'revert' goes back
-- to the last saved. Only the numbers the shader reads (src/render/shaders.lua, matKind > 0); velvet
-- has none. { label, field, index, min, max, step }
local SLIDERS = {
    [1] = { -- metal
        { 'shine', 'spec', 1, 0, 3 }, { 'shine size', 'spec', 2, 1, 200, 1 }, { 'rough', 'surf', 4, 0, 1 },
        { 'tint red', 'tint', 1, 0, 1 }, { 'tint green', 'tint', 2, 0, 1 }, { 'tint blue', 'tint', 3, 0, 1 },
        { 'tint amount', 'tint', 4, 0, 1 },
    },
    [5] = { -- a surface
        { 'shine', 'spec', 1, 0, 2 }, { 'shine size', 'spec', 2, 1, 200, 1 }, { 'shine colour', 'spec', 3, 0, 1 },
        { 'clear coat', 'spec', 4, 0, 1 }, { 'edge sheen', 'surf', 2, 0, 1 }, { 'edges dark', 'surf', 3, 0, 1 },
    },
}
local DEFAULTS = { spec = { 0, 0, 0, 0 }, surf = { 0, 0, 0, 0 }, tint = { 1, 1, 1, 0 } }
local EDIT_W = 400
local ROW = 40

local function copyPresets()
    local t = {}
    for name, preset in pairs(materials.PRESETS) do
        local c = {}
        for k, v in pairs(preset) do
            if type(v) == 'table' then
                c[k] = {}
                for i, x in ipairs(v) do c[k][i] = x end
            else
                c[k] = v
            end
        end
        t[name] = c
    end
    return t
end

-- the presets as last saved (or as the file had them when editing started); kept over a hot reload
local function savedPresets()
    ui._materialSaved = ui._materialSaved or copyPresets()
    return ui._materialSaved
end

local function presetValue(preset, field, i)
    local t = preset[field]
    return (t and t[i]) or DEFAULTS[field][i]
end

local function setPresetValue(preset, field, i, v)
    local t = preset[field] or {}
    preset[field] = t
    for k = #t + 1, i - 1 do t[k] = DEFAULTS[field][k] end -- no holes in the array
    t[i] = v
end

local function presetsDiffer(a, b)
    for _, field in ipairs({ 'spec', 'surf', 'tint' }) do
        for i = 1, 4 do
            if presetValue(a, field, i) ~= presetValue(b, field, i) then return true end
        end
    end
    return a.kind ~= b.kind
end

local function anyUnsaved()
    local saved = savedPresets()
    for name, preset in pairs(materials.PRESETS) do
        if not saved[name] or presetsDiffer(preset, saved[name]) then return true end
    end
    return false
end

local function changed(name)
    materials.changed(name)
    stale[name] = true
end

local function number(v)
    local text = string.format('%.3f', v):gsub('0+$', ''):gsub('%.$', '')
    return text
end

local function array(t)
    local parts = {}
    for i, v in ipairs(t) do parts[i] = number(v) end
    return '{ ' .. table.concat(parts, ', ') .. ' }'
end

-- the PRESETS block of src/render/materials.lua written again from the live presets (NAMES order);
-- the rest of the file as it was. Returns true, or nil and why.
local function save()
    local path = love.filesystem.getSource() .. '/src/render/materials.lua'
    local file = io.open(path, 'r')
    if not file then return nil, 'cannot read ' .. path end
    local text = file:read('*a')
    file:close()
    local from = text:find('lib.PRESETS = {\n', 1, true)
    local to = from and text:find('\n}\n', from, true)
    if not to then return nil, 'no PRESETS block in ' .. path end
    local lines = { 'lib.PRESETS = {' }
    for _, name in ipairs(materials.NAMES) do
        local preset = materials.PRESETS[name]
        if preset then
            local line = '    ' .. name .. ' = { kind = ' .. number(preset.kind)
            for _, field in ipairs({ 'spec', 'surf', 'tint' }) do
                if preset[field] then line = line .. ', ' .. field .. ' = ' .. array(preset[field]) end
            end
            lines[#lines + 1] = line .. ' },'
        end
    end
    lines[#lines + 1] = '}'
    text = text:sub(1, from - 1) .. table.concat(lines, '\n') .. text:sub(to + 2)
    file = io.open(path, 'w')
    if not file then return nil, 'cannot write ' .. path end
    file:write(text)
    file:close()
    ui._materialSaved = copyPresets()
    return true
end

local function revert()
    local saved = savedPresets()
    for name, preset in pairs(materials.PRESETS) do
        local s = saved[name]
        if s then
            for _, field in ipairs({ 'spec', 'surf', 'tint' }) do
                if s[field] then
                    preset[field] = {}
                    for i, v in ipairs(s[field]) do preset[field][i] = v end
                else
                    preset[field] = nil
                end
            end
            changed(name)
        end
    end
end

local function drawEditPane(popup, x, y, h)
    local edit = ui._materialEdit
    local name = popup.current
    local preset = name and materials.PRESETS[name]
    love.graphics.setColor(ui.theme.button.text_default)
    ui.alignedLabel(x, y, name and ('editing: ' .. name) or 'pick a material to edit it')
    local yy = y + ROW
    local rows = preset and SLIDERS[preset.kind]
    if preset and not rows then
        ui.alignedLabel(x, yy, name .. ' has no numbers to set')
    end
    for _, s in ipairs(rows or {}) do
        local label, field, i, min, max, step = s[1], s[2], s[3], s[4], s[5], s[6]
        ui.alignedLabel(x, yy + 7, label)
        local v = ui.sliderWithInput('mat-edit:' .. name .. ':' .. label, x + 120, yy, EDIT_W - 120 - 100, min, max,
            presetValue(preset, field, i), nil, step or 0.01)
        if v and v ~= presetValue(preset, field, i) then
            setPresetValue(preset, field, i, v)
            changed(name)
        end
        yy = yy + ROW
    end
    local unsaved = anyUnsaved()
    local by = y + h - ui.theme.button.height
    if ui.button(x, by, 90, 'save', nil, unsaved and ui.theme.header.active or nil) and unsaved then
        local ok, err = save()
        edit.message = ok and 'saved to src/render/materials.lua' or err
    end
    if ui.button(x + 96, by, 90, 'revert') and unsaved then
        revert()
        edit.message = 'back to the last saved'
    end
    local note = edit.message or (unsaved and 'not saved yet' or nil)
    if note then
        love.graphics.setColor(ui.theme.button.text_default)
        love.graphics.printf(note, x + 194, by + 4, (EDIT_W - 200) / LABEL_SCALE, 'left', 0, LABEL_SCALE, LABEL_SCALE)
    end
end

-- The open popup, on top of everything: call once a frame after the panels.
function lib.drawPopup()
    local popup = ui._materialPopup
    if not popup then return end
    -- its row wasn't drawn this frame (the panel closed, another part selected): close it
    if not popup.drawn or popup.picked then
        ui._materialPopup = nil
        return
    end
    popup.drawn = false

    ui._materialEdit = ui._materialEdit or { on = false }
    local edit = ui._materialEdit
    local wasDragging = ui.draggingSliderID ~= nil

    local options = { false }
    for _, name in ipairs(materials.NAMES) do options[#options + 1] = name end
    local rows = math.ceil(#options / COLS)
    local gridW = COLS * CELL_W
    local gridH = rows * CELL_H + ui.theme.button.height + PAD -- the edit toggle under the swatches
    local editH = edit.on and (ROW * 9) or 0
    local pw = gridW + 2 * PAD + (edit.on and (EDIT_W + PAD) or 0)
    local ph = math.max(gridH, editH) + 2 * PAD
    local sw, sh = ui.getDimensions()
    -- under the button, its right edges lined up (the right column is at the screen's right), on screen
    local px = math.max(10, math.min(popup.x + popup.w - pw, sw - pw - 10))
    local py = popup.y + popup.h + 4
    if py + ph > sh - 10 then py = math.max(10, popup.y - ph - 4) end
    ui.blockRect = { px, py, pw, ph }
    local gx = px + pw - PAD - gridW -- the swatches on the right, the edit pane left of them

    -- the pointer as it is: startFrame hid it from the widgets under the popup
    ui.mouseX, ui.mouseY = ui.realMouseX or ui.mouseX, ui.realMouseY or ui.mouseY
    local mx, my = ui.mouseX, ui.mouseY
    ui.panel(px, py, pw, ph, nil, function()
        for i, name in ipairs(options) do
            name = name or nil
            local cx = gx + ((i - 1) % COLS) * CELL_W
            local cy = py + PAD + math.floor((i - 1) / COLS) * CELL_H
            local hover = inside(mx, my, cx, cy, CELL_W, CELL_H)
            if hover then
                love.graphics.setColor(ui.theme.button.hover)
                love.graphics.rectangle('fill', cx + 1, cy + 1, CELL_W - 2, CELL_H - 2, 6, 6)
            end
            if name == popup.current then
                love.graphics.setColor(ui.theme.header.active)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle('line', cx + 1, cy + 1, CELL_W - 2, CELL_H - 2, 6, 6)
            end
            drawSwatch(name, cx + (CELL_W - BALL) / 2, cy + 2, BALL)
            love.graphics.setColor(hover and ui.theme.button.text_hover or ui.theme.button.text_default)
            love.graphics.printf(name or 'none', cx, cy + BALL + 2, CELL_W / LABEL_SCALE, 'center', 0,
                LABEL_SCALE, LABEL_SCALE)
            if hover and ui.mouseReleased and not wasDragging then
                if edit.on then
                    -- editing: on the part straight away, the popup stays open to tune it
                    popup.apply, popup.value, popup.current = true, name, name
                    edit.message = nil
                else
                    popup.picked, popup.value = true, name
                end
            end
        end
        local ty = py + PAD + rows * CELL_H
        if ui.button(gx, ty, 110, edit.on and 'edit: on' or 'edit', nil, edit.on and ui.theme.header.active or nil) then
            edit.on = not edit.on
        end
        if edit.on then drawEditPane(popup, px + PAD, py + PAD, ph - 2 * PAD) end
    end)
    love.graphics.setColor(1, 1, 1)

    if ui.mouseReleased and not popup.justOpened and not wasDragging and not inside(mx, my, px, py, pw, ph) then
        ui._materialPopup = nil
    end
    popup.justOpened = false
end

lib.save = save -- also for the bridge

return lib

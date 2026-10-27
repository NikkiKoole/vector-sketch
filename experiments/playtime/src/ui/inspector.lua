-- inspector.lua
-- One generic panel body for anything that declares its `params` (see
-- src/behaviors.lua): a label column plus one widget per row, basic rows first,
-- advanced rows behind a 'more' fold. Plan: docs/EDITOR-INSPECTOR-LIBRARY.md.
local ui = require('src.ui.all')

local lib = {}

lib.labelWidth = 90
lib.rowHeight = 45

local openFolds = {} -- [foldId] = true; losing it on hot reload is harmless

-- Open or close the '+ more' fold of panel `id` (specs draw the advanced rows too).
function lib.setFoldOpen(id, open) openFolds[id] = open or nil end

local function labelOf(row, target)
    local label = row.label or row.key
    if type(label) == 'function' then return label(target) end
    return label
end

-- Kinds: text (keepSpaces = true keeps spaces), number (slider + field), numberText
-- (field only), bool, choice, action, buttons (one per option), note (label only),
-- color (swatch + hex), file (texture browser + name).
-- A row reads/writes `target[key]`, or calls row.get(target) / row.set(target, v)
-- (Box2D objects). A set may return a replacement target (a rebuilt joint).
local function valueOf(row, target)
    local v
    if row.get then v = row.get(target) else v = target[row.key] end
    if v == nil then return row.default end
    return v
end

local function setValue(row, target, v)
    if row.set then return row.set(target, v) end
    target[row.key] = v
end

local function resolve(v, target)
    if type(v) == 'function' then return v(target) end
    return v
end

-- Returns a replacement target when the row's set rebuilt it.
local function drawRow(id, row, target, body, x, y, w)
    local wx = x + lib.labelWidth
    if row.kind ~= 'action' and row.kind ~= 'note' then ui.alignedLabel(x, y + 7, labelOf(row, target)) end
    if row.kind == 'text' then
        local t, dirty = ui.textinput(id .. row.key, wx, y + 2, w - lib.labelWidth, 40, row.default or '',
            valueOf(row, target) or '')
        if t and dirty then return setValue(row, target, row.keepSpaces and t or (t:gsub('%s', ''))) end
    elseif row.kind == 'numberText' then -- a plain number field, for values without a sensible range
        local v = valueOf(row, target)
        local t, dirty = ui.textinput(id .. row.key, wx, y + 2, w - lib.labelWidth, 40, '',
            tostring(math.floor(v * 100 + 0.5) / 100), true)
        if dirty and tonumber(t) then return setValue(row, target, tonumber(t)) end
    elseif row.kind == 'number' then
        local shown = valueOf(row, target)
        if type(shown) == 'number' then shown = math.floor(shown * 100 + 0.5) / 100 end -- not -209.9999
        local v = ui.sliderWithInput(id .. row.key, wx, y, w - lib.labelWidth - 90, resolve(row.min, target),
            resolve(row.max, target), shown, nil, row.step)
        if v then return setValue(row, target, tonumber(v)) end
    elseif row.kind == 'bool' then
        local clicked, checked = ui.checkbox(wx, y + 7, valueOf(row, target) ~= false, '')
        if clicked then return setValue(row, target, checked) end
    elseif row.kind == 'choice' then
        local current = valueOf(row, target)
        if ui.button(wx, y + 7, w - lib.labelWidth, tostring(current)) then
            local opts = row.options
            local i = 1
            for k, o in ipairs(opts) do if o == current then i = k end end
            return setValue(row, target, opts[i % #opts + 1])
        end
    elseif row.kind == 'action' then
        if ui.button(wx, y + 7, w - lib.labelWidth, labelOf(row, target)) then return row.run(body, target) end
    elseif row.kind == 'buttons' then -- one small button per option: run(body, target, option)
        local bw = (w - lib.labelWidth) / #row.options
        for i, option in ipairs(row.options) do
            if ui.button(wx + (i - 1) * bw, y + 7, bw - 4, option) then return row.run(body, target, option) end
        end
    elseif row.kind == 'note' then
        ui.alignedLabel(x, y + 7, labelOf(row, target), { 1, 1, 1, 0.6 })
    elseif row.kind == 'color' then -- swatch (opens the palette) + hex field
        local hex = valueOf(row, target)
        local r, g, b, a = require('src.physics.box2d-draw-textured').hexToColor(hex or 'ffffffff')
        if ui.button(wx, y + 7, 30, '', nil, { r, g, b, a }) then
            local state = require('src.state')
            if state.panelVisibility.showPalette then
                state.panelVisibility.showPalette = nil
                state.showPaletteFunc = nil
            else
                state.panelVisibility.showPalette = true
                state.showPaletteFunc = function(color) setValue(row, target, color) end
            end
        end
        local t, dirty = ui.textinput(id .. row.key, wx + 36, y + 2, w - lib.labelWidth - 36, 40, 'hex', hex or '')
        if t and dirty then return setValue(row, target, (t:gsub('%s', ''))) end
    elseif row.kind == 'file' then -- '…' opens the texture browser + the file name
        if ui.button(wx, y + 7, 30, '...') then
            require('src.file-browser'):open('/textures', { excludes = '-mask' }, function(path)
                setValue(row, target, path:match('/textures/(.+)$') or path) -- the renderer prepends textures/
            end)
        end
        local t, dirty = ui.textinput(id .. row.key, wx + 36, y + 2, w - lib.labelWidth - 36, 40, '',
            valueOf(row, target) or '')
        if t and dirty then return setValue(row, target, (t:gsub('%s', ''))) end
    end
end

-- Draw `params` for `target` (a behavior table, a joint, ...) at x, y in width
-- w. Returns the height used, plus the new target if a row rebuilt it (then it
-- stops: the old target is gone). `id` keeps text inputs and the fold apart.
function lib.drawParams(id, params, target, body, x, y, w)
    local cy = y
    local function rows(advanced)
        for _, row in ipairs(params) do
            if (row.advanced or false) == advanced and (not row.visible or row.visible(target)) then
                local replaced = drawRow(id, row, target, body, x, cy, w)
                cy = cy + lib.rowHeight
                if replaced ~= nil and replaced ~= target then return replaced end
            end
        end
    end
    local replaced = rows(false)
    if replaced then return cy - y, replaced end
    local hasAdvanced = false
    for _, row in ipairs(params) do hasAdvanced = hasAdvanced or row.advanced or false end
    if hasAdvanced then
        local open = openFolds[id]
        if ui.button(x, cy + 7, w, open and '- less' or '+ more') then openFolds[id] = not open end
        cy = cy + lib.rowHeight
        if open then
            replaced = rows(true)
            if replaced then return cy - y, replaced end
        end
    end
    return cy - y
end

return lib

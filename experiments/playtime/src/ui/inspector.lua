-- inspector.lua
-- One generic panel body for anything that declares its `params` (see
-- src/behaviors.lua): a label column plus one widget per row, basic rows first,
-- advanced rows behind a 'more' fold. Plan: docs/EDITOR-INSPECTOR-LIBRARY.md.
local ui = require('src.ui.all')
local color = require('src.color')
local fileBrowser = require('src.file-browser')
local state = require('src.state')

local lib = {}

local sizes = ui.theme.inspector
lib.labelWidth = sizes.labelWidth
lib.rowHeight = sizes.rowHeight
local FIELD_H = sizes.fieldHeight -- text field height
local DY = sizes.widgetDY         -- buttons, checkboxes and labels sit this far down the row

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
-- color (swatch + hex), file (texture browser + name), part (a checkbox with the label, on(target) /
-- setOn(target, v), then a '<' choice '>' when the row has options, else note(target) as text).
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

-- A choice button at bx, width bw: click = the next option; stepper = '<' and '>' either side too.
-- row.display(target, value) may show a value as other text. Returns the option picked, or nil.
local function drawChoice(row, target, bx, y, bw)
    local current, opts = valueOf(row, target), resolve(row.options, target)
    local i = 1
    for k, o in ipairs(opts) do if o == current then i = k end end
    if row.stepper then
        local aw = 22
        if ui.button(bx, y + DY, aw, '<') then return opts[(i - 2) % #opts + 1] end
        if ui.button(bx + bw - aw, y + DY, aw, '>') then return opts[i % #opts + 1] end
        bx, bw = bx + aw + 2, bw - 2 * (aw + 2)
    end
    local text = row.display and row.display(target, current) or tostring(current)
    if ui.button(bx, y + DY, bw, text) then return opts[i % #opts + 1] end
end

-- Returns a replacement target when the row's set rebuilt it. labelWidth: the
-- label column (default lib.labelWidth; a checkbox pair uses its own).
local function drawRow(id, row, target, body, x, y, w, labelWidth)
    local wx = x + (labelWidth or lib.labelWidth)
    if row.kind ~= 'action' and row.kind ~= 'note' and row.kind ~= 'part' and not row.wide then
        ui.alignedLabel(x, y + DY, labelOf(row, target))
    end
    if row.kind == 'text' then
        local t, dirty = ui.textinput(id .. row.key, wx, y + 2, w - lib.labelWidth, FIELD_H, row.default or '',
            valueOf(row, target) or '')
        if t and dirty then return setValue(row, target, row.keepSpaces and t or (t:gsub('%s', ''))) end
    elseif row.kind == 'numberText' then -- a plain number field, for values without a sensible range
        local v = valueOf(row, target)
        local t, dirty = ui.textinput(id .. row.key, wx, y + 2, w - lib.labelWidth, FIELD_H, '',
            tostring(math.floor(v * 100 + 0.5) / 100), true)
        if dirty and tonumber(t) then return setValue(row, target, tonumber(t)) end
    elseif row.kind == 'number' then
        local shown = valueOf(row, target)
        if type(shown) == 'number' then shown = math.floor(shown * 100 + 0.5) / 100 end -- not -209.9999
        local v = ui.sliderWithInput(id .. row.key, wx, y, w - lib.labelWidth - 90, resolve(row.min, target),
            resolve(row.max, target), shown, nil, row.step)
        if v then return setValue(row, target, tonumber(v)) end
    elseif row.kind == 'bool' then
        local clicked, checked = ui.checkbox(wx, y + DY, valueOf(row, target) ~= false, '')
        if clicked then return setValue(row, target, checked) end
    elseif row.kind == 'choice' then -- click: the next option; row.stepper: '<' and '>' either side too
        local picked = drawChoice(row, target, wx, y, w - lib.labelWidth)
        if picked ~= nil then return setValue(row, target, picked) end
    elseif row.kind == 'part' then -- [x] name, then '<' choice '>' (or a note): a wider label column
        local clicked, checked = ui.checkbox(x, y + DY, row.on(target), labelOf(row, target))
        if clicked then return row.setOn(target, checked) end
        local px = x + lib.labelWidth + 24
        if row.options then
            local picked = drawChoice(row, target, px, y, w - lib.labelWidth - 24)
            if picked ~= nil then return setValue(row, target, picked) end
        elseif row.note then
            ui.alignedLabel(px, y + DY, row.note(target))
        end
    elseif row.kind == 'action' then -- no label column: the button is the label, full width
        if ui.button(x, y + DY, w - 4, labelOf(row, target)) then return row.run(body, target) end
    elseif row.kind == 'buttons' then -- one small button per option: run(body, target, option); wide: no label
        local bx = row.wide and x or wx
        local bw = (row.wide and w - 4 or w - lib.labelWidth) / #row.options
        for i, option in ipairs(row.options) do
            if ui.button(bx + (i - 1) * bw, y + DY, bw - 4, option) then return row.run(body, target, option) end
        end
    elseif row.kind == 'note' then
        ui.alignedLabel(x, y + DY, labelOf(row, target), { 1, 1, 1, 0.6 })
    elseif row.kind == 'color' then -- swatch (opens the palette) + hex field
        local hex = valueOf(row, target)
        local r, g, b, a = color.hexToColor(hex or 'ffffffff')
        if ui.button(wx, y + DY, 30, '', nil, { r, g, b, a }) then
            if state.panelVisibility.showPalette then
                state.panelVisibility.showPalette = nil
                state.showPaletteFunc = nil
            else
                state.panelVisibility.showPalette = true
                state.showPaletteFunc = function(picked) setValue(row, target, picked) end
            end
        end
        local t, dirty = ui.textinput(id .. row.key, wx + 36, y + 2, w - lib.labelWidth - 36, FIELD_H, 'hex', hex or '')
        if t and dirty then return setValue(row, target, (t:gsub('%s', ''))) end
    elseif row.kind == 'file' then -- '…' opens the texture browser + the file name
        if ui.button(wx, y + DY, 30, '...') then
            fileBrowser:open('/textures', { excludes = '-mask' }, function(path)
                setValue(row, target, path:match('/textures/(.+)$') or path) -- the renderer prepends textures/
            end)
        end
        local t, dirty = ui.textinput(id .. row.key, wx + 36, y + 2, w - lib.labelWidth - 36, FIELD_H, '',
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
        local shown = {}
        for _, row in ipairs(params) do
            if (row.advanced or false) == advanced and (not row.visible or row.visible(target)) then
                table.insert(shown, row)
            end
        end
        local i = 1
        while i <= #shown do
            local row, nextRow = shown[i], shown[i + 1]
            local replaced
            if row.kind == 'action' and nextRow and nextRow.kind == 'action' then
                -- two buttons side by side
                local half = w / 2
                replaced = drawRow(id, row, target, body, x, cy, half)
                if replaced == nil or replaced == target then
                    replaced = drawRow(id, nextRow, target, body, x + half, cy, half)
                end
                i = i + 2
            elseif row.kind == 'bool' and nextRow and nextRow.kind == 'bool' then
                -- two checkboxes side by side: label, then its box at the end of each half
                local half = w / 2
                local boxAt = half - ui.theme.slider.height - 12
                replaced = drawRow(id, row, target, body, x, cy, half, boxAt)
                if replaced == nil or replaced == target then
                    replaced = drawRow(id, nextRow, target, body, x + half, cy, half, boxAt)
                end
                i = i + 2
            else
                replaced = drawRow(id, row, target, body, x, cy, w)
                i = i + 1
            end
            cy = cy + lib.rowHeight
            if replaced ~= nil and replaced ~= target then return replaced end
        end
    end
    local replaced = rows(false)
    if replaced then return cy - y, replaced end
    local hasAdvanced = false
    for _, row in ipairs(params) do
        hasAdvanced = hasAdvanced or (row.advanced and (not row.visible or row.visible(target))) or false
    end
    if hasAdvanced then
        local open = openFolds[id]
        if ui.button(x, cy + DY, w, open and '- less' or '+ more') then openFolds[id] = not open end
        cy = cy + lib.rowHeight
        if open then
            replaced = rows(true)
            if replaced then return cy - y, replaced end
        end
    end
    return cy - y
end

return lib

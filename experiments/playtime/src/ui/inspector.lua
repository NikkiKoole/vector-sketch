-- inspector.lua
-- One generic panel body for anything that declares its `params` (see
-- src/behaviors.lua): a label column plus one widget per row, basic rows first,
-- advanced rows behind a 'more' fold. Plan: docs/EDITOR-INSPECTOR-LIBRARY.md.
local ui = require('src.ui.all')
local color = require('src.color')
local fileBrowser = require('src.file-browser')
local state = require('src.state')
local materialPicker = require('src.ui.material-picker')
local palette = require('src.ui.palette')

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
-- setOn(target, v), then a '<' choice '>' when the row has options, else note(target) as text),
-- section (a fold header: the rows after it, up to the next section, show only while it's open; open =
-- true opens it at first; kept on state.inspectorFolds; a section with nothing visible under it hides),
-- custom (row.draw(x, y, w, target) draws it and returns the height it used; 0 hides it).
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

-- One drawer per row kind: drawer(c) with c = { id, row, target, body, x, y, w, wx } (wx: where the
-- widget column starts). Returns a replacement target when the row's set rebuilt it.
local drawers = {}

-- a text field; `keep` keeps spaces
local function textField(c, x, width, placeholder, value, keep)
    local t, dirty = ui.textinput(c.id .. c.row.key, x, c.y + 2, width, FIELD_H, placeholder, value)
    if t and dirty then return setValue(c.row, c.target, keep and t or (t:gsub('%s', ''))) end
end

drawers.text = function(c)
    return textField(c, c.wx, c.w - lib.labelWidth, c.row.default or '', valueOf(c.row, c.target) or '',
        c.row.keepSpaces)
end

drawers.numberText = function(c) -- a plain number field, for values without a sensible range
    local v = valueOf(c.row, c.target)
    local t, dirty = ui.textinput(c.id .. c.row.key, c.wx, c.y + 2, c.w - lib.labelWidth, FIELD_H, '',
        tostring(math.floor(v * 100 + 0.5) / 100), true)
    if dirty and tonumber(t) then return setValue(c.row, c.target, tonumber(t)) end
end

drawers.number = function(c)
    local row, target = c.row, c.target
    local shown = valueOf(row, target)
    if type(shown) == 'number' then shown = math.floor(shown * 100 + 0.5) / 100 end -- not -209.9999
    local v = ui.sliderWithInput(c.id .. row.key, c.wx, c.y, c.w - lib.labelWidth - 90, resolve(row.min, target),
        resolve(row.max, target), shown, nil, row.step)
    if v then return setValue(row, target, tonumber(v)) end
end

drawers.bool = function(c)
    local clicked, checked = ui.checkbox(c.wx, c.y + DY, valueOf(c.row, c.target) ~= false, '')
    if clicked then return setValue(c.row, c.target, checked) end
end

drawers.choice = function(c) -- click: the next option; row.stepper: '<' and '>' either side too
    local picked = drawChoice(c.row, c.target, c.wx, c.y, c.w - lib.labelWidth)
    if picked ~= nil then return setValue(c.row, c.target, picked) end
end

drawers.material = function(c) -- a swatch button that opens the material swatches; 'none' or a name
    local picked, name = materialPicker.button(c.id .. c.row.key, c.wx, c.y + DY, c.w - lib.labelWidth,
        ui.theme.button.height, valueOf(c.row, c.target))
    if picked then return setValue(c.row, c.target, name or 'none') end
end

drawers.part = function(c) -- [x] name, then '<' choice '>' (or a note): a wider label column
    local row, target = c.row, c.target
    local clicked, checked = ui.checkbox(c.x, c.y + DY, row.on(target), labelOf(row, target))
    if clicked then return row.setOn(target, checked) end
    local px = c.x + lib.labelWidth + 24
    if row.options then
        local picked = drawChoice(row, target, px, c.y, c.w - lib.labelWidth - 24)
        if picked ~= nil then return setValue(row, target, picked) end
    elseif row.note then
        ui.alignedLabel(px, c.y + DY, row.note(target))
    end
end

drawers.action = function(c) -- no label column: the button is the label, full width
    if ui.button(c.x, c.y + DY, c.w - 4, labelOf(c.row, c.target)) then return c.row.run(c.body, c.target) end
end

drawers.buttons = function(c) -- one small button per option: run(body, target, option); wide: no label
    local row = c.row
    local bx = row.wide and c.x or c.wx
    local bw = (row.wide and c.w - 4 or c.w - lib.labelWidth) / #row.options
    for i, option in ipairs(row.options) do
        if ui.button(bx + (i - 1) * bw, c.y + DY, bw - 4, option) then return row.run(c.body, c.target, option) end
    end
end

drawers.note = function(c)
    ui.alignedLabel(c.x, c.y + DY, labelOf(c.row, c.target), { 1, 1, 1, 0.6 })
end

drawers.color = function(c) -- swatch (opens the palette) + hex field
    local row, target = c.row, c.target
    local hex = valueOf(row, target)
    local r, g, b, a = color.hexToColor(hex or 'ffffffff')
    if ui.button(c.wx, c.y + DY, 30, '', nil, { r, g, b, a }) then
        palette.toggle(hex, function(picked) setValue(row, target, picked) end)
    end
    return textField(c, c.wx + 36, c.w - lib.labelWidth - 36, 'hex', hex or '')
end

drawers.file = function(c) -- '…' opens the texture browser + the file name
    local row, target = c.row, c.target
    if ui.button(c.wx, c.y + DY, 30, '...') then
        fileBrowser:open('/textures', { excludes = '-mask' }, function(path)
            setValue(row, target, path:match('/textures/(.+)$') or path) -- the renderer prepends textures/
        end)
    end
    return textField(c, c.wx + 36, c.w - lib.labelWidth - 36, '', valueOf(row, target) or '')
end

-- kinds that draw their own label (or have none)
local NO_LABEL_COLUMN = { action = true, note = true, part = true }

-- Returns a replacement target when the row's set rebuilt it. labelWidth: the
-- label column (default lib.labelWidth; a checkbox pair uses its own).
local function drawRow(id, row, target, body, x, y, w, labelWidth)
    if not NO_LABEL_COLUMN[row.kind] and not row.wide then
        ui.alignedLabel(x, y + DY, labelOf(row, target))
    end
    local drawer = drawers[row.kind]
    if drawer then
        return drawer({ id = id, row = row, target = target, body = body, x = x, y = y, w = w,
            wx = x + (labelWidth or lib.labelWidth) })
    end
end

-- whether section row `row` of panel `id` is open (state.inspectorFolds: it survives a hot swap)
local function sectionOpen(id, row)
    state.inspectorFolds = state.inspectorFolds or {}
    local open = state.inspectorFolds[id .. '/' .. row.key]
    if open == nil then return row.open == true end
    return open
end

-- Draw `params` for `target` (a behavior table, a joint, ...) at x, y in width
-- w. Returns the height used, plus the new target if a row rebuilt it (then it
-- stops: the old target is gone). `id` keeps text inputs and the fold apart.
function lib.drawParams(id, params, target, body, x, y, w)
    local cy = y
    local function rows(advanced)
        local shown = {}
        local section, sectionRows -- the fold the rows belong to, and its visible rows
        local function closeSection()
            if section and #sectionRows > 0 then
                table.insert(shown, section)
                if sectionOpen(id, section) then
                    for _, row in ipairs(sectionRows) do table.insert(shown, row) end
                end
            end
        end
        for _, row in ipairs(params) do
            if row.kind == 'section' then
                if not advanced then
                    closeSection()
                    section, sectionRows = row, {}
                end
            elseif (row.advanced or false) == advanced and (not row.visible or row.visible(target)) then
                table.insert(sectionRows or shown, row)
            end
        end
        closeSection()
        local i = 1
        while i <= #shown do
            local row, nextRow = shown[i], shown[i + 1]
            local replaced
            if row.kind == 'section' then
                local open = sectionOpen(id, row)
                if ui.button(x + 8, cy + DY, w - 8, (open and '÷  ' or '•  ') .. labelOf(row, target)) then
                    state.inspectorFolds[id .. '/' .. row.key] = not open
                end
                i = i + 1
            elseif row.kind == 'custom' then
                local h = row.draw(x, cy, w, target) or 0
                cy = cy + h - lib.rowHeight -- the row's own height, not a row's
                i = i + 1
            elseif row.kind == 'action' and nextRow and nextRow.kind == 'action' then
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

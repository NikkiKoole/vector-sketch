-- inspector.lua
-- One generic panel body for anything that declares its `params` (see
-- src/behaviors.lua): a label column plus one widget per row, basic rows first,
-- advanced rows behind a 'more' fold. Plan: docs/EDITOR-INSPECTOR-LIBRARY.md.
local ui = require('src.ui.all')

local lib = {}

lib.enabled = true -- false: the old hand-made behavior panels (src/playtime-ui.lua)
lib.labelWidth = 90
lib.rowHeight = 45

local openFolds = {} -- [foldId] = true; losing it on hot reload is harmless

local function labelOf(row, target)
    local label = row.label or row.key
    if type(label) == 'function' then return label(target) end
    return label
end

local function valueOf(row, target)
    local v = target[row.key]
    if v == nil then return row.default end
    return v
end

local function drawRow(id, row, target, body, x, y, w)
    local wx = x + lib.labelWidth
    if row.kind ~= 'action' then ui.alignedLabel(x, y + 7, labelOf(row, target)) end
    if row.kind == 'text' then
        local t = ui.textinput(id .. row.key, wx, y + 2, w - lib.labelWidth, 40, row.default or '',
            valueOf(row, target) or '')
        if t then target[row.key] = t:gsub('%s', '') end
    elseif row.kind == 'number' then
        local v = ui.sliderWithInput(id .. row.key, wx, y, w - lib.labelWidth - 90, row.min, row.max,
            valueOf(row, target), nil, row.step)
        if v then target[row.key] = tonumber(v) end
    elseif row.kind == 'bool' then
        local clicked, checked = ui.checkbox(wx, y + 7, valueOf(row, target) ~= false, '')
        if clicked then target[row.key] = checked end
    elseif row.kind == 'choice' then
        local current = valueOf(row, target)
        if ui.button(wx, y + 7, w - lib.labelWidth, tostring(current)) then
            local opts = row.options
            local i = 1
            for k, o in ipairs(opts) do if o == current then i = k end end
            target[row.key] = opts[i % #opts + 1]
        end
    elseif row.kind == 'action' then
        if ui.button(wx, y + 7, w - lib.labelWidth, labelOf(row, target)) then row.run(body, target) end
    end
end

-- Draw `params` for `target` (a behavior table) at x, y in width w. Returns the
-- height used. `id` keeps text inputs and the fold apart per body.
function lib.drawParams(id, params, target, body, x, y, w)
    local cy = y
    local hasAdvanced = false
    for _, row in ipairs(params) do
        if row.advanced then
            hasAdvanced = true
        else
            drawRow(id, row, target, body, x, cy, w)
            cy = cy + lib.rowHeight
        end
    end
    if hasAdvanced then
        local open = openFolds[id]
        if ui.button(x, cy + 7, w, open and '- less' or '+ more') then openFolds[id] = not open end
        cy = cy + lib.rowHeight
        if open then
            for _, row in ipairs(params) do
                if row.advanced then
                    drawRow(id, row, target, body, x, cy, w)
                    cy = cy + lib.rowHeight
                end
            end
        end
    end
    return cy - y
end

return lib

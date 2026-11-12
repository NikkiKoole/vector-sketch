-- src/ui/kind-editor.lua: the properties panel for a part of a kind's instance (src/kinds.lua, docs/KINDS.md
-- KD4b), the Mipo panel's shape: the whole first (its name, copy, delete; its settings from the kind's
-- `rows`, roll), then its parts on a picture of it (part-map.drawShapes) and the picked part's own rows
-- (the kind's `partRows`), then dissolve (plain bodies, the workshop's). A setting changed makes it again
-- in place (kinds.rebuild).
local lib = {}

local ui = require('src.ui.all')
local state = require('src.state')
local kinds = require('src.kinds')
local library = require('src.library')
local partMap = require('src.ui.mipo.part-map')

local SMALL = 30

local function selectThing(thing)
    local sel = state.selection
    sel.selectedObj, sel.selectedBodies, sel.selectedJoint, sel.selectedSFixture = thing, nil, nil, nil
end

local function step(list, current, delta)
    local at = 1
    for i, v in ipairs(list) do if v == current then at = i end end
    return list[(at - 1 + delta) % #list + 1]
end

-- the instance's settings with one changed (a copy: rebuild takes it as the new settings)
local function with(settings, key, value)
    local copy = {}
    for k, v in pairs(settings) do copy[k] = v end
    copy[key] = value
    return copy
end

-- the kind's settings rows; returns y, and new settings when one changed
local function drawSettings(instance, kind, x, y, W, ROW)
    local changed
    for _, row in ipairs(kind.rows or {}) do
        local value = instance.settings[row.key]
        if row.kind == 'choice' then
            local pick
            if ui.button(x, y, SMALL, '<') then pick = step(row.options, value, -1) end
            if ui.button(x + SMALL + 4, y, W - 2 * SMALL - 8, tostring(value)) then
                pick = step(row.options, value, 1)
            end
            if ui.button(x + W - SMALL, y, SMALL, '>') then pick = step(row.options, value, 1) end
            if pick and pick ~= value then changed = with(instance.settings, row.key, pick) end
        elseif row.kind == 'number' then
            local raw = ui.sliderWithInput('kind_' .. row.key, x, y, 120, row.min, row.max, value or row.min)
            ui.alignedLabel(x, y, '  ' .. (row.label or row.key))
            local v = raw ~= nil and tonumber(raw) or nil -- nothing back when it didn't change
            if v and v ~= value then changed = with(instance.settings, row.key, v) end
        end
        y = y + ROW
    end
    return y, changed
end

function lib.draw(instance, partName, panelX, panelY, panelWidth, panelH)
    local kind = kinds.kindOf(instance.kind)
    if not kind then return end
    ui.scrollableList('kind_scroll', panelX, panelY, panelWidth, panelH, function(_, _, _, _, scrollOffset)
        local pad = ui.theme.spacing
        local ROW = ui.theme.lineHeight + ui.theme.spacing
        local x, y = panelX + pad, panelY + pad + (scrollOffset or 0)
        local startY = y
        local W = panelWidth - 40
        local bw = math.floor(W / 3)

        -- the whole: name, copy, delete
        ui.label(x, y, instance.kind)
        local thing = state.selection.selectedObj
        if thing and ui.button(x + W - 2 * bw - 4, y, bw, 'copy') then
            -- library.clone brings the whole instance; the copy's same part gets selected
            for _, copy in ipairs(library.clone({ thing })) do
                if copy.kindPart == partName then selectThing(copy) break end
            end
        end
        if ui.button(x + W - bw, y, bw, 'delete') then
            kinds.remove(instance)
            selectThing(nil)
            return y + ROW - startY
        end
        y = y + ROW

        -- its settings and roll: either makes it again, in place
        local changed
        y, changed = drawSettings(instance, kind, x, y, W, ROW)
        if kind.roll and ui.button(x, y, math.floor(W / 2) - 2, 'roll') then changed = kind.roll(instance.settings) end
        y = y + ROW
        if changed then
            kinds.rebuild(instance, changed)
            return y - startY -- its bodies are new: the rest next frame
        end

        -- its parts on a picture of it; the picked one's own rows
        y = y + ui.theme.spacing
        love.graphics.line(x, y, x + W, y)
        y = y + ui.theme.spacing
        local anchor = instance.parts[kind.anchor or 'frame']
        if anchor and anchor.body and not anchor.body:isDestroyed() then
            local picked, h = partMap.drawShapes('kind_parts', x, y, W, instance.parts, partName, anchor.body)
            if picked and instance.parts[picked] then selectThing(instance.parts[picked]) end
            y = y + h + ui.theme.spacing
        end
        ui.label(x, y, tostring(partName))
        y = y + ROW
        local part = instance.parts[partName]
        for i, row in ipairs((kind.partRows and part and kind.partRows(partName, part)) or {}) do
            local current = row.get()
            local raw = ui.sliderWithInput('kind_part_' .. i, x, y, 120, row.min, row.max, current)
            local v = raw ~= nil and tonumber(raw) or nil -- nothing back when it didn't change
            ui.alignedLabel(x, y, '  ' .. row.label)
            if v and v ~= current then row.set(v) end
            y = y + ROW
        end

        -- dissolve: the parts become plain bodies, to change in the workshop
        y = y + ui.theme.spacing
        if ui.button(x, y, math.floor(W / 2) - 2, 'dissolve') then kinds.dissolve(instance) end
        y = y + ROW
        return y - startY
    end)
end

return lib

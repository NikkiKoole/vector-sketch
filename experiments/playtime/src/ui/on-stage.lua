-- The "on stage" tab of the right column: one row per object on the stage.
-- Mipos get a row each, wires show as `button -> gate1 -> gate`, the other
-- bodies are grouped by label (`hold x28`). Clicking a row selects it; clicking
-- a group again steps to the next one. See docs/EDITOR-INSPECTOR-LIBRARY.md.
local lib = {}

local ui = require('src.ui.all')
local state = require('src.state')
local camera = require('src.camera')
local cameraFollow = require('src.camera-follow')
local mipoRegistry = require('src.mipo-registry')
local signals = require('src.signals')
local thingOf = require('src.utils').thingOf

local function labelOf(body)
    local thing = thingOf(body)
    if thing.label and thing.label ~= '' then return thing.label end
    return '(' .. tostring(thing.shapeType) .. ')'
end

local function mipoBody(instance)
    for _, name in ipairs({ 'torso1', 'head' }) do
        local part = instance.parts[name]
        if part and part.body and not part.body:isDestroyed() then return part.body end
    end
    for _, part in pairs(instance.parts) do
        if part.body and not part.body:isDestroyed() then return part.body end
    end
end

-- Rows in order: { header = 'mipos' } or { label, bodies = {...} }.
function lib.rows()
    local rows = {}
    local world = state.physicsWorld
    if not world then return rows end

    local mipoRows = {}
    for id, instance in pairs(mipoRegistry.getAll()) do
        local body = mipoBody(instance)
        if body then table.insert(mipoRows, { label = 'mipo ' .. id, bodies = { body }, mipoId = id }) end
    end
    table.sort(mipoRows, function(a, b) return a.label < b.label end)
    if #mipoRows > 0 then
        table.insert(rows, { header = 'mipos' })
        for _, row in ipairs(mipoRows) do table.insert(rows, row) end
    end

    local wires = signals.wires()
    if #wires > 0 then
        table.insert(rows, { header = 'wires' })
        for _, wire in ipairs(wires) do
            table.insert(rows, {
                label = labelOf(wire.from) .. ' -> ' .. wire.signal .. ' -> ' .. labelOf(wire.to),
                bodies = { wire.from, wire.to },
            })
        end
    end

    local groups, order = {}, {}
    for _, body in ipairs(world:getBodies()) do
        local thing = thingOf(body)
        if thing and not thing.mipoId then
            local label = labelOf(body)
            if not groups[label] then
                groups[label] = { label = label, bodies = {} }
                table.insert(order, label)
            end
            table.insert(groups[label].bodies, body)
        end
    end
    table.sort(order)
    if #order > 0 then
        table.insert(rows, { header = 'things' })
        for _, label in ipairs(order) do
            local group = groups[label]
            -- a stable order, so stepping through a group visits each one once
            table.sort(group.bodies, function(a, b) return thingOf(a).id < thingOf(b).id end)
            if #group.bodies > 1 then group.label = label .. '  x' .. #group.bodies end
            table.insert(rows, group)
        end
    end
    return rows
end

local function selectedBody()
    local obj = state.selection.selectedObj
    if obj and obj.body and not obj.body:isDestroyed() then return obj.body end
end

local function indexOf(list, value)
    for i, v in ipairs(list) do
        if v == value then return i end
    end
end

-- a Mipo's row lights up for any of its parts
local function isSelected(row, body)
    if not body then return false end
    if row.mipoId then
        local thing = thingOf(body)
        return thing ~= nil and thing.mipoId == row.mipoId
    end
    return indexOf(row.bodies, body) ~= nil
end

-- the body a click on this row selects: the first one, or the next after the selected one
function lib.nextBody(row)
    local i = indexOf(row.bodies, selectedBody())
    if i and #row.bodies > 1 and not row.label:find(' -> ') then
        return row.bodies[i % #row.bodies + 1]
    end
    return row.bodies[1]
end

-- pan to the body when it's off screen (or under the right column)
local function showOnStage(body)
    local cam = camera.getInstance()
    local sx, sy = cam:getScreenCoordinates(body:getPosition())
    local w, h = ui.getDimensions()
    if sx < 0 or sy < 0 or sx > w - 340 or sy > h then
        cam:setTranslation(body:getPosition())
    end
end

function lib.select(body)
    state.selection.selectedObj = thingOf(body)
    state.selection.selectedJoint = nil
    state.selection.selectedSFixture = nil
    state.selection.selectedBodies = nil
    showOnStage(body)
end

function lib.draw(x, y, w, h)
    ui.panel(x, y, w, h, 'on stage', function()
        ui.scrollPanel('on-stage-panel', x, y + ui.theme.panelHeader, w, h - ui.theme.panelHeader - 5, function()
            local rowX, rowY, rowW = x + 10, y + ui.theme.panelHeader + ui.theme.spacing, w - 20
            local current = selectedBody()
            local rowH = ui.theme.button.height
            for _, row in ipairs(lib.rows()) do
                if row.header then
                    ui.label(rowX, rowY, row.header)
                else
                    -- hovering a row outlines its bodies on the stage (src/editor-render.lua)
                    if ui.mouseX >= rowX and ui.mouseX <= rowX + rowW and ui.mouseY >= rowY
                        and ui.mouseY <= rowY + rowH then
                        state.interaction.hoverBodies = row.bodies
                    end
                    -- a Mipo row has a 'cam' toggle: the camera follows this one while playing
                    local camW = row.mipoId and 50 or 0
                    local labelW = rowW - (camW > 0 and camW + 6 or 0)
                    if ui.header_button(rowX, rowY, labelW, ' ' .. row.label, isSelected(row, current)) then
                        lib.select(lib.nextBody(row))
                    end
                    if camW > 0 then
                        local pinned = cameraFollow.isPinned(row.bodies[1])
                        if ui.header_button(rowX + labelW + 6, rowY, camW, ' cam', pinned) then
                            cameraFollow.pin(not pinned and row.bodies[1] or nil)
                        end
                    end
                end
                rowY = rowY + rowH + 4
            end
        end)
    end)
end

return lib

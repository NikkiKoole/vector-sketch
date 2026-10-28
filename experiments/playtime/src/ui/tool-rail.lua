-- tool-rail.lua — the left tool rail (docs/EDITOR-INSPECTOR-LIBRARY.md, step d).
-- One button per tool group. The button reuses the group's last pick; the small tab
-- next to it opens a flyout with the whole group in two columns. A group either
-- spawns on press (shapes: press and drag one out, from the rail or the flyout) or
-- starts a mode on click (joints: then click body A and body B).
-- Picks and the open flyout live on state.toolRail so they survive hot reloads.
local lib = {}

local ui = require('src.ui.all')
local state = require('src.state')
local objectManager = require('src.object-manager')
local camera = require('src.camera')
local cam = camera.getInstance()
local ST = require('src.shape-types')
local JT = require('src.joint-types')
local modes = require('src.modes')

local RAIL_X = 10
local RAIL_TOP = 60
local BUTTON = 56
local TAB = 18
local COLUMN = 110

lib.SHORT_NAMES = {
    [ST.RECTANGLE] = 'rect',
    [ST.PENTAGON] = '5-gon',
    [ST.HEXAGON] = '6-gon',
    [ST.HEPTAGON] = '7-gon',
    [ST.OCTAGON] = '8-gon',
}

-- The thing a rail/flyout press spawned, so a release back over the rail can undo it.
local spawned = nil

local function spawnShape(shapeType)
    ui.draggingActive = ui.activeElementID
    local wx, wy = cam:getWorldCoordinates(love.mouse.getPosition())
    objectManager.startSpawn(shapeType, wx, wy)
    spawned = state.interaction.draggingObj
end

lib.groups = {
    {
        key = 'shape',
        default = ST.RECTANGLE,
        sections = {
            { ST.RECTANGLE, ST.CIRCLE, ST.CAPSULE, ST.RIBBON },
            { title = 'more', ST.TRIANGLE, ST.ITRIANGLE, ST.TORSO, ST.TRAPEZIUM,
                ST.PENTAGON, ST.HEXAGON, ST.HEPTAGON, ST.OCTAGON },
        },
        onPress = spawnShape,
    },
    {
        key = 'joint',
        default = JT.REVOLUTE,
        sections = {
            { JT.REVOLUTE, JT.WELD, JT.DISTANCE, JT.ROPE },
            { title = 'more', JT.WHEEL, JT.MOTOR, JT.PRISMATIC, JT.PULLEY, JT.FRICTION },
        },
        -- clicking the button again while picking bodies cancels
        onClick = function(jointType)
            if modes.is(modes.JOINT_CREATION) and state.jointParams
                and state.jointParams.jointType == jointType then
                state.jointParams = nil
                modes.clear()
                return
            end
            state.jointParams = { body1 = nil, body2 = nil, jointType = jointType }
            modes.set(modes.JOINT_CREATION)
        end,
        isActive = function() return modes.is(modes.JOINT_CREATION) end,
    },
}

function lib.groupOf(item)
    for _, group in ipairs(lib.groups) do
        for _, section in ipairs(group.sections) do
            for _, it in ipairs(section) do
                if it == item then return group.key end
            end
        end
    end
end

local function railState()
    state.toolRail = state.toolRail or { open = nil, last = {} }
    return state.toolRail
end

function lib.lastPick(group)
    return railState().last[group.key] or group.default
end

-- Placeholder icons, drawn from the shape itself.
local function regularPolygon(cx, cy, r, n, rotation)
    local points = {}
    for i = 0, n - 1 do
        local a = rotation + i * 2 * math.pi / n
        points[#points + 1] = cx + math.cos(a) * r
        points[#points + 1] = cy + math.sin(a) * r
    end
    return points
end

local function drawIcon(item, cx, cy, r)
    local lg = love.graphics
    lg.setColor(ui.theme.button.text_default)
    lg.setLineWidth(3)
    local up = -math.pi / 2
    if item == ST.RECTANGLE then
        lg.rectangle('line', cx - r, cy - r * 0.7, r * 2, r * 1.4)
    elseif item == ST.CIRCLE then
        lg.circle('line', cx, cy, r)
    elseif item == ST.CAPSULE then
        lg.rectangle('line', cx - r * 0.5, cy - r, r, r * 2, r * 0.5, r * 0.5)
    elseif item == ST.RIBBON then
        lg.line(cx - r, cy + r * 0.4, cx - r * 0.5, cy - r * 0.4, cx, cy + r * 0.4,
            cx + r * 0.5, cy - r * 0.4, cx + r, cy + r * 0.4)
    elseif item == ST.TRIANGLE then
        lg.polygon('line', regularPolygon(cx, cy + r * 0.2, r, 3, up))
    elseif item == ST.ITRIANGLE then
        lg.polygon('line', cx - r * 0.7, cy - r, cx + r * 0.7, cy - r, cx, cy + r)
    elseif item == ST.TORSO then
        lg.polygon('line', cx - r * 0.5, cy - r, cx + r * 0.5, cy - r, cx + r, cy - r * 0.2,
            cx + r * 0.6, cy + r, cx - r * 0.6, cy + r, cx - r, cy - r * 0.2)
    elseif item == ST.TRAPEZIUM then
        lg.polygon('line', cx - r * 0.5, cy - r * 0.6, cx + r * 0.5, cy - r * 0.6,
            cx + r, cy + r * 0.6, cx - r, cy + r * 0.6)
    elseif item == JT.REVOLUTE then
        lg.line(cx - r, cy + r * 0.6, cx, cy)
        lg.line(cx, cy, cx + r, cy + r * 0.6)
        lg.circle('fill', cx, cy, r * 0.25)
    elseif item == JT.WELD then
        lg.rectangle('line', cx - r, cy - r * 0.5, r, r)
        lg.rectangle('line', cx, cy - r * 0.5, r, r)
    elseif item == JT.DISTANCE then
        lg.line(cx - r, cy, cx + r, cy)
        lg.circle('fill', cx - r, cy, r * 0.2)
        lg.circle('fill', cx + r, cy, r * 0.2)
    elseif item == JT.ROPE then
        lg.line(cx - r, cy - r * 0.5, cx - r * 0.3, cy + r * 0.5, cx + r * 0.3, cy - r * 0.5,
            cx + r, cy + r * 0.5)
        lg.circle('fill', cx - r, cy - r * 0.5, r * 0.2)
        lg.circle('fill', cx + r, cy + r * 0.5, r * 0.2)
    elseif lib.groupOf(item) ~= 'shape' then
        lg.printf(item:sub(1, 4), cx - r * 2, cy - ui.font:getHeight() / 2, r * 4, 'center')
    else
        local sides = { [ST.PENTAGON] = 5, [ST.HEXAGON] = 6, [ST.HEPTAGON] = 7, [ST.OCTAGON] = 8 }
        lg.polygon('line', regularPolygon(cx, cy, r, sides[item] or 6, up))
    end
end

local function inRect(rect, x, y)
    return rect and x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

-- Rects of the rail and the open flyout, from the last draw.
local railRect, flyoutRect = nil, nil

function lib.isOver(x, y)
    return inRect(railRect, x, y) or inRect(flyoutRect, x, y)
end

local function finishSpawn()
    ui.draggingActive = nil
    local thing = spawned
    spawned = nil
    -- a click without a drag drops the shape on the rail: take it back
    if thing and thing.body and not thing.body:isDestroyed() and lib.isOver(ui.mouseX, ui.mouseY) then
        if state.interaction.draggingObj == thing then state.interaction.draggingObj = nil end
        objectManager.destroyBody(thing.body)
    end
end

function lib.flyoutSize(group)
    local gap = ui.theme.spacing
    local h = gap
    for _, section in ipairs(group.sections) do
        if section.title then h = h + ui.theme.lineHeight + gap end
        h = h + math.ceil(#section / 2) * (ui.theme.button.height + gap)
    end
    return gap * 3 + COLUMN * 2, h
end

local function drawFlyout(group, x, y)
    local rs = railState()
    local gap = ui.theme.spacing
    local w, h = lib.flyoutSize(group)
    flyoutRect = { x = x, y = y, w = w, h = h }
    ui.panel(x, y, w, h, nil, function()
        local cy = y + gap
        for _, section in ipairs(group.sections) do
            if section.title then
                ui.label(x + gap, cy, '— ' .. section.title)
                cy = cy + ui.theme.lineHeight + gap
            end
            for i, item in ipairs(section) do
                local column = (i - 1) % 2
                local bx = x + gap + column * (COLUMN + gap)
                local fill = item == lib.lastPick(group) and ui.theme.header.active or nil
                local clicked, pressed, released = ui.button(bx, cy, COLUMN, lib.SHORT_NAMES[item] or item, nil,
                    fill)
                if pressed and group.onPress then
                    rs.last[group.key] = item
                    group.onPress(item)
                end
                if released then
                    rs.open = nil
                    if group.onPress then finishSpawn() end
                end
                if clicked and group.onClick then
                    rs.last[group.key] = item
                    group.onClick(item)
                end
                if column == 1 or i == #section then
                    cy = cy + ui.theme.button.height + gap
                end
            end
        end
    end)
end

function lib.draw()
    local rs = railState()
    local gap = ui.theme.spacing
    local railW = gap * 2 + BUTTON + TAB
    local railH = gap + #lib.groups * (BUTTON + gap)
    railRect = { x = RAIL_X, y = RAIL_TOP, w = railW, h = railH }

    -- a press anywhere else closes the flyout
    if rs.open and ui.mousePressed and not lib.isOver(ui.mouseX, ui.mouseY) then
        rs.open = nil
    end
    flyoutRect = nil

    local openGroup, openY = nil, nil
    ui.panel(RAIL_X, RAIL_TOP, railW, railH, nil, function()
        for i, group in ipairs(lib.groups) do
            local x = RAIL_X + gap
            local y = RAIL_TOP + gap + (i - 1) * (BUTTON + gap)
            local active = group.isActive and group.isActive()
            local clicked, pressed, released = ui.button(x, y, BUTTON, '', BUTTON,
                active and ui.theme.header.active or nil)
            drawIcon(lib.lastPick(group), x + BUTTON / 2, y + BUTTON / 2, BUTTON * 0.3)
            if group.onPress then
                if pressed then group.onPress(lib.lastPick(group)) end
                if released then finishSpawn() end
            elseif clicked then
                group.onClick(lib.lastPick(group))
            end

            local isOpen = rs.open == group.key
            local tabClicked = ui.button(x + BUTTON, y, TAB, '', BUTTON, isOpen and ui.theme.header.active or nil)
            love.graphics.setColor(ui.theme.button.text_default)
            local tx, ty = x + BUTTON + TAB / 2, y + BUTTON / 2
            love.graphics.polygon('fill', tx - 3, ty - 6, tx - 3, ty + 6, tx + 4, ty)
            if tabClicked then rs.open = (not isOpen) and group.key or nil end
            if rs.open == group.key then openGroup, openY = group, y end
        end
    end)

    if openGroup then
        drawFlyout(openGroup, RAIL_X + railW + gap, openY)
    end
end

return lib

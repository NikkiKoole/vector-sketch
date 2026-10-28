-- tool-rail.lua — the left tool rail (docs/EDITOR-INSPECTOR-LIBRARY.md, step d).
-- One button per tool group. The button reuses the group's last pick; the small tab
-- next to it opens a flyout with the whole group in two columns. A group either
-- works by press-drag-release (shapes: drag one out; attach: drop an sfixture on a
-- body; mipo: drag one out) or starts a mode on click (joints: then click body A
-- and body B; draw: draw on the stage). Clicking an active mode's button again ends it.
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
local fixtures = require('src.fixtures')
local mathutils = require('src.math-utils')
local box2dPointerJoints = require('src.physics.box2d-pointerjoints')

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
    ['texfixture'] = 'texture',
    ['connected-texture'] = 'connected',
    ['tile-repeat'] = 'tile',
    ['trace-vertices'] = 'trace',
    [modes.DRAW_FREE_PATH] = 'freepath',
    [modes.DRAW_FREE_POLY] = 'freeform',
    [modes.DRAW_CLICK] = 'click',
}

-- The thing a rail/flyout press spawned, so a release back over the rail can undo it.
local spawned = nil

local function spawnShape(shapeType)
    ui.draggingActive = ui.activeElementID
    local wx, wy = cam:getWorldCoordinates(love.mouse.getPosition())
    objectManager.startSpawn(shapeType, wx, wy)
    spawned = state.interaction.draggingObj
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

local function startAttach()
    ui.draggingActive = ui.activeElementID
    state.interaction.offsetDragging = { 0, 0 }
end

-- texfixtures start as big as the body they land on; the rest as a 30 radius circle
local ATTACH_EXTRA = {
    ['texfixture'] = function(body)
        local _, _, w, h = mathutils.getCenterAndDimensions(body)
        return { width = w, height = h }
    end,
}

-- Drop an sfixture of this kind on the body under the mouse (topmost), if any.
local function dropAttach(subtype)
    ui.draggingActive = nil
    if lib.isOver(ui.mouseX, ui.mouseY) then return end
    local wx, wy = cam:getWorldCoordinates(ui.mouseX, ui.mouseY)
    local _, hitted = box2dPointerJoints.handlePointerPressed(wx, wy, 'mouse', {}, not state.world.paused)
    if #hitted > 0 then
        local body = hitted[#hitted]:getBody()
        local localX, localY = body:getLocalPoint(wx, wy)
        local extraData = ATTACH_EXTRA[subtype] and ATTACH_EXTRA[subtype](body) or { radius = 30 }
        state.selection.selectedSFixture = fixtures.createSFixture(body, localX, localY, subtype, extraData)
    end
end

-- A Mipo dropped back on the rail is taken back too (the mipo registry drops
-- instances whose parts are all gone).
local spawnedMipo = nil

local function spawnMipo(kind)
    ui.draggingActive = ui.activeElementID
    local CM = require('src.character-manager')
    local wx, wy = cam:getWorldCoordinates(love.mouse.getPosition())
    local instance = CM.createCharacter('humanoid', wx, wy, 0.3)
    if not instance then return end
    if kind == 'mipo *' then CM.randomizeMipoConstrained(instance) else CM.randomizeMipo(instance) end
    CM.poseTpose(instance)
    local torsoThing = instance.parts['torso1']
    if torsoThing then
        state.interaction.draggingObj = torsoThing
        state.interaction.offsetDragging = { 0, 0 }
        local allThings = {}
        for _, part in pairs(instance.parts) do
            table.insert(allThings, part)
        end
        state.selection.selectedBodies = allThings
    end
    spawnedMipo = instance
end

local function finishMipo()
    ui.draggingActive = nil
    state.selection.selectedBodies = nil
    local instance = spawnedMipo
    spawnedMipo = nil
    if instance and lib.isOver(ui.mouseX, ui.mouseY) then
        state.interaction.draggingObj = nil
        for _, part in pairs(instance.parts) do
            if part.body and not part.body:isDestroyed() then objectManager.destroyBody(part.body) end
        end
    end
end

local function startDraw(mode)
    if modes.is(mode) then
        modes.clear()
    else
        modes.set(mode)
    end
    state.interaction.polyVerts = {}
    state.interaction.lastPolyPt = nil
end

-- the draw tools' one option, under the flyout: how far apart freehand points are
local function drawDrawOptions(x, y, w)
    -- label, slider, then sliderWithInput's own 80 px box 10 px after the slider
    local labelW = 40
    ui.alignedLabel(x, y, 'dis')
    local minDist = ui.sliderWithInput('minDistance', x + labelW, y, w - labelW - 90, 1, 150,
        state.editorPreferences.minPointDistance or 10)
    if minDist then
        state.editorPreferences.minPointDistance = tonumber(minDist) or 50
    end
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
        onRelease = finishSpawn,
    },
    {
        key = 'draw',
        default = modes.DRAW_FREE_POLY,
        sections = {
            { modes.DRAW_FREE_POLY, modes.DRAW_FREE_PATH, modes.DRAW_CLICK },
        },
        onClick = startDraw,
        isActive = function()
            return modes.is(modes.DRAW_FREE_POLY) or modes.is(modes.DRAW_FREE_PATH) or modes.is(modes.DRAW_CLICK)
        end,
        drawOptions = drawDrawOptions,
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
    {
        key = 'attach',
        default = 'snap',
        sections = {
            { title = 'play', 'snap', 'anchor' },
            { title = 'looks', 'texfixture', 'connected-texture', 'tile-repeat', 'light' },
            { title = 'skin', 'resource', 'meshusert', 'uvusert', 'trace-vertices' },
        },
        onPress = startAttach,
        onRelease = dropAttach,
    },
    {
        key = 'mipo',
        default = 'mipo',
        sections = {
            { 'mipo', 'mipo *' },
        },
        onPress = spawnMipo,
        onRelease = finishMipo,
    },
    {
        key = 'settings', -- a plain button: no picks, no flyout
        onClick = function()
            local pv = state.panelVisibility
            pv.worldSettingsOpened = not pv.worldSettingsOpened
        end,
        isActive = function() return state.panelVisibility.worldSettingsOpened end,
    },
}

function lib.groupOf(item)
    for _, group in ipairs(lib.groups) do
        for _, section in ipairs(group.sections or {}) do
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
    elseif item == 'snap' then
        lg.circle('line', cx, cy, r)
        lg.circle('fill', cx, cy, r * 0.3)
    elseif item == 'anchor' then
        lg.circle('line', cx, cy, r * 0.6)
        lg.line(cx - r, cy, cx + r, cy)
        lg.line(cx, cy - r, cx, cy + r)
    elseif item == modes.DRAW_FREE_POLY then
        lg.polygon('line', cx - r, cy + r * 0.3, cx - r * 0.4, cy - r, cx + r * 0.6, cy - r * 0.6,
            cx + r, cy + r * 0.5, cx, cy + r * 0.8)
    elseif item == modes.DRAW_FREE_PATH then
        lg.line(cx - r, cy + r * 0.6, cx - r * 0.5, cy - r * 0.3, cx, cy + r * 0.2, cx + r * 0.5, cy - r * 0.6,
            cx + r, cy - r * 0.2)
    elseif item == modes.DRAW_CLICK then
        local pts = { cx - r, cy + r * 0.6, cx - r * 0.2, cy - r, cx + r, cy + r * 0.2 }
        lg.polygon('line', pts)
        for i = 1, #pts, 2 do lg.circle('fill', pts[i], pts[i + 1], r * 0.18) end
    elseif item == 'settings' then
        for i = 0, 7 do
            local a = i * math.pi / 4
            local c, sn = math.cos(a), math.sin(a)
            lg.line(cx + c * r * 0.55, cy + sn * r * 0.55, cx + c * r, cy + sn * r)
        end
        lg.circle('line', cx, cy, r * 0.55)
        lg.circle('fill', cx, cy, r * 0.2)
    elseif item == 'mipo' or item == 'mipo *' then
        lg.circle('line', cx, cy - r * 0.35, r * 0.45)
        lg.line(cx, cy + r * 0.1, cx, cy + r * 0.6)
        lg.line(cx - r * 0.7, cy + r * 0.25, cx + r * 0.7, cy + r * 0.25)
        lg.line(cx, cy + r * 0.6, cx - r * 0.5, cy + r)
        lg.line(cx, cy + r * 0.6, cx + r * 0.5, cy + r)
        if item == 'mipo *' then lg.print('*', cx + r * 0.5, cy - r) end
    elseif lib.groupOf(item) ~= 'shape' then
        lg.printf(item:sub(1, 4), cx - r * 2, cy - ui.font:getHeight() / 2, r * 4, 'center')
    else
        local sides = { [ST.PENTAGON] = 5, [ST.HEXAGON] = 6, [ST.HEPTAGON] = 7, [ST.OCTAGON] = 8 }
        lg.polygon('line', regularPolygon(cx, cy, r, sides[item] or 6, up))
    end
end


function lib.flyoutSize(group)
    local gap = ui.theme.spacing
    local h = gap
    for _, section in ipairs(group.sections) do
        if section.title then h = h + ui.theme.lineHeight + gap end
        h = h + math.ceil(#section / 2) * (ui.theme.button.height + gap)
    end
    if group.drawOptions then h = h + ui.theme.lineHeight + gap end
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
                    if group.onRelease then group.onRelease(item) end
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
        if group.drawOptions then group.drawOptions(x + gap, cy, w - gap * 2) end
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
            drawIcon(group.sections and lib.lastPick(group) or group.key, x + BUTTON / 2, y + BUTTON / 2,
                BUTTON * 0.3)
            if group.onPress then
                if pressed then group.onPress(lib.lastPick(group)) end
                if released and group.onRelease then group.onRelease(lib.lastPick(group)) end
            elseif clicked then
                group.onClick(lib.lastPick(group))
            end

            if group.sections then
                local isOpen = rs.open == group.key
                local tabClicked = ui.button(x + BUTTON, y, TAB, '', BUTTON,
                    isOpen and ui.theme.header.active or nil)
                love.graphics.setColor(ui.theme.button.text_default)
                local tx, ty = x + BUTTON + TAB / 2, y + BUTTON / 2
                love.graphics.polygon('fill', tx - 3, ty - 6, tx - 3, ty + 6, tx + 4, ty)
                if tabClicked then rs.open = (not isOpen) and group.key or nil end
                if rs.open == group.key then openGroup, openY = group, y end
            end
        end
    end)

    if openGroup then
        drawFlyout(openGroup, RAIL_X + railW + gap, openY)
    end
end

return lib

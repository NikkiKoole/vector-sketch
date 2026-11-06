-- floor-guide.lua — the scene's light floor shown on the stage while the settings panel's light section
-- is open and its 'floor on stage' is ticked (state.floorGuideOn, src/light-params.lua; off by default,
-- Nikki: a deep setting, not to see always), and dragged there: the line things stand on
-- (standY) and the wall's foot behind them (standY - depth), the floor the band between (src/scene-light.lua:
-- the full level's 3D shadows fall along it). Each line has a knob at the screen's middle; dragging the
-- stand line moves the whole floor, dragging the wall's foot changes the depth.
-- The drag lives on state.interaction.floorDrag (hot reload).
local lib = {}

local state = require('src.state')
local camera = require('src.camera')
local cam = camera.getInstance()
local sceneLight = require('src.scene-light')

local GRAB = 12 -- px
local ORANGE = { 242 / 255, 133 / 255, 0 } -- the UI's orange

-- the floor while the light section is open in the editor, else nil
function lib.floor()
    local pv = state.panelVisibility
    if not state.floorGuideOn then return nil end
    if not (pv and pv.worldSettingsOpened and state.settingsFolds and state.settingsFolds.light) then return nil end
    return sceneLight.settings().floor
end

-- the knobs, in the world: x at the screen's middle, on each line
local function knobs(floor)
    local w, h = love.graphics.getDimensions()
    local x = cam:getWorldCoordinates(w / 2, h / 2)
    return x, floor.standY, floor.standY - floor.depth
end

local function near(wy, ly)
    return math.abs(wy - ly) * cam:getScale() <= GRAB
end

-- a press at screen x, y: true when it grabbed a line
function lib.pressed(x, y)
    local floor = lib.floor()
    if not floor then return false end
    local _, standY, wallY = knobs(floor)
    local _, wy = cam:getWorldCoordinates(x, y)
    -- anywhere along the line (the knob shows where)
    if near(wy, standY) then
        state.interaction.floorDrag = { which = 'stand', grabY = wy, startStand = standY }
        return true
    end
    if near(wy, wallY) then
        state.interaction.floorDrag = { which = 'wall', grabY = wy, startDepth = floor.depth }
        return true
    end
    return false
end

-- the mouse moved to screen x, y: true while a line is held
function lib.moved(x, y)
    local drag = state.interaction.floorDrag
    if not drag then return false end
    local floor = sceneLight.settings().floor
    if not floor then
        state.interaction.floorDrag = nil
        return false
    end
    local _, wy = cam:getWorldCoordinates(x, y)
    local dy = wy - drag.grabY
    if drag.which == 'stand' then
        floor.standY = math.floor(drag.startStand + dy + 0.5)
    else
        floor.depth = math.max(50, math.floor(drag.startDepth - dy + 0.5)) -- up: deeper
    end
    return true
end

function lib.released()
    if not state.interaction.floorDrag then return false end
    state.interaction.floorDrag = nil
    return true
end

local function dashed(x1, x2, y, dash)
    local x = x1
    while x < x2 do
        love.graphics.line(x, y, math.min(x + dash, x2), y)
        x = x + dash * 2
    end
end

-- in world coordinates (the camera on), over the scene
function lib.draw()
    local floor = lib.floor()
    if not floor then return end
    local w, h = love.graphics.getDimensions()
    local x1, y1 = cam:getWorldCoordinates(0, 0)
    local x2 = cam:getWorldCoordinates(w, h)
    local px = 1 / cam:getScale()
    local kx, standY, wallY = knobs(floor)
    local r, g, b, a = love.graphics.getColor()
    local lineWidth = love.graphics.getLineWidth()
    -- the floor: the band between the wall's foot and where things stand
    love.graphics.setColor(ORANGE[1], ORANGE[2], ORANGE[3], 0.12)
    love.graphics.rectangle('fill', x1, wallY, x2 - x1, standY - wallY)
    love.graphics.setLineWidth(2 * px)
    love.graphics.setColor(ORANGE[1], ORANGE[2], ORANGE[3], 0.95)
    love.graphics.line(x1, standY, x2, standY)
    dashed(x1, x2, wallY, 14 * px)
    -- the knobs and their names
    local drag = state.interaction.floorDrag
    for _, line in ipairs({ { y = standY, name = 'floor: things stand here', which = 'stand' },
        { y = wallY, name = 'wall foot (depth ' .. floor.depth .. ')', which = 'wall' } }) do
        local held = drag and drag.which == line.which
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle('fill', kx, line.y, (held and 9 or 7) * px)
        love.graphics.setColor(ORANGE[1], ORANGE[2], ORANGE[3], 1)
        love.graphics.circle('line', kx, line.y, (held and 9 or 7) * px)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.print(line.name, kx + 14 * px, line.y - 22 * px, 0, px, px)
    end
    if y1 > wallY then -- off the top: say so
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.print('wall foot above the screen', kx + 14 * px, y1 + 10 * px, 0, px, px)
    end
    love.graphics.setLineWidth(lineWidth)
    love.graphics.setColor(r, g, b, a)
end

return lib

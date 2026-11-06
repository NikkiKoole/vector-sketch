-- Turn and size handles on a selected body, on the stage (editor, paused): a knob above it turns it
-- (shift: steps of 15°), a square at its corner makes it bigger or smaller, the same in every
-- direction (objectManager.scaleThing, once, on release; while dragging only its outline grows).
-- Not on Mipo parts or blobs. The drag lives on state.interaction.transformDrag (hot reload).
local lib = {}

local state = require('src.state')
local camera = require('src.camera')
local cam = camera.getInstance()
local mipoRegistry = require('src.mipo-registry')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')
local objectManager = require('src.object-manager')

local GRAB = 12        -- px: how close a press must be to a handle
local KNOB_GAP = 30    -- px: the turn knob above the body
local SNAP = math.rad(15)
local MIN_SCALE, MAX_SCALE = 0.1, 10

-- the selected body these handles work on, or nil
function lib.target()
    if not state.world.paused then return nil end
    local thing = state.selection.selectedObj
    if not thing or not thing.body or thing.body:isDestroyed() then return nil end
    if state.selection.selectedSFixture or state.polyEdit.tempVerts then return nil end
    if mipoRegistry.getFromBody(thing.body) then return nil end
    if #fixtures.sfixtureData(thing.body, subtypes.SOFTBODY) > 0 then return nil end
    return thing
end

-- the body's collision shapes, in its own frame, as polygons (a circle as 16 points)
local function localOutlines(body)
    local list = {}
    for _, fixture in ipairs(body:getFixtures()) do
        if fixture:getUserData() == nil then
            local shape = fixture:getShape()
            local kind = shape:getType()
            if kind == 'circle' then
                local cx, cy = shape:getPoint()
                local r, points = shape:getRadius(), {}
                for i = 0, 15 do
                    local a = i / 16 * math.pi * 2
                    points[#points + 1] = cx + math.cos(a) * r
                    points[#points + 1] = cy + math.sin(a) * r
                end
                list[#list + 1] = points
            elseif kind == 'polygon' or kind == 'chain' or kind == 'edge' then
                list[#list + 1] = { shape:getPoints() }
            end
        end
    end
    return list
end

local function localBounds(body)
    local minX, minY, maxX, maxY
    for _, points in ipairs(localOutlines(body)) do
        for i = 1, #points, 2 do
            local x, y = points[i], points[i + 1]
            minX, minY = math.min(minX or x, x), math.min(minY or y, y)
            maxX, maxY = math.max(maxX or x, x), math.max(maxY or y, y)
        end
    end
    return minX, minY, maxX, maxY
end

-- where the handles are, in the world: the turn knob, the size square, and the knob's stem foot
local function handlePositions(body)
    local minX, minY, maxX, maxY = localBounds(body)
    if not minX then return nil end
    local px = 1 / cam:getScale()
    local angle = body:getAngle()
    local upX, upY = math.sin(angle), -math.cos(angle) -- the body's up, in the world
    local footX, footY = body:getWorldPoint((minX + maxX) / 2, minY)
    local knobX, knobY = footX + upX * KNOB_GAP * px, footY + upY * KNOB_GAP * px
    local cornerX, cornerY = body:getWorldPoint(maxX, maxY)
    -- a little out from the corner, away from the body's middle
    local ox, oy = body:getPosition()
    local dx, dy = cornerX - ox, cornerY - oy
    local d = math.sqrt(dx * dx + dy * dy)
    if d > 0 then cornerX, cornerY = cornerX + dx / d * 8 * px, cornerY + dy / d * 8 * px end
    return { knobX = knobX, knobY = knobY, footX = footX, footY = footY, sizeX = cornerX, sizeY = cornerY }
end

local function near(ax, ay, bx, by)
    local r = GRAB / cam:getScale()
    return (ax - bx) ^ 2 + (ay - by) ^ 2 <= r * r
end

local function mouseAngle(body, wx, wy)
    local ox, oy = body:getPosition()
    return math.atan2(wy - oy, wx - ox)
end

local function mouseDist(body, wx, wy)
    local ox, oy = body:getPosition()
    return math.sqrt((wx - ox) ^ 2 + (wy - oy) ^ 2)
end

-- a press at screen x, y: true when it grabbed a handle
function lib.pressed(x, y)
    local thing = lib.target()
    if not thing then return false end
    local where = handlePositions(thing.body)
    if not where then return false end
    local wx, wy = cam:getWorldCoordinates(x, y)
    if near(wx, wy, where.knobX, where.knobY) then
        state.interaction.transformDrag = { kind = 'turn', thing = thing,
            startAngle = thing.body:getAngle(), startMouse = mouseAngle(thing.body, wx, wy) }
        return true
    end
    if near(wx, wy, where.sizeX, where.sizeY) then
        state.interaction.transformDrag = { kind = 'size', thing = thing,
            startDist = math.max(1e-3, mouseDist(thing.body, wx, wy)), factor = 1 }
        return true
    end
    return false
end

-- the mouse moved to screen x, y: true while a handle is held
function lib.moved(x, y)
    local drag = state.interaction.transformDrag
    if not drag then return false end
    local body = drag.thing.body
    if not body or body:isDestroyed() then
        state.interaction.transformDrag = nil
        return false
    end
    local wx, wy = cam:getWorldCoordinates(x, y)
    if drag.kind == 'turn' then
        local angle = drag.startAngle + (mouseAngle(body, wx, wy) - drag.startMouse)
        if love.keyboard.isDown('lshift', 'rshift') then angle = math.floor(angle / SNAP + 0.5) * SNAP end
        body:setAngle(angle)
    else
        local f = mouseDist(body, wx, wy) / drag.startDist
        drag.factor = math.max(MIN_SCALE, math.min(MAX_SCALE, f))
    end
    return true
end

-- the press let go: true when it was a handle's
function lib.released()
    local drag = state.interaction.transformDrag
    if not drag then return false end
    state.interaction.transformDrag = nil
    local thing = drag.thing
    if not thing.body or thing.body:isDestroyed() then return true end
    if drag.kind == 'size' and math.abs(drag.factor - 1) > 0.01 then
        thing = objectManager.scaleThing(thing, drag.factor)
        state.selection.selectedObj = thing
    end
    if thing.body and not thing.body:isDestroyed() then thing.body:setAwake(true) end
    return true
end

-- the handles, in world coordinates (drawn with the camera on)
function lib.draw()
    local thing = lib.target()
    if not thing then return end
    local body = thing.body
    local where = handlePositions(body)
    if not where then return end
    local px = 1 / cam:getScale()
    local r, g, b, a = love.graphics.getColor()
    local lineWidth = love.graphics.getLineWidth()
    love.graphics.setLineWidth(2 * px)
    local orange = { 242 / 255, 133 / 255, 0, 0.95 } -- the UI's orange, as the selection box

    local drag = state.interaction.transformDrag
    if drag and drag.kind == 'size' and drag.thing == thing then
        -- the outline at the size it will be
        love.graphics.setColor(orange)
        local f = drag.factor
        for _, points in ipairs(localOutlines(body)) do
            local world = {}
            for i = 1, #points, 2 do
                world[i], world[i + 1] = body:getWorldPoint(points[i] * f, points[i + 1] * f)
            end
            if #world >= 6 then love.graphics.polygon('line', world) end
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(string.format('×%.2f', f), where.sizeX + 14 * px, where.sizeY, 0, px, px)
    end
    if drag and drag.kind == 'turn' and drag.thing == thing then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(string.format('%d°', math.floor(math.deg(body:getAngle()) + 0.5)),
            where.knobX + 14 * px, where.knobY - 8 * px, 0, px, px)
    end

    -- the turn knob on its stem
    love.graphics.setColor(orange)
    love.graphics.line(where.footX, where.footY, where.knobX, where.knobY)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle('fill', where.knobX, where.knobY, 7 * px)
    love.graphics.setColor(orange)
    love.graphics.circle('line', where.knobX, where.knobY, 7 * px)
    -- the size square
    local h = 6 * px
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle('fill', where.sizeX - h, where.sizeY - h, 2 * h, 2 * h)
    love.graphics.setColor(orange)
    love.graphics.rectangle('line', where.sizeX - h, where.sizeY - h, 2 * h, 2 * h)

    love.graphics.setLineWidth(lineWidth)
    love.graphics.setColor(r, g, b, a)
end

return lib

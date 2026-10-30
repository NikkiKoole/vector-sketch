-- poly-edit.lua
-- Drawing a new polygon or path (ribbon) and editing the vertices of the selected
-- one: the editor's polygon tools, on state.interaction / state.polyEdit /
-- state.texFixtureEdit. Moved out of object-manager.lua, which makes and remakes bodies.
local logger = require('src.logger')
local mathutils = require('src.math-utils')
local utils = require('src.utils')
local state = require('src.state')
local modes = require('src.modes')
local fixtures = require('src.fixtures')
local objectManager = require('src.object-manager')
local ST = require('src.shape-types')

local lib = {}

local function segmentNormal(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then return 0, 0 end
    dx, dy = dx / len, dy / len
    -- perpendicular (left-hand normal)
    return -dy, dx
end

local function polylineRibbon(points, halfWidth)
    assert(#points >= 2, "Need at least 2 points for a ribbon")

    local left  = {}
    local right = {}

    -- compute left/right offset points for each center point
    for i, p in ipairs(points) do
        local x, y = p[1], p[2]
        local nx, ny

        if i == 1 then
            -- start: use first segment
            nx, ny = segmentNormal(x, y, points[i + 1][1], points[i + 1][2])
        elseif i == #points then
            -- end: use last segment
            nx, ny = segmentNormal(points[i - 1][1], points[i - 1][2], x, y)
        else
            -- middle: average normals of prev and next segments
            local nx1, ny1 = segmentNormal(points[i - 1][1], points[i - 1][2], x, y)
            local nx2, ny2 = segmentNormal(x, y, points[i + 1][1], points[i + 1][2])
            nx, ny = nx1 + nx2, ny1 + ny2
            local len = math.sqrt(nx * nx + ny * ny)
            if len > 0 then
                nx, ny = nx / len, ny / len
            end
        end

        left[i]  = { x - nx * halfWidth, y - ny * halfWidth }
        right[i] = { x + nx * halfWidth, y + ny * halfWidth }
    end

    -- build polygon: left side in order, right side reversed
    local verts = {}

    -- left side (forward)
    for i = 1, #left do
        table.insert(verts, left[i][1])
        table.insert(verts, left[i][2])
    end

    -- right side (backwards)
    for i = #right, 1, -1 do
        table.insert(verts, right[i][1])
        table.insert(verts, right[i][2])
    end

    return verts
end

function lib.finalizePath()
    local result = nil
    local unflat = {}
    for i = 1, #state.interaction.polyVerts, 2 do
        local pv = state.interaction.polyVerts
        table.insert(unflat, { pv[i + 0], pv[i + 1] })
    end

    if #state.interaction.polyVerts >= 6 and #unflat > 2 then
        local halfWidth = 40
        local verts = polylineRibbon(unflat, halfWidth)
        local cx, cy = mathutils.computeCentroid(state.interaction.polyVerts)

        local settings = {
            x = cx,
            y = cy,
            bodyType = state.editorPreferences.nextType,
            vertices = verts
        }
        result = objectManager.addThing(ST.RIBBON, settings)
    else
        -- Not enough vertices to form a polygon
        logger:error("Not enough vertices to create a polygon.")
    end
    modes.clear()
    state.interaction.capturingPoly = false
    state.interaction.polyVerts = {}
    state.interaction.lastPolyPt = nil
    return result
end

function lib.finalizePolygon()
    local result = nil
    if #state.interaction.polyVerts >= 6 then
        local cx, cy = mathutils.computeCentroid(state.interaction.polyVerts)
        local settings = {
            x = cx,
            y = cy,
            bodyType = state.editorPreferences.nextType,
            vertices = state.interaction
                .polyVerts
        }
        result = objectManager.addThing(ST.CUSTOM, settings)
    else
        -- Not enough vertices to form a polygon
        logger:error("Not enough vertices to create a polygon.")
    end
    -- Reset the drawing state

    modes.clear()
    state.interaction.capturingPoly = false
    state.interaction.polyVerts = {}
    state.interaction.lastPolyPt = nil
    return result
end

-- The edge of the polygon being edited nearest to world point x, y, and that point
-- in the polygon's own coordinates.
local function getClosestEdge(x, y)
    local obj = state.selection.selectedObj
    if obj then
        local offx, offy = obj.body:getPosition()
        local px, py = mathutils.worldToLocal(x - offx, y - offy, obj.body:getAngle(), state.polyEdit.centroid.x,
            state.polyEdit.centroid.y)
        local result = mathutils.findClosestEdge(state.polyEdit.tempVerts, px, py)
        return result, px, py
    end
end

function lib.insertRibbonPair(x, y)
    local edge, px, py = getClosestEdge(x, y)

    mathutils.insertValuesAt(state.polyEdit.tempVerts, edge * 2 + 1, px, py)
    local otherEdge   = (#state.polyEdit.tempVerts / 2) - edge
    local firstHalf   = edge * 2 < #state.polyEdit.tempVerts / 2
    local indexOffset = firstHalf and 0 or -1
    local other       = otherEdge + indexOffset
    local x1          = state.polyEdit.tempVerts[(other - 1) * 2 + 1]
    local y1          = state.polyEdit.tempVerts[(other - 1) * 2 + 2]
    local x2          = state.polyEdit.tempVerts[(other) * 2 + 1]
    local y2          = state.polyEdit.tempVerts[(other) * 2 + 2]
    local cx          = mathutils.lerp(x1, x2, .5)
    local cy          = mathutils.lerp(y1, y2, .5)

    mathutils.insertValuesAt(state.polyEdit.tempVerts, (otherEdge + indexOffset) * 2 + 1, cx, cy)
    return edge, px, py
end

-- A click deletes a vertex when it lands this close (polygon units)
local DELETE_RADIUS = 10

-- Is vertex `index` close enough to px, py to delete, and may the polygon lose one?
local function canDeleteVertex(index, px, py)
    local verts = state.polyEdit.tempVerts
    local dx, dy = px - verts[(index - 1) * 2 + 1], py - verts[(index - 1) * 2 + 2]
    if dx * dx + dy * dy > DELETE_RADIUS * DELETE_RADIUS then
        logger:error("No vertex close enough to delete.")
        return false
    end
    if #verts <= 6 then
        logger:error("Cannot delete vertex: A polygon must have at least three vertices.")
        return false
    end
    return true
end

function lib.removeRibbonPair(x, y)
    local edge, px, py = getClosestEdge(x, y)
    if edge and canDeleteVertex(edge, px, py) then
        local otherEdge = (#state.polyEdit.tempVerts / 2) - edge + 1
        mathutils.removeVertexAt(state.polyEdit.tempVerts, math.max(edge, otherEdge))
        mathutils.removeVertexAt(state.polyEdit.tempVerts, math.min(edge, otherEdge))
        lib.maybeUpdateCustomPolygonVertices()
    end
end

function lib.insertCustomPolygonVertex(x, y)
    local edge, px, py = getClosestEdge(x, y)
    if edge then
        mathutils.insertValuesAt(state.polyEdit.tempVerts, edge * 2 + 1, px, py)
    end
end

function lib.removeCustomPolygonVertex(x, y)
    local edge, px, py = getClosestEdge(x, y)
    if edge and canDeleteVertex(edge, px, py) then
        mathutils.removeVertexAt(state.polyEdit.tempVerts, edge)
        lib.maybeUpdateCustomPolygonVertices()
    end
end

function lib.maybeUpdateCustomPolygonVertices()
    if not utils.tablesEqualNumbers(state.polyEdit.tempVerts, state.selection.selectedObj.vertices) then
        local nx, ny = mathutils.computeCentroid(state.polyEdit.tempVerts)
        local ox, oy = mathutils.computeCentroid(state.selection.selectedObj.vertices)
        local dx = nx - ox
        local dy = ny - oy
        local body = state.selection.selectedObj.body
        local dx2, dy2 = mathutils.rotatePoint(dx, dy, 0, 0, body:getAngle())
        local oldX, oldY = body:getPosition()

        body:setPosition(oldX + dx2, oldY + dy2)

        state.selection.selectedObj = objectManager.recreateThingFromBody(body,
            { optionalVertices = state.polyEdit.tempVerts })

        state.polyEdit.tempVerts = utils.shallowCopy(state.selection.selectedObj.vertices)
        state.polyEdit.centroid = { x = nx, y = ny }
    end
end

-- The texfixture's edited corners become its shape.
function lib.maybeUpdateTexFixtureVertices()
    state.selection.selectedSFixture = fixtures.replaceShape(state.selection.selectedSFixture,
        state.texFixtureEdit.tempVerts)
end

return lib

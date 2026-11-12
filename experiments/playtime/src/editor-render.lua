-- here we just have small functions that render things for the editor
-- (not ui but active state, selection boxes that sort of thing)
--
local registry = require('src.registry')
local state = require('src.state')
local modes = require('src.modes')
local fixtures = require('src.fixtures')
local box2dDraw = require('src.physics.box2d-draw')
local mathutils = require('src.math-utils')
local camera = require('src.camera')
local cam = camera.getInstance()
local utils = require('src.utils')
local inputmanager = require('src.input-manager')
local subtypes = require('src.subtypes')
local resourceLink = require('src.resource-link')
local ST = require('src.shape-types')
local NT = require('src.node-types')
local cdt = require('src.cdt')
local colors = require('src.color')
local mipoRegistry = require('src.mipo-registry')
local lib = {}

-- Grab handles for a flat vertex array, highlighting the one under the
-- mouse. labels: 'always' prints every vertex index, 'unhovered' prints
-- only next to non-hovered handles (meta8 flow), nil prints none.
-- Shared by the polyEdit and texFixtureEdit overlays.
local function drawVertexHandles(verts, cx, cy, invZoom, labels)
    local hitR = 10 * invZoom
    for i = 1, #verts, 2 do
        local vx = verts[i]
        local vy = verts[i + 1]
        local dist = math.sqrt((cx - vx) ^ 2 + (cy - vy) ^ 2)
        local hovered = dist < hitR
        if hovered then
            love.graphics.setColor(0, 0, 0)
            love.graphics.circle('fill', vx, vy, 13 * invZoom)
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle('fill', vx, vy, 11 * invZoom)
        else
            love.graphics.setColor(0, 0, 0)
            love.graphics.setLineWidth(invZoom)
            love.graphics.circle('line', vx, vy, 12 * invZoom)
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle('line', vx, vy, 10 * invZoom)
        end
        if labels == 'always' or (labels == 'unhovered' and not hovered) then
            love.graphics.setColor(0, 0, 0)
            love.graphics.print(math.ceil(i / 2), vx, vy, 0, invZoom, invZoom)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(math.ceil(i / 2), vx - 2 * invZoom, vy - 2 * invZoom, 0, invZoom, invZoom)
        end
    end
end

-- drawGrid renders in WORLD space so it must be called inside cam:push().
-- Line width is divided by the camera scale so grid lines stay visually 1px
-- regardless of zoom.
function lib.drawGrid(color)
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(1 / cam:getScale())
    love.graphics.setColor(color[1], color[2], color[3], color[4])

    local w, h = love.graphics.getDimensions()
    local tlx, tly = cam:getWorldCoordinates(0, 0)
    local brx, bry = cam:getWorldCoordinates(w, h)
    local step = state.world.meter
    local startX = math.floor(tlx / step) * step
    local endX = math.ceil(brx / step) * step
    local startY = math.floor(tly / step) * step
    local endY = math.ceil(bry / step) * step

    for i = startX, endX, step do
        love.graphics.line(i, tly, i, bry)
    end
    for i = startY, endY, step do
        love.graphics.line(tlx, i, brx, i)
    end
    love.graphics.setLineWidth(lw)
    love.graphics.setColor(1, 1, 1)
end

-- A MESHUSERT node pair's endpoints on the body they share: a joint gives its two anchors (one per body),
-- an anchor sfixture its centre. nil, nil when the two share no body.
local function endpointsOnSharedBody(nA, nB)
    local function resolve(n)
        if n.type == NT.JOINT then
            local joint = registry.getJointByID(n.id)
            if not joint then return {} end
            local x1, y1, x2, y2 = joint:getAnchors()
            local bA, bB = joint:getBodies()
            return { { body = bA, wx = x1, wy = y1 }, { body = bB, wx = x2, wy = y2 } }
        end
        local f = registry.getSFixtureByID(n.id)
        if not f then return {} end
        local bp = f:getBody()
        local pts = { bp:getWorldPoints(f:getShape():getPoints()) }
        local cx, cy = mathutils.getCenterOfPoints(pts)
        return { { body = bp, wx = cx, wy = cy } }
    end
    local a, b = resolve(nA), resolve(nB)
    for _, ai in ipairs(a) do
        for _, bi in ipairs(b) do
            if ai.body == bi.body then return ai, bi end
        end
    end
    return nil, nil
end

-- A MESHUSERT's bone-segment influence capsules, so the user can see what `bindRadius` actually covers in
-- world space: a capsule is the set of points within `radius` of the bone segment, the influence zone
-- applySegmentWeights uses.
local function drawInfluenceCapsules(ud)
    local radius = tonumber(ud.extra.bindRadius) or 80
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(1 / cam:getScale())
    love.graphics.setColor(1.0, 0.7, 0.2, 0.7)
    local nodes = ud.extra.nodes
    for i = 1, #nodes - 1 do
        local a, b = endpointsOnSharedBody(nodes[i], nodes[i + 1])
        if a and b then
            local dx, dy = b.wx - a.wx, b.wy - a.wy
            local len = math.sqrt(dx * dx + dy * dy)
            if len > 1e-4 then
                -- Perpendicular offset, normalized. Two parallel lines forming the "tube" part.
                local nxp, nyp = -dy / len * radius, dx / len * radius
                love.graphics.line(a.wx + nxp, a.wy + nyp, b.wx + nxp, b.wy + nyp)
                love.graphics.line(a.wx - nxp, a.wy - nyp, b.wx - nxp, b.wy - nyp)
            end
            -- Rounded caps: full circles at each endpoint (simpler than arcs, slight overlap with tube
            -- lines is fine).
            love.graphics.circle('line', a.wx, a.wy, radius)
            love.graphics.circle('line', b.wx, b.wy, radius)
            -- Centerline for orientation reference.
            love.graphics.setColor(1.0, 0.7, 0.2, 0.35)
            love.graphics.line(a.wx, a.wy, b.wx, b.wy)
            love.graphics.setColor(1.0, 0.7, 0.2, 0.7)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(lw)
end

-- the selected sfixture: a small circle on its centroid (and a MESHUSERT's capsules)
local function drawSelectedSFixture()
    local fixture = state.selection.selectedSFixture
    if not fixture or fixture:isDestroyed() then return end
    local body = fixture:getBody()
    local centroid = fixtures.getCentroidOfFixture(body, fixture)
    local cwx, cwy = body:getWorldPoint(centroid[1], centroid[2])
    love.graphics.circle('line', cwx, cwy, 3)
    local ud = fixture:getUserData()
    if ud.subtype == subtypes.MESHUSERT and ud.extra.nodes and #ud.extra.nodes >= 2 then
        drawInfluenceCapsules(ud)
    end
end

-- the mouse in world coordinates, and the size a screen pixel is there (markers stay the same size on
-- screen: precise when zoomed in, not giant when zoomed out)
local function mouseInWorld()
    local mx, my = love.mouse:getPosition()
    local cx, cy = cam:getWorldCoordinates(mx, my)
    return cx, cy, 1 / cam:getScale()
end

-- the handles for dragging a custom or ribbon shape's vertices, while they're unlocked
local function drawPolyEditHandles()
    local obj = state.selection.selectedObj
    local rightShape = obj and (obj.shapeType == ST.CUSTOM or obj.shapeType == ST.RIBBON or obj.shapeType == ST.TRACK)
    if not (state.polyEdit.tempVerts and rightShape and state.polyEdit.lockedVerts == false) then return end
    local verts = mathutils.getLocalVerticesForCustomSelected(state.polyEdit.tempVerts, obj,
        state.polyEdit.centroid.x, state.polyEdit.centroid.y)
    local cx, cy, invZoom = mouseInWorld()
    drawVertexHandles(verts, cx, cy, invZoom, 'always')
end

-- the handles for a texfixture's vertices, while they're unlocked; meta8 also its four cross lines
-- (1-5, 2-8, 3-7, 4-6: the numbers for src/shape8-dict.lua, 'copy dict entry' in the panel)
local function drawTexFixtureHandles()
    local fixture = state.selection.selectedSFixture
    if not (state.texFixtureEdit.tempVerts and fixture and state.texFixtureEdit.lockedVerts == false) then return end
    local thing = utils.thingOf(fixture:getBody())
    local isMeta8 = fixture:getUserData().label == 'meta8'
    local verts = mathutils.getLocalVerticesForCustomSelected(state.texFixtureEdit.tempVerts, thing, 0, 0)
    local cx, cy, invZoom = mouseInWorld()
    drawVertexHandles(verts, cx, cy, invZoom, isMeta8 and 'unhovered' or nil)
    if isMeta8 then
        for _, pair in ipairs({ { 1, 5 }, { 2, 8 }, { 3, 7 }, { 4, 6 } }) do
            local i, j = pair[1], pair[2]
            love.graphics.line(verts[i * 2 - 1], verts[i * 2], verts[j * 2 - 1], verts[j * 2])
        end
    end
end

-- One triangle in the painter: filled in its assigned bone's / group's colour (a hovered group brighter,
-- its outline thicker), the selection over it in the target's colour, an unassigned one outlined green.
local function paintTriangle(colorOf, assigned, hovered, selected, target, x1, y1, x2, y2, x3, y3)
    if assigned then
        local r, gn, bl = colorOf(assigned)
        love.graphics.setColor(r, gn, bl, hovered and 0.85 or 0.6)
        love.graphics.polygon('fill', x1, y1, x2, y2, x3, y3)
        love.graphics.setColor(r, gn, bl, hovered and 1.0 or 0.9)
        love.graphics.setLineWidth(hovered and 3 or 1)
        love.graphics.polygon('line', x1, y1, x2, y2, x3, y3)
    end
    if selected then
        local r, gn, bl = colorOf(target)
        love.graphics.setColor(r, gn, bl, 0.85)
        love.graphics.polygon('fill', x1, y1, x2, y2, x3, y3)
    end
    if not assigned then
        love.graphics.setColor(0.2, 1.0, 0.4, 0.4)
        love.graphics.setLineWidth(1)
        love.graphics.polygon('line', x1, y1, x2, y2, x3, y3)
    end
end

-- The triangle painter (EDIT_MESH_TRIS) on the selected MESHUSERT: its triangles (on its RESOURCE's mesh)
-- painted by bone or by group (triangleGroups lives on the RESOURCE fixture), and the brush at the mouse.
local function drawTrianglePainter()
    local fixture = state.selection.selectedSFixture
    if not (modes.is(modes.EDIT_MESH_TRIS) and fixture) then return end
    local ud = fixture:getUserData()
    if not (ud and subtypes.is(ud, subtypes.MESHUSERT) and ud.label) then return end
    local mappert = resourceLink.find(ud)
    if not mappert then return end
    local mextra = mappert:getUserData().extra
    local triIdx = mextra and mextra.triangles
    local meshData = mappert:getBody():getUserData()
    local baseVerts = (mextra and mextra.meshVertices) or meshData.thing.vertices
    local polyCx, polyCy = mathutils.computeCentroid(baseVerts)
    local centeredVerts = mathutils.makePolygonRelativeToCenter(baseVerts, polyCx, polyCy)
    local worldAt = fixtures.makeMeshVertexMapper(ud.extra, centeredVerts, fixture:getBody())
    if triIdx and #triIdx >= 3 then
        local editor = state.triangleEditor
        local selSet = {}
        for _, t in ipairs(editor.selectedTriangles) do selSet[t] = true end
        local groups = (editor.paintMode or 'bones') == 'groups'
        local colorOf = groups and colors.groupColor or colors.boneColor
        local assignedTo = ud.extra.triangleBones -- (not and/or: a nil triangleGroups would fall to the bones)
        if groups then assignedTo = mextra.triangleGroups end
        local target = groups and (editor.selectedGroup or 1) or (editor.selectedBone or 1)
        for t = 1, math.floor(#triIdx / 3) do
            local i1, i2, i3 = triIdx[(t - 1) * 3 + 1], triIdx[(t - 1) * 3 + 2], triIdx[(t - 1) * 3 + 3]
            if i1 and i2 and i3 then
                local x1, y1 = worldAt(i1)
                local x2, y2 = worldAt(i2)
                local x3, y3 = worldAt(i3)
                local assigned = assignedTo and assignedTo[t]
                local hovered = groups and assigned ~= nil and assigned == editor.hoveredGroup
                paintTriangle(colorOf, assigned, hovered, selSet[t], target, x1, y1, x2, y2, x3, y3)
            end
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
    -- Brush radius at mouse cursor
    local bcx, bcy = cam:getWorldCoordinates(love.mouse.getPosition())
    love.graphics.setColor(1, 1, 0, 0.3)
    love.graphics.circle('line', bcx, bcy, tonumber(state.triangleEditor.brushSize) or 20)
    love.graphics.setColor(1, 1, 1, 1)
end

-- The editor's overlay, in this order (a part draws in the colour the one before left): the selected
-- sfixture, the selected joint's anchors, the polygon being drawn, the vertex handles of a shape or a
-- texfixture being edited, the selected bodies, the node an add-node mode would take, the shape's edited
-- outline, the triangle painter.
function lib.renderActiveEditorThings()
    drawSelectedSFixture()
    if state.selection.selectedJoint and not state.selection.selectedJoint:isDestroyed() then
        box2dDraw.drawJointAnchors(state.selection.selectedJoint)
    end
    local drawing = modes.is(modes.DRAW_CLICK) or modes.is(modes.DRAW_FREE_POLY) or modes.is(modes.DRAW_FREE_PATH)
    if drawing and #state.interaction.polyVerts >= 6 then
        love.graphics.polygon('line', state.interaction.polyVerts)
    end
    if modes.is(modes.DRAW_TRACK) and #state.interaction.polyVerts >= 4 then -- a line, its painted zones coloured
        require('src.track').drawStroke(state.interaction.polyVerts)
    end
    drawPolyEditHandles()
    drawTexFixtureHandles()
    local selected = state.selection.selectedObj
    if selected and selected.shapeType == ST.TRACK then -- its crossings: click one to swap over and under
        require('src.track').drawCrossings(selected, 1 / cam:getScale())
    end
    if state.selection.selectedBodies then
        box2dDraw.drawBodies(utils.map(state.selection.selectedBodies, function(thing) return thing.body end))
    end
    if modes.is(modes.ADD_NODE_CONNECTED_TEX) or modes.is(modes.ADD_NODE_MESHUSERT) then
        local node = inputmanager.showCloseNode()
        if node then love.graphics.rectangle('line', node[1] - 5, node[2] - 5, 10, 10) end
    end
    if state.polyEdit.tempVerts and state.selection.selectedObj then -- the shape's outline while it changes
        local verts = mathutils.getLocalVerticesForCustomSelected(state.polyEdit.tempVerts,
            state.selection.selectedObj, state.polyEdit.centroid.x, state.polyEdit.centroid.y)
        love.graphics.setColor(1, 0, 0)
        local track = state.selection.selectedObj.shapeType == ST.TRACK
        if track and not (state.selection.selectedObj.track and state.selection.selectedObj.track.closed) then
            if #verts >= 4 then love.graphics.line(verts) end -- an open track: no closing edge
        elseif #verts >= 6 then
            love.graphics.polygon('line', verts)
        end
        love.graphics.setColor(1, 1, 1)
    end
    drawTrianglePainter()
    love.graphics.setColor(1, 1, 1)
end

-- Steiner-point authoring overlay. When the selected body has
-- `thing.extraSteiner` populated, draws each point as an orange dot
-- and the would-be triangulation in green. This is the authoring
-- feedback for PLACE_STEINER mode. Steiners flow through MESHUSERT's
-- triangulation on the paired RESOURCE — they affect textured-mesh
-- detail, not body collision (by design).
-- What one box goes around: a body, or every part of the Mipo it belongs to.
local function boxBodies(body)
    local made = require('src.kinds').ofBody(body) -- a kind's instance (src/kinds.lua): all its parts
    if made then return require('src.kinds').bodies(made), made end
    local instance = mipoRegistry.getFromBody(body)
    if not instance then return { body }, nil end
    local bodies = {}
    for _, part in pairs(instance.parts) do
        if part.body and not part.body:isDestroyed() then table.insert(bodies, part.body) end
    end
    return bodies, instance
end

-- A rounded box around these bodies' collision shapes, the same thickness at any zoom.
local function drawBox(bodies, alpha, width)
    local minX, minY, maxX, maxY
    for _, body in ipairs(bodies) do
        for _, fixture in ipairs(body:getFixtures()) do
            if fixture:getUserData() == nil then -- collision shapes, not sfixtures
                local x1, y1, x2, y2 = fixture:getBoundingBox()
                minX, minY = math.min(minX or x1, x1), math.min(minY or y1, y1)
                maxX, maxY = math.max(maxX or x2, x2), math.max(maxY or y2, y2)
            end
        end
    end
    if not minX then return end
    local scale = cam:getScale()
    local pad = 8 / scale
    local r, g, b, a = love.graphics.getColor()
    local lineWidth = love.graphics.getLineWidth()
    love.graphics.setColor(242 / 255, 133 / 255, 0, alpha) -- the UI's orange
    love.graphics.setLineWidth(width / scale)
    love.graphics.rectangle('line', minX - pad, minY - pad, maxX - minX + 2 * pad, maxY - minY + 2 * pad,
        6 / scale, 6 / scale)
    love.graphics.setLineWidth(lineWidth)
    love.graphics.setColor(r, g, b, a)
end

-- The clicked part of a Mipo, thin, inside the Mipo's box (docs/KINDS.md KD3): its collision shapes' outlines.
local function drawPartOutline(body)
    local scale = cam:getScale()
    local r, g, b, a = love.graphics.getColor()
    local lineWidth = love.graphics.getLineWidth()
    love.graphics.setColor(242 / 255, 133 / 255, 0, 0.8)
    love.graphics.setLineWidth(2 / scale)
    for _, fixture in ipairs(body:getFixtures()) do
        if fixture:getUserData() == nil then
            local shape = fixture:getShape()
            if shape:type() == 'PolygonShape' then
                love.graphics.polygon('line', body:getWorldPoints(shape:getPoints()))
            elseif shape:type() == 'CircleShape' then
                local cx, cy = body:getWorldPoint(shape:getPoint())
                love.graphics.circle('line', cx, cy, shape:getRadius())
            end
        end
    end
    love.graphics.setLineWidth(lineWidth)
    love.graphics.setColor(r, g, b, a)
end

-- Boxes on the stage, whatever the view (in 'tex/body' a Mipo's own shapes
-- aren't drawn): a strong one around the selection (a whole Mipo for a Mipo
-- part), light ones around what the hovered on-stage row stands for.
function lib.renderSelectionBox()
    local thing = state.selection.selectedObj
    if thing and thing.body and not thing.body:isDestroyed() then
        local bodies, instance = boxBodies(thing.body)
        drawBox(bodies, 0.9, 3)
        if instance then drawPartOutline(thing.body) end
    end
    -- set by the on-stage list while its row is hovered; used up here so it
    -- doesn't linger once the pointer leaves
    local hovered = state.interaction.hoverBodies
    state.interaction.hoverBodies = nil
    local mipoDone = {}
    for _, body in ipairs(hovered or {}) do
        if not body:isDestroyed() then
            local bodies, instance = boxBodies(body)
            if not (instance and mipoDone[instance]) then
                if instance then mipoDone[instance] = true end
                drawBox(bodies, 0.75, 2)
            end
        end
    end
end

function lib.renderSteinerOverlay()
    local thing = state.selection.selectedObj
    if not thing or not thing.body or thing.body:isDestroyed() then return end
    if not thing.vertices or #thing.vertices < 6 then return end
    if not thing.extraSteiner or #thing.extraSteiner < 2 then return end

    local body = thing.body

    -- Polygon verts are stored in authoring-world coords; the rendered body
    -- uses `vert - centroid(thing.vertices)` as its body-local frame. Match
    -- that frame so the overlay tracks the body when it moves.
    local localPoly = mathutils.makePolygonRelativeToCenter(thing.vertices, mathutils.computeCentroid(thing.vertices))

    local meshVerts, triIdx = cdt.triangulatePolyWithSteiner(localPoly, thing.extraSteiner)

    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(1 / cam:getScale())

    if meshVerts and triIdx and #triIdx >= 3 then
        love.graphics.setColor(0.2, 0.85, 0.35, 0.85)
        for t = 1, #triIdx - 2, 3 do
            local i1, i2, i3 = triIdx[t], triIdx[t + 1], triIdx[t + 2]
            local x1, y1 = body:getWorldPoint(meshVerts[(i1 - 1) * 2 + 1], meshVerts[(i1 - 1) * 2 + 2])
            local x2, y2 = body:getWorldPoint(meshVerts[(i2 - 1) * 2 + 1], meshVerts[(i2 - 1) * 2 + 2])
            local x3, y3 = body:getWorldPoint(meshVerts[(i3 - 1) * 2 + 1], meshVerts[(i3 - 1) * 2 + 2])
            love.graphics.polygon('line', x1, y1, x2, y2, x3, y3)
        end
    end

    -- Steiner points themselves — solid orange dot with a dark border so
    -- they pop against any body color.
    local dotR = 5 / cam:getScale()
    for i = 1, #thing.extraSteiner, 2 do
        local wx, wy = body:getWorldPoint(thing.extraSteiner[i], thing.extraSteiner[i + 1])
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.circle('fill', wx, wy, dotR * 1.4)
        love.graphics.setColor(1, 0.55, 0.1, 1)
        love.graphics.circle('fill', wx, wy, dotR)
    end

    -- Brush cursor in PLACE_STEINER mode so the user knows they're hot.
    if modes.is(modes.PLACE_STEINER) then
        local mx, my = love.mouse.getPosition()
        local wx, wy = cam:getWorldCoordinates(mx, my)
        love.graphics.setColor(1, 0.55, 0.1, 0.4)
        love.graphics.circle('line', wx, wy, dotR * 1.6)
    end

    love.graphics.setLineWidth(lw)
    love.graphics.setColor(1, 1, 1, 1)
end

return lib

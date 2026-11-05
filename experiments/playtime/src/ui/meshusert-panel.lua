-- ui/meshusert-panel.lua
-- The MESHUSERT part of the sfixture panel (src/ui/sfixture-editor.lua): nodes, bind radius and
-- falloff, bind pose / spine bind / unbind (src/meshusert-bind.lua), the triangle painter (bones and
-- z-order groups, auto assign, split, clear splits, brush size) and the mesh transform sliders.
-- Split out of sfixture-editor.lua (CODE-SPLITS-2026-10.md SPLIT4).
local logger = require('src.logger')
local registry = require('src.registry')
local mathutils = require('src.math-utils')
local ui = require('src.ui.all')
local camera = require('src.camera')
local cam = camera.getInstance()
local state = require('src.state')
local modes = require('src.modes')
local resourceLink = require('src.resource-link')
local NT = require('src.node-types')
local cdt = require('src.cdt')
local meshusertBind = require('src.meshusert-bind')
local utils = require('src.utils')
local color = require('src.color')

local lib = {}

local BUTTON_HEIGHT = ui.theme.lineHeight
local ROW_WIDTH = ui.theme.rowWidth

-- Per-MESHUSERT toggle: show transform sliders (meshX/Y, scaleX/Y) even when
-- bound. They're baked into bindVerts, so toggling this on is "I want to
-- adjust and re-bind." Keyed by sfixture id.
local showTransformSliders = {}

-- Returns world x, y for a node (JOINT → midpoint of both anchors, ANCHOR → centroid).
local function nodeWorldPos(node)
    if node.type == NT.JOINT then
        local joint = registry.getJointByID(node.id)
        if not joint then return nil end
        local x1, y1, x2, y2 = joint:getAnchors()
        return (x1 + x2) / 2, (y1 + y2) / 2
    elseif node.type == NT.ANCHOR then
        local f = registry.getSFixtureByID(node.id)
        if not f then return nil end
        local pts = { f:getBody():getWorldPoints(f:getShape():getPoints()) }
        return mathutils.getCenterOfPoints(pts)
    end
end

-- Tag a set of triangle indices with a group number on the RESOURCE fixture
-- that owns this MESHUSERT's triangle list. Groups drive triangle render
-- order (lower group drawn first → behind).
function lib.assignTrianglesToGroup(meshusertFixture, triIndices, group)
    if not meshusertFixture or meshusertFixture:isDestroyed() then return end
    local ud = meshusertFixture:getUserData()
    if not ud then return end

    local mappert = resourceLink.find(ud)
    if not mappert then return end

    local mextra = mappert:getUserData().extra
    if not mextra then return end
    if not mextra.triangleGroups then mextra.triangleGroups = {} end
    for _, t in ipairs(triIndices) do
        mextra.triangleGroups[t] = group
    end
    mextra.triangleOrderDirty = true
    logger:info('Assigned ' .. #triIndices .. ' triangles to group ' .. tostring(group))
end

-- Tag a set of triangle indices with a bone (node index) on the MESHUSERT fixture.
-- Per-triangle bone overrides DQS per-vertex influences for those triangles.
function lib.assignTrianglesToBone(meshusertFixture, triIndices, boneIndex)
    if not meshusertFixture or meshusertFixture:isDestroyed() then return end
    local ud = meshusertFixture:getUserData()
    if not ud then return end
    if not ud.extra.triangleBones then ud.extra.triangleBones = {} end
    for _, t in ipairs(triIndices) do
        ud.extra.triangleBones[t] = boneIndex
    end
    logger:info('Assigned ' .. #triIndices .. ' triangles to bone ' .. tostring(boneIndex))
end

local WIDE = ROW_WIDTH + 50 -- a row's full width, past the narrow button at its end

-- === bind: nodes, radius, falloff, bind pose, spine bind, unbind ===

local function drawNodeRows(r, ud, myID)
    r.next()
    if ui.button(r.x, r.y, ROW_WIDTH, 'add node ' .. (ud.extra.nodes and #ud.extra.nodes or '')) then
        modes.set(modes.ADD_NODE_MESHUSERT)
    end
    if ui.button(r.x + ROW_WIDTH, r.y, 50, 'x ') then
        ud.extra.nodes = {}
    end
    r.next()

    -- Bind radius: how far each bone segment's influence reaches. Larger = softer falloff /
    -- more blending; smaller = tighter skin-to-bone coupling. Applied at bind time.
    local br = ui.sliderWithInput(myID .. ' bindRadius', r.x, r.y, ROW_WIDTH, 10, 500, ud.extra.bindRadius or 80)
    ui.alignedLabel(r.x, r.y, ' bindRadius')
    if br then ud.extra.bindRadius = br end
    r.next()

    -- Bind falloff: exponent on the smoothstep weight. 1 = default cubic falloff; <1 = broader
    -- blend across bones (softer seams); >1 = sharper cutoff (more rigid per-bone). Takes effect
    -- on the next `bind pose`: click it again after changing this.
    local bf = ui.sliderWithInput(myID .. ' bindFalloff', r.x, r.y, ROW_WIDTH, 0.25, 4,
        tonumber(ud.extra.bindFalloff) or 1)
    ui.alignedLabel(r.x, r.y, ' bindFalloff')
    if bf then ud.extra.bindFalloff = bf end
    r.next()

    if ui.button(r.x, r.y, ROW_WIDTH, 'bind pose') then
        meshusertBind.bindInfluences(ud, state.selection.selectedSFixture:getBody())
    end
end

-- Spine bind: instead of weights, each vertex rides the curve through its nodes
-- (docs/MESHUSERT-SPINE-BIND-PLAN.md). Multi splits the node list at repeated IDs (the root
-- anchor recurs as a chain separator, e.g. 4 limbs off one hub); each vert is hard-assigned
-- to its closest chain, so seam triangles between chains stretch on divergence.
local function drawSpineRows(r, ud, myID)
    local function spineButton(label, multi, active)
        if ui.button(r.x, r.y, ROW_WIDTH, label, BUTTON_HEIGHT, active and { 0.2, 0.7, 1.0 } or nil) then
            local bind, err = meshusertBind.bindSpine(ud, state.selection.selectedSFixture:getBody(), multi)
            if not bind then logger:error('spine-bind failed: ' .. tostring(err)) end
        end
    end
    r.next()
    local inSpineMode = ud.extra.spineBind ~= nil
    local isMulti = inSpineMode and ud.extra.spineBind.multi
    spineButton((inSpineMode and not isMulti) and 'rebind spine' or 'bind spine', false, inSpineMode and not isMulti)
    r.next()
    spineButton(isMulti and 'rebind spine (multi)' or 'bind spine (multi)', true, isMulti)

    if inSpineMode then
        r.next()
        local newBend = ui.sliderWithInput(myID .. ' spineBendiness', r.x, r.y, ROW_WIDTH, 0, 6,
            ud.extra.spineBendiness or 2)
        ui.alignedLabel(r.x, r.y, ' bendiness')
        if newBend then ud.extra.spineBendiness = math.floor(newBend + 0.5) end
    end

    -- Unbind: clear whichever mode is active. Falls back to the undeformed draw path (drawn at
    -- body transform, no deformation).
    local hasDQS = ud.extra.influences and #ud.extra.influences > 0
    if hasDQS or inSpineMode then
        r.next()
        if ui.button(r.x, r.y, ROW_WIDTH, 'unbind (reset mesh)') then
            meshusertBind.unbind(ud.extra)
        end
    end
end

-- === the triangle painter ===

-- Retriangulate the linked RESOURCE (when it has a backdrop) and drop the bone assignments:
-- the topology changed.
local function retriangulate(ud, rv, rud)
    local bd = resourceLink.backdrop(rud)
    if bd then
        cdt.computeResourceMesh(rud, rv:getBody(), bd)
    end
    meshusertBind.clearInfluences(ud.extra, true)
end

-- Split the selected triangles: a Steiner point at each one's centre, kept on the RESOURCE's
-- body (Path B) in body-local coords. allVerts may be body-local (meshVertices) or
-- authoring-world (thing.vertices, legacy saves); subtracting its own centroid normalizes
-- to body-local either way.
local function splitSelected(ud)
    local rv = resourceLink.find(ud) -- the linked RESOURCE, if any
    local rud = rv and not rv:isDestroyed() and rv:getUserData()
    if not rud then return end
    local rextra = rud.extra
    local triIdx = rextra and rextra.triangles
    local allVerts = rextra and (rextra.meshVertices or utils.thingOf(rv:getBody()).vertices)
    if not (triIdx and allVerts) then return end
    local bodyThing = utils.thingOf(rv:getBody())
    local ocenX, ocenY = mathutils.computeCentroid(allVerts)
    bodyThing.extraSteiner = bodyThing.extraSteiner or {}
    for _, t in ipairs(state.triangleEditor.selectedTriangles) do
        local i1 = triIdx[(t - 1) * 3 + 1]
        local i2 = triIdx[(t - 1) * 3 + 2]
        local i3 = triIdx[(t - 1) * 3 + 3]
        if i1 and i2 and i3 then
            local cx = (allVerts[(i1 - 1) * 2 + 1] + allVerts[(i2 - 1) * 2 + 1]
                + allVerts[(i3 - 1) * 2 + 1]) / 3 - ocenX
            local cy = (allVerts[(i1 - 1) * 2 + 2] + allVerts[(i2 - 1) * 2 + 2]
                + allVerts[(i3 - 1) * 2 + 2]) / 3 - ocenY
            bodyThing.extraSteiner[#bodyThing.extraSteiner + 1] = cx
            bodyThing.extraSteiner[#bodyThing.extraSteiner + 1] = cy
        end
    end
    retriangulate(ud, rv, rud)
end

-- the painter's on/off button; returns whether it was on when drawn
local function drawPainterToggle(r)
    local editMode = modes.is(modes.EDIT_MESH_TRIS)
    local buttonLabel = editMode and 'EDITING TRIS' or 'edit triangles'
    local buttonColor = editMode and { 0.2, 0.8, 0.2 } or nil
    if ui.button(r.x, r.y, ROW_WIDTH, buttonLabel, BUTTON_HEIGHT, buttonColor) then
        if editMode then modes.clear() else modes.set(modes.EDIT_MESH_TRIS) end
        state.triangleEditor.selectedTriangles = {}
    end
    return editMode
end

-- sub-mode tabs: paint bones or z-order groups
local function drawPaintTabs(r)
    local te = state.triangleEditor
    if not te.paintMode then te.paintMode = 'bones' end
    r.next()
    local boneTabColor  = te.paintMode == 'bones'  and { 0.2, 0.6, 1 } or nil
    local groupTabColor = te.paintMode == 'groups' and { 0.2, 0.6, 1 } or nil
    local halfW = WIDE / 2 - 1
    if ui.button(r.x, r.y, halfW, 'Bones', BUTTON_HEIGHT, boneTabColor) then
        te.paintMode = 'bones'
        te.selectedTriangles = {}
    end
    if ui.button(r.x + halfW + 2, r.y, halfW, 'Z-order', BUTTON_HEIGHT, groupTabColor) then
        te.paintMode = 'groups'
        te.selectedTriangles = {}
    end
    r.next()
end

-- how many triangles are selected, clear, split
local function drawSelectionRows(r, ud)
    local te = state.triangleEditor
    ui.label(r.x, r.y, 'Selected: ' .. #te.selectedTriangles .. ' tris')
    if #te.selectedTriangles > 0 then
        if ui.button(r.x + ROW_WIDTH, r.y, 50, 'clear') then
            te.selectedTriangles = {}
        end
    end
    r.next()
    if #te.selectedTriangles > 0 then
        if ui.button(r.x, r.y, WIDE, 'split selected') then
            splitSelected(ud)
            te.selectedTriangles = {}
        end
        r.next()
    end
end

-- A row of numbered buttons (groups or bones), the selected one in its colour; returns the
-- number under the mouse, if any.
local function drawNumberButtons(r, count, buttonW, selected, colorOf, onPick)
    local hovered
    for i = 1, count do
        local bx = r.x + (i - 1) * (buttonW + 2)
        if ui.mouseX >= bx and ui.mouseX <= bx + buttonW and ui.mouseY >= r.y and ui.mouseY <= r.y + BUTTON_HEIGHT then
            hovered = i
        end
        local col = (selected == i) and { colorOf(i) } or nil
        if ui.button(bx, r.y, buttonW, tostring(i), BUTTON_HEIGHT, col) then
            onPick(i)
        end
    end
    return hovered
end

-- TRIANGLE GROUPS: groups drive triangle render order (lower group drawn first, behind).
-- The data lives on the paired RESOURCE fixture (mextra.triangleGroups).
local function drawGroupPicker(r, ud)
    local te = state.triangleEditor
    love.graphics.line(r.x, r.y + 5, r.x + WIDE, r.y + 5)
    r.next()
    ui.label(r.x, r.y, 'Group (z-order):')
    r.next()
    -- the hovered group is published for the triangle-painter render pass in editor-render.lua,
    -- which emphasizes the triangles assigned to it
    te.hoveredGroup = drawNumberButtons(r, 8, WIDE / 8 - 2, te.selectedGroup, color.groupColor,
        function(g) te.selectedGroup = g end)
    r.next()

    if #te.selectedTriangles > 0 then
        if ui.button(r.x, r.y, WIDE, 'Assign to group ' .. te.selectedGroup) then
            lib.assignTrianglesToGroup(state.selection.selectedSFixture, te.selectedTriangles, te.selectedGroup)
            te.selectedTriangles = {}
        end
        r.next()
    end

    if ui.button(r.x, r.y, WIDE, 'clear all groups') then
        local rv = resourceLink.find(ud) -- the linked RESOURCE, if any
        local rud = rv and not rv:isDestroyed() and rv:getUserData()
        if rud then
            rud.extra.triangleGroups = nil
            rud.extra.triangleOrderDirty = true
        end
    end
    r.next()
end

-- the bone (node) under the mouse, else the selected one, ringed on stage
local function highlightBone(nodes, boneIndex)
    if not (boneIndex and nodes[boneIndex]) then return end
    local wx, wy = nodeWorldPos(nodes[boneIndex])
    if not wx then return end
    local boneR, boneG, boneB = color.boneColor(boneIndex)
    ui.onStage(function()
        local sx, sy = cam:getScreenCoordinates(wx, wy)
        love.graphics.setColor(boneR, boneG, boneB, 0.9)
        love.graphics.setLineWidth(3)
        love.graphics.circle('line', sx, sy, 18)
        love.graphics.line(sx - 24, sy, sx + 24, sy)
        love.graphics.line(sx, sy - 24, sx, sy + 24)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setLineWidth(1)
    end)
end

-- each triangle to the bone with the highest total influence weight across its 3 verts
local function autoAssignByWeight(ud)
    local influences = ud.extra.influences
    local mappert = resourceLink.find(ud)
    local triIdx = influences and mappert and mappert:getUserData().extra.triangles
    if not triIdx then return end
    local newBones = {}
    for t = 1, math.floor(#triIdx / 3) do
        local boneTotals = {}
        for corner = 0, 2 do
            for _, infl in ipairs(influences[triIdx[t * 3 - 2 + corner]] or {}) do
                boneTotals[infl.nodeIndex] = (boneTotals[infl.nodeIndex] or 0) + infl.w
            end
        end
        local bestBone, bestW = 1, -1
        for boneIdx, total in pairs(boneTotals) do
            if total > bestW then bestBone, bestW = boneIdx, total end
        end
        newBones[t] = bestBone
    end
    ud.extra.triangleBones = newBones
end

-- Each triangle's centre (where the mesh is drawn: meshusert-bind's framing, as for binding)
-- to the closest node anchor within bindRadius. Triangles outside every radius stay nil (DQS
-- fallback); fix edges by painting.
local function autoAssignByProximity(ud)
    local nodes = ud.extra.nodes
    local radius = tonumber(ud.extra.bindRadius) or 80
    local mappert = resourceLink.find(ud)
    local mextra = mappert and mappert:getUserData().extra
    local triIdx = mextra and mextra.triangles
    local wv = nodes and #nodes > 0 and triIdx
        and meshusertBind.worldVerts(ud, state.selection.selectedSFixture:getBody())
    if not wv then return end
    local newBones = {}
    for t = 1, math.floor(#triIdx / 3) do
        local tcx, tcy = 0, 0
        for corner = 0, 2 do
            local vi = triIdx[t * 3 - 2 + corner]
            tcx = tcx + wv[(vi - 1) * 2 + 1]
            tcy = tcy + wv[(vi - 1) * 2 + 2]
        end
        tcx, tcy = tcx / 3, tcy / 3
        local bestNode, bestDist = nil, math.huge
        for nj, node in ipairs(nodes) do
            for _, info in ipairs(meshusertBind.nodeLocal(node)) do
                local wx, wy = info.body:getWorldPoint(info.offx, info.offy)
                local d = math.sqrt((tcx - wx) ^ 2 + (tcy - wy) ^ 2)
                if d < bestDist then bestDist = d; bestNode = nj end
            end
        end
        if bestNode and bestDist <= radius then
            newBones[t] = bestNode
        end
    end
    ud.extra.triangleBones = newBones
end

-- BONES: one button per node. Assigning paints triangleBones on the MESHUSERT (not the
-- RESOURCE): it overrides the DQS per-vertex weights for those triangles.
local function drawBonePicker(r, ud)
    local te = state.triangleEditor
    local nodes = ud.extra.nodes
    ui.label(r.x, r.y, 'Bone:')
    r.next()
    local hoveredBone = drawNumberButtons(r, #nodes, math.min(40, WIDE / #nodes - 2), te.selectedBone,
        color.boneColor, function(b) te.selectedBone = b end)
    -- hover wins, so you see the bone you're about to pick
    highlightBone(nodes, hoveredBone or te.selectedBone)
    r.next()
    if #te.selectedTriangles > 0 then
        if ui.button(r.x, r.y, WIDE, 'Assign to bone ' .. te.selectedBone) then
            lib.assignTrianglesToBone(state.selection.selectedSFixture, te.selectedTriangles, te.selectedBone)
            te.selectedTriangles = {}
        end
        r.next()
    end
    if ui.button(r.x, r.y, WIDE, 'auto assign bones') then autoAssignByWeight(ud) end
    r.next()
    if ui.button(r.x, r.y, WIDE, 'auto assign by proximity') then autoAssignByProximity(ud) end
    r.next()
    if ui.button(r.x, r.y, WIDE, 'clear all bones') then
        ud.extra.triangleBones = nil
    end
    r.next()
end

-- Clear splits: wipes thing.extraSteiner on the RESOURCE's body and re-triangulates it
-- (Path B: the Steiner points live on the body, not the RESOURCE). Only when there are some.
local function drawClearSplits(r, ud)
    local rv = resourceLink.find(ud) -- the linked RESOURCE, if any
    local rud = rv and not rv:isDestroyed() and rv:getUserData()
    if not rud then return end
    local rBodyThing = utils.thingOf(rv:getBody())
    if not (rBodyThing.extraSteiner and #rBodyThing.extraSteiner > 0) then return end
    if ui.button(r.x, r.y, WIDE, 'clear splits (' .. #rBodyThing.extraSteiner / 2 .. ')') then
        rBodyThing.extraSteiner = nil
        retriangulate(ud, rv, rud)
    end
    r.next()
end

-- TRIANGLE PAINTER: tag triangles with a z-order group or a bone
local function drawTrianglePainter(r, ud, myID)
    r.next()
    love.graphics.line(r.x, r.y + 10, r.x + WIDE, r.y + 10)
    r.next()
    if not drawPainterToggle(r) then return end
    drawPaintTabs(r)
    drawSelectionRows(r, ud)
    if state.triangleEditor.paintMode == 'groups' then
        drawGroupPicker(r, ud)
    end
    local nodes = ud.extra.nodes
    if state.triangleEditor.paintMode == 'bones' and nodes and #nodes > 0 then
        drawBonePicker(r, ud)
    end
    drawClearSplits(r, ud)

    love.graphics.line(r.x, r.y + 5, r.x + WIDE, r.y + 5)
    r.next()
    local brushSize = ui.sliderWithInput(myID .. 'brushSize', r.x, r.y, ROW_WIDTH, 5, 100,
        state.triangleEditor.brushSize or 20)
    ui.alignedLabel(r.x, r.y, ' brush size')
    if brushSize then
        state.triangleEditor.brushSize = brushSize
    end
    r.next()
end

-- === the mesh's place: meshX/Y, scaleX/Y, rotation, z ===

local function transformSlider(r, ud, myID, key, min, max, default)
    r.next()
    local v = ui.sliderWithInput(myID .. ' ' .. key, r.x, r.y, ROW_WIDTH, min, max, ud.extra[key] or default)
    ui.alignedLabel(r.x, r.y, ' ' .. key)
    if v then ud.extra[key] = v end
end

-- meshX/Y + scaleX/Y are baked into bindVerts at bind time; after a bind they're dead until you
-- re-bind. Hidden by default once bound, behind a toggle so you can tweak + re-bind.
local function drawTransformRows(r, ud, myID)
    local isBound = ud.extra.influences and #ud.extra.influences > 0
    local showTransforms = not isBound or showTransformSliders[ud.id]
    if isBound then
        r.next()
        local label = showTransformSliders[ud.id] and 'hide transform (re-bind to apply)' or 'adjust transform'
        if ui.button(r.x, r.y, ROW_WIDTH, label) then
            showTransformSliders[ud.id] = not showTransformSliders[ud.id]
        end
    end
    if not showTransforms then return end
    transformSlider(r, ud, myID, 'meshX', -300, 300, 0)
    transformSlider(r, ud, myID, 'meshY', -300, 300, 0)
    transformSlider(r, ud, myID, 'scaleX', 0.25, 3, 1)
    transformSlider(r, ud, myID, 'scaleY', 0.25, 3, 1)
    r.next()
    local meshRotDeg = ui.sliderWithInput(myID .. ' meshRot', r.x, r.y, ROW_WIDTH, -180, 180,
        math.deg(ud.extra.meshRot or 0))
    ui.alignedLabel(r.x, r.y, ' meshRot')
    if meshRotDeg then ud.extra.meshRot = math.rad(meshRotDeg) end
    r.next()
    ui.zOffsetSlider(myID, ud.extra, r.x, r.y, ROW_WIDTH)
end

-- Draws the rows from x, y down; advance() moves to the next row and returns its x, y.
function lib.draw(ud, myID, x, y, advance)
    local r = { x = x, y = y }
    function r.next() r.x, r.y = advance() end
    drawNodeRows(r, ud, myID)
    drawSpineRows(r, ud, myID)
    drawTrianglePainter(r, ud, myID)
    drawTransformRows(r, ud, myID)
end

-- for specs (claudetools/snapshots/meshpanel_spec.lua), not part of the API
lib._test = { showTransformSliders = showTransformSliders }

return lib

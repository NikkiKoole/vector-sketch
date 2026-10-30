local lib = {}

local logger = require('src.logger')
local registry = require('src.registry')
local mathutils = require('src.math-utils')
local ui = require('src.ui.all')
local camera = require('src.camera')
local cam = camera.getInstance()
local fixtures = require('src.fixtures')
local state = require('src.state')
local modes = require('src.modes')
local subtypes = require('src.subtypes')
local resourceLink = require('src.resource-link')
local inspector = require('src.ui.inspector')
local sfixtureParams = require('src.sfixture-params')
local texfixtureParams = require('src.texfixture-params')
local NT = require('src.node-types')
local cdt = require('src.cdt')
local meshusertBind = require('src.meshusert-bind')

local PANEL_WIDTH = ui.theme.panelWidth
local BUTTON_HEIGHT = ui.theme.lineHeight
local ROW_WIDTH = ui.theme.rowWidth
local BUTTON_SPACING = ui.theme.spacing

-- Per-MESHUSERT toggle: show transform sliders (meshX/Y, scaleX/Y) even when
-- bound. They're baked into bindVerts, so toggling this on is "I want to
-- adjust and re-bind." Keyed by sfixture id.
local showTransformSliders = {}

local accordionStatesSF = {
    ['position'] = false,
    ['texture'] = true,
    ['patch1'] = false,
    ['patch2'] = false,
    ['patch3'] = false,
}

local lastSFixtureForCleanup = nil

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

-- Draw every accordion open (spec/ui-overflow_spec.lua measures the fully open panel).
local forceOpen = false
function lib.setAllAccordions(open) forceOpen = open end

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

-- panelX, panelY, panelWidth, panelH: the panel rect (default: the right edge, full height)
function lib.drawSelectedSFixture(panelX, panelY, panelWidth, panelH)
    local w, h = love.graphics.getDimensions()
    panelWidth = panelWidth or PANEL_WIDTH
    panelX, panelY, panelH = panelX or (w - panelWidth - 20), panelY or 20, panelH or (h - 40)
    if lastSFixtureForCleanup ~= state.selection.selectedSFixture then
        lastSFixtureForCleanup = state.selection.selectedSFixture
        if state.panelVisibility.showPalette then
            state.panelVisibility.showPalette = nil
            state.showPaletteFunc = nil
        end
        state.texFixtureEdit.tempVerts = nil
        state.texFixtureEdit.centroid = nil
        state.texFixtureEdit.lockedVerts = true
        state.texFixtureEdit.dragIdx = 0
    end
    if state.selection.selectedSFixture:isDestroyed() then return end
    local ud = state.selection.selectedSFixture:getUserData()

    local sfixtureType = ud.subtype or ud.type -- the panel title: what kind of fixture
    local x, y
    -- Function to create an accordion
    local function drawAccordion(key, contentFunc)
        -- Draw the accordion header

        local clicked = ui.header_button(x, y, PANEL_WIDTH - 40, (accordionStatesSF[key] and " ÷  " or " •") ..
            ' ' .. key, accordionStatesSF[key])
        if clicked then
            accordionStatesSF[key] = not accordionStatesSF[key]
        end
        y = y + BUTTON_HEIGHT + BUTTON_SPACING

        if accordionStatesSF[key] or forceOpen then
            contentFunc(clicked)
        end
    end

    local function drawContent()
        local padding = BUTTON_SPACING
        local layout = ui.createLayout({
            type = 'columns',
            spacing = BUTTON_SPACING,
            startX = panelX + 20,
            startY = panelY + ui.theme.contentTop + padding
        })
        x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
        local nextRow = function()
            x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
        end

        local myID = state.selection.selectedSFixture:getUserData().id
        -- label + destroy for every kind; the simple kinds draw all their settings
        -- from src/sfixture-params.lua, the rest keep their hand-made sections below
        local subtypeRows = sfixtureParams.bySubtype[ud.subtype]
        local rows = {}
        for _, row in ipairs(sfixtureParams.header) do rows[#rows + 1] = row end
        for _, row in ipairs(subtypeRows or {}) do rows[#rows + 1] = row end
        for _, row in ipairs(sfixtureParams.footer) do rows[#rows + 1] = row end
        local used, replaced = inspector.drawParams('sfixture_' .. tostring(myID), rows,
            state.selection.selectedSFixture, nil, x, y, 270)
        if replaced ~= nil or subtypeRows then return end
        layout.curY = y + used
        nextRow()

        if subtypes.is(ud, subtypes.TEXFIXTURE) then
            -- every setting from src/texfixture-params.lua, one inspector list per accordion
            local fixture = state.selection.selectedSFixture
            local function section(name, sectionRows)
                local gone
                drawAccordion(name, function()
                    local height, newFixture = inspector.drawParams('texfix_' .. name .. '_' .. tostring(myID),
                        sectionRows, fixture, nil, x, y, 270)
                    y = y + height
                    gone = newFixture ~= nil
                end)
                layout.curY = y
                nextRow()
                return gone
            end
            if section('position', texfixtureParams.position) then return end
            if section('texture', texfixtureParams.texture) then return end
            local e = fixture:getUserData().extra
            if e.hairs and section('hairs', texfixtureParams.hairs) then return end
            if e.plasticine and section('plasticine', texfixtureParams.plasticine) then return end
            for _, layer in ipairs({ 'patch1', 'patch2', 'patch3' }) do
                if section(layer, texfixtureParams.patch(layer)) then return end
            end
        elseif subtypes.is(ud, subtypes.MESHUSERT) then
            nextRow()
            if ui.button(x, y, ROW_WIDTH, 'add node ' .. (ud.extra.nodes and #ud.extra.nodes or '')) then
                modes.set(modes.ADD_NODE_MESHUSERT)
            end
            if ui.button(x + ROW_WIDTH, y, 50, 'x ') then
                ud.extra.nodes = {}
            end
            nextRow()

            -- Triangulation mode toggle — A/B test ear-clipping vs
            -- CDT+Steiner. Flipping it recomputes the linked RESOURCE's mesh
            -- (uvs/triangles/meshVertices) and unbinds this MESHUSERT so the
            -- user re-binds against the new topology.
            -- Bind radius: how far each bone segment's influence reaches.
            -- Larger = softer falloff / more blending; smaller = tighter
            -- skin-to-bone coupling. Applied at bind time.
            local br = ui.sliderWithInput(myID .. ' bindRadius', x, y, ROW_WIDTH, 10, 500, ud.extra.bindRadius or 80)
            ui.alignedLabel(x, y, ' bindRadius')
            if br then ud.extra.bindRadius = br end
            nextRow()

            -- Bind falloff: exponent on the smoothstep weight. 1 = default
            -- cubic falloff; <1 = broader blend across bones (softer seams);
            -- >1 = sharper cutoff (more rigid per-bone). Takes effect on
            -- next `bind pose` — click it again after changing this.
            local bf = ui.sliderWithInput(myID .. ' bindFalloff', x, y, ROW_WIDTH, 0.25, 4,
                tonumber(ud.extra.bindFalloff) or 1)
            ui.alignedLabel(x, y, ' bindFalloff')
            if bf then ud.extra.bindFalloff = bf end
            nextRow()

            if ui.button(x, y, ROW_WIDTH, 'bind pose') then
                meshusertBind.bindInfluences(ud, state.selection.selectedSFixture:getBody())
            end

            -- Spine bind: instead of weights, each vertex rides the curve through its nodes
            -- (docs/MESHUSERT-SPINE-BIND-PLAN.md); multi splits the nodes where the root repeats.
            local function spineButton(label, multi, active)
                if ui.button(x, y, ROW_WIDTH, label, BUTTON_HEIGHT, active and { 0.2, 0.7, 1.0 } or nil) then
                    local bind, err = meshusertBind.bindSpine(ud, state.selection.selectedSFixture:getBody(), multi)
                    if not bind then logger:error('spine-bind failed: ' .. tostring(err)) end
                end
            end

            nextRow()
            local inSpineMode = ud.extra.spineBind ~= nil
            local isMulti = inSpineMode and ud.extra.spineBind.multi
            local spineBtnLabel = (inSpineMode and not isMulti) and 'rebind spine' or 'bind spine'
            spineButton(spineBtnLabel, false, inSpineMode and not isMulti)

            -- Multi-chain: split the node list at repeated IDs (user's root
            -- anchor recurs as a chain separator — e.g. 4 limbs off one hub).
            -- Each vert is hard-assigned to its closest chain. Seam triangles
            -- between chains stretch on divergence — fix with soft blending.
            nextRow()
            local multiBtnLabel = isMulti and 'rebind spine (multi)' or 'bind spine (multi)'
            spineButton(multiBtnLabel, true, isMulti)

            if inSpineMode then
                nextRow()
                local newBend = ui.sliderWithInput(myID .. ' spineBendiness', x, y, ROW_WIDTH, 0, 6,
                    ud.extra.spineBendiness or 2)
                ui.alignedLabel(x, y, ' bendiness')
                if newBend then ud.extra.spineBendiness = math.floor(newBend + 0.5) end
            end

            -- Unbind: clear whichever mode is active. Falls back to the
            -- undeformed draw path (drawn at body transform, no deformation).
            local hasDQS = ud.extra.influences and #ud.extra.influences > 0
            if hasDQS or inSpineMode then
                nextRow()
                if ui.button(x, y, ROW_WIDTH, 'unbind (reset mesh)') then
                    meshusertBind.unbind(ud.extra)
                end
            end

            -- TRIANGLE PAINTER — tag triangles with a group number. Groups
            -- drive triangle render order (lower group → drawn first → behind).
            -- Data lives on the paired RESOURCE fixture (mextra.triangleGroups).
            nextRow()
            love.graphics.line(x, y + 10, x + ROW_WIDTH + 50, y + 10)
            nextRow()

            local editMode = modes.is(modes.EDIT_MESH_TRIS)
            local buttonLabel = editMode and 'EDITING TRIS' or 'edit triangles'
            local buttonColor = editMode and { 0.2, 0.8, 0.2 } or nil

            if ui.button(x, y, ROW_WIDTH, buttonLabel, BUTTON_HEIGHT, buttonColor) then
                if editMode then
                    modes.clear()
                    state.triangleEditor.selectedTriangles = {}
                else
                    modes.set(modes.EDIT_MESH_TRIS)
                    state.triangleEditor.selectedTriangles = {}
                end
            end

            if editMode then
                -- Sub-mode: bones or z-order groups
                if not state.triangleEditor.paintMode then
                    state.triangleEditor.paintMode = 'bones'
                end
                nextRow()
                local boneTabColor  = state.triangleEditor.paintMode == 'bones'  and {0.2,0.6,1} or nil
                local groupTabColor = state.triangleEditor.paintMode == 'groups' and {0.2,0.6,1} or nil
                local halfW = (ROW_WIDTH + 50) / 2 - 1
                if ui.button(x,           y, halfW, 'Bones',   BUTTON_HEIGHT, boneTabColor)  then
                    state.triangleEditor.paintMode = 'bones'
                    state.triangleEditor.selectedTriangles = {}
                end
                if ui.button(x + halfW + 2, y, halfW, 'Z-order', BUTTON_HEIGHT, groupTabColor) then
                    state.triangleEditor.paintMode = 'groups'
                    state.triangleEditor.selectedTriangles = {}
                end
                nextRow()

                ui.label(x, y, 'Selected: ' .. #state.triangleEditor.selectedTriangles .. ' tris')
                if #state.triangleEditor.selectedTriangles > 0 then
                    if ui.button(x + ROW_WIDTH, y, 50, 'clear') then
                        state.triangleEditor.selectedTriangles = {}
                    end
                end
                nextRow()

                if #state.triangleEditor.selectedTriangles > 0 then
                    if ui.button(x, y, ROW_WIDTH + 50, 'split selected') then
                        for _, rv in ipairs({ resourceLink.find(ud) }) do -- the linked RESOURCE, if any
                            if not rv:isDestroyed() then
                                local rud = rv:getUserData()
                                if rud then
                                    local rextra = rud.extra
                                    local triIdx = rextra and rextra.triangles
                                    local allVerts = rextra
                                        and (rextra.meshVertices or rv:getBody():getUserData().thing.vertices)
                                    if triIdx and allVerts then
                                        -- Path B: Steiner points live on the body in body-local
                                        -- coords. allVerts may be either body-local (new code,
                                        -- meshVertices) or authoring-world (thing.vertices or
                                        -- legacy saves); subtracting its own centroid normalizes
                                        -- to body-local either way.
                                        local bodyThing = rv:getBody():getUserData().thing
                                        local ocenX, ocenY = mathutils.computeCentroid(allVerts)
                                        bodyThing.extraSteiner = bodyThing.extraSteiner or {}
                                        for _, t in ipairs(state.triangleEditor.selectedTriangles) do
                                            local i1 = triIdx[(t - 1) * 3 + 1]
                                            local i2 = triIdx[(t - 1) * 3 + 2]
                                            local i3 = triIdx[(t - 1) * 3 + 3]
                                            if i1 and i2 and i3 then
                                                local cx = (allVerts[(i1-1)*2+1] + allVerts[(i2-1)*2+1]
                                                    + allVerts[(i3-1)*2+1]) / 3 - ocenX
                                                local cy = (allVerts[(i1-1)*2+2] + allVerts[(i2-1)*2+2]
                                                    + allVerts[(i3-1)*2+2]) / 3 - ocenY
                                                bodyThing.extraSteiner[#bodyThing.extraSteiner + 1] = cx
                                                bodyThing.extraSteiner[#bodyThing.extraSteiner + 1] = cy
                                            end
                                        end
                                        -- Re-triangulate with the new points included
                                        local bd = resourceLink.backdrop(rud)
                                        if bd then
                                            cdt.computeResourceMesh(rud, rv:getBody(), bd, mathutils)
                                        end
                                        -- Invalidate bone assignments — topology changed
                                        meshusertBind.clearInfluences(ud.extra, true) -- topology changed
                                    end
                                    break
                                end
                            end
                        end
                        state.triangleEditor.selectedTriangles = {}
                    end
                    nextRow()
                end

                if state.triangleEditor.paintMode == 'groups' then
                    love.graphics.line(x, y + 5, x + ROW_WIDTH + 50, y + 5)
                    nextRow()

                    -- Group picker: 1..8 buttons. Lower = behind.
                    ui.label(x, y, 'Group (z-order):')
                    nextRow()
                    local btnW = (ROW_WIDTH + 50) / 8 - 2
                    local hoveredGroup
                    for g = 1, 8 do
                        local isSel = (state.triangleEditor.selectedGroup == g)
                        local gbx = x + (g - 1) * (btnW + 2)
                        local isHover = ui.mouseX >= gbx and ui.mouseX <= gbx + btnW
                            and ui.mouseY >= y and ui.mouseY <= y + BUTTON_HEIGHT
                        if isHover then hoveredGroup = g end
                        local gx = ((g * 73) % 256) / 255
                        local gy = ((g * 151) % 256) / 255
                        local gz = ((g * 211) % 256) / 255
                        local col = isSel and { gx, gy, gz } or nil
                        if ui.button(gbx, y, btnW, tostring(g), BUTTON_HEIGHT, col) then
                            state.triangleEditor.selectedGroup = g
                        end
                    end
                    -- Published for the triangle-painter render pass in editor-
                    -- render.lua — emphasizes tris assigned to the hovered group.
                    state.triangleEditor.hoveredGroup = hoveredGroup
                    nextRow()

                    if #state.triangleEditor.selectedTriangles > 0 then
                        if ui.button(x, y, ROW_WIDTH + 50,
                            'Assign to group ' .. state.triangleEditor.selectedGroup) then
                            lib.assignTrianglesToGroup(
                                state.selection.selectedSFixture,
                                state.triangleEditor.selectedTriangles,
                                state.triangleEditor.selectedGroup
                            )
                            state.triangleEditor.selectedTriangles = {}
                        end
                        nextRow()
                    end

                    if ui.button(x, y, ROW_WIDTH + 50, 'clear all groups') then
                        for _, rv in ipairs({ resourceLink.find(ud) }) do -- the linked RESOURCE, if any
                            if not rv:isDestroyed() then
                                local rud = rv:getUserData()
                                if rud then
                                    rud.extra.triangleGroups = nil
                                    rud.extra.triangleOrderDirty = true
                                end
                            end
                        end
                    end
                    nextRow()
                end -- groups sub-mode

                -- Bone picker: one button per node. Assign paints triangleBones
                -- on the MESHUSERT (not RESOURCE) — overrides DQS per-vertex weights.
                local nodes = ud.extra.nodes
                if state.triangleEditor.paintMode == 'bones' and nodes and #nodes > 0 then
                    ui.label(x, y, 'Bone:')
                    nextRow()
                    local boneBtnW = math.min(40, (ROW_WIDTH + 50) / #nodes - 2)
                    local hoveredBone
                    for b = 1, #nodes do
                        local isSel = (state.triangleEditor.selectedBone == b)
                        local bx = x + (b - 1) * (boneBtnW + 2)
                        local isHover = ui.mouseX >= bx and ui.mouseX <= bx + boneBtnW
                            and ui.mouseY >= y and ui.mouseY <= y + BUTTON_HEIGHT
                        if isHover then hoveredBone = b end
                        local boneR = ((b * 97)  % 256) / 255
                        local boneG = ((b * 163) % 256) / 255
                        local boneB = ((b * 211) % 256) / 255
                        local col = isSel and { boneR, boneG, boneB } or nil
                        if ui.button(bx, y, boneBtnW, tostring(b), BUTTON_HEIGHT, col) then
                            state.triangleEditor.selectedBone = b
                        end
                    end
                    -- Highlight the hovered bone (preview) or the selected one.
                    -- Hover wins so the user sees the bone they're *about* to pick.
                    local highlightBone = hoveredBone or state.triangleEditor.selectedBone
                    if highlightBone and nodes[highlightBone] then
                        local wx, wy = nodeWorldPos(nodes[highlightBone])
                        if wx then
                            local b = highlightBone
                            local boneR = ((b * 97)  % 256) / 255
                            local boneG = ((b * 163) % 256) / 255
                            local boneB = ((b * 211) % 256) / 255
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
                    end
                    nextRow()
                    if #state.triangleEditor.selectedTriangles > 0 then
                        if ui.button(x, y, ROW_WIDTH + 50,
                            'Assign to bone ' .. state.triangleEditor.selectedBone) then
                            lib.assignTrianglesToBone(
                                state.selection.selectedSFixture,
                                state.triangleEditor.selectedTriangles,
                                state.triangleEditor.selectedBone
                            )
                            state.triangleEditor.selectedTriangles = {}
                        end
                        nextRow()
                    end
                    -- Auto-assign: each triangle goes to the bone with the
                    -- highest total influence weight across its 3 verts.
                    if ui.button(x, y, ROW_WIDTH + 50, 'auto assign bones') then
                        local influences = ud.extra.influences
                        local mappert2 = resourceLink.find(ud)
                        if influences and mappert2 then
                            local triIdx2 = mappert2:getUserData().extra.triangles
                            if triIdx2 then
                                local newBones = {}
                                local numTris2 = math.floor(#triIdx2 / 3)
                                for t = 1, numTris2 do
                                    local boneTotals = {}
                                    for corner = 0, 2 do
                                        local vi = triIdx2[t * 3 - 2 + corner]
                                        local inflList = influences[vi]
                                        if inflList then
                                            for _, infl in ipairs(inflList) do
                                                boneTotals[infl.nodeIndex] = (boneTotals[infl.nodeIndex] or 0) + infl.w
                                            end
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
                        end
                    end
                    nextRow()
                    -- Proximity-based auto-assign: triangle centroid → closest
                    -- node anchor within bindRadius. Triangles outside all radii
                    -- stay nil (DQS fallback). Use manual painting to fix edges.
                    if ui.button(x, y, ROW_WIDTH + 50, 'auto assign by proximity') then
                        local proxNodes = ud.extra.nodes
                        local radius = tonumber(ud.extra.bindRadius) or 80
                        local mappert2 = resourceLink.find(ud)
                        local mextra2 = mappert2 and mappert2:getUserData().extra
                        local triIdx2 = mextra2 and mextra2.triangles
                        -- the mesh where it's drawn (meshusert-bind: the same framing as binding)
                        local wv = proxNodes and #proxNodes > 0 and triIdx2
                            and meshusertBind.worldVerts(ud, state.selection.selectedSFixture:getBody())
                        if wv then
                            do
                                local function triCentroidWorld(t)
                                    local wcx, wcy = 0, 0
                                    for corner = 0, 2 do
                                        local vi = triIdx2[t * 3 - 2 + corner]
                                        wcx = wcx + wv[(vi - 1) * 2 + 1]
                                        wcy = wcy + wv[(vi - 1) * 2 + 2]
                                    end
                                    return wcx / 3, wcy / 3
                                end
                                local newBones = {}
                                local numTris2 = math.floor(#triIdx2 / 3)
                                for t = 1, numTris2 do
                                    local tcx, tcy = triCentroidWorld(t)
                                    local bestNode, bestDist = nil, math.huge
                                    for nj, node in ipairs(proxNodes) do
                                        for _, info in ipairs(meshusertBind.nodeLocal(node)) do
                                            local wx, wy = info.body:getWorldPoint(info.offx, info.offy)
                                            local d = math.sqrt((tcx-wx)^2 + (tcy-wy)^2)
                                            if d < bestDist then bestDist = d; bestNode = nj end
                                        end
                                    end
                                    if bestNode and bestDist <= radius then
                                        newBones[t] = bestNode
                                    end
                                end
                                ud.extra.triangleBones = newBones
                            end
                        end
                    end
                    nextRow()
                    if ui.button(x, y, ROW_WIDTH + 50, 'clear all bones') then
                        ud.extra.triangleBones = nil
                    end
                    nextRow()
                end

                -- Clear splits: wipes thing.extraSteiner on the body and re-triangulates
                -- the linked RESOURCE. (Path B: Steiners live on the body, not the RESOURCE.)
                do
                    for _, rv in ipairs({ resourceLink.find(ud) }) do -- the linked RESOURCE, if any
                        if not rv:isDestroyed() then
                            local rud = rv:getUserData()
                            if rud then
                                local rBodyThing = rv:getBody():getUserData().thing
                                if rBodyThing.extraSteiner and #rBodyThing.extraSteiner > 0 then
                                    local numSplits = #rBodyThing.extraSteiner / 2
                                    if ui.button(x, y, ROW_WIDTH + 50, 'clear splits (' .. numSplits .. ')') then
                                        rBodyThing.extraSteiner = nil
                                        local bd = resourceLink.backdrop(rud)
                                        if bd then
                                            cdt.computeResourceMesh(rud, rv:getBody(), bd, mathutils)
                                        end
                                        meshusertBind.clearInfluences(ud.extra, true) -- topology changed
                                    end
                                    nextRow()
                                end
                                break
                            end
                        end
                    end
                end

                love.graphics.line(x, y + 5, x + ROW_WIDTH + 50, y + 5)
                nextRow()

                local brushSize = ui.sliderWithInput(myID .. 'brushSize', x, y, ROW_WIDTH, 5, 100,
                    state.triangleEditor.brushSize or 20)
                ui.alignedLabel(x, y, ' brush size')
                if brushSize then
                    state.triangleEditor.brushSize = brushSize
                end
                nextRow()
            end

            -- meshX/Y + scaleX/Y are baked into bindVerts at bind time; after
            -- bind they're dead until you re-bind. Hide by default once bound,
            -- show behind a toggle so you can tweak + re-bind when you want.
            local isBound = ud.extra.influences and #ud.extra.influences > 0
            local showTransforms = not isBound or showTransformSliders[ud.id]
            if isBound then
                nextRow()
                local label = showTransformSliders[ud.id] and 'hide transform (re-bind to apply)' or 'adjust transform'
                if ui.button(x, y, ROW_WIDTH, label) then
                    showTransformSliders[ud.id] = not showTransformSliders[ud.id]
                end
            end
            if showTransforms then
                nextRow()
                local meshX = ui.sliderWithInput(myID .. ' meshX', x, y, ROW_WIDTH, -300, 300, ud.extra.meshX or 0)
                ui.alignedLabel(x, y, ' meshX')
                if meshX then ud.extra.meshX = meshX end
                nextRow()
                local meshY = ui.sliderWithInput(myID .. ' meshY', x, y, ROW_WIDTH, -300, 300, ud.extra.meshY or 0)
                ui.alignedLabel(x, y, ' meshY')
                if meshY then ud.extra.meshY = meshY end
                nextRow()
                local scaleX = ui.sliderWithInput(myID .. ' scaleX', x, y, ROW_WIDTH, 0.25, 3, ud.extra.scaleX or 1)
                ui.alignedLabel(x, y, ' scaleX')
                if scaleX then ud.extra.scaleX = scaleX end
                nextRow()
                local scaleY = ui.sliderWithInput(myID .. ' scaleY', x, y, ROW_WIDTH, 0.25, 3, ud.extra.scaleY or 1)
                ui.alignedLabel(x, y, ' scaleY')
                if scaleY then ud.extra.scaleY = scaleY end
                nextRow()
                local meshRotDeg = ui.sliderWithInput(myID .. ' meshRot', x, y, ROW_WIDTH, -180, 180,
                    math.deg(ud.extra.meshRot or 0))
                ui.alignedLabel(x, y, ' meshRot')
                if meshRotDeg then ud.extra.meshRot = math.rad(meshRotDeg) end
                nextRow()
                ui.zOffsetSlider(myID, ud.extra, x, y, ROW_WIDTH)
            end
        elseif subtypes.is(ud, subtypes.RESOURCE) then
            do
                ui.label(x, y, 'backdrop index (for uvmap)')
                nextRow()
                -- shows the backdrop with this RESOURCE's image (0: not on stage);
                -- typing another index makes that backdrop's image its picture
                local b = resourceLink.backdrop(ud)
                local shownIndex = 0
                for i, bd in ipairs(state.backdrops) do
                    if bd == b then shownIndex = i end
                end
                local numericInputText, changed = ui.textinput(myID .. 'backdropindex', x, y, 90, BUTTON_HEIGHT, ".",
                    "" .. shownIndex, true)
                local typedIndex = changed and tonumber(numericInputText)
                if typedIndex and state.backdrops[typedIndex] then
                    b = state.backdrops[typedIndex]
                    ud.extra.imageURL = b.url
                    ud.extra.selectedBGIndex = typedIndex
                end
                if b then

                    -- first we draw a YELLOW border around the backdrop
                    ui.onStage(function()
                        local x1, y1 = cam:getScreenCoordinates(b.x, b.y)
                        local x2, y2 = cam:getScreenCoordinates(b.x + b.w, b.y + b.h)
                        love.graphics.setColor(1, 1, 0)
                        love.graphics.rectangle('line', x1, y1, x2 - x1, y2 - y1)
                        love.graphics.setColor(1, 1, 1)
                    end)

                    local bod = state.selection.selectedSFixture:getBody()

                    -- UVs + triangles from `src/cdt.lua` (strip for ribbons, authored with
                    -- split points, else ear-clip), made again only when the body, the
                    -- backdrop, the outline or the splits changed
                    cdt.refreshResourceMesh(ud, bod, b)
                end
            end
            nextRow()

            -- Path B: Steiners live on the body, not the RESOURCE.
            local resBody = state.selection.selectedSFixture:getBody()
            local resBodyThing = resBody and resBody:getUserData() and resBody:getUserData().thing
            if resBodyThing and resBodyThing.extraSteiner and #resBodyThing.extraSteiner > 0 then
                local numSplits = #resBodyThing.extraSteiner / 2
                if ui.button(x, y, ROW_WIDTH + 50, 'clear splits (' .. numSplits .. ')') then
                    resBodyThing.extraSteiner = nil
                    local bd = resourceLink.backdrop(ud)
                    if bd then
                        cdt.computeResourceMesh(ud, resBody, bd, mathutils)
                    end
                end
                nextRow()
            end

            if ui.button(x, y, 50, 'c') then
                local body = state.selection.selectedSFixture:getBody()
                state.selection.selectedSFixture = fixtures.updateSFixturePosition(state.selection.selectedSFixture,
                    body:getX(), body:getY())
            end
            nextRow()
        end

        nextRow()
    end

    ui.panel(panelX, panelY, panelWidth, panelH, '∞ ' .. sfixtureType .. ' ∞', function()
        -- content scrolls when it doesn't fit (spec/ui-overflow_spec.lua)
        local header = ui.theme.panelHeader
        ui.scrollPanel('sfixture-panel', panelX, panelY + header, panelWidth, panelH - header - 5, drawContent)
    end)
end

return lib

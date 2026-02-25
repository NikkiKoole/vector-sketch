local lib = {}

local logger = require('src.logger')
local registry = require('src.registry')
local mathutils = require('src.math-utils')
local ui = require('src.ui.all')
local joints = require('src.joints')
local camera = require('src.camera')
local cam = camera.getInstance()
local utils = require('src.utils')
local fixtures = require('src.fixtures')
local snap = require('src.physics.snap')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')
local state = require('src.state')
local fileBrowser = require('src.file-browser')

local PANEL_WIDTH = 300
local BUTTON_HEIGHT = ui.theme.lineHeight
local ROW_WIDTH = 160
local BUTTON_SPACING = 10

local getCenterAndDimensions = mathutils.getCenterAndDimensions

local accordionStatesSF = {
    ['position'] = false,
    ['texture'] = true,
    ['patch1'] = false,
    ['patch2'] = false,
    ['patch3'] = false,
}

local lastSFixtureForCleanup = nil

-- Assign selected vertices to a bone with rigid or blend mode
function lib.assignVerticesToBone(fixture, vertexIndices, nodeIndex, mode, weight)
    if not fixture or fixture:isDestroyed() then return end

    local ud = fixture:getUserData()
    if not ud or not ud.extra then return end

    -- Initialize vertexAssignments if it doesn't exist
    if not ud.extra.vertexAssignments then
        ud.extra.vertexAssignments = {}
    end

    for _, vi in ipairs(vertexIndices) do
        if mode == 'rigid' then
            -- Replace all weights with single bone at 100%
            ud.extra.vertexAssignments[vi] = {
                { nodeIndex = nodeIndex, weight = 1.0 }
            }
        elseif mode == 'blend' then
            -- Add or update weight for this bone
            if not ud.extra.vertexAssignments[vi] then
                ud.extra.vertexAssignments[vi] = {}
            end

            local found = false
            for _, assignment in ipairs(ud.extra.vertexAssignments[vi]) do
                if assignment.nodeIndex == nodeIndex then
                    assignment.weight = weight
                    found = true
                    break
                end
            end

            if not found then
                table.insert(ud.extra.vertexAssignments[vi], {
                    nodeIndex = nodeIndex,
                    weight = weight
                })
            end

            -- Normalize weights so they sum to 1.0
            local sum = 0
            for _, a in ipairs(ud.extra.vertexAssignments[vi]) do
                sum = sum + a.weight
            end
            if sum > 0 then
                for _, a in ipairs(ud.extra.vertexAssignments[vi]) do
                    a.weight = a.weight / sum
                end
            end
        end
    end

    logger:info('Assigned ' .. #vertexIndices .. ' vertices to node ' .. nodeIndex .. ' (' .. mode .. ')')
end

function lib.drawSelectedSFixture()
    local panelWidth = PANEL_WIDTH
    local w, h = love.graphics.getDimensions()
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

    --  local sfixtureType = (ud and ud.extra and ud.extra.type == 'texfixture') and 'texfixture' or 'sfixture'
    local sfixtureType = ud.type .. ' ' .. (ud.subtype and ud.subtype or '')
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


        if accordionStatesSF[key] then
            contentFunc(clicked)
        end
    end




    ui.panel(w - panelWidth - 20, 20, panelWidth, h - 40, '∞ ' .. sfixtureType .. ' ∞', function()
        local padding = BUTTON_SPACING
        local layout = ui.createLayout({
            type = 'columns',
            spacing = BUTTON_SPACING,
            startX = w - panelWidth,
            startY = 100 + padding
        })
        x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
        local nextRow = function()
            x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
        end

        local myID = state.selection.selectedSFixture:getUserData().id
        local myLabel = state.selection.selectedSFixture:getUserData().label or ''
        local oldTexFixUD = state.selection.selectedSFixture:getUserData()

        local function handlePaletteAndHex(idPrefix, postFix, px, py, pw, currentHex, onColorChange, _setDirty)
            local r, g, b, a = box2dDrawTextured.hexToColor(currentHex)
            local dirty = function() oldTexFixUD.extra.dirty = true end
            local paletteShow = ui.button(px - 10, py, 20, '', BUTTON_HEIGHT, { r, g, b, a })
            if paletteShow then
                if state.panelVisibility.showPalette then
                    state.panelVisibility.showPalette = nil
                    state.showPaletteFunc = nil
                else
                    state.panelVisibility.showPalette = true
                    state.showPaletteFunc = function(color)
                        dirty()
                        onColorChange(color)
                    end
                end
            end
            local hex = ui.textinput(idPrefix .. postFix, px + 10, py, pw, BUTTON_HEIGHT, "", currentHex or '')
            if hex and hex ~= currentHex then
                oldTexFixUD.extra.dirty = true
                onColorChange(hex)
            end
            ui.label(px + 10, py, postFix, { 1, 1, 1, 0.2 })
        end

        local function handleURLInput(id, labelText, px, py, pw, currentValue, updateCallback)
            local urlShow = ui.button(px - 10, py, 20, '', BUTTON_HEIGHT, { 1, 1, 1, 0.2 })
            if urlShow then
                fileBrowser:loadFiles('/textures', { includes = '-mask' })
                --fileBrowser:loadFiles('/textures', {excludes='-mask'})
            end
            local newValue = ui.textinput(id .. labelText, px + 10, py, pw, BUTTON_HEIGHT, "", currentValue or '')
            if newValue and newValue ~= currentValue then
                updateCallback(newValue)
                oldTexFixUD.extra.dirty = true
                state.selection.selectedSFixture:setUserData(oldTexFixUD)
            end
            ui.label(px, py, labelText, { 1, 1, 1, 0.2 })
            return newValue or currentValue
        end

        local function patchTransformUI(layer)
            local oldId = myID
            myID = myID .. ':' .. layer
            ui.createSliderWithId(myID, 'r', x, y, ROW_WIDTH, 0, math.pi * 2,
                oldTexFixUD.extra[layer].r or 0,
                function(v)
                    oldTexFixUD.extra[layer].r = v
                    oldTexFixUD.extra.dirty = true
                end)

            nextRow()
            ui.createSliderWithId(myID, 'sx', x, y, 50, 0.01, 3, oldTexFixUD.extra[layer].sx or 1,
                function(v)
                    oldTexFixUD.extra[layer].sx = v
                    oldTexFixUD.extra.dirty = true
                end)

            local slx, sly = ui.sameLine()
            ui.createSliderWithId(myID, 'sy', slx, sly, 50, 0.01, 3,
                oldTexFixUD.extra[layer].sy or 1,
                function(v)
                    oldTexFixUD.extra[layer].sy = v
                    oldTexFixUD.extra.dirty = true
                end)

            nextRow()
            ui.createSliderWithId(myID, 'tx', x, y, 50, -1, 1, oldTexFixUD.extra[layer].tx or 0,
                function(v)
                    oldTexFixUD.extra[layer].tx = v
                    oldTexFixUD.extra.dirty = true
                end)

            local slx2, sly2 = ui.sameLine()
            ui.createSliderWithId(myID, 'ty', slx2, sly2, 50, -1, 1, oldTexFixUD.extra[layer].ty or 0,
                function(v)
                    oldTexFixUD.extra[layer].ty = v
                    oldTexFixUD.extra.dirty = true
                end)

            nextRow()
            myID = oldId
        end

        local function combineImageUI(layer)
            local oldId = myID
            myID = myID .. ':' .. layer
            local dirty = function() oldTexFixUD.extra.dirty = true end
            handlePaletteAndHex(myID, 'bgHex', x, y, 100, oldTexFixUD.extra[layer].bgHex,
                function(color)
                    oldTexFixUD.extra[layer].bgHex = color; oldTexFixUD.extra[layer].cached = nil
                end, dirty)
            local slx, sly = ui.sameLine(20)
            handleURLInput(myID, 'bgURL', slx, sly, 150, oldTexFixUD.extra[layer].bgURL,
                function(u)
                    oldTexFixUD.extra[layer].bgURL = u
                end)
            nextRow()
            handlePaletteAndHex(myID, 'fgHex', x, y, 100, oldTexFixUD.extra[layer].fgHex,
                function(c)
                    oldTexFixUD.extra[layer].fgHex = c; oldTexFixUD.extra[layer].cached = nil
                end, dirty)
            slx, sly = ui.sameLine(20)
            handleURLInput(myID, 'fgURL', slx, sly, 150, oldTexFixUD.extra[layer].fgURL,
                function(u) oldTexFixUD.extra[layer].fgURL = u end)
            nextRow()
            ---
            handlePaletteAndHex(myID, 'patternHex', x, y, 100, oldTexFixUD.extra[layer].pHex,
                function(color)
                    oldTexFixUD.extra[layer].pHex = color; oldTexFixUD.extra[layer].cached = nil
                end, dirty)
            slx, sly = ui.sameLine(20)
            handleURLInput(myID, 'patternURL', slx, sly, 150, oldTexFixUD.extra[layer].pURL,
                function(u) oldTexFixUD.extra[layer].pURL = u end)
            nextRow()

            ui.createSliderWithId(myID, 'pr', x, y, ROW_WIDTH, 0, math.pi * 2,
                oldTexFixUD.extra[layer].pr or 0,
                function(v)
                    oldTexFixUD.extra[layer].pr = v
                    oldTexFixUD.extra.dirty = true
                end)

            nextRow()
            ui.createSliderWithId(myID, 'psx', x, y, 50, 0.01, 3, oldTexFixUD.extra[layer].psx or 1,
                function(v)
                    oldTexFixUD.extra[layer].psx = v
                    oldTexFixUD.extra.dirty = true
                end)

            slx, sly = ui.sameLine()
            ui.createSliderWithId(myID, 'psy', slx, sly, 50, 0.01, 3,
                oldTexFixUD.extra[layer].psy or 1,
                function(v)
                    oldTexFixUD.extra[layer].psy = v
                    oldTexFixUD.extra.dirty = true
                end)

            nextRow()
            ui.createSliderWithId(myID, 'ptx', x, y, 50, -1, 1, oldTexFixUD.extra[layer].ptx or 0,
                function(v)
                    oldTexFixUD.extra[layer].ptx = v
                    oldTexFixUD.extra.dirty = true
                end)

            local slx2, sly2 = ui.sameLine()
            ui.createSliderWithId(myID, 'pty', slx2, sly2, 50, -1, 1, oldTexFixUD.extra[layer].pty or 0,
                function(v)
                    oldTexFixUD.extra[layer].pty = v
                    oldTexFixUD.extra.dirty = true
                end)

            nextRow()
            myID = oldId
        end

        local function flipWholeUI(layer)
            local dirtyX, checkedX = ui.checkbox(x, y, oldTexFixUD.extra[layer].fx == -1, 'flipx')
            if dirtyX then
                oldTexFixUD.extra[layer].fx = checkedX and -1 or 1
                oldTexFixUD.extra.dirty = true
                state.selection.selectedSFixture:setUserData(oldTexFixUD)
            end
            local slx, sly = ui.sameLine()
            local dirtyY, checkedY = ui.checkbox(slx, sly, oldTexFixUD.extra[layer].fy == -1, 'flipy')
            if dirtyY then
                oldTexFixUD.extra[layer].fy = checkedY and -1 or 1
                oldTexFixUD.extra.dirty = true
                state.selection.selectedSFixture:setUserData(oldTexFixUD)
            end

            nextRow()
        end

        local newLabel = ui.textinput(myID .. ' label', x, y, 260, BUTTON_HEIGHT, "", myLabel)
        if newLabel and newLabel ~= myLabel then
            local oldUD = utils.shallowCopy(state.selection.selectedSFixture:getUserData())
            oldUD.label = newLabel

            state.selection.selectedSFixture:setUserData(oldUD)
        end
        nextRow()


        if ui.button(x, y, ROW_WIDTH, 'destroy') then
            fixtures.destroyFixture(state.selection.selectedSFixture)
            state.selection.selectedSFixture = nil
            return
        end
        nextRow()





        if ud.subtype == 'texfixture' or ud.extra.type == 'texfixture' then
            oldTexFixUD = state.selection.selectedSFixture:getUserData()
            drawAccordion('position', function()
                if ui.button(x, y, BUTTON_HEIGHT, '∆') then
                    state.currentMode = 'positioningSFixture'
                end
                nextRow()
                local slx, sly = ui.sameLine()
                if ui.button(slx, sly, ROW_WIDTH - 100, 'c') then
                    local body = state.selection.selectedSFixture:getBody()
                    state.selection.selectedSFixture = fixtures.updateSFixturePosition(state.selection.selectedSFixture,
                        body:getX(), body:getY())
                    oldTexFixUD = state.selection.selectedSFixture:getUserData()
                    state.texFixtureEdit.tempVerts = utils.shallowCopy(oldTexFixUD.extra.vertices)
                end

                slx, sly = ui.sameLine()
                if ui.button(slx, sly, ROW_WIDTH - 100, 'd') then
                    local body = state.selection.selectedSFixture:getBody()
                    --   logger:info('should look up the native dimensions of this texture')
                    --   logger:inspect(state.selection.selectedSFixture:getUserData())
                    local _, _, bw, bh = getCenterAndDimensions(body)
                    fixtures.updateSFixtureDimensions(bw, bh)
                    oldTexFixUD = state.selection.selectedSFixture:getUserData()
                    state.texFixtureEdit.tempVerts = utils.shallowCopy(oldTexFixUD.extra.vertices)
                end

                slx, sly = ui.sameLine()
                if ui.button(slx, sly, ROW_WIDTH - 100, 'x') then
                    --  local body = state.selection.selectedSFixture:getBody()
                    --   logger:info('should look up the native dimensions of this texture')
                    --   logger:inspect(state.selection.selectedSFixture:getUserData())
                    local sfUD = state.selection.selectedSFixture:getUserData()
                    if sfUD.extra and sfUD.extra.main and sfUD.extra.main.bgURL then
                        local path = sfUD.extra.main.bgURL
                        --print('finding: ', 'textures/' .. path)
                        local info = love.filesystem.getInfo('textures/' .. path)

                        if (info and info.type ~= 'directory') then
                            local img = love.graphics.newImage('textures/' .. path)
                            if img then
                                local imgW, imgH = img:getDimensions()
                                logger:info('texture dimensions:', imgW, imgH)
                                logger:info('still nedds to update the body too!')
                                local bud = state.selection.selectedSFixture:getBody():getUserData()
                                if bud and bud.thing then
                                    if bud.thing.shapeType == 'rectangle' then
                                        bud.thing.width = imgW
                                        bud.thing.height = imgH

                                        --objectManager.recreateThingFromBody(
                                        --    state.selection.selectedSFixture:getBody(),
                                        --    bud.thing)
                                        --bud.thing.vertices = nil
                                        --bud.thing.dirty = true
                                        -- state.selection.selectedObj = objectManager.recreateThingFromBody(
                                        --     state.selection.selectedSFixture:getBody(),
                                        --     bud.thing)
                                        -- state.editorPreferences.lastUsedRadius = newRadius
                                        -- body = state.selection.selectedObj.body
                                    end
                                    logger:inspect(bud.thing)
                                end

                                fixtures.updateSFixtureDimensions(imgW, imgH)
                            end
                        end
                    end
                    -- local cx, cy, w, h = getCenterAndDimensions(body)
                    -- fixtures.updateSFixtureDimensions(w, h)
                    -- local oldTexFixUD = state.selection.selectedSFixture:getUserData()
                    -- state.texFixtureEdit.tempVerts = utils.shallowCopy(oldTexFixUD.extra.vertices)
                end
                nextRow()



                local points = oldTexFixUD.extra.vertices or { state.selection.selectedSFixture:getShape():getPoints() }
                local polyW, polyH = mathutils.getPolygonDimensions(points)

                if ui.checkbox(x, y, state.editorPreferences.showTexFixtureDim, 'dims') then
                    state.editorPreferences.showTexFixtureDim = not state.editorPreferences.showTexFixtureDim
                end
                nextRow()

                if ui.button(x, y, 200, state.texFixtureEdit.lockedVerts and 'verts locked' or 'verts unlocked') then
                    oldTexFixUD = state.selection.selectedSFixture:getUserData()
                    state.texFixtureEdit.lockedVerts = not state.texFixtureEdit.lockedVerts

                    if state.texFixtureEdit.lockedVerts == false then
                        state.texFixtureEdit.tempVerts = utils.shallowCopy(oldTexFixUD.extra.vertices)
                    else
                        state.texFixtureEdit.tempVerts = nil
                        state.texFixtureEdit.centroid = nil
                    end
                end

                slx, sly = ui.sameLine()
                if ui.button(slx, sly, 40, oldTexFixUD.extra.vertexCount or '') then
                    if oldTexFixUD.extra.vertexCount == 4 then
                        oldTexFixUD.extra.vertexCount = 8
                    elseif oldTexFixUD.extra.vertexCount == 8 then
                        oldTexFixUD.extra.vertexCount = 4
                    end
                end

                nextRow()

                if (state.editorPreferences.showTexFixtureDim) then
                    local newWidth = ui.sliderWithInput(myID .. 'texfix width', x, y, ROW_WIDTH, 1, 1000, polyW)
                    ui.alignedLabel(x, y, ' width')
                    nextRow()

                    local newHeight = ui.sliderWithInput(myID .. ' texfix height', x, y, ROW_WIDTH, 1, 1000, polyH)
                    ui.alignedLabel(x, y, ' height')
                    nextRow()

                    if newWidth and math.abs(newWidth - polyW) > 1 then
                        fixtures.updateSFixtureDimensions(newWidth, polyH)
                        polyW, polyH = mathutils.getPolygonDimensions(points)
                    end
                    if newHeight and math.abs(newHeight - polyH) > 1 then
                        fixtures.updateSFixtureDimensions(polyW, newHeight)
                    end
                end
                ui.createSliderWithId(myID, ' texfixzOffset', x, y, ROW_WIDTH, -180, 180,
                    math.floor(oldTexFixUD.extra.zOffset or 0),
                    function(v)
                        oldTexFixUD.extra.zOffset = math.floor(v)
                    end)
            end)
            nextRow()




            drawAccordion("texture", function()
                nextRow()
                local e = state.selection.selectedSFixture:getUserData().extra
                if ui.checkbox(x, y, true, (e.OMP == false or e.OMP == nil) and 'BG + FG' or 'OMP') then
                    e.OMP = not e.OMP
                end

                nextRow()


                --main patch1 patch2
                --lineart, mask, pattern



                if not e.OMP then
                    oldTexFixUD.extra.main = oldTexFixUD.extra.main or {}
                    local dirty = function() oldTexFixUD.extra.dirty = true end

                    handlePaletteAndHex(myID, 'bgHex', x, y, 100, oldTexFixUD.extra.main.bgHex,
                        function(c)
                            oldTexFixUD.extra.main.bgHex = c; oldTexFixUD.extra.main.cached = nil
                        end, dirty)
                    local slx, sly = ui.sameLine(20)
                    handleURLInput(myID, 'bgURL', slx, sly, 150, oldTexFixUD.extra.main.bgURL,
                        function(u)
                            oldTexFixUD.extra.main.bgURL = u
                        end)
                    nextRow()
                    handlePaletteAndHex(myID, 'fgHex', x, y, 100, oldTexFixUD.extra.main.fgHex,
                        function(c)
                            oldTexFixUD.extra.main.fgHex = c; oldTexFixUD.extra.main.cached = nil;
                        end, dirty)
                    slx, sly = ui.sameLine(20)
                    handleURLInput(myID, 'fgURL', slx, sly, 150, oldTexFixUD.extra.main.fgURL,
                        function(u)
                            oldTexFixUD.extra.main.fgURL = u
                        end)

                    nextRow()
                end

                if e.OMP then
                    oldTexFixUD.extra.main = oldTexFixUD.extra.main or {}

                    combineImageUI('main')
                    flipWholeUI('main')

                    local dirty = function() oldTexFixUD.extra.dirty = true end
                    handlePaletteAndHex(myID, 'maintint', x, y, 100, oldTexFixUD.extra.main.tint,
                        function(color) oldTexFixUD.extra.main.tint = color end, dirty)
                end
            end)
            nextRow()

            local function drawPatchAccordion(layer)
                drawAccordion(layer, function()
                    oldTexFixUD.extra[layer] = oldTexFixUD.extra[layer] or {}
                    nextRow()
                    combineImageUI(layer)
                    nextRow()
                    patchTransformUI(layer)
                    flipWholeUI(layer)
                    local dirty = function() oldTexFixUD.extra.dirty = true end
                    handlePaletteAndHex(myID, layer .. 'tint', x, y, 100, oldTexFixUD.extra[layer].tint,
                        function(color) oldTexFixUD.extra[layer].tint = color end, dirty)
                end)
            end
            drawPatchAccordion('patch1')
            nextRow()
            drawPatchAccordion('patch2')
            nextRow()
            drawPatchAccordion('patch3')
        elseif ud.subtype == 'meshusert' then
            nextRow()
            if ui.button(x, y, ROW_WIDTH, 'add node ' .. (ud.extra.nodes and #ud.extra.nodes or '')) then
                state.currentMode = 'addNodeToMeshUsert'
            end
            if ui.button(x + ROW_WIDTH, y, 50, 'x ') then
                ud.extra.nodes = {}
            end
            nextRow()




            if ui.button(x, y, ROW_WIDTH, 'bind pose') then
                local label = ud.label or ""


                -- todo extract this!!
                local mappert
                for _, v in pairs(registry.sfixtures) do
                    if not v:isDestroyed() then
                        local vud = v:getUserData()

                        if (#vud.label > 0 and label == vud.label and vud.subtype == 'resource') then
                            mappert = v
                        end
                    end
                end



                --print(label, mappert)
                if mappert then
                    -- mappert is a thing completely outside of my body,
                    -- it's just a place where the mesh is stored.
                    local mb = mappert:getBody()
                    local mud = mb:getUserData()
                    local verts = mud.thing.vertices -- this is the original mesh.

                    logger:info("**")

                    local vx, vy = mathutils.getCenterOfPoints(verts)
                    verts = mathutils.makePolygonRelativeToCenter(verts, vx, vy)

                    if ud.extra.meshX or ud.extra.meshY then
                        verts = mathutils.transformPolygonPoints(verts, ud.extra.meshX or 0, ud.extra.meshY or 0)
                    end
                    if ud.extra.scaleX or ud.extra.scaleY then
                        verts = mathutils.scalePolygonPoints(verts, ud.extra.scaleX or 1, ud.extra.scaleY or 1)
                    end
                    -- convert LOCAL verts -> WORLD verts
                    local function vertsToWorld(body, localVerts)
                        local out = {}
                        for i = 1, #localVerts, 2 do
                            local lx, ly = localVerts[i], localVerts[i + 1]
                            local wx, wy = body:getWorldPoint(lx, ly)
                            out[#out + 1] = wx
                            out[#out + 1] = wy
                        end
                        return out
                    end
                    local function getNodeLocal(node)
                        if node.type == "joint" then
                            local joint = registry.getJointByID(node.id)
                            if not joint then return {} end

                            local x1, y1, x2, y2 = joint:getAnchors() -- world anchors
                            local bodyA, bodyB = joint:getBodies()

                            -- local positions of each anchor in its own body frame
                            local ax, ay = bodyA:getLocalPoint(x1, y1)
                            local bx, by = bodyB:getLocalPoint(x2, y2)

                            return {
                                {
                                    body = bodyA,
                                    offx = ax,
                                    offy = ay,
                                    type = "joint",
                                    id = node.id,
                                    side = "A",
                                },
                                {
                                    body = bodyB,
                                    offx = bx,
                                    offy = by,
                                    type = "joint",
                                    id = node.id,
                                    side = "B",
                                }
                            }
                        end

                        if node.type == "anchor" then
                            local f = registry.getSFixtureByID(node.id)
                            if not f then return {} end

                            local bp = f:getBody()
                            local pts = { bp:getWorldPoints(f:getShape():getPoints()) }
                            local centerX, centerY = mathutils.getCenterOfPoints(pts)

                            local lx, ly = bp:getLocalPoint(centerX, centerY)

                            return {
                                {
                                    body = bp,
                                    offx = lx,
                                    offy = ly,
                                    type = "anchor",
                                    id = node.id,
                                }
                            }
                        end

                        return {}
                    end
                    local function computeInfluences(worldVerts, nodes)
                        local influences = {}
                        local numVerts = #worldVerts / 2

                        for vi = 1, numVerts do
                            local wx = worldVerts[(vi - 1) * 2 + 1]
                            local wy = worldVerts[(vi - 1) * 2 + 2]
                            influences[vi] = {}

                            for nj = 1, #nodes do
                                local node = nodes[nj]
                                local infos = getNodeLocal(node)

                                for _, info in ipairs(infos) do
                                    local bb = info.body

                                    local lx, ly = bb:getLocalPoint(wx, wy)
                                    local dx = lx - info.offx
                                    local dy = ly - info.offy
                                    local dist = math.sqrt(dx * dx + dy * dy)

                                    influences[vi][#influences[vi] + 1] = {
                                        nodeIndex = nj,
                                        body      = bb,        -- IMPORTANT but not wanetd here, atleast do not save it
                                        offx      = info.offx, -- bind pose anchor local
                                        offy      = info.offy,
                                        nodeType  = info.type,
                                        nodeId    = info.id,
                                        side      = info.side, -- nil for anchors, "A"/"B" for joints
                                        dx        = dx,
                                        dy        = dy,
                                        dist      = dist,
                                        w         = 0,
                                    }
                                end
                            end
                        end

                        return influences
                    end
                    local function applyWeights(influences, params)
                        local eps = params and params.eps or 1e-6
                        local mode = params and params.mode or "inverse"
                        local sigma = params and params.sigma or 0.5
                        local R = params and params.R or 1.0

                        for vi = 1, #influences do
                            local infl = influences[vi]

                            local sum = 0
                            for k = 1, #infl do
                                local d = infl[k].dist
                                local wt
                                if mode == "inverse" then
                                    wt = 1 / (d + eps)
                                elseif mode == "gaussian" then
                                    wt = math.exp(-(d * d) / (2 * sigma * sigma))
                                elseif mode == "linear" then
                                    wt = (d < R) and (1 - d / R) or 0
                                end
                                infl[k].w = wt
                                sum = sum + wt
                            end

                            if sum > 0 then
                                for k = 1, #infl do
                                    infl[k].w = infl[k].w / sum
                                end
                            end
                        end

                        return influences
                    end
                    local function pruneTopK(influences, K)
                        for vi = 1, #influences do
                            table.sort(influences[vi], function(a, b) return a.w > b.w end)
                            while #influences[vi] > K do table.remove(influences[vi]) end

                            local sum = 0
                            for k = 1, #influences[vi] do sum = sum + influences[vi][k].w end
                            if sum > 0 then
                                for k = 1, #influences[vi] do influences[vi][k].w = influences[vi][k].w / sum end
                            end
                        end
                        return influences
                    end
                    --logger:inspect(vertsToWorld(b, verts))
                    verts = vertsToWorld(mb, verts)

                    if ud.extra.nodes and #ud.extra.nodes > 0 then
                        local influences = computeInfluences(verts, ud.extra.nodes)
                        influences = applyWeights(influences)

                        -- optional but highly recommended:
                        influences = pruneTopK(influences, 3)

                        ud.extra.influences = influences -- STORE IT
                        --logger:inspect(influences)
                    end
                end
            end


            -- VERTEX ASSIGNMENT UI
            nextRow()
            love.graphics.line(x, y + 10, x + ROW_WIDTH + 50, y + 10)
            nextRow()

            local editMode = state.currentMode == 'editMeshVertices'
            local buttonLabel = editMode and 'EDITING' or 'edit vertices'
            local buttonColor = editMode and { 0.2, 0.8, 0.2 } or nil

            if ui.button(x, y, ROW_WIDTH, buttonLabel, BUTTON_HEIGHT, buttonColor) then
                if editMode then
                    state.currentMode = nil
                    state.vertexEditor.selectedVertices = {}
                else
                    state.currentMode = 'editMeshVertices'
                    state.vertexEditor.selectedVertices = {}
                end
            end

            if editMode then
                nextRow()
                ui.label(x, y, 'Selected: ' .. #state.vertexEditor.selectedVertices .. ' vertices')

                -- Clear selection button
                if #state.vertexEditor.selectedVertices > 0 then
                    if ui.button(x + ROW_WIDTH, y, 50, 'clear') then
                        state.vertexEditor.selectedVertices = {}
                    end
                end

                nextRow()
                love.graphics.line(x, y + 5, x + ROW_WIDTH + 50, y + 5)
                nextRow()

                -- Bone selection
                if ud.extra.nodes and #ud.extra.nodes > 0 then
                    ui.label(x, y, 'Assign to bone:')
                    nextRow()

                    for i = 1, #ud.extra.nodes do
                        local node = ud.extra.nodes[i]
                        local isSelected = (state.vertexEditor.selectedBone == i)
                        local nodeLabel = 'Node ' .. i .. ' (' .. (node.type or '?') .. ')'
                        local nodeColor = isSelected and { 0.3, 0.6, 1.0 } or nil

                        if ui.button(x, y, ROW_WIDTH + 50, nodeLabel, BUTTON_HEIGHT, nodeColor) then
                            state.vertexEditor.selectedBone = i
                        end
                        nextRow()
                    end

                    nextRow()
                    love.graphics.line(x, y + 5, x + ROW_WIDTH + 50, y + 5)
                    nextRow()

                    -- Assignment mode buttons
                    ui.label(x, y, 'Assignment mode:')
                    nextRow()

                    local rigidColor = (state.vertexEditor.assignmentMode == 'rigid') and { 0.8, 0.3, 0.3 } or nil
                    if ui.button(x, y, (ROW_WIDTH + 50) / 2 - 5, 'Rigid (100%)', BUTTON_HEIGHT, rigidColor) then
                        state.vertexEditor.assignmentMode = 'rigid'
                    end

                    local blendColor = (state.vertexEditor.assignmentMode == 'blend') and { 0.3, 0.8, 0.3 } or nil
                    if ui.button(x + (ROW_WIDTH + 50) / 2 + 5, y,
                        (ROW_WIDTH + 50) / 2 - 5, 'Blend', BUTTON_HEIGHT, blendColor) then
                        state.vertexEditor.assignmentMode = 'blend'
                    end
                    nextRow()

                    -- Blend weight slider (only show in blend mode)
                    if state.vertexEditor.assignmentMode == 'blend' then
                        local weight = ui.sliderWithInput(myID .. 'blendWeight', x, y, ROW_WIDTH, 0, 1,
                            state.vertexEditor.blendWeight or 0.5)
                        ui.alignedLabel(x, y, ' weight')
                        if weight then
                            state.vertexEditor.blendWeight = weight
                        end
                        nextRow()
                    end

                    -- Apply assignment button
                    if #state.vertexEditor.selectedVertices > 0 then
                        local applyLabel = state.vertexEditor.assignmentMode == 'rigid'
                            and 'Apply Rigid'
                            or 'Add Blend (' .. string.format("%.2f", state.vertexEditor.blendWeight) .. ')'

                        if ui.button(x, y, ROW_WIDTH + 50, applyLabel) then
                            -- Apply the assignment
                            lib.assignVerticesToBone(
                                state.selection.selectedSFixture,
                                state.vertexEditor.selectedVertices,
                                state.vertexEditor.selectedBone,
                                state.vertexEditor.assignmentMode,
                                state.vertexEditor.blendWeight
                            )
                        end
                        nextRow()
                    end

                    nextRow()
                    love.graphics.line(x, y + 5, x + ROW_WIDTH + 50, y + 5)
                    nextRow()

                    -- Brush size for selection
                    local brushSize = ui.sliderWithInput(myID .. 'brushSize', x, y, ROW_WIDTH, 5, 100,
                        state.vertexEditor.brushSize or 20)
                    ui.alignedLabel(x, y, ' brush size')
                    if brushSize then
                        state.vertexEditor.brushSize = brushSize
                    end
                    nextRow()
                else
                    ui.label(x, y, 'Add nodes first!')
                    nextRow()
                end
            end

            nextRow()
            local meshX = ui.sliderWithInput(myID .. ' meshX', x, y, ROW_WIDTH, -300, 300, ud.extra.meshX or 0)
            ui.alignedLabel(x, y, ' meshX')

            if meshX then
                ud.extra.meshX = meshX
            end
            nextRow()
            local meshY = ui.sliderWithInput(myID .. ' meshY', x, y, ROW_WIDTH, -300, 300, ud.extra.meshY or 0)
            ui.alignedLabel(x, y, ' meshY')

            if meshY then
                ud.extra.meshY = meshY
            end
            nextRow()
            local scaleX = ui.sliderWithInput(myID .. ' scaleX', x, y, ROW_WIDTH, 0.25, 3, ud.extra.scaleX or 1)
            ui.alignedLabel(x, y, ' scaleX')

            if scaleX then
                ud.extra.scaleX = scaleX
            end
            nextRow()
            local scaleY = ui.sliderWithInput(myID .. ' scaleY', x, y, ROW_WIDTH, 0.25, 3, ud.extra.scaleY or 1)
            ui.alignedLabel(x, y, ' scaleY')

            if scaleY then
                ud.extra.scaleY = scaleY
            end
        elseif ud.subtype == 'resource' then
            local selectedIndex
            if #state.backdrops then
                ui.label(x, y, 'backdrop index (for uvmap)')
                nextRow()
                local numericInputText = ui.textinput(myID .. 'backdropindex', x, y, 90, BUTTON_HEIGHT, ".",
                    "" .. (ud.extra.selectedBGIndex or 0),
                    true)
                selectedIndex = tonumber(numericInputText)
                ud.extra.selectedBGIndex = selectedIndex
                if selectedIndex and selectedIndex >= 1 and selectedIndex <= #state.backdrops then
                    local b = state.backdrops[selectedIndex]

                    -- first we draw a YELLOW border around the backdrop
                    local x1, y1 = cam:getScreenCoordinates(b.x, b.y)
                    local x2, y2 = cam:getScreenCoordinates(b.x + b.w, b.y + b.h)
                    love.graphics.setColor(1, 1, 0)
                    love.graphics.rectangle('line', x1, y1, x2 - x1, y2 - y1)
                    love.graphics.setColor(1, 1, 1)

                    local bod = state.selection.selectedSFixture:getBody()
                    local bud = bod:getUserData()
                    local centerX, centerY = mathutils.getCenterOfPoints(bud.thing.vertices)
                    local verts = {}

                    for i = 1, #bud.thing.vertices, 2 do
                        verts[i] = bud.thing.vertices[i] - centerX
                        verts[i + 1] = bud.thing.vertices[i + 1] - centerY
                    end
                    -- love.graphics.polygon('line', verts)
                    -- now we also draw the backdrop bbox in that space
                    local x1l, y1l = bod:getLocalPoint(b.x, b.y)
                    local x2l, y2l = bod:getLocalPoint(b.x + b.w, b.y + b.h)
                    local rectW, rectH = x2l - x1l, y2l - y1l

                    -- love.graphics.rectangle('line', x1l, y1l, w, h)
                    --  love.graphics.pop()

                    -- vertices assumed to be world-space positions of the poly
                    local function normalizeUVsFromRect(polyVerts, rect)
                        local t = {}
                        for i = 1, #polyVerts, 2 do
                            local vx = polyVerts[i]
                            local vy = polyVerts[i + 1]

                            local u = (vx - rect.x) / rect.w
                            local v = (vy - rect.y) / rect.h

                            table.insert(t, u)
                            table.insert(t, v)
                        end
                        return t
                    end

                    local uvs = normalizeUVsFromRect(verts, { x = x1l, y = y1l, w = rectW, h = rectH })
                    --logger:inspect(uvs)
                    ud.extra.uvs = uvs
                end
            end

            if ui.button(x + 100, y, ROW_WIDTH * 0.75, 'bind-pose') then
                logger:info('here we do nothing...')
                --print('first we figure out if we are over a background.')
                -- lets just persist an index into bg
                -- TODO: implement bind-pose for resource sfixtures
            end
            local slx, sly = ui.sameLine()
            if ui.button(slx, sly, 50, 'c') then
                local body = state.selection.selectedSFixture:getBody()
                state.selection.selectedSFixture = fixtures.updateSFixturePosition(state.selection.selectedSFixture,
                    body:getX(), body:getY())
                --local oldTexFixUD = state.selection.selectedSFixture:getUserData()
                --state.texFixtureEdit.tempVerts = utils.shallowCopy(oldTexFixUD.extra.vertices)
            end
            nextRow()
            ui.label(x, y, 'global mesh ftw!')
        else
            drawAccordion('position', function()
                nextRow()
                if ui.button(x, y, BUTTON_HEIGHT, '∆') then
                    state.currentMode = 'positioningSFixture'
                end
                local slx, sly = ui.sameLine()
                if ui.button(slx, sly, ROW_WIDTH - 100, 'c') then
                    local body = state.selection.selectedSFixture:getBody()
                    state.selection.selectedSFixture = fixtures.updateSFixturePosition(state.selection.selectedSFixture,
                        body:getX(), body:getY())

                    oldTexFixUD = state.selection.selectedSFixture:getUserData()
                    if (oldTexFixUD.extra.vertices) then
                        state.texFixtureEdit.tempVerts = utils.shallowCopy(oldTexFixUD.extra.vertices)
                    end
                end

                nextRow()

                local points = { state.selection.selectedSFixture:getShape():getPoints() }
                local dim = mathutils.getPolygonDimensions(points)
                local newRadius = ui.sliderWithInput(myID .. ' radius', x, y, ROW_WIDTH, 1, 200, dim)
                ui.alignedLabel(x, y, ' radius')
                if newRadius and newRadius ~= dim then
                    fixtures.updateSFixtureDimensions(newRadius, newRadius)
                    snap.rebuildSnapFixtures(registry.sfixtures)
                end

                nextRow()
                local function handleOffset(xMultiplier, yMultiplier)
                    local body = state.selection.selectedSFixture:getBody()
                    local parentVerts = body:getUserData().thing.vertices
                    local sfPoints = { state.selection.selectedSFixture:getShape():getPoints() }
                    local centerX, centerY = mathutils.getCenterOfPoints(sfPoints)
                    local bounds = mathutils.getBoundingRect(parentVerts)
                    local relativePoints = mathutils.makePolygonRelativeToCenter(sfPoints, centerX, centerY)
                    local newShape = mathutils.makePolygonAbsolute(relativePoints,
                        ((bounds.width / 2) * xMultiplier),
                        ((bounds.height / 2) * yMultiplier))

                    local oldUD = utils.shallowCopy(state.selection.selectedSFixture:getUserData())
                    state.selection.selectedSFixture:destroy()

                    local shape = love.physics.newPolygonShape(newShape)
                    local newfixture = love.physics.newFixture(body, shape)
                    newfixture:setSensor(true) -- Sensor so it doesn't collide
                    newfixture:setUserData(oldUD)
                    state.selection.selectedSFixture = newfixture
                end

                if state.selection.selectedSFixture:getUserData().subtype ~= 'texfixture' then
                    if ui.button(x, y, 40, 'N') then
                        handleOffset(0, -1)
                    end
                    slx, sly = ui.sameLine()
                    if ui.button(slx, sly, 40, 'E') then
                        handleOffset(1, 0)
                    end
                    slx, sly = ui.sameLine()
                    if ui.button(slx, sly, 40, 'S') then
                        handleOffset(0, 1)
                    end
                    slx, sly = ui.sameLine()
                    if ui.button(slx, sly, 40, 'W') then
                        handleOffset(-1, 0)
                    end
                    slx, sly = ui.sameLine()
                    if ui.button(slx, sly, 40, 'C') then
                        handleOffset(0, 0)
                    end
                end
            end)

            local oldUD = utils.shallowCopy(state.selection.selectedSFixture:getUserData())
            if oldUD.label == 'connected-texture' or oldUD.subtype == 'connected-texture' then
                oldTexFixUD.extra.main = oldTexFixUD.extra.main or {}
                if ui.button(x, y, ROW_WIDTH, 'add node ' .. (oldUD.extra.nodes and #oldUD.extra.nodes or '')) then
                    state.currentMode = 'addNodeToConnectedTexture'
                end

                local function inArray(value, array)
                    for i = 1, #array do
                        if array[i] == value then
                            return true
                        end
                    end
                    return false
                end

                if ui.button(x + ROW_WIDTH, y, ROW_WIDTH / 2, 'auto ') then
                    print('todo auto node')
                    local body = state.selection.selectedSFixture:getBody()
                    local connectedBodies = {}
                    ud.extra.nodes = {}
                    while not inArray(body, connectedBodies) do
                        --   print(#connectedBodies)
                        local attachedJoints = body:getJoints()
                        if #attachedJoints > 0 then
                            table.insert(connectedBodies, body)

                            --print('1 attached joint found, lets start there..')
                            local joint = attachedJoints[1]
                            ud.extra.nodes[#connectedBodies] = { id = joints.getJointId(joint), type = 'joint' }
                            -- print(inspect(ud.extra.nodes))
                            local bodyA, bodyB = joint:getBodies()
                            if not inArray(bodyA, connectedBodies) then
                                body = bodyA
                                --print('settinga')
                            end
                            if not inArray(bodyB, connectedBodies) then
                                body = bodyB
                                --print('settingb')
                            end
                        end
                    end

                    --ud.extra.nodes[j] = { id = instance.joints[jointID], type = 'joint' }
                end

                nextRow()
                if ui.button(x + ROW_WIDTH + ROW_WIDTH / 2, y, 20, '?') then
                    logger:inspect(ud.extra.nodes)
                end
                nextRow()

                ui.createSliderWithId(myID, ' texfixzOffset', x, y, ROW_WIDTH, -180, 180,
                    math.floor(oldTexFixUD.extra.zOffset or 0),
                    function(v)
                        oldTexFixUD.extra.zOffset = math.floor(v)
                    end)
                nextRow()
                nextRow()
                local e = state.selection.selectedSFixture:getUserData().extra
                if ui.checkbox(x, y, true, (e.OMP == false or e.OMP == nil) and 'BG + FG' or 'OMP') then
                    e.OMP = not e.OMP
                end
                nextRow()
                oldTexFixUD.extra.main = oldTexFixUD.extra.main or {}
                ui.createSliderWithId(myID, 'wmul', x + 50, y, ROW_WIDTH - 50, 0.1, 10.0,
                    oldTexFixUD.extra.main.wmul or 1,
                    function(v)
                        oldTexFixUD.extra.main.wmul = v
                    end)
                if ui.checkbox(x, y, (oldTexFixUD.extra.main.dir == nil or oldTexFixUD.extra.main.dir == 1), 'dir') then
                    if oldTexFixUD.extra.main.dir == nil or oldTexFixUD.extra.main.dir == 1 then
                        oldTexFixUD.extra.main.dir = -1
                    else
                        oldTexFixUD.extra.main.dir = 1
                    end
                end
                nextRow()


                if not e.OMP then
                    local dirty = function() oldTexFixUD.extra.dirty = true end
                    handlePaletteAndHex(myID, 'bgHex', x, y, 100, oldTexFixUD.extra.main.bgHex,
                        function(c) oldTexFixUD.extra.main.bgHex = c end, dirty)
                    local slx, sly = ui.sameLine(20)
                    handleURLInput(myID, 'bgURL', slx, sly, 150, oldTexFixUD.extra.main.bgURL,
                        function(u)
                            oldTexFixUD.extra.main.bgURL = u
                        end)
                    nextRow()
                    handlePaletteAndHex(myID, 'fgHex', x, y, 100, oldTexFixUD.extra.main.fgHex,
                        function(c) oldTexFixUD.extra.main.fgHex = c end, dirty)
                    slx, sly = ui.sameLine(20)
                    handleURLInput(myID, 'fgURL', slx, sly, 150, oldTexFixUD.extra.main.fgURL,
                        function(u)
                            oldTexFixUD.extra.main.fgURL = u
                        end)

                    nextRow()
                end

                if e.OMP then
                    oldTexFixUD.extra.main = oldTexFixUD.extra.main or {}

                    combineImageUI('main')
                    flipWholeUI('main')

                    local dirty = function() oldTexFixUD.extra.dirty = true end
                    handlePaletteAndHex(myID, 'maintint', x, y, 100, oldTexFixUD.extra.main.tint,
                        function(color) oldTexFixUD.extra.main.tint = color end, dirty)
                end
            end

            if oldUD.subtype == 'tile-repeat' then
                oldTexFixUD.extra.main = oldTexFixUD.extra.main or {}
                oldTexFixUD.extra.tileWidthM = oldTexFixUD.extra.tileWidthM or 1
                oldTexFixUD.extra.tileHeightM = oldTexFixUD.extra.tileHeightM or 1
                oldTexFixUD.extra.tileRotation = oldTexFixUD.extra.tileRotation or 0
                ui.createSliderWithId(myID, 'twm', x, y, 160, 0.01,
                    100,
                    oldTexFixUD.extra.tileWidthM, function(v)
                        oldTexFixUD.extra.tileWidthM = v
                        oldTexFixUD.extra._mesh = nil
                    end)
                nextRow()
                nextRow()
                ui.createSliderWithId(myID, 'thm', x, y, 160, 0.01,
                    100,
                    oldTexFixUD.extra.tileHeightM, function(v)
                        oldTexFixUD.extra.tileHeightM = v
                        oldTexFixUD.extra._mesh = nil
                    end)
                nextRow()

                ui.createSliderWithId(myID, 'tr', x, y, 160, 0,
                    2 * math.pi,
                    oldTexFixUD.extra.tileRotation, function(v)
                        oldTexFixUD.extra.tileRotation = v
                        oldTexFixUD.extra._mesh = nil
                    end)

                nextRow()

                ui.createSliderWithId(myID, ' texfixzOffset', x, y, ROW_WIDTH, -180, 180,
                    math.floor(oldTexFixUD.extra.zOffset or 0),
                    function(v)
                        oldTexFixUD.extra.zOffset = math.floor(v)
                    end)

                nextRow()
                handleURLInput(myID, 'bgURL', x, y, 150, oldTexFixUD.extra.main.bgURL,
                    function(u)
                        oldTexFixUD.extra.main.bgURL = u
                    end)
                nextRow()
                local dirty = function() oldTexFixUD.extra.dirty = true end
                handlePaletteAndHex(myID, 'maintint', x, y, 100, oldTexFixUD.extra.main.tint,
                    function(color) oldTexFixUD.extra.main.tint = color end, dirty)
            end



            if oldUD.subtype == 'trace-vertices' then
                oldTexFixUD.extra.main = oldTexFixUD.extra.main or {}
                oldTexFixUD.extra.startIndex = oldTexFixUD.extra.startIndex or 1
                oldTexFixUD.extra.endIndex = oldTexFixUD.extra.endIndex or 1
                oldTexFixUD.extra.tension = oldTexFixUD.extra.tension or .05
                oldTexFixUD.extra.spacing = oldTexFixUD.extra.spacing or 10
                oldTexFixUD.extra.width = oldTexFixUD.extra.width or 100
                local body = state.selection.selectedSFixture:getBody()
                local parentVerts = body:getUserData().thing.vertices
                --print(#parentVerts)
                nextRow()
                nextRow()
                ui.createSliderWithId(myID, 'startIndex', x, y, 160, -(#parentVerts / 2),
                    (#parentVerts / 2),
                    oldTexFixUD.extra.startIndex, function(v)
                        oldTexFixUD.extra.startIndex = math.floor(v + 0)
                    end)

                ui.alignedLabel(x + 130, y, oldTexFixUD.extra.startIndex)
                nextRow()
                ui.createSliderWithId(myID, 'endIndex', x, y, 160, -(#parentVerts / 2),
                    (#parentVerts / 2),
                    oldTexFixUD.extra.endIndex, function(v)
                        oldTexFixUD.extra.endIndex = math.floor(v + 0)
                    end)

                ui.alignedLabel(x + 130, y, oldTexFixUD.extra.endIndex)

                nextRow()
                ui.createSliderWithId(myID, 'tension', x, y, 160, 0.01,
                    0.5,
                    oldTexFixUD.extra.tension, function(v)
                        oldTexFixUD.extra.tension = v
                    end)
                nextRow()
                ui.createSliderWithId(myID, 'spacing', x, y, 160, 1,
                    100,
                    oldTexFixUD.extra.spacing, function(v)
                        oldTexFixUD.extra.spacing = v
                    end)
                nextRow()
                ui.createSliderWithId(myID, 'width', x, y, 160, 1,
                    1000,
                    oldTexFixUD.extra.width, function(v)
                        oldTexFixUD.extra.width = v
                    end)
                nextRow()
                ui.createSliderWithId(myID, ' texfixzOffset', x, y, ROW_WIDTH, -180, 180,
                    math.floor(oldTexFixUD.extra.zOffset or 0),
                    function(v)
                        oldTexFixUD.extra.zOffset = math.floor(v)
                    end)
                nextRow()
                nextRow()
                local e = state.selection.selectedSFixture:getUserData().extra
                if ui.checkbox(x, y, true, (e.OMP == false or e.OMP == nil) and 'BG + FG' or 'OMP') then
                    e.OMP = not e.OMP
                end
                nextRow()
                oldTexFixUD.extra.main = oldTexFixUD.extra.main or {}
                ui.createSliderWithId(myID, 'wmul', x + 50, y, ROW_WIDTH - 50, 0.1, 10.0,
                    oldTexFixUD.extra.main.wmul or 1,
                    function(v)
                        oldTexFixUD.extra.main.wmul = v
                    end)
                if ui.checkbox(x, y, (oldTexFixUD.extra.main.dir == nil or oldTexFixUD.extra.main.dir == 1), 'dir') then
                    if oldTexFixUD.extra.main.dir == nil or oldTexFixUD.extra.main.dir == 1 then
                        oldTexFixUD.extra.main.dir = -1
                    else
                        oldTexFixUD.extra.main.dir = 1
                    end
                end
                nextRow()


                if not e.OMP then
                    local dirty = function() oldTexFixUD.extra.dirty = true end
                    handlePaletteAndHex(myID, 'bgHex', x, y, 100, oldTexFixUD.extra.main.bgHex,
                        function(c)
                            oldTexFixUD.extra.main.bgHex = c
                        end, dirty)
                    local slx, sly = ui.sameLine(20)
                    handleURLInput(myID, 'bgURL', slx, sly, 150, oldTexFixUD.extra.main.bgURL,
                        function(u)
                            oldTexFixUD.extra.main.bgURL = u
                        end)
                    nextRow()
                    handlePaletteAndHex(myID, 'fgHex', x, y, 100, oldTexFixUD.extra.main.fgHex,
                        function(c) oldTexFixUD.extra.main.fgHex = c end, dirty)
                    slx, sly = ui.sameLine(20)
                    handleURLInput(myID, 'fgURL', slx, sly, 150, oldTexFixUD.extra.main.fgURL,
                        function(u)
                            oldTexFixUD.extra.main.fgURL = u
                        end)

                    nextRow()
                end

                if e.OMP then
                    oldTexFixUD.extra.main = oldTexFixUD.extra.main or {}

                    combineImageUI('main')
                    flipWholeUI('main')

                    local dirty = function() oldTexFixUD.extra.dirty = true end
                    handlePaletteAndHex(myID, 'maintint', x, y, 100, oldTexFixUD.extra.main.tint,
                        function(color) oldTexFixUD.extra.main.tint = color end, dirty)
                end
            end
        end
        nextRow()
    end)
end

return lib

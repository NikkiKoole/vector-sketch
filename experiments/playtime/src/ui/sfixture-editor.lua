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
local modes = require('src.modes')
local fileBrowser = require('src.file-browser')
local subtypes = require('src.subtypes')
local NT = require('src.node-types')
local SIDES = require('src.sides')
local cdt = require('src.cdt')

local PANEL_WIDTH = 300
local BUTTON_HEIGHT = ui.theme.lineHeight
local ROW_WIDTH = 160
local BUTTON_SPACING = 10

local getCenterAndDimensions = mathutils.getCenterAndDimensions

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





        if subtypes.is(ud, subtypes.TEXFIXTURE) then
            oldTexFixUD = state.selection.selectedSFixture:getUserData()
            drawAccordion('position', function()
                if ui.button(x, y, BUTTON_HEIGHT, '∆') then
                    modes.set(modes.POSITIONING_SFIXTURE)
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
            local function recomputeLinkedResourceAndUnbind()
                local lbl = ud.label or ''
                for _, rv in pairs(registry.sfixtures) do
                    if not rv:isDestroyed() then
                        local rud = rv:getUserData()
                        if #rud.label > 0 and rud.label == lbl and subtypes.is(rud, subtypes.RESOURCE) then
                            local idx = rud.extra and rud.extra.selectedBGIndex
                            local bd = idx and state.backdrops and state.backdrops[idx]
                            if bd then
                                cdt.computeResourceMesh(rud, rv:getBody(), bd,
                                    state.triangulationMode,
                                    state.cdtSpacing, mathutils)
                            end
                        end
                    end
                end
                ud.extra.influences = nil
                ud.extra.bindVerts = nil
                ud.extra.vertexAssignments = nil
            end

            local tmode = state.triangulationMode or 'basic'
            local tlabel = (tmode == 'cdt') and 'triangulation: CDT (click for basic)'
                or 'triangulation: basic (click for CDT)'
            if ui.button(x, y, ROW_WIDTH, tlabel) then
                state.triangulationMode = (tmode == 'cdt') and 'basic' or 'cdt'
                recomputeLinkedResourceAndUnbind()
            end
            nextRow()

            -- CDT Steiner-point spacing (only relevant when mode=='cdt').
            -- Smaller = denser interior mesh = smoother deformation, more
            -- triangles. Recomputes on drag + clears the bind so the user
            -- re-binds once satisfied with the density.
            if state.triangulationMode == 'cdt' then
                local defaultSpacing = state.cdtSpacing or 60
                local newSpacing = ui.sliderWithInput(myID .. ' cdtSpacing', x, y, ROW_WIDTH,
                    10, 200, defaultSpacing)
                ui.alignedLabel(x, y, ' cdt spacing (lo=dense)')
                if newSpacing and tonumber(newSpacing) and tonumber(newSpacing) ~= defaultSpacing then
                    state.cdtSpacing = tonumber(newSpacing)
                    recomputeLinkedResourceAndUnbind()
                end
                nextRow()
            end

            -- Bind radius: how far each bone segment's influence reaches.
            -- Larger = softer falloff / more blending; smaller = tighter
            -- skin-to-bone coupling. Applied at bind time.
            local br = ui.sliderWithInput(myID .. ' bindRadius', x, y, ROW_WIDTH, 10, 500, ud.extra.bindRadius or 80)
            ui.alignedLabel(x, y, ' bindRadius')
            if br then ud.extra.bindRadius = br end
            nextRow()

            if ui.button(x, y, ROW_WIDTH, 'bind pose') then
                local label = ud.label or ""


                -- todo extract this!!
                local mappert
                for _, v in pairs(registry.sfixtures) do
                    if not v:isDestroyed() then
                        local vud = v:getUserData()

                        if (#vud.label > 0 and label == vud.label and subtypes.is(vud, subtypes.RESOURCE)) then
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
                    -- Prefer the RESOURCE's `meshVertices` when present
                    -- (CDT mode — includes Steiner points). Fall back to the
                    -- polygon's raw verts for basic mode / legacy scenes.
                    local mapperExtra = mappert:getUserData().extra
                    local verts = (mapperExtra and mapperExtra.meshVertices)
                        or mud.thing.vertices

                    logger:info("**")

                    -- Center by polygon BODY's position (not mean-of-verts)
                    -- to match the mesh render path and UV compute — keeps
                    -- bindVerts, mesh render, and texture UVs all in the
                    -- same frame (eliminates the 3-4 px drift that mean-of-
                    -- verts introduced).
                    local vx, vy = mb:getPosition()
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
                        if node.type == NT.JOINT then
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
                                    type = NT.JOINT,
                                    id = node.id,
                                    side = SIDES.A,
                                },
                                {
                                    body = bodyB,
                                    offx = bx,
                                    offy = by,
                                    type = NT.JOINT,
                                    id = node.id,
                                    side = SIDES.B,
                                }
                            }
                        end

                        if node.type == NT.ANCHOR then
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
                                    type = NT.ANCHOR,
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
                                        bindAngle = bb:getAngle(), -- body rotation at bind time (for DQS)
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
                    -- Segment-based weighting (ported from
                    -- experiments/deform-textured/main.lua:570). For each
                    -- consecutive pair of nodes that share a body, treat that
                    -- pair as a bone SEGMENT on that body. Compute weight per
                    -- body from segment-distance + smoothstep falloff, then
                    -- distribute the body weight across the influences we've
                    -- already created on that body.
                    --
                    -- Why: point-distance (old applyWeights) blurs a vertex
                    -- between every nearby anchor, which collapses mesh width
                    -- at bone midpoints. Segment-distance binds a vertex to
                    -- whichever bone it's closest-to as a whole line, keeping
                    -- width consistent along the length.
                    local function distToSegment(px, py, ax, ay, bx, by)
                        local abx, aby = bx - ax, by - ay
                        local abLen2 = abx * abx + aby * aby
                        if abLen2 < 1e-12 then
                            local dx, dy = px - ax, py - ay
                            return math.sqrt(dx * dx + dy * dy), 0
                        end
                        local t = ((px - ax) * abx + (py - ay) * aby) / abLen2
                        if t < 0 then t = 0 elseif t > 1 then t = 1 end
                        local cx, cy = ax + abx * t, ay + aby * t
                        local dx, dy = px - cx, py - cy
                        return math.sqrt(dx * dx + dy * dy), t
                    end
                    local function smoothstep(e0, e1, x)
                        if x <= e0 then return 0 end
                        if x >= e1 then return 1 end
                        local t = (x - e0) / (e1 - e0)
                        return t * t * (3 - 2 * t)
                    end
                    local function buildSegments(nodes)
                        local segs = {}
                        for i = 1, #nodes - 1 do
                            local a = getNodeLocal(nodes[i])
                            local b = getNodeLocal(nodes[i + 1])
                            for _, ai in ipairs(a) do
                                for _, bi in ipairs(b) do
                                    if ai.body == bi.body then
                                        segs[#segs + 1] = {
                                            body = ai.body,
                                            lax = ai.offx, lay = ai.offy,
                                            lbx = bi.offx, lby = bi.offy,
                                        }
                                    end
                                end
                            end
                        end
                        return segs
                    end
                    local function applySegmentWeights(influences, nodes, worldVerts, radius)
                        radius = radius or 80
                        local segments = buildSegments(nodes)
                        if #segments == 0 then
                            -- Fall back to point-based inverse-distance weights.
                            for vi = 1, #influences do
                                local sum = 0
                                for k = 1, #influences[vi] do
                                    influences[vi][k].w = 1 / (influences[vi][k].dist + 1e-6)
                                    sum = sum + influences[vi][k].w
                                end
                                if sum > 0 then
                                    for k = 1, #influences[vi] do
                                        influences[vi][k].w = influences[vi][k].w / sum
                                    end
                                end
                            end
                            return influences
                        end

                        local numVerts = #worldVerts / 2
                        for vi = 1, numVerts do
                            local px = worldVerts[(vi - 1) * 2 + 1]
                            local py = worldVerts[(vi - 1) * 2 + 2]

                            -- Per-body weight = max segment weight across any
                            -- segment on that body (one body can host multiple
                            -- segments if the node list is longer).
                            local bodyW = {}
                            for _, seg in ipairs(segments) do
                                local wax, way = seg.body:getWorldPoint(seg.lax, seg.lay)
                                local wbx, wby = seg.body:getWorldPoint(seg.lbx, seg.lby)
                                local d = distToSegment(px, py, wax, way, wbx, wby)
                                local w = 1 - smoothstep(0, radius, d)
                                if w > 0 and (not bodyW[seg.body] or bodyW[seg.body] < w) then
                                    bodyW[seg.body] = w
                                end
                            end

                            -- Count influences per body to split body-weight
                            -- evenly (multiple endpoints on a body deform
                            -- rigidly together — sharing the weight keeps the
                            -- total body contribution = body-weight).
                            local countPerBody = {}
                            for k = 1, #influences[vi] do
                                local b = influences[vi][k].body
                                countPerBody[b] = (countPerBody[b] or 0) + 1
                            end

                            local sum = 0
                            for k = 1, #influences[vi] do
                                local b = influences[vi][k].body
                                local bw = bodyW[b] or 0
                                influences[vi][k].w = bw / countPerBody[b]
                                sum = sum + influences[vi][k].w
                            end

                            if sum > 0 then
                                for k = 1, #influences[vi] do
                                    influences[vi][k].w = influences[vi][k].w / sum
                                end
                            else
                                -- All segments outside radius → bind to the
                                -- nearest segment's body at full weight so the
                                -- vertex isn't left orphaned.
                                local bestBody, bestDist = nil, math.huge
                                for _, seg in ipairs(segments) do
                                    local wax, way = seg.body:getWorldPoint(seg.lax, seg.lay)
                                    local wbx, wby = seg.body:getWorldPoint(seg.lbx, seg.lby)
                                    local d = distToSegment(px, py, wax, way, wbx, wby)
                                    if d < bestDist then bestDist = d; bestBody = seg.body end
                                end
                                if bestBody then
                                    local count = countPerBody[bestBody] or 1
                                    for k = 1, #influences[vi] do
                                        influences[vi][k].w = (influences[vi][k].body == bestBody) and (1 / count) or 0
                                    end
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
                    -- Capture bindVerts in the MESHUSERT-owning body's world
                    -- space (the bone), NOT the polygon's world space. The
                    -- pre-bind draw path renders the mesh at the bone's
                    -- transform (`box2d-draw-textured.lua:1625`), so binding
                    -- relative to the bone keeps the mesh visually in place
                    -- — what-you-see-is-what-you-bind. Using `mb` (polygon
                    -- body) here instead caused the mesh to jump on bind.
                    local ownerBody = state.selection.selectedSFixture:getBody()
                    verts = vertsToWorld(ownerBody, verts)

                    if ud.extra.nodes and #ud.extra.nodes > 0 then
                        local influences = computeInfluences(verts, ud.extra.nodes)
                        influences = applySegmentWeights(influences, ud.extra.nodes, verts, tonumber(ud.extra.bindRadius) or 80)

                        -- optional but highly recommended:
                        influences = pruneTopK(influences, 3)

                        ud.extra.influences = influences -- STORE IT

                        -- Capture world-space bind-pose vertex positions (for DQS skinning).
                        local bindVerts = {}
                        local numVerts = #verts / 2
                        for vi = 1, numVerts do
                            bindVerts[vi] = { verts[(vi - 1) * 2 + 1], verts[(vi - 1) * 2 + 2] }
                        end
                        ud.extra.bindVerts = bindVerts
                        --logger:inspect(influences)
                    end
                end
            end

            -- Unbind: clear influences + bindVerts + vertex assignments so
            -- the mesh falls back to the undeformed draw path (drawn at bone
            -- position, no deformation). Keeps the node list + transforms.
            if ud.extra.influences and #ud.extra.influences > 0 then
                nextRow()
                if ui.button(x, y, ROW_WIDTH, 'unbind (reset mesh)') then
                    ud.extra.influences = nil
                    ud.extra.bindVerts = nil
                    ud.extra.vertexAssignments = nil
                end
            end


            -- VERTEX ASSIGNMENT UI
            nextRow()
            love.graphics.line(x, y + 10, x + ROW_WIDTH + 50, y + 10)
            nextRow()

            local editMode = modes.is(modes.EDIT_MESH_VERTS)
            local buttonLabel = editMode and 'EDITING' or 'edit vertices'
            local buttonColor = editMode and { 0.2, 0.8, 0.2 } or nil

            if ui.button(x, y, ROW_WIDTH, buttonLabel, BUTTON_HEIGHT, buttonColor) then
                if editMode then
                    modes.clear()
                    state.vertexEditor.selectedVertices = {}
                else
                    modes.set(modes.EDIT_MESH_VERTS)
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
            end
        elseif subtypes.is(ud, subtypes.RESOURCE) then
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

                    -- Delegate UV + triangulation to the shared mesh builder
                    -- in `src/cdt.lua`. Picks basic or CDT based on
                    -- `state.triangulationMode`. Stores `ud.extra.uvs`,
                    -- `ud.extra.triangles`, and optionally
                    -- `ud.extra.meshVertices` (CDT mode only).
                    cdt.computeResourceMesh(ud, bod, b,
                        state.triangulationMode or 'basic',
                        state.cdtSpacing, mathutils)
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
                    modes.set(modes.POSITIONING_SFIXTURE)
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

                if not subtypes.is(state.selection.selectedSFixture:getUserData(), subtypes.TEXFIXTURE) then
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
            if subtypes.is(oldUD, subtypes.CONNECTED_TEXTURE) then
                oldTexFixUD.extra.main = oldTexFixUD.extra.main or {}
                if ui.button(x, y, ROW_WIDTH, 'add node ' .. (oldUD.extra.nodes and #oldUD.extra.nodes or '')) then
                    modes.set(modes.ADD_NODE_CONNECTED_TEX)
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
                            ud.extra.nodes[#connectedBodies] = { id = joints.getJointId(joint), type = NT.JOINT }
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

            if subtypes.is(oldUD, subtypes.TILE_REPEAT) then
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



            if subtypes.is(oldUD, subtypes.TRACE_VERTICES) then
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

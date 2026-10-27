local lib = {}

local mathutils = require('src.math-utils')
local ui = require('src.ui.all')
local camera = require('src.camera')
local cam = camera.getInstance()
local utils = require('src.utils')
local fixtures = require('src.fixtures')
local snap = require('src.physics.snap')
local sceneIO = require('src.io')
local objectManager = require('src.object-manager')
local recorder = require('src.recorder')
local state = require('src.state')
local ST = require('src.shape-types')
local modes = require('src.modes')
local inspector = require('src.ui.inspector')
local bodyParams = require('src.body-params')

local PANEL_WIDTH = 300
local BUTTON_HEIGHT = ui.theme.lineHeight
local ROW_WIDTH = 160
local BUTTON_SPACING = 10

local accordionStatesSO = {
    behaviors = false,
    position = false,
    transform = false,
    physics = false,
    motion = false,
    joints = false,
    sfixtures = false,
    textured = false,
}


-- Draw every accordion open (spec/ui-overflow_spec.lua measures the fully open panel).
local forceOpen = false
function lib.setAllAccordions(open) forceOpen = open end

-- panelX, panelY, panelWidth, panelH: the panel rect (default: the right edge, full height)
function lib.drawUpdateSelectedObjectUI(panelX, panelY, panelWidth, panelH)
    if recorder.isRecording then return end
    local w, h = love.graphics.getDimensions()
    panelWidth = panelWidth or PANEL_WIDTH
    panelX, panelY, panelH = panelX or (w - panelWidth - 20), panelY or 20, panelH or (h - 40)
    ui.panel(panelX, panelY, panelWidth, panelH, '∞ body props ∞', function()
        -- content scrolls when it doesn't fit (spec/ui-overflow_spec.lua)
        ui.scrollPanel('body-panel', panelX, panelY + 40, panelWidth, panelH - 45, function()
            local body = state.selection.selectedObj.body
            -- local angleDegrees = body:getAngle() * 180 / math.pi
            local myID = state.selection.selectedObj.id

            -- Initialize Layout
            local padding = BUTTON_SPACING
            local layout = ui.createLayout({
                type = 'columns',
                spacing = BUTTON_SPACING,
                startX = panelX + 20,
                startY = panelY + 80 + padding
            })

            if body:isDestroyed() then return end

            local x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
            local nextRow = function()
                x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
            end
            -- Function to create an accordion
            local function drawAccordion(key, contentFunc)
                -- Draw the accordion header

                local clicked = ui.header_button(x, y, PANEL_WIDTH - 40, (accordionStatesSO[key] and " ÷  " or " •") ..
                    ' ' .. key, accordionStatesSO[key])
                if clicked then
                    accordionStatesSO[key] = not accordionStatesSO[key]
                end
                y = y + BUTTON_HEIGHT + BUTTON_SPACING

                -- If the accordion is expanded, draw the content
                if accordionStatesSO[key] or forceOpen then
                    contentFunc(clicked)
                end
            end

            -- Custom/ribbon polygons: unlock vertices, Steiner points (old and new panel)
            local function polygonTools()
                if (state.selection.selectedObj) then
                    if state.selection.selectedObj
                        and state.selection.selectedObj.shapeType == ST.CUSTOM
                        or state.selection.selectedObj.shapeType == ST.RIBBON then
                        if ui.button(x, y, 260,
                            state.polyEdit.lockedVerts and 'verts locked' or 'verts unlocked') then
                            state.polyEdit.lockedVerts = not state.polyEdit.lockedVerts
                            if state.polyEdit.lockedVerts == false then
                                state.polyEdit.tempVerts = utils.shallowCopy(state.selection.selectedObj
                                    .vertices)
                                local cx, cy = mathutils.computeCentroid(state.selection.selectedObj
                                    .vertices)
                                state.polyEdit.centroid = { x = cx, y = cy }
                            else
                                state.polyEdit.tempVerts = nil
                                state.polyEdit.centroid = nil
                            end
                        end

                        -- POC: Steiner-point authoring on the body's polygon. Stores
                        -- (x,y) pairs in body-local coords on thing.extraSteiner. Does
                        -- NOT rebuild collision fixtures or change the fill draw — the
                        -- overlay in editor-render renders the would-be triangulation
                        -- on top so the user can see the effect without committing.
                        local selThing = state.selection.selectedObj
                        local steinerCount = selThing.extraSteiner and #selThing.extraSteiner / 2 or 0
                        local placing = modes.is(modes.PLACE_STEINER)
                        nextRow()
                        local label = placing and 'placing steiner (click inside, right-click remove)'
                            or 'place steiner'
                        local color = placing and { 0.2, 0.8, 0.2 } or nil
                        if ui.button(x, y, 260, label, BUTTON_HEIGHT, color) then
                            if placing then modes.clear() else modes.set(modes.PLACE_STEINER) end
                        end
                        if steinerCount > 0 then
                            nextRow()
                            if ui.button(x, y, 260, 'clear steiner (' .. steinerCount .. ')') then
                                selThing.extraSteiner = nil
                            end
                        end
                        return true
                    end
                end
                return false
            end

            if ui.button(x, y, 100, 'clone') then
                state.selection.selectedBodies = { state.selection.selectedObj }
                local cloned = sceneIO.cloneSelection(state.selection.selectedBodies, state.physicsWorld)
                state.selection.selectedBodies = cloned
                state.selection.selectedObj = nil
            end

            local slx, sly = ui.sameLine()
            if ui.button(slx, sly, 140, 'destroy') then
                snap.destroySnapJointAboutBody(body)
                objectManager.destroyBody(body)
                state.selection.selectedObj = nil
                return
            end
            nextRow()

            local userData = body:getUserData()
            local thing = userData and userData.thing
            if thing then
                local used, replaced = inspector.drawParams('body_' .. tostring(myID), bodyParams.rows, thing, body,
                    x, y, 270)
                if replaced then return end -- rebuilt or flipped: the new thing draws next frame
                layout.curY = y + used
                nextRow()
            end

            if thing then
                drawAccordion("behaviors",
                    function(_clicked)
                        --local w = love.graphics.getFont():getWidth('straight') + 20
                        -- ui.button(x, y, w, 'straight')
                        --ui.toggleButton(x, y, w, BUTTON_HEIGHT, 'straight', 'straight', false)

                        -- what behaviors do i have ?
                        -- KEEP_ANGLE
                        -- LIMB_HUB
                        -- HUB_PRESETS = {
                        --   humanoid = {
                        --     allowed = { "left_arm", "right_arm", "left_leg", "right_leg", "neck" }
                        --   },
                        --   upper_torso = {
                        --     allowed = { "left_arm", "right_arm", "neck" }
                        --   },
                        --   lower_torso = {
                        --     allowed = { "left_leg", "right_leg" }
                        --   },
                        --   potatohead = {
                        --     allowed = { "limb1", "limb2", "limb3", "limb4" }
                        --   }
                        -- }
                        -- print(inspect(userData))
                        if thing.behaviors then
                            for i = 1, #thing.behaviors do
                                nextRow()

                                local behavior = thing.behaviors[i]
                                local btnW = love.graphics.getFont():getWidth(behavior.name) + 20
                                if ui.button(x, y, btnW, behavior.name, BUTTON_HEIGHT, { 0.4, 0.4, 0.8 }) then
                                    if (state.panelVisibility.customBehavior) then
                                        state.panelVisibility.customBehavior = false
                                    else
                                        state.panelVisibility.customBehavior = { body = body, name = behavior.name }
                                    end
                                end
                            end
                        end

                        nextRow()
                        if ui.button(x, y, 260, 'add behavior') then
                            if (state.panelVisibility.addBehavior) then
                                state.panelVisibility.addBehavior = false
                            else
                                state.panelVisibility.addBehavior = { body = body }
                            end
                        end

                        --nextRow()
                    end)
                nextRow()

                if polygonTools() then nextRow() end

                if not body:isDestroyed() then
                    local attachedJoints = body:getJoints()
                    if attachedJoints and #attachedJoints > 0
                        and not (#attachedJoints == 1 and attachedJoints[1]:getType() == 'mouse') then
                        drawAccordion("joints",
                            function()
                                for _, joint in ipairs(attachedJoints) do
                                    -- Display joint type and unique identifier for identification
                                    local jointType = joint:getType()

                                    if (jointType ~= 'mouse') then
                                        -- Display joint button
                                        x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
                                        local jointLabel = string.format("%s %s", jointType,
                                            string.sub(joint:getUserData().id, 1, 3))

                                        local clicked, _, _, isHover = ui.button(x, y, 260, jointLabel)

                                        if clicked then
                                            state.selection.selectedJoint = joint
                                        end
                                        if isHover then
                                            local x1, y1, x2, y2 = joint:getAnchors()
                                            -- local centroid = fixtures.getCentroidOfFixture(body, myfixtures[i])
                                            --  local x2, y2 = body:getLocalPoint(ud.offsetA.x, ud.offsetA.y)
                                            ui.onStage(function()
                                                local ax3, ay3 = cam:getScreenCoordinates(x1, y1)
                                                love.graphics.circle('line', ax3, ay3, 6)
                                                local bx3, by3 = cam:getScreenCoordinates(x2, y2)
                                                love.graphics.circle('line', bx3, by3, 3)
                                            end)
                                        end
                                    end
                                end
                            end)
                        nextRow()
                    end
                end

                local myfixtures = body:getFixtures()
                local ok, index  = fixtures.hasFixturesWithUserDataAtBeginning(myfixtures)
                if ok and index > 0 then
                    drawAccordion("sfixtures",
                        function()
                            for i = 1, index do
                                nextRow()
                                --logger:inspect(myfixtures[i]:getUserData())

                                local subtype = myfixtures[i]:getUserData().subtype

                                local prefix = (string.sub(subtype, 1, 3))
                                local fixLabel = string.format("%s %s", prefix,
                                    string.sub(myfixtures[i]:getUserData().id, 1, 3))
                                local clicked, _, _, isHover = ui.button(x, y, 260, fixLabel)

                                if clicked then
                                    state.selection.selectedJoint = nil
                                    state.selection.selectedObj = nil
                                    state.selection.selectedSFixture = myfixtures[i]
                                end

                                if isHover then
                                    local centroid = fixtures.getCentroidOfFixture(body, myfixtures[i])
                                    local x2, y2 = body:getWorldPoint(centroid[1], centroid[2])
                                    ui.onStage(function()
                                        local x3, y3 = cam:getScreenCoordinates(x2, y2)
                                        love.graphics.circle('line', x3, y3, 3)
                                    end)
                                end
                            end
                        end)

                    nextRow()
                end
            end

            nextRow()

            -- List Attached Joints Using Body:getJoints()
        end)
    end)
end

return lib

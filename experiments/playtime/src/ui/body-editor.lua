local lib = {}

local logger = require('src.logger')
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

function lib.drawUpdateSelectedObjectUI()
    -- Define a table to keep track of accordion states

    if recorder.isRecording then return end
    local panelWidth = PANEL_WIDTH
    local w, h = love.graphics.getDimensions()
    ui.panel(w - panelWidth - 20, 20, panelWidth, h - 40, '∞ body props ∞', function()
        local body = state.selection.selectedObj.body
        -- local angleDegrees = body:getAngle() * 180 / math.pi
        local myID = state.selection.selectedObj.id

        -- Initialize Layout
        local padding = BUTTON_SPACING
        local layout = ui.createLayout({
            type = 'columns',
            spacing = BUTTON_SPACING,
            startX = w - panelWidth,
            startY = 100 + padding
        })

        -- Toggle Body Type Button
        -- Retrieve the current body type
        if body:isDestroyed() then return end
        local currentBodyType = body:getType() -- 'static', 'dynamic', or 'kinematic'

        -- Determine the next body type in the cycle
        local nextBodyType
        if currentBodyType == 'static' then
            nextBodyType = 'dynamic'
        elseif currentBodyType == 'dynamic' then
            nextBodyType = 'kinematic'
        elseif currentBodyType == 'kinematic' then
            nextBodyType = 'static'
        end

        -- Add a button to toggle the body type
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
            if accordionStatesSO[key] then
                contentFunc(clicked)
            end
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

        if ui.button(x, y, 260, currentBodyType) then
            body:setType(nextBodyType)
            body:setAwake(true)
        end
        nextRow()

        local userData = body:getUserData()
        local thing = userData and userData.thing

        if thing then
            -- Shape Properties
            local shapeType = thing.shapeType

            local newLabel = ui.textinput(myID .. ' label', x, y, 260, BUTTON_HEIGHT, "", thing.label)
            if newLabel and newLabel ~= thing.label then
                thing.label = newLabel -- Update the label
            end

            nextRow()

            nextRow()

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

            drawAccordion("position",
                function(_clicked)
                    nextRow()
                    local xValue = thing.body:getX()
                    local xInputText, xDirty = ui.textinput(myID .. 'x', x, y, 120, BUTTON_HEIGHT, ".", "" .. xValue,
                        true)
                    if (xDirty) then
                        local numericPosX = tonumber(xInputText)
                        if numericPosX then
                            thing.body:setX(numericPosX)
                        else
                            logger:error("Invalid X position input!")
                        end
                    end
                    local slx2, sly2 = ui.sameLine()
                    local yValue = thing.body:getY()
                    local yInputText, yDirty = ui.textinput(myID .. 'y', slx2, sly2, 120, BUTTON_HEIGHT, ".",
                        "" .. yValue, true)
                    if (yDirty) then
                        local numericPosY = tonumber(yInputText)
                        if numericPosY then
                            thing.body:setY(numericPosY)
                        else
                            logger:error("Invalid Y position input!")
                        end
                    end

                    nextRow()

                    local fixedAngleDirty = ui.checkbox(x, y, body:isFixedRotation(), 'fixed angle')
                    if fixedAngleDirty then
                        body:setFixedRotation(not body:isFixedRotation())
                    end

                    -- Angle Slider
                    nextRow()

                    local newAngle = ui.sliderWithInput(myID .. 'angle', x, y, ROW_WIDTH, -180, 180,
                        (body:getAngle() * 180 / math.pi))
                    if newAngle and (body:getAngle() * 180 / math.pi) ~= newAngle then
                        body:setAngle(newAngle * math.pi / 180)
                    end
                    ui.alignedLabel(x, y, ' angle')


                    nextRow()

                    -- local newZOffset = ui.sliderWithInput(myID .. 'zOffset', x, y, ROW_WIDTH, -180, 180,
                    --     math.floor(thing.zOffset),
                    --     (body:isAwake() and not state.world.paused) or dirtyBodyChange)
                    -- if newZOffset and thing.zOffset ~= newZOffset then
                    --     thing.zOffset = math.floor(newZOffset)
                    -- end
                    -- ui.label(x, y, ' zOffset')
                end
            )
            nextRow()

            drawAccordion("transform",
                function(_clicked)
                    nextRow()

                    if ui.button(x, y, 120, 'flipX') then
                        state.selection.selectedObj = objectManager.flipThing(thing, 'x', true)
                    end
                    local slx3, sly3 = ui.sameLine()
                    if ui.button(slx3, sly3, 120, 'flipY') then
                        state.selection.selectedObj = objectManager.flipThing(thing, 'y', true)
                    end


                    nextRow()
                    if shapeType == 'circle' then
                        -- Show radius control for circles


                        local newRadius = ui.sliderWithInput(myID .. ' radius', x, y, ROW_WIDTH, 1, 200, thing.radius)
                        ui.alignedLabel(x, y, ' radius')
                        if newRadius and newRadius ~= thing.radius then
                            state.selection.selectedObj = objectManager.recreateThingFromBody(body,
                                { shapeType = "circle", radius = newRadius })
                            state.editorPreferences.lastUsedRadius = newRadius
                            body = state.selection.selectedObj.body
                        end
                    elseif shapeType == 'rectangle' or shapeType == 'itriangle' then
                        -- Show width and height controls for these shapes


                        local newWidth = ui.sliderWithInput(myID .. ' width', x, y, ROW_WIDTH, 1, 800, thing.width)
                        ui.alignedLabel(x, y, ' width')
                        nextRow()

                        local newHeight = ui.sliderWithInput(myID .. ' height', x, y, ROW_WIDTH, 1, 800, thing.height)
                        ui.alignedLabel(x, y, ' height')

                        if (newWidth and newWidth ~= thing.width) or (newHeight and newHeight ~= thing.height) then
                            state.editorPreferences.lastUsedWidth = newWidth
                            state.editorPreferences.lastUsedHeight = newHeight
                            state.selection.selectedObj = objectManager.recreateThingFromBody(body, {
                                shapeType = shapeType,
                                width = newWidth or thing.width,
                                height = newHeight or thing.height,
                            })
                            body = state.selection.selectedObj.body
                        end
                    elseif shapeType == 'torso' then
                        local newWidth = ui.sliderWithInput(myID .. ' width', x, y, ROW_WIDTH, 1, 800, thing.width)
                        ui.alignedLabel(x, y, ' width')
                        nextRow()

                        local newWidth2 = ui.sliderWithInput(myID .. ' width2', x, y, ROW_WIDTH, 1, 800, thing.width2)
                        ui.alignedLabel(x, y, ' width2')
                        nextRow()

                        local newWidth3 = ui.sliderWithInput(myID .. ' width3', x, y, ROW_WIDTH, 1, 800, thing.width3)
                        ui.alignedLabel(x, y, ' width3')
                        nextRow()

                        local newHeight = ui.sliderWithInput(myID .. ' height', x, y, ROW_WIDTH, 1, 800, thing.height)
                        ui.alignedLabel(x, y, ' height')
                        nextRow()
                        local newHeight2 = ui.sliderWithInput(
                            myID .. ' height2', x, y, ROW_WIDTH, 1, 800, thing.height2)
                        ui.alignedLabel(x, y, ' height2')
                        nextRow()
                        local newHeight3 = ui.sliderWithInput(
                            myID .. ' height3', x, y, ROW_WIDTH, 1, 800, thing.height3)
                        ui.alignedLabel(x, y, ' height3')
                        nextRow()
                        local newHeight4 = ui.sliderWithInput(
                            myID .. ' height4', x, y, ROW_WIDTH, 1, 800, thing.height4)
                        ui.alignedLabel(x, y, ' height4')
                        nextRow()

                        if (newWidth and newWidth ~= thing.width) or
                            (newWidth2 and newWidth2 ~= thing.width2) or
                            (newWidth3 and newWidth3 ~= thing.width3) or
                            (newHeight and newHeight ~= thing.height) or
                            (newHeight2 and newHeight2 ~= thing.height2) or
                            (newHeight3 and newHeight3 ~= thing.height3) or
                            (newHeight4 and newHeight4 ~= thing.height4) then
                            state.editorPreferences.lastUsedWidth = newWidth
                            state.editorPreferences.lastUsedWidth2 = newWidth2
                            state.editorPreferences.lastUsedWidth3 = newWidth3
                            state.editorPreferences.lastUsedHeight = newHeight
                            state.editorPreferences.lastUsedHeight2 = newHeight2
                            state.editorPreferences.lastUsedHeight3 = newHeight3
                            state.editorPreferences.lastUsedHeight4 = newHeight4

                            state.selection.selectedObj = objectManager.recreateThingFromBody(body, {
                                shapeType = shapeType,
                                width = newWidth or thing.width,
                                width2 = newWidth2 or thing.width2,
                                width3 = newWidth3 or thing.width3,
                                height = newHeight or thing.height,
                                height2 = newHeight2 or thing.height2,
                                height3 = newHeight3 or thing.height3,
                                height4 = newHeight4 or thing.height4,
                            })
                            body = state.selection.selectedObj.body
                        end
                    elseif shapeType == 'trapezium' or shapeType == 'capsule' then
                        -- Show width and height controls for these shapes


                        local newWidth = ui.sliderWithInput(myID .. ' width', x, y, ROW_WIDTH, 1, 800, thing.width)
                        ui.alignedLabel(x, y, ' width')
                        nextRow()

                        local newWidth2 = ui.sliderWithInput(myID .. ' width2', x, y, ROW_WIDTH, 1, 800,
                            (thing.width2 or 5))
                        ui.alignedLabel(x, y, ' width2')
                        nextRow()

                        local newHeight = ui.sliderWithInput(myID .. ' height', x, y, ROW_WIDTH, 1, 800, thing.height)
                        ui.alignedLabel(x, y, ' height')

                        if (newWidth and newWidth ~= thing.width)
                            or (newWidth2 and newWidth2 ~= thing.width2)
                            or (newHeight and newHeight ~= thing.height) then
                            state.editorPreferences.lastUsedWidth2 = newWidth2
                            state.editorPreferences.lastUsedWidth = newWidth
                            state.editorPreferences.lastUsedHeight = newHeight
                            state.selection.selectedObj = objectManager.recreateThingFromBody(body, {
                                shapeType = shapeType,
                                width = newWidth or thing.width,
                                width2 = newWidth2 or thing.width2,

                                height = newHeight or thing.height,
                            })
                            body = state.selection.selectedObj.body
                        end
                    else
                        -- For polygonal or other custom shapes, only allow radius control if applicable
                        if shapeType == 'triangle' or shapeType == 'pentagon' or shapeType == 'hexagon' or
                            shapeType == 'heptagon' or shapeType == 'octagon' then
                            nextRow()

                            local newRadius = ui.sliderWithInput(myID .. ' radius', x, y, ROW_WIDTH, 1, 200, thing
                                .radius)
                            ui.alignedLabel(x, y, ' radius')
                            if newRadius and newRadius ~= thing.radius then
                                state.selection.selectedObj = objectManager.recreateThingFromBody(body,
                                    { shapeType = shapeType, radius = newRadius })
                                state.editorPreferences.lastUsedRadius = newRadius
                                body = state.selection.selectedObj.body
                            end
                        else
                            -- No UI controls for custom or unsupported shapes
                            --+ (BUTTON_HEIGHT-ui.fontHeight)(x, y, 'custom')
                            if (state.selection.selectedObj) then
                                if state.selection.selectedObj
                                    and state.selection.selectedObj.shapeType == 'custom'
                                    or state.selection.selectedObj.shapeType == 'ribbon' then
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
                                end
                            end
                        end
                    end

                    nextRow()
                end)
            nextRow()

            drawAccordion("physics",
                function()
                    local bodyFixtures = body:getFixtures()
                    if #bodyFixtures >= 1 then
                        local density = bodyFixtures[1]:getDensity()

                        nextRow()
                        local newDensity = ui.sliderWithInput(myID .. 'density', x, y, ROW_WIDTH, 0, 10, density)
                        if newDensity and density ~= newDensity then
                            for i = 1, #bodyFixtures do
                                bodyFixtures[i]:setDensity(newDensity)
                            end
                        end
                        ui.alignedLabel(x, y, ' density')

                        -- Bounciness Slider
                        local bounciness = bodyFixtures[1]:getRestitution()
                        nextRow()

                        local newBounce = ui.sliderWithInput(myID .. 'bounce', x, y, ROW_WIDTH, 0, 1, bounciness)
                        if newBounce and bounciness ~= newBounce then
                            for i = 1, #bodyFixtures do
                                bodyFixtures[i]:setRestitution(newBounce)
                            end
                        end
                        ui.alignedLabel(x, y, ' bounce')

                        -- Friction Slider
                        local friction = bodyFixtures[1]:getFriction()
                        nextRow()

                        local newFriction = ui.sliderWithInput(myID .. 'friction', x, y, ROW_WIDTH, 0, 1, friction)
                        if newFriction and friction ~= newFriction then
                            for i = 1, #bodyFixtures do
                                bodyFixtures[i]:setFriction(newFriction)
                            end
                        end
                        ui.alignedLabel(x, y, ' friction')
                        nextRow()


                        local fb = thing.body
                        bodyFixtures = fb:getFixtures()
                        local ff = bodyFixtures[1]
                        local firstNonUserdataFixture = ff
                        for k = 1, #bodyFixtures do
                            local fixture = bodyFixtures[k]
                            if fixture:getUserData() == nil then
                                firstNonUserdataFixture = fixture
                                break
                            end
                        end
                        local groupIndex = ff:getGroupIndex()
                        local groupIndexSlider = ui.sliderWithInput(myID .. 'groupIndex', x, y, 160, -32768, 32767,
                            groupIndex, false, 1)
                        ui.alignedLabel(x, y, ' groupid')
                        if groupIndexSlider then
                            local value = math.floor(groupIndexSlider)
                            local count = 0

                            local b = thing.body
                            local grpFixtures = b:getFixtures()
                            for j = 1, #grpFixtures do
                                grpFixtures[j]:setGroupIndex(value)
                                count = count + 1
                            end
                        end
                        nextRow()
                        if ui.checkbox(x, y, firstNonUserdataFixture:isSensor(), 'sensor') then
                            -- ff:setSensor(not ff:isSensor())
                            local b = thing.body
                            local sensorFixtures = b:getFixtures()
                            local value = not firstNonUserdataFixture:isSensor()
                            for j = 1, #sensorFixtures do
                                if not sensorFixtures[j]:getUserData() then
                                    sensorFixtures[j]:setSensor(value)
                                end
                            end
                        end
                    end

                    nextRow()
                    -- body:setAngularDamping(1)
                    -- body:setLinearDamping(1)
                    --
                    local angleDamp = tonumber(body:getAngularDamping())
                    local newAngularDamping = ui.sliderWithInput(myID .. 'angd', x, y, ROW_WIDTH, 0, 10, angleDamp,
                        body:isAwake() and not state.world.paused)
                    if newAngularDamping and angleDamp ~= newAngularDamping then
                        body:setAngularDamping(newAngularDamping)
                    end
                    ui.alignedLabel(x, y, ' ang-damping')
                    nextRow()

                    local linDamp = tonumber(body:getLinearDamping())
                    local newLinearDamping = ui.sliderWithInput(myID .. 'lind', x, y, ROW_WIDTH, 0, 10, linDamp,
                        body:isAwake() and not state.world.paused)
                    if newLinearDamping and linDamp ~= newLinearDamping then
                        body:setLinearDamping(newLinearDamping)
                    end
                    ui.alignedLabel(x, y, ' lin-damping')
                    nextRow()
                end)
            nextRow()

            drawAccordion("motion",
                function()
                    -- set sleeping allowed
                    nextRow()
                    local sleepDirty = ui.checkbox(x, y, body:isSleepingAllowed(), 'sleep ok')
                    if sleepDirty then
                        body:setSleepingAllowed(not body:isSleepingAllowed())
                    end
                    nextRow()
                    -- angukar veloicity
                    local angleDegrees = tonumber(math.deg(body:getAngularVelocity()))
                    if math.abs(angleDegrees) < 0.001 then angleDegrees = 0 end
                    local newAngle = ui.sliderWithInput(myID .. 'angv', x, y, ROW_WIDTH, -180, 180, angleDegrees,
                        body:isAwake() and not state.world.paused)
                    if newAngle and angleDegrees ~= newAngle then
                        body:setAngularVelocity(math.rad(newAngle))
                    end
                    ui.alignedLabel(x, y, ' ang-vel')

                    nextRow()
                    local bulletDirty = ui.checkbox(x, y, body:isBullet(), 'bullet')
                    if bulletDirty then
                        body:setBullet(not body:isBullet())
                    end

                    nextRow()
                end
            )
            nextRow()

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

                                    if ui.button(x, y, 260, jointLabel) then
                                        state.selection.selectedJoint = joint
                                        --  state.selection.selectedObj = nil
                                    end

                                    local clicked, _, _, isHover = ui.button(x, y, 260, jointLabel)

                                    if clicked then
                                        state.selection.selectedJoint = joint
                                    end
                                    if isHover then
                                        local x1, y1, x2, y2 = joint:getAnchors()
                                        -- local centroid = fixtures.getCentroidOfFixture(body, myfixtures[i])
                                        --  local x2, y2 = body:getLocalPoint(ud.offsetA.x, ud.offsetA.y)
                                        local ax3, ay3 = cam:getScreenCoordinates(x1, y1)
                                        love.graphics.circle('line', ax3, ay3, 6)
                                        local bx3, by3 = cam:getScreenCoordinates(x2, y2)
                                        love.graphics.circle('line', bx3, by3, 3)
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

                            local subtype = myfixtures[i]:getUserData().subtype or myfixtures[i]:getUserData().extra
                                .type

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
                                local x3, y3 = cam:getScreenCoordinates(x2, y2)
                                love.graphics.circle('line', x3, y3, 3)
                            end
                        end
                    end)

                nextRow()
            end
        end

        nextRow()

        -- List Attached Joints Using Body:getJoints()
    end)
end

return lib

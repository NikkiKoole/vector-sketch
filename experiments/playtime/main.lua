-- main.lua
package.path = package.path .. ";../../?.lua"

-- todo extract jsut the camera stuff i need nowadasy from these files and wrap it in one package
local cam = require('lib.cameraBase').getInstance()
local camera = require 'lib.camera'
-- todo extract just the routines i need nowadays.. (render box2d world debug draw, something about pointer)
local phys = require 'lib.mainPhysics'
local blob = require 'vendor.loveblobs'
local inspect = require 'vendor.inspect'

local ui = require 'src.ui-all'
local joint = require 'src.joints'
local shapes = require 'src.shapes'
local selectrect = require 'src.selection-rect'
local io = require 'src.io'
local uuid = require 'src.uuid'
local registry = require 'src.registry'
local script = require 'src.script'
local objectManager = require 'src.object-manager'

---- todo
-- offsetA & offsetB now use a rotation that needs to be done in the other direction too.
-- it feels its not needed. per se

-- a factory that creates new objects ..
-- floaty karlsson ting


function waitForEvent()
    local a, b, c, d, e
    repeat
        a, b, c, d, e = love.event.wait()
    until a == "focus" or a == 'mousepressed' or a == 'touchpressed'
end

waitForEvent()

local function generateID()
    return uuid.uuid()
end
local function shallowCopy(original)
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = value
    end
    -- setmetatable(copy, getmetatable(original))
    return copy
end
-- Function to compare two tables for equality (assuming they are arrays of numbers)
local function tablesEqualNumbers(t1, t2)
    -- Check if both tables have the same number of elements
    if #t1 ~= #t2 then
        return false
    end

    -- Compare each corresponding element
    for i = 1, #t1 do
        if t1[i] ~= t2[i] then
            return false
        end
    end

    -- All elements are equal
    return true
end

local PANEL_WIDTH = 300
local BUTTON_HEIGHT = 40
local ROW_WIDTH = 160
local BUTTON_SPACING = 10
local FIXED_TIMESTEP = true
local TICKRATE = 1 / 60

function love.load()
    -- Load and set the font
    local font = love.graphics.newFont('assets/cooper_bold_bt.ttf', 30)
    love.keyboard.setKeyRepeat(true)
    love.graphics.setFont(font)

    -- Initialize UI
    ui.init(font)

    bodyTypes = { 'dynamic', 'kinematic', 'static' }

    uiState = {
        lastUsedRadius = 20,
        lastUsedWidth = 40,
        lastUsedHeight = 40,
        showGrid = false,
        radiusOfNextSpawn = 100,
        bodyTypeOfNextSpawn = 'dynamic',
        addShapeOpened = false,
        addJointOpened = false,
        worldSettingsOpened = false,
        maybeHideSelectedPanel = false,
        currentlySelectedJoint = nil,
        currentlySettingOffsetAFunction = nil,
        currentlySelectedObject = nil,
        currentlyDraggingObject = nil,
        offsetForCurrentlyDragging = { nil, nil },
        worldText = '',
        jointCreationMode = nil,
        jointUpdateMode = nil,
        isDrawingFreeformPolygon = false,
        isDrawingClickPlacePolygon = false,
        customPolygonLockedVerts = true,
        customPolygonDraggingVertexIndex = 0,
        customPolygonTempVertices = nil, -- used when dragging a vertex
        customPolygonCXCY = nil,
        polygonVertices = {},
        minPointDistance = 50, -- Default minimum distance
        lastPolygonPoint = nil,
        lastSelectedBody = nil,
        selectedBodies = nil,
        lastSelectedJoint = nil,
        saveDialogOpened = false,
        saveName = 'untitled'
    }

    worldState = {
        meter = 100,
        paused = true,
        gravity = 9.80,
        mouseForce = 500000,
        mouseDamping = 0.5
    }

    sceneScript = nil


    love.physics.setMeter(worldState.meter)
    --world = love.physics.newWorld(0, worldState.gravity * love.physics.getMeter(), true)
    phys.setupWorldWithGravity(worldState.meter, worldState.gravity)

    local w, h = love.graphics.getDimensions()
    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(325, 325, 2000, 2000)

    objectManager.addThing('rectangle', 200, 400, 'dynamic', 100, 400)
    objectManager.addThing('rectangle', 600, 400, 'dynamic', 100)
    -- -- addThing('rectangle', 450, 800, 'kinematic', 200)
    -- -- addThing('rectangle', 850, 800, 'static', 200)
    objectManager.addThing('rectangle', 250, 1000, 'static', 100, 1800)
    -- -- addThing('rectangle', 1100, 100, 'dynamic', 300)
    objectManager.addThing('circle', 1000, 400, 'dynamic', 100)
    objectManager.addThing('circle', 1300, 400, 'dynamic', 100)


    -- -- Adding custom polygon
    local customVertices = {
        0, 0,
        100, 0,
        50, 500,
        -- Add more vertices as needed
    }
    objectManager.addThing('custom', 500, 500, 'dynamic', nil, nil, nil, 'CustomShape', customVertices)

    softbodies = {}

    playWithSoftbodies = false
    if playWithSoftbodies then
        local b = blob.softbody(world, 500, 0, 102, 2, 4)
        b:setFrequency(1)
        b:setDamping(0.1)
        b:setFriction(1)

        table.insert(softbodies, b)
        local points = {
            0, 500, 800, 500,
            800, 800, 0, 800
        }
        local b = blob.softsurface(world, points, 64, "static")
        table.insert(softbodies, b)
    end
end

function finalizeSpawn()
    if uiState.currentlyDraggingObject then
        uiState.currentlyDraggingObject.body:setAwake(true)

        uiState.currentlySelectedObject = uiState.currentlyDraggingObject
        uiState.currentlyDraggingObject = nil
    end
end

local function sanitizeString(input)
    if not input then return "" end   -- Handle nil or empty strings
    return input:gsub("[%c%s]+$", "") -- Remove control characters and trailing spaces
end

function finalizePolygon()
    if #uiState.polygonVertices >= 6 then
        -- Proceed to triangulate and create the physics body
        --
        local cx, cy = shapes.computeCentroid(uiState.polygonVertices)
        objectManager.addThing('custom', cx, cy, uiState.bodyTypeOfNextSpawn, nil, nil, nil, '', uiState.polygonVertices)
        --shapes.createPolygonShape(uiState.polygonVertices)
    else
        -- Not enough vertices to form a polygon
        print("Not enough vertices to create a polygon.")
    end
    -- Reset the drawing state
    uiState.isDrawingClickPlacePolygon = false
    uiState.isDrawingFreeformPolygon = false
    uiState.isCapturingPolygon = false
    uiState.polygonVertices = {}
    uiState.lastPolygonPoint = nil
end

function rotatePoint(x, y, originX, originY, angle)
    -- Translate the point to the origin
    local translatedX = x - originX
    local translatedY = y - originY

    -- Apply rotation
    local rotatedX = translatedX * math.cos(angle) - translatedY * math.sin(angle)
    local rotatedY = translatedX * math.sin(angle) + translatedY * math.cos(angle)

    -- Translate back to the original position
    local finalX = rotatedX + originX
    local finalY = rotatedY + originY

    return finalX, finalY
end

function love.update(dt)
    if not worldState.paused then
        -- for i, v in ipairs(softbodies) do
        --     v:update(dt)
        -- end

        for i = 1, 1 do
            world:update(dt)
        end

        if sceneScript and sceneScript.update then
            sceneScript.update()
        end
    end
    phys.handleUpdate(dt)

    if uiState.currentlyDraggingObject then
        local mx, my = love.mouse.getPosition()
        local wx, wy = cam:getWorldCoordinates(mx, my)
        local offx = uiState.offsetForCurrentlyDragging[1]
        local offy = uiState.offsetForCurrentlyDragging[2]
        local rx, ry = rotatePoint(offx, offy, 0, 0, uiState.currentlyDraggingObject.body:getAngle())
        local oldPosX, oldPosY = uiState.currentlyDraggingObject.body:getPosition()
        uiState.currentlyDraggingObject.body:setPosition(wx + rx, wy + ry)

        -- figure out if we are dragging a group!
        if uiState.selectedBodies then
            for i = 1, #uiState.selectedBodies do
                if (uiState.selectedBodies[i] == uiState.currentlyDraggingObject) then
                    local newPosX, newPosY = uiState.currentlyDraggingObject.body:getPosition()
                    local dx = newPosX - oldPosX
                    local dy = newPosY - oldPosY
                    for j = 1, #uiState.selectedBodies do
                        if (uiState.selectedBodies[j] ~= uiState.currentlyDraggingObject) then
                            local oldPosX, oldPosY = uiState.selectedBodies[j].body:getPosition()
                            uiState.selectedBodies[j].body:setPosition(oldPosX + dx, oldPosY + dy)
                        end
                    end
                end
            end
        end
    end
end

local function drawAddShapeUI()
    local shapeTypes = { 'circle', 'triangle', 'itriangle', 'capsule', 'trapezium', 'rectangle', 'pentagon',
        'hexagon',
        'heptagon',
        'octagon' }
    local titleHeight = ui.font:getHeight() + BUTTON_SPACING
    local startX = 20
    local startY = 70
    local panelWidth = 200
    local buttonSpacing = BUTTON_SPACING
    local buttonHeight = ui.theme.button.height
    local panelHeight = titleHeight + ((#shapeTypes + 3) * (buttonHeight + buttonSpacing)) + buttonSpacing

    ui.panel(startX, startY, panelWidth, panelHeight, '', function()
        local layout = ui.createLayout({
            type = 'columns',
            spacing = BUTTON_SPACING,
            startX = startX + BUTTON_SPACING,
            startY = startY + BUTTON_SPACING
        })

        local x, y = ui.nextLayoutPosition(layout, panelWidth - 20, buttonHeight)

        if ui.button(x, y, 180, uiState.bodyTypeOfNextSpawn) then
            local index = -1
            for i, v in ipairs(bodyTypes) do
                if uiState.bodyTypeOfNextSpawn == v then
                    index = i
                end
            end
            uiState.bodyTypeOfNextSpawn = bodyTypes[index % #bodyTypes + 1]
        end

        for _, shape in ipairs(shapeTypes) do
            local width = panelWidth - 20
            local height = buttonHeight
            x, y = ui.nextLayoutPosition(layout, width, height)
            local _, pressed, released = ui.button(x, y, width, shape)
            if pressed then
                ui.draggingActive = ui.activeElementID
                local mx, my = love.mouse.getPosition()
                local wx, wy = cam:getWorldCoordinates(mx, my)
                objectManager.startSpawn(shape, wx, wy)
            end
            if released then
                ui.draggingActive = nil
            end
        end

        local width = panelWidth - 20
        local height = buttonHeight
        x, y = ui.nextLayoutPosition(layout, width, height)
        local minDist = ui.sliderWithInput('minDistance', x, y, 80, 1, 150, uiState.minPointDistance or 10)
        ui.label(x, y, 'dis')
        if minDist then
            uiState.minPointDistance = minDist
        end

        -- Add a button for custom polygon
        x, y = ui.nextLayoutPosition(layout, width, height)
        if ui.button(x, y, width, 'freeform') then
            uiState.isDrawingFreeformPolygon = true
            uiState.polygonVertices = {}
            uiState.lastPolygonPoint = nil
        end

        x, y = ui.nextLayoutPosition(layout, width, height)
        if ui.button(x, y, width, 'click') then
            uiState.isDrawingClickPlacePolygon = true
            uiState.polygonVertices = {}
            uiState.lastPolygonPoint = nil
        end
    end)
end

local function drawUpdateSelectedObjectUI()
    local panelWidth = PANEL_WIDTH
    local w, h = love.graphics.getDimensions()
    ui.panel(w - panelWidth - 20, 20, panelWidth, h - 40, '∞ body props ∞', function()
        local body = uiState.currentlySelectedObject.body
        local angleDegrees = body:getAngle() * 180 / math.pi
        local myID = uiState.currentlySelectedObject.id

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
        x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)

        local nextRow = function()
            x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
        end
        if ui.button(x, y, 260, currentBodyType) then
            body:setType(nextBodyType)
            body:setAwake(true)
        end



        local userData = body:getUserData()
        local thing = userData and userData.thing

        local dirtyBodyChange = false
        if (uiState.lastSelectedBody ~= body) then
            dirtyBodyChange = true
            uiState.lastSelectedBody = body
        end

        if thing then
            -- Shape Properties
            local shapeType = thing.shapeType

            -- Label Editor
            nextRow()
            local newLabel = ui.textinput(myID .. ' label', x, y, 260, 40, "", thing.label)
            if newLabel and newLabel ~= thing.label then
                thing.label = newLabel -- Update the label
            end

            nextRow()

            if shapeType == 'circle' then
                -- Show radius control for circles
                nextRow()

                local newRadius = ui.sliderWithInput(myID .. ' radius', x, y, ROW_WIDTH, 1, 200, thing.radius)
                ui.label(x, y, ' radius')
                if newRadius and newRadius ~= thing.radius then
                    uiState.currentlySelectedObject = objectManager.recreateThingFromBody(body,
                        { shapeType = "circle", radius = newRadius })
                    uiState.lastUsedRadius = newRadius
                    body = uiState.currentlySelectedObject.body
                end
            elseif shapeType == 'rectangle' or shapeType == 'capsule' or shapeType == 'trapezium' or shapeType == 'itriangle' then
                -- Show width and height controls for these shapes
                nextRow()

                local newWidth = ui.sliderWithInput(myID .. ' width', x, y, ROW_WIDTH, 1, 800, thing.width)
                ui.label(x, y, ' width')
                nextRow()

                local newHeight = ui.sliderWithInput(myID .. ' height', x, y, ROW_WIDTH, 1, 800, thing.height)
                ui.label(x, y, ' height')

                if (newWidth and newWidth ~= thing.width) or (newHeight and newHeight ~= thing.height) then
                    uiState.lastUsedWidth = newWidth
                    uiState.lastUsedHeight = newHeight
                    uiState.currentlySelectedObject = objectManager.recreateThingFromBody(body, {
                        shapeType = shapeType,
                        width = newWidth or thing.width,
                        height = newHeight or thing.height,
                    })
                    body = uiState.currentlySelectedObject.body
                end
            else
                -- For polygonal or other custom shapes, only allow radius control if applicable
                if shapeType == 'triangle' or shapeType == 'pentagon' or shapeType == 'hexagon' or
                    shapeType == 'heptagon' or shapeType == 'octagon' then
                    nextRow()

                    local newRadius = ui.sliderWithInput(myID .. ' radius', x, y, ROW_WIDTH, 1, 200, thing.radius,
                        dirtyBodyChange)
                    ui.label(x, y, ' radius')
                    if newRadius and newRadius ~= thing.radius then
                        uiState.currentlySelectedObject = objectManager.recreateThingFromBody(body,
                            { shapeType = shapeType, radius = newRadius })
                        uiState.lastUsedRadius = newRadius
                        body = uiState.currentlySelectedObject.body
                    end
                else
                    -- No UI controls for custom or unsupported shapes
                    --ui.label(x, y, 'custom')
                    if ui.button(x, y, 260, uiState.customPolygonLockedVerts and 'verts locked' or 'verts unlocked') then
                        uiState.customPolygonLockedVerts = not uiState.customPolygonLockedVerts
                        if uiState.customPolygonLockedVerts == false then
                            uiState.customPolygonTempVertices = shallowCopy(uiState.currentlySelectedObject.vertices)
                            local cx, cy = shapes.computeCentroid(uiState.currentlySelectedObject.vertices)
                            uiState.customPolygonCXCY = { x = cx, y = cy }
                        else
                            uiState.customPolygonTempVertices = nil
                            uiState.customPolygonCXCY = nil
                        end
                    end
                end
            end
        end
        nextRow()

        local dirty, checked = ui.checkbox(x, y, body:isFixedRotation(), 'fixed angle')
        if dirty then
            body:setFixedRotation(not body:isFixedRotation())
        end

        -- Angle Slider
        nextRow()

        local newAngle = ui.sliderWithInput(myID .. 'angle', x, y, ROW_WIDTH, -180, 180, angleDegrees,
            body:isAwake() and not worldState.paused)
        if newAngle and angleDegrees ~= newAngle then
            body:setAngle(newAngle * math.pi / 180)
        end
        ui.label(x, y, ' angle')

        -- Density Slider
        local fixtures = body:getFixtures()
        if #fixtures >= 1 then
            local density = fixtures[1]:getDensity()
            nextRow()

            local newDensity = ui.sliderWithInput(myID .. 'density', x, y, ROW_WIDTH, 0, 10, density)
            if newDensity and density ~= newDensity then
                for i = 1, #fixtures do
                    fixtures[i]:setDensity(newDensity)
                end
            end
            ui.label(x, y, ' density')

            -- Bounciness Slider
            local bounciness = fixtures[1]:getRestitution()
            nextRow()

            local newBounce = ui.sliderWithInput(myID .. 'bounce', x, y, ROW_WIDTH, 0, 1, bounciness)
            if newBounce and bounciness ~= newBounce then
                for i = 1, #fixtures do
                    fixtures[i]:setRestitution(newBounce)
                end
            end
            ui.label(x, y, ' bounce')

            -- Friction Slider
            local friction = fixtures[1]:getFriction()
            nextRow()

            local newFriction = ui.sliderWithInput(myID .. 'friction', x, y, ROW_WIDTH, 0, 1, friction)
            if newFriction and friction ~= newFriction then
                for i = 1, #fixtures do
                    fixtures[i]:setFriction(newFriction)
                end
            end
            ui.label(x, y, ' friction')
        end
        nextRow()
        -- set sleeping allowed
        local dirty, checked = ui.checkbox(x, y, body:isSleepingAllowed(), 'sleep ok')
        if dirty then
            body:setSleepingAllowed(not body:isSleepingAllowed())
        end
        nextRow()
        -- angukar veloicity
        local angleDegrees = tonumber(math.deg(body:getAngularVelocity()))
        if math.abs(angleDegrees) < 0.001 then angleDegrees = 0 end
        local newAngle = ui.sliderWithInput(myID .. 'angv', x, y, ROW_WIDTH, -180, 180, angleDegrees,
            body:isAwake() and not worldState.paused)
        if newAngle and angleDegrees ~= newAngle then
            body:setAngularVelocity(math.rad(newAngle))
        end
        ui.label(x, y, ' ang-vel')

        nextRow()
        if ui.button(x, y, 260, 'destroy') then
            objectManager.destroyBody(body)

            uiState.currentlySelectedObject = nil
        end

        -- List Attached Joints Using Body:getJoints()
        if not body:isDestroyed() then
            local attachedJoints = body:getJoints()
            if attachedJoints and #attachedJoints > 0 and not (#attachedJoints == 1 and attachedJoints[1]:getType() == 'mouse') then
                ui.label(x, y + 60, '∞ joints ∞')
                nextRow()
                -- layout:nextRow()

                for _, joint in ipairs(attachedJoints) do
                    -- Display joint type and unique identifier for identification
                    local jointType = joint:getType()
                    local jointID = tostring(joint)
                    if (jointType ~= 'mouse') then
                        -- Display joint button
                        x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT - 10)
                        local jointLabel = string.format("%s", jointType)

                        if ui.button(x, y, ROW_WIDTH, jointLabel) then
                            uiState.currentlySelectedJoint = joint
                            uiState.currentlySelectedObject = nil
                        end
                    end
                end
            end
        end
    end)
end

local function drawGrid(cam, worldState)
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, .1)

    local w, h = love.graphics.getDimensions()
    local tlx, tly = cam:getWorldCoordinates(0, 0)
    local brx, bry = cam:getWorldCoordinates(w, h)
    local step = worldState.meter
    local startX = math.floor(tlx / step) * step
    local endX = math.ceil(brx / step) * step
    local startY = math.floor(tly / step) * step
    local endY = math.ceil(bry / step) * step

    for i = startX, endX, step do
        local x, _ = cam:getScreenCoordinates(i, 0)
        love.graphics.line(x, 0, x, h)
    end
    for i = startY, endY, step do
        local _, y = cam:getScreenCoordinates(0, i)
        love.graphics.line(0, y, w, y)
    end
    love.graphics.setLineWidth(lw)
    love.graphics.setColor(1, 1, 1)
end

function drawUI()
    ui.startFrame()
    local w, h = love.graphics.getDimensions()
    love.graphics.rectangle('line', 10, 10, w - 20, h - 20, 20, 20)

    -- "Add Shape" Button
    if ui.button(20, 20, 200, 'add shape') then
        uiState.addShapeOpened = not uiState.addShapeOpened
    end

    if uiState.addShapeOpened then
        drawAddShapeUI()
    end

    -- "Add Joint" Button
    if ui.button(230, 20, 200, 'add joint') then
        uiState.addJointOpened = not uiState.addJointOpened
    end

    if uiState.addJointOpened then
        local jointTypes = { 'distance', 'weld', 'rope', 'revolute', 'wheel', 'motor', 'prismatic', 'pulley' }
        local titleHeight = ui.font:getHeight() + BUTTON_SPACING
        local startX = 230
        local startY = 70
        local panelWidth = 200
        local buttonSpacing = BUTTON_SPACING
        local buttonHeight = ui.theme.button.height
        local panelHeight = titleHeight + (#jointTypes * (buttonHeight + BUTTON_SPACING))

        ui.panel(startX, startY, panelWidth, panelHeight, '', function()
            local layout = ui.createLayout({
                type = 'columns',
                spacing = buttonSpacing,
                startX = startX + BUTTON_SPACING,
                startY = startY + BUTTON_SPACING
            })
            for _, joint in ipairs(jointTypes) do
                local width = panelWidth - 20
                local height = buttonHeight
                local x, y = ui.nextLayoutPosition(layout, width, height)
                local jointStarted = ui.button(x, y, width, joint)
                if jointStarted then
                    uiState.jointCreationMode = { body1 = nil, body2 = nil, jointType = joint }
                end
            end
        end)
    end

    -- "World Settings" Button
    if ui.button(440, 20, 300, 'world settings') then
        uiState.worldSettingsOpened = not uiState.worldSettingsOpened
    end

    if uiState.worldSettingsOpened then
        local startX = 440
        local startY = 70
        local panelWidth = PANEL_WIDTH
        local panelHeight = 400
        local buttonSpacing = BUTTON_SPACING
        local titleHeight = ui.font:getHeight() + BUTTON_SPACING

        ui.panel(startX, startY, panelWidth, panelHeight, '• ∫ƒF world •', function()
            local layout = ui.createLayout({
                type = 'columns',
                spacing = BUTTON_SPACING,
                startX = startX + BUTTON_SPACING,
                startY = startY + titleHeight + BUTTON_SPACING
            })
            local width = panelWidth - BUTTON_SPACING * 2

            local x, y = ui.nextLayoutPosition(layout, width, BUTTON_HEIGHT)

            --  x, y = ui.nextLayoutPosition(layout, width, 50)
            local grav = ui.sliderWithInput('grav', x, y, ROW_WIDTH, -10, BUTTON_HEIGHT, worldState.gravity)
            if grav then
                worldState.gravity = grav
                if world then
                    world:setGravity(0, worldState.gravity * worldState.meter)
                end
            end
            ui.label(x, y, ' gravity')

            x, y = ui.nextLayoutPosition(layout, width, BUTTON_HEIGHT)
            local g, value = ui.checkbox(x, y, uiState.showGrid, 'grid') --showGrid = true,
            if g then
                uiState.showGrid = value
            end


            x, y = ui.nextLayoutPosition(layout, width, BUTTON_HEIGHT)
            local mouseForce = ui.sliderWithInput(' mouse F', x, y, ROW_WIDTH, 0, 1000000, worldState.mouseForce)
            if mouseForce then
                worldState.mouseForce = mouseForce
            end
            ui.label(x, y, ' mouse F')
            x, y = ui.nextLayoutPosition(layout, width, BUTTON_HEIGHT)
            local mouseDamp = ui.sliderWithInput(' damp', x, y, ROW_WIDTH, 0.001, 1, worldState.mouseDamping)
            if mouseDamp then
                worldState.mouseDamping = mouseDamp
            end
            ui.label(x, y, ' damp')

            x, y = ui.nextLayoutPosition(layout, width, BUTTON_HEIGHT)
            local t = ui.textinput('worldText', x, y, 280, 70, 'add text...', uiState.worldText)
            if t then
                uiState.worldText = t
            end
        end)
    end

    -- Play/Pause Button
    if ui.button(750, 20, 150, worldState.paused and 'play' or 'pause') then
        worldState.paused = not worldState.paused
    end

    if sceneScript and sceneScript.onStart then
        if ui.button(920, 20, 50, 'R') then
            sceneScript.onStart()
        end
    end

    if uiState.currentlySelectedObject and not uiState.currentlySelectedJoint then
        drawUpdateSelectedObjectUI()
    end


    if uiState.isDrawingClickPlacePolygon then
        local panelWidth = PANEL_WIDTH
        local w, h = love.graphics.getDimensions()
        ui.panel(w - panelWidth - 20, 20, panelWidth, h - 40, '∞ click draw vertex polygon ∞', function()
            local padding = BUTTON_SPACING
            local layout = ui.createLayout({
                type = 'columns',
                spacing = BUTTON_SPACING,
                startX = w - panelWidth,
                startY = 100 + padding
            })
            x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
            if ui.button(x, y, 260, 'finalize') then
                finalizePolygon()
                --local cloned = io.cloneSelection(uiState.selectedBodies)
                -- uiState.selectedBodies = cloned
            end
        end)
    end

    if uiState.selectedBodies and #uiState.selectedBodies > 0 then
        local panelWidth = PANEL_WIDTH
        local w, h = love.graphics.getDimensions()
        ui.panel(w - panelWidth - 20, 20, panelWidth, h - 40, '∞ selection ∞', function()
            local padding = BUTTON_SPACING
            local layout = ui.createLayout({
                type = 'columns',
                spacing = BUTTON_SPACING,
                startX = w - panelWidth,
                startY = 100 + padding
            })

            x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)


            if ui.button(x, y, 260, 'clone') then
                local cloned = io.cloneSelection(uiState.selectedBodies)
                uiState.selectedBodies = cloned
            end
            x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
            if ui.button(x, y, 260, 'destroy') then
                for i = #uiState.selectedBodies, 1, -1 do
                    objectManager.destroyBody(uiState.selectedBodies[i].body)
                end
                uiState.selectedBodies = nil
            end
            x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
        end)
    end


    if uiState.jointCreationMode and uiState.jointCreationMode.body1 and uiState.jointCreationMode.body2 then
        joint.doJointCreateUI(uiState, 500, 100, 400, 150)
    end

    if uiState.currentlySelectedJoint then
        -- (w - panelWidth - 20, 20, panelWidth, h - 40
        joint.doJointUpdateUI(uiState, uiState.currentlySelectedJoint, w - PANEL_WIDTH - 20, 20, PANEL_WIDTH, h - 40)
    end

    if uiState.jointCreationMode and ((uiState.jointCreationMode.body1 == nil) or (uiState.jointCreationMode.body2 == nil)) then
        if (uiState.jointCreationMode.body1 == nil) then
            ui.panel(500, 100, 300, 100, '• pick 1st body •', function()
                local x = 510
                local y = 150
                local width = 280
                if ui.button(x, y, width, 'cancel') then
                    uiState.jointCreationMode = nil
                end
            end)
        elseif (uiState.jointCreationMode.body2 == nil) then
            ui.panel(500, 100, 300, 100, '• pick 2nd body •', function()
                local x = 510
                local y = 150
                local width = 280
                if ui.button(x, y, width, 'cancel') then
                    uiState.jointCreationMode = nil
                end
            end)
        end
    end

    if uiState.saveDialogOpened then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle('fill', 0, 0, w, h)
        love.graphics.setColor(1, 1, 1)
        ui.panel(300, 300, w - 600, h - 600, '»»» save «««', function()
            local t = ui.textinput('savename', 320, 350, w - 640, 40, 'add text...', uiState.saveName)
            if t then
                uiState.saveName = sanitizeString(t)
            end
            if ui.button(320, 500, 200, 'save') then
                uiState.saveDialogOpened = false
                io.save(world, worldState, uiState.saveName)
            end
            if ui.button(540, 500, 200, 'cancel') then
                uiState.saveDialogOpened = false
            end
        end)
    end

    if ui.draggingActive then
        love.graphics.setColor(ui.theme.draggedElement.fill)
        local x, y = love.mouse.getPosition()
        love.graphics.circle('fill', x, y, 10)
        love.graphics.setColor(1, 1, 1)
    end
end

local function getLocalVerticesForCustomSelected(vertices, obj, cx, cy)
    local verts = vertices
    local offX, offY = obj.body:getPosition()
    local angle = obj.body:getAngle()
    local result = {}

    for i = 1, #verts, 2 do
        local rx, ry = rotatePoint(verts[i] - cx, verts[i + 1] - cy, 0, 0, angle)
        local vx, vy = offX + rx, offY + ry
        table.insert(result, vx)
        table.insert(result, vy)
    end

    return result
end
function love.draw()
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(20 / 255, 5 / 255, 20 / 255)
    if uiState.showGrid then
        drawGrid(cam, worldState)
    end
    cam:push()



    phys.drawWorld(world)

    if sceneScript and sceneScript.draw then
        sceneScript.draw()
    end



    if uiState.currentlySelectedJoint and not uiState.currentlySelectedJoint:isDestroyed() then
        local x1, y1, x2, y2 = uiState.currentlySelectedJoint:getAnchors()
        love.graphics.circle('line', x1, y1, 10)

        love.graphics.line(x2 - 10, y2, x2 + 10, y2)
        love.graphics.line(x2, y2 - 10, x2, y2 + 10)
    end

    local lw = love.graphics.getLineWidth()
    for i, v in ipairs(softbodies) do
        love.graphics.setColor(50 * i / 255, 100 / 255, 200 * i / 255, .8)
        if (tostring(v) == "softbody") then
            v:draw("fill", false)
        else
            v:draw(false)
        end
    end
    love.graphics.setLineWidth(lw)
    love.graphics.setColor(1, 1, 1)


    if uiState.isDrawingFreeformPolygon or uiState.isDrawingClickPlacePolygon then
        if (#uiState.polygonVertices >= 6) then
            love.graphics.polygon('line', uiState.polygonVertices)
        end
    end

    -- draw mousehandlers for dragging vertices
    if uiState.customPolygonTempVertices and uiState.currentlySelectedObject and uiState.currentlySelectedObject.shapeType == 'custom' and uiState.customPolygonLockedVerts == false then
        local verts = getLocalVerticesForCustomSelected(uiState.customPolygonTempVertices,
            uiState.currentlySelectedObject, uiState.customPolygonCXCY.x, uiState.customPolygonCXCY.y)

        local mx, my = love.mouse:getPosition()
        local cx, cy = cam:getWorldCoordinates(mx, my)

        for i = 1, #verts, 2 do
            local vx = verts[i]
            local vy = verts[i + 1]
            local dist = math.sqrt((cx - vx) ^ 2 + (cy - vy) ^ 2)
            if dist < 10 then
                love.graphics.circle('fill', vx, vy, 10)
            else
                love.graphics.circle('line', vx, vy, 10)
            end
        end
    end
    -- Highlight selected bodies
    if uiState.selectedBodies then
        local lw = love.graphics.getLineWidth()
        love.graphics.setLineWidth(6)
        love.graphics.setColor(1, 0, 1) -- Red outline for selection
        for _, thing in ipairs(uiState.selectedBodies) do
            --local fixtures = body:getFixtures()
            local body = thing.body
            for _, fixture in ipairs(body:getFixtures()) do
                --for fixture in pairs(fixtures) do
                local shape = fixture:getShape()
                love.graphics.push()
                love.graphics.translate(body:getX(), body:getY())
                love.graphics.rotate(body:getAngle())
                if shape:typeOf("CircleShape") then
                    love.graphics.circle("line", 0, 0, shape:getRadius())
                elseif shape:typeOf("PolygonShape") then
                    local points = { shape:getPoints() }
                    love.graphics.polygon("line", points)
                elseif shape:typeOf("EdgeShape") then
                    local x1, y1, x2, y2 = shape:getPoints()
                    love.graphics.line(x1, y1, x2, y2)
                end
                love.graphics.pop()
            end
        end
        love.graphics.setLineWidth(lw)
        love.graphics.setColor(1, 1, 1) -- Reset color
    end

    if uiState.customPolygonTempVertices then
        -- local result = getLocalVerticesForCustomSelected(uiState.customPolygonTempVertices, obj, cx, cy)
        local verts = getLocalVerticesForCustomSelected(uiState.customPolygonTempVertices,
            uiState.currentlySelectedObject, uiState.customPolygonCXCY.x, uiState.customPolygonCXCY.y)

        --uiState.customPolygonTempVertices
        love.graphics.setColor(1, 0, 0)
        love.graphics.polygon('line', verts)
        love.graphics.setColor(1, 1, 1) -- Rese
    end

    cam:pop()
    if uiState.startSelection then
        selectrect.draw(uiState.startSelection)
    end

    drawUI()

    if uiState.maybeHideSelectedPanel then
        if not (ui.activeElementID or ui.focusedTextInputID) then
            uiState.currentlySelectedObject = nil
            uiState.currentlySelectedJoint = nil
        end
        uiState.maybeHideSelectedPanel = false
        uiState.customPolygonTempVertices = nil
        uiState.customPolygonLockedVerts = true
    end

    if FIXED_TIMESTEP then
        love.graphics.print('f' .. string.format("%02d", 1 / TICKRATE), w - 80, 10)
    else
        love.graphics.print(string.format("%03d", love.timer.getFPS()), w - 80, 10)
    end
end

local function maybeUpdateCustomPolygonVertices()
    if not tablesEqualNumbers(uiState.customPolygonTempVertices, uiState.currentlySelectedObject.vertices) then
        local nx, ny = shapes.computeCentroid(uiState.customPolygonTempVertices)
        local ox, oy = shapes.computeCentroid(uiState.currentlySelectedObject.vertices)
        local dx = nx - ox
        local dy = ny - oy
        local body = uiState.currentlySelectedObject.body
        local oldX, oldY = body:getPosition()
        body:setPosition(oldX + dx, oldY + dy)
        uiState.currentlySelectedObject = objectManager.recreateThingFromBody(body,
            { optionalVertices = uiState.customPolygonTempVertices })

        uiState.customPolygonTempVertices = shallowCopy(uiState.currentlySelectedObject.vertices)

        uiState.customPolygonCXCY = { x = nx, y = ny }
    end
end

function love.wheelmoved(dx, dy)
    local newScale = cam.scale * (1 + dy / 10)
    if newScale > 0.01 and newScale < 50 then
        cam:scaleToPoint(1 + dy / 10)
    end
end

function love.mousemoved(x, y, dx, dy)
    if uiState.customPolygonDraggingVertexIndex and uiState.customPolygonDraggingVertexIndex > 0 then
        local index = uiState.customPolygonDraggingVertexIndex
        local obj = uiState.currentlySelectedObject
        local angle = obj.body:getAngle()
        local dx2, dy2 = rotatePoint(dx, dy, 0, 0, -angle)
        dx2 = dx2 / cam.scale
        dy2 = dy2 / cam.scale
        uiState.customPolygonTempVertices[index] = uiState.customPolygonTempVertices[index] + dx2
        uiState.customPolygonTempVertices[index + 1] = uiState.customPolygonTempVertices[index + 1] + dy2
    elseif uiState.isCapturingPolygon then
        local wx, wy = cam:getWorldCoordinates(x, y)
        -- Check if the distance from the last point is greater than minPointDistance
        local addPoint = false
        if not uiState.lastPolygonPoint then
            addPoint = true
        else
            local lastX, lastY = uiState.lastPolygonPoint.x, uiState.lastPolygonPoint.y
            local distSq = (wx - lastX) ^ 2 + (wy - lastY) ^ 2
            if distSq >= (uiState.minPointDistance / cam.scale) ^ 2 then
                addPoint = true
            end
        end
        if addPoint then
            --table.insert(uiState.polygonVertices, { x = wx, y = wy })
            table.insert(uiState.polygonVertices, wx)
            table.insert(uiState.polygonVertices, wy)
            uiState.lastPolygonPoint = { x = wx, y = wy }
        end
    elseif love.mouse.isDown(3) then
        local tx, ty = cam:getTranslation()
        cam:setTranslation(tx - dx / cam.scale, ty - dy / cam.scale)
    end
end

function love.filedropped(file)
    local name = file:getFilename()
    if string.find(name, '.playtime.json') then
        file:open("r")
        local data = file:read()
        uiState.currentlySelectedJoint = nil
        uiState.currentlySelectedObject = nil
        io.load(data, world)
        file:close()
    end
    if string.find(name, '.playtime.lua') then
        file:open("r")
        local data = file:read()

        script.setEnv({ bodies = registry.bodies, joints = registry.joints, world = world, worldState = worldState })
        sceneScript = script.loadScript(data, name)()
        -- print(world)
        if sceneScript and sceneScript.onStart then
            sceneScript.onStart()
        end
        -- print(world)
        file:close()
    end
end

function love.textinput(t)
    ui.handleTextInput(t)
end

-- Function to convert world coordinates to local coordinates of a shape
local function worldToLocal(worldX, worldY, obj, cx, cy)
    -- Get the body's position and angle
    local offX, offY = obj.body:getPosition()
    local angle = obj.body:getAngle()

    -- Step 1: Translate the world point to the body's origin
    local translatedX = worldX - offX
    local translatedY = worldY - offY

    -- Step 2: Rotate the point by -angle to align with the local coordinate system
    local cosA = math.cos(-angle)
    local sinA = math.sin(-angle)
    local rotatedX = translatedX * cosA - translatedY * sinA
    local rotatedY = translatedX * sinA + translatedY * cosA

    -- Step 3: Adjust for the centroid offset
    local localX = rotatedX + cx
    local localY = rotatedY + cy

    return localX, localY
end

local function distancePointToSegment(px, py, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1

    if dx == 0 and dy == 0 then
        -- The segment is a single point
        local dist = math.sqrt((px - x1) ^ 2 + (py - y1) ^ 2)
        return dist, { x = x1, y = y1 }
    end

    -- Calculate the t that minimizes the distance
    local t = ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy)

    -- Clamp t to the [0,1] range
    t = math.max(0, math.min(1, t))

    -- Find the closest point on the segment
    local closestX = x1 + t * dx
    local closestY = y1 + t * dy

    -- Calculate the distance
    local dist = math.sqrt((px - closestX) ^ 2 + (py - closestY) ^ 2)

    return dist, { x = closestX, y = closestY }
end
-- Function to find the closest edge to a given point
-- Returns the index of the first vertex of the closest edge
local function findClosestEdge(verts, px, py)
    local minDist = math.huge
    local closestEdgeIndex = nil

    local numVertices = #verts / 2

    for i = 1, numVertices do
        local j = (i % numVertices) + 1 -- Next vertex (wrap around)
        local x1 = verts[(i - 1) * 2 + 1]
        local y1 = verts[(i - 1) * 2 + 2]
        local x2 = verts[(j - 1) * 2 + 1]
        local y2 = verts[(j - 1) * 2 + 2]

        local dist, _ = distancePointToSegment(px, py, x1, y1, x2, y2)

        if dist < minDist then
            minDist = dist
            closestEdgeIndex = i -- Insert after vertex i
        end
    end

    return closestEdgeIndex
end

local function findClosestVertex(verts, px, py)
    local minDistSq = math.huge
    local closestVertexIndex = nil

    local numVertices = #verts / 2

    for i = 1, numVertices do
        local vx = verts[(i - 1) * 2 + 1]
        local vy = verts[(i - 1) * 2 + 2]
        local dx = px - vx
        local dy = py - vy
        local distSq = dx * dx + dy * dy

        if distSq < minDistSq then
            minDistSq = distSq
            closestVertexIndex = i
        end
    end

    return closestVertexIndex
end
-- Function to remove a vertex from the table based on its vertex index
-- verts: flat list {x1, y1, x2, y2, ...}
-- vertexIndex: the index of the vertex to remove (1, 2, 3, ...)
local function removeVertexAt(verts, vertexIndex)
    local posX = (vertexIndex - 1) * 2 + 1
    local posY = posX + 1

    -- Remove y-coordinate first to prevent shifting issues
    table.remove(verts, posY)
    table.remove(verts, posX)
end

local function insertValuesAt(tbl, pos, val1, val2)
    table.insert(tbl, pos, val1)
    table.insert(tbl, pos + 1, val2)
end

local function insertCustomPolygonVertex(x, y)
    local px, py = worldToLocal(x, y, uiState.currentlySelectedObject, uiState.customPolygonCXCY.x,
        uiState.customPolygonCXCY.y)
    -- Find the closest edge index
    local insertAfterVertexIndex = findClosestEdge(uiState.customPolygonTempVertices, px, py)
    insertValuesAt(uiState.customPolygonTempVertices, insertAfterVertexIndex * 2 + 1, px, py)
end

-- Function to remove a custom polygon vertex based on mouse click
local function removeCustomPolygonVertex(x, y)
    -- Step 1: Convert world coordinates to local coordinates
    local px, py = worldToLocal(x, y, uiState.currentlySelectedObject,
        uiState.customPolygonCXCY.x, uiState.customPolygonCXCY.y)

    -- Step 2: Find the closest vertex index
    local closestVertexIndex = findClosestVertex(uiState.customPolygonTempVertices, px, py)

    if closestVertexIndex then
        -- Optional: Define a maximum allowable distance to consider for deletion
        local maxDeletionDistanceSq = 100 -- Adjust as needed (e.g., 10 units squared)
        local vx = uiState.customPolygonTempVertices[(closestVertexIndex - 1) * 2 + 1]
        local vy = uiState.customPolygonTempVertices[(closestVertexIndex - 1) * 2 + 2]
        local dx = px - vx
        local dy = py - vy
        local distSq = dx * dx + dy * dy

        if distSq <= maxDeletionDistanceSq then
            -- Step 3: Remove the vertex from the vertex list

            -- Step 4: Ensure the polygon has a minimum number of vertices (e.g., 3)
            if #uiState.customPolygonTempVertices <= 6 then
                print("Cannot delete vertex: A polygon must have at least three vertices.")
                -- Optionally, you can restore the removed vertex or prevent deletion
                return
            end
            removeVertexAt(uiState.customPolygonTempVertices, closestVertexIndex)

            maybeUpdateCustomPolygonVertices()

            -- Debugging Output
            print(string.format("Removed vertex at local coordinates: (%.2f, %.2f)", vx, vy))
        else
            print("No vertex close enough to delete.")
        end
    else
        print("No vertex found to delete.")
    end
end

function love.keypressed(key)
    ui.handleKeyPress(key)
    if key == 'escape' then
        love.event.quit()
    end
    if key == 'space' then
        worldState.paused = not worldState.paused
    end
    if key == 'f5' then
        worldState.paused = true
        uiState.saveDialogOpened = true
    end
    if key == 'i' and uiState.customPolygonTempVertices then
        -- figure out where my mousecursor is, between what nodes?
        local mx, my = love.mouse.getPosition()
        local wx, wy = cam:getWorldCoordinates(mx, my)
        insertCustomPolygonVertex(wx, wy)
        maybeUpdateCustomPolygonVertices()
    end
    if key == 'd' and uiState.customPolygonTempVertices then
        -- Remove a vertex
        local mx, my = love.mouse.getPosition()
        local wx, wy = cam:getWorldCoordinates(mx, my)
        removeCustomPolygonVertex(wx, wy)
    end
end

local function handlePointer(x, y, id, action)
    if action == "pressed" then
        -- Handle press logig
        --   -- this will block interacting on bodies when 'roughly' over the opened panel
        if uiState.saveDialogOpened then return end
        if uiState.currentlySelectedJoint or uiState.currentlySelectedObject or uiState.selectedBodies or uiState.isDrawingClickPlacePolygon then
            local w, h = love.graphics.getDimensions()
            if x > w - 300 then
                return
            end
        end

        local startSelection = love.keyboard.isDown('lshift')
        if (startSelection) then
            uiState.startSelection = { x = x, y = y }
        end

        local cx, cy = cam:getWorldCoordinates(x, y)

        if uiState.customPolygonTempVertices and uiState.currentlySelectedObject and uiState.currentlySelectedObject.shapeType == 'custom' and uiState.customPolygonLockedVerts == false then
            local verts = getLocalVerticesForCustomSelected(uiState.customPolygonTempVertices,
                uiState.currentlySelectedObject, uiState.customPolygonCXCY.x, uiState.customPolygonCXCY.y)
            for i = 1, #verts, 2 do
                local vx = verts[i]
                local vy = verts[i + 1]
                local dist = math.sqrt((cx - vx) ^ 2 + (cy - vy) ^ 2)
                if dist < 10 then
                    uiState.customPolygonDraggingVertexIndex = i

                    return
                else
                    uiState.customPolygonDraggingVertexIndex = 0
                end
            end
        end

        if (uiState.isDrawingClickPlacePolygon) then
            -- uiState.polygonVertices
            table.insert(uiState.polygonVertices, cx)
            table.insert(uiState.polygonVertices, cy)
        end
        if (uiState.currentlySettingOffsetAFunction) then
            uiState.currentlySelectedJoint = uiState.currentlySettingOffsetAFunction(cx, cy)
            uiState.currentlySettingOffsetAFunction = nil
        end
        if (uiState.currentlySettingOffsetBFunction) then
            uiState.currentlySelectedJoint = uiState.currentlySettingOffsetBFunction(cx, cy)
            uiState.currentlySettingOffsetBFunction = nil
        end

        local onPressedParams = {
            pointerForceFunc = function(fixture)
                return worldState.mouseForce
            end,
            damp = worldState.mouseDamping
        }

        local _, hitted = phys.handlePointerPressed(cx, cy, id, onPressedParams, not worldState.paused)

        if (uiState.selectedBodies and #hitted == 0) then
            uiState.selectedBodies = nil
        end

        if #hitted > 0 then
            local ud = hitted[1]:getBody():getUserData()
            if ud and ud.thing then
                uiState.currentlySelectedObject = ud.thing
            end
            if uiState.jointCreationMode then
                if uiState.jointCreationMode.body1 == nil then
                    uiState.jointCreationMode.body1 = uiState.currentlySelectedObject.body
                elseif uiState.jointCreationMode.body2 == nil then
                    if (uiState.currentlySelectedObject.body ~= uiState.jointCreationMode.body1) then
                        uiState.jointCreationMode.body2 = uiState.currentlySelectedObject.body
                    end
                end
            end

            if (worldState.paused) then
                -- local ud = uiState.currentlySelectedObject:getBody():getUserData()
                uiState.currentlyDraggingObject = uiState.currentlySelectedObject
                if uiState.currentlySelectedObject then
                    local offx, offy = uiState.currentlySelectedObject.body:getLocalPoint(cx, cy)
                    uiState.offsetForCurrentlyDragging = { -offx, -offy }
                end
            end
        else
            uiState.maybeHideSelectedPanel = true
        end
    elseif action == "released" then
        -- Handle release logic
        phys.handlePointerReleased(x, y, id)
        if uiState.currentlyDraggingObject then
            finalizeSpawn()
        end
        if uiState.isDrawingFreeformPolygon then
            finalizePolygon()
        end
        if uiState.customPolygonDraggingVertexIndex > 0 then
            uiState.customPolygonDraggingVertexIndex = 0
            maybeUpdateCustomPolygonVertices()
        end
        if (uiState.startSelection) then
            local tlx = math.min(uiState.startSelection.x, x)
            local tly = math.min(uiState.startSelection.y, y)
            local brx = math.max(uiState.startSelection.x, x)
            local bry = math.max(uiState.startSelection.y, y)
            local tlxw, tlyw = cam:getWorldCoordinates(tlx, tly)
            local brxw, bryw = cam:getWorldCoordinates(brx, bry)
            local selected = selectrect.selectWithin(world,
                { x = tlxw, y = tlyw, width = brxw - tlxw, height = bryw - tlyw })

            uiState.selectedBodies = selected

            uiState.startSelection = nil
        end
    end
end

function love.mousepressed(x, y, button, istouch)
    if not istouch and button == 1 then
        if uiState.isDrawingFreeformPolygon then
            -- Start capturing mouse movement
            uiState.isCapturingPolygon = true
            uiState.polygonVertices = {}
            uiState.lastPolygonPoint = nil
        else
            handlePointer(x, y, 'mouse', 'pressed')
        end
    end
    if playWithSoftbodies and button == 2 then
        local cx, cy = cam:getWorldCoordinates(x, y)
        local b = blob.softbody(world, cx, cy, 102, 2, 4)
        b:setFrequency(1)
        b:setDamping(0.1)
        b:setFriction(1)

        table.insert(softbodies, b)
    end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    handlePointer(x, y, id, 'pressed')
end

function love.mousereleased(x, y, button, istouch)
    if not istouch then
        handlePointer(x, y, 'mouse', 'released')
    end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    handlePointer(x, y, id, 'released')
end

if FIXED_TIMESTEP then
    function love.run()
        if love.math then
            love.math.setRandomSeed(os.time())
        end

        if love.load then love.load(arg) end

        local previous = love.timer.getTime()
        local lag = 0.0
        while true do
            local current = love.timer.getTime()
            local elapsed = current - previous
            previous = current
            lag = lag + elapsed

            if love.event then
                love.event.pump()
                for name, a, b, c, d, e, f in love.event.poll() do
                    if name == "quit" then
                        if not love.quit or not love.quit() then
                            return a
                        end
                    end
                    love.handlers[name](a, b, c, d, e, f)
                end
            end

            while lag >= TICKRATE do
                if love.update then love.update(TICKRATE) end
                lag = lag - TICKRATE
            end

            if love.graphics and love.graphics.isActive() then
                love.graphics.clear(love.graphics.getBackgroundColor())
                love.graphics.origin()
                if love.draw then love.draw(lag / TICKRATE) end
                love.graphics.present()
            end
        end
    end
end

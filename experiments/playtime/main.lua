-- main.lua

local camera = require 'src.camera'
local cam = camera.getInstance()

local blob = require 'vendor.loveblobs'
inspect = require 'vendor.inspect'

local ui = require 'src.ui-all'
local joint = require 'src.joints'
local selectrect = require 'src.selection-rect'
local eio = require 'src.io'
local registry = require 'src.registry'
local script = require 'src.script'
local objectManager = require 'src.object-manager'
mathutils = require 'src.math-utils'

local utils = require 'src.utils'
local box2dDraw = require 'src.box2d-draw'
local box2dPointerJoints = require 'src.box2d-pointerjoints'

function waitForEvent()
    local a, b, c, d, e
    repeat
        a, b, c, d, e = love.event.wait()
    until a == "focus" or a == 'mousepressed' or a == 'touchpressed'
end

waitForEvent()

local PANEL_WIDTH = 300
local BUTTON_HEIGHT = 40
local ROW_WIDTH = 160
local BUTTON_SPACING = 10
local FIXED_TIMESTEP = true
local TICKRATE = 1 / 60

function love.load(args)
    -- Load and set the font
    local font = love.graphics.newFont('assets/cooper_bold_bt.ttf', 30)
    love.keyboard.setKeyRepeat(true)
    love.graphics.setFont(font)

    -- Initialize UI
    ui.init(font)

    uiState = {
        lastUsedRadius = 20,
        lastUsedWidth = 40,
        lastUsedHeight = 40,
        showGrid = false,
        radiusOfNextSpawn = 100,
        nextType = 'dynamic',
        addShapeOpened = false,
        addJointOpened = false,
        worldSettingsOpened = false,
        maybeHideSelectedPanel = false,
        selectedJoint = nil,
        setOffsetAFunc = nil,
        setOffsetBFunc = nil,
        selectedObj = nil,
        draggingObj = nil,
        offsetDragging = { nil, nil },
        worldText = '',
        jointCreationMode = nil,
        jointUpdateMode = nil,
        drawFreePoly = false,
        drawClickPoly = false,
        capturingPoly = false,
        polyLockedVerts = true,
        polyDragIdx = 0,
        polyTempVerts = nil, -- used when dragging a vertex
        polyCentroid = nil,
        polyVerts = {},
        minPointDistance = 50, -- Default minimum distance
        lastPolyPt = nil,
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
        mouseDamping = 0.5,
        speedMultiplier = 1.0
    }


    sceneScript = nil
    scriptPath = nil
    lastModTime = nil
    hotReloadTimer = 0    -- Accumulates time
    hotReloadInterval = 1 -- Check every 1 second

    love.physics.setMeter(worldState.meter)

    --world = love.physics.newWorld(0, worldState.gravity * love.physics.getMeter(), true)
    --love.physics.setMeter(m)

    world = love.physics.newWorld(0, worldState.gravity * love.physics.getMeter(), true)
    --phys.setupWorldWithGravity(worldState.meter, worldState.gravity)

    local w, h = love.graphics.getDimensions()
    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(325, 325, 2000, 2000)

    objectManager.addThing('rectangle', 200, 400, 'dynamic', 100, 400)
    -- objectManager.addThing('rectangle', 600, 400, 'dynamic', 100)
    -- objectManager.addThing('rectangle', 450, 800, 'kinematic', 200)
    -- objectManager.addThing('rectangle', 850, 800, 'static', 200)
    -- objectManager.addThing('rectangle', 250, 1000, 'static', 100, 1800)
    -- objectManager.addThing('rectangle', 1100, 100, 'dynamic', 300)
    -- objectManager.addThing('circle', 1000, 400, 'dynamic', 100)
    -- objectManager.addThing('circle', 1300, 400, 'dynamic', 100)


    -- -- Adding custom polygon
    local customVertices = {
        0, 0,
        100, 0,
        200, 100,
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
        local b = blob.softsurface(world, points, 64, "dynamic")
        table.insert(softbodies, b)
        b:setJointFrequency(1)
        b:setJointDamping(.1)
        --b:setFixtureRestitution(2)
        -- b:setFixtureFriction(10)
    end

    world:setCallbacks(beginContact, endContact, preSolve, postSolve)

   -- loadScriptAndScene('snap')
end

function beginContact(fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
    script.call('beginContact', fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
end

function endContact(fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
    script.call('endContact', fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
end

function preSolve(fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
    script.call('preSolve', fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
end

function postSolve(fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
    script.call('postSolve', fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
end

function loadScene(name)
    local data = getFiledata(name):getString()
    uiState.selectedJoint = nil
    uiState.selectedObj = nil
    eio.load(data, world)
    return data
end

function loadScriptAndScene(id)
    local jsonPath = '/scripts/' .. id .. '.playtime.json'
    local luaPath = '/scripts/' .. id .. '.playtime.lua'
    jsoninfo = love.filesystem.getInfo(jsonPath)
    luainfo = love.filesystem.getInfo(luaPath)
    if (jsoninfo and luainfo) then
        local cwd = love.filesystem.getWorkingDirectory()
        loadScene(cwd .. jsonPath)
        loadAndRunScript(cwd .. luaPath)
    else
        print('issue loading both files.')
    end
end

local function getFileModificationTime(path)
    -- a bit of lame thing, i'm getting the cwd and the fll path
    -- then im cutting the duplication, so i'm left with the local fileName
    -- load that using love filesystem so i can get the mod time....
    local cwd = love.filesystem.getWorkingDirectory()
    local diff = utils.getPathDifference(cwd, path)
    if diff then
        local info = love.filesystem.getInfo(diff)
        return info and info.modtime or 0
    end
    return 0
end

function getFiledata(filename)
    local f = io.open(filename, 'r')
    if f then
        local filedata = love.filesystem.newFileData(f:read("*all"), filename)
        f:close()
        return filedata
    end
end

function loadAndRunScript(name)
    local data = getFiledata(name):getString()
    sceneScript = script.loadScript(data, name)()
    scriptPath = name

    script.call('onUnload')
    script.call('onStart')

    lastModTime = getFileModificationTime(name)
end

function maybeHotReload(dt)
    -- Accumulate time
    hotReloadTimer = hotReloadTimer + dt
    -- Check if the accumulated time exceeds the interval
    if hotReloadTimer >= hotReloadInterval then
        hotReloadTimer = hotReloadTimer - hotReloadInterval -- Reset timer
        if scriptPath then
            local newModeTime = (getFileModificationTime(scriptPath))
            if (newModeTime ~= lastModTime) then
                print('trying to load file because timestamp differs.')
                loadAndRunScript(scriptPath)
            end
            lastModTime = newModeTime
        end
    end
end

function love.update(dt)

    maybeHotReload(dt)

    local scaled_dt = dt * worldState.speedMultiplier
    if not worldState.paused then
        if playWithSoftbodies then
         for i, v in ipairs(softbodies) do
             v:update(scaled_dt)
         end
        end

        for i = 1, 1 do
            world:update(scaled_dt)
        end
        script.call('update', scaled_dt)
    end

    box2dPointerJoints.handlePointerUpdate(scaled_dt, cam)
    --phys.handleUpdate(dt)

    if uiState.draggingObj then
        local mx, my = love.mouse.getPosition()
        local wx, wy = cam:getWorldCoordinates(mx, my)
        local offx = uiState.offsetDragging[1]
        local offy = uiState.offsetDragging[2]
        local rx, ry = mathutils.rotatePoint(offx, offy, 0, 0, uiState.draggingObj.body:getAngle())
        local oldPosX, oldPosY = uiState.draggingObj.body:getPosition()
        uiState.draggingObj.body:setPosition(wx + rx, wy + ry)

        -- figure out if we are dragging a group!
        if uiState.selectedBodies then
            for i = 1, #uiState.selectedBodies do
                if (uiState.selectedBodies[i] == uiState.draggingObj) then
                    local newPosX, newPosY = uiState.draggingObj.body:getPosition()
                    local dx = newPosX - oldPosX
                    local dy = newPosY - oldPosY
                    for j = 1, #uiState.selectedBodies do
                        if (uiState.selectedBodies[j] ~= uiState.draggingObj) then
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
        local bodyTypes = { 'dynamic', 'kinematic', 'static' }
        if ui.button(x, y, 180, uiState.nextType) then
            local index = -1
            for i, v in ipairs(bodyTypes) do
                if uiState.nextType == v then
                    index = i
                end
            end
            uiState.nextType = bodyTypes[index % #bodyTypes + 1]
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
            uiState.drawFreePoly = true
            uiState.polyVerts = {}
            uiState.lastPolyPt = nil
        end

        x, y = ui.nextLayoutPosition(layout, width, height)
        if ui.button(x, y, width, 'click') then
            uiState.drawClickPoly = true
            uiState.polyVerts = {}
            uiState.lastPolyPt = nil
        end
    end)
end

local function drawUpdateSelectedObjectUI()
    local panelWidth = PANEL_WIDTH
    local w, h = love.graphics.getDimensions()
    ui.panel(w - panelWidth - 20, 20, panelWidth, h - 40, '∞ body props ∞', function()
        local body = uiState.selectedObj.body
        -- local angleDegrees = body:getAngle() * 180 / math.pi
        local myID = uiState.selectedObj.id

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
            if ui.button(x, y, 120, 'flipX') then
                uiState.selectedObj = objectManager.flipThing(thing, 'x', true)
                dirtyBodyChange = true
            end
            if ui.button(x + 140, y, 120, 'flipY') then
                uiState.selectedObj = objectManager.flipThing(thing, 'y', true)
                dirtyBodyChange = true
            end
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
                    uiState.selectedObj = objectManager.recreateThingFromBody(body,
                        { shapeType = "circle", radius = newRadius })
                    uiState.lastUsedRadius = newRadius
                    body = uiState.selectedObj.body
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
                    uiState.selectedObj = objectManager.recreateThingFromBody(body, {
                        shapeType = shapeType,
                        width = newWidth or thing.width,
                        height = newHeight or thing.height,
                    })
                    body = uiState.selectedObj.body
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
                        uiState.selectedObj = objectManager.recreateThingFromBody(body,
                            { shapeType = shapeType, radius = newRadius })
                        uiState.lastUsedRadius = newRadius
                        body = uiState.selectedObj.body
                    end
                else
                    -- No UI controls for custom or unsupported shapes
                    --ui.label(x, y, 'custom')
                    if ui.button(x, y, 260, uiState.polyLockedVerts and 'verts locked' or 'verts unlocked') then
                        uiState.polyLockedVerts = not uiState.polyLockedVerts
                        if uiState.polyLockedVerts == false then
                            uiState.polyTempVerts = utils.shallowCopy(uiState.selectedObj.vertices)
                            local cx, cy = mathutils.computeCentroid(uiState.selectedObj.vertices)
                            uiState.polyCentroid = { x = cx, y = cy }
                        else
                            uiState.polyTempVerts = nil
                            uiState.polyCentroid = nil
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

        local newAngle = ui.sliderWithInput(myID .. 'angle', x, y, ROW_WIDTH, -180, 180,
            (body:getAngle() * 180 / math.pi),
            (body:isAwake() and not worldState.paused) or dirtyBodyChange)
        if newAngle and (body:getAngle() * 180 / math.pi) ~= newAngle then
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

            uiState.selectedObj = nil
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
                            uiState.selectedJoint = joint
                            uiState.selectedObj = nil
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
    if worldState.paused then love.graphics.setColor(.7, .7, .5) else love.graphics.setColor(1, 1, 1) end
    love.graphics.rectangle('line', 10, 10, w - 20, h - 20, 20, 20)
    love.graphics.setColor(1, 1, 1)

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
        local jointTypes = { 'distance', 'weld', 'rope', 'revolute', 'wheel', 'motor', 'prismatic', 'pulley', 'friction' }
        local titleHeight = ui.font:getHeight() + BUTTON_SPACING
        local startX = 230
        local startY = 70
        local panelWidth = 200
        local buttonSpacing = BUTTON_SPACING
        local buttonHeight = ui.theme.button.height
        local panelHeight = (#jointTypes * (buttonHeight + BUTTON_SPACING) + BUTTON_SPACING)

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
        --local panelHeight = 255
        local buttonHeight = ui.theme.button.height

        local buttonSpacing = BUTTON_SPACING
        local titleHeight = ui.font:getHeight() + BUTTON_SPACING
        local panelHeight = titleHeight + titleHeight + (6 * (buttonHeight + BUTTON_SPACING) + BUTTON_SPACING)
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


            -- Add Speed Multiplier Slider
            local x, y = ui.nextLayoutPosition(layout, width, BUTTON_HEIGHT)
            local newSpeed = ui.sliderWithInput('speed', x, y, ROW_WIDTH, 0.1, 10.0, worldState.speedMultiplier)
            if newSpeed then
                worldState.speedMultiplier = newSpeed
            end
            ui.label(x, y, ' speed')


            x, y = ui.nextLayoutPosition(layout, width, BUTTON_HEIGHT)
            ui.label(x, y, registry.print())
            -- local t = ui.textinput('worldText', x, y, 280, 70, 'add text...', uiState.worldText)
            -- if t then
            --     uiState.worldText = t
            -- end
        end)
    end

    -- Play/Pause Button
    if ui.button(750, 20, 150, worldState.paused and 'play' or 'pause') then
        worldState.paused = not worldState.paused
    end

    if sceneScript and sceneScript.onStart then
        if ui.button(920, 20, 50, 'R') then
            -- todo actually reread the file itself!
            loadAndRunScript(scriptPath)
            sceneScript.onStart()
        end
    end

    if uiState.selectedObj and not uiState.selectedJoint then
        drawUpdateSelectedObjectUI()
    end

    if uiState.drawClickPoly then
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
                local cloned = eio.cloneSelection(uiState.selectedBodies)
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

    if uiState.selectedJoint then
        -- (w - panelWidth - 20, 20, panelWidth, h - 40
        joint.doJointUpdateUI(uiState, uiState.selectedJoint, w - PANEL_WIDTH - 20, 20, PANEL_WIDTH, h - 40)
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
                uiState.saveName = utils.sanitizeString(t)
            end
            if ui.button(320, 500, 200, 'save') then
                uiState.saveDialogOpened = false
                eio.save(world, worldState, uiState.saveName)
            end
            if ui.button(540, 500, 200, 'cancel') then
                uiState.saveDialogOpened = false
                love.system.openURL("file://" .. love.filesystem.getSaveDirectory())
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

function love.draw()
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(20 / 255, 5 / 255, 20 / 255)
    if uiState.showGrid then
        drawGrid(cam, worldState)
    end
    cam:push()

    box2dDraw.drawWorld(world)

    script.call('draw')
    -- if sceneScript and sceneScript.draw then
    --     sceneScript.draw()
    -- end

    if uiState.selectedJoint and not uiState.selectedJoint:isDestroyed() then
        local x1, y1, x2, y2 = uiState.selectedJoint:getAnchors()
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

    -- draw to be drawn polygon
    if uiState.drawFreePoly or uiState.drawClickPoly then
        if (#uiState.polyVerts >= 6) then
            love.graphics.polygon('line', uiState.polyVerts)
        end
    end

    -- draw mousehandlers for dragging vertices
    if uiState.polyTempVerts and uiState.selectedObj and uiState.selectedObj.shapeType == 'custom' and uiState.polyLockedVerts == false then
        local verts = mathutils.getLocalVerticesForCustomSelected(uiState.polyTempVerts,
            uiState.selectedObj, uiState.polyCentroid.x, uiState.polyCentroid.y)

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
        local bodies = utils.map(uiState.selectedBodies, function(thing)
            return thing.body
        end)
        box2dDraw.drawBodies(bodies)
    end

    -- draw temp poly when changing vertices
    if uiState.polyTempVerts then
        local verts = mathutils.getLocalVerticesForCustomSelected(uiState.polyTempVerts,
            uiState.selectedObj, uiState.polyCentroid.x, uiState.polyCentroid.y)
        love.graphics.setColor(1, 0, 0)
        love.graphics.polygon('line', verts)
        love.graphics.setColor(1, 1, 1) -- Rese
    end

    cam:pop()

    if uiState.startSelection then
        selectrect.draw(uiState.startSelection)
    end


    drawUI()
    script.call('drawUI')

    if uiState.maybeHideSelectedPanel then
        if not (ui.activeElementID or ui.focusedTextInputID) then
            uiState.selectedObj = nil
            uiState.selectedJoint = nil
        end
        uiState.maybeHideSelectedPanel = false
        uiState.polyTempVerts = nil
        uiState.polyLockedVerts = true
    end

    if sceneScript and sceneScript.foundError then
        love.graphics.setColor(1, 0, 0)
        love.graphics.print(sceneScript.foundError, 0, h / 2)
        love.graphics.setColor(1, 1, 1)
    end

    if FIXED_TIMESTEP then
        love.graphics.print('f' .. string.format("%02d", 1 / TICKRATE), w - 80, 10)
    else
        love.graphics.print(string.format("%03d", love.timer.getFPS()), w - 80, 10)
    end
end

function love.wheelmoved(dx, dy)
    local newScale = cam.scale * (1 + dy / 10)
    if newScale > 0.01 and newScale < 50 then
        cam:scaleToPoint(1 + dy / 10)
    end
end

function love.mousemoved(x, y, dx, dy)
    if uiState.polyDragIdx and uiState.polyDragIdx > 0 then
        local index = uiState.polyDragIdx
        local obj = uiState.selectedObj
        local angle = obj.body:getAngle()
        local dx2, dy2 = mathutils.rotatePoint(dx, dy, 0, 0, -angle)
        dx2 = dx2 / cam.scale
        dy2 = dy2 / cam.scale
        uiState.polyTempVerts[index] = uiState.polyTempVerts[index] + dx2
        uiState.polyTempVerts[index + 1] = uiState.polyTempVerts[index + 1] + dy2
    elseif uiState.capturingPoly then
        local wx, wy = cam:getWorldCoordinates(x, y)
        -- Check if the distance from the last point is greater than minPointDistance
        local addPoint = false
        if not uiState.lastPolyPt then
            addPoint = true
        else
            local lastX, lastY = uiState.lastPolyPt.x, uiState.lastPolyPt.y
            local distSq = (wx - lastX) ^ 2 + (wy - lastY) ^ 2
            if distSq >= (uiState.minPointDistance / cam.scale) ^ 2 then
                addPoint = true
            end
        end
        if addPoint then
            --table.insert(uiState.polygonVertices, { x = wx, y = wy })
            table.insert(uiState.polyVerts, wx)
            table.insert(uiState.polyVerts, wy)
            uiState.lastPolyPt = { x = wx, y = wy }
        end
    elseif love.mouse.isDown(3) then
        local tx, ty = cam:getTranslation()
        cam:setTranslation(tx - dx / cam.scale, ty - dy / cam.scale)
    end
end

function love.filedropped(file)
    local name = file:getFilename()
    if string.find(name, '.playtime.json') then
        script.call('onSceneUnload')
        loadScene(name)
        script.call('onSceneLoaded')
    end
    if string.find(name, '.playtime.lua') then
        loadAndRunScript(name)
    end
end

function love.textinput(t)
    ui.handleTextInput(t)
end

function finalizePolygon()
    if #uiState.polyVerts >= 6 then
        local cx, cy = mathutils.computeCentroid(uiState.polyVerts)
        objectManager.addThing('custom', cx, cy, uiState.nextType, nil, nil, nil, '', uiState.polyVerts)
    else
        -- Not enough vertices to form a polygon
        print("Not enough vertices to create a polygon.")
    end
    -- Reset the drawing state
    uiState.drawClickPoly = false
    uiState.drawFreePoly = false
    uiState.capturingPoly = false
    uiState.polyVerts = {}
    uiState.lastPolyPt = nil
end

local function maybeUpdateCustomPolygonVertices()
    if not utils.tablesEqualNumbers(uiState.polyTempVerts, uiState.selectedObj.vertices) then
        local nx, ny = mathutils.computeCentroid(uiState.polyTempVerts)
        local ox, oy = mathutils.computeCentroid(uiState.selectedObj.vertices)
        local dx = nx - ox
        local dy = ny - oy
        local body = uiState.selectedObj.body
        local oldX, oldY = body:getPosition()
        body:setPosition(oldX + dx, oldY + dy)
        uiState.selectedObj = objectManager.recreateThingFromBody(body,
            { optionalVertices = uiState.polyTempVerts })

        uiState.polyTempVerts = utils.shallowCopy(uiState.selectedObj.vertices)
        -- uiState.selectedObj.vertices = uiState.polyTempVerts
        uiState.polyCentroid = { x = nx, y = ny }
    end
end

local function insertCustomPolygonVertex(x, y)
    local obj = uiState.selectedObj
    local offx, offy = obj.body:getPosition()
    local px, py = mathutils.worldToLocal(x - offx, y - offy, obj.body:getAngle(), uiState.polyCentroid.x,
        uiState.polyCentroid.y)
    -- Find the closest edge index
    local insertAfterVertexIndex = mathutils.findClosestEdge(uiState.polyTempVerts, px, py)
    mathutils.insertValuesAt(uiState.polyTempVerts, insertAfterVertexIndex * 2 + 1, px, py)
end

-- Function to remove a custom polygon vertex based on mouse click
local function removeCustomPolygonVertex(x, y)
    -- Step 1: Convert world coordinates to local coordinates

    local obj = uiState.selectedObj

    local offx, offy = obj.body:getPosition()
    local px, py = mathutils.worldToLocal(x - offx, y - offy, obj.body:getAngle(),
        uiState.polyCentroid.x, uiState.polyCentroid.y)

    -- Step 2: Find the closest vertex index
    local closestVertexIndex = mathutils.findClosestVertex(uiState.polyTempVerts, px, py)

    if closestVertexIndex then
        -- Optional: Define a maximum allowable distance to consider for deletion
        local maxDeletionDistanceSq = 100 -- Adjust as needed (e.g., 10 units squared)
        local vx = uiState.polyTempVerts[(closestVertexIndex - 1) * 2 + 1]
        local vy = uiState.polyTempVerts[(closestVertexIndex - 1) * 2 + 2]
        local dx = px - vx
        local dy = py - vy
        local distSq = dx * dx + dy * dy
        --print(distSq)
        if distSq <= maxDeletionDistanceSq then
            -- Step 3: Remove the vertex from the vertex list

            -- Step 4: Ensure the polygon has a minimum number of vertices (e.g., 3)
            if #uiState.polyTempVerts <= 6 then
                print("Cannot delete vertex: A polygon must have at least three vertices.")
                -- Optionally, you can restore the removed vertex or prevent deletion
                return
            end
            mathutils.removeVertexAt(uiState.polyTempVerts, closestVertexIndex)
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
    if key == 'i' and uiState.polyTempVerts then
        -- figure out where my mousecursor is, between what nodes?
        local mx, my = love.mouse.getPosition()
        local wx, wy = cam:getWorldCoordinates(mx, my)
        insertCustomPolygonVertex(wx, wy)
        maybeUpdateCustomPolygonVertices()
    end
    if key == 'd' and uiState.polyTempVerts then
        -- Remove a vertex
        local mx, my = love.mouse.getPosition()
        local wx, wy = cam:getWorldCoordinates(mx, my)
        removeCustomPolygonVertex(wx, wy)
    end
    script.call('onKeyPress', key)
end

local function handlePointer(x, y, id, action)
    if action == "pressed" then
        -- Handle press logig
        --   -- this will block interacting on bodies when 'roughly' over the opened panel
        if uiState.saveDialogOpened then return end
        if uiState.selectedJoint or uiState.selectedObj or uiState.selectedBodies or uiState.drawClickPoly then
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

        if uiState.polyTempVerts and uiState.selectedObj and uiState.selectedObj.shapeType == 'custom' and uiState.polyLockedVerts == false then
            local verts = mathutils.getLocalVerticesForCustomSelected(uiState.polyTempVerts,
                uiState.selectedObj, uiState.polyCentroid.x, uiState.polyCentroid.y)
            for i = 1, #verts, 2 do
                local vx = verts[i]
                local vy = verts[i + 1]
                local dist = math.sqrt((cx - vx) ^ 2 + (cy - vy) ^ 2)
                if dist < 10 then
                    uiState.polyDragIdx = i

                    return
                else
                    uiState.polyDragIdx = 0
                end
            end
        end

        if (uiState.drawClickPoly) then
            table.insert(uiState.polyVerts, cx)
            table.insert(uiState.polyVerts, cy)
        end
        if (uiState.setOffsetAFunc) then
            uiState.selectedJoint = uiState.setOffsetAFunc(cx, cy)
            uiState.setOffsetAFunc = nil
        end
        if (uiState.setOffsetBFunc) then
            uiState.selectedJoint = uiState.setOffsetBFunc(cx, cy)
            uiState.setOffsetBFunc = nil
        end

        local onPressedParams = {
            pointerForceFunc = function(fixture)
                return worldState.mouseForce
            end,
            damp = worldState.mouseDamping
        }

        local _, hitted = box2dPointerJoints.handlePointerPressed(cx, cy, id, onPressedParams, not worldState.paused)

        if (uiState.selectedBodies and #hitted == 0) then
            uiState.selectedBodies = nil
        end

        if #hitted > 0 then
            local ud = hitted[1]:getBody():getUserData()
            if ud and ud.thing then
                uiState.selectedObj = ud.thing
            end
            if sceneScript and not worldState.paused and uiState.selectedObj then
                uiState.selectedObj = nil
            end
            if uiState.jointCreationMode and uiState.selectedObj then
                if uiState.jointCreationMode.body1 == nil then
                    uiState.jointCreationMode.body1 = uiState.selectedObj.body
                elseif uiState.jointCreationMode.body2 == nil then
                    if (uiState.selectedObj.body ~= uiState.jointCreationMode.body1) then
                        uiState.jointCreationMode.body2 = uiState.selectedObj.body
                    end
                end
            end

            if (worldState.paused) then
                -- local ud = uiState.currentlySelectedObject:getBody():getUserData()
                uiState.draggingObj = uiState.selectedObj
                if uiState.selectedObj then
                    local offx, offy = uiState.selectedObj.body:getLocalPoint(cx, cy)
                    uiState.offsetDragging = { -offx, -offy }
                end
            else
                local newHitted = utils.map(hitted, function(h)
                    local ud = (h:getBody() and h:getBody():getUserData())
                    local thing = ud and ud.thing
                    return thing
                end)
                script.call('onPressed', newHitted)

            end
        else
            uiState.maybeHideSelectedPanel = true
        end
    elseif action == "released" then
        -- Handle release logic
        local releasedObjs = box2dPointerJoints.handlePointerReleased(x, y, id)
        if (#releasedObjs > 0) then
            local newReleased = utils.map(releasedObjs, function(h) return h:getUserData() and h:getUserData().thing end)

            script.call('onReleased', newReleased)

        end
        if uiState.draggingObj then
            uiState.draggingObj.body:setAwake(true)
            uiState.selectedObj = uiState.draggingObj
            uiState.draggingObj = nil
        end

        if uiState.drawFreePoly then
            finalizePolygon()
        end

        if uiState.polyDragIdx > 0 then
            uiState.polyDragIdx = 0
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
        if uiState.drawFreePoly then
            -- Start capturing mouse movement
            uiState.capturingPoly = true
            uiState.polyVerts = {}
            uiState.lastPolyPt = nil
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
            lag = lag + elapsed * worldState.speedMultiplier

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

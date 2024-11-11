-- main.lua
package.path = package.path .. ";../../?.lua"
local inspect = require 'inspect'
local ui = require 'ui-all'
local cam = require('lib.cameraBase').getInstance()
local camera = require 'lib.camera'
local phys = require 'lib.mainPhysics'

function love.load()
    -- Load and set the font
    local font = love.graphics.newFont('cooper_bold_bt.ttf', 32)
    love.keyboard.setKeyRepeat(true)
    love.graphics.setFont(font)

    -- Initialize UI
    ui.init(font)

    bodyTypes = { 'dynamic', 'kinematic', 'static' }

    uiState = {
        radiusOfNextSpawn = 20,
        bodyTypeOfNextSpawn = 'dynamic',
        addShapeOpened = false,
        addJointOpened = false,
        worldSettingsOpened = false,
        maybeHideSelectedPanel = false,
        currentlySelectedObject = nil,
        currentlySpawningObject = nil,
        worldText = ''
    }

    worldState = {
        paused = true,
        gravity = 9.81
    }

    love.physics.setMeter(64)
    world = love.physics.newWorld(0, worldState.gravity * love.physics.getMeter(), true)
    phys.setupWorld(64)
    objects = {}

    -- Create the ground
    objects.ground = {}
    objects.ground.body = love.physics.newBody(world, 325, 625)
    objects.ground.shape = love.physics.newRectangleShape(650, 50)
    objects.ground.fixture = love.physics.newFixture(objects.ground.body, objects.ground.shape)

    -- Create a ball
    objects.ball = {}
    objects.ball.body = love.physics.newBody(world, 325, 325, "dynamic")
    objects.ball.body:setSleepingAllowed(false)
    objects.ball.shape = love.physics.newCircleShape(20)
    objects.ball.fixture = love.physics.newFixture(objects.ball.body, objects.ball.shape, 1)
    objects.ball.fixture:setRestitution(0.9)

    local w, h = love.graphics.getDimensions()
    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(325, 325, 2000, 2000)
end

-- Function to generate vertices of a regular polygon
local function makePolygonVertices(sides, radius)
    local vertices = {}
    local angleStep = (2 * math.pi) / sides
    local rotationOffset = math.pi / 2 -- Rotate so one vertex is at the top
    for i = 0, sides - 1 do
        local angle = i * angleStep - rotationOffset
        local x = radius * math.cos(angle)
        local y = radius * math.sin(angle)
        table.insert(vertices, x)
        table.insert(vertices, y)
    end
    return vertices
end

local function capsuleXY(w, h, cs, x, y)
    -- cs == cornerSize
    local w2 = w / 2
    local h2 = h / 2

    local bt = -h2 + cs
    local bb = h2 - cs
    local bl = -w2 + cs
    local br = w2 - cs

    return {
        x - w2, y + bt,
        x + bl, y - h2,
        x + br, y - h2,
        x + w2, y + bt,
        x + w2, y + bb,
        x + br, y + h2,
        x + bl, y + h2,
        x - w2, y + bb
    }
end

local function makeTrapezium(w, w2, h, x, y)
    return {
        x - w / 2, y - h / 2,
        x + w / 2, y - h / 2,
        x + w2 / 2, y + h / 2,
        x - w2 / 2, y + h / 2
    }
end

function startSpawn(shapeType, mx, my)
    local thing = {}
    local wx, wy = cam:getWorldCoordinates(mx, my)
    local radius = tonumber(uiState.radiusOfNextSpawn) or 10
    local bodyType = uiState.bodyTypeOfNextSpawn

    thing.body = love.physics.newBody(world, wx, wy, bodyType)

    if shapeType == 'circle' then
        thing.shape = love.physics.newCircleShape(radius)
    elseif shapeType == 'rectangle' then
        thing.shape = love.physics.newRectangleShape(radius * 2, radius * 2)
    elseif shapeType == 'capsule' then
        local w = radius
        local h = radius * 2
        local vertices = capsuleXY(w, h, w / 5, 0, 0)
        thing.shape = love.physics.newPolygonShape(vertices)
    elseif shapeType == 'trapezium' then
        local w = radius
        local h = radius * 2
        local vertices = makeTrapezium(w, w * 1.2, h, 0, 0)
        thing.shape = love.physics.newPolygonShape(vertices)
    else
        local sides = ({
            triangle = 3,
            pentagon = 5,
            hexagon = 6,
            heptagon = 7,
            octagon = 8,
        })[shapeType]
        if sides then
            local vertices = makePolygonVertices(sides, radius)
            thing.shape = love.physics.newPolygonShape(vertices)
        end
    end

    thing.fixture = love.physics.newFixture(thing.body, thing.shape, 1)
    thing.fixture:setRestitution(0.3)
    thing.body:setAwake(false)
    uiState.currentlySpawningObject = thing
end

function finalizeSpawn()
    if uiState.currentlySpawningObject then
        uiState.currentlySpawningObject.body:setAwake(true)
        uiState.currentlySpawningObject = nil
    end
end

function love.update(dt)
    if not worldState.paused then
        world:update(dt)
    end
    phys.handleUpdate(dt)

    if uiState.currentlySpawningObject then
        local mx, my = love.mouse.getPosition()
        local wx, wy = cam:getWorldCoordinates(mx, my)
        uiState.currentlySpawningObject.body:setPosition(wx, wy)
    end
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
        local shapeTypes = { 'circle', 'triangle', 'capsule', 'trapezium', 'rectangle', 'pentagon', 'hexagon',
            'heptagon',
            'octagon' }
        local titleHeight = ui.font:getHeight() + 10
        local startX = 20
        local startY = 70
        local panelWidth = 200
        local buttonSpacing = 10
        local buttonHeight = ui.theme.button.height
        local panelHeight = titleHeight + ((#shapeTypes + 4) * (buttonHeight + buttonSpacing)) + buttonSpacing

        ui.panel(startX, startY, panelWidth, panelHeight, 'drag »', function()
            local layout = ui.createLayout({
                type = 'columns',
                spacing = buttonSpacing,
                startX = startX + 10,
                startY = startY + titleHeight + 10
            })

            local x, y = ui.nextLayoutPosition(layout, panelWidth - 20, buttonHeight)
            local r = ui.sliderWithInput('radius', x, y, 60, 0.1, 150, uiState.radiusOfNextSpawn)
            if r then
                uiState.radiusOfNextSpawn = r
            end

            x, y = ui.nextLayoutPosition(layout, panelWidth - 20, buttonHeight)
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
                    startSpawn(shape, mx, my)
                end
                if released then
                    ui.draggingActive = nil
                    finalizeSpawn()
                end
            end
        end)
    end

    -- "Add Joint" Button
    if ui.button(230, 20, 200, 'add joint') then
        uiState.addJointOpened = not uiState.addJointOpened
    end

    if uiState.addJointOpened then
        local jointTypes = { 'distance', 'friction', 'gear', 'mouse', 'prismatic', 'pulley', 'revolute', 'rope', 'weld',
            'motor', 'wheel' }
        local titleHeight = ui.font:getHeight() + 10
        local startX = 230
        local startY = 70
        local panelWidth = 200
        local buttonSpacing = 10
        local buttonHeight = ui.theme.button.height
        local panelHeight = titleHeight + (#jointTypes * (buttonHeight + buttonSpacing)) + buttonSpacing

        ui.panel(startX, startY, panelWidth, panelHeight, 'drag »', function()
            local layout = ui.createLayout({
                type = 'columns',
                spacing = buttonSpacing,
                startX = startX + 10,
                startY = startY + titleHeight + 10
            })
            for _, joint in ipairs(jointTypes) do
                local width = panelWidth - 20
                local height = buttonHeight
                local x, y = ui.nextLayoutPosition(layout, width, height)
                ui.button(x, y, width, joint)
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
        local panelWidth = 300
        local panelHeight = 400
        local buttonSpacing = 10
        local titleHeight = ui.font:getHeight() + 10

        ui.panel(startX, startY, panelWidth, panelHeight, '• ∫ƒF world •', function()
            local layout = ui.createLayout({
                type = 'columns',
                spacing = buttonSpacing,
                startX = startX + 10,
                startY = startY + titleHeight + 10
            })
            local width = panelWidth - 20

            local x, y = ui.nextLayoutPosition(layout, width, 50)
            ui.label(x, y, 'gravity m/s²')

            x, y = ui.nextLayoutPosition(layout, width, 50)
            local grav = ui.sliderWithInput('grav', x, y, 160, -10, 50, worldState.gravity)
            if grav then
                worldState.gravity = grav
                if world then
                    world:setGravity(0, worldState.gravity * love.physics.getMeter())
                end
            end

            x, y = ui.nextLayoutPosition(layout, width, 50)
            local t = ui.textinput('worldText', x, y, 280, 200, 'add text...', uiState.worldText)
            if t then
                uiState.worldText = t
            end
        end)
    end

    -- Play/Pause Button
    if ui.button(750, 20, 150, worldState.paused and 'play' or 'pause') then
        worldState.paused = not worldState.paused
    end

    -- Properties Panel
    if uiState.currentlySelectedObject then
        ui.panel(w - 300, 60, 280, h - 80, '∞ Properties ∞', function()
            local body = uiState.currentlySelectedObject:getBody()
            local angleDegrees = body:getAngle() * 180 / math.pi
            local sliderID = tostring(body)
            local newAngle = ui.sliderWithInput(sliderID .. 'angle', w - 290, 120, 160, -180, 180, angleDegrees,
                body:isAwake() and not worldState.paused)
            if newAngle and angleDegrees ~= newAngle then
                body:setAngle(newAngle * math.pi / 180)
            end

            local fixtures = body:getFixtures()
            if #fixtures == 1 then
                local density = fixtures[1]:getDensity()
                local newDensity = ui.sliderWithInput(sliderID .. 'density', w - 290, 180, 160, 0, 10, density)
                if newDensity and density ~= newDensity then
                    fixtures[1]:setDensity(newDensity)
                end

                local bounciness = fixtures[1]:getRestitution()
                local newBounce = ui.sliderWithInput(sliderID .. 'bounciness', w - 290, 240, 160, 0, 1, bounciness)
                if newBounce and bounciness ~= newBounce then
                    fixtures[1]:setRestitution(newBounce)
                end

                local friction = fixtures[1]:getFriction()
                local newFriction = ui.sliderWithInput(sliderID .. 'friction', w - 290, 300, 160, 0, 1, friction)
                if newFriction and friction ~= newFriction then
                    fixtures[1]:setFriction(newFriction)
                end
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
    love.graphics.clear(20 / 255, 5 / 255, 20 / 255)
    cam:push()
    phys.drawWorld(world)
    cam:pop()
    drawUI()
    if uiState.maybeHideSelectedPanel then
        if not (ui.activeElementID or ui.focusedTextInputID) then
            uiState.currentlySelectedObject = nil
        end
        uiState.maybeHideSelectedPanel = false
    end
end

function love.wheelmoved(dx, dy)
    local newScale = cam.scale * (1 + dy / 10)
    if newScale > 0.01 and newScale < 50 then
        cam:scaleToPoint(1 + dy / 10)
    end
end

function love.mousemoved(x, y, dx, dy)
    if love.keyboard.isDown('space') or love.mouse.isDown(3) then
        local tx, ty = cam:getTranslation()
        cam:setTranslation(tx - dx / cam.scale, ty - dy / cam.scale)
    end
end

function love.textinput(t)
    ui.handleTextInput(t)
end

function love.keypressed(key)
    ui.handleKeyPress(key)
    if key == 'escape' then
        love.event.quit()
    end
end

local function pointerPressed(x, y, id)
    local cx, cy = cam:getWorldCoordinates(x, y)
    local onPressedParams = {
        pointerForceFunc = function(fixture)
            return 50000
        end
    }
    local _, hitted = phys.handlePointerPressed(cx, cy, id, onPressedParams)
    if #hitted > 0 then
        uiState.currentlySelectedObject = hitted[1]
    else
        uiState.maybeHideSelectedPanel = true
    end
end

function love.mousepressed(x, y, button, istouch)
    if not istouch and button == 1 then
        pointerPressed(x, y, 'mouse')
    end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    pointerPressed(x, y, id)
end

local function pointerReleased(x, y, id)
    phys.handlePointerReleased(x, y, id)
end

function love.mousereleased(x, y, button, istouch)
    if not istouch then
        pointerReleased(x, y, 'mouse')
    end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    pointerReleased(x, y, id)
end

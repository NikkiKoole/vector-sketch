-- main.lua
package.path = package.path .. ";../../?.lua"
inspect      = require 'inspect'
local ui     = require 'ui-all'
local cam    = require('lib.cameraBase').getInstance()
local camera = require 'lib.camera'
local phys   = require 'lib.mainPhysics'

-- Initialize Love2D
function love.load()
    -- Load and set the font
    local font = love.graphics.newFont('cooper_bold_bt.ttf', 32)

    --local font = love.graphics.newFont('QuentinBlakeRegular.otf', 32)
    love.keyboard.setKeyRepeat(true)
    love.graphics.setFont(font)

    -- Initialize UI
    ui.init(font)


    bodytypes = { 'dynamic', 'kinematic', 'static' }

    uiState = {
        radius_of_next_spawn = 20,
        bodytype_of_next_spawn = 'dynamic',
        add_shape_opened = false,
        add_joint_opened = false,
        world_settings_opened = false,
        maybeHideSelectedPanel = false,
        currentlySelectedObject = nil,
        currentlySpawningObject = nil,
        worldText = ''
    }
    worldState = {
        paused = true,
        meter = 64,
        gravity = 9.81
    }

    --local world
    --
    love.physics.setMeter(64)
    world = love.physics.newWorld(0, worldState.gravity * love.physics.getMeter(), true)
    phys.setupWorld(64)
    objects = {}

    --let's create the ground
    objects.ground = {}
    objects.ground.body = love.physics.newBody(world, 650 / 2, 650 - 50 / 2)                    --remember, the shape (the rectangle we create next) anchors to the body from its center, so we have to move it to (650/2, 650-50/2)
    objects.ground.shape = love.physics.newRectangleShape(650, 50)                              --make a rectangle with a width of 650 and a height of 50
    objects.ground.fixture = love.physics.newFixture(objects.ground.body, objects.ground.shape) --attach shape to body

    --let's create a ball
    objects.ball = {}
    objects.ball.body = love.physics.newBody(world, 650 / 2, 650 / 2, "dynamic")             --place the body in the center of the world and make it dynamic, so it can move around
    objects.ball.body:setSleepingAllowed(false)
    objects.ball.shape = love.physics.newCircleShape(20)                                     --the ball's shape has a radius of 20
    objects.ball.fixture = love.physics.newFixture(objects.ball.body, objects.ball.shape, 1) -- Attach fixture to body and give it a density of 1.
    objects.ball.fixture:setRestitution(0.9)                                                 --let the ball bounce


    local w, h = love.graphics.getDimensions()
    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(650 / 2, 650 / 2, 2000, 2000)
end

-- Function to generate vertices of a regular polygon
function makePolygonVertices(sides, radius)
    local vertices = {}
    local angleStep = (2 * math.pi) / sides
    local rotationOffset = math.pi / 2 -- Rotate so one vertex is at the top (optional)
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

    local result = {
        x + -w2, y + bt,
        x + bl, y + -h2,
        x + br, y + -h2,
        x + w2, y + bt,
        x + w2, y + bb,
        x + br, y + h2,
        x + bl, y + h2,
        x + -w2, y + bb
    }
    return result
end

local function makeTrapezium(w, w2, h, x, y)
    local cx = x
    local cy = y
    return {
        cx - w / 2, cy - h / 2,
        cx + w / 2, cy - h / 2,
        cx + w2 / 2, cy + h / 2,
        cx - w2 / 2, cy + h / 2
    }
end

function startSpawn(type, mx, my)
    local thing = {}
    local wx, wy = cam:getWorldCoordinates(mx, my)
    local r = uiState.radius_of_next_spawn
    local bt = uiState.bodytype_of_next_spawn

    thing.body = love.physics.newBody(world, wx, wy, bt)

    if type == 'circle' then
        thing.shape = love.physics.newCircleShape(r)
    elseif type == 'rectangle' then
        thing.shape = love.physics.newRectangleShape(r * 2, r * 2)
    elseif type == 'capsule' then
        local w = r
        local h = r * 2
        local vertices = capsuleXY(w, h, w / 5, 0, 0)
        thing.shape = love.physics.newPolygonShape(vertices)
    elseif type == 'trapezium' then
        local w = r
        local h = r * 2
        local vertices = makeTrapezium(w, w * 1.2, h, 0, 0)
        thing.shape = love.physics.newPolygonShape(vertices)
    elseif type == 'triangle' then
        local vertices = makePolygonVertices(3, r)
        thing.shape = love.physics.newPolygonShape(vertices)
    elseif type == 'pentagon' then
        local vertices = makePolygonVertices(5, r)
        thing.shape = love.physics.newPolygonShape(vertices)
    elseif type == 'hexagon' then
        local vertices = makePolygonVertices(6, r)
        thing.shape = love.physics.newPolygonShape(vertices)
    elseif type == 'heptagon' then
        local vertices = makePolygonVertices(7, r)
        thing.shape = love.physics.newPolygonShape(vertices)
    elseif type == 'octagon' then
        local vertices = makePolygonVertices(8, r)
        thing.shape = love.physics.newPolygonShape(vertices)
    end

    thing.fixture = love.physics.newFixture(thing.body, thing.shape, 1)
    thing.fixture:setRestitution(0.3)
    thing.body:setAwake(false)
    uiState.currentlySpawningObject = thing
end

function finalizeSpawn(type, mx, my)
    if uiState.currentlySpawningObject then
        uiState.currentlySpawningObject.body:setAwake(true)
        uiState.currentlySpawningObject = nil
    end
end

-- Update function
function love.update(dt)
    -- Reserved for future UI updates
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

-- Draw UI and Handle Interactions
--
--
function drawUI()
    ui.startFrame() -- Start a new UI frame
    local w, h = love.graphics.getDimensions()
    love.graphics.rectangle('line', 10, 10, w - 20, h - 20, 20, 20)



    -- "Add Shape" Button
    local addShapeClicked, _ = ui.button(20, 20, 200, 'add shape')
    if addShapeClicked then
        uiState.add_shape_opened = not uiState.add_shape_opened
    end

    if uiState.add_shape_opened then
        local types = { 'circle', 'triangle', 'capsule', 'trapezium', 'rectangle', 'pentagon', 'hexagon', 'heptagon',
            'octagon' }
        local titleHeight = ui.font:getHeight() + 10
        local startX = 20
        local startY = 70
        local panelWidth = 200
        local buttonSpacing = 10
        local buttonHeight = ui.theme.button.height
        local panelHeight = titleHeight + ((#types + 4) * (buttonHeight + buttonSpacing)) + buttonSpacing

        ui.panel(startX, startY, panelWidth, panelHeight, 'drag »', function()
            local layout = ui.createLayout({
                type = 'columns',
                spacing = buttonSpacing,
                startX = startX + 10,
                startY = startY + titleHeight + 10
            })
            local x, y = ui.nextLayoutPosition(layout, width, buttonHeight)
            local r = ui.sliderWithInput(x, y, 60, 0.1, 150, uiState.radius_of_next_spawn)
            if r then
                uiState.radius_of_next_spawn = r
            end

            local x, y = ui.nextLayoutPosition(layout, width, buttonHeight)
            local btClicked = ui.button(x, y, 180, uiState.bodytype_of_next_spawn)
            if btClicked then
                local index = -1
                for i = 1, #bodytypes do
                    if uiState.bodytype_of_next_spawn == bodytypes[i] then
                        index = i
                    end
                end
                local nextIndex = index + 1
                if (index + 1 > #bodytypes) then
                    nextIndex = 1
                end
                uiState.bodytype_of_next_spawn = bodytypes[nextIndex]
            end
            --ui.slider(x, y, 100, buttonHeight, 'horizontal', 0.1, 10, uiState.radius_of_next_spawn)
            local x, y = ui.nextLayoutPosition(layout, width, buttonHeight)
            for i = 1, #types do
                local width = panelWidth - 20
                local height = buttonHeight
                local x, y = ui.nextLayoutPosition(layout, width, height)
                local spawnClicked, spawnPressed, spawnReleased = ui.button(x, y, width, types[i])
                if spawnClicked then
                    print('Hello ' .. types[i] .. ' is clicked! Now I say World!')
                end
                if spawnPressed then
                    -- Track which element is being dragged
                    ui.draggingActive = ui.activeElementID
                    print('Hello ' .. types[i] .. ' is pressed! Now I say World!')
                    local mx, my = love.mouse:getPosition()
                    startSpawn(types[i], mx, my)
                end
                if spawnReleased then
                    ui.draggingActive = nil
                    print('Hello ' .. types[i] .. ' is released! Now I say World!')
                    local mx, my = love.mouse:getPosition()
                    finalizeSpawn(types[i], mx, my)
                end
            end
        end)
    end

    -- "Add Joint" Button
    local addJointClicked, _ = ui.button(230, 20, 200, 'add joint')
    if addJointClicked then
        uiState.add_joint_opened = not uiState.add_joint_opened
    end

    if uiState.add_joint_opened then
        local types = { 'distance', 'friction', 'gear', 'mouse', 'prismatic', 'pulley', 'revolute', 'rope', 'weld',
            'motor', 'wheel' }

        local titleHeight = ui.font:getHeight() + 10
        local startX = 230
        local startY = 70
        local panelWidth = 200
        local buttonSpacing = 10
        local buttonHeight = ui.theme.button.height
        local panelHeight = titleHeight + (#types * (buttonHeight + buttonSpacing)) + buttonSpacing

        ui.panel(startX, startY, panelWidth, panelHeight, 'drag »', function()
            local layout = ui.createLayout({
                type = 'columns',
                spacing = buttonSpacing,
                startX = startX + 10,
                startY = startY + titleHeight + 10
            })
            for i = 1, #types do
                local width = panelWidth - 20
                local height = buttonHeight
                local x, y = ui.nextLayoutPosition(layout, width, height)
                local spawnClicked, spawnPressed, spawnReleased = ui.button(x, y, width, types[i])
                if spawnClicked then
                    print('Hello ' .. types[i] .. ' is clicked! Now I say World!')
                end
                if spawnPressed then
                    -- Track which element is being dragged
                    ui.draggingActive = ui.activeElementID
                    print('Hello ' .. types[i] .. ' is pressed! Now I say World!')
                end
                if spawnReleased then
                    ui.draggingActive = nil
                    print('Hello ' .. types[i] .. ' is released! Now I say World!')
                end
            end
        end)
    end

    local worldSettingsClicked, _ = ui.button(440, 20, 300, 'world settings')
    if worldSettingsClicked then
        uiState.world_settings_opened = not uiState.world_settings_opened
    end
    if uiState.world_settings_opened then
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
            local clicked, checkstate = ui.checkbox(x + ui.font:getWidth('gravity m/s²') + 10, y, gravityState, '')
            if clicked then
                gravityState = checkstate
            end
            local x, y = ui.nextLayoutPosition(layout, width, 50)
            local grav = ui.sliderWithInput(x, y, 160, -10, 50, worldState.gravity)
            if grav then
                worldState.gravity = grav
                if world then
                    world:setGravity(0, worldState.gravity * love.physics.getMeter())
                end
            end
            local x, y = ui.nextLayoutPosition(layout, width, 50)
            local t = ui.textinput(x, y, 280, 200, 'add text...', uiState.worldText)
            if t then
                -- print('jo!')
                uiState.worldText = t
            end
        end)
    end

    local playOrPauseClicked, _ = ui.button(750, 20, 150, worldState.paused and 'play' or 'pause')
    if playOrPauseClicked then
        worldState.paused = not worldState.paused
    end


    if uiState.currentlySelectedObject then
        ui.panel(w - 300, 60, 280, h - 80, '∞ Properties ∞', function()
            --print(uiState.currentlySelectedObject)
            local b = uiState.currentlySelectedObject:getBody()
            local v = b:getAngle() / (math.pi / 180)
            local r = ui.slider(w - 290, 120, 180, 30, 'horizontal', -180, 180, v)
            --  local r = ui.sliderWithInput(w - 290, 120, 180, -180, 180, v)
            if r then
                r = string.format("%.2f", r)
                if v ~= r then
                    b:setAngle(r * math.pi / 180)
                end
            end
        end)
    end

    if ui.draggingActive then
        love.graphics.setColor(ui.theme.draggedElement.fill) -- Dragged element color
        local x, y = love.mouse.getPosition()
        love.graphics.circle('fill', x, y, 10)
        love.graphics.setColor(1, 1, 1) -- Reset color
    end

    if false then
        local options = { "dynamic", "static", "kinematic" }
        local dropd, dropPressed, dropReleased = ui.dropdown(100, 100, 200, options, pickedoption)
        if dropd then
            pickedoption = dropd
        end
        if dropPressed then
            -- Track which element is being dragged
            ui.draggingActive = ui.activeElementID
            print('Hello ' .. pickedoption .. ' is pressed! Now I say World!')
        end
        if dropReleased then
            ui.draggingActive = nil
            print('Hello ' .. pickedoption .. ' is released! Now I say World!')
        end
    end
end

function love.draw()
    love.graphics.clear(20 / 255, 5 / 255, 20 / 255)
    cam:push()

    phys.drawWorld(world)
    cam:pop()

    drawUI()
    if uiState.maybeHideSelectedPanel then
        if (ui.activeElementID) then
            -- nothing todo, i've interacted on some UI so do not hide the panel
        else
            uiState.currentlySelectedObject = nil
            -- this is needed becaue some elements (textinput) hold on to state
            uiState.currentlySelectedObjectChange = true
        end
        uiState.maybeHideSelectedPanel = false
    end
    if uiState.currentlySelectedObjectChange then
        uiState.currentlySelectedObjectChange = false
    end
end

function love.wheelmoved(dx, dy)
    local newScale = cam.scale * (1 + dy / 10)
    if (newScale > 0.01 and newScale < 50) then
        cam:scaleToPoint(1 + dy / 10)
    end
end

function love.mousemoved(x, y, dx, dy)
    --if followCamera == 'free' then
    if love.keyboard.isDown('space') or love.mouse.isDown(3) then
        local x, y = cam:getTranslation()
        cam:setTranslation(x - dx / cam.scale, y - dy / cam.scale)
    end
    --end
end

-- Handle text input globally and delegate to the focused TextInput
function love.textinput(t)
    ui.handleTextInput(t)
end

-- Handle key presses globally and delegate to the focused TextInput
function love.keypressed(key)
    ui.handleKeyPress(key)

    -- Exit the game when 'escape' key is pressed
    if key == 'escape' then
        love.event.quit()
    end
end

local function pointerPressed(x, y, id)
    local w, h = love.graphics.getDimensions()
    local cx, cy = cam:getWorldCoordinates(x, y)
    local onPressedParams = {
        pointerForceFunc = function(fixture)
            local ud = fixture:getUserData()
            --print(inspect(ud))
            local force =
                (ud and ud.bodyType == 'torso' and 1000000) or
                (ud and ud.bodyType == 'frame' and 1000000) or
                50000
            -- print(force)
            return force
        end
        --pointerForceFunc = function(fixture) return 1400 end
    }
    local interacted, hitted = phys.handlePointerPressed(cx, cy, id, onPressedParams)
    if (#hitted > 0) then
        -- this in a table of hitted objects as in pressed with the pointer.
        --print('hitted 401', inspect(hitted), ui.mouseReleased)
        if #hitted == 1 then
            uiState.currentlySelectedObject = hitted[1]
            uiState.currentlySelectedObjectChange = true
        end
    else
        -- print('activelemet id', ui.activeElementID, ui.mousePressed)

        uiState.maybeHideSelectedPanel = true
    end
end

function love.mousepressed(x, y, button, istouch)
    if not istouch then
        if button == 1 then
            pointerPressed(x, y, 'mouse')
        end
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
    --ui.removeFromPressedPointers(id)
end

function icon()
    local x = 100
    local y = 100
    love.graphics.setColor(193 / 255, 117 / 255, 16 / 255)
    love.graphics.circle('fill', x + 50, y + 50, 50)
    love.graphics.setColor(1, 1, 1)
    love.graphics.polygon('fill', x, y, x + 100, y, x + 100, y + 100)
    local font2 = love.graphics.newFont('cooper_bold_bt.ttf', 80)
    love.graphics.setFont(font2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print('pt', x + 5 + 10, -10 + y + 5)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print('pt', x + 10, -10 + y)
end

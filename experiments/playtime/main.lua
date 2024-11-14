-- main.lua
package.path = package.path .. ";../../?.lua"
local inspect = require 'inspect'
local ui = require 'ui-all'
local cam = require('lib.cameraBase').getInstance()
local camera = require 'lib.camera'
local phys = require 'lib.mainPhysics'
local decompose = require 'decompose'
function love.load()
    -- Load and set the font
    local font = love.graphics.newFont('cooper_bold_bt.ttf', 32)
    love.keyboard.setKeyRepeat(true)
    love.graphics.setFont(font)

    -- Initialize UI
    ui.init(font)

    bodyTypes = { 'dynamic', 'kinematic', 'static' }

    uiState = {
        showGrid = false,
        radiusOfNextSpawn = 20,
        bodyTypeOfNextSpawn = 'dynamic',
        addShapeOpened = false,
        addJointOpened = false,
        worldSettingsOpened = false,
        maybeHideSelectedPanel = false,
        currentlySelectedObject = nil,
        currentlyDraggingObject = nil,
        offsetForCurrentlyDragging = { nil, nil },
        worldText = '',
        jointCreationMode = nil,
        isDrawingPolygon = false,
        polygonVertices = {},
        minPointDistance = 10, -- Default minimum distance
        lastPolygonPoint = nil,
    }

    worldState = {
        meter = 200,
        paused = true,
        gravity = 9.81
    }

    love.physics.setMeter(worldState.meter)
    world = love.physics.newWorld(0, worldState.gravity * love.physics.getMeter(), true)
    phys.setupWorld(64)

    local w, h = love.graphics.getDimensions()
    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(325, 325, 2000, 2000)
end

local function rotatePoint(x, y, originX, originY, angle)
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
    thing.body:setUserData({ thing = thing })
    uiState.currentlyDraggingObject = thing
    uiState.offsetForCurrentlyDragging = { 0, 0 }
end

-- function createJoint(data)
--     print(inspect(data))
--     uiState.jointCreationMode = nil
-- end
function createJoint(data)
    local bodyA = data.body1
    local bodyB = data.body2
    local jointType = data.jointType

    local joint
    if jointType == 'distance' then
        -- Create a Distance Joint
        local x1, y1 = bodyA:getPosition()
        local x2, y2 = bodyB:getPosition()
        local length = data.length or ((x2 - x1) ^ 2 + (y2 - y1) ^ 2) ^ 0.5
        joint = love.physics.newDistanceJoint(bodyA, bodyB, x1, y1, x2, y2, false)
        joint:setLength(length)
    elseif jointType == 'revolute' then
        -- Create a Revolute Joint at the first body's position
        local x, y = bodyA:getPosition()
        joint = love.physics.newRevoluteJoint(bodyA, bodyB, x, y, false)
    elseif jointType == 'weld' then
        -- Create a Weld Joint at the first body's position
        local x, y = bodyA:getPosition()
        joint = love.physics.newWeldJoint(bodyA, bodyB, x, y, false)
    elseif jointType == 'motor' then
        -- Create a Motor Joint
        local correctionFactor = data.correctionFactor or 1
        joint = love.physics.newMotorJoint(bodyA, bodyB, correctionFactor, false)
        if data.maxForce then
            joint:setMaxForce(data.maxForce)
        end
        if data.maxTorque then
            joint:setMaxTorque(data.maxTorque)
        end
    elseif jointType == 'wheel' then
        -- Create a Wheel Joint
        local x, y = bodyA:getPosition()
        local axisX, axisY = 0, 1 -- Vertical axis
        joint = love.physics.newWheelJoint(bodyA, bodyB, x, y, axisX, axisY, false)
        if data.frequency then
            joint:setSpringFrequency(data.frequency)
        end
        if data.dampingRatio then
            joint:setSpringDampingRatio(data.dampingRatio)
        end
    elseif jointType == 'rope' then
        -- Create a Rope Joint
        local x1, y1 = bodyA:getPosition()
        local x2, y2 = bodyB:getPosition()
        local maxLength = data.maxLength or ((x2 - x1) ^ 2 + (y2 - y1) ^ 2) ^ 0.5
        joint = love.physics.newRopeJoint(bodyA, bodyB, x1, y1, x2, y2, maxLength, false)
    elseif jointType == 'pulley' then
        -- Create a Pulley Joint
        local x1, y1 = bodyA:getWorldCenter()
        local x2, y2 = bodyB:getWorldCenter()
        local gx1, gy1 = x1, y1 - 100
        local gx2, gy2 = x2, y2 - 100
        local ratio = data.ratio or 1
        joint = love.physics.newPulleyJoint(bodyA, bodyB, gx1, gy1, gx2, gy2, x1, y1, x2, y2, ratio, false)
    elseif jointType == 'friction' then
        -- Create a Friction Joint
        local x, y = bodyA:getPosition()
        joint = love.physics.newFrictionJoint(bodyA, bodyB, x, y, false)
        if data.maxForce then
            joint:setMaxForce(data.maxForce)
        end
        if data.maxTorque then
            joint:setMaxTorque(data.maxTorque)
        end
    else
        -- Handle other joints or unimplemented types
        print("Joint type '" .. jointType .. "' is not implemented yet.")
        uiState.jointCreationMode = nil
        return
    end

    -- Store the joint
    worldState.joints = worldState.joints or {}
    table.insert(worldState.joints, joint)

    -- Clear joint creation mode
    uiState.jointCreationMode = nil
end

function finalizeSpawn()
    if uiState.currentlyDraggingObject then
        uiState.currentlyDraggingObject.body:setAwake(true)
        uiState.currentlyDraggingObject = nil
    end
end

function love.update(dt)
    if not worldState.paused then
        world:update(dt)
    end
    phys.handleUpdate(dt)

    if uiState.currentlyDraggingObject then
        local mx, my = love.mouse.getPosition()
        local wx, wy = cam:getWorldCoordinates(mx, my)
        local offx = uiState.offsetForCurrentlyDragging[1]
        local offy = uiState.offsetForCurrentlyDragging[2]
        local rx, ry = rotatePoint(offx, offy, 0, 0, uiState.currentlyDraggingObject.body:getAngle())
        uiState.currentlyDraggingObject.body:setPosition(wx + rx, wy + ry)
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

        ui.panel(startX, startY, panelWidth, panelHeight, '', function()
            local layout = ui.createLayout({
                type = 'columns',
                spacing = buttonSpacing,
                startX = startX + 10,
                startY = startY + 10
            })

            local x, y = ui.nextLayoutPosition(layout, panelWidth - 20, buttonHeight)
            local r = ui.sliderWithInput('radius', x, y, 80, 0.1, 150, uiState.radiusOfNextSpawn)
            ui.label(x, y, ' size')
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
            if ui.button(x, y, width, 'custom') then
                uiState.isDrawingPolygon = true
                uiState.polygonVertices = {}
                uiState.lastPolygonPoint = nil
            end
        end)
    end

    -- "Add Joint" Button
    if ui.button(230, 20, 200, 'add joint') then
        uiState.addJointOpened = not uiState.addJointOpened
    end

    if uiState.addJointOpened then
        --'gear'
        --'prismatic',
        local jointTypes = { 'distance', 'friction', 'pulley', 'revolute', 'rope', 'weld', 'motor', 'wheel' }
        --local jointTypes = { 'distance', 'revolute', 'weld', 'prismatic', 'motor' }
        local titleHeight = ui.font:getHeight() + 10
        local startX = 230
        local startY = 70
        local panelWidth = 200
        local buttonSpacing = 10
        local buttonHeight = ui.theme.button.height
        local panelHeight = titleHeight + (#jointTypes * (buttonHeight + buttonSpacing)) + buttonSpacing

        ui.panel(startX, startY, panelWidth, panelHeight, '', function()
            local layout = ui.createLayout({
                type = 'columns',
                spacing = buttonSpacing,
                startX = startX + 10,
                startY = startY + 10
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
            local g, value = ui.checkbox(x, y, uiState.showGrid, 'grid') --showGrid = true,
            if g then
                uiState.showGrid = value
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
    -- Properties Panel
    if uiState.currentlySelectedObject then
        local panelWidth = 300
        local w, h = love.graphics.getDimensions()
        ui.panel(w - panelWidth - 20, 20, panelWidth, h - 40, '∞ body props ∞', function()
            local body = uiState.currentlySelectedObject:getBody()
            local angleDegrees = body:getAngle() * 180 / math.pi
            local sliderID = tostring(body)

            -- Initialize Layout
            local padding = 10
            local layout = ui.createLayout({
                type = 'columns',
                spacing = 10,
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
            x, y = ui.nextLayoutPosition(layout, 160, 50)
            if ui.button(x, y, 260, currentBodyType) then
                body:setType(nextBodyType)
                body:setAwake(true)
            end

            x, y = ui.nextLayoutPosition(layout, 160, 50)
            local dirty, checked = ui.checkbox(x, y, body:isFixedRotation(), 'fixed rotation')
            if dirty then
                body:setFixedRotation(not body:isFixedRotation())
            end

            -- Angle Slider
            local x, y = ui.nextLayoutPosition(layout, 160, 50)
            local newAngle = ui.sliderWithInput(sliderID .. 'angle', x, y, 160, -180, 180, angleDegrees,
                body:isAwake() and not worldState.paused)
            if newAngle and angleDegrees ~= newAngle then
                body:setAngle(newAngle * math.pi / 180)
            end
            ui.label(x, y, ' angle')

            -- Density Slider
            local fixtures = body:getFixtures()
            if #fixtures >= 1 then
                local density = fixtures[1]:getDensity()
                x, y = ui.nextLayoutPosition(layout, 160, 50)
                local newDensity = ui.sliderWithInput(sliderID .. 'density', x, y, 160, 0, 10, density)
                if newDensity and density ~= newDensity then
                    for i = 1, #fixtures do
                        fixtures[i]:setDensity(newDensity)
                    end
                end
                ui.label(x, y, ' density')

                -- Bounciness Slider
                local bounciness = fixtures[1]:getRestitution()
                x, y = ui.nextLayoutPosition(layout, 160, 50)
                local newBounce = ui.sliderWithInput(sliderID .. 'bounciness', x, y, 160, 0, 1, bounciness)
                if newBounce and bounciness ~= newBounce then
                    for i = 1, #fixtures do
                        fixtures[i]:setRestitution(newBounce)
                    end
                end
                ui.label(x, y, ' bounciness')

                -- Friction Slider
                local friction = fixtures[1]:getFriction()
                x, y = ui.nextLayoutPosition(layout, 160, 50)
                local newFriction = ui.sliderWithInput(sliderID .. 'friction', x, y, 160, 0, 1, friction)
                if newFriction and friction ~= newFriction then
                    for i = 1, #fixtures do
                        fixtures[i]:setFriction(newFriction)
                    end
                end
                ui.label(x, y, ' friction')
            end




            -- List Attached Joints Using Body:getJoints()
            local attachedJoints = body:getJoints()
            if attachedJoints and #attachedJoints > 0 then
                ui.label(x, y + 60, '∞ joints ∞')
                x, y = ui.nextLayoutPosition(layout, 160, 50)

                -- layout:nextRow()

                for _, joint in ipairs(attachedJoints) do
                    -- Display joint type and unique identifier for identification
                    local jointType = joint:getType()
                    local jointID = tostring(joint)
                    if (jointType ~= 'mouse') then
                        -- Display joint button
                        x, y = ui.nextLayoutPosition(layout, 160, 30)
                        local jointLabel = string.format("%s", jointType)

                        if ui.button(x, y, 160, jointLabel) then
                            uiState.selectedJoint = joint
                        end
                    end
                    --layout:nextRow()
                end
            end
        end)
    end

    if uiState.jointCreationMode and uiState.jointCreationMode.body1 and uiState.jointCreationMode.body2 then
        ui.panel(500, 100, 300, 400, uiState.jointCreationMode.jointType .. ' joint', function()
            local layout = ui.createLayout({
                type = 'columns',
                spacing = 10,
                startX = 500 + 10,
                startY = 100 + 10
            })

            local width = 280
            local jointType = uiState.jointCreationMode.jointType
            local x, y = ui.nextLayoutPosition(layout, 160, 50)

            if jointType == 'distance' then
                -- Length
                x, y = ui.nextLayoutPosition(layout, 160, 50)
                local x1, y1 = uiState.jointCreationMode.body1:getPosition()
                local x2, y2 = uiState.jointCreationMode.body2:getPosition()
                local defaultLength = ((x2 - x1) ^ 2 + (y2 - y1) ^ 2) ^ 0.5
                local length = ui.sliderWithInput('length', x, y, 160, 0.1, 500,
                    uiState.jointCreationMode.length or defaultLength)
                ui.label(x, y, 'Length')
                if length then
                    uiState.jointCreationMode.length = length
                end
            elseif jointType == 'motor' then
                x, y = ui.nextLayoutPosition(layout, 160, 50)
                local maxForce = ui.sliderWithInput('maxForce', x, y, 160, 0, 10000,
                    uiState.jointCreationMode.maxForce or 1000)
                ui.label(x, y, 'Max Force')
                if maxForce then
                    uiState.jointCreationMode.maxForce = maxForce
                end

                x, y = ui.nextLayoutPosition(layout, 160, 50)
                local maxTorque = ui.sliderWithInput('maxTorque', x, y, 160, 0, 10000,
                    uiState.jointCreationMode.maxTorque or 1000)
                ui.label(x, y, 'Max Torque')
                if maxTorque then
                    uiState.jointCreationMode.maxTorque = maxTorque
                end
                x, y = ui.nextLayoutPosition(layout, 160, 50)

                local correctionFactor = ui.sliderWithInput('correctionFactor', x, y, 160, 0, 1,
                    uiState.jointCreationMode.correctionFactor or 1)
                ui.label(x, y, 'Correction')
                if correctionFactor then
                    uiState.jointCreationMode.correctionFactor = correctionFactor
                end
            elseif jointType == 'wheel' then
                x, y = ui.nextLayoutPosition(layout, 160, 50)
                -- Frequency
                local frequency = ui.sliderWithInput('frequency', x, y, 160, 0, 10,
                    uiState.jointCreationMode.frequency or 5)
                ui.label(x, y, 'Frequency')
                if frequency then
                    uiState.jointCreationMode.frequency = frequency
                end
                --y = y + 60
                -- Damping Ratio
                x, y = ui.nextLayoutPosition(layout, 160, 50)
                local dampingRatio = ui.sliderWithInput('damping', x, y, 160, 0, 1,
                    uiState.jointCreationMode.dampingRatio or 0.7)
                ui.label(x, y, 'Damping')
                if dampingRatio then
                    uiState.jointCreationMode.dampingRatio = dampingRatio
                end
                -- y = y + 60
            elseif jointType == 'rope' then
                -- Max Length
                x, y = ui.nextLayoutPosition(layout, 160, 50)
                local x1, y1 = uiState.jointCreationMode.body1:getPosition()
                local x2, y2 = uiState.jointCreationMode.body2:getPosition()
                local defaultLength = ((x2 - x1) ^ 2 + (y2 - y1) ^ 2) ^ 0.5
                local maxLength = ui.sliderWithInput('maxLength', x, y, 160, 0.1, 500,
                    uiState.jointCreationMode.maxLength or defaultLength)
                ui.label(x, y, 'Max Length')
                if maxLength then
                    uiState.jointCreationMode.maxLength = maxLength
                end
                -- y = y + 60
            elseif jointType == 'pulley' then
                -- Ratio
                x, y = ui.nextLayoutPosition(layout, 160, 50)
                local ratio = ui.sliderWithInput('ratio', x, y, 160, 0.1, 10, uiState.jointCreationMode.ratio or 1)
                ui.label(x, y, 'Ratio')
                if ratio then
                    uiState.jointCreationMode.ratio = ratio
                end
                --  y = y + 60
            elseif jointType == 'friction' then
                -- Max Force
                x, y = ui.nextLayoutPosition(layout, 160, 50)
                local maxForce = ui.sliderWithInput('maxForce', x, y, 160, 0, 1000,
                    uiState.jointCreationMode.maxForce or 10)
                ui.label(x, y, 'Max Force')
                if maxForce then
                    uiState.jointCreationMode.maxForce = maxForce
                end
                --y = y + 60
                -- Max Torque
                x, y = ui.nextLayoutPosition(layout, 160, 50)
                local maxTorque = ui.sliderWithInput('maxTorque', x, y, 160, 0, 1000,
                    uiState.jointCreationMode.maxTorque or 10)
                ui.label(x, y, 'Max Torque')
                if maxTorque then
                    uiState.jointCreationMode.maxTorque = maxTorque
                end
                --  y = y + 60
            end

            -- "Create Joint" and "Cancel" Buttons
            -- y = y + 50
            x, y = ui.nextLayoutPosition(layout, 160, 50)
            if ui.button(x, y, width, 'Create Joint') then
                createJoint(uiState.jointCreationMode)
                uiState.jointCreationMode = nil
            end
            x, y = ui.nextLayoutPosition(layout, 160, 50)
            --y = y + 50
            if ui.button(x, y, width, 'Cancel') then
                uiState.jointCreationMode = nil
            end
        end)
    end





    if uiState.jointCreationMode and ((uiState.jointCreationMode.body1 == nil) or (uiState.jointCreationMode.body2 == nil)) then
        if (uiState.jointCreationMode.body1 == nil) then
            ui.panel(500, 100, 300, 100, '• pick 1st body •', function()
                local x = 510
                local y = 150
                local width = 280
                if ui.button(x, y, width, 'Cancel') then
                    uiState.jointCreationMode = nil
                end
            end)
        elseif (uiState.jointCreationMode.body2 == nil) then
            ui.panel(500, 100, 300, 100, '• pick 2nd body •', function()
                local x = 510
                local y = 150
                local width = 280
                if ui.button(x, y, width, 'Cancel') then
                    uiState.jointCreationMode = nil
                end
            end)
        end
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
        local lw = love.graphics.getLineWidth()
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, .1)
        local w, h = love.graphics.getDimensions()
        local tlx, tly = cam:getWorldCoordinates(0, 0)
        local brx, bry = cam:getWorldCoordinates(w, h)
        local step = worldState.meter
        local roundedStartX = math.floor(tlx / step) * step
        local roundedEndX = math.ceil(brx / step) * step
        local roundedStartY = math.floor(tly / step) * step
        local roundedEndY = math.ceil(bry / step) * step

        for i = roundedStartX, roundedEndX, step do
            local x, _ = cam:getScreenCoordinates(i, 0)
            love.graphics.line(x, 0, x, h)
        end
        for i = roundedStartY, roundedEndY, step do
            local _, y = cam:getScreenCoordinates(0, i)

            love.graphics.line(0, y, w, y)
        end
        love.graphics.setLineWidth(lw)
        love.graphics.setColor(1, 1, 1, 1)
        --print(w)
    end
    cam:push()
    phys.drawWorld(world)
    if (uiState.currentlySelectedObject) then
        --        phys.drawSelected(uiState.currentlySelectedObject:getBody())
    end
    if uiState.isDrawingPolygon then
        --print(inspect(uiState.polygonVertices))
        if (#uiState.polygonVertices > 3) then
            local polygon = {}
            for i = 1, #uiState.polygonVertices do
                table.insert(polygon, uiState.polygonVertices[i].x)
                table.insert(polygon, uiState.polygonVertices[i].y)
            end
            --print(inspect(polygon))
            love.graphics.polygon('line', polygon)
        end
    end
    cam:pop()
    drawUI()
    if uiState.maybeHideSelectedPanel then
        if not (ui.activeElementID or ui.focusedTextInputID) then
            uiState.currentlySelectedObject = nil
        end
        uiState.maybeHideSelectedPanel = false
    end
    love.graphics.print(string.format("%03d", love.timer.getFPS()), w - 80, 10)
end

function love.wheelmoved(dx, dy)
    local newScale = cam.scale * (1 + dy / 10)
    if newScale > 0.01 and newScale < 50 then
        cam:scaleToPoint(1 + dy / 10)
    end
end

function love.mousemoved(x, y, dx, dy)
    if uiState.isCapturingPolygon then
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
            table.insert(uiState.polygonVertices, { x = wx, y = wy })
            uiState.lastPolygonPoint = { x = wx, y = wy }
        end
    elseif love.keyboard.isDown('space') or love.mouse.isDown(3) then
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
    local _, hitted = phys.handlePointerPressed(cx, cy, id, onPressedParams, not worldState.paused)
    if #hitted > 0 then
        uiState.currentlySelectedObject = hitted[1]
        if (worldState.paused) then
            if uiState.jointCreationMode then
                if uiState.jointCreationMode.body1 == nil then
                    uiState.jointCreationMode.body1 = uiState.currentlySelectedObject:getBody()
                elseif uiState.jointCreationMode.body2 == nil then
                    if (uiState.currentlySelectedObject:getBody() ~= uiState.jointCreationMode.body1) then
                        uiState.jointCreationMode.body2 = uiState.currentlySelectedObject:getBody()
                    end
                end
            else
                local ud = uiState.currentlySelectedObject:getBody():getUserData()
                uiState.currentlyDraggingObject = ud.thing

                local offx, offy = ud.thing.body:getLocalPoint(cx, cy)
                uiState.offsetForCurrentlyDragging = { -offx, -offy }
            end
        end
    else
        uiState.maybeHideSelectedPanel = true
    end
end

function love.mousepressed(x, y, button, istouch)
    if not istouch and button == 1 then
        if uiState.isDrawingPolygon then
            -- Start capturing mouse movement
            uiState.isCapturingPolygon = true
            uiState.polygonVertices = {}
            uiState.lastPolygonPoint = nil
        else
            pointerPressed(x, y, 'mouse')
        end
    end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    pointerPressed(x, y, id)
end

local function tableConcat(t1, t2)
    for i = 1, #t2 do
        table.insert(t1, t2[i])
    end
    return t1
end
function createPolygonShape(vertices)
    -- Convert vertices to a format suitable for love.math.triangulate()

    local polygon = {}
    for _, vertex in ipairs(vertices) do
        table.insert(polygon, vertex.x)
        table.insert(polygon, vertex.y)
    end

    local allowComplex = true -- todo parametrize this
    local triangles

    if allowComplex then
        local result = {}
        decompose.decompose_complex_poly(polygon, result)
        triangles = {}
        for i = 1, #result do
            local tris = love.math.triangulate(result[i])
            tableConcat(triangles, tris)
        end
    else
        triangles = love.math.triangulate(polygon)
    end
    if #triangles == 0 then
        print("Failed to triangulate polygon.")
        return
    end

    -- Create the physics body
    local bodyType = uiState.bodyTypeOfNextSpawn or 'dynamic'
    -- Compute centroid for body position
    local centroidX, centroidY = computeCentroid(vertices)
    local body = love.physics.newBody(world, centroidX, centroidY, bodyType)

    -- Create fixtures for each triangle
    for _, triangle in ipairs(triangles) do
        -- Adjust triangle vertices relative to body position
        local localVertices = {}
        for i = 1, #triangle, 2 do
            local x = triangle[i] - centroidX
            local y = triangle[i + 1] - centroidY
            table.insert(localVertices, x)
            table.insert(localVertices, y)
        end
        local shape = love.physics.newPolygonShape(localVertices)
        local fixture = love.physics.newFixture(body, shape, 1)
        fixture:setRestitution(0.3)
    end

    -- Store the body in your simulation
    body:setUserData({ thing = { body = body } })
end

function computeCentroid(vertices)
    local sumX, sumY = 0, 0
    for _, vertex in ipairs(vertices) do
        sumX = sumX + vertex.x
        sumY = sumY + vertex.y
    end
    local count = #vertices
    return sumX / count, sumY / count
end

function finalizePolygon()
    if #uiState.polygonVertices >= 3 then
        -- Proceed to triangulate and create the physics body
        createPolygonShape(uiState.polygonVertices)
    else
        -- Not enough vertices to form a polygon
        print("Not enough vertices to create a polygon.")
    end
    -- Reset the drawing state
    uiState.isDrawingPolygon = false
    uiState.isCapturingPolygon = false
    uiState.polygonVertices = {}
    uiState.lastPolygonPoint = nil
end

local function pointerReleased(x, y, id)
    phys.handlePointerReleased(x, y, id)
    if uiState.currentlyDraggingObject then
        finalizeSpawn()
    end
    if uiState.isDrawingPolygon then
        finalizePolygon()
        --print('releasde')
    end
end

function love.mousereleased(x, y, button, istouch)
    if not istouch then
        pointerReleased(x, y, 'mouse')
    end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    pointerReleased(x, y, id)
end

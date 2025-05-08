-- NOTE MAKE REVOLUTE JOINTS ALWAYS FROM PARENT TO CHILD!!!!!!!!

-- TODO there is an issue where the .vertices arent populated after load.
-- TODO src/object-manager.lua:666:	I should figure out if i want to do something weird with the offset, think connect to torso logic at edge nr...
-- TODO look for : destroybody doesnt destroy the joint on it ?
-- TODO dirty list for textures that need to be remade, (box2d-draw-textured)
-- TODO in character manager, the w and h arent used when we have a shape 8 i prbaly want to calculate sx and sy depending on w and h instead of not using them
-- DOING playing around with characters, getting them back in the system
-- TODO swap body parts
-- TODO add some ui to change body properties

logger = require 'src.logger'
inspect = require 'vendor.inspect'

local blob = require 'vendor.loveblobs'
local Peeker = require 'vendor.peeker'
local recorder = require 'src.recorder'
local ui = require 'src.ui-all'
local playtimeui = require 'src.playtime-ui'

local selectrect = require 'src.selection-rect'
local script = require 'src.script'
local objectManager = require 'src.object-manager'

local utils = require 'src.utils'
local box2dDraw = require 'src.box2d-draw'
local box2dDrawTextured = require 'src.box2d-draw-textured'
local box2dPointerJoints = require 'src.box2d-pointerjoints'
local camera = require 'src.camera'
local cam = camera.getInstance()


snap = require 'src.snap'
registry = require 'src.registry'

local InputManager = require 'src.input-manager'
local state = require 'src.state'
local sceneLoader = require 'src.scene-loader'
local editorRenderer = require 'src.editor-render'
local CharacterManager = require 'src.character-manager'

function waitForEvent()
    local a
    repeat
        a = love.event.wait()
        print(a)
    until a == "focus" or a == 'mousepressed' or a == 'touchpressed'
end

waitForEvent()

local FIXED_TIMESTEP = true
local FPS = 60 -- in platime ui we also have a fps
local TICKRATE = 1 / FPS

function love.load(args)
    --


    local fontHeight = 25
    --local font = love.graphics.newFont('assets/cooper_bold_bt.ttf', fontHeight)
    --local font = love.graphics.newFont('assets/QuentinBlakeRegular.otf', fontHeight)
    local font = love.graphics.newFont('assets/Arial Narrow.ttf', fontHeight)

    love.keyboard.setKeyRepeat(true)
    love.graphics.setFont(font)

    ui.init(font, fontHeight)

    love.physics.setMeter(state.world.meter)
    state.physicsWorld = love.physics.newWorld(0, state.world.gravity * love.physics.getMeter(), true)

    local w, h = love.graphics.getDimensions()
    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(325, 325, 2000, 2000)

    objectManager.addThing('rectangle', { x = 200, y = 400, height = 100, width = 400 })

    -- -- Adding custom polygon
    local customVertices = {
        250, 0,
        0, 300,
        500, 300,
        -- Add more vertices as needed
    }

    objectManager.addThing('custom', { vertices = customVertices })
    --objectManager.addThing('custom', 0, 0, 'dynamic', nil, nil, nil, nil, 'CustomShape', customVertices)

    if state.world.playWithSoftbodies then
        local b = blob.softbody(state.physicsWorld, 500, 0, 102, 1, 1)
        b:setFrequency(3)
        b:setDamping(0.1)
        --b:setFriction(1)

        table.insert(state.world.softbodies, b)
        local points = {
            0, 500, 800, 500,
            800, 800, 0, 800
        }
        local b = blob.softsurface(state.physicsWorld, points, 120, "dynamic")
        table.insert(state.world.softbodies, b)
        b:setJointFrequency(2)
        b:setJointDamping(.1)
        --b:setFixtureRestitution(2)
        -- b:setFixtureFriction(10)
    end



    state.physicsWorld:setCallbacks(beginContact, endContact, preSolve, postSolve)


    --local cwd = love.filesystem.getWorkingDirectory()
    --loadScene(cwd .. '/scripts/snap2.playtime.json')
    --loadScene(cwd .. '/scripts/grow.playtime.json')

    --loadScriptAndScene('elasto')
    --  sceneLoader.loadScriptAndScene('snap')
    --sceneLoader.loadScriptAndScene('straight')
    local cwd = love.filesystem.getWorkingDirectory()
    sceneLoader.loadScene(cwd .. '/scripts/empty.playtime.json')
    -- sceneLoader.loadScene(cwd .. '/scripts/limits.playtime.json')
    --sceneLoader.loadScene(cwd .. '/scripts/limitsagain.playtime.json')



    humanoidInstance = CharacterManager.createCharacter("humanoid", 300, 300)


    --CharacterManager.updateSinglePart('luleg', { h = 300 }, humanoidInstance)
    --CharacterManager.updateSinglePart('ruleg', { h = 300 }, humanoidInstance)

    -- logger:inspect(humanoidInstance.dna)
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

function love.update(dt)
    if recorder.isRecording or recorder.isReplaying then
        recorder:update(dt)
    end

    Peeker.update(dt)
    sceneLoader.maybeHotReload(dt)

    local scaled_dt = dt * state.world.speedMultiplier
    if not state.world.paused then
        if state.world.playWithSoftbodies then
            for i, v in ipairs(state.world.softbodies) do
                v:update(scaled_dt)
            end
        end
        local velocityiterations = 8
        local positioniterations = 13 -- 3
        for i = 1, 1 do
            state.physicsWorld:update(scaled_dt, velocityiterations, positioniterations)
        end
        script.call('update', scaled_dt)

        snap.update(scaled_dt)
    end


    if recorder.isRecording and utils.tablelength(recorder.recordingMouseJoints) > 0 then
        recorder:recordMouseJointUpdates(cam)
    end

    box2dPointerJoints.handlePointerUpdate(scaled_dt, cam)
    --phys.handleUpdate(dt)

    if state.interaction.draggingObj then
        InputManager.handleDraggingObj()
    end
end

function love.draw()
    Peeker.attach()
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(120 / 255, 125 / 255, 120 / 255)

    if state.editorPreferences.showGrid then
        editorRenderer.drawGrid()
    end

    box2dDrawTextured.makeCombinedImages()
    cam:push()
    love.graphics.setColor(1, 1, 1, 1)
    box2dDraw.drawWorld(state.physicsWorld, state.world.debugDrawMode)
    box2dDrawTextured.drawTexturedWorld(state.physicsWorld)

    script.call('draw')

    editorRenderer.renderActiveEditorThings()
    cam:pop()



    -- love.graphics.print(string.format("%.1f", (love.timer.getTime() - now)), 0, 0)
    --love.graphics.print(string.format("%03d", love.timer.getTime()), 100, 100)

    Peeker.detach()
    if state.interaction.startSelection then
        selectrect.draw(state.interaction.startSelection)
    end


    playtimeui.drawUI()
    script.call('drawUI')

    if recorder.isRecording then
        love.graphics.setColor(1, 0, 0)
        love.graphics.circle('fill', 20, 20, 20)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(string.format("%.1f", love.timer.getTime() - recorder.startTime), 5, 5)
    end

    if state.scene.sceneScript and state.scene.sceneScript.foundError then
        love.graphics.setColor(1, 0, 0)
        love.graphics.print(state.scene.sceneScript.foundError, 0, h / 2)
        love.graphics.setColor(1, 1, 1)
    end

    if FIXED_TIMESTEP then
        love.graphics.print('f' .. string.format("%02d", 1 / TICKRATE), w - 80, 10)
    else
        love.graphics.print(string.format("%03d", love.timer.getFPS()), w - 80, 10)
    end
end

function love.wheelmoved(dx, dy)
    if not ui.overPanel then
        local newScale = cam.scale * (1 + dy / 10)
        if newScale > 0.01 and newScale < 50 then
            cam:scaleToPoint(1 + dy / 10)
        end
    end
    ui.mouseWheelDx = dx
    ui.mouseWheelDy = dy
end

function love.filedropped(file)
    local name = file:getFilename()
    if string.find(name, '.playtime.json') then
        script.call('onSceneUnload')
        sceneLoader.loadScene(name)
        script.call('onSceneLoaded')
    end
    if string.find(name, '.playtime.lua') then
        sceneLoader.loadAndRunScript(name)
    end
end

function love.textinput(t)
    ui.handleTextInput(t)
end

function love.keypressed(key)
    ui.handleKeyPress(key)
    InputManager.handleKeyPressed(key)
    script.call('onKeyPress', key)

    if key == 'r' then
        CharacterManager.updatePart('torso1', { sy = love.math.random() * 2, sx = love.math.random() * 12 },
            humanoidInstance)
        -- CharacterManager.updatePart('torso2', { sy = love.math.random() * 2 }, humanoidInstance)
        -- CharacterManager.updatePart('torso3', { sy = love.math.random() * 2 }, humanoidInstance)
        -- CharacterManager.updatePart('torso4', { sy = love.math.random() * 2, sx = love.math.random() * 12 },
        --     humanoidInstance)
        --  CharacterManager.updatePart('head', { sy = love.math.random() * 10 }, humanoidInstance)
        --CharacterManager.updatePart('luleg', { h = 20 + love.math.random() * 400 }, humanoidInstance)
    end
end

function love.mousemoved(x, y, dx, dy)
    InputManager.handleMouseMoved(x, y, dx, dy)
end

function love.mousepressed(x, y, button, istouch)
    InputManager.handleMousePressed(x, y, button, istouch)
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    InputManager.handleTouchPressed(id, x, y, dx, dy, pressure)
end

function love.mousereleased(x, y, button, istouch)
    InputManager.handleMouseReleased(x, y, button, istouch)
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    InputManager.handleTouchReleased(id, x, y, dx, dy, pressure)
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
            lag = lag + elapsed * state.world.speedMultiplier

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
--

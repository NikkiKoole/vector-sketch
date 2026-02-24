-- Test mode: run with 'love . --test'
if arg[1] == '--test' or arg[2] == '--test' then
    require('tests.run').run()
    love.event.quit(0)
    return
end

-- Spec mode: run busted specs inside LÖVE with 'love . --specs'
if arg[1] == '--specs' or arg[2] == '--specs' then
    require('run-specs')
    return
end

-- NOTE MAKE REVOLUTE JOINTS ALWAYS FROM PARENT TO CHILD!!!!!!!!

-- TODO there is an issue where the .vertices arent populated after load.
-- TODO src/object-manager.lua:666: I should figure out if i want to do something weird with the offset,
-- think connect to torso logic at edge nr...
-- TODO look for : destroybody doesnt destroy the joint on it ?
-- TODO dirty list for textures that need to be remade, (box2d-draw-textured)
-- TODO in character manager, the w and h arent used when we have a shape 8 i prbaly want to
-- calculate sx and sy depending on w and h instead of not using them
-- TODO swap body parts
-- TODO add some ui to change body properties

-- TODO z-order for characters is predefined
-- TODO characters could be facing 3 ways (facingleft/facingright/facingfront)
-- TODO group id < 0 but different per character

-- TODO how to handle referebce to humanoid after reload? maybe do a first humanoid for debug?
--
-- TODO some sfixtures end up with sensor=false , i dunno why yet.

--- strategy of performance tuning
--- for the 'vendor.jprof' to give clear result it needs to be off.
--- to see the memory churn the best you should turn off manual_gc too.
--- when you are happy you can turn back on the jit and manual_gc to improve framerate.


-- local ffi = require "ffi"

-- ffi.cdef [[
-- int printf(const char *fmt, ...);
-- ]]

-- ffi.C.printf("Hi hello from C!\n")

local bridge = require 'vendor.claude-bridge'
local lurker = require 'vendor.lurker'
local _lurker_onerror = lurker.onerror
lurker.onerror = function(e, nostacktrace)
    bridge.recordError("lurker", e)
    _lurker_onerror(e, nostacktrace)
end
-- Keep bridge alive during lurker error state
lurker.errorupdate = function(_dt)
    bridge.update()
end
require 'src.logger'
require 'vendor.inspect'
local prof = require 'vendor.jprof'
local manual_gc = require 'vendor.batteries.manual_gc'
jit.off() -- luacheck: ignore 113 (jit is a LuaJIT global)
require 'vendor.ProFi'

local blob = require 'vendor.loveblobs'
local Peeker = require 'vendor.peeker'
local recorder = require 'src.recorder'
local ui = require 'src.ui-all'
local playtimeui = require 'src.playtime-ui'

local selectrect = require 'src.selection-rect'
local script = require 'src.script'
require 'src.object-manager'


--local moonshine = require 'moonshine'


local utils = require 'src.utils'
local box2dDraw = require 'src.box2d-draw'
local box2dDrawTextured = require 'src.box2d-draw-textured'
local box2dPointerJoints = require 'src.box2d-pointerjoints'
local camera = require 'src.camera'
local cam = camera.getInstance()
require 'src.uuid'

local snap = require 'src.snap'
local characterExperiments = require 'src.character-experiments'
local keep_angle = require 'src.keep-angle'
require 'src.registry'


require 'src.math-utils'

local InputManager = require 'src.input-manager'
local state = require 'src.state'
local sceneLoader = require 'src.scene-loader'
local editorRenderer = require 'src.editor-render'
require 'src.character-manager'



local function waitForEvent()
    local a
    repeat
        a = love.event.wait()
        print(a)
    until a == "focus" or a == 'mousepressed' or a == 'touchpressed'
end

-- Skip wait screen when launched with --bridge (for automated/AI use)
local skip_wait = false
for _, v in ipairs(arg or {}) do
    if v == '--bridge' then skip_wait = true end
end
if not skip_wait then
    waitForEvent()
end

local FIXED_TIMESTEP = true
local FPS = 60 -- in platime ui we also have a fps
local TICKRATE = 1 / FPS



local humanoidInstance = nil -- uncomment a createCharacter call in love.load to enable character experiments

function love.load(_args)
    --
    -- logger:info('random seed:', love.math.getRandomSeed())

    --testGuid()


    --love.math.setRandomSeed(love.timer.getTime())
    -- logger:info('uuid:', uuid.generateID())
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

    --objectManager.addThing('rectangle', { x = 200, y = 400, height = 100, width = 400 })

    --objectManager.addThing('custom', { vertices = customVertices })
    --objectManager.addThing('custom', 0, 0, 'dynamic', nil, nil, nil, nil, 'CustomShape', customVertices)



    --effect = moonshine(moonshine.effects.dmg)
    --.chain(moonshine.effects.vignette)
    --effect.filmgrain.size = 2

    -- todo this can be optimized, maybe first figure out what kind of script if any we have running.
    --state.physicsWorld:setCallbacks(beginContact, endContact, preSolve, postSolve)


    local cwd = love.filesystem.getWorkingDirectory()
    -- sceneLoader.loadScene(cwd .. '/scripts/snap2.playtime.json')
    --sceneLoader.loadScriptAndScene('water')
    -- sceneLoader.loadScene(cwd .. '/scripts/resources.playtime.json')
     --sceneLoader.loadScene(cwd .. '/scripts/beginmesh.playtime.json')
     sceneLoader.loadScene(cwd .. '/scripts/test.playtime.json')
    -- sceneLoader.loadAndRunScript(cwd .. '/scripts/mesh_test.playtime.lua')

    --loadScriptAndScene('elasto')
    --sceneLoader.loadScriptAndScene('water')
    -- sceneLoader.loadScriptAndScene('straight')

    --local cwd = love.filesystem.getWorkingDirectory()
    --sceneLoader.loadScene(cwd .. '/scripts/empty2.playtime.json')
    --   sceneLoader.loadScene(cwd .. '/scripts/knutjump.playtime.json')


    -- sceneLoader.loadScene(cwd .. '/scripts/limits.playtime.json')
    --sceneLoader.loadScene(cwd .. '/scripts/limitsagain.playtime.json')
    --humanoidInstance = CharacterManager.createCharacter("humanoid", 100, 300, .15)
    --  humanoidInstance = CharacterManager.createCharacter("humanoid", 300, 300, .3)


    --humanoidInstance = CharacterManager.createCharacter("humanoid", 800, 300, .1)

    if state.world.playWithSoftbodies then
        local softBody = blob.softbody(state.physicsWorld, 500, 0, 102, 1, 1)
        softBody:setFrequency(3)
        softBody:setDamping(0.1)
        --softBody:setFriction(1)

        table.insert(state.world.softbodies, softBody)
        local points = {
            0, 500, 800, 500,
            800, 800, 0, 800
        }
        local softSurface = blob.softsurface(state.physicsWorld, points, 120, "dynamic")
        table.insert(state.world.softbodies, softSurface)
        softSurface:setJointFrequency(2)
        softSurface:setJointDamping(.1)
        --b:setFixtureRestitution(2)
        -- b:setFixtureFriction(10)
    end

    -- if state.backdrop and state.backdrop.url then
    --     state.backdrop.image = love.graphics.newImage(state.backdrop.url)
    -- end

    -- humanoidInstance = CharacterManager.createCharacter("humanoid", 300, 800, .5)
    --humanoidInstance = CharacterManager.createCharacter("humanoid", 500, 300)
    -- humanoidInstance = CharacterManager.createCharacter("humanoid", 700, 300)
    -- humanoidInstance = CharacterManager.createCharacter("humanoid", 900, 300)
    -- humanoidInstance = CharacterManager.createCharacter("humanoid", 1100, 300)
    -- humanoidInstance = CharacterManager.createCharacter("humanoid", 1300, 300)
    -- humanoidInstance = CharacterManager.createCharacter("humanoid", 1500, 300)
    -- humanoidInstance = CharacterManager.createCharacter("humanoid", 1700, 300)
    -- humanoidInstance = CharacterManager.createCharacter("humanoid", 1900, 300)
    -- humanoidInstance = CharacterManager.createCharacter("humanoid", 2100, 300)
    -- humanoidInstance = CharacterManager.createCharacter("humanoid", 2300, 300)
    -- humanoidInstance = CharacterManager.createCharacter("humanoid", 2500, 300)
    -- humanoidInstance = CharacterManager.createCharacter("humanoid", 2700, 300)
end

local function beginContact(fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
    if bridge.destroying_body then return end
    bridge.logCollision('beginContact', fix1, fix2, contact)
    script.call('beginContact', fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
end

local function endContact(fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
    if bridge.destroying_body then return end
    bridge.logCollision('endContact', fix1, fix2, contact)
    script.call('endContact', fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
end

local function preSolve(fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
    if bridge.destroying_body then return end
    script.call('preSolve', fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
end

local function postSolve(fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
    if bridge.destroying_body then return end
    bridge.logCollision('postSolve', fix1, fix2, contact, n_impulse1, tan_impulse1)
    script.call('postSolve', fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
end

-- Expose callbacks on state so the bridge can access them
state.physicsCallbacks = { beginContact, endContact, preSolve, postSolve }

local beginframetime = love.timer.getTime()

function love.update(dt)
    bridge.update()
    lurker.update()
    prof.push('frame')

    --if ProFi.has_started == true and ProFi.has_finished == false then
    --    ProFi:checkMemory(0, "love.update")
    -- end

    beginframetime = love.timer.getTime()
    if recorder.isRecording or recorder.isReplaying then
        recorder:update(dt)
    end

    Peeker.update(dt)
    sceneLoader.maybeHotReload(dt)

    local scaled_dt = dt * state.world.speedMultiplier
    prof.push('physics-update')
    if not state.world.paused then
        if state.world.playWithSoftbodies then
            for _, v in ipairs(state.world.softbodies) do
                v:update(scaled_dt)
            end
        end
        local velocityiterations = 8 --* 2
        local positioniterations = 3 --* 2 -- 3
        -- for i = 1, 1 do
        --     state.physicsWorld:update(scaled_dt, velocityiterations, positioniterations)
        -- end


        local substeps = 1
        local step = scaled_dt / substeps
        prof.push('physicsWorld:update')
        for _ = 1, substeps do
            state.physicsWorld:update(step, velocityiterations * 2, positioniterations * 2)
        end
        prof.pop('physicsWorld:update')

        script.call('update', scaled_dt)
        --for i = 1, #joints do
        --correctJoint(joints[i])
        --end
        snap.update(scaled_dt)
        -- todo use pointerjoints instead!!!
        local interacted = box2dPointerJoints.getInteractedWithPointer()
        local newHitted = utils.map(interacted, function(h)
            local ud = (h:getUserData())
            local thing = ud and ud.thing
            return thing
        end)
        keep_angle.update(scaled_dt, newHitted)
    end
    prof.pop('physics-update')

    if recorder.isRecording and utils.tablelength(recorder.recordingMouseJoints) > 0 then
        recorder:recordMouseJointUpdates(cam)
    end
    prof.push('pointers')
    box2dPointerJoints.handlePointerUpdate(scaled_dt, cam)
    --phys.handleUpdate(dt)
    prof.pop('pointers')
    if state.interaction.draggingObj then
        InputManager.handleDraggingObj()
    end
    manual_gc(0.002, 2)
    prof.pop('frame')
end

function love.quit()
    -- this takes annoyingly long
    local time = love.timer.getTime()
    prof.write("prof.mpack")
    print('writing took', love.timer.getTime() - time, 'seconds')
end

function love.draw()
    prof.push('frame')

    --if ProFi.has_started == true and ProFi.has_finished == false then
    --    ProFi:checkMemory(0, "love.draw")
    --end
    Peeker.attach()
    local w, h = love.graphics.getDimensions()

    love.graphics.clear(120 / 255, 125 / 255, 120 / 255)

    if state.world.darkMode then
        love.graphics.clear(.1, 0.2, .1)
    else
        local creamy = { 245 / 255, 245 / 255, 220 / 255 } --#F5F5DC Creamy White:
        love.graphics.clear(creamy)
    end



    if state.editorPreferences.showGrid then
        editorRenderer.drawGrid(state.world.darkMode and { 1, 1, 1, .1 } or { 0, 0, 1, .1 })
    end
    --for i = 1, 100 do
    box2dDrawTextured.makeCombinedImages()
    --end
    --effect(function()
    cam:push()
    love.graphics.setColor(1, 1, 1, 1)


    -- if state.backdrop and state.backdrop.show then
    --     love.graphics.draw(state.backdrop.image, 0, 0)
    -- end
    if state.backdrops then
        for i = 1, #state.backdrops do
            local b = state.backdrops[i]
            if b.url and b.image == nil then
                b.image = love.graphics.newImage(b.url)
                b.w = b.image:getWidth()
                b.h = b.image:getHeight()
            end
            if b.selected then
                love.graphics.rectangle("line", b.x or 0, b.y or 0, b.image:getWidth(), b.image:getHeight())
            end
            if b.border then
                love.graphics.rectangle("line", b.x or 0, b.y or 0, b.image:getWidth(), b.image:getHeight())
            end
            love.graphics.draw(b.image, b.x or 0, b.y or 0)
        end
    end

    prof.push('drawworld')
    box2dDraw.drawWorld(state.physicsWorld, state.world.debugDrawMode)
    prof.pop('drawworld')
    prof.push('drawtexturedworld')
    if state.world.showTextures then
        box2dDrawTextured.drawTexturedWorld(state.physicsWorld)
    end
    prof.pop('drawtexturedworld')
    script.call('draw')

    editorRenderer.renderActiveEditorThings()
    cam:pop()
    -- end)
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
        local timediff = love.timer.getTime() - beginframetime
        if timediff > TICKRATE then
            love.graphics.setColor(1, 0, 0)
            love.graphics.print(timediff, w - 80, 50)
            love.graphics.setColor(1, 1, 1)
        end
    else
        love.graphics.print(string.format("%03d", love.timer.getFPS()), w - 80, 10)
    end
    prof.pop('frame')
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

local function getRelativePath(absPath, cwd)
    -- Normalize both so they don't end with a slash
    cwd = cwd:gsub("/+$", "")
    absPath = absPath:gsub("/+$", "")

    -- Ensure absPath starts with cwd
    if absPath:sub(1, #cwd) == cwd then
        local rel = absPath:sub(#cwd + 1)
        return rel ~= "" and rel or "/"
    end

    return nil -- not inside working directory
end
function love.filedropped(file)
    local name = file:getFilename()
    if string.find(name, '.playtime.json') then
        script.call('onSceneUnload')
        sceneLoader.loadScene(name)
        script.call('onSceneLoaded')
        return
    end
    if string.find(name, '.playtime.lua') then
        sceneLoader.loadAndRunScript(name)
        return
    end

    local x, y = love.mouse:getPosition()
    local wx, wy = cam:getWorldCoordinates(x, y)
    local cwd = love.filesystem.getWorkingDirectory()
    local relative = getRelativePath(name, cwd)
    if relative then
        table.insert(state.backdrops, { x = wx, y = wy, url = relative })
    end
end

function love.textinput(t)
    ui.handleTextInput(t)
end

function love.resize(_w, _h)
    --   effect.resize(w, h)
end

function love.keypressed(key)
    ui.handleKeyPress(key)
    InputManager.handleKeyPressed(key)
    script.call('onKeyPress', key)

    if not ui.focusedTextInputID then
        characterExperiments.handleKeyPress(key, humanoidInstance)
    end
end

function love.mousemoved(x, y, dx, dy)
    InputManager.handleMouseMoved(x, y, dx, dy)
    if state.panelVisibility.bgSettingsOpened then
        if love.mouse.isDown(1) then
            for i = 1, #state.backdrops do
                local b = state.backdrops[i]
                if b.selected then
                    local wx, wy = cam:getWorldCoordinates(x, y)
                    b.x = wx
                    b.y = wy
                end
            end
        end
    end
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
    local gameLoop = require("src.game-loop")
    love.run = gameLoop.createFixedTimestepRun(TICKRATE)
end

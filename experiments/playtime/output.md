main.lua
```lua
-- NOTE MAKE REVOLUTE JOINTS ALWAYS FROM PARENT TO CHILD!!!!!!!!

-- TODO there is an issue where the .vertices arent populated after load.
-- TODO src/object-manager.lua:666:	I should figure out if i want to do something weird with the offset, think connect to torso logic at edge nr...
-- TODO look for : destroybody doesnt destroy the joint on it ?
-- TODO dirty list for textures that need to be remade, (box2d-draw-textured)
-- TODO in character manager, the w and h arent used when we have a shape 8 i prbaly want to calculate sx and sy depending on w and h instead of not using them
-- TODO swap body parts
-- TODO add some ui to change body properties

-- BUG press R and then N , torso hair is not positioned correctly, also the wrong texture is displayed for a torso
-- also, this is because we do naot have a real DNA yet, i think what i mean with a real dns is a lookup table that tells me all the
-- decisions we need, now we have some stuff in the instance.textures but we do not 'know' why.
-- i alway see th etorso shape pop back to a circle
-- BUG , when preseing R, N, L you can see he specia fixtures grow too big

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


local moonshine = require 'moonshine'


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

    --effect = moonshine(moonshine.effects.dmg)
    --.chain(moonshine.effects.vignette)
    --effect.filmgrain.size = 2

    state.physicsWorld:setCallbacks(beginContact, endContact, preSolve, postSolve)


    --local cwd = love.filesystem.getWorkingDirectory()
    --loadScene(cwd .. '/scripts/snap2.playtime.json')
    --loadScene(cwd .. '/scripts/grow.playtime.json')

    --loadScriptAndScene('elasto')
    --sceneLoader.loadScriptAndScene('water')
    --sceneLoader.loadScriptAndScene('straight')

    local cwd = love.filesystem.getWorkingDirectory()
    sceneLoader.loadScene(cwd .. '/scripts/empty.playtime.json')

    -- sceneLoader.loadScene(cwd .. '/scripts/limits.playtime.json')
    --sceneLoader.loadScene(cwd .. '/scripts/limitsagain.playtime.json')

    humanoidInstance = CharacterManager.createCharacter("humanoid", 300, 300)
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

-- this is quite the fix, a bit janky, but i fixes all the issues where bodies and joints 'break' and freak out
-- we do need some sesible expectedDitsance
function correctJoint(joint)
    local expectedDistance = 10
    local bodyA, bodyB = joint:getBodies()
    local anchorAx, anchorAy, anchorBx, anchorBy = joint:getAnchors()
    local maxDist = 1.5 * expectedDistance -- use your rig specs

    local dx, dy = anchorBx - anchorAx, anchorBy - anchorAy
    local dist = math.sqrt(dx * dx + dy * dy)
    if bodyB then
        if dist > maxDist then
            -- Optionally move B toward A
            local fixX = anchorAx + dx * expectedDistance / dist
            local fixY = anchorAy + dy * expectedDistance / dist
            bodyB:setTransform(fixX, fixY, bodyB:getAngle())

            -- Optional: reset velocity
            bodyB:setLinearVelocity(0, 0)
            bodyB:setAngularVelocity(0)
        end
    end
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
        local joints = state.physicsWorld:getJoints()
        for i = 1, #joints do
            --correctJoint(joints[i])
        end
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
    --effect(function()
    cam:push()
    love.graphics.setColor(1, 1, 1, 1)
    box2dDraw.drawWorld(state.physicsWorld, state.world.debugDrawMode)

    box2dDrawTextured.drawTexturedWorld(state.physicsWorld)

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

local function randomHexColor()
    local r = math.random(0, 255)
    local g = math.random(0, 255)
    local b = math.random(0, 255)
    local a = 255 -- fully opaque, or adjust if you want random alpha

    return string.format("%02X%02X%02X%02X", r, g, b, a)
end

function love.resize(w, h)
    --   effect.resize(w, h)
end

function love.keypressed(key)
    ui.handleKeyPress(key)
    InputManager.handleKeyPressed(key)
    script.call('onKeyPress', key)

    if not ui.focusedTextInputID then
        if key == 'r' then
            -- we will just recolor everything.

            -- logger:inspect(humanoidInstance.dna.creation)
            local parts = humanoidInstance.dna.creation.torsoSegments
            for i = 1, parts do
                local bgHex = '000000ff'
                local fgHex = randomHexColor()
                local pHex = randomHexColor()
                CharacterManager.updateSkinOfPart(humanoidInstance, 'torso' .. i,
                    { bgHex = bgHex, fgHex = fgHex, pHex = pHex })
                CharacterManager.updateSkinOfPart(humanoidInstance, 'torso' .. i,
                    { bgHex = bgHex, fgHex = fgHex, pHex = pHex }, 'patch1')
                CharacterManager.updateSkinOfPart(humanoidInstance, 'torso' .. i,
                    { bgHex = bgHex, fgHex = fgHex, pHex = pHex }, 'patch2')

                -- local urls = { 'shapeA3', 'shapeA2', 'shapeA1', 'shapeA4', 'shapes1', 'shapes2', 'shapes3', 'shapes4',
                --     'shapes5', 'shapes6', 'shapes7', 'shapes8', 'shapes9', 'shapes10', 'shapes11', 'shapes12', 'shapes13' }
                -- local urlIndex = math.ceil(math.random() * #urls)
                -- local url = urls[urlIndex]
                -- --print(url)
                -- local s = .5 + love.math.random() * 2
                -- local sign = math.random() < .5 and -1 or 1
                -- logger:info({ shape8URL = url, sy = love.math.random() * 2, sx = love.math.random() * 12 })
                -- CharacterManager.updatePart('torso' .. i,
                --     { shape8URL = url .. '.png', sy = s * sign, sx = s },
                --     humanoidInstance)
                -- CharacterManager.updateShape8(humanoidInstance, 'torso1', url)
                -- print(url)
                -- CharacterManager.updateTextureGroupValue(humanoidInstance, 'torso1Skin', 'bgURL', url .. '.png')
                -- CharacterManager.updateTextureGroupValue(humanoidInstance, 'torso1Skin', 'fgURL', url .. '-mask.png')
                -- CharacterManager.updateTextureGroupValueInRoot(humanoidInstance, 'torso1Hair', 'followShape8',
                --     url .. '.png')
            end
            CharacterManager.addTexturesFromInstance2(humanoidInstance)
            -- CharacterManager.updatePart('torso2', { sy = love.math.random() * 2 }, humanoidInstance)
            -- CharacterManager.updatePart('torso3', { sy = love.math.random() * 2 }, humanoidInstance)
            -- CharacterManager.updatePart('torso4', { sy = love.math.random() * 2, sx = love.math.random() * 12 },
            --     humanoidInstance)
            --  CharacterManager.updatePart('head', { sy = love.math.random() * 10 }, humanoidInstance)
            --CharacterManager.updatePart('luleg', { h = 20 + love.math.random() * 400 }, humanoidInstance)
        end


        if key == 'n' then
            --logger:inspect(humanoidInstance.dna.creation)
            --local oldCreation = humanoidInstance.dna.creation
            --logger:inspect(humanoidInstance.dna.creation)

            --  CharacterManager.rebuildFromCreation(humanoidInstance,
            --      { neckSegments = math.ceil(1 + love.math.random() * 5) })
            CharacterManager.rebuildFromCreation(humanoidInstance, {})

            --            CharacterManager.refreshTextures(humanoidInstance)
            --print("AFTER", humanoidInstance.dna.parts['torso1'].shape8URL)
            CharacterManager.addTexturesFromInstance2(humanoidInstance)
            -- local parts = humanoidInstance.dna.creation.neckSegments
            -- if (not humanoidInstance.dna.creation.isPotatoHead) then
            --     for i = 1, parts do
            --         CharacterManager.updatePart('neck' .. i,
            --             { h = 100 },
            --             humanoidInstance)
            --     end
            -- end
            -- CharacterManager.addTextureFixturesFromInstance(humanoidInstance)
        end
        if key == 'x' then
            local bgColor = '000000ff'
            local fgColor = randomHexColor()
            local pColor = randomHexColor()
            local urls = { 'shapeA3', 'shapeA2', 'shapeA1', 'shapeA4', 'shapes1', 'shapes2', 'shapes3', 'shapes4',
                'shapes5', 'shapes6', 'shapes7', 'shapes8', 'shapes9', 'shapes10', 'shapes11', 'shapes12', 'shapes13' }
            local urlIndex = math.ceil(math.random() * #urls)
            local url = urls[urlIndex]
            local creation = humanoidInstance.dna.creation
            --print(inspect(creation))
            local count = creation.torsoSegments
            local s = 1 + math.random() * 1
            for i = 1, count do
                CharacterManager.updatePart('torso' .. i,
                    { shape8URL = url .. '.png', sy = s, sx = s },
                    humanoidInstance)
                --CharacterManager.updateShape8(humanoidInstance, 'torso' .. i, url)
            end

            CharacterManager.rebuildFromCreation(humanoidInstance,
                { torsoSegments = count, isPotatoHead = not creation.isPotatoHead })



            -- for i = 1, count do
            --     local partName = 'torso' .. i
            --     local group = partName .. 'Skin'
            --     local hair = partName .. 'Hair'

            --     CharacterManager.updateTextureGroupValue(humanoidInstance, group, 'bgURL', url .. '.png')
            --     CharacterManager.updateTextureGroupValue(humanoidInstance, group, 'fgURL', url .. '-mask.png')
            --     CharacterManager.updateTextureGroupValue(humanoidInstance, group, 'pHex', pColor)
            --     CharacterManager.updateTextureGroupValue(humanoidInstance, group, 'fgHex', fgColor)
            --     CharacterManager.updateTextureGroupValue(humanoidInstance, group, 'bgHex', bgColor)


            --     CharacterManager.updateTextureGroupValueInRoot(humanoidInstance, hair, 'followShape8', url .. '.png')
            -- end


            -- -- print('x')
            -- -- print("BEFORE", humanoidInstance.dna.parts['torso1'].shape8URL)
            -- CharacterManager.updatePart('torso1', { shape8URL = url .. '.png' }, humanoidInstance)

            -- CharacterManager.rebuildFromCreation(humanoidInstance, {})


            -- --   CharacterManager.refreshTextures(humanoidInstance)
            -- CharacterManager.updateTextureGroupValue(humanoidInstance, 'torso1Skin', 'bgURL', url .. '.png')
            -- CharacterManager.updateTextureGroupValue(humanoidInstance, 'torso1Skin', 'fgURL', url .. '-mask.png')
            -- CharacterManager.updateTextureGroupValueInRoot(humanoidInstance, 'torso1Hair', 'followShape8',
            --     url .. '.png')

            -- --print("AFTER", humanoidInstance.dna.parts['torso1'].shape8URL)
            CharacterManager.addTexturesFromInstance2(humanoidInstance)
        end

        if key == 'l' then
            local lowerleglength = 20 + love.math.random() * 1400
            CharacterManager.updatePart('luleg', { h = lowerleglength }, humanoidInstance)
            CharacterManager.updatePart('ruleg', { h = lowerleglength }, humanoidInstance)
            CharacterManager.updatePart('llleg', { h = lowerleglength }, humanoidInstance)
            CharacterManager.updatePart('rlleg', { h = lowerleglength }, humanoidInstance)

            local lowerarmlength = 120 + love.math.random() * 1400
            CharacterManager.updatePart('luarm', { h = lowerarmlength }, humanoidInstance)
            CharacterManager.updatePart('ruarm', { h = lowerarmlength }, humanoidInstance)
            CharacterManager.updatePart('llarm', { h = lowerarmlength }, humanoidInstance)
            CharacterManager.updatePart('rlarm', { h = lowerarmlength }, humanoidInstance)


            CharacterManager.addTexturesFromInstance2(humanoidInstance)
        end
        if key == 'p' then
            local bgColor = '000000ff'
            local fgColor = randomHexColor()
            local pColor = randomHexColor()

            local oldCreation = humanoidInstance.dna.creation
            local segments = 1 + math.ceil(love.math.random() * 5)

            local url = humanoidInstance.dna.parts['torso1'].shape8URL
            local sx = humanoidInstance.dna.parts['torso1'].dims.sx
            local sy = humanoidInstance.dna.parts['torso1'].dims.sy


            -- for i = 1, segments do
            --     CharacterManager.updatePart('torso' .. i,
            --         { shape8URL = url .. '.png' },
            --         humanoidInstance)
            -- end

            --  print(url)
            -- logger:info(oldCreation.torsoSegments, segments)
            logger:info(segments)
            CharacterManager.rebuildFromCreation(humanoidInstance,
                { torsoSegments = segments })

            for i = 1, segments do
                CharacterManager.updatePart('torso' .. i,
                    { shape8URL = url },
                    humanoidInstance)
                --CharacterManager.updateShape8(humanoidInstance, 'torso' .. i, url:gsub('.png', ''))
            end
            logger:info(segments)
            -- for i = 1, segments do
            --     CharacterManager.updatePart('torso' .. i,
            --         { shape8URL = url, sy = sx, sx = sy },
            --         humanoidInstance)
            --     -- CharacterManager.updateShape8(humanoidInstance, 'torso' .. i, url:gsub('.png', ''))

            --     local partName = 'torso' .. i
            --     local group = partName .. 'Skin'
            --     local hair = partName .. 'Hair'

            --     CharacterManager.updateTextureGroupValue(humanoidInstance, group, 'bgURL', url)
            --     CharacterManager.updateTextureGroupValue(humanoidInstance, group, 'fgURL', url:gsub('.png', '-mask.png'))
            --     CharacterManager.updateTextureGroupValue(humanoidInstance, group, 'pHex', pColor)

            --     CharacterManager.updateTextureGroupValueInRoot(humanoidInstance, hair, 'followShape8', url)
            -- end



            -- CharacterManager.updateTextureGroupValue(humanoidInstance, 'leftLegSkin', 'bgHex', bgColor)
            -- CharacterManager.updateTextureGroupValue(humanoidInstance, 'leftLegSkin', 'fgHex', fgColor)
            -- CharacterManager.updateTextureGroupValue(humanoidInstance, 'leftLegSkin', 'pHex', pColor)

            -- CharacterManager.updateTextureGroupValue(humanoidInstance, 'rightLegSkin', 'bgHex', bgColor)
            -- CharacterManager.updateTextureGroupValue(humanoidInstance, 'rightLegSkin', 'fgHex', fgColor)
            -- CharacterManager.updateTextureGroupValue(humanoidInstance, 'rightLegSkin', 'pHex', pColor)


            -- logger:info(fgColor, pColor)
            --  if url then CharacterManager.updateShape8(humanoidInstance, 'torso1', url) end
            CharacterManager.addTexturesFromInstance2(humanoidInstance)
        end
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

```

src//behaviors.lua
```lua
local lib = {}


lib.allBehaviors = {
    { name = 'KEEP_ANGLE', description = 'keep a body at a certain angle, still not completely settled on the other variables. Kp*I etc.' },
    { name = 'LIMB_HUB',   description = 'a polygon that has things attached, the location where is defined in here, by its edge number and a lerp between vertex -1 and vertex.' }
}


return lib

```

src//box2d-draw-textured.lua
```lua
--[[
TODO Recreating meshes every frame in drawSquishableHairOver and createTexturedTriangleStrip (within drawTexturedWorld) is definitely inefficient. We should absolutely cache these.
]] --

local lib = {}
local state = require 'src.state'
local mathutils = require 'src.math-utils'
local polyline = require 'src.polyline'
local shapes = require 'src.shapes'

local tex1 = love.graphics.newImage('textures/pat/type2t.png')
tex1:setWrap('mirroredrepeat', 'mirroredrepeat')

local line = love.graphics.newImage('textures/shapes6.png')
local maskTex = love.graphics.newImage('textures/shapes6-mask.png')
local imageCache = {}
local shrinkFactor = 1


-- local shaderCode = love.filesystem.read("shaders/offset-halftone.glsl")
-- local halttoneShader = love.graphics.newShader(shaderCode)


-- --local shaderCode2   = love.filesystem.read("shaders/chromasep.glsl")
-- local chromaShader  = love.graphics.newShader [[
-- extern vec2 direction;
-- vec4 effect(vec4 color, Image texture, vec2 tc, vec2 _)
-- {
--   return color * vec4(
--     Texel(texture, tc - direction).r,
--     Texel(texture, tc).g,
--     Texel(texture, tc + direction).b,
--     1.0);
-- }]]

local moonshine     = require 'moonshine'
local effect        = moonshine(moonshine.effects.shadow)

lib.setShrinkFactor = function(value)
    shrinkFactor = value
end

lib.getShrinkFactor = function()
    return shrinkFactor
end

function getLoveImage(path, settings)
    if not imageCache[path] then
        local info = love.filesystem.getInfo(path)
        if not info or info.type ~= 'file' then
            --print("Warning: File not found - " .. path)
            return nil, nil, nil
        end
        local img = love.graphics.newImage(path)
        if (settings) then
            if settings.wrapX and settings.wrapY then
                img:setWrap(settings.wrapX, settings.wrapY)
            end
        end
        if img then
            local imgw, imgh = img:getDimensions()
            imageCache[path] = { img = img, imgw = imgw, imgh = imgh }
        end
    end

    if imageCache[path] then
        return imageCache[path].img, imageCache[path].imgw, imageCache[path].imgh
    else
        return nil, nil, nil
    end
end

local settings = { wrapX = 'mirroredrepeat', wrapY = 'mirroredrepeat' }
getLoveImage('textures/pat/type0.png', settings)
getLoveImage('textures/pat/type1.png', settings)
getLoveImage('textures/pat/type2.png', settings)
getLoveImage('textures/pat/type3.png', settings)
getLoveImage('textures/pat/type4.png', settings)
getLoveImage('textures/pat/type5.png', settings)
getLoveImage('textures/pat/type6.png', settings)
getLoveImage('textures/pat/type7.png', settings)
getLoveImage('textures/pat/type8.png', settings)



local base = {
    '020202', '4f3166', '69445D', '613D41', 'efebd8',
    '6f323a', '872f44', '8d184c', 'be193b', 'd2453a',
    'd6642f', 'd98524', 'dca941', 'e6c800', 'f8df00',
    'ddc340', 'dbd054', 'ddc490', 'ded29c', 'dad3bf',
    '9c9d9f', '938541', '808b1c', '8A934E', '86a542',
    '57843d', '45783c', '2a5b3e', '1b4141', '1e294b',
    '0d5f7f', '065966', '1b9079', '3ca37d', '49abac',
    '5cafc9', '159cb3', '1d80af', '2974a5', '1469a3',
    '045b9f', '9377b2', '686094', '5f4769', '815562',
    '6e5358', '493e3f', '4a443c', '7c3f37', 'a93d34',
    'CB433A', 'a95c42', 'c37c61', 'd19150', 'de9832',
    'bd7a3e', '865d3e', '706140', '7e6f53', '948465',
    '252f38', '42505f', '465059', '57595a', '6e7c8c',
    '75899c', 'aabdce', '807b7b', '857b7e', '8d7e8a',
    'b38e91', 'a2958d', 'd2a88d', 'ceb18c', 'cf9267',
    'f0644d', 'ff7376', 'd76656', 'b16890', '020202',
    '333233', '814800', 'efebd8', '1a5f8f', '66a5bc',
    '87727b', 'a23d7e', 'fa8a00', 'fef1d0', 'ffa8a2',
    '6e614c', '418090', 'b5d9a4', 'c0b99e', '4D391F',
    '4B6868', '9F7344', '9D7630', 'D3C281', '8F4839',
    'EEC488', 'C77D52', 'C2997A', '9C5F43', '9C8D81',
    '965D64', '798091', '4C5575', '6E4431', '626964',
}
lib.palette = base






function createTexturedTriangleStrip(image, optionalWidthMultiplier)
    -- this assumes an strip that is oriented vertically
    local w, h = image:getDimensions()
    w = w * (optionalWidthMultiplier or 1)

    local vertices = {}
    local segments = 11
    local hPart = h / (segments - 1)
    local hv = 1 / (segments - 1)
    local runningHV = 0
    local runningHP = 0
    local index = 0

    for i = 1, segments do
        vertices[index + 1] = { -w / 2, runningHP, 0, runningHV }
        vertices[index + 2] = { w / 2, runningHP, 1, runningHV }
        runningHV = runningHV + hv
        runningHP = runningHP + hPart
        index = index + 2
    end

    local mesh = love.graphics.newMesh(vertices, "strip")
    mesh:setTexture(image)
    return mesh
end

function lib.hexToColor(hex)
    if type(hex) ~= "string" then
        -- print("Warning: hexToColor expected a string but got " .. type(hex))
        return 1, 1, 1, 1
    end

    -- Remove any leading hash symbol.
    hex = hex:gsub("#", "")

    -- Expand shorthand forms:
    if #hex == 3 then
        -- Example: "f00" becomes "ff0000"
        hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
        -- Append full opacity.
        hex = hex .. "FF"
    elseif #hex == 4 then
        -- Example: "f00a" becomes "ff0000aa"
        hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2) .. hex:sub(4, 4):rep(2)
    elseif #hex == 6 then
        -- Append alpha if missing.
        hex = hex .. "FF"
    elseif #hex ~= 8 then
        -- print("Warning: invalid hex string length (" .. #hex .. ") for value: " .. hex)
        return 1, 1, 1, 1
    end

    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    local a = tonumber(hex:sub(7, 8), 16)

    -- If any conversion failed, return white.
    if not (r and g and b and a) then
        -- print("Warning: invalid hex color value: " .. hex)
        return 1, 1, 1, 1
    end

    return r / 255, g / 255, b / 255, a / 255
end

-- only thing thats no longer possible == using an alpha for the background color
local maskShader = love.graphics.newShader([[
	uniform Image fill;
    uniform vec4 backgroundColor;
    uniform mat2 uvTransform;
    uniform vec2 uvTranslation;

	vec4 effect(vec4 color, Image mask, vec2 uv, vec2 fc) {
        vec2 transformedUV = uv * uvTransform;
        transformedUV.x += uvTranslation.x;
        transformedUV.y += uvTranslation.y;
        vec3 patternMix = mix(backgroundColor.rgb, color.rgb, Texel(fill, transformedUV).a * color.a);
        return vec4(patternMix, Texel(mask, uv).r * backgroundColor.a  );
	}
]])



local function getDrawParams(flipx, flipy, imgw, imgh)
    local sx = flipx
    local sy = flipy

    local ox = flipx == -1 and imgw or 0
    local oy = flipy == -1 and imgh or 0

    return sx, sy, ox, oy
end

local function buildKey(lineart, mask, color1, alpha1, texture2, color2, alpha2, texRot, texScaleX, texScaleY,
                        texOffX, texOffY,
                        lineColor, lineAlpha,
                        flipx, flipy, patches)
    local function toStr(v)
        if type(v) == "number" then
            return string.format("%.3f", v)
        elseif type(v) == "table" then
            return table.concat(v, ",")
        elseif type(v) == "boolean" then
            return v and "1" or "0"
        elseif type(v) == "userdata" and v.typeOf and v:typeOf("Image") then
            return tostring(v):match("Image: (.+)") or "image"
        else
            return tostring(v)
        end
    end

    local keyParts = {
        toStr(lineart),
        toStr(mask),
        toStr(color1), alpha1,
        toStr(texture2), toStr(color2), alpha2,
        texRot, texScaleX, texScaleY,
        texOffX, texOffY,
        toStr(lineColor), lineAlpha,
        flipx, flipy
    }

    if patches then
        for _, p in ipairs(patches) do
            table.insert(keyParts, toStr(p.img))
            table.insert(keyParts, p.tx or 0)
            table.insert(keyParts, p.ty or 0)
            table.insert(keyParts, p.r or 0)
            table.insert(keyParts, p.sx or 1)
            table.insert(keyParts, p.sy or 1)
            table.insert(keyParts, p.tint or "ffffff")
        end
    end

    return table.concat(keyParts, "|")
end

local testCache = {}

lib.makeTexturedCanvas = function(lineart, mask, color1, alpha1, texture2, color2, alpha2, texRot, texScaleX, texScaleY,
                                  texOffX, texOffY,
                                  lineColor, lineAlpha,
                                  flipx, flipy, patches)
    local key = buildKey(lineart, mask, color1, alpha1, texture2, color2, alpha2, texRot, texScaleX, texScaleY,
        texOffX, texOffY,
        lineColor, lineAlpha,
        flipx, flipy, patches)

    if testCache[key] == true then
        --    logger:info('double?', key)
    end
    testCache[key] = true
    --  logger:info(key)

    if true then
        local lineartColor = lineColor or { 0, 0, 0, 1 }
        local lw, lh = lineart:getDimensions()
        --  local dpiScale = 1 --love.graphics.getDPIScale()
        local canvas = love.graphics.newCanvas(lw, lh, { dpiscale = 1 })

        love.graphics.setCanvas({ canvas, stencil = false }) --<<<

        --

        -- the reason for outline ghost stuff is this color
        -- its not a simple fix, you could make it so we use color A if some layer is lpha 0 etc
        love.graphics.clear(lineartColor[1], lineartColor[2], lineartColor[3], 0) ---<<<<

        if (true) then
            love.graphics.setShader(maskShader)
            local transform = love.math.newTransform()


            transform:rotate(texRot)
            transform:scale(texScaleX, texScaleY)

            local m1, m2, _, _, m5, m6 = transform:getMatrix()
            local dx = texOffX --love.math.random() * .001
            local dy = texOffY
            if texture2 then
                maskShader:send('fill', texture2)
            end

            maskShader:send('backgroundColor', { color1[1], color1[2], color1[3], alpha1 / 5 })
            maskShader:send('uvTransform', { { m1, m2 }, { m5, m6 } })
            maskShader:send('uvTranslation', { dx, dy })

            if mask then
                local sx, sy, ox, oy = getDrawParams(flipx, flipy, lw, lh)
                love.graphics.setColor(color2[1], color2[2], color2[3], alpha2 / 5)
                love.graphics.draw(mask, 0, 0, 0, sx, sy, ox, oy)
            end
            love.graphics.setShader()
        end

        if true then
            if patches then
                for i = 1, #patches do
                    local patch = patches[i]
                    if patch and patch.img then
                        love.graphics.setColorMask(true, true, true, false)
                        local r, g, b, a = lib.hexToColor(patch.tint)
                        love.graphics.setColor(r, g, b, a)
                        local image = patch.img
                        local imgw, imgh = image:getDimensions()
                        local xOffset = (patch.tx or 0) * (imgw) * shrinkFactor
                        local yOffset = (patch.ty or 0) * (imgh) * shrinkFactor
                        love.graphics.draw(image, (lw) / 2 + xOffset, (lh) / 2 + yOffset,
                            (patch.r or 0) * ((math.pi * 2) / 16),
                            (patch.sx or 1) * shrinkFactor,
                            (patch.sy or 1) * shrinkFactor,
                            imgw / 2, imgh / 2)
                        love.graphics.setColorMask(true, true, true, true)
                    end
                end
            end
        end



        -- I want to know If we do this or not..
        -- if (true and renderPatch) then
        --     love.graphics.setColorMask(true, true, true, false)
        --     -- for i = 1, #renderPatch do
        --     --     local p = renderPatch[i]

        --     --     love.graphics.setColor(1, 1, 1, 1)
        --     --     local image = love.graphics.newImage(p.)
        --     --     local imgw, imgh = image:getDimensions();
        --     --     local xOffset = p.tx * (imgw / 6) * shrinkFactor
        --     --     local yOffset = p.ty * (imgh / 6) * shrinkFactor
        --     --     love.graphics.draw(image, (lw) / 2 + xOffset, (lh) / 2 + yOffset, p.r * ((math.pi * 2) / 16),
        --     --         p.sx * shrinkFactor,
        --     --         p.sy * shrinkFactor,
        --     --         imgw / 2, imgh / 2)
        --     --     --print(lw, lh)
        --     --     if true then
        --     --         local img = love.graphics.newImage('textures/eye4.png')
        --     --         --local img = love.graphics.newImage('assets/test1.png')
        --     --         --love.graphics.setBlendMode('subtract')

        --     --         for i = 1, 13 do
        --     --             love.graphics.setColor(love.math.random(), love.math.random(), love.math.random(), 0.4)
        --     --             local s = 3 + love.math.random() * 3
        --     --             love.graphics.draw(img, lw * love.math.random(), lh * love.math.random(),
        --     --                 love.math.random() * math.pi * 2,
        --     --                 1 / s, 1 / s)
        --     --         end

        --     --         --love.graphics.setBlendMode("alpha")
        --     --     end
        --     -- end
        --     love.graphics.setColorMask(true, true, true, true)
        -- end


        love.graphics.setColor(lineartColor[1], lineartColor[2], lineartColor[3], lineAlpha / 5)
        local sx, sy, ox, oy = getDrawParams(flipx, flipy, lw, lh)
        --  print(flipx, flipy, lw, lh, sx, sy, ox, oy)
        --love.graphics.setColor(0, 0, 0)
        love.graphics.draw(lineart, 0, 0, 0, sx, sy, ox, oy)

        love.graphics.setColor(0, 0, 0) --- huh?!
        love.graphics.setCanvas()       --- <<<<<

        local otherCanvas = love.graphics.newCanvas(lw / shrinkFactor, lh / shrinkFactor,
            { dpiscale = 1 })
        love.graphics.setCanvas({ otherCanvas, stencil = false })                 --<<<
        love.graphics.clear(lineartColor[1], lineartColor[2], lineartColor[3], 0) ---<<<<
        love.graphics.setColor(1, 1, 1)
        --- huh?!
        love.graphics.draw(canvas, 0, 0, 0, 1 / shrinkFactor, 1 / shrinkFactor)
        -- love.graphics.rectangle('fill', 0, 0, 1000, 1000)
        --print(0, 0, 0, 1 / shrinkFactor, 1 / shrinkFactor)
        love.graphics.setCanvas()       --- <<<<<
        local imageData = otherCanvas:newImageData()
        love.graphics.setColor(0, 0, 0) --- huh?!
        --local imageData = canvas:newImageData()



        canvas:release()
        otherCanvas:release()
        -- print(imageData)
        return imageData
    end
    -- return lineart:getData()
    -- return nil -- love.image.newImageData(mask)
end
function makePatch(name, ud)
    local result = nil
    if ud.extra[name] and ud.extra[name].bgURL then
        local outlineImage = getLoveImage('textures/' .. ud.extra[name].bgURL)
        local olr, olg, olb, ola = lib.hexToColor(ud.extra[name].bgHex)
        local maskImage = getLoveImage('textures/' .. ud.extra[name].fgURL)
        local mr, mg, mb, ma = lib.hexToColor(ud.extra[name].fgHex)
        local patternImage = getLoveImage('textures/pat/' .. ud.extra[name].pURL)
        local pr, pg, pb, pa = lib.hexToColor(ud.extra[name].pHex)
        if outlineImage then
            local imgData = lib.makeTexturedCanvas(
                outlineImage,            -- line art
                maskImage,               -- mask
                { mr, mg, mb },          -- color1
                ma * 5,                  -- alpha1
                patternImage or tex1,    -- texture2 (fill texture)
                { pr, pg, pb },          -- color2
                pa * 5,                  -- alpha2
                ud.extra[name].pr or 0,  -- texRot
                ud.extra[name].psx or 1, -- texScale
                ud.extra[name].psy or 1, -- texScale
                ud.extra[name].ptx or 0,
                ud.extra[name].pty or 0,
                { olr, olg, olb },      -- lineColor
                ola * 5,                -- lineAlpha
                ud.extra[name].fx or 1, -- flipx (normal)
                ud.extra[name].fy or 1  -- flipy (normal)
            )
            result = {
                img = love.graphics.newImage(imgData),
                --img = getLoveImage('textures/' .. ud.extra.patch1URL),
                tint = ud.extra[name].tint or 'ffffff',
                tx = ud.extra[name].tx,
                ty = ud.extra[name].ty,
                sx = ud.extra[name].sx,
                sy = ud.extra[name].sy,
                r = ud.extra[name].r
            }
        end
        return result
    end
    return result
end

function lib.makeCombinedImages()
    local bodies = state.physicsWorld:getBodies()
    for _, body in ipairs(bodies) do
        local fixtures = body:getFixtures()
        for i = 1, #fixtures do
            local ud = fixtures[i]:getUserData()
            if ud and ud.extra and ud.extra.OMP and ud.extra.dirty then
                local patch1 = makePatch('patch1', ud)
                local patch2 = makePatch('patch2', ud)
                local patch3 = makePatch('patch3', ud)

                local outlineImage = getLoveImage('textures/' .. ud.extra.main.bgURL)
                local olr, olg, olb, ola = lib.hexToColor(ud.extra.main.bgHex)
                local maskImage = getLoveImage('textures/' .. ud.extra.main.fgURL)
                local mr, mg, mb, ma = lib.hexToColor(ud.extra.main.fgHex)
                local patternImage = getLoveImage('textures/pat/' .. ud.extra.main.pURL)
                local pr, pg, pb, pa = lib.hexToColor(ud.extra.main.pHex)

                if outlineImage or line then
                    local imgData = lib.makeTexturedCanvas(
                        outlineImage or line,   -- line art
                        maskImage or maskTex,   -- mask
                        { mr, mg, mb },         -- color1
                        ma * 5,                 -- alpha1
                        patternImage or tex1,   -- texture2 (fill texture)
                        { pr, pg, pb },         -- color2
                        pa * 5,                 -- alpha2
                        ud.extra.main.pr or 0,  -- texRot
                        ud.extra.main.psx or 1, -- texScale
                        ud.extra.main.psy or 1, -- texScale
                        ud.extra.main.ptx or 0,
                        ud.extra.main.pty or 0,
                        { olr, olg, olb },         -- lineColor
                        ola * 5,                   -- lineAlpha
                        ud.extra.main.fx or 1,     -- flipx (normal)
                        ud.extra.main.fy or 1,     -- flipy (normal)
                        { patch1, patch2, patch3 } -- renderPatch (set to truthy to enable extra patch rendering)
                    )
                    image = love.graphics.newImage(imgData)
                    ud.extra.ompImage = image
                end
                fixtures[i]:setUserData(ud)

                ud.extra.dirty = false
            end
        end
    end
end

local function makeSquishableUVsFromPoints(v)
    local verts = {}
    if #v == 8 then -- has 4 (4*(x,y)) vertices
        verts[1] = { v[1], v[2], 0, 0 }
        verts[2] = { v[3], v[4], 1, 0 }
        verts[3] = { v[5], v[6], 1, 1 }
        verts[4] = { v[7], v[8], 0, 1 }
        verts[5] = { v[1], v[2], 0, 0 } -- this is an extra one to make it go round
    end

    if #v == 16 then -- has 8 (8*(x,y)) vertices
        verts[1] = { v[1], v[2], 0, 0 }
        verts[2] = { v[3], v[4], .5, 0 }
        verts[3] = { v[5], v[6], 1, 0 }
        verts[4] = { v[7], v[8], 1, .5 }
        verts[5] = { v[9], v[10], 1, 1 }
        verts[6] = { v[11], v[12], .5, 1 }
        verts[7] = { v[13], v[14], 0, 1 }
        verts[8] = { v[15], v[16], 0, .5 }
        verts[9] = { v[1], v[2], 0, 0 } -- this is an extra one to make it go round
    end

    return verts
end


local function renderHair(box2dGuy, guy, faceData, creation, multipliers, x, y, r, sx, sy)
    local canvasCache = guy.canvasCache
    local dpi = 1 --love.graphics.getDPIScale()
    local shrink = canvas.getShrinkFactor()
    if true then
        if true or box2dGuy.hairNeedsRedo then
            local img = canvasCache.hairCanvas
            local w, h = img:getDimensions()
            local f = faceData.metaPoints
            -- todo parameter hair (beard, only top hair, sidehair)
            --local hairLine = { f[6], f[7], f[8], f[1], f[2], f[3], f[4] }
            local hairLine = { f[7], f[8], f[1], f[2], f[3] }
            -- local hairLine = { f[8], f[1], f[2] }
            -- print(inspect(hairLine))
            --local hairLine = { f[3], f[4], f[5], f[6], f[7] }
            local points = hairLine
            local hairTension = .02
            local spacing = 10 * multipliers.hair.sMultiplier
            local coords

            coords = border.unloosenVanillaline(points, hairTension, spacing)

            local length = getLengthOfPath(hairLine)
            local factor = (length / h)
            local hairWidthMultiplier = 1 * multipliers.hair.wMultiplier
            local width = (w * factor) * hairWidthMultiplier / 1 --30 --160 * 10
            local verts, indices, draw_mode = polyline.render('miter', coords, width)

            local vertsWithUVs = {}

            for i = 1, #verts do
                local u = (i % 2 == 1) and 0 or 1
                local v = math.floor(((i - 1) / 2)) / (#verts / 2 - 1)
                vertsWithUVs[i] = { verts[i][1], verts[i][2], u, v }
            end

            local vertices = vertsWithUVs
            local m = love.graphics.newMesh(vertices, "strip")
            m:setTexture(img)
            love.graphics.draw(m, x, y, r - math.pi, sx * creation.head.flipx * (dpi / shrink), sy * (dpi / shrink))
        end
    end
end




local function drawSquishableHairOver(img, x, y, r, sx, sy, growFactor, vertices)
    local p = {}
    for i = 1, #vertices do
        p[i] = vertices[i] * growFactor
    end
    -- local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
    local uvs = makeSquishableUVsFromPoints(p)


    -- todo maybe parametrize this point so you can make the midle of the fan not be the exact middle of the polygon.
    local cx, cy, _, _ = mathutils.getCenterOfPoints(vertices)
    table.insert(uvs, 1, { cx, cy, .5, .5 }) -- I will just alwasy put a center vertex as the first one

    local _mesh = love.graphics.newMesh(uvs) --or love.graphics.newMesh(uvs, 'fan')
    local img = img
    _mesh:setTexture(img)

    love.graphics.draw(_mesh, x, y, r, 1, 1)
end




function texturedCurve(curve, image, mesh, dir, scaleW)
    if not dir then dir = 1 end
    if not scaleW then scaleW = 1 end
    local dl = curve:getDerivative()

    for i = 1, 1 do
        local w, h = image:getDimensions()
        local count = mesh:getVertexCount()

        for j = 1, count, 2 do
            local index                  = (j - 1) / (count - 2)
            local xl, yl                 = curve:evaluate(index)
            local dx, dy                 = dl:evaluate(index)
            local a                      = math.atan2(dy, dx) + math.pi / 2
            local a2                     = math.atan2(dy, dx) - math.pi / 2
            local line                   = (w * dir) * scaleW --- here we can make the texture wider!!, also flip it
            local x2                     = xl + line * math.cos(a)
            local y2                     = yl + line * math.sin(a)
            local x3                     = xl + line * math.cos(a2)
            local y3                     = yl + line * math.sin(a2)

            local x, y, u, v, r, g, b, a = mesh:getVertex(j)
            mesh:setVertex(j, { x2, y2, u, v })
            x, y, u, v, r, g, b, a = mesh:getVertex(j + 1)
            mesh:setVertex(j + 1, { x3, y3, u, v })
        end
    end
end

local function doubleControlPoints(points, duplications)
    local result = {}

    -- Sanity check: must be even number of values
    if #points % 2 ~= 0 then
        error("Input array must have even number of elements (x, y pairs)")
    end

    local numPoints = #points / 2

    for i = 1, numPoints do
        local x = points[(i - 1) * 2 + 1]
        local y = points[(i - 1) * 2 + 2]

        table.insert(result, x)
        table.insert(result, y)

        -- Double the point if it's a *middle* point (not first or last)
        if i > 1 and i < numPoints then
            for j = 1, duplications do
                table.insert(result, x)
                table.insert(result, y)
            end
        end
    end

    return result
end

function lib.drawTexturedWorld(world)
    local bodies = world:getBodies()
    local drawables = {}

    for _, body in ipairs(bodies) do
        -- local ud = body:getUserData()
        -- if (ud and ud.thing) then
        --     local composedZ = ((ud.thing.zGroupOffset or 0) * 1000) + ud.thing.zOffset
        --     table.insert(drawables, { z = composedZ, body = body, thing = ud.thing })
        -- end
        -- todo instead of having to check all the fixtures every frame we should mark a thing that has these type of specialfixtures.
        local fixtures = body:getFixtures()
        for i = 1, #fixtures do
            local ud = fixtures[i]:getUserData()

            if ud and ud.subtype == 'trace-vertices' then
                local composedZ = ((ud.extra.zGroupOffset or 0) * 1000) + (ud.extra.zOffset or 0)

                table.insert(drawables, {
                    type = 'trace-vertices',
                    z = composedZ,
                    extra = ud.extra,
                    thing = body:getUserData().thing
                })
            end

            if ud and ud.subtype == 'tile-repeat' then
                local composedZ = ((ud.extra.zGroupOffset or 0) * 1000) + (ud.extra.zOffset or 0)

                table.insert(drawables, {
                    type = 'tile-repeat',
                    z = composedZ,
                    extra = ud.extra,
                    thing = body:getUserData().thing
                })
            end

            if (ud and ud.extra and ud.extra.type == 'texfixture') or (ud and ud.subtype == 'texfixture') then
                local composedZ = ((ud.extra.zGroupOffset or 0) * 1000) + (ud.extra.zOffset or 0)
                table.insert(drawables,
                    {
                        type = 'texfixture',
                        z = composedZ,
                        texfixture = fixtures[i],
                        extra = ud.extra,
                        body = body,
                        thing = body:getUserData().thing
                    })
            end

            if ud and (ud.label == "connected-texture" or ud.subtype == 'connected-texture') and ud.extra.nodes then
                -- logger:inspect(ud)
                --logger:info('got some new kind of combined drawing todo!')
                local points = {}
                for j = 1, #ud.extra.nodes do
                    local it = ud.extra.nodes[j]
                    if it.type == 'anchor' then
                        local f = registry.getSFixtureByID(it.id)
                        local b = f:getBody()
                        local centerX, centerY = mathutils.getCenterOfPoints({ b:getWorldPoints(f:getShape():getPoints()) })
                        table.insert(points, centerX)
                        table.insert(points, centerY)
                    end
                    if it.type == 'joint' then
                        local j = registry.getJointByID(it.id)
                        if j and not j:isDestroyed() then
                            local x1, y1, _, _ = j:getAnchors()
                            table.insert(points, x1)
                            table.insert(points, y1)
                        end
                    end
                end

                if #points == 4 then
                    -- here we will just introduce a little midle thingie
                    -- -- becaue i cannot draw a curve of 2 points
                    function addMidpoint(points)
                        if #points ~= 4 then
                            error("Expected array of exactly 2 points (4 numbers)")
                        end

                        local x1, y1, x2, y2 = points[1], points[2], points[3], points[4]
                        local midX = (x1 + x2) / 2
                        local midY = (y1 + y2) / 2

                        return { x1, y1, midX, midY, x2, y2 }
                    end

                    points = addMidpoint(points)
                end

                if #points >= 6 then
                    -- todo here we might want to grow the curve... so it will stick a little bit from the sides
                    local function growLine(p1, p2, length)
                        local angle = math.atan2(p1[2] - p2[2], p1[1] - p2[1])
                        local new_x = p1[1] + length * math.cos(angle)
                        local new_y = p1[2] + length * math.sin(angle)
                        return new_x, new_y
                    end
                    -- todo parameter this
                    local growLength = 20
                    points[1], points[2] = growLine({ points[1], points[2] }, { points[3], points[4] }, growLength)
                    points[5], points[6] = growLine({ points[5], points[6] }, { points[3], points[4] }, growLength)


                    points = doubleControlPoints(points, 2)


                    local composedZ = ((ud.extra.zGroupOffset or 0) * 1000) + (ud.extra.zOffset or 0)
                    --print(inspect(ud.extra))
                    table.insert(drawables,
                        {
                            z = composedZ,
                            type = 'connected-texture',
                            curve = love.math.newBezierCurve(points),
                            --texfixture = fixtures[i],
                            extra = ud.extra,
                            --body = body,
                            -- thing = body:getUserData().thing
                        })
                end
            end
        end
    end
    --print(#drawables)
    table.sort(drawables, function(a, b)
        return a.z < b.z
    end)




    -- todo: these3 function look very much alike, we wnat to combine them all in otne,
    -- another issue here is that i dont really understand how to set the ox and oy correctly, (for the combined Image)
    -- and there is an issue with the center of the 'fan' mesh, it shouldnt always be 0,0 you can see this when you position the texfxture with the
    -- onscreen 'd' button quite a distnace out of the actual physics body center.
    --
    local function drawImageLayerSquish(url, hex, extra, texfixture)
        -- print('jo!')
        local img, imgw, imgh = getLoveImage('textures/' .. url)
        local vertices = extra.vertices or { texfixture:getShape():getPoints() }

        if (vertices and img) then
            local body = texfixture:getBody()
            local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
            local sx = ww / imgw
            local sy = hh / imgh
            local rx, ry = mathutils.rotatePoint(cx, cy, 0, 0, body:getAngle())
            local r, g, b, a = lib.hexToColor(hex)
            love.graphics.setColor(r, g, b, a)
            --  drawSquishableHairOver(img, body:getX() + rx, body:getY() + ry, body:getAngle(), sx, sy, 1, vertices)
            drawSquishableHairOver(img, body:getX(), body:getY(), body:getAngle(), sx, sy, 1, vertices)
        end
    end
    local function drawImageLayerVanilla(url, hex, extra, texfixture)
        local img, imgw, imgh = getLoveImage('textures/' .. url)
        local vertices = extra.vertices or { texfixture:getShape():getPoints() }

        if (vertices and img) then
            local body = texfixture:getBody()
            -- local body = texfixture:getBody()
            local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
            local sx = ww / imgw
            local sy = hh / imgh
            local rx, ry = mathutils.rotatePoint(cx, cy, 0, 0, body:getAngle())
            local r, g, b, a = lib.hexToColor(hex)
            love.graphics.setColor(r, g, b, a)

            love.graphics.draw(img, body:getX() + rx, body:getY() + ry,
                body:getAngle(), sx * 1, sy * 1,
                (imgw) / 2, (imgh) / 2)
            --drawSquishableHairOver(img, body:getX() + rx, body:getY() + ry, body:getAngle(), sx, sy, 1, vertices)
        end
    end
    local function drawCombinedImageVanilla(ompImage, extra, texfixture, thing)
        local vertices = extra.vertices or { texfixture:getShape():getPoints() }
        local img = ompImage
        local imgw, imgh = ompImage:getDimensions()

        if vertices and img then
            local body = texfixture:getBody()
            local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
            local sx = ww / imgw
            local sy = hh / imgh
            local rx, ry = mathutils.rotatePoint(cx, cy, 0, 0, body:getAngle())
            --local r, g, b, a = hexToColor(thing.textures.bgHex)

            -- this routine is alos good, but it doenst take in affect the squishyness. you cannot deform the rectangle
            -- love.graphics.setColor(1, 1, 1, 1)
            -- love.graphics.draw(img, body:getX() + rx, body:getY() + ry, body:getAngle(),
            --     sx * 1 * thing.mirrorX,
            --     sy * 1 * thing.mirrorY, (imgw) / 2, (imgh) / 2)



            -- this routine works as is, you just need to center more often, the 0,0 at the beginning is not always corretc though..
            local r, g, b, a = lib.hexToColor(extra.main.tint or 'ffffffff')
            love.graphics.setColor(r, g, b, a)
            --drawSquishableHairOver(img, body:getX() + rx, body:getY() + ry, body:getAngle(), sx, sy, 1, vertices)
            drawSquishableHairOver(img, body:getX(), body:getY(), body:getAngle(), sx, sy, 1, vertices)
        end
    end

    --love.graphics.setShader(chromaShader)
    --chromaShader:send("direction", { 10 * love.math.random(), 10 })
    --for _, body in ipairs(bodies) do

    --effect(function()
    for i = 1, #drawables do
        local body = drawables[i].body
        local thing = drawables[i].thing
        local texfixture = drawables[i].texfixture

        if drawables[i].type == 'texfixture' then
            --if texfixture then
            local extra = drawables[i].extra
            if not extra.OMP then -- this is the BG and FG routine
                if extra.main and extra.main.bgURL then
                    drawImageLayerSquish(extra.main.bgURL, extra.main.bgHex, extra, texfixture)
                    --drawImageLayerVanilla(extra.bgURL, extra.bgHex, extra,  texfixture:getBody() )
                end
                if extra.main and extra.main.fgURL then
                    drawImageLayerSquish(extra.main.fgURL, extra.main.fgHex, extra, texfixture)
                    --drawImageLayerVanilla(extra.bgURL, extra.bgHex, extra,  texfixture:getBody() )
                end
            end

            if extra.OMP then
                if (texfixture and extra.ompImage) then
                    drawCombinedImageVanilla(extra.ompImage, extra, texfixture, thing)
                end
                --end
            end
        end

        if drawables[i].type == 'connected-texture' then
            local curve = drawables[i].curve
            local extra = drawables[i].extra
            if not extra.OMP then -- this is the BG and FG routine
                if extra.main and extra.main.bgURL then
                    local img = getLoveImage('textures/' .. extra.main.bgURL)
                    if img then
                        local mesh = createTexturedTriangleStrip(img)
                        texturedCurve(curve, img, mesh, extra.main.dir or 1, extra.main.wmul or 1)
                        local olr, olg, olb, ola = lib.hexToColor(extra.main.bgHex)
                        love.graphics.setColor(olr, olg, olb, ola)
                        love.graphics.draw(mesh)
                    end
                end
                if extra.main and extra.main.fgURL then
                    local img = getLoveImage('textures/' .. extra.main.fgURL)
                    if img then
                        print(extra.main.wmul)
                        local mesh = createTexturedTriangleStrip(img)
                        texturedCurve(curve, img, mesh, extra.main.dir or 1, extra.main.wmul or 1)
                        local olr, olg, olb, ola = lib.hexToColor(extra.main.fgHex)
                        love.graphics.setColor(olr, olg, olb, ola)
                        love.graphics.draw(mesh)
                    end
                end
            end
            if extra.OMP then
                local img = extra.ompImage
                local mesh = createTexturedTriangleStrip(img)

                texturedCurve(curve, img, mesh, extra.main.dir or 1, extra.main.wmul or 1)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(mesh)
            end
        end

        if drawables[i].type == 'tile-repeat' then
            local vertices = drawables[i].thing.vertices
            local tris = shapes.makeTrianglesFromPolygon(vertices)
            local img = getLoveImage('textures/' .. drawables[i].extra.main.bgURL)
            if img then
                img:setWrap("repeat", "repeat")
                local texW, texH = img:getWidth(), img:getHeight()
                local centroidX, centroidY = mathutils.computeCentroid(vertices)
                local meshVertices = {}

                local twm = drawables[i].extra.tileWidthM
                local thm = drawables[i].extra.tileHeightM
                local tr = drawables[i].extra.tileRotation

                local bb = mathutils.getBoundingRect(vertices)
                -- bb.width and bb.height
                local uvParams = {
                    tileWidth = texW * twm,  --bb.width,    -- world units per tile horizontally
                    tileHeight = texH * thm, --bb.height,  -- world units per tile vertically
                    rotate = tr,             -- radians
                    offsetX = 0,             -- offset in world units
                    offsetY = 0,
                    scaleX = 1,              -- scale texture space (can be 1 / repeatX)
                    scaleY = 1,
                    anchor = "center",       -- or "top-left"
                    keepAspect = false       -- optional flag to preserve aspect ratio
                }

                local function transformUV(x, y, cx, cy, opts)
                    -- Translate point to origin (centroid or top-left)
                    local dx = x - cx + opts.offsetX
                    local dy = y - cy + opts.offsetY

                    -- Rotate
                    local cosA = math.cos(opts.rotate or 0)
                    local sinA = math.sin(opts.rotate or 0)
                    local rx = dx * cosA - dy * sinA
                    local ry = dx * sinA + dy * cosA

                    -- Scale to UV space
                    local tileW = opts.tileWidth or 64
                    local tileH = opts.tileHeight or 64
                    local u = rx / tileW
                    local v = ry / tileH

                    return u * (opts.scaleX or 1), v * (opts.scaleY or 1)
                end



                for j = 1, #tris do
                    local tri = tris[j]
                    for k = 0, 2 do
                        local x = tri[k * 2 + 1]
                        local y = tri[k * 2 + 2]
                        local u, v = transformUV(x, y, centroidX, centroidY, uvParams)
                        table.insert(meshVertices, {
                            x - centroidX, y - centroidY,
                            u, v,
                            255, 255, 255, 255
                        })
                    end
                end

                local vertexFormat = {
                    { "VertexPosition", "float", 2 },
                    { "VertexTexCoord", "float", 2 },
                    { "VertexColor",    "byte",  4 },
                }

                local mesh = love.graphics.newMesh(vertexFormat, meshVertices, "triangles")
                mesh:setTexture(img)

                --love.graphics.setColor(1, 1, 1, 1)

                local r, g, b, a = lib.hexToColor(drawables[i].extra.main.tint or 'ffffffff')
                love.graphics.setColor(r, g, b, a)

                local body = drawables[i].thing.body
                love.graphics.draw(mesh, body:getX(), body:getY(), body:getAngle())
            end
        end


        if drawables[i].type == 'trace-vertices' then
            local length = (#drawables[i].thing.vertices) / 2
            local startIndex = drawables[i].extra.startIndex
            local endIndex = drawables[i].extra.endIndex
            local indices = getIndices(length, startIndex, endIndex)
            local points = {}
            local pointsflat = {}
            -- logger:info(length)
            -- logger:inspect(indices)
            for j = 1, #indices do
                --local index = indices[j]
                local x = drawables[i].thing.vertices[indices[j] * 2 + 1]
                local y = drawables[i].thing.vertices[indices[j] * 2 + 2]
                table.insert(points, { x, y })
                table.insert(pointsflat, x)
                table.insert(pointsflat, y)
            end


            if #points >= 2 then
                --love.graphics.line(pointsflat)
                --if drawables[i].extra.main.bgURL
                local img = getLoveImage('textures/' .. (drawables[i].extra.main.bgURL))
                if not img then
                    img = getLoveImage('textures/' .. 'hair7.png')
                end

                local w, h = img:getDimensions()

                local hairTension = drawables[i].extra.tension or .02 -- love.math.random() --.02
                local spacing = drawables[i].extra.spacing or 5
                -- 5                                                    --* multipliers.hair.sMultiplier
                local coords = mathutils.unloosenVanillaline(points, hairTension, spacing)
                -- logger:info('check these below')
                -- logger:inspect(points)
                -- logger:inspect(coords)
                local length = mathutils.getLengthOfPath(points)

                --local factor = (length / h)
                --local hairWidthMultiplier = 1 --* multipliers.hair.wMultiplier
                local width = drawables[i].extra.width or 100 -- 100 --(w * factor) / 2
                --2                         -- 100             (w * factor) * hairWidthMultiplier / 1 --30 --160 * 10
                local verts, indices, draw_mode = polyline.render('miter', coords, width)

                local cx, cy = mathutils.getCenterOfPoints(drawables[i].thing.vertices)
                for i = 1, #verts do
                    verts[i][1] = verts[i][1] - cx
                    verts[i][2] = verts[i][2] - cy
                end

                local vertsWithUVs = {}

                for i = 1, #verts do
                    local u = (i % 2 == 1) and 0 or 1
                    local v = math.floor(((i - 1) / 2)) / (#verts / 2 - 1)
                    vertsWithUVs[i] = { verts[i][1], verts[i][2], u, v }
                end

                local vertices = vertsWithUVs


                local m = love.graphics.newMesh(vertices, "strip")
                m:setTexture(img)
                local body = drawables[i].thing.body
                --local cx, cy, ww, hh = mathutils.getCenterOfPoints(drawables[i].thing.vertices)
                love.graphics.draw(m, body:getX(), body:getY(), body:getAngle())
            end
            --logger:inspect(points)
            --logger:inspect()
        end
    end
    --  end)
    --love.graphics.setShader()
    --love.graphics.setDepthMode()
end

function resolveIndex(index, length)
    return (index < 0) and ((length + index) % length) or (index % length)
end

function getIndices(length, startIdx, endIdx, allowFullLoop)
    local start = resolveIndex(startIdx, length)
    local ending = resolveIndex(endIdx, length)
    local result = {}

    local i = start
    repeat
        table.insert(result, i)
        i = (i + 1) % length
    until i == ending and (not allowFullLoop or i == start)

    if i == ending then
        table.insert(result, i)
    end

    return result
end

return lib

```

src//box2d-draw.lua
```lua
--box2d-draw.lua

local lib = {}

local state = require 'src.state'
local pal = {
    ['orange']  = { 242 / 255, 133 / 255, 0 },         --#F28500  tangerine orange
    ['sun']     = { 253 / 255, 215 / 255, 4 / 255 },   --#FFD700  sunshine yellow
    ['rust']    = { 183 / 255, 64 / 255, 13 / 255 },   --#b7410e  rust otange
    ['avocado'] = { 106 / 255, 144 / 255, 32 / 255 },  --#568203  avocado graan
    ['gold']    = { 219 / 255, 145 / 255, 0 },         --#da9100  harvest gold
    ['lime']    = { 69 / 255, 205 / 255, 50 / 255 },   --#32CD32  lime green
    ['creamy']  = { 245 / 255, 245 / 255, 220 / 255 }, --#F5F5DC Creamy White:
    ['choco']   = { 123 / 255, 64 / 255, 0 },          --#7B3F00 Chocolate Brown:
    ['beige']   = { 244 / 255, 164 / 255, 97 / 255 },  --#F4A460 Sand Beige:
    ['red']     = { 217 / 255, 73 / 255, 56 / 255 },   --#D94A38 Adobe Red:
}

local function getBodyColor(body)
    if body:getType() == 'kinematic' then
        return pal.red
    end
    if body:getType() == 'dynamic' then
        return pal.lime
    end
    if body:getType() == 'static' then
        return pal.sun
    end
end

local function getEndpoint(x, y, angle, length)
    local endX = x + length * math.cos(angle)
    local endY = y + length * math.sin(angle)
    return endX, endY
end



function lib.drawWorld(world, drawOutline)
    if drawOutline == nil then drawOutline = true end
    local r, g, b, a = love.graphics.getColor()
    local alpha = .8 * state.world.debugAlpha
    love.graphics.setLineJoin("none")
    love.graphics.setColor(0, 0, 0, alpha)
    local bodies = world:getBodies()
    for _, body in ipairs(bodies) do
        local fixtures = body:getFixtures()

        for _, fixture in ipairs(fixtures) do
            --if fixture:getUserData() then
            --     print(inspect(fixture:getUserData()))
            --end
            if fixture:getShape():type() == 'PolygonShape' then
                local color = getBodyColor(body)
                love.graphics.setColor(color[1], color[2], color[3], alpha)
                if (fixture:getUserData()) then
                    if fixture:getUserData().bodyType == "connector" then
                        love.graphics.setColor(1, 0, 0, alpha)
                    end
                    if fixture:getUserData().type then
                        local color = pal.orange
                        love.graphics.setColor(color[1], color[2], color[3], alpha)
                    end
                end
                love.graphics.polygon("fill", body:getWorldPoints(fixture:getShape():getPoints()))
                local color = pal.creamy
                love.graphics.setColor(color[1], color[2], color[3], alpha)
                if (fixture:getUserData()) then
                    if fixture:getUserData().bodyType == "connector" then
                        love.graphics.setColor(1, 0, 0, alpha)
                    end
                    --  print(inspect(fixture:getUserData() ))
                end
                if drawOutline then love.graphics.polygon('line', body:getWorldPoints(fixture:getShape():getPoints())) end
            elseif fixture:getShape():type() == 'EdgeShape' or fixture:getShape():type() == 'ChainShape' then
                love.graphics.setColor(0, 1, 1, alpha)
                local points = { body:getWorldPoints(fixture:getShape():getPoints()) }
                for i = 1, #points, 2 do
                    if i < #points - 2 then love.graphics.line(points[i], points[i + 1], points[i + 2], points[i + 3]) end
                end
            elseif fixture:getShape():type() == 'CircleShape' then
                local body_x, body_y = body:getPosition()
                local shape_x, shape_y = fixture:getShape():getPoint()
                local r = fixture:getShape():getRadius()
                local color = getBodyColor(body)
                local segments = 180
                love.graphics.setColor(color[1], color[2], color[3], alpha)
                love.graphics.circle('fill', body_x + shape_x, body_y + shape_y, r, segments)

                local color = pal.creamy
                love.graphics.setColor(color[1], color[2], color[3], alpha)
                if drawOutline then love.graphics.circle('line', body_x + shape_x, body_y + shape_y, r, segments) end
            end
        end
    end
    love.graphics.setColor(255, 255, 255, alpha)
    -- Joint debug

    local joints = world:getJoints()
    for _, joint in ipairs(joints) do
        local x1, y1, x2, y2 = joint:getAnchors()

        if (x1 and y1 and x2 and y2) then
            local color = pal.creamy
            love.graphics.setColor(color[1], color[2], color[3], alpha)
            love.graphics.line(x1, y1, x2, y2)
        end
        local color = pal.orange
        love.graphics.setColor(color[1], color[2], color[3], alpha)

        love.graphics.setLineJoin("miter")
        if x1 and y1 then love.graphics.circle('line', x1, y1, 4) end
        if x2 and y2 then love.graphics.circle('line', x2, y2, 4) end
        love.graphics.setLineJoin("none")

        local jointType = joint:getType()
        if jointType == 'pulley' then
            local gx1, gy1, gx2, gy2 = joint:getGroundAnchors()
            love.graphics.setColor(1, 1, 0, alpha)
            love.graphics.line(x1, y1, gx1, gy1)
            love.graphics.line(x2, y2, gx2, gy2)
            love.graphics.line(gx1, gy1, gx2, gy2)
        end
        if jointType == 'prismatic' then
            local x, y = joint:getAnchors()
            local ax, ay = joint:getAxis()
            local length = 50
            love.graphics.setColor(1, 0.5, 0) -- Orange
            love.graphics.line(x, y, x + ax * length, y + ay * length)
            if joint:areLimitsEnabled() then
                local lower, upper = joint:getLimits()
                love.graphics.setColor(1, 1, 0) -- Yellow
                love.graphics.line(x + ax * lower, y + ay * lower, x + ax * lower + ax * 10, y + ay * lower + ay * 10)
                love.graphics.line(x + ax * upper, y + ay * upper, x + ax * upper + ax * 10, y + ay * upper + ay * 10)
            end
            love.graphics.setColor(1, 1, 1) -- Reset
        end
        if jointType == 'revolute' and joint:areLimitsEnabled() then
            local lower = joint:getLowerLimit()
            local upper = joint:getUpperLimit()
            local referenceAngle = joint:getReferenceAngle()

            local bodyA, bodyB = joint:getBodies()
            local angleA = bodyA:getAngle()
            local angleB = bodyB:getAngle()

            -- Use the joint's reference frame to compute world-space zero angle
            local zeroAngle = angleA + referenceAngle

            local startAngle = zeroAngle + lower
            local endAngle = zeroAngle + upper
            if endAngle < startAngle then
                endAngle = endAngle + 2 * math.pi
            end

            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.setLineJoin("miter")
            love.graphics.arc('line', x1, y1, 15, startAngle, endAngle)
            love.graphics.setLineJoin("none")

            -- draw current angle of bodyB relative to bodyA (via reference frame)
            local currentRelative = angleB - zeroAngle
            local dirAngle = zeroAngle + currentRelative
            local endX, endY = getEndpoint(x1, y1, dirAngle, 15)
            love.graphics.setColor(0.5, 0.5, 0.5, alpha)
            love.graphics.line(x1, y1, endX, endY)
        end
        if jointType == 'wheel' then
            -- Draw wheel joint axis
            local axisX, axisY = joint:getAxis()
            if x1 and y1 and axisX and axisY then
                local axisLength = 50                   -- Scale factor for visualizing the axis
                love.graphics.setColor(0, .5, 0, alpha) -- Green for axis
                love.graphics.line(x1, y1, x1 + axisX * axisLength, y1 + axisY * axisLength)
                love.graphics.setColor(1, 1, 1, alpha)
            end
        end
    end
    love.graphics.setLineJoin("miter")
    love.graphics.setColor(r, g, b, a)
    --   love.graphics.setLineWidth(1)
end

function lib.drawJointAnchors(joint)
    local color = pal.creamy
    love.graphics.setColor(color[1], color[2], color[3], 1)
    local x1, y1, x2, y2 = joint:getAnchors()
    love.graphics.circle('line', x1, y1, 10)
    love.graphics.line(x2 - 10, y2, x2 + 10, y2)
    love.graphics.line(x2, y2 - 10, x2, y2 + 10)
end

function lib.drawBodies(bodies)
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(6)
    love.graphics.setColor(1, 0, 1) -- Red outline for selection
    for i = 1, #bodies do
        --for _, thing in ipairs(state.selection.selectedBodies) do
        --local fixtures = body:getFixtures()
        local body = bodies[i]
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

return lib

```

src//box2d-pointerjoints.lua
```lua
--box2d-pointerjoints.lua
local lib = {}
local state = require 'src.state'
local pointerJoints = {}

local function getPointerPosition(id)
    if id == 'mouse' then
        return love.mouse.getPosition()
    else
        return love.touch.getPosition(id)
    end
end

local function makePrio(fixture)
    local ud = fixture:getUserData()
    if ud and type(ud) == 'table' then
        if ud.bodyType then
            if string.match(ud.bodyType, 'hand') then
                return 3
            end

            if string.match(ud.bodyType, 'arm') then
                return 2
            end
        end
    end
    return 1
end

function lib.makePointerJoint(id, bodyToAttachTo, wx, wy, force, damp)
    local pointerJoint = {}
    pointerJoint.id = id
    pointerJoint.jointBody = bodyToAttachTo
    pointerJoint.joint = love.physics.newMouseJoint(pointerJoint.jointBody, wx, wy)
    pointerJoint.joint:setDampingRatio(damp or .5)
    pointerJoint.joint:setMaxForce(force)
    return pointerJoint
end

function lib.resetPointerJoints()
    pointerJoints = {}
end

function lib.killMouseJointIfPossible(id)
    local index = -1
    if pointerJoints then
        for i = 1, #pointerJoints do
            if pointerJoints[i].id == id then
                index = i
                if (pointerJoints[i].joint and not pointerJoints[i].joint:isDestroyed()) then
                    pointerJoints[i].joint:destroy()
                end
                pointerJoints[i].joint     = nil
                pointerJoints[i].jointBody = nil
            end
        end
        if index ~= -1 then
            table.remove(pointerJoints, index)
        end
    end
end

function lib.removeDeadPointerJoints()
    local index = -1
    for i = #pointerJoints, 1, -1 do
        if (pointerJoints[i].joint and pointerJoints[i].joint:isDestroyed()) then
            pointerJoints[i].joint     = nil
            pointerJoints[i].jointBody = nil
            table.remove(pointerJoints, i)
        end
    end
end

function lib.handlePointerUpdate(dt, cam)
    lib.removeDeadPointerJoints()
    -- connect connectors
    for i = 1, #pointerJoints do
        local mj = pointerJoints[i]
        if (mj.joint) then
            local mx, my = getPointerPosition(mj.id) --love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)
            mj.joint:setTarget(wx, wy)

            local fixtures = mj.jointBody:getFixtures()
            for k = 1, #fixtures do
                local f = fixtures[k]
                if f:getUserData() and type(f:getUserData()) == 'table' and f:getUserData().bodyType then
                    if f:getUserData().bodyType == 'connector' then
                        --connect.maybeConnectThisConnector(f)
                    end
                end
            end
        end
    end

    -- diconnect connectors
    --connect.maybeBreakAnyConnectorBecauseForce(dt)
    --connect.cleanupCoolDownList(dt)
end

function lib.getPointerJointAttachedTo(body)
    if pointerJoints then
        for i = 1, #pointerJoints do
            local mj = pointerJoints[i]
            if mj.joint and mj.jointBody and mj.jointBody == body then
                return mj
            end
        end
    end
end

function lib.getInteractedWithPointer()
    local interactedWith = {}
    local pjs = pointerJoints
    for i = 1, #pjs do
        table.insert(interactedWith, pjs[i].jointBody)
    end
    return interactedWith
end

function lib.getPointerJoints()
    return pointerJoints
end

function lib.handlePointerReleased(x, y, id)
    local released = {}
    if pointerJoints then
        for i = 1, #pointerJoints do
            local mj = pointerJoints[i]
            -- if false then
            if mj.id == id then
                if mj.joint and mj.jointBody then
                    table.insert(released, mj.jointBody)
                end
            end
        end
        lib.killMouseJointIfPossible(id)
    end
    --print('jo!', #released)
    return released
end

function lib.handlePointerPressed(wx, wy, id, onPressedParams, allowMouseJointMaking)
    if allowMouseJointMaking == nil then allowMouseJointMaking = true end
    -- local wx, wy = cam:getWorldCoordinates(x, y)
    --

    local bodies = state.physicsWorld:getBodies()
    local temp = {}
    local hitted = {}
    for _, body in ipairs(bodies) do
        if body:getType() == 'kinematic' then
            -- for the playitme editor i do want to be able to slect these..
            -- local fixtures = body:getFixtures()
            local fixtures = body:getFixtures()
            for _, fixture in ipairs(fixtures) do
                local hitThisOne = fixture:testPoint(wx, wy)

                if (hitThisOne) then
                    table.insert(hitted, fixture)
                end
            end
        end
        if body:getType() ~= 'kinematic' then
            local fixtures = body:getFixtures()
            for _, fixture in ipairs(fixtures) do
                local hitThisOne = fixture:testPoint(wx, wy)
                local isSensor = fixture:isSensor()
                if (hitThisOne) then
                    table.insert(hitted, fixture)
                end
                -- something here needs to be parameterized.

                if (hitThisOne and not isSensor) then
                    table.insert(temp,
                        { id = id, body = body, wx = wx, wy = wy, prio = makePrio(fixture), fixture = fixture })

                    if onPressedParams then
                        if onPressedParams.onPressedFunc then
                            onPressedParams.onPressedFunc(body)
                        end
                    end
                end
            end
        end
    end

    local createdmousejointdata = {}

    if #temp > 0 then
        table.sort(temp, function(k1, k2) return k1.prio > k2.prio end)
        lib.killMouseJointIfPossible(id)

        local damp = .5
        if onPressedParams and onPressedParams.damp then
            damp = onPressedParams.damp
        end
        local force = 100
        if onPressedParams and onPressedParams.pointerForceFunc then
            force = onPressedParams.pointerForceFunc(temp[1].fixture)
        end

        if (allowMouseJointMaking) then
            local udID = temp[1].body:getUserData().thing.id
            createdmousejointdata = {
                pointerID = temp[1].id,
                bodyID = udID,
                --body = temp[1].body,
                wx = temp[1].wx,
                wy = temp[1].wy,
                force = force,
                damp = damp
            }
            table.insert(pointerJoints,
                lib.makePointerJoint(temp[1].id, temp[1].body, temp[1].wx, temp[1].wy, force, damp))
        end
    end
    -- print(#pointerJoints)
    if #temp == 0 then lib.killMouseJointIfPossible(id) end

    return #temp > 0, hitted, createdmousejointdata
end

return lib

```

src//camera.lua
```lua
--camera.lua
local Camera = require 'vendor.brady'


local function resizeCamera(self, w, h)
    local scaleW, scaleH = w / self.w, h / self.h
    local scale = math.min(scaleW, scaleH)
    -- the line below keeps aspect
    --self.w, self.h = scale * self.w, scale * self.h
    -- the line below deosnt keep aspect
    self.w, self.h = scaleW * self.w, scaleH * self.h
    self.aspectRatio = self.w / w
    self.offsetX, self.offsetY = self.w / 2, self.h / 2
    offset = offset * scale
end

local function createCamera()
    offset = 0
    local W, H = love.graphics.getDimensions()

    return Camera(
        W - 2 * offset,
        H - 2 * offset,
        {
            x = offset,
            y = offset,
            resizable = true,
            maintainAspectRatio = true,
            resizingFunction = function(self, w, h)
                resizeCamera(self, w, h)
                local W, H = love.graphics.getDimensions()
                self.x = offset
                self.y = offset
            end,
            getContainerDimensions = function()
                local W, H = love.graphics.getDimensions()
                return W - 2 * offset, H - 2 * offset
            end
        }
    )
end

local _camera = createCamera()
local lib = {}
-- i've gotten rid of a lot of older functionality i was using i the vector sketch experiments, no longer usefull.'
lib.getInstance = function()
    return _camera
end
lib.centerCameraOnPosition = function(x, y, vw, vh)
    local cw, ch = _camera:getContainerDimensions()
    local targetScale = math.min(cw / vw, ch / vh)
    _camera:setScale(targetScale)
    _camera:setTranslation(x, y)
end
lib.setCameraViewport = function(c2, w, h)
    local cx, cy = c2:getTranslation()
    local cw, ch = c2:getContainerDimensions()
    local targetScale = math.min(cw / w, ch / h)
    c2:setScale(targetScale)
    c2:setTranslation(cx, -1 * h / 2)
end

return lib

```

src//character-manager.lua
```lua
local lib = {}

local ObjectManager = require 'src.object-manager' -- To create the physical parts
local Joints = require 'src.joints'
local uuid = require 'src.uuid'
local utils = require 'src.utils'
local mathutils = require 'src.math-utils'
local fixtures = require 'src.fixtures'

-- todo,
-- the curves for the limbs need a grow parameter, now its just some hardcoded value in lib.drawTexturedWorld(world)
-- the torso images, or maybe every tex-fixture also needs a growvalue that describes how much the w, h values will be grown.
-- next the chesthair has a grow too, the torso too and I also have a foot offset value that should be parametrized.

local function randomHexColor()
    local r = math.random(0, 255)
    local g = math.random(0, 255)
    local b = math.random(0, 255)
    local a = 255 -- fully opaque, or adjust if you want random alpha
    return string.format("%02X%02X%02X%02X", r, g, b, a)
end

function createDefaultTextureDNABlock(shape, skipFG)
    return {
        bgURL = shape .. '.png',
        fgURL = skipFG and '' or shape .. '-mask.png',
        pURL = '',
        bgHex = '020202ff',
        fgHex = skipFG and '' or 'ff0000ff',
        pHex = 'ffff00ff',
    }
end

function initBlock(url)
    return {
        bgURL = (url or '') .. '.png',
        fgURL = (url or '') .. '-mask.png',
        pURL = '',
        bgHex = '020202ff',
        fgHex = randomHexColor(),
        pHex = randomHexColor(),
    }
end

function add(block, values)
    for k, v in pairs(values) do
        block[k] = v
    end
    return block
end

function lib.updateSkinOfPart(instance, partName, values, optionalPatchName)
    local p = instance.dna.parts[partName]
    if p then
        if p.appearance and p.appearance['skin'] then
            local patch = optionalPatchName or 'main'
            if p.appearance['skin'][patch] then
                for k, v in pairs(values) do
                    p.appearance['skin'][patch][k] = v
                end
            end
        end
    end
end

local shape8Dict = {
    ['shapeA1.png'] = {
        v = {
            1.61, -272.46, 112.13, -133.04, 154.81, 76.67, 123.57, 229.44, 1.21, 273.51, -134.54, 225.43, -145.28, 73.64, -91.99, -132.77
        }
    },
    ['shapeA2.png'] = {
        v = {
            11.62, -224.06, 60.89, -144.08, 59.89, -20.57, 133.96, 135.02, 4.30, 224.06, -133.96, 131.49, -51.71, -20.97, -39.30, -147.16,
        }
    },
    ['shapeA3.png'] = {
        v = {
            -6.62, -189.25, 135.88, -69.67, 160.54, 45.82, 123.85, 154.90, -6.37, 189.25, -92.40, 153.92, -164.61, 53.37, -155.10, -67.94
        }
    },
    ['shapeA4.png'] = {
        v = {
            7.91, -194.17, 133.01, -56.57, 126.54, 45.82, 101.32, 190.94, -6.99, 195.81, -129.67, 185.05, -134.73, 40.26, -110.48, -66.30

        }
    },


    ['shapes1.png'] = {
        v = {
            10.53, -244.02, 133.00, -56.57, 135.72, 48.44, 124.93, 221.11, -0.43, 231.23, -128.36, 215.22, -138.66, 41.58, -134.09, -62.36

        }
    },
    ['shapes2.png'] = {
        v = {
            -3.37, -223.15, 74.58, -78.83, 89.81, 51.22, 104.06, 196.07, -0.43, 231.23, -92.19, 202.70, -94.15, 54.10, -61.75, -80.45
        }
    },
    ['shapes3.png'] = {
        v = {
            -3.37, -206.98, 132.81, -137.06, 148.04, 12.40, 110.53, 186.37, -6.90, 216.67, -97.04, 192.99, -149.14, 7.194, -141.01, -141.91
        }
    },
    ['shapes4.png'] = {
        v = {
            0.52, -123.04, 164.04, -98.02, 148.04, 12.40, 157.384, 112.19, -1.05, 117.121, -149.75, 105.159, -149.14, 7.19, -168.33, -87.25
        }
    },
    ['shapes5.png'] = {
        v = {
            0.52, -162.14, 74.68, -132.92, 78.23, -4.34, 73.61, 148.49, -2.44, 156.21, -81.33, 142.85, -84.921, 1.609, -87.35, -126.353,

        }
    },
    ['shapes6.png'] = {
        v = {
            3.17, -178.04, 77.33, -118.34, 92.815, -0.36, 93.491, 143.19, -2.44, 160.19, -85.314, 141.53, -92.87, 0.28, -67.478, -119.727
        }
    },
    ['shapes7.png'] = {
        v = {
            -3.26, -452.74, 127.787, -245.570, 305.58, 19.37, 247.03, 384.48, -2.448, 451.92, -276.14, 378.42, -283.70, 15.63, -207.86, -238.17

        }
    },
    ['shapes8.png'] = {
        v = {
            3.90, -154.02, 271.18, -307.71, 341.43, 26.54, 89.31, 298.45, -9.62, 332.43, -166.22, 299.56, -302.83, 34.76, -238.93, -319.43

        }
    },
    ['shapes9.png'] = {
        v = {
            -0.56, -236.64, 233.22, -191.59, 198.53, 24.31, 174.16, 206.90, -18.55, 216.32, -226.51, 205.78, -233.61, 19.13, -234.46, -198.85


        }
    },
    ['shapes10.png'] = {
        v = {
            4.96, -407.86, 166.94, -232.10, 231.67, 24.31, 141.02, 344.99, -16.71, 418.85, -186.00, 332.82, -233.61, 19.13, -182.91, -233.83
        }
    },
    ['shapes11.png'] = {
        v = {
            4.96, -451.24, 110.80, -405.62, 195.94, 6.45, 306.89, 408.78, 13.91, 436.71, -277.86, 417.03, -205.54, -3.84, -114.01, -417.56
        }
    },
    ['shapes12.png'] = {
        v = {
            17.22, -129.91, 208.91, -76.93, 249.91, 11.35, 191.60, 109.52, 9.01, 142.36, -228.81, 103.06, -247.24, -1.39, -175.34, -91.32
        }
    },
    ['shapes13.png'] = {
        v = {
            22.72, -239.92, 175.91, -101.68, 197.65, 11.35, 177.85, 219.53, 14.51, 260.62, -168.30, 210.32, -156.48, 12.37, -125.83, -105.07
        }
    },
    ['feet2.png'] = {
        v = {

            -- 197.92951957406, -17.817718028013, 170.28347402696, 84.883981989375, 104.3382073697, 106.29365560207, -139.66342189896, 114.08328408959, -165.65174171676, -8.6379557618171, -123.63314042073, -45.112484801676, 86.784081767721, -100.15140769724, 155.71079120581, -103.47476376929


            22.724588666593, -239.91966159884, 175.91013654, -101.67978777203, 197.65083381201, 11.351997784339, 177.84539019051, 219.53355732218, 14.507790801039, 260.6223497519, -168.29987466902, 210.31594772675, -156.47637293323, 12.365272224268, -125.83138609296, -105.07368014657

        }
    },

    ['feet2r.png'] = {
        v = {

            -- 197.92951957406, -17.817718028013, 170.28347402696, 84.883981989375, 104.3382073697, 106.29365560207, -139.66342189896, 114.08328408959, -165.65174171676, -8.6379557618171, -123.63314042073, -45.112484801676, 86.784081767721, -100.15140769724, 155.71079120581, -103.47476376929

            46.990907603994, -189.52773689109, 96.489192783945, -184.68643013375, 131.34012844459, 48.508703705155, 109.48859096573, 180.93295171947, 45.027594164554, 234.39907734869, -15.618229361652, 176.92515604219, -70.173442070241, 53.300130131955, -87.304763540911, -193.80518221938


        }
    },
    ['feet6r.png'] = {
        v = {
            -26.163452363425, -287.93776875202, 45.977848996918, -180.33200394521, 110.43888273961, 42.412507041203, 116.65637069995, 166.59739225104, -6.9388089085194, 273.82186588688, -108.79936590647, 268.31434765346, -110.23416300478, 47.203933468003, -102.10981258194, -181.61278889148
        }
    }
}

local dna = {
    ['humanoid'] = {
        creation = {
            isPotatoHead = false,
            neckSegments = 5,
            torsoSegments = 1
        },


        -- in the pppearance belwo we have a few options for types:
        -- skin = a skin that assumes a shape8 url to be present.
        -- bodyhair, = an overlay that assumes the shape8 url to be present, it will follow that
        -- connected-skin = a texture that will be drawn over a few connectd bodyparts
        -- connected-hair = an overlay that assumes a few parts to be there too.

        parts = {
            ['torso-segment-template'] = {
                appearance = {
                    -- this will do the neck texturing (connecting torso and head)
                    ['connected-skin'] = {
                        main = add(initBlock('leg5'), {}),
                        endNode = 'head'
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = 1 }),
                        endNode = 'head'
                    },
                    ['skin'] = {
                        main = initBlock(),
                        patch1 = add(initBlock('patch2'), { tx = 0.3, ty = 0.3 }),
                        patch2 = add(initBlock('patch1'), { tx = -0.3, ty = 0.3 })
                    },
                    ['bodyhair'] = { main = add(initBlock('borsthaar4'), {}) }
                },
                dims = { w = 280, w2 = 5, h = 300, sx = 1, sy = 1 },
                shape8URL = 'shapeA1.png',
                shape = 'shape8',
                j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },

            --['torso-segment-template'] = { dims = { w = 280, w2 = 5, h = 80 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 16, up = math.pi / 16 } } },
            -- ['torso1'] = { dims = { w = 300, w2 = 4, h = 300 }, shape = 'trapezium' },
            ['neck-segment-template'] = {

                dims = { w = 80, w2 = 4, h = 150 },
                shape = 'capsule',
                j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            -- ['head'] = { dims = { w = 100, w2 = 4, h = 180 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 4, up = math.pi / 4 } } },
            ['head'] = {
                appearance = {
                    ['skin'] = {
                        main = initBlock(),
                        patch1 = add(initBlock('patch1'), { tx = 0.3, ty = 0.3 }),
                        patch2 = add(initBlock('patch1'), { tx = -0.3, ty = 0.3 })
                    },
                    ['bodyhair'] = { main = initBlock('borsthaar4') }
                },
                dims = { w = 100, w2 = 4, h = 180, sx = 1, sy = 1 },
                shape = 'shape8',
                shape8URL = 'shapeA2.png',
                j = { type = 'revolute', limits = { low = -math.pi / 4, up = math.pi / 4 } }
            },
            ['luleg'] = {
                appearance = {
                    ['connected-skin'] = {
                        main = add(initBlock('leg5'), { dir = -1 }),
                        endNode = 'lfoot'
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = -1 }),
                        endNode = 'lfoot'
                    }
                },
                dims = { w = 80, h = 200, w2 = 4 },
                shape = 'capsule',
                j = { type = 'revolute', limits = { low = 0, up = math.pi / 2 } }
            },
            ['ruleg'] = {
                appearance = {
                    ['connected-skin'] = {
                        main = add(initBlock('leg5'), { dir = 1 }),
                        endNode = 'rfoot'
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = 1 }),
                        endNode = 'rfoot'
                    }
                },
                dims = { w = 80, h = 200, w2 = 4 },
                shape = 'capsule',
                j = { type = 'revolute', limits = { low = -math.pi / 2, up = 0 } }
            },
            ['llleg'] = { dims = { w = 80, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 2, up = 0 } } },
            ['rlleg'] = { dims = { w = 80, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = { low = 0, up = math.pi / 2 } } },
            ['luarm'] = {
                appearance = {
                    ['connected-skin'] = {
                        zOffset = 1,
                        main = add(initBlock('leg5'), { dir = -1 }),
                        endNode = 'lhand'
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = -1 }),
                        endNode = 'lfoot'
                    }
                },
                dims = { w = 40, h = 200, w2 = 4 },
                shape = 'capsule',
                j = { type = 'revolute', limits = { low = 0, up = math.pi } }
            },
            ['ruarm'] = {
                appearance = {
                    ['connected-skin'] = {
                        zOffset = 1,
                        main = add(initBlock('leg5'), { dir = 1 }),
                        endNode = 'rhand'
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = 1 }),
                        endNode = 'lfoot'
                    }
                },
                dims = { w = 40, h = 200, w2 = 4 },
                shape = 'capsule',
                j = { type = 'revolute', limits = { low = -math.pi, up = 0 } }
            },
            ['llarm'] = { dims = { w = 40, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = {} } },
            ['rlarm'] = { dims = { w = 40, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = {} } },
            ['lfoot'] = {
                appearance = {
                    ['skin'] = {
                        main = add(initBlock(), { dir = -1 }),
                    },

                },
                dims = { w = 80, h = 150, sx = .5, sy = 1 },
                shape = 'shape8',
                shape8URL = 'feet6r.png',
                j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            ['rfoot'] = {
                appearance = {
                    ['skin'] = {
                        main = add(initBlock(), { dir = 1 }),
                    },
                },
                dims = { w = 80, h = 150, sx = -.5, sy = 1 },
                shape = 'shape8',
                shape8URL = 'feet6r.png',
                j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            -- TODO THIS IS SO WEIRD, BUT WHEN I DONT USE A SHAPE8 for THE FOOT THE ANGLE IS FLIPPED?!
            --['lfoot'] = { dims = { w = 80, h = 250 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            --['rfoot'] = { dims = { w = 80, h = 250 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            ['lhand'] = {
                appearance = {
                    ['skin'] = {
                        main = add(initBlock(), { dir = -1 }),
                    },
                },
                dims = { w = 40, h = 40, sx = .5, sy = .9 },
                shape = 'shape8',
                shape8URL = 'feet2r.png',
                j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            ['rhand'] = {
                appearance = {
                    ['skin'] = {
                        main = add(initBlock(), {}),
                    },
                },
                dims = { w = 40, h = 40, sx = -.5, sy = .9 },
                shape = 'shape8',
                shape8URL = 'feet2r.png',
                j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            -- TODo same kind of weirdness for the hands!
            -- ['lhand'] = { dims = { w = 40, h = 400 }, shape = 'rectangle', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            -- ['rhand'] = { dims = { w = 40, h = 400 }, shape = 'rectangle', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            ['lear'] = { dims = { w = 10, h = 100 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 16, up = math.pi / 16 } }, stanceAngle = -math.pi / 2 },
            ['rear'] = { dims = { w = 10, h = 100 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 16, up = math.pi / 16 } }, stanceAngle = math.pi / 2 }
        },

    }
}



function lib.updateShape8(instance, partName, newShape8Name)
    -- Update the physics part
    lib.updatePart(partName, { shape8URL = newShape8Name .. '.png' }, instance)

    -- Trigger a rebuild
    lib.rebuildFromCreation(instance, {})

    -- Update all visuals linked to that shape
    --lib.updateTextureGroupValue(instance, partName .. 'Skin', 'bgURL', newShape8Name .. '.png')
    --lib.updateTextureGroupValue(instance, partName .. 'Skin', 'fgURL', newShape8Name .. '-mask.png')
    --lib.updateTextureGroupValueInRoot(instance, partName .. 'Hair', 'followShape8', newShape8Name .. '.png')

    -- Recreate the actual texture fixtures
    --   lib.addTextureFixturesFromInstance(instance)
end

-- copy pasted from playtime-ui.lua
local function getCenterAndDimensions(body)
    local ud = body:getUserData()
    local cx, cy, w, h
    if ud.thing.vertices then
        local verts = ud.thing.vertices
        cx, cy, w, h = mathutils.getCenterOfPoints(verts)
    else -- this is a circle shape..
        cx, cy = body:getPosition()
        w, h = ud.thing.radius * 2, ud.thing.radius * 2
    end
    return cx, cy, w, h
end


local function makeTransformedVertices(vertices, scaleX, scaleY)
    local result = {}

    for i = 1, #vertices, 2 do
        local x = vertices[i]
        local y = vertices[i + 1]
        local newX = x * scaleX
        local newY = y * scaleY
        table.insert(result, newX)
        table.insert(result, newY)
    end

    return result
end

local function getTransformedIndex(index, flipX, flipY)
    if flipY == -1 and flipX == 1 then
        local values = { 5, 4, 3, 2, 1, 8, 7, 6 }
        return values[index]
    end
    if flipX == -1 and flipY == 1 then
        local values = { 1, 8, 7, 6, 5, 4, 3, 2 }
        return values[index]
    end
    if flipX == -1 and flipY == -1 then
        local values = { 5, 6, 7, 8, 1, 2, 3, 4 }
        return values[index]
    end
    if flipX == 1 and flipY == 1 then
        local values = { 1, 2, 3, 4, 5, 6, 7, 8 }
        return values[index]
    end
end

local function clamp(x, min, max)
    return x < min and min or (x > max and max or x)
end

local function lerp(a, b, amount)
    return a + (b - a) * clamp(amount, 0, 1)
end

local function extractNeckIndex(name)
    local index = string.match(name, "^neck(%d+)$")
    return index and tonumber(index) or nil
end

local function extractTorsoIndex(name)
    local index = string.match(name, "^torso(%d+)$")
    return index and tonumber(index) or nil
end

local function getParentAndChildrenFromPartName(partName, guy)
    local creation      = guy.dna.creation
    local neckSegments  = creation.neckSegments or 0
    local torsoSegments = creation.torsoSegments or 1

    local highestTorso  = 'torso' .. torsoSegments
    local lowestTorso   = 'torso1'

    local map           = {

        head = { p = (neckSegments > 0) and ('neck' .. neckSegments) or highestTorso, c = { 'lear', 'rear' } },
        lear = { p = 'head' },
        rear = { p = 'head' },
        luarm = { p = highestTorso, c = 'llarm' },
        llarm = { p = 'luarm', c = 'lhand' },
        lhand = { p = 'llarm' },
        ruarm = { p = highestTorso, c = 'rlarm' },
        rlarm = { p = 'ruarm', c = 'rhand' },
        rhand = { p = 'rlarm' },
        luleg = { p = lowestTorso, c = 'llleg' },
        llleg = { p = 'luleg', c = 'lfoot' },
        lfoot = { p = 'llleg' },
        ruleg = { p = lowestTorso, c = 'rlleg' },
        rlleg = { p = 'ruleg', c = 'rfoot' },
        rfoot = { p = 'rlleg' },

    }

    local neckIndex     = extractNeckIndex(partName)
    if neckIndex then
        if neckIndex == 1 then
            map[partName] = { p = highestTorso, c = (neckIndex == neckSegments) and 'head' or 'neck2' }
        else
            map[partName] = {
                p = 'neck' .. (neckIndex - 1),
                c = (neckIndex == neckSegments) and 'head' or
                    'neck' .. neckIndex + 1
            }
        end
    end

    local torsoIndex = extractTorsoIndex(partName)

    if torsoIndex then
        if torsoIndex then
            local children = {}
            -- Middle segments connect only to the next torso segment
            if torsoIndex < torsoSegments then
                table.insert(children, 'torso' .. (torsoIndex + 1))
            end

            -- Highest segment connects to arms and neck/head
            if torsoIndex == torsoSegments then
                if not creation.isPotatoHead then
                    table.insert(children, (neckSegments > 0) and 'neck1' or 'head')
                end
                table.insert(children, 'luarm')
                table.insert(children, 'ruarm')
                if creation.isPotatoHead then -- Potato ears attach to highest torso
                    table.insert(children, 'lear')
                    table.insert(children, 'rear')
                end
            end
            -- Lowest segment connects to legs
            if torsoIndex == 1 then
                table.insert(children, 'luleg')
                table.insert(children, 'ruleg')
            end
            if torsoIndex == 1 then
                map[partName] = { c = children } -- Torso1 has no parent
            else
                map[partName] = { p = 'torso' .. (torsoIndex - 1), c = children }
            end
        end
    end

    -- Overrides for special cases
    -- Head connects directly to highest torso if no neck
    if partName == 'head' and neckSegments == 0 then
        map[partName] = { p = highestTorso, c = { 'lear', 'rear' } }
    end

    -- If Potato Head, ears parent is highest torso (head doesn't exist as parent)
    if creation.isPotatoHead then
        map['lear'] = { p = highestTorso }
        map['rear'] = { p = highestTorso }
        -- Remove head connection if it exists from map
        map['head'] = nil -- No head part in potato mode
    end

    -- If only one torso segment, it has all children directly
    if torsoSegments == 1 and partName == 'torso1' then
        local children = {}
        if creation.isPotatoHead then
            children = { 'luarm', 'ruarm', 'luleg', 'ruleg', 'lear', 'rear' }
        else
            children = { (neckSegments > 0) and 'neck1' or 'head', 'luarm', 'ruarm', 'luleg', 'ruleg' }
        end

        map[partName] = { c = children }
    end

    local result = map[partName]
    return result or {} -- Return empty table if partName not found
end

local function sign(value)
    if value < 0 or value == nil then return -1 else return 1 end
end

local function getOwnOffset(partName, guy)
    local parts = guy.dna.parts


    -- upward
    if extractNeckIndex(partName) then
        return 0, -parts[partName].dims.h / 2
    end
    if extractTorsoIndex(partName) then
        if parts[partName].shape == 'shape8' then
            print(parts[partName].shape8URL)
            local raw = shape8Dict[parts[partName].shape8URL].v
            local vertices = makeTransformedVertices(raw, parts[partName].dims.sx or 1, parts[partName].dims.sy or 1)
            local topIndex = getTransformedIndex(1, sign(parts[partName].dims.sx), sign(parts[partName].dims.sy))
            local bottomIndex = getTransformedIndex(5, sign(parts[partName].dims.sx), sign(parts[partName].dims.sy))
            return -vertices[(bottomIndex * 2) - 1], vertices[(topIndex * 2)]
        else
            return 0, -parts[partName].dims.h / 2
        end
    end

    if partName == 'head' then
        if parts[partName].shape == 'shape8' then
            local raw = shape8Dict[parts[partName].shape8URL].v
            local vertices = makeTransformedVertices(raw, parts[partName].dims.sx or 1, parts[partName].dims.sy or 1)
            local topIndex = getTransformedIndex(1, sign(parts[partName].dims.sx), sign(parts[partName].dims.sy))
            local bottomIndex = getTransformedIndex(5, sign(parts[partName].dims.sx), sign(parts[partName].dims.sy))
            return -vertices[(bottomIndex * 2) - 1], vertices[(topIndex * 2)]
        else
            return 0, -parts[partName].dims.h / 2
        end
    end
    if partName == 'lear' then
        return 0, -parts.lear.dims.h / 2
    end
    if partName == 'rear' then
        return 0, -parts.rear.dims.h / 2
    end
    -- downward
    if partName == 'luleg' then
        return 0, parts.luleg.dims.h / 2
    end
    if partName == 'ruleg' then
        return 0, parts.ruleg.dims.h / 2
    end
    if partName == 'llleg' then
        return 0, parts.llleg.dims.h / 2
    end
    if partName == 'lfoot' or partName == 'rfoot' then
        local part = parts[partName]
        if part.shape == 'shape8' then
            local raw = shape8Dict[part.shape8URL].v

            local vertices = makeTransformedVertices(raw, part.dims.sx or 1, part.dims.sy or 1)
            local index = getTransformedIndex(1, sign(part.dims.sx), sign(part.dims.sy)) -- or pick 5 or another

            -- todo like the grow offsets this too should be parametrized
            local footOffset = 0
            return vertices[(index * 2) - 1], -vertices[(index * 2)] + footOffset
        else
            return 0, part.dims.h / 2
        end
    end
    if partName == 'rlleg' then
        return 0, parts.rlleg.dims.h / 2
    end

    if partName == 'luarm' then
        return 0, parts.luarm.dims.h / 2
    end
    if partName == 'ruarm' then
        return 0, parts.ruarm.dims.h / 2
    end
    if partName == 'rhand' or partName == 'lhand' then
        local part = parts[partName]
        if part.shape == 'shape8' then
            local raw = shape8Dict[part.shape8URL].v

            local vertices = makeTransformedVertices(raw, part.dims.sx or 1, part.dims.sy or 1)
            --logger:info(part.dims.sx, part.dims.sy)
            local index = getTransformedIndex(1, sign(part.dims.sx), sign(part.dims.sy)) -- or pick 5 or another
            return vertices[(index * 2) - 1], -vertices[(index * 2)]
        else
            return 0, part.dims.h / 2
        end
    end
    if partName == 'llarm' then
        return 0, parts.llarm.dims.h / 2
    end
    if partName == 'rlarm' then
        return 0, parts.rlarm.dims.h / 2
    end

    return 0, 0
end

local function getOffsetFromParent(partName, guy)
    local parts         = guy.dna.parts
    local creation      = guy.dna.creation
    local positioners   = guy.dna.positioners
    local data          = getParentAndChildrenFromPartName(partName, guy)
    -- Define the name of the highest torso segment
    local torsoSegments = creation.torsoSegments or 1
    local highestTorso  = 'torso' .. torsoSegments
    -- Define the name of the lowest torso segment (always torso1)
    local lowestTorso   = 'torso1'


    local function getTorsoPart8FromSpecificTorso(index, torsoIndex)
        local torso = 'torso' .. torsoIndex
        local raw = shape8Dict[parts[torso].shape8URL].v
        local vertices = makeTransformedVertices(raw, parts[torso].dims.sx or 1, parts[torso].dims.sy or 1)
        local newIndex = getTransformedIndex(index, sign(parts[torso].dims.sx), sign(parts[torso].dims.sy))
        return vertices[(newIndex * 2) - 1], vertices[(newIndex * 2)]
    end

    local function getTorsoPart8FromHighest(index)
        return getTorsoPart8FromSpecificTorso(index, torsoSegments)
    end

    local function getTorsoPart8FromLowest(index)
        return getTorsoPart8FromSpecificTorso(index, 1)
    end

    local function hasTorso8()
        if parts[highestTorso].shape == 'shape8' then
            return true
        end
        return false
    end

    local function hasHead8()
        if parts['head'].shape == 'shape8' then
            return true
        end
        return false
    end

    local function getHeadPart8(index)
        local raw = shape8Dict[parts['head'].shape8URL].v
        local vertices = makeTransformedVertices(raw, parts['head'].dims.sx or 1, parts['head'].dims.sy or 1)
        local newIndex = getTransformedIndex(index, sign(parts['head'].dims.sx), sign(parts['head'].dims.sy))

        return vertices[(newIndex * 2) - 1], vertices[(newIndex * 2)]
    end

    if extractNeckIndex(partName) then
        local index = extractNeckIndex(partName)
        if index == 1 then
            if hasTorso8() then
                return getTorsoPart8FromHighest(1)
            else
                return 0, -parts[highestTorso].dims.h / 2
            end
        else
            return 0, -parts['neck' .. (index - 1)].dims.h / 2
        end
    elseif extractTorsoIndex(partName) then
        local index = extractTorsoIndex(partName)
        if index == 1 then
            return 0, 0
        else
            if hasTorso8() then
                return getTorsoPart8FromSpecificTorso(1, index - 1)
            else
                return 0, -parts['torso' .. (index - 1)].dims.h / 2
            end
        end
    elseif partName == 'llarm' then
        return 0, parts.luarm.dims.h / 2
    elseif partName == 'rlarm' then
        return 0, parts.ruarm.dims.h / 2
    elseif partName == 'llleg' then
        return 0, parts.luleg.dims.h / 2
    elseif partName == 'lfoot' then
        return 0, parts.llleg.dims.h / 2
    elseif partName == 'rlleg' then
        return 0, parts.ruleg.dims.h / 2
    elseif partName == 'rfoot' then
        return 0, parts.rlleg.dims.h / 2
    elseif partName == 'rhand' then
        return 0, parts.rlarm.dims.h / 2
    elseif partName == 'lhand' then
        return 0, parts.llarm.dims.h / 2
    elseif partName == 'luarm' then
        if hasTorso8() then
            if creation.isPotatoHead then
                return getTorsoPart8FromHighest(7)
            else
                return getTorsoPart8FromHighest(8)
            end
        else
            return -parts[highestTorso].dims.w / 2, -parts[highestTorso].dims.h / 2
        end
    elseif partName == 'ruarm' then
        if hasTorso8() then
            if creation.isPotatoHead then
                return getTorsoPart8FromHighest(3)
            else
                return getTorsoPart8FromHighest(2)
            end
        else
            return parts[highestTorso].dims.w / 2, -parts[highestTorso].dims.h / 2
        end
    elseif partName == 'luleg' then
        local t = 0.5 --positioners.leg.x
        if hasTorso8() then
            local ax, ay = getTorsoPart8FromLowest(6)
            local bx, by = getTorsoPart8FromLowest(5)
            local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
            return rx, ry
        else
            return (-parts[lowestTorso].dims.w / 2) * (1 - t), parts[lowestTorso].dims.h / 2
        end
    elseif partName == 'ruleg' then
        local t = 0.5 -- positioners.leg.x

        if hasTorso8() then
            local ax, ay = getTorsoPart8FromLowest(4)
            local bx, by = getTorsoPart8FromLowest(5)
            local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
            return rx, ry
        else
            return (parts[lowestTorso].dims.w / 2) * (1 - t), parts[lowestTorso].dims.h / 2
        end
    elseif partName == 'lear' then
        if creation.isPotatoHead then
            if hasTorso8() then
                local t = 0.5
                local ax, ay = getTorsoPart8FromHighest(8)
                local bx, by = getTorsoPart8FromHighest(7)
                local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
                return rx, ry
            else
                return -parts[highestTorso].dims.w / 2, -parts[highestTorso].dims.h / 2
            end
        else
            if hasHead8() then
                local t = 0.5
                local ax, ay = getHeadPart8(7)
                local bx, by = getHeadPart8(8)
                local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
                return rx, ry
            else
                return -parts.head.dims.w / 2, -parts.head.dims.h / 2
            end
        end
    elseif partName == 'rear' then
        if creation.isPotatoHead then
            if hasTorso8() then
                local t = 0.5
                local ax, ay = getTorsoPart8FromHighest(2)
                local bx, by = getTorsoPart8FromHighest(3)
                local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
                return rx, ry
            else
                return parts[highestTorso].dims.w / 2, -parts[highestTorso].dims.h / 2
            end
        else
            if hasHead8() then
                local t = 0.5
                local ax, ay = getHeadPart8(2)
                local bx, by = getHeadPart8(3)
                local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
                return rx, ry
            else
                return parts.head.dims.w / 2, -parts.head.dims.h / 2
            end
        end
    elseif (partName == 'head') then
        if creation.neckSegments == 0 then
            if hasTorso8() then
                return getTorsoPart8FromHighest(1)
            else
                return 0, -parts[highestTorso].dims.h / 2
            end
        else
            local last = 'neck' .. creation.neckSegments
            return 0, -parts[last].dims.h / 2
        end
    else
        return 0, 0
    end
end

local function getAngleOffset(partName, guy)
    local parts = guy.dna.parts
    if partName == 'lfoot' then
        return math.pi / 2
    elseif partName == 'rfoot' then
        return -math.pi / 2
    elseif partName == 'lear' then
        return parts.lear.stanceAngle
    elseif partName == 'rear' then
        return parts.rear.stanceAngle
    else
        return 0
    end
end


local function makePart(partName, instance, settings)
    local values = getParentAndChildrenFromPartName(partName, instance)
    local parent = values.p
    local prevA = 0

    if parent then
        if instance.parts[parent] then
            local parentPosX, parentPosY = instance.parts[parent].body:getPosition()
            prevA = instance.parts[parent].body:getAngle()
            local parentOffsetX, parentOffsetY = getOffsetFromParent(partName, instance)
            local px, py = instance.parts[parent].body:getWorldPoint(parentOffsetX, parentOffsetY)
            settings.x = px
            settings.y = py
        end
    end

    local ownOffsetX, ownOffsetY = getOwnOffset(partName, instance)
    local xangle = getAngleOffset(partName, instance)

    -- Rotate own offset into parent space
    local rotatedOwnX, rotatedOwnY = mathutils.rotatePoint(ownOffsetX, ownOffsetY, 0, 0, prevA + xangle)

    settings.x = settings.x + rotatedOwnX
    settings.y = settings.y + rotatedOwnY

    local thing = ObjectManager.addThing(settings.shapeType, settings)

    if thing then
        thing.body:setAngle(prevA + xangle)

        if extractNeckIndex(partName) then
            thing.body:setAngularDamping(.1)
            thing.body:setLinearDamping(.1)
        end
        if extractTorsoIndex(partName) then
            thing.body:setAngularDamping(.1)
            thing.body:setLinearDamping(.1)
            local f = thing.body:getFixtures()
            for i = 1, #f do
                f[i]:setDensity(1)
            end
        end

        instance.parts[partName] = thing
    end

    if parent then
        local partA_thing = instance.parts[parent]
        local partB_thing = instance.parts[partName]

        if (partA_thing and partB_thing) then
            local jointData = instance.dna.parts[partName].j
            local jointCreationData = {
                body1 = partA_thing.body,
                body2 = partB_thing.body,
                jointType = jointData.type,
                collideConnected = false, -- Default to false
                id = uuid.generateID(),
                offsetA = { x = 0, y = 0 },
                offsetB = { x = 0, y = 0 },
            }
            -- logger:info('joint:', parent, partName)
            -- todo we dont really need this yet...
            instance.joints[parent .. '->' .. partName] = jointCreationData.id

            local offX, offY = getOffsetFromParent(partName, instance)
            jointCreationData.offsetA.x = jointCreationData.offsetA.x + offX
            jointCreationData.offsetA.y = jointCreationData.offsetA.y + offY
            local joint = Joints.createJoint(jointCreationData)
            local limits = jointData.limits

            if joint and limits and limits.low and limits.up then
                joint:setLimits(limits.low, limits.up)
                joint:setLimitsEnabled(true)
            end
        end
    end
end

local function getPoseCache(instance)
    local poseCache = {}
    for partName, part in pairs(instance.parts) do
        local body = part.body
        local groupIndex = body:getFixtures()[1]:getGroupIndex()
        poseCache[partName] = {
            pos = { body:getPosition() },
            angle = body:getAngle(),
            linearVelocity = { body:getLinearVelocity() },
            angularVelocity = body:getAngularVelocity(),
            groupIndex = groupIndex or 0
        }
    end
    return poseCache
end
local function applyPoseCache(instance, poseCache)
    -- using the cache
    for partName, pose in pairs(poseCache) do
        if instance.parts[partName] and pose then
            local body = instance.parts[partName].body
            --body:setPosition(pose.pos[1], pose.pos[2])
            body:setAngle(pose.angle)
            body:setLinearVelocity(pose.linearVelocity[1], pose.linearVelocity[2])
            body:setAngularVelocity(pose.angularVelocity)

            local fixtures = body:getFixtures()
            for j = 1, #fixtures do
                fixtures[j]:setGroupIndex(pose.groupIndex)
            end
        end
    end
end

local function fixDrift(positionTorso, instance)
    if positionTorso then
        local newPosX, newPosY = instance.parts['torso1'].body:getPosition()
        local newAngle = instance.parts['torso1'].body:getAngle()
        local dx = positionTorso[1] - newPosX
        local dy = positionTorso[2] - newPosY

        for _, part in pairs(instance.parts) do
            local bx, by = part.body:getPosition()
            part.body:setPosition(bx + dx, by + dy)
        end
    end
end

local function updateSinglePart(partName, data, instance)
    local partData = instance.dna.parts[partName]
    if not partData then return end


    for k, v in pairs(data) do
        if (partData.dims[k]) then
            partData.dims[k] = v
        elseif partData[k] then
            partData[k] = v
        end
    end

    local oldBody = nil
    local oldPosX, oldPosY = 0, 0
    local oldAngle = 0

    -- Remove old body
    local extras = {}
    if instance.parts[partName] then
        oldBody = instance.parts[partName].body
        oldPosX, oldPosY = oldBody:getPosition()
        oldAngle = oldBody:getAngle()
        local body = instance.parts[partName].body
        ObjectManager.destroyBody(body)
        instance.parts[partName] = nil
    end
    -- Recreate the part
    local settings = {
        x = oldPosX,
        y = oldPosY,
        bodyType = 'dynamic',
        shapeType = partData.shape,
        shape8URL = partData.shape8URL,
        label = partName,
        density = partData.density or 1,
        radius = partData.dims.r,
        width = partData.dims.w,
        width2 = partData.dims.w2,
        width3 = partData.dims.w2,
        height = partData.dims.h,
        height2 = partData.dims.h,
        height3 = partData.dims.h,
        height4 = partData.dims.h,
    }

    if partData.shape8URL and shape8Dict[partData.shape8URL] then
        local raw = shape8Dict[partData.shape8URL].v
        settings.vertices = makeTransformedVertices(raw, partData.dims.sx or 1, partData.dims.sy or 1)
    end

    local children = getParentAndChildrenFromPartName(partName, instance).c or {}
    if type(children) == 'string' then
        children = { children }
    end
    makePart(partName, instance, settings)

    -- after making a part set it to its angle so the children will be using that angle in their calculations.
    instance.parts[partName].body:setAngle(oldAngle)

    for _, childName in ipairs(children) do
        local childData = instance.dna.parts[childName]
        if childData then
            updateSinglePart(childName, {}, instance) -- trigger rebuild
        end
    end
end

-- update part
function lib.updatePart(partName, data, instance)
    local positionTorso = nil
    local oldAngle = 0
    if partName == 'torso1' then
        positionTorso = { instance.parts['torso1'].body:getPosition() }
    end

    -- filling the cache
    local poseCache = getPoseCache(instance)
    updateSinglePart(partName, data, instance)
    applyPoseCache(instance, poseCache)
    if positionTorso then fixDrift(positionTorso, instance) end
end

-- given an instance with dna and a new creation, this function is made to change a creation of a humanoid during runtime.
-- its alos used by initially creating a character.
function lib.rebuildFromCreation(instance, newCreation)
    -- Step 1: Update the creation settings
    for k, v in pairs(newCreation) do
        instance.dna.creation[k] = v
    end

    local torsoX, torsoY = instance.parts['torso1'].body:getPosition()
    local torsoAngle = instance.parts['torso1'].body:getAngle()

    local poseCache = getPoseCache(instance)

    local positionTorso = { instance.parts['torso1'].body:getPosition() }


    -- Step 2: Remove all existing parts
    for _, part in pairs(instance.parts) do
        ObjectManager.destroyBody(part.body)
    end

    instance.parts = {}
    instance.joints = {}
    instance.textures = {}

    lib.createCharacterFromExistingDNA(instance, torsoX, torsoY, torsoAngle)

    applyPoseCache(instance, poseCache)
    if positionTorso then fixDrift(positionTorso, instance) end
end

function lib.addTexturesFromInstance2(instance)
    -- for k, v in pairs(instance.parts) do
    --     local part = v
    --     print(inspect(v))
    --     if part.appearance then
    --         print(k)
    --     end
    -- end
    for k, v in pairs(instance.dna.parts) do
        if v.appearance then
            --logger:info(k .. ' has appearance')
            local relevant = instance.parts[k]
            if (relevant) then
                --logger:info('relevant real thing found ' .. k)
                --logger:inspect(v.appearance)
                --
                --
                -- maybe i can jst remove all texture fixtures from the body right now?
                -- and then reattahc new ones below.

                local allFixtures = relevant.body:getFixtures()
                for fi = #allFixtures, 1, -1 do -- backwards to safely remove
                    local f = allFixtures[fi]
                    local ud = f:getUserData()
                    if ud then
                        if (ud.subtype == 'connected-texture' or ud.subtype == 'texfixture') then
                            fixtures.destroyFixture(f)
                        end
                    end
                end

                for k2, v2 in pairs(v.appearance) do
                    --print(k2)
                    if k2 == 'skin' then
                        local body = relevant.body
                        local cx, cy, w, h = getCenterAndDimensions(body)
                        local growfactor = 1.1
                        local fixture = fixtures.createSFixture(body, 0, 0, 'texfixture',
                            { width = w * growfactor, height = h * growfactor })
                        local ud = fixture:getUserData()
                        ud.extra.OMP = true --it.OMP
                        ud.extra.dirty = true
                        ud.extra.main = utils.deepCopy(v2.main)
                        ud.extra.main.bgURL = v.shape8URL
                        ud.extra.main.fgURL = v.shape8URL:gsub('.png', '-mask.png')

                        if v.dims.sy ~= nil and v.dims.sy < 0 then
                            ud.extra.main.fy = -1
                        end
                        if v.dims.sx ~= nil and v.dims.sx < 0 then
                            ud.extra.main.fx = -1
                        end

                        if v2.patch1 then
                            ud.extra.patch1 = utils.deepCopy(v2.patch1)
                        end
                        if v2.patch2 then
                            ud.extra.patch2 = utils.deepCopy(v2.patch2)
                        end
                        if v2.patch3 then
                            ud.extra.patch3 = utils.deepCopy(v2.patch3)
                        end
                    elseif k2 == 'bodyhair' then
                        local body = relevant.body
                        local cx, cy, w, h = getCenterAndDimensions(body)
                        local growfactor = 1.1
                        local fixture = fixtures.createSFixture(body, 0, 0, 'texfixture',
                            { width = w * growfactor, height = h * growfactor })
                        local ud = fixture:getUserData()
                        ud.extra.OMP = false --it.OMP
                        ud.extra.zOffset = 40
                        ud.extra.dirty = true
                        ud.extra.main = utils.deepCopy(v2.main)

                        local raw = shape8Dict[v.shape8URL].v
                        local growfactor = 1.5
                        local vertices = makeTransformedVertices(raw, (v.dims.sx or 1) * growfactor,
                            (v.dims.sy or 1) * growfactor)

                        ud.extra.vertices = vertices
                        ud.extra.vertexCount = #vertices / 2
                    elseif k2 == 'connected-skin' or k2 == 'connected-hair' then
                        local body = relevant.body
                        print(k)
                        --print(k, v2.endNode)
                        -- depending on the start and end node. build the jointlabels
                        local torsoSegments = instance.dna.creation.torsoSegments or 1
                        local jointLabels = {}

                        local fixture = fixtures.createSFixture(body, 0, 0, 'connected-texture',
                            { radius = 30 })

                        local ud = fixture:getUserData()

                        ud.extra = {
                            attachTo = k,
                            OMP = (k2 == 'connected-skin'),
                            dirty = true,
                            main = utils.deepCopy(v2.main),
                            zOffset = v2.zOffset or 0,
                            nodes = {}
                        }
                        if k:find('uleg') then
                            --print('this is an upper-leg, connect to torso1')
                            if k == 'luleg' then
                                jointLabels = { "torso1->luleg", "luleg->llleg", "llleg->lfoot" }
                            elseif k == 'ruleg' then
                                jointLabels = { "torso1->ruleg", "ruleg->rlleg", "rlleg->rfoot" }
                            end
                        end
                        if k:find('uarm') then
                            local top = 'torso' .. torsoSegments

                            --print('this is an upper-leg, connect to torso1')
                            if k == 'luarm' then
                                jointLabels = { top .. "->luarm", "luarm->llarm", "llarm->lhand" }
                            elseif k == 'ruarm' then
                                jointLabels = { top .. "->ruarm", "ruarm->rlarm", "rlarm->rhand" }
                            end
                        end
                        -- we only do neck stuff from the top torso to the head. (other torso segments are ignored)
                        if k == ('torso' .. torsoSegments) and v2.endNode == 'head' then
                            local neckSegments = instance.dna.creation.neckSegments or 0
                            local previous = 'torso' .. torsoSegments

                            for i = 1, neckSegments do
                                local current = 'neck' .. i
                                table.insert(jointLabels, previous .. '->' .. current)
                                previous = current
                            end
                            -- Final connection to head
                            table.insert(jointLabels, previous .. '->head')
                            --logger:inspect(jointLabels)

                            print('this is about texturing the neck')
                        end
                        for j = 1, #jointLabels do
                            local jointID = jointLabels[j]
                            ud.extra.nodes[j] = { id = instance.joints[jointID], type = 'joint' }
                        end
                    end
                end
                -- here we do stuff.
                -- i think we should haev some kind of helper function that know depending on what the body tye is how we will add
                -- sfiuxture or connected fixture etc..
            end
        end
    end
end

-- function lib.addTextureFixturesFromInstance(instance)
--     function removeSimilarFixture(body, it)
--         local allFixtures = body:getFixtures()
--         for fi = #allFixtures, 1, -1 do -- backwards to safely remove
--             local f = allFixtures[fi]
--             local ud = f:getUserData()
--             --  logger:inspect(ud)
--             --if ud then
--             --    print(ud.label, it.label, ud and ud.label == it.label, ud.extra.OMP == it.OMP)
--             --end
--             if ud and ud.extra.OMP == it.OMP then
--                 --logger:info('destroying fixture')
--                 fixtures.destroyFixture(f)
--             end
--         end
--     end

--     for i = 1, #instance.textures do
--         local it = instance.textures[i]
--         --print(it.type, it.subtype)
--         if it.type == 'sfixture' then
--             if it.subtype == 'texfixture' then
--                 local body = instance.parts[it.attachTo].body
--                 removeSimilarFixture(body, it)
--                 --print("body angle at texture creation:", body:getAngle())
--                 local cx, cy, w, h = getCenterAndDimensions(body)
--                 -- local localX, localY = body:getLocalPoint(wx, wy)
--                 local growfactor = 1.1
--                 local fixture = fixtures.createSFixture(body, 0, 0, 'texfixture',
--                     { width = w * growfactor, height = h * growfactor })
--                 local ud = fixture:getUserData()
--                 ud.extra.OMP = it.OMP
--                 ud.extra.dirty = true
--                 ud.extra.main = utils.deepCopy(it.main)

--                 ud.extra.zOffset = it.zOffset or 0
--                 ud.extra.attachTo = it.attachTo
--                 local partData = instance.dna.parts[it.attachTo]

--                 -- todo we probably also need to flip the other ones (patch1..3) but not sure..
--                 if partData.dims.sy ~= nil and partData.dims.sy < 0 then
--                     ud.extra.main.fy = -1
--                 end
--                 if partData.dims.sx ~= nil and partData.dims.sx < 0 then
--                     ud.extra.main.fx = -1
--                 end

--                 if it.patch1 then
--                     ud.extra.patch1 = utils.deepCopy(it.patch1)
--                 end
--                 if it.patch2 then
--                     ud.extra.patch2 = utils.deepCopy(it.patch2)
--                 end
--                 if it.patch3 then
--                     ud.extra.patch3 = utils.deepCopy(it.patch3)
--                 end
--                 if it.followShape8 then
--                     ud.extra.followShape8 = it.followShape8
--                     -- logger:inspect(ud.extra)
--                     --  logger:inspect(it.followShape8)
--                     --print(it.followShape8)
--                     local raw = shape8Dict[it.followShape8].v
--                     local partData = instance.dna.parts[it.attachTo]
--                     local growfactor = 1.5
--                     local vertices = makeTransformedVertices(raw, (partData.dims.sx or 1) * growfactor,
--                         (partData.dims.sy or 1) * growfactor)


--                     ud.extra.vertices = vertices
--                     ud.extra.vertexCount = #vertices / 2
--                     -- logger:info('found a follo8')
--                     --  logger:inspect(ud.extra)
--                 end
--                 -- followShape8 = 'shapeA3.png',


--                 --logger:info('texgisture to add:')
--             end

--             if it.subtype == 'connected-texture' then
--                 --print('got some stuff todo')
--                 -- print(it.attachTo)
--                 local body = instance.parts[it.attachTo].body

--                 -- REMOVE OLD CONNECTED-TEXTURE FIXTURES FIRST
--                 removeSimilarFixture(body, it)

--                 local fixture = fixtures.createSFixture(body, 0, 0, 'connected-texture',
--                     { radius = 30 })
--                 local ud = fixture:getUserData()
--                 ud.extra = {
--                     attachTo = it.attachTo,
--                     OMP = it.OMP,                   -- we will just alays use OUTLINE/ MASK / PATTERN TEXTURES for characters.
--                     dirty = true,                   -- because the rendered needs to pick this up.
--                     main = utils.deepCopy(it.main), -- this is still missing a lot but that will be defaulted
--                     zOffset = it.zOffset or 0,
--                     nodes = {

--                     }

--                 }
--                 for j = 1, #it.jointLabels do
--                     local jointID = it.jointLabels[j]
--                     -- print(jointID)
--                     ud.extra.nodes[j] = { id = instance.joints[jointID], type = 'joint' }
--                     --print(instance.joints[jointID])
--                 end
--             end
--         end
--     end
-- end

-- function lib.updateTextureGroupValue(instance, group, key, value)
--     for i = 1, #instance.textures do
--         local t = instance.textures[i]
--         if t.group == group and t.main then
--             t.main[key] = value
--             --logger:info('setting', key, value)
--         end
--     end
-- end

-- function lib.updateTextureGroupValueInRoot(instance, group, key, value)
--     for i = 1, #instance.textures do
--         local t = instance.textures[i]
--         if t.group == group then
--             t[key] = value
--             -- logger:info('setting', key, value)
--         end
--     end
-- end

function lib.createCharacterFromExistingDNA(instance, x, y, optionalTorsoAngle)
    -- same logic as in createCharacter, but uses `instance.dna` and skips the `deepCopy`
    -- rebuilds the ordered list, generates torso/neck segments, limbs, etc.
    --
    local isPotato = instance.dna.creation.isPotatoHead
    local hasNeck = instance.dna.creation.neckSegments > 0
    local ordered = {}

    local torsoSegments = instance.dna.creation.torsoSegments or 1 -- Default to 1 torso segment
    -- 1. Add Torso Segments
    logger:info('createCharacterFromExistingDNA', torsoSegments)
    for i = 1, torsoSegments do
        local partName = 'torso' .. i
        table.insert(ordered, partName)
        -- Copy template DNA for this segment if it doesn't exist (it shouldn't)
        if not instance.dna.parts[partName] then
            -- Ensure template exists
            if not instance.dna.parts['torso-segment-template'] then
                error("Missing 'torso-segment-template' in DNA for template: " .. template)
            end

            instance.dna.parts[partName] = utils.deepCopy(instance.dna.parts['torso-segment-template'])

            -- if we have multiple torso parts i want to remove the data that is about neck.
            -- only the topmost torso may have that data.

            -- if i ~= torsoSegments then
            --     instance.dna.parts[partName].appearance['connected-skin'] = nil
            --     print('removed unneeded nexk texture data from a torso segemnt')
            -- end

            -- Optional: Modify dimensions/properties of specific segments here if needed
            -- e.g., make torso1 wider (pelvis) or torsoN narrower (shoulders)
            --instance.dna.parts[partName].dims.w = i * 100
            --logger:inspect(instance.dna.parts[partName])
            --  instance.dna.parts[partName].dims.w = ((torsoSegments + 1) - i) * 100
        end
    end

    if hasNeck and not isPotato then
        for i = 1, (instance.dna.creation.neckSegments or 2) do
            table.insert(ordered, 'neck' .. i)
            instance.dna.parts['neck' .. i] = utils.deepCopy(instance.dna.parts['neck-segment-template'])
        end
    end
    if not isPotato then
        table.insert(ordered, 'head')
    end
    -- Common limbs
    local limbs = {
        'luleg', 'ruleg', 'llleg', 'rlleg', 'lfoot', 'rfoot',
        'luarm', 'ruarm', 'llarm', 'rlarm', 'lhand', 'rhand',
        'lear', 'rear'
    }
    for _, part in ipairs(limbs) do table.insert(ordered, part) end


    for i = 1, #ordered do
        local partName = ordered[i]
        local partData = instance.dna.parts[partName]
        --logger:info(partName, partData.shapeName)
        local settings = {
            x = x,
            y = y,
            bodyType = 'dynamic',       -- Start as dynamic, will be adjusted later if inactive
            shapeType = partData.shape, -- Use shape defined in template
            shape8URL = partData.shape8URL,
            label = partName,           --partName,           -- Use part name as initial label
            density = partData.density or 1,
            radius = partData.dims.r,
            width = partData.dims.w,
            width2 = partData.dims.w2,
            width3 = partData.dims.w2,
            height = partData.dims.h,
            height2 = partData.dims.h,
            height3 = partData.dims.h,
            height4 = partData.dims.h,

            -- Add other physics properties if needed (friction, restitution?)
        }

        if (partData.shape8URL) then
            if (shape8Dict[partData.shape8URL]) then
                local raw = shape8Dict[partData.shape8URL].v
                settings.vertices = makeTransformedVertices(raw, partData.dims.sx or 1, partData.dims.sy or 1)
            end
        end
        --logger:info('getting offset for ', partName)



        makePart(partName, instance, settings)
        if optionalTorsoAngle and partName == 'torso1' then
            instance.parts['torso1'].body:setAngle(optionalTorsoAngle)
        end
    end


    -- here we will build up the sfixtures we need.
    --logger:info('calling defaultSetupTextures')


    lib.addTexturesFromInstance2(instance)
    --logger:info('calling addTextureFixturesFromInstance')
    return instance
end

function lib.createCharacter(template, x, y)
    if dna[template] then
        local instance = {
            id = uuid.generateID(),
            templateName = template,
            dna = utils.deepCopy(dna[template]), -- Copy template data for potential instance modification
            parts = {},                          -- { [partName] = thingObject, ... }
            joints = {},                         -- unused...{ [connectionName] = jointObject, ... }
            --appearanceValues = {},               -- Will hold visual overrides (implement later)
            -- Add other instance-specific state if needed
            textures = {},   -- here we will keep the data about what texture will go where (simple textures and connected textures)
            positioners = {} -- here we will have some lerp values describing how things are positioned..
        }
        return lib.createCharacterFromExistingDNA(instance, x, y)
    end
end

return lib

```

src//editor-render.lua
```lua
-- here we just have snall functions that render thigns for the editor (not ui but active state, selction boxes that sot of thing)
--
local state = require 'src.state'
local fixtures = require 'src.fixtures'
local box2dDraw = require 'src.box2d-draw'
local shapes = require 'src.shapes'
local mathutils = require 'src.math-utils'
local camera = require 'src.camera'
local cam = camera.getInstance()
local utils = require 'src.utils'

local lib = {}


function lib.drawGrid()
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, .1)

    local w, h = love.graphics.getDimensions()
    local tlx, tly = cam:getWorldCoordinates(0, 0)
    local brx, bry = cam:getWorldCoordinates(w, h)
    local step = state.world.meter
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

function lib.renderActiveEditorThings()
    if state.selection.selectedSFixture and not state.selection.selectedSFixture:isDestroyed() then
        local body = state.selection.selectedSFixture:getBody()
        local centroid = fixtures.getCentroidOfFixture(body, state.selection.selectedSFixture)
        local x2, y2 = body:getWorldPoint(centroid[1], centroid[2])
        love.graphics.circle('line', x2, y2, 3)
    end

    if state.selection.selectedJoint and not state.selection.selectedJoint:isDestroyed() then
        box2dDraw.drawJointAnchors(state.selection.selectedJoint)
    end

    local lw = love.graphics.getLineWidth()
    for i, v in ipairs(state.world.softbodies) do
        love.graphics.setColor(50 * i / 255, 100 / 255, 200 * i / 255, .8)
        if (tostring(v) == "softbody") then
            love.graphics.setColor(50 * i / 255, 100 / 255, 200 * i / 255, .8)
            --v:draw("fill", false)
            love.graphics.setColor(50 * i / 255, 255 / 255, 200 * i / 255, .8)
            local polygon = v:getPoly()
            local tris = shapes.makeTrianglesFromPolygon(polygon)
            for i = 1, #tris do
                love.graphics.polygon('fill', tris[i])
            end
        else
            --v:draw(false)
            local polygon = v:getPoly()
            local tris = shapes.makeTrianglesFromPolygon(polygon)
            for i = 1, #tris do
                love.graphics.polygon('fill', tris[i])
            end
        end
    end
    love.graphics.setLineWidth(lw)
    love.graphics.setColor(1, 1, 1)

    -- draw to be drawn polygon
    if state.currentMode == 'drawClickMode' or state.currentMode == 'drawFreePoly' then
        if (#state.interaction.polyVerts >= 6) then
            love.graphics.polygon('line', state.interaction.polyVerts)
        end
    end


    -- draw mousehandlers for dragging vertices
    if state.polyEdit.tempVerts and state.selection.selectedObj and state.selection.selectedObj.shapeType == 'custom' and state.polyEdit.lockedVerts == false then
        local verts = mathutils.getLocalVerticesForCustomSelected(state.polyEdit.tempVerts,
            state.selection.selectedObj, state.polyEdit.centroid.x, state.polyEdit.centroid.y)

        local mx, my = love.mouse:getPosition()
        local cx, cy = cam:getWorldCoordinates(mx, my)

        for i = 1, #verts, 2 do
            local vx = verts[i]
            local vy = verts[i + 1]
            local dist = math.sqrt((cx - vx) ^ 2 + (cy - vy) ^ 2)
            if dist < 10 then
                love.graphics.setColor(0, 0, 0)
                love.graphics.circle('fill', vx, vy, 13)
                love.graphics.setColor(1, 1, 1)
                love.graphics.circle('fill', vx, vy, 11)
            else
                love.graphics.setColor(0, 0, 0)
                love.graphics.circle('line', vx, vy, 12)
                love.graphics.setColor(1, 1, 1)
                love.graphics.circle('line', vx, vy, 10)
            end
        end
    end


    if state.texFixtureEdit.tempVerts and state.selection.selectedSFixture and state.texFixtureEdit.lockedVerts == false then
        local thing     = state.selection.selectedSFixture:getBody():getUserData().thing

        local fixtureUD = state.selection.selectedSFixture:getUserData()
        local isMeta8   = fixtureUD.label == 'meta8'
        local verts     = mathutils.getLocalVerticesForCustomSelected(state.texFixtureEdit.tempVerts,
            thing, 0, 0)
        --print(inspect(verts))
        local mx, my    = love.mouse:getPosition()
        local cx, cy    = cam:getWorldCoordinates(mx, my)
        logger:inspect(fixtureUD)
        for i = 1, #verts, 2 do
            local vx = verts[i]
            local vy = verts[i + 1]
            local dist = math.sqrt((cx - vx) ^ 2 + (cy - vy) ^ 2)
            if dist < 10 then
                love.graphics.setColor(0, 0, 0)
                love.graphics.circle('fill', vx, vy, 13)
                love.graphics.setColor(1, 1, 1)
                love.graphics.circle('fill', vx, vy, 11)
            else
                love.graphics.setColor(0, 0, 0)
                love.graphics.circle('line', vx, vy, 12)
                love.graphics.setColor(1, 1, 1)
                love.graphics.circle('line', vx, vy, 10)

                if (isMeta8) then
                    love.graphics.setColor(0, 0, 0)
                    love.graphics.print(math.ceil(i / 2), vx, vy)
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.print(math.ceil(i / 2), vx - 2, vy - 2)
                end
            end
        end

        if (isMeta8) then
            -- index 1 -> 5
            love.graphics.line(verts[1 * 2 - 1], verts[1 * 2 - 0], verts[5 * 2 - 1], verts[5 * 2 - 0])
            -- index 2 -> 8
            love.graphics.line(verts[2 * 2 - 1], verts[2 * 2 - 0], verts[8 * 2 - 1], verts[8 * 2 - 0])
            -- index 3 -> 7
            love.graphics.line(verts[3 * 2 - 1], verts[3 * 2 - 0], verts[7 * 2 - 1], verts[7 * 2 - 0])
            -- index 4 -> 6
            love.graphics.line(verts[4 * 2 - 1], verts[4 * 2 - 0], verts[6 * 2 - 1], verts[6 * 2 - 0])
        end
    end

    -- Highlight selected bodies
    if state.selection.selectedBodies then
        local bodies = utils.map(state.selection.selectedBodies, function(thing)
            return thing.body
        end)
        box2dDraw.drawBodies(bodies)
    end

    -- draw temp poly when changing vertices
    if state.polyEdit.tempVerts and state.selection.selectedObj then
        local verts = mathutils.getLocalVerticesForCustomSelected(state.polyEdit.tempVerts,
            state.selection.selectedObj, state.polyEdit.centroid.x, state.polyEdit.centroid.y)
        love.graphics.setColor(1, 0, 0)
        love.graphics.polygon('line', verts)
        love.graphics.setColor(1, 1, 1) -- Rese
    end
end

return lib

```

src//file-browser.lua
```lua
-- this thing needs to be able to show files visually, lets start with just showing the filetype im after given a subdir.

local lib = {}


function lib:loadFiles(path, filterrules)
    local all_items = love.filesystem.getDirectoryItems(path)
    local filtered = {}
    for _, item in ipairs(all_items) do

        local info = love.filesystem.getInfo(path..'/'..item)
        if info and (info.type == "file") then
            local ok = true
            if filterrules then
                if filterrules.includes then
                    local str = item
                    local index = string.find(str, filterrules.includes)
                    if not index  then
                        ok = false
                    end
                end
                if filterrules.excludes then
                    local str = item
                    local index = string.find(str, filterrules.excludes)
                    if index then
                        ok = false
                    end
                end
            end

            if ok then
                table.insert(filtered, {info=info, path=path, item=item})
            end

        end
       -- count = count + 1
    end

    for i= 1, #filtered do
        print(filtered[i].item)
    end

    logger:info('count:',#filtered)
    -- Apply current search_query to filter files
    --self:filterFiles()

    -- Adjust scroll_offset and selected_index if necessary
    --if self.scroll_offset > 0 and (self.scroll_offset + self.max_display_items) > #self.filtered_files then
    --    self.scroll_offset = math.max(0, #self.filtered_files - self.max_display_items)
    --    self.selected_index = math.min(self.selected_index, #self.filtered_files)
    --end
end

return lib

```

src//fixtures.lua
```lua
--fixtures.lua


local mathutils = require 'src.math-utils'
local uuid = require 'src.uuid'

local registry = require 'src.registry'
local utils = require 'src.utils' -- Needed for shallowCopy
local state = require 'src.state'
local lib = {}


-- Updates the position of an sfixture based on a new WORLD coordinate click
function lib.updateSFixturePosition(sfixture, worldX, worldY)
    if not sfixture or sfixture:isDestroyed() then
        logger:error("WARN: updateSFixturePosition called on invalid sfixture"); return nil
    end

    local body = sfixture:getBody()
    if not body or body:isDestroyed() then
        logger:error("WARN: updateSFixturePosition called on sfixture with invalid body"); return nil
    end

    -- Convert world click to body's local coordinates for the new shape center
    local localX, localY = body:getLocalPoint(worldX, worldY)
    local oldUD = utils.deepCopy(sfixture:getUserData())
    --  logger:info(oldUD.extra.vertices ,  { sfixture:getShape():getPoints() })
    local points = oldUD.extra.vertices or
        { sfixture:getShape():getPoints() } -- Existing local points
    local centerX, centerY = mathutils.getCenterOfPoints(points)

    local relativePoints = mathutils.makePolygonRelativeToCenter(points, centerX, centerY) -- Points relative to old center

    -- Create new absolute points centered at the *new* local click position
    local newShapePoints = mathutils.makePolygonAbsolute(relativePoints, localX, localY)

    local dx, dy = centerX - localX, centerY - localY

    -- Use deepCopy if 'extra' might contain tables

    if oldUD.extra and oldUD.extra.vertices then
        -- logger:info('vertices found, need to adjust all of them:',#oldUD.extra.vertices,dx,dy)
        -- logger:info(inspect(oldUD.extra.vertices))
        for i = 1, #oldUD.extra.vertices, 2 do
            oldUD.extra.vertices[i + 0] = oldUD.extra.vertices[i + 0] - dx
            oldUD.extra.vertices[i + 1] = oldUD.extra.vertices[i + 1] - dy
        end
        --  logger:info(inspect(oldUD.extra.vertices))
    end
    local fixtureID = oldUD.id                   -- Keep the ID
    local fixtureDensity = sfixture:getDensity() -- Keep properties
    local fixtureFriction = sfixture:getFriction()
    local fixtureRestitution = sfixture:getRestitution()
    local fixtureGroupIndex = sfixture:getGroupIndex()

    -- logger:info(string.format("Updating SFixture %s Position to World(%.2f, %.2f) -> Local(%.2f, %.2f)", fixtureID,
    --     worldX,
    --     worldY, localX, localY))

    -- Destroy old fixture and unregister
    sfixture:destroy()
    registry.unregisterSFixture(fixtureID)

    -- Create the new shape and fixture
    local shape = love.physics.newPolygonShape(newShapePoints)
    local newfixture = love.physics.newFixture(body, shape, fixtureDensity)
    newfixture:setSensor(true) -- Ensure it remains a sensor
    newfixture:setFriction(fixtureFriction)
    newfixture:setRestitution(fixtureRestitution)
    newfixture:setGroupIndex(fixtureGroupIndex)
    newfixture:setUserData(oldUD)                    -- Reuse the userdata (including the ID)

    registry.registerSFixture(fixtureID, newfixture) -- Register the new fixture with the *same* ID

    return newfixture
end

function lib.hasFixturesWithUserDataAtBeginning(fixtures)
    -- first we will start looking from beginning untill we no longer find userdata on fixtures
    -- then we will start looking fom that index on and expect not to found any more userdata
    local found = true
    local index = 0
    for i = 1, #fixtures do
        if found then
            if fixtures[i]:getUserData() then
                index = i
            else
                found = false
            end
        end
        if not found then
            if fixtures[i]:getUserData() then
                return false, -1
            else

            end
        end
    end
    return true, index
end

function lib.getCentroidOfFixture(body, fixture)
    return { mathutils.getCenterOfPoints({ fixture:getShape():getPoints() }) }
end

local function rect(w, h, x, y)
    return {
        x - w / 2, y - h / 2,
        x + w / 2, y - h / 2,
        x + w / 2, y + h / 2,
        x - w / 2, y + h / 2
    }
end

local function rect8(w, h, x, y)
    return {
        x - w / 2, y - h / 2,
        x, y - h / 2,
        x + w / 2, y - h / 2,
        x + w / 2, y,
        x + w / 2, y + h / 2,
        x, y + h / 2,
        x - w / 2, y + h / 2,
        x - w / 2, y,
    }
end



function lib.destroyFixture(fixture)
    registry.unregisterSFixture(fixture:getUserData().id)
    fixture:destroy()
end

function lib.updateSFixtureDimensionsFunc(w, h)
    local points = { state.selection.selectedSFixture:getShape():getPoints() }
    local oldUD = utils.shallowCopy(state.selection.selectedSFixture:getUserData())
    local body = state.selection.selectedSFixture:getBody()
    state.selection.selectedSFixture:destroy()

    local centerX, centerY = mathutils.getCenterOfPoints(points)
    local vv = oldUD.extra.vertexCount == 8 and rect8(w, h, centerX, centerY) or rect(w, h, centerX, centerY)
    local shape = love.physics.newPolygonShape(vv)
    local newfixture = love.physics.newFixture(body, shape)
    oldUD.extra.vertices = vv
    newfixture:setSensor(true) -- Sensor so it doesn't collide
    newfixture:setUserData(oldUD)

    state.selection.selectedSFixture = newfixture
    --snap.updateFixture(newfixture)
    registry.registerSFixture(oldUD.id, newfixture)

    return newfixture
end

function lib.createSFixture(body, localX, localY, subtype, cfg)
    if (subtype == 'snap') then
        local shape = love.physics.newPolygonShape(rect(cfg.radius * 5, cfg.radius * 5, localX, localY))
        local fixture = love.physics.newFixture(body, shape)
        fixture:setSensor(true) -- Sensor so it doesn't collide
        local setId = uuid.generateID()
        fixture:setUserData({ type = "sfixture", subtype = 'snap', id = setId, label = '', extra = {} })
        registry.registerSFixture(setId, fixture)
        return fixture
    end
    if (subtype == 'anchor') then
        local shape = love.physics.newPolygonShape(rect(cfg.radius, cfg.radius, localX, localY))
        local fixture = love.physics.newFixture(body, shape)
        fixture:setSensor(true) -- Sensor so it doesn't collide
        local setId = uuid.generateID()
        fixture:setUserData({ type = "sfixture", subtype = 'anchor', id = setId, label = '', extra = {} })
        registry.registerSFixture(setId, fixture)
        return fixture
    end
    if (subtype == 'connected-texture') then
        local shape = love.physics.newPolygonShape(rect(cfg.radius, cfg.radius, localX, localY))
        local fixture = love.physics.newFixture(body, shape)
        fixture:setSensor(true) -- Sensor so it doesn't collide
        local setId = uuid.generateID()
        fixture:setUserData({ type = "sfixture", subtype = 'connected-texture', id = setId, label = '', extra = {} })
        registry.registerSFixture(setId, fixture)
        return fixture
    end
    if (subtype == 'trace-vertices') then
        local shape = love.physics.newPolygonShape(rect(cfg.radius, cfg.radius, localX, localY))
        local fixture = love.physics.newFixture(body, shape)
        fixture:setSensor(true) -- Sensor so it doesn't collide
        local setId = uuid.generateID()
        fixture:setUserData({ type = "sfixture", subtype = 'trace-vertices', id = setId, label = '', extra = {} })
        registry.registerSFixture(setId, fixture)
        return fixture
    end
    if (subtype == 'tile-repeat') then
        local shape = love.physics.newPolygonShape(rect(cfg.radius, cfg.radius, localX, localY))
        local fixture = love.physics.newFixture(body, shape)
        fixture:setSensor(true) -- Sensor so it doesn't collide
        local setId = uuid.generateID()
        fixture:setUserData({ type = "sfixture", subtype = 'tile-repeat', id = setId, label = '', extra = {} })
        registry.registerSFixture(setId, fixture)
        return fixture
    end
    if (subtype == 'texfixture') then
        local vertexCount = 4
        local vv = vertexCount == 4 and rect(cfg.width, cfg.height, localX, localY) or
            rect8(cfg.width, cfg.height, localX, localY)
        local shape = love.physics.newPolygonShape(vv)
        local fixture = love.physics.newFixture(body, shape, 0)
        fixture:setSensor(true)  -- Sensor so it doesn't collide
        local setId = uuid.generateID()
        fixture:setUserData({ type = "sfixture", id = setId, subtype = 'texfixture', label = '', extra = { vertexCount = vertexCount, vertices = vv } })
        registry.registerSFixture(setId, fixture)
        return fixture
    end
    logger:info('I NEED A BETTER CONFIG FOR THIS FIXTURE OF YOURS!', inspect(cfg))
end

--function lib.createTexFixtureShape(vertexCount)

return lib

```

src//input-manager.lua
```lua
local lib = {}
local camera = require 'src.camera'
local cam = camera.getInstance()
local box2dPointerJoints = require 'src.box2d-pointerjoints'
local mathutils = require 'src.math-utils'
local recorder = require 'src.recorder'
local utils = require 'src.utils'
local script = require 'src.script'
local selectrect = require 'src.selection-rect'
local objectManager = require 'src.object-manager'
local state = require 'src.state'
local blob = require 'vendor.loveblobs'
local ui = require 'src.ui-all'
local fixtures = require 'src.fixtures'
local joints = require 'src.joints'

local distanceSquared = function(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    --local distance = math.sqrt(dx * dx + dy * dy)
    return dx * dx + dy * dy
end

local function handlePointer(x, y, id, action)
    if action == "pressed" then
        -- Handle press logig
        --   -- this will block interacting on bodies when 'roughly' over the opened panel
        if state.panelVisibility.saveDialogOpened then return end
        if state.panelVisibility.showPalette then
            local w, h = love.graphics.getDimensions()
            if y < h - 400 or x > w - 300 then
                state.panelVisibility.showPalette = nil
                return
            else
                return
            end
        end
        if state.selection.selectedJoint or state.selection.selectedObj or state.selection.selectedSFixture or state.selection.selectedBodies
            or state.currentMode == 'drawFreePoly' or state.currentMode == 'drawClickPoly' then
            local w, h = love.graphics.getDimensions()
            if x > w - 300 then
                return
            end
        end

        local startSelection = love.keyboard.isDown('lshift')
        if (startSelection) then
            state.interaction.startSelection = { x = x, y = y }
        end

        local cx, cy = cam:getWorldCoordinates(x, y)

        if state.polyEdit.tempVerts and state.selection.selectedObj and state.selection.selectedObj.shapeType == 'custom' and state.polyEdit.lockedVerts == false then
            local verts = mathutils.getLocalVerticesForCustomSelected(state.polyEdit.tempVerts,
                state.selection.selectedObj, state.polyEdit.centroid.x, state.polyEdit.centroid.y)
            for i = 1, #verts, 2 do
                local vx = verts[i]
                local vy = verts[i + 1]
                local dist = math.sqrt((cx - vx) ^ 2 + (cy - vy) ^ 2)
                if dist < 10 then
                    state.polyEdit.dragIdx = i

                    return
                else
                    state.polyEdit.dragIdx = 0
                end
            end
        end

        if state.texFixtureEdit.tempVerts and state.selection.selectedSFixture and state.texFixtureEdit.lockedVerts == false then
            --local verts = mathutils.getLocalVerticesForCustomSelected(state.polyEdit.tempVerts,
            --    state.selection.selectedObj, state.polyEdit.centroid.x, state.polyEdit.centroid.y)
            local thing = state.selection.selectedSFixture:getBody():getUserData().thing
            local verts = mathutils.getLocalVerticesForCustomSelected(state.texFixtureEdit.tempVerts,
                thing, 0, 0)

            for i = 1, #verts, 2 do
                local vx = verts[i]
                local vy = verts[i + 1]
                local dist = math.sqrt((cx - vx) ^ 2 + (cy - vy) ^ 2)
                if dist < 10 then
                    state.texFixtureEdit.dragIdx = i
                    return
                else
                    state.texFixtureEdit.dragIdx = 0
                end
            end
        end

        if (state.currentMode == 'drawClickMode') then
            local w, h = love.graphics.getDimensions()
            if x < w - 300 then
                table.insert(state.interaction.polyVerts, cx)
                table.insert(state.interaction.polyVerts, cy)
            end
        end

        if (state.currentMode == 'setOffsetA') then
            local bodyA, bodyB = state.selection.selectedJoint:getBodies()
            local fx, fy = mathutils.rotatePoint(cx - bodyA:getX(), cy - bodyA:getY(), 0, 0, -bodyA:getAngle())
            state.selection.selectedJoint = joints.updateJointOffsetA(state.selection.selectedJoint, fx, fy) --state.interaction.setOffsetAFunc(cx, cy)
            --state.interaction.setOffsetAFunc = nil
            state.currentMode = nil
        end

        if (state.currentMode == 'setOffsetB') then
            local bodyA, bodyB = state.selection.selectedJoint:getBodies()
            local fx, fy = mathutils.rotatePoint(cx - bodyB:getX(), cy - bodyB:getY(), 0, 0, -bodyB:getAngle())

            state.selection.selectedJoint = joints.updateJointOffsetB(state.selection.selectedJoint, fx, fy) --state.interaction.setOffsetAFunc(cx, cy)
            --state.interaction.setOffsetAFunc = nil
            state.currentMode = nil
        end


        if (state.currentMode == 'positioningSFixture') then
            state.selection.selectedSFixture = fixtures.updateSFixturePosition(state.selection.selectedSFixture, cx, cy)
            local oldTexFixUD = state.selection.selectedSFixture:getUserData()

            if (oldTexFixUD.extra.vertices) then
                state.texFixtureEdit.tempVerts = utils.shallowCopy(oldTexFixUD.extra.vertices)
            end
            state.currentMode = nil
        end




        local onPressedParams = {
            pointerForceFunc = function(fixture)
                return state.world.mouseForce
            end,
            damp = state.world.mouseDamping
        }

        local _, hitted, madedata = box2dPointerJoints.handlePointerPressed(cx, cy, id, onPressedParams,
            not state.world.paused)

        if (state.selection.selectedBodies and #hitted == 0) then
            state.selection.selectedBodies = nil
        end


        if (state.currentMode == 'addNodeToConnectedTexture') then
            -- we need to walk trough all anchor fitures and all joints to see if im very close to one?
            --
            --
            --


            local closest = nil
            local closestDistanceSquared = math.huge
            for _, f in pairs(registry.sfixtures) do
                local body = f:getBody()
                local ud = f:getUserData()
                if ud.label == 'anchor' or ud.subtype == 'anchor' then
                    -- todo this will find ALL sfitures bot just anchors
                    local centerX, centerY = mathutils.getCenterOfPoints({ body:getWorldPoints(f:getShape():getPoints()) })

                    local d = distanceSquared(centerX, centerY, cx, cy)
                    if d < closestDistanceSquared then
                        closestDistanceSquared = d
                        closest = { type = 'anchor', id = f:getUserData().id }
                    end
                end
            end

            for _, j in pairs(registry.joints) do
                local x1, y1, x2, y2 = j:getAnchors()
                local d = distanceSquared(x1, y1, cx, cy)
                if d < closestDistanceSquared then
                    closestDistanceSquared = d
                    closest = { type = 'joint', id = j:getUserData().id }
                end
            end


            if math.sqrt(closestDistanceSquared) < 30 then
                --print(logger:info(math.sqrt(closestDistanceSquared)))

                local ud = state.selection.selectedSFixture:getUserData()
                ud.extra.nodes = ud.extra.nodes or {}

                local lastAdded = ud.extra.nodes[#ud.extra.nodes]
                --                logger:inspect(lastAdded)
                if (closest and lastAdded and lastAdded.id ~= closest.id) or not lastAdded then
                    table.insert(ud.extra.nodes, closest)
                end

                state.selection.selectedSFixture:setUserData(ud)
                --logger:inspect(state.selection.selectedSFixture:getUserData())
                return
            else
                state.currentMode = nil
                return
            end
        end




        if #hitted > 0 then
            local ud = hitted[1]:getBody():getUserData()
            if ud and ud.thing then
                state.selection.selectedObj = ud.thing
            end
            if state.scene.sceneScript and not state.world.paused and state.selection.selectedObj then
                state.selection.selectedObj = nil
            end
            if (state.currentMode == 'jointCreationMode') and state.selection.selectedObj then
                if #hitted == 2 and (state.jointParams.body1 == nil) and (state.jointParams.body2 == nil) then
                    -- if you click exactly where two bodies overlap,
                    -- picking the one whose center is closest to your click as body1.

                    local b1 = hitted[1]:getBody():getUserData().thing.body
                    local b2 = hitted[2]:getBody():getUserData().thing.body

                    local b1x, b1y = b1:getLocalPoint(cx, cy)
                    local b2x, b2y = b2:getLocalPoint(cx, cy)
                    -- todo i think a good compromise is to pick the body where the cx,cy is closst to its middel as the first,
                    -- this will result in the most usefull cases i think.
                    --logger:info('b1', px, py)
                    if (distanceSquared(b1x, b1y, 0, 0) < distanceSquared(b2x, b2y, 0, 0)) then
                        state.jointParams.body1 = b1
                        state.jointParams.body2 = b2
                        state.jointParams.p1 = { b1x, b1y }
                        state.jointParams.p2 = { b2x, b2y }
                    else
                        state.jointParams.body1 = b2
                        state.jointParams.body2 = b1
                        state.jointParams.p1 = { b2x, b2y }
                        state.jointParams.p2 = { b1x, b1y }
                    end
                else
                    if state.jointParams.body1 == nil then
                        state.jointParams.body1 = state.selection.selectedObj.body
                        local px, py = state.jointParams.body1:getLocalPoint(cx, cy)
                        state.jointParams.p1 = { px, py }
                    elseif state.jointParams.body2 == nil then
                        if (state.selection.selectedObj.body ~= state.jointParams.body1) then
                            state.jointParams.body2 = state.selection.selectedObj.body
                            local px, py = state.jointParams.body2:getLocalPoint(cx, cy)
                            state.jointParams.p2 = { px, py }
                        end
                    end
                end
            end

            if (state.world.paused) then
                state.interaction.draggingObj = state.selection.selectedObj
                if state.selection.selectedObj then
                    local offx, offy = state.selection.selectedObj.body:getLocalPoint(cx, cy)
                    state.interaction.offsetDragging = { -offx, -offy }
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
            --state.interaction.maybeHideSelectedPanel = true
            state.interaction.pressMissedEverything = true
        end
        if recorder.isRecording and #hitted > 0 and not state.world.paused and madedata.bodyID then
            --madedata.activeLayer = recorder.activeLayer
            recorder:recordMouseJointStart(madedata)
            -- print('should record a moujoint creation...', inspect(madedata))
        end
    elseif action == "released" then
        -- Handle release logic
        local releasedObjs = box2dPointerJoints.handlePointerReleased(x, y, id)
        if (#releasedObjs > 0) then
            -- todo this line below can be erroring, i ve had it happen when dragging a chacter nd pressing N
            local newReleased = utils.map(releasedObjs, function(h) return h:getUserData() and h:getUserData().thing end)

            script.call('onReleased', newReleased)
            if recorder.isRecording and not state.world.paused then
                for _, obj in ipairs(releasedObjs) do
                    recorder:recordMouseJointFinish(id, obj:getUserData().thing.id)
                    --  print('should record a moujoint deletion...', inspect(obj:getUserData().thing.id))
                end
            end
        end


        if state.interaction.pressMissedEverything then
            local wasOverUI = ui.activeElementID or ui.focusedTextInputID or ui.overPanel
            if not wasOverUI then
                -- removed from main!
                if (state.selection.selectedSFixture and not state.selection.selectedSFixture:isDestroyed()) then
                    local body = state.selection.selectedSFixture:getBody()
                    local thing = body:getUserData().thing

                    state.selection.selectedObj = thing
                    state.selection.selectedSFixture = nil
                    state.texFixtureEdit.tempVerts = nil
                    state.texFixtureEdit.centroid = nil
                    state.texFixtureEdit.lockedVerts = true
                    state.interaction.maybeHideSelectedPanel = false
                elseif (state.selection.selectedJoint) then
                    state.selection.selectedJoint = nil
                    state.interaction.maybeHideSelectedPanel = false
                else
                    if not (ui.activeElementID or ui.focusedTextInputID) then
                        state.selection.selectedObj = nil
                        state.selection.selectedSFixture = nil
                        state.selection.selectedJoint = nil
                    end
                    state.interaction.maybeHideSelectedPanel = false
                    state.polyEdit.tempVerts = nil
                    state.polyEdit.lockedVerts = true
                end
                -- todo this is dumb..
                state.panelVisibility.addBehavior = false
                state.panelVisibility.customBehavior = false
                state.panelVisibility.addJointOpened = false
                state.panelVisibility.addShapeOpened = false
                state.panelVisibility.worldSettingsOpened = false
                state.panelVisibility.recordingPanelOpened = false
                state.panelVisibility.showPalette = false
            else

            end
        end
        state.interaction.pressMissedEverything = false

        if state.interaction.draggingObj then
            state.interaction.draggingObj.body:setAwake(true)
            state.selection.selectedObj = state.interaction.draggingObj
            state.interaction.draggingObj = nil
        end

        -- if we have released a mousebutton but it isnt nr1, then we keep on drawing free polygon
        if state.currentMode == 'drawFreePoly' and not love.mouse.isDown(1) then
            state.interaction.capturingPoly = false
            objectManager.finalizePolygon()
        end

        if state.polyEdit.dragIdx > 0 then
            state.polyEdit.dragIdx = 0
            objectManager.maybeUpdateCustomPolygonVertices()
        end

        if state.texFixtureEdit.dragIdx > 0 then
            state.texFixtureEdit.dragIdx = 0
            objectManager.maybeUpdateTexFixtureVertices()
        end

        if (state.interaction.startSelection) then
            local tlx = math.min(state.interaction.startSelection.x, x)
            local tly = math.min(state.interaction.startSelection.y, y)
            local brx = math.max(state.interaction.startSelection.x, x)
            local bry = math.max(state.interaction.startSelection.y, y)
            local tlxw, tlyw = cam:getWorldCoordinates(tlx, tly)
            local brxw, bryw = cam:getWorldCoordinates(brx, bry)
            local selected = selectrect.selectWithin(state.physicsWorld,
                { x = tlxw, y = tlyw, width = brxw - tlxw, height = bryw - tlyw })

            state.selection.selectedBodies = selected
            state.interaction.startSelection = nil
        end
    end
end

function lib.handleDraggingObj()
    local mx, my = love.mouse.getPosition()
    local wx, wy = cam:getWorldCoordinates(mx, my)
    local offx = state.interaction.offsetDragging[1]
    local offy = state.interaction.offsetDragging[2]
    local rx, ry = mathutils.rotatePoint(offx, offy, 0, 0, state.interaction.draggingObj.body:getAngle())
    local oldPosX, oldPosY = state.interaction.draggingObj.body:getPosition()
    state.interaction.draggingObj.body:setPosition(wx + rx, wy + ry)
    if recorder.isRecording then
        local ud = state.interaction.draggingObj.body:getUserData()

        recorder:recordObjectSetPosition(state.interaction.draggingObj.id, wx + rx, wy + ry)
    end
    -- figure out if we are dragging a group!
    if state.selection.selectedBodies then
        for i = 1, #state.selection.selectedBodies do
            if (state.selection.selectedBodies[i] == state.interaction.draggingObj) then
                local newPosX, newPosY = state.interaction.draggingObj.body:getPosition()
                local dx = newPosX - oldPosX
                local dy = newPosY - oldPosY
                for j = 1, #state.selection.selectedBodies do
                    if (state.selection.selectedBodies[j] ~= state.interaction.draggingObj) then
                        local oldPosX, oldPosY = state.selection.selectedBodies[j].body:getPosition()
                        state.selection.selectedBodies[j].body:setPosition(oldPosX + dx, oldPosY + dy)
                    end
                end
            end
        end
    end
end

function lib.handleMousePressed(x, y, button, istouch)
    if not istouch and button == 1 then
        if state.currentMode == 'drawFreePoly' then
            -- Start capturing mouse movement
            state.interaction.capturingPoly = true
            state.interaction.polyVerts = {}
            state.interaction.lastPolyPt = nil
        else
            handlePointer(x, y, 'mouse', 'pressed')
        end
    end

    if state.world.playWithSoftbodies and button == 2 then
        local cx, cy = cam:getWorldCoordinates(x, y)


        local b = blob.softbody(state.physicsWorld, cx, cy, 102, 1, 1)
        b:setFrequency(3)
        b:setDamping(0.1)

        table.insert(state.world.softbodies, b)
    end
end

function lib.handleTouchPressed(id, x, y, dx, dy, pressure)
    --handlePointer(x, y, id, 'pressed')
    if state.currentMode == 'drawFreePoly' then
        -- Start capturing mouse movement
        state.interaction.capturingPoly = true
        state.interaction.polyVerts = {}
        state.interaction.lastPolyPt = nil
    else
        handlePointer(x, y, id, 'pressed')
    end
end

function lib.handleMouseReleased(x, y, button, istouch)
    if not istouch then
        handlePointer(x, y, 'mouse', 'released')
    end
end

function lib.handleTouchReleased(id, x, y, dx, dy, pressure)
    handlePointer(x, y, id, 'released')
end

function lib.handleMouseMoved(x, y, dx, dy)
    --print('moved')
    if state.polyEdit.dragIdx and state.polyEdit.dragIdx > 0 then
        local index = state.polyEdit.dragIdx
        local obj = state.selection.selectedObj
        local angle = obj.body:getAngle()
        local dx2, dy2 = mathutils.rotatePoint(dx, dy, 0, 0, -angle)
        dx2 = dx2 / cam.scale
        dy2 = dy2 / cam.scale
        state.polyEdit.tempVerts[index] = state.polyEdit.tempVerts[index] + dx2
        state.polyEdit.tempVerts[index + 1] = state.polyEdit.tempVerts[index + 1] + dy2
    elseif state.texFixtureEdit.dragIdx and state.texFixtureEdit.dragIdx > 0 then
        local index = state.texFixtureEdit.dragIdx
        local obj = state.selection.selectedSFixture:getBody():getUserData().thing


        local angle = obj.body:getAngle()
        local dx2, dy2 = mathutils.rotatePoint(dx, dy, 0, 0, -angle)
        dx2 = dx2 / cam.scale
        dy2 = dy2 / cam.scale
        state.texFixtureEdit.tempVerts[index] = state.texFixtureEdit.tempVerts[index] + dx2
        state.texFixtureEdit.tempVerts[index + 1] = state.texFixtureEdit.tempVerts[index + 1] + dy2

        local ud = state.selection.selectedSFixture:getUserData()
        --logger:info(inspect(ud))
        ud.extra.vertices[index] = state.texFixtureEdit.tempVerts[index]
        ud.extra.vertices[index + 1] = state.texFixtureEdit.tempVerts[index + 1]
        state.selection.selectedSFixture:setUserData(ud)
        -- print(index)
    elseif state.interaction.capturingPoly and (state.currentMode == 'drawFreePoly' or state.currentMode == 'drawClickPoly') and (not (love.mouse.isDown(3) or love.mouse.isDown(2))) then
        local wx, wy = cam:getWorldCoordinates(x, y)
        -- Check if the distance from the last point is greater than minPointDistance
        local addPoint = false
        if not state.interaction.lastPolyPt then
            addPoint = true
        else
            local lastX, lastY = state.interaction.lastPolyPt.x, state.interaction.lastPolyPt.y
            local distSq = (wx - lastX) ^ 2 + (wy - lastY) ^ 2
            if distSq >= (state.editorPreferences.minPointDistance / cam.scale) ^ 2 then
                addPoint = true
            end
        end
        if addPoint then
            table.insert(state.interaction.polyVerts, wx)
            table.insert(state.interaction.polyVerts, wy)
            state.interaction.lastPolyPt = { x = wx, y = wy }
        end
    elseif love.mouse.isDown(3) or love.mouse.isDown(2) then
        local tx, ty = cam:getTranslation()
        cam:setTranslation(tx - dx / cam.scale, ty - dy / cam.scale)
    end
end

function lib.handleKeyPressed(key)
    if key == 'escape' then
        if state.panelVisibility.quitDialogOpened == true then
            love.event.quit()
        end
        if state.panelVisibility.quitDialogOpened == false then
            state.panelVisibility.quitDialogOpened = true
        end
    end
    if key == 'space' then
        if state.panelVisibility.quitDialogOpened == true then
            state.panelVisibility.quitDialogOpened = false
        else
            state.world.paused = not state.world.paused
            if recorder.isRecording then recorder:recordPause(state.world.paused) end
        end
    end
    if key == "c" then
        love.graphics.captureScreenshot(os.time() .. ".png")
    end
    if key == 'f5' then
        state.world.paused = true
        state.panelVisibility.saveDialogOpened = true
    end
    if key == 'i' and state.polyEdit.tempVerts then
        -- figure out where my mousecursor is, between what nodes?
        local mx, my = love.mouse.getPosition()
        local wx, wy = cam:getWorldCoordinates(mx, my)
        objectManager.insertCustomPolygonVertex(wx, wy)
        objectManager.maybeUpdateCustomPolygonVertices()
    end
    if key == 'd' and state.polyEdit.tempVerts then
        -- Remove a vertex
        local mx, my = love.mouse.getPosition()
        local wx, wy = cam:getWorldCoordinates(mx, my)
        objectManager.removeCustomPolygonVertex(wx, wy)
    end
end

return lib

```

src//io.lua
```lua
--io.lua
local lib = {}

local inspect = require 'vendor.inspect'
local json = require 'vendor.dkjson'
local uuid = require 'src.uuid'
local registry = require 'src.registry'
local shapes = require 'src.shapes'
local jointHandlers = require 'src.joint-handlers'
local mathutils = require 'src.math-utils'
local utils = require 'src.utils'
local jointslib = require 'src.joints'
local fixtures = require 'src.fixtures'
local state = require 'src.state'

local snap = require 'src.snap'

function lib.reload(data, world, cam)
    lib.load(data, world, cam)
end

local function clearWorld(world)
    for _, body in pairs(world:getBodies()) do
        body:destroy()
    end
    registry.reset()
end

function lib.buildWorld(data, world, cam)
    local idMap = {}
    -- todo is this actually needed, i *think* its a premature optimization, getting ready to load a file into an exitsing situation, button
    -- this isnt really used. so we just might as well just always use the oldid....
    --print(reuseOldIds)
    -- local function getNewId(oldId)
    --     if not reuseOldIds then
    --         if idMap[oldId] == nil then
    --             idMap[oldId] = uuid.generateID()
    --         end
    --         return idMap[oldId]
    --     else
    --         return oldId
    --     end
    -- end
    local function getNewId(oldId)
        return oldId
    end
    -- should we mabe move this out ?
    clearWorld(world)

    snap.resetList()

    if data.camera then
        cam:setTranslation(data.camera.x, data.camera.y)
        cam:setScale(data.camera.scale)
    end

    local recreatedSFixtures = {}
    -- Iterate through saved bodies and recreate them
    for _, bodyData in ipairs(data.bodies) do
        -- Create a new body
        local body = love.physics.newBody(world, bodyData.position[1], bodyData.position[2], bodyData.bodyType)
        body:setAngle(bodyData.angle)
        body:setLinearVelocity(bodyData.linearVelocity[1], bodyData.linearVelocity[2])
        body:setAngularVelocity(bodyData.angularVelocity)
        body:setFixedRotation(bodyData.fixedRotation or false)
        body:setLinearDamping(bodyData.linearDamping or 0)
        body:setAngularDamping(bodyData.angularDamping or 0)

        local shared = bodyData.sharedFixtureData

        for i = #bodyData.fixtures, 1, -1 do -- doing this backwards keeps order intact
            local fixtureData = bodyData.fixtures[i]
            local shape
            if (fixtureData.radius) then
                --if shared.shapeType == "circle" then
                shape = love.physics.newCircleShape(fixtureData.radius)
            elseif fixtureData.points then
                --elseif shared.shapeType == "polygon" then
                local points = {}
                -- for _, point in ipairs(fixtureData.points) do
                --     table.insert(points, point.x)
                --     table.insert(points, point.y)
                -- end
                for _, point in ipairs(fixtureData.points) do
                    table.insert(points, point)
                end

                local success, err = pcall(function()
                    shape = love.physics.newPolygonShape(unpack(points))
                end)
                if err then
                    logger:info('failed creating a polygonshape, will add a circle instead')
                    shape = nil
                end



                -- elseif fixtureData.shapeType == "edge" then
                --     local x1 = fixtureData.points[1].x
                --     local y1 = fixtureData.points[1].y
                --     local x2 = fixtureData.points[2].x
                --     local y2 = fixtureData.points[2].y
                --     shape = love.physics.newEdgeShape(x1, y1, x2, y2)
            else
                logger:error("Unsupported shape type:", fixtureData.shapeType)
            end


            if shape then
                local fixture = love.physics.newFixture(body, shape, shared.density)
                fixture:setFriction(shared.friction)
                fixture:setRestitution(shared.restitution)
                fixture:setGroupIndex(shared.groupIndex or 0)
                fixture:setSensor(shared.sensor or false)
                if fixtureData.userData then
                    fixture:setSensor(fixtureData.sensor)
                    local oldUD = utils.shallowCopy(fixtureData.userData)
                    oldUD.id = oldUD.id and getNewId(oldUD.id) or uuid.generateID()

                    fixture:setUserData(oldUD)

                    -- make it recreate the image!
                    if oldUD.extra and oldUD.extra.OMP then
                        oldUD.extra.dirty = true
                    end

                    table.insert(recreatedSFixtures, fixture)


                    registry.registerSFixture(oldUD.id, fixture)
                    --print(inspect(utils.shallowCopy(fixture:getUserData())))
                end
            end
        end

        -- Recreate the 'thing' table
        local thing = {
            id = getNewId(bodyData.id),
            label = bodyData.label,
            shapeType = bodyData.shapeType,
            radius = (bodyData.dims and bodyData.dims.radius) or bodyData.radius,
            width = (bodyData.dims and bodyData.dims.width) or bodyData.width,
            width2 = (bodyData.dims and bodyData.dims.width2) or bodyData.width2,
            width3 = (bodyData.dims and bodyData.dims.width3) or bodyData.width3,
            height = (bodyData.dims and bodyData.dims.height) or bodyData.height,
            height2 = (bodyData.dims and bodyData.dims.height2) or bodyData.height2,
            height3 = (bodyData.dims and bodyData.dims.height3) or bodyData.height3,
            height4 = (bodyData.dims and bodyData.dims.height4) or bodyData.height4,
            body = body,
            mirrorX = bodyData.mirrorX or 1,
            mirrorY = bodyData.mirrorY or 1,
            vertices = bodyData.vertices,
            behaviors = bodyData.behaviors,
            --  shape = body:getFixtures()[1]:getShape(), -- Assuming one fixture per body
            fixture = body:getFixtures()[1], -- this is used in clone.
            -- textures = bodyData.textures or { bgURL = '', bgEnabled = false, bgHex = 'ffffffff' },
            -- zOffset = bodyData.zOffset or 0,
        }

        -- Assign the 'thing' to the body's user data
        body:setUserData({ thing = thing })
        --  print(thing.id, inspect(body:getUserData()))
        registry.registerBody(thing.id, body)
    end

    -- todo now we have all the sfixtures and bodies
    -- only now we can patch up stuff with old ids in extra folder ..

    -- Iterate through saved joints and recreate them
    for _, jointData in ipairs(data.joints) do
        local bodyA = registry.getBodyByID(getNewId(jointData.bodyA))
        local bodyB = registry.getBodyByID(getNewId(jointData.bodyB))

        if bodyA and bodyB then
            local joint
            local anchorA = jointData.anchorA
            local anchorB = jointData.anchorB
            local collideConnected = jointData.collideConnected


            if jointData.type == "distance" then
                joint = love.physics.newDistanceJoint(
                    bodyA, bodyB,
                    anchorA[1], anchorA[2],
                    anchorB[1], anchorB[2],
                    collideConnected
                )
                joint:setLength(jointData.properties.length)
                joint:setFrequency(jointData.properties.frequency)
                joint:setDampingRatio(jointData.properties.dampingRatio)
            elseif jointData.type == "revolute" then
                joint = love.physics.newRevoluteJoint(
                    bodyA, bodyB,
                    anchorA[1], anchorA[2],
                    --anchorB[1], anchorB[2],
                    collideConnected
                )
                joint:setMotorEnabled(jointData.properties.motorEnabled)
                if jointData.properties.motorEnabled then
                    joint:setMotorSpeed(jointData.properties.motorSpeed)
                    joint:setMaxMotorTorque(jointData.properties.maxMotorTorque)
                end
                joint:setLimitsEnabled(jointData.properties.limitsEnabled)
                if jointData.properties.limitsEnabled then
                    joint:setLimits(jointData.properties.lowerLimit, jointData.properties.upperLimit)
                end
            elseif jointData.type == "rope" then
                joint = love.physics.newRopeJoint(
                    bodyA, bodyB,
                    anchorA[1], anchorA[2],
                    anchorB[1], anchorB[2],
                    jointData.properties.maxLength
                )
            elseif jointData.type == "weld" then
                joint = love.physics.newWeldJoint(
                    bodyA, bodyB,
                    anchorA[1], anchorA[2],
                    collideConnected
                )
                joint:setFrequency(jointData.properties.frequency)
                joint:setDampingRatio(jointData.properties.dampingRatio)
            elseif jointData.type == "prismatic" then
                joint = love.physics.newPrismaticJoint(
                    bodyA, bodyB,
                    anchorA[1], anchorA[2],
                    jointData.properties.axis.x, jointData.properties.axis.y,
                    collideConnected
                )
                joint:setMotorEnabled(jointData.properties.motorEnabled)
                if jointData.properties.motorEnabled then
                    joint:setMotorSpeed(jointData.properties.motorSpeed)
                    joint:setMaxMotorForce(jointData.properties.maxMotorForce)
                end
                joint:setLimitsEnabled(jointData.properties.limitsEnabled)
                if jointData.properties.limitsEnabled then
                    joint:setLimits(jointData.properties.lowerLimit, jointData.properties.upperLimit)
                end
            elseif jointData.type == "pulley" then
                joint = love.physics.newPulleyJoint(
                    bodyA, bodyB,
                    jointData.properties.groundAnchor1.x, jointData.properties.groundAnchor1.y,
                    jointData.properties.groundAnchor2.x, jointData.properties.groundAnchor2.y,
                    anchorA[1], anchorA[2],
                    anchorB[1], anchorB[2],
                    jointData.properties.ratio,
                    collideConnected
                )
            elseif jointData.type == "wheel" then
                joint = love.physics.newWheelJoint(
                    bodyA, bodyB,
                    anchorA[1], anchorA[2],
                    jointData.properties.axis.x, jointData.properties.axis.y,
                    collideConnected
                )
                joint:setSpringFrequency(jointData.properties.springFrequency)
                joint:setSpringDampingRatio(jointData.properties.springDampingRatio)

                joint:setMotorEnabled(jointData.properties.motorEnabled)

                if jointData.properties.motorEnabled then
                    joint:setMotorSpeed(jointData.properties.motorSpeed)
                    joint:setMaxMotorTorque(jointData.properties.maxMotorTorque)
                end
            elseif jointData.type == "motor" then
                joint = love.physics.newMotorJoint(
                    bodyA, bodyB,
                    jointData.properties.correctionFactor,
                    collideConnected
                )
                joint:setAngularOffset(jointData.properties.angularOffset)
                joint:setLinearOffset(jointData.properties.linearOffsetX, jointData.properties.linearOffsetY)
                joint:setMaxForce(jointData.properties.maxForce)
                joint:setMaxTorque(jointData.properties.maxTorque)
            elseif jointData.type == "friction" then
                joint = love.physics.newFrictionJoint(
                    bodyA, bodyB,
                    anchorA[1], anchorA[2],
                    anchorB[1], anchorB[2],
                    collideConnected
                )
                joint:setMaxForce(jointData.properties.maxForce)
                joint:setMaxTorque(jointData.properties.maxTorque)
            else
                -- Handle unsupported joint types
                logger:error("Unsupported joint type during load:", jointData.type)
            end

            if joint then
                -- Assign the joint ID
                -- joint:setUserData({ id = jointData.id })


                local fxa, fya = mathutils.rotatePoint(anchorA[1] - bodyA:getX(), anchorA[2] - bodyA:getY(), 0, 0,
                    -bodyA:getAngle())
                local fxb, fyb = mathutils.rotatePoint(anchorB[1] - bodyB:getX(), anchorB[2] - bodyB:getY(), 0, 0,
                    -bodyB:getAngle())


                local scriptmeta = jointData.scriptmeta

                local ud = {
                    id = getNewId(jointData.id),
                    offsetA = { x = fxa, y = fya },
                    offsetB = { x = fxb, y = fyb }
                }

                if jointData.scriptmeta then ud.scriptmeta = jointData.scriptmeta end

                joint:setUserData(ud)

                -- Register the joint in the registry
                registry.registerJoint(ud.id, joint)
            end
        else
            logger:error("Failed to find bodies for joint:", jointData.id)
        end
    end
end

function lib.load(data, world, cam)
    local jsonData, pos, err = json.decode(data, 1, nil)
    if err then
        logger:error("Error decoding JSON:", err)
        return
    end

    -- Verify version
    if jsonData then
        if jsonData.version ~= "1.0" then
            logger:error("Unsupported save version:", jsonData.version)
            return
        end
    else
        logger:error('failed loading json')
        return
    end
    -- Clear existing world
    lib.buildWorld(jsonData, world, cam, reuseOldIds)

    snap.onSceneLoaded()
end

local function needsDimProperty(prop, shape)
    local needsRadius = function(shape)
        return shape == 'triangle' or shape == 'pentagon' or shape == 'hexagon' or
            shape == 'heptagon' or shape == 'octagon' or shape == 'circle'
    end

    if prop == 'radius' then
        return needsRadius(shape)
    elseif prop == 'width' then
        return not needsRadius(shape) and shape ~= 'custom'
    elseif prop == 'height' then
        return not needsRadius(shape) and shape ~= 'custom'
    elseif prop == 'height2' then
        return shape == 'capsule' or shape == 'torso'
    elseif prop == 'width2' then
        return shape == 'trapezium' or shape == 'torso'
    elseif prop == 'height3' or prop == 'height4' then
        return shape == 'torso'
    elseif prop == 'width3' then
        return shape == 'torso'
    end
end


function lib.gatherSaveData(world, camera)
    local saveData = {
        version = "1.0", -- Versioning for future compatibility
        bodies = {},
        joints = {},
        camera = {}
    }
    for _, body in pairs(world:getBodies()) do
        local userData = body:getUserData()
        local thing = userData and userData.thing

        if thing and thing.id then
            local lvx, lvy = body:getLinearVelocity()
            local bodyData = {
                id = thing.id, -- Unique identifier
                label = utils.sanitizeString(thing.label),
                shapeType = thing.shapeType,
                dims = {
                    radius = needsDimProperty('radius', thing.shapeType) and thing.radius or nil,
                    width = needsDimProperty('width', thing.shapeType) and thing.width or nil,
                    width2 = needsDimProperty('width2', thing.shapeType) and thing.width2 or nil,
                    width3 = needsDimProperty('width3', thing.shapeType) and thing.width3 or nil,
                    height = needsDimProperty('height', thing.shapeType) and thing.height or nil,
                    height2 = needsDimProperty('height2', thing.shapeType) and thing.height2 or nil,
                    height3 = needsDimProperty('height3', thing.shapeType) and thing.height3 or nil,
                    height4 = needsDimProperty('height4', thing.shapeType) and thing.height4 or nil,
                },
                --textures = thing.textures,
                -- zOffset = thing.zOffset,
                mirrorX = thing.mirrorX,
                mirrorY = thing.mirrorY,
                --radius = thing.radius,
                vertices = thing.vertices,
                bodyType = body:getType(), -- 'dynamic', 'kinematic', or 'static'
                position = { utils.round_to_decimals(body:getX(), 4), utils.round_to_decimals(body:getY(), 4) },
                angle = utils.round_to_decimals(body:getAngle(), 4),
                linearVelocity = { lvx, lvy },
                angularVelocity = utils.round_to_decimals(body:getAngularVelocity(), 4),
                linearDamping = utils.round_to_decimals(body:getLinearDamping(), 4),
                angularDamping = utils.round_to_decimals(body:getAngularDamping(), 4),
                fixedRotation = body:isFixedRotation(),
                fixtures = {},
                sharedFixtureData = {},
                behaviors = thing.behaviors
            }
            -- Iterate through all fixtures of the body

            -- to save data i am assuming all fixtures are the same type and have the same settings.
            local bodyFixtures = body:getFixtures()
            if #bodyFixtures >= 1 then
                if #bodyFixtures >= 1 then
                    -- local fixtures = fb:getFixtures()
                    -- local ff = fixtures[1]
                    local first = bodyFixtures[1]

                    for k = 1, #bodyFixtures do
                        local fixture = bodyFixtures[k]
                        if fixture:getUserData() == nil then
                            first = fixture
                            break
                        end
                    end


                    bodyData.sharedFixtureData.density = utils.round_to_decimals(first:getDensity(), 4)
                    bodyData.sharedFixtureData.friction = utils.round_to_decimals(first:getFriction(), 4)
                    bodyData.sharedFixtureData.restitution = utils.round_to_decimals(first:getRestitution(), 4)
                    bodyData.sharedFixtureData.groupIndex = first:getGroupIndex()

                    bodyData.sharedFixtureData.sensor = first:isSensor() -- this isnt always working!!!!!!!!   need to find a fixture which is def. not a userdata one

                    -- todo this shape type name isnt really used anymore...
                    -- can we just delete it ?
                    local shape = first:getShape()
                    if shape:typeOf("CircleShape") then
                        bodyData.sharedFixtureData.shapeType = 'circle'
                    elseif shape:typeOf("PolygonShape") then
                        bodyData.sharedFixtureData.shapeType = 'polygon'
                    end
                end
            end

            for _, fixture in ipairs(body:getFixtures()) do
                local shape = fixture:getShape()

                local fixtureData = {}
                if shape:typeOf("CircleShape") then
                    --fixtureData.shapeType = "circle"
                    fixtureData.radius = shape:getRadius()
                elseif shape:typeOf("PolygonShape") then
                    local result = {}
                    local points = { shape:getPoints() }
                    for i = 1, #points do
                        table.insert(result, utils.round_to_decimals(points[i], 3))
                    end
                    fixtureData.points = result
                    -- elseif shape:typeOf("EdgeShape") then
                    --     fixtureData.shapeType = "edge"
                    --     local x1, y1, x2, y2 = shape:getPoints()
                    --     fixtureData.points = { { x = x1, y = y1 }, { x = x2, y = y2 } }
                else
                    -- Handle other shape types if any
                    fixtureData.shapeType = "unknown"
                end

                if fixture:getUserData() then
                    if utils.sanitizeString(fixture:getUserData().label) == 'snap' or fixture:getUserData().subtype == 'snap' then
                        local ud             = fixture:getUserData()

                        ud.extra.fixture     = 'fixture'
                        -- todo cannot reproduce this one yet.. ?Error: src/io.lua:455: attempt to call method 'getUserData' (a nil value)
                        ud.extra.at          = ud.extra.at and ud.extra.at:getUserData().thing.id
                        ud.extra.to          = ud.extra.to and ud.extra.to:getUserData().thing.id
                        fixtureData.userData = utils.deepCopy(ud)
                    else
                        local ud = fixture:getUserData()
                        if ud.extra and ud.extra.type == 'texfixture' or ud.subtype == 'texfixture' then
                            ud.extra.dirty = true
                            if ud.extra.ompImage then ud.extra.ompImage = nil end
                        end
                        if ud.extra and ud.extra.ompImage then
                            ud.extra.dirty = true
                            ud.extra.ompImage = nil
                        end
                        fixtureData.userData = utils.deepCopy(ud)
                    end



                    fixtureData.sensor = fixture:isSensor()
                end
                table.insert(bodyData.fixtures, fixtureData)
            end

            table.insert(saveData.bodies, bodyData)
        end
    end

    -- Iterate through all joints in the world
    for _, joint in pairs(world:getJoints()) do
        local jointUserData = joint:getUserData()
        local jointID = jointUserData and jointUserData.id

        if not jointID then
            logger:debug('what is up with this joint?')
        else
            -- Get connected bodies
            local bodyA, bodyB = joint:getBodies()

            local thingA = bodyA:getUserData() and bodyA:getUserData().thing
            local thingB = bodyB:getUserData() and bodyB:getUserData().thing

            if thingA and thingB then
                local x1, y1, x2, y2 = joint:getAnchors()
                local jointData = {

                    id = jointID,
                    type = joint:getType(),
                    bodyA = thingA.id,
                    bodyB = thingB.id,
                    anchorA = { utils.round_to_decimals(x1, 3), utils.round_to_decimals(y1, 3) },
                    anchorB = { utils.round_to_decimals(x2, 3), utils.round_to_decimals(y2, 3) },
                    collideConnected = joint:getCollideConnected(),
                    properties = {}
                }


                if (jointUserData.scriptmeta) then
                    jointData.scriptmeta = utils.shallowCopy(jointUserData.scriptmeta)
                end

                -- Extract joint-specific properties
                if joint:getType() == "distance" then
                    jointData.properties.length = joint:getLength()
                    jointData.properties.frequency = joint:getFrequency()
                    jointData.properties.dampingRatio = joint:getDampingRatio()
                elseif joint:getType() == 'rope' then
                    jointData.properties.maxLength = joint:getMaxLength()
                elseif joint:getType() == "revolute" then
                    jointData.properties.motorEnabled = joint:isMotorEnabled()
                    if jointData.properties.motorEnabled then
                        jointData.properties.motorSpeed = joint:getMotorSpeed()
                        jointData.properties.maxMotorTorque = joint:getMaxMotorTorque()
                    end
                    jointData.properties.limitsEnabled = joint:areLimitsEnabled()
                    if jointData.properties.limitsEnabled then
                        jointData.properties.lowerLimit = joint:getLowerLimit()
                        jointData.properties.upperLimit = joint:getUpperLimit()
                    end
                elseif joint:getType() == "weld" then
                    jointData.properties.frequency = joint:getFrequency()
                    jointData.properties.dampingRatio = joint:getDampingRatio()
                elseif joint:getType() == "prismatic" then
                    local axisx, axisy = joint:getAxis()
                    jointData.properties.axis = { x = axisx, y = axisy }
                    jointData.properties.motorEnabled = joint:isMotorEnabled()
                    if jointData.properties.motorEnabled then
                        jointData.properties.motorSpeed = joint:getMotorSpeed()
                        jointData.properties.maxMotorForce = joint:getMaxMotorForce()
                    end
                    jointData.properties.limitsEnabled = joint:areLimitsEnabled()
                    if jointData.properties.limitsEnabled then
                        jointData.properties.lowerLimit = joint:getLowerLimit()
                        jointData.properties.upperLimit = joint:getUpperLimit()
                    end
                elseif joint:getType() == "pulley" then
                    local a1x, a1y, a2x, a2y = joint:getGroundAnchors()
                    jointData.properties.groundAnchor1 = { x = a1x, y = a1y }
                    jointData.properties.groundAnchor2 = { x = a2x, y = a2y }
                    jointData.properties.ratio = joint:getRatio()
                elseif joint:getType() == "wheel" then
                    jointData.properties.motorEnabled = joint:isMotorEnabled()
                    if jointData.properties.motorEnabled then
                        jointData.properties.motorSpeed = joint:getMotorSpeed()
                        jointData.properties.maxMotorTorque = joint:getMaxMotorTorque()
                    end
                    local axisx, axisy = joint:getAxis()
                    jointData.properties.axis = { x = axisx, y = axisy }
                    jointData.properties.springFrequency = joint:getSpringFrequency()
                    jointData.properties.springDampingRatio = joint:getSpringDampingRatio()
                elseif joint:getType() == "motor" then
                    jointData.properties.correctionFactor = joint:getCorrectionFactor()
                    jointData.properties.angularOffset = joint:getAngularOffset()
                    jointData.properties.linearOffsetX, jointData.properties.linearOffsetY = joint:getLinearOffset()
                    jointData.properties.maxForce = joint:getMaxForce()
                    jointData.properties.maxTorque = joint:getMaxTorque()
                elseif joint:getType() == "friction" then
                    jointData.properties.maxForce = joint:getMaxForce()
                    jointData.properties.maxTorque = joint:getMaxTorque()
                else
                    -- Handle unsupported joint types
                    logger:error("Unsupported joint type during save:", joint:getType())
                end

                table.insert(saveData.joints, jointData)
            else
                logger:error("Failed to find bodies for joint:", jointID)
            end
        end
    end

    local camx, camy = camera:getTranslation()
    saveData.camera = {
        rotation = camera:getRotation(),
        x = camx,
        y = camy,
        scale = camera:getScale()
    }
    return saveData
end

function lib.save(world, camera, filename)
    -- Serialize the data to JSON
    local saveData = lib.gatherSaveData(world, camera)
    logger:debug(inspect(saveData))
    local jsonData = json.encode(saveData, { indent = true })

    -- Write the JSON data to a file
    local success, message = love.filesystem.write(filename .. '.playtime.json', jsonData)
    if success then
        logger:info("World successfully saved to " .. filename)
        logger:info("file://" .. love.filesystem.getSaveDirectory())
    else
        logger:error("Failed to save world:", message)
    end

    love.system.openURL("file://" .. love.filesystem.getSaveDirectory())
end

function lib.cloneSelection(selectedBodies, world)
    -- Mapping from original body IDs to cloned body instances
    local clonedBodiesMap = {}

    -- mapping from old ids (of bodies and fixtures) to new cloned ids
    local idMapping = {}

    -- Step 1: Clone Bodies
    for _, originals in ipairs(selectedBodies) do
        local originalBody = originals.body
        local userData     = originalBody:getUserData()
        if userData and userData.thing then
            local originalThing = userData.thing

            -- Generate a new unique ID for the cloned body
            local newID = uuid.generateID()
            idMapping[originalThing.id] = newID
            -- Clone body properties
            local newBody = love.physics.newBody(world, originalBody:getX() + 50, originalBody:getY() + 50,
                originalBody:getType())
            newBody:setAngle(originalBody:getAngle())
            newBody:setLinearVelocity(originalBody:getLinearVelocity())
            newBody:setAngularVelocity(originalBody:getAngularVelocity())
            newBody:setFixedRotation(originalBody:isFixedRotation())
            newBody:setSleepingAllowed(originalBody:isSleepingAllowed())
            newBody:setLinearDamping(originalBody:getLinearDamping())
            newBody:setAngularDamping(originalBody:getAngularDamping())
            -- Clone shape
            local settings = {
                radius = originalThing.radius,
                width = originalThing.width,
                width2 = originalThing.width2,
                width3 = originalThing.width3,
                height = originalThing.height,
                height2 = originalThing.height2,
                height3 = originalThing.height3,
                height4 = originalThing.height4,
                optionalVertices = originalThing.vertices,

            }
            local newShapeList, newVertices = shapes.createShape(originalThing.shapeType, settings)


            local oldFixtures = originalBody:getFixtures()



            local ok, offset = fixtures.hasFixturesWithUserDataAtBeginning(oldFixtures)
            if not ok then
                logger:error('some how the userdata fixtures arent at the beginning!')
            end
            if ok and offset > -1 then
                for i = 1 + offset, #oldFixtures do
                    local oldF = oldFixtures[i]
                    local newFixture = love.physics.newFixture(newBody, newShapeList[i - (offset)], oldF:getDensity())
                    newFixture:setRestitution(oldF:getRestitution())
                    newFixture:setFriction(oldF:getFriction())
                    newFixture:setGroupIndex(oldF:getGroupIndex())
                    newFixture:setSensor(oldF:isSensor())
                end
                if offset > 0 then
                    -- here we should recreate the special fixtures..
                    for i = 1, offset do
                        local oldF = oldFixtures[i]
                        local shape = oldF:getShape():getPoints()


                        local newFixture = love.physics.newFixture(newBody, oldF:getShape(), oldF:getDensity())
                        newFixture:setRestitution(oldF:getRestitution())
                        newFixture:setFriction(oldF:getFriction())
                        newFixture:setGroupIndex(oldF:getGroupIndex())

                        local oldUD = utils.deepCopy(oldF:getUserData())
                        local oldid = oldUD.id

                        oldUD.id = uuid.generateID()
                        idMapping[oldid] = oldUD.id
                        if utils.sanitizeString(oldUD.label) == 'snap' or oldUD.subtype == 'snap' then
                            oldUD.extra.at = nil
                            oldUD.extra.to = nil
                            oldUD.extra.fixture = nil
                        end

                        newFixture:setUserData(oldUD)
                        newFixture:setSensor(oldF:isSensor())

                        registry.registerSFixture(oldUD.id, newFixture)
                    end
                end
            end


            -- Clone fixture
            --local newFixture = love.physics.newFixture(newBody, newShape, originalThing.fixture:getDensity())
            --newFixture:setRestitution(originalThing.fixture:getRestitution())
            --newFixture:setFriction(originalThing.fixture:getFriction())

            -- Clone user data
            if (originalThing.vertices) then
                if (#originalThing.vertices ~= #newVertices) then
                    utils.trace('vertex count before and after cloning ', #originalThing.vertices, #newVertices)
                end
            end
            local clonedThing = {
                shapeType = originalThing.shapeType,
                radius = originalThing.radius,
                width = originalThing.width,
                width2 = (originalThing.width2 or 1),
                width3 = originalThing.width3,
                height = originalThing.height,
                height2 = originalThing.height2,
                height3 = originalThing.height3,
                height4 = originalThing.height4,
                label = originalThing.label,
                mirrorX = originalThing.mirrorX,
                mirrorY = originalThing.mirrorY,
                behaviors = originalThing.behaviors,
                body = newBody,
                shapes = newShapeList,
                vertices = newVertices,
                --textures = originalThing.textures,
                --zOffset = originalThing.zOffset,
                id = newID
            }
            newBody:setUserData({ thing = clonedThing })

            -- Register the cloned body
            registry.registerBody(newID, newBody)

            -- Store in the map for joint cloning
            clonedBodiesMap[originalThing.id] = clonedThing
        end
    end

    local doneJoints = {}
    -- Step 2: Clone Joints
    for _, originalThing in ipairs(state.selection.selectedBodies) do
        local originalBody = originalThing.body
        local joints = originalBody:getJoints()
        for _, originalJoint in ipairs(joints) do
            local ud = originalJoint:getUserData()
            if ud and ud.id then
                if not doneJoints[ud.id] == true then -- make sure we dont do joints twice..
                    local jointType = originalJoint:getType()
                    local handler = jointHandlers[jointType]
                    doneJoints[ud.id] = true
                    if handler and handler.extract then
                        local jointData = handler.extract(originalJoint)
                        -- utils.trace(inspect(jointData))
                        -- Determine the original bodies connected by the joint
                        local bodyA, bodyB = originalJoint:getBodies()
                        local clonedBodyA = clonedBodiesMap[bodyA:getUserData().thing.id]
                        local clonedBodyB = clonedBodiesMap[bodyB:getUserData().thing.id]



                        -- If both bodies are cloned, proceed to clone the joint
                        if clonedBodyA and clonedBodyB then
                            local newJointData = {
                                body1 = clonedBodyA.body,
                                body2 = clonedBodyB.body,
                                jointType = jointType,
                                collideConnected = originalJoint:getCollideConnected(),
                                id = uuid.generateID(),

                                offsetA = { x = ud.offsetA.x, y = ud.offsetA.y },
                                offsetB = { x = ud.offsetB.x, y = ud.offsetB.y }
                            }
                            idMapping[ud.id] = newJointData.id
                            -- Include all joint-specific properties
                            for key, value in pairs(jointData) do
                                newJointData[key] = value
                            end
                            local limitsEnabled = originalJoint:areLimitsEnabled()
                            local lower, upper = originalJoint:getLimits()
                            local oldRef = originalJoint:getReferenceAngle()
                            local newJoint = jointslib.createJoint(newJointData)
                            local newRef = originalJoint:getReferenceAngle()
                            --  logger:info(oldRef, newRef)
                            newJoint:setLimits(lower, upper)
                            --newJoint:setUpperLimit(upper)
                            --newJoint:setLowerLimit(lower)
                            newJoint:setLimitsEnabled(limitsEnabled)

                            if ud.scriptmeta then
                                local newud = newJoint:getUserData()
                                newud.scriptmeta = utils.shallowCopy(ud.scriptmeta)
                                newJoint:setUserData(newud)
                                if ud.scriptmeta.type and ud.scriptmeta.type == 'snap' then
                                    snap.addSnapJoint(newJoint)
                                end
                            end
                            -- Register the new joint
                            registry.registerJoint(newJointData.id, newJoint)
                        end
                    end
                end
            end
        end
    end

    -- at this point everything that is cloned is added into the world
    -- logger:inspect(idMapping)
    -- now we need to figure out if i have any of the connected-texture fixtures with ids in their userdata that needs updating
    for k, v in pairs(clonedBodiesMap) do
        local fixtures = v.body:getFixtures()
        for j = 1, #fixtures do
            local fixture = fixtures[j]
            local ud = fixture:getUserData()
            local oldUD = utils.deepCopy(ud)
            if oldUD and oldUD.extra and oldUD.extra.nodes then
                for ni = 1, #oldUD.extra.nodes do
                    oldUD.extra.nodes[ni].id = idMapping[oldUD.extra.nodes[ni].id]
                end
                fixture:setUserData(oldUD)
            end
        end
    end




    local result = {}
    for k, v in pairs(clonedBodiesMap) do
        table.insert(result, v)
    end
    return result
    --state.selection.selectedBodies = result
end

return lib

```

src//joint-handlers.lua
```lua
-- joint-handlers.lua
local jointHandlers = {}

jointHandlers["distance"] = {
    create = function(data, x1, y1, x2, y2)
        local length = data.length or math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        local joint = love.physics.newDistanceJoint(data.body1, data.body2, x1, y1, x2, y2, data.collideConnected)
        joint:setLength(length)
        return joint
    end,

    extract = function(joint)
        return {
            length = joint:getLength(),
            frequency = joint:getFrequency(),
            dampingRatio = joint:getDampingRatio(),
        }
    end
}
jointHandlers["friction"] = {
    create = function(data, x1, y1, x2, y2)
        local joint = love.physics.newFrictionJoint(data.body1, data.body2, x1, y1, x2, y2, data.collideConnected)
        return joint
    end,

    extract = function(joint)
        return {
            maxForce = joint:getMaxForce(),
            maxTorque = joint:getMaxTorque()
        }
    end
}
jointHandlers["weld"] = {
    create = function(data, x1, y1, x2, y2)
        local joint = love.physics.newWeldJoint(data.body1, data.body2, x1, y1, data.collideConnected)
        return joint
    end,
    extract = function(joint)
        return {
            frequency = joint:getFrequency(),
            dampingRatio = joint:getDampingRatio(),
        }
    end
}
jointHandlers["rope"] = {
    create = function(data, x1, y1, x2, y2)
        local maxLength = data.maxLength or math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        local joint = love.physics.newRopeJoint(data.body1, data.body2, x1, y1, x2, y2, maxLength, data.collideConnected)
        return joint
    end,
    extract = function(joint)
        return {
            maxLength = joint:getMaxLength()
        }
    end
}
jointHandlers["revolute"] = {

    create = function(data, x1, y1, x2, y2)
        local joint = love.physics.newRevoluteJoint(data.body1, data.body2, x1, y1, data.collideConnected)

        return joint
    end,
    extract = function(joint)
        return {
            motorEnabled = joint:isMotorEnabled(),
            motorSpeed = joint:getMotorSpeed(),
            maxMotorTorque = joint:getMaxMotorTorque(),
            limitsEnabled = joint:areLimitsEnabled(),
            lowerLimit = joint:getLowerLimit(),
            upperLimit = joint:getUpperLimit(),
        }
    end
}
jointHandlers["wheel"] = {
    create = function(data, x1, y1, x2, y2)
        local joint = love.physics.newWheelJoint(data.body1, data.body2, x1, y1, data.axisX or 0, data.axisY or 1,
            data.collideConnected)

        if data.springFrequency then
            joint:setSpringFrequency(data.springFrequency)
        end
        if data.springDampingRatio then
            joint:setSpringDampingRatio(data.springDampingRatio)
        end
        return joint
    end,
    extract = function(joint)
        return {
            springFrequency = joint:getSpringFrequency(),
            springDampingRatio = joint:getSpringDampingRatio(),
        }
    end
}
jointHandlers["motor"] = {
    create = function(data, x1, y1, x2, y2)
        local joint = love.physics.newMotorJoint(data.body1, data.body2, data.correctionFactor or .3,
            data.collideConnected)
        return joint
    end,
    extract = function(joint)
        local lox, loy = joint:getLinearOffset()
        return {
            correctionFactor = joint:getCorrectionFactor(),
            angularOffset = joint:getAngularOffset(),
            linearOffsetX = lox,
            linearOffsetY = loy,
            maxForce = joint:getMaxForce(),
            maxTorque = joint:getMaxTorque()
        }
    end
}
jointHandlers["prismatic"] = {
    create = function(data, x1, y1, x2, y2)
        local joint = love.physics.newPrismaticJoint(data.body1, data.body2, x1, y1, data.axisX or 0, data.axisY or 1,
            data.collideConnected)
        joint:setLowerLimit(0)
        joint:setUpperLimit(0)
        return joint
    end,
    extract = function(joint)
        return {
            motorEnabled = joint:isMotorEnabled(),
            motorSpeed = joint:getMotorSpeed(),
            maxMotorForce = joint:getMaxMotorForce(),
            limitsEnabled = joint:areLimitsEnabled(),
            lowerLimit = joint:getLowerLimit(),
            upperLimit = joint:getUpperLimit(),

        }
    end
}
jointHandlers["pulley"] = {
    create = function(data, x1, y1, x2, y2)
        local groundAnchorA = data.groundAnchor1 or { 0, 0 }
        local groundAnchorB = data.groundAnchor2 or { 0, 0 }
        local bodyA_centerX, bodyA_centerY = data.body1:getWorldCenter()
        local bodyB_centerX, bodyB_centerY = data.body2:getWorldCenter()
        local ratio = data.ratio or 1

        local joint = love.physics.newPulleyJoint(
            data.body1, data.body2,
            bodyA_centerX or groundAnchorA[1], groundAnchorA[2],
            bodyB_centerX or groundAnchorB[1], groundAnchorB[2],
            bodyA_centerX, bodyA_centerY,
            bodyB_centerX, bodyB_centerY,
            ratio,
            false
        )
        return joint
    end,
    extract = function(joint)
        local x1, y1, x2, y2 = joint:getGroundAnchors()
        return {
            groundAnchor1 = { x1, y1 },
            groundAnchor2 = { x2, y2 },
            ratio = joint:getRatio()
        }
    end
}
jointHandlers["friction"] = {
    create = function(data, x1, y1, x2, y2)
        -- Create a Friction Joint
        local x, y = data.body1:getPosition()
        local joint = love.physics.newFrictionJoint(data.body1, data.body2, x1, y1, false)

        if data.maxForce then
            joint:setMaxForce(data.maxForce)
        end
        if data.maxTorque then
            joint:setMaxTorque(data.maxTorque)
        end
        return joint
    end,
    extract = function(joint)
        return {
            maxForce = joint:getMaxForce(),
            maxTorque = joint:getMaxTorque(),
        }
    end
}
return jointHandlers

```

src//joints.lua
```lua
--joints.lua

local lib = {}
local uuid = require 'src.uuid'
local jointHandlers = require 'src.joint-handlers'
local registry = require 'src.registry'
local mathutils = require 'src.math-utils'


-- Updates offsetA of a joint based on a new LOCAL point (relative to body A)
function lib.updateJointOffsetA(joint, localX, localY)
    if not joint or joint:isDestroyed() then
        logger:error("WARN: updateJointOffsetA called on invalid joint"); return nil
    end
    local offsetA = { x = localX, y = localY }
    local offsetB = lib.getJointMetaSetting(joint, "offsetB") or { x = 0, y = 0 } -- Keep existing offset B
    logger:info(string.format("Updating Joint %s Offset A to: (%.2f, %.2f)", (joint:getUserData().id or "N/A"), localX,
        localY))
    -- Recreate the joint using existing properties but new offset A
    return lib.recreateJoint(joint, { offsetA = offsetA, offsetB = offsetB })
end

-- Updates offsetB of a joint based on a new LOCAL point (relative to body B)
function lib.updateJointOffsetB(joint, localX, localY)
    if not joint or joint:isDestroyed() then
        logger:error("WARN: updateJointOffsetB called on invalid joint"); return nil
    end
    local offsetA = lib.getJointMetaSetting(joint, "offsetA") or { x = 0, y = 0 } -- Keep existing offset A
    local offsetB = { x = localX, y = localY }
    logger:info(string.format("Updating Joint %s Offset B to: (%.2f, %.2f)", (joint:getUserData().id or "N/A"), localX,
        localY))
    -- Recreate the joint using existing properties but new offset B
    return lib.recreateJoint(joint, { offsetA = offsetA, offsetB = offsetB })
end

function lib.getJointId(joint)
    local ud = joint:getUserData()
    if ud then
        return ud.id
    end
    logger:error('THIS IS WRONG WHY THIS JOINT HAS NO ID!!', tostring(joint:getType()))
    return nil
end

function lib.setJointMetaSetting(joint, settingKey, settingValue)
    -- Get the existing userdata
    local ud = joint:getUserData() or {}

    -- Ensure userdata is a table
    if type(ud) ~= "table" then
        ud = {} -- Initialize as a table if not already
    end

    -- Update or add the specific setting
    ud[settingKey] = settingValue

    -- Set the updated userdata back on the joint
    joint:setUserData(ud)
end

function lib.getJointMetaSetting(joint, settingKey)
    -- Get the existing userdata
    local ud = joint:getUserData()

    -- Check if userdata exists and is a table
    if type(ud) == "table" then
        return ud[settingKey] -- Return the specific setting
    else
        logger:error('could not find meta settting ' .. settingKey .. ' on joint with type ' .. tostring(joint:getType()))
        return nil -- Return nil if userdata is not a table or doesn't exist
    end
end

function lib.createJoint(data)
    local bodyA = data.body1
    local bodyB = data.body2
    local jointType = data.jointType

    local joint

    local x1, y1 = bodyA:getPosition()
    local x2, y2 = bodyB:getPosition()


    if not (jointType == 'rope' or jointType == 'distance') then
        -- i only want to do the positioning when im a rope joint..!
        -- that p1 and p2 is set when creating the joint by clicking on the bodies..
        data.p1 = { 0, 0 }
        data.p2 = { 0, 0 }
    end

    local offsetA = data.offsetA or { x = data.p1[1], y = data.p1[2] } or { x = 0, y = 0 }
    local rx, ry = mathutils.rotatePoint(offsetA.x, offsetA.y, 0, 0, bodyA:getAngle())
    x1, y1 = x1 + rx, y1 + ry

    local offsetB = data.offsetB or { x = data.p2[1], y = data.p2[2] } or { x = 0, y = 0 }
    local rx, ry = mathutils.rotatePoint(offsetB.x, offsetB.y, 0, 0, bodyB:getAngle())
    x2, y2 = x2 + rx, y2 + ry

    local handler = jointHandlers[jointType]

    if handler and handler.create then
        joint = handler.create(data, x1, y1, x2, y2)
    else
        logger:error("Joint type '" .. jointType .. "' is not implemented yet.")
        return
    end

    local setId = data.id or uuid.generateID()
    joint:setUserData({ id = setId })
    lib.setJointMetaSetting(joint, 'offsetA', offsetA)
    lib.setJointMetaSetting(joint, 'offsetB', offsetB)

    registry.registerJoint(setId, joint)
    return joint
end

function lib.extractJoints(body)
    local joints = body:getJoints()
    local jointData = {}

    for _, joint in ipairs(joints) do
        local bodyA, bodyB = joint:getBodies()
        local otherBody = (bodyA == body) and bodyB or bodyA -- Determine the other connected body
        local jointType = joint:getType()
        local isBodyA = (bodyA == body)

        local data = {
            offsetA = lib.getJointMetaSetting(joint, "offsetA"),
            offsetB = lib.getJointMetaSetting(joint, "offsetB"),
            id = lib.getJointId(joint),
            jointType = jointType,
            otherBody = otherBody,
            collideConnected = joint:getCollideConnected(),
            originalBodyOrder = isBodyA and "bodyA" or "bodyB",
        }

        local handler = jointHandlers[jointType]
        if not handler or not handler.extract then
            logger:error("extract: Unsupported joint type: " .. jointType)
            goto continue
        end

        -- Extract additional data using the handler
        local additionalData = handler.extract(joint)
        for key, value in pairs(additionalData) do
            data[key] = value
        end

        table.insert(jointData, data)
        ::continue::
    end

    return jointData
end

function lib.recreateJoint(joint, newSettings, swapBodies)
    if joint:isDestroyed() then
        logger:error("The joint is already destroyed.")
        return nil
    end

    local bodyA, bodyB = joint:getBodies()

    local jointType = joint:getType()

    local id = lib.getJointId(joint)
    local offsetA = lib.getJointMetaSetting(joint, "offsetA") or { x = 0, y = 0 }
    local offsetB = lib.getJointMetaSetting(joint, "offsetB") or { x = 0, y = 0 }



    local data = {
        body1 = bodyA,
        body2 = bodyB,
        jointType = jointType,
        id = id,
        offsetA = offsetA,
        offsetB = offsetB,
        collideConnected =
            joint:getCollideConnected()
    }

    -- Add new settings to the data
    for key, value in pairs(newSettings or {}) do
        data[key] = value
    end

    local handler = jointHandlers[jointType]
    if not handler or not handler.extract then
        logger:error("recreate extract: Unsupported joint type: " .. jointType)
    end

    -- Extract additional data using the handler
    local additionalData = handler.extract(joint)
    for key, value in pairs(additionalData) do
        data[key] = value
    end

    joint:destroy()

    -- Create a new joint with the updated data
    bodyA:setAwake(true)
    bodyB:setAwake(true)

    return lib.createJoint(data)
end

-- this one is only called from recreateThingFromBody


local function tranlateBody(body, dx, dy)
    local x, y = body:getPosition()
    body:setPosition(x + dx, y + dy)
end

function moveUntilEnd(from, dx, dy, visited, dir)
    local joints = from:getJoints()
    for i = 1, #joints do
        local bodyA, bodyB = joints[i]:getBodies()

        if (dir == 'A') then
            if (not visited[bodyB:getUserData().thing.id]) then
                tranlateBody(bodyB, dx, dy)
                visited[bodyB:getUserData().thing.id] = true
                moveUntilEnd(bodyB, dx, dy, visited, dir)
            end
            -- if (not visited[bodyA:getUserData().thing.id]) then
            --     tranlateBody(bodyA, -dx, -dy)
            --     visited[bodyA:getUserData().thing.id] = true
            --     moveUntilEnd(bodyA, -dx, -dy, visited, dir)
            -- end
        end
        if dir == 'B' then
            if (not visited[bodyA:getUserData().thing.id]) then
                tranlateBody(bodyA, dx, dy)
                visited[bodyA:getUserData().thing.id] = true
                moveUntilEnd(bodyA, dx, dy, visited, dir)
            end
            -- if (not visited[bodyB:getUserData().thing.id]) then
            --     tranlateBody(bodyB, dx, dy)
            --     visited[bodyB:getUserData().thing.id] = true
            --     moveUntilEnd(bodyB, dx, dy, visited, dir)
            -- end
        end
    end
end

function lib.reattachJoints(jointData, newBody, oldVertices)
    local visited = {}
    for _, data in ipairs(jointData) do
        local jointType = data.jointType
        local otherBody = data.otherBody

        if data.originalBodyOrder == "bodyA" then
            data.body1 = newBody
            data.body2 = data.otherBody

            local before = { x = data.offsetA.x, y = data.offsetA.y }

            if true then
                local weights = mathutils.getMeanValueCoordinatesWeights(data.offsetA.x, data.offsetA.y, oldVertices)
                local newx, newy = mathutils.repositionPointUsingWeights(weights, newBody:getUserData().thing.vertices)

                data.offsetA.x = newx
                data.offsetA.y = newy
            end


            local after = { x = data.offsetA.x, y = data.offsetA.y }

            local rx, ry = mathutils.rotatePoint(
                after.x - before.x, after.y - before.y, 0, 0, newBody:getAngle()
            )
            local id = data.otherBody:getUserData().thing.id
            if (not visited[id]) then
                local ox, oy = data.otherBody:getPosition()

                tranlateBody(data.otherBody, rx, ry)
                --moveUntilEnd(from, dx, dy, visited)
                --data.otherBody:setPosition(ox + rx, oy + ry)
                visited[id] = true
                moveUntilEnd(data.otherBody, rx, ry, visited, 'A')
            end
        else
            data.body1 = data.otherBody
            data.body2 = newBody

            local before = { x = data.offsetB.x, y = data.offsetB.y }

            if true then
                local weights = mathutils.getMeanValueCoordinatesWeights(data.offsetB.x, data.offsetB.y, oldVertices)
                local newx, newy = mathutils.repositionPointUsingWeights(weights, newBody:getUserData().thing.vertices)

                data.offsetB.x = newx
                data.offsetB.y = newy
            end


            local after = { x = data.offsetB.x, y = data.offsetB.y }

            local ox, oy = data.otherBody:getPosition()
            local rx, ry = mathutils.rotatePoint(
                after.x - before.x, after.y - before.y, 0, 0, newBody:getAngle()
            )
            local id = data.otherBody:getUserData().thing.id
            if not visited[id] then
                visited[id] = true
                tranlateBody(data.otherBody, rx, ry)
                --data.otherBody:setPosition(ox + rx, oy + ry)
                moveUntilEnd(data.otherBody, rx, ry, visited, 'B')
            end


            -- if true then -- this pushes back the other way!
            --     local rx, ry = mathutils.rotatePoint(
            --         after.x - before.x, after.y - before.y, 0, 0, newBody:getAngle()
            --     )

            --     local nx, ny = newBody:getPosition()

            --     newBody:setPosition(nx - rx, ny - ry)
            -- end
        end


        local result = lib.createJoint(data)
    end
end

return lib

```

src//logger.lua
```lua
-- src/logger.lua
local inspect = require 'vendor.inspect'

local Logger = {}
Logger.__index = Logger

-- Store original print function safely
local _old_print = print

function Logger:new()
    local instance = setmetatable({}, Logger)
    -- You could add log levels, file output etc. here later
    return instance
end

-- Generic log function
function Logger:_log(level, ...)
    local info = debug.getinfo(3, "Sl") -- 3 levels up: _log -> info/warn/error -> caller
    local source = info.short_src or "unknown"
    local line = info.currentline > 0 and info.currentline or "?"
    -- Basic formatting
    local prefix = string.format("[%s] %s:%s:", level, source, line)
    -- Use the original print function for output
    _old_print(prefix, ...)
end

-- Specific level methods
--
--
function Logger:trace(...)
    self:_log("TRACE", debug.traceback(), ...)
end

function Logger:info(...)
    self:_log("INFO", ...)
end

function Logger:warn(...)
    self:_log("WARN", ...)
end

function Logger:error(...)
    self:_log("ERROR", ...)
end

function Logger:inspect(...)
    self:_log("INSPECT", inspect(...))
end

function Logger:debug(...)
    -- Add a flag check if you only want debug logs sometimes
    -- if DEBUG_ENABLED then
    self:_log("DEBUG", ...)
    -- end
end

return Logger

```

src//math-utils.lua
```lua
--math-utils.lua
local lib = {}



local function unpackNodePointsLoop(points)
    local unpacked = {}

    for i = 0, #points do
        local nxt = i == #points and 1 or i + 1
        unpacked[1 + (i * 2)] = points[nxt][1]
        unpacked[2 + (i * 2)] = points[nxt][2]
    end

    for i = 0, #points do
        local nxt = i == #points and 1 or i + 1
        unpacked[(#points * 2) + 1 + (i * 2)] = points[nxt][1]
        unpacked[(#points * 2) + 2 + (i * 2)] = points[nxt][2]
    end

    return unpacked
end

local function unpackNodePoints(points, noloop)
    local unpacked = {}
    if #points >= 1 then
        for i = 0, #points - 1 do
            unpacked[1 + (i * 2)] = points[i + 1][1]
            unpacked[2 + (i * 2)] = points[i + 1][2]
        end

        -- make it go round
        if noloop == nil then
            unpacked[(#points * 2) + 1] = points[1][1]
            unpacked[(#points * 2) + 2] = points[1][2]
        end
    end

    return unpacked
end

function lerp(a, b, t)
    return a + (b - a) * t
end

local function getDistance(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    local distance = math.sqrt((dx * dx) + (dy * dy))

    return distance
end

function lib.getLengthOfPath(path)
    local result = 0
    for i = 1, #path - 1 do
        local a = path[i]
        local b = path[i + 1]
        result = result + getDistance(a[1], a[2], b[1], b[2])
    end
    return result
end

local function evenlySpreadPath(result, path, index, running, spacing)
    -- Stop if there's no next segment
    if index >= #path then return end

    local here = path[index]
    local there = path[index + 1]

    local d = getDistance(here[1], here[2], there[1], there[2])

    -- Handle degenerate segment (zero length)
    if d == 0 then
        return evenlySpreadPath(result, path, index + 1, running, spacing)
    end

    while running < d do
        local t = running / d
        local x = lerp(here[1], there[1], t)
        local y = lerp(here[2], there[2], t)
        table.insert(result, { x, y, { 1, 0, 1 } })
        running = running + spacing
    end

    -- Carry leftover distance into next segment
    return evenlySpreadPath(result, path, index + 1, running - d, spacing)
end

--https://love2d.org/forums/viewtopic.php?t=1401
local function GetSplinePos(tab, percent, tension) --returns the position at 'percent' distance along the spline.
    if (tab and (#tab >= 4)) then
        local pos = (((#tab) / 2) - 1) * percent
        local lowpnt, percent_2 = math.modf(pos)

        local i = (1 + lowpnt * 2)
        local p1x = tab[i]
        local p1y = tab[i + 1]
        local p2x = tab[i + 2]
        local p2y = tab[i + 3]

        local p0x = tab[i - 2]
        local p0y = tab[i - 1]
        local p3x = tab[i + 4]
        local p3y = tab[i + 5]

        local tension = tension or .5
        local t1x = 0
        local t1y = 0
        if (p0x and p0y) then
            t1x = (1.0 - tension) * (p2x - p0x)
            t1y = (1.0 - tension) * (p2y - p0y)
        end
        local t2x = 0
        local t2y = 0
        if (p3x and p3y) then
            t2x = (1.0 - tension) * (p3x - p1x)
            t2y = (1.0 - tension) * (p3y - p1y)
        end

        local s = percent_2
        local s2 = s * s
        local s3 = s * s * s
        local h1 = 2 * s3 - 3 * s2 + 1
        local h2 = -2 * s3 + 3 * s2
        local h3 = s3 - 2 * s2 + s
        local h4 = s3 - s2
        local px = (h1 * p1x) + (h2 * p2x) + (h3 * t1x) + (h4 * t2x)
        local py = (h1 * p1y) + (h2 * p2y) + (h3 * t1y) + (h4 * t2y)

        return px, py
    end
end



lib.unloosenVanillaline = function(points, tension, spacing)
    local work = unpackNodePoints(points, true)
    local output = {}
    local amt = #points * 2
    for i = 0, amt do
        local t = (i / amt)
        if t >= 1 then t = 0.99999999 end
        if t == 0 then t = 0.00000001 end

        local x, y = GetSplinePos(work, t, tension)
        table.insert(output, { x, y })
    end
    --logger:inspect(output)
    local rrr = {}
    local r2 = evenlySpreadPath(rrr, output, 1, 0, spacing)

    output = unpackNodePoints(rrr)

    -- what a hack ! the end is not good it looped back and i dont know how to solve it
    -- in evenlyspreadpath....
    table.remove(output, #output)
    table.remove(output, #output)
    return output
end




function lib.makePolygonRelativeToCenter(polygon, centerX, centerY)
    -- Calculate the center


    -- Shift all points to make them relative to the center
    local relativePolygon = {}
    for i = 1, #polygon, 2 do
        local x = polygon[i] - centerX
        local y = polygon[i + 1] - centerY
        table.insert(relativePolygon, x)
        table.insert(relativePolygon, y)
    end

    return relativePolygon, centerX, centerY
end

function lib.makePolygonAbsolute(relativePolygon, newCenterX, newCenterY)
    local absolutePolygon = {}
    for i = 1, #relativePolygon, 2 do
        local x = relativePolygon[i] + newCenterX
        local y = relativePolygon[i + 1] + newCenterY
        table.insert(absolutePolygon, x)
        table.insert(absolutePolygon, y)
    end

    return absolutePolygon
end

function lib.getCenterOfPoints(points)
    local tlx = math.huge
    local tly = math.huge
    local brx = -math.huge
    local bry = -math.huge
    for ip = 1, #points, 2 do
        if points[ip + 0] < tlx then tlx = points[ip + 0] end
        if points[ip + 1] < tly then tly = points[ip + 1] end
        if points[ip + 0] > brx then brx = points[ip + 0] end
        if points[ip + 1] > bry then bry = points[ip + 1] end
    end
    --return tlx, tly, brx, bry
    local w = brx - tlx
    local h = bry - tly
    return tlx + w / 2, tly + h / 2, w, h
end

function lib.getPolygonDimensions(polygon)
    -- Initialize min and max values
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge

    -- Loop through the polygon's points
    for i = 1, #polygon, 2 do
        local x, y = polygon[i], polygon[i + 1]
        if x < minX then minX = x end
        if x > maxX then maxX = x end
        if y < minY then minY = y end
        if y > maxY then maxY = y end
    end

    -- Calculate width and height
    local width = maxX - minX
    local height = maxY - minY

    return width, height
end

function lib.getCenterOfPoints2(points)
    local tlx = math.huge
    local tly = math.huge
    local brx = -math.huge
    local bry = -math.huge
    for ip = 1, #points do
        local p = points[ip]
        if p.x < tlx then tlx = p.x end
        if p.y < tly then tly = p.y end
        if p.x > brx then brx = p.x end
        if p.y > bry then bry = p.y end
    end
    --return tlx, tly, brx, bry
    local w = brx - tlx
    local h = bry - tly
    return tlx + w / 2, tly + h / 2
end

local function getCenterOfShapeFixtures(fixts)
    local xmin = math.huge
    local ymin = math.huge
    local xmax = -math.huge
    local ymax = -math.huge
    for i = 1, #fixts do
        local it = fixts[i]
        if it:getUserData() then
        else
            local points = {}
            if (it:getShape().getPoints) then
                points = { it:getShape():getPoints() }
            else
                points = { it:getShape():getPoint() }
            end

            for j = 1, #points, 2 do
                local xx = points[j]
                local yy = points[j + 1]
                if xx < xmin then xmin = xx end
                if xx > xmax then xmax = xx end
                if yy < ymin then ymin = yy end
                if yy > ymax then ymax = yy end
            end
        end
    end
    return xmin + (xmax - xmin) / 2, ymin + (ymax - ymin) / 2
end

-- Utility function to check if a point is inside a polygon.
-- Implements the ray-casting algorithm.
local function pointInPath(x, y, poly)
    local inside = false
    local n = #poly
    for i = 1, n, 2 do
        local j = (i + 2) % n
        if j == 0 then j = n end
        local xi, yi = poly[i], poly[i + 1]
        local xj, yj = poly[j], poly[j + 1]

        local intersect = ((yi > y) ~= (yj > y)) and
            (x < (xj - xi) * (y - yi) / (yj - yi + 1e-10) + xi)
        if intersect then
            inside = not inside
        end
    end
    return inside
end

function lib.pointInRect(px, py, rect)
    return px >= rect.x and px <= (rect.x + rect.width) and
        py >= rect.y and py <= (rect.y + rect.height)
end

function lib.getCorners(polygon)
    if #polygon ~= 8 then
        logger:error("getCorners expects a polygon with exactly 4 vertices (8 numbers)")
        return nil, nil, nil, nil
    end

    local vertices = {}
    for i = 1, #polygon, 2 do
        table.insert(vertices, { x = polygon[i], y = polygon[i + 1], id = (i + 1) / 2 })
    end

    local cx, cy = 0, 0
    for i = 1, #vertices do
        cx = cx + vertices[i].x
        cy = cy + vertices[i].y
    end
    cx = cx / #vertices
    cy = cy / #vertices

    local corners = { tl = nil, tr = nil, br = nil, bl = nil }

    for _, v in ipairs(vertices) do
        local angle = math.atan2(v.y - cy, v.x - cx)

        -- Define angle boundaries for quadrants more cleanly (radians)
        local pi_2 = math.pi / 2                      -- 90 degrees

        if angle > -math.pi and angle <= -pi_2 then   -- (-180, -90] degrees --> Top-Left Quad III
            corners.tl = v
        elseif angle > -pi_2 and angle <= 0 then      -- (-90, 0] degrees --> Top-Right Quad IV
            corners.tr = v
        elseif angle > 0 and angle <= pi_2 then       -- (0, 90] degrees --> Bottom-Right Quad I
            corners.br = v
        elseif angle > pi_2 and angle <= math.pi then -- (90, 180] degrees --> Bottom-Left Quad II
            corners.bl = v
        else
            -- Should not happen with atan2 range
            logger:error(string.format("Warning: Vertex angle %.2f rad (%.1f deg) out of expected range (-pi, pi].",
                angle,
                math.deg(angle)))
        end
    end


    local assigned_count = 0
    if corners.tl then assigned_count = assigned_count + 1 end
    if corners.tr then assigned_count = assigned_count + 1 end
    if corners.br then assigned_count = assigned_count + 1 end
    if corners.bl then assigned_count = assigned_count + 1 end

    -- Check for duplicate assignments (same vertex assigned to multiple corners)
    local assignments = {}
    local duplicates = false
    for _, corner_v in pairs(corners) do
        if corner_v then
            if assignments[corner_v.id] then
                duplicates = true
                logger:error(string.format("Warning: Duplicate assignment for vertex ID %d", corner_v.id))
                break
            end
            assignments[corner_v.id] = true
        end
    end


    if assigned_count ~= 4 or duplicates then
        logger:error("Warning: Could not assign all 4 corners uniquely using angle quadrants.")
        -- This indicates the angle logic is insufficient for the shape/orientation
        -- A fallback or more complex geometric analysis might be needed.
    end

    return corners.tl, corners.tr, corners.br, corners.bl
end

function lib.getBoundingRect(polygon)
    local min_x, min_y = polygon[1], polygon[2]
    local max_x, max_y = polygon[1], polygon[2]
    for i = 3, #polygon, 2 do
        local x, y = polygon[i], polygon[i + 1]
        if x < min_x then min_x = x end
        if y < min_y then min_y = y end
        if x > max_x then max_x = x end
        if y > max_y then max_y = y end
    end
    return { x = min_x, y = min_y, width = max_x - min_x, height = max_y - min_y }
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
function lib.findClosestEdge(verts, px, py)
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

function lib.findClosestVertex(verts, px, py)
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

function lib.normalizeAxis(x, y)
    local magnitude = math.sqrt(x ^ 2 + y ^ 2)
    if magnitude == 0 then
        return 1, 0 -- Default to (1, 0) if the vector is zero
    else
        --   print('normalizing', x / magnitude, y / magnitude)
        return x / magnitude, y / magnitude
    end
end

function lib.calculateDistance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

function lib.computeCentroid(polygon)
    return lib.getCenterOfPoints(polygon)


    -- this is not a  correct way of doing it!!!!
    -- local sumX, sumY = 0, 0
    -- for i = 1, #polygon, 2 do
    --     --for _, vertex in ipairs(vertices) do
    --     sumX = sumX + polygon[i]
    --     sumY = sumY + polygon[i + 1]
    --     -- end
    -- end
    -- local count = (#polygon / 2)
    -- return sumX / count, sumY / count
end

function lib.rotatePoint(x, y, originX, originY, angle)
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

function lib.localVerts(obj)
    if not obj.vertices then
        error('obj needs vertices if you want to do stuff with them')
    end
    local cx, cy = lib.computeCentroid(obj.vertices)
    return lib.getLocalVerticesForCustomSelected(obj.vertices, obj, cx, cy)
end

function lib.getLocalVerticesForCustomSelected(vertices, obj, cx, cy)
    local verts = vertices
    local offX, offY = obj.body:getPosition()
    local angle = obj.body:getAngle()
    local result = {}

    for i = 1, #verts, 2 do
        local rx, ry = lib.rotatePoint(verts[i] - cx, verts[i + 1] - cy, 0, 0, angle)
        local vx, vy = offX + rx, offY + ry
        table.insert(result, vx)
        table.insert(result, vy)
    end
    return result
end

-- Function to convert world coordinates to local coordinates of a shape
function lib.worldToLocal(worldX, worldY, angle, cx, cy)
    -- Get the body's position and angle
    -- local offX, offY = obj.body:getPosition()
    --local angle = obj.body:getAngle()

    -- Step 1: Translate the world point to the body's origin
    local translatedX = worldX -- offX
    local translatedY = worldY -- offY

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

-- Function to remove a vertex from the table based on its vertex index
-- verts: flat list {x1, y1, x2, y2, ...}
-- vertexIndex: the index of the vertex to remove (1, 2, 3, ...)
function lib.removeVertexAt(verts, vertexIndex)
    local posX = (vertexIndex - 1) * 2 + 1
    local posY = posX + 1

    -- Remove y-coordinate first to prevent shifting issues
    table.remove(verts, posY)
    table.remove(verts, posX)
end

function lib.insertValuesAt(tbl, pos, val1, val2)
    table.insert(tbl, pos, val1)
    table.insert(tbl, pos + 1, val2)
end

-- decompose_complex.lua
-- A module for decomposing complex polygons into simpler polygons by handling intersections.



-- Function to find the intersection point between two line segments.
local function getLineIntersection(p0_x, p0_y, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y)
    local s1_x = p1_x - p0_x
    local s1_y = p1_y - p0_y
    local s2_x = p3_x - p2_x
    local s2_y = p3_y - p2_y

    local denom = (-s2_x * s1_y + s1_x * s2_y)
    if denom == 0 then return nil end -- Parallel lines

    local s = (-s1_y * (p0_x - p2_x) + s1_x * (p0_y - p2_y)) / denom
    local t = (s2_x * (p0_y - p2_y) - s2_y * (p0_x - p2_x)) / denom

    if s >= 0 and s <= 1 and t >= 0 and t <= 1 then
        local intersect_x = p0_x + (t * s1_x)
        local intersect_y = p0_y + (t * s1_y)
        return intersect_x, intersect_y
    end

    return nil
end

-- Function to find all collision points (intersections) within a polygon.
local function getCollisions(poly)
    local collisions = {}
    local n = #poly

    for outeri = 1, n, 2 do
        local ax, ay = poly[outeri], poly[outeri + 1]
        local ni = outeri + 2
        if ni > n then ni = 1 end
        local bx, by = poly[ni], poly[ni + 1]

        for inneri = 1, n, 2 do
            -- Skip adjacent edges
            if inneri ~= outeri and inneri ~= ((outeri + 2 - 1) % n) + 1 then
                local cx, cy = poly[inneri], poly[inneri + 1]
                local ni_inner = inneri + 2
                if ni_inner > n then ni_inner = 1 end
                local dx, dy = poly[ni_inner], poly[ni_inner + 1]

                local ix, iy = getLineIntersection(ax, ay, bx, by, cx, cy, dx, dy)
                if ix and iy then
                    -- Avoid adding shared vertices as intersections
                    if not ((ax == cx and ay == cy) or (ax == dx and ay == dy) or
                            (bx == cx and by == cy) or (bx == dx and by == dy)) then
                        local collision = { i1 = outeri, i2 = inneri, x = ix, y = iy }
                        -- Check for duplicate collisions
                        local duplicate = false
                        for _, existing in ipairs(collisions) do
                            if (existing.i1 == collision.i2 and existing.i2 == collision.i1) then
                                duplicate = true
                                break
                            end
                        end
                        if not duplicate then
                            table.insert(collisions, collision)
                        end
                    end
                end
            end
        end
    end

    return collisions
end


local function tableConcat(t1, t2)
    for i = 1, #t2 do
        table.insert(t1, t2[i])
    end
    return t1
end

function lib.decompose(poly, result)
    result = result or {}
    local intersections = getCollisions(poly)

    if #intersections == 0 then
        tableConcat(result, { poly })
        return result
    end

    -- Process only the first intersection to avoid redundant splits
    local intersection = intersections[1]

    local p1, p2 = lib.splitPoly(poly, intersection)

    -- Recursively decompose the resulting polygons
    lib.decompose(p1, result)
    lib.decompose(p2, result)

    return result
end

---


---

-- for the boyonce i prolly need thi algo:
-- http://rosettacode.org/wiki/Sutherland-Hodgman_polygon_clipping#Lua
-- http://rosettacode.org/wiki/Sutherland-Hodgman_polygon_clipping#JavaScript

function inside(p, cp1, cp2)
    return (cp2.x - cp1.x) * (p.y - cp1.y) > (cp2.y - cp1.y) * (p.x - cp1.x)
end

function intersection(cp1, cp2, s, e)
    local dcx, dcy = cp1.x - cp2.x, cp1.y - cp2.y
    local dpx, dpy = s.x - e.x, s.y - e.y
    local n1 = cp1.x * cp2.y - cp1.y * cp2.x
    local n2 = s.x * e.y - s.y * e.x
    local n3 = 1 / (dcx * dpy - dcy * dpx)
    local x = (n1 * dpx - n2 * dcx) * n3
    local y = (n1 * dpy - n2 * dcy) * n3
    return { x = x, y = y }
end

function lib.polygonClip(subjectPolygon, clipPolygon)
    local outputList = subjectPolygon
    local cp1 = clipPolygon[#clipPolygon]
    for _, cp2 in ipairs(clipPolygon) do -- WP clipEdge is cp1,cp2 here
        local inputList = outputList
        outputList = {}
        local s = inputList[#inputList]
        for _, e in ipairs(inputList) do
            if inside(e, cp1, cp2) then
                if not inside(s, cp1, cp2) then
                    outputList[#outputList + 1] = intersection(cp1, cp2, s, e)
                end
                outputList[#outputList + 1] = e
            elseif inside(s, cp1, cp2) then
                outputList[#outputList + 1] = intersection(cp1, cp2, s, e)
            end
            s = e
        end
        cp1 = cp2
    end
    return outputList
end

function lib.findIntersections(polygon, line)
    local intersections = {}
    local n = #polygon / 2 -- Number of vertices

    for i = 1, n do
        local j = (i % n) + 1 -- Next vertex index (wrap around)

        -- Current edge points
        local x1, y1 = polygon[(i - 1) * 2 + 1], polygon[(i - 1) * 2 + 2]
        local x2, y2 = polygon[(j - 1) * 2 + 1], polygon[(j - 1) * 2 + 2]

        -- Line to check against
        local lx1, ly1, lx2, ly2 = line.x1, line.y1, line.x2, line.y2

        -- Get intersection point
        local Px, Py = getLineIntersection(x1, y1, x2, y2, lx1, ly1, lx2, ly2)

        if Px and Py then
            -- Check for duplicates
            local duplicate = false
            for _, inter in ipairs(intersections) do
                if math.abs(inter.x - Px) < 1e-6 and math.abs(inter.y - Py) < 1e-6 then
                    duplicate = true
                    break
                end
            end

            if not duplicate then
                table.insert(intersections, { x = Px, y = Py, i1 = i, i2 = j })
            end
        end
    end

    return intersections
end

-- Function to split a polygon into two at a single given intersection point.
-- this is used to fix self-intersecting polygons
function lib.splitPoly(poly, intersection)
    local function getIndices()
        local biggestIndex = math.max(intersection.i1, intersection.i2)
        local smallestIndex = math.min(intersection.i1, intersection.i2)
        return smallestIndex, biggestIndex
    end

    local smallestIndex, biggestIndex = getIndices()
    local wrap = {}
    local back = {}
    local bb = biggestIndex

    -- Build the 'wrap' polygon
    while bb ~= smallestIndex do
        bb = bb + 2
        if bb > #poly - 1 then
            bb = 1
        end
        table.insert(wrap, poly[bb])
        table.insert(wrap, poly[bb + 1])
    end
    table.insert(wrap, intersection.x)
    table.insert(wrap, intersection.y)

    -- Build the 'back' polygon
    local bk = biggestIndex
    while bk ~= smallestIndex do
        table.insert(back, poly[bk])
        table.insert(back, poly[bk + 1])
        bk = bk - 2
        if bk < 1 then
            bk = #poly - 1
        end
    end
    table.insert(back, intersection.x)
    table.insert(back, intersection.y)

    return wrap, back
end

-- Add or replace this function in your existing math-utils.lua
-- Function to slice a polygon with a line defined by points p1 and p2

-- polygon = {
--         100, 100,
--         300, 100,
--         200, 200,
--         100, 200,
--     }

--     polygon = {
--         100, 100,
--         -300, 300,
--         300, 300,
--     }

--     polygon = {
--         100, 100, -- Vertex 1
--         200, 100, -- Vertex 2
--         200, 150, -- Vertex 3
--         150, 150, -- Vertex 4 (inward dent)
--         150, 200, -- Vertex 5
--         100, 200, -- Vertex 6
--     }

-- Define slicing points (horizontal line at y = 150)

-- Define slicing points
-- local p1 = { x = -5000, y = 150 }
-- local p2 = { x = 5000, y = 150 }


-- polygon = {
--     0, -100,    -- Vertex 1
--     23, -30,    -- Vertex 2
--     100, -30,   -- Vertex 3
--     38, 10,     -- Vertex 4
--     59, 80,     -- Vertex 5
--     0, 40,      -- Vertex 6
--     -59, 80,    -- Vertex 7
--     -38, 10,    -- Vertex 8
--     -100, -30,  -- Vertex 9
--     -23, -30,   -- Vertex 10
-- }

-- -- Define slicing points (diagonal line)
-- local p1 = { x = -150, y = 150 }
-- local p2 = { x = 150, y = -150 }



function lib.slicePolygon(polygon, p1, p2)
    -- p1 and p2 define the slicing line: {x = ..., y = ...}

    -- Step 1: Find intersection points between the slice line and the polygon
    local sliceLine = { x1 = p1.x, y1 = p1.y, x2 = p2.x, y2 = p2.y }
    local intersections = lib.findIntersections(polygon, sliceLine)


    for _, inter in ipairs(intersections) do
        --     print(string.format("Intersection at (%.2f, %.2f) on edge %d-%d", inter.x, inter.y, inter.i1, inter.i2))
    end

    -- Ensure there are at least two unique intersection points
    if #intersections < 2 then
        return { polygon } -- Return the original polygon as a single-element table
    end

    -- Step 2: Sort intersections based on their order along the slice line
    local function sortByDistance(a, b)
        local dx = sliceLine.x2 - sliceLine.x1
        local dy = sliceLine.y2 - sliceLine.y1
        local distanceA = (a.x - sliceLine.x1) * dx + (a.y - sliceLine.y1) * dy
        local distanceB = (b.x - sliceLine.x1) * dx + (b.y - sliceLine.y1) * dy
        return distanceA < distanceB
    end
    table.sort(intersections, sortByDistance)

    -- Step 3: Select two unique intersection points
    local uniqueIntersections = {}
    local threshold = 1e-6
    for _, inter in ipairs(intersections) do
        local isUnique = true
        for _, unique in ipairs(uniqueIntersections) do
            if math.abs(inter.x - unique.x) < threshold and math.abs(inter.y - unique.y) < threshold then
                isUnique = false
                break
            end
        end
        if isUnique then
            table.insert(uniqueIntersections, inter)
            if #uniqueIntersections == 2 then break end
        end
    end

    if #uniqueIntersections < 2 then
        logger:error("Not enough unique intersections to slice the polygon.")
        return { polygon }
    end

    local inter1, inter2 = uniqueIntersections[1], uniqueIntersections[2]

    -- Step 4: Insert intersection points into the polygon's vertex list
    -- To prevent index shifting issues, insert the intersection points in descending order of their insertion positions

    -- Determine insertion positions
    -- inter.i1 is the index of the first vertex of the edge where the intersection occurs
    local insertPos1 = inter1.i1 * 2 -- Position in the flat array
    local insertPos2 = inter2.i1 * 2 -- Position in the flat array

    -- Sort insertion positions in descending order
    if insertPos1 < insertPos2 then
        insertPos1, insertPos2 = insertPos2, insertPos1
        inter1, inter2 = inter2, inter1
    end

    -- Insert inter1 first
    lib.insertValuesAt(polygon, insertPos1 + 1, inter1.x, inter1.y)
    -- Insert inter2 next
    lib.insertValuesAt(polygon, insertPos2 + 1, inter2.x, inter2.y)

    -- Step 5: Find the new indices of the inserted intersection points
    local function findVertexIndex(x, y)
        for i = 1, #polygon, 2 do
            if math.abs(polygon[i] - x) < threshold and math.abs(polygon[i + 1] - y) < threshold then
                return (i + 1) / 2 -- Convert flat index to vertex index (1-based)
            end
        end
        return nil
    end

    local newInter1Index = findVertexIndex(inter1.x, inter1.y)
    local newInter2Index = findVertexIndex(inter2.x, inter2.y)

    if not newInter1Index or not newInter2Index then
        logger:error("Failed to find the new intersection indices after insertion.")
        return { polygon }
    end

    -- Step 6: Traverse the polygon to create two new polygons
    local function traverse(polygon, startIdx, endIdx, direction)
        local result = {}
        local n = #polygon / 2
        local idx = startIdx

        while true do
            table.insert(result, polygon[(idx - 1) * 2 + 1])
            table.insert(result, polygon[(idx - 1) * 2 + 2])

            if idx == endIdx then
                break
            end

            if direction == "clockwise" then
                idx = idx % n + 1
            else
                idx = (idx - 2) % n + 1
            end
        end

        return result
    end

    -- Create first polygon: traverse from inter1 to inter2 clockwise
    local poly1 = traverse(polygon, newInter1Index, newInter2Index, "clockwise")
    -- Create second polygon: traverse from inter2 to inter1 clockwise
    local poly2 = traverse(polygon, newInter2Index, newInter1Index, "clockwise")

    -- At this point, poly1 and poly2 already include the intersection points
    -- There's no need to append inter1 and inter2 again, as it causes duplication


    return { poly1, poly2 }
end

function lib.getMeanValueCoordinatesWeights(px, py, poly)
    local n = #poly / 2 -- number of vertices
    local weights = {}
    local weightSum = 0
    local epsilon = 1e-10
    -- Loop over each vertex of the polygon
    for i = 1, n do
        -- Get current, previous, and next vertex indices (wrapping around)
        local i_prev = (i - 2) % n + 1
        local i_next = (i % n) + 1

        -- Current vertex coordinates
        local xi = poly[2 * i - 1]
        local yi = poly[2 * i]
        -- Previous vertex coordinates
        local xprev = poly[2 * i_prev - 1]
        local yprev = poly[2 * i_prev]
        -- Next vertex coordinates
        local xnext = poly[2 * i_next - 1]
        local ynext = poly[2 * i_next]

        -- Vectors from point p to current, previous, and next vertices
        local dx = xi - px
        local dy = yi - py
        local d = math.sqrt(dx * dx + dy * dy)

        local dx_prev = xprev - px
        local dy_prev = yprev - py
        -- local d_prev = math.sqrt(dx_prev * dx_prev + dy_prev * dy_prev)

        local dx_next = xnext - px
        local dy_next = ynext - py
        -- local d_next = math.sqrt(dx_next * dx_next + dy_next * dy_next)

        local d = math.sqrt(dx * dx + dy * dy) + 1e-10
        local d_prev = math.sqrt(dx_prev * dx_prev + dy_prev * dy_prev) + 1e-10
        local d_next = math.sqrt(dx_next * dx_next + dy_next * dy_next) + 1e-10

        -- Angles between vectors
        local angle_prev = math.acos((dx * dx_prev + dy * dy_prev) / (d * d_prev))
        local angle_next = math.acos((dx * dx_next + dy * dy_next) / (d * d_next))

        -- Mean value weight for vertex i
        local tan_prev = math.tan(angle_prev / 2)
        local tan_next = math.tan(angle_next / 2)

        -- Avoid division by zero if point p coincides with a vertex
        if d == 0 then
            -- p is at vertex i
            for j = 1, n do
                weights[j] = 0
            end
            weights[i] = 1
            return weights
        end

        local w = (tan_prev + tan_next) / d
        weights[i] = w
        weightSum = weightSum + w
    end

    -- Normalize weights so they sum to 1
    for i = 1, n do
        weights[i] = weights[i] / weightSum
    end

    return weights
end

function lib.repositionPointUsingWeights(weights, newPolygon)
    local newX, newY = 0, 0
    local n = #newPolygon / 2
    for i = 1, n do
        local wx = newPolygon[2 * i - 1]
        local wy = newPolygon[2 * i]
        newX = newX + weights[i] * wx
        newY = newY + weights[i] * wy
    end
    return newX, newY
end

function lib.closestEdgeParams(px, py, poly)
    local n = #poly / 2
    local best = {
        edgeIndex = nil,
        t = 0,
        distance = math.huge,
        sign = 1
    }

    for i = 1, n do
        local j = (i % n) + 1 -- next vertex index wrapping around

        local x1, y1 = poly[2 * i - 1], poly[2 * i]
        local x2, y2 = poly[2 * j - 1], poly[2 * j]

        -- Edge vector
        local ex = x2 - x1
        local ey = y2 - y1
        local edgeLength2 = ex * ex + ey * ey

        -- Vector from vertex i to point
        local dx = px - x1
        local dy = py - y1

        -- Project (dx, dy) onto edge to find parameter t
        local t = 0
        if edgeLength2 > 0 then
            t = (dx * ex + dy * ey) / edgeLength2
        end

        -- Clamp t to [0,1] to stay within the segment
        local clampedT = math.max(0, math.min(1, t))

        -- Closest point on edge to (px,py)
        local projX = x1 + clampedT * ex
        local projY = y1 + clampedT * ey

        -- Distance from point to projection
        local distX = px - projX
        local distY = py - projY
        local dist = math.sqrt(distX * distX + distY * distY)

        if dist < best.distance then
            -- Determine side (sign) of the edge using cross product:
            local cross = ex * dy - ey * dx
            local sign = (cross >= 0) and 1 or -1

            best.edgeIndex = i
            best.t = clampedT
            best.distance = dist
            best.sign = sign
        end
    end

    return best
end

function lib.repositionPointClosestEdge(params, newPoly)
    local n = #newPoly / 2

    if not params.edgeIndex or params.edgeIndex < 1 or params.edgeIndex > n then
        return nil, nil
    end

    local i = params.edgeIndex
    local j = (i % n) + 1

    local x1, y1 = newPoly[2 * i - 1], newPoly[2 * i]
    local x2, y2 = newPoly[2 * j - 1], newPoly[2 * j]

    local ex = x2 - x1
    local ey = y2 - y1
    local projX = x1 + params.t * ex
    local projY = y1 + params.t * ey

    local length = math.sqrt(ex * ex + ey * ey)
    if length == 0 then
        return projX, projY
    end

    -- Standard OUTWARD normal for CCW polygon: (dy, -dx) / length
    local nx = ey / length
    local ny = -ex / length

    -- Apply the formula: Proj + sign * distance * Normal
    -- The 'sign' from closestEdgeParams directly multiplies the normal offset
    local newX = projX + params.sign * params.distance * nx
    local newY = projY + params.sign * params.distance * ny

    return newX, newY
end

function lib.findEdgeAndLerpParam(px, py, poly)
    local n = #poly / 2
    local best = {
        edgeIndex = nil,
        t = 0,
        minDist = math.huge
    }

    for i = 1, n do
        local j = (i % n) + 1 -- next vertex index (wrap-around)

        local x1, y1 = poly[2 * i - 1], poly[2 * i]
        local x2, y2 = poly[2 * j - 1], poly[2 * j]

        -- Edge vector
        local ex = x2 - x1
        local ey = y2 - y1
        local edgeLength2 = ex * ex + ey * ey

        -- Vector from vertex i to point
        local dx = px - x1
        local dy = py - y1

        -- Project (dx, dy) onto the edge to find parameter t
        local t = 0
        if edgeLength2 > 0 then
            t = (dx * ex + dy * ey) / edgeLength2
        end

        -- Clamp t to [0,1]
        local clampedT = math.max(0, math.min(1, t))

        -- Closest point on edge to (px, py)
        local projX = x1 + clampedT * ex
        local projY = y1 + clampedT * ey

        -- Distance from point to projected point
        local distX = px - projX
        local distY = py - projY
        local dist = distX * distX + distY * distY -- squared distance for comparison

        if dist < best.minDist then
            best.minDist = dist
            best.edgeIndex = i
            best.t = clampedT
        end
    end

    return best.edgeIndex, best.t
end

function lib.lerpOnEdge(edgeIndex, t, newPoly)
    local n = #newPoly / 2
    if not edgeIndex or edgeIndex < 1 or edgeIndex > n then
        return nil, nil
    end

    local i = edgeIndex
    local j = (i % n) + 1 -- next vertex index (wrap-around)

    local x1, y1 = newPoly[2 * i - 1], newPoly[2 * i]
    local x2, y2 = newPoly[2 * j - 1], newPoly[2 * j]

    -- Linear interpolation between vertices using t
    local newX = (1 - t) * x1 + t * x2
    local newY = (1 - t) * y1 + t * y2

    return newX, newY
end

local function getCenterOfShapeFixtures(fixts)
    local xmin = math.huge
    local ymin = math.huge
    local xmax = -math.huge
    local ymax = -math.huge
    for i = 1, #fixts do
        local it = fixts[i]
        if it:getUserData() then
        else
            local points = {}
            if (it:getShape().getPoints) then
                points = { it:getShape():getPoints() }
            else
                points = { it:getShape():getPoint() }
            end
            --print(inspect(points))
            for j = 1, #points, 2 do
                local xx = points[j]
                local yy = points[j + 1]
                if xx < xmin then xmin = xx end
                if xx > xmax then xmax = xx end
                if yy < ymin then ymin = yy end
                if yy > ymax then ymax = yy end
            end
        end
    end
    return xmin + (xmax - xmin) / 2, ymin + (ymax - ymin) / 2
end

-- end experiemnt

return lib

```

src//object-manager.lua
```lua
-- object-manager.lua
local lib = {}
local shapes = require 'src.shapes'
local uuid = require 'src.uuid'
local registry = require 'src.registry'
local joints = require 'src.joints'
local jointHandlers = require 'src.joint-handlers'
local inspect = require 'vendor.inspect'
local utils = require 'src.utils'
local mathutils = require 'src.math-utils'
local fixtures = require 'src.fixtures'
local snap = require 'src.snap'
local blob = require 'vendor.loveblobs'
local state = require 'src.state'

function lib.finalizePolygonAsSoftSurface()
    if #state.interaction.polyVerts >= 6 then
        local points = state.interaction.polyVerts
        local b = blob.softsurface(state.physicsWorld, points, 120, "dynamic")
        table.insert(state.world.softbodies, b)
        b:setJointFrequency(10)
        b:setJointDamping(10)
    end
    logger:warn('blob surface wanted instead?')
    -- Reset the drawing state

    state.currentMode = nil
    state.interaction.capturingPoly = false
    state.interaction.polyVerts = {}
    state.interaction.lastPolyPt = nil
end

function lib.finalizePolygon()
    if #state.interaction.polyVerts >= 6 then
        local cx, cy = mathutils.computeCentroid(state.interaction.polyVerts)
        --local cx, cy = mathutils.getCenterOfPoints(state.interaction.polyVerts)
        local settings = {
            x = cx,
            y = cy,
            bodyType = state.editorPreferences.nextType,
            vertices = state.interaction
                .polyVerts
        }
        -- objectManager.addThing('custom', cx, cy, state.editorPreferences.nextType, nil, nil, nil, nil, '', state.interaction.polyVerts)
        lib.addThing('custom', settings)
    else
        -- Not enough vertices to form a polygon
        logger:error("Not enough vertices to create a polygon.")
    end
    -- Reset the drawing state

    state.currentMode = nil
    state.interaction.capturingPoly = false
    state.interaction.polyVerts = {}
    state.interaction.lastPolyPt = nil
end

function lib.insertCustomPolygonVertex(x, y)
    local obj = state.selection.selectedObj
    if obj then
        local offx, offy = obj.body:getPosition()
        local px, py = mathutils.worldToLocal(x - offx, y - offy, obj.body:getAngle(), state.polyEdit.centroid.x,
            state.polyEdit.centroid.y)
        -- Find the closest edge index
        local insertAfterVertexIndex = mathutils.findClosestEdge(state.polyEdit.tempVerts, px, py)
        mathutils.insertValuesAt(state.polyEdit.tempVerts, insertAfterVertexIndex * 2 + 1, px, py)
    end
end

-- Function to remove a custom polygon vertex based on mouse click
function lib.removeCustomPolygonVertex(x, y)
    -- Step 1: Convert world coordinates to local coordinates

    local obj = state.selection.selectedObj
    if obj then
        local offx, offy = obj.body:getPosition()
        local px, py = mathutils.worldToLocal(x - offx, y - offy, obj.body:getAngle(),
            state.polyEdit.centroid.x, state.polyEdit.centroid.y)

        -- Step 2: Find the closest vertex index
        local closestVertexIndex = mathutils.findClosestVertex(state.polyEdit.tempVerts, px, py)

        if closestVertexIndex then
            -- Optional: Define a maximum allowable distance to consider for deletion
            local maxDeletionDistanceSq = 100 -- Adjust as needed (e.g., 10 units squared)
            local vx = state.polyEdit.tempVerts[(closestVertexIndex - 1) * 2 + 1]
            local vy = state.polyEdit.tempVerts[(closestVertexIndex - 1) * 2 + 2]
            local dx = px - vx
            local dy = py - vy
            local distSq = dx * dx + dy * dy

            if distSq <= maxDeletionDistanceSq then
                -- Step 3: Remove the vertex from the vertex list

                -- Step 4: Ensure the polygon has a minimum number of vertices (e.g., 3)
                if #state.polyEdit.tempVerts <= 6 then
                    logger:error("Cannot delete vertex: A polygon must have at least three vertices.")
                    -- Optionally, you can restore the removed vertex or prevent deletion
                    return
                end
                mathutils.removeVertexAt(state.polyEdit.tempVerts, closestVertexIndex)
                lib.maybeUpdateCustomPolygonVertices()

                -- Debugging Output
                logger:info(string.format("Removed vertex at local coordinates: (%.2f, %.2f)", vx, vy))
            else
                logger:error("No vertex close enough to delete.")
            end
        else
            logger:error("No vertex found to delete.")
        end
    end
end

function lib.maybeUpdateCustomPolygonVertices()
    if not utils.tablesEqualNumbers(state.polyEdit.tempVerts, state.selection.selectedObj.vertices) then
        local nx, ny = mathutils.computeCentroid(state.polyEdit.tempVerts)
        local ox, oy = mathutils.computeCentroid(state.selection.selectedObj.vertices)
        local dx = nx - ox
        local dy = ny - oy
        local body = state.selection.selectedObj.body
        local dx2, dy2 = mathutils.rotatePoint(dx, dy, 0, 0, body:getAngle())
        local oldX, oldY = body:getPosition()

        body:setPosition(oldX + dx2, oldY + dy2)

        state.selection.selectedObj = lib.recreateThingFromBody(body,
            { optionalVertices = state.polyEdit.tempVerts })

        state.polyEdit.tempVerts = utils.shallowCopy(state.selection.selectedObj.vertices)
        -- state.selection.selectedObj.vertices = state.polyEdit.tempVerts
        state.polyEdit.centroid = { x = nx, y = ny }
    end
end

function lib.maybeUpdateTexFixtureVertices()
    --print('we need todo stuff here!')
    local points = { state.selection.selectedSFixture:getShape():getPoints() }


    local oldUD = utils.shallowCopy(state.selection.selectedSFixture:getUserData())
    local body = state.selection.selectedSFixture:getBody()
    state.selection.selectedSFixture:destroy()

    local centerX, centerY = mathutils.getCenterOfPoints(points)
    local shape = love.physics.newPolygonShape(state.texFixtureEdit.tempVerts)
    local newfixture = love.physics.newFixture(body, shape)
    newfixture:setSensor(true) -- Sensor so it doesn't collide

    newfixture:setUserData(oldUD)

    state.selection.selectedSFixture = newfixture
    --snap.updateFixture(newfixture)
    registry.registerSFixture(oldUD.id, newfixture)
    --snap.rebuildSnapFixtures(registry.sfixtures)
end

-- Helper function to collect all connected bodies
local function collectBodies(thing, collected)
    collected = collected or {}
    if not thing or not thing.body or collected[thing.id] then
        return collected
    end
    collected[thing.id] = thing.body
    for _, joint in ipairs(thing.body:getJoints()) do
        local bodyA, bodyB = joint:getBodies()
        local otherBody = (bodyA == thing.body) and bodyB or bodyA
        local otherThing = otherBody:getUserData() and otherBody:getUserData().thing
        if otherThing then
            collectBodies(otherThing, collected)
        end
    end
    return collected
end

-- Helper function to create and configure a physics body with shapes
local function createThing(shapeType, conf)
    --local function createThing(shapeType, x, y, bodyType, radius, width, width2, height, label, optionalVertices)
    -- Initialize default values
    bodyType = bodyType or 'dynamic'
    -- radius = radius or 20         -- Default radius for circular shapes
    -- width = width or radius * 2   -- Default width for polygonal shapes
    -- width2 = width2 or radius * 2 -- Default width for polygonal shapes
    -- height = height or radius * 2 -- Default height for polygonal shapes
    --label = label or "" -- Default label

    -- Create the physics body at the specified world coordinates
    local body = love.physics.newBody(state.physicsWorld, conf.x or 0, conf.y or 0, bodyType)

    local settings = {
        radius = conf.radius,
        width = conf.width,
        width2 = conf.width2,
        width3 = conf.width3,
        height = conf.height,
        height2 = conf.height2,
        height3 = conf.height3,
        height4 = conf.height4,
        optionalVertices = conf.vertices or nil, --optionalVertices
        --shape8URL = conf.shape8URL

    }
    local shapeList, vertices = shapes.createShape(shapeType, settings)

    if not shapeList then
        logger:error("Failed to create shapes for:", shapeType)
        return nil
    end

    -- Attach fixtures to the body for each shape
    for _, shape in ipairs(shapeList) do
        local fixture = love.physics.newFixture(body, shape, 1)
        fixture:setRestitution(0.3) -- Set bounciness
    end

    -- Configure body properties
    body:setAwake(true)

    -- Create the 'thing' table to store properties
    local thing = {
        shapeType = shapeType,
        radius = settings.radius,
        width = settings.width,
        width2 = settings.width2,
        width3 = settings.width3,
        height = settings.height,
        height2 = settings.height2,
        height3 = settings.height3,
        height4 = settings.height4,
        label = conf.label or '',
        mirrorX = conf.mirrorX or 1,
        mirrorY = conf.mirrorY or 1,
        body = body,
        shapes = shapeList,
        vertices = vertices, -- Store vertices if needed
        -- textures = { bgURL = '', bgEnabled = false, bgHex = 'ffffffff' },
        zOffset = 0,
        id = uuid.generateID(),
    }

    -- Set user data for easy access
    body:setUserData({ thing = thing })

    -- Register the body in the registry
    registry.registerBody(thing.id, body)

    return thing
end

function lib.startSpawn(shapeType, wx, wy)
    local radius = tonumber(state.editorPreferences.lastUsedRadius) or 10
    local width = tonumber(state.editorPreferences.lastUsedWidth) or radius * 2     -- Default width for polygons
    local width2 = tonumber(state.editorPreferences.lastUsedWidth2) or radius * 2.3 -- Default width for polygons
    local width3 = tonumber(state.editorPreferences.lastUsedWidth3) or radius * 2.3 -- Default width for polygons

    local height = tonumber(state.editorPreferences.lastUsedHeight) or
        radius * 2 -- Default height for polygons
    local height2 = tonumber(state.editorPreferences.lastUsedHeight2) or
        radius * 2 -- Default height for polygons
    local height3 = tonumber(state.editorPreferences.lastUsedHeight3) or
        radius * 2 -- Default height for polygons

    local height4 = tonumber(state.editorPreferences.lastUsedHeight4) or
        radius * 2 -- Default height for polygons


    local bodyType = state.editorPreferences.nextType
    local settings = {
        x = wx,
        y = wy,
        bodyType = bodyType,
        radius = radius,
        width = width,
        width2 = width2,
        width3 = width3,
        height = height,
        height2 = height2,
        height3 = height3,
        height4 = height4,
        label = ''
    }

    local thing = createThing(shapeType, settings)

    if not thing then
        logger:info("startSpawn: Failed to create thing.")
        return
    end

    state.interaction.draggingObj = thing
    state.interaction.offsetDragging = { 0, 0 }
end

function lib.addThing(shapeType, settings)
    --function lib.addThing(shapeType, x, y, bodyType, radius, width, width2, height, label, optionalVertices)
    --local thing = createThing(shapeType, x, y, bodyType, radius, width, width2, height, label, optionalVertices)
    --  print(inspect(settings))
    local thing = createThing(shapeType, settings)
    if not thing then
        logger:error("addThing: Failed to create thing.")
        return nil
    end

    return thing
end

-- this one is called when the shape of the body changes, thus, its kinda safe to make weird changes to joints too.
function lib.recreateThingFromBody(body, newSettings)
    if body:isDestroyed() then
        logger:error("The body is already destroyed.")
        return nil
    end
    local userData = body:getUserData()
    local thing = userData and userData.thing -- Extract current properties

    local x, y = body:getPosition()
    local angle = body:getAngle()
    local velocityX, velocityY = body:getLinearVelocity()
    local angularVelocity = body:getAngularVelocity()
    local bodyType = newSettings.bodyType or body:getType()
    local firstFixture = body:getFixtures()[1]
    local restitution = firstFixture:getRestitution()
    local friction = firstFixture:getFriction()
    local fixedRotation = body:isFixedRotation() -- Capture fixed angle state
    -- Get the original `thing` for shape info

    local oldVertices = utils.shallowCopy(thing.vertices)
    local oldFixtures = body:getFixtures()

    local jointData = joints.extractJoints(body)

    -- Create new body
    local newBody = love.physics.newBody(state.physicsWorld, x, y, bodyType)
    newBody:setAngle(angle)
    newBody:setLinearVelocity(velocityX, velocityY)
    newBody:setAngularVelocity(angularVelocity)
    newBody:setFixedRotation(fixedRotation) -- Reapply fixed rotation
    -- Create a new shape


    local settings = {
        radius = newSettings.radius or thing.radius,
        width = newSettings.width or thing.width,
        width2 = newSettings.width2 or thing.width2,
        width3 = newSettings.width3 or thing.width3,
        height = newSettings.height or thing.height,
        height2 = newSettings.height2 or thing.height2,
        height3 = newSettings.height3 or thing.height3,
        height4 = newSettings.height4 or thing.height4,
        optionalVertices = newSettings.optionalVertices
    }
    local shapeList, newVertices = shapes.createShape(
        newSettings.shapeType or thing.shapeType,
        settings
    )



    local ok, offset = fixtures.hasFixturesWithUserDataAtBeginning(oldFixtures)

    for _, shape in ipairs(shapeList) do
        local fixture = love.physics.newFixture(newBody, shape, 1)
        fixture:setRestitution(newSettings.restitution or restitution)
        fixture:setFriction(newSettings.friction or friction)
    end

    if offset > 0 then
        -- here we should recreate the special fixtures..
        for i = 1, offset do
            local oldF = oldFixtures[i]
            local points = { oldF:getShape():getPoints() }

            local abs = oldF:getShape()
            local centerX, centerY = mathutils.getCenterOfPoints(points)
            if (thing.vertices) then
                -- we are repositioning special fixtures (anchors, snappoints) and doing our best to set them at a decent position.
                -- this is fine for all sort of editor made things,
                -- todo specific positioning for mipo on behavors
                -- but for mipos character we might just want to be very precise and dending on behaviors and tags and dedicated rules.
                --local params = mathutils.closestEdgeParams(centerX, centerY, thing.vertices)
                --local new_px, new_py = mathutils.repositionPointClosestEdge(params, newVertices)

                if (#thing.vertices == #newVertices) then -- this general case isn working when the amount of points change. (and im not sure if it wise otherwise)
                    local weights = mathutils.getMeanValueCoordinatesWeights(centerX, centerY, thing.vertices)
                    local new_px, new_py = mathutils.repositionPointUsingWeights(weights, newVertices)

                    local rel = mathutils.makePolygonRelativeToCenter(points, centerX, centerY)
                    abs = love.physics.newPolygonShape(mathutils.makePolygonAbsolute(rel, new_px, new_py))
                else
                    local new_px, new_py = centerX, centerY
                    local rel = mathutils.makePolygonRelativeToCenter(points, centerX, centerY)
                    abs = love.physics.newPolygonShape(mathutils.makePolygonAbsolute(rel, 0, 0))
                end
            end


            local newFixture = love.physics.newFixture(newBody, abs, oldF:getDensity())
            newFixture:setRestitution(oldF:getRestitution())
            newFixture:setFriction(oldF:getFriction())
            newFixture:setUserData(utils.shallowCopy(oldF:getUserData()))

            registry.registerSFixture(oldF:getUserData().id, newFixture)
            snap.rebuildSnapFixtures(registry.sfixtures)
        end
    end



    -- Update the `thing` table
    thing.label = thing.label
    thing.body = newBody
    thing.shapes = shapeList

    thing.radius = newSettings.radius or thing.radius
    thing.width = newSettings.width or thing.width
    thing.width2 = newSettings.width2 or thing.width2
    thing.width3 = newSettings.width3 or thing.width3
    thing.height = newSettings.height or thing.height
    thing.height2 = newSettings.height2 or thing.height2
    thing.height3 = newSettings.height3 or thing.height3
    thing.height4 = newSettings.height4 or thing.height4
    thing.id = thing.id or uuid.generateID()
    thing.vertices = newVertices
    thing.behaviors = newSettings.behaviors or thing.behaviors


    registry.registerBody(thing.id, thing.body)
    newBody:setUserData({ thing = thing })

    joints.reattachJoints(jointData, newBody, oldVertices)

    snap.maybeUpdateSnapJoints(jointData)

    -- Destroy the old body
    body:destroy()

    return thing
end

function lib.destroyBody(body)
    local thing = body:getUserData().thing
    local bjoints = body:getJoints()
    for i = 1, #bjoints do
        local ud = bjoints[i]:getUserData()
        if ud and ud.id then
            --  logger:trace(ud.id)
            registry.unregisterJoint(ud.id)
            bjoints[i]:destroy()
        end
    end
    local bfixtures = body:getFixtures()
    ---print(#bfixtures)
    for i = 1, #bfixtures do
        local f = bfixtures[i]
        local ud = f:getUserData()
        if ud and ud.id then
            fixtures.destroyFixture(f)
            --registry.unregisterSFixture(ud.id)
            --bfixtures[i]:destroy()
        end
    end
    registry.unregisterBody(thing.id)
    body:destroy()
end

function lib.flipThing(thing, axis, recursive)
    -- Validate input
    if not thing or not thing.body then
        logger:error("flipThing: Invalid 'thing' provided.")
        return
    end

    if axis ~= 'x' and axis ~= 'y' then
        logger:error("flipThing: Invalid axis. Use 'x' or 'y'.")
        return
    end

    -- Tables to keep track of processed bodies and joints
    local processedBodies = {}
    local processedJoints = {}
    local toBeProcessedJoints = {}
    local centroidX, centroidY = thing.body:getPosition()



    --print('calculating centroid')
    -- Phase 1: Flip All Bodies
    local function flipBody(currentThing)
        local currentBody = currentThing.body
        if not currentBody or processedBodies[currentThing.id] then
            return
        end

        processedBodies[currentThing.id] = utils.shallowCopy(currentThing.vertices) or true

        -- Get current position and angle
        local currentX, currentY = currentBody:getPosition()

        local currentAngle = currentBody:getAngle()

        -- Calculate relative position to centroid
        local relX = currentX - centroidX
        local relY = currentY - centroidY

        -- Determine new relative position based on flip axis
        local newRelX, newRelY
        if axis == 'x' then
            newRelX = -relX
            newRelY = relY
        elseif axis == 'y' then
            newRelX = relX
            newRelY = -relY
        end
        -- Calculate new absolute position
        local newX = centroidX + newRelX
        local newY = centroidY + newRelY
        local newAngle
        if axis == 'x' then
            newAngle = -currentAngle
            currentThing.mirrorX = currentThing.mirrorX * -1
        elseif axis == 'y' then
            newAngle = -currentAngle
            currentThing.mirrorY = currentThing.mirrorY * -1
        end

        currentThing.body:setPosition(newX, newY)
        currentThing.body:setAngle(newAngle)


        --currentThing.mirroredX = (currentThing.mirroredX or 1)

        if currentThing.vertices then
            local flippedVertices = utils.shallowCopy(currentThing.vertices)
            for i = 1, #currentThing.vertices, 2 do
                if axis == 'x' then
                    flippedVertices[i] = -flippedVertices[i]         -- Invert X coordinate
                elseif axis == 'y' then
                    flippedVertices[i + 1] = -flippedVertices[i + 1] -- Invert Y coordinate
                end
            end
            currentThing.vertices = flippedVertices
        end

        -- Flip each fixture's shape
        -- for _, fixture in ipairs(currentBody:getFixtures()) do
        --     print(_, fixture:getUserData() ~= nil)
        -- end
        local fixtures = currentBody:getFixtures()
        -- if i do this backwards the fixtures end up being in the same order... !!
        for i = #fixtures, 1, -1 do
            -- for _, fixture in ipairs(currentBody:getFixtures()) do
            local fixture = fixtures[i]
            local shape = fixture:getShape()
            if shape:typeOf("PolygonShape") then
                local points = { shape:getPoints() }
                for i = 1, #points, 2 do
                    if axis == 'x' then
                        points[i] = -points[i]         -- Invert X coordinate
                    elseif axis == 'y' then
                        points[i + 1] = -points[i + 1] -- Invert Y coordinate
                    end
                end
                -- currentThing.vertices = points;
                -- Create a new shape with flipped vertices
                local success, newShape = pcall(love.physics.newPolygonShape, unpack(points))
                if not success then
                    print("flipThing: Failed to create new PolygonShape:", newShape)
                else
                    -- Preserve fixture properties
                    local density = fixture:getDensity()
                    local friction = fixture:getFriction()
                    local restitution = fixture:getRestitution()

                    -- Create a new fixture and destroy the old one
                    local newFixture = love.physics.newFixture(currentBody, newShape, density)
                    newFixture:setFriction(friction)
                    newFixture:setRestitution(restitution)
                    if (fixture:getUserData()) then
                        newFixture:setUserData(utils.deepCopy(fixture:getUserData()))
                        registry.registerSFixture(fixture:getUserData().id, newFixture)
                        snap.maybeUpdateSFixture(newFixture:getUserData().id)
                    end


                    fixture:destroy()
                end
            elseif shape:typeOf("CircleShape") then
                -- No need to flip circle shapes beyond position
                -- Circle radius remains the same
                -- If the circle has user data affecting orientation, handle it here
            end
        end
        -- for _, fixture in ipairs(currentBody:getFixtures()) do
        --     print(_, fixture:getUserData() ~= nil)
        -- end
        -- Determine new angle based on flip axis

        -- If recursive, flip connected bodies first
        if recursive then
            for _, joint in ipairs(currentBody:getJoints()) do
                local jointUserData = joint:getUserData()
                if not jointUserData or not jointUserData.id then
                    logger:error("flipThing: Joint without valid user data encountered.")
                    goto continue
                end

                toBeProcessedJoints[jointUserData.id] = joint
                -- Determine the other body connected by the joint
                local bodyA, bodyB = joint:getBodies()
                local otherBody = (bodyA == currentBody) and bodyB or bodyA
                local otherThing = otherBody:getUserData() and otherBody:getUserData().thing

                if not otherThing then
                    logger:error("flipThing: Connected joint's other body is invalid.")
                    goto continue
                end

                -- Recursively flip the connected body
                flipBody(otherThing)

                ::continue::
            end
        end
    end

    -- Phase 2: Flip All Joints
    local function flipJoints()
        for jointID, joint in pairs(toBeProcessedJoints) do
            local jointType = joint:getType()
            local jointUserData = joint:getUserData()

            if not jointUserData or not jointUserData.id then
                logger:error("flipThing: Joint without valid user data encountered.")
                goto continue
            end

            if processedJoints[jointUserData.id] then
                goto continue
            end
            processedJoints[jointUserData.id] = true

            -- Extract joint data using the handler
            local handler = jointHandlers[jointType]
            if not handler or not handler.extract then
                logger:error("flipThing: No handler found for joint type:", jointType)
                goto continue
            end
            local jointData = handler.extract(joint)

            -- Determine the connected bodies
            local bodyA, bodyB = joint:getBodies()
            local thingA = bodyA:getUserData() and bodyA:getUserData().thing
            local thingB = bodyB:getUserData() and bodyB:getUserData().thing

            if not thingA or not thingB then
                logger:error("flipThing: One or both connected things are invalid.")
                goto continue
            end


            logger:info(
                'I should figure out if i want to do something weird with the offset, think connect to torso logic at edge nr...')
            --print('old', inspect(processedBodies[thingA.id]), inspect(processedBodies[thingB.id]))
            --print('new', inspect(thingA.vertices), inspect(thingB.vertices))


            --todo when a joint is flipped i alos need to redo its limits (if applicable)


            local offsetA = jointUserData.offsetA
            local offsetB = jointUserData.offsetB

            if axis == 'x' then
                offsetA.x = -offsetA.x
                offsetB.x = -offsetB.x
            elseif axis == 'y' then
                offsetA.y = -offsetA.y
                offsetB.y = -offsetB.y
            end

            local limitsEnabled = joint:areLimitsEnabled()
            local lower, upper = joint:getLimits()


            local id = joint:getUserData().id
            local newJoint = joints.recreateJoint(joint, { offsetA = offsetA, offsetB = offsetB })

            if axis == 'x' then
                newJoint:setLimits(-upper, -lower)
                newJoint:setLimitsEnabled(limitsEnabled)
            end
            if axis == 'y' then
                -- as long as you build your joints in the right order this just works like this.
                -- the reason is quite subtle (before we did lowerlimit  +math.pi and higherlimit + math.pi), but
                -- because the axis is flipped , the order between the joint becomes flipped too, which offsets that math.pi back to 0

                -- TLDR dont make the joints in the wrong order, then everything works great!
                newJoint:setLimits(-upper, -lower)
                newJoint:setLimitsEnabled(limitsEnabled)
            end
            snap.maybeUpdateSnapJointWithId(id)
            ::continue::
        end
    end

    -- Phase 1: Flip All Bodies Recursively
    flipBody(thing)

    -- Phase 2: Flip All Joints
    flipJoints()

    -- snap.rebuildSnapFixtures(registry.sfixtures)
    --print('************* Flip Completed *************')
    return thing
end

return lib

```

src//playtime-ui.lua
```lua
local lib = {}

local eio = require 'src.io'
local registry = require 'src.registry'
local mathutils = require 'src.math-utils'
local ui = require 'src.ui-all'
local joints = require 'src.joints'
local objectManager = require 'src.object-manager'
local camera = require 'src.camera'
local cam = camera.getInstance()
local box2dPointerJoints = require 'src.box2d-pointerjoints'
local utils = require 'src.utils'
local ProFi = require 'vendor.ProFi'
local fixtures = require 'src.fixtures'
local snap = require 'src.snap'
local box2dDrawTextured = require 'src.box2d-draw-textured'
local Peeker = require 'vendor.peeker'
local recorder = require 'src.recorder'
local state = require 'src.state'
local script = require 'src.script'
local sceneLoader = require 'src.scene-loader'
local fileBrowser = require 'src.file-browser'
local behaviors = require 'src.behaviors'
local PANEL_WIDTH = 300
local BUTTON_HEIGHT = ui.theme.lineHeight
local ROW_WIDTH = 160
local BUTTON_SPACING = 10
local FPS = 60

local offsetHasChangedViaOutside

local colorpickers = {
    bg = false
}

-- todo move this somewhere sensible , i also need it in character manager
local function getCenterAndDimensions(body)
    local ud = body:getUserData()
    local cx, cy, w, h
    if ud.thing.vertices then
        local verts = ud.thing.vertices
        cx, cy, w, h = mathutils.getCenterOfPoints(verts)
    else -- this is a circle shape..
        cx, cy = body:getPosition()

        w, h = ud.thing.radius * 2, ud.thing.radius * 2
    end
    return cx, cy, w, h
end

local function createSliderWithId(id, label, x, y, width, min, max, value, callback, changed)
    local newValue = ui.sliderWithInput(id .. "::" .. label, x, y, width, min, max, value, changed)
    if newValue then
        callback(newValue)
    end
    ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), label)
    return newValue
end
-- Helper function to create a checkbox with an associated label
local function createCheckbox(labelText, x, y, value, callback)
    local changed, newValue = ui.checkbox(x, y, value, labelText)
    if changed then
        callback(newValue)
    end
    return newValue
end

local function rect(w, h, x, y)
    return {
        x - w / 2, y - h / 2,
        x + w / 2, y - h / 2,
        x + w / 2, y + h / 2,
        x - w / 2, y + h / 2
    }
end

function lib.doJointCreateUI(_x, _y, w, h)
    ui.panel(_x, _y, w, h, '∞ ' .. state.jointParams.jointType .. ' ∞', function()
        local layout = ui.createLayout({
            type = 'columns',
            spacing = 10,
            startX = _x + 10,
            startY = _y + 10
        })

        local width = 180
        local x, y = ui.nextLayoutPosition(layout, 160, BUTTON_HEIGHT)
        local nextRow = function()
            x, y = ui.nextLayoutPosition(layout, 160, BUTTON_HEIGHT)
        end
        nextRow()
        if ui.button(x, y, width, 'Create') then
            local j = joints.createJoint(state.jointParams)
            state.selection.selectedJoint = j
            state.selection.selectedObject = nil
            state.jointParams = nil
            state.currentMode = nil
        end

        if ui.button(x + width + 10, y, width, 'Cancel') then
            state.jointParams = nil
            state.currentMode = nil
        end
    end)
end

function lib.doJointUpdateUI(j, _x, _y, w, h)
    if not j:isDestroyed() then
        ui.panel(_x, _y, w, h, '∞ ' .. j:getType() .. ' ∞', function()
            local bodyA, bodyB = j:getBodies()

            local layout = ui.createLayout({
                type = 'columns',
                spacing = 10,
                startX = _x + 10,
                startY = _y + 10
            })
            local jointType = j:getType()
            local jointId = joints.getJointId(j)
            local x, y = ui.nextLayoutPosition(layout, 160, BUTTON_HEIGHT)

            local nextRow = function()
                x, y = ui.nextLayoutPosition(layout, 160, BUTTON_HEIGHT)
            end
            nextRow()
            local width = 280


            if ui.button(x, y, width, 'destroy') then
                local setId = joints.getJointId(j)
                registry.unregisterJoint(setId)
                j:destroy()
                return;
            end

            local function axisFunctionality(j)
                local axisEnabled = createCheckbox(' axis', x, y,
                    state.editorPreferences.axisEnabled or false,
                    function(val)
                        state.editorPreferences.axisEnabled = val
                    end
                )

                if axisEnabled then
                    local _x, _y = j:getAxis()
                    --_x, _y = normalizeAxis(_x, _y)
                    nextRow()
                    local axisX = createSliderWithId(jointId, ' axisX', x, y, 160, -1, 1,
                        _x or 0,
                        function(val)
                            state.selection.selectedJoint = joints.recreateJoint(j, { axisX = val, axisY = _y })
                            j = state.selection.selectedJoint
                        end
                    )
                    nextRow()
                    local axisY = createSliderWithId(jointId, ' axisY', x, y, 160, -1, 1,
                        _y or 1,
                        function(val)
                            state.selection.selectedJoint = joints.recreateJoint(j, { axisX = _x, axisY = val })
                            j = state.selection.selectedJoint
                        end
                    )
                    nextRow()
                    if ui.button(x, y, 160, 'normalize') then
                        local _x, _y = j:getAxis()
                        _x, _y = mathutils.normalizeAxis(_x, _y)
                        state.selection.selectedJoint = joints.recreateJoint(j, { axisX = _x, axisY = _y })
                        j = state.selection.selectedJoint
                    end
                end
                return j
            end

            local function collideFunctionality(j)
                local collideEnabled = createCheckbox(' collide', x, y,
                    j:getCollideConnected(),
                    function(val)
                        state.selection.selectedJoint = joints.recreateJoint(j, { collideConnected = val })
                        j = state.selection.selectedJoint
                    end
                )
                return j
            end

            local function motorFunctionality(j, settings)
                local motorEnabled = createCheckbox(' motor', x, y,
                    j:isMotorEnabled(),
                    function(val)
                        j:setMotorEnabled(val)
                    end
                )
                nextRow()
                if j:isMotorEnabled() then
                    local motorSpeed = createSliderWithId(jointId, ' speed', x, y, 160, -1000, 1000,
                        j:getMotorSpeed(),
                        function(val) j:setMotorSpeed(val) end
                    )
                    nextRow()
                    if (settings and settings.useTorque) then
                        local maxMotorTorque = createSliderWithId(jointId, ' max T', x, y, 160, 0, 100000,
                            j:getMaxMotorTorque(),
                            function(val) j:setMaxMotorTorque(val) end
                        )
                        nextRow()
                    end
                    if (settings and settings.useForce) then
                        local maxMotorForce = createSliderWithId(jointId, ' max F', x, y, 160, 0, 100000,
                            j:getMaxMotorForce(),
                            function(val) j:setMaxMotorForce(val) end
                        )
                        nextRow()
                    end
                end
            end

            local function limitsFunctionalityAngular(j)
                local limitsEnabled = createCheckbox(' limits', x, y,
                    j:areLimitsEnabled(),
                    function(val)
                        j:setLimitsEnabled(val)
                    end
                )

                if (j:areLimitsEnabled()) then
                    nextRow()
                    local up = math.deg(j:getUpperLimit())
                    local lowerLimit = createSliderWithId(jointId, ' lower', x, y, 160, -180, up,
                        math.deg(j:getLowerLimit()),
                        function(val)
                            local newValue = math.rad(val)

                            j:setLowerLimit(newValue)
                        end
                    )
                    nextRow()
                    local low = math.deg(j:getLowerLimit())
                    local upperLimit = createSliderWithId(jointId, ' upper', x, y, 160, low, 180,
                        math.deg(j:getUpperLimit()),
                        function(val)
                            local newValue = math.rad(val)
                            j:setUpperLimit(newValue)
                        end
                    )
                end
            end

            local function limitsFunctionalityLinear(j)
                local limitsEnabled = createCheckbox(' limits', x, y,
                    j:areLimitsEnabled(),
                    function(val)
                        j:setLimitsEnabled(val)
                    end
                )

                if (j:areLimitsEnabled()) then
                    nextRow()
                    local up = (j:getUpperLimit())
                    local lowerLimit = createSliderWithId(jointId, ' lower', x, y, 160, -1000, up,
                        j:getLowerLimit(),
                        function(val)
                            j:setLowerLimit(val)
                        end
                    )
                    nextRow()
                    local low = j:getLowerLimit()
                    local upperLimit = createSliderWithId(jointId, ' upper', x, y, 160, low, 1000,
                        j:getUpperLimit(),
                        function(val)
                            j:setUpperLimit(val)
                        end
                    )
                end
            end

            local function offsetSliders(j)
                if not joints.getJointMetaSetting(j, 'offsetA') then
                    joints.setJointMetaSetting(j, 'offsetA', { x = 0, y = 0 })
                end
                local offsetA = joints.getJointMetaSetting(j, 'offsetA') or 0

                if not joints.getJointMetaSetting(j, 'offsetB') then
                    joints.setJointMetaSetting(j, 'offsetB', { x = 0, y = 0 })
                end
                local offsetB = joints.getJointMetaSetting(j, 'offsetB') or 0

                function updateOffsetA(x, y)
                    --local rx, ry = rotatePoint(x, y, 0, 0, bodyA:getAngle())

                    offsetA.x = x
                    offsetA.y = y
                    joints.setJointMetaSetting(j, 'offsetA', { x = offsetA.x, y = offsetA.y })
                    state.selection.selectedJoint = joints.recreateJoint(j)
                    j = state.selection.selectedJoint


                    offsetHasChangedViaOutside = true
                    return j
                end

                function updateOffsetB(x, y)
                    --local rx, ry = rotatePoint(x, y, 0, 0, bodyA:getAngle())

                    offsetB.x = x
                    offsetB.y = y
                    joints.setJointMetaSetting(j, 'offsetB', { x = offsetB.x, y = offsetB.y })
                    state.selection.selectedJoint = joints.recreateJoint(j)
                    j = state.selection.selectedJoint


                    offsetHasChangedViaOutside = true
                    return j
                end

                -- Ensure offsets exist


                nextRow()
                if ui.button(x, y, BUTTON_HEIGHT, '∆') then
                    state.currentMode = 'setOffsetA'
                end
                if jointType ~= 'revolute' then
                    if ui.button(x + 50, y, BUTTON_HEIGHT, 'b  ') then
                        state.currentMode = 'setOffsetB'
                    end
                end
                nextRow()
                if (offsetHasChangedViaOutside) then offsetHasChangedViaOutside = false end

                local bodyA, bodyB = j:getBodies()
                local ud = bodyA:getUserData()


                if false and ud and ud.thing then
                    --print(inspect(ud.thing))
                    if ud.thing.width and ud.thing.height then
                        if ui.button(x, y, 30, '0', 30) then
                            updateOffsetA(0, -ud.thing.height / 2)
                        end
                        if ui.button(x + 30, y, 30, '1', 30) then
                            updateOffsetA(ud.thing.width / 2, -ud.thing.height / 2)
                        end
                        if ui.button(x + 60, y, 30, '2', 30) then
                            updateOffsetA(ud.thing.width / 2, 0)
                        end
                        if ui.button(x + 90, y, 30, '3', 30) then
                            updateOffsetA(ud.thing.width / 2, ud.thing.height / 2)
                        end
                        if ui.button(x + 120, y, 30, '4', 30) then
                            updateOffsetA(0, ud.thing.height / 2)
                        end
                        if ui.button(x + 150, y, 30, '5', 30) then
                            updateOffsetA(-ud.thing.width / 2, ud.thing.height / 2)
                        end
                        if ui.button(x + 180, y, 30, '6', 30) then
                            updateOffsetA(-ud.thing.width / 2, 0)
                        end
                        if ui.button(x + 210, y, 30, '7', 30) then
                            updateOffsetA(-ud.thing.width / 2, -ud.thing.height / 2)
                        end
                    end
                    if ui.button(x + 240, y, 30, '8', 30) then
                        updateOffsetA(0, 0)
                    end
                end

                nextRow()



                return j
            end

            if jointType == 'distance' then
                nextRow()
                j = collideFunctionality(j)
                nextRow()
                j = offsetSliders(j)
                nextRow()
                -- local bodyA, bodyB = j:getBodies()
                local x1, y1 = bodyA:getPosition()
                local x2, y2 = bodyB:getPosition()
                local myLength = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
                local length = createSliderWithId(jointId, ' length', x, y, 160, 0.1, 500,
                    state.jointLengthParams.length or myLength,
                    function(val)
                        j:setLength(val)
                        state.jointLengthParams.length = val
                    end
                )
                nextRow()

                local frequency = createSliderWithId(jointId, ' freq', x, y, 160, 0, 20,
                    j:getFrequency(),
                    function(val) j:setFrequency(val) end
                )
                nextRow()
                local damping = createSliderWithId(jointId, ' damp', x, y, 160, 0, 20,
                    j:getDampingRatio(),
                    function(val) j:setDampingRatio(val) end
                )

                nextRow()
                nextRow()
            elseif jointType == 'weld' then
                nextRow()
                j = collideFunctionality(j)
                nextRow()
                j = offsetSliders(j)
                nextRow()
                local frequency = createSliderWithId(jointId, ' freq', x, y, 160, 0, 20,
                    j:getFrequency(),
                    function(val) j:setFrequency(val) end
                )
                nextRow()
                local damping = createSliderWithId(jointId, ' damp', x, y, 160, 0, 20,
                    j:getDampingRatio(),
                    function(val) j:setDampingRatio(val) end
                )
                nextRow()
            elseif jointType == 'rope' then
                nextRow()
                j = collideFunctionality(j)
                nextRow()
                j = offsetSliders(j)
                nextRow()
                -- local bodyA, bodyB = j:getBodies()
                local x1, y1 = bodyA:getPosition()
                local x2, y2 = bodyB:getPosition()
                local myLength = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
                local length = createSliderWithId(jointId, ' length', x, y, 160, 0.1, 500,
                    state.jointLengthParams.maxLength or myLength,
                    function(val)
                        j:setMaxLength(val)
                        state.jointLengthParams.maxLength = val
                    end
                )
                nextRow()
            elseif jointType == 'revolute' then
                nextRow()
                j = collideFunctionality(j)
                nextRow()
                j = offsetSliders(j)
                nextRow()
                limitsFunctionalityAngular(j)
                nextRow()
                motorFunctionality(j, { useTorque = true })
            elseif jointType == 'wheel' then
                nextRow()
                j = collideFunctionality(j)
                nextRow()
                j = offsetSliders(j)
                nextRow()
                j = axisFunctionality(j)
                nextRow()
                -- if not j:isDestroyed() then
                local springFrequency = createSliderWithId(jointId, ' spring F', x, y, 160, 0, 100,
                    j:getSpringFrequency(),
                    function(val)
                        j:setSpringFrequency(val)
                    end
                )
                nextRow()
                local springDamping = createSliderWithId(jointId, ' spring D', x, y, 160, 0, 1,
                    j:getSpringDampingRatio(),
                    function(val) j:setSpringDampingRatio(val) end
                )
                nextRow()
                motorFunctionality(j, { useTorque = true })
                -- axisFunctionality(j)
                nextRow()
                --  end
            elseif jointType == 'motor' then
                nextRow()
                j = collideFunctionality(j)
                nextRow()
                j = offsetSliders(j)
                nextRow()
                local angularOffset = createSliderWithId(jointId, ' angular o', x, y, 160, -180, 180,
                    math.deg(j:getAngularOffset()),
                    function(val) j:setAngularOffset(math.rad(val)) end
                )
                nextRow()
                local correctionF = createSliderWithId(jointId, ' corr.', x, y, 160, 0, 1,
                    j:getCorrectionFactor(),
                    function(val) j:setCorrectionFactor(val) end
                )
                nextRow()
                local lx, ly = j:getLinearOffset()
                local lxOff = createSliderWithId(jointId, ' lx', x, y, 160, -1000, 1000,
                    lx,
                    function(val) j:setLinearOffset(val, ly) end
                )
                nextRow()
                local lyOff = createSliderWithId(jointId, ' ly', x, y, 160, -1000, 1000,
                    ly,
                    function(val) j:setLinearOffset(lx, val) end
                )
                nextRow()
                local maxForce = createSliderWithId(jointId, ' force', x, y, 160, 0, 100000,
                    j:getMaxForce(),
                    function(val) j:setMaxForce(val) end
                )
                nextRow()
                local maxTorque = createSliderWithId(jointId, ' torque', x, y, 160, 0, 100000,
                    j:getMaxTorque(),
                    function(val) j:setMaxTorque(val) end
                )
                nextRow()
            elseif jointType == 'friction' then
                j = offsetSliders(j)
                nextRow()
                local maxForce = createSliderWithId(jointId, ' force', x, y, 160, 0, 100000,
                    j:getMaxForce(),
                    function(val) j:setMaxForce(val) end
                )
                nextRow()
                local maxTorque = createSliderWithId(jointId, ' torque', x, y, 160, 0, 100000,
                    j:getMaxTorque(),
                    function(val) j:setMaxTorque(val) end
                )
                nextRow()
            elseif jointType == 'prismatic' then
                nextRow()
                j = collideFunctionality(j)
                nextRow()
                j = offsetSliders(j)
                nextRow()
                j = axisFunctionality(j)
                nextRow()
                limitsFunctionalityLinear(j)
                nextRow()
                motorFunctionality(j, { useForce = true })
            end
        end)
    end
end

function lib.drawAddShapeUI()
    local shapeTypes = { 'rectangle', 'circle', 'triangle', 'itriangle', 'capsule', 'torso', 'trapezium', 'pentagon',
        'hexagon',
        'heptagon',
        'octagon' }
    local titleHeight = ui.font:getHeight() + BUTTON_SPACING
    local startX = 20
    local startY = 70
    local panelWidth = 200
    local buttonSpacing = BUTTON_SPACING
    local buttonHeight = ui.theme.button.height
    local panelHeight = titleHeight + ((#shapeTypes + 6) * (buttonHeight + buttonSpacing)) + buttonSpacing

    ui.panel(startX, startY, panelWidth, panelHeight, '', function()
        local layout = ui.createLayout({
            type = 'columns',
            spacing = BUTTON_SPACING,
            startX = startX + BUTTON_SPACING,
            startY = startY + BUTTON_SPACING
        })

        local x, y = ui.nextLayoutPosition(layout, panelWidth - 20, buttonHeight)
        local nextRow = function()
            x, y = ui.nextLayoutPosition(layout, panelWidth - 20, buttonHeight)
        end

        for _, shape in ipairs(shapeTypes) do
            local width = panelWidth - 20
            local height = buttonHeight

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
            nextRow()
        end
        love.graphics.line(x - 20, y + 20, x + panelWidth + 20, y + 20)

        local width = panelWidth - 20
        local height = buttonHeight
        nextRow()

        local minDist = ui.sliderWithInput('minDistance', x, y, 80, 1, 150,
            state.editorPreferences.minPointDistance or 10)
        ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), '  dis')
        if minDist then
            state.editorPreferences.minPointDistance = minDist
        end

        -- Add a button for custom polygon
        nextRow()
        local freeformbutton, _, freeformReleased = ui.button(x, y, width, 'freeform')
        if freeformReleased then
            state.currentMode = 'drawFreePoly'
            state.interaction.polyVerts = {}
            state.interaction.lastPolyPt = nil
        end
        nextRow()

        if ui.button(x, y, width, 'click') then
            state.currentMode = 'drawClickMode'
            state.interaction.polyVerts = {}
            state.interaction.lastPolyPt = nil
        end
        nextRow()

        local width = panelWidth - 20
        local height = buttonHeight

        local function getHittedBody()
            local mx, my = love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)
            local _, hitted = box2dPointerJoints.handlePointerPressed(wx, wy, 'mouse', {}, not state.world.paused)
            if (#hitted > 0) then
                local body = hitted[#hitted]:getBody()
                return body
            end
            return nil
        end

        local function handleFixtureButton(x, y, width, label, shapeType, extraDataFunc)
            local _, pressed, released = ui.button(x, y, width, label)

            if pressed then
                ui.draggingActive = ui.activeElementID
                local mx, my = love.mouse.getPosition()
                local wx, wy = cam:getWorldCoordinates(mx, my)
                state.interaction.offsetDragging = { 0, 0 }
            end

            if released then
                local mx, my = love.mouse.getPosition()
                local wx, wy = cam:getWorldCoordinates(mx, my)
                local _, hitted = box2dPointerJoints.handlePointerPressed(wx, wy, 'mouse', {}, not state.world.paused)
                if #hitted > 0 then
                    local body = hitted[#hitted]:getBody()
                    local localX, localY = body:getLocalPoint(wx, wy)
                    local extraData = extraDataFunc and extraDataFunc(body, localX, localY) or { radius = 30 }
                    local fixture = fixtures.createSFixture(body, localX, localY, shapeType, extraData)
                    state.selection.selectedSFixture = fixture
                end
                ui.draggingActive = nil
            end

            nextRow()
        end

        handleFixtureButton(x, y, width, 'snapfixture', 'snap')
        handleFixtureButton(x, y, width, 'anchorfixture', 'anchor')
        handleFixtureButton(x, y, width, 'texturefixture', 'texfixture', function(body, localX, localY)
            local cx, cy, w, h = getCenterAndDimensions(body)
            return { width = w, height = h }
        end)
        handleFixtureButton(x, y, width, 'connectedtexture', 'connected-texture')
        handleFixtureButton(x, y, width, 'trace-vertices', 'trace-vertices')
        handleFixtureButton(x, y, width, 'tile-repeat', 'tile-repeat')
    end)
end

function lib.drawAddJointUI()
    local jointTypes = { 'distance', 'weld', 'rope', 'revolute', 'wheel', 'motor', 'prismatic', 'pulley',
        'friction' }
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
                state.jointParams = { body1 = nil, body2 = nil, jointType = joint }
                state.currentMode = 'jointCreationMode'
            end
        end
    end)
end

function lib.drawRecordingUI()
    local startX = 800
    local startY = 70
    local panelWidth = PANEL_WIDTH
    --local panelHeight = 255
    local buttonHeight = ui.theme.button.height

    local buttonSpacing = BUTTON_SPACING
    local titleHeight = ui.font:getHeight() + BUTTON_SPACING
    local panelHeight = titleHeight + titleHeight + (9 * (buttonHeight + BUTTON_SPACING) + BUTTON_SPACING)
    ui.panel(startX, startY, panelWidth, panelHeight, '• recording stuff •', function()
        local layout = ui.createLayout({
            type = 'columns',
            spacing = BUTTON_SPACING,
            startX = startX + BUTTON_SPACING,
            startY = startY + titleHeight + BUTTON_SPACING
        })
        local width = panelWidth - BUTTON_SPACING * 2
        local x, y = ui.nextLayoutPosition(layout, width, BUTTON_HEIGHT)
        local nextRow = function()
            x, y = ui.nextLayoutPosition(layout, width, BUTTON_HEIGHT)
        end

        local function startFromCurrentCheckpoint()
            state.selection.selectedJoint = nil
            state.selection.selectedObj = nil
            eio.buildWorld(state.scene.checkpoints[state.scene.activeCheckpointIndex].saveData, state.physicsWorld, cam,
                true)
            --

            if state.scene.sceneScript then state.scene.sceneScript.onStart() end
        end

        local addcheckpointbutton = ui.button(x, y, width, 'add checkpoint')
        if addcheckpointbutton then
            local saveData = eio.gatherSaveData(state.physicsWorld, cam)
            table.insert(state.scene.checkpoints, { saveData = saveData, recordings = {} })
        end
        nextRow()
        local chars = { 'A', 'B', 'C', 'D', 'E', 'F' }
        for i = 1, #state.scene.checkpoints do
            if ui.button(x + (i - 1) * 45, y, 40, chars[i]) then
                if state.scene.activeCheckpointIndex > 0 then
                    state.scene.checkpoints[state.scene.activeCheckpointIndex].recordings = utils.deepCopy(recorder
                        .recordings)
                end

                state.scene.activeCheckpointIndex = i

                recorder.recordings = utils.deepCopy(state.scene.checkpoints[state.scene.activeCheckpointIndex]
                    .recordings)
                startFromCurrentCheckpoint()
            end
        end
        y = y + 15
        love.graphics.line(x - 20, y + 20, x + panelWidth + 20, y + 20)
        nextRow()




        local function videoing()
            if Peeker.get_status() then
                Peeker.isProcessing = true
                Peeker.stop()
            else
                Peeker.isProcessing = false
                Peeker.start({
                    --w = 320,   --optional
                    --h = 320,   --optional
                    scale = 1, --this overrides w, h above, this is preferred to keep aspect ratio
                    --n_threads = 1,
                    fps = FPS,
                    out_dir = string.format("awesome_video"), --optional
                    -- format = "mkv", --optional
                    overlay = "circle",                       --or "text"
                    post_clean_frames = false,
                    total_frames = 1000,
                })
            end
        end

        if state.scene.activeCheckpointIndex > 0 and ((not recorder.isRecording and state.world.paused) or recorder.isRecording) then
            local pointerbutton = ui.button(x, y, width,
                recorder.isRecording and 'RECORDING gestures' or 'record gestures')
            if pointerbutton then
                if recorder.isRecording then
                    recorder:stopRecording()
                else
                    startFromCurrentCheckpoint()
                    recorder:startRecording()
                    recorder:startReplay() -- needed to replay earlier recordings if any.
                end
            end
            if #recorder.recordings > 0 then
                nextRow()

                local replaybutton = ui.button(x, y, width, 'replay gestures')
                if replaybutton then
                    startFromCurrentCheckpoint()
                    recorder:startReplay()
                end
            end
        end
        y = y + 15
        love.graphics.line(x - 20, y + 20, x + panelWidth + 20, y + 20)
        nextRow()
        nextRow()


        -- only allowed to start recording from pause
        if state.scene.activeCheckpointIndex > 0 then
            local peekerbutton = ui.button(x, y, width,
                Peeker.get_status() and 'RECORDING gesture video' or 'record gesture video')
            if peekerbutton then
                if not Peeker.get_status() then
                    state.world.paused = true -- it starts recording from pause so should start playing like that too
                    startFromCurrentCheckpoint()
                    recorder:startReplay()
                end
                videoing()
            end
            nextRow()
        end
        local saveloc = ui.button(x, y, width, 'open savedir')
        if saveloc then
            love.system.openURL("file://" .. love.filesystem.getSaveDirectory())
        end

        nextRow()
        -- local peekerbutton2 = ui.button(x, y, width,
        --     Peeker.get_status() and 'RECORDING video' or 'record vanilla video')
        -- if peekerbutton2 then
        --     videoing(false)
        -- end
        nextRow()
    end)
end

function lib.drawWorldSettingsUI()
    local startX = 440
    local startY = 70
    local panelWidth = PANEL_WIDTH
    --local panelHeight = 255
    local buttonHeight = ui.theme.button.height

    local buttonSpacing = BUTTON_SPACING
    local titleHeight = ui.font:getHeight() + BUTTON_SPACING
    local panelHeight = titleHeight + titleHeight + (9 * (buttonHeight + BUTTON_SPACING) + BUTTON_SPACING)
    ui.panel(startX, startY, panelWidth, panelHeight, '• ∫ƒF§ world •', function()
        local layout = ui.createLayout({
            type = 'columns',
            spacing = BUTTON_SPACING,
            startX = startX + BUTTON_SPACING,
            startY = startY + titleHeight + BUTTON_SPACING
        })
        local width = panelWidth - BUTTON_SPACING * 2

        local x, y = ui.nextLayoutPosition(layout, width, BUTTON_HEIGHT)
        local nextRow = function()
            x, y = ui.nextLayoutPosition(layout, width, BUTTON_HEIGHT)
        end
        --  x, y = ui.nextLayoutPosition(layout, width, 50)
        --  local grav = ui.sliderWithInput('grav', x, y, ROW_WIDTH, -10, BUTTON_HEIGHT, state.world.gravity)
        local grav = createSliderWithId('', 'grav', x, y, ROW_WIDTH, -10, 20, state.world.gravity, function(v)
            state.world.gravity = v
            if state.physicsWorld then
                state.physicsWorld:setGravity(0, state.world.gravity * state.world.meter)
            end
        end)

        nextRow()

        local g, value = ui.checkbox(x, y, state.editorPreferences.showGrid, 'grid') --showGrid = true,
        if g then
            state.editorPreferences.showGrid = value
        end
        local g, value = ui.checkbox(x + 150, y, state.world.debugDrawMode, 'draw') --showGrid = true,
        if g then
            state.world.debugDrawMode = value
        end
        nextRow()


        local debugAlpha = createSliderWithId('', 'debugalpha', x, y, ROW_WIDTH, 0, 1, state.world.debugAlpha,
            function(v)
                state.world.debugAlpha = v
            end)

        nextRow()
        nextRow()

        local debugAlpha = createSliderWithId('', 'mouse F', x, y, ROW_WIDTH, 0, 1000000, state.world.mouseForce,
            function(v)
                state.world.mouseForce = v
            end)

        nextRow()

        local mouseDamp = createSliderWithId('', 'damp', x, y, ROW_WIDTH, 0.001, 1, state.world.mouseDamping, function(v)
            state.world.mouseDamping = v
        end)

        -- Add Speed Multiplier Slider

        nextRow()
        local newSpeed = createSliderWithId('', 'speed', x, y, ROW_WIDTH, 0.1, 10.0, state.world.speedMultiplier,
            function(v)
                state.world.speedMultiplier = v
            end)

        nextRow()

        ui.label(x, y, registry.print())
        nextRow()

        if ui.button(x, y, ROW_WIDTH, state.world.profiling and 'profiling' or 'profile') then
            if state.world.profiling then
                ProFi:stop()
                ProFi:writeReport('profilingReport.txt')
                state.world.profiling = false
            else
                ProFi:start()
                state.world.profiling = true
            end
        end
        nextRow()


        ui.label(x, y, string.format("%.2f", love.graphics.getStats().texturememory / 1000000) .. ' MB')
        ui.label(x + 150, y, love.graphics.getStats().drawcallsbatched .. 'batched')
    end)
end

local hadBeenDraggingObj = false
local accordionStatesSF = {
    ['position'] = false,
    ['texture'] = true,
    ['patch1'] = false,
    ['patch2'] = false,
    ['patch3'] = false,
}

function lib.drawSelectedSFixture()
    local panelWidth = PANEL_WIDTH
    local w, h = love.graphics.getDimensions()
    if state.interaction.draggingObj then
        hadBeenDraggingObj = true
    end
    if state.selection.selectedSFixture:isDestroyed() then return end
    local ud = state.selection.selectedSFixture:getUserData()
    --  local sfixtureType = (ud and ud.extra and ud.extra.type == 'texfixture') and 'texfixture' or 'sfixture'
    local sfixtureType = ud.type .. ' ' .. (ud.subtype and ud.subtype or '')
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

        function handlePaletteAndHex(idPrefix, postFix, x, y, width, currentHex, onColorChange, setDirty)
            local r, g, b, a = box2dDrawTextured.hexToColor(currentHex)
            local dirty = function() oldTexFixUD.extra.dirty = true end
            local paletteShow = ui.button(x - 10, y, 20, '', BUTTON_HEIGHT, { r, g, b, a })
            if paletteShow then
                if state.panelVisibility.showPalette then
                    state.panelVisibility.showPalette = nil
                    state.showPaletteFunc = nil
                else
                    state.panelVisibility.showPalette = true
                    state.showPaletteFunc = function(color)
                        dirty()
                        --  oldTexFixUD.extra.dirty = true
                        colorpickers[postFix] = true
                        onColorChange(color)
                    end
                end
            end
            local hex = ui.textinput(idPrefix .. postFix, x + 10, y, width, BUTTON_HEIGHT, "", currentHex or '',
                false, colorpickers[postFix])
            if hex and hex ~= currentHex then
                --setDirty()
                oldTexFixUD.extra.dirty = true
                onColorChange(hex)
            end

            if colorpickers[postFix] then
                colorpickers[postFix] = false
            end
            ui.label(x + 10, y, postFix, { 1, 1, 1, 0.2 })
        end

        function handleURLInput(id, labelText, x, y, width, currentValue, updateCallback)
            local urlShow = ui.button(x - 10, y, 20, '', BUTTON_HEIGHT, { 1, 1, 1, 0.2 })
            if urlShow then
                fileBrowser:loadFiles('/textures', { includes = '-mask' })
                --fileBrowser:loadFiles('/textures', {excludes='-mask'})
            end
            local newValue = ui.textinput(id .. labelText, x + 10, y, width, BUTTON_HEIGHT, "", currentValue or '')
            if newValue and newValue ~= currentValue then
                updateCallback(newValue)
                oldTexFixUD.extra.dirty = true
                state.selection.selectedSFixture:setUserData(oldTexFixUD)
            end
            ui.label(x, y, labelText, { 1, 1, 1, 0.2 })
            return newValue or currentValue
        end

        function patchTransformUI(layer)
            local oldId = myID
            myID = myID .. ':' .. layer
            local newRotation = createSliderWithId(myID, 'r', x, y, ROW_WIDTH, 0, math.pi * 2,
                oldTexFixUD.extra[layer].r or 0,
                function(v)
                    oldTexFixUD.extra[layer].r = v
                    oldTexFixUD.extra.dirty = true
                end)

            nextRow()
            local newScaleX = createSliderWithId(myID, 'sx', x, y, 50, 0.01, 3, oldTexFixUD.extra[layer].sx or 1,
                function(v)
                    oldTexFixUD.extra[layer].sx = v
                    oldTexFixUD.extra.dirty = true
                end)


            local newScaleY = createSliderWithId(myID, 'sy', x + 140, y, 50, 0.01, 3,
                oldTexFixUD.extra[layer].sy or 1,
                function(v)
                    oldTexFixUD.extra[layer].sy = v
                    oldTexFixUD.extra.dirty = true
                end)

            nextRow()
            local newXOff = createSliderWithId(myID, 'tx', x, y, 50, -1, 1, oldTexFixUD.extra[layer].tx or 0,
                function(v)
                    oldTexFixUD.extra[layer].tx = v
                    oldTexFixUD.extra.dirty = true
                end)

            local newYOff = createSliderWithId(myID, 'ty', x + 140, y, 50, -1, 1, oldTexFixUD.extra[layer].ty or 0,
                function(v)
                    oldTexFixUD.extra[layer].ty = v
                    oldTexFixUD.extra.dirty = true
                end)

            nextRow()
            myID = oldId
        end

        function combineImageUI(layer)
            local oldId = myID
            myID = myID .. ':' .. layer
            local dirty = function() oldTexFixUD.extra.dirty = true end
            handlePaletteAndHex(myID, 'bgHex', x, y, 100, oldTexFixUD.extra[layer].bgHex,
                function(color) oldTexFixUD.extra[layer].bgHex = color end, dirty)
            handleURLInput(myID, 'bgURL', x + 130, y, 150, oldTexFixUD.extra[layer].bgURL,
                function(u)
                    oldTexFixUD.extra[layer].bgURL = u
                end)
            nextRow()
            handlePaletteAndHex(myID, 'fgHex', x, y, 100, oldTexFixUD.extra[layer].fgHex,
                function(c) oldTexFixUD.extra[layer].fgHex = c end, dirty)
            handleURLInput(myID, 'fgURL', x + 130, y, 150, oldTexFixUD.extra[layer].fgURL,
                function(u) oldTexFixUD.extra[layer].fgURL = u end)
            nextRow()
            ---
            handlePaletteAndHex(myID, 'patternHex', x, y, 100, oldTexFixUD.extra[layer].pHex,
                function(color) oldTexFixUD.extra[layer].pHex = color end, dirty)
            handleURLInput(myID, 'patternURL', x + 130, y, 150, oldTexFixUD.extra[layer].pURL,
                function(u) oldTexFixUD.extra[layer].pURL = u end)
            nextRow()

            local newRotation = createSliderWithId(myID, 'pr', x, y, ROW_WIDTH, 0, math.pi * 2,
                oldTexFixUD.extra[layer].pr or 0,
                function(v)
                    oldTexFixUD.extra[layer].pr = v
                    oldTexFixUD.extra.dirty = true
                end)

            nextRow()
            local newScaleX = createSliderWithId(myID, 'psx', x, y, 50, 0.01, 3, oldTexFixUD.extra[layer].psx or 1,
                function(v)
                    oldTexFixUD.extra[layer].psx = v
                    oldTexFixUD.extra.dirty = true
                end)


            local newScaleY = createSliderWithId(myID, 'psy', x + 140, y, 50, 0.01, 3,
                oldTexFixUD.extra[layer].psy or 1,
                function(v)
                    oldTexFixUD.extra[layer].psy = v
                    oldTexFixUD.extra.dirty = true
                end)

            nextRow()
            local newXOff = createSliderWithId(myID, 'ptx', x, y, 50, -1, 1, oldTexFixUD.extra[layer].ptx or 0,
                function(v)
                    oldTexFixUD.extra[layer].ptx = v
                    oldTexFixUD.extra.dirty = true
                end)

            local newYOff = createSliderWithId(myID, 'pty', x + 140, y, 50, -1, 1, oldTexFixUD.extra[layer].pty or 0,
                function(v)
                    oldTexFixUD.extra[layer].pty = v
                    oldTexFixUD.extra.dirty = true
                end)

            nextRow()
            myID = oldId
        end

        function flipWholeUI(layer)
            local dirtyX, checkedX = ui.checkbox(x, y, oldTexFixUD.extra[layer].fx == -1, 'flipx')
            if dirtyX then
                oldTexFixUD.extra[layer].fx = checkedX and -1 or 1
                oldTexFixUD.extra.dirty = true
                state.selection.selectedSFixture:setUserData(oldTexFixUD)
            end
            local dirtyY, checkedY = ui.checkbox(x + 150, y, oldTexFixUD.extra[layer].fy == -1, 'flipy')
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





        if ud.subtype == 'texfixture' or ud.extra.type == 'texfixture' then
            local oldTexFixUD = state.selection.selectedSFixture:getUserData()
            drawAccordion('position', function()
                if ui.button(x, y, BUTTON_HEIGHT, '∆') then
                    state.currentMode = 'positioningSFixture'
                end
                nextRow()
                if ui.button(x + 150, y, ROW_WIDTH - 100, 'c') then
                    local body = state.selection.selectedSFixture:getBody()
                    state.selection.selectedSFixture = fixtures.updateSFixturePosition(state.selection.selectedSFixture,
                        body:getX(), body:getY())
                    local oldTexFixUD = state.selection.selectedSFixture:getUserData()
                    state.texFixtureEdit.tempVerts = utils.shallowCopy(oldTexFixUD.extra.vertices)
                end

                if ui.button(x + 210, y, ROW_WIDTH - 100, 'd') then
                    local body = state.selection.selectedSFixture:getBody()
                    local cx, cy, w, h = getCenterAndDimensions(body)
                    fixtures.updateSFixtureDimensionsFunc(w, h)
                    local oldTexFixUD = state.selection.selectedSFixture:getUserData()
                    state.texFixtureEdit.tempVerts = utils.shallowCopy(oldTexFixUD.extra.vertices)
                end
                nextRow()



                local points = oldTexFixUD.extra.vertices or { state.selection.selectedSFixture:getShape():getPoints() }
                local w, h   = mathutils.getPolygonDimensions(points)

                if ui.checkbox(x, y, state.editorPreferences.showTexFixtureDim, 'dims') then
                    state.editorPreferences.showTexFixtureDim = not state.editorPreferences.showTexFixtureDim
                end
                nextRow()

                if ui.button(x, y, 200, state.texFixtureEdit.lockedVerts and 'verts locked' or 'verts unlocked') then
                    local oldTexFixUD = state.selection.selectedSFixture:getUserData()
                    state.texFixtureEdit.lockedVerts = not state.texFixtureEdit.lockedVerts

                    if state.texFixtureEdit.lockedVerts == false then
                        state.texFixtureEdit.tempVerts = utils.shallowCopy(oldTexFixUD.extra.vertices)
                    else
                        state.texFixtureEdit.tempVerts = nil
                        state.texFixtureEdit.centroid = nil
                    end
                end

                if ui.button(x + 220, y, 40, oldTexFixUD.extra.vertexCount or '') then
                    if oldTexFixUD.extra.vertexCount == 4 then
                        oldTexFixUD.extra.vertexCount = 8
                    elseif oldTexFixUD.extra.vertexCount == 8 then
                        oldTexFixUD.extra.vertexCount = 4
                    end
                end

                nextRow()

                if (state.editorPreferences.showTexFixtureDim) then
                    local newWidth = ui.sliderWithInput(myID .. 'texfix width', x, y, ROW_WIDTH, 1, 1000, w)
                    ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' width')
                    nextRow()

                    local newHeight = ui.sliderWithInput(myID .. ' texfix height', x, y, ROW_WIDTH, 1, 1000, h)
                    ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' height')
                    nextRow()

                    if newWidth and math.abs(newWidth - w) > 1 then
                        fixtures.updateSFixtureDimensionsFunc(newWidth, h)
                        w, h = mathutils.getPolygonDimensions(points)
                    end
                    if newHeight and math.abs(newHeight - h) > 1 then
                        fixtures.updateSFixtureDimensionsFunc(w, newHeight)
                        w, h = mathutils.getPolygonDimensions(points)
                    end
                end
                local newZOffset = createSliderWithId(myID, ' texfixzOffset', x, y, ROW_WIDTH, -180, 180,
                    math.floor(oldTexFixUD.extra.zOffset or 0),
                    function(v)
                        oldTexFixUD.extra.zOffset = math.floor(v)
                    end,
                    (not state.world.paused) or dirtyBodyChange)
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

                    handlePaletteAndHex(myID, 'bgHex', x, y, 100, oldTexFixUD.extra.main.bgHex,
                        function(c) oldTexFixUD.extra.main.bgHex = c end, dirty)
                    handleURLInput(myID, 'bgURL', x + 130, y, 150, oldTexFixUD.extra.main.bgURL,
                        function(u)
                            oldTexFixUD.extra.main.bgURL = u
                        end)
                    nextRow()
                    handlePaletteAndHex(myID, 'fgHex', x, y, 100, oldTexFixUD.extra.main.fgHex,
                        function(c) oldTexFixUD.extra.main.fgHex = c end, dirty)
                    handleURLInput(myID, 'fgURL', x + 130, y, 150, oldTexFixUD.extra.main.fgURL,
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

            drawAccordion('patch1', function()
                oldTexFixUD.extra.patch1 = oldTexFixUD.extra.patch1 or {}
                nextRow()
                combineImageUI('patch1')
                nextRow()
                patchTransformUI('patch1')
                flipWholeUI('patch1')
                --nextRow()
                local dirty = function() oldTexFixUD.extra.dirty = true end
                handlePaletteAndHex(myID, 'patch1tint', x, y, 100, oldTexFixUD.extra.patch1.tint,
                    function(color) oldTexFixUD.extra.patch1.tint = color end, dirty)
            end)
            nextRow()
            drawAccordion('patch2', function()
                oldTexFixUD.extra.patch2 = oldTexFixUD.extra.patch2 or {}
                nextRow()
                combineImageUI('patch2')
                nextRow()
                patchTransformUI('patch2')
                flipWholeUI('patch2')
                -- nextRow()
                local dirty = function() oldTexFixUD.extra.dirty = true end
                handlePaletteAndHex(myID, 'patch2tint', x, y, 100, oldTexFixUD.extra.patch2.tint,
                    function(color) oldTexFixUD.extra.patch2.tint = color end, dirty)
            end)
            nextRow()
            drawAccordion('patch3', function()
                oldTexFixUD.extra.patch3 = oldTexFixUD.extra.patch3 or {}
                nextRow()
                combineImageUI('patch3')
                nextRow()
                patchTransformUI('patch3')
                flipWholeUI('patch3')
                --nextRow()
                local dirty = function() oldTexFixUD.extra.dirty = true end
                handlePaletteAndHex(myID, 'patch3tint', x, y, 100, oldTexFixUD.extra.patch3.tint,
                    function(color) oldTexFixUD.extra.patch3.tint = color end, dirty)
            end)
        else
            drawAccordion('position', function()
                nextRow()
                if ui.button(x, y, BUTTON_HEIGHT, '∆') then
                    state.currentMode = 'positioningSFixture'
                end

                if ui.button(x + 150, y, ROW_WIDTH - 100, 'c') then
                    local body = state.selection.selectedSFixture:getBody()
                    state.selection.selectedSFixture = fixtures.updateSFixturePosition(state.selection.selectedSFixture,
                        body:getX(), body:getY())
                    local oldTexFixUD = state.selection.selectedSFixture:getUserData()
                    state.texFixtureEdit.tempVerts = utils.shallowCopy(oldTexFixUD.extra.vertices)
                end

                nextRow()

                local points = { state.selection.selectedSFixture:getShape():getPoints() }
                local dim = mathutils.getPolygonDimensions(points)
                local newRadius = ui.sliderWithInput(myID .. ' radius', x, y, ROW_WIDTH, 1, 200, dim)
                ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' radius')
                if newRadius and newRadius ~= dim then
                    fixtures.updateSFixtureDimensionsFunc(newRadius, newRadius)
                    snap.rebuildSnapFixtures(registry.sfixtures)
                end

                nextRow()
                local function handleOffset(xMultiplier, yMultiplier)
                    local body = state.selection.selectedSFixture:getBody()
                    local parentVerts = body:getUserData().thing.vertices
                    local allFixtures = body:getUserData().thing.body:getFixtures()
                    local points = { state.selection.selectedSFixture:getShape():getPoints() }
                    local centerX, centerY = mathutils.getCenterOfPoints(points)
                    local bounds = mathutils.getBoundingRect(parentVerts)
                    local relativePoints = mathutils.makePolygonRelativeToCenter(points, centerX, centerY)
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

                if state.selection.selectedSFixture:getUserData().subtype ~= 'texfixture' then
                    if ui.button(x, y, 40, 'N') then
                        handleOffset(0, -1)
                    end
                    if ui.button(x + 50, y, 40, 'E') then
                        handleOffset(1, 0)
                    end
                    if ui.button(x + 100, y, 40, 'S') then
                        handleOffset(0, 1)
                    end
                    if ui.button(x + 150, y, 40, 'W') then
                        handleOffset(-1, 0)
                    end
                    if ui.button(x + 200, y, 40, 'C') then
                        handleOffset(0, 0)
                    end
                end
            end)

            local oldUD = utils.shallowCopy(state.selection.selectedSFixture:getUserData())
            if oldUD.label == 'connected-texture' or oldUD.subtype == 'connected-texture' then
                oldTexFixUD.extra.main = oldTexFixUD.extra.main or {}
                if ui.button(x, y, ROW_WIDTH, 'add node ' .. (oldUD.extra.nodes and #oldUD.extra.nodes or '')) then
                    state.currentMode = 'addNodeToConnectedTexture'
                end

                nextRow()

                nextRow()

                local newZOffset = createSliderWithId(myID, ' texfixzOffset', x, y, ROW_WIDTH, -180, 180,
                    math.floor(oldTexFixUD.extra.zOffset or 0),
                    function(v)
                        oldTexFixUD.extra.zOffset = math.floor(v)
                    end,
                    (not state.world.paused) or dirtyBodyChange)
                nextRow()
                nextRow()
                local e = state.selection.selectedSFixture:getUserData().extra
                if ui.checkbox(x, y, true, (e.OMP == false or e.OMP == nil) and 'BG + FG' or 'OMP') then
                    e.OMP = not e.OMP
                end
                nextRow()
                oldTexFixUD.extra.main = oldTexFixUD.extra.main or {}
                local newWMul = createSliderWithId(myID, 'wmul', x + 50, y, ROW_WIDTH - 50, 0.1, 10.0,
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
                    handlePaletteAndHex(myID, 'bgHex', x, y, 100, oldTexFixUD.extra.main.bgHex,
                        function(c) oldTexFixUD.extra.main.bgHex = c end, dirty)
                    handleURLInput(myID, 'bgURL', x + 130, y, 150, oldTexFixUD.extra.main.bgURL,
                        function(u)
                            oldTexFixUD.extra.main.bgURL = u
                        end)
                    nextRow()
                    handlePaletteAndHex(myID, 'fgHex', x, y, 100, oldTexFixUD.extra.main.fgHex,
                        function(c) oldTexFixUD.extra.main.fgHex = c end, dirty)
                    handleURLInput(myID, 'fgURL', x + 130, y, 150, oldTexFixUD.extra.main.fgURL,
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

            if oldUD.subtype == 'tile-repeat' then
                oldTexFixUD.extra.main = oldTexFixUD.extra.main or {}
                oldTexFixUD.extra.tileWidthM = oldTexFixUD.extra.tileWidthM or 1
                oldTexFixUD.extra.tileHeightM = oldTexFixUD.extra.tileHeightM or 1
                oldTexFixUD.extra.tileRotation = oldTexFixUD.extra.tileRotation or 0
                local twm = createSliderWithId(myID, 'twm', x, y, 160, 0.01,
                    100,
                    oldTexFixUD.extra.tileWidthM, function(v)
                        oldTexFixUD.extra.tileWidthM = v
                    end)
                nextRow()
                nextRow()
                local thm = createSliderWithId(myID, 'thm', x, y, 160, 0.01,
                    100,
                    oldTexFixUD.extra.tileHeightM, function(v)
                        oldTexFixUD.extra.tileHeightM = v
                    end)
                nextRow()

                local tr = createSliderWithId(myID, 'tr', x, y, 160, 0,
                    2 * math.pi,
                    oldTexFixUD.extra.tileRotation, function(v)
                        oldTexFixUD.extra.tileRotation = v
                    end)

                nextRow()

                local newZOffset = createSliderWithId(myID, ' texfixzOffset', x, y, ROW_WIDTH, -180, 180,
                    math.floor(oldTexFixUD.extra.zOffset or 0),
                    function(v)
                        oldTexFixUD.extra.zOffset = math.floor(v)
                    end,
                    (not state.world.paused) or dirtyBodyChange)

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



            if oldUD.subtype == 'trace-vertices' then
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
                local startIndexSlider = createSliderWithId(myID, 'startIndex', x, y, 160, -(#parentVerts / 2),
                    (#parentVerts / 2),
                    oldTexFixUD.extra.startIndex, function(v)
                        oldTexFixUD.extra.startIndex = math.floor(v + 0)
                    end)

                ui.label(x + 130, y + (BUTTON_HEIGHT - ui.fontHeight), oldTexFixUD.extra.startIndex)
                nextRow()
                local endIndexSlider = createSliderWithId(myID, 'endIndex', x, y, 160, -(#parentVerts / 2),
                    (#parentVerts / 2),
                    oldTexFixUD.extra.endIndex, function(v)
                        oldTexFixUD.extra.endIndex = math.floor(v + 0)
                    end)

                ui.label(x + 130, y + (BUTTON_HEIGHT - ui.fontHeight), oldTexFixUD.extra.endIndex)

                nextRow()
                local tensionSlider = createSliderWithId(myID, 'tension', x, y, 160, 0.01,
                    0.5,
                    oldTexFixUD.extra.tension, function(v)
                        oldTexFixUD.extra.tension = v
                    end)
                nextRow()
                local spacingSlider = createSliderWithId(myID, 'spacing', x, y, 160, 1,
                    100,
                    oldTexFixUD.extra.spacing, function(v)
                        oldTexFixUD.extra.spacing = v
                    end)
                nextRow()
                local widthSlider = createSliderWithId(myID, 'width', x, y, 160, 1,
                    1000,
                    oldTexFixUD.extra.width, function(v)
                        oldTexFixUD.extra.width = v
                    end)
                nextRow()
                local newZOffset = createSliderWithId(myID, ' texfixzOffset', x, y, ROW_WIDTH, -180, 180,
                    math.floor(oldTexFixUD.extra.zOffset or 0),
                    function(v)
                        oldTexFixUD.extra.zOffset = math.floor(v)
                    end,
                    (not state.world.paused) or dirtyBodyChange)
                nextRow()
                nextRow()
                local e = state.selection.selectedSFixture:getUserData().extra
                if ui.checkbox(x, y, true, (e.OMP == false or e.OMP == nil) and 'BG + FG' or 'OMP') then
                    e.OMP = not e.OMP
                end
                nextRow()
                oldTexFixUD.extra.main = oldTexFixUD.extra.main or {}
                local newWMul = createSliderWithId(myID, 'wmul', x + 50, y, ROW_WIDTH - 50, 0.1, 10.0,
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
                    handlePaletteAndHex(myID, 'bgHex', x, y, 100, oldTexFixUD.extra.main.bgHex,
                        function(c) oldTexFixUD.extra.main.bgHex = c end, dirty)
                    handleURLInput(myID, 'bgURL', x + 130, y, 150, oldTexFixUD.extra.main.bgURL,
                        function(u)
                            oldTexFixUD.extra.main.bgURL = u
                        end)
                    nextRow()
                    handlePaletteAndHex(myID, 'fgHex', x, y, 100, oldTexFixUD.extra.main.fgHex,
                        function(c) oldTexFixUD.extra.main.fgHex = c end, dirty)
                    handleURLInput(myID, 'fgURL', x + 130, y, 150, oldTexFixUD.extra.main.fgURL,
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

function lib.drawSelectedBodiesUI()
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
        local nextRow = function()
            x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
        end

        if ui.button(x, y, 260, 'clone') then
            local cloned = eio.cloneSelection(state.selection.selectedBodies, state.physicsWorld)
            state.selection.selectedBodies = cloned
        end
        nextRow()

        if ui.button(x, y, 260, 'destroy') then
            for i = #state.selection.selectedBodies, 1, -1 do
                snap.destroySnapJointAboutBody(state.selection.selectedBodies[i].body)
                print('destroybody doesnt destroy the joint on it ?')
                objectManager.destroyBody(state.selection.selectedBodies[i].body)
            end

            state.selection.selectedBodies = nil
        end
        nextRow()

        if state.selection.selectedBodies and #state.selection.selectedBodies > 0 then
            local fb = state.selection.selectedBodies[1].body
            local fixtures = fb:getFixtures()
            local ff = fixtures[1]
            local groupIndex = ff:getGroupIndex()
            local groupIndexSlider = ui.sliderWithInput('groupIndex', x, y, 160, -32768, 32767, groupIndex)

            if groupIndexSlider then
                local value = math.floor(groupIndexSlider)
                local count = 0
                for i = 1, #state.selection.selectedBodies do
                    local b = state.selection.selectedBodies[i].body
                    local fixtures = b:getFixtures()
                    for j = 1, #fixtures do
                        fixtures[j]:setGroupIndex(value)
                        count = count + 1
                    end
                end
            end
            ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' groupid')
        end
        -- end
        nextRow()
    end)
end

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
        x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
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
            local cloned = eio.cloneSelection(state.selection.selectedBodies, state.physicsWorld)
            state.selection.selectedBodies = cloned
            state.selection.selectedObj = nil
        end

        if ui.button(x + 120, y, 140, 'destroy') then
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

        local dirtyBodyChange = false
        if (state.selection.lastSelectedBody ~= body) then
            dirtyBodyChange = true
            state.selection.lastSelectedBody = body
        end

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
                function(clicked)
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
                            local w = love.graphics.getFont():getWidth(behavior.name) + 20
                            if ui.button(x, y, w, behavior.name, BUTTON_HEIGHT, { 0.4, 0.4, 0.8 }) then
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
                function(clicked)
                    nextRow()
                    local value = thing.body:getX()
                    local numericInputText, dirty = ui.textinput(myID .. 'x', x, y, 120, BUTTON_HEIGHT, ".", "" .. value,
                        true,
                        clicked or not state.world.paused or state.interaction.draggingObj)
                    if hadBeenDraggingObj then
                        dirty = true
                    end
                    if (dirty) then
                        local numericPosX = tonumber(numericInputText)
                        if numericPosX then
                            thing.body:setX(numericPosX)
                        else
                            -- Handle invalid input, e.g., reset to previous value or show an error
                            logger:error("Invalid X position input!")
                        end
                    end
                    local value = thing.body:getY()
                    local numericInputText, dirty = ui.textinput(myID .. 'y', x + 140, y, 120, BUTTON_HEIGHT, ".",
                        "" .. value, true,
                        clicked or not state.world.paused or state.interaction.draggingObj)
                    if hadBeenDraggingObj then
                        dirty = true
                    end
                    if (dirty) then
                        local numericPosY = tonumber(numericInputText)
                        if numericPosY then
                            thing.body:setY(numericPosY)
                        else
                            -- Handle invalid input, e.g., reset to previous value or show an error
                            logger:error("Invalid Y position input!")
                        end
                    end
                    if hadBeenDraggingObj then
                        hadBeenDraggingObj = false
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
                        (body:isAwake() and not state.world.paused) or dirtyBodyChange)
                    if newAngle and (body:getAngle() * 180 / math.pi) ~= newAngle then
                        body:setAngle(newAngle * math.pi / 180)
                    end
                    ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' angle')


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
                function(clicked)
                    nextRow()

                    if ui.button(x, y, 120, 'flipX') then
                        state.selection.selectedObj = objectManager.flipThing(thing, 'x', true)
                        dirtyBodyChange = true
                    end
                    if ui.button(x + 140, y, 120, 'flipY') then
                        state.selection.selectedObj = objectManager.flipThing(thing, 'y', true)
                        dirtyBodyChange = true
                    end


                    nextRow()
                    if shapeType == 'circle' then
                        -- Show radius control for circles


                        local newRadius = ui.sliderWithInput(myID .. ' radius', x, y, ROW_WIDTH, 1, 200, thing.radius)
                        ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' radius')
                        if newRadius and newRadius ~= thing.radius then
                            state.selection.selectedObj = objectManager.recreateThingFromBody(body,
                                { shapeType = "circle", radius = newRadius })
                            state.editorPreferences.lastUsedRadius = newRadius
                            body = state.selection.selectedObj.body
                        end
                    elseif shapeType == 'rectangle' or shapeType == 'itriangle' then
                        -- Show width and height controls for these shapes


                        local newWidth = ui.sliderWithInput(myID .. ' width', x, y, ROW_WIDTH, 1, 800, thing.width)
                        ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' width')
                        nextRow()

                        local newHeight = ui.sliderWithInput(myID .. ' height', x, y, ROW_WIDTH, 1, 800, thing.height)
                        ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' height')

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
                        ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' width')
                        nextRow()

                        local newWidth2 = ui.sliderWithInput(myID .. ' width2', x, y, ROW_WIDTH, 1, 800, thing.width2)
                        ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' width2')
                        nextRow()

                        local newWidth3 = ui.sliderWithInput(myID .. ' width3', x, y, ROW_WIDTH, 1, 800, thing.width3)
                        ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' width3')
                        nextRow()

                        local newHeight = ui.sliderWithInput(myID .. ' height', x, y, ROW_WIDTH, 1, 800, thing.height)
                        ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' height')
                        nextRow()
                        local newHeight2 = ui.sliderWithInput(myID .. ' height2', x, y, ROW_WIDTH, 1, 800, thing.height2)
                        ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' height2')
                        nextRow()
                        local newHeight3 = ui.sliderWithInput(myID .. ' height3', x, y, ROW_WIDTH, 1, 800, thing.height3)
                        ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' height3')
                        nextRow()
                        local newHeight4 = ui.sliderWithInput(myID .. ' height4', x, y, ROW_WIDTH, 1, 800, thing.height4)
                        ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' height4')
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
                        ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' width')
                        nextRow()

                        local newWidth2 = ui.sliderWithInput(myID .. ' width2', x, y, ROW_WIDTH, 1, 800,
                            (thing.width2 or 5))
                        ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' width2')
                        nextRow()

                        local newHeight = ui.sliderWithInput(myID .. ' height', x, y, ROW_WIDTH, 1, 800, thing.height)
                        ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' height')

                        if (newWidth and newWidth ~= thing.width) or (newWidth2 and newWidth2 ~= thing.width2) or (newHeight and newHeight ~= thing.height) then
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
                                .radius,
                                dirtyBodyChange)
                            ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' radius')
                            if newRadius and newRadius ~= thing.radius then
                                state.selection.selectedObj = objectManager.recreateThingFromBody(body,
                                    { shapeType = shapeType, radius = newRadius })
                                state.editorPreferences.lastUsedRadius = newRadius
                                body = state.selection.selectedObj.body
                            end
                        else
                            -- No UI controls for custom or unsupported shapes
                            --+ (BUTTON_HEIGHT-ui.fontHeight)(x, y, 'custom')
                            if state.selection.selectedObj.shapeType == 'custom' then
                                if ui.button(x, y, 260, state.polyEdit.lockedVerts and 'verts locked' or 'verts unlocked') then
                                    state.polyEdit.lockedVerts = not state.polyEdit.lockedVerts
                                    if state.polyEdit.lockedVerts == false then
                                        state.polyEdit.tempVerts = utils.shallowCopy(state.selection.selectedObj
                                            .vertices)
                                        local cx, cy = mathutils.computeCentroid(state.selection.selectedObj.vertices)
                                        state.polyEdit.centroid = { x = cx, y = cy }
                                    else
                                        state.polyEdit.tempVerts = nil
                                        state.polyEdit.centroid = nil
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
                        ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' density')

                        -- Bounciness Slider
                        local bounciness = fixtures[1]:getRestitution()
                        nextRow()

                        local newBounce = ui.sliderWithInput(myID .. 'bounce', x, y, ROW_WIDTH, 0, 1, bounciness)
                        if newBounce and bounciness ~= newBounce then
                            for i = 1, #fixtures do
                                fixtures[i]:setRestitution(newBounce)
                            end
                        end
                        ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' bounce')

                        -- Friction Slider
                        local friction = fixtures[1]:getFriction()
                        nextRow()

                        local newFriction = ui.sliderWithInput(myID .. 'friction', x, y, ROW_WIDTH, 0, 1, friction)
                        if newFriction and friction ~= newFriction then
                            for i = 1, #fixtures do
                                fixtures[i]:setFriction(newFriction)
                            end
                        end
                        ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' friction')
                        nextRow()


                        local fb = thing.body
                        local fixtures = fb:getFixtures()
                        local ff = fixtures[1]
                        local firstNonUserdataFixture = ff
                        for k = 1, #fixtures do
                            local fixture = fixtures[k]
                            if fixture:getUserData() == nil then
                                firstNonUserdataFixture = fixture
                                break
                            end
                        end
                        local groupIndex = ff:getGroupIndex()
                        local groupIndexSlider = ui.sliderWithInput(myID .. 'groupIndex', x, y, 160, -32768, 32767,
                            groupIndex)
                        ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' groupid')
                        if groupIndexSlider then
                            local value = math.floor(groupIndexSlider)
                            local count = 0

                            local b = thing.body
                            local fixtures = b:getFixtures()
                            for j = 1, #fixtures do
                                fixtures[j]:setGroupIndex(value)
                                count = count + 1
                            end
                        end
                        nextRow()
                        if ui.checkbox(x, y, firstNonUserdataFixture:isSensor(), 'sensor') then
                            -- ff:setSensor(not ff:isSensor())
                            local b = thing.body
                            local fixtures = b:getFixtures()
                            local value = not firstNonUserdataFixture:isSensor()
                            for j = 1, #fixtures do
                                if not fixtures[j]:getUserData() then
                                    fixtures[j]:setSensor(value)
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
                    ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' ang-damping')
                    nextRow()

                    local linDamp = tonumber(body:getLinearDamping())
                    local newLinearDamping = ui.sliderWithInput(myID .. 'lind', x, y, ROW_WIDTH, 0, 10, linDamp,
                        body:isAwake() and not state.world.paused)
                    if newLinearDamping and linDamp ~= newLinearDamping then
                        body:setLinearDamping(newLinearDamping)
                    end
                    ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' lin-damping')
                    nextRow()
                end)
            nextRow()

            drawAccordion("motion",
                function()
                    -- set sleeping allowed
                    nextRow()
                    local dirty, checked = ui.checkbox(x, y, body:isSleepingAllowed(), 'sleep ok')
                    if dirty then
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
                    ui.label(x, y + (BUTTON_HEIGHT - ui.fontHeight), ' ang-vel')

                    nextRow()
                    local dirty, checked = ui.checkbox(x, y, body:isBullet(), 'bullet')
                    if dirty then
                        body:setBullet(not body:isBullet())
                    end

                    nextRow()
                end
            )
            nextRow()

            if not body:isDestroyed() then
                local attachedJoints = body:getJoints()
                if attachedJoints and #attachedJoints > 0 and not (#attachedJoints == 1 and attachedJoints[1]:getType() == 'mouse') then
                    drawAccordion("joints",
                        function()
                            for _, joint in ipairs(attachedJoints) do
                                -- Display joint type and unique identifier for identification
                                local jointType = joint:getType()
                                local jointID = tostring(joint)

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
                                        --print(inspect(joint:getUserData()))
                                        local ud = joint:getUserData()
                                        local x1, y1, x2, y2 = joint:getAnchors()
                                        -- local centroid = fixtures.getCentroidOfFixture(body, myfixtures[i])
                                        --  local x2, y2 = body:getLocalPoint(ud.offsetA.x, ud.offsetA.y)
                                        local x3, y3 = cam:getScreenCoordinates(x1, y1)
                                        love.graphics.circle('line', x3, y3, 6)
                                        local x3, y3 = cam:getScreenCoordinates(x2, y2)
                                        love.graphics.circle('line', x3, y3, 3)
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
                            logger:inspect(myfixtures[i]:getUserData())

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

function lib.drawUI()
    ui.startFrame()
    local w, h = love.graphics.getDimensions()
    if state.world.paused then
        love.graphics.setColor({ 244 / 255, 164 / 255, 97 / 255 })
    else
        love.graphics.setColor({ 245 /
        255, 245 / 255, 220 / 255 })
    end

    love.graphics.rectangle('line', 10, 10, w - 20, h - 20, 20, 20)
    love.graphics.setColor(1, 1, 1)

    -- "Add Shape" Button
    if ui.button(20, 20, 200, 'add shape') then
        state.panelVisibility.addShapeOpened = not state.panelVisibility.addShapeOpened
    end

    if state.panelVisibility.addShapeOpened then
        lib.drawAddShapeUI()
    end

    -- "Add Joint" Button
    if ui.button(230, 20, 200, 'add joint') then
        state.panelVisibility.addJointOpened = not state.panelVisibility.addJointOpened
    end

    if state.panelVisibility.addJointOpened then
        lib.drawAddJointUI()
    end

    -- "World Settings" Button
    if ui.button(440, 20, 200, 'settings') then
        state.panelVisibility.worldSettingsOpened = not state.panelVisibility.worldSettingsOpened
    end

    if state.panelVisibility.worldSettingsOpened then
        lib.drawWorldSettingsUI()
    end

    -- Play/Pause Button
    if ui.button(650, 20, 150, state.world.paused and 'play' or 'pause') then
        state.world.paused = not state.world.paused
    end

    if ui.button(810, 20, 150, state.world.isRecordingPointers and 'recording' or 'record') then
        state.panelVisibility.recordingPanelOpened = not state.panelVisibility.recordingPanelOpened
        -- state.world.isRecordingPointers = not state.world.isRecordingPointers
    end
    if state.panelVisibility.recordingPanelOpened then
        lib.drawRecordingUI()
    end

    if state.scene.sceneScript and state.scene.sceneScript.onStart then
        if ui.button(970, 20, 50, 'R') then
            -- todo actually reread the file itself!
            sceneLoader.loadAndRunScript(state.scene.scriptPath)
            script.call('onStart') --state.scene.sceneScript.onStart()
        end
    end








    if state.currentMode == 'drawClickMode' then
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
                logger:info('finalize clicked')
                objectManager.finalizePolygon()
            end
            x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
            if ui.button(x, y, 260, 'soft-surface') then
                objectManager.finalizePolygonAsSoftSurface()
            end
        end)
    end

    if state.selection.selectedObj and not state.selection.selectedJoint and not state.selection.selectedSFixture then
        lib.drawUpdateSelectedObjectUI()
    end

    if state.selection.selectedBodies and #state.selection.selectedBodies > 0 then
        lib.drawSelectedBodiesUI()
    end

    if (state.currentMode == 'jointCreationMode') and state.jointParams.body1 and state.jointParams.body2 then
        lib.doJointCreateUI(500, 100, 400, 150)
    end

    if state.selection.selectedSFixture then
        lib.drawSelectedSFixture()
    end

    if state.selection.selectedObj and state.selection.selectedJoint then
        -- (w - panelWidth - 20, 20, panelWidth, h - 40
        lib.doJointUpdateUI(state.selection.selectedJoint, w - PANEL_WIDTH - 20, 20, PANEL_WIDTH, h - 40)
    end

    if (state.currentMode == 'setOffsetA') or (state.currentMode == 'setOffsetB') or state.currentMode == 'positioningSFixture' then
        ui.panel(500, 100, 300, 60, '• click point ∆', function()
        end)
    end

    if (state.currentMode == 'addNodeToConnectedTexture') then
        ui.panel(500, 100, 400, 60, '• click anchor or joint to add ', function()
        end)
    end


    if (state.currentMode == 'jointCreationMode') and ((state.jointParams.body1 == nil) or (state.jointParams.body2 == nil)) then
        if (state.jointParams.body1 == nil) then
            ui.panel(500, 100, 300, 100, '• pick 1st body •', function()
                local x = 510
                local y = 150
                local width = 280
                if ui.button(x, y, width, 'cancel') then
                    state.jointParams = nil
                    state.currentMode = nil
                end
            end)
        elseif (state.jointParams.body2 == nil) then
            ui.panel(500, 100, 300, 100, '• pick 2nd body •', function()
                local x = 510
                local y = 150
                local width = 280
                if ui.button(x, y, width, 'cancel') then
                    state.jointParams = nil
                    state.currentMode = nil
                end
            end)
        end
    end

    if state.panelVisibility.showPalette then
        local w, h = love.graphics.getDimensions()
        ui.panel(10, h - 400, w - 300, 400, '• pick color •', function()
            --ui.coloredRect()
            local cellHeight = 50
            local itemsPerRow = math.floor((w - 300) / cellHeight)
            local numRows = math.ceil(110 / itemsPerRow)
            -- assume a similar height for each swatch cell
            local maxRows = math.floor(400 / cellHeight)

            for i = 1, #box2dDrawTextured.palette do
                local row = math.floor((i - 1) / itemsPerRow)
                local column = (i - 1) % itemsPerRow
                local x = column * cellHeight
                local y = row * cellHeight

                -- ui.coloredRect(0, 0, { 255, 0, 0 }, 40)
                if ui.coloredRect(10 + x, h - 300 + y, { box2dDrawTextured.hexToColor(box2dDrawTextured.palette[i]) }, 40) then
                    state.showPaletteFunc(box2dDrawTextured.palette[i])
                end
            end
        end)
    end

    if state.panelVisibility.saveDialogOpened then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle('fill', 0, 0, w, h)
        love.graphics.setColor(1, 1, 1)
        ui.panel(300, 300, w - 600, h - 600, '»»» save «««', function()
            local t = ui.textinput('savename', 320, 350, w - 640, 40, 'add text...', state.editorPreferences.saveName)
            if t then
                state.editorPreferences.saveName = utils.sanitizeString(t)
            end
            if ui.button(320, 500, 200, 'save') then
                state.panelVisibility.saveDialogOpened = false
                eio.save(state.physicsWorld, cam, state.editorPreferences.saveName)
            end
            if ui.button(540, 500, 200, 'cancel') then
                state.panelVisibility.saveDialogOpened = false
                love.system.openURL("file://" .. love.filesystem.getSaveDirectory())
            end
        end)
    end

    if state.panelVisibility.quitDialogOpened then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle('fill', 0, 0, w, h)
        love.graphics.setColor(1, 1, 1)

        local header = ' » really quit ? « '
        local minW = ui.font:getWidth(header)
        local panelW = math.max(minW, w - 600)
        local panelH = math.max(ui.font:getHeight() * 6, h - 600)
        local offW = w - panelW
        local offH = h - panelH
        local m = panelW - minW
        ui.panel(offW / 2, offH / 2, panelW, panelH, header, function()
            ui.label(offW / 2 + 20, offH / 2 + 40, '[esc] to quit')
            ui.label(offW / 2 + 20, offH / 2 + 80, '[space] to cancel')
        end)
    end

    --state.panelVisibility.customBehavior = { body = body, name = behavior.name }



    if state.panelVisibility.customBehavior then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle('fill', 0, 0, w, h)
        love.graphics.setColor(1, 1, 1)

        ui.panel(50, 50, 300, 300, state.panelVisibility.customBehavior.name,

            function()
                local lookup = utils.findByField(behaviors.allBehaviors, 'name',
                    state.panelVisibility.customBehavior.name)
                --print(inspect(lookedup))
                if lookup then
                    if ui.button(50, 50, 50, '?') then
                        if state.panelVisibility.customBehaviorDescription then
                            state.panelVisibility.customBehaviorDescription = false
                        else
                            state.panelVisibility.customBehaviorDescription = lookup.description
                        end
                    end
                end


                ui.scrollableList('custombehaviors', 50, 100, 280, 250,
                    function(baseX, baseY, w, h, offsetY)
                        if state.panelVisibility.customBehavior.name == 'LIMB_HUB' then
                            -- we can assume all these type of other things are attached via revolute joints
                            local me = state.panelVisibility.customBehavior.body
                            local joints = me:getJoints()
                            local names = {}
                            for i = 1, #joints do
                                local bodyA, bodyB = joints[i]:getBodies()
                                local otherBody = bodyA == me and bodyB or bodyA
                                --print(inspect(otherBody:getUserData().thing.label))
                                table.insert(names, otherBody:getUserData().thing.label)
                            end

                            local maxY = 0
                            local lineHeight = 30
                            for i = 1, #names do
                                local elementY = (baseY + offsetY) + (i - 1) * lineHeight
                                ui.button(baseX, elementY, 100, names[i])
                                local newValue = ui.textinput('limb_hub_vertexpicker' .. names[i], baseX + 100, elementY,
                                    50, BUTTON_HEIGHT, "vertex", 0)
                                -- _id, x, y, width, height, placeholder, currentText
                                --  ui.textinput()
                                maxY = maxY + lineHeight
                            end
                            return maxY
                        end
                        -- local maxY = 0
                        -- local lineHeight = 40
                        -- for i = 1, 28 do
                        --     local elementY = (baseY + offsetY) + (i - 1) * lineHeight
                        --     if elementY + lineHeight < baseY then
                        --     elseif elementY > baseY + h then
                        --     else
                        --         ui.button(baseX, elementY, 100, 'test2' .. i)
                        --     end
                        --     maxY = maxY + lineHeight
                        -- end

                        -- return maxY
                    end
                )
            end
        )
    end

    if state.panelVisibility.customBehaviorDescription then
        ui.panel(100, 50, 300, 300, '', function()
            love.graphics.printf(state.panelVisibility.customBehaviorDescription, 110, 100, 280)
        end, { .5, .5, .9 })
    end


    if state.panelVisibility.addBehavior then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle('fill', 0, 0, w, h)
        love.graphics.setColor(1, 1, 1)

        -- local all_options = {
        --     'KEEP_ANGLE',
        --     'LIMB_HUB'
        -- }




        local myUD = utils.deepCopy(state.panelVisibility.addBehavior.body:getUserData())
        --logger:inspect(myUD)
        local myBehaviors = myUD.thing.behaviors or {}

        local function updatePossibleOptions()
            local possible_options = {}
            for _, behavior in ipairs(behaviors.allBehaviors) do
                local isIn = false
                for j = 1, #myBehaviors do
                    if myBehaviors[j].name == behavior.name then
                        isIn = true
                        break
                    end
                end
                if not isIn then
                    table.insert(possible_options, behavior.name)
                end
            end
            return possible_options
        end

        local possible_options = updatePossibleOptions()

        ui.panel(50, 50, 300, 300, 'add behavior',
            function()
                for i, option in ipairs(possible_options) do
                    if ui.button(50, 100 + (i - 1) * 40, 200, option) then
                        --local newUD = utils.deepCopy(myUD)
                        if not myUD.thing.behaviors then
                            myUD.thing.behaviors = {}
                        end
                        table.insert(myUD.thing.behaviors, { name = option })
                        state.panelVisibility.addBehavior.body:setUserData(myUD)
                        state.panelVisibility.addBehavior = false
                        --table.insert(myBehaviors, {name = option})
                    end
                end
            end
        )
    end

    if ui.draggingActive then
        love.graphics.setColor(ui.theme.draggedElement.fill)
        local x, y = love.mouse.getPosition()
        love.graphics.circle('fill', x, y, 10)
        love.graphics.setColor(1, 1, 1)
    end
end

return lib

```

src//polyline.lua
```lua
local polyline = {}

local LINES_PARALLEL_EPS = 0.05;

local function Vector(x, y)
    if y then
        return { x = x, y = y }
    else -- clone vector
        return { x = x.x, y = x.y }
    end
end

local function length(vector)
    return math.sqrt(vector.x * vector.x + vector.y * vector.y)
end

local function normal(out, vector, scale)
    out.x = -vector.y * scale
    out.y = vector.x * scale
    return out
end

local function cross(x1, y1, x2, y2)
    return x1 * y2 - y1 * x2
end

local function renderEdgeNone(anchors, normals, s, len_s, ns, q, r, hw)
    table.insert(anchors, Vector(q))
    table.insert(anchors, Vector(q))
    table.insert(normals, Vector(ns))
    table.insert(normals, Vector(-ns.x, -ns.y))

    s.x, s.y = r.x - q.x, r.y - q.y
    len_s = length(s)
    normal(ns, s, hw / len_s)

    table.insert(anchors, Vector(q))
    table.insert(anchors, Vector(q))
    table.insert(normals, Vector(-ns.x, -ns.y))
    table.insert(normals, Vector(ns))

    return len_s
end

local function renderEdgeMiter(anchors, normals, s, len_s, ns, q, r, hw)
    local tx, ty = r.x - q.x, r.y - q.y
    local len_t = math.sqrt(tx * tx + ty * ty)
    local ntx, nty = -ty * (hw / len_t), tx * (hw / len_t)

    table.insert(anchors, Vector(q))
    table.insert(anchors, Vector(q))

    local det = cross(s.x, s.y, tx, ty)
    if (math.abs(det) / (len_s * len_t) < LINES_PARALLEL_EPS) and (s.x * tx + s.y * ty > 0) then
        -- lines parallel, compute as u1 = q + ns * w/2, u2 = q - ns * w/2
        table.insert(normals, Vector(ns))
        table.insert(normals, Vector(-ns.x, -ns.y))
    else
        -- cramers rule
        local nx, ny = ntx - ns.x, nty - ns.y
        local lambda = cross(nx, ny, tx, ty) / det
        local dx, dy = ns.x + (s.x * lambda), ns.y + (s.y * lambda)
        --print('craners', dx,dy)
        --if dx > math.pi*2 then dx = math.pi*2 end
        --if dx < -math.pi*2 then dx = -math.pi*2 end
        --if dy > math.pi*2 then dy = math.pi*2 end
        --if dy < -math.pi*2 then dy = -math.pi*2 end

        table.insert(normals, Vector(dx, dy))
        table.insert(normals, Vector(-dx, -dy))
    end

    s.x, s.y = tx, ty
    ns.x, ns.y = ntx, nty
    return len_t
end

local function renderEdgeBevel(anchors, normals, s, len_s, ns, q, r, hw)
    local tx, ty = r.x - q.x, r.y - q.y
    local len_t = math.sqrt(tx * tx + ty * ty)
    local ntx, nty = -ty * (hw / len_t), tx * (hw / len_t)

    local det = cross(s.x, s.y, tx, ty)
    if (math.abs(det) / (len_s * len_t) < LINES_PARALLEL_EPS) and (s.x * tx + s.y * ty > 0) then
        -- lines parallel, compute as u1 = q + ns * w/2, u2 = q - ns * w/2
        table.insert(anchors, Vector(q))
        table.insert(anchors, Vector(q))
        table.insert(normals, Vector(ntx, nty))
        table.insert(normals, Vector(-ntx, -nty))

        s.x, s.y = tx, ty
        return len_t -- early out
    end

    -- cramers rule
    local nx, ny = ntx - ns.x, nty - ns.y
    local lambda = cross(nx, ny, tx, ty) / det
    local dx, dy = ns.x + (s.x * lambda), ns.y + (s.y * lambda)

    table.insert(anchors, Vector(q))
    table.insert(anchors, Vector(q))
    table.insert(anchors, Vector(q))
    table.insert(anchors, Vector(q))
    if det > 0 then -- 'left' turn
        table.insert(normals, Vector(dx, dy))
        table.insert(normals, Vector(-ns.x, -ns.y))
        table.insert(normals, Vector(dx, dy))
        table.insert(normals, Vector(-ntx, -nty))
    else
        table.insert(normals, Vector(ns.x, ns.y))
        table.insert(normals, Vector(-dx, -dy))
        table.insert(normals, Vector(ntx, nty))
        table.insert(normals, Vector(-dx, -dy))
    end

    s.x, s.y = tx, ty
    ns.x, ns.y = ntx, nty
    return len_t
end

local function renderOverdraw(vertices, offset, vertex_count, overdraw_vertex_count, normals, pixel_size, is_looping)
    for i = 1, vertex_count, 2 do
        vertices[i + offset] = { vertices[i][1], vertices[i][2] }
        local length = length(normals[i])
        vertices[i + offset + 1] = {
            vertices[i][1] + normals[i].x * (pixel_size / length),
            vertices[i][2] + normals[i].y * (pixel_size / length)
        }
    end

    for i = 1, vertex_count, 2 do
        local k = vertex_count - i + 1
        vertices[offset + vertex_count + i] = { vertices[k][1], vertices[k][2] }
        local length = length(normals[i])
        vertices[offset + vertex_count + i + 1] = {
            vertices[k][1] + normals[k].x * (pixel_size / length),
            vertices[k][2] + normals[k].y * (pixel_size / length)
        }
    end

    if not is_looping then
        local spacerx, spacery = vertices[offset + 1][1] - vertices[offset + 3][1],
            vertices[offset + 1][2] - vertices[offset + 3][2]
        local spacer_length = math.sqrt(spacerx * spacerx + spacery * spacery)
        spacerx, spacery = spacerx * (pixel_size / spacer_length), spacery * (pixel_size / spacer_length)
        vertices[offset + 2][1], vertices[offset + 2][2] = vertices[offset + 2][1] + spacerx,
            vertices[offset + 2][2] + spacery
        vertices[offset + overdraw_vertex_count - 2][1] = vertices[offset + overdraw_vertex_count - 2][1] + spacerx
        vertices[offset + overdraw_vertex_count - 2][2] = vertices[offset + overdraw_vertex_count - 2][2] + spacery

        spacerx = vertices[offset + vertex_count - 0][1] - vertices[offset + vertex_count - 2][1]
        spacery = vertices[offset + vertex_count - 0][2] - vertices[offset + vertex_count - 2][2]
        spacer_length = math.sqrt(spacerx * spacerx + spacery * spacery)
        spacerx, spacery = spacerx * (pixel_size / spacer_length), spacery * (pixel_size / spacer_length)
        vertices[offset + vertex_count][1] = vertices[offset + vertex_count][1] + spacerx
        vertices[offset + vertex_count][2] = vertices[offset + vertex_count][2] + spacery
        vertices[offset + vertex_count + 2][1] = vertices[offset + vertex_count + 2][1] + spacerx
        vertices[offset + vertex_count + 2][2] = vertices[offset + vertex_count + 2][2] + spacery

        vertices[offset + overdraw_vertex_count - 1] = vertices[offset + 1]
        vertices[offset + overdraw_vertex_count - 0] = vertices[offset + 2]
    end
end

local function renderOverdrawNone(vertices, offset, vertex_count, overdraw_vertex_count, normals, pixel_size, is_looping)
    for i = 1, vertex_count - 1, 4 do
        local sx, sy = vertices[i][1] - vertices[i + 3][1], vertices[i][2] - vertices[i + 3][2]
        local tx, ty = vertices[i][1] - vertices[i + 1][1], vertices[i][2] - vertices[i + 1][2]
        local sl = math.sqrt(sx * sx + sy * sy)
        local tl = math.sqrt(tx * tx + ty * ty)
        sx, sy = sx * (pixel_size / sl), sy * (pixel_size / sl)
        tx, ty = tx * (pixel_size / tl), ty * (pixel_size / tl)

        local k = 4 * (i - 1) + 1 + offset
        vertices[k + 00] = { vertices[i + 0][1], vertices[i + 0][2] }
        vertices[k + 01] = { vertices[i + 0][1] + sx + tx, vertices[i + 0][2] + sy + ty }
        vertices[k + 02] = { vertices[i + 1][1] + sx - tx, vertices[i + 1][2] + sy - ty }
        vertices[k + 03] = { vertices[i + 1][1], vertices[i + 1][2] }

        vertices[k + 04] = { vertices[i + 1][1], vertices[i + 1][2] }
        vertices[k + 05] = { vertices[i + 1][1] + sx - tx, vertices[i + 1][2] + sy - ty }
        vertices[k + 06] = { vertices[i + 2][1] - sx - tx, vertices[i + 2][2] - sy - ty }
        vertices[k + 07] = { vertices[i + 2][1], vertices[i + 2][2] }

        vertices[k + 08] = { vertices[i + 2][1], vertices[i + 2][2] }
        vertices[k + 09] = { vertices[i + 2][1] - sx - tx, vertices[i + 2][2] - sy - ty }
        vertices[k + 10] = { vertices[i + 3][1] - sx + tx, vertices[i + 3][2] - sy + ty }
        vertices[k + 11] = { vertices[i + 3][1], vertices[i + 3][2] }

        vertices[k + 12] = { vertices[i + 3][1], vertices[i + 3][2] }
        vertices[k + 13] = { vertices[i + 3][1] - sx + tx, vertices[i + 3][2] - sy + ty }
        vertices[k + 14] = { vertices[i + 0][1] + sx + tx, vertices[i + 0][2] + sy + ty }
        vertices[k + 15] = { vertices[i + 0][1], vertices[i + 0][2] }
    end
end

local JOIN_TYPES = {
    miter = renderEdgeMiter,
    none = renderEdgeNone,
    bevel = renderEdgeBevel,
}

polyline.render = function(join_type, coords, half_width, pixel_size, draw_overdraw, rndMultiplier)
    local renderEdge = JOIN_TYPES[join_type]
    assert(renderEdge, join_type .. ' is not a valid line join type.')

    local anchors = {}
    local normals = {}

    local is_looping = (coords[1] == coords[#coords - 1]) and (coords[2] == coords[#coords])
    local s
    if is_looping then
        s = Vector(coords[1] - coords[#coords - 3], coords[2] - coords[#coords - 2])
    else
        s = Vector(coords[3] - coords[1], coords[4] - coords[2])
    end

    local len_s = length(s)
    local thick_index = 1
    --  print(inspect(half_width))
    local function getHalfWidth(index)
        --print(index, inspect(half_width))
        if type(half_width) == "table" then
            if index > #half_width then return half_width[#half_width] end

            return half_width[index]
        else
            return half_width
        end
    end

    local ns = normal({}, s, getHalfWidth(thick_index) / len_s)

    local r, q = Vector(coords[1], coords[2]), Vector(0, 0)
    for i = 1, #coords - 2, 2 do
        if draw_overdraw then
            half_width[thick_index] = getHalfWidth(thick_index) - pixel_size * 0.3
        end

        q.x, q.y = r.x, r.y
        r.x, r.y = coords[i + 2], coords[i + 3]
        ns = normal({}, s, getHalfWidth(thick_index) / len_s)
        len_s = renderEdge(anchors, normals, s, len_s, ns, q, r, getHalfWidth(thick_index))
        thick_index = thick_index + 1
    end

    q.x, q.y = r.x, r.y
    if is_looping then
        r.x, r.y = coords[3], coords[4]
    else
        r.x, r.y = r.x + s.x, r.y + s.y
    end

    -- 'fix', when you havent added enough thicknesses (1 more then lengths) just use the last one
    --hal_widthgetHalfWidth(thick_index)
    --if thick_index > #half_width then half_width[thick_index] = half_width[#half_width] end
    ns = normal({}, s, getHalfWidth(thick_index) / len_s)
    len_s = renderEdge(anchors, normals, s, len_s, ns, q, r, getHalfWidth(thick_index))


    local vertices = {}
    local indices = nil
    local draw_mode = 'strip'
    local vertex_count = #normals

    local extra_vertices = 0
    local overdraw_vertex_count = 0
    if draw_overdraw then
        if join_type == 'none' then
            overdraw_vertex_count = 4 * (vertex_count - 4 - 1)
        else
            overdraw_vertex_count = 2 * vertex_count
            if not is_looping then overdraw_vertex_count = overdraw_vertex_count + 2 end
            extra_vertices = 2
        end
    end

    if join_type == 'none' then
        vertex_count = vertex_count - 4
        for i = 3, #normals - 2 do
            table.insert(vertices, {
                anchors[i].x + normals[i].x,
                anchors[i].y + normals[i].y,
                0, 0, 255, 255, 255, 255
            })
        end
        draw_mode = 'triangles'
    else
        local firstR
        -- love.math.setRandomSeed(1 )  -- i cant do this it breaks surrounding code that relies on rand
        for i = 1, vertex_count do
            local r = 1
            if rndMultiplier ~= nil then
                r = love.math.random() * 4
                if i == 1 then
                    firstR = r
                end
                if i == vertex_count then
                    r = firstR
                end
                -- end
                r = 5 * rndMultiplier + (love.math.random() * rndMultiplier)
            end

            --if rndMultiplier ~= 0 then
            table.insert(vertices, {
                anchors[i].x + normals[i].x * (r),
                anchors[i].y + normals[i].y * (r),

            })
        end
        -- for i=1,vertex_count do
        --   table.insert(vertices, {
        --     anchors[i].x + normals[i].x,
        --     anchors[i].y + normals[i].y,
        --     0, 0, 255, 255, 255, 255
        --   })
        -- end
    end

    if draw_overdraw then
        if join_type == 'none' then
            renderOverdrawNone(vertices, vertex_count + extra_vertices, vertex_count, overdraw_vertex_count, normals,
                pixel_size, is_looping)
            for i = vertex_count + 1 + extra_vertices, #vertices do
                if ((i % 4) < 2) then
                    vertices[i][8] = 255
                else
                    vertices[i][8] = 0
                end
            end
        else
            renderOverdraw(vertices, vertex_count + extra_vertices, vertex_count, overdraw_vertex_count, normals,
                pixel_size,
                is_looping)
            for i = vertex_count + 1 + extra_vertices, #vertices do
                vertices[i][8] = 255 * (i % 2) -- alpha
            end
        end
    end

    if extra_vertices > 0 then
        vertices[vertex_count + 1] = { vertices[vertex_count][1], vertices[vertex_count][2] }
        vertices[vertex_count + 2] = { vertices[vertex_count + 3][1], vertices[vertex_count + 3][2] }
    end

    if draw_mode == 'triangles' then
        indices = {}
        local num_indices = (vertex_count + extra_vertices + overdraw_vertex_count) / 4
        for i = 0, num_indices - 1 do
            -- First triangle.
            table.insert(indices, i * 4 + 0 + 1)
            table.insert(indices, i * 4 + 1 + 1)
            table.insert(indices, i * 4 + 2 + 1)

            -- Second triangle.
            table.insert(indices, i * 4 + 0 + 1)
            table.insert(indices, i * 4 + 2 + 1)
            table.insert(indices, i * 4 + 3 + 1)
        end
    end

    return vertices, indices, draw_mode
end

return polyline

```

src//recorder.lua
```lua
local box2dPointerJoints = require 'src.box2d-pointerjoints'
local registry = require 'src.registry'
local utils = require 'src.utils'
local state = require 'src.state'

local recorder = {
    isRecording = false,
    isReplaying = false,
    isPaused = false,
    currentTime = 0,
    recordings = {},           -- Will hold multiple recording layers
    activeLayer = 1,
    events = {},               -- Current layer's events
    --objectStates = {},         -- Store initial states of objects
    recordingMouseJoints = {}, -- here we save the mousejoints (or data to recreate them) whilst recording them
    replayingMouseJoints = {}, -- here we keep the actual mousejoints that have been createdwhile replaying a recording.
    replayIndices = {}
}

function recorder:startRecording(layerIndex)
    self.isRecording = true
    self.currentTime = 0
    self.startTime = love.timer.getTime()
    self.activeLayer = layerIndex or #self.recordings + 1
    --self.events = {}
    --self.recordings = {}

    self.replayIndices = {}
    self.recordingMouseJoints = {} -- here we save the mousejoints (or data to recreate them) whilst recording them
    self.replayingMouseJoints = {} --

    logger:info('started recording on layer', self.activeLayer, layerIndex)
end

function recorder:stopRecording()
    self.isRecording = false
    self.recordings[self.activeLayer] = utils.deepCopy(self.events)
    self.events = {}
end

function recorder:startReplay()
    self.isReplaying = true
    self.currentTime = 0

    for i = 1, #self.recordings do
        self.replayIndices[i] = 1
    end
    -- Save initial world state
end

function recorder:update(dt)
    if not (self.isRecording or self.isReplaying) or self.isPaused then return end

    self.currentTime = self.currentTime + dt

    if self.isReplaying then
        -- Process all recordings
        for layerIdx = 1, #self.recordings do
            local events = self.recordings[layerIdx]
            --for layerIdx, events in ipairs(self.recordings) do
            --  local startIdx = self.replayIndices[layerIdx]
            --  local batchSize = 3
            -- local endIdx = math.min(startIdx + batchSize, #events)
            for i = 1, #events do
                local evt = events[i]
                -- print(evt.timestamp, self.currentTime)
                if evt.timestamp == self.currentTime then
                    --print('event at index ', i, #events)
                    recorder:processEvent(evt, layerIdx)
                    self.replayIndices[layerIdx] = i
                end
            end
            -- self:processEventsAtCurrentTime(events)
        end
    end
end

local function getPointerPosition(id)
    if id == 'mouse' then
        return love.mouse.getPosition()
    else
        return love.touch.getPosition(id)
    end
end
function recorder:recordMouseJointUpdates(cam)
    for k, v in pairs(self.recordingMouseJoints) do
        if v.data.pointerId then
            local x, y = getPointerPosition(v.data.pointerId)
            local wx, wy = cam:getWorldCoordinates(x, y)

            local event = {
                type = "object_interaction",
                timestamp = self.currentTime,
                action = "mousejoint-update",
                data = {
                    pointerId = v.data.pointerId,
                    objectId = v.data.objectId,
                    x = wx,
                    y = wy
                }
            }

            table.insert(self.events, event)
        end
    end
end

function recorder:recordMouseJointStart(data)
    local event = {
        type = "object_interaction",
        timestamp = self.currentTime,
        action = "mousejoint-start",
        data = {
            pointerId = data.pointerID,
            objectId = data.bodyID,
            wx = data.wx,
            wy = data.wy,
            force = data.force,
            damp = data.damp
        }
    }

    self.recordingMouseJoints[data.pointerID .. data.bodyID .. self.activeLayer] = event
    table.insert(self.events, event)
end

function recorder:recordMouseJointFinish(pointerid, bodyid)
    local event = {
        type = "object_interaction",
        timestamp = self.currentTime,
        action = "mousejoint-end",
        data = {
            pointerId = pointerid,
            objectId = bodyid,

        }
    }
    --   print(inspect(event))
    self.recordingMouseJoints[pointerid .. bodyid .. self.activeLayer] = nil
    table.insert(self.events, event)
end

function recorder:recordPause(pause)
    local event = {
        timestamp = self.currentTime,
        type = "world_interaction",
        action = "pause",
        data = {
            state = pause
        }
    }
    table.insert(self.events, event)
end

function recorder:recordObjectSetPosition(bodyId, x, y)
    local event = {
        timestamp = self.currentTime,
        type = "object_interaction",
        action = "position",
        data = {
            objectId = bodyId,
            x = x,
            y = y
        }
    }
    --print(inspect(event))
    table.insert(self.events, event)
end

-- During replay, we'll need to map recorded object IDs to current objects
function recorder:mapRecordedIdToCurrentObject(recordedId)
    return registry.getBodyByID(recordedId)
end

function recorder:processEvent(event, layerIdx)
    if event.type == "object_interaction" then
        local currentObject = self:mapRecordedIdToCurrentObject(event.data.objectId)

        if not currentObject then return end

        if event.action == "position" then
            currentObject:setPosition(event.data.x, event.data.y)
        elseif event.action == 'mousejoint-start' then
            local data = event.data
            local created = box2dPointerJoints.makePointerJoint(
                data.pointerId, registry.getBodyByID(data.objectId), data.wx, data.wy,
                data.force, data.damp)

            self.replayingMouseJoints[data.pointerId .. data.objectId .. layerIdx] =
            {
                joint = created.joint,
                body = created.jointBody,
                objectId = data.objectId
            }
        elseif event.action == 'mousejoint-update' then
            local data = event.data

            self.replayingMouseJoints[data.pointerId .. data.objectId .. layerIdx].joint:setTarget(data.x, data
                .y)
        elseif event.action == 'mousejoint-end' then
            local data = event.data
            local is = self.replayingMouseJoints[data.pointerId .. data.objectId .. layerIdx]

            if is and is.joint then
                is.joint:destroy()
            end

            self.replayingMouseJoints[data.pointerId .. data.objectId .. layerIdx] = nil
        else
            logger:info(inspect(event))
        end
    end
    if event.type == 'world_interaction' then
        if event.action == 'pause' then
            state.world.paused = event.data.state
        end
    end
end

return recorder

```

src//registry.lua
```lua
-- registry.lua
local utils = require 'src.utils'
--local snap = require 'src.snap'
local registry = {
    bodies = {}, -- [id] = body
    joints = {}, -- [id] = joint
    sfixtures = {},
    groups = {}
    -- Add more categories if needed
}

function registry.print()
    return '#b:' ..
        utils.tablelength(registry.bodies) ..
        ', #j:' .. utils.tablelength(registry.joints) .. ' #sf:' .. utils.tablelength(registry.sfixtures)
end

-- Register a body
function registry.registerBody(id, body)
    registry.bodies[id] = body
end

-- Unregister a body
function registry.unregisterBody(id)
    registry.bodies[id] = nil
end

-- Get a body by ID
function registry.getBodyByID(id)
    return registry.bodies[id]
end

-- Register a joint
function registry.registerJoint(id, joint)
    registry.joints[id] = joint
end

-- Unregister a joint
function registry.unregisterJoint(id)
    if not registry.joints[id] then
        logger:info('no s joint to unregister here', id)
    end
    --logger:info('unregistering joit ', id)
    registry.joints[id] = nil
end

-- Get a joint by ID
function registry.getJointByID(id)
    return registry.joints[id]
end

-- sfixtures
function registry.registerSFixture(id, sfix)
    registry.sfixtures[id] = sfix
    snap.rebuildSnapFixtures(registry.sfixtures)
end

function registry.unregisterSFixture(id)
    if not registry.sfixtures[id] then
        logger:info('no s fixture to unregister here')
    end
    registry.sfixtures[id] = nil
    snap.rebuildSnapFixtures(registry.sfixtures)
end

function registry.getSFixtureByID(id)
    return registry.sfixtures[id]
end

-- Reset the registry (useful when loading a new world)
function registry.reset()
    registry.bodies = {}
    registry.joints = {}
    registry.sfixtures = {}
    snap.rebuildSnapFixtures(registry.sfixtures)
end

return registry

```

src//scene-loader.lua
```lua
local lib = {}
local state = require 'src.state'
local eio = require 'src.io'
local script = require 'src.script'
local utils = require 'src.utils'
local camera = require 'src.camera'
local cam = camera.getInstance()

local hotReloadTimer = 0
local hotReloadInterval = 1
local lastModTime = 0

function lib.loadScene(name)
    local data = getFiledata(name):getString()
    state.selection.selectedJoint = nil
    state.selection.selectedObj = nil
    eio.load(data, state.physicsWorld, cam)
    logger:info("Scene loaded: " .. name)
    return data
end

function lib.loadScriptAndScene(id)
    local jsonPath = '/scripts/' .. id .. '.playtime.json'
    local luaPath = '/scripts/' .. id .. '.playtime.lua'
    jsoninfo = love.filesystem.getInfo(jsonPath)
    luainfo = love.filesystem.getInfo(luaPath)
    if (jsoninfo and luainfo) then
        local cwd = love.filesystem.getWorkingDirectory()
        lib.loadScene(cwd .. jsonPath)
        lib.loadAndRunScript(cwd .. luaPath)
    else
        logger:error('issue loading both files.')
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

function lib.loadAndRunScript(name)
    local data = getFiledata(name):getString()
    state.scene.sceneScript = script.loadScript(data, name)()
    state.scene.scriptPath = name
    script.setEnv({ worldState = state.world, world = state.physicsWorld, state = state })
    script.call('onUnload')
    script.call('onStart')

    lastModTime = getFileModificationTime(name)
end

function lib.maybeHotReload(dt)
    -- Accumulate time
    hotReloadTimer = hotReloadTimer + dt
    --state.scene.hotReloadTimer = state.scene.hotReloadTimer + dt
    -- Check if the accumulated time exceeds the interval
    --if state.scene.hotReloadTimer >= state.scene.hotReloadInterval then
    if hotReloadTimer >= hotReloadInterval then
        -- state.scene.hotReloadTimer = state.scene.hotReloadTimer - state.scene.hotReloadInterval -- Reset timer
        hotReloadTimer = hotReloadTimer - hotReloadInterval
        if state.scene.scriptPath then
            local newModeTime = (getFileModificationTime(state.scene.scriptPath))
            if (newModeTime ~= lastModTime) then
                logger:info('trying to load file because timestamp differs.')
                lib.loadAndRunScript(state.scene.scriptPath)
            end
            lastModTime = newModeTime
        end
    end
end

return lib

```

src//script.lua
```lua
--script.lua
local script = {}
local inspect = require 'vendor.inspect'
local camera = require 'src.camera'
local cam = camera.getInstance()
local utils = require 'src.utils'
local mathutils = require 'src.math-utils'
local shapes = require 'src.shapes'
local ui = require 'src.ui-all'
local box2dPointerJoints = require 'src.box2d-pointerjoints'
local uuid = require 'src.uuid'
local registry = require 'src.registry'
local objectManager = require 'src.object-manager'
local state = require 'src.state'
--- here a tiny collection of helper function will grow, function i am sure that will be reused in various scripts.
function getObjectsByLabel(label)
    local objects = {}
    for _, body in pairs(state.physicsWorld:getBodies()) do
        local userData = body:getUserData()
        if (userData and userData.thing and userData.thing.label == label) then
            table.insert(objects, userData.thing)
        end
    end
    return objects
end

function mouseWorldPos()
    local mx, my = love.mouse:getPosition()
    local cx, cy = cam:getWorldCoordinates(mx, my)
    return cx, cy
end

-- end collection

local scriptEnv = {
    generateID               = uuid.generateID,
    objectManager            = objectManager,
    ui                       = ui,
    cam                      = cam,
    mathutils                = mathutils,
    getPJAttachedTo          = box2dPointerJoints.getPointerJointAttachedTo,
    getInteractedWithPointer = box2dPointerJoints.getInteractedWithPointer,
    polygonClip              = mathutils.polygonClip,
    pairs                    = pairs,
    ipairs                   = ipairs,
    table                    = table,
    inspect                  = inspect,
    print                    = print,
    math                     = math,
    love                     = love,
    random                   = love.math.random,
    getObjectsByLabel        = getObjectsByLabel,
    world                    = state.physicsWorld,
    string                   = string,
    mouseWorldPos            = mouseWorldPos,
    worldState               = state.world,
    unpack                   = unpack,
    getmetatable             = getmetatable,
    registry                 = registry
    -- Add global utilities like NeedManager, etc.
    --broadcastEvent = function(eventName, data)
    -- Implementation for event broadcasting
    --end,
}

function script.setEnv(newEnv)
    for key, value in pairs(newEnv) do
        scriptEnv[key] = value
    end
end

function script.call(method, ...)
    if state.scene.sceneScript and state.scene.sceneScript[method] then
        state.scene.sceneScript[method](...)
    end
end

function script.loadScript(data, filePath)
    --print('>>>>> script environment api')
    --printTableKeys(scriptEnv)
    --print('>>>>>')
    local scriptContent = data
    if not scriptContent then
        error("Script not found: " .. filePath)
    end


    local chunk, err = load(scriptContent, "@" .. filePath, "t", scriptEnv)
    if err then
        logger:error('error: ' .. err)
    else
        if not chunk then
            error("Error loading script: " .. err)
        end

        local success, err = pcall(chunk)
        if not success then
            error("Error executing script: " .. err)
        end

        logger:info("Script loaded: " .. filePath)
        if success then
            return chunk
        end
    end

    return function()
        local s = {}
        s.onStart = function() logger:error("error: " .. err .. "\nError in script: " .. filePath) end
        s.foundError = err -- utils.insertNewlines(err, 100)
        return s
    end
end

return script

```

src//selection-rect.lua
```lua
--selection-rect.lua
local lib = {}
local mathutils = require 'src.math-utils'

-- Include the drawDottedLine function here
local function drawDottedLine(x1, y1, x2, y2, dotSize, spacing)
    local dx = x2 - x1
    local dy = y2 - y1
    local distance = math.sqrt(dx * dx + dy * dy)

    local numDots = math.floor(distance / spacing)

    local stepX = dx / distance
    local stepY = dy / distance

    for i = 0, numDots do
        local cx = x1 + stepX * spacing * i
        local cy = y1 + stepY * spacing * i
        love.graphics.rectangle("fill", cx, cy, dotSize, dotSize)
    end
end

-- Convert local shape vertices to world coordinates based on the body's position and angle
local function getShapeWorldPoints(body, shape)
    local points = {}
    local angle = body:getAngle()
    local xBody, yBody = body:getPosition()

    if shape:typeOf("CircleShape") then
        -- For circles, represent as the center point
        table.insert(points, { x = xBody, y = yBody })
    elseif shape:typeOf("PolygonShape") or shape:typeOf("EdgeShape") then
        local points2 = { shape:getPoints() }

        for i = 1, #points2, 2 do
            local localX, localY = points2[i], points2[i + 1]
            -- Apply rotation
            local rotatedX = localX * math.cos(angle) - localY * math.sin(angle)
            local rotatedY = localX * math.sin(angle) + localY * math.cos(angle)
            -- Translate to world coordinates
            local worldX = xBody + rotatedX
            local worldY = yBody + rotatedY
            table.insert(points, { x = worldX, y = worldY })
        end
    elseif shape:typeOf("RectangleShape") then
        logger:error('NOT HANDLING THIS SHAPE RectangleShape')
        -- Handle RectangleShape if using a custom shape type
        -- Love2D does not have a native RectangleShape; rectangles are typically PolygonShapes
    else
        logger:error('NOT HANDLING THIS SHAPE ??')
    end

    return points
end



function lib.draw(selection)
    local x, y = love.mouse:getPosition()
    local tlx = math.min(selection.x, x)
    local tly = math.min(selection.y, y)
    local brx = math.max(selection.x, x)
    local bry = math.max(selection.y, y)

    drawDottedLine(tlx, tly, brx, tly, 5, 10)
    drawDottedLine(brx, tly, brx, bry, 5, 10)
    drawDottedLine(tlx, bry, brx, bry, 5, 10)
    drawDottedLine(tlx, tly, tlx, bry, 5, 10)
end

function lib.selectWithin(world, rect)
    local bodiesInside = {}
    for _, body in pairs(world:getBodies()) do
        local userData = body:getUserData()
        local thing = userData and userData.thing
        if thing then
            local fixtures = body:getFixtures()
            local allFixturesInside = true
            for _, fixture in ipairs(fixtures) do
                local shape = fixture:getShape()
                local worldPoints = getShapeWorldPoints(body, shape)

                -- For each point of the shape, check if it's inside the rectangle
                for _, point in ipairs(worldPoints) do
                    if not mathutils.pointInRect(point.x, point.y, rect) then
                        allFixturesInside = false
                        break -- No need to check further points
                    end
                end
                if not allFixturesInside then
                    break -- No need to check further fixtures
                end
            end
            if allFixturesInside then
                table.insert(bodiesInside, thing)
            end
        end
    end
    return bodiesInside
end

return lib

```

src//shapes.lua
```lua
-- shapes.lua

local mathutils = require 'src.math-utils'
local utils = require 'src.utils'
local inspect = require 'vendor.inspect'
local shapes = {}

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

local function capsuleXY(w, h, csw, x, y)
    -- cs == cornerSize
    local w2 = w / 2
    local h2 = h / 2

    local bt = -h2 + csw --* 2
    local bb = h2 - csw  --* 2
    local bl = -w2 + csw
    local br = w2 - csw

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

local function torso(w1, w2, w3, h1, h2, h3, h4, x, y)
    return {
        x, y - h1 - h2,
        x + w1 / 2, y - h2,
        x + w2 / 2, y,
        x + w3 / 2, y + h3,
        x, y + h3 + h4,
        x - w3 / 2, y + h3,
        x - w2 / 2, y,
        x - w1 / 2, y - h2,
    }
end


local function approximateCircle(radius, centerX, centerY, segments)
    segments = segments or 32 -- Default to 32 segments if not specified
    local vertices = {}
    local angleIncrement = (2 * math.pi) / segments

    for i = 0, segments - 1 do
        local angle = i * angleIncrement
        local x = centerX + radius * math.cos(angle)
        local y = centerY + radius * math.sin(angle)
        table.insert(vertices, x)
        table.insert(vertices, y)
    end

    return vertices
end

local function rect(w, h, x, y)
    return {
        x - w / 2, y - h / 2,
        x + w / 2, y - h / 2,
        x + w / 2, y + h / 2,
        x - w / 2, y + h / 2
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

local function makeITriangle(w, h, x, y)
    return {
        x - w / 2, y + h / 2,
        x + w / 2, y + h / 2,
        x, y - h / 2
    }
end

function shapes.makeTrianglesFromPolygon(polygon)
    -- when this is true we also solve, self intersecting and everythign
    local triangles = {}
    local result = {}
    local success, err = pcall(function()
        mathutils.decompose(polygon, result)
    end)

    if not success then
        logger:error("Error in decompose_complex_poly: " .. err)
        return nil -- Exit early if decomposition fails
    end

    for i = 1, #result do
        local success, tris = pcall(love.math.triangulate, result[i])
        if success then
            utils.tableConcat(triangles, tris)
        else
            logger:error("Failed to triangulate part of the polygon: " .. tris)
        end
    end
    return triangles
end

local function makeShapeListFromPolygon(polygon)
    local shapesList = {}
    local allowComplex = true -- TODO: parameterize this
    local triangles = {}

    -- first figure out if we are maybe a simple polygon we can use -as is- by box2d
    if #polygon <= 16 and love.math.isConvex(polygon) then
        --print('cause its simple!')
        local centroidX, centroidY = mathutils.computeCentroid(polygon)
        local localVertices = {}
        for i = 1, #polygon, 2 do
            local x = polygon[i] - centroidX
            local y = polygon[i + 1] - centroidY
            table.insert(localVertices, x)
            table.insert(localVertices, y)
        end
        table.insert(shapesList, love.physics.newPolygonShape(localVertices))
    else                     -- ok we are not the simplest polygons we need more work,
        if allowComplex then -- when this is true we also solve, self intersecting and everythign
            local result = {}
            local success, err = pcall(function()
                mathutils.decompose(polygon, result)
            end)

            if not success then
                logger:error("Error in decompose_complex_poly: " .. err)
                return nil -- Exit early if decomposition fails
            end

            for i = 1, #result do
                local success, tris = pcall(love.math.triangulate, result[i])
                if success then
                    utils.tableConcat(triangles, tris)
                else
                    logger:error("Failed to triangulate part of the polygon: " .. tris)
                end
            end
        else -- this is a bit of a nono, its no longer really in use and doenst fix all werid cases. faster though.
            local success, result = pcall(love.math.triangulate, polygon)
            if success then
                triangles = result
            else
                logger:error("Failed to triangulate polygon: " .. result)
                return nil -- Exit early if triangulation fails
            end
        end

        if #triangles == 0 then
            logger:error("No valid triangles were created.")
            return nil
        end
        local centroidX, centroidY = mathutils.computeCentroid(polygon)
        for _, triangle in ipairs(triangles) do
            -- Adjust triangle vertices relative to body position
            local localVertices = {}
            for i = 1, #triangle, 2 do
                local x = triangle[i] - centroidX
                local y = triangle[i + 1] - centroidY
                table.insert(localVertices, x)
                table.insert(localVertices, y)
            end

            local shapeSuccess, shape = pcall(love.physics.newPolygonShape, localVertices)
            if shapeSuccess then
                table.insert(shapesList, shape)
            else
                logger:error("Failed to create shape for triangle: " .. shape)
            end
        end
    end
    return shapesList
end

-- function shapes.getTriangles(polygon)
--     local triangles = {}
--     local result = {}
--     local success, err = pcall(function()
--         mathutils.decompose(polygon, result)
--     end)


--     for i = 1, #result do
--         local success, tris = pcall(love.math.triangulate, result[i])
--         if success then
--             utils.tableConcat(triangles, tris)
--         else
--             print("Failed to triangulate part of the polygon: " .. tris)
--         end
--     end
--     return triangles
-- end




function shapes.createShape(shapeType, settings)
    if (settings.radius == 0) then settings.radius = 1 end
    if (settings.width == 0) then settings.width = 1 end
    if (settings.height == 0) then settings.height = 1 end

    local shapesList = {}
    local vertices = nil

    if shapeType == 'circle' then
        vertices = approximateCircle(settings.radius, 0, 0, 20)
        --table.insert(shapesList, love.physics.newPolygonShape(vertices))
        table.insert(shapesList, love.physics.newCircleShape(settings.radius))
    elseif shapeType == 'rectangle' then
        vertices = rect(settings.width, settings.height, 0, 0)
        table.insert(shapesList, love.physics.newRectangleShape(settings.width, settings.height))
    elseif shapeType == 'torso' then
        vertices = torso(settings.width, settings.width2, settings.width3, settings.height,
            settings.height2,
            settings.height3, settings.height4, 0, 0)
        shapesList = makeShapeListFromPolygon(vertices) or {}
        --table.insert(shapesList, love.physics.newPolygonShape(vertices))
    elseif shapeType == 'capsule' then
        local radius = math.min(settings.width / (settings.width2 or 1), settings.height / (settings.width2 or 1))
        vertices = capsuleXY(settings.width, settings.height, radius, 0, 0)
        table.insert(shapesList, love.physics.newPolygonShape(vertices))
    elseif shapeType == 'trapezium' then
        vertices = makeTrapezium(settings.width, settings.width2 or (settings.width * 1.2), settings.height, 0, 0)
        table.insert(shapesList, love.physics.newPolygonShape(vertices))
    elseif shapeType == 'itriangle' then
        vertices = makeITriangle(settings.width, settings.height, 0, 0)
        table.insert(shapesList, love.physics.newPolygonShape(vertices))
    elseif shapeType == 'shape8' then
        --local v = makeTransformedVertices(settings.optionalVertices)
        vertices = settings.optionalVertices

        shapesList = makeShapeListFromPolygon(vertices) or {}
        -- logger:info('lets start to make a thingie', inspect(settings))
    else
        local sides = ({
            triangle = 3,
            pentagon = 5,
            hexagon = 6,
            heptagon = 7,
            octagon = 8,
        })[shapeType]

        if sides then
            vertices = makePolygonVertices(sides, settings.radius)
            local cx, cy = mathutils.getCenterOfPoints(vertices)
            local rel = mathutils.makePolygonRelativeToCenter(vertices, cx, cy)
            vertices = mathutils.makePolygonAbsolute(rel, 0, 0)
            table.insert(shapesList, love.physics.newPolygonShape(vertices))
        elseif shapeType == 'custom' then
            if settings.optionalVertices then
                local polygon = settings.optionalVertices

                shapesList = makeShapeListFromPolygon(polygon) or {}

                vertices = polygon
            else
                error('shapetype custom needs optionalVertices!')
            end
        else
            --print(shapeType, radius, width, height, optionalVertices)
            error("Unknown shape type: " .. tostring(shapeType))
        end
    end
    return shapesList, vertices
end

return shapes

```

src//snap.lua
```lua
-- general usage snap logic
--
local uuid = require 'src.uuid'
local utils = require 'src.utils'
local box2dPointerJoints = require 'src.box2d-pointerjoints'
local mathutils = require 'src.math-utils'

local snapFixtures = {}
local snapDistance = 140           -- Maximum distance to snap
local mySnapJoints = {}            -- Store created joints
local jointBreakThreshold = 100000 -- Force threshold for breaking the joint
local cooldownTime = .5            -- Time in seconds to prevent immediate reconnection
local cooldownList = {}            -- Table to track cooldown for each snap point
local onlyConnectWhenInteracted = true
local onlyBreakWhenInteracted = true

local lib = {}


-- todo currently snap is a bit broken.. (snap fixtures dont seem to have the at and to in the xtra data set ?)
-- the script 'snap.playtime.lua' is wroking investigate this further in the near future

-- Add cooldown to a snap point
local function addCooldown(fixture)
    local currentTime = love.timer.getTime()
    cooldownList[fixture] = currentTime + cooldownTime
end

-- Check if a snap point is in cooldown
local function isInCooldown(fixture, currentTime)
    return cooldownList[fixture] and currentTime < cooldownList[fixture]
end


local function oneOfThemIsInteractedWith(b1, b2, list)
    for i = 1, #list do
        if list[i] == b1 or list[i] == b2 then
            return true
        end
    end
    return false
end
-- Create a revolute joint between two bodies
local function createRevoluteJoint(body1, body2, x, y, x2, y2, index1, index2)
    local id = uuid.generateID()

    local joint = love.physics.newRevoluteJoint(body1, body2, x, y, x2, y2)

    local xa, ya = body1:getLocalPoint(x, y)
    local offsetA = { x = xa, y = ya }

    local xb, yb = body1:getLocalPoint(x2, y2)

    local offsetB = { x = xb, y = yb }

    joint:setUserData({ id = id, offsetA = offsetA, offsetB = offsetB, scriptmeta = { type = 'snap' } })
    --  joint:setUserData({ id = id, scriptmeta = { type = 'snap', index1 = index1, index2 = index2 } })
    table.insert(mySnapJoints, joint)
    registry.registerJoint(id, joint)
end

local function areBodiesConnected2(body1, body2, snapFixtures)
    for i = 1, #snapFixtures do
        local it = snapFixtures[i]:getUserData().extra
        if (it.to == body1 and it.at == body2) or (it.to == body2 and it.at == body1) then
            return true
        end
    end
    return false
end


function checkForJointBreaks(dt, interacted, snapFixtures)
    for i = #mySnapJoints, 1, -1 do
        local joint = mySnapJoints[i]

        -- Check if the force exceeds the threshold
        local xf, yf = joint:getReactionForce(1 / dt)

        if math.max(math.abs(xf), math.abs(yf)) > jointBreakThreshold then
            -- Break the joint
            -- Cleanup: Mark the snap points as disconnected
            local body1, body2 = joint:getBodies()
            if (not onlyBreakWhenInteracted or (oneOfThemIsInteractedWith(body1, body2, interacted))) then
                for j = 1, #snapFixtures do
                    local extra = snapFixtures[j]:getUserData().extra
                    if extra.to == body1 and extra.at == body2 then
                        extra.to = nil
                        local ud = snapFixtures[j]:getUserData()
                        ud.extra = extra
                        snapFixtures[j]:setUserData(ud)
                        addCooldown(snapFixtures[j])
                    elseif extra.to == body2 and extra.at == body1 then
                        extra.to = nil
                        local ud = snapFixtures[j]:getUserData()
                        ud.extra = extra
                        snapFixtures[j]:setUserData(ud)
                        addCooldown(snapFixtures[j])
                    end
                end
                registry.unregisterJoint(joint:getUserData().id)

                joint:destroy()
                -- Remove the joint from the list of joints
                table.remove(mySnapJoints, i)
            end
        end
    end
end

local function checkForSnaps(interacted, snapFixtures)
    local currentTime = love.timer.getTime()

    for i = 1, #snapFixtures do
        local it1 = snapFixtures[i]:getUserData().extra

        if it1.to == nil and not isInCooldown(it1.fixture, currentTime) then -- else this snap point is already connected and it cannot be connected more then once
            local body1 = it1.at
            if not body1 then
                logger:error('body1 is nil!    ')
                logger:info(inspect(it1))
            end

            -- todo , src/snap.lua:119: attempt to call method 'getWorldPoint' (a nil value)

            local x1, y1 = body1:getWorldPoint(it1.xOffset, it1.yOffset)

            for j = 1, #snapFixtures do
                if j ~= i then                                                           -- else you check it against it
                    local it2 = snapFixtures[j]:getUserData().extra
                    if it2.to == nil and not isInCooldown(it2.fixture, currentTime) then -- else it2 is already connected,
                        local body2 = it2.at
                        local x2, y2 = body2:getWorldPoint(it2.xOffset, it2.yOffset)

                        local distance = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
                        if distance <= snapDistance then
                            if (not onlyConnectWhenInteracted or (oneOfThemIsInteractedWith(body1, body2, interacted))) then
                                if not areBodiesConnected2(body1, body2, snapFixtures) then -- else these bodies are already connected..
                                    createRevoluteJoint(body1, body2, x1, y1, x2, y2, i, j)
                                    it1.to = body2
                                    local ud1 = snapFixtures[i]:getUserData()
                                    ud1.extra = it1
                                    snapFixtures[i]:setUserData(ud1)

                                    it2.to = body1
                                    local ud2 = snapFixtures[j]:getUserData()
                                    ud2.extra = it2
                                    snapFixtures[j]:setUserData(ud2)
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end


function lib.update(dt)
    if #snapFixtures > 0 then
        --print('amount of snapfixtures: ', #snapFixtures)
        local interacted = box2dPointerJoints.getInteractedWithPointer()
        checkForSnaps(interacted, snapFixtures)
        checkForJointBreaks(dt, interacted, snapFixtures) -- Check for joint breaks every frame
    end
end

function lib.maybeUpdateSFixture(id)
    for i = 1, #snapFixtures do
        -- TODO snapFixtures should bbecome a key value map keyed on IDs
        if (snapFixtures[i]:isDestroyed() or snapFixtures[i]:getUserData().id == id) then
            snapFixtures[i] = registry.getSFixtureByID(id)
        end
    end
end

function lib.rebuildSnapFixtures(sfix)
    snapFixtures = {}
    local count = 0
    for k, v in pairs(sfix) do
        if not v:isDestroyed() then
            local ud = v:getUserData()
            --logger:inspect(ud)
            if ud and utils.sanitizeString(ud.subtype) == 'snap' then
                local centroid = { mathutils.getCenterOfPoints({ v:getShape():getPoints() }) }
                local ud = v:getUserData()

                ud.extra.xOffset = centroid[1]
                ud.extra.yOffset = centroid[2]
                ud.extra.at = v:getBody()
                ud.extra.fixture = v
                v:setUserData(ud)
                table.insert(snapFixtures, v)
            else
                --     --print('what is wrong ?', not v:isDestroyed(), ud, ud.label == 'snap',
                --     --    ud.label)
            end
            count = count + 1
        end
    end
    --print('we now have ', #snapFixtures, 'snapfixtures')
end

function calculateDistance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

function lib.onSceneLoaded()
    --print('should build snapjoints array', #mySnapJoints)

    for k, value in pairs(registry.joints) do
        local ud = value:getUserData()

        -- Check if the joint is a snap-type joint
        --if ud and ud.scriptmeta and ud.scriptmeta.type and ud.scriptmeta.type == 'snap' then
        --    print('wowzers')
        --end

        -- Check if the joint is a snap-type joint
        if ud and ud.scriptmeta and ud.scriptmeta.type and ud.scriptmeta.type == 'snap' then
            -- Get the two bodies connected by the joint
            local bodyA, bodyB = value:getBodies()
            -- Get the anchor points of the joint
            local x1, y1, x2, y2 = value:getAnchors()
            -- Retrieve unique IDs for both bodies
            local id1 = bodyA:getUserData().thing.id
            local id2 = bodyB:getUserData().thing.id
            -- Tables to store possible snap point indices for each body
            local indx1Options = {}
            local indx2Options = {}


            for i = 1, #snapFixtures do
                local extra = snapFixtures[i]:getUserData().extra
                local atId = extra.at:getUserData().thing.id

                if (atId == id1) then
                    table.insert(indx1Options, i)
                end
                if (atId == id2) then
                    table.insert(indx2Options, i)
                end
            end

            -- Initialize variables to find the closest snap point for bodyA
            local indx1
            local indx1dist = math.huge

            -- Determine the closest snap point for bodyA to the joint's first anchor
            for i = 1, #indx1Options do
                local index = indx1Options[i]
                local extra = snapFixtures[index]:getUserData().extra
                local wx, wy = extra.at:getLocalPoint(x1, y1)
                local distance = calculateDistance(extra.xOffset, extra.yOffset, wx, wy)
                if distance < indx1dist then
                    indx1dist = distance
                    indx1 = index
                end
            end

            --print(indx1, indx1dist)
            -- Initialize variables to find the closest snap point for bodyB
            local indx2
            local indx2dist = math.huge

            -- Determine the closest snap point for bodyB to the joint's second anchor
            for i = 1, #indx2Options do
                local index = indx2Options[i]
                local extra = snapFixtures[index]:getUserData().extra
                local wx, wy = extra.at:getLocalPoint(x2, y2)
                local distance = calculateDistance(extra.xOffset, extra.yOffset, wx, wy)
                if distance < indx2dist then
                    indx2dist = distance
                    indx2 = index
                end
            end

            -- Link the two closest snap points by setting their 'to' references

            local i1ud = snapFixtures[indx1]:getUserData()
            local i2ud = snapFixtures[indx2]:getUserData()

            i1ud.extra.to = i2ud.extra.at
            i2ud.extra.to = i1ud.extra.at
            snapFixtures[indx1]:setUserData(i1ud)
            snapFixtures[indx2]:setUserData(i2ud)


            table.insert(mySnapJoints, value)
        end
    end
end

function lib.resetList()
    mySnapJoints = {}
end

function lib.addSnapJoint(j)
    table.insert(mySnapJoints, j)
end

function lib.maybeUpdateSnapJoints(joints)
    for i = 1, #mySnapJoints do
        local msj = mySnapJoints[i]
        local lookForId = msj:getUserData().id

        for j = 1, #joints do
            local newer = joints[j]

            if (lookForId == newer.id) then
                mySnapJoints[i] = registry.getJointByID(newer.id)
            end
        end
    end
end

function lib.maybeUpdateSnapJointWithId(id)
    for i = 1, #mySnapJoints do
        local msj = mySnapJoints[i]
        -- TODO mySnapJoints should bbecome a key value map keyed on IDs
        if msj:isDestroyed() or msj:getUserData().id == id then
            mySnapJoints[i] = registry.getJointByID(id)
        end
        --if snap.maybeUpdateSnapJointWithId(id)
    end
end

function lib.destroySnapJointAboutBody(body)
    for i = #mySnapJoints, 1, -1 do
        local joint = mySnapJoints[i]
        local body1, body2 = joint:getBodies()
        if (body:getUserData().thing.id == body1:getUserData().thing.id) then
            registry.unregisterJoint(joint:getUserData().id)
            joint:destroy()
            table.remove(mySnapJoints, i)
        end
        if (body:getUserData().thing.id == body2:getUserData().thing.id) then
            registry.unregisterJoint(joint:getUserData().id)

            joint:destroy()
            table.remove(mySnapJoints, i)
        end
    end
end

return lib
-- end general snap

```

src//state.lua
```lua
local state = {}


state.scene = {
    sceneScript = nil,
    scriptPath = nil,
    checkpoints = {},
    activeCheckpointIndex = 0
}

state.selection = {
    selectedObj = nil,
    selectedJoint = nil,
    selectedSFixture = nil,
    selectedBodies = nil,
    lastSelectedBody = nil, -- Maybe belongs here? Or separate interaction tracker?
}

state.interaction = { -- State directly related to ongoing user actions
    draggingObj = nil,
    offsetDragging = { nil, nil },
    polyVerts = {},       -- Temporary vertices while drawing
    lastPolyPt = nil,
    startSelection = nil, -- For selection rect
}

state.panelVisibility = {
    addShapeOpened = false,
    addJointOpened = false,
    worldSettingsOpened = false,
    recordingPanelOpened = false,
    saveDialogOpened = false,
    quitDialogOpened = false,
    showPalette = nil,
    addBehavior = false,
    customBehavior = false,
    customBehaviorDescription = false,
}

state.editorPreferences = { -- Less volatile state
    showGrid = false,
    nextType = 'dynamic',
    lastUsedRadius = 20,
    lastUsedWidth = 40,
    lastUsedWidth2 = 5,
    lastUsedHeight = 40,
    lastUsedHeight2 = 40,
    saveName = 'untitled',
    showTexFixtureDim = false,
    axisEnabled = false,
    minPointDistance = 50, -- Could be editor config
}

state.polyEdit = {
    dragIdx = 0,
    tempVerts = nil,
    lockedVerts = true,
    centroid = nil
}

state.texFixtureEdit = {
    dragIdx = 0,
    lockedVerts = true,
    tempVerts = nil,
    verts = {}
}

--state.scrollers = {}    -- will be filled with scrollers ({value=0})

state.currentMode = nil -- 'jointCreationMode' 'drawFreePoly' 'drawClickPoly', 'positioningSFixture', 'setOffsetA', 'setOffsetB' , 'addNodeToConnectedTexture'
state.jointParams = nil
state.jointLengthParams = {}
state.showPaletteFunc = nil

state.world = {
    debugDrawMode = true,
    debugAlpha = 1,
    profiling = false,
    meter = 500,
    isRecordingPointers = false,
    paused = true,
    gravity = 9.80,
    mouseForce = 500000,
    mouseDamping = 0.5,
    speedMultiplier = 1.0,
    softbodies = {},
    playWithSoftbodies = false

}

state.physicsWorld = nil



return state

```

src//ui-all.lua
```lua
-- ui-all.lua
local ui = {}

require('src.ui-textinput')(ui)

local creamy = { 245 / 255, 245 / 255, 220 / 255 } --#F5F5DC Creamy White:
local orange = { 242 / 255, 133 / 255, 0 }
-- Theme Configuration
local theme  = {
    lineHeight = 25,
    button = {
        default = { 188 / 255, 175 / 255, 156 / 255 },   -- Default fill color
        hover = { 105 / 255, 98 / 255, 109 / 255 },      -- Hover fill color
        pressed = { 217 / 255, 189 / 255, 197 / 255 },   -- Pressed fill color
        outline = creamy,                                -- Outline color
        text_default = creamy,                           -- Default text color
        text_hover = { 244 / 255, 189 / 255, 94 / 255 }, -- Text color on hover
        radius = 2,
        height = 25
    },
    checkbox = {
        checked = { 1, 1, 1 },
        label = { 1, 1, 1 }, -- Label text color
    },
    toggleButton = {
        onFill = { 0.1, 0.6, 0.1 },  -- Green fill when toggled on
        offFill = { 0.6, 0.1, 0.1 }, -- Red fill when toggled off
        onText = creamy,             -- Text color when toggled on
        offText = creamy,            -- Text color when toggled off
        outline = creamy,            -- Outline color
    },
    slider = {
        track = { 0.5, 0.5, 0.5 }, -- Slider track color
        thumb = { 0.2, 0.6, 1 },   -- Slider thumb color
        outline = creamy,
        track_radius = 2,
        height = 25
    },
    draggedElement = {
        fill = { 1, 1, 1 }, -- Color of the dragged element
    },
    general = {
        text = creamy, -- General text color
    },
    panel = {
        background = { 50 / 255, 50 / 255, 50 / 255 }, -- Panel background color
        outline = creamy,                              -- Panel outline color
        label = creamy,                                -- Panel label text color
    },
    textinput = {
        background = { 0.1, 0.1, 0.1 },                          -- Background color of the TextInput
        outline = creamy,                                        -- Default outline color
        text = creamy,                                           -- Text color
        placeholder = { 0.5, 0.5, 0.5 },                         -- Placeholder text color
        cursor = { 1, 1, 1 },                                    -- Cursor color
        focusedBorderColor = { 244 / 255, 189 / 255, 94 / 255 }, -- Border color when focused
        selectionBackground = { 0.2, 0.4, 0.8, 0.5 },            -- Selection highlight color
    },
    header = {
        active = orange
    },
    lineWidth = 3, -- General line width
}

ui.theme     = theme

--- Initializes the UI module.
function ui.init(font, fontHeight)
    ui.nextID = 1               -- Unique ID counter
    ui.dragOffset = { x = 0, y = 0 }
    ui.focusedTextInputID = nil -- Tracks the currently focused TextInput
    ui.textInputs = {}
    ui.fontHeight = fontHeight
    ui.font = font or love.graphics.getFont()
    ui.mouseWheelDy = 0
    ui.mouseWheelDx = 0
    ui.overPanel = false
end

--- Resets UI state at the start of each frame.
function ui.startFrame()
    ui.nextID = 1           -- Reset unique ID counter at the start of each frame

    ui.mousePressed = false -- Reset click state
    ui.mouseReleased = false

    local down = love.mouse.isDown(1)
    if not ui.mouseIsDown and down then
        ui.mousePressed = true
    end
    if ui.mouseIsDown and not down then
        ui.mouseReleased = true
    end
    ui.mouseIsDown = down

    ui.mouseX, ui.mouseY = love.mouse.getPosition()
    --  print('setting to false')
    ui.overPanel = false
end

function ui.generateID()
    local id = ui.nextID
    ui.nextID = ui.nextID + 1
    return id
end

--- Creates a layout context for arranging UI elements.
function ui.createLayout(params)
    local layout = {
        type = params.type or 'rows',
        margin = params.margin or 0,
        spacing = params.spacing or 0,
        curX = params.startX or 0,
        curY = params.startY or 0,
    }
    return layout
end

--- Calculates the next position in the layout and updates the layout context.
function ui.nextLayoutPosition(layout, elementWidth, elementHeight)
    local x = layout.curX
    local y = layout.curY

    -- Update positions for the next element
    if layout.type == 'rows' then
        layout.curX = layout.curX + elementWidth + layout.spacing
    elseif layout.type == 'columns' then
        layout.curY = layout.curY + elementHeight + layout.spacing
    end

    return x, y
end

ui._scrollers = {}


function ui.scrollableList(id, x, y, w, h, drawFunc)
    local scrollY = ui._scrollers[id] or { value = 0 }
    ui.panel(x, y, w + 20, h, '', function()
        local contentHeight = ui.scrollArea(id, x, y, w, h, scrollY, drawFunc) --  drawFunc(x, y, w, h, -scrollY.value)
        --  print(contentHeight)
        --print(id)
        if contentHeight > h then
            local result = ui.slider(x + w, y, h, 20, 'vertical', (contentHeight) - h, 0, scrollY
                .value,
                id)
            if result then
                scrollY.value = result
            end
            ui._scrollers[id] = scrollY
        end
    end)
end

function ui.scrollArea(_id, x, y, w, h, scrollY, drawFunc)
    local isHover = ui.mouseX >= x and ui.mouseX <= x + w and
        ui.mouseY >= y and ui.mouseY <= y + h

    love.graphics.setScissor(x, y, w, h)

    local maxContentY = drawFunc(x, y, w, h, -scrollY.value) or 0

    if isHover and maxContentY > h and ui.mouseWheelDy ~= 0 then
        local contentHeight = maxContentY
        scrollY.value = math.max(0, scrollY.value - ui.mouseWheelDy * 20)
        scrollY.value = math.min(scrollY.value, contentHeight - h)
        ui.mouseWheelDy = 0
    end
    scrollY.value = math.max(0, math.min(scrollY.value, maxContentY - h))
    love.graphics.setScissor()
    return maxContentY
    -- -- love.graphics.pop()
end

--- Creates a horizontal slider with a numeric input field.
function ui.sliderWithInput(_id, x, y, w, min, max, value, changed)
    local yOffset = (40 - theme.slider.height) / 2
    local panelSlider = ui.slider(x, y + yOffset, w, ui.theme.slider.height, 'horizontal', min, max, value, _id)
    local valueHasChangedViaSlider = false
    local returnValue = nil

    if panelSlider then
        value = string.format("%.2f", panelSlider)
        valueHasChangedViaSlider = true
        returnValue = value
    end

    local valueChangeFromOutside = valueHasChangedViaSlider or changed

    -- TextInput for numeric input
    local numericInputText, dirty = ui.textinput(_id, x + w + 10, y + yOffset, 80, ui.theme.slider.height,
        "Enter number...",
        "" .. value,
        true, valueChangeFromOutside)


    if dirty then
        value = tonumber(numericInputText)
        returnValue = value
    end

    if returnValue then
        return returnValue
    end
end

--- Draws a panel with optional label and content.
function ui.panel(x, y, width, height, label, drawFunc, optionalFillColor)
    -- Draw panel background
    --
    local isHover = ui.mouseX >= x and ui.mouseX <= x + width and
        ui.mouseY >= y and ui.mouseY <= y + height
    if isHover then
        ui.overPanel = true
    end
    local rxry = 0
    if theme.button.radius > 0 then
        rxry = math.min(width / 6, height / 6) / theme.button.radius
    end
    love.graphics.setColor(optionalFillColor or theme.panel.background)
    love.graphics.rectangle("fill", x, y, width, height, rxry, rxry)

    -- Draw panel outline
    love.graphics.setColor(theme.panel.outline)
    love.graphics.setLineWidth(theme.lineWidth)
    love.graphics.rectangle("line", x, y, width, height, rxry, rxry)

    -- Draw panel label if provided
    if label then
        love.graphics.setColor(theme.panel.label)
        local labelHeight = ui.font:getHeight()
        love.graphics.printf(label, x, y + 5, width, "center")
    end

    -- Enable scissor to clip UI elements within the panel
    if width > 0 and height > 0 then
        --  love.graphics.setScissor(x, y, width, height)
    end
    -- Call the provided draw function to render UI elements inside the panel
    if drawFunc then
        drawFunc()
    end

    -- Disable scissor
    -- love.graphics.setScissor()

    -- Reset color to white
    love.graphics.setColor(1, 1, 1)
end

--- Creates a checkbox with a label.
function ui.checkbox(x, y, checked, label)
    local size = theme.slider.height
    -- Determine the label to display inside the checkbox
    local checkmark = checked and "x" or ""

    -- Render the checkbox square using the existing button function
    local clicked, pressed, released = ui.button(x, y, size, '', size)

    -- Toggle the checked state if the checkbox was clicked
    if clicked then
        checked = not checked
    end
    local radius = size / 4
    if checked then
        love.graphics.setColor(theme.checkbox.checked) -- Use checkbox's checked color
        love.graphics.circle('fill', x + size / 2, y + size / 2, radius)
    end
    -- Draw the label text next to the checkbox
    love.graphics.setColor(theme.checkbox.label)       -- Label text color
    local textY = y + (size - ui.font:getHeight()) / 2 -- Vertically center the text
    love.graphics.print(label, x + size + 10, textY)

    -- Reset color to white
    love.graphics.setColor(1, 1, 1)

    -- Return the updated checked state
    return clicked, checked
end

--- Creates a toggle button that maintains an on/off state.
--- however i like the checkbox better though.......
function ui.toggleButton(x, y, width, height, labelOn, labelOff, isToggled)
    local id = ui.generateID()
    local isHover = ui.mouseX >= x and ui.mouseX <= x + width and
        ui.mouseY >= y and ui.mouseY <= y + height
    local pressed = isHover and ui.mousePressed

    if pressed then
        ui.activeElementID = id
    end

    -- Toggle state handling
    local used = false
    if ui.activeElementID == id and ui.mouseReleased and isHover then
        isToggled = not isToggled
        ui.activeElementID = nil
        used = true
    end

    -- Determine the label and colors based on the toggle state
    local label = isToggled and labelOn or labelOff
    local fillColor = isToggled and ui.theme.toggleButton.onFill or ui.theme.toggleButton.offFill
    local textColor = isToggled and ui.theme.toggleButton.onText or ui.theme.toggleButton.offText

    local rxry = 0
    if theme.button.radius > 0 then
        rxry = math.min(width, height) / theme.button.radius
    end
    -- Draw the button background
    love.graphics.setColor(fillColor)
    love.graphics.rectangle("fill", x, y, width, height, rxry, rxry)

    -- Draw button outline
    love.graphics.setColor(ui.theme.toggleButton.outline)
    love.graphics.setLineWidth(ui.theme.lineWidth)
    love.graphics.rectangle("line", x, y, width, height, rxry, rxry)

    -- Draw the label
    love.graphics.setColor(textColor)
    local textHeight = ui.font:getHeight()
    love.graphics.printf(label, x, y + (height - textHeight) / 2, width, "center")

    -- Reset color
    love.graphics.setColor(1, 1, 1)

    return used, isToggled
end

--- Creates a button.
function ui.header_button(x, y, width, label, opened)
    -- header button doenst have a button radius (its rectangular, and the lanbel is not centered..)
    local height = theme.button.height

    local id = ui.generateID() -- Generate unique ID
    local isHover = ui.mouseX >= x and ui.mouseX <= x + width and
        ui.mouseY >= y and ui.mouseY <= y + height
    local pressed = isHover and ui.mousePressed

    if pressed then
        ui.activeElementID = id
    end
    -- Draw the button with state-based colors
    if ui.activeElementID == id then
        love.graphics.setColor(theme.button.pressed) -- Pressed state
    elseif isHover then
        love.graphics.setColor(theme.button.hover)   -- Hover state
    else
        love.graphics.setColor(theme.button.default) -- Default state
    end
    local rxry = 0
    if opened then
        love.graphics.setColor(theme.header.active)
    end
    love.graphics.rectangle("fill", x, y, width, height, rxry, rxry)

    -- Draw button outline
    love.graphics.setColor(theme.button.outline) -- Outline color
    love.graphics.setLineWidth(theme.lineWidth)
    love.graphics.rectangle("line", x, y, width, height, rxry, rxry)

    -- Draw button label with state-based color
    if isHover then
        love.graphics.setColor(theme.button.text_hover)   -- Text color on hover
    else
        love.graphics.setColor(theme.button.text_default) -- Default text color
    end
    local textHeight = ui.font:getHeight()
    love.graphics.print(label, x, y + (height - textHeight) / 2)
    -- love.graphics.printf(label, x, y + (height - textHeight) / 2, width, "center")

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)

    local clicked = false
    local released = ui.mouseReleased and ui.activeElementID == id

    if ui.activeElementID == id and released and isHover then
        clicked = true
    end
    if released then
        -- Reset the active element ID
        ui.activeElementID = nil
    end
    return clicked, pressed, released
end

function ui.coloredRect(x, y, color, size)
    local id = ui.generateID()
    local isHover = ui.mouseX >= x and ui.mouseX <= x + size and
        ui.mouseY >= y and ui.mouseY <= y + size
    local pressed = isHover and ui.mousePressed
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x, y, size, size)
    if pressed then
        ui.activeElementID = id
    end

    local clicked = false
    local released = ui.mouseReleased and ui.activeElementID == id

    if ui.activeElementID == id and released and isHover then
        clicked = true
    end
    if released then
        -- Reset the active element ID
        ui.activeElementID = nil
    end




    return clicked, pressed, released, isHover
end

--- Creates a button.
function ui.button(x, y, width, label, optionalHeight, optionalFillColor)
    local height = optionalHeight and optionalHeight or theme.button.height

    local id = ui.generateID() -- Generate unique ID
    local isHover = ui.mouseX >= x and ui.mouseX <= x + width and
        ui.mouseY >= y and ui.mouseY <= y + height
    local pressed = isHover and ui.mousePressed

    if pressed then
        ui.activeElementID = id
        --print("Button pressed" .. id)
    end
    -- Draw the button with state-based colors
    if ui.activeElementID == id then
        love.graphics.setColor(theme.button.pressed) -- Pressed state
    elseif isHover then
        love.graphics.setColor(theme.button.hover)   -- Hover state
    else
        if (optionalFillColor) then
            love.graphics.setColor(optionalFillColor)
        else
            love.graphics.setColor(theme.button.default) -- Default state
        end
    end
    local rxry = 0
    if theme.button.radius > 0 then
        rxry = math.min(width, height) / theme.button.radius
    end

    love.graphics.rectangle("fill", x, y, width, height, rxry, rxry)

    -- Draw button outline
    love.graphics.setColor(theme.button.outline) -- Outline color
    love.graphics.setLineWidth(theme.lineWidth)
    love.graphics.rectangle("line", x, y, width, height, rxry, rxry)

    -- Draw button label with state-based color
    if isHover then
        love.graphics.setColor(theme.button.text_hover)   -- Text color on hover
    else
        love.graphics.setColor(theme.button.text_default) -- Default text color
    end
    local textHeight = ui.font:getHeight()
    love.graphics.printf(label, x, y + (height - textHeight) / 2, width, "center")

    -- Reset color
    love.graphics.setColor(1, 1, 1)

    local clicked = false
    local released = ui.mouseReleased and ui.activeElementID == id

    if ui.activeElementID == id and released and isHover then
        clicked = true
    end
    if released then
        -- Reset the active element ID
        ui.activeElementID = nil
    end
    return clicked, pressed, released, isHover
end

--- Creates a slider (horizontal or vertical).
function ui.slider(x, y, length, thickness, orientation, min, max, value, extraId)
    local inValue = value

    local sliderID
    if (extraId) then
        sliderID = extraId
    else
        sliderID = ui.generateID()
    end
    local isHorizontal = orientation == 'horizontal'

    -- Calculate proportion and initial thumb position
    local proportion = (value - min) / (max - min)
    local thumbX, thumbY
    if isHorizontal then
        thumbX = x + proportion * (length - thickness)
        thumbY = y
    else
        thumbX = x
        thumbY = y + (1 - proportion) * (length - thickness)
    end

    -- Render the track
    love.graphics.setColor(theme.slider.track) -- Slider track color

    local rxry = 0
    if theme.slider.track_radius > 0 then
        rxry = math.min(length, thickness) / theme.slider.track_radius
    end
    if isHorizontal then
        love.graphics.rectangle("fill", x, y, length, thickness, rxry, rxry)
    else
        love.graphics.rectangle("fill", x, y, thickness, length, rxry, rxry)
    end

    -- Draw track outline
    love.graphics.setColor(theme.slider.outline) -- Slider track outline color
    love.graphics.setLineWidth(theme.lineWidth)
    if isHorizontal then
        love.graphics.rectangle("line", x, y, length, thickness, rxry, rxry)
    else
        love.graphics.rectangle("line", x, y, thickness, length, rxry, rxry)
    end


    -- Set scissor to restrict rendering to the track area
    love.graphics.setScissor(x, y, isHorizontal and length or thickness, isHorizontal and thickness or length)

    -- Render the thumb using the existing button function
    local thumbLabel = ''
    local clicked, pressed, released = ui.button(thumbX, thumbY, thickness, thumbLabel, thickness)

    -- Remove scissor after rendering the thumb
    love.graphics.setScissor()



    -- -- Render the thumb using the existing button function
    -- local thumbLabel = ''
    -- local clicked, pressed, released = ui.button(thumbX, thumbY, thickness, thumbLabel, thickness)

    -- Handle dragging
    --  logger:info(ui.draggingSliderID)
    if pressed then
        ui.draggingSliderID = sliderID
        -- Calculate and store the offset
        if isHorizontal then
            ui.dragOffset.x = ui.mouseX - thumbX
            ui.dragOffset.y = 0 -- Not needed for horizontal
        else
            ui.dragOffset.x = 0 -- Not needed for vertical
            ui.dragOffset.y = ui.mouseY - thumbY
        end
    end

    if ui.draggingSliderID == sliderID then
        local mouseX, mouseY = ui.mouseX, ui.mouseY
        if isHorizontal then
            -- Clamp thumbX within the track boundaries
            thumbX = math.max(x, math.min(mouseX - ui.dragOffset.x, x + length - thickness))
            proportion = (thumbX - x) / (length - thickness)
        else
            -- Clamp thumbY within the track boundaries
            thumbY = math.max(y, math.min(mouseY - ui.dragOffset.y, y + length - thickness))
            proportion = 1 - ((thumbY - y) / (length - thickness))
        end

        value = min + proportion * (max - min)
    end

    if released and ui.draggingSliderID == sliderID then
        ui.draggingSliderID = nil
        -- Reset the drag offset
        ui.dragOffset.x = 0
        ui.dragOffset.y = 0
    end
    -- Reset color
    love.graphics.setColor(1, 1, 1)

    -- Return the updated value if it has changed
    if inValue ~= value then
        return value
    else
        return false
    end
end

--- Handles text input for the UI, particularly for text inputs.
function ui.handleTextInput(t)
    local textinputstate = ui.focusedTextInputID and ui.textInputs[ui.focusedTextInputID]
    if textinputstate then
        ui.handleTextInputForTextInput(t, textinputstate)
    end
end

--- Handles key presses for the UI, particularly for text inputs.
function ui.handleKeyPress(key)
    local textinputstate = ui.focusedTextInputID and ui.textInputs[ui.focusedTextInputID]

    if textinputstate then
        ui.handleKeyPressForTextInput(key, textinputstate)
    end
end

--- Draws a text label at the specified position.
function ui.centeredLabel(x, y, width, text)
    love.graphics.setColor(ui.theme.general.text)

    love.graphics.printf(text, x, y, width, "center")
    love.graphics.setColor(1, 1, 1)
end

function ui.label(x, y, text, color)
    love.graphics.setColor(color or ui.theme.general.text)
    local yOffset = 0 --ui.font:getHeight(text) / 2
    love.graphics.print(text, x, y + yOffset)
    love.graphics.setColor(1, 1, 1)
end

--- Creates a dropdown menu.
function ui.dropdown(x, y, width, options, currentSelection)
    local id = ui.generateID()
    local isOpen = ui.dropdownStates and ui.dropdownStates[id] or false
    -- Draw the dropdown box
    local clicked, pressed, released = ui.button(x, y, width, currentSelection)

    -- Toggle dropdown state
    if clicked then
        isOpen = not isOpen
    end
    ui.dropdownStates = ui.dropdownStates or {}
    ui.dropdownStates[id] = isOpen

    -- Draw options if open
    if isOpen then
        for i, option in ipairs(options) do
            local optionY = y + i * (theme.button.height + 10)
            local optionClicked = ui.button(x + width, optionY, width, option)
            if optionClicked then
                currentSelection = option
                ui.dropdownStates[id] = false -- Close dropdown
                return currentSelection
            end
        end
    end
    return false, pressed, released
end

return ui

```

src//ui-textinput.lua
```lua
--ui-text-input.lua
return function(ui)
    --- Helper function to calculate cursor position within a line based on mouse X coordinate.
    function ui.calculateCursorPositionInLine(text, relativeX)
        local newCursorPosition = 0
        for i = 1, #text do
            local subText = text:sub(1, i)
            local textWidth = ui.font:getWidth(subText)
            if textWidth > relativeX then
                newCursorPosition = i - 1
                break
            end
        end
        if relativeX > ui.font:getWidth(text) then
            newCursorPosition = #text
        end
        return newCursorPosition
    end

    --- Function to reconstruct the text from lines.
    function ui.reconstructText(lines)
        return table.concat(lines, "\n")
    end

    --- Function to split text into lines.
    function ui.splitTextIntoLines(text)
        local lines = {}
        for line in (text .. "\n"):gmatch("(.-)\n") do
            table.insert(lines, line)
        end
        return lines
    end

    --- Function to check if the selection is empty.
    function ui.isSelectionEmpty(state)
        return state.selectionStart.line == state.selectionEnd.line and
            state.selectionStart.char == state.selectionEnd.char
    end

    --- Function to get the selected text.
    function ui.getSelectedText(state)
        local selStartLine = state.selectionStart.line
        local selStartChar = state.selectionStart.char
        local selEndLine = state.selectionEnd.line
        local selEndChar = state.selectionEnd.char

        -- Normalize selection indices
        if selStartLine > selEndLine or (selStartLine == selEndLine and selStartChar > selEndChar) then
            selStartLine, selEndLine = selEndLine, selStartLine
            selStartChar, selEndChar = selEndChar, selStartChar
        end

        local selectedText = {}
        for i = selStartLine, selEndLine do
            local lineText = state.lines[i]
            local startChar = (i == selStartLine) and selStartChar + 1 or 1
            local endChar = (i == selEndLine) and selEndChar or #lineText
            table.insert(selectedText, lineText:sub(startChar, endChar))
        end
        return table.concat(selectedText, "\n")
    end

    --- Function to delete the selected text.
    function ui.deleteSelection(state)
        local selStartLine = state.selectionStart.line
        local selStartChar = state.selectionStart.char
        local selEndLine = state.selectionEnd.line
        local selEndChar = state.selectionEnd.char

        -- Normalize selection indices
        if selStartLine > selEndLine or (selStartLine == selEndLine and selStartChar > selEndChar) then
            selStartLine, selEndLine = selEndLine, selStartLine
            selStartChar, selEndChar = selEndChar, selStartChar
        end

        if selStartLine == selEndLine then
            -- Selection within a single line
            local line = state.lines[selStartLine]
            state.lines[selStartLine] = line:sub(1, selStartChar) .. line:sub(selEndChar + 1)
        else
            -- Selection spans multiple lines
            local startLineText = state.lines[selStartLine]:sub(1, selStartChar)
            local endLineText = state.lines[selEndLine]:sub(selEndChar + 1)
            -- Remove middle lines
            for i = selStartLine + 1, selEndLine do
                table.remove(state.lines, selStartLine + 1)
            end
            -- Merge start and end lines
            state.lines[selStartLine] = startLineText .. endLineText
        end
        -- Update cursor position
        state.cursorPosition = { line = selStartLine, char = selStartChar }
        -- Clear selection
        state.selectionStart = { line = selStartLine, char = selStartChar }
        state.selectionEnd = { line = selStartLine, char = selStartChar }
        -- Reconstruct text
        state.text = ui.reconstructText(state.lines)
    end

    --- Helper function to calculate cursor position based on mouse X coordinate.
    function ui.calculateCursorPosition(text, relativeX)
        local newCursorPosition = 0
        for i = 1, #text do
            local subText = text:sub(1, i)
            local textWidth = ui.font:getWidth(subText)
            if textWidth > relativeX then
                newCursorPosition = i - 1
                break
            end
        end
        if relativeX > ui.font:getWidth(text) then
            newCursorPosition = #text
        end
        return newCursorPosition
    end

    function ui.handleTextInputForTextInput(t, state)
        -- local state = ui.textInputs[ui.focusedTextInputID]

        if state.isNumeric and not tonumber(t) and t ~= "." and t ~= "-" then
            -- Ignore non-numeric input
            return
        end

        if not ui.isSelectionEmpty(state) then
            ui.deleteSelection(state)
        end

        local pos = state.cursorPosition
        local line = state.lines[pos.line]
        if t == "\n" or t == "\r" then
            -- Handle new line
            local beforeCursor = line:sub(1, pos.char)
            local afterCursor = line:sub(pos.char + 1)
            state.lines[pos.line] = beforeCursor
            table.insert(state.lines, pos.line + 1, afterCursor)
            pos.line = pos.line + 1
            pos.char = 0
        else
            -- Regular character input
            state.lines[pos.line] = line:sub(1, pos.char) .. t .. line:sub(pos.char + 1)
            pos.char = pos.char + #t
        end
        -- Update selection
        state.selectionStart = { line = pos.line, char = pos.char }
        state.selectionEnd = { line = pos.line, char = pos.char }
        -- Reconstruct text
        state.text = ui.reconstructText(state.lines)
    end

    function ui.handleKeyPressForTextInput(key, state)
        -- local state = ui.textInputs[ui.focusedTextInputID]
        local isCtrlDown = love.keyboard.isDown('lctrl', 'rctrl')
        local isShiftDown = love.keyboard.isDown('lshift', 'rshift')
        local isCMDDown = love.keyboard.isDown('lgui', 'rgui')
        if isCtrlDown or isCMDDown then
            if key == 'c' then
                -- Copy
                if not ui.isSelectionEmpty(state) then
                    local selectedText = ui.getSelectedText(state)
                    love.system.setClipboardText(selectedText)
                end
            elseif key == 'v' then
                -- Paste
                local clipboardText = love.system.getClipboardText() or ""
                if clipboardText ~= "" then
                    -- Delete selected text if any
                    if not ui.isSelectionEmpty(state) then
                        ui.deleteSelection(state)
                    end
                    -- Insert clipboard text
                    local pos = state.cursorPosition
                    local linesToInsert = ui.splitTextIntoLines(clipboardText)
                    if #linesToInsert == 1 then
                        -- Insert into current line
                        local line = state.lines[pos.line]
                        state.lines[pos.line] = line:sub(1, pos.char) .. linesToInsert[1] .. line:sub(pos.char + 1)
                        pos.char = pos.char + #linesToInsert[1]
                    else
                        -- Insert multiple lines
                        local line = state.lines[pos.line]
                        local beforeCursor = line:sub(1, pos.char)
                        local afterCursor = line:sub(pos.char + 1)
                        state.lines[pos.line] = beforeCursor .. linesToInsert[1]
                        for i = 2, #linesToInsert - 1 do
                            table.insert(state.lines, pos.line + i - 1, linesToInsert[i])
                        end
                        table.insert(state.lines, pos.line + #linesToInsert - 1,
                            linesToInsert[#linesToInsert] .. afterCursor)
                        pos.line = pos.line + #linesToInsert - 1
                        pos.char = #linesToInsert[#linesToInsert]
                    end
                    -- Clear selection
                    state.selectionStart = { line = pos.line, char = pos.char }
                    state.selectionEnd = { line = pos.line, char = pos.char }
                    -- Reconstruct text
                    state.text = ui.reconstructText(state.lines)
                end
            elseif key == 'x' then
                -- Cut
                if not ui.isSelectionEmpty(state) then
                    local selectedText = ui.getSelectedText(state)
                    love.system.setClipboardText(selectedText)
                    ui.deleteSelection(state)
                end
            end
        else
            -- Handle other keys
            local pos = state.cursorPosition
            if key == "backspace" then
                if not ui.isSelectionEmpty(state) then
                    ui.deleteSelection(state)
                elseif pos.char > 0 then
                    -- Delete character before cursor
                    local line = state.lines[pos.line]
                    state.lines[pos.line] = line:sub(1, pos.char - 1) .. line:sub(pos.char + 1)
                    pos.char = pos.char - 1
                elseif pos.line > 1 then
                    -- Merge with previous line
                    local prevLine = state.lines[pos.line - 1]
                    pos.char = #prevLine
                    state.lines[pos.line - 1] = prevLine .. state.lines[pos.line]
                    table.remove(state.lines, pos.line)
                    pos.line = pos.line - 1
                end
                -- Update selection
                state.selectionStart = { line = pos.line, char = pos.char }
                state.selectionEnd = { line = pos.line, char = pos.char }
                state.text = ui.reconstructText(state.lines)
            elseif key == "delete" then
                if not ui.isSelectionEmpty(state) then
                    ui.deleteSelection(state)
                elseif pos.char < #state.lines[pos.line] then
                    -- Delete character after cursor
                    local line = state.lines[pos.line]
                    state.lines[pos.line] = line:sub(1, pos.char) .. line:sub(pos.char + 2)
                elseif pos.line < #state.lines then
                    -- Merge with next line
                    state.lines[pos.line] = state.lines[pos.line] .. state.lines[pos.line + 1]
                    table.remove(state.lines, pos.line + 1)
                end
                -- Update selection
                state.selectionStart = { line = pos.line, char = pos.char }
                state.selectionEnd = { line = pos.line, char = pos.char }
                state.text = ui.reconstructText(state.lines)
            elseif key == "left" then
                if pos.char > 0 then
                    pos.char = pos.char - 1
                elseif pos.line > 1 then
                    pos.line = pos.line - 1
                    pos.char = #state.lines[pos.line]
                end
                if isShiftDown then
                    state.selectionEnd = { line = pos.line, char = pos.char }
                else
                    state.selectionStart = { line = pos.line, char = pos.char }
                    state.selectionEnd = { line = pos.line, char = pos.char }
                end
            elseif key == "right" then
                if pos.char < #state.lines[pos.line] then
                    pos.char = pos.char + 1
                elseif pos.line < #state.lines then
                    pos.line = pos.line + 1
                    pos.char = 0
                end
                if isShiftDown then
                    state.selectionEnd = { line = pos.line, char = pos.char }
                else
                    state.selectionStart = { line = pos.line, char = pos.char }
                    state.selectionEnd = { line = pos.line, char = pos.char }
                end
            elseif key == "up" then
                if pos.line > 1 then
                    pos.line = pos.line - 1
                    pos.char = math.min(pos.char, #state.lines[pos.line])
                end
                if isShiftDown then
                    state.selectionEnd = { line = pos.line, char = pos.char }
                else
                    state.selectionStart = { line = pos.line, char = pos.char }
                    state.selectionEnd = { line = pos.line, char = pos.char }
                end
            elseif key == "down" then
                if pos.line < #state.lines then
                    pos.line = pos.line + 1
                    pos.char = math.min(pos.char, #state.lines[pos.line])
                end
                if isShiftDown then
                    state.selectionEnd = { line = pos.line, char = pos.char }
                else
                    state.selectionStart = { line = pos.line, char = pos.char }
                    state.selectionEnd = { line = pos.line, char = pos.char }
                end
            elseif key == "home" then
                pos.char = 0
                if isShiftDown then
                    state.selectionEnd = { line = pos.line, char = pos.char }
                else
                    state.selectionStart = { line = pos.line, char = pos.char }
                    state.selectionEnd = { line = pos.line, char = pos.char }
                end
            elseif key == "end" then
                pos.char = #state.lines[pos.line]
                if isShiftDown then
                    state.selectionEnd = { line = pos.line, char = pos.char }
                else
                    state.selectionStart = { line = pos.line, char = pos.char }
                    state.selectionEnd = { line = pos.line, char = pos.char }
                end
            elseif key == "return" or key == "kpenter" then
                -- Handle new line on enter key
                --ui.handleTextInput("\n")
                ui.handleTextInputForTextInput("\n", state)
            elseif key == "escape" then
                ui.focusedTextInputID = nil
            end
        end
    end

    function ui.textinput(_id, x, y, width, height, placeholder, currentText, isNumeric, reparse)
        local id = _id or ui.generateID()

        -- Initialize state for this TextInput if not already done
        if not ui.textInputs[id] then
            ui.textInputs[id] = {
                text = currentText or "",
                lines = {}, -- Stores text broken into lines
                cursorPosition = { line = 1, char = 0 },
                cursorTimer = 0,
                cursorVisible = true,
                isNumeric = isNumeric or false,
                selectionStart = { line = 1, char = 0 },
                selectionEnd = { line = 1, char = 0 },
                isSelecting = false,
            }
            -- Split initial text into lines
            ui.textInputs[id].lines = ui.splitTextIntoLines(ui.textInputs[id].text)
        end

        local state = ui.textInputs[id]

        if reparse then
            state.text = currentText
            state.lines = ui.splitTextIntoLines(state.text)
        end

        local isHover = ui.mouseX >= x and ui.mouseX <= x + width and
            ui.mouseY >= y and ui.mouseY <= y + height

        -- Handle focus and cursor positioning
        if ui.mousePressed then
            if isHover then
                ui.focusedTextInputID = id

                local relativeX = ui.mouseX - x - 5 -- Subtracting padding
                local relativeY = ui.mouseY - y
                local lineIndex = math.floor(relativeY / ui.font:getHeight()) + 1
                lineIndex = math.max(1, math.min(lineIndex, #state.lines))
                local lineText = state.lines[lineIndex]
                local charIndex = ui.calculateCursorPositionInLine(lineText, relativeX)
                state.cursorPosition = { line = lineIndex, char = charIndex }
                state.selectionStart = { line = lineIndex, char = charIndex }
                state.selectionEnd = { line = lineIndex, char = charIndex }
                state.isSelecting = true
            else
                if ui.focusedTextInputID == id then
                    ui.focusedTextInputID = nil
                end
            end
        end

        -- Handle text selection with mouse dragging
        if ui.focusedTextInputID == id and ui.mouseIsDown and state.isSelecting then
            local relativeX = ui.mouseX - x - 5
            local relativeY = ui.mouseY - y
            local lineIndex = math.floor(relativeY / ui.font:getHeight()) + 1
            lineIndex = math.max(1, math.min(lineIndex, #state.lines))
            local lineText = state.lines[lineIndex]
            local charIndex = ui.calculateCursorPositionInLine(lineText, relativeX)
            state.cursorPosition = { line = lineIndex, char = charIndex }
            state.selectionEnd = { line = lineIndex, char = charIndex }
        elseif ui.mouseReleased and state.isSelecting then
            state.isSelecting = false
        end

        -- Check if this TextInput is focused
        local isFocused = (ui.focusedTextInputID == id)

        -- Update cursor blinking
        if isFocused then
            state.cursorTimer = state.cursorTimer + 1.0 / 90 --love.timer.getDelta()
            if state.cursorTimer >= 0.5 then
                state.cursorVisible = not state.cursorVisible
                state.cursorTimer = 0
            end
        else
            state.cursorVisible = false
            state.cursorTimer = 0
        end

        -- Draw TextInput background
        love.graphics.setColor(ui.theme.textinput.background)
        love.graphics.rectangle("fill", x, y, width, height, ui.theme.button.radius, ui.theme.button.radius)

        -- Draw TextInput outline
        if isFocused then
            love.graphics.setColor(ui.theme.textinput.focusedBorderColor)
        else
            love.graphics.setColor(ui.theme.textinput.outline)
        end
        love.graphics.setLineWidth(ui.theme.lineWidth)
        love.graphics.rectangle("line", x, y, width, height, ui.theme.button.radius, ui.theme.button.radius)

        local lineHeight = ui.font:getHeight()

        -- Set up scissor to clip text inside the TextInput area
        love.graphics.setScissor(x, y, width, height)

        -- Draw selection background
        local selStartLine = state.selectionStart.line
        local selStartChar = state.selectionStart.char
        local selEndLine = state.selectionEnd.line
        local selEndChar = state.selectionEnd.char

        -- Normalize selection indices
        if selStartLine > selEndLine or (selStartLine == selEndLine and selStartChar > selEndChar) then
            selStartLine, selEndLine = selEndLine, selStartLine
            selStartChar, selEndChar = selEndChar, selStartChar
        end

        if not (selStartLine == selEndLine and selStartChar == selEndChar) then
            for i = selStartLine, selEndLine do
                local lineText = state.lines[i]
                local startChar = (i == selStartLine) and selStartChar or 0
                local endChar = (i == selEndLine) and selEndChar or #lineText
                local selectionWidth = ui.font:getWidth(lineText:sub(startChar + 1, endChar))
                local selectionX = x + 5 + ui.font:getWidth(lineText:sub(1, startChar))
                local selectionY = y + (i - 1) * lineHeight
                love.graphics.setColor(ui.theme.textinput.selectionBackground)
                love.graphics.rectangle('fill', selectionX, selectionY, selectionWidth, lineHeight)
            end
        end

        -- Draw text
        for i, line in ipairs(state.lines) do
            local textY = y + (i - 1) * lineHeight
            love.graphics.setColor(ui.theme.textinput.text)
            love.graphics.print(line, x + 5, textY)
        end

        -- Draw cursor if focused
        if isFocused and state.cursorVisible then
            local pos = state.cursorPosition
            local lineText = state.lines[pos.line]:sub(1, pos.char)
            local cursorX = x + 5 + ui.font:getWidth(lineText)
            local cursorY = y + (pos.line - 1) * lineHeight
            love.graphics.setColor(ui.theme.textinput.cursor)
            love.graphics.line(cursorX, cursorY, cursorX, cursorY + lineHeight)
        end

        -- Remove scissor
        love.graphics.setScissor()

        -- Reset color
        love.graphics.setColor(1, 1, 1)

        return state.text, state.text ~= currentText
    end
end
--return ui

```

src//utils.lua
```lua
--utils.lua

local lib = {}
-- Utility function to concatenate two tables.

-- Define the map function
function lib.map(tbl, func)
    local new_tbl = {}
    for i, v in ipairs(tbl) do
        new_tbl[i] = func(v)
    end
    return new_tbl
end

function lib.trace(...)
    local info = debug.getinfo(2, "Sl")
    local t = { info.short_src .. ":" .. info.currentline .. ":" }
    for i = 1, select("#", ...) do
        local x = select(i, ...)
        if type(x) == "number" then
            x = string.format("%g", lib.round_to_decimals(x, 2))
        end
        t[#t + 1] = tostring(x)
    end
    logger:info(table.concat(t, " "))
end

function lib.getPathDifference(base, full)
    -- Ensure both inputs are strings
    if type(base) ~= "string" or type(full) ~= "string" then
        error("Both base and full paths must be strings")
    end

    -- Handle root path explicitly
    if base == "/" then
        if full:sub(1, 1) == "/" then
            return full:sub(2) -- Return path without leading slash
        else
            return full        -- Should not happen if full is absolute, but handle anyway
        end
    end

    -- If the paths are identical, return an empty string
    if full == base then
        return ""
    end

    -- Check if the base path is a prefix of the full path
    if full:sub(1, #base) == base then
        -- Ensure that the base path ends at a directory boundary
        local nextChar = full:sub(#base + 1, #base + 1)
        if nextChar == "/" then
            -- Extract the remaining part of the path
            return full:sub(#base + 1)
            -- Check if the base is the entire path except for the final segment without a leading slash
            -- This case seems less common for absolute paths but might occur.
        elseif nextChar == "" then
            return "" -- Or maybe nil depending on desired behavior? Empty seems reasonable.
        end
    end

    -- If base is not a proper prefix, return nil or handle accordingly
    return nil
end

function lib.sanitizeString(input)
    if not input then return "" end   -- Handle nil or empty strings
    return input:gsub("[%c%s]+$", "") -- Remove control characters and trailing spaces
end

function lib.round_to_decimals(num, dec)
    local multiplier = 10 ^ dec -- 10^4 for 4 decimal places
    return math.floor(num * multiplier + 0.5) / multiplier
end

function lib.tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

function lib.printTableKeys(tbl)
    for key, _ in pairs(tbl) do
        logger:info(key)
    end
end

function lib.tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

function lib.tableConcat(t1, t2)
    for i = 1, #t2 do
        table.insert(t1, t2[i])
    end
    return t1
end

function lib.shallowCopy(original)
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = value
    end
    return copy
end

function lib.deepCopy(orig, copies)
    -- 'copies' table tracks already-copied tables to handle cyclic references.
    copies = copies or {}

    -- If the value is not a table, return it directly (base case).
    if type(orig) ~= "table" then
        return orig
    end

    -- If we've already copied this table, return the copy to avoid recursion loops.
    if copies[orig] then
        return copies[orig]
    end

    -- Create a new table for the copy and record it in 'copies'.
    local copy = {}
    copies[orig] = copy

    -- Recursively copy all keys and values from the original.
    for key, value in pairs(orig) do
        local copiedKey = lib.deepCopy(key, copies)
        local copiedValue = lib.deepCopy(value, copies)
        copy[copiedKey] = copiedValue
    end

    -- Preserve the metatable, if any.
    setmetatable(copy, getmetatable(orig))

    return copy
end

function lib.findByField(array, field, target)
    for _, element in ipairs(array) do
        local value = element[field]
        if type(value) == "string" and value == target then
            return element
        elseif type(value) == "table" then
            for _, v in ipairs(value) do
                if v == target then
                    return element
                end
            end
        end
    end
    return nil -- not found
end

function lib.tablesEqualNumbers(t1, t2, tolerance)
    tolerance = tolerance or 1e-9 -- Default tolerance for floating point

    -- Check if both tables have the same number of elements
    if #t1 ~= #t2 then
        return false
    end

    -- Compare each corresponding element
    for i = 1, #t1 do
        local v1 = t1[i]
        local v2 = t2[i]
        -- Use tolerance check for numbers
        if type(v1) == 'number' and type(v2) == 'number' then
            if math.abs(v1 - v2) > tolerance then
                return false
            end
        elseif v1 ~= v2 then -- Use standard comparison for non-numbers
            return false
        end
    end

    return true
end

return lib

```

src//uuid.lua
```lua
--uuid.lua
local random = love.math.random
local lib = {}
function lib.uuid128()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return (string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end))
end

-- Base62 character set
local base62_chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
-- Function to encode a number into Base62
function lib.base62_encode(num)
    local result = ""
    local base = 62
    repeat
        local remainder = num % base
        result = string.sub(base62_chars, remainder + 1, remainder + 1) .. result
        num = math.floor(num / base)
    until num == 0
    return result
end

-- Example: Encode a random 64-bit number
function lib.uuid64_base62()
    -- Generate a random 64-bit integer
    local num = love.math.random(0, 0xffffffff) * 0x100000000 + love.math.random(0, 0xffffffff)
    return lib.base62_encode(num)
end

function lib.uuid32_base62()
    local num = love.math.random(0, 0xffffffff) -- Generate a 32-bit random integer
    return lib.base62_encode(num)
end

function lib.uuid()
    return lib.uuid32_base62()
    --return lib.uuid128()
end

function lib.generateID()
    return lib.uuid()
end

return lib

```


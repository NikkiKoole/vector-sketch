-- NOTE MAKE REVOLUTE JOINTS ALWAYS FROM PARENT TO CHILD!!!!!!!!

-- TODO there is an issue where the .vertices arent populated after load.
-- TODO src/object-manager.lua:666:	I should figure out if i want to do something weird with the offset, think connect to torso logic at edge nr...
-- TODO look for : destroybody doesnt destroy the joint on it ?
-- TODO dirty list for textures that need to be remade, (box2d-draw-textured)
-- TODO in character manager, the w and h arent used when we have a shape 8 i prbaly want to calculate sx and sy depending on w and h instead of not using them
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


--local moonshine = require 'moonshine'


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

    if state.world.darkMode then
        love.graphics.clear(.1, 0.2, .1)
    else
        local creamy = { 245 / 255, 245 / 255, 220 / 255 } --#F5F5DC Creamy White:
        love.graphics.clear(creamy)
    end
    if state.editorPreferences.showGrid then
        editorRenderer.drawGrid(state.world.darkMode and { 1, 1, 1, .1 } or { 0, 0, 1, .1 })
    end

    box2dDrawTextured.makeCombinedImages()
    --effect(function()
    cam:push()
    love.graphics.setColor(1, 1, 1, 1)
    box2dDraw.drawWorld(state.physicsWorld, state.world.debugDrawMode)

    if state.world.showTextures then
        box2dDrawTextured.drawTexturedWorld(state.physicsWorld)
    end
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
        if key == 'e' then
            local bgHex = '000000ff'
            local fgHex = randomHexColor()
            local pHex = randomHexColor()
            CharacterManager.updateSkinOfPart(humanoidInstance, 'lear',
                { bgHex = bgHex, fgHex = fgHex, pHex = pHex })
            CharacterManager.updateSkinOfPart(humanoidInstance, 'rear',
                { bgHex = bgHex, fgHex = fgHex, pHex = pHex })

            local urls = { 'earx1r', 'earx2r', 'earx3r', 'earx4r', 'earx5r', 'earx6r', 'earx7r', 'earx8r', 'earx9r',
                'earx10r', 'earx11r', 'earx12r', 'earx13r', 'earx14r', 'earx15r', 'earx16r' }
            --local urls = { 'earx1r', 'earx2r' }
            local urlIndex = math.ceil(math.random() * #urls)
            local url = urls[urlIndex]
            print(url)
            local creation = humanoidInstance.dna.creation
            local s = 1 + math.random() * 1
            local sy = love.math.random()
            CharacterManager.updatePart('lear',
                { shape8URL = url .. '.png', sy = s, sx = -s * sy },
                humanoidInstance)
            CharacterManager.updatePart('rear',
                { shape8URL = url .. '.png', sy = s, sx = s * sy },
                humanoidInstance)
            CharacterManager.addTexturesFromInstance2(humanoidInstance)
        end
        if key == 'f' then
            --,
            local urls = { 'hand3r', 'feet8r', 'feet2r', 'feet6r', 'feet5xr', 'feet3xr', 'feet7r',
                'feet7xr' }
            --local urls = { 'feet7xr', 'hand3r' }
            local urlIndex = math.ceil(math.random() * #urls)
            local url = urls[urlIndex]
            local creation = humanoidInstance.dna.creation
            local s = 1 + math.random() * 1

            CharacterManager.updatePart('lfoot',
                { shape8URL = url .. '.png', sy = s, sx = s },
                humanoidInstance)
            CharacterManager.updatePart('rfoot',
                { shape8URL = url .. '.png', sy = s, sx = -s },
                humanoidInstance)

            local s = 1 + math.random() * 1
            local urlIndex = math.ceil(math.random() * #urls)
            local url = urls[urlIndex]
            CharacterManager.updatePart('lhand',
                { shape8URL = url .. '.png', sy = s, sx = s },
                humanoidInstance)
            CharacterManager.updatePart('rhand',
                { shape8URL = url .. '.png', sy = s, sx = -s },
                humanoidInstance)

            CharacterManager.rebuildFromCreation(humanoidInstance, {})
            print(url)
            CharacterManager.addTexturesFromInstance2(humanoidInstance)
        end

        if key == 'b' then
            local bgHex = randomHexColor()
            local fgHex = randomHexColor()
            local pHex = randomHexColor()


            local urls = { 'borsthaar1', 'borsthaar2', 'borsthaar3', 'borsthaar4', 'borsthaar5', 'borsthaar6',
                'borsthaar7' }
            local urlIndex = math.ceil(math.random() * #urls)
            local url = urls[urlIndex]

            local creation = humanoidInstance.dna.creation
            local count = creation.torsoSegments
            print(url)
            for i = 1, count do
                CharacterManager.updateBodyhairOfPart(humanoidInstance, 'torso' .. i,
                    { bgURL = url .. '.png', fgURL = url .. '-mask.png', bgHex = bgHex, fgHex = fgHex, pHex = pHex })
            end
            CharacterManager.addTexturesFromInstance2(humanoidInstance)
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
                    { shape8URL = url .. '.png', sy = s * (math.random() < 0.5 and -1 or 1), sx = s },
                    humanoidInstance)
                --CharacterManager.updateShape8(humanoidInstance, 'torso' .. i, url)
            end


            local s = 1 + math.random() * 1
            local urlIndex = math.ceil(math.random() * #urls)
            local url = urls[urlIndex]
            CharacterManager.updatePart('head',
                { shape8URL = url .. '.png', sy = s * (math.random() < 0.5 and -1 or 1), sx = s },
                humanoidInstance)

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

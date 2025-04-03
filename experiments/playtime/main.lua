-- TODO
-- build a ui where you can add multiple tags..

local old_print = print
print = function(...)
    local info = debug.getinfo(2, "Sl")
    local source = info.source
    if source:sub(-4) == ".lua" then source = source:sub(1, -5) end
    if source:sub(1, 1) == "@" then source = source:sub(2) end
    local msg = ("%s:%i"):format(source, info.currentline)
    old_print(msg, ...)
end

local blob = require 'vendor.loveblobs'
inspect = require 'vendor.inspect'
local Peeker = require 'vendor.peeker'

local recorder = require 'src.recorder'

local ui = require 'src.ui-all'
local playtimeui = require 'src.playtime-ui'
local shapes = require 'src.shapes'
local selectrect = require 'src.selection-rect'
local eio = require 'src.io'
local script = require 'src.script'
local objectManager = require 'src.object-manager'
local mathutils = require 'src.math-utils'
local utils = require 'src.utils'
local box2dDraw = require 'src.box2d-draw'
local box2dDrawTextured = require 'src.box2d-draw-textured'

local box2dPointerJoints = require 'src.box2d-pointerjoints'
local camera = require 'src.camera'
local cam = camera.getInstance()
local fixtures = require 'src.fixtures'
snap = require 'src.snap'
registry = require 'src.registry'
local InputManager = require 'src.input-manager'
local state = require 'src.state'

function waitForEvent()
    local a, b, c, d, e
    repeat
        a, b, c, d, e = love.event.wait()
        --print(a, b, c, d, e)
    until a == "focus" or a == 'mousepressed' or a == 'touchpressed'
end

waitForEvent()

local PANEL_WIDTH = 300
local BUTTON_HEIGHT = 40
local ROW_WIDTH = 160
local BUTTON_SPACING = 10
local FIXED_TIMESTEP = true
local FPS = 60 -- in platime ui we also have a fps
local TICKRATE = 1 / FPS

local now = love.timer:getTime()

function love.load(args)
    local font = love.graphics.newFont('assets/cooper_bold_bt.ttf', 25)
    love.keyboard.setKeyRepeat(true)
    love.graphics.setFont(font)

    ui.init(font)

    sceneScript = nil
    scriptPath = nil
    lastModTime = nil
    hotReloadTimer = 0    -- Accumulates time
    hotReloadInterval = 1 -- Check every 1 second

    love.physics.setMeter(state.world.meter)


    state.physicsWorld = love.physics.newWorld(0, state.world.gravity * love.physics.getMeter(), true)


    local w, h = love.graphics.getDimensions()
    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(325, 325, 2000, 2000)


    objectManager.addThing('rectangle', { x = 200, y = 400, height = 100, width = 400 })
    -- objectManager.addThing('rectangle', 200, 400, 'dynamic', 100, 400, 400)
    -- objectManager.addThing('rectangle', 600, 400, 'dynamic', 100)
    -- objectManager.addThing('rectangle', 450, 800, 'kinematic', 200)
    -- objectManager.addThing('rectangle', 850, 800, 'static', 200)
    -- objectManager.addThing('rectangle', 250, 1000, 'static', 100, 1800)
    -- objectManager.addThing('rectangle', 1100, 100, 'dynamic', 300)
    -- objectManager.addThing('circle', 1000, 400, 'dynamic', 100)
    -- objectManager.addThing('circle', 1300, 400, 'dynamic', 100)


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
    --loadScriptAndScene('water')
    --loadScriptAndScene('puppet')
    local cwd = love.filesystem.getWorkingDirectory()
    reloadScene(cwd .. '/scripts/lekker.playtime.json')

    checkpoints = {}
    activeCheckpointIndex = 0
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

function reloadScene(name)
    local data = getFiledata(name):getString()
    state.selection.selectedJoint = nil
    state.selection.selectedObj = nil
    eio.reload(data, state.physicsWorld)
    print("Scene loaded: " .. name)
    print(inspect(registry.bodies))
    return data
end

function loadScene(name)
    local data = getFiledata(name):getString()
    state.selection.selectedJoint = nil
    state.selection.selectedObj = nil
    eio.load(data, state.physicsWorld, cam)
    print("Scene loaded: " .. name)
    return data
end

function loadScriptAndScene(id)
    local jsonPath = '/scripts/' .. id .. '.playtime.json'
    local luaPath = '/scripts/' .. id .. '.playtime.lua'
    jsoninfo = love.filesystem.getInfo(jsonPath)
    luainfo = love.filesystem.getInfo(luaPath)
    if (jsoninfo and luainfo) then
        local cwd = love.filesystem.getWorkingDirectory()
        reloadScene(cwd .. jsonPath)
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
    script.setEnv({ worldState = state.world, world = state.physicsWorld, state = state })
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
    if recorder.isRecording or recorder.isReplaying then
        recorder:update(dt)
    end

    Peeker.update(dt)
    maybeHotReload(dt)

    local scaled_dt = dt * state.world.speedMultiplier
    if not state.world.paused then
        if state.world.playWithSoftbodies then
            for i, v in ipairs(state.world.softbodies) do
                v:update(scaled_dt)
            end
        end

        for i = 1, 1 do
            state.physicsWorld:update(scaled_dt)
        end
        script.call('update', scaled_dt)

        snap.update(scaled_dt)
    end
    function tablelength(T)
        local count = 0
        for _ in pairs(T) do count = count + 1 end
        return count
    end

    if recorder.isRecording and tablelength(recorder.recordingMouseJoints) > 0 then
        recorder:recordMouseJointUpdates(cam)
        --print('hwo to record mousejoint movement')
    end

    box2dPointerJoints.handlePointerUpdate(scaled_dt, cam)
    --phys.handleUpdate(dt)

    if state.interaction.draggingObj then
        InputManager.handleDraggingObj()
    end
end

local function drawGrid(cam)
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

function drawUI()
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
        playtimeui.drawAddShapeUI()
    end

    -- "Add Joint" Button
    if ui.button(230, 20, 200, 'add joint') then
        state.panelVisibility.addJointOpened = not state.panelVisibility.addJointOpened
    end

    if state.panelVisibility.addJointOpened then
        playtimeui.drawAddJointUI()
    end

    -- "World Settings" Button
    if ui.button(440, 20, 200, 'settings') then
        state.panelVisibility.worldSettingsOpened = not state.panelVisibility.worldSettingsOpened
    end

    if state.panelVisibility.worldSettingsOpened then
        playtimeui.drawWorldSettingsUI()
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
        playtimeui.drawRecordingUI()
    end
    if sceneScript and sceneScript.onStart then
        if ui.button(920, 20, 50, 'R') then
            -- todo actually reread the file itself!
            loadAndRunScript(scriptPath)
            sceneScript.onStart()
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
                objectManager.finalizePolygon()
            end
            x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
            if ui.button(x, y, 260, 'soft-surface') then
                objectManager.finalizePolygonAsSoftSurface()
            end
        end)
    end

    if state.selection.selectedObj and not state.selection.selectedJoint and not state.selection.selectedSFixture then
        playtimeui.drawUpdateSelectedObjectUI()
    end

    if state.selection.selectedBodies and #state.selection.selectedBodies > 0 then
        playtimeui.drawSelectedBodiesUI()
    end

    if (state.currentMode == 'jointCreationMode') and state.jointParams.body1 and state.jointParams.body2 then
        playtimeui.doJointCreateUI(500, 100, 400, 150)
    end

    if state.selection.selectedSFixture then
        playtimeui.drawSelectedSFixture()
    end

    if state.selection.selectedObj and state.selection.selectedJoint then
        -- (w - panelWidth - 20, 20, panelWidth, h - 40
        playtimeui.doJointUpdateUI(state.selection.selectedJoint, w - PANEL_WIDTH - 20, 20, PANEL_WIDTH, h - 40)
    end

    if (state.currentMode == 'setOffsetA') or (state.currentMode == 'setOffsetB') or state.currentMode == 'positioningSFixture' then
        ui.panel(500, 100, 300, 60, '• click point ∆', function()
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


    if ui.draggingActive then
        love.graphics.setColor(ui.theme.draggedElement.fill)
        local x, y = love.mouse.getPosition()
        love.graphics.circle('fill', x, y, 10)
        love.graphics.setColor(1, 1, 1)
    end
end

function love.draw()
    Peeker.attach()
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(120 / 255, 125 / 255, 120 / 255)
    if state.editorPreferences.showGrid then
        drawGrid(cam, state.world)
    end

    box2dDrawTextured.makeCombinedImages()
    cam:push()
    love.graphics.setColor(1, 1, 1, 1)
    box2dDraw.drawWorld(state.physicsWorld, state.world.debugDrawMode)
    box2dDrawTextured.drawTexturedWorld(state.physicsWorld)

    script.call('draw')

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
            -- print(inspect(polygon), inspect(tris))
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
                love.graphics.circle('fill', vx, vy, 10)
            else
                love.graphics.circle('line', vx, vy, 10)
            end
        end
    end


    if state.texFixtureEdit.tempVerts and state.selection.selectedSFixture and state.texFixtureEdit.lockedVerts == false then
        local thing = state.selection.selectedSFixture:getBody():getUserData().thing
        local verts = mathutils.getLocalVerticesForCustomSelected(state.texFixtureEdit.tempVerts,
            thing, 0, 0)

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

    cam:pop()

    -- love.graphics.print(string.format("%.1f", (love.timer.getTime() - now)), 0, 0)
    --love.graphics.print(string.format("%03d", love.timer.getTime()), 100, 100)


    Peeker.detach()
    if state.interaction.startSelection then
        selectrect.draw(state.interaction.startSelection)
    end


    drawUI()
    script.call('drawUI')

    if recorder.isRecording then
        love.graphics.setColor(1, 0, 0)
        love.graphics.circle('fill', 20, 20, 20)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(string.format("%.1f", love.timer.getTime() - recorder.startTime), 5, 5)
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
    elseif (state.currentMode == 'drawFreePoly' or state.currentMode == 'drawClickPoly') then
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

function love.keypressed(key)
    ui.handleKeyPress(key)
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

    script.call('onKeyPress', key)
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

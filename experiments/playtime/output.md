main.lua
```lua
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


    world = love.physics.newWorld(0, state.world.gravity * love.physics.getMeter(), true)


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
        local b = blob.softbody(world, 500, 0, 102, 1, 1)
        b:setFrequency(3)
        b:setDamping(0.1)
        --b:setFriction(1)

        table.insert(state.world.softbodies, b)
        local points = {
            0, 500, 800, 500,
            800, 800, 0, 800
        }
        local b = blob.softsurface(world, points, 120, "dynamic")
        table.insert(state.world.softbodies, b)
        b:setJointFrequency(2)
        b:setJointDamping(.1)
        --b:setFixtureRestitution(2)
        -- b:setFixtureFriction(10)
    end


    world:setCallbacks(beginContact, endContact, preSolve, postSolve)


    --local cwd = love.filesystem.getWorkingDirectory()
    --loadScene(cwd .. '/scripts/snap2.playtime.json')
    --loadScene(cwd .. '/scripts/grow.playtime.json')

    --loadScriptAndScene('straight')
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
    state.ui.selectedJoint = nil
    state.ui.selectedObj = nil
    eio.reload(data, world)
    print("Scene loaded: " .. name)
    print(inspect(registry.bodies))
    return data
end

function loadScene(name)
    local data = getFiledata(name):getString()
    state.ui.selectedJoint = nil
    state.ui.selectedObj = nil
    eio.load(data, world, cam)
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
    script.setEnv({ worldState = state.world, world = world })
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
            world:update(scaled_dt)
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

    if state.ui.draggingObj then
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
        state.ui.addShapeOpened = not state.ui.addShapeOpened
    end

    if state.ui.addShapeOpened then
        playtimeui.drawAddShapeUI()
    end

    -- "Add Joint" Button
    if ui.button(230, 20, 200, 'add joint') then
        state.ui.addJointOpened = not state.ui.addJointOpened
    end

    if state.ui.addJointOpened then
        playtimeui.drawAddJointUI()
    end

    -- "World Settings" Button
    if ui.button(440, 20, 200, 'settings') then
        state.ui.worldSettingsOpened = not state.ui.worldSettingsOpened
    end

    if state.ui.worldSettingsOpened then
        playtimeui.drawWorldSettingsUI()
    end

    -- Play/Pause Button
    if ui.button(650, 20, 150, state.world.paused and 'play' or 'pause') then
        state.world.paused = not state.world.paused
    end

    if ui.button(810, 20, 150, state.world.isRecordingPointers and 'recording' or 'record') then
        state.ui.recordingPanelOpened = not state.ui.recordingPanelOpened
        -- state.world.isRecordingPointers = not state.world.isRecordingPointers
    end
    if state.ui.recordingPanelOpened then
        playtimeui.drawRecordingUI()
    end
    if sceneScript and sceneScript.onStart then
        if ui.button(920, 20, 50, 'R') then
            -- todo actually reread the file itself!
            loadAndRunScript(scriptPath)
            sceneScript.onStart()
        end
    end

    if state.ui.drawClickPoly then
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

    if state.ui.selectedObj and not state.ui.selectedJoint and not state.ui.selectedSFixture then
        playtimeui.drawUpdateSelectedObjectUI()
    end

    if state.ui.selectedBodies and #state.ui.selectedBodies > 0 then
        playtimeui.drawSelectedBodiesUI()
    end

    if state.ui.jointCreationMode and state.ui.jointCreationMode.body1 and state.ui.jointCreationMode.body2 then
        playtimeui.doJointCreateUI(500, 100, 400, 150)
    end

    if state.ui.selectedSFixture then
        playtimeui.drawSelectedSFixture()
    end

    if state.ui.selectedObj and state.ui.selectedJoint then
        -- (w - panelWidth - 20, 20, panelWidth, h - 40
        playtimeui.doJointUpdateUI(state.ui.selectedJoint, w - PANEL_WIDTH - 20, 20, PANEL_WIDTH, h - 40)
    end

    if state.ui.setOffsetAFunc or state.ui.setOffsetBFunc or state.ui.setUpdateSFixturePosFunc then
        ui.panel(500, 100, 300, 60, '• click point ∆', function()
        end)
    end

    if state.ui.jointCreationMode and ((state.ui.jointCreationMode.body1 == nil) or (state.ui.jointCreationMode.body2 == nil)) then
        if (state.ui.jointCreationMode.body1 == nil) then
            ui.panel(500, 100, 300, 100, '• pick 1st body •', function()
                local x = 510
                local y = 150
                local width = 280
                if ui.button(x, y, width, 'cancel') then
                    state.ui.jointCreationMode = nil
                end
            end)
        elseif (state.ui.jointCreationMode.body2 == nil) then
            ui.panel(500, 100, 300, 100, '• pick 2nd body •', function()
                local x = 510
                local y = 150
                local width = 280
                if ui.button(x, y, width, 'cancel') then
                    state.ui.jointCreationMode = nil
                end
            end)
        end
    end

    if state.ui.showPalette then
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
                    state.ui.showPaletteFunc(box2dDrawTextured.palette[i])
                end
            end
        end)
    end

    if state.ui.saveDialogOpened then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle('fill', 0, 0, w, h)
        love.graphics.setColor(1, 1, 1)
        ui.panel(300, 300, w - 600, h - 600, '»»» save «««', function()
            local t = ui.textinput('savename', 320, 350, w - 640, 40, 'add text...', state.ui.saveName)
            if t then
                state.ui.saveName = utils.sanitizeString(t)
            end
            if ui.button(320, 500, 200, 'save') then
                state.ui.saveDialogOpened = false
                eio.save(world, cam, state.ui.saveName)
            end
            if ui.button(540, 500, 200, 'cancel') then
                state.ui.saveDialogOpened = false
                love.system.openURL("file://" .. love.filesystem.getSaveDirectory())
            end
        end)
    end

    if state.ui.quitDialogOpened then
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
    if state.ui.showGrid then
        drawGrid(cam, state.world)
    end

    box2dDrawTextured.makeCombinedImages()
    cam:push()
    love.graphics.setColor(1, 1, 1, 1)
    box2dDraw.drawWorld(world, state.world.debugDrawMode)
    box2dDrawTextured.drawTexturedWorld(world)

    script.call('draw')

    if state.ui.selectedSFixture and not state.ui.selectedSFixture:isDestroyed() then
        local body = state.ui.selectedSFixture:getBody()
        local centroid = fixtures.getCentroidOfFixture(body, state.ui.selectedSFixture)
        local x2, y2 = body:getWorldPoint(centroid[1], centroid[2])
        love.graphics.circle('line', x2, y2, 3)
    end

    if state.ui.selectedJoint and not state.ui.selectedJoint:isDestroyed() then
        box2dDraw.drawJointAnchors(state.ui.selectedJoint)
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
    if state.ui.drawFreePoly or state.ui.drawClickPoly then
        if (#state.ui.polyVerts >= 6) then
            love.graphics.polygon('line', state.ui.polyVerts)
        end
    end

    -- draw mousehandlers for dragging vertices
    if state.ui.polyTempVerts and state.ui.selectedObj and state.ui.selectedObj.shapeType == 'custom' and state.ui.polyLockedVerts == false then
        local verts = mathutils.getLocalVerticesForCustomSelected(state.ui.polyTempVerts,
            state.ui.selectedObj, state.ui.polyCentroid.x, state.ui.polyCentroid.y)

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


    if state.ui.texFixtureTempVerts and state.ui.selectedSFixture and state.ui.texFixtureLockedVerts == false then
        local thing = state.ui.selectedSFixture:getBody():getUserData().thing
        local verts = mathutils.getLocalVerticesForCustomSelected(state.ui.texFixtureTempVerts,
            thing, 0, 0)
        --local verts = state.ui.texFixtureTempVerts
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
    if state.ui.selectedBodies then
        local bodies = utils.map(state.ui.selectedBodies, function(thing)
            return thing.body
        end)
        box2dDraw.drawBodies(bodies)
    end

    -- draw temp poly when changing vertices
    if state.ui.polyTempVerts and state.ui.selectedObj then
        local verts = mathutils.getLocalVerticesForCustomSelected(state.ui.polyTempVerts,
            state.ui.selectedObj, state.ui.polyCentroid.x, state.ui.polyCentroid.y)
        love.graphics.setColor(1, 0, 0)
        love.graphics.polygon('line', verts)
        love.graphics.setColor(1, 1, 1) -- Rese
    end

    cam:pop()

    -- love.graphics.print(string.format("%.1f", (love.timer.getTime() - now)), 0, 0)
    --love.graphics.print(string.format("%03d", love.timer.getTime()), 100, 100)


    Peeker.detach()
    if state.ui.startSelection then
        selectrect.draw(state.ui.startSelection)
    end


    drawUI()
    script.call('drawUI')

    if recorder.isRecording then
        love.graphics.setColor(1, 0, 0)
        love.graphics.circle('fill', 20, 20, 20)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(string.format("%.1f", love.timer.getTime() - recorder.startTime), 5, 5)
    end

    if state.ui.maybeHideSelectedPanel then
        if (state.ui.selectedSFixture) then
            local body = state.ui.selectedSFixture:getBody()
            local thing = body:getUserData().thing

            state.ui.selectedObj = thing
            state.ui.selectedSFixture = nil
            state.ui.maybeHideSelectedPanel = false
        elseif (state.ui.selectedJoint) then
            state.ui.selectedJoint = nil
            state.ui.maybeHideSelectedPanel = false
        else
            if not (ui.activeElementID or ui.focusedTextInputID) then
                state.ui.selectedObj = nil
                state.ui.selectedSFixture = nil
                state.ui.selectedJoint = nil
            end
            state.ui.maybeHideSelectedPanel = false
            state.ui.polyTempVerts = nil
            state.ui.polyLockedVerts = true
        end
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
    if state.ui.polyDragIdx and state.ui.polyDragIdx > 0 then
        local index = state.ui.polyDragIdx
        local obj = state.ui.selectedObj
        local angle = obj.body:getAngle()
        local dx2, dy2 = mathutils.rotatePoint(dx, dy, 0, 0, -angle)
        dx2 = dx2 / cam.scale
        dy2 = dy2 / cam.scale
        state.ui.polyTempVerts[index] = state.ui.polyTempVerts[index] + dx2
        state.ui.polyTempVerts[index + 1] = state.ui.polyTempVerts[index + 1] + dy2
    elseif state.ui.texFixtureDragIdx and state.ui.texFixtureDragIdx > 0 then
        local index = state.ui.texFixtureDragIdx
        local obj = state.ui.selectedSFixture:getBody():getUserData().thing
        local angle = obj.body:getAngle()
        local dx2, dy2 = mathutils.rotatePoint(dx, dy, 0, 0, -angle)
        dx2 = dx2 / cam.scale
        dy2 = dy2 / cam.scale
        state.ui.texFixtureTempVerts[index] = state.ui.texFixtureTempVerts[index] + dx2
        state.ui.texFixtureTempVerts[index + 1] = state.ui.texFixtureTempVerts[index + 1] + dy2
    elseif state.ui.capturingPoly then
        local wx, wy = cam:getWorldCoordinates(x, y)
        -- Check if the distance from the last point is greater than minPointDistance
        local addPoint = false
        if not state.ui.lastPolyPt then
            addPoint = true
        else
            local lastX, lastY = state.ui.lastPolyPt.x, state.ui.lastPolyPt.y
            local distSq = (wx - lastX) ^ 2 + (wy - lastY) ^ 2
            if distSq >= (state.ui.minPointDistance / cam.scale) ^ 2 then
                addPoint = true
            end
        end
        if addPoint then
            --table.insert(state.ui.polygonVertices, { x = wx, y = wy })
            table.insert(state.ui.polyVerts, wx)
            table.insert(state.ui.polyVerts, wy)
            state.ui.lastPolyPt = { x = wx, y = wy }
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
        if state.ui.quitDialogOpened == true then
            love.event.quit()
        end
        if state.ui.quitDialogOpened == false then
            state.ui.quitDialogOpened = true
        end
    end
    if key == 'space' then
        if state.ui.quitDialogOpened == true then
            state.ui.quitDialogOpened = false
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
        state.ui.saveDialogOpened = true
    end
    if key == 'i' and state.ui.polyTempVerts then
        -- figure out where my mousecursor is, between what nodes?
        local mx, my = love.mouse.getPosition()
        local wx, wy = cam:getWorldCoordinates(mx, my)
        objectManager.insertCustomPolygonVertex(wx, wy)
        objectManager.maybeUpdateCustomPolygonVertices()
    end
    if key == 'd' and state.ui.polyTempVerts then
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

```

src/box2d-draw-textured.lua
```lua
local lib = {}

local mathutils = require 'src.math-utils'

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


--local img = love.graphics.newImage('textures/leg1.png')
local tex1 = love.graphics.newImage('textures/pat/type2t.png')
tex1:setWrap('mirroredrepeat', 'mirroredrepeat')
local line = love.graphics.newImage('textures/shapes6.png')
local maskTex = love.graphics.newImage('textures/shapes6-mask.png')
--local imgw, imgh = img:getDimensions()
local imageCache = {}

function getLoveImage(path)
    if not imageCache[path] then
        local info = love.filesystem.getInfo(path)
        if not info or info.type ~= 'file' then
            --print("Warning: File not found - " .. path)
            return nil, nil, nil
        end
        local img = love.graphics.newImage(path)
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

local shrinkFactor = 1

--local image = nil

lib.setShrinkFactor = function(value)
    shrinkFactor = value
end
lib.getShrinkFactor = function()
    return shrinkFactor
end

local function getDrawParams(flipx, flipy, imgw, imgh)
    local sx = flipx
    local sy = flipy

    local ox = flipx == -1 and imgw or 0
    local oy = flipy == -1 and imgh or 0

    return sx, sy, ox, oy
end



lib.makeTexturedCanvas = function(lineart, mask, color1, alpha1, texture2, color2, alpha2, texRot, texScale,
                                  texOffX, texOffY,
                                  lineColor, lineAlpha,
                                  flipx, flipy, patch1)
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
            transform:scale(texScale, texScale)

            local m1, m2, _, _, m5, m6 = transform:getMatrix()
            local dx = texOffX --love.math.random() * .001
            local dy = texOffY
            maskShader:send('fill', texture2)
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

        print(patch1, patch1 and patch1.img)
        if (patch1 and patch1.img) then
            love.graphics.setColorMask(true, true, true, false)

            local r, g, b, a = lib.hexToColor(patch1.hex or 'ffffff')
            love.graphics.setColor(r, g, b, a)


            local image = patch1.img
            local imgw, imgh = image:getDimensions()
            local xOffset = (patch1.tx or 0) * (imgw) * shrinkFactor
            local yOffset = (patch1.ty or 0) * (imgh) * shrinkFactor
            love.graphics.draw(image, (lw) / 2 + xOffset, (lh) / 2 + yOffset, (patch1.r or 0) * ((math.pi * 2) / 16),
                (patch1.sx or 1) * shrinkFactor,
                (patch1.sy or 1) * shrinkFactor,
                imgw / 2, imgh / 2)
            print('getting in here!')
            love.graphics.setColorMask(true, true, true, true)
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



function lib.makeCombinedImages()
    local bodies = world:getBodies()
    for _, body in ipairs(bodies) do
        local fixtures = body:getFixtures()
        for i = 1, #fixtures do
            local ud = fixtures[i]:getUserData()
            if ud and ud.extra and ud.extra.OMP and ud.extra.dirty then
                ud.extra.dirty = false

                local outlineImage = getLoveImage('textures/' .. ud.extra.bgURL)
                local olr, olg, olb, ola = lib.hexToColor(ud.extra.bgHex)
                local maskImage = getLoveImage('textures/' .. ud.extra.fgURL)
                local mr, mg, mb, ma = lib.hexToColor(ud.extra.fgHex)
                local patternImage = getLoveImage('textures/pat/' .. ud.extra.patternURL)
                local pr, pg, pb, pa = lib.hexToColor(ud.extra.patternHex)

                if ud.extra.patch1URL then
                    print(ud.extra.patch1URL, 'textures/' .. ud.extra.patch1URL)
                end
                local patch1 = ud.extra.patch1URL and {

                    img = getLoveImage('textures/' .. ud.extra.patch1URL),
                    hex = ud.extra.patch1Hex,
                    tx = ud.extra.patch1TX,
                    ty = ud.extra.patch1TY,
                    sx = ud.extra.patch1SX,
                    sy = ud.extra.patch1SY,
                    r = ud.extra.patch1r,
                } or nil

                local imgData = lib.makeTexturedCanvas(
                    line,                      -- line art
                    maskTex,                   -- mask

                    { mr, mg, mb },            -- color1
                    ma * 5,                    -- alpha1
                    tex1,                      -- texture2 (fill texture)
                    { pr, pg, pb },            -- color2
                    pa * 5,                    -- alpha2
                    ud.extra.texRotation or 0, -- texRot
                    ud.extra.texScale or 1,    -- texScale
                    ud.extra.texXOff or 0,
                    ud.extra.texYOff or 0,
                    { olr, olg, olb },      -- lineColor
                    ola * 5,                -- lineAlpha
                    ud.extra.texFlipX or 1, -- flipx (normal)
                    ud.extra.texFlipY or 1, -- flipy (normal)
                    patch1                  -- renderPatch (set to truthy to enable extra patch rendering)
                )
                image = love.graphics.newImage(imgData)

                ud.extra.ompImage = image
                fixtures[i]:setUserData(ud)
            end
        end
    end
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
            if (ud and ud.extra and ud.extra.type == 'texfixture') then
                local composedZ = ((ud.extra.zGroupOffset or 0) * 1000) + (ud.extra.zOffset or 0)
                --print(inspect(ud.extra))
                table.insert(drawables,
                    {
                        z = composedZ,
                        texfixture = fixtures[i],
                        extra = ud.extra,
                        body = body,
                        thing = body:getUserData().thing
                    })
            end
        end
    end
    --print(#drawables)
    table.sort(drawables, function(a, b)
        return a.z < b.z
    end)

    --for _, body in ipairs(bodies) do
    for i = 1, #drawables do
        local body = drawables[i].body
        local thing = drawables[i].thing
        local texfixture = drawables[i].texfixture



        if texfixture then
            local extra = drawables[i].extra


            if not extra.OMP and extra.bgURL then -- this is the BG and FG routine
                local url = extra.bgURL
                local img, imgw, imgh = getLoveImage('textures/' .. url)
                local body = texfixture:getBody()

                local vertices = { texfixture:getShape():getPoints() }

                if (img) then
                    -- -- the Mesh DrawMode "fan" works well for 4-vertex Meshes.
                    -- mesh = love.graphics.newMesh(vert2, "fan")
                    -- mesh:setTexture(img)

                    if vertices then
                        local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
                        local sx = ww / imgw
                        local sy = hh / imgh
                        local r, g, b, a = lib.hexToColor(extra.bgHex)
                        local rx, ry = mathutils.rotatePoint(cx, cy, 0, 0, body:getAngle())

                        love.graphics.setColor(r, g, b, a)
                        love.graphics.draw(img, body:getX() + rx, body:getY() + ry,
                            body:getAngle(), sx * 1, sy * 1,
                            (imgw) / 2, (imgh) / 2)

                        -- love.graphics.draw(mesh, body:getX() + rx, body:getY() + ry, body:getAngle(), sx * 1, sy * 1,
                        --     (imgw) / 2, (imgh) / 2)
                    else
                        print('NO VERTICES FOUND, kinda hard ', inspect(thing))
                    end
                end

                local url = extra.fgURL
                local img, imgw, imgh = getLoveImage('textures/' .. url)
                local body = texfixture:getBody()

                local vertices = { texfixture:getShape():getPoints() }

                if (img) then
                    if vertices then
                        local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
                        local sx = ww / imgw
                        local sy = hh / imgh
                        local r, g, b, a = lib.hexToColor(extra.fgHex)
                        local rx, ry = mathutils.rotatePoint(cx, cy, 0, 0, body:getAngle())

                        love.graphics.setColor(r, g, b, a)
                        love.graphics.draw(img, body:getX() + rx, body:getY() + ry,
                            body:getAngle(), sx * 1, sy * 1,
                            (imgw) / 2, (imgh) / 2)

                        -- love.graphics.draw(mesh, body:getX() + rx, body:getY() + ry, body:getAngle(), sx * 1, sy * 1,
                        --     (imgw) / 2, (imgh) / 2)
                    else
                        print('NO VERTICES FOUND, kinda hard ', inspect(thing))
                    end
                end
            end

            if extra.OMP then
                if (texfixture) then
                    --local thing = ud.thing
                    --local vertices = thing.vertices
                    local vertices = { texfixture:getShape():getPoints() }
                    image = extra.ompImage --lib.makePatternTexture()


                    if (image) then
                        local img = image
                        local imgw, imgh = image:getDimensions()
                        if vertices then
                            local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
                            local sx = ww / imgw
                            local sy = hh / imgh
                            local rx, ry = mathutils.rotatePoint(cx, cy, 0, 0, body:getAngle())
                            --local r, g, b, a = hexToColor(thing.textures.bgHex)
                            love.graphics.setColor(1, 1, 1, 1)
                            --love.graphics.draw(img, body:getX(), body:getY())
                            love.graphics.draw(img, body:getX() + rx, body:getY() + ry, body:getAngle(),
                                sx * 1 * thing.mirrorX,
                                sy * 1 * thing.mirrorY, (imgw) / 2, (imgh) / 2)
                        else
                            print('NO VERTICES FOUND, kinda hard ', inspect(thing))
                        end
                    end
                end
                --end
            end
        end
    end
    --love.graphics.setDepthMode()
end

return lib

```

src/box2d-draw.lua
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
        if jointType == 'revolute' then
            if joint:areLimitsEnabled() then
                local lower = joint:getLowerLimit()
                local upper = joint:getUpperLimit()

                local bodyA, bodyB = joint:getBodies()
                local b1A = bodyA:getAngle()

                love.graphics.setColor(1, 1, 1, alpha)
                love.graphics.setLineJoin("miter")
                love.graphics.arc('line', x1, y1, 15, math.pi / 2 + b1A + lower, math.pi / 2 + b1A + upper)
                love.graphics.setLineJoin("none")


                local b1B = bodyB:getAngle()

                local angleBetween = b1A - b1B

                local endX, endY = getEndpoint(x1, y1, (b1B + math.pi / 2), 15)

                love.graphics.setColor(0.5, 0.5, 0.5, alpha)
                love.graphics.line(x1, y1, endX, endY)
            end
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
        --for _, thing in ipairs(state.ui.selectedBodies) do
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

src/box2d-pointerjoints.lua
```lua
--box2d-pointerjoints.lua
local lib = {}

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

    local bodies = world:getBodies()
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

src/camera.lua
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

src/fixtures.lua
```lua
--fixtures.lua


local mathutils = require 'src.math-utils'
local uuid = require 'src.uuid'

local registry = require 'src.registry'
local lib = {}


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


function lib.destroyFixture(fixture)
    registry.unregisterSFixture(fixture:getUserData().id)
    fixture:destroy()
end

function lib.createSFixture(body, localX, localY, cfg)
    if (cfg.label == 'snap') then
        local shape = love.physics.newPolygonShape(rect(cfg.radius, cfg.radius, localX, localY))
        local fixture = love.physics.newFixture(body, shape)
        fixture:setSensor(true) -- Sensor so it doesn't collide
        local setId = uuid.generateID()
        fixture:setUserData({ type = "sfixture", id = setId, label = cfg.label, extra = {} })
        registry.registerSFixture(setId, fixture)
        return fixture
    end
    if (cfg.label == 'texfixture') then
        local shape = love.physics.newPolygonShape(rect(cfg.width, cfg.height, localX, localY))
        local fixture = love.physics.newFixture(body, shape, 0)
        fixture:setSensor(true) -- Sensor so it doesn't collide
        local setId = uuid.generateID()
        fixture:setUserData({ type = "sfixture", id = setId, label = '', extra = { type = 'texfixture' } })
        registry.registerSFixture(setId, fixture)
        return fixture
    end
    print('I NEED A BETTER CONFIG FOR THIS FIXTURE OF YOURS!')
end

return lib

```

src/input-manager.lua
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

local function handlePointer(x, y, id, action)
    if action == "pressed" then
        -- Handle press logig
        --   -- this will block interacting on bodies when 'roughly' over the opened panel
        if state.ui.saveDialogOpened then return end
        if state.ui.showPalette then
            local w, h = love.graphics.getDimensions()
            if y < h - 400 or x > w - 300 then
                state.ui.showPalette = nil
                return
            else
                return
            end
        end
        if state.ui.selectedJoint or state.ui.selectedObj or state.ui.selectedSFixture or state.ui.selectedBodies or state.ui.drawClickPoly then
            local w, h = love.graphics.getDimensions()
            if x > w - 300 then
                return
            end
        end

        local startSelection = love.keyboard.isDown('lshift')
        if (startSelection) then
            state.ui.startSelection = { x = x, y = y }
        end

        local cx, cy = cam:getWorldCoordinates(x, y)

        if state.ui.polyTempVerts and state.ui.selectedObj and state.ui.selectedObj.shapeType == 'custom' and state.ui.polyLockedVerts == false then
            local verts = mathutils.getLocalVerticesForCustomSelected(state.ui.polyTempVerts,
                state.ui.selectedObj, state.ui.polyCentroid.x, state.ui.polyCentroid.y)
            for i = 1, #verts, 2 do
                local vx = verts[i]
                local vy = verts[i + 1]
                local dist = math.sqrt((cx - vx) ^ 2 + (cy - vy) ^ 2)
                if dist < 10 then
                    state.ui.polyDragIdx = i

                    return
                else
                    state.ui.polyDragIdx = 0
                end
            end
        end

        if state.ui.texFixtureTempVerts and state.ui.selectedSFixture and state.ui.texFixtureLockedVerts == false then
            --local verts = mathutils.getLocalVerticesForCustomSelected(state.ui.polyTempVerts,
            --    state.ui.selectedObj, state.ui.polyCentroid.x, state.ui.polyCentroid.y)
            local thing = state.ui.selectedSFixture:getBody():getUserData().thing
            local verts = mathutils.getLocalVerticesForCustomSelected(state.ui.texFixtureTempVerts,
                thing, 0, 0)
            --local verts = state.ui.texFixtureTempVerts
            for i = 1, #verts, 2 do
                local vx = verts[i]
                local vy = verts[i + 1]
                local dist = math.sqrt((cx - vx) ^ 2 + (cy - vy) ^ 2)
                if dist < 10 then
                    state.ui.texFixtureDragIdx = i
                    return
                else
                    state.ui.texFixtureDragIdx = 0
                end
            end
        end



        if (state.ui.drawClickPoly) then
            table.insert(state.ui.polyVerts, cx)
            table.insert(state.ui.polyVerts, cy)
        end
        if (state.ui.setOffsetAFunc) then
            state.ui.selectedJoint = state.ui.setOffsetAFunc(cx, cy)
            state.ui.setOffsetAFunc = nil
        end
        if (state.ui.setOffsetBFunc) then
            state.ui.selectedJoint = state.ui.setOffsetBFunc(cx, cy)
            state.ui.setOffsetBFunc = nil
        end
        if (state.ui.setUpdateSFixturePosFunc) then
            state.ui.selectedSFixture = state.ui.setUpdateSFixturePosFunc(cx, cy)
            state.ui.setUpdateSFixturePosFunc = nil
        end

        local onPressedParams = {
            pointerForceFunc = function(fixture)
                return state.world.mouseForce
            end,
            damp = state.world.mouseDamping
        }

        local _, hitted, madedata = box2dPointerJoints.handlePointerPressed(cx, cy, id, onPressedParams,
            not state.world.paused)

        if (state.ui.selectedBodies and #hitted == 0) then
            state.ui.selectedBodies = nil
        end

        if #hitted > 0 then
            local ud = hitted[1]:getBody():getUserData()
            if ud and ud.thing then
                state.ui.selectedObj = ud.thing
            end
            if sceneScript and not state.world.paused and state.ui.selectedObj then
                state.ui.selectedObj = nil
            end
            if state.ui.jointCreationMode and state.ui.selectedObj then
                if state.ui.jointCreationMode.body1 == nil then
                    state.ui.jointCreationMode.body1 = state.ui.selectedObj.body
                    local px, py = state.ui.jointCreationMode.body1:getLocalPoint(cx, cy)
                    state.ui.jointCreationMode.p1 = { px, py }
                elseif state.ui.jointCreationMode.body2 == nil then
                    if (state.ui.selectedObj.body ~= state.ui.jointCreationMode.body1) then
                        state.ui.jointCreationMode.body2 = state.ui.selectedObj.body
                        local px, py = state.ui.jointCreationMode.body2:getLocalPoint(cx, cy)
                        state.ui.jointCreationMode.p2 = { px, py }
                        --print(state.ui.jointCreationMode.body2:getLocalPoint(cx, cy))
                    end
                end
            end

            if (state.world.paused) then
                -- local ud = state.ui.currentlySelectedObject:getBody():getUserData()
                state.ui.draggingObj = state.ui.selectedObj
                if state.ui.selectedObj then
                    local offx, offy = state.ui.selectedObj.body:getLocalPoint(cx, cy)
                    state.ui.offsetDragging = { -offx, -offy }
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
            state.ui.maybeHideSelectedPanel = true
        end
        if recorder.isRecording and #hitted > 0 and not state.world.paused and madedata.bodyID then
            --madedata.activeLayer = recorder.activeLayer
            recorder:recordMouseJointStart(madedata)
            -- print('should record a moujoint creation...', inspect(madedata))
        end
        -- if recorder.isRecording and #hitted > 0 then
        --     local wx, wy = cam:getWorldCoordinates(x, y)
        --     local hitObject = hitted[1]:getBody():getUserData().thing
        --     local localPointX, localPointY = hitObject.body:getLocalPoint(wx, wy)
        --     recorder:recordObjectGrab(hitObject, localPointX, localPointY, state.world.mouseForce, state.world
        --         .mouseDamping)
        -- end
    elseif action == "released" then
        -- Handle release logic
        local releasedObjs = box2dPointerJoints.handlePointerReleased(x, y, id)
        if (#releasedObjs > 0) then
            local newReleased = utils.map(releasedObjs, function(h) return h:getUserData() and h:getUserData().thing end)

            script.call('onReleased', newReleased)
            if recorder.isRecording and not state.world.paused then
                for _, obj in ipairs(releasedObjs) do
                    recorder:recordMouseJointFinish(id, obj:getUserData().thing.id)
                    --  print('should record a moujoint deletion...', inspect(obj:getUserData().thing.id))
                end
            end

            -- if recorder.isRecording then
            --     --local releasedObjs = box2dPointerJoints.handlePointerReleased(x, y, id)
            --     for _, obj in ipairs(releasedObjs) do
            --         recorder:recordObjectRelease(obj:getUserData().thing)
            --     end
            -- end
        end
        if state.ui.draggingObj then
            state.ui.draggingObj.body:setAwake(true)
            state.ui.selectedObj = state.ui.draggingObj
            state.ui.draggingObj = nil
        end

        if state.ui.drawFreePoly then
            objectManager.finalizePolygon()
        end

        if state.ui.polyDragIdx > 0 then
            state.ui.polyDragIdx = 0
            objectManager.maybeUpdateCustomPolygonVertices()
        end

        if state.ui.texFixtureDragIdx > 0 then
            state.ui.texFixtureDragIdx = 0
            objectManager.maybeUpdateTexFixtureVertices()
        end

        if (state.ui.startSelection) then
            local tlx = math.min(state.ui.startSelection.x, x)
            local tly = math.min(state.ui.startSelection.y, y)
            local brx = math.max(state.ui.startSelection.x, x)
            local bry = math.max(state.ui.startSelection.y, y)
            local tlxw, tlyw = cam:getWorldCoordinates(tlx, tly)
            local brxw, bryw = cam:getWorldCoordinates(brx, bry)
            local selected = selectrect.selectWithin(world,
                { x = tlxw, y = tlyw, width = brxw - tlxw, height = bryw - tlyw })

            state.ui.selectedBodies = selected
            state.ui.startSelection = nil
        end
    end
end

function lib.handleDraggingObj()
    local mx, my = love.mouse.getPosition()
    local wx, wy = cam:getWorldCoordinates(mx, my)
    local offx = state.ui.offsetDragging[1]
    local offy = state.ui.offsetDragging[2]
    local rx, ry = mathutils.rotatePoint(offx, offy, 0, 0, state.ui.draggingObj.body:getAngle())
    local oldPosX, oldPosY = state.ui.draggingObj.body:getPosition()
    state.ui.draggingObj.body:setPosition(wx + rx, wy + ry)
    if recorder.isRecording then
        local ud = state.ui.draggingObj.body:getUserData()
        -- print(inspect(state.ui.draggingObj))
        -- print(inspect(ud))
        recorder:recordObjectSetPosition(state.ui.draggingObj.id, wx + rx, wy + ry)
    end
    -- figure out if we are dragging a group!
    if state.ui.selectedBodies then
        for i = 1, #state.ui.selectedBodies do
            if (state.ui.selectedBodies[i] == state.ui.draggingObj) then
                local newPosX, newPosY = state.ui.draggingObj.body:getPosition()
                local dx = newPosX - oldPosX
                local dy = newPosY - oldPosY
                for j = 1, #state.ui.selectedBodies do
                    if (state.ui.selectedBodies[j] ~= state.ui.draggingObj) then
                        local oldPosX, oldPosY = state.ui.selectedBodies[j].body:getPosition()
                        state.ui.selectedBodies[j].body:setPosition(oldPosX + dx, oldPosY + dy)
                    end
                end
            end
        end
    end
end

function lib.handleMousePressed(x, y, button, istouch)
    if not istouch and button == 1 then
        if state.ui.drawFreePoly then
            -- Start capturing mouse movement
            state.ui.capturingPoly = true
            state.ui.polyVerts = {}
            state.ui.lastPolyPt = nil
        else
            handlePointer(x, y, 'mouse', 'pressed')
        end
    end

    if state.world.playWithSoftbodies and button == 2 then
        local cx, cy = cam:getWorldCoordinates(x, y)


        local b = blob.softbody(world, cx, cy, 102, 1, 1)
        b:setFrequency(3)
        b:setDamping(0.1)

        table.insert(state.world.softbodies, b)
    end
end

function lib.handleTouchPressed(id, x, y, dx, dy, pressure)
    --handlePointer(x, y, id, 'pressed')
    if state.ui.drawFreePoly then
        -- Start capturing mouse movement
        state.ui.capturingPoly = true
        state.ui.polyVerts = {}
        state.ui.lastPolyPt = nil
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

return lib

```

src/io.lua
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

local snap = require 'src.snap'

function lib.reload(data, world, cam)
    lib.load(data, world, cam, true)
end

function lib.buildWorld(data, world, cam, reuseOldIds)
    local idMap = {}
    -- todo is this actually needed, i *think* its a premature optimization, getting ready to load a file into an exitsing situation, button
    -- this isnt really used. so we just might as well just always use the oldid....

    --print(reuseOldIds)
    local function getNewId(oldId)
        if not reuseOldIds then
            if idMap[oldId] == nil then
                idMap[oldId] = uuid.generateID()
            end
            return idMap[oldId]
        else
            return oldId
        end
    end

    if true then
        for _, body in pairs(world:getBodies()) do
            body:destroy()
        end
        registry.reset()
    end

    snap.resetList()

    if data.camera then
        cam:setTranslation(data.camera.x, data.camera.y)
        cam:setScale(data.camera.scale)
        --print(inspect(cam))
        --print('camera in saved file found.', data.camera.x, data.camera.y)
    end

    local recreatedSFixtures = {}
    -- Iterate through saved bodies and recreate them
    for _, bodyData in ipairs(data.bodies) do
        -- Create a new body
        local body = love.physics.newBody(world, bodyData.position[1], bodyData.position[2], bodyData.bodyType)
        body:setAngle(bodyData.angle)
        body:setLinearVelocity(bodyData.linearVelocity[1], bodyData.linearVelocity[2])
        body:setAngularVelocity(bodyData.angularVelocity)
        body:setFixedRotation(bodyData.fixedRotation)

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
                shape = love.physics.newPolygonShape(unpack(points))
                -- elseif fixtureData.shapeType == "edge" then
                --     local x1 = fixtureData.points[1].x
                --     local y1 = fixtureData.points[1].y
                --     local x2 = fixtureData.points[2].x
                --     local y2 = fixtureData.points[2].y
                --     shape = love.physics.newEdgeShape(x1, y1, x2, y2)
            else
                print("Unsupported shape type:", fixtureData.shapeType)
            end


            if shape then
                local fixture = love.physics.newFixture(body, shape, shared.density)
                fixture:setFriction(shared.friction)
                fixture:setRestitution(shared.restitution)
                fixture:setGroupIndex(shared.groupIndex or 0)
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
                print("Unsupported joint type during load:", jointData.type)
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
            print("Failed to find bodies for joint:", jointData.id)
        end
    end
end

function lib.load(data, world, cam, reuseOldIds)
    local jsonData, pos, err = json.decode(data, 1, nil)
    if err then
        print("Error decoding JSON:", err)
        return
    end

    -- Verify version
    if jsonData then
        if jsonData.version ~= "1.0" then
            print("Unsupported save version:", jsonData.version)
            return
        end
    else
        print('failed loading json')
        return
    end
    -- Clear existing world
    lib.buildWorld(jsonData, world, cam, reuseOldIds)

    snap.onSceneLoaded()

    --print("World successfully loaded")
end

local function needsDimProperty(prop, shape)
    -- print(shape, prop)

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
                fixedRotation = body:isFixedRotation(),
                fixtures = {},
                sharedFixtureData = {}
            }
            -- Iterate through all fixtures of the body

            -- to save data i am assuming all fixtures are the same type and have the same settings.
            local bodyFixtures = body:getFixtures()
            if #bodyFixtures >= 1 then
                if #bodyFixtures >= 1 then
                    local first = bodyFixtures[1]
                    bodyData.sharedFixtureData.density = utils.round_to_decimals(first:getDensity(), 4)
                    bodyData.sharedFixtureData.friction = utils.round_to_decimals(first:getFriction(), 4)
                    bodyData.sharedFixtureData.restitution = utils.round_to_decimals(first:getRestitution(), 4)
                    bodyData.sharedFixtureData.groupIndex = first:getGroupIndex()
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
                    if utils.sanitizeString(fixture:getUserData().label) == 'snap' then
                        local ud             = fixture:getUserData()

                        ud.extra.fixture     = 'fixture'
                        ud.extra.at          = ud.extra.at and ud.extra.at:getUserData().thing.id
                        ud.extra.to          = ud.extra.to and ud.extra.to:getUserData().thing.id
                        fixtureData.userData = utils.deepCopy(ud)
                    else
                        local ud = fixture:getUserData()
                        if ud.extra and ud.extra.type == 'texfixture' then
                            if ud.extra.ompImage then ud.extra.ompImage = nil end
                        end
                        fixtureData.userData = utils.deepCopy(ud)
                    end



                    fixtureData.sensor = fixture:isSensor()
                    --print(inspect(utils.shallowCopy(fixture:getUserData())))
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
            print('what is up with this joint?')
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
                    print("Unsupported joint type during save:", joint:getType())
                end

                table.insert(saveData.joints, jointData)
            else
                print("Failed to find bodies for joint:", jointID)
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
    print(inspect(saveData))
    local jsonData = json.encode(saveData, { indent = true })

    -- Write the JSON data to a file
    local success, message = love.filesystem.write(filename .. '.playtime.json', jsonData)
    if success then
        print("World successfully saved to " .. filename)
        print("file://" .. love.filesystem.getSaveDirectory())
    else
        print("Failed to save world:", message)
    end

    love.system.openURL("file://" .. love.filesystem.getSaveDirectory())
end

function lib.cloneSelection(selectedBodies, world)
    -- Mapping from original body IDs to cloned body instances
    local clonedBodiesMap = {}

    -- Step 1: Clone Bodies
    for _, originals in ipairs(selectedBodies) do
        local originalBody = originals.body
        local userData     = originalBody:getUserData()
        if userData and userData.thing then
            local originalThing = userData.thing

            -- Generate a new unique ID for the cloned body
            local newID = uuid.generateID()

            -- Clone body properties
            local newBody = love.physics.newBody(world, originalBody:getX() + 50, originalBody:getY() + 50,
                originalBody:getType())
            newBody:setAngle(originalBody:getAngle())
            newBody:setLinearVelocity(originalBody:getLinearVelocity())
            newBody:setAngularVelocity(originalBody:getAngularVelocity())
            newBody:setFixedRotation(originalBody:isFixedRotation())
            newBody:setSleepingAllowed(originalBody:isSleepingAllowed())

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
                print('some how the userdata fixtures arent at the beginning!')
            end
            if ok and offset > -1 then
                -- print(ok, offset)
                for i = 1 + offset, #oldFixtures do
                    local oldF = oldFixtures[i]
                    local newFixture = love.physics.newFixture(newBody, newShapeList[i - (offset)], oldF:getDensity())
                    newFixture:setRestitution(oldF:getRestitution())
                    newFixture:setFriction(oldF:getFriction())
                    newFixture:setGroupIndex(oldF:getGroupIndex())
                end
                if offset > 0 then
                    -- here we should recreate the special fixtures..
                    for i = 1, offset do
                        local oldF = oldFixtures[i]
                        local shape = oldF:getShape():getPoints()
                        --print(inspect(getCentroidOfFixture(originalBody, oldF)))

                        local newFixture = love.physics.newFixture(newBody, oldF:getShape(), oldF:getDensity())
                        newFixture:setRestitution(oldF:getRestitution())
                        newFixture:setFriction(oldF:getFriction())
                        newFixture:setGroupIndex(oldF:getGroupIndex())
                        local oldUD = utils.deepCopy(oldF:getUserData())
                        oldUD.id = uuid.generateID()

                        if utils.sanitizeString(oldUD.label) == 'snap' then
                            oldUD.extra.at = nil
                            oldUD.extra.to = nil
                            oldUD.extra.fixture = nil
                        end
                        --print(inspect(oldUD))
                        newFixture:setUserData(oldUD)
                        newFixture:setSensor(oldF:isSensor())
                        --- print(oldUD.id)
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
    for _, originalThing in ipairs(state.ui.selectedBodies) do
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

                        --print(inspect(ud))

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

                            -- Include all joint-specific properties
                            for key, value in pairs(jointData) do
                                newJointData[key] = value
                            end
                            -- print(inspect(newJointData))
                            local newJoint = jointslib.createJoint(newJointData)
                            -- print(inspect(newJoint:getUserData()))
                            if ud.scriptmeta then
                                local newud = newJoint:getUserData()
                                newud.scriptmeta = utils.shallowCopy(ud.scriptmeta)
                                newJoint:setUserData(newud)
                                if ud.scriptmeta.type and ud.scriptmeta.type == 'snap' then
                                    snap.addSnapJoint(newJoint)
                                end
                                --print('we should add this to snapjoints probably')
                            end
                            -- Register the new joint
                            registry.registerJoint(newJointData.id, newJoint)
                        end
                    end
                end
            end
        end
    end

    local result = {}
    for k, v in pairs(clonedBodiesMap) do
        table.insert(result, v)
    end
    return result
    --state.ui.selectedBodies = result
end

return lib

```

src/joint-handlers.lua
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
        --print(x1, y1)
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

src/joints.lua
```lua
--joints.lua

local lib = {}
local uuid = require 'src.uuid'
local jointHandlers = require 'src.joint-handlers'
local registry = require 'src.registry'
local mathutils = require 'src.math-utils'

function lib.getJointId(joint)
    local ud = joint:getUserData()
    if ud then
        return ud.id
    end
    print('THIS IS WRONG WHY THIS JOINT HAS NO ID!!', tostring(joint:getType()))
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
        print('could not find meta settting ' .. settingKey .. ' on joint with type ' .. tostring(joint:getType()))
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
        print("Joint type '" .. jointType .. "' is not implemented yet.")
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
            print("extract: Unsupported joint type: " .. jointType)
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

function lib.recreateJoint(joint, newSettings)
    if joint:isDestroyed() then
        print("The joint is already destroyed.")
        return nil
    end

    local bodyA, bodyB = joint:getBodies()
    local jointType = joint:getType()

    local id = lib.getJointId(joint)
    local offsetA = lib.getJointMetaSetting(joint, "offsetA") or { x = 0, y = 0 }
    local offsetB = lib.getJointMetaSetting(joint, "offsetB") or { x = 0, y = 0 }
    --  print(inspect(offsetA), inspect(offsetB))
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
        print("recreate extract: Unsupported joint type: " .. jointType)
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
    --  print(inspect(data))
    return lib.createJoint(data)
end

-- this one is only called from recreateThingFromBody


local function tranlateBody(body, dx, dy)
    local x, y = body:getPosition()
    body:setPosition(x + dx, y + dy)
end

function moveUntilEnd(from, dx, dy, visited, dir)
    --print(dx, dy, visited[to:getUserData().thing.id], to)

    local joints = from:getJoints()
    for i = 1, #joints do
        local bodyA, bodyB = joints[i]:getBodies()

        if (dir == 'A') then
            print('A')
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
            --  print(inspect(oldVertices))
            local before = { x = data.offsetA.x, y = data.offsetA.y }
            --  print('A before: ', data.offsetA.x, data.offsetA.y)
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
                print('A', id)
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
                --print('B', id)
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

src/math-utils.lua
```lua
--math-utils.lua
local lib = {}


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
    --print('makePolygonAbsolute center:', newCenterX, newCenterY)
    local absolutePolygon = {}
    for i = 1, #relativePolygon, 2 do
        local x = relativePolygon[i] + newCenterX
        local y = relativePolygon[i + 1] + newCenterY
        table.insert(absolutePolygon, x)
        table.insert(absolutePolygon, y)
    end
    --  print('resulting absolute poly:', inspect(absolutePolygon))
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
    -- Expecting polygon to be a table with exactly 8 numbers: x1,y1, x2,y2, x3,y3, x4,y4
    local vertices = {
        { x = polygon[1], y = polygon[2] },
        { x = polygon[3], y = polygon[4] },
        { x = polygon[5], y = polygon[6] },
        { x = polygon[7], y = polygon[8] }
    }

    -- Compute the centroid of the 4 vertices.
    local cx, cy = 0, 0
    for i = 1, 4 do
        cx = cx + vertices[i].x
        cy = cy + vertices[i].y
    end
    cx = cx / 4
    cy = cy / 4

    -- Classify vertices relative to the centroid.
    local topLeft, topRight, bottomLeft, bottomRight
    for i = 1, 4 do
        local v = vertices[i]
        if v.x < cx and v.y < cy then
            topLeft = v
        elseif v.x >= cx and v.y < cy then
            topRight = v
        elseif v.x < cx and v.y >= cy then
            bottomLeft = v
        elseif v.x >= cx and v.y >= cy then
            bottomRight = v
        end
    end

    return topLeft, topRight, bottomRight, bottomLeft
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
    --print(inspect(poly), inspect(intersection))
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
        --print(Px,Py, x1, y1, x2, y2, lx1, ly1, lx2, ly2)
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


-- -- Slice the polygon
-- slicedPolygons = mathutils.slicePolygon(polygon, p1, p2)
-- print(inspect(slicedPolygons))
function lib.slicePolygon(polygon, p1, p2)
    -- p1 and p2 define the slicing line: {x = ..., y = ...}

    -- Step 1: Find intersection points between the slice line and the polygon
    local sliceLine = { x1 = p1.x, y1 = p1.y, x2 = p2.x, y2 = p2.y }
    local intersections = lib.findIntersections(polygon, sliceLine)

    -- Debug: Print found intersections
    --   print("Found Intersections:")
    for _, inter in ipairs(intersections) do
        --     print(string.format("Intersection at (%.2f, %.2f) on edge %d-%d", inter.x, inter.y, inter.i1, inter.i2))
    end

    -- Ensure there are at least two unique intersection points
    if #intersections < 2 then
        --     print("Slice line does not intersect the polygon twice.")
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
        print("Not enough unique intersections to slice the polygon.")
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

    -- Debug: Print polygon after insertions
    -- print("Polygon after inserting intersection points:")
    -- print(inspect(polygon))

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
        print("Failed to find the new intersection indices after insertion.")
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

    -- Debug: Print the resulting polygons
    -- print("Resulting Polygons:")
    -- print("Polygon 1:")
    -- print(inspect(poly1))
    -- print("Polygon 2:")
    -- print(inspect(poly2))

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

    -- Ensure the edgeIndex is valid
    if not params.edgeIndex or params.edgeIndex < 1 or params.edgeIndex > n then
        return nil, nil
    end

    local i = params.edgeIndex
    local j = (i % n) + 1 -- next vertex index wrapping around

    local x1, y1 = newPoly[2 * i - 1], newPoly[2 * i]
    local x2, y2 = newPoly[2 * j - 1], newPoly[2 * j]

    -- Compute new point along the edge using t
    local ex = x2 - x1
    local ey = y2 - y1
    local projX = x1 + params.t * ex
    local projY = y1 + params.t * ey

    -- Compute a perpendicular (normal) to the edge
    local length = math.sqrt(ex * ex + ey * ey)
    -- Avoid division by zero:
    if length == 0 then
        return projX, projY
    end
    local nx = -ey / length
    local ny = ex / length

    -- Offset by the stored distance along the normal direction
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
    print(2 * i - 1, 2 * i, 2 * j - 1, 2 * j)
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

src/object-manager.lua
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
    if #state.ui.polyVerts >= 6 then
        local points = state.ui.polyVerts
        local b = blob.softsurface(world, points, 120, "dynamic")
        table.insert(softbodies, b)
        b:setJointFrequency(10)
        b:setJointDamping(10)
    end
    print('blob surface wanted instead?')
    -- Reset the drawing state
    state.ui.drawClickPoly = false
    state.ui.drawFreePoly = false
    state.ui.capturingPoly = false
    state.ui.polyVerts = {}
    state.ui.lastPolyPt = nil
end

function lib.finalizePolygon()
    if #state.ui.polyVerts >= 6 then
        local cx, cy = mathutils.computeCentroid(state.ui.polyVerts)
        --local cx, cy = mathutils.getCenterOfPoints(state.ui.polyVerts)
        local settings = { x = cx, y = cy, bodyType = state.ui.nextType, vertices = state.ui.polyVerts }
        -- objectManager.addThing('custom', cx, cy, state.ui.nextType, nil, nil, nil, nil, '', state.ui.polyVerts)
        lib.addThing('custom', settings)
    else
        -- Not enough vertices to form a polygon
        print("Not enough vertices to create a polygon.")
    end
    -- Reset the drawing state
    state.ui.drawClickPoly = false
    state.ui.drawFreePoly = false
    state.ui.capturingPoly = false
    state.ui.polyVerts = {}
    state.ui.lastPolyPt = nil
end

function lib.insertCustomPolygonVertex(x, y)
    local obj = state.ui.selectedObj
    if obj then
        local offx, offy = obj.body:getPosition()
        local px, py = mathutils.worldToLocal(x - offx, y - offy, obj.body:getAngle(), state.ui.polyCentroid.x,
            state.ui.polyCentroid.y)
        -- Find the closest edge index
        local insertAfterVertexIndex = mathutils.findClosestEdge(state.ui.polyTempVerts, px, py)
        mathutils.insertValuesAt(state.ui.polyTempVerts, insertAfterVertexIndex * 2 + 1, px, py)
    end
end

-- Function to remove a custom polygon vertex based on mouse click
function lib.removeCustomPolygonVertex(x, y)
    -- Step 1: Convert world coordinates to local coordinates

    local obj = state.ui.selectedObj
    if obj then
        local offx, offy = obj.body:getPosition()
        local px, py = mathutils.worldToLocal(x - offx, y - offy, obj.body:getAngle(),
            state.ui.polyCentroid.x, state.ui.polyCentroid.y)

        -- Step 2: Find the closest vertex index
        local closestVertexIndex = mathutils.findClosestVertex(state.ui.polyTempVerts, px, py)

        if closestVertexIndex then
            -- Optional: Define a maximum allowable distance to consider for deletion
            local maxDeletionDistanceSq = 100 -- Adjust as needed (e.g., 10 units squared)
            local vx = state.ui.polyTempVerts[(closestVertexIndex - 1) * 2 + 1]
            local vy = state.ui.polyTempVerts[(closestVertexIndex - 1) * 2 + 2]
            local dx = px - vx
            local dy = py - vy
            local distSq = dx * dx + dy * dy
            --print(distSq)
            if distSq <= maxDeletionDistanceSq then
                -- Step 3: Remove the vertex from the vertex list

                -- Step 4: Ensure the polygon has a minimum number of vertices (e.g., 3)
                if #state.ui.polyTempVerts <= 6 then
                    print("Cannot delete vertex: A polygon must have at least three vertices.")
                    -- Optionally, you can restore the removed vertex or prevent deletion
                    return
                end
                mathutils.removeVertexAt(state.ui.polyTempVerts, closestVertexIndex)
                lib.maybeUpdateCustomPolygonVertices()

                -- Debugging Output
                print(string.format("Removed vertex at local coordinates: (%.2f, %.2f)", vx, vy))
            else
                print("No vertex close enough to delete.")
            end
        else
            print("No vertex found to delete.")
        end
    end
end

function lib.maybeUpdateCustomPolygonVertices()
    if not utils.tablesEqualNumbers(state.ui.polyTempVerts, state.ui.selectedObj.vertices) then
        local nx, ny = mathutils.computeCentroid(state.ui.polyTempVerts)
        local ox, oy = mathutils.computeCentroid(state.ui.selectedObj.vertices)
        local dx = nx - ox
        local dy = ny - oy
        local body = state.ui.selectedObj.body
        local dx2, dy2 = mathutils.rotatePoint(dx, dy, 0, 0, body:getAngle())
        local oldX, oldY = body:getPosition()

        body:setPosition(oldX + dx2, oldY + dy2)

        state.ui.selectedObj = lib.recreateThingFromBody(body,
            { optionalVertices = state.ui.polyTempVerts })

        state.ui.polyTempVerts = utils.shallowCopy(state.ui.selectedObj.vertices)
        -- state.ui.selectedObj.vertices = state.ui.polyTempVerts
        state.ui.polyCentroid = { x = nx, y = ny }
    end
end

function lib.maybeUpdateTexFixtureVertices()
    --print('we need todo stuff here!')
    local points = { state.ui.selectedSFixture:getShape():getPoints() }
    --print(inspect(points))
    --print(inspect(state.ui.texFixtureTempVerts))

    local oldUD = utils.shallowCopy(state.ui.selectedSFixture:getUserData())
    local body = state.ui.selectedSFixture:getBody()
    state.ui.selectedSFixture:destroy()

    local centerX, centerY = mathutils.getCenterOfPoints(points)
    local shape = love.physics.newPolygonShape(state.ui.texFixtureTempVerts)
    local newfixture = love.physics.newFixture(body, shape)
    newfixture:setSensor(true) -- Sensor so it doesn't collide

    newfixture:setUserData(oldUD)

    state.ui.selectedSFixture = newfixture
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
    local body = love.physics.newBody(world, conf.x or 0, conf.y or 0, bodyType)

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


    }
    local shapeList, vertices = shapes.createShape(shapeType, settings)

    if not shapeList then
        print("Failed to create shapes for:", shapeType)
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
    local radius = tonumber(state.ui.lastUsedRadius) or 10
    local width = tonumber(state.ui.lastUsedWidth) or radius * 2     -- Default width for polygons
    local width2 = tonumber(state.ui.lastUsedWidth2) or radius * 2.3 -- Default width for polygons
    local width3 = tonumber(state.ui.lastUsedWidth3) or radius * 2.3 -- Default width for polygons

    local height = tonumber(state.ui.lastUsedHeight) or radius * 2   -- Default height for polygons
    local height2 = tonumber(state.ui.lastUsedHeight2) or radius * 2 -- Default height for polygons
    local height3 = tonumber(state.ui.lastUsedHeight3) or radius * 2 -- Default height for polygons

    local height4 = tonumber(state.ui.lastUsedHeight4) or radius * 2 -- Default height for polygons


    local bodyType = state.ui.nextType
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
    -- print(inspect(settings))
    local thing = createThing(shapeType, settings)

    if not thing then
        print("startSpawn: Failed to create thing.")
        return
    end

    state.ui.draggingObj = thing
    state.ui.offsetDragging = { 0, 0 }
end

function lib.addThing(shapeType, settings)
    --function lib.addThing(shapeType, x, y, bodyType, radius, width, width2, height, label, optionalVertices)
    --local thing = createThing(shapeType, x, y, bodyType, radius, width, width2, height, label, optionalVertices)
    --  print(inspect(settings))
    local thing = createThing(shapeType, settings)
    if not thing then
        print("addThing: Failed to create thing.")
        return nil
    end

    return thing
end

-- this one is called when the shape of the body changes, thus, its kinda safe to make weird changes to joints too.
function lib.recreateThingFromBody(body, newSettings)
    if body:isDestroyed() then
        print("The body is already destroyed.")
        return nil
    end
    local userData = body:getUserData()
    local thing = userData and userData.thing
    -- Extract current properties
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
    local newBody = love.physics.newBody(world, x, y, bodyType)
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
            -- so maybe we can figure out between which 2 vertices i am, or closest too
            -- and then reposition myself in the same way to those 2 vertices.
            --
            -- goal would be to for example remain in place when growing a leg.. ?
            -- oh maybe its better to also use fixtures for this behaviour but not snap, but boneconnect or something.
            --
            --print(inspect(fixtures/fixturesgetCentroidOfFixture(originalBody, oldF)))
            local abs = oldF:getShape()
            local centerX, centerY = mathutils.getCenterOfPoints(points)
            if (thing.vertices) then
                local params = mathutils.closestEdgeParams(centerX, centerY, thing.vertices)
                --     --  print(inspect(params))
                local new_px, new_py = mathutils.repositionPointClosestEdge(params, newVertices)

                --     --local cx, cy = mathutils.computeCentroid(state.ui.selectedObj.vertices)
                --     --print(cx, cy, centerX, centerY)
                --     local allFixtures = body:getUserData().thing.body:getFixtures()
                --     local offX, offY = getCenterOfShapeFixtures(allFixtures)

                --     -- local weights = meanValueCoordinates(centerX, centerY, thing.vertices)
                --     -- local new_px, new_py = repositionPoint(weights, newVertices)
                ---local edgeIndex, t = findEdgeAndLerpParam(centerX, centerY, thing.vertices)
                --     --print(edgeIndex, t)
                --local new_px, new_py = lerpOnEdge(edgeIndex, t, newVertices)

                local rel = mathutils.makePolygonRelativeToCenter(points, centerX, centerY)
                abs = love.physics.newPolygonShape(mathutils.makePolygonAbsolute(rel, new_px, new_py))
                --print('jo!')

                --     --print(centerX, centerY, new_px, new_py)
            end
            --local relativePoints = makePolygonRelativeToCenter(points, centerX, centerY)
            -- local newShape = makePolygonAbsolute(relativePoints, localX, localY)



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
    for i = 1, #joints do
        local ud = bjoints[i]:getUserData()
        if ud and ud.id then
            registry.unregisterJoint(ud.id)
            bjoints[i]:destroy()
        end
    end
    local bfixtures = body:getFixtures()
    for i = 1, #bfixtures do
        local ud = bfixtures[i]:getUserData()
        if ud and ud.id then
            registry.unregisterSFixture(ud.id)
            bfixtures[i]:destroy()
        end
    end
    registry.unregisterBody(thing.id)
    body:destroy()
end

function lib.flipThing(thing, axis, recursive)
    -- Validate input
    if not thing or not thing.body then
        print("flipThing: Invalid 'thing' provided.")
        return
    end

    if axis ~= 'x' and axis ~= 'y' then
        print("flipThing: Invalid axis. Use 'x' or 'y'.")
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
        print(inspect(currentThing))
        print(currentThing.body, newX, newY)
        -- Update body's position and angle
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
                    print("flipThing: Joint without valid user data encountered.")
                    goto continue
                end

                toBeProcessedJoints[jointUserData.id] = joint
                -- Determine the other body connected by the joint
                local bodyA, bodyB = joint:getBodies()
                local otherBody = (bodyA == currentBody) and bodyB or bodyA
                local otherThing = otherBody:getUserData() and otherBody:getUserData().thing

                if not otherThing then
                    print("flipThing: Connected joint's other body is invalid.")
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
                print("flipThing: Joint without valid user data encountered.")
                goto continue
            end

            if processedJoints[jointUserData.id] then
                goto continue
            end
            processedJoints[jointUserData.id] = true

            -- Extract joint data using the handler
            local handler = jointHandlers[jointType]
            if not handler or not handler.extract then
                print("flipThing: No handler found for joint type:", jointType)
                goto continue
            end
            local jointData = handler.extract(joint)

            -- Determine the connected bodies
            local bodyA, bodyB = joint:getBodies()
            local thingA = bodyA:getUserData() and bodyA:getUserData().thing
            local thingB = bodyB:getUserData() and bodyB:getUserData().thing

            if not thingA or not thingB then
                print("flipThing: One or both connected things are invalid.")
                goto continue
            end


            print(
                'I should figure out if i want to do something weird with the offset, think connect to torso logic at edge nr...')
            --print('old', inspect(processedBodies[thingA.id]), inspect(processedBodies[thingB.id]))
            --print('new', inspect(thingA.vertices), inspect(thingB.vertices))





            local offsetA = jointUserData.offsetA
            local offsetB = jointUserData.offsetB
            --print('before', inspect(offsetA), inspect(offsetB))
            if axis == 'x' then
                offsetA.x = -offsetA.x
                offsetB.x = -offsetB.x
            elseif axis == 'y' then
                offsetA.y = -offsetA.y
                offsetB.y = -offsetB.y
            end




            local id = joint:getUserData().id
            joints.recreateJoint(joint, { offsetA = offsetA, offsetB = offsetB })
            -- print(registry.getJointByID(id):isDestroyed())

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

src/playtime-ui.lua
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
local PANEL_WIDTH = 300
local BUTTON_HEIGHT = ui.theme.lineHeight
local ROW_WIDTH = 160
local BUTTON_SPACING = 10
local FPS = 60
local offsetHasChangedViaOutside
local BGcolorHasChangedViaPalette
local FGcolorHasChangedViaPalette
local PatternColorHasChangedViaPalette
local Patch1ColorHasChangedViaPalette

local colorpickers = {
    bg = false
}


local function createSliderWithId(id, label, x, y, width, min, max, value, callback, changed)
    local newValue = ui.sliderWithInput(id .. "::" .. label, x, y, width, min, max, value, changed)
    if newValue then
        callback(newValue)
    end
    ui.label(x, y, label)
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
    ui.panel(_x, _y, w, h, '∞ ' .. state.ui.jointCreationMode.jointType .. ' ∞', function()
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
            local j = joints.createJoint(state.ui.jointCreationMode)
            state.ui.selectedJoint = j
            state.ui.selectedObject = nil
            state.ui.jointCreationMode = nil
        end

        if ui.button(x + width + 10, y, width, 'Cancel') then
            state.ui.jointCreationMode = nil
        end
    end)
end

function lib.doJointUpdateUI(j, _x, _y, w, h)
    if not j:isDestroyed() then
        ui.panel(_x, _y, w, h, '∞ ' .. j:getType() .. ' ∞', function()
            local bodyA, bodyB = j:getBodies()
            if state.ui.jointUpdateMode == nil then
                state.ui.jointUpdateMode = { body1 = bodyA, body2 = bodyB, jointType = j:getType() }
            end
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
                    state.ui.axisEnabled or false,
                    function(val)
                        state.ui.axisEnabled = val
                    end
                )

                if axisEnabled then
                    local _x, _y = j:getAxis()
                    --_x, _y = normalizeAxis(_x, _y)
                    nextRow()
                    local axisX = createSliderWithId(jointId, ' axisX', x, y, 160, -1, 1,
                        _x or 0,
                        function(val)
                            state.ui.selectedJoint = joints.recreateJoint(j, { axisX = val, axisY = _y })
                            j = state.ui.selectedJoint
                        end
                    )
                    nextRow()
                    local axisY = createSliderWithId(jointId, ' axisY', x, y, 160, -1, 1,
                        _y or 1,
                        function(val)
                            state.ui.selectedJoint = joints.recreateJoint(j, { axisX = _x, axisY = val })
                            j = state.ui.selectedJoint
                        end
                    )
                    nextRow()
                    if ui.button(x, y, 160, 'normalize') then
                        local _x, _y = j:getAxis()
                        _x, _y = mathutils.normalizeAxis(_x, _y)
                        state.ui.selectedJoint = joints.recreateJoint(j, { axisX = _x, axisY = _y })
                        j = state.ui.selectedJoint
                    end
                end
                return j
            end

            local function collideFunctionality(j)
                local collideEnabled = createCheckbox(' collide', x, y,
                    j:getCollideConnected(),
                    function(val)
                        state.ui.selectedJoint = joints.recreateJoint(j, { collideConnected = val })
                        j = state.ui.selectedJoint
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
                    state.ui.selectedJoint = joints.recreateJoint(j)
                    j = state.ui.selectedJoint


                    offsetHasChangedViaOutside = true
                    return j
                end

                function updateOffsetB(x, y)
                    --local rx, ry = rotatePoint(x, y, 0, 0, bodyA:getAngle())

                    offsetB.x = x
                    offsetB.y = y
                    joints.setJointMetaSetting(j, 'offsetB', { x = offsetB.x, y = offsetB.y })
                    state.ui.selectedJoint = joints.recreateJoint(j)
                    j = state.ui.selectedJoint


                    offsetHasChangedViaOutside = true
                    return j
                end

                -- Ensure offsets exist


                nextRow()
                if ui.button(x, y, BUTTON_HEIGHT, '∆') then
                    state.ui.setOffsetAFunc = function(x, y)
                        local fx, fy = mathutils.rotatePoint(x - bodyA:getX(), y - bodyA:getY(), 0, 0, -bodyA:getAngle())
                        -- print(fx, fy)
                        return updateOffsetA(fx, fy)
                    end
                end
                if ui.button(x + 50, y, BUTTON_HEIGHT, 'b  ') then
                    state.ui.setOffsetBFunc = function(x, y)
                        local fx, fy = mathutils.rotatePoint(x - bodyB:getX(), y - bodyB:getY(), 0, 0, -bodyB:getAngle())
                        -- print(fx, fy)
                        return updateOffsetB(fx, fy)
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
                    state.ui.jointUpdateMode.length or myLength,
                    function(val)
                        j:setLength(val)
                        state.ui.jointUpdateMode.length = val
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
                    state.ui.jointUpdateMode.maxLength or myLength,
                    function(val)
                        j:setMaxLength(val)
                        state.ui.jointUpdateMode.maxLength = val
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
    local panelHeight = titleHeight + ((#shapeTypes + 5) * (buttonHeight + buttonSpacing)) + buttonSpacing

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

        local minDist = ui.sliderWithInput('minDistance', x, y, 80, 1, 150, state.ui.minPointDistance or 10)
        ui.label(x, y, 'dis')
        if minDist then
            state.ui.minPointDistance = minDist
        end

        -- Add a button for custom polygon
        nextRow()
        if ui.button(x, y, width, 'freeform') then
            state.ui.drawFreePoly = true
            state.ui.polyVerts = {}
            state.ui.lastPolyPt = nil
        end
        nextRow()

        if ui.button(x, y, width, 'click') then
            state.ui.drawClickPoly = true
            state.ui.polyVerts = {}
            state.ui.lastPolyPt = nil
        end
        nextRow()

        local width = panelWidth - 20
        local height = buttonHeight

        local _, pressed, released = ui.button(x, y, width, 'sfixture')
        if pressed then
            ui.draggingActive = ui.activeElementID
            local mx, my = love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)

            state.ui.offsetDragging = { 0, 0 }
        end
        if released then
            local mx, my = love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)
            local _, hitted = box2dPointerJoints.handlePointerPressed(wx, wy, 'mouse', {}, not state.world.paused)
            if (#hitted > 0) then
                local body = hitted[#hitted]:getBody()
                local localX, localY = body:getLocalPoint(wx, wy)
                local fixture = fixtures.createSFixture(body, localX, localY, { label = 'snap', radius = 30 })
                state.ui.selectedSFixture = fixture
            end
            ui.draggingActive = nil
        end
        nextRow()


        local _, pressed, released = ui.button(x, y, width, 'texfixture')
        if pressed then
            ui.draggingActive = ui.activeElementID
            local mx, my = love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)

            state.ui.offsetDragging = { 0, 0 }
        end
        if released then
            local mx, my = love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)
            local _, hitted = box2dPointerJoints.handlePointerPressed(wx, wy, 'mouse', {}, not state.world.paused)
            if (#hitted > 0) then
                local body = hitted[#hitted]:getBody()

                local verts = body:getUserData().thing.vertices
                local cx, cy, w, h = mathutils.getCenterOfPoints(verts)
                print(cx, cy, w, h)
                local localX, localY = body:getLocalPoint(wx, wy)
                local fixture = fixtures.createSFixture(body, localX, localY,
                    { label = 'texfixture', width = w, height = h })
                state.ui.selectedSFixture = fixture
            end
            ui.draggingActive = nil
        end
        nextRow()
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
                state.ui.jointCreationMode = { body1 = nil, body2 = nil, jointType = joint }
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
            state.ui.selectedJoint = nil
            state.ui.selectedObj = nil
            eio.buildWorld(checkpoints[activeCheckpointIndex].saveData, world, cam, true)
            --

            if sceneScript then sceneScript.onStart() end
        end

        local addcheckpointbutton = ui.button(x, y, width, 'add checkpoint')
        if addcheckpointbutton then
            local saveData = eio.gatherSaveData(world, cam)
            table.insert(checkpoints, { saveData = saveData, recordings = {} })
        end
        nextRow()
        local chars = { 'A', 'B', 'C', 'D', 'E', 'F' }
        for i = 1, #checkpoints do
            if ui.button(x + (i - 1) * 45, y, 40, chars[i]) then
                if activeCheckpointIndex > 0 then
                    checkpoints[activeCheckpointIndex].recordings = utils.deepCopy(recorder.recordings)
                end

                activeCheckpointIndex = i

                recorder.recordings = utils.deepCopy(checkpoints[activeCheckpointIndex].recordings)
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

        if activeCheckpointIndex > 0 and ((not recorder.isRecording and state.world.paused) or recorder.isRecording) then
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
        if activeCheckpointIndex > 0 then
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
        local grav = ui.sliderWithInput('grav', x, y, ROW_WIDTH, -10, BUTTON_HEIGHT, state.world.gravity)
        if grav then
            state.world.gravity = grav
            if world then
                world:setGravity(0, state.world.gravity * state.world.meter)
            end
        end
        ui.label(x, y, ' gravity')
        nextRow()

        local g, value = ui.checkbox(x, y, state.ui.showGrid, 'grid') --showGrid = true,
        if g then
            state.ui.showGrid = value
        end
        local g, value = ui.checkbox(x + 150, y, state.world.debugDrawMode, 'draw') --showGrid = true,
        if g then
            state.world.debugDrawMode = value
        end
        nextRow()



        local debugAlpha = ui.sliderWithInput('debugalpha', x, y, ROW_WIDTH, 0, 1, state.world.debugAlpha)
        if debugAlpha then
            state.world.debugAlpha = debugAlpha
        end
        ui.label(x, y, ' dbgAlpha')
        nextRow()
        nextRow()

        local mouseForce = ui.sliderWithInput(' mouse F', x, y, ROW_WIDTH, 0, 1000000, state.world.mouseForce)
        if mouseForce then
            state.world.mouseForce = mouseForce
        end
        ui.label(x, y, ' mouse F')
        nextRow()

        local mouseDamp = ui.sliderWithInput(' damp', x, y, ROW_WIDTH, 0.001, 1, state.world.mouseDamping)
        if mouseDamp then
            state.world.mouseDamping = mouseDamp
        end
        ui.label(x, y, ' damp')


        -- Add Speed Multiplier Slider

        nextRow()
        local newSpeed = ui.sliderWithInput('speed', x, y, ROW_WIDTH, 0.1, 10.0, state.world.speedMultiplier)
        if newSpeed then
            state.world.speedMultiplier = newSpeed
        end
        ui.label(x, y, ' speed')

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
    end)
end

local hadBeenDraggingObj = false
local accordionStatesSF = {
    ['texture'] = true,
    ['patch1'] = false,
    ['patch2'] = false,
}

function lib.drawSelectedSFixture()
    local panelWidth = PANEL_WIDTH
    local w, h = love.graphics.getDimensions()
    if state.ui.draggingObj then
        hadBeenDraggingObj = true
    end
    local ud = state.ui.selectedSFixture:getUserData()
    local sfixtureType = (ud and ud.extra and ud.extra.type == 'texfixture') and 'texfixture' or 'sfixture'

    -- Function to create an accordion
    local function drawAccordion(key, contentFunc)
        -- Draw the accordion header

        local clicked = ui.header_button(x, y, PANEL_WIDTH - 40, (accordionStatesSF[key] and " ÷  " or " •") ..
            ' ' .. key, accordionStatesSF[key])
        if clicked then
            accordionStatesSF[key] = not accordionStatesSF[key]
        end
        y = y + BUTTON_HEIGHT + BUTTON_SPACING

        -- If the accordion is expanded, draw the content
        -- print(key)
        --print(inspect(accordionStates))
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

        local myID = state.ui.selectedSFixture:getUserData().id
        local myLabel = state.ui.selectedSFixture:getUserData().label or ''
        --print(myID)

        local newLabel = ui.textinput(myID .. ' label', x, y, 260, BUTTON_HEIGHT, "", myLabel)
        if newLabel and newLabel ~= myLabel then
            local oldUD = utils.shallowCopy(state.ui.selectedSFixture:getUserData())
            oldUD.label = newLabel

            state.ui.selectedSFixture:setUserData(oldUD)
        end
        nextRow()


        if ui.button(x, y, ROW_WIDTH, 'destroy') then
            fixtures.destroyFixture(state.ui.selectedSFixture)
            state.ui.selectedSFixture = nil
            return
        end
        nextRow()

        local updateSFixtureDimensionsFunc = function(w, h)
            local points = { state.ui.selectedSFixture:getShape():getPoints() }
            local oldUD = utils.shallowCopy(state.ui.selectedSFixture:getUserData())
            local body = state.ui.selectedSFixture:getBody()
            state.ui.selectedSFixture:destroy()

            local centerX, centerY = mathutils.getCenterOfPoints(points)
            local shape = love.physics.newPolygonShape(rect(w, h, centerX, centerY))
            local newfixture = love.physics.newFixture(body, shape)
            newfixture:setSensor(true) -- Sensor so it doesn't collide
            newfixture:setUserData(oldUD)

            state.ui.selectedSFixture = newfixture
            --snap.updateFixture(newfixture)
            registry.registerSFixture(oldUD.id, newfixture)

            return newfixture
        end

        local updateSFixturePosFunc = function(x, y)
            local body = state.ui.selectedSFixture:getBody()
            local beforeIndex = 0
            local myfixtures = body:getFixtures()

            for i = 1, #myfixtures do
                if myfixtures[i] == state.ui.selectedSFixture then
                    beforeIndex = i
                end
            end
            local localX, localY = body:getLocalPoint(x, y)
            local points = { state.ui.selectedSFixture:getShape():getPoints() }
            local centerX, centerY = mathutils.getCenterOfPoints(points)
            local relativePoints = mathutils.makePolygonRelativeToCenter(points, centerX, centerY)
            local newShape = mathutils.makePolygonAbsolute(relativePoints, localX, localY)
            local oldUD = utils.shallowCopy(state.ui.selectedSFixture:getUserData())
            state.ui.selectedSFixture:destroy()

            local shape = love.physics.newPolygonShape(newShape)
            local newfixture = love.physics.newFixture(body, shape)
            newfixture:setSensor(true) -- Sensor so it doesn't collide

            newfixture:setUserData(oldUD)
            local afterIndex = 0
            local myfixtures = body:getFixtures()
            for i = 1, #myfixtures do
                if myfixtures[i] == newfixture then
                    afterIndex = i
                end
            end
            --print(beforeIndex, afterIndex)
            registry.registerSFixture(oldUD.id, newfixture)

            return newfixture
        end



        if ui.button(x, y, BUTTON_HEIGHT, '∆') then
            state.ui.setUpdateSFixturePosFunc = updateSFixturePosFunc
        end
        if ui.button(x + 150, y, ROW_WIDTH - 100, 'c') then
            local body = state.ui.selectedSFixture:getBody()
            state.ui.selectedSFixture = updateSFixturePosFunc(body:getX(), body:getY())
        end
        if ui.button(x + 210, y, ROW_WIDTH - 100, 'd') then
            local body = state.ui.selectedSFixture:getBody()
            --print(inspect(body))
            local verts = body:getUserData().thing.vertices
            local cx, cy, w, h = mathutils.getCenterOfPoints(verts)
            updateSFixtureDimensionsFunc(w, h)
        end
        nextRow()


        if sfixtureType == 'texfixture' then
            local points = { state.ui.selectedSFixture:getShape():getPoints() }
            local w, h   = mathutils.getPolygonDimensions(points)

            if ui.checkbox(x, y, state.ui.showTexFixtureDim, 'dims') then
                state.ui.showTexFixtureDim = not state.ui.showTexFixtureDim
            end
            nextRow()
            if (state.ui.showTexFixtureDim) then
                local newWidth = ui.sliderWithInput(myID .. 'texfix width', x, y, ROW_WIDTH, 1, 1000, w)
                ui.label(x, y, ' width')
                nextRow()

                local newHeight = ui.sliderWithInput(myID .. ' texfix height', x, y, ROW_WIDTH, 1, 1000, h)
                ui.label(x, y, ' height')
                nextRow()

                if newWidth and math.abs(newWidth - w) > 1 then
                    updateSFixtureDimensionsFunc(newWidth, h)
                    w, h = mathutils.getPolygonDimensions(points)
                end
                if newHeight and math.abs(newHeight - h) > 1 then
                    updateSFixtureDimensionsFunc(w, newHeight)
                    w, h = mathutils.getPolygonDimensions(points)
                end
            end
            local oldTexFixUD = state.ui.selectedSFixture:getUserData()
            local newZOffset = ui.sliderWithInput(myID .. 'texfixzOffset', x, y, ROW_WIDTH, -180, 180,
                math.floor(oldTexFixUD.extra.zOffset or 0),
                (not state.world.paused) or dirtyBodyChange)
            if newZOffset and oldTexFixUD.extra.zOffset ~= newZOffset then
                oldTexFixUD.extra.zOffset = math.floor(newZOffset)
            end
            ui.label(x, y, ' zOffset')
            nextRow()

            drawAccordion("texture", function()
                nextRow()
                local e = state.ui.selectedSFixture:getUserData().extra
                if ui.checkbox(x, y, true, (e.OMP == false or e.OMP == nil) and 'BG + FG' or 'OMP') then
                    e.OMP = not e.OMP
                end

                nextRow()

                --lineart, mask, pattern

                function handlePaletteAndHex(idPrefix, postFix, x, y, currentHex, onColorChange)
                    local r, g, b, a = box2dDrawTextured.hexToColor(currentHex)
                    local paletteShow = ui.button(x, y, 40, '', BUTTON_HEIGHT, { r, g, b, a })
                    if paletteShow then
                        if state.ui.showPalette then
                            state.ui.showPalette = nil
                            state.ui.showPaletteFunc = nil
                        else
                            state.ui.showPalette = true
                            state.ui.showPaletteFunc = function(color)
                                currentHex = color
                                oldTexFixUD.extra.dirty = true
                                colorpickers[postFix] = true
                                onColorChange(color)
                            end
                        end
                    end
                    local hex = ui.textinput(idPrefix .. postFix, x + 50, y, 210, BUTTON_HEIGHT, "", currentHex or '',
                        false, colorpickers[postFix])
                    if hex and hex ~= currentHex then
                        currentHex = hex
                        onColorChange(hex)
                        oldTexFixUD.extra.dirty = true
                    end

                    if colorpickers[postFix] then
                        colorpickers[postFix] = false
                    end
                    ui.label(x + 50, y, postFix, { 1, 1, 1, 0.2 })
                    return currentHex
                end

                function handleURLInput(id, labelText, x, y, currentValue, updateCallback)
                    local newValue = ui.textinput(id .. labelText, x, y, 260, BUTTON_HEIGHT, "", currentValue or '')
                    if newValue and newValue ~= currentValue then
                        updateCallback(newValue)
                        oldTexFixUD.extra.dirty = true
                        state.ui.selectedSFixture:setUserData(oldTexFixUD)
                    end
                    ui.label(x, y, labelText, { 1, 1, 1, 0.2 })
                    return newValue or currentValue
                end

                if not e.OMP then
                    handleURLInput(myID, 'bgURL', x, y, oldTexFixUD.extra.bgURL,
                        function(u) oldTexFixUD.extra.bgURL = u end)
                    nextRow()
                    handlePaletteAndHex(myID, 'bgHex', x, y, oldTexFixUD.extra.bgHex,
                        function(c) oldTexFixUD.extra.bgHex = c end)
                    nextRow()
                    handleURLInput(myID, 'fgURL', x, y, oldTexFixUD.extra.fgURL,
                        function(u) oldTexFixUD.extra.fgURL = u end)
                    nextRow()
                    handlePaletteAndHex(myID, 'fgHex', x, y, oldTexFixUD.extra.fgHex,
                        function(c) oldTexFixUD.extra.fgHex = c end)
                    nextRow()
                end
                if e.OMP then
                    handleURLInput(myID, 'bgURL', x, y, oldTexFixUD.extra.bgURL,
                        function(u) oldTexFixUD.extra.bgURL = u end)
                    nextRow()
                    handlePaletteAndHex(myID, 'bgHex', x, y, oldTexFixUD.extra.bgHex,
                        function(color) oldTexFixUD.extra.bgHex = color end)
                    nextRow()
                    handleURLInput(myID, 'fgURL', x, y, oldTexFixUD.extra.fgURL,
                        function(u) oldTexFixUD.extra.fgURL = u end)
                    nextRow()
                    handlePaletteAndHex(myID, 'fgHex', x, y, oldTexFixUD.extra.fgHex,
                        function(c) oldTexFixUD.extra.fgHex = c end)
                    nextRow()
                    ---
                    handleURLInput(myID, 'patternURL', x, y, oldTexFixUD.extra.patternURL,
                        function(u) oldTexFixUD.extra.patternURL = u end)
                    nextRow()
                    handlePaletteAndHex(myID, 'patternHex', x, y, oldTexFixUD.extra.patternHex,
                        function(color) oldTexFixUD.extra.patternHex = color end)
                    nextRow()

                    -----
                    local newRotation = ui.sliderWithInput(myID .. ' texrotation', x, y, ROW_WIDTH, 0, math.pi * 2,
                        oldTexFixUD.extra.texRotation or 0)
                    ui.label(x, y, ' texrot')
                    if newRotation and newRotation ~= oldTexFixUD.extra.texRotation then
                        oldTexFixUD.extra.texRotation = newRotation
                        oldTexFixUD.extra.dirty = true
                    end
                    nextRow()
                    local newScale = ui.sliderWithInput(myID .. ' texscale', x, y, ROW_WIDTH, 0.01, 3,
                        oldTexFixUD.extra.texScale or 0)
                    ui.label(x, y, ' texscale')
                    if newScale and newScale ~= oldTexFixUD.extra.texScale then
                        oldTexFixUD.extra.texScale = newScale
                        oldTexFixUD.extra.dirty = true
                    end
                    nextRow()
                    local newXOff = ui.sliderWithInput(myID .. ' texXOffscale', x, y, ROW_WIDTH, 0, 1,
                        oldTexFixUD.extra.texXOff or 0)
                    ui.label(x, y, ' xoff')
                    if newXOff and newXOff ~= oldTexFixUD.extra.texXOff then
                        oldTexFixUD.extra.texXOff = newXOff
                        oldTexFixUD.extra.dirty = true
                    end
                    nextRow()
                    local newYOff = ui.sliderWithInput(myID .. ' texYOffscale', x, y, ROW_WIDTH, 0, 1,
                        oldTexFixUD.extra.texYOff or 0)
                    ui.label(x, y, ' yoff')
                    if newYOff and newYOff ~= oldTexFixUD.extra.texYOff then
                        oldTexFixUD.extra.texYOff = newYOff
                        oldTexFixUD.extra.dirty = true
                    end
                    nextRow()
                    local dirtyX, checkedX = ui.checkbox(x, y, e.texFlipX == -1, 'flipx')
                    if dirtyX then
                        oldTexFixUD.extra.texFlipX = checkedX and -1 or 1
                        oldTexFixUD.extra.dirty = true
                        state.ui.selectedSFixture:setUserData(oldTexFixUD)
                    end
                    local dirtyY, checkedY = ui.checkbox(x + 150, y, e.texFlipY == -1, 'flipy')
                    if dirtyY then
                        oldTexFixUD.extra.texFlipY = checkedY and -1 or 1
                        oldTexFixUD.extra.dirty = true
                        state.ui.selectedSFixture:setUserData(oldTexFixUD)
                    end

                    nextRow()
                end
            end)
            nextRow()
            drawAccordion('patch1', function()
                -- 2 patches will be made here for now.
                local patch1URL = ui.textinput(myID .. 'patchURL1', x + 40, y, 220, BUTTON_HEIGHT, "",
                    oldTexFixUD.extra.patch1URL or '')
                if patch1URL and patch1URL ~= oldTexFixUD.extra.patch1URL then
                    oldTexFixUD.extra.patch1URL = patch1URL
                    oldTexFixUD.extra.dirty = true
                    state.ui.selectedSFixture:setUserData(oldTexFixUD)
                end

                ui.label(x + 50, y, 'patchURL1', { 1, 1, 1, 0.2 })
                nextRow()
                nextRow()
                local paletteShow = ui.button(x, y, 40, 'p', BUTTON_HEIGHT)
                if paletteShow then
                    if state.ui.showPalette then
                        state.ui.showPalette = nil
                        state.ui.showPaletteFunc = nil
                    else
                        state.ui.showPalette = true
                        state.ui.showPaletteFunc = function(color)
                            oldTexFixUD.extra.patch1Hex = color
                            oldTexFixUD.extra.dirty = true
                            PatternColorHasChangedViaPalette = true
                        end
                    end
                end
                local patch1Hex = ui.textinput(myID .. ' patchHex1', x + 50, y, 210, BUTTON_HEIGHT, "",
                    oldTexFixUD.extra.patch1Hex or '',
                    false,
                    PatternColorHasChangedViaPalette)
                if patch1Hex and patch1Hex ~= oldTexFixUD.extra.patch1Hex then
                    oldTexFixUD.extra.patch1Hex = patch1Hex
                    oldTexFixUD.extra.dirty = true
                end
                if PatternColorHasChangedViaPalette then
                    PatternColorHasChangedViaPalette = false
                end
                ui.label(x + 50, y, 'patchHex1', { 1, 1, 1, 0.2 })
                nextRow()

                local patch1TX = ui.sliderWithInput(myID .. ' patch1TX', x, y, 50, -1, 1,
                    oldTexFixUD.extra.patch1TX or 0)
                ui.label(x, y, 'TX')
                if patch1TX and patch1TX ~= oldTexFixUD.extra.patch1TX then
                    oldTexFixUD.extra.patch1TX = patch1TX
                    oldTexFixUD.extra.dirty = true
                end
                -- nextRow()
                local patch1TY = ui.sliderWithInput(myID .. ' patch1TY', x + 140, y, 50, -1, 1,
                    oldTexFixUD.extra.patch1TY or 0)
                ui.label(x + 140, y, 'TY')
                if patch1TY and patch1TY ~= oldTexFixUD.extra.patch1TY then
                    oldTexFixUD.extra.patch1TY = patch1TY
                    oldTexFixUD.extra.dirty = true
                end


                nextRow()

                local patch1SX = ui.sliderWithInput(myID .. ' patch1SX', x, y, 50, -1, 1,
                    oldTexFixUD.extra.patch1SX or 1)
                ui.label(x, y, 'SX')
                if patch1SX and patch1SX ~= oldTexFixUD.extra.patch1SX then
                    oldTexFixUD.extra.patch1SX = patch1SX
                    oldTexFixUD.extra.dirty = true
                end
                -- nextRow()
                local patch1SY = ui.sliderWithInput(myID .. ' patch1SY', x + 140, y, 50, -1, 1,
                    oldTexFixUD.extra.patch1SY or 1)
                ui.label(x + 140, y, 'SY')
                if patch1SY and patch1SY ~= oldTexFixUD.extra.patch1SY then
                    oldTexFixUD.extra.patch1SY = patch1SY
                    oldTexFixUD.extra.dirty = true
                end
                nextRow()
                local patch1r = ui.sliderWithInput(myID .. ' patch1r', x, y, ROW_WIDTH, -math.pi, math.pi,
                    oldTexFixUD.extra.patch1r or 1)
                ui.label(x, y, ' patch1r')
                if patch1r and patch1r ~= oldTexFixUD.extra.patch1r then
                    oldTexFixUD.extra.patch1r = patch1r
                    oldTexFixUD.extra.dirty = true
                end
                nextRow()
            end)
            nextRow()
            drawAccordion('patch2', function()
                -- 2 patches will be made here for now.
                local patchURL2 = ui.textinput(myID .. 'patchURL2', x + 40, y, 220, BUTTON_HEIGHT, "",
                    oldTexFixUD.extra.patchURL2 or '')
                if patchURL2 and patchURL2 ~= oldTexFixUD.extra.patchURL2 then
                    oldTexFixUD.extra.patchURL1 = patchURL2
                    oldTexFixUD.extra.dirty = true
                    state.ui.selectedSFixture:setUserData(oldTexFixUD)
                end

                ui.label(x + 50, y, 'patchURL2', { 1, 1, 1, 0.2 })
                nextRow()
                nextRow()
                local paletteShow = ui.button(x, y, 40, 'p', BUTTON_HEIGHT)
                if paletteShow then
                    if state.ui.showPalette then
                        state.ui.showPalette = nil
                        state.ui.showPaletteFunc = nil
                    else
                        state.ui.showPalette = true
                        state.ui.showPaletteFunc = function(color)
                            oldTexFixUD.extra.patchHex2 = color
                            oldTexFixUD.extra.dirty = true
                            PatternColorHasChangedViaPalette = true
                        end
                    end
                end
                local patchHex2 = ui.textinput(myID .. ' patchHex2', x + 50, y, 210, BUTTON_HEIGHT, "",
                    oldTexFixUD.extra.patchHex2 or '',
                    false,
                    PatternColorHasChangedViaPalette)
                if patchHex2 and patchHex2 ~= oldTexFixUD.extra.patchHex2 then
                    oldTexFixUD.extra.patchHex2 = patchHex2
                    oldTexFixUD.extra.dirty = true
                end
                if PatternColorHasChangedViaPalette then
                    PatternColorHasChangedViaPalette = false
                end
                ui.label(x + 50, y, 'patchHex2', { 1, 1, 1, 0.2 })
                nextRow()
                local patch2TX = ui.sliderWithInput(myID .. ' patch2TX', x, y, ROW_WIDTH, -1, 1,
                    oldTexFixUD.extra.patch2TX or 0)
                ui.label(x, y, ' patch2TX')
                if patch2TX and patch2TX ~= oldTexFixUD.extra.patch2TX then
                    oldTexFixUD.extra.patch2TX = patch2TX
                end
                nextRow()
                local patch2TY = ui.sliderWithInput(myID .. ' patch2TY', x, y, ROW_WIDTH, -1, 1,
                    oldTexFixUD.extra.patch2TY or 0)
                ui.label(x, y, ' patch2TY')
                if patch2TY and patch2TY ~= oldTexFixUD.extra.patch2TY then
                    oldTexFixUD.extra.patch2TY = patch2TY
                end


                local patch2SX = ui.sliderWithInput(myID .. ' patch2SX', x, y, ROW_WIDTH, -1, 1,
                    oldTexFixUD.extra.patch2SX or 1)
                ui.label(x, y, ' patch2SX')
                if patch2SX and patch2SX ~= oldTexFixUD.extra.patch2SX then
                    oldTexFixUD.extra.patch2SX = patch2SX
                end
                nextRow()
                local patch2SY = ui.sliderWithInput(myID .. ' patch2SY', x, y, ROW_WIDTH, -1, 1,
                    oldTexFixUD.extra.patch2SY or 1)
                ui.label(x, y, ' patch2SY')
                if patch2SY and patch2SY ~= oldTexFixUD.extra.patch2SY then
                    oldTexFixUD.extra.patch2SY = patch2SY
                end
                nextRow()
                local patch2r = ui.sliderWithInput(myID .. ' patch2r', x, y, ROW_WIDTH, -1, 1,
                    oldTexFixUD.extra.patch2r or 1)
                ui.label(x, y, ' patch2r')
                if patch2r and patch2r ~= oldTexFixUD.extra.patch2r then
                    oldTexFixUD.extra.patch2r = patch2r
                end
                nextRow()
            end)
        else
            local points = { state.ui.selectedSFixture:getShape():getPoints() }
            local dim = mathutils.getPolygonDimensions(points)
            local newRadius = ui.sliderWithInput(myID .. ' radius', x, y, ROW_WIDTH, 1, 200, dim)
            ui.label(x, y, ' radius')
            if newRadius and newRadius ~= dim then
                updateSFixtureDimensionsFunc(newRadius, newRadius)
                snap.rebuildSnapFixtures(registry.sfixtures)
            end
        end
        nextRow()

        local function handleOffset(xMultiplier, yMultiplier)
            local body = state.ui.selectedSFixture:getBody()
            local parentVerts = body:getUserData().thing.vertices
            local allFixtures = body:getUserData().thing.body:getFixtures()
            local points = { state.ui.selectedSFixture:getShape():getPoints() }
            local centerX, centerY = mathutils.getCenterOfPoints(points)
            local bounds = mathutils.getBoundingRect(parentVerts)
            local relativePoints = mathutils.makePolygonRelativeToCenter(points, centerX, centerY)
            local newShape = mathutils.makePolygonAbsolute(relativePoints,
                ((bounds.width / 2) * xMultiplier),
                ((bounds.height / 2) * yMultiplier))

            local oldUD = utils.shallowCopy(state.ui.selectedSFixture:getUserData())
            state.ui.selectedSFixture:destroy()

            local shape = love.physics.newPolygonShape(newShape)
            local newfixture = love.physics.newFixture(body, shape)
            newfixture:setSensor(true) -- Sensor so it doesn't collide
            newfixture:setUserData(oldUD)
            state.ui.selectedSFixture = newfixture
        end

        if sfixtureType ~= 'texfixture' then
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
            local cloned = eio.cloneSelection(state.ui.selectedBodies, world)
            state.ui.selectedBodies = cloned
        end
        nextRow()

        if ui.button(x, y, 260, 'destroy') then
            for i = #state.ui.selectedBodies, 1, -1 do
                snap.destroySnapJointAboutBody(state.ui.selectedBodies[i].body)
                objectManager.destroyBody(state.ui.selectedBodies[i].body)
            end

            state.ui.selectedBodies = nil
        end
        nextRow()

        if state.ui.selectedBodies and #state.ui.selectedBodies > 0 then
            local fb = state.ui.selectedBodies[1].body
            local fixtures = fb:getFixtures()
            local ff = fixtures[1]
            local groupIndex = ff:getGroupIndex()
            local groupIndexSlider = ui.sliderWithInput('groupIndex', x, y, 160, -32768, 32767, groupIndex)
            ui.label(x, y, ' groupid')
            if groupIndexSlider then
                local value = math.floor(groupIndexSlider)
                local count = 0
                for i = 1, #state.ui.selectedBodies do
                    local b = state.ui.selectedBodies[i].body
                    local fixtures = b:getFixtures()
                    for j = 1, #fixtures do
                        fixtures[j]:setGroupIndex(value)
                        count = count + 1
                    end
                end
            end
        end
        -- end
        nextRow()
    end)
end

local accordionStatesSO = {
    tags = false,
    position = false,
    transform = true,
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
        local body = state.ui.selectedObj.body
        -- local angleDegrees = body:getAngle() * 180 / math.pi
        local myID = state.ui.selectedObj.id

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
            --print(state.ui.selectedObj)
            state.ui.selectedBodies = { state.ui.selectedObj }
            local cloned = eio.cloneSelection(state.ui.selectedBodies, world)
            state.ui.selectedBodies = cloned
            state.ui.selectedObj = nil
        end

        if ui.button(x + 120, y, 140, 'destroy') then
            snap.destroySnapJointAboutBody(body)
            objectManager.destroyBody(body)
            state.ui.selectedObj = nil
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
        if (state.ui.lastSelectedBody ~= body) then
            dirtyBodyChange = true
            state.ui.lastSelectedBody = body
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
            if false then
                drawAccordion("tags", function(clicked)
                    local w = love.graphics.getFont():getWidth('straight') + 20
                    -- ui.button(x, y, w, 'straight')
                    ui.toggleButton(x, y, w, BUTTON_HEIGHT, 'straight', 'straight', false)
                    nextRow()
                end)
                nextRow()
            end
            drawAccordion("position", function(clicked)
                nextRow()
                local value = thing.body:getX()
                local numericInputText, dirty = ui.textinput(myID .. 'x', x, y, 120, BUTTON_HEIGHT, ".", "" .. value,
                    true,
                    clicked or not state.world.paused or state.ui.draggingObj)
                if hadBeenDraggingObj then
                    dirty = true
                end
                if (dirty) then
                    local numericPosX = tonumber(numericInputText)
                    if numericPosX then
                        print('setting x')
                        thing.body:setX(numericPosX)
                    else
                        -- Handle invalid input, e.g., reset to previous value or show an error
                        print("Invalid X position input!")
                    end
                end
                local value = thing.body:getY()
                local numericInputText, dirty = ui.textinput(myID .. 'y', x + 140, y, 120, BUTTON_HEIGHT, ".",
                    "" .. value, true,
                    clicked or not state.world.paused or state.ui.draggingObj)
                if hadBeenDraggingObj then
                    dirty = true
                end
                if (dirty) then
                    local numericPosY = tonumber(numericInputText)
                    if numericPosY then
                        print('setting y')
                        thing.body:setY(numericPosY)
                    else
                        -- Handle invalid input, e.g., reset to previous value or show an error
                        print("Invalid Y position input!")
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
                ui.label(x, y, ' angle')


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

            drawAccordion("transform", function(clicked)
                nextRow()

                if ui.button(x, y, 120, 'flipX') then
                    state.ui.selectedObj = objectManager.flipThing(thing, 'x', true)
                    dirtyBodyChange = true
                end
                if ui.button(x + 140, y, 120, 'flipY') then
                    state.ui.selectedObj = objectManager.flipThing(thing, 'y', true)
                    dirtyBodyChange = true
                end


                nextRow()
                if shapeType == 'circle' then
                    -- Show radius control for circles


                    local newRadius = ui.sliderWithInput(myID .. ' radius', x, y, ROW_WIDTH, 1, 200, thing.radius)
                    ui.label(x, y, ' radius')
                    if newRadius and newRadius ~= thing.radius then
                        state.ui.selectedObj = objectManager.recreateThingFromBody(body,
                            { shapeType = "circle", radius = newRadius })
                        state.ui.lastUsedRadius = newRadius
                        body = state.ui.selectedObj.body
                    end
                elseif shapeType == 'rectangle' or shapeType == 'itriangle' then
                    -- Show width and height controls for these shapes


                    local newWidth = ui.sliderWithInput(myID .. ' width', x, y, ROW_WIDTH, 1, 800, thing.width)
                    ui.label(x, y, ' width')
                    nextRow()

                    local newHeight = ui.sliderWithInput(myID .. ' height', x, y, ROW_WIDTH, 1, 800, thing.height)
                    ui.label(x, y, ' height')

                    if (newWidth and newWidth ~= thing.width) or (newHeight and newHeight ~= thing.height) then
                        state.ui.lastUsedWidth = newWidth
                        state.ui.lastUsedHeight = newHeight
                        state.ui.selectedObj = objectManager.recreateThingFromBody(body, {
                            shapeType = shapeType,
                            width = newWidth or thing.width,
                            height = newHeight or thing.height,
                        })
                        body = state.ui.selectedObj.body
                    end
                elseif shapeType == 'torso' then
                    local newWidth = ui.sliderWithInput(myID .. ' width', x, y, ROW_WIDTH, 1, 800, thing.width)
                    ui.label(x, y, ' width')
                    nextRow()

                    local newWidth2 = ui.sliderWithInput(myID .. ' width2', x, y, ROW_WIDTH, 1, 800, thing.width2)
                    ui.label(x, y, ' width2')
                    nextRow()

                    local newWidth3 = ui.sliderWithInput(myID .. ' width3', x, y, ROW_WIDTH, 1, 800, thing.width3)
                    ui.label(x, y, ' width3')
                    nextRow()

                    local newHeight = ui.sliderWithInput(myID .. ' height', x, y, ROW_WIDTH, 1, 800, thing.height)
                    ui.label(x, y, ' height')
                    nextRow()
                    local newHeight2 = ui.sliderWithInput(myID .. ' height2', x, y, ROW_WIDTH, 1, 800, thing.height2)
                    ui.label(x, y, ' height2')
                    nextRow()
                    local newHeight3 = ui.sliderWithInput(myID .. ' height3', x, y, ROW_WIDTH, 1, 800, thing.height3)
                    ui.label(x, y, ' height3')
                    nextRow()
                    local newHeight4 = ui.sliderWithInput(myID .. ' height4', x, y, ROW_WIDTH, 1, 800, thing.height4)
                    ui.label(x, y, ' height4')
                    nextRow()

                    if (newWidth and newWidth ~= thing.width) or
                        (newWidth2 and newWidth2 ~= thing.width2) or
                        (newWidth3 and newWidth3 ~= thing.width3) or
                        (newHeight and newHeight ~= thing.height) or
                        (newHeight2 and newHeight2 ~= thing.height2) or
                        (newHeight3 and newHeight3 ~= thing.height3) or
                        (newHeight4 and newHeight4 ~= thing.height4) then
                        state.ui.lastUsedWidth = newWidth
                        state.ui.lastUsedWidth2 = newWidth2
                        state.ui.lastUsedWidth3 = newWidth3
                        state.ui.lastUsedHeight = newHeight
                        state.ui.lastUsedHeight2 = newHeight2
                        state.ui.lastUsedHeight3 = newHeight3
                        state.ui.lastUsedHeight4 = newHeight4

                        state.ui.selectedObj = objectManager.recreateThingFromBody(body, {
                            shapeType = shapeType,
                            width = newWidth or thing.width,
                            width2 = newWidth2 or thing.width2,
                            width3 = newWidth3 or thing.width3,
                            height = newHeight or thing.height,
                            height2 = newHeight2 or thing.height2,
                            height3 = newHeight3 or thing.height3,
                            height4 = newHeight4 or thing.height4,
                        })
                        body = state.ui.selectedObj.body
                    end
                elseif shapeType == 'trapezium' or shapeType == 'capsule' then
                    -- Show width and height controls for these shapes


                    local newWidth = ui.sliderWithInput(myID .. ' width', x, y, ROW_WIDTH, 1, 800, thing.width)
                    ui.label(x, y, ' width')
                    nextRow()

                    local newWidth2 = ui.sliderWithInput(myID .. ' width2', x, y, ROW_WIDTH, 1, 800, (thing.width2 or 5))
                    ui.label(x, y, ' width2')
                    nextRow()

                    local newHeight = ui.sliderWithInput(myID .. ' height', x, y, ROW_WIDTH, 1, 800, thing.height)
                    ui.label(x, y, ' height')

                    if (newWidth and newWidth ~= thing.width) or (newWidth2 and newWidth2 ~= thing.width2) or (newHeight and newHeight ~= thing.height) then
                        state.ui.lastUsedWidth2 = newWidth2
                        state.ui.lastUsedWidth = newWidth
                        state.ui.lastUsedHeight = newHeight
                        state.ui.selectedObj = objectManager.recreateThingFromBody(body, {
                            shapeType = shapeType,
                            width = newWidth or thing.width,
                            width2 = newWidth2 or thing.width2,

                            height = newHeight or thing.height,
                        })
                        body = state.ui.selectedObj.body
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
                            state.ui.selectedObj = objectManager.recreateThingFromBody(body,
                                { shapeType = shapeType, radius = newRadius })
                            state.ui.lastUsedRadius = newRadius
                            body = state.ui.selectedObj.body
                        end
                    else
                        -- No UI controls for custom or unsupported shapes
                        --ui.label(x, y, 'custom')
                        if ui.button(x, y, 260, state.ui.polyLockedVerts and 'verts locked' or 'verts unlocked') then
                            state.ui.polyLockedVerts = not state.ui.polyLockedVerts
                            if state.ui.polyLockedVerts == false then
                                state.ui.polyTempVerts = utils.shallowCopy(state.ui.selectedObj.vertices)
                                local cx, cy = mathutils.computeCentroid(state.ui.selectedObj.vertices)
                                state.ui.polyCentroid = { x = cx, y = cy }
                            else
                                state.ui.polyTempVerts = nil
                                state.ui.polyCentroid = nil
                            end
                        end
                    end
                end

                nextRow()
            end)
            --nextRow()

            -- drawAccordion("textures", function(clicked)
            --     nextRow()
            --     ui.label(x, y, 'FG / BG / hex')
            --     nextRow()
            --     local dirty, checked = ui.checkbox(x, y, thing.textures.bgEnabled, '')
            --     if dirty then
            --         thing.textures.bgEnabled = not thing.textures.bgEnabled
            --     end
            --     local bgURL = ui.textinput(myID .. ' bgURL', x + 40, y, 220, 40, "", thing.textures.bgURL)
            --     if bgURL and bgURL ~= thing.textures.bgURL then
            --         thing.textures.bgURL = bgURL
            --     end
            --     nextRow()

            --     local paletteShow = ui.button(x, y, 40, 'p', 40)
            --     if paletteShow then
            --         if state.ui.showPalette then
            --             state.ui.showPalette = nil
            --             state.ui.showPaletteFunc = nil
            --         else
            --             state.ui.showPalette = true
            --             state.ui.showPaletteFunc = function(color)
            --                 thing.textures.bgHex = color
            --                 BGcolorHasChangedViaPalette = true
            --             end
            --         end
            --     end
            --     --if not state.ui.showPalette then
            --     --_id, x, y, width, height, placeholder, currentText, isNumeric, reparse

            --     local bgHex = ui.textinput(myID .. ' bgHex', x + 50, y, 210, 40, "", thing.textures.bgHex, false,
            --         BGcolorHasChangedViaPalette)
            --     if BGcolorHasChangedViaPalette then
            --         BGcolorHasChangedViaPalette = false
            --     end
            --     if bgHex and bgHex ~= thing.textures.bgHex then
            --         thing.textures.bgHex = bgHex
            --     end
            --     --end

            --     nextRow()
            --     local dirty, checked = ui.checkbox(x, y, thing.textures.fgEnabled, '')
            --     if dirty then
            --         thing.textures.fgEnabled = not thing.textures.fgEnabled
            --     end
            --     local fgURL = ui.textinput(myID .. ' fgURL', x + 40, y, 220, 40, "", thing.textures.fgURL)
            --     if fgURL and fgURL ~= thing.textures.fgURL then
            --         --local oldUD = utils.shallowCopy(state.ui.selectedSFixture:getUserData())
            --         -- oldUD.label = newLabel
            --         -- state.ui.selectedSFixture:setUserData(oldUD)
            --         --local info = love.filesystem.getInfo('textures/' .. thing.textures.bgURL)
            --         --if (info and info.type == 'file') then else thing.textures.bgEnabled = false end
            --         thing.textures.fgURL = fgURL
            --     end


            --     nextRow()
            --     local fgHex = ui.textinput(myID .. ' fgHex', x + 50, y, 210, 40, "", thing.textures.fgHex, false,
            --         FGcolorHasChangedViaPalette)
            --     if FGcolorHasChangedViaPalette then
            --         FGcolorHasChangedViaPalette = false
            --     end
            --     if fgHex and fgHex ~= thing.textures.fgHex then
            --         thing.textures.fgHex = fgHex
            --     end
            --     local paletteShow = ui.button(x, y, 40, 'p', 40)
            --     if paletteShow then
            --         if state.ui.showPalette then
            --             state.ui.showPalette = nil
            --             state.ui.showPaletteFunc = nil
            --             --print(thing.textures.bgHex)
            --         else
            --             state.ui.showPalette = true
            --             state.ui.showPaletteFunc = function(color)
            --                 thing.textures.fgHex = color
            --                 FGcolorHasChangedViaPalette = true
            --             end
            --         end
            --     end


            --     nextRow()
            -- end)

            nextRow()

            drawAccordion("physics", function()
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
                    nextRow()


                    local fb = thing.body
                    local fixtures = fb:getFixtures()
                    local ff = fixtures[1]
                    local groupIndex = ff:getGroupIndex()
                    local groupIndexSlider = ui.sliderWithInput(myID .. 'groupIndex', x, y, 160, -32768, 32767,
                        groupIndex)
                    ui.label(x, y, ' groupid')
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
                end
                nextRow()
            end)
            nextRow()
            drawAccordion("motion", function()
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
                ui.label(x, y, ' ang-vel')

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
                    drawAccordion("joints", function()
                        for _, joint in ipairs(attachedJoints) do
                            -- Display joint type and unique identifier for identification
                            local jointType = joint:getType()
                            local jointID = tostring(joint)

                            if (jointType ~= 'mouse') then
                                -- Display joint button
                                x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT - 10)
                                local jointLabel = string.format("%s %s", jointType,
                                    string.sub(joint:getUserData().id, 1, 3))

                                if ui.button(x, y, 260, jointLabel) then
                                    state.ui.selectedJoint = joint
                                    --  state.ui.selectedObj = nil
                                end

                                local clicked, _, _, isHover = ui.button(x, y, 260, jointLabel)

                                if clicked then
                                    state.ui.selectedJoint = joint
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
                drawAccordion("sfixtures", function()
                    for i = 1, index do
                        nextRow()
                        local fixLabel = string.format("%s %s", 'sf',
                            string.sub(myfixtures[i]:getUserData().id, 1, 3))
                        local clicked, _, _, isHover = ui.button(x, y, 260, fixLabel)

                        if clicked then
                            state.ui.selectedJoint = nil
                            state.ui.selectedObj = nil
                            state.ui.selectedSFixture = myfixtures[i]
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

return lib

```

src/recorder.lua
```lua
local box2dPointerJoints = require 'src.box2d-pointerjoints'
local registry = require 'src.registry'
local utils = require 'src.utils'
local state = require 'src.state'

function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

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

    print('started recording on layer', self.activeLayer, layerIndex)
end

function recorder:stopRecording()
    self.isRecording = false
    self.recordings[self.activeLayer] = utils.deepCopy(self.events)
    self.events = {}
    -- self.recordings.layerindex = self.activeLayer
    -- print(#self.recordings, #self.events)
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
    --print(inspect(data))
    self.recordingMouseJoints[data.pointerID .. data.bodyID .. self.activeLayer] = event
    table.insert(self.events, event)
end

function recorder:recordMouseJointFinish(pointerid, bodyid)
    -- print(inspect(id))
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
            --print(created)
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
            print(inspect(event))
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

src/registry.lua
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
        print('no s joint to unregister here', id)
    end
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
        print('no s fixture to unregister here')
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

src/script.lua
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
    for _, body in pairs(world:getBodies()) do
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
    world                    = world,
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
    if sceneScript and sceneScript[method] then
        sceneScript[method](...)
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
        print('error: ' .. err)
    else
        if not chunk then
            error("Error loading script: " .. err)
        end

        local success, err = pcall(chunk)
        if not success then
            error("Error executing script: " .. err)
        end

        print("Script loaded: " .. filePath)
        if success then
            return chunk
        end
    end

    return function()
        local s = {}
        s.onStart = function() print("error: " .. err .. "\nError in script: " .. filePath) end
        s.foundError = err -- utils.insertNewlines(err, 100)
        return s
    end
end

return script

```

src/selection-rect.lua
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
        print('NOT HANDLING THIS SHAPE RectangleShape')
        -- Handle RectangleShape if using a custom shape type
        -- Love2D does not have a native RectangleShape; rectangles are typically PolygonShapes
    else
        print('NOT HANDLING THIS SHAPE ??')
    end

    return points
end



function lib.draw(selection)
    local x, y = love.mouse:getPosition()
    local tlx = math.min(selection.x, x)
    local tly = math.min(selection.y, y)
    local brx = math.max(selection.x, x)
    local bry = math.max(selection.y, y)
    -- print(inspect(selection), x, y)
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

src/shapes.lua
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
        print("Error in decompose_complex_poly: " .. err)
        return nil -- Exit early if decomposition fails
    end

    for i = 1, #result do
        local success, tris = pcall(love.math.triangulate, result[i])
        if success then
            utils.tableConcat(triangles, tris)
        else
            print("Failed to triangulate part of the polygon: " .. tris)
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
                print("Error in decompose_complex_poly: " .. err)
                return nil -- Exit early if decomposition fails
            end

            for i = 1, #result do
                local success, tris = pcall(love.math.triangulate, result[i])
                if success then
                    utils.tableConcat(triangles, tris)
                else
                    print("Failed to triangulate part of the polygon: " .. tris)
                end
            end
        else -- this is a bit of a nono, its no longer really in use and doenst fix all werid cases. faster though.
            local success, result = pcall(love.math.triangulate, polygon)
            if success then
                triangles = result
            else
                print("Failed to triangulate polygon: " .. result)
                return nil -- Exit early if triangulation fails
            end
        end

        if #triangles == 0 then
            print("No valid triangles were created.")
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
                print("Failed to create shape for triangle: " .. shape)
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

--     if not success then
--         print("Error in decompose_complex_poly: " .. err)
--         return nil -- Exit early if decomposition fails
--     end
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
        vertices = capsuleXY(settings.width, settings.height, settings.width / (settings.width2 or 1), 0, 0)
        table.insert(shapesList, love.physics.newPolygonShape(vertices))
    elseif shapeType == 'trapezium' then
        vertices = makeTrapezium(settings.width, settings.width2 or (settings.width * 1.2), settings.height, 0, 0)
        table.insert(shapesList, love.physics.newPolygonShape(vertices))
    elseif shapeType == 'itriangle' then
        vertices = makeITriangle(settings.width, settings.height, 0, 0)
        table.insert(shapesList, love.physics.newPolygonShape(vertices))
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
                --print(inspect(polygon))
                shapesList = makeShapeListFromPolygon(polygon) or {}
                --print('shapelist size:', #shapesList)
                vertices = polygon
                --print('numvertices', #vertices)
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

src/snap.lua
```lua
-- general usage snap logic
--
local uuid = require 'src.uuid'
local utils = require 'src.utils'
local box2dPointerJoints = require 'src.box2d-pointerjoints'
local mathutils = require 'src.math-utils'

local snapFixtures = {}
local snapDistance = 40            -- Maximum distance to snap
local mySnapJoints = {}            -- Store created joints
local jointBreakThreshold = 100000 -- Force threshold for breaking the joint
local cooldownTime = .5            -- Time in seconds to prevent immediate reconnection
local cooldownList = {}            -- Table to track cooldown for each snap point
local onlyConnectWhenInteracted = true
local onlyBreakWhenInteracted = true

local lib = {}

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
    -- print(id)
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
    -- print(#mySnapJoints)
    --for k, v in pairs(registry.joints) do
    --    print(k, v:isDestroyed())
    --end
    --for i = #mySnapJoints, 1, -1 do
    --    print(i, mySnapJoints[i]:isDestroyed())
    --end


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

                --print('todo remove joint from registry')
            end
        end
    end
end

local function checkForSnaps(interacted, snapFixtures)
    -- print(#interacted, #snapFixtures)
    local currentTime = love.timer.getTime()

    for i = 1, #snapFixtures do
        local it1 = snapFixtures[i]:getUserData().extra

        if it1.to == nil and not isInCooldown(it1.fixture, currentTime) then -- else this snap point is already connected and it cannot be connected more then once
            local body1 = it1.at
            if not body1 then
                print('body1 is nil!    ')
                print(inspect(it1))
            end
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
    --print(count)
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

            if ud and utils.sanitizeString(ud.label) == 'snap' then
                local centroid = { mathutils.getCenterOfPoints({ v:getShape():getPoints() }) }
                local ud = v:getUserData()
                --print(count, ud.extra, v:getBody(), k)
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

            --print(#snapFixtures)
            -- Find all snap points associated with bodyA and bodyB
            for i = 1, #snapFixtures do
                local extra = snapFixtures[i]:getUserData().extra
                local atId = extra.at:getUserData().thing.id
                --print(atId, id1, id2)
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
    -- print('should reset snapjoints array', #mySnapJoints)
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
    --print('should remove things from snapjoints array maybe')
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

src/state.lua
```lua
local state = {}

state.ui = {
    lastUsedRadius = 20,
    lastUsedWidth = 40,
    lastUsedWidth2 = 5,
    lastUsedHeight = 40,
    lastUsedHeight2 = 40,

    showGrid = false,
    radiusOfNextSpawn = 100,
    nextType = 'dynamic',
    addShapeOpened = false,
    addJointOpened = false,

    worldSettingsOpened = false,
    maybeHideSelectedPanel = false,

    showTexFixtureDim = false,

    selectedJoint = nil,
    setOffsetAFunc = nil,
    setOffsetBFunc = nil,
    setUpdateSFixturePosFunc = nil,
    selectedSFixture = nil,
    selectedObj = nil,
    draggingObj = nil,
    offsetDragging = { nil, nil },
    worldText = '',
    jointCreationMode = nil,
    jointUpdateMode = nil,
    drawFreePoly = false,
    drawClickPoly = false,
    capturingPoly = false,

    polyDragIdx = 0,
    polyLockedVerts = true,
    polyTempVerts = nil, -- used when dragging a vertex
    polyCentroid = nil,
    polyVerts = {},

    texFixtureDragIdx = 0,
    texFixtureLockedVerts = true,
    texFixtureVerts = {},

    showPalette = nil,
    minPointDistance = 50, -- Default minimum distance
    lastPolyPt = nil,
    lastSelectedBody = nil,
    selectedBodies = nil,
    lastSelectedJoint = nil,
    saveDialogOpened = false,
    quitDialogOpened = false,
    saveName = 'untitled',
    recordingPanelOpened = false,
}

state.world = {
    debugDrawMode = true,
    debugAlpha = 1,
    profiling = false,
    meter = 100,
    isRecordingPointers = false,
    paused = true,
    gravity = 9.80,
    mouseForce = 500000,
    mouseDamping = 0.5,
    speedMultiplier = 1.0,
    softbodies = {},
    playWithSoftbodies = false

}



return state

```

src/ui-all.lua
```lua
-- ui-all.lua
local ui = {}

require('src.ui-textinput')(ui)

local creamy = { 245 / 255, 245 / 255, 220 / 255 } --#F5F5DC Creamy White:
local orange = { 242 / 255, 133 / 255, 0 }
-- Theme Configuration
local theme  = {
    lineHeight = 30,
    button = {
        default = { 188 / 255, 175 / 255, 156 / 255 },   -- Default fill color
        hover = { 105 / 255, 98 / 255, 109 / 255 },      -- Hover fill color
        pressed = { 217 / 255, 189 / 255, 197 / 255 },   -- Pressed fill color
        outline = creamy,                                -- Outline color
        text_default = creamy,                           -- Default text color
        text_hover = { 244 / 255, 189 / 255, 94 / 255 }, -- Text color on hover
        radius = 2,
        height = 30
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
        height = 30
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
function ui.init(font)
    ui.nextID = 1               -- Unique ID counter
    ui.dragOffset = { x = 0, y = 0 }
    ui.focusedTextInputID = nil -- Tracks the currently focused TextInput
    ui.textInputs = {}
    ui.font = font or love.graphics.getFont()
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
    --print(valueHasChangedViaSlider, changed, dirty)
    if returnValue then
        return returnValue
    end
end

--- Draws a panel with optional label and content.
function ui.panel(x, y, width, height, label, drawFunc)
    -- Draw panel background
    --
    --
    local rxry = 0
    if theme.button.radius > 0 then
        rxry = math.min(width / 6, height / 6) / theme.button.radius
    end
    love.graphics.setColor(theme.panel.background)
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
        love.graphics.setScissor(x, y, width, height)
    end
    -- Call the provided draw function to render UI elements inside the panel
    if drawFunc then
        drawFunc()
    end

    -- Disable scissor
    love.graphics.setScissor()

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
    local sliderID = ui.generateID()
    if (extraId) then
        sliderID = sliderID .. extraId
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
    --  love.graphics.print(text, x, y)
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

src/ui-textinput.lua
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
        --print(id, currentText)
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
            --  print(love.timer.getDelta())
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

src/utils.lua
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
    print(table.concat(t, " "))
end

-- Utility function to get the difference between two paths
function lib.getPathDifference(base, full)
    -- Ensure both inputs are strings
    if type(base) ~= "string" or type(full) ~= "string" then
        error("Both base and full paths must be strings")
    end

    -- If the paths are identical, return an empty string
    if full == base then
        return ""
    end

    -- Check if the base path is a prefix of the full path
    if full:sub(1, #base) == base then
        -- Ensure that the base path ends at a directory boundary
        -- i.e., the next character should be '/' or the full path should end here
        local nextChar = full:sub(#base + 1, #base + 1)
        if nextChar == "/" then
            -- Extract the remaining part of the path
            return full:sub(#base + 1)
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
        print(key)
    end
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

-- Function to compare two tables for equality (assuming they are arrays of numbers)
function lib.tablesEqualNumbers(t1, t2)
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

    return true
end

return lib

```

src/uuid.lua
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


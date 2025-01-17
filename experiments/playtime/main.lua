-- main.lua

-- TODO
-- build a ui where you can add multiple tags..
-- have group/collection concept
-- have a marker/tag/behaviour concept.

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
local box2dPointerJoints = require 'src.box2d-pointerjoints'
local camera = require 'src.camera'
local cam = camera.getInstance()
local fixtures = require 'src.fixtures'
snap = require 'src.snap'

registry = require 'src.registry'
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
local TICKRATE = 1 / 60

-- todo what todo with this?!!!
--local snapPoints = {}

function love.load(args)
    local font = love.graphics.newFont('assets/cooper_bold_bt.ttf', 30)
    love.keyboard.setKeyRepeat(true)
    love.graphics.setFont(font)

    ui.init(font)

    uiState = {
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
        quitDialogOpened = false,
        saveName = 'untitled'
    }

    worldState = {
        debugDrawMode = true,
        profiling = false,
        meter = 100,
        paused = true,
        gravity = 9.80,
        mouseForce = 500000,
        mouseDamping = 0.5,
        speedMultiplier = 1.0
    }

    tags = {
        'straight',
        'snap',
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
    softbodies = {}
    playWithSoftbodies = false
    if playWithSoftbodies then
        local b = blob.softbody(world, 500, 0, 102, 1, 1)
        b:setFrequency(3)
        b:setDamping(0.1)
        --b:setFriction(1)

        table.insert(softbodies, b)
        local points = {
            0, 500, 800, 500,
            800, 800, 0, 800
        }
        local b = blob.softsurface(world, points, 120, "dynamic")
        table.insert(softbodies, b)
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
    --  loadScriptAndScene('water')
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
    script.setEnv({ worldState = worldState, world = world })
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

        snap.update(scaled_dt)
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
    if worldState.paused then
        love.graphics.setColor({ 244 / 255, 164 / 255, 97 / 255 })
    else
        love.graphics.setColor({ 245 /
        255, 245 / 255, 220 / 255 })
    end

    love.graphics.rectangle('line', 10, 10, w - 20, h - 20, 20, 20)
    love.graphics.setColor(1, 1, 1)

    -- "Add Shape" Button
    if ui.button(20, 20, 200, 'add shape') then
        uiState.addShapeOpened = not uiState.addShapeOpened
    end

    if uiState.addShapeOpened then
        playtimeui.drawAddShapeUI()
    end

    -- "Add Joint" Button
    if ui.button(230, 20, 200, 'add joint') then
        uiState.addJointOpened = not uiState.addJointOpened
    end

    if uiState.addJointOpened then
        playtimeui.drawAddJointUI()
    end

    -- "World Settings" Button
    if ui.button(440, 20, 200, 'settings') then
        uiState.worldSettingsOpened = not uiState.worldSettingsOpened
    end

    if uiState.worldSettingsOpened then
        playtimeui.drawWorldSettingsUI()
    end

    -- Play/Pause Button
    if ui.button(650, 20, 150, worldState.paused and 'play' or 'pause') then
        worldState.paused = not worldState.paused
    end

    if sceneScript and sceneScript.onStart then
        if ui.button(920, 20, 50, 'R') then
            -- todo actually reread the file itself!
            loadAndRunScript(scriptPath)
            sceneScript.onStart()
        end
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
            x, y = ui.nextLayoutPosition(layout, ROW_WIDTH, BUTTON_HEIGHT)
            if ui.button(x, y, 260, 'soft-surface') then
                finalizePolygonAsSoftSurface()
            end
        end)
    end

    if uiState.selectedObj and not uiState.selectedJoint and not uiState.selectedSFixture then
        playtimeui.drawUpdateSelectedObjectUI()
    end

    if uiState.selectedBodies and #uiState.selectedBodies > 0 then
        playtimeui.drawSelectedBodiesUI()
    end

    if uiState.jointCreationMode and uiState.jointCreationMode.body1 and uiState.jointCreationMode.body2 then
        playtimeui.doJointCreateUI(uiState, 500, 100, 400, 150)
    end

    if uiState.selectedSFixture then
        playtimeui.drawSelectedSFixture()
    end

    if uiState.selectedObj and uiState.selectedJoint then
        -- (w - panelWidth - 20, 20, panelWidth, h - 40
        playtimeui.doJointUpdateUI(uiState, uiState.selectedJoint, w - PANEL_WIDTH - 20, 20, PANEL_WIDTH, h - 40)
    end

    if uiState.setOffsetAFunc or uiState.setOffsetBFunc or uiState.setUpdateSFixturePosFunc then
        ui.panel(500, 100, 300, 60, '• click point ∆', function()
        end)
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

    if uiState.quitDialogOpened then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle('fill', 0, 0, w, h)
        love.graphics.setColor(1, 1, 1)
        ui.panel(300, 300, w - 600, h - 600, '»»» really quit ? «««', function()
            ui.label(400, 400, '[esc] to quit')
            ui.label(400, 450, '[space] to cancel')
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

    box2dDraw.drawWorld(world, worldState.debugDrawMode)

    script.call('draw')

    if uiState.selectedSFixture and not uiState.selectedSFixture:isDestroyed() then
        local body = uiState.selectedSFixture:getBody()
        local centroid = fixtures.getCentroidOfFixture(body, uiState.selectedSFixture)
        local x2, y2 = body:getWorldPoint(centroid[1], centroid[2])
        love.graphics.circle('line', x2, y2, 3)
    end

    if uiState.selectedJoint and not uiState.selectedJoint:isDestroyed() then
        box2dDraw.drawJointAnchors(uiState.selectedJoint)
    end

    local lw = love.graphics.getLineWidth()
    for i, v in ipairs(softbodies) do
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
    if uiState.polyTempVerts and uiState.selectedObj then
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
        if (uiState.selectedSFixture) then
            local body = uiState.selectedSFixture:getBody()
            local thing = body:getUserData().thing

            uiState.selectedObj = thing
            uiState.selectedSFixture = nil
            uiState.maybeHideSelectedPanel = false
        elseif (uiState.selectedJoint) then
            uiState.selectedJoint = nil
            uiState.maybeHideSelectedPanel = false
        else
            if not (ui.activeElementID or ui.focusedTextInputID) then
                uiState.selectedObj = nil
                uiState.selectedSFixture = nil
                uiState.selectedJoint = nil
            end
            uiState.maybeHideSelectedPanel = false
            uiState.polyTempVerts = nil
            uiState.polyLockedVerts = true
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

function finalizePolygonAsSoftSurface()
    if #uiState.polyVerts >= 6 then
        local points = uiState.polyVerts
        local b = blob.softsurface(world, points, 120, "dynamic")
        table.insert(softbodies, b)
        b:setJointFrequency(10)
        b:setJointDamping(10)
    end
    print('blob surface wanted instead?')
    -- Reset the drawing state
    uiState.drawClickPoly = false
    uiState.drawFreePoly = false
    uiState.capturingPoly = false
    uiState.polyVerts = {}
    uiState.lastPolyPt = nil
end

function finalizePolygon()
    if #uiState.polyVerts >= 6 then
        local cx, cy = mathutils.computeCentroid(uiState.polyVerts)
        --local cx, cy = mathutils.getCenterOfPoints(uiState.polyVerts)
        local settings = { x = cx, y = cy, bodyType = uiState.nextType, vertices = uiState.polyVerts }
        -- objectManager.addThing('custom', cx, cy, uiState.nextType, nil, nil, nil, nil, '', uiState.polyVerts)
        objectManager.addThing('custom', settings)
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
        local dx2, dy2 = mathutils.rotatePoint(dx, dy, 0, 0, body:getAngle())
        local oldX, oldY = body:getPosition()
        --print(dx)
        body:setPosition(oldX + dx2, oldY + dy2)
        uiState.selectedObj = objectManager.recreateThingFromBody(body,
            { optionalVertices = uiState.polyTempVerts })

        uiState.polyTempVerts = utils.shallowCopy(uiState.selectedObj.vertices)
        -- uiState.selectedObj.vertices = uiState.polyTempVerts
        uiState.polyCentroid = { x = nx, y = ny }
    end
end

local function insertCustomPolygonVertex(x, y)
    local obj = uiState.selectedObj
    if obj then
        local offx, offy = obj.body:getPosition()
        local px, py = mathutils.worldToLocal(x - offx, y - offy, obj.body:getAngle(), uiState.polyCentroid.x,
            uiState.polyCentroid.y)
        -- Find the closest edge index
        local insertAfterVertexIndex = mathutils.findClosestEdge(uiState.polyTempVerts, px, py)
        mathutils.insertValuesAt(uiState.polyTempVerts, insertAfterVertexIndex * 2 + 1, px, py)
    end
end

-- Function to remove a custom polygon vertex based on mouse click
local function removeCustomPolygonVertex(x, y)
    -- Step 1: Convert world coordinates to local coordinates

    local obj = uiState.selectedObj
    if obj then
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
end

function love.keypressed(key)
    ui.handleKeyPress(key)
    if key == 'escape' then
        if uiState.quitDialogOpened == true then
            love.event.quit()
        end
        if uiState.quitDialogOpened == false then
            uiState.quitDialogOpened = true
        end
    end
    if key == 'space' then
        if uiState.quitDialogOpened == true then
            uiState.quitDialogOpened = false
        else
            worldState.paused = not worldState.paused
        end
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
        if uiState.selectedJoint or uiState.selectedObj or uiState.selectedSFixture or uiState.selectedBodies or uiState.drawClickPoly then
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
        if (uiState.setUpdateSFixturePosFunc) then
            uiState.selectedSFixture = uiState.setUpdateSFixturePosFunc(cx, cy)
            uiState.setUpdateSFixturePosFunc = nil
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


        local b = blob.softbody(world, cx, cy, 102, 1, 1)
        b:setFrequency(3)
        b:setDamping(0.1)

        table.insert(softbodies, b)
    end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    --handlePointer(x, y, id, 'pressed')
    if uiState.drawFreePoly then
        -- Start capturing mouse movement
        uiState.capturingPoly = true
        uiState.polyVerts = {}
        uiState.lastPolyPt = nil
    else
        handlePointer(x, y, id, 'pressed')
    end
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
--

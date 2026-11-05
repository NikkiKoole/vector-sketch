-- Sweep: the editor's tool modes (src/modes.lua) and drags, driven by the mouse through
-- src/input-manager.lua as a person would: in every scene, each tool started the way its panel
-- or the tool rail starts it, then its clicks and drags. Run whole, and cut off halfway by
-- something else: the thing it works on destroyed or rebuilt from its panel, another tool
-- picked, the tool switched off, play mode on and off, the room loaded again. Then a next click
-- on a body and one on nothing. Every frame is the game's: the world, the editor overlay and
-- the panels (playtime-ui.drawUI). DEEPER-ISSUES 4: no rules for entering or leaving a mode.
-- Checks: nothing throws; after the cut, no tool left on with what it works on gone ('stale');
-- the sweeps' world checks (sfixtures first, registry) and a save and reload that keeps everything.
-- Problems the scene has untouched are left out.
-- Run: TOOLS_OUT=/some/file.txt love . --specs claudetools/tool-modes_spec.lua  [TOOLS_ONLY=dollhouse]
-- (docs/CODE-COMPLEXITY-2026-11.md, the sweeps)
if not love then return end
local out = os.getenv('TOOLS_OUT')
if not out or out == '' then return end
local only = os.getenv('TOOLS_ONLY')
local MEM = os.getenv('TOOLS_MEM') -- a memory line per run in the report (what grows)

local json = require('vendor.dkjson')
local state = require('src.state')
local registry = require('src.registry')
local sceneLoader = require('src.scene-loader')
local camera = require('src.camera')
local utils = require('src.utils')
local modes = require('src.modes')
local subtypes = require('src.subtypes')
local mathutils = require('src.math-utils')
local ui = require('src.ui.all')
local input = require('src.input-manager')
local playMode = require('src.play-mode')
local pointerJoints = require('src.physics.box2d-pointerjoints')
local box2dDraw = require('src.physics.box2d-draw')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')
local editorRender = require('src.editor-render')
local bodyParams = require('src.body-params')
local jointParams = require('src.joint-params')
local sfixtureParams = require('src.sfixture-params')
local sweep = require('claudetools.sweep')

local alive = sweep.alive
local cam = camera.getInstance()
local playtimeui

-- the mouse, as the editor reads it
local mouse = { x = 600, y = 384, down = {} }
love.mouse.getPosition = function() return mouse.x, mouse.y end
love.mouse.getX = function() return mouse.x end
love.mouse.getY = function() return mouse.y end
love.mouse.isDown = function(...)
    for _, b in ipairs({ ... }) do if mouse.down[b] then return true end end
    return false
end

-- a button to press in the next top prompt ('create', 'finalize'), as a click on it would
local promptAnswer
local realTopPrompt = ui.topPrompt
ui.topPrompt = function(text, buttons, ...)
    local r = realTopPrompt(text, buttons, ...)
    if promptAnswer then
        for _, b in ipairs(buttons or {}) do
            if b == promptAnswer then
                promptAnswer = nil
                return b
            end
        end
    end
    return r
end

local canvas
-- one frame of the game in the editor: input's per-frame work, a step when running, the world,
-- the editor overlay, the panels
local function frame()
    local world = state.physicsWorld
    pointerJoints.handlePointerUpdate(1 / 60, cam)
    if state.interaction.draggingObj then input.handleDraggingObj() end
    if not state.world.paused then world:update(1 / 60) end
    box2dDrawTextured.makeCombinedImages()
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear()
    cam:push()
    box2dDraw.drawWorld(world)
    box2dDrawTextured.drawTexturedWorld(world)
    if not playMode.isOn() then
        editorRender.renderActiveEditorThings()
        editorRender.renderSteinerOverlay()
        editorRender.renderSelectionBox()
    end
    cam:pop()
    if not playMode.isOn() then
        love.graphics.push()
        love.graphics.scale(ui.scale)
        playtimeui.drawUI()
        love.graphics.pop()
    end
    love.graphics.setCanvas()
    -- end the frame, like the game: thousands drawn as one frame ran the GPU out of memory
    -- (Metal 'Insufficient Memory' after 22 scenes; the editor snapshot hit it on the iMac too)
    love.graphics.present()
end

local function moveTo(wx, wy)
    local x, y = cam:getScreenCoordinates(wx, wy)
    local dx, dy = x - mouse.x, y - mouse.y
    mouse.x, mouse.y = x, y
    input.handleMouseMoved(x, y, dx, dy)
end
local function press(wx, wy, button)
    moveTo(wx, wy)
    mouse.down[button or 1] = true
    input.handleMousePressed(mouse.x, mouse.y, button or 1, false)
    frame()
end
local function release(wx, wy, button)
    moveTo(wx, wy)
    mouse.down[button or 1] = nil
    input.handleMouseReleased(mouse.x, mouse.y, button or 1, false)
    frame()
end
local function click(wx, wy, button)
    press(wx, wy, button)
    release(wx, wy, button)
end
local function prompt(answer)
    promptAnswer = answer
    frame()
    promptAnswer = nil
end

-- everything the editor keeps between clicks, back to how a fresh editor has it
local function resetEditor()
    if playMode.isOn() then playMode.exit() end
    state.world.paused = true
    state.currentMode = nil
    state.jointParams = nil
    state.pickAutoRopifyModeHitted = nil
    local sel = state.selection
    sel.selectedObj, sel.selectedJoint, sel.selectedSFixture, sel.selectedBodies = nil, nil, nil, nil
    state.polyEdit.tempVerts, state.polyEdit.centroid, state.polyEdit.lockedVerts = nil, nil, true
    state.polyEdit.dragIdx = 0
    state.texFixtureEdit.tempVerts, state.texFixtureEdit.centroid = nil, nil
    state.texFixtureEdit.lockedVerts, state.texFixtureEdit.dragIdx = true, 0
    local i = state.interaction
    i.draggingObj, i.startSelection, i.capturingPoly = nil, nil, false
    i.polyVerts, i.lastPolyPt = {}, nil
    i.pressMissedEverything, i.pressedOverUI = false, false
    mouse.down = {}
    for _, panel in ipairs({ 'saveDialogOpened', 'quitDialogOpened', 'showPalette', 'addBehavior', 'customBehavior',
        'bgSettingsOpened', 'worldSettingsOpened', 'recordingPanelOpened' }) do
        state.panelVisibility[panel] = false
    end
end

-- ---- what a tool works on, found in the loaded scene (the first by id: the same every run) ----

local function sortedValues(map, keep)
    local ids = {}
    for id, v in pairs(map) do if alive(v) and keep(v) then ids[#ids + 1] = id end end
    table.sort(ids)
    return ids[1] and map[ids[1]]
end
local function anyBody(skipMipo)
    return sortedValues(registry.bodies, function(body)
        local thing = utils.thingOf(body)
        return thing and not (skipMipo and thing.mipoId)
    end)
end
local function sfixtureOf(subtype, needs)
    return sortedValues(registry.sfixtures, function(f)
        local ud = f:getUserData()
        return ud.subtype == subtype and (not needs or needs(ud))
    end)
end
local function anyJoint()
    return sortedValues(registry.joints, function() return true end)
end
local function polygonBody()
    return sortedValues(registry.bodies, function(body)
        local thing = utils.thingOf(body)
        return thing and (thing.shapeType == 'custom' or thing.shapeType == 'ribbon') and thing.vertices
    end)
end
-- two bodies that aren't Mipo parts (a Mipo's parts are too small to tell apart by a click)
local function twoBodies()
    local first = anyBody(true)
    if not first then return nil end
    local second = sortedValues(registry.bodies, function(body)
        local thing = utils.thingOf(body)
        return body ~= first and thing and not thing.mipoId
    end)
    return first, second
end

local function look(x, y) camera.centerCameraOnPosition(x, y, 1200, 768) end
local function far(x, y) return x + 4000, y + 4000 end -- a point with nothing on it
-- a point inside a body: its first collision fixture's centre
local function inside(body)
    for _, f in ipairs(body:getFixtures()) do
        if not f:getUserData() then
            local x1, y1, x2, y2 = f:getBoundingBox()
            return (x1 + x2) / 2, (y1 + y2) / 2
        end
    end
    return body:getPosition()
end
local function selectThing(body) state.selection.selectedObj = utils.thingOf(body) end
local function rowLabelled(rows, label, target)
    for _, row in ipairs(rows) do
        local l = row.label
        if type(l) == 'function' then l = l(target) end
        if l == label or row.key == label then return row end
    end
end

-- ---- the tools: setup() starts it on what it needs (nil: the scene has nothing for it), then
-- steps, each one press / drag / prompt ----

local TOOLS = {}
local function tool(name, setup) TOOLS[#TOOLS + 1] = { name = name, setup = setup } end

for _, side in ipairs({ 'A', 'B' }) do
    tool('joint anchor ' .. side, function()
        local joint = anyJoint()
        if not joint then return nil end
        state.selection.selectedJoint = joint
        local rows = jointParams.byType[joint:getType()] or {}
        local row = rowLabelled(rows, side == 'A' and '∆ anchor' or '∆ anchor B', joint)
        if not row then return nil end
        row.run(nil, joint)
        local bodyA, bodyB = joint:getBodies()
        local x, y = inside(side == 'A' and bodyA or bodyB)
        look(x, y)
        return { function() click(x + 3, y + 3) end, function() frame() end }
    end)
end

tool('position sfixture', function()
    local fixture = sfixtureOf(subtypes.SNAP) or sfixtureOf(subtypes.ANCHOR)
    if not fixture then return nil end
    state.selection.selectedSFixture = fixture
    local row = rowLabelled(sfixtureParams.bySubtype[fixture:getUserData().subtype], '∆ position', fixture)
        or { run = function() modes.set(modes.POSITIONING_SFIXTURE) end }
    row.run(nil, fixture)
    local x, y = inside(fixture:getBody())
    look(x, y)
    return { function() frame() end, function() click(x + 2, y + 2) end }
end)

local function addNodes(subtype, start)
    return function()
        local fixture = sfixtureOf(subtype)
        local joint = anyJoint()
        if not (fixture and joint) then return nil end
        state.selection.selectedSFixture = fixture
        start(fixture)
        local x, y = joint:getAnchors()
        local x2, y2 = inside(fixture:getBody())
        look(x, y)
        return {
            function() click(x, y) end,
            function() click(x2, y2) end,
            function() click(far(x, y)) end, -- nothing near: the tool ends
        }
    end
end
tool('ribbon nodes', addNodes(subtypes.CONNECTED_TEXTURE, function(fixture)
    rowLabelled(sfixtureParams.bySubtype[subtypes.CONNECTED_TEXTURE], 'add node (' ..
        #(fixture:getUserData().extra.nodes or {}) .. ')', fixture).run(nil, fixture)
end))
tool('mesh nodes', addNodes(subtypes.MESHUSERT, function() modes.set(modes.ADD_NODE_MESHUSERT) end))

tool('mesh triangles', function()
    local fixture = sfixtureOf(subtypes.MESHUSERT)
    if not fixture then return nil end
    state.selection.selectedSFixture = fixture
    modes.set(modes.EDIT_MESH_TRIS)
    local x, y = inside(fixture:getBody())
    look(x, y)
    return {
        function() press(x - 20, y - 20) end,
        function() for k = 1, 6 do moveTo(x - 20 + k * 7, y - 20 + k * 7); frame() end end,
        function() release(x + 22, y + 22) end,
    }
end)

tool('steiner points', function()
    local body = polygonBody() or anyBody(true)
    if not body then return nil end
    selectThing(body)
    modes.set(modes.PLACE_STEINER)
    local x, y = inside(body)
    look(x, y)
    return {
        function() click(x, y) end,                   -- a point
        function() press(x, y) end,                   -- grab it
        function() moveTo(x + 4, y + 3); frame() end, -- drag it
        function() release(x + 4, y + 3) end,
        function() click(x + 4, y + 3, 2) end,        -- right-click: gone
    }
end)

tool('polygon corners', function()
    local body = polygonBody()
    if not body then return nil end
    local thing = utils.thingOf(body)
    state.selection.selectedObj = thing
    -- the body panel's 'verts unlocked' (src/ui/body-editor.lua)
    state.polyEdit.lockedVerts = false
    state.polyEdit.tempVerts = utils.shallowCopy(thing.vertices)
    local cx, cy = mathutils.computeCentroid(thing.vertices)
    state.polyEdit.centroid = { x = cx, y = cy }
    local wx, wy = body:getWorldPoint(thing.vertices[1], thing.vertices[2])
    look(wx, wy)
    return {
        function() press(wx, wy) end,
        function() for k = 1, 4 do moveTo(wx + k * 3, wy + k * 2); frame() end end,
        function() release(wx + 12, wy + 8) end,
        function() moveTo(inside(body)); input.handleKeyPressed('i'); frame() end,
        function() input.handleKeyPressed('d'); frame() end,
    }
end)

tool('texture corners', function()
    local fixture = sfixtureOf(subtypes.TEXFIXTURE, function(ud) return ud.extra and ud.extra.vertices end)
    if not fixture then return nil end
    state.selection.selectedSFixture = fixture
    local v = fixture:getUserData().extra.vertices
    state.texFixtureEdit.lockedVerts = false
    state.texFixtureEdit.tempVerts = utils.shallowCopy(v)
    local wx, wy = fixture:getBody():getWorldPoint(v[1], v[2])
    look(wx, wy)
    return {
        function() press(wx, wy) end,
        function() for k = 1, 4 do moveTo(wx + k * 3, wy + k * 2); frame() end end,
        function() release(wx + 12, wy + 8) end,
    }
end)

for _, jointType in ipairs({ 'revolute', 'weld', 'rope', 'distance', 'prismatic' }) do
    tool('make ' .. jointType .. ' joint', function()
        local a, b = twoBodies()
        if not (a and b) then return nil end
        -- the tool rail's joint button
        state.jointParams = { body1 = nil, body2 = nil, jointType = jointType }
        modes.set(modes.JOINT_CREATION)
        local ax, ay = inside(a)
        local bx, by = inside(b)
        return {
            function() look(ax, ay); click(ax, ay) end,
            function() look(bx, by); click(bx, by) end,
            function() prompt('create') end,
        }
    end)
end

local function drawTool(mode, finish)
    return function()
        local body = anyBody()
        local x, y = 0, 0
        if body then x, y = body:getPosition() end
        x, y = far(x, y)
        -- the tool rail's draw buttons (startDraw)
        modes.set(mode)
        state.interaction.polyVerts, state.interaction.lastPolyPt = {}, nil
        look(x, y)
        local pts = { { x, y }, { x + 80, y }, { x + 90, y + 70 }, { x + 10, y + 80 } }
        if mode == modes.DRAW_CLICK then
            return {
                function() click(pts[1][1], pts[1][2]) end,
                function() click(pts[2][1], pts[2][2]) end,
                function() click(pts[3][1], pts[3][2]) end,
                function() click(pts[4][1], pts[4][2]) end,
                function() prompt(finish) end,
            }
        end
        return {
            function() press(pts[1][1], pts[1][2]) end,
            function() for k = 2, 4 do moveTo(pts[k][1], pts[k][2]); frame() end end,
            function() release(pts[4][1], pts[4][2]) end,
        }
    end
end
tool('draw by clicks', drawTool(modes.DRAW_CLICK, 'finalize'))
tool('draw free polygon', drawTool(modes.DRAW_FREE_POLY))
tool('draw free path', drawTool(modes.DRAW_FREE_PATH))

tool('drag a body', function()
    local body = anyBody()
    if not body then return nil end
    local x, y = inside(body)
    look(x, y)
    return {
        function() press(x, y) end,
        function() for k = 1, 5 do moveTo(x + k * 10, y + k * 5); frame() end end,
        function() release(x + 50, y + 25) end,
    }
end)

tool('drag a body, running', function()
    local body = anyBody()
    if not body then return nil end
    state.world.paused = false
    local x, y = inside(body)
    look(x, y)
    return {
        function() press(x, y) end,
        function() for k = 1, 5 do moveTo(x + k * 10, y + k * 5); frame() end end,
        function() release(x + 50, y + 25) end,
    }
end)

-- ---- the cuts: what else happens while a tool is halfway ----

-- what's selected, destroyed or rebuilt through its own panel's row
local function selected()
    local sel = state.selection
    if sel.selectedSFixture and alive(sel.selectedSFixture) then return 'sfixture', sel.selectedSFixture end
    if sel.selectedJoint and alive(sel.selectedJoint) then return 'joint', sel.selectedJoint end
    if sel.selectedObj and sel.selectedObj.body and alive(sel.selectedObj.body) then return 'body', sel.selectedObj end
    -- picking bodies for a joint: the first one picked
    local jp = state.jointParams
    if jp and jp.body1 and alive(jp.body1) then return 'body', utils.thingOf(jp.body1) end
end

local CUTS = {
    { 'destroy it', function()
        local kind, target = selected()
        if kind == 'body' then
            rowLabelled(bodyParams.rows, 'destroy', target).run(target.body, target)
        elseif kind == 'joint' then
            jointParams.header[2].run(nil, target)
        elseif kind == 'sfixture' then
            sfixtureParams.footer[1].run(nil, target)
        end
    end },
    { 'rebuild it', function()
        local kind, target = selected()
        if kind == 'body' then
            local row = rowLabelled(bodyParams.rows, 'width', target)
            if not (row and row.visible(target)) then row = rowLabelled(bodyParams.rows, 'radius', target) end
            if row and row.visible(target) then row.set(target, (row.get(target) or 10) + 5) end
        elseif kind == 'joint' then
            local row = rowLabelled(jointParams.byType[target:getType()] or {}, 'collide', target)
            if row then row.set(target, not row.get(target)) end
        elseif kind == 'sfixture' then
            pcall(sfixtureParams.placeOnEdge, target, 'C') -- not every sfixture is a box; then nothing
        end
    end },
    { 'another tool', function()
        if modes.is(modes.JOINT_CREATION) then
            modes.set(modes.DRAW_FREE_POLY)
            state.interaction.polyVerts, state.interaction.lastPolyPt = {}, nil
        else
            state.jointParams = { body1 = nil, body2 = nil, jointType = 'revolute' }
            modes.set(modes.JOINT_CREATION)
        end
    end },
    { 'tool off', function() modes.clear() end },
    { 'play and back', function()
        playMode.enter(); frame(); frame(); playMode.exit()
    end },
    { 'room again', function(text) sceneLoader.loadSceneData(text, 'the room again') end },
}

-- what's left pointing at something gone, after a cut
local function stale(p)
    local sel = state.selection
    local function gone(object) return object ~= nil and not alive(object) end
    if sel.selectedObj and gone(sel.selectedObj.body) then p.add('stale: the selected body is destroyed') end
    if gone(sel.selectedJoint) then p.add('stale: the selected joint is destroyed') end
    if gone(sel.selectedSFixture) then p.add('stale: the selected sfixture is destroyed') end
    local mode = state.currentMode
    local needsJoint = mode == modes.SET_OFFSET_A or mode == modes.SET_OFFSET_B
    local needsSFixture = mode == modes.POSITIONING_SFIXTURE or mode == modes.ADD_NODE_CONNECTED_TEX
        or mode == modes.ADD_NODE_MESHUSERT or mode == modes.EDIT_MESH_TRIS
    if needsJoint and not (sel.selectedJoint and alive(sel.selectedJoint)) then
        p.add('stale: ' .. mode .. ' on without its joint')
    end
    if needsSFixture and not (sel.selectedSFixture and alive(sel.selectedSFixture)) then
        p.add('stale: ' .. mode .. ' on without its sfixture')
    end
    local bodyThere = sel.selectedObj and sel.selectedObj.body and alive(sel.selectedObj.body)
    if mode == modes.PLACE_STEINER and not bodyThere then
        p.add('stale: ' .. mode .. ' on without its body')
    end
    local jp = state.jointParams
    if jp and (gone(jp.body1) or gone(jp.body2)) then p.add('stale: joint making holds a destroyed body') end
    if state.polyEdit.tempVerts and not bodyThere then
        p.add('stale: polygon corners edited without their body')
    end
    if state.texFixtureEdit.tempVerts and not (sel.selectedSFixture and alive(sel.selectedSFixture)) then
        p.add('stale: texture corners edited without their sfixture')
    end
    local dragging = state.interaction.draggingObj
    if dragging and gone(dragging.body) then p.add('stale: dragging a destroyed body') end
end

-- one tool in one scene: whole (cut nil) or cut off halfway; returns the problems
local function run(text, toolDef, cut)
    local p = sweep.problems()
    sweep.fresh()
    resetEditor()
    if not p.phase('load', function() sceneLoader.loadSceneData(text, 'sweep') end) then return p.finish(), true end
    local steps
    if not p.phase('start', function() steps = toolDef.setup() end) then return p.finish(), true end
    if not steps then
        resetEditor()
        return p.finish(), false
    end
    local upto = cut and math.max(1, math.floor(#steps / 2)) or #steps
    local ok = p.phase('tool', function()
        frame()
        for k = 1, upto do steps[k]() end
    end)
    if ok and cut then
        ok = p.phase('cut: ' .. cut[1], function() cut[2](text); frame() end)
        -- as the editor has it when it next acts: on the next mouse move (modes.dropWhatsGone)
        if ok then p.phase('stale', function() input.handleMouseMoved(mouse.x, mouse.y, 0, 0); stale(p) end) end
    end
    if ok then
        -- the next click: on a body, then on nothing
        p.phase('next click', function()
            local body = anyBody()
            if body then
                local x, y = inside(body)
                look(x, y)
                click(x, y)
                click(far(x, y))
            end
            frame()
        end)
    end
    local world = state.physicsWorld
    mouse.down = {}
    resetEditor()
    p.phase('check', function() sweep.checkWorld(p, world) end)
    sweep.saveAndReload(p, world)
    collectgarbage('collect') -- the worlds and their pictures before the next run
    return p.finish(), true
end

describe('tool modes', function()
    it('every tool in every scene, whole and cut off', function()
        local font = love.graphics.newFont(12)
        love.graphics.setFont(font)
        ui.init(font, font:getHeight())
        playtimeui = require('src.playtime-ui')
        canvas = love.graphics.newCanvas(1200, 768)
        local file = assert(io.open(out, 'w'))
        local report = sweep.report('tool-modes_spec')
        local total, failing = 0, 0
        for _, path in ipairs(sweep.scenes(only)) do
            local text = love.filesystem.read(path)
            local data = text and json.decode(text)
            if type(data) == 'table' and data.bodies then
                local ids = sweep.idsOf(data)
                -- the scene untouched: its own problems
                local own = {}
                local p0 = sweep.problems()
                sweep.fresh(); resetEditor()
                if p0.phase('load', function() sceneLoader.loadSceneData(text, 'sweep') end) then
                    p0.phase('frame', function() frame() end)
                    sweep.saveAndReload(p0, state.physicsWorld)
                end
                for _, problem in ipairs(p0.finish()) do
                    own[sweep.shape(problem, ids)] = true
                    file:write('UNTOUCHED ', path, ': ', problem, '\n')
                end
                local count = 0
                for _, toolDef in ipairs(TOOLS) do
                    for c = 0, #CUTS do
                        local cut = CUTS[c]
                        local problems, ran = run(text, toolDef, cut)
                        if ran then
                            count, total = count + 1, total + 1
                            local any = false
                            local label = toolDef.name .. (cut and (' / ' .. cut[1]) or ' / whole')
                            for _, problem in ipairs(problems) do
                                local message = sweep.shape(problem, ids)
                                if not own[message] then
                                    any = true
                                    report.add(message, problem, path .. ' / ' .. label, label)
                                end
                            end
                            if any then failing = failing + 1 end
                            if MEM then
                                local g = love.graphics.getStats()
                                file:write(string.format('MEM %d lua %.1f MB  textures %.1f MB  canvases %d  images %d  %s\n',
                                    total, collectgarbage('count') / 1024, g.texturememory / 1048576, g.canvases,
                                    g.images, label))
                            end
                        end
                        if not ran then break end -- the scene has nothing for this tool
                    end
                end
                file:write('scene ', path, ' done (', count, ' runs)\n'); file:flush()
            end
        end
        report.write(file, total, failing, 'tool runs')
        file:close()
        ui.topPrompt = realTopPrompt
    end)
end)

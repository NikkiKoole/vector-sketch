-- Snapshot: a pixel hash of editor-render's renderActiveEditorThings (the editor's overlay: the selected
-- sfixture and a MESHUSERT's influence capsules, the selected joint, a polygon being drawn, the vertex
-- handles of a shape or a texfixture being edited (meta8's cross lines too), the selected bodies, the node
-- a connected texture / MESHUSERT would take, the triangle painter in both modes) for each of those
-- states set up by hand in a few scenes, drawn through the camera as the game does.
-- claudetools/snapshot.sh. Runs only when $SNAPSHOT_OUT is set.
if not love then return end
local out = os.getenv('SNAPSHOT_OUT')
if not out or out == '' then return end

local state = require('src.state')
local registry = require('src.registry')
local sceneIO = require('src.io')
local camera = require('src.camera')
local modes = require('src.modes')
local subtypes = require('src.subtypes')
local utils = require('src.utils')
local mathutils = require('src.math-utils')
local editorRender = require('src.editor-render')
local resourceLink = require('src.resource-link')

local SCENES = { 'scripts/tech/hoop.playtime.json', 'scripts/tech/workmoreclean.playtime.json',
                 'scripts/tests/meta.playtime.json', 'scripts/rooms/kitchen.playtime.json',
                 'scripts/rooms/dollhouse.playtime.json' }
local CAP = 25 -- at most this many sfixtures / joints / shapes per scene and kind (the dollhouse has hundreds)
local W, H = 1200, 768

local mouseX, mouseY = 0, 0
love.mouse.getPosition = function() return mouseX, mouseY end

local function reset()
    state.selection.selectedObj, state.selection.selectedJoint = nil, nil
    state.selection.selectedSFixture, state.selection.selectedBodies = nil, nil
    state.interaction.polyVerts = {}
    state.polyEdit.tempVerts, state.polyEdit.lockedVerts, state.polyEdit.centroid = nil, true, nil
    state.texFixtureEdit.tempVerts, state.texFixtureEdit.lockedVerts = nil, true
    state.triangleEditor.selectedTriangles, state.triangleEditor.paintMode = {}, nil
    state.triangleEditor.hoveredGroup = nil
    modes.clear()
    mouseX, mouseY = 0, 0
end

local function bounds(world)
    local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
    for _, body in ipairs(world:getBodies()) do
        local x, y = body:getPosition()
        x1, y1, x2, y2 = math.min(x1, x), math.min(y1, y), math.max(x2, x), math.max(y2, y)
    end
    return x1, y1, x2, y2
end

local font = love.graphics.newFont(12)
local function hash()
    local canvas = love.graphics.newCanvas(W, H)
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setFont(font)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
    local cam = camera.getInstance()
    cam:push()
    local ok, err = pcall(editorRender.renderActiveEditorThings)
    cam:pop()
    love.graphics.setCanvas()
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
    local h = ok and love.data.encode('string', 'hex', love.data.hash('md5', canvas:newImageData():getString())):sub(1, 12)
        or ('ERR ' .. tostring(err):sub(1, 70))
    canvas:release()
    return h
end

-- the mouse over a world point (for the hovered vertex handle, the closest node)
local function mouseAt(wx, wy)
    mouseX, mouseY = camera.getInstance():getScreenCoordinates(wx, wy)
end

local function sortedById(list)
    table.sort(list, function(a, b) return tostring(a.id) < tostring(b.id) end)
    return list
end

local function sfixturesOf(world)
    local list = {}
    for _, body in ipairs(world:getBodies()) do
        for _, f in ipairs(body:getFixtures()) do
            local ud = f:getUserData()
            if type(ud) == 'table' and ud.subtype then list[#list + 1] = { id = ud.id, fixture = f, ud = ud } end
        end
    end
    return sortedById(list)
end

local function jointsOf(world)
    local list = {}
    for _, joint in ipairs(world:getJoints()) do
        local ud = joint:getUserData()
        list[#list + 1] = { id = ud and ud.id or tostring(#list), joint = joint }
    end
    return sortedById(list)
end

local function thingsOf(world)
    local list = {}
    for _, body in ipairs(world:getBodies()) do
        local thing = utils.thingOf(body)
        if thing then list[#list + 1] = { id = thing.id, thing = thing } end
    end
    return sortedById(list)
end

local function scenarios(world)
    local rows = {}
    local function row(label) rows[#rows + 1] = label .. ' ' .. hash() reset() end
    reset()
    row('nothing')
    local sf = sfixturesOf(world)
    for i = 1, math.min(CAP, #sf) do -- the selected sfixture (a MESHUSERT draws its capsules)
        state.selection.selectedSFixture = sf[i].fixture
        row('sfixture ' .. tostring(sf[i].id))
    end
    local joints = jointsOf(world)
    for i = 1, math.min(CAP, #joints) do
        state.selection.selectedJoint = joints[i].joint
        row('joint ' .. tostring(joints[i].id))
    end
    local x1, y1, x2, y2 = bounds(world)
    for _, mode in ipairs({ modes.DRAW_CLICK, modes.DRAW_FREE_POLY, modes.DRAW_FREE_PATH }) do
        modes.set(mode)
        state.interaction.polyVerts = { x1, y1, x2, y1, (x1 + x2) / 2, y2, x1, (y1 + y2) / 2 }
        row('drawing ' .. mode)
    end
    local things = thingsOf(world)
    local shapes = 0
    for _, t in ipairs(things) do -- a custom or ribbon shape's vertices, unlocked; the mouse on vertex 1
        local thing = t.thing
        if (thing.shapeType == 'custom' or thing.shapeType == 'ribbon') and thing.vertices and shapes < CAP then
            shapes = shapes + 1
            state.selection.selectedObj = thing
            state.polyEdit.tempVerts = utils.shallowCopy(thing.vertices)
            local cx, cy = mathutils.computeCentroid(thing.vertices)
            state.polyEdit.centroid = { x = cx, y = cy }
            state.polyEdit.lockedVerts = false
            local verts = mathutils.getLocalVerticesForCustomSelected(state.polyEdit.tempVerts, thing, cx, cy)
            mouseAt(verts[1], verts[2])
            row('polyedit ' .. tostring(thing.id))
            state.selection.selectedObj = thing -- the same, locked: only the red outline
            state.polyEdit.tempVerts = utils.shallowCopy(thing.vertices)
            state.polyEdit.centroid = { x = cx, y = cy }
            row('polyedit locked ' .. tostring(thing.id))
        end
    end
    local tex = 0
    for _, s in ipairs(sf) do -- a texfixture's vertices, unlocked (meta8 draws its cross lines)
        if s.ud.subtype == subtypes.TEXFIXTURE and s.ud.extra and s.ud.extra.vertices and tex < CAP then
            tex = tex + 1
            state.selection.selectedSFixture = s.fixture
            state.texFixtureEdit.tempVerts = utils.shallowCopy(s.ud.extra.vertices)
            state.texFixtureEdit.lockedVerts = false
            local verts = mathutils.getLocalVerticesForCustomSelected(state.texFixtureEdit.tempVerts,
                utils.thingOf(s.fixture:getBody()), 0, 0)
            mouseAt(verts[3], verts[4])
            row('texedit ' .. tostring(s.id))
        end
    end
    local selected = {}
    for i = 1, math.min(5, #things) do selected[#selected + 1] = things[i].thing end
    state.selection.selectedBodies = selected
    row('selected bodies')
    for _, mode in ipairs({ modes.ADD_NODE_CONNECTED_TEX, modes.ADD_NODE_MESHUSERT }) do
        for i = 1, math.min(3, #joints) do -- the mouse on a joint's anchor: the node it would take
            modes.set(mode)
            local ax, ay = joints[i].joint:getAnchors()
            mouseAt(ax, ay)
            row('add node ' .. mode .. ' ' .. tostring(joints[i].id))
        end
    end
    for _, s in ipairs(sf) do -- the triangle painter on a MESHUSERT, in both modes (groups with and without
        -- triangles assigned: the scenes have none saved, so a few for the run)
        if s.ud.subtype == subtypes.MESHUSERT then
            local resource = resourceLink.find(s.ud)
            local rextra = resource and resource:getUserData().extra
            local savedGroups = rextra and rextra.triangleGroups
            for _, paint in ipairs({ 'bones', 'groups', 'groups assigned' }) do
                if paint == 'groups assigned' and rextra then
                    rextra.triangleGroups = {}
                    for t = 1, 12 do rextra.triangleGroups[t] = t % 3 + 1 end
                end
                modes.set(modes.EDIT_MESH_TRIS)
                state.selection.selectedSFixture = s.fixture
                state.triangleEditor.paintMode = paint == 'bones' and 'bones' or 'groups'
                state.triangleEditor.selectedTriangles = { 1, 2, 5 }
                state.triangleEditor.hoveredGroup = 1
                local bx, by = s.fixture:getBody():getPosition()
                mouseAt(bx, by)
                row('triangles ' .. paint .. ' ' .. tostring(s.id))
            end
            if rextra then rextra.triangleGroups = savedGroups end
        end
    end
    return rows
end

describe('overlay snapshot', function()
    it('hashes the editor overlay in every state', function()
        local lines = {}
        local cam = camera.getInstance()
        local savedScale, savedX, savedY = cam:getScale(), cam:getTranslation()
        for _, path in ipairs(SCENES) do
            local world = love.physics.newWorld(0, 0, true)
            state.physicsWorld = world
            registry.reset()
            state.backdrops = {}
            math.randomseed(1); love.math.setRandomSeed(1)
            local ok, err = pcall(sceneIO.load, love.filesystem.read(path), world, cam)
            if ok then
                local x1, y1, x2, y2 = bounds(world)
                cam:setScale(math.min(W / math.max(x2 - x1 + 600, 1), H / math.max(y2 - y1 + 600, 1)))
                cam:setTranslation((x1 + x2) / 2, (y1 + y2) / 2)
                for _, r in ipairs(scenarios(world)) do lines[#lines + 1] = path .. ' | ' .. r end
            else
                lines[#lines + 1] = path .. ' LOADERR ' .. tostring(err):sub(1, 80)
            end
            reset()
            for _, body in ipairs(world:getBodies()) do body:setUserData(nil) end
            world:setCallbacks()
            world:destroy()
            registry.reset()
        end
        cam:setScale(savedScale)
        cam:setTranslation(savedX, savedY)
        local f = assert(io.open(out, 'w'))
        f:write(table.concat(lines, '\n'), '\n')
        f:close()
    end)
end)

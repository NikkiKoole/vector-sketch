-- What the scene sweeps share (claudetools/scene-damage_spec.lua, claudetools/editor-actions_spec.lua):
-- the scene list, a fresh world, a drawn frame, catching logger.error, and the report that groups
-- problems by message with the first scene and case that hit it.
local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local box2dDraw = require('src.physics.box2d-draw')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')
local logger = require('src.logger')
local utils = require('src.utils')
local fixtures = require('src.fixtures')
local json = require('vendor.dkjson')
local sceneIO = require('src.io')
local camera = require('src.camera')

local lib = {}

-- every scene file in scripts/ (only: part of its path), sorted
function lib.scenes(only)
    local list = {}
    for _, scene in ipairs(require('src.scene-catalog').list()) do
        if scene.path and (not only or scene.path:find(only, 1, true)) then list[#list + 1] = scene.path end
    end
    table.sort(list)
    return list
end

-- n of the indices 1..count, spread evenly
function lib.spread(count, n)
    local list = {}
    if count <= n then
        for i = 1, count do list[i] = i end
    else
        for k = 1, n do list[k] = math.floor((k - 1) * count / n) + 1 end
    end
    return list
end

function lib.fresh()
    if state.physicsWorld and not state.physicsWorld:isDestroyed() then
        state.physicsWorld:setCallbacks()
        state.physicsWorld:destroy()
    end
    registry.reset()
    mipoRegistry.reset()
    state.physicsWorld = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
    return state.physicsWorld
end

local canvas
function lib.frame(world)
    canvas = canvas or love.graphics.newCanvas(400, 300)
    box2dDrawTextured.makeCombinedImages()
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear()
    box2dDraw.drawWorld(world)
    box2dDrawTextured.drawTexturedWorld(world)
    love.graphics.setCanvas()
end

-- a LÖVE object still there (one LÖVE released when its world went can't be asked: gone)
function lib.alive(object)
    local ok, destroyed = pcall(object.isDestroyed, object)
    return ok and not destroyed
end
local alive = lib.alive

-- what the world holds: bodies, joints, sfixtures per subtype
local function census(world)
    local c = { bodies = world:getBodyCount(), joints = 0, sfixtures = {} }
    for _, joint in ipairs(world:getJoints()) do
        if (joint:getUserData() or {}).id then c.joints = c.joints + 1 end
    end
    for _, body in ipairs(world:getBodies()) do
        -- a Mipo's own sfixtures are made again from its DNA on load (a limb's ribbon needs its
        -- joints: one destroyed in the editor, its ribbon isn't made again), so not counted
        local thing = utils.thingOf(body)
        if not (thing and thing.mipoId) then
            for _, fixture in ipairs(body:getFixtures()) do
                local ud = fixture:getUserData()
                if ud and ud.subtype then c.sfixtures[ud.subtype] = (c.sfixtures[ud.subtype] or 0) + 1 end
            end
        end
    end
    return c
end

local function compareCensus(p, before, after)
    if after.bodies ~= before.bodies then p.add('reload bodies: ' .. after.bodies .. ' of ' .. before.bodies) end
    if after.joints ~= before.joints then p.add('reload joints: ' .. after.joints .. ' of ' .. before.joints) end
    for subtype, n in pairs(before.sfixtures) do
        local m = after.sfixtures[subtype] or 0
        if m ~= n then p.add('reload ' .. subtype .. ' sfixtures: ' .. m .. ' of ' .. n) end
    end
end

-- the sfixtures-first order and the registry agreeing with the world
function lib.checkWorld(p, world)
    for _, body in ipairs(world:getBodies()) do
        local thing = utils.thingOf(body)
        if not fixtures.hasFixturesWithUserDataAtBeginning(body:getFixtures()) then
            p.add('sfixtures not first on a body: ' .. tostring(thing and thing.shapeType))
        end
        if thing and thing.id and registry.getBodyByID(thing.id) ~= body then
            p.add('body not registered under its id')
        end
    end
    for _, kind in ipairs({ 'bodies', 'joints', 'sfixtures' }) do
        for _, object in pairs(registry[kind]) do
            if not alive(object) then p.add('registry ' .. kind .. ' holds a destroyed one') end
        end
    end
    for _, joint in ipairs(world:getJoints()) do
        local id = (joint:getUserData() or {}).id
        if id and registry.getJointByID(id) ~= joint then p.add('joint not registered under its id') end
    end
end

-- save the world, load the save into a fresh one, compare what's in them, draw the reload
function lib.saveAndReload(p, world)
    local saved, before
    if p.phase('save', function()
            before = census(world)
            saved = json.encode(sceneIO.gatherSaveData(world, camera.getInstance()))
        end) then
        local world2 = lib.fresh()
        if p.phase('reload', function() sceneIO.load(saved, world2, camera.getInstance()) end) then
            compareCensus(p, before, census(world2))
            p.phase('draw reloaded', function() lib.frame(world2) end)
        end
    end
end

-- A run's problems: phase(name, fn) runs fn under xpcall and notes a throw with its traceback;
-- add(text) notes anything else; finish() stops catching logger.error and returns the list, the
-- logged lines last ('logged: ...').
function lib.problems()
    local list, logged = {}, {}
    local realError = logger.error
    logger.error = function(self, ...)
        local parts = {}
        for i = 1, select('#', ...) do parts[#parts + 1] = tostring((select(i, ...))) end
        logged[#logged + 1] = table.concat(parts, ' ')
        return realError(self, ...)
    end
    local p = {}
    function p.add(text) list[#list + 1] = text end
    function p.phase(name, fn)
        local ok, err = xpcall(fn, debug.traceback)
        if not ok then list[#list + 1] = name .. ': ' .. tostring(err) end
        return ok
    end
    function p.finish()
        logger.error = realError
        for _, line in ipairs(logged) do list[#list + 1] = 'logged: ' .. line end
        return list
    end
    return p
end

-- every id in the scene's data (bodies, joints, sfixtures, Mipos), to blank out of messages
function lib.idsOf(data)
    local ids = {}
    local function walk(t)
        for k, v in pairs(t) do
            if type(v) == 'table' then walk(v)
            elseif (k == 'id' or k == 'mipoId') and type(v) == 'string' then ids[v] = true end
        end
    end
    walk(data)
    return ids
end

-- an error's first line without the ids and numbers that differ per case
function lib.shape(problem, ids)
    problem = problem:match('^[^\n]*'):gsub('[%w_%-]+', function(w) if ids[w] then return '<id>' end end)
    return (problem:gsub('%d+%.%d+', '#'):gsub('of %d+', 'of #'):gsub(': %d+ ', ': # '):sub(1, 200))
end

-- The grouped report. add(key, problem, where) counts a problem under its key, keeping the first
-- example (where + the top of its traceback); write(file, total, failing) writes thrown errors and
-- lost things first, then what was only logged.
function lib.report(skipInTrace)
    local groups, order = {}, {}
    local r = {}
    -- tag (optional): what hit it ('steiner points / destroy it'), listed per kind in the report
    function r.add(key, problem, where, tag)
        if not groups[key] then
            local trace = {}
            for line in problem:gmatch('[^\n]+') do
                if #trace < 8 and not line:find(skipInTrace, 1, true) then trace[#trace + 1] = line end
            end
            groups[key] = { count = 0, example = where .. ' -> ' .. table.concat(trace, '\n        ') }
            order[#order + 1] = key
        end
        groups[key].count = groups[key].count + 1
        if tag then
            groups[key].tags = groups[key].tags or {}
            if not groups[key].tags[tag] then
                groups[key].tags[tag] = true
                groups[key].tagList = groups[key].tagList or {}
                table.insert(groups[key].tagList, tag)
            end
        end
    end
    function r.write(file, total, failing, what)
        local function logged(key) return key:sub(1, 8) == 'logged: ' end
        table.sort(order, function(a, b)
            if logged(a) ~= logged(b) then return not logged(a) end
            return groups[a].count > groups[b].count
        end)
        file:write(string.format('\n%d %s, %d with problems, %d kinds:\n', total, what, failing, #order))
        local inLogged = false
        for _, key in ipairs(order) do
            if logged(key) and not inLogged then
                inLogged = true
                file:write('\n---- only logged (handled, but worth a look) ----\n')
            end
            file:write(string.format('\n[%d] %s\n', groups[key].count, key))
            if groups[key].tagList then file:write('    in: ', table.concat(groups[key].tagList, '; '), '\n') end
            file:write('    e.g. ', groups[key].example, '\n')
        end
    end
    return r
end

return lib

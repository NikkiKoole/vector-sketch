-- Sweep: every scene in scripts/ with one thing taken out (a body, a joint, an sfixture, a Mipo's
-- entry), then loaded, drawn, stepped, saved and loaded again. Things in a scene name other things by
-- id (ribbons their joints, meshes their anchors and pictures, snaps, doors, Mipo parts); a scene that
-- doesn't load is lost work. Reports every error grouped by message, with the first scene and case
-- that hit it, and loads that lose more bodies than were taken out.
-- Run: DAMAGE_OUT=/some/file.txt love . --specs claudetools/scene-damage_spec.lua  [DAMAGE_ONLY=dollhouse]
-- (docs/CODE-COMPLEXITY-2026-11.md, the damaged-scene sweep)
if not love then return end
local out = os.getenv('DAMAGE_OUT')
if not out or out == '' then return end
local only = os.getenv('DAMAGE_ONLY')
local PER_KIND = tonumber(os.getenv('DAMAGE_PER_KIND') or '') or 25

local json = require('vendor.dkjson')
local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local sceneIO = require('src.io')
local camera = require('src.camera')
local box2dDraw = require('src.physics.box2d-draw')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')
local logger = require('src.logger')

love.mouse.getPosition = function() return 0, 0 end

local function scenes()
    local list = {}
    for _, scene in ipairs(require('src.scene-catalog').list()) do
        if scene.path and (not only or scene.path:find(only, 1, true)) then list[#list + 1] = scene.path end
    end
    table.sort(list)
    return list
end

-- n of the indices 1..count, spread evenly
local function spread(count, n)
    local list = {}
    if count <= n then
        for i = 1, count do list[i] = i end
    else
        for k = 1, n do list[k] = math.floor((k - 1) * count / n) + 1 end
    end
    return list
end

-- the damage cases of one scene: { label, apply(data), lostBodies }
local function cases(data)
    local list = {}
    local bodies, joints = data.bodies or {}, data.joints or {}
    for _, i in ipairs(spread(#bodies, PER_KIND)) do
        local b = bodies[i]
        list[#list + 1] = { 'body ' .. tostring(b.id) .. ' ' .. tostring(b.label or b.mipoPartName or ''),
            function(d) table.remove(d.bodies, i) end, 1 }
    end
    for _, i in ipairs(spread(#joints, PER_KIND)) do
        local j = joints[i]
        list[#list + 1] = { 'joint ' .. tostring(j.id) .. ' ' .. tostring(j.type),
            function(d) table.remove(d.joints, i) end, 0 }
    end
    local sfixtures = {}
    for bi, b in ipairs(bodies) do
        for fi, f in ipairs(b.fixtures or {}) do
            if f.userData then sfixtures[#sfixtures + 1] = { bi, fi, f.userData } end
        end
    end
    for _, k in ipairs(spread(#sfixtures, PER_KIND)) do
        local bi, fi, ud = sfixtures[k][1], sfixtures[k][2], sfixtures[k][3]
        list[#list + 1] = { 'sfixture ' .. tostring(ud.id) .. ' ' .. tostring(ud.subtype),
            function(d) table.remove(d.bodies[bi].fixtures, fi) end, 0 }
    end
    for i, c in ipairs(data.characters or {}) do
        if i > PER_KIND then break end
        list[#list + 1] = { 'mipo entry ' .. tostring(c.id), function(d) table.remove(d.characters, i) end, nil }
    end
    return list
end

local function fresh()
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
local function frame(world)
    box2dDrawTextured.makeCombinedImages()
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear()
    box2dDraw.drawWorld(world)
    box2dDrawTextured.drawTexturedWorld(world)
    love.graphics.setCanvas()
end

-- runs one damaged scene through load / draw / step / save / reload; returns a list of problems
local function run(text, expectBodies)
    local problems = {}
    local logged = {}
    local realError = logger.error
    logger.error = function(self, ...)
        local parts = {}
        for i = 1, select('#', ...) do parts[#parts + 1] = tostring((select(i, ...))) end
        logged[#logged + 1] = table.concat(parts, ' ')
        return realError(self, ...)
    end
    local function phase(name, fn)
        local ok, err = xpcall(fn, debug.traceback)
        if not ok then problems[#problems + 1] = name .. ': ' .. tostring(err) end
        return ok
    end
    local world = fresh()
    local loaded = phase('load', function() sceneIO.load(text, world, camera.getInstance()) end)
    if loaded and expectBodies and world:getBodyCount() < expectBodies then
        problems[#problems + 1] = 'lost bodies: ' .. world:getBodyCount() .. ' of ' .. expectBodies
    end
    if loaded then
        phase('draw', function() frame(world) end)
        phase('step', function() for _ = 1, 3 do world:update(1 / 60) end end)
        phase('draw after step', function() frame(world) end)
        local saved
        if phase('save', function() saved = json.encode(sceneIO.gatherSaveData(world, camera.getInstance())) end) then
            local count = world:getBodyCount()
            local world2 = fresh()
            if phase('reload', function() sceneIO.load(saved, world2, camera.getInstance()) end) then
                if world2:getBodyCount() < count then
                    problems[#problems + 1] = 'reload lost bodies: ' .. world2:getBodyCount() .. ' of ' .. count
                end
                phase('draw reloaded', function() frame(world2) end)
            end
        end
    end
    logger.error = realError
    for _, line in ipairs(logged) do problems[#problems + 1] = 'logged: ' .. line end
    return problems
end

-- every id in the scene's data (bodies, joints, sfixtures, Mipos), to blank out of messages
local function idsOf(data)
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

-- an error's place and words without the ids and numbers that differ per case
local function shape(problem, ids)
    problem = problem:gsub('[%w_%-]+', function(w) if ids[w] then return '<id>' end end)
    return (problem:gsub('%d+%.%d+', '#'):gsub('of %d+', 'of #'):gsub(': %d+ ', ': # '):sub(1, 200))
end

describe('damaged scenes', function()
    it('load, draw, step, save and load again with one thing taken out', function()
        canvas = love.graphics.newCanvas(400, 300)
        local file = assert(io.open(out, 'w'))
        local groups, order = {}, {}
        local total, failing = 0, 0
        for _, path in ipairs(scenes()) do
            local text = love.filesystem.read(path)
            local data = text and json.decode(text)
            if type(data) == 'table' and data.bodies then
                -- the scene as it is: how many bodies it makes, and its own problems (not the damage's)
                local ids = idsOf(data)
                local whole = run(text, nil)
                local baseline = state.physicsWorld:getBodyCount()
                local own = {}
                for _, p in ipairs(whole) do own[shape(p:match('^[^\n]*'), ids)] = true end
                for _, p in ipairs(whole) do
                    file:write('UNDAMAGED ', path, ': ', p, '\n')
                end
                for _, case in ipairs(cases(data)) do
                    local damaged = json.decode(text)
                    case[2](damaged)
                    local expect = case[3] and (baseline - case[3]) or nil
                    local problems = run(json.encode(damaged), expect)
                    total = total + 1
                    local any = false
                    for _, p in ipairs(problems) do
                        local key = shape(p:match('^[^\n]*'), ids)
                        if not own[key] then
                            any = true
                            if not groups[key] then
                                local trace = {}
                                for line in p:gmatch('[^\n]+') do
                                    if #trace < 8 and not line:find('scene%-damage_spec') then trace[#trace + 1] = line end
                                end
                                groups[key] = { count = 0, example = path .. ' / ' .. case[1] .. ' -> '
                                    .. table.concat(trace, '\n        ') }
                                order[#order + 1] = key
                            end
                            groups[key].count = groups[key].count + 1
                        end
                    end
                    if any then failing = failing + 1 end
                end
                file:write('scene ', path, ' done\n'); file:flush()
            end
        end
        -- thrown errors and lost bodies first, then what was only logged
        local function logged(key) return key:sub(1, 8) == 'logged: ' end
        table.sort(order, function(a, b)
            if logged(a) ~= logged(b) then return not logged(a) end
            return groups[a].count > groups[b].count
        end)
        file:write(string.format('\n%d damaged loads, %d with problems, %d kinds:\n', total, failing, #order))
        local inLogged = false
        for _, key in ipairs(order) do
            if logged(key) and not inLogged then
                inLogged = true
                file:write('\n---- only logged (handled, but worth a look) ----\n')
            end
            file:write(string.format('\n[%d] %s\n    e.g. %s\n', groups[key].count, key, groups[key].example))
        end
        file:close()
    end)
end)

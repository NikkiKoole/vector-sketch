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
local sceneIO = require('src.io')
local camera = require('src.camera')
local sweep = require('claudetools.sweep')

love.mouse.getPosition = function() return 0, 0 end
local spread = sweep.spread

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

-- runs one damaged scene through load / draw / step / save / reload; returns a list of problems
local function run(text, expectBodies)
    local p = sweep.problems()
    local world = sweep.fresh()
    local loaded = p.phase('load', function() sceneIO.load(text, world, camera.getInstance()) end)
    if loaded and expectBodies and world:getBodyCount() < expectBodies then
        p.add('lost bodies: ' .. world:getBodyCount() .. ' of ' .. expectBodies)
    end
    if loaded then
        p.phase('draw', function() sweep.frame(world) end)
        p.phase('step', function() for _ = 1, 3 do world:update(1 / 60) end end)
        p.phase('draw after step', function() sweep.frame(world) end)
        local saved
        if p.phase('save', function() saved = json.encode(sceneIO.gatherSaveData(world, camera.getInstance())) end) then
            local count = world:getBodyCount()
            local world2 = sweep.fresh()
            if p.phase('reload', function() sceneIO.load(saved, world2, camera.getInstance()) end) then
                if world2:getBodyCount() < count then
                    p.add('reload lost bodies: ' .. world2:getBodyCount() .. ' of ' .. count)
                end
                p.phase('draw reloaded', function() sweep.frame(world2) end)
            end
        end
    end
    return p.finish()
end

describe('damaged scenes', function()
    it('load, draw, step, save and load again with one thing taken out', function()
        local file = assert(io.open(out, 'w'))
        local report = sweep.report('scene-damage_spec')
        local total, failing = 0, 0
        for _, path in ipairs(sweep.scenes(only)) do
            local text = love.filesystem.read(path)
            local data = text and json.decode(text)
            if type(data) == 'table' and data.bodies then
                -- the scene as it is: how many bodies it makes, and its own problems (not the damage's)
                local ids = sweep.idsOf(data)
                local whole = run(text, nil)
                local baseline = state.physicsWorld:getBodyCount()
                local own = {}
                for _, p in ipairs(whole) do own[sweep.shape(p, ids)] = true end
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
                        local key = sweep.shape(p, ids)
                        if not own[key] then
                            any = true
                            report.add(key, p, path .. ' / ' .. case[1])
                        end
                    end
                    if any then failing = failing + 1 end
                end
                file:write('scene ', path, ' done\n'); file:flush()
            end
        end
        report.write(file, total, failing, 'damaged loads')
        file:close()
    end)
end)

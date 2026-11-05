-- Sweep: every scene in scripts/, with one editor action done to it through the inspector's own rows
-- (src/body-params.lua, src/joint-params.lua, src/sfixture-params.lua: resize, flip, clone, destroy,
-- a joint's limits / motor / collide, an sfixture moved, resized, destroyed) or an sfixture attached
-- from the tool rail; then checked, drawn, stepped, saved and loaded again.
-- Rebuilding a body or a joint while the game runs is where DEEPER-ISSUES 2 and 7 live: the
-- sfixtures-first order on a body, and code still holding the joint or body that was replaced.
-- Checks after the action: every body's sfixtures come first; the registry holds no destroyed
-- object and every body is registered under its id; draw / step / save / reload don't throw; the
-- reload has as many bodies, joints and sfixtures (not counting a Mipo's own) as were saved.
-- Problems the untouched scene has already are left out. One case per row and kind of target
-- (a rectangle's width, a revolute joint's motor) per scene, on up to ACTIONS_PER_KIND targets.
-- Run: ACTIONS_OUT=/some/file.txt love . --specs claudetools/editor-actions_spec.lua  [ACTIONS_ONLY=dollhouse]
-- (docs/CODE-COMPLEXITY-2026-11.md, the sweeps)
if not love then return end
local out = os.getenv('ACTIONS_OUT')
if not out or out == '' then return end
local only = os.getenv('ACTIONS_ONLY')
local PER_KIND = tonumber(os.getenv('ACTIONS_PER_KIND') or '') or 2

local json = require('vendor.dkjson')
local state = require('src.state')
local sweep = require('claudetools.sweep')
local actions = require('claudetools.actions')

love.mouse.getPosition = function() return 0, 0 end

describe('editor actions', function()
    it('every scene, one inspector change or attach at a time', function()
        local file = assert(io.open(out, 'w'))
        local report = sweep.report('editor-actions_spec')
        local total, failing = 0, 0
        for _, path in ipairs(sweep.scenes(only)) do
            local text = love.filesystem.read(path)
            local data = text and json.decode(text)
            if type(data) == 'table' and data.bodies then
                local ids = sweep.idsOf(data)
                local whole = actions.run(text, nil)
                local own = {}
                for _, p in ipairs(whole) do
                    own[sweep.shape(p, ids)] = true
                    file:write('UNTOUCHED ', path, ': ', p, '\n')
                end
                local cases = actions.casesOf(state.physicsWorld, PER_KIND)
                for _, case in ipairs(cases) do
                    local problems = actions.run(text, case)
                    total = total + 1
                    local any = false
                    for _, p in ipairs(problems) do
                        local message = sweep.shape(p, ids)
                        if not own[message] then
                            local key = message .. '   [' .. case[1]:match('^(.-) %(') .. ']'
                            any = true
                            report.add(key, p, path .. ' / ' .. case[1])
                        end
                    end
                    if any then failing = failing + 1 end
                end
                file:write('scene ', path, ' done (', #cases, ' actions)\n'); file:flush()
            end
        end
        report.write(file, total, failing, 'actions')
        file:close()
    end)
end)

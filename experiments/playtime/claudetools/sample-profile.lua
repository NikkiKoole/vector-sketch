-- A sampling profiler for the running game (docs/MEASURING.md): LuaJIT's jit.profile notes, about a
-- hundred times a second, which function runs and who called it. A few % overhead, so the game runs
-- at its real speed and tiny functions called thousands of times a frame don't look heavier than
-- they are (ProFi's call hooks made the game ~40x slower and did). Desktop only (LuaJIT).
--   curl -X POST localhost:8001/exec -d '{"code":"require(\"claudetools.sample-profile\").start(10)"}'
--   ... 10 seconds ...
--   curl -X POST localhost:8001/eval -d '{"code":"return require(\"claudetools.sample-profile\").report"}'
-- start(seconds, mode): mode 'F' (functions, default) or 'l' (lines). The report: where the time
-- went (Lua, C: LÖVE/Box2D/the GPU driver/waiting for vsync, GC), then the Lua functions by own
-- time (self) and with what they call (total), as a share of the Lua time. C time can't be pinned
-- on a function: LuaJIT only takes the sample once it's back in Lua, wherever that is next (it put
-- 55% on an image-cache lookup that measures at 0.08 ms a frame). Time C calls with
-- claudetools/frame-profile.lua instead. It also writes .profiles/<time>.folded in LÖVE's save
-- directory (stacks, one per line, with their sample count): drop it on https://www.speedscope.app
-- for a flame graph.
local lib = {}

local DEPTH = 40
local VM = { N = 'compiled', I = 'Lua (interpreted)', C = 'C (LÖVE, Box2D, driver, vsync)', G = 'garbage collector',
    J = 'JIT compiler' }

local run

local function finish()
    local prof = require('jit.profile')
    prof.stop()
    local total = run.samples
    local lines = { string.format('%d samples over %.1f s (one every %.1f ms)', total, run.seconds,
        run.seconds * 1000 / math.max(total, 1)) }
    local function pct(n) return string.format('%5.1f%%', n / math.max(total, 1) * 100) end
    lines[#lines + 1] = 'where the time went:'
    local states = {}
    for state, n in pairs(run.states) do states[#states + 1] = { state, n } end
    table.sort(states, function(a, b) return a[2] > b[2] end)
    for _, s in ipairs(states) do lines[#lines + 1] = '  ' .. pct(s[2]) .. '  ' .. (VM[s[1]] or s[1]) end
    local lua = (run.states.I or 0) + (run.states.N or 0) + (run.states.G or 0)
    local function topLua(counts, title, limit)
        local list = {}
        for name, n in pairs(counts) do list[#list + 1] = { name, n } end
        table.sort(list, function(a, b) return a[2] > b[2] end)
        lines[#lines + 1] = title
        for i = 1, math.min(limit, #list) do
            lines[#lines + 1] = string.format('  %5.1f%%  %s', list[i][2] / math.max(lua, 1) * 100, list[i][1])
        end
    end
    topLua(run.self, 'Lua time, own (self):', 30)
    topLua(run.total, 'Lua time, with what it calls (total):', 25)
    lib.report = table.concat(lines, '\n')
    local folded = {}
    for stack, n in pairs(run.stacks) do folded[#folded + 1] = stack .. ' ' .. n end
    table.sort(folded)
    love.filesystem.createDirectory('.profiles')
    local name = os.date('%Y%m%d-%H%M%S') .. '.folded'
    -- the save directory, not the project: LÖVE only writes there
    love.filesystem.write('.profiles/' .. name, table.concat(folded, '\n') .. '\n')
    lib.folded = love.filesystem.getSaveDirectory() .. '/.profiles/' .. name
    lib.report = lib.report .. '\nflame graph: ' .. lib.folded
    print(lib.report)
    run = nil
end

-- Sample for `seconds` (default 10). Stops itself; the report is in lib.report.
function lib.start(seconds, mode)
    if run then return 'already running' end
    local ok, prof = pcall(require, 'jit.profile')
    if not ok then return 'no jit.profile here (the web build has no LuaJIT)' end
    mode = mode or 'F'
    lib.report = nil
    run = { samples = 0, states = {}, self = {}, total = {}, stacks = {}, seconds = seconds or 10,
        started = love.timer.getTime() }
    prof.start(mode .. 'i1', function(thread, samples, vmstate)
        run.samples = run.samples + samples
        run.states[vmstate] = (run.states[vmstate] or 0) + samples
        local stack = prof.dumpstack(thread, mode .. ';', -DEPTH):gsub(';$', '')
        if vmstate == 'G' then stack = stack .. ';(garbage collector)' end
        if vmstate == 'C' then
            -- not where the C time was spent (see the top): one bucket, kept out of the Lua tables
            run.stacks['(C)'] = (run.stacks['(C)'] or 0) + samples
            return
        end
        run.stacks[stack] = (run.stacks[stack] or 0) + samples
        local leaf = stack:match('([^;]+)$') or '?'
        run.self[leaf] = (run.self[leaf] or 0) + samples
        local seen = {}
        for frame in stack:gmatch('[^;]+') do
            if not seen[frame] then
                seen[frame] = true
                run.total[frame] = (run.total[frame] or 0) + samples
            end
        end
    end)
    -- stop from the game loop, not from inside the sampler
    local funcs = require('vendor.lurker').lovefuncs
    local update = funcs.update
    funcs.update = function(dt)
        update(dt)
        if run and love.timer.getTime() - run.started >= run.seconds then
            funcs.update = update
            finish()
        end
    end
    return 'sampling ' .. run.seconds .. ' s'
end

return lib

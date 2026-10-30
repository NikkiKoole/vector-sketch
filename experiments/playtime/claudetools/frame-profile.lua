-- Where a frame goes, step by step (docs/MEASURING.md M3). Run inside the game through the bridge:
--   curl -X POST localhost:8001/exec -d '{"code":"require(\"claudetools.frame-profile\").start(300)"}'
--   ... wait for the frames ...
--   curl -X POST localhost:8001/eval -d '{"code":"return require(\"claudetools.frame-profile\").report"}'
-- Times every update step main.lua calls (each module's update, world:update), the whole update
-- and draw, the textured draw by kind (state.drawTimes), garbage made per frame and GPU stats.
-- Garbage per step is what the Lua heap grew by during it; a GC step inside lowers it, so it's a
-- floor, and it counts Lua tables only (not meshes, images: those live outside the Lua heap).
-- Wraps module functions while it runs and puts them back after. Start it on a copy of the
-- project or a game you'll restart: a lurker hot swap during a run keeps the wrappers.
local lib = {}

local timer = love.timer.getTime

-- module, function name, label: what love.update calls, in its order
local STEPS = {
    { 'src.doors', 'update', 'doors' },
    { 'src.blob', 'beforeStep', 'blobs before' },
    { 'src.mipo-joint-guard', 'update', 'joint guard' },
    { 'src.mipo-actions', 'update', 'mipo actions' },
    { 'src.signals', 'update', 'signals' },
    { 'src.mipo-voice', 'update', 'mipo voice' },
    { 'src.mipo-chatter', 'update', 'mipo chatter' },
    { 'src.mipo-band', 'update', 'mipo band' },
    { 'src.flight-recorder', 'update', 'flight recorder' },
    { 'src.physics.snap', 'update', 'snap' },
    { 'src.keep-angle', 'update', 'keep angle' },
    { 'src.blob', 'afterStep', 'blobs after' },
    { 'src.sound', 'update', 'sound + music' },
    { 'src.liquid', 'update', 'liquid' },
    { 'src.physics.box2d-pointerjoints', 'handlePointerUpdate', 'pointers' },
    { 'src.mipo-face', 'update', 'mipo face' },
    { 'src.camera-follow', 'update', 'camera follow' },
    { 'src.physics.box2d-draw-textured', 'drawTexturedWorld', 'draw: textured' },
}

local run
local restore = {}

local function wrap(tbl, name, label)
    local f = tbl[name]
    restore[#restore + 1] = function() tbl[name] = f end
    tbl[name] = function(...)
        local kb = collectgarbage('count')
        local t0 = timer()
        local a, b, c, d = f(...)
        if run then
            run.ms[label] = (run.ms[label] or 0) + timer() - t0
            run.kb[label] = (run.kb[label] or 0) + math.max(0, collectgarbage('count') - kb)
        end
        return a, b, c, d
    end
end

local function finish()
    for i = #restore, 1, -1 do restore[i]() end
    restore = {}
    local state = require('src.state')
    local n = run.frames
    local lines = {}
    local function row(label, total)
        local kb = run.kb[label:gsub('^%s+', '')]
        lines[#lines + 1] = string.format('%-26s %7.3f ms', label, total / n * 1000)
            .. (kb and kb / n >= 0.1 and string.format('  %7.1f KB garbage', kb / n) or '')
    end
    lines[#lines + 1] = string.format('%d frames, %d bodies, %d joints, %d Mipos', n,
        state.physicsWorld:getBodyCount(), state.physicsWorld:getJointCount(), run.mipos)
    run.kb['UPDATE (whole)'], run.kb['DRAW (whole)'] = run.kb['(update)'], run.kb['(draw)']
    row('UPDATE (whole)', run.ms['(update)'] or 0)
    local labels = {}
    for label in pairs(run.ms) do
        if not label:match('^%(') and not label:match('^draw') then labels[#labels + 1] = label end
    end
    table.sort(labels, function(a, b) return run.ms[a] > run.ms[b] end)
    for _, label in ipairs(labels) do row('  ' .. label, run.ms[label]) end
    row('DRAW (whole)', run.ms['(draw)'] or 0)
    row('  draw: textured', run.ms['draw: textured'] or 0)
    local kinds = {}
    for kind in pairs(state.drawTimes.ms) do kinds[#kinds + 1] = kind end
    table.sort(kinds, function(a, b) return state.drawTimes.ms[a] > state.drawTimes.ms[b] end)
    for _, kind in ipairs(kinds) do
        lines[#lines + 1] = string.format('    %-22s %7.3f ms  (%d a frame)', kind,
            state.drawTimes.ms[kind] / n * 1000, math.floor((state.drawTimes.count[kind] or 0) / n + 0.5))
    end
    lines[#lines + 1] = string.format('garbage made           %7.1f KB a frame', run.garbage / n)
    local s = run.stats
    lines[#lines + 1] = string.format('gpu: %d draw calls, %d shader switches, %.1f MB textures, %d images, %d canvases',
        s.drawcalls, s.shaderswitches, s.texturememory / 1048576, s.images, s.canvases)
    state.drawTimes = nil
    lib.report = table.concat(lines, '\n')
    print(lib.report)
    run = nil
end

-- Time the next `frames` frames.
function lib.start(frames)
    if run then return 'already running' end
    lib.report = nil
    local state = require('src.state')
    local n = 0
    for _ in pairs(require('src.mipo-registry').getAll()) do n = n + 1 end
    run = { frames = 0, want = frames or 300, ms = {}, kb = {}, garbage = 0, mipos = n }
    state.drawTimes = { frames = 0, ms = {}, count = {} }
    for _, step in ipairs(STEPS) do wrap(require(step[1]), step[2], step[3]) end
    -- world:update is a method on the World type, shared by every world
    local world = state.physicsWorld
    local methods = getmetatable(world).__index
    local update = methods.update
    restore[#restore + 1] = function() methods.update = update end
    methods.update = function(w, ...)
        local t0 = timer()
        update(w, ...)
        if run then run.ms['physics (world:update)'] = (run.ms['physics (world:update)'] or 0) + timer() - t0 end
    end
    -- the whole update and draw: lurker's real functions (love.update is lurker's wrapper)
    local funcs = require('vendor.lurker').lovefuncs
    local lu, ld = funcs.update, funcs.draw
    restore[#restore + 1] = function() funcs.update, funcs.draw = lu, ld end
    funcs.update = function(dt)
        local kb = collectgarbage('count')
        local t0 = timer()
        lu(dt)
        run.ms['(update)'] = (run.ms['(update)'] or 0) + timer() - t0
        local made = math.max(0, collectgarbage('count') - kb)
        run.kb['(update)'] = (run.kb['(update)'] or 0) + made
        run.garbage = run.garbage + made
    end
    funcs.draw = function()
        local kb = collectgarbage('count')
        local t0 = timer()
        ld()
        run.ms['(draw)'] = (run.ms['(draw)'] or 0) + timer() - t0
        local made = math.max(0, collectgarbage('count') - kb)
        run.kb['(draw)'] = (run.kb['(draw)'] or 0) + made
        run.garbage = run.garbage + made
        run.stats = love.graphics.getStats()
        run.frames = run.frames + 1
        if run.frames >= run.want then finish() end
    end
    return 'timing ' .. run.want .. ' frames'
end

return lib

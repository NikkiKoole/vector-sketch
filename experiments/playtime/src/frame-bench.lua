-- Frame timing over the next few seconds: update (physics + scripts), draw (the CPU side)
-- and the time between frames, plus what the slow frames had in them.
-- ./playtime.sh bench [localhost|device] [seconds] runs it over the bridge.
--
-- It wraps lurker's copies of love.update/love.draw, not love.update itself: lurker would
-- keep a wrapper of love.update as the real one on the next hot swap (CLAUDE.md).
-- The run lives on state.benchRun so a hot swap of this file doesn't lose it.
local state = require('src.state')

local lib = {}

local SLOW_MS = 20 -- a frame later than this missed a vsync at 60 Hz

-- With parts: what love.update calls, timed one by one ({ module, function name }).
-- Box2D's world:update can't be wrapped (a userdata method): it's in what's left.
local PARTS = {
    { 'src.blob', 'beforeStep' }, { 'src.blob', 'afterStep' },
    { 'src.script', 'call' },
    { 'src.mipo-joint-guard', 'update' }, { 'src.mipo-actions', 'update' },
    { 'src.signals', 'update' }, { 'src.mipo-voice', 'update' }, { 'src.mipo-chatter', 'update' },
    { 'src.mipo-band', 'update' }, { 'src.physics.snap', 'update' }, { 'src.keep-angle', 'update' },
    { 'src.sound', 'update' }, { 'src.liquid', 'update' },
    { 'src.physics.box2d-pointerjoints', 'handlePointerUpdate' }, { 'src.mipo-face', 'update' },
    { 'src.camera-follow', 'update' },
}

local function wrapParts(run, now)
    run.parts, run.unwrap = {}, {}
    for _, p in ipairs(PARTS) do
        local ok, module = pcall(require, p[1])
        local fn = ok and type(module) == 'table' and module[p[2]]
        if type(fn) == 'function' then
            local name = p[1]:gsub('^src%.', ''):gsub('^physics%.', '') .. '.' .. p[2]
            local part = { name = name, ms = 0 }
            run.parts[#run.parts + 1] = part
            module[p[2]] = function(...)
                local t = now()
                local a, b, c, d = fn(...)
                part.ms = part.ms + (now() - t) * 1000
                return a, b, c, d
            end
            run.unwrap[#run.unwrap + 1] = function() module[p[2]] = fn end
        end
    end
end

-- parts: also time each part of love.update (PARTS)
function lib.start(parts)
    if state.benchRun then return 'already running' end
    local lf = require('vendor.lurker').lovefuncs
    local now = love.timer.getTime
    local run = {
        frames = {}, cur = { u = 0, steps = 0, gc = false },
        origUpdate = lf.update, origDraw = lf.draw,
        dropped = state.loopDroppedSteps or 0, -- steps the game loop let go (src/game-loop.lua)
    }
    state.benchRun = run
    if parts then wrapParts(run, now) end
    lf.update = function(...)
        local kb = collectgarbage('count')
        local t = now()
        run.origUpdate(...)
        local c = run.cur
        c.u = c.u + (now() - t)
        c.steps = c.steps + 1
        if collectgarbage('count') < kb then c.gc = true end -- memory went down: a GC step ran
    end
    lf.draw = function(...)
        local kb = collectgarbage('count')
        local t = now()
        run.origDraw(...)
        local c = run.cur
        run.frames[#run.frames + 1] = {
            u = c.u * 1000, d = (now() - t) * 1000, dt = love.timer.getDelta() * 1000,
            steps = c.steps, gc = c.gc or collectgarbage('count') < kb, kb = collectgarbage('count'),
        }
        run.cur = { u = 0, steps = 0, gc = false }
    end
    return 'started'
end

local function stats(frames, key)
    local values = {}
    local sum = 0
    for i, f in ipairs(frames) do
        values[i] = f[key]
        sum = sum + f[key]
    end
    table.sort(values)
    local function at(q) return values[math.max(1, math.ceil(#values * q))] end
    return string.format('mean %5.2f  p50 %5.2f  p95 %5.2f  max %5.2f', sum / #values, at(0.5), at(0.95),
        values[#values])
end

-- Stops the run and returns the report as text.
function lib.stop()
    local run = state.benchRun
    if not run then return 'not running' end
    local lf = require('vendor.lurker').lovefuncs
    lf.update, lf.draw = run.origUpdate, run.origDraw
    for _, unwrap in ipairs(run.unwrap or {}) do unwrap() end
    state.benchRun = nil
    local frames = run.frames
    if #frames == 0 then return 'no frames' end

    local steps, gcFrames, slow = 0, 0, {}
    for i, f in ipairs(frames) do
        steps = steps + f.steps
        if f.gc then gcFrames = gcFrames + 1 end
        if f.dt > SLOW_MS then slow[#slow + 1] = i end
    end
    local w, h = love.graphics.getPixelDimensions()
    local lines = {
        string.format('%s, %dx%d px, %d frames, %.0f fps, %.2f physics steps a frame, Lua %.1f MB',
            love.system.getOS(), w, h, #frames, love.timer.getFPS(), steps / #frames,
            collectgarbage('count') / 1024),
        '  frame   ' .. stats(frames, 'dt'),
        '  update  ' .. stats(frames, 'u'),
        '  draw    ' .. stats(frames, 'd'),
        string.format('  over %d ms: %d frames (%.1f%%); frames with a GC step: %d', SLOW_MS, #slow,
            100 * #slow / #frames, gcFrames),
    }
    local dropped = (state.loopDroppedSteps or 0) - run.dropped
    if dropped > 0 then -- the loop's time budget or cap: the game ran slower than real time
        lines[#lines + 1] = string.format('  slow motion: game time at %.0f%% of real time (%d steps dropped)',
            100 * steps / (steps + dropped), dropped)
    end
    if run.parts then
        local updateMs, partsMs = 0, 0
        for _, f in ipairs(frames) do updateMs = updateMs + f.u end
        table.sort(run.parts, function(a, b) return a.ms > b.ms end)
        lines[#lines + 1] = '  update, ms a frame:'
        for _, p in ipairs(run.parts) do
            partsMs = partsMs + p.ms
            if p.ms / #frames >= 0.05 then
                lines[#lines + 1] = string.format('    %5.2f  %s', p.ms / #frames, p.name)
            end
        end
        lines[#lines + 1] = string.format('    %5.2f  the rest: Box2D world:update, input, the loop',
            (updateMs - partsMs) / #frames)
    end
    -- The slow frames themselves. A slow frame's own update/draw can be small: then the time
    -- went before it (the frame before ran long) or outside Lua (present, the GPU, the OS).
    for n, i in ipairs(slow) do
        if n > 12 then
            lines[#lines + 1] = string.format('  … %d more', #slow - 12)
            break
        end
        local f, before = frames[i], frames[i - 1]
        lines[#lines + 1] = string.format('  #%-4d frame %5.1f  update %5.1f (%d steps)%s  draw %4.1f%s',
            i, f.dt, f.u, f.steps, f.gc and ' GC' or '   ', f.d,
            before and string.format('   | before: update %4.1f%s draw %4.1f', before.u,
                before.gc and ' GC' or '', before.d) or '')
    end
    return table.concat(lines, '\n')
end

return lib

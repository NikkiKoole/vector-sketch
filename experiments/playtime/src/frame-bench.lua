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

function lib.start()
    if state.benchRun then return 'already running' end
    local lf = require('vendor.lurker').lovefuncs
    local now = love.timer.getTime
    local run = {
        frames = {}, cur = { u = 0, steps = 0, gc = false },
        origUpdate = lf.update, origDraw = lf.draw,
    }
    state.benchRun = run
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

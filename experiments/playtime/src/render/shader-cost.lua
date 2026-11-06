-- shader-cost.lua — what a shader costs the GPU, measured: each entry draws its thing many times over a
-- square canvas, and the time until the GPU is done (a one-pixel read waits for it) is the cost.
-- Returned per million pixels drawn (ms/MP), so a shape's size on screen doesn't matter: a phone
-- screen is ~1 MP (iPhone SE 2: 0.75 x 1.33), so 1 ms/MP is about 1 ms for a full-screen layer.
-- LÖVE 11 has no GPU timers; this times from the CPU, so a few rounds are taken and the fastest kept.
-- Small differences (under ~0.1 ms/MP on a desktop GPU) are noise. Used by material-check (x).
--
-- lib.measure(entries, opts) -> { { name, msPerMP, relative }, ... }
--   entries: { { name = ..., draw = function(size) ... end }, ... }  draw covers the size x size canvas
--   opts.size (512), opts.repeats (80 draws a round), opts.rounds (7), opts.baseline (an entry's name:
--   relative is measured against it, else against the first)
local lib = {}

local function waitForGPU(canvas)
    love.graphics.setCanvas()
    canvas:newImageData(1, 1, 0, 0, 1, 1) -- a read waits until everything drawn to it is done
end

function lib.measure(entries, opts)
    opts = opts or {}
    local size = opts.size or 512
    local repeats = opts.repeats or 80
    local rounds = opts.rounds or 7
    local canvas = love.graphics.newCanvas(size, size)
    local outer = love.graphics.getCanvas()
    love.graphics.push('all')
    love.graphics.origin()
    local results = {}
    for _, entry in ipairs(entries) do
        local best = math.huge
        for round = 0, rounds do
            love.graphics.setCanvas(canvas)
            love.graphics.clear(0, 0, 0, 0)
            waitForGPU(canvas)
            local t0 = love.timer.getTime()
            love.graphics.setCanvas(canvas)
            for _ = 1, repeats do entry.draw(size) end
            waitForGPU(canvas)
            local ms = (love.timer.getTime() - t0) * 1000
            if round > 0 then best = math.min(best, ms) end -- round 0 warms up (shader compile, uploads)
        end
        local mp = size * size * repeats / 1e6
        results[#results + 1] = { name = entry.name, msPerMP = best / mp }
    end
    love.graphics.pop()
    love.graphics.setCanvas(outer)
    local base = results[1]
    for _, r in ipairs(results) do
        if r.name == opts.baseline then base = r end
    end
    for _, r in ipairs(results) do r.relative = r.msPerMP / math.max(1e-6, base.msPerMP) end
    return results
end

return lib

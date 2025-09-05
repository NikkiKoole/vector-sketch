local now = (love and love.timer and love.timer.getTime)
local lib = {}

-- bench(fn, seconds[, ...]) -> stats table
function lib.bench(fn, seconds, ...)
    seconds = seconds or 0.25
    -- warm-up (helps LuaJIT compile hot path)
    for _ = 1, 1e4 do fn(...) end

    collectgarbage("collect"); collectgarbage("collect")

    local n, t0 = 0, now()
    local t1 = t0
    repeat
        fn(...); n = n + 1
        t1 = now()
    until (t1 - t0) >= seconds

    local dt = t1 - t0
    return {
        calls         = n,
        secs          = dt,
        ns_per_call   = (dt / n) * 1e9,
        calls_per_sec = n / dt,
    }
end

-- pretty print
function lib.show(tag, s)
    print(("%s  |  %.1fk calls/s  |  %.1f ns/call  |  %.3f s total"):format(
        tag, s.calls_per_sec / 1e3, s.ns_per_call, s.secs))
end

function lib.compare(nameA, fnA, nameB, fnB, seconds, ...)
    local a = lib.bench(fnA, seconds, ...)
    local b = lib.bench(fnB, seconds, ...)
    lib.show(nameA, a); lib.show(nameB, b)
    local speedup = a.ns_per_call / b.ns_per_call
    print(("Speedup %s -> %s: x%.2f"):format(nameA, nameB, speedup))
end

return lib

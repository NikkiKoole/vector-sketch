-- physics-units.lua
-- The game's tuned numbers (speeds, forces, gains) are written as they were tuned:
-- at REFERENCE_METER pixels per metre. These turn them into what they have to be at
-- the meter the world runs at (state.world.meter, love.physics.getMeter()), so a
-- bigger meter (smaller, faster things in the same pixels) plays the same way.
--
-- With k = meter / REFERENCE_METER and the same pixel sizes and densities:
--   gravity in px/s^2 grows k times, so a fall of the same pixels takes 1/sqrt(k)
--   the time: speeds (px/s) and rates (1/s: rad/s, Hz, P gains on angle) grow sqrt(k),
--   accelerations (px/s^2, rad/s^2) grow k;
--   mass (density per m^2 over the same pixels) shrinks k^2 (mass()), so a force (mass * px/s^2)
--   is 1/k and an impulse (mass * px/s) 1/k^1.5.
-- Masses read from bodies and inertias (applyTorque(inertia * alpha)) take care of
-- themselves. Values the code measures (an impact speed) go the other way with
-- toReference*, so thresholds keep their tuned numbers. Durations in seconds are left
-- alone: a daze lasts as long at any meter.
-- At the reference meter every function returns its input.
local lib = {}

lib.REFERENCE_METER = 100

function lib.meter()
    return (love and love.physics and love.physics.getMeter()) or lib.REFERENCE_METER
end

-- k and sqrt(k) for the last meter seen: these run thousands of times a step
local lastMeter, k, rootK = nil, 1, 1
local function factors()
    local meter = lib.meter()
    if meter ~= lastMeter then
        lastMeter, k = meter, meter / lib.REFERENCE_METER
        rootK = math.sqrt(k)
    end
    return k, rootK
end

-- k: how many times bigger the meter is than the reference.
function lib.scale()
    return (factors())
end

function lib.speed(v) local _, r = factors(); return v * r end
function lib.rate(x) local _, r = factors(); return x * r end
function lib.accel(a) return a * factors() end
function lib.mass(m) return m / factors() ^ 2 end
function lib.force(f) return f / factors() end
function lib.impulse(j) local s, r = factors(); return j / (s * r) end

-- Physics steps per second. A fall of the same pixels is over sqrt(k) times sooner, so the
-- step shrinks with it: each step then covers the same part of every motion as 60 a second
-- at the reference meter, and counts in steps (debounces, check slices) keep their meaning.
-- At 400 px per metre and 60 steps Mipo legs sagged and splayed on landing: the gravity
-- added per step was 4x, the angle controller only 2x as quick.
lib.REFERENCE_STEPS = 60
function lib.stepsPerSecond(meter)
    return lib.REFERENCE_STEPS * math.sqrt((meter or lib.meter()) / lib.REFERENCE_METER)
end

-- The meter from the command line: `--meter <px per metre>` (love . --meter 400,
-- METER=400 ./playtime.sh start, love . --specs --meter 400). It's set once, before the
-- world exists: LÖVE's meter is global and changing it under live bodies moves them.
function lib.meterFromArgs(args)
    for i = 1, #(args or {}) do
        if args[i] == '--meter' then return tonumber(args[i + 1]) end
    end
    return nil
end

-- What `mass` weighs (a force) at 9.8 m/s^2: grab and pull strengths are counted in weights.
function lib.weight(mass) return mass * 9.8 * lib.meter() end

function lib.toReferenceSpeed(v) local _, r = factors(); return v / r end
function lib.toReferenceForce(f) return f * factors() end

return lib

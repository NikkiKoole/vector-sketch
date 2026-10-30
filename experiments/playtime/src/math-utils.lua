-- math-utils.lua
-- The small ones live here: clamp, lerp, clampedLerp, remap, dist, wrapAngle, normalizeAxis, sign.
-- The rest went to their own modules (CODE-SPLITS-2026-10.md SPLIT7) and math-utils still hands
-- them out under the old names, so `mathutils.getCenterOfPoints` keeps working:
--   src/polygon.lua       polygon transforms, centres, bounds, edges, vertices, rotatePoint
--   src/spline.lua        path length, spline points, even resampling
--   src/polygon-ops.lua   triangulate, decompose, clip, split
--   src/mesh-weights.lua  mean value coordinates, closest-edge repositioning
-- They pass the call on instead of copying the function, so a hot reload of a module reaches
-- everyone who required math-utils. Those modules don't require math-utils: deps point one way.
local polygon = require('src.polygon')
local spline = require('src.spline')
local polygonOps = require('src.polygon-ops')
local meshWeights = require('src.mesh-weights')

local lib = {}

-- min wins when min > max, like the math.max(min, math.min(max, x)) it replaces
function lib.clamp(x, min, max)
    return math.max(min, math.min(max, x))
end

function lib.lerp(a, b, t)
    return a + (b - a) * t
end

function lib.clampedLerp(a, b, t)
    return a + (b - a) * lib.clamp(t, 0, 1)
end

-- x from [inMin, inMax] to [outMin, outMax], held inside the out range
function lib.remap(x, inMin, inMax, outMin, outMax)
    return lib.clampedLerp(outMin, outMax, (x - inMin) / (inMax - inMin))
end

function lib.dist(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- an angle in [-pi, pi)
function lib.wrapAngle(a)
    return (a + math.pi) % (2 * math.pi) - math.pi
end

function lib.normalizeAxis(x, y)
    local magnitude = math.sqrt(x ^ 2 + y ^ 2)
    if magnitude == 0 then
        return 1, 0 -- Default to (1, 0) if the vector is zero
    else
        return x / magnitude, y / magnitude
    end
end

function lib.sign(value)
    if value == nil or value < 0 then return -1 else return 1 end
end

for _, module in ipairs({ polygon, spline, polygonOps, meshWeights }) do
    for name, fn in pairs(module) do
        if type(fn) == 'function' then
            assert(lib[name] == nil, 'math-utils: two modules define ' .. name)
            lib[name] = function(...) return module[name](...) end
        end
    end
end

return lib

-- limb.lua — generate a smooth ribbon polygon around a chain.
--
-- Samples the chain as an arc-length parameterised polyline at N
-- evenly-spaced steps, offsets by ±halfWidth along the local tangent.
-- More samples = smoother bend, more polygon verts for the (t, s)
-- decomposition to work with. Miter-clamped at sharp bends so the
-- inner edge doesn't self-intersect.

local M = {}

local function arcLengths(polyline)
    local out = { 0 }
    local total = 0
    local n = #polyline / 2
    for i = 1, n - 1 do
        local ax, ay = polyline[(i - 1) * 2 + 1], polyline[(i - 1) * 2 + 2]
        local bx, by = polyline[i * 2 + 1], polyline[i * 2 + 2]
        local dx, dy = bx - ax, by - ay
        total = total + math.sqrt(dx * dx + dy * dy)
        out[i + 1] = total
    end
    return out, total
end

-- Evaluate a polyline at arc-length `s`, return (x, y, tx, ty) where
-- (tx, ty) is the unit tangent at that point.
local function polylineAt(polyline, arcs, s)
    local n = #polyline / 2
    for i = 1, n - 1 do
        if s <= arcs[i + 1] + 1e-9 then
            local ax, ay = polyline[(i - 1) * 2 + 1], polyline[(i - 1) * 2 + 2]
            local bx, by = polyline[i * 2 + 1], polyline[i * 2 + 2]
            local segLen = arcs[i + 1] - arcs[i]
            local u = segLen > 1e-9 and (s - arcs[i]) / segLen or 0
            local x = ax + u * (bx - ax)
            local y = ay + u * (by - ay)
            local dx, dy = bx - ax, by - ay
            local L = math.sqrt(dx * dx + dy * dy)
            local tx = L > 1e-9 and dx / L or 1
            local ty = L > 1e-9 and dy / L or 0
            return x, y, tx, ty
        end
    end
    -- past end: return last point, last tangent
    local i = n - 1
    local ax, ay = polyline[(i - 1) * 2 + 1], polyline[(i - 1) * 2 + 2]
    local bx, by = polyline[i * 2 + 1], polyline[i * 2 + 2]
    local dx, dy = bx - ax, by - ay
    local L = math.sqrt(dx * dx + dy * dy)
    return bx, by, L > 1e-9 and dx / L or 1, L > 1e-9 and dy / L or 0
end

-- Build a ribbon polygon by sampling the chain at `segments+1` points
-- along its arc length, offsetting each ±halfWidth along the left-
-- normal. Returns a closed polygon: first (N+1) coords are the left
-- side (forward), last (N+1) coords are the right side (backward).
-- N = segments. So polygon has 2*(N+1) coord pairs.
function M.ribbonAroundChain(chain, halfWidth, segments)
    segments = segments or 24
    local arcs, total = arcLengths(chain)
    if total < 1e-6 then return nil end

    local left, right = {}, {}
    for i = 0, segments do
        local s = (i / segments) * total
        local x, y, tx, ty = polylineAt(chain, arcs, s)
        -- left-normal of tangent
        local nx, ny = -ty, tx
        left[#left + 1] = x + nx * halfWidth
        left[#left + 1] = y + ny * halfWidth
        right[#right + 1] = x - nx * halfWidth
        right[#right + 1] = y - ny * halfWidth
    end

    local poly = {}
    for i = 1, #left, 2 do
        poly[#poly + 1] = left[i]
        poly[#poly + 1] = left[i + 1]
    end
    for i = #right - 1, 1, -2 do
        poly[#poly + 1] = right[i]
        poly[#poly + 1] = right[i + 1]
    end
    return poly
end

return M

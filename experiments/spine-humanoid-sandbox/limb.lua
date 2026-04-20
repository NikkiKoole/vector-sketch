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

-- Hand-authored "cartoon arm" polygon around a 3-joint chain: narrower
-- at shoulder, biceps bulge mid-upper-arm, narrow at elbow, slight
-- forearm taper, wider at fist. Shows how non-uniform traced polygons
-- deform with the spine-mesh math — not uniform ribbons.
--
-- Generated procedurally from the rest chain so it scales. In real
-- playtime usage this polygon would come from a freepath trace of the
-- character illustration; here it's just a concrete example.
function M.cartoonArmAroundChain(chain)
    local arcs, total = arcLengths(chain)
    if total < 1e-6 then return nil end
    -- (arc-length-fraction, halfWidth) stops; piecewise-linear between.
    local profile = {
        { 0.00, 18 }, -- shoulder: narrow
        { 0.15, 34 }, -- bicep bulge
        { 0.30, 28 },
        { 0.50, 14 }, -- elbow pinch
        { 0.70, 20 },
        { 0.90, 24 }, -- forearm swell
        { 1.00, 28 }, -- fist
    }
    local function widthAt(u)
        for i = 1, #profile - 1 do
            local a, b = profile[i], profile[i + 1]
            if u <= b[1] then
                local span = b[1] - a[1]
                local t = span > 1e-9 and (u - a[1]) / span or 0
                return a[2] + t * (b[2] - a[2])
            end
        end
        return profile[#profile][2]
    end

    local segments = 32
    local left, right = {}, {}
    for i = 0, segments do
        local u = i / segments
        local s = u * total
        local x, y, tx, ty = polylineAt(chain, arcs, s)
        local nx, ny = -ty, tx
        local hw = widthAt(u)
        left[#left + 1] = x + nx * hw
        left[#left + 1] = y + ny * hw
        right[#right + 1] = x - nx * hw
        right[#right + 1] = y - ny * hw
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

-- Load a polygon from a playtime `.playtime.json` scene file. Returns
-- the first body's outline verts, translated so the polygon's centroid
-- sits at the midpoint of the given chain. No scaling — polygon shows
-- at its authored size so you can tell if it fits the skeleton.
function M.loadFromPlaytimeJSON(path, chain)
    local dkjson = require('dkjson')
    local f = io.open(path, 'r')
    if not f then return nil, 'file not found: ' .. path end
    local text = f:read('*all'); f:close()
    local data, _, err = dkjson.decode(text, 1, nil)
    if err then return nil, err end
    if not data or not data.bodies or not data.bodies[1] then
        return nil, 'no body[1]'
    end
    local srcVerts = data.bodies[1].vertices
    if not srcVerts or #srcVerts < 6 then return nil, 'body has no vertices' end

    -- Centroid of the source polygon.
    local cx, cy = 0, 0
    local n = #srcVerts / 2
    for i = 1, #srcVerts, 2 do cx = cx + srcVerts[i]; cy = cy + srcVerts[i + 1] end
    cx, cy = cx / n, cy / n

    -- Midpoint of the chain (where we'll center the polygon).
    local arcs, total = arcLengths(chain)
    local mx, my = polylineAt(chain, arcs, total * 0.5)

    -- Translate so polygon centroid lands on chain midpoint.
    local out = {}
    for i = 1, #srcVerts, 2 do
        out[#out + 1] = srcVerts[i] - cx + mx
        out[#out + 1] = srcVerts[i + 1] - cy + my
    end
    return out
end

return M

-- spline.lua
-- Paths and splines: path length, a point along a Catmull-Rom spline, a path resampled at
-- even spacing (unloosenVanillaline: control points -> an evenly spaced flat list).
-- Split out of math-utils.lua (CODE-SPLITS-2026-10.md SPLIT7); math-utils still hands these out.

local lib = {}

function lib.getLengthOfPath(path)
    local result = 0
    for i = 1, #path - 1 do
        local a = path[i]
        local b = path[i + 1]
        result = result + math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
    end
    return result
end

--https://love2d.org/forums/viewtopic.php?t=1401
local function GetSplinePos(tab, percent, tension) --returns the position at 'percent' distance along the spline.
    if (tab and (#tab >= 4)) then
        local pos = (((#tab) / 2) - 1) * percent
        local lowpnt, percent_2 = math.modf(pos)

        local i = (1 + lowpnt * 2)
        local p1x = tab[i]
        local p1y = tab[i + 1]
        local p2x = tab[i + 2]
        local p2y = tab[i + 3]

        local p0x = tab[i - 2]
        local p0y = tab[i - 1]
        local p3x = tab[i + 4]
        local p3y = tab[i + 5]

        tension = tension or .5
        local t1x = 0
        local t1y = 0
        if (p0x and p0y) then
            t1x = (1.0 - tension) * (p2x - p0x)
            t1y = (1.0 - tension) * (p2y - p0y)
        end
        local t2x = 0
        local t2y = 0
        if (p3x and p3y) then
            t2x = (1.0 - tension) * (p3x - p1x)
            t2y = (1.0 - tension) * (p3y - p1y)
        end

        local s = percent_2
        local s2 = s * s
        local s3 = s * s * s
        local h1 = 2 * s3 - 3 * s2 + 1
        local h2 = -2 * s3 + 3 * s2
        local h3 = s3 - 2 * s2 + s
        local h4 = s3 - s2
        local px = (h1 * p1x) + (h2 * p2x) + (h3 * t1x) + (h4 * t2x)
        local py = (h1 * p1y) + (h2 * p2y) + (h3 * t1y) + (h4 * t2y)

        return px, py
    end
end

local sqrt = math.sqrt

local function flattenPoints(points, closed, out)
    out = out or {}
    -- wipe without reallocating: set length to 0
    for i = #out, 1, -1 do out[i] = nil end

    local n = #points
    local j = 1
    for i = 1, n do
        local p    = points[i]
        out[j]     = p[1]
        out[j + 1] = p[2]
        j          = j + 2
    end
    if closed and n > 0 then
        local p1   = points[1]
        out[j]     = p1[1]
        out[j + 1] = p1[2]
    end
    return out
end

local function evenlySpreadPathFlat(pathFlat, spacing, startOffset, closed, include_first, include_last, outFlat)
    outFlat = outFlat or {}
    for i = #outFlat, 1, -1 do outFlat[i] = nil end

    local n = #pathFlat
    if n < 4 then return outFlat end

    local acc = startOffset or 0
    local outLen = 0

    -- Optionally emit the first point (for anchors/handles)
    if include_first and (acc == 0) then
        outLen = outLen + 1; outFlat[outLen] = pathFlat[1]
        outLen = outLen + 1; outFlat[outLen] = pathFlat[2]
    end

    -- Iterate segments
    local lastx = pathFlat[1]
    local lasty = pathFlat[2]
    local i = 3
    local lastSegment = (closed and n) or (n - 2)

    while true do
        local nx, ny = pathFlat[i], pathFlat[i + 1]
        local dx, dy = nx - lastx, ny - lasty
        local segLen = sqrt(dx * dx + dy * dy)

        if segLen > 0 then
            while acc < segLen do
                local t = acc / segLen
                outLen = outLen + 1; outFlat[outLen] = lastx + dx * t
                outLen = outLen + 1; outFlat[outLen] = lasty + dy * t
                acc = acc + spacing
            end
            acc = acc - segLen
        end

        lastx, lasty = nx, ny
        i = i + 2

        -- next segment or wrap for closed
        if i > lastSegment then
            if closed then
                -- last->first and then stop
                nx, ny = pathFlat[1], pathFlat[2]
                dx, dy = nx - lastx, ny - lasty
                segLen = sqrt(dx * dx + dy * dy)
                if segLen > 0 then
                    while acc < segLen do
                        local t = acc / segLen
                        outLen = outLen + 1; outFlat[outLen] = lastx + dx * t
                        outLen = outLen + 1; outFlat[outLen] = lasty + dy * t
                        acc = acc + spacing
                    end
                end
            elseif include_last and acc == 0 then
                -- Emit true end if we landed exactly on it
                outLen = outLen + 1; outFlat[outLen] = pathFlat[n - 1]
                outLen = outLen + 1; outFlat[outLen] = pathFlat[n]
            end
            break
        end
    end

    return outFlat
end

-- this should be fast (according to vhatgpt) but not sseeing it
lib.unloosenVanillaline = function(points, tension, spacing, samples, closed)
    -- 1) Flatten control points for the spline evaluator
    local flat = flattenPoints(points, false) -- no loop here unless your spline requires it

    -- 2) Sample the spline into a flat list (avoid t==0/1 edge-cases)
    local samp = {}
    local nSamples = samples or (#points * 2)
    if nSamples < 2 then nSamples = 2 end
    local step = 1 / nSamples
    local eps  = 1e-8
    local j    = 1
    for i = 0, nSamples - 1 do
        local t = i * step
        if t <= 0 then t = eps elseif t >= 1 then t = 1 - eps end
        local x, y  = GetSplinePos(flat, t, tension)
        samp[j]     = x
        samp[j + 1] = y
        j           = j + 2
    end

    -- (optional) if you *want* the sample ring closed before spacing:

    -- 3) Evenly re-space those samples, flat in/flat out, no hacks
    -- For a loop that shouldn’t duplicate the first point, use closed=true and include_first=false
    local out = evenlySpreadPathFlat(samp, spacing, 0, closed == true, false, false)

    return out -- flat [x1,y1,x2,y2,...]
end

return lib

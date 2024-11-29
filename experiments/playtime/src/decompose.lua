-- decompose_complex.lua
-- A module for decomposing complex polygons into simpler polygons by handling intersections.

local decompose_complex = {}

-- Utility function to concatenate two tables.
local function tableConcat(t1, t2)
    for i = 1, #t2 do
        table.insert(t1, t2[i])
    end
    return t1
end

-- Utility function to calculate the distance between two points.
local function distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

-- Utility function to check if a point is inside a polygon.
-- Implements the ray-casting algorithm.
local function pointInPath(x, y, poly)
    local inside = false
    local n = #poly
    for i = 1, n, 2 do
        local j = (i + 2) % n
        if j == 0 then j = n end
        local xi, yi = poly[i], poly[i + 1]
        local xj, yj = poly[j], poly[j + 1]

        local intersect = ((yi > y) ~= (yj > y)) and
            (x < (xj - xi) * (y - yi) / (yj - yi + 1e-10) + xi)
        if intersect then
            inside = not inside
        end
    end
    return inside
end

-- Function to find the intersection point between two line segments.
local function getLineIntersection(p0_x, p0_y, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y)
    local s1_x = p1_x - p0_x
    local s1_y = p1_y - p0_y
    local s2_x = p3_x - p2_x
    local s2_y = p3_y - p2_y

    local denom = (-s2_x * s1_y + s1_x * s2_y)
    if denom == 0 then return nil end -- Parallel lines

    local s = (-s1_y * (p0_x - p2_x) + s1_x * (p0_y - p2_y)) / denom
    local t = (s2_x * (p0_y - p2_y) - s2_y * (p0_x - p2_x)) / denom

    if s >= 0 and s <= 1 and t >= 0 and t <= 1 then
        local intersect_x = p0_x + (t * s1_x)
        local intersect_y = p0_y + (t * s1_y)
        return intersect_x, intersect_y
    end

    return nil
end

-- Function to find all collision points (intersections) within a polygon.
local function getCollisions(poly)
    local collisions = {}
    local n = #poly

    for outeri = 1, n, 2 do
        local ax, ay = poly[outeri], poly[outeri + 1]
        local ni = outeri + 2
        if ni > n then ni = 1 end
        local bx, by = poly[ni], poly[ni + 1]

        for inneri = 1, n, 2 do
            -- Skip adjacent edges
            if inneri ~= outeri and inneri ~= ((outeri + 2 - 1) % n) + 1 then
                local cx, cy = poly[inneri], poly[inneri + 1]
                local ni_inner = inneri + 2
                if ni_inner > n then ni_inner = 1 end
                local dx, dy = poly[ni_inner], poly[ni_inner + 1]

                local ix, iy = getLineIntersection(ax, ay, bx, by, cx, cy, dx, dy)
                if ix and iy then
                    -- Avoid adding shared vertices as intersections
                    if not ((ax == cx and ay == cy) or (ax == dx and ay == dy) or
                            (bx == cx and by == cy) or (bx == dx and by == dy)) then
                        local collision = { i1 = outeri, i2 = inneri, x = ix, y = iy }
                        -- Check for duplicate collisions
                        local duplicate = false
                        for _, existing in ipairs(collisions) do
                            if (existing.i1 == collision.i2 and existing.i2 == collision.i1) then
                                duplicate = true
                                break
                            end
                        end
                        if not duplicate then
                            table.insert(collisions, collision)
                        end
                    end
                end
            end
        end
    end

    return collisions
end

-- Function to split a polygon into two at a given intersection point.
local function splitPoly(poly, intersection)
    local function getIndices()
        local biggestIndex = math.max(intersection.i1, intersection.i2)
        local smallestIndex = math.min(intersection.i1, intersection.i2)
        return smallestIndex, biggestIndex
    end

    local smallestIndex, biggestIndex = getIndices()
    local wrap = {}
    local back = {}
    local bb = biggestIndex

    -- Build the 'wrap' polygon
    while bb ~= smallestIndex do
        bb = bb + 2
        if bb > #poly - 1 then
            bb = 1
        end
        table.insert(wrap, poly[bb])
        table.insert(wrap, poly[bb + 1])
    end
    table.insert(wrap, intersection.x)
    table.insert(wrap, intersection.y)

    -- Build the 'back' polygon
    local bk = biggestIndex
    while bk ~= smallestIndex do
        table.insert(back, poly[bk])
        table.insert(back, poly[bk + 1])
        bk = bk - 2
        if bk < 1 then
            bk = #poly - 1
        end
    end
    table.insert(back, intersection.x)
    table.insert(back, intersection.y)

    return wrap, back
end


function decompose_complex.decompose_complex_poly(poly, result)
    result = result or {}
    local intersections = getCollisions(poly)

    if #intersections == 0 then
        tableConcat(result, { poly })
        return result
    end

    -- Process only the first intersection to avoid redundant splits
    local intersection = intersections[1]
    local p1, p2 = splitPoly(poly, intersection)

    -- Recursively decompose the resulting polygons
    decompose_complex.decompose_complex_poly(p1, result)
    decompose_complex.decompose_complex_poly(p2, result)

    return result
end

return decompose_complex

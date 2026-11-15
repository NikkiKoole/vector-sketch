-- polygon-ops.lua
-- Cutting polygons up: triangulate to indices, decompose a self-intersecting polygon,
-- Sutherland-Hodgman clipping, split at an intersection.
-- Split out of math-utils.lua (CODE-SPLITS-2026-10.md SPLIT7); math-utils still hands these out.

local lib = {}

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

-- The first crossing in a polygon (flat { x1, y1, ... }) as { i1, i2, x, y } (i1, i2: the two
-- edges' first x indices), or nil. "First" in the order decompose always used: outer edge i1 from
-- the start, inner edge i2 from the start, adjacent edges and edges meeting at an equal vertex
-- skipped. Was getCollisions, which tried every pair and found every crossing, where decompose took
-- only the first (2 ms for a 100-point mouth on the Mac, 10 on the phone). Now only edge pairs whose
-- boxes overlap are tried (a sweep over the edges sorted by x), in that same order, with the same
-- intersection maths: the same answer (spec/polygon-decompose_spec.lua). When native/desound/
-- polydecomp.c is there the same runs in C (lib.firstCollisionNative).
local boxX0, boxX1, boxY0, boxY1 = {}, {}, {}, {} -- per edge, reused (decompose is done with them before it recurses)
local byX, pairs_ = {}, {}
local BOX_PAD = 1e-6 -- px: a box rejects only a pair clearly apart, never one rounding could call touching
local function byX0(a, b) return boxX0[a] < boxX0[b] end

-- the crossing of outer edge i and inner edge j (first x indices), or nil
local function crossing(poly, n, i, j)
    local ni = i + 2
    if ni > n then ni = 1 end
    local nj = j + 2
    if nj > n then nj = 1 end
    local ax, ay, bx, by = poly[i], poly[i + 1], poly[ni], poly[ni + 1]
    local cx, cy, dx, dy = poly[j], poly[j + 1], poly[nj], poly[nj + 1]
    local ix, iy = getLineIntersection(ax, ay, bx, by, cx, cy, dx, dy)
    -- Avoid adding shared vertices as intersections
    if ix and iy and not ((ax == cx and ay == cy) or (ax == dx and ay == dy) or
            (bx == cx and by == cy) or (bx == dx and by == dy)) then
        return { i1 = i, i2 = j, x = ix, y = iy }
    end
end

-- every pair in order, no boxes: for a polygon with a NaN in it (it can't be sorted)
local function firstCollisionAllPairs(poly, n)
    for i = 1, n, 2 do
        local nextEdge = ((i + 2 - 1) % n) + 1
        for j = 1, n, 2 do
            if j ~= i and j ~= nextEdge then
                local hit = crossing(poly, n, i, j)
                if hit then return hit end
            end
        end
    end
end

local function firstCollisionLua(poly)
    local n = #poly
    if n % 2 == 1 and n > 1 then error('polygon with an odd number of coordinates') end
    local m = n / 2
    for i = 1, n, 2 do
        local j = i + 2
        if j > n then j = 1 end
        local x0, x1, y0, y1 = poly[i], poly[j], poly[i + 1], poly[j + 1]
        if x0 ~= x0 or y0 ~= y0 then return firstCollisionAllPairs(poly, n) end
        if x0 > x1 then x0, x1 = x1, x0 end
        if y0 > y1 then y0, y1 = y1, y0 end
        boxX0[i], boxX1[i], boxY0[i], boxY1[i] = x0 - BOX_PAD, x1 + BOX_PAD, y0 - BOX_PAD, y1 + BOX_PAD
        byX[(i + 1) / 2] = i
    end
    for k = m + 1, #byX do byX[k] = nil end
    table.sort(byX, byX0)

    -- the edge pairs whose boxes overlap, both ways round, as one number each (outer, then inner)
    local np, key = 0, n + 1
    for p = 1, m do
        local a = byX[p]
        local ax1, ay0, ay1 = boxX1[a], boxY0[a], boxY1[a]
        local aNext = a + 2
        if aNext > n then aNext = 1 end
        for q = p + 1, m do
            local b = byX[q]
            if boxX0[b] > ax1 then break end
            -- adjacent edges never count: the next one is skipped, the one before meets at an equal vertex
            if b ~= aNext and boxY0[b] <= ay1 and ay0 <= boxY1[b] then
                local bNext = b + 2
                if bNext > n then bNext = 1 end
                if a ~= bNext then
                    pairs_[np + 1], pairs_[np + 2] = a * key + b, b * key + a
                    np = np + 2
                end
            end
        end
    end
    for k = np + 1, #pairs_ do pairs_[k] = nil end
    table.sort(pairs_)
    for k = 1, np do
        local i = math.floor(pairs_[k] / key)
        local hit = crossing(poly, n, i, pairs_[k] - i * key)
        if hit then return hit end
    end
    return nil
end
lib.firstCollisionLua = firstCollisionLua

local function tableConcat(t1, t2)
    for i = 1, #t2 do
        table.insert(t1, t2[i])
    end
    return t1
end

-- Triangulate `polyVerts` (flat {x1,y1,x2,y2,...}) and return a flat list of
-- vertex indices (1-based, into polyVerts) describing the triangles. Three
-- consecutive indices = one triangle.
--
-- Uses nearest-vertex matching (not exact coord equality) because
-- love.math.triangulate can produce coords that differ from the input by
-- tiny floating-point amounts (~1e-4) even though no Steiner points are
-- introduced. Formatted string lookups fail on those boundary cases.
--
-- Returns nil if triangulation fails or produces a vertex more than
-- `tol` away from every input vertex (which would mean real Steiner
-- points — caller should fall back to per-frame triangulation).
function lib.triangulateToIndices(polyVerts, tol)
    tol = tol or 0.01
    local tolSq = tol * tol
    local ok, tris = pcall(love.math.triangulate, polyVerts)
    if not ok or not tris then return nil end
    local numVerts = math.floor(#polyVerts / 2)
    local indices = {}
    for j = 1, #tris do
        local tri = tris[j]
        for k = 0, 2 do
            local tx, ty = tri[k * 2 + 1], tri[k * 2 + 2]
            local bestIdx, bestDistSq = nil, math.huge
            for vi = 1, numVerts do
                local dx = polyVerts[(vi - 1) * 2 + 1] - tx
                local dy = polyVerts[(vi - 1) * 2 + 2] - ty
                local d2 = dx * dx + dy * dy
                if d2 < bestDistSq then
                    bestDistSq = d2
                    bestIdx = vi
                end
            end
            if bestIdx and bestDistSq < tolSq then
                indices[#indices + 1] = bestIdx
            else
                -- Triangulator introduced a Steiner point beyond tolerance.
                return nil
            end
        end
    end
    return indices
end

lib.firstCollision = firstCollisionLua

function lib.decompose(poly, result)
    result = result or {}
    local intersection = lib.firstCollision(poly)

    if not intersection then
        tableConcat(result, { poly })
        return result
    end

    local p1, p2 = lib.splitPoly(poly, intersection)

    -- Recursively decompose the resulting polygons
    lib.decompose(p1, result)
    lib.decompose(p2, result)

    return result
end

---

---


local function inside(p, cp1, cp2)
    return (cp2.x - cp1.x) * (p.y - cp1.y) > (cp2.y - cp1.y) * (p.x - cp1.x)
end

local function intersection(cp1, cp2, s, e)
    local dcx, dcy = cp1.x - cp2.x, cp1.y - cp2.y
    local dpx, dpy = s.x - e.x, s.y - e.y
    local n1 = cp1.x * cp2.y - cp1.y * cp2.x
    local n2 = s.x * e.y - s.y * e.x
    local n3 = 1 / (dcx * dpy - dcy * dpx)
    local x = (n1 * dpx - n2 * dcx) * n3
    local y = (n1 * dpy - n2 * dcy) * n3
    return { x = x, y = y }
end

function lib.polygonClip(subjectPolygon, clipPolygon)
    local outputList = subjectPolygon
    local cp1 = clipPolygon[#clipPolygon]
    for _, cp2 in ipairs(clipPolygon) do -- WP clipEdge is cp1,cp2 here
        local inputList = outputList
        outputList = {}
        local s = inputList[#inputList]
        for _, e in ipairs(inputList) do
            if inside(e, cp1, cp2) then
                if not inside(s, cp1, cp2) then
                    outputList[#outputList + 1] = intersection(cp1, cp2, s, e)
                end
                outputList[#outputList + 1] = e
            elseif inside(s, cp1, cp2) then
                outputList[#outputList + 1] = intersection(cp1, cp2, s, e)
            end
            s = e
        end
        cp1 = cp2
    end
    return outputList
end

-- Function to split a polygon into two at a single given intersection point.
-- this is used to fix self-intersecting polygons
function lib.splitPoly(poly, inter)
    local function getIndices()
        local biggestIndex = math.max(inter.i1, inter.i2)
        local smallestIndex = math.min(inter.i1, inter.i2)
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
    table.insert(wrap, inter.x)
    table.insert(wrap, inter.y)

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
    table.insert(back, inter.x)
    table.insert(back, inter.y)

    return wrap, back
end

-- Add or replace this function in your existing math-utils.lua
-- Function to slice a polygon with a line defined by points p1 and p2

-- Define slicing points (horizontal line at y = 150)

return lib

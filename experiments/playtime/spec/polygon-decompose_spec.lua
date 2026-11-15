-- spec/polygon-decompose_spec.lua
-- The careful triangulation (shapes.makeTrianglesFromPolygon: decompose a self-crossing polygon, then
-- love.math.triangulate each piece) got quicker: polygon-ops' first crossing stops at the first one and
-- skips edge pairs whose boxes are apart, and runs in C when native/desound/polydecomp.c is built in.
-- Each must give the same pieces as the old getCollisions + decompose, kept here as the reference, over
-- mouths (src/render/mouth.lua polygonOf, crossing lips included), simple, concave and self-crossing
-- polygons, near-duplicate points and collinear edges. Prints the timings.
-- Run with: love . --specs spec/polygon-decompose_spec.lua

if not love then return end

local polygonOps = require('src.polygon-ops')
local shapes = require('src.shapes')
local mouth = require('src.render.mouth')
local mouthShapes = require('src.mouth-shapes')

---------------------------------------------------------------- the old code, as it was (b7fed53f)

local function getLineIntersection(p0_x, p0_y, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y)
    local s1_x = p1_x - p0_x
    local s1_y = p1_y - p0_y
    local s2_x = p3_x - p2_x
    local s2_y = p3_y - p2_y
    local denom = (-s2_x * s1_y + s1_x * s2_y)
    if denom == 0 then return nil end
    local s = (-s1_y * (p0_x - p2_x) + s1_x * (p0_y - p2_y)) / denom
    local t = (s2_x * (p0_y - p2_y) - s2_y * (p0_x - p2_x)) / denom
    if s >= 0 and s <= 1 and t >= 0 and t <= 1 then
        return p0_x + (t * s1_x), p0_y + (t * s1_y)
    end
    return nil
end

local function getCollisions(poly)
    local collisions = {}
    local n = #poly
    for outeri = 1, n, 2 do
        local ax, ay = poly[outeri], poly[outeri + 1]
        local ni = outeri + 2
        if ni > n then ni = 1 end
        local bx, by = poly[ni], poly[ni + 1]
        for inneri = 1, n, 2 do
            if inneri ~= outeri and inneri ~= ((outeri + 2 - 1) % n) + 1 then
                local cx, cy = poly[inneri], poly[inneri + 1]
                local ni_inner = inneri + 2
                if ni_inner > n then ni_inner = 1 end
                local dx, dy = poly[ni_inner], poly[ni_inner + 1]
                local ix, iy = getLineIntersection(ax, ay, bx, by, cx, cy, dx, dy)
                if ix and iy then
                    if not ((ax == cx and ay == cy) or (ax == dx and ay == dy) or
                            (bx == cx and by == cy) or (bx == dx and by == dy)) then
                        local collision = { i1 = outeri, i2 = inneri, x = ix, y = iy }
                        local duplicate = false
                        for _, existing in ipairs(collisions) do
                            if (existing.i1 == collision.i2 and existing.i2 == collision.i1) then
                                duplicate = true
                                break
                            end
                        end
                        if not duplicate then table.insert(collisions, collision) end
                    end
                end
            end
        end
    end
    return collisions
end

local function oldDecompose(poly, result)
    result = result or {}
    local intersections = getCollisions(poly)
    if #intersections == 0 then
        result[#result + 1] = poly
        return result
    end
    local p1, p2 = polygonOps.splitPoly(poly, intersections[1])
    oldDecompose(p1, result)
    oldDecompose(p2, result)
    return result
end

local function oldTriangles(poly)
    local result = {}
    if not pcall(oldDecompose, poly, result) then return nil end
    local triangles = {}
    for i = 1, #result do
        local ok, tris = pcall(love.math.triangulate, result[i])
        if ok then for _, t in ipairs(tris) do triangles[#triangles + 1] = t end end
    end
    return triangles
end

---------------------------------------------------------------- the polygons

local function area(tris)
    local a = 0
    for _, t in ipairs(tris) do
        a = a + math.abs((t[3] - t[1]) * (t[6] - t[2]) - (t[5] - t[1]) * (t[4] - t[2])) / 2
    end
    return a
end

local function mouthCurve(shape, sx, sy, open)
    local minY, maxY = math.huge, -math.huge
    for i = 2, 16, 2 do minY, maxY = math.min(minY, shape.points[i]), math.max(maxY, shape.points[i]) end
    local cp = {}
    for i = 1, 16, 2 do
        local x, y = shape.points[i] * sx, shape.points[i + 1] * sy
        if i >= 11 and i <= 15 then y = y + open * (maxY - minY) * sy end
        cp[i], cp[i + 1] = x, y
    end
    return cp
end

local function polygonSet()
    love.math.setRandomSeed(11)
    local R = love.math.random
    local set, mouths, crossingMouths = {}, 0, 0
    local function add(kind, poly) set[#set + 1] = { kind = kind, poly = poly } end
    -- mouths: every shape, sizes and openings (open < 0 lifts the lower lip through the upper: crossed)
    for _, shape in ipairs(mouthShapes.normalized) do
        for k = 1, 16 do
            local open = k <= 12 and R() * 2.4 - 0.9 or -0.2 - R() * 0.7 -- the last few crossed more often
            local poly = mouth.polygonOf(mouthCurve(shape, 1 + R() * 4, 1 + R() * 4, open))
            if poly and #poly >= 6 then
                mouths = mouths + 1
                if not pcall(love.math.triangulate, poly) then crossingMouths = crossingMouths + 1 end
                add('mouth', poly)
            end
        end
    end
    -- circles and regular polygons, 3..120 points
    for n = 3, 120, 7 do
        local p = {}
        for k = 0, n - 1 do
            local a = k / n * math.pi * 2
            p[#p + 1], p[#p + 2] = 300 + math.cos(a) * 80, 200 + math.sin(a) * 60
        end
        add('circle', p)
    end
    -- stars (concave)
    for n = 4, 40, 3 do
        local p = {}
        for k = 0, n * 2 - 1 do
            local a, r = k / (n * 2) * math.pi * 2, (k % 2 == 0) and 100 or 30 + R() * 30
            p[#p + 1], p[#p + 2] = math.cos(a) * r, math.sin(a) * r
        end
        add('star', p)
    end
    -- figure-eights (one crossing in the middle), and loops crossing several times
    for n = 8, 100, 6 do
        local p = {}
        for k = 0, n - 1 do
            local a = k / n * math.pi * 2
            p[#p + 1], p[#p + 2] = math.sin(a) * 120, math.sin(a) * math.cos(a) * 60 + 0.37
        end
        add('figure-eight', p)
        local q, turns = {}, 2 + (n % 3)
        for k = 0, n - 1 do
            local a = k / n * math.pi * 2
            local r = 80 + 40 * math.cos(a * turns * 1.5)
            q[#q + 1], q[#q + 2] = math.cos(a * turns) * r + 5, math.sin(a * turns) * r * 0.7
        end
        add('loops', q)
    end
    -- random points: tangles
    for _ = 1, 30 do
        local p = {}
        for _ = 1, 4 + math.floor(R() * 14) do p[#p + 1], p[#p + 2] = R() * 200, R() * 200 end
        add('tangle', p)
    end
    -- near-duplicate points and collinear edges: a box with points along its edges, some nudged by 1e-7
    for k = 1, 15 do
        local p = {}
        local side = 3 + k
        local corners = { { 0, 0 }, { 100, 0 }, { 100, 60 }, { 0, 60 } }
        for c = 1, 4 do
            local a, b = corners[c], corners[c % 4 + 1]
            for s = 0, side - 1 do
                local t = s / side
                p[#p + 1], p[#p + 2] = a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
                if s == 1 and k % 2 == 0 then -- a point again, a hair off
                    p[#p + 1], p[#p + 2] = p[#p - 1] + 1e-7, p[#p] - 1e-7
                end
            end
        end
        add('collinear', p)
    end
    -- a bow tie with an exactly repeated vertex, and a polygon touching itself at a vertex
    add('bowtie', { 0, 0, 100, 100, 100, 0, 0, 100 })
    add('touch', { 0, 0, 50, 50, 100, 0, 100, 100, 50, 50, 0, 100 })
    add('spike', { 0, 0, 100, 0, 100, 50, 50, 50, 100, 50, 100, 100, 0, 100 })
    return set, mouths, crossingMouths
end

---------------------------------------------------------------- the checks

local function sameNumbers(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

-- decompose with polygon-ops' firstCollision set to `first`; returns ok, pieces
local function decomposeWith(first, poly)
    local saved = polygonOps.firstCollision
    polygonOps.firstCollision = first
    local result = {}
    local ok, err = pcall(polygonOps.decompose, poly, result)
    polygonOps.firstCollision = saved
    return ok, ok and result or err
end

local function timeIt(rounds, set, fn)
    local t0 = love.timer.getTime()
    for _ = 1, rounds do
        for _, entry in ipairs(set) do fn(entry.poly) end
    end
    return (love.timer.getTime() - t0) * 1000 / rounds
end

describe('polygon decompose', function()
    local set, mouths, crossingMouths = polygonSet()

    it('has a polygon set with many mouths, some of them crossed', function()
        assert.is_true(mouths >= #set / 2, mouths .. ' mouths of ' .. #set)
        assert.is_true(crossingMouths > 30, crossingMouths .. ' crossing mouths')
    end)

    local ways = { { 'lua', polygonOps.firstCollisionLua } }
    if polygonOps.firstCollisionNative then ways[#ways + 1] = { 'C', polygonOps.firstCollisionNative } end

    for _, way in ipairs(ways) do
        local name, first = way[1], way[2]
        it('gives the old pieces, number for number (' .. name .. ')', function()
            local errors, pieces = 0, 0
            for i, entry in ipairs(set) do
                local oldOk, old = pcall(oldDecompose, entry.poly)
                local ok, new = decomposeWith(first, entry.poly)
                assert.are.equal(oldOk, ok, entry.kind .. ' ' .. i .. ': errors differ')
                if oldOk then
                    assert.are.equal(#old, #new, entry.kind .. ' ' .. i .. ': piece count')
                    for k = 1, #old do
                        assert.is_true(sameNumbers(old[k], new[k]), entry.kind .. ' ' .. i .. ': piece ' .. k)
                    end
                    pieces = pieces + #old
                else
                    errors = errors + 1
                end
            end
            print(string.format('  [%s] %d polygons, %d pieces, %d errors (both ways)', name, #set, pieces, errors))
        end)

        it('covers the same triangle area as before (' .. name .. ')', function()
            local saved = polygonOps.firstCollision
            polygonOps.firstCollision = first
            for i, entry in ipairs(set) do
                local old = oldTriangles(entry.poly)
                local new = shapes.makeTrianglesFromPolygon(entry.poly)
                assert.are.equal(old == nil, new == nil, entry.kind .. ' ' .. i)
                if old then
                    local a, b = area(old), area(new)
                    assert.is_true(math.abs(a - b) <= 0.01 * math.max(a, 1e-9) + 1e-9,
                        string.format('%s %d: %.3f vs %.3f', entry.kind, i, a, b))
                end
            end
            polygonOps.firstCollision = saved
        end)
    end

    it('decomposing an odd-length polygon errors the same ways', function()
        for _, way in ipairs(ways) do
            local oldOk = pcall(oldDecompose, { 0, 0, 10, 0, 10 })
            local ok = decomposeWith(way[2], { 0, 0, 10, 0, 10 })
            assert.are.equal(oldOk, ok, way[1])
        end
    end)

    it('is quicker (prints the timings, JIT off as in the game)', function()
        if jit then jit.off(); jit.flush() end -- luacheck: ignore 113
        local mouthSet, crossedSet, bigSet = {}, {}, {}
        for _, entry in ipairs(set) do
            if entry.kind == 'mouth' then
                mouthSet[#mouthSet + 1] = entry
                if not pcall(love.math.triangulate, entry.poly) then crossedSet[#crossedSet + 1] = entry end
            end
            if #entry.poly >= 160 then bigSet[#bigSet + 1] = entry end
        end
        local groups = { { 'all', set }, { 'mouths', mouthSet }, { 'crossed mouths', crossedSet },
            { '80+ points', bigSet } }
        for _, g in ipairs(groups) do
            local label, polys = g[1], g[2]
            local points = 0
            for _, e in ipairs(polys) do points = points + #e.poly / 2 end
            local old = timeIt(5, polys, function(p) pcall(oldDecompose, p) end)
            local line = string.format('  decompose, %-14s %4d polygons (%3.0f points avg): old %7.2f ms',
                label, #polys, points / #polys, old)
            for _, way in ipairs(ways) do
                local first = way[2]
                local t = timeIt(5, polys, function(p) decomposeWith(first, p) end)
                line = line .. string.format(', %s %6.2f ms (%.1fx)', way[1], t, old / t)
            end
            print(line)
        end
        -- the whole careful path for comparison: decompose plus love.math.triangulate of each piece
        local tri = timeIt(5, crossedSet, function(p) shapes.makeTrianglesFromPolygon(p) end)
        local quick = timeIt(5, crossedSet, function(p)
            local pieces = {}
            polygonOps.decompose(p, pieces)
            for _, piece in ipairs(pieces) do pcall(love.math.triangulate, piece) end
        end)
        print(string.format('  crossed mouths, the careful path whole: %.2f ms (%.2f without logging failed pieces)',
            tri, quick))
        if jit then jit.on() end -- luacheck: ignore 113
    end)
end)

-- src/render/mouth.lua (split from physics/box2d-draw-textured.lua, SPLIT1)
local lib = {}
local shapes = require('src.shapes')
local utils = require('src.utils')

-- Build a closed polygon from mouth curvePoints (16 floats: 8 control points).
-- Returns a cleaned flat vertex array suitable for triangulation, or nil.
-- A mouth's triangles, kept until its polygon changes: the mouth is drawn every frame
-- (twice with teeth) and only changes shape while it talks, and makeTrianglesFromPolygon
-- was ~a third of the draw with a dozen Mipos. Weak keys, not on `extra`: that's saved.
local mouthTrisCache = setmetatable({}, { __mode = 'k' })
local function mouthTriangles(extra, slot, poly)
    local perExtra = mouthTrisCache[extra]
    if not perExtra then perExtra = {}; mouthTrisCache[extra] = perExtra end
    local cached = perExtra[slot]
    if cached and #cached.poly == #poly then
        local same = true
        for k = 1, #poly do
            if cached.poly[k] ~= poly[k] then same = false; break end
        end
        if same then return cached.tris end
    end
    local tris = shapes.makeTrianglesFromPolygon(poly)
    perExtra[slot] = { poly = poly, tris = tris }
    return tris
end

-- Lip strips are in the mouth's own space and a mouth only moves while it talks: a strip
-- already holding this curve (same 16 numbers, written last into this mesh) is drawn as
-- is. Lips sharing a picture share a mesh; then the last writer differs and it's redone.
local stripCurve = setmetatable({}, { __mode = 'k' }) -- [mesh] = the curve data last written
local function stripHolds(mesh, data)
    local last = stripCurve[mesh]
    local same = last ~= nil and #last == #data
    if same then
        for k = 1, #data do
            if last[k] ~= data[k] then same = false; break end
        end
    end
    if not same then
        local copy = {}
        for k = 1, #data do copy[k] = data[k] end
        stripCurve[mesh] = copy
    end
    return same
end

-- buildMouthPolygon makes two Bezier curves and renders them: kept per input (the 16
-- curve points), as most mouths are still most of the time.
local mouthPolyCache = { keys = {}, polys = {}, next = 1 }
local MOUTH_POLY_SLOTS = 64

local buildMouthPolygonUncached
local function buildMouthPolygon(curvePoints)
    if not curvePoints or #curvePoints ~= 16 then return nil end
    local key = table.concat(curvePoints, ',')
    local cache = mouthPolyCache
    local hit = cache.polys[key]
    if hit ~= nil then return hit or nil end
    local poly = buildMouthPolygonUncached(curvePoints)
    -- a ring of slots: talking mouths make new shapes every frame; don't keep them all
    local old = cache.keys[cache.next]
    if old then cache.polys[old] = nil end
    cache.keys[cache.next] = key
    cache.polys[key] = poly or false
    cache.next = cache.next % MOUTH_POLY_SLOTS + 1
    return poly
end

buildMouthPolygonUncached = function(curvePoints)
    local pts = curvePoints

    local upData = {
        pts[1], pts[2], pts[3], pts[4],
        pts[3], pts[4], pts[5], pts[6],
        pts[5], pts[6], pts[7], pts[8],
        pts[7], pts[8], pts[9], pts[10],
    }
    local downData = {
        pts[9], pts[10], pts[11], pts[12],
        pts[11], pts[12], pts[13], pts[14],
        pts[13], pts[14], pts[15], pts[16],
        pts[15], pts[16], pts[1], pts[2],
    }

    local upCurve = love.math.newBezierCurve(upData)
    local downCurve = love.math.newBezierCurve(downData)
    -- depth 3: with 1 the few straight pieces cut outside the curve where it bends sharply
    -- at the corners, and the hole poked out past the lips there (cached per shape)
    local upPts = upCurve:render(3)
    local downPts = downCurve:render(3)

    local poly = {}
    for pi = 1, #upPts do poly[#poly + 1] = upPts[pi] end
    for pi = 1, #downPts do poly[#poly + 1] = downPts[pi] end

    -- Remove consecutive duplicates
    local cleaned = {}
    local prevX, prevY
    for pi = 1, #poly - 1, 2 do
        local px, py = poly[pi], poly[pi + 1]
        if not prevX or math.abs(px - prevX) > 0.1 or math.abs(py - prevY) > 0.1 then
            cleaned[#cleaned + 1] = px
            cleaned[#cleaned + 1] = py
            prevX, prevY = px, py
        end
    end

    if #cleaned >= 6 then return cleaned end
    return nil
end

-- Lips (mouth-upper / mouth-lower): the ribbon runs along the mouth hole's edge, the lip
-- picture's height along the curve and its width across it, u = 0 above the curve and
-- u = 1 below (both lips run left to right). Where across the picture the mouth-opening
-- edge is differs per picture (a straight edge on one side, a blob, a cup), so it is
-- measured: the middle of the stroke nearest the opening side (the right for an upper
-- lip, whose hole is below; the left for a lower lip), averaged over the middle rows.
-- That line is put on the hole's edge. (Was: the ribbon's middle on the edge, then 8 px
-- toward the hole for every lip: a different offset for every picture and thickness.)
local lipEdges = {}
function lib.lipEdgeU(url, side)
    local key = url .. '|' .. side
    if lipEdges[key] then return lipEdges[key] end
    local ok, data = pcall(love.image.newImageData, 'textures/' .. url)
    local edge = 0.5
    if ok and data then
        local w, h = data:getDimensions()
        local sum, n = 0, 0
        local from, to, step = 0, w - 1, 1
        if side == 'upper' then from, to, step = w - 1, 0, -1 end
        for y = math.floor(h * 0.2), math.floor(h * 0.8) do
            local first, last
            for x = from, to, step do
                local _, _, _, a = data:getPixel(x, y)
                if a > 0.5 then
                    first = first or x
                    last = x
                elseif first then
                    break
                end
            end
            if first then sum, n = sum + (first + last) / 2, n + 1 end
        end
        if n > 0 then edge = (sum / n + 0.5) / w end
        data:release()
    end
    lipEdges[key] = edge
    return edge
end

-- How far to move a lip ribbon's middle along the curve's left normal (down, for both
-- lips) so its opening edge lies on the hole's edge.
local function lipShift(extra, side, lipImg)
    local url = extra.main and extra.main.bgURL
    if not url or url == '' then return 0 end
    local edge = lib.lipEdgeU(url, side)
    -- the ribbon spans -halfWidth (u = 0) .. +halfWidth (u = 1) around its middle
    return -(2 * edge - 1) * lipImg:getWidth() * (extra.lipScale or 0.25)
end

-- A mouth decal's 8 curve points as the face is now: the animated shape (mouthShapeVec on
-- the face's thing, src/mipo-face.lua) scaled onto the face; nil while it isn't animating.
local function animatedCurvePoints(extra, body)
    local thing = utils.thingOf(body)
    local vec = thing and thing.mouthShapeVec
    if not (vec and extra.mouthScaleX) then return nil end
    local points = {}
    for ci = 1, 16, 2 do
        points[ci] = vec[ci] * extra.mouthScaleX + extra.mouthX
        points[ci + 1] = vec[ci + 1] * extra.mouthScaleY + extra.mouthY
    end
    return points
end


lib.stripHolds = stripHolds
lib.mouthTriangles = mouthTriangles
lib.lipShift = lipShift
lib.buildMouthPolygon = buildMouthPolygon
lib.animatedCurvePoints = animatedCurvePoints

return lib

-- src/render/mouth.lua (split from physics/box2d-draw-textured.lua, SPLIT1)
local lib = {}
local color = require('src.color')
local ompBake = require('src.render.omp-bake')
local ribbon = require('src.render.ribbon')
local getLoveImage = ompBake.getLoveImage
local ownStrip = ribbon.ownStrip
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

-- The same triangles as one Mesh (one draw call), made when first asked and kept with them.
local function mouthMesh(extra, slot, poly)
    local tris = mouthTriangles(extra, slot, poly)
    if not tris or #tris == 0 then return nil end
    local cached = mouthTrisCache[extra][slot]
    if not cached.mesh then
        local vertices = {}
        for _, t in ipairs(tris) do
            for k = 1, 6, 2 do vertices[#vertices + 1] = { t[k], t[k + 1] } end
        end
        cached.mesh = love.graphics.newMesh(vertices, 'triangles', 'static')
    end
    return cached.mesh
end

-- A lip's Bezier from the mouth's 8 curve points `s` (16 numbers): the upper lip over p1..p5, the
-- lower one back from p1 over p8..p5, so both run left to right (the picture the same way up).
-- Written into `into` (reused: drawn every frame). Each lip owns its strip (ribbon.ownStrip), laid
-- again only when its curve changes: a mouth only moves while it talks.
local function lipCurve(s, side, into)
    if side == 'upper' then
        into[1], into[2], into[3], into[4] = s[1], s[2], s[3], s[4]
        into[5], into[6], into[7], into[8] = s[3], s[4], s[5], s[6]
        into[9], into[10], into[11], into[12] = s[5], s[6], s[7], s[8]
        into[13], into[14], into[15], into[16] = s[7], s[8], s[9], s[10]
    else
        into[1], into[2], into[3], into[4] = s[1], s[2], s[15], s[16]
        into[5], into[6], into[7], into[8] = s[15], s[16], s[13], s[14]
        into[9], into[10], into[11], into[12] = s[13], s[14], s[11], s[12]
        into[13], into[14], into[15], into[16] = s[11], s[12], s[9], s[10]
    end
    return into
end
local lipScratch = {}

-- buildMouthPolygon makes two Bezier curves and renders them: kept per input (the 16
-- curve points), as most mouths are still most of the time.
local mouthPolyCache = { keys = {}, polys = {}, next = 1 }
local MOUTH_POLY_SLOTS = 64

local buildMouthPolygonUncached
local buildMouthPolygonCached

-- A mouth's polygon: the one from last frame while its 16 curve numbers are the same (most
-- frames: a mouth only moves while it talks), else from the shared cache. The shared cache's
-- key is a string of all 16 numbers, and making it every frame for every mouth cost more than
-- the rest of the draw on an iPhone (2026-10-31). Per mouth and slot, weak keys like above.
local lastPolys = setmetatable({}, { __mode = 'k' })
local function buildMouthPolygon(curvePoints, extra, slot)
    if not curvePoints or #curvePoints ~= 16 then return nil end
    if not extra then return buildMouthPolygonCached(curvePoints) end
    local perExtra = lastPolys[extra]
    if not perExtra then perExtra = {}; lastPolys[extra] = perExtra end
    local last = perExtra[slot]
    if last then
        local same = true
        for k = 1, 16 do
            if last.points[k] ~= curvePoints[k] then same = false; break end
        end
        if same then return last.poly end
    else
        last = { points = {} }
        perExtra[slot] = last
    end
    for k = 1, 16 do last.points[k] = curvePoints[k] end
    last.poly = buildMouthPolygonCached(curvePoints)
    return last.poly
end

buildMouthPolygonCached = function(curvePoints)
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



    -- Mouth backdrop: dark interior fill. Drawn below teeth (z = mouth-lower - 2)
    -- so teeth always render on top of the void.
local function drawMouthBackdrop(d)
    local extra = d.extra
    local body = d.body
    if body and not body:isDestroyed() then
        local angle = body:getAngle()
        local bx, by = body:getPosition()

        love.graphics.push()
        love.graphics.translate(bx, by)
        love.graphics.rotate(angle)

        local curvePoints = animatedCurvePoints(extra, body) or extra.curvePoints
        local cleaned = buildMouthPolygon(curvePoints, extra, 'backdrop')
        -- The triangles filled straight away: they don't overlap (simple loops, triangulated),
        -- so the see-through colour comes out even, as it did through a stencil. A stencil
        -- pass per mouth was ~50 µs each on an iPhone SE 2 (2026-10-31).
        local mesh = cleaned and mouthMesh(extra, 'backdrop', cleaned)
        if mesh then
            love.graphics.setColor(color.hexToColor(extra.backdropHex or '00000099'))
            love.graphics.draw(mesh)
        end

        love.graphics.pop()
    end
end

    -- Mouth lower lip: lip curve only (interior fill moved to mouth-backdrop)
local function drawLowerLip(d)
    local extra = d.extra
    local body = d.body
    local points = extra.curvePoints
    if body and not body:isDestroyed() and points and #points == 16 then
        local angle = body:getAngle()
        local bx, by = body:getPosition()

        love.graphics.push()
        love.graphics.translate(bx, by)
        love.graphics.rotate(angle)

        local curve = lipCurve(animatedCurvePoints(extra, body) or points, 'lower', lipScratch)
        local lipImg = extra.ompImage
        if not lipImg and extra.main and extra.main.bgURL then
            lipImg = getLoveImage('textures/' .. extra.main.bgURL)
        end
        if lipImg then
            local scale = extra.lipScale or 0.25
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(ownStrip(extra, 'lip', lipImg, scale, curve, -1, lipShift(extra, 'lower', lipImg)))
        end

        love.graphics.pop()
    end
end

local function drawUpperLip(d)
    local extra = d.extra
    local body = d.body
    local points = extra.curvePoints
    if body and not body:isDestroyed() and points and #points == 16 then
        local angle = body:getAngle()
        local bx, by = body:getPosition()

        love.graphics.push()
        love.graphics.translate(bx, by)
        love.graphics.rotate(angle)

        local curve = lipCurve(animatedCurvePoints(extra, body) or points, 'upper', lipScratch)
        local lipImg = extra.ompImage
        if not lipImg and extra.main and extra.main.bgURL then
            lipImg = getLoveImage('textures/' .. extra.main.bgURL)
        end
        if lipImg then
            local scale = extra.lipScale or 0.25
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(ownStrip(extra, 'lip', lipImg, scale, curve, -1, lipShift(extra, 'upper', lipImg)))
        end

        love.graphics.pop()
    end
end

    -- Teeth: positioned image, optionally stencil-clipped to mouth interior
local function drawTeeth(d)
    local extra = d.extra
    local body = d.body
    if body and not body:isDestroyed() then
        local angle = body:getAngle()
        local bx, by = body:getPosition()

        love.graphics.push()
        love.graphics.translate(bx, by)
        love.graphics.rotate(angle)

        local img = extra.ompImage
        if not img and extra.main and extra.main.bgURL then
            img = getLoveImage('textures/' .. extra.main.bgURL)
        end

        if img then
            local ox = extra.ox or 0
            local oy = extra.oy or 0
            local w = extra.w or 20
            local h = extra.h or 10
            local imgW, imgH = img:getDimensions()
            local scaleX = w / imgW
            local scaleY = h / imgH

            -- Build a local curvePoints copy. Animated from mouthShapeVec when
            -- available, otherwise copied from bind so we can safely mutate.
            local curvePoints = extra.curvePoints and animatedCurvePoints(extra, body)
            if curvePoints then
                -- Anchor at corner midpoint (stable) with a small pull toward
                -- p3 (top of opening) so teeth follow lip motion subtly.
                local cmx = (curvePoints[1] + curvePoints[9])  * 0.5
                local cmy = (curvePoints[2] + curvePoints[10]) * 0.5
                local k = 0.3
                ox = cmx * (1 - k) + curvePoints[5] * k
                oy = cmy * (1 - k) + curvePoints[6] * k
            elseif extra.curvePoints then
                curvePoints = {}
                for ci = 1, #extra.curvePoints do
                    curvePoints[ci] = extra.curvePoints[ci]
                end
            end

            -- For stickOut: push the lower-arc Y values (p6, p7, p8) down by
            -- ~teeth height BEFORE the polygon is built. Preserves the natural
            -- top of the curve (including dips in weird mouth shapes — front
            -- teeth show through below the dip) and creates vertical room.
            if curvePoints and extra.teethStickOut and #curvePoints == 16 then
                local drop = h * 0.8
                curvePoints[12] = curvePoints[12] + drop  -- p6.y
                curvePoints[14] = curvePoints[14] + drop  -- p7.y
                curvePoints[16] = curvePoints[16] + drop  -- p8.y
            end

            local cleaned = buildMouthPolygon(curvePoints, extra, 'teeth')

            if cleaned then
                local tris = mouthTriangles(extra, 'teeth', cleaned)
                if tris and #tris > 0 then
                    love.graphics.stencil(function()
                        for ti = 1, #tris do
                            love.graphics.polygon("fill", tris[ti])
                        end
                    end, "replace", 1)
                    love.graphics.setStencilTest("equal", 1)

                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(img, ox - w / 2, oy - h / 2, 0, scaleX, scaleY)

                    love.graphics.setStencilTest()
                end
            end
        end

        love.graphics.pop()
    end
end


-- The mouth's drawables (createDrawables): drawn on the face body, around its curve points.
lib.drawers = {
    ['mouth-backdrop'] = drawMouthBackdrop,
    ['mouth-lower'] = drawLowerLip,
    ['mouth-upper'] = drawUpperLip,
    ['mouth-teeth'] = drawTeeth,
}

return lib

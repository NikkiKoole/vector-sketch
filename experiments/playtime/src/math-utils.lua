--math-utils.lua
local lib = {}



local function unpackNodePointsLoop(points)
    local unpacked = {}

    for i = 0, #points do
        local nxt = i == #points and 1 or i + 1
        unpacked[1 + (i * 2)] = points[nxt][1]
        unpacked[2 + (i * 2)] = points[nxt][2]
    end

    for i = 0, #points do
        local nxt = i == #points and 1 or i + 1
        unpacked[(#points * 2) + 1 + (i * 2)] = points[nxt][1]
        unpacked[(#points * 2) + 2 + (i * 2)] = points[nxt][2]
    end

    return unpacked
end

local function unpackNodePoints(points, noloop)
    local unpacked = {}
    if #points >= 1 then
        for i = 0, #points - 1 do
            unpacked[1 + (i * 2)] = points[i + 1][1]
            unpacked[2 + (i * 2)] = points[i + 1][2]
        end

        -- make it go round
        if noloop == nil then
            unpacked[(#points * 2) + 1] = points[1][1]
            unpacked[(#points * 2) + 2] = points[1][2]
        end
    end

    return unpacked
end

function lerp(a, b, t)
    return a + (b - a) * t
end

local function getDistance(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    local distance = math.sqrt((dx * dx) + (dy * dy))

    return distance
end

function lib.getLengthOfPath(path)
    local result = 0
    for i = 1, #path - 1 do
        local a = path[i]
        local b = path[i + 1]
        result = result + getDistance(a[1], a[2], b[1], b[2])
    end
    return result
end

-- local function evenlySpreadPath2(result, path, index, running, spacing)
--     -- Stop if there's no next segment
--     if index >= #path then return end

--     local hereX = path[index + 1]
--     local hereY = path[index + 2]
--     local thereX = path[index + 3]
--     local thereY = path[index + 4]

--     local d = getDistance(hereX, hereY, thereX, thereY)

--     -- Handle degenerate segment (zero length)
--     if d == 0 then
--         return evenlySpreadPath2(result, path, index + 2, running, spacing)
--     end

--     while running < d do
--         local t = running / d
--         local x = lerp(hereX, thereY, t)
--         local y = lerp(hereX, thereY, t)
--         -- table.insert(result, { x, y, { 1, 0, 1 } })
--         table.insert(result, x)
--         table.insert(result, y)
--         running = running + spacing
--     end

--     -- Carry leftover distance into next segment
--     return evenlySpreadPath2(result, path, index + 2, running - d, spacing)
-- end

local function evenlySpreadPath(result, path, index, running, spacing)
    -- Stop if there's no next segment
    if index >= #path then return end

    local here = path[index]
    local there = path[index + 1]

    local d = getDistance(here[1], here[2], there[1], there[2])

    -- Handle degenerate segment (zero length)
    if d == 0 then
        return evenlySpreadPath(result, path, index + 1, running, spacing)
    end

    while running < d do
        local t = running / d
        local x = lerp(here[1], there[1], t)
        local y = lerp(here[2], there[2], t)
        table.insert(result, { x, y, { 1, 0, 1 } })
        running = running + spacing
    end

    -- Carry leftover distance into next segment
    return evenlySpreadPath(result, path, index + 1, running - d, spacing)
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

        local tension = tension or .5
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
lib.unloosenVanillalineOLD = function(points, tension, spacing)
    --todo unpackNodePointsLoop shows up in perfromance measures.
    -- its a heavy hot looped
    -- also unneeded, atleast below. if evenlySpreadPatch would not give me packed nodes to begin with
    --logger:inspect(points)

    local work = unpackNodePoints(points, true)
    local output = {}
    local output2 = {}
    local amt = #points * 2
    for i = 0, amt do
        local t = (i / amt)
        if t >= 1 then t = 0.99999999 end
        if t == 0 then t = 0.00000001 end

        local x, y = GetSplinePos(work, t, tension)
        --table.insert(output, { x, y })
        output[i] = { x, y }

        --output2[(i * 2) + 1] = x
        --output2[(i * 2) + 2] = y
    end
    --logger:inspect(output)
    local rrr = {}
    --logger:inspect(output)
    --logger:inspect(output2)
    local r2 = evenlySpreadPath(rrr, output, 1, 0, spacing)

    output = unpackNodePoints(rrr)
    --logger:inspect(output)

    -- what a hack ! the end is not good it looped back and i dont know how to solve it
    -- in evenlyspreadpath....
    table.remove(output, #output)
    table.remove(output, #output)
    return output
end

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
                    acc = acc - segLen
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
    -- if closed then samp[j] = samp[1]; samp[j+1] = samp[2]; j = j + 2 end

    -- 3) Evenly re-space those samples, flat in/flat out, no hacks
    -- For a loop that shouldn’t duplicate the first point, use closed=true and include_first=false
    local out = evenlySpreadPathFlat(samp, spacing, 0, closed == true, false, false)

    return out -- flat [x1,y1,x2,y2,...]
end



function lib.makePolygonRelativeToCenter(polygon, centerX, centerY)
    -- Calculate the center


    -- Shift all points to make them relative to the center
    local relativePolygon = {}
    for i = 1, #polygon, 2 do
        local x = polygon[i] - centerX
        local y = polygon[i + 1] - centerY
        table.insert(relativePolygon, x)
        table.insert(relativePolygon, y)
    end

    return relativePolygon, centerX, centerY
end

function lib.makePolygonAbsolute(relativePolygon, newCenterX, newCenterY)
    local absolutePolygon = {}
    for i = 1, #relativePolygon, 2 do
        local x = relativePolygon[i] + newCenterX
        local y = relativePolygon[i + 1] + newCenterY
        table.insert(absolutePolygon, x)
        table.insert(absolutePolygon, y)
    end

    return absolutePolygon
end

function lib.getCenterOfPoints(points)
    local tlx = math.huge
    local tly = math.huge
    local brx = -math.huge
    local bry = -math.huge
    for ip = 1, #points, 2 do
        if points[ip + 0] < tlx then tlx = points[ip + 0] end
        if points[ip + 1] < tly then tly = points[ip + 1] end
        if points[ip + 0] > brx then brx = points[ip + 0] end
        if points[ip + 1] > bry then bry = points[ip + 1] end
    end
    --return tlx, tly, brx, bry
    local w = brx - tlx
    local h = bry - tly
    return tlx + w / 2, tly + h / 2, w, h
end

function lib.getPolygonDimensions(polygon)
    -- Initialize min and max values
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge

    -- Loop through the polygon's points
    for i = 1, #polygon, 2 do
        local x, y = polygon[i], polygon[i + 1]
        if x < minX then minX = x end
        if x > maxX then maxX = x end
        if y < minY then minY = y end
        if y > maxY then maxY = y end
    end

    -- Calculate width and height
    local width = maxX - minX
    local height = maxY - minY

    return width, height
end

function lib.getCenterOfPoints2(points)
    local tlx = math.huge
    local tly = math.huge
    local brx = -math.huge
    local bry = -math.huge
    for ip = 1, #points do
        local p = points[ip]
        if p.x < tlx then tlx = p.x end
        if p.y < tly then tly = p.y end
        if p.x > brx then brx = p.x end
        if p.y > bry then bry = p.y end
    end
    --return tlx, tly, brx, bry
    local w = brx - tlx
    local h = bry - tly
    return tlx + w / 2, tly + h / 2
end

local function getCenterOfShapeFixtures(fixts)
    local xmin = math.huge
    local ymin = math.huge
    local xmax = -math.huge
    local ymax = -math.huge
    for i = 1, #fixts do
        local it = fixts[i]
        if it:getUserData() then
        else
            local points = {}
            if (it:getShape().getPoints) then
                points = { it:getShape():getPoints() }
            else
                points = { it:getShape():getPoint() }
            end

            for j = 1, #points, 2 do
                local xx = points[j]
                local yy = points[j + 1]
                if xx < xmin then xmin = xx end
                if xx > xmax then xmax = xx end
                if yy < ymin then ymin = yy end
                if yy > ymax then ymax = yy end
            end
        end
    end
    return xmin + (xmax - xmin) / 2, ymin + (ymax - ymin) / 2
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

function lib.pointInRect(px, py, rect)
    return px >= rect.x and px <= (rect.x + rect.width) and
        py >= rect.y and py <= (rect.y + rect.height)
end

function lib.getCorners(polygon)
    if #polygon ~= 8 then
        logger:error("getCorners expects a polygon with exactly 4 vertices (8 numbers)")
        return nil, nil, nil, nil
    end

    local vertices = {}
    for i = 1, #polygon, 2 do
        table.insert(vertices, { x = polygon[i], y = polygon[i + 1], id = (i + 1) / 2 })
    end

    local cx, cy = 0, 0
    for i = 1, #vertices do
        cx = cx + vertices[i].x
        cy = cy + vertices[i].y
    end
    cx = cx / #vertices
    cy = cy / #vertices

    local corners = { tl = nil, tr = nil, br = nil, bl = nil }

    for _, v in ipairs(vertices) do
        local angle = math.atan2(v.y - cy, v.x - cx)

        -- Define angle boundaries for quadrants more cleanly (radians)
        local pi_2 = math.pi / 2                      -- 90 degrees

        if angle > -math.pi and angle <= -pi_2 then   -- (-180, -90] degrees --> Top-Left Quad III
            corners.tl = v
        elseif angle > -pi_2 and angle <= 0 then      -- (-90, 0] degrees --> Top-Right Quad IV
            corners.tr = v
        elseif angle > 0 and angle <= pi_2 then       -- (0, 90] degrees --> Bottom-Right Quad I
            corners.br = v
        elseif angle > pi_2 and angle <= math.pi then -- (90, 180] degrees --> Bottom-Left Quad II
            corners.bl = v
        else
            -- Should not happen with atan2 range
            logger:error(string.format("Warning: Vertex angle %.2f rad (%.1f deg) out of expected range (-pi, pi].",
                angle,
                math.deg(angle)))
        end
    end


    local assigned_count = 0
    if corners.tl then assigned_count = assigned_count + 1 end
    if corners.tr then assigned_count = assigned_count + 1 end
    if corners.br then assigned_count = assigned_count + 1 end
    if corners.bl then assigned_count = assigned_count + 1 end

    -- Check for duplicate assignments (same vertex assigned to multiple corners)
    local assignments = {}
    local duplicates = false
    for _, corner_v in pairs(corners) do
        if corner_v then
            if assignments[corner_v.id] then
                duplicates = true
                logger:error(string.format("Warning: Duplicate assignment for vertex ID %d", corner_v.id))
                break
            end
            assignments[corner_v.id] = true
        end
    end


    if assigned_count ~= 4 or duplicates then
        logger:error("Warning: Could not assign all 4 corners uniquely using angle quadrants.")
        -- This indicates the angle logic is insufficient for the shape/orientation
        -- A fallback or more complex geometric analysis might be needed.
    end

    return corners.tl, corners.tr, corners.br, corners.bl
end

function lib.getBoundingRect(polygon)
    local min_x, min_y = polygon[1], polygon[2]
    local max_x, max_y = polygon[1], polygon[2]
    for i = 3, #polygon, 2 do
        local x, y = polygon[i], polygon[i + 1]
        if x < min_x then min_x = x end
        if y < min_y then min_y = y end
        if x > max_x then max_x = x end
        if y > max_y then max_y = y end
    end
    return { x = min_x, y = min_y, width = max_x - min_x, height = max_y - min_y }
end

local function distancePointToSegment(px, py, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1

    if dx == 0 and dy == 0 then
        -- The segment is a single point
        local dist = math.sqrt((px - x1) ^ 2 + (py - y1) ^ 2)
        return dist, { x = x1, y = y1 }
    end

    -- Calculate the t that minimizes the distance
    local t = ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy)

    -- Clamp t to the [0,1] range
    t = math.max(0, math.min(1, t))

    -- Find the closest point on the segment
    local closestX = x1 + t * dx
    local closestY = y1 + t * dy

    -- Calculate the distance
    local dist = math.sqrt((px - closestX) ^ 2 + (py - closestY) ^ 2)

    return dist, { x = closestX, y = closestY }
end
-- Function to find the closest edge to a given point
-- Returns the index of the first vertex of the closest edge
function lib.findClosestEdge(verts, px, py)
    local minDist = math.huge
    local closestEdgeIndex = nil

    local numVertices = #verts / 2

    for i = 1, numVertices do
        local j = (i % numVertices) + 1 -- Next vertex (wrap around)
        local x1 = verts[(i - 1) * 2 + 1]
        local y1 = verts[(i - 1) * 2 + 2]
        local x2 = verts[(j - 1) * 2 + 1]
        local y2 = verts[(j - 1) * 2 + 2]

        local dist, _ = distancePointToSegment(px, py, x1, y1, x2, y2)

        if dist < minDist then
            minDist = dist
            closestEdgeIndex = i -- Insert after vertex i
        end
    end

    return closestEdgeIndex
end

function lib.findClosestVertex(verts, px, py)
    local minDistSq = math.huge
    local closestVertexIndex = nil

    local numVertices = #verts / 2

    for i = 1, numVertices do
        local vx = verts[(i - 1) * 2 + 1]
        local vy = verts[(i - 1) * 2 + 2]
        local dx = px - vx
        local dy = py - vy
        local distSq = dx * dx + dy * dy

        if distSq < minDistSq then
            minDistSq = distSq
            closestVertexIndex = i
        end
    end

    return closestVertexIndex
end

function lib.normalizeAxis(x, y)
    local magnitude = math.sqrt(x ^ 2 + y ^ 2)
    if magnitude == 0 then
        return 1, 0 -- Default to (1, 0) if the vector is zero
    else
        --   print('normalizing', x / magnitude, y / magnitude)
        return x / magnitude, y / magnitude
    end
end

function lib.calculateDistance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

function lib.computeCentroid(polygon)
    return lib.getCenterOfPoints(polygon)


    -- this is not a  correct way of doing it!!!!
    -- local sumX, sumY = 0, 0
    -- for i = 1, #polygon, 2 do
    --     --for _, vertex in ipairs(vertices) do
    --     sumX = sumX + polygon[i]
    --     sumY = sumY + polygon[i + 1]
    --     -- end
    -- end
    -- local count = (#polygon / 2)
    -- return sumX / count, sumY / count
end

function lib.rotatePoint(x, y, originX, originY, angle)
    -- Translate the point to the origin
    local translatedX = x - originX
    local translatedY = y - originY

    -- Apply rotation
    local rotatedX = translatedX * math.cos(angle) - translatedY * math.sin(angle)
    local rotatedY = translatedX * math.sin(angle) + translatedY * math.cos(angle)

    -- Translate back to the original position
    local finalX = rotatedX + originX
    local finalY = rotatedY + originY

    return finalX, finalY
end

function lib.localVerts(obj)
    if not obj.vertices then
        error('obj needs vertices if you want to do stuff with them')
    end
    local cx, cy = lib.computeCentroid(obj.vertices)
    return lib.getLocalVerticesForCustomSelected(obj.vertices, obj, cx, cy)
end

function lib.getLocalVerticesForCustomSelected(vertices, obj, cx, cy)
    local verts = vertices
    local offX, offY = obj.body:getPosition()
    local angle = obj.body:getAngle()
    local result = {}

    for i = 1, #verts, 2 do
        local rx, ry = lib.rotatePoint(verts[i] - cx, verts[i + 1] - cy, 0, 0, angle)
        local vx, vy = offX + rx, offY + ry
        table.insert(result, vx)
        table.insert(result, vy)
    end
    return result
end

-- Function to convert world coordinates to local coordinates of a shape
function lib.worldToLocal(worldX, worldY, angle, cx, cy)
    -- Get the body's position and angle
    -- local offX, offY = obj.body:getPosition()
    --local angle = obj.body:getAngle()

    -- Step 1: Translate the world point to the body's origin
    local translatedX = worldX -- offX
    local translatedY = worldY -- offY

    -- Step 2: Rotate the point by -angle to align with the local coordinate system
    local cosA = math.cos(-angle)
    local sinA = math.sin(-angle)
    local rotatedX = translatedX * cosA - translatedY * sinA
    local rotatedY = translatedX * sinA + translatedY * cosA

    -- Step 3: Adjust for the centroid offset
    local localX = rotatedX + cx
    local localY = rotatedY + cy

    return localX, localY
end

-- Function to remove a vertex from the table based on its vertex index
-- verts: flat list {x1, y1, x2, y2, ...}
-- vertexIndex: the index of the vertex to remove (1, 2, 3, ...)
function lib.removeVertexAt(verts, vertexIndex)
    local posX = (vertexIndex - 1) * 2 + 1
    local posY = posX + 1

    -- Remove y-coordinate first to prevent shifting issues
    table.remove(verts, posY)
    table.remove(verts, posX)
end

function lib.insertValuesAt(tbl, pos, val1, val2)
    table.insert(tbl, pos, val1)
    table.insert(tbl, pos + 1, val2)
end

-- decompose_complex.lua
-- A module for decomposing complex polygons into simpler polygons by handling intersections.



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


local function tableConcat(t1, t2)
    for i = 1, #t2 do
        table.insert(t1, t2[i])
    end
    return t1
end

function lib.decompose(poly, result)
    result = result or {}
    local intersections = getCollisions(poly)

    if #intersections == 0 then
        tableConcat(result, { poly })
        return result
    end

    -- Process only the first intersection to avoid redundant splits
    local intersection = intersections[1]

    local p1, p2 = lib.splitPoly(poly, intersection)

    -- Recursively decompose the resulting polygons
    lib.decompose(p1, result)
    lib.decompose(p2, result)

    return result
end

---


---

-- for the boyonce i prolly need thi algo:
-- http://rosettacode.org/wiki/Sutherland-Hodgman_polygon_clipping#Lua
-- http://rosettacode.org/wiki/Sutherland-Hodgman_polygon_clipping#JavaScript

function inside(p, cp1, cp2)
    return (cp2.x - cp1.x) * (p.y - cp1.y) > (cp2.y - cp1.y) * (p.x - cp1.x)
end

function intersection(cp1, cp2, s, e)
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

function lib.findIntersections(polygon, line)
    local intersections = {}
    local n = #polygon / 2 -- Number of vertices

    for i = 1, n do
        local j = (i % n) + 1 -- Next vertex index (wrap around)

        -- Current edge points
        local x1, y1 = polygon[(i - 1) * 2 + 1], polygon[(i - 1) * 2 + 2]
        local x2, y2 = polygon[(j - 1) * 2 + 1], polygon[(j - 1) * 2 + 2]

        -- Line to check against
        local lx1, ly1, lx2, ly2 = line.x1, line.y1, line.x2, line.y2

        -- Get intersection point
        local Px, Py = getLineIntersection(x1, y1, x2, y2, lx1, ly1, lx2, ly2)

        if Px and Py then
            -- Check for duplicates
            local duplicate = false
            for _, inter in ipairs(intersections) do
                if math.abs(inter.x - Px) < 1e-6 and math.abs(inter.y - Py) < 1e-6 then
                    duplicate = true
                    break
                end
            end

            if not duplicate then
                table.insert(intersections, { x = Px, y = Py, i1 = i, i2 = j })
            end
        end
    end

    return intersections
end

-- Function to split a polygon into two at a single given intersection point.
-- this is used to fix self-intersecting polygons
function lib.splitPoly(poly, intersection)
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

-- Add or replace this function in your existing math-utils.lua
-- Function to slice a polygon with a line defined by points p1 and p2

-- polygon = {
--         100, 100,
--         300, 100,
--         200, 200,
--         100, 200,
--     }

--     polygon = {
--         100, 100,
--         -300, 300,
--         300, 300,
--     }

--     polygon = {
--         100, 100, -- Vertex 1
--         200, 100, -- Vertex 2
--         200, 150, -- Vertex 3
--         150, 150, -- Vertex 4 (inward dent)
--         150, 200, -- Vertex 5
--         100, 200, -- Vertex 6
--     }

-- Define slicing points (horizontal line at y = 150)

-- Define slicing points
-- local p1 = { x = -5000, y = 150 }
-- local p2 = { x = 5000, y = 150 }


-- polygon = {
--     0, -100,    -- Vertex 1
--     23, -30,    -- Vertex 2
--     100, -30,   -- Vertex 3
--     38, 10,     -- Vertex 4
--     59, 80,     -- Vertex 5
--     0, 40,      -- Vertex 6
--     -59, 80,    -- Vertex 7
--     -38, 10,    -- Vertex 8
--     -100, -30,  -- Vertex 9
--     -23, -30,   -- Vertex 10
-- }

-- -- Define slicing points (diagonal line)
-- local p1 = { x = -150, y = 150 }
-- local p2 = { x = 150, y = -150 }



function lib.slicePolygon(polygon, p1, p2)
    -- p1 and p2 define the slicing line: {x = ..., y = ...}

    -- Step 1: Find intersection points between the slice line and the polygon
    local sliceLine = { x1 = p1.x, y1 = p1.y, x2 = p2.x, y2 = p2.y }
    local intersections = lib.findIntersections(polygon, sliceLine)


    --for _, inter in ipairs(intersections) do
    --     print(string.format("Intersection at (%.2f, %.2f) on edge %d-%d", inter.x, inter.y, inter.i1, inter.i2))
    --end

    -- Ensure there are at least two unique intersection points
    if #intersections < 2 then
        return { polygon } -- Return the original polygon as a single-element table
    end

    -- Step 2: Sort intersections based on their order along the slice line
    local function sortByDistance(a, b)
        local dx = sliceLine.x2 - sliceLine.x1
        local dy = sliceLine.y2 - sliceLine.y1
        local distanceA = (a.x - sliceLine.x1) * dx + (a.y - sliceLine.y1) * dy
        local distanceB = (b.x - sliceLine.x1) * dx + (b.y - sliceLine.y1) * dy
        return distanceA < distanceB
    end
    table.sort(intersections, sortByDistance)

    -- Step 3: Select two unique intersection points
    local uniqueIntersections = {}
    local threshold = 1e-6
    for _, inter in ipairs(intersections) do
        local isUnique = true
        for _, unique in ipairs(uniqueIntersections) do
            if math.abs(inter.x - unique.x) < threshold and math.abs(inter.y - unique.y) < threshold then
                isUnique = false
                break
            end
        end
        if isUnique then
            table.insert(uniqueIntersections, inter)
            if #uniqueIntersections == 2 then break end
        end
    end

    if #uniqueIntersections < 2 then
        logger:error("Not enough unique intersections to slice the polygon.")
        return { polygon }
    end

    local inter1, inter2 = uniqueIntersections[1], uniqueIntersections[2]

    -- Step 4: Insert intersection points into the polygon's vertex list
    -- To prevent index shifting issues, insert the intersection points in descending order of their insertion positions

    -- Determine insertion positions
    -- inter.i1 is the index of the first vertex of the edge where the intersection occurs
    local insertPos1 = inter1.i1 * 2 -- Position in the flat array
    local insertPos2 = inter2.i1 * 2 -- Position in the flat array

    -- Sort insertion positions in descending order
    if insertPos1 < insertPos2 then
        insertPos1, insertPos2 = insertPos2, insertPos1
        inter1, inter2 = inter2, inter1
    end

    -- Insert inter1 first
    lib.insertValuesAt(polygon, insertPos1 + 1, inter1.x, inter1.y)
    -- Insert inter2 next
    lib.insertValuesAt(polygon, insertPos2 + 1, inter2.x, inter2.y)

    -- Step 5: Find the new indices of the inserted intersection points
    local function findVertexIndex(x, y)
        for i = 1, #polygon, 2 do
            if math.abs(polygon[i] - x) < threshold and math.abs(polygon[i + 1] - y) < threshold then
                return (i + 1) / 2 -- Convert flat index to vertex index (1-based)
            end
        end
        return nil
    end

    local newInter1Index = findVertexIndex(inter1.x, inter1.y)
    local newInter2Index = findVertexIndex(inter2.x, inter2.y)

    if not newInter1Index or not newInter2Index then
        logger:error("Failed to find the new intersection indices after insertion.")
        return { polygon }
    end

    -- Step 6: Traverse the polygon to create two new polygons
    local function traverse(polygon, startIdx, endIdx, direction)
        local result = {}
        local n = #polygon / 2
        local idx = startIdx

        while true do
            table.insert(result, polygon[(idx - 1) * 2 + 1])
            table.insert(result, polygon[(idx - 1) * 2 + 2])

            if idx == endIdx then
                break
            end

            if direction == "clockwise" then
                idx = idx % n + 1
            else
                idx = (idx - 2) % n + 1
            end
        end

        return result
    end

    -- Create first polygon: traverse from inter1 to inter2 clockwise
    local poly1 = traverse(polygon, newInter1Index, newInter2Index, "clockwise")
    -- Create second polygon: traverse from inter2 to inter1 clockwise
    local poly2 = traverse(polygon, newInter2Index, newInter1Index, "clockwise")

    -- At this point, poly1 and poly2 already include the intersection points
    -- There's no need to append inter1 and inter2 again, as it causes duplication


    return { poly1, poly2 }
end

function lib.getMeanValueCoordinatesWeights(px, py, poly)
    local n = #poly / 2 -- number of vertices
    local weights = {}
    local weightSum = 0
    local epsilon = 1e-10
    -- Loop over each vertex of the polygon
    for i = 1, n do
        -- Get current, previous, and next vertex indices (wrapping around)
        local i_prev = (i - 2) % n + 1
        local i_next = (i % n) + 1

        -- Current vertex coordinates
        local xi = poly[2 * i - 1]
        local yi = poly[2 * i]
        -- Previous vertex coordinates
        local xprev = poly[2 * i_prev - 1]
        local yprev = poly[2 * i_prev]
        -- Next vertex coordinates
        local xnext = poly[2 * i_next - 1]
        local ynext = poly[2 * i_next]

        -- Vectors from point p to current, previous, and next vertices
        local dx = xi - px
        local dy = yi - py
        local d = math.sqrt(dx * dx + dy * dy)

        local dx_prev = xprev - px
        local dy_prev = yprev - py
        -- local d_prev = math.sqrt(dx_prev * dx_prev + dy_prev * dy_prev)

        local dx_next = xnext - px
        local dy_next = ynext - py
        -- local d_next = math.sqrt(dx_next * dx_next + dy_next * dy_next)

        local d = math.sqrt(dx * dx + dy * dy) + 1e-10
        local d_prev = math.sqrt(dx_prev * dx_prev + dy_prev * dy_prev) + 1e-10
        local d_next = math.sqrt(dx_next * dx_next + dy_next * dy_next) + 1e-10

        -- Angles between vectors
        local angle_prev = math.acos((dx * dx_prev + dy * dy_prev) / (d * d_prev))
        local angle_next = math.acos((dx * dx_next + dy * dy_next) / (d * d_next))

        -- Mean value weight for vertex i
        local tan_prev = math.tan(angle_prev / 2)
        local tan_next = math.tan(angle_next / 2)

        -- Avoid division by zero if point p coincides with a vertex
        if d == 0 then
            -- p is at vertex i
            for j = 1, n do
                weights[j] = 0
            end
            weights[i] = 1
            return weights
        end

        local w = (tan_prev + tan_next) / d
        weights[i] = w
        weightSum = weightSum + w
    end

    -- Normalize weights so they sum to 1
    for i = 1, n do
        weights[i] = weights[i] / weightSum
    end

    return weights
end

function lib.lerp(a, b, t)
    return a + (b - a) * t
end

function lib.repositionPointUsingWeights(weights, newPolygon)
    local newX, newY = 0, 0
    local n = #newPolygon / 2
    for i = 1, n do
        local wx = newPolygon[2 * i - 1]
        local wy = newPolygon[2 * i]
        newX = newX + weights[i] * wx
        newY = newY + weights[i] * wy
    end
    return newX, newY
end

function lib.closestEdgeParams(px, py, poly)
    local n = #poly / 2
    local best = {
        edgeIndex = nil,
        t = 0,
        distance = math.huge,
        sign = 1
    }

    for i = 1, n do
        local j = (i % n) + 1 -- next vertex index wrapping around

        local x1, y1 = poly[2 * i - 1], poly[2 * i]
        local x2, y2 = poly[2 * j - 1], poly[2 * j]

        -- Edge vector
        local ex = x2 - x1
        local ey = y2 - y1
        local edgeLength2 = ex * ex + ey * ey

        -- Vector from vertex i to point
        local dx = px - x1
        local dy = py - y1

        -- Project (dx, dy) onto edge to find parameter t
        local t = 0
        if edgeLength2 > 0 then
            t = (dx * ex + dy * ey) / edgeLength2
        end

        -- Clamp t to [0,1] to stay within the segment
        local clampedT = math.max(0, math.min(1, t))

        -- Closest point on edge to (px,py)
        local projX = x1 + clampedT * ex
        local projY = y1 + clampedT * ey

        -- Distance from point to projection
        local distX = px - projX
        local distY = py - projY
        local dist = math.sqrt(distX * distX + distY * distY)

        if dist < best.distance then
            -- Determine side (sign) of the edge using cross product:
            local cross = ex * dy - ey * dx
            local sign = (cross >= 0) and 1 or -1

            best.edgeIndex = i
            best.t = clampedT
            best.distance = dist
            best.sign = sign
        end
    end

    return best
end

function lib.repositionPointClosestEdge(params, newPoly)
    local n = #newPoly / 2

    if not params.edgeIndex or params.edgeIndex < 1 or params.edgeIndex > n then
        return nil, nil
    end

    local i = params.edgeIndex
    local j = (i % n) + 1

    local x1, y1 = newPoly[2 * i - 1], newPoly[2 * i]
    local x2, y2 = newPoly[2 * j - 1], newPoly[2 * j]

    local ex = x2 - x1
    local ey = y2 - y1
    local projX = x1 + params.t * ex
    local projY = y1 + params.t * ey

    local length = math.sqrt(ex * ex + ey * ey)
    if length == 0 then
        return projX, projY
    end

    -- Standard OUTWARD normal for CCW polygon: (dy, -dx) / length
    local nx = ey / length
    local ny = -ex / length

    -- Apply the formula: Proj + sign * distance * Normal
    -- The 'sign' from closestEdgeParams directly multiplies the normal offset
    local newX = projX + params.sign * params.distance * nx
    local newY = projY + params.sign * params.distance * ny

    return newX, newY
end

function lib.findEdgeAndLerpParam(px, py, poly)
    local n = #poly / 2
    local best = {
        edgeIndex = nil,
        t = 0,
        minDist = math.huge
    }

    for i = 1, n do
        local j = (i % n) + 1 -- next vertex index (wrap-around)

        local x1, y1 = poly[2 * i - 1], poly[2 * i]
        local x2, y2 = poly[2 * j - 1], poly[2 * j]

        -- Edge vector
        local ex = x2 - x1
        local ey = y2 - y1
        local edgeLength2 = ex * ex + ey * ey

        -- Vector from vertex i to point
        local dx = px - x1
        local dy = py - y1

        -- Project (dx, dy) onto the edge to find parameter t
        local t = 0
        if edgeLength2 > 0 then
            t = (dx * ex + dy * ey) / edgeLength2
        end

        -- Clamp t to [0,1]
        local clampedT = math.max(0, math.min(1, t))

        -- Closest point on edge to (px, py)
        local projX = x1 + clampedT * ex
        local projY = y1 + clampedT * ey

        -- Distance from point to projected point
        local distX = px - projX
        local distY = py - projY
        local dist = distX * distX + distY * distY -- squared distance for comparison

        if dist < best.minDist then
            best.minDist = dist
            best.edgeIndex = i
            best.t = clampedT
        end
    end

    return best.edgeIndex, best.t
end

function lib.lerpOnEdge(edgeIndex, t, newPoly)
    local n = #newPoly / 2
    if not edgeIndex or edgeIndex < 1 or edgeIndex > n then
        return nil, nil
    end

    local i = edgeIndex
    local j = (i % n) + 1 -- next vertex index (wrap-around)

    local x1, y1 = newPoly[2 * i - 1], newPoly[2 * i]
    local x2, y2 = newPoly[2 * j - 1], newPoly[2 * j]

    -- Linear interpolation between vertices using t
    local newX = (1 - t) * x1 + t * x2
    local newY = (1 - t) * y1 + t * y2

    return newX, newY
end

-- end experiemnt

return lib

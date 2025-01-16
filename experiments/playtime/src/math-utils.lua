--math-utils.lua
local lib = {}


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
    --print('makePolygonAbsolute center:', newCenterX, newCenterY)
    local absolutePolygon = {}
    for i = 1, #relativePolygon, 2 do
        local x = relativePolygon[i] + newCenterX
        local y = relativePolygon[i + 1] + newCenterY
        table.insert(absolutePolygon, x)
        table.insert(absolutePolygon, y)
    end
    --  print('resulting absolute poly:', inspect(absolutePolygon))
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
    return tlx + w / 2, tly + h / 2
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
            --print(inspect(points))
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
    --print(inspect(poly), inspect(intersection))
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
        --print(Px,Py, x1, y1, x2, y2, lx1, ly1, lx2, ly2)
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


-- -- Slice the polygon
-- slicedPolygons = mathutils.slicePolygon(polygon, p1, p2)
-- print(inspect(slicedPolygons))
function lib.slicePolygon(polygon, p1, p2)
    -- p1 and p2 define the slicing line: {x = ..., y = ...}

    -- Step 1: Find intersection points between the slice line and the polygon
    local sliceLine = { x1 = p1.x, y1 = p1.y, x2 = p2.x, y2 = p2.y }
    local intersections = lib.findIntersections(polygon, sliceLine)

    -- Debug: Print found intersections
    --   print("Found Intersections:")
    for _, inter in ipairs(intersections) do
        --     print(string.format("Intersection at (%.2f, %.2f) on edge %d-%d", inter.x, inter.y, inter.i1, inter.i2))
    end

    -- Ensure there are at least two unique intersection points
    if #intersections < 2 then
        --     print("Slice line does not intersect the polygon twice.")
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
        print("Not enough unique intersections to slice the polygon.")
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

    -- Debug: Print polygon after insertions
    -- print("Polygon after inserting intersection points:")
    -- print(inspect(polygon))

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
        print("Failed to find the new intersection indices after insertion.")
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

    -- Debug: Print the resulting polygons
    -- print("Resulting Polygons:")
    -- print("Polygon 1:")
    -- print(inspect(poly1))
    -- print("Polygon 2:")
    -- print(inspect(poly2))

    return { poly1, poly2 }
end

-- start experiemnt with adding joint to edge or something..

function meanValueCoordinates(px, py, poly)
    local n = #poly / 2 -- number of vertices
    local weights = {}
    local weightSum = 0

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
        local d_prev = math.sqrt(dx_prev * dx_prev + dy_prev * dy_prev)

        local dx_next = xnext - px
        local dy_next = ynext - py
        local d_next = math.sqrt(dx_next * dx_next + dy_next * dy_next)

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

function repositionPoint(weights, newPolygon)
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

    -- Ensure the edgeIndex is valid
    if not params.edgeIndex or params.edgeIndex < 1 or params.edgeIndex > n then
        return nil, nil
    end

    local i = params.edgeIndex
    local j = (i % n) + 1 -- next vertex index wrapping around

    local x1, y1 = newPoly[2 * i - 1], newPoly[2 * i]
    local x2, y2 = newPoly[2 * j - 1], newPoly[2 * j]

    -- Compute new point along the edge using t
    local ex = x2 - x1
    local ey = y2 - y1
    local projX = x1 + params.t * ex
    local projY = y1 + params.t * ey

    -- Compute a perpendicular (normal) to the edge
    local length = math.sqrt(ex * ex + ey * ey)
    -- Avoid division by zero:
    if length == 0 then
        return projX, projY
    end
    local nx = -ey / length
    local ny = ex / length

    -- Offset by the stored distance along the normal direction
    local newX = projX + params.sign * params.distance * nx
    local newY = projY + params.sign * params.distance * ny

    return newX, newY
end

function findEdgeAndLerpParam(px, py, poly)
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

function lerpOnEdge(edgeIndex, t, newPoly)
    local n = #newPoly / 2
    if not edgeIndex or edgeIndex < 1 or edgeIndex > n then
        return nil, nil
    end

    local i = edgeIndex
    local j = (i % n) + 1 -- next vertex index (wrap-around)
    print(2 * i - 1, 2 * i, 2 * j - 1, 2 * j)
    local x1, y1 = newPoly[2 * i - 1], newPoly[2 * i]
    local x2, y2 = newPoly[2 * j - 1], newPoly[2 * j]

    -- Linear interpolation between vertices using t
    local newX = (1 - t) * x1 + t * x2
    local newY = (1 - t) * y1 + t * y2

    return newX, newY
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
            --print(inspect(points))
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

-- end experiemnt

return lib

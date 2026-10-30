-- polygon.lua
-- Polygons as flat lists {x1, y1, x2, y2, ...}: move, rotate, scale, centres and bounds,
-- corners, the closest edge or vertex, local <-> world, insert and remove a vertex; rotatePoint.
-- Split out of math-utils.lua (CODE-SPLITS-2026-10.md SPLIT7); math-utils still hands these out.
local logger = require('src.logger')

local lib = {}

function lib.transformPolygonPoints(polygon, offX, offY)
    -- Calculate the center

    -- Shift all points to make them relative to the center
    local relativePolygon = {}
    for i = 1, #polygon, 2 do
        local x = polygon[i] + offX
        local y = polygon[i + 1] + offY
        table.insert(relativePolygon, x)
        table.insert(relativePolygon, y)
    end

    return relativePolygon
end

function lib.rotatePolygonPoints(polygon, angle)
    local cosA, sinA = math.cos(angle), math.sin(angle)
    local result = {}
    for i = 1, #polygon, 2 do
        local x, y = polygon[i], polygon[i + 1]
        result[i]     = x * cosA - y * sinA
        result[i + 1] = x * sinA + y * cosA
    end
    return result
end

function lib.scalePolygonPoints(polygon, scaleX, scaleY)
    -- Calculate the center

    -- Shift all points to make them relative to the center
    local relativePolygon = {}
    for i = 1, #polygon, 2 do
        local x = polygon[i] * scaleX
        local y = polygon[i + 1] * scaleY
        table.insert(relativePolygon, x)
        table.insert(relativePolygon, y)
    end

    return relativePolygon
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
    local w = brx - tlx
    local h = bry - tly
    return tlx + w / 2, tly + h / 2, w, h
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

-- Not a centroid: the centre of the bounding box (getCenterOfPoints), which is what the 24 callers
-- (and the saved body-local coords built on it) count on. Also returns w, h.
function lib.computeCentroid(polygon)
    return lib.getCenterOfPoints(polygon)
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


function lib.getCenterAndDimensions(body)
    local ud = body:getUserData()
    local cx, cy, w, h
    if ud.thing.vertices then
        local verts = ud.thing.vertices
        cx, cy, w, h = lib.getCenterOfPoints(verts)
    else -- circle shape
        cx, cy = body:getPosition()
        w, h = ud.thing.radius * 2, ud.thing.radius * 2
    end
    return cx, cy, w, h
end

return lib

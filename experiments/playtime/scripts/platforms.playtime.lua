local s = {}

function s.onStart()
    platform = getObjectsByLabel('platform')[1]

    local lverts = mathutils.localVerts(platform)

    chains = generateChainShapesFromPolygonWithNormals(lverts, 10)
    -- print(inspect(chains))
    -- local body = love.physics.newBody(world, 0, 0)
    -- local shape = love.physics.newChainShape(false, unpack(chainverts))
    -- local fixture = love.physics.newFixture(body, shape)
end

function s.draw()
    love.graphics.setColor(1, 0, 0)
    for j = 1, #chains do
        local chainverts = chains[j]
        for i = 1, #chainverts / 2 do
            local index = (i - 1) * 2
            local c = chainverts
            love.graphics.line(c[index + 1][1], c[index + 1][2], c[index + 2][1], c[index + 2][2])
        end
    end
    love.graphics.setColor(1, 1, 1)
    --love.graphics.polygon('fill', chainverts)
end

function generateChainShapesFromPolygonWithNormals(polygon, yOffset)
    local function calculateNormal(x1, y1, x2, y2)
        -- Compute the normal vector
        local dx, dy = x2 - x1, y2 - y1
        local length = math.sqrt(dx ^ 2 + dy ^ 2)
        return -dy / length, dx / length -- Perpendicular vector (dx, -dy rotated 90 degrees CCW)
    end

    local chains = {}
    local currentChain = {}

    for i = 1, #polygon - 2, 2 do
        local x1, y1 = polygon[i], polygon[i + 1]
        local x2, y2 = polygon[i + 2], polygon[i + 3]

        -- Compute the normal vector
        local nx, ny = calculateNormal(x1, y1, x2, y2)

        -- Check if this edge is facing downward (positive y in Love2D)
        if ny > 0 then
            -- This is a bottom edge, offset the vertices downward
            table.insert(currentChain, { x1, y1 + yOffset })
            table.insert(currentChain, { x2, y2 + yOffset })
        else
            -- If not a bottom edge, finalize the current chain (if any)
            if #currentChain > 0 then
                table.insert(chains, currentChain)
                currentChain = {}
            end
        end
    end

    -- Finalize the last chain if there are remaining edges
    if #currentChain > 0 then
        table.insert(chains, currentChain)
    end

    return chains
end

-- Function to create a chain shape for the bottom edges of a polygon
function createBottomChainShape(polygonVertices, yOffset)
    local chainVertices = {}

    local function calculateNormal(x1, y1, x2, y2)
        local dx, dy = x2 - x1, y2 - y1
        local length = math.sqrt(dx * dx + dy * dy)
        return -dy / length, dx / length -- Outward normal
    end

    -- Traverse each edge of the polygon
    for i = 1, #polygonVertices - 2, 2 do
        local x1, y1 = polygonVertices[i], polygonVertices[i + 1]
        local x2, y2 = polygonVertices[i + 2], polygonVertices[i + 3]

        -- Calculate the outward normal of the edge
        local nx, ny = calculateNormal(x1, y1, x2, y2)

        -- Check if the normal has a downward component
        if ny > 0 then
            -- Add the edge to the chain shape with offset
            table.insert(chainVertices, x1)
            table.insert(chainVertices, y1 + yOffset)
            table.insert(chainVertices, x2)
            table.insert(chainVertices, y2 + yOffset)
        end
    end

    -- Check the last edge (closing the polygon)
    local x1, y1 = polygonVertices[#polygonVertices - 1], polygonVertices[#polygonVertices]
    local x2, y2 = polygonVertices[1], polygonVertices[2]
    local nx, ny = calculateNormal(x1, y1, x2, y2)

    if ny > 0 then
        table.insert(chainVertices, x1)
        table.insert(chainVertices, y1 + yOffset)
        table.insert(chainVertices, x2)
        table.insert(chainVertices, y2 + yOffset)
    end

    return chainVertices
end

-- Function to calculate drag direction using MouseJoint
local function getDragDirection22(body, mouseJoint)
    if not mouseJoint then
        return { x = 0, y = 0 }
    end

    local bodyX, bodyY = body:getPosition()
    local targetX, targetY = mouseJoint:getTarget()

    local dx = targetX - bodyX
    local dy = targetY - bodyY

    local magnitude = math.sqrt(dx * dx + dy * dy)
    if magnitude == 0 then
        return { x = 0, y = 0 }
    end

    return { x = dx / magnitude, y = dy / magnitude }
end

-- Helper function to calculate drag direction using MouseJoint
local function getDragDirection(body, mouseJoint)
    if not mouseJoint then
        return { x = 0, y = 0 }
    end

    local bodyX, bodyY = body:getPosition()
    local targetX, targetY = mouseJoint:getTarget()

    local dx = targetX - bodyX
    local dy = targetY - bodyY

    local magnitude = math.sqrt(dx * dx + dy * dy)
    if magnitude == 0 then
        return { x = 0, y = 0 }
    end

    return { x = dx / magnitude, y = dy / magnitude }
end

function s.preSolveqoiwdhioqw(fix1, fix2, contact)
    -- Get fixtures and bodies involved in the collision
    local fixtureA, fixtureB = contact:getFixtures()
    local bodyA, bodyB = fixtureA:getBody(), fixtureB:getBody()

    -- Identify if one of the fixtures is a platform and the other is a draggable body
    local platformFixture, draggableBody

    if bodyA == platform.body and bodyB:getType() ~= "static" then
        draggableBody = bodyB
        platformFixture = fixtureA
    elseif bodyB == platform.body and bodyA:getType() ~= "static" then
        draggableBody = bodyA
        platformFixture = fixtureB
    else
        return -- Neither fixture is a platform or both are static; no action needed
    end

    -- Ensure that the draggable body is currently being dragged
    -- if not isDragging or draggedBody ~= draggableBody then
    --     return
    -- end

    -- Get the collision normal from the contact manifold
    --local worldManifold = contact:getWorldManifold()
    --local normal = { worldManifold.normal.x, worldManifold.normal.y }

    -- Calculate the angle of the collision normal in degrees
    --  local normalAngle = math.deg(math.atan2(normal[2], normal[1]))


    local collisionNormal = { contact:getNormal() }

    -- Calculate the angle of the collision normal in degrees
    local normalAngle = math.deg(math.atan2(collisionNormal[2], collisionNormal[1]))

    -- Normalize angle between -180 to 180
    if normalAngle > 180 then
        normalAngle = normalAngle - 360
    elseif normalAngle < -180 then
        normalAngle = normalAngle + 360
    end

    -- Determine if the collision is on the bottom or top edge
    local isBottomEdge = false
    local isTopEdge = false

    -- Define angle thresholds for classification
    -- Adjust these based on your platform's orientation and design
    if normalAngle > 45 and normalAngle < 135 then
        isBottomEdge = true
    elseif normalAngle > -135 and normalAngle < -45 then
        isTopEdge = true
    end

    -- Get the drag direction using MouseJoint
    local dragDirection = getDragDirection(draggedBody, mouseJoint)

    -- Calculate dot product between drag direction and collision normal
    local dot = dragDirection.x * collisionNormal[1] + dragDirection.y * collisionNormal[2]

    -- Decision Logic:
    if isBottomEdge then
        if dot > 0 then
            -- Dragging downwards into bottom edge: allow collision
            return
        else
            -- Dragging upwards through bottom edge: prevent collision
            contact:setEnabled(false)
        end
    elseif isTopEdge then
        if dot < 0 then
            -- Dragging upwards into top edge: prevent collision
            contact:setEnabled(false)
            -- Placeholder for additional action when dragging from top
        else
            -- Dragging downwards from top edge: allow collision
            return
        end
    else
        -- Side edges or other orientations: define behavior as needed
        -- For this example, allow collision
        return
    end
end

function s.preSolve1(fix1, fix2, contact)
    --print(fix1, fix2, contact)

    local fixtureA, fixtureB = contact:getFixtures()
    local bodyA, bodyB = fixtureA:getBody(), fixtureB:getBody()

    -- Identify if one of the fixtures is a platform and the other is a draggable body
    local platformFixture, draggableFixture

    if bodyA == platform.body and bodyB:getType() ~= "static" then
        draggedBody = bodyB
        platformFixture = fixtureA
        draggableFixture = fixtureB
    elseif bodyB == platform.body and bodyA:getType() ~= "static" then
        draggedBody = bodyA
        platformFixture = fixtureB
        draggableFixture = bodyA:getFixtures()[1] -- Assuming single fixture
    else
        return                                    -- Neither fixture is a platform or both are static; no action needed
    end


    -- Proceed only if dragging is active and the draggable body is being dragged
    --if not isDragging or draggedBody ~= draggableFixture:getBody() then
    --    return
    --end

    -- Get the collision normal
    local collisionNormal = { contact:getNormal() }

    -- Calculate the angle of the collision normal in degrees
    local normalAngle = math.deg(math.atan2(collisionNormal[2], collisionNormal[1]))

    -- Normalize angle between -180 to 180
    if normalAngle > 180 then
        normalAngle = normalAngle - 360
    elseif normalAngle < -180 then
        normalAngle = normalAngle + 360
    end

    -- Determine if the collision is on the bottom or top edge
    local isBottomEdge = false
    local isTopEdge = false

    -- Define angle thresholds for classification
    -- Adjust these based on your platform's orientation and design
    if normalAngle > 45 and normalAngle < 135 then
        isBottomEdge = true
    elseif normalAngle > -135 and normalAngle < -45 then
        isTopEdge = true
    end

    print('bottom', isBottomEdge, 'top', isTopEdge)



    -- local mouseJoint = getPJAttachedTo(draggedBody).joint
    -- local dragDirection = getDragDirection(draggedBody, mouseJoint)
    --
    --Get the draggable body's velocity
    local vx, vy = draggedBody:getLinearVelocity()
    local dragDirection = { x = vx, y = vy }

    --Normalize drag direction
    local speed = math.sqrt(dragDirection.x ^ 2 + dragDirection.y ^ 2)
    if speed == 0 then
        return -- No movement; cannot determine direction
    end
    dragDirection.x = dragDirection.x / speed
    dragDirection.y = dragDirection.y / speed

    -- Calculate dot product between drag direction and collision normal
    local dot = dragDirection.x * collisionNormal[1] + dragDirection.y * collisionNormal[2]
    --print(inspect(getPJAttachedTo(draggedBody)))
    -- Decision Logic:
    if isBottomEdge then
        if dot > 0 then
            -- Dragging downwards into bottom edge: allow collision
            return
        else
            -- Dragging upwards through bottom edge: prevent collision
            contact:setEnabled(false)
        end
    elseif isTopEdge then
        --print(dot)
        --print(dragDirection.y)
        if dot < 0 then
            --if dot < 0 then
            -- Dragging upwards into top edge: prevent collision
            --contact:setEnabled(false)
            -- Placeholder for additional action when dragging from top
        else
            -- Dragging downwards from top edge: allow collision
            return
        end
    else
        -- Side edges or other orientations: define as needed
        -- For this example, allow collision
        return
    end
end

return s

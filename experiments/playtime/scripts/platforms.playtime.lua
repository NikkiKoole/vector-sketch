local s = {}

function s.onStart()
    platform = getObjectsByLabel('platform')[1]
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

function s.preSolve(fix1, fix2, contact)
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

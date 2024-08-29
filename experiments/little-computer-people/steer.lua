function makeVehicle(x, y)
    return {
        position = Vector(x, y),
        velocity = Vector(0, 0),
        acceleration = Vector(0, 0),
        r = 4,
        currentTarget = nil,
        maxSpeed = 1 + love.math.random() * 0,
        maxForce = 2,
        color = { r = love.math.random(), g = love.math.random(), b = love.math.random() }
    }
end

function vehicleApplyBehaviors(v, others, target)
    local separate = vehicleSeparate(v, others)
    --  local predictiveAvoid = vehiclePredictiveAvoid(v, others)
    --local seek = vehicleSeek(v, target)
    if target then
        --print('got a target')
        local arrive = vehicleArrive(v, target)
        arrive = arrive * .8
        vehicleApplyForce(v, arrive)
    end

    if false then
        local avoidWalls = vehicleAvoidWalls(v, walkgrid)
        avoidWalls = avoidWalls * .25
        vehicleApplyForce(v, avoidWalls)
    end
    --local align = vehicleAlignment(v, others)
    --local avoidWalls = vehicleAvoidWalls(v, grid)
    --local wander = vehicleWander(v)
    -- local cohesion = vehicleCohesion(v, others)

    -- align = align * 1
    -- wander = wander * .2
    separate = separate * 1 -- seek = seek * 0.5
    --

    --cohesion = cohesion * .15

    -- vehicleApplyForce(v, align)
    -- vehicleApplyForce(v, wander)
    --vehicleApplyForce(v, cohesion)
    --vehicleApplyForce(v, predictiveAvoid)
    vehicleApplyForce(v, separate)
end

function vehicleCohesion(v, others)
    local neighborDist = 100
    local sum = Vector(0, 0)
    local count = 0

    for i = 1, #others do
        local other = others[i]
        local d = Vector.distance(v.position, other.position)
        if (v ~= other and d < neighborDist) then
            sum = sum + other.position
            count = count + 1
        end
    end

    if (count > 0) then
        sum = sum / count -- Average position
        return vehicleSeek(v, sum)
    else
        return Vector(0, 0)
    end
end

function vehicleAvoidWalls(v, grid)
    local lookahead = 4 --2 * CELL_SIZE -- Distance to look ahead
    local ahead = v.position + Vector.setMag(v.velocity, lookahead)

    local avoidanceForce = Vector(0, 0)
    local closestWall = nil

    -- Check nearby cells in the direction of movement
    for y = 1, GRID_HEIGHT do
        for x = 1, GRID_WIDTH do
            if grid[y][x] == 1 then -- If there's a wall
                local wallPos = Vector((x - 1) * CELL_SIZE + CELL_SIZE / 2, (y - 1) * CELL_SIZE + CELL_SIZE / 2)
                local distance = Vector.distance(ahead, wallPos)

                if distance < CELL_SIZE then
                    local steerAway = ahead - wallPos

                    --local strength = math.min(v.maxForce, v.maxForce / (distance * distance))
                    -- local strength = v.maxForce / math.sqrt(distance)
                    local minDistance = 4 -- Minimum effective distance
                    local effectiveDistance = math.max(distance, minDistance)
                    local strength = (v.maxForce / effectiveDistance) * 10
                    --print(strength)
                    -- print(effectiveDistance)
                    --local strength = v.maxForce
                    steerAway = Vector.setMag(steerAway, strength)


                    --steerAway = Vector.setMag(steerAway, strength)

                    -- steerAway = Vector.setMag(steerAway, v.maxForce / distance)
                    avoidanceForce = avoidanceForce + steerAway

                    if not closestWall or distance < Vector.distance(v.position, closestWall) then
                        closestWall = wallPos
                    end
                end
            end
        end
    end

    return avoidanceForce
end

function getNeighborsInRange(v, others, range)
    local result = {}
    for i = 1, #others do
        local other = others[i]
        local d = Vector.distance(v.position, other.position)
        if v ~= other and d < range then
            table.insert(result, other)
        end
    end
    return result
end

function vehicleSetRadiusDependingOnNeighbors(v, others, default, i)
    local desiredSeparation = 4 * 2
    local sum = Vector(0, 0)
    local count = 0
    for i = 1, #others do
        local other = others[i]
        local d = Vector.distance(v.position, other.position)
        if v ~= other and d < desiredSeparation then
            local diff = v.position - other.position
            diff = Vector.setMag(diff, 1 / d)
            sum = sum + diff
            count = count + 1
        end
    end
    if count >= 0 then
        local radius = mapInto(count, 0, 2, default, 0)
        --vehicles[i].r = math.max(radius, 0)
        --print('doing stuff: ', vehicles[i].r)
    end
end

function vehicleSeparate(v, others)
    local desiredSeparation = v.r
    local sum = Vector(0, 0)
    local count = 0
    for i = 1, #others do
        local other = others[i]
        local d = Vector.distance(v.position, other.position)
        if v ~= other and d < desiredSeparation then
            local diff = v.position - other.position
            diff = Vector.setMag(diff, 1 / d)
            sum = sum + diff
            count = count + 1
        end
    end
    if count > 0 then
        sum = sum / count
        sum = Vector.setMag(sum, v.maxSpeed)
        sum = sum - v.velocity

        sum = Vector.limit(sum, v.maxForce)
    end
    return sum
end

function vehicleSeek(v, target)
    local desired = target - v.position
    desired = Vector.setMag(desired, v.maxSpeed)
    local steer = desired - v.velocity
    steer = Vector.limit(steer, v.maxForce)
    return steer
    -- vehicleApplyForce(v, steer)
end

function vehicleArrive(v, target)
    local desired = target - v.position
    local d = desired.length

    local ARRIVE_DISTANCE = 8
    if (d < ARRIVE_DISTANCE) then
        local m = mapInto(d, 0, ARRIVE_DISTANCE, 0, v.maxSpeed)
        desired = Vector.setMag(desired, m)
    else
        desired = Vector.setMag(desired, v.maxSpeed)
    end

    local steer = desired - v.velocity
    steer = Vector.limit(steer, v.maxForce)
    return steer
    --vehicleApplyForce(v, steer)
end

function vehiclePredictiveAvoid(v, others)
    local avoidanceForce = Vector(0, 0)
    local futurePosition = v.position + v.velocity * 1.5 -- Predict future position (1.5 time units ahead)
    local desiredSeparation = v.r * 2                    -- Desired separation distance

    for i = 1, #others do
        local other = others[i]

        -- Skip self or other if it has no velocity
        if v ~= other and other.velocity.length > 0 then
            -- Predict future position of the other vehicle
            local otherFuturePosition = other.position + other.velocity * 1.5

            -- Calculate distance between the future positions
            local distance = Vector.distance(futurePosition, otherFuturePosition)

            -- If the predicted distance is less than the desired separation, calculate avoidance
            if distance < desiredSeparation then
                local diff = futurePosition - otherFuturePosition
                diff = Vector.setMag(diff, v.maxSpeed) -- Set magnitude proportional to maxSpeed
                avoidanceForce = avoidanceForce + diff -- Sum up all avoidance forces
            end
        end
    end

    -- Limit the avoidance force by the maxForce of the vehicle
    avoidanceForce = Vector.limit(avoidanceForce, v.maxForce)

    return avoidanceForce
end

function vehicleApplyForce(v, force)
    v.acceleration = v.acceleration + force
end

function vehicleUpdate(v)
    v.velocity = v.velocity + v.acceleration
    Vector.limit(v.velocity, v.maxSpeed)
    v.position = v.position + v.velocity
    v.acceleration = v.acceleration * 0
end

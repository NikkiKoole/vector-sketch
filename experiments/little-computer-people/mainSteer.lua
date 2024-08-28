package.path = package.path .. ";../../?.lua"

Vector = require 'vendor.brinevector'
-- Define grid dimensions and cell size
local GRID_WIDTH = 800 / 20
local GRID_HEIGHT = 600 / 20
local CELL_SIZE = 20

function makeVehicle(x, y)
    return {
        position = Vector(x, y),
        velocity = Vector(0, 0),
        acceleration = Vector(0, 0),
        r = 8,
        maxSpeed = 10,
        maxForce = .4,
        color = { r = love.math.random(), g = love.math.random(), b = love.math.random() }
    }
end

function vehicleApplyBehaviors(v, others, target)
    local separate = vehicleSeparate(v, others)
    local seek = vehicleSeek(v, target)
    local arrive = vehicleArrive(v, target)
    local align = vehicleAlignment(v, others)
    local avoidWalls = vehicleAvoidWalls(v, grid)
    local wander = vehicleWander(v)
    --local cohesion = vehicleCohesion(v, others)

    align = align * 1
    wander = wander * .2
    separate = separate * .8
    seek = seek * 0.5
    arrive = arrive * .5
    avoidWalls = avoidWalls * .9
    --cohesion = cohesion * .15

    -- vehicleApplyForce(v, align)
    -- vehicleApplyForce(v, wander)
    -- vehicleApplyForce(v, cohesion)
    vehicleApplyForce(v, separate)
    vehicleApplyForce(v, arrive)
    vehicleApplyForce(v, avoidWalls)
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

function vehicleWander(v)
    local wanderRadius = 250
    local wanderDistance = 8
    local wanderJitter = 100

    v.wanderTheta = (v.wanderTheta or 0) + love.math.random() * wanderJitter - wanderJitter * 0.5

    local wanderForce = Vector.setMag(v.velocity, wanderDistance)
    local circleLocation = v.position + wanderForce

    local h = Vector.fromAngle(v.wanderTheta)
    h = h * wanderRadius

    local target = circleLocation + h

    return vehicleSeek(v, target)
end

function vehicleSeek(v, target)
    local desired = target - v.position
    desired = Vector.setMag(desired, v.maxSpeed)
    local steer = desired - v.velocity
    steer = Vector.limit(steer, v.maxForce)
    return steer
    -- vehicleApplyForce(v, steer)
end

function mapInto(x, in_min, in_max, out_min, out_max)
    return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end

function vehicleArrive(v, target)
    local desired = target - v.position
    local d = desired.length

    local ARRIVE_DISTANCE = 500
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

function vehicleAvoidWalls(v, grid)
    local lookahead = 16 --2 * CELL_SIZE -- Distance to look ahead
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

function vehicleAlignment(v, others)
    local neighborDist = 50
    local sum = Vector(0, 0)
    local count = 0

    for i = 1, #others do
        local other = others[i]
        local d = Vector.distance(v.position, other.position)
        if (v ~= other and d < neighborDist) then
            sum = sum + other.velocity
            count = count + 1
        end
    end

    if (count > 0) then
        sum = sum / count
        sum = Vector.setMag(sum, v.maxSpeed)
        local steer = sum - v.velocity
        steer = Vector.limit(steer, v.maxForce)
        return steer
    else
        return Vector(0, 0)
    end
end

function vehicleSeparate(v, others)
    local desiredSeparation = v.r * 2
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

-- Create a grid with some walls
function createGrid()
    local grid = {}
    for y = 1, GRID_HEIGHT do
        grid[y] = {}
        for x = 1, GRID_WIDTH do
            -- Randomly place walls; 0 = empty, 1 = wall
            grid[y][x] = (love.math.random() > 0.7) and 1 or 0
        end
    end
    return grid
end

function love.load()
    -- font = love.graphics.newFont('SMW.Monospace.ttf', 24)
    font = love.graphics.newFont('SMW.Whole-Pixel.Spacing.ttf', 24)
    love.graphics.setFont(font)
    vehicles = {}
    for i = 1, 400 do
        vehicles[i] = makeVehicle(love.math.random() * 800, 300)
    end

    grid = createGrid()
end

function love.draw()
    for y = 1, GRID_HEIGHT do
        for x = 1, GRID_WIDTH do
            if grid[y][x] == 1 then
                love.graphics.setColor(0.5, 0.5, 0.5)
                love.graphics.rectangle('fill', (x - 1) * CELL_SIZE, (y - 1) * CELL_SIZE, CELL_SIZE, CELL_SIZE)
            else
                love.graphics.setColor(1, 1, 1, 0.1)
                love.graphics.rectangle('line', (x - 1) * CELL_SIZE, (y - 1) * CELL_SIZE, CELL_SIZE, CELL_SIZE)
            end
        end
    end
    love.graphics.setColor(1, 1, 1)


    local m = Vector(love.mouse.getX(), love.mouse.getY())
    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        vehicleApplyBehaviors(vehicle, vehicles, m)
        vehicleUpdate(vehicle)
        love.graphics.setColor(vehicle.color.r, vehicle.color.g, vehicle.color.b)
        love.graphics.circle('fill', vehicle.position.x, vehicle.position.y, vehicle.r)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Current FPS: " .. tostring(love.timer.getFPS()), 10, 10)
    love.graphics.print("Little pet people", 10, 40)
end

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
end

function love.update()

end

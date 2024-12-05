local s = {}

function s.onStart()
    worldState.paused = false
    water = getObjectsByLabel('water')[1]
    water.body:getFixtures()[1]:setSensor(true)

    submergedFixtures = {} -- a body can have multipe fixtures
end

local function flatToPoints(flat)
    local result = {}
    for i = 1, #flat, 2 do
        result[(i + 1) / 2] = { x = flat[i], y = flat[i + 1] }
    end
    return result
end

local function isCounterClockwise(polygon)
    local sum = 0
    for i = 1, #polygon do
        local p1 = polygon[i]
        local p2 = polygon[i % #polygon + 1]
        sum = sum + (p2.x - p1.x) * (p2.y + p1.y)
    end
    return sum < 0 -- Negative means counterclockwise
end

local function reversePolygon(polygon)
    local reversed = {}
    for i = #polygon, 1, -1 do
        reversed[#reversed + 1] = polygon[i]
    end
    return reversed
end

local function prepareVerticesForClipping(thing)
    local lverts = mathutils.localVerts(thing)
    local points = flatToPoints(lverts)
    if not isCounterClockwise(points) then
        points = reversePolygon(points)
    end
    return points
end

function s.update(dt)

end

function calculatePolygonArea(polygon)
    local area = 0
    local cx, cy = 0, 0 -- Centroid components
    local count = #polygon

    -- Ensure we have at least 3 vertices (a valid polygon)
    if count < 3 then
        return 0, { x = 0, y = 0 }
    end

    -- Loop through each edge of the polygon
    for i = 1, count do
        local p1 = polygon[i]
        local p2 = polygon[(i % count) + 1] -- Wrap to the first vertex

        -- Calculate area contribution (Shoelace formula)
        local cross = p1.x * p2.y - p2.x * p1.y
        area = area + cross

        -- Calculate centroid contribution
        cx = cx + (p1.x + p2.x) * cross
        cy = cy + (p1.y + p2.y) * cross
    end

    -- Finalize area and centroid calculations
    area = area / 2
    cx = cx / (6 * area)
    cy = cy / (6 * area)

    -- Return absolute area (since it can be negative depending on vertex order)
    return math.abs(area), { x = cx, y = cy }
end

function s.draw()
    local start = love.timer.getTime()
    local submergedThings = {}
    for i = 1, #submergedFixtures do
        local t = submergedFixtures[i]:getBody():getUserData().thing
        submergedThings[t.id] = t
    end
    local result = {}
    for k, v in pairs(submergedThings) do
        table.insert(result, v)
    end


    local waterPoly = prepareVerticesForClipping(water)


    for i = 1, #result do
        local otherPoly = prepareVerticesForClipping(result[i])
        local clip = mathutils.polygonClip(waterPoly, otherPoly)
        local submergedArea, center = calculatePolygonArea(clip) --local cx, cy = mathutils.computeCentroid(resultpoly)

        local resultpoly = {}
        for j = 1, #clip do
            table.insert(resultpoly, clip[j].x)
            table.insert(resultpoly, clip[j].y)
        end
        -- print(#result)
        --
        --
        --
        local dragCoefficient = .1
        local angularDamping = .15
        local fluidDensity = 1
        local m = love.physics.getMeter()
        local g = worldState.gravity

        if resultpoly and #resultpoly >= 6 then
            love.graphics.polygon('fill', resultpoly)
            -- print(area)
            local b = -(g / m) * submergedArea * fluidDensity


            if (worldState.paused == false) then
                result[i].body:applyForce(0, b, center.x, center.y)



                -- Apply drag resistance
                local vx, vy = result[i].body:getLinearVelocity()
                local speed = math.sqrt(vx ^ 2 + vy ^ 2)
                local dragForceX = -dragCoefficient * vx * speed
                local dragForceY = -dragCoefficient * vy * speed
                result[i].body:applyForce(dragForceX, dragForceY)

                -- Apply angular damping
                local omega = result[i].body:getAngularVelocity()
                local torque = -angularDamping * omega
                result[i].body:applyTorque(torque)
            end
        end
    end
    local duration = love.timer.getTime() - start
    --  print(string.format("It took %.3f milliseconds", duration * 1000))
end

function s.beginContact(fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
    local thingA = fix1:getBody():getUserData().thing
    local thingB = fix2:getBody():getUserData().thing
    if thingA == water then
        if (thingB.vertices) then
            table.insert(submergedFixtures, fix2)
        end
    end
    if thingB == water then
        if (thingA.vertices) then
            table.insert(submergedFixtures, fix1)
        end
    end
end

function s.endContact(fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
    local thingA = fix1:getBody():getUserData().thing
    local thingB = fix2:getBody():getUserData().thing
    if thingA == water then
        for i = #submergedFixtures, 1, -1 do
            if submergedFixtures[i] == fix2 then
                table.remove(submergedFixtures, i)
            end
        end
    end
    if thingB == water then
        for i = #submergedFixtures, 1, -1 do
            if submergedFixtures[i] == fix1 then
                table.remove(submergedFixtures, i)
            end
        end
    end
end

return s

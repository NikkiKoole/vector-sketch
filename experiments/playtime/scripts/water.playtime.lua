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
    local lverts = mathutils.localVerts(water)
    local points = flatToPoints(lverts)
    if not isCounterClockwise(points) then
        points = reversePolygon(points)
    end
    return points
end

function s.update(dt)

end

function s.draw()
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
        -- print(inspect(otherPoly))
        love.graphics.print(inspect(clip), 0, 0)
    end
end

function s.beginContact(fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
    local thingA = fix1:getBody():getUserData().thing
    local thingB = fix2:getBody():getUserData().thing
    if thingA == water then
        table.insert(submergedFixtures, fix2)
    end
    if thingB == water then
        table.insert(submergedFixtures, fix1)
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

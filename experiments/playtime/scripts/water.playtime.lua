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
        result[(i + 1) / 2] = { flat[i], flat[i + 1] }
    end
    return result
end

function s.update(dt)
    local submergedThings = {}
    for i = 1, #submergedFixtures do
        local t = submergedFixtures[i]:getBody():getUserData().thing
        submergedThings[t.id] = t
    end
    local result = {}
    for k, v in pairs(submergedThings) do
        table.insert(result, v)
    end

    local wverts = mathutils.localVerts(water.vertices, water)
    local waterPoints = flatToPoints(wverts)

    for i = 1, #result do
        local verts = mathutils.localVerts(result[i].vertices, result[i])
        local b = flatToPoints(verts)
        print(inspect(waterPoints))
        print(inspect(b))

        --local a = polygonClip(waterPoints, b)

        --print(#a)
        -- print(inspect({ points = waterPoints }))
        -- print(inspect({ points = b }))
    end
    --print(inspect(flatToPoints(water.vertices)))
    -- now we have the (partly)submerged things in result.
    -- now i can run extract vertices the way i want from water and from result[x]
    -- then run the polygon clipping.
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

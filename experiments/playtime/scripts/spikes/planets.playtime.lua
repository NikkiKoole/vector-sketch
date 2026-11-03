local s = {}

local function applyGravity(planet, body)
    local planetPosX, planetPosY = planet.body:getPosition()
    local bodyPosX, bodyPosY = body:getPosition()
    local direction = { x = planetPosX - bodyPosX, y = planetPosY - bodyPosY }
    local distanceSquared = direction.x ^ 2 + direction.y ^ 2

    -- Check if within influence radius
    if distanceSquared > planet.maxInfluenceRadius ^ 2 then
        return
    end

    -- Avoid division by zero
    if distanceSquared == 0 then
        return
    end

    local distance = math.sqrt(distanceSquared)
    local forceMagnitude = planet.gravity / distanceSquared

    -- Normalize direction
    local force = { x = (direction.x / distance) * forceMagnitude, y = (direction.y / distance) * forceMagnitude }

    -- Apply force to the center of the body

    body:applyForce(force.x, force.y)
end

function s.onStart()
    -- how to set the gravity.
    state.world.gravity = 0
    state.physicsWorld:setGravity(0, 0)

    planets = {}

    -- because i dont have labels or ids yet ill just make al the static objects planets,
    planets = getObjectsByLabel('planet')

    for i = 1, #planets do
        local it = planets[i]
        it.maxInfluenceRadius = 10000
        it.gravity = 100000 + random() * 1000000
    end

    local bodies = state.physicsWorld:getBodies()
    for i = 1, #bodies do
        bodies[i]:setAwake(true)
    end

    if false then
        for _, body in ipairs(state.physicsWorld:getBodies()) do
            if body:getType() == 'static' then
                local d = {
                    body = body,
                    maxInfluenceRadius = 10000,
                    gravity = 1000000 + random() * 1000000
                }
                table.insert(planets, d)
            end
            if body:getType() == 'dynamic' then
                body:setAwake(true)
            end
        end
    end
end

-- function s.drawUI(x,y,w,h)
--     ui.panel(.... , function()
--     if ui.button(x, y, label) then

--     end end
-- end

function s.draw()
    for i = 1, #planets do
        local x, y = planets[i].body:getPosition()
        love.graphics.circle('line', x, y, planets[i].maxInfluenceRadius)
    end
end

function s.update(dt)
    for _, planet in ipairs(planets) do
        for _, body in ipairs(state.physicsWorld:getBodies()) do
            if body:getType() == 'dynamic' then
                applyGravity(planet, body)
            end
        end
    end
end

return s

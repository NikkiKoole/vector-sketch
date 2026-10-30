-- bridge-serialize.lua
-- Turns any Lua value into something JSON can hold: LÖVE objects (bodies, joints, fixtures,
-- shapes) as small tables, functions and other userdata as strings, cycles and deep nesting cut
-- off. Shared by vendor/claude-bridge.lua (desktop, port 8001) and src/web-bridge.lua (browser).


local love_type_extractors = {}

love_type_extractors["Body"] = function(obj)
    if obj:isDestroyed() then return { destroyed = true } end
    local x, y = obj:getPosition()
    local vx, vy = obj:getLinearVelocity()
    local ud = obj:getUserData()
    local thing = ud and ud.thing
    return {
        _type = "Body",
        id = thing and thing.id or nil,
        label = thing and thing.label or nil,
        bodyType = obj:getType(),
        x = x, y = y,
        angle = obj:getAngle(),
        vx = vx, vy = vy,
        angularVelocity = obj:getAngularVelocity(),
        awake = obj:isAwake(),
        active = obj:isActive(),
        fixtureCount = #obj:getFixtures(),
    }
end

love_type_extractors["Joint"] = function(obj)
    if obj:isDestroyed() then return { destroyed = true } end
    local bodyA, bodyB = obj:getBodies()
    local udA = bodyA and bodyA:getUserData()
    local udB = bodyB and bodyB:getUserData()
    local thingA = udA and udA.thing
    local thingB = udB and udB.thing
    local ud = obj:getUserData()
    return {
        _type = "Joint",
        id = ud and ud.id or nil,
        jointType = obj:getType(),
        bodyA = thingA and thingA.id or nil,
        bodyB = thingB and thingB.id or nil,
    }
end

love_type_extractors["Fixture"] = function(obj)
    if obj:isDestroyed() then return { destroyed = true } end
    local shape = obj:getShape()
    return {
        _type = "Fixture",
        shapeType = shape and shape:getType() or nil,
        density = obj:getDensity(),
        friction = obj:getFriction(),
        restitution = obj:getRestitution(),
        isSensor = obj:isSensor(),
        filterData = { obj:getFilterData() },
    }
end

love_type_extractors["Shape"] = function(obj)
    return {
        _type = "Shape",
        shapeType = obj:getType(),
    }
end

local function safe_serialize(value, depth, max_depth, seen)
    depth = depth or 0
    max_depth = max_depth or 4
    seen = seen or {}

    if value == nil then
        return nil -- json null
    end

    local t = type(value)

    if t == "number" then
        -- Handle NaN and inf
        if value ~= value then return nil end -- NaN
        if value == math.huge or value == -math.huge then return nil end
        return value
    end

    if t == "string" then
        return value
    end

    if t == "boolean" then
        return value
    end

    if t == "function" then
        return "<function>"
    end

    if t == "userdata" then
        -- Try LÖVE type extractors
        for type_name, extractor in pairs(love_type_extractors) do
            local ok, is_type = pcall(function() return value.typeOf and value:typeOf(type_name) end)
            if ok and is_type then
                return extractor(value)
            end
        end
        return "<userdata>"
    end

    if t == "table" then
        if seen[value] then
            return "<circular ref>"
        end
        if depth >= max_depth then
            return "<max depth>"
        end
        seen[value] = true

        -- Check if it's an array
        local is_array = true
        local max_index = 0
        local count = 0
        for k, _ in pairs(value) do
            count = count + 1
            if type(k) == "number" and k == math.floor(k) and k > 0 then
                if k > max_index then max_index = k end
            else
                is_array = false
            end
        end
        -- Empty table -> empty object
        if count == 0 then return {} end
        -- If max_index is much larger than count, treat as sparse -> object
        if is_array and max_index > count * 2 then is_array = false end

        if is_array then
            local result = {}
            for i = 1, max_index do
                result[i] = safe_serialize(value[i], depth + 1, max_depth, seen)
            end
            seen[value] = nil
            return result
        else
            local result = {}
            for k, v in pairs(value) do
                local key
                if type(k) == "string" then
                    key = k
                elseif type(k) == "number" then
                    key = tostring(k)
                else
                    key = tostring(k)
                end
                result[key] = safe_serialize(v, depth + 1, max_depth, seen)
            end
            seen[value] = nil
            return result
        end
    end

    return tostring(value)
end

return { serialize = safe_serialize }

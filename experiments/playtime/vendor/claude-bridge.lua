--
-- claude-bridge.lua
--
-- HTTP JSON API for Claude to interact with the running playtime game.
-- Runs on port 8001, coexists with lovebird (port 8000).
--
-- Usage (2 lines in main.lua):
--   local bridge = require 'vendor.claude-bridge'
--   -- in love.update(dt): bridge.update()
--

local socket = require "socket"
local json = require "vendor.dkjson"

local bridge = {}

bridge.port = 8001
bridge.host = "*"
bridge.whitelist = { "127.0.0.1" }
bridge.server = nil
bridge.connections = {}
bridge.inited = false
bridge.frame_count = 0
bridge.snapshots = {}

-- ─────────────────────────────────────────────
-- Console capture + error tracking
-- ─────────────────────────────────────────────

bridge.console_buffer = {}
bridge.console_max = 200
bridge.errors = {}
bridge.errors_max = 50

-- ─────────────────────────────────────────────
-- Input simulation queue
-- ─────────────────────────────────────────────

bridge.input_queue = {}

-- ─────────────────────────────────────────────
-- Watch expressions
-- ─────────────────────────────────────────────

bridge.watches = {}       -- { [name] = { code=str, fn=compiled, interval=N, samples={}, max_samples=N, last_frame=N } }
bridge.watch_max_samples = 200
bridge.breakpoints = {}   -- { [name] = { code=str, fn=compiled, hit=false, hit_frame=N, hit_value=any, once=bool } }

-- ─────────────────────────────────────────────
-- Collision event log
-- ─────────────────────────────────────────────

bridge.collisions = {}
bridge.collisions_max = 200
bridge.collision_logging = false
bridge.destroying_body = false  -- guard flag to skip callbacks during body destruction

local function get_fixture_id(fixture)
    if not fixture or fixture:isDestroyed() then return nil end
    local body = fixture:getBody()
    if not body or body:isDestroyed() then return nil end
    local ud = body:getUserData()
    local thing = ud and ud.thing
    return thing and thing.id or nil
end

local function get_fixture_label(fixture)
    if not fixture or fixture:isDestroyed() then return nil end
    local body = fixture:getBody()
    if not body or body:isDestroyed() then return nil end
    local ud = body:getUserData()
    local thing = ud and ud.thing
    return thing and thing.label or nil
end

function bridge.logCollision(event_type, fix1, fix2, contact, ni1, ti1, ni2, ti2)
    if not bridge.collision_logging then return end
    if bridge.destroying_body then return end  -- skip during body destruction to avoid native crash
    local cx, cy = 0, 0
    if contact and not contact:isDestroyed() then
        local ok, x, y = pcall(function() return contact:getPositions() end)
        if ok and x then cx, cy = x, y end
    end
    local entry = {
        frame = bridge.frame_count,
        type = event_type,
        bodyA = get_fixture_id(fix1),
        bodyB = get_fixture_id(fix2),
        labelA = get_fixture_label(fix1),
        labelB = get_fixture_label(fix2),
        x = cx, y = cy,
    }
    if event_type == "postSolve" and ni1 then
        entry.normalImpulse = ni1
        entry.tangentImpulse = ti1
    end
    table.insert(bridge.collisions, entry)
    while #bridge.collisions > bridge.collisions_max do
        table.remove(bridge.collisions, 1)
    end
end

local _original_print = print
function print(...)
    -- Store in buffer
    local args = {...}
    local parts = {}
    for i = 1, select('#', ...) do
        parts[#parts + 1] = tostring(args[i])
    end
    local line = table.concat(parts, "\t")
    table.insert(bridge.console_buffer, {
        frame = bridge.frame_count,
        time = os.clock(),
        text = line,
    })
    -- Trim buffer
    while #bridge.console_buffer > bridge.console_max do
        table.remove(bridge.console_buffer, 1)
    end
    -- Also print to real stdout
    _original_print(...)
end

function bridge.recordError(source, message)
    table.insert(bridge.errors, {
        frame = bridge.frame_count,
        time = os.clock(),
        source = source,
        message = tostring(message),
    })
    while #bridge.errors > bridge.errors_max do
        table.remove(bridge.errors, 1)
    end
end

-- ─────────────────────────────────────────────
-- Safe serialization
-- ─────────────────────────────────────────────

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

-- ─────────────────────────────────────────────
-- Response helpers
-- ─────────────────────────────────────────────

local function get_meta()
    local state = require 'src.state'
    local registry = require 'src.registry'
    local utils = require 'src.utils'
    local body_count = 0
    local joint_count = 0
    for _ in pairs(registry.bodies) do body_count = body_count + 1 end
    for _ in pairs(registry.joints) do joint_count = joint_count + 1 end
    return {
        fps = love.timer.getFPS(),
        frame = bridge.frame_count,
        paused = state.world.paused,
        bodyCount = body_count,
        jointCount = joint_count,
    }
end

local function ok_response(data, extra_meta)
    local resp = {
        ok = true,
        data = data,
        meta = get_meta(),
    }
    if extra_meta then
        for k, v in pairs(extra_meta) do resp.meta[k] = v end
    end
    return json.encode(resp)
end

local function err_response(msg)
    local resp = {
        ok = false,
        error = msg,
        meta = get_meta(),
    }
    return json.encode(resp)
end

local function json_http_response(status, body)
    return "HTTP/1.1 " .. status .. "\r\n" ..
        "Content-Type: application/json\r\n" ..
        "Access-Control-Allow-Origin: *\r\n" ..
        "Content-Length: " .. #body .. "\r\n" ..
        "\r\n" .. body
end

-- ─────────────────────────────────────────────
-- URL / HTTP parsing
-- ─────────────────────────────────────────────

local function unescape(str)
    local f = function(x) return string.char(tonumber("0x" .. x)) end
    return (str:gsub("%+", " "):gsub("%%(..)", f))
end

local function parse_url(url)
    local res = {}
    res.path, res.search = url:match("/([^%?]*)%??(.*)")
    res.path = res.path or ""
    res.search = res.search or ""
    res.query = {}
    for k, v in res.search:gmatch("([^&^?]-)=([^&^#]*)") do
        res.query[k] = unescape(v)
    end
    return res
end

-- ─────────────────────────────────────────────
-- Route handlers
-- ─────────────────────────────────────────────

local routes = {}

-- Phase 1: Minimum Viable

routes["GET /ping"] = function(req)
    return ok_response("pong")
end

routes["GET /state"] = function(req)
    local state = require 'src.state'
    local registry = require 'src.registry'
    local utils = require 'src.utils'
    local gx, gy = state.physicsWorld:getGravity()
    local sel = state.selection.selectedObj
    local sel_id = nil
    if sel then
        local ud = sel:getUserData()
        local thing = ud and ud.thing
        sel_id = thing and thing.id
    end
    return ok_response({
        gravity = { x = gx, y = gy },
        paused = state.world.paused,
        speedMultiplier = state.world.speedMultiplier,
        meter = state.world.meter,
        currentMode = state.currentMode,
        darkMode = state.world.darkMode,
        debugDrawMode = state.world.debugDrawMode,
        showTextures = state.world.showTextures,
        selectedBody = sel_id,
        selectedJoint = state.selection.selectedJoint and (function()
            local ud = state.selection.selectedJoint:getUserData()
            return ud and ud.id
        end)() or nil,
    })
end

routes["GET /bodies"] = function(req)
    local registry = require 'src.registry'
    local result = {}
    for id, body in pairs(registry.bodies) do
        if not body:isDestroyed() then
            local ud = body:getUserData()
            local thing = ud and ud.thing
            result[#result + 1] = {
                id = id,
                label = thing and thing.label or nil,
                bodyType = body:getType(),
                x = body:getX(),
                y = body:getY(),
                angle = body:getAngle(),
                awake = body:isAwake(),
                fixtureCount = #body:getFixtures(),
            }
        end
    end
    return ok_response(result)
end

routes["GET /body"] = function(req)
    local registry = require 'src.registry'
    local id = req.query.id
    if not id then return err_response("missing ?id= parameter") end
    local body = registry.getBodyByID(id)
    if not body then return err_response("body not found: " .. id) end
    if body:isDestroyed() then return err_response("body is destroyed: " .. id) end

    local ud = body:getUserData()
    local thing = ud and ud.thing
    local vx, vy = body:getLinearVelocity()
    local mass, inertia = body:getMass(), body:getInertia()

    -- Fixtures
    local fixtures = {}
    for i, fix in ipairs(body:getFixtures()) do
        local shape = fix:getShape()
        local fix_data = {
            shapeType = shape:getType(),
            density = fix:getDensity(),
            friction = fix:getFriction(),
            restitution = fix:getRestitution(),
            isSensor = fix:isSensor(),
        }
        if shape:getType() == "polygon" then
            fix_data.points = { shape:getPoints() }
        elseif shape:getType() == "circle" then
            local cx, cy = shape:getPoint()
            fix_data.center = { x = cx, y = cy }
            fix_data.radius = shape:getRadius()
        elseif shape:getType() == "chain" then
            fix_data.points = { shape:getPoints() }
        elseif shape:getType() == "edge" then
            fix_data.points = { shape:getPoints() }
        end
        fixtures[#fixtures + 1] = fix_data
    end

    -- Connected joints
    local connected_joints = {}
    for _, joint in ipairs(body:getJoints()) do
        if not joint:isDestroyed() then
            local jud = joint:getUserData()
            connected_joints[#connected_joints + 1] = {
                id = jud and jud.id or nil,
                jointType = joint:getType(),
            }
        end
    end

    -- Thing data (safe serialized)
    local thing_data = nil
    if thing then
        thing_data = safe_serialize(thing, 0, 3)
    end

    return ok_response({
        id = id,
        label = thing and thing.label or nil,
        shapeType = thing and thing.shapeType or nil,
        bodyType = body:getType(),
        x = body:getX(),
        y = body:getY(),
        angle = body:getAngle(),
        vx = vx, vy = vy,
        angularVelocity = body:getAngularVelocity(),
        linearDamping = body:getLinearDamping(),
        angularDamping = body:getAngularDamping(),
        fixedRotation = body:isFixedRotation(),
        gravityScale = body:getGravityScale(),
        mass = mass,
        inertia = inertia,
        awake = body:isAwake(),
        active = body:isActive(),
        fixtures = fixtures,
        connectedJoints = connected_joints,
        thing = thing_data,
    })
end

routes["GET /joints"] = function(req)
    local registry = require 'src.registry'
    local result = {}
    for id, joint in pairs(registry.joints) do
        if not joint:isDestroyed() then
            local bodyA, bodyB = joint:getBodies()
            local udA = bodyA and bodyA:getUserData()
            local udB = bodyB and bodyB:getUserData()
            local thingA = udA and udA.thing
            local thingB = udB and udB.thing
            local ud = joint:getUserData()
            result[#result + 1] = {
                id = id,
                jointType = joint:getType(),
                bodyA = thingA and thingA.id or nil,
                bodyB = thingB and thingB.id or nil,
                labelA = thingA and thingA.label or nil,
                labelB = thingB and thingB.label or nil,
            }
        end
    end
    return ok_response(result)
end

routes["GET /joint"] = function(req)
    local registry = require 'src.registry'
    local id = req.query.id
    if not id then return err_response("missing ?id= parameter") end
    local joint = registry.getJointByID(id)
    if not joint then return err_response("joint not found: " .. id) end
    if joint:isDestroyed() then return err_response("joint is destroyed: " .. id) end

    local bodyA, bodyB = joint:getBodies()
    local udA = bodyA and bodyA:getUserData()
    local udB = bodyB and bodyB:getUserData()
    local thingA = udA and udA.thing
    local thingB = udB and udB.thing
    local ud = joint:getUserData()
    local jtype = joint:getType()

    local data = {
        id = id,
        jointType = jtype,
        bodyA = thingA and thingA.id or nil,
        bodyB = thingB and thingB.id or nil,
        labelA = thingA and thingA.label or nil,
        labelB = thingB and thingB.label or nil,
        collideConnected = joint:getCollideConnected(),
    }

    -- Type-specific properties
    if jtype == "revolute" then
        data.jointAngle = joint:getJointAngle()
        data.jointSpeed = joint:getJointSpeed()
        data.motorEnabled = joint:isMotorEnabled()
        data.limitsEnabled = joint:areLimitsEnabled()
        if joint:areLimitsEnabled() then
            data.lowerLimit, data.upperLimit = joint:getLimits()
        end
        if joint:isMotorEnabled() then
            data.motorSpeed = joint:getMotorSpeed()
            data.maxMotorTorque = joint:getMaxMotorTorque()
        end
        data.anchorA = { joint:getAnchors() }
    elseif jtype == "distance" then
        data.length = joint:getLength()
        data.frequency = joint:getFrequency()
        data.dampingRatio = joint:getDampingRatio()
        data.anchorA = { joint:getAnchors() }
    elseif jtype == "prismatic" then
        data.jointTranslation = joint:getJointTranslation()
        data.jointSpeed = joint:getJointSpeed()
        data.motorEnabled = joint:isMotorEnabled()
        data.limitsEnabled = joint:areLimitsEnabled()
        data.axis = { joint:getAxis() }
    elseif jtype == "weld" then
        data.frequency = joint:getFrequency()
        data.dampingRatio = joint:getDampingRatio()
    elseif jtype == "rope" then
        data.maxLength = joint:getMaxLength()
    elseif jtype == "friction" then
        data.maxForce = joint:getMaxForce()
        data.maxTorque = joint:getMaxTorque()
    end

    -- Include joint userData (safe serialized)
    if ud then
        data.userData = safe_serialize(ud, 0, 3)
    end

    return ok_response(data)
end

-- /eval — Execute Lua, return result as JSON
routes["POST /eval"] = function(req)
    local code = req.json_body and req.json_body.code
    if not code then return err_response("missing 'code' in JSON body") end
    local max_depth = req.json_body.depth or 4

    -- Preamble: make common modules available
    local preamble = [[
        local state = require 'src.state'
        local registry = require 'src.registry'
        local objectManager = require 'src.object-manager'
        local joints = require 'src.joints'
        local sceneIO = require 'src.io'
        local inspect = require 'vendor.inspect'
        local utils = require 'src.utils'
    ]]

    local full_code = preamble .. "\n" .. code
    local fn, compile_err = loadstring(full_code, "eval")
    if not fn then
        return err_response("compile error: " .. tostring(compile_err))
    end

    -- Timeout via instruction count hook (~100ms worth)
    local timed_out = false
    local old_hook_fn, old_hook_mask, old_hook_count = debug.gethook()
    debug.sethook(function()
        timed_out = true
        error("eval timeout: execution exceeded instruction limit")
    end, "", 1000000) -- ~1M instructions

    local ok, result = pcall(fn)

    -- Restore old hook
    if old_hook_fn then
        debug.sethook(old_hook_fn, old_hook_mask, old_hook_count)
    else
        debug.sethook()
    end

    if not ok then
        return err_response(tostring(result))
    end

    return ok_response(safe_serialize(result, 0, max_depth))
end

-- Phase 2: Full Read Capability

routes["GET /selection"] = function(req)
    local state = require 'src.state'
    local registry = require 'src.registry'

    local sel = state.selection.selectedObj
    if not sel then
        -- Check for selected joint
        local sj = state.selection.selectedJoint
        if sj and not sj:isDestroyed() then
            local ud = sj:getUserData()
            local id = ud and ud.id
            if id then
                -- Reuse joint handler
                local fake_req = { query = { id = id } }
                return routes["GET /joint"](fake_req)
            end
        end
        return ok_response(nil)
    end
    if sel:isDestroyed() then return ok_response(nil) end

    local ud = sel:getUserData()
    local thing = ud and ud.thing
    local id = thing and thing.id
    if id then
        local fake_req = { query = { id = id } }
        return routes["GET /body"](fake_req)
    end
    return ok_response(nil)
end

routes["GET /sfixtures"] = function(req)
    local registry = require 'src.registry'
    local result = {}
    for id, sfix in pairs(registry.sfixtures) do
        local body = nil
        local ok_pcall, _ = pcall(function()
            if not sfix:isDestroyed() then
                body = sfix:getBody()
            end
        end)
        local body_id = nil
        if body then
            local bud = body:getUserData()
            local thing = bud and bud.thing
            body_id = thing and thing.id
        end
        result[#result + 1] = {
            id = id,
            bodyId = body_id,
        }
    end
    return ok_response(result)
end

routes["GET /scene"] = function(req)
    local state = require 'src.state'
    local sceneIO = require 'src.io'
    local camera = require 'src.camera'
    local cam = camera.getInstance()
    local ok_pcall, data = pcall(function()
        return sceneIO.gatherSaveData(state.physicsWorld, cam)
    end)
    if not ok_pcall then
        return err_response("gatherSaveData failed: " .. tostring(data))
    end
    return ok_response(safe_serialize(data, 0, 6))
end

routes["GET /world"] = function(req)
    local state = require 'src.state'
    local gx, gy = state.physicsWorld:getGravity()
    return ok_response({
        gravity = { x = gx, y = gy },
        meter = state.world.meter,
        paused = state.world.paused,
        speedMultiplier = state.world.speedMultiplier,
        darkMode = state.world.darkMode,
        debugDrawMode = state.world.debugDrawMode,
        drawFixtures = state.world.drawFixtures,
        drawOutline = state.world.drawOutline,
        showTextures = state.world.showTextures,
        showDebugIds = state.world.showDebugIds,
        debugAlpha = state.world.debugAlpha,
        debugDrawBodies = state.world.debugDrawBodies,
        debugDrawJoints = state.world.debugDrawJoints,
    })
end

routes["GET /registry"] = function(req)
    local registry = require 'src.registry'
    local bodies = {}
    for id, body in pairs(registry.bodies) do
        if not body:isDestroyed() then
            local ud = body:getUserData()
            local thing = ud and ud.thing
            bodies[id] = {
                label = thing and thing.label or nil,
                bodyType = body:getType(),
                x = body:getX(),
                y = body:getY(),
            }
        end
    end
    local joints = {}
    for id, joint in pairs(registry.joints) do
        if not joint:isDestroyed() then
            joints[id] = {
                jointType = joint:getType(),
            }
        end
    end
    local sfixtures = {}
    for id, _ in pairs(registry.sfixtures) do
        sfixtures[id] = true
    end
    return ok_response({
        bodies = bodies,
        joints = joints,
        sfixtures = sfixtures,
    })
end

-- Phase 3: Write Capability

-- /exec — Execute Lua without return value (fire-and-forget)
routes["POST /exec"] = function(req)
    local code = req.json_body and req.json_body.code
    if not code then return err_response("missing 'code' in JSON body") end

    local preamble = [[
        local state = require 'src.state'
        local registry = require 'src.registry'
        local objectManager = require 'src.object-manager'
        local joints = require 'src.joints'
        local sceneIO = require 'src.io'
        local inspect = require 'vendor.inspect'
        local utils = require 'src.utils'
    ]]

    local full_code = preamble .. "\n" .. code
    local fn, compile_err = loadstring(full_code, "exec")
    if not fn then
        return err_response("compile error: " .. tostring(compile_err))
    end

    local ok, err_msg = pcall(fn)
    if not ok then
        return err_response(tostring(err_msg))
    end

    return ok_response(true)
end

routes["POST /world/pause"] = function(req)
    local state = require 'src.state'
    state.world.paused = true
    return ok_response(true)
end

routes["POST /world/unpause"] = function(req)
    local state = require 'src.state'
    state.world.paused = false
    return ok_response(true)
end

routes["POST /world/step"] = function(req)
    local state = require 'src.state'
    local frames = (req.json_body and req.json_body.frames) or 1
    local dt = 1 / 60
    for i = 1, frames do
        state.physicsWorld:update(dt, 8, 3)
    end
    return ok_response({ stepped = frames })
end

routes["POST /body/create"] = function(req)
    local objectManager = require 'src.object-manager'
    local params = req.json_body
    if not params then return err_response("missing JSON body") end
    local shape = params.shape or "rectangle"
    local opts = params.opts or {}
    local ok_pcall, result = pcall(function()
        return objectManager.addThing(shape, opts)
    end)
    if not ok_pcall then
        return err_response("addThing failed: " .. tostring(result))
    end
    return ok_response(safe_serialize(result, 0, 2))
end

routes["POST /body/destroy"] = function(req)
    local registry = require 'src.registry'
    local objectManager = require 'src.object-manager'
    local state = require 'src.state'
    local id = req.json_body and req.json_body.id
    if not id then return err_response("missing 'id' in JSON body") end
    local body = registry.getBodyByID(id)
    if not body then return err_response("body not found: " .. id) end
    -- Must clear Box2D callbacks before destroying — LÖVE's C++ crashes with SEGFAULT
    -- when endContact fires on partially-destroyed fixtures (Reference::push fails)
    local state = require 'src.state'
    local cb = {state.physicsWorld:getCallbacks()}
    state.physicsWorld:setCallbacks(nil, nil, nil, nil)
    bridge.destroying_body = true
    local ok_pcall, err_msg = pcall(function()
        objectManager.destroyBody(body)
    end)
    bridge.destroying_body = false
    if #cb > 0 then state.physicsWorld:setCallbacks(unpack(cb)) end
    if not ok_pcall then
        return err_response("destroyThing failed: " .. tostring(err_msg))
    end
    return ok_response(true)
end

routes["POST /scene/save"] = function(req)
    local state = require 'src.state'
    local sceneIO = require 'src.io'
    local camera = require 'src.camera'
    local cam = camera.getInstance()
    local filename = req.json_body and req.json_body.filename
    if not filename then return err_response("missing 'filename' in JSON body") end
    local ok_pcall, err_msg = pcall(function()
        local data = sceneIO.gatherSaveData(state.physicsWorld, cam)
        local encoded = json.encode(data, { indent = true })
        local f = io.open(filename, "w")
        if not f then error("cannot open file: " .. filename) end
        f:write(encoded)
        f:close()
    end)
    if not ok_pcall then
        return err_response("save failed: " .. tostring(err_msg))
    end
    return ok_response({ saved = filename })
end

routes["POST /scene/load"] = function(req)
    local sceneLoader = require 'src.scene-loader'
    local filename = req.json_body and req.json_body.filename
    if not filename then return err_response("missing 'filename' in JSON body") end
    local ok_pcall, err_msg = pcall(function()
        sceneLoader.loadScene(filename)
    end)
    if not ok_pcall then
        return err_response("load failed: " .. tostring(err_msg))
    end
    return ok_response({ loaded = filename })
end

routes["POST /reload"] = function(req)
    -- Force hot-reload by resetting the timer in scene-loader's maybeHotReload
    -- Since there's no direct hotReload function, we use eval as fallback
    local sceneLoader = require 'src.scene-loader'
    local state = require 'src.state'
    local ok_pcall, err_msg = pcall(function()
        if state.scene.scriptPath then
            sceneLoader.loadAndRunScript(state.scene.scriptPath)
        end
    end)
    if not ok_pcall then
        return err_response("reload failed: " .. tostring(err_msg))
    end
    return ok_response(true)
end

-- ─── Camera ───

routes["GET /camera"] = function(req)
    local camera = require 'src.camera'
    local cam = camera.getInstance()
    local tx, ty = cam:getTranslation()
    local scale = cam:getScale()
    local cw, ch = cam:getContainerDimensions()
    local halfW = (cw / scale) / 2
    local halfH = (ch / scale) / 2
    return ok_response({
        x = tx,
        y = ty,
        scale = scale,
        visibleBounds = {
            left = tx - halfW,
            top = ty - halfH,
            right = tx + halfW,
            bottom = ty + halfH,
        },
    })
end

routes["POST /camera"] = function(req)
    local camera = require 'src.camera'
    local cam = camera.getInstance()
    local params = req.json_body or {}

    if params.fitToScene then
        local registry = require 'src.registry'
        local minX, minY = math.huge, math.huge
        local maxX, maxY = -math.huge, -math.huge
        local count = 0
        for _, body in pairs(registry.bodies) do
            if not body:isDestroyed() then
                local x, y = body:getPosition()
                if x < minX then minX = x end
                if y < minY then minY = y end
                if x > maxX then maxX = x end
                if y > maxY then maxY = y end
                count = count + 1
            end
        end
        if count > 0 then
            local padding = 100
            local cx = (minX + maxX) / 2
            local cy = (minY + maxY) / 2
            local vw = (maxX - minX) + padding * 2
            local vh = (maxY - minY) + padding * 2
            camera.centerCameraOnPosition(cx, cy, vw, vh)
        end
    else
        if params.x or params.y then
            local tx, ty = cam:getTranslation()
            cam:setTranslation(params.x or tx, params.y or ty)
        end
        if params.scale then
            cam:setScale(params.scale)
        end
    end

    -- Return updated state
    local tx, ty = cam:getTranslation()
    local scale = cam:getScale()
    local cw, ch = cam:getContainerDimensions()
    local halfW = (cw / scale) / 2
    local halfH = (ch / scale) / 2
    return ok_response({
        x = tx,
        y = ty,
        scale = scale,
        visibleBounds = {
            left = tx - halfW,
            top = ty - halfH,
            right = tx + halfW,
            bottom = ty + halfH,
        },
    })
end

-- ─── Screenshot ───

routes["POST /screenshot"] = function(req)
    local params = req.json_body or {}
    local filename = params.filename or ("screenshot_" .. bridge.frame_count .. ".png")
    local savedir = love.filesystem.getSaveDirectory()
    local fullpath = savedir .. "/" .. filename
    -- Use callback form: captureScreenshot fires at end of love.draw()
    local ready = false
    local capture_error = nil
    love.graphics.captureScreenshot(function(imageData)
        local ok_encode, fileData = pcall(function()
            return imageData:encode("png")
        end)
        if not ok_encode then
            capture_error = tostring(fileData)
            ready = true
            return
        end
        local ok_write, writeErr = pcall(function()
            love.filesystem.write(filename, fileData)
        end)
        if not ok_write then
            capture_error = tostring(writeErr)
        end
        ready = true
    end)
    -- Return a deferred response that the connection handler will poll
    return {
        _deferred = true,
        max_frames = 120, -- ~2 seconds at 60fps
        poll = function()
            if not ready then return nil end
            if capture_error then
                return err_response("screenshot failed: " .. capture_error)
            end
            return ok_response({ filename = filename, path = fullpath })
        end,
    }
end

-- ─── Scene Clear ───

routes["POST /scene/clear"] = function(req)
    local registry = require 'src.registry'
    local objectManager = require 'src.object-manager'
    local destroyed = 0
    local state = require 'src.state'
    -- Clear Box2D callbacks to prevent SEGFAULT during body destruction
    local cb = {state.physicsWorld:getCallbacks()}
    state.physicsWorld:setCallbacks(nil, nil, nil, nil)
    bridge.destroying_body = true
    -- Collect IDs first to avoid modifying table during iteration
    local ids = {}
    for id, body in pairs(registry.bodies) do
        ids[#ids + 1] = { id = id, body = body }
    end
    for _, entry in ipairs(ids) do
        if not entry.body:isDestroyed() then
            local ok_pcall, err_msg = pcall(function()
                objectManager.destroyBody(entry.body)
            end)
            if ok_pcall then
                destroyed = destroyed + 1
            end
        end
    end
    bridge.destroying_body = false
    if #cb > 0 then state.physicsWorld:setCallbacks(unpack(cb)) end
    -- Reset registry to clean up any stragglers
    registry.bodies = {}
    registry.joints = {}
    registry.sfixtures = {}
    return ok_response({ destroyed = destroyed })
end

-- ─── World Run ───

routes["POST /world/run"] = function(req)
    local state = require 'src.state'
    local params = req.json_body or {}
    local frames = params.frames or 60
    local dt = 1 / 60
    local was_paused = state.world.paused
    state.world.paused = false
    for i = 1, frames do
        state.physicsWorld:update(dt, 8, 3)
    end
    state.world.paused = true
    return ok_response({ stepped = frames, wasPaused = was_paused })
end

-- ─── Bounds ───

routes["GET /bounds"] = function(req)
    local registry = require 'src.registry'
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local count = 0
    for _, body in pairs(registry.bodies) do
        if not body:isDestroyed() then
            local x, y = body:getPosition()
            if x < minX then minX = x end
            if y < minY then minY = y end
            if x > maxX then maxX = x end
            if y > maxY then maxY = y end
            count = count + 1
        end
    end
    if count == 0 then
        return ok_response({ left = 0, top = 0, right = 0, bottom = 0, count = 0 })
    end
    return ok_response({
        left = minX, top = minY,
        right = maxX, bottom = maxY,
        count = count,
    })
end

-- ─── Help ───

local route_descriptions = {
    ["GET /ping"] = "Health check, returns 'pong'",
    ["GET /state"] = "Get overall app state (gravity, paused, mode, selection)",
    ["GET /bodies"] = "List all bodies (id, label, position, type)",
    ["GET /body"] = "Get detailed body info by ?id=",
    ["GET /joints"] = "List all joints",
    ["GET /joint"] = "Get detailed joint info by ?id=",
    ["GET /selection"] = "Get the currently selected body or joint",
    ["GET /sfixtures"] = "List all special fixtures",
    ["GET /scene"] = "Get full scene save data",
    ["GET /world"] = "Get world settings (gravity, meter, draw modes)",
    ["GET /registry"] = "Get registry summary (bodies, joints, sfixtures)",
    ["GET /camera"] = "Get camera position, scale, and visible bounds",
    ["GET /bounds"] = "Get AABB encompassing all bodies",
    ["GET /help"] = "List all available routes with descriptions",
    ["GET /diff"] = "Compare two snapshots (?from=&to=)",
    ["POST /eval"] = "Execute Lua code and return result as JSON",
    ["POST /exec"] = "Execute Lua code (fire-and-forget, no return value)",
    ["POST /body/create"] = "Create a new physics body",
    ["POST /body/destroy"] = "Destroy a body by id",
    ["POST /world/pause"] = "Pause physics simulation",
    ["POST /world/unpause"] = "Unpause physics simulation",
    ["POST /world/step"] = "Step physics N frames (default 1) while paused",
    ["POST /world/run"] = "Unpause, step N frames (default 60), re-pause",
    ["POST /scene/save"] = "Save scene to file",
    ["POST /scene/load"] = "Load scene from file",
    ["POST /scene/clear"] = "Destroy all bodies and reset registry",
    ["POST /reload"] = "Hot-reload current script",
    ["POST /snapshot"] = "Take a named snapshot of body positions",
    ["POST /screenshot"] = "Capture screenshot, returns file path",
    ["POST /camera"] = "Set camera position/scale or fitToScene",
    ["POST /quit"] = "Quit the application",
    ["GET /console"] = "Get recent print() output (?n=50 for last N lines)",
    ["POST /console/clear"] = "Clear the console buffer",
    ["GET /errors"] = "Get captured errors (lurker, pcall, etc.)",
    ["POST /errors/clear"] = "Clear the error list",
    ["POST /body/update"] = "Update body properties (position, velocity, type, friction, etc.)",
    ["GET /collisions"] = "Get collision events (?n=50, ?body=ID, ?type=beginContact)",
    ["POST /collisions/start"] = "Start logging collisions (enables physics callbacks)",
    ["POST /collisions/stop"] = "Stop logging collisions",
    ["POST /collisions/clear"] = "Clear collision log",
    ["POST /input"] = "Queue raw input events (mousepressed, keypressed, etc.)",
    ["POST /input/click"] = "Simulate a mouse click at x,y",
    ["POST /input/drag"] = "Simulate a mouse drag from (x1,y1) to (x2,y2)",
    ["POST /input/key"] = "Simulate a key press",
    ["POST /watch"] = "Register a watch expression (evaluated every N frames)",
    ["GET /watch"] = "Get watch samples (?name=X or list all)",
    ["DELETE /watch"] = "Remove a watch (?name=X or clear all)",
    ["POST /breakpoint"] = "Set a conditional breakpoint (pauses when condition is true)",
    ["GET /breakpoint"] = "Get breakpoint status (?name=X or list all)",
    ["POST /breakpoint/reset"] = "Reset a hit breakpoint so it can trigger again",
    ["DELETE /breakpoint"] = "Remove a breakpoint (?name=X or clear all)",
    ["POST /profile/benchmark"] = "Benchmark a Lua code snippet (iterations, warmup, returns timing stats)",
    ["POST /profile/frames"] = "Profile N frames of physics with ProFi (returns text report)",
    ["POST /specs"] = "Run busted specs inside LÖVE ({target:'spec/file.lua', fresh:true})",
}

routes["GET /help"] = function(req)
    local result = {}
    for route, desc in pairs(route_descriptions) do
        local method, path = route:match("(%S+) (%S+)")
        result[#result + 1] = {
            method = method,
            path = path,
            description = desc,
        }
    end
    table.sort(result, function(a, b)
        if a.path == b.path then return a.method < b.method end
        return a.path < b.path
    end)
    return ok_response(result)
end

-- ─── Console ───

routes["GET /console"] = function(req)
    local last_n = tonumber(req.query.n) or 50
    local result = {}
    local start = math.max(1, #bridge.console_buffer - last_n + 1)
    for i = start, #bridge.console_buffer do
        result[#result + 1] = bridge.console_buffer[i]
    end
    return ok_response(result)
end

routes["POST /console/clear"] = function(req)
    bridge.console_buffer = {}
    return ok_response(true)
end

-- ─── Errors ───

routes["GET /errors"] = function(req)
    return ok_response(bridge.errors)
end

routes["POST /errors/clear"] = function(req)
    bridge.errors = {}
    return ok_response(true)
end

-- ─── Body Editing ───

routes["POST /body/update"] = function(req)
    local registry = require 'src.registry'
    local params = req.json_body
    if not params then return err_response("missing JSON body") end
    local id = params.id
    if not id then return err_response("missing 'id'") end
    local body = registry.getBodyByID(id)
    if not body then return err_response("body not found: " .. id) end
    if body:isDestroyed() then return err_response("body is destroyed: " .. id) end

    local applied = {}

    -- Position
    if params.x or params.y then
        local cx, cy = body:getPosition()
        body:setPosition(params.x or cx, params.y or cy)
        applied[#applied + 1] = "position"
    end

    -- Angle
    if params.angle then
        body:setAngle(params.angle)
        applied[#applied + 1] = "angle"
    end

    -- Velocity
    if params.vx or params.vy then
        local vx, vy = body:getLinearVelocity()
        body:setLinearVelocity(params.vx or vx, params.vy or vy)
        applied[#applied + 1] = "linearVelocity"
    end

    -- Angular velocity
    if params.angularVelocity then
        body:setAngularVelocity(params.angularVelocity)
        applied[#applied + 1] = "angularVelocity"
    end

    -- Body type
    if params.bodyType then
        body:setType(params.bodyType)
        applied[#applied + 1] = "bodyType"
    end

    -- Damping
    if params.linearDamping then
        body:setLinearDamping(params.linearDamping)
        applied[#applied + 1] = "linearDamping"
    end
    if params.angularDamping then
        body:setAngularDamping(params.angularDamping)
        applied[#applied + 1] = "angularDamping"
    end

    -- Gravity scale
    if params.gravityScale then
        body:setGravityScale(params.gravityScale)
        applied[#applied + 1] = "gravityScale"
    end

    -- Fixed rotation
    if params.fixedRotation ~= nil then
        body:setFixedRotation(params.fixedRotation)
        applied[#applied + 1] = "fixedRotation"
    end

    -- Awake
    if params.awake ~= nil then
        body:setAwake(params.awake)
        applied[#applied + 1] = "awake"
    end

    -- Active
    if params.active ~= nil then
        body:setActive(params.active)
        applied[#applied + 1] = "active"
    end

    -- Fixture properties (applied to all fixtures)
    if params.friction or params.restitution or params.density or params.sensor ~= nil then
        for _, fixture in ipairs(body:getFixtures()) do
            if params.friction then
                fixture:setFriction(params.friction)
            end
            if params.restitution then
                fixture:setRestitution(params.restitution)
            end
            if params.density then
                fixture:setDensity(params.density)
            end
            if params.sensor ~= nil then
                fixture:setSensor(params.sensor)
            end
        end
        if params.density then
            body:resetMassData()
        end
        if params.friction then applied[#applied + 1] = "friction" end
        if params.restitution then applied[#applied + 1] = "restitution" end
        if params.density then applied[#applied + 1] = "density" end
        if params.sensor ~= nil then applied[#applied + 1] = "sensor" end
    end

    -- Apply impulse
    if params.impulse then
        local ix = params.impulse.x or 0
        local iy = params.impulse.y or 0
        body:applyLinearImpulse(ix, iy)
        applied[#applied + 1] = "impulse"
    end

    -- Apply force
    if params.force then
        local fx = params.force.x or 0
        local fy = params.force.y or 0
        body:applyForce(fx, fy)
        applied[#applied + 1] = "force"
    end

    return ok_response({ id = id, applied = applied })
end

-- ─── Collision Log ───

routes["GET /collisions"] = function(req)
    local last_n = tonumber(req.query.n) or 50
    local filter_body = req.query.body  -- optional: filter by body id
    local filter_type = req.query.type  -- optional: filter by event type
    local result = {}
    for i = #bridge.collisions, 1, -1 do
        local c = bridge.collisions[i]
        local match = true
        if filter_body and c.bodyA ~= filter_body and c.bodyB ~= filter_body then
            match = false
        end
        if filter_type and c.type ~= filter_type then
            match = false
        end
        if match then
            result[#result + 1] = c
            if #result >= last_n then break end
        end
    end
    -- Reverse so oldest first
    local reversed = {}
    for i = #result, 1, -1 do reversed[#reversed + 1] = result[i] end
    return ok_response({
        logging = bridge.collision_logging,
        count = #bridge.collisions,
        events = reversed,
    })
end

routes["POST /collisions/start"] = function(req)
    local state = require 'src.state'
    bridge.collision_logging = true
    bridge.collisions = {}
    -- Enable physics callbacks if not already set
    state.physicsWorld:setCallbacks(unpack(state.physicsCallbacks))
    return ok_response({ logging = true })
end

routes["POST /collisions/stop"] = function(req)
    bridge.collision_logging = false
    return ok_response({ logging = false, eventsCaptured = #bridge.collisions })
end

routes["POST /collisions/clear"] = function(req)
    bridge.collisions = {}
    return ok_response(true)
end

-- ─── Input Simulation ───

routes["POST /input"] = function(req)
    local events = req.json_body and req.json_body.events
    if not events then
        -- Single event shorthand
        local event = req.json_body
        if not event or not event.type then
            return err_response("missing 'events' array or single event with 'type'")
        end
        events = { event }
    end

    local queued = 0
    for _, event in ipairs(events) do
        local delay = event.delay or 0  -- delay in frames from now
        event.frame = bridge.frame_count + delay
        table.insert(bridge.input_queue, event)
        queued = queued + 1
    end
    return ok_response({ queued = queued })
end

routes["POST /input/click"] = function(req)
    local params = req.json_body or {}
    local x = params.x or 0
    local y = params.y or 0
    local button = params.button or 1
    local hold = params.hold or 3  -- frames to hold

    table.insert(bridge.input_queue, { type = "mousemoved", x = x, y = y, frame = bridge.frame_count + 1 })
    table.insert(bridge.input_queue, { type = "mousepressed", x = x, y = y, button = button, frame = bridge.frame_count + 2 })
    table.insert(bridge.input_queue, { type = "mousereleased", x = x, y = y, button = button, frame = bridge.frame_count + 2 + hold })
    return ok_response({ x = x, y = y, button = button })
end

routes["POST /input/drag"] = function(req)
    local params = req.json_body or {}
    local fromX = params.fromX or params.x1 or 0
    local fromY = params.fromY or params.y1 or 0
    local toX = params.toX or params.x2 or 0
    local toY = params.toY or params.y2 or 0
    local steps = params.steps or 10
    local button = params.button or 1

    -- Move to start
    table.insert(bridge.input_queue, { type = "mousemoved", x = fromX, y = fromY, frame = bridge.frame_count + 1 })
    -- Press
    table.insert(bridge.input_queue, { type = "mousepressed", x = fromX, y = fromY, button = button, frame = bridge.frame_count + 2 })
    -- Interpolate movement
    for i = 1, steps do
        local t = i / steps
        local x = fromX + (toX - fromX) * t
        local y = fromY + (toY - fromY) * t
        local dx = (toX - fromX) / steps
        local dy = (toY - fromY) / steps
        table.insert(bridge.input_queue, { type = "mousemoved", x = x, y = y, dx = dx, dy = dy, frame = bridge.frame_count + 2 + i })
    end
    -- Release
    table.insert(bridge.input_queue, { type = "mousereleased", x = toX, y = toY, button = button, frame = bridge.frame_count + 3 + steps })
    return ok_response({ fromX = fromX, fromY = fromY, toX = toX, toY = toY, steps = steps })
end

routes["POST /input/key"] = function(req)
    local params = req.json_body or {}
    local key = params.key
    if not key then return err_response("missing 'key'") end
    local hold = params.hold or 2  -- frames to hold

    table.insert(bridge.input_queue, { type = "keypressed", key = key, frame = bridge.frame_count + 1 })
    table.insert(bridge.input_queue, { type = "keyreleased", key = key, frame = bridge.frame_count + 1 + hold })
    return ok_response({ key = key })
end

-- ─── Watch Expressions ───

routes["POST /watch"] = function(req)
    local params = req.json_body or {}
    local name = params.name
    if not name then return err_response("missing 'name'") end
    local code = params.code
    if not code then return err_response("missing 'code' (Lua expression)") end
    local interval = params.interval or 1  -- evaluate every N frames
    local max_samples = params.max_samples or bridge.watch_max_samples

    -- Compile with same preamble as eval
    local preamble = [[
        local state = require 'src.state'
        local registry = require 'src.registry'
        local objectManager = require 'src.object-manager'
        local inspect = require 'vendor.inspect'
        local utils = require 'src.utils'
    ]]
    local full_code = preamble .. "\nreturn " .. code
    local fn, compile_err = loadstring(full_code, "watch:" .. name)
    if not fn then
        return err_response("compile error: " .. tostring(compile_err))
    end

    bridge.watches[name] = {
        code = code,
        fn = fn,
        interval = interval,
        max_samples = max_samples,
        samples = {},
        last_frame = bridge.frame_count,
    }
    return ok_response({ name = name, interval = interval })
end

routes["GET /watch"] = function(req)
    local name = req.query.name
    if name then
        -- Get specific watch
        local watch = bridge.watches[name]
        if not watch then return err_response("watch not found: " .. name) end
        local last_n = tonumber(req.query.n) or #watch.samples
        local result = {}
        local start = math.max(1, #watch.samples - last_n + 1)
        for i = start, #watch.samples do
            result[#result + 1] = watch.samples[i]
        end
        return ok_response({
            name = name,
            code = watch.code,
            interval = watch.interval,
            sampleCount = #watch.samples,
            samples = result,
        })
    else
        -- List all watches
        local result = {}
        for wname, watch in pairs(bridge.watches) do
            local last_sample = watch.samples[#watch.samples]
            result[#result + 1] = {
                name = wname,
                code = watch.code,
                interval = watch.interval,
                sampleCount = #watch.samples,
                lastValue = last_sample and last_sample.value or nil,
                lastError = last_sample and last_sample.error or nil,
            }
        end
        return ok_response(result)
    end
end

routes["DELETE /watch"] = function(req)
    local name = req.query.name
    if not name then
        -- Clear all watches
        bridge.watches = {}
        return ok_response({ cleared = "all" })
    end
    if not bridge.watches[name] then
        return err_response("watch not found: " .. name)
    end
    bridge.watches[name] = nil
    return ok_response({ removed = name })
end

-- ─── Breakpoints ───

routes["POST /breakpoint"] = function(req)
    local params = req.json_body or {}
    local name = params.name
    if not name then return err_response("missing 'name'") end
    local code = params.code
    if not code then return err_response("missing 'code' (Lua condition that returns truthy to break)") end
    local once = params.once
    if once == nil then once = false end

    local preamble = [[
        local state = require 'src.state'
        local registry = require 'src.registry'
        local objectManager = require 'src.object-manager'
        local inspect = require 'vendor.inspect'
        local utils = require 'src.utils'
    ]]
    local full_code = preamble .. "\nreturn " .. code
    local fn, compile_err = loadstring(full_code, "breakpoint:" .. name)
    if not fn then
        return err_response("compile error: " .. tostring(compile_err))
    end

    bridge.breakpoints[name] = {
        code = code,
        fn = fn,
        hit = false,
        hit_frame = nil,
        hit_value = nil,
        once = once,
    }
    return ok_response({ name = name, once = once })
end

routes["GET /breakpoint"] = function(req)
    local name = req.query.name
    if name then
        local bp = bridge.breakpoints[name]
        if not bp then return err_response("breakpoint not found: " .. name) end
        return ok_response({
            name = name,
            code = bp.code,
            hit = bp.hit,
            hit_frame = bp.hit_frame,
            hit_value = bp.hit_value,
            once = bp.once,
        })
    else
        local result = {}
        for bname, bp in pairs(bridge.breakpoints) do
            result[#result + 1] = {
                name = bname,
                code = bp.code,
                hit = bp.hit,
                hit_frame = bp.hit_frame,
                hit_value = bp.hit_value,
                once = bp.once,
            }
        end
        return ok_response(result)
    end
end

routes["POST /breakpoint/reset"] = function(req)
    local name = req.json_body and req.json_body.name
    if name then
        local bp = bridge.breakpoints[name]
        if not bp then return err_response("breakpoint not found: " .. name) end
        bp.hit = false
        bp.hit_frame = nil
        bp.hit_value = nil
        return ok_response({ reset = name })
    else
        for _, bp in pairs(bridge.breakpoints) do
            bp.hit = false
            bp.hit_frame = nil
            bp.hit_value = nil
        end
        return ok_response({ reset = "all" })
    end
end

routes["DELETE /breakpoint"] = function(req)
    local name = req.query.name
    if not name then
        bridge.breakpoints = {}
        return ok_response({ cleared = "all" })
    end
    if not bridge.breakpoints[name] then
        return err_response("breakpoint not found: " .. name)
    end
    bridge.breakpoints[name] = nil
    return ok_response({ removed = name })
end

-- ─── Profiling ───

routes["POST /profile/benchmark"] = function(req)
    local params = req.json_body or {}
    local code = params.code
    if not code then return err_response("missing 'code' (Lua code to benchmark)") end
    local iterations = params.iterations or 100
    local warmup = params.warmup or 10

    local preamble = [[
        local state = require 'src.state'
        local registry = require 'src.registry'
        local objectManager = require 'src.object-manager'
        local inspect = require 'vendor.inspect'
        local utils = require 'src.utils'
    ]]

    local full_code = preamble .. "\nreturn function()\n" .. code .. "\nend"
    local fn, compile_err = loadstring(full_code, "benchmark")
    if not fn then
        return err_response("compile error: " .. tostring(compile_err))
    end

    local ok, bench_fn = pcall(fn)
    if not ok then
        return err_response("runtime error: " .. tostring(bench_fn))
    end
    if type(bench_fn) ~= "function" then
        return err_response("code must be executable statements (wrapped in a function)")
    end

    -- Warmup
    for i = 1, warmup do
        local wok, werr = pcall(bench_fn)
        if not wok then
            return err_response("error during warmup: " .. tostring(werr))
        end
    end

    -- Benchmark
    local times = {}
    local total = 0
    local clock = love.timer.getTime or os.clock
    for i = 1, iterations do
        local t0 = clock()
        bench_fn()
        local t1 = clock()
        local elapsed = t1 - t0
        times[i] = elapsed
        total = total + elapsed
    end

    table.sort(times)
    local mean = total / iterations
    local median = times[math.ceil(iterations / 2)]
    local min = times[1]
    local max = times[iterations]
    -- p95
    local p95 = times[math.ceil(iterations * 0.95)]

    return ok_response({
        iterations = iterations,
        warmup = warmup,
        total = total,
        mean = mean,
        median = median,
        min = min,
        max = max,
        p95 = p95,
        unit = "seconds",
    })
end

routes["POST /profile/frames"] = function(req)
    local params = req.json_body or {}
    local frames = params.frames or 60
    local sort = params.sort or "duration"

    ProFi:reset()
    if sort == "count" then
        ProFi:setSortMethod("count")
    else
        ProFi:setSortMethod("duration")
    end

    ProFi:start()
    local state = require 'src.state'
    local dt = 1 / 60
    for i = 1, frames do
        state.physicsWorld:update(dt, 8, 3)
    end
    ProFi:stop()

    -- Write to temp file, read back
    local tmpfile = love.filesystem.getSaveDirectory() .. "/_bridge_profile.txt"
    ProFi:writeReport(tmpfile)

    local f = io.open(tmpfile, "r")
    local report = ""
    if f then
        report = f:read("*all")
        f:close()
        os.remove(tmpfile)
    end

    return ok_response({
        frames = frames,
        sort = sort,
        report = report,
    })
end

-- ─── Specs (busted inside LÖVE) ───

routes["POST /specs"] = function(req)
    local target = (req.json_body and req.json_body.target) or "spec"
    local freshModules = req.json_body and req.json_body.fresh  -- clear src.* from package.loaded

    -- Add luarocks 5.1 paths so busted can be found
    local home = os.getenv('HOME')
    local oldPath = package.path
    local oldCpath = package.cpath
    package.path = home .. '/.luarocks/share/lua/5.1/?.lua;'
                 .. home .. '/.luarocks/share/lua/5.1/?/init.lua;'
                 .. package.path
    package.cpath = home .. '/.luarocks/lib/lua/5.1/?.so;'
                  .. package.cpath

    -- Capture busted output
    local output_lines = {}
    local oldPrint = print
    print = function(...)
        local parts = {}
        for i = 1, select('#', ...) do
            parts[#parts + 1] = tostring(select(i, ...))
        end
        local line = table.concat(parts, "\t")
        output_lines[#output_lines + 1] = line
        oldPrint(...)  -- also print to console
    end

    -- Capture io.write too (busted uses it for progress dots)
    local oldWrite = io.write
    local writeBuffer = ""
    io.write = function(...)
        for i = 1, select('#', ...) do
            writeBuffer = writeBuffer .. tostring(select(i, ...))
        end
        oldWrite(...)
    end

    -- Intercept os.exit
    local realExit = os.exit
    local exitCode = 0
    os.exit = function(code)
        exitCode = code or 0
    end

    -- Clear any previously loaded busted modules so we get a fresh run
    for k in pairs(package.loaded) do
        if k:match('^busted') or k:match('^pl%.') or k:match('^mediator') or k:match('^say') or k:match('^term') or k:match('^luassert') then
            package.loaded[k] = nil
        end
    end

    -- Optionally clear src.* modules for a clean require state
    -- (specs that test module behavior may need this)
    if freshModules then
        for k in pairs(package.loaded) do
            if k:match('^src%.') or k:match('^spec%.') then
                package.loaded[k] = nil
            end
        end
    end

    -- Override arg
    local oldArg = arg
    arg = { target }
    arg[0] = 'busted'
    arg[-1] = 'luajit'

    local ok, err = pcall(function()
        require('busted.runner')({ standalone = false })
    end)

    -- Restore everything
    arg = oldArg
    os.exit = realExit
    print = oldPrint
    io.write = oldWrite
    package.path = oldPath
    package.cpath = oldCpath

    if writeBuffer ~= "" then
        table.insert(output_lines, 1, writeBuffer)
    end

    if not ok then
        return ok_response({
            success = false,
            error = tostring(err),
            output = table.concat(output_lines, "\n"),
        })
    end

    return ok_response({
        success = exitCode == 0,
        exit_code = exitCode,
        output = table.concat(output_lines, "\n"),
    })
end

-- ─── Quit ───

routes["POST /quit"] = function(req)
    love.event.quit()
    return ok_response(true)
end

-- Phase 4: Snapshot / Diff

routes["POST /snapshot"] = function(req)
    local name = req.json_body and req.json_body.name
    if not name then return err_response("missing 'name' in JSON body") end
    local registry = require 'src.registry'
    local snap = {}
    for id, body in pairs(registry.bodies) do
        if not body:isDestroyed() then
            local ud = body:getUserData()
            local thing = ud and ud.thing
            snap[id] = {
                label = thing and thing.label or nil,
                bodyType = body:getType(),
                x = body:getX(),
                y = body:getY(),
                angle = body:getAngle(),
                awake = body:isAwake(),
            }
        end
    end
    bridge.snapshots[name] = {
        time = os.time(),
        frame = bridge.frame_count,
        bodies = snap,
    }
    return ok_response({ name = name, bodyCount = 0 + (function()
        local c = 0
        for _ in pairs(snap) do c = c + 1 end
        return c
    end)() })
end

routes["GET /diff"] = function(req)
    local from_name = req.query.from
    local to_name = req.query.to
    if not from_name or not to_name then
        return err_response("missing ?from= or ?to= parameter")
    end
    local snap_from = bridge.snapshots[from_name]
    local snap_to = bridge.snapshots[to_name]
    if not snap_from then return err_response("snapshot not found: " .. from_name) end
    if not snap_to then return err_response("snapshot not found: " .. to_name) end

    local added = {}
    local removed = {}
    local moved = {}
    local changed = {}

    -- Bodies in 'to' but not in 'from'
    for id, b in pairs(snap_to.bodies) do
        if not snap_from.bodies[id] then
            added[#added + 1] = { id = id, label = b.label, x = b.x, y = b.y }
        end
    end

    -- Bodies in 'from' but not in 'to'
    for id, b in pairs(snap_from.bodies) do
        if not snap_to.bodies[id] then
            removed[#removed + 1] = { id = id, label = b.label }
        end
    end

    -- Bodies in both — check for changes
    for id, b_from in pairs(snap_from.bodies) do
        local b_to = snap_to.bodies[id]
        if b_to then
            local dx = math.abs(b_to.x - b_from.x)
            local dy = math.abs(b_to.y - b_from.y)
            local da = math.abs(b_to.angle - b_from.angle)
            if dx > 0.1 or dy > 0.1 or da > 0.001 then
                moved[#moved + 1] = {
                    id = id,
                    label = b_from.label,
                    from = { x = b_from.x, y = b_from.y, angle = b_from.angle },
                    to = { x = b_to.x, y = b_to.y, angle = b_to.angle },
                }
            end
            -- Check other property changes
            if b_to.bodyType ~= b_from.bodyType or b_to.awake ~= b_from.awake then
                changed[#changed + 1] = {
                    id = id,
                    label = b_from.label,
                    from = { bodyType = b_from.bodyType, awake = b_from.awake },
                    to = { bodyType = b_to.bodyType, awake = b_to.awake },
                }
            end
        end
    end

    return ok_response({
        from = { name = from_name, frame = snap_from.frame, time = snap_from.time },
        to = { name = to_name, frame = snap_to.frame, time = snap_to.time },
        added = added,
        removed = removed,
        moved = moved,
        changed = changed,
    })
end

-- ─────────────────────────────────────────────
-- HTTP server (borrowed from lovebird pattern)
-- ─────────────────────────────────────────────

local function check_whitelist(addr)
    if bridge.whitelist == nil then return true end
    for _, a in ipairs(bridge.whitelist) do
        local ptn = "^" .. a:gsub("%.", "%%."):gsub("%*", "%%d*") .. "$"
        if addr:match(ptn) then return true end
    end
    return false
end

local function receive(client, pattern)
    while true do
        local data, msg = client:receive(pattern)
        if not data then
            if msg == "timeout" then
                coroutine.yield(true)
            else
                coroutine.yield(nil)
            end
        else
            return data
        end
    end
end

local function send(client, data)
    local idx = 1
    while idx < #data do
        local res, msg = client:send(data, idx)
        if not res and msg == "closed" then
            coroutine.yield(nil)
        else
            idx = idx + res
            coroutine.yield(true)
        end
    end
end

local function handle_connection(client)
    -- Parse request line
    local request_line = receive(client, "*l")
    if not request_line then return end

    local method, url, proto = request_line:match("(%S*)%s*(%S*)%s*(%S*)")
    if not method or not url then return end

    -- Parse headers
    local headers = {}
    while true do
        local line = receive(client, "*l")
        if not line or #line == 0 then break end
        local k, v = line:match("(.-):%s*(.*)$")
        if k then headers[k] = v end
    end

    -- Read body if Content-Length present
    local body = nil
    if headers["Content-Length"] then
        local len = tonumber(headers["Content-Length"])
        if len and len > 0 then
            body = receive(client, len)
        end
    end

    -- Parse URL
    local parsed_url = parse_url(url)

    -- Build request object
    local req = {
        method = method,
        url = url,
        path = parsed_url.path,
        query = parsed_url.query,
        headers = headers,
        body = body,
        json_body = nil,
    }

    -- Parse JSON body
    if body and headers["Content-Type"] and headers["Content-Type"]:find("application/json") then
        local ok_decode, decoded = pcall(json.decode, body)
        if ok_decode then
            req.json_body = decoded
        end
    end

    -- Also try parsing body as JSON even without Content-Type header (convenience for curl)
    if body and not req.json_body then
        local ok_decode, decoded = pcall(json.decode, body)
        if ok_decode and type(decoded) == "table" then
            req.json_body = decoded
        end
    end

    -- Handle CORS preflight
    if method == "OPTIONS" then
        local resp = "HTTP/1.1 204 No Content\r\n" ..
            "Access-Control-Allow-Origin: *\r\n" ..
            "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n" ..
            "Access-Control-Allow-Headers: Content-Type\r\n" ..
            "Content-Length: 0\r\n" ..
            "\r\n"
        send(client, resp)
        client:close()
        return
    end

    -- Route to handler
    local route_key = method .. " /" .. parsed_url.path
    local handler = routes[route_key]

    local response_body
    if handler then
        local ok_handler, result = pcall(handler, req)
        if ok_handler then
            -- Support deferred responses (e.g. screenshot waits for next draw)
            if type(result) == "table" and result._deferred then
                local frames_waited = 0
                while frames_waited < (result.max_frames or 120) do
                    local polled = result.poll()
                    if polled then
                        response_body = polled
                        break
                    end
                    frames_waited = frames_waited + 1
                    coroutine.yield(true) -- yield back to bridge.update, resume next frame
                end
                if not response_body then
                    response_body = err_response("deferred response timed out")
                end
            else
                response_body = result
            end
        else
            response_body = err_response("handler error: " .. tostring(result))
        end
    else
        response_body = err_response("not found: " .. method .. " /" .. parsed_url.path)
    end

    local http_response = json_http_response("200 OK", response_body)
    send(client, http_response)
    client:close()
end

-- ─────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────

function bridge.init()
    -- Create TCP socket with SO_REUSEADDR to avoid "address already in use" on restart
    local server = socket.tcp4()
    server:setoption("reuseaddr", true)
    assert(server:bind(bridge.host, bridge.port))
    assert(server:listen(8))
    server:settimeout(0)
    bridge.server = server
    local addr, port = bridge.server:getsockname()
    print("[claude-bridge] listening on " .. addr .. ":" .. port)
    bridge.inited = true
end

function bridge.update()
    if not bridge.inited then bridge.init() end
    bridge.frame_count = bridge.frame_count + 1

    -- Process input queue
    local new_queue = {}
    for _, event in ipairs(bridge.input_queue) do
        if event.frame <= bridge.frame_count then
            if event.type == "mousepressed" and love.mousepressed then
                love.mousepressed(event.x, event.y, event.button or 1, false)
            elseif event.type == "mousereleased" and love.mousereleased then
                love.mousereleased(event.x, event.y, event.button or 1, false)
            elseif event.type == "mousemoved" and love.mousemoved then
                love.mousemoved(event.x, event.y, event.dx or 0, event.dy or 0)
            elseif event.type == "keypressed" and love.keypressed then
                love.keypressed(event.key, event.key, false)
            elseif event.type == "keyreleased" and love.keyreleased then
                love.keyreleased(event.key, event.key)
            elseif event.type == "wheelmoved" and love.wheelmoved then
                love.wheelmoved(event.dx or 0, event.dy or 0)
            end
        else
            new_queue[#new_queue + 1] = event
        end
    end
    bridge.input_queue = new_queue

    -- Evaluate watches
    for name, watch in pairs(bridge.watches) do
        if bridge.frame_count - watch.last_frame >= watch.interval then
            watch.last_frame = bridge.frame_count
            local ok, result = pcall(watch.fn)
            local sample = {
                frame = bridge.frame_count,
                value = ok and safe_serialize(result, 0, 3) or nil,
                error = not ok and tostring(result) or nil,
            }
            table.insert(watch.samples, sample)
            while #watch.samples > watch.max_samples do
                table.remove(watch.samples, 1)
            end
        end
    end

    -- Evaluate breakpoints
    local state = require 'src.state'
    if not state.world.paused then
        local to_remove = {}
        for name, bp in pairs(bridge.breakpoints) do
            if not bp.hit then
                local ok, result = pcall(bp.fn)
                if ok and result then
                    bp.hit = true
                    bp.hit_frame = bridge.frame_count
                    bp.hit_value = safe_serialize(result, 0, 3)
                    state.world.paused = true
                    print("[bridge] breakpoint '" .. name .. "' hit at frame " .. bridge.frame_count)
                    if bp.once then
                        to_remove[#to_remove + 1] = name
                    end
                end
            end
        end
        for _, name in ipairs(to_remove) do
            bridge.breakpoints[name] = nil
        end
    end

    -- Accept new connections
    while true do
        local client = bridge.server:accept()
        if not client then break end
        client:settimeout(0)
        local addr = client:getsockname()
        if check_whitelist(addr) then
            local conn = coroutine.wrap(function()
                xpcall(function() handle_connection(client) end, function(err)
                    print("[claude-bridge] error: " .. tostring(err))
                end)
            end)
            bridge.connections[conn] = true
        else
            client:close()
        end
    end

    -- Resume existing connections
    for conn in pairs(bridge.connections) do
        local status = conn()
        if status == nil then
            bridge.connections[conn] = nil
        end
    end
end

return bridge

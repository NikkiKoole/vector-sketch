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
        local eio = require 'src.io'
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
    local eio = require 'src.io'
    local camera = require 'src.camera'
    local cam = camera.getInstance()
    local ok_pcall, data = pcall(function()
        return eio.gatherSaveData(state.physicsWorld, cam)
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
        local eio = require 'src.io'
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
    local id = req.json_body and req.json_body.id
    if not id then return err_response("missing 'id' in JSON body") end
    local body = registry.getBodyByID(id)
    if not body then return err_response("body not found: " .. id) end
    local ok_pcall, err_msg = pcall(function()
        objectManager.destroyBody(body)
    end)
    if not ok_pcall then
        return err_response("destroyThing failed: " .. tostring(err_msg))
    end
    return ok_response(true)
end

routes["POST /scene/save"] = function(req)
    local state = require 'src.state'
    local eio = require 'src.io'
    local camera = require 'src.camera'
    local cam = camera.getInstance()
    local filename = req.json_body and req.json_body.filename
    if not filename then return err_response("missing 'filename' in JSON body") end
    local ok_pcall, err_msg = pcall(function()
        local data = eio.gatherSaveData(state.physicsWorld, cam)
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
            response_body = result
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
    bridge.server = assert(socket.bind(bridge.host, bridge.port))
    bridge.server:settimeout(0)
    local addr, port = bridge.server:getsockname()
    print("[claude-bridge] listening on " .. addr .. ":" .. port)
    bridge.inited = true
end

function bridge.update()
    if not bridge.inited then bridge.init() end
    bridge.frame_count = bridge.frame_count + 1

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

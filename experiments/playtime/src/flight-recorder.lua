-- flight-recorder.lua
-- Dev tool: a rolling buffer of per-step physics state for Mipos, so odd behavior
-- (limbs stretching, getting stuck) can be inspected frame by frame afterwards.
-- Arm it, reproduce the problem, then dump:
--   curl -X POST localhost:8001/eval -d '{"code":"return require(\"src.flight-recorder\").arm()"}'
--   curl -X POST localhost:8001/eval -d '{"code":"return require(\"src.flight-recorder\").dump(\"circles\")"}'
-- The dump is JSON in the LÖVE save directory (flight/<name>.json).
local json = require('vendor.dkjson')
local state = require('src.state')
local mipoRegistry = require('src.mipo-registry')
local camera = require('src.camera')

local lib = {}

lib.armed = false
lib.maxFrames = 60 * 30 -- 30 seconds at 60 fps

local frames = {}
local head = 0  -- index of the newest frame in the ring
local count = 0
local frameNumber = 0

local function r(x) return math.floor(x * 100 + 0.5) / 100 end

local function partName(body)
    local instance, name = mipoRegistry.getFromBody(body)
    if instance then return instance.id .. '.' .. name end
    local ud = body:getUserData()
    return (ud and ud.thing and (ud.thing.label or ud.thing.id)) or tostring(body)
end

local function capture(dt)
    frameNumber = frameNumber + 1
    local mx, my = love.mouse.getPosition()
    local wmx, wmy = camera.getInstance():getWorldCoordinates(mx, my)
    local frame = { f = frameNumber, t = r(love.timer.getTime()), dt = r(dt * 1000) / 1000,
                    mouse = { r(wmx), r(wmy), love.mouse.isDown(1) },
                    parts = {}, joints = {}, grabs = {}, external = {} }

    for _, body in ipairs(state.physicsWorld:getBodies()) do
        if mipoRegistry.getFromBody(body) then
            local x, y = body:getPosition()
            local vx, vy = body:getLinearVelocity()
            frame.parts[partName(body)] = { r(x), r(y), r(body:getAngle()), r(vx), r(vy), r(body:getAngularVelocity()) }
        end
    end

    local invDt = dt > 0 and 1 / dt or 60
    for _, joint in ipairs(state.physicsWorld:getJoints()) do
        local bodyA, bodyB = joint:getBodies()
        local jointType = joint:getType()
        if jointType == 'mouse' then
            local tx, ty = joint:getTarget()
            local ax, ay = joint:getAnchors()
            local fx, fy = joint:getReactionForce(invDt)
            frame.grabs[#frame.grabs + 1] = { body = partName(bodyB or bodyA), target = { r(tx), r(ty) },
                anchor = { r(ax), r(ay) }, force = r(math.sqrt(fx * fx + fy * fy)), maxForce = r(joint:getMaxForce()) }
        elseif bodyA and bodyB and mipoRegistry.getFromBody(bodyA)
            and mipoRegistry.getFromBody(bodyA) == mipoRegistry.getFromBody(bodyB) then
            local x1, y1, x2, y2 = joint:getAnchors()
            local fx, fy = joint:getReactionForce(invDt)
            local entry = { a = partName(bodyA), b = partName(bodyB), type = jointType,
                sep = r(math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)), force = r(math.sqrt(fx * fx + fy * fy)) }
            if jointType == 'revolute' then
                entry.angle = r(joint:getJointAngle())
                if joint:areLimitsEnabled() then
                    entry.limits = { r(joint:getLowerLimit()), r(joint:getUpperLimit()) }
                end
                entry.torque = r(joint:getReactionTorque(invDt))
            end
            frame.joints[#frame.joints + 1] = entry
        elseif bodyA and bodyB then
            -- joints from a Mipo part to something else (e.g. mud balls): count per part
            for _, body in ipairs({ bodyA, bodyB }) do
                if mipoRegistry.getFromBody(body) then
                    local name = partName(body)
                    frame.external[name] = (frame.external[name] or 0) + 1
                end
            end
        end
    end

    head = head % lib.maxFrames + 1
    frames[head] = frame
    count = math.min(count + 1, lib.maxFrames)
end

function lib.update(dt)
    if lib.armed and state.physicsWorld then capture(dt) end
end

function lib.arm()
    frames, head, count = {}, 0, 0
    lib.armed = true
    return 'armed: keeping the last ' .. lib.maxFrames .. ' physics steps'
end

function lib.disarm()
    lib.armed = false
    return 'disarmed'
end

-- Frames in order, oldest first.
function lib.getFrames()
    local ordered = {}
    for i = 1, count do
        local idx = (head - count + i - 1) % lib.maxFrames + 1
        ordered[#ordered + 1] = frames[idx]
    end
    return ordered
end

function lib.dump(name)
    local ordered = lib.getFrames()
    love.filesystem.createDirectory('flight')
    local path = 'flight/' .. (name or ('dump-' .. frameNumber)) .. '.json'
    love.filesystem.write(path, json.encode({ frames = ordered }))
    return { path = love.filesystem.getSaveDirectory() .. '/' .. path, frames = #ordered }
end

return lib

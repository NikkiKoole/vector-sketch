-- camera-follow.lua — the camera while playing, Sago style. It follows the Mipo you
-- last touched (or the body you pinned in the on-stage tab); paused, it stays put.
-- It holds still while you drag (the pointer would chase the camera), and a manual
-- pan hands the camera back to you until the next touch. Dragging something to the
-- edge of the screen pans that way (playing or not). While playing the camera keeps
-- inside the scene's bounds and zoom limits. Scripts get follow/shake/zoomTo/bounds
-- through lib.script. The settings are per scene (state.cameraSettings, saved with
-- the camera in src/io.lua); the settings panel's camera section shows them
-- (src/camera-params.lua). docs/EXPERIMENTS-HARVEST.md #2, docs/DOLL-PLAY.md.
local lib = {}

local state = require('src.state')
local camera = require('src.camera')
local mathutils = require('src.math-utils')
local mipoRegistry = require('src.mipo-registry')
local pointerJoints = require('src.physics.box2d-pointerjoints')

-- What a scene starts with; a saved scene overrides what it has.
lib.defaults = {
    follow = true,      -- follow while playing
    deadZone = 0.3,     -- fraction of the screen the target may wander from the centre before the camera moves
    speed = 3,          -- how quickly the camera catches up (1/s)
    lookAhead = 0.35,   -- seconds of the target's velocity to lead by
    maxLead = 0.25,     -- the lead is at most this fraction of the screen
    minZoom = 0.1,      -- zoom limits while playing
    maxZoom = 5,
    edgePan = true,     -- dragging something near the screen edge pans
    edgeMargin = 80,    -- screen px from the edge where that starts
    edgeSpeed = 900,    -- screen px/s right at the edge
    edgeLag = 150,      -- screen px: a dragged thing this far behind the cursor (stuck behind a wall) stops the pan
    bounds = nil,       -- { x1, y1, x2, y2 } in world units: while playing the view stays inside
}

-- On state: a hot reload keeps who's being followed.
state.cameraFollow = state.cameraFollow or { pinned = nil, last = nil, handsOff = false }
local F = state.cameraFollow

function lib.settings()
    if not state.cameraSettings then lib.loadSettings(nil) end
    return state.cameraSettings
end

-- A scene's saved settings (nil: a scene without them gets the defaults).
function lib.loadSettings(saved)
    local s = {}
    for k, v in pairs(lib.defaults) do s[k] = v end
    for k, v in pairs(saved or {}) do s[k] = v end
    if s.bounds then s.bounds = { s.bounds[1], s.bounds[2], s.bounds[3], s.bounds[4] } end
    state.cameraSettings = s
    F.pinned, F.last, F.handsOff, F.zoom, F.shake = nil, nil, false, nil, nil
    return s
end

function lib.saveSettings()
    local out = {}
    for k, v in pairs(lib.settings()) do out[k] = v end
    return out
end

local function alive(body) return body and not body:isDestroyed() and body end

-- The body that stands for what was touched: a Mipo's torso, else the body itself.
local function standIn(body)
    local instance = mipoRegistry.getFromBody(body)
    local torso = instance and instance.parts and instance.parts.torso1
    return alive(torso and torso.body) or body
end

local function playing() return not state.world.paused end

function lib.isOn()
    return lib.settings().follow ~= false and playing()
end

-- Follow this body from now on (nil: back to the last touched).
function lib.pin(body)
    F.pinned = body and standIn(body) or nil
    F.handsOff = false
end

function lib.isPinned(body)
    return body ~= nil and F.pinned ~= nil and alive(F.pinned) == standIn(body)
end

-- A manual pan: leave the camera alone until something is touched again.
function lib.notePan()
    if lib.isOn() then F.handsOff = true end
end

function lib.target()
    return alive(F.pinned) or alive(F.last)
end

-- The smallest zoom that keeps the view inside the bounds (or minZoom).
local function zoomFloor(s, w, h)
    local floor = s.minZoom
    local b = s.bounds
    if b and b[3] > b[1] and b[4] > b[2] then
        floor = math.max(floor, w / (b[3] - b[1]), h / (b[4] - b[2]))
    end
    return floor
end

-- May the wheel zoom to `scale`? While playing: only inside the limits.
function lib.zoomAllowed(scale)
    if not playing() then return true end
    local s = lib.settings()
    local w, h = love.graphics.getDimensions()
    return scale >= zoomFloor(s, w, h) and scale <= s.maxZoom
end

-- Moves `from` toward `to` by the part outside +-zone, smoothed by k.
local function approach(from, to, zone, k)
    local e = to - from
    if math.abs(e) <= zone then return from end
    local beyond = e - (e > 0 and zone or -zone)
    return from + beyond * k
end

-- How far into the edge margin p is (0 outside it, 1 at the edge), signed by side.
local function edgeDepth(p, size, margin)
    if p < margin then return -(margin - math.max(0, p)) / margin end
    if p > size - margin then return (p - (size - margin)) / margin end
    return 0
end

-- How much a dragged thing keeps up with the cursor: 1 when the grabbed point is at the
-- cursor, fading to 0 at `edgeLag` screen px behind it. grabX/grabY in world units (nil: keeping up).
local function keepingUp(cam, s, mx, my, grabX, grabY)
    if not grabX then return 1 end
    local sx, sy = cam:getScreenCoordinates(grabX, grabY)
    local lag = math.sqrt((sx - mx) ^ 2 + (sy - my) ^ 2)
    local near = math.max(1, s.edgeLag) / 2
    return mathutils.clamp(2 - lag / near, 0, 1)
end

-- Pan when the mouse, dragging something, is near the screen edge. Returns the pan in world units.
-- grabX/grabY: where the dragged thing is held (world); when it lags behind, the pan stops.
function lib.edgePan(dt, mx, my, grabX, grabY)
    local s = lib.settings()
    if not s.edgePan then return 0, 0 end
    local cam = camera.getInstance()
    local w, h = love.graphics.getDimensions()
    local margin = math.max(1, s.edgeMargin)
    local speed = s.edgeSpeed * dt / cam.scale * keepingUp(cam, s, mx, my, grabX, grabY)
    local dx = edgeDepth(mx, w, margin) * speed
    local dy = edgeDepth(my, h, margin) * speed
    if dx ~= 0 or dy ~= 0 then
        local cx, cy = cam:getTranslation()
        cam:setTranslation(cx + dx, cy + dy)
    end
    return dx, dy
end

-- Keep the view inside the bounds (centred on an axis where the bounds are smaller than the view).
local function clampToBounds(cam, s, w, h)
    local b = s.bounds
    if not b then return end
    local cx, cy = cam:getTranslation()
    local hw, hh = w / 2 / cam.scale, h / 2 / cam.scale
    local function clampAxis(c, lo, hi, half)
        if hi - lo <= half * 2 then return (lo + hi) / 2 end
        return mathutils.clamp(c, lo + half, hi - half)
    end
    cam:setTranslation(clampAxis(cx, b[1], b[3], hw), clampAxis(cy, b[2], b[4], hh))
end

local function follow(dt, cam, s, w, h)
    local body = lib.target()
    if not body then return end
    local scale = cam.scale
    local tx, ty = body:getPosition()
    local vx, vy = body:getLinearVelocity()
    local maxX, maxY = w * s.maxLead / scale, h * s.maxLead / scale
    tx = tx + mathutils.clamp(vx * s.lookAhead, -maxX, maxX)
    ty = ty + mathutils.clamp(vy * s.lookAhead, -maxY, maxY)
    local cx, cy = cam:getTranslation()
    local k = 1 - math.exp(-dt * s.speed)
    cam:setTranslation(approach(cx, tx, w * s.deadZone / scale, k), approach(cy, ty, h * s.deadZone / scale, k))
end

-- A scripted zoom (lib.zoomTo), eased; it wins over the zoom limits.
local function stepZoom(dt, cam)
    local z = F.zoom
    if not z then return false end
    z.t = math.min(z.duration, z.t + dt)
    local u = z.duration > 0 and z.t / z.duration or 1
    u = u * u * (3 - 2 * u)
    cam:setScale(mathutils.lerp(z.from, z.to, u))
    if z.t >= z.duration then F.zoom = nil end
    return true
end

-- The shake is an offset put on after everything else and taken off first thing next frame.
local function removeShake(cam)
    local o = F.shakeOffset
    if not o then return end
    local cx, cy = cam:getTranslation()
    cam:setTranslation(cx - o[1], cy - o[2])
    F.shakeOffset = nil
end

local function applyShake(dt, cam)
    local sh = F.shake
    if not sh then return end
    sh.t = sh.t + dt
    if sh.t >= sh.duration then F.shake = nil; return end
    local amount = sh.amount * (1 - sh.t / sh.duration)
    local ox, oy = (love.math.random() * 2 - 1) * amount, (love.math.random() * 2 - 1) * amount
    local cx, cy = cam:getTranslation()
    cam:setTranslation(cx + ox, cy + oy)
    F.shakeOffset = { ox, oy }
end

local function dragging()
    local dragged = pointerJoints.getInteractedWithPointer()
    return dragged[1] or (state.interaction.draggingObj and state.interaction.draggingObj.body)
end

function lib.update(dt)
    local cam = camera.getInstance()
    local s = lib.settings()
    local w, h = love.graphics.getDimensions()
    removeShake(cam)

    local dragged = dragging()
    if dragged then
        -- a pointer joint's second anchor is the point held on the body
        local pj = pointerJoints.getPointerJointAttachedTo(dragged)
        local grabX, grabY
        if pj and pj.joint and not pj.joint:isDestroyed() then
            local _, _, ax, ay = pj.joint:getAnchors()
            grabX, grabY = ax, ay
        end
        local mx, my = love.mouse.getPosition()
        lib.edgePan(dt, mx, my, grabX, grabY)
        if #pointerJoints.getInteractedWithPointer() > 0 then
            F.last = standIn(dragged)
            F.handsOff = false
        end
    elseif lib.isOn() and not F.handsOff then
        follow(dt, cam, s, w, h)
    end

    local zooming = stepZoom(dt, cam)
    if playing() then
        if not zooming then
            local scale = math.max(zoomFloor(s, w, h), math.min(s.maxZoom, cam.scale))
            if scale ~= cam.scale then cam:setScale(scale) end
        end
        clampToBounds(cam, s, w, h)
    end
    applyShake(dt, cam)
end

-- The bounds in the editor: the stage, with what's outside it dimmed. Inside cam:push().
function lib.drawBounds()
    local b = lib.settings().bounds
    if not b or playing() then return end
    local cam = camera.getInstance()
    local w, h = love.graphics.getDimensions()
    local x1, y1 = cam:getWorldCoordinates(0, 0)
    local x2, y2 = cam:getWorldCoordinates(w, h)
    x1, y1 = math.min(x1, b[1]), math.min(y1, b[2])
    x2, y2 = math.max(x2, b[3]), math.max(y2, b[4])
    love.graphics.setColor(0, 0, 0, 0.18)
    love.graphics.rectangle('fill', x1, y1, x2 - x1, b[2] - y1)
    love.graphics.rectangle('fill', x1, b[4], x2 - x1, y2 - b[4])
    love.graphics.rectangle('fill', x1, b[2], b[1] - x1, b[4] - b[2])
    love.graphics.rectangle('fill', b[3], b[2], x2 - b[3], b[4] - b[2])
    love.graphics.setColor(1, 0.55, 0.2, 0.9)
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(2 / cam.scale)
    love.graphics.rectangle('line', b[1], b[2], b[3] - b[1], b[4] - b[2])
    love.graphics.setLineWidth(lw)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Bounds from what the editor shows right now.
function lib.boundsFromView()
    local cam = camera.getInstance()
    local w, h = love.graphics.getDimensions()
    local x1, y1 = cam:getWorldCoordinates(0, 0)
    local x2, y2 = cam:getWorldCoordinates(w, h)
    lib.settings().bounds = { math.floor(x1), math.floor(y1), math.ceil(x2), math.ceil(y2) }
end

-- For scene scripts (src/script.lua puts it in their env as `camera`).
local function bodyOf(v)
    if type(v) == 'table' and v.body then return v.body end
    return v
end
lib.script = {
    follow = function(thingOrBody) lib.pin(bodyOf(thingOrBody)) end, -- nil: back to the last touched
    setBounds = function(x1, y1, x2, y2)
        lib.settings().bounds = x1 and { math.min(x1, x2), math.min(y1, y2), math.max(x1, x2), math.max(y1, y2) } or nil
    end,
    shake = function(amount, seconds) F.shake = { amount = amount or 20, duration = seconds or 0.4, t = 0 } end,
    zoomTo = function(scale, seconds)
        F.zoom = { from = camera.getInstance().scale, to = scale, duration = seconds or 0.6, t = 0 }
    end,
    settings = function() return lib.settings() end,
}

return lib
